local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("PartyFrames")
Mod.ArenaDRData = _G.KUI_ARENA_DR_DATA or { spells = {}, categories = {}, categoryOrder = {}, resetTime = 16.5 }

local _G = _G
local UIParent = UIParent
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UnitExists = _G.UnitExists
local UnitName = _G.UnitName
local UnitClass = _G.UnitClass
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitHealthMissing = _G.UnitHealthMissing
local UnitHealthPercent = _G.UnitHealthPercent
local UnitPower = _G.UnitPower
local UnitPowerMax = _G.UnitPowerMax
local UnitGetTotalAbsorbs = _G.UnitGetTotalAbsorbs
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitIsConnected = _G.UnitIsConnected
local UnitIsAFK = _G.UnitIsAFK
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned
local UnitIsUnit = _G.UnitIsUnit
local UnitInRange = _G.UnitInRange
local UnitPhaseReason = _G.UnitPhaseReason
local CheckInteractDistance = _G.CheckInteractDistance
local UnitClassBase = _G.UnitClassBase
local UnitGUID = _G.UnitGUID
local UnitIsGroupLeader = _G.UnitIsGroupLeader
local UnitIsGroupAssistant = _G.UnitIsGroupAssistant
local GetReadyCheckStatus = _G.GetReadyCheckStatus
local GetRaidTargetIndex = _G.GetRaidTargetIndex
local SetRaidTargetIconTexture = _G.SetRaidTargetIconTexture
local C_Spell = _G.C_Spell
local GetSpecializationInfo = _G.GetSpecializationInfo
local GetNumGroupMembers = _G.GetNumGroupMembers
local GetRaidRosterInfo = _G.GetRaidRosterInfo
local IsInRaid = _G.IsInRaid
local IsInInstance = _G.IsInInstance
local C_Timer = _G.C_Timer
local C_UnitAuras = _G.C_UnitAuras
local AuraUtil = _G.AuraUtil
local C_CurveUtil = _G.C_CurveUtil
local CurveConstants = _G.CurveConstants
local GameTooltip = _G.GameTooltip
local Enum = _G.Enum
local CreateColor = _G.CreateColor
local RegisterUnitWatch = _G.RegisterUnitWatch
local UnregisterUnitWatch = _G.UnregisterUnitWatch
local AbbreviateNumbers = _G.AbbreviateNumbers
local C_StringUtil = _G.C_StringUtil
local issecretvalue = _G.issecretvalue
local canaccessvalue = _G.canaccessvalue

-- C_UI.IsSecret is the 12.x API (see KT.IsSecret in KullThranUI/Core.lua).
-- The lowercase globals (issecretvalue/canaccessvalue) are legacy and are not
-- guaranteed to exist, so they are only used as a fallback here. This helper
-- must stay defined above the first reference to it in this file.
local function IsSecretValue(value)
    if C_UI and C_UI.IsSecret then
        local ok, secret = pcall(C_UI.IsSecret, value)
        if ok and secret == true then return true end
    end
    if _G.IsSecretValue then
        local ok, secret = pcall(_G.IsSecretValue, value)
        if ok and secret == true then return true end
    end
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, value)
        if ok and secret == true then return true end
    end
    if canaccessvalue then
        local ok, accessible = pcall(canaccessvalue, value)
        if ok and accessible == false then return true end
    end
    return false
end

local GetPlayerAuraBySpellID = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
local GetUnitAuraBySpellID = C_UnitAuras and C_UnitAuras.GetUnitAuraBySpellID
local LibRangeCheck = LibStub("LibRangeCheck-3.0", true)
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local CUSTOM_CLASS_COLORS = _G.CUSTOM_CLASS_COLORS
local MODE_ORDER = { "party", "raid", "raid40", "arena", "arenaEnemy", "boss" }

local function GetAuraFitLimits(frameWidth, db, mode)
    db = db or {}
    local width = math.max(0, tonumber(frameWidth) or tonumber(db.frameWidth) or 125)
    local size = math.max(10, math.min(28, tonumber(db.auraIconSize) or 18))
    local spacing = math.max(0, math.min(8, tonumber(db.auraIconSpacing) or 0))
    local isRaidMode = mode == "raid" or mode == "raid40"
    local debuffSize = math.max(size, isRaidMode and 22 or 24)
    local availablePerSide = math.max(0, (width - 8) * 0.5)
    local buffFit = math.floor((availablePerSide + spacing) / math.max(1, size + spacing))
    local debuffFit = math.floor((availablePerSide + spacing) / math.max(1, debuffSize + spacing))
    return math.max(0, math.min(5, buffFit)), math.max(0, math.min(5, debuffFit))
end

ns.GetAuraFitLimits = GetAuraFitLimits

-- ---------------------------------------------------------------------------
-- Module-owned event host. Blizzard's addon profiler bills an entire handler
-- call tree to the addon whose execution context CREATED the frame the handler
-- entered through. This host is born here, in the PartyFrames main chunk, so
-- every event KUI Party Frames handles is attributed to KullThranUI_PartyFrames.
-- AceEvent's shared AceEvent30Frame belongs to the parent addon (KullThranUI)
-- and was billing all of this module's work to the root. Mirrors the
-- module-owned shell pattern keeps profiler attribution local.
-- The dispatcher preserves AceEvent's calling convention: fn(Mod, event, ...).
-- Stored on ns (not as file locals) to stay under the 200-local main-chunk cap.
-- ---------------------------------------------------------------------------
ns.PF_EventHandlers = ns.PF_EventHandlers or {}
ns.PF_EventFrame = ns.PF_EventFrame or CreateFrame("Frame")
ns.PF_EventFrame:SetScript("OnEvent", function(_, event, ...)
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("party.event.dispatch")
    local handler = ns.PF_EventHandlers[event] or event
    local fn = Mod[handler]
    if fn then fn(Mod, event, ...) end
    if profileStarted then profiler:End("party.event.dispatch", profileStarted) end
end)
Mod.eventFrame = ns.PF_EventFrame

function Mod:RegisterModuleEvent(event, handler)
    ns.PF_EventHandlers[event] = handler
    ns.PF_EventFrame:RegisterEvent(event)
end

-- Duration countdown driver. Runs OnUpdate only while at least one unit frame
-- is shown and disarms itself as soon as the last one is hidden, replacing the
-- permanent 0.2s C_Timer ticker. Re-armed on every path that can show frames.
-- The heavy pass keeps the original 0.2s cadence; the frame stays shown (but
-- idle) until the next boundary so hiding disarms within at most one step.
ns.PF_DurationDriver = ns.PF_DurationDriver or CreateFrame("Frame")
ns.PF_DurationDriver:SetScript("OnUpdate", function(self, elapsed)
    Mod._durationDriverElapsed = (Mod._durationDriverElapsed or 0) + elapsed
    if Mod._durationDriverElapsed < 0.2 then return end
    Mod._durationDriverElapsed = 0
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("party.duration.driver")
    local updated = Mod:CentralAuraUpdate()
    if profileStarted then profiler:End("party.duration.driver", profileStarted) end
    if updated then return end
    Mod._durationDriverArmed = nil
    self:Hide()
end)
Mod._durationIcons = Mod._durationIcons or {}

function Mod:ArmAuraDurationDriver()
    if not Mod._durationIcons or next(Mod._durationIcons) == nil then
        Mod._durationDriverArmed = nil
        ns.PF_DurationDriver:Hide()
        return
    end
    if Mod._durationDriverArmed then return end
    Mod._durationDriverArmed = true
    Mod._durationDriverElapsed = 0
    ns.PF_DurationDriver:Show()
end

-- UNIT_AURA coalescer. In a large raid UNIT_AURA can burst many times per
-- frame (any HoT/DoT/stack change on any member). Batching the flush per
-- distinct unit per rendered frame turns N rescans into at most one scan per
-- unit per frame. The coalescer self-disarms
-- while idle, so it costs nothing between bursts. Stored on ns/Mod (not as
-- file locals) to keep the main chunk under the 200-local cap.
ns.PF_AuraFlushDriver = ns.PF_AuraFlushDriver or CreateFrame("Frame")
ns.PF_AuraFlushDriver:SetScript("OnUpdate", function(self)
    local pending = Mod._pendingAuraUnits
    if not pending or next(pending) == nil then
        Mod._auraFlushQueued = nil
        self:Hide()
        return
    end
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("party.aura.flush")
    for unit in pairs(pending) do
        pending[unit] = nil
        Mod:FlushUnitAuras(unit)
    end
    if profileStarted then profiler:End("party.aura.flush", profileStarted) end
end)

-- Shield changes can arrive in large bursts in raids. Keep them independent
-- from the full unit painter and spread the work over frames, matching the
-- bounded dirty-queue model used by the aura path above.
ns.PF_AbsorbFlushDriver = ns.PF_AbsorbFlushDriver or CreateFrame("Frame")
ns.PF_AbsorbFlushDriver:SetScript("OnUpdate", function(self)
    local pending = Mod._pendingAbsorbUnits
    if not pending or next(pending) == nil then
        Mod._absorbFlushQueued = nil
        self:Hide()
        return
    end
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("party.absorb.flush")
    local processed = 0
    for unit in pairs(pending) do
        pending[unit] = nil
        Mod:FlushUnitAbsorbs(unit)
        processed = processed + 1
        if processed >= 20 then break end
    end
    if profileStarted then profiler:End("party.absorb.flush", profileStarted) end
    if next(pending) == nil then
        Mod._absorbFlushQueued = nil
        self:Hide()
    end
end)

-- ---------------------------------------------------------------------------
-- Roster-scoped UNIT_* dispatcher (Grid2 / DandersFrames Core/RosterEvents.lua
-- pattern). RegisterEvent("UNIT_AURA"/"UNIT_HEALTH"/...) is GLOBAL: it fires
-- for every unit token in the game (nameplates, mobs, pets, targets...), a
-- firehose in a 40-man raid. Danders keeps one hidden frame per roster unit
-- (player + party1-4 + raid1-40 + arena1-5), each with a single
-- RegisterUnitEvent(event, unit), so events only arrive for units we display.
-- Per-unit frames are born inside OnEvent dispatch on PartyFrames' own event
-- frame, so all of this work is attributed to KullThranUI_PartyFrames in nap.
-- Stored on ns/Mod (not file locals) to stay under the 200-local main-chunk cap.
-- ---------------------------------------------------------------------------
ns.PF_RosterUnitEvents = {
    "UNIT_AURA", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_FREQUENT",
    "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_CONNECTION", "UNIT_NAME_UPDATE",
    "UNIT_IN_RANGE_UPDATE", "UNIT_ABSORB_AMOUNT_CHANGED",
}

function Mod:GetRosterUnitFrame(unit)
    Mod._rosterFrames = Mod._rosterFrames or {}
    local f = Mod._rosterFrames[unit]
    if f then return f end
    f = CreateFrame("Frame")
    f:Hide()
    f._unit = unit
    f:SetScript("OnEvent", function(self, event)
        if event == "UNIT_AURA" then
            Mod:OnUnitAura(event, self._unit)
        elseif event == "UNIT_IN_RANGE_UPDATE" then
            Mod:OnUnitRange(event, self._unit)
        elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" then
            Mod:OnUnitAbsorb(event, self._unit)
        else
            Mod:OnUnitEvent(event, self._unit)
        end
    end)
    Mod._rosterFrames[unit] = f
    return f
end

function Mod:BuildRosterUnitSet()
    local set = { player = true }
    if _G.IsInRaid and _G.IsInRaid() then
        local n = _G.GetNumGroupMembers and _G.GetNumGroupMembers() or 0
        for i = 1, n do set["raid" .. i] = true end
    elseif _G.IsInGroup and _G.IsInGroup() then
        local n = _G.GetNumGroupMembers and _G.GetNumGroupMembers() or 0
        for i = 1, n - 1 do set["party" .. i] = true end
    end
    -- Arena enemies only exist in arena; registering them elsewhere is inert.
    for i = 1, 5 do set["arena" .. i] = true end
    for i = 1, 5 do set["boss" .. i] = true end
    return set
end

function Mod:RebuildRosterEvents()
    local newSet = self:BuildRosterUnitSet()
    local oldSet = Mod._rosterUnits or {}
    Mod._rosterUnits = newSet
    for unit in pairs(oldSet) do
        if not newSet[unit] then
            local f = Mod._rosterFrames and Mod._rosterFrames[unit]
            if f then
                for _, evt in ipairs(ns.PF_RosterUnitEvents) do
                    f:UnregisterEvent(evt)
                end
            end
        end
    end
    for unit in pairs(newSet) do
        if not oldSet[unit] then
            local f = self:GetRosterUnitFrame(unit)
            for _, evt in ipairs(ns.PF_RosterUnitEvents) do
                f:RegisterUnitEvent(evt, unit)
            end
        end
    end
end

local ROLE_ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3, NONE = 4 }
local ROLE_COLORS = {
    TANK = { r = 0.24, g = 0.52, b = 1.00 },
    HEALER = { r = 0.20, g = 0.86, b = 0.45 },
    DAMAGER = { r = 0.92, g = 0.34, b = 0.25 },
}
local PF_STATIC = {
    profileAuto = "auto",
    augmentationSpecID = 1473,
    roleCoords = {
        TANK = { 0, 0.296875, 0.296875, 0.65 },
        HEALER = { 0.296875, 0.59375, 0, 0.296875 },
        DAMAGER = { 0.296875, 0.59375, 0.296875, 0.65 },
    },
    testClassColors = {
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
        PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
        PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
        MAGE = { r = 0.25, g = 0.78, b = 0.92 },
        ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    },
    textureBG = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga",
    whiteTexture = "Interface\\Buttons\\WHITE8x8",
    partyVerticalNameLeftInset = 24,
}

local TEXTURE_FILL = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"
local ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\UnitFramesIcons\\"
local ROLE_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Modules\\Tooltip\\Icons\\"
local DEFAULT_FONT_NAME = KT.DEFAULT_FONT_NAME or "AAA_ITC_Avant_Garde"
local DEFAULT_FONT_PATH = KT.DEFAULT_FONT_PATH or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local DEFAULT_ABSORB_COLOR = { r = 0.11, g = 1.00, b = 0.62, a = 0.82 }
local OFFLINE_HEALTH_COLOR = { r = 0.52, g = 0.54, b = 0.57, a = 0.9 }
local OFFLINE_POWER_COLOR = { r = 0.34, g = 0.35, b = 0.38, a = 0.9 }

local AURA_DEFAULTS = {
    showAuras = true,
    showBuffs = false,
    showDebuffs = true,
    showDispelOverlay = true,
    showCrowdControl = true,
    showArenaTrinket = true,
    showArenaDR = true,
    arenaTrinketIconSize = 40,
    arenaDRIconSize = 32,
    arenaTrinketSide = "RIGHT",
    arenaSpecIconSide = "LEFT",
    arenaDRSide = "LEFT",
    showMissingBuffs = true,
    auraIconSize = 18,
    auraIconSpacing = 0,
    auraMaxBuffs = 5,
    auraMaxDebuffs = 5,
    auraOnlyPlayerBuffs = true,
    auraShowAllDebuffs = true,
    auraAnchor = "BOTTOMRIGHT",
    debuffAnchor = "BOTTOMLEFT",
    debuffGrowthH = "RIGHT",
    debuffGrowthV = "DOWN",
    buffIconsOffsetX = 0,
    buffIconsOffsetY = 0,
    debuffIconsOffsetX = 0,
    debuffIconsOffsetY = 0,
    auraIconOffsetX = 0,
    auraIconOffsetY = 0,
    missingBuffOffsetX = 0,
    missingBuffOffsetY = 0,
    dispelOverlayAlpha = 1.00,
    dispelBorderThickness = 2,
    dispelGradientAlpha = 1.00,
    dispelGradientSize = 0.50,
    missingBuffIconSize = 30,
    auraSpellVisibility = {},
    auraSpellCatalog = {},
    showReadyCheckIcon = true,
    showLeaderIcon = true,
    showRaidTargetIcon = true,
    rangeFadeEnabled = true,
    rangeFadeAlpha = 0.45,
}

local DISPEL_COLORS = {
    Magic = { r = 0.20, g = 0.60, b = 1.00 },
    Curse = { r = 0.60, g = 0.00, b = 1.00 },
    Disease = { r = 0.60, g = 0.40, b = 0.00 },
    Poison = { r = 0.00, g = 0.60, b = 0.00 },
    Enrage = { r = 1.00, g = 0.45, b = 0.00 },
    Bleed = { r = 1.00, g = 0.00, b = 0.00 },
}

local DISPEL_BY_ENUM = {
    [1] = "Magic",
    [2] = "Curse",
    [3] = "Disease",
    [4] = "Poison",
    [9] = "Enrage",
    [11] = "Bleed",
}

local DISPEL_PRIORITY = {
    Bleed = 1,
    Enrage = 2,
    Magic = 3,
    Curse = 4,
    Disease = 5,
    Poison = 6,
}

local DISPEL_ENUM_BY_NAME = {
    Magic = 1,
    Curse = 2,
    Disease = 3,
    Poison = 4,
    Enrage = 9,
    Bleed = 11,
}

local dispelColorCurves = {}

local DEBUFF_FILTERS = {
    "HARMFUL|RAID",
    "HARMFUL|RAID_IN_COMBAT",
    "HARMFUL|CROWD_CONTROL",
    "HARMFUL|IMPORTANT",
}

local BUFF_DISPLAY_FILTERS = {
    "HELPFUL|PLAYER",
    "HELPFUL|RAID",
    "HELPFUL|RAID_IN_COMBAT",
    "HELPFUL|IMPORTANT",
    "HELPFUL|BIG_DEFENSIVE",
    "HELPFUL|EXTERNAL_DEFENSIVE",
}

local MISSING_BUFF_RULES = {
    DRUID = {
        key = "missingBuffCheckMark",
        name = "Mark of the Wild",
        icon = 136078,
        spellIDs = { 1126, 432661 },
    },
    PRIEST = {
        key = "missingBuffCheckStamina",
        name = "Power Word: Fortitude",
        icon = 135987,
        spellIDs = { 21562 },
    },
    MAGE = {
        key = "missingBuffCheckIntellect",
        name = "Arcane Intellect",
        icon = 135932,
        spellIDs = { 1459, 432778 },
    },
    WARRIOR = {
        key = "missingBuffCheckAttackPower",
        name = "Battle Shout",
        icon = 132333,
        spellIDs = { 6673 },
    },
    SHAMAN = {
        key = "missingBuffCheckSkyfury",
        name = "Skyfury",
        icon = 4630367,
        spellIDs = { 462854 },
    },
    EVOKER = {
        key = "missingBuffCheckBronze",
        name = "Blessing of the Bronze",
        icon = 4622448,
        spellIDs = { 381748, 381732, 381741, 381746, 381749, 381750, 381751, 381752, 381753, 381754, 381756, 381757, 381758 },
    },
}
local SAMPLE_AURA_CATALOG = {
    { spellID = 118, auraType = "debuff", name = "Polymorph", icon = 136071 },
    { spellID = 980, auraType = "debuff", name = "Agony", icon = 136139 },
    { spellID = 589, auraType = "debuff", name = "Shadow Word: Pain", icon = 136207 },
    { spellID = 8680, auraType = "debuff", name = "Wound Poison", icon = 134197 },
    { spellID = 388539, auraType = "debuff", name = "Rend", icon = 132155 },
    { spellID = 228318, auraType = "debuff", name = "Enrage", icon = 132152 },
    { spellID = 2094, auraType = "debuff", name = "Blind", icon = 136175 },
}
local BLIZZARD_CLASS_COLORS = {
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },
    DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },
    DRUID = { r = 1.00, g = 0.49, b = 0.04 },
    EVOKER = { r = 0.20, g = 0.58, b = 0.50 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
    MAGE = { r = 0.25, g = 0.78, b = 0.92 },
    MONK = { r = 0.00, g = 1.00, b = 0.60 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    PRIEST = { r = 1.00, g = 1.00, b = 1.00 },
    ROGUE = { r = 1.00, g = 0.96, b = 0.41 },
    SHAMAN = { r = 0.00, g = 0.44, b = 0.87 },
    WARLOCK = { r = 0.53, g = 0.53, b = 0.93 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
}

local TEST_UNITS = {
    { name = "Tankerino", class = "WARRIOR", role = "TANK", health = 0.98, power = 0.85, maxHealth = 100000, absorb = 0.20 },
    { name = "Healsworth", class = "PRIEST", role = "HEALER", health = 0.92, power = 0.90, maxHealth = 85000, absorb = 0.10 },
    { name = "Player", class = "PALADIN", role = "DAMAGER", health = 0.76, power = 0.65, maxHealth = 90000, absorb = 0.05, isPlayer = true },
    { name = "Alexandros", class = "MAGE", role = "DAMAGER", health = 0, power = 0, maxHealth = 75000, absorb = 0, status = "Dead" },
    { name = "Xx", class = "ROGUE", role = "DAMAGER", health = 0.34, power = 0.55, maxHealth = 70000, absorb = 0.12, status = "Offline" },
}

local TEST_AURA_DEBUFFS = {
    { icon = 136071, spellID = 118, dispelType = "Magic" },
    { icon = 136139, spellID = 980, dispelType = "Curse" },
    { icon = 136207, spellID = 589, dispelType = "Magic" },
    { icon = 132155, spellID = 388539, dispelType = "Bleed" },
    { icon = 132140, spellID = 431491, dispelType = "Bleed" },
    { icon = 132152, spellID = 228318, dispelType = "Enrage" },
    { icon = 136066, spellID = 55078, dispelType = "Disease" },
    { icon = 136067, spellID = 8680, dispelType = "Poison" },
    { icon = 135781, spellID = 209858, dispelType = "Poison" },
    { icon = 136182, spellID = 2094, dispelType = "Magic" },
    { icon = 132298, spellID = 339, dispelType = "Magic" },
    { icon = 237514, spellID = 115078, dispelType = "Magic" },
    { icon = 135807, spellID = 2120, dispelType = "Magic" },
    { icon = 236216, spellID = 316099, dispelType = "Magic" },
    { icon = 135945, spellID = 3600, dispelType = "Disease" },
    { icon = 463565, spellID = 25771, dispelType = "Magic" },
}

local PROFILE_PRESETS = {
    dps_tank = {
        label = "DPS / Tank",
        party = {
            frameWidth = 235,
            frameHeight = 41,
            frameScale = 1,
            framePadding = 1,
            frameSpacing = 10,
            growDirection = "VERTICAL",
            growthAnchor = "CENTER",
            showPlayer = false,
            colorByClass = true,
            showAbsorbBar = true,
            showPowerBar = false,
            powerBarHeight = 4,
            healthTexture = TEXTURE_FILL,
            absorbBarTexture = TEXTURE_FILL,
            healthTextFormat = "CURRENTMAX",
            healthTextAbbreviate = true,
            textFont = DEFAULT_FONT_NAME,
            textOutline = "OUTLINE",
            nameFontSize = 15,
            healthTextFontSize = 12,
        },
        raid = {
            frameWidth = 88,
            frameHeight = 48,
            frameScale = 1,
            framePadding = 1,
            frameSpacing = 0,
            growDirection = "HORIZONTAL",
            growthAnchor = "CENTER",
            colorByClass = true,
            raidUseGroups = true,
            raidGroupSpacing = -1,
            raidGroupsPerRow = 8,
            raidPlayersPerRow = 5,
            sortEnabled = true,
            sortByClass = true,
            sortAlphabetical = false,
            sortSeparateMeleeRanged = true,
            showAbsorbBar = true,
            showPowerBar = false,
            powerBarHeight = 4,
            healthTexture = TEXTURE_FILL,
            absorbBarTexture = TEXTURE_FILL,
            healthTextFormat = "PERCENT",
            healthTextAbbreviate = true,
            textFont = DEFAULT_FONT_NAME,
            textOutline = "OUTLINE",
            nameFontSize = 11,
            healthTextFontSize = 10,
        },
        raid40 = {
            frameWidth = 73,
            frameHeight = 43,
            frameScale = 1,
            framePadding = 1,
            frameSpacing = 0,
            growDirection = "HORIZONTAL",
            growthAnchor = "CENTER",
            colorByClass = true,
            raidUseGroups = true,
            raidTestFrameCount = 40,
            raidGroupSpacing = -1,
            raidGroupsPerRow = 8,
            raidPlayersPerRow = 5,
            sortEnabled = true,
            sortByClass = true,
            sortAlphabetical = false,
            sortSeparateMeleeRanged = true,
            showAbsorbBar = true,
            showPowerBar = false,
            powerBarHeight = 4,
            healthTexture = TEXTURE_FILL,
            absorbBarTexture = TEXTURE_FILL,
            healthTextFormat = "PERCENT",
            healthTextAbbreviate = true,
            textFont = DEFAULT_FONT_NAME,
            textOutline = "OUTLINE",
            nameFontSize = 10,
            healthTextFontSize = 9,
        },
        arena = {
            frameWidth = 235,
            frameHeight = 41,
            frameScale = 1,
            framePadding = 1,
            frameSpacing = 10,
            growDirection = "VERTICAL",
            growthAnchor = "CENTER",
            showPlayer = false,
            colorByClass = true,
            showAbsorbBar = true,
            showPowerBar = false,
            powerBarHeight = 4,
            healthTexture = TEXTURE_FILL,
            absorbBarTexture = TEXTURE_FILL,
            healthTextFormat = "CURRENTMAX",
            healthTextAbbreviate = true,
            textFont = DEFAULT_FONT_NAME,
            textOutline = "OUTLINE",
            nameFontSize = 15,
            healthTextFontSize = 12,
        },
        boss = {
        enabled = true,
        frameWidth = 235,
        frameHeight = 41,
        frameScale = 1,
        framePadding = 1,
        frameSpacing = 10,
        growDirection = "VERTICAL",
        growthAnchor = "CENTER",
        pixelPerfect = true,
        showPlayer = false,
        colorByClass = true,
        healthTexture = TEXTURE_FILL,
        absorbBarTexture = TEXTURE_FILL,
        absorbBarColor = DEFAULT_ABSORB_COLOR,
        showAbsorbBar = true,
        showPowerBar = false,
        powerBarHeight = 4,
        healthTextFormat = "PERCENT",
        healthTextAbbreviate = true,
        textFont = DEFAULT_FONT_NAME,
        textOutline = "OUTLINE",
        nameFontSize = 15,
        healthTextFontSize = 12,
    },
    positions = {
            party = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 115, y = -230 },
            raid = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 0, y = -354 },
            arena = { point = "CENTER", relativePoint = "CENTER", x = -400, y = 14.58335876464844 },
        },
    },
    heal = {
        label = "Heal",
        party = {
            frameWidth = 138,
            frameHeight = 93,
            frameScale = 1,
            framePadding = 1,
            frameSpacing = 1,
            growDirection = "HORIZONTAL",
            growthAnchor = "CENTER",
            showPlayer = true,
            colorByClass = true,
            showAbsorbBar = true,
            showPowerBar = false,
            powerBarHeight = 4,
            healthTexture = TEXTURE_FILL,
            absorbBarTexture = TEXTURE_FILL,
            healthTextFormat = "CURRENTMAX",
            healthTextAbbreviate = true,
            textFont = DEFAULT_FONT_NAME,
            textOutline = "OUTLINE",
            nameFontSize = 15,
            healthTextFontSize = 12,
        },
        raid = {
            frameWidth = 88,
            frameHeight = 48,
            frameScale = 1,
            framePadding = 1,
            frameSpacing = 0,
            growDirection = "HORIZONTAL",
            growthAnchor = "CENTER",
            colorByClass = true,
            raidUseGroups = true,
            raidGroupSpacing = -1,
            raidGroupsPerRow = 8,
            raidPlayersPerRow = 5,
            sortEnabled = true,
            sortByClass = true,
            sortAlphabetical = false,
            sortSeparateMeleeRanged = true,
            showAbsorbBar = true,
            showPowerBar = false,
            powerBarHeight = 4,
            healthTexture = TEXTURE_FILL,
            absorbBarTexture = TEXTURE_FILL,
            healthTextFormat = "PERCENT",
            healthTextAbbreviate = true,
            textFont = DEFAULT_FONT_NAME,
            textOutline = "OUTLINE",
            nameFontSize = 11,
            healthTextFontSize = 10,
            raidGroupOutline = true,
        },
        raid40 = {
            frameWidth = 73,
            frameHeight = 43,
            frameScale = 1,
            framePadding = 1,
            frameSpacing = 0,
            growDirection = "HORIZONTAL",
            growthAnchor = "CENTER",
            colorByClass = true,
            raidUseGroups = true,
            raidTestFrameCount = 40,
            raidGroupSpacing = -1,
            raidGroupsPerRow = 8,
            raidPlayersPerRow = 5,
            sortEnabled = true,
            sortByClass = true,
            sortAlphabetical = false,
            sortSeparateMeleeRanged = true,
            showAbsorbBar = true,
            showPowerBar = false,
            powerBarHeight = 4,
            healthTexture = TEXTURE_FILL,
            absorbBarTexture = TEXTURE_FILL,
            healthTextFormat = "PERCENT",
            healthTextAbbreviate = true,
            textFont = DEFAULT_FONT_NAME,
            textOutline = "OUTLINE",
            nameFontSize = 10,
            healthTextFontSize = 9,
            raidGroupOutline = true,
        },
        arena = {
            frameWidth = 138,
            frameHeight = 93,
            frameScale = 1,
            framePadding = 1,
            frameSpacing = 1,
            growDirection = "HORIZONTAL",
            growthAnchor = "CENTER",
            showPlayer = true,
            colorByClass = true,
            showAbsorbBar = true,
            showPowerBar = false,
            powerBarHeight = 4,
            healthTexture = TEXTURE_FILL,
            absorbBarTexture = TEXTURE_FILL,
            healthTextFormat = "CURRENTMAX",
            healthTextAbbreviate = true,
            textFont = DEFAULT_FONT_NAME,
            textOutline = "OUTLINE",
            nameFontSize = 15,
            healthTextFontSize = 12,
        },
        boss = {
        enabled = true,
        frameWidth = 235,
        frameHeight = 41,
        frameScale = 1,
        framePadding = 1,
        frameSpacing = 10,
        growDirection = "VERTICAL",
        growthAnchor = "CENTER",
        pixelPerfect = true,
        showPlayer = false,
        colorByClass = true,
        healthTexture = TEXTURE_FILL,
        absorbBarTexture = TEXTURE_FILL,
        absorbBarColor = DEFAULT_ABSORB_COLOR,
        showAbsorbBar = true,
        showPowerBar = false,
        powerBarHeight = 4,
        healthTextFormat = "PERCENT",
        healthTextAbbreviate = true,
        textFont = DEFAULT_FONT_NAME,
        textOutline = "OUTLINE",
        nameFontSize = 15,
        healthTextFontSize = 12,
    },
    positions = {
            party = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 115, y = -230 },
            raid = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 0, y = -354 },
            arena = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -260 },
        },
    },
}

