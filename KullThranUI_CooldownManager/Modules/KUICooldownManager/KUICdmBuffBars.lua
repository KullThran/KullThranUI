--------------------------------------------------------------------------------
--  KUICdmBuffBars.lua
--  Tracked Buff Bars (per-bar buff tracking with individual settings)
--------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local KT = (ns and ns.KT) or _G.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local issecretvalue = issecretvalue or (C_UI and C_UI.IsSecret) or function() return false end

-- Set to true to enable Tracked Buff Bars functionality
local TBB_ENABLED = true

-- Forward references from main CDM file (set during init)
local CDM

function ns.InitBuffBars(cdm)
    CDM = cdm
end

-------------------------------------------------------------------------------
--  Tracked Buff Bars v2: Per-bar buff tracking with individual settings
--  Each bar tracks a single buff/aura and has its own display settings.
-------------------------------------------------------------------------------
local TBB_TEX_BASE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\textures\\"
local TBB_TEXTURES = {
    ["none"]          = nil,
    ["beautiful"]     = TBB_TEX_BASE .. "beautiful.tga",
    ["plating"]       = TBB_TEX_BASE .. "plating.tga",
    ["atrocity"]      = TBB_TEX_BASE .. "atrocity.tga",
    ["divide"]        = TBB_TEX_BASE .. "divide.tga",
    ["glass"]         = TBB_TEX_BASE .. "glass.tga",
    ["gradient-lr"]   = TBB_TEX_BASE .. "gradient-lr.tga",
    ["gradient-rl"]   = TBB_TEX_BASE .. "gradient-rl.tga",
    ["gradient-bt"]   = TBB_TEX_BASE .. "gradient-bt.tga",
    ["gradient-tb"]   = TBB_TEX_BASE .. "gradient-tb.tga",
    ["matte"]         = TBB_TEX_BASE .. "matte.tga",
    ["sheer"]         = TBB_TEX_BASE .. "sheer.tga",
}
local TBB_TEXTURE_ORDER = {
    "none", "beautiful", "plating",
    "atrocity", "divide", "glass",
    "gradient-lr", "gradient-rl", "gradient-bt", "gradient-tb",
    "matte", "sheer",
}
local TBB_TEXTURE_NAMES = {
    ["none"]        = "None",
    ["beautiful"]   = "Beautiful",
    ["plating"]     = "Plating",
    ["atrocity"]    = "Atrocity",
    ["divide"]      = "Divide",
    ["glass"]       = "Glass",
    ["gradient-lr"] = "Gradient Right",
    ["gradient-rl"] = "Gradient Left",
    ["gradient-bt"] = "Gradient Up",
    ["gradient-tb"] = "Gradient Down",
    ["matte"]       = "Matte",
    ["sheer"]       = "Sheer",
}
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

local function ResolveTBBTexturePath(map, key, fallback)
    local tex = map and map[key]
    if type(tex) == "string" and tex ~= "" then
        return tex
    end
    return fallback
end

