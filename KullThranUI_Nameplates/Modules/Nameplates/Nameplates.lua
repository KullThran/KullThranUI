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
    if C_LFGInfo and C_LFGInfo.IsInLFGFollowerDungeon and C_LFGInfo.IsInLFGFollowerDungeon() then
        return true
    end
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID == 208 then
        return true
    end
    return false
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

ns.GetFont = GetFont
ns.GetNPOutline = GetNPOutline
ns.GetNPUseShadow = GetNPUseShadow
ns.SetFSFont = SetFSFont
ns.plates = {}
ns.platesByNameplate = ns.platesByNameplate or {}
_G.KullThranUINameplates_NS = ns
ns._IsSecretValue = ns._IsSecretValue or function(value)
    if C_UI and C_UI.IsSecret then return C_UI.IsSecret(value) == true end
    if _G.IsSecretValue then return _G.IsSecretValue(value) == true end
    if issecretvalue then return issecretvalue(value) == true end
    return false
end

-- Tabla constante de slots de texto sobre la barra de vida (elevada a file-scope
-- para evitar asignaciones por cada llamada a UpdateHealthValues).
local HP_BAR_SLOTS = {
    { key = "textSlotRight",  anchor = "RIGHT",  point = "RIGHT",  xOff = -2 },
    { key = "textSlotLeft",   anchor = "LEFT",   point = "LEFT",   xOff = 4 },
    { key = "textSlotCenter", anchor = "CENTER", point = "CENTER", xOff = 0 },
}

