local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local AR = KT:NewModule("Armory", "AceEvent-3.0", "AceHook-3.0")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end

-- Cache WoW Globals
local _G = _G
local pairs, select, tonumber = pairs, select, tonumber
local issecretvalue = issecretvalue
local securecallfunction = securecallfunction
local GetInventoryItemLink = GetInventoryItemLink
local GetInventoryItemQuality = GetInventoryItemQuality
local GetAverageItemLevel = GetAverageItemLevel
local GetItemInfo = GetItemInfo
local C_Item = C_Item
local C_TooltipInfo = C_TooltipInfo
local hooksecurefunc = hooksecurefunc
local ItemLocation = ItemLocation
local UnitClass = UnitClass
local UnitName = UnitName
local UnitLevel = UnitLevel
local GetZoneText = GetZoneText
local C_ChallengeMode = C_ChallengeMode
local C_ClassColor = C_ClassColor
local MenuUtil = MenuUtil
local GetSpecialization = GetSpecialization
local GetSpecializationInfo = GetSpecializationInfo
local UnitStat = UnitStat
local UnitArmor = UnitArmor
local GetCritChance = GetCritChance
local GetHaste = GetHaste
local UnitSpellHaste = UnitSpellHaste
local GetMasteryEffect = GetMasteryEffect
local GetVersatilityBonus = GetVersatilityBonus
local GetCombatRatingBonus = GetCombatRatingBonus
local GetLifesteal = GetLifesteal
local GetAvoidance = GetAvoidance
local GetSpeed = GetSpeed
local GetUnitSpeed = GetUnitSpeed
local UnitSpeed = UnitSpeed
local CR_VERSATILITY_DAMAGE_DONE = CR_VERSATILITY_DAMAGE_DONE
local GetDodgeChance = GetDodgeChance
local GetParryChance = GetParryChance
local GetBlockChance = GetBlockChance
local SetPortraitTexture = SetPortraitTexture
local GetPersonalRatedInfo = GetPersonalRatedInfo
local C_PvP = C_PvP

-- RUTAS DE TEXTURAS
local TEXTURE_PATH = "Interface\\AddOns\\KullThranUI\\Modules\\Armory\\Armory Textures\\"
local STATS_TEXTURE_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\"
local ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"
local DEFAULT_BACKGROUND_FILE = "Space.blp"

-- TEXTURAS ESPECIFICAS
local TITLE_STRIPE = STATS_TEXTURE_PATH .. "title_background_png.tga"
local PANEL_BG = STATS_TEXTURE_PATH .. "KUISettingsSurface.png"
local ARMORY_PANEL_BG = STATS_TEXTURE_PATH .. "KUISettingsSurface.png"
local ARMORY_PANEL_ASPECT = 583 / 1024
local STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

-- Route any font name/path through the locale-aware resolver so Latin-only
-- faces (Friz Quadrata, FRIZQT__, Avant Garde) can never paint tofu on
-- non-Latin languages; on Latin locales raw paths are kept raw.
local function SafeFont(nameOrPath, fallback)
    if KT and KT.ResolveFontForLocale then
        return KT:ResolveFontForLocale(nameOrPath, fallback or STANDARD_TEXT_FONT)
    end
    return (LSM and nameOrPath and LSM:Fetch("font", nameOrPath)) or fallback or STANDARD_TEXT_FONT
end
local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"
local ARMORY_HEADER_GOLD = { r = 0.94, g = 0.78, b = 0.29, a = 1 }
local ARMORY_ILVL_PURPLE_LEGACY = { r = 0.72, g = 0.46, b = 0.96, a = 1 }
local ARMORY_ILVL_PURPLE = { r = 0.7568627451, g = 0.00, b = 1.00, a = 1 }
local ARMORY_PVP_ILVL_COLOR = { r = 0.00, g = 0.50, b = 1.00, a = 1 }
local ARMORY_ATTRIBUTE_COLOR_LEGACY = { r = 0.93, g = 0.58, b = 0.34, a = 1 }
local ARMORY_ATTRIBUTE_COLOR = { r = 1.00, g = 0.4823529412, b = 0.00, a = 1 }
local ARMORY_ENHANCEMENT_COLOR_LEGACY = { r = 0.36, g = 0.82, b = 0.74, a = 1 }
local ARMORY_ENHANCEMENT_COLOR = { r = 0.00, g = 1.00, b = 0.6156862745, a = 1 }
local ARMORY_SECONDARY_COLOR = { r = 1.00, g = 0.96, b = 0.41, a = 1 }
local ARMORY_DEFENSE_COLOR = { r = 0.00, g = 0.44, b = 0.87, a = 1 }
local ARMORY_ARMOR_COLOR = { r = 0.2, g = 0.6588235294, b = 0.9019607843, a = 1 }
local ARMORY_GENERAL_COLOR = { r = 0.60, g = 0.60, b = 0.60, a = 1 }
local ARMORY_ATTACK_COLOR = { r = 1.00, g = 0.41, b = 0.70, a = 1 }
local ARMORY_PURPLE_COLOR = { r = 0.64, g = 0.21, b = 0.93, a = 1 }
local ARMORY_PINK_COLOR = { r = 0.9882352941, g = 0.6745098039, b = 0.6745098039, a = 1 }
local ARMORY_HEADER_ATTRIBUTE = { r = 1.00, g = 0.64, b = 0.00, a = 1 }
local ARMORY_HEADER_SECONDARY = { r = 0.50, g = 0.78, b = 0.50, a = 1 }
local ARMORY_HEADER_DEFENSE = { r = 0.41, g = 0.80, b = 0.94, a = 1 }
local ARMORY_HEADER_GENERAL = { r = 0.75, g = 0.75, b = 0.75, a = 1 }
local STATS_TABS_RESERVED_HEIGHT = 36

local ENCHANT_QUALITY_ICON_PATTERN = "(|A.-|a)"

local function SafeArmoryNumber(value)
    if value == nil then
        return nil
    end

    if issecretvalue and issecretvalue(value) then
        if not securecallfunction then
            return nil
        end

        local extracted = securecallfunction(function(v)
            return tonumber(v)
        end, value)

        if extracted == nil or (issecretvalue and issecretvalue(extracted)) then
            return nil
        end

        return extracted
    end

    return tonumber(value)
end

local function SafeArmoryNumberCall(func, ...)
    if not func then
        return nil, nil, nil, nil, nil
    end

    local ok, a, b, c, d, e = pcall(func, ...)
    if not ok then
        return nil, nil, nil, nil, nil
    end

    return SafeArmoryNumber(a), SafeArmoryNumber(b), SafeArmoryNumber(c), SafeArmoryNumber(d), SafeArmoryNumber(e)
end
-- GetSpeed is the tertiary Speed stat, not total movement. Use the run-speed
-- result from GetUnitSpeed and normalize the 7 yards/sec base to 100%.
local ARMORY_BASE_RUN_SPEED = 7
local function GetArmorySpeedPercent()
    local _, runSpeed = SafeArmoryNumberCall(GetUnitSpeed or UnitSpeed, 'player')
    if runSpeed and runSpeed > 0 then
        return (runSpeed / ARMORY_BASE_RUN_SPEED) * 100
    end

    local unitSpeed = SafeArmoryNumberCall(UnitSpeed, "player")
    if unitSpeed and unitSpeed > 0 then
        return (unitSpeed / ARMORY_BASE_RUN_SPEED) * 100
    end

    return 100
end
local function GetArmoryHastePercent()
    -- UnitSpellHaste matches the character-sheet value and
    -- includes the current haste effects more reliably than GetHaste alone.
    local haste = SafeArmoryNumberCall(UnitSpellHaste, "player")
    if haste ~= nil then
        return haste
    end

    return SafeArmoryNumberCall(GetHaste) or 0
end
local function GetArmoryAccentColor(alpha)
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin or nil
    if skin and skin.armoryColorMode == "custom" and skin.armoryColor then
        local c = skin.armoryColor
        return c.r or 1, c.g or 0, c.b or 0.3333333333, alpha or c.a or 1
    end
    if KT and KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        return r or 1, g or 0, b or 0.3333333333, alpha or 1
    end
    return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333, alpha or 1
end

local function ApplyArmoryTextureGradient(texture, orientation, startR, startG, startB, startA, endR, endG, endB, endA)
    if not texture then
        return
    end

    texture:SetTexture(WHITE8X8)
    if texture.SetGradientAlpha then
        texture:SetGradientAlpha(
            orientation or "HORIZONTAL",
            startR or 1, startG or 1, startB or 1, startA or 1,
            endR or 1, endG or 1, endB or 1, endA or 1
        )
    else
        texture:SetColorTexture(startR or 1, startG or 1, startB or 1, math.max(startA or 0, endA or 0))
    end
end

local function ApplyArmoryPanelTexture(texture)
    if not texture then
        return
    end

    local ok = false
    if texture.SetTexture then
        local success, result = pcall(texture.SetTexture, texture, ARMORY_PANEL_BG)
        ok = success and result ~= false
    end

    if not ok and texture.SetTexture then
        texture:SetTexture(PANEL_BG)
    end

    texture:SetBlendMode("BLEND")
    texture:SetVertexColor(1, 1, 1, 1)
end

local function LayoutArmoryPanelTexture(texture, parent)
    if not (texture and parent) then
        return
    end

    local width = parent.GetWidth and parent:GetWidth() or 0
    local height = parent.GetHeight and parent:GetHeight() or 0
    if width <= 0 or height <= 0 then
        texture:ClearAllPoints()
        texture:SetAllPoints(parent)
        if texture.SetTexCoord then
            texture:SetTexCoord(0, 1, 0, 1)
        end
        return
    end

    texture:ClearAllPoints()
    if texture.SetTexCoord then
        texture:SetTexCoord(0, 1, 0, 1)
    end

    local targetWidth = height * ARMORY_PANEL_ASPECT
    if targetWidth >= width then
        texture:SetPoint("TOP", parent, "TOP", 0, 0)
        texture:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)
        texture:SetWidth(targetWidth)
    else
        local targetHeight = width / ARMORY_PANEL_ASPECT
        texture:SetPoint("LEFT", parent, "LEFT", 0, 0)
        texture:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
        texture:SetHeight(targetHeight)
        texture:SetPoint("CENTER", parent, "CENTER", 0, 0)
    end
end

local function IsApproxColor(color, r, g, b, a)
    if type(color) ~= "table" then
        return false
    end

    local epsilon = 0.02
    return math.abs((color.r or 0) - r) <= epsilon
        and math.abs((color.g or 0) - g) <= epsilon
        and math.abs((color.b or 0) - b) <= epsilon
        and math.abs((color.a or 1) - (a or 1)) <= epsilon
end

local function CopyColor(color)
    return { r = color.r or 1, g = color.g or 1, b = color.b or 1, a = color.a or 1 }
end

local function PromoteColor(profile, key, targetColor, legacyColor)
    if type(profile) ~= "table" then
        return
    end

    local color = profile[key]
    if color == nil
        or (legacyColor and IsApproxColor(color, legacyColor.r, legacyColor.g, legacyColor.b, legacyColor.a))
        or IsApproxColor(color, ARMORY_HEADER_GOLD.r, ARMORY_HEADER_GOLD.g, ARMORY_HEADER_GOLD.b, ARMORY_HEADER_GOLD.a)
    then
        profile[key] = CopyColor(targetColor)
    end
end

local function LayoutHeaderSideLines(leftLine, rightLine, label, parent, color)
    if not (leftLine and rightLine and label and parent) then
        return
    end

    local parentWidth = parent.GetWidth and parent:GetWidth() or 180
    local labelWidth = label.GetStringWidth and label:GetStringWidth() or 0
    local gap = math.max(10, math.floor(parentWidth * 0.06))
    local lineWidth = math.max(28, math.floor((parentWidth - labelWidth - (gap * 2)) / 2))
    local labelHalfWidth = math.floor((labelWidth or 0) / 2)
    local r = (color and color.r) or 1
    local g = (color and color.g) or 1
    local b = (color and color.b) or 1
    local a = ((color and color.a) or 1) * 0.82

    leftLine:ClearAllPoints()
    leftLine:SetSize(lineWidth, 2)
    leftLine:SetPoint("RIGHT", label, "CENTER", -(labelHalfWidth + gap), 0)
    leftLine:SetTexture(WHITE8X8)
    leftLine:SetColorTexture(r, g, b, a)
    leftLine:Show()

    rightLine:ClearAllPoints()
    rightLine:SetSize(lineWidth, 2)
    rightLine:SetPoint("LEFT", label, "CENTER", labelHalfWidth + gap, 0)
    rightLine:SetTexture(WHITE8X8)
    rightLine:SetColorTexture(r, g, b, a)
    rightLine:Show()