-------------------------------------------------------------------------------
--  Popular Buffs: hardcoded entries shown in the spell picker.
--  spellIDs: list of all spell IDs that represent this buff (any match = active).
--  customDuration: fixed duration in seconds used to drive the bar fill.
--  icon: fileID to display (used when no spellID resolves an icon).
--  name: display name shown in the picker and on the bar.
-------------------------------------------------------------------------------
local TBB_POPULAR_BUFFS = {
    {
        key            = "bloodlust",
        name           = UnitFactionGroup("player") == "Horde" and "Bloodlust" or "Heroism",
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
    ---------------------------------------------------------------------------
    --  Demonology Warlock Guardians
    --  These summons have no player aura; detection relies on the Blizzard CDM
    --  active-state / buff-viewer fallback (see KUICooldownManager.lua).
    ---------------------------------------------------------------------------
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

-- Resolve player class color for default fill
local _tbbClassR, _tbbClassG, _tbbClassB = 0.05, 0.82, 0.62
do
    local _, ct = UnitClass("player")
    if ct then
        local cc = RAID_CLASS_COLORS[ct]
        if cc then _tbbClassR, _tbbClassG, _tbbClassB = cc.r, cc.g, cc.b end
    end
end

local TBB_DEFAULT_BAR = {
    spellID   = 0,
    name      = "New Bar",
    enabled   = true,
    height    = 24,
    width     = 270,
    verticalOrientation = false,
    texture   = "none",
    fillR     = _tbbClassR, fillG = _tbbClassG, fillB = _tbbClassB, fillA = 1,
    bgR       = 0, bgG = 0, bgB = 0, bgA = 0.4,
    gradientEnabled = false,
    gradientR = 0.20, gradientG = 0.20, gradientB = 0.80, gradientA = 1,
    gradientDir = "HORIZONTAL",
    opacity   = 1.0,
    showTimer = true,
    timerPosition = "right",
    timerSize = 11,
    timerX    = 0,
    timerY    = 0,
    showName  = true,
    namePosition = "left",
    nameSize  = 11,
    nameX     = 0,
    nameY     = 0,
    showSpark = true,
    iconDisplay = "none",
    iconSize    = 24,
    iconX       = 0,
    iconY       = 0,
    iconBorderSize = 0,
    stacksPosition = "center",
    stacksSize     = 11,
    stacksX        = 0,
    stacksY        = 0,
    stackThresholdEnabled = false,
    stackThreshold = 5,
    stackThresholdR = 0.8,
    stackThresholdG = 0.1,
    stackThresholdB = 0.1,
    stackThresholdA = 1,
    stackThresholdMaxEnabled = false,
    stackThresholdMax = 10,
    stackThresholdTicks = "",
    pandemicGlow = false,
    pandemicGlowStyle = 1,
    pandemicGlowColor = { r = 1, g = 1, b = 0 },
    pandemicGlowLines = 8,
    pandemicGlowThickness = 2,
    pandemicGlowSpeed = 4,
}
ns.TBB_DEFAULT_BAR = TBB_DEFAULT_BAR

--- Get tracked buff bars profile data (with lazy init)
function ns.GetTrackedBuffBars()
    if not CDM or not CDM.db then return { selectedBar = 1, bars = {} } end
    local p = CDM.db.profile
    if not p.trackedBuffBars then
        p.trackedBuffBars = { selectedBar = 1, bars = {} }
    end
    
    for i, bar in ipairs(p.trackedBuffBars.bars) do
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
    newBar.name = "Bar " .. (#tbb.bars + 1)
    newBar.id = "bar_" .. tostring(#tbb.bars + 1) .. "_" .. tostring(math.floor(GetTime() * 1000))
    tbb.bars[#tbb.bars + 1] = newBar
    tbb.selectedBar = #tbb.bars

    -- Auto-position: place new bar adjacent to the previous one
    -- Horizontal: stack above; Vertical: place to the right
    local p = CDM and CDM.db and CDM.db.profile
    if p then
        if not p.tbbPositions then p.tbbPositions = {} end
        local prevIdx = #tbb.bars - 1
        if prevIdx >= 1 then
            local prevBar = tbb.bars[prevIdx]
            local prevPosKey = prevBar.id or tostring(prevIdx)
            local prevPos = p.tbbPositions[prevPosKey]
            local prevCfg = tbb.bars[prevIdx]
            local newPosKey = newBar.id or tostring(#tbb.bars)
            if prevPos and prevPos.point then
                local px = prevPos.x or 0
                local py = prevPos.y or 0
                if newBar.verticalOrientation then
                    -- Vertical bars: place to the right of previous
                    local barW = (prevCfg and prevCfg.height or 24) + 4
                    p.tbbPositions[newPosKey] = {
                        point = prevPos.point, relPoint = prevPos.relPoint or prevPos.point, relativePoint = prevPos.relPoint or prevPos.point,
                        x = px + barW, y = py,
                    }
                else
                    -- Horizontal bars: place above previous
                    local barH = (prevCfg and prevCfg.height or 24) + 4
                    p.tbbPositions[newPosKey] = {
                        point = prevPos.point, relPoint = prevPos.relPoint or prevPos.point, relativePoint = prevPos.relPoint or prevPos.point,
                        x = px, y = py + barH,
                    }
                end
            end
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
local tbbTickFrame
local function RefreshTBBTickFrameState()
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
local _tbbRebuildPending = false

function ns.GetTBBFrame(idx)
    return tbbFrames[idx]
end

-------------------------------------------------------------------------------
--  Per-bar grouping helpers
--  A bar is "grouped" (checked) when cfg.grouped ~= false (default checked).
--  All checked bars form ONE group in index order: the first ENABLED checked
--  bar is the group anchor (owns the position/mover), later checked bars chain
--  to it and share its width/height. Unchecked bars are fully independent.
-------------------------------------------------------------------------------
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

local CDM_FONT_FALLBACK = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\fonts\\Expressway.TTF"
local function GetCDMFont()
    if _G.KT and _G.KT.FONT_PATH then return _G.KT.FONT_PATH end
    if KT and KT.FONT_PATH then return KT.FONT_PATH end
    return CDM_FONT_FALLBACK
end
local function GetTBBOutline()
    return "OUTLINE"
end
local function GetTBBUseShadow()
    return false
end
local function SetTBBFont(fs, font, size)
    if not (fs and fs.SetFont) then return end
    local outline = GetTBBOutline()
    fs:SetFont(font, size, outline)
    if GetTBBUseShadow() then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
    else
        fs:SetShadowOffset(0, 0)
    end
end

local function CreateTrackedBuffBarFrame(parent, idx)
    -- wrapFrame is the top-level container for bar + icon + border.
    -- Positioning, show/hide, and unlock mode all operate on wrapFrame.
    -- The StatusBar is a child of wrapFrame so the border can use SetAllPoints
    -- on wrapFrame for a pixel-perfect fit (same pattern as the cast bar).
    local wrapFrame = CreateFrame("Frame", "CDM_TBBWrap" .. idx, parent)
    wrapFrame:SetFrameStrata("MEDIUM")
    wrapFrame:SetFrameLevel(10)

    local bar = CreateFrame("StatusBar", "CDM_TBB" .. idx, wrapFrame)
    if bar.EnableMouseClicks then bar:EnableMouseClicks(false) end
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0.65)
    wrapFrame._bar = bar

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.4)
    wrapFrame._bg = bg

    -- Spark
    local spark = bar:CreateTexture(nil, "OVERLAY", nil, 2)
    spark:SetTexture("Interface\\AddOns\\KullThranUI\\Modules\\Nameplates\\Media\\cast_spark.tga")
    spark:SetBlendMode("ADD")
    spark:Hide()
    wrapFrame._spark = spark

    -- Gradient clip frame (full-bar gradient masked to fill width)
    wrapFrame._gradClip = nil
    wrapFrame._gradTex = nil

    -- Text overlay: always sits above the fill texture and gradient clip
    local textOverlay = CreateFrame("Frame", nil, bar)
    textOverlay:SetAllPoints(bar)
    textOverlay:SetFrameLevel(bar:GetFrameLevel() + 3)
    wrapFrame._textOverlay = textOverlay

    -- Timer text
    local timerText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetTBBFont(timerText, GetCDMFont(), 11)
    timerText:SetTextColor(1, 1, 1, 0.9)
    timerText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    timerText:SetJustifyH("RIGHT")
    wrapFrame._timerText = timerText

    -- Name text (left side)
    local nameText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetTBBFont(nameText, GetCDMFont(), 11)
    nameText:SetWordWrap(false)
    nameText:SetTextColor(1, 1, 1, 0.9)
    nameText:SetPoint("LEFT", bar, "LEFT", 4, 0)
    nameText:SetJustifyH("LEFT")
    wrapFrame._nameText = nameText

    -- Stacks text (positioned relative to the StatusBar)
    local stacksText = textOverlay:CreateFontString(nil, "OVERLAY")
    SetTBBFont(stacksText, GetCDMFont(), 11)
    stacksText:SetTextColor(1, 1, 1, 0.9)
    stacksText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    stacksText:Hide()
    wrapFrame._stacksText = stacksText

    -- Icon: child of wrapFrame so it is part of the combined rect.
    local icon = CreateFrame("Frame", nil, wrapFrame)
    icon:SetSize(24, 24)
    icon:Hide()
    local iconTex = icon:CreateTexture(nil, "ARTWORK")
    iconTex:SetAllPoints()
    iconTex:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    icon._tex = iconTex
    wrapFrame._icon = icon

    -- Border: SetAllPoints(wrapFrame) so it covers bar + icon exactly.
    -- wrapFrame IS the combined rect, so this is always pixel-perfect.
    local bdrContainer = CreateFrame("Frame", nil, wrapFrame)
    bdrContainer:SetAllPoints(wrapFrame)
    bdrContainer:SetFrameLevel(wrapFrame:GetFrameLevel() + 5)
    bdrContainer:Hide()
    wrapFrame._barBorder = bdrContainer

    -- Pandemic glow overlay: covers the whole bar, above border
    local panGlowOverlay = CreateFrame("Frame", nil, wrapFrame)
    panGlowOverlay:SetAllPoints(wrapFrame)
    panGlowOverlay:SetFrameLevel(wrapFrame:GetFrameLevel() + 6)
    panGlowOverlay:SetAlpha(0)
    panGlowOverlay:EnableMouse(false)
    wrapFrame._pandemicGlowOverlay = panGlowOverlay

    -- Hidden Cooldown widget for DurationObject mirroring
    local cd = CreateFrame("Cooldown", nil, bar, "CooldownFrameTemplate")
    cd:SetAllPoints()
    cd:SetDrawSwipe(false)
    cd:SetDrawBling(false)
    cd:SetDrawEdge(false)
    cd:SetAlpha(0)
    cd:Hide()
    wrapFrame._cooldown = cd

    wrapFrame:Hide()
    return wrapFrame
end

-- Overlay para mostrar el umbral de stacks configurado sin depender de
-- comparaciones Lua contra valores seguros.
local THRESH_DEFAULT_TEX = "Interface\\Buttons\\WHITE8x8"
local function GetOrCreateStackThresholdOverlay(bar)
    local existing = bar._threshOverlay
    if existing then return existing end
    local sb = bar._bar
    if not sb then return nil end

    local overlay = CreateFrame("StatusBar", nil, sb)
    -- Configurar propiedades visuales iniciales de una vez
    overlay:SetStatusBarTexture(THRESH_DEFAULT_TEX)
    overlay:SetFrameLevel(sb:GetFrameLevel() + 2)
    overlay:SetMinMaxValues(0, 1)
    overlay:SetValue(0)
    overlay:SetAllPoints(sb:GetStatusBarTexture())
    overlay:Hide()

    bar._threshOverlay = overlay
    return overlay
end

local function RefreshStackThresholdOverlay(bar, cfg)
    if not cfg.stackThresholdEnabled then
        if bar._threshOverlay then bar._threshOverlay:Hide() end
        return
    end
    local overlay = GetOrCreateStackThresholdOverlay(bar)
    if not overlay then return end

    local texPath = ResolveTBBTexturePath(TBB_TEXTURES, cfg.texture or "none", "Interface\\Buttons\\WHITE8x8")
    overlay:SetStatusBarTexture(texPath)
    overlay:SetOrientation(cfg.verticalOrientation and "VERTICAL" or "HORIZONTAL")
    overlay:GetStatusBarTexture():SetVertexColor(
        cfg.stackThresholdR or 0.8,
        cfg.stackThresholdG or 0.1,
        cfg.stackThresholdB or 0.1,
        cfg.stackThresholdA or 1)

    -- Anchor to the main fill texture so the overlay is clipped to the
    -- filled portion of the bar (matters for passive stack-fill bars).
    overlay:ClearAllPoints()
    overlay:SetAllPoints(bar._bar:GetStatusBarTexture())

    local threshold = cfg.stackThreshold or 5
    overlay:SetMinMaxValues(threshold - 1, threshold)
    overlay:SetValue(0)
    overlay:Show()
end

local function UpdateStackThresholdValue(bar)
    local overlay = bar._threshOverlay
    if not overlay or not overlay:IsShown() then return end
    overlay:SetValue(bar._stackCount or 0)
end

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

local function ParseStackTickList(text)
    if type(text) ~= "string" or text == "" then return nil end

    -- Construir lista ordenada sin duplicados
    local uniq, result = {}, {}
    for segment in text:gmatch("([^,]+)") do
        local n = tonumber(segment:match("^%s*(.-)%s*$"))
        if n and n > 0 and not uniq[n] then
            uniq[n] = true
            result[#result + 1] = n
        end
    end
    if #result == 0 then return nil end
    table.sort(result)
    return result
end

-- Apply tick marks to a bar based on config.
-- sb: the StatusBar (actual bar or preview bar)
-- cfg: bar config table (needs stackThresholdTicks, stackThresholdMax)
-- tickCache: table to store tick textures
-- isVert: vertical orientation flag
-- tickParent: optional frame to parent ticks to (above overlay)
local function UpdateStackTickMarks(sb, cfg, tickCache, isVert, tickParent)
    local maxStacks = cfg.stackThresholdMax or 10

    -- Ocultar marcas existentes primero
    if tickCache then
        for idx = 1, #tickCache do tickCache[idx]:Hide() end
    end

    -- Verificar si las marcas están habilitadas
    if not (cfg.stackThresholdEnabled and cfg.stackThresholdMaxEnabled) then return end
    if not tickCache or maxStacks < 1 then return end

    local vals = ParseStackTickList(cfg.stackThresholdTicks)
    if not vals then return end

    local PP = KT and KT.PP
    local parent = tickParent or sb
    -- Asegurar que hay suficientes texturas en la caché
    for _ = #tickCache + 1, #vals do
        local tex = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetColorTexture(1, 1, 1, 1)
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
        tickCache[#tickCache + 1] = tex
    end

    -- Posicionar cada marca según orientación
    local onePx = PP and PP.Scale(1) or 1
    local barW, barH = sb:GetWidth(), sb:GetHeight()
    for i, v in ipairs(vals) do
        if v > maxStacks then break end  -- vals está ordenado, podemos cortar aquí
        local tex = tickCache[i]
        local frac = v / maxStacks
        tex:ClearAllPoints()
        if isVert then
            local yOff = PP and PP.Scale(barH * frac) or (barH * frac)
            tex:SetSize(barW, onePx)
            tex:SetPoint("BOTTOMLEFT", sb, "BOTTOMLEFT", 0, yOff)
        else
            local xOff = PP and PP.Scale(barW * frac) or (barW * frac)
            tex:SetSize(onePx, barH)
            tex:SetPoint("TOPLEFT", sb, "TOPLEFT", xOff, 0)
        end
        tex:Show()
    end
end
ns.ApplyTBBTickMarks = UpdateStackTickMarks

local function ApplyTrackedBuffBarSettings(bar, cfg)
    -- bar = wrapFrame (top-level container). bar._bar = the StatusBar child.
    if not bar or not cfg then return end
    local sb = bar._bar  -- StatusBar
    if not sb then return end
    local w = cfg.width or 200
    local h = cfg.height or 18
    local isVert = cfg.verticalOrientation
    bar._lastVertical = isVert  -- cached for per-frame spark re-anchor in tick
    local iconMode = cfg.iconDisplay or "none"
    local hasIcon = iconMode ~= "none"
    local iSize = h  -- icon always matches bar height

    -- Size wrapFrame to cover bar + icon (same as cast bar's castBarFrame).
    -- Icon and bar are positioned inside wrapFrame so the border is pixel-perfect.
    if isVert then
        -- Vertical: bar is h wide x w tall; icon adds iSize to height
        local totalH = hasIcon and (w + iSize) or w
        bar:SetSize(h, totalH)
    else
        -- Horizontal: bar is w wide x h tall; icon adds iSize to width
        local totalW = hasIcon and (w + iSize) or w
        bar:SetSize(totalW, h)
    end

    -- Position StatusBar inside wrapFrame
    sb:ClearAllPoints()
    if hasIcon then
        if isVert then
            if iconMode == "left" then
                -- Icon at bottom, bar above it
                sb:SetPoint("TOPLEFT",     bar, "TOPLEFT",     0, 0)
                sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, iSize)
            else
                -- Icon at top, bar below it
                sb:SetPoint("TOPLEFT",     bar, "TOPLEFT",     0, -iSize)
                sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
            end
        else
            if iconMode == "left" then
                -- Icon on left, bar to the right
                sb:SetPoint("TOPLEFT",     bar, "TOPLEFT",     iSize, 0)
                sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0,     0)
            else
                -- Icon on right, bar to the left
                sb:SetPoint("TOPLEFT",     bar, "TOPLEFT",     0,      0)
                sb:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -iSize, 0)
            end
        end
    else
        sb:SetAllPoints(bar)
    end

    -- Orientation
    sb:SetOrientation(isVert and "VERTICAL" or "HORIZONTAL")

    -- Texture (only re-set if changed to avoid fill flash)
    local texPath = ResolveTBBTexturePath(TBB_TEXTURES, cfg.texture or "none", "Interface\\Buttons\\WHITE8x8")
    if bar._lastTexPath ~= texPath then
        sb:SetStatusBarTexture(texPath)
        bar._lastTexPath = texPath
    end

    -- Fill color (user-defined, defaults to class color)
    local fR, fG, fB, fA = cfg.fillR or _tbbClassR, cfg.fillG or _tbbClassG, cfg.fillB or _tbbClassB, cfg.fillA or 1
    sb:GetStatusBarTexture():SetVertexColor(fR, fG, fB, fA)
    bar._baseFillR, bar._baseFillG, bar._baseFillB, bar._baseFillA = fR, fG, fB, fA

    -- Background color
    if bar._bg then
        bar._bg:SetColorTexture(cfg.bgR or 0, cfg.bgG or 0, cfg.bgB or 0, cfg.bgA or 0.4)
    end

    -- Gradient (clip frame approach: full-bar gradient masked to fill width)
    local fillTex = sb:GetStatusBarTexture()
    if cfg.gradientEnabled then
        local dir = cfg.gradientDir or "HORIZONTAL"

        fillTex:SetVertexColor(1, 1, 1, 0)

        if not bar._gradClip then
            local clip = CreateFrame("Frame", nil, sb)
            clip:SetClipsChildren(true)
            clip:SetFrameLevel(sb:GetFrameLevel() + 1)

            local tex = clip:CreateTexture(nil, "ARTWORK", nil, 1)
            tex:SetPoint("TOPLEFT",     sb, "TOPLEFT",     0, 0)
            tex:SetPoint("BOTTOMRIGHT", sb, "BOTTOMRIGHT", 0, 0)

            bar._gradClip = clip
            bar._gradTex = tex
        end

        -- Anchor the clip frame to the fill texture so it tracks
        -- automatically when Blizzard's SetTimerDuration animates the bar.
        -- The fill texture shrinks as the buff expires; anchoring to it
        -- means the clip follows without any per-tick width calculations.
        local clip = bar._gradClip
        clip:ClearAllPoints()
        clip:SetAllPoints(fillTex)

        bar._gradTex:SetTexture(texPath)
        bar._gradTex:SetVertexColor(1, 1, 1, 1)
        bar._gradTex:SetGradient(dir,
            CreateColor(fR, fG, fB, fA),
            CreateColor(cfg.gradientR or 0.20, cfg.gradientG or 0.20, cfg.gradientB or 0.80, cfg.gradientA or 1)
        )

        clip:Show()
        bar._gradientActive = true
    else
        if bar._gradClip then bar._gradClip:Hide() end
        bar._gradientActive = nil

        fillTex:SetVertexColor(fR, fG, fB, fA)
    end

    -- Opacity (target stored for smooth lerp in tick)
    bar._opacityTarget = cfg.opacity or 1.0
    if not bar._tbbReady then
        bar:SetAlpha(bar._opacityTarget)
    end

    -- Timer
    local timerPos = cfg.timerPosition or (cfg.showTimer and "right" or "none")
    if timerPos ~= "none" then
        bar._timerText:Show()
        local tSize = cfg.timerSize or 11
        SetTBBFont(bar._timerText, GetCDMFont(), tSize)
        bar._timerText:ClearAllPoints()
        if isVert then
            bar._timerText:SetPoint("TOP", sb, "TOP", cfg.timerX or 0, -8 + (cfg.timerY or 0))
            bar._timerText:SetJustifyH("CENTER")
        else
            local tX = cfg.timerX or 0
            local tY = cfg.timerY or 0
            if timerPos == "center" then
                bar._timerText:SetPoint("CENTER", sb, "CENTER", tX, tY)
                bar._timerText:SetJustifyH("CENTER")
            elseif timerPos == "top" then
                bar._timerText:SetPoint("BOTTOM", sb, "TOP", tX, 5 + tY)
                bar._timerText:SetJustifyH("CENTER")
            elseif timerPos == "bottom" then
                bar._timerText:SetPoint("TOP", sb, "BOTTOM", tX, -5 + tY)
                bar._timerText:SetJustifyH("CENTER")
            elseif timerPos == "left" then
                bar._timerText:SetPoint("LEFT", sb, "LEFT", 5 + tX, tY)
                bar._timerText:SetJustifyH("LEFT")
            else -- "right"
                bar._timerText:SetPoint("RIGHT", sb, "RIGHT", -5 + tX, tY)
                bar._timerText:SetJustifyH("RIGHT")
            end
        end
    else
        bar._timerText:Hide()
    end

    -- Spark
    if cfg.showSpark then
        local sparkAnchor = (bar._gradientActive and bar._gradClip) or sb:GetStatusBarTexture()
        bar._spark:SetSize(8, h)
        bar._spark:SetRotation(0)
        bar._spark:ClearAllPoints()
        if isVert then
            bar._spark:SetPoint("CENTER", sparkAnchor, "TOP", 0, 0)
        else
            bar._spark:SetPoint("CENTER", sparkAnchor, "RIGHT", 0, 0)
        end
        bar._spark:Show()
    else
        bar._spark:Hide()
    end

    -- Name text (hidden in vertical orientation)
    local namePos = cfg.namePosition or ((cfg.showName ~= false) and "left" or "none")
    if namePos ~= "none" and not isVert then
        bar._nameText:Show()
        local nSize = cfg.nameSize or 11
        SetTBBFont(bar._nameText, GetCDMFont(), nSize)
        bar._nameText:ClearAllPoints()
        local nX = cfg.nameX or 0
        local nY = cfg.nameY or 0
        if namePos == "center" then
            bar._nameText:SetPoint("CENTER", sb, "CENTER", nX, nY)
            bar._nameText:SetJustifyH("CENTER")
        elseif namePos == "top" then
            bar._nameText:SetPoint("BOTTOM", sb, "TOP", nX, 5 + nY)
            bar._nameText:SetJustifyH("CENTER")
        elseif namePos == "bottom" then
            bar._nameText:SetPoint("TOP", sb, "BOTTOM", nX, -5 + nY)
            bar._nameText:SetJustifyH("CENTER")
        elseif namePos == "right" then
            bar._nameText:SetPoint("RIGHT", sb, "RIGHT", -5 + nX, nY)
            bar._nameText:SetJustifyH("RIGHT")
        else -- "left"
            bar._nameText:SetPoint("LEFT", sb, "LEFT", 5 + nX, nY)
            bar._nameText:SetJustifyH("LEFT")
        end
        local hasTimer = (timerPos ~= "none")
        bar._nameText:SetWidth(w - 12 - (hasTimer and 45 or 0))
    else
        bar._nameText:Hide()
    end

    -- Icon: positioned inside wrapFrame
    if hasIcon and bar._icon then
        bar._icon:SetSize(iSize, iSize)
        bar._icon:ClearAllPoints()
        if isVert then
            if iconMode == "left" then
                bar._icon:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
            else
                bar._icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            end
        else
            if iconMode == "left" then
                bar._icon:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
            else
                bar._icon:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
            end
        end
        bar._icon:Show()
    elseif bar._icon then
        bar._icon:Hide()
    end

    -- Stacks text positioning
    if bar._stacksText then
        local sPos = cfg.stacksPosition or "center"
        if sPos == "none" then
            bar._stacksText:Hide()
            bar._stacksHidden = true
        else
            bar._stacksHidden = nil
            local sSize = cfg.stacksSize or 11
            local sX = cfg.stacksX or 0
            local sY = cfg.stacksY or 0
            SetTBBFont(bar._stacksText, GetCDMFont(), sSize)
            bar._stacksText:ClearAllPoints()
            if sPos == "top" then
                bar._stacksText:SetPoint("BOTTOM", sb, "TOP", sX, 5 + sY)
            elseif sPos == "bottom" then
                bar._stacksText:SetPoint("TOP", sb, "BOTTOM", sX, -5 + sY)
            elseif sPos == "left" then
                bar._stacksText:SetPoint("LEFT", sb, "LEFT", 5 + sX, sY)
            elseif sPos == "right" then
                bar._stacksText:SetPoint("RIGHT", sb, "RIGHT", -5 + sX, sY)
            else
                bar._stacksText:SetPoint("CENTER", sb, "CENTER", sX, sY)
            end
        end
    end

    -- Border: bdrContainer already has SetAllPoints(wrapFrame) from creation.
    -- wrapFrame IS the combined rect, so the border is always pixel-perfect.
    if bar._barBorder then
        local bSz = cfg.borderSize or 0
        if bSz > 0 then
            local PP = KT and KT.PP
            if PP then
                if not bar._barBorder._ppBorders then
                    PP.CreateBorder(bar._barBorder, cfg.borderR or 0, cfg.borderG or 0, cfg.borderB or 0, 1, bSz)
                else
                    PP.UpdateBorder(bar._barBorder, bSz, cfg.borderR or 0, cfg.borderG or 0, cfg.borderB or 0, 1)
                end
                bar._barBorder:Show()
            end
        else
            bar._barBorder:Hide()
        end
    end

    -- Stack threshold overlay (stacked StatusBar approach, secret-safe)
    RefreshStackThresholdOverlay(bar, cfg)

    -- Stack threshold tick marks (above the threshold overlay)
    if not bar._threshTicks then bar._threshTicks = {} end
    if not bar._tickOverlay then
        local to = CreateFrame("Frame", nil, sb)
        to:SetAllPoints(sb)
        to:SetFrameLevel(sb:GetFrameLevel() + 3)
        bar._tickOverlay = to
    end
    UpdateStackTickMarks(sb, cfg, bar._threshTicks, isVert, bar._tickOverlay)
    bar._ticksDirty = true  -- bar may not have valid dimensions yet; re-apply once laid out
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
                for _, sid in ipairs(cfg.spellIDs) do
                    local ok, result = pcall(C_UnitAuras.GetPlayerAuraBySpellID, sid)
                    if ok and result then
                        local dur = result.duration
                        local exp = result.expirationTime
                        local secretD = issecretvalue and issecretvalue(dur)
                        local secretE = issecretvalue and issecretvalue(exp)
                        if not secretD and not secretE and dur and exp and dur > 0 and exp > 0 then
                            bar._activeDuration = cfg.customDuration
                            bar._customStart = now - (cfg.customDuration - math.max(0, exp - now))
                        else
                            -- Secret or no duration: start timer from now
                            bar._activeDuration = cfg.customDuration
                            bar._customStart = now
                        end
                        break
                    end
                end
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
    if not TBB_ENABLED then return end
    if not CDM or not CDM.db then return end
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("cdm.buff_bars.rebuild")
    if InCombatLockdown() then
        _tbbRebuildPending = true
        if profileStarted then profiler:End("cdm.buff_bars.rebuild", profileStarted) end
        return
    end
    _tbbRebuildPending = false

    local tbb = ns.GetTrackedBuffBars()
    local bars = tbb.bars
    local p = CDM.db.profile
    if not p.tbbPositions then p.tbbPositions = {} end

    -- Hide bars beyond current count
    for i = #bars + 1, #tbbFrames do
        if tbbFrames[i] then tbbFrames[i]:Hide() end
    end

    local anyEnabled = false
    local lastGroupedBar = nil
    for i, cfg in ipairs(bars) do
        if not tbbFrames[i] then
            tbbFrames[i] = CreateTrackedBuffBarFrame(UIParent, i)
        end
        local bar = tbbFrames[i]

        if cfg.enabled == false then
            bar:Hide()
        else
            anyEnabled = true
            ApplyTrackedBuffBarSettings(bar, cfg)

            -- Icon texture: for popular buffs use the hardcoded icon, otherwise resolve from spell info
            if bar._icon and bar._icon._tex then
                local iconID = nil
                if cfg.popularKey then
                    -- Find the matching popular entry for its hardcoded icon
                    for _, pe in ipairs(TBB_POPULAR_BUFFS) do
                        if pe.key == cfg.popularKey then iconID = pe.icon; break end
                    end
                end
                if not iconID and cfg.spellID and cfg.spellID > 0 then
                    local spInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(cfg.spellID)
                    if spInfo then iconID = spInfo.iconID end
                end
                if iconID then bar._icon._tex:SetTexture(iconID) end
            end

            -- Name text: prefer stored name (preserves custom item/spell names),
            -- fall back to spell info only when no name was stored.
            local namePos2 = cfg.namePosition or ((cfg.showName ~= false) and "left" or "none")
            if namePos2 ~= "none" and bar._nameText then
                local displayName = cfg.name
                if (not displayName or displayName == "") and cfg.spellID and cfg.spellID > 0 then
                    local spInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(cfg.spellID)
                    displayName = spInfo and spInfo.name or ""
                end
                bar._nameText:SetText(displayName or "")
            end

            -- Saved position / grouping. Only CHECKED (cfg.grouped) bars chain;
            -- the first checked bar takes the independent branch (its own saved
            -- pos) and becomes the anchor, later checked bars chain to it.
            -- Unchecked bars always fall to the independent branch.
            local barGrouped = ns.TBBBarGrouped(cfg)
            if barGrouped and lastGroupedBar then
                -- Grouped: position relative to previous grouped bar
                local growDir = (tbb.groupGrowDirection or "DOWN"):upper()
                local spacing = tbb.groupSpacing or 2
                bar:ClearAllPoints()
                if growDir == "DOWN" then
                    bar:SetPoint("TOP", lastGroupedBar, "BOTTOM", 0, -spacing)
                elseif growDir == "UP" then
                    bar:SetPoint("BOTTOM", lastGroupedBar, "TOP", 0, spacing)
                elseif growDir == "RIGHT" then
                    bar:SetPoint("LEFT", lastGroupedBar, "RIGHT", spacing, 0)
                elseif growDir == "LEFT" then
                    bar:SetPoint("RIGHT", lastGroupedBar, "LEFT", -spacing, 0)
                end
            else
                -- Independent positioning (bar 1 always, or grouping disabled)
                local posKey = cfg.id or tostring(i)
                local pos = p.tbbPositions[posKey]
                if pos and pos.point then
                    -- Skip for unlock-anchored bars (anchor system is authority)
                    local unlockKey = "TBB_" .. posKey
                    local anchored = false
                    if not anchored or not bar:GetLeft() then
                        bar:ClearAllPoints()
                        if pos.scale then pcall(function() bar:SetScale(pos.scale) end) end
                        bar:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
                    end
                else
                    bar:ClearAllPoints()
                    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 200 - (i - 1) * ((cfg.height or 24) + 4))
                end
            end

            if barGrouped then lastGroupedBar = bar end

            -- Mark bar as ready but keep hidden; the tick will show it
            -- when the tracked buff is actually active on the player.
            bar._tbbReady = true
            bar._isPassive = nil
            bar._resolvedAuraID = nil
            bar._blizzChild = nil
            bar._customStart = nil
            bar._activeDuration = nil
            bar._lastLiveIcon = nil
            bar._lastLiveName = nil
            bar:Hide()
        end
    end

    if anyEnabled then
        if not tbbTickFrame then
            tbbTickFrame = CreateFrame("Frame")
            local tbbAccum = 0
            tbbTickFrame:SetScript("OnUpdate", function(self, elapsed)
                -- Smooth opacity lerp for all active bars
                local lerpSpeed = elapsed * 8
                for _, f in ipairs(tbbFrames) do
                    if f and f._opacityTarget then
                        local cur = f:GetAlpha()
                        local tgt = f._opacityTarget
                        if math.abs(cur - tgt) > 0.005 then
                            f:SetAlpha(cur + (tgt - cur) * math.min(1, lerpSpeed))
                        elseif cur ~= tgt then
                            f:SetAlpha(tgt)
                        end
                    end
                end
                tbbAccum = tbbAccum + (elapsed or 0)
                -- Run the expensive update on a bounded event-driven cadence: the
                -- aura/stack/texture pass runs at 5 Hz; UNIT_AURA/cast events
                -- also request an immediate coalesced refresh. Native status
                -- bars animate their fill themselves, while opacity interpolation
                -- above remains per-frame, so this avoids repeated aura API scans
                -- without making the visible animation less smooth.
                if tbbAccum < 0.2 then return end
                self._lastDt = tbbAccum
                tbbAccum = 0
                ns.UpdateTrackedBuffBarTimers()
            end)
        end
        if ns.UpdateTrackedBuffBarTimers then
            ns.UpdateTrackedBuffBarTimers()
        else
            RefreshTBBTickFrameState()
        end
    elseif tbbTickFrame then
        tbbTickFrame:Hide()
    end

    -- Re-register all bars with unlock mode so new/removed bars are reflected
    if ns.RegisterTBBUnlockElements then
        ns.RegisterTBBUnlockElements()
    end
    if ns.RefreshTBBResolvedIDs then
        ns.RefreshTBBResolvedIDs()
    end
    -- Gate event listeners based on whether any bars are configured
    ns.RefreshBuffBarGating()
    if profileStarted then profiler:End("cdm.buff_bars.rebuild", profileStarted) end
end

-------------------------------------------------------------------------------
--  TBB Applications hook: mirrors Blizzard CDM's Applications Show/Hide onto
--  our _stacksText, same pattern as the main CDM bars' HookBlizzChildApplications.
--  Blizzard only shows the Applications frame when stacks > 1, so we trust
--  its Show/Hide as the gate -- no value comparison needed.
-------------------------------------------------------------------------------
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
                        UpdateStackTickMarks(sb, cfg, bar._threshTicks, cfg.verticalOrientation, bar._tickOverlay)
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
            bar._directBlizzChild = directChild
            local isActive = directChild and directChild.IsShown and directChild:IsShown() or false
            for _, sid in ipairs(cfg.spellIDs) do
                local sidChild = buffChildCache[sid] or allChildCache[sid]
                if activeCache[sid] or (IsCoreBuffActive and IsCoreBuffActive(sid, sid, sidChild)) then
                    isActive = true
                    break
                end
            end

            -- Fallback: check player auras directly
            if not isActive or not bar._customStart then
                for _, sid in ipairs(cfg.spellIDs) do
                    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, sid)
                    if ok and aura then
                        isActive = true
                        if not bar._customStart then
                            local dur = aura.duration
                            local exp = aura.expirationTime
                            local secretD = issecretvalue and issecretvalue(dur)
                            local secretE = issecretvalue and issecretvalue(exp)
                            if not secretD and not secretE and dur and exp and dur > 0 and exp > 0 then
                                bar._activeDuration = cfg.customDuration
                                bar._customStart = now - (cfg.customDuration - math.max(0, exp - now))
                            else
                                bar._activeDuration = cfg.customDuration
                                bar._customStart = now
                            end
                        end
                        break
                    end
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
                        UpdateStackTickMarks(bar._bar, cfg, bar._threshTicks, cfg.verticalOrientation, bar._tickOverlay)
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

            -- Check active state using the same caches the core CDM builds
            local blzChild = directChild
                          or buffChildCache[resolvedID] or buffChildCache[spellID]
                          or allChildCache[resolvedID] or allChildCache[spellID]
            local isActive = (directChild and directChild.IsShown and directChild:IsShown())
                          or (IsCoreBuffActive and IsCoreBuffActive(resolvedID, spellID, blzChild))
                          or activeCache[resolvedID] or activeCache[spellID]
            if not isActive then
                if IsBufChildActive and IsBufChildActive(blzChild) then
                    isActive = true
                end
            end
            -- Fallback: check player auras directly (covers passives and
            -- buffs not tracked by Blizzard CDM)
            if not isActive then
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, resolvedID)
                if not ok or not aura then
                    ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
                end
                if ok and aura then isActive = true end
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
                        UpdateStackTickMarks(bar._bar, cfg, bar._threshTicks, cfg.verticalOrientation, bar._tickOverlay)
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
    return _tbbRebuildPending
end

-------------------------------------------------------------------------------
--  Register Tracked Buff Bars with unlock mode
-------------------------------------------------------------------------------
function ns.RegisterTBBUnlockElements()
    if not TBB_ENABLED then return end
    if not KT or not KT.RegisterMovableElements then return end
    if not CDM or not CDM.db then return end
    local tbb = ns.GetTrackedBuffBars()
    local bars = tbb.bars
    if not bars or #bars == 0 then return end
    local groupAnchor = ns.TBBGroupAnchorIndex()

    local elements = {}
    for i, cfg in ipairs(bars) do
        local idx = i
        local posKey = cfg.id or tostring(idx)
        local bar = tbbFrames[idx]
        local isGrouped = ns.TBBBarGrouped(cfg)
        
        if bar and ((not isGrouped) or (idx == groupAnchor)) then
            elements[#elements + 1] = {
                key = "TBB_" .. posKey,
                label = "Buff Bar: " .. (cfg.name or ("Bar " .. idx)) .. (isGrouped and " (Group)" or ""),
                group = "Cooldown Manager",
                order = 650,
                getFrame = function() return tbbFrames[idx] end,
                getMoverSize = function()
                    local tbbData = ns.GetTrackedBuffBars()
                    local cBars = tbbData and tbbData.bars
                    
                    if isGrouped and cBars then
                        local growDir = (tbbData.groupGrowDirection or "DOWN"):upper()
                        local spacing = tbbData.groupSpacing or 2
                        local gW, gH = 0, 0
                        local count = 0
                        for j, c in ipairs(cBars) do
                            if c.enabled ~= false and ns.TBBBarGrouped(c) then
                                count = count + 1
                                local w = c.width or 200
                                local h = c.height or 24
                                local isVert = c.verticalOrientation
                                local hasIcon = (c.iconDisplay or "none") ~= "none"
                                local bw = isVert and h or (hasIcon and (w + h) or w)
                                local bh = isVert and (hasIcon and (w + h) or w) or h
                                if growDir == "DOWN" or growDir == "UP" then
                                    gW = math.max(gW, bw)
                                    gH = gH + bh
                                else
                                    gW = gW + bw
                                    gH = math.max(gH, bh)
                                end
                            end
                        end
                        if count > 1 then
                            if growDir == "DOWN" or growDir == "UP" then
                                gH = gH + spacing * (count - 1)
                            else
                                gW = gW + spacing * (count - 1)
                            end
                        end
                        if gW > 0 and gH > 0 then
                            return gW, gH
                        end
                    end
                end,
                getSize = function()
                    local tbbData = ns.GetTrackedBuffBars()
                    local c = tbbData and tbbData.bars and tbbData.bars[idx]
                    return c and c.width or 200, c and c.height or 24
                end,
                setEditableSize = function(_, w, h)
                    local tbbData = ns.GetTrackedBuffBars()
                    local c = tbbData and tbbData.bars and tbbData.bars[idx]
                    if c then
                        c.width = w
                        c.height = h
                        ns.BuildTrackedBuffBars()
                    end
                end,
                savePosition = function(_, point, relPoint, x, y, scale)
                    local p = CDM.db.profile
                    if not p.tbbPositions then p.tbbPositions = {} end
                    p.tbbPositions[posKey] = { point = point, relPoint = relPoint, relativePoint = relPoint, x = x, y = y, scale = scale }
                    local f = tbbFrames[idx]
                    if f then
                        if scale then pcall(function() f:SetScale(scale) end) end
                        f:ClearAllPoints()
                        f:SetPoint(point, UIParent, relPoint or point, x, y)
                    end
                    ns.BuildTrackedBuffBars()
                end,
                loadPosition = function()
                    local p = CDM.db.profile
                    local pos = p.tbbPositions and p.tbbPositions[posKey]
                    if pos and not pos.relativePoint and pos.relPoint then pos.relativePoint = pos.relPoint end
                    return pos
                end,
                getScale = function()
                    local p = CDM.db.profile
                    local pos = p.tbbPositions and p.tbbPositions[posKey]
                    return pos and pos.scale or 1.0
                end,
                clearPosition = function()
                    local p = CDM.db.profile
                    if p.tbbPositions then p.tbbPositions[posKey] = nil end
                end,
                applyPosition = function()
                    ns.BuildTrackedBuffBars()
                end,
            }
        end
    end

    if #elements > 0 then
        KT:RegisterMovableElements(elements)
    end
end
_G._CDM_RegisterTBBUnlock = ns.RegisterTBBUnlockElements