local defaults = {
    enable = true,
    hostile = { r = 0.39, g = 0.11, b = 0.09 },
    neutral = { r = 0.81, g = 0.72, b = 0.19 },
    friendly = { r = 0.20, g = 0.55, b = 0.90 },
    tapped  = { r = 0.50, g = 0.50, b = 0.50 },
    enemyOutOfCombat = { r = 0.34, g = 0.34, b = 0.34 },
    focus = { r = 0.051, g = 0.820, b = 0.620 },
    focusColorEnabled = true,
    focusOverlayTexture = "striped-v2",
    focusOverlayAlpha = 0.40,
    focusOverlayColor = { r = 1.0, g = 1.0, b = 1.0 },
    caster  = { r = 0.231, g = 0.510, b = 0.965 },
    miniboss = { r = 0.518, g = 0.243, b = 0.984 },
    enemyInCombat = { r = 0.800, g = 0.137, b = 0.137 },
    tankHasAggro = { r = 0.05, g = 0.82, b = 0.62 },
    tankHasAggroEnabled = true,
    classicTankAggro = false,
    tankLosingAggro = { r = 0.81, g = 0.72, b = 0.19 },
    tankOtherTankHasAggro = { r = 0.26, g = 0.58, b = 0.95 },
    tankNoAggro = { r = 1.00, g = 0.22, b = 0.17 },
    dpsNearAggro = { r = 0.81, g = 0.72, b = 0.19 },
    dpsNoAggro = { r = 0.39, g = 0.11, b = 0.09 },
    dpsHasAggro = { r = 1.00, g = 0.50, b = 0.00 },
    threatModHealth = true,
    threatModBorder = false,
    threatModName = false,
    threatUseSoloColor = false,
    threatSoloColor = { r = 0.39, g = 0.11, b = 0.09 },
    interruptReady = { r = 0.92, g = 0.35, b = 0.20 },
    interruptCooldown = { r = 0.45, g = 0.45, b = 0.45 },
    castBar = { r = 0.70, g = 0.40, b = 0.90 },
    castBarUninterruptible = { r = 0.80, g = 0.18, b = 0.16 },
    healthBarHeight = 30,
    friendlyNameOnly = true,
    friendlyNameOnlyYOffset = -20,
    friendlyPlateYOffset = 0,
    friendlyHealthBarHeight = 17,
    friendlyHealthBarWidth = 150,
    showFriendlyNPCs = true,
    showFriendlyPlayers = true,
    friendlyShowDefaultNames = false,
    classColorFriendly = true,
    showEnemyPets = false,
    showShieldPrediction = true,
    animateHealthBar = false,
    font = ns.DEFAULT_FONT_PATH,
    textSlotTop = "enemyName",
    textSlotRight = "healthPercent",
    textSlotLeft = "none",
    textSlotCenter = "none",
    showTargetArrows = true,
    targetIndicatorStyle = "arrow-double",
    targetIndicatorReversed = true,
    targetIndicatorGlow = true,
    targetIndicatorGlowColor = { r = 0.00, g = 0.7686, b = 1.00 }, -- #00C4FF
    targetArrowScale = 1.0,
    showClassPower = false,
    classPowerPos = "bottom",
    classPowerYOffset = 3,
    classPowerXOffset = 0,
    classPowerScale = 1.0,
    classPowerClassColors = true,
    classPowerCustomColor = { r = 1.00, g = 0.84, b = 0.30 },
    classPowerBgColor = { r = 0.082, g = 0.082, b = 0.082, a = 1.0 },
    classPowerEmptyColor = { r = 0.2, g = 0.2, b = 0.2, a = 1.0 },
    classPowerGap = 2,
    healthBarWidth = 45,
    nameplateOverlapV = 1.05,
    stackSpacingScale = 50,
    stackingEnabled = true,
    hitboxScaleX = 100,
    hitboxScaleY = 100,
    nameplateYOffset = 0,
    enemyNameTextSize = 12,
    debuffTimerColor = { r = 1, g = 1, b = 1 },
    auraTextPosition = "topleft",
    debuffTimerPosition = "topleft",
    buffTimerPosition = "topleft",
    ccTimerPosition = "topleft",
    auraDurationTextSize = 15,
    auraDurationTextColor = { r = 1, g = 1, b = 1 },
    auraStackTextSize = 11,
    auraStackTextColor = { r = 1, g = 1, b = 1 },
    debuffSlot = "top",
    topDebuffAlign = "center",
    topDebuffOffsetX = 0,
    buffSlot = "left",
    ccSlot = "right",
    debuffYOffset = 2,
    sideAuraXOffset = 2,
    nameYOffset = 0,
    auraSpacing = 2,
    debuffIconSize = 40,
    buffIconSize = 36,
    buffTextSize = 12,
    buffTextColor = { r = 1, g = 1, b = 1 },
    ccIconSize = 36,
    ccTextSize = 12,
    ccTextColor = { r = 1, g = 1, b = 1 },
    targetGlowStyle = "kullthranui",
    targetGlowColor = { r = 0.00, g = 0.6157, b = 1.00 }, -- #009DFF
    raidMarkerPos = "topright",
    raidMarkerSize = 24,
    classificationSlot = "topleft",
    rareEliteIconSize = 20,
    castBarHeight = 17,
    castNameSize = 10,
    castNameColor = { r = 1, g = 1, b = 1 },
    castTargetSize = 10,
    castTargetClassColor = true,
    castTargetColor = { r = 1, g = 1, b = 1 },
    -- Show every debuff cast by the player on hostile nameplates. Restricting
    -- this to Blizzard's nameplateShowPersonal flag hides many ordinary DoTs.
    showAllDebuffs = true,
    borderStyle = "kullthran",
    borderColor = { r = 0.067, g = 0.067, b = 0.067 },
    pandemicGlow = false,
    pandemicGlowStyle = 1,
    pandemicGlowColor = { r = 1.0, g = 0.800, b = 0.329 },
    pandemicGlowLines = 8,
    pandemicGlowThickness = 1,
    pandemicGlowSpeed = 4,
    debuffExpiryGlow = true,
    debuffExpiryGlowThreshold = 3,
    debuffExpiryGlowUseTypeColor = true,
    debuffExpiryGlowColor = { r = 1.0, g = 0.82, b = 0.20 },
    dispelGlow = false,
    dispelGlowStyle = 2,
    dispelGlowColor = { r = 1.0, g = 1.0, b = 1.0 },
    dispelGlowUseTypeColor = false,
    castScale = 100,
    focusCastHeight = 100,
    questMobColorEnabled = false,
    questMobColor = { r = 0.157, g = 0.855, b = 0.475 },
    colorOverrideEnabled = false,
    showAggroFlash = false,
    showAggroGlow = false,
    unitTypeColoringEnabled = true,
    unitTypeColoringNoOverrideThreat = true,
    unitTypeColoringEnableElite = false,
    unitTypeColoringEnableTrivial = false,
    boss = { r = 0.80, g = 0.18, b = 0.16 },
    elite = { r = 0.90, g = 0.58, b = 0.16 },
    trivial = { r = 0.45, g = 0.45, b = 0.45 },
    priorityTargetsEnabled = false,
    priorityTargetsInput = "",
    priorityTargetsCompiled = nil,
    priorityTargetsColor = { r = 0.90, g = 0.20, b = 0.20 },
    priorityTargetsTexture = "Melli Reforged",
    auraPriorityEnabled = false,
    auraPriorityInput = "",
    auraPriorityCompiled = nil,
    auraPriorityColor = { r = 0.55, g = 0.35, b = 1.00 },
    auraPriorityTexture = "Melli Reforged",
    auraPriorityMatchMode = "all",
    showCastIcon = true,
    castIconScale = 1,
    hashLineEnabled = false,
    hashLinePercent = 30,
    hashLineColor = { r = 1, g = 1, b = 1 },
    kickTickEnabled = true,
    kickTickColor = { r = 1, g = 1, b = 1 },
    -- Core Positions: slot-based size + XY offsets
    topSlotSize = 40,        topSlotXOffset = 0,      topSlotYOffset = 0,
    rightSlotSize = 36,      rightSlotXOffset = 0,    rightSlotYOffset = 0,
    leftSlotSize = 36,       leftSlotXOffset = 0,     leftSlotYOffset = 0,
    toprightSlotSize = 36,   toprightSlotXOffset = 0, toprightSlotYOffset = 0, toprightSlotGrowth = "right",
    topleftSlotSize = 36,    topleftSlotXOffset = 0,  topleftSlotYOffset = 0,  topleftSlotGrowth = "left",
    bottomSlotSize = 40,     bottomSlotXOffset = 0,   bottomSlotYOffset = 0,
    -- Posiciones de texto: tamaño y offsets XY por slot
    textSlotTopSize = 12,    textSlotTopXOffset = 0,  textSlotTopYOffset = 0,
    textSlotRightSize = 10,  textSlotRightXOffset = 0, textSlotRightYOffset = 0,
    textSlotLeftSize = 10,   textSlotLeftXOffset = 0,  textSlotLeftYOffset = 0,
    textSlotCenterSize = 10, textSlotCenterXOffset = 0, textSlotCenterYOffset = 0,
    -- Posiciones de texto: colores por slot
    textSlotTopColor = { r = 1, g = 1, b = 1 },
    textSlotRightColor = { r = 1, g = 1, b = 1 },
    textSlotLeftColor = { r = 1, g = 1, b = 1 },
    textSlotCenterColor = { r = 1, g = 1, b = 1 },
    -- Textura overlay de barra de vida
    healthBarTexture = "Melli Reforged",
    castBarTexture = "Melli Reforged",
    friendlyPlayerHealthTexture = "Melli Reforged",
    friendlyNPCHealthTexture = "Melli Reforged",
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
local LEGACY_ICON_DEFAULTS = {
    debuffIconSize = 26,
    buffIconSize = 24,
    ccIconSize = 24,
    topSlotSize = 26,
    rightSlotSize = 24,
    leftSlotSize = 24,
    toprightSlotSize = 24,
    topleftSlotSize = 24,
    bottomSlotSize = 26,
}
local PREVIOUS_ICON_DEFAULTS = {
    debuffIconSize = 33,
    buffIconSize = 30,
    ccIconSize = 30,
    topSlotSize = 33,
    rightSlotSize = 30,
    leftSlotSize = 30,
    toprightSlotSize = 30,
    topleftSlotSize = 30,
    bottomSlotSize = 33,
}

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

local function ApplyHealthBarTexture(plate)
    local health = plate.health
    if not health then return end
    local texKey = (db and db.healthBarTexture) or defaults.healthBarTexture or "none"
    if plate and plate.unit and not UnitCanAttack("player", plate.unit) then
        if UnitIsPlayer(plate.unit) then
            texKey = (db and db.friendlyPlayerHealthTexture) or defaults.friendlyPlayerHealthTexture or "Melli Reforged"
        else
            texKey = (db and db.friendlyNPCHealthTexture) or defaults.friendlyNPCHealthTexture or "Melli Reforged"
        end
    end
    local path   = ResolveTexturePath(ns.healthBarTextures, texKey, "Interface\\Buttons\\WHITE8x8")
    health:SetStatusBarTexture(path)
end
ns.ApplyHealthBarTexture = ApplyHealthBarTexture

local function ApplyCastBarTexture(plate)
    local cast = plate and plate.cast
    if not cast then return end
    local texKey = (db and db.castBarTexture) or defaults.castBarTexture or "none"
    cast:SetStatusBarTexture(ResolveTexturePath(ns.healthBarTextures, texKey, "Interface\\Buttons\\WHITE8x8"))
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
    return KullThranUINameplatesDB and KullThranUINameplatesDB.healthBarHeight or defaults.healthBarHeight
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
local function GetRaidMarkerPos()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.raidMarkerPos or defaults.raidMarkerPos
end
ns.GetRaidMarkerPos = GetRaidMarkerPos
local function GetRaidMarkerSize()
    local pos = KullThranUINameplatesDB and KullThranUINameplatesDB.raidMarkerPos or defaults.raidMarkerPos
    if pos == "none" then return defaults.raidMarkerSize or 24 end
    return KullThranUINameplatesDB and KullThranUINameplatesDB[pos .. "SlotSize"] or defaults[pos .. "SlotSize"] or 24
end
ns.GetRaidMarkerSize = GetRaidMarkerSize
local function GetRaidMarkerYOffset()
    return 0
end
ns.GetRaidMarkerYOffset = GetRaidMarkerYOffset
local function GetClassificationSlot()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.classificationSlot or defaults.classificationSlot
end
ns.GetClassificationSlot = GetClassificationSlot
local function GetRareEliteIconSize()
    local pos = KullThranUINameplatesDB and KullThranUINameplatesDB.classificationSlot or defaults.classificationSlot
    if pos == "none" then return defaults.rareEliteIconSize or 20 end
    return KullThranUINameplatesDB and KullThranUINameplatesDB[pos .. "SlotSize"] or defaults[pos .. "SlotSize"] or 20
end
ns.GetRareEliteIconSize = GetRareEliteIconSize
local function GetNameYOffset()
    return KullThranUINameplatesDB and KullThranUINameplatesDB.nameYOffset or defaults.nameYOffset
end
ns.GetNameYOffset = GetNameYOffset
local textSlotKeys = { "textSlotTop", "textSlotRight", "textSlotLeft", "textSlotCenter" }
ns.textSlotKeys = textSlotKeys

local function GetTextSlot(slotKey)
    return (db and db[slotKey]) or defaults[slotKey]
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
local healthTextWidths = {
    healthPercent       = 38,
    healthPercentNoSign = 38,
    healthNumber  = 38,
    healthPctNum  = 75,
    healthNumPct  = 75,
}
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
local function GetDebuffIconSize()
    local slot = (db and db.debuffSlot) or defaults.debuffSlot
    if slot == "none" then return defaults.debuffIconSize or 26 end
    return GetSlotSize(slot)
end
ns.GetDebuffIconSize = GetDebuffIconSize
local function GetBuffIconSize()
    local slot = (db and db.buffSlot) or defaults.buffSlot
    if slot == "none" then return defaults.buffIconSize or 24 end
    return GetSlotSize(slot)
end
ns.GetBuffIconSize = GetBuffIconSize
local function GetCCIconSize()
    local slot = (db and db.ccSlot) or defaults.ccSlot
    if slot == "none" then return defaults.ccIconSize or 24 end
    return GetSlotSize(slot)
end
ns.GetCCIconSize = GetCCIconSize
local function GetTargetGlowStyle()
    if db and db.targetGlowStyle then return db.targetGlowStyle end
    return defaults.targetGlowStyle
end
ns.GetTargetGlowStyle = GetTargetGlowStyle
local function GetShowTargetGlow()
    return GetTargetGlowStyle() ~= "none"
end
ns.GetShowTargetGlow = GetShowTargetGlow
local function GetShowClassPower()
    if db and db.showClassPower ~= nil then return db.showClassPower end
    return defaults.showClassPower
end
ns.GetShowClassPower = GetShowClassPower
local function GetClassPowerPos()
    return (db and db.classPowerPos) or defaults.classPowerPos
end
ns.GetClassPowerPos = GetClassPowerPos
local function GetClassPowerYOffset()
    return (db and db.classPowerYOffset) or defaults.classPowerYOffset
end
ns.GetClassPowerYOffset = GetClassPowerYOffset
local function GetClassPowerXOffset()
    return (db and db.classPowerXOffset) or defaults.classPowerXOffset
end
ns.GetClassPowerXOffset = GetClassPowerXOffset
local function GetClassPowerScale()
    return (db and db.classPowerScale) or defaults.classPowerScale
end
ns.GetClassPowerScale = GetClassPowerScale
local function GetClassPowerGap()
    return (db and db.classPowerGap) or defaults.classPowerGap
end
ns.GetClassPowerGap = GetClassPowerGap
local function GetClassPowerClassColors()
    if db and db.classPowerClassColors ~= nil then return db.classPowerClassColors end
    return defaults.classPowerClassColors
end
ns.GetClassPowerClassColors = GetClassPowerClassColors
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

-------------------------------------------------------------------------------
--  Glow Engines provided by shared KullThranUI glow system.
--  Local aliases for the pandemic glow wrapper below.
-------------------------------------------------------------------------------
local _G_Glows = KullThranUI.Glows
local StartProceduralAnts = _G_Glows.StartProceduralAnts
local StopProceduralAnts  = _G_Glows.StopProceduralAnts
local StartButtonGlow     = _G_Glows.StartButtonGlow
local StopButtonGlow      = _G_Glows.StopButtonGlow
local StartAutoCastShine  = _G_Glows.StartAutoCastShine
local StopAutoCastShine   = _G_Glows.StopAutoCastShine
ns.StartProceduralAnts = StartProceduralAnts
ns.StopProceduralAnts  = StopProceduralAnts
ns.StartButtonGlow     = StartButtonGlow
ns.StopButtonGlow      = StopButtonGlow
ns.StartAutoCastShine  = StartAutoCastShine
ns.StopAutoCastShine   = StopAutoCastShine

-- Los glows de nameplates deben quedar por encima de otros elementos de interfaz.
local NAMEPLATE_GLOW_STRATA = "TOOLTIP"
local NAMEPLATE_GLOW_FRAME_LEVEL = 1000
local function RaiseNameplateGlowLayers(glowObject)
    local wrapper = glowObject and glowObject.wrapper
    if not wrapper then return end
    wrapper:SetFrameStrata(NAMEPLATE_GLOW_STRATA)
    wrapper:SetFrameLevel(NAMEPLATE_GLOW_FRAME_LEVEL)
    local overlay = wrapper.overlay
    if overlay then
        overlay:SetFrameStrata(NAMEPLATE_GLOW_STRATA)
        overlay:SetFrameLevel(NAMEPLATE_GLOW_FRAME_LEVEL + 1)
    end
    local autoGlow = wrapper._ktAutoCastGlow
    if autoGlow then
        autoGlow:SetFrameStrata(NAMEPLATE_GLOW_STRATA)
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
    wrapper:SetFrameStrata(NAMEPLATE_GLOW_STRATA)
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
    wrapper:SetFrameStrata(NAMEPLATE_GLOW_STRATA)

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
--  Fase 1  (ResolveOffsets):  slotKey → DB key → posición → XY.
--  Fase 2  (BuildPlacement):  genera tabla de descriptores de ancla
--            {pt, rel, relPt, x, y}[1..count] sin tocar frames.
--  Fase 3  (Commit):          aplica descriptores sobre frames reales.
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

--- Fase 1: resuelve offsets XY desde la DB para un slotKey de aura.
--- Mapea slotKey → DB key → posición guardada → GetSlotOffsets.
function ns._AuraLayout.ResolveOffsets(slotKey)
    local dbKey = ns._AuraLayout.SLOT_DB_MAP[slotKey]
    if not dbKey then return 0, 0 end
    local pos = (db and db[dbKey]) or defaults[dbKey]
    if not pos or pos == "none" then return 0, 0 end
    return GetSlotOffsets(pos)
end

local GetTopTextVerticalLift

--- Fase 2: construye descriptores de anclaje para count iconos.
--- Retorna nil si count < 1 o el slot no es reconocido.
--- Cada entry: {pt, rel, relPt, x, y} — listo para PP.Point directo.
function ns._AuraLayout.BuildPlacement(slot, count, sizeW, gap, plate, dx, dy, slotKey)
    if count < 1 then return nil end
    dx, dy = dx or 0, dy or 0
    local step = sizeW + gap
    local anchors = {}

    if slot == "left" or slot == "right" then
        -- Lateral: iconos en columna pegados al borde de la barra de vida
        local lateral = GetSideAuraXOffset()
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

--- Fase 3: aplica descriptores de ancla sobre los frames.
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
    return (db and db[slotKey .. "Size"]) or defaults[slotKey .. "Size"] or 10
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
    local lateralPx = GetSideAuraXOffset()

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
    for _, s in ipairs(singles) do
        if s.frame and s.frame:IsShown() then
            local side = s.posFunc()
            if side == "left" or side == "right" then
                local sz = s.sizeFunc()
                local xo = (select(1, ns._AuraLayout.ResolveOffsets(s.key)))
                local ext = (side == "left") and (lateralPx + sz - xo) or (lateralPx + sz + xo)
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
    if not (plate.leftArrow and plate.leftArrow:IsShown()) then return end
    local extL, extR = ns._AuraLayout.MeasureLateralExtent(plate)
    local arrowGap = 8
    plate.leftArrow:ClearAllPoints()
    plate.rightArrow:ClearAllPoints()
    PP.Point(plate.leftArrow,  "RIGHT", plate.health, "LEFT",  -(extL + arrowGap), 0)
    PP.Point(plate.rightArrow, "LEFT",  plate.health, "RIGHT",   extR + arrowGap,  0)
end

-- Compatibilidad: alias legado para llamadas externas
ns.PositionArrowsOutsideAuras = function(plate) ns._AuraLayout.CommitArrowAnchors(plate) end

-------------------------------------------------------------------------------
--  Sistema visual por capas para adornos de placa (target, focus, arrows).
--
--  Arquitectura en 3 fases:
--    Fase 1 – Resolución de estado: ns._ResolveTargetVisuals lee DB + unit
--             y devuelve un descriptor plano con lo que cada capa necesita.
--    Fase 2 – Adquisición de recursos: ns._AcquireVisualLayer construye
--             o reutiliza los objetos gráficos de una capa concreta.
--    Fase 3 – Commit: ApplyTarget / UpdateHealthColor aplican el descriptor
--             sobre los recursos ya adquiridos, mostrando u ocultando.
--
--  Separar cálculo y aplicación permite que un refresh parcial (ej: cambio
--  de target) no recalcule capas que no cambian (focus overlay) y viceversa.
-------------------------------------------------------------------------------
local GLOW_TEX = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\background.png"
local GLOW_EXTEND = 6

-- Fase 1: resolución de estado visual de target y adornos laterales.
-- Devuelve un descriptor ligero (no crea objetos) que el commit consume.
-- Se almacena en ns.* porque no podemos añadir locales de archivo (200).
ns._ResolveTargetVisuals = function(plate, unit)
    local desc = {
        isTarget = false,
        glowNeeded = false,
        vibrantBorder = false,
        arrowsNeeded = false,
        arrowScale = 1.0,
        indicatorStyle = defaults.targetIndicatorStyle,
        classPowerNeeded = false,
    }
    if not unit then return desc end
    desc.isTarget = UnitIsUnit(unit, "target")
    if not desc.isTarget then return desc end

    local style = GetTargetGlowStyle()
    desc.glowNeeded = (style ~= "none")
    desc.vibrantBorder = (style == "vibrant")

    desc.arrowsNeeded = ns.GetShowTargetArrows()
    desc.arrowScale = (db and db.targetArrowScale) or 1.0
    desc.indicatorStyle = ns.GetTargetIndicatorStyle()

    desc.classPowerNeeded = (GetShowClassPower() and classPowerType ~= nil)
    return desc
end

-- Fase 2: pool de recursos visuales por capa. Cada capa se construye una
-- sola vez por placa y se reutiliza en sucesivos targets.  La separación
-- de la construcción respecto al commit permite que la geometría sea
-- inmutable y el commit solo toque visibilidad y tintes.
ns._AcquireVisualLayer = function(plate, layerName)
    -- ─ Capa "glow": halo de 8 piezas (4 esquinas + 4 lados) ─
    if layerName == "glow" then
        if plate.glow then return plate.glow end

        local host = CreateFrame("Frame", nil, plate)
        host:SetFrameStrata("BACKGROUND")
        host:SetFrameLevel(1)
        host:SetPoint("TOPLEFT",     plate.health, "TOPLEFT",     -GLOW_EXTEND,  GLOW_EXTEND)
        host:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT",  GLOW_EXTEND, -GLOW_EXTEND)

        local glowColor = (db and db.targetGlowColor) or defaults.targetGlowColor
        local glowR = (glowColor and (glowColor.r or glowColor[1])) or 0.4117
        local glowG = (glowColor and (glowColor.g or glowColor[2])) or 0.6667
        local glowB = (glowColor and (glowColor.b or glowColor[3])) or 1.0
        local m = 0.48
        local c = 12
        local inv = 1 - m
        local glowTextures = {}

        -- Esquinas: descriptores compactos {ancla, texcoords}
        local corners = {
            { "TOPLEFT",     { 0,   m,   0, m   } },
            { "TOPRIGHT",    { inv, 1,   0, m   } },
            { "BOTTOMLEFT",  { 0,   m, inv, 1   } },
            { "BOTTOMRIGHT", { inv, 1, inv, 1   } },
        }
        local cornerTex = {}
        for i, def in ipairs(corners) do
            local tex = host:CreateTexture(nil, "BACKGROUND")
            tex:SetTexture(GLOW_TEX)
            tex:SetVertexColor(glowR, glowG, glowB, 1)
            tex:SetBlendMode("ADD")
            tex:SetSize(c, c)
            tex:SetPoint(def[1])
            tex:SetTexCoord(def[2][1], def[2][2], def[2][3], def[2][4])
            cornerTex[i] = tex
            glowTextures[#glowTextures + 1] = tex
        end

        -- Lados: se estiran entre esquinas adyacentes
        local sides = {
            { "h", {"TOPLEFT",cornerTex[1],"TOPRIGHT"},       {"TOPRIGHT",cornerTex[2],"TOPLEFT"},       {m,inv,0,m}   },
            { "h", {"BOTTOMLEFT",cornerTex[3],"BOTTOMRIGHT"},  {"BOTTOMRIGHT",cornerTex[4],"BOTTOMLEFT"}, {m,inv,inv,1}  },
            { "w", {"TOPLEFT",cornerTex[1],"BOTTOMLEFT"},      {"BOTTOMLEFT",cornerTex[3],"TOPLEFT"},     {0,m,m,inv}    },
            { "w", {"TOPRIGHT",cornerTex[2],"BOTTOMRIGHT"},    {"BOTTOMRIGHT",cornerTex[4],"TOPRIGHT"},   {inv,1,m,inv}  },
        }
        for _, s in ipairs(sides) do
            local tex = host:CreateTexture(nil, "BACKGROUND")
            tex:SetTexture(GLOW_TEX)
            tex:SetVertexColor(glowR, glowG, glowB, 1)
            tex:SetBlendMode("ADD")
            if s[1] == "h" then tex:SetHeight(c) else tex:SetWidth(c) end
            tex:SetPoint(s[2][1], s[2][2], s[2][3])
            tex:SetPoint(s[3][1], s[3][2], s[3][3])
            tex:SetTexCoord(s[4][1], s[4][2], s[4][3], s[4][4])
            glowTextures[#glowTextures + 1] = tex
        end

        host._textures = glowTextures
        plate.glowFrame = host
        plate.glow = host
        host:Hide()
        return host
    end

    -- ─ Capa "arrows": dos texturas laterales de target ─
    if layerName == "arrows" then
        if plate.leftArrow then return plate.leftArrow, plate.rightArrow end

        plate.leftArrow = plate:CreateTexture(nil, "OVERLAY")
        plate.leftArrow:SetTexture("Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\arrow_left.png")
        plate.rightArrow = plate:CreateTexture(nil, "OVERLAY")
        plate.rightArrow:SetTexture("Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\arrow_right.png")
        -- Escala inicial; el commit la recalcula con el valor de DB actual
        local sc = 1.0
        local aw, ah = math.floor(11 * sc + 0.5), math.floor(16 * sc + 0.5)
        PP.Size(plate.leftArrow, aw, ah)
        PP.Point(plate.leftArrow, "RIGHT", plate.health, "LEFT", -8, 0)
        plate.leftArrow:Hide()
        PP.Size(plate.rightArrow, aw, ah)
        PP.Point(plate.rightArrow, "LEFT", plate.health, "RIGHT", 8, 0)
        plate.rightArrow:Hide()
        return plate.leftArrow, plate.rightArrow
    end

    -- ─ Capa "focus": overlay de rayas inclinadas sobre la barra de vida ─
    -- Se compone de dos clip-frames (fill + bg) con opacidades distintas
    -- para distinguir la zona llena del fondo vacío.
    if layerName == "focus" then
        if plate.focusClipFill then return true end

        local overlayAlpha = (KullThranUINameplatesDB and KullThranUINameplatesDB.focusOverlayAlpha) or defaults.focusOverlayAlpha
        local overlayColor = (KullThranUINameplatesDB and KullThranUINameplatesDB.focusOverlayColor) or defaults.focusOverlayColor
        local STRIPE_TEX = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\striped-v2.png"
        local fillTex = plate.health:GetStatusBarTexture()

        -- Clip sobre el fill: ancla directa a la textura de la StatusBar
        plate.focusClipFill = CreateFrame("Frame", nil, plate.health)
        plate.focusClipFill:SetClipsChildren(true)
        plate.focusClipFill:SetPoint("TOPLEFT", fillTex, "TOPLEFT", 0, -1)
        plate.focusClipFill:SetPoint("BOTTOMRIGHT", fillTex, "BOTTOMRIGHT", 0, 1)
        plate.focusClipFill:SetFrameLevel(plate.health:GetFrameLevel() + 1)
        plate.focusOverlayFill = plate.focusClipFill:CreateTexture(nil, "ARTWORK", nil, 2)
        plate.focusOverlayFill:SetPoint("TOPLEFT", plate.health, "TOPLEFT", 0, 0)
        plate.focusOverlayFill:SetSize(200, 24)
        plate.focusOverlayFill:SetTexture(STRIPE_TEX)
        plate.focusOverlayFill:SetAlpha(overlayAlpha)
        plate.focusOverlayFill:SetVertexColor(overlayColor.r, overlayColor.g, overlayColor.b)
        plate.focusClipFill:Hide()

        -- Clip sobre el fondo vacío: más tenue (30% de alpha)
        plate.focusClipBg = CreateFrame("Frame", nil, plate.health)
        plate.focusClipBg:SetClipsChildren(true)
        plate.focusClipBg:SetPoint("TOPLEFT", fillTex, "TOPRIGHT", 0, -1)
        plate.focusClipBg:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", 0, 1)
        plate.focusClipBg:SetFrameLevel(plate.health:GetFrameLevel() + 1)
        plate.focusOverlayBg = plate.focusClipBg:CreateTexture(nil, "ARTWORK", nil, 1)
        plate.focusOverlayBg:SetPoint("TOPLEFT", plate.health, "TOPLEFT", 0, 0)
        plate.focusOverlayBg:SetSize(200, 24)
        plate.focusOverlayBg:SetTexture(STRIPE_TEX)
        plate.focusOverlayBg:SetAlpha(overlayAlpha * 0.3)
        plate.focusOverlayBg:SetVertexColor(overlayColor.r, overlayColor.g, overlayColor.b)
        plate.focusClipBg:Hide()
        return true
    end
end

local plateEventProfileLabels = {}
local frameCache = CreateFramePool("Frame", UIParent, nil, nil, false, function(plate)
    plate:SetFlattensRenderLayers(true)
    plate.health = CreateFrame("StatusBar", nil, plate)
    plate.health:SetFrameLevel(10)  
    plate.health:SetPoint("CENTER", plate, "CENTER", 0, GetNameplateYOffset())
    plate.health:SetSize(GetHealthBarWidth(), GetHealthBarHeight())
    plate.health:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    plate.health:SetClipsChildren(false)
    plate.healthBG = plate.health:CreateTexture(nil, "BACKGROUND")
    plate.healthBG:SetAllPoints()
    plate.healthBG:SetColorTexture(0.12, 0.12, 0.12, 1.0)
    -- Línea hash: marcador vertical fino en un porcentaje de vida configurable
    plate.hashLine = plate.health:CreateTexture(nil, "OVERLAY", nil, 3)
    plate.hashLine:SetColorTexture(1, 1, 1, 0.8)
    plate.hashLine:SetWidth(2)
    plate.hashLine:SetPoint("TOP", plate.health, "TOP", 0, 0)
    plate.hashLine:SetPoint("BOTTOM", plate.health, "BOTTOM", 0, 0)
    plate.hashLine:Hide()
    plate.absorb = CreateFrame("StatusBar", nil, plate.health)
    plate.absorb:SetStatusBarTexture("Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\absorb-default.png")
    plate.absorb:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    plate.absorb:SetStatusBarColor(1, 1, 1, 0.8)
    plate.absorb:SetReverseFill(true)
    plate.absorb:SetPoint("TOPRIGHT", plate.health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    plate.absorb:SetPoint("BOTTOMRIGHT", plate.health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    plate.absorb:SetWidth(GetHealthBarWidth())
    plate.absorb:SetHeight(GetHealthBarHeight())
    plate.absorb:SetFrameLevel(plate.health:GetFrameLevel())
    plate.absorbOverflow = CreateFrame("StatusBar", nil, plate.health)
    plate.absorbOverflow:SetStatusBarTexture("Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\absorb-default.png")
    plate.absorbOverflow:GetStatusBarTexture():SetDrawLayer("ARTWORK", 1)
    plate.absorbOverflow:SetStatusBarColor(1, 1, 1, 0.8)
    plate.absorbOverflow:SetReverseFill(false)
    plate.absorbOverflow:SetPoint("TOPLEFT", plate.health, "TOPRIGHT", 0, 0)
    plate.absorbOverflow:SetPoint("BOTTOMLEFT", plate.health, "BOTTOMRIGHT", 0, 0)
    plate.absorbOverflow:SetWidth(0)
    plate.absorbOverflow:SetFrameLevel(plate.health:GetFrameLevel())
    plate.absorbOverflow:Hide()
    plate.absorbOverflowDivider = plate.health:CreateTexture(nil, "OVERLAY", nil, 7)
    plate.absorbOverflowDivider:SetColorTexture(0, 0, 0, 1)
    plate.absorbOverflowDivider:SetPoint("TOPRIGHT", plate.health, "TOPRIGHT", 0, 0)
    plate.absorbOverflowDivider:SetPoint("BOTTOMRIGHT", plate.health, "BOTTOMRIGHT", 0, 0)
    plate.absorbOverflowDivider:SetWidth(1)
    plate.absorbOverflowDivider:Hide()
    if CreateUnitHealPredictionCalculator then
        plate.hpCalculator = CreateUnitHealPredictionCalculator()
        if plate.hpCalculator.SetMaximumHealthMode then
            plate.hpCalculator:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.WithAbsorbs)
            plate.hpCalculator:SetDamageAbsorbClampMode(Enum.UnitDamageAbsorbClampMode.MaximumHealth)
        end
    end
    local function AddBorder(parent)
        local PP = KullThranUI and KullThranUI.PP
        if PP then
            PP.CreateBorder(parent, 0, 0, 0, 1, 1, "OVERLAY", 5)
        end
    end
-- Nameplate border subsystem
    -- Fase 1 (BuildBorderGeometry): recorre un blueprint de 8 segmentos
    --   (4 esquinas + 4 aristas) para producir las texturas. El blueprint
    --   es estático y compartido por todas las placas.
    -- Fase 2 (SelectBorderVariant / ApplyBorderStyle): decide cuál de
    --   los dos conjuntos (colorless / simple) queda visible.
    -- Fase 3 (TintBorderTextures / ApplyBorderColor): aplica vertex
    --   color a ambos conjuntos en una sola pasada.
    local BORDER_TEX        = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\border-colorless.png"
    local BORDER_TEX_SIMPLE = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\border-simple.png"
    local BORDER_C = 6  -- tamaño de esquina en px

    -- Blueprint de segmentos: corners [1-4] y edges [5-8].
    -- Cada edge referencia corners por índice para sus dos anclas.
    local BORDER_SEGS = {
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

    -- Fase 1: construye un frame con texturas recorriendo el blueprint.
    local function BuildBorderGeometry(parent, tex, color)
        local f = CreateFrame("Frame", nil, parent)
        f:SetFrameLevel(parent:GetFrameLevel() + 5)
        f:SetAllPoints()
        f._texs = {}
        local corners = {}
        for i, seg in ipairs(BORDER_SEGS) do
            local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
            t:SetTexture(tex)
            t:SetVertexColor(color.r, color.g, color.b)
            t:SetTexCoord(seg.tc[1], seg.tc[2], seg.tc[3], seg.tc[4])
            f._texs[i] = t
            if seg.t == "c" then
                t:SetSize(BORDER_C, BORDER_C)
                t:SetPoint(seg.pt, f, seg.pt, 0, 0)
                corners[i] = t
            else
                if seg.dim == "h" then t:SetHeight(BORDER_C) else t:SetWidth(BORDER_C) end
                t:SetPoint(seg.a1pt, corners[seg.a1c], seg.a1r, 0, 0)
                t:SetPoint(seg.a2pt, corners[seg.a2c], seg.a2r, 0, 0)
            end
        end
        return f
    end

    local bc = { r = 0, g = 0, b = 0 }
    bc.r, bc.g, bc.b = GetBorderColor()
    plate.borderFrame        = BuildBorderGeometry(plate.health, BORDER_TEX,        bc)
    plate._simpleBorderFrame = BuildBorderGeometry(plate.health, BORDER_TEX_SIMPLE, bc)

    -- Fase 2: selecciona el variante visible según estilo de DB
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
    -- Fase 3: aplica vertex color a ambos conjuntos de texturas
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
    plate.healthTextFrame = CreateFrame("Frame", nil, plate)
    plate.healthTextFrame:SetAllPoints(plate.health)
    plate.healthTextFrame:SetFrameLevel(plate.health:GetFrameLevel() + 7)
    plate.hpText = plate.healthTextFrame:CreateFontString(nil, "OVERLAY")
    SetFSFont(plate.hpText, 10, GetNPOutline())
    PP.Point(plate.hpText, "RIGHT", plate.health, "RIGHT", -2, 0)
    plate.hpNumber = plate.healthTextFrame:CreateFontString(nil, "OVERLAY")
    SetFSFont(plate.hpNumber, 10, GetNPOutline())
    plate.hpNumber:SetPoint("CENTER", plate.health, "CENTER", 0, 0)
    plate.hpNumber:Hide()
    plate.highlight = plate.healthTextFrame:CreateTexture(nil, "OVERLAY", nil, 6)
    plate.highlight:SetAllPoints()
    plate.highlight:SetColorTexture(1, 1, 1, 0.3)
    plate.highlight:Hide()
    -- Overlay superior de texto: renderiza sobre la barra de vida + bordes para que el texto del slot top nunca quede oculto
    plate.topTextFrame = CreateFrame("Frame", nil, plate)
    plate.topTextFrame:SetAllPoints(plate.health)
    plate.topTextFrame:SetFrameLevel(plate.health:GetFrameLevel() + 6)
    plate.name = plate:CreateFontString(nil, "OVERLAY")
    SetFSFont(plate.name, GetEnemyNameTextSize(), GetNPOutline())
    PP.Point(plate.name, "BOTTOM", plate.health, "TOP", 0, 4)
    PP.Width(plate.name, math.max(GetHealthBarWidth(), 20))
    plate.name:SetWordWrap(false)
    plate.name:SetMaxLines(1)
    plate.raidFrame = CreateFrame("Frame", nil, plate)
    local rmSize = GetRaidMarkerSize()
    PP.Size(plate.raidFrame, rmSize, rmSize)
    plate.raidFrame:SetFrameLevel(plate.health:GetFrameLevel() + 6)
    plate.raidFrame:Hide()
    plate.raid = plate.raidFrame:CreateTexture(nil, "ARTWORK")
    plate.raid:SetAllPoints()
    plate.raid:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    plate.classFrame = CreateFrame("Frame", nil, plate)
    local _reIconSz = GetRareEliteIconSize()
    PP.Size(plate.classFrame, _reIconSz, _reIconSz)
    PP.Point(plate.classFrame, "LEFT", plate.health, "LEFT", 2, 0)
    plate.classFrame:SetFrameLevel(plate.health:GetFrameLevel() + 3)
    plate.classFrame:Hide()
    plate.class = plate.classFrame:CreateTexture(nil, "ARTWORK")
    plate.class:SetAllPoints()
    plate.cast = CreateFrame("StatusBar", nil, plate)
    -- La cast bar ocupa el ancho completo de la barra de vida; el icono cuelga fuera a la izquierda
    plate.cast:SetSize(GetHealthBarWidth(), CAST_H)
    plate.cast:SetPoint("TOPLEFT", plate.health, "BOTTOMLEFT", 0, 0)
    plate.cast:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    plate.cast:SetStatusBarColor(1, 1, 1, 1)
    plate.cast:SetMinMaxValues(0, 1)
    plate.cast:Hide()
    plate.castBG = plate.cast:CreateTexture(nil, "BACKGROUND")
    plate.castBG:SetAllPoints()
    plate.castBG:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    plate.castLeftBorder = plate.cast:CreateTexture(nil, "OVERLAY", nil, 7)
    plate.castLeftBorder:SetColorTexture(0, 0, 0, 1)
    plate.castLeftBorder:SetWidth(1)
    plate.castLeftBorder:SetPoint("TOPLEFT", plate.cast, "TOPLEFT", 0, 0)
    plate.castLeftBorder:SetPoint("BOTTOMLEFT", plate.cast, "BOTTOMLEFT", 0, 0)
    -- El frame de icono cuelga fuera del borde izquierdo de la cast bar.
    -- Parented a cast (se oculta automáticamente con ella) y anclado a cast (mismo
    -- frame = resolución de layout en un solo paso, sin jitter inter-frames).
    plate.castIconFrame = CreateFrame("Frame", nil, plate.cast)
    plate.castIconFrame:SetSize(CAST_H, CAST_H)
    plate.castIconFrame:SetPoint("TOPRIGHT", plate.cast, "TOPLEFT", 0, 0)
    AddBorder(plate.castIconFrame)
    plate.castIcon = plate.castIconFrame:CreateTexture(nil, "ARTWORK")
    plate.castIcon:SetPoint("TOPLEFT", plate.castIconFrame, "TOPLEFT", 1, -1)
    plate.castIcon:SetPoint("BOTTOMRIGHT", plate.castIconFrame, "BOTTOMRIGHT", -1, 1)
    plate.castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    plate.castSpark = plate.cast:CreateTexture(nil, "OVERLAY", nil, 1)
    plate.castSpark:SetTexture("Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\cast_spark.tga")
    plate.castSpark:SetSize(8, CAST_H)
    plate.castSpark:SetPoint("CENTER", plate.cast:GetStatusBarTexture(), "RIGHT", 0, 0)
    plate.castSpark:SetBlendMode("ADD")
    local shieldHeight = CAST_H * 0.75
    local shieldWidth = shieldHeight * (29 / 35)
    plate.castShieldFrame = CreateFrame("Frame", nil, plate.cast)
    plate.castShieldFrame:SetSize(shieldWidth, shieldHeight)
    plate.castShieldFrame:SetPoint("CENTER", plate.cast, "LEFT", 0, 0)
    plate.castShieldFrame:SetFrameLevel(plate.castIconFrame:GetFrameLevel() + 5)
    plate.castShieldFrame:Hide()
    plate.castShield = plate.castShieldFrame:CreateTexture(nil, "OVERLAY")
    plate.castShield:SetAllPoints()
    plate.castShield:SetTexture("Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\shield.png")
    plate.castBarOverlay = plate.cast:CreateTexture(nil, "ARTWORK", nil, 2)
    plate.castBarOverlay:SetAllPoints(plate.cast:GetStatusBarTexture())
    plate.castBarOverlay:SetTexture("Interface\\Buttons\\WHITE8x8")
    plate.castBarOverlay:SetAlpha(0)
    -- Marca de kick tick: clip frame + dos StatusBars invisibles + una textura visible de tick
    -- interruptPositioner sigue el elapsed del cast; interruptMarker sigue el CD restante del kick
    -- La textura del tick se posiciona en el borde derecho del fill del interruptMarker
    plate.kickClip = CreateFrame("Frame", nil, plate.cast)
    plate.kickClip:SetAllPoints(plate.cast)
    plate.kickClip:SetClipsChildren(true)
    plate.kickPositioner = CreateFrame("StatusBar", nil, plate.kickClip)
    plate.kickPositioner:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    plate.kickPositioner:GetStatusBarTexture():SetAlpha(0)
    plate.kickPositioner:SetPoint("CENTER", plate.cast)
    plate.kickPositioner:SetFrameLevel(plate.cast:GetFrameLevel() + 1)
    plate.kickPositioner:Hide()
    plate.kickMarker = CreateFrame("StatusBar", nil, plate.kickClip)
    plate.kickMarker:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    plate.kickMarker:GetStatusBarTexture():SetAlpha(0)
    plate.kickMarker:SetClipsChildren(true)
    plate.kickMarker:SetPoint("LEFT", plate.kickPositioner:GetStatusBarTexture(), "RIGHT")
    plate.kickMarker:SetSize(1, 1) -- sized later in UpdateKickTick
    plate.kickMarker:SetFrameLevel(plate.cast:GetFrameLevel() + 2)
    plate.kickMarker:Hide()
    plate.kickTick = plate.kickMarker:CreateTexture(nil, "OVERLAY", nil, 3)
    plate.kickTick:SetColorTexture(1, 1, 1, 1)
    plate.kickTick:SetWidth(2)
    plate.kickTick:SetPoint("TOP", plate.kickMarker, "TOP", 0, 0)
    plate.kickTick:SetPoint("BOTTOM", plate.kickMarker, "BOTTOM", 0, 0)
    plate.kickTick:SetPoint("LEFT", plate.kickMarker:GetStatusBarTexture(), "RIGHT")
    plate.kickTick:Hide()
    plate.castName = plate.cast:CreateFontString(nil, "OVERLAY")
    SetFSFont(plate.castName, 10, GetNPOutline())
    plate.castName:SetPoint("LEFT", plate.cast, "LEFT", 5, 0)
    plate.castName:SetJustifyH("LEFT")
    plate.castName:SetWordWrap(false)
    plate.castName:SetMaxLines(1)
    plate.castTarget = plate.cast:CreateFontString(nil, "OVERLAY")
    SetFSFont(plate.castTarget, 10, GetNPOutline())
    plate.castTarget:SetPoint("RIGHT", plate.cast, "RIGHT", -3, 0)
    plate.castTarget:SetJustifyH("RIGHT")
    plate.castTarget:SetWordWrap(false)
    plate.castTarget:SetMaxLines(1)
    plate.debuffs = {}
    for i = 1, 4 do
        local d = CreateFrame("Frame", nil, plate)
        d:SetFrameStrata("MEDIUM")
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
        b:SetFrameStrata("MEDIUM")
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
        c:SetFrameStrata("MEDIUM")
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
    if not KullThranUINameplatesDB then
        KullThranUINameplatesDB = {}
    end
    db = KullThranUINameplatesDB
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
    if not KullThranUINameplatesDB._showAllPlayerDebuffsMigrated_v1 then
        -- The previous default only showed auras Blizzard labels as
        -- nameplateShowPersonal. Enable all player-owned debuffs so normal
        -- DoTs are visible on NPC and mob nameplates as well.
        KullThranUINameplatesDB.showAllDebuffs = true
        KullThranUINameplatesDB._showAllPlayerDebuffsMigrated_v1 = true
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

function ns.RefreshStackingBounds()
    local scale = GetStackSpacingScale() / 100
    local barH = GetHealthBarHeight()
    local castH2 = GetCastBarHeight()
    local nameGap = 4 + GetEnemyNameTextSize()
    local totalH = nameGap + barH + castH2
    local w = GetHealthBarWidth()
    for _, plate in pairs(ns.plates) do
        if plate._stackBounds then
            plate._stackBounds:SetSize(w, totalH * scale)
        end
    end
end

local queuedNameplateCVars = {}
local queuedNameplateBits = {}
local cvarApplyFrame = CreateFrame("Frame")
local cvarApplyPending = false

local function ApplyQueuedNameplateCVars()
    if InCombatLockdown() then
        cvarApplyFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    cvarApplyFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")

    if SetCVar then
        for name, value in pairs(queuedNameplateCVars) do
            pcall(SetCVar, name, value)
            queuedNameplateCVars[name] = nil
        end
    end

    if C_CVar and C_CVar.SetCVarBitfield then
        for index, entry in ipairs(queuedNameplateBits) do
            pcall(C_CVar.SetCVarBitfield, entry.field, entry.bit, entry.value)
            queuedNameplateBits[index] = nil
        end
    end
end

cvarApplyFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        ApplyQueuedNameplateCVars()
    end
end)
cvarApplyFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    cvarApplyPending = false
    ApplyQueuedNameplateCVars()
end)

function ns.QueueNameplateCVar(name, value)
    if not name then return end
    queuedNameplateCVars[name] = value
    if not cvarApplyPending then
        cvarApplyPending = true
        cvarApplyFrame:Show()
    end
end

function ns.QueueNameplateCVarBitfield(field, bit, value)
    if field == nil or bit == nil then return end
    for _, entry in ipairs(queuedNameplateBits) do
        if entry.field == field and entry.bit == bit then
            entry.value = value
            return
        end
    end
    queuedNameplateBits[#queuedNameplateBits + 1] = { field = field, bit = bit, value = value }
    if not cvarApplyPending then
        cvarApplyPending = true
        cvarApplyFrame:Show()
    end
end

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
    if C_NamePlateManager and C_NamePlateManager.SetNamePlateHitTestInsets
       and Enum and Enum.NamePlateType then
        C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Enemy, -10000, -10000, -10000, -10000)
        C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Friendly, -10000, -10000, -10000, -10000)
    end
    -- Desplazar contenido de la placa para compensar el crecimiento del frame
    local yShift = GetHitboxYShift()
    for _, plate in pairs(ns.plates) do
        plate:ClearAllPoints()
        plate:SetPoint("CENTER", plate.nameplate, "CENTER", 0, yShift)
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
-- Configura todos los CVars de nameplates y el hitbox de click al iniciar.
-- Organizado en bloques funcionales: aura bitfields, visibilidad friendly,
-- geometría/escalado, y por último hitbox. Los hooksecurefunc del driver
-- se inyectan una sola vez (primera invocación).
local auraCVarHooksInstalled = false
local function SetupAuraCVars()
    -- 1) Bitfields de auras para NPCs y jugadores enemigos
    if C_CVar and C_CVar.SetCVarBitfield then
        local setBit = ns.QueueNameplateCVarBitfield
        if NamePlateConstants and Enum then
            local npcField = NamePlateConstants.ENEMY_NPC_AURA_DISPLAY_CVAR
            local npcBits  = Enum.NamePlateEnemyNpcAuraDisplay
            if npcField and npcBits then
                if npcBits.Debuffs       then setBit(npcField, npcBits.Debuffs, true) end
                if npcBits.CrowdControl  then setBit(npcField, npcBits.CrowdControl, true) end
            end
            local plyField = NamePlateConstants.ENEMY_PLAYER_AURA_DISPLAY_CVAR
            local plyBits  = Enum.NamePlateEnemyPlayerAuraDisplay
            if plyField and plyBits then
                if plyBits.Debuffs       then setBit(plyField, plyBits.Debuffs, true) end
                if plyBits.LossOfControl then setBit(plyField, plyBits.LossOfControl, true) end
            end
        end
    end

    -- 2) CVars: agrupados por propósito (friendly, color, geometría, distancia)
    if ns.QueueNameplateCVar then
        local db = KullThranUINameplatesDB or defaults
        local nameOnly  = (db.friendlyNameOnly ~= false)
        local showPly   = (db.showFriendlyPlayers ~= false)
        local showNpc   = (db.showFriendlyNPCs == true)
        local defNames  = (db.friendlyShowDefaultNames == true)
        local classCol  = (db.classColorFriendly ~= false) and 1 or 0

        -- Visibilidad de nameplates aliados
        local friendlyVars = {
            nameplateShowOnlyNameForFriendlyPlayerUnits = nameOnly and 1 or 0,
            nameplateShowFriendlyPlayers = showPly and 1 or 0,
            UnitNameFriendlyPlayerName   = (showPly or defNames) and 1 or 0,
            nameplateShowFriends         = showPly and 1 or 0,
            nameplateShowFriendlyNPCs    = showNpc and 1 or 0,
            nameplateShowFriendlyNpcs    = showNpc and 1 or 0,
            ShowClassColorInFriendlyNameplate = classCol,
            nameplateUseClassColorForFriendlyPlayerUnitNames = classCol,
        }
        for k, v in pairs(friendlyVars) do ns.QueueNameplateCVar(k, v) end

        -- Mascotas enemigas
        ns.QueueNameplateCVar("nameplateShowEnemyPets", (db.showEnemyPets == true) and 1 or 0)
        ns.QueueNameplateCVar("ShowClassColorInNameplate", 1)

        -- Geometría y escalado (valores fijos del addon)
        local geomVars = {
            nameplateSize                  = 3,
            nameplateShowAll               = db.nameplateShowAll ~= nil and (db.nameplateShowAll and 1 or 0) or tonumber(GetCVar("nameplateShowAll") or 0),
            nameplateMinScale              = 1,
            nameplateMaxScale              = 1,
            nameplateSelectedScale         = 1,
            nameplateOverlapH              = 1,
            nameplateOverlapV              = db.nameplateOverlapV or defaults.nameplateOverlapV,
            nameplateMaxAlpha              = 1,
            nameplateMaxAlphaDistance       = 40,
            nameplateMinAlpha              = 0.6,
            nameplateMinAlphaDistance       = -100000,
            nameplateMaxDistance            = 60,
            nameplateTargetBehindMaxDistance = 30,
            clampTargetNameplateToScreen    = 1,
        }
        for k, v in pairs(geomVars) do ns.QueueNameplateCVar(k, v) end
    end

    -- 3) Stacking motion (bitfield propio de KUI)
    ns.RefreshStackingMotion()

    -- 4) Hitbox de click: se recalcula al cambiar opciones o al resize
    local function RecalcClickArea()
        if InCombatLockdown() then return end
        local cfg = KullThranUINameplatesDB or defaults
        local scaleX = (cfg.hitboxScaleX or 100) / 100
        local scaleY = (cfg.hitboxScaleY or 100) / 100
        if C_NamePlate and C_NamePlate.SetNamePlateSize then
            C_NamePlate.SetNamePlateSize(
                GetHealthBarWidth() * scaleX,
                GetHealthBarHeight() * scaleY)
        end
        -- Insets a -10000 para que el hitbox no recorte el click
        if C_NamePlateManager and C_NamePlateManager.SetNamePlateHitTestInsets
           and Enum and Enum.NamePlateType then
            local huge = -10000
            C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Enemy,    huge, huge, huge, huge)
            C_NamePlateManager.SetNamePlateHitTestInsets(Enum.NamePlateType.Friendly, huge, huge, huge, huge)
        end
    end
    C_Timer.After(0, RecalcClickArea)

    -- 5) Hooks del driver de Blizzard: sólo una vez para evitar duplicados
    if NamePlateDriverFrame and not auraCVarHooksInstalled then
        auraCVarHooksInstalled = true
        NamePlateDriverFrame:UnregisterEvent("DISPLAY_SIZE_CHANGED")
        NamePlateDriverFrame:UnregisterEvent("CVAR_UPDATE")
        hooksecurefunc(NamePlateDriverFrame, "UpdateNamePlateOptions", RecalcClickArea)
        if NamePlateDriverFrame.SetupClassNameplateBars then
            hooksecurefunc(NamePlateDriverFrame, "SetupClassNameplateBars", function(self)
                local bars = {
                    self.classNamePlatePowerBar,
                    self.classNamePlateMechanicFrame,
                    self.classNamePlateAlternatePowerBar,
                }
                for _, bar in ipairs(bars) do
                    if bar then
                        bar:Hide()
                        bar:UnregisterAllEvents()
                    end
                end
            end)
        end
        hooksecurefunc(NamePlateDriverFrame, "OnNamePlateAdded", function(_, addedUnit)
            if addedUnit == "preview" then return end
            local np = C_NamePlate.GetNamePlateForUnit(addedUnit)
            if np and addedUnit and ns.IsEnemyNameplateUnit(addedUnit, np) then
                ns.HideBlizzardFrame(np, addedUnit)
            end
        end)
    end
    ns.ApplyNamePlateClickArea = RecalcClickArea