end

local function EnsureArmoryColorDefaults(profile)
    if type(profile) ~= "table" then
        return
    end

    -- Forzar nuevos valores de colores (sobrescribe perfiles existentes)
    profile.statFontSize = 11
    profile.armorColor = CopyColor(ARMORY_ARMOR_COLOR)
    profile.leechColor = CopyColor(ARMORY_PINK_COLOR)
    profile.avoidanceColor = CopyColor(ARMORY_PINK_COLOR)
    profile.speedColor = CopyColor(ARMORY_PINK_COLOR)

    if profile.showAvgIlvlPvP == nil then profile.showAvgIlvlPvP = true end
    if profile.avgIlvlPvPShowLabel == nil then profile.avgIlvlPvPShowLabel = true end
    if profile.avgIlvlPvPDecimals == nil then profile.avgIlvlPvPDecimals = false end
    profile.avgIlvlPvPFont = profile.avgIlvlPvPFont or profile.avgIlvlFont or profile.statFont or "Friz Quadrata TT"
    profile.avgIlvlPvPFontSize = tonumber(profile.avgIlvlPvPFontSize) or 10
    profile.avgIlvlPvPOutline = profile.avgIlvlPvPOutline or "OUTLINE"
    profile.avgIlvlPvPColor = profile.avgIlvlPvPColor or CopyColor(ARMORY_PVP_ILVL_COLOR)
    profile.avgIlvlPvPOffsetX = tonumber(profile.avgIlvlPvPOffsetX) or 0
    profile.avgIlvlPvPOffsetY = tonumber(profile.avgIlvlPvPOffsetY) or -2

    PromoteColor(profile, "avgIlvlColor", ARMORY_ILVL_PURPLE, ARMORY_ILVL_PURPLE_LEGACY)
    PromoteColor(profile, "itemLevelColor", ARMORY_ILVL_PURPLE, ARMORY_ILVL_PURPLE_LEGACY)
    PromoteColor(profile, "attrColor", ARMORY_ATTRIBUTE_COLOR, ARMORY_ATTRIBUTE_COLOR_LEGACY)
    PromoteColor(profile, "strengthColor", ARMORY_ATTRIBUTE_COLOR, ARMORY_ATTRIBUTE_COLOR_LEGACY)
    PromoteColor(profile, "agilityColor", ARMORY_ATTRIBUTE_COLOR, ARMORY_ATTRIBUTE_COLOR_LEGACY)
    PromoteColor(profile, "intellectColor", ARMORY_ATTRIBUTE_COLOR, ARMORY_ATTRIBUTE_COLOR_LEGACY)
    PromoteColor(profile, "staminaColor", ARMORY_ATTRIBUTE_COLOR, ARMORY_ATTRIBUTE_COLOR_LEGACY)
    PromoteColor(profile, "enchantColor", ARMORY_ENHANCEMENT_COLOR, ARMORY_ENHANCEMENT_COLOR_LEGACY)
    PromoteColor(profile, "enhColor", ARMORY_ENHANCEMENT_COLOR, ARMORY_ENHANCEMENT_COLOR_LEGACY)
    PromoteColor(profile, "critColor", ARMORY_ENHANCEMENT_COLOR, ARMORY_ENHANCEMENT_COLOR_LEGACY)
    PromoteColor(profile, "hasteColor", ARMORY_ENHANCEMENT_COLOR, ARMORY_ENHANCEMENT_COLOR_LEGACY)
    PromoteColor(profile, "masteryColor", ARMORY_ENHANCEMENT_COLOR, ARMORY_ENHANCEMENT_COLOR_LEGACY)
    PromoteColor(profile, "versatilityColor", ARMORY_ENHANCEMENT_COLOR, ARMORY_ENHANCEMENT_COLOR_LEGACY)
    PromoteColor(profile, "dodgeColor", ARMORY_ENHANCEMENT_COLOR, ARMORY_ENHANCEMENT_COLOR_LEGACY)
    PromoteColor(profile, "parryColor", ARMORY_ENHANCEMENT_COLOR, ARMORY_ENHANCEMENT_COLOR_LEGACY)
    PromoteColor(profile, "blockColor", ARMORY_ENHANCEMENT_COLOR, ARMORY_ENHANCEMENT_COLOR_LEGACY)

    profile.ilvlHeaderColor = CopyColor(ARMORY_HEADER_GOLD)
    profile.attrHeaderColor = CopyColor(ARMORY_HEADER_ATTRIBUTE)
    profile.enhHeaderColor = CopyColor(ARMORY_HEADER_SECONDARY)
end

local function GetUnifiedHeaderColor(profile)
    local color = profile and profile.ilvlHeaderColor or nil
    if type(color) == "table" then
        return color
    end
    return ARMORY_HEADER_GOLD
end

-- Slots de equipamiento
local SLOT_IDS = {
    ["HeadSlot"] = 1, ["NeckSlot"] = 2, ["ShoulderSlot"] = 3, ["ShirtSlot"] = 4, ["ChestSlot"] = 5,
    ["WaistSlot"] = 6, ["LegsSlot"] = 7, ["FeetSlot"] = 8, ["WristSlot"] = 9, ["HandsSlot"] = 10,
    ["Finger0Slot"] = 11, ["Finger1Slot"] = 12, ["Trinket0Slot"] = 13, ["Trinket1Slot"] = 14,
    ["BackSlot"] = 15, ["MainHandSlot"] = 16, ["SecondaryHandSlot"] = 17, ["TabardSlot"] = 19,
}

-- Lista de fondos
local BACKGROUND_LIST = {
    { key = "CLASS",    name = "Class (Automatic)", file = nil },
    { key = "SPACE",    name = "Space / Cosmos",    file = "Space.blp" },
    { key = "CASTLE",   name = "Castle (Alliance)",  file = "Castle.blp" },
    { key = "EMPIRE",   name = "Empire (Horde)",     file = "TheEmpire.blp" },
    { key = "KYRIAN",   name = "Bastion (Kyrian)",    file = "Cov_Kyrian.blp" },
    { key = "NECRO",    name = "Necrolords",        file = "Cov_Necrolords.blp" },
    { key = "NIGHTFAE", name = "Night Fae",  file = "Cov_NightFae.blp" },
    { key = "VENTHYR",  name = "Venthyr",             file = "Cov_Venthyr.blp" },
    { key = "DK",       name = "Death Knight",    file = "DEATHKNIGHT.blp" },
    { key = "HUNTER",   name = "Hunter",             file = "HUNTER.blp" },
    { key = "MAGE",     name = "Mage",                file = "MAGE.blp" },
    { key = "WARRIOR",  name = "Warrior",            file = "WARRIOR.blp" },
    { key = "ROGUE",    name = "Rogue",              file = "ROGUE.blp" },
    { key = "DRUID",    name = "Druid",              file = "DRUID.blp" },
    { key = "SHAMAN",   name = "Shaman",              file = "SHAMAN.blp" },
    { key = "PRIEST",   name = "Priest",           file = "PRIEST.blp" },
    { key = "WARLOCK",  name = "Warlock",               file = "WARLOCK.blp" },
    { key = "PALADIN",  name = "Paladin",             file = "PALADIN.blp" },
    { key = "MONK",     name = "Monk",               file = "MONK.blp" },
    { key = "DH",       name = "Demon Hunter",    file = "DEMONHUNTER.blp" },
    { key = "EVOKER",   name = "Evoker",            file = DEFAULT_BACKGROUND_FILE },
}

local CLASS_BACKGROUND_FILES = {
    DEATHKNIGHT = "DEATHKNIGHT.blp",
    DEMONHUNTER = "DEMONHUNTER.blp",
    DRUID = "DRUID.blp",
    EVOKER = DEFAULT_BACKGROUND_FILE,
    HUNTER = "HUNTER.blp",
    MAGE = "MAGE.blp",
    MONK = "MONK.blp",
    PALADIN = "PALADIN.blp",
    PRIEST = "PRIEST.blp",
    ROGUE = "ROGUE.blp",
    SHAMAN = "SHAMAN.blp",
    WARLOCK = "WARLOCK.blp",
    WARRIOR = "WARRIOR.blp",
}

function AR:OnInitialize()
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if LSM then
        LSM:Register("background", "Blizzard Quest Log", "Interface\\QuestFrame\\UI-QuestLog-Book-BG")
        LSM:Register("background", "KullThran Armory", PANEL_BG)
    end

    if not KT.db.profile.armory then
        KT.db.profile.armory = {
            scale = 1.05,
            showIlvl = true, ilvlSize = 12, ilvlColorByRarity = true, ilvlColor = {r=1, g=1, b=1, a=1},
            ilvlHeaderColor = {r=0.94, g=0.78, b=0.29, a=1},
            showAvgIlvl = true, avgIlvlDecimals = true, avgIlvlColor = {r=0.7568627451, g=0.00, b=1.00, a=1},
            showAvgIlvlPvP = true, avgIlvlPvPShowLabel = true, avgIlvlPvPDecimals = false,
            avgIlvlPvPFont = "Friz Quadrata TT", avgIlvlPvPFontSize = 10, avgIlvlPvPOutline = "OUTLINE",
            avgIlvlPvPColor = {r=0.00, g=0.50, b=1.00, a=1}, avgIlvlPvPOffsetX = 0, avgIlvlPvPOffsetY = -2,
            showEnchant = true, enchantSize = 10, enchantFont = "Friz Quadrata TT", enchantColor = {r=0.00, g=1.00, b=0.6156862745, a=1},
            enchantX = 0, enchantY = 2, avgIlvlFontSize = 20,
            
            -- Opciones de Puntuación M+
            scoreType = "M+",
            scoreFont = "Friz Quadrata TT", scoreSize = 22, scoreOutline = "OUTLINE",

            colorStats = true,
            secondaryStatDisplayMode = "percent",
            statFont = "Friz Quadrata TT", statFontSize = 11,
            statSpacing = 3,
            statsTexture = "KullThran Armory",
            statsColor = {r=0.85, g=0.85, b=0.9, a=1},
            itemLevelColor = {r=0.7568627451, g=0.00, b=1.00, a=1},
            attrColor = {r=1.00, g=0.4823529412, b=0.00, a=1},
            attrHeaderColor = {r=1.00, g=0.64, b=0.00, a=1},
            enhColor = {r=0.00, g=1.00, b=0.6156862745, a=1},
            enhHeaderColor = {r=0.50, g=0.78, b=0.50, a=1},
            strengthColor = {r=1.00, g=0.4823529412, b=0.00, a=1},
            agilityColor = {r=1.00, g=0.4823529412, b=0.00, a=1},
            intellectColor = {r=1.00, g=0.4823529412, b=0.00, a=1},
            staminaColor = {r=1.00, g=0.4823529412, b=0.00, a=1},
            armorColor = {r=0.2, g=0.6588235294, b=0.9019607843, a=1},
            healthColor = {r=1.00, g=0.4823529412, b=0.00, a=1},
            manaColor = {r=1.00, g=0.4823529412, b=0.00, a=1},
            critColor = {r=1.00, g=0.96, b=0.41, a=1},
            hasteColor = {r=1.00, g=0.96, b=0.41, a=1},
            masteryColor = {r=1.00, g=0.96, b=0.41, a=1},
            versatilityColor = {r=1.00, g=0.96, b=0.41, a=1},
            attackPowerColor = {r=1.00, g=0.41, b=0.70, a=1},
            attackSpeedColor = {r=1.00, g=0.41, b=0.70, a=1},
            spellPowerColor = {r=1.00, g=0.41, b=0.70, a=1},
            leechColor = {r=0.9882352941, g=0.6745098039, b=0.6745098039, a=1},
            avoidanceColor = {r=0.9882352941, g=0.6745098039, b=0.6745098039, a=1},
            speedColor = {r=0.9882352941, g=0.6745098039, b=0.6745098039, a=1},
            dodgeColor = {r=0.00, g=0.44, b=0.87, a=1},
            parryColor = {r=0.00, g=0.44, b=0.87, a=1},
            blockColor = {r=0.00, g=0.44, b=0.87, a=1},
            showStrengthLabel = true,
            showAgilityLabel = true,
            showIntellectLabel = true,
            showStaminaLabel = true,
            showArmorLabel = true,
            showCritLabel = true,
            showHasteLabel = true,
            showMasteryLabel = true,
            showVersatilityLabel = true,
            showLeechLabel = true,
            showAvoidanceLabel = true,
            showSpeedLabel = true,
            showDodgeLabel = true,
            showParryLabel = true,
            showBlockLabel = true,
            backgroundType = "CLASS",
            showPortrait = false,
        }
    end
    EnsureArmoryColorDefaults(KT.db.profile.armory)
    self.db = KT.db.profile.armory
    self.db.secondaryStatDisplayMode = self.db.secondaryStatDisplayMode or "percent"
