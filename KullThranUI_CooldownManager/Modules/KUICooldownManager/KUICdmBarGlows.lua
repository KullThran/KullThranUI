--------------------------------------------------------------------------------
--  KUI_BarGlows.lua
--  Bar Glows: Overlay system that reads CDM buff bars and overlays glows
--  on action buttons for KullThranUI.
--------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

-- Forward references from main CDM file (set during init)
local KUI_CDM, GetTargetButton, GetActionButton, GetSortedSlots, StartNativeGlow, StopNativeGlow

-- Runtime caches: bar-glow polling must only read state, never rebuild spell
-- aliases or query the aura API for every icon on every 0.1s tick.
local cachedBarGlows
local glowAuraStateCache = {}
local glowAliasCache = {}
local targetIdentifierCache = {}

function ns.InitBarGlows(kui_cdm, getTarget, getAction, getSorted, startGlow, stopGlow)
    KUI_CDM = kui_cdm
    GetTargetButton = getTarget
    GetActionButton = getAction
    GetSortedSlots = getSorted
    StartNativeGlow = startGlow
    StopNativeGlow = stopGlow
    if ns.RequestBarGlowUpdate then ns.RequestBarGlowUpdate() end
end

-------------------------------------------------------------------------------
--  GetAllCDMBuffSpells
-------------------------------------------------------------------------------
function ns.GetAllCDMBuffSpells()
    if not KUI_CDM or not KUI_CDM.db then return {}, {} end
    local p = KUI_CDM.db.profile
    if not p or not p.cdmBars or not p.cdmBars.bars then return {}, {} end

    local trackedSet = {}
    local trackedOrder = {}

    for _, bar in ipairs(p.cdmBars.bars) do
        local isBuff = (bar.barType == "buffs") or (bar.key == "buffs")
        if isBuff then
            local spells = ns.GetCDMSpellsForBar(bar.key)
            if spells then
                for _, sp in ipairs(spells) do
                    if sp.isKnown and sp.spellID and sp.spellID > 0 and not trackedSet[sp.spellID] then
                        local entry = {
                            spellID = sp.spellID,
                            cdID = sp.cdID,
                            name = sp.name,
                            icon = sp.icon,
                            barKey = bar.key,
                            barName = bar.name or bar.key,
                            isDisplayed = sp.isDisplayed,
                        }
                        trackedSet[sp.spellID] = entry
                        trackedOrder[#trackedOrder + 1] = entry
                    end
                end
            end
        end
    end

    local tracked, untracked = {}, {}
    for _, entry in ipairs(trackedOrder) do
        if entry.isDisplayed then
            tracked[#tracked + 1] = entry
        else
            untracked[#untracked + 1] = entry
        end
    end

    return tracked, untracked
end

function ns.GetBarGlows()
    if not KUI_CDM or not KUI_CDM.db then return { enabled = true, selectedBar = 1, assignments = {} } end
    local p = KUI_CDM.db.profile
    if not p.barGlows then
        p.barGlows = {
            enabled = true, glowStyle = "blizzard", selectedBar = 1, selectedButton = nil,
            glowColor = { r = 1, g = 0.82, b = 0.1 }, classColor = false,
            procGlowStyle = "blizzard", selectedAssignment = 1, selectedSpellIdentifier = nil,
            assignments = {}, spellOverrides = {},
        }
    end
    if p.barGlows.glowStyle == nil then p.barGlows.glowStyle = "blizzard" end
    if p.barGlows.procGlowStyle == nil then p.barGlows.procGlowStyle = "blizzard" end
    if not p.barGlows.glowColor then p.barGlows.glowColor = { r = 1, g = 0.82, b = 0.1 } end
    if p.barGlows.classColor == nil then p.barGlows.classColor = false end
    if type(p.barGlows.assignments) ~= "table" then p.barGlows.assignments = {} end
    if type(p.barGlows.spellOverrides) ~= "table" then p.barGlows.spellOverrides = {} end

    -- Migration: older builds stored glowStyle as the dropdown index (1..4),
    -- but StartNativeGlow consumes legacy numeric codes (6/1/2/0).
    if not p.barGlows._glowStyleFixV2 then
        for _, list in pairs(p.barGlows.assignments) do
            if type(list) == "table" then
                for _, entry in ipairs(list) do
                    local s = tonumber(entry and entry.glowStyle)
                    if s == 1 then entry.glowStyle = 6
                    elseif s == 2 then entry.glowStyle = 1
                    elseif s == 3 then entry.glowStyle = 2
                    elseif s == 4 then entry.glowStyle = 0
                    end
                end
            end
        end
        p.barGlows._glowStyleFixV2 = true
    end

    -- Migration: older defaults effectively behaved like AutoCast Shine.
    -- Normalize those legacy defaults to Blizzard proc glow once.
    if not p.barGlows._glowDefaultFixV3 then
        if p.barGlows.glowStyle == nil or p.barGlows.glowStyle == "autocast" then
            p.barGlows.glowStyle = "blizzard"
        end
        if p.barGlows.procGlowStyle == nil or p.barGlows.procGlowStyle == "autocast" then
            p.barGlows.procGlowStyle = "blizzard"
        end
        for _, list in pairs(p.barGlows.assignments) do
            if type(list) == "table" then
                for _, entry in ipairs(list) do
                    if entry then
                        if entry.glowStyle == "autocast" then
                            entry.glowStyle = 6
                        elseif tonumber(entry.glowStyle) == 1 then
                            entry.glowStyle = 6
                        end
                    end
                end
            end
        end
        p.barGlows._glowDefaultFixV3 = true
    end
    cachedBarGlows = p.barGlows
    return p.barGlows
end

local function GetSpellOverrideKey(identifier)
    if identifier == nil then
        return nil
    end
    return tostring(identifier)
end
ns.GetBarGlowSpellOverrideKey = GetSpellOverrideKey

function ns.GetBarGlowSpellOverride(identifier, create)
    local key = GetSpellOverrideKey(identifier)
    if not key then
        return nil
    end

    local bg = cachedBarGlows or ns.GetBarGlows()
    bg.spellOverrides = bg.spellOverrides or {}
    local entry = bg.spellOverrides[key]
    if not entry and create then
        entry = {
            useGlobalGlow = true,
            useGlobalColor = true,
            useGlobalSwipeColor = true,
        }
        bg.spellOverrides[key] = entry
    end
    if entry and entry.useGlobalSwipeColor == nil then
        entry.useGlobalSwipeColor = true
    end
    return entry
end

function ns.GetButtonAssignments(barIdx, btnIdx)
    local bg = ns.GetBarGlows()
    local key = barIdx .. "_" .. btnIdx
    return bg.assignments[key]
end

function ns.IsSpellAuraActive(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then return false end
    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    return ok and aura ~= nil
end

-------------------------------------------------------------------------------
--  Bar Glows: Overlay System
-------------------------------------------------------------------------------
local overlayFrames = {}
local hasActiveOverlays = false
local lastSourceStates = {}
local overlayEventFrame

local HIDDEN_ALPHA = 0.001
local PACK_SPACING = 6

local function SaveOrigPoints(slot)
    if slot.__KUIOrigPoints then return end
    local n = slot:GetNumPoints()
    if not n or n == 0 then return end
    local pts = {}
    for i = 1, n do pts[i] = { slot:GetPoint(i) } end
    slot.__KUIOrigPoints = pts
end

local function RestoreOrigPoints(slot)
    local pts = slot.__KUIOrigPoints
    if not pts then return end
    slot:ClearAllPoints()
    for _, p in ipairs(pts) do slot:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
end

local function ApplyPerSlotAlpha(slots)
    if not slots then return end
    for _, slot in ipairs(slots) do
        if slot.__KUIHideFromCDM then
            if slot.__KUIPrevAlpha == nil then
                slot.__KUIPrevAlpha = slot:GetAlpha() or 1
                slot:SetAlpha(HIDDEN_ALPHA)
            end
        else
            if slot.__KUIPrevAlpha ~= nil then
                slot:SetAlpha(slot.__KUIPrevAlpha)
                slot.__KUIPrevAlpha = nil
            end
        end
    end
end

local lastPackLayout = {}
local shownBuffer = {}

local function PackVisibleSlots()
    local root = _G.BuffIconCooldownViewer
    if not root then return end
    local slots = GetSortedSlots()
    if not slots then return end

    -- Never mutate Blizzard's buff-row layout during a glow refresh unless
    -- an actual hide-from-CDM flag is present.
    local hiddenCount = 0
    for _, slot in ipairs(slots) do
        if slot and slot.__KUIHideFromCDM then hiddenCount = hiddenCount + 1 end
    end
    if hiddenCount == 0 then
        if lastPackLayout.count and lastPackLayout.count > 0 then
            for _, slot in ipairs(slots) do RestoreOrigPoints(slot) end
        end
        for key in pairs(lastPackLayout) do lastPackLayout[key] = nil end
        return
    end

    local count = 0
    for _, slot in ipairs(slots) do
        if slot and slot.IsShown and slot:IsShown() and not slot.__KUIHideFromCDM then
            count = count + 1
            shownBuffer[count] = slot
        end
    end
    for i = count + 1, #shownBuffer do shownBuffer[i] = nil end
    if count == 0 then lastPackLayout.count = 0; return end

    local iconSize = shownBuffer[1]:GetWidth() or 35
    if iconSize < 5 then iconSize = 35 end

    local layoutChanged = (count ~= lastPackLayout.count) or (iconSize ~= lastPackLayout.iconSize)
    if not layoutChanged then
        for idx = 1, count do
            if shownBuffer[idx] ~= lastPackLayout[idx] then layoutChanged = true; break end
        end
    end
    if not layoutChanged then return end

    for _, slot in ipairs(slots) do SaveOrigPoints(slot) end
    for _, slot in ipairs(slots) do RestoreOrigPoints(slot) end

    local totalW = (count * iconSize) + ((count - 1) * PACK_SPACING)
    local startX = -(totalW / 2) + (iconSize / 2)
    for idx = 1, count do
        local slot = shownBuffer[idx]
        slot:ClearAllPoints()
        slot:SetPoint("CENTER", root, "CENTER", startX + (idx - 1) * (iconSize + PACK_SPACING), 0)
        lastPackLayout[idx] = slot
    end
    for i = count + 1, (lastPackLayout.count or 0) do lastPackLayout[i] = nil end
    lastPackLayout.count = count
    lastPackLayout.iconSize = iconSize
end

local function ApplyPerSlotHidingAndPack(force)
    local slots = GetSortedSlots(force)
    if not slots then return end
    ApplyPerSlotAlpha(slots)
    PackVisibleSlots()
end

local function ApplyPerSlotHidingAndPackSoon()
    lastPackLayout.count = nil
    ApplyPerSlotHidingAndPack(true)
    C_Timer.After(0.2, function()
        lastPackLayout.count = nil
        ApplyPerSlotHidingAndPack(true)
    end)
end
ns.ApplyPerSlotHidingAndPackSoon = ApplyPerSlotHidingAndPackSoon

local hookedSlots = {}
local UpdateOverlayVisuals

local overlayVisualsPending = false
local overlayVisualsTimer
local function DeferredOverlayVisuals()
    overlayVisualsPending = false
    overlayVisualsTimer = nil
    if UpdateOverlayVisuals then UpdateOverlayVisuals() end
end

local function QueueOverlayVisuals(delay)
    if overlayVisualsPending then return end
    overlayVisualsPending = true
    delay = tonumber(delay) or 0
    if delay > 0 and C_Timer.NewTimer then
        overlayVisualsTimer = C_Timer.NewTimer(delay, DeferredOverlayVisuals)
    else
        C_Timer.After(0, DeferredOverlayVisuals)
    end
end

local slotLayoutPending = false
local function DeferredSlotLayout()
    slotLayoutPending = false
    lastPackLayout.count = nil
    ApplyPerSlotHidingAndPack(true)
    QueueOverlayVisuals()
end

local function OnSlotVisibilityChanged()
    if slotLayoutPending then return end
    slotLayoutPending = true
    C_Timer.After(0, DeferredSlotLayout)
end

local function HookCDMSlot(slot)
    if not slot or hookedSlots[slot] then return end
    hookedSlots[slot] = true
    slot:HookScript("OnShow", OnSlotVisibilityChanged)
    slot:HookScript("OnHide", OnSlotVisibilityChanged)
end

local function HookAllCDMChildren(root)
    if not root or not root.GetChildren then return end
    if root.EnumerateChildren then
        for c in root:EnumerateChildren() do
            if c and c.GetWidth and c:GetWidth() > 5 then HookCDMSlot(c) end
        end
        return
    end

    local children = { root:GetChildren() }
    for i = 1, #children do
        local c = children[i]
        if c and c.GetWidth and c:GetWidth() > 5 then HookCDMSlot(c) end
    end
end

local lastChildCount = 0
local cdmHookFrame
local function EnsureCDMHookFrame()
    if cdmHookFrame then return cdmHookFrame end
    local f = CreateFrame("Frame")
    cdmHookFrame = f
    ns.cdmHookFrame = f
    f:Hide()
    f:SetScript("OnShow", function(self)
        if self._ticker and self._ticker.Cancel then
            self._ticker:Cancel()
        end
        self._ticker = C_Timer.NewTicker(0.5, function()
            local root = _G.BuffIconCooldownViewer
            if not root or not root.GetChildren then return end
            local children = root:GetNumChildren()
            if children ~= lastChildCount then
                lastChildCount = children
                HookAllCDMChildren(root)
            else
                self:Hide()
            end
        end)
    end)
    f:SetScript("OnHide", function(self)
        if self._ticker and self._ticker.Cancel then
            self._ticker:Cancel()
        end
        self._ticker = nil
    end)
    return f
end
ns.EnsureCDMHookFrame = EnsureCDMHookFrame
EnsureCDMHookFrame()

local function GetOrCreateOverlay(actionBar, actionButtonIndex, cdmSlotIndex)
    local key = actionBar .. "_" .. actionButtonIndex .. "_" .. cdmSlotIndex
    if overlayFrames[key] then return overlayFrames[key] end
    local btn = GetTargetButton(actionBar, actionButtonIndex)
    if not btn then return nil end
    local overlay = CreateFrame("Frame", "KUI_Glow_" .. key, btn)
    overlay:SetAllPoints(btn)
    overlay:SetFrameLevel(btn:GetFrameLevel() + 10)
    overlay:Hide()
    overlayFrames[key] = overlay
    return overlay
end

local function SetupOverlays()
    if not KUI_CDM or not KUI_CDM.db then return end
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("cdm.bar_glows.setup")
    local p = KUI_CDM.db.profile
    local bg = p.barGlows
    cachedBarGlows = bg
    wipe(glowAuraStateCache)
    wipe(glowAliasCache)
    wipe(targetIdentifierCache)
    if not bg or not bg.enabled then
        cachedBarGlows = nil
        wipe(glowAuraStateCache)
        wipe(glowAliasCache)
        wipe(targetIdentifierCache)
        hasActiveOverlays = false
        if overlayEventFrame then overlayEventFrame:UnregisterAllEvents() end
        for key, overlay in pairs(overlayFrames) do
            StopNativeGlow(overlay)
            overlay:Hide()
        end
        if profileStarted then profiler:End("cdm.bar_glows.setup", profileStarted) end
        return
    end

    local activeKeys = {}
    local anyActive = false

    for assignKey, buffList in pairs(bg.assignments) do
        if buffList and #buffList > 0 then
            local barIdx, btnIdx = assignKey:match("^(%d+)_(%d+)$")
            barIdx = tonumber(barIdx)
            btnIdx = tonumber(btnIdx)
            if barIdx and btnIdx then
                for i, entry in ipairs(buffList) do
                    local key = assignKey .. "_" .. i
                    local existing = overlayFrames[key]
                    if existing then
                        local expectedBtn = GetTargetButton(barIdx, btnIdx)
                        if expectedBtn and existing:GetParent() ~= expectedBtn then
                            StopNativeGlow(existing)
                            existing:Hide()
                            existing:SetParent(nil)
                            overlayFrames[key] = nil
                            lastSourceStates[key] = nil
                        end
                    end

                    local btn = GetTargetButton(barIdx, btnIdx)
                    if btn then
                        if not overlayFrames[key] then
                            local overlay = CreateFrame("Frame", "KUI_GlowV2_" .. key, btn)
                            overlay:SetAllPoints(btn)
                            overlay:SetFrameLevel(btn:GetFrameLevel() + 10)
                            overlayFrames[key] = overlay
                        end
                        local overlay = overlayFrames[key]
                        overlay._assignEntry = entry
                        overlay:Show()
                        activeKeys[key] = true
                        anyActive = true
                    end
                end
            end
        end
    end

    for key, overlay in pairs(overlayFrames) do
        if not activeKeys[key] then
            StopNativeGlow(overlay)
            overlay:Hide()
            lastSourceStates[key] = nil
        end
    end

    hasActiveOverlays = anyActive
    if overlayEventFrame then
        overlayEventFrame:UnregisterAllEvents()
        if anyActive then
            overlayEventFrame:RegisterUnitEvent("UNIT_AURA", "player")
            overlayEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
            overlayEventFrame:RegisterEvent("SPELLS_CHANGED")
            overlayEventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
            overlayEventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
            overlayEventFrame:RegisterEvent("PLAYER_DEAD")
            overlayEventFrame:RegisterEvent("PLAYER_ALIVE")
            overlayEventFrame:RegisterEvent("PLAYER_UNGHOST")
            overlayEventFrame:RegisterEvent("UPDATE_BINDINGS")
            overlayEventFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
            overlayEventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
        end
    end
    if anyActive and UpdateOverlayVisuals then
        UpdateOverlayVisuals()
    end
    if profileStarted then profiler:End("cdm.bar_glows.setup", profileStarted) end
end

local BAR_START_SLOTS = {
    [1] = 1, [2] = 61, [3] = 49, [4] = 25, [5] = 37,
    [6] = 145, [7] = 157, [8] = 169,
}

local function GetClassGlowColor()
    local _, ct = UnitClass("player")
    if ct then
        local cc = RAID_CLASS_COLORS[ct]
        if cc then return cc.r, cc.g, cc.b end
    end
    return 1, 0.82, 0.1
end

local function GetGlowColor(entry, bg)
    local cr, cg, cb = 1, 0.82, 0.1
    if entry and entry.useGlobalColor then
        entry = nil
    end

    if entry and entry.classColor then
        cr, cg, cb = GetClassGlowColor()
    elseif entry and entry.glowColor then
        cr = entry.glowColor.r or 1
        cg = entry.glowColor.g or 0.82
        cb = entry.glowColor.b or 0.1
    elseif bg and bg.classColor then
        cr, cg, cb = GetClassGlowColor()
    elseif bg and bg.glowColor then
        cr = bg.glowColor.r or 1
        cg = bg.glowColor.g or 0.82
        cb = bg.glowColor.b or 0.1
    end
    return cr, cg, cb
end
ns.ResolveBarGlowColor = GetGlowColor

local function GetGlowStyle(entry, bg)
    if entry and entry.useGlobalGlow then
        entry = nil
    end
    local style = entry and entry.glowStyle
    if type(style) == "string" then
        local lowered = style:lower()
        if lowered == "none" then return 0 end
        if lowered == "blizzard" or lowered == "autocast" or lowered == "pixel" or lowered == "button" then
            return lowered
        end
    end

    local s = tonumber(style)
    if s == 0 then return 0 end
    if s == 6 then return "blizzard" end
    if s == 1 then return "autocast" end
    if s == 2 then return "pixel" end
    if s == 4 then return "button" end

    local global = bg and bg.glowStyle
    if global == "none" then return 0 end
    if global == "pixel" then return "pixel" end
    if global == "autocast" then return "autocast" end
    if global == "button" then return "button" end
    local resolved = "blizzard"
    if type(style) == "string" then
        local lowered = style:lower()
        if lowered == "pixel" then
            resolved = "pixel"
        elseif lowered == "autocast" then
            resolved = "autocast"
        elseif lowered == "button" then
            resolved = "button"
        elseif lowered == "blizzard" then
            resolved = "blizzard"
        end
    elseif global == "pixel" or global == "autocast" or global == "button" then
        resolved = global
    end

    if resolved ~= "blizzard" and ns.CDMHasNamedGlowSupport and not ns.CDMHasNamedGlowSupport(resolved) then
        return "blizzard"
    end
    return resolved
end
ns.ResolveBarGlowStyle = GetGlowStyle

local GetCooldownProcGlowStyle

local function IsCleanGlowSpellID(id)
    return type(id) == "number"
        and not (issecretvalue and issecretvalue(id))
        and id > 0
end

local function GetGlowSpellAliases(...)
    local argc = select('#', ...)
    local keyParts = {}
    for i = 1, argc do keyParts[i] = tostring(select(i, ...)) end
    local cacheKey = table.concat(keyParts, ':')
    local cached = glowAliasCache[cacheKey]
    if cached then return cached end

    local result, seen = {}, {}
    local function add(id)
        if not IsCleanGlowSpellID(id) or seen[id] then return end
        seen[id] = true
        result[#result + 1] = id
    end
    local pending = { ... }
    local read = 1
    while read <= #pending do
        local id = pending[read]
        read = read + 1
        if IsCleanGlowSpellID(id) then
            add(id)
            if ns.ApplyBuffSpellCorrection then
                local corrected = ns.ApplyBuffSpellCorrection(id)
                if IsCleanGlowSpellID(corrected) and not seen[corrected] then pending[#pending + 1] = corrected end
            end
            if C_Spell then
                if C_Spell.GetBaseSpell then
                    local ok, base = pcall(C_Spell.GetBaseSpell, id)
                    if ok and IsCleanGlowSpellID(base) and not seen[base] then pending[#pending + 1] = base end
                end
                if C_Spell.GetOverrideSpell then
                    local ok, override = pcall(C_Spell.GetOverrideSpell, id)
                    if ok and IsCleanGlowSpellID(override) and not seen[override] then pending[#pending + 1] = override end
                end
            end
        end
    end
    glowAliasCache[cacheKey] = result
    return result
end

local function AddActiveCDMGlow(activeMap, identifier, entry)
    if not activeMap or not entry then return end
    for _, id in ipairs(GetGlowSpellAliases(identifier)) do activeMap[id] = entry end
end

local function FindActiveCDMGlow(icon, activeMap)
    if not icon or not activeMap then return nil, nil end
    local ids = GetGlowSpellAliases(icon._baseSpellID, icon._spellID, icon._actionSpellID)
    for _, id in ipairs(ids) do
        if activeMap[id] then return activeMap[id], id end
    end
    return nil, nil
end
local function GetTargetGlowColor(identifier, triggerEntry, bg)
    local spellOverride = ns.GetBarGlowSpellOverride(identifier, false)
    if spellOverride and spellOverride.useGlobalColor ~= true then
        return GetGlowColor(spellOverride, bg)
    end
    return GetGlowColor(triggerEntry, bg)
end
ns.ResolveBarGlowColorForTarget = GetTargetGlowColor

local function GlowColorChanged(frame, r, g, b)
    if not frame then
        return true
    end
    local lr, lg, lb = frame._kuiLastGlowR, frame._kuiLastGlowG, frame._kuiLastGlowB
    return lr ~= r or lg ~= g or lb ~= b
end

local function RememberGlowColor(frame, r, g, b)
    if not frame then
        return
    end
    frame._kuiLastGlowR = r
    frame._kuiLastGlowG = g
    frame._kuiLastGlowB = b
end

local function ClearRememberedGlowColor(frame)
    if not frame then
        return
    end
    frame._kuiLastGlowR = nil
    frame._kuiLastGlowG = nil
    frame._kuiLastGlowB = nil
end

local function GetTargetGlowStyle(identifier, triggerEntry, bg, useProcStyle)
    local spellOverride = ns.GetBarGlowSpellOverride(identifier, false)
    local globalStyle = useProcStyle and (bg and bg.procGlowStyle) or (bg and bg.glowStyle)
    if spellOverride and spellOverride.useGlobalGlow ~= true then
        return GetGlowStyle(spellOverride, { glowStyle = globalStyle })
    end
    if useProcStyle then
        return GetCooldownProcGlowStyle(triggerEntry, bg)
    end
    return GetGlowStyle(triggerEntry, bg)
end
ns.ResolveBarGlowStyleForTarget = GetTargetGlowStyle

GetCooldownProcGlowStyle = function(entry, bg)
    if entry and not entry.useGlobalGlow then
        return GetGlowStyle(entry, { glowStyle = bg and bg.procGlowStyle })
    end
    local style = bg and bg.procGlowStyle
    if style == "none" then return 0 end
    if style == "pixel" then return "pixel" end
    if style == "autocast" then return "autocast" end
    if style == "button" then return "button" end
    return "blizzard"
end

local activeCDMGlowsScratch = {}
UpdateOverlayVisuals = function()
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("cdm.bar_glows.visuals")
    local actionPhaseStarted = profiler and profiler:Begin("cdm.bar_glows.actions")
    local bg = cachedBarGlows or ns.GetBarGlows()
    local activeCDMGlows = activeCDMGlowsScratch
    wipe(activeCDMGlows)
    local auraStateCache = glowAuraStateCache
    local cdmHasTarget = not ns.CDMHasUsableTarget or ns.CDMHasUsableTarget()
    local playerDead = UnitIsDeadOrGhost and UnitIsDeadOrGhost('player') or false

    -- 1. Evaluamos los brillos de las barras de acción (tu código original)
    for key, overlay in pairs(overlayFrames) do
        if overlay:IsShown() and overlay._assignEntry then
            local entry = overlay._assignEntry
            local spellID = entry.spellID
            local mode = entry.mode or "ACTIVE"

            local auraActive = false
            if spellID and spellID > 0 then
                local cachedAuraState = auraStateCache[spellID]
                if cachedAuraState == nil then
                    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
                    cachedAuraState = ok and aura ~= nil
                    auraStateCache[spellID] = cachedAuraState
                end
                auraActive = cachedAuraState
            end

            local shouldGlow = (mode == "MISSING") and not auraActive or auraActive

            local barIdx, btnIdx = key:match("^(%d+)_(%d+)")
            barIdx = tonumber(barIdx)
            if playerDead then
                shouldGlow = false
            end
            btnIdx = tonumber(btnIdx)
            local targetIdentifier = targetIdentifierCache[key]
            if targetIdentifier == false then targetIdentifier = nil end
            if targetIdentifier == nil and barIdx and btnIdx then
                local startSlot = BAR_START_SLOTS[barIdx]
                if startSlot and ns.CDM_ResolveIdentifierFromActionSlot then
                    targetIdentifier = ns.CDM_ResolveIdentifierFromActionSlot(startSlot + btnIdx - 1)
                    targetIdentifierCache[key] = targetIdentifier or false
                end
            end

            local style = GetTargetGlowStyle(targetIdentifier, entry, bg, false)
            if shouldGlow then
                if style == 0 then
                    if overlay._glowActive then
                        StopNativeGlow(overlay)
                    end
                    ClearRememberedGlowColor(overlay)
                else
                    local cr, cg, cb = GetTargetGlowColor(targetIdentifier, entry, bg)
                    if (not overlay._glowActive) or (overlay._kuiLastStyle ~= style) or GlowColorChanged(overlay, cr, cg, cb) then
                        if overlay._glowActive then
                            StopNativeGlow(overlay)
                        end
                        StartNativeGlow(overlay, style, cr, cg, cb)
                        RememberGlowColor(overlay, cr, cg, cb)
                    end
                end
            else
                if overlay._glowActive then
                    StopNativeGlow(overlay)
                end
                ClearRememberedGlowColor(overlay)
            end
            overlay._kuiLastStyle = style
            lastSourceStates[key] = shouldGlow
            
            -- Forward active action assignments to matching CDM icons.
            if shouldGlow and cdmHasTarget then
                if barIdx and btnIdx then
                    local startSlot = BAR_START_SLOTS[barIdx]
                    if startSlot then
                        if targetIdentifier then
                            -- Guardamos este hechizo en la lista de "debe brillar en el CDM"
                            AddActiveCDMGlow(activeCDMGlows, targetIdentifier, entry)
                            AddActiveCDMGlow(activeCDMGlows, entry.actionSpellID, entry)
                            AddActiveCDMGlow(activeCDMGlows, entry.spellID, entry)
                        end
                    end
                end
            end
        end
    end
    if actionPhaseStarted then profiler:End("cdm.bar_glows.actions", actionPhaseStarted) end
    local iconPhaseStarted = profiler and profiler:Begin("cdm.bar_glows.cdm_icons")
    
    -- Apply the resolved state to matching CDM icons.
    if ns.cdmBarIcons then
        for _, icons in pairs(ns.cdmBarIcons) do
            for _, icon in ipairs(icons) do
                local glowTarget = icon._customModuleGlowOverlay
                if glowTarget then
                    -- Re-assert only after a real CDM reanchor/metadata change.
                    -- SetFrameLevel on every 0.1s pass can trigger UI work even
                    -- though the icon and its overlay have not moved.
                    local glowLevel = icon:GetFrameLevel() + 17
                    if glowTarget._kuiGlowFrameLevel ~= glowLevel then
                        glowTarget:SetFrameLevel(glowLevel)
                        glowTarget._kuiGlowFrameLevel = glowLevel
                    end
                    if glowTarget._spellID ~= icon._spellID then glowTarget._spellID = icon._spellID end
                    if glowTarget._baseSpellID ~= icon._baseSpellID then glowTarget._baseSpellID = icon._baseSpellID end
                    if glowTarget._actionSpellID ~= icon._actionSpellID then glowTarget._actionSpellID = icon._actionSpellID end
                end
                local matchEntry, targetIdentifier
                if icon:IsShown() then matchEntry, targetIdentifier = FindActiveCDMGlow(icon, activeCDMGlows) end
                icon._customModuleGlowWanted = matchEntry ~= nil
                if matchEntry then
                    if not icon._customModuleGlowOverlay then
                        icon._customModuleGlowOverlay = CreateFrame("Frame", nil, icon)
                        icon._customModuleGlowOverlay:SetAllPoints(icon)
                        icon._customModuleGlowOverlay:SetFrameStrata("LOW")
                        icon._customModuleGlowOverlay:SetAlpha(0)
                        icon._customModuleGlowOverlay:SetFrameLevel(icon:GetFrameLevel() + 17)
                        icon._customModuleGlowOverlay._kuiUseSelfGlowTarget = true
                        glowTarget = icon._customModuleGlowOverlay
                    end
                    if icon._actionSpellID ~= targetIdentifier then icon._actionSpellID = targetIdentifier end
                    if glowTarget._actionSpellID ~= targetIdentifier then glowTarget._actionSpellID = targetIdentifier end
                    glowTarget._kuiGlowSource = "barglows:" .. tostring(targetIdentifier)
                    local style = GetTargetGlowStyle(targetIdentifier, matchEntry, bg, true)
                    if style == 0 then
                        if icon._customModuleGlowActive then StopNativeGlow(glowTarget) end
                        icon._customModuleGlowActive = false
                        icon._customModuleGlowStyle = nil
                        ClearRememberedGlowColor(glowTarget)
                    else
                        local cr, cg, cb = GetTargetGlowColor(targetIdentifier, matchEntry, bg)
                        if (not icon._customModuleGlowActive)
                            or icon._customModuleGlowStyle ~= style
                            or GlowColorChanged(glowTarget, cr, cg, cb) then
                            if icon._customModuleGlowActive then StopNativeGlow(glowTarget) end
                            StartNativeGlow(glowTarget, style, cr, cg, cb)
                            icon._customModuleGlowActive = true
                            icon._customModuleGlowStyle = style
                            RememberGlowColor(glowTarget, cr, cg, cb)
                        end
                    end
                elseif icon._customModuleGlowActive and glowTarget then
                    StopNativeGlow(glowTarget)
                    icon._customModuleGlowActive = false
                    icon._customModuleGlowStyle = nil
                    ClearRememberedGlowColor(glowTarget)
                elseif glowTarget then
                    ClearRememberedGlowColor(glowTarget)
                end
            end
        end
    end
    if iconPhaseStarted then profiler:End("cdm.bar_glows.cdm_icons", iconPhaseStarted) end
    if profileStarted then profiler:End("cdm.bar_glows.visuals", profileStarted) end
end

local updatePending = false
local updateTimer = nil
local function DoUpdate()
    updatePending = false
    updateTimer = nil
    SetupOverlays()
end

function ns.RefreshBarGlowRuntime(fullRefresh)
    if fullRefresh then
        SetupOverlays()
        return
    end
    QueueOverlayVisuals()
end

local function RequestUpdate()
    if type(lastSourceStates) == "table" then
        wipe(lastSourceStates)
    else
        lastSourceStates = {}
    end
    if updateTimer then updateTimer:Cancel() end
    updatePending = true
    local ensure = ns.EnsureCDMHookFrame or EnsureCDMHookFrame
    local hookFrame = ensure and ensure()
    if hookFrame and hookFrame.Show then hookFrame:Show() end
    updateTimer = C_Timer.NewTimer(0.1, DoUpdate)
end
ns.RequestBarGlowUpdate = RequestUpdate

overlayEventFrame = CreateFrame("Frame")
overlayEventFrame:SetScript("OnEvent", function(_, event)
    if event == "UNIT_AURA" then
        wipe(glowAuraStateCache)
    elseif event == "UPDATE_BINDINGS"
        or event == "ACTIONBAR_SLOT_CHANGED"
        or event == "UPDATE_BONUS_ACTIONBAR"
        or event == "PLAYER_ENTERING_WORLD"
        or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "SPELLS_CHANGED" then
        wipe(glowAuraStateCache)
        wipe(glowAliasCache)
        wipe(targetIdentifierCache)
    end
    -- Aura bursts may contain many UNIT_AURA events in one frame. One visual
    -- reconciliation within 50 ms is enough for a glow while avoiding a full
    -- assignment + CDM-icon scan for every individual aura update.
    if hasActiveOverlays then QueueOverlayVisuals(event == "UNIT_AURA" and 0.05 or 0) end
end)