end
-------------------------------------------------------------------------------
--  Class Power Display (combo points, holy power, chi, etc.)
--  Zero cost when disabled: no events registered, no frames created.
--  When enabled, a single watcher frame handles UNIT_POWER_UPDATE for "player"
--  and shows pips only on the current target's nameplate.
-------------------------------------------------------------------------------
local classPowerWatcher
local classPowerType     -- Enum.PowerType value for the player's class resource, or nil
local classPowerMax = 0  -- max pips for the resource
local classPowerFormReq  -- required GetShapeshiftFormID() value, or nil if no form check needed
local CP_PIP_W, CP_PIP_H = 8, 3  -- pip geometry

-- Per-class filled pip colors (official WoW class colors)
local CP_CLASS_COLORS = {
    ROGUE       = { 1.00, 0.96, 0.41 },
    DRUID       = { 1.00, 0.49, 0.04 },
    PALADIN     = { 0.96, 0.55, 0.73 },
    MONK        = { 0.00, 1.00, 0.60 },
    WARLOCK     = { 0.58, 0.51, 0.79 },
    MAGE        = { 0.25, 0.78, 0.92 },
    EVOKER      = { 0.20, 0.58, 0.50 },
    DEMONHUNTER = { 0.34, 0.06, 0.46 },
    SHAMAN      = { 0.00, 0.44, 0.87 },
    HUNTER      = { 0.67, 0.83, 0.45 },
    WARRIOR     = { 0.78, 0.61, 0.43 },
}
local CP_DEFAULT_COLOR = { 1.00, 0.84, 0.30 }  -- fallback gold