end

function AR:OnEnable()
    if not self.db.enable then return end

    if _G.CharacterFrame then 
        _G.CharacterFrame:SetScale(self.db.scale)

        -- Ocultar textos de Blizzard
        if _G.CharacterFrame.TitleText then 
             _G.CharacterFrame.TitleText:Hide()
             hooksecurefunc(_G.CharacterFrame.TitleText, "Show", function(self) self:Hide() end)
        end
        if _G.CharacterLevelText then 
             _G.CharacterLevelText:Hide()
             hooksecurefunc(_G.CharacterLevelText, "Show", function(self) self:Hide() end)
        end
        if _G.CharacterNameText then _G.CharacterNameText:Hide() end 
        
        -- Ocultar retrato nativo
        if _G.CharacterFramePortrait then
            if not self.db.showPortrait then _G.CharacterFramePortrait:Hide() end
            hooksecurefunc(_G.CharacterFramePortrait, "Show", function(self) 
                if not AR.db.showPortrait then self:Hide() end 
            end)
        end
        
        -- Crear Cabecera Personalizada
        self:CreateHeader()
    end

    self:SecureHook("PaperDollItemSlotButton_Update", "UpdateSlot")
    self:SecureHook("PaperDollFrame_UpdateStats", "UpdateMyStats")

    self:RegisterEvent("UNIT_PORTRAIT_UPDATE", "UpdateHeader") 
    self:RegisterEvent("UNIT_MODEL_CHANGED", "UpdateHeader")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "UpdateHeader")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("ZONE_CHANGED", "UpdateHeader")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateHeader")
    self:RegisterEvent("PLAYER_LEVEL_UP", "UpdateHeader")
    self:RegisterEvent("PLAYER_EQUIPMENT_CHANGED", "RefreshEquippedItems")
    self:RegisterEvent("UNIT_INVENTORY_CHANGED", "RefreshEquippedItems")
    
    self:RegisterEvent('PLAYER_MOUNT_DISPLAY_CHANGED', 'RefreshMovementStats')
    self:RegisterEvent('UNIT_AURA', 'RefreshMovementStats')
    self:CreateStatsPanel() 
    self:CreateConfigButton() 
    self:CreateBackgroundSelector() 
    
    C_Timer.After(0.5, function() self:SafeRefresh() end)
    
    _G.CharacterFrame:HookScript("OnShow", function() 
        C_Timer.After(0.1, function()
            self:SafeRefresh()
        end)
        
        if _G.InspectFrame and _G.InspectFrame:IsShown() then
             _G.CharacterFrame:ClearAllPoints()
             _G.CharacterFrame:SetPoint("TOPLEFT", _G.UIParent, "TOPLEFT", 40, -40)
             _G.InspectFrame:ClearAllPoints()
             _G.InspectFrame:SetPoint("TOPLEFT", _G.CharacterFrame, "TOPRIGHT", 60, 0)
        end
    end)

    hooksecurefunc("PaperDollFrame_SetSidebar", function(self, index)
        if AR.StatsFrame then
            if index == 1 then
                AR.StatsFrame:Show()
            else
                AR.StatsFrame:Hide()
            end
        end
    end)

    if _G.PaperDollFrame then
        _G.PaperDollFrame:HookScript("OnHide", function() if self.StatsFrame then self.StatsFrame:Hide() end end)
    end

    if KT.db and KT.db.RegisterCallback then
        KT.db.RegisterCallback(self, "OnProfileChanged", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileCopied", "Refresh")
        KT.db.RegisterCallback(self, "OnProfileReset", "Refresh")
    end
end

local function FormatArmoryNumber(value)
    local numeric = SafeArmoryNumber(value)
    if not numeric then
        return "—"
    end

    numeric = math.floor(numeric + 0.5)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(numeric)
    end
    return tostring(numeric)
end

local function SanitizeArmoryTooltip(text, replacement)
    if type(text) ~= "string" then return "" end
    local percentToken = "\001"
    text = text:gsub("%%%%", percentToken)
    text = text:gsub("%%[%d%$%.%-%+]*[cdeEfgGiouXxsq]", tostring(replacement or ""))
    text = text:gsub(percentToken, "%%")
    text = text:gsub("%s+([%.,])", "%1"):gsub("%s%s+", " ")
    return text:gsub("^%s+", ""):gsub("%s+$", "")
end

local function BuildSecondaryStatEntry(displayMode, label, percentValue, ratingValue, color, tooltip, numericValueOverride)
    local safePercent = SafeArmoryNumber(percentValue) or 0
    local safeRating = SafeArmoryNumber(ratingValue)
    local percentText = string.format("%.2f%%", safePercent)
    local safeNumeric = numericValueOverride ~= nil and SafeArmoryNumber(numericValueOverride) or safeRating
    local numericText = safeNumeric and safeNumeric > 0 and FormatArmoryNumber(safeNumeric) or "0"

    local formatMode = "BOTH"
    local kt = _G.LibStub and _G.LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
    if kt then
        local ar = kt:GetModule("Armory", true)
        if ar and ar.db and ar.db.profile and ar.db.profile.statFormatMode then
            formatMode = ar.db.profile.statFormatMode
        end
    end

    local displayValue
    if formatMode == "PERCENT" then
        displayValue = percentText
    elseif formatMode == "NUMERIC" then
        displayValue = numericText
    else
        displayValue = string.format("%s (%s)", numericText, percentText)
    end

    return {
        label = label,
        value = displayValue,
        color = color,
        tooltip = tooltip
    }
end

local STAT_LABEL_SETTING_KEYS = {
    strength = "showStrengthLabel",
    agility = "showAgilityLabel",
    intellect = "showIntellectLabel",
    stamina = "showStaminaLabel",
    armor = "showArmorLabel",
    crit = "showCritLabel",
    haste = "showHasteLabel",
    mastery = "showMasteryLabel",
    versatility = "showVersatilityLabel",
    leech = "showLeechLabel",
    avoidance = "showAvoidanceLabel",
    speed = "showSpeedLabel",
    dodge = "showDodgeLabel",
    parry = "showParryLabel",
    block = "showBlockLabel",
}

function AR:IsStatLabelVisible(statKey)
    if not statKey then
        return true
    end

    local settingKey = STAT_LABEL_SETTING_KEYS[statKey]
    if not settingKey then
        return true
    end

    return self.db[settingKey] ~= false
end

function AR:ApplyStatsPanelTheme()
    if not self.StatsFrame then return end

    if KT and KT.ApplyTexturedSurface then
        KT:ApplyTexturedSurface(self.StatsFrame)
        if self.StatsFrame.Background then
            self.StatsFrame.Background:SetAlpha(0)
        end
        self.StatsFrame.BackgroundBase:SetAlpha(0)
    else
        self.StatsFrame.BackgroundBase:SetColorTexture(0, 0, 0, 0.96)
        ApplyArmoryPanelTexture(self.StatsFrame.Background)
        LayoutArmoryPanelTexture(self.StatsFrame.Background, self.StatsFrame)
    end
    
    self.StatsFrame.GradientFill:SetColorTexture(0, 0, 0, 0)
    self.StatsFrame.GradientShade:SetColorTexture(0, 0, 0, 0)
    self.StatsFrame.TopGlow:SetColorTexture(0, 0, 0, 0)
    self.StatsFrame.LeftGlow:SetColorTexture(0, 0, 0, 0)
    self.StatsFrame.BottomLine:SetColorTexture(0, 0, 0, 0)
end

-- ============================================================================
-- CABECERA PERSONALIZADA (HEADER & AURA)
-- ============================================================================
function AR:CreateHeader()
    if self.Header then return end
    
    -- Marco contenedor
    local h = CreateFrame("Frame", "KT_ArmoryHeader", _G.PaperDollFrame)
    h:SetSize(380, 80)
    h:SetPoint("TOPLEFT", _G.CharacterFrame, "TOPLEFT", 0, 0) 
    h:SetFrameStrata("HIGH")
    h:SetFrameLevel(_G.PaperDollFrame:GetFrameLevel() + 10) 
    
    -- 1. ICONO DE CLASE (Siempre visible)
    h.ClassIcon = h:CreateTexture(nil, "OVERLAY", nil, 7)
    h.ClassIcon:SetSize(60, 60)
    h.ClassIcon:SetPoint("TOPLEFT", -5, 9) 
    
    -- Mascara circular para icono de clase
    local mask = h:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetAllPoints(h.ClassIcon)
    h.ClassIcon:AddMaskTexture(mask)

    -- Marco secundario para Info (Nombre, Nivel, M+)
    local info = CreateFrame("Frame", "KT_ArmoryInfo", _G.PaperDollFrame or _G.CharacterFrame)
    info:SetSize(380, 80)
    info:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 0)
    info:SetFrameStrata("HIGH")
    info:SetFrameLevel(h:GetFrameLevel() + 1)
    h.InfoFrame = info

    -- 2. NOMBRE (En InfoFrame)
    h.Name = info:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    h.Name:SetPoint("TOPLEFT", h.ClassIcon, "TOPRIGHT", 10, -24) 
    h.Name:SetJustifyH("LEFT")
    h.Name:SetWordWrap(false)

    -- 3. NIVEL (En InfoFrame)
    h.Level = info:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    h.Level:SetPoint("TOPLEFT", h.Name, "BOTTOMLEFT", 0, -1)

    -- 4. ICONO DE SPEC (En InfoFrame)
    h.SpecIcon = info:CreateTexture(nil, "OVERLAY", nil, 7)
    h.SpecIcon:SetSize(20, 20) 
    h.SpecIcon:SetPoint("LEFT", h.Name, "RIGHT", 5, 1)
    
    local specMask = info:CreateMaskTexture()
    specMask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    specMask:SetAllPoints(h.SpecIcon)
    h.SpecIcon:AddMaskTexture(specMask)
    
    -- 5. PUNTUACION M+ (En InfoFrame)
    h.Score = info:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    h.Score:SetPoint("TOP", _G.CharacterFrame, "TOP", 37, -24) 
    h.Score:SetJustifyH("CENTER")
    
    h.ScoreLabel = info:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    h.ScoreLabel:SetText(LText("M+"))
    h.ScoreLabel:SetTextColor(0.7, 0.7, 0.7)
    h.ScoreLabel:SetPoint("RIGHT", h.Score, "LEFT", -2, 0)
    h.ScoreLabel:SetJustifyH("RIGHT")

    self.Header = h
    self:UpdateHeader()
end

function AR:OpenOptionsPage()
    if KT and KT.OpenRegisteredPage then
        KT:OpenRegisteredPage("armory", true)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if KT and KT.OpenRegisteredPage then
                    KT:OpenRegisteredPage("armory", true)
                end
            end)
        end
    elseif KT and KT.OpenMenu then
        KT:OpenMenu("armory")
    end
