-- KUICdmBuffBars.lua
-- Tracked buff bars: one bar per followed buff, each with its own settings.
local ADDON_NAME, ns = ...
local KT = (ns and ns.KT) or _G.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local issecretvalue = issecretvalue or (C_UI and C_UI.IsSecret) or function() return false end
local function LText(text)
    local L = KT and KT.GetLocale and KT:GetLocale()
    return (L and L[text]) or text
end

-- Forward references from main CDM file (set during init)
local CDM

function ns.InitBuffBars(cdm)
    CDM = cdm
end

-- Tracked buff bars v2: each bar follows one buff and carries its own look.
-- Fill textures: "none" (flat) plus the KUI bar textures from the core catalogue
-- (KT.KUI_BAR_TEXTURES, Defaults.lua). The key is the texture's KUI name; bars saved
-- with an older key are renamed in ns.GetTrackedBuffBars.
local TBB_TEXTURE_RENAMES = KT.KUI_BAR_TEXTURE_RENAMES or {}
local TBB_TEXTURES, TBB_TEXTURE_ORDER, TBB_TEXTURE_NAMES = {}, { "none" }, { none = "None" }
for _, entry in ipairs(KT.KUI_BAR_TEXTURES or {}) do
    TBB_TEXTURE_ORDER[#TBB_TEXTURE_ORDER + 1] = entry.name
    TBB_TEXTURE_NAMES[entry.name] = entry.name
    TBB_TEXTURES[entry.name] = entry.path
end
ns.TBB_TEXTURES      = TBB_TEXTURES
ns.TBB_TEXTURE_ORDER = TBB_TEXTURE_ORDER
ns.TBB_TEXTURE_NAMES = TBB_TEXTURE_NAMES
ns.activeCdmPandemicBars = ns.activeCdmPandemicBars or {}

if not ns.cdmPandemicCurve and C_CurveUtil and Enum and Enum.LuaCurveType then
    ns.cdmPandemicCurve = C_CurveUtil.CreateCurve()
    ns.cdmPandemicCurve:SetType(Enum.LuaCurveType.Step)
    ns.cdmPandemicCurve:AddPoint(0, 1)
    ns.cdmPandemicCurve:AddPoint(0.3, 0)
end

-- Popular buffs offered in the spell picker. Fields: spellIDs (any match
-- means active), customDuration (seconds, drives the fill), icon (fileID used
-- when no spell icon resolves) and name (label in the picker and on the bar).
local TBB_POPULAR_BUFFS = {
    {
        key            = "bloodlust",
        name           = UnitFactionGroup("player") == "Horde" and "Bloodlust" or "Heroism",
        nameSpellID    = UnitFactionGroup("player") == "Horde" and 2825 or 32182,
        icon           = 132313,
        spellIDs       = { 2825, 32182, 80353, 264667, 390386, 381301, 444062, 444257 },
        customDuration = 40,
    },
    {
        key            = "lights_potential",
        name           = "Light's Potential",
        icon           = 7548911,
        spellIDs       = { 1236616, 431932 },
        customDuration = 30,
    },
    {
        key            = "potion_recklessness",
        name           = "Potion of Recklessness",
        icon           = 7548916,
        spellIDs       = { 1236994 },
        customDuration = 30,
    },
    {
        key            = "invis_potion",
        name           = "Invisibility Potion",
        icon           = 134764,
        spellIDs       = { 371125, 431424, 371133, 371134, 1236551 },
        customDuration = 18,
    },
    {
        key            = "time_spiral",
        name           = "Time Spiral",
        icon           = 4622479,
        -- No spellIDs: detected via SPELL_ACTIVATION_OVERLAY_GLOW on movement abilities
        glowBased      = true,
        glowSpellIDs   = {
            48265,   -- Death's Advance
            195072,  -- Fel Rush
            189110,  -- Infernal Strike
            1850,    -- Dash
            252216,  -- Tiger Dash
            358267,  -- Hover
            186257,  -- Aspect of the Cheetah
            1953,    -- Blink
            212653,  -- Shimmer
            361138,  -- Roll
            119085,  -- Chi Torpedo
            190784,  -- Divine Steed
            73325,   -- Leap of Faith
            2983,    -- Sprint
            192063,  -- Gust of Wind
            58875,   -- Spirit Walk
            79206,   -- Spiritwalker's Grace
            48020,   -- Demonic Circle: Teleport
            6544,    -- Heroic Leap
        },
        customDuration = 10,
    },
    -- Demonology Warlock summons: no player aura exists for them, so detection
    -- relies on the Blizzard CDM active-state / buff-viewer fallback (see
    -- KUICooldownManager.lua).
    {
        key            = "call_dreadstalkers",
        name           = "Call Dreadstalkers",
        icon           = 1378282,
        spellIDs       = { 104316 },
        customDuration = 12,
        class          = "WARLOCK",
    },
    {
        key            = "demonic_tyrant",
        name           = "Summon Demonic Tyrant",
        icon           = 2065628,
        spellIDs       = { 265187 },
        customDuration = 15,
        class          = "WARLOCK",
    },
    {
        key            = "summon_vilefiend",
        name           = "Summon Vilefiend",
        icon           = 1616211,
        spellIDs       = { 264119 },
        customDuration = 15,
        class          = "WARLOCK",
    },
    {
        key            = "grimoire_felguard",
        name           = "Grimoire: Felguard",
        icon           = 136216,
        spellIDs       = { 111898 },
        customDuration = 17,
        class          = "WARLOCK",
    },
}
-- Prefer the client's localized spell name; the names above are fallbacks.
for _, entry in ipairs(TBB_POPULAR_BUFFS) do
    local sid = entry.nameSpellID or (entry.spellIDs and entry.spellIDs[1])
    local localized = sid and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(sid)
    if type(localized) == "string" and localized ~= "" then
        entry.name = localized
    end
end
ns.TBB_POPULAR_BUFFS = TBB_POPULAR_BUFFS

-- Build a fast lookup: spellID -> popular buff entry (for UNIT_AURA detection)
local _popularSpellIDMap = {}
for _, entry in ipairs(TBB_POPULAR_BUFFS) do
    if entry.spellIDs then
        for _, sid in ipairs(entry.spellIDs) do
            _popularSpellIDMap[sid] = entry
        end
    end
end

-- Build a fast lookup: glow spellID -> popular buff key (for SPELL_ACTIVATION_OVERLAY)
local _glowSpellIDMap = {}
for _, entry in ipairs(TBB_POPULAR_BUFFS) do
    if entry.glowSpellIDs then
        for _, sid in ipairs(entry.glowSpellIDs) do
            _glowSpellIDMap[sid] = entry.key
        end
    end
end

-- Forward declaration -- actual table is populated by BuildTrackedBuffBars below
local tbbFrames
local _tbbTimerRefreshPending = false

local function RequestTBBTimerRefresh()
    if _tbbTimerRefreshPending then return end
    _tbbTimerRefreshPending = true
    C_Timer.After(0.05, function()
        _tbbTimerRefreshPending = false
        if ns.UpdateTrackedBuffBarTimers then
            ns.UpdateTrackedBuffBarTimers()
        end
    end)
end
ns.RequestTrackedBuffBarTimerRefresh = RequestTBBTimerRefresh

--- Returns true if the user has at least one tracked buff bar configured
function ns.HasBuffBars()
    if not CDM or not CDM.db then return false end
    local tbb = ns.GetTrackedBuffBars()
    return tbb and tbb.bars and #tbb.bars > 0
end

-- Listen for spell casts to start duration timers for popular buffs that
-- don't leave a detectable aura (e.g. potions), and to reset placed-unit
-- timers for effects like Consecration on successful recast.
local tbbCastListener = CreateFrame("Frame")
tbbCastListener:SetScript("OnEvent", function(_, _, _, _, spellID)
    if not spellID then return end
    if not CDM or not CDM.db then return end
    local now = GetTime()

    -- Reset placed-unit timers on recast (e.g. Consecration, efflo)
    if ns.PLACED_UNIT_DURATIONS and ns.PLACED_UNIT_DURATIONS[spellID] then
        ns._placedUnitStartCache = ns._placedUnitStartCache or {}
        ns._placedUnitStartCache[spellID] = now
    end

    -- Start custom-duration timers for popular tracked buffs that do not
    -- leave a detectable aura duration object. (e.g Consecration, Efflo etc)
    local entry = _popularSpellIDMap[spellID]
    if not entry or not entry.customDuration then
        RequestTBBTimerRefresh()
        return
    end
    local tbb = ns.GetTrackedBuffBars()
    if not tbb or not tbb.bars then return end
    for i, cfg in ipairs(tbb.bars) do
        if cfg.popularKey == entry.key then
            local bar = tbbFrames[i]
            if bar and bar._tbbReady then
                bar._customStart    = now
                bar._activeDuration = entry.customDuration
            end
        end
    end
    RequestTBBTimerRefresh()
end)

-- Listen for spell activation overlay glow events to drive glow-based bars
-- (e.g. Time Spiral). SHOW starts the custom timer, HIDE clears it.
local tbbGlowListener = CreateFrame("Frame")
tbbGlowListener:SetScript("OnEvent", function(_, event, spellID)
    if not spellID then return end
    -- spellID can be a secret value in combat; bail to avoid taint spread
    if issecretvalue and issecretvalue(spellID) then return end
    local key = _glowSpellIDMap[spellID]
    if not key then return end
    if not CDM or not CDM.db then return end
    local tbb = ns.GetTrackedBuffBars()
    if not tbb or not tbb.bars then return end
    local isShow = (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    local now = GetTime()
    for i, cfg in ipairs(tbb.bars) do
        if cfg.popularKey == key then
            local bar = tbbFrames[i]
            if bar and bar._tbbReady then
                if isShow then
                    if not bar._customStart then
                        bar._customStart    = now
                        bar._activeDuration = cfg.customDuration or 10
                    end
                else
                    bar._customStart    = nil
                    bar._activeDuration = nil
                end
            end
        end
    end
    RequestTBBTimerRefresh()
end)

-- Default fill colour: the player's class colour when it is known.
local _tbbClassR, _tbbClassG, _tbbClassB = 0.05, 0.82, 0.62
do
    local _, classToken = UnitClass("player")
    local classColor = classToken and RAID_CLASS_COLORS[classToken]
    if classColor then
        _tbbClassR, _tbbClassG, _tbbClassB = classColor.r, classColor.g, classColor.b
    end
end

-- Saved-key defaults for a new bar, written per concern and merged flat below
-- (the saved variables keep one flat table per bar).
local TBB_DEFAULT_SECTIONS = {
    { spellID = 0, name = LText("New Bar"), enabled = true },
    { height = 24, width = 270, verticalOrientation = false, opacity = 1.0 },
    {
        texture = "none",
        fillR = _tbbClassR, fillG = _tbbClassG, fillB = _tbbClassB, fillA = 1,
        bgR = 0, bgG = 0, bgB = 0, bgA = 0.4,
    },
    {
        gradientEnabled = false, gradientDir = "HORIZONTAL",
        gradientR = 0.20, gradientG = 0.20, gradientB = 0.80, gradientA = 1,
    },
    { showTimer = true, timerPosition = "right", timerSize = 11, timerX = 0, timerY = 0 },
    { showName = true, namePosition = "left", nameSize = 11, nameX = 0, nameY = 0 },
    {
        showSpark = true,
        iconDisplay = "left", iconSize = 24, iconX = 0, iconY = 0, iconBorderSize = 0,
    },
    { stacksPosition = "center", stacksSize = 11, stacksX = 0, stacksY = 0 },
    {
        stackThresholdEnabled = false, stackThreshold = 5,
        stackThresholdR = 0.8, stackThresholdG = 0.1, stackThresholdB = 0.1, stackThresholdA = 1,
        stackThresholdMaxEnabled = false, stackThresholdMax = 10, stackThresholdTicks = "",
    },
    {
        pandemicGlow = false, pandemicGlowStyle = 1, pandemicGlowColor = { r = 1, g = 1, b = 0 },
        pandemicGlowLines = 8, pandemicGlowThickness = 2, pandemicGlowSpeed = 4,
    },
}
local TBB_DEFAULT_BAR = {}
for _, section in ipairs(TBB_DEFAULT_SECTIONS) do
    for key, value in pairs(section) do TBB_DEFAULT_BAR[key] = value end
end
ns.TBB_DEFAULT_BAR = TBB_DEFAULT_BAR

--- Get tracked buff bars profile data (with lazy init)
function ns.GetTrackedBuffBars()
    if not CDM or not CDM.db then return { selectedBar = 1, bars = {} } end
    local p = CDM.db.profile
    if not p.trackedBuffBars then
        p.trackedBuffBars = { selectedBar = 1, bars = {} }
    end

    -- Bars used to be created with no icon; the icon now shows on the left by
    -- default. Once per profile, bars still on the old default get it.
    local migrateIcon = not p.trackedBuffBars.iconLeftDefault
    p.trackedBuffBars.iconLeftDefault = true

    for i, bar in ipairs(p.trackedBuffBars.bars) do
        if migrateIcon and bar.iconDisplay == "none" then
            bar.iconDisplay = "left"
        end
        if bar.texture and TBB_TEXTURE_RENAMES[bar.texture] then
            bar.texture = TBB_TEXTURE_RENAMES[bar.texture]
        end
        if not bar.id then
            bar.id = "bar_" .. tostring(i) .. "_" .. tostring(math.floor(GetTime() * 1000))
            if p.tbbPositions and p.tbbPositions[tostring(i)] then
                p.tbbPositions[bar.id] = p.tbbPositions[tostring(i)]
                p.tbbPositions[tostring(i)] = nil
            end
        end
    end
    return p.trackedBuffBars
end

--- Add a new tracked buff bar
function ns.AddTrackedBuffBar()
    local tbb = ns.GetTrackedBuffBars()
    local newBar = {}
    -- Copy settings from the last bar if one exists, otherwise use defaults.
    -- Stack-related settings are always reset to defaults (not copied).
    local source = (#tbb.bars > 0) and tbb.bars[#tbb.bars] or TBB_DEFAULT_BAR
    local STACK_KEYS = {
        stacksPosition = true, stacksSize = true, stacksX = true, stacksY = true,
        stackThresholdEnabled = true, stackThreshold = true,
        stackThresholdR = true, stackThresholdG = true, stackThresholdB = true, stackThresholdA = true,
        stackThresholdMaxEnabled = true, stackThresholdMax = true, stackThresholdTicks = true,
    }
    for k, v in pairs(TBB_DEFAULT_BAR) do
        if STACK_KEYS[k] then
            newBar[k] = v
        else
            newBar[k] = (source[k] ~= nil) and source[k] or v
        end
    end
    -- Always reset spell-specific fields
    newBar.spellID = 0
    newBar.name = string.format(LText("Bar %d"), #tbb.bars + 1)
    newBar.id = "bar_" .. tostring(#tbb.bars + 1) .. "_" .. tostring(math.floor(GetTime() * 1000))
    tbb.bars[#tbb.bars + 1] = newBar
    tbb.selectedBar = #tbb.bars

    -- Seat the new bar next to the previous one: above it for horizontal bars,
    -- to its right for vertical ones.
    local profile = CDM and CDM.db and CDM.db.profile
    if profile then
        profile.tbbPositions = profile.tbbPositions or {}
        local prev = tbb.bars[#tbb.bars - 1]
        local prevPos = prev and profile.tbbPositions[prev.id or tostring(#tbb.bars - 1)]
        if prevPos and prevPos.point then
            local step = (prev.height or 24) + 4
            local shiftX, shiftY = 0, step
            if newBar.verticalOrientation then shiftX, shiftY = step, 0 end
            local rel = prevPos.relPoint or prevPos.point
            profile.tbbPositions[newBar.id or tostring(#tbb.bars)] = {
                point = prevPos.point, relPoint = rel, relativePoint = rel,
                x = (prevPos.x or 0) + shiftX, y = (prevPos.y or 0) + shiftY,
            }
        end
    end

    ns.BuildTrackedBuffBars()
    return #tbb.bars
end

--- Remove a tracked buff bar by index
function ns.RemoveTrackedBuffBar(idx)
    local tbb = ns.GetTrackedBuffBars()
    if idx < 1 or idx > #tbb.bars then return end
    table.remove(tbb.bars, idx)
    if tbb.selectedBar > #tbb.bars then tbb.selectedBar = math.max(1, #tbb.bars) end
    ns.BuildTrackedBuffBars()
end

--- Tracked buff bar frames
tbbFrames = {}
-- Context shared with KUICdmBuffBarMarks, KUICdmBuffBarFrame and KUICdmBuffBarBuild. Built once here; the fields
-- that name functions of this file are set at its end.
local barCtx = {
    PP = KT and KT.PP,
    Textures = TBB_TEXTURES,
    Marks = ns.CdmBuffBarMarks,
    Frame = ns.CdmBuffBarFrame,
    FillDefaultR = _tbbClassR,
    FillDefaultG = _tbbClassG,
    FillDefaultB = _tbbClassB,
    frames = tbbFrames,
    state = {},
    PopularBuffs = TBB_POPULAR_BUFFS,
    KT = KT,
    LText = LText,
}
local function RefreshTBBTickFrameState()
    local tbbTickFrame = barCtx.state.tickFrame
    if not tbbTickFrame then return end

    local shouldRun = false
    if tbbFrames then
        for _, bar in ipairs(tbbFrames) do
            if bar then
                local alpha = bar.GetAlpha and (bar:GetAlpha() or 0) or 0
                local target = bar._opacityTarget
                local isAnimating = target ~= nil and math.abs(alpha - target) > 0.005
                local hasTimedState = bar:IsShown() and (
                    bar._customStart ~= nil
                    or bar._activeDuration ~= nil
                    or bar._isPassive == false
                    or (bar._spark and bar._spark:IsShown())
                    or (ns.activeCdmPandemicBars and ns.activeCdmPandemicBars[bar] ~= nil)
                )
                if hasTimedState or isAnimating then
                    shouldRun = true
                    break
                end
            end
        end
    end

    tbbTickFrame._timerAccum = 0
    if shouldRun then
        if not tbbTickFrame:IsShown() then
            tbbTickFrame:Show()
        end
    elseif tbbTickFrame:IsShown() then
        tbbTickFrame:Hide()
    end
end

function ns.GetTBBFrame(idx)
    return tbbFrames[idx]
end

-- Grouping: a bar is grouped unless cfg.grouped == false. All grouped bars form
-- one chain in index order. The first enabled grouped bar anchors the chain (it
-- owns the saved position and the mover); later ones attach to it and share its
-- size. Ungrouped bars stand alone.

function ns.TBBBarGrouped(cfg)
    return cfg ~= nil and cfg.grouped ~= false
end

-- Index of the group anchor = first enabled, checked bar (or nil if none).
function ns.TBBGroupAnchorIndex()
    local t = ns.GetTrackedBuffBars()
    for i, c in ipairs(t.bars or {}) do
        if c.enabled ~= false and ns.TBBBarGrouped(c) then return i end
    end
    return nil
end

-- Count of checked bars (regardless of enabled) -- drives the grow/spacing gate.
function ns.TBBGroupedCount()
    local t = ns.GetTrackedBuffBars()
    local n = 0
    for _, c in ipairs(t.bars or {}) do
        if ns.TBBBarGrouped(c) then n = n + 1 end
    end
    return n
end

local UpdateStackThresholdValue = ns.CdmBuffBarMarks.UpdateThresholdValue

local function TBBMatchesCooldownInfo(info, sid)
    if not info or not sid or sid <= 0 then return false end
    if info.overrideSpellID == sid then return true end
    if info.spellID == sid then return true end
    if info.linkedSpellIDs then
        for _, linkedID in ipairs(info.linkedSpellIDs) do
            if linkedID == sid then return true end
        end
    end
    return false
end

local function TBBFrameMatchesConfig(frame, cfg)
    if not frame or not cfg then return false end
    local cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
    local getInfo = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
    local info = cdID and getInfo and getInfo(cdID)

    if cfg.spellIDs then
        for _, sid in ipairs(cfg.spellIDs) do
            if TBBMatchesCooldownInfo(info, sid) then return true end
        end
    elseif cfg.spellID and cfg.spellID > 0 then
        if TBBMatchesCooldownInfo(info, cfg.spellID) then return true end
    else
        return false
    end

    local getCanonical = ns.GetCanonicalSpellIDForFrame
    local frameSID = getCanonical and getCanonical(frame)
    if not frameSID then return false end

    if cfg.spellIDs then
        for _, sid in ipairs(cfg.spellIDs) do
            if frameSID == sid then return true end
        end
        return false
    end

    return frameSID == cfg.spellID
end

local _tbbFindChildGeneration = 0
local _tbbFindChildCache = {}

function ns.InvalidateTBBFrameCache()
    _tbbFindChildGeneration = _tbbFindChildGeneration + 1
    wipe(_tbbFindChildCache)
end

local function FindTBBBlizzardChild(cfg)
    if not cfg then return nil end

    local cached = _tbbFindChildCache[cfg]
    if cached and cached.gen == _tbbFindChildGeneration then
        if cached.frame and cached.frame.cooldownID == cached.cdID then
            return cached.frame
        end
    end

    local entry = { gen = _tbbFindChildGeneration, frame = false, cdID = nil }
    _tbbFindChildCache[cfg] = entry

    local viewer = _G.BuffBarCooldownViewer
    if not viewer then return nil end

    local function TryFrame(frame)
        if TBBFrameMatchesConfig(frame, cfg) then
            entry.frame = frame
            entry.cdID = frame.cooldownID or (frame.cooldownInfo and frame.cooldownInfo.cooldownID)
            return true
        end
        return false
    end

    if viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
        for frame in viewer.itemFramePool:EnumerateActive() do
            if TryFrame(frame) then return frame end
        end
    elseif viewer.EnumerateChildren then
        for frame in viewer:EnumerateChildren() do
            if TryFrame(frame) then return frame end
        end
    elseif viewer.GetNumChildren then
        local _children = { viewer:GetChildren() }
        for i, frame in ipairs(_children) do
            if frame and TryFrame(frame) then return frame end
        end
    end

    return nil
end
ns.FindTBBChild = FindTBBBlizzardChild

local _tbbBlizzBarText = setmetatable({}, { __mode = "k" })
local function GetTBBBlizzBarFontStrings(blizzBar)
    if not blizzBar then return nil, nil end
    local cached = _tbbBlizzBarText[blizzBar]
    if cached then
        return cached.nameFS ~= false and cached.nameFS or nil,
            cached.timerFS ~= false and cached.timerFS or nil
    end

    local nameFS, timerFS, fsIndex
    fsIndex = 0
    for _, region in pairs({ blizzBar:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            fsIndex = fsIndex + 1
            if fsIndex == 1 then nameFS = region end
            if fsIndex == 2 then timerFS = region end
        end
    end

    _tbbBlizzBarText[blizzBar] = {
        nameFS = nameFS or false,
        timerFS = timerFS or false,
    }
    return nameFS, timerFS
end

local function MirrorTBBBlizzardStatusBar(bar, cfg, blzChild)
    local sb = bar and bar._bar
    local blizzBar = blzChild and blzChild.Bar
    if not sb or not blizzBar then return false end

    local okMinMax, minValue, maxValue = pcall(blizzBar.GetMinMaxValues, blizzBar)
    if okMinMax then
        pcall(sb.SetMinMaxValues, sb, minValue, maxValue)
    end

    local okValue, value = pcall(blizzBar.GetValue, blizzBar)
    if okValue then
        pcall(sb.SetValue, sb, value)
    end

    if cfg.showTimer and bar._timerText then
        local _, timerFS = GetTBBBlizzBarFontStrings(blizzBar)
        local okText, text = timerFS and pcall(timerFS.GetText, timerFS)
        if okText and text and text ~= "" then
            bar._timerText:SetText(text)
            bar._timerText:Show()
        else
            bar._timerText:Hide()
        end
    elseif bar._timerText then
        bar._timerText:Hide()
    end

    if bar._nameText and bar._nameText:IsShown() then
        local nameText
        local nameFS = GetTBBBlizzBarFontStrings(blizzBar)
        local okText, text = nameFS and pcall(nameFS.GetText, nameFS)
        if okText and text and text ~= "" then nameText = text end
        if nameText then
            bar._nameText:SetText(nameText)
            bar._lastLiveName = nameText
        end
    end

    if bar._icon and bar._icon:IsShown() and bar._icon._tex then
        local icon
        if blzChild.Icon and blzChild.Icon.GetTexture then
            local okIcon, liveIcon = pcall(blzChild.Icon.GetTexture, blzChild.Icon)
            if okIcon and liveIcon and not (issecretvalue and issecretvalue(liveIcon)) then
                icon = liveIcon
            end
        end
        if icon and icon ~= bar._lastLiveIcon then
            bar._icon._tex:SetTexture(icon)
            bar._lastLiveIcon = icon
        end
    end

    if cfg.showSpark and bar._spark then
        bar._spark:Show()
    end

    return true
end

local UpdateStackTickMarks = ns.CdmBuffBarMarks.UpdateTickMarks
function ns.ApplyTBBTickMarks(sb, cfg, tickCache, isVert, tickParent)
    UpdateStackTickMarks(barCtx, sb, cfg, tickCache, isVert, tickParent)
end

-- Reusable helpers for secret-safe aura field access (avoids closure allocation per tick)
local _tbbAura
local function _TBBGetDuration() return _tbbAura.duration end
local function _TBBGetExpiration() return _tbbAura.expirationTime end
local function _TBBGetName() return _tbbAura.name end
local function _TBBGetSpellId() return _tbbAura.spellId end

-- Resolve a configured spell name without enumerating player auras. In 12.1
-- GetAuraDataByIndex is forbidden while aura data is secret; known-ID lookup
-- remains the supported path.
local function _TBBScanByName(name)
    if type(name) ~= "string" or name == "" then return nil, nil end
    local ok, info = pcall(C_Spell.GetSpellInfo, name)
    local sid = ok and info and info.spellID
    if sid and not (issecretvalue and issecretvalue(sid)) and sid > 0 then
        local auraOK, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, sid)
        if auraOK and aura then return aura, sid end
    end
    return nil, nil
end

-- Scan current player buffs to cache the real aura spellID for each TBB bar.
local function RefreshTBBResolvedIDs()
    if not CDM or not CDM.db then return end
    local tbb = ns.GetTrackedBuffBars()
    local bars = tbb.bars
    if not bars then return end
    for i, cfg in ipairs(bars) do
        local bar = tbbFrames[i]
        if bar and cfg.enabled ~= false and ((cfg.spellID and cfg.spellID > 0) or (cfg.name and cfg.name ~= "")) then
              local ok, aura = false, nil
              if cfg.spellID and cfg.spellID > 0 then
                  ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, cfg.spellID)
              end
              if ok and aura then
                  bar._resolvedAuraID = cfg.spellID
              elseif cfg.name and cfg.name ~= "" then
                  local _, sid = _TBBScanByName(cfg.name)
                  bar._resolvedAuraID = sid or nil
              end
          end
    end
end
ns.RefreshTBBResolvedIDs = RefreshTBBResolvedIDs

-- Cache _customStart for popular buff bars on UNIT_AURA so the fill timer
-- starts at the right moment. Only needed for multi-ID (popular) bars that
-- use customDuration. Single-ID bars use the DurationObject path from the
-- Blizzard CDM child and need no event-driven caching.
-- Start (or back-date) the fill timer of a popular bar from a live aura.
-- Secret or missing duration data just starts the timer now.
local function SeedCustomTimer(bar, cfg, aura, now)
    local dur, exp = aura.duration, aura.expirationTime
    local unreadable = issecretvalue and (issecretvalue(dur) or issecretvalue(exp))
    bar._activeDuration = cfg.customDuration
    if not unreadable and dur and exp and dur > 0 and exp > 0 then
        bar._customStart = now - (cfg.customDuration - math.max(0, exp - now))
    else
        bar._customStart = now
    end
end

-- Whether a Blizzard CooldownViewer item says its effect is up. A bar item stays
-- shown after its aura ends unless Blizzard's "Hide When Inactive" is on, so its
-- shown flag cannot answer this. Returns nil when the item cannot tell (no item,
-- no IsActive, or a secret answer); the caller then uses its other checks.
local function BlizzardItemActive(child)
    if not child or type(child.IsActive) ~= "function" then return nil end
    local ok, active = pcall(child.IsActive, child)
    if not ok or (issecretvalue and issecretvalue(active)) then return nil end
    return active and true or false
end
ns.TBBBlizzardItemActive = BlizzardItemActive

-- First of the given spell IDs that is currently an aura on the player.
local function FirstPlayerAura(spellIDs)
    for _, sid in ipairs(spellIDs) do
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, sid)
        if ok and aura then return aura end
    end
end

local tbbAuraListener = CreateFrame("Frame")
local _tbbAuraScanPending = false
local _tbbAuraNeedsResolve = false

local function ProcessTrackedBuffAuraBurst()
    _tbbAuraScanPending = false
    if not CDM or not CDM.db then return end
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("cdm.buff_bars.aura_scan")
    if _tbbAuraNeedsResolve and ns.RefreshTBBResolvedIDs then
        ns.RefreshTBBResolvedIDs()
    end
    _tbbAuraNeedsResolve = false
    local tbb = ns.GetTrackedBuffBars()
    local bars = tbb.bars
    if not bars then
        if profileStarted then profiler:End("cdm.buff_bars.aura_scan", profileStarted) end
        return
    end
    local now = GetTime()
    for i, cfg in ipairs(bars) do
        local bar = tbbFrames[i]
        if bar and bar._tbbReady and cfg.enabled ~= false and cfg.spellIDs and cfg.customDuration then
            -- Only initialize _customStart if not already running
            if not bar._customStart then
                local live = FirstPlayerAura(cfg.spellIDs)
                if live then SeedCustomTimer(bar, cfg, live, now) end
            end
        end
    end
    RequestTBBTimerRefresh()
    if profileStarted then profiler:End("cdm.buff_bars.aura_scan", profileStarted) end
end

tbbAuraListener:SetScript("OnEvent", function(_, _, _, updateInfo)
    if not CDM or not CDM.db then return end
    -- Only resolve IDs when aura composition changed. Fields (isFullUpdate,
    -- addedAuras, removedAuraInstanceIDs) can be *secret* in instanced content
    -- and testing a secret errors in Lua, so bind to locals and issecretvalue-gate
    -- every use; when unreadable assume churn (one coalesced rescan is cheaper
    -- than an error). Duration/stack-only edges still refresh timers but skip the
    -- full per-bar rescan that used to run once per UNIT_AURA event.
    local needsResolve = true
    if type(updateInfo) == "table" and issecretvalue and not issecretvalue(updateInfo) then
        local isFull = updateInfo.isFullUpdate
        local added = updateInfo.addedAuras
        local removed = updateInfo.removedAuraInstanceIDs
        local anySecret = (issecretvalue and (issecretvalue(isFull) or issecretvalue(added) or issecretvalue(removed))) or false
        if not anySecret then
            needsResolve = isFull == true
                or (type(added) == "table" and next(added) ~= nil)
                or (type(removed) == "table" and next(removed) ~= nil)
        end
    end
    if not needsResolve then return end
    _tbbAuraNeedsResolve = true
    if _tbbAuraScanPending then return end
    _tbbAuraScanPending = true
    C_Timer.After(0.05, ProcessTrackedBuffAuraBurst)
end)

--- Register or unregister TBB event listeners based on whether any bars are configured.
--- Call this whenever bars are added or removed.
function ns.RefreshBuffBarGating()
    local hasBars = ns.HasBuffBars()
    if hasBars then
        if not tbbCastListener:IsEventRegistered("UNIT_SPELLCAST_SUCCEEDED") then
            tbbCastListener:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        end
        if not tbbAuraListener:IsEventRegistered("UNIT_AURA") then
            tbbAuraListener:RegisterUnitEvent("UNIT_AURA", "player")
        end
        if not tbbGlowListener:IsEventRegistered("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") then
            tbbGlowListener:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
            tbbGlowListener:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        end
    else
        tbbCastListener:UnregisterAllEvents()
        tbbAuraListener:UnregisterAllEvents()
        tbbGlowListener:UnregisterAllEvents()
    end
end

function ns.BuildTrackedBuffBars()
    ns.CdmBuffBarBuild.Build(barCtx)
end

-- Applications mirroring: Blizzard's CDM child shows its Applications frame
-- only when stacks > 1, so its Show/Hide drives our stack text directly and no
-- stack value is ever compared here (the value may be secret).
local _tbbStackHookedChildren = {}

local function HookTBBBlizzChildApplications(blizzChild)
    if not blizzChild or _tbbStackHookedChildren[blizzChild] then return end
    local appsFrame = blizzChild.Applications
    if not appsFrame then return end
    local appsText = appsFrame.Applications
    if not appsText then return end

    _tbbStackHookedChildren[blizzChild] = true

    hooksecurefunc(appsFrame, "Show", function()
        local tbbBar = blizzChild._tbbBar
        if not tbbBar or not tbbBar._stacksText then return end
        if tbbBar._blizzChild ~= blizzChild then return end
        if tbbBar._stacksHidden then return end
        local ok, txt = pcall(appsText.GetText, appsText)
        if ok and txt then
            tbbBar._stacksText:SetText(txt)
            tbbBar._stacksText:Show()
            local nOk, n = pcall(tonumber, txt)
            tbbBar._stackCount = (nOk and n) or 0
        end
    end)

    hooksecurefunc(appsFrame, "Hide", function()
        local tbbBar = blizzChild._tbbBar
        if tbbBar and tbbBar._stacksText and tbbBar._blizzChild == blizzChild then
            tbbBar._stacksText:Hide()
            tbbBar._stackCount = 0
        end
    end)
end

-- Secret-safe helper: returns true if apps should be displayed as stacks.
-- Non-secret: checks apps > 1. Secret: attempts comparison via pcall;
-- if it errors (truly opaque), returns true so FontString renders natively.
local function ShouldShowStacks(apps)
    if not apps then return false end
    local isSecret = issecretvalue and issecretvalue(apps)
    if not isSecret then return apps > 1 end
    local ok, gt1 = pcall(function() return apps > 1 end)
    if not ok then return true end
    return gt1
end

-- Helper: update stacks text and count for a TBB bar.
-- Display: passes Blizzard child Applications text directly (handles secrets).
-- Count: stores applications value on bar._stackCount for the threshold overlay.
-- Since the overlay uses SetValue (secret-safe), _stackCount can be secret.
--
-- Spells from Blizzard's "Tracked Buffs" (buff viewers, vi=3,4) have a native
-- Applications sub-frame that Blizzard manages -- we just read it directly.
-- Spells from "Tracked Bars" (CD/utility viewers, vi=1,2) lack that native
-- handling, so we hook Applications Show/Hide and fall back to aura API.
local function UpdateTBBStacks(bar, cfg)
    if not bar._stacksText then bar._stackCount = 0; return end
    if bar._stacksHidden then bar._stacksText:Hide(); bar._stackCount = 0; return end

    local emptyCache     = ns._tbbEmptyCache or {}
    ns._tbbEmptyCache    = emptyCache
    local buffChildCache = ns._tickBlizzBuffChildCache or emptyCache
    local allChildCache  = ns._tickBlizzAllChildCache or emptyCache
    ns._tbbAuraFallbackCache = ns._tbbAuraFallbackCache or {}
    local auraCache      = ns._tickAuraCache or ns._tbbAuraFallbackCache
    local directChild    = bar._directBlizzChild

    -- Multi-ID (popular) bars: check each spellID
    if cfg.spellIDs then
        for _, sid in ipairs(cfg.spellIDs) do
            -- Prefer buff viewer child (native Applications); fall back to bar viewer
            local isBuffViewer = buffChildCache[sid] ~= nil or (directChild ~= nil and directChild.Bar ~= nil)
            local blzChild = (directChild and TBBFrameMatchesConfig(directChild, { spellID = sid }) and directChild)
                or buffChildCache[sid]
                or allChildCache[sid]

            -- Only hook bar-viewer children (buff viewers handle stacks natively)
            if blzChild and not isBuffViewer then
                blzChild._tbbBar = bar
                bar._blizzChild = blzChild
                HookTBBBlizzChildApplications(blzChild)
            end
            if blzChild and blzChild.Applications and blzChild.Applications:IsShown() then
                local appsText = blzChild.Applications.Applications
                if appsText then
                    local txt = appsText:GetText()
                    if txt then
                        bar._stacksText:SetText(txt)
                        bar._stacksText:Show()
                        bar._stackCount = tonumber(txt) or 0
                        return
                    end
                end
            end
            -- Aura fallback only for bar-viewer spells (no native Applications)
            if not isBuffViewer and auraCache then
                local aura = auraCache[sid]
                if aura == nil then
                    local ok, res = pcall(C_UnitAuras.GetPlayerAuraBySpellID, sid)
                    aura = (ok and res) or false
                    auraCache[sid] = aura
                end
                if aura and aura.applications and ShouldShowStacks(aura.applications) then
                    bar._stacksText:SetText(aura.applications)
                    bar._stacksText:Show()
                    bar._stackCount = aura.applications
                    return
                end
            end
        end
        bar._stacksText:Hide()
        bar._stackCount = 0
        return
    end

    -- Single-ID bars
    local resolvedID = bar._resolvedAuraID or cfg.spellID
    if not resolvedID or resolvedID <= 0 then
        bar._stacksText:Hide()
        bar._stackCount = 0
        return
    end

    -- Check if the spell lives in a buff viewer (native Applications handling)
    local isBuffViewer = buffChildCache[resolvedID] ~= nil or buffChildCache[cfg.spellID] ~= nil or (directChild ~= nil and directChild.Bar ~= nil)
    local blzChild = (directChild and TBBFrameMatchesConfig(directChild, cfg) and directChild)
                  or buffChildCache[resolvedID] or allChildCache[resolvedID]
                  or buffChildCache[cfg.spellID] or allChildCache[cfg.spellID]

    -- Only hook bar-viewer children (buff viewers handle stacks natively)
    if blzChild and not isBuffViewer then
        blzChild._tbbBar = bar
        bar._blizzChild = blzChild
        HookTBBBlizzChildApplications(blzChild)
    end

    -- Path 1: Blizzard child Applications frame (works for both viewer types)
    if blzChild and blzChild.Applications and blzChild.Applications:IsShown() then
        local appsText = blzChild.Applications.Applications
        if appsText then
            local txt = appsText:GetText()
            if txt then
                bar._stacksText:SetText(txt)
                bar._stacksText:Show()
                local apps
                if auraCache then
                    local aura = auraCache[resolvedID]
                    if aura == nil then
                        local aOk, res = pcall(C_UnitAuras.GetPlayerAuraBySpellID, resolvedID)
                        aura = (aOk and res) or false
                        auraCache[resolvedID] = aura
                    end
                    if aura and aura.applications then apps = aura.applications end
                end
                bar._stackCount = apps or 0
                if not apps then
                    bar._stackCount = tonumber(txt) or 0
                end
                return
            end
        end
    end

    -- Buff-viewer spells: if Applications frame isn't shown, no stacks to display.
    -- Skip aura fallbacks that can produce "0" for non-stacking buffs.
    if isBuffViewer then
        bar._stacksText:Hide()
        bar._stackCount = 0
        return
    end

    -- Path 2: aura cache lookup (bar-viewer children without Applications frame)
    if auraCache then
        local aura = auraCache[resolvedID]
        if aura == nil then
            local ok, res = pcall(C_UnitAuras.GetPlayerAuraBySpellID, resolvedID)
            aura = (ok and res) or false
            auraCache[resolvedID] = aura
        end
        if aura and aura.applications then
            bar._stackCount = aura.applications
            if ShouldShowStacks(aura.applications) then
                bar._stacksText:SetText(aura.applications)
                bar._stacksText:Show()
            else
                bar._stacksText:Hide()
            end
            return
        end
    end

    bar._stacksText:Hide()
    bar._stackCount = 0
end

function ns.UpdateTrackedBuffBarTimers()
    if not CDM or not CDM.db then return end
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("cdm.buff_bars.timers")
    local tbb = ns.GetTrackedBuffBars()
    local bars = tbb.bars
    local now = GetTime()
    local emptyCache = ns._tbbEmptyCache or {}
    ns._tbbEmptyCache = emptyCache
    local activeCache = ns._tickBlizzActiveCache or emptyCache
    local buffChildCache = ns._tickBlizzBuffChildCache or emptyCache
    local allChildCache = ns._tickBlizzAllChildCache or emptyCache
    local IsBufChildActive = ns.IsBufChildCooldownActive
    local IsCoreBuffActive = ns.IsCDMBuffActiveForBar
    local inCombat = InCombatLockdown()

    -- Self-heal placeholder mode if user navigated away from Buff Bars
    if ns._tbbPlaceholderMode then
        local ap = nil
        if ap ~= "Tracking Bars" then
            ns._tbbPlaceholderMode = false
            if ns.HideTBBPlaceholders then ns.HideTBBPlaceholders() end
        end
    end

    for i, cfg in ipairs(bars) do
        local bar = tbbFrames[i]
        if not bar or not bar._tbbReady then
            -- bar not configured or disabled, skip
        elseif ns._tbbPlaceholderMode then
            -- Buff Bars options tab is open; keep bars visible for placeholders
            if not bar:IsShown() then bar:Show() end
        elseif cfg.enabled == false then
            bar:Hide()
        elseif cfg.glowBased then
            -- Glow-based bar (e.g. Time Spiral). Active only while _customStart is set
            -- by the SPELL_ACTIVATION_OVERLAY_GLOW listener.
            local sb = bar._bar
            if bar._customStart then
                local activeDur = bar._activeDuration or cfg.customDuration or 10
                local elapsed = now - bar._customStart
                local remaining = math.max(0, activeDur - elapsed)
                if remaining > 0 then
                    if not bar:IsShown() then bar:Show() end
                    local frac = remaining / activeDur
                    sb:SetMinMaxValues(0, 1)
                    sb:SetValue(frac)
                    if cfg.showTimer and bar._timerText then
                        local t
                        if remaining >= 10 then t = format("%d", floor(remaining))
                        else t = format("%.1f", remaining) end
                        bar._timerText:SetText(t)
                        bar._timerText:Show()
                    end
                else
                    bar._customStart    = nil
                    bar._activeDuration = nil
                    bar:Hide()
                end
                UpdateStackThresholdValue(bar)
                if bar._ticksDirty and sb then
                    local w = sb:GetWidth()
                    if w and w > 0 then
                        UpdateStackTickMarks(barCtx, sb, cfg, bar._threshTicks, cfg.verticalOrientation, bar._tickOverlay)
                        bar._ticksDirty = nil
                    end
                end
            else
                if bar:IsShown() then bar:Hide() end
                if bar._stacksText then bar._stacksText:Hide() end
            end
        elseif cfg.spellIDs then
            -- Multi-ID bar (popular buffs). Active if any ID is in the CDM active cache.
            local sb = bar._bar  -- StatusBar child of wrapFrame
            local directChild = FindTBBBlizzardChild(cfg)
            local directActive = BlizzardItemActive(directChild)
            if directActive == nil then
                directActive = directChild and directChild.IsShown and directChild:IsShown() or false
            end
            -- An item that is up but no longer active must not lend its data to the bar.
            if not directActive then directChild = nil end
            bar._directBlizzChild = directChild
            local isActive = directActive
            for _, sid in ipairs(cfg.spellIDs) do
                local sidChild = buffChildCache[sid] or allChildCache[sid]
                local itemActive = BlizzardItemActive(sidChild)
                if itemActive == nil then
                    itemActive = activeCache[sid] or (IsCoreBuffActive and IsCoreBuffActive(sid, sid, sidChild))
                end
                if itemActive then
                    isActive = true
                    break
                end
            end

            -- Fallback: check player auras directly
            if not isActive or not bar._customStart then
                local live = FirstPlayerAura(cfg.spellIDs)
                if live then
                    isActive = true
                    if not bar._customStart then SeedCustomTimer(bar, cfg, live, now) end
                end
            end

            -- Fall back to cast-triggered custom timer (covers potions etc. that
            -- may not appear in CDM viewers at all)
            if not isActive and bar._customStart then
                local activeDur = bar._activeDuration or cfg.customDuration
                if activeDur and activeDur > 0 then
                    local elapsed = now - bar._customStart
                    if elapsed < activeDur then
                        isActive = true
                    else
                        bar._customStart    = nil
                        bar._activeDuration = nil
                    end
                end
            end

            if isActive then
                if not bar:IsShown() then bar:Show() end
                UpdateTBBStacks(bar, cfg)

                -- All multi-ID bars use customDuration for the fill animation
                local mirroredBlizzardBar = directChild and MirrorTBBBlizzardStatusBar(bar, cfg, directChild)
                local activeDur = bar._activeDuration or cfg.customDuration
                if not mirroredBlizzardBar and activeDur and activeDur > 0 and bar._customStart then
                    local elapsed = now - bar._customStart
                    local remaining = math.max(0, activeDur - elapsed)
                    local frac = remaining / activeDur
                    sb:SetMinMaxValues(0, 1)
                    sb:SetValue(frac)
                    if cfg.showTimer and bar._timerText then
                        if remaining <= 0 then
                            bar._timerText:Hide()
                        else
                            local t
                            if remaining >= 60 then t = format("%dm", floor(remaining / 60))
                            elseif remaining >= 10 then t = format("%d", floor(remaining))
                            else t = format("%.1f", remaining) end
                            bar._timerText:SetText(t)
                            bar._timerText:Show()
                        end
                    end
                    if remaining <= 0 then
                        bar._customStart    = nil
                        bar._activeDuration = nil
                        bar:Hide()
                    end
                elseif not mirroredBlizzardBar then
                    -- Active but no custom timer started yet (or permanent)
                    sb:SetValue(1)
                    if cfg.showTimer and bar._timerText then bar._timerText:Hide() end
                end
                UpdateStackThresholdValue(bar)
                -- Re-apply tick marks once bar has valid dimensions after layout
                if bar._ticksDirty and bar._bar then
                    local w = bar._bar:GetWidth()
                    if w and w > 0 then
                        UpdateStackTickMarks(barCtx, bar._bar, cfg, bar._threshTicks, cfg.verticalOrientation, bar._tickOverlay)
                        bar._ticksDirty = nil
                    end
                end
            else
                if bar:IsShown() then bar:Hide() end
                if bar._stacksText then bar._stacksText:Hide() end
            end
        elseif not cfg.spellID or cfg.spellID == 0 then
            bar:Hide()
        else
            local spellID = cfg.spellID
            local resolvedID = bar._resolvedAuraID or spellID
            local sb = bar._bar  -- StatusBar child of wrapFrame
            local directChild = FindTBBBlizzardChild(cfg)
            bar._directBlizzChild = directChild

            local blzChild = directChild
                          or buffChildCache[resolvedID] or buffChildCache[spellID]
                          or allChildCache[resolvedID] or allChildCache[spellID]
            -- The Blizzard item's own active flag decides when it has one: its shown
            -- flag, and the caches built from it, stay true after the aura ends.
            local isActive = BlizzardItemActive(blzChild)
            if isActive == nil then
                -- No usable flag: the same caches the core CDM builds.
                isActive = (directChild and directChild.IsShown and directChild:IsShown())
                          or (IsCoreBuffActive and IsCoreBuffActive(resolvedID, spellID, blzChild))
                          or activeCache[resolvedID] or activeCache[spellID]
                if not isActive and IsBufChildActive and IsBufChildActive(blzChild) then
                    isActive = true
                end
                isActive = isActive and true or false
            elseif not isActive then
                -- An inactive item keeps its last fill and timer text; do not mirror it.
                blzChild = nil
                bar._directBlizzChild = nil
            end
            -- Fallback: check player auras directly (covers passives, buffs not
            -- tracked by Blizzard CDM and an item Blizzard has not bound yet)
            local fallbackAura
            if not isActive then
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, resolvedID)
                if not ok or not aura then
                    ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
                end
                if ok and aura then
                    isActive = true
                    fallbackAura = aura
                end
            end

            if not isActive and inCombat and (cfg.customDuration or bar._activeDuration) and bar._customStart then
                local activeDur = bar._activeDuration or cfg.customDuration
                if activeDur and activeDur > 0 then
                    local elapsed = now - bar._customStart
                    if elapsed < activeDur then
                        isActive = true
                    else
                        bar._customStart    = nil
                        bar._activeDuration = nil
                    end
                end
            end

            if isActive then
                if not bar:IsShown() then bar:Show() end
                UpdateTBBStacks(bar, cfg)

                -- Dynamically update icon from Blizzard CDM child's live texture
                -- so aura-driven icon changes (e.g. Roll the Bones sub-buffs) are
                -- reflected each tick instead of staying on the static config icon.
                if blzChild and bar._icon and bar._icon._tex and blzChild.Icon and blzChild.Icon.GetTexture then
                    local liveIconTex = blzChild.Icon:GetTexture()
                    local isSecret = issecretvalue and issecretvalue(liveIconTex)
                    if not isSecret and liveIconTex and liveIconTex ~= bar._lastLiveIcon then
                        bar._icon._tex:SetTexture(liveIconTex)
                        bar._lastLiveIcon = liveIconTex
                    end
                end

                local activeDur = bar._activeDuration or cfg.customDuration
                if activeDur and activeDur > 0 and bar._customStart then
                    local elapsed = now - bar._customStart
                    local remaining = math.max(0, activeDur - elapsed)
                    local frac = remaining / activeDur
                    sb:SetMinMaxValues(0, 1)
                    sb:SetValue(frac)

                    if cfg.showTimer and bar._timerText then
                        if remaining <= 0 then
                            bar._timerText:Hide()
                        else
                            local t
                            if remaining >= 3600 then t = format("%dh", floor(remaining / 3600))
                            elseif remaining >= 60 then t = format("%dm", floor(remaining / 60))
                            elseif remaining >= 10 then t = format("%d", floor(remaining))
                            else t = format("%.1f", remaining) end
                            bar._timerText:SetText(t)
                            bar._timerText:Show()
                        end
                    end

                    if remaining <= 0 then
                        bar._customStart    = nil
                        bar._activeDuration = nil
                        bar:Hide()
                    end
                else
                    -- Standard path: try DurationObject via Blizzard CDM child.
                    -- If no duration object is available (passives, permanent
                    -- buffs, or spells not tracked by Blizzard CDM), default
                    -- to a full bar with timer hidden.
                    local durObj = nil
                    local mirroredBlizzardBar = blzChild and MirrorTBBBlizzardStatusBar(bar, cfg, blzChild)
                    if not mirroredBlizzardBar then
                    if blzChild then
                        local auraID = blzChild.auraInstanceID
                        local auraUnit = blzChild.auraDataUnit or "player"
                        if auraID then
                            local ok, d = pcall(C_UnitAuras.GetAuraDuration, auraUnit, auraID)
                            if ok and d then durObj = d end
                        end
                    end

                    -- Aura found by the direct query: its own duration drives the bar.
                    if not durObj and fallbackAura and fallbackAura.auraInstanceID ~= nil then
                        local ok, d = pcall(C_UnitAuras.GetAuraDuration, "player", fallbackAura.auraInstanceID)
                        if ok and d then durObj = d end
                    end

                    -- Totem/summon fallback: use the DurationObject or raw
                    -- start+dur that the main CDM already captured via its
                    -- SetCooldown / SetCooldownFromDurationObject hooks.
                    if not durObj and blzChild then
                        local cachedDurObj = ns._cdmDurObjCache[blzChild]
                        if cachedDurObj then
                            durObj = cachedDurObj
                        end
                    end

                    -- Raw start+dur fallback (totems): drive the bar manually
                    -- from the plain numbers the main CDM hooks captured.
                    local rawRemaining, rawDur, rawIsSecret
                    if not durObj and blzChild then
                        local rs = ns._cdmRawStartCache[blzChild]
                        local rd = ns._cdmRawDurCache[blzChild]
                        if rs and rd then
                            local sRS = issecretvalue and issecretvalue(rs)
                            local sRD = issecretvalue and issecretvalue(rd)
                            if sRS or sRD then
                                rawIsSecret = true
                                local ok, calcRem = pcall(function() return (rs + rd) - now end)
                                if ok and calcRem then
                                    rawRemaining = calcRem
                                    rawDur = rd
                                end
                            elseif rd > 0 then
                                rawRemaining = math.max(0, (rs + rd) - now)
                                rawDur = rd
                            end
                        end
                    end

                    -- Placed unit fixed duration fallback (e.g. Consecration)
                    if not durObj and not rawRemaining then
                        local fixedDur = ns.PLACED_UNIT_DURATIONS[resolvedID]
                        if fixedDur then
                            local startCache = ns._placedUnitStartCache
                            if startCache then
                                if not startCache[resolvedID] then
                                    startCache[resolvedID] = now
                                end
                                rawRemaining = math.max(0, (startCache[resolvedID] + fixedDur) - now)
                                rawDur = fixedDur
                            end
                        end
                    end

                    -- Validate the duration object actually has remaining time.
                    -- Permanent/passive buffs may return a durObj that reads as
                    -- zero, which would render an empty bar.
                    -- We cache passive state on the bar so it persists into combat.
                    local useDurObj = false
                    if durObj then
                        local ok, rem = pcall(durObj.GetRemainingDuration, durObj)
                        if ok and rem then
                            local isSecret = issecretvalue and issecretvalue(rem)
                            if isSecret then
                                -- In combat: trust cached passive state if we have it
                                if bar._isPassive then
                                    useDurObj = false
                                else
                                    useDurObj = true
                                end
                            elseif rem > 0 then
                                useDurObj = true
                                bar._isPassive = false
                            else
                                -- rem == 0 out of combat means passive/permanent
                                bar._isPassive = true
                            end
                        end
                    else
                        -- No durObj: passive unless raw fallback available
                        if rawIsSecret then
                            if rawRemaining then
                                bar._isPassive = false
                            end
                        elseif not (rawRemaining and rawRemaining > 0) then
                            bar._isPassive = true
                        end
                    end

                    if useDurObj then
                        sb:SetMinMaxValues(0, 1)
                        sb:SetTimerDuration(durObj, Enum.StatusBarInterpolation.None, Enum.StatusBarTimerDirection.RemainingTime)
                        sb:SetToTargetValue()
                        if cfg.showSpark and bar._spark then bar._spark:Show() end

                        if cfg.showTimer and bar._timerText then
                            local ok, remaining = pcall(durObj.GetRemainingDuration, durObj)
                            if ok and remaining then
                                local isSecret = issecretvalue and issecretvalue(remaining)
                                if isSecret then
                                    local fok, fstr = pcall(format, "%.1f", remaining)
                                    if fok and fstr then
                                        bar._timerText:SetText(fstr)
                                    else
                                        bar._timerText:SetText(remaining)
                                    end
                                else
                                    local t
                                    if remaining >= 3600 then t = format("%dh", floor(remaining / 3600))
                                    elseif remaining >= 60 then t = format("%dm", floor(remaining / 60))
                                    elseif remaining >= 10 then t = format("%d", floor(remaining))
                                    else t = format("%.1f", remaining) end
                                    bar._timerText:SetText(t)
                                end
                                bar._timerText:Show()
                            else
                                bar._timerText:Hide()
                            end
                        end
                    elseif rawRemaining and (rawIsSecret or rawRemaining > 0) then
                        -- Raw start+dur path (totems/summons): manual bar fill
                        sb:SetMinMaxValues(0, 1)
                        if rawIsSecret then
                            pcall(sb.SetValue, sb, rawRemaining / rawDur)
                        else
                            sb:SetValue(rawRemaining / rawDur)
                        end
                        if cfg.showSpark and bar._spark then bar._spark:Show() end
                        if cfg.showTimer and bar._timerText then
                            if rawIsSecret then
                                local fok, fstr = pcall(format, "%.1f", rawRemaining)
                                if fok and fstr then
                                    bar._timerText:SetText(fstr)
                                else
                                    bar._timerText:SetText("")
                                end
                            else
                                local t
                                if rawRemaining >= 3600 then t = format("%dh", floor(rawRemaining / 3600))
                                elseif rawRemaining >= 60 then t = format("%dm", floor(rawRemaining / 60))
                                elseif rawRemaining >= 10 then t = format("%d", floor(rawRemaining))
                                else t = format("%.1f", rawRemaining) end
                                bar._timerText:SetText(t)
                            end
                            bar._timerText:Show()
                        end
                    else
                        -- Permanent/passive buff or no valid duration
                        local maxS = cfg.stackThresholdMax
                        if bar._isPassive and cfg.stackThresholdMaxEnabled and maxS and maxS > 0 then
                            sb:SetMinMaxValues(0, maxS)
                            sb:SetValue(bar._stackCount or 0)
                        else
                            sb:SetMinMaxValues(0, 1)
                            sb:SetValue(1)
                        end
                        if bar._timerText then bar._timerText:Hide() end
                        if bar._spark then bar._spark:Hide() end
                    end
                    end

                    -- Pandemic glow on tracked buff bars
                    if cfg.pandemicGlow and durObj and ns.cdmPandemicCurve then
                        -- Determine glow target: icon if shown, otherwise the bar overlay
                        local glowTarget
                        if bar._icon and bar._icon:IsShown() then
                            if not bar._pandemicGlowOnIcon then
                                if not bar._icon._pandemicOverlay then
                                    local ov = CreateFrame("Frame", nil, bar._icon)
                                    ov:SetAllPoints(bar._icon)
                                    ov:SetFrameLevel(bar._icon:GetFrameLevel() + 2)
                                    ov:SetAlpha(0)
                                    ov:EnableMouse(false)
                                    bar._icon._pandemicOverlay = ov
                                end
                            end
                            glowTarget = bar._icon._pandemicOverlay
                            bar._pandemicGlowOnIcon = true
                        else
                            glowTarget = bar._pandemicGlowOverlay
                            bar._pandemicGlowOnIcon = false
                        end
                        local style = cfg.pandemicGlowStyle or 1
                        -- When glowing the bar overlay (no icon), only Pixel Glow (1)
                        -- and Auto-Cast Shine (4) render properly on a wide rectangle.
                        -- Fall back to Pixel Glow for icon-shaped styles.
                        if not bar._pandemicGlowOnIcon and style ~= 1 and style ~= 4 then
                            style = 1
                        end
                        if not bar._pandemicGlowActive or bar._pandemicGlowStyleIdx ~= style or bar._pandemicGlowTarget ~= glowTarget then
                            if bar._pandemicGlowActive and bar._pandemicGlowTarget and bar._pandemicGlowTarget ~= glowTarget then
                                ns.StopNativeGlow(bar._pandemicGlowTarget)
                            end
                            local c = cfg.pandemicGlowColor or { r = 1, g = 1, b = 0 }
                            local glowOpts = (style == 1) and {
                                N = cfg.pandemicGlowLines or 8,
                                th = cfg.pandemicGlowThickness or 2,
                                period = cfg.pandemicGlowSpeed or 4,
                            } or nil
                            ns.StartNativeGlow(glowTarget, style, c.r or 1, c.g or 1, c.b or 0, glowOpts)
                            bar._pandemicGlowActive = true
                            bar._pandemicGlowStyleIdx = style
                            bar._pandemicGlowTarget = glowTarget
                        end
                        glowTarget:SetAlpha(
                            C_CurveUtil.EvaluateColorValueFromBoolean(
                                durObj:IsZero(), 0,
                                durObj:EvaluateRemainingPercent(ns.cdmPandemicCurve)))
                        ns.activeCdmPandemicBars[bar] = durObj
                    elseif bar._pandemicGlowActive then
                        if bar._pandemicGlowTarget then
                            ns.StopNativeGlow(bar._pandemicGlowTarget)
                        end
                        bar._pandemicGlowActive = false
                        bar._pandemicGlowStyleIdx = nil
                        bar._pandemicGlowTarget = nil
                        ns.activeCdmPandemicBars[bar] = nil
                    end
                end
                -- Feed threshold overlay each tick (secret-safe, no comparison)
                UpdateStackThresholdValue(bar)
                -- Re-apply tick marks once bar has valid dimensions after layout
                if bar._ticksDirty and bar._bar then
                    local w = bar._bar:GetWidth()
                    if w and w > 0 then
                        UpdateStackTickMarks(barCtx, bar._bar, cfg, bar._threshTicks, cfg.verticalOrientation, bar._tickOverlay)
                        bar._ticksDirty = nil
                    end
                end
            else
                -- Buff not active, hide the bar and clear state
                if bar._pandemicGlowActive then
                    if bar._pandemicGlowTarget then ns.StopNativeGlow(bar._pandemicGlowTarget) end
                    bar._pandemicGlowActive = false
                    bar._pandemicGlowStyleIdx = nil
                    bar._pandemicGlowTarget = nil
                    ns.activeCdmPandemicBars[bar] = nil
                end
                if bar:IsShown() then bar:Hide() end
                if bar._stacksText then bar._stacksText:Hide() end
                bar._resolvedAuraID = nil
                bar._blizzChild = nil
                bar._customStart = nil
                bar._activeDuration = nil
                bar._isPassive = nil
                bar._lastLiveIcon = nil
                bar._lastLiveName = nil
                if bar._cooldown then bar._cooldown:Clear() end
            end
        end
    end

    -- Re-anchor sparks every frame so they track the fill edge smoothly,
    -- same as the cast bar approach.
    for _, bar in ipairs(tbbFrames) do
        if bar and bar._spark and bar._spark:IsShown() and bar._bar then
            local sb = bar._bar
            local cfg_isVert = bar._lastVertical  -- cached from ApplyTrackedBuffBarSettings
            bar._spark:ClearAllPoints()
            if bar._gradientActive and bar._gradClip then
                if cfg_isVert then
                    bar._spark:SetPoint("CENTER", bar._gradClip, "TOP", 0, 0)
                else
                    bar._spark:SetPoint("CENTER", bar._gradClip, "RIGHT", 0, 0)
                end
            else
                if cfg_isVert then
                    bar._spark:SetPoint("CENTER", sb:GetStatusBarTexture(), "TOP", 0, 0)
                else
                    bar._spark:SetPoint("CENTER", sb:GetStatusBarTexture(), "RIGHT", 0, 0)
                end
            end
        end
    end

    RefreshTBBTickFrameState()
    if profileStarted then profiler:End("cdm.buff_bars.timers", profileStarted) end
end

function ns.IsTBBRebuildPending()
    return barCtx.state.rebuildPending
end

-- Unlock-mode registration for the tracked buff bars.
function ns.RegisterTBBUnlockElements()
    ns.CdmBuffBarBuild.RegisterUnlock(barCtx)
end
_G._CDM_RegisterTBBUnlock = ns.RegisterTBBUnlockElements

-- Options preview: the selected bar drawn by the same frame code as the real
-- bars, draining in a loop so fill, spark and timer can be judged live.
local PREVIEW_CYCLE = 12
local PREVIEW_MAX_HEIGHT = 120
local tbbPreview, tbbPreviewHost, tbbPreviewCfg

-- The bar frames are built for UIParent; inside the options window they take
-- the host's strata and sit above it, keeping their order among themselves.
local function LiftPreviewToHost(root, host)
    local frames, levels = {}, {}
    local function Collect(frame)
        frames[#frames + 1] = frame
        levels[#levels + 1] = frame:GetFrameLevel()
        for _, child in ipairs({ frame:GetChildren() }) do Collect(child) end
    end
    Collect(root)
    local strata = host:GetFrameStrata()
    local shift = host:GetFrameLevel() + 2 - levels[1]
    for i, frame in ipairs(frames) do
        frame:SetFrameStrata(strata)
        frame:SetFrameLevel(math.max(0, levels[i] + shift))
    end
end

local function PreviewIcon(cfg)
    if cfg.popularKey then
        for _, entry in ipairs(TBB_POPULAR_BUFFS) do
            if entry.key == cfg.popularKey then return entry.icon end
        end
    end
    local info = cfg.spellID and cfg.spellID > 0 and C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(cfg.spellID)
    return (info and info.iconID) or 134400
end

local function PreviewName(cfg)
    if cfg.name and cfg.name ~= "" then return cfg.name end
    local name = cfg.spellID and cfg.spellID > 0 and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(cfg.spellID)
    return name or LText("New Bar")
end

local function TickPreview(bar)
    local cfg = tbbPreviewCfg
    if not cfg or not bar._bar then return end
    local remaining = PREVIEW_CYCLE - (GetTime() % PREVIEW_CYCLE)
    bar._bar:SetMinMaxValues(0, 1)
    bar._bar:SetValue(remaining / PREVIEW_CYCLE)
    if bar._timerText and bar._timerText:IsShown() then
        bar._timerText:SetText(remaining >= 10 and format("%d", floor(remaining)) or format("%.1f", remaining))
    end
end

--- Shows the preview inside host for cfg, scaled to fit availableWidth.
--- Returns the height the host needs.
function ns.ShowTBBPreview(host, cfg, availableWidth)
    if not host or type(cfg) ~= "table" then return 0 end
    if not tbbPreview then
        tbbPreview = ns.CdmBuffBarFrame.CreateBar(barCtx, host, "Preview")
        tbbPreview:SetScript("OnUpdate", TickPreview)
    elseif tbbPreview:GetParent() ~= host then
        tbbPreview:SetParent(host)
    end
    tbbPreviewHost, tbbPreviewCfg = host, cfg
    LiftPreviewToHost(tbbPreview, host)

    ns.CdmBuffBarFrame.ApplySettings(barCtx, tbbPreview, cfg)
    if tbbPreview._icon and tbbPreview._icon._tex then
        tbbPreview._icon._tex:SetTexture(PreviewIcon(cfg))
    end
    if tbbPreview._nameText then tbbPreview._nameText:SetText(PreviewName(cfg)) end
    if tbbPreview._stacksText then tbbPreview._stacksText:Hide() end

    local barW, barH = tbbPreview:GetSize()
    local scale = 1
    if availableWidth and availableWidth > 0 and barW > availableWidth then
        scale = availableWidth / barW
    end
    if barH * scale > PREVIEW_MAX_HEIGHT then scale = PREVIEW_MAX_HEIGHT / barH end
    tbbPreview:SetScale(scale)
    tbbPreview:ClearAllPoints()
    tbbPreview:SetPoint("CENTER", host, "CENTER", 0, 0)
    -- A disabled bar is still previewed, dimmed, so its look can be set up first.
    if cfg.enabled == false then tbbPreview:SetAlpha((cfg.opacity or 1) * 0.4) end
    TickPreview(tbbPreview)
    tbbPreview:Show()
    return barH * scale
end

--- Re-applies the last previewed settings after an option changed.
function ns.RefreshTBBPreview()
    if tbbPreview and tbbPreviewHost and tbbPreviewCfg and tbbPreviewHost:IsVisible() then
        local width = tbbPreviewHost:GetWidth()
        ns.ShowTBBPreview(tbbPreviewHost, tbbPreviewCfg, width and width - 20)
    end
end

function barCtx.FontPath()
    return (_G.KT and _G.KT.FONT_PATH) or (KT and KT.FONT_PATH) or "Fonts\\FRIZQT__.TTF"
end
function barCtx.GetProfile()
    return CDM and CDM.db and CDM.db.profile
end
function barCtx.GetProfiler()
    return _G.KT and _G.KT.CombatProfiler
end
barCtx.GetTrackedBuffBars = ns.GetTrackedBuffBars
barCtx.IsGrouped = ns.TBBBarGrouped
barCtx.GroupAnchorIndex = ns.TBBGroupAnchorIndex
barCtx.UpdateTimers = ns.UpdateTrackedBuffBarTimers
barCtx.RefreshTickState = RefreshTBBTickFrameState
barCtx.RegisterUnlock = ns.RegisterTBBUnlockElements
barCtx.RefreshResolvedIDs = ns.RefreshTBBResolvedIDs
barCtx.RefreshGating = ns.RefreshBuffBarGating
barCtx.Rebuild = ns.BuildTrackedBuffBars