-- Map class { powerType, maxPips (fallback) }
-- Entries can be a simple table { type, max } or a spec-keyed table { [specID] = { type, max } }
local CLASS_POWER_MAP = {
    ROGUE       = { Enum.PowerType.ComboPoints, 5 },
    DRUID       = { Enum.PowerType.ComboPoints, 5 },
    PALADIN     = { Enum.PowerType.HolyPower,   5 },
    MONK        = { [268] = { "BREWMASTER_STAGGER", 1 },
                    [269] = { Enum.PowerType.Chi, 5 } },
    WARLOCK     = { Enum.PowerType.SoulShards,   5 },
    MAGE        = { Enum.PowerType.ArcaneCharges, 4 },
    EVOKER      = { Enum.PowerType.Essence,      5 },
    DEMONHUNTER = { [581] = { "SOUL_FRAGMENTS_VENGEANCE", 6 } },  -- Solo Venganza (valor secreto)
    SHAMAN      = { [263] = { "MAELSTROM_WEAPON", 10 } },  -- Solo Mejora
    PRIEST      = { [258] = { "INSANITY_BAR", 100 } },     -- Solo Sombra
    HUNTER      = { [253] = { "FOCUS_BAR", 100 },
                    [254] = { "FOCUS_BAR", 100 },
                    [255] = { "TIP_OF_THE_SPEAR", 3 } },   -- Solo Supervivencia
    WARRIOR     = { [72]  = { "WHIRLWIND_STACKS", 4 } },    -- Solo Furia
}

-- Lazy-create pip textures on a plate (done once, then reused via show/hide)
local function CreateClassPowerPip(plate)
    local background = plate:CreateTexture(nil, "OVERLAY", nil, 2)
    background:SetColorTexture(0.082, 0.082, 0.082, 1)
    background:Hide()

    local fill = plate:CreateTexture(nil, "OVERLAY", nil, 3)
    fill:SetColorTexture(1, 1, 1, 1)
    PP.Size(fill, CP_PIP_W, CP_PIP_H)
    fill:Hide()
    fill._bg = background

    return fill
end

