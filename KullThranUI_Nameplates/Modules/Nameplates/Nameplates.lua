local addon, ns = ...

local PP = KullThranUI.PP
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local C_UnitAuras_GetAuraAppDisplayCount = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount
local C_UnitAuras_GetAuraDuration = C_UnitAuras and C_UnitAuras.GetAuraDuration

-- Forever rejects derived target tokens and group-unit tokens such as
-- targettarget, focustarget, party1 and raid1 in
-- C_NamePlate.GetNamePlateForUnit. Those units can still produce UNIT_LEVEL
-- and similar events, so resolve only supported tokens and fail safely.
local function GetSafeNamePlateForUnit(unit)
    if type(unit) ~= "string"
        or unit == "targettarget"
        or unit == "focustarget"
        or unit:match("^party%d+$")
        or unit:match("^raid%d+$")
        or unit:match("^partypet%d+$")
        or unit:match("^raidpet%d+$") then
        return nil
    end
    if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then
        return nil
    end

    local ok, nameplate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok then
        return nil
    end
    return nameplate
end
ns.IsAccessibleValue = ns.IsAccessibleValue or function(value)
    if issecretvalue and issecretvalue(value) then return false end
    if canaccessvalue and not canaccessvalue(value) then return false end
    return true
end
ns.CanIterateTable = ns.CanIterateTable or function(value)
    if value == nil then return true end
    if type(value) ~= "table" or not ns.IsAccessibleValue(value) then return false end
    if issecrettable then
        local ok, secret = pcall(issecrettable, value)
        if not ok or secret then return false end
    end
    return pcall(next, value)
end
function ns.IsEnemyNameplateUnit(unit, nameplate)
    if not unit then return false end
    local ok, canAttack = pcall(UnitCanAttack, "player", unit)
    if ok and ns.IsAccessibleValue(canAttack) then
        return canAttack == true
    end
    local uf = nameplate and nameplate.UnitFrame
    local isFriend = uf and uf.isFriend
    if ns.IsAccessibleValue(isFriend) and type(isFriend) == "boolean" then
        return isFriend ~= true
    end
    return false
end
function ns.IsPlayerNameplateUnit(unit, nameplate)
    if not unit then return false end
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if ok and ns.IsAccessibleValue(isPlayer) then
        return isPlayer == true
    end
    local uf = nameplate and nameplate.UnitFrame
    local nativeValue = uf and uf.isPlayer
    return ns.IsAccessibleValue(nativeValue)
        and type(nativeValue) == "boolean"
        and nativeValue == true
end
ns.DEFAULT_FONT_PATH = ns.DEFAULT_FONT_PATH or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"

function ns.ResolveNameplateFont(fontValue)
    local core = ns.KT or _G.KT or KullThranUI
    local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
    local fallback = (core and core.ResolveFontPath and core:ResolveFontPath())
        or (core and core.FONT_PATH)
        or ns.DEFAULT_FONT_PATH

    -- Korean, Chinese and Russian need a font with their script: a saved font
    -- that cannot draw it (Avant Garde) gives way to the core's localized font.
    if core and core.IsNonLatinLocale and core:IsNonLatinLocale() and core.IsFontCompatibleWithLocale
        and type(fontValue) == "string" and fontValue ~= "" and not core:IsFontCompatibleWithLocale(fontValue) then
        return fallback
    end

    if type(fontValue) == "string" and fontValue ~= "" then
        if lsm then
            local fetched = lsm:Fetch("font", fontValue, true)
            if fetched then
                return fetched
            end
            for _, name in ipairs(lsm:List("font")) do
                local registeredPath = lsm:Fetch("font", name, true)
                if registeredPath == fontValue then
                    return fontValue
                end
            end
        end

        local normalized = fontValue:gsub("/", "\\"):lower()
        if not normalized:find("interface\\addons\\", 1, true) then
            return fontValue
        end
    end

    return fallback
end
-- Getters de configuración: cada función lee un valor de KullThranUINameplatesDB
-- con fallback a `defaults`. Patrón estándar: DB and DB.key or defaults.key.
-- Se exportan a ns.* para acceso cruzado desde otros módulos (Options, Friendly).
local function GetFont()
    local core = ns.KT or _G.KT or KullThranUI
    if core and core.GetNPFontPath then
        return core.GetNPFontPath("nameplates")
    end
    return ns.ResolveNameplateFont(KullThranUINameplatesDB and KullThranUINameplatesDB.font or defaults.font)
end
local function GetNPOutline()
    return (KullThranUI and KullThranUI.GetFontOutlineFlag and KullThranUI.GetFontOutlineFlag()) or "OUTLINE"
end
local function GetNPUseShadow()
    return not KullThranUI or not KullThranUI.GetFontUseShadow or KullThranUI.GetFontUseShadow()
end
ns.IsInFollowerDungeon = function()
    local lfg = C_LFGInfo
    if lfg and lfg.IsInLFGFollowerDungeon and lfg.IsInLFGFollowerDungeon() then
        return true
    end
    -- Follower dungeons report difficulty 208 from GetInstanceInfo.
    return select(3, GetInstanceInfo()) == 208
end
local FRIENDLY_INSTANCE_MODES = {
    name_only = true,
    always = true,
    never = true,
}

local function IsRelevantFriendlyInstance()
    if ns.IsInFollowerDungeon and ns.IsInFollowerDungeon() then
        return true
    end
    if type(IsInInstance) ~= "function" then
        return false
    end
    local ok, inInstance, instanceType = pcall(IsInInstance)
    if not ok or inInstance ~= true then
        return false
    end
    -- Do not change friendly nameplates in battlegrounds or arenas. The
    -- instance policy is intended for dungeons, raids and scenarios/delves.
    return instanceType == "party"
        or instanceType == "raid"
        or instanceType == "scenario"
end

local function GetFriendlyInstanceMode(isPlayer)
    local db = KullThranUINameplatesDB or {}
    local key = isPlayer and "friendlyPlayersInInstances" or "friendlyNPCsInInstances"
    local mode = db[key]
    if not FRIENDLY_INSTANCE_MODES[mode] then
        mode = "name_only"
    end
    if not IsRelevantFriendlyInstance() then
        return nil
    end
    return mode
end

function ns.IsRelevantFriendlyInstance()
    return IsRelevantFriendlyInstance()
end

function ns.GetFriendlyInstanceMode(isPlayer)
    return GetFriendlyInstanceMode(isPlayer)
end

function ns.GetEffectiveFriendlyNameOnly(isPlayer)
    local mode = GetFriendlyInstanceMode(isPlayer)
    if mode == "name_only" then
        return true
    elseif mode == "always" then
        return false
    end

    local db = KullThranUINameplatesDB or {}
    local key = isPlayer and "friendlyPlayerNameOnly" or "friendlyNPCNameOnly"
    if db[key] ~= nil then
        return db[key] ~= false
    end
    return db.friendlyNameOnly ~= false
end

function ns.ShouldShowFriendlyNameplates(isPlayer)
    local mode = GetFriendlyInstanceMode(isPlayer)
    if mode == "never" then
        return false
    end

    local db = KullThranUINameplatesDB or {}
    if isPlayer then
        return db.showFriendlyPlayers ~= false
    end
    return db.showFriendlyNPCs == true
end
local function SetFSFont(fs, size, flags)
    if not fs or not fs.SetFont then
        return
    end

    local outline = flags
    if outline == nil then
        outline = GetNPOutline()
    end

    local fontPath = GetFont()
    local ok = pcall(fs.SetFont, fs, fontPath, tonumber(size) or 11, outline)
    if not ok then
        fontPath = ns.ResolveNameplateFont()
        pcall(fs.SetFont, fs, fontPath, tonumber(size) or 11, outline)
    end
    if KT and KT.EnableTextFontFallback then
        KT:EnableTextFontFallback(fs, fontPath)
    end

    if outline == "" and GetNPUseShadow() then
        fs:SetShadowColor(0, 0, 0, 1)
        fs:SetShadowOffset(1, -1)
        return
    end

    fs:SetShadowOffset(0, 0)
end

for exportName, exportFn in pairs({
    GetFont = GetFont,
    GetNPOutline = GetNPOutline,
    GetNPUseShadow = GetNPUseShadow,
    SetFSFont = SetFSFont,
}) do
    ns[exportName] = exportFn
end
ns.plates = {}
ns.platesByNameplate = ns.platesByNameplate or {}
_G.KullThranUINameplates_NS = ns
ns._IsSecretValue = ns._IsSecretValue or function(value)
    if C_UI and C_UI.IsSecret then return C_UI.IsSecret(value) == true end
    if _G.IsSecretValue then return _G.IsSecretValue(value) == true end
    if issecretvalue then return issecretvalue(value) == true end
    return false
end

local function SafeUnitLevelText(unit)
    if not unit then return nil end
    if type(UnitExists) == "function" then
        local existsOK, exists = pcall(UnitExists, unit)
        if not existsOK or exists == false then return nil end
    end

    local level
    local levelAPIRan = false

    -- Keep the same Forever-safe lookup used by UnitFrames. UnitLevel can
    -- expose a legacy/unknown value while UnitEffectiveLevel is available.
    if type(UnitEffectiveLevel) == "function" then
        local ok, value = pcall(UnitEffectiveLevel, unit)
        if ok and not ns._IsSecretValue(value) then
            levelAPIRan = true
            if type(value) == "number" then level = value end
        end
    end
    if (type(level) ~= "number" or level <= 0) and type(UnitLevel) == "function" then
        local ok, value = pcall(UnitLevel, unit)
        if ok and not ns._IsSecretValue(value) then
            levelAPIRan = true
            if type(value) == "number" then level = value end
        end
    end

    if type(level) == "number" and level > 0 then return tostring(level) end
    -- Match oUF's readable fallback when the unit exists but its numeric
    -- level is unavailable on this client.
    if levelAPIRan then return "??" end
    return nil
end

local function SafeUnitClassification(unit)
    if not unit or type(UnitClassification) ~= "function" then return nil end
    local ok, classification = pcall(UnitClassification, unit)
    if not ok or ns._IsSecretValue(classification) or type(classification) ~= "string" then
        return nil
    end
    return classification
end

-- Tabla constante de slots de texto sobre la barra de vida (elevada a file-scope
-- para evitar asignaciones por cada llamada a UpdateHealthValues).
local HP_BAR_SLOTS = {
    { key = "textSlotRight",  anchor = "RIGHT",  point = "RIGHT",  xOff = -2 },
    { key = "textSlotLeft",   anchor = "LEFT",   point = "LEFT",   xOff = 4 },
    { key = "textSlotCenter", anchor = "CENTER", point = "CENTER", xOff = 0 },
}

local defaults = {
friendlyPlayerNameTextSize = 12,
friendlyNPCNameTextSize = 12,
friendlyGuildTextSize = 12,
friendlyHealthTextSize = 10,
friendlyPlayerNameAlignment = "center",
friendlyNPCNameAlignment = "center",
enable = true,
threatModBorder = false,
friendlyShowDefaultNames = false,
textSlotRight = "healthPercent",
topSlotSize = 30,
focusColorEnabled = true,
dispelGlowUseTypeColor = false,
showFriendlyNPCs = true,
castBarUninterruptible = {
b = 0.16,
g = 0.18,
r = 0.8,
},
leftSlotXOffset = 0,
toprightSlotXOffset = 0,
castBarHeight = 17,
textSlotTop = "enemyName",
threatModHealth = true,
debuffExpiryGlow = true,
debuffTimerPosition = "topleft",
tapped = {
b = 0.5,
g = 0.5,
r = 0.5,
},
friendlyNameOnlyYOffset = -20,
friendlyPlayerNameOnly = true,
friendlyNPCNameOnly = true,
friendlyPlayersInInstances = "name_only",
friendlyNPCsInInstances = "name_only",
showAggroGlow = false,
healthBarTexture = "Melli Reforged",
raidMarkerSize = 24,
topDebuffAlign = "center",
nameYOffset = 0,
textSlotRightColor = {
b = 1,
g = 1,
r = 1,
},
auraDurationTextColor = {
b = 1,
g = 1,
r = 1,
},
elite = {
b = 0.16,
g = 0.58,
r = 0.9,
},
priorityTargetsEnabled = false,
classPowerCustomColor = {
b = 0.3,
g = 0.84,
r = 1,
},
enemyOutOfCombat = {
b = 0.34,
g = 0.34,
r = 0.34,
},
topSlotYOffset = 0,
pandemicGlowSpeed = 4,
buffIconSize = 36,
caster = {
b = 0.965,
g = 0.51,
r = 0.231,
},
_auraIconScaleMigrated_v2 = true,
friendlyNPCHealthTexture = "Melli Reforged",
targetGlowStyle = "kullthranui",
levelColor = {
b = 0.2,
g = 0.82,
r = 1,
},
_castBarStateColorsMigrated_v2 = true,
topleftSlotXOffset = 0,
rightSlotSize = 36,
levelXOffset = 24,
hitboxScaleX = 100,
classPowerEmptyColor = {
b = 0.2,
g = 0.2,
r = 0.2,
},
miniboss = {
b = 0.984,
g = 0.243,
r = 0.518,
},
buffTimerPosition = "topleft",
targetGlowColor = {
b = 1,
g = 0.6157,
r = 0,
},
auraStackTextColor = {
b = 1,
g = 1,
r = 1,
},
hashLinePercent = 30,
bottomSlotXOffset = 0,
raidMarkerPos = "top",
_raidMarkerAboveNameMigrated_v1 = true,
showAggroFlash = false,
enemyInCombat = {
b = 0.137,
g = 0.137,
r = 0.8,
},
dispelGlowStyle = 2,
auraStackTextSize = 11,
topSlotXOffset = 0,
toprightSlotSize = 36,
_friendlyPlateDefaultsMigrated_v2 = true,
tankHasAggro = {
b = 0.62,
g = 0.82,
r = 0.05,
},
ccIconSize = 36,
classicTankAggro = false,
topleftSlotSize = 36,
_auraIconScaleMigrated_v1 = true,
debuffExpiryGlowUseTypeColor = true,
dispelGlowColor = {
b = 1,
g = 1,
r = 1,
},
interruptReady = {
b = 0.2,
g = 0.35,
r = 0.92,
},
textSlotRightYOffset = 0,
textSlotLeft = "none",
castNameSize = 10,
bottomSlotSize = 30,
targetIndicatorStyle = "arrow-double",
castIconScale = 1,
pandemicGlowStyle = 1,
levelShadow = true,
rareEliteIconSize = 36,
_classificationSizeMigrated_v2 = true,
threatModName = false,
textSlotCenterColor = {
b = 1,
g = 1,
r = 1,
},
auraPriorityEnabled = false,
ccSlot = "right",
focusOverlayAlpha = 0.4,
friendly = {
b = 0.9,
g = 0.55,
r = 0.2,
},
dispelGlow = false,
textSlotRightSize = 10,
ccTimerPosition = "topleft",
unitTypeColoringEnableElite = false,
friendlyPlateYOffset = 0,
kickTickEnabled = true,
castNameColor = {
b = 1,
g = 1,
r = 1,
},
classPowerXOffset = 0,
textSlotLeftSize = 10,
interruptCooldown = {
b = 0.45,
g = 0.45,
r = 0.45,
},
debuffSlot = "top",
leftSlotSize = 36,
showTargetArrows = true,
_castBarStateColorsMigrated_v1 = true,
threatUseSoloColor = false,
targetIndicatorGlowColor = {
b = 1,
g = 0.7686,
r = 0,
},
threatSoloColor = {
b = 0.09,
g = 0.11,
r = 0.39,
},
castBar = {
b = 0.9,
g = 0.4,
r = 0.7,
},
friendlyHealthBarWidth = 80,
enemyNameTextSize = 12,
borderColor = {
b = 0.067,
g = 0.067,
r = 0.067,
},
classPowerBgColor = {
b = 0.082,
g = 0.082,
r = 0.082,
},
_barSizeDefaultsMigrated_v1 = true,
dpsNoAggro = {
b = 0.09,
g = 0.11,
r = 0.39,
},
levelFontOutline = "OUTLINE",
tankLosingAggro = {
b = 0.19,
g = 0.72,
r = 0.81,
},
debuffIconSize = 30,
unitTypeColoringNoOverrideThreat = true,
buffSlot = "left",
sideAuraXOffset = 2,
friendlyNameOnly = true,
_healthBarTextureMediaMigrated_v1 = true,
hashLineColor = {
b = 1,
g = 1,
r = 1,
},
classPowerClassColors = true,
showShieldPrediction = true,
borderStyle = "kullthran",
pandemicGlow = false,
classPowerGap = 2,
tankHasAggroEnabled = true,
kickTickColor = {
b = 1,
g = 1,
r = 1,
},
animateHealthBar = false,
debuffExpiryGlowColor = {
b = 0.2,
g = 0.82,
r = 1,
},
buffTextSize = 12,
auraPriorityColor = {
b = 1,
g = 0.35,
r = 0.55,
},
rightSlotXOffset = 0,
neutral = {
b = 0.19,
g = 0.72,
r = 0.81,
},
castBarTexture = "Melli Reforged",
showFriendlyPlayers = true,
dpsNearAggro = {
b = 0.19,
g = 0.72,
r = 0.81,
},
castTargetClassColor = true,
auraDurationTextSize = 15,
textSlotLeftYOffset = 0,
focus = {
b = 0.62,
g = 0.82,
r = 0.051,
},
toprightSlotGrowth = "right",
_tankHasAggroEnabledMigrated_v1 = true,
showClassPower = false,
textSlotCenterSize = 10,
textSlotTopYOffset = 0,
nameplateYOffset = 0,
levelYOffset = 4,
classPowerPos = "bottom",
dpsHasAggro = {
b = 0,
g = 0.5,
r = 1,
},
pandemicGlowColor = {
b = 0.329,
g = 0.8,
r = 1,
},
unitTypeColoringEnableTrivial = false,
targetIndicatorGlow = true,
topDebuffOffsetX = 0,
textSlotTopXOffset = 0,
buffTextColor = {
b = 1,
g = 1,
r = 1,
},
questMobColor = {
b = 0.475,
g = 0.855,
r = 0.157,
},
debuffYOffset = 2,
questMobColorEnabled = false,
levelDifficultyColorEnabled = false,
levelTextDifficultyColor = true,
healthBarWidth = 45,
debuffTimerColor = {
b = 1,
g = 1,
r = 1,
},
boss = {
b = 0.16,
g = 0.18,
r = 0.8,
},
debuffExpiryGlowThreshold = 3,
nameplateOverlapV = 1.05,
classColorFriendly = true,
ccTextColor = {
b = 1,
g = 1,
r = 1,
},
auraSpacing = 2,
priorityTargetsInput = "",
leftSlotYOffset = 0,
classPowerYOffset = 3,
castTargetColor = {
b = 1,
g = 1,
r = 1,
},
hitboxScaleY = 100,
bottomSlotYOffset = 0,
priorityTargetsColor = {
b = 0.2,
g = 0.2,
r = 0.9,
},
topleftSlotYOffset = 0,
castTargetSize = 10,
friendlyPlayerHealthTexture = "Melli Reforged",
classificationSlot = "topright",
classificationXOffset = 0,
classificationYOffset = 0,
_classificationCornerMigrated_v1 = true,
textSlotTopSize = 12,
textSlotLeftColor = {
b = 1,
g = 1,
r = 1,
},
showEnemyPets = false,
font = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf",
textSlotCenterXOffset = 0,
focusOverlayColor = {
b = 1,
g = 1,
r = 1,
},
focusOverlayTexture = "striped-v2",
levelFontSize = 11,
textSlotCenter = "none",
colorOverrideEnabled = false,
unitTypeColoringEnabled = true,
healthBarHeight = 30,
trivial = {
b = 0.45,
g = 0.45,
r = 0.45,
},
friendlyHealthBarHeight = 12,
-- The level layout is safe to calculate by default, but level text itself
-- remains opt-in so nameplate visuals do not gain extra text.
showLevel = false,
showEnemyLevel = false,
showFriendlyLevel = false,
useDynamicNameplateLevelLayout = true,
tankNoAggro = {
b = 0.17,
g = 0.22,
r = 1,
},
ccTextSize = 12,
classPowerScale = 1,
castScale = 100,
enable = true,
auraPriorityMatchMode = "all",
hashLineEnabled = false,
auraTextPosition = "topleft",
auraPriorityTexture = "Melli Reforged",
topleftSlotGrowth = "left",
hostile = {
b = 0.09,
g = 0.11,
r = 0.39,
},
showCastIcon = true,
levelFont = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf",
_showAllPlayerDebuffsMigrated_v1 = true,
rightSlotYOffset = 0,
pandemicGlowThickness = 1,
targetArrowScale = 1,
textSlotLeftXOffset = 0,
stackingEnabled = true,
_debuffExpiryGlowMigrated_v1 = true,
textSlotTopColor = {
b = 1,
g = 1,
r = 1,
},
auraPriorityInput = "",
showAllDebuffs = true,
toprightSlotYOffset = 0,
tankOtherTankHasAggro = {
b = 0.95,
g = 0.58,
r = 0.26,
},
focusCastHeight = 100,
priorityTargetsTexture = "Melli Reforged",
pandemicGlowLines = 8,
textSlotRightXOffset = 0,
stackSpacingScale = 50,
textSlotCenterYOffset = 0,
targetIndicatorReversed = true,
}
local BAR_W = 150
ns.defaults = defaults
_G.KullThranUINameplatesDefaults = defaults

-- Live SavedVariables alias used by getters throughout this file.
-- Assigned in InitDB(); declared before the shared indicator helpers so they
-- close over the same profile table as the rest of the module.
local db

-- Shared catalogue for live plates, options and previews. Imported indicators
-- are 64x64 TGA files; their visible geometry is kept square and scaled from a
-- compact 24px base so transparent padding is preserved.
ns.targetIndicatorOrder = {
    "arrows",
    "arrow-broken",
    "arrow-composite",
    "arrow-double",
    "arrow-full",
    "arrow-thin",
    "bracket",
    "bracket-thin",
    "hinge",
    "hinge-thin",
}
ns.targetIndicatorStyles = {
    arrows = {
        label = "KUI Arrows",
        left = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\arrow_left.png",
        right = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\arrow_right.png",
        width = 11,
        height = 16,
    },
    ["arrow-broken"] = {
        label = "Broken Arrows",
        left = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\ArrowBrokenLeft.tga",
        right = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\ArrowBrokenRight.tga",
        width = 24,
        height = 24,
    },
    ["arrow-composite"] = {
        label = "Composite Arrows",
        left = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\ArrowCompositeLeft.tga",
        right = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\ArrowCompositeRight.tga",
        width = 24,
        height = 24,
    },
    ["arrow-double"] = {
        label = "Double Arrows",
        left = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\ArrowDoubleLeft.tga",
        right = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\ArrowDoubleRight.tga",
        width = 24,
        height = 24,
    },
    ["arrow-full"] = {
        label = "Full Arrows",
        left = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\ArrowFullLeft.tga",
        right = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\ArrowFullRight.tga",
        width = 24,
        height = 24,
    },
    ["arrow-thin"] = {
        label = "Thin Arrows",
        left = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\ArrowThinLeft.tga",
        right = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\ArrowThinRight.tga",
        width = 24,
        height = 24,
    },
    bracket = {
        label = "Bracket",
        texture = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\Bracket.tga",
        mirrorRight = true,
        width = 24,
        height = 24,
    },
    ["bracket-thin"] = {
        label = "Bracket Thin",
        texture = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\BracketThin.tga",
        mirrorRight = true,
        width = 24,
        height = 24,
    },
    hinge = {
        label = "Hinge",
        texture = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\Hinge.tga",
        mirrorRight = true,
        width = 24,
        height = 24,
    },
    ["hinge-thin"] = {
        label = "Hinge Thin",
        texture = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TargetIndicatorTextures\\HingeThin.tga",
        mirrorRight = true,
        width = 24,
        height = 24,
    },
}

function ns.GetTargetIndicatorStyle()
    local key = (db and db.targetIndicatorStyle) or defaults.targetIndicatorStyle
    return ns.targetIndicatorStyles[key] and key or defaults.targetIndicatorStyle
end

function ns.GetShowTargetArrows()
    if db and db.showTargetArrows ~= nil then return db.showTargetArrows end
    return defaults.showTargetArrows
end

function ns.GetTargetIndicatorGlowEnabled()
    if db and db.targetIndicatorGlow ~= nil then return db.targetIndicatorGlow end
    return defaults.targetIndicatorGlow
end

function ns.GetTargetIndicatorPreviewTexture(styleKey)
    local info = ns.targetIndicatorStyles[styleKey] or ns.targetIndicatorStyles[defaults.targetIndicatorStyle]
    return info and (info.preview or info.right or info.texture or info.left) or nil
end

function ns.RefreshTargetIndicatorTextures(plate, styleKey, scale)
    if not plate then return end
    local previewArrows = plate._arrows
    local leftArrow = plate.leftArrow or (previewArrows and previewArrows.left)
    local rightArrow = plate.rightArrow or (previewArrows and previewArrows.right)
    if not (leftArrow and rightArrow) then return end
    local key = styleKey or ns.GetTargetIndicatorStyle()
    local info = ns.targetIndicatorStyles[key] or ns.targetIndicatorStyles[defaults.targetIndicatorStyle]
    if not info then return end

    local reversed = (db and db.targetIndicatorReversed)
    if reversed == nil then reversed = defaults.targetIndicatorReversed end
    local flipLeft = (info.mirrorLeft == true) ~= (reversed == true)
    local flipRight = (info.mirrorRight == true) ~= (reversed == true)
    local leftPath = info.left or info.texture
    local rightPath = info.right or info.texture

    leftArrow:SetTexture(leftPath)
    rightArrow:SetTexture(rightPath)
    leftArrow:SetTexCoord(flipLeft and 1 or 0, flipLeft and 0 or 1, 0, 1)
    rightArrow:SetTexCoord(flipRight and 1 or 0, flipRight and 0 or 1, 0, 1)

    local appliedScale = tonumber(scale) or (db and db.targetArrowScale) or defaults.targetArrowScale or 1
    local width = math.max(1, math.floor((info.width or 24) * appliedScale + 0.5))
    local height = math.max(1, math.floor((info.height or 24) * appliedScale + 0.5))
    PP.Size(leftArrow, width, height)
    PP.Size(rightArrow, width, height)

    local glowEnabled = ns.GetTargetIndicatorGlowEnabled()
    if glowEnabled and not plate.leftArrowGlow then
        plate.leftArrowGlow = plate:CreateTexture(nil, "ARTWORK", nil, 1)
        plate.leftArrowGlow:SetBlendMode("ADD")
        plate.leftArrowGlow:SetPoint("CENTER", leftArrow, "CENTER", 0, 0)
        plate.rightArrowGlow = plate:CreateTexture(nil, "ARTWORK", nil, 1)
        plate.rightArrowGlow:SetBlendMode("ADD")
        plate.rightArrowGlow:SetPoint("CENTER", rightArrow, "CENTER", 0, 0)
    end
    if plate.leftArrowGlow and plate.rightArrowGlow then
        local color = (db and db.targetIndicatorGlowColor) or defaults.targetIndicatorGlowColor
        if type(color) ~= "table" then color = defaults.targetIndicatorGlowColor end
        local glowSpread = math.max(2, math.floor(6 * appliedScale + 0.5))
        plate.leftArrowGlow:SetTexture(leftPath)
        plate.rightArrowGlow:SetTexture(rightPath)
        plate.leftArrowGlow:SetTexCoord(flipLeft and 1 or 0, flipLeft and 0 or 1, 0, 1)
        plate.rightArrowGlow:SetTexCoord(flipRight and 1 or 0, flipRight and 0 or 1, 0, 1)
        plate.leftArrowGlow:SetVertexColor(color.r or 1, color.g or 0.36, color.b or 0.05, 0.72)
        plate.rightArrowGlow:SetVertexColor(color.r or 1, color.g or 0.36, color.b or 0.05, 0.72)
        PP.Size(plate.leftArrowGlow, width + glowSpread, height + glowSpread)
        PP.Size(plate.rightArrowGlow, width + glowSpread, height + glowSpread)
        plate.leftArrowGlow:SetShown(glowEnabled and leftArrow:IsShown())
        plate.rightArrowGlow:SetShown(glowEnabled and rightArrow:IsShown())
    end
    plate._targetIndicatorStyle = key
end

function ns.SetTargetIndicatorShown(plate, shown)
    if not plate then return end
    local previewArrows = plate._arrows
    local leftArrow = plate.leftArrow or (previewArrows and previewArrows.left)
    local rightArrow = plate.rightArrow or (previewArrows and previewArrows.right)
    shown = shown == true
    if leftArrow then leftArrow:SetShown(shown) end
    if rightArrow then rightArrow:SetShown(shown) end
    local showGlow = shown and ns.GetTargetIndicatorGlowEnabled()
    if plate.leftArrowGlow then plate.leftArrowGlow:SetShown(showGlow) end
    if plate.rightArrowGlow then plate.rightArrowGlow:SetShown(showGlow) end
end

local function CopyColor(color)
    if type(color) ~= "table" then return nil end
    return { r = color.r, g = color.g, b = color.b }
end