local DEFAULTS = {
    enable = true,
    party = {
        enabled = true,
        frameWidth = 235,
        frameHeight = 41,
        frameScale = 1,
        framePadding = 1,
        frameSpacing = 10,
        growDirection = "VERTICAL",
        growthAnchor = "CENTER",
        pixelPerfect = true,
        showPlayer = false,
        colorByClass = true,
        healthTexture = TEXTURE_FILL,
        absorbBarTexture = TEXTURE_FILL,
        absorbBarColor = DEFAULT_ABSORB_COLOR,
        showAbsorbBar = true,
        showPowerBar = false,
        powerBarHeight = 4,
        healthTextFormat = "CURRENTMAX",
        healthTextAbbreviate = true,
        textFont = DEFAULT_FONT_NAME,
        textOutline = "OUTLINE",
        nameFontSize = 15,
        healthTextFontSize = 12,
    },
    raid = {
        enabled = true,
        frameWidth = 88,
        frameHeight = 48,
        frameScale = 1,
        framePadding = 1,
        frameSpacing = 0,
        growDirection = "HORIZONTAL",
        growthAnchor = "CENTER",
        pixelPerfect = true,
        colorByClass = true,
        raidUseGroups = true,
        raidPopOutOwnGroup = false,
        raidTestFrameCount = 20,
        raidGroupSpacing = -1,
        raidGroupsPerRow = 8,
        raidPlayersPerRow = 5,
        sortEnabled = true,
        sortByClass = true,
        sortAlphabetical = false,
        sortSeparateMeleeRanged = true,
        healthTexture = TEXTURE_FILL,
        absorbBarTexture = TEXTURE_FILL,
        absorbBarColor = DEFAULT_ABSORB_COLOR,
        showAbsorbBar = true,
        showPowerBar = false,
        powerBarHeight = 4,
        healthTextFormat = "PERCENT",
        healthTextAbbreviate = true,
        textFont = DEFAULT_FONT_NAME,
        textOutline = "OUTLINE",
        nameFontSize = 11,
        healthTextFontSize = 10,
    },
    raid40 = {
        enabled = true,
        frameWidth = 73,
        frameHeight = 43,
        frameScale = 1,
        framePadding = 1,
        frameSpacing = 0,
        growDirection = "HORIZONTAL",
        growthAnchor = "CENTER",
        pixelPerfect = true,
        colorByClass = true,
        raidUseGroups = true,
        raidPopOutOwnGroup = false,
        raidTestFrameCount = 40,
        raidGroupSpacing = -1,
        raidGroupsPerRow = 8,
        raidPlayersPerRow = 5,
        sortEnabled = true,
        sortByClass = true,
        sortAlphabetical = false,
        sortSeparateMeleeRanged = true,
        healthTexture = TEXTURE_FILL,
        absorbBarTexture = TEXTURE_FILL,
        showAbsorbBar = true,
        showPowerBar = false,
        powerBarHeight = 4,
        healthTextFormat = "PERCENT",
        healthTextAbbreviate = true,
        textFont = DEFAULT_FONT_NAME,
        textOutline = "OUTLINE",
        nameFontSize = 10,
        healthTextFontSize = 9,
    },
    arena = {
        enabled = true,
        frameWidth = 235,
        frameHeight = 41,
        frameScale = 1,
        framePadding = 1,
        frameSpacing = 10,
        growDirection = "VERTICAL",
        growthAnchor = "CENTER",
        pixelPerfect = true,
        showPlayer = false,
        colorByClass = true,
        healthTexture = TEXTURE_FILL,
        absorbBarTexture = TEXTURE_FILL,
        absorbBarColor = DEFAULT_ABSORB_COLOR,
        showAbsorbBar = true,
        showPowerBar = false,
        powerBarHeight = 4,
        healthTextFormat = "PERCENT",
        healthTextAbbreviate = true,
        textFont = DEFAULT_FONT_NAME,
        textOutline = "OUTLINE",
        nameFontSize = 15,
        healthTextFontSize = 12,
        raidGroupOutline = true,
    },
    arenaEnemy = {
        enabled = true,
        frameWidth = 235,
        frameHeight = 41,
        frameScale = 1,
        framePadding = 1,
        frameSpacing = 10,
        growDirection = "VERTICAL",
        growthAnchor = "CENTER",
        pixelPerfect = true,
        showPlayer = false,
        colorByClass = true,
        healthTexture = TEXTURE_FILL,
        absorbBarTexture = TEXTURE_FILL,
        absorbBarColor = DEFAULT_ABSORB_COLOR,
        showAbsorbBar = true,
        showPowerBar = false,
        powerBarHeight = 4,
        healthTextFormat = "PERCENT",
        healthTextAbbreviate = true,
        textFont = DEFAULT_FONT_NAME,
        textOutline = "OUTLINE",
        nameFontSize = 15,
        healthTextFontSize = 12,
        raidGroupOutline = true,
        showMissingBuffs = false,
    },
    boss = {
        enabled = true,
        frameWidth = 235,
        frameHeight = 41,
        frameScale = 1,
        framePadding = 1,
        frameSpacing = 10,
        growDirection = "VERTICAL",
        growthAnchor = "CENTER",
        pixelPerfect = true,
        showPlayer = false,
        colorByClass = true,
        healthTexture = TEXTURE_FILL,
        absorbBarTexture = TEXTURE_FILL,
        absorbBarColor = DEFAULT_ABSORB_COLOR,
        showAbsorbBar = true,
        showPowerBar = false,
        powerBarHeight = 4,
        healthTextFormat = "PERCENT",
        healthTextAbbreviate = true,
        textFont = DEFAULT_FONT_NAME,
        textOutline = "OUTLINE",
        nameFontSize = 15,
        healthTextFontSize = 12,
    },
    positions = {
        party = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 115, y = -230 },
        raid = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = -6.666610717773438, y = -25 },
        raidOwnGroup = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = -6.666610717773438, y = -310 },
        raid40OwnGroup = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = -6.666610717773438, y = -310 },
        arena = { point = "CENTER", relativePoint = "CENTER", x = -400, y = 14.58335876464844 },
        arenaEnemy = { point = "CENTER", relativePoint = "CENTER", x = 400, y = 14.58335876464844 },
        boss = { point = "CENTER", relativePoint = "CENTER", x = 0, y = -260 },
    },
    activePreset = "dps_tank",
    autoProfileBySpec = true,
    specProfiles = {},
    profilePositions = {},
}

local function CopyDefaults(src, dst)
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
            end
            CopyDefaults(value, dst[key])
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

local function CopyPosition(pos)
    return {
        point = pos and pos.point or "CENTER",
        relativePoint = pos and pos.relativePoint or (pos and pos.point) or "CENTER",
        x = pos and pos.x or 0,
        y = pos and pos.y or 0,
        scale = pos and pos.scale or nil,
    }
end

local function CopyPositions(src, dst)
    if not (src and dst) then return end
    for _, key in ipairs({ "party", "raid", "raid40", "arena", "arenaEnemy", "boss", "raidOwnGroup", "raid40OwnGroup" }) do
        if src[key] then
            dst[key] = CopyPosition(src[key])
        end
    end
end

local function NormalizeMode(mode)
    if mode == "raid" or mode == "raid40" or mode == "arena" or mode == "arenaEnemy" or mode == "boss" then
        return mode
    end
    return "party"
end

function Mod:GetOwnGroupPositionKey(mode)
    mode = NormalizeMode(mode)
    if mode == "raid40" then return "raid40OwnGroup" end
    if mode == "raid" then return "raidOwnGroup" end
    return nil
end

function Mod:NormalizePositionKey(key)
    if key == "raidOwnGroup" or key == "raid40OwnGroup" then
        return key
    end
    return NormalizeMode(key)
end

local function IsRaidMode(mode)
    return mode == "raid" or mode == "raid40"
end

function Mod:IsArenaContext(ignoreCached)
    local _, instanceType = IsInInstance and IsInInstance()
    -- Battleground clients can retain arena-opponent spec data from a previous
    -- match. The authoritative PvP instance type must clear that stale cache.
    if instanceType == [=[pvp]=] then
        self._arenaContext = nil
        return false
    end
    if instanceType == 'arena' then return true end

    if self.GetAccessibleGroupCount and self:GetAccessibleGroupCount() > 5 then
        self._arenaContext = nil
        return false
    end

    -- IsInInstance can lag behind the battlefield state while zoning. A live
    -- non-arena battlefield is authoritative and must reject stale arenaN/specs.
    if _G.C_PvP and _G.C_PvP.IsActiveBattlefield then
        local activeOK, active = pcall(_G.C_PvP.IsActiveBattlefield)
        if activeOK and active == true then
            local arenaActive = false
            if _G.IsActiveBattlefieldArena then
                local arenaOK, value = pcall(_G.IsActiveBattlefieldArena)
                arenaActive = arenaOK and value == true
            end
            if not arenaActive then
                self._arenaContext = nil
                return false
            end
        end
    end

    if _G.IsActiveBattlefieldArena then
        local ok, active = pcall(_G.IsActiveBattlefieldArena)
        if ok and active == true then return true end
    end

    -- ARENA_PREP_OPPONENT_SPECIALIZATIONS can be more reliable than
    -- IsInInstance during the loading/preparation transition.
    if _G.GetNumArenaOpponentSpecs then
        local ok, count = pcall(_G.GetNumArenaOpponentSpecs)
        local secret = false
        if ok and IsSecretValue(count) then
            secret = true
        end
        if ok and not secret and type(count) == 'number' and count > 0 then
            return true
        end
    end

    return not ignoreCached and self._arenaContext == true
end

function Mod:GetAccessibleGroupCount()
    if not GetNumGroupMembers then return 0 end
    local function ReadCount(category)
        local ok, total = pcall(GetNumGroupMembers, category)
        if not ok then return 0 end
        if IsSecretValue(total) then return 0 end
        if type(total) ~= [=[number]=] then return 0 end
        return math.max(0, math.min(40, total))
    end

    -- Matchmade PvP keeps its full roster in the instance category while the
    -- uncategorized/home query may expose only the player's five-man subgroup.
    local instanceTotal = ReadCount(_G.LE_PARTY_CATEGORY_INSTANCE or 2)
    if instanceTotal > 0 then return instanceTotal end
    return ReadCount(nil)
end

local function GetLiveGroupMode()
    if Mod:IsArenaContext() then
        return "arena"
    end

    local accessibleTotal = Mod:GetAccessibleGroupCount()
    if accessibleTotal > 5 then
        return accessibleTotal > 25 and [=[raid40]=] or [=[raid]=]
    end

    if IsInRaid and IsInRaid() then
        local total = accessibleTotal
        return total > 25 and "raid40" or "raid"
    end

    if UnitExists then
        for i = 1, 4 do
            if UnitExists("party" .. i) then
                return "party"
            end
        end
    end

    return nil
end

local function AuraDebugChat(message)
    if not message then return end
    local text = "|cff66ccff[PF AuraDebug]|r " .. tostring(message)
    local frame = _G.DEFAULT_CHAT_FRAME or _G.ChatFrame1
    if frame and frame.AddMessage then
        frame:AddMessage(text)
    elseif _G.print then
        _G.print(text)
    end
end

local function DebugAuraSpellPrint(db, message, force)
    if not message then return end
    local enabled = db and db.debugAuraSpells == true
    if not enabled and KT and KT.GetModule then
        local mod = KT:GetModule("PartyFrames", true)
        enabled = mod and mod.db and mod.db.debugAuraSpells == true
    end
    if not (enabled or force) then return end
    AuraDebugChat(message)
end

local managedHideDrivers = setmetatable({}, { __mode = "k" })
local function SafeHideManagedFrame(frame)
    if not frame then return end
    if IsSecretValue(frame) then return end
    if frame.IsForbidden then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok or forbidden then return end
    end

    -- A constant secure visibility driver cannot be undone by Blizzard, Danders
    -- or range updates during arena preparation/combat. Register it only while
    -- unlocked; alpha remains the fallback for frames without state support.
    if RegisterStateDriver and not managedHideDrivers[frame] and not (InCombatLockdown and InCombatLockdown()) then
        local ok = pcall(RegisterStateDriver, frame, "visibility", "hide")
        if ok then managedHideDrivers[frame] = true end
    end
    if frame.SetAlpha then pcall(frame.SetAlpha, frame, 0) end
    if frame.EnableMouse then pcall(frame.EnableMouse, frame, false) end
    if frame.SetMouseClickEnabled then pcall(frame.SetMouseClickEnabled, frame, false) end
    if frame.SetMouseMotionEnabled then pcall(frame.SetMouseMotionEnabled, frame, false) end
end

local function GetExternalAuraReserve(db, mode)
    return 0
end

function Mod:CanIterateTable(value)
    if type(value) ~= 'table' or IsSecretValue(value) then return false end
    if _G.issecrettable then
        local ok, secret = pcall(_G.issecrettable, value)
        if not ok or secret == true then return false end
    end
    -- A table can be non-secret itself while its iteration is forbidden in a
    -- tainted PvP execution path. Probe `next` without consuming its contents.
    local ok = pcall(next, value)
    return ok
end

local function IsUsableClassToken(classToken)
    return not IsSecretValue(classToken) and classToken and classToken ~= ""
end

local function GetUnitClassToken(unit)
    if KT and KT.SafeUnitClass then
        -- SafeUnitClass mirrors UnitClass: the localized class name is the
        -- first result and the stable class file token is the second.
        local ok, _, token = pcall(KT.SafeUnitClass, unit)
        if ok and IsUsableClassToken(token) then return token end
    end
    local classToken
    if UnitClass then
        local ok, _, token = pcall(UnitClass, unit)
        if ok and IsUsableClassToken(token) then
            classToken = token
        end
    end
    if not classToken and UnitClassBase then
        -- UnitClassBase returns the class file token as its first result.
        local ok, token = pcall(UnitClassBase, unit)
        if ok and IsUsableClassToken(token) then
            classToken = token
        end
    end
    if not classToken and UnitIsUnit and UnitClass then
        local unitOK, isPlayer = pcall(UnitIsUnit, unit, "player")
        if unitOK and not IsSecretValue(isPlayer) and isPlayer == true then
            local ok, _, token = pcall(UnitClass, "player")
            if ok and IsUsableClassToken(token) then
                classToken = token
            end
        end
    end
    return classToken
end

local function GetClassColor(unit, fallbackR, fallbackG, fallbackB)
    local classToken = GetUnitClassToken(unit)
    local c = classToken and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]) or BLIZZARD_CLASS_COLORS[classToken])
    if c then
        return c.r, c.g, c.b
    end

    -- In PvP the unit can be valid while its class token is protected. Do not
    -- use that token as a Lua key; Blizzard's native class-color API accepts
    -- it and the returned protected RGB values can flow into StatusBar.
    if UnitClass and C_ClassColor and C_ClassColor.GetClassColor then
        local _, rawClass = UnitClass(unit)
        if IsSecretValue(rawClass) then
            local nativeColor = C_ClassColor.GetClassColor(rawClass)
            if nativeColor then return nativeColor:GetRGB() end
        end
    end

    return fallbackR or 0.92, fallbackG or 0.34, fallbackB or 0.25
end

local function GetTestClassColor(classToken, role)
    local c = classToken and PF_STATIC.testClassColors[classToken]
    if c then
        return c.r, c.g, c.b
    end
    c = role and ROLE_COLORS[role]
    if c then
        return c.r, c.g, c.b
    end
    return 0.92, 0.34, 0.25
end

local function GetRoleColor(role)
    local c = role and ROLE_COLORS[role]
    if c then
        return c.r, c.g, c.b
    end
    return 0.92, 0.34, 0.25
end

local function GetPowerColor()
    return 0.22, 0.45, 0.95
end

local function ResolveFontPath(fontName)
    if KT.ResolveFontPath then
        return KT:ResolveFontPath(fontName or DEFAULT_FONT_NAME, DEFAULT_FONT_PATH)
    end
    return DEFAULT_FONT_PATH
end

local function ApplyTextStyle(text, db, sizeKey, fallbackSize, maxSize)
    if not text then return end
    local outline = (db and db.textOutline) or "OUTLINE"
    if outline == "NONE" then outline = "" end
    local size = tonumber(db and db[sizeKey]) or fallbackSize
    if maxSize and size > maxSize then
        size = math.max(8, maxSize)
    end
    text:SetFont(ResolveFontPath(db and db.textFont), size, outline)
    text:SetTextColor(1, 1, 1, 1)
end

local function FormatHealthValue(value, abbreviate)
    if abbreviate and AbbreviateNumbers then
        return AbbreviateNumbers(value)
    end
    return tostring(value)
end

local function FitText(value, maxChars)
    -- PvP names can be secret strings. They may be forwarded to a FontString,
    -- but Lua cannot inspect their length or slice them in tainted execution.
    if IsSecretValue(value) then return value end
    value = tostring(value or "")
    maxChars = tonumber(maxChars) or 0
    if maxChars <= 0 or #value <= maxChars then
        return value
    end
    if maxChars <= 3 then
        return value:sub(1, maxChars)
    end
    return value:sub(1, maxChars - 1) .. "."
end

Mod._testArenaSpecIDs = { 70, 63, 259, 71, 258 }