-- Pre-aloca los 10 pips de recurso de clase en la placa. Se crean todos de
-- golpe porque Lua 5.1 no tiene tinsert eficiente y reasignar la tabla
-- durante combate causaría micro-stutters.
local function EnsureClassPowerPips(plate)
    if plate._cpPips then return end
    local pips = {}
    local idx = 1
    while idx <= 10 do
        pips[idx] = CreateClassPowerPip(plate)
        idx = idx + 1
    end
    plate._cpPips = pips
end

-- Lazy-create a single StatusBar for bar-type class resources (e.g. stagger)
local function EnsureClassPowerBar(plate)
    if plate._cpBar then
        return
    end

    local bar = CreateFrame("StatusBar", nil, plate)
    bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    bar:SetFrameLevel(plate:GetFrameLevel() + 5)
    bar:Hide()

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.082, 0.082, 0.082, 1)
    bar._bg = bg
    plate._cpBar = bar
end

-- Tabla de recursos de tipo barra: encapsula la lectura de cada recurso
-- y la estrategia de color específica. Stagger usa umbrales cromáticos
-- (rojo/amarillo/verde); Insanity y Focus usan color de clase.
-- Almacenado en ns para no consumir locals de archivo (límite 200).
ns._BarResourceDefs = {
    BREWMASTER_STAGGER = {
        read = function()
            local cur = UnitStagger("player") or 0
            local mx  = UnitHealthMax("player")
            local sec = issecretvalue and (issecretvalue(cur) or issecretvalue(mx))
            if not sec and (not mx or mx <= 0) then mx = 1 end
            return cur, mx, sec
        end,
        -- Umbrales de Stagger: verde < 30%, amarillo 30-60%, rojo > 60%
        colorFn = function(cur, mx, isSecret, classClr)
            if isSecret then return classClr[1], classClr[2], classClr[3] end
            local pct = cur / mx
            if pct >= 0.6 then return 1.0, 0.2, 0.2 end
            if pct >= 0.3 then return 1.0, 0.85, 0.2 end
            return 0.2, 0.8, 0.2
        end,
    },
    INSANITY_BAR = {
        read = function()
            local cur = UnitPower("player", 13) or 0
            local mx  = UnitPowerMax("player", 13) or 100
            if issecretvalue and issecretvalue(mx) then mx = 100 end
            if not mx or mx <= 0 then mx = 100 end
            return cur, mx, false
        end,
    },
    FOCUS_BAR = {
        read = function()
            local cur = UnitPower("player", 2) or 0
            local mx  = UnitPowerMax("player", 2) or 100
            if issecretvalue and issecretvalue(mx) then mx = 100 end
            if not mx or mx <= 0 then mx = 100 end
            return cur, mx, false
        end,
    },
}

-- Resuelve cur/max/isSecret para recursos de tipo pip basándose en el
-- classPowerType activo. Los recursos tipo string usan funciones
-- manuales; los numéricos van directos a UnitPower/UnitPowerMax.
ns._PipResourceResolvers = {
    SOUL_FRAGMENTS_VENGEANCE = function()
        local cur = C_Spell and C_Spell.GetSpellCastCount and C_Spell.GetSpellCastCount(228477) or 0
        return cur, 6, true
    end,
    MAELSTROM_WEAPON = function()
        local c, m = KullThranUI.GetMaelstromWeapon()
        return c, m, false
    end,
    TIP_OF_THE_SPEAR = function()
        local c, m = KullThranUI.GetTipOfTheSpear()
        return c, m, false
    end,
    WHIRLWIND_STACKS = function()
        local c, m = KullThranUI.GetWhirlwindStacks()
        return c, m, false
    end,
}

-- Actualiza la visualización de recurso de clase en una placa de nameplate.
-- Separa la ruta de renderizado en dos fases: recursos de tipo barra
-- (StatusBar uniforme) y recursos de tipo pip (texturas individuales).
-- Los 3 recursos de barra se manejan con ns._BarResourceDefs para
-- eliminar la duplicación de bloques casi-idénticos.
local function UpdateClassPowerOnPlate(plate)
    if not plate or not plate._cpPips then return end

    -- Sin tipo de recurso activo: ocultar todo y salir
    if not classPowerType then
        for i = 1, #plate._cpPips do
            plate._cpPips[i]:Hide()
            if plate._cpPips[i]._bg then plate._cpPips[i]._bg:Hide() end
        end
        if plate._cpBar then plate._cpBar:Hide() end
        return
    end

    local cpScale = GetClassPowerScale()
    local cpYOff  = GetClassPowerYOffset()
    local cpXOff  = GetClassPowerXOffset()
    local cpPos   = GetClassPowerPos()
    local bgCol   = GetClassPowerBgColor()

    -- Resolver anclaje: encima o debajo de la barra de salud,
    -- evitando solapamiento con la barra de casteo si está activa
    local anchorPoint, anchorRelPoint, anchorFrame, yDir
    if cpPos == "top" then
        anchorPoint, anchorRelPoint, anchorFrame, yDir = "BOTTOM", "TOP", plate.health, 1
    elseif plate.isCasting and plate.cast:IsShown() then
        anchorPoint, anchorRelPoint, anchorFrame, yDir = "TOP", "BOTTOM", plate.cast, -1
    else
        anchorPoint, anchorRelPoint, anchorFrame, yDir = "TOP", "BOTTOM", plate.health, -1
    end

    -- === Fase 1: Recursos de tipo barra (Stagger, Insanity, Focus) ===
    local barDef = ns._BarResourceDefs[classPowerType]
    if barDef then
        -- Ocultar todos los pips: la barra los reemplaza
        for i = 1, #plate._cpPips do
            plate._cpPips[i]:Hide()
            if plate._cpPips[i]._bg then plate._cpPips[i]._bg:Hide() end
            if plate._cpPips[i]._secretBar then plate._cpPips[i]._secretBar:Hide() end
        end
        EnsureClassPowerBar(plate)
        local bar = plate._cpBar
        local cur, mx, isSecret = barDef.read()

        -- Layout uniforme: 6 pips de ancho, escalado por cpScale
        local scaledW = CP_PIP_W * cpScale * 6
        local scaledH = CP_PIP_H * cpScale
        bar:ClearAllPoints()
        bar:SetSize(scaledW, scaledH)
        bar:SetPoint(anchorPoint, anchorFrame, anchorRelPoint, cpXOff, yDir * cpYOff)
        bar:SetMinMaxValues(0, mx)
        bar:SetValue(cur)

        -- Color: el bar-def puede tener su propia función de color (Stagger)
        -- o usar el color de clase estándar (Insanity, Focus)
        local _, pClass = UnitClass("player")
        local classClr = CP_CLASS_COLORS[pClass] or CP_DEFAULT_COLOR
        if not GetClassPowerClassColors() then
            local cc = GetClassPowerCustomColor()
            classClr = { cc.r, cc.g, cc.b }
        end

        if barDef.colorFn then
            bar:SetStatusBarColor(barDef.colorFn(cur, mx, isSecret, classClr))
        else
            bar:SetStatusBarColor(classClr[1], classClr[2], classClr[3], 1)
        end

        bar._bg:SetColorTexture(bgCol.r, bgCol.g, bgCol.b, bgCol.a)
        bar:Show()
        return
    end

    -- === Fase 2: Recursos de tipo pip ===
    -- Ocultar barra si venimos de un recurso tipo barra
    if plate._cpBar then plate._cpBar:Hide() end

    -- Resolver valor actual y máximo del recurso pip
    local cur, maxP, isSecret
    local resolver = ns._PipResourceResolvers[classPowerType]
    if resolver then
        cur, maxP, isSecret = resolver()
        -- Whirlwind: maxP puede ser 0 entre combates
        if not maxP or maxP <= 0 then
            for i = 1, #plate._cpPips do
                plate._cpPips[i]:Hide()
                if plate._cpPips[i]._bg then plate._cpPips[i]._bg:Hide() end
            end
            return
        end
    else
        -- Recurso numérico genérico (combo points, chi, soul shards, etc.)
        cur = UnitPower("player", classPowerType) or 0
        maxP = UnitPowerMax("player", classPowerType) or classPowerMax
        if maxP <= 0 then maxP = classPowerMax end
        isSecret = false
    end
    if maxP <= 0 then
        for i = 1, #plate._cpPips do
            plate._cpPips[i]:Hide()
            if plate._cpPips[i]._bg then plate._cpPips[i]._bg:Hide() end
        end
        return
    end

    -- Layout de pips: calcular posiciones una vez y aplicar en un solo bucle
    local scaledW   = PP.Scale(CP_PIP_W * cpScale)
    local scaledH   = PP.Scale(CP_PIP_H * cpScale)
    local scaledGap = PP.Scale(GetClassPowerGap() * cpScale)

    -- Precalcular borde izquierdo de cada pip en coordenadas de grupo
    local pipPositions = {}
    for idx = 1, maxP do
        pipPositions[idx] = PP.Scale((idx - 1) * (scaledW + scaledGap))
    end
    local halfGroup = PP.Scale((pipPositions[maxP] + scaledW) / 2)

    -- Resolver color de clase o personalizado
    local _, pClass = UnitClass("player")
    local cpColor
    if GetClassPowerClassColors() then
        cpColor = CP_CLASS_COLORS[pClass] or CP_DEFAULT_COLOR
    else
        local cc = GetClassPowerCustomColor()
        cpColor = { cc.r, cc.g, cc.b }
    end
    local emptyCol = GetClassPowerEmptyColor()
    local leftAnchor = (anchorPoint == "BOTTOM") and "BOTTOMLEFT" or "TOPLEFT"

    -- Recorrer pips: posicionar los activos, ocultar los sobrantes
    for i = 1, #plate._cpPips do
        local pip = plate._cpPips[i]
        if i > maxP then
            pip:Hide()
            if pip._bg then pip._bg:Hide() end
            if pip._secretBar then pip._secretBar:Hide() end
        else
            pip:ClearAllPoints()
            PP.Size(pip, scaledW, scaledH)
            pip:SetPoint(leftAnchor, anchorFrame, anchorRelPoint,
                PP.Scale(pipPositions[i] - halfGroup + cpXOff),
                PP.Scale(yDir * cpYOff))

            -- Fondo detrás de cada pip
            local bg = pip._bg
            if bg then
                bg:ClearAllPoints()
                bg:SetAllPoints(pip)
                bg:SetColorTexture(bgCol.r, bgCol.g, bgCol.b, bgCol.a)
                bg:Show()
            end

            -- Valores secretos (Soul Fragments): usar StatusBar intermedia
            -- para que Blizzard resuelva la comparación internamente
            if isSecret then
                if not pip._secretBar then
                    local sb = CreateFrame("StatusBar", nil, plate)
                    sb:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
                    sb:SetFrameLevel(plate:GetFrameLevel() + 5)
                    pip._secretBar = sb
                end
                local sb = pip._secretBar
                sb:ClearAllPoints()
                sb:SetAllPoints(pip)
                sb:SetMinMaxValues(i - 1, i)
                sb:SetValue(cur)
                sb:SetStatusBarColor(cpColor[1], cpColor[2], cpColor[3], 1)
                sb:Show()
                pip:SetColorTexture(emptyCol.r, emptyCol.g, emptyCol.b, emptyCol.a)
            else
                if pip._secretBar then pip._secretBar:Hide() end
                if i <= cur then
                    pip:SetColorTexture(cpColor[1], cpColor[2], cpColor[3], 1)
                else
                    pip:SetColorTexture(emptyCol.r, emptyCol.g, emptyCol.b, emptyCol.a)
                end
            end
            pip:Show()
        end
    end
end

-- Oculta todos los pips y la barra de recurso de clase en una placa.
-- Recorre una sola vez ocultando pip, fondo y secretBar en cada iteración.
local function HideClassPowerOnPlate(plate)
    if not plate or not plate._cpPips then return end

    for _, pip in ipairs(plate._cpPips) do
        pip:Hide()
        if pip._bg then pip._bg:Hide() end
        if pip._secretBar then pip._secretBar:Hide()
        end
    end
    if plate._cpBar then
        plate._cpBar:Hide()
    end
end

-- Retorna el offset Y extra que los elementos sobre la barra de vida necesitan
-- para librar los pips de class power (cuando están arriba y visibles).
GetClassPowerTopPush = function(plate)
    if not GetShowClassPower() or not classPowerType then return 0 end
    if GetClassPowerPos() ~= "top" then return 0 end
    if not plate or not plate.unit or not UnitIsUnit(plate.unit, "target") then return 0 end
    local cpScale = GetClassPowerScale()
    local cpYOff = GetClassPowerYOffset()
    return CP_PIP_H * cpScale + cpYOff
end

local function ShouldDisplayClassPower()
    return not classPowerFormReq or GetShapeshiftFormID() == classPowerFormReq
end

local function RefreshClassPowerPlates(repositionTopElements)
    local showClassPower = ShouldDisplayClassPower()

    for _, plate in pairs(ns.plates) do
        if showClassPower and plate.unit and UnitIsUnit(plate.unit, "target") then
            EnsureClassPowerPips(plate)
            UpdateClassPowerOnPlate(plate)
        else
            HideClassPowerOnPlate(plate)
        end

        if repositionTopElements and plate.unit then
            plate:RefreshNamePosition()
            plate:UpdateRaidIcon()
        end
    end
end

local function RefreshClassPower()
    RefreshClassPowerPlates(false)
end

local function RefreshClassPowerFull()
    RefreshClassPowerPlates(true)
end

-- Forward declarations for mutual recursion on spec change
local DisableClassPowerWatcher
local ApplyClassPowerSetting