end

function AR:SafeRefresh()
    local ok, err = pcall(function()
        self:Refresh()
    end)
    if not ok and KT and KT.Print then
        KT:Print("Armory refresh error: " .. tostring(err))
    end
end

function AR:RefreshEquippedItems(_, unit)
    if unit and unit ~= "player" then return end
    if self._equipmentRefreshQueued then return end
    self._equipmentRefreshQueued = true
    C_Timer.After(0.05, function()
        self._equipmentRefreshQueued = nil
        if self and self.SafeRefresh then self:SafeRefresh() end
    end)
end

function AR:RefreshMovementStats(_, unit)
    if unit and unit ~= 'player' then return end
    if _G.CharacterFrame and not _G.CharacterFrame:IsShown() then return end
    if self._movementRefreshQueued then return end

    self._movementRefreshQueued = true
    C_Timer.After(0.05, function()
        self._movementRefreshQueued = nil
        if self and self.SafeRefresh then
            self:SafeRefresh()
        end
    end)
end

function AR:UpdateHeader()
    if not self.Header then return end
    local LSM = LibStub("LibSharedMedia-3.0", true)
    
    -- A. AURA (CLASE)
    local _, class = UnitClass("player")
    if class and _G.CLASS_ICON_TCOORDS[class] then
        self.Header.ClassIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        self.Header.ClassIcon:SetTexCoord(unpack(_G.CLASS_ICON_TCOORDS[class]))
        self.Header.ClassIcon:SetAlpha(1)
        self.Header.ClassIcon:Show()
    end

    -- B. NOMBRE Y CLASE TEXTO
    local name = UnitName("player")
    local classColor = C_ClassColor.GetClassColor(class)
    
    local nameFont = SafeFont(self.db.charNameFont, STANDARD_TEXT_FONT)
    self.Header.Name:SetFont(nameFont, self.db.charNameSize or 16, self.db.charNameOutline or "OUTLINE")
    self.Header.Name:SetText(name)
    if classColor then
        self.Header.Name:SetTextColor(classColor.r, classColor.g, classColor.b)
    else
        self.Header.Name:SetTextColor(1, 1, 1)
    end
    
    -- C. NIVEL
    local levelFont = (self.db.charLevelFont and SafeFont(self.db.charLevelFont, "GameFontHighlight")) or "GameFontHighlight"
    self.Header.Level:SetFont(levelFont, self.db.charLevelSize or 12, self.db.charLevelOutline or "OUTLINE")
    local level = UnitLevel("player")
    self.Header.Level:SetText(LText("Level ") .. level)

    -- D. ICONO SPEC
    local currentSpec = GetSpecialization()
    if currentSpec then
        local _, _, _, icon = GetSpecializationInfo(currentSpec)
        if icon then
            self.Header.SpecIcon:SetTexture(icon)
            self.Header.SpecIcon:SetAlpha(1)
            self.Header.SpecIcon:Show()
        end
    else
        self.Header.SpecIcon:Hide()
    end
    
    -- E. SCORE (M+ / PVP)
    local scoreType = self.db.scoreType or "M+"
    local score = 0
    local labelText = LText("M+")
    local color = {r=1, g=1, b=1}

    if scoreType == "M+" then
        score = C_ChallengeMode.GetOverallDungeonScore()
        labelText = LText("M+")
        color = C_ChallengeMode.GetDungeonScoreRarityColor(score) or {r=1, g=1, b=1}
    elseif scoreType == "PVP" then
        labelText = "PvP"
        local maxRating = 0
        
        -- Check 2v2, 3v3, RBG
        for _, bracket in pairs({1, 2, 4}) do
            local rating = select(1, GetPersonalRatedInfo(bracket))
            if rating and rating > maxRating then maxRating = rating end
        end
        
        -- Check Solo Shuffle
        if C_PvP and C_PvP.GetSoloShufflePersonalRatedInfo then
            local shuffleRating = C_PvP.GetSoloShufflePersonalRatedInfo()
            if shuffleRating and shuffleRating > maxRating then maxRating = shuffleRating end
        end
        
        score = maxRating
        
        -- Colors based on rating thresholds
        if score >= 2400 then color = {r=1, g=0.5, b=0} -- Elite
        elseif score >= 2100 then color = {r=0.6, g=0.2, b=0.8} -- Duelist
        elseif score >= 1800 then color = {r=0, g=0.44, b=0.87} -- Rival
        elseif score >= 1600 then color = {r=0, g=0.8, b=0} -- Challenger
        elseif score >= 1400 then color = {r=0.8, g=0.8, b=0} -- Combatant
        else color = {r=0.5, g=0.5, b=0.5} end
    end
    
    local scoreFont = SafeFont(self.db.scoreFont, STANDARD_TEXT_FONT)
    local scoreSize = self.db.scoreSize or 22
    local scoreOutline = self.db.scoreOutline or "OUTLINE"
    
    self.Header.Score:SetFont(scoreFont, scoreSize, scoreOutline)
    self.Header.ScoreLabel:SetFont(scoreFont, scoreSize, scoreOutline)
    self.Header.ScoreLabel:SetText(labelText)

    if score and score > 0 then
        self.Header.Score:SetText(score)
        self.Header.Score:SetTextColor(color.r, color.g, color.b)
        self.Header.ScoreLabel:Show()
    else
        self.Header.Score:SetText("")
        self.Header.ScoreLabel:Hide()
    end
    
    if self.db.showPortrait and _G.CharacterFramePortrait then
        SetPortraitTexture(_G.CharacterFramePortrait, "player")
    end
end

-- ============================================================================
-- BACKGROUND SELECTOR
-- ============================================================================

function AR:CreateBackgroundSelector()
    local modelScene = _G.CharacterModelScene
    if modelScene and not modelScene.KT_Armory_BG then
        modelScene.KT_Armory_BG = modelScene:CreateTexture(nil, "ARTWORK")
        modelScene.KT_Armory_BG:SetDrawLayer("ARTWORK", -8)
        modelScene.KT_Armory_BG:SetAllPoints(modelScene)
        
        if modelScene.BackgroundOverlay then modelScene.BackgroundOverlay:SetAlpha(0) end
        modelScene:HookScript("OnShow", function() self:UpdateBackground() end)
    end

    if modelScene then
        local btn = CreateFrame("Button", "KT_ArmoryBGSelector", modelScene)
        btn:SetSize(20, 20)
        if _G.CharacterTabardSlot then
            btn:SetPoint("LEFT", _G.CharacterTabardSlot, "RIGHT", 6, 0)
        else
            btn:SetPoint("TOPRIGHT", modelScene, "TOPRIGHT", -5, -5)
        end
        btn:SetNormalTexture("Interface\\Icons\\INV_Misc_Map02")
        btn:GetNormalTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
        btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        
        btn:SetScript("OnClick", function(self)
            if not MenuUtil then return end 
            MenuUtil.CreateContextMenu(self, function(owner, root)
                root:CreateTitle("Select Background")
                for _, data in ipairs(BACKGROUND_LIST) do
                    root:CreateCheckbox(data.name, 
                        function() return AR.db.backgroundType == data.key end, 
                        function() AR.db.backgroundType = data.key; AR:UpdateBackground() end
                    )
                end
            end)
        end)
    end
end

function AR:UpdateBackground()
    local modelScene = _G.CharacterModelScene
    local bg = modelScene and modelScene.KT_Armory_BG
    local type = self.db.backgroundType or "CLASS"
    local filename = nil

    if type == "CLASS" then
        local _, classFilename = UnitClass("player")
        filename = CLASS_BACKGROUND_FILES[classFilename]
    else
        for _, d in ipairs(BACKGROUND_LIST) do
            if d.key == type then filename = d.file break end
        end
    end

    filename = filename or DEFAULT_BACKGROUND_FILE

    if bg then
        bg:SetTexture(TEXTURE_PATH .. filename)
        bg:SetTexCoord(0, 1, 0, 1)
        bg:SetVertexColor(1, 1, 1, 1)
        bg:Show()
        if modelScene.BackgroundOverlay then modelScene.BackgroundOverlay:SetAlpha(0) end
    end
end

function AR:PLAYER_ENTERING_WORLD()
    self:Refresh()
end

-- ============================================================================
-- SLOTS UPDATE
-- ============================================================================

local function CreateSlotQualityBorder(button)
    local border = CreateFrame("Frame", nil, button)
    border:SetAllPoints(button)
    border:SetFrameLevel(button:GetFrameLevel() + 8)
    border:EnableMouse(false)
    border.edges = {}

    for index = 1, 4 do
        border.edges[index] = border:CreateTexture(nil, "OVERLAY", nil, 7)
    end

    border.edges[1]:SetPoint("TOPLEFT")
    border.edges[1]:SetPoint("TOPRIGHT")
    border.edges[1]:SetHeight(2)
    border.edges[2]:SetPoint("BOTTOMLEFT")
    border.edges[2]:SetPoint("BOTTOMRIGHT")
    border.edges[2]:SetHeight(2)
    border.edges[3]:SetPoint("TOPLEFT")
    border.edges[3]:SetPoint("BOTTOMLEFT")
    border.edges[3]:SetWidth(2)
    border.edges[4]:SetPoint("TOPRIGHT")
    border.edges[4]:SetPoint("BOTTOMRIGHT")
    border.edges[4]:SetWidth(2)

    button.ktQualityBorder = border
    return border
end

local function UpdateSlotQualityBorder(button, slotID, itemLink)
    if not itemLink then
        if button.backdrop and button.backdrop.SetBackdropBorderColor then
            button.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
        if button.ktQualityBorder then
            button.ktQualityBorder:Hide()
        end
        return nil
    end

    local quality = GetInventoryItemQuality and GetInventoryItemQuality("player", slotID)
    if quality == nil and C_Item.GetItemQualityByID then
        quality = C_Item.GetItemQualityByID(itemLink)
    end
    if quality == nil then
        local _, _, cachedQuality = GetItemInfo(itemLink)
        quality = cachedQuality
    end
    if quality == nil then
        if button.ktQualityBorder then
            button.ktQualityBorder:Hide()
        end
        return nil
    end

    local r, g, b = C_Item.GetItemQualityColor(quality)
    local border = button.ktQualityBorder or CreateSlotQualityBorder(button)
    local borderTarget = button.backdrop or button
    border:ClearAllPoints()
    border:SetAllPoints(borderTarget)
    if button.backdrop and button.backdrop.SetBackdropBorderColor then
        button.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
    end
    for index = 1, 4 do
        border.edges[index]:SetColorTexture(r, g, b, 1)
    end
    border:Show()

    return quality
end

