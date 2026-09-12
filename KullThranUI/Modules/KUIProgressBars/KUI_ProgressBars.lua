-------------------------------------------------------------------------------
--  KUI_ProgressBars.lua
--  Runtime for detached progress bars kept outside the active TOC load path.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
if not KT then return end

local PB = KT:NewModule("KUIProgressBars", "AceEvent-3.0")
ns.PB = PB
local LSM = LibStub("LibSharedMedia-3.0", true)

local KUI_InGameBars = {}
local KUI_ProgressEngine = CreateFrame("Frame")
local AuraCache = { player={}, target={}, pet={}, focus={} }
local CastCache = {}
local AuraFrameIndex = { player = {}, target = {}, pet = {}, focus = {} }
local CastFrameIndex = {}
local TrackedBuffTimers = {}
local TrackedBuffFrameIndex = {}
local ActiveFrames = {}
local ActiveIndex = {}
local RecentItemUse = {}
local TrackedItemCounts = {}
local ItemSpellCache = {}
local StartTrackedBuffFrame
local StopTrackedBuffFrame

local function NormalizeDurationName(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end
    local normalized = value:lower():gsub("[^%w%s]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    if normalized == "" then
        return nil
    end
    return normalized
end

local CLASS_DURATION_SEEDS = {
    DRUID = {
        [22812] = { duration = 12, name = "Barkskin" },
        [22842] = { duration = 3, name = "Frenzied Regeneration" },
        [29166] = { duration = 10, name = "Innervate" },
        [48517] = { duration = 15, name = "Solar Eclipse" },
        [48518] = { duration = 15, name = "Lunar Eclipse" },
        [61336] = { duration = 6, name = "Survival Instincts" },
        [102342] = { duration = 12, name = "Ironbark" },
        [205636] = { duration = 10, name = "Force of Nature" },
    },
    WARRIOR = {
        [871] = { duration = 8, name = "Shield Wall" },
        [12975] = { duration = 15, name = "Last Stand" },
        [184364] = { duration = 8, name = "Enraged Regeneration" },
        [23920] = { duration = 5, name = "Spell Reflection" },
    },
    PALADIN = {
        [498] = { duration = 8, name = "Divine Protection" },
        [642] = { duration = 8, name = "Divine Shield" },
        [1022] = { duration = 10, name = "Blessing of Protection" },
        [1044] = { duration = 8, name = "Blessing of Freedom" },
        [31850] = { duration = 8, name = "Ardent Defender" },
    },
    PRIEST = {
        [33206] = { duration = 8, name = "Pain Suppression" },
        [47788] = { duration = 10, name = "Guardian Spirit" },
        [194384] = { duration = 15, name = "Atonement" },
    },
    MAGE = {
        [45438] = { duration = 10, name = "Ice Block" },
        [12051] = { duration = 6, name = "Evocation" },
    },
    ROGUE = {
        [31224] = { duration = 5, name = "Cloak of Shadows" },
        [5277] = { duration = 10, name = "Evasion" },
    },
    HUNTER = {
        [5384] = { duration = 360, name = "Feign Death" },
        [186265] = { duration = 8, name = "Aspect of the Turtle" },
    },
    WARLOCK = {
        [104773] = { duration = 8, name = "Unending Resolve" },
    },
    DEATHKNIGHT = {
        [48792] = { duration = 8, name = "Icebound Fortitude" },
        [55233] = { duration = 10, name = "Vampiric Blood" },
    },
    SHAMAN = {
        [108271] = { duration = 12, name = "Astral Shift" },
    },
    MONK = {
        [115203] = { duration = 15, name = "Fortifying Brew" },
    },
    DEMONHUNTER = {
        [187827] = { duration = 24, name = "Metamorphosis" },
    },
    EVOKER = {
        [363916] = { duration = 12, name = "Obsidian Scales" },
    },
}

local function IsAccessibleValue(v)
    if issecretvalue and issecretvalue(v) then return false end
    if canaccessvalue and not canaccessvalue(v) then return false end
    return true
end

local function IsSafeNum(v, fallback)
    if type(v) ~= "number" then return fallback end
    local ok, res = pcall(function() return v + 0 end)
    if not ok or (issecretvalue and issecretvalue(res)) then return fallback end
    return res
end

local function IsSafeStr(v, fallback)
    if not IsAccessibleValue(v) then return fallback end
    if type(v) ~= "string" then return fallback end
    return v
end

local function GetNow()
    return (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
end

local function IsProgressBarsEnabled()
    local p = KT.db and KT.db.profile and KT.db.profile.progressBars
    return not (p and p.enable == false)
end

local function HideAllProgressBars()
    for _, f in pairs(KUI_InGameBars) do
        if f then
            f:Hide()
            f._realDuration = 0
            f._kuiPBActive = false
        end
    end
    wipe(ActiveFrames)
    wipe(ActiveIndex)
end

local function GetCDMItemCooldownInfo(itemID)
    local cdmNS = _G.KUI_CDM_NS
    if cdmNS and type(cdmNS.CDMResolveItemCooldownInfo) == "function" then
        return cdmNS.CDMResolveItemCooldownInfo(itemID)
    end

    if C_Item and C_Item.GetItemCooldown then
        return C_Item.GetItemCooldown(itemID)
    end

    return 0, 0, 0
end

local function GetTrackedItemCount(itemID)
    itemID = IsSafeNum(itemID, 0)
    if itemID <= 0 then
        return 0
    end

    if C_Item and C_Item.GetItemCount then
        local ok, count = pcall(C_Item.GetItemCount, itemID, false, false, false, false)
        if ok then
            return IsSafeNum(count, 0)
        end
    end

    if _G.GetItemCount then
        local ok, count = pcall(_G.GetItemCount, itemID, false, false, false)
        if ok then
            return IsSafeNum(count, 0)
        end
    end

    return 0
end

local function GetTrackedProgressItemIDs()
    local ids, seen = {}, {}
    for _, frame in pairs(KUI_InGameBars) do
        if frame and frame._isActiveNow and frame._pbTriggerType == "spellcast" then
            local spellID = IsSafeNum(frame._pbSpellID, 0)
            if spellID < 0 then
                local itemID = -spellID
                if itemID > 0 and not seen[itemID] then
                    seen[itemID] = true
                    ids[#ids + 1] = itemID
                end
            end
        end
    end
    return ids
end

local function SnapshotTrackedItemCounts(markUsage)
    local now = GetNow()
    local active = {}
    local itemIDs = GetTrackedProgressItemIDs()

    for i = 1, #itemIDs do
        local itemID = itemIDs[i]
        active[itemID] = true
        local count = GetTrackedItemCount(itemID)
        local previous = TrackedItemCounts[itemID]
        if markUsage and previous ~= nil and count < previous then
            RecentItemUse[itemID] = now
        end
        TrackedItemCounts[itemID] = count
    end

    for itemID in pairs(TrackedItemCounts) do
        if not active[itemID] then
            TrackedItemCounts[itemID] = nil
            RecentItemUse[itemID] = nil
            ItemSpellCache[itemID] = nil
        end
    end
end

local function ResolveTrackedItemSpellID(itemID)
    itemID = IsSafeNum(itemID, 0)
    if itemID <= 0 then
        return 0
    end

    local cached = ItemSpellCache[itemID]
    if cached ~= nil then
        return cached
    end

    local spellID = 0
    local nameOrNil, spellInfo = nil, nil

    if C_Item and C_Item.GetItemSpell then
        local ok, a, b = pcall(C_Item.GetItemSpell, itemID)
        if ok then
            nameOrNil, spellInfo = a, b
        end
    elseif _G.GetItemSpell then
        local ok, a, b = pcall(_G.GetItemSpell, itemID)
        if ok then
            nameOrNil, spellInfo = a, b
        end
    end

    if type(spellInfo) == "number" then
        spellID = spellInfo
    elseif type(spellInfo) == "string" then
        spellID = tonumber(spellInfo:match("spell:(%d+)")) or 0
    elseif type(nameOrNil) == "number" then
        spellID = nameOrNil
    end

    ItemSpellCache[itemID] = spellID
    return spellID
end

local function MarkTrackedItemUseBySpell(spellID)
    spellID = IsSafeNum(spellID, 0)
    if spellID <= 0 then
        return
    end

    local now = GetNow()
    local itemIDs = GetTrackedProgressItemIDs()
    for i = 1, #itemIDs do
        local itemID = itemIDs[i]
        if ResolveTrackedItemSpellID(itemID) == spellID then
            RecentItemUse[itemID] = now
        end
    end
end

local function GetProgressSpellDurationDB()
    KUISpellDurationDB = KUISpellDurationDB or {}
    local db = KUISpellDurationDB
    db.spells = db.spells or {}
    db.names = db.names or {}
    db.meta = db.meta or {}

    if not db.meta.migratedFromProfile and KT and KT.db and KT.db.profile and KT.db.profile.cooldownManager then
        local legacy = KT.db.profile.cooldownManager.progressSpellDurations
        if type(legacy) == "table" then
            for key, value in pairs(legacy) do
                if type(key) == "number" and type(value) == "table" then
                    local duration = IsSafeNum(value.duration, 0)
                    if duration > 0 then
                        db.spells[key] = db.spells[key] or {}
                        db.spells[key].duration = duration
                        db.spells[key].name = db.spells[key].name or value.name
                    end
                end
            end
        end
        db.meta.migratedFromProfile = true
    end

    local _, classToken = UnitClass("player")
    db.meta.seededClasses = db.meta.seededClasses or {}
    if classToken and not db.meta.seededClasses[classToken] then
        local seeds = CLASS_DURATION_SEEDS[classToken]
        if seeds then
            for spellID, seed in pairs(seeds) do
                if type(db.spells[spellID]) ~= "table" or IsSafeNum(db.spells[spellID].duration, 0) <= 0 then
                    db.spells[spellID] = {
                        duration = seed.duration,
                        name = seed.name,
                        seeded = true,
                    }
                end
                local normalizedName = NormalizeDurationName(seed.name)
                if normalizedName and (not db.names[normalizedName] or IsSafeNum(db.names[normalizedName], 0) <= 0) then
                    db.names[normalizedName] = seed.duration
                end
            end
        end
        db.meta.seededClasses[classToken] = true
    end

    return db
end

local function RememberProgressSpellDuration(spellID, duration, spellName)
    spellID = IsSafeNum(spellID, 0)
    duration = IsSafeNum(duration, 0)
    if spellID <= 0 or duration <= 0 then
        return
    end

    local db = GetProgressSpellDurationDB()
    local entry = db.spells[spellID]
    if type(entry) ~= "table" then
        entry = {}
        db.spells[spellID] = entry
    end

    entry.duration = duration
    if type(spellName) == "string" and spellName ~= "" then
        entry.name = spellName
        local normalizedName = NormalizeDurationName(spellName)
        if normalizedName then
            db.names[normalizedName] = duration
        end
    end
    entry.updatedAt = GetNow()
end

function ns.GetStoredProgressSpellDuration(spellID, fallback, spellName)
    spellID = IsSafeNum(spellID, 0)
    local db = GetProgressSpellDurationDB()
    if spellID > 0 then
        local entry = db.spells[spellID]
        if type(entry) == "table" then
            local duration = IsSafeNum(entry.duration, 0)
            if duration > 0 then
                return duration
            end
        end
    end
    local normalizedName = NormalizeDurationName(spellName)
    if normalizedName then
        local byName = IsSafeNum(db.names[normalizedName], 0)
        if byName > 0 then
            return byName
        end
    end
    return fallback
end

local function ResolveProgressBarDuration(cfg, spellID, fallback)
    local spellName = cfg and cfg.name
    if (not spellName or spellName == "") and spellID > 0 and C_Spell and C_Spell.GetSpellName then
        local ok, resolvedName = pcall(C_Spell.GetSpellName, spellID)
        if ok then
            spellName = resolvedName
        end
    end
    if cfg and cfg.useCustomDuration and IsSafeNum(cfg.duration, 0) > 0 then
        return cfg.duration
    end
    return ns.GetStoredProgressSpellDuration(spellID, IsSafeNum(cfg and cfg.duration, fallback or 10), spellName)
end

local function GetProgressBarTexturePath(cfg)
    local textureName = cfg and cfg.texture
    if type(textureName) ~= "string" or textureName == "" then
        textureName = "Melli"
    end

    if LSM and textureName then
        local texturePath = LSM:Fetch("statusbar", textureName, true)
        if texturePath and texturePath ~= "" then
            return texturePath
        end
    end

    return "Interface\\Buttons\\WHITE8x8"
end

local function SaveToCache(unit, rawSpellID, rawExp, rawDur, rawApps, rawName, rawInstanceID)
    if type(rawSpellID) ~= "number" then return end
    local ok, spellID = pcall(function() return rawSpellID + 0 end)
    if not ok or (issecretvalue and issecretvalue(spellID)) then return end
    
    if not AuraCache[unit] then AuraCache[unit] = {} end
    local exp  = IsSafeNum(rawExp, 0)
    local dur  = IsSafeNum(rawDur, 0)
    local apps = IsSafeNum(rawApps, 0)
    local name = IsSafeStr(rawName, "")
    local inst = IsSafeNum(rawInstanceID, 0)

    if unit == "player" and dur > 0 then
        RememberProgressSpellDuration(spellID, dur, name)
        local trackedFrames = TrackedBuffFrameIndex[spellID]
        if trackedFrames then
            for i = 1, #trackedFrames do
                local frame = trackedFrames[i]
                if frame and frame._trackedBuffActive and frame.cfg and not frame.cfg.useCustomDuration then
                    frame._trackedBuffActive.duration = dur
                end
            end
        end
    end
    
    if not AuraCache[unit][spellID] or exp > AuraCache[unit][spellID].expirationTime then
        AuraCache[unit][spellID] = { expirationTime=exp, duration=dur, stacks=apps, name=name, instanceID=inst }
    end
end

local function NormalizeAuraName(value)
    if type(value) ~= "string" or value == "" then
        return ""
    end
    return value:lower():gsub("[^%w%s]", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
end

local function CanonicalAuraName(value)
    local normalized = NormalizeAuraName(value)
    if normalized == "" then
        return ""
    end
    local words = {}
    for word in normalized:gmatch("%S+") do
        words[#words + 1] = word
    end
    table.sort(words)
    return table.concat(words, " ")
end

local function AuraNamesMatch(left, right)
    local a = NormalizeAuraName(left)
    local b = NormalizeAuraName(right)
    if a == "" or b == "" then
        return false
    end
    if a == b or CanonicalAuraName(a) == CanonicalAuraName(b) then
        return true
    end
    return a:find(b, 1, true) ~= nil or b:find(a, 1, true) ~= nil
end

local function ResolveAuraCacheEntry(unit, cleanSpellID, cfg)
    local bySpell = AuraCache[unit]
    if not bySpell then
        return nil
    end

    local direct = bySpell[cleanSpellID]
    if direct then
        return direct
    end

    local wantedNames = {}
    local function AddWantedName(value)
        if type(value) == "string" and value ~= "" then
            wantedNames[#wantedNames + 1] = value
        end
    end

    AddWantedName(cfg and cfg.name)
    if cleanSpellID > 0 and C_Spell and C_Spell.GetSpellName then
        local ok, spellName = pcall(C_Spell.GetSpellName, cleanSpellID)
        if ok then
            AddWantedName(spellName)
        end
    end

    if #wantedNames == 0 then
        return nil
    end

    for _, auraData in pairs(bySpell) do
        if auraData and auraData.name then
            for i = 1, #wantedNames do
                if AuraNamesMatch(auraData.name, wantedNames[i]) then
                    return auraData
                end
            end
        end
    end

    return nil
end

local function ResolveTrackedBuffAuraLive(cleanSpellID, cfg)
    if cleanSpellID > 0 and C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, cleanSpellID)
        if ok and IsAccessibleValue(aura) and type(aura) == "table" then
            RememberProgressSpellDuration(cleanSpellID, aura.duration, aura.name)
            return aura
        end
    end

    local wantedNames = {}
    local function AddWantedName(value)
        if type(value) == "string" and value ~= "" then
            wantedNames[#wantedNames + 1] = value
        end
    end

    AddWantedName(cfg and cfg.name)
    if cleanSpellID > 0 and C_Spell and C_Spell.GetSpellName then
        local ok, spellName = pcall(C_Spell.GetSpellName, cleanSpellID)
        if ok then
            AddWantedName(spellName)
        end
    end

    if #wantedNames == 0 or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        return nil
    end

    for i = 1, 40 do
        local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not auraData or not IsAccessibleValue(auraData) or type(auraData) ~= "table" then
            break
        end
        for index = 1, #wantedNames do
            if AuraNamesMatch(auraData.name, wantedNames[index]) then
                RememberProgressSpellDuration(cleanSpellID, auraData.duration, auraData.name)
                return auraData
            end
        end
    end

    return nil
end

local function FullAuraScan(unit)
    if not AuraCache[unit] then AuraCache[unit] = {} end
    wipe(AuraCache[unit])
    local function Scan(filter)
        for i = 1, 100 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
            if not ok or not aura or not IsAccessibleValue(aura) or type(aura) ~= "table" then break end
            SaveToCache(unit, aura.spellId, aura.expirationTime, aura.duration, aura.applications, aura.name, aura.auraInstanceID)
        end
    end
    Scan("HELPFUL"); Scan("HARMFUL")
end

local function OnUnitAuraPayload(unit)
    -- Incremental UNIT_AURA lists are Blizzard-owned and may become
    -- non-iterable in tainted PvP execution. Index scans never consume them.
    FullAuraScan(unit)
end

local KUI_AuraTracker = CreateFrame("Frame")
KUI_AuraTracker:RegisterEvent("PLAYER_ENTERING_WORLD")
KUI_AuraTracker:RegisterEvent("UNIT_AURA")
KUI_AuraTracker:RegisterEvent("PLAYER_TARGET_CHANGED")
KUI_AuraTracker:RegisterEvent("PLAYER_FOCUS_CHANGED")
KUI_AuraTracker:RegisterEvent("UNIT_PET")
KUI_AuraTracker:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
KUI_AuraTracker:RegisterEvent("BAG_UPDATE_DELAYED")

KUI_AuraTracker:SetScript("OnEvent", function(self, event, arg1, arg2, arg3)
    if not IsProgressBarsEnabled() then
        HideAllProgressBars()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        if ns.BuildInGameProgressBars then ns.BuildInGameProgressBars() end
        FullAuraScan("player"); FullAuraScan("target"); FullAuraScan("pet"); FullAuraScan("focus")
        SnapshotTrackedItemCounts(false)
        if ns.PB and ns.PB.RefreshAll then
            ns.PB:RefreshAll()
        end
    elseif event == "UNIT_AURA" then
        if arg1 == "player" or arg1 == "target" or arg1 == "focus" or arg1 == "pet" then
            OnUnitAuraPayload(arg1)
            if ns.PB and ns.PB.RefreshUnit then
                ns.PB:RefreshUnit(arg1)
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then FullAuraScan("target")
        if ns.PB and ns.PB.RefreshUnit then
            ns.PB:RefreshUnit("target")
        end
    elseif event == "PLAYER_FOCUS_CHANGED"  then FullAuraScan("focus")
        if ns.PB and ns.PB.RefreshUnit then
            ns.PB:RefreshUnit("focus")
        end
    elseif event == "UNIT_PET" then
        if arg1 == "player" then
            FullAuraScan("pet")
            if ns.PB and ns.PB.RefreshUnit then
                ns.PB:RefreshUnit("pet")
            end
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        SnapshotTrackedItemCounts(true)
        local cdmNS = _G.KUI_CDM_NS
        if cdmNS and type(cdmNS.RefreshSyntheticItemCooldownsFromBags) == "function" then
            cdmNS.RefreshSyntheticItemCooldownsFromBags()
        end
        if ns.PB and ns.PB.RefreshAll then
            ns.PB:RefreshAll()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = arg1, arg2, arg3
        if unit == "player" and spellID then 
            local now = GetNow()
            MarkTrackedItemUseBySpell(spellID)
            if not CastCache[spellID] or (now - CastCache[spellID]) > 0.5 then
                CastCache[spellID] = now 
            end
            if ns.PB and ns.PB.RefreshCast then
                ns.PB:RefreshCast(spellID)
            end
            local trackedFrames = TrackedBuffFrameIndex[spellID]
            if trackedFrames then
                TrackedBuffTimers[spellID] = {
                    startTime = now,
                    spellID = spellID,
                }
                for i = 1, #trackedFrames do
                    StartTrackedBuffFrame(trackedFrames[i], spellID, now)
                end
            end
        end
    end
end)

function ns.BuildInGameProgressBars()
    local p = KT.db and KT.db.profile and KT.db.profile.progressBars
    if not p then return end
    if not IsProgressBarsEnabled() then
        HideAllProgressBars()
        return
    end
    
    local lists = {
        { profile=p.customAuraBars,  prefix="AURA_", defX=350  },
    }
    
    local elementsToRegister = {}
    for _, f in pairs(KUI_InGameBars) do f._isActiveNow = false end

    wipe(AuraFrameIndex.player); wipe(AuraFrameIndex.target); wipe(AuraFrameIndex.pet); wipe(AuraFrameIndex.focus)
    wipe(CastFrameIndex)
    wipe(TrackedBuffFrameIndex)
    wipe(ActiveFrames)
    wipe(ActiveIndex)
    
    for _, listData in ipairs(lists) do
        local profile = listData.profile
        if profile and profile.bars then
            for i, cfg in ipairs(profile.bars) do
                local barKey = listData.prefix .. i
                local f = KUI_InGameBars[barKey]
                if not f then
                    f = CreateFrame("Frame", "KUI_"..barKey, UIParent)
                    f.key = barKey
                    KUI_InGameBars[barKey] = f
                    f.bg        = f:CreateTexture(nil, "BACKGROUND")
                    f.statusBar = CreateFrame("StatusBar", nil, f)
                    f.spark     = f.statusBar:CreateTexture(nil, "OVERLAY")
                    f.iconTex   = f:CreateTexture(nil, "ARTWORK")
                    f.iconBorder= CreateFrame("Frame", nil, f, "BackdropTemplate")
                    f.nameText  = f.statusBar:CreateFontString(nil, "OVERLAY")
                    f.timerText = f.statusBar:CreateFontString(nil, "OVERLAY")
                    f.border    = CreateFrame("Frame", nil, f, "BackdropTemplate")
                end
                
                f.cfg = cfg; f._isActiveNow = true

                local triggerType = cfg.triggerType or "spellcast"
                if listData.prefix == "TBB_" then
                    triggerType = "trackedbuff"
                    cfg.triggerType = "trackedbuff"
                    cfg.unit = "player"
                end
                local cleanSpellID = IsSafeNum(cfg.spellID, 0)
                local unitKey = cfg.unit or "player"
                f._pbSpellID = cleanSpellID
                f._pbTriggerType = triggerType
                f._pbUnit = unitKey
                f._pbIsTrackedBuffBar = (listData.prefix == "TBB_")

                if cleanSpellID and cleanSpellID > 0 then
                    if triggerType == "trackedbuff" then
                        TrackedBuffFrameIndex[cleanSpellID] = TrackedBuffFrameIndex[cleanSpellID] or {}
                        table.insert(TrackedBuffFrameIndex[cleanSpellID], f)
                    elseif triggerType == "spellcast" then
                        CastFrameIndex[cleanSpellID] = CastFrameIndex[cleanSpellID] or {}
                        table.insert(CastFrameIndex[cleanSpellID], f)
                    else
                        local unit = f._pbUnit
                        AuraFrameIndex[unit] = AuraFrameIndex[unit] or {}
                        AuraFrameIndex[unit][cleanSpellID] = AuraFrameIndex[unit][cleanSpellID] or {}
                        table.insert(AuraFrameIndex[unit][cleanSpellID], f)
                    end
                end
                local w, h = cfg.width or 270, cfg.height or 24
                f:SetSize(w, h)
                f.bg:SetAllPoints()
                f.bg:SetColorTexture(cfg.bgR or 0, cfg.bgG or 0, cfg.bgB or 0, cfg.bgA or 0.4)
                
                f.statusBar:SetAllPoints()
                local tex = GetProgressBarTexturePath(cfg)
                f.statusBar:SetStatusBarTexture(tex)
                f.statusBar:SetStatusBarColor(cfg.fillR or 1, cfg.fillG or 0, cfg.fillB or 0, cfg.fillA or 1)
                
                if cfg.showSpark then
                    f.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark"); f.spark:SetBlendMode("ADD")
                    f.spark:SetSize(16, h*2); f.spark:SetPoint("CENTER", f.statusBar:GetStatusBarTexture(), "RIGHT", 0, 0)
                else f.spark:Hide() end
                
                local defIcon = 134400
                local dName = cfg.name or "Aura Name"
                local sid
                
                if type(cfg.spellID) == "string" then
                    for id in string.gmatch(cfg.spellID, "%d+") do sid = tonumber(id); break end
                else 
                    sid = tonumber(cfg.spellID) 
                end

                if sid and sid > 0 then
                    defIcon = C_Spell.GetSpellTexture(sid) or 134400
                    local info = C_Spell.GetSpellInfo(sid)
                    if info and info.name then dName = info.name end
                elseif sid and sid < 0 then
                    defIcon = C_Item.GetItemIconByID(-sid) or 134400
                    local iName = C_Item.GetItemNameByID(-sid)
                    if iName then dName = iName end
                end

                f._cachedName = dName

                if cfg.iconDisplay and cfg.iconDisplay ~= "none" then
                    local iSz = cfg.iconSize or 24
                    f.iconTex:SetSize(iSz, iSz); f.iconTex:ClearAllPoints()
                    local ix, iy = cfg.iconX or 0, cfg.iconY or 0
                    if cfg.iconDisplay == "left" then f.iconTex:SetPoint("RIGHT", f, "LEFT", -2+ix, iy)
                    else f.iconTex:SetPoint("LEFT", f, "RIGHT", 2+ix, iy) end
                    
                    f.iconTex:SetTexture(defIcon); f.iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    
                    if cfg.iconBorderSize and cfg.iconBorderSize > 0 then
                        f.iconBorder:SetAllPoints(f.iconTex)
                        f.iconBorder:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=cfg.iconBorderSize})
                        f.iconBorder:SetBackdropBorderColor(cfg.borderR or 0, cfg.borderG or 0, cfg.borderB or 0, 1)
                        f.iconBorder:Show()
                    else f.iconBorder:Hide() end
                    f.iconTex:Show()
                else f.iconTex:Hide(); f.iconBorder:Hide() end
                
                f.nameText:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", cfg.nameSize or 11, "OUTLINE")
                f.nameText:ClearAllPoints(); f.nameText:SetPoint("LEFT", 4+(cfg.nameX or 0), cfg.nameY or 0)
                
                f.timerText:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", cfg.timerSize or 11, "OUTLINE")
                f.timerText:ClearAllPoints(); f.timerText:SetPoint("RIGHT", -4+(cfg.timerX or 0), cfg.timerY or 0)
                
                if cfg.borderSize and cfg.borderSize > 0 then
                    f.border:SetAllPoints()
                    f.border:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8x8", edgeSize=cfg.borderSize})
                    f.border:SetBackdropBorderColor(cfg.borderR or 0, cfg.borderG or 0, cfg.borderB or 0, 1)
                    f.border:Show()
                else f.border:Hide() end
                
                f:SetAlpha(cfg.opacity or 1.0)
                f:ClearAllPoints()
                if cfg.position and cfg.position.pt then
                    f:SetPoint(cfg.position.pt, UIParent, cfg.position.rp or cfg.position.pt, cfg.position.x, cfg.position.y)
                else f:SetPoint("CENTER", UIParent, "CENTER", listData.defX, 150-(i*35)) end
                f:Hide()
                local defaultX = listData.defX
                local defaultY = 150 - (i * 35)

                table.insert(elementsToRegister, {
                    key = "PROGBAR_"..barKey,
                    label = cfg.name or ("Bar "..i),
                    getFrame = function() return KUI_InGameBars[barKey] end,
                    getSize  = function() return cfg.width or 270, cfg.height or 24 end,
                    getEditableSize = function()
                        return cfg.width or 270, cfg.height or 24
                    end,
                    loadPosition = function()
                        if cfg.position and cfg.position.pt then
                            return {
                                point = cfg.position.pt,
                                relativePoint = cfg.position.rp or cfg.position.pt,
                                x = cfg.position.x or 0,
                                y = cfg.position.y or 0,
                            }
                        end
                        return {
                            point = "CENTER",
                            relativePoint = "CENTER",
                            x = defaultX,
                            y = defaultY,
                        }
                    end,
                    setEditableSize = function(_, width, height)
                        cfg.width = math.max(50, math.floor((tonumber(width) or cfg.width or 270) + 0.5))
                        cfg.height = math.max(8, math.floor((tonumber(height) or cfg.height or 24) + 0.5))

                        if ns.BuildInGameProgressBars then
                            ns.BuildInGameProgressBars()
                        end

                        local frame = KUI_InGameBars[barKey]
                        if frame and ns.PB and ns.PB.RefreshFrame then
                            ns.PB:RefreshFrame(frame)
                        end
                    end,
                    savePosition = function(_, pt, rp, x, y) cfg.position = {pt=pt, rp=rp, x=x, y=y} end,
                    applyPosition = function()
                        local frame = KUI_InGameBars[barKey]
                        if not frame then
                            return
                        end

                        frame:ClearAllPoints()
                        if cfg.position and cfg.position.pt then
                            frame:SetPoint(cfg.position.pt, UIParent, cfg.position.rp or cfg.position.pt, cfg.position.x or 0, cfg.position.y or 0)
                        else
                            frame:SetPoint("CENTER", UIParent, "CENTER", defaultX, defaultY)
                        end
                    end,
                })
            end
        end
    end
    if KT.RegisterMovableElements then KT:RegisterMovableElements(elementsToRegister) end

    FullAuraScan("player")
    FullAuraScan("target")
    FullAuraScan("pet")
    FullAuraScan("focus")
    SnapshotTrackedItemCounts(false)

    if ns.PB and ns.PB.RefreshAll then
        ns.PB:RefreshAll()
    end
end

local ENGINE_INTERVAL_ACTIVE = 0.10 -- 10fps is enough for countdown bars, avoids per-frame OnUpdate
local ENGINE_INTERVAL_IDLE   = 1.00 -- idle cadence when nothing is active (keeps unlock mode responsive)
local _engineTicker = nil
local _engineInterval = nil
local _engineLastAt = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()

local function ActivateFrame(f)
    if ActiveIndex[f] then
        return
    end
    ActiveFrames[#ActiveFrames + 1] = f
    ActiveIndex[f] = #ActiveFrames
end

local function DeactivateFrame(f)
    local idx = ActiveIndex[f]
    if not idx then
        return
    end
    local last = ActiveFrames[#ActiveFrames]
    ActiveFrames[idx] = last
    ActiveFrames[#ActiveFrames] = nil
    ActiveIndex[f] = nil
    if last then
        ActiveIndex[last] = idx
    end
end

local function SetEngineInterval(interval, tickFn)
    interval = tonumber(interval) or ENGINE_INTERVAL_ACTIVE
    if _engineTicker and _engineInterval == interval then
        return
    end
    if _engineTicker and _engineTicker.Cancel then
        _engineTicker:Cancel()
        _engineTicker = nil
    end
    _engineInterval = interval
    _engineLastAt = GetNow()
    _engineTicker = C_Timer.NewTicker(interval, tickFn)
end

StopTrackedBuffFrame = function(f)
    if not f then
        return
    end
    f:SetScript("OnUpdate", nil)
    f._trackedBuffActive = nil
    f._realDuration = 0
    if f.IsShown and f:IsShown() and not (ns.IsUnlocked and ns.IsUnlocked()) then
        f:Hide()
    end
    DeactivateFrame(f)
end

StartTrackedBuffFrame = function(f, spellID, startTime)
    if not f or not f.cfg then
        return
    end

    StopTrackedBuffFrame(f)

    local cfg = f.cfg
    local duration = ResolveProgressBarDuration(cfg, spellID, 10)
    if duration <= 0 then
        duration = 10
    end

    local startedAt = IsSafeNum(startTime, 0)
    if startedAt <= 0 then
        startedAt = GetNow()
    end

    f._trackedBuffActive = {
        spellID = spellID,
        startTime = startedAt,
        duration = duration,
        elapsed = 0,
    }

    local function UpdateTrackedBuffVisual()
        if not f or not f.cfg or not f._trackedBuffActive then
            StopTrackedBuffFrame(f)
            return
        end

        local active = f._trackedBuffActive
        local remain = active.duration - (GetNow() - active.startTime)
        local nameStr = f._cachedName

        if remain <= 0 then
            StopTrackedBuffFrame(f)
            return
        end

        if not f:IsShown() then
            f:Show()
        end

        if active.duration <= 0 then
            active.duration = 1
        end
        f.statusBar:SetMinMaxValues(0, active.duration)
        f.statusBar:SetValue(remain)

        if cfg.showTimer then
            f.timerText:SetText(string.format("%.1f", remain))
            f.timerText:Show()
        end
        if cfg.showName ~= false then
            f.nameText:SetText(nameStr)
            f.nameText:Show()
        end
    end

    UpdateTrackedBuffVisual()
    f:SetScript("OnUpdate", function(self, elapsed)
        local active = self._trackedBuffActive
        if not active then
            self:SetScript("OnUpdate", nil)
            return
        end
        active.elapsed = (active.elapsed or 0) + (elapsed or 0)
        if active.elapsed < 0.05 then
            return
        end
        active.elapsed = 0
        UpdateTrackedBuffVisual()
    end)
end

local function UpdateFrameState(f, now, elapsed, unlocked)
    if not f or not f._isActiveNow then
        if f and f.IsShown and f:IsShown() then
            f:Hide()
        end
        if f then
            StopTrackedBuffFrame(f)
            f._realDuration = 0
            f._lastAuraData = nil
            f._hideGrace = 0
            DeactivateFrame(f)
        end
        return false
    end

    local cfg = f.cfg
    if unlocked then
        if not f:IsShown() then
            f:Show()
        end
        f.statusBar:SetMinMaxValues(0, 1)
        f.statusBar:SetValue(0.65)
        if cfg.showTimer then
            f.timerText:SetText("12.5")
            f.timerText:Show()
        end
        if cfg.showName ~= false then
            f.nameText:SetText(f._cachedName)
            f.nameText:Show()
        end
        ActivateFrame(f)
        return true
    end

    -- =========================================================================
    -- Workaround: Forzar anclaje para prevenir movimientos por otros addons
    -- Esto soluciona que la barra de casteo mueva las barras de progreso.
    -- =========================================================================
    if not unlocked and cfg.position and cfg.position.pt then
        local _, relativeTo = f:GetPoint()
        if not relativeTo or (relativeTo.GetName and relativeTo:GetName() ~= "UIParent") then
            f:ClearAllPoints()
            f:SetPoint(cfg.position.pt, UIParent, cfg.position.rp or cfg.position.pt, cfg.position.x, cfg.position.y)
        end
    end

    local targetUnit   = cfg.unit or "player"
    local cleanSpellID = IsSafeNum(cfg.spellID, 0)
    local triggerType  = cfg.triggerType or "spellcast"
    local cachedAura, isSpellTimer, timerStart = nil, false, 0
    local spellTimerDuration = nil

    if triggerType == "trackedbuff" then
        if f._trackedBuffActive then
            if not f:IsShown() then
                f:Show()
            end
            return true
        end
        if f:IsShown() then
            f:Hide()
        end
        DeactivateFrame(f)
        return false
    elseif triggerType == "spellcast" then
        if cleanSpellID < 0 then
            local itemID = -cleanSpellID
            local itemStart, itemDuration, itemEnable = GetCDMItemCooldownInfo(itemID)
            local duration = IsSafeNum(itemDuration, 0)
            local enabled = (itemEnable == 1 or itemEnable == true)
            local recentUseAt = IsSafeNum(RecentItemUse[itemID], 0)
            local hasRecentExactUse = recentUseAt > 0 and (now - recentUseAt) <= 2.5
            local existingStart = IsSafeNum(f._trackedItemCooldownStart, 0)
            local existingDuration = IsSafeNum(f._trackedItemCooldownDuration, 0)
            local keepExisting = existingStart > 0 and existingDuration > 0 and (now - existingStart) < existingDuration

            if enabled and duration > 1.5 and (hasRecentExactUse or keepExisting) then
                timerStart = IsSafeNum(itemStart, 0)
                if timerStart <= 0 then
                    timerStart = now
                end
                f._trackedItemCooldownStart = timerStart
                f._trackedItemCooldownDuration = duration
                spellTimerDuration = duration
                isSpellTimer = (now - timerStart) < duration
            else
                f._trackedItemCooldownStart = nil
                f._trackedItemCooldownDuration = nil
            end
        else
            timerStart = CastCache[cleanSpellID]
            if timerStart then
                local dur = ResolveProgressBarDuration(cfg, cleanSpellID, 10)
                if (now - timerStart) < dur then
                    spellTimerDuration = dur
                    isSpellTimer = true
                end
            end
        end
    else
        if f._pbIsTrackedBuffBar and targetUnit == "player" then
            cachedAura = ResolveTrackedBuffAuraLive(cleanSpellID, cfg)
        else
            cachedAura = ResolveAuraCacheEntry(targetUnit, cleanSpellID, cfg)
        end
    end

    if cachedAura then
        local expSafe = IsSafeNum(cachedAura.expirationTime, 0)
        local durSafe = IsSafeNum(cachedAura.duration, 0)
        if expSafe <= 0 or durSafe <= 0 then
            cachedAura = nil
            f._lastAuraData = nil
            f._hideGrace = 0
        end
    end

    if cachedAura then
        f._lastAuraData = cachedAura
        f._hideGrace = 0
    elseif f._lastAuraData then
        f._hideGrace = (f._hideGrace or 0) + (elapsed or 0)
        if f._hideGrace < 0.5 then
            cachedAura = f._lastAuraData
        else
            f._lastAuraData = nil
        end
    end

    if isSpellTimer or cachedAura then
        if not f:IsShown() then
            f:Show()
        end

        local remain, duration, maxBar
        if isSpellTimer then
            duration = spellTimerDuration or ResolveProgressBarDuration(cfg, cleanSpellID, 10)
            remain = duration - (now - timerStart)
            maxBar = duration
        else
            local expTime = cachedAura.expirationTime
            remain = expTime > 0 and (expTime - now) or 0
            duration = cachedAura.duration
            if cfg.useCustomDuration and cfg.duration and cfg.duration > 0 then
                duration = cfg.duration
            end

            local rDur = f._realDuration or 0
            if remain > rDur then
                f._realDuration = (remain > 0) and remain or duration
                rDur = f._realDuration
            end
            maxBar = (rDur > 0) and rDur or duration
        end

        if remain <= 0 and (not cachedAura or cachedAura.expirationTime > 0) then
            f:Hide()
            f._realDuration = 0
            DeactivateFrame(f)
            return false
        end

        if maxBar <= 0 then
            maxBar = 1
        end
        f.statusBar:SetMinMaxValues(0, maxBar)
        f.statusBar:SetValue(remain)

        if cfg.showTimer then
            f.timerText:SetText(string.format("%.1f", remain))
            f.timerText:Show()
        end
        if cfg.showName ~= false then
            local nameStr = (cachedAura and cachedAura.name ~= "") and cachedAura.name or f._cachedName
            local stackCount = cachedAura and (cachedAura.stacks or cachedAura.applications)
            if type(stackCount) == "number" and stackCount > 1 then
                nameStr = nameStr .. " (" .. stackCount .. ")"
            end
            f.nameText:SetText(nameStr)
            f.nameText:Show()
        end

        ActivateFrame(f)
        return true
    end

    if f:IsShown() then
        f:Hide()
    end
    f._realDuration = 0
    DeactivateFrame(f)
    return false
end

local function EngineTick()
    local profiler = KT and KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("core.progressBars.engine")
    if not IsProgressBarsEnabled() then
        HideAllProgressBars()
        SetEngineInterval(ENGINE_INTERVAL_IDLE, EngineTick)
        if profileStarted then profiler:End("core.progressBars.engine", profileStarted) end
        return
    end

    local now = GetNow()
    local elapsed = now - (_engineLastAt or now)
    _engineLastAt = now

    local unlocked = ns.IsUnlocked and ns.IsUnlocked()

    if unlocked then
        for _, f in pairs(KUI_InGameBars) do
            UpdateFrameState(f, now, elapsed, true)
        end
    else
        for i = #ActiveFrames, 1, -1 do
            local f = ActiveFrames[i]
            UpdateFrameState(f, now, elapsed, false)
        end
    end

    local wantInterval = (unlocked or #ActiveFrames > 0) and ENGINE_INTERVAL_ACTIVE or ENGINE_INTERVAL_IDLE
    SetEngineInterval(wantInterval, EngineTick)
    if profileStarted then profiler:End("core.progressBars.engine", profileStarted) end
end

local function StartEngine()
    SetEngineInterval(ENGINE_INTERVAL_IDLE, EngineTick)
end

function PB:RefreshFrame(frame)
    if not IsProgressBarsEnabled() then
        HideAllProgressBars()
        return
    end

    local unlocked = ns.IsUnlocked and ns.IsUnlocked()
    local now = GetNow()
    UpdateFrameState(frame, now, 0, unlocked)
    local wantInterval = (unlocked or #ActiveFrames > 0) and ENGINE_INTERVAL_ACTIVE or ENGINE_INTERVAL_IDLE
    SetEngineInterval(wantInterval, EngineTick)
end

function PB:RefreshUnit(unit)
    if not IsProgressBarsEnabled() then
        HideAllProgressBars()
        return
    end

    local bySpell = AuraFrameIndex[unit]
    if not bySpell then
        return
    end
    for _, frames in pairs(bySpell) do
        for i = 1, #frames do
            self:RefreshFrame(frames[i])
        end
    end
end

function PB:RefreshCast(spellID)
    if not IsProgressBarsEnabled() then
        HideAllProgressBars()
        return
    end

    local frames = CastFrameIndex[spellID]
    if not frames then
        return
    end
    for i = 1, #frames do
        self:RefreshFrame(frames[i])
    end
end

function PB:RefreshTrackedBuff(spellID)
    if not IsProgressBarsEnabled() then
        HideAllProgressBars()
        return
    end

    local frames = TrackedBuffFrameIndex[spellID]
    if not frames then
        return
    end
    for i = 1, #frames do
        self:RefreshFrame(frames[i])
    end
end

function PB:RefreshAll()
    if not IsProgressBarsEnabled() then
        HideAllProgressBars()
        return
    end

    self:RefreshUnit("player")
    self:RefreshUnit("target")
    self:RefreshUnit("pet")
    self:RefreshUnit("focus")
    for spellID in pairs(TrackedBuffFrameIndex) do
        self:RefreshTrackedBuff(spellID)
    end
end

StartEngine()