-- Enable/disable the class power watcher
-- Activa el watcher de recurso de clase para el jugador actual.
-- Resuelve la spec y busca en CLASS_POWER_MAP el tipo de recurso a rastrear.
-- Hay dos caminos internos:
--   · String-type (custom-tracked, e.g. stagger/maelstrom): OnUpdate poll + eventos
--   · Numeric-type (WoW powerType nativo, e.g. combo points): sólo eventos de poder
-- Para string-type, se usa una tabla de despacho de eventos en vez de una
-- cadena if/elseif; la mayoría de eventos delegan a una misma función
-- RouteManualTrackers que centraliza las llamadas a HandleTipOfTheSpear y
-- HandleWhirlwindStacks.
local function EnableClassPowerWatcher()
    if classPowerWatcher then return end  -- ya activo
    local _, playerClass = UnitClass("player")
    local info = CLASS_POWER_MAP[playerClass]
    if not info then return end  -- clase sin recurso rastreable

    -- Resolver entradas específicas de spec: si info tiene claves numéricas de specID
    if info[1] == nil then
        local spec = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization and C_SpecializationInfo.GetSpecialization())
            or (GetSpecialization and GetSpecialization())
        local specID
        if spec then
            if C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo then
                specID = C_SpecializationInfo.GetSpecializationInfo(spec)
            elseif GetSpecializationInfo then
                specID = GetSpecializationInfo(spec)
            end
        end
        info = specID and info[specID]
        if not info then return end  -- spec actual sin recurso rastreable
    end

    classPowerType = info[1]
    classPowerMax = info[2]
    classPowerFormReq = (playerClass == "DRUID") and 1 or nil  -- Druida: solo forma felina
    classPowerWatcher = CreateFrame("Frame")

    -- Camino string-type: recursos custom-tracked con OnUpdate poll + dispatch de eventos
    if type(classPowerType) == "string" then
        local elapsed = 0
        classPowerWatcher:SetScript("OnUpdate", function(_, dt)
            elapsed = elapsed + dt
            if elapsed < 0.1 then return end
            elapsed = 0
            RefreshClassPower()
        end)
        classPowerWatcher:RegisterUnitEvent("UNIT_AURA", "player")
        classPowerWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
        classPowerWatcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        classPowerWatcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        classPowerWatcher:RegisterEvent("PLAYER_DEAD")
        classPowerWatcher:RegisterEvent("PLAYER_ALIVE")
        classPowerWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
        -- Stagger depende de la salud del jugador
        if classPowerType == "BREWMASTER_STAGGER" then
            classPowerWatcher:RegisterUnitEvent("UNIT_HEALTH", "player")
            classPowerWatcher:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
        end

        -- Helper: reenvía eventos a trackers manuales (TotS, Whirlwind) cuando
        -- KullThranUI_ResourceBars NO está cargado (_ERB_AceDB ausente).
        local function RouteManualTrackers(event, ...)
            if _G._ERB_AceDB then return end
            if not KullThranUI then return end
            if KullThranUI.HandleTipOfTheSpear then
                KullThranUI.HandleTipOfTheSpear(event, ...)
            end
            if KullThranUI.HandleWhirlwindStacks then
                KullThranUI.HandleWhirlwindStacks(event, ...)
            end
        end

        -- Tabla de despacho: cada evento de string-type se resuelve aquí.
        -- PLAYER_SPECIALIZATION_CHANGED destruye y reconstruye el watcher
        -- porque la spec nueva puede no tener este recurso.
        local STRING_EVENT_DISPATCH = {
            PLAYER_SPECIALIZATION_CHANGED = function()
                DisableClassPowerWatcher()
                ApplyClassPowerSetting()
            end,
            PLAYER_TARGET_CHANGED = function()
                RefreshClassPowerFull()
            end,
            UNIT_SPELLCAST_SUCCEEDED = function(event, ...)
                if _G._ERB_AceDB then
                    RefreshClassPower()
                    return
                end
                local unit, castGUID, spellID = ...
                if unit == "player" then
                    RouteManualTrackers(event, unit, castGUID, spellID)
                end
                RefreshClassPower()
            end,
            PLAYER_DEAD = function(event)
                RouteManualTrackers(event)
                RefreshClassPower()
            end,
            PLAYER_ALIVE = function(event)
                RouteManualTrackers(event)
                RefreshClassPower()
            end,
            PLAYER_REGEN_ENABLED = function(event)
                if not _G._ERB_AceDB and KullThranUI and KullThranUI.HandleWhirlwindStacks then
                    KullThranUI.HandleWhirlwindStacks(event)
                end
                RefreshClassPower()
            end,
        }

        classPowerWatcher:SetScript("OnEvent", function(_, event, ...)
            local handler = STRING_EVENT_DISPATCH[event]
            if handler then
                handler(event, ...)
            else
                -- Eventos no listados (UNIT_AURA, UNIT_HEALTH, etc.) sólo refrescan
                RefreshClassPower()
            end
        end)
    else
        -- Camino numeric-type: recurso nativo de WoW (combo points, chi, etc.)
        classPowerWatcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
        classPowerWatcher:RegisterUnitEvent("UNIT_MAXPOWER", "player")
        classPowerWatcher:RegisterEvent("PLAYER_TARGET_CHANGED")
        classPowerWatcher:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        if classPowerFormReq then
            classPowerWatcher:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        end
        classPowerWatcher:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then
                RefreshClassPowerFull()
            else
                RefreshClassPower()
            end
        end)
    end
    RefreshClassPowerFull()
end

-- Desmonta el watcher de recurso de clase y limpia el estado visual
-- en todas las placas activas. Resetea primero los scripts para cortar
-- cualquier callback pendiente antes de tocar las placas.
DisableClassPowerWatcher = function()
    if not classPowerWatcher then return end

    -- Cortar todo callback antes de recorrer placas (evita reentrancia)
    classPowerWatcher:SetScript("OnUpdate", nil)
    classPowerWatcher:SetScript("OnEvent", nil)
    classPowerWatcher:UnregisterAllEvents()
    classPowerWatcher:Hide()

    classPowerWatcher = nil
    classPowerFormReq = nil

    -- Recorrer cada placa para ocultar pips y re-anclar elementos desplazados
    for unit, plate in pairs(ns.plates) do
        HideClassPowerOnPlate(plate)
        if plate.unit then
            plate:UpdateRaidIcon()
            plate:RefreshNamePosition()
        end
    end
end

-- Se llama al inicio y cuando cambia el ajuste de class power
ApplyClassPowerSetting = function()
    if GetShowClassPower() then
        EnableClassPowerWatcher()
    else
        DisableClassPowerWatcher()
    end
end
ns.ApplyClassPowerSetting = ApplyClassPowerSetting
ns.RefreshClassPower = RefreshClassPowerFull
-- Oscurece un color RGB por un factor (0-1). Valores fuera de rango se
-- saturan sin usar una closure auxiliar; math.min/max son más directos.
local function DarkenColor(r, g, b, factor)
    local s = tonumber(factor)
    if not s or s <= 0 or s > 1 then s = 0.60 end
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
    local isRaid = IsInRaid()
    local count = isRaid and GetNumGroupMembers() or GetNumSubgroupMembers()
    local prefix = isRaid and "raid" or "party"
    for i = 1, count do
        local groupUnit = prefix .. i
        if UnitExists(groupUnit) and not UnitIsUnit(groupUnit, "player") then
            if UnitGroupRolesAssigned(groupUnit) == "TANK" then
                local otherIsTanking = GetThreatInfoForUnit(groupUnit, targetUnit)
                if otherIsTanking then
                    return true
                end
            end
        end
    end
    return false
end
-------------------------------------------------------------------------------
--  Quest Mob Detection
--  Uses C_TooltipInfo to scan unit tooltips for quest objective lines.
--  Cached per unit; invalidated on QUEST_LOG_UPDATE and NAME_PLATE_UNIT_REMOVED.
-------------------------------------------------------------------------------
local questMobCache = {}
local QUEST_LINE_TYPES
if Enum and Enum.TooltipDataLineType then
    QUEST_LINE_TYPES = {
        [Enum.TooltipDataLineType.QuestObjective] = true,
        [Enum.TooltipDataLineType.QuestTitle] = true,
        [Enum.TooltipDataLineType.QuestPlayer] = true,
    }
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
            -- En grupo, sólo colorear para TUS quests: si el nombre
            -- no coincide, ignorar hasta el siguiente QuestTitle.
            -- leftText puede ser un "secret value" (taint) en combate
            if isInGroup then
                local ok, result = pcall(function() return line.leftText ~= playerName end)
                ignoreUntilTitle = ok and result or false
            end
        elseif lt == Enum.TooltipDataLineType.QuestTitle then
            ignoreUntilTitle = false
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
questCacheWatcher:SetScript("OnEvent", function()
    wipe(questMobCache)
    for _, plate in pairs(ns.plates) do
        plate:UpdateHealthColor()
    end
end)

-- Resuelve el color de barra de vida según una cadena de prioridad de 8 niveles.
-- La prioridad es estricta: el primer nivel que coincide retorna inmediatamente.
--   P1: Tapped (gris)             → siempre visible, no depende de combate
--   P2: Quest mob (configurado)   → requiere opt-in en DB
--   P3: Jugador enemigo (clase)   → PvP/mundo, RAID_CLASS_COLORS
--   P4: Amenaza (tank/dps/grupo)  → sólo en instancia o grupo
--   P5: Focus (configurado)       → requiere opt-in en DB
--   P6: Neutral (reacción 4)      → incluye atacables no hostiles
--   P7: Miniboss (elite/boss)     → oscurecido si fuera de combate
--   P8: Caster (PALADIN NPC)      → oscurecido si fuera de combate
--   Fallback: enemigo genérico    → oscurecido si fuera de combate
local function GetReactionColor(unit)
    local db = KullThranUINameplatesDB or defaults
    local function C(key)
        return db[key] or defaults[key]
    end

    -- P1: Tapped → siempre retorna gris sin importar combate ni grupo
    if UnitIsTapDenied(unit) then
        local c = C("tapped")
        return c.r, c.g, c.b
    end

    -- P2: Quest mob → sólo si el color de quest está habilitado en DB
    if db.questMobColorEnabled and IsQuestMob(unit) then
        local qc = db.questMobColor or defaults.questMobColor
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
                local enabled = defaults.tankHasAggroEnabled
                if db.tankHasAggroEnabled ~= nil then enabled = db.tankHasAggroEnabled end
                if enabled then
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
    if focusC and UnitIsUnit(unit, "focus") then
        local enabled = defaults.focusColorEnabled
        if db.focusColorEnabled ~= nil then enabled = db.focusColorEnabled end
        if enabled then
            return focusC.r, focusC.g, focusC.b
        end
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
    local classification = UnitClassification(unit)
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
    return DarkenColor(eic.r, eic.g, eic.b)
end
local hookedUFs = {}
local hookedHighlights = {}
local npOffscreenParent = CreateFrame("Frame")
npOffscreenParent:Hide()
ns._offscreenParents = ns._offscreenParents or {}
ns.MoveToOffscreen = function(element)
    if not element then return end
    if not ns._offscreenParents[element] then
        ns._offscreenParents[element] = element:GetParent()
    end
    element:SetParent(npOffscreenParent)
end
ns.RestoreFromOffscreen = function(element)
    if not element then return end
    local origParent = ns._offscreenParents[element]
    if origParent then
        element:SetParent(origParent)
        ns._offscreenParents[element] = nil
    end
end
-- Lista centralizada de hijos del UnitFrame de Blizzard que se ocultan/restauran
-- al adquirir o liberar una placa enemiga. Definida una sola vez para que
-- HideBlizzardFrame y RestoreBlizzardFrame iteren la misma secuencia.
ns._BLIZZARD_UF_CHILDREN = {
    "healthBar", "HealthBarsContainer", "castBar", "name",
    "selectionHighlight", "aggroHighlight", "softTargetFrame",
    "SoftTargetFrame", "ClassificationFrame", "RaidTargetFrame",
    "PlayerLevelDiffFrame", "BuffFrame",
}

-- Suprime visualmente los elementos del UnitFrame Blizzard para nameplates
-- enemigos. NO reparenta: mantiene la jerarquía original para que el layout
-- y hit-testing de Blizzard sigan funcionando sin restricciones.
local function HideBlizzardFrame(nameplate, unit)
    if not nameplate then return end
    local uf = nameplate.UnitFrame
    if not uf then return end
    if unit and UnitCanAttack("player", unit) then
        uf:SetAlpha(0)
        -- Recorrer la tabla centralizada para ocultar cada hijo
        for _, key in ipairs(ns._BLIZZARD_UF_CHILDREN) do
            local elem = uf[key]
            if elem then elem:SetAlpha(0); elem:Hide() end
        end

        -- Mantener el procesamiento Blizzard de auras intacto (evita taint
        -- en su ruta segura de update), pero mover sus listas visuales fuera
        -- de pantalla para que debuffList/buffList sigan actualizandose.
        if uf.AurasFrame then
            ns.MoveToOffscreen(uf.AurasFrame.DebuffListFrame)
            ns.MoveToOffscreen(uf.AurasFrame.BuffListFrame)
            ns.MoveToOffscreen(uf.AurasFrame.CrowdControlListFrame)
            ns.MoveToOffscreen(uf.AurasFrame.LossOfControlFrame)
        end
        -- Mantener WidgetContainer funcional reparentándolo al nameplate
        -- para que su layout no afecte los bounds del UnitFrame
        if uf.WidgetContainer then
            uf.WidgetContainer:SetParent(nameplate)
        end
    end
    -- Hook de alpha: fuerza alpha 0 cuando Blizzard intenta restaurarlo
    if not hookedUFs[uf] then
        hookedUFs[uf] = true
        local locked = false
        hooksecurefunc(uf, "SetAlpha", function(self)
            if locked then return end
            locked = true
            local ufUnit = self.unit or (self.GetUnit and self:GetUnit())
            if ufUnit and UnitExists(ufUnit) and UnitCanAttack("player", ufUnit) then
                self:SetAlpha(0)
            end
            locked = false
        end)
    end
    -- KUI reads auras through C_UnitAuras slot APIs. Do not hook Blizzard's
    -- RefreshAuras or alter its UNIT_AURA registration: either action can make
    -- Blizzard iterate protected PvP collections from tainted execution.: suprime Show/SetShown en placas enemigas
    if uf.selectionHighlight and not hookedHighlights[uf.selectionHighlight] then
        hookedHighlights[uf.selectionHighlight] = true
        local function SuppressHighlight(self)
            local parent = self:GetParent()
            if parent == npOffscreenParent then return end
            if not parent then return end
            local ufUnit = parent.unit or (parent.GetUnit and parent:GetUnit())
            if ufUnit and UnitExists(ufUnit) and UnitCanAttack("player", ufUnit) then
                self:SetAlpha(0)
                self:Hide()
            end
        end
        hooksecurefunc(uf.selectionHighlight, "Show", SuppressHighlight)
        hooksecurefunc(uf.selectionHighlight, "SetShown", function(self, shown)
            if shown then SuppressHighlight(self) end
        end)
    end
end

-- Restaura los elementos del UnitFrame Blizzard cuando se libera una placa,
-- dejando el frame reciclado en estado limpio para la siguiente unidad.
local function RestoreBlizzardFrame(nameplate)
    if not nameplate then return end
    local uf = nameplate.UnitFrame
    if not uf then return end

    -- Restaurar visibilidad iterando la misma tabla centralizada
    for _, key in ipairs(ns._BLIZZARD_UF_CHILDREN) do
        local elem = uf[key]
        if elem then elem:SetAlpha(1); elem:Show() end
    end

    -- Restaurar WidgetContainer a su padre original
    if uf.WidgetContainer then uf.WidgetContainer:SetParent(uf) end

    -- Restaurar AurasFrame (sólo visibilidad; el event wiring queda en
    -- manos de Blizzard)
    if uf.AurasFrame then
        ns.RestoreFromOffscreen(uf.AurasFrame.DebuffListFrame)
        ns.RestoreFromOffscreen(uf.AurasFrame.BuffListFrame)
        ns.RestoreFromOffscreen(uf.AurasFrame.CrowdControlListFrame)
        ns.RestoreFromOffscreen(uf.AurasFrame.LossOfControlFrame)
    end
end
ns.HideBlizzardFrame = HideBlizzardFrame
local castFallbackFrame = CreateFrame("Frame")
local fallbackCastCount = 0
local _fallbackPlates = {}
castFallbackFrame:SetScript("OnUpdate", function()
    for plate in pairs(_fallbackPlates) do
        if plate.isCasting and plate.unit and plate.nameplate then
            local bc = plate.nameplate.UnitFrame and plate.nameplate.UnitFrame.castBar
            if bc and bc:IsShown() then
                if plate._castIsChannel then
                    local _, _, _, startTimeMS, endTimeMS = UnitChannelInfo(plate.unit)
                    if startTimeMS and endTimeMS and endTimeMS > startTimeMS then
                        local duration = (endTimeMS - startTimeMS) / 1000
                        local elapsed = math.max(0, math.min(duration, GetTime() - (startTimeMS / 1000)))
                        plate.cast:SetMinMaxValues(0, duration)
                        plate.cast:SetValue(elapsed)
                    else
                        plate.cast:SetMinMaxValues(bc:GetMinMaxValues())
                        plate.cast:SetValue(bc:GetValue())
                    end
                else
                    plate.cast:SetMinMaxValues(bc:GetMinMaxValues())
                    plate.cast:SetValue(bc:GetValue())
                end
            else
                if not plate._interrupted then
                    plate.cast:Hide()
                end
                plate.isCasting = false
                plate._castFallback = nil
                _fallbackPlates[plate] = nil
                fallbackCastCount = fallbackCastCount - 1
                if fallbackCastCount <= 0 then
                    fallbackCastCount = 0
                    castFallbackFrame:Hide()
                end
                EndInterruptTracking()
            end
        end
    end
end)
castFallbackFrame:Hide()