function AR:UpdateSlot(button)
    -- Skip hidden character-frame refreshes. The enchant tooltip scan is
    -- expensive and the overlays are refreshed again when the panel opens.
    if (_G.CharacterFrame and not _G.CharacterFrame:IsShown()) then return end

    local slotID = button:GetID()
    local isEquipSlot = false
    for _, id in pairs(SLOT_IDS) do if id == slotID then isEquipSlot = true break end end
    if not isEquipSlot then return end

    if not button.ktIlvl then
        button.ktIlvl = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        button.ktIlvl:SetPoint("TOPLEFT", 2, -2)
    end
    if not button.ktEnchant then
        button.ktEnchant = button:CreateFontString(nil, "OVERLAY", "SystemFont_Tiny")
    end
    
    button.ktEnchant:ClearAllPoints()
    local isRight = (slotID == 6 or slotID == 7 or slotID == 8 or slotID == 10 or slotID == 11 or slotID == 12 or slotID == 13 or slotID == 14 or slotID == 16)
    
    if isRight then
        button.ktEnchant:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", (self.db.enchantX or 0), (self.db.enchantY or 2))
        button.ktEnchant:SetJustifyH("RIGHT")
    else
        button.ktEnchant:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", (self.db.enchantX or 0), (self.db.enchantY or 2))
        button.ktEnchant:SetJustifyH("LEFT")
    end

    local link = GetInventoryItemLink("player", slotID)
    local quality = UpdateSlotQualityBorder(button, slotID, link)
    if not link then
        button.ktIlvl:SetText(""); button.ktEnchant:SetText(""); 
        button.ktIlvl:Hide(); button.ktEnchant:Hide(); 
        return
    end

    -- 1. ITEM LEVEL
    if self.db.showIlvl then
        local effectiveILvl = 0
        local itemLoc = ItemLocation:CreateFromEquipmentSlot(slotID)
        
        if C_Item.DoesItemExist(itemLoc) then
            effectiveILvl = C_Item.GetCurrentItemLevel(itemLoc)
        end
        
        if not effectiveILvl or effectiveILvl == 0 then effectiveILvl = C_Item.GetDetailedItemLevelInfo(link) end
        
        local LSM = LibStub("LibSharedMedia-3.0", true)
        local font = STANDARD_TEXT_FONT
        if self.db.ilvlFont then font = SafeFont(self.db.ilvlFont, STANDARD_TEXT_FONT) end
        button.ktIlvl:SetFont(font, self.db.ilvlSize or 12, self.db.ilvlOutline or "OUTLINE")
        button.ktIlvl:SetText(effectiveILvl or "")
        button.ktIlvl:Show()
        
        if self.db.ilvlColorByRarity and quality then
            local r, g, b = C_Item.GetItemQualityColor(quality)
            button.ktIlvl:SetTextColor(r, g, b)
        else
            local c = self.db.ilvlColor
            button.ktIlvl:SetTextColor(c.r, c.g, c.b)
        end
    else
        button.ktIlvl:Hide()
    end

    -- 2. ENCHANTS
    if self.db.showEnchant then
        local enchantText, enchantIcon = self:GetEnchantText(link)
        local LSM = LibStub("LibSharedMedia-3.0", true)
        local font = STANDARD_TEXT_FONT
        if self.db.enchantFont then font = SafeFont(self.db.enchantFont, STANDARD_TEXT_FONT) end
        
        button.ktEnchant:SetFont(font, self.db.enchantSize or 10, "OUTLINE")
        if enchantText then
            if string.len(enchantText) > 18 then enchantText = string.sub(enchantText, 1, 15).."..." end
            if enchantIcon then
                enchantText = enchantText.." "..enchantIcon
            end
            button.ktEnchant:SetText(enchantText)
            local c = self.db.enchantColor
            button.ktEnchant:SetTextColor(c.r, c.g, c.b)
            button.ktEnchant:Show()
        else
            button.ktEnchant:Hide()
        end
    else
        button.ktEnchant:Hide()
    end
end

function AR:GetEnchantText(itemLink)
    if not itemLink then return nil end
    local enchantID = tonumber(string.match(itemLink, "item:%d+:(%d+):"))
    if not enchantID or enchantID == 0 then return nil end

    local data = C_TooltipInfo.GetHyperlink(itemLink)
    if (issecretvalue and issecretvalue(data))
        or (canaccessvalue and not canaccessvalue(data))
        or type(data) ~= "table" then return nil end
    local lines = data.lines
    if (issecretvalue and issecretvalue(lines))
        or (canaccessvalue and not canaccessvalue(lines))
        or type(lines) ~= "table" then return nil end
    
    local pattern = _G.ENCHANTED_TOOLTIP_LINE:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
    pattern = pattern:gsub("%%%%s", "(.+)")

    for _, line in ipairs(lines) do
        local lineAccessible = not (issecretvalue and issecretvalue(line))
            and (not canaccessvalue or canaccessvalue(line))
        local text = lineAccessible and type(line) == "table" and line.leftText or nil
        if text and not (issecretvalue and issecretvalue(text))
            and (not canaccessvalue or canaccessvalue(text)) then
            local icon = text:match(ENCHANT_QUALITY_ICON_PATTERN)
            local cleanText = text
                :gsub("|c%x%x%x%x%x%x%x%x", "")
                :gsub("|r", "")
                :gsub("|T.-|t", "")
                :gsub(ENCHANT_QUALITY_ICON_PATTERN, "")
            local enchant = cleanText:match(pattern)
            if enchant then
                enchant = enchant:gsub("^%s+", ""):gsub("%s+$", "")
                return enchant, icon
            end
        end
    end
    return nil
end

-- ============================================================================
-- STATS PANEL
-- ============================================================================

local function GetIcon(spellID)
    local icon
    local success, result = pcall(function()
        if C_Spell and C_Spell.GetSpellTexture then
            return C_Spell.GetSpellTexture(spellID)
        elseif C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            return info and info.iconID
        elseif GetSpellTexture then
            return GetSpellTexture(spellID)
        elseif GetSpellInfo then
            local _, _, tex = GetSpellInfo(spellID)
            return tex
        end
    end)
    if success and result then
        icon = result
    end
    
    if icon then
        return string.format("|T%s:14:14:0:0:64:64:5:59:5:59|t ", icon)
    end
    -- Fallback to default icons if API fails
    return ""
end

local ICONS = {
    -- Secondary
    Crit = GetIcon(143610),
    Haste = GetIcon(143618),
    Mastery = "|TInterface\\Icons\\spell_arcane_prismaticcloak:14:14:0:0:64:64:5:59:5:59|t ",
    Versatility = GetIcon(143622),

    -- Attributes
    Strength = "|T132401:14:14:0:0:64:64:5:59:5:59|t ",
    Agility = "|T135133:14:14:0:0:64:64:5:59:5:59|t ",
    Intellect = "|TInterface\\Icons\\spell_holy_magicalsentry:14:14:0:0:64:64:5:59:5:59|t ",
    Stamina = "|T1386545:14:14:0:0:64:64:5:59:5:59|t ",
    Health = GetIcon(6940),
    Mana = GetIcon(158338),
    GCD = "|TInterface\\Icons\\inv_misc_pocketwatch_01:14:14:0:0:64:64:5:59:5:59|t ",

    -- Attack
    AttackPower = GetIcon(100),
    AttackSpeed = "|T1717022:14:14:0:0:64:64:5:59:5:59|t ",
    SpellPower = GetIcon(384452),

    -- Defense
    Armor = GetIcon(74001),
    Dodge = GetIcon(34481),
    Parry = GetIcon(3127),
    Block = "|TInterface\\Icons\\inv_shield_1h_alliance_d_02:14:14:0:0:64:64:5:59:5:59|t ",

    -- General
    Leech = "|T136211:14:14:0:0:64:64:5:59:5:59|t ",
    Avoidance = "|T458725:14:14:0:0:64:64:5:59:5:59|t ",
    Speed = "|TInterface\\Icons\\ability_rogue_sprint:14:14:0:0:64:64:5:59:5:59|t ",
}

local function BuildSecondaryStatEntry(displayMode, label, percentValue, ratingValue, color, tooltip, numericValueOverride)
    local safePercent = SafeArmoryNumber(percentValue) or 0
    local safeRating = SafeArmoryNumber(ratingValue)
    local percentText = string.format("%.2f%%", safePercent)
    local safeNumeric = numericValueOverride ~= nil and SafeArmoryNumber(numericValueOverride) or safeRating
    local numericText = safeNumeric and safeNumeric > 0 and FormatArmoryNumber(safeNumeric) or "0"

    local formatMode = "BOTH"
    local kt = _G.LibStub and _G.LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
    if kt then
        local ar = kt:GetModule("Armory", true)
        if ar and ar.db and ar.db.profile and ar.db.profile.statFormatMode then
            formatMode = ar.db.profile.statFormatMode
        end
    end

    local displayValue
    if formatMode == "PERCENT" then
        displayValue = percentText
    elseif formatMode == "NUMERIC" then
        displayValue = numericText
    else
        displayValue = string.format("%s (%s)", numericText, percentText)
    end

    return {
        label = label,
        value = displayValue,
        color = color,
        tooltip = tooltip
    }
end

function AR:CreateStatsPanel()
    if self.StatsFrame then return end
    
    if _G.CharacterStatsPane then
        _G.CharacterStatsPane:Hide()
        _G.CharacterStatsPane:SetParent(UIFrameHider)
        hooksecurefunc(_G.CharacterStatsPane, "Show", function(self) self:Hide() end)
    end
    
    local parent = _G.CharacterFrameInsetRight
    
    if _G.CharacterFrame and _G.CharacterFrameInsetRight then
        local w = _G.CharacterFrame:GetWidth()
        if w and w < 700 then
            _G.CharacterFrame:SetWidth(w + 82)
            _G.CharacterFrameInsetRight:SetWidth(280)
        end
    end

    local f = CreateFrame("Frame", "KT_ArmoryStats", parent)
    f:SetAllPoints()
    
    f.BackgroundBase = f:CreateTexture(nil, "BACKGROUND")
    f.BackgroundBase:SetAllPoints()
    f.BackgroundBase:SetColorTexture(0, 0, 0, 1)

    f:HookScript("OnSizeChanged", function(frame)
        if frame.Background then LayoutArmoryPanelTexture(frame.Background, frame) end
    end)

    f.GradientFill = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    f.GradientFill:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.GradientFill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

    f.GradientShade = f:CreateTexture(nil, "BACKGROUND", nil, 3)
    f.GradientShade:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.GradientShade:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

    f.TopGlow = f:CreateTexture(nil, "BACKGROUND", nil, 4)
    f.TopGlow:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.TopGlow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)

    f.LeftGlow = f:CreateTexture(nil, "BACKGROUND", nil, 5)
    f.LeftGlow:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    f.LeftGlow:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)

    f.BottomLine = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.BottomLine:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
    f.BottomLine:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    f.BottomLine:SetHeight(1)
    
    f.ScrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.ScrollFrame:SetPoint("TOPLEFT", 10, -10)
    f.ScrollFrame:SetPoint("BOTTOMRIGHT", -20, 10)
    
    if f.ScrollFrame.ScrollBar then
        local sb = f.ScrollFrame.ScrollBar
        sb:ClearAllPoints()
        sb:SetPoint("TOPLEFT", f.ScrollFrame, "TOPRIGHT", 2, -16)
        sb:SetPoint("BOTTOMLEFT", f.ScrollFrame, "BOTTOMRIGHT", 2, 16)
        
        if sb.ScrollUpButton then sb.ScrollUpButton:Hide() end
        if sb.ScrollDownButton then sb.ScrollDownButton:Hide() end
        if sb.Top then sb.Top:Hide() end
        if sb.Bottom then sb.Bottom:Hide() end
        if sb.Middle then sb.Middle:Hide() end
        if sb.Background then sb.Background:Hide() end
        
        local track = sb:CreateTexture(nil, "BACKGROUND")
        track:SetPoint("TOP", sb, "TOP", 0, 16)
        track:SetPoint("BOTTOM", sb, "BOTTOM", 0, -16)
        track:SetWidth(4)
        track:SetColorTexture(0, 0, 0, 0.4)
        
        local thumb = sb:GetThumbTexture()
        if thumb then
            thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
            if KT and KT.GetStyleAccentRGB then
                local r, g, b = KT:GetStyleAccentRGB()
                thumb:SetVertexColor(r, g, b, 1)
            else
                thumb:SetVertexColor(0.8, 0.8, 0.8, 1)
            end
            thumb:SetWidth(4)
        end
    end
    
    f.ScrollChild = CreateFrame("Frame", nil, f.ScrollFrame)
    f.ScrollChild:SetSize(250, 1)
    f.ScrollFrame:SetScrollChild(f.ScrollChild)
    f.ScrollFrame:HookScript("OnSizeChanged", function(self, width, height)
        if width > 0 then
            f.ScrollChild:SetWidth(width)
        end
    end)

    f.IlvlTitle = f.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.IlvlTitle:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    f.IlvlTitle:SetPoint("TOP", f.ScrollChild, "TOP", 0, -12)
    f.IlvlTitle:SetJustifyH("CENTER")
    f.IlvlTitle:Hide() -- Hide the 'Item Level' text itself as the user just wants the number
    f.IlvlTitle:SetText(LText("Item Level"))
    
    f.IlvlTitle:ClearAllPoints()
    f.IlvlTitle:SetPoint("TOP", f.ScrollChild, "TOP", 0, -11)
    f.IlvlTitle:SetJustifyH("CENTER")
    
    f.IlvlSepLeft = f.ScrollChild:CreateTexture(nil, "ARTWORK")
    f.IlvlSepLeft:SetSize(80, 8)
    f.IlvlSepLeft:SetPoint("RIGHT", f.IlvlTitle, "LEFT", -5, 1)
    f.IlvlSepLeft:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\separator_armory.png")
    f.IlvlSepLeft:SetTexCoord(1, 0, 0, 1)
    f.IlvlSepLeft:Hide()
    
    f.IlvlSepRight = f.ScrollChild:CreateTexture(nil, "ARTWORK")
    f.IlvlSepRight:SetSize(80, 8)
    f.IlvlSepRight:SetPoint("LEFT", f.IlvlTitle, "RIGHT", 5, 1)
    f.IlvlSepRight:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\separator_armory.png")
    f.IlvlSepRight:SetTexCoord(0, 1, 0, 1)
    f.IlvlSepRight:Hide()
    
    -- Keep Item Level centered directly under its title.
    f.Ilvl = f.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.Ilvl:SetPoint("TOP", f.IlvlTitle, "BOTTOM", 0, -4)
    f.Ilvl:SetJustifyH("CENTER")
    
    f.IlvlPvP = f.ScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.IlvlPvP:SetPoint("TOP", f.Ilvl, "BOTTOM", 0, -2)
    f.IlvlPvP:SetJustifyH("CENTER")
    f.IlvlPvP:SetFont(SafeFont(KT and KT.DEFAULT_FONT_NAME), 10, "OUTLINE")
    
    f.Stats = {}
    self.StatsFrame = f

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, delta)
        if IsControlKeyDown() then
            local newScale = (AR.db.scale or 1) + (delta * 0.05)
            if newScale < 0.6 then newScale = 0.6 end
            if newScale > 1.6 then newScale = 1.6 end
            AR.db.scale = newScale
            if _G.CharacterFrame then _G.CharacterFrame:SetScale(newScale) end
        end
    end)

    if _G.CharacterStatsPane then
        self:SecureHook(_G.CharacterStatsPane, "Show", function() 
            if self.StatsFrame and _G.PaperDollFrame:IsShown() then self.StatsFrame:Show() end 
        end)
        self:SecureHook(_G.CharacterStatsPane, "Hide", function() 
            if self.StatsFrame then self.StatsFrame:Hide() end 
        end)
    end

    self:ApplyStatsPanelTheme()