local function ColorsMatch(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    return a.r == b.r and a.g == b.g and a.b == b.b
end

ns.BAR_W = BAR_W
local CAST_H = 17
-- Icon sizes shipped by earlier releases, kept to recognise untouched profiles.
-- Large-icon keys and small-icon keys share one size per release.
local LEGACY_ICON_DEFAULTS, PREVIOUS_ICON_DEFAULTS = {}, {}
for _, group in ipairs({
    { keys = { "debuffIconSize", "topSlotSize", "bottomSlotSize" }, legacy = 26, previous = 33 },
    { keys = { "buffIconSize", "ccIconSize", "rightSlotSize", "leftSlotSize", "toprightSlotSize", "topleftSlotSize" },
      legacy = 24, previous = 30 },
}) do
    for _, key in ipairs(group.keys) do
        LEGACY_ICON_DEFAULTS[key] = group.legacy
        PREVIOUS_ICON_DEFAULTS[key] = group.previous
    end
end

-- Tablas de texturas overlay para la barra de vida (almacenadas en ns para
-- no presionar el límite de locales). Solo contiene la entrada "none";
-- las texturas de SharedMedia se añaden después.
do
    ns.healthBarTextures = {
        ["none"] = nil,
    }
    ns.healthBarTextureOrder = {
        "none",
    }
    ns.healthBarTextureNames = {
        ["none"] = "None",
    }
end

local LEGACY_HEALTH_BAR_TEXTURE_KEYS = {
    beautiful = true,
    plating = true,
    atrocity = true,
    divide = true,
    glass = true,
    ["gradient-lr"] = true,
    ["gradient-rl"] = true,
    ["gradient-bt"] = true,
    ["gradient-tb"] = true,
    matte = true,
    sheer = true,
}

-- Resuelve la ruta de textura: busca en la tabla o devuelve el fallback
local function ResolveTexturePath(textureTable, key, fallback)
    if textureTable and textureTable[key] then
        return textureTable[key]
    end
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local sharedPath = type(key) == "string" and LSM and LSM:Fetch("statusbar", key, true)
    if sharedPath then
        if textureTable then textureTable[key] = sharedPath end
        return sharedPath
    end
    return fallback or "Interface\\Buttons\\WHITE8x8"
end

-- Old KUI slots can retain the native fill saved by a previous style.
-- Resolve KUI's default directly from its bundled asset, not a stale media cache.
function ns.ResolveNameplateBarTexture(key)
    local style = ns.NameplateStyle and ns.NameplateStyle()
    if style == "kui" or style == nil then
        if key == "Blizzard" or key == "Blizzard Raid Bar"
            or key == "Interface\\TargetingFrame\\UI-StatusBar" then
            key = "Melli Reforged"
        end
        if key == "Melli Reforged" then
            return "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\MelliReforged.tga"
        end
    end
    if key == "Melli Dark" then
        return "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga"
    end
    return ResolveTexturePath(ns.healthBarTextures, key, "Interface\\Buttons\\WHITE8x8")
end

local function ApplyHealthBarTexture(plate)
    local health = plate.health
    if not health then return end
    local textureDB = KullThranUINameplatesDB or db
    local texKey = (textureDB and textureDB.healthBarTexture) or defaults.healthBarTexture or "none"
    if plate and plate.unit and not UnitCanAttack("player", plate.unit) then
        if UnitIsPlayer(plate.unit) then
            texKey = (textureDB and textureDB.friendlyPlayerHealthTexture) or defaults.friendlyPlayerHealthTexture or "Melli Reforged"
        else
            texKey = (textureDB and textureDB.friendlyNPCHealthTexture) or defaults.friendlyNPCHealthTexture or "Melli Reforged"
        end
    end
    local path   = ns.ResolveNameplateBarTexture(texKey)
    health:SetStatusBarTexture(path)
end
ns.ApplyHealthBarTexture = ApplyHealthBarTexture

local function ApplyCastBarTexture(plate)
    local cast = plate and plate.cast
    if not cast then return end
    local textureDB = KullThranUINameplatesDB or db
    local texKey = (textureDB and textureDB.castBarTexture) or defaults.castBarTexture or "none"
    cast:SetStatusBarTexture(ns.ResolveNameplateBarTexture(texKey))
end
ns.ApplyCastBarTexture = ApplyCastBarTexture

local function GetNameplateYOffset()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.nameplateYOffset or defaults.nameplateYOffset
end
ns.GetNameplateYOffset = GetNameplateYOffset
local function GetStackSpacingScale()
    return (KullThranUINameplatesDB and KullThranUINameplatesDB.stackSpacingScale) or defaults.stackSpacingScale
end
ns.GetStackSpacingScale = GetStackSpacingScale
local function GetCastScale()
    return (KullThranUINameplatesDB and KullThranUINameplatesDB.castScale) or defaults.castScale
end
ns.GetCastScale = GetCastScale
local function GetHealthBarHeight()
    local v = KullThranUINameplatesDB and KullThranUINameplatesDB.healthBarHeight
    if v and v ~= defaults.healthBarHeight then return v end
    local th = ns.ThemeBarHeight and ns.ThemeBarHeight()
    return th or defaults.healthBarHeight
end
ns.GetHealthBarHeight = GetHealthBarHeight
local function GetFriendlyHealthBarHeight()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.friendlyHealthBarHeight or defaults.friendlyHealthBarHeight
end
ns.GetFriendlyHealthBarHeight = GetFriendlyHealthBarHeight
local function GetFriendlyHealthBarWidth()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.friendlyHealthBarWidth or defaults.friendlyHealthBarWidth
end
ns.GetFriendlyHealthBarWidth = GetFriendlyHealthBarWidth
local function GetEnemyNameTextSize()
    -- Tamaño de fuente del slot de texto superior (usado para cálculo de gap de apilamiento)
    return (db and db.textSlotTopSize) or defaults.textSlotTopSize or 10
end
ns.GetEnemyNameTextSize = GetEnemyNameTextSize
local function GetDebuffTextColor()
    local c = db and db.debuffTimerColor or defaults.debuffTimerColor
    return c.r, c.g, c.b, 1
end
ns.GetDebuffTextColor = GetDebuffTextColor
ns.GetPandemicGlow = function()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.pandemicGlow or defaults.pandemicGlow
end

-- Definiciones de estilos de glow pandémico (reemplaza LibCustomGlow)
-- 1 = Pixel Glow (procedural ants), 2 = Action Button Glow (animated ants texture),
-- 3 = Auto-Cast Shine (orbiting sparkles), 4 = GCD (FlipBook atlas),
-- 5 = Modern WoW Glow (FlipBook atlas), 6 = Classic WoW Glow (FlipBook texture)
local PANDEMIC_GLOW_STYLES = {
    { name = "Pixel Glow",           procedural = true },
    { name = "Action Button Glow",   buttonGlow = true, scale = 1.36, previewScale = 1.28 },
    { name = "Auto-Cast Shine",      autocast = true },
    { name = "GCD",                  atlas = "RotationHelper_Ants_Flipbook",  scale = 1.47, previewScale = 1.47 },
    { name = "Modern WoW Glow",      atlas = "UI-HUD-ActionBar-Proc-Loop-Flipbook",  scale = 1.34, previewScale = 1.34 },
    { name = "Classic WoW Glow",     texture = "Interface\\SpellActivationOverlay\\IconAlertAnts",
      rows = 5, columns = 5, frames = 25, duration = 0.3, frameW = 48, frameH = 48, scale = 1.47, previewScale = 1.47 },
}
ns.PANDEMIC_GLOW_STYLES = PANDEMIC_GLOW_STYLES

ns.GetPandemicGlowStyle = function()
    local raw = db and db.pandemicGlowStyle
    if raw == nil then return defaults.pandemicGlowStyle end
    if type(raw) == "number" then return raw end
    return 1
end
ns.GetPandemicGlowColor = function()
    local c = (db and db.pandemicGlowColor) or defaults.pandemicGlowColor
    return c.r, c.g, c.b
end
ns.GetPandemicGlowLines = function()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.pandemicGlowLines or defaults.pandemicGlowLines
end
ns.GetPandemicGlowThickness = function()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.pandemicGlowThickness or defaults.pandemicGlowThickness
end
ns.GetPandemicGlowSpeed = function()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.pandemicGlowSpeed or defaults.pandemicGlowSpeed
end

ns.GetAuraTypeColor = function(unit, aura)
    if not (unit and aura and aura.auraInstanceID) then
        return nil
    end

    local dispelName = aura.dispelName
    local fallback = dispelName and DebuffTypeColor and DebuffTypeColor[dispelName]
    if fallback then
        return CreateColor(fallback.r or 1, fallback.g or 1, fallback.b or 1, 1)
    end

    return nil
end

ns.GetDebuffExpiryGlowColor = function(typeColor)
    local useType = db and db.debuffExpiryGlowUseTypeColor
    if useType == nil then useType = defaults.debuffExpiryGlowUseTypeColor end
    if useType and typeColor and typeColor.GetRGBA then
        return typeColor:GetRGBA()
    end
    local c = (db and db.debuffExpiryGlowColor) or defaults.debuffExpiryGlowColor
    return c.r, c.g, c.b, 1
end

-- Glow de buffs dispeleables: detección taint-safe vía GetAuraDispelTypeColor
do
    local DISPEL_NONE = 0
    local DISPEL_MAGIC = 1
    local DISPEL_CURSE = 2
    local DISPEL_DISEASE = 3
    local DISPEL_POISON = 4
    local DISPEL_ENRAGE = 9

    local dispelDetectionCurve
    if C_CurveUtil and C_CurveUtil.CreateColorCurve and Enum and Enum.LuaCurveType then
        dispelDetectionCurve = C_CurveUtil.CreateColorCurve()
        dispelDetectionCurve:SetType(Enum.LuaCurveType.Step)
        local clear = CreateColor(0, 0, 0, 0)
        local blue = CreateColor(0.2, 0.6, 1.0, 1)
        local red = CreateColor(1.0, 0.2, 0.2, 1)
        dispelDetectionCurve:AddPoint(DISPEL_NONE, clear)
        dispelDetectionCurve:AddPoint(DISPEL_MAGIC, blue)
        dispelDetectionCurve:AddPoint(DISPEL_CURSE, clear)
        dispelDetectionCurve:AddPoint(DISPEL_DISEASE, clear)
        dispelDetectionCurve:AddPoint(DISPEL_POISON, clear)
        dispelDetectionCurve:AddPoint(DISPEL_ENRAGE, red)
    end

    local _, playerClass = UnitClass("player")
    local OFFENSIVE_DISPEL_SPELLS = {
        { 370, "Magic", nil },
        { 378773, "Magic", nil },
        { 528, "Magic", nil },
        { 278326, "Magic", nil },
        { 19505, "Magic", "WARLOCK" },
        { 19801, "Both", nil },
        { 2908, "Enrage", nil },
        { 30449, "Magic", nil },
        { 115078, "Enrage", "MONK", 450432 },
    }
    local canDispelMagic, canDispelEnrage = false, false

    local function RebuildDispelTypes()
        canDispelMagic, canDispelEnrage = false, false
        for _, entry in ipairs(OFFENSIVE_DISPEL_SPELLS) do
            local spellID, category, requiredClass, requiredTalent = entry[1], entry[2], entry[3], entry[4]
            if requiredClass and playerClass ~= requiredClass then
                -- Clase incorrecta para este hechizo
            else
                local known = false
                if requiredClass and not requiredTalent then
                    if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook
                        and Enum and Enum.SpellBookSpellBank then
                        known = C_SpellBook.IsSpellKnownOrInSpellBook(spellID, Enum.SpellBookSpellBank.Pet)
                    elseif IsSpellKnown then
                        known = IsSpellKnown(spellID, true)
                    end
                elseif requiredTalent then
                    if IsPlayerSpell then
                        known = IsPlayerSpell(requiredTalent)
                    elseif IsSpellKnown then
                        known = IsSpellKnown(requiredTalent, false)
                    end
                elseif C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
                    known = C_SpellBook.IsSpellKnownOrInSpellBook(spellID)
                elseif IsSpellKnown then
                    known = IsSpellKnown(spellID, false)
                end

                if known then
                    if category == "Magic" or category == "Both" then canDispelMagic = true end
                    if category == "Enrage" or category == "Both" then canDispelEnrage = true end
                end
            end
        end
    end

    local dispelFrame = CreateFrame("Frame")
    dispelFrame:RegisterEvent("SPELLS_CHANGED")
    dispelFrame:RegisterEvent("UNIT_PET")
    dispelFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_PET" and unit ~= "player" then return end
        RebuildDispelTypes()
    end)
    RebuildDispelTypes()

    ns.CanDispelAura = function(unit, aura)
        if not (canDispelMagic or canDispelEnrage) then return false end
        local typeColor
        if dispelDetectionCurve and C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor then
            local ok, c = pcall(C_UnitAuras.GetAuraDispelTypeColor, unit, aura.auraInstanceID, dispelDetectionCurve)
            if ok and c then typeColor = c end
        end
        return true, typeColor
    end
end

ns.GetDispelGlow = function()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.dispelGlow or defaults.dispelGlow
end

ns.GetDispelGlowStyle = function()
    local raw = db and db.dispelGlowStyle
    if raw == nil then return defaults.dispelGlowStyle end
    if type(raw) == "number" then return raw end
    return 2
end

ns.GetDispelGlowColor = function(typeColor)
    local useType = db and db.dispelGlowUseTypeColor
    if useType == nil then useType = defaults.dispelGlowUseTypeColor end
    if useType and typeColor then
        return typeColor:GetRGBA()
    end
    local c = (db and db.dispelGlowColor) or defaults.dispelGlowColor
    return c.r, c.g, c.b
end

local function GetCastBarHeight()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.castBarHeight or defaults.castBarHeight
end
ns.GetCastBarHeight = GetCastBarHeight
local function GetFocusCastHeight()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.focusCastHeight or defaults.focusCastHeight
end
ns.GetFocusCastHeight = GetFocusCastHeight
local function GetShowCastIcon()
    if db and db.showCastIcon ~= nil then return db.showCastIcon end
    return defaults.showCastIcon
end
local function GetCastIconScale()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.castIconScale or defaults.castIconScale
end
local function GetKickTickEnabled()
    if db and db.kickTickEnabled ~= nil then return db.kickTickEnabled end
    return true
end
local function GetKickTickColor()
    local c = (db and db.kickTickColor) or defaults.kickTickColor
    return c.r, c.g, c.b
end
local function GetAuraSpacing()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.auraSpacing or defaults.auraSpacing
end
ns.GetAuraSpacing = GetAuraSpacing
local function GetDebuffYOffset()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.debuffYOffset or defaults.debuffYOffset
end
ns.GetDebuffYOffset = GetDebuffYOffset
local function GetSideAuraXOffset()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.sideAuraXOffset or defaults.sideAuraXOffset
end
ns.GetSideAuraXOffset = GetSideAuraXOffset
-- Side gap for one plate: past the level badge (right) or quest icon (left) the style draws there.
function ns.SideAuraXOffsetFor(plate, side)
    local base = GetSideAuraXOffset()
    if not (plate and ns.ThemeSideOccupied) then return base end
    local l, r = ns.ThemeSideOccupied(plate)
    return base + ((side == "left") and l or r)
end
local function GetRaidMarkerPos()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.raidMarkerPos or defaults.raidMarkerPos
end
ns.GetRaidMarkerPos = GetRaidMarkerPos
local function GetRaidMarkerSize()
    local live = KullThranUINameplatesDB
    local pos = live and live.raidMarkerPos or defaults.raidMarkerPos
    if pos == "none" then return defaults.raidMarkerSize or 24 end
    local sizeKey = pos .. "SlotSize"
    return live and live[sizeKey] or defaults[sizeKey] or 24
end
local function GetRaidMarkerYOffset() return 0 end
ns.GetRaidMarkerSize, ns.GetRaidMarkerYOffset = GetRaidMarkerSize, GetRaidMarkerYOffset
local function GetClassificationSlot()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.classificationSlot or defaults.classificationSlot
end
ns.GetClassificationSlot = GetClassificationSlot
local function GetRareEliteIconSize()
    return tonumber(KullThranUINameplatesDB and KullThranUINameplatesDB.rareEliteIconSize)
        or defaults.rareEliteIconSize or 20
end
ns.GetRareEliteIconSize = GetRareEliteIconSize
local function GetNameYOffset()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.nameYOffset or defaults.nameYOffset
end
ns.GetNameYOffset = GetNameYOffset

local function GetLevelConfigValue(key)
    local live = KullThranUINameplatesDB
    if live and live[key] ~= nil then return live[key] end
    return defaults[key]
end

local function ShouldShowNameplateLevel(isFriendly)
    if KT.IS_FOREVER ~= true and (not ns.NameplateStyle or ns.NameplateStyle() == "kui") then return false end
    local key = isFriendly and "showFriendlyLevel" or "showEnemyLevel"
    local live = KullThranUINameplatesDB
    if live and live[key] ~= nil then
        return live[key] == true
    end
    -- Keep profiles that only have the legacy showLevel key working.
    if not isFriendly and live and live.showLevel ~= nil then
        return live.showLevel == true
    end
    return defaults[key] == true
end
ns.ShouldShowNameplateLevel = ShouldShowNameplateLevel

local function UseDynamicNameplateLevelLayout()
    return GetLevelConfigValue("useDynamicNameplateLevelLayout") == true
end

local function ApplyLevelTextStyle(fontString)
    if not (fontString and fontString.SetFont) then return end

    local fontValue = GetLevelConfigValue("levelFont") or ns.DEFAULT_FONT_PATH
    local fontPath = ns.ResolveNameplateFont(fontValue)
    local size = tonumber(GetLevelConfigValue("levelFontSize")) or defaults.levelFontSize or 11
    size = math.max(6, math.min(48, size))

    local outline = GetLevelConfigValue("levelFontOutline")
    if outline == "NONE" then outline = "" end
    if type(outline) ~= "string" then outline = "OUTLINE" end

    local ok = pcall(fontString.SetFont, fontString, fontPath, size, outline)
    if not ok then
        pcall(fontString.SetFont, fontString, ns.DEFAULT_FONT_PATH, size, outline)
    end

    local color = GetLevelConfigValue("levelColor") or defaults.levelColor
    fontString:SetTextColor(color.r or 1, color.g or 1, color.b or 1, color.a or 1)

    if GetLevelConfigValue("levelShadow") ~= false then
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(1, -1)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
end

ns.GetNameplateLevelText = SafeUnitLevelText
ns.ApplyNameplateLevelTextStyle = ApplyLevelTextStyle

local textSlotKeys = { "textSlotTop", "textSlotRight", "textSlotLeft", "textSlotCenter" }
ns.textSlotKeys = textSlotKeys

local function GetTextSlot(slotKey)
    local v = (db and db[slotKey]) or defaults[slotKey]
    -- Retail/Forever: look Blizzard (nombre dentro de la barra, a la izquierda)
    -- solo si el usuario no movio los slots (siguen en su valor por defecto).
    if (slotKey == "textSlotTop" or slotKey == "textSlotLeft")
        and ns.ThemeBlizzText and ns.ThemeBlizzText() then
        local top = (db and db.textSlotTop) or defaults.textSlotTop
        local left = (db and db.textSlotLeft) or defaults.textSlotLeft
        if top == defaults.textSlotTop and left == defaults.textSlotLeft then
            return (slotKey == "textSlotTop") and "none" or "enemyName"
        end
    end
    return v
end
ns.GetTextSlot = GetTextSlot

local function FindSlotForElement(element)
    if not element or element == "none" then
        return nil
    end

    for index = 1, #textSlotKeys do
        local key = textSlotKeys[index]
        if GetTextSlot(key) == element then
            return key
        end
    end
end
ns.FindSlotForElement = FindSlotForElement

local function FormatCombinedHealth(element, pctText, numText)
    if element == "healthPctNum" then return pctText .. " | " .. numText
    elseif element == "healthNumPct" then return numText .. " | " .. pctText
    end
    return ""
end

-- Estima el ancho en píxeles del texto de vida para un tipo de elemento.
-- No podemos leer anchos renderizados reales (valores secretos de WoW),
-- así que usamos estimaciones fijas basadas en los peores casos típicos.
local HEALTH_TEXT_PADDING = 10  -- margen de seguridad en px
local healthTextWidths = {}
for _, element in ipairs({ "healthPercent", "healthPercentNoSign", "healthNumber" }) do
    healthTextWidths[element] = 38
end
for _, element in ipairs({ "healthPctNum", "healthNumPct" }) do
    healthTextWidths[element] = 75
end
local function EstimateHealthTextWidth(element)
    local baseWidth = healthTextWidths[element]
    if not baseWidth then
        return HEALTH_TEXT_PADDING
    end
    if element == "healthPctNum" or element == "healthNumPct" then
        return baseWidth + HEALTH_TEXT_PADDING + 2
    end
    return baseWidth + HEALTH_TEXT_PADDING
end
ns.EstimateHealthTextWidth = EstimateHealthTextWidth

local function GetHealthBarWidth()
    local extra = KullThranUINameplatesDB and KullThranUINameplatesDB.healthBarWidth or defaults.healthBarWidth
    -- Style width only while the player keeps the default width.
    if extra == defaults.healthBarWidth and ns.ThemeBarWidthExtra then
        extra = ns.ThemeBarWidthExtra() or extra
    end
    return BAR_W + extra
end
ns.GetHealthBarWidth = GetHealthBarWidth

-- Retorna el offset Y que aplica al contenido de la placa cuando la escala Y del
-- hitbox difiere de 100%. SetNamePlateSize crece/encoge el frame desde su ancla
-- base, así que desplazamos el contenido para mantener la barra visual en su sitio.
local function GetHitboxYShift()
    local db = KullThranUINameplatesDB or defaults
    local sy = (db.hitboxScaleY or 100) / 100
    if sy == 1 then return 0 end
    return -((GetHealthBarHeight() * sy) - GetHealthBarHeight()) / 2
end
ns.GetHitboxYShift = GetHitboxYShift
-- Slot-based size/offset getters
local function GetSlotSize(posKey)
    return (db and db[posKey .. "SlotSize"]) or defaults[posKey .. "SlotSize"] or 24
end
ns.GetSlotSize = GetSlotSize
local function GetSlotOffsets(posKey)
    local xOff = (db and db[posKey .. "SlotXOffset"]) or defaults[posKey .. "SlotXOffset"] or 0
    local yOff = (db and db[posKey .. "SlotYOffset"]) or defaults[posKey .. "SlotYOffset"] or 0
    return xOff, yOff
end
ns.GetSlotOffsets = GetSlotOffsets
-- Getter builders for profile values: the saved value wins, the shipped
-- default is the fallback. `prefer` treats any falsy saved value as unset,
-- while `explicit` only treats nil as unset (false is a legitimate choice).
ns._CfgGet = {}
function ns._CfgGet.prefer(key)
    return function()
        local saved = db and db[key]
        if saved then return saved end
        return defaults[key]
    end
end
function ns._CfgGet.explicit(key)
    return function()
        local saved = db and db[key]
        if saved == nil then return defaults[key] end
        return saved
    end
end
-- Icon size of an aura group: its slot decides, "none" uses the group's own default.
function ns._CfgGet.iconSize(group, fallback)
    local slotKey, sizeKey = group .. "Slot", group .. "IconSize"
    return function()
        local slot = (db and db[slotKey]) or defaults[slotKey]
        if slot == "none" then return defaults[sizeKey] or fallback end
        return GetSlotSize(slot)
    end
end

local GetDebuffIconSize = ns._CfgGet.iconSize("debuff", 26)
local GetBuffIconSize = ns._CfgGet.iconSize("buff", 24)
local GetCCIconSize = ns._CfgGet.iconSize("cc", 24)
local GetTargetGlowStyle = ns._CfgGet.prefer("targetGlowStyle")
local function GetShowTargetGlow()
    return GetTargetGlowStyle() ~= "none"
end
local GetShowClassPower = ns._CfgGet.explicit("showClassPower")
local GetClassPowerPos = ns._CfgGet.prefer("classPowerPos")
local GetClassPowerYOffset = ns._CfgGet.prefer("classPowerYOffset")
local GetClassPowerXOffset = ns._CfgGet.prefer("classPowerXOffset")
local GetClassPowerGap = ns._CfgGet.prefer("classPowerGap")
local GetClassPowerClassColors = ns._CfgGet.explicit("classPowerClassColors")
local GetClassPowerScale
do
    local baseScale = ns._CfgGet.prefer("classPowerScale")
    GetClassPowerScale = function()
        local scale = baseScale()
        if ns.NameplateStyle and ns.NameplateStyle() == "classic" then
            scale = scale * 0.8
        end
        return scale
    end
end
for exportName, exportFn in pairs({
    GetDebuffIconSize = GetDebuffIconSize,
    GetBuffIconSize = GetBuffIconSize,
    GetCCIconSize = GetCCIconSize,
    GetTargetGlowStyle = GetTargetGlowStyle,
    GetShowTargetGlow = GetShowTargetGlow,
    GetShowClassPower = GetShowClassPower,
    GetClassPowerPos = GetClassPowerPos,
    GetClassPowerYOffset = GetClassPowerYOffset,
    GetClassPowerXOffset = GetClassPowerXOffset,
    GetClassPowerScale = GetClassPowerScale,
    GetClassPowerGap = GetClassPowerGap,
    GetClassPowerClassColors = GetClassPowerClassColors,
}) do
    ns[exportName] = exportFn
end
-- Combo point shape: "retail" / "forever" (the client's points), "circle" (KUI Style's own
-- points) or "pip" (rectangular).
local function GetClassPowerShape()
    if db and db.classPowerShape then return db.classPowerShape end
    -- Unset: each style its own points; KUI Style pips, Classic the KUI points.
    local theme = ns.NameplateStyle and ns.NameplateStyle()
    if theme == "kui" then return "pip" end
    if theme == "retail" or theme == "forever" then return theme end
    return "circle"
end
ns.GetClassPowerShape = GetClassPowerShape
local function GetClassPowerCustomColor()
    local c = (db and db.classPowerCustomColor) or defaults.classPowerCustomColor
    return c
end
ns.GetClassPowerCustomColor = GetClassPowerCustomColor
local function GetClassPowerBgColor()
    local c = (db and db.classPowerBgColor) or defaults.classPowerBgColor
    return c
end
ns.GetClassPowerBgColor = GetClassPowerBgColor
local function GetClassPowerEmptyColor()
    local c = (db and db.classPowerEmptyColor) or defaults.classPowerEmptyColor
    return c
end
ns.GetClassPowerEmptyColor = GetClassPowerEmptyColor
local function GetBorderStyle()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.borderStyle or defaults.borderStyle
end
ns.GetBorderStyle = GetBorderStyle
local function GetBorderColor()
    local c = (db and db.borderColor) or defaults.borderColor
    return c.r, c.g, c.b
end
ns.GetBorderColor = GetBorderColor
local function GetAuraSlots()
    local ds = (db and db.debuffSlot) or defaults.debuffSlot
    local bs = (db and db.buffSlot)   or defaults.buffSlot
    local cs = (db and db.ccSlot)     or defaults.ccSlot
    return ds, bs, cs
end
ns.GetAuraSlots = GetAuraSlots
local function GetTopDebuffAlign()
    local align = (db and db.topDebuffAlign) or defaults.topDebuffAlign or "center"
    if align == "left" or align == "right" then
        return align
    end
    return "center"
end
ns.GetTopDebuffAlign = GetTopDebuffAlign
local function GetTopDebuffOffsetX()
    return (db and db.topDebuffOffsetX) or defaults.topDebuffOffsetX or 0
end
ns.GetTopDebuffOffsetX = GetTopDebuffOffsetX

-- Motor de glow pandémico: ants procedurales, button glow, autocast shine, FlipBook
-- Envuelto en do...end para que las locales internas no cuenten contra el límite
-- de 200 del chunk principal. Los ítems necesarios externamente se almacenan en ns.
do
-- Curva pandémica: función escalón que retorna 1 cuando el % restante <= 30% (ventana pandémica), 0 en caso contrario
-- Los valores secretos de objetos de duración se pasan SOLO a APIs de widget de Blizzard (SetAlpha), nunca se comparan en Lua
local pandemicCurve
if C_CurveUtil and C_CurveUtil.CreateCurve then
    pandemicCurve = C_CurveUtil.CreateCurve()
    pandemicCurve:SetType(Enum.LuaCurveType.Step)
    pandemicCurve:AddPoint(0, 1)
    pandemicCurve:AddPoint(0.3, 0)
end
ns.pandemicCurve = pandemicCurve

-- The three glow engines (ants, button glow, autocast shine) live in the core
-- KullThranUI.Glows table; the pandemic wrapper below uses them directly.
local glowEngines = KullThranUI.Glows
local StartProceduralAnts, StopProceduralAnts = glowEngines.StartProceduralAnts, glowEngines.StopProceduralAnts
local StartButtonGlow, StopButtonGlow = glowEngines.StartButtonGlow, glowEngines.StopButtonGlow
local StartAutoCastShine, StopAutoCastShine = glowEngines.StartAutoCastShine, glowEngines.StopAutoCastShine
for _, engineName in ipairs({ "ProceduralAnts", "ButtonGlow", "AutoCastShine" }) do
    ns["Start" .. engineName] = glowEngines["Start" .. engineName]
    ns["Stop" .. engineName] = glowEngines["Stop" .. engineName]
end

-- Nameplate glows share the strata of the aura slot they decorate and rise
-- above it by frame level, so windows such as the world map still cover them.
local function GetNameplateGlowStrata(owner)
    local strata = owner and owner.GetFrameStrata and owner:GetFrameStrata()
    return strata or "BACKGROUND"
end
local NAMEPLATE_GLOW_FRAME_LEVEL = 1000
local function RaiseNameplateGlowLayers(glowObject)
    local wrapper = glowObject and glowObject.wrapper
    if not wrapper then return end
    local strata = GetNameplateGlowStrata(wrapper:GetParent())
    wrapper:SetFrameStrata(strata)
    wrapper:SetFrameLevel(NAMEPLATE_GLOW_FRAME_LEVEL)
    local overlay = wrapper.overlay
    if overlay then
        overlay:SetFrameStrata(strata)
        overlay:SetFrameLevel(NAMEPLATE_GLOW_FRAME_LEVEL + 1)
    end
    local autoGlow = wrapper._ktAutoCastGlow
    if autoGlow then
        autoGlow:SetFrameStrata(strata)
        autoGlow:SetFrameLevel(NAMEPLATE_GLOW_FRAME_LEVEL + 1)
    end
    local flipTex = glowObject.flipTex
    if flipTex and flipTex.SetDrawLayer then
        flipTex:SetDrawLayer("OVERLAY", 7)
    end
end

-- Conjunto de slots de debuff con glows pandémicos activos; solo estos reciben el tick de alpha
local activePandemicSlots = {}
ns.activePandemicSlots = activePandemicSlots
ns.trackedExpirySlots = ns.trackedExpirySlots or {}
local trackedExpirySlots = ns.trackedExpirySlots
ns.trackedExpirySlots = trackedExpirySlots
local debuffExpiryCurve
local debuffExpiryCurveThreshold

local function StopDebuffExpiryGlow(slot)
    trackedExpirySlots[slot] = nil
    local glow = slot and slot.expiryGlow
    if not glow then
        return
    end

    if glow.wrapper then
        StopButtonGlow(glow.wrapper)
        glow.wrapper:SetAlpha(0)
        glow.wrapper:Hide()
    end
    glow.active = false
    glow.size = nil
end

local function EnsureDebuffExpiryGlow(slot)
    if slot.expiryGlow then
        return slot.expiryGlow
    end

    local wrapper = CreateFrame("Frame", nil, slot)
    wrapper:SetPoint("CENTER", slot, "CENTER", 0, 0)
    wrapper:SetSize(1, 1)
    wrapper:SetFrameLevel(slot:GetFrameLevel() + 8)
    wrapper:SetFrameStrata(GetNameplateGlowStrata(slot))
    if wrapper.EnableMouse then
        wrapper:EnableMouse(false)
    end
    wrapper:SetAlpha(0)
    wrapper:Hide()

    local glow = {
        wrapper = wrapper,
        active = false,
    }
    slot.expiryGlow = glow
    return glow
end

local function GetDebuffExpiryCurve()
    local cfg = KullThranUINameplatesDB or defaults
    local threshold = tonumber(cfg.debuffExpiryGlowThreshold) or defaults.debuffExpiryGlowThreshold or 3
    if threshold <= 0 or not (C_CurveUtil and C_CurveUtil.CreateCurve and Enum and Enum.LuaCurveType) then
        return nil
    end

    if debuffExpiryCurve and debuffExpiryCurveThreshold == threshold then
        return debuffExpiryCurve
    end

    local pct = math.max(0.05, math.min(0.9, threshold / 12))
    local curve = C_CurveUtil.CreateCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0, 1)
    curve:AddPoint(pct, 0)
    debuffExpiryCurve = curve
    debuffExpiryCurveThreshold = threshold
    return debuffExpiryCurve
end

local function UpdateDebuffExpiryGlow(slot, typeColor)
    local cfg = KullThranUINameplatesDB or defaults
    if cfg.debuffExpiryGlow ~= true then
        StopDebuffExpiryGlow(slot)
        return
    end

    local durObj = slot and slot._durationObj
    local curve = GetDebuffExpiryCurve()
    if not durObj or not curve then
        StopDebuffExpiryGlow(slot)
        return
    end

    local glow = EnsureDebuffExpiryGlow(slot)
    local alpha = C_CurveUtil.EvaluateColorValueFromBoolean(durObj:IsZero(), 0, durObj:EvaluateRemainingPercent(curve))
    local glowSize = tonumber(cfg.debuffIconSize) or tonumber(cfg.auraIconSize) or defaults.debuffIconSize or 40
    local shouldRefreshGlow = (not glow.active) or glow.size ~= glowSize

    if shouldRefreshGlow then
        glow.wrapper:ClearAllPoints()
        glow.wrapper:SetPoint("CENTER", slot, "CENTER", 0, 0)
        glow.wrapper:SetSize(glowSize, glowSize)
        StopButtonGlow(glow.wrapper)
        StartButtonGlow(glow.wrapper, glowSize)
        RaiseNameplateGlowLayers(glow)
        glow.active = true
        glow.size = glowSize
    end

    glow.wrapper:SetAlpha(alpha)
    glow.wrapper:Show()
    trackedExpirySlots[slot] = true
    if ns.ArmPandemicTick then ns.ArmPandemicTick() end
end

ns.StopDebuffExpiryGlow = StopDebuffExpiryGlow
ns.UpdateDebuffExpiryGlow = UpdateDebuffExpiryGlow

-- Desactiva el glow pandémico de una ranura y la desregistra del tick
-- de alpha. Limpia animaciones y detiene todos los engines visuales
-- antes de marcar como inactivo.
local function StopPandemicGlow(slot)
    activePandemicSlots[slot] = nil
    local glow = slot and slot.pandemicGlow
    if not glow or not glow.active then return end

    if glow.animGroup then glow.animGroup:Stop() end
    if glow.flipTex and glow.flipTex.IsShown and glow.flipTex:IsShown() then
        glow.flipTex:Hide()
    end
    local w = glow.wrapper
    if w then
        StopProceduralAnts(w)
        StopButtonGlow(w)
        StopAutoCastShine(w)
        w:Hide()
    end
    glow.active = false
end

-- Construye o reutiliza el conjunto de frames visuales (wrapper, flipTex,
-- animGroup, flipAnim) para un glow de cualquier tipo. El campo `field`
-- indica la clave en el slot ("pandemicGlow" o "dispelGlow") y `initAlpha`
-- el valor inicial del wrapper (0 para pandemic, 1 para dispel).
local function BuildGlowFrameSet(slot, field, initAlpha)
    local g = slot[field]
    if g then return g end

    local wrapper = CreateFrame("Frame", nil, slot)
    wrapper:SetAllPoints()
    wrapper:SetFrameLevel(slot:GetFrameLevel() + 1)
    wrapper:SetFrameStrata(GetNameplateGlowStrata(slot))

    local flipTex = wrapper:CreateTexture(nil, "OVERLAY", nil, 7)
    flipTex:SetPoint("CENTER")

    local ag = flipTex:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local fa = ag:CreateAnimation("FlipBook")

    wrapper:Show()
    wrapper:SetAlpha(initAlpha)

    g = { wrapper = wrapper, flipTex = flipTex, animGroup = ag, flipAnim = fa, active = false }
    slot[field] = g
    return g
end

-- Mapa de parada selectiva: cada rama sólo detiene los engines que NO
-- va a activar, evitando el coste de Stop+Start redundante.
ns._GLOW_CLEANUP = {
    proc = function(w) StopButtonGlow(w); StopAutoCastShine(w) end,
    btn  = function(w) StopProceduralAnts(w); StopAutoCastShine(w) end,
    auto = function(w) StopProceduralAnts(w); StopButtonGlow(w) end,
    flip = function(w) StopProceduralAnts(w); StopButtonGlow(w); StopAutoCastShine(w) end,
}

-- Despacho unificado de estilos de glow: recibe el sub-objeto (pg/dg),
-- la entrada de estilo, tamaño de icono y color RGB. proceduralCfg permite
-- sobreescribir líneas/grosor/velocidad (usado por dispelGlow con valores
-- fijos distintos de la configuración del usuario).
local function ActivateGlowStyle(glowObj, entry, sz, cr, cg, cb, proceduralCfg)
    local w = glowObj.wrapper

    -- Resolver qué rama activar y limpiar las rivales
    local kind
    if     entry.procedural then kind = "proc"
    elseif entry.buttonGlow then kind = "btn"
    elseif entry.autocast   then kind = "auto"
    else                         kind = "flip"
    end
    ns._GLOW_CLEANUP[kind](w)

    -- Todas las ramas excepto flipBook ocultan el flipTex antes de activar
    if kind ~= "flip" then
        glowObj.flipTex:Hide()
        glowObj.animGroup:Stop()
    end

    if kind == "proc" then
        local cfg  = proceduralCfg or {}
        local N    = cfg.lines     or ns.GetPandemicGlowLines()
        local th   = cfg.thickness or ns.GetPandemicGlowThickness()
        local spd  = cfg.speed     or ns.GetPandemicGlowSpeed()
        local len  = math.floor((sz * 2) * (2 / N - 0.1))
        if len > sz then len = sz end
        if len < 1 then len = 1 end
        StartProceduralAnts(w, N, th, spd, len, cr, cg, cb, sz)
        RaiseNameplateGlowLayers(glowObj)
        return
    end

    if kind == "btn" then
        StartButtonGlow(w, sz, cr, cg, cb, entry.scale or 1.36)
        RaiseNameplateGlowLayers(glowObj)
        return
    end

    if kind == "auto" then
        StartAutoCastShine(w, sz, cr, cg, cb)
        RaiseNameplateGlowLayers(glowObj)
        return
    end

    -- FlipBook: GCD, Modern WoW Glow, Classic WoW Glow
    local texSz = sz * (entry.scale or 1)
    glowObj.flipTex:SetSize(texSz, texSz)
    if entry.atlas then
        glowObj.flipTex:SetAtlas(entry.atlas)
    elseif entry.texture then
        glowObj.flipTex:SetTexture(entry.texture)
    end
    glowObj.flipAnim:SetFlipBookRows(entry.rows or 6)
    glowObj.flipAnim:SetFlipBookColumns(entry.columns or 5)
    glowObj.flipAnim:SetFlipBookFrames(entry.frames or 30)
    glowObj.flipAnim:SetDuration(entry.duration or 1.0)
    glowObj.flipAnim:SetFlipBookFrameWidth(entry.frameW or 0)
    glowObj.flipAnim:SetFlipBookFrameHeight(entry.frameH or 0)
    glowObj.flipTex:SetDesaturated(true)
    glowObj.flipTex:SetVertexColor(cr, cg, cb)
    glowObj.flipTex:Show()
    glowObj.animGroup:Play()