-- Pandemic glow alpha-only tick: only iterates slots with active pandemic glows
local pandemicTickFrame = CreateFrame("Frame")
local pandemicTickAccum = 0
pandemicTickFrame:SetScript("OnUpdate", function(_, elapsed)
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
end)

local NameplateFrame = {}
function NameplateFrame:RefreshStackBounds(nameplate)
    if not nameplate.SetStackingBoundsFrame then
        return
    end

    if not self._stackBounds then
        self._stackBounds = CreateFrame("Frame", nil, nameplate)
        local tex = self._stackBounds:CreateTexture(nil, "BACKGROUND")
        tex:SetColorTexture(1, 0, 0, 0)
        tex:SetAllPoints(self._stackBounds)
    end

    self._stackBounds:SetParent(nameplate)
    self._stackBounds:ClearAllPoints()

    local totalHeight = (4 + GetEnemyNameTextSize()) + GetHealthBarHeight() + GetCastBarHeight()
    self._stackBounds:SetPoint("CENTER", nameplate, "CENTER", 0, GetNameplateYOffset())
    self._stackBounds:SetSize(GetHealthBarWidth(), totalHeight * (GetStackSpacingScale() / 100))
    self._stackBounds:Show()
    nameplate:SetStackingBoundsFrame(self._stackBounds)
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
    self.health:SetPoint("CENTER", self, "CENTER", 0, yOffset)
    self.health:SetSize(barW, barH)
    self.absorb:SetSize(barW, barH)

    -- Barra de casteo: anclada debajo de la barra de salud
    self.cast:ClearAllPoints()
    self.cast:SetSize(barW, castH)
    self.cast:SetPoint("TOPLEFT", self.health, "BOTTOMLEFT", 0, 0)

    -- Icono de hechizo: cuadrado del tamaño del casteo, a la izquierda
    self.castIconFrame:ClearAllPoints()
    self.castIconFrame:SetSize(castH, castH)
    self.castIconFrame:SetPoint("TOPRIGHT", self.cast, "TOPLEFT", 0, 0)
    if GetShowCastIcon() then
        self.castIconFrame:SetScale(GetCastIconScale())
        self.castIconFrame:Show()
    else
        self.castIconFrame:Hide()
    end

    -- Elementos secundarios del casteo que dependen de castH
    self.castLeftBorder:SetWidth(1)
    self.castSpark:SetHeight(castH)
    self.kickMarker:SetSize(barW, castH)

    if self.absorbOverflow then
        self.absorbOverflow:SetHeight(barH)
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
    "UNIT_AURA", "LOSS_OF_CONTROL_UPDATE", "LOSS_OF_CONTROL_ADDED",
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

-- Refresca todos los datos visuales de la placa en su estado actual.
-- Se invoca una sola vez al final de SetUnit para evitar refrescos
-- parciales durante la inicialización.
function NameplateFrame:RefreshPlateState()
    self:UpdateHealth()
    self:UpdateName()
    self:UpdateClassification()
    self:UpdateRaidIcon()
    self:ApplyTarget()
    self:ApplyMouseover()
    self:UpdateAuras()
    self:UpdateCast()
    ApplyHealthBarTexture(self)
    ApplyCastBarTexture(self)
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
    self:ClearAllPoints()
    self:SetPoint("CENTER", nameplate, "CENTER", 0, GetHitboxYShift())
    self:SetSize(1, 1)
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
    self:RefreshNamePosition()
    self:ApplyCastFontSettings()
    self:ApplyAuraVisualSettings(GetAuraSpacing())

    -- Paso 3: suprimir UnitFrame Blizzard
    HideBlizzardFrame(nameplate, unit)

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
        if self._castFallback then
            self._castFallback = nil
            _fallbackPlates[self] = nil
            fallbackCastCount = fallbackCastCount - 1
            if fallbackCastCount <= 0 then fallbackCastCount = 0; castFallbackFrame:Hide() end
        end
        EndInterruptTracking()
    end

    -- 3. Limpiar ranuras de auras: CC primero (2 ranuras), luego debuffs+buffs (4 c/u)
    self.name:SetText("")
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
    self._shownAuras = nil
    self.cast:Hide()
    self.castShieldFrame:Hide()
    self.castShieldFrame:SetAlpha(1)
    self.castBarOverlay:SetAlpha(0)
    self.isCasting = false
    self._castFallback = nil
    self._castIsChannel = nil
    _fallbackPlates[self] = nil
    self._kickProtected = nil
    self:HideKickTick()
    if self._interruptTimer then
        self._interruptTimer:Cancel()
        self._interruptTimer = nil
    end
    self._interrupted = nil

    -- 5. Ocultar adornos visuales
    if self.glow then self.glow:Hide() end
    self.highlight:Hide()
    self.raidFrame:Hide()
    self.classFrame:Hide()
    if self.leftArrow then self.leftArrow:Hide() end
    if self.rightArrow then self.rightArrow:Hide() end
    HideClassPowerOnPlate(self)
    self.absorb:Hide()
    if self.absorbOverflow then
        self.absorbOverflow:Hide()
        self.absorbOverflow:SetWidth(0)
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
    if self._stackBounds then
        self._stackBounds:ClearAllPoints()
        self._stackBounds:SetParent(self)
        self._stackBounds:Hide()
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
        self:UpdateName()
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
-- Aplica el color de la barra de vida según GetReactionColor (8 niveles
-- de prioridad) y gestiona el overlay de focus (rayas) si la unidad
-- es el focus actual del jugador.
function NameplateFrame:UpdateHealthColor()
    local unit = self.unit
    if not unit then return end
    self.health:SetStatusBarColor(GetReactionColor(unit))
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
        local sideOffset = GetSideAuraXOffset()
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

local function GetTopNameReservedWidth(frame, barWidth)
    local reservedWidth = 0

    if frame.raidFrame and frame.raidFrame:IsShown() and GetRaidMarkerPos() ~= "none" then
        reservedWidth = reservedWidth + (2 * (GetRaidMarkerSize() - 2)) + 7
    end

    if frame.classFrame and frame.classFrame:IsShown() and GetClassificationSlot() ~= "none" then
        reservedWidth = reservedWidth + GetRareEliteIconSize() + 4
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

-- Fase 3 commit: oculta las flechas de target si existen
local function HideTargetArrows(frame)
    ns.SetTargetIndicatorShown(frame, false)
end

-- Fase 3 commit: dimensiona y muestra las flechas de target usando el
-- descriptor previamente resuelto en ns._ResolveTargetVisuals.
local function CommitTargetArrows(frame, desc)
    if not desc.arrowsNeeded then
        HideTargetArrows(frame)
        return
    end
    ns._AcquireVisualLayer(frame, "arrows")
    ns.RefreshTargetIndicatorTextures(frame, desc.indicatorStyle, desc.arrowScale)
    ns.SetTargetIndicatorShown(frame, true)
end

-- Fase 3 commit: muestra u oculta los pips de class power en la placa
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
        PP.Point(frame.name, "LEFT", frame.health, "LEFT", 4 + offsetX, offsetY)
        frame.name:SetJustifyH("LEFT")
        return true
    end
    if slotKey == "textSlotCenter" then
        frame.name:SetPoint("CENTER", frame.health, "CENTER", offsetX, offsetY)
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
        self.name:SetText("")
        return
    end

    local displayName = UnitName(unit)
    self.name:SetText(type(displayName) == "string" and displayName or "")
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

    local atlas = CLASSIFICATION_ATLASES[UnitClassification(unit)]
    if not atlas then
        self.classFrame:Hide()
        self:UpdateNameWidth()
        return
    end

    self.class:SetAtlas(atlas)
    PP.Size(self.classFrame, GetRareEliteIconSize(), GetRareEliteIconSize())
    local offsetX, offsetY = ns._AuraLayout.ResolveOffsets("classification")
    AnchorPlateAdornment(self.classFrame, slot, offsetX, offsetY, GetClassPowerTopPush(self))
    self.classFrame:Show()
    self:UpdateNameWidth()
end
function NameplateFrame:UpdateNameWidth()
    local barW = GetHealthBarWidth()
    local nameSlot = FindSlotForElement("enemyName")

    if nameSlot == "textSlotTop" then
        PP.Width(self.name, GetTopNameReservedWidth(self, barW))
        return
    end

    if nameSlot then
        local remainingWidth = barW - GetInlineNameReservedWidth(nameSlot)
        PP.Width(self.name, math.max(remainingWidth, 20))
        return
    end

    PP.Width(self.name, math.max(barW, 20))
end
-- Re-ancla el nombre de la unidad según el slot actual y refresca
-- auras y clasificación para mantener coherencia de layout.
function NameplateFrame:RefreshNamePosition()
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

    self:UpdateAuras()
    self:UpdateClassification()
end
-- Muestra/oculta el icono de marca de raid en la posición configurada.
function NameplateFrame:UpdateRaidIcon()
    local unit = SyncPlateUnitToken(self)
    if not unit then
        self.raidFrame:Hide()
        self:UpdateNameWidth()
        return
    end

    local pos = GetRaidMarkerPos()
    local markerIndex = GetRaidTargetIndex and GetRaidTargetIndex(unit)
    if pos == "none" or type(markerIndex) == "nil" then
        self.raidFrame:Hide()
        self:UpdateNameWidth()
        return
    end

    SetRaidTargetIconTexture(self.raid, markerIndex)
    PP.Size(self.raidFrame, GetRaidMarkerSize(), GetRaidMarkerSize())
    local offsetX, offsetY = ns._AuraLayout.ResolveOffsets("raidMarker")
    AnchorPlateAdornment(self.raidFrame, pos, offsetX, offsetY, GetClassPowerTopPush(self))
    self.raidFrame:Show()
    self:UpdateNameWidth()
end
-- Fase 3 commit: aplica el estado visual de target sobre la placa.
-- Consume el descriptor de ns._ResolveTargetVisuals para decidir qué
-- capas mostrar/ocultar, evitando recálculos redundantes.
function NameplateFrame:ApplyTarget()
    local unit = SyncPlateUnitToken(self)
    if not unit then
        return
    end

    -- Fase 1: resolver estado visual completo
    local desc = ns._ResolveTargetVisuals(self, unit)

    -- Fase 2+3: glow – adquirir recurso sólo si lo necesitamos
    if desc.glowNeeded then
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

    -- Fase 3: bordes – vibrant tiñe de blanco; todo lo demás restaura color
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

    -- Fase 3: flechas y class power desde descriptor
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
    if self._interruptTimer then
        self._interruptTimer:Cancel()
        self._interruptTimer = nil
    end
end

function NameplateFrame:RefreshTargetClassPowerPosition()
    if GetShowClassPower() and classPowerType and self._cpPips and self.unit and UnitIsUnit(self.unit, "target") then
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
        if self._castFallback then
            self._castFallback = nil
            _fallbackPlates[self] = nil
            fallbackCastCount = fallbackCastCount - 1
            if fallbackCastCount <= 0 then
                fallbackCastCount = 0
                castFallbackFrame:Hide()
            end
        end

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

    self.castName:SetWidth(0)
    self.castName:ClearAllPoints()
    self.castName:SetPoint("LEFT", self.cast, "LEFT", 5, 0)
    self.castName:SetPoint("RIGHT", self.castTarget, "LEFT", -5, 0)

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
    if not (C_Spell and C_Spell.GetSpellCooldownDuration) then
        self:HideKickTick()
        return
    end
    -- Midnight path: use secret duration objects
    if UnitCastingDuration and self.cast.SetTimerDuration then
        local castDuration = isChannel and UnitChannelDuration(self.unit) or UnitCastingDuration(self.unit)
        if not castDuration then
            self:HideKickTick()
            return
        end

        local interruptCD = C_Spell.GetSpellCooldownDuration(activeKickSpell)
        if not interruptCD then
            self:HideKickTick()
            return
        end

        local reverseFill = self.cast.GetReverseFill and self.cast:GetReverseFill() or (isChannel and true or false)
        self:PrimeKickTickBars(castDuration, interruptCD, reverseFill)
        self:StopKickTicker()
        self._kickTicker = C_Timer.NewTicker(0.1, function()
            local profiler = _G.KT and _G.KT.CombatProfiler
            local profileStarted = profiler and profiler:Begin("nameplates.kick_tick.tick")
            if not self.isCasting or not self.unit then
                self:HideKickTick()
                if profileStarted then
                    profiler:End("nameplates.kick_tick.tick", profileStarted)
                end
                return
            end

            local icd = C_Spell.GetSpellCooldownDuration(activeKickSpell)
            if not icd then
                self:HideKickTick()
                if profileStarted then
                    profiler:End("nameplates.kick_tick.tick", profileStarted)
                end
                return
            end

            -- The duration object is already refreshed at 10 Hz here.  Updating
            -- the marker in-place avoids rebuilding anchors and recreating this
            -- ticker on every global SPELL_UPDATE_COOLDOWN event.
            self.kickMarker:SetValue(icd:GetRemainingDuration())
            self:RefreshKickTickAlpha(icd)
            if profileStarted then
                profiler:End("nameplates.kick_tick.tick", profileStarted)
            end
        end)
    else
        self:HideKickTick()
    end
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
        if self._castFallback then
            self._castFallback = nil
            _fallbackPlates[self] = nil
            fallbackCastCount = fallbackCastCount - 1
            if fallbackCastCount <= 0 then fallbackCastCount = 0; castFallbackFrame:Hide() end
        end
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
    self.castName:SetWidth(0)
    self.castName:ClearAllPoints()
    self.castName:SetPoint("LEFT", self.cast, "LEFT", 5, 0)
    self.castName:SetPoint("RIGHT", self.castTarget, "LEFT", -5, 0)
    self.castShieldFrame:Hide()
    self.castShieldFrame:SetAlpha(1)
    self.castBarOverlay:SetAlpha(0)
    self.cast:Show()

    -- Programar auto-ocultación tras 1 segundo
    if self._interruptTimer then
        self._interruptTimer:Cancel()
        self._interruptTimer = nil
    end
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
manager:RegisterEvent("PLAYER_LOGIN")
manager:RegisterEvent("NAME_PLATE_UNIT_ADDED")
manager:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
manager:RegisterEvent("PLAYER_TARGET_CHANGED")
manager:RegisterEvent("PLAYER_FOCUS_CHANGED")
manager:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
manager:RegisterEvent("RAID_TARGET_UPDATE")
manager:RegisterEvent("PLAYER_REGEN_DISABLED")
manager:RegisterEvent("PLAYER_REGEN_ENABLED")
manager:RegisterEvent("GROUP_ROSTER_UPDATE")
manager:RegisterEvent("PLAYER_ROLES_ASSIGNED")
manager:RegisterEvent('ARENA_OPPONENT_UPDATE')
manager:RegisterEvent('ARENA_PREP_OPPONENT_SPECIALIZATIONS')
manager:RegisterEvent('UPDATE_BATTLEFIELD_SCORE')
manager:RegisterEvent("PLAYER_ENTERING_WORLD")
manager:RegisterEvent("ZONE_CHANGED_NEW_AREA")
manager:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
manager:RegisterEvent("DISPLAY_SIZE_CHANGED")
manager:RegisterEvent("UI_SCALE_CHANGED")

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