end

function AR:UpdateMyStats()
    -- PaperDollFrame_UpdateStats also runs while the character panel is
    -- hidden; do not rebuild the complete stats list in that path.

    if not self.StatsFrame then return end
    if (self.StatsFrame.IsShown and not self.StatsFrame:IsShown()) then return end
    
    local LSM = LibStub("LibSharedMedia-3.0", true)
    local font = SafeFont(self.db.statFont, STANDARD_TEXT_FONT)
    local size = self.db.statFontSize or 11
    
    local headerFontName = self.db.headerFont or "Friz Quadrata TT"
    local headerFont = SafeFont(headerFontName, STANDARD_TEXT_FONT)
    local headerOutline = self.db.headerOutline or "OUTLINE"
    local headerSize = size + 2
    
    self:ApplyStatsPanelTheme()

    if self.db.showAvgIlvl then
        local avg, avgEquipped, avgPvp = SafeArmoryNumberCall(GetAverageItemLevel)
        local ilvlText = ""
        if avg and avgEquipped and self.db.avgIlvlDecimals then
            ilvlText = string.format("%.1f / %.1f", avgEquipped, avg)
        elseif avg and avgEquipped then
            ilvlText = string.format("%d / %d", math.floor(avgEquipped), math.floor(avg))
        end
        self.StatsFrame.Ilvl:SetText(ilvlText)
        
        if avgPvp and avgPvp > 0 and self.db.showAvgIlvlPvP ~= false then
            local pvpValue = self.db.avgIlvlPvPDecimals and string.format("%.1f", avgPvp) or tostring(math.floor(avgPvp))
            local pvpText = self.db.avgIlvlPvPShowLabel == false and pvpValue or ("PvP: " .. pvpValue)
            local pvpFontName = self.db.avgIlvlPvPFont or self.db.avgIlvlFont or self.db.statFont
            local pvpFont = SafeFont(pvpFontName, STANDARD_TEXT_FONT)
            local pvpColor = self.db.avgIlvlPvPColor or ARMORY_PVP_ILVL_COLOR

            self.StatsFrame.IlvlPvP:ClearAllPoints()
            self.StatsFrame.IlvlPvP:SetPoint("TOP", self.StatsFrame.Ilvl, "BOTTOM", tonumber(self.db.avgIlvlPvPOffsetX) or 0, tonumber(self.db.avgIlvlPvPOffsetY) or -2)
            self.StatsFrame.IlvlPvP:SetFont(pvpFont, tonumber(self.db.avgIlvlPvPFontSize) or 10, self.db.avgIlvlPvPOutline or "OUTLINE")
            self.StatsFrame.IlvlPvP:SetText(pvpText)
            self.StatsFrame.IlvlPvP:SetTextColor(pvpColor.r or 0, pvpColor.g or 0.5, pvpColor.b or 1, pvpColor.a or 1)
            self.StatsFrame.IlvlPvP:Show()
        else
            if self.StatsFrame.IlvlPvP then self.StatsFrame.IlvlPvP:Hide() end
        end
        
        local ilvlSize = self.db.avgIlvlFontSize or 20
        local ilvlColor = self.db.avgIlvlColor or self.db.itemLevelColor or ARMORY_ILVL_PURPLE
        local ilvlFont = SafeFont(self.db.avgIlvlFont, font)
        local ilvlOutline = self.db.avgIlvlOutline or "OUTLINE"
        
        self.StatsFrame.Ilvl:SetFont(ilvlFont, ilvlSize, ilvlOutline)
        self.StatsFrame.Ilvl:SetJustifyH("CENTER")
        self.StatsFrame.Ilvl:SetTextColor(ilvlColor.r, ilvlColor.g, ilvlColor.b)
        self.StatsFrame.Ilvl:Show()
        
        if self.db.ilvlHeaderColor then
            local c = self.db.ilvlHeaderColor
            self.StatsFrame.IlvlTitle:SetTextColor(c.r, c.g, c.b)
            self.StatsFrame.IlvlSepRight:SetVertexColor(c.r, c.g, c.b, 1)
            if self.StatsFrame.IlvlSepLeft then self.StatsFrame.IlvlSepLeft:SetVertexColor(c.r, c.g, c.b, 1) end
        end
        self.StatsFrame.IlvlTitle:SetFont(headerFont, headerSize, headerOutline)
        self.StatsFrame.IlvlTitle:SetJustifyH("CENTER")
        self.StatsFrame.IlvlTitle:Show()
        self.StatsFrame.IlvlSepRight:Show()
        if self.StatsFrame.IlvlSepLeft then self.StatsFrame.IlvlSepLeft:Show() end
    else
        self.StatsFrame.Ilvl:Hide()
        self.StatsFrame.IlvlPvP:Hide()
        self.StatsFrame.IlvlTitle:Hide()
        self.StatsFrame.IlvlSepRight:Hide()
        if self.StatsFrame.IlvlSepLeft then self.StatsFrame.IlvlSepLeft:Hide() end
    end
    
    local statsList = {}
    local unit = "player"
    local secondaryMode = self.db.secondaryStatDisplayMode or "percent"
    local spec = GetSpecialization()
    local _, class = UnitClass(unit)
    
    -- ATTRIBUTES
    local attrHeaderColor = self.db.attrHeaderColor or ARMORY_HEADER_ATTRIBUTE
    table.insert(statsList, { type = "header", label = _G["STAT_CATEGORY_ATTRIBUTES"] or "Attributes", color = attrHeaderColor })
    
    local primaryStatID = nil
    if class == "HUNTER" or class == "ROGUE" or class == "DEMONHUNTER" then primaryStatID = 2 
    elseif class == "MAGE" or class == "WARLOCK" or class == "PRIEST" or class == "EVOKER" then primaryStatID = 4 
    elseif class == "WARRIOR" or class == "DEATHKNIGHT" then primaryStatID = 1 
    elseif class == "PALADIN" then primaryStatID = (spec == 1) and 4 or 1
    elseif class == "SHAMAN" then primaryStatID = (spec == 2) and 2 or 4
    elseif class == "MONK" then primaryStatID = (spec == 2) and 4 or 2
    elseif class == "DRUID" then primaryStatID = (spec == 1 or spec == 4) and 4 or 2 end

    if primaryStatID then
        local statVal, effectiveStat = SafeArmoryNumberCall(UnitStat, unit, primaryStatID)
        local statName = _G["SPELL_STAT"..primaryStatID.."_NAME"]
        local statColor = self.db.attrColor
        local icon = ""
        if primaryStatID == 1 then statColor = self.db.strengthColor; icon = ICONS.Strength
        elseif primaryStatID == 2 then statColor = self.db.agilityColor; icon = ICONS.Agility
        elseif primaryStatID == 4 then statColor = self.db.intellectColor; icon = ICONS.Intellect end
        
        table.insert(statsList, { 
            statKey = (primaryStatID == 1 and "strength") or (primaryStatID == 2 and "agility") or (primaryStatID == 4 and "intellect") or nil,
            label = icon .. statName, 
            value = effectiveStat or statVal, 
            numericValue = FormatArmoryNumber(effectiveStat or statVal),
            numericValueLabel = "Value",
            color = statColor or self.db.attrColor, 
            tooltip = _G["DEFAULT_STAT"..primaryStatID.."_TOOLTIP"],
            showLabel = self:IsStatLabelVisible((primaryStatID == 1 and "strength") or (primaryStatID == 2 and "agility") or (primaryStatID == 4 and "intellect") or nil),
        })
    end
    
    local stamBase, stamEffective = SafeArmoryNumberCall(UnitStat, unit, 3)
    table.insert(statsList, { 
        statKey = "stamina",
        label = ICONS.Stamina .. _G["SPELL_STAT3_NAME"], 
        value = stamEffective or stamBase, 
        numericValue = FormatArmoryNumber(stamEffective or stamBase),
        numericValueLabel = "Value",
        color = self.db.staminaColor or self.db.attrColor, 
        tooltip = _G["DEFAULT_STAT3_TOOLTIP"],
        showLabel = self:IsStatLabelVisible("stamina"),
    })

    local health = SafeArmoryNumberCall(UnitHealthMax, unit)
    local healthText = health and FormatArmoryNumber(health) or "—"
    table.insert(statsList, { 
        statKey = "health",
        label = ICONS.Health .. _G["HEALTH"], 
        value = health or "—", 
        numericValue = healthText,
        numericValueLabel = "Value",
        color = self.db.healthColor or self.db.attrColor, 
        tooltip = _G["STAT_HEALTH_TOOLTIP"],
        showLabel = true,
    })

    local mana = SafeArmoryNumberCall(UnitPowerMax, unit, 0)
    if mana and mana > 0 then
        local manaText = FormatArmoryNumber(mana)
        table.insert(statsList, { 
            statKey = "mana",
            label = ICONS.Mana .. _G["MANA"], 
            value = mana, 
            numericValue = manaText,
            numericValueLabel = "Value",
            color = self.db.manaColor or self.db.attrColor, 
            tooltip = _G["STAT_MANA_TOOLTIP"],
            showLabel = true,
        })
    end

    -- SECONDARY
    local secHeaderColor = self.db.enhHeaderColor or ARMORY_HEADER_SECONDARY
    table.insert(statsList, { type = "header", label = _G.STAT_CATEGORY_ENHANCEMENTS or "Secondary", color = secHeaderColor })

    local crit = SafeArmoryNumberCall(GetCritChance) or 0
    local critRating = (CR_CRIT_MELEE and SafeArmoryNumberCall(GetCombatRating, CR_CRIT_MELEE)) or 0
    local critEntry = BuildSecondaryStatEntry(secondaryMode, ICONS.Crit .. _G["STAT_CRITICAL_STRIKE"], crit, critRating, self.db.critColor, _G["CR_CRIT_TOOLTIP"])
    critEntry.statKey = "crit"; critEntry.showLabel = self:IsStatLabelVisible("crit"); table.insert(statsList, critEntry)
    
    local haste = GetArmoryHastePercent()
    local hasteRating = (CR_HASTE_MELEE and SafeArmoryNumberCall(GetCombatRating, CR_HASTE_MELEE)) or 0
    local hasteEntry = BuildSecondaryStatEntry(secondaryMode, ICONS.Haste .. _G["STAT_HASTE"], haste, hasteRating, self.db.hasteColor, _G["STAT_HASTE_TOOLTIP"])
    hasteEntry.statKey = "haste"; hasteEntry.showLabel = self:IsStatLabelVisible("haste"); table.insert(statsList, hasteEntry)
    
    local mastery = SafeArmoryNumberCall(GetMasteryEffect) or 0
    local masteryRating = (CR_MASTERY and SafeArmoryNumberCall(GetCombatRating, CR_MASTERY)) or 0
    local masteryEntry = BuildSecondaryStatEntry(secondaryMode, ICONS.Mastery .. _G["STAT_MASTERY"], mastery, masteryRating, self.db.masteryColor, _G["STAT_MASTERY_TOOLTIP"])
    masteryEntry.statKey = "mastery"; masteryEntry.showLabel = self:IsStatLabelVisible("mastery"); table.insert(statsList, masteryEntry)
    
    local versRating = (CR_VERSATILITY_DAMAGE_DONE and SafeArmoryNumberCall(GetCombatRating, CR_VERSATILITY_DAMAGE_DONE)) or 0
    local versBonusA = SafeArmoryNumberCall(GetCombatRatingBonus, CR_VERSATILITY_DAMAGE_DONE) or 0
    local versBonusB = SafeArmoryNumberCall(GetVersatilityBonus, CR_VERSATILITY_DAMAGE_DONE) or 0
    local vers = versBonusA + versBonusB
    local versEntry = BuildSecondaryStatEntry(secondaryMode, ICONS.Versatility .. _G["STAT_VERSATILITY"], vers, versRating, self.db.versatilityColor, _G["CR_VERSATILITY_TOOLTIP"])
    versEntry.statKey = "versatility"; versEntry.showLabel = self:IsStatLabelVisible("versatility"); table.insert(statsList, versEntry)
    
    -- ATTACK
    table.insert(statsList, { type = "header", label = _G.STAT_CATEGORY_ATTACK or "Attack", color = {r=0.8, g=0.2, b=0.2, a=1} })

    -- UnitAttackPower can return secret numbers during combat.  Never perform
    -- arithmetic on the raw values; keep the row visible when unavailable.
    local apBase, apPos, apNeg = SafeArmoryNumberCall(UnitAttackPower, unit)
    local ap = apBase and apPos and apNeg and (apBase + apPos + apNeg) or nil
    local attackPowerText = ap and FormatArmoryNumber(ap) or "—"
    table.insert(statsList, { 
        statKey = "attackpower",
        label = ICONS.AttackPower .. (_G["STAT_ATTACK_POWER"] or "Attack Power"), 
        value = ap or "—", 
        numericValue = attackPowerText,
        numericValueLabel = "Value",
        color = self.db.attackPowerColor or self.db.attrColor, 
        tooltip = _G["STAT_ATTACK_POWER_TOOLTIP"],
        showLabel = true,
    })

    local mhSpeed, ohSpeed = SafeArmoryNumberCall(UnitAttackSpeed, unit)
    local asText = "—"
    if mhSpeed and mhSpeed > 0 then
        asText = string.format("%.2fs", mhSpeed)
    end
    if mhSpeed and ohSpeed and ohSpeed > 0 then
        asText = string.format("%.2fs / %.2fs", mhSpeed, ohSpeed)
    end
    table.insert(statsList, { 
        statKey = "attackspeed",
        label = ICONS.AttackSpeed .. (_G["STAT_ATTACK_SPEED"] or "Attack Speed"), 
        value = asText, 
        color = self.db.attackSpeedColor or self.db.attrColor, 
        tooltip = _G["STAT_ATTACK_SPEED_TOOLTIP"],
        showLabel = true,
    })

    local sp = SafeArmoryNumberCall(GetSpellBonusDamage, 7)
    local spellPowerText = sp and FormatArmoryNumber(sp) or "—"
    table.insert(statsList, { 
        statKey = "spellpower",
        label = ICONS.SpellPower .. (_G["STAT_SPELL_POWER"] or "Spell Power"), 
        value = sp or "—", 
        numericValue = spellPowerText,
        numericValueLabel = "Value",
        color = self.db.spellPowerColor or self.db.attrColor, 
        tooltip = _G["STAT_SPELL_POWER_TOOLTIP"],
        showLabel = true,
    })

    -- DEFENSE
    local defHeaderColor = ARMORY_HEADER_DEFENSE
    table.insert(statsList, { type = "header", label = _G.STAT_CATEGORY_DEFENSE or "Defense", color = defHeaderColor })

    local baseArmor, effectiveArmor = SafeArmoryNumberCall(UnitArmor, unit)
    table.insert(statsList, { 
        statKey = "armor",
        label = ICONS.Armor .. _G["STAT_ARMOR"], 
        value = effectiveArmor, 
        numericValue = FormatArmoryNumber(effectiveArmor),
        numericValueLabel = "Value",
        color = self.db.armorColor or self.db.attrColor, 
        tooltip = _G["STAT_ARMOR_TOOLTIP"],
        showLabel = self:IsStatLabelVisible("armor"),
    })

    local dodge = SafeArmoryNumberCall(GetDodgeChance) or 0
    local dodgeRating = (CR_DODGE and SafeArmoryNumberCall(GetCombatRating, CR_DODGE)) or 0
    local dodgeEntry = BuildSecondaryStatEntry(secondaryMode, ICONS.Dodge .. _G["STAT_DODGE"], dodge, dodgeRating, self.db.dodgeColor, _G["CR_DODGE_TOOLTIP"])
    dodgeEntry.statKey = "dodge"; dodgeEntry.showLabel = self:IsStatLabelVisible("dodge"); table.insert(statsList, dodgeEntry)
    
    local parry = SafeArmoryNumberCall(GetParryChance) or 0
    local parryRating = (CR_PARRY and SafeArmoryNumberCall(GetCombatRating, CR_PARRY)) or 0
    local parryEntry = BuildSecondaryStatEntry(secondaryMode, ICONS.Parry .. _G["STAT_PARRY"], parry, parryRating, self.db.parryColor, _G["CR_PARRY_TOOLTIP"])
    parryEntry.statKey = "parry"; parryEntry.showLabel = self:IsStatLabelVisible("parry"); table.insert(statsList, parryEntry)
    
    local block = SafeArmoryNumberCall(GetBlockChance) or 0
    local blockRating = (CR_BLOCK and SafeArmoryNumberCall(GetCombatRating, CR_BLOCK)) or 0
    local blockEntry = BuildSecondaryStatEntry(secondaryMode, ICONS.Block .. _G["STAT_BLOCK"], block, blockRating, self.db.blockColor, _G["CR_BLOCK_TOOLTIP"])
    blockEntry.statKey = "block"; blockEntry.showLabel = self:IsStatLabelVisible("block"); table.insert(statsList, blockEntry)

    -- GENERAL
    local genHeaderColor = ARMORY_HEADER_GENERAL
    table.insert(statsList, { type = "header", label = _G.STAT_CATEGORY_GENERAL or "General", color = genHeaderColor })

    local leech = SafeArmoryNumberCall(GetLifesteal) or 0
    local leechRating = (CR_LIFESTEAL and SafeArmoryNumberCall(GetCombatRating, CR_LIFESTEAL)) or 0
    local leechEntry = BuildSecondaryStatEntry(secondaryMode, ICONS.Leech .. _G["STAT_LIFESTEAL"], leech, leechRating, self.db.leechColor, _G["CR_LIFESTEAL_TOOLTIP"])
    leechEntry.statKey = "leech"; leechEntry.showLabel = self:IsStatLabelVisible("leech"); table.insert(statsList, leechEntry)
    
    local avoidance = SafeArmoryNumberCall(GetAvoidance) or 0
    local avoidanceRating = (CR_AVOIDANCE and SafeArmoryNumberCall(GetCombatRating, CR_AVOIDANCE)) or 0
    local avoidanceEntry = BuildSecondaryStatEntry(secondaryMode, ICONS.Avoidance .. _G["STAT_AVOIDANCE"], avoidance, avoidanceRating, self.db.avoidanceColor, _G["CR_AVOIDANCE_TOOLTIP"])
    avoidanceEntry.statKey = "avoidance"; avoidanceEntry.showLabel = self:IsStatLabelVisible("avoidance"); table.insert(statsList, avoidanceEntry)
    
    local speed = GetArmorySpeedPercent()
    -- Speed is a total movement percentage, not a useful raw combat-rating
    -- number: CR_SPEED is normally 0 at base speed and makes the UI look broken.
    local speedEntry = BuildSecondaryStatEntry(secondaryMode, ICONS.Speed .. _G["STAT_SPEED"], speed, speed, self.db.speedColor, _G["CR_SPEED_TOOLTIP"], speed)
    speedEntry.statKey = "speed"; speedEntry.showLabel = self:IsStatLabelVisible("speed"); table.insert(statsList, speedEntry)

    local visibleStats = {}
    local pendingHeader
    for _, data in ipairs(statsList) do
        if data.type == "header" then
            pendingHeader = data
        elseif data.showLabel ~= false then
            if pendingHeader then
                table.insert(visibleStats, pendingHeader)
                pendingHeader = nil
            end
            table.insert(visibleStats, data)
        end
    end
    statsList = visibleStats
    
    local scrollChild = self.StatsFrame.ScrollChild
    local prevFrame = nil
    local spacing = self.db.statSpacing or 3
    spacing = math.max(0, tonumber(spacing) or 3)
    local sectionSpacing = math.max(spacing + 6, math.floor((size or 12) * 0.66))
    local contentWidth = tonumber(scrollChild:GetWidth()) or 250
    if contentWidth <= 0 then contentWidth = 250 end
    
    local startY = -14
    if self.db.showAvgIlvl then
        local ilvlSize = self.db.avgIlvlFontSize or 20
        local pvpExtraHeight = 0
        if self.db.showAvgIlvlPvP ~= false then
            local pvpSize = tonumber(self.db.avgIlvlPvPFontSize) or 10
            local pvpOffsetY = tonumber(self.db.avgIlvlPvPOffsetY) or -2
            pvpExtraHeight = math.max(0, pvpSize - 10) + math.max(0, -2 - pvpOffsetY)
        end
        startY = -(34 + ilvlSize + pvpExtraHeight + sectionSpacing)
    end
    
    local totalHeight = math.abs(startY)
    
    for i, data in ipairs(statsList) do
        local row = self.StatsFrame.Stats[i]
        if not row then
            row = CreateFrame("Frame", nil, scrollChild)
            row:SetSize(contentWidth, 20)
            
            row.Icon = row:CreateTexture(nil, "OVERLAY")
            row.Icon:SetSize(14, 14)
            row.Icon:SetPoint("LEFT", row, "LEFT", 10, -2)
            row.Icon:Hide()
            
            row.Label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.Label:SetPoint("LEFT", row, "LEFT", 10, -2)
            row.Label:SetWordWrap(false)
            row.Label:SetNonSpaceWrap(false)
            row.Label:SetJustifyH("LEFT")
            row.Label:SetMaxLines(1)
            
            row.Value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.Value:SetPoint("RIGHT", row, "RIGHT", -10, -2)
            row.Value:SetWordWrap(false)
            row.Value:SetJustifyH("RIGHT")
            row.Value:SetWordWrap(false)
            row.Value:SetNonSpaceWrap(false)
            
            row.RightLine = row:CreateTexture(nil, "ARTWORK")
            row.RightLine:SetSize(1, 1)
            row.RightLine:Hide()
            
            row.LeftLine = row:CreateTexture(nil, "ARTWORK")
            row.LeftLine:SetSize(1, 1)
            row.LeftLine:Hide()
            
            row:EnableMouse(true)
            row:SetScript("OnEnter", function(self)
                if not self.tooltip then return end
                GameTooltip:Hide()
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:ClearLines()
                local rawLabel = self.label or ""
                rawLabel = rawLabel:gsub("|T.-|t%s*", "")
                GameTooltip:SetText(rawLabel, 1, 1, 1)
                GameTooltip:AddLine(SanitizeArmoryTooltip(self.tooltip, self.percentValueText or self.numericValueText), nil, nil, nil, true)
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            self.StatsFrame.Stats[i] = row
        end
        
        row:ClearAllPoints()
        row:SetWidth(contentWidth)
        
        local rowHeight = 20
        if data.type == "header" then rowHeight = 22 end
        
        local rowSpacing = spacing
        if i > 1 and data.type == "header" then
            rowSpacing = sectionSpacing
        end

        if i == 1 then
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, startY)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, startY)
        else
            row:SetPoint("TOPLEFT", prevFrame, "BOTTOMLEFT", 0, -rowSpacing)
            row:SetPoint("TOPRIGHT", prevFrame, "BOTTOMRIGHT", 0, -rowSpacing)
        end
        
        row:SetHeight(rowHeight)
        totalHeight = totalHeight + rowHeight + rowSpacing
        
        row.Label:Hide()
        row.Value:Hide()
        if row.RightLine then row.RightLine:Hide() end
        if row.LeftLine then row.LeftLine:Hide() end
        row.tooltip = nil
        row.label = nil
        row.numericValueText = nil
        row.numericValueLabel = nil
        row.percentValueText = nil
        row:EnableMouse(false)
        row.Label:SetWidth(contentWidth - 20)
        row.Value:SetWidth(contentWidth - 20)
        
        if data.type == "header" then
            row.Label:Show()
            row.Label:SetFont(headerFont, headerSize, headerOutline)
            row.Label:SetText(data.label)
            row.Label:SetWidth(0)
            
            if data.color then
                row.Label:SetTextColor(data.color.r, data.color.g, data.color.b)
            else
                row.Label:SetTextColor(0.8, 0.8, 0.2) 
            end
            
            row.Label:ClearAllPoints()
            row.Label:SetPoint("CENTER", row, "CENTER", 0, -3)
            row.Label:SetWordWrap(false)
            row.Label:SetJustifyH("CENTER")
            
            if not row.LeftLine then
                row.LeftLine = row:CreateTexture(nil, "ARTWORK")
            end
            
            row.LeftLine:Show()
            row.LeftLine:ClearAllPoints()
            row.LeftLine:SetPoint("RIGHT", row.Label, "LEFT", -5, 1)
            row.LeftLine:SetSize(80, 8)
            row.LeftLine:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\separator_armory.png")
            row.LeftLine:SetTexCoord(1, 0, 0, 1)
            
            row.RightLine:Show()
            row.RightLine:ClearAllPoints()
            row.RightLine:SetPoint("LEFT", row.Label, "RIGHT", 5, 1)
            row.RightLine:SetSize(80, 8)
            row.RightLine:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\separator_armory.png")
            row.RightLine:SetTexCoord(0, 1, 0, 1)
            
            if data.color then
                row.LeftLine:SetVertexColor(data.color.r, data.color.g, data.color.b, 1)
                row.RightLine:SetVertexColor(data.color.r, data.color.g, data.color.b, 1)
            else
                row.LeftLine:SetVertexColor(0.8, 0.8, 0.2, 1)
                row.RightLine:SetVertexColor(0.8, 0.8, 0.2, 1)
            end
            
        else
            local labelText = tostring(data.label or "")
            local valueText = ""
            local formatMode = self.db.statFormatMode or "BOTH"
            
            if data.numericValue and data.percentValue then
                if formatMode == "NUMERIC" then
                    valueText = data.numericValue
                elseif formatMode == "PERCENT" then
                    valueText = data.percentValue
                else
                    valueText = string.format("%s (%s)", data.numericValue, data.percentValue)
                end
            else
                valueText = tostring(data.numericValue or data.percentValue or data.value or "")
            end
            row.Label:Show()
            row.Value:Show()
            row.tooltip = data.tooltip
            row.label = labelText
            row.numericValueText = data.numericValue and tostring(data.numericValue) or nil
            row.numericValueLabel = data.numericValueLabel
            row.percentValueText = data.percentValue
            row:EnableMouse(data.tooltip ~= nil and data.tooltip ~= "")
            
            row.Label:SetFont(font, tonumber(size) or 11, "OUTLINE")
            row.Value:SetFont(font, tonumber(size) or 11, "OUTLINE")
            
            local prefixIcon, cleanLabel = string.match(labelText, "^(|T.-|t%s*)(.*)$")
            if not prefixIcon then
                cleanLabel = labelText
                row.Icon:Hide()
                row.Label:SetPoint("LEFT", row, "LEFT", 10, -2)
            else
                local texPath = string.match(prefixIcon, "|T([^:]+)")
                if texPath then
                    row.Icon:SetTexture(tonumber(texPath) or texPath)
                    row.Icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
                    row.Icon:Show()
                    row.Label:SetPoint("LEFT", row.Icon, "RIGHT", 4, 0)
                else
                    row.Icon:Hide()
                    row.Label:SetPoint("LEFT", row, "LEFT", 10, -2)
                end
            end
            
            row.Value:SetText(valueText)
            row.Value:ClearAllPoints()
            row.Value:SetPoint("RIGHT", row, "RIGHT", -10, -2)

            -- Size the value column from the actual rendered text. The old fixed
            -- 115px column left too little room for labels such as Critical Strike
            -- and allowed the two FontStrings to visually overlap.
            local valueTextWidth = row.Value.GetStringWidth and row.Value:GetStringWidth() or 0
            local valueWidth = math.min(125, math.max(28, valueTextWidth + 8))
            row.Value:SetWidth(valueWidth)

            local inset = 10
            local columnGap = 6
            local iconOffset = row.Icon:IsShown() and 18 or 0
            local labelStart = inset + iconOffset
            local labelWidth = math.max(1, contentWidth - inset - valueWidth - columnGap - labelStart)            
            local function utf8_safe_truncate(str, limit)
                local len = string.len(str)
                local chars = 0
                local offset = 1
                while offset <= len and chars < limit do
                    local b = string.byte(str, offset)
                    if not b then break end
                    if b < 128 then offset = offset + 1
                    elseif b < 224 then offset = offset + 2
                    elseif b < 240 then offset = offset + 3
                    else offset = offset + 4 end
                    chars = chars + 1
                end
                if offset <= len then
                    chars = 0
                    local newOffset = 1
                    local ellipsisLimit = math.max(1, limit - 3)
                    while newOffset <= len and chars < ellipsisLimit do
                        local b = string.byte(str, newOffset)
                        if not b then break end
                        if b < 128 then newOffset = newOffset + 1
                        elseif b < 224 then newOffset = newOffset + 2
                        elseif b < 240 then newOffset = newOffset + 3
                        else newOffset = newOffset + 4 end
                        chars = chars + 1
                    end
                    return string.sub(str, 1, newOffset - 1) .. "..."
                end
                return str
            end

            local function utf8_length(str)
                local count = 0
                local offset = 1
                local len = string.len(str)
                while offset <= len do
                    local b = string.byte(str, offset)
                    if not b then break end
                    if b < 128 then offset = offset + 1
                    elseif b < 224 then offset = offset + 2
                    elseif b < 240 then offset = offset + 3
                    else offset = offset + 4 end
                    count = count + 1
                end
                return count
            end

            -- Keep the complete label whenever it fits. Only truncate after
            -- measuring the rendered FontString, rather than estimating a
            -- fixed number of pixels per character.
            row.Label:SetWidth(labelWidth)
            row.Label:SetText(cleanLabel)
            if row.Label.GetStringWidth and row.Label:GetStringWidth() > labelWidth then
                local limit = utf8_length(cleanLabel)
                local fittedLabel = cleanLabel
                while limit > 1 do
                    limit = limit - 1
                    local candidate = utf8_safe_truncate(cleanLabel, limit)
                    row.Label:SetText(candidate)
                    fittedLabel = candidate
                    if row.Label:GetStringWidth() <= labelWidth then
                        break
                    end
                end
                cleanLabel = fittedLabel
            end
            row.Label:SetText(cleanLabel)
            row.Label:ClearAllPoints()
            if row.Icon:IsShown() then
                row.Label:SetPoint("LEFT", row.Icon, "RIGHT", 4, 0)
            else
                row.Label:SetPoint("LEFT", row, "LEFT", 10, -2)
            end
            -- Keep the label inside the gap before the value even when a
            -- localization produces a wider stat name.
            row.Label:SetPoint("RIGHT", row.Value, "LEFT", -columnGap, 0)
            row.Label:SetWidth(labelWidth)
            
            if self.db.colorStats and data.color then
                row.Label:SetTextColor(data.color.r, data.color.g, data.color.b)
            else
                row.Label:SetTextColor(1, 1, 1)
            end
            
            if self.db.colorStatValues ~= false and data.color then
                row.Value:SetTextColor(data.color.r, data.color.g, data.color.b)
            elseif self.db.statValueColor then
                local c = self.db.statValueColor
                row.Value:SetTextColor(c.r, c.g, c.b, c.a or 1)
            else
                row.Value:SetTextColor(1, 1, 1)
            end
        end
        
        row:Show()
        prevFrame = row
    end
    
    self.StatsFrame.ScrollChild:SetHeight(totalHeight)

    local scrollFrame = self.StatsFrame.ScrollFrame
    local viewportHeight = tonumber(scrollFrame:GetHeight()) or 0
    local hasOverflow = totalHeight > (viewportHeight + 1)
    if scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:SetShown(hasOverflow)
    end
    if not hasOverflow then
        scrollFrame:SetVerticalScroll(0)
    end
    -- The KUI text tabs live above the inset; do not reserve their old row
    -- inside the Stats viewport every time the values are refreshed.
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", 10, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", hasOverflow and -20 or -4, 10)
    
    for i = #statsList + 1, #self.StatsFrame.Stats do
        self.StatsFrame.Stats[i]:Hide()
    end