end

-- Exportar para que el bloque de dispelGlow pueda reutilizar el despachador
ns._ActivateGlowStyle = ActivateGlowStyle
ns._BuildGlowFrameSet = BuildGlowFrameSet

-- Activa o reutiliza el glow pandémico en una ranura de debuff. Delega
-- el dispatch de estilo visual a ActivateGlowStyle, compartiendo la
-- lógica con dispelGlow sin duplicar las ramas de branching.
local function StartPandemicGlow(slot, slotSize)
    local pg = BuildGlowFrameSet(slot, "pandemicGlow", 0)
    local styleIdx = ns.GetPandemicGlowStyle()
    if styleIdx < 1 or styleIdx > #PANDEMIC_GLOW_STYLES then styleIdx = 1 end

    -- Reusar glow activo si el estilo no cambió
    if pg.active and pg.styleIdx == styleIdx then
        pg.wrapper:Show()
        return
    end
    -- Cambio de estilo: detener el anterior antes de activar el nuevo
    if pg.active then StopPandemicGlow(slot) end

    local cr, cg, cb = ns.GetPandemicGlowColor()
    ActivateGlowStyle(pg, PANDEMIC_GLOW_STYLES[styleIdx], slotSize or 26, cr, cg, cb)

    pg.wrapper:Show()
    pg.active = true
    pg.styleIdx = styleIdx
end

-- Aplica glow pandémico usando el objeto de duración secret-safe.
-- Los valores secretos de IsZero/EvaluateRemainingPercent van SOLO a
-- APIs de widget Blizzard (SetAlpha), nunca a comparaciones Lua.
-- Las ranuras activas se registran para un tick ligero de alpha.
local function ApplyPandemicGlow(slot)
    local durObj = slot._durationObj
    if not durObj or not pandemicCurve then
        StopPandemicGlow(slot)
        return
    end

    StartPandemicGlow(slot, GetDebuffIconSize())

    local wrapper = slot.pandemicGlow and slot.pandemicGlow.wrapper
    if not wrapper then return end

    wrapper:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(
        durObj:IsZero(), 0,
        durObj:EvaluateRemainingPercent(pandemicCurve)
    ))
    activePandemicSlots[slot] = true
    if ns.ArmPandemicTick then ns.ArmPandemicTick() end
end
ns.StopPandemicGlow = StopPandemicGlow
ns.ApplyPandemicGlow = ApplyPandemicGlow
end -- do (glow engine)

-- Bloque de dispelGlow: reutiliza el despachador unificado ActivateGlowStyle
-- almacenado en ns para evitar duplicar las ramas de estilo visual.
do
    -- Parámetros procedural fijos para dispel: intensidad visual distinta
    -- de la configuración del usuario para pandemic.
    local DISPEL_PROC_CFG = { lines = 8, thickness = 2, speed = 4 }

    local function StopDispelGlow(slot)
        local dg = slot.dispelGlow
        if not dg or not dg.active then return end
        if dg.animGroup then dg.animGroup:Stop() end
        if dg.flipTex then dg.flipTex:Hide() end
        ns.StopProceduralAnts(dg.wrapper)
        ns.StopButtonGlow(dg.wrapper)
        ns.StopAutoCastShine(dg.wrapper)
        dg.wrapper:Hide()
        dg.active = false
    end

    -- Resuelve la alpha del wrapper para dispelGlow según typeColor.
    -- Si hay color de tipo de dispel usa su canal alpha; si no, opaco.
    local function ResolveDispelAlpha(wrapper, typeColor)
        if typeColor then
            local _, _, _, a = typeColor:GetRGBA()
            wrapper:SetAlpha(a)
        else
            wrapper:SetAlpha(1)
        end
    end

    -- Activa el glow de dispel en una ranura de buff enemigo.
    -- Usa ns._ActivateGlowStyle para el dispatch de estilo visual;
    -- usa DISPEL_PROC_CFG para sobreescribir los parámetros procedural.
    local function StartDispelGlow(slot, slotSize, typeColor)
        local dg = ns._BuildGlowFrameSet(slot, "dispelGlow", 1)
        local styleIdx = ns.GetDispelGlowStyle()
        if styleIdx < 1 or styleIdx > #PANDEMIC_GLOW_STYLES then styleIdx = 1 end
        local sz = slotSize or 24

        local cr, cg, cb = ns.GetDispelGlowColor(typeColor)

        -- Reusar glow activo si el estilo no cambió
        if dg.active and dg.styleIdx == styleIdx then
            dg.wrapper:Show()
            ResolveDispelAlpha(dg.wrapper, typeColor)
            return
        end
        if dg.active then StopDispelGlow(slot) end

        ns._ActivateGlowStyle(dg, PANDEMIC_GLOW_STYLES[styleIdx], sz, cr, cg, cb, DISPEL_PROC_CFG)

        dg.wrapper:Show()
        dg.active = true
        dg.styleIdx = styleIdx
        ResolveDispelAlpha(dg.wrapper, typeColor)
    end

    ns.StopDispelGlow = StopDispelGlow
    ns.StartDispelGlow = StartDispelGlow
end

-- Forward declaration (defined later in the class power section)
local GetClassPowerTopPush
-- Aura layout subsystem
--  Sistema de layout de auras — separa cálculo geométrico de aplicación.
--
--  Paso 1  (ResolveOffsets):  slotKey → DB key → posición → XY.
--  Paso 2  (BuildPlacement):  genera tabla de descriptores de ancla
--            {pt, rel, relPt, x, y}[1..count] sin tocar frames.
--  Paso 3  (Commit):          aplica descriptores sobre frames reales.
--
--  MeasureLateralExtent + CommitArrowAnchors sustituyen la antigua
--  PositionArrowsOutsideAuras con la misma separación cálculo/aplicación.
-- Aura layout API
ns._AuraLayout = {
    -- Mapeo slot lógico → clave de posición en la DB.
    -- Desacopla la identidad del slot de la ruta de almacenamiento.
    SLOT_DB_MAP = {
        debuffSlot     = "debuffSlot",
        buffSlot       = "buffSlot",
        ccSlot         = "ccSlot",
        classification = "classificationSlot",
        raidMarker     = "raidMarkerPos",
    },
}

--- Paso 1: resuelve offsets XY desde la DB para un slotKey de aura.
--- Mapea slotKey → DB key → posición guardada → GetSlotOffsets.
function ns._AuraLayout.ResolveOffsets(slotKey)
    if slotKey == "classification" then
        return tonumber(db and db.classificationXOffset) or 0,
            tonumber(db and db.classificationYOffset) or 0
    end
    local dbKey = ns._AuraLayout.SLOT_DB_MAP[slotKey]
    if not dbKey then return 0, 0 end
    local pos = (db and db[dbKey]) or defaults[dbKey]
    if not pos or pos == "none" then return 0, 0 end
    return GetSlotOffsets(pos)
end

local GetTopTextVerticalLift