function Mod:GetArenaSpecIcon(unit, fakeIndex)
    local specID
    if fakeIndex then
        local testSpecs = Mod._testArenaSpecIDs
        specID = testSpecs[((fakeIndex - 1) % #testSpecs) + 1]
    elseif type(unit) == 'string' and _G.GetArenaOpponentSpec then
        local arenaIndex = tonumber(string.match(unit, '^arena(%d+)$'))
        if arenaIndex then
            local ok, value = pcall(_G.GetArenaOpponentSpec, arenaIndex)
            if ok and not IsSecretValue(value) and type(value) == 'number' and value > 0 then
                specID = value
            end
        end
    end
    if not (specID and _G.GetSpecializationInfoByID) then return nil end
    local ok, _, specName, _, icon, _, classFile = pcall(_G.GetSpecializationInfoByID, specID)
    if not ok or IsSecretValue(icon) then return nil end
    if IsSecretValue(specName) then specName = nil end
    if IsSecretValue(classFile) then classFile = nil end
    return icon, specName, classFile
end

function Mod:SetArenaSpecIcon(frame, icon, specName)
    local holder = frame and frame.specIconFrame
    if not holder then return end
    if frame.mode ~= 'arenaEnemy' then
        holder:Hide()
        return
    end
    if icon then
        frame._arenaSpecIcon = icon
        frame._arenaSpecName = specName or frame._arenaSpecName
    else
        icon = frame._arenaSpecIcon
    end
    if icon then
        holder.icon:SetTexture(icon)
        holder.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        holder:Show()
    else
        holder:Hide()
    end
end

local function SetTestHealthText(text, data, db, hpPercent)
    if not text then return end
    local format = db and db.healthTextFormat or "CURRENTMAX"
    if format == "NONE" then
        text:SetText("")
        text:Hide()
        return
    end

    local maxHealth = data.maxHealth or 100000
    local current = math.floor((hpPercent or 0) * maxHealth)
    local deficit = maxHealth - current
    local abbreviate = db and db.healthTextAbbreviate

    if format == "PERCENT" then
        text:SetFormattedText("%.0f%%", (hpPercent or 0) * 100)
    elseif format == "CURRENT" then
        text:SetText(FormatHealthValue(current, abbreviate))
    elseif format == "DEFICIT" then
        text:SetText(deficit > 0 and ("-" .. FormatHealthValue(deficit, abbreviate)) or "")
    elseif format == "CURRENTMAX" then
        text:SetText(FormatHealthValue(current, abbreviate) .. "/" .. FormatHealthValue(maxHealth, abbreviate))
    else
        text:SetFormattedText("%.0f%%", (hpPercent or 0) * 100)
    end
    text:Show()
end

local function MakeUnitLabel(unit)
    if not unit then return "" end
    local name = UnitName and UnitName(unit)
    return name or unit
end

local function SafeUnitBoolean(func, unit)
    if type(func) ~= "function" then return nil end
    local ok, value = pcall(func, unit)
    if not ok or IsSecretValue(value) then
        return nil
    end
    return value and true or false
end

local function SetHealthText(text, unit, db, hpPercent)
    if not text then return end
    local format = db and db.healthTextFormat or "CURRENTMAX"
    if format == "NONE" then
        text:SetText("")
        text:Hide()
    elseif format == "CURRENTMAX" then
        local curr = UnitHealth and UnitHealth(unit, true)
        local maxHP = UnitHealthMax and UnitHealthMax(unit, true)
        if curr and maxHP then
            text:SetFormattedText("%s/%s", FormatHealthValue(curr, db and db.healthTextAbbreviate), FormatHealthValue(maxHP, db and db.healthTextAbbreviate))
        else
            text:SetText("")
        end
        text:Show()
    elseif format == "CURRENT" then
        local curr = UnitHealth and UnitHealth(unit, true)
        if curr then
            text:SetText(FormatHealthValue(curr, db and db.healthTextAbbreviate))
        else
            text:SetText("")
        end
        text:Show()
    elseif format == "DEFICIT" then
        local deficit = UnitHealthMissing and UnitHealthMissing(unit, true)
        if deficit then
            if C_StringUtil and C_StringUtil.TruncateWhenZero and C_StringUtil.WrapString then
                text:SetText(C_StringUtil.WrapString(C_StringUtil.TruncateWhenZero(deficit), "-"))
                if db and db.healthTextAbbreviate and AbbreviateNumbers and text:GetText() then
                    text:SetFormattedText("-%s", AbbreviateNumbers(deficit))
                end
            elseif db and db.healthTextAbbreviate and AbbreviateNumbers then
                text:SetFormattedText("-%s", AbbreviateNumbers(deficit))
            else
                text:SetFormattedText("-%s", deficit)
            end
        else
            text:SetText("")
        end
        text:Show()
    else
        text:SetFormattedText("%.0f%%", hpPercent)
        text:Show()
    end
end

local function IsUnitUsable(unit)
    if not (unit and UnitExists) then return false end
    local ok, exists = pcall(UnitExists, unit)
    return ok and not IsSecretValue(exists) and exists == true
end

-- Raid tokens are sorted and rebound by the custom raid/raid40 layout. The
-- direct UnitIsGroup* queries can be temporarily unavailable while the roster
-- is rebuilt (and can be protected in combat), whereas GetRaidRosterInfo
-- exposes the authoritative rank for that raid slot. The second return value
-- distinguishes an ordinary member from an unreadable result.
local function ReadGroupLeaderState(unit)
    if type(unit) == "string" then
        local raidIndex = unit:match("^raid(%d+)$")
        if raidIndex and GetRaidRosterInfo then
            local ok, _, rank = pcall(GetRaidRosterInfo, tonumber(raidIndex))
            if ok and not IsSecretValue(rank) and type(rank) == "number" then
                if rank == 2 then return "assistant", true end
                if rank == 1 then return "leader", true end
                return nil, true
            end
        end
    end

    local ok, value = false, nil
    if UnitIsGroupLeader then
        ok, value = pcall(UnitIsGroupLeader, unit)
        if ok and not IsSecretValue(value) then
            if value then return "leader", true end
        else
            ok = false
        end
    end

    if UnitIsGroupAssistant then
        local assistantOK, assistant = pcall(UnitIsGroupAssistant, unit)
        if assistantOK and not IsSecretValue(assistant) then
            if assistant then return "assistant", true end
            return nil, ok == true
        end
    end

    return nil, false
end

local function ShowUnitTooltip(frame)
    if not frame or frame.fakeUnit or not frame.unit then return end
    if InCombatLockdown and InCombatLockdown() then
        if GameTooltip then GameTooltip:Hide() end
        return
    end
    if not (GameTooltip and IsUnitUsable(frame.unit)) then return end
    if GameTooltip:IsForbidden() then return end

    if _G.GameTooltip_SetDefaultAnchor then
        _G.GameTooltip_SetDefaultAnchor(GameTooltip, frame)
    else
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    end
    GameTooltip:SetUnit(frame.unit)
    GameTooltip:Show()
end

local function HideUnitTooltip(frame)
    if not GameTooltip or GameTooltip:IsForbidden() then return end
    local owner = GameTooltip:GetOwner()
    if owner == frame then
        GameTooltip:Hide()
    end
end

local EMPTY_AURA_STATE = {
    buffs = {},
    debuffs = {},
    cc = nil,
    missingBuff = nil,
    dispelType = nil,
    dispelAuraInstanceID = nil,
    dispelAura = nil,
}

local function SafeUnitInRange(unit)
    if not unit then return true end
    if UnitIsUnit then
        local ok, isPlayer = pcall(UnitIsUnit, unit, "player")
        if ok and not IsSecretValue(isPlayer) and isPlayer == true then
            return true
        end
    end
    if not IsUnitUsable(unit) then
        return true
    end
    if SafeUnitBoolean(UnitIsConnected, unit) == false then
        return false -- FIX: properly fade disconnected players
    end
    if UnitIsVisible then
        local ok, visible = pcall(UnitIsVisible, unit)
        if ok and visible then
            return true -- FIX: if they are rendered, they are in range, regardless of API errors
        end
    end
    if UnitPhaseReason then
        local ok, phaseReason = pcall(UnitPhaseReason, unit)
        if ok and phaseReason ~= nil and phaseReason ~= 0 then
            return false -- FIX: 0 might be truthy, check explicitly
        end
    end

    local rc = LibRangeCheck
    if not rc and LibStub then
        rc = LibStub("LibRangeCheck-3.0", true)
        LibRangeCheck = rc
    end
    if rc and rc.GetRange then
        local ok, minRange, maxRange = pcall(rc.GetRange, rc, unit, false, false) -- FIX: Do not require LoS for simple range checks
        if ok then
            if maxRange and maxRange <= 45 then
                return true
            end
            if minRange and (not maxRange or minRange > 45) then
                return false
            end
        end
    end

    if UnitInRange then
        local ok, inRange = pcall(UnitInRange, unit)
        if ok and inRange ~= nil then
            return inRange
        end
    end
    if CheckInteractDistance and not (InCombatLockdown and InCombatLockdown()) then
        local ok, inRange = pcall(CheckInteractDistance, unit, 4)
        if ok then
            return inRange and true or false
        end
    end

    return true
end

local function ApplyFrameRangeAlpha(frame, inRange, alpha)
    if not frame then return end
    alpha = tonumber(alpha) or 0.45
    if frame.SetAlphaFromBoolean then
        frame:SetAlphaFromBoolean(inRange, 1, alpha)
    elseif not IsSecretValue(inRange) then
        frame:SetAlpha(inRange and 1 or alpha)
    end
end

local function MovePlayerToMiddle(units)
    if not UnitIsUnit then return end

    local playerIndex
    for i, unit in ipairs(units) do
        if type(unit) == "string" then
            local ok, isPlayer = pcall(UnitIsUnit, unit, "player")
            if ok and not IsSecretValue(isPlayer) and isPlayer == true then
                playerIndex = i
                break
            end
        end
    end
    if not playerIndex then return end

    local total = #units
    local middle = math.floor(total / 2) + 1
    if playerIndex == middle then return end

    local playerUnit = table.remove(units, playerIndex)
    table.insert(units, math.min(middle, #units + 1), playerUnit)
end

local function GetUnitTokenSortIndex(unit)
    if unit == "player" then return 0 end
    local index = tonumber(tostring(unit or ""):match("%d+")) or 99
    return index
end

local function GetAccessibleUnitRole(unit)
    if not (UnitGroupRolesAssigned and unit) then return "NONE" end
    local ok, role = pcall(UnitGroupRolesAssigned, unit)
    if not ok or IsSecretValue(role) or type(role) ~= "string" or not ROLE_ORDER[role] then
        return "NONE"
    end
    return role
end

local function GetAccessibleUnitNameForSort(unit)
    if not (UnitName and unit) then return tostring(unit or "") end
    local ok, name = pcall(UnitName, unit)
    if not ok or IsSecretValue(name) or type(name) ~= "string" then
        return tostring(unit or "")
    end
    return name
end

local function SortGroupUnitsByRole(units)
    table.sort(units, function(a, b)
        local unitA = type(a) == "table" and a.unit or a
        local unitB = type(b) == "table" and b.unit or b
        local roleA = GetAccessibleUnitRole(unitA)
        local roleB = GetAccessibleUnitRole(unitB)
        local orderA = ROLE_ORDER[roleA] or ROLE_ORDER.NONE or 9
        local orderB = ROLE_ORDER[roleB] or ROLE_ORDER.NONE or 9
        if orderA ~= orderB then
            return orderA < orderB
        end
        return GetUnitTokenSortIndex(unitA) < GetUnitTokenSortIndex(unitB)
    end)
end

local function GetTestUnitData(fakeUnit, mode)
    local index = fakeUnit.index or 1
    local data = TEST_UNITS[((index - 1) % #TEST_UNITS) + 1]
    local result = {}
    for key, value in pairs(data) do
        result[key] = value
    end
    result.name = fakeUnit.isPlayer and "Player" or data.name
    result.isPlayer = fakeUnit.isPlayer or data.isPlayer
    result.role = fakeUnit.isPlayer and "DAMAGER" or result.role
    local testStatusOverrides = ns.PF_TestStatusOverrides
    if fakeUnit.isPlayer then
        result.status = nil
    elseif testStatusOverrides then
        result.status = testStatusOverrides[index]
        if result.status == "Dead" then
            result.health = 0
            result.power = 0
            result.absorb = 0
        end
    end
    local testClasses = {"HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR", "DRUID", "DEATHKNIGHT", "MONK", "DEMONHUNTER", "EVOKER"}
    result.class = fakeUnit.isPlayer and "PALADIN" or testClasses[((index - 1) % #testClasses) + 1]
    return result
end

local function GetSpecInfo(specIndex)
    if not (GetSpecializationInfo and specIndex) then return nil end
    local specID, name, _, icon, role = GetSpecializationInfo(specIndex)
    if not specID then return nil end
    return {
        index = specIndex,
        id = specID,
        name = name or tostring(specID),
        icon = icon,
        role = role or "DAMAGER",
    }
end

local function GetAutoProfileForSpec(specID, role)
    if specID == PF_STATIC.augmentationSpecID then
        return "heal"
    end
    if role == "HEALER" then
        return "heal"
    end
    return "dps_tank"
end

local function ApplyAuraDefaults(db)
    if not db then return end
    CopyDefaults(AURA_DEFAULTS, db)
end

function Mod:EnsureDB()
    KT.db.profile.partyFrames = KT.db.profile.partyFrames or {}
    CopyDefaults(DEFAULTS, KT.db.profile.partyFrames)
    self.db = KT.db.profile.partyFrames
    self.db.raid40 = self.db.raid40 or {}
    CopyDefaults(DEFAULTS.raid, self.db.raid40)
    for _, mode in ipairs(MODE_ORDER) do
        ApplyAuraDefaults(self.db[mode])
    end
    if not self.db.arenaTrackerSplitSizesMigrated then
        local arenaEnemy = self.db.arenaEnemy
        if arenaEnemy then
            arenaEnemy.arenaTrinketIconSize = 40
            arenaEnemy.arenaDRIconSize = tonumber(arenaEnemy.arenaTrackerIconSize) or 28
        end
        self.db.arenaTrackerSplitSizesMigrated = true
    end
    if not self.db.missingBuffIconSizeMigrated then
        for _, mode in ipairs(MODE_ORDER) do
            if self.db[mode] and (tonumber(self.db[mode].missingBuffIconSize) or 0) <= 18 then
                self.db[mode].missingBuffIconSize = AURA_DEFAULTS.missingBuffIconSize
            end
        end
        self.db.missingBuffIconSizeMigrated = true
    end
    if not self.db.dispelBorderMigrated or not self.db.dispelGradientStrengthMigrated then
        for _, mode in ipairs(MODE_ORDER) do
            if self.db[mode] then
                if (tonumber(self.db[mode].dispelOverlayAlpha) or 0) <= 0.34 then
                    self.db[mode].dispelOverlayAlpha = AURA_DEFAULTS.dispelOverlayAlpha
                end
                self.db[mode].dispelBorderThickness = tonumber(self.db[mode].dispelBorderThickness) or AURA_DEFAULTS.dispelBorderThickness
                if (tonumber(self.db[mode].dispelGradientAlpha) or 0) <= 0.34 then
                    self.db[mode].dispelGradientAlpha = AURA_DEFAULTS.dispelGradientAlpha
                end
                if (tonumber(self.db[mode].dispelGradientSize) or 0) <= 0.35 then
                    self.db[mode].dispelGradientSize = AURA_DEFAULTS.dispelGradientSize
                end
            end
        end
        self.db.dispelBorderMigrated = true
        self.db.dispelGradientStrengthMigrated = true
    end
    if not self.db.debuffVisibilityMigrated then
        for _, mode in ipairs(MODE_ORDER) do
            if self.db[mode] then
                if (tonumber(self.db[mode].auraMaxDebuffs) or 0) < 5 then
                    self.db[mode].auraMaxDebuffs = 5
                end
                if (tonumber(self.db[mode].auraIconSize) or 0) < 20 then
                    self.db[mode].auraIconSize = 20
                end
            end
        end
        self.db.debuffVisibilityMigrated = true
    end
    if not self.db.kuiModernAuraSpacingMigrated then
        for _, mode in ipairs(MODE_ORDER) do
            if self.db[mode] then
                self.db[mode].auraIconSpacing = 0
            end
        end
        self.db.kuiModernAuraSpacingMigrated = true
    end
    if not self.db.auraIconVisibilityDefaultsMigrated then
        for _, mode in ipairs(MODE_ORDER) do
            if self.db[mode] then
                self.db[mode].showBuffs = false
                self.db[mode].showDebuffs = false
            end
        end
        self.db.auraIconVisibilityDefaultsMigrated = true
    end
    if not self.db.auraShowAllDebuffsDirectDefaultMigrated then
        for _, mode in ipairs(MODE_ORDER) do
            if self.db[mode] then
                if self.db[mode].showDispelOverlay ~= false then
                    self.db[mode].showDebuffs = true
                end
                self.db[mode].auraShowAllDebuffs = true
            end
        end
        self.db.auraShowAllDebuffsDirectDefaultMigrated = true
    end
    if not self.db.auraDebuffIconRenderMigrated then
        for _, mode in ipairs(MODE_ORDER) do
            if self.db[mode] and self.db[mode].showDispelOverlay ~= false then
                self.db[mode].showAuras = true
                self.db[mode].showDebuffs = true
                self.db[mode].auraShowAllDebuffs = true
                if (tonumber(self.db[mode].auraMaxDebuffs) or 0) < 1 then
                    self.db[mode].auraMaxDebuffs = AURA_DEFAULTS.auraMaxDebuffs
                end
            end
        end
        self.db.auraDebuffIconRenderMigrated = true
    end
    
    if not self.db.auraDebuffLayoutMigrated then
        for _, mode in ipairs(MODE_ORDER) do
            if self.db[mode] then
                self.db[mode].debuffAnchor = IsRaidMode(mode) and "BOTTOMLEFT" or "CENTER"
                self.db[mode].debuffGrowthH = "RIGHT"
                self.db[mode].debuffGrowthV = "DOWN"
            end
        end
        self.db.auraDebuffLayoutMigrated = true
    end

    if not self.db.healthFormatMigrated then
        if self.db.raid and self.db.raid.healthTextFormat == "CURRENTMAX" then
            self.db.raid.healthTextFormat = "PERCENT"
        end
        if self.db.raid40 and self.db.raid40.healthTextFormat == "CURRENTMAX" then
            self.db.raid40.healthTextFormat = "PERCENT"
        end
        self.db.healthFormatMigrated = true
    end

    if not self.db.roleIconBlizzardDefaultMigrated then
        for _, mode in ipairs(MODE_ORDER) do
            if self.db[mode] then
                self.db[mode].roleIconStyle = "BLIZZARD"
            end
        end
        self.db.roleIconBlizzardDefaultMigrated = true
    end

    if self.db.raid40.raidTestFrameCount == nil then
        self.db.raid40.raidTestFrameCount = 40
    end
    self.db.positions = self.db.positions or {}
    if not self.db.positions.raid40 then
        self.db.positions.raid40 = CopyPosition(self.db.positions.raid or DEFAULTS.positions.raid)
    end
    if not self.db.positions.raidOwnGroup then
        self.db.positions.raidOwnGroup = CopyPosition(DEFAULTS.positions.raidOwnGroup)
    end
    if not self.db.positions.raid40OwnGroup then
        self.db.positions.raid40OwnGroup = CopyPosition(self.db.positions.raidOwnGroup or DEFAULTS.positions.raid40OwnGroup)
    end
    self.db.profilePositions = self.db.profilePositions or {}
    if self.db.activePreset and not self.db.profilePositions[self.db.activePreset] then
        self.db.profilePositions[self.db.activePreset] = {}
        CopyPositions(self.db.positions, self.db.profilePositions[self.db.activePreset])
    end
    return self.db
end

local externalFrameCallbacks = {}

local function GetExternalPartyFramesAPI()
    local api = _G.KullThranUI_PartyFrames
    if type(api) ~= "table" then
        api = {}
        _G.KullThranUI_PartyFrames = api
    end
    return api
end

local function FireExternalPartyFramesEvent(event)
    local callbacks = externalFrameCallbacks[event]
    if not callbacks then return end
    for owner, callback in pairs(callbacks) do
        if type(callback) == "function" then
            pcall(callback, owner, event)
        elseif owner and type(callback) == "string" and type(owner[callback]) == "function" then
            pcall(owner[callback], owner, event)
        end
    end
end

local function ScheduleExternalPartyFramesRefresh()
    if Mod._externalFramesRefreshQueued then return end
    Mod._externalFramesRefreshQueued = true
    local function fire()
        Mod._externalFramesRefreshQueued = nil
        FireExternalPartyFramesEvent("OnFramesSorted")
        FireExternalPartyFramesEvent("OnFramesChanged")
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, fire)
    else
        fire()
    end
end

-- â”€â”€ BliZzi_Interrupts integration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
-- BliZzi exposes a public resolver BIT.UnitFrames:GetPartyFrame(unit, provider)
-- and BIT.UnitFrames:GetAvailableProviders(). We hook those functions so KUI
-- frames appear under the name "KullThranUI" in BliZzi's provider dropdown,
-- and AUTO mode resolves KUI frames correctly.
-- The hook is idempotent (_kuiHooked guard) and fires either immediately (if
-- BliZzi loaded before KUI) or from OnAddonLoaded (if it loads after KUI).
local function InstallBliZziHook()
    if not (BIT and BIT.UnitFrames and BIT.UnitFrames.GetPartyFrame) then return end
    if BIT.UnitFrames._kuiHooked then return end
    BIT.UnitFrames._kuiHooked = true

    -- Returns the first visible KUI frame whose .unit matches the given token.
    local kuiModes = { "party", "raid", "raid40", "arena" }
    local function FindKUI(unit)
        if not (Mod and Mod.frames) then return nil end
        for _, mode in ipairs(kuiModes) do
            for _, frame in ipairs(Mod.frames[mode] or {}) do
                if frame.unit == unit and not frame.fakeUnit and frame:IsShown() then
                    return frame
                end
            end
        end
        if Mod.ownGroupFrames then
            for _, mode in ipairs({ "raid", "raid40" }) do
                for _, frame in ipairs(Mod.ownGroupFrames[mode] or {}) do
                    if frame.unit == unit and not frame.fakeUnit and frame:IsShown() then
                        return frame
                    end
                end
            end
        end
        return nil
    end

    -- Hook GetPartyFrame: handle "KULLTHRANUI" provider and inject into AUTO.
    local _origGetPartyFrame = BIT.UnitFrames.GetPartyFrame
    BIT.UnitFrames.GetPartyFrame = function(self, unit, providerOverride)
        if providerOverride == "KULLTHRANUI" then
            return FindKUI(unit)
        end
        if not providerOverride or providerOverride == "AUTO" then
            local f = FindKUI(unit)
            if f then return f end
        end
        return _origGetPartyFrame(self, unit, providerOverride)
    end

    -- Hook GetAvailableProviders: inject "KullThranUI" after AUTO.
    local _origGetProviders = BIT.UnitFrames.GetAvailableProviders
    BIT.UnitFrames.GetAvailableProviders = function(self)
        local list = _origGetProviders(self)
        table.insert(list, 2, { value = "KULLTHRANUI", label = "KullThranUI" })
        return list
    end

    -- Hook CountFrameAddons: KUI counts as one detected 3rd-party provider.
    local _origCount = BIT.UnitFrames.CountFrameAddons
    BIT.UnitFrames.CountFrameAddons = function(self)
        return (_origCount(self) or 0) + 1
    end
end

local function InstallExternalPartyFramesAPI()
    local api = GetExternalPartyFramesAPI()

    api.GetAllFrames = function(visibleOnly)
        if Mod and Mod.GetExternalAnchorFrames then
            return Mod:GetExternalAnchorFrames(visibleOnly)
        end
        return {}
    end

    api.RegisterCallback = function(owner, event, callback)
        if type(event) ~= "string" then return end
        if type(callback) ~= "function" and type(callback) ~= "string" then return end
        externalFrameCallbacks[event] = externalFrameCallbacks[event] or {}
        externalFrameCallbacks[event][owner or callback] = callback
    end

    api.UnregisterCallback = function(owner, event)
        if event then
            if externalFrameCallbacks[event] then
                externalFrameCallbacks[event][owner] = nil
            end
            return
        end
        for _, callbacks in pairs(externalFrameCallbacks) do
            callbacks[owner] = nil
        end
    end

    api.RefreshCallbacks = ScheduleExternalPartyFramesRefresh
    _G.KullThranUI_PartyFrames_GetAllFrames = api.GetAllFrames

    -- â”€â”€ BliZzi_Interrupts integration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    -- Try immediately in case BliZzi_Interrupts already loaded before KUI.
    -- If not, OnAddonLoaded will call InstallBliZziHook() when it fires.
    InstallBliZziHook()
end

function Mod:GetExternalAnchorFrames(visibleOnly)
    local result = {}
    for _, mode in ipairs(MODE_ORDER) do
        for _, frame in ipairs((self.frames and self.frames[mode]) or {}) do
            if frame and frame.unit and not frame.fakeUnit and (frame:IsShown() or not visibleOnly) then
                result[#result + 1] = frame
            end
        end
    end
    return result
end

function Mod:OnInitialize()
    InstallExternalPartyFramesAPI()
    self:EnsureDB()
    self.containers = {}
    self.ownGroupContainers = {}
    self.frames = {}
    self.ownGroupFrames = {}
    self.auraCache = {}
    self.testMode = {}
    self.testAuraSeeds = {}
    self.testAnimationPhase = 0
    self.pendingLayout = {}
    self.elementsRegistered = false
    self.arenaDRState = {}
    self.arenaDRScan = {}
    self.arenaTrinketIcons = {}
end

SLASH_KTPFDEBUG1 = "/ktpfdebug"
SlashCmdList.KTPFDEBUG = function(msg)
    local mod = KT and KT.GetModule and KT:GetModule("PartyFrames", true)
    if not mod then
        AuraDebugChat("PartyFrames module not loaded.")
        return
    end
    msg = string.lower(tostring(msg or ""))
    if msg == "on" or msg == "1" or msg == "true" then
        mod:SetAuraSpellDebug(true)
    elseif msg == "off" or msg == "0" or msg == "false" then
        mod:SetAuraSpellDebug(false)
    elseif msg:match("^dump") then
        local mode = msg:match("^dump%s+(%S+)") or "party"
        mod:SetAuraSpellDebug(true)
        mod:DumpAuraSpellDebug(mode)
    else
        AuraDebugChat("/ktpfdebug on | off | dump [party|raid|raid40|arena]")
    end
end

function Mod:OnEnable()
    self:EnsureDB()
    if self.db.enable == false then return end

    self:CreateContainers()
    self:CreateUnitFrames()
    self:RegisterUnlockElements()
    self:EnforceSinglePartyFrameSystem()

    self:RegisterModuleEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
    self:RegisterModuleEvent('ZONE_CHANGED_NEW_AREA', 'OnPlayerEnteringWorld')
    self:RegisterModuleEvent("ENCOUNTER_START", "OnEncounterStateChanged")
    self:RegisterModuleEvent("ENCOUNTER_END", "OnEncounterStateChanged")
    self:RegisterModuleEvent("GROUP_ROSTER_UPDATE", "OnGroupRosterUpdate")
    -- PARTY_LEADER_CHANGED covers leadership changes GROUP_ROSTER_UPDATE does
    -- not always fire for, and runs out of combat so leader reads stay untainted.
    self:RegisterModuleEvent("PARTY_LEADER_CHANGED", "OnGroupRosterUpdate")
    self:RegisterModuleEvent("RAID_ROSTER_UPDATE", "OnGroupRosterUpdate")
    self:RegisterModuleEvent('ARENA_OPPONENT_UPDATE', 'OnArenaRosterUpdate')
    self:RegisterModuleEvent('ARENA_PREP_OPPONENT_SPECIALIZATIONS', 'OnArenaRosterUpdate')
    self:RegisterModuleEvent('ARENA_COOLDOWNS_UPDATE', 'OnArenaCooldownUpdate')
    -- This legacy event is absent on some Retail builds. Keep the richer icon
    -- information when available without preventing the module from loading.
    pcall(self.RegisterModuleEvent, self, 'ARENA_CROWD_CONTROL_SPELL_UPDATE', 'OnArenaCrowdControlSpellUpdate')
    self:RegisterModuleEvent('PVP_MATCH_STATE_CHANGED', 'OnArenaCooldownUpdate')
    -- Deliberately NOT registered globally: UNIT_AURA / UNIT_HEALTH /
    -- UNIT_POWER_FREQUENT / UNIT_MAXHEALTH / UNIT_MAXPOWER / UNIT_DISPLAYPOWER /
    -- UNIT_CONNECTION / UNIT_NAME_UPDATE / UNIT_IN_RANGE_UPDATE fire for EVERY
    -- unit token in the game (nameplates, mobs, pets, targets...), a firehose
    -- in a 40-man raid. They are registered per-roster-unit via
    -- RegisterUnitEvent by RebuildRosterEvents (Grid2 / DandersFrames pattern),
    -- so events only arrive for units this addon actually displays.
    self:RegisterModuleEvent("READY_CHECK", "RefreshAllIndicators")
    self:RegisterModuleEvent("READY_CHECK_CONFIRM", "RefreshAllIndicators")
    self:RegisterModuleEvent("READY_CHECK_FINISHED", "RefreshAllIndicators")
    self:RegisterModuleEvent("RAID_TARGET_UPDATE", "OnRaidTargetUpdate")
    -- Deliberately NOT registered: NAME_PLATE_UNIT_ADDED/REMOVED fire for every
    -- nameplate spawn/despawn (dozens of mobs in a raid) and each one refreshed
    -- the raid-target lookup for all 40 frames. Marker changes are covered by
    -- RAID_TARGET_UPDATE alone.
    self:RegisterModuleEvent("PLAYER_SPECIALIZATION_CHANGED", "OnSpecChanged")
    self:RegisterModuleEvent("ACTIVE_TALENT_GROUP_CHANGED", "OnSpecChanged")
    self:RegisterModuleEvent("PLAYER_TALENT_UPDATE", "OnSpecChanged")
    self:RegisterModuleEvent("ADDON_LOADED", "OnAddonLoaded")
    self:RegisterModuleEvent("PLAYER_REGEN_DISABLED")
    self:RegisterModuleEvent("PLAYER_REGEN_ENABLED")
    -- Range is fully event-driven (UNIT_IN_RANGE_UPDATE); no repeating poll.
    self:ArmAuraDurationDriver()

    -- Roster-scoped UNIT_* registrations are NOT built here: OnEnable runs in
    -- the root addon's context, so frames created here would be billed to
    -- KullThranUI in nap (the attribution bug we fixed). They are built by
    -- RebuildRosterEvents from PLAYER_ENTERING_WORLD / GROUP_ROSTER_UPDATE,
    -- which fire through our own event frame (PartyFrames context).

    C_Timer.After(0, function()
        self:ApplyCurrentSpecProfile()
        self:EnforceSinglePartyFrameSystem()
        self:RefreshWorldRosterIfChanged(nil, false)
    end)
    C_Timer.After(1, function()
        self:EnforceSinglePartyFrameSystem()
    end)
end

function Mod:GetModeDB(mode)
    self:EnsureDB()
    return self.db[NormalizeMode(mode)]
end

function Mod:UpdateFrameRange(frame, updateAurasOnChange)
    if not (frame and frame.unit) or frame.fakeUnit then return true end
    if SafeUnitBoolean(UnitIsDeadOrGhost, frame.unit) or SafeUnitBoolean(UnitIsConnected, frame.unit) == false then
        return true
    end
    local db = self:GetModeDB(frame.mode or "party")
    if not db or db.rangeFadeEnabled == false then
        frame._ktInRange = true
        frame._ktOutOfRange = false
        frame:SetAlpha(1)
        return true
    end

    local inRange = SafeUnitInRange(frame.unit)
    local isSecret = IsSecretValue(inRange) or IsSecretValue(frame._ktInRange)
    local changed = isSecret or frame._ktInRange == nil or frame._ktInRange ~= inRange
    if changed then
        local wasOut = frame._ktOutOfRange == true
        frame._ktInRange = inRange
        if not IsSecretValue(inRange) then
            frame._ktOutOfRange = inRange == false
            if frame._ktOutOfRange then
                -- Out of range: aura data is unavailable, so the engine stops
                -- delivering UNIT_AURA and the AuraContainer would keep the stale
                -- buttons from the previous occupant of this frame (duplicate-looking
                -- debuffs on out-of-sight raid frames). Unbind so the engine drops
                -- them; rebind when the unit comes back into range.
                if ns.PF_UnbindAuraContainers then ns.PF_UnbindAuraContainers(frame) end
            elseif wasOut then
                if ns.PF_BindAuraContainers then ns.PF_BindAuraContainers(frame, frame.unit) end
                if self.auraCache then
                    self.auraCache[frame.unit] = nil
                end
            end
        else
            frame._ktOutOfRange = false
        end
        if updateAurasOnChange then
            self:UpdateFrameAuras(frame)
        end
    end

    ApplyFrameRangeAlpha(frame, inRange, db.rangeFadeAlpha)
    if not IsSecretValue(inRange) and inRange == true and SafeUnitBoolean(UnitIsAFK, frame.unit) then
        frame:SetAlpha(0.80)
    end
    return inRange
end

function Mod:RefreshRangeAll()
    if not self.frames then return end
    for _, mode in ipairs(MODE_ORDER) do
        for _, frame in ipairs(self.frames[mode] or {}) do
            if frame:IsShown() and frame.unit and not frame.fakeUnit then
                self:UpdateFrameRange(frame, true)
            end
        end
    end
    for _, mode in ipairs({ "raid", "raid40" }) do
        for _, frame in ipairs((self.ownGroupFrames and self.ownGroupFrames[mode]) or {}) do
            if frame:IsShown() and frame.unit and not frame.fakeUnit then
                self:UpdateFrameRange(frame, true)
            end
        end
    end
end

function Mod:OnUnitRange(_, unit)
    if not unit then return end
    -- SetFrameUnit keeps this index current for every live/duplicate frame.
    -- Walking every mode here made a single range event inspect the whole
    -- party/raid frame pool, so dispatch directly from unit -> button.
    -- dispatch model.
    local frames = self._auraUnitFrames and self._auraUnitFrames[unit]
    if not frames then return end
    for i = 1, #frames do
        local frame = frames[i]
        if frame and frame:IsShown() then
            self:UpdateFrameRange(frame, true)
        end
    end
end

function Mod:GetLayoutConfig(mode)
    return self:GetModeDB(mode)
end

function Mod:GetConfigValue(mode, key, fallback)
    local db = self:GetModeDB(mode)
    if db and db[key] ~= nil then
        return db[key]
    end
    return fallback
end

function Mod:SetConfigValue(mode, key, value)
    local db = self:GetModeDB(mode)
    if not db then return false end
    db[key] = value
    self.auraCache = {}
    return self:ApplyLayout(mode)
end

function Mod:HideBlizzardPartyFrames()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingExternalFrameHide = true
        return
    end

    SafeHideManagedFrame(_G.PartyFrame)

    for i = 1, 5 do
        SafeHideManagedFrame(_G["PartyMemberFrame" .. i])
        SafeHideManagedFrame(_G["PartyMemberFrame" .. i .. "PetFrame"])
        SafeHideManagedFrame(_G["PartyMemberFrame" .. i .. "BuffFrame"])
        SafeHideManagedFrame(_G["PartyMemberFrame" .. i .. "DebuffFrame"])
        SafeHideManagedFrame(_G["CompactPartyFrameMember" .. i])
        SafeHideManagedFrame(_G["ArenaEnemyFrame" .. i])
    end

    SafeHideManagedFrame(_G.ArenaEnemyFrames)
    SafeHideManagedFrame(_G.ArenaEnemyFramesContainer)
    SafeHideManagedFrame(_G.CompactArenaFrame)
    -- Retail stores the allied arena buttons in a child array. Suppress each
    -- fixed slot without iterating the Blizzard-owned collection.
    local compactArenaMembers = _G.CompactArenaFrame and _G.CompactArenaFrame.memberUnitFrames
    local canReadCompactArenaMembers = compactArenaMembers ~= nil
    if canReadCompactArenaMembers and issecrettable then
        local ok, secret = pcall(issecrettable, compactArenaMembers)
        canReadCompactArenaMembers = ok and not secret
    end
    if canReadCompactArenaMembers then
        for i = 1, 5 do
            local ok, member = pcall(function() return compactArenaMembers[i] end)
            if ok then SafeHideManagedFrame(member) end
        end
    end

    SafeHideManagedFrame(_G.CompactPartyFrame)
    if _G.CompactPartyFrame then
        SafeHideManagedFrame(_G.CompactPartyFrame.title)
        SafeHideManagedFrame(_G.CompactPartyFrame.borderFrame)
        SafeHideManagedFrame(_G.CompactPartyFrame.dropdown)
        SafeHideManagedFrame(_G.CompactPartyFrame.menuButton)
    end

    SafeHideManagedFrame(_G.CompactRaidFrameContainer)
    if _G.CompactRaidFrameContainer and _G.CompactRaidFrameContainer.SetScale and not (InCombatLockdown and InCombatLockdown()) then
        pcall(_G.CompactRaidFrameContainer.SetScale, _G.CompactRaidFrameContainer, 0.001)
    end
    for i = 1, 40 do
        SafeHideManagedFrame(_G["CompactRaidFrame" .. i])
    end
    for group = 1, 8 do
        SafeHideManagedFrame(_G["CompactRaidGroup" .. group])
        for member = 1, 5 do
            SafeHideManagedFrame(_G["CompactRaidGroup" .. group .. "Member" .. member])
        end
    end
end

function Mod:HideLegacyKUIUnitFramesParty()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingExternalFrameHide = true
        return
    end

    for i = 1, 4 do
        SafeHideManagedFrame(_G["KullThranUI_UF_Party" .. i])
    end
end

function Mod:HideExternalPartyFrameAddons()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingExternalFrameHide = true
        return
    end

    local DF = _G.DandersFrames or _G.DF
    if DF then
        if DF.HideTestFrames then pcall(DF.HideTestFrames, DF, true) end
        if DF.HideRaidTestFrames then pcall(DF.HideRaidTestFrames, DF) end
        SafeHideManagedFrame(DF.partyContainer)
        SafeHideManagedFrame(DF.raidContainer)
        SafeHideManagedFrame(DF.arenaHeader)
        SafeHideManagedFrame(DF.container)
    end

    if _G.DandersFrames_GetPartyContainer then
        local ok, frame = pcall(_G.DandersFrames_GetPartyContainer)
        if ok then SafeHideManagedFrame(frame) end
    end
    if _G.DandersFrames_GetRaidContainer then
        local ok, frame = pcall(_G.DandersFrames_GetRaidContainer)
        if ok then SafeHideManagedFrame(frame) end
    end
    if _G.DandersFrames_GetArenaHeader then
        local ok, frame = pcall(_G.DandersFrames_GetArenaHeader)
        if ok then SafeHideManagedFrame(frame) end
    end

    SafeHideManagedFrame(_G.DandersFramesContainer)
    SafeHideManagedFrame(_G.DandersPartyContainer)
    SafeHideManagedFrame(_G.DandersRaidContainer)
    SafeHideManagedFrame(_G.DandersRaidFramesContainer)
    SafeHideManagedFrame(_G.DandersArenaHeader)
end

function Mod:EnforceSinglePartyFrameSystem()
    if not (self.db and self.db.enable ~= false) then return end
    self:HideBlizzardPartyFrames()
    self:HideLegacyKUIUnitFramesParty()
    self:HideExternalPartyFrameAddons()
end

function Mod:GetRootConfigValue(key, fallback)
    self:EnsureDB()
    if self.db[key] ~= nil then
        return self.db[key]
    end
    return fallback
end

function Mod:SetRootConfigValue(key, value)
    self:EnsureDB()
    self.db[key] = value
    if key == "autoProfileBySpec" and value then
        return self:ApplyCurrentSpecProfile(true)
    end
    return true
end

local function CopyPresetSection(src, dst)
    if not (src and dst) then return end
    for key, value in pairs(src) do
        if type(value) == "table" then
            dst[key] = dst[key] or {}
            CopyPresetSection(value, dst[key])
        else
            dst[key] = value
        end
    end
end

function Mod:GetPresetDefinitions()
    return PROFILE_PRESETS
end

function Mod:GetPlayerSpecs()
    local specs = {}
    if not (_G.GetNumSpecializations and GetSpecializationInfo) then return specs end
    local count = _G.GetNumSpecializations(false, false) or 0
    for i = 1, count do
        local info = GetSpecInfo(i)
        if info then
            specs[#specs + 1] = info
        end
    end
    return specs
end

function Mod:GetCurrentSpecInfo()
    if not _G.GetSpecialization then return nil end
    return GetSpecInfo(_G.GetSpecialization())
end

function Mod:GetSpecProfileAssignment(specID)
    self:EnsureDB()
    specID = tonumber(specID)
    if not specID then return PF_STATIC.profileAuto end
    local value = self.db.specProfiles and self.db.specProfiles[specID]
    if value == "dps_tank" or value == "heal" then
        return value
    end
    return PF_STATIC.profileAuto
end

function Mod:SetSpecProfileAssignment(specID, presetKey)
    self:EnsureDB()
    specID = tonumber(specID)
    if not specID then return false end
    self.db.specProfiles = self.db.specProfiles or {}
    if presetKey == "dps_tank" or presetKey == "heal" then
        self.db.specProfiles[specID] = presetKey
    else
        self.db.specProfiles[specID] = nil
    end
    local current = self:GetCurrentSpecInfo()
    if current and current.id == specID and self.db.autoProfileBySpec ~= false then
        return self:ApplyCurrentSpecProfile(true)
    end
    return true
end

function Mod:ResolveSpecProfile(specInfo)
    if not specInfo then return self.db and self.db.activePreset or "dps_tank" end
    local assigned = self:GetSpecProfileAssignment(specInfo.id)
    if assigned ~= PF_STATIC.profileAuto then
        return assigned
    end
    return GetAutoProfileForSpec(specInfo.id, specInfo.role)
end

function Mod:ApplyCurrentSpecProfile(force)
    self:EnsureDB()
    if self.db.autoProfileBySpec == false then return true end
    local specInfo = self:GetCurrentSpecInfo()
    if not specInfo then return true end
    local presetKey = self:ResolveSpecProfile(specInfo)
    if not force and self.db.activePreset == presetKey then
        self._lastSpecProfileID = specInfo.id
        return true
    end
    self._lastSpecProfileID = specInfo.id
    return self:ApplyPreset(presetKey, true)
end

function Mod:ApplyPreset(presetKey, fromSpecAuto)
    local preset = PROFILE_PRESETS[presetKey]
    if not preset then return false, "missing" end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingPresetKey = presetKey
        return false, "combat"
    end

    self:EnsureDB()
    for _, mode in ipairs(MODE_ORDER) do
        CopyPresetSection(preset[mode] or (mode == "raid40" and preset.raid), self.db[mode])
        if mode == "raid40" then
            self.db[mode].raidTestFrameCount = 40
        end
    end
    self.db.profilePositions = self.db.profilePositions or {}
    if self.db.profilePositions[presetKey] then
        CopyPositions(self.db.profilePositions[presetKey], self.db.positions)
    else
        CopyPositions(preset.positions, self.db.positions)
        self.db.profilePositions[presetKey] = {}
        CopyPositions(self.db.positions, self.db.profilePositions[presetKey])
    end
    self.db.activePreset = presetKey
    if not fromSpecAuto then
        self._lastSpecProfileID = nil
    end
    self:RefreshAll()
    return true
end

function Mod:CreateContainers()
    for _, mode in ipairs(MODE_ORDER) do
        if not self.containers[mode] then
            local name = "KUIPartyFrames" .. mode:gsub("^%l", string.upper) .. "Container"
            local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
            frame:SetSize(260, 120)
            frame:SetClampedToScreen(true)
            frame:Hide()
            self.containers[mode] = frame
            self:ApplyPosition(mode)
        end
    end
    self.ownGroupContainers = self.ownGroupContainers or {}
    for _, mode in ipairs({ "raid", "raid40" }) do
        if not self.ownGroupContainers[mode] then
            local name = "KUIPartyFrames" .. mode:gsub("^%l", string.upper) .. "OwnGroupContainer"
            local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
            frame:SetSize(120, 260)
            frame:SetClampedToScreen(true)
            frame:Hide()
            self.ownGroupContainers[mode] = frame
            self:ApplyOwnGroupPosition(mode)
        end
    end
end

local function CreateAuraIcon(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(18, 18)
    if parent and parent.GetFrameLevel then
        holder:SetFrameLevel((parent:GetFrameLevel() or 0) + 5)
    end
    holder.bg = holder:CreateTexture(nil, "BACKGROUND")
    holder.bg:SetAllPoints()
    holder.bg:SetColorTexture(0, 0, 0, 0.86)
    holder.icon = holder:CreateTexture(nil, "ARTWORK")
    holder.icon:SetPoint("TOPLEFT", 2, -2)
    holder.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    holder.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    holder.cooldown = CreateFrame("Cooldown", nil, holder, "CooldownFrameTemplate")
    holder.cooldown:SetAllPoints(holder.icon)
    holder.cooldown.noCooldownCount = true
    holder.cooldown.noOCC = true
    holder.cooldown.noCooldownText = true
    holder.cooldown:SetDrawEdge(false)
    holder.cooldown:SetDrawSwipe(true)
    holder.cooldown:SetReverse(true)
    if holder.cooldown.SetHideCountdownNumbers then
        holder.cooldown:SetHideCountdownNumbers(true)
    end
    holder.cooldown:Hide()
    holder.duration = holder.cooldown:CreateFontString(nil, "OVERLAY")
    holder.duration:SetFont(ResolveFontPath(), 9, "OUTLINE")
    holder.duration:SetPoint("CENTER", holder, "CENTER", 0, 0)
    holder.duration:SetTextColor(1, 1, 1, 1)
    holder.duration:SetShadowColor(0, 0, 0, 1)
    holder.duration:SetShadowOffset(1, -1)
    holder.duration:Hide()
    holder.count = holder.cooldown:CreateFontString(nil, "OVERLAY")
    holder.count:SetFont(ResolveFontPath(), 11, "OUTLINE")
    holder.count:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -1, -1)
    holder.count:SetTextColor(1, 1, 1, 1)
    holder.count:SetShadowColor(0, 0, 0, 1)
    holder.count:SetShadowOffset(1, -1)
    -- OnUpdate removed, handled by centralized ticker
    local top = holder:CreateTexture(nil, "OVERLAY")
    top:SetTexture([[Interface\Buttons\WHITE8X8]])
    top:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    top:SetPoint("BOTTOMRIGHT", holder, "TOPRIGHT", 0, -2)

    local bottom = holder:CreateTexture(nil, "OVERLAY")
    bottom:SetTexture([[Interface\Buttons\WHITE8X8]])
    bottom:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, 2)

    local left = holder:CreateTexture(nil, "OVERLAY")
    left:SetTexture([[Interface\Buttons\WHITE8X8]])
    left:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -2)
    left:SetPoint("BOTTOMRIGHT", holder, "BOTTOMLEFT", 2, 2)

    local right = holder:CreateTexture(nil, "OVERLAY")
    right:SetTexture([[Interface\Buttons\WHITE8X8]])
    right:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, -2)
    right:SetPoint("BOTTOMLEFT", holder, "BOTTOMRIGHT", -2, 2)

    holder.border = { top, bottom, left, right }
    holder:Hide()
    return holder
end

local function CreateDispelFrameBorder(parent)
    local border = {}
    for i = 1, 4 do
        border[i] = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        border[i]:SetColorTexture(0, 0, 0, 0)
        border[i]:Hide()
    end
    border[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border[1]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border[2]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border[2]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border[3]:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border[3]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border[4]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border[4]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientTop = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientTop:SetTexture(PF_STATIC.whiteTexture)
    border.gradientTop:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.gradientTop:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.gradientTop:Hide()
    border.gradientBottom = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientBottom:SetTexture(PF_STATIC.whiteTexture)
    border.gradientBottom:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.gradientBottom:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientBottom:Hide()
    border.gradientLeft = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientLeft:SetTexture(PF_STATIC.whiteTexture)
    border.gradientLeft:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    border.gradientLeft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    border.gradientLeft:Hide()
    border.gradientRight = parent:CreateTexture(nil, "ARTWORK", nil, 2)
    border.gradientRight:SetTexture(PF_STATIC.whiteTexture)
    border.gradientRight:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    border.gradientRight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    border.gradientRight:Hide()
    return border
end

local function CreateOverlayIcon(parent, size)
    local holder = CreateFrame("Frame", nil, parent)
    if parent then holder:SetFrameStrata(parent:GetFrameStrata()) end
    holder:SetSize(size or 16, size or 16)
    if parent and parent.GetFrameLevel then
        holder:SetFrameLevel((parent:GetFrameLevel() or 0) + 20)
    end
    holder.texture = holder:CreateTexture(nil, "OVERLAY")
    holder.texture:SetAllPoints()
    holder:Hide()
    return holder
end

local function SetBlizzardRoleIconCoords(texture, role)
    if not texture then return end
    local coords = PF_STATIC.roleCoords[role]
    if coords then
        texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function Clamp01(value, fallback)
    value = tonumber(value)
    if value == nil then return fallback end
    if IsSecretValue(value) then return fallback end
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function ResetReusableTexture(texture, alpha)
    if not texture then return end
    if texture.SetTexture then texture:SetTexture(PF_STATIC.whiteTexture) end
    if texture.SetTexCoord then texture:SetTexCoord(0, 1, 0, 1) end
    if texture.SetBlendMode then texture:SetBlendMode("BLEND") end
    if texture.SetVertexColor then texture:SetVertexColor(1, 1, 1, alpha == nil and 1 or alpha) end
end

local function HideDispelTexture(texture)
    if not texture then return end
    ResetReusableTexture(texture, 0)
    texture:Hide()
end

local function HideDispelFrameBorder(border)
    if not border then return end
    for _, edge in ipairs(border) do
        if edge then
            edge:SetColorTexture(0, 0, 0, 0)
            edge:Hide()
        end
    end
    HideDispelTexture(border.gradientTop)
    HideDispelTexture(border.gradientBottom)
    HideDispelTexture(border.gradientLeft)
    HideDispelTexture(border.gradientRight)
end

local function SetDispelFrameBorder(frame, color, alpha, thickness, gradientAlpha, gradientSize)
    local border = frame and frame.dispelBorder
    if not border then return end
    if not color then
        HideDispelFrameBorder(border)
        return
    end
    
    thickness = math.max(1, math.min(4, tonumber(thickness) or 2))
    alpha = math.max(0, math.min(1, tonumber(alpha) or 1.0))
    gradientAlpha = math.max(0, math.min(1, tonumber(gradientAlpha) or 1.0))
    gradientSize = math.max(0.12, math.min(0.60, tonumber(gradientSize) or 0.5))
    
    -- Extract color dynamically without touching secret values
    local function SafeSetColor(tex, colorObj, overrideAlpha)
        if colorObj.GetRGBA then
            local r, g, b, a = colorObj:GetRGBA()
            if overrideAlpha ~= nil then
                tex:SetVertexColor(r, g, b, overrideAlpha)
            else
                tex:SetVertexColor(r, g, b, a)
            end
        else
            tex:SetVertexColor(colorObj.r or 1, colorObj.g or 1, colorObj.b or 1, overrideAlpha or colorObj.a or 1)
        end
    end
    
    border[1]:SetHeight(thickness)
    border[2]:SetHeight(thickness)
    border[3]:SetWidth(thickness)
    border[4]:SetWidth(thickness)
    for _, edge in ipairs(border) do
        edge:SetTexture("Interface\\Buttons\\WHITE8X8")
        SafeSetColor(edge, color, alpha)
        edge:Show()
    end
    
    local width = tonumber(frame._layoutWidth) or 1
    local height = tonumber(frame._layoutHeight) or 1
    local edgeH = math.max(thickness + 3, math.floor(height * gradientSize))
    local edgeW = math.max(thickness + 3, math.floor(width * gradientSize))
    local fadeAlpha = math.min(gradientAlpha, alpha * 0.9)
    
    if border.gradientTop then
        border.gradientTop:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_V")
        border.gradientTop:SetHeight(edgeH)
        SafeSetColor(border.gradientTop, color, fadeAlpha)
        border.gradientTop:SetBlendMode("BLEND")
        border.gradientTop:Show()
    end
    if border.gradientBottom then
        border.gradientBottom:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_V_Rev")
        border.gradientBottom:SetHeight(edgeH)
        SafeSetColor(border.gradientBottom, color, fadeAlpha)
        border.gradientBottom:SetBlendMode("BLEND")
        border.gradientBottom:Show()
    end
    if border.gradientLeft then
        border.gradientLeft:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_H")
        border.gradientLeft:SetWidth(edgeW)
        SafeSetColor(border.gradientLeft, color, fadeAlpha)
        border.gradientLeft:SetBlendMode("BLEND")
        border.gradientLeft:Show()
    end
    if border.gradientRight then
        border.gradientRight:SetTexture("Interface\\AddOns\\KullThranUI\\Media\\DF_Gradient_H_Rev")
        border.gradientRight:SetWidth(edgeW)
        SafeSetColor(border.gradientRight, color, fadeAlpha)
        border.gradientRight:SetBlendMode("BLEND")
        border.gradientRight:Show()
    end
end

local function GetDispelColorCurve(alpha)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType and CreateColor) then
        return nil
    end
    alpha = tonumber(alpha) or 1
    local key = string.format("%.2f", alpha)
    if dispelColorCurves[key] then
        return dispelColorCurves[key]
    end
    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, CreateColor(0, 0, 0, 0))
    for name, enumValue in pairs(DISPEL_ENUM_BY_NAME) do
        local c = DISPEL_COLORS[name]
        if c then
            curve:AddPoint(enumValue, CreateColor(c.r, c.g, c.b, alpha))
        end
    end
    dispelColorCurves[key] = curve
    return curve
end

local function GetAuraDispelColor(unit, auraInstanceID, alpha)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor and unit and auraInstanceID) then
        return nil
    end
    local curve = GetDispelColorCurve(alpha)
    if not curve then return nil end
    local ok, color = pcall(C_UnitAuras.GetAuraDispelTypeColor, unit, auraInstanceID, curve)
    if ok and color then
        return color
    end
    return nil
end

function Mod:CreateUnitButton(parent, name)
    local button = CreateFrame("Button", name, parent, "SecureUnitButtonTemplate")
    button:RegisterForClicks("AnyUp")
    button:SetAttribute("*type1", "target")
    button:SetAttribute("type1", "target")
    button:SetAttribute("*type2", "togglemenu")
    button:SetAttribute("type2", "togglemenu")
    button:SetHighlightTexture("")
    button:EnableMouse(true)
    button._ktPartyFrame = true

    if KT.AddBackdrop then
        KT:AddBackdrop(button, 0.03, 0.035, 0.045, 0.95)
    end
    if KT.AddBorder then
        KT:AddBorder(button, 0, 0, 0, 1)
    end

    button.health = CreateFrame("StatusBar", nil, button)
    button.health:SetPoint("TOPLEFT", 3, -3)
    button.health:SetPoint("TOPRIGHT", -3, -3)
    button.health:SetHeight(34)
    button.health:SetMinMaxValues(0, 1)
    button.health:SetValue(1)
    button.health:SetStatusBarTexture(TEXTURE_FILL)
    button.health.bg = button.health:CreateTexture(nil, "BACKGROUND")
    button.health.bg:SetAllPoints()
    button.health.bg:SetTexture(PF_STATIC.textureBG)
    button.health.bg:SetVertexColor(0.05, 0.05, 0.06, 1)

    button.absorb = CreateFrame("StatusBar", nil, button.health)
    button.absorb:SetMinMaxValues(0, 100)
    button.absorb:SetReverseFill(true)
    button.absorb:SetFrameLevel(button.health:GetFrameLevel() + 2)
    button.absorb:SetStatusBarTexture(TEXTURE_FILL)
    button.absorb:Hide()

    button.power = CreateFrame("StatusBar", nil, button)
    button.power:SetPoint("TOPLEFT", button.health, "BOTTOMLEFT", 0, -2)
    button.power:SetPoint("TOPRIGHT", button.health, "BOTTOMRIGHT", 0, -2)
    button.power:SetHeight(6)
    button.power:SetMinMaxValues(0, 1)
    button.power:SetValue(1)
    button.power:SetStatusBarTexture(TEXTURE_FILL)
    button.power.bg = button.power:CreateTexture(nil, "BACKGROUND")
    button.power.bg:SetAllPoints()
    button.power.bg:SetTexture(PF_STATIC.textureBG)
    button.power.bg:SetVertexColor(0.04, 0.04, 0.05, 1)

    button.overlayFrame = CreateFrame("Frame", nil, button)
    button.overlayFrame:SetAllPoints(button.health)
    button.overlayFrame:SetFrameLevel(button.health:GetFrameLevel() + 5)

    button.dispelOverlay = button.health:CreateTexture(nil, "ARTWORK", nil, 5)
    button.dispelOverlay:SetAllPoints(button.health)
    button.dispelOverlay:SetTexture(PF_STATIC.whiteTexture)
    button.dispelOverlay:SetBlendMode("ADD")
    button.dispelOverlay:Hide()

    button.dispelBorderFrame = CreateFrame("Frame", nil, button)
    button.dispelBorderFrame:SetAllPoints(button)
    button.dispelBorderFrame:SetFrameLevel(button:GetFrameLevel() + 16)
    button.dispelBorder = CreateDispelFrameBorder(button.dispelBorderFrame)

    button.statusIconFrame = CreateFrame("Frame", nil, button)
    button.statusIconFrame:SetAllPoints(button.health)
    button.statusIconFrame:SetFrameLevel(button.dispelBorderFrame:GetFrameLevel() + 2)
    button.statusIcon = button.statusIconFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    button.statusIcon:SetSize(20, 20)
    button.statusIcon:SetPoint("CENTER", button.health, "CENTER", 0, 0)
    button.statusIcon:Hide()

    button.nameText = button.overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.nameText:SetJustifyH("LEFT")
    button.nameText:SetWordWrap(false)
    if button.nameText.SetNonSpaceWrap then button.nameText:SetNonSpaceWrap(false) end
    ApplyTextStyle(button.nameText, DEFAULTS.party, "nameFontSize", 15)

    button.valueText = button.overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    button.valueText:SetJustifyH("RIGHT")
    button.valueText:SetWordWrap(false)
    if button.valueText.SetNonSpaceWrap then button.valueText:SetNonSpaceWrap(false) end
    ApplyTextStyle(button.valueText, DEFAULTS.party, "healthTextFontSize", 12)

    button.roleIcon = button.overlayFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    button.roleIcon:SetSize(18, 18)
    button.roleIcon:Hide()

    button.specIconFrame = CreateFrame('Frame', nil, button, 'BackdropTemplate')
    button.specIconFrame:SetFrameLevel(button:GetFrameLevel() + 2)
    button.specIconFrame:SetFrameStrata(button:GetFrameStrata())
    button.specIconFrame.bg = button.specIconFrame:CreateTexture(nil, 'BACKGROUND')
    button.specIconFrame.bg:SetAllPoints()
    button.specIconFrame.bg:SetColorTexture(0.015, 0.015, 0.02, 0.98)
    button.specIconFrame.icon = button.specIconFrame:CreateTexture(nil, 'ARTWORK')
    button.specIconFrame.icon:SetPoint('TOPLEFT', 2, -2)
    button.specIconFrame.icon:SetPoint('BOTTOMRIGHT', -2, 2)
    if KT.AddBorder then
        KT:AddBorder(button.specIconFrame, 0.85, 0.42, 0.04, 1)
    end
    button.specIconFrame:Hide()

    button.leaderIcon = CreateOverlayIcon(button.overlayFrame, 12)
    button.raidTargetIcon = CreateOverlayIcon(button, 16)
    button.readyCheckIcon = CreateOverlayIcon(button.overlayFrame, 16)

    button.statusText = button.overlayFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.statusText:SetJustifyH("CENTER")
    button.statusText:SetWordWrap(false)
    if button.statusText.SetNonSpaceWrap then button.statusText:SetNonSpaceWrap(false) end
    ApplyTextStyle(button.statusText, DEFAULTS.party, "healthTextFontSize", 12)
    button.statusText:Hide()

    button.auraFrame = CreateFrame("Frame", nil, button)
    button.auraFrame:SetAllPoints(button)
    button.auraFrame:SetFrameLevel(button.overlayFrame:GetFrameLevel() + 2)
    button.auraFrame:SetFrameStrata(button:GetFrameStrata())
    button.buffIcons = {}
    button.debuffIcons = {}
    for i = 1, 5 do
        button.buffIcons[i] = CreateAuraIcon(button.auraFrame)
        button.debuffIcons[i] = CreateAuraIcon(button.auraFrame)
    end

    button.ccIcon = CreateAuraIcon(button.auraFrame)
    button.ccIcon.ccText = button.ccIcon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.ccIcon.ccText:SetPoint("CENTER")
    button.ccIcon.ccText:SetText("CC")
    button.ccIcon.ccText:SetTextColor(1, 0.20, 0.20, 1)
    button.ccIcon.ccText:SetShadowColor(0, 0, 0, 1)
    button.ccIcon.ccText:SetShadowOffset(1, -1)

    button.trinketIcon = CreateAuraIcon(button.auraFrame)
    button.trinketIcon.cooldown.noCooldownCount = nil
    button.trinketIcon.cooldown.noOCC = nil
    if button.trinketIcon.cooldown.SetHideCountdownNumbers then
        button.trinketIcon.cooldown:SetHideCountdownNumbers(false)
    end
    button.trinketIcon.trinketText = button.trinketIcon:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
    button.trinketIcon.trinketText:SetPoint('BOTTOM', 0, 1)
    button.trinketIcon.trinketText:SetText('')
    button.trinketIcon.trinketText:SetFont(ResolveFontPath(), 7, 'OUTLINE')
    button.trinketIcon.trinketText:SetTextColor(1, 1, 1, 1)

    button.drIcons = {}
    for i = 1, 4 do
        local icon = CreateAuraIcon(button.auraFrame)
        icon.drLevel = icon:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
        icon.drLevel:SetPoint('TOPLEFT', 2, -1)
        icon.drLevel:SetFont(ResolveFontPath(), 9, 'OUTLINE')
        icon.drLevel:SetTextColor(1, 1, 1, 1)
        button.drIcons[i] = icon
    end

    button.missingBuffIcon = CreateAuraIcon(button.auraFrame)
    button.missingBuffIcon.missingText = button.missingBuffIcon:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    button.missingBuffIcon.missingText:SetPoint("BOTTOM", 0, -1)
    button.missingBuffIcon.missingText:SetText("!")
    button.missingBuffIcon.missingText:SetTextColor(1, 0.15, 0.15, 1)
    button.missingBuffIcon.missingText:SetShadowColor(0, 0, 0, 1)
    button.missingBuffIcon.missingText:SetShadowOffset(1, -1)
    button.missingBuffIcon.missingText:Hide()

    button.hover = button:CreateTexture(nil, "HIGHLIGHT")
    button.hover:SetAllPoints()
    button.hover:SetColorTexture(1, 1, 1, 0.08)

    button:SetScript("OnEnter", ShowUnitTooltip)
    button:SetScript("OnLeave", HideUnitTooltip)

    return button
end

function Mod:CreateUnitFrames()
    for _, mode in ipairs(MODE_ORDER) do
        self.frames[mode] = self.frames[mode] or {}
        local maxFrames = IsRaidMode(mode) and 40 or 5
        for i = 1, maxFrames do
            if not self.frames[mode][i] then
                self.frames[mode][i] = self:CreateUnitButton(self.containers[mode], "KUIPartyFrames" .. mode .. i)
            end
        end
    end
    self.ownGroupFrames = self.ownGroupFrames or {}
    for _, mode in ipairs({ "raid", "raid40" }) do
        self.ownGroupFrames[mode] = self.ownGroupFrames[mode] or {}
        for i = 1, 5 do
            if not self.ownGroupFrames[mode][i] then
                self.ownGroupFrames[mode][i] = self:CreateUnitButton(self.ownGroupContainers[mode], "KUIPartyFrames" .. mode .. "OwnGroup" .. i)
            end
        end
    end
    ScheduleExternalPartyFramesRefresh()
end

local function SetAuraIconBorderColor(icon, r, g, b, alpha)
    if not icon then return end
    r, g, b = Clamp01(r, 0), Clamp01(g, 0), Clamp01(b, 0)
    alpha = Clamp01(alpha, 0.8)
    
    if icon.bg then
        local bgAlpha = (r == 0 and g == 0 and b == 0) and 0.86 or 1
        icon.bg:SetColorTexture(r, g, b, bgAlpha)
    end

    if icon.border then
        local top, bottom, left, right = unpack(icon.border)
        if top and bottom and left and right then
            local dr, dg, db = r * 0.35, g * 0.35, b * 0.35
            top:SetVertexColor(r, g, b, alpha)
            bottom:SetVertexColor(dr, dg, db, alpha)
if left.SetGradientAlpha then
                left:SetGradientAlpha("VERTICAL", dr, dg, db, alpha, r, g, b, alpha)
                right:SetGradientAlpha("VERTICAL", dr, dg, db, alpha, r, g, b, alpha)
            elseif left.SetGradient then
                -- Pool or reuse ColorMixin objects to avoid GC pressure
                if not Mod._tempColor1 then Mod._tempColor1 = CreateColor(0,0,0,1) end
                if not Mod._tempColor2 then Mod._tempColor2 = CreateColor(0,0,0,1) end
                Mod._tempColor1:SetRGBA(dr, dg, db, alpha)
                Mod._tempColor2:SetRGBA(r, g, b, alpha)
                left:SetGradient("VERTICAL", Mod._tempColor1, Mod._tempColor2)
                right:SetGradient("VERTICAL", Mod._tempColor1, Mod._tempColor2)
            end
            top:Show()
            bottom:Show()
            left:Show()
            right:Show()
        else
            for _, edge in ipairs(icon.border) do
                if edge then
                    edge:SetVertexColor(r, g, b, alpha)
                    edge:Show()
                end
            end
        end
    end
end

local function HideAuraIcon(icon)
    if not icon then return end
    if Mod._durationIcons then
        Mod._durationIcons[icon] = nil
    end
    -- ApplyLayout visits every preallocated party/raid/arena frame. Most of
    -- those icons are already empty, especially while switching into a BG.
    if icon._ktAuraCleared and not icon:IsShown() then return end
    icon.icon:SetTexture(nil)
    if icon.bg then icon.bg:SetTexture(nil) end
    if icon.cooldown then icon.cooldown:Hide() end
    if icon.duration then
        icon.duration:SetText("")
        icon.duration:Hide()
    end
    icon._auraExpirationTime = nil
    icon._durationElapsed = 0
    if icon.count then icon.count:SetText("") end
    if icon.border then
        for _, edge in ipairs(icon.border) do
            if edge then edge:Hide() end
        end
    end
    -- RenderAuraIcon always assigns the next visible border colour.
    icon._ktAuraCleared = true
    icon:Hide()
end

local function HideAuraIconSet(icons)
    if not icons then return end
    for _, icon in ipairs(icons) do
        HideAuraIcon(icon)
    end
end

local function ReadAuraIcon(auraData)
    if not auraData then return nil end
    return auraData.icon or auraData.texture
end

local function SetAuraTextureSafe(texture, value)
    if not (texture and value) then return false end
    local ok = pcall(texture.SetTexture, texture, value)
    return ok == true
end

local function FormatAuraDuration(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then return nil end
    if seconds >= 3600 then
        return tostring(math.floor((seconds / 3600) + 0.5)) .. "h"
    elseif seconds >= 60 then
        return tostring(math.floor((seconds / 60) + 0.5)) .. "m"
    elseif seconds >= 10 then
        return tostring(math.floor(seconds + 0.5))
    end
    return tostring(math.max(1, math.floor(seconds + 0.5)))
end

local function UpdateAuraDurationText(icon)
    if not (icon and icon.duration and icon._auraExpirationTime and _G.GetTime) then
        if icon and icon.duration then
            icon.duration:SetText("")
            icon.duration:Hide()
        end
        return
    end
    local remaining = icon._auraExpirationTime - _G.GetTime()
    local text = FormatAuraDuration(remaining)
    if text then
        icon.duration:SetText(text)
        icon.duration:Show()
    else
        icon.duration:SetText("")
        icon.duration:Hide()
    end
end

local function SetAuraDurationTextState(icon, aura)
    if not icon then return end
    Mod._durationIcons = Mod._durationIcons or {}
    Mod._durationIcons[icon] = nil
    icon._auraExpirationTime = nil
    icon._durationElapsed = 0
    if icon.duration then
        icon.duration:SetText("")
        icon.duration:Hide()
    end
    local expirationTime = aura and aura.expirationTime
    if expirationTime
        and not IsSecretValue(expirationTime)
        and type(expirationTime) == "number"
        and expirationTime > 0 then
        icon._auraExpirationTime = expirationTime
        icon._updateDurationText = UpdateAuraDurationText
        Mod._durationIcons[icon] = true
        Mod:ArmAuraDurationDriver()
        UpdateAuraDurationText(icon)
    end
end

local function SetAuraCooldownSafe(cooldown, aura)
    if not cooldown then return end
    cooldown:Hide()
    if not aura then return end

    if aura.durationObject and cooldown.SetCooldownFromDurationObject then
        local ok = pcall(cooldown.SetCooldownFromDurationObject, cooldown, aura.durationObject)
        if ok then
            cooldown:Show()
            return
        end
    end

    local duration, expirationTime = aura.duration, aura.expirationTime
    if duration and expirationTime
        and not IsSecretValue(duration)
        and not IsSecretValue(expirationTime)
        and type(duration) == "number"
        and type(expirationTime) == "number"
        and duration > 0
        and expirationTime > 0 then
        local ok = false
        if cooldown.SetCooldownFromExpirationTime then
            ok = pcall(cooldown.SetCooldownFromExpirationTime, cooldown, expirationTime, duration)
        end
        if not ok and cooldown.SetCooldown then
            ok = pcall(cooldown.SetCooldown, cooldown, expirationTime - duration, duration)
        end
        if ok then cooldown:Show() end
    end
end

local function GetSpellNameSafe(spellID, fallback)
    spellID = tonumber(spellID)
    if spellID and C_Spell then
        if C_Spell.GetSpellInfo then
            local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
            if ok and type(info) == "table" and info.name and not IsSecretValue(info.name) then
                return info.name
            end
        end
        if C_Spell.GetSpellName then
            local ok, name = pcall(C_Spell.GetSpellName, spellID)
            if ok and name and not IsSecretValue(name) then
                return name
            end
        end
    end
    return fallback or ("Spell " .. tostring(spellID or ""))
end

local function GetSpellIconSafe(spellID, fallback)
    spellID = tonumber(spellID)
    if spellID and C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, spellID)
        if ok and icon and not IsSecretValue(icon) then
            return icon
        end
    end
    return fallback
end

local function ReadAuraSpellID(auraData)
    if not auraData then return nil end
    local spellID = auraData.spellId or auraData.spellID
    if IsSecretValue(spellID) then return nil end
    return tonumber(spellID)
end

local function ReadAuraName(auraData)
    if not auraData then return nil end
    local name = auraData.name
    if IsSecretValue(name) then return nil end
    return name
end

local function EnsureAuraSpellCatalog(db)
    if not db then return nil end
    if type(db.auraSpellCatalog) ~= "table" then
        db.auraSpellCatalog = {}
    end
    return db.auraSpellCatalog
end

local function RegisterAuraCatalogEntry(db, spellID, auraType, name, icon)
    spellID = tonumber(spellID)
    if not spellID then return end
    local catalog = EnsureAuraSpellCatalog(db)
    if not catalog then return end
    local key = tostring(spellID)
    local entry = catalog[key]
    if type(entry) == "table" and entry.name and entry.icon and (not auraType or entry.auraType == auraType) then
        return
    end
    local resolvedName = (name and not IsSecretValue(name) and name) or (type(entry) == "table" and entry.name) or GetSpellNameSafe(spellID)
    local resolvedIcon = (icon and not IsSecretValue(icon) and icon) or (type(entry) == "table" and entry.icon) or GetSpellIconSafe(spellID)
    if type(entry) ~= "table" then
        catalog[key] = {
            spellID = spellID,
            name = resolvedName,
            icon = resolvedIcon,
            auraType = auraType or "aura",
        }
        return
    end
    entry.spellID = spellID
    if resolvedName and entry.name ~= resolvedName then entry.name = resolvedName end
    if resolvedIcon and entry.icon ~= resolvedIcon then entry.icon = resolvedIcon end
    if auraType and entry.auraType ~= auraType then entry.auraType = auraType end
end

local function AuraSpellIsVisible(db, spellID)
    spellID = tonumber(spellID)
    if not spellID or not db or type(db.auraSpellVisibility) ~= "table" then return true end
    return db.auraSpellVisibility[tostring(spellID)] ~= false
end

local function AuraTypeMatchesCatalog(auraType, entryType)
    if not auraType or not entryType then return true end
    return auraType == entryType or (auraType == "debuff" and entryType == "aura")
end

local function NormalizeAuraName(name)
    if type(name) ~= "string" or name == "" then return nil end
    return string.lower(name)
end

local function AuraHiddenEntryMatches(entry, auraType, auraName, auraIcon)
    if type(entry) ~= "table" or not AuraTypeMatchesCatalog(auraType, entry.auraType) then
        return false
    end
    local entryName = NormalizeAuraName(entry.name)
    if auraName and entryName and auraName == entryName then
        return true
    end
    if auraIcon and entry.icon and not IsSecretValue(auraIcon) and auraIcon == entry.icon then
        return true
    end
    return false
end

local function AuraHiddenSpellMatches(db, hiddenSpellID, auraType, auraName, auraIcon)
    hiddenSpellID = tonumber(hiddenSpellID)
    if not hiddenSpellID then return false end

    local catalog = db and db.auraSpellCatalog
    local entry = type(catalog) == "table" and catalog[tostring(hiddenSpellID)] or nil
    if AuraHiddenEntryMatches(entry, auraType, auraName, auraIcon) then
        return true
    end
    for _, sample in ipairs(SAMPLE_AURA_CATALOG) do
        if tonumber(sample.spellID) == hiddenSpellID and AuraHiddenEntryMatches(sample, auraType, auraName, auraIcon) then
            return true
        end
    end
    for _, rule in pairs(MISSING_BUFF_RULES) do
        local spellID = rule.spellIDs and rule.spellIDs[1]
        if tonumber(spellID) == hiddenSpellID and AuraHiddenEntryMatches({ auraType = "missing", name = rule.name, icon = rule.icon }, auraType, auraName, auraIcon) then
            return true
        end
    end
    return false
end

local function AuraDisplayIsVisible(db, spellID, auraData, auraType)
    if AuraSpellIsVisible(db, spellID) == false then
        DebugAuraSpellPrint(db, string.format("hide exact %s spellID=%s name=%s", tostring(auraType), tostring(spellID), tostring(ReadAuraName(auraData) or "")))
        return false
    end
    if not (db and type(db.auraSpellVisibility) == "table" and auraData) then return true end

    local auraName = NormalizeAuraName(ReadAuraName(auraData))
    local auraIcon = ReadAuraIcon(auraData)
    if IsSecretValue(auraIcon) then auraIcon = nil end
    if not auraName and not auraIcon then return true end

    for hiddenSpellID, visible in pairs(db.auraSpellVisibility) do
        if visible == false and AuraHiddenSpellMatches(db, hiddenSpellID, auraType, auraName, auraIcon) then
            DebugAuraSpellPrint(db, string.format("hide catalog %s hiddenSpellID=%s auraSpellID=%s name=%s icon=%s", tostring(auraType), tostring(hiddenSpellID), tostring(spellID), tostring(auraName), tostring(auraIcon)))
            return false
        end
    end
    DebugAuraSpellPrint(db, string.format("show %s spellID=%s name=%s icon=%s hiddenCount=%s", tostring(auraType), tostring(spellID), tostring(auraName), tostring(auraIcon), tostring(db.auraSpellVisibility and "table" or "none")))
    return true
end

local function ReadAuraInstanceID(auraData)
    if not auraData then return nil end
    local auraInstanceID = auraData.auraInstanceID
    if IsSecretValue(auraInstanceID) then return nil end
    return auraInstanceID
end

local AuraMatchesFilter

local function GetAuraStackText(unit, auraInstanceID, auraData)
    if unit and auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount then
        local ok, stackText = pcall(C_UnitAuras.GetAuraApplicationDisplayCount, unit, auraInstanceID, 2, 99)
        if ok and stackText then
            return stackText
        end
    end
    local ok, count = pcall(function()
        local applications = auraData and auraData.applications
        if applications and applications > 1 then
            return applications
        end
        return nil
    end)
    if ok and count then
        return count
    end
    return nil
end

local function GetAuraDurationObject(unit, auraInstanceID)
    if unit and auraInstanceID and C_UnitAuras and C_UnitAuras.GetAuraDuration then
        local ok, durationObject = pcall(C_UnitAuras.GetAuraDuration, unit, auraInstanceID)
        if ok and durationObject then return durationObject end
    end
    return nil
end

local function GetAuraDispelType(auraData)
    if not auraData then return nil end
    local dispelName = auraData.dispelName
    if not IsSecretValue(dispelName) and DISPEL_COLORS[dispelName] then
        return dispelName
    end
    local dispelType = auraData.dispelType
    if not IsSecretValue(dispelType) and type(dispelType) == "number" then
        return DISPEL_BY_ENUM[dispelType]
    end
    return nil
end

local function GetAuraDispelDisplayType(unit, auraInstanceID, auraData)
    local dispelType = GetAuraDispelType(auraData)
    if dispelType then return dispelType end
    return nil
end

function AuraMatchesFilter(unit, auraInstanceID, filter)
    if not (C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID and unit and auraInstanceID and filter) then
        return false
    end
    local ok, filteredOut = pcall(C_UnitAuras.IsAuraFilteredOutByInstanceID, unit, auraInstanceID, filter)
    if not ok or IsSecretValue(filteredOut) then
        return false
    end
    return filteredOut == false
end

local function GetAuraFilterMatches(unit, auraInstanceID)
    if not (C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID and unit and auraInstanceID) then
        return nil
    end
    local ok, matches = pcall(function()
        local out = {}
        for _, filter in ipairs(DEBUFF_FILTERS) do
            out[filter] = C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, filter) == false
        end
        out.dispellable = C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE") == false
        out.cc = C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, "HARMFUL|CROWD_CONTROL") == false
        return out
    end)
    if not ok then return nil end
    return matches
end

local function AuraIsFromPlayer(auraData)
    if not auraData then return false end
    local sourceUnit = auraData.sourceUnit
    if not sourceUnit or IsSecretValue(sourceUnit) then return false end
    if sourceUnit == "player" then return true end
    if UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, sourceUnit, "player")
        return ok and not IsSecretValue(same) and same == true
    end
    return false
end


Mod._auraDisplayPool = {}
Mod.GetPooledAuraDisplay = function()
    local t = table.remove(Mod._auraDisplayPool)
    if not t then return {} end
    wipe(t)
    return t
end
Mod.ReleaseAuraDisplay = function(t)
    if type(t) == "table" then
        Mod._auraDisplayPool[#Mod._auraDisplayPool + 1] = t
    end
end
local function BuildAuraDisplay(auraData, dispelType, unit)
    local auraInstanceID = ReadAuraInstanceID(auraData)
    return {
        icon = ReadAuraIcon(auraData),
        spellID = ReadAuraSpellID(auraData),
        auraInstanceID = auraInstanceID,
        dispelType = dispelType or GetAuraDispelType(auraData),
        stackText = GetAuraStackText(unit, auraInstanceID, auraData),
        durationObject = GetAuraDurationObject(unit, auraInstanceID),
        duration = not IsSecretValue(auraData and auraData.duration) and auraData.duration or 0,
        expirationTime = not IsSecretValue(auraData and auraData.expirationTime) and auraData.expirationTime or 0,
        isBossDebuff = not IsSecretValue(auraData and auraData.isBossDebuff) and auraData.isBossDebuff,
        isCastByPlayer = not IsSecretValue(auraData and auraData.isCastByPlayer) and auraData.isCastByPlayer,
    }
end

local function AddAuraIcon(result, listName, auraData, maxCount, dispelType, unit)
    local list = result[listName]
    if not list or #list >= maxCount then return end
    local display = BuildAuraDisplay(auraData, dispelType, unit)
    if display.icon then
        list[#list + 1] = display
    end
end

local function AddHelpfulAuraIconFiltered(result, unit, db, auraData, maxBuffs, seenBuffs)
    if not (result and unit and db and auraData and maxBuffs and maxBuffs > 0) then return end
    if #result.buffs >= maxBuffs then return end

    local spellID = ReadAuraSpellID(auraData)
    if not AuraDisplayIsVisible(db, spellID, auraData, "buff") then return end

    local auraInstanceID = ReadAuraInstanceID(auraData)
    local iconKey = ReadAuraIcon(auraData)
    if IsSecretValue(iconKey) then iconKey = nil end
    local key = auraInstanceID or spellID or iconKey
    if key and seenBuffs and seenBuffs[key] then return end

    local show = false
    if db.auraOnlyPlayerBuffs ~= false then
        show = AuraIsFromPlayer(auraData)
    else
        for _, filter in ipairs(BUFF_DISPLAY_FILTERS) do
            if AuraMatchesFilter(unit, auraInstanceID, filter) then
                show = true
                break
            end
        end
    end
    if not show then return end

    AddAuraIcon(result, "buffs", auraData, maxBuffs, nil, unit)
    if key and seenBuffs then
        seenBuffs[key] = true
    end
end

local function TrackDispel(result, dispelType, auraInstanceID, auraDisplay)
    if auraInstanceID and not result.dispelAuraInstanceID then
        result.dispelAuraInstanceID = auraInstanceID
    end
    if auraDisplay and auraDisplay.icon and not result.dispelAura then
        result.dispelAura = auraDisplay
    end
    if not dispelType then return end
    local current = result.dispelType
    if not current or (DISPEL_PRIORITY[dispelType] or 99) < (DISPEL_PRIORITY[current] or 99) then
        result.dispelType = dispelType
        result.dispelAuraInstanceID = auraInstanceID or result.dispelAuraInstanceID
        if auraDisplay and auraDisplay.icon then
            result.dispelAura = auraDisplay
        end
    end
end

local function RuleIsPresent(rule, presentSpellIDs)
    if not (rule and presentSpellIDs) then return true end
    for _, spellID in ipairs(rule.spellIDs or {}) do
        if presentSpellIDs[spellID] then
            return true
        end
    end
    return false
end

local function UnitHasBuffBySpellID(unit, spellID)
    if not spellID then return false end
    local isPlayerUnit = unit == "player"
    if not isPlayerUnit and UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, unit, "player")
        isPlayerUnit = ok and not IsSecretValue(same) and same == true
    end
    local api = isPlayerUnit and GetPlayerAuraBySpellID or GetUnitAuraBySpellID
    if not api then return false end
    local ok, aura
    if api == GetPlayerAuraBySpellID then
        ok, aura = pcall(api, spellID)
    else
        ok, aura = pcall(api, unit, spellID)
    end
    return ok and aura ~= nil
end

local function UnitHasMissingBuffRule(unit, rule)
    if not (unit and rule) then return false end
    for _, spellID in ipairs(rule.spellIDs or {}) do
        if UnitHasBuffBySpellID(unit, spellID) then
            return true
        end
    end

    if rule.name and AuraUtil and AuraUtil.FindAuraByName then
        local ok, auraData = pcall(AuraUtil.FindAuraByName, rule.name, unit, "HELPFUL")
        if ok and auraData then
            return true
        end
    end

    if AuraUtil and AuraUtil.ForEachAura then
        local found = false
        pcall(AuraUtil.ForEachAura, unit, "HELPFUL", nil, function(auraData)
            local spellID = ReadAuraSpellID(auraData)
            if spellID then
                for _, trackedID in ipairs(rule.spellIDs or {}) do
                    if spellID == trackedID then
                        found = true
                        return true
                    end
                end
            end
        end, true)
        if found then return true end
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        for i = 1, 40 do
            local ok, auraData = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HELPFUL")
            if not ok or not auraData then break end
            local spellID = ReadAuraSpellID(auraData)
            if spellID then
                for _, trackedID in ipairs(rule.spellIDs or {}) do
                    if spellID == trackedID then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function GetPlayerMissingBuffRule(db)
    if not (db and db.showMissingBuffs ~= false) then return nil end
    local rule
    if UnitClass then
        local _, classToken = UnitClass("player")
        if not IsSecretValue(classToken) then
            rule = classToken and MISSING_BUFF_RULES[classToken]
        end
    end
    if not rule or db[rule.key] == false then return nil end
    return rule
end

function Mod:GetDirectMissingBuffDisplay(unit, db)
    local rule = GetPlayerMissingBuffRule(db)
    if not (unit and rule and GetUnitAuraBySpellID) then
        return nil
    end

    -- Long-term class buffs are non-secret spell IDs in 12.1. Query only the
    -- known IDs directly; never fall back to enumerating protected aura lists.
    for _, spellID in ipairs(rule.spellIDs or {}) do
        if UnitHasBuffBySpellID(unit, spellID) then
            return nil
        end
    end

    local isDead = SafeUnitBoolean(UnitIsDeadOrGhost, unit)
    local isConnected = SafeUnitBoolean(UnitIsConnected, unit)
    local spellID = rule.spellIDs and rule.spellIDs[1]
    if isDead or isConnected == false or not AuraSpellIsVisible(db, spellID) then
        return nil
    end

    RegisterAuraCatalogEntry(db, spellID, 'missing', rule.name, rule.icon)
    return {
        icon = rule.icon,
        spellID = spellID,
        name = rule.name,
    }
end

local function ScanUnitAuraState(unit, db)
    -- Reuse previous result table if exists
    local result = Mod.auraCache[unit] or { buffs = {}, debuffs = {} }
    for _, aura in ipairs(result.buffs) do Mod.ReleaseAuraDisplay(aura) end
    for _, aura in ipairs(result.debuffs) do Mod.ReleaseAuraDisplay(aura) end
    if result.cc then Mod.ReleaseAuraDisplay(result.cc) end
    if result.missingBuff then Mod.ReleaseAuraDisplay(result.missingBuff) end
    if result.dispelAura then Mod.ReleaseAuraDisplay(result.dispelAura) end
    wipe(result.buffs)
    wipe(result.debuffs)
    result.cc = nil
    result.missingBuff = nil
    result.dispelType = nil
    result.dispelAuraInstanceID = nil
    result.dispelAura = nil
    local arenaDRScanID = Mod:BeginArenaDRScan(unit)
    if not (db and C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot and IsUnitUsable(unit)) then
        Mod:EndArenaDRScan(unit, arenaDRScanID)
        return result
    end

    local maxBuffs = math.max(0, math.min(5, tonumber(db.auraMaxBuffs) or 3))
    local maxDebuffs = math.max(0, math.min(5, tonumber(db.auraMaxDebuffs) or 3))
    local missingRule = GetPlayerMissingBuffRule(db)
    local presentHelpful = missingRule and {} or nil

    if db.showBuffs ~= false or missingRule then
        local ok, helpfulData = pcall(function()
            local slots = { C_UnitAuras.GetAuraSlots(unit, "HELPFUL") }
            local data = {}
            for i = 2, #slots do
                local auraData = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
                if auraData then
                    data[#data + 1] = auraData
                end
            end
            return data
        end)
        if ok and Mod:CanIterateTable(helpfulData) then
            for i = 1, #helpfulData do
                local auraData = helpfulData[i]
                local spellID = ReadAuraSpellID(auraData)
                local buffFromPlayer = AuraIsFromPlayer(auraData)
                if spellID and presentHelpful then
                    presentHelpful[spellID] = true
                end
                if db.auraOnlyPlayerBuffs == false or buffFromPlayer then
                    RegisterAuraCatalogEntry(db, spellID, "buff", ReadAuraName(auraData), ReadAuraIcon(auraData))
                end
            end
        end
    end

    if db.showBuffs ~= false and maxBuffs > 0 then
        local seenBuffs = {}
        for _, filter in ipairs(db.auraOnlyPlayerBuffs == false and BUFF_DISPLAY_FILTERS or { "HELPFUL|PLAYER" }) do
            local ok, helpfulData = pcall(function()
                local slots = { C_UnitAuras.GetAuraSlots(unit, filter) }
                local data = {}
                for i = 2, #slots do
                    local auraData = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
                    if auraData then
                        data[#data + 1] = auraData
                    end
                end
                return data
            end)
            if ok and Mod:CanIterateTable(helpfulData) then
                for i = 1, #helpfulData do
                    AddHelpfulAuraIconFiltered(result, unit, db, helpfulData[i], maxBuffs, seenBuffs)
                    if #result.buffs >= maxBuffs then break end
                end
            end
            if #result.buffs >= maxBuffs then break end
        end
    end

    if db.showDebuffs ~= false or db.showDispelOverlay ~= false or db.showCrowdControl ~= false
        or (arenaDRScanID and db.showArenaDR ~= false) then
        local harmfulSeen = 0
        local function ProcessHarmfulAura(auraData)
            if not auraData then return end
            harmfulSeen = harmfulSeen + 1
            local spellID = ReadAuraSpellID(auraData)
            local auraInstanceID = ReadAuraInstanceID(auraData)
            Mod:ObserveArenaDRAura(unit, spellID, auraInstanceID, arenaDRScanID)
            local matches = GetAuraFilterMatches(unit, auraInstanceID)
            local dispelType = GetAuraDispelDisplayType(unit, auraInstanceID, auraData)
            local hasDispelOverlayAura = dispelType or (auraData.dispelName ~= nil)
                or (matches and matches.dispellable)
                or (auraData and auraData.isBossDebuff)
            local spellVisible = AuraDisplayIsVisible(db, spellID, auraData, "debuff")
            local auraDisplay = nil
            RegisterAuraCatalogEntry(db, spellID, "debuff", ReadAuraName(auraData), ReadAuraIcon(auraData))
            if db.showDispelOverlay ~= false and hasDispelOverlayAura then
                auraDisplay = BuildAuraDisplay(auraData, dispelType, unit)
                TrackDispel(result, dispelType, auraInstanceID, spellVisible and auraDisplay or nil)
            end
            local passesFilter = false
            if matches then
                for _, filter in ipairs(DEBUFF_FILTERS) do
                    if matches[filter] then
                        passesFilter = true
                        break
                    end
                end
            end
            local isCC = (matches and matches.cc) or Mod:GetArenaDRCategory(spellID) ~= nil
            if spellVisible and isCC and db.showCrowdControl ~= false and not result.cc then
                result.cc = auraDisplay or BuildAuraDisplay(auraData, dispelType, unit)
            end
            if spellVisible and db.showDebuffs ~= false and maxDebuffs > 0 and (db.auraShowAllDebuffs == true or dispelType or passesFilter) then
                if auraDisplay and auraDisplay.icon and #result.debuffs < maxDebuffs then
                    result.debuffs[#result.debuffs + 1] = auraDisplay
                else
                    AddAuraIcon(result, "debuffs", auraData, maxDebuffs, dispelType, unit)
                end
            end
        end

        local ok, harmfulData = pcall(function()
            local slots = { C_UnitAuras.GetAuraSlots(unit, "HARMFUL") }
            local data = {}
            for i = 2, #slots do
                local auraData = C_UnitAuras.GetAuraDataBySlot(unit, slots[i])
                if auraData then
                    data[#data + 1] = auraData
                end
            end
            return data
        end)
        if ok and Mod:CanIterateTable(harmfulData) then
            for i = 1, #harmfulData do
                ProcessHarmfulAura(harmfulData[i])
            end
        end
        if harmfulSeen == 0 and C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            for i = 1, 40 do
                local okIndex, auraData = pcall(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
                if not okIndex or not auraData then break end
                ProcessHarmfulAura(auraData)
            end
        end
    end

    if missingRule and not RuleIsPresent(missingRule, presentHelpful) and not UnitHasMissingBuffRule(unit, missingRule) then
        local isDead = SafeUnitBoolean(UnitIsDeadOrGhost, unit)
        local isConnected = SafeUnitBoolean(UnitIsConnected, unit)
        local spellID = (missingRule.spellIDs and missingRule.spellIDs[1]) or nil
        RegisterAuraCatalogEntry(db, spellID, "missing", missingRule.name, missingRule.icon)
        if not isDead and isConnected ~= false and AuraSpellIsVisible(db, spellID) then
            result.missingBuff = {
                icon = missingRule.icon,
                spellID = spellID,
                name = missingRule.name,
            }
        end
    end

    Mod:EndArenaDRScan(unit, arenaDRScanID)
    return result
end

local function GetTestAuraState(fakeUnit, mode, db, seed)
    local index = fakeUnit and fakeUnit.index or 1
    local result = { buffs = {}, debuffs = {}, cc = nil, missingBuff = nil, dispelType = nil, dispelAuraInstanceID = nil }
    local noDispelOverlay = ns.PF_TestNoDispelOverlay
    if not db or db.showAuras == false then return result end

    local maxBuffs = math.max(0, math.min(5, tonumber(db.auraMaxBuffs) or 3))
    local maxDebuffs = math.max(0, math.min(5, tonumber(db.auraMaxDebuffs) or 3))
    if db.showBuffs ~= false and maxBuffs > 0 then
        local buffIcons = {
            { icon = 136078, spellID = 1126 },
            { icon = 135932, spellID = 1459 },
            { icon = 132333, spellID = 6673 },
            { icon = 4622448, spellID = 381748 },
            { icon = 4630367, spellID = 462854 },
        }
        local wanted = math.min(maxBuffs, 2 + (index % 2))
        for i = 1, #buffIcons do
            local sample = buffIcons[((index + i - 2) % #buffIcons) + 1]
            if AuraSpellIsVisible(db, sample.spellID) then
                result.buffs[#result.buffs + 1] = sample
                if #result.buffs >= wanted then break end
            end
        end
    end
    if db.showDebuffs ~= false and maxDebuffs > 0 then
        local seedOffset = tonumber(seed) or 0
        for i = 1, #TEST_AURA_DEBUFFS do
            local sample = TEST_AURA_DEBUFFS[(((index * 7) + (i * 11) + seedOffset) % #TEST_AURA_DEBUFFS) + 1]
            if db.showDispelOverlay ~= false and not (noDispelOverlay and noDispelOverlay[index]) then
                TrackDispel(result, sample.dispelType, sample.spellID)
            end
            if AuraSpellIsVisible(db, sample.spellID) then
                result.debuffs[#result.debuffs + 1] = sample
                if #result.debuffs >= maxDebuffs then break end
            end
        end
    end
    if db.showCrowdControl ~= false and index % 4 == 0 and AuraSpellIsVisible(db, 118) then
        result.cc = { icon = 136071, spellID = 118, dispelType = "Magic" }
        if not (noDispelOverlay and noDispelOverlay[index]) then
            TrackDispel(result, "Magic")
        end
    end
    local missingRule = GetPlayerMissingBuffRule(db)
    local missingSpellID = missingRule and missingRule.spellIDs and missingRule.spellIDs[1]
    if missingRule and index % 5 == 2 and AuraSpellIsVisible(db, missingSpellID) then
        result.missingBuff = { icon = missingRule.icon, spellID = missingSpellID, name = missingRule.name }
    end
    return result
end

local function LayoutAuraIconSet(icons, anchorFrame, point, relativePoint, x, y, size, spacing, direction)
    for i, icon in ipairs(icons or {}) do
        icon:ClearAllPoints()
        icon:SetSize(size, size)
        if icon.count then
            icon.count:SetFont(ResolveFontPath(), math.max(10, math.min(14, math.floor(size * 0.55 + 0.5))), "OUTLINE")
        end
        if icon.duration then
            icon.duration:SetFont(ResolveFontPath(), math.max(8, math.min(11, math.floor(size * 0.42 + 0.5))), "OUTLINE")
        end
        if i == 1 then
            icon:SetPoint(point, anchorFrame, relativePoint or point, x or 0, y or 0)
        elseif direction == "LEFT" then
            icon:SetPoint("RIGHT", icons[i - 1], "LEFT", -spacing, 0)
        else
            icon:SetPoint("LEFT", icons[i - 1], "RIGHT", spacing, 0)
        end
    end
end

local function LayoutFrameAuras(frame, db, mode)
    if not (frame and db) then return end
    local size = math.max(10, math.min(28, tonumber(db.auraIconSize) or 18))
    local spacing = math.max(0, math.min(8, tonumber(db.auraIconSpacing) or 0))
    local missingSize = math.max(14, math.min(44, tonumber(db.missingBuffIconSize) or 30))
    local isRaidMode = IsRaidMode(mode or frame.mode)
    local auraX = tonumber(db.auraIconOffsetX) or 0
    local auraY = tonumber(db.auraIconOffsetY) or 0
    local missingX = tonumber(db.missingBuffOffsetX) or 0
    local missingY = tonumber(db.missingBuffOffsetY) or 0

    frame.ccIcon:ClearAllPoints()
    frame.ccIcon:SetSize(isRaidMode and math.max(size, 16) or math.max(size + 2, 18), isRaidMode and math.max(size, 16) or math.max(size + 2, 18))
    frame.ccIcon:SetPoint("CENTER", frame.health, "CENTER", auraX, auraY)

    if frame.trinketIcon then
        local trinketSize = math.max(28, math.min(52, tonumber(db.arenaTrinketIconSize) or 40))
        local drSize = math.max(20, math.min(40, tonumber(db.arenaDRIconSize) or 32))
        local trinketSide = db.arenaTrinketSide or "RIGHT"
        local drSide = db.arenaDRSide or "LEFT"
        
        frame.trinketIcon:ClearAllPoints()
        frame.trinketIcon:SetSize(trinketSize, trinketSize)
        
        if trinketSide == "LEFT" then
            frame.trinketIcon:SetPoint('RIGHT', frame, 'LEFT', -5, 0)
        else
            frame.trinketIcon:SetPoint('LEFT', frame, 'RIGHT', 5, 0)
        end

        for i = 1, 4 do
            local icon = frame.drIcons and frame.drIcons[i]
            if icon then
                icon:ClearAllPoints()
                icon:SetSize(drSize, drSize)
                if i == 1 then
                    if drSide == "LEFT" then
                        if trinketSide == "LEFT" then
                            icon:SetPoint('RIGHT', frame.trinketIcon, 'LEFT', -3, 0)
                        else
                            icon:SetPoint('RIGHT', frame, 'LEFT', -5, 0)
                        end
                    else
                        if trinketSide == "RIGHT" then
                            icon:SetPoint('LEFT', frame.trinketIcon, 'RIGHT', 3, 0)
                        else
                            icon:SetPoint('LEFT', frame, 'RIGHT', 5, 0)
                        end
                    end
                else
                    if drSide == "LEFT" then
                        icon:SetPoint('RIGHT', frame.drIcons[i - 1], 'LEFT', -2, 0)
                    else
                        icon:SetPoint('LEFT', frame.drIcons[i - 1], 'RIGHT', 2, 0)
                    end
                end
            end
        end
    end

    frame.missingBuffIcon:ClearAllPoints()
    if isRaidMode then
        frame.missingBuffIcon:SetSize(missingSize, missingSize)
        frame.missingBuffIcon:SetPoint("CENTER", frame.health, "CENTER", missingX, missingY)
    else
        local partyMissingSize = math.min(missingSize, 29)
        frame.missingBuffIcon:SetSize(partyMissingSize, partyMissingSize)
        frame.missingBuffIcon:SetPoint("CENTER", frame.health, "CENTER", missingX, missingY)
    end
end

local function LayoutCenteredAuraIcons(frame, db, buffCount, debuffCount)
    if not (frame and frame.health and db) then return end
    local size = math.max(10, math.min(28, tonumber(db.auraIconSize) or 18))
    local spacing = math.max(0, math.min(8, tonumber(db.auraIconSpacing) or 0))
    local isRaidMode = IsRaidMode(frame.mode)
    local buffSize = size
    local debuffSize = math.max(size, isRaidMode and 22 or 24)
    local buffX = tonumber(db.buffIconsOffsetX) or 0
    local buffY = tonumber(db.buffIconsOffsetY) or 0
    local debuffX = tonumber(db.debuffIconsOffsetX) or 0
    local debuffY = tonumber(db.debuffIconsOffsetY) or 0
    buffCount = math.max(0, math.min(5, tonumber(buffCount) or 0))
    debuffCount = math.max(0, math.min(5, tonumber(debuffCount) or 0))
    local stepB = buffSize + spacing
    local stepD = debuffSize + spacing
    local gap = (buffCount > 0 and debuffCount > 0) and spacing or 0
    local totalW = math.max(0, (buffCount - 1) * stepB) + math.max(0, (debuffCount - 1) * stepD)
        + (buffCount > 0 and buffSize or 0) + (debuffCount > 0 and debuffSize or 0) + gap
    local half = totalW / 2
    LayoutAuraIconSet(frame.debuffIcons, frame.health, "CENTER", "CENTER", -half + debuffSize / 2 + debuffX, debuffY, debuffSize, spacing, "RIGHT")
    LayoutAuraIconSet(frame.buffIcons, frame.health, "CENTER", "CENTER", half - math.max(0, (buffCount - 1) * stepB) - buffSize / 2 + buffX, buffY, buffSize, spacing, "LEFT")
end

local function RenderAuraIcon(icon, aura, tintFallback)
    if not icon then return end
    if not (aura and aura.icon) then
        HideAuraIcon(icon)
        return
    end
    if not SetAuraTextureSafe(icon.icon, aura.icon) then
        HideAuraIcon(icon)
        return
    end
    icon._ktAuraCleared = nil
    SetAuraCooldownSafe(icon.cooldown, aura)
    SetAuraDurationTextState(icon, aura)
    if icon.count then
        icon.count:SetText("")
        if aura.stackText then
            pcall(icon.count.SetText, icon.count, aura.stackText)
        end
    end
    local tint = aura.dispelType and DISPEL_COLORS[aura.dispelType] or tintFallback
    local r, g, b = 0, 0, 0
    if tint then
        r, g, b = tint.r or tint[1] or 0, tint.g or tint[2] or 0, tint.b or tint[3] or 0
    end
    SetAuraIconBorderColor(icon, r, g, b, 1.0)
    icon:Show()
end

function Mod:GetArenaDRCategory(spellID)
    if not spellID or IsSecretValue(spellID) then return nil end
    local data = self.ArenaDRData
    local category = data and data.spells and data.spells[tonumber(spellID)]
    if type(category) == 'table' then
        return category[1], category
    end
    return category, nil
end

function Mod:BeginArenaDRScan(unit)
    if type(unit) ~= 'string' or IsSecretValue(unit) or not unit:match('^arena%d+$') then return nil end
    self._arenaDRScanSerial = (self._arenaDRScanSerial or 0) + 1
    self.arenaDRScan = self.arenaDRScan or {}
    self.arenaDRScan[unit] = self._arenaDRScanSerial
    return self._arenaDRScanSerial
end

function Mod:ObserveArenaDRCategory(unit, category, spellID, auraInstanceID, scanID)
    local data = self.ArenaDRData
    local categoryInfo = data and data.categories and data.categories[category]
    if not categoryInfo or category == 'taunt' then return end
    self.arenaDRState = self.arenaDRState or {}
    local unitState = self.arenaDRState[unit]
    if not unitState then
        unitState = {}
        self.arenaDRState[unit] = unitState
    end
    local state = unitState[category]
    if not state then
        state = { activeKeys = {} }
        unitState[category] = state
    end

    -- Never use an AuraInstanceID as a Lua table key in PvP. Blizzard may
    -- protect it after combat begins, making the table forbidden to iterate.
    -- DR only needs one active marker per spell/category.
    local auraKey = 'spell:' .. tostring(spellID)
    state.activeKeys = state.activeKeys or {}
    local now = GetTime()
    if state.activeKeys[auraKey] == nil then
        if not state.level or (not state.activeKey and (not state.expirationTime or now >= state.expirationTime)) then
            state.level = categoryInfo.immediateImmune and 2 or 1
        else
            state.level = math.min(2, state.level + 1)
        end
        state.expirationTime = nil
        state.startTime = nil
        state.spellID = spellID
        state.icon = GetSpellIconSafe(spellID, categoryInfo.icon)
    end
    state.activeKeys[auraKey] = scanID
    state.activeKey = true
    state.seenScan = scanID
end

function Mod:ObserveArenaDRAura(unit, spellID, auraInstanceID, scanID)
    local category, shared = self:GetArenaDRCategory(spellID)
    if not category then return end
    self:ObserveArenaDRCategory(unit, category, spellID, auraInstanceID, scanID)
    if type(shared) == 'table' then
        for i = 1, #shared do
            if shared[i] ~= category then
                self:ObserveArenaDRCategory(unit, shared[i], spellID, auraInstanceID, scanID)
            end
        end
    end
end

function Mod:EndArenaDRScan(unit, scanID)
    if not scanID then return end
    local unitState = self.arenaDRState and self.arenaDRState[unit]
    local order = self.ArenaDRData and self.ArenaDRData.categoryOrder
    if not (unitState and order) then return end
    local now = GetTime()
    for i = 1, #order do
        local category = order[i]
        local state = unitState[category]
        if state then
            local wasActive = state.activeKey == true
            local activeCount = 0
            for auraKey, seenScan in pairs(state.activeKeys or {}) do
                if seenScan ~= scanID then
                    state.activeKeys[auraKey] = nil
                else
                    activeCount = activeCount + 1
                end
            end
            state.activeKey = activeCount > 0 and true or nil
            if wasActive and activeCount == 0 then
                local categoryInfo = self.ArenaDRData.categories and self.ArenaDRData.categories[category]
                local resetTime = tonumber(categoryInfo and categoryInfo.resetTime) or tonumber(self.ArenaDRData.resetTime) or 16.5
                state.activeKey = nil
                state.startTime = now
                state.expirationTime = now + resetTime
            elseif not state.activeKey and state.expirationTime and now >= state.expirationTime then
                unitState[category] = nil
            end
        end
    end
end

function Mod:UpdateArenaDR(frame)
    if not frame or not frame.drIcons then return end
    local db = self:GetModeDB(frame.mode or 'party')
    if frame.mode ~= 'arenaEnemy' or not db or db.showArenaDR == false then
        HideAuraIconSet(frame.drIcons)
        return
    end

    local data = self.ArenaDRData
    local order = data and data.categoryOrder
    if not order then
        HideAuraIconSet(frame.drIcons)
        return
    end

    if frame.fakeUnit then
        local icon = frame.drIcons[1]
        local info = data.categories and data.categories.stun
        if icon and info then
            icon.icon:SetTexture(info.icon)
            icon.cooldown:Hide()
            icon.duration:Hide()
            icon.drLevel:SetText('1/2')
            SetAuraIconBorderColor(icon, info.color[1], info.color[2], info.color[3], 1)
            icon:ClearAllPoints()
            icon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
            icon:Show()
        end
        for i = 2, #frame.drIcons do HideAuraIcon(frame.drIcons[i]) end
        return
    end

    local unitState = self.arenaDRState and self.arenaDRState[frame.unit]
    local now = GetTime()
    local shown = 0
    if unitState then
        for i = 1, #order do
            local category = order[i]
            local state = unitState[category]
            if state and state.activeKey then
                shown = shown + 1
                local icon = frame.drIcons[shown]
                local info = data.categories[category]
                if not icon or not info then break end
                icon.icon:SetTexture(state.icon or info.icon)
                if Mod._durationIcons then
                    Mod._durationIcons[icon] = nil
                end
                icon._auraExpirationTime = nil
                icon.cooldown:Hide()
                icon.duration:Hide()
                icon.drLevel:SetText((state.level or 1) >= 2 and 'IMM' or '1/2')
                SetAuraIconBorderColor(icon, info.color[1], info.color[2], info.color[3], 1)
                icon:ClearAllPoints()
                if shown == 1 then
                    icon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
                else
                    icon:SetPoint("RIGHT", frame.drIcons[shown-1], "LEFT", -2, 0)
                end
                icon:Show()
                if shown >= #frame.drIcons then break end
            elseif state and state.expirationTime and state.expirationTime > now then
                shown = shown + 1
                local icon = frame.drIcons[shown]
                local info = data.categories[category]
                if not icon or not info then break end
                icon.icon:SetTexture(state.icon or info.icon)
                icon._auraExpirationTime = state.expirationTime
                icon._updateDurationText = UpdateAuraDurationText
                Mod._durationIcons = Mod._durationIcons or {}
                Mod._durationIcons[icon] = true
                Mod:ArmAuraDurationDriver()
                UpdateAuraDurationText(icon)
                local resetTime = tonumber(info.resetTime) or tonumber(data.resetTime) or 16.5
                icon.cooldown:SetCooldown(state.startTime or (state.expirationTime - resetTime), resetTime)
                icon.cooldown:Show()
                icon.drLevel:SetText((state.level or 1) >= 2 and 'IMM' or '1/2')
                SetAuraIconBorderColor(icon, info.color[1], info.color[2], info.color[3], 1)
                icon:ClearAllPoints()
                if shown == 1 then
                    icon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
                else
                    icon:SetPoint("RIGHT", frame.drIcons[shown-1], "LEFT", -2, 0)
                end
                icon:Show()
                if shown >= #frame.drIcons then break end
            elseif state and not state.activeKey and state.expirationTime and state.expirationTime <= now then
                unitState[category] = nil
            end
        end
    end
    for i = shown + 1, #frame.drIcons do HideAuraIcon(frame.drIcons[i]) end
end

function Mod:UpdateArenaTrinket(frame)
    if not frame or not frame.trinketIcon then return end
    local db = self:GetModeDB(frame.mode or 'party')
    if (frame.mode ~= 'arenaEnemy' and frame.mode ~= 'arena') or not db or db.showArenaTrinket == false then
        HideAuraIcon(frame.trinketIcon)
        return
    end

    local icon = self.arenaTrinketIcons and self.arenaTrinketIcons[frame.unit]
    if frame.fakeUnit then
        icon = 'Interface\\Icons\\INV_Jewelry_TrinketPVP_02'
    end
    if not icon then
        HideAuraIcon(frame.trinketIcon)
        return
    end
    frame.trinketIcon.icon:SetTexture(icon)
    frame.trinketIcon.duration:Hide()
    frame.trinketIcon.count:SetText('')
    frame.trinketIcon.cooldown:Hide()
    SetAuraIconBorderColor(frame.trinketIcon, 0, 0, 0, 1)

    if not frame.fakeUnit and frame.unit and _G.C_PvP then
        local durationObject
        if _G.C_PvP.GetArenaCrowdControlDuration then
            local ok, value = pcall(_G.C_PvP.GetArenaCrowdControlDuration, frame.unit)
            if ok then durationObject = value end
        end
        if durationObject and frame.trinketIcon.cooldown.SetCooldownFromDurationObject then
            local ok = pcall(frame.trinketIcon.cooldown.SetCooldownFromDurationObject, frame.trinketIcon.cooldown, durationObject)
            if ok then frame.trinketIcon.cooldown:Show() end
        elseif _G.C_PvP.GetArenaCrowdControlInfo then
            local ok, spellID, itemID, startTime, duration = pcall(_G.C_PvP.GetArenaCrowdControlInfo, frame.unit)
            if ok then
                if itemID and not IsSecretValue(itemID) and _G.C_Item and _G.C_Item.GetItemIconByID then
                    local iconOK, itemIcon = pcall(_G.C_Item.GetItemIconByID, itemID)
                    if iconOK and itemIcon and not IsSecretValue(itemIcon) then
                        frame.trinketIcon.icon:SetTexture(itemIcon)
                    end
                elseif spellID and not IsSecretValue(spellID) then
                    frame.trinketIcon.icon:SetTexture(GetSpellIconSafe(spellID, icon))
                end
                if not IsSecretValue(startTime) and not IsSecretValue(duration)
                    and type(startTime) == 'number' and type(duration) == 'number' and duration > 0 then
                    if duration > 1000 then
                        startTime, duration = startTime / 1000, duration / 1000
                    end
                    frame.trinketIcon.cooldown:SetCooldown(startTime, duration)
                    frame.trinketIcon.cooldown:Show()
                    SetAuraIconBorderColor(frame.trinketIcon, 0, 0, 0, 1)
                end
            end
        end
    end
    frame.trinketIcon:Show()
end

function Mod:UpdateArenaTrackers(frame)
    if not frame then return end
    self:UpdateArenaTrinket(frame)
    self:UpdateArenaDR(frame)
end

function Mod:ResetArenaTrackers()
    self.arenaDRState = {}
    self.arenaDRScan = {}
    self.arenaTrinketIcons = {}
    for i = 1, 5 do
        local frame = self.frames and self.frames.arenaEnemy and self.frames.arenaEnemy[i]
        if frame then
            HideAuraIcon(frame.trinketIcon)
            HideAuraIconSet(frame.drIcons)
        end
    end
end

function Mod:OnArenaCooldownUpdate(_, unit)
    if unit and (IsSecretValue(unit) or type(unit) ~= 'string' or not unit:match('^arena%d+$')) then
        unit = nil
    end
    for i = 1, 5 do
        local frame = self.frames and self.frames.arenaEnemy and self.frames.arenaEnemy[i]
        if frame and (not unit or frame.unit == unit) then
            self:UpdateArenaTrinket(frame)
        end
    end
end

function Mod:OnArenaCrowdControlSpellUpdate(_, unit, spellID, itemID)
    if IsSecretValue(unit) or type(unit) ~= 'string' or not unit:match('^arena%d+$') then return end
    local icon
    if itemID and not IsSecretValue(itemID) and _G.C_Item and _G.C_Item.GetItemIconByID then
        local ok, value = pcall(_G.C_Item.GetItemIconByID, itemID)
        if ok and value and not IsSecretValue(value) then icon = value end
    end
    if not icon and spellID and not IsSecretValue(spellID) then
        icon = GetSpellIconSafe(spellID)
    end
    if icon then
        self.arenaTrinketIcons = self.arenaTrinketIcons or {}
        self.arenaTrinketIcons[unit] = icon
    end
    self:OnArenaCooldownUpdate(nil, unit)
end

function Mod:ClearFrameAuras(frame)
    if not frame then return end
    HideAuraIconSet(frame.buffIcons)
    HideAuraIconSet(frame.debuffIcons)
    HideAuraIcon(frame.ccIcon)
    HideAuraIcon(frame.missingBuffIcon)
    HideAuraIcon(frame.trinketIcon)
    HideAuraIconSet(frame.drIcons)
    if ns.PF_UnbindAuraContainers then ns.PF_UnbindAuraContainers(frame) end
    if frame.ktAuraContainers then
        frame.ktAuraContainers.buffs:Hide()
        frame.ktAuraContainers.debuffs:Hide()
        frame.ktAuraContainers.cc:Hide()
    end
    if frame.dispelOverlay then frame.dispelOverlay:Hide() end
    SetDispelFrameBorder(frame, nil)
end

function Mod:GetAuraState(frame, db)
    if not frame then return nil end
    if frame.fakeUnit then
        local mode = frame.mode or "party"
        local seed = self.testAuraSeeds and self.testAuraSeeds[mode] or 0
        return GetTestAuraState(frame.fakeUnit, mode, db, seed)
    end
    if not frame.unit then return nil end
    self.auraCache = self.auraCache or {}
    local cacheMode = frame.mode or "party"
    local cached = self.auraCache[frame.unit]
    -- FIX: Removed frame._ktOutOfRange early return so auras update out of range!
    if cached and cached._ktAuraMode == cacheMode then
        return cached
    end
    local state = ScanUnitAuraState(frame.unit, db)
    state._ktAuraMode = cacheMode
    self.auraCache[frame.unit] = state
    return state
end

function Mod:UpdateFrameAuras(frame)
    if not frame then return end
    
    local db = self:GetModeDB(frame.mode or "party")
    if db and frame.ktAuraContainers then
        if frame._ktOutOfRange then
            if ns.PF_UnbindAuraContainers then ns.PF_UnbindAuraContainers(frame) end
        end

        -- AuraKit/Blizzard owns the live buff, debuff and CC buttons here. The
        -- old Lua icon pools must not be cleared on every UNIT_AURA. Keep the
        -- native container intact and only update its custom extras.
        local missingBuff = db.showAuras ~= false
            and frame.mode ~= "arenaEnemy"
            and frame._ktOutOfRange ~= true
            and self:GetDirectMissingBuffDisplay(frame.unit, db)
            or nil
        RenderAuraIcon(frame.missingBuffIcon, missingBuff, { r = 1, g = 0.08, b = 0.08 })
        if frame.dispelOverlay then frame.dispelOverlay:Hide() end
        SetDispelFrameBorder(frame, nil)
        if frame.mode == "arena" or frame.mode == "arenaEnemy" then
            self:UpdateArenaTrackers(frame)
        end
        return
    end
    if db then
        local showsBuffs = db.showAuras ~= false and db.showBuffs ~= false
        local showsDebuffs = db.showAuras ~= false and db.showDebuffs ~= false
        local showsCC = db.showAuras ~= false and db.showCrowdControl ~= false
        local showsMissing = db.showAuras ~= false and db.showMissingBuffs ~= false and frame.mode ~= "arenaEnemy"
        local showsDispel = db.showDispelOverlay ~= false
        local arenaMode = frame.mode == "arena" or frame.mode == "arenaEnemy"
        local tracksArena = arenaMode and (db.showArenaDR ~= false or db.showArenaTrinket ~= false)
        if not (showsBuffs or showsDebuffs or showsCC or showsMissing or showsDispel or tracksArena) then
            self:ClearFrameAuras(frame)
            self:UpdateArenaTrackers(frame)
            return
        end
        local c1 = db.dispelColorMagic or {r=0.2, g=0.6, b=1.0}
        local c2 = db.dispelColorCurse or {r=0.6, g=0.0, b=1.0}
        local c3 = db.dispelColorDisease or {r=0.6, g=0.4, b=0.0}
        local c4 = db.dispelColorPoison or {r=0.0, g=0.6, b=0.0}
        local c9 = db.dispelColorEnrage or {r=1.0, g=0.0, b=0.0}
        local c11 = db.dispelColorBleed or {r=0.8, g=0.0, b=0.0}
        
        -- Update the local DISPEL_COLORS table used throughout the file
        DISPEL_COLORS["Magic"] = c1
        DISPEL_COLORS["Curse"] = c2
        DISPEL_COLORS["Disease"] = c3
        DISPEL_COLORS["Poison"] = c4
        DISPEL_COLORS["Enrage"] = c9
        DISPEL_COLORS["Bleed"] = c11
        
        local rebuildCurve = false
        if not self._lastDispelColors then
            rebuildCurve = true
        else
            local l = self._lastDispelColors
            if l[1].r ~= c1.r or l[1].g ~= c1.g or l[1].b ~= c1.b or
               l[2].r ~= c2.r or l[2].g ~= c2.g or l[2].b ~= c2.b or
               l[3].r ~= c3.r or l[3].g ~= c3.g or l[3].b ~= c3.b or
               l[4].r ~= c4.r or l[4].g ~= c4.g or l[4].b ~= c4.b or
               l[9].r ~= c9.r or l[9].g ~= c9.g or l[9].b ~= c9.b or
               l[11].r ~= c11.r or l[11].g ~= c11.g or l[11].b ~= c11.b then
               rebuildCurve = true
            end
        end

        if rebuildCurve then
            self.DF_DispelCurve = nil
            self._lastDispelColors = {
                [1] = {r=c1.r, g=c1.g, b=c1.b},
                [2] = {r=c2.r, g=c2.g, b=c2.b},
                [3] = {r=c3.r, g=c3.g, b=c3.b},
                [4] = {r=c4.r, g=c4.g, b=c4.b},
                [9] = {r=c9.r, g=c9.g, b=c9.b},
                [11] = {r=c11.r, g=c11.g, b=c11.b}
            }
        end
        
        if self.DF_DispelCurve == nil then
            if C_CurveUtil and C_CurveUtil.CreateColorCurve then
                local curve = C_CurveUtil.CreateColorCurve()
                curve:SetType(Enum.LuaCurveType.Step)
                curve:AddPoint(0, CreateColor(0, 0, 0, 0))
                curve:AddPoint(1, CreateColor(c1.r, c1.g, c1.b, 0.8))
                curve:AddPoint(2, CreateColor(c2.r, c2.g, c2.b, 0.8))
                curve:AddPoint(3, CreateColor(c3.r, c3.g, c3.b, 0.8))
                curve:AddPoint(4, CreateColor(c4.r, c4.g, c4.b, 0.8))
                curve:AddPoint(9, CreateColor(c9.r, c9.g, c9.b, 0.8))
                curve:AddPoint(11, CreateColor(c11.r, c11.g, c11.b, 0.8))
                self.DF_DispelCurve = curve
            else
                self.DF_DispelCurve = false
            end
        end
    end
    
    LayoutFrameAuras(frame, db, frame.mode)
    if not db then
        self:ClearFrameAuras(frame)
        return
    end
    local state = self:GetAuraState(frame, db)
    if not state then
        self:ClearFrameAuras(frame)
        self:UpdateArenaTrackers(frame)
        return
    end

    -- Arena trinket/DR indicators are independent of the normal aura toggles.
    self:UpdateArenaTrackers(frame)

    if db.showAuras == false then
        HideAuraIconSet(frame.buffIcons)
        HideAuraIconSet(frame.debuffIcons)
        HideAuraIcon(frame.ccIcon)
        HideAuraIcon(frame.missingBuffIcon)
        if frame.dispelOverlay then frame.dispelOverlay:Hide() end
        local borderColor = nil
        if db.showDispelOverlay ~= false then
            borderColor = (state.dispelType and DISPEL_COLORS[state.dispelType]) or GetAuraDispelColor(frame.unit, state.dispelAuraInstanceID, tonumber(db.dispelOverlayAlpha) or 1.0)
        end
        SetDispelFrameBorder(frame, borderColor, tonumber(db.dispelOverlayAlpha) or 1.0, tonumber(db.dispelBorderThickness) or 2, tonumber(db.dispelGradientAlpha) or 1.0, tonumber(db.dispelGradientSize) or 0.5)
        return
    end

    local auraFitBuffs, auraFitDebuffs = 5, 5
    if ns.GetAuraFitLimits then
        auraFitBuffs, auraFitDebuffs = ns.GetAuraFitLimits(frame.GetWidth and frame:GetWidth() or nil, db, frame.mode)
    end
    for i, icon in ipairs(frame.buffIcons or {}) do
        if i <= auraFitBuffs then
            RenderAuraIcon(icon, state.buffs and state.buffs[i])
        else
            HideAuraIcon(icon)
        end
    end
    for i, icon in ipairs(frame.debuffIcons or {}) do
        if i <= auraFitDebuffs then
            local aura = state.debuffs and state.debuffs[i]
            if i == 1 and not aura and state.dispelAura and db.showDispelOverlay ~= false then
                aura = state.dispelAura
            end
            RenderAuraIcon(icon, aura, { r = 0.8, g = 0, b = 0 })
        else
            HideAuraIcon(icon)
        end
    end
    RenderAuraIcon(frame.ccIcon, db.showCrowdControl ~= false and state.cc or nil, { r = 1, g = 0.12, b = 0.12 })
    RenderAuraIcon(frame.missingBuffIcon, db.showMissingBuffs ~= false and frame._ktOutOfRange ~= true and state.missingBuff or nil, { r = 1, g = 0.08, b = 0.08 })

    local buffCount = math.min(auraFitBuffs, state.buffs and #state.buffs or 0)
    local debuffCount = math.min(auraFitDebuffs, state.debuffs and #state.debuffs or 0)
    if debuffCount == 0 and auraFitDebuffs > 0 and state.dispelAura and db.showDispelOverlay ~= false then
        debuffCount = 1
    end
    LayoutCenteredAuraIcons(frame, db, buffCount, debuffCount)

    if frame.dispelOverlay then frame.dispelOverlay:Hide() end
    local borderColor = nil
    if db.showDispelOverlay ~= false then
        borderColor = (state.dispelType and DISPEL_COLORS[state.dispelType]) or GetAuraDispelColor(frame.unit, state.dispelAuraInstanceID, tonumber(db.dispelOverlayAlpha) or 1.0)
        
        -- 255 loop removed, relying on GetAuraDispelColor logic or state.dispelType

        if not borderColor and state.debuffs and #state.debuffs > 0 then
            for _, aura in ipairs(state.debuffs) do
                if aura.isBossDebuff then
                    borderColor = { r = 0.8, g = 0.1, b = 0.1, a = tonumber(db.dispelOverlayAlpha) or 1.0 }
                    break
                end
            end
        end
        -- GetAuraSlots fallback removed
    end
    SetDispelFrameBorder(frame, borderColor, tonumber(db.dispelOverlayAlpha) or 1.0, tonumber(db.dispelBorderThickness) or 2, tonumber(db.dispelGradientAlpha) or 1.0, tonumber(db.dispelGradientSize) or 0.5)
end

function Mod:GetAuraSpellCatalog(mode)
    local db = self:GetModeDB(mode or "party")
    local entries = {}
    local seen = {}

    local function AddEntry(spellID, auraType, name, icon)
        spellID = tonumber(spellID)
        if not spellID or seen[spellID] then return end
        seen[spellID] = true
        entries[#entries + 1] = {
            spellID = spellID,
            auraType = auraType or "aura",
            name = GetSpellNameSafe(spellID, name),
            icon = GetSpellIconSafe(spellID, icon),
        }
    end

    for _, rule in pairs(MISSING_BUFF_RULES) do
        AddEntry((rule.spellIDs and rule.spellIDs[1]) or nil, "missing", rule.name, rule.icon)
    end
    for _, entry in ipairs(SAMPLE_AURA_CATALOG) do
        AddEntry(entry.spellID, entry.auraType, entry.name, entry.icon)
    end
    if db and type(db.auraSpellCatalog) == "table" then
        for _, entry in pairs(db.auraSpellCatalog) do
            if type(entry) == "table" then
                AddEntry(entry.spellID, entry.auraType, entry.name, entry.icon)
            end
        end
    end

    table.sort(entries, function(a, b)
        local an = a.name or ""
        local bn = b.name or ""
        if an == bn then return (a.spellID or 0) < (b.spellID or 0) end
        return an < bn
    end)
    return entries
end

function Mod:IsAuraSpellVisible(mode, spellID)
    return AuraSpellIsVisible(self:GetModeDB(mode or "party"), spellID)
end

function Mod:DebugAuraSpellClick(mode, spellID, enabled, source)
    self:EnsureDB()
    DebugAuraSpellPrint(self.db, string.format("ui click source=%s mode=%s spellID=%s enabled=%s currentlyVisible=%s", tostring(source), tostring(mode), tostring(spellID), tostring(enabled), tostring(self:IsAuraSpellVisible(mode, spellID))))
end

function Mod:SetAuraSpellVisible(mode, spellID, visible)
    mode = NormalizeMode(mode or "party")
    local db = self:GetModeDB(mode)
    if not db then return false end
    if type(db.auraSpellVisibility) ~= "table" then
        db.auraSpellVisibility = {}
    end
    spellID = tonumber(spellID)
    if not spellID then return false end
    local key = tostring(spellID)
    local before = db.auraSpellVisibility[key]
    if visible == false then
        db.auraSpellVisibility[key] = false
    else
        db.auraSpellVisibility[key] = nil
    end
    DebugAuraSpellPrint(self.db, string.format("set mode=%s spellID=%s visible=%s before=%s after=%s", tostring(mode), tostring(spellID), tostring(visible), tostring(before), tostring(db.auraSpellVisibility[key])))
    self.auraCache = {}
    local ok, reason = self:ApplyLayout(mode)
    DebugAuraSpellPrint(self.db, string.format("apply mode=%s ok=%s reason=%s cacheCleared=true", tostring(mode), tostring(ok), tostring(reason)))
    return ok, reason
end

function Mod:ResetAuraSpellVisibility(mode)
    mode = NormalizeMode(mode or "party")
    local db = self:GetModeDB(mode)
    if not db then return false end
    db.auraSpellVisibility = {}
    DebugAuraSpellPrint(self.db, "reset mode=" .. tostring(mode))
    self.auraCache = {}
    return self:ApplyLayout(mode)
end

function Mod:DumpAuraSpellDebug(mode)
    mode = NormalizeMode(mode or "party")
    self:EnsureDB()
    local modeDB = self:GetModeDB(mode)
    local hidden = {}
    if modeDB and type(modeDB.auraSpellVisibility) == "table" then
        for spellID, visible in pairs(modeDB.auraSpellVisibility) do
            if visible == false then
                hidden[#hidden + 1] = tostring(spellID)
            end
        end
    end
    table.sort(hidden)
    DebugAuraSpellPrint(self.db, string.format("dump mode=%s hidden=%s", tostring(mode), (#hidden > 0 and table.concat(hidden, ", ") or "none")))
    for _, frame in ipairs((self.frames and self.frames[mode]) or {}) do
        if frame:IsShown() and frame.unit then
            local state = self:GetAuraState(frame, modeDB)
            DebugAuraSpellPrint(self.db, string.format("frame unit=%s buffs=%d debuffs=%d cc=%s missing=%s", tostring(frame.unit), #(state and state.buffs or {}), #(state and state.debuffs or {}), tostring(state and state.cc and state.cc.spellID), tostring(state and state.missingBuff and state.missingBuff.spellID)))
            local border = frame.dispelBorder
            local borderShown = border and border[1] and border[1]:IsShown() and "shown" or "hidden"
            local gradientShown = border and border.gradientTop and border.gradientTop:IsShown() and "shown" or "hidden"
            DebugAuraSpellPrint(self.db, string.format("  dispelBorder type=%s auraID=%s edge=%s gradient=%s outOfRange=%s layout=%sx%s", tostring(state and state.dispelType), tostring(state and state.dispelAuraInstanceID), borderShown, gradientShown, tostring(frame._ktOutOfRange == true), tostring(frame._layoutWidth), tostring(frame._layoutHeight)))
            for i, aura in ipairs((state and state.buffs) or {}) do
                DebugAuraSpellPrint(self.db, string.format("  buff[%d] spellID=%s icon=%s", i, tostring(aura.spellID), tostring(aura.icon)))
            end
            for i, aura in ipairs((state and state.debuffs) or {}) do
                DebugAuraSpellPrint(self.db, string.format("  debuff[%d] spellID=%s icon=%s dispel=%s", i, tostring(aura.spellID), tostring(aura.icon), tostring(aura.dispelType)))
            end
        end
    end
end

function Mod:SetAuraSpellDebug(enabled)
    self:EnsureDB()
    self.db.debugAuraSpells = enabled == true
    DebugAuraSpellPrint(self.db, self.db.debugAuraSpells and "enabled" or "disabled", true)
end

ns.SetRaidTargetIcon = function(texture, index)
    if not texture or not index then return false end
    texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(texture, index)
        return true
    end
    if IsSecretValue(index) then return false end
    local col = ((index - 1) % 4) / 4
    local row = math.floor((index - 1) / 4) / 4
    texture:SetTexCoord(col, col + 0.25, row, row + 0.25)
    return true
end

ns.GetUnitNameKey = function(unit)
    if not (unit and UnitName) then return nil end
    local ok, name, realm = pcall(UnitName, unit)
    if not (ok and name and not IsSecretValue(name)) then return nil end
    if realm and realm ~= "" and not IsSecretValue(realm) then
        return string.lower(tostring(name) .. "-" .. tostring(realm)), string.lower(tostring(name))
    end
    return string.lower(tostring(name)), nil
end

ns.SafePublicEquals = function(left, right)
    if IsSecretValue(left) or IsSecretValue(right) then return false end
    if left and right then
        local ok, same = pcall(function()
            return left == right
        end)
        return ok and same == true
    end
    return false
end

ns.UnitTokenMatches = function(unit, token, guid, unitNameKey, shortNameKey)
    if UnitIsUnit then
        local ok, same = pcall(UnitIsUnit, unit, token)
        if ok and not IsSecretValue(same) and same == true then
            return true
        end
    end

    if guid and UnitGUID then
        local okTokenGuid, tokenGuid = pcall(UnitGUID, token)
        if okTokenGuid and ns.SafePublicEquals(tokenGuid, guid) then
            return true
        end
    end

    if unitNameKey then
        local tokenNameKey, tokenShortNameKey = ns.GetUnitNameKey(token)
        return ns.SafePublicEquals(tokenNameKey, unitNameKey)
            or (shortNameKey and ns.SafePublicEquals(tokenShortNameKey, shortNameKey))
            or (shortNameKey and ns.SafePublicEquals(tokenNameKey, shortNameKey))
            or ns.SafePublicEquals(tokenShortNameKey, unitNameKey)
    end

    return false
end

ns.GetUnitRaidTargetIndex = function(unit)
    if not (unit and GetRaidTargetIndex) then return nil end

    local ok, index = pcall(GetRaidTargetIndex, unit)
    if ok and index then
        return index
    end

    -- Group-unit frames use standard tokens (partyN/raidN/player/arenaN). A
    -- marker set on them is always reported by the direct call above, so the
    -- nameplate enumeration below can never find them and is pure overhead
    -- (43 token lookups with pcalls per frame per refresh, 40+ frames in raid).
    if unit == "player"
        or unit:match("^party%d+$")
        or unit:match("^raid%d+$")
        or unit:match("^arena%d+$") then
        return nil
    end

    local guid
    if UnitGUID then
        local okGuid, value = pcall(UnitGUID, unit)
        if okGuid and value and not IsSecretValue(value) then
            guid = value
        end
    end
    local unitNameKey, shortNameKey = ns.GetUnitNameKey(unit)

    local candidates = { "target", "focus", "mouseover" }
    for _, token in ipairs(candidates) do
        if ns.UnitTokenMatches(unit, token, guid, unitNameKey, shortNameKey) then
            ok, index = pcall(GetRaidTargetIndex, token)
            if ok and index then
                return index
            end
        end
    end

    -- Never enumerate C_NamePlate.GetNamePlates() here. Its returned table may
    -- be restricted during PvP. Fixed unit tokens provide the same lookup while
    -- keeping all iteration on a KUI-owned numeric range.
    for i = 1, 40 do
        local token = "nameplate" .. i
        if UnitExists and UnitExists(token)
            and ns.UnitTokenMatches(unit, token, guid, unitNameKey, shortNameKey) then
            ok, index = pcall(GetRaidTargetIndex, token)
            if ok and index then
                return index
            end
        end
    end

    return nil
end

ns.SetLeaderIcon = function(icon, state)
    if not icon then return end
    if state == "leader" then
        icon.texture:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
        icon.texture:SetTexCoord(0, 1, 0, 1)
        icon:Show()
    elseif state == "assistant" then
        icon.texture:SetTexture("Interface\\GroupFrame\\UI-Group-AssistantIcon")
        icon.texture:SetTexCoord(0, 1, 0, 1)
        icon:Show()
    else
        icon:Hide()
    end
end

ns.SetReadyCheckIcon = function(icon, status)
    if not icon then return end
    local texture
    if status == "ready" then
        texture = "Interface\\RaidFrame\\ReadyCheck-Ready"
    elseif status == "notready" then
        texture = "Interface\\RaidFrame\\ReadyCheck-NotReady"
    elseif status == "waiting" then
        texture = "Interface\\RaidFrame\\ReadyCheck-Waiting"
    end
    if texture then
        icon.texture:SetTexture(texture)
        icon.texture:SetTexCoord(0, 1, 0, 1)
        icon:Show()
    else
        icon:Hide()
    end
end

function Mod:UpdateFrameIndicators(frame, data)
    if not frame then return end
    local db = self:GetModeDB(frame.mode or "party")
    if data then
        local index = frame.fakeUnit and frame.fakeUnit.index or 1
        ns.SetLeaderIcon(frame.leaderIcon, db.showLeaderIcon ~= false and (index == 1 and "leader" or (index == 2 and "assistant" or nil)) or nil)
        if db.showRaidTargetIcon ~= false and index % 5 == 0 then
            ns.SetRaidTargetIcon(frame.raidTargetIcon.texture, ((index - 1) % 8) + 1)
            frame.raidTargetIcon:Show()
        else
            frame.raidTargetIcon:Hide()
        end
        if db.showReadyCheckIcon ~= false and not data.status and index % 6 == 0 then
            local status = index % 12 == 0 and "notready" or "ready"
            ns.SetReadyCheckIcon(frame.readyCheckIcon, status)
        else
            frame.readyCheckIcon:Hide()
        end
        return
    end

    local unit = frame.unit
    if not IsUnitUsable(unit) then
        frame._lastLeaderState = nil
        ns.SetLeaderIcon(frame.leaderIcon, nil)
        frame.raidTargetIcon:Hide()
        frame.readyCheckIcon:Hide()
        return
    end

    local leaderState
    if db.showLeaderIcon ~= false then
        local readable
        leaderState, readable = ReadGroupLeaderState(unit)
        if readable then
            frame._lastLeaderState = leaderState
        else
            -- Tainted execution (typically in combat) makes leader queries return
            -- secret values. Keep the last readable state instead of blanking the
            -- icon, mirroring the out-of-combat read strategy of DandersFrames.
            leaderState = frame._lastLeaderState
            if not leaderState and not frame._leaderReadPending then
                -- The update path can be tainted (PvP/in-combat identity reads).
                -- Re-query in a fresh, untainted C_Timer context so plain booleans
                -- come back and the icon can finally be populated.
                frame._leaderReadPending = true
                local pendingUnit = unit
                C_Timer.After(0, function()
                    frame._leaderReadPending = nil
                    if frame.unit ~= pendingUnit then return end
                    local pendingState, pendingReadable = ReadGroupLeaderState(pendingUnit)
                    if pendingReadable then
                        frame._lastLeaderState = pendingState
                        ns.SetLeaderIcon(frame.leaderIcon, pendingState)
                        return
                    end
                    -- Keep a valid icon during a transient protected read.
                    ns.SetLeaderIcon(frame.leaderIcon, frame._lastLeaderState)
                end)
            end
        end
    else
        frame._lastLeaderState = nil
    end
    ns.SetLeaderIcon(frame.leaderIcon, leaderState)

    if db.showRaidTargetIcon ~= false and GetRaidTargetIndex then
        local index = ns.GetUnitRaidTargetIndex(unit)
        if index then
            ns.SetRaidTargetIcon(frame.raidTargetIcon.texture, index)
            frame.raidTargetIcon:Show()
        else
            frame.raidTargetIcon:Hide()
        end
    else
        frame.raidTargetIcon:Hide()
    end

    if db.showReadyCheckIcon ~= false and GetReadyCheckStatus then
        local ok, status = pcall(GetReadyCheckStatus, unit)
        if ok and not IsSecretValue(status) then
            ns.SetReadyCheckIcon(frame.readyCheckIcon, status)
        else
            frame.readyCheckIcon:Hide()
        end
    else
        frame.readyCheckIcon:Hide()
    end
end

function Mod:GetUnits(mode)
    mode = NormalizeMode(mode)
    local units = {}

    if self.testMode[mode] then
        local db = self:GetModeDB(mode)
        local includePlayer = not IsRaidMode(mode) and db.showPlayer ~= false
        local isArenaMode = mode == "arena" or mode == "arenaEnemy"
        local count = IsRaidMode(mode) and (tonumber(db.raidTestFrameCount) or (mode == "raid40" and 40 or 20)) or (isArenaMode and 3 or (mode == "boss" and 5 or (includePlayer and 5 or 4)))
        count = math.max(1, math.min(IsRaidMode(mode) and 40 or 5, count))
        local middle = math.floor(count / 2) + 1
        units.layoutCount = count
        for i = 1, count do
            units[#units + 1] = { fake = true, index = i, slot = i, isPlayer = includePlayer and i == middle }
        end
        return units
    end

    if mode == "boss" then
        for i = 1, 5 do
            local unit = "boss" .. i
            if IsUnitUsable(unit) then units[#units + 1] = unit end
        end
        units.layoutCount = #units
    elseif mode == "arenaEnemy" then
        for i = 1, 5 do
            local unit = 'arena' .. i
            -- Opponent tokens are disclosed asynchronously after entering arena.
            -- Bind all secure tokens before combat so UnitWatch can reveal them.
            units[#units + 1] = unit
        end
        local opponentCount = 3
        if GetNumArenaOpponentSpecs then
            local ok, count = pcall(GetNumArenaOpponentSpecs)
            count = ok and not IsSecretValue(count) and tonumber(count) or nil
            if count and count > 0 then
                opponentCount = math.max(1, math.min(5, count))
            end
        end
        units.layoutCount = opponentCount
    elseif mode == 'arena' and IsInRaid and IsInRaid() then
        -- Some arena types expose the allied roster through raidN rather than
        -- partyN. Still render those units with the dedicated Arena profile.
        local db = self:GetModeDB(mode)
        local total = math.min(5, self:GetAccessibleGroupCount())
        for i = 1, total do
            local unit = 'raid' .. i
            if IsUnitUsable(unit) then
                local isPlayer = false
                if UnitIsUnit then
                    local ok, same = pcall(UnitIsUnit, unit, 'player')
                    isPlayer = ok and not IsSecretValue(same) and same == true
                end
                if db.showPlayer ~= false or not isPlayer then
                    units[#units + 1] = unit
                end
            end
        end
        SortGroupUnitsByRole(units)
        units.roleSorted = true
        if db.growDirection == 'HORIZONTAL' and db.growthAnchor == 'CENTER' then
            units.layoutCount = db.showPlayer ~= false and 3 or 2
            units.visibleLayoutCount = #units
        end
    elseif IsRaidMode(mode) then
        local total = self:GetAccessibleGroupCount()
        local db = self:GetModeDB(mode)
        if db and db.raidUseGroups ~= false and GetRaidRosterInfo then
            local ppg = tonumber(db.raidPlayersPerRow) or 5
            local subgroupCounts = {}
            local maxSlot = 0
            for i = 1, math.min(total, 40) do
                local unit = "raid" .. i
                if IsUnitUsable(unit) then
                    local subgroup = self:GetRosterSubgroup(i, math.ceil(i / ppg))
                    if subgroup < 1 or subgroup > 8 then
                        subgroup = math.ceil(i / ppg)
                    end
                    subgroupCounts[subgroup] = (subgroupCounts[subgroup] or 0) + 1
                    local slot = ((subgroup - 1) * ppg) + subgroupCounts[subgroup]
                    maxSlot = math.max(maxSlot, slot)
                    units[#units + 1] = { unit = unit, slot = slot, subgroup = subgroup }
                end
            end
            units.layoutCount = maxSlot
            return units
        else
            for i = 1, math.min(total, 40) do
                local unit = "raid" .. i
                if IsUnitUsable(unit) then
                    units[#units + 1] = unit
                end
            end
        end
    else
        local db = self:GetModeDB(mode)
        if db.showPlayer ~= false then
            for i = 1, 4 do
                local unit = "party" .. i
                if IsUnitUsable(unit) then
                    units[#units + 1] = unit
                end
            end
            if IsUnitUsable("player") then
                units[#units + 1] = "player"
            end
            SortGroupUnitsByRole(units)
            units.roleSorted = true
            if db.growDirection == "HORIZONTAL" and db.growthAnchor == "CENTER" then
                units.layoutCount = mode == "arena" and 3 or 5
                units.visibleLayoutCount = #units
            end
        else
            for i = 1, 4 do
                local unit = "party" .. i
                if IsUnitUsable(unit) then
                    units[#units + 1] = unit
                end
            end
            SortGroupUnitsByRole(units)
            units.roleSorted = true
            if db.growDirection == "HORIZONTAL" and db.growthAnchor == "CENTER" then
                units.layoutCount = mode == "arena" and 3 or 4
                units.visibleLayoutCount = #units
            end
        end
    end

    if IsRaidMode(mode) and self.db[mode].sortEnabled ~= false then
        table.sort(units, function(a, b)
            local unitA = type(a) == "table" and a.unit or a
            local unitB = type(b) == "table" and b.unit or b
            local roleA = GetAccessibleUnitRole(unitA)
            local roleB = GetAccessibleUnitRole(unitB)
            if ROLE_ORDER[roleA] ~= ROLE_ORDER[roleB] then
                return (ROLE_ORDER[roleA] or 9) < (ROLE_ORDER[roleB] or 9)
            end
            if self.db[mode].sortByClass then
                local classA = GetUnitClassToken(unitA)
                local classB = GetUnitClassToken(unitB)
                if classA ~= classB then
                    return tostring(classA or "") < tostring(classB or "")
                end
            end
            if self.db[mode].sortAlphabetical then
                return GetAccessibleUnitNameForSort(unitA) < GetAccessibleUnitNameForSort(unitB)
            end
            return tostring(unitA) < tostring(unitB)
        end)
    end

    if not units.layoutCount and not units.roleSorted then
        MovePlayerToMiddle(units)
    end

    return units
end

function Mod:GetRosterSubgroup(index, fallback)
    if not GetRaidRosterInfo then return fallback end
    local ok, _, _, subgroup = pcall(GetRaidRosterInfo, index)
    if not ok or IsSecretValue(subgroup) then return fallback end
    subgroup = tonumber(subgroup)
    if subgroup and subgroup >= 1 and subgroup <= 8 then
        return subgroup
    end
    return fallback
end

function Mod:GetPlayerRaidSubgroup(total, ppg)
    if not UnitGUID then return nil end
    local playerOK, playerGUID = pcall(UnitGUID, "player")
    if not playerOK or not playerGUID or IsSecretValue(playerGUID) then return nil end

    for i = 1, math.min(total or 0, 40) do
        local unit = "raid" .. i
        local guidOK, guid = pcall(UnitGUID, unit)
        if guidOK and guid and not IsSecretValue(guid) and guid == playerGUID then
            return self:GetRosterSubgroup(i, math.ceil(i / (ppg or 5)))
        end
    end
    return nil
end

function Mod:GetOwnGroupUnits(mode)
    mode = NormalizeMode(mode)
    local units = {}
    if not IsRaidMode(mode) then return units end

    local db = self:GetModeDB(mode)
    if not (db and db.raidPopOutOwnGroup == true and db.raidUseGroups ~= false) then
        return units
    end

    local ppg = math.max(1, math.min(5, tonumber(db.raidPlayersPerRow) or 5))
    units.layoutCount = ppg

    if self.testMode[mode] then
        for i = 1, ppg do
            units[#units + 1] = { fake = true, index = i, slot = i, isPlayer = i == math.ceil(ppg / 2), ownGroup = true, subgroup = 1 }
        end
        units.subgroup = 1
        return units
    end

    local total = self:GetAccessibleGroupCount()
    local playerSubgroup = self:GetPlayerRaidSubgroup(total, ppg)
    if not playerSubgroup then return units end

    for i = 1, math.min(total, 40) do
        local unit = "raid" .. i
        if IsUnitUsable(unit) then
            local subgroup = self:GetRosterSubgroup(i, math.ceil(i / ppg))
            if subgroup == playerSubgroup then
                units[#units + 1] = { unit = unit, slot = #units + 1, subgroup = subgroup, ownGroup = true }
            end
        end
    end

    units.subgroup = playerSubgroup
    units.layoutCount = math.max(ppg, #units)
    return units
end

function Mod:GetLayoutCount(mode, units)
    local count = units and (units.layoutCount or #units) or 0
    for _, unit in ipairs(units or {}) do
        if type(unit) == "table" and unit.slot and unit.slot > count then
            count = unit.slot
        end
    end
    return count
end

function Mod:GetModeVisibility(mode)
    local db = self:GetModeDB(mode)
    if not db or db.enabled == false then return false end
    if self.testMode[mode] then return true end
    if self:HasActiveTestMode() then return false end
    local inArena = self:IsArenaContext()
    if mode == "arenaEnemy" then
        return inArena
    end
    if mode == "boss" then
        return IsEncounterInProgress and IsEncounterInProgress() == true
    end
    local liveMode = GetLiveGroupMode()
    if liveMode then
        return mode == liveMode
    end
    if IsRaidMode(mode) then
        local total = self:GetAccessibleGroupCount()
        return mode == "raid40" and total > 25 or (total > 0 and total <= 25)
    end
    if mode == "arena" then
        return inArena
    end
    return not (IsInRaid and IsInRaid()) and not inArena
end

function Mod:GetContainerSize(mode, count)
    local db = self:GetModeDB(mode)
    count = count or #self:GetUnits(mode)
    if count <= 0 then
        count = IsRaidMode(mode) and (mode == "raid40" and 40 or 20)
            or ((mode == "arena" or mode == "arenaEnemy") and 3 or 5)
    end

    local w = (tonumber(db.frameWidth) or 125) * (tonumber(db.frameScale) or 1)
    local h = (tonumber(db.frameHeight) or 64) * (tonumber(db.frameScale) or 1)
    local spacing = tonumber(db.frameSpacing) or 2
    local cols
    local groupHeaderH = 0
    if IsRaidMode(mode) then
        if db.raidUseGroups ~= false then
            local ppg = tonumber(db.raidPlayersPerRow) or 5
            cols = math.ceil(count / ppg)
            local maxGroups = tonumber(db.raidGroupsPerRow) or 8
            if cols > maxGroups then cols = maxGroups end
            groupHeaderH = 18
        else
            cols = math.max(1, math.min(count, tonumber(db.raidGroupsPerRow) or 5))
        end
    elseif db.growDirection == "VERTICAL" then
        cols = 1
    else
        cols = count
    end
    cols = math.max(1, math.min(cols, count))
    local rows = math.ceil(count / cols)
    if IsRaidMode(mode) and db.raidUseGroups ~= false then
        local ppg = tonumber(db.raidPlayersPerRow) or 5
        rows = ppg
    end
    local auraReserve = GetExternalAuraReserve(db, mode)
    local layoutSpacing = spacing
    if mode == "party" and auraReserve > 0 then
        layoutSpacing = math.max(spacing, 6)
    end
    return (cols * w) + ((cols - 1) * spacing), (rows * (h + auraReserve)) + ((rows - 1) * layoutSpacing) + groupHeaderH, cols, rows
end

function Mod:PositionFrame(frame, parent, index, count, mode, visibleCount, layoutKind)
    local db = self:GetModeDB(mode)
    local width = (tonumber(db.frameWidth) or 125) * (tonumber(db.frameScale) or 1)
    local height = (tonumber(db.frameHeight) or 64) * (tonumber(db.frameScale) or 1)
    local spacing = tonumber(db.frameSpacing) or 2
    local padding = math.max(0, tonumber(db.framePadding) or 0)
    local powerHeight = math.max(4, math.min(8, tonumber(db.powerBarHeight) or (height * 0.12)))
    local showPower = db.showPowerBar == true
    local _, _, cols = self:GetContainerSize(mode, count)
    local col, row
    local groupHeaderH = 0
    local centerOffsetX = 0
    if layoutKind == "ownGroup" then
        col = 0
        row = math.max(0, index - 1)
        groupHeaderH = 18
    elseif IsRaidMode(mode) and db.raidUseGroups ~= false then
        local ppg = tonumber(db.raidPlayersPerRow) or 5
        local maxGroups = tonumber(db.raidGroupsPerRow) or 8
        local groupIndex = math.floor((index - 1) / ppg)
        local memberIndex = (index - 1) % ppg
        col = groupIndex % maxGroups
        row = memberIndex + math.floor(groupIndex / maxGroups) * ppg
        groupHeaderH = 18
    else
        col = (index - 1) % cols
        row = math.floor((index - 1) / cols)
        if not IsRaidMode(mode) and db.growDirection == "HORIZONTAL" and db.growthAnchor == "CENTER" then
            visibleCount = math.max(1, math.min(tonumber(visibleCount) or count or 1, count or 1))
            if visibleCount < count then
                centerOffsetX = ((count - visibleCount) * (width + spacing)) * 0.5
            end
        end
    end

    frame:ClearAllPoints()
    local auraReserve = GetExternalAuraReserve(db, mode)
    local compactPartySpacing = spacing
    if mode == "party" and auraReserve > 0 then
        compactPartySpacing = math.max(spacing, 6)
    end
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", centerOffsetX + (col * (width + spacing)), -(row * (height + auraReserve + compactPartySpacing)) - groupHeaderH)
    frame:SetSize(width, height)
    frame._layoutWidth = width
    frame._layoutHeight = height

    if frame.specIconFrame then
        frame.specIconFrame:ClearAllPoints()
        local specIconSize = math.max(36, height)
        local specSide = db and db.arenaSpecIconSide or "LEFT"
        frame.specIconFrame:SetSize(specIconSize, specIconSize)
        if specSide == "LEFT" then
            frame.specIconFrame:SetPoint('RIGHT', frame, 'LEFT', -4, 0)
        else
            frame.specIconFrame:SetPoint('LEFT', frame, 'RIGHT', 4, 0)
        end
        if mode ~= 'arenaEnemy' then
            frame.specIconFrame:Hide()
        end
    end

    frame.health:ClearAllPoints()
    frame.power:ClearAllPoints()
    frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", padding, -padding)
    frame.health:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -padding, -padding)
    if showPower then
        frame.power:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", padding, padding)
        frame.power:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -padding, padding)
        frame.power:SetHeight(powerHeight)
        frame.health:SetPoint("BOTTOMRIGHT", frame.power, "TOPRIGHT", 0, 1)
    else
        frame.health:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -padding, padding)
        frame.power:SetHeight(powerHeight)
    end

    local maxName = IsRaidMode(mode) and math.floor(height * 0.40) or nil
    local maxValue = IsRaidMode(mode) and math.floor(height * 0.35) or nil

    ApplyTextStyle(frame.nameText, db, "nameFontSize", 15, maxName)
    ApplyTextStyle(frame.valueText, db, "healthTextFontSize", 12, maxValue)
    ApplyTextStyle(frame.statusText, db, "healthTextFontSize", 12, maxValue)

    local innerWidth = math.max(1, width - (padding * 2))
    frame.nameText:ClearAllPoints()
    frame.valueText:ClearAllPoints()
    local nx = tonumber(db.nameOffsetX) or 0
    local ny = tonumber(db.nameOffsetY) or 0
    local hx = tonumber(db.healthOffsetX) or 0
    local hy = tonumber(db.healthOffsetY) or 0

    local statusValueWidth = math.min(70, innerWidth)
    if height >= 70 or (width < 140 and height >= 40) then
        frame._nameMaxChars = math.max(3, math.floor(innerWidth / ((tonumber(db.nameFontSize) or 15) * 0.58)))
        frame.nameText:SetJustifyH("CENTER")
        frame.nameText:SetPoint("CENTER", frame.health, "CENTER", 0 + nx, 10 + ny)
        frame.nameText:SetWidth(innerWidth - 12)
        frame.nameText:SetHeight(18)
        frame.valueText:SetJustifyH("CENTER")
        frame.valueText:SetPoint("CENTER", frame.health, "CENTER", 0 + hx, -10 + hy)
        frame.valueText:SetWidth(innerWidth - 12)
        frame.valueText:SetHeight(16)
    else
        local format = db.healthTextFormat or "CURRENTMAX"
        local valueWidth
        if format == "NONE" then
            valueWidth = 1
        elseif format == "PERCENT" then
            valueWidth = 38
        else
            valueWidth = math.min(math.max(72, math.floor(innerWidth * 0.44)), math.max(44, innerWidth - 34))
        end
        statusValueWidth = valueWidth
        -- Allied and enemy arena frames use the same lower-left role icon as
        -- party frames, so reserve its full width before starting the name.
        local reserveRoleIcon = mode == "arena" or mode == "arenaEnemy"
            or (mode == "party" and db.growDirection == "VERTICAL")
        local nameLeftInset = reserveRoleIcon and PF_STATIC.partyVerticalNameLeftInset or 6
        local nameWidth = math.max(24, innerWidth - valueWidth - 16 - (nameLeftInset - 6))
        frame._nameMaxChars = math.max(3, math.floor(nameWidth / ((tonumber(db.nameFontSize) or 15) * 0.58)))
        frame.nameText:SetJustifyH("LEFT")
        frame.nameText:SetPoint("LEFT", frame.health, "LEFT", nameLeftInset + nx, 0 + ny)
        frame.nameText:SetWidth(nameWidth)
        frame.nameText:SetHeight(math.max(12, height - (padding * 2)))
        frame.valueText:SetJustifyH("RIGHT")
        frame.valueText:SetPoint("RIGHT", frame.health, "RIGHT", -6 + hx, 0 + hy)
        frame.valueText:SetWidth(valueWidth)
        frame.valueText:SetHeight(math.max(12, height - (padding * 2)))
    end

    -- Anchor statusIcon
    frame.statusIcon:ClearAllPoints()
    local isRaidMode = (mode == "raid" or mode == "raid40")
    local isCenteredStatus = height >= 70 or (width < 140 and height >= 40)
    local isHorizontalCenteredStatus = isCenteredStatus and db.growDirection == "HORIZONTAL"
    if isRaidMode then
        frame.statusIcon:SetSize(20, 20)
        frame.statusIcon:SetPoint("CENTER", frame.health, "CENTER", 0, 5)
        frame.statusIcon:SetAlpha(1)
    elseif isCenteredStatus then
        local iconSize = height >= 70 and 22 or 18
        frame.statusIcon:SetSize(iconSize, iconSize)
        frame.statusIcon:SetAlpha(1)
    else
        frame.statusIcon:SetSize(14, 14)
        frame.statusIcon:SetAlpha(1)
    end
    
    frame.statusText:ClearAllPoints()
    frame.statusText:SetJustifyH("CENTER")
    if isRaidMode and (height >= 70 or (width < 140 and height >= 40)) then
        frame.statusText:SetWidth(innerWidth - 12)
        frame.statusText:SetHeight(14)
        frame.statusText:SetPoint("CENTER", frame.health, "CENTER", 0, -12)
    elseif isCenteredStatus then
        frame.statusText:SetJustifyH(isHorizontalCenteredStatus and "CENTER" or "LEFT")
        frame.statusText:SetWidth(isHorizontalCenteredStatus and math.min(90, innerWidth - 12) or math.min(70, innerWidth - 24))
        frame.statusText:SetHeight(16)
        frame.statusText:SetPoint("CENTER", frame.health, "CENTER", isHorizontalCenteredStatus and 0 or 12, isHorizontalCenteredStatus and -3 or 0)
    else
        frame.statusText:SetJustifyH("LEFT")
        frame.statusText:SetWidth(math.max(34, math.min(statusValueWidth, innerWidth - 24)))
        frame.statusText:SetHeight(math.max(12, height - (padding * 2)))
        frame.statusText:SetPoint("RIGHT", frame.health, "RIGHT", -6, 0)
    end
    if not isRaidMode then
        frame.statusIcon:ClearAllPoints()
        if isHorizontalCenteredStatus then
            frame.statusIcon:SetPoint("TOP", frame.statusText, "BOTTOM", 0, -1)
        else
            frame.statusIcon:SetPoint("RIGHT", frame.statusText, "LEFT", -3, 0)
        end
    end

    frame.roleIcon:ClearAllPoints()
    frame.roleIcon:SetSize(18, 18)
    frame.roleIcon:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 2)
    frame.roleIcon:SetShown(true)

    frame.leaderIcon:ClearAllPoints()
    frame.leaderIcon:SetSize(12, 12)
    frame.leaderIcon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 1)

    frame.raidTargetIcon:ClearAllPoints()
    frame.raidTargetIcon:SetSize(16, 16)
    frame.raidTargetIcon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

    frame.readyCheckIcon:ClearAllPoints()
    frame.readyCheckIcon:SetSize(16, 16)
    frame.readyCheckIcon:SetScale(1.6)
    frame.readyCheckIcon:SetPoint("CENTER", frame, "CENTER", 0, 0)

    frame.absorb:ClearAllPoints()
    frame.absorb:SetPoint("TOPRIGHT", frame.health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    frame.absorb:SetPoint("BOTTOMRIGHT", frame.health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    frame.absorb:SetWidth(math.max(1, width - (padding * 2)))
end

function Mod:SetFrameUnit(frame, unit)
    if InCombatLockdown and InCombatLockdown() then
        self.pendingAll = true
        return false
    end
    if UnregisterUnitWatch then
        pcall(UnregisterUnitWatch, frame)
    end
    local oldUnit = frame.unit
    frame.unit = type(unit) == "string" and unit or (type(unit) == "table" and unit.unit) or nil
    frame.fakeUnit = type(unit) == "table" and unit.fake and unit or nil
    frame._lastLeaderState = nil
    frame._ktInRange = nil
    frame._ktOutOfRange = false
    frame._ktEventDead = nil
    frame._ktEventConnected = nil
    frame._ktPowerMax = nil
    frame._ktAbsorbMax = nil
    frame._ktAbsorbValue = nil
    frame:SetAttribute("unit", frame.unit)
    if frame.unit ~= oldUnit then
        self._auraUnitFrames = self._auraUnitFrames or {}
        local list = self._auraUnitFrames[oldUnit]
        if list then
            for i = #list, 1, -1 do
                if list[i] == frame then
                    table.remove(list, i)
                end
            end
            if #list == 0 then
                self._auraUnitFrames[oldUnit] = nil
            end
        end
        if frame.unit then
            list = self._auraUnitFrames[frame.unit]
            if not list then
                list = {}
                self._auraUnitFrames[frame.unit] = list
            end
            list[#list + 1] = frame
        end
    end
    if ns.PF_BindAuraContainers then ns.PF_BindAuraContainers(frame, frame.unit) end
    -- Enemy arena slots must remain visible during preparation, before
    -- UnitExists(arenaN) becomes true. Their visibility is managed by ApplyLayout.
    if frame.unit and RegisterUnitWatch and frame.mode ~= 'arenaEnemy' then
        pcall(RegisterUnitWatch, frame)
    end
    return true
end

function Mod:UpdateFrameVisual(frame, refreshAuras)
    if not frame then return end

    if frame.fakeUnit then
        local db = self:GetModeDB(frame.mode or "party")
        local data = GetTestUnitData(frame.fakeUnit, frame.mode or "party")
        local index = frame.fakeUnit.index or 1
        local specIcon, specName
        if frame.mode == 'arenaEnemy' then
            specIcon, specName = Mod:GetArenaSpecIcon(nil, index)
        end
        Mod:SetArenaSpecIcon(frame, specIcon, specName)
        local phase = self.testAnimationPhase or 0
        local role = data.role or "DAMAGER"
        local health = data.health or 0.75
        if not data.status then
            local wave = math.sin((phase * math.pi * 2) + index) * 0.16
            health = math.max(0.08, math.min(1, health + wave))
        end
        local power = math.max(0, math.min(1, (data.power or 0.7) + (math.sin((phase * math.pi * 2) + (index * 0.6)) * 0.10)))
        frame.health:SetMinMaxValues(0, 100)
        frame.health:SetStatusBarTexture(db.healthTexture or TEXTURE_FILL)
        frame.health:SetValue(health * 100)
        local cr, cg, cb
        if db.colorByClass ~= false then
            cr, cg, cb = GetTestClassColor(data.class, role)
        else
            cr, cg, cb = GetRoleColor(role)
        end
        frame.health:SetStatusBarColor(cr, cg, cb, 1)
        if data.status == "Offline" then
            frame.health:SetStatusBarColor(OFFLINE_HEALTH_COLOR.r, OFFLINE_HEALTH_COLOR.g, OFFLINE_HEALTH_COLOR.b, OFFLINE_HEALTH_COLOR.a)
            frame.health.bg:SetVertexColor(0.09, 0.10, 0.11, 1)
        else
            frame.health.bg:SetVertexColor(0.05, 0.05, 0.06, 1)
        end
        frame.power:SetMinMaxValues(0, 100)
        frame.power:SetValue(power * 100)
        if data.status == "Offline" then
            frame.power:SetStatusBarColor(OFFLINE_POWER_COLOR.r, OFFLINE_POWER_COLOR.g, OFFLINE_POWER_COLOR.b, OFFLINE_POWER_COLOR.a)
            frame.power.bg:SetVertexColor(0.06, 0.07, 0.08, 1)
        else
            frame.power:SetStatusBarColor(GetPowerColor())
            frame.power.bg:SetVertexColor(0.04, 0.04, 0.05, 1)
        end
        frame.power:SetShown(db.showPowerBar == true)
        frame.absorb:SetStatusBarTexture(TEXTURE_FILL)
        frame.absorb:SetStatusBarColor(DEFAULT_ABSORB_COLOR.r, DEFAULT_ABSORB_COLOR.g, DEFAULT_ABSORB_COLOR.b, DEFAULT_ABSORB_COLOR.a)
        frame.absorb:SetMinMaxValues(0, 100)
        frame.absorb:SetValue((data.absorb or 0) * 100)
        frame.absorb:SetShown(db.showAbsorbBar ~= false and (data.absorb or 0) > 0)
        local isRaidMode = (frame.mode == "raid" or frame.mode == "raid40")
        if data.status == "Dead" then
            frame.statusIcon:SetTexture(ICON_PATH .. "Dead.png")
            frame.statusIcon:Show()
            frame.nameText:SetAlpha(isRaidMode and 0.3 or 1)
        elseif data.status == "Offline" then
            frame.statusIcon:SetTexture(ICON_PATH .. "Offline.png")
            frame.statusIcon:Show()
            frame.nameText:SetAlpha(isRaidMode and 0.3 or 1)
        else
            frame.statusIcon:Hide()
            frame.nameText:SetAlpha(1)
        end
        frame.nameText:SetText(FitText(data.isPlayer and "Player" or data.name, frame._nameMaxChars))
        frame.nameText:Show()
        local frameH = tonumber(db.frameHeight) or 64
        local frameW = (tonumber(db.frameWidth) or 125) * (tonumber(db.frameScale) or 1)
        local centeredStatus = frameH >= 70 or (frameW < 140 and frameH >= 40)
        if data.status then
            local statusLabel = data.status == "Offline" and "Offline" or "Dead"
            frame.valueText:SetText("")
            frame.valueText:Hide()
            frame.statusText:SetText(statusLabel)
            frame.statusText:Show()
        else
            frame.statusText:Hide()
            SetTestHealthText(frame.valueText, data, db, health)
        end
        local style = db.roleIconStyle or "BLIZZARD"
        if role == "DAMAGER" or role == "HEALER" or role == "TANK" then
            if style == "KT" then
                frame.roleIcon:SetTexture(ROLE_ICON_PATH .. (role == "DAMAGER" and "DPS" or (role == "HEALER" and "Healer" or "Tank")) .. ".png")
                frame.roleIcon:SetTexCoord(0, 1, 0, 1)
            else
                frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
                SetBlizzardRoleIconCoords(frame.roleIcon, role)
            end
            frame.roleIcon:Show()
        else
            frame.roleIcon:Hide()
        end
        self:UpdateFrameIndicators(frame, data)
        frame:SetAlpha(data.status == "Offline" and 0.50 or (data.status == "Dead" and 0.62 or 1))
        if data.status then
            if refreshAuras ~= false then
                self:ClearFrameAuras(frame)
            end
            self:UpdateArenaTrackers(frame)
        elseif refreshAuras ~= false then
            self:UpdateFrameAuras(frame)
        end
        return
    end

    local unit = frame.unit
    local specIcon, specName, classFile
    if frame.mode == 'arenaEnemy' then
        specIcon, specName, classFile = Mod:GetArenaSpecIcon(unit)
    end
    Mod:SetArenaSpecIcon(frame, specIcon, specName)
    if not IsUnitUsable(unit) then
        local arenaIndex = frame.mode == 'arenaEnemy' and type(unit) == 'string'
            and tonumber(string.match(unit, '^arena(%d+)$')) or nil
        frame.nameText:SetText(arenaIndex and FitText(frame._arenaSpecName or ('Enemy ' .. arenaIndex), frame._nameMaxChars) or '')
        frame.nameText:SetShown(arenaIndex ~= nil)
        frame.valueText:SetText("")
        frame.roleIcon:Hide()
        frame.statusText:SetText("")
        frame.statusText:Hide()
        frame._ktInRange = true
        frame._ktOutOfRange = false
        frame:SetAlpha(arenaIndex and 1 or 0.35)
        frame.health:SetMinMaxValues(0, 100)
        frame.health:SetValue(arenaIndex and 100 or 0)
        if arenaIndex then
            local r, g, b = 0.20, 0.20, 0.24
            local db = self:GetModeDB(frame.mode or "party")
            if classFile and db and db.colorByClass ~= false then
                local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
                if c then
                    r, g, b = c.r, c.g, c.b
                end
            end
            frame.health:SetStatusBarColor(r, g, b, 0.92)
        end
        frame.power:SetValue(0)
        frame.absorb:Hide()
        frame.statusIcon:Hide()
        self:ClearFrameAuras(frame)
        self:UpdateArenaTrackers(frame)
        self:UpdateFrameIndicators(frame)
        return
    end

    local role = GetAccessibleUnitRole(unit)
    local db = self:GetModeDB(frame.mode or "party")
    local frameH = tonumber(db and db.frameHeight) or 64
    local frameW = ((tonumber(db and db.frameWidth) or 125) * (tonumber(db and db.frameScale) or 1))
    local centeredStatus = frameH >= 70 or (frameW < 140 and frameH >= 40)
    local r, g, b
    if db.colorByClass ~= false then
        r, g, b = GetClassColor(unit)
    else
        r, g, b = GetRoleColor(role)
    end
    local pr, pg, pb = GetPowerColor()

    frame.health:SetMinMaxValues(0, 100)
    frame.health:SetStatusBarTexture(db.healthTexture or TEXTURE_FILL)
    local hpPercent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    frame.health:SetValue(hpPercent)
    SetHealthText(frame.valueText, unit, db, hpPercent)
    frame.health:SetStatusBarColor(r, g, b, 0.9)
    frame.health.bg:SetVertexColor(0.05, 0.05, 0.06, 1)

    if db.showAbsorbBar ~= false and frame.absorb and UnitGetTotalAbsorbs and UnitHealthMax then
        local c = db.absorbBarColor or DEFAULT_ABSORB_COLOR
        frame.absorb:SetStatusBarTexture(db.absorbBarTexture or TEXTURE_FILL)
        frame.absorb:SetStatusBarColor(c.r or DEFAULT_ABSORB_COLOR.r, c.g or DEFAULT_ABSORB_COLOR.g, c.b or DEFAULT_ABSORB_COLOR.b, c.a or DEFAULT_ABSORB_COLOR.a)
        frame.absorb:SetMinMaxValues(0, UnitHealthMax(unit, true))
        frame.absorb:SetValue(UnitGetTotalAbsorbs(unit))
        frame.absorb:Show()
    elseif frame.absorb then
        frame.absorb:Hide()
    end

    local power = UnitPower and UnitPower(unit)
    local maxPower = UnitPowerMax and UnitPowerMax(unit)
    if db.showPowerBar == false or IsSecretValue(power) or IsSecretValue(maxPower) or type(power) ~= "number" or type(maxPower) ~= "number" then
        frame.power:Hide()
    else
        frame.power:SetMinMaxValues(0, maxPower)
        frame.power:SetValue(power)
        frame.power:Show()
    end
    frame.power:SetStatusBarColor(pr, pg, pb, 0.9)
    frame.power.bg:SetVertexColor(0.04, 0.04, 0.05, 1)
    frame.nameText:SetText(FitText(MakeUnitLabel(unit), frame._nameMaxChars))
    
    local style = db.roleIconStyle or "BLIZZARD"
    if role and not IsSecretValue(role) and (role == "DAMAGER" or role == "HEALER" or role == "TANK") then
        if style == "KT" then
            frame.roleIcon:SetTexture(ROLE_ICON_PATH .. (role == "DAMAGER" and "DPS" or (role == "HEALER" and "Healer" or "Tank")) .. ".png")
            frame.roleIcon:SetTexCoord(0, 1, 0, 1)
        else
            frame.roleIcon:SetTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
            SetBlizzardRoleIconCoords(frame.roleIcon, role)
        end
        frame.roleIcon:Show()
    else
        frame.roleIcon:Hide()
    end
    self:UpdateFrameIndicators(frame)

    local isDead = SafeUnitBoolean(UnitIsDeadOrGhost, unit)
    local isConnected = SafeUnitBoolean(UnitIsConnected, unit)
    frame._ktEventDead = isDead
    frame._ktEventConnected = isConnected
    local isAFK = SafeUnitBoolean(UnitIsAFK, unit)
    if isDead then
        frame.nameText:Show()
        frame.valueText:SetText("")
        frame.valueText:Hide()
        frame.statusText:SetText("Dead")
        frame.statusText:Show()
        frame.statusIcon:SetTexture(ICON_PATH .. "Dead.png")
        frame.statusIcon:Show()
        frame.nameText:SetAlpha((frame.mode == "raid" or frame.mode == "raid40") and 0.3 or 1)
        frame._ktInRange = true
        frame._ktOutOfRange = false
        frame:SetAlpha(0.62)
        self:ClearFrameAuras(frame)
        return
    elseif isConnected == false then
        frame.health:SetStatusBarColor(OFFLINE_HEALTH_COLOR.r, OFFLINE_HEALTH_COLOR.g, OFFLINE_HEALTH_COLOR.b, OFFLINE_HEALTH_COLOR.a)
        frame.health.bg:SetVertexColor(0.09, 0.10, 0.11, 1)
        frame.power:SetStatusBarColor(OFFLINE_POWER_COLOR.r, OFFLINE_POWER_COLOR.g, OFFLINE_POWER_COLOR.b, OFFLINE_POWER_COLOR.a)
        frame.power.bg:SetVertexColor(0.06, 0.07, 0.08, 1)
        frame.nameText:Show()
        frame.valueText:SetText("")
        frame.valueText:Hide()
        frame.statusText:SetText("Offline")
        frame.statusText:Show()
        frame.statusIcon:SetTexture(ICON_PATH .. "Offline.png")
        frame.statusIcon:Show()
        frame.nameText:SetAlpha((frame.mode == "raid" or frame.mode == "raid40") and 0.3 or 1)
        frame._ktInRange = true
        frame._ktOutOfRange = false
        frame:SetAlpha(0.50)
        self:ClearFrameAuras(frame)
        return
    elseif isAFK then
        frame.nameText:Show()
        if centeredStatus then
            frame.valueText:SetJustifyH("CENTER")
        else
            frame.valueText:SetJustifyH("RIGHT")
        end
        frame.statusText:Hide()
        frame.statusIcon:SetTexture(ICON_PATH .. "AFK.png")
        -- Keep the AFK label a little more compact in party frames without
        -- changing the indicator sizing used by the other frame modes.
        if frame.mode == "party" then
            frame.statusIcon:SetSize(28, 14)
        else
            frame.statusIcon:SetSize(32, 16)
        end
        frame.statusIcon:Show()
        frame.nameText:SetAlpha((frame.mode == "raid" or frame.mode == "raid40") and 0.3 or 1)
        local inRange = self:UpdateFrameRange(frame, false)
        if not IsSecretValue(inRange) and inRange == true then
            frame:SetAlpha(0.80)
        end
        self:ClearFrameAuras(frame)
        return
    else
        frame.nameText:Show()
        if centeredStatus then
            frame.valueText:SetJustifyH("CENTER")
        else
            frame.valueText:SetJustifyH("RIGHT")
        end
        frame.statusText:Hide()
        frame.statusIcon:Hide()
        frame.nameText:SetAlpha(1)
        self:UpdateFrameRange(frame, false)
    end
    
    if refreshAuras ~= false then
        local db = self:GetModeDB(frame.mode or "party")
        if db and ns.PF_UpdateAuraContainers then
            if ns.PF_UpdateAuraContainers(frame, db) then
                LayoutFrameAuras(frame, db, frame.mode)
            end
        end
        self:UpdateFrameAuras(frame)
    end
end

function Mod:UpdateGroupHeaders(container, mode, count)
    container.groupHeaders = container.groupHeaders or {}
    local db = self:GetModeDB(mode)
    local useGroups = IsRaidMode(mode) and db.raidUseGroups ~= false
    
    if (mode == "arena" or mode == "arenaEnemy") and db.enable == false then
        for _, header in ipairs(container.groupHeaders) do header:Hide() end
        container:Hide()
        return
    end
    
    if not useGroups then
        for _, header in ipairs(container.groupHeaders) do header:Hide() end
        return
    end
    
    local ppg = tonumber(db.raidPlayersPerRow) or 5
    local maxGroups = tonumber(db.raidGroupsPerRow) or 8
    local numGroups = math.ceil(count / ppg)
    
    local width = (tonumber(db.frameWidth) or 125) * (tonumber(db.frameScale) or 1)
    local spacing = tonumber(db.frameSpacing) or 2
    local height = (tonumber(db.frameHeight) or 64) * (tonumber(db.frameScale) or 1)
    
    for i = 1, math.max(numGroups, #container.groupHeaders) do
        local header = container.groupHeaders[i]
        if i <= numGroups then
            if not header then
                header = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                header:SetJustifyH("CENTER")
                container.groupHeaders[i] = header
            end
            local outline = (db.raidGroupOutline ~= false) and "OUTLINE" or ""
            local fontFile, fontSize = header:GetFont()
            if db.textFont then
                fontFile = ResolveFontPath(db.textFont)
                fontSize = 12
            end
            header:SetFont(fontFile, fontSize, outline)
            local groupIndex = i - 1
            local col = groupIndex % maxGroups
            local rowOffset = math.floor(groupIndex / maxGroups) * ppg
            
            header:SetText("Group " .. i)
            header:ClearAllPoints()
            header:SetPoint("BOTTOM", container, "TOPLEFT", (col * (width + spacing)) + (width / 2), -(rowOffset * (height + spacing)) - 6)
            header:Show()
        elseif header then
            header:Hide()
        end
    end
end

function Mod:GetOwnGroupContainerSize(mode, count)
    local db = self:GetModeDB(mode)
    local rows = math.max(1, tonumber(count) or tonumber(db.raidPlayersPerRow) or 5)
    local w = (tonumber(db.frameWidth) or 125) * (tonumber(db.frameScale) or 1)
    local h = (tonumber(db.frameHeight) or 64) * (tonumber(db.frameScale) or 1)
    local spacing = tonumber(db.frameSpacing) or 2
    local auraReserve = GetExternalAuraReserve(db, mode)
    return w, (rows * (h + auraReserve)) + ((rows - 1) * spacing) + 18
end

function Mod:UpdateOwnGroupHeader(container, mode, units)
    if not container then return end
    container.ownGroupHeader = container.ownGroupHeader or container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local header = container.ownGroupHeader
    local db = self:GetModeDB(mode)
    local width = (tonumber(db.frameWidth) or 125) * (tonumber(db.frameScale) or 1)
    local outline = (db.raidGroupOutline ~= false) and "OUTLINE" or ""
    local fontFile, fontSize = header:GetFont()
    if db.textFont then
        fontFile = ResolveFontPath(db.textFont)
        fontSize = 12
    end
    header:SetFont(fontFile, fontSize, outline)
    header:SetJustifyH("CENTER")
    header:SetText(units and units.subgroup and ("Your Group " .. tostring(units.subgroup)) or "Your Group")
    header:ClearAllPoints()
    header:SetPoint("BOTTOM", container, "TOPLEFT", width / 2, -6)
    header:Show()
end

function Mod:ApplyOwnGroupLayout(mode, units, visible)
    mode = NormalizeMode(mode)
    if not IsRaidMode(mode) then return end

    local container = self.ownGroupContainers and self.ownGroupContainers[mode]
    local frames = self.ownGroupFrames and self.ownGroupFrames[mode]
    if not (container and frames) then return end

    units = units or {}
    local shouldShow = visible and #units > 0
    local layoutCount = math.max(tonumber(units.layoutCount) or 0, #units)
    if shouldShow then
        local width, height = self:GetOwnGroupContainerSize(mode, layoutCount)
        container:SetSize(math.max(40, width), math.max(24, height))
        self:ApplyOwnGroupPosition(mode)
        self:UpdateOwnGroupHeader(container, mode, units)
    elseif container.ownGroupHeader then
        container.ownGroupHeader:Hide()
    end

    for index, frame in ipairs(frames) do
        local unit = units[index]
        if shouldShow and unit then
            local slot = type(unit) == "table" and unit.slot or index
            self:PositionFrame(frame, container, slot, layoutCount, mode, nil, "ownGroup")
            frame.mode = mode
            self:SetFrameUnit(frame, unit)
            frame:Show()
            self:UpdateFrameVisual(frame)
        else
            self:SetFrameUnit(frame, nil)
            self:ClearFrameAuras(frame)
            frame:Hide()
        end
    end

    container:SetShown(shouldShow)
end

function Mod:ApplyLayout(mode)
    mode = NormalizeMode(mode)
    if InCombatLockdown and InCombatLockdown() then
        self.pendingLayout[mode] = true
        return false, "combat"
    end

    self:EnsureDB()
    self:CreateContainers()
    self:CreateUnitFrames()

    local units = self:GetUnits(mode)
    local ownGroupUnits = self:GetOwnGroupUnits(mode)
    local container = self.containers[mode]
    local frames = self.frames[mode]
    local layoutCount = self:GetLayoutCount(mode, units)
    local visibleLayoutCount = units.visibleLayoutCount or #units
    local width, height = self:GetContainerSize(mode, layoutCount)
    container:SetSize(math.max(40, width), math.max(24, height))
    self:ApplyPosition(mode)

    local visible = self:GetModeVisibility(mode)
    -- Restore an arena container hidden defensively during a previous BG.
    container:SetAlpha(1)
    local reserveSecureUnits = mode == 'arenaEnemy'
        and not self.testMode[mode]
        and self:GetModeDB(mode).enabled ~= false
    for index, frame in ipairs(frames) do
        local unit = units[index]
        if (visible or reserveSecureUnits) and unit then
            local slot = type(unit) == "table" and unit.slot or index
            self:PositionFrame(frame, container, slot, layoutCount, mode, visibleLayoutCount)
            frame.mode = mode
            self:SetFrameUnit(frame, unit)
            if mode == 'arenaEnemy' and not frame.fakeUnit then
                -- During arena preparation specs are public before arenaN exists.
                -- Keep the announced slots visible; unit data fills in at the gate.
                frame:SetShown(visible and index <= layoutCount)
            else
                frame:Show()
            end
            self:UpdateFrameVisual(frame)
        else
            self:SetFrameUnit(frame, nil)
            self:ClearFrameAuras(frame)
            frame:Hide()
        end
    end

    self:UpdateGroupHeaders(container, mode, layoutCount)
    container._ktRosterLayoutKey = table.concat({ tostring(layoutCount), tostring(visibleLayoutCount), visible and "1" or "0" }, ":")
    for _, frame in ipairs(frames) do
        frame._ktRosterUnitKey = self:GetRosterUnitKey(frame.fakeUnit or frame.unit)
    end
    -- Keep the enemy container prepared outside arenas; its children remain hidden
    -- until arena visibility is active, then show throughout the preparation phase.
    container:SetShown((visible and #units > 0) or reserveSecureUnits)
    self:ApplyOwnGroupLayout(mode, ownGroupUnits, visible)
    self:ArmAuraDurationDriver()
    ScheduleExternalPartyFramesRefresh()
    return true
end

-- GROUP_ROSTER_UPDATE is emitted in bursts and does not mean that every frame
-- system changed. Keep the expensive full rebuild for options/profile changes;
-- this path only touches the live mode and slots whose occupant changed.
function Mod:GetLiveRosterModes()
    if self:HasActiveTestMode() then
        for _, mode in ipairs(MODE_ORDER) do
            if self.testMode[mode] then return { mode } end
        end
    end
    local modes
    if self:IsArenaContext() then
        modes = { "arena", "arenaEnemy" }
    elseif IsInRaid and IsInRaid() then
        modes = { self:GetAccessibleGroupCount() > 25 and "raid40" or "raid" }
    else
        modes = { "party" }
    end
    if IsEncounterInProgress and IsEncounterInProgress() == true then
        modes[#modes + 1] = "boss"
    end
    return modes
end

function Mod:GetRosterUnitKey(unit)
    if type(unit) == "table" and unit.fake then
        return "fake:" .. tostring(unit.index or unit.slot or 0)
    end
    local token = type(unit) == "table" and unit.unit or unit
    if type(token) ~= "string" then return nil end
    if UnitGUID then
        local ok, guid = pcall(UnitGUID, token)
        if ok and guid and not IsSecretValue(guid) then return "guid:" .. tostring(guid) end
    end
    -- Unit tokens are a safe fallback while a PvP unit remains secret.
    return "unit:" .. token
end

function Mod:HideRosterMode(mode)
    local container = self.containers and self.containers[mode]
    if container then container:Hide() end
    local ownGroup = self.ownGroupContainers and self.ownGroupContainers[mode]
    if ownGroup then ownGroup:Hide() end
end

function Mod:RefreshRosterLayout(mode)
    mode = NormalizeMode(mode)
    if InCombatLockdown and InCombatLockdown() then
        self.pendingLayout[mode] = true
        return false, "combat"
    end
    local container = self.containers and self.containers[mode]
    local frames = self.frames and self.frames[mode]
    if not (container and frames) then return self:ApplyLayout(mode) end

    local units = self:GetUnits(mode)
    local visible = self:GetModeVisibility(mode)
    local layoutCount = self:GetLayoutCount(mode, units)
    local visibleLayoutCount = units.visibleLayoutCount or #units
    local layoutKey = table.concat({ tostring(layoutCount), tostring(visibleLayoutCount), visible and "1" or "0" }, ":")
    local layoutChanged = container._ktRosterLayoutKey ~= layoutKey
    local reserveSecureUnits = mode == "arenaEnemy" and not self.testMode[mode] and self:GetModeDB(mode).enabled ~= false

    if layoutChanged then
        local width, height = self:GetContainerSize(mode, layoutCount)
        container:SetSize(math.max(40, width), math.max(24, height))
        self:ApplyPosition(mode)
        container._ktRosterLayoutKey = layoutKey
    end
    container:SetAlpha(1)

    for index, frame in ipairs(frames) do
        local unit = units[index]
        if (visible or reserveSecureUnits) and unit then
            local slot = type(unit) == "table" and unit.slot or index
            local unitKey = self:GetRosterUnitKey(unit)
            local occupantChanged = frame._ktRosterUnitKey ~= unitKey
            if layoutChanged then self:PositionFrame(frame, container, slot, layoutCount, mode, visibleLayoutCount) end
            frame.mode = mode
            local token = type(unit) == "table" and unit.unit or unit
            if frame.unit ~= token or frame.fakeUnit ~= (type(unit) == "table" and unit.fake and unit or nil) then
                self:SetFrameUnit(frame, unit)
            end
            frame._ktRosterUnitKey = unitKey
            if occupantChanged and type(token) == "string" and self.auraCache then
                self.auraCache[token] = nil
            end
            if mode == "arenaEnemy" and not frame.fakeUnit then
                frame:SetShown(visible and index <= layoutCount)
            else
                frame:Show()
            end
            -- Existing occupants are updated by UNIT_* and UNIT_AURA; avoid
            -- re-styling every visible raid button on a roster notification.
            if occupantChanged then self:UpdateFrameVisual(frame) end
        elseif frame.unit or frame.fakeUnit or frame:IsShown() then
            self:SetFrameUnit(frame, nil)
            frame._ktRosterUnitKey = nil
            self:ClearFrameAuras(frame)
            frame:Hide()
        end
    end
    if layoutChanged then self:UpdateGroupHeaders(container, mode, layoutCount) end
    container:SetShown((visible and #units > 0) or reserveSecureUnits)
    self:ApplyOwnGroupLayout(mode, self:GetOwnGroupUnits(mode), visible)
    return true
end

function Mod:RefreshLiveRoster()
    if self.db and self.db.enable == false then return end
    if InCombatLockdown and InCombatLockdown() then
        self.pendingRoster = true
        return false, "combat"
    end
    self:EnsureDB()
    if not self.containers or not self.frames then
        self:CreateContainers()
        self:CreateUnitFrames()
    end
    local active = {}
    for _, mode in ipairs(self:GetLiveRosterModes()) do
        active[mode] = true
        self:RefreshRosterLayout(mode)
    end
    for _, mode in ipairs(MODE_ORDER) do
        if not active[mode] then self:HideRosterMode(mode) end
    end
    -- Seed range in the same pass (events alone are not guaranteed for freshly
    -- joined members), then keep the aura duration countdown alive.
    self:RefreshRangeAll()
    self:ArmAuraDurationDriver()
    self:EnforceSinglePartyFrameSystem()
    ScheduleExternalPartyFramesRefresh()
end

function Mod:GetLiveRosterSignature()
    local signature = {}
    local inInstance, instanceType = false, "none"
    if IsInInstance then
        inInstance, instanceType = IsInInstance()
    end
    signature[#signature + 1] = inInstance and "1" or "0"
    signature[#signature + 1] = tostring(instanceType or "none")
    signature[#signature + 1] = self._arenaContext and "arena" or "world"
    for _, mode in ipairs(self:GetLiveRosterModes()) do
        local units = self:GetUnits(mode)
        signature[#signature + 1] = mode
        signature[#signature + 1] = tostring(units.layoutCount or #units)
        signature[#signature + 1] = tostring(units.visibleLayoutCount or #units)
        for index, unit in ipairs(units) do
            signature[#signature + 1] = tostring(index)
            signature[#signature + 1] = self:GetRosterUnitKey(unit) or "-"
        end
    end
    return table.concat(signature, "|")
end

function Mod:RefreshWorldRosterIfChanged(refreshToken, force)
    if refreshToken and refreshToken ~= self._worldRefreshToken then return false end
    local signature = self:GetLiveRosterSignature()
    if not force and signature == self._worldRosterSignature then return false end
    self._worldRosterSignature = signature
    local refreshed = self:RefreshLiveRoster()
    if refreshed ~= false then
        self._worldRosterSignature = self:GetLiveRosterSignature()
    end
    return refreshed ~= false
end

function Mod:RefreshAll()
    if self.db and self.db.enable == false then return end
    self.auraCache = {}
    self:EnforceSinglePartyFrameSystem()
    for _, mode in ipairs(MODE_ORDER) do
        self:ApplyLayout(mode)
    end
    self:UpdateTestAnimationState()
end

function Mod:OnEncounterStateChanged()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingRosterModes = self.pendingRosterModes or {}
        self.pendingRosterModes.boss = true
        return
    end
    self:RefreshRosterLayout("boss")
end

function Mod:OnGroupRosterUpdate()
    -- Rebuild the per-unit event registrations immediately so UNIT_* events are
    -- not missed between the roster change and the coalesced UI refresh below.
    self:RebuildRosterEvents()
    -- Coalesce the burst, then update only the pool used by the current mode.
    self._rosterRefreshToken = (self._rosterRefreshToken or 0) + 1
    local token = self._rosterRefreshToken
    C_Timer.After(0.08, function()
        if token ~= self._rosterRefreshToken then return end
        self:RefreshLiveRoster()
        self._worldRosterSignature = self:GetLiveRosterSignature()
    end)
    -- Rank data can settle after the unit tokens/layout. Re-read indicators
    -- after both phases so raid and raid40 do not miss assistant promotions.
    C_Timer.After(0.20, function()
        if token ~= self._rosterRefreshToken then return end
        self:RefreshAllIndicators()
    end)
    C_Timer.After(0.75, function()
        if token ~= self._rosterRefreshToken then return end
        self:RefreshAllIndicators()
    end)
end

function Mod:OnPlayerEnteringWorld()
    self:RebuildRosterEvents()
    self._worldRefreshToken = (self._worldRefreshToken or 0) + 1
    local refreshToken = self._worldRefreshToken
    local inArena = self:IsArenaContext(true)
    self._arenaContext = inArena and true or nil
    self:ResetArenaTrackers()
    local inInstance = IsInInstance and IsInInstance()
    local hasInstanceGroup = false
    if _G.IsInGroup then
        local groupOK, grouped = pcall(_G.IsInGroup, _G.LE_PARTY_CATEGORY_INSTANCE or 2)
        hasInstanceGroup = groupOK and grouped == true
    end
    if inInstance or hasInstanceGroup then
        -- Never carry preview/test rosters into live PvP or instance content.
        for _, mode in ipairs(MODE_ORDER) do
            self.testMode[mode] = nil
        end
    end
    if inArena then
        for _, frame in ipairs((self.frames and self.frames.arenaEnemy) or {}) do
            frame._arenaSpecIcon = nil
            frame._arenaSpecName = nil
        end
    end
    self:ApplyCurrentSpecProfile()
    self:RefreshWorldRosterIfChanged(refreshToken, false)
    if C_Timer and C_Timer.After then
        -- Instance-category rosters are populated asynchronously while zoning.
        C_Timer.After(0.25, function()
            self:RefreshWorldRosterIfChanged(refreshToken, false)
        end)
        C_Timer.After(1.00, function()
            self:RefreshWorldRosterIfChanged(refreshToken, false)
        end)
    end
    if inArena and C_Timer and C_Timer.After then
        -- Opponent units arrive during preparation; retry before secure combat lock.
        C_Timer.After(0.10, function() self:OnArenaRosterUpdate() end)
        C_Timer.After(0.50, function() self:OnArenaRosterUpdate() end)
        C_Timer.After(1.00, function() self:OnArenaRosterUpdate() end)
    end
end

function Mod:OnArenaRosterUpdate(event)
    if event == 'ARENA_PREP_OPPONENT_SPECIALIZATIONS' or event == 'ARENA_OPPONENT_UPDATE' then
        local confirmedArena = self:IsArenaContext(true)
        self._arenaContext = confirmedArena and true or nil
        if not confirmedArena then
            if not (InCombatLockdown and InCombatLockdown()) then
                self:RefreshLiveRoster()
            elseif self.containers and self.containers.arenaEnemy then
                self.containers.arenaEnemy:SetAlpha(0)
            end
            return
        end
        for _, mode in ipairs(MODE_ORDER) do
            self.testMode[mode] = nil
        end
    end
    if InCombatLockdown and InCombatLockdown() then
        -- Unit attributes were prepared on entry. During combat only repaint;
        -- protected layout changes would otherwise be delayed until match end.
        for _, mode in ipairs({ 'arena', 'arenaEnemy' }) do
            for _, frame in ipairs((self.frames and self.frames[mode]) or {}) do
                if frame.unit then
                    self:UpdateFrameVisual(frame)
                end
            end
        end
        self:OnArenaCooldownUpdate()
        return
    end
    -- Re-evaluate the live pools so layouts from the previous context are
    -- hidden as soon as arena preparation establishes the final roster.
    self:RefreshLiveRoster()
    self:OnArenaCooldownUpdate()
    -- Blizzard and external frame providers process the same preparation event.
    -- Reassert suppression after their handlers have had a chance to Show().
    if self._arenaContext and C_Timer and C_Timer.After then
        C_Timer.After(0, function() self:EnforceSinglePartyFrameSystem() end)
        C_Timer.After(0.20, function() self:EnforceSinglePartyFrameSystem() end)
    end
end

function Mod:OnAddonLoaded(_, addonName)
    if addonName == "KullThranUI_UnitFrames"
        or addonName == "Blizzard_CompactRaidFrames"
        or addonName == "DandersFrames"
        or addonName == "DandersFramers" then
        C_Timer.After(0, function()
            self:EnforceSinglePartyFrameSystem()
        end)
        C_Timer.After(1, function()
            self:EnforceSinglePartyFrameSystem()
        end)
    end
    -- Hook BliZzi when it finishes loading (handles the case where BliZzi loads
    -- after KUI; the immediate call in InstallExternalPartyFramesAPI handles the
    -- reverse load order).
    if addonName == "BliZzi_Interrupts" then
        InstallBliZziHook()
    end
end

function Mod:OnSpecChanged()
    self.auraCache = {}
    for _, mode in ipairs(MODE_ORDER) do
        for _, frame in ipairs(self.frames[mode] or {}) do
            frame._ktInRange = nil
            frame._ktOutOfRange = false
        end
    end
    for _, mode in ipairs({ "raid", "raid40" }) do
        for _, frame in ipairs((self.ownGroupFrames and self.ownGroupFrames[mode]) or {}) do
            frame._ktInRange = nil
            frame._ktOutOfRange = false
        end
    end
    self:ApplyCurrentSpecProfile()
    self:RefreshRangeAll()
end

function Mod:UpdateFrameHealthEvent(frame)
    local unit = frame and frame.unit
    if not unit or frame.fakeUnit or not IsUnitUsable(unit) then
        self:UpdateFrameVisual(frame, false)
        return
    end

    -- Death and reconnect transitions also affect alpha, status text, auras
    -- and colors. Escalate only those transitions to the complete painter.
    local isDead = SafeUnitBoolean(UnitIsDeadOrGhost, unit)
    local isConnected = SafeUnitBoolean(UnitIsConnected, unit)
    if frame._ktEventDead == nil
        or frame._ktEventDead ~= isDead
        or frame._ktEventConnected ~= isConnected then
        frame._ktEventDead = isDead
        frame._ktEventConnected = isConnected
        self:UpdateFrameVisual(frame, false)
        return
    end
    if isDead or isConnected == false then return end

    local db = self:GetModeDB(frame.mode or "party")
    local hpPercent = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
    frame.health:SetValue(hpPercent)
    SetHealthText(frame.valueText, unit, db, hpPercent)
end

function Mod:UpdateFramePowerEvent(frame, event)
    local unit = frame and frame.unit
    if not unit or frame.fakeUnit or not IsUnitUsable(unit) then
        self:UpdateFrameVisual(frame, false)
        return
    end
    local db = self:GetModeDB(frame.mode or "party")
    if SafeUnitBoolean(UnitIsDeadOrGhost, unit)
        or SafeUnitBoolean(UnitIsConnected, unit) == false then
        return
    end
    local power = UnitPower and UnitPower(unit)
    local maxPower = UnitPowerMax and UnitPowerMax(unit)
    if db.showPowerBar == false or IsSecretValue(power) or IsSecretValue(maxPower)
        or type(power) ~= "number" or type(maxPower) ~= "number" then
        frame.power:Hide()
        frame._ktPowerMax = nil
        return
    end
    if event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" or frame._ktPowerMax ~= maxPower then
        frame.power:SetMinMaxValues(0, maxPower)
        frame._ktPowerMax = maxPower
    end
    frame.power:SetValue(power)
    frame.power:Show()
    if event == "UNIT_DISPLAYPOWER" then
        local pr, pg, pb = GetPowerColor()
        frame.power:SetStatusBarColor(pr, pg, pb, 0.9)
    end
end

function Mod:UpdateFrameAbsorbEvent(frame)
    local unit = frame and frame.unit
    if not unit or frame.fakeUnit or not IsUnitUsable(unit) then
        self:UpdateFrameVisual(frame, false)
        return
    end
    local db = self:GetModeDB(frame.mode or "party")
    if db.showAbsorbBar == false or not frame.absorb or not UnitGetTotalAbsorbs or not UnitHealthMax then
        if frame.absorb then frame.absorb:Hide() end
        frame._ktAbsorbMax = nil
        frame._ktAbsorbValue = nil
        return
    end

    local maxHealth = UnitHealthMax(unit, true)
    local amount = UnitGetTotalAbsorbs(unit)
    local maxSecret = IsSecretValue(maxHealth)
    local amountSecret = IsSecretValue(amount)
    if maxSecret or frame._ktAbsorbMax ~= maxHealth then
        frame.absorb:SetMinMaxValues(0, maxHealth)
        if maxSecret then frame._ktAbsorbMax = nil else frame._ktAbsorbMax = maxHealth end
    end
    if amountSecret or frame._ktAbsorbValue ~= amount then
        frame.absorb:SetValue(amount)
        if amountSecret then frame._ktAbsorbValue = nil else frame._ktAbsorbValue = amount end
    end
    frame.absorb:Show()
end

function Mod:OnUnitEvent(event, unit)
    if not unit then return end
    -- The unit event frame already tells us the exact token. Do not scan all
    -- mode pools to rediscover it, and do not repaint unrelated elements for
    -- high-frequency health/power events.
    local frames = self._auraUnitFrames and self._auraUnitFrames[unit]
    if not frames then return end
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileName = (event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH") and "party.health.paint"
        or (event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER") and "party.power.paint"
        or "party.identity.paint"
    local profileStarted = profiler and profiler:Begin(profileName)
    for i = 1, #frames do
        local frame = frames[i]
        if frame and frame:IsShown() then
            if event == "UNIT_HEALTH" then
                self:UpdateFrameHealthEvent(frame)
            elseif event == "UNIT_MAXHEALTH" then
                self:UpdateFrameHealthEvent(frame)
                self:UpdateFrameAbsorbEvent(frame)
            elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" or event == "UNIT_DISPLAYPOWER" then
                self:UpdateFramePowerEvent(frame, event)
            elseif event == "UNIT_NAME_UPDATE" and frame.unit and IsUnitUsable(frame.unit) then
                frame.nameText:SetText(FitText(MakeUnitLabel(frame.unit), frame._nameMaxChars))
            else
                self:UpdateFrameVisual(frame, true)
            end
        end
    end
    if profileStarted then profiler:End(profileName, profileStarted) end
end

function Mod:FlushUnitAbsorbs(unit)
    local frames = self._auraUnitFrames and self._auraUnitFrames[unit]
    if not frames then return end
    for i = 1, #frames do
        local frame = frames[i]
        if frame and frame:IsShown() then
            self:UpdateFrameAbsorbEvent(frame)
        end
    end
end

function Mod:OnUnitAbsorb(event, unit)
    if not unit then return end
    self._pendingAbsorbUnits = self._pendingAbsorbUnits or {}
    self._pendingAbsorbUnits[unit] = true
    if not self._absorbFlushQueued then
        self._absorbFlushQueued = true
        ns.PF_AbsorbFlushDriver:Show()
    end
end

function Mod:FlushUnitAuras(unit)
    if self.auraCache then
        self.auraCache[unit] = nil
    end
    local frames = self._auraUnitFrames and self._auraUnitFrames[unit]
    if frames then
        for i = 1, #frames do
            local frame = frames[i]
            if frame:IsShown() then
                self:UpdateFrameAuras(frame)
            end
        end
    end
end

function Mod:OnUnitAura(event, unit)
    if not unit then return end

    -- The UNIT_AURA updateInfo payload and its nested lists can be protected in
    -- PvP. Do not inspect or iterate them at all. Native 12.1 AuraContainers
    -- process automatically in C++; we only flush custom UI elements (missing
    -- buffs, arena trackers). The flush is coalesced per unit per rendered
    -- frame to avoid rescanning the same unit on every UNIT_AURA burst in a
    -- large raid (see ns.PF_AuraFlushDriver above).
    if not Mod._pendingAuraUnits then Mod._pendingAuraUnits = {} end
    Mod._pendingAuraUnits[unit] = true
    if not Mod._auraFlushQueued then
        Mod._auraFlushQueued = true
        ns.PF_AuraFlushDriver:Show()
    end
end

function Mod:RefreshAllIndicators()
    for _, mode in ipairs(MODE_ORDER) do
        for _, frame in ipairs(self.frames[mode] or {}) do
            if frame:IsShown() then
                self:UpdateFrameIndicators(frame, frame.fakeUnit and GetTestUnitData(frame.fakeUnit, frame.mode or mode) or nil)
            end
        end
    end
    for _, mode in ipairs({ "raid", "raid40" }) do
        for _, frame in ipairs((self.ownGroupFrames and self.ownGroupFrames[mode]) or {}) do
            if frame:IsShown() then
                self:UpdateFrameIndicators(frame, frame.fakeUnit and GetTestUnitData(frame.fakeUnit, frame.mode or mode) or nil)
            end
        end
    end
end

function Mod:OnRaidTargetUpdate()
    self:RefreshAllIndicators()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, function()
            self:RefreshAllIndicators()
        end)
    end
end

function Mod:PLAYER_REGEN_ENABLED()
    if self.pendingExternalFrameHide then
        self.pendingExternalFrameHide = nil
        self:EnforceSinglePartyFrameSystem()
    end
    if self.pendingPresetKey then
        local presetKey = self.pendingPresetKey
        self.pendingPresetKey = nil
        self:ApplyPreset(presetKey, true)
        return
    end
    if self.pendingAll then
        self.pendingAll = nil
        self:RefreshAll()
        return
    end
    if self.pendingRoster then
        self.pendingRoster = nil
        self:RefreshLiveRoster()
    end
    if self:CanIterateTable(self.pendingRosterModes) then
        for mode in pairs(self.pendingRosterModes) do
            self.pendingRosterModes[mode] = nil
            self:RefreshRosterLayout(mode)
        end
    end
    if not self:CanIterateTable(self.pendingLayout) then return end
    for mode in pairs(self.pendingLayout) do
        self.pendingLayout[mode] = nil
        self:ApplyLayout(mode)
    end
end

function Mod:PLAYER_REGEN_DISABLED()
    if not GameTooltip or GameTooltip:IsForbidden() then return end
    local owner = GameTooltip:GetOwner()
    if owner and owner._ktPartyFrame then
        GameTooltip:Hide()
    end
end

function Mod:SetTestMode(mode, enabled)
    mode = NormalizeMode(mode)
    if InCombatLockdown and InCombatLockdown() then
        return false, "combat"
    end
    self.testAuraSeeds = self.testAuraSeeds or {}
    if enabled then
        -- Test layouts are mutually exclusive; otherwise raid samples can remain
        -- visible over an arena preview and look like the live arena layout.
        for _, otherMode in ipairs(MODE_ORDER) do
            self.testMode[otherMode] = nil
        end
        self.testAuraSeeds[mode] = math.random(1, 100000)
    end
    self.testMode[mode] = enabled and true or nil
    self.auraCache = {}
    self:RefreshAll()
    self:UpdateTestAnimationState()
    return true
end

function Mod:RandomizeTestAuras(mode)
    mode = NormalizeMode(mode)
    self.testAuraSeeds = self.testAuraSeeds or {}
    self.testAuraSeeds[mode] = math.random(1, 100000)
    self.auraCache = {}
    if self.testMode and self.testMode[mode] then
        self:ApplyLayout(mode)
    end
    return true
end

function Mod:IsTestMode(mode)
    mode = NormalizeMode(mode)
    return self.testMode and self.testMode[mode] == true
end

function Mod:ToggleTestMode(mode)
    mode = NormalizeMode(mode)
    return self:SetTestMode(mode, not self:IsTestMode(mode))
end

function Mod:HideAllTests()
    if InCombatLockdown and InCombatLockdown() then return false, "combat" end
    for _, mode in ipairs(MODE_ORDER) do
        self.testMode[mode] = nil
    end
    self:RefreshAll()
    self:UpdateTestAnimationState()
    return true
end

function Mod:HasActiveTestMode()
    for _, mode in ipairs(MODE_ORDER) do
        if self.testMode and self.testMode[mode] then
            return true
        end
    end
    return false
end

function Mod:UpdateTestFrames()
    for _, mode in ipairs(MODE_ORDER) do
        if self.testMode and self.testMode[mode] then
            for _, frame in ipairs(self.frames[mode] or {}) do
                if frame:IsShown() and frame.fakeUnit then
                    self:UpdateFrameVisual(frame, false)
                end
            end
            for _, frame in ipairs((self.ownGroupFrames and self.ownGroupFrames[mode]) or {}) do
                if frame:IsShown() and frame.fakeUnit then
                    self:UpdateFrameVisual(frame, false)
                end
            end
        end
    end
end

function Mod:UpdateTestAnimationState()
    if self:HasActiveTestMode() then
        if self.testAnimationTicker or not C_Timer then return end
        self.testAnimationPhase = 0
        self.testAnimationTicker = C_Timer.NewTicker(0.05, function()
            self.testAnimationPhase = ((self.testAnimationPhase or 0) + 0.02) % 1
            self:UpdateTestFrames()
        end)
    elseif self.testAnimationTicker then
        self.testAnimationTicker:Cancel()
        self.testAnimationTicker = nil
        self.testAnimationPhase = 0
    end
end

function Mod:HighlightVisibleFrames()
    local function HighlightFrame(frame)
        if frame:IsShown() then
            frame:SetAlpha(1)
            if frame.hover then
                frame.hover:SetColorTexture(1, 1, 1, 0.24)
                frame.hover:Show()
                C_Timer.After(0.35, function()
                    if frame and frame.hover then
                        frame.hover:SetColorTexture(1, 1, 1, 0.08)
                    end
                end)
            end
        end
    end

    for _, mode in ipairs(MODE_ORDER) do
        for _, frame in ipairs(self.frames[mode] or {}) do
            HighlightFrame(frame)
        end
    end
    for _, mode in ipairs({ "raid", "raid40" }) do
        for _, frame in ipairs((self.ownGroupFrames and self.ownGroupFrames[mode]) or {}) do
            HighlightFrame(frame)
        end
    end
    return true
end

function Mod:GetRosterSnapshot(mode)
    mode = NormalizeMode(mode)
    local rows = {}
    local units = self:GetUnits(mode)
    for _, unit in ipairs(units) do
        if type(unit) == "table" then
            if unit.fake then
                local data = GetTestUnitData(unit, mode)
                rows[#rows + 1] = {
                    unit = unit.isPlayer and "player" or (mode .. tostring(unit.index or 1)),
                    name = data.name or "",
                    role = data.role or "",
                }
            elseif IsUnitUsable(unit.unit) then
                local role = GetAccessibleUnitRole(unit.unit)
                rows[#rows + 1] = {
                    unit = unit.unit,
                    name = MakeUnitLabel(unit.unit),
                    role = role ~= "NONE" and role or "",
                }
            end
        elseif IsUnitUsable(unit) then
            local role = GetAccessibleUnitRole(unit)
            rows[#rows + 1] = {
                unit = unit,
                name = MakeUnitLabel(unit),
                role = role ~= "NONE" and role or "",
            }
        end
    end
    return rows
end

function Mod:LoadPosition(mode)
    self:EnsureDB()
    return CopyPosition(self.db.positions[self:NormalizePositionKey(mode)])
end

function Mod:SavePosition(mode, point, relativePoint, x, y, scale)
    self:EnsureDB()
    mode = self:NormalizePositionKey(mode)
    self.db.positions[mode] = self.db.positions[mode] or {}
    self.db.positions[mode].point = point
    self.db.positions[mode].relativePoint = relativePoint
    self.db.positions[mode].x = x
    self.db.positions[mode].y = y
    self.db.positions[mode].scale = scale
    local presetKey = self.db.activePreset
    if presetKey then
        self.db.profilePositions = self.db.profilePositions or {}
        self.db.profilePositions[presetKey] = self.db.profilePositions[presetKey] or {}
        self.db.profilePositions[presetKey][mode] = CopyPosition(self.db.positions[mode])
    end
end

function Mod:ApplyPosition(mode)
    if InCombatLockdown and InCombatLockdown() then return end
    mode = NormalizeMode(mode)
    local frame = self.containers and self.containers[mode]
    if not frame then return end
    local pos = self:LoadPosition(mode)
    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function Mod:ApplyOwnGroupPosition(mode)
    if InCombatLockdown and InCombatLockdown() then return end
    mode = NormalizeMode(mode)
    local frame = self.ownGroupContainers and self.ownGroupContainers[mode]
    local positionKey = self:GetOwnGroupPositionKey(mode)
    if not (frame and positionKey) then return end
    local pos = self:LoadPosition(positionKey)
    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

function Mod:RegisterUnlockElements()
    if self.elementsRegistered or not KT.RegisterMovableElements then return end

    local labels = {
        party = "Party Frames - Party",
        raid = "Party Frames - Raid",
        raidOwnGroup = "Party Frames - Own Group",
        arena = "Party Frames - Arena",
        arenaEnemy = "Party Frames - Arena Enemies",
    }
    local elements = {}
    for index, mode in ipairs(MODE_ORDER) do
        elements[#elements + 1] = {
            key = "PARTYFRAMES_" .. mode:upper(),
            label = labels[mode],
            group = "Party Frames",
            order = 20 + index,
            getFrame = function()
                return self.containers[mode]
            end,
            getSize = function()
                local frame = self.containers[mode]
                if frame then return frame:GetSize() end
                return self:GetContainerSize(mode)
            end,
            isHidden = function()
                local frame = self.containers[mode]
                return not (frame and frame:IsShown())
            end,
            loadPosition = function()
                return self:LoadPosition(mode)
            end,
            savePosition = function(_, point, relativePoint, x, y, scale)
                self:SavePosition(mode, point, relativePoint, x, y, scale)
            end,
            applyPosition = function()
                self:ApplyPosition(mode)
            end,
        }
    end
    for index, mode in ipairs({ "raid", "raid40" }) do
        local positionKey = self:GetOwnGroupPositionKey(mode)
        elements[#elements + 1] = {
            key = "PARTYFRAMES_" .. mode:upper() .. "_OWN_GROUP",
            label = mode == "raid40" and "Party Frames - Own Group (Raid 40)" or labels.raidOwnGroup,
            group = "Party Frames",
            order = 30 + index,
            getFrame = function()
                return self.ownGroupContainers and self.ownGroupContainers[mode]
            end,
            getSize = function()
                local frame = self.ownGroupContainers and self.ownGroupContainers[mode]
                if frame then return frame:GetSize() end
                return self:GetOwnGroupContainerSize(mode)
            end,
            isHidden = function()
                local frame = self.ownGroupContainers and self.ownGroupContainers[mode]
                return not (frame and frame:IsShown())
            end,
            loadPosition = function()
                return self:LoadPosition(positionKey)
            end,
            savePosition = function(_, point, relativePoint, x, y, scale)
                self:SavePosition(positionKey, point, relativePoint, x, y, scale)
            end,
            applyPosition = function()
                self:ApplyOwnGroupPosition(mode)
            end,
        }
    end

    KT:RegisterMovableElements(elements)
    self.elementsRegistered = true
end


-- Centralized Aura Duration Update.
-- Driven by Mod:ArmAuraDurationDriver(): an OnUpdate that runs only while at
-- least one unit frame is shown and disarms itself once the last one hides,
-- replacing the permanent 0.2s C_Timer.NewTicker. Returns whether any frame is
-- still visible so the driver can keep itself alive.
Mod.CentralAuraUpdate = function()
    local active = Mod._durationIcons
    if not active then return false end

    local anyActive = false
    local now = _G.GetTime and _G.GetTime() or 0
    for icon in pairs(active) do
        local expirationTime = icon._auraExpirationTime
        if icon:IsShown() and icon._updateDurationText
            and expirationTime and expirationTime > 0 then
            icon:_updateDurationText()
            if expirationTime > now then
                anyActive = true
            else
                active[icon] = nil
            end
        else
            active[icon] = nil
        end
    end
    return anyActive
end