end

function AR:CreateConfigButton()
    if self.configBtn then return end
    local characterFrame = _G.CharacterFrame
    local closeButton = characterFrame and (characterFrame.CloseButton or _G.CharacterFrameCloseButton)
    local parent = characterFrame or self.StatsFrame
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(24, 24)
    if closeButton then
        btn:SetPoint("RIGHT", closeButton, "LEFT", -2, 0)
        btn:SetFrameLevel(closeButton:GetFrameLevel() + 1)
    else
        btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -30, -3)
        btn:SetFrameLevel(parent:GetFrameLevel() + 10)
    end
    
    btn:SetNormalTexture("Interface\\Icons\\Trade_Engineering")
    btn:GetNormalTexture():SetTexCoord(0.1, 0.9, 0.1, 0.9)
    btn:GetNormalTexture():ClearAllPoints()
    btn:GetNormalTexture():SetPoint("TOPLEFT", 4, -4)
    btn:GetNormalTexture():SetPoint("BOTTOMRIGHT", -4, 4)
    btn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    
    btn:SetScript("OnClick", function()
        AR:OpenOptionsPage()
    end)
    self.configBtn = btn
end

function AR:Refresh()
    self.db = KT.db.profile.armory
    EnsureArmoryColorDefaults(self.db)
    if _G.CharacterFrame then _G.CharacterFrame:SetScale(self.db.scale) end
    
    if _G.CharacterFramePortrait then
        if self.db.showPortrait then
            _G.CharacterFramePortrait:Show()
            SetPortraitTexture(_G.CharacterFramePortrait, "player")
        else
            _G.CharacterFramePortrait:Hide()
        end
    end
    
    self:UpdateBackground()
    if self.Header then self:UpdateHeader() end
    
    if _G.CharacterFrame:IsShown() then
        for slotName, _ in pairs(SLOT_IDS) do
             local button = _G["Character"..slotName]
             if button then self:UpdateSlot(button) end
        end
        self:UpdateMyStats()
    end
end