--- Paso 2: construye descriptores de anclaje para count iconos.
--- Retorna nil si count < 1 o el slot no es reconocido.
--- Cada entry: {pt, rel, relPt, x, y} — listo para PP.Point directo.
function ns._AuraLayout.BuildPlacement(slot, count, sizeW, gap, plate, dx, dy, slotKey)
    if count < 1 then return nil end
    dx, dy = dx or 0, dy or 0
    local step = sizeW + gap
    local anchors = {}

    if slot == "left" or slot == "right" then
        -- Lateral: iconos en columna pegados al borde de la barra de vida
        local lateral = ns.SideAuraXOffsetFor(plate, slot)
        local sign = (slot == "left") and -1 or 1
        local pt   = (slot == "left") and "BOTTOMRIGHT" or "BOTTOMLEFT"
        local rel  = (slot == "left") and "BOTTOMLEFT"  or "BOTTOMRIGHT"
        for i = 1, count do
            anchors[i] = { pt = pt, rel = plate.health, relPt = rel,
                x = sign * (lateral + (i - 1) * step) + dx, y = dy }
        end

    elseif slot == "top" or slot == "bottom" then
        -- El slot superior se ancla por Y al contenido top activo, pero los debuffs
        -- pueden alinearse horizontalmente al ancho de la barra.
        local anchor, relFrame, baseY
        if slot == "bottom" then
            anchor, relFrame, baseY = "TOP", plate.cast, -2 + dy
        else
            local topEl = GetTextSlot("textSlotTop")
            relFrame = (topEl == "enemyName" and plate.name)
                    or (topEl == "healthNumber" and plate.hpNumber)
                    or (topEl ~= "none" and plate.hpText)
                    or plate.health
            local push = (topEl == "none") and GetClassPowerTopPush(plate) or 0
            anchor = "BOTTOM"
            baseY = GetDebuffYOffset() + push + dy
            if slotKey == "debuffSlot" then
                baseY = baseY + GetTopTextVerticalLift(plate, topEl)
                -- A raid marker over the name sits under the debuff row.
                if GetRaidMarkerPos() == "top" and plate.raidFrame and plate.raidFrame:IsShown() then
                    baseY = baseY + GetRaidMarkerSize() + 2
                end
            end
        end
        if slot == "top" and slotKey == "debuffSlot" then
            local align = GetTopDebuffAlign()
            local topOffsetX = dx + GetTopDebuffOffsetX()
            local halfN = (count + 1) * 0.5
            if align == "left" then
                for i = 1, count do
                    anchors[i] = { pt = "BOTTOMLEFT", rel = plate.health, relPt = "TOPLEFT",
                        x = ((i - 1) * step) + topOffsetX, y = baseY }
                end
            elseif align == "right" then
                for i = 1, count do
                    anchors[i] = { pt = "BOTTOMRIGHT", rel = plate.health, relPt = "TOPRIGHT",
                        x = (-((count - i) * step)) + topOffsetX, y = baseY }
                end
            else
                for i = 1, count do
                    anchors[i] = { pt = "BOTTOM", rel = plate.health, relPt = "TOP",
                        x = (i - halfN) * step + topOffsetX, y = baseY }
                end
            end
        else
            local relPt = (slot == "bottom") and "BOTTOM" or "TOP"
            local halfN = (count + 1) * 0.5
            for i = 1, count do
                anchors[i] = { pt = anchor, rel = relFrame, relPt = relPt,
                    x = (i - halfN) * step + dx, y = baseY }
            end
        end

    elseif slot == "topleft" or slot == "topright" then
        -- Esquinas: primer icono en la esquina, los siguientes crecen según DB
        local isLeft  = (slot == "topleft")
        local db      = KullThranUINameplatesDB
        local growKey = isLeft and "topleftSlotGrowth" or "toprightSlotGrowth"
        local growDir = (db and db[growKey]) or defaults[growKey]
        local pt      = isLeft and "BOTTOMLEFT"  or "BOTTOMRIGHT"
        local rel     = isLeft and "TOPLEFT"     or "TOPRIGHT"
        local originX = (isLeft and -2 or 2) + dx
        local originY = GetDebuffYOffset() + GetClassPowerTopPush(plate) + dy
        -- Vectores de avance según dirección de crecimiento configurada
        local gx, gy = 0, 0
        if growDir == "up" then
            gy = step
        elseif (isLeft and growDir == "right") or (not isLeft and growDir == "left") then
            gx = (isLeft and 1 or -1) * step
        else
            gx = (isLeft and -1 or 1) * step
        end
        for i = 1, count do
            local off = i - 1
            anchors[i] = { pt = pt, rel = plate.health, relPt = rel,
                x = originX + off * gx, y = originY + off * gy }
        end
    end

    return (#anchors > 0) and anchors or nil
end

--- Paso 3: aplica descriptores de ancla sobre los frames.
--- No calcula geometría; sólo itera y ejecuta PP.Point.
function ns._AuraLayout.Commit(frames, count, anchors)
    if not anchors then return end
    for i = 1, count do
        local a = anchors[i]
        if a and frames[i] then
            frames[i]:ClearAllPoints()
            PP.Point(frames[i], a.pt, a.rel, a.relPt, a.x, a.y)
        end
    end
end

-- Compatibilidad: firma legada usada desde Nameplates_Options y código externo.
-- (frames, count, slot, plate, sizeW, sizeH, gap, xOff, yOff)
function ns.PositionAuraSlot(frames, count, slot, plate, sizeW, _, gap, xOff, yOff, slotKey)
    ns._AuraLayout.Commit(frames, count,
        ns._AuraLayout.BuildPlacement(slot, count, sizeW, gap, plate, xOff, yOff, slotKey))
end

-- Offset XY para un slot de texto (ej: "textSlotTop")
local function GetTextSlotOffsets(slotKey)
    local xOff = (db and db[slotKey .. "XOffset"]) or 0
    local yOff = (db and db[slotKey .. "YOffset"]) or 0
    return xOff, yOff
end

-- Tamaño de fuente para un slot de texto (ej: "textSlotTop")
local function GetTextSlotSize(slotKey)
    local v = (db and db[slotKey .. "Size"]) or defaults[slotKey .. "Size"] or 10
    if v == (defaults[slotKey .. "Size"] or 10) and ns.ThemeBlizzText and ns.ThemeBlizzText()
        and (slotKey == "textSlotLeft" or slotKey == "textSlotRight") then
        return v + 2
    end
    return v
end
ns.GetTextSlotSize = GetTextSlotSize

-- Color para un slot de texto (ej: "textSlotTop")
local function GetTextSlotColor(slotKey)
    local c = (db and db[slotKey .. "Color"]) or defaults[slotKey .. "Color"]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

--- Mide la extensión lateral (px) que ocupan auras, raid marker y
--- clasificación en cada lado de la placa. Usado por CommitArrowAnchors
--- para apartar las flechas lo suficiente.
--- @return number extL, number extR
GetTopTextVerticalLift = function(plate, topElement)
    if not plate or topElement == "none" then
        return 0
    end

    local _, topYOffset = GetTextSlotOffsets("textSlotTop")
    local topFontSize = GetTextSlotSize("textSlotTop")

    -- Evita GetTop() sobre regiones restringidas: aproximamos la altura del
    -- texto superior con su offset vertical y el tamaño de fuente configurado.
    return 4 + GetNameYOffset() + topYOffset + topFontSize
end
ns.GetTopTextVerticalLift = GetTopTextVerticalLift

function ns._AuraLayout.MeasureLateralExtent(plate)
    local debuffSlot, buffSlot, ccSlot = GetAuraSlots()
    local spacing   = GetAuraSpacing()
    local lateralL  = ns.SideAuraXOffsetFor(plate, "left")
    local lateralR  = ns.SideAuraXOffsetFor(plate, "right")

    -- Cuenta iconos visibles en un pool de frames hasta cap
    local function CountVis(frameList, cap)
        local n = 0
        for i = 1, cap do
            if frameList[i] and frameList[i]:IsShown() then n = n + 1 end
        end
        return n
    end

    local extL, extR = 0, 0

    -- Grupos de auras (debuffs, buffs, cc) en slot lateral
    local groups = {
        { pos = debuffSlot, pool = plate.debuffs or {}, cap = 6, sz = GetDebuffIconSize(), key = "debuffSlot" },
        { pos = buffSlot,   pool = plate.buffs   or {}, cap = 4, sz = GetBuffIconSize(),   key = "buffSlot"  },
        { pos = ccSlot,     pool = plate.cc      or {}, cap = 2, sz = GetCCIconSize(),     key = "ccSlot"    },
    }
    for _, g in ipairs(groups) do
        if g.pos == "left" or g.pos == "right" then
            local vis = CountVis(g.pool, g.cap)
            if vis > 0 then
                local xo  = (select(1, ns._AuraLayout.ResolveOffsets(g.key)))
                local lateralPx = (g.pos == "left") and lateralL or lateralR
                local raw = lateralPx + (vis - 1) * (spacing + g.sz) + g.sz
                local adj = (g.pos == "left") and (raw - xo) or (raw + xo)
                if g.pos == "left" then
                    extL = (adj > extL) and adj or extL
                else
                    extR = (adj > extR) and adj or extR
                end
            end
        end
    end

    -- Elementos sueltos laterales: raid marker y clasificación
    local singles = {
        { posFunc = GetRaidMarkerPos,      sizeFunc = GetRaidMarkerSize,    frame = plate.raidFrame,  key = "raidMarker"     },
        { posFunc = GetClassificationSlot, sizeFunc = GetRareEliteIconSize, frame = plate.classFrame, key = "classification" },
    }
    -- Forever style: the classification icon is part of the style's own room (ThemeLateralExtent).
    local themeClassification = ns.ThemeClassificationLeft and ns.ThemeClassificationLeft()
    for _, s in ipairs(singles) do
        if s.frame and s.frame:IsShown() and not (themeClassification and s.key == "classification") then
            local side = s.posFunc()
            if side == "topright" and s.key == "classification" then
                local xo = select(1, ns._AuraLayout.ResolveOffsets(s.key))
                extR = math.max(extR, 2 + s.sizeFunc() * 0.5 + xo)
            elseif side == "left" or side == "right" then
                local sz = s.sizeFunc()
                local xo = (select(1, ns._AuraLayout.ResolveOffsets(s.key)))
                local ext = (side == "left") and (lateralL + sz - xo) or (lateralR + sz + xo)
                if side == "left" then
                    extL = (ext > extL) and ext or extL
                else
                    extR = (ext > extR) and ext or extR
                end
            end
        end
    end

    return extL, extR
end

--- Posiciona las flechas de target fuera del espacio lateral ocupado.
--- Combina MeasureLateralExtent (cálculo) con el anclaje real (commit).
function ns._AuraLayout.CommitArrowAnchors(plate)
    if not (plate.leftArrow and plate.rightArrow) then return end
    if not (plate.leftArrow:IsShown() or plate.rightArrow:IsShown()) then return end
    local extL, extR = ns._AuraLayout.MeasureLateralExtent(plate)
    if ns.ThemeLateralExtent then
        local tl, tr = ns.ThemeLateralExtent(plate)
        extL, extR = math.max(extL, tl), math.max(extR, tr)
    end
    local arrowGap = 8
    plate.leftArrow:ClearAllPoints()
    plate.rightArrow:ClearAllPoints()
    PP.Point(plate.leftArrow,  "RIGHT", plate.health, "LEFT",  -(extL + arrowGap), 0)
    PP.Point(plate.rightArrow, "LEFT",  plate.health, "RIGHT",   extR + arrowGap,  0)
end

-- Compatibilidad: alias legado para llamadas externas
ns.PositionArrowsOutsideAuras = function(plate) ns._AuraLayout.CommitArrowAnchors(plate) end

-- Target and focus adornments: ns._ResolveTargetVisuals answers what a plate needs and
-- ns._AcquireVisualLayer builds its layers (Nameplates_VisualLayers.lua). ApplyTarget and
-- UpdateHealthColor below commit the result: showing, hiding and recolouring.
ns.NameplatesVisualLayers.Setup({
    client = "retail",
    PP = PP,
    defaults = defaults,
    GetDB = function() return db end,
    GetTargetGlowStyle = GetTargetGlowStyle,
    GetShowClassPower = GetShowClassPower,
})

-- Nameplate border (shared with the options style samples, Nameplates_StyleSample.lua):
ns.PLATE_BORDER_TEX = {
    kullthran = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\border-colorless.png",
    simple    = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\border-simple.png",
}
ns.PLATE_BORDER_C = 6  -- tamaño de esquina en px

-- Blueprint de segmentos: corners [1-4] y edges [5-8].
-- Cada edge referencia corners por índice para sus dos anclas.
ns._PlateBorderSegs = {
    -- esquinas: {t, point, texCoord}
    { t = "c", pt = "TOPLEFT",     tc = {0, 0.5, 0, 0.5} },
    { t = "c", pt = "TOPRIGHT",    tc = {0.5, 1, 0, 0.5} },
    { t = "c", pt = "BOTTOMLEFT",  tc = {0, 0.5, 0.5, 1} },
    { t = "c", pt = "BOTTOMRIGHT", tc = {0.5, 1, 0.5, 1} },
    -- aristas: {t, a1pt, a1corner, a1rel, a2pt, a2corner, a2rel, dim, texCoord}
    { t = "e", a1pt = "TOPLEFT",     a1c = 1, a1r = "TOPRIGHT",    a2pt = "TOPRIGHT",    a2c = 2, a2r = "TOPLEFT",     dim = "h", tc = {0.5, 0.5, 0, 0.5} },
    { t = "e", a1pt = "BOTTOMLEFT",  a1c = 3, a1r = "BOTTOMRIGHT", a2pt = "BOTTOMRIGHT", a2c = 4, a2r = "BOTTOMLEFT",  dim = "h", tc = {0.5, 0.5, 0.5, 1} },
    { t = "e", a1pt = "TOPLEFT",     a1c = 1, a1r = "BOTTOMLEFT",  a2pt = "BOTTOMLEFT",  a2c = 3, a2r = "TOPLEFT",     dim = "w", tc = {0, 0.5, 0.5, 0.5} },
    { t = "e", a1pt = "TOPRIGHT",    a1c = 2, a1r = "BOTTOMRIGHT", a2pt = "BOTTOMRIGHT", a2c = 4, a2r = "TOPRIGHT",    dim = "w", tc = {0.5, 1, 0.5, 0.5} },
}

-- Paso 1: construye un frame con texturas recorriendo el blueprint.
function ns.BuildPlateBorder(parent, tex, color)
    local f = CreateFrame("Frame", nil, parent)
    f:SetFrameLevel(parent:GetFrameLevel() + 5)
    f:SetAllPoints()
    f._texs = {}
    local corners = {}
    for i, seg in ipairs(ns._PlateBorderSegs) do
        local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetTexture(tex)
        t:SetVertexColor(color.r, color.g, color.b)
        t:SetTexCoord(seg.tc[1], seg.tc[2], seg.tc[3], seg.tc[4])
        f._texs[i] = t
        if seg.t == "c" then
            t:SetSize(ns.PLATE_BORDER_C, ns.PLATE_BORDER_C)
            t:SetPoint(seg.pt, f, seg.pt, 0, 0)
            corners[i] = t
        else
            if seg.dim == "h" then t:SetHeight(ns.PLATE_BORDER_C) else t:SetWidth(ns.PLATE_BORDER_C) end
            t:SetPoint(seg.a1pt, corners[seg.a1c], seg.a1r, 0, 0)
            t:SetPoint(seg.a2pt, corners[seg.a2c], seg.a2r, 0, 0)
        end
    end
    return f
end
-- end plate border

local plateEventProfileLabels = {}
local frameCache = CreateFramePool("Frame", UIParent, nil, nil, false, function(plate)
    -- Keep text and textures as independent regions. Flattening a 1x1
    -- child frame can rasterize the whole nameplate and stretch it while
    -- Blizzard changes the projected scale with camera movement.
    plate:SetFlattensRenderLayers(false)
    if plate.SetIgnoreParentScale then
        plate:SetIgnoreParentScale(true)
    end
    -- Assembly helpers for plate parts. A spec describes one part (level,
    -- size, anchors, texture, flags) and Configure applies it; `pixel` routes
    -- size and anchors through the pixel-perfect PP helpers.
    local function Configure(part, spec)
        if spec.level then part:SetFrameLevel(spec.level) end
        if spec.levelOf then part:SetFrameLevel(spec.levelOf[1]:GetFrameLevel() + spec.levelOf[2]) end
        if spec.size then
            if spec.pixel then PP.Size(part, spec.size[1], spec.size[2]) else part:SetSize(spec.size[1], spec.size[2]) end
        end
        if spec.width then
            if spec.pixel then PP.Width(part, spec.width) else part:SetWidth(spec.width) end
        end
        if spec.height then part:SetHeight(spec.height) end
        for _, anchor in ipairs(spec.at or {}) do
            if spec.pixel then PP.Point(part, unpack(anchor)) else part:SetPoint(unpack(anchor)) end
        end
        if spec.fill then
            if spec.fill == true then part:SetAllPoints() else part:SetAllPoints(spec.fill) end
        end
        if spec.tex then part:SetTexture(spec.tex) end
        if spec.color then part:SetColorTexture(unpack(spec.color)) end
        if spec.coords then part:SetTexCoord(unpack(spec.coords)) end
        if spec.blend then part:SetBlendMode(spec.blend) end
        if spec.alpha then part:SetAlpha(spec.alpha) end
        if spec.barTex then
            part:SetStatusBarTexture(spec.barTex)
            if spec.barLayer then part:GetStatusBarTexture():SetDrawLayer(unpack(spec.barLayer)) end
            if spec.barAlpha then part:GetStatusBarTexture():SetAlpha(spec.barAlpha) end
        end
        if spec.barColor then part:SetStatusBarColor(unpack(spec.barColor)) end
        if spec.range then part:SetMinMaxValues(unpack(spec.range)) end
        if spec.reverse ~= nil then part:SetReverseFill(spec.reverse) end
        if spec.clip ~= nil then part:SetClipsChildren(spec.clip) end
        if spec.fontSize then SetFSFont(part, spec.fontSize, GetNPOutline()) end
        if spec.justify then part:SetJustifyH(spec.justify) end
        if spec.wrap ~= nil then part:SetWordWrap(spec.wrap) end
        if spec.lines then part:SetMaxLines(spec.lines) end
        if spec.hide then part:Hide() end
        return part
    end
    local function Make(kind, parent, spec)
        local part
        if kind == "tex" then
            part = parent:CreateTexture(nil, spec.layer, nil, spec.sub)
        elseif kind == "text" then
            part = parent:CreateFontString(nil, "OVERLAY")
        else
            part = CreateFrame(kind, nil, parent)
        end
        if spec.field then plate[spec.field] = part end
        return Configure(part, spec)
    end

    local WHITE_TEX = "Interface\\Buttons\\WHITE8x8"
    local ABSORB_TEX = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\absorb-default.png"
    local barW, barH = GetHealthBarWidth(), GetHealthBarHeight()

    local health = Make("StatusBar", plate, {
        field = "health", level = 10, clip = false, barTex = WHITE_TEX, size = { barW, barH },
        at = { { "CENTER", plate, "CENTER", 0, GetNameplateYOffset() } },
    })
    Make("tex", health, { field = "healthBG", layer = "BACKGROUND", fill = true, color = { 0.12, 0.12, 0.12, 1.0 } })
    -- Thin vertical marker drawn at a configurable health percentage.
    Make("tex", health, {
        field = "hashLine", layer = "OVERLAY", sub = 3, color = { 1, 1, 1, 0.8 }, width = 2, hide = true,
        at = { { "TOP", health, "TOP", 0, 0 }, { "BOTTOM", health, "BOTTOM", 0, 0 } },
    })
    local healthFill = health:GetStatusBarTexture()
    Make("StatusBar", health, {
        field = "absorb", barTex = ABSORB_TEX, barLayer = { "ARTWORK", 1 }, barColor = { 1, 1, 1, 0.8 }, reverse = true,
        at = { { "TOPRIGHT", healthFill, "TOPRIGHT", 0, 0 }, { "BOTTOMRIGHT", healthFill, "BOTTOMRIGHT", 0, 0 } },
        width = barW, height = barH, levelOf = { health, 0 },
    })
    Make("StatusBar", health, {
        field = "absorbOverflow", barTex = ABSORB_TEX, barLayer = { "ARTWORK", 1 }, barColor = { 1, 1, 1, 0.8 }, reverse = false,
        at = { { "TOPLEFT", health, "TOPRIGHT", 0, 0 }, { "BOTTOMLEFT", health, "BOTTOMRIGHT", 0, 0 } },
        width = 0, levelOf = { health, 0 }, hide = true,
    })
    Make("tex", health, {
        field = "absorbOverflowDivider", layer = "OVERLAY", sub = 7, color = { 0, 0, 0, 1 }, width = 1, hide = true,
        at = { { "TOPRIGHT", health, "TOPRIGHT", 0, 0 }, { "BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0 } },
    })
    local calc = CreateUnitHealPredictionCalculator and CreateUnitHealPredictionCalculator()
    plate.hpCalculator = calc
    if calc and calc.SetMaximumHealthMode then
        calc:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.WithAbsorbs)
        calc:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)
    end
    local function AddBorder(parent)
        local PP = KullThranUI and KullThranUI.PP
        if PP then
            PP.CreateBorder(parent, 0, 0, 0, 1, 1, "OVERLAY", 5)
        end
    end
-- Nameplate border subsystem
    -- Paso 1 (BuildBorderGeometry): recorre un blueprint de 8 segmentos
    --   (4 esquinas + 4 aristas) para producir las texturas. El blueprint
    --   es estático y compartido por todas las placas.
    -- Paso 2 (SelectBorderVariant / ApplyBorderStyle): decide cuál de
    --   los dos conjuntos (colorless / simple) queda visible.
    -- Paso 3 (TintBorderTextures / ApplyBorderColor): aplica vertex
    --   color a ambos conjuntos en una sola pasada.
    local BORDER_TEX        = ns.PLATE_BORDER_TEX.kullthran
    local BORDER_TEX_SIMPLE = ns.PLATE_BORDER_TEX.simple
    local BuildBorderGeometry = ns.BuildPlateBorder

    local bc = { r = 0, g = 0, b = 0 }
    bc.r, bc.g, bc.b = GetBorderColor()
    plate.borderFrame        = BuildBorderGeometry(plate.health, BORDER_TEX,        bc)
    plate._simpleBorderFrame = BuildBorderGeometry(plate.health, BORDER_TEX_SIMPLE, bc)

    -- Paso 2: selecciona el variante visible según estilo de DB
    function plate:ApplyBorderStyle()
        local style = GetBorderStyle()
        if style == "none" then
            plate.borderFrame:Hide()
            plate._simpleBorderFrame:Hide()
        elseif style == "simple" then
            plate.borderFrame:Hide()
            plate._simpleBorderFrame:Show()
        else
            plate.borderFrame:Show()
            plate._simpleBorderFrame:Hide()
        end
    end
    -- Paso 3: aplica vertex color a ambos conjuntos de texturas
    function plate:ApplyBorderColor()
        local cr, cg, cb = GetBorderColor()
        for _, tex in ipairs(plate.borderFrame._texs) do tex:SetVertexColor(cr, cg, cb) end
        for _, tex in ipairs(plate._simpleBorderFrame._texs) do tex:SetVertexColor(cr, cg, cb) end
    end
    plate:ApplyBorderStyle()
    -- Target glow, flechas y focus overlay se crean lazy bajo demanda
    -- (ns._AcquireVisualLayer) ya que solo
    -- 1 placa a la vez los muestra. Ahorra ~14 objetos por placa.
    -- Frame overlay de texto: renderiza sobre el stripe de focus (nivel +1)
    -- Text overlay: draws above the focus stripe (level +7).
    local textLayer = Make("Frame", plate, { field = "healthTextFrame", fill = health, levelOf = { health, 7 } })
    Make("text", textLayer, {
        field = "hpText", fontSize = 10, pixel = true, at = { { "RIGHT", health, "RIGHT", -2, 0 } },
    })
    Make("text", textLayer, {
        field = "hpNumber", fontSize = 10, at = { { "CENTER", health, "CENTER", 0, 0 } }, hide = true,
    })
    Make("tex", textLayer, {
        field = "highlight", layer = "OVERLAY", sub = 6, fill = true, color = { 1, 1, 1, 0.3 }, hide = true,
    })
    -- Top text overlay: above the health bar and its borders so the top slot text is never covered.
    local topLayer = Make("Frame", plate, { field = "topTextFrame", fill = health, levelOf = { health, 6 } })
    Make("text", plate, {
        field = "name", fontSize = GetEnemyNameTextSize(), pixel = true, wrap = false, lines = 1,
        at = { { "BOTTOM", health, "TOP", 0, 4 } }, width = math.max(GetHealthBarWidth(), 20),
    })
    -- Forever level text: independent of the four health/name text slots.
    local levelText = Make("text", topLayer, { field = "level" })
    ApplyLevelTextStyle(levelText)
    Configure(levelText, {
        justify = "RIGHT", wrap = false, lines = 1, width = 0, height = 48, hide = true,
        at = { { "BOTTOMLEFT", health, "TOPLEFT", GetLevelConfigValue("levelXOffset") or 24,
            GetLevelConfigValue("levelYOffset") or 4 } },
    })
    local markerSize = GetRaidMarkerSize()
    local raidHolder = Make("Frame", plate, {
        field = "raidFrame", pixel = true, size = { markerSize, markerSize }, levelOf = { health, 6 }, hide = true,
    })
    Make("tex", raidHolder, {
        field = "raid", layer = "ARTWORK", fill = true, tex = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
    })
    local classSize = GetRareEliteIconSize()
    local classHolder = Make("Frame", plate, {
        field = "classFrame", pixel = true, size = { classSize, classSize }, levelOf = { health, 3 }, hide = true,
        at = { { "LEFT", health, "LEFT", 2, 0 } },
    })
    Make("tex", classHolder, { field = "class", layer = "ARTWORK", fill = true })

    -- The cast bar spans the whole health bar; its icon hangs off the left edge.
    local cast = Make("StatusBar", plate, {
        field = "cast", size = { barW, CAST_H }, barTex = WHITE_TEX, barColor = { 1, 1, 1, 1 }, range = { 0, 1 }, hide = true,
        at = { { "TOPLEFT", health, "BOTTOMLEFT", 0, 0 } },
    })
    local castFill = cast:GetStatusBarTexture()
    Make("tex", cast, { field = "castBG", layer = "BACKGROUND", fill = true, color = { 0.1, 0.1, 0.1, 0.9 } })
    Make("tex", cast, {
        field = "castLeftBorder", layer = "OVERLAY", sub = 7, color = { 0, 0, 0, 1 }, width = 1,
        at = { { "TOPLEFT", cast, "TOPLEFT", 0, 0 }, { "BOTTOMLEFT", cast, "BOTTOMLEFT", 0, 0 } },
    })
    -- The icon frame is parented to the cast bar (hides with it) and anchored to it,
    -- so layout resolves in one pass without frame-to-frame jitter.
    local iconHolder = Make("Frame", cast, {
        field = "castIconFrame", size = { CAST_H, CAST_H }, at = { { "TOPRIGHT", cast, "TOPLEFT", 0, 0 } },
    })
    AddBorder(iconHolder)
    Make("tex", iconHolder, {
        field = "castIcon", layer = "ARTWORK", coords = { 0.08, 0.92, 0.08, 0.92 },
        at = { { "TOPLEFT", iconHolder, "TOPLEFT", 1, -1 }, { "BOTTOMRIGHT", iconHolder, "BOTTOMRIGHT", -1, 1 } },
    })
    Make("tex", cast, {
        field = "castSpark", layer = "OVERLAY", sub = 1, blend = "ADD", size = { 8, CAST_H },
        tex = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\cast_spark.tga",
        at = { { "CENTER", castFill, "RIGHT", 0, 0 } },
    })
    local shieldH = CAST_H * 0.75
    local shieldHolder = Make("Frame", cast, {
        field = "castShieldFrame", size = { shieldH * (29 / 35), shieldH }, levelOf = { iconHolder, 5 }, hide = true,
        at = { { "CENTER", cast, "LEFT", 0, 0 } },
    })
    Make("tex", shieldHolder, {
        field = "castShield", layer = "OVERLAY", fill = true,
        tex = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\shield.png",
    })
    Make("tex", cast, {
        field = "castBarOverlay", layer = "ARTWORK", sub = 2, fill = castFill, tex = WHITE_TEX, alpha = 0,
    })
    -- Kick tick: a clipping frame holds two invisible StatusBars plus one visible tick.
    -- The positioner follows the cast's elapsed time, the marker follows the kick's remaining
    -- cooldown, and the tick sits on the right edge of the marker's fill.
    local kickClip = Make("Frame", cast, { field = "kickClip", fill = cast, clip = true })
    local positioner = Make("StatusBar", kickClip, {
        field = "kickPositioner", barTex = WHITE_TEX, barAlpha = 0, levelOf = { cast, 1 }, hide = true,
        at = { { "CENTER", cast } },
    })
    local marker = Make("StatusBar", kickClip, {
        field = "kickMarker", barTex = WHITE_TEX, barAlpha = 0, clip = true, levelOf = { cast, 2 }, hide = true,
        size = { 1, 1 }, -- resized later in UpdateKickTick
        at = { { "LEFT", positioner:GetStatusBarTexture(), "RIGHT" } },
    })
    Make("tex", marker, {
        field = "kickTick", layer = "OVERLAY", sub = 3, color = { 1, 1, 1, 1 }, width = 2, hide = true,
        at = { { "TOP", marker, "TOP", 0, 0 }, { "BOTTOM", marker, "BOTTOM", 0, 0 },
            { "LEFT", marker:GetStatusBarTexture(), "RIGHT" } },
    })
    Make("text", cast, {
        field = "castName", fontSize = 10, justify = "LEFT", wrap = false, lines = 1,
        at = { { "LEFT", cast, "LEFT", 5, 0 } },
    })
    Make("text", cast, {
        field = "castTarget", fontSize = 10, justify = "RIGHT", wrap = false, lines = 1,
        at = { { "RIGHT", cast, "RIGHT", -3, 0 } },
    })
    plate.debuffs = {}
    for i = 1, 4 do
        local d = CreateFrame("Frame", nil, plate)
        d:SetFrameLevel(800)
        PP.Size(d, 26, 26)
        PP.Point(d, "BOTTOM", plate.name, "TOP", (i - 2.5) * 30, 2)
        AddBorder(d)
        d.icon = d:CreateTexture(nil, "ARTWORK")
        PP.Point(d.icon, "TOPLEFT", d, "TOPLEFT", 1, -1)
        PP.Point(d.icon, "BOTTOMRIGHT", d, "BOTTOMRIGHT", -1, 1)
        d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        d.cd = CreateFrame("Cooldown", nil, d, "CooldownFrameTemplate")
        PP.Point(d.cd, "TOPLEFT", d, "TOPLEFT", 1, -1)
        PP.Point(d.cd, "BOTTOMRIGHT", d, "BOTTOMRIGHT", -1, 1)
        d.cd:SetFrameLevel(d:GetFrameLevel() + 2)
        if d.cd.SetDrawSwipe then d.cd:SetDrawSwipe(true) end
        if d.cd.SetDrawEdge then d.cd:SetDrawEdge(false) end
        if d.cd.SetDrawBling then d.cd:SetDrawBling(false) end
        if d.cd.SetReverse then d.cd:SetReverse(true) end
        if d.cd.SetHideCountdownNumbers then d.cd:SetHideCountdownNumbers(false) end
        d.count = d.cd:CreateFontString(nil, "OVERLAY")
        SetFSFont(d.count, 11, "OUTLINE")
        PP.Point(d.count, "BOTTOMRIGHT", d, "BOTTOMRIGHT", 1, 1)
        d.count:SetJustifyH("RIGHT")
        local cdRegions = { d.cd:GetRegions() }
        for _, region in ipairs(cdRegions) do
            if region:GetObjectType() == "FontString" then
                d.cd.text = region
                SetFSFont(region, 11, "OUTLINE")
                region:ClearAllPoints()
                PP.Point(region, "TOPLEFT", d, "TOPLEFT", -3, 4)
                region:SetJustifyH("LEFT")
                region:SetTextColor(GetDebuffTextColor())
                break
            end
        end
        d:Hide()
        plate.debuffs[i] = d
    end
    plate.buffs = {}
    for i = 1, 4 do
        local b = CreateFrame("Frame", nil, plate)
        b:SetFrameLevel(800)
        PP.Size(b, 24, 24)
        PP.Point(b, "RIGHT", plate.health, "LEFT", -2 - (i - 1) * 26, 0)
        AddBorder(b)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        PP.Point(b.icon, "TOPLEFT", b, "TOPLEFT", 1, -1)
        PP.Point(b.icon, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        PP.Point(b.cd, "TOPLEFT", b, "TOPLEFT", 1, -1)
        PP.Point(b.cd, "BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
        b.cd:SetFrameLevel(b:GetFrameLevel() + 2)
        if b.cd.SetDrawSwipe then b.cd:SetDrawSwipe(true) end
        if b.cd.SetDrawEdge then b.cd:SetDrawEdge(false) end
        if b.cd.SetDrawBling then b.cd:SetDrawBling(false) end
        if b.cd.SetReverse then b.cd:SetReverse(true) end
        if b.cd.SetHideCountdownNumbers then b.cd:SetHideCountdownNumbers(false) end
        b.count = b.cd:CreateFontString(nil, "OVERLAY")
        SetFSFont(b.count, 9, "OUTLINE")
        PP.Point(b.count, "BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        local bCdRegions = { b.cd:GetRegions() }
        for _, region in ipairs(bCdRegions) do
            if region:GetObjectType() == "FontString" then
                b.cd.text = region
                SetFSFont(region, 12, "OUTLINE")
                region:ClearAllPoints()
                region:SetPoint("CENTER", b, "CENTER", 0, 0)
                break
            end
        end
        b:Hide()
        plate.buffs[i] = b
    end
    


    plate.cc = {}
    for i = 1, 2 do
        local c = CreateFrame("Frame", nil, plate)
        c:SetFrameLevel(800)
        PP.Size(c, 24, 24)
        PP.Point(c, "LEFT", plate.health, "RIGHT", 2 + (i - 1) * 26, 0)
        AddBorder(c)
        c.icon = c:CreateTexture(nil, "ARTWORK")
        PP.Point(c.icon, "TOPLEFT", c, "TOPLEFT", 1, -1)
        PP.Point(c.icon, "BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 1)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        c.cd = CreateFrame("Cooldown", nil, c, "CooldownFrameTemplate")
        PP.Point(c.cd, "TOPLEFT", c, "TOPLEFT", 1, -1)
        PP.Point(c.cd, "BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 1)
        c.cd:SetFrameLevel(c:GetFrameLevel() + 2)
        if c.cd.SetDrawSwipe then c.cd:SetDrawSwipe(true) end
        if c.cd.SetDrawEdge then c.cd:SetDrawEdge(false) end
        if c.cd.SetDrawBling then c.cd:SetDrawBling(false) end
        if c.cd.SetReverse then c.cd:SetReverse(true) end
        if c.cd.SetHideCountdownNumbers then c.cd:SetHideCountdownNumbers(false) end
        local cdRegions = { c.cd:GetRegions() }
        for _, region in ipairs(cdRegions) do
            if region:GetObjectType() == "FontString" then
                c.cd.text = region
                SetFSFont(region, 12, "OUTLINE")
                region:ClearAllPoints()
                region:SetPoint("CENTER", c, "CENTER", 0, 0)
                break
            end
        end
        c:Hide()
        plate.cc[i] = c
    end
    plate:SetScript("OnEvent", function(self, event, ...)
        local handler = self[event]
        if handler then
            local profiler = _G.KT and _G.KT.CombatProfiler
            local label = plateEventProfileLabels[event]
            if not label then
                label = "nameplates.unit." .. tostring(event)
                plateEventProfileLabels[event] = label
            end
            local profileStarted = profiler and profiler:Begin(label)
            handler(self, ...)
            if profileStarted then profiler:End(label, profileStarted) end
        end
    end)
end)
-- Inicializa la base de datos de nameplates. Ejecuta migraciones versionadas
-- (friendly plates v2, tankHasAggro v1, healthBarTexture media v1) y rellena
-- cualquier clave faltante con los valores de `defaults`.
local function InitDB()
    -- Forever can expose the declared SavedVariable after this file has
    -- created its compatibility table. Ask Core for the on-disk table before
    -- applying defaults, otherwise the first session would hide persisted
    -- nameplate settings behind an empty table.
    local rawNameplates = _G.KT_RAW_NAMEPLATES_DB
    if type(rawNameplates) ~= "table" and type(_G.KT_RAW_READ_FUNC) == "function" then
        pcall(_G.KT_RAW_READ_FUNC)
        rawNameplates = _G.KT_RAW_NAMEPLATES_DB
    end
    if type(rawNameplates) == "table"
        and (type(KullThranUINameplatesDB) ~= "table" or next(KullThranUINameplatesDB) == nil) then
        KullThranUINameplatesDB = rawNameplates
        _G.KullThranUINameplatesDB_Forever = rawNameplates
    end
    if not KullThranUINameplatesDB then
        KullThranUINameplatesDB = {}
    end
    db = KullThranUINameplatesDB

    -- Seed missing level-layout keys without overwriting a user's choices.
    -- Old profiles only had showLevel, so its value becomes the enemy-level
    -- fallback while friendly levels remain independently opt-in.
    if not KullThranUINameplatesDB._levelLayoutDefaultsMigrated_v2 then
        local legacyShowLevel = KullThranUINameplatesDB.showLevel
        if KullThranUINameplatesDB.useDynamicNameplateLevelLayout == nil then
            KullThranUINameplatesDB.useDynamicNameplateLevelLayout = true
        end
        if KullThranUINameplatesDB.showLevel == nil then
            KullThranUINameplatesDB.showLevel = false
        end
        if KullThranUINameplatesDB.showEnemyLevel == nil then
            KullThranUINameplatesDB.showEnemyLevel = legacyShowLevel == true
        end
        if KullThranUINameplatesDB.showFriendlyLevel == nil then
            KullThranUINameplatesDB.showFriendlyLevel = false
        end
        KullThranUINameplatesDB._levelLayoutDefaultsMigrated_v2 = true
    end
    if not KullThranUINameplatesDB._friendlyPlateDefaultsMigrated_v2 then
        -- Normalize friendly plates to the intended default behavior:
        -- visible by default, but rendered name-only instead of health bars.
        if KullThranUINameplatesDB._friendlyDefaultsMigrated_v1
            or KullThranUINameplatesDB.showFriendlyPlayers == nil then
            KullThranUINameplatesDB.showFriendlyPlayers = true
        end
        if KullThranUINameplatesDB._friendlyDefaultsMigrated_v1
            or KullThranUINameplatesDB.showFriendlyNPCs == nil then
            KullThranUINameplatesDB.showFriendlyNPCs = true
        end
        if KullThranUINameplatesDB.friendlyNameOnly == nil then
            KullThranUINameplatesDB.friendlyNameOnly = true
        end
        if KullThranUINameplatesDB._friendlyDefaultsMigrated_v1
            or KullThranUINameplatesDB.friendlyShowDefaultNames == nil then
            KullThranUINameplatesDB.friendlyShowDefaultNames = false
        end
        KullThranUINameplatesDB._friendlyDefaultsMigrated_v1 = nil
        KullThranUINameplatesDB._friendlyPlateDefaultsMigrated_v2 = true
    end
    if not KullThranUINameplatesDB._friendlyNameOnlySplitMigrated_v1 then
        -- Keep existing profiles intact while allowing players and NPCs to
        -- switch independently between name-only and health-bar rendering.
        local legacyNameOnly = KullThranUINameplatesDB.friendlyNameOnly ~= false
        if KullThranUINameplatesDB.friendlyPlayerNameOnly == nil then
            KullThranUINameplatesDB.friendlyPlayerNameOnly = legacyNameOnly
        end
        if KullThranUINameplatesDB.friendlyNPCNameOnly == nil then
            KullThranUINameplatesDB.friendlyNPCNameOnly = legacyNameOnly
        end
        KullThranUINameplatesDB._friendlyNameOnlySplitMigrated_v1 = true
    end
    if not KullThranUINameplatesDB._raidMarkerAboveNameMigrated_v1 then
        -- The raid marker moved from the bar's top-right corner to the middle,
        -- just above the name (2026-11-07). Other positions stay as chosen.
        if KullThranUINameplatesDB.raidMarkerPos == "topright" then
            KullThranUINameplatesDB.raidMarkerPos = "top"
        end
        KullThranUINameplatesDB._raidMarkerAboveNameMigrated_v1 = true
    end
    if not KullThranUINameplatesDB._showAllPlayerDebuffsMigrated_v1 then
        -- The previous default only showed auras Blizzard labels as
        -- nameplateShowPersonal. Enable all player-owned debuffs so normal
        -- DoTs are visible on NPC and mob nameplates as well.
        KullThranUINameplatesDB.showAllDebuffs = true
        KullThranUINameplatesDB._showAllPlayerDebuffsMigrated_v1 = true
    end
    if not KullThranUINameplatesDB._classificationSizeMigrated_v2 then
        local saved = KullThranUINameplatesDB
        -- Before the corner change, classification inherited its assigned slot's size.
        -- Repair the first corner migration's 20px fallback using the former default slot.
        local oldSlot = saved._classificationCornerMigrated_v1 and "topleft"
            or saved.classificationSlot or "topleft"
        if not saved._classificationCornerMigrated_v1 or saved.rareEliteIconSize == nil
            or saved.rareEliteIconSize == 20 then
            saved.rareEliteIconSize = tonumber(saved[oldSlot .. "SlotSize"])
                or defaults[oldSlot .. "SlotSize"] or defaults.rareEliteIconSize
        end
        saved._classificationSizeMigrated_v2 = true
    end
    if not KullThranUINameplatesDB._classificationCornerMigrated_v1 then
        local saved = KullThranUINameplatesDB
        local oldSlot = saved.classificationSlot or "topleft"
        if oldSlot ~= "none" and oldSlot ~= "topright" then
            -- Keep the displaced aura/marker enabled in the vacated slot.
            for _, key in ipairs({ "debuffSlot", "buffSlot", "ccSlot", "raidMarkerPos" }) do
                if (saved[key] or defaults[key]) == "topright" then saved[key] = oldSlot end
            end
            saved.classificationSlot = "topright"
        end
        saved._classificationCornerMigrated_v1 = true
    end
    -- The old shared key still decides until a player alignment is saved.
    if KullThranUINameplatesDB.friendlyPlayerNameAlignment == nil then
        KullThranUINameplatesDB.friendlyPlayerNameAlignment = KullThranUINameplatesDB.friendlyNameAlignment
    end
    for k, v in pairs(defaults) do
        if KullThranUINameplatesDB[k] == nil then
            if type(v) == "table" then
                KullThranUINameplatesDB[k] = { r = v.r, g = v.g, b = v.b }
            else
                KullThranUINameplatesDB[k] = v
            end
        end
    end
    if not KullThranUINameplatesDB._barSizeDefaultsMigrated_v1 then
        if KullThranUINameplatesDB.healthBarWidth == 6 then
            KullThranUINameplatesDB.healthBarWidth = defaults.healthBarWidth
        end
        if KullThranUINameplatesDB.healthBarHeight == 17 then
            KullThranUINameplatesDB.healthBarHeight = defaults.healthBarHeight
        end
        KullThranUINameplatesDB._barSizeDefaultsMigrated_v1 = true
    end
    if not KullThranUINameplatesDB._friendlyBarSizeDefaultsMigrated_v2 then
        if KullThranUINameplatesDB.friendlyHealthBarWidth == 150 then
            KullThranUINameplatesDB.friendlyHealthBarWidth = defaults.friendlyHealthBarWidth
        end
        if KullThranUINameplatesDB.friendlyHealthBarHeight == 17 then
            KullThranUINameplatesDB.friendlyHealthBarHeight = defaults.friendlyHealthBarHeight
        end
        KullThranUINameplatesDB._friendlyBarSizeDefaultsMigrated_v2 = true
    end
    if not KullThranUINameplatesDB._castBarStateColorsMigrated_v1 then
        if KullThranUINameplatesDB.castBar == nil then
            KullThranUINameplatesDB.castBar = CopyColor(defaults.castBar)
        end
        if KullThranUINameplatesDB.interruptReady == nil then
            KullThranUINameplatesDB.interruptReady = CopyColor(defaults.interruptReady)
        end
        if KullThranUINameplatesDB.interruptCooldown == nil then
            KullThranUINameplatesDB.interruptCooldown = CopyColor(defaults.interruptCooldown)
        end
        if KullThranUINameplatesDB.castBarUninterruptible == nil
            or ColorsMatch(KullThranUINameplatesDB.castBarUninterruptible, KullThranUINameplatesDB.interruptCooldown)
            or ColorsMatch(KullThranUINameplatesDB.castBarUninterruptible, defaults.interruptCooldown) then
            KullThranUINameplatesDB.castBarUninterruptible = CopyColor(defaults.castBarUninterruptible)
        end
        KullThranUINameplatesDB._castBarStateColorsMigrated_v1 = true
    end
    if not KullThranUINameplatesDB._castBarStateColorsMigrated_v2 then
        local castBar = KullThranUINameplatesDB.castBar or defaults.castBar
        local interruptReady = KullThranUINameplatesDB.interruptReady or defaults.interruptReady
        local legacyCooldown = KullThranUINameplatesDB.interruptCooldown or defaults.interruptCooldown

        if ColorsMatch(castBar, interruptReady) and not ColorsMatch(legacyCooldown, castBar) then
            KullThranUINameplatesDB.castBar = CopyColor(legacyCooldown)
        end

        KullThranUINameplatesDB._castBarStateColorsMigrated_v2 = true
    end
    if not KullThranUINameplatesDB._tankHasAggroEnabledMigrated_v1 then
        KullThranUINameplatesDB.tankHasAggroEnabled = true
        KullThranUINameplatesDB._tankHasAggroEnabledMigrated_v1 = true
    end
    if not KullThranUINameplatesDB._healthBarTextureMediaMigrated_v1 then
        if LEGACY_HEALTH_BAR_TEXTURE_KEYS[KullThranUINameplatesDB.healthBarTexture] then
            KullThranUINameplatesDB.healthBarTexture = defaults.healthBarTexture or "none"
        end
        if LEGACY_HEALTH_BAR_TEXTURE_KEYS[KullThranUINameplatesDB.friendlyPlayerHealthTexture] then
            KullThranUINameplatesDB.friendlyPlayerHealthTexture = defaults.friendlyPlayerHealthTexture or "Melli Reforged"
        end
        if LEGACY_HEALTH_BAR_TEXTURE_KEYS[KullThranUINameplatesDB.friendlyNPCHealthTexture] then
            KullThranUINameplatesDB.friendlyNPCHealthTexture = defaults.friendlyNPCHealthTexture or "Melli Reforged"
        end
        KullThranUINameplatesDB._healthBarTextureMediaMigrated_v1 = true
    end
    if not KullThranUINameplatesDB._auraIconScaleMigrated_v1 then
        for key, oldValue in pairs(LEGACY_ICON_DEFAULTS) do
            local current = KullThranUINameplatesDB[key]
            if current == nil or current == oldValue then
                KullThranUINameplatesDB[key] = defaults[key]
            end
        end
        KullThranUINameplatesDB._auraIconScaleMigrated_v1 = true
    end
    if not KullThranUINameplatesDB._auraIconScaleMigrated_v2 then
        for key, oldValue in pairs(PREVIOUS_ICON_DEFAULTS) do
            local current = KullThranUINameplatesDB[key]
            if current == nil or current == oldValue then
                KullThranUINameplatesDB[key] = defaults[key]
            end
        end
        KullThranUINameplatesDB._auraIconScaleMigrated_v2 = true
    end
    if not KullThranUINameplatesDB._classPowerShapeMigrated_v2 then
        -- v1 of the option auto-filled "circle" from the defaults table, which
        -- blocked the per-style default (KUI Style = pips). Unset it once.
        if KullThranUINameplatesDB.classPowerShape == "circle" then
            KullThranUINameplatesDB.classPowerShape = nil
        end
        KullThranUINameplatesDB._classPowerShapeMigrated_v2 = true
    end
    if not KullThranUINameplatesDB._classPowerDefaultMigrated_v1 then
        -- Older Forever profiles stored the old false default explicitly,
        -- which prevented the combo-point watcher from ever starting.
        if KullThranUINameplatesDB.showClassPower == nil
            or KullThranUINameplatesDB.showClassPower == false then
            KullThranUINameplatesDB.showClassPower = true
        end
        KullThranUINameplatesDB._classPowerDefaultMigrated_v1 = true
    end
    if not KullThranUINameplatesDB._debuffExpiryGlowMigrated_v1 then
        if KullThranUINameplatesDB.debuffExpiryGlow == nil or KullThranUINameplatesDB.debuffExpiryGlow == false then
            KullThranUINameplatesDB.debuffExpiryGlow = true
        end
        KullThranUINameplatesDB._debuffExpiryGlowMigrated_v1 = true
    end
end

local function IsNameplatesEnabled()
    return not (KullThranUINameplatesDB and KullThranUINameplatesDB.enable == false)
end
local kickSpellsByClass = {
    DEATHKNIGHT = {47528},
    WARRIOR = {6552},
    WARLOCK = {19647, 89766, 119910, 1276467, 132409},
    SHAMAN = {57994},
    ROGUE = {1766},
    PRIEST = {15487},
    PALADIN = {31935, 96231},
    MONK = {116705},
    MAGE = {2139},
    HUNTER = {187707, 147362},
    EVOKER = {351338},
    DRUID = {38675, 78675, 106839},
    DEMONHUNTER = {183752},
}
local activeKickSpell
-- Comprueba si el jugador puede usar un hechizo de interrupción concreto.
-- Prioriza la API moderna de SpellBook; si no existe, recurre al legacy
-- IsSpellKnown. También revisa el banco de mascota por si el kick es del pet.
local function PlayerKnowsInterruptSpell(spellId)
    if not (C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook) then
        return IsSpellKnown and IsSpellKnown(spellId) or false
    end
    -- Comprobar primero en el banco del jugador, luego en el del pet
    if C_SpellBook.IsSpellKnownOrInSpellBook(spellId) then return true end
    local petBank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Pet
    return petBank and C_SpellBook.IsSpellKnownOrInSpellBook(spellId, petBank) or false
end

-- Escanea la lista de kicks de la clase del jugador y almacena el primero
-- conocido como activeKickSpell. Se re-evalúa en cambios de spec/talents.
local function UpdatePlayerInterruptSpell()
    activeKickSpell = nil
    local classKicks = kickSpellsByClass[UnitClassBase("player")]
    if not classKicks then return end
    for idx = 1, #classKicks do
        if PlayerKnowsInterruptSpell(classKicks[idx]) then
            activeKickSpell = classKicks[idx]
        end
    end
end
-- Decide el color de la barra de casteo según si la interrupción del jugador
-- está disponible. Usa exclusivamente APIs secret-safe de Midnight 12.x:
-- GetSpellCooldownDuration → :IsZero() → EvaluateColorValueFromBoolean.
-- NUNCA se hace branch (if/not/comparación) sobre valores secretos.
local function SelectCastBarTint(readyTint, cooldownTint)
    if not activeKickSpell then return cooldownTint.r, cooldownTint.g, cooldownTint.b end
    if not (C_Spell and C_Spell.GetSpellCooldownDuration) then return cooldownTint.r, cooldownTint.g, cooldownTint.b end
    if not (C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean) then return cooldownTint.r, cooldownTint.g, cooldownTint.b end

    local cdTime = C_Spell.GetSpellCooldownDuration(activeKickSpell)
    if not (cdTime and cdTime.IsZero) then return cooldownTint.r, cooldownTint.g, cooldownTint.b end

    -- offCD es secret boolean: pasarlo directo a EvaluateColorValueFromBoolean
    -- sin testear con if/not. La API resuelve el valor internamente.
    local offCD = cdTime:IsZero()
    return C_CurveUtil.EvaluateColorValueFromBoolean(offCD, cooldownTint.r, readyTint.r),
           C_CurveUtil.EvaluateColorValueFromBoolean(offCD, cooldownTint.g, readyTint.g),
           C_CurveUtil.EvaluateColorValueFromBoolean(offCD, cooldownTint.b, readyTint.b)
end

local function MaybeDebugCastColor(plate, readyTint, cooldownTint, uninterruptibleTint)
    return
end
function ns.RefreshBorderStyle()
    for _, plate in pairs(ns.plates) do
        if plate.ApplyBorderStyle then
            plate:ApplyBorderStyle()
        end
        if ns.ApplyThemeSkin then ns.ApplyThemeSkin(plate) end
    end
end
function ns.RefreshBorderColor()
    for _, plate in pairs(ns.plates) do
        if plate.ApplyBorderColor then
            plate:ApplyBorderColor()
        end
    end
end
function ns.RefreshNameplateYOffset()
    local yOff = GetNameplateYOffset()
    for _, plate in pairs(ns.plates) do
        plate.health:ClearAllPoints()
        plate.health:SetPoint("CENTER", plate, "CENTER", 0, yOff)
    end
end

-- Footprint handed to Blizzard's stacking engine: the name line, the health
-- bar and the cast bar, scaled by the user's spacing percentage.
function ns.GetStackBoundsSize()
    local stackHeight = 4 + GetEnemyNameTextSize() + GetHealthBarHeight() + GetCastBarHeight()
    return GetHealthBarWidth(), stackHeight * (GetStackSpacingScale() / 100)
end

function ns.RefreshStackingBounds()
    local boundsW, boundsH = ns.GetStackBoundsSize()
    for _, plate in pairs(ns.plates) do
        local bounds = plate._stackBounds
        if bounds then bounds:SetSize(boundsW, boundsH) end
    end
end

-- CVar queue, click area and the once-only hooks on Blizzard's driver (Nameplates_CVars.lua).
ns.NameplatesCVars.Setup({
    client = "retail",
    defaults = defaults,
    GetSafeNamePlateForUnit = GetSafeNamePlateForUnit,
    GetHealthBarWidth = GetHealthBarWidth,
    GetHealthBarHeight = GetHealthBarHeight,
})

function ns.RefreshStackingMotion()
    if not C_CVar or not C_CVar.SetCVarBitfield then return end
    local db = KullThranUINameplatesDB or defaults
    local enabled = (db.stackingEnabled ~= false)
    if Enum and Enum.NamePlateStackType then
        ns.QueueNameplateCVarBitfield("nameplateStackingTypes", Enum.NamePlateStackType.Enemy, enabled)
        ns.QueueNameplateCVarBitfield("nameplateStackingTypes", Enum.NamePlateStackType.Friendly, false)
    end
end
function ns.RefreshHitboxSize()
    if InCombatLockdown() then return end
    if not C_NamePlate or not C_NamePlate.SetNamePlateSize then return end
    local db = KullThranUINameplatesDB or defaults
    local sx = (db.hitboxScaleX or 100) / 100
    local sy = (db.hitboxScaleY or 100) / 100
    local baseW = GetHealthBarWidth()
    local baseH = GetHealthBarHeight()
    local newH  = baseH * sy
    C_NamePlate.SetNamePlateSize(baseW * sx, newH)
    -- El frame crece hacia arriba desde su base, así que la altura extra queda arriba.
    -- Desplazamos el área de hit hacia abajo para centrarla en la barra.
    local plateManager = C_NamePlateManager
    if plateManager and plateManager.SetNamePlateHitTestInsets and Enum and Enum.NamePlateType then
        for _, plateKind in ipairs({ Enum.NamePlateType.Enemy, Enum.NamePlateType.Friendly }) do
            plateManager.SetNamePlateHitTestInsets(plateKind, -10000, -10000, -10000, -10000)
        end
    end
    -- Desplazar contenido de la placa para compensar el crecimiento del frame
    local yShift = GetHitboxYShift()
    for _, plate in pairs(ns.plates) do
        plate:AnchorToNameplate(yShift)
    end
end

--- Full visual refresh for all plates called when an entire preset is applied.
--- Re-runs SetUnit on each active plate, which re-reads all DB values and applies
--- them.  Only runs on deliberate preset switch (not per-frame or per-event).
function ns.RefreshAllSettings()
    if not IsNameplatesEnabled() then
        return
    end

    for _, plate in pairs(ns.plates) do
        if plate.unit and plate.nameplate then
            plate:SetUnit(plate.unit, plate.nameplate)
        end
    end
    if ns.ApplyClassPowerSetting then ns.ApplyClassPowerSetting() end
    if ns.RefreshFriendlyPlayerLevels then ns.RefreshFriendlyPlayerLevels() end
end
local kickWatcher = CreateFrame("Frame")
kickWatcher:RegisterEvent("PLAYER_LOGIN")
kickWatcher:RegisterEvent("SPELLS_CHANGED")
local activeCastCount = 0
kickWatcher:SetScript("OnEvent", function()
    UpdatePlayerInterruptSpell()
end)
local _castColorTicker
local function SetCastWatcherState(enabled)
    if enabled then
        if activeKickSpell and not _castColorTicker then
            _castColorTicker = C_Timer.NewTicker(0.2, function()
                local profiler = _G.KT and _G.KT.CombatProfiler
                local profileStarted = profiler and profiler:Begin("nameplates.cast_color.tick")
                for _, plate in pairs(ns.plates) do
                    if plate.isCasting and plate.unit and plate._kickProtected ~= nil then
                        plate:ApplyCastColor(plate._kickProtected)
                    end
                end
                if profileStarted then
                    profiler:End("nameplates.cast_color.tick", profileStarted)
                end
            end)
        end
        return
    end

    if _castColorTicker then
        _castColorTicker:Cancel()
        _castColorTicker = nil
    end
end

local function BeginInterruptTracking()
    activeCastCount = activeCastCount + 1
    if activeCastCount == 1 then
        SetCastWatcherState(true)
    end
end
local function EndInterruptTracking()
    activeCastCount = activeCastCount - 1
    if activeCastCount <= 0 then
        activeCastCount = 0
        SetCastWatcherState(false)
    end
end
-- Class resource pips on the target's plate (Nameplates_ClassPower.lua).
ns.NameplatesClassPower.Setup({
    client = "retail",
    PP = PP,
    GetShowClassPower = GetShowClassPower,
    GetClassPowerPos = GetClassPowerPos,
    GetClassPowerYOffset = GetClassPowerYOffset,
    GetClassPowerXOffset = GetClassPowerXOffset,
    GetClassPowerGap = GetClassPowerGap,
    GetClassPowerClassColors = GetClassPowerClassColors,
    GetClassPowerScale = GetClassPowerScale,
    GetClassPowerShape = GetClassPowerShape,
    GetClassPowerCustomColor = GetClassPowerCustomColor,
    GetClassPowerBgColor = GetClassPowerBgColor,
    GetClassPowerEmptyColor = GetClassPowerEmptyColor,
})
GetClassPowerTopPush = ns.NameplatesClassPower.TopPush
local EnsureClassPowerPips = ns.NameplatesClassPower.EnsurePips
local UpdateClassPowerOnPlate = ns.NameplatesClassPower.UpdatePlate
local HideClassPowerOnPlate = ns.NameplatesClassPower.HidePlate
-- Oscurece un color RGB por un factor (0-1). Valores fuera de rango se
-- saturan sin usar una closure auxiliar; math.min/max son más directos.
local function DarkenColor(r, g, b, factor)
    local s = tonumber(factor)
    if not s or s <= 0 or s > 1 then
        local style = ns.NameplateStyle and ns.NameplateStyle()
        -- Keep idle KUI bars readable while retaining their combat contrast.
        s = (style == "kui") and 0.85 or 1
    end
    return math.min(1, math.max(0, r * s)),
           math.min(1, math.max(0, g * s)),
           math.min(1, math.max(0, b * s))
end
-- Cached threat-context state.
local _inThreatContent = false
local _isTankRole      = false

-- Refresca la caché de contexto de amenaza: si estamos en contenido donde
-- importa el threat (dungeons, raids, delves) y si el jugador es tank.
-- Se llama en cambios de zona, grupo y especialización.
local function RefreshThreatCache()
    -- Resolver rol primero: es independiente de la zona y se usa abajo
    local assignedRole = UnitGroupRolesAssigned("player")
    if assignedRole == "NONE" then
        local specIdx = GetSpecialization and GetSpecialization()
        local specRole = specIdx and GetSpecializationRole and GetSpecializationRole(specIdx)
        assignedRole = specRole or "NONE"
    end
    _isTankRole = (assignedRole == "TANK")

    -- Determinar si estamos en contenido instanciado relevante para threat
    local _, instType, diffID = GetInstanceInfo()
    local diff = tonumber(diffID) or 0
    local isGarrison = C_Garrison and C_Garrison.IsOnGarrisonMap
                   and C_Garrison.IsOnGarrisonMap()
    if diff == 0 or isGarrison then
        _inThreatContent = false
        return
    end
    local isDelve = C_PartyInfo and C_PartyInfo.IsDelveInProgress
                and C_PartyInfo.IsDelveInProgress()
    _inThreatContent = (instType == "party")
                    or (instType == "raid")
                    or (isDelve == true)
end

local function InRealInstancedContent()
    return _inThreatContent
end

local function IsPlayerTankRoleLive()
    local role = UnitGroupRolesAssigned("player")
    if role == "TANK" then
        return true
    end
    if GetSpecialization and GetSpecializationRole then
        local spec = GetSpecialization()
        if spec then
            return GetSpecializationRole(spec) == "TANK"
        end
    end
    return false
end

local function GetThreatInfoForUnit(sourceUnit, targetUnit)
    local isTanking, status = UnitDetailedThreatSituation(sourceUnit, targetUnit)
    if issecretvalue then
        if issecretvalue(isTanking) then isTanking = nil end
        if issecretvalue(status) then status = nil end
    end
    if status == nil then
        status = UnitThreatSituation(sourceUnit, targetUnit)
        if issecretvalue and issecretvalue(status) then
            status = nil
        end
    end
    if isTanking == nil and status ~= nil then
        isTanking = status >= 2
    end
    return isTanking, status
end

local function IsOtherTankTankingUnit(targetUnit)
    if not IsInGroup() then return false end
    local inRaid = IsInRaid()
    local prefix = inRaid and "raid" or "party"
    local members = inRaid and GetNumGroupMembers() or GetNumSubgroupMembers()
    for slot = 1, members do
        local memberUnit = prefix .. slot
        local isOtherTank = UnitExists(memberUnit) and not UnitIsUnit(memberUnit, "player")
            and UnitGroupRolesAssigned(memberUnit) == "TANK"
        if isOtherTank and GetThreatInfoForUnit(memberUnit, targetUnit) then
            return true
        end
    end
    return false
end
-- Quest mob detection: unit tooltips (C_TooltipInfo) are scanned for quest
-- objective lines. Results are cached per unit and dropped on QUEST_LOG_UPDATE
-- or when the nameplate unit goes away.
local questMobCache = {}
local QUEST_LINE_TYPES
if Enum and Enum.TooltipDataLineType then
    QUEST_LINE_TYPES = {
        [Enum.TooltipDataLineType.QuestObjective] = true,
        [Enum.TooltipDataLineType.QuestTitle] = true,
        [Enum.TooltipDataLineType.QuestPlayer] = true,
    }
end

-- Objective key: the text without its progress and dashes, lower case, so a
-- tooltip line and the quest log entry for the same objective match.
function ns.QuestObjectiveKey(text)
    if type(text) ~= "string" then return nil end
    local key = text:gsub("%d+%s*/%s*%d+", ""):gsub("%d+%%", ""):gsub("^[%s%-]+", ""):gsub("[%s%-:]+$", "")
    key = key:lower()
    return key ~= "" and key or nil
end

-- Keys of the player's own unfinished objectives, rebuilt after QUEST_LOG_UPDATE
-- (ns.myQuestObjectives = nil). In a group the tooltip also lists other
-- members' objectives under their names, and the name line does not always
-- match UnitName("player"), so group tooltips are checked against this.
function ns.MyQuestObjectives()
    if ns.myQuestObjectives then return ns.myQuestObjectives end
    local keys = {}
    local log = C_QuestLog
    if log and log.GetNumQuestLogEntries and log.GetInfo and log.GetQuestObjectives then
        for index = 1, log.GetNumQuestLogEntries() or 0 do
            local info = log.GetInfo(index)
            if info and not info.isHeader and info.questID then
                for _, objective in ipairs(log.GetQuestObjectives(info.questID) or {}) do
                    if not objective.finished then
                        local key = ns.QuestObjectiveKey(objective.text)
                        if key then keys[key] = true end
                    end
                end
            end
        end
    elseif GetNumQuestLogEntries and GetQuestLogTitle and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        for index = 1, GetNumQuestLogEntries() or 0 do
            local _, _, _, isHeader = GetQuestLogTitle(index)
            if not isHeader then
                for objective = 1, GetNumQuestLeaderBoards(index) or 0 do
                    local text, _, finished = GetQuestLogLeaderBoard(objective, index)
                    if not finished then
                        local key = ns.QuestObjectiveKey(text)
                        if key then keys[key] = true end
                    end
                end
            end
        end
    end
    ns.myQuestObjectives = keys
    return keys
end

local function IsQuestMob(unit)
    if not C_TooltipInfo or not QUEST_LINE_TYPES then return false end
    if questMobCache[unit] ~= nil then return questMobCache[unit] end
    -- Dentro de instancia no hay quest mobs de mundo abierto
    if InRealInstancedContent() then
        questMobCache[unit] = false
        return false
    end
    local info = C_TooltipInfo.GetUnit(unit)
    if not ns.IsAccessibleValue(info) or type(info) ~= "table" then
        questMobCache[unit] = false
        return false
    end
    local lines = info.lines
    if not ns.IsAccessibleValue(lines) or type(lines) ~= "table" then
        questMobCache[unit] = false
        return false
    end
    local playerName = UnitName("player")
    local isInGroup = IsInGroup()
    local ignoreUntilTitle = false
    for _, line in ipairs(lines) do
        local lt = ns.IsAccessibleValue(line) and type(line) == "table" and line.type or nil
        if not ns.IsAccessibleValue(lt) then lt = nil end
        if not QUEST_LINE_TYPES[lt] then
            -- Línea no relacionada con quests: saltar
        elseif lt == Enum.TooltipDataLineType.QuestPlayer then
            -- Member name lines: in a group, ownership is decided by the
            -- player's own quest log below, not by matching this name.
        elseif lt == Enum.TooltipDataLineType.QuestTitle then
            ignoreUntilTitle = false
        elseif lt == Enum.TooltipDataLineType.QuestObjective and isInGroup then
            -- One of the player's own unfinished objectives (leftText can be
            -- a secret value in combat: pcall).
            local ok, mine = pcall(function()
                local key = ns.QuestObjectiveKey(line.leftText)
                return key and ns.MyQuestObjectives()[key] or false
            end)
            if ok and mine then
                questMobCache[unit] = true
                return true
            end
        elseif lt == Enum.TooltipDataLineType.QuestObjective and not ignoreUntilTitle then
            -- Comprobar si el objetivo está incompleto (X/Y o N%)
            -- leftText puede ser taint; envolver en pcall
            local ok, isIncomplete = pcall(function()
                local txt = line.leftText or ""
                local c1, c2 = txt:match("(%d+)/(%d+)")
                if c1 and c1 ~= c2 then return true end
                local pct = txt:match("(%d+)%%")
                if pct and pct ~= "100" then return true end
                return false
            end)
            if ok and isIncomplete then
                questMobCache[unit] = true
                return true
            end
        end
    end
    questMobCache[unit] = false
    return false
end
ns.IsQuestMob = IsQuestMob

-- Invalida la caché de quest mobs cuando cambia el log de quests y
-- refresca colores en todas las placas para reflejar progreso actualizado.
local questCacheWatcher = CreateFrame("Frame")
questCacheWatcher:RegisterEvent("QUEST_LOG_UPDATE")
questCacheWatcher:RegisterEvent("GROUP_ROSTER_UPDATE")
questCacheWatcher:SetScript("OnEvent", function()
    wipe(questMobCache)
    ns.myQuestObjectives = nil
    for _, plate in pairs(ns.plates) do
        plate:UpdateHealthColor()
    end
end)

-- Level colour of an attackable unit, on the same scale as the level number of
-- the unit frames: grey (far below you), green, yellow, orange and red. A hidden
-- level ("??") is red. nil when the client keeps the level or difficulty secret.
local function SafeLevelValue(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok and not ns._IsSecretValue(value) then return value end
    return nil
end

local function GetLevelDifficultyColor(unit)
    local color
    if C_PlayerInfo and type(GetDifficultyColor) == "function" then
        local difficulty = SafeLevelValue(C_PlayerInfo.GetContentDifficultyCreatureForPlayer, unit)
        if difficulty ~= nil then color = SafeLevelValue(GetDifficultyColor, difficulty) end
    end
    if type(color) ~= "table" then
        local level = SafeLevelValue(UnitEffectiveLevel, unit)
        if type(level) ~= "number" or level == 0 then level = SafeLevelValue(UnitLevel, unit) end
        if type(level) ~= "number" or level == 0 then return nil end
        if level < 0 then return 1, 0.1, 0.1 end
        color = SafeLevelValue(GetCreatureDifficultyColor or GetQuestDifficultyColor, level)
    end
    if type(color) ~= "table" or ns._IsSecretValue(color.r) or type(color.r) ~= "number" then return nil end
    return color.r, color.g, color.b
end
ns.GetLevelDifficultyColor = GetLevelDifficultyColor

-- Level number colour by difficulty, in every style: only for units you can attack, while
-- "Color Enemy Level by Difficulty" is on. nil means the style's own level colour.
function ns.LevelTextDifficultyColor(unit)
    local db = KullThranUINameplatesDB
    if db and db.levelTextDifficultyColor == false then return nil end
    if not unit or SafeLevelValue(UnitCanAttack, "player", unit) ~= true then return nil end
    return GetLevelDifficultyColor(unit)
end

-- Leveling up changes every difficulty colour; the player's level settles a moment after the event.
local levelColorWatcher = CreateFrame("Frame")
levelColorWatcher:RegisterEvent("PLAYER_LEVEL_UP")
levelColorWatcher:SetScript("OnEvent", function()
    local db = KullThranUINameplatesDB
    local bars = db and db.levelDifficultyColorEnabled
    local numbers = not (db and db.levelTextDifficultyColor == false)
    if not (bars or numbers) then return end
    C_Timer.After(1, function()
        for _, plate in pairs(ns.plates) do
            if bars then plate:UpdateHealthColor() end
            if numbers and plate.UpdateLevel then plate:UpdateLevel() end
        end
    end)
end)

-- Resuelve el color de barra de vida según una cadena de prioridad de 8 niveles.
-- La prioridad es estricta: el primer nivel que coincide retorna inmediatamente.
--   P1: Tapped (gris)             → siempre visible, no depende de combate
--   P2: Quest mob (configurado)   → requiere opt-in en DB
--   P3: Jugador enemigo (clase)   → PvP/mundo, RAID_CLASS_COLORS
--   P4: Amenaza (tank/dps/grupo)  → sólo en instancia o grupo
--   P5: Focus (configurado)       → requiere opt-in en DB
--   P5b: Nivel (configurado)      → atacables por dificultad de nivel, opt-in en DB
--   P6: Neutral (reacción 4)      → incluye atacables no hostiles
--   P7: Miniboss (elite/boss)     → oscurecido si fuera de combate
--   P8: Caster (PALADIN NPC)      → oscurecido si fuera de combate
--   Fallback: enemigo genérico    → oscurecido si fuera de combate
local function GetReactionColor(unit)
    local db = KullThranUINameplatesDB or defaults
    local function C(key)
        return db[key] or defaults[key]
    end
    -- On/off switches: only an unset (nil) value falls back to the shipped default.
    local function Enabled(key)
        local saved = db[key]
        if saved == nil then return defaults[key] end
        return saved
    end

    -- P1: Tapped → siempre retorna gris sin importar combate ni grupo
    if UnitIsTapDenied(unit) then
        local c = C("tapped")
        return c.r, c.g, c.b
    end

    -- P2: Quest mob → sólo si el color de quest está habilitado en DB
    if db.questMobColorEnabled and IsQuestMob(unit) then
        local qc = db.questMobColor or defaults.questMobColor
        -- Classic's final brightness boost makes blue quest bars too pale.
        -- Deepen that blue before the shared colour pass, including saved profiles.
        if ns.NameplateStyle and ns.NameplateStyle() == "classic"
            and qc.b > qc.r and qc.b > qc.g then
            return qc.r * 0.5, qc.g * 0.5, qc.b * 0.5
        end
        return qc.r, qc.g, qc.b
    end

    -- P3: Jugador enemigo → color de clase directamente de RAID_CLASS_COLORS
    if UnitIsPlayer(unit) and UnitCanAttack("player", unit) then
        local _, rawClass = UnitClass(unit)
        if issecretvalue and issecretvalue(rawClass) then
            -- PvP identities can expose a secret class token. The native
            -- class-color API accepts that token and its protected RGB values
            -- may flow directly into SetStatusBarColor without Lua inspecting
            -- them or using the token as a table key.
            if C_ClassColor and C_ClassColor.GetClassColor then
                local nativeColor = C_ClassColor.GetClassColor(rawClass)
                if nativeColor then return nativeColor:GetRGB() end
            end
        else
            local class = rawClass
            if _G.KullThranUI and _G.KullThranUI.SafeUnitClass then
                local _, safeClass = _G.KullThranUI.SafeUnitClass(unit)
                class = safeClass or class
            end
            local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            if c then return c.r, c.g, c.b end
        end
    end

    -- P4: Amenaza → sólo aplica dentro de instancia, grupo o rol tanque.
    -- Internamente se bifurca en dos caminos: DPS/healer vs tanque,
    -- cada uno con su propia escala de colores (aggro/near/noAggro vs
    -- losing/has/otherTank/noAggro).
    local isTankRole = _isTankRole or IsPlayerTankRoleLive()
    local shouldCheckThreat = InRealInstancedContent() or IsInGroup() or isTankRole
    if shouldCheckThreat then
        -- Obtener datos de amenaza protegidos contra issecretvalue de Blizzard
        local isTanking, status = GetThreatInfoForUnit("player", unit)
        if issecretvalue and issecretvalue(isTanking) then isTanking = nil end
        if issecretvalue and issecretvalue(status) then status = nil end
        if type(isTanking) ~= "boolean" then isTanking = nil end
        if type(status) ~= "number" then status = nil end

        -- Resolver target del mob para inferir amenaza cuando la API no lo indica
        local unitTarget = unit .. "target"
        local targetExists = UnitExists(unitTarget)
        if issecretvalue and issecretvalue(targetExists) then targetExists = false end
        if type(targetExists) ~= "boolean" then targetExists = false end

        local targetIsPlayer = false
        local targetIsTank = false
        if targetExists then
            targetIsPlayer = UnitIsUnit(unitTarget, "player")
            if issecretvalue and issecretvalue(targetIsPlayer) then targetIsPlayer = false end
            if type(targetIsPlayer) ~= "boolean" then targetIsPlayer = false end

            if IsInGroup() then
                local targetRole = UnitGroupRolesAssigned(unitTarget)
                if issecretvalue and issecretvalue(targetRole) then targetRole = nil end
                targetIsTank = (targetRole == "TANK")
                if type(targetIsTank) ~= "boolean" then targetIsTank = false end
            end
        end

        -- Inferencia: si la API no indicó isTanking, deducirlo del target
        if isTanking == nil then
            if targetIsPlayer then
                isTanking = true
            elseif targetIsTank then
                isTanking = false
            end
        end

        -- P4a: Camino DPS/healer → 3 niveles: tiene aggro, near aggro, no aggro
        if not isTankRole then
            if IsInGroup() then
                if isTanking == true or targetIsPlayer then
                    local c = C("dpsHasAggro")
                    return c.r, c.g, c.b
                elseif status ~= nil and status >= 2 then
                    local c = C("dpsNearAggro")
                    return c.r, c.g, c.b
                elseif status ~= nil or targetExists then
                    local c = C("dpsNoAggro")
                    return c.r, c.g, c.b
                end
            end
        else
            -- P4b: Camino tanque → 4 niveles: perdiendo, tiene, otroTanque, sin aggro
            if targetIsPlayer or isTanking == true then
                if status ~= nil and status < 3 and status >= 2 then
                    local c = C("tankLosingAggro")
                    return c.r, c.g, c.b
                end
                if Enabled("tankHasAggroEnabled") then
                    local c = C("tankHasAggro")
                    return c.r, c.g, c.b
                end
            elseif targetIsTank or IsOtherTankTankingUnit(unit) then
                local c = C("tankOtherTankHasAggro")
                return c.r, c.g, c.b
            elseif (status ~= nil or targetExists) and (UnitAffectingCombat(unit) or targetExists) then
                local c = C("tankNoAggro")
                return c.r, c.g, c.b
            end
        end
    end

    -- P5: Focus → sólo si focusColorEnabled está activo en DB
    local focusC = C("focus")
    if focusC and UnitIsUnit(unit, "focus") and Enabled("focusColorEnabled") then
        return focusC.r, focusC.g, focusC.b
    end

    -- P5b: Nivel → color de dificultad del nivel en cualquier unidad atacable
    if db.levelDifficultyColorEnabled and UnitCanAttack("player", unit) then
        local lr, lg, lb = GetLevelDifficultyColor(unit)
        if lr then return lr, lg, lb end
    end

    -- P6: Neutral → reacción 4, o atacable pero no hostil
    local reaction = UnitReaction(unit, "player")
    if reaction and reaction == 4 then
        local c = C("neutral")
        return c.r, c.g, c.b
    end
    if UnitCanAttack("player", unit) and not UnitIsEnemy(unit, "player") then
        local c = C("neutral")
        return c.r, c.g, c.b
    end

    -- P7: Miniboss → elite/worldboss/rareelite de nivel alto, oscurecido fuera de combate
    local inCombat = UnitAffectingCombat(unit)
    local classification = SafeUnitClassification(unit)
    if classification == "elite" or classification == "worldboss" or classification == "rareelite" then
        local level = UnitLevel(unit)
        local playerLevel = UnitLevel("player")
        if level == -1 or (playerLevel and level >= playerLevel + 1) then
            local c = C("miniboss")
            if type(inCombat) == "boolean" and inCombat then
                return c.r, c.g, c.b
            else
                return DarkenColor(c.r, c.g, c.b)
            end
        end
    end

    -- P8: Caster NPC → actualmente sólo PALADIN NPCs, oscurecido fuera de combate
    local unitClass = UnitClassBase and UnitClassBase(unit)
    if issecretvalue and issecretvalue(unitClass) then
        unitClass = nil
    end
    if unitClass == "PALADIN" then
        local c = C("caster")
        if type(inCombat) == "boolean" and inCombat then
            return c.r, c.g, c.b
        else
            return DarkenColor(c.r, c.g, c.b)
        end
    end

    -- Fallback: enemigo genérico, oscurecido si fuera de combate
    local eic = C("enemyInCombat")
    if type(inCombat) == "boolean" and inCombat then
        return eic.r, eic.g, eic.b
    end
    -- Classic and Forever styles keep the saturated colour out of combat (no darkening)
    local style = ns.NameplateStyle and ns.NameplateStyle()
    if style == "classic" or style == "forever" then
        return eic.r, eic.g, eic.b
    end
    return DarkenColor(eic.r, eic.g, eic.b)
end
-- Blizzard's unit frame on hostile plates (Nameplates_BlizzardPlate.lua). KUI reads auras
-- through C_UnitAuras slot APIs. Do not hook Blizzard's RefreshAuras or alter its UNIT_AURA
-- registration: either can make Blizzard iterate protected PvP collections from tainted
-- execution.
ns.NameplatesBlizzardPlate.Setup({ client = "retail" })
local castFallbackFrame = CreateFrame("Frame")
local fallbackCastCount = 0
local _fallbackPlates = {}
-- Takes a plate out of the set whose cast bar mirrors Blizzard's; the poller
-- frame goes to sleep once the set is empty.
function ns._ReleaseCastFallback(plate)
    plate._castFallback = nil
    _fallbackPlates[plate] = nil
    fallbackCastCount = math.max(0, fallbackCastCount - 1)
    if fallbackCastCount == 0 then
        castFallbackFrame:Hide()
    end
end
castFallbackFrame:SetScript("OnUpdate", function()
    for plate in pairs(_fallbackPlates) do
        if plate.isCasting and plate.unit and plate.nameplate then
            local blizzUF = plate.nameplate.UnitFrame
            local blizzBar = blizzUF and blizzUF.castBar
            if blizzBar and blizzBar:IsShown() then
                -- Channels are timed from the channel info when it is sane;
                -- everything else mirrors Blizzard's own bar.
                local lowest, highest, current
                if plate._castIsChannel then
                    local _, _, _, startMS, endMS = UnitChannelInfo(plate.unit)
                    if startMS and endMS and endMS > startMS then
                        local span = (endMS - startMS) / 1000
                        lowest, highest = 0, span
                        current = math.max(0, math.min(span, GetTime() - (startMS / 1000)))
                    end
                end
                if not current then
                    lowest, highest = blizzBar:GetMinMaxValues()
                    current = blizzBar:GetValue()
                end
                plate.cast:SetMinMaxValues(lowest, highest)
                plate.cast:SetValue(current)
            else
                -- Blizzard's bar is gone: retire this plate from the fallback set.
                if not plate._interrupted then
                    plate.cast:Hide()
                end
                plate.isCasting = false
                ns._ReleaseCastFallback(plate)
                EndInterruptTracking()
            end
        end
    end
end)
castFallbackFrame:Hide()

-- Pandemic glow alpha-only tick: only iterates slots with active pandemic glows.
-- Self-disarming: the frame is shown only while a pandemic or expiry slot is
-- tracked, so with no glows on screen no per-frame code runs at all.
local pandemicTickFrame = CreateFrame("Frame")
pandemicTickFrame:Hide()
local pandemicTickAccum = 0
function ns.ArmPandemicTick()
    if not pandemicTickFrame:IsShown() then
        pandemicTickAccum = 0
        pandemicTickFrame:Show()
    end
end
pandemicTickFrame:SetScript("OnUpdate", function(self, elapsed)
    pandemicTickAccum = pandemicTickAccum + elapsed
    if pandemicTickAccum < 0.2 then return end
    pandemicTickAccum = 0
    if ns.GetPandemicGlow() then
        for slot in pairs(ns.activePandemicSlots) do
            local durObj = slot._durationObj
            if durObj and slot.pandemicGlow and slot.pandemicGlow.active then
                slot.pandemicGlow.wrapper:SetAlpha(C_CurveUtil.EvaluateColorValueFromBoolean(durObj:IsZero(), 0, durObj:EvaluateRemainingPercent(ns.pandemicCurve)))
            else
                ns.StopPandemicGlow(slot)
            end
        end
    end

    local expirySlots = ns.trackedExpirySlots
    if expirySlots then
        for slot in pairs(expirySlots) do
            ns.UpdateDebuffExpiryGlow(slot, slot._typeColor)
            if not slot:IsShown() then
                ns.StopDebuffExpiryGlow(slot)
            end
        end
    end

    if not next(ns.activePandemicSlots) and not (expirySlots and next(expirySlots)) then
        self:Hide()
    end
end)

local NameplateFrame = {}
-- Centres the plate on its Blizzard nameplate, lowered by `yShift`; `snapped`
-- uses the pixel-perfect helper instead of a raw SetPoint.
function NameplateFrame:AnchorToNameplate(yShift, snapped)
    self:ClearAllPoints()
    if snapped then
        PP.Point(self, "CENTER", self.nameplate, "CENTER", 0, yShift)
    else
        self:SetPoint("CENTER", self.nameplate, "CENTER", 0, yShift)
    end
end
-- Cancels the pending "interrupted" auto-hide timer, if one is running.
function NameplateFrame:CancelInterruptTimer()
    local timer = self._interruptTimer
    if timer then
        timer:Cancel()
        self._interruptTimer = nil
    end
end
-- Puts the shield icon and the colour overlay of the cast bar back to their idle look.
function NameplateFrame:ResetCastDecor()
    self.castShieldFrame:Hide()
    self.castShieldFrame:SetAlpha(1)
    self.castBarOverlay:SetAlpha(0)
end
function NameplateFrame:RefreshStackBounds(nameplate)
    if not nameplate.SetStackingBoundsFrame then
        return
    end

    local bounds = self._stackBounds
    if not bounds then
        bounds = CreateFrame("Frame", nil, nameplate)
        self._stackBounds = bounds
        -- Invisible fill so the frame has a measurable extent.
        local fill = bounds:CreateTexture(nil, "BACKGROUND")
        fill:SetColorTexture(1, 0, 0, 0)
        fill:SetAllPoints(bounds)
    end

    local boundsW, boundsH = ns.GetStackBoundsSize()
    bounds:SetParent(nameplate)
    bounds:ClearAllPoints()
    PP.Point(bounds, "CENTER", nameplate, "CENTER", 0, GetNameplateYOffset())
    PP.Size(bounds, boundsW, boundsH)
    bounds:Show()
    nameplate:SetStackingBoundsFrame(bounds)
end

-- Posiciona y dimensiona las barras principales de la placa (salud, absorb,
-- casteo e icono). La altura de casteo puede sobredimensionarse si la
-- unidad es el foco del jugador. Se resuelven todas las dimensiones ANTES
-- de aplicarlas para minimizar relayouts internos del motor de frames.
function NameplateFrame:LayoutCoreBars(unit)
    local barW    = GetHealthBarWidth()
    local barH    = GetHealthBarHeight()
    local castH   = GetCastBarHeight()
    local yOffset = GetNameplateYOffset()

    -- Sobredimensionar la barra de casteo para el foco si está configurado
    if unit and UnitIsUnit(unit, "focus") then
        local focusPct = GetFocusCastHeight()
        if focusPct ~= 100 then
            castH = math.floor(castH * focusPct / 100 + 0.5)
        end
    end

    -- Barra de salud y absorb: mismas dimensiones, centradas en la placa
    self.health:ClearAllPoints()
    local nativeRetail = ns.NameplateStyle and ns.NameplateStyle() == "retail"
    if nativeRetail then
        -- Keep the atlas and its fill in the same logical geometry. Rounding
        -- dimensions again as world scale changes stretches the border in steps.
        self.health:SetPoint("CENTER", self, "CENTER", 0, yOffset)
        self.health:SetSize(barW, barH)
        self.absorb:SetSize(barW, barH)
    else
        PP.Point(self.health, "CENTER", self, "CENTER", 0, yOffset)
        PP.Size(self.health, barW, barH)
        PP.Size(self.absorb, barW, barH)
    end

    -- Barra de casteo: anclada debajo de la barra de salud
    self.cast:ClearAllPoints()
    if nativeRetail then
        self.cast:SetSize(barW, castH)
        self.cast:SetPoint("TOPLEFT", self.health, "BOTTOMLEFT", 0, 0)
    else
        PP.Size(self.cast, barW, castH)
        PP.Point(self.cast, "TOPLEFT", self.health, "BOTTOMLEFT", 0, 0)
    end

    -- Icono de hechizo: cuadrado del tamaño del casteo, a la izquierda
    self.castIconFrame:ClearAllPoints()
    PP.Size(self.castIconFrame, castH, castH)
    PP.Point(self.castIconFrame, "TOPRIGHT", self.cast, "TOPLEFT", 0, 0)
    if GetShowCastIcon() then
        self.castIconFrame:SetScale(GetCastIconScale())
        self.castIconFrame:Show()
    else
        self.castIconFrame:Hide()
    end

    -- Elementos secundarios del casteo que dependen de castH
    PP.Width(self.castLeftBorder, 1)
    PP.Height(self.castSpark, castH)
    PP.Size(self.kickMarker, barW, castH)

    if self.absorbOverflow then
        PP.Height(self.absorbOverflow, barH)
    end
end

function NameplateFrame:ApplyEnemyNameTint()
    local slotKey = FindSlotForElement("enemyName")
    if not slotKey then
        return
    end

    local nr, ng, nb = GetTextSlotColor(slotKey)
    self.name:SetTextColor(nr, ng, nb, 1)
end

function NameplateFrame:ApplyCastTargetColorFromToken(classToken)
    local db = KullThranUINameplatesDB or defaults
    local useClassColor = db.castTargetClassColor
    if useClassColor == nil then
        useClassColor = defaults.castTargetClassColor
    end

    if useClassColor then
        if classToken and C_ClassColor then
            local classColor = C_ClassColor.GetClassColor(classToken)
            if classColor then
                self.castTarget:SetTextColor(classColor:GetRGB())
                return
            end
        end

        self.castTarget:SetTextColor(1, 1, 1, 1)
        return
    end

    local castTargetColor = db.castTargetColor or defaults.castTargetColor
    self.castTarget:SetTextColor(castTargetColor.r, castTargetColor.g, castTargetColor.b, 1)
end

function NameplateFrame:ApplyCastFontSettings()
    local nameSize = (db and db.castNameSize) or defaults.castNameSize
    local targetSize = (db and db.castTargetSize) or defaults.castTargetSize
    local nameColor = (db and db.castNameColor) or defaults.castNameColor
    local classToken

    SetFSFont(self.castName, nameSize, GetNPOutline())
    SetFSFont(self.castTarget, targetSize, GetNPOutline())
    self.castName:SetTextColor(nameColor.r, nameColor.g, nameColor.b, 1)

    if self.unit then
        if UnitSpellTargetClass then
            classToken = UnitSpellTargetClass(self.unit)
        end

        if not classToken then
            local targetUnit = self.unit .. "target"
            if UnitIsPlayer(targetUnit) then
                classToken = UnitClassBase(targetUnit)
            end
        end
    end

    self:ApplyCastTargetColorFromToken(classToken)
end

function NameplateFrame:ApplyAuraTimerPosition(durText, auraFrame, pos, size, color)
    local cooldownFrame = auraFrame.cd
    if pos == "none" then
        if cooldownFrame and cooldownFrame.SetHideCountdownNumbers then
            cooldownFrame:SetHideCountdownNumbers(true)
        end
        return
    end

    if cooldownFrame and cooldownFrame.SetHideCountdownNumbers then
        cooldownFrame:SetHideCountdownNumbers(false)
    end

    SetFSFont(durText, size, "OUTLINE")
    durText:SetTextColor(color.r, color.g, color.b, 1)
    durText:ClearAllPoints()

    if pos == "center" then
        durText:SetPoint("CENTER", auraFrame, "CENTER", 0, 0)
        durText:SetJustifyH("CENTER")
        return
    end

    if pos == "topright" then
        PP.Point(durText, "TOPRIGHT", auraFrame, "TOPRIGHT", 3, 4)
        durText:SetJustifyH("RIGHT")
        return
    end

    PP.Point(durText, "TOPLEFT", auraFrame, "TOPLEFT", -3, 4)
    durText:SetJustifyH("LEFT")
end

function NameplateFrame:ApplyAuraSlotTheme(slots, count, durationSize, durationColor, stackSize, stackColor, timerPosition)
    for i = 1, count do
        local slot = slots[i]
        if slot and slot.cd and slot.cd.text then
            self:ApplyAuraTimerPosition(slot.cd.text, slot, timerPosition, durationSize, durationColor)
        end

        if slot and slot.count then
            SetFSFont(slot.count, stackSize, "OUTLINE")
            slot.count:SetTextColor(stackColor.r, stackColor.g, stackColor.b, 1)
        end
    end
end

function NameplateFrame:ApplyAuraVisualSettings(gap)
    if ns.NPC_ApplyVisualSettings then
        ns.NPC_ApplyVisualSettings(self)
    end
    local durationSize = (db and db.auraDurationTextSize) or defaults.auraDurationTextSize
    local durationColor = (db and db.auraDurationTextColor) or defaults.auraDurationTextColor
    local stackSize = (db and db.auraStackTextSize) or defaults.auraStackTextSize
    local stackColor = (db and db.auraStackTextColor) or defaults.auraStackTextColor
    local debuffTimerPosition = (db and db.debuffTimerPosition) or (db and db.auraTextPosition) or defaults.debuffTimerPosition
    local buffTimerPosition = (db and db.buffTimerPosition) or (db and db.auraTextPosition) or defaults.buffTimerPosition
    local ccTimerPosition = (db and db.ccTimerPosition) or (db and db.auraTextPosition) or defaults.ccTimerPosition
    local debuffSize = GetDebuffIconSize()
    local buffSize = GetBuffIconSize()
    local ccSize = GetCCIconSize()
    local debuffSlot, buffSlot, ccSlot = GetAuraSlots()

    self:ApplyAuraSlotTheme(self.debuffs, 4, durationSize, durationColor, stackSize, stackColor, debuffTimerPosition)
    for i = 1, 4 do
        PP.Size(self.debuffs[i], debuffSize, debuffSize)
    end

    self:ApplyAuraSlotTheme(self.buffs, 4, durationSize, durationColor, stackSize, stackColor, buffTimerPosition)
    for i = 1, 4 do
        PP.Size(self.buffs[i], buffSize, buffSize)
    end
    do
        local buffX, buffY = ns._AuraLayout.ResolveOffsets("buffSlot")
        ns._AuraLayout.Commit(self.buffs, 4,
            ns._AuraLayout.BuildPlacement(buffSlot, 4, buffSize, gap, self, buffX, buffY, "buffSlot"))
    end

    self:ApplyAuraSlotTheme(self.cc, 2, durationSize, durationColor, stackSize, stackColor, ccTimerPosition)
    for i = 1, 2 do
        PP.Size(self.cc[i], ccSize, ccSize)
    end
    do
        local ccX, ccY = ns._AuraLayout.ResolveOffsets("ccSlot")
        ns._AuraLayout.Commit(self.cc, 2,
            ns._AuraLayout.BuildPlacement(ccSlot, 2, ccSize, gap, self, ccX, ccY, "ccSlot"))
    end
end

-- Eventos unitarios que la placa enemiga necesita para mantenerse actualizada.
-- Almacenados en tabla para iterar; se registran todos con RegisterUnitEvent
-- en una sola pasada al adquirir la placa.
ns._TRACKED_PLATE_EVENTS = {
    "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_NAME_UPDATE",
    "UNIT_LEVEL", "UNIT_AURA", "LOSS_OF_CONTROL_UPDATE", "LOSS_OF_CONTROL_ADDED",
    "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_FLAGS", "UNIT_FACTION",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTIBLE",
    "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}
function NameplateFrame:RegisterTrackedEvents(unit)
    for _, ev in ipairs(ns._TRACKED_PLATE_EVENTS) do
        self:RegisterUnitEvent(ev, unit)
    end
end

function NameplateFrame:RefreshCastTextAnchors()
    if not (self.castName and self.cast and self.castTarget) then
        return
    end

    self.castName:ClearAllPoints()
    PP.Width(self.castName, 0)
    PP.Point(self.castName, "LEFT", self.cast, "LEFT", 5, 0)
    PP.Point(self.castName, "RIGHT", self.castTarget, "LEFT", -5, 0)
end

function NameplateFrame:RefreshPixelPerfectLayout()
    if not (self.unit and self.nameplate) then
        return
    end

    local scale = self.GetEffectiveScale and self:GetEffectiveScale()
    if type(scale) ~= "number" or scale <= 0 then
        return
    end
    if self._ktPixelScale and math.abs(self._ktPixelScale - scale) < 0.003 then
        return
    end
    self._ktPixelScale = scale

    -- Text and pips still follow physical pixels. Retail's atlas bars keep
    -- their logical size; only explicit layout/settings changes resize them.
    if not (ns.NameplateStyle and ns.NameplateStyle() == "retail") then
        self:LayoutCoreBars(self.unit)
    end
    self:RefreshStackBounds(self.nameplate)
    self:RefreshNamePosition()
    self:UpdateRaidIcon()
    self:RefreshTargetClassPowerPosition()
    if self.isCasting then
        self:RefreshCastTextAnchors()
    end
end
-- Refresca todos los datos visuales de la placa en su estado actual.
-- Se invoca una sola vez al final de SetUnit para evitar refrescos
-- parciales durante la inicialización.
function NameplateFrame:RefreshPlateState()
    self:UpdateHealth()
    self:RefreshNamePosition()
    self:UpdateRaidIcon()
    self:ApplyTarget()
    self:ApplyMouseover()
    self:UpdateCast()
    ApplyHealthBarTexture(self)
    ApplyCastBarTexture(self)
    if ns.ApplyThemeSkin then
        local skinBefore = self._skinHealth and self._skinHealth.style
        ns.ApplyThemeSkin(self)
        -- A new plate (or a theme switch) gets its skin after ApplyTarget: redo the target
        -- selection on it, or the target keeps the generic glow without the theme frame.
        if (self._skinHealth and self._skinHealth.style) ~= skinBefore then self:ApplyTarget() end
    end
end
-- Vincula la placa KUI a un unit token y nameplate Blizzard. El orden
-- de inicialización es:
--   1. Anclar frame al nameplate
--   2. Configurar layout y fuentes (sólo geometría, sin datos)
--   3. Suprimir elementos Blizzard
--   4. Registrar eventos
--   5. Refrescar todo el estado visual con datos reales
-- Este orden garantiza que al llegar al paso 5 todos los listeners
-- ya están activos y la geometría está resuelta.
function NameplateFrame:SetUnit(unit, nameplate)
    self.unit = unit
    self.nameplate = nameplate
    -- Paso 1: anclar al nameplate Blizzard
    self:SetParent(nameplate)
    if nameplate.GetFrameStrata then
        self:SetFrameStrata(nameplate:GetFrameStrata())
    end
    if self.SetIgnoreParentScale then
        self:SetIgnoreParentScale(false)
    end
    self:AnchorToNameplate(GetHitboxYShift(), true)
    PP.Size(self, 1, 1)
    self:SetFrameLevel(nameplate:GetFrameLevel() + 1)
    self:Show()

    -- AuraContainer creates its buttons at the parent's current frame level.
    -- Bind it only after this plate belongs to the Blizzard nameplate; creating
    -- it while pooled under UIParent leaves the aura buttons behind the plate.
    if ns.NPC_Bind then ns.NPC_Bind(self, unit) end

    -- Paso 2: geometría y fuentes
    self:RefreshStackBounds(nameplate)
    self:LayoutCoreBars(unit)
    self:ApplyEnemyNameTint()
    self:ApplyCastFontSettings()
    self:ApplyAuraVisualSettings(GetAuraSpacing())

    -- Paso 3: suprimir UnitFrame Blizzard
    ns.HideBlizzardFrame(nameplate, unit)

    -- Paso 4-5: eventos + estado visual
    self:RegisterTrackedEvents(unit)
    self:RefreshPlateState()
end
-- Limpia el cooldown de un frame de aura: desactiva swipe y resetea
-- el cooldown. Compatible con la API moderna (Clear) y el fallback antiguo.
-- Se almacena en ns para no consumir un local de ámbito de archivo.
ns._ResetAuraCooldown = function(cd)
    if not cd then return end
    if cd.SetDrawSwipe then cd:SetDrawSwipe(false) end
    if cd.Clear then cd:Clear() else cd:SetCooldown(0, 0) end
end

-- Desvincula la placa KUI de su unidad. El orden de limpieza es:
--   1. Desregistrar TODOS los eventos (corta callbacks entrantes)
--   2. Cancelar tracking de casteo activo
--   3. Limpiar ranuras de auras (CC, debuffs, buffs)
--   4. Resetear estado de casteo visual
--   5. Ocultar adornos (glow, flechas, pips, absorb)
--   6. Desanclar de la jerarquía del nameplate
-- El frame queda listo para ser reciclado por el frameCache.
function NameplateFrame:ClearUnit()
    if ns.NPC_Unbind then ns.NPC_Unbind(self) end
    -- 1. Cortar todo callback antes de tocar la UI
    self:UnregisterAllEvents()

    -- 2. Cancelar tracking de casteo
    if self.isCasting then
        self.isCasting = false
        if self._castFallback then ns._ReleaseCastFallback(self) end
        EndInterruptTracking()
    end

    -- 3. Limpiar ranuras de auras: CC primero (2 ranuras), luego debuffs+buffs (4 c/u)
    self.name:SetText("")
    if self.level then
        self.level:SetText("")
        self.level:Hide()
    end
    local resetCD = ns._ResetAuraCooldown
    for i = 1, 2 do
        local slot = self.cc[i]
        resetCD(slot.cd)
        slot.icon:SetTexture(nil)
        slot:Hide()
    end
    for i = 1, 4 do
        local dSlot = self.debuffs[i]
        resetCD(dSlot.cd)
        dSlot.icon:SetTexture(nil)
        dSlot:Hide()
        ns.StopPandemicGlow(dSlot)
        dSlot._durationObj = nil
        dSlot._expirationTime = nil
        dSlot._durationSeconds = nil
        dSlot._typeColor = nil

        local bSlot = self.buffs[i]
        resetCD(bSlot.cd)
        bSlot.icon:SetTexture(nil)
        bSlot:Hide()
    end

    -- 4. Resetear estado de casteo visual
    self.unit = nil
    self.nameplate = nil
    self._displayNameText = nil
    self._displayLevelText = nil
    self._dynamicLevelXOffset = nil
    self._ktPixelScale = nil
    if self.SetIgnoreParentScale then
        self:SetIgnoreParentScale(false)
    end
    self._shownAuras = nil
    self.cast:Hide()
    self:ResetCastDecor()
    self.isCasting = false
    self._castFallback, self._castIsChannel = nil, nil
    _fallbackPlates[self] = nil
    self._kickProtected = nil
    self:HideKickTick()
    self:CancelInterruptTimer()
    self._interrupted = nil

    -- 5. Ocultar adornos visuales
    for _, ornament in ipairs({ "glow", "highlight", "raidFrame", "classFrame", "leftArrow", "rightArrow" }) do
        local piece = self[ornament]
        if piece then piece:Hide() end
    end
    HideClassPowerOnPlate(self)
    self.absorb:Hide()
    local overflow = self.absorbOverflow
    if overflow then
        overflow:Hide()
        overflow:SetWidth(0)
    end
    if self.absorbOverflowDivider then
        self.absorbOverflowDivider:Hide()
    end

    -- 6. Desanclar: devolver al pool limpio
    self:Hide()
    self:SetScale(1)
    self:SetParent(UIParent)
    self:ClearAllPoints()
    -- Desacoplar stacking bounds del nameplate anterior para que el motor
    -- de apilamiento no se confunda al reciclar el frame
    local bounds = self._stackBounds
    if bounds then
        bounds:ClearAllPoints()
        bounds:SetParent(self)
        bounds:Hide()
    end
end
function NameplateFrame:ResolveHealthUnit()
    local unit = self.unit
    if not unit then
        return nil
    end

    local nameplate = self.nameplate
    local liveToken = nameplate and nameplate.namePlateUnitToken
    if liveToken and liveToken ~= unit then
        self.unit = liveToken
        unit = liveToken
        self:RefreshNamePosition()
    end

    return unit
end

function NameplateFrame:RefreshHealthBars(unit)
    local maxHealth = UnitHealthMax(unit)
    local config = KullThranUINameplatesDB or defaults
    local health = UnitHealth(unit)
    local absorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0
    local interpolation = Enum and Enum.StatusBarInterpolation
    local mode = config.animateHealthBar and interpolation and interpolation.ExponentialEaseOut or
        interpolation and interpolation.Immediate

    local maxSecret = ns._IsSecretValue(maxHealth)
    if maxSecret or self._healthMax ~= maxHealth then
        self.health:SetMinMaxValues(0, maxHealth)
        self.absorb:SetMinMaxValues(0, maxHealth)
        if maxSecret then self._healthMax = nil else self._healthMax = maxHealth end
    end
    if mode ~= nil then self.health:SetValue(health, mode) else self.health:SetValue(health) end

    if config.showShieldPrediction ~= false then
        if mode ~= nil then self.absorb:SetValue(absorb, mode) else self.absorb:SetValue(absorb) end
        self.absorb:Show()
    else
        self.absorb:SetValue(0)
        self.absorb:Hide()
    end

end

function NameplateFrame:RefreshHashLine(unit)
    local isTarget = unit and UnitIsUnit(unit, "target")
    local enabled = db and db.hashLineEnabled
    local percent = (db and db.hashLinePercent) or defaults.hashLinePercent

    if not enabled or not percent or percent <= 0 or not isTarget then
        self.hashLine:Hide()
        return
    end

    local xPos = self.health:GetWidth() * (percent / 100)
    local color = (db and db.hashLineColor) or defaults.hashLineColor

    self.hashLine:ClearAllPoints()
    self.hashLine:SetPoint("TOP", self.health, "TOPLEFT", xPos, 0)
    self.hashLine:SetPoint("BOTTOM", self.health, "BOTTOMLEFT", xPos, 0)
    self.hashLine:SetColorTexture(color.r, color.g, color.b, 0.8)
    self.hashLine:Show()
end

function NameplateFrame:BuildHealthTextValues(unit)
    local values = self._healthTextValues
    if not values then
        values = {}
        self._healthTextValues = values
    end
    local dead = UnitIsDeadOrGhost(unit)
    if ns._IsSecretValue(dead) then dead = false end
    if dead then
        values.percent, values.percentNoSign, values.number = "0%", "0", "0"
        return values
    end

    if not UnitHealthPercent then
        values.percent, values.percentNoSign, values.number = "", "", ""
        return values
    end

    local scaleTo100 = CurveConstants and CurveConstants.ScaleTo100 or nil
    local percentValue = UnitHealthPercent(unit, true, scaleTo100)
    local healthValue = UnitHealth(unit)
    if ns._IsSecretValue(percentValue) or ns._IsSecretValue(healthValue) then
        values.percent, values.percentNoSign, values.number = "", "", ""
        return values
    end
    if type(percentValue) ~= "number" or type(healthValue) ~= "number" then
        values.percent, values.percentNoSign, values.number = "", "", ""
        return values
    end
    values.percent = string.format("%d%%", percentValue)
    values.percentNoSign = string.format("%d", percentValue)
    values.number = AbbreviateLargeNumbers(healthValue)
    return values
end

function NameplateFrame:ApplyHealthTextToSlot(fontString, text, slot, slotKey, valueOnly)
    if fontString._ktHealthTextValue ~= text then
        fontString:SetText(text)
        fontString._ktHealthTextValue = text
    end
    if valueOnly then
        fontString:Show()
        return
    end
    local xOffset, yOffset = GetTextSlotOffsets(slotKey)
    local fontSize = GetTextSlotSize(slotKey)
    local sr, sg, sb = GetTextSlotColor(slotKey)

    fontString:SetParent(self.healthTextFrame)
    SetFSFont(fontString, fontSize, GetNPOutline())
    fontString:ClearAllPoints()

    if slot.anchor == "CENTER" then
        fontString:SetPoint("CENTER", self.health, "CENTER", xOffset, yOffset)
    else
        PP.Point(fontString, slot.anchor, self.health, slot.point, slot.xOff + xOffset, yOffset)
    end

    fontString:SetJustifyH(slot.anchor)
    fontString:SetTextColor(sr, sg, sb, 1)
    fontString:Show()
end

function NameplateFrame:ApplyTopHealthText(topElement, textValues, valueOnly)
    if topElement ~= "healthPercent" and topElement ~= "healthPercentNoSign" and topElement ~= "healthNumber"
        and topElement ~= "healthPctNum" and topElement ~= "healthNumPct" then
        return
    end

    local fontString = self.hpText
    local text
    if topElement == "healthNumber" then
        fontString = self.hpNumber
        text = textValues.number
    elseif topElement == "healthPercent" then
        text = textValues.percent
    elseif topElement == "healthPercentNoSign" then
        text = textValues.percentNoSign
    else
        text = FormatCombinedHealth(topElement, textValues.percent, textValues.number)
    end
    if fontString._ktHealthTextValue ~= text then
        fontString:SetText(text)
        fontString._ktHealthTextValue = text
    end
    if valueOnly then
        fontString:Show()
        return
    end

    local xOffset, yOffset = GetTextSlotOffsets("textSlotTop")
    local fontSize = GetTextSlotSize("textSlotTop")
    local tr, tg, tb = GetTextSlotColor("textSlotTop")

    SetFSFont(fontString, fontSize, GetNPOutline())
    fontString:SetParent(self.topTextFrame)
    fontString:ClearAllPoints()
    PP.Point(fontString, "BOTTOM", self.health, "TOP", xOffset, 4 + GetNameYOffset() + GetClassPowerTopPush(self) + yOffset)
    fontString:SetJustifyH("CENTER")
    fontString:SetTextColor(tr, tg, tb, 1)
    fontString:Show()
end

-- Actualiza los valores numéricos de salud: refresca barras, hash line,
-- y aplica texto de salud (porcentaje, número, combinado) según la config
-- de slots de texto (textSlotRight/Left/Center/Top).
function NameplateFrame:RefreshHealthText(unit, valueOnly)
    local textValues = self:BuildHealthTextValues(unit)
    self.hpText:Hide()
    self.hpNumber:Hide()

    for si = 1, #HP_BAR_SLOTS do
        local slot = HP_BAR_SLOTS[si]
        local element = GetTextSlot(slot.key)
        if element == "healthPercent" or element == "healthPercentNoSign" then
            local text = (element == "healthPercentNoSign") and textValues.percentNoSign or textValues.percent
            self:ApplyHealthTextToSlot(self.hpText, text, slot, slot.key, valueOnly)
        elseif element == "healthNumber" then
            self:ApplyHealthTextToSlot(self.hpNumber, textValues.number, slot, slot.key, valueOnly)
        elseif element == "healthPctNum" or element == "healthNumPct" then
            self:ApplyHealthTextToSlot(self.hpText, FormatCombinedHealth(element, textValues.percent, textValues.number), slot, slot.key, valueOnly)
        end
    end

    self:ApplyTopHealthText(GetTextSlot("textSlotTop"), textValues, valueOnly)
end

function NameplateFrame:UpdateHealthValues()
    local unit = self:ResolveHealthUnit()
    if not unit then return end
    self:RefreshHealthBars(unit)
    self:RefreshHashLine(unit)
    self:RefreshHealthText(unit, false)
end

function NameplateFrame:UpdateHealthValue()
    local unit = self:ResolveHealthUnit()
    if not unit then return end
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("nameplates.health.paint")
    local config = KullThranUINameplatesDB or defaults
    local interpolation = Enum and Enum.StatusBarInterpolation
    local mode = config.animateHealthBar and interpolation and interpolation.ExponentialEaseOut
        or interpolation and interpolation.Immediate
    local health = UnitHealth(unit)
    if mode ~= nil then self.health:SetValue(health, mode) else self.health:SetValue(health) end
    self:RefreshHealthText(unit, true)
    if profileStarted then profiler:End("nameplates.health.paint", profileStarted) end
end

function NameplateFrame:UpdateAbsorbValue()
    local unit = self:ResolveHealthUnit()
    if not unit then return end
    local profiler = _G.KT and _G.KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("nameplates.absorb.paint")
    local config = KullThranUINameplatesDB or defaults
    if config.showShieldPrediction ~= false then
        if self._healthMax == nil then
            local maxHealth = UnitHealthMax(unit)
            self.absorb:SetMinMaxValues(0, maxHealth)
            if not ns._IsSecretValue(maxHealth) then self._healthMax = maxHealth end
        end
        local absorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0
        local interpolation = Enum and Enum.StatusBarInterpolation
        local mode = config.animateHealthBar and interpolation and interpolation.ExponentialEaseOut
            or interpolation and interpolation.Immediate
        if mode ~= nil then self.absorb:SetValue(absorb, mode) else self.absorb:SetValue(absorb) end
        self.absorb:Show()
    else
        self.absorb:SetValue(0)
        self.absorb:Hide()
    end
    if profileStarted then profiler:End("nameplates.absorb.paint", profileStarted) end
end

function NameplateFrame:UpdateHealthBounds()
    self._healthMax = nil
    self:UpdateHealthValues()
end
-- Brightens the final resolved color without changing its semantic state.
local function BrightenNameplateColor(r, g, b)
    if issecretvalue and (issecretvalue(r) or issecretvalue(g) or issecretvalue(b)) then
        return r, g, b
    end
    local theme = ns.NameplateStyle and ns.NameplateStyle()
    local native = theme == "classic" or theme == "forever" or theme == "retail"
    -- Retail keeps Blizzard's colours as they are; only the dark threat colours below are lifted.
    local gain = theme == "retail" and 1 or theme == "classic" and 1.5 or (native and 1.10 or 1.30)
    local lift = theme == "retail" and 0 or (native and 0.02 or 0.06)
    r, g, b = math.min(1, (r or 0) * gain + lift),
        math.min(1, (g or 0) * gain + lift), math.min(1, (b or 0) * gain + lift)
    if native then
        -- Group threat colours must remain readable without changing their hue.
        local peak = math.max(r, g, b)
        if peak > 0 and peak < 0.75 then
            local boost = 0.75 / peak
            r, g, b = r * boost, g * boost, b * boost
        end
    end
    return r, g, b
end
ns.BrightenNameplateColor = BrightenNameplateColor

-- Aplica el color de la barra de vida según GetReactionColor (8 niveles
-- de prioridad) y gestiona el overlay de focus (rayas) si la unidad
-- es el focus actual del jugador.
function NameplateFrame:UpdateHealthColor()
    local unit = self.unit
    if not unit then return end
    local hr, hg, hb = GetReactionColor(unit)
    self.health:SetStatusBarColor(BrightenNameplateColor(hr, hg, hb))
    -- Focus overlay: show stripe textures on focus target's health bar
    -- Fill clip frame at full alpha, bg clip frame at half alpha
    local db2 = KullThranUINameplatesDB or defaults
    local focusTex = db2.focusOverlayTexture or defaults.focusOverlayTexture
    if focusTex ~= "none" and UnitIsUnit(unit, "focus") then
        ns._AcquireVisualLayer(self, "focus")
        local MEDIA = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\"
        local texPath = MEDIA .. focusTex .. ".png"
        local overlayAlpha = db2.focusOverlayAlpha or defaults.focusOverlayAlpha
        local oc = db2.focusOverlayColor or defaults.focusOverlayColor
        self.focusOverlayFill:SetTexture(texPath)
        self.focusOverlayFill:SetAlpha(overlayAlpha)
        self.focusOverlayFill:SetVertexColor(oc.r, oc.g, oc.b)
        self.focusClipFill:Show()
        self.focusOverlayBg:SetTexture(texPath)
        self.focusOverlayBg:SetAlpha(overlayAlpha * 0.3)
        self.focusOverlayBg:SetVertexColor(oc.r, oc.g, oc.b)
        self.focusClipBg:Show()
    elseif self.focusClipFill then
        self.focusClipFill:Hide()
        self.focusClipBg:Hide()
    end
end

local INLINE_NAME_SLOTS = { "textSlotRight", "textSlotLeft", "textSlotCenter" }
local CLASSIFICATION_TEXTURE_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\Nemapltes-RareEliteIcons\\Untitled - 18 de agosto de 2026 a las 22.39.01.png"
ns.CLASSIFICATION_TEXTURE_PATH = CLASSIFICATION_TEXTURE_PATH
-- The custom elite dragon belongs to the KUI style; Classic, Retail and Forever use Blizzard's.
function ns.UseCustomEliteIcon()
    local style = ns.NameplateStyle and ns.NameplateStyle()
    return style == nil or style == "kui"
end
local CLASSIFICATION_TEXTURES = {
    elite = CLASSIFICATION_TEXTURE_PATH,
    worldboss = CLASSIFICATION_TEXTURE_PATH,
}

local CLASSIFICATION_ATLASES = {
    elite = "nameplates-icon-elite-gold",
    worldboss = "nameplates-icon-elite-gold",
    rareelite = "nameplates-icon-elite-silver",
    rare = "nameplates-icon-star",
}

local function SyncPlateUnitToken(frame)
    local unit = frame and frame.unit
    if not unit then
        return nil
    end

    local nameplate = frame.nameplate
    local liveToken = nameplate and nameplate.namePlateUnitToken
    if type(liveToken) == "string" and liveToken ~= "" and liveToken ~= unit then
        frame.unit = liveToken
        unit = liveToken
    end

    return unit
end

local function AnchorPlateAdornment(frame, slot, xOffset, yOffset, topPush)
    frame:ClearAllPoints()

    if slot == "top" then
        PP.Point(frame, "BOTTOM", frame:GetParent().health, "TOP", xOffset, GetDebuffYOffset() + topPush + yOffset)
        return true
    end

    if slot == "left" or slot == "right" then
        local sideOffset = ns.SideAuraXOffsetFor(frame:GetParent(), slot)
        local point = (slot == "left") and "RIGHT" or "LEFT"
        local relativePoint = (slot == "left") and "LEFT" or "RIGHT"
        local horizontal = (slot == "left") and (-sideOffset + xOffset) or (sideOffset + xOffset)
        PP.Point(frame, point, frame:GetParent().health, relativePoint, horizontal, yOffset)
        return true
    end

    if slot == "topleft" or slot == "topright" then
        local point = (slot == "topleft") and "BOTTOMLEFT" or "BOTTOMRIGHT"
        local relativePoint = (slot == "topleft") and "TOPLEFT" or "TOPRIGHT"
        local horizontal = (slot == "topleft") and (-2 + xOffset) or (2 + xOffset)
        PP.Point(frame, point, frame:GetParent().health, relativePoint, horizontal, topPush + yOffset)
        return true
    end

    return false
end

local LEVEL_NAME_GAP = 4

local function AnchorClassificationAdornment(frame, slot, xOffset, yOffset, topPush, parent)
    parent = parent or frame:GetParent()
    if slot == "topright" then
        -- Center the existing-size ornament on the bar corner so it embraces the border.
        -- Level badges and class power do not move this corner anchor.
        frame:ClearAllPoints()
        PP.Point(frame, "CENTER", parent.health, "TOPRIGHT",
            2 + (xOffset or 0), 2 + (yOffset or 0))
        return true
    end
    if slot == "topleft"
        and UseDynamicNameplateLevelLayout()
        and parent.level and parent.level:IsShown() then
        local health = parent.health
        local iconSize = GetRareEliteIconSize()
        local levelX = parent._dynamicLevelXOffset
            or tonumber(GetLevelConfigValue("levelXOffset")) or 24
        local horizontal = levelX - iconSize - LEVEL_NAME_GAP + (xOffset or 0)
        frame:ClearAllPoints()
        PP.Point(frame, "BOTTOMLEFT", health, "TOPLEFT", horizontal, (topPush or 0) + (yOffset or 0))
        return true
    end
    -- Disabled mode deliberately uses the existing anchor unchanged.
    return AnchorPlateAdornment(frame, slot, xOffset, yOffset, topPush)
end
ns.AnchorClassificationAdornment = AnchorClassificationAdornment
local function GetTopNameReservedWidth(frame, barWidth)
    local reservedWidth = 0

    if frame.raidFrame and frame.raidFrame:IsShown() and GetRaidMarkerPos() ~= "none" then
        reservedWidth = reservedWidth + (2 * (GetRaidMarkerSize() - 2)) + 7
    end

    if frame.classFrame and frame.classFrame:IsShown() and GetClassificationSlot() ~= "none"
        and not (ns.ThemeClassificationLeft and ns.ThemeClassificationLeft()) then
        local inset = GetRareEliteIconSize()
        if GetClassificationSlot() == "topright" then
            local x = select(1, ns._AuraLayout.ResolveOffsets("classification"))
            inset = math.max(0, inset * 0.5 - 2 - x)
        end
        reservedWidth = reservedWidth + inset + 4
    end

    return math.max(barWidth - reservedWidth, 20)
end

local function GetInlineNameReservedWidth(nameSlot)
    local reservedWidth = 0
    for _, slotKey in ipairs(INLINE_NAME_SLOTS) do
        if slotKey ~= nameSlot then
            local element = GetTextSlot(slotKey)
            if element and element ~= "none" and element ~= "enemyName" then
                reservedWidth = reservedWidth + EstimateHealthTextWidth(element)
            end
        end
    end
    return reservedWidth
end

-- Paso 3 commit: oculta las flechas de target si existen
local function HideTargetArrows(frame)
    ns.SetTargetIndicatorShown(frame, false)
end

-- Paso 3 commit: dimensiona y muestra las flechas de target usando el
-- descriptor previamente resuelto en ns._ResolveTargetVisuals.
local function CommitTargetArrows(frame, desc)
    if not desc.arrowsNeeded then
        HideTargetArrows(frame)
        return
    end
    ns._AcquireVisualLayer(frame, "arrows")
    ns.RefreshTargetIndicatorTextures(frame, desc.indicatorStyle, desc.arrowScale)
    ns.SetTargetIndicatorShown(frame, true)
    ns._AuraLayout.CommitArrowAnchors(frame)
end

-- Paso 3 commit: muestra u oculta los pips de class power en la placa
-- según el descriptor de estado visual.
local function CommitTargetClassPower(frame, desc)
    if not desc.classPowerNeeded then
        HideClassPowerOnPlate(frame)
        return
    end
    if not desc.isTarget then
        HideClassPowerOnPlate(frame)
        return
    end
    EnsureClassPowerPips(frame)
    UpdateClassPowerOnPlate(frame)
end

local function ApplyNameAnchor(frame, slotKey)
    local offsetX, offsetY = GetTextSlotOffsets(slotKey)
    SetFSFont(frame.name, GetTextSlotSize(slotKey), GetNPOutline())

    if slotKey == "textSlotTop" then
        frame.name:SetParent(frame.topTextFrame)
        local topPush = GetClassPowerTopPush(frame)
        PP.Point(frame.name, "BOTTOM", frame.health, "TOP", offsetX, 4 + GetNameYOffset() + topPush + offsetY)
        frame.name:SetJustifyH("CENTER")
        return true
    end

    frame.name:SetParent(frame.healthTextFrame)
    if slotKey == "textSlotLeft" then
        local lvlInset = (ns.ThemeLevelInset and ns.ThemeLevelInset(frame)) or 0
        PP.Point(frame.name, "LEFT", frame.health, "LEFT", 4 + offsetX + lvlInset, offsetY)
        frame.name:SetJustifyH("LEFT")
        return true
    end
    if slotKey == "textSlotCenter" then
        PP.Point(frame.name, "CENTER", frame.health, "CENTER", offsetX, offsetY)
        frame.name:SetJustifyH("CENTER")
        return true
    end
    if slotKey == "textSlotRight" then
        PP.Point(frame.name, "RIGHT", frame.health, "RIGHT", -2 + offsetX, offsetY)
        frame.name:SetJustifyH("RIGHT")
        return true
    end

    return false
end

function NameplateFrame:UpdateHealth()
    local unit = SyncPlateUnitToken(self)
    if not unit then
        return
    end

    self:UpdateHealthValues()
    self:UpdateHealthColor()
end
-- Actualiza el texto del nombre de la unidad en la placa.
function NameplateFrame:UpdateName()
    local unit = SyncPlateUnitToken(self)
    if not unit then
        self._displayNameText = ""
        self.name:SetText("")
        return
    end

    local displayName = UnitName(unit)
    local nameText
    if ns.IsAccessibleValue(displayName) and type(displayName) == "string" then
        nameText = displayName
    else
        nameText = ""
    end
    self._displayNameText = nameText

    -- Secret strings may still be displayed by FontString:SetText. Keep the
    -- original value for rendering, while the cached layout value above stays
    -- accessible so dynamic positioning can inspect it safely.
    if type(displayName) == "string" then
        self.name:SetText(displayName)
    else
        self.name:SetText("")
    end
end
local function EstimateTextWidth(text, fontSize, barWidth)
    if not ns.IsAccessibleValue(text) or type(text) ~= "string" or text == "" then return 0 end

    local size = tonumber(fontSize) or 11
    local width = tonumber(barWidth) or 0
    size = math.max(6, size)
    width = math.max(0, width)

    -- Use only accessible text/configuration values. Never query rendered
    -- FontString geometry, which can be secret or tainted in Retail.
    local estimated = string.len(text) * size * 0.65 + 6
    return math.min(width, math.max(0, estimated))
end

local function ResolveLevelXOffset(frame, baseX)
    if not UseDynamicNameplateLevelLayout() then
        return baseX, nil
    end

    local nameText = frame._displayNameText
    local levelText = frame._displayLevelText
    local nameSlot = FindSlotForElement("enemyName")
    local nameTextSafe = ns.IsAccessibleValue(nameText) and type(nameText) == "string"
    local levelTextSafe = ns.IsAccessibleValue(levelText) and type(levelText) == "string"
    if nameSlot ~= "textSlotTop"
        or not nameTextSafe or nameText == ""
        or not levelTextSafe or levelText == "" then
        return baseX, nil
    end

    local barWidth = GetHealthBarWidth()
    local nameSize = tonumber(GetTextSlotSize("textSlotTop")) or 12
    local levelSize = tonumber(GetLevelConfigValue("levelFontSize")) or 11
    local estimatedNameWidth = EstimateTextWidth(nameText, nameSize, barWidth)
    local estimatedLevelWidth = EstimateTextWidth(levelText, levelSize, barWidth)
    local safeLevelWidth = math.max(24, math.min(barWidth, estimatedLevelWidth))
    local nameStart = math.max(0, (barWidth - estimatedNameWidth) * 0.5)
    local candidate = nameStart - LEVEL_NAME_GAP - safeLevelWidth

    -- The base offset is retained for short names. Long names can move the
    -- level left as far as necessary to keep the four-pixel gap.
    -- Return the same safe estimate that UpdateLevelAnchor applies as the
    -- FontString width. This keeps the anchor math and rendered glyph box in
    -- agreement without querying protected FontString geometry.
    return math.min(baseX, candidate), safeLevelWidth
end

function NameplateFrame:UpdateLevelAnchor()
    if not self.level or not self.health then return end

    local baseX = tonumber(GetLevelConfigValue("levelXOffset")) or 24
    local y = tonumber(GetLevelConfigValue("levelYOffset")) or 4
    local x, dynamicLevelWidth = ResolveLevelXOffset(self, baseX)

    self._dynamicLevelXOffset = x
    if UseDynamicNameplateLevelLayout() and dynamicLevelWidth then
        PP.Width(self.level, dynamicLevelWidth)
    else
        -- Disabled mode keeps the previous auto-sized level layout exactly.
        PP.Width(self.level, 0)
    end
    self.level:ClearAllPoints()
    PP.Point(self.level, "BOTTOMLEFT", self.health, "TOPLEFT", x, y)
    if ns.ApplyThemeLevel then ns.ApplyThemeLevel(self) end
    -- The badge or quest icon may have changed size: side auras move past it.
    if ns.NPC_AnchorSides then ns.NPC_AnchorSides(self) end
    ns._AuraLayout.CommitArrowAnchors(self)
end
-- Muestra/oculta el nivel de la unidad con estilo y posición independientes.
function NameplateFrame:UpdateLevel()
    if not self.level then return end

    local unit = SyncPlateUnitToken(self)
    if not unit or not ShouldShowNameplateLevel(false) then
        self._displayLevelText = nil
        self.level:SetText("")
        self.level:Hide()
        self:UpdateLevelAnchor()
        return
    end

    local levelText = SafeUnitLevelText(unit)
    if not levelText then
        self._displayLevelText = nil
        self.level:SetText("")
        self.level:Hide()
        self:UpdateLevelAnchor()
        return
    end

    ApplyLevelTextStyle(self.level)
    local colorFor = ns.LevelTextDifficultyColor
    local lr, lg, lb
    if colorFor then lr, lg, lb = colorFor(unit) end
    if lr then self.level:SetTextColor(lr, lg, lb, 1) end
    self._displayLevelText = levelText
    self.level:SetText(levelText)
    PP.Height(self.level, math.max(16, (tonumber(GetLevelConfigValue("levelFontSize")) or 11) + 6))
    self.level:Show()
    self:UpdateLevelAnchor()
end
-- Muestra/oculta el icono de clasificación (elite, worldboss, rareelite, rare)
-- según el slot configurado. Dentro de instancia se oculta siempre.
function NameplateFrame:UpdateClassification()
    local unit = SyncPlateUnitToken(self)
    if not unit then
        self.classFrame:Hide()
        self:UpdateNameWidth()
        return
    end

    local slot = GetClassificationSlot()
    if slot == "none" or InRealInstancedContent() then
        self.classFrame:Hide()
        self:UpdateNameWidth()
        return
    end

    local classification = SafeUnitClassification(unit)
    local atlas = CLASSIFICATION_ATLASES[classification]
    local custom = CLASSIFICATION_TEXTURES[classification]
    local texturePath = ns.UseCustomEliteIcon() and custom or nil
    if not atlas and not texturePath then
        self.classFrame:Hide()
        self:UpdateNameWidth()
        return
    end

    if texturePath then
        self.class:SetTexture(texturePath)
        self.class:SetTexCoord(0, 1, 0, 1)
    elseif self.class:SetAtlas(atlas) == false and custom then
        -- a client without Blizzard's dragon atlas keeps the custom one
        texturePath = custom
        self.class:SetTexture(texturePath)
        self.class:SetTexCoord(0, 1, 0, 1)
    end
    if ns.ThemeClassificationLeft and ns.ThemeClassificationLeft() then
        -- Forever style: on the left end of the bar. UpdateNameWidth re-places the level,
        -- which moves the quest icon and side auras past it.
        ns.PlaceThemeClassification(self.classFrame, self.health, texturePath ~= nil)
        self.classFrame:Show()
        self:UpdateNameWidth()
        return
    end
    PP.Size(self.classFrame, GetRareEliteIconSize(), GetRareEliteIconSize())
    local offsetX, offsetY = ns._AuraLayout.ResolveOffsets("classification")
    AnchorClassificationAdornment(self.classFrame, slot, offsetX, offsetY, GetClassPowerTopPush(self))
    self.classFrame:Show()
    self:UpdateNameWidth()
end
function NameplateFrame:UpdateNameWidth()
    local barW = GetHealthBarWidth()
    local nameSlot = FindSlotForElement("enemyName")

    if nameSlot == "textSlotTop" then
        PP.Width(self.name, GetTopNameReservedWidth(self, barW))
        if self.UpdateLevelAnchor then self:UpdateLevelAnchor() end
        return
    end

    if nameSlot then
        local remainingWidth = barW - GetInlineNameReservedWidth(nameSlot)
        PP.Width(self.name, math.max(remainingWidth, 20))
        if self.UpdateLevelAnchor then self:UpdateLevelAnchor() end
        return
    end

    PP.Width(self.name, math.max(barW, 20))
    if self.UpdateLevelAnchor then self:UpdateLevelAnchor() end
end
-- Re-ancla el nombre de la unidad según el slot actual y refresca
-- auras y clasificación para mantener coherencia de layout.
function NameplateFrame:RefreshNamePosition()
    -- Keep the layout pass deterministic: acquire the accessible name first,
    -- size the name, then resolve the level offset before classification.
    self:UpdateName()
    local nameSlot = FindSlotForElement("enemyName")
    self:UpdateNameWidth()
    self.name:ClearAllPoints()

    local isFriendly = self.unit and not UnitCanAttack("player", self.unit) and not UnitIsUnit(self.unit, "player")
    local nameOnly = isFriendly and ns and ns.IsNameOnlyMode and ns.IsNameOnlyMode()
    if nameOnly or not nameSlot or not ApplyNameAnchor(self, nameSlot) then
        self.name:Hide()
    else
        self.name:Show()
    end

    self:UpdateLevel()
    self:UpdateClassification()
    self:UpdateAuras()
end

local function ValidateNameplateLevelMethods()
    assert(type(NameplateFrame.UpdateLevel) == "function", "NameplateFrame.UpdateLevel must remain a function")
    assert(type(NameplateFrame.UpdateLevelAnchor) == "function", "NameplateFrame.UpdateLevelAnchor must remain a function")
    assert(type(NameplateFrame.UpdateClassification) == "function", "NameplateFrame.UpdateClassification must remain a function")
end

ValidateNameplateLevelMethods()
-- Muestra/oculta el icono de marca de raid en la posición configurada.
function NameplateFrame:UpdateRaidIcon()
    local wasShown = self.raidFrame:IsShown()
    -- A top marker lifts the debuff row: lay the auras out again when it
    -- appears or goes away.
    local function RelayoutTopAuras()
        if wasShown ~= self.raidFrame:IsShown() and GetRaidMarkerPos() == "top" and self.UpdateAuras then
            self:UpdateAuras()
        end
    end
    local unit = SyncPlateUnitToken(self)
    if not unit then
        self.raidFrame:Hide()
        self:UpdateNameWidth()
        RelayoutTopAuras()
        return
    end

    local pos = GetRaidMarkerPos()
    local markerIndex = GetRaidTargetIndex and GetRaidTargetIndex(unit)
    if pos == "none" or type(markerIndex) == "nil" then
        self.raidFrame:Hide()
        self:UpdateNameWidth()
        RelayoutTopAuras()
        return
    end

    SetRaidTargetIconTexture(self.raid, markerIndex)
    PP.Size(self.raidFrame, GetRaidMarkerSize(), GetRaidMarkerSize())
    local offsetX, offsetY = ns._AuraLayout.ResolveOffsets("raidMarker")
    if pos == "top" and self.name and self.name:IsShown() then
        -- Centred just above the name, under the debuff row.
        self.raidFrame:ClearAllPoints()
        PP.Point(self.raidFrame, "BOTTOM", self.name, "TOP", offsetX, 2 + offsetY)
    else
        AnchorPlateAdornment(self.raidFrame, pos, offsetX, offsetY, GetClassPowerTopPush(self))
    end
    self.raidFrame:Show()
    self:UpdateNameWidth()
    RelayoutTopAuras()
end
-- Paso 3 commit: aplica el estado visual de target sobre la placa.
-- Consume el descriptor de ns._ResolveTargetVisuals para decidir qué
-- capas mostrar/ocultar, evitando recálculos redundantes.
function NameplateFrame:ApplyTarget()
    local unit = SyncPlateUnitToken(self)
    if not unit then
        return
    end

    -- Paso 1: resolver estado visual completo
    local desc = ns._ResolveTargetVisuals(self, unit)

    -- Classic / Retail / Forever draw Blizzard's own selection (frame, highlight, darkened
    -- non-targets) unless the target glow style is "none"; the generic glow then stays hidden.
    local themedSelection = ns.ApplyThemeTargetGlow
        and ns.ApplyThemeTargetGlow(self, desc.isTarget, GetTargetGlowStyle() ~= "none")

    -- Paso 2+3: glow – adquirir recurso sólo si lo necesitamos
    if desc.glowNeeded and not themedSelection then
        ns._AcquireVisualLayer(self, "glow")
        local glowColor = (db and db.targetGlowColor) or defaults.targetGlowColor
        local glowR = (glowColor and (glowColor.r or glowColor[1])) or 0.4117
        local glowG = (glowColor and (glowColor.g or glowColor[2])) or 0.6667
        local glowB = (glowColor and (glowColor.b or glowColor[3])) or 1.0
        for _, tex in ipairs(self.glow._textures or {}) do
            tex:SetVertexColor(glowR, glowG, glowB, 1)
        end
        self.glow:Show()
    elseif self.glow then
        self.glow:Hide()
    end

    -- Paso 3: bordes – vibrant tiñe de blanco; todo lo demás restaura color
    if desc.vibrantBorder then
        local color = (db and db.targetGlowColor) or defaults.targetGlowColor
        local r = (color and (color.r or color[1])) or 0.4117
        local g = (color and (color.g or color[2])) or 0.6667
        local b = (color and (color.b or color[3])) or 1.0
        for _, tex in ipairs(self.borderFrame._texs) do tex:SetVertexColor(r, g, b) end
        for _, tex in ipairs(self._simpleBorderFrame._texs) do tex:SetVertexColor(r, g, b) end
    else
        self:ApplyBorderColor()
    end

    -- Paso 3: flechas y class power desde descriptor
    CommitTargetArrows(self, desc)
    CommitTargetClassPower(self, desc)
end
-- Muestra/oculta el highlight de mouseover y registra la placa en
-- transitionState para el ticker de seguimiento de mouseover.
function NameplateFrame:ApplyMouseover()
    local unit = SyncPlateUnitToken(self)
    if not unit then
        self.highlight:Hide()
        return
    end

    local isMouseover = UnitExists("mouseover") and UnitIsUnit(unit, "mouseover")
    if isMouseover then
        self.highlight:Show()
        if ns._npTransitionState then
            ns._npTransitionState.currentMouseoverPlate = self
        end
    else
        self.highlight:Hide()
    end
end
-- Actualiza las 3 categorías de auras (debuffs, buffs, CC) en la placa.
-- El flujo tiene 6 fases:
--   F1: Guardia → abortar si la unidad ya no es válida
--   F2: Detección incremental → si updateInfo contiene cambios relevantes
--       (added/removed/updated que afecten _shownAuras), continuar; si no, salir
--   F3: Limpieza → resetear todas las ranuras (cooldowns, iconos, glows)
--   F4: Poblar → iterar GetUnitAuras por tipo (HARMFUL|PLAYER, HELPFUL, CC)
--       y llenar ranuras con icono/cooldown/glow correspondiente
--   F5: Layout → dimensionar y posicionar cada grupo según configuración
--   F6: Flechas → re-anclar flechas de target fuera de las auras más externas
function ns.GetAccessibleUnitAuras(unit, filter)
    local result = {}
    if not (unit and C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot) then
        return result
    end
    local function PackSlots(...)
        return { n = select("#", ...), ... }
    end
    local ok, slots = pcall(function()
        return PackSlots(C_UnitAuras.GetAuraSlots(unit, filter))
    end)
    if not ok or type(slots) ~= "table" then return result end
    -- `slots` is our own positional table; no Blizzard-owned collection is
    -- exposed to pairs/ipairs from tainted execution.
    for i = 2, slots.n or 0 do
        local okAura, aura = pcall(C_UnitAuras.GetAuraDataBySlot, unit, slots[i])
        if okAura and type(aura) == "table" then
            result[#result + 1] = aura
        end
    end
    return result
end

function NameplateFrame:UpdateAuras(updateInfo)
    -- F1: Guardia de validez
    if not self.unit or not self.nameplate then return end
    if ns.NPC_Update then
        ns.NPC_Update(self)
        return
    end
    local unit = self.unit

    -- Never iterate UNIT_AURA's incremental payload. In PvP its nested lists
    -- can become inaccessible after a successful `next` probe when execution
    -- is tainted by a profiler. A slot-based refresh is deterministic and does
    -- not touch Blizzard-owned tables.
    updateInfo = nil

    -- Always perform a full slot-based refresh. The incremental UNIT_AURA
    -- payload contains Blizzard-owned collections that are restricted in PvP.
    -- F3: Limpieza — resetear todas las ranuras antes de repoblar.
    -- Usa ns._ResetAuraCooldown para el reset unificado de cooldowns.
    if not self._shownAuras then
        self._shownAuras = {}
    else
        wipe(self._shownAuras)
    end

    local resetCD = ns._ResetAuraCooldown
    for i = 1, 4 do
        local dSlot = self.debuffs[i]
        local bSlot = self.buffs[i]
        dSlot:Hide()
        dSlot.icon:SetTexture(nil)
        if dSlot.pandemicGlow and dSlot.pandemicGlow.active then
            ns.StopPandemicGlow(dSlot)
        end
        dSlot._durationObj = nil
        dSlot._expirationTime = nil
        dSlot._durationSeconds = nil
        dSlot._typeColor = nil
        bSlot:Hide()
        bSlot.icon:SetTexture(nil)
        if bSlot.dispelGlow and bSlot.dispelGlow.active then
            ns.StopDispelGlow(bSlot)
        end
        resetCD(dSlot.cd)
        resetCD(bSlot.cd)
    end
    for i = 1, 2 do
        local ccSlot = self.cc[i]
        ccSlot:Hide()
        ccSlot.icon:SetTexture(nil)
        resetCD(ccSlot.cd)
    end
    -- F4: Poblar — obtener auras por tipo y llenar las ranuras disponibles
    -- Get slot assignments; skip processing for any slot set to "none"
    local debuffSlotVal, buffSlotVal, ccSlotVal = GetAuraSlots()
    local dIdx = 1
    -- F4a: Debuffs (HARMFUL|PLAYER) — filtro por importancia si showAllDebuffs está desactivado
    if debuffSlotVal ~= "none" then
    -- Do not inspect Blizzard's debuffList. The slot snapshot below is owned by
    -- KUI and remains iterable even when the native list becomes restricted.
    if C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot then
        -- 12.1 compat: HARMFUL|PLAYER may return empty in some contexts.
        -- Fall back to HARMFUL|INCLUDE_NAME_PLATE_ONLY, then bare HARMFUL.
        local allDebuffs = ns.GetAccessibleUnitAuras(unit, "HARMFUL|PLAYER")
        if not allDebuffs or #allDebuffs == 0 then
            allDebuffs = ns.GetAccessibleUnitAuras(unit, "HARMFUL|INCLUDE_NAME_PLATE_ONLY")
        end
        if not allDebuffs or #allDebuffs == 0 then
            allDebuffs = ns.GetAccessibleUnitAuras(unit, "HARMFUL")
        end
        if allDebuffs then
            for _, aura in ipairs(allDebuffs) do
                if dIdx > 4 then break end
                local id = aura and aura.auraInstanceID
                if id and aura.icon then
                        local slot = self.debuffs[dIdx]
                        slot.icon:SetTexture(aura.icon)
                        slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        slot.icon:Show()
                        if C_UnitAuras_GetAuraAppDisplayCount then
                            slot.count:SetText(C_UnitAuras_GetAuraAppDisplayCount(unit, id, 2, 1000) or "")
                        end
                        local cd = slot.cd
                        if cd and C_UnitAuras_GetAuraDuration then
                            local durObj = C_UnitAuras_GetAuraDuration(unit, id)
                            if durObj and cd.SetCooldownFromDurationObject then
                                if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
                                cd:SetCooldownFromDurationObject(durObj)
                                cd:Show()
                            end
                            slot._durationObj = durObj
                            slot._expirationTime = aura.expirationTime
                            slot._durationSeconds = aura.duration
                            slot._typeColor = ns.GetAuraTypeColor and ns.GetAuraTypeColor(unit, aura)
                            ns.trackedExpirySlots = ns.trackedExpirySlots or {}
                            ns.trackedExpirySlots[slot] = true
                            if ns.ArmPandemicTick then ns.ArmPandemicTick() end
                        else
                            slot._durationObj = nil
                            slot._expirationTime = aura.expirationTime
                            slot._durationSeconds = aura.duration
                            slot._typeColor = ns.GetAuraTypeColor and ns.GetAuraTypeColor(unit, aura)
                            if ns.trackedExpirySlots then
                                ns.trackedExpirySlots[slot] = nil
                            end
                        end
                        slot:Show()
                        ns.UpdateDebuffExpiryGlow(slot, slot._typeColor)
                        self._shownAuras[id] = true
                        dIdx = dIdx + 1
                end
            end
        end
    end
    local debuffCount = dIdx - 1
    if debuffCount > 0 then
        local spacing = GetAuraSpacing()
        local debuffSz = GetDebuffIconSize()
        for i = 1, debuffCount do
            PP.Size(self.debuffs[i], debuffSz, debuffSz)
        end
        do
            local debuffX, debuffY = ns._AuraLayout.ResolveOffsets("debuffSlot")
            ns._AuraLayout.Commit(self.debuffs, debuffCount,
                ns._AuraLayout.BuildPlacement(debuffSlotVal, debuffCount, debuffSz, spacing, self, debuffX, debuffY, "debuffSlot"))
        end
    end
    -- Pandemic glow check for debuffs
    local pandemicEnabled = ns.GetPandemicGlow()
    for i = 1, 4 do
        local slot = self.debuffs[i]
        local pg = slot.pandemicGlow
        if i <= (dIdx - 1) and pandemicEnabled then
            ns.ApplyPandemicGlow(slot)
        else
            if pg and pg.active then
                ns.StopPandemicGlow(slot)
            end
        end
        if i > (dIdx - 1) or not slot._durationObj then
            ns.StopDebuffExpiryGlow(slot)
        end
    end
    end -- debuffSlotVal ~= "none"
    -- F4b: Buffs (HELPFUL|INCLUDE_NAME_PLATE_ONLY) — sólo dispelables en enemigos
    if buffSlotVal ~= "none" then
    if UnitCanAttack("player", unit) and C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot then
        -- INCLUDE_NAME_PLATE_ONLY replaces Blizzard buffList:Iterate safely.
        local allBuffs = ns.GetAccessibleUnitAuras(unit, "HELPFUL|INCLUDE_NAME_PLATE_ONLY")
        local bIdx = 1
        local dispelGlowEnabled = ns.GetDispelGlow and ns.GetDispelGlow()
        if allBuffs then
            for _, aura in ipairs(allBuffs) do
                if bIdx > 4 then break end
                local id = aura and aura.auraInstanceID
                if id and aura.icon then
                    local slot = self.buffs[bIdx]
                    slot.icon:SetTexture(aura.icon)
                    slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    slot.icon:Show()
                    if C_UnitAuras_GetAuraAppDisplayCount then
                        slot.count:SetText(C_UnitAuras_GetAuraAppDisplayCount(unit, id, 2, 1000) or "")
                    end
                    local cd = slot.cd
                    if cd and C_UnitAuras_GetAuraDuration then
                        local durObj = C_UnitAuras_GetAuraDuration(unit, id)
                        if durObj and cd.SetCooldownFromDurationObject then
                            if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
                            cd:SetCooldownFromDurationObject(durObj)
                            cd:Show()
                        end
                    end
                    local canDispel, typeColor = ns.CanDispelAura and ns.CanDispelAura(unit, aura)
                    if dispelGlowEnabled and canDispel then
                        ns.StartDispelGlow(slot, GetBuffIconSize(), typeColor)
                    elseif slot.dispelGlow and slot.dispelGlow.active then
                        ns.StopDispelGlow(slot)
                    end
                    slot:Show()
                    self._shownAuras[id] = true
                    bIdx = bIdx + 1
                end
            end
        end
    end
    end -- buffSlotVal ~= "none"
    -- F4c: CC (HARMFUL|CROWD_CONTROL) — máximo 2 ranuras de crowd control
    local ccShown = 0
    if ccSlotVal ~= "none" then
    if C_UnitAuras and C_UnitAuras.GetAuraSlots and C_UnitAuras.GetAuraDataBySlot then
        local ccAuras = ns.GetAccessibleUnitAuras(unit, "HARMFUL|CROWD_CONTROL")
        if ccAuras then
            for _, aura in ipairs(ccAuras) do
                if ccShown >= 2 then break end
                if aura and aura.auraInstanceID and aura.icon then
                    ccShown = ccShown + 1
                    local slot = self.cc[ccShown]
                    slot.icon:SetTexture(aura.icon)
                    slot.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    slot.icon:Show()
                    local cd = slot.cd
                    if cd and C_UnitAuras_GetAuraDuration then
                        local durObj = C_UnitAuras_GetAuraDuration(unit, aura.auraInstanceID)
                        if durObj and cd.SetCooldownFromDurationObject then
                            if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
                            cd:SetCooldownFromDurationObject(durObj)
                            cd:Show()
                        end
                    end
                    slot:Show()
                    self._shownAuras[aura.auraInstanceID] = true
                end
            end
        end
    end
    end -- ccSlotVal ~= "none"
    -- F5: Layout — dimensionar y posicionar cada grupo de auras según config
    if buffSlotVal ~= "none" then
        local buffCount = 0
        for i = 1, 4 do if self.buffs[i]:IsShown() then buffCount = buffCount + 1 end end
        if buffCount > 0 then
            local spacing = GetAuraSpacing()
            local buffSz = GetBuffIconSize()
            for i = 1, buffCount do
                PP.Size(self.buffs[i], buffSz, buffSz)
            end
            do
                local buffX, buffY = ns._AuraLayout.ResolveOffsets("buffSlot")
                ns._AuraLayout.Commit(self.buffs, buffCount,
                    ns._AuraLayout.BuildPlacement(buffSlotVal, buffCount, buffSz, spacing, self, buffX, buffY, "buffSlot"))
            end
        end
    end
    if ccSlotVal ~= "none" and ccShown > 0 then
        local spacing = GetAuraSpacing()
        local ccSz = GetCCIconSize()
        for i = 1, ccShown do
            PP.Size(self.cc[i], ccSz, ccSz)
        end
        do
            local ccX, ccY = ns._AuraLayout.ResolveOffsets("ccSlot")
            ns._AuraLayout.Commit(self.cc, ccShown,
                ns._AuraLayout.BuildPlacement(ccSlotVal, ccShown, ccSz, spacing, self, ccX, ccY, "ccSlot"))
        end
    end
    -- F6: Flechas — re-anclar fuera de las auras más externas
    ns._AuraLayout.CommitArrowAnchors(self)
end
function NameplateFrame:ResolveCastInfo()
    local unit = self.unit
    if not unit then
        return nil
    end

    local castName, _, texture, _, _, _, _, kickProtected = UnitCastingInfo(unit)
    if type(castName) ~= "nil" then
        return castName, texture, kickProtected, false
    end

    castName, _, texture, _, _, _, kickProtected = UnitChannelInfo(unit)
    if type(castName) ~= "nil" then
        return castName, texture, kickProtected, true
    end

    return nil
end

function NameplateFrame:ResolveCastTarget()
    local unit = self.unit
    if not unit then
        return nil, nil
    end

    local targetName
    local classToken
    if UnitSpellTargetName then
        targetName = UnitSpellTargetName(unit)
    end
    if UnitSpellTargetClass then
        classToken = UnitSpellTargetClass(unit)
    end

    if targetName or classToken then
        return targetName, classToken
    end

    local targetUnit = unit .. "target"
    return UnitName(targetUnit), UnitClassBase(targetUnit)
end

function NameplateFrame:ClearInterruptedCastState()
    if not self._interrupted then
        return
    end

    self._interrupted = nil
    self:CancelInterruptTimer()
end

function NameplateFrame:RefreshTargetClassPowerPosition()
    if GetShowClassPower() and ns.NameplatesClassPower.resourceType and self._cpPips and self.unit and UnitIsUnit(self.unit, "target") then
        UpdateClassPowerOnPlate(self)
    end
end

-- Detiene el tracking de casteo activo: oculta la barra (a menos que esté
-- en estado interrupted), limpia el fallback OnUpdate si estaba activo,
-- y restaura la escala de la placa.
function NameplateFrame:StopCastTracking()
    if not self._interrupted then
        self.cast:Hide()
    end

    if self.isCasting then
        if self._castFallback then ns._ReleaseCastFallback(self) end
        EndInterruptTracking()
    end

    self.isCasting = false
    self._castIsChannel = nil
    self:HideKickTick()
    self:ApplyCastScale()
    self:RefreshTargetClassPowerPosition()
end

-- Configura la representación visual de un casteo: icono, nombre, target,
-- color de interruptibilidad, shield overlay. Retorna kickProtected para
-- que el caller pueda decidir si mostrar el kick tick.
function NameplateFrame:ApplyCastPresentation(castName, texture, kickProtected)
    self.cast:Show()

    if type(texture) ~= "nil" then
        self.castIcon:SetTexture(texture)
    end

    self.castName:SetText(type(castName) ~= "nil" and castName or "")

    local targetName, classToken = self:ResolveCastTarget()
    self.castTarget:SetText(type(targetName) ~= "nil" and targetName or "")
    self:ApplyCastTargetColorFromToken(classToken)

    PP.Width(self.castName, 0)
    self.castName:ClearAllPoints()
    PP.Point(self.castName, "LEFT", self.cast, "LEFT", 5, 0)
    PP.Point(self.castName, "RIGHT", self.castTarget, "LEFT", -5, 0)

    if type(kickProtected) == "nil" then
        kickProtected = false
    end

    self._kickProtected = kickProtected

    local cfg = KullThranUINameplatesDB or defaults
    local uninterruptibleColor = cfg.castBarUninterruptible or defaults.castBarUninterruptible
    self.castBarOverlay:SetVertexColor(uninterruptibleColor.r, uninterruptibleColor.g, uninterruptibleColor.b)
    self.castShieldFrame:Show()
    self:ApplyCastColor(kickProtected)

    return kickProtected
end

-- Inicia el timeline de casteo usando la API moderna (SetTimerDuration)
-- o el fallback OnUpdate (para versiones <12.0.5 sin UnitCastingDuration).
function NameplateFrame:StartCastTimeline(isChannel)
    local unit = self.unit
    self._castIsChannel = isChannel and true or false
    if self.cast.SetFillStyle and Enum and Enum.StatusBarFillStyle then
        self.cast:SetFillStyle(isChannel
            and Enum.StatusBarFillStyle.Reverse
            or Enum.StatusBarFillStyle.Standard)
    elseif self.cast.SetReverseFill then
        self.cast:SetReverseFill(isChannel and true or false)
    end

    if UnitCastingDuration and self.cast.SetTimerDuration then
        local castDuration
        local timerDirection

        if isChannel then
            castDuration = UnitChannelDuration(unit)
            -- Reverse fill + elapsed time advances from right to left.
            timerDirection = Enum.StatusBarTimerDirection.ElapsedTime
        else
            castDuration = UnitCastingDuration(unit)
            timerDirection = Enum.StatusBarTimerDirection.ElapsedTime
        end

        if castDuration then
            self.cast:SetTimerDuration(castDuration, nil, timerDirection)
        end

        if not self.isCasting then
            BeginInterruptTracking()
        end

        self.isCasting = true
        return
    end

    if self.isCasting then
        return
    end

    self.isCasting = true
    self._castFallback = true
    _fallbackPlates[self] = true
    fallbackCastCount = fallbackCastCount + 1
    castFallbackFrame:Show()
    BeginInterruptTracking()
end

-- Punto de entrada principal de actualización de casteo. Resuelve la info
-- del casteo actual (nombre, textura, kickProtected, isChannel), aplica
-- la presentación visual, inicia el timeline y configura el kick tick.
function NameplateFrame:UpdateCast()
    local castName, texture, kickProtected, isChannel = self:ResolveCastInfo()
    if not castName then
        self:StopCastTracking()
        return
    end

    self:ClearInterruptedCastState()
    kickProtected = self:ApplyCastPresentation(castName, texture, kickProtected)
    self:StartCastTimeline(isChannel)
    self:ApplyCastScale()
    self:UpdateKickTick(kickProtected, isChannel)
    self:RefreshTargetClassPowerPosition()
end
-- Aplica la escala de placa durante casteo (configurable en DB).
function NameplateFrame:ApplyCastScale()
    local s = GetCastScale() / 100
    if self.isCasting and s ~= 1 then
        self:SetScale(s)
    else
        self:SetScale(1)
    end
end
-- Aplica el color de la barra de casteo: tint normal o interrupt-ready,
-- y gestiona el overlay de no-interruptible usando SetAlphaFromBoolean.
function NameplateFrame:ApplyCastColor(uninterruptible)
    local cfg = KullThranUINameplatesDB or defaults
    local readyTint = cfg.interruptReady or defaults.interruptReady
    local cooldownTint = cfg.castBar or defaults.castBar
    local uninterruptibleTint = cfg.castBarUninterruptible or defaults.castBarUninterruptible
    local normalR, normalG, normalB = SelectCastBarTint(readyTint, cooldownTint)
    local cr, cg, cb = normalR, normalG, normalB

    if C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        cr = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, uninterruptibleTint.r, normalR)
        cg = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, uninterruptibleTint.g, normalG)
        cb = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, uninterruptibleTint.b, normalB)
    elseif uninterruptible then
        cr, cg, cb = uninterruptibleTint.r, uninterruptibleTint.g, uninterruptibleTint.b
    end

    self.cast:SetStatusBarColor(1, 1, 1, 1)
    self.cast:GetStatusBarTexture():SetVertexColor(cr, cg, cb)
    self.castBarOverlay:SetVertexColor(uninterruptibleTint.r, uninterruptibleTint.g, uninterruptibleTint.b)
    if self.castBarOverlay.SetAlphaFromBoolean then
        self.castBarOverlay:SetAlphaFromBoolean(uninterruptible)
        self.castShieldFrame:SetAlphaFromBoolean(uninterruptible)
    elseif C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local a = C_CurveUtil.EvaluateColorValueFromBoolean(uninterruptible, 1, 0)
        self.castBarOverlay:SetAlpha(a)
        self.castShieldFrame:SetAlpha(a)
    else
        local a = uninterruptible and 1 or 0
        self.castBarOverlay:SetAlpha(a)
        self.castShieldFrame:SetAlpha(a)
    end

    MaybeDebugCastColor(self, readyTint, cooldownTint, uninterruptibleTint)
end
-- Cancela el ticker periódico que actualiza la visibilidad del kick tick.
function NameplateFrame:StopKickTicker()
    if self._kickTicker then
        self._kickTicker:Cancel()
        self._kickTicker = nil
    end
end

-- Ancla las barras de kick tick respetando reverseFill (canales vs casteos).
function NameplateFrame:ConfigureKickTickAnchors(reverseFill)
    self.kickMarker:ClearAllPoints()
    self.kickTick:ClearAllPoints()

    if reverseFill then
        self.kickPositioner:SetFillStyle(Enum.StatusBarFillStyle.Reverse)
        self.kickMarker:SetFillStyle(Enum.StatusBarFillStyle.Reverse)
        self.kickMarker:SetPoint("RIGHT", self.kickPositioner:GetStatusBarTexture(), "LEFT")
        self.kickTick:SetPoint("TOP", self.kickMarker, "TOP")
        self.kickTick:SetPoint("BOTTOM", self.kickMarker, "BOTTOM")
        self.kickTick:SetPoint("RIGHT", self.kickMarker:GetStatusBarTexture(), "LEFT")
        return
    end

    self.kickPositioner:SetFillStyle(Enum.StatusBarFillStyle.Standard)
    self.kickMarker:SetFillStyle(Enum.StatusBarFillStyle.Standard)
    self.kickMarker:SetPoint("LEFT", self.kickPositioner:GetStatusBarTexture(), "RIGHT")
    self.kickTick:SetPoint("TOP", self.kickMarker, "TOP")
    self.kickTick:SetPoint("BOTTOM", self.kickMarker, "BOTTOM")
    self.kickTick:SetPoint("LEFT", self.kickMarker:GetStatusBarTexture(), "RIGHT")
end

-- Actualiza la opacidad del marcador de kick según si el interrupt
-- está disponible (CD = 0) y si el casteo es interruptible.
function NameplateFrame:RefreshKickTickAlpha(interruptDuration)
    if interruptDuration and interruptDuration.IsZero and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
        local interruptible = C_CurveUtil.EvaluateColorValueFromBoolean(self._kickProtected, 0, 1)
        local kickReady = interruptDuration:IsZero()
        local alpha = C_CurveUtil.EvaluateColorValueFromBoolean(kickReady, 0, interruptible)
        self.kickTick:SetAlpha(alpha)
        return
    end

    local kickReady = false
    if interruptDuration and interruptDuration.GetRemainingDuration then
        kickReady = interruptDuration:GetRemainingDuration() == 0
    end

    self.kickTick:SetAlpha((self._kickProtected or kickReady) and 0 or 1)
end

-- Prepara las barras de posicionamiento del kick tick: dimensiona,
-- establece min/max y valor inicial del positioner y marker.
function NameplateFrame:PrimeKickTickBars(castDuration, interruptDuration, reverseFill)
    local width = self.cast:GetWidth()
    local height = GetCastBarHeight()
    local maxDuration = castDuration:GetTotalDuration()

    self.kickPositioner:SetSize(width, height)
    self.kickPositioner:SetMinMaxValues(0, maxDuration)
    self.kickPositioner:SetValue(castDuration:GetElapsedDuration())

    self.kickMarker:SetSize(width, height)
    self.kickMarker:SetMinMaxValues(0, maxDuration)
    self.kickMarker:SetValue(interruptDuration:GetRemainingDuration())

    local r, g, b = GetKickTickColor()
    self.kickTick:SetColorTexture(r, g, b, 1)
    self:ConfigureKickTickAnchors(reverseFill)
    self.kickPositioner:Show()
    self.kickMarker:Show()
    self.kickTick:Show()
    self:RefreshKickTickAlpha(interruptDuration)
end

-- Oculta completamente el kick tick (positioner + marker + ticker).
function NameplateFrame:HideKickTick()
    self.kickPositioner:Hide()
    self.kickMarker:Hide()
    self.kickTick:Hide()
    self:StopKickTicker()
end
-- Punto de entrada del kick tick: si está habilitado y hay un spell de kick
-- activo, calcula duraciones y configura el ticker de refresco periódico.
-- kickProtected es un "secret boolean" en Midnight (no se puede branchar).
function NameplateFrame:UpdateKickTick(kickProtected, isChannel)
    if not GetKickTickEnabled() or not activeKickSpell then
        self:HideKickTick()
        return
    end
    -- kickProtected es secret boolean: almacenar para usar con SetAlphaFromBoolean
    self._kickProtected = kickProtected

    -- Midnight path: the tick runs on secret duration objects, so every piece
    -- of that API has to exist or the tick stays hidden.
    local cooldownOf = C_Spell and C_Spell.GetSpellCooldownDuration
    if not (cooldownOf and UnitCastingDuration and self.cast.SetTimerDuration) then
        self:HideKickTick()
        return
    end
    local castDuration = isChannel and UnitChannelDuration(self.unit) or UnitCastingDuration(self.unit)
    local kickCooldown = castDuration and cooldownOf(activeKickSpell)
    if not kickCooldown then
        self:HideKickTick()
        return
    end

    local reverseFill = self.cast.GetReverseFill and self.cast:GetReverseFill() or (isChannel and true or false)
    self:PrimeKickTickBars(castDuration, kickCooldown, reverseFill)
    self:StopKickTicker()
    self._kickTicker = C_Timer.NewTicker(0.1, function()
        local profiler = _G.KT and _G.KT.CombatProfiler
        local profileStarted = profiler and profiler:Begin("nameplates.kick_tick.tick")
        local liveCooldown = self.isCasting and self.unit and cooldownOf(activeKickSpell)
        if liveCooldown then
            -- The duration object is already refreshed at 10 Hz here.  Updating
            -- the marker in-place avoids rebuilding anchors and recreating this
            -- ticker on every global SPELL_UPDATE_COOLDOWN event.
            self.kickMarker:SetValue(liveCooldown:GetRemainingDuration())
            self:RefreshKickTickAlpha(liveCooldown)
        else
            self:HideKickTick()
        end
        if profileStarted then
            profiler:End("nameplates.kick_tick.tick", profileStarted)
        end
    end)
end
-- Resuelve nombre y classToken del interruptor a partir de su GUID.
-- Intenta UnitNameFromGUID primero (disponible en Midnight), luego
-- fallback a UnitTokenFromGUID → UnitName/UnitClassBase.
ns._ResolveInterrupterInfo = function(guid)
    if not guid then return nil, nil end
    if UnitNameFromGUID then
        local name = UnitNameFromGUID(guid)
        local _, class = GetPlayerInfoByGUID(guid)
        if name then return name, class end
    end
    local token = UnitTokenFromGUID(guid)
    if token then
        return UnitName(token), UnitClassBase(token)
    end
    return nil, nil
end

-- Muestra el estado "Interrupted" en la barra de casteo de la placa.
-- Primero cancela el tracking activo, luego pinta la barra en rojo,
-- resuelve el nombre del interruptor y programa un timer de 1 s para
-- ocultar todo automáticamente.
function NameplateFrame:ShowInterrupted(interrupterGUID)
    -- Cancelar tracking de casteo activo antes de tocar la UI
    if self.isCasting then
        if self._castFallback then ns._ReleaseCastFallback(self) end
        EndInterruptTracking()
    end
    self.isCasting = false
    self:HideKickTick()
    self:ApplyCastScale()

    -- Pintar la barra de casteo como interrumpida: rojo lleno, texto fijo
    self._interrupted = true
    self.cast:SetReverseFill(false)
    self.cast:SetMinMaxValues(0, 1)
    self.cast:SetValue(1)
    self.cast:SetStatusBarColor(1, 1, 1, 1)
    self.cast:GetStatusBarTexture():SetVertexColor(0.8, 0.0, 0.0)
    self.castName:SetText(LText("Interrupted"))

    -- Resolver y mostrar el nombre del interruptor con color de clase
    local intName, intClass = ns._ResolveInterrupterInfo(interrupterGUID)
    if intName then
        self.castTarget:SetText(intName)
        self:ApplyCastTargetColorFromToken(intClass)
    else
        self.castTarget:SetText("")
    end

    -- Re-anclar nombre y objetivo de casteo para el texto de interrupción
    PP.Width(self.castName, 0)
    self.castName:ClearAllPoints()
    PP.Point(self.castName, "LEFT", self.cast, "LEFT", 5, 0)
    PP.Point(self.castName, "RIGHT", self.castTarget, "LEFT", -5, 0)
    self:ResetCastDecor()
    self.cast:Show()

    -- Programar auto-ocultación tras 1 segundo
    self:CancelInterruptTimer()
    self._interruptTimer = C_Timer.NewTimer(1.0, function()
        if self._interrupted then
            self._interrupted = nil
            self._interruptTimer = nil
            self.cast:Hide()
        end
    end)
end
-- Unit event dispatch
-- Agrupa los handlers por tipo de refresh en una tabla centralizada.
-- Un loop genera los métodos de NameplateFrame desde los grupos en vez
-- de definir 19 funciones individuales idénticas en estructura.
local PLATE_HANDLER_GROUPS = {
    { "UpdateHealthValue",  "UNIT_HEALTH" },
    { "UpdateHealthBounds", "UNIT_MAXHEALTH" },
    { "UpdateAbsorbValue",  "UNIT_ABSORB_AMOUNT_CHANGED" },
    { "UpdateAuras",        "LOSS_OF_CONTROL_UPDATE", "LOSS_OF_CONTROL_ADDED" },
    { "UpdateName",         "UNIT_NAME_UPDATE" },
    { "UpdateLevel",        "UNIT_LEVEL" },
    { "UpdateHealthColor",  "UNIT_THREAT_LIST_UPDATE", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_FLAGS", "UNIT_FACTION" },
    { "UpdateCast",         "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START",
                            "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE",
                            "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP",
                            "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTIBLE",
                            "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" },
}
for _, group in ipairs(PLATE_HANDLER_GROUPS) do
    local method = group[1]
    for i = 2, #group do
        NameplateFrame[group[i]] = function(self) self[method](self) end
    end
end

-- Name and level changes must re-run the complete dependent layout pass.
NameplateFrame.UNIT_NAME_UPDATE = function(self)
    self:RefreshNamePosition()
end
NameplateFrame.UNIT_LEVEL = function(self)
    self:UpdateLevel()
    self:UpdateClassification()
    local db = KullThranUINameplatesDB
    if db and db.levelDifficultyColorEnabled then self:UpdateHealthColor() end
end
-- Handlers con firma especial: reciben argumentos posicionales del dispatch.
-- UNIT_AURA pasa updateInfo (arg2); UNIT_SPELLCAST_INTERRUPTED pasa
-- interrupterGUID (arg4).
function NameplateFrame:UNIT_AURA(_, updateInfo)
    self:UpdateAuras(updateInfo)
end
function NameplateFrame:UNIT_SPELLCAST_INTERRUPTED(_, _, _, interrupterGUID)
    self:ShowInterrupted(interrupterGUID)
end
local manager = CreateFrame("Frame")
for _, eventName in ipairs({
    "PLAYER_LOGIN", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_LEVEL",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UPDATE_MOUSEOVER_UNIT", "RAID_TARGET_UPDATE",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED",
    "ARENA_OPPONENT_UPDATE", "ARENA_PREP_OPPONENT_SPECIALIZATIONS", "UPDATE_BATTLEFIELD_SCORE",
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_DIFFICULTY_CHANGED",
    "INSTANCE_GROUP_SIZE_CHANGED", "SCENARIO_UPDATE", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED",
}) do
    manager:RegisterEvent(eventName)
end

local transitionState = ns._npTransitionState or {
    pendingUnits = {},
    currentMouseoverPlate = nil,
    mouseoverTicker = nil,
    pendingWatchers = {},
    enemyWatchers = {},
    factionFrame = CreateFrame("Frame"),
    factionFrameActive = false,
}
ns._npTransitionState = transitionState
ns.pendingUnits = transitionState.pendingUnits
-- Silences and forgets the per-unit watcher kept in `watchers`, if there is one.
transitionState.DropWatcher = function(watchers, unit)
    local watcher = watchers[unit]
    if watcher then
        watcher:UnregisterAllEvents()
        watchers[unit] = nil
    end
end

-- Helper: iterate ns.plates safely. The table can become tainted when
-- C_AddOnProfiler (!!AddonProfiler) or similar profiling addons mark the
-- execution context. In BG/Arena the resulting "attempted to iterate a
-- table that cannot be accessed while tainted" error cascades thousands of
-- times. pcall absorbs the taint so the caller can continue.
local function SafeForEachPlate(callback)
    pcall(function()
        for unit, plate in pairs(ns.plates) do
            callback(unit, plate)
        end
    end)
end
ns.SafeForEachPlate = SafeForEachPlate

function ns.RefreshNameplateLevels()
    SafeForEachPlate(function(_, plate)
        if plate and plate.unit and plate.RefreshNamePosition then
            plate:RefreshNamePosition()
        end
    end)
end

local function AcquireEnemyPlate(unit, nameplate)
    local plate = frameCache:Acquire()
    if not plate._mixedIn then
        plate._mixedIn = true
        Mixin(plate, NameplateFrame)
    end
    ns.plates[unit], ns.platesByNameplate[nameplate] = plate, plate
    plate:SetUnit(unit, nameplate)
    return plate
end

local function ReleaseEnemyPlate(unit)
    local plate = ns.plates[unit]
    if not plate then
        return
    end

    if transitionState.currentMouseoverPlate == plate then
        transitionState.currentMouseoverPlate = nil
        if transitionState.mouseoverTicker then
            transitionState.mouseoverTicker:Cancel()
            transitionState.mouseoverTicker = nil
        end
    end
    if ns.currentTargetPlate == plate then
        ns.currentTargetPlate = nil
    end
    if ns.currentFocusPlate == plate then
        ns.currentFocusPlate = nil
    end
    if plate.nameplate then
        ns.platesByNameplate[plate.nameplate] = nil
    end

    plate:ClearUnit()
    frameCache:Release(plate)
    ns.plates[unit] = nil
end

local function RemoveFriendlyPresentation(unit)
    -- Name-only look (overlay name/guild/level + hidden Blizzard UF) is not a
    -- friendlyPlates entry, so it must be dropped explicitly or it stays drawn
    -- underneath the hostile bar plate.
    if ns.RemoveFriendlyNameOnlyPresentation then
        ns.RemoveFriendlyNameOnlyPresentation(unit, GetSafeNamePlateForUnit(unit))
    end
    if ns.RemoveFriendlyPlateNoRestore then
        ns.RemoveFriendlyPlateNoRestore(unit)
        return
    end
    if ns.RemoveFriendlyPlate then
        ns.RemoveFriendlyPlate(unit)
    end
end

-- Vigía de unidad friendly/pendiente: espera a que se vuelva atacable (ej: duelo)
-- Crea un frame vigía que espera a que una unidad friendly-pending se
-- convierta en atacable (ej: duelo aceptado). Al detectar hostilidad limpia
-- el estado pendiente, retira la presentación friendly y promueve a placa
-- enemiga, encadenando un enemy-watcher para el camino de vuelta.
transitionState.CreatePendingWatcher = function(unit, nameplate)
    local f = CreateFrame("Frame")
    f:RegisterUnitEvent("UNIT_FLAGS", unit)
    f:RegisterUnitEvent("UNIT_NAME_UPDATE", unit)
    f:SetScript("OnEvent", function(self, _, u)
        -- Mientras siga sin ser atacable, no hay nada que hacer
        if not ns.IsEnemyNameplateUnit(u, GetSafeNamePlateForUnit(u)) then return end

        -- Limpieza del estado de transición antes de tocar la placa
        self:UnregisterAllEvents()
        transitionState.pendingUnits[u] = nil
        transitionState.pendingWatchers[u] = nil

        -- Promoción: retirar friendly → adquirir enemiga → vigilar retorno
        RemoveFriendlyPresentation(u)
        local np = GetSafeNamePlateForUnit(u)
        if np then
            if ns.plates[u] then ReleaseEnemyPlate(u) end
            AcquireEnemyPlate(u, np)
        end
        transitionState.enemyWatchers[u] = transitionState.CreateEnemyWatcher(u)
    end)
    return f
end

-- Vigía inverso: espera a que una unidad promocionada a enemiga vuelva a
-- ser friendly (fin de duelo, cambio de facción). Al detectarlo libera la
-- placa enemiga, restaura presentación friendly y registra un pending-watcher
-- por si vuelve a cambiar.
transitionState.CreateEnemyWatcher = function(unit)
    local f = CreateFrame("Frame")
    f:RegisterUnitEvent("UNIT_FLAGS", unit)
    f:SetScript("OnEvent", function(self, _, u)
        if ns.IsEnemyNameplateUnit(u, GetSafeNamePlateForUnit(u)) then return end

        self:UnregisterAllEvents()
        transitionState.enemyWatchers[u] = nil
        ReleaseEnemyPlate(u)

        -- Intentar restaurar presentación friendly y preparar el camino inverso
        local np = GetSafeNamePlateForUnit(u)
        if not np then return end
        -- The enemy look hid the Blizzard UnitFrame children; bring them back
        -- before the friendly look (bar or name-only overlay) is re-applied.
        ns.NameplatesBlizzardPlate.RestoreFrame(np)
        transitionState.pendingUnits[u] = np
        transitionState.pendingWatchers[u] = transitionState.CreatePendingWatcher(u, np)
        if ns.TryAddFriendlyPlate then
            ns.TryAddFriendlyPlate(u)
        end
        if ns.TrySuppressNPCHealthBar then ns.TrySuppressNPCHealthBar(u, np) end
        if ns.TrySuppressFriendlyPlayerNameplate then
            ns.TrySuppressFriendlyPlayerNameplate(u, np)
        end
        if ns.UpdateFriendlyPlayerLevel then ns.UpdateFriendlyPlayerLevel(np, u) end
    end)
    return f
end

-- Activa o desactiva el listener de UNIT_FACTION según si estamos en mundo
-- abierto (donde pueden ocurrir duelos) o dentro de instancia. Usa un flag
-- de estado para evitar register/unregister redundantes.
-- Reconcile transitions explicitly when a duel ends. Depending on the client
-- build, the opponent may not emit UNIT_FLAGS/UNIT_FACTION after the duel,
-- leaving a recycled enemy plate visible even though the unit is friendly.
-- This is event-driven and only runs for the small set of transition watchers.
local function ReconcileFactionTransitions()
    local pending = {}
    local enemies = {}

    for unit in pairs(transitionState.pendingWatchers) do
        pending[#pending + 1] = unit
    end
    for unit in pairs(transitionState.enemyWatchers) do
        enemies[#enemies + 1] = unit
    end

    for i = 1, #pending do
        local unit = pending[i]
        local watcher = transitionState.pendingWatchers[unit]
        if watcher and ns.IsEnemyNameplateUnit(unit, GetSafeNamePlateForUnit(unit)) then
            local handler = watcher:GetScript("OnEvent")
            if handler then handler(watcher, "UNIT_FACTION", unit) end
        end
    end
    for i = 1, #enemies do
        local unit = enemies[i]
        local watcher = transitionState.enemyWatchers[unit]
        if watcher and not ns.IsEnemyNameplateUnit(unit, GetSafeNamePlateForUnit(unit)) then
            local handler = watcher:GetScript("OnEvent")
            if handler then handler(watcher, "UNIT_FACTION", unit) end
        end
    end

    -- Fallback for a recycled plate whose watcher was lost. Only inspect the
    -- small custom enemy-plate pool, and restore units that are now friendly.
    local staleEnemies = {}
    ns.SafeForEachPlate(function(unit, _)
        if not transitionState.enemyWatchers[unit]
            and not ns.IsEnemyNameplateUnit(unit, GetSafeNamePlateForUnit(unit)) then
            staleEnemies[#staleEnemies + 1] = unit
        end
    end)
    for i = 1, #staleEnemies do
        local unit = staleEnemies[i]
        ReleaseEnemyPlate(unit)
        local nameplate = GetSafeNamePlateForUnit(unit)
        if nameplate then
            transitionState.pendingUnits[unit] = nameplate
            transitionState.pendingWatchers[unit] = transitionState.CreatePendingWatcher(unit, nameplate)
            if ns.TryAddFriendlyPlate then ns.TryAddFriendlyPlate(unit) end
            ns.NameplatesBlizzardPlate.RestoreFrame(nameplate)
            if ns.TrySuppressNPCHealthBar then ns.TrySuppressNPCHealthBar(unit, nameplate) end
            if ns.TrySuppressFriendlyPlayerNameplate then
                ns.TrySuppressFriendlyPlayerNameplate(unit, nameplate)
            end
            if ns.UpdateFriendlyPlayerLevel then ns.UpdateFriendlyPlayerLevel(nameplate, unit) end
        end
    end

    ns.RefreshThreatContextAndPlateColors()
end
local function UpdateFactionFrameForZone()
    local _, instType = IsInInstance()
    -- En instancias (party/raid/arena/pvp) no se producen cambios de facción
    -- por duelo, así que se desactiva el listener.
    local needsWatch = (not instType) or (instType == "none")
    if transitionState.factionFrameActive == needsWatch then return end

    transitionState.factionFrameActive = needsWatch
    if needsWatch then
        transitionState.factionFrame:RegisterEvent("UNIT_FACTION")
    else
        transitionState.factionFrame:UnregisterEvent("UNIT_FACTION")
    end
end

function ns.RefreshThreatContextAndPlateColors()
    RefreshThreatCache()
    wipe(questMobCache)
    ns.SafeForEachPlate(function(_, plate)
        if plate and plate.UpdateHealthColor then
            plate:UpdateHealthColor()
        end
    end)
end

-- Events that re-evaluate the threat context, and the duel events that flip attackability.
transitionState.contextEvents = {
    PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true, PLAYER_DIFFICULTY_CHANGED = true,
    ROLE_CHANGED_INFORM = true, PLAYER_ROLES_ASSIGNED = true, GROUP_ROSTER_UPDATE = true,
}
transitionState.duelEvents = { DUEL_FINISHED = true, DUEL_INBOUNDS = true, DUEL_OUTOFBOUNDS = true }
;(function(frame)
    for _, group in ipairs({ transitionState.contextEvents, transitionState.duelEvents }) do
        for eventName in pairs(group) do
            frame:RegisterEvent(eventName)
        end
    end
end)(transitionState.factionFrame)
transitionState.factionFrame:SetScript("OnEvent", function(_, event, unit)
    if transitionState.duelEvents[event] then
        ReconcileFactionTransitions()
        -- Faction/attackability can settle one client tick after the duel event.
        C_Timer.After(0.10, ReconcileFactionTransitions)
        return
    end
    if transitionState.contextEvents[event] then
        local function settle()
            ns.RefreshThreatContextAndPlateColors()
            UpdateFactionFrameForZone()
        end
        if event == "PLAYER_ENTERING_WORLD" then
            settle()
            -- El PEW inicial puede dispararse antes de que los datos de dificultad/instancia se asienten.
            C_Timer.After(0.6, settle)
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            settle()
        else
            ns.RefreshThreatContextAndPlateColors()
        end
        return
    end
    -- UNIT_FACTION: the watcher that owns this unit gets the event replayed.
    local owner = transitionState.pendingWatchers[unit] or transitionState.enemyWatchers[unit]
    if owner then
        owner:GetScript("OnEvent")(owner, "UNIT_FACTION", unit)
    end
end)
local function UpdateMouseover()
    local mouseoverNameplate = UnitExists("mouseover") and GetSafeNamePlateForUnit("mouseover")
    local newMouseoverPlate = mouseoverNameplate and ns.platesByNameplate[mouseoverNameplate] or nil

    if transitionState.currentMouseoverPlate and transitionState.currentMouseoverPlate ~= newMouseoverPlate then
        transitionState.currentMouseoverPlate.highlight:Hide()
        transitionState.currentMouseoverPlate = nil
    end

    if newMouseoverPlate and transitionState.currentMouseoverPlate ~= newMouseoverPlate then
        newMouseoverPlate.highlight:Show()
        transitionState.currentMouseoverPlate = newMouseoverPlate
    end

    if UnitExists("mouseover") then
        if not transitionState.mouseoverTicker then
            transitionState.mouseoverTicker = C_Timer.NewTicker(0.1, function()
                if not UnitExists("mouseover") then
                    if transitionState.mouseoverTicker then
                        transitionState.mouseoverTicker:Cancel()
                        transitionState.mouseoverTicker = nil
                    end
                    UpdateMouseover()
                end
            end)
        end
    end
end
-- Re-applies the vertical offset to every visible friendly name-only plate
function ns.RefreshFriendlyNameOnlyOffset()
    if ns.RefreshFriendlyNameOnlyOverlayLayout then
        ns.RefreshFriendlyNameOnlyOverlayLayout()
        return
    end    local db = KullThranUINameplatesDB or defaults
    local nameOnly = (db.friendlyNameOnly ~= false)
    local yOff = nameOnly and (db.friendlyNameOnlyYOffset or 0) or 0
    for unit, nameplate in pairs(transitionState.pendingUnits) do
        if nameplate.UnitFrame then
            local uf = nameplate.UnitFrame
            if yOff ~= 0 then
                uf:SetPoint("TOPLEFT", nameplate, "TOPLEFT", 0, yOff)
                uf:SetPoint("BOTTOMRIGHT", nameplate, "BOTTOMRIGHT", 0, yOff)
                nameplate._enoYOffset = true
            elseif nameplate._enoYOffset then
                uf:SetPoint("TOPLEFT", nameplate, "TOPLEFT", 0, 0)
                uf:SetPoint("BOTTOMRIGHT", nameplate, "BOTTOMRIGHT", 0, 0)
                nameplate._enoYOffset = nil
            end
        end
    end
end

-- Inicializa la base de datos y aplica ajustes al cargar el módulo
function ns.InitializeNameplateModule()
    if not IsNameplatesEnabled() then
        return
    end

    InitDB()
    -- Añadir texturas de SharedMedia a tablas runtime para que las claves se resuelvan en runtime
    local appendMedia = KullThranUI.AppendSharedMediaTextures
    if appendMedia then
        appendMedia(ns.healthBarTextureNames, ns.healthBarTextureOrder, nil, ns.healthBarTextures)
    end
    ns.NameplatesCVars.ApplyAll()
    ns.ApplyClassPowerSetting()
    -- Aplicar preset asignado a spec al login (antes de abrir la UI)
    if ns._ApplySpecPresetFromDB then ns._ApplySpecPresetFromDB() end
end

function ns.ResetNameplatesDB()
    if not KullThranUINameplatesDB then
        KullThranUINameplatesDB = {}
    else
        wipe(KullThranUINameplatesDB)
    end

    InitDB()
    ns.NameplatesCVars.ApplyAll()

    if ns.UpdateFriendlyNameplateSystem then
        ns.UpdateFriendlyNameplateSystem()
    end

    if ns.RefreshAllSettings then
        ns.RefreshAllSettings()
    end
end

if _G.KT_NS then
    _G.KT_NS.ResetNameplatesDB = ns.ResetNameplatesDB
end

-- Despacho principal de eventos del módulo de nameplates. Gestiona el ciclo
-- de vida completo: login → ADDED (adquirir/friendly) → REMOVED (liberar/restaurar)
-- → target/focus/mouseover → raid icons → threat refresh → UI scale.
manager:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        InitDB()
        if not IsNameplatesEnabled() then
            return
        end
        ns.InitializeNameplateModule()
    elseif not IsNameplatesEnabled() then
        return
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local nameplate = GetSafeNamePlateForUnit(unit)
        if not nameplate then return end
        if not ns.IsEnemyNameplateUnit(unit, nameplate) then
            transitionState.pendingUnits[unit] = nameplate
            transitionState.pendingWatchers[unit] = transitionState.CreatePendingWatcher(unit, nameplate)
            if ns.TryAddFriendlyPlate then ns.TryAddFriendlyPlate(unit) end
            -- Colorear nombres de NPC en verde en modo name-only
            if ns.TryColorFriendlyNPCName then ns.TryColorFriendlyNPCName(unit, nameplate) end
            -- Ocultar barras de vida de NPC en modo name-only
            if ns.TrySuppressNPCHealthBar then ns.TrySuppressNPCHealthBar(unit, nameplate) end
            -- Friendly players now use the same stable addon-owned overlay as
            -- friendly NPCs. Do not restore Blizzard's native name FontString:
            -- mixing both layout trees is what causes camera-dependent text
            -- deformation.
            if ns.TrySuppressFriendlyPlayerNameplate then
                ns.TrySuppressFriendlyPlayerNameplate(unit, nameplate)
            end            return
        end
        transitionState.pendingUnits[unit] = nil
        transitionState.DropWatcher(transitionState.pendingWatchers, unit)
        -- A recycled nameplate may still carry a friendly look (duel opponent).
        RemoveFriendlyPresentation(unit)
        if ns.plates[unit] then
            ReleaseEnemyPlate(unit)
        end
        AcquireEnemyPlate(unit, nameplate)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        questMobCache[unit] = nil
        -- Restaurar elementos del UnitFrame de Blizzard para que el nameplate reciclado quede limpio
        local nameplate = GetSafeNamePlateForUnit(unit)
        if nameplate then
            if ns.UpdateFriendlyPlayerLevel then
                ns.UpdateFriendlyPlayerLevel(nameplate, nil)
            end
            ns.NameplatesBlizzardPlate.RestoreFrame(nameplate)
        end
        -- Restaurar color de nombre de NPC si lo teñimos
        if nameplate and ns.RestoreFriendlyNPCNameColor then
            ns.RestoreFriendlyNPCNameColor(nameplate)
        end
        -- Restaurar barra de vida de NPC si la suprimimos
        if nameplate and ns.RestoreNPCHealthBar then
            ns.RestoreNPCHealthBar(nameplate)
        end
        -- Restaurar offset Y de name-only si lo aplicamos
        if nameplate and nameplate._enoYOffset then
            local uf = nameplate.UnitFrame
            if uf then
                uf:SetPoint("TOPLEFT", nameplate, "TOPLEFT", 0, 0)
                uf:SetPoint("BOTTOMRIGHT", nameplate, "BOTTOMRIGHT", 0, 0)
            end
            nameplate._enoYOffset = nil
        end
        transitionState.pendingUnits[unit] = nil
        transitionState.DropWatcher(transitionState.pendingWatchers, unit)
        transitionState.DropWatcher(transitionState.enemyWatchers, unit)
        ReleaseEnemyPlate(unit)
        if ns.RemoveFriendlyPlate then ns.RemoveFriendlyPlate(unit) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        local targetNameplate = UnitExists("target") and GetSafeNamePlateForUnit("target")
        local newTargetPlate = targetNameplate and ns.platesByNameplate[targetNameplate] or nil
        if ns.currentTargetPlate and ns.currentTargetPlate ~= newTargetPlate then
            ns.currentTargetPlate:ApplyTarget()
        end
        if newTargetPlate then
            newTargetPlate:ApplyTarget()
        end
        ns.currentTargetPlate = newTargetPlate
    elseif event == "UNIT_LEVEL" then
        local nameplate = unit and GetSafeNamePlateForUnit(unit)
        if nameplate and ns.UpdateFriendlyPlayerLevel then
            ns.UpdateFriendlyPlayerLevel(nameplate, unit)
        end
        local friendlyPlate = nameplate and ns.friendlyPlatesByNameplate and ns.friendlyPlatesByNameplate[nameplate]
        if friendlyPlate and friendlyPlate.UpdateLevel then
            friendlyPlate:UpdateLevel()
        end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        local focusPct = GetFocusCastHeight()
        local focusNameplate = UnitExists("focus") and GetSafeNamePlateForUnit("focus")
        local newFocusPlate = focusNameplate and ns.platesByNameplate[focusNameplate] or nil
        local function RefreshFocusPlate(plate)
            if not plate then return end
            plate:UpdateHealthColor()
            if focusPct ~= 100 then
                local castH = GetCastBarHeight()
                if plate.unit and UnitIsUnit(plate.unit, "focus") then
                    castH = math.floor(castH * focusPct / 100 + 0.5)
                end
                plate:LayoutCoreBars(plate.unit)
            end
        end
        if ns.currentFocusPlate and ns.currentFocusPlate ~= newFocusPlate then
            RefreshFocusPlate(ns.currentFocusPlate)
        end
        if newFocusPlate then
            RefreshFocusPlate(newFocusPlate)
        end
        ns.currentFocusPlate = newFocusPlate
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        UpdateMouseover()
    elseif event == "RAID_TARGET_UPDATE" then
        SafeForEachPlate(function(_, plate) plate:UpdateRaidIcon() end)
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        SafeForEachPlate(function(_, plate) plate:UpdateHealthColor() end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        SafeForEachPlate(function(u, plate)
            if plate then ReleaseEnemyPlate(u) end
        end)
        ns.NameplatesCVars.ApplyAll()
        if ns.UpdateFriendlyNameplateSystem then
            ns.UpdateFriendlyNameplateSystem()
        end
        C_Timer.After(0.5, function()
            if IsNameplatesEnabled() then
                ns.NameplatesCVars.ApplyAll()
                if ns.UpdateFriendlyNameplateSystem then
                    ns.UpdateFriendlyNameplateSystem()
                end
            end
        end)
        RefreshThreatCache()
    elseif event == 'ZONE_CHANGED_NEW_AREA' or event == 'PLAYER_DIFFICULTY_CHANGED'
        or event == 'INSTANCE_GROUP_SIZE_CHANGED' or event == 'SCENARIO_UPDATE' then
        ns.NameplatesCVars.ApplyAll()
        if ns.UpdateFriendlyNameplateSystem then
            ns.UpdateFriendlyNameplateSystem()
        end
        RefreshThreatCache()
        SafeForEachPlate(function(_, plate) plate:UpdateHealthColor() end)
    elseif event == 'GROUP_ROSTER_UPDATE'
        or event == 'PLAYER_ROLES_ASSIGNED'
        or event == 'ARENA_OPPONENT_UPDATE'
        or event == 'ARENA_PREP_OPPONENT_SPECIALIZATIONS'
        or event == 'UPDATE_BATTLEFIELD_SCORE' then
        RefreshThreatCache()
        SafeForEachPlate(function(_, plate) plate:UpdateHealthColor() end)
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        local reapplyClickArea = ns.ApplyNamePlateClickArea
        if reapplyClickArea then reapplyClickArea() end
    end
end)

-- Attribute the complete manager callback, including acquisition/release and
-- target/focus refresh paths that are not part of a plate's unit-event script.
do
    local managerEventHandler = manager:GetScript("OnEvent")
    local managerEventProfileLabels = {}
    manager:SetScript("OnEvent", function(frame, event, ...)
        local profiler = _G.KT and _G.KT.CombatProfiler
        local label = managerEventProfileLabels[event]
        if not label then
            label = "nameplates.manager." .. tostring(event)
            managerEventProfileLabels[event] = label
        end
        local profileStarted = profiler and profiler:Begin(label)
        managerEventHandler(frame, event, ...)
        if profileStarted then profiler:End(label, profileStarted) end
    end)
end

-- La escala efectiva de una nameplate cambia continuamente con la perspectiva.
-- Reaplicar el layout sólo al detectar un cambio evita tanto la deformacion
-- como un OnUpdate costoso por placa.
do
    local elapsedSinceRefresh = 0
    -- Hoisted: a fresh closure per tick was pure garbage (the tick runs 10x/s).
    local function RelayoutPlate(_, plate)
        if plate and plate.RefreshPixelPerfectLayout then
            plate:RefreshPixelPerfectLayout()
        end
    end
    -- Self-disarming: the manager frame is hidden (it still receives events)
    -- while no KUI plate exists or the module is off, so no per-frame code runs
    -- then; the next NAME_PLATE_UNIT_ADDED shows it again.
    manager:HookScript("OnEvent", function(self, event)
        if event == "NAME_PLATE_UNIT_ADDED" and not self:IsShown() then
            elapsedSinceRefresh = 0
            self:Show()
        end
    end)
    manager:SetScript("OnUpdate", function(self, elapsed)
        elapsedSinceRefresh = elapsedSinceRefresh + (elapsed or 0)
        if elapsedSinceRefresh < 0.1 then
            return
        end
        elapsedSinceRefresh = 0

        if not IsNameplatesEnabled()
            or (not next(ns.plates) and not (ns.friendlyPlates and next(ns.friendlyPlates))) then
            self:Hide()
            return
        end

        SafeForEachPlate(RelayoutPlate)

        if ns.RefreshFriendlyPixelPerfectLayout then
            pcall(ns.RefreshFriendlyPixelPerfectLayout)
        end
    end)
end
-- Spec-preset handling at login: the preset assigned to the current spec is
-- applied on login and on spec changes even if the options window was never
-- opened. Once the options UI registers its own spec auto-switch, that
-- handler owns PLAYER_SPECIALIZATION_CHANGED and this early one only covers
-- the first login.
do
    local function ApplySpecPresetFromDB()
        -- Colour settings are stored as {r,g,b}; copy them so a profile never aliases a preset table.
        local function CloneSetting(value)
            if type(value) == "table" and value.r then
                return { r = value.r, g = value.g, b = value.b }
            end
            return value
        end
        -- Pours the preset values into the live profile. Builtin defaults overwrite
        -- unconditionally; saved presets only touch keys they actually define.
        local function LoadPresetValues(db, keys, source, overwriteMissing)
            if not source then return end
            for _, key in ipairs(keys) do
                local value = source[key]
                if value ~= nil or overwriteMissing then
                    db[key] = CloneSetting(value)
                end
            end
        end
        local function CurrentSpecID()
            local index = GetSpecialization and GetSpecialization() or 0
            if index > 0 and GetSpecializationInfo then
                return (GetSpecializationInfo(index))
            end
        end

        local db = KullThranUINameplatesDB
        local specID = db and CurrentSpecID()
        local assignments = specID and db._specAssignments
        if not assignments then return end

        -- One pass: does any preset claim a spec at all, and which one claims ours?
        local anyAssigned, owner = false, nil
        for presetKey, specList in pairs(assignments) do
            if next(specList) then
                anyAssigned = true
                if specList[specID] and not owner then owner = presetKey end
            end
        end
        if not anyAssigned then return end

        local targetKey = owner or db._specDefaultPreset
        if not targetKey then return end
        if (db._activePreset or "kullthranui") == targetKey then return end  -- already active

        local presetKeys = ns._displayPresetKeys  -- filled in below
        if not presetKeys then return end

        if targetKey == "kullthranui" then
            LoadPresetValues(db, presetKeys, ns.defaults, true)
        elseif targetKey == "custom" then
            LoadPresetValues(db, presetKeys, db._customPreset)
        elseif targetKey:sub(1, 5) == "user:" then
            LoadPresetValues(db, presetKeys, db._presets and db._presets[targetKey:sub(6)])
        end

        db._activePreset = targetKey
        db._builtinSnapshot = nil
    end
    -- Almacenar las claves de preset para que el handler de login pueda usarlas (se setea una vez).
    -- Se divide en chunks pequeños para ser amigable con el parser de WoW.
    do
        local presetKeys = {}
        local function AddPresetKeys(...)
            for i = 1, select("#", ...) do
                presetKeys[#presetKeys + 1] = select(i, ...)
            end
        end

        AddPresetKeys(
            "borderStyle", "borderColor", "targetGlowStyle", "targetGlowColor", "showTargetArrows",
            "targetIndicatorStyle", "targetIndicatorReversed", "targetIndicatorGlow",
            "targetIndicatorGlowColor", "targetArrowScale",
            "showClassPower", "classPowerPos", "classPowerYOffset", "classPowerXOffset", "classPowerScale",
            "classPowerClassColors", "classPowerCustomColor", "classPowerGap"
        )
        AddPresetKeys(
            "textSlotTop", "textSlotRight", "textSlotLeft", "textSlotCenter",
            "nameYOffset",
            "showLevel", "levelFont", "levelFontSize", "levelFontOutline", "levelShadow",
            "levelColor", "levelXOffset", "levelYOffset", "useDynamicNameplateLevelLayout",
            "healthBarHeight", "healthBarWidth", "castBarHeight",
            "castNameSize", "castNameColor", "castTargetSize", "castTargetClassColor", "castTargetColor"
        )
        AddPresetKeys(
            "debuffSlot", "buffSlot", "ccSlot",
            "debuffYOffset", "sideAuraXOffset", "auraSpacing",
            "debuffTimerPosition", "buffTimerPosition", "ccTimerPosition",
            "auraDurationTextSize", "auraDurationTextColor",
            "auraStackTextSize", "auraStackTextColor",
            "buffTextSize", "buffTextColor", "ccTextSize", "ccTextColor",
            "raidMarkerPos", "classificationSlot", "classificationXOffset", "classificationYOffset", "rareEliteIconSize"
        )
        AddPresetKeys(
            "topSlotSize", "topSlotXOffset", "topSlotYOffset",
            "rightSlotSize", "rightSlotXOffset", "rightSlotYOffset",
            "leftSlotSize", "leftSlotXOffset", "leftSlotYOffset",
            "toprightSlotSize", "toprightSlotXOffset", "toprightSlotYOffset", "toprightSlotGrowth",
            "topleftSlotSize", "topleftSlotXOffset", "topleftSlotYOffset", "topleftSlotGrowth"
        )
        AddPresetKeys(
            "textSlotTopSize", "textSlotTopXOffset", "textSlotTopYOffset",
            "textSlotRightSize", "textSlotRightXOffset", "textSlotRightYOffset",
            "textSlotLeftSize", "textSlotLeftXOffset", "textSlotLeftYOffset",
            "textSlotCenterSize", "textSlotCenterXOffset", "textSlotCenterYOffset",
            "textSlotTopColor", "textSlotRightColor", "textSlotLeftColor", "textSlotCenterColor"
        )

        ns._displayPresetKeys = presetKeys
    end

    -- Spec changes that happen before the options UI has ever been opened.
    local specWatcher = CreateFrame("Frame")
    specWatcher:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    specWatcher:SetScript("OnEvent", function(_, _, unit)
        if unit ~= "player" then return end
        RefreshThreatCache()
        -- Once the framework registered its own spec switcher, it owns this event.
        local registry = KullThranUI and KullThranUI._specSwitchRegistry
        if registry and #registry > 0 then return end
        ApplySpecPresetFromDB()
        local refreshAll = ns.RefreshAllSettings
        if refreshAll then refreshAll() end
    end)

    -- Exposed so OnEnable can run it at login.
    ns._ApplySpecPresetFromDB = ApplySpecPresetFromDB
end