local function AcquireEnemyPlate(unit, nameplate)
    local plate = frameCache:Acquire()
    if not plate._mixedIn then
        Mixin(plate, NameplateFrame)
        plate._mixedIn = true
    end
    ns.plates[unit] = plate
    ns.platesByNameplate[nameplate] = plate
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
        if not UnitCanAttack("player", u) then return end

        -- Limpieza del estado de transición antes de tocar la placa
        self:UnregisterAllEvents()
        transitionState.pendingUnits[u] = nil
        transitionState.pendingWatchers[u] = nil

        -- Promoción: retirar friendly → adquirir enemiga → vigilar retorno
        RemoveFriendlyPresentation(u)
        local np = C_NamePlate.GetNamePlateForUnit(u)
        if np then AcquireEnemyPlate(u, np) end
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
        if UnitCanAttack("player", u) then return end

        self:UnregisterAllEvents()
        transitionState.enemyWatchers[u] = nil
        ReleaseEnemyPlate(u)

        -- Intentar restaurar presentación friendly y preparar el camino inverso
        local np = C_NamePlate.GetNamePlateForUnit(u)
        if not np then return end
        transitionState.pendingUnits[u] = np
        transitionState.pendingWatchers[u] = transitionState.CreatePendingWatcher(u, np)
        if ns.TryAddFriendlyPlate then
            ns.TryAddFriendlyPlate(u)
        end
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
        if watcher and UnitCanAttack("player", unit) then
            local handler = watcher:GetScript("OnEvent")
            if handler then handler(watcher, "UNIT_FACTION", unit) end
        end
    end
    for i = 1, #enemies do
        local unit = enemies[i]
        local watcher = transitionState.enemyWatchers[unit]
        if watcher and not UnitCanAttack("player", unit) then
            local handler = watcher:GetScript("OnEvent")
            if handler then handler(watcher, "UNIT_FACTION", unit) end
        end
    end

    -- Fallback for a recycled plate whose watcher was lost. Only inspect the
    -- small custom enemy-plate pool, and restore units that are now friendly.
    local staleEnemies = {}
    ns.SafeForEachPlate(function(unit, _)
        if not transitionState.enemyWatchers[unit] and not UnitCanAttack("player", unit) then
            staleEnemies[#staleEnemies + 1] = unit
        end
    end)
    for i = 1, #staleEnemies do
        local unit = staleEnemies[i]
        ReleaseEnemyPlate(unit)
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate then
            transitionState.pendingUnits[unit] = nameplate
            transitionState.pendingWatchers[unit] = transitionState.CreatePendingWatcher(unit, nameplate)
            if ns.TryAddFriendlyPlate then ns.TryAddFriendlyPlate(unit) end
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

transitionState.factionFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
transitionState.factionFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
transitionState.factionFrame:RegisterEvent("PLAYER_DIFFICULTY_CHANGED")
transitionState.factionFrame:RegisterEvent("ROLE_CHANGED_INFORM")
transitionState.factionFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED")
transitionState.factionFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
transitionState.factionFrame:RegisterEvent("DUEL_FINISHED")
transitionState.factionFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "DUEL_FINISHED" then
        ReconcileFactionTransitions()
        -- Faction/attackability can settle one client tick after the duel event.
        C_Timer.After(0.10, ReconcileFactionTransitions)
        return
    end
    if event == "PLAYER_ENTERING_WORLD"
    or event == "ZONE_CHANGED_NEW_AREA"
    or event == "PLAYER_DIFFICULTY_CHANGED"
    or event == "ROLE_CHANGED_INFORM"
    or event == "PLAYER_ROLES_ASSIGNED"
    or event == "GROUP_ROSTER_UPDATE" then
        ns.RefreshThreatContextAndPlateColors()
        if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
            UpdateFactionFrameForZone()
        end
        if event == "PLAYER_ENTERING_WORLD" then
            -- El PEW inicial puede dispararse antes de que los datos de dificultad/instancia se asienten.
            C_Timer.After(0.6, function()
                ns.RefreshThreatContextAndPlateColors()
                UpdateFactionFrameForZone()
            end)
        end
        return
    end
    -- UNIT_FACTION dispatch
    if transitionState.pendingWatchers[unit] then
        local w = transitionState.pendingWatchers[unit]
        w:GetScript("OnEvent")(w, "UNIT_FACTION", unit)
    elseif transitionState.enemyWatchers[unit] then
        local w = transitionState.enemyWatchers[unit]
        w:GetScript("OnEvent")(w, "UNIT_FACTION", unit)
    end
end)
local function UpdateMouseover()
    local mouseoverNameplate = UnitExists("mouseover") and C_NamePlate.GetNamePlateForUnit("mouseover")
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
-- Refresh Y-offset on all visible friendly name-only plates
function ns.RefreshFriendlyNameOnlyOffset()
    local db = KullThranUINameplatesDB or defaults
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
    if KullThranUI.AppendSharedMediaTextures then
        KullThranUI.AppendSharedMediaTextures(
            ns.healthBarTextureNames,
            ns.healthBarTextureOrder,
            nil,
            ns.healthBarTextures
        )
    end
    SetupAuraCVars()
    ApplyClassPowerSetting()
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
    SetupAuraCVars()

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
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if not nameplate then return end
        if not ns.IsEnemyNameplateUnit(unit, nameplate) then
            transitionState.pendingUnits[unit] = nameplate
            transitionState.pendingWatchers[unit] = transitionState.CreatePendingWatcher(unit, nameplate)
            if ns.TryAddFriendlyPlate then ns.TryAddFriendlyPlate(unit) end
            -- Colorear nombres de NPC en verde en modo name-only
            if ns.TryColorFriendlyNPCName then ns.TryColorFriendlyNPCName(unit, nameplate) end
            -- Ocultar barras de vida de NPC en modo name-only
            if ns.TrySuppressNPCHealthBar then ns.TrySuppressNPCHealthBar(unit, nameplate) end
            -- Asegurar que el UF de Blizzard esté visible para placas friendly en
            -- modo name-only. Los frames se reciclan: un UF usado para enemigo
            -- puede tener alpha 0 o hijos reparentados offscreen.
            local db = KullThranUINameplatesDB or defaults
            -- Friendly players use Blizzard's name region in name-only mode.
            -- Friendly NPCs use KUI's overlay and their complete Blizzard UF
            -- must remain suppressed.
            if db.friendlyNameOnly ~= false and ns.IsPlayerNameplateUnit(unit, nameplate) then
                local uf = nameplate.UnitFrame
                if uf then
                    -- Restaurar alpha si el UF reciclado estaba suprimido
                    -- Alpha on a recycled Blizzard plate can be protected.
                    -- Restore the intended value without reading/comparing it.
                    uf:SetAlpha(1)
                    -- Restaurar FontString del nombre si fue movido offscreen
                    if uf.name and uf.name:GetParent() ~= uf then
                        uf.name:SetParent(uf)
                    end
                    -- Asegurar que el UF esté parented al nameplate (no al frame oculto)
                    if uf:GetParent() ~= nameplate then
                        uf:SetParent(nameplate)
                        uf:SetAlpha(1)
                        uf:Show()
                    end
                    if ns.EnforceFriendlyPlayerNameOnly then
                        ns.EnforceFriendlyPlayerNameOnly(nameplate, unit)
                    end
                end
                -- Aplicar offset Y
                local yOff = db.friendlyNameOnlyYOffset or 0
                if yOff ~= 0 and nameplate.UnitFrame then
                    nameplate.UnitFrame:SetPoint("TOPLEFT", nameplate, "TOPLEFT", 0, yOff)
                    nameplate.UnitFrame:SetPoint("BOTTOMRIGHT", nameplate, "BOTTOMRIGHT", 0, yOff)
                    nameplate._enoYOffset = true
                end
                -- La fuente se aplica globalmente vía SystemFont_NamePlate override
            end
            return
        end
        transitionState.pendingUnits[unit] = nil
        if ns.plates[unit] then
            ReleaseEnemyPlate(unit)
        end
        local plate = frameCache:Acquire()
        if not plate._mixedIn then
            Mixin(plate, NameplateFrame)
            plate._mixedIn = true
        end
        ns.plates[unit] = plate
        ns.platesByNameplate[nameplate] = plate
        plate:SetUnit(unit, nameplate)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        questMobCache[unit] = nil
        -- Restaurar elementos del UnitFrame de Blizzard para que el nameplate reciclado quede limpio
        local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
        if nameplate then
            RestoreBlizzardFrame(nameplate)
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
        if transitionState.pendingWatchers[unit] then
            transitionState.pendingWatchers[unit]:UnregisterAllEvents()
            transitionState.pendingWatchers[unit] = nil
        end
        if transitionState.enemyWatchers[unit] then
            transitionState.enemyWatchers[unit]:UnregisterAllEvents()
            transitionState.enemyWatchers[unit] = nil
        end
        local plate = ns.plates[unit]
        if plate then
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
        if ns.RemoveFriendlyPlate then ns.RemoveFriendlyPlate(unit) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        local targetNameplate = UnitExists("target") and C_NamePlate.GetNamePlateForUnit("target")
        local newTargetPlate = targetNameplate and ns.platesByNameplate[targetNameplate] or nil
        if ns.currentTargetPlate and ns.currentTargetPlate ~= newTargetPlate then
            ns.currentTargetPlate:ApplyTarget()
        end
        if newTargetPlate then
            newTargetPlate:ApplyTarget()
        end
        ns.currentTargetPlate = newTargetPlate
    elseif event == "PLAYER_FOCUS_CHANGED" then
        local focusPct = GetFocusCastHeight()
        local focusNameplate = UnitExists("focus") and C_NamePlate.GetNamePlateForUnit("focus")
        local newFocusPlate = focusNameplate and ns.platesByNameplate[focusNameplate] or nil
        local function RefreshFocusPlate(plate)
            if not plate then return end
            plate:UpdateHealthColor()
            if focusPct ~= 100 then
                local castH = GetCastBarHeight()
                if plate.unit and UnitIsUnit(plate.unit, "focus") then
                    castH = math.floor(castH * focusPct / 100 + 0.5)
                end
                plate.cast:SetHeight(castH)
                plate.castIconFrame:SetSize(castH, castH)
                plate.castSpark:SetHeight(castH)
                plate.kickMarker:SetHeight(castH)
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
        SetupAuraCVars()
        if ns.UpdateFriendlyNameplateSystem then
            ns.UpdateFriendlyNameplateSystem()
        end
        C_Timer.After(0.5, function()
            if IsNameplatesEnabled() then
                SetupAuraCVars()
                if ns.UpdateFriendlyNameplateSystem then
                    ns.UpdateFriendlyNameplateSystem()
                end
            end
        end)
        RefreshThreatCache()
    elseif event == 'ZONE_CHANGED_NEW_AREA' or event == 'PLAYER_DIFFICULTY_CHANGED' then
        SetupAuraCVars()
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
        if ns.ApplyNamePlateClickArea then
            ns.ApplyNamePlateClickArea()
        end
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

-------------------------------------------------------------------------------
--  SPEC PRESET LOGIN HANDLER
--  Applies the correct spec-assigned preset on login and on spec change,
--  even before the options UI is ever opened.  Once the UI opens and
--  RegisterSpecAutoSwitch is called, the framework handler takes over for
--  PLAYER_SPECIALIZATION_CHANGED; this early handler ensures the first
--  login is covered.
-------------------------------------------------------------------------------
do
    local function ApplySpecPresetFromDB()
        local db = KullThranUINameplatesDB
        if not db then return end

        local specIndex = GetSpecialization and GetSpecialization() or 0
        local specID = specIndex and specIndex > 0 and GetSpecializationInfo
                       and GetSpecializationInfo(specIndex) or nil
        if not specID then return end

        local K_ASSIGN  = "_specAssignments"
        local K_ACTIVE  = "_activePreset"
        local K_DEFAULT = "_specDefaultPreset"
        local K_PRESETS = "_presets"
        local K_SNAP    = "_builtinSnapshot"
        local K_CUSTOM  = "_customPreset"

        local specMap = db[K_ASSIGN]
        if not specMap then return end

        -- Comprobar si existe alguna asignación de spec
        local hasAny = false
        for _, specList in pairs(specMap) do
            if next(specList) then hasAny = true; break end
        end
        if not hasAny then return end

        -- Buscar qué preset posee este specID
        local targetKey
        for presetKey, specList in pairs(specMap) do
            if specList[specID] then targetKey = presetKey; break end
        end
        -- Fallback al preset por defecto si no hay coincidencia directa
        if not targetKey and db[K_DEFAULT] then
            targetKey = db[K_DEFAULT]
        end
        if not targetKey then return end

        local currentActive = db[K_ACTIVE] or "kullthranui"
        if currentActive == targetKey then return end  -- ya es el correcto

        -- Aplicar la snapshot para targetKey
        local presetKeys = ns._displayPresetKeys  -- set below
        if not presetKeys then return end

        if targetKey == "kullthranui" then
            for _, key in ipairs(presetKeys) do
                local def = ns.defaults[key]
                if type(def) == "table" and def.r then
                    db[key] = { r = def.r, g = def.g, b = def.b }
                else
                    db[key] = def
                end
            end
            db[K_SNAP] = nil
        elseif targetKey == "custom" then
            if db[K_CUSTOM] then
                for _, key in ipairs(presetKeys) do
                    local v = db[K_CUSTOM][key]
                    if v ~= nil then
                        if type(v) == "table" and v.r then
                            db[key] = { r = v.r, g = v.g, b = v.b }
                        else
                            db[key] = v
                        end
                    end
                end
            end
        elseif targetKey:sub(1, 5) == "user:" then
            local name = targetKey:sub(6)
            local snap = db[K_PRESETS] and db[K_PRESETS][name]
            if snap then
                for _, key in ipairs(presetKeys) do
                    local v = snap[key]
                    if v ~= nil then
                        if type(v) == "table" and v.r then
                            db[key] = { r = v.r, g = v.g, b = v.b }
                        else
                            db[key] = v
                        end
                    end
                end
            end
        end

        db[K_ACTIVE] = targetKey
        db[K_SNAP] = nil
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
            "raidMarkerPos", "classificationSlot"
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

    -- Manejar cambios de spec que ocurren antes de abrir la UI
    local specLoginFrame = CreateFrame("Frame")
    specLoginFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    specLoginFrame:SetScript("OnEvent", function(_, event, unit)
        if unit ~= "player" then return end
        RefreshThreatCache()
        -- Si el handler del framework está registrado, dejar que él gestione esto
        if KullThranUI and KullThranUI._specSwitchRegistry
           and #KullThranUI._specSwitchRegistry > 0 then
            return
        end
        ApplySpecPresetFromDB()
        if ns.RefreshAllSettings then ns.RefreshAllSettings() end
    end)

    -- Exponer para llamar desde OnEnable (tiempo de login)
    ns._ApplySpecPresetFromDB = ApplySpecPresetFromDB
    _G._ENP_RefreshAllSettings = function() if ns.RefreshAllSettings then ns.RefreshAllSettings() end end
end
