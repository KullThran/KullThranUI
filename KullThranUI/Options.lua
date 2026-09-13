-- Options.lua
-- Sistema de opciones custom basado en KT.Widgets (sin AceConfig)
-- Reemplaza AceConfigDialog por un panel propio (custom)
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local LSM = LibStub("LibSharedMedia-3.0", true)

local ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"
local CATEGORY_ICON_PATH = ICON_PATH .. "CategoryIcons\\"
local MODULE_ICON_PATH = ICON_PATH .. "Icons_40x26\\"

ns.PAGE_ICON_MAP = {
    general        = "Config",
    skins          = "Skins",
    nameplates     = "Nameplates",
    unitframes     = "UnitFrames",
    partyframes    = "PartyFrames",
    minimap        = "Minimap",
    actionbars     = "ActionBars",
    buffs          = "BuffsAndDebuffs",
    castbar        = "CastBar",
    tooltip        = "Tooltip",
    armory         = "Armory",
    inspectarmory  = "Inspect",
    dragonriding   = "DragonRiding",
    expbar         = "ExperienceBar",
    chat           = "Chat",
    bags           = "Bags",
    aurareminders  = "AuraReminders",
    cooldownmanager = "KUICooldownManager",
    teleportmenu   = "TeleportMenu",
    cursor         = "Cursor",
    enhancements   = "Enhacements",
    external       = "cogs",
    installer      = "Installer",
    objectivetracker = "Tracker",
    resourcebars    = "ResourceBars",
}

ns.MENU_CATEGORIES = {
    { id = "general_style", label = "General & Style", icon = "General", order = 10 },
    { id = "units_character", label = "Units & Character", icon = "UnitsAndCharacter", order = 20 },
    { id = "combat_auras", label = "Combat & Auras", icon = "CombatAndAuras", order = 30 },
    { id = "hud_navigation", label = "HUD & Navigation", icon = "HUD", order = 40 },
    { id = "utility_social", label = "Utility & Social", icon = "UtilityAndSocial", order = 50 },
}

ns.PAGE_CATEGORY_MAP = {
    general = "general_style",
    skins = "general_style",
    enhancements = "general_style",
    external = "general_style",
    installer = "general_style",

    unitframes = "units_character",
    partyframes = "units_character",
    nameplates = "units_character",
    armory = "units_character",
    inspectarmory = "units_character",

    actionbars = "combat_auras",
    cooldownmanager = "combat_auras",
    aurareminders = "combat_auras",
    buffs = "combat_auras",
    castbar = "combat_auras",
    resourcebars = "combat_auras",

    objectivetracker = "hud_navigation",
    expbar = "hud_navigation",
    minimap = "hud_navigation",
    dragonriding = "hud_navigation",
    teleportmenu = "hud_navigation",

    chat = "utility_social",
    bags = "utility_social",
    tooltip = "utility_social",
    cursor = "utility_social",
}

ns.HIDDEN_OPTION_PAGES = {
    progressbars = true,
}

ns.MODULE_ICON_MAP = {
    general = "Config",
    skins = "Skins",
    enhancements = "Enhacements",
    external = "Cogs",
    installer = "Installer",
    unitframes = "UnitFrames",
    partyframes = "PartyFrames",
    nameplates = "Nameplates",
    armory = "Armory",
    inspectarmory = "Inspect",
    actionbars = "ActionBars",
    cooldownmanager = "CooldownManager",
    aurareminders = "AuraReminders",
    buffs = "BuffsAndDebuffs",
    castbar = "CastBar",
    resourcebars = "ResourceBars",
    objectivetracker = "Tracker",
    expbar = "ExperienceBar",
    minimap = "Minimap",
    dragonriding = "DragonRiding",
    teleportmenu = "TeleportMenu",
    chat = "Chat",
    bags = "Bags",
    tooltip = "Tooltip",
    cursor = "Cursor",
}

ns.CATEGORY_OVERVIEW_PREFIX = "__category__:"
ns.CATEGORY_OVERVIEW_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Button.png"

ns.CATEGORY_DESCRIPTION_MAP = {
    general_style = "Core configuration, visual styles and setup tools for KullThranUI.",
    units_character = "Configure unit displays, nameplates and character information.",
    combat_auras = "Manage combat controls, cooldowns, auras, casts and resources.",
    hud_navigation = "Customize tracking, navigation and heads-up display elements.",
    utility_social = "Configure communication, inventory and everyday utility tools.",
}

ns.MODULE_DESCRIPTION_MAP = {
    general = "Global interface settings, profiles, colors and quick setup.",
    skins = "Apply the KullThranUI visual style to Blizzard interface elements.",
    enhancements = "Quality-of-life features and additional interface improvements.",
    external = "Configure supported external addons and their KUI integration.",
    installer = "Run the guided setup and install the recommended configuration.",

    unitframes = "Customize player, target, focus and related unit frames.",
    partyframes = "Configure party and group frames for clear group information.",
    nameplates = "Control enemy and friendly nameplates, auras and indicators.",
    armory = "Customize the character equipment and progression display.",
    inspectarmory = "Improve the inspection window with equipment details and stats.",

    actionbars = "Configure action bar layout, buttons, paging and visibility.",
    cooldownmanager = "Track important ability cooldowns and combat availability.",
    aurareminders = "Create reminders for missing buffs, stances and useful auras.",
    buffs = "Customize player buffs, debuffs and their visual presentation.",
    castbar = "Configure cast bars, spell information and interrupt feedback.",
    resourcebars = "Display class resources and other combat power information.",

    objectivetracker = "Customize quests, objectives and scenario tracking.",
    expbar = "Track experience, reputation and other progression values.",
    minimap = "Configure the minimap, buttons and navigation information.",
    dragonriding = "Customize skyriding vigor and related movement information.",
    teleportmenu = "Access hearthstones, portals and teleportation spells quickly.",

    chat = "Customize chat windows, private conversations and message behavior.",
    bags = "Configure inventory layout, sorting and item presentation.",
    tooltip = "Customize information tooltips and their appearance.",
    cursor = "Improve cursor visibility with configurable visual effects.",
}
-- Forward declarations are intentionally above the theme helpers so every
-- callback shares the same navigation state.
ns.activePageId = nil
ns.openCategoryIds = {}

local function IsCategoryOpen(categoryId)
    return categoryId and ns.openCategoryIds[categoryId] == true
end
ns.navButtons = {}
ns.categoryButtons = {}
ns.pages = {}
local LoadPage
local LoadCategoryOverview

ns.MENU_ICON_PRESERVE_COLOR = {}
local GetMenuAccentColor
ns.OPTIONS_RECYCLER = CreateFrame("Frame")
ns.OPTIONS_RECYCLER:Hide()
ns.PAGE_ICON_STYLE_MAP = {
    nameplates = {
        width = 56,
        height = 34,
        offsetY = 1,
},
}

local function LocalizeText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

local function GetMenuIconColorMode()
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin
    if skin and skin.menuIconColorMode == "accent" then
        return "accent"
    end
    return "white"
end

local function GetMenuIconVertexColor(iconName)
    if ns.MENU_ICON_PRESERVE_COLOR[iconName] then
        return 1, 1, 1
    end
    if GetMenuIconColorMode() == "accent" then
        return GetMenuAccentColor()
    end
    return 1, 1, 1
end

local function MakeStyleColor(r, g, b, a)
    return { r = r or 0, g = g or 0, b = b or 0, a = a == nil and 1 or a }
end
local function CopyStyleColor(color)
    return MakeStyleColor(
        color and color.r or color and color[1] or 0,
        color and color.g or color and color[2] or 0,
        color and color.b or color and color[3] or 0,
        color and color.a or color and color[4] or 1
    )
end

local function BlendStyleColor(a, b, amount)
    amount = tonumber(amount) or 0.5
    if amount < 0 then amount = 0 end
    if amount > 1 then amount = 1 end
    local inv = 1 - amount
    return {
        r = ((a and a.r) or 0) * inv + ((b and b.r) or 0) * amount,
        g = ((a and a.g) or 0) * inv + ((b and b.g) or 0) * amount,
        b = ((a and a.b) or 0) * inv + ((b and b.b) or 0) * amount,
        a = ((a and a.a) or 1) * inv + ((b and b.a) or 1) * amount,
}
end

local STYLE_PRESETS = {
    kui_crimson = {
        label = "KUI Crimson",
        accent = MakeStyleColor(1.00, 0.08, 0.34, 1),
        border = MakeStyleColor(1.00, 0.18, 0.39, 1),
        background = MakeStyleColor(0.04, 0.02, 0.03, 0.97),
        text = MakeStyleColor(0.98, 0.94, 0.96, 1),
        muted = MakeStyleColor(0.74, 0.72, 0.76, 1),
        backgroundTint = MakeStyleColor(1.00, 0.08, 0.34, 0.16),
        iconMode = "accent",
},
    frost_blue = {
        label = "Frost Blue",
        accent = MakeStyleColor(0.20, 0.76, 1.00, 1),
        border = MakeStyleColor(0.37, 0.84, 1.00, 1),
        background = MakeStyleColor(0.02, 0.05, 0.08, 0.97),
        text = MakeStyleColor(0.92, 0.97, 1.00, 1),
        muted = MakeStyleColor(0.68, 0.77, 0.82, 1),
        backgroundTint = MakeStyleColor(0.18, 0.66, 1.00, 0.18),
        iconMode = "accent",
},
    emerald_night = {
        label = "Emerald Night",
        accent = MakeStyleColor(0.16, 0.88, 0.50, 1),
        border = MakeStyleColor(0.28, 0.95, 0.62, 1),
        background = MakeStyleColor(0.02, 0.06, 0.04, 0.97),
        text = MakeStyleColor(0.93, 1.00, 0.96, 1),
        muted = MakeStyleColor(0.68, 0.80, 0.74, 1),
        backgroundTint = MakeStyleColor(0.10, 0.82, 0.44, 0.17),
        iconMode = "accent",
},
    royal_violet = {
        label = "Royal Violet",
        accent = MakeStyleColor(0.54, 0.48, 1.00, 1),
        border = MakeStyleColor(0.66, 0.60, 1.00, 1),
        background = MakeStyleColor(0.03, 0.03, 0.08, 0.97),
        text = MakeStyleColor(0.96, 0.95, 1.00, 1),
        muted = MakeStyleColor(0.73, 0.72, 0.84, 1),
        backgroundTint = MakeStyleColor(0.42, 0.36, 1.00, 0.16),
        iconMode = "accent",
},
    ember_gold = {
        label = "Ember Gold",
        accent = MakeStyleColor(1.00, 0.62, 0.16, 1),
        border = MakeStyleColor(1.00, 0.74, 0.28, 1),
        background = MakeStyleColor(0.08, 0.04, 0.02, 0.97),
        text = MakeStyleColor(1.00, 0.96, 0.90, 1),
        muted = MakeStyleColor(0.84, 0.76, 0.64, 1),
        backgroundTint = MakeStyleColor(1.00, 0.52, 0.12, 0.17),
        iconMode = "accent",
},
    obsidian_teal = {
        label = "Obsidian Teal",
        accent = MakeStyleColor(0.10, 0.86, 0.82, 1),
        border = MakeStyleColor(0.24, 0.94, 0.90, 1),
        background = MakeStyleColor(0.02, 0.04, 0.05, 0.97),
        text = MakeStyleColor(0.91, 0.99, 0.98, 1),
        muted = MakeStyleColor(0.63, 0.79, 0.77, 1),
        backgroundTint = MakeStyleColor(0.08, 0.72, 0.68, 0.18),
        iconMode = "accent",
},
    blood_moon = {
        label = "Blood Moon",
        accent = MakeStyleColor(0.90, 0.16, 0.22, 1),
        border = MakeStyleColor(1.00, 0.28, 0.34, 1),
        background = MakeStyleColor(0.07, 0.01, 0.02, 0.97),
        text = MakeStyleColor(1.00, 0.93, 0.94, 1),
        muted = MakeStyleColor(0.84, 0.66, 0.68, 1),
        backgroundTint = MakeStyleColor(0.82, 0.10, 0.18, 0.18),
        iconMode = "accent",
},
    sunforge = {
        label = "Sunforge",
        accent = MakeStyleColor(1.00, 0.78, 0.18, 1),
        border = MakeStyleColor(1.00, 0.86, 0.34, 1),
        background = MakeStyleColor(0.08, 0.06, 0.01, 0.97),
        text = MakeStyleColor(1.00, 0.98, 0.90, 1),
        muted = MakeStyleColor(0.86, 0.80, 0.62, 1),
        backgroundTint = MakeStyleColor(1.00, 0.70, 0.12, 0.18),
        iconMode = "accent",
},
    arcwine = {
        label = "Arcwine",
        accent = MakeStyleColor(0.82, 0.30, 1.00, 1),
        border = MakeStyleColor(0.90, 0.46, 1.00, 1),
        background = MakeStyleColor(0.05, 0.02, 0.08, 0.97),
        text = MakeStyleColor(0.98, 0.94, 1.00, 1),
        muted = MakeStyleColor(0.77, 0.68, 0.86, 1),
        backgroundTint = MakeStyleColor(0.72, 0.22, 1.00, 0.17),
        iconMode = "accent",
},
    stormsteel = {
        label = "Stormsteel",
        accent = MakeStyleColor(0.58, 0.70, 0.84, 1),
        border = MakeStyleColor(0.70, 0.80, 0.92, 1),
        background = MakeStyleColor(0.03, 0.05, 0.07, 0.97),
        text = MakeStyleColor(0.94, 0.97, 1.00, 1),
        muted = MakeStyleColor(0.67, 0.74, 0.80, 1),
        backgroundTint = MakeStyleColor(0.44, 0.58, 0.74, 0.16),
        iconMode = "accent",
},
    plague_green = {
        label = "Plague Green",
        accent = MakeStyleColor(0.62, 0.88, 0.12, 1),
        border = MakeStyleColor(0.74, 0.96, 0.28, 1),
        background = MakeStyleColor(0.04, 0.06, 0.01, 0.97),
        text = MakeStyleColor(0.95, 1.00, 0.90, 1),
        muted = MakeStyleColor(0.74, 0.83, 0.60, 1),
        backgroundTint = MakeStyleColor(0.50, 0.78, 0.08, 0.18),
        iconMode = "accent",
    },
    sakura_fall = {
        label = "Sakura Fall",
        accent = MakeStyleColor(0.96, 0.53, 0.69, 1),
        border = MakeStyleColor(1.00, 0.63, 0.79, 1),
        background = MakeStyleColor(0.06, 0.03, 0.04, 0.97),
        text = MakeStyleColor(0.98, 0.92, 0.94, 1),
        muted = MakeStyleColor(0.82, 0.70, 0.74, 1),
        backgroundTint = MakeStyleColor(0.96, 0.53, 0.69, 0.16),
        iconMode = "accent",
    },
}

local function KT_GetActiveAccent(skin)
    if KT and KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        return { r = r, g = g, b = b, a = 1 }
    end
    return (skin and skin.accentColor) or STYLE_PRESETS.kui_crimson.accent
end

local function GetOptionsStylePalette()
    local palette = KT and KT.GetStylePalette and KT:GetStylePalette() or KT and KT.STYLE_PALETTE or nil
    if palette then
        return palette
    end

    local fallback = STYLE_PRESETS.kui_crimson
    return {
        accent = CopyStyleColor(fallback.accent),
        border = CopyStyleColor(fallback.border),
        background = CopyStyleColor(fallback.background),
        text = CopyStyleColor(fallback.text),
        muted = CopyStyleColor(fallback.muted),
        backgroundTint = CopyStyleColor(fallback.backgroundTint),
        iconMode = fallback.iconMode,
        preset = "kui_crimson",
}
end

local function GetMenuPaletteColors()
    local palette = GetOptionsStylePalette()
    local accent = palette.accent or STYLE_PRESETS.kui_crimson.accent
    local background = palette.background or STYLE_PRESETS.kui_crimson.background
    local text = palette.text or STYLE_PRESETS.kui_crimson.text
    local muted = palette.muted or STYLE_PRESETS.kui_crimson.muted
    return palette, accent, background, text, muted
end

GetMenuAccentColor = function()
    local _, accent = GetMenuPaletteColors()
    return accent.r or 1, accent.g or 0, accent.b or 0.3333333333
end

local function GetMenuNavBackdropTint(isActive)
    local _, accent, background = GetMenuPaletteColors()
    local tint = BlendStyleColor(background, accent, isActive and 0.24 or 0.12)
    return tint.r or 0.03, tint.g or 0.03, tint.b or 0.04, isActive and 0.96 or 0.90
end

local function ApplyMenuNavButtonTheme(btn, isActive)
    if not btn then
        return
    end

    local accentR, accentG, accentB = GetMenuAccentColor()

    if btn.selBg then
        btn.selBg:SetColorTexture(accentR, accentG, accentB, 0.16)
    end
    if btn.selBar then
        btn.selBar:SetColorTexture(accentR, accentG, accentB, 1)
    end
    if btn.iconBox then
        local bgR, bgG, bgB, bgA = GetMenuNavBackdropTint(isActive)
        if KT.AddBackdrop then
            KT:AddBackdrop(btn.iconBox, bgR, bgG, bgB, bgA)
        end
        if KT.AddBorder then
            KT:AddBorder(btn.iconBox, accentR, accentG, accentB, isActive and 0.75 or 0.35)
        end
    end
end

local function ApplyMenuScrollBarTheme(scrollBar)
    if not scrollBar then
        return
    end

    local _, accent, background = GetMenuPaletteColors()
    local thumb = scrollBar._thumb or (scrollBar.GetThumbTexture and scrollBar:GetThumbTexture()) or nil
    local trackBg = scrollBar._trackBg
    local trackL = scrollBar._trackL
    local trackR = scrollBar._trackR
    local trackTint = BlendStyleColor(background, accent, 0.18)

    if thumb and thumb.SetVertexColor then
        thumb:SetVertexColor(accent.r or 1, accent.g or 0, accent.b or 0.3333333333, 0.9)
    end
    if trackBg and trackBg.SetColorTexture then
        trackBg:SetColorTexture(trackTint.r or 0.06, trackTint.g or 0.06, trackTint.b or 0.08, 0.72)
    end
    if trackL and trackL.SetColorTexture then
        trackL:SetColorTexture(accent.r or 1, accent.g or 0, accent.b or 0.3333333333, 0.4)
    end
    if trackR and trackR.SetColorTexture then
        trackR:SetColorTexture(accent.r or 1, accent.g or 0, accent.b or 0.3333333333, 0.4)
    end
end

local function SyncSmartStyleDerivedTargets()
    local profile = KT and KT.db and KT.db.profile
    if not profile then return end

    profile.skin = profile.skin or {}
    local skin = profile.skin
    local accent = CopyStyleColor(KT_GetActiveAccent(skin))
    local background = CopyStyleColor(skin.backgroundColor or STYLE_PRESETS.kui_crimson.background)
    local text = CopyStyleColor(skin.menuTextColor or STYLE_PRESETS.kui_crimson.text)
    local muted = CopyStyleColor(skin.menuSubtextColor or STYLE_PRESETS.kui_crimson.muted)

    skin.borderColor = CopyStyleColor(skin.borderColor or accent)
    skin.headerColor = BlendStyleColor(background, accent, 0.18)

    if profile.chat then
        profile.chat.highlightColor = CopyStyleColor(accent)
        profile.chat.panelColor = MakeStyleColor(background.r, background.g, background.b, 0.10)
    end
    if profile.bags then
        profile.bags.panelColor = MakeStyleColor(background.r, background.g, background.b, 0.94)
    end
    if profile.actionbars then
        profile.actionbars.buttonBackdropColor = MakeStyleColor(background.r, background.g, background.b, 0.74)
    end
    if profile.castbar then
        if profile.castbar.colorMode == nil then
            profile.castbar.colorMode = "THEME"
        end
        if profile.castbar.colorMode == "THEME" then
            profile.castbar.color = CopyStyleColor(accent)
        end
        profile.castbar.textColor = CopyStyleColor(text)
    end
    if profile.tooltip then
        profile.tooltip.textColor = CopyStyleColor(text)
    end
    if profile.blizzframes then
        profile.blizzframes.trackerColor = CopyStyleColor(accent)
    end
    if profile.armory then
        profile.armory.separatorColor = CopyStyleColor(accent)
        profile.armory.statsColor = CopyStyleColor(text)
    end
    if profile.inspectArmory then
        profile.inspectArmory.avgIlvlColor = CopyStyleColor(accent)
    end
    if profile.cooldownManager and profile.cooldownManager.cdmBars and profile.cooldownManager.cdmBars.bars then
        for _, bar in ipairs(profile.cooldownManager.cdmBars.bars) do
            bar.bgR = background.r
            bar.bgG = background.g
            bar.bgB = background.b
        end
    end

    profile.skin.menuTextColor = CopyStyleColor(text)
    profile.skin.menuSubtextColor = CopyStyleColor(muted)
end

function KT:NormalizeStyleState()
    local profile = self and self.db and self.db.profile
    if not profile then return end

    profile.skin = profile.skin or {}
    local skin = profile.skin
    local presetKey = skin.stylePreset
    local preset = presetKey and presetKey ~= "custom" and STYLE_PRESETS[presetKey] or nil

    if preset then
        skin.accentColor = CopyStyleColor(preset.accent)
        skin.borderColor = CopyStyleColor(preset.border or preset.accent)
        skin.backgroundColor = CopyStyleColor(preset.background)
        skin.menuTextColor = CopyStyleColor(preset.text)
        skin.menuSubtextColor = CopyStyleColor(preset.muted)
        skin.menuBackgroundTint = CopyStyleColor(preset.backgroundTint or preset.accent)
        skin.menuIconColorMode = preset.iconMode or "accent"
        skin.headerColor = BlendStyleColor(skin.backgroundColor, skin.accentColor, 0.18)
    end

    SyncSmartStyleDerivedTargets()
end

local function RefreshSmartStyleLive()
    if KT and KT.NormalizeStyleState then
        KT:NormalizeStyleState()
    end
    if KT and KT.RefreshStylePalette then
        KT:RefreshStylePalette()
    end
    if KT and KT.MenuPrincipal and KT.MenuPrincipal.RefreshTheme then
        KT.MenuPrincipal:RefreshTheme()
    end
    if KT and KT.GetModule then
        local castbar = KT:GetModule("CastBar", true)
        if castbar and castbar.Refresh then
            castbar:Refresh()
        end
        local cursor = KT:GetModule("Cursor", true)
        if cursor and cursor.ApplySettings then
            cursor:ApplySettings()
        end
        local minimap = KT:GetModule("Minimap", true)
        if minimap and minimap.UpdateSocialMinimapIconStyle then
            minimap:UpdateSocialMinimapIconStyle()
        end
        local unlockMode = KT:GetModule("UnlockMode", true)
        if unlockMode and unlockMode.isOpen and unlockMode.ApplyTheme then
            unlockMode:ApplyTheme()
        end
    end
    if KT and KT.RefreshPage then
        KT:RefreshPage(true)
    end
end

local function ApplySmartStylePreset(styleKey)
    local profile = KT and KT.db and KT.db.profile
    local preset = styleKey and STYLE_PRESETS[styleKey] or nil
    if not (profile and preset) then
        return
    end

    profile.skin = profile.skin or {}
    local skin = profile.skin
    profile.castbar = profile.castbar or {}
    profile.castbar.colorMode = "THEME"
    skin.kullthranUIColorByClass = false
    skin.borderTheme = "KULLTHRAN"
    skin.borderThemeBeforeClass = "KULLTHRAN"
    skin.stylePreset = styleKey
    skin.accentColor = CopyStyleColor(preset.accent)
    skin.borderColor = CopyStyleColor(preset.border or preset.accent)
    skin.backgroundColor = CopyStyleColor(preset.background)
    skin.menuTextColor = CopyStyleColor(preset.text)
    skin.menuSubtextColor = CopyStyleColor(preset.muted)
    skin.menuBackgroundTint = CopyStyleColor(preset.backgroundTint or preset.accent)
    skin.menuIconColorMode = preset.iconMode or "accent"
    skin.friendListColorMode = "accent"
    skin.friendListColor = nil
    skin.armoryColorMode = "accent"
    skin.armoryColor = nil
    skin.bagsColorMode = "accent"
    skin.bagsColor = nil

    SyncSmartStyleDerivedTargets()
    RefreshSmartStyleLive()
end

KT.STYLE_PRESETS = STYLE_PRESETS
KT.ApplySmartStylePreset = ApplySmartStylePreset
KT.SyncSmartStyleDerivedTargets = SyncSmartStyleDerivedTargets

local function ApplyMenuNavButtonIconStyle(btn)
    if not (btn and btn.ico) then return end
    local r, g, b = GetMenuIconVertexColor(btn._iconName or "")
    btn.ico:SetVertexColor(r, g, b, 1)
end

local function ApplyMenuNavButtonIconLayout(btn, pageId)
    if not (btn and btn.ico) then return end
    local style = ns.PAGE_ICON_STYLE_MAP[pageId] or {}
    btn.ico:ClearAllPoints()
    btn.ico:SetPoint("CENTER", style.offsetX or 0, style.offsetY or 0)
    btn.ico:SetSize(style.width or 60, style.height or 40)
    if style.texCoord then
        btn.ico:SetTexCoord(unpack(style.texCoord))
    else
        btn.ico:SetTexCoord(0, 1, 0, 1)
    end
end

local function ApplySearchResultIconLayout(texture, anchor, pageId)
    if not (texture and anchor) then return end

    local style = ns.PAGE_ICON_STYLE_MAP[pageId] or {}
    local baseWidth = style.width or 60
    local baseHeight = style.height or 40
    local scale = math.min(24 / baseWidth, 16 / baseHeight)

    texture:ClearAllPoints()
    texture:SetPoint("RIGHT", anchor, "LEFT", -6, (style.offsetY or 0) * scale)
    texture:SetSize(
        math.max(1, math.floor((baseWidth * scale) + 0.5)),
        math.max(1, math.floor((baseHeight * scale) + 0.5))
    )
    if style.texCoord then
        texture:SetTexCoord(unpack(style.texCoord))
    else
        texture:SetTexCoord(0, 1, 0, 1)
    end
end

local function RefreshMenuNavIcons()
    if type(ns.navButtons) == "table" then
        for _, btn in pairs(ns.navButtons) do
            ApplyMenuNavButtonIconStyle(btn)
        end
    end
    if type(ns.categoryButtons) == "table" then
        for _, btn in pairs(ns.categoryButtons) do
            ApplyMenuNavButtonIconStyle(btn)
        end
    end
    if KT and KT.MenuPrincipal and KT.MenuPrincipal._ktUnlockShortcut then
        ApplyMenuNavButtonIconStyle(KT.MenuPrincipal._ktUnlockShortcut)
    end
end

-- ============================================================================
-- GENERAL: UnlockMode shortcut button (header action)
-- ============================================================================
local UNLOCKMODE_BUTTON_HEIGHT = 56
local UNLOCKMODE_ICON_NAME = "UnlockMode"
local NAV_SCROLL_TOP_GAP = 16
local NAV_SCROLL_BOTTOM_GAP = 18
local NAV_CONTENT_TOP_PADDING = 4

local function EnsureUnlockModeShortcut(menu)
    if not menu then return end
    if menu._ktUnlockShortcut then
        return menu._ktUnlockShortcut
    end

    local parent = menu._navHost or menu
    local accentR, accentG, accentB = GetMenuAccentColor()
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(UNLOCKMODE_BUTTON_HEIGHT)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -10)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -28, -10)
    btn:SetFrameLevel((menu and menu.GetFrameLevel and menu:GetFrameLevel() or 0) + 50)
    btn:SetAlpha(0.55)

    local selBg = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
    selBg:SetAllPoints()
    selBg:SetColorTexture(accentR, accentG, accentB, 0.16)
    selBg:Hide()
    btn.selBg = selBg

    local selBar = btn:CreateTexture(nil, "ARTWORK")
    selBar:SetWidth(6)
    selBar:SetPoint("LEFT")
    selBar:SetPoint("TOPLEFT")
    selBar:SetPoint("BOTTOMLEFT")
    selBar:SetColorTexture(accentR, accentG, accentB, 1)
    selBar:Hide()
    btn.selBar = selBar

    local sep = btn:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 0)
    sep:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -8, 0)
    sep:SetColorTexture(1, 1, 1, 0.05)
    btn.sep = sep

    local iconBox = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    iconBox:SetSize(72, 48)
    iconBox:SetPoint("LEFT", btn, "LEFT", 16, 0)
    btn.iconBox = iconBox
    ApplyMenuNavButtonTheme(btn, false)

    local ico = iconBox:CreateTexture(nil, "OVERLAY")
    ico:SetSize(60, 40)
    ico:SetPoint("CENTER")
    ico:SetTexture(ICON_PATH .. UNLOCKMODE_ICON_NAME .. ".png")
    btn._iconName = UNLOCKMODE_ICON_NAME
    btn.ico = ico
    ApplyMenuNavButtonIconStyle(btn)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(KT.FONT_PATH, 14, "OUTLINE")
    label:SetPoint("LEFT", iconBox, "RIGHT", 16, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -16, 0)
    label:SetJustifyH("LEFT")
    label:SetText(LocalizeText("KUI Unlock Mode"))
    label:SetTextColor(0.78, 0.78, 0.78, 1)
    btn.label = label

    local hov = btn:CreateTexture(nil, "BACKGROUND")
    hov:SetAllPoints()
    hov:SetColorTexture(1, 1, 1, 0)
    btn._hov = hov

    local function GetUnlockModeModule()
        if KT and KT.GetModule then
            return KT:GetModule("UnlockMode", true)
        end
    end

    local function IsUnlockModeOpen()
        local um = GetUnlockModeModule()
        return (um and um.isOpen) or (KT and KT._unlockActive) or false
    end

    local function UpdateVisual()
        local isOpen = IsUnlockModeOpen()
        ApplyMenuNavButtonIconStyle(btn)

        local isHovered = btn.IsMouseOver and btn:IsShown() and btn:IsMouseOver()
        btn._hov:SetColorTexture(1, 1, 1, (isHovered and not isOpen) and 0.05 or 0)

        if isOpen then
            btn:SetAlpha(1)
            btn.selBg:Show()
            btn.selBar:Show()
            btn.iconBox:SetAlpha(1)
            ApplyMenuNavButtonTheme(btn, true)
            label:SetTextColor(1, 1, 1, 1)
        else
            btn:SetAlpha(0.55)
            btn.selBg:Hide()
            btn.selBar:Hide()
            btn.iconBox:SetAlpha(0.92)
            ApplyMenuNavButtonTheme(btn, false)
            label:SetTextColor(0.78, 0.78, 0.78, 1)
        end
    end

    btn:SetScript("OnEnter", function(self)
        if not IsUnlockModeOpen() then
            self._hov:SetColorTexture(1, 1, 1, 0.05)
        end
        if KT.AddBorder and self.iconBox then
            KT:AddBorder(self.iconBox, 1, 1, 1, 0.45)
        end
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(LocalizeText("KUI Unlock Mode"), 1, 1, 1)
            GameTooltip:AddLine(LocalizeText("Click to toggle KullThranUI Unlock Mode."), 0.75, 0.75, 0.75, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
        self._hov:SetColorTexture(1, 1, 1, 0)
        if GameTooltip then GameTooltip:Hide() end
        UpdateVisual()
    end)
    btn:SetScript("OnClick", function()
        local um = GetUnlockModeModule()
        if um and um.ToggleUnlockMode then
            um:ToggleUnlockMode()
        elseif KT and KT.Print then
            KT:Print(LocalizeText("|cffFF4444UnlockMode|r: module not available."))
        end

        if C_Timer then
            C_Timer.After(0, UpdateVisual)
            C_Timer.After(0.25, UpdateVisual)
        else
            UpdateVisual()
        end
    end)

    btn.UpdateVisual = UpdateVisual
    btn:Hide()

    menu._ktUnlockShortcut = btn
    return btn
end

local function UpdateUnlockModeShortcut(menu, pageId)
    if not menu then return end
    local btn = EnsureUnlockModeShortcut(menu)
    if not btn then return end

    if pageId then
        btn:Show()
        if btn.UpdateVisual then btn:UpdateVisual() end
    else
        btn:Hide()
    end
end

-- ============================================================================
-- HELPERS DE MEDIA
-- ============================================================================
local function GetFontValues()
    local v = {}
    if LSM then
        for _, n in ipairs(LSM:List("font")) do
            if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(n) then
                v[n] = (n == "Friz Quadrata TT") and "Friz Quadrata TT (Blizzard)" or n
            end
        end
    end
    if not next(v) then
        local def = (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "AAA_ITC_Avant_Garde"
        v[def] = def
    end
    return v
end
local fontPreviewAliases = {}
local function NormalizeFontMediaPath(path)
    if type(path) ~= "string" then return nil end
    return path:gsub("/", string.char(92)):lower()
end
local function ResolveRegisteredFontName(value)
    if type(value) ~= "string" or value == "" then
        return KT.DEFAULT_FONT_NAME or "AAA_ITC_Avant_Garde"
    end

    local values = GetFontValues()
    if values[value] then return value end

    local targetPath = NormalizeFontMediaPath(value)
    if LSM and targetPath then
        for _, name in ipairs(LSM:List("font")) do
            local registeredPath = LSM:Fetch("font", name, true)
            if NormalizeFontMediaPath(registeredPath) == targetPath then
                return name
            end
        end
    end

    if value:find("/", 1, true) or value:find(string.char(92), 1, true) then
        local leaf = value:gsub(string.char(92), "/"):match("([^/]+)$") or value
        local displayName = leaf:gsub("%.[^%.]+$", "")
        fontPreviewAliases[displayName] = value
        return displayName
    end

    return value
end
local function ResolveFontPreviewPath(value)
    local aliasPath = fontPreviewAliases[value]
    if aliasPath then return aliasPath end

    local name = ResolveRegisteredFontName(value)
    if KT.ResolveFontPath then
        return KT:ResolveFontPath(name)
    end
    if LSM then
        return LSM:Fetch("font", name, true)
    end
    return type(value) == "string" and value or nil
end
local function GetStatusbarValues()
    local v = {}
    if LSM then for _, n in ipairs(LSM:List("statusbar")) do v[n] = n end end
    return v
end
local function GetBackgroundValues()
    local v = {}
    if LSM then for _, n in ipairs(LSM:List("background")) do v[n] = n end end
    return v
end
local function Reload() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local function ResetConfirm() StaticPopup_Show("KULLTHRANUI_RESET_CONFIRM") end

-- ============================================================================
-- LOCALIZATION
-- ============================================================================
local function LText(text)
    return LocalizeText(text)
end

local function LTextFmt(text, ...)
    local fmt = LText(text)
    if select("#", ...) > 0 then
        return string.format(fmt, ...)
    end
    return fmt
end

local CHANGELOG_WAGO_URL = "https://addons.wago.io/addons/kullthranui/versions"
local CHANGELOG_FILES_URL = "https://www.curseforge.com/wow/addons/kui-kullthranui/files/all?page=1&pageSize=20&showAlphaFiles=show"
local CHANGELOG_DISCORD_URL = "https://discord.gg/cqAVWpeVvd"

local function EnsureDiscordPopupDialog()
    if not _G.StaticPopupDialogs then
        return
    end

    if _G.StaticPopupDialogs["KULLTHRANUI_DISCORD"] then
        return
    end

    _G.StaticPopupDialogs["KULLTHRANUI_DISCORD"] = {
        text = "KullThranUI Discord",
        button1 = CLOSE or "Close",
        hasEditBox = true,
        editBoxWidth = 320,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnShow = function(self)
            local editBox = self.EditBox or self.editBox
            if editBox then
                editBox:SetText(CHANGELOG_DISCORD_URL)
                if editBox.HighlightText then
                    editBox:HighlightText()
                end
                if editBox.SetFocus then
                    editBox:SetFocus()
                end
            end
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
}
end

local function ShowDiscordPopup()
    EnsureDiscordPopupDialog()
    if _G.StaticPopup_Show then
        _G.StaticPopup_Show("KULLTHRANUI_DISCORD")
    end
end
-- AUTO-CHANGELOG-LATEST:BEGIN
local CHANGELOG_LATEST_ARCHIVED_VERSION = "5.0.6"
-- AUTO-CHANGELOG-LATEST:END
-- AUTO-CHANGELOG:BEGIN
local CHANGELOG_ENTRIES = {
    ["5.0.6"] = {
        version = "5.0.6",
        published = "2026-09-12",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "KullThranUI Changelog",
            "Current addon version: 5.0.6",
            "Primary source: https://addons.wago.io/addons/kullthranui/versions",
            "Secondary source: https://www.curseforge.com/wow/addons/kui-kullthranui/files/all?page=1&pageSize=20&showAlphaFiles=show",
            "5.0.6 (2026-09-12)",
            "New Feature: Mythic+ History. A detailed Mythic+ history has been added to the Enhancements module, allowing you to track completed keys and view a keystone summary breakdown, including a damage meter to see who did the most DPS during the run. NOTE: The Mythic+ History will only display all party members after activating the submodule, as KullThranUI needs to start saving the runs internally from that point forward.",
            "Localization updates: Translations have been applied across all KullThranUI modules. Localization and compatibility have been expanded to cover 97% of the addon and its features. Added country flags to easily     distinguish languages. Fixed translation errors across several Widget elements and the Enhancements submodule.",
            "Skins module update: New visual style applied. Improved the visibility and overall readability of the reskinned default Blizzard frames.",
            "Added a scrollbar to the Widget system. It will now appear automatically in all modules that have enough options to require scrolling.",
            "Added a Minimap button to open KUI options directly.",
            "Fixed an issue in the Objective Tracker where the 'Scenario' header would display even when not inside an instance.",
            "Fixed KUI Tracker behavior in the CooldownManager. Potion and Warlock Healthstone cooldowns will now properly reset after a raid boss wipe/reset (when the appropriate conditions are met).",
            "KullThranUI is now officially available on GitHub! Future updates for CurseForge and Wago will be deployed from there, and Pull Requests will soon be enabled so the community can help improve translations.",
            "5.0.5 (2026-09-05)",
            "Added a configurable Combat Timer to Enhancements, with an idle display, a short final-duration hold, styling controls, Unlock Mode support, and a frame width that follows the rendered timer text.",
            "Promoted Melli Reforged to the default status-bar texture across KUI, including a one-time Resource Bars migration from Melli and synchronized texture selection for health, primary, and secondary resources.",
            "Added per-module profile import and export controls to options pages and corrected profile ownership for Action Bars, Bags, Progress Bars, External Addons, Enhancements, and other scoped settings.",
            "Expanded Nameplates target highlighting with multiple indicator styles, reversible direction, indicator shadow glow, configurable indicator and target-glow colors, scaling, previews, and preset support.",
            "Refined the Nameplates Display live preview with compact one-row font, outline, and bar-texture selectors, and fixed health-bar clicks so they open the corresponding size settings.",
            "Improved SharedMedia selectors throughout KUI with complete registered font and texture lists, inline previews, dependable scrolling, and support for media added by other addons.",
            "Reworked the Cooldown Manager potion tracker with stable combat, health, healthstone, and optional mana slots, selectable potion quality, corrected Midnight item ranks, and combat-safe layout updates.",
            "Restored Action Bars hotkeys, overlay glows, mouseover behavior, bindings refreshes, and visual enhancements on protected buttons while isolating unsafe cooldown hooks for Midnight APIs.",
            "Updated Aura Reminders for Midnight Season 2 with locale-independent instance IDs, spell icons, scrollable talent selectors, and compatibility with older name-based reminders.",
            "Improved Party Frames with selectable SharedMedia health and absorb textures, matching live previews, and missing-buff reminders that ignore non-player companions and scenario NPCs.",
            "Extended Unit Frames with Melli Reforged defaults, full SharedMedia font and status-bar support per unit, live media previews, and a corrected Default Texture control.",
            "Reworked Character and Armory navigation with accent-aware Stats, Titles, Equipment, and Progress tabs, more reliable pane visibility, and a compact configuration button beside the close control.",
            "Hardened Enhanced Friend List raid navigation by passing protected roster clicks through Blizzard's native control and correctly restoring or suppressing the native frame artwork.",
            "Fixed the dedicated Group chat tab so it receives the complete native group-message set while respecting secure and combat-locked chat restrictions.",
            "Refined the minimap button drawer so it captures only genuine addon launchers, leaves Expansion Summary, waypoints, POIs, and scanner pins untouched, and restores original button sizes.",
            "Expanded the Tooltip live preview with real player identity, guild, specialization, faction, item level, Mythic+ or PvP score, raid progress, and class-colored health styling.",
            "Added a configurable Great Vault skin, refined World Map breadcrumbs and search styling, fixed Ready Check decision labels, and removed the duplicate protected Game Menu skin path.",
            "Hardened the Escape Menu against FrameMeasurement taint by removing unsafe enumeration of foreign overlay frames anchored to protected nameplates.",
            "5.0.4 (2026-09-01)",
            "Fixed Ready Check layouts for both incoming and self-initiated checks, removing leftover Blizzard artwork and the empty panel behind consumable trackers.",
            "Eliminated periodic Cooldown Manager combat freezes by coalescing tracker refreshes and avoiding repeated inventory, tooltip, and item-spell scans.",
            "Reduced Nameplates interrupt-tracker overhead by replacing global cooldown-event rebuilds with lightweight local ticker updates.",
            "Expanded /ktfreeze diagnostics with event/addon attribution and Lua allocation/GC tracking without intrusive global CPU polling.",
            "Reworked Enhancements with a Mythic+ timer that owns its tracker presentation, key details, forces progress, deaths, boss objectives, chest thresholds, and completion state.",
            "Expanded Mythic+ timer configuration with independent fonts, textures, sizes, widths, heights, colours, glow controls, chest-one, chest-two, chest-three, and forces-bar typography, plus a remaining-time-only display with localized forces text.",
            "Made SharedMedia font and texture selectors complete and usable throughout Enhancements, including installed fonts and textures, inline preview rendering in dropdowns, left-aligned option labels, and corrected selector placement.",
            "Reworked Damage Meter configuration and preview with realistic player/spec data, working dynamic Blizzard window discovery, font and texture controls, centered bar layout, selectable spec/class/hidden player icons, rounded icon support, and corrected bar spacing.",
            "Added automatic LFG role-check controls under Automation & Social, including selectable Tank, Healer, and Damage roles and automatic confirmation when queueing alone or with a group.",
            "Refined Enhancements navigation with module-specific artwork, accent-coloured icons, the red sword Damage Meter icon, Blizzard chat artwork for Automation & Social, and clearer Interface & Comfort and System Tuning references.",
            "Hardened LFG and popup skins for current Retail UI changes, including accent-only queue-ready borders, working close buttons, black uncovered popup surfaces, preserved dungeon artwork, and safer handling of native NineSlice and border textures.",
            "Fixed the KUI Unlock Mode navigation state so closing and reopening the main options window cannot leave Unlock Mode visually selected as the active page.",
            "Completed the Enhancements localization pass across the supported locales for the new timer, Damage Meter, LFG automation, typography, texture, forces, preview, and navigation strings.",
            "5.0.3 (2026-08-29)",
            "Restored reliable per-conversation whisper capture on secure-chat builds by mirroring Blizzard-rendered whisper lines into KUI history, including Battle.net conversations, without bypassing the selected whisper thread.",
            "Hardened Chat integration for protected message and channel data by avoiding unsafe native filter and channel-list mutations, preventing taint attribution and protected-table failures during PvP and other restricted chat dispatches.",
            "5.0.2 (2026-08-29)",
            "Reworked first-time setup for new characters with a dedicated starting-profile choice, allowing existing saved profiles to be selected or KUI defaults to be used without forcing every character onto the KullThranUI profile.",
            "Improved Installer and profile startup handling with stable per-character tracking, safer specialization-profile transitions, correct layout imports into the active profile, and more reliable continuation through conflict detection and setup.",
            "Expanded the Fonts & Colors page with live font previews, a separate Launcher and Options font, individual typography controls for major HUD, social, character, and inspection areas, and additional color controls for interface surfaces, action bars, progress displays, Chat, Armory, and Inspect.",
            "Reworked global font inheritance so modules that still follow the global font update together while explicitly customized areas preserve their own selection, with combat-safe deferred refreshes across the supported interface.",
            "Refined the main configuration window with an accent-colored KUI logo, a new resize grip, a slimmer navigation scrollbar, immediate minimap social-icon recoloring, and a scalable nine-slice background that preserves its proportions at preset and custom window sizes.",
            "Redesigned KUI Unlock Mode with a wider and cleaner sidebar, clearer active-element feedback, improved mover menus, direct access to profile importing, an animated opening logo, and an automatically retracting sidebar that remains available from the edge of the screen.",
            "Improved the in-game changelog window so its complete â€œDonâ€™t show againâ€ row is clickable, the current patch suppression state is restored correctly, and enabling or disabling the option is saved immediately.",
            "Hardened Chat against protected edit-box state changes during combat, preventing unsafe whisper, Battle.net, and chat-type mutations while retaining the normal input flow outside combat.",
            "Reduced Cooldown Manager background work by replacing continuous glow polling with coalesced event-driven updates, refreshing only affected bars when possible, and avoiding redundant transition passes once Blizzardâ€™s Cooldown Viewer pools have stabilized.",
            "Improved Cooldown Manager trackers by hiding unavailable potion items, keeping owned potion ranks synchronized, stabilizing player and target frame anchoring around narrow CDM layouts, and making arena, battleground, specialization, and world-transition recovery more selective.",
            "Reworked centered horizontal Party and Arena layouts so the player remains in the intended middle position as the group fills, with a corrected bottom-center default position for horizontal Party Frames.",
            "Improved Party Frames range, phase, roster, aura, and encounter handling with more reliable out-of-range recovery, independent dispel indicators, properly layered AuraKit dispel effects, boss-frame activation during encounters, and fewer unnecessary full roster rebuilds while zoning.",
            "Refined Modern KUI group-interface skins with complete accent borders for selected LFG entries, clearer role-selection feedback, and a rebuilt Ready Check presentation with restored portraits, dedicated Ready and Not Ready buttons, consistent surfaces, and accent-aware artwork.",
            "5.0.1 (2026-08-26)",
            "Restored reliable first-run Installer startup for new users and brought back the visible \"Don't show again\" control, with synchronized login settings so the prompt can be disabled or re-enabled cleanly.",
            "Hardened Chat against protected and secret PvP payloads, preventing duplicated battleground system messages while preserving Blizzard's native message handling.",
            "Restored access to Blizzard's Group Management controls, including raid and world-marker tools, when KullThranUI Party Frames are active.",
            "Improved Party Frames during PvP and arena transitions with safer protected-unit handling and more reliable roster, role, raid-target, and aura refreshes.",
            "Fixed KullThranUI Bags tainting Blizzard's protected container click path, restoring item use, equipping, dragging, and background drops without UseContainerItem() forbidden-action errors.",
            "5.0.0 (2026-08-25)",
            "Redesigned the main KullThranUI configuration window around expandable module categories, with dedicated 60x40 category artwork, compact module shortcuts, persistent multi-category expansion, and reliable toggling from both the category row and its arrow.",
            "Added category overview pages that present every available module as a large shortcut card with its icon and a concise description, while keeping the most recently selected category open in the right-hand panel.",
            "Corrected category selection and navigation feedback so only the active category remains highlighted, module counts appear only on category overview pages, and expanded categories can coexist without changing the active page.",
            "Refined the global options presentation with a slightly brighter panel background, consistent category-arrow artwork based on the KUI minimap button, and cleaner icon, spacing, and selected-state behavior throughout the sidebar.",
            "Reworked private whisper persistence so opened character and Battle.net conversations can survive a UI reload, including conversations opened before any message is exchanged, while closed conversations remain dismissed and session state is cleared on disconnect.",
            "Hardened Chat against protected and secret strings when capturing whisper targets or copying chat history, and prevented closed temporary Blizzard whisper windows from reopening automatically.",
            "Corrected Action Bar cooldown presentation so active cooldowns use a properly darkened swipe over every supported button shape instead of retaining the normal colored background.",
            "Rebuilt Damage Meter player pinning around a Details-style pinned final row: the player remains visible without corrupting the real ranking order, scrolling can inspect the complete list, and combat-start refreshes no longer push the meter to an unrelated position.",
            "Improved Damage Meter combat-session handling, saved history, protected-value support, and live refresh scheduling to avoid redundant delayed updates during continuous combat events.",
            "Added a genuinely opaque Objective Tracker background mode with a solid black surface, an accent-colored top border, and an accurate live preview that cannot inherit the legacy gradient or fade.",
            "Expanded Armory PvP item-level support with a working live-preview indicator and independent controls for visibility, label, decimals, font, size, outline, color, and horizontal or vertical positioning.",
            "Repositioned Installer Party Frame test controls into a compact left-aligned group so Party, Raid, and Raid 40 tests no longer overlap or distort the live preview.",
            "Significantly reduced Party Frames update cost through unit-scoped event registration, coalesced aura refreshes, bounded absorb queues, cached aura state, and a centralized duration driver that runs only while required.",
            "Improved Nameplates runtime efficiency with reusable frame pooling and cached threat, quest-target, and contextual state, reducing repeated allocation and expensive unit scans during combat.",
            "Optimized Resource Bars to reuse resolved layout and marker data and to update ranges, values, and text only when their relevant unit state changes.",
            "Extended protected and secret-value safeguards across Party Frames, Resource Bars, Nameplates, Chat, Damage Meter, and other high-frequency combat paths for improved Midnight API compatibility.",
            "Added and reviewed localization for the new 5.0.0 category pages, Objective Tracker background controls, Armory PvP item-level settings, and related interface text across every supported language.",
            "Improved package hygiene by removing unused development artifacts, reference trees, duplicate media, temporary scripts, and unreferenced external resources, and added a KullThranUI license that explicitly preserves third-party ownership and licensing terms.",
            "4.1.5 (2026-08-23)",
            "Reworked the Installer flow so first-time setup opens reliably for every character, reload-required changes return to the exact previous step, and the Installer can be opened directly with `/installer` or `/ins`.",
            "Expanded the Installer with a dedicated Resource Bars step, clearer module enable and disable behavior, localized reload prompts, improved pressed-state feedback, and the correct KullThranUI background across every page.",
            "Redesigned Installer previews for Action Bars, Buffs & Debuffs, Party Frames, Resource Bars, Nameplates, and Armory so configuration choices use realistic layouts, class abilities, aura examples, and their actual icon shapes.",
            "Restored shape support across Action Bars, Buffs & Debuffs, and Cooldown Manager, including masked cooldown swipes, hotkeys rendered above masks, shape-aware selection feedback, and removal of square shadows from non-default shapes.",
            "Improved cooldown handling for protected and secret values, preventing repeated ActionButton and SetCooldown errors without relying on continuous texture updates.",
            "Reworked dispel and status overlays in Party Frames and Unit Frames for Magic, Poison, Curse, Disease, and Bleed effects, with the intended diffused presentation across party, raid, arena, and supported dungeon follower frames.",
            "Fixed friendly units retaining hostile colors after a duel and corrected additional reaction, target, and state refresh edge cases in Unit Frames and Party Frames.",
            "Improved Nameplates options with correctly initialized default slider values and search-style highlights restricted to the relevant configuration gears instead of covering complete option rows.",
            "Corrected Armory live previews so empty equipment slots remain empty, displayed stats match the real panel, and movement speed is calculated from the appropriate game values.",
            "Expanded and refined Modern KUI skins for Trade, Ready Check, Arena Shuffle, group invitations, role popups, PvP inspection, consumable frames, and other Blizzard dialogs.",
            "Fixed missing role icons in group invitation and acceptance popups, accent colors not applying to Ready Check consumables, and popup errors caused by invalid texture layers or unsafe hooks.",
            "Improved Enhanced Friend List invite-button styling so the original artwork follows the active accent instead of being replaced or remaining white.",
            "Reorganized minimap utility buttons outside the map with dedicated Calendar, Tracking, Mail, Friends, Guild, and Teleport Menu controls, consistent Modern KUI backgrounds, accent-aware social icons, and pixel-perfect edge anchoring.",
            "Separated Teleport Menu from the KullThranUI minimap-button collector, added a dedicated custom portal button and corrected label, and replaced the menu settings icon with the standard KUI gear artwork.",
            "4.1.4 (2026-08-21)",
            "Reworked Buffs & Debuffs with fully custom AuraKit containers managed through KUI Unlock Mode, preserving existing user positions during migration and applying consistent minimap-relative defaults and spacing.",
            "Restored the original Masque Simplicity appearance for auras, fixed weapon-enchant text initialization, improved the live preview layout, and made short durations clearly distinguishable from application counts.",
            "Optimized Buffs & Debuffs aura processing and improved icon reliability under the protected and secret aura restrictions used during combat.",
            "Reworked Cooldown Manager update scheduling to eliminate redundant full refreshes caused by cooldown and aura event storms, substantially reducing combat CPU usage.",
            "Fixed inconsistent CDM proc glows, missing or incorrectly spaced buff-bar icons, protected icon visibility errors, and tracking failures after the first use of an ability or item.",
            "Restored KUI Tracker defensive, racial, potion, and trinket tracking in raids and Mythic+, corrected potion rank and quantity selection, improved cooldown text visibility, and added reliable feedback for passive trinket procs.",
            "Added a Modern KUI skin for Blizzard's native Cooldown Manager and a direct button in KUI CDM options to open it, with combat-safe loading and proper support for its frame-based side tabs.",
            "Fixed a severe Bags performance issue caused by cooldown events. Bag item cooldowns now update incrementally, including Hearthstones, while item-level text is restricted to actual equipment.",
            "Added the `/ktcombat` combat profiler with per-addon CPU deltas, event counters, spike tracking, and detailed CDM phase and bar diagnostics.",
            "Optimized Party Frames aura and event processing in both idle and combat, restored dispel-type textures, and corrected AFK and Raid Assistant icons across group, raid, and Raid 40 layouts.",
            "Improved protected-frame handling across Unit Frames, Nameplates, Party Frames, and Cooldown Manager to prevent taint errors and forbidden frame-strata or visibility operations.",
            "Fixed the Damage Meter scrolling to random ranking sections and ensured that a manually selected top position remains stable while combat data updates.",
            "Corrected Armory movement-speed calculations and rebuilt stat-label sizing to prevent overlap without unnecessarily truncating Intellect, Stamina, Critical Strike, Mastery, and other labels.",
            "Fixed misplaced private whisper windows and prevented hidden Friends controls from intercepting right-clicks while the Social window is closed.",
            "Repaired Enhanced Friend List layout and interaction regressions, removed the Lua local-variable limit warning and nil-function error, and restored reliable opening, refreshing, and button behavior.",
            "Fixed missing role artwork in group invitations, the dark lower section of self-initiated Ready Checks, and Release Spirit availability during raid and Mythic boss encounters where releasing is not allowed.",
            "Fixed Aura Reminders continuing to request food after the player had already eaten from a feast.",
            "Improved Guild, LFG, popup, and Objective Tracker skin behavior and corrected several profile and localization edge cases.",
        },
    },
    ["5.0.5"] = {
        version = "5.0.5",
        published = "2026-09-05",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Added a configurable Combat Timer to Enhancements, with an idle display, a short final-duration hold, styling controls, Unlock Mode support, and a frame width that follows the rendered timer text.",
            "Promoted Melli Reforged to the default status-bar texture across KUI, including a one-time Resource Bars migration from Melli and synchronized texture selection for health, primary, and secondary resources.",
            "Added per-module profile import and export controls to options pages and corrected profile ownership for Action Bars, Bags, Progress Bars, External Addons, Enhancements, and other scoped settings.",
            "Expanded Nameplates target highlighting with multiple indicator styles, reversible direction, indicator shadow glow, configurable indicator and target-glow colors, scaling, previews, and preset support.",
            "Refined the Nameplates Display live preview with compact one-row font, outline, and bar-texture selectors, and fixed health-bar clicks so they open the corresponding size settings.",
            "Improved SharedMedia selectors throughout KUI with complete registered font and texture lists, inline previews, dependable scrolling, and support for media added by other addons.",
            "Reworked the Cooldown Manager potion tracker with stable combat, health, healthstone, and optional mana slots, selectable potion quality, corrected Midnight item ranks, and combat-safe layout updates.",
            "Restored Action Bars hotkeys, overlay glows, mouseover behavior, bindings refreshes, and visual enhancements on protected buttons while isolating unsafe cooldown hooks for Midnight APIs.",
            "Updated Aura Reminders for Midnight Season 2 with locale-independent instance IDs, spell icons, scrollable talent selectors, and compatibility with older name-based reminders.",
            "Improved Party Frames with selectable SharedMedia health and absorb textures, matching live previews, and missing-buff reminders that ignore non-player companions and scenario NPCs.",
            "Extended Unit Frames with Melli Reforged defaults, full SharedMedia font and status-bar support per unit, live media previews, and a corrected Default Texture control.",
            "Reworked Character and Armory navigation with accent-aware Stats, Titles, Equipment, and Progress tabs, more reliable pane visibility, and a compact configuration button beside the close control.",
            "Hardened Enhanced Friend List raid navigation by passing protected roster clicks through Blizzard's native control and correctly restoring or suppressing the native frame artwork.",
            "Fixed the dedicated Group chat tab so it receives the complete native group-message set while respecting secure and combat-locked chat restrictions.",
            "Refined the minimap button drawer so it captures only genuine addon launchers, leaves Expansion Summary, waypoints, POIs, and scanner pins untouched, and restores original button sizes.",
            "Expanded the Tooltip live preview with real player identity, guild, specialization, faction, item level, Mythic+ or PvP score, raid progress, and class-colored health styling.",
            "Added a configurable Great Vault skin, refined World Map breadcrumbs and search styling, fixed Ready Check decision labels, and removed the duplicate protected Game Menu skin path.",
            "Hardened the Escape Menu against FrameMeasurement taint by removing unsafe enumeration of foreign overlay frames anchored to protected nameplates.",
        },
    },
    ["5.0.4"] = {
        version = "5.0.4",
        published = "2026-09-01",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Fixed Ready Check layouts for both incoming and self-initiated checks, removing leftover Blizzard artwork and the empty panel behind consumable trackers.",
            "Eliminated periodic Cooldown Manager combat freezes by coalescing tracker refreshes and avoiding repeated inventory, tooltip, and item-spell scans.",
            "Reduced Nameplates interrupt-tracker overhead by replacing global cooldown-event rebuilds with lightweight local ticker updates.",
            "Expanded /ktfreeze diagnostics with event/addon attribution and Lua allocation/GC tracking without intrusive global CPU polling.",
            "Reworked Enhancements with a Mythic+ timer that owns its tracker presentation, key details, forces progress, deaths, boss objectives, chest thresholds, and completion state.",
            "Expanded Mythic+ timer configuration with independent fonts, textures, sizes, widths, heights, colours, glow controls, chest-one, chest-two, chest-three, and forces-bar typography, plus a remaining-time-only display with localized forces text.",
            "Made SharedMedia font and texture selectors complete and usable throughout Enhancements, including installed fonts and textures, inline preview rendering in dropdowns, left-aligned option labels, and corrected selector placement.",
            "Reworked Damage Meter configuration and preview with realistic player/spec data, working dynamic Blizzard window discovery, font and texture controls, centered bar layout, selectable spec/class/hidden player icons, rounded icon support, and corrected bar spacing.",
            "Added automatic LFG role-check controls under Automation & Social, including selectable Tank, Healer, and Damage roles and automatic confirmation when queueing alone or with a group.",
            "Refined Enhancements navigation with module-specific artwork, accent-coloured icons, the red sword Damage Meter icon, Blizzard chat artwork for Automation & Social, and clearer Interface & Comfort and System Tuning references.",
            "Hardened LFG and popup skins for current Retail UI changes, including accent-only queue-ready borders, working close buttons, black uncovered popup surfaces, preserved dungeon artwork, and safer handling of native NineSlice and border textures.",
            "Fixed the KUI Unlock Mode navigation state so closing and reopening the main options window cannot leave Unlock Mode visually selected as the active page.",
            "Completed the Enhancements localization pass across the supported locales for the new timer, Damage Meter, LFG automation, typography, texture, forces, preview, and navigation strings.",
        },
    },
    ["5.0.3"] = {
        version = "5.0.3",
        published = "2026-08-29",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Restored reliable per-conversation whisper capture on secure-chat builds by mirroring Blizzard-rendered whisper lines into KUI history, including Battle.net conversations, without bypassing the selected whisper thread.",
            "Hardened Chat integration for protected message and channel data by avoiding unsafe native filter and channel-list mutations, preventing taint attribution and protected-table failures during PvP and other restricted chat dispatches.",
        },
    },
    ["5.0.2"] = {
        version = "5.0.2",
        published = "2026-08-29",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Reworked first-time setup for new characters with a dedicated starting-profile choice, allowing existing saved profiles to be selected or KUI defaults to be used without forcing every character onto the KullThranUI profile.",
            "Improved Installer and profile startup handling with stable per-character tracking, safer specialization-profile transitions, correct layout imports into the active profile, and more reliable continuation through conflict detection and setup.",
            "Expanded the Fonts & Colors page with live font previews, a separate Launcher and Options font, individual typography controls for major HUD, social, character, and inspection areas, and additional color controls for interface surfaces, action bars, progress displays, Chat, Armory, and Inspect.",
            "Reworked global font inheritance so modules that still follow the global font update together while explicitly customized areas preserve their own selection, with combat-safe deferred refreshes across the supported interface.",
            "Refined the main configuration window with an accent-colored KUI logo, a new resize grip, a slimmer navigation scrollbar, immediate minimap social-icon recoloring, and a scalable nine-slice background that preserves its proportions at preset and custom window sizes.",
            "Redesigned KUI Unlock Mode with a wider and cleaner sidebar, clearer active-element feedback, improved mover menus, direct access to profile importing, an animated opening logo, and an automatically retracting sidebar that remains available from the edge of the screen.",
            "Improved the in-game changelog window so its complete “Don’t show again” row is clickable, the current patch suppression state is restored correctly, and enabling or disabling the option is saved immediately.",
            "Hardened Chat against protected edit-box state changes during combat, preventing unsafe whisper, Battle.net, and chat-type mutations while retaining the normal input flow outside combat.",
            "Reduced Cooldown Manager background work by replacing continuous glow polling with coalesced event-driven updates, refreshing only affected bars when possible, and avoiding redundant transition passes once Blizzard’s Cooldown Viewer pools have stabilized.",
            "Improved Cooldown Manager trackers by hiding unavailable potion items, keeping owned potion ranks synchronized, stabilizing player and target frame anchoring around narrow CDM layouts, and making arena, battleground, specialization, and world-transition recovery more selective.",
            "Reworked centered horizontal Party and Arena layouts so the player remains in the intended middle position as the group fills, with a corrected bottom-center default position for horizontal Party Frames.",
            "Improved Party Frames range, phase, roster, aura, and encounter handling with more reliable out-of-range recovery, independent dispel indicators, properly layered AuraKit dispel effects, boss-frame activation during encounters, and fewer unnecessary full roster rebuilds while zoning.",
            "Refined Modern KUI group-interface skins with complete accent borders for selected LFG entries, clearer role-selection feedback, and a rebuilt Ready Check presentation with restored portraits, dedicated Ready and Not Ready buttons, consistent surfaces, and accent-aware artwork.",
        },
    },
    ["5.0.1"] = {
        version = "5.0.1",
        published = "2026-08-26",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Restored reliable first-run Installer startup for new users and brought back the visible \"Don't show again\" control, with synchronized login settings so the prompt can be disabled or re-enabled cleanly.",
            "Hardened Chat against protected and secret PvP payloads, preventing duplicated battleground system messages while preserving Blizzard's native message handling.",
            "Restored access to Blizzard's Group Management controls, including raid and world-marker tools, when KullThranUI Party Frames are active.",
            "Improved Party Frames during PvP and arena transitions with safer protected-unit handling and more reliable roster, role, raid-target, and aura refreshes.",
            "Fixed KullThranUI Bags tainting Blizzard's protected container click path, restoring item use, equipping, dragging, and background drops without UseContainerItem() forbidden-action errors.",
        },
    },
    ["5.0.0"] = {
        version = "5.0.0",
        published = "2026-08-25",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Redesigned the main KullThranUI configuration window around expandable module categories, with dedicated 60x40 category artwork, compact module shortcuts, persistent multi-category expansion, and reliable toggling from both the category row and its arrow.",
            "Added category overview pages that present every available module as a large shortcut card with its icon and a concise description, while keeping the most recently selected category open in the right-hand panel.",
            "Corrected category selection and navigation feedback so only the active category remains highlighted, module counts appear only on category overview pages, and expanded categories can coexist without changing the active page.",
            "Refined the global options presentation with a slightly brighter panel background, consistent category-arrow artwork based on the KUI minimap button, and cleaner icon, spacing, and selected-state behavior throughout the sidebar.",
            "Reworked private whisper persistence so opened character and Battle.net conversations can survive a UI reload, including conversations opened before any message is exchanged, while closed conversations remain dismissed and session state is cleared on disconnect.",
            "Hardened Chat against protected and secret strings when capturing whisper targets or copying chat history, and prevented closed temporary Blizzard whisper windows from reopening automatically.",
            "Corrected Action Bar cooldown presentation so active cooldowns use a properly darkened swipe over every supported button shape instead of retaining the normal colored background.",
            "Rebuilt Damage Meter player pinning around a Details-style pinned final row: the player remains visible without corrupting the real ranking order, scrolling can inspect the complete list, and combat-start refreshes no longer push the meter to an unrelated position.",
            "Improved Damage Meter combat-session handling, saved history, protected-value support, and live refresh scheduling to avoid redundant delayed updates during continuous combat events.",
            "Added a genuinely opaque Objective Tracker background mode with a solid black surface, an accent-colored top border, and an accurate live preview that cannot inherit the legacy gradient or fade.",
            "Expanded Armory PvP item-level support with a working live-preview indicator and independent controls for visibility, label, decimals, font, size, outline, color, and horizontal or vertical positioning.",
            "Repositioned Installer Party Frame test controls into a compact left-aligned group so Party, Raid, and Raid 40 tests no longer overlap or distort the live preview.",
            "Significantly reduced Party Frames update cost through unit-scoped event registration, coalesced aura refreshes, bounded absorb queues, cached aura state, and a centralized duration driver that runs only while required.",
            "Improved Nameplates runtime efficiency with reusable frame pooling and cached threat, quest-target, and contextual state, reducing repeated allocation and expensive unit scans during combat.",
            "Optimized Resource Bars to reuse resolved layout and marker data and to update ranges, values, and text only when their relevant unit state changes.",
            "Extended protected and secret-value safeguards across Party Frames, Resource Bars, Nameplates, Chat, Damage Meter, and other high-frequency combat paths for improved Midnight API compatibility.",
            "Added and reviewed localization for the new 5.0.0 category pages, Objective Tracker background controls, Armory PvP item-level settings, and related interface text across every supported language.",
            "Improved package hygiene by removing unused development artifacts, reference trees, duplicate media, temporary scripts, and unreferenced external resources, and added a KullThranUI license that explicitly preserves third-party ownership and licensing terms.",
        },
    },
    ["4.1.5"] = {
        version = "4.1.5",
        published = "2026-08-23",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Reworked the Installer flow so first-time setup opens reliably for every character, reload-required changes return to the exact previous step, and the Installer can be opened directly with `/installer` or `/ins`.",
            "Expanded the Installer with a dedicated Resource Bars step, clearer module enable and disable behavior, localized reload prompts, improved pressed-state feedback, and the correct KullThranUI background across every page.",
            "Redesigned Installer previews for Action Bars, Buffs & Debuffs, Party Frames, Resource Bars, Nameplates, and Armory so configuration choices use realistic layouts, class abilities, aura examples, and their actual icon shapes.",
            "Restored shape support across Action Bars, Buffs & Debuffs, and Cooldown Manager, including masked cooldown swipes, hotkeys rendered above masks, shape-aware selection feedback, and removal of square shadows from non-default shapes.",
            "Improved cooldown handling for protected and secret values, preventing repeated ActionButton and SetCooldown errors without relying on continuous texture updates.",
            "Reworked dispel and status overlays in Party Frames and Unit Frames for Magic, Poison, Curse, Disease, and Bleed effects, with the intended diffused presentation across party, raid, arena, and supported dungeon follower frames.",
            "Fixed friendly units retaining hostile colors after a duel and corrected additional reaction, target, and state refresh edge cases in Unit Frames and Party Frames.",
            "Improved Nameplates options with correctly initialized default slider values and search-style highlights restricted to the relevant configuration gears instead of covering complete option rows.",
            "Corrected Armory live previews so empty equipment slots remain empty, displayed stats match the real panel, and movement speed is calculated from the appropriate game values.",
            "Expanded and refined Modern KUI skins for Trade, Ready Check, Arena Shuffle, group invitations, role popups, PvP inspection, consumable frames, and other Blizzard dialogs.",
            "Fixed missing role icons in group invitation and acceptance popups, accent colors not applying to Ready Check consumables, and popup errors caused by invalid texture layers or unsafe hooks.",
            "Improved Enhanced Friend List invite-button styling so the original artwork follows the active accent instead of being replaced or remaining white.",
            "Reorganized minimap utility buttons outside the map with dedicated Calendar, Tracking, Mail, Friends, Guild, and Teleport Menu controls, consistent Modern KUI backgrounds, accent-aware social icons, and pixel-perfect edge anchoring.",
            "Separated Teleport Menu from the KullThranUI minimap-button collector, added a dedicated custom portal button and corrected label, and replaced the menu settings icon with the standard KUI gear artwork.",
        },
    },
    ["4.1.4"] = {
        version = "4.1.4",
        published = "2026-08-21",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Reworked Buffs & Debuffs with fully custom AuraKit containers managed through KUI Unlock Mode, preserving existing user positions during migration and applying consistent minimap-relative defaults and spacing.",
            "Restored the original Masque Simplicity appearance for auras, fixed weapon-enchant text initialization, improved the live preview layout, and made short durations clearly distinguishable from application counts.",
            "Optimized Buffs & Debuffs aura processing and improved icon reliability under the protected and secret aura restrictions used during combat.",
            "Reworked Cooldown Manager update scheduling to eliminate redundant full refreshes caused by cooldown and aura event storms, substantially reducing combat CPU usage.",
            "Fixed inconsistent CDM proc glows, missing or incorrectly spaced buff-bar icons, protected icon visibility errors, and tracking failures after the first use of an ability or item.",
            "Restored KUI Tracker defensive, racial, potion, and trinket tracking in raids and Mythic+, corrected potion rank and quantity selection, improved cooldown text visibility, and added reliable feedback for passive trinket procs.",
            "Added a Modern KUI skin for Blizzard's native Cooldown Manager and a direct button in KUI CDM options to open it, with combat-safe loading and proper support for its frame-based side tabs.",
            "Fixed a severe Bags performance issue caused by cooldown events. Bag item cooldowns now update incrementally, including Hearthstones, while item-level text is restricted to actual equipment.",
            "Added the `/ktcombat` combat profiler with per-addon CPU deltas, event counters, spike tracking, and detailed CDM phase and bar diagnostics.",
            "Optimized Party Frames aura and event processing in both idle and combat, restored dispel-type textures, and corrected AFK and Raid Assistant icons across group, raid, and Raid 40 layouts.",
            "Improved protected-frame handling across Unit Frames, Nameplates, Party Frames, and Cooldown Manager to prevent taint errors and forbidden frame-strata or visibility operations.",
            "Fixed the Damage Meter scrolling to random ranking sections and ensured that a manually selected top position remains stable while combat data updates.",
            "Corrected Armory movement-speed calculations and rebuilt stat-label sizing to prevent overlap without unnecessarily truncating Intellect, Stamina, Critical Strike, Mastery, and other labels.",
            "Fixed misplaced private whisper windows and prevented hidden Friends controls from intercepting right-clicks while the Social window is closed.",
            "Repaired Enhanced Friend List layout and interaction regressions, removed the Lua local-variable limit warning and nil-function error, and restored reliable opening, refreshing, and button behavior.",
            "Fixed missing role artwork in group invitations, the dark lower section of self-initiated Ready Checks, and Release Spirit availability during raid and Mythic boss encounters where releasing is not allowed.",
            "Fixed Aura Reminders continuing to request food after the player had already eaten from a feast.",
            "Improved Guild, LFG, popup, and Objective Tracker skin behavior and corrected several profile and localization edge cases.",
        },
    },
}
-- AUTO-CHANGELOG:END

local function GetCurrentKUIVersion()
    local ver = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
        or KT.VERSION
        or "5.0.6"
    -- When loaded from the source tree without the BigWigs packager the TOC
    -- still contains the literal "@project-version@" token.  Fall back to the
    -- hardcoded release version so the changelog and options never display it.
    if ver and ver:find("@", 1, true) then
        ver = "5.0.6"
    end
    return ver
end

local function NormalizeVersionKey(version)
    if type(version) ~= "string" then
        return nil
    end

    version = version:match("^%s*(.-)%s*$") or version
    if version == "" then
        return nil
    end

    local numeric = version:match("(%d+%.%d+%.%d+)")
        or version:match("(%d+%.%d+)")
    return numeric or version
end

local function ParseVersionParts(version)
    local normalized = NormalizeVersionKey(version)
    if not normalized then
        return nil
    end

    local parts = {}
    for token in normalized:gmatch("(%d+)") do
        parts[#parts + 1] = tonumber(token) or 0
    end
    if #parts == 0 then
        return nil
    end
    return parts
end

local function CompareVersions(a, b)
    local aParts = ParseVersionParts(a)
    local bParts = ParseVersionParts(b)
    if not aParts and not bParts then
        return 0
    elseif not aParts then
        return -1
    elseif not bParts then
        return 1
    end

    local count = math.max(#aParts, #bParts)
    for i = 1, count do
        local av = aParts[i] or 0
        local bv = bParts[i] or 0
        if av ~= bv then
            return av > bv and 1 or -1
        end
    end
    return 0
end

-- Expose version information during addon startup, not only after opening
-- the on-demand options ns.pages.
KT.CompareVersions = CompareVersions
KT.GetLatestArchivedChangelogVersion = function()
    return CHANGELOG_LATEST_ARCHIVED_VERSION
end

local function GetChangelogEntryForVersion(version)
    if type(version) ~= "string" then
        return nil
    end

    return CHANGELOG_ENTRIES[version]
        or CHANGELOG_ENTRIES[NormalizeVersionKey(version)]
end

local function GetLatestArchivedChangelogEntry()
    local preferred = CHANGELOG_ENTRIES[CHANGELOG_LATEST_ARCHIVED_VERSION]
    local latest = preferred

    for key, entry in pairs(CHANGELOG_ENTRIES) do
        if type(entry) == "table" then
            if not latest then
                latest = entry
            else
                local entryPublished = tostring(entry.published or "")
                local latestPublished = tostring(latest.published or "")
                if entryPublished > latestPublished then
                    latest = entry
                elseif entryPublished == latestPublished and CompareVersions(key, latest.version or "") > 0 then
                    latest = entry
                end
            end
        end
    end

    return latest
end

local function GetChangelogDisplayInfo(version)
    local currentVersion = version or GetCurrentKUIVersion()
    local entry = GetChangelogEntryForVersion(currentVersion)
    local latestEntry = GetLatestArchivedChangelogEntry()
    local isFallback = entry == nil and latestEntry ~= nil
    return currentVersion, entry, latestEntry, isFallback
end

local function BuildChangelogText(version)
    local currentVersion, entry, latestEntry, isFallback = GetChangelogDisplayInfo(version)
    local lines = {
        LTextFmt("Current Version: %s", currentVersion),
}
    local function NormalizeNote(note)
        if type(note) ~= "string" then
            return nil
        end
        note = note:gsub("\r\n", "\n")
        note = note:gsub("\r", "\n")
        note = note:gsub("^%s*[%*%-]+%s*", "")
        note = note:gsub("%s+$", "")
        if note == "" then
            return nil
        end
        return note
    end

    if isFallback then
        lines[#lines + 1] = ""
        lines[#lines + 1] = LTextFmt("No published Wago changelog was found for version %s.", currentVersion)
        lines[#lines + 1] = LText("Secondary Source: CurseForge Files")
        lines[#lines + 1] = CHANGELOG_FILES_URL
        lines[#lines + 1] = LText("Fallback Source: Discord")
        lines[#lines + 1] = CHANGELOG_DISCORD_URL
    end

    if not entry and not latestEntry then
        lines[#lines + 1] = ""
        lines[#lines + 1] = LText("No changelog data is available yet.")
        return table.concat(lines, "\n")
    end

    local displayEntry = entry or latestEntry

    lines[#lines + 1] = ""
    if entry then
        lines[#lines + 1] = LTextFmt("Published changelog version: %s", displayEntry.version)
    else
        lines[#lines + 1] = LTextFmt("Latest archived changelog: %s", displayEntry.version)
    end
    lines[#lines + 1] = LTextFmt("Published: %s", displayEntry.published)
    lines[#lines + 1] = LTextFmt("Primary Source: %s", displayEntry.sourceLabel or "Wago Addons")
    lines[#lines + 1] = displayEntry.sourceUrl or CHANGELOG_WAGO_URL

    if not entry then
        lines[#lines + 1] = ""
        lines[#lines + 1] = LText("Showing the latest archived changelog below until the current version is published on Wago, CurseForge, or announced on Discord.")
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = LText("Changes")

    if displayEntry.notes and #displayEntry.notes > 0 then
        for _, note in ipairs(displayEntry.notes) do
            local cleanNote = NormalizeNote(note)
            if cleanNote then
                lines[#lines + 1] = "- " .. cleanNote
            end
        end
    else
        lines[#lines + 1] = LText("No changelog data is available yet.")
    end

    return table.concat(lines, "\n")
end

local changelogPopup

local function IsChangelogVersionStored(changelogDb, version)
    if type(changelogDb) ~= "table" or not version then
        return false
    end

    return NormalizeVersionKey(changelogDb.lastAutoShownVersion) == version
        or NormalizeVersionKey(changelogDb.lastDismissedVersion) == version
        or (type(changelogDb.dismissedVersions) == "table"
            and changelogDb.dismissedVersions[version] == true)
end

local function GetRawChangelogDB(create)
    local saved = _G.KullThranDB
    if type(saved) ~= "table" then
        return nil
    end
    if type(saved.global) ~= "table" then
        if not create then return nil end
        saved.global = {}
    end
    if type(saved.global.changelog) ~= "table" then
        if not create then return nil end
        saved.global.changelog = {}
    end
    return saved.global.changelog
end

function KT:IsChangelogPatchSuppressed(version)
    local currentVersion = NormalizeVersionKey(version or GetCurrentKUIVersion())
    local changelogDb = self.db and self.db.global and self.db.global.changelog
    local rawChangelogDb = GetRawChangelogDB(false)
    local installerDb = self.db and self.db.profile and self.db.profile.installer
    local profileDismissedVersion = installerDb and NormalizeVersionKey(installerDb.dismissedChangelogVersion)
    local sessionDismissed = self._changelogDismissedVersions

    return currentVersion ~= nil and (
        (type(sessionDismissed) == "table" and sessionDismissed[currentVersion] == true)
        or IsChangelogVersionStored(changelogDb, currentVersion)
        or IsChangelogVersionStored(rawChangelogDb, currentVersion)
        or profileDismissedVersion == currentVersion
    )
end

function KT:SetChangelogPatchSuppressed(version, suppressed)
    if not self.db then
        return
    end
    self.db.global = self.db.global or {}

    local currentVersion = NormalizeVersionKey(version or GetCurrentKUIVersion())
    if not currentVersion then
        return
    end

    self.db.global.changelog = self.db.global.changelog or {}
    local changelogDb = self.db.global.changelog
    local rawChangelogDb = GetRawChangelogDB(true)
    local installerDb = self.db.profile and self.db.profile.installer

    local shouldSuppress = suppressed and true or false
    self._changelogDismissedVersions = self._changelogDismissedVersions or {}
    self._changelogDismissedVersions[currentVersion] = shouldSuppress or nil

    local function UpdateStore(store)
        if type(store) ~= "table" then return end
        store.dismissedVersions = store.dismissedVersions or {}
        if shouldSuppress then
            store.lastAutoShownVersion = currentVersion
            store.lastDismissedVersion = currentVersion
            store.dismissedVersions[currentVersion] = true
        else
            if NormalizeVersionKey(store.lastAutoShownVersion) == currentVersion then
                store.lastAutoShownVersion = nil
            end
            if NormalizeVersionKey(store.lastDismissedVersion) == currentVersion then
                store.lastDismissedVersion = nil
            end
            store.dismissedVersions[currentVersion] = nil
        end
    end

    UpdateStore(changelogDb)
    if rawChangelogDb ~= changelogDb then
        UpdateStore(rawChangelogDb)
    end

    if shouldSuppress then
        if installerDb then
            installerDb.dismissedChangelogVersion = currentVersion
        end
    else
        if installerDb and NormalizeVersionKey(installerDb.dismissedChangelogVersion) == currentVersion then
            installerDb.dismissedChangelogVersion = nil
        end
    end

    return self:IsChangelogPatchSuppressed(currentVersion) == shouldSuppress
end

local function RefreshChangelogPopupLayout(popup)
    if not (popup and popup.scroll and popup.scrollContent and popup.body) then
        return
    end

    local scrollWidth = popup.scroll:GetWidth()
    if not scrollWidth or scrollWidth <= 0 then
        scrollWidth = 606
    end

    local contentWidth = math.max(120, math.floor(scrollWidth) - 10)
    popup.scrollContent:SetWidth(contentWidth)
    popup.body:SetWidth(math.max(80, contentWidth - 8))
    popup.scrollContent:SetHeight(math.max(1, math.ceil(popup.body:GetStringHeight()) + 12))
    popup.scroll:SetVerticalScroll(0)
end

local function RefreshChangelogPopupTheme(popup)
    if not popup then
        return
    end

    local palette = GetOptionsStylePalette()
    local accent = palette.accent or { r = KT.C_R or 1, g = KT.C_G or 0, b = KT.C_B or 0.3333333333, a = 1 }
    local background = palette.background or { r = 0.04, g = 0.04, b = 0.06, a = 0.97 }
    local text = palette.text or { r = 1, g = 1, b = 1, a = 1 }

    if KT.AddBackdrop then
        KT:AddBackdrop(popup, background.r or 0.04, background.g or 0.04, background.b or 0.06, background.a or 0.97)
    end
    if KT.AddBorder then
        KT:AddBorder(popup, accent.r or 1, accent.g or 0, accent.b or 0.3333333333, 0.9)
    end

    if popup.header then
        popup.header:SetTextColor(accent.r or 1, accent.g or 0, accent.b or 0.3333333333, 1)
    end

    if popup.closeBtn then
        if KT.AddBackdrop then
            KT:AddBackdrop(popup.closeBtn, 0.08, 0.08, 0.11, 1)
        end
        if KT.AddBorder then
            KT:AddBorder(popup.closeBtn, accent.r or 1, accent.g or 0, accent.b or 0.3333333333, 0.55)
        end
    end

    if popup.closeLabel then
        popup.closeLabel:SetTextColor(text.r or 1, text.g or 1, text.b or 1, 1)
    end

    if popup.dontShowAgainChk and popup.dontShowAgainChk.Checked then
        popup.dontShowAgainChk.Checked:SetVertexColor(
            accent.r or 1, accent.g or 0, accent.b or 0.3333333333, accent.a or 1)
    end
end

local function EnsureChangelogPopup()
    if changelogPopup then
        return changelogPopup
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(660, 520)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()

    local header = frame:CreateFontString(nil, "OVERLAY")
    header:SetFont(KT.FONT_PATH, 14, "OUTLINE")
    header:SetPoint("TOPLEFT", 18, -16)
    frame.header = header

    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(110, 28)
    closeBtn:SetPoint("BOTTOMRIGHT", -18, 16)
    frame.closeBtn = closeBtn

    local dontShowAgainChk = CreateFrame("CheckButton", nil, frame, "BackdropTemplate")
    dontShowAgainChk:SetSize(20, 20)
    dontShowAgainChk:SetPoint("RIGHT", closeBtn, "LEFT", -220, 0)
    if KT.AddBackdrop then KT:AddBackdrop(dontShowAgainChk) end
    dontShowAgainChk:SetBackdropColor(0, 0, 0, 1)
    
    dontShowAgainChk.Checked = dontShowAgainChk:CreateTexture(nil, "ARTWORK")
    dontShowAgainChk.Checked:SetTexture("Interface\\Buttons\\WHITE8x8")
    local palette = GetOptionsStylePalette()
    local accent = palette.accent or { r = KT.C_R or 1, g = KT.C_G or 0, b = KT.C_B or 0.3333333333 }
    dontShowAgainChk.Checked:SetVertexColor(accent.r or 1, accent.g or 0, accent.b or 0.3333333333, accent.a or 1)
    dontShowAgainChk.Checked:SetAllPoints(dontShowAgainChk)
    dontShowAgainChk.Checked:SetAlpha(0)

    local function ApplyDontShowAgainState(state, persist)
        state = state and true or false
        dontShowAgainChk.KT_SuppressedState = state
        dontShowAgainChk:SetChecked(state)
        dontShowAgainChk.Checked:SetAlpha(state and 1 or 0)
        if persist and frame.changelogVersion then
            KT:SetChangelogPatchSuppressed(frame.changelogVersion, state)
        end
    end
    
    local dontShowText = dontShowAgainChk:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dontShowText:SetPoint("LEFT", dontShowAgainChk, "RIGHT", 5, 0)
    dontShowText:SetText(LText("Don't show again for this patch"))
    dontShowText:SetFont(KT.FONT_PATH, 11, "")

    dontShowAgainChk:SetScript("OnClick", function(self)
        ApplyDontShowAgainState(self:GetChecked(), true)
    end)
    frame.dontShowAgainChk = dontShowAgainChk

    local dontShowAgainHitbox = CreateFrame("Button", nil, frame)
    dontShowAgainHitbox:SetPoint("TOPLEFT", dontShowAgainChk, "TOPLEFT", 0, 0)
    dontShowAgainHitbox:SetPoint("BOTTOMRIGHT", dontShowText, "BOTTOMRIGHT", 0, 0)
    dontShowAgainHitbox:SetFrameLevel(dontShowAgainChk:GetFrameLevel() + 1)
    dontShowAgainHitbox:RegisterForClicks("LeftButtonUp")
    dontShowAgainHitbox:SetScript("OnClick", function()
        ApplyDontShowAgainState(not dontShowAgainChk.KT_SuppressedState, true)
    end)
    frame.dontShowAgainHitbox = dontShowAgainHitbox

    local closeLbl = closeBtn:CreateFontString(nil, "OVERLAY")
    closeLbl:SetFont(KT.FONT_PATH, 11, "OUTLINE")
    closeLbl:SetPoint("CENTER")
    closeLbl:SetText(LText("Close"))
    frame.closeLabel = closeLbl
    closeBtn:SetScript("OnClick", function()
        frame:Hide()
    end)
    closeBtn:SetScript("OnEnter", function(self)
        local palette = GetOptionsStylePalette()
        local c = palette.accent or { r = KT.C_R or 1, g = KT.C_G or 0, b = KT.C_B or 0.3333333333 }
        if KT.AddBorder then KT:AddBorder(self, c.r or 1, c.g or 0, c.b or 0.3333333333, 1) end
    end)
    closeBtn:SetScript("OnLeave", function(self)
        local palette = GetOptionsStylePalette()
        local c = palette.accent or { r = KT.C_R or 1, g = KT.C_G or 0, b = KT.C_B or 0.3333333333 }
        if KT.AddBorder then KT:AddBorder(self, c.r or 1, c.g or 0, c.b or 0.3333333333, 0.55) end
    end)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 18, -44)
    scroll:SetPoint("BOTTOMRIGHT", -36, 54)
    frame.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(580, 1)
    scroll:SetScrollChild(content)
    frame.scrollContent = content

    local body = content:CreateFontString(nil, "ARTWORK")
    body:SetFont(KT.FONT_PATH, 11, "")
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetPoint("TOPLEFT", 4, -4)
    body:SetPoint("TOPRIGHT", -4, -4)
    body:SetWordWrap(true)
    if body.SetNonSpaceWrap then body:SetNonSpaceWrap(true) end
    if body.SetSpacing then body:SetSpacing(2) end
    frame.body = body

    frame:SetScript("OnHide", function(self)
        if self.scroll then self.scroll:SetVerticalScroll(0) end
        if self.dontShowAgainChk then
            KT:SetChangelogPatchSuppressed(
                self.changelogVersion,
                self.dontShowAgainChk.KT_SuppressedState == true
            )
        end
        -- Triggers the next step in the login popup sequence
        if KT.ProcessLoginPopups then KT:ProcessLoginPopups() end
    end)
    frame:SetScript("OnShow", function(self)
        local suppressed = KT:IsChangelogPatchSuppressed(self.changelogVersion)
        if self.dontShowAgainChk then
            ApplyDontShowAgainState(suppressed, false)
        end
        RefreshChangelogPopupTheme(self)
        RefreshChangelogPopupLayout(self)
        C_Timer.After(0, function()
            if self and self:IsShown() then
                RefreshChangelogPopupTheme(self)
                RefreshChangelogPopupLayout(self)
            end
        end)
    end)
    frame:SetScript("OnSizeChanged", function(self)
        RefreshChangelogPopupLayout(self)
    end)

    RefreshChangelogPopupTheme(frame)

    changelogPopup = frame
    return frame
end

function KT:ShowChangelogPopup(version)
    local popup = EnsureChangelogPopup()
    local requestedVersion = NormalizeVersionKey(version or GetCurrentKUIVersion()) or GetCurrentKUIVersion()
    local bodyText = BuildChangelogText(requestedVersion)

    popup.changelogVersion = requestedVersion
    popup.header:SetText(LText("Changelog"))
    popup.body:SetText(bodyText)
    RefreshChangelogPopupTheme(popup)
    RefreshChangelogPopupLayout(popup)
    popup:Show()
    popup:Raise()
end

local MENU_CPU_SAMPLE_INTERVAL = 1
local MENU_HEAVY_PERF_SAMPLE_INTERVAL = 10

local function IsScriptProfilingEnabled()
    if GetCVarBool then
        return GetCVarBool("scriptProfile")
    end
    return tostring(GetCVar and GetCVar("scriptProfile") or "0") == "1"
end

local function GetMenuPerfStatus(cpuPercent, fps)
    local cpu = tonumber(cpuPercent)
    if cpu == nil then
        if fps >= 90 then
            return LText("Perf Idle")
        elseif fps >= 60 then
            return LText("Perf OK")
        elseif fps >= 40 then
            return LText("Perf Load")
        end
        return LText("Perf High")
    end

    if fps >= 90 and cpu < 0.5 then
        return LText("Perf Idle")
    elseif fps >= 60 and cpu < 2 then
        return LText("Perf OK")
    elseif fps >= 40 and cpu < 5 then
        return LText("Perf Load")
    end
    return LText("Perf High")
end

local function FormatAddonMemory(memoryKB)
    local value = tonumber(memoryKB) or 0
    if value >= 1024 then
        return string.format("%.1f MB", value / 1024)
    end
    return string.format("%d KB", math.floor(value + 0.5))
end

local function UpdateMenuCpuUsageText(frame, resetSample)
    if not (frame and frame.cpuUsageText) then
        return
    end

    local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
    local profilingEnabled = UpdateAddOnCPUUsage and GetAddOnCPUUsage and IsScriptProfilingEnabled()
    local needsHeavySample = resetSample or not frame.menuPerfLastHeavySampleAt or ((now - frame.menuPerfLastHeavySampleAt) >= MENU_HEAVY_PERF_SAMPLE_INTERVAL)

    local totalCpu = frame.menuPerfCachedTotalCpu
    local memoryKB = frame.menuPerfCachedMemoryKB or 0

    if needsHeavySample then
        if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
            UpdateAddOnMemoryUsage()
            memoryKB = (GetAddOnMemoryUsage(addonName) or GetAddOnMemoryUsage(KT.baseName or "KullThranUI")) or 0
            frame.menuPerfCachedMemoryKB = memoryKB
        end

        if profilingEnabled and UpdateAddOnCPUUsage and GetAddOnCPUUsage then
            UpdateAddOnCPUUsage()
            totalCpu = (GetAddOnCPUUsage(addonName) or GetAddOnCPUUsage(KT.baseName or "KullThranUI") or 0)
            frame.menuPerfCachedTotalCpu = totalCpu
        elseif not profilingEnabled then
            totalCpu = nil
            frame.menuPerfCachedTotalCpu = nil
        end

        frame.menuPerfLastHeavySampleAt = now
    end

    local memoryText = FormatAddonMemory(memoryKB)
    local fps = GetFramerate and GetFramerate() or 0

    if profilingEnabled and (resetSample or not frame.cpuUsageLastSample or not frame.cpuUsageLastAt) then
        frame.cpuUsageLastSample = totalCpu
        frame.cpuUsageLastAt = now
        frame.cpuUsageText:SetText(string.format("%s %s | %s | %.0f FPS", LText("Mem"), memoryText, LText("Calibrating"), fps))
        frame.cpuUsageText:SetTextColor(0.58, 0.58, 0.62, 0.95)
        return
    end

    local cpuPercent = nil
    if profilingEnabled and frame.cpuUsageLastSample and frame.cpuUsageLastAt then
        local elapsed = math.max(0.001, now - frame.cpuUsageLastAt)
        local deltaCpu = math.max(0, totalCpu - frame.cpuUsageLastSample)
        local cpuMsPerSecond = deltaCpu / elapsed
        cpuPercent = cpuMsPerSecond / 10
    end
    local status = GetMenuPerfStatus(cpuPercent, fps)

    if profilingEnabled then
        frame.cpuUsageLastSample = totalCpu
        frame.cpuUsageLastAt = now
        frame.cpuUsageText:SetText(string.format("%s %.1f%% | %s %s | %s | %.0f FPS", LText("CPU"), cpuPercent or 0, LText("Mem"), memoryText, status, fps))
    else
        frame.cpuUsageText:SetText(string.format("%s %s | %s | %.0f FPS", LText("Mem"), memoryText, status, fps))
    end
    frame.cpuUsageText:SetTextColor(0.58, 0.58, 0.62, 0.95)
end

local function StopMenuCpuUsageTicker(frame)
    if frame and frame.cpuUsageTicker and frame.cpuUsageTicker.Cancel then
        frame.cpuUsageTicker:Cancel()
    end
    if frame then
        frame.cpuUsageTicker = nil
        frame.cpuUsageLastSample = nil
        frame.cpuUsageLastAt = nil
        frame.menuPerfLastHeavySampleAt = nil
        frame.menuPerfCachedTotalCpu = nil
        frame.menuPerfCachedMemoryKB = nil
    end
end

local function StartMenuCpuUsageTicker(frame)
    if not frame or frame.cpuUsageTicker then
        return
    end

    UpdateMenuCpuUsageText(frame, true)
    frame.cpuUsageTicker = C_Timer.NewTicker(MENU_CPU_SAMPLE_INTERVAL, function()
        if not frame:IsShown() then
            StopMenuCpuUsageTicker(frame)
            return
        end
        UpdateMenuCpuUsageText(frame, false)
    end)
end

-- ============================================================================
-- Corrupted generated comment removed.
-- ============================================================================
local MENU_W   = 1220
local MENU_H   = 880
local MENU_MIN_W = 1120
local MENU_MIN_H = 800
local MENU_SIZE_PRESETS = {
    { key = "S", width = 1220, height = 880, tooltip = "Compact" },
    { key = "M", width = 1380, height = 980, tooltip = "Medium" },
    { key = "L", width = 1540, height = 1080, tooltip = "Large" },
}

local NAV_W       = 300
local TOP_MARGIN  = 90
local BOT_MARGIN  = 60

local CONTENT_W = MENU_W - NAV_W - 30

local function Lerp(a, b, t)
    return a + ((b - a) * t)
end

local function GetMenuLayoutMetrics(frame)
    local width = (frame and frame.GetWidth and frame:GetWidth()) or MENU_W
    local height = (frame and frame.GetHeight and frame:GetHeight()) or MENU_H
    local smallPreset = MENU_SIZE_PRESETS[1]
    local mediumPreset = MENU_SIZE_PRESETS[2]
    local largePreset = MENU_SIZE_PRESETS[3]
    local t
    local navWidth
    local maxContentWidth
    local topMargin
    local bottomMargin

    if width <= (mediumPreset and mediumPreset.width or MENU_W) then
        local range = math.max(1, (mediumPreset and mediumPreset.width or MENU_W) - (smallPreset and smallPreset.width or MENU_W))
        t = math.max(0, math.min(1, (width - (smallPreset and smallPreset.width or MENU_W)) / range))
        navWidth = math.floor(Lerp(292, 300, t) + 0.5)
        maxContentWidth = math.floor(Lerp(850, 960, t) + 0.5)
        topMargin = math.floor(Lerp(88, 90, t) + 0.5)
        bottomMargin = math.floor(Lerp(56, 60, t) + 0.5)
    else
        local range = math.max(1, (largePreset and largePreset.width or MENU_W) - (mediumPreset and mediumPreset.width or MENU_W))
        t = math.max(0, math.min(1, (width - (mediumPreset and mediumPreset.width or MENU_W)) / range))
        navWidth = math.floor(Lerp(300, 308, t) + 0.5)
        maxContentWidth = math.floor(Lerp(960, 1040, t) + 0.5)
        topMargin = math.floor(Lerp(90, 94, t) + 0.5)
        bottomMargin = math.floor(Lerp(60, 64, t) + 0.5)
    end

    local contentInsetLeft = navWidth + 20
    local availableContentWidth = math.max(320, width - contentInsetLeft - 20)
    local contentWidth = math.min(availableContentWidth, maxContentWidth)
    local contentInsetRight = math.max(20, width - contentInsetLeft - contentWidth)
    local contentInsetTop = topMargin + 10
    local contentInsetBottom = bottomMargin + 10
    -- Extra breathing room between the artwork's content panel edge and the
    -- actual options/blocks. Bumping this insets the whole options window
    -- (scroll + blocks + backgrounds derive from it), not one module.
    local contentPadLeft = 26

    return {
        width = width,
        height = height,
        navWidth = navWidth,
        topMargin = topMargin,
        bottomMargin = bottomMargin,
        contentInsetLeft = contentInsetLeft + contentPadLeft,
        contentInsetRight = contentInsetRight,
        contentInsetTop = contentInsetTop,
        contentInsetBottom = contentInsetBottom,
        contentWidth = contentWidth - contentPadLeft,
        navContentWidth = math.max(180, navWidth - 10),
    }
end

local function GetMenuSizeBounds()
    local screenW, screenH = GetPhysicalScreenSize()
    screenW = tonumber(screenW) or 1920
    screenH = tonumber(screenH) or 1080

    local maxWidth = math.max(MENU_MIN_W, math.floor(screenW * 0.92))
    local maxHeight = math.max(MENU_MIN_H, math.floor(screenH * 0.92))
    return MENU_MIN_W, MENU_MIN_H, maxWidth, maxHeight
end

local function ClampMenuSize(width, height)
    local minWidth, minHeight, maxWidth, maxHeight = GetMenuSizeBounds()
    width = tonumber(width) or MENU_W
    height = tonumber(height) or MENU_H
    width = math.max(minWidth, math.min(maxWidth, math.floor(width + 0.5)))
    height = math.max(minHeight, math.min(maxHeight, math.floor(height + 0.5)))
    return width, height
end

local function GetCurrentMenuUIScale()
    local scale = UIParent and UIParent.GetScale and UIParent:GetScale() or nil
    if not scale or scale <= 0 then
        scale = KT and KT.db and KT.db.profile and tonumber(KT.db.profile.uiScale) or nil
    end
    if not scale or scale <= 0 then
        scale = 1
    end
    return scale
end

local function GetResponsiveMenuSize()
    local profile = KT and KT.db and KT.db.profile
    if profile and tonumber(profile.menuCustomWidth) and tonumber(profile.menuCustomHeight) then
        return ClampMenuSize(profile.menuCustomWidth, profile.menuCustomHeight)
    end

    local screenW, screenH = GetPhysicalScreenSize()
    screenW = tonumber(screenW) or 1920
    screenH = tonumber(screenH) or 1080

    local uiScale = GetCurrentMenuUIScale()
    local scaleBoost = 0.71 / uiScale
    if scaleBoost < 1 then scaleBoost = 1 end
    if scaleBoost > 1.35 then scaleBoost = 1.35 end

    local width = math.floor((MENU_W * scaleBoost) + 0.5)
    local height = math.floor((MENU_H * math.min(scaleBoost, 1.25)) + 0.5)
    local autoMaxPreset = MENU_SIZE_PRESETS[2]

    local _, _, maxWidth, maxHeight = GetMenuSizeBounds()
    if autoMaxPreset then
        width = math.min(width, autoMaxPreset.width or width)
        height = math.min(height, autoMaxPreset.height or height)
    end
    width = math.max(math.min(MENU_W, maxWidth), math.min(width, maxWidth))
    height = math.max(math.min(MENU_H, maxHeight), math.min(height, maxHeight))

    return ClampMenuSize(width, height)
end

local function ApplyTextureGradient(texture, orientation, startR, startG, startB, startA, endR, endG, endB, endA)
    if not texture then return end
    if texture.SetGradientAlpha then
        texture:SetGradientAlpha(orientation, startR, startG, startB, startA, endR, endG, endB, endA)
        return
    end
    if texture.SetGradient and CreateColor then
        texture:SetGradient(orientation,
            CreateColor(startR, startG, startB, startA),
            CreateColor(endR, endG, endB, endA)
        )
        return
    end
    if texture.SetColorTexture then
        texture:SetColorTexture(startR, startG, startB, math.max(startA or 0, endA or 0))
    end
end

local function GetContentWidthForMenu(frame)
    local metrics = GetMenuLayoutMetrics(frame)
    return metrics.contentWidth
end

local function PersistManualMenuSize(frame)
    local profile = KT and KT.db and KT.db.profile
    if not (frame and profile) then return end
    local width, height = ClampMenuSize(frame:GetWidth(), frame:GetHeight())
    profile.menuCustomWidth = width
    profile.menuCustomHeight = height
end

local MENU_BACKGROUND_IMAGE_WIDTH = 1307
local MENU_BACKGROUND_IMAGE_HEIGHT = 953

local function CreateMenuBackgroundLayer(holder, texturePath, sourceX, sourceY, subLevel, allTextures)
    local layer = {
        sourceX = sourceX,
        sourceY = sourceY,
        textures = {},
    }

    for row = 1, #sourceY - 1 do
        layer.textures[row] = {}
        for column = 1, #sourceX - 1 do
            local texture = holder:CreateTexture(nil, "BACKGROUND", nil, subLevel)
            texture:SetTexture(texturePath)
            layer.textures[row][column] = texture
            allTextures[#allTextures + 1] = texture
        end
    end

    return layer
end

local function LayoutMenuBackgroundLayer(layer, holder, destinationX, destinationY)
    if not (layer and holder) then return end
    if #destinationX ~= #layer.sourceX or #destinationY ~= #layer.sourceY then return end

    for row = 1, #layer.sourceY - 1 do
        for column = 1, #layer.sourceX - 1 do
            local texture = layer.textures[row] and layer.textures[row][column]
            if texture then
                local left = destinationX[column]
                local right = destinationX[column + 1]
                local top = destinationY[row]
                local bottom = destinationY[row + 1]

                texture:ClearAllPoints()
                texture:SetPoint("TOPLEFT", holder, "TOPLEFT", left, -top)
                texture:SetPoint("BOTTOMRIGHT", holder, "TOPLEFT", right, -bottom)
                texture:SetTexCoord(
                    layer.sourceX[column] / MENU_BACKGROUND_IMAGE_WIDTH,
                    layer.sourceX[column + 1] / MENU_BACKGROUND_IMAGE_WIDTH,
                    layer.sourceY[row] / MENU_BACKGROUND_IMAGE_HEIGHT,
                    layer.sourceY[row + 1] / MENU_BACKGROUND_IMAGE_HEIGHT
                )
                texture:Show()
            end
        end
    end
end

local function UpdateMenuLayoutForSize(frame)
    if not frame then return end
    local metrics = GetMenuLayoutMetrics(frame)

    if frame._navHost then
        frame._navHost:ClearAllPoints()
        frame._navHost:SetWidth(metrics.navWidth)
        frame._navHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -metrics.topMargin)
        frame._navHost:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, metrics.bottomMargin)
    end

    if frame.scrollFrame then
        frame.scrollFrame:ClearAllPoints()
        frame.scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", metrics.contentInsetLeft, -metrics.contentInsetTop)
        frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -metrics.contentInsetRight, metrics.contentInsetBottom)
    end

    if frame.scrollChild then
        frame.scrollChild:SetWidth(metrics.contentWidth)
    end
    if frame._navContent then
        frame._navContent:SetWidth(metrics.navContentWidth)
    end

    if frame._reloadBtn and frame._resetBtn and frame._discordBtn then
        local discWidth = 34
        local gap = 6
        local navMargin = 10
        local btnWidth = (metrics.navWidth - (navMargin * 2) - discWidth - (gap * 2)) / 2

        frame._reloadBtn:ClearAllPoints()
        frame._reloadBtn:SetSize(btnWidth - 10, 34)
        frame._reloadBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", navMargin, 15)

        frame._resetBtn:ClearAllPoints()
        frame._resetBtn:SetSize(btnWidth + 10, 34)
        frame._resetBtn:SetPoint("LEFT", frame._reloadBtn, "RIGHT", gap, 0)

        frame._discordBtn:ClearAllPoints()
        frame._discordBtn:SetSize(discWidth, 34)
        frame._discordBtn:SetPoint("LEFT", frame._resetBtn, "RIGHT", gap, 0)
    end

    if frame.RefreshNavigationScroll then
        frame:RefreshNavigationScroll()
    end
end

local function UpdateMenuBackgroundLayout(frame)
    if not (frame and frame._customBg and frame._customBgHolder) then return end

    local width = frame.GetWidth and frame:GetWidth() or 0
    local height = frame.GetHeight and frame:GetHeight() or 0
    if width <= 0 or height <= 0 then return end

    local palette = GetOptionsStylePalette()
    local metrics = GetMenuLayoutMetrics(frame)

    local slices = frame._customBgSlices or {}
    local layers = frame._customBgLayers
    if not layers then return end

    -- The exported PNGs keep the original 1307x953 canvas. These guides are
    -- the opaque borders in that canvas, not arbitrary crops. Mapping the
    -- guides to the live widget geometry keeps borders and shadows sharp while
    -- only the large, flat portions of the artwork are allowed to stretch.
    LayoutMenuBackgroundLayer(layers.fondo, frame._customBgHolder,
        { 0, width },
        { 0, height }
    )

    local navContentTop = metrics.topMargin + 10 + UNLOCKMODE_BUTTON_HEIGHT
        + NAV_SCROLL_TOP_GAP + NAV_CONTENT_TOP_PADDING
    local leftPanelTop = navContentTop - 10
    local navContentBottom = height - metrics.bottomMargin
    local navCoreRight = metrics.navWidth + 2
    LayoutMenuBackgroundLayer(layers.leftPanel, frame._customBgHolder,
        { 0, navCoreRight, navCoreRight + 55 },
        { leftPanelTop - 55, leftPanelTop, navContentBottom }
    )

    LayoutMenuBackgroundLayer(layers.bottomLeft, frame._customBgHolder,
        { 3, metrics.navWidth - 2 },
        { height - 58, height - 6 }
    )

    local unlockBottom = metrics.topMargin + 10 + UNLOCKMODE_BUTTON_HEIGHT
    local unlockCoreRight = metrics.navWidth - 7
    LayoutMenuBackgroundLayer(layers.unlock, frame._customBgHolder,
        { 0, unlockCoreRight, unlockCoreRight + 182 },
        { 0, unlockBottom - 2, unlockBottom + 2, unlockBottom + 202 }
    )

    local contentBorderLeft = metrics.contentInsetLeft - 8
    local contentBorderTop = math.max(1, metrics.contentInsetTop - 27)
    LayoutMenuBackgroundLayer(layers.right, frame._customBgHolder,
        { contentBorderLeft, contentBorderLeft + 8, width },
        { contentBorderTop, contentBorderTop + 8, height }
    )

    -- This is a fixed top-right cap. It must move with the right edge, never
    -- crop at the current window width or stretch with the content panel.
    LayoutMenuBackgroundLayer(layers.rightTop, frame._customBgHolder,
        { width - 241, width },
        { 0, 132 }
    )

    local background = palette.background or STYLE_PRESETS.kui_crimson.background
    local tint = palette.accent or STYLE_PRESETS.kui_crimson.accent
    local headerTint = palette.headerColor or BlendStyleColor(background, tint, 0.35)

    for _, texture in ipairs(slices) do
        if texture.SetDesaturated then
            texture:SetDesaturated(true)
        end
    end

    local tintLift = BlendStyleColor(
        tint,
        MakeStyleColor(1, 1, 1, 1),
        0.34
    )
    for _, texture in ipairs(slices) do
        texture:SetVertexColor(tintLift.r or 0.45, tintLift.g or 0.45, tintLift.b or 0.52, 1)
    end

    if frame._customBgLift then
        frame._customBgLift:SetColorTexture(1, 1, 1, 0.03)
        frame._customBgLift:Show()
    end

    if frame._customBgHeaderTint then
        local headerLeft = math.max(0, math.floor((metrics and metrics.navWidth or 0) + 0.5))
        frame._customBgHeaderTint:ClearAllPoints()
        frame._customBgHeaderTint:SetPoint("TOPLEFT", frame._customBgHolder, "TOPLEFT", headerLeft, 0)
        frame._customBgHeaderTint:SetPoint("TOPRIGHT", frame._customBgHolder, "TOPRIGHT", 0, 0)
        frame._customBgHeaderTint:SetHeight(math.max(72, math.floor((metrics and metrics.topMargin or height * 0.16) * 0.95)))
        ApplyTextureGradient(
            frame._customBgHeaderTint,
            "VERTICAL",
            headerTint.r or tint.r or 1, headerTint.g or tint.g or 0, headerTint.b or tint.b or 0.333, 0.24,
            background.r or 0.03, background.g or 0.03, background.b or 0.04, 0
        )
        frame._customBgHeaderTint:Show()
    end

    for _, overlay in ipairs({
        frame._customBgWash,
        frame._customBgTopGlow,
        frame._customBgBottomGlow,
        frame._customBgRightGlow,
}) do
        if overlay then
            overlay:Hide()
        end
    end
end

local function UpdateMenuThemeVisuals(menu)
    if not menu then return end

    local _, accent, background, text, muted = GetMenuPaletteColors()

    if KT.AddBorder then
        KT:AddBorder(menu, 0.03, 0.03, 0.04, 0.98)
    end

    if menu._closeTex then
        menu._closeTex:SetVertexColor(text.r or 1, text.g or 1, text.b or 1, 1)
    end
    if menu._logoTex then
        if menu._logoTex.SetDesaturated then
            menu._logoTex:SetDesaturated(true)
        end
        menu._logoTex:SetVertexColor(accent.r or 1, accent.g or 1, accent.b or 1, 1)
    end
    if menu.cpuUsageText then
        menu.cpuUsageText:SetTextColor(muted.r or 0.74, muted.g or 0.74, muted.b or 0.78, 0.95)
    end
    if menu.searchBox and KT.AddBorder then
        KT:AddBorder(menu.searchBox, accent.r or 1, accent.g or 0, accent.b or 0.333, 0.72)
    end
    if menu._searchIcon then
        menu._searchIcon:SetVertexColor(accent.r or 1, accent.g or 0, accent.b or 0.333, 1)
    end
    if menu._searchHint then
        menu._searchHint:SetTextColor(accent.r or 1, accent.g or 0, accent.b or 0.333, 0.55)
    end
    if menu._searchClearTex then
        menu._searchClearTex:SetVertexColor(accent.r or 1, accent.g or 0, accent.b or 0.333, 1)
    end
    if menu._searchDropdown and KT.AddBorder then
        KT:AddBorder(menu._searchDropdown, accent.r or 1, accent.g or 0, accent.b or 0.333, 0.8)
    end
    if menu._searchScrollBar then
        ApplyMenuScrollBarTheme(menu._searchScrollBar)
    end
    for _, resultButton in ipairs(menu._searchResultButtons or {}) do
        if resultButton.moduleText then
            resultButton.moduleText:SetTextColor(accent.r or 1, accent.g or 0, accent.b or 0.333, 1)
        end
        if resultButton.moduleIcon then
            local iconR, iconG, iconB = GetMenuIconVertexColor(resultButton._searchIconName or "")
            resultButton.moduleIcon:SetVertexColor(iconR, iconG, iconB, 1)
        end
    end
    if menu._versionText then
        local vr = math.floor((accent.r or 1) * 255 + 0.5)
        local vg = math.floor((accent.g or 0) * 255 + 0.5)
        local vb = math.floor((accent.b or 0.333) * 255 + 0.5)
	menu._versionText:SetText(string.format("|cff%02x%02x%02xv%s|r", vr, vg, vb, menu._versionValue or (KT.VERSION or "5.0.6")))
    end

    for _, btn in ipairs(menu._sizePresetButtons or {}) do
        if KT.AddBorder then
            KT:AddBorder(btn, accent.r or 1, accent.g or 0, accent.b or 0.333, 0.55)
        end
        if btn.label then
            btn.label:SetTextColor(text.r or 1, text.g or 1, text.b or 1, 1)
        end
    end

    if menu._reloadBtn and KT.AddBorder then
        KT:AddBorder(menu._reloadBtn, 0.14, 0.14, 0.16, 0.7)
    end
    if menu._reloadLabel then
        menu._reloadLabel:SetTextColor(text.r or 1, text.g or 1, text.b or 1, 1)
    end
    if menu._resetBtn and KT.AddBorder then
        KT:AddBorder(menu._resetBtn, accent.r or 1, accent.g or 0, accent.b or 0.333, 0.7)
    end
    if menu._resetLabel then
        menu._resetLabel:SetTextColor(accent.r or 1, accent.g or 0, accent.b or 0.333, 1)
    end
    if menu._discordBtn and KT.AddBorder then
        KT:AddBorder(menu._discordBtn, accent.r or 1, accent.g or 0, accent.b or 0.333, 0.7)
    end
    if menu._discordIcon then
        menu._discordIcon:SetVertexColor(accent.r or 1, accent.g or 0, accent.b or 0.333, 1)
    end
    if menu._resizeGrip and menu._resizeGrip._texture then
        menu._resizeGrip._texture:SetVertexColor(
            accent.r or 1, accent.g or 0, accent.b or 0.333, 0.9)
    end

    if menu._stickyPreviewHost and KT.AddBorder then
        KT:AddBorder(menu._stickyPreviewHost, accent.r or 1, accent.g or 0, accent.b or 0.333, 0.65)
    end

    if menu.scrollFrame and menu.scrollFrame.ScrollBar then
        ApplyMenuScrollBarTheme(menu.scrollFrame.ScrollBar)
    end
    if menu._navScrollBar then
        ApplyMenuScrollBarTheme(menu._navScrollBar)
    end

    if menu._ktUnlockShortcut and menu._ktUnlockShortcut.UpdateVisual then
        if menu._ktUnlockShortcut.iconBox and KT.AddBackdrop then
            local unlockActive = (KT and KT._unlockActive) or false
            local bgR, bgG, bgB, bgA = GetMenuNavBackdropTint(unlockActive)
            KT:AddBackdrop(menu._ktUnlockShortcut.iconBox, bgR, bgG, bgB, bgA)
        end
        menu._ktUnlockShortcut:UpdateVisual()
    end

    if menu._categoryButtons then
        for _, btn in ipairs(menu._categoryButtons) do
            if btn.UpdateVisual then
                btn:UpdateVisual()
            else
                ApplyMenuNavButtonTheme(btn, IsCategoryOpen(btn.categoryId))
                ApplyMenuNavButtonIconStyle(btn)
            end
        end
    end
    if menu._navButtons then
        for _, btn in ipairs(menu._navButtons) do
            ApplyMenuNavButtonTheme(btn, ns.activePageId == btn.pageId)
            ApplyMenuNavButtonIconStyle(btn)
        end
    end

    UpdateMenuBackgroundLayout(menu)
end

local function ApplyMenuCustomSize(frame, width, height)
    if not frame then return end
    local profile = KT and KT.db and KT.db.profile
    width, height = ClampMenuSize(width, height)
    if profile then
        profile.menuCustomWidth = width
        profile.menuCustomHeight = height
    end
    frame:SetSize(width, height)
    UpdateMenuLayoutForSize(frame)
end

local function ApplyResponsiveMenuMetrics(frame)
    if not frame then return end

    local minWidth, minHeight, maxWidth, maxHeight = GetMenuSizeBounds()
    if type(frame.SetResizeBounds) == "function" then
        frame:SetResizeBounds(minWidth, minHeight, maxWidth, maxHeight)
    elseif type(frame.SetMinResize) == "function" and type(frame.SetMaxResize) == "function" then
        frame:SetMinResize(minWidth, minHeight)
        frame:SetMaxResize(maxWidth, maxHeight)
    end

    local width, height = GetResponsiveMenuSize()
    frame:SetSize(width, height)
    UpdateMenuLayoutForSize(frame)
end

KT.MenuPrincipal = nil

local CATEGORY_BY_ID = {}
for _, category in ipairs(ns.MENU_CATEGORIES) do
    CATEGORY_BY_ID[category.id] = category
end

local function GetPageCategoryId(pageId, explicitCategoryId)
    local categoryId = explicitCategoryId or ns.PAGE_CATEGORY_MAP[pageId]
    if CATEGORY_BY_ID[categoryId] then
        return categoryId
    end
    return "general_style"
end

local function GetCategoryOverviewPageId(categoryId)
    if not CATEGORY_BY_ID[categoryId] then
        return nil
    end
    return ns.CATEGORY_OVERVIEW_PREFIX .. categoryId
end

local function GetCategoryIdFromOverviewPageId(pageId)
    if type(pageId) ~= "string" or pageId:sub(1, #ns.CATEGORY_OVERVIEW_PREFIX) ~= ns.CATEGORY_OVERVIEW_PREFIX then
        return nil
    end

    local categoryId = pageId:sub(#ns.CATEGORY_OVERVIEW_PREFIX + 1)
    if CATEGORY_BY_ID[categoryId] then
        return categoryId
    end
    return nil
end

local function GetRegisteredCategoryPages(categoryId)
    local categoryPages = {}
    for _, page in ipairs(ns.pages) do
        if (page.categoryId or GetPageCategoryId(page.id)) == categoryId then
            categoryPages[#categoryPages + 1] = page
        end
    end
    return categoryPages
end
local function GetActiveCategoryId()
    local overviewCategoryId = GetCategoryIdFromOverviewPageId(ns.activePageId)
    if overviewCategoryId then
        return overviewCategoryId
    end

    for _, page in ipairs(ns.pages) do
        if page.id == ns.activePageId then
            return page.categoryId or GetPageCategoryId(page.id)
        end
    end
    return nil
end

local function SortRegisteredPages(a, b)
    local aOrder = tonumber(a and a.order) or 1000
    local bOrder = tonumber(b and b.order) or 1000
    if aOrder == bOrder then
        return tostring(a and a.id or "") < tostring(b and b.id or "")
    end
    return aOrder < bOrder
end

local function HasRegisteredPage(pageId)
    if not pageId then
        return false
    end

    for _, page in ipairs(ns.pages) do
        if page.id == pageId then
            return true
        end
    end

    return false
end

local function RegisterPage(id, label, order, builder, categoryId)
    if ns.HIDDEN_OPTION_PAGES[id] then
        return
    end

    local resolvedCategoryId = GetPageCategoryId(id, categoryId)

    for _, page in ipairs(ns.pages) do
        if page.id == id then
            page.label = label
            page.order = order
            page.builder = builder
            page.categoryId = resolvedCategoryId
            table.sort(ns.pages, SortRegisteredPages)
            if KT.MenuPrincipal and KT.MenuPrincipal.RebuildCategoryNavigation then
                C_Timer.After(0, function()
                    if KT.MenuPrincipal then
                        KT.MenuPrincipal:RebuildCategoryNavigation()
                    end
                end)
            end
            return
        end
    end

    table.insert(ns.pages, {
        id = id,
        label = label,
        order = order,
        builder = builder,
        categoryId = resolvedCategoryId,
    })
    table.sort(ns.pages, SortRegisteredPages)

    if KT.MenuPrincipal and KT.MenuPrincipal.RebuildCategoryNavigation then
        C_Timer.After(0, function()
            if KT.MenuPrincipal then
                KT.MenuPrincipal:RebuildCategoryNavigation()
            end
        end)
    end
end

function KT:RegisterPage(id, label, order, builder, categoryId)
    RegisterPage(id, label, order, builder, categoryId)
end

function KT:OpenRegisteredPage(pageId, forceReload, preserveScroll)
    if not HasRegisteredPage(pageId) then
        return self:OpenMenu(pageId)
    end

    if self.MenuPrincipal and self.MenuPrincipal:IsShown() then
        ns.activePageId = nil
        LoadPage(self.MenuPrincipal, pageId, forceReload ~= false, preserveScroll == true)
        return self.MenuPrincipal
    end

    return self:OpenMenu(pageId)
end

local function TryLoadOnDemandAddon(addonName)
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn) then
        return false, "C_AddOns unavailable"
    end

    if C_AddOns.IsAddOnLoaded(addonName) then
        return true
    end

    local playerName = UnitName and UnitName("player")
    if playerName and C_AddOns.GetAddOnEnableState then
        local state = C_AddOns.GetAddOnEnableState(playerName, addonName) or 0
        if state <= 0 then
            return false, "DISABLED"
        end
    end

    if InCombatLockdown and InCombatLockdown() then
        return false, "COMBAT"
    end

    local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, addonName)
    if not ok then
        return false, "ERROR"
    end
    if loaded then
        return true
    end
    return false, reason or "FAILED"
end

function KT:RegisterLoadOnDemandPage(pageId, label, order, addonName)
    self:RegisterPage(pageId, label, order, function(sc, W)
        local y, h = 0, 0

        _, h = W:SectionHeader(sc, label, -y); y = y + h
        _, h = W:Label(sc, "This module is loaded on demand. If the page does not appear, press Retry.", -y, 11); y = y + h

        local loaded, reason = TryLoadOnDemandAddon(addonName)
        if loaded then
            _, h = W:Label(sc, "Module loaded. Refreshing page...", -y, 11); y = y + h
            C_Timer.After(0, function()
                if KT and KT.RefreshPage then
                    KT:RefreshPage()
                end
            end)
            return y
        end

        KT.NormalizeVersionKey = NormalizeVersionKey
        KT.CompareVersions = CompareVersions
        KT.GetLatestArchivedChangelogVersion = function()
            return CHANGELOG_LATEST_ARCHIVED_VERSION
        end

        if reason == "COMBAT" then
            _, h = W:Label(sc, "This module cannot be loaded while you are in combat. Leave combat and try again.", -y, 11); y = y + h
        elseif reason == "DISABLED" then
            _, h = W:Label(sc, "This addon is disabled in the AddOns list. Enable it and reload the UI.", -y, 11); y = y + h
        else
            _, h = W:Label(sc, "Could not load the module addon (" .. tostring(reason or "FAILED") .. ").", -y, 11); y = y + h
        end

        _, h = W:Button(sc, "Retry", -y, function()
            if KT and KT.RefreshPage then
                KT:RefreshPage()
            end
        end); y = y + h

        return y
    end)
end

-- ============================================================================
-- HELPER: fuerza la scrollbar a actualizarse visualmente desde el primer frame
-- ============================================================================
local function GetSafeScrollValue(value)
    if issecretvalue and issecretvalue(value) then
        return 0
    end
    return tonumber(value) or 0
end

local function ForceScrollBarUpdate(sf, sb, thumb, preserveValue, restoreValue)
    -- Dispara OnScrollRangeChanged manualmente tras un tick para que
    -- Corrupted generated comment removed.
    C_Timer.After(0, function()
        if not sf or not sf:IsShown() then return end
        thumb = thumb or (sb and sb._thumb) or (sb and sb.GetThumbTexture and sb:GetThumbTexture()) or nil
        if not (sb and thumb) then return end
        local sfH   = sf:GetHeight()
        local scH   = sf:GetScrollChild() and sf:GetScrollChild():GetHeight() or 0
        local range = math.max(0, scH - sfH)
        if sf.UpdateScrollBar then
            sf:UpdateScrollBar(preserveValue, restoreValue, range)
            return
        end

        sb:SetMinMaxValues(0, math.max(1, range))
        if preserveValue then
            local value = restoreValue ~= nil and GetSafeScrollValue(restoreValue) or GetSafeScrollValue(sb:GetValue())
            value = math.max(0, math.min(range, value))
            sb:SetValue(value)
            sf:SetVerticalScroll(value)
        else
            sb:SetValue(0)
        end

        if sfH and sfH > 0 and range > 0 then
            local ratio = sfH / (sfH + range)
            thumb:SetHeight(math.max(24, math.floor(sfH * ratio)))
        else
            -- Sin scroll: thumb llena el track (pero lo mostramos igualmente)
            thumb:SetHeight(math.max(24, sfH - 4))
        end
    end)
end

-- ============================================================================
-- BLOQUES DE OPCIONES (DOS COLUMNAS)
-- ============================================================================
local function CreateOptionBlock(parent, title, x, y, width)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 40)
    frame:SetPoint("TOPLEFT", x, y)
    local accentR, accentG, accentB = GetMenuAccentColor()
    KT:AddBackdrop(frame, 0.025, 0.025, 0.032, 0.98)
    KT:AddBorder(frame, accentR, accentG, accentB, 0.38)

    local headerBand = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBand:SetPoint("TOPLEFT", 1, -1)
    headerBand:SetPoint("TOPRIGHT", -1, -1)
    headerBand:SetHeight(23)
    headerBand:SetColorTexture(accentR, accentG, accentB, 0.10)

    local accentRail = frame:CreateTexture(nil, "ARTWORK")
    accentRail:SetPoint("TOPLEFT", 1, -1)
    accentRail:SetPoint("BOTTOMLEFT", 1, 1)
    accentRail:SetWidth(3)
    accentRail:SetColorTexture(accentR, accentG, accentB, 0.82)

    local titleText = frame:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(KT.FONT_PATH, 10, "OUTLINE")
    titleText:SetTextColor(accentR, accentG, accentB, 1)
    titleText:SetPoint("TOPLEFT", 10, -8)
    local header = LText(title) or ""
    if type(header) == "string" then
        header = header:upper()
    end
    titleText:SetText(header)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 0, -24)
    content:SetWidth(width)
    content:SetHeight(1)
    content.rowCounter = 0

    return frame, content
end

local function FinalizeOptionBlock(frame, content, contentHeight)
    local headerH = 24
    local bottomPad = 10
    local total = headerH + contentHeight + bottomPad
    content:SetHeight(contentHeight)
    frame:SetHeight(total)
    return total
end

local function BeginOptionBlocks(sc, startY, opts)
    local gap = (opts and opts.gap) or 12
    local columnGap = (opts and opts.columnGap) or 14
    local fullW = sc:GetWidth()
    -- Reserve a right margin so two-column option blocks never sit flush against
    -- the frame border. leftX keeps the existing left pad; the right edge of the
    -- right column lands at (fullW - rightPad).
    local leftX = 10
    local rightPad = 12
    local blockW = math.floor((fullW - leftX - rightPad - columnGap) / 2)
    local rightX = leftX + blockW + columnGap
    return {
        parent = sc,
        startY = startY,
        gap = gap,
        blockW = blockW,
        leftX = leftX,
        rightX = rightX,
        leftUsed = 0,
        rightUsed = 0,
        left = {},
        right = {},
}
end

local function AddOptionBlock(cols, column, title, buildFn)
    local x = (column == "right") and cols.rightX or cols.leftX
    local yOff = -(cols.startY + ((column == "right") and cols.rightUsed or cols.leftUsed))
    local frame, content = CreateOptionBlock(cols.parent, title, x, yOff, cols.blockW)
    local contentH = buildFn(content)
    local totalH = FinalizeOptionBlock(frame, content, contentH)
    local blockList = cols[column]
    if blockList then
        blockList[#blockList + 1] = frame
    end
    if column == "right" then
        cols.rightUsed = cols.rightUsed + totalH + cols.gap
    else
        cols.leftUsed = cols.leftUsed + totalH + cols.gap
    end
end

local function EndOptionBlocks(cols)
    return cols.startY + math.max(cols.leftUsed, cols.rightUsed)
end

-- ============================================================================
-- Corrupted generated comment removed.
-- ============================================================================
KT.Options = KT.Options or {}
KT.Options.LText = LText
KT.Options.LTextFmt = LTextFmt
KT.Options.GetFontValues = GetFontValues
KT.Options.GetStatusbarValues = GetStatusbarValues
KT.Options.GetBackgroundValues = GetBackgroundValues
KT.Options.Reload = Reload
KT.Options.ResetConfirm = ResetConfirm

KT.Options.CreateOptionBlock = CreateOptionBlock
KT.Options.FinalizeOptionBlock = FinalizeOptionBlock
KT.Options.BeginOptionBlocks = BeginOptionBlocks
KT.Options.AddOptionBlock = AddOptionBlock
KT.Options.EndOptionBlocks = EndOptionBlocks

-- ============================================================================
-- Corrupted generated comment removed.
-- ============================================================================
local function CreateContentScroll(parent)
    local metrics = GetMenuLayoutMetrics(parent)
    local sf, sc, sb = KT.Widgets:ScrollFrame(parent, {
        contentWidth = metrics.contentWidth,
        scrollBarParent = parent,
        scrollBarWidth = 6,
        scrollBarOffset = 5,
        thumbWidth = 4,
        wheelStep = 60,
        autoHide = true,
    })
    sf:SetPoint("TOPLEFT", parent, "TOPLEFT", metrics.contentInsetLeft, -metrics.contentInsetTop)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -metrics.contentInsetRight, metrics.contentInsetBottom)
    sc:SetWidth(metrics.contentWidth)
    ApplyMenuScrollBarTheme(sb)

    return sf, sc
end

local function GetStickyPreviewHeight(frame, opts)
    if not frame then return 1 end
    local scale = (frame.GetScale and frame:GetScale()) or 1
    local baseHeight = (opts and opts.height) or (((frame.GetHeight and frame:GetHeight()) or 1) * scale)
    local extraPad = (opts and opts.extraPad) or 10
    return math.max(1, math.floor(baseHeight + (extraPad * 2) + 0.5))
end

local function ClearStickyPreview(menu)
    if not menu then return end

    local frame = menu._stickyPreviewFrame
    local host = menu._stickyPreviewHost

    -- Invalidate ownership before changing anchors or parent. Sticky previews hook
    -- OnSizeChanged, so keeping the reference alive here could reattach and show
    -- the old preview while another page is being built (notably via search).
    menu._stickyPreviewFrame = nil
    menu._stickyPreviewOpts = nil

    local retired = {}
    local function RetirePreview(preview)
        if not preview or retired[preview] then return end
        retired[preview] = true
        preview:Hide()
        preview:ClearAllPoints()
        preview:SetParent(ns.OPTIONS_RECYCLER)
    end

    RetirePreview(frame)
    if host then
        -- Only retire leftover sticky preview shells. Never recycle host chrome
        -- (backdrop/border frames created by AddBackdrop/AddBorder).
        for _, child in ipairs({ host:GetChildren() }) do
            if child._ktUseStickyPreview then
                RetirePreview(child)
            end
        end
        host:SetHeight(1)
        host:Hide()
    end
end

local function UpdateStickyPreviewLayout(menu)
    if not menu then return end
    local host = menu._stickyPreviewHost
    local frame = menu._stickyPreviewFrame
    local opts = menu._stickyPreviewOpts or {}
    if not (host and frame) then return end

    local point = opts.point or "TOP"
    local relativePoint = opts.relativePoint or point
    local xOff = opts.x or 0
    local yOff = opts.y or -10

    host:SetHeight(GetStickyPreviewHeight(frame, opts))
    host:Show()

    frame:SetParent(host)
    frame:ClearAllPoints()
    frame:SetPoint(point, host, relativePoint, xOff, yOff)
    frame:Show()
end

function KT:AttachStickyPreview(frame, opts)
    local menu = self.MenuPrincipal or KT.MenuPrincipal
    if not (menu and menu._stickyPreviewHost and frame) then return frame end

    if menu._stickyPreviewFrame and menu._stickyPreviewFrame ~= frame then
        ClearStickyPreview(menu)
    end

    menu._stickyPreviewFrame = frame
    menu._stickyPreviewOpts = opts or {}

    if not frame._ktStickyPreviewHooked then
        frame._ktStickyPreviewHooked = true
        frame:HookScript("OnSizeChanged", function(selfFrame)
            local activeMenu = KT.MenuPrincipal
            if activeMenu and activeMenu._stickyPreviewFrame == selfFrame then
                UpdateStickyPreviewLayout(activeMenu)
            end
        end)
    end

    UpdateStickyPreviewLayout(menu)
    return frame
end

-- ============================================================================
-- Corrupted generated comment removed.
-- ============================================================================
local MODULE_PAGE_RESTORE_CONFIG = {
    actionbars = { profileKeys = { "actionbars", "blizzframes" } },
    aurareminders = {
        reset = function()
            if _G._KUIAR_AceDB and _G._KUIAR_AceDB.ResetProfile then
                _G._KUIAR_AceDB:ResetProfile()
            end
        end,
    },
    bags = {
        profileKeys = { "bags" },
        reset = function(profile)
            if profile and profile.skin then
                profile.skin.bagsColorMode = nil
                profile.skin.bagsColor = nil
            end
        end,
    },
    buffs = { profileKeys = { "buffsAndDebuffs" } },
    dragonriding = { profileKeys = { "dragonRiding" } },
    expbar = { profileKeys = { "experienceBar" } },
    external = {
        profileKeys = { "uufIntegration" },
        restoreLabel = "Reset KUI External Integrations",
        confirmText = "Reset only KUI integration settings for Unhalted Unit Frames?",
    },
    inspectarmory = { profileKeys = { "inspectArmory" } },
    minimap = { profileKeys = { "minimap", "minimapButton" } },
    progressbars = { profileKeys = { "progressBars" } },
    skins = { profileKeys = { "skin" } },
    teleportmenu = { profileKeys = { "teleportMenu" } },
    tooltip = { profileKeys = { "tooltip" } },
}

local function RestoreModulePageDefaults(pageId)
    local config = MODULE_PAGE_RESTORE_CONFIG[pageId]
    local profile = KT and KT.db and KT.db.profile
    if not (config and profile) then return end

    for _, key in ipairs(config.profileKeys or {}) do
        profile[key] = nil
    end
    if config.reset then
        config.reset(profile)
    end

    ReloadUI()
end

local function AppendModuleProfileTools(sc, W, pageId, totalHeight)
    if not (sc and W and W.SectionHeader and W.Label and W.DualRow) then
        return totalHeight
    end

    local profileMod = KT and KT.GetModule and KT:GetModule("Profiles", true)
    local info = profileMod and profileMod.GetPageProfileInfo and profileMod:GetPageProfileInfo(pageId)
    if not info then
        return totalHeight
    end

    local y = math.max(0, tonumber(totalHeight) or 0) + 8
    local h
    _, h = W:SectionHeader(sc, LText("Profile") .. " - " .. LText(info.label), -y)
    y = y + (tonumber(h) or 0)
    _, h = W:Label(
        sc,
        LText("Import or export only the settings that belong to this module. Other KUI modules are never overwritten here."),
        -y,
        11
    )
    y = y + (tonumber(h) or 0)

    _, h = W:DualRow(sc, -y,
        {
            type = "button",
            text = LText("Export"),
            onClick = function()
                local exportString, err = profileMod:ExportPageProfileString(pageId)
                if not exportString then
                    if KT and KT.Print then KT:Print(err or "No se pudo exportar el modulo.") end
                    return
                end
                profileMod:ShowExportPopup(
                    LText("Export") .. " - " .. LText(info.label),
                    exportString
                )
            end,
        },
        {
            type = "button",
            text = LText("Import"),
            onClick = function()
                profileMod:ShowImportPopup(
                    LText("Import") .. " - " .. LText(info.label),
                    LText("|cffff5555Only this module's settings will be replaced. Other modules contained in the string will be ignored.|r"),
                    function(text)
                        local ok, err = profileMod:ImportPageProfileString(pageId, text)
                        if not ok then
                            error(err or "No se pudo importar el modulo.", 0)
                        end
                        return true
                    end
                )
            end,
        }
    )
    y = y + (tonumber(h) or 42)
    return y + 8
end

KT.Options.AppendModuleProfileTools = AppendModuleProfileTools

local function AppendModuleRestoreDefaults(sc, W, pageId, totalHeight)
    local config = MODULE_PAGE_RESTORE_CONFIG[pageId]
    if not (config and sc and W and W.Button) then
        return totalHeight
    end

    local y = math.max(0, tonumber(totalHeight) or 0) + 8
    local _, h = W:Button(sc, LText(config.restoreLabel or "Restore Defaults"), -y, function()
        RestoreModulePageDefaults(pageId)
    end, "FULL", true, LText(config.confirmText or "RESET_CONFIRM_TEXT"))
    return y + (tonumber(h) or 42) + 8
end
local function GetOverviewModuleIcon(pageId)
    local iconName = ns.MODULE_ICON_MAP[pageId]
    if iconName then
        return MODULE_ICON_PATH .. iconName .. ".png", iconName
    end

    iconName = ns.PAGE_ICON_MAP[pageId] or pageId
    return ICON_PATH .. iconName .. ".png", iconName
end

local function CreateCategoryOverviewModuleButton(parent, menu, page, x, y, width)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, 104)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)

    local accentR, accentG, accentB = GetMenuAccentColor()
    if KT.AddBackdrop then
        KT:AddBackdrop(btn, 0.025, 0.025, 0.035, 0.96)
    end
    if KT.AddBorder then
        KT:AddBorder(btn, accentR, accentG, accentB, 0.36)
    end

    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetTexture(ns.CATEGORY_OVERVIEW_TEXTURE)
    background:SetVertexColor(accentR, accentG, accentB, 0.08)
    btn._overviewBackground = background

    local accentBar = btn:CreateTexture(nil, "ARTWORK")
    accentBar:SetWidth(4)
    accentBar:SetPoint("TOPLEFT")
    accentBar:SetPoint("BOTTOMLEFT")
    accentBar:SetColorTexture(accentR, accentG, accentB, 0.72)

    local iconBox = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    iconBox:SetSize(72, 50)
    iconBox:SetPoint("LEFT", btn, "LEFT", 13, 0)
    if KT.AddBackdrop then
        local bgR, bgG, bgB, bgA = GetMenuNavBackdropTint(false)
        KT:AddBackdrop(iconBox, bgR, bgG, bgB, bgA)
    end
    if KT.AddBorder then
        KT:AddBorder(iconBox, accentR, accentG, accentB, 0.52)
    end

    local icon = iconBox:CreateTexture(nil, "OVERLAY")
    icon:SetSize(60, 40)
    icon:SetPoint("CENTER")
    local iconTexture, iconName = GetOverviewModuleIcon(page.id)
    icon:SetTexture(iconTexture)
    btn.ico = icon
    btn._iconName = iconName
    ApplyMenuNavButtonIconStyle(btn)
    ApplyMenuNavButtonIconLayout(btn, page.id)

    local title = btn:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT.FONT_PATH, 13, "OUTLINE")
    title:SetPoint("TOPLEFT", iconBox, "TOPRIGHT", 13, -6)
    title:SetPoint("RIGHT", btn, "RIGHT", -28, 0)
    title:SetJustifyH("LEFT")
    title:SetText(LText(page.label or page.id))
    title:SetTextColor(1, 1, 1, 1)

    local description = btn:CreateFontString(nil, "OVERLAY")
    description:SetFont(KT.FONT_PATH, 10, "")
    description:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    description:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -24, 12)
    description:SetJustifyH("LEFT")
    description:SetJustifyV("TOP")
    description:SetWordWrap(true)
    description:SetText(LText(ns.MODULE_DESCRIPTION_MAP[page.id] or "Open this module's configuration options."))
    description:SetTextColor(0.72, 0.72, 0.76, 1)

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(14, 10)
    arrow:SetPoint("RIGHT", btn, "RIGHT", -9, 0)
    arrow:SetTexture(ICON_PATH .. "right_arrow.png")
    arrow:SetVertexColor(accentR, accentG, accentB, 0.76)

    btn:SetScript("OnEnter", function(self)
        self._overviewBackground:SetVertexColor(accentR, accentG, accentB, 0.17)
        if KT.AddBorder then
            KT:AddBorder(self, accentR, accentG, accentB, 0.9)
            KT:AddBorder(iconBox, accentR, accentG, accentB, 0.9)
        end
        title:SetTextColor(accentR, accentG, accentB, 1)
        arrow:SetVertexColor(accentR, accentG, accentB, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self._overviewBackground:SetVertexColor(accentR, accentG, accentB, 0.08)
        if KT.AddBorder then
            KT:AddBorder(self, accentR, accentG, accentB, 0.36)
            KT:AddBorder(iconBox, accentR, accentG, accentB, 0.52)
        end
        title:SetTextColor(1, 1, 1, 1)
        arrow:SetVertexColor(accentR, accentG, accentB, 0.76)
    end)
    btn:SetScript("OnClick", function()
        LoadPage(menu, page.id)
    end)

    return btn
end

local function BuildCategoryOverview(menu, sc, categoryId)
    local category = CATEGORY_BY_ID[categoryId]
    if not category then
        return 1
    end

    local categoryPages = GetRegisteredCategoryPages(categoryId)
    local contentWidth = math.max(420, (sc:GetWidth() or 0) - 20)
    local y = 0
    local accentR, accentG, accentB = GetMenuAccentColor()

    local hero = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    hero:SetSize(contentWidth, 106)
    hero:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)
    if KT.AddBackdrop then
        KT:AddBackdrop(hero, 0.02, 0.02, 0.028, 0.98)
    end
    if KT.AddBorder then
        KT:AddBorder(hero, accentR, accentG, accentB, 0.58)
    end

    local heroAccent = hero:CreateTexture(nil, "ARTWORK")
    heroAccent:SetHeight(3)
    heroAccent:SetPoint("TOPLEFT")
    heroAccent:SetPoint("TOPRIGHT")
    heroAccent:SetColorTexture(accentR, accentG, accentB, 1)

    local categoryIconBox = CreateFrame("Frame", nil, hero, "BackdropTemplate")
    categoryIconBox:SetSize(74, 52)
    categoryIconBox:SetPoint("LEFT", hero, "LEFT", 18, 0)
    if KT.AddBackdrop then
        KT:AddBackdrop(categoryIconBox, 0.035, 0.035, 0.045, 0.98)
    end
    if KT.AddBorder then
        KT:AddBorder(categoryIconBox, accentR, accentG, accentB, 0.72)
    end

    local categoryIcon = categoryIconBox:CreateTexture(nil, "OVERLAY")
    categoryIcon:SetSize(60, 40)
    categoryIcon:SetPoint("CENTER")
    categoryIcon:SetTexture(CATEGORY_ICON_PATH .. category.icon .. ".png")
    local iconR, iconG, iconB = GetMenuIconVertexColor(category.icon or "")
    categoryIcon:SetVertexColor(iconR, iconG, iconB, 1)

    local eyebrow = hero:CreateFontString(nil, "OVERLAY")
    eyebrow:SetFont(KT.FONT_PATH, 9, "OUTLINE")
    eyebrow:SetPoint("TOPLEFT", categoryIconBox, "TOPRIGHT", 16, -2)
    eyebrow:SetText(LText("MODULE CATEGORY"))
    eyebrow:SetTextColor(accentR, accentG, accentB, 1)

    local title = hero:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT.FONT_PATH, 18, "OUTLINE")
    title:SetPoint("TOPLEFT", eyebrow, "BOTTOMLEFT", 0, -5)
    title:SetPoint("RIGHT", hero, "RIGHT", -18, 0)
    title:SetJustifyH("LEFT")
    title:SetText(LText(category.label))
    title:SetTextColor(1, 1, 1, 1)

    local subtitle = hero:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(KT.FONT_PATH, 10, "")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -7)
    subtitle:SetPoint("RIGHT", hero, "RIGHT", -18, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(LText(ns.CATEGORY_DESCRIPTION_MAP[categoryId] or "Choose a module to open its configuration."))
    subtitle:SetTextColor(0.72, 0.72, 0.76, 1)

    y = y + 124

    local sectionHeader = CreateFrame("Frame", nil, sc)
    sectionHeader:SetSize(contentWidth, 18)
    sectionHeader:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)

    local sectionTitle = sectionHeader:CreateFontString(nil, "OVERLAY")
    sectionTitle:SetFont(KT.FONT_PATH, 10, "OUTLINE")
    sectionTitle:SetPoint("LEFT", sectionHeader, "LEFT", 0, 0)
    sectionTitle:SetText(LText("MODULE SHORTCUTS"))
    sectionTitle:SetTextColor(accentR, accentG, accentB, 1)

    local countText = sectionHeader:CreateFontString(nil, "OVERLAY")
    countText:SetFont(KT.FONT_PATH, 9, "")
    countText:SetPoint("RIGHT", sectionHeader, "RIGHT", 0, 0)
    countText:SetText(tostring(#categoryPages) .. " " .. LText("modules available"))
    countText:SetTextColor(0.58, 0.58, 0.62, 1)

    y = y + 27

    local gap = 12
    local columns = contentWidth >= 660 and 2 or 1
    local cardWidth = math.floor((contentWidth - (gap * (columns - 1))) / columns)
    local cardHeight = 104
    local rowGap = 12

    for index, page in ipairs(categoryPages) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        CreateCategoryOverviewModuleButton(sc, menu, page, 10 + column * (cardWidth + gap), y + row * (cardHeight + rowGap), cardWidth)
    end

    local rows = math.ceil(#categoryPages / columns)
    if rows == 0 then
        local empty = sc:CreateFontString(nil, "OVERLAY")
        empty:SetFont(KT.FONT_PATH, 11, "")
        empty:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)
        empty:SetText(LText("No modules are currently available in this category."))
        empty:SetTextColor(0.68, 0.68, 0.72, 1)
        return y + 40
    end

    return y + rows * cardHeight + math.max(0, rows - 1) * rowGap
end

LoadCategoryOverview = function(menu, categoryId, forceReload, preserveScroll)
    if not (menu and CATEGORY_BY_ID[categoryId]) then
        return
    end

    local pageId = GetCategoryOverviewPageId(categoryId)
    if ns.activePageId == pageId and not forceReload then
        return
    end

    local restoreScroll = 0
    if preserveScroll and menu.scrollFrame then
        restoreScroll = GetSafeScrollValue(menu.scrollFrame:GetVerticalScroll())
    end

    ns.activePageId = pageId
    local profile = KT and KT.db and KT.db.profile
    if profile then
        profile.menuLastPageId = pageId
        profile.menuOpenCategory = categoryId
    end

    for _, btn in pairs(ns.navButtons) do
        if btn.UpdateVisual then
            btn:UpdateVisual()
        end
    end

    local sc = menu.scrollChild
    if not sc then
        return
    end

    ClearStickyPreview(menu)
    for _, region in ipairs({sc:GetRegions()}) do
        region:Hide()
    end
    for _, child in ipairs({sc:GetChildren()}) do
        child:Hide()
        child:SetParent(ns.OPTIONS_RECYCLER)
    end
    sc:SetHeight(1)

    local totalH = BuildCategoryOverview(menu, sc, categoryId)
    local menuHeight = (menu.GetHeight and menu:GetHeight()) or MENU_H
    local metrics = GetMenuLayoutMetrics(menu)
    sc:SetHeight(math.max(totalH + 30, menuHeight - metrics.topMargin - metrics.bottomMargin))

    local sf = menu.scrollFrame
    if sf and sf.ScrollBar then
        sf.ScrollBar:SetValue(preserveScroll and restoreScroll or 0)
        ForceScrollBarUpdate(sf, sf.ScrollBar, sf.ScrollBar._thumb, preserveScroll, restoreScroll)
    end

    UpdateUnlockModeShortcut(menu, pageId)
    if menu.UpdateCategoryVisuals then
        menu:UpdateCategoryVisuals()
    end
end
LoadPage = function(menu, pageId, forceReload, preserveScroll)
    local categoryId = GetPageCategoryId(pageId)
    if menu and menu.SetOpenCategory then
        menu:SetOpenCategory(categoryId, pageId, true)
    end
    if ns.activePageId == pageId and not forceReload then return end

    local restoreScroll = 0
    if preserveScroll and menu and menu.scrollFrame then
        restoreScroll = GetSafeScrollValue(menu.scrollFrame:GetVerticalScroll())
    end

    ns.activePageId = pageId
    local profile = KT and KT.db and KT.db.profile
    if profile then
        profile.menuLastPageId = pageId
        profile.menuOpenCategory = categoryId
    end

    for id, btn in pairs(ns.navButtons) do
        if id == pageId then
            btn:SetAlpha(1)
            if btn.selBar then btn.selBar:Show() end
            if btn.selBg  then btn.selBg:Show()  end
            if btn.lbl    then btn.lbl:SetTextColor(1, 1, 1, 1) end
            if btn.iconBox then
                btn.iconBox:SetAlpha(1)
                ApplyMenuNavButtonTheme(btn, true)
            end
            ApplyMenuNavButtonIconStyle(btn)
        else
            btn:SetAlpha(0.55)
            if btn.selBar then btn.selBar:Hide() end
            if btn.selBg  then btn.selBg:Hide()  end
            if btn.lbl    then btn.lbl:SetTextColor(0.78, 0.78, 0.78, 1) end
            if btn.iconBox then
                btn.iconBox:SetAlpha(0.92)
                ApplyMenuNavButtonTheme(btn, false)
            end
            ApplyMenuNavButtonIconStyle(btn)
        end
    end

    local sc = menu.scrollChild
    ClearStickyPreview(menu)
    for _, region in ipairs({sc:GetRegions()}) do
        region:Hide()
    end
    for _, child in ipairs({sc:GetChildren()}) do
        child:Hide()
        child:SetParent(ns.OPTIONS_RECYCLER)
    end
    sc:SetHeight(1)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            collectgarbage("step", 64)
        end)
    end
    local W = KT.Widgets
    if not W then return end

    local proxyW
    local searchFilter = menu._searchFilter or ""
    if searchFilter ~= "" then
        local filter = searchFilter:lower()
        local function SearchValueMatches(value)
            if type(value) == "string" then
                local plain = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                local localized = LocalizeText(plain) or plain
                return plain:lower():find(filter, 1, true) ~= nil
                    or localized:lower():find(filter, 1, true) ~= nil
            elseif type(value) == "table" then
                for key, child in pairs(value) do
                    if SearchValueMatches(key) or SearchValueMatches(child) then return true end
                end
            end
            return false
        end

        local function HighlightSearchMatch(widget)
            if not (widget and widget.CreateTexture) then return end
            local r, g, b = GetMenuAccentColor()
            local glow = widget._ktSearchHighlight
            if not glow then
                glow = widget:CreateTexture(nil, "BACKGROUND")
                glow:SetPoint("TOPLEFT", widget, "TOPLEFT", -6, 4)
                glow:SetPoint("BOTTOMRIGHT", widget, "BOTTOMRIGHT", 6, -4)
                widget._ktSearchHighlight = glow
                local pulse = glow:CreateAnimationGroup()
                pulse:SetLooping("BOUNCE")
                local fade = pulse:CreateAnimation("Alpha")
                fade:SetFromAlpha(0.45)
                fade:SetToAlpha(1)
                fade:SetDuration(0.7)
                glow._ktPulse = pulse
            end
            glow:SetColorTexture(r, g, b, 0.20)
            glow:Show()
            if glow._ktPulse and not glow._ktPulse:IsPlaying() then glow._ktPulse:Play() end
        end

        proxyW = setmetatable({}, {
            __index = function(t, k)
                if type(W[k]) == "function" then
                    return function(self, parent, arg2, arg3, ...)
                        local extra = {...}
                        local widget, height = W[k](W, parent, arg2, arg3, unpack(extra))
                        if k ~= "Spacer" and (SearchValueMatches(arg2) or SearchValueMatches(arg3) or SearchValueMatches(extra)) then
                            HighlightSearchMatch(widget)
                        end
                        return widget, height
                    end
                end
                return W[k]
            end
        })
    else
        proxyW = W
    end

    local totalH
    for _, page in ipairs(ns.pages) do
        if page.id == pageId and page.builder then
            totalH = page.builder(sc, proxyW)
            totalH = AppendModuleProfileTools(sc, W, pageId, totalH)
            totalH = AppendModuleRestoreDefaults(sc, W, pageId, totalH)
            local menuHeight = (menu and menu.GetHeight and menu:GetHeight()) or MENU_H
            local metrics = GetMenuLayoutMetrics(menu)
            sc:SetHeight(math.max(totalH + 30, menuHeight - metrics.topMargin - metrics.bottomMargin))
            break
        end
    end

    local sf = menu.scrollFrame
    if sf.ScrollBar then
        sf.ScrollBar:SetValue(preserveScroll and restoreScroll or 0)
        ForceScrollBarUpdate(sf, sf.ScrollBar, sf.ScrollBar and sf.ScrollBar._thumb, preserveScroll, restoreScroll)
    end

    UpdateUnlockModeShortcut(menu, pageId)
    if menu and menu.UpdateCategoryVisuals then
        menu:UpdateCategoryVisuals()
    end
end

local function RequestMenuPageReflow(menu)
    if not (menu and menu:IsShown() and ns.activePageId) then return end
    if menu._pageReflowScheduled then return end
    menu._pageReflowScheduled = true
    C_Timer.After(0.05, function()
        if not menu then return end
        menu._pageReflowScheduled = false
        if not (menu:IsShown() and ns.activePageId) then return end
        local pid = ns.activePageId
        ns.activePageId = nil
        local categoryId = GetCategoryIdFromOverviewPageId(pid)
        if categoryId then
            LoadCategoryOverview(menu, categoryId, true, true)
        else
            LoadPage(menu, pid, true, true)
        end
    end)
end

-- ============================================================================
-- Corrupted generated comment removed.
-- ============================================================================
local function CreateMenuFrame()
    if KT.MenuPrincipal then return KT.MenuPrincipal end

    local f = CreateFrame("Frame", "KullThranUIMenu", UIParent)
    f:SetSize(MENU_W, MENU_H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:SetResizable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()

    if KT.AddBorder then KT:AddBorder(f, 0, 0, 0, 1) end

    -- Corrupted generated comment removed.
    local bgHolder = CreateFrame("Frame", nil, f)
    bgHolder:SetAllPoints()
    bgHolder:SetClipsChildren(true)
    bgHolder:SetFrameLevel(math.max(0, (f:GetFrameLevel() or 1) - 5))
    f._customBgHolder = bgHolder

    local basePath = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CapasFondo\\"
    
    local backgroundTextures = {}
    local backgroundLayers = {}

    backgroundLayers.fondo = CreateMenuBackgroundLayer(bgHolder, basePath .. "Fondo.png",
        { 0, 1307 }, { 0, 953 }, -7, backgroundTextures)
    backgroundLayers.leftPanel = CreateMenuBackgroundLayer(bgHolder, basePath .. "LeftPanel.png",
        { 0, 294, 349 }, { 109, 164, 894 }, -6, backgroundTextures)
    backgroundLayers.bottomLeft = CreateMenuBackgroundLayer(bgHolder, basePath .. "BottomLeftDivisor.png",
        { 3, 290 }, { 895, 947 }, -5, backgroundTextures)
    backgroundLayers.right = CreateMenuBackgroundLayer(bgHolder, basePath .. "RightDivisor.png",
        { 311, 319, 1307 }, { 71, 79, 953 }, -5, backgroundTextures)
    backgroundLayers.rightTop = CreateMenuBackgroundLayer(bgHolder, basePath .. "RightTopDivisor.png",
        { 1066, 1307 }, { 0, 132 }, -5, backgroundTextures)
    backgroundLayers.unlock = CreateMenuBackgroundLayer(bgHolder, basePath .. "UnlockModeDivisor.png",
        { 0, 285, 467 }, { 0, 152, 156, 356 }, -5, backgroundTextures)

    f._customBgLayers = backgroundLayers
    f._customBgSlices = backgroundTextures
    -- Alias retained for the existing background-ready checks.
    f._customBg = backgroundLayers.fondo.textures[1][1]

    local customBgLift = bgHolder:CreateTexture(nil, "BACKGROUND", nil, -6)
    customBgLift:SetAllPoints(bgHolder)
    customBgLift:SetColorTexture(1, 1, 1, 0.05)
    f._customBgLift = customBgLift

    local customBgHeaderTint = bgHolder:CreateTexture(nil, "BACKGROUND", nil, -5)
    customBgHeaderTint:SetTexture("Interface\\Buttons\\WHITE8x8")
    f._customBgHeaderTint = customBgHeaderTint

    local logoTex = f:CreateTexture(nil, "ARTWORK", nil, 1)
    logoTex:SetSize(80, 80)
    logoTex:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -14)
    logoTex:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png")
    f._logoTex = logoTex

    -- Corrupted generated comment removed.
    local closeBtn = CreateFrame("Button", nil, f)
    closeBtn:SetSize(30, 30)
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -34)
    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetSize(16, 16)
    closeTex:SetPoint("CENTER")
    closeTex:SetTexture(ICON_PATH .. "kui-close.png")
    closeBtn:SetScript("OnClick",  function() KT:OpenMenu() end)
    closeBtn:SetScript("OnEnter",  function() closeTex:SetVertexColor(1, 0.3, 0.3, 1) end)
    closeBtn:SetScript("OnLeave",  function() closeTex:SetVertexColor(0.6, 0.6, 0.6, 1) end)
    f._closeTex = closeTex

    local presetAnchor = closeBtn
    f._sizePresetButtons = {}
    local accentR, accentG, accentB = GetMenuAccentColor()
    for i = #MENU_SIZE_PRESETS, 1, -1 do
        local preset = MENU_SIZE_PRESETS[i]
        local btn = CreateFrame("Button", nil, f)
        btn:SetSize(32, 24)
        btn:SetPoint("RIGHT", presetAnchor, "LEFT", -8, 0)
        if KT.AddBackdrop then KT:AddBackdrop(btn, 0.06, 0.06, 0.08, 0.96) end
        if KT.AddBorder then KT:AddBorder(btn, accentR, accentG, accentB, 0.55) end
        btn.preset = preset
        btn.label = btn:CreateFontString(nil, "OVERLAY")
        btn.label:SetFont(KT.FONT_PATH, 11, "OUTLINE")
        btn.label:SetText(preset.key)
        btn.label:SetTextColor(0.92, 0.92, 0.94, 1)
        btn.label:SetPoint("CENTER")
        btn:SetScript("OnClick", function(self)
            ApplyMenuCustomSize(f, self.preset.width, self.preset.height)
        end)
        btn:SetScript("OnEnter", function(self)
            if KT.AddBorder then KT:AddBorder(self, 1, 1, 1, 0.9) end
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(LText("Window Size: ") .. self.preset.tooltip, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            local lr, lg, lb = GetMenuAccentColor()
            if KT.AddBorder then KT:AddBorder(self, lr, lg, lb, 0.55) end
            if GameTooltip then GameTooltip:Hide() end
        end)
        tinsert(f._sizePresetButtons, 1, btn)
        presetAnchor = btn
    end

    local resizeGrip = CreateFrame("Button", nil, f)
    resizeGrip:SetSize(40, 30)
    resizeGrip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    resizeGrip:RegisterForDrag("LeftButton")
    resizeGrip:SetFrameLevel(f:GetFrameLevel() + 20)
    f._resizeGrip = resizeGrip

    local gripTexture = resizeGrip:CreateTexture(nil, "ARTWORK")
    gripTexture:SetSize(27, 19)
    gripTexture:SetPoint("BOTTOMRIGHT", resizeGrip, "BOTTOMRIGHT", -1, 1)
    gripTexture:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\arrowlauncher.png")
    gripTexture:SetVertexColor(accentR, accentG, accentB, 0.9)
    resizeGrip._texture = gripTexture
    resizeGrip:SetScript("OnEnter", function(self)
        self._texture:SetVertexColor(1, 1, 1, 1)
    end)
    resizeGrip:SetScript("OnLeave", function(self)
        local lr, lg, lb = GetMenuAccentColor()
        self._texture:SetVertexColor(lr, lg, lb, 0.9)
    end)
    resizeGrip:SetScript("OnDragStart", function()
        f._manualResizeActive = true
        f:StartSizing("BOTTOMRIGHT")
    end)
    resizeGrip:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        f._manualResizeActive = false
        PersistManualMenuSize(f)
    end)

    local cpuUsageText = f:CreateFontString(nil, "OVERLAY")
    cpuUsageText:SetFont(KT.FONT_PATH, 11, "OUTLINE")
    cpuUsageText:SetPoint("RIGHT", presetAnchor, "LEFT", -26, 0)
    cpuUsageText:SetWidth(120)
    cpuUsageText:SetJustifyH("RIGHT")
    cpuUsageText:SetTextColor(0.58, 0.58, 0.62, 0.95)
    cpuUsageText:SetText(LText("Calibrating"))
    f.cpuUsageText = cpuUsageText

    local globalSearchIndex = nil
    local function BuildGlobalSearchIndex()
        if globalSearchIndex then return globalSearchIndex end
        globalSearchIndex = {}
        
        local W = KT.Widgets
        if not W then return globalSearchIndex end

        local dummyFrame = CreateFrame("Frame")
        dummyFrame.GetWidth = function() return 500 end
        dummyFrame.GetHeight = function() return 500 end

        local currentBuildingPageId = nil
        local currentBuildingPageLabel = nil

        local function AddIndexedText(value)
            if type(value) == "string" and value ~= "" then
                globalSearchIndex[#globalSearchIndex + 1] = { text = value, pageId = currentBuildingPageId, pageLabel = currentBuildingPageLabel }
            elseif type(value) == "table" then
                for key, child in pairs(value) do
                    if type(key) == "string" then AddIndexedText(key) end
                    if type(child) == "string" or type(child) == "table" then AddIndexedText(child) end
                end
            end
        end

        local proxyW = setmetatable({}, {
            __index = function(_, k)
                if type(W[k]) == "function" then
                    return function(_, parent, arg2, arg3, ...)
                        if k ~= "Spacer" then
                            AddIndexedText(arg2)
                            AddIndexedText(arg3)
                            for _, value in ipairs({...}) do AddIndexedText(value) end
                        end
                        local dummy = CreateFrame("Frame", nil, dummyFrame)
                        dummy:Hide()
                        return dummy, 0
                    end
                end
                return W[k]
            end
        })

        local originalActivePageId = ns.activePageId
        for _, page in ipairs(ns.pages) do
            if page.builder and page.id then
                ns.activePageId = page.id
                currentBuildingPageId = page.id
                currentBuildingPageLabel = page.label or page.id
                AddIndexedText(currentBuildingPageLabel)
                AddIndexedText(page.id)
                if page.id == "enhancements" then
                    -- The Damage Meter controls are built from a secondary tab,
                    -- so make the feature discoverable even when that tab is not active.
                    AddIndexedText(LText("Damage Meter"))
                    AddIndexedText(LText("Damage Meter Settings"))
                    AddIndexedText(LText("Mythic+ Timer"))
                    AddIndexedText(LText("Live Preview"))
                end
                pcall(page.builder, dummyFrame, proxyW)
            end
        end
        ns.activePageId = originalActivePageId

        return globalSearchIndex
    end

    local searchBox = CreateFrame("EditBox", nil, f)
    searchBox:SetHeight(32)
    searchBox:SetPoint("RIGHT", cpuUsageText, "LEFT", -16, 0)
    searchBox:SetPoint("LEFT", f, "TOPLEFT", NAV_W + 20, -38)
    searchBox:SetFont(KT.FONT_PATH, 12, "OUTLINE")
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(31, 32, 0, 0)
    if KT.AddBackdrop then KT:AddBackdrop(searchBox, 0.05, 0.05, 0.06, 0.9) end
    if KT.AddBorder then KT:AddBorder(searchBox, accentR, accentG, accentB, 0.72) end

    local searchIcon = searchBox:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(18, 18)
    searchIcon:SetPoint("LEFT", 8, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetVertexColor(accentR, accentG, accentB, 1)
    f._searchIcon = searchIcon

    local searchHint = searchBox:CreateFontString(nil, "OVERLAY")
    searchHint:SetFont(KT.FONT_PATH, 12, "OUTLINE")
    searchHint:SetTextColor(accentR, accentG, accentB, 0.55)
    searchHint:SetPoint("LEFT", 31, 0)
    searchHint:SetText(LocalizeText("Search..."))
    f._searchHint = searchHint

    local searchClear = CreateFrame("Button", nil, searchBox)
    searchClear:SetSize(24, 24)
    searchClear:SetPoint("RIGHT", searchBox, "RIGHT", -4, 0)
    searchClear:SetFrameLevel(searchBox:GetFrameLevel() + 2)
    searchClear:Hide()

    local searchClearTex = searchClear:CreateTexture(nil, "ARTWORK")
    searchClearTex:SetSize(12, 12)
    searchClearTex:SetPoint("CENTER")
    searchClearTex:SetTexture(ICON_PATH .. "kui-close.png")
    searchClearTex:SetVertexColor(accentR, accentG, accentB, 1)
    searchClear:SetScript("OnEnter", function()
        searchClearTex:SetVertexColor(1, 1, 1, 1)
    end)
    searchClear:SetScript("OnLeave", function()
        local r, g, b = GetMenuAccentColor()
        searchClearTex:SetVertexColor(r, g, b, 1)
    end)
    f._searchClearTex = searchClearTex

    local searchDropdown = CreateFrame("Frame", nil, f, "BackdropTemplate")
    searchDropdown:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
    searchDropdown:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -4)
    searchDropdown:SetHeight(240)
    searchDropdown:SetFrameLevel((f:GetFrameLevel() or 1) + 60)
    searchDropdown:EnableMouse(true)
    searchDropdown:Hide()
    if KT.AddBackdrop then KT:AddBackdrop(searchDropdown, 0.05, 0.05, 0.06, 0.98) end
    if KT.AddBorder then KT:AddBorder(searchDropdown, accentR, accentG, accentB, 0.8) end

    local dropdownScroll = CreateFrame("ScrollFrame", "KT_SearchScroll", searchDropdown)
    dropdownScroll:SetPoint("TOPLEFT", 4, -4)
    dropdownScroll:SetPoint("BOTTOMRIGHT", -20, 4)
    
    local dropdownContent = CreateFrame("Frame", nil, dropdownScroll)
    dropdownContent:SetSize(searchBox:GetWidth() - 24, 1)
    dropdownScroll:SetScrollChild(dropdownContent)
    
    local dropdownSb = CreateFrame("Slider", nil, dropdownScroll)
    dropdownSb:SetPoint("TOPRIGHT", searchDropdown, "TOPRIGHT", -4, -4)
    dropdownSb:SetPoint("BOTTOMRIGHT", searchDropdown, "BOTTOMRIGHT", -4, 4)
    dropdownSb:SetWidth(12)
    dropdownSb:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    dropdownSb:SetOrientation("VERTICAL")
    dropdownSb:SetValueStep(1)
    dropdownSb:SetMinMaxValues(0, 1)
    local ddThumb = dropdownSb:GetThumbTexture()
    if ddThumb then
        ddThumb:SetWidth(12)
        ddThumb:SetHeight(20)
        ddThumb:SetVertexColor(accentR, accentG, accentB, 0.9)
    end
    local dropdownSbBg = dropdownSb:CreateTexture(nil, "BACKGROUND")
    dropdownSbBg:SetAllPoints()
    dropdownSbBg:SetColorTexture(0, 0, 0, 0.5)
    dropdownSb._thumb = ddThumb
    dropdownSb._trackBg = dropdownSbBg
    f._searchDropdown = searchDropdown
    f._searchScrollBar = dropdownSb

    dropdownScroll:EnableMouseWheel(true)
    dropdownScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = dropdownSb:GetValue()
        local min, max = dropdownSb:GetMinMaxValues()
        if delta > 0 then dropdownSb:SetValue(math.max(min, cur - 30))
        else dropdownSb:SetValue(math.min(max, cur + 30)) end
    end)
    dropdownScroll:SetScript("OnVerticalScroll", function(self, offset)
        dropdownSb:SetValue(offset)
    end)
    dropdownSb:SetScript("OnValueChanged", function(self, value)
        dropdownScroll:SetVerticalScroll(value)
    end)

    local searchResultButtons = {}
    f._searchResultButtons = searchResultButtons
    local function CloseSearchDropdown(clearFocus)
        searchDropdown:Hide()
        if clearFocus then
            searchBox:ClearFocus()
        end
    end

    local function UpdateSearchResults(filter)
        filter = filter:lower()
        if filter == "" then
            searchDropdown:Hide()
            return
        end
        local index = BuildGlobalSearchIndex()
        local matches = {}
        local seen = {}
        local terms = {}
        for term in filter:gmatch("%S+") do terms[#terms + 1] = term end
        for _, item in ipairs(index) do
            local cleanText = (item.text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            local locText = LocalizeText(cleanText) or cleanText
            local pageText = LocalizeText(item.pageLabel or "") or item.pageLabel or ""
            local haystack = (cleanText .. " " .. locText .. " " .. pageText .. " " .. (item.pageId or "")):lower()
            local matchesAll = true
            for _, term in ipairs(terms) do if not haystack:find(term, 1, true) then matchesAll = false break end end
            local seenKey = (item.pageId or "") .. "\031" .. cleanText
            if matchesAll and not seen[seenKey] then
                seen[seenKey] = true
                table.insert(matches, { text = cleanText, pageId = item.pageId, pageLabel = item.pageLabel })
            end
        end

        for _, btn in ipairs(searchResultButtons) do
            btn:Hide()
        end

        if #matches == 0 then
            searchDropdown:Hide()
            return
        end

        local resultAccentR, resultAccentG, resultAccentB = GetMenuAccentColor()
        if KT.AddBorder then
            KT:AddBorder(searchDropdown, resultAccentR, resultAccentG, resultAccentB, 0.8)
        end
        ApplyMenuScrollBarTheme(dropdownSb)
        searchDropdown:Show()
        dropdownContent:SetWidth(searchBox:GetWidth() - 24)
        local y = 0
        local btnHeight = 30
        for i, match in ipairs(matches) do
            local btn = searchResultButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, dropdownContent)
                btn:SetSize(dropdownContent:GetWidth(), btnHeight)
                
                local hover = btn:CreateTexture(nil, "BACKGROUND")
                hover:SetAllPoints()
                hover:SetColorTexture(1, 1, 1, 0.1)
                hover:Hide()
                
                local text = btn:CreateFontString(nil, "OVERLAY")
                text:SetFont(KT.FONT_PATH, 11, "OUTLINE")
                text:SetPoint("LEFT", 8, 0)
                text:SetPoint("RIGHT", -100, 0)
                text:SetJustifyH("LEFT")
                text:SetTextColor(0.9, 0.9, 0.9, 1)
                
                local moduleText = btn:CreateFontString(nil, "OVERLAY")
                moduleText:SetFont(KT.FONT_PATH, 10, "OUTLINE")
                moduleText:SetPoint("RIGHT", -8, 0)
                moduleText:SetJustifyH("RIGHT")
                moduleText:SetTextColor(resultAccentR, resultAccentG, resultAccentB, 1)

                local moduleIcon = btn:CreateTexture(nil, "OVERLAY")
                moduleIcon:SetSize(24, 16)
                moduleIcon:SetPoint("RIGHT", moduleText, "LEFT", -6, 0)

                btn.hover = hover
                btn.text = text
                btn.moduleText = moduleText
                btn.moduleIcon = moduleIcon

                btn:SetScript("OnEnter", function() hover:Show() end)
                btn:SetScript("OnLeave", function() hover:Hide() end)
                btn:SetScript("OnClick", function()
                    f._searchFilter = btn.searchText
                    searchBox:SetText(LocalizeText(btn.searchText or "") or btn.searchText or "")
                    CloseSearchDropdown(true)
                    if btn.pageId == "enhancements" and (btn.searchText or ""):lower():find("damage meter", 1, true) then
                        local enhancements = KT:GetModule("Enhancements", true)
                        local edb = enhancements and enhancements.GetDB and enhancements:GetDB()
                        if edb then
                            edb.ui = edb.ui or {}
                            edb.ui.activeEnhancementCategory = "damage"
                        end
                    end
                    if KT.OpenRegisteredPage then
                        KT:OpenRegisteredPage(btn.pageId)
                    end
                end)
                table.insert(searchResultButtons, btn)
            end
            
            btn:SetWidth(dropdownContent:GetWidth())
            btn.text:SetText(LocalizeText(match.text) or match.text)
            btn.moduleText:SetText(LocalizeText(match.pageLabel) or match.pageId)

            btn.moduleText:SetTextColor(resultAccentR, resultAccentG, resultAccentB, 1)
            
            local iconName = ns.PAGE_ICON_MAP[match.pageId] or "Config"
            btn._searchIconName = iconName
            btn.moduleIcon:SetTexture(ICON_PATH .. iconName .. ".png")
            ApplySearchResultIconLayout(btn.moduleIcon, btn.moduleText, match.pageId)
            local ir, ig, ib = GetMenuIconVertexColor(iconName)
            btn.moduleIcon:SetVertexColor(ir, ig, ib, 1)

            btn.pageId = match.pageId
            btn.searchText = match.text
            btn:SetPoint("TOPLEFT", 0, -y)
            btn:Show()
            y = y + btnHeight
        end

        dropdownContent:SetHeight(y)
        local maxScroll = math.max(0, y - searchDropdown:GetHeight() + 8)
        dropdownSb:SetMinMaxValues(0, maxScroll)
        if dropdownSb:GetValue() > maxScroll then
            dropdownSb:SetValue(maxScroll)
        end
    end

    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if self:GetText() == "" then
            searchHint:Show()
            searchClear:Hide()
        else
            searchHint:Hide()
            searchClear:Show()
        end
        if userInput then
            UpdateSearchResults(self:GetText())
        end
    end)

    searchClear:SetScript("OnClick", function()
        searchBox:SetText("")
        f._searchFilter = nil
        UpdateSearchResults("")
        RequestMenuPageReflow(f)
        searchBox:SetFocus()
    end)
    
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        f._searchFilter = nil
        UpdateSearchResults("")
        RequestMenuPageReflow(f)
        self:ClearFocus()
    end)

    local searchMouseWasDown = false
    f:HookScript("OnUpdate", function()
        local mouseIsDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
        if mouseIsDown and not searchMouseWasDown
            and (searchDropdown:IsShown() or searchBox:HasFocus())
            and not searchBox:IsMouseOver()
            and not searchDropdown:IsMouseOver()
        then
            CloseSearchDropdown(true)
        end
        searchMouseWasDown = mouseIsDown
    end)
    
    f.searchBox = searchBox

    -- Corrupted generated comment removed.
    local titleTex = f:CreateFontString(nil, "OVERLAY")
    titleTex:SetFont(KT.FONT_PATH, 13, "OUTLINE")
    local verColor = string.format("%02x%02x%02x", accentR*255, accentG*255, accentB*255)
	titleTex:SetText("|cff" .. verColor .. "v" .. (KT.VERSION or "5.0.6") .. "|r")
    titleTex:SetPoint("TOPLEFT", f, "TOPLEFT", 94, -68)
    titleTex:SetWidth(190)
    titleTex:SetJustifyH("LEFT")
    f._versionText = titleTex
	f._versionValue = KT.VERSION or "5.0.6"

    -- Corrupted generated comment removed.
    local nav = CreateFrame("Frame", nil, f)
    nav:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
    nav:SetWidth(NAV_W)
    nav:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -TOP_MARGIN)
    nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, BOT_MARGIN)
    f._navHost = nav

    local unlockBtn = EnsureUnlockModeShortcut(f)

    -- Corrupted generated comment removed.
    local navScroll = CreateFrame("ScrollFrame", "KT_NavScroll", nav)
    navScroll:SetPoint("TOPLEFT", unlockBtn, "BOTTOMLEFT", 0, -NAV_SCROLL_TOP_GAP)
    navScroll:SetPoint("BOTTOMRIGHT", nav, "BOTTOMRIGHT", -4, NAV_SCROLL_BOTTOM_GAP)
    navScroll:EnableMouseWheel(true)

    -- Manual ScrollBar for Nav
    local navSb = CreateFrame("Slider", nil, navScroll)
    navSb:SetPoint("TOPRIGHT", navScroll, "TOPRIGHT", -2, -4)
    navSb:SetPoint("BOTTOMRIGHT", navScroll, "BOTTOMRIGHT", -2, 4)
    navSb:SetWidth(10)
    navSb:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    navSb:SetOrientation("VERTICAL")
    navSb:SetValueStep(1)
    navSb:SetMinMaxValues(0, 1)
    local nThumb = navSb:GetThumbTexture()
    if nThumb then
        nThumb:SetWidth(4)
        nThumb:SetHeight(24)
    end
    local navSbBg = navSb:CreateTexture(nil, "BACKGROUND")
    navSbBg:SetPoint("TOP", navSb, "TOP", 0, 0)
    navSbBg:SetPoint("BOTTOM", navSb, "BOTTOM", 0, 0)
    navSbBg:SetWidth(2)
    navSb._thumb = nThumb
    navSb._trackBg = navSbBg
    ApplyMenuScrollBarTheme(navSb)

    local function ApplyNavigationScrollRange(yrange)
        if issecretvalue and issecretvalue(yrange) then
            yrange = 0
        else
            yrange = tonumber(yrange) or 0
        end
        yrange = math.max(0, yrange)
        navSb._scrollRange = yrange

        local navH = navScroll:GetHeight()
        if navH and navH > 0 and yrange > 0.5 then
            if f._navContent then
                f._navContent:SetWidth(math.max(180, (nav:GetWidth() or NAV_W) - 18))
            end
            navSb:Show()
            navSb:SetMinMaxValues(0, yrange)
            if navSb:GetValue() > yrange then navSb:SetValue(yrange) end
            local ratio = navH / (navH + yrange)
            if nThumb then
                local trackH = navSb:GetHeight() or math.max(16, navH - 8)
                nThumb:SetHeight(math.min(trackH, math.max(16, math.floor(trackH * ratio))))
            end
        else
            if f._navContent then
                f._navContent:SetWidth(math.max(180, (nav:GetWidth() or NAV_W) - 10))
            end
            navSb:SetMinMaxValues(0, 1)
            navSb:SetValue(0)
            navScroll:SetVerticalScroll(0)
            navSb:Hide()
        end
    end

    navScroll:SetScript("OnScrollRangeChanged", function(self, xrange, yrange)
        ApplyNavigationScrollRange(yrange)
    end)
    navScroll:SetScript("OnVerticalScroll", function(self, offset)
        local range = navSb._scrollRange or 0
        if range > 0 then
            navSb:SetValue(math.max(0, math.min(range, offset or 0)))
        end
    end)
    navScroll:SetScript("OnMouseWheel", function(self, delta)
        local range = navSb._scrollRange or 0
        if range <= 0 then return end
        local cur = navSb:GetValue()
        if delta > 0 then navSb:SetValue(math.max(0, cur - 20))
        else navSb:SetValue(math.min(range, cur + 20)) end
    end)
    navSb:SetScript("OnValueChanged", function(self, value)
        local range = self._scrollRange or 0
        navScroll:SetVerticalScroll(math.max(0, math.min(range, value or 0)))
    end)

    local navContent = CreateFrame("Frame", nil, navScroll)
    navContent:SetWidth(NAV_W - 10)
    navContent:SetHeight(1)
    navScroll:SetScrollChild(navContent)
    f._navScrollBar = navSb
    f._navContent = navContent
    f._navButtons = {}
    f._categoryButtons = {}
    f._categoryButtonsById = {}
    f._moduleButtonsByCategory = {}

    local CATEGORY_BTN_H = 56
    local CATEGORY_BTN_GAP = 6
    local MODULE_BTN_H = 32
    local MODULE_BTN_GAP = 2
    local MODULE_INDENT = 26

    local function ClearNavigationTable(tbl)
        for key in pairs(tbl) do
            tbl[key] = nil
        end
    end

    local function UpdateNavigationScrollRange(revealPageId)
        local navH = navScroll:GetHeight() or 0
        local contentH = navContent:GetHeight() or 0
        local range = math.max(0, contentH - navH)

        ApplyNavigationScrollRange(range)

        local target = revealPageId and ns.navButtons[revealPageId] or nil
        if target and target:IsShown() and navH > 0 then
            local rowTop = target._navOffset or 0
            local rowBottom = rowTop + (target:GetHeight() or MODULE_BTN_H)
            local viewTop = navSb:GetValue() or 0
            local viewBottom = viewTop + navH

            if rowTop < viewTop then
                navSb:SetValue(math.max(0, rowTop))
            elseif rowBottom > viewBottom then
                navSb:SetValue(math.min(range, math.max(0, rowBottom - navH)))
            end
        end
    end

    function f:RefreshNavigationScroll(revealPageId)
        UpdateNavigationScrollRange(revealPageId)
    end

    function f:UpdateCategoryVisuals()
        for _, btn in ipairs(self._categoryButtons or {}) do
            if btn.UpdateVisual then
                btn:UpdateVisual()
            end
        end
        for _, btn in ipairs(self._navButtons or {}) do
            if btn.UpdateVisual then
                btn:UpdateVisual()
            end
        end
    end

    function f:ReflowCategoryNavigation(revealPageId)
        local navY = -NAV_CONTENT_TOP_PADDING

        for _, category in ipairs(ns.MENU_CATEGORIES) do
            local categoryButton = self._categoryButtonsById[category.id]
            local moduleButtons = self._moduleButtonsByCategory[category.id] or {}

            if categoryButton and #moduleButtons > 0 then
                categoryButton:ClearAllPoints()
                categoryButton:SetPoint("TOPLEFT", navContent, "TOPLEFT", 0, navY)
                categoryButton:SetPoint("TOPRIGHT", navContent, "TOPRIGHT", 0, navY)
                categoryButton._navOffset = -navY
                categoryButton:Show()
                navY = navY - CATEGORY_BTN_H - CATEGORY_BTN_GAP

                if IsCategoryOpen(category.id) then
                    for _, moduleButton in ipairs(moduleButtons) do
                        moduleButton:ClearAllPoints()
                        moduleButton:SetPoint("TOPLEFT", navContent, "TOPLEFT", 0, navY)
                        moduleButton:SetPoint("TOPRIGHT", navContent, "TOPRIGHT", 0, navY)
                        moduleButton._navOffset = -navY
                        moduleButton:Show()
                        navY = navY - MODULE_BTN_H - MODULE_BTN_GAP
                    end
                else
                    for _, moduleButton in ipairs(moduleButtons) do
                        moduleButton:Hide()
                    end
                end
            elseif categoryButton then
                categoryButton:Hide()
            end
        end

        navContent:SetHeight(math.max(1, math.abs(navY) + 10))
        self:UpdateCategoryVisuals()
        UpdateNavigationScrollRange(revealPageId)

        C_Timer.After(0, function()
            if self and self._navContent then
                UpdateNavigationScrollRange(revealPageId)
            end
        end)
    end

    function f:SetOpenCategory(categoryId, revealPageId, forceOpen)
        if categoryId and not CATEGORY_BY_ID[categoryId] then
            categoryId = "general_style"
        end
        if not categoryId then
            return
        end

        if forceOpen then
            ns.openCategoryIds[categoryId] = true
        else
            ns.openCategoryIds[categoryId] = not IsCategoryOpen(categoryId) or nil
        end

        local profile = KT and KT.db and KT.db.profile
        if profile then
            profile.menuOpenCategory = categoryId
            profile.menuOpenCategories = {}
            for id, isOpen in pairs(ns.openCategoryIds) do
                if isOpen and CATEGORY_BY_ID[id] then
                    profile.menuOpenCategories[id] = true
                end
            end
        end

        self:ReflowCategoryNavigation(revealPageId)
    end

    local function CreateCategoryButton(category)
        local btn = CreateFrame("Button", nil, navContent)
        local categoryId = category.id
        btn.categoryId = categoryId
        btn:SetHeight(CATEGORY_BTN_H)
        btn:SetAlpha(0.62)

        local selBg = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
        selBg:SetAllPoints()
        selBg:Hide()
        btn.selBg = selBg

        local selBar = btn:CreateTexture(nil, "ARTWORK")
        selBar:SetWidth(6)
        selBar:SetPoint("TOPLEFT")
        selBar:SetPoint("BOTTOMLEFT")
        selBar:Hide()
        btn.selBar = selBar

        local hover = btn:CreateTexture(nil, "BACKGROUND")
        hover:SetAllPoints()
        hover:SetColorTexture(1, 1, 1, 0)
        btn._hov = hover

        local separator = btn:CreateTexture(nil, "ARTWORK")
        separator:SetHeight(1)
        separator:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 0)
        separator:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -8, 0)
        separator:SetColorTexture(1, 1, 1, 0.05)
        btn.sep = separator

        local iconBox = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        iconBox:SetSize(72, 48)
        iconBox:SetPoint("LEFT", btn, "LEFT", 16, 0)
        btn.iconBox = iconBox

        local icon = iconBox:CreateTexture(nil, "OVERLAY")
        icon:SetSize(60, 40)
        icon:SetPoint("CENTER")
        icon:SetTexture(CATEGORY_ICON_PATH .. category.icon .. ".png")
        btn._iconName = category.icon
        btn.ico = icon

        -- Reuse the MinimapButton drawer toggle artwork while leaving the
        -- complete category row as the single click target. A nested button
        -- here can consume or duplicate the parent click when collapsing.
        local categoryToggle = CreateFrame("Frame", nil, btn)
        categoryToggle:SetSize(20, 40)
        categoryToggle:SetPoint("RIGHT", btn, "RIGHT", -5, 0)
        categoryToggle:EnableMouse(false)
        btn.categoryToggle = categoryToggle

        local arrow = categoryToggle:CreateTexture(nil, "ARTWORK")
        arrow:SetPoint("CENTER")
        arrow:SetSize(20, 20)
        arrow:SetTexture(ICON_PATH .. "EnhancedFriendList\\ArrowDown.png")
        arrow:SetTexCoord(0, 1, 0, 1)
        arrow:SetDesaturated(false)
        arrow:SetAlpha(0.92)
        categoryToggle.Icon = arrow
        btn.arrow = arrow

        local label = btn:CreateFontString(nil, "OVERLAY")
        label:SetFont(KT.FONT_PATH, 12, "OUTLINE")
        label:SetText(LText(category.label))
        label:SetPoint("LEFT", iconBox, "RIGHT", 12, 0)
        label:SetPoint("RIGHT", categoryToggle, "LEFT", -6, 0)
        label:SetHeight(40)
        label:SetJustifyH("LEFT")
        label:SetJustifyV("MIDDLE")
        label:SetWordWrap(true)
        btn.lbl = label

        btn.UpdateVisual = function(self)
            local isOpen = IsCategoryOpen(categoryId)
            local isActiveCategory = GetActiveCategoryId() == categoryId

            if self._hov then
                self._hov:SetColorTexture(1, 1, 1, 0)
            end
            self:SetAlpha((isOpen or isActiveCategory) and 1 or 0.62)
            if isActiveCategory then self.selBg:Show() else self.selBg:Hide() end
            if isActiveCategory then self.selBar:Show() else self.selBar:Hide() end
            self.iconBox:SetAlpha(isOpen and 1 or 0.92)
            local textLevel = isActiveCategory and 1 or (isOpen and 0.9 or 0.78)
            self.lbl:SetTextColor(textLevel, textLevel, textLevel, 1)
            local accentR, accentG, accentB = GetMenuAccentColor()
            self.arrow:SetRotation(isOpen and 0 or (math.pi * 1.5))
            self.arrow:SetVertexColor(accentR, accentG, accentB, 1)
            self.arrow:SetDesaturated(false)
            self.arrow:SetAlpha(self:IsMouseOver() and 1 or 0.92)
            ApplyMenuNavButtonTheme(self, isOpen or isActiveCategory)
            ApplyMenuNavButtonIconStyle(self)
        end

        local function ToggleCategory()
            f:SetOpenCategory(categoryId, nil, false)
            LoadCategoryOverview(f, categoryId)
        end

        btn:SetScript("OnEnter", function(self)
            if self.arrow then
                self.arrow:SetAlpha(1)
            end
            if GetActiveCategoryId() ~= categoryId then
                self._hov:SetColorTexture(1, 1, 1, 0.05)
                if self.iconBox and KT.AddBorder then
                    KT:AddBorder(self.iconBox, 1, 1, 1, 0.45)
                end
            end
        end)
        btn:SetScript("OnLeave", function(self)
            self._hov:SetColorTexture(1, 1, 1, 0)
            self:UpdateVisual()
        end)
        btn:SetScript("OnClick", ToggleCategory)

        btn:UpdateVisual()
        return btn
    end

    local function CreateModuleButton(page, categoryId)
        local btn = CreateFrame("Button", nil, navContent)
        local pageId = page.id
        btn.pageId = pageId
        btn.categoryId = categoryId
        btn.isModuleButton = true
        btn:SetHeight(MODULE_BTN_H)
        btn:SetAlpha(0.62)

        local selBg = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
        selBg:SetPoint("TOPLEFT", btn, "TOPLEFT", 20, 0)
        selBg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        selBg:Hide()
        btn.selBg = selBg

        local selBar = btn:CreateTexture(nil, "ARTWORK")
        selBar:SetWidth(3)
        selBar:SetPoint("TOPLEFT", btn, "TOPLEFT", 20, 0)
        selBar:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 20, 0)
        selBar:Hide()
        btn.selBar = selBar

        local hover = btn:CreateTexture(nil, "BACKGROUND")
        hover:SetPoint("TOPLEFT", btn, "TOPLEFT", 20, 0)
        hover:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
        hover:SetColorTexture(1, 1, 1, 0)
        btn._hov = hover

        local iconBox = CreateFrame("Frame", nil, btn, "BackdropTemplate")
        iconBox:SetSize(48, 28)
        iconBox:SetPoint("LEFT", btn, "LEFT", MODULE_INDENT, 0)
        btn.iconBox = iconBox

        local icon = iconBox:CreateTexture(nil, "OVERLAY")
        icon:SetSize(40, 26)
        icon:SetPoint("CENTER")
        local iconName = ns.MODULE_ICON_MAP[pageId]
        if iconName then
            icon:SetTexture(MODULE_ICON_PATH .. iconName .. ".png")
        else
            iconName = ns.PAGE_ICON_MAP[pageId] or pageId
            icon:SetTexture(ICON_PATH .. iconName .. ".png")
        end
        btn._iconName = iconName
        btn.ico = icon

        local label = btn:CreateFontString(nil, "OVERLAY")
        label:SetFont(KT.FONT_PATH, 12, "OUTLINE")
        label:SetText(LText(page.label))
        label:SetPoint("LEFT", iconBox, "RIGHT", 10, 0)
        label:SetPoint("RIGHT", btn, "RIGHT", -12, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        btn.lbl = label

        btn.UpdateVisual = function(self)
            local isActive = ns.activePageId == pageId
            self:SetAlpha(isActive and 1 or 0.62)
            if isActive then
                self.selBg:Show()
                self.selBar:Show()
            else
                self.selBg:Hide()
                self.selBar:Hide()
            end
            self.iconBox:SetAlpha(isActive and 1 or 0.88)
            self.lbl:SetTextColor(isActive and 1 or 0.76, isActive and 1 or 0.76, isActive and 1 or 0.76, 1)
            ApplyMenuNavButtonTheme(self, isActive)
            ApplyMenuNavButtonIconStyle(self)
        end

        btn:SetScript("OnEnter", function(self)
            if ns.activePageId ~= pageId then
                self._hov:SetColorTexture(1, 1, 1, 0.05)
                if self.iconBox and KT.AddBorder then
                    KT:AddBorder(self.iconBox, 1, 1, 1, 0.45)
                end
            end
        end)
        btn:SetScript("OnLeave", function(self)
            self._hov:SetColorTexture(1, 1, 1, 0)
            self:UpdateVisual()
        end)
        btn:SetScript("OnClick", function()
            LoadPage(f, pageId)
        end)

        btn:UpdateVisual()
        return btn
    end

    function f:RebuildCategoryNavigation()
        for _, btn in ipairs(self._categoryButtons or {}) do
            btn:Hide()
            btn:SetParent(ns.OPTIONS_RECYCLER)
        end
        for _, btn in ipairs(self._navButtons or {}) do
            btn:Hide()
            btn:SetParent(ns.OPTIONS_RECYCLER)
        end

        self._categoryButtons = {}
        self._categoryButtonsById = {}
        self._moduleButtonsByCategory = {}
        self._navButtons = {}
        ClearNavigationTable(ns.navButtons)
        ClearNavigationTable(ns.categoryButtons)

        for _, category in ipairs(ns.MENU_CATEGORIES) do
            local categoryPages = {}
            for _, page in ipairs(ns.pages) do
                local pageCategoryId = page.categoryId or GetPageCategoryId(page.id)
                if pageCategoryId == category.id then
                    categoryPages[#categoryPages + 1] = page
                end
            end

            if #categoryPages > 0 then
                local categoryButton = CreateCategoryButton(category)
                self._categoryButtons[#self._categoryButtons + 1] = categoryButton
                self._categoryButtonsById[category.id] = categoryButton
                ns.categoryButtons[category.id] = categoryButton
                self._moduleButtonsByCategory[category.id] = {}

                for _, page in ipairs(categoryPages) do
                    local moduleButton = CreateModuleButton(page, category.id)
                    self._navButtons[#self._navButtons + 1] = moduleButton
                    self._moduleButtonsByCategory[category.id][#self._moduleButtonsByCategory[category.id] + 1] = moduleButton
                    ns.navButtons[page.id] = moduleButton
                end
            end
        end

        local hasOpenCategory = false
        for categoryId, isOpen in pairs(ns.openCategoryIds) do
            if not isOpen or not self._categoryButtonsById[categoryId] then
                ns.openCategoryIds[categoryId] = nil
            else
                hasOpenCategory = true
            end
        end

        if not hasOpenCategory then
            local profile = KT and KT.db and KT.db.profile
            local savedCategories = profile and profile.menuOpenCategories
            local hasSavedCategoryState = type(savedCategories) == "table"
            if type(savedCategories) == "table" then
                for _, category in ipairs(ns.MENU_CATEGORIES) do
                    if savedCategories[category.id] and self._categoryButtonsById[category.id] then
                        ns.openCategoryIds[category.id] = true
                        hasOpenCategory = true
                    end
                end
            end

            if not hasOpenCategory and not hasSavedCategoryState then
                local savedCategoryId = profile and profile.menuOpenCategory
                if savedCategoryId and self._categoryButtonsById[savedCategoryId] then
                    ns.openCategoryIds[savedCategoryId] = true
                    hasOpenCategory = true
                end
            end

            if not hasOpenCategory and not hasSavedCategoryState and self._categoryButtons[1] then
                ns.openCategoryIds[self._categoryButtons[1].categoryId] = true
            end
        end

        self:ReflowCategoryNavigation(ns.activePageId)

        local overviewCategoryId = GetCategoryIdFromOverviewPageId(ns.activePageId)
        if overviewCategoryId and self.scrollChild and C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if self and self:IsShown() then
                    ns.activePageId = nil
                    LoadCategoryOverview(self, overviewCategoryId, true, true)
                end
            end)
        end
    end

    f:RebuildCategoryNavigation()

    -- Botones Inferiores (Reload & Reset)
    local discWidth = 34
    local gap = 6
    local navMargin = 10
    local btnWidth = (NAV_W - (navMargin * 2) - discWidth - (gap * 2)) / 2

    local reloadBtn = CreateFrame("Button", nil, f)
    reloadBtn:SetSize(btnWidth - 10, 34)
    reloadBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", navMargin, 15)
    if KT.AddBackdrop then KT:AddBackdrop(reloadBtn, 0.1, 0.1, 0.1, 1) end
    if KT.AddBorder then KT:AddBorder(reloadBtn, 0.4, 0.4, 0.4, 0.7) end
    local reloadLbl = reloadBtn:CreateFontString(nil, "OVERLAY")
    reloadLbl:SetFont(KT.FONT_PATH, 12, "OUTLINE")
    reloadLbl:SetText(LText("Reload UI"))
    reloadLbl:SetTextColor(1, 1, 1, 1)
    reloadLbl:SetAllPoints(); reloadLbl:SetJustifyH("CENTER")
    reloadBtn:SetScript("OnClick", ReloadUI)
    reloadBtn:SetScript("OnEnter", function() if KT.AddBorder then KT:AddBorder(reloadBtn, 1, 1, 1, 1) end end)
    reloadBtn:SetScript("OnLeave", function() if KT.AddBorder then KT:AddBorder(reloadBtn, 0.4, 0.4, 0.4, 0.7) end end)
    f._reloadBtn = reloadBtn
    f._reloadLabel = reloadLbl

    local resetBtn = CreateFrame("Button", nil, f)
    resetBtn:SetSize(btnWidth + 10, 34)
    resetBtn:SetPoint("LEFT", reloadBtn, "RIGHT", gap, 0)
    if KT.AddBackdrop then KT:AddBackdrop(resetBtn, 0.15, 0.03, 0.03, 1) end
    if KT.AddBorder then KT:AddBorder(resetBtn, 0.8, 0.1, 0.1, 0.7) end
    local resetLbl = resetBtn:CreateFontString(nil, "OVERLAY")
    resetLbl:SetFont(KT.FONT_PATH, 12, "OUTLINE")
    resetLbl:SetText(LText("Reset Profile"))
    resetLbl:SetTextColor(1, 0.4, 0.4, 1)
    resetLbl:SetAllPoints(); resetLbl:SetJustifyH("CENTER")
    resetBtn:SetScript("OnClick",  ResetConfirm)
    resetBtn:SetScript("OnEnter",  function() if KT.AddBorder then KT:AddBorder(resetBtn, 1, 0.2, 0.2, 1) end end)
    resetBtn:SetScript("OnLeave",  function()
        local palette = GetOptionsStylePalette()
        local accent = palette.accent or {}
        if KT.AddBorder then
            KT:AddBorder(resetBtn, accent.r or 1, accent.g or 0, accent.b or 0.333, 0.7)
        end
        if resetLbl then
            resetLbl:SetTextColor(accent.r or 1, accent.g or 0, accent.b or 0.333, 1)
        end
    end)
    f._resetBtn = resetBtn
    f._resetLabel = resetLbl

    local discordBtn = CreateFrame("Button", nil, f)
    discordBtn:SetSize(discWidth, 34)
    discordBtn:SetPoint("LEFT", resetBtn, "RIGHT", gap, 0)
    if KT.AddBackdrop then KT:AddBackdrop(discordBtn, 0.15, 0.15, 0.2, 1) end
    if KT.AddBorder then KT:AddBorder(discordBtn, 0.3, 0.3, 0.5, 0.7) end
    local discIcon = discordBtn:CreateTexture(nil, "ARTWORK")
    discIcon:SetSize(22, 22)
    discIcon:SetPoint("CENTER")
    discIcon:SetTexture(ICON_PATH .. "discord-2.png")
    discordBtn:SetScript("OnClick", ShowDiscordPopup)
    discordBtn:SetScript("OnEnter", function(s) if KT.AddBorder then KT:AddBorder(s, 0.5, 0.5, 0.8, 1) end end)
    discordBtn:SetScript("OnLeave", function(s)
        local palette = GetOptionsStylePalette()
        local accent = palette.accent or {}
        if KT.AddBorder then
            KT:AddBorder(s, accent.r or 1, accent.g or 0, accent.b or 0.333, 0.7)
        end
        if discIcon then
            discIcon:SetVertexColor(accent.r or 1, accent.g or 0, accent.b or 0.333, 1)
        end
    end)
    f._discordBtn = discordBtn
    f._discordIcon = discIcon

    -- Corrupted generated comment removed.
    local sf, sc = CreateContentScroll(f)
    sf:SetFrameLevel((f:GetFrameLevel() or 1) + 12)
    sc:SetFrameLevel((sf:GetFrameLevel() or ((f:GetFrameLevel() or 1) + 12)) + 1)
    f.scrollFrame = sf
    f.scrollChild = sc
    local previewHost = CreateFrame("Frame", nil, f)
    previewHost:SetPoint("TOPLEFT", sf, "TOPLEFT", 0, 0)
    previewHost:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
    previewHost:SetHeight(1)
    previewHost:SetClipsChildren(false)
    previewHost:SetFrameStrata(f:GetFrameStrata())
    previewHost:SetFrameLevel(sf:GetFrameLevel() + 20)
    if KT.AddBackdrop then KT:AddBackdrop(previewHost, 0.02, 0.02, 0.03, 0.94) end
    if KT.AddBorder then KT:AddAccentBorder(previewHost, 0.65) end
    if previewHost.bgKT then
        previewHost.bgKT:SetColorTexture(0.03, 0.03, 0.04, 0.92)
    end
    previewHost:Hide()
    f._stickyPreviewHost = previewHost
    KT._scrollFrame = sf
    f.RefreshTheme = function(self)
        UpdateMenuThemeVisuals(self)
    end
    f:SetScript("OnSizeChanged", function(self, width, height)
        if self._applyingSizeChange then return end
        local clampedW, clampedH = ClampMenuSize(width, height)
        if math.abs((width or 0) - clampedW) > 0.5 or math.abs((height or 0) - clampedH) > 0.5 then
            self._applyingSizeChange = true
            self:SetSize(clampedW, clampedH)
            self._applyingSizeChange = false
            return
        end

        UpdateMenuLayoutForSize(self)
        UpdateMenuBackgroundLayout(self)
        UpdateStickyPreviewLayout(self)
        if self._manualResizeActive then
            PersistManualMenuSize(self)
        end
        RequestMenuPageReflow(self)
    end)
    f:HookScript("OnShow", function(self)
        StartMenuCpuUsageTicker(self)

        -- The menu can be hidden by Unlock Mode and shown again without
        -- reloading the active page. Refresh the shortcut here so its
        -- selected state always reflects the real Unlock Mode state.
        if self._ktUnlockShortcut and self._ktUnlockShortcut.UpdateVisual then
            self._ktUnlockShortcut:UpdateVisual()
        end
    end)
    f:HookScript("OnHide", function(self)
        StopMenuCpuUsageTicker(self)
    end)
    if not KT.SmoothScrollTo then
        function KT.SmoothScrollTo(pos)
            if not (KT.MenuPrincipal and KT.MenuPrincipal.scrollFrame and KT.MenuPrincipal.scrollFrame.ScrollBar) then return end
            local target = tonumber(pos) or 0
            local host = KT.MenuPrincipal._stickyPreviewHost
            if host and host:IsShown() then
                target = target - (host:GetHeight() or 0) - 12
            end
            KT.MenuPrincipal.scrollFrame.ScrollBar:SetValue(math.max(0, target))
        end
    end

    tinsert(UISpecialFrames, f:GetName())
    KT.MenuPrincipal = f
    ApplyResponsiveMenuMetrics(f)
    UpdateMenuThemeVisuals(f)
    UpdateMenuBackgroundLayout(f)

    if ns.pages[1] then
        local profile = KT and KT.db and KT.db.profile
        local savedPageId = profile and profile.menuLastPageId
        local savedCategoryId = GetCategoryIdFromOverviewPageId(savedPageId)
        if savedCategoryId then
            C_Timer.After(0, function() LoadCategoryOverview(f, savedCategoryId) end)
        else
            local initialPageId = HasRegisteredPage(savedPageId) and savedPageId or ns.pages[1].id
            C_Timer.After(0, function() LoadPage(f, initialPageId) end)
        end
    end

    return f
end

-- ============================================================================
-- Corrupted generated comment removed.
-- ============================================================================
local function LockScaleGuard()
    if not UIParent then return end
    if KT and KT.db and KT.db.profile and KT.db.profile.useBlizzardUIScale then
        return
    end
    local locked = UIParent:GetScale()
    if not locked or locked <= 0 then return end

    if KT and KT.db and KT.db.profile then
        local desired = tonumber(KT.db.profile.uiScale)
        local auto = (KT.db.profile.autoResolutionScale ~= false)
        if auto or not desired then
            local _, height = GetPhysicalScreenSize()
            if height and height >= 2160 then
                desired = 0.35
            elseif height and height >= 1440 then
                desired = 0.53
            else
                desired = 0.71
            end
            KT.db.profile.uiScale = desired
        end
        if desired and math.abs(desired - locked) > 0.001 then
            if KT and KT._ApplyScaleValue then
                KT:_ApplyScaleValue(desired)
            else
                UIParent:SetScale(desired)
            end
            locked = desired
        end
    end

    if not KT._scaleLockHooked then
        KT._scaleLockHooked = true
        hooksecurefunc(UIParent, "SetScale", function(_, newScale)
            if KT._scaleLocked and newScale and math.abs(newScale - KT._scaleLockValue) > 0.001 then
                C_Timer.After(0, function()
                    if KT._scaleLocked and UIParent then
                        if KT and KT._ApplyScaleValue then
                            KT:_ApplyScaleValue(KT._scaleLockValue)
                        else
                            UIParent:SetScale(KT._scaleLockValue)
                        end
                    end
                end)
            end
        end)
    end

    if not KT._cvarLockHooked then
        KT._cvarLockHooked = true
        hooksecurefunc("SetCVar", function(cvar, value)
            if KT._scaleLocked and cvar and cvar:lower() == "uiscale" then
                C_Timer.After(0, function()
                    if KT._scaleLocked and UIParent then
                        if KT and KT._ApplyScaleValue then
                            KT:_ApplyScaleValue(KT._scaleLockValue)
                        else
                            UIParent:SetScale(KT._scaleLockValue)
                        end
                    end
                end)
            end
        end)
    end

    KT._scaleLockValue = locked
    KT._scaleLocked    = true

    C_Timer.After(0.5, function()
        KT._scaleLocked = false
    end)
end

local function CloseGameMenuForKUIOptions()
    local gameMenu = _G.GameMenuFrame
    if gameMenu and gameMenu:IsShown() then
        if HideUIPanel then
            pcall(HideUIPanel, gameMenu)
        end
        if gameMenu:IsShown() and gameMenu.Hide then
            pcall(gameMenu.Hide, gameMenu)
        end
    end
end

function KT:OpenMenu(pageId)
    CloseGameMenuForKUIOptions()

    local unlockMode = self.GetModule and self:GetModule("UnlockMode", true)
    if unlockMode and unlockMode.isOpen and unlockMode.CloseUnlockMode then
        unlockMode:CloseUnlockMode(true, true)
    end

    if self._openingMenu then
        return self.MenuPrincipal
    end

    self._openingMenu = true
    local f = CreateMenuFrame()
    local ok, err = xpcall(function()
        if f:IsShown() and not pageId then
            f:Hide()
        else
            LockScaleGuard()
            ApplyResponsiveMenuMetrics(f)
            f:Show()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, CloseGameMenuForKUIOptions)
            end

            if UIParent and KT._scaleLockValue and not (KT.db and KT.db.profile and KT.db.profile.useBlizzardUIScale) then
                local cur = UIParent:GetScale()
                if cur and math.abs(cur - KT._scaleLockValue) > 0.001 then
                    if KT and KT._ApplyScaleValue then
                        KT:_ApplyScaleValue(KT._scaleLockValue)
                    else
                        UIParent:SetScale(KT._scaleLockValue)
                    end
                end
            end

            if pageId then
                local requestedCategoryId = GetCategoryIdFromOverviewPageId(pageId)
                if requestedCategoryId then
                    f:SetOpenCategory(requestedCategoryId, nil, true)
                    LoadCategoryOverview(f, requestedCategoryId)
                else
                    LoadPage(f, pageId)
                    if C_Timer and C_Timer.After and HasRegisteredPage(pageId) then
                        C_Timer.After(0, function()
                            if f and f:IsShown() then
                                LoadPage(f, pageId, true)
                            end
                        end)
                    end
                end
            elseif ns.pages[1] and not ns.activePageId then
                local profile = KT and KT.db and KT.db.profile
                local savedPageId = profile and profile.menuLastPageId
                local savedCategoryId = GetCategoryIdFromOverviewPageId(savedPageId)
                if savedCategoryId then
                    LoadCategoryOverview(f, savedCategoryId)
                else
                    local initialPageId = HasRegisteredPage(savedPageId) and savedPageId or ns.pages[1].id
                    LoadPage(f, initialPageId)
                end
            end

        end
    end, geterrorhandler() or debugstack)

    self._openingMenu = nil
    if not ok then
        error(err)
    end

    return f
end

function KT:ToggleConfig()
    self:OpenMenu()
end

function KT:RefreshPage(preserveScroll)
    if KT.MenuPrincipal and KT.MenuPrincipal:IsShown() and ns.activePageId then
        local pid = ns.activePageId
        -- Same-page controls frequently rebuild their page. Preserve the viewport
        -- by default; callers performing real navigation can pass false explicitly.
        local shouldPreserveScroll = preserveScroll
        if shouldPreserveScroll == nil then
            shouldPreserveScroll = true
        end
        ns.activePageId = nil
        local categoryId = GetCategoryIdFromOverviewPageId(pid)
        if categoryId then
            LoadCategoryOverview(KT.MenuPrincipal, categoryId, true, shouldPreserveScroll == true)
        else
            LoadPage(KT.MenuPrincipal, pid, true, shouldPreserveScroll == true)
        end
    end
end

function KT:RefreshMenuFonts()
    local menu = self.MenuPrincipal
    local fontPath = self.FONT_PATH
    if not menu or type(fontPath) ~= "string" or fontPath == "" then return end

    local visited = {}
    local function ApplyObjectFont(object)
        if not object or visited[object] then return end
        visited[object] = true

        local objectType = object.GetObjectType and object:GetObjectType()
        if (objectType == "FontString" or objectType == "EditBox") and object.GetFont and object.SetFont then
            local _, size, flags = object:GetFont()
            if size then
                pcall(object.SetFont, object, fontPath, size, flags or "")
            end
        end

        if object.GetRegions then
            for index = 1, select("#", object:GetRegions()) do
                ApplyObjectFont(select(index, object:GetRegions()))
            end
        end
        if object.GetChildren then
            for index = 1, select("#", object:GetChildren()) do
                ApplyObjectFont(select(index, object:GetChildren()))
            end
        end
    end

    ApplyObjectFont(menu)
end

-- ============================================================================
-- ============================================================================
-- Corrupted generated comment removed.
-- ============================================================================
-- ============================================================================

local generalSubTab = "general"
local actionbarsSubTab = "general"
local buffsSubTab = "general"
local armorySubTab = "general"
local chatSubTab = "general"

local ACTIONBARS_SUBTABS = {
    { id = "general", label = "General" },
    { id = "shapes", label = "Shapes" },
    { id = "layout", label = "Layout" },
    { id = "text", label = "Typography" },
    { id = "fade", label = "Fade" },
}

local BUFFS_SUBTABS = {
    { id = "general", label = "General" },
    { id = "buffs", label = "Buffs" },
    { id = "debuffs", label = "Debuffs" },
    { id = "text", label = "Text" },
}

local ARMORY_SUBTABS = {
    { id = "general", label = "General" },
    { id = "itemlevel", label = "Item Level" },
    { id = "enchants", label = "Enchants" },
    { id = "stats", label = "Stats" },
}

local CHAT_SUBTABS = {
    { id = "general", label = "General" },
    { id = "appearance", label = "Appearance" },
    { id = "tabs1", label = "Tabs 1-3" },
    { id = "tabs2", label = "Tabs 4-6" },
}
local profilesSelectionName = nil
local profilesDraftName = ""
local selectedModuleExports = {}
local selectedCDMSpecExports = {}
local PAGE_BUTTON_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Button.png"

local GENERAL_SUBTABS = {
    { id = "general", label = "General" },
    { id = "disablemodules", label = "Disable Modules" },
    { id = "compatibility", label = "Compatibility" },
    { id = "profiles", label = "Profiles" },
    { id = "quicksetup", label = "Quick Setup" },
    { id = "fontscolors", label = "Fonts & Colors" },
}

function KT:SetGeneralOptionsSubTab(tabId)
    generalSubTab = tabId or "general"
end

local function DetectResolutionPresetAndScale()
    local _, height = GetPhysicalScreenSize()
    if height and height >= 2160 then return "4K", 0.35 end
    if height and height >= 1440 then return "2K", 0.53 end
    return "1080p", 0.71
end

local function GetProfilesModule()
    return KT:GetModule("Profiles", true)
end

local function GetConflictDetectorModule()
    return KT:GetModule("AddonConflictDetector", true)
end

function KT:OpenCompatibilityPanel()
    generalSubTab = "compatibility"
    self:OpenMenu("general")
    if self.RefreshPage then
        self:RefreshPage()
    end
end

local function EnsureProfileState()
    local profileMod = GetProfilesModule()
    if not profileMod then
        return
    end

    local _, profileList = profileMod:GetProfileValues()
    if not profilesSelectionName or not tContains(profileList, profilesSelectionName) then
        profilesSelectionName = KT.db and KT.db:GetCurrentProfile() or profileList[1]
    end

    local availableModules = {}
    for _, def in ipairs(profileMod:GetModuleDefinitions()) do
        availableModules[def.id] = true
        if selectedModuleExports[def.id] == nil then
            selectedModuleExports[def.id] = false
        end
    end
    for moduleID in pairs(selectedModuleExports) do
        if not availableModules[moduleID] then
            selectedModuleExports[moduleID] = nil
        end
    end

    for _, specInfo in ipairs(profileMod:GetCDMSpecEntries()) do
        if selectedCDMSpecExports[specInfo.key] == nil then
            selectedCDMSpecExports[specInfo.key] = specInfo.hasData and true or false
        end
    end
end

local function CollectSelectedKeys(selectionTable)
    local selected = {}
    for key, enabled in pairs(selectionTable) do
        if enabled then
            selected[#selected + 1] = key
        end
    end
    table.sort(selected)
    return selected
end

local function SetAllSelections(selectionTable, entries, value)
    for _, entry in ipairs(entries) do
        selectionTable[entry.id or entry.key] = value
    end
end

local function GetCurrentSpecVisual()
    local specIndex = GetSpecialization and GetSpecialization() or nil
    if not specIndex or specIndex <= 0 then
        return nil, LText("No Specialization"), nil
    end
local specID, specName, _, specIcon = GetSpecializationInfo(specIndex)
    return specID, specName or LText("Unknown Spec"), specIcon
end

local function AddPageSubTabBar(parent, yOffset, tabs, selectedId, onSelect)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(parent:GetWidth() - 20, 44)
    frame:SetPoint("TOPLEFT", 10, yOffset)
    frame:SetClipsChildren(false)

    local gap = 4
    local btnWidth = math.floor((frame:GetWidth() - (gap * (#tabs - 1))) / #tabs)
    local accentR, accentG, accentB = GetMenuAccentColor()

    local tex = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\MenuButtonTab.png"
    local minX = 12 / 601
    local maxX = 586 / 601
    local minY = 8 / 147
    local maxY = 136 / 147
    local cx = 8 / 601
    local cy = 8 / 147
    local cornerScreen = 4

    for index, tabInfo in ipairs(tabs) do
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(btnWidth, 38)
        button:SetPoint("TOPLEFT", (index - 1) * (btnWidth + gap), 0)
        button:SetHighlightTexture("")

        local visual = CreateFrame("Frame", nil, button)
        visual:SetAllPoints()
        visual:SetFrameLevel(button:GetFrameLevel() + 8)
        visual:SetClipsChildren(false)

        local slices = {}
        for i = 1, 9 do
            local t = visual:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(tex)
            slices[i] = t
        end
        local TL, TR, BL, BR, T, B, L, R, C = unpack(slices)

        TL:SetSize(cornerScreen, cornerScreen); TR:SetSize(cornerScreen, cornerScreen)
        BL:SetSize(cornerScreen, cornerScreen); BR:SetSize(cornerScreen, cornerScreen)
        TL:SetPoint("TOPLEFT"); TR:SetPoint("TOPRIGHT")
        BL:SetPoint("BOTTOMLEFT"); BR:SetPoint("BOTTOMRIGHT")
        T:SetPoint("TOPLEFT", TL, "TOPRIGHT"); T:SetPoint("BOTTOMRIGHT", TR, "BOTTOMLEFT")
        B:SetPoint("TOPLEFT", BL, "TOPRIGHT"); B:SetPoint("BOTTOMRIGHT", BR, "BOTTOMLEFT")
        L:SetPoint("TOPLEFT", TL, "BOTTOMLEFT"); L:SetPoint("BOTTOMRIGHT", BL, "TOPRIGHT")
        R:SetPoint("TOPLEFT", TR, "BOTTOMLEFT"); R:SetPoint("BOTTOMRIGHT", BR, "TOPRIGHT")
        C:SetPoint("TOPLEFT", TL, "BOTTOMRIGHT"); C:SetPoint("BOTTOMRIGHT", BR, "TOPLEFT")

        TL:SetTexCoord(minX, minX+cx, minY, minY+cy)
        TR:SetTexCoord(maxX-cx, maxX, minY, minY+cy)
        BL:SetTexCoord(minX, minX+cx, maxY-cy, maxY)
        BR:SetTexCoord(maxX-cx, maxX, maxY-cy, maxY)
        T:SetTexCoord(minX+cx, maxX-cx, minY, minY+cy)
        B:SetTexCoord(minX+cx, maxX-cx, maxY-cy, maxY)
        L:SetTexCoord(minX, minX+cx, minY+cy, maxY-cy)
        R:SetTexCoord(maxX-cx, maxX, minY+cy, maxY-cy)
        C:SetTexCoord(minX+cx, maxX-cx, minY+cy, maxY-cy)

        button.slices = slices
        for _, t in ipairs(slices) do
            t:SetVertexColor(accentR, accentG, accentB, selectedId == tabInfo.id and 1 or 0.4)
        end

        local label = visual:CreateFontString(nil, "OVERLAY")
        label:SetFont(KT.FONT_PATH, 11, "OUTLINE")
        label:SetText(LText(tabInfo.label))
        label:SetPoint("CENTER", 0, 0)
        label:SetTextColor(selectedId == tabInfo.id and 1 or 0.7, selectedId == tabInfo.id and 1 or 0.7, selectedId == tabInfo.id and 1 or 0.7, 1)

        button:SetScript("OnEnter", function()
            for _, t in ipairs(button.slices) do t:SetVertexColor(accentR, accentG, accentB, 1) end
            label:SetTextColor(1, 1, 1, 1)
        end)
        button:SetScript("OnLeave", function()
            for _, t in ipairs(button.slices) do t:SetVertexColor(accentR, accentG, accentB, selectedId == tabInfo.id and 1 or 0.4) end
            label:SetTextColor(selectedId == tabInfo.id and 1 or 0.7, selectedId == tabInfo.id and 1 or 0.7, selectedId == tabInfo.id and 1 or 0.7, 1)
        end)
        button:SetScript("OnClick", function()
            onSelect(tabInfo.id)
        end)
    end
    return frame, 50
end

function KT.AddOptionsSubTabBar(parent, yOffset, tabs, selectedId, onSelect)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(parent:GetWidth() - 20, 44)
    frame:SetPoint("TOPLEFT", 10, yOffset)
    frame:SetClipsChildren(false)

    local gap = 4
    local btnWidth = math.floor((frame:GetWidth() - (gap * (#tabs - 1))) / #tabs)
    local accentR, accentG, accentB = GetMenuAccentColor()

    for index, tabInfo in ipairs(tabs) do
        local button = CreateFrame("Button", nil, frame)
        button:SetSize(btnWidth, 38)
        button:SetPoint("TOPLEFT", (index - 1) * (btnWidth + gap), 0)
        button:SetHighlightTexture("")

        local visual = CreateFrame("Frame", nil, button)
        visual:SetAllPoints()
        visual:SetFrameLevel(button:GetFrameLevel() + 8)
        visual:SetClipsChildren(false)
        
        -- 9-slice implementation using actual 601x147 image dimensions
        local tex = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\MenuButton.png"
        local minX = 12 / 601
        local maxX = 586 / 601
        local minY = 8 / 147
        local maxY = 136 / 147
        local cornerScreen = 4
        local cx = 8 / 601
        local cy = 8 / 147

        local slices = {}
        for i = 1, 9 do
            local t = visual:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(tex)
            slices[i] = t
        end
        local TL, TR, BL, BR, T, B, L, R, C = unpack(slices)

        -- Size corners
        TL:SetSize(cornerScreen, cornerScreen)
        TR:SetSize(cornerScreen, cornerScreen)
        BL:SetSize(cornerScreen, cornerScreen)
        BR:SetSize(cornerScreen, cornerScreen)
        
        -- Position corners
        TL:SetPoint("TOPLEFT")
        TR:SetPoint("TOPRIGHT")
        BL:SetPoint("BOTTOMLEFT")
        BR:SetPoint("BOTTOMRIGHT")

        -- Position edges
        T:SetPoint("TOPLEFT", TL, "TOPRIGHT")
        T:SetPoint("BOTTOMRIGHT", TR, "BOTTOMLEFT")
        B:SetPoint("TOPLEFT", BL, "TOPRIGHT")
        B:SetPoint("BOTTOMRIGHT", BR, "BOTTOMLEFT")
        L:SetPoint("TOPLEFT", TL, "BOTTOMLEFT")
        L:SetPoint("BOTTOMRIGHT", BL, "TOPRIGHT")
        R:SetPoint("TOPLEFT", TR, "BOTTOMLEFT")
        R:SetPoint("BOTTOMRIGHT", BR, "TOPRIGHT")

        -- Position center
        C:SetPoint("TOPLEFT", TL, "BOTTOMRIGHT")
        C:SetPoint("BOTTOMRIGHT", BR, "TOPLEFT")

        -- Map UVs to the actual border
        TL:SetTexCoord(minX, minX + cx, minY, minY + cy)
        TR:SetTexCoord(maxX - cx, maxX, minY, minY + cy)
        BL:SetTexCoord(minX, minX + cx, maxY - cy, maxY)
        BR:SetTexCoord(maxX - cx, maxX, maxY - cy, maxY)
        
        T:SetTexCoord(minX + cx, maxX - cx, minY, minY + cy)
        B:SetTexCoord(minX + cx, maxX - cx, maxY - cy, maxY)
        L:SetTexCoord(minX, minX + cx, minY + cy, maxY - cy)
        R:SetTexCoord(maxX - cx, maxX, minY + cy, maxY - cy)
        C:SetTexCoord(minX + cx, maxX - cx, minY + cy, maxY - cy)
        
        button.slices = slices
        
        -- Colorize
        for _, t in ipairs(slices) do
            t:SetVertexColor(accentR, accentG, accentB, selectedId == tabInfo.id and 1 or 0.4)
        end

        local label = visual:CreateFontString(nil, "OVERLAY")
        label:SetFont(KT.FONT_PATH, 11, "OUTLINE")
        label:SetText(LText(tabInfo.label))
        label:SetPoint("CENTER", 0, 0)
        
        if selectedId == tabInfo.id then
            label:SetTextColor(1, 1, 1, 1)
        else
            label:SetTextColor(0.7, 0.7, 0.7, 1)
        end

        button:SetScript("OnEnter", function()
            for _, t in ipairs(button.slices) do
                t:SetVertexColor(accentR, accentG, accentB, 1)
            end
            label:SetTextColor(1, 1, 1, 1)
        end)
        
        button:SetScript("OnLeave", function()
            for _, t in ipairs(button.slices) do
                t:SetVertexColor(accentR, accentG, accentB, selectedId == tabInfo.id and 1 or 0.4)
            end
            if selectedId == tabInfo.id then
                label:SetTextColor(1, 1, 1, 1)
            else
                label:SetTextColor(0.7, 0.7, 0.7, 1)
            end
        end)

        button:SetScript("OnClick", function()
            onSelect(tabInfo.id)
        end)
    end
    return frame, 50
end

-- Removed assignment since KT.AddOptionsSubTabBar is now defined distinctly

local function AddSubTabBar(parent, yOffset)
    return AddPageSubTabBar(parent, yOffset, GENERAL_SUBTABS, generalSubTab, function(tabId)
        generalSubTab = tabId
        KT:RefreshPage()
    end)
end

local function AddProfileSpecCard(parent, yOffset, currentProfileName, assignedProfileName)
    local _, specName, specIcon = GetCurrentSpecVisual()

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(parent:GetWidth() - 20, 66)
    frame:SetPoint("TOPLEFT", 10, yOffset)
    KT:AddBackdrop(frame, 0.04, 0.04, 0.06, 0.96)
    KT:AddAccentBorder(frame, 0.42)

    local buttonBg = frame:CreateTexture(nil, "BACKGROUND")
    buttonBg:SetAllPoints()
    buttonBg:SetTexture(PAGE_BUTTON_TEXTURE)
    buttonBg:SetVertexColor(1, 1, 1, 0.32)

    local iconBox = CreateFrame("Frame", nil, frame)
    iconBox:SetSize(44, 44)
    iconBox:SetPoint("LEFT", 10, 0)
    KT:AddBackdrop(iconBox, 0.02, 0.02, 0.03, 1)
    KT:AddAccentBorder(iconBox, 0.75)

    local icon = iconBox:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture(specIcon or 134400)

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT.FONT_PATH, 11, "OUTLINE")
    title:SetPoint("TOPLEFT", iconBox, "TOPRIGHT", 12, -8)
    title:SetText(LText("Current Profile"))
    KT:SetAccentTextColor(title, 1)

    local profileText = frame:CreateFontString(nil, "OVERLAY")
    profileText:SetFont(KT.FONT_PATH, 13, "OUTLINE")
    profileText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    profileText:SetText(currentProfileName or LText("Unknown"))
    profileText:SetTextColor(1, 1, 1, 1)

    local specText = frame:CreateFontString(nil, "OVERLAY")
    specText:SetFont(KT.FONT_PATH, 10, "")
    specText:SetPoint("BOTTOMLEFT", profileText, "BOTTOMLEFT", 0, -14)
    specText:SetText(LTextFmt("Spec: %s", specName or LText("Unknown")))
    specText:SetTextColor(0.76, 0.76, 0.76, 1)

    local assignText = frame:CreateFontString(nil, "OVERLAY")
    assignText:SetFont(KT.FONT_PATH, 10, "")
    assignText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    assignText:SetJustifyH("RIGHT")
    assignText:SetText(LTextFmt("Assigned: %s", assignedProfileName or LText("None")))
    assignText:SetTextColor(assignedProfileName and 1 or 0.62, assignedProfileName and 1 or 0.62, assignedProfileName and 1 or 0.62, 1)

    return frame, 72
end

local PROFILE_MODULE_ICON_MAP = {
    general = "Config",
    skins = "Skins",
    minimap = "Minimap",
    actionbars = "ActionBars",
    unitframes = "UnitFrames",
    partyframes = "PartyFrames",
    cooldownmanager = "KUICooldownManager",
    resourcebars = "ResourceBars",
    buffs = "BuffsAndDebuffs",
    castbar = "CastBar",
    chat = "Chat",
    bags = "Bags",
    tooltip = "Tooltip",
    armory = "Armory",
    inspectarmory = "Inspect",
    dragonriding = "DragonRiding",
    expbar = "ExperienceBar",
    enhancements = "Enhacements",
    damagemeter = "Enhacements",
    mythicplustimer = "Enhacements",
    objectivetracker = "Tracker",
    nameplates = "Nameplates",
    aurareminders = "AuraReminders",
    blizzmove = "UnlockMode",
    cursor = "Cursor",
    teleportmenu = "TeleportMenu",
}

local function CreateProfilesSelectionCard(parent, x, y, width, height, opts)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width, height)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)

    local isSelected = opts.isSelected and opts.isSelected() or false
    KT:AddBackdrop(btn, 0.04, 0.04, 0.06, isSelected and 0.98 or 0.9)
    KT:AddAccentBorder(btn, isSelected and 0.82 or 0.35)

    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(PAGE_BUTTON_TEXTURE)
    bg:SetVertexColor(1, 1, 1, isSelected and 0.24 or 0.12)

    local iconBox = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    iconBox:SetSize(38, 38)
    iconBox:SetPoint("LEFT", btn, "LEFT", 8, 0)
    KT:AddBackdrop(iconBox, 0.02, 0.02, 0.03, 1)
    KT:AddAccentBorder(iconBox, isSelected and 0.82 or 0.4)

    local icon = iconBox:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    if opts.icon then
        icon:SetTexture(opts.icon)
        icon:SetSize(34, 34)
    else
        icon:SetTexture(134400)
        icon:SetSize(34, 34)
    end
    if opts.iconPath then
        icon:SetTexture(opts.iconPath)
        local ir, ig, ib = GetMenuIconVertexColor(opts.iconName or "")
        icon:SetVertexColor(ir, ig, ib, 1)
        local style = ns.PAGE_ICON_STYLE_MAP[opts.iconName and opts.iconName:lower() or ""] or {}
        local baseW = style.width or 60
        local baseH = style.height or 40
        local fitW = math.max(18, iconBox:GetWidth() - 8)
        local fitH = math.max(18, iconBox:GetHeight() - 8)
        local scale = math.min(fitW / baseW, fitH / baseH, 1)
        icon:SetSize(math.floor(baseW * scale + 0.5), math.floor(baseH * scale + 0.5))
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", iconBox, "CENTER", (style.offsetX or 0) * scale, (style.offsetY or 0) * scale)
    end

    local title = btn:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT.FONT_PATH, 11, "OUTLINE")
    title:SetPoint("TOPLEFT", iconBox, "TOPRIGHT", 8, -8)
    title:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -28, -8)
    title:SetJustifyH("LEFT")
    title:SetText(opts.title or "")
    title:SetTextColor(1, 1, 1, 1)

    local subtitle = btn:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(KT.FONT_PATH, 9, "")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -28, -22)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText(opts.subtitle or "")
    subtitle:SetTextColor(0.72, 0.72, 0.72, 1)

    local mark = btn:CreateTexture(nil, "OVERLAY")
    mark:SetSize(14, 14)
    mark:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -8, -8)
    KT:SetAccentTexture(mark, isSelected and 1 or 0.18)

    btn:SetScript("OnEnter", function(self)
        bg:SetVertexColor(1, 1, 1, isSelected and 0.28 or 0.18)
        if GameTooltip and opts.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(opts.tooltip, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function()
        bg:SetVertexColor(1, 1, 1, isSelected and 0.24 or 0.12)
        if GameTooltip then GameTooltip:Hide() end
    end)
    btn:SetScript("OnClick", function()
        if opts.onClick then
            opts.onClick()
        end
    end)

    return btn
end

local function AddProfilesSelectionGrid(parent, startY, entries, opts)
    local cols = opts.columns or 2
    local gap = opts.gap or 8
    local height = opts.cardHeight or 54
    local usableWidth = (parent:GetWidth() or 320) - 20
    local cardWidth = math.floor((usableWidth - ((cols - 1) * gap)) / cols)
    local y = startY

    for index, entry in ipairs(entries) do
        local col = (index - 1) % cols
        local row = math.floor((index - 1) / cols)
        local x = 10 + col * (cardWidth + gap)
        local rowY = y + row * (height + gap)
        CreateProfilesSelectionCard(parent, x, rowY, cardWidth, height, {
            title = opts.getTitle and opts.getTitle(entry) or "",
            subtitle = opts.getSubtitle and opts.getSubtitle(entry) or "",
            tooltip = opts.getTooltip and opts.getTooltip(entry) or nil,
            icon = opts.getIcon and opts.getIcon(entry) or nil,
            iconPath = opts.getIconPath and opts.getIconPath(entry) or nil,
            iconName = opts.getIconName and opts.getIconName(entry) or nil,
            isSelected = function()
                return opts.isSelected and opts.isSelected(entry)
            end,
            onClick = function()
                if opts.onToggle then
                    opts.onToggle(entry, not (opts.isSelected and opts.isSelected(entry)))
                end
            end,
    })
    end

    local rows = math.max(1, math.ceil(#entries / cols))
    return y + rows * height + math.max(0, rows - 1) * gap
end

local COMPATIBILITY_ICON_NAME_BY_RULE = {
    ui_suites = "Installer",
    cooldown_manager = "KUICooldownManager",
    bags = "Bags",
    chat = "Chat",
    unit_frames = "UnitFrames",
    action_bars = "ActionBars",
    cast_bar = "CastBar",
    minimap = "Minimap",
    nameplates = "Nameplates",
}

local function GetCompatibilityIcon(detector, entry, addon)
    if detector and detector.GetAddonIcon then
        local icon = detector:GetAddonIcon(addon.name, entry.rule and entry.rule.id or nil)
        if icon then
            return icon
        end
    end
    local iconName = COMPATIBILITY_ICON_NAME_BY_RULE[entry.rule and entry.rule.id or ""] or "Config"
    return ICON_PATH .. iconName .. ".png", iconName
end

local function GetCompatibilityState(addon, detector)
    local pendingReload = detector and detector.HasPendingReload and detector:HasPendingReload(addon.name)
    if pendingReload then
        return LText("Addon Change - Reload Required"), 1, 0.72, 0.3
    end
    if addon.loaded and addon.enabled then
        return LText("Loaded & Enabled"), 1, 0.35, 0.35
    end
    if addon.loaded then
        return LText("Loaded This Session"), 1, 0.55, 0.25
    end
    if addon.enabled then
        return LText("Enabled"), 1, 0.82, 0.35
    end
    return LText("Disabled"), 0.45, 1, 0.45
end

local function StyleCompatibilityButton(btn, style)
    if style == "reload" then
        KT:AddBackdrop(btn, 0.1, 0.1, 0.1, 1)
        KT:AddBorder(btn, 0.5, 0.5, 0.5, 0.8)
    elseif style == "kui" then
        KT:AddBackdrop(btn, 0.08, 0.08, 0.15, 1)
        KT:AddBorder(btn, 0.25, 0.45, 1, 0.8)
    elseif style == "addon" then
        KT:AddBackdrop(btn, 0.15, 0.03, 0.03, 1)
        KT:AddBorder(btn, 0.8, 0.1, 0.1, 0.8)
    else
        KT:AddBackdrop(btn, 0.06, 0.08, 0.06, 1)
        KT:AddBorder(btn, 0.35, 0.6, 0.35, 0.75)
    end
end

local function AddCompatibilityActionButton(parent, text, point, style, onClick)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(132, 24)
    btn:SetPoint(unpack(point))
    StyleCompatibilityButton(btn, style)
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    btn:SetScript("OnEnter", function(self)
        if self:IsEnabled() and KT.AddBorder then
            KT:AddBorder(self, 1, 1, 1, 0.95)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        StyleCompatibilityButton(self, style)
    end)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(KT.FONT_PATH, 9, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(1, 1, 1, 1)
    return btn
end

local function AddCompatibilityAddonCard(parent, yOffset, width, detector, entry, addon)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, 86)
    frame:SetPoint("TOPLEFT", 0, -yOffset)
    KT:AddBackdrop(frame, 0.04, 0.04, 0.06, 0.96)
    KT:AddAccentBorder(frame, 0.32)

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(PAGE_BUTTON_TEXTURE)
    bg:SetVertexColor(1, 1, 1, 0.1)

    local iconBox = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconBox:SetSize(42, 42)
    iconBox:SetPoint("LEFT", 10, 0)
    KT:AddBackdrop(iconBox, 0.02, 0.02, 0.03, 1)
    KT:AddAccentBorder(iconBox, 0.55)

    local iconTex = iconBox:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("CENTER")
    local icon, iconName = GetCompatibilityIcon(detector, entry, addon)
    if type(icon) == "number" then
        iconTex:SetTexture(icon)
        iconTex:SetSize(34, 34)
    elseif type(icon) == "string" and icon ~= "" then
        iconTex:SetTexture(icon)
        local style = ns.PAGE_ICON_STYLE_MAP[(iconName or ""):lower()] or {}
        local baseW = style.width or 34
        local baseH = style.height or 34
        local fitW = 34
        local fitH = 34
        local scale = math.min(fitW / baseW, fitH / baseH, 1)
        iconTex:SetSize(math.floor(baseW * scale + 0.5), math.floor(baseH * scale + 0.5))
        iconTex:SetPoint("CENTER", (style.offsetX or 0) * scale, (style.offsetY or 0) * scale)
        local ir, ig, ib = GetMenuIconVertexColor(iconName or "")
        iconTex:SetVertexColor(ir, ig, ib, 1)
    else
        iconTex:SetTexture(134400)
        iconTex:SetSize(34, 34)
    end

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT.FONT_PATH, 11, "OUTLINE")
    title:SetPoint("TOPLEFT", iconBox, "TOPRIGHT", 10, -8)
    title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -170, -8)
    title:SetJustifyH("LEFT")
    title:SetText(addon.title or addon.name or LText("Addon"))
    title:SetTextColor(1, 1, 1, 1)

    local stateText, sr, sg, sb = GetCompatibilityState(addon, detector)
    local status = frame:CreateFontString(nil, "OVERLAY")
    status:SetFont(KT.FONT_PATH, 9, "OUTLINE")
    status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -5)
    status:SetText(stateText)
    status:SetTextColor(sr, sg, sb, 1)

    local ruleLabel = frame:CreateFontString(nil, "OVERLAY")
    ruleLabel:SetFont(KT.FONT_PATH, 9, "")
    ruleLabel:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -5)
    ruleLabel:SetPoint("RIGHT", frame, "RIGHT", -170, 0)
    ruleLabel:SetJustifyH("LEFT")
    ruleLabel:SetText(LText(entry.rule and entry.rule.reason or ""))
    ruleLabel:SetTextColor(0.72, 0.72, 0.74, 1)

    local pendingReload = detector and detector.HasPendingReload and detector:HasPendingReload(addon.name)
    local pendingModuleReload = detector and detector.HasPendingModuleReload and detector:HasPendingModuleReload(entry.rule and entry.rule.id)

    if pendingModuleReload then
        AddCompatibilityActionButton(frame, LText("Reload UI"), { "TOPRIGHT", frame, "TOPRIGHT", -10, -14 }, "reload", ReloadUI)
    elseif detector and detector.DisableKUIRule and entry.rule and entry.rule.id and entry.rule.canDisableKUI ~= false then
        AddCompatibilityActionButton(frame, LText("Disable KUI Module"), { "TOPRIGHT", frame, "TOPRIGHT", -10, -14 }, "kui", function()
            local ok, label = detector:DisableKUIRule(entry.rule.id)
            if ok then
                if KT and KT.Print then
                    KT:Print(string.format("%s disabled. Reload UI to apply the change.", label or (entry.rule and entry.rule.title) or "KUI module"))
                end
                if KT and KT.RefreshPage then
                    KT:RefreshPage()
                end
            elseif KT and KT.Print then
                KT:Print("Could not disable the KUI module from the Compatibility panel.")
            end
        end)
    end

    if pendingReload or (addon.loaded and not addon.enabled) then
        AddCompatibilityActionButton(frame, LText("Reload UI"), { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 14 }, "reload", ReloadUI)
    elseif addon.enabled then
        AddCompatibilityActionButton(frame, LText("Disable Addon"), { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 14 }, "addon", function()
            local ok = detector and detector.DisableAddon and detector:DisableAddon(addon.name)
            if ok then
                if KT and KT.Print then
                    KT:Print(string.format("%s disabled. Reload UI to apply the change.", addon.title or addon.name or "Addon"))
                end
                if KT and KT.RefreshPage then
                    KT:RefreshPage()
                end
            elseif KT and KT.Print then
                KT:Print(string.format("Could not disable %s from the Compatibility panel.", addon.title or addon.name or "Addon"))
            end
        end)
    elseif detector and detector.EnableAddonAndDisableKUIRule and entry.rule and entry.rule.id and entry.rule.canDisableKUI ~= false then
        AddCompatibilityActionButton(frame, LText("Use Addon"), { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 14 }, "kui", function()
            local ok, addonEnabled, moduleDisabled, label = detector:EnableAddonAndDisableKUIRule(addon.name, entry.rule.id)
            if ok then
                if KT and KT.Print then
                    KT:Print(string.format("%s enabled and %s disabled. Reload UI to apply both changes.",
                        addon.title or addon.name or "Addon",
                        label or (entry.rule and entry.rule.title) or "KUI module"))
                end
                if KT and KT.RefreshPage then
                    KT:RefreshPage()
                end
            elseif KT and KT.Print then
                if addonEnabled and not moduleDisabled then
                    KT:Print(string.format("%s was enabled, but the KUI module could not be disabled.", addon.title or addon.name or "Addon"))
                elseif moduleDisabled and not addonEnabled then
                    KT:Print(string.format("%s was disabled, but %s could not be enabled.", label or "KUI module", addon.title or addon.name or "Addon"))
                else
                    KT:Print(string.format("Could not enable %s or disable the KUI module from the Compatibility panel.", addon.title or addon.name or "Addon"))
                end
            end
        end)
    else
        local disabledBtn = AddCompatibilityActionButton(frame, LText("Disabled"), { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 14 }, "disabled", nil)
        disabledBtn:Disable()
    end

    return frame, 94
end

local function GetInactiveCompatibilityOptions(report)
    local inactive = {}
    for _, entry in ipairs(report or {}) do
        local addons = {}
        for _, addon in ipairs(entry.addons or {}) do
            if addon and addon.installed and not addon.loaded and not addon.enabled then
                table.insert(addons, addon)
            end
        end
        if #addons > 0 then
            table.insert(inactive, {
                rule = entry.rule,
                addons = addons,
                hasLoaded = false,
        })
        end
    end
    return inactive
end

local function BuildCompatibilityTab(sc, W, y)
    local h = 0
    local detector = GetConflictDetectorModule()
    if not detector then
        _, h = W:SectionHeader(sc, "Compatibility", -y); y = y + h
        _, h = W:Label(sc, "Compatibility detector module not available.", -y, 11, { r = 1, g = 0.35, b = 0.35 }); y = y + h
        return y
    end

    local db = detector.GetDB and detector:GetDB() or nil
    local report = detector:Scan()
    local active = detector:GetActiveConflicts(report)
    local inactive = GetInactiveCompatibilityOptions(report)

    local pendingReloadCount = 0
    if db and db.pendingReload then
        for _, flag in pairs(db.pendingReload) do
            if flag then
                pendingReloadCount = pendingReloadCount + 1
            end
        end
    end
    if db and db.pendingModuleReload then
        for _, flag in pairs(db.pendingModuleReload) do
            if flag then
                pendingReloadCount = pendingReloadCount + 1
            end
        end
    end

    local cols = BeginOptionBlocks(sc, y, { gap = 14, columnGap = 14 })

    AddOptionBlock(cols, "left", LText("Compatibility Detector"), function(container)
        local by = 0
        _, h = W:Label(container, LText("Detect loaded addons that overlap with KullThranUI modules and manage them from one place."), -by, 11); by = by + h
        _, h = W:Toggle(container, LText("Auto Scan on Login"), -by,
            function() return db and db.autoScan ~= false end,
            function(v) if db then db.autoScan = v and true or false end end
        ); by = by + h
        _, h = W:Toggle(container, LText("Show Conflict Popup"), -by,
            function() return db and db.notify ~= false end,
            function(v) if db then db.notify = v and true or false end end
        ); by = by + h
        _, h = W:Toggle(container, LText("Mute Popup Permanently"), -by,
            function() return db and db.dontShowAgain == true end,
            function(v) if db then db.dontShowAgain = v and true or false end end
        ); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", LText("Actions"), function(container)
        local by = 0
        do
            local r, g, b = KT:GetStyleAccentRGB()
            local detectedCount = detector.GetUniqueAddonCount and detector:GetUniqueAddonCount(active, true) or #active
            _, h = W:Label(container, LTextFmt("Detected Addons: %s", tostring(detectedCount)), -by, 11, { r = r, g = g, b = b }); by = by + h
        end
        _, h = W:Label(container, LTextFmt("Pending Reload Changes: %s", tostring(pendingReloadCount)), -by, 11); by = by + h
        _, h = W:Button(container, LText("Rescan Now"), -by, function()
            if KT and KT.RefreshPage then
                KT:RefreshPage()
            end
        end); by = by + h
        _, h = W:Button(container, LText("Reload UI"), -by, ReloadUI); by = by + h
        return by
    end)

    y = EndOptionBlocks(cols) + 6

    _, h = W:SectionHeader(sc, LText("Detected Conflicts"), -y); y = y + h

    if #active == 0 and #inactive == 0 then
        _, h = W:Label(sc, LText("No active incompatible addons detected right now."), -y, 11, { r = 0.45, g = 1, b = 0.45 }); y = y + h
        return y
    end

    for _, entry in ipairs(active) do
        local block, content = CreateOptionBlock(sc, entry.rule and LText(entry.rule.title) or LText("Conflict"), 10, -y, sc:GetWidth() - 22)
        local by = 0
        _, h = W:Label(content, entry.rule and LText(entry.rule.reason) or "", -by, 11); by = by + h
        for _, addon in ipairs(entry.addons or {}) do
            if addon and (addon.loaded or addon.enabled) then
                local _, usedH = AddCompatibilityAddonCard(content, by, content:GetWidth(), detector, entry, addon)
                by = by + usedH
            end
        end
        y = y + FinalizeOptionBlock(block, content, by) + 12
    end

    if #inactive > 0 then
        _, h = W:SectionHeader(sc, "Installed Compatibility Options", -y); y = y + h
        _, h = W:Label(sc, "These installed addons are disabled. Use Addon enables the addon and disables the overlapping KUI module before the same reload.", -y, 11); y = y + h

        for _, entry in ipairs(inactive) do
            local block, content = CreateOptionBlock(sc, entry.rule and entry.rule.title or "Compatibility Option", 10, -y, sc:GetWidth() - 22)
            local by = 0
            _, h = W:Label(content, entry.rule and entry.rule.reason or "", -by, 11); by = by + h
            for _, addon in ipairs(entry.addons or {}) do
                local _, usedH = AddCompatibilityAddonCard(content, by, content:GetWidth(), detector, entry, addon)
                by = by + usedH
            end
            y = y + FinalizeOptionBlock(block, content, by) + 12
        end
    end

    return y
end

local function BuildGeneralCore(sc, W, y)
    local h = 0
    local currentVersion, changelogEntry, latestChangelogEntry, isFallback = GetChangelogDisplayInfo()
    local accentR, accentG, accentB = GetMenuAccentColor()
    local profileName = KT.db and KT.db:GetCurrentProfile() or LText("Unknown")
    local profileMod = GetProfilesModule()
    local assigned = profileMod and profileMod:GetCurrentSpecAssignment() or nil

    -- Strong landing card: this page is the control center of the addon, not a
    -- flat list of unrelated widgets.
    local hero = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    hero:SetPoint("TOPLEFT", 10, -y)
    hero:SetSize(sc:GetWidth() - 20, 104)
    KT:AddBackdrop(hero, 0.025, 0.022, 0.028, 0.98)
    KT:AddBorder(hero, accentR, accentG, accentB, 0.72)

    local heroRail = hero:CreateTexture(nil, "ARTWORK")
    heroRail:SetPoint("TOPLEFT", 1, -1)
    heroRail:SetPoint("BOTTOMLEFT", 1, 1)
    heroRail:SetWidth(5)
    heroRail:SetColorTexture(accentR, accentG, accentB, 1)

    local heroEyebrow = hero:CreateFontString(nil, "OVERLAY")
    heroEyebrow:SetFont(KT.FONT_PATH, 9, "OUTLINE")
    heroEyebrow:SetPoint("TOPLEFT", 22, -15)
    heroEyebrow:SetText(LText("KULLTHRANUI CONFIGURATION"))
    heroEyebrow:SetTextColor(accentR, accentG, accentB, 1)

    local heroTitle = hero:CreateFontString(nil, "OVERLAY")
    heroTitle:SetFont(KT.FONT_PATH, 18, "OUTLINE")
    heroTitle:SetPoint("TOPLEFT", heroEyebrow, "BOTTOMLEFT", 0, -7)
    heroTitle:SetText(LText("Interface Control Center"))
    heroTitle:SetTextColor(1, 1, 1, 1)

    local heroDescription = hero:CreateFontString(nil, "OVERLAY")
    heroDescription:SetFont(KT.FONT_PATH, 10, "")
    heroDescription:SetPoint("TOPLEFT", heroTitle, "BOTTOMLEFT", 0, -7)
    heroDescription:SetPoint("RIGHT", hero, "RIGHT", -22, 0)
    heroDescription:SetJustifyH("LEFT")
    heroDescription:SetText(LText("Configure the foundation of KUI here. Module-specific behavior remains in the sections on the left."))
    heroDescription:SetTextColor(0.72, 0.72, 0.76, 1)

    local heroProfile = hero:CreateFontString(nil, "OVERLAY")
    heroProfile:SetFont(KT.FONT_PATH, 10, "OUTLINE")
    heroProfile:SetPoint("BOTTOMLEFT", 22, 13)
    heroProfile:SetText(LTextFmt("PROFILE  %s", profileName))
    heroProfile:SetTextColor(0.92, 0.92, 0.95, 1)

    local heroVersion = hero:CreateFontString(nil, "OVERLAY")
    heroVersion:SetFont(KT.FONT_PATH, 10, "OUTLINE")
    heroVersion:SetPoint("BOTTOMRIGHT", -18, 13)
    heroVersion:SetText(LTextFmt("VERSION  %s", currentVersion))
    heroVersion:SetTextColor(accentR, accentG, accentB, 1)

    if assigned then
        local heroSpec = hero:CreateFontString(nil, "OVERLAY")
        heroSpec:SetFont(KT.FONT_PATH, 9, "")
        heroSpec:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -18, -16)
        heroSpec:SetText(LTextFmt("SPEC ASSIGNMENT  %s", assigned))
        heroSpec:SetTextColor(0.72, 0.72, 0.76, 1)
    end

    y = y + 118

    local coreCols = BeginOptionBlocks(sc, y, { gap = 14, columnGap = 14 })

    AddOptionBlock(coreCols, "left", "Interface Scale", function(container)
        local by = 0
        _, h = W:Label(container, LText("Match KUI to your display first. This controls the scale used by every module."), -by, 10); by = by + h
        _, h = W:Toggle(container, "Use Blizzard UI Scale", -by,
            function()
                return KT.db.profile.useBlizzardUIScale
            end,
            function(v)
                KT.db.profile.useBlizzardUIScale = v
                if v then
                    KT.db.profile.autoResolutionScale = false
                end
                KT:ApplyUIScale()
            end
        ); by = by + h
        _, h = W:Dropdown(container, "Resolution Preset", -by,
            { ["1080p"] = "1920x1080 (1080p)", ["2K"] = "2560x1440 (2K)", ["4K"] = "3840x2160 (4K)" },
            function()
                local preset = DetectResolutionPresetAndScale()
                return preset
            end,
            function()
                local Installer = KT:GetModule("Installer", true)
                if Installer and Installer.ApplyScaleOnly then
                    Installer:ApplyScaleOnly("AUTO", { silent = true })
                else
                    local _, autoScale = DetectResolutionPresetAndScale()
                    if KT.db.profile.useBlizzardUIScale and KT.SetBlizzardUIScale then
                        KT:SetBlizzardUIScale(autoScale)
                    else
                        KT.db.profile.autoResolutionScale = true
                        KT.db.profile.uiScale = autoScale
                        KT:ApplyUIScale()
                    end
                end
            end
        ); by = by + h
        _, h = W:Slider(container, "Manual UI Scale", -by,
            function()
                local scale
                if KT.db.profile.useBlizzardUIScale and KT.GetBlizzardUIScale then
                    scale = KT:GetBlizzardUIScale()
                else
                    scale = tonumber(KT.db.profile.uiScale)
                end
                if not scale then
                    local _, autoScale = DetectResolutionPresetAndScale()
                    return autoScale
                end
                return scale
            end,
            function(v)
                if KT.db.profile.useBlizzardUIScale and KT.SetBlizzardUIScale then
                    KT:SetBlizzardUIScale(v)
                else
                    KT.db.profile.autoResolutionScale = false
                    KT.db.profile.uiScale = v
                    KT:ApplyUIScale()
                end
            end,
            0.3, 1.5, 0.01
        ); by = by + h
        return by
    end)

    local skin = KT.db.profile.skin
    AddOptionBlock(coreCols, "right", "Appearance & Language", function(container)
        local by = 0
        _, h = W:Label(container, LText("Define the global accent behavior and the language used throughout the configuration."), -by, 10); by = by + h
        _, h = W:Dropdown(container, "Color Theme", -by,
            { ["KULLTHRAN"] = "KullThran (Default)", ["CLASS"] = "Class Color", ["CUSTOM"] = "Custom Color" },
            function() return skin.borderTheme end,
            function(v)
                skin.borderTheme = v
                skin.kullthranUIColorByClass = (v == "CLASS")
                if v ~= "CLASS" then
                    skin.borderThemeBeforeClass = v
                elseif skin.borderThemeBeforeClass == nil then
                    skin.borderThemeBeforeClass = "KULLTHRAN"
                end
                KT.db.profile.castbar = KT.db.profile.castbar or {}
                KT.db.profile.castbar.colorMode = "THEME"
                RefreshSmartStyleLive()
            end
        ); by = by + h
        _, h = W:ColorSwatch(container, "Custom Accent Color", -by,
            function() local color = skin.customBorderColor; return color.r, color.g, color.b, color.a end,
            function(r, g, b, a)
                skin.customBorderColor = { r = r, g = g, b = b, a = a }
                KT.db.profile.castbar = KT.db.profile.castbar or {}
                KT.db.profile.castbar.colorMode = "THEME"
                RefreshSmartStyleLive()
            end,
            true
        ); by = by + h
        _, h = W:Toggle(container, "KullThranUI Class Color", -by,
            function()
                return skin.kullthranUIColorByClass == true or skin.borderTheme == "CLASS"
            end,
            function(v)
                if v then
                    if skin.borderTheme ~= "CLASS" then
                        skin.borderThemeBeforeClass = skin.borderTheme or "KULLTHRAN"
                    end
                    skin.kullthranUIColorByClass = true
                    skin.borderTheme = "CLASS"
                else
                    skin.kullthranUIColorByClass = false
                    local fallbackTheme = skin.borderThemeBeforeClass
                    if fallbackTheme ~= "CUSTOM" and fallbackTheme ~= "KULLTHRAN" then
                        fallbackTheme = "KULLTHRAN"
                    end
                    skin.borderTheme = fallbackTheme or "KULLTHRAN"
                end
                KT.db.profile.castbar = KT.db.profile.castbar or {}
                KT.db.profile.castbar.colorMode = "THEME"
                RefreshSmartStyleLive()
            end
        ); by = by + h
        _, h = W:Dropdown(container, "Language", -by,
            {
                ["auto"] = "Auto (Client)",
                ["enUS"] = "English", ["esES"] = "Spanish", ["frFR"] = "French",
                ["deDE"] = "German", ["itIT"] = "Italian", ["ptBR"] = "Portuguese",
                ["ruRU"] = "Russian", ["koKR"] = "Korean",
                ["zhTW"] = "Traditional Chinese", ["zhCN"] = "Simplified Chinese"
            },
            function() return KT.db.profile.language end,
            function(v) KT.db.profile.language = v; ReloadUI() end,
            { "auto", "enUS", "esES", "frFR", "deDE", "itIT", "ptBR", "ruRU", "koKR", "zhTW", "zhCN" },
            { localeFlags = true }
        ); by = by + h
        return by
    end)

    y = EndOptionBlocks(coreCols) + 4

    local updateBlock, updateContent = CreateOptionBlock(sc, "Updates & Release Notes", 10, -y, sc:GetWidth() - 22)
    local updateY = 0
    _, h = W:Label(updateContent, LTextFmt("Installed Version: %s", currentVersion), -updateY, 11, { r = accentR, g = accentG, b = accentB }); updateY = updateY + h
    if changelogEntry then
        _, h = W:Label(updateContent, LTextFmt("Release notes are available for version %s.", changelogEntry.version), -updateY, 10); updateY = updateY + h
    elseif latestChangelogEntry then
        _, h = W:Label(updateContent, LTextFmt("Latest archived release notes: %s", latestChangelogEntry.version), -updateY, 10); updateY = updateY + h
    end
    if isFallback then
        _, h = W:Label(updateContent, LText("The current release has not been published to the Wago archive yet. CurseForge and Discord sources remain available inside the changelog."), -updateY, 10, { r = 1, g = 0.62, b = 0.32 }); updateY = updateY + h
    end
    _, h = W:Button(updateContent, "Open Changelog", -updateY, function()
        if KT and KT.ShowChangelogPopup then
            KT:ShowChangelogPopup(currentVersion)
        end
    end, "FULL"); updateY = updateY + h
    y = y + FinalizeOptionBlock(updateBlock, updateContent, updateY) + 14
    _, h = W:SectionHeader(sc, "Advanced Style System", -y); y = y + h
    _, h = W:Label(sc, "Build a complete visual preset for KUI or fine tune the palette manually. These settings affect the entire addon.", -y, 11); y = y + h
    local styleCols = BeginOptionBlocks(sc, y, { gap = 14, columnGap = 14 })

    AddOptionBlock(styleCols, "left", "Preset Styles", function(container)
        local by = 0
        _, h = W:Label(container, "Choose a preset to recolor the KullThranUI menu and sync the main profile accent values.", -by, 11); by = by + h

        local presetOrder = {
            "kui_crimson",
            "frost_blue",
            "emerald_night",
            "royal_violet",
            "ember_gold",
            "obsidian_teal",
            "blood_moon",
            "sunforge",
            "arcwine",
            "stormsteel",
            "plague_green",
            "sakura_fall",
        }
        local btnGap = 10
        local btnHeight = 36
        local btnWidth = math.floor((container:GetWidth() - 30 - btnGap) / 2)
        local currentPreset = KT.db.profile.skin and KT.db.profile.skin.stylePreset or "kui_crimson"

        for index, presetKey in ipairs(presetOrder) do
            local preset = STYLE_PRESETS[presetKey]
            local row = math.floor((index - 1) / 2)
            local col = (index - 1) % 2
            local x = 10 + (col * (btnWidth + btnGap))
            local yOff = by + (row * (btnHeight + 8))
            local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
            btn:SetSize(btnWidth, btnHeight)
            btn:SetPoint("TOPLEFT", container, "TOPLEFT", x, -yOff)
            KT:AddBackdrop(btn, preset.background.r, preset.background.g, preset.background.b, 0.96)
            KT:AddBorder(btn, preset.accent.r, preset.accent.g, preset.accent.b, currentPreset == presetKey and 0.95 or 0.45)

            local title = btn:CreateFontString(nil, "OVERLAY")
            title:SetFont(KT.FONT_PATH, 10, "OUTLINE")
            title:SetPoint("CENTER")
            title:SetText(preset.label)
            title:SetTextColor(preset.text.r, preset.text.g, preset.text.b, 1)

            local accentLine = btn:CreateTexture(nil, "ARTWORK")
            accentLine:SetHeight(2)
            accentLine:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 3, 3)
            accentLine:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -3, 3)
            accentLine:SetColorTexture(preset.accent.r, preset.accent.g, preset.accent.b, 1)

            btn:SetScript("OnClick", function()
                ApplySmartStylePreset(presetKey)
            end)
            btn:SetScript("OnEnter", function(self)
                if KT.AddBorder then KT:AddBorder(self, 1, 1, 1, 0.95) end
            end)
            btn:SetScript("OnLeave", function(self)
                local selected = KT.db.profile.skin and KT.db.profile.skin.stylePreset == presetKey
                if KT.AddBorder then
                    KT:AddBorder(self, preset.accent.r, preset.accent.g, preset.accent.b, selected and 0.95 or 0.45)
                end
            end)
        end

        by = by + (math.ceil(#presetOrder / 2) * (btnHeight + 8))
        _, h = W:Label(container, LText("Preset selection also updates accent-driven fields like tracker highlights, chat highlight and castbar color."), -by, 10); by = by + h
        return by
    end)

    AddOptionBlock(styleCols, "right", LText("Manual Colors"), function(container)
        local by = 0
        KT.db.profile.skin = KT.db.profile.skin or {}
        local skin = KT.db.profile.skin
        skin.unlockModeColorMode = skin.unlockModeColorMode or "accent"
        skin.friendListColorMode = skin.friendListColorMode or "accent"
        skin.armoryColorMode = skin.armoryColorMode or "accent"
        skin.bagsColorMode = skin.bagsColorMode or "accent"

        local function ApplyManualStyle()
            skin.stylePreset = "custom"
            SyncSmartStyleDerivedTargets()
            RefreshSmartStyleLive()
        end


        _, h = W:Label(container, LText("Fine tune the smart recolor palette manually if you want a custom style."), -by, 11); by = by + h
        _, h = W:ColorSwatch(container, LText("Accent Color"), -by,
            function() local c = KT_GetActiveAccent(skin); return c.r, c.g, c.b, 1 end,
            function(r, g, b)
                skin.accentColor = MakeStyleColor(r, g, b, 1)
                skin.customBorderColor = MakeStyleColor(r, g, b, 1)
                skin.kullthranUIColorByClass = false
                skin.borderTheme = "CUSTOM"
                skin.borderThemeBeforeClass = "CUSTOM"
                ApplyManualStyle()
            end,
            false
        ); by = by + h
        _, h = W:ColorSwatch(container, LText("Window Background"), -by,
            function() local c = skin.backgroundColor or STYLE_PRESETS.kui_crimson.background; return c.r, c.g, c.b, c.a end,
            function(r, g, b, a) skin.backgroundColor = MakeStyleColor(r, g, b, a); ApplyManualStyle() end,
            true
        ); by = by + h
        _, h = W:ColorSwatch(container, LText("Main Text"), -by,
            function() local c = skin.menuTextColor or STYLE_PRESETS.kui_crimson.text; return c.r, c.g, c.b, 1 end,
            function(r, g, b) skin.menuTextColor = MakeStyleColor(r, g, b, 1); ApplyManualStyle() end,
            false
        ); by = by + h
        _, h = W:ColorSwatch(container, LText("Secondary Text"), -by,
            function() local c = skin.menuSubtextColor or STYLE_PRESETS.kui_crimson.muted; return c.r, c.g, c.b, 1 end,
            function(r, g, b) skin.menuSubtextColor = MakeStyleColor(r, g, b, 1); ApplyManualStyle() end,
            false
        ); by = by + h
        _, h = W:ColorSwatch(container, LText("Background Tint"), -by,
            function() local c = skin.menuBackgroundTint or STYLE_PRESETS.kui_crimson.backgroundTint; return c.r, c.g, c.b, c.a end,
            function(r, g, b, a) skin.menuBackgroundTint = MakeStyleColor(r, g, b, a); ApplyManualStyle() end,
            true
        ); by = by + h
        _, h = W:Dropdown(container, "Unlock Mode Color", -by,
            { accent = "Accent", custom = "Custom" },
            function() return skin.unlockModeColorMode or "accent" end,
            function(v) skin.unlockModeColorMode = v; ApplyManualStyle() end,
            { "accent", "custom" }
        ); by = by + h
        _, h = W:ColorSwatch(container, "Unlock Mode Accent", -by,
            function()
                local mode = skin.unlockModeColorMode or "accent"
                local c = (mode == "accent") and (KT_GetActiveAccent(skin)) or (skin.unlockModeColor or KT_GetActiveAccent(skin))
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                skin.unlockModeColorMode = "custom"
                skin.unlockModeColor = MakeStyleColor(r, g, b, 1)
                ApplyManualStyle()
            end,
            false
        ); by = by + h
        _, h = W:Dropdown(container, "Friend List Color", -by,
            { accent = "Accent", custom = "Custom" },
            function() return skin.friendListColorMode or "accent" end,
            function(v) skin.friendListColorMode = v; ApplyManualStyle() end,
            { "accent", "custom" }
        ); by = by + h
        _, h = W:ColorSwatch(container, "Friend List Accent", -by,
            function()
                local mode = skin.friendListColorMode or "accent"
                local c = (mode == "accent") and (KT_GetActiveAccent(skin)) or (skin.friendListColor or KT_GetActiveAccent(skin))
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                skin.friendListColorMode = "custom"
                skin.friendListColor = MakeStyleColor(r, g, b, 1)
                ApplyManualStyle()
            end,
            false
        ); by = by + h
        _, h = W:Dropdown(container, "Armory Color", -by,
            { accent = "Accent", custom = "Custom" },
            function() return skin.armoryColorMode or "accent" end,
            function(v)
                skin.armoryColorMode = v
                ApplyLegacySkinColorEdit()
            end,
            { "accent", "custom" }
        ); by = by + h
        _, h = W:ColorSwatch(container, "Armory Accent", -by,
            function()
                local mode = skin.armoryColorMode or "accent"
                local c = (mode == "accent") and (KT_GetActiveAccent(skin)) or (skin.armoryColor or KT_GetActiveAccent(skin))
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                skin.armoryColorMode = "custom"
                skin.armoryColor = { r = r, g = g, b = b, a = 1 }
                ApplyLegacySkinColorEdit()
            end,
            false
        ); by = by + h
        _, h = W:Dropdown(container, "Objective Tracker Color", -by,
            { accent = "Accent", custom = "Custom" },
            function() return KT.db.profile.objectiveTracker and KT.db.profile.objectiveTracker.colorMode or "accent" end,
            function(v)
                if KT.db.profile.objectiveTracker then KT.db.profile.objectiveTracker.colorMode = v end
                ApplyLegacySkinColorEdit()
            end,
            { "accent", "custom" }
        ); by = by + h
        _, h = W:ColorSwatch(container, "Objective Tracker Accent", -by,
            function()
                local obj = KT.db.profile.objectiveTracker
                local mode = obj and obj.colorMode or "accent"
                local c = (mode == "accent") and (KT_GetActiveAccent(skin)) or (obj and obj.customColor or KT_GetActiveAccent(skin))
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                local obj = KT.db.profile.objectiveTracker
                if obj then
                    obj.colorMode = "custom"
                    obj.customColor = { r = r, g = g, b = b, a = 1 }
                end
                ApplyLegacySkinColorEdit()
            end,
            false
        ); by = by + h
        _, h = W:Dropdown(container, "Bags Color", -by,
            { accent = "Accent", custom = "Custom" },
            function() return skin.bagsColorMode or "accent" end,
            function(v) skin.bagsColorMode = v; ApplyManualStyle() end,
            { "accent", "custom" }
        ); by = by + h
        _, h = W:ColorSwatch(container, "Bags Accent", -by,
            function()
                local mode = skin.bagsColorMode or "accent"
                local c = (mode == "accent") and (KT_GetActiveAccent(skin)) or (skin.bagsColor or KT_GetActiveAccent(skin))
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                skin.bagsColorMode = "custom"
                skin.bagsColor = MakeStyleColor(r, g, b, 1)
                ApplyManualStyle()
            end,
            false
        ); by = by + h
        _, h = W:Dropdown(container, "Menu Icons", -by,
            { accent = "Accent", white = "White" },
            function() return skin.menuIconColorMode or "accent" end,
            function(v) skin.menuIconColorMode = v; ApplyManualStyle() end,
            { "accent", "white" }
        ); by = by + h
        _, h = W:Label(container, "If some live module keeps the previous palette, use Reload UI after saving the style.", -by, 10); by = by + h
        return by
    end)

    y = EndOptionBlocks(styleCols) + 8

    return y
end

local function BuildProfilesTab(sc, W, y)
    local profileMod = GetProfilesModule()
    local h = 0
    if not profileMod then
        _, h = W:Label(sc, "Profiles module not available.", -y, 11, { r = 1, g = 0.35, b = 0.35 }); y = y + h
        return y
    end

    EnsureProfileState()
    local function RefreshProfilesPage()
        EnsureProfileState()
        if KT.RefreshPage then
            KT:RefreshPage()
        end
    end

    local cols = BeginOptionBlocks(sc, y, { gap = 14, columnGap = 14 })
    local defs = profileMod:GetModuleDefinitions()
    local specEntries = profileMod:GetCDMSpecEntries()
    local assignedProfile = profileMod:GetCurrentSpecAssignment()

    AddOptionBlock(cols, "left", "KUI Profiles", function(container)
        local by = 0
        _, h = AddProfileSpecCard(container, -by, KT.db and KT.db:GetCurrentProfile() or "Unknown", assignedProfile); by = by + h
        _, h = W:Dropdown(container, "Saved Profiles", -by,
            function()
                return select(1, profileMod:GetProfileValues())
            end,
            function()
                EnsureProfileState()
                return profilesSelectionName
            end,
            function(v)
                profilesSelectionName = v
            end
        ); by = by + h
        _, h = W:Input(container, "Save Current As", -by,
            function() return profilesDraftName end,
            function(v) profilesDraftName = v end
        ); by = by + h

        _, h = W:DualRow(container, -by,
            {
                type = "button",
                text = "Load Selected",
                onClick = function()
                    local ok, err = profileMod:SwitchProfile(profilesSelectionName)
                    if not ok and err then
                        KT:Print(err)
                    else
                        profilesSelectionName = KT.db:GetCurrentProfile()
                        profilesDraftName = profilesSelectionName or ""
                        RefreshProfilesPage()
                    end
                end,
        },
            {
                type = "button",
                text = "Delete Selected",
                onClick = function()
                    local ok, err = profileMod:DeleteProfile(profilesSelectionName)
                    if not ok and err then
                        KT:Print(err)
                    else
                        profilesSelectionName = KT.db:GetCurrentProfile()
                        RefreshProfilesPage()
                    end
                end,
        }
        ); by = by + h

        _, h = W:DualRow(container, -by,
            {
                type = "button",
                text = "Save As",
                onClick = function()
                    local ok, err = profileMod:SaveCurrentAsProfile(profilesDraftName)
                    if not ok and err then
                        KT:Print(err)
                    else
                        profilesSelectionName = KT.db:GetCurrentProfile()
                        profilesDraftName = profilesSelectionName or ""
                        RefreshProfilesPage()
                    end
                end,
        },
            {
                type = "button",
                text = "Assign To Spec",
                onClick = function()
                    local target = profilesSelectionName or KT.db:GetCurrentProfile()
                    local ok, err = profileMod:AssignCurrentSpec(target)
                    if not ok and err then
                        KT:Print(err)
                    else
                        profilesSelectionName = target
                        RefreshProfilesPage()
                    end
                end,
        }
        ); by = by + h

        _, h = W:Button(container, "Clear Spec Assign", -by, function()
            local ok, err = profileMod:ClearCurrentSpecAssignment()
            if not ok and err then
                KT:Print(err)
            else
                RefreshProfilesPage()
            end
        end); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "Profile Transfer", function(container)
        local by = 0
        _, h = W:Label(container, "Export or import the full active KullThranUI profile from one place.", -by, 11); by = by + h
        _, h = W:Button(container, "Export Current Profile", -by, function()
            local exportString, err = profileMod:ExportCurrentProfileString()
            if not exportString then
                KT:Print(err)
            else
                profileMod:ShowExportPopup(LText("Export Current Profile"), exportString)
            end
        end, "FULL"); by = by + h
        _, h = W:Button(container, "Import Profile", -by, function()
            profileMod:ShowImportPopup(
                LText("Import Profile"),
                LText("|cffff5555This overwrites the active KullThranUI profile.|r"),
                function(text)
                    local ok, err = profileMod:ImportProfileString(text)
                    if not ok and err then
                        KT:Print(err)
                    else
                        profilesSelectionName = KT.db:GetCurrentProfile()
                        profilesDraftName = profilesSelectionName or ""
                        RefreshProfilesPage()
                    end
                end
            )
        end, "FULL"); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", "Modules Export", function(container)
        local by = 0
        _, h = W:Label(container, "Pick the KUI modules you want to export or merge into the current profile.", -by, 11); by = by + h
        by = AddProfilesSelectionGrid(container, by, defs, {
            columns = 2,
            cardHeight = 52,
            getTitle = function(def)
                return LText(def.label)
            end,
            getSubtitle = function()
                return LText("Module export")
            end,
            getIconPath = function(def)
                local iconName = PROFILE_MODULE_ICON_MAP[def.id] or "Config"
                return ICON_PATH .. iconName .. ".png"
            end,
            getIconName = function(def)
                return PROFILE_MODULE_ICON_MAP[def.id] or "Config"
            end,
            isSelected = function(def)
                return selectedModuleExports[def.id] == true
            end,
            onToggle = function(def, selected)
                selectedModuleExports[def.id] = selected and true or false
                RefreshProfilesPage()
            end,
    })
        _, h = W:DualRow(container, -by,
            {
                type = "button",
                text = "Check All",
                onClick = function()
                    SetAllSelections(selectedModuleExports, defs, true)
                    RefreshProfilesPage()
                end,
        },
            {
                type = "button",
                text = "Uncheck All",
                onClick = function()
                    SetAllSelections(selectedModuleExports, defs, false)
                    RefreshProfilesPage()
                end,
        }
        ); by = by + h
        _, h = W:Button(container, "Load Selected Modules From Saved Profile", -by, function()
            local ok, err = profileMod:ApplyModulesFromProfile(profilesSelectionName, CollectSelectedKeys(selectedModuleExports))
            if not ok and err then
                KT:Print(err)
            else
                RefreshProfilesPage()
            end
        end, "FULL"); by = by + h
        _, h = W:DualRow(container, -by,
            {
                type = "button",
                text = "Export Selected Modules",
                onClick = function()
                    local exportString, err = profileMod:ExportModulesString(CollectSelectedKeys(selectedModuleExports))
                    if not exportString then
                        KT:Print(err)
                    else
                        profileMod:ShowExportPopup(LText("Export Selected Modules"), exportString)
                    end
                end,
        },
            {
                type = "button",
                text = "Import Modules",
                onClick = function()
                    profileMod:ShowImportPopup(
                        LText("Import Module Profile"),
                        LText("|cffff5555This merges the imported modules into the active profile.|r"),
                        function(text)
                            local ok, err = profileMod:ImportProfileString(text)
                            if not ok and err then
                                KT:Print(err)
                            else
                                RefreshProfilesPage()
                            end
                        end
                    )
                end,
        }
        ); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "CDM Spell Profiles", function(container)
        local by = 0
        _, h = W:Label(container, "Each card is a specialization. Export only the specs you actually want to move.", -by, 11); by = by + h
        by = AddProfilesSelectionGrid(container, by, specEntries, {
            columns = 2,
            cardHeight = 52,
            getTitle = function(spec)
                return spec.name
            end,
            getSubtitle = function(spec)
                return spec.hasData and LText("CDM data saved") or LText("No CDM data yet")
            end,
            getIcon = function(spec)
                return spec.icon or 134400
            end,
            isSelected = function(spec)
                return selectedCDMSpecExports[spec.key] == true
            end,
            onToggle = function(spec, selected)
                selectedCDMSpecExports[spec.key] = selected and true or false
                RefreshProfilesPage()
            end,
    })
        _, h = W:DualRow(container, -by,
            {
                type = "button",
                text = "Check All",
                onClick = function()
                    SetAllSelections(selectedCDMSpecExports, specEntries, true)
                    RefreshProfilesPage()
                end,
        },
            {
                type = "button",
                text = "Uncheck All",
                onClick = function()
                    SetAllSelections(selectedCDMSpecExports, specEntries, false)
                    RefreshProfilesPage()
                end,
        }
        ); by = by + h
        _, h = W:DualRow(container, -by,
            {
                type = "button",
                text = "Export CDM Spell Profiles",
                onClick = function()
                    local exportString, err = profileMod:ExportCDMSpellsString(CollectSelectedKeys(selectedCDMSpecExports))
                    if not exportString then
                        KT:Print(err)
                    else
                        profileMod:ShowExportPopup(LText("Export CDM Spell Profiles"), exportString)
                    end
                end,
        },
            {
                type = "button",
                text = "Import CDM Spell Profiles",
                onClick = function()
                    profileMod:ShowImportPopup(
                        LText("Import CDM Spell Profile"),
                        LText("|cffff5555This overwrites imported CDM specs.|r"),
                        function(text)
                            local ok, err = profileMod:ImportCDMSpellsString(text)
                            if not ok and err then
                                KT:Print(err)
                            else
                                RefreshProfilesPage()
                            end
                        end
                    )
                end,
        }
        ); by = by + h
        return by
    end)

    return EndOptionBlocks(cols)
end

local function BuildQuickSetupTab(sc, W, y)
    local h = 0

    _, h = W:SectionHeader(sc, "Quick Setup", -y); y = y + h
    _, h = W:Label(sc, "|cffFF5555Warning:|r These installers overwrite the target profile and reload the UI.", -y, 11); y = y + h

    if ns.ProfileData and ns.Handlers then
        _, h = W:SectionHeader(sc, "Layout Profiles", -y); y = y + h
        for _, res in ipairs({ "1080p", "2K", "4K" }) do
            local preset = res
            _, h = W:Button(sc, LTextFmt("%s Layout", preset), -y, function()
                ns.Handlers.Layout("KullThranUI", ns.ProfileData.Layouts[preset])
                KT:ForceSetProfile("KullThranUI", "KullThranUI")
                ReloadUI()
            end, "FULL", true, LTextFmt("Apply %s layout? UI will reload.", preset)); y = y + h
        end
    end

    _, h = W:SectionHeader(sc, "CDM Presets", -y); y = y + h
    _, h = W:Label(sc, "The per-spec CDM import/export framework is now in Profiles. Additional presets can be added later once the source data is available.", -y, 11); y = y + h
    return y
end

local function BuildFontsColorsTab(sc, W, y)
    local h = 0
    local profile = KT.db.profile
    profile.objectiveTracker = profile.objectiveTracker or {
        enable = true,
        font = profile.globalFont and profile.globalFont.font or KT.DEFAULT_FONT_NAME,
        fontSize = 13,
        fontOutline = "OUTLINE",
        colorMode = "accent",
        customColor = { r = 1, g = 1, b = 1, a = 1 },
    }
    local skin = profile.skin
    local globalFont = profile.globalFont
    local inheritValue = "__KUI_GLOBAL_FONT__"

    local function GetInheritedFontValues()
        local values = GetFontValues()
        values[inheritValue] = "Use Global Font"
        return values
    end

    local function GetFontChoice(db, key, nilMeansGlobal)
        local value = db and db[key]
        local normalizedValue = ResolveRegisteredFontName(value)
        local normalizedGlobal = ResolveRegisteredFontName(globalFont.font)
        if (nilMeansGlobal and not value) or normalizedValue == normalizedGlobal then
            return inheritValue
        end
        return normalizedValue or inheritValue
    end

    local function ResolveChoicePreview(value)
        if value == inheritValue then
            value = globalFont.font
        end
        return ResolveFontPreviewPath(value)
    end

    local function QueueTypographyRefresh()
        local mod = KT:GetModule("GlobalFont", true)
        if mod and mod.QueueConsumerRefresh then
            mod:QueueConsumerRefresh()
        end
    end

    local function AddFontChoice(container, label, by, db, key)
        local _, height = W:Dropdown(container, label, -by,
            GetInheritedFontValues,
            function() return GetFontChoice(db, key, false) end,
            function(value)
                db[key] = value == inheritValue and globalFont.font or value
                QueueTypographyRefresh()
            end,
            nil,
            ResolveChoicePreview
        )
        return by + height
    end
    if skin.menuIconColorMode == nil then
        skin.menuIconColorMode = "accent"
    end
    if skin.unlockModeColorMode == nil then
        skin.unlockModeColorMode = "accent"
    end
    if skin.friendListColorMode == nil then
        skin.friendListColorMode = "accent"
    end
    if skin.armoryColorMode == nil then
        skin.armoryColorMode = "accent"
    end
    if skin.bagsColorMode == nil then
        skin.bagsColorMode = "accent"
    end
    if skin.kullthranUIColorByClass == nil then
        skin.kullthranUIColorByClass = true
    end
    local function ApplyLegacySkinColorEdit()
        skin.stylePreset = "custom"
        SyncSmartStyleDerivedTargets()
        RefreshSmartStyleLive()
    end

    local function QueueVisualRefresh()
        RefreshSmartStyleLive()
        QueueTypographyRefresh()
    end

    local function AddColorChoice(container, label, by, db, key, fallback, hasAlpha, afterSet)
        local _, height = W:ColorSwatch(container, label, -by,
            function()
                local c = (db and db[key]) or fallback or { r = 1, g = 1, b = 1, a = 1 }
                return c.r or 1, c.g or 1, c.b or 1, c.a == nil and 1 or c.a
            end,
            function(r, g, b, a)
                local previous = db[key]
                db[key] = {
                    r = r, g = g, b = b,
                    a = hasAlpha and a or (previous and previous.a) or (fallback and fallback.a) or 1,
                }
                if afterSet then afterSet(db[key]) else QueueVisualRefresh() end
            end,
            hasAlpha and true or false
        )
        return by + height
    end

    _, h = W:Label(sc, LText("Start with the overall theme and font, then fine tune the base palette and area-specific accents only where you want a custom look."), -y, 11); y = y + h

    local cols = BeginOptionBlocks(sc, y, { gap = 14, columnGap = 16 })

    AddOptionBlock(cols, "left", LText("Interface Style"), function(container)
        local by = 0

        _, h = W:Label(container, LText("The launcher can inherit the global font or keep its own face without changing module text."), -by, 11); by = by + h
        _, h = W:Dropdown(container, LText("Launcher & Options Font"), -by,
            GetInheritedFontValues,
            function() return GetFontChoice(globalFont, "interfaceFont", true) end,
            function(value)
                local mod = KT:GetModule("GlobalFont", true)
                if mod and mod.SetInterfaceFont then
                    mod:SetInterfaceFont(value == inheritValue and nil or value)
                end
            end,
            nil,
            ResolveChoicePreview
        ); by = by + h

        by = AddFontChoice(container, LText("Objective Tracker Font"), by, profile.objectiveTracker, "font")
        return by
    end)

    AddOptionBlock(cols, "right", LText("Typography"), function(container)
        local by = 0

        _, h = W:Label(container, LText("This font becomes the default face used across the UI wherever the global font system is applied."), -by, 11); by = by + h
        _, h = W:Dropdown(container, LText("Global Font"), -by,
            GetFontValues,
            function() return ResolveRegisteredFontName(KT.db.profile.globalFont.font) end,
            function(v)
                local mod = KT:GetModule("GlobalFont", true)
                if mod and mod.SetFont then mod:SetFont(v) end
            end,
            nil,
            ResolveFontPreviewPath
        ); by = by + h

        return by
    end)

    AddOptionBlock(cols, "left", LText("HUD Typography"), function(container)
        local by = 0
        _, h = W:Label(container, LText("Override individual HUD areas. Choosing Use Global Font keeps that field linked to future global changes."), -by, 11); by = by + h
        by = AddFontChoice(container, LText("Minimap Zone"), by, profile.minimap, "zoneFont")
        by = AddFontChoice(container, LText("Minimap Statistics"), by, profile.minimap, "statsFont")
        by = AddFontChoice(container, LText("Tooltip"), by, profile.tooltip, "font")
        by = AddFontChoice(container, LText("Cast Bar"), by, profile.castbar, "font")
        by = AddFontChoice(container, LText("Dragon Riding"), by, profile.dragonRiding, "font")
        by = AddFontChoice(container, LText("Experience Bar"), by, profile.experienceBar, "font")
        return by
    end)

    AddOptionBlock(cols, "right", LText("Action & Social Typography"), function(container)
        local by = 0
        by = AddFontChoice(container, LText("Action Bar Count"), by, profile.actionbars, "font")
        by = AddFontChoice(container, LText("Action Bar Hotkeys"), by, profile.actionbars, "hotkeyFont")
        by = AddFontChoice(container, LText("Action Bar Macro Text"), by, profile.actionbars, "macroFont")
        by = AddFontChoice(container, LText("Buff Duration"), by, profile.buffsAndDebuffs, "durationFont")
        by = AddFontChoice(container, LText("Buff Count"), by, profile.buffsAndDebuffs, "countFont")
        by = AddFontChoice(container, LText("Chat"), by, profile.chat, "font")
        return by
    end)

    AddOptionBlock(cols, "left", LText("Character Typography"), function(container)
        local by = 0
        by = AddFontChoice(container, LText("Armory Item Level"), by, profile.armory, "ilvlFont")
        by = AddFontChoice(container, LText("Armory Average Item Level"), by, profile.armory, "avgIlvlFont")
        by = AddFontChoice(container, LText("Armory Character Name"), by, profile.armory, "charNameFont")
        by = AddFontChoice(container, LText("Armory Character Level"), by, profile.armory, "charLevelFont")
        by = AddFontChoice(container, LText("Armory Headers"), by, profile.armory, "headerFont")
        by = AddFontChoice(container, LText("Armory Score"), by, profile.armory, "scoreFont")
        by = AddFontChoice(container, LText("Armory Enchants"), by, profile.armory, "enchantFont")
        by = AddFontChoice(container, LText("Armory Statistics"), by, profile.armory, "statFont")
        return by
    end)

    AddOptionBlock(cols, "right", LText("Inspect Typography"), function(container)
        local by = 0
        by = AddFontChoice(container, LText("Inspect Item Level"), by, profile.inspectArmory, "ilvlFont")
        by = AddFontChoice(container, LText("Average Item Level"), by, profile.inspectArmory, "avgIlvlFont")
        by = AddFontChoice(container, LText("Average Item Level Label"), by, profile.inspectArmory, "avgIlvlLabelFont")
        by = AddFontChoice(container, LText("Inspect Enchants"), by, profile.inspectArmory, "enchantFont")
        by = AddFontChoice(container, LText("Inspect Statistics"), by, profile.inspectArmory, "statFont")
        return by
    end)

    AddOptionBlock(cols, "left", LText("Accent Targets"), function(container)
        local by = 0

        _, h = W:Label(container, LText("These controls let specific parts of the UI inherit the main accent or use a dedicated custom color."), -by, 11); by = by + h
        _, h = W:Dropdown(container, LText("Unlock Mode Color"), -by,
            { accent = "Accent", custom = "Custom" },
            function() return skin.unlockModeColorMode or "accent" end,
            function(v)
                skin.unlockModeColorMode = v
                ApplyLegacySkinColorEdit()
            end,
            { "accent", "custom" }
        ); by = by + h
        _, h = W:ColorSwatch(container, "Unlock Mode Accent", -by,
            function()
                local mode = skin.unlockModeColorMode or "accent"
                local c = (mode == "accent") and (KT_GetActiveAccent(skin)) or (skin.unlockModeColor or KT_GetActiveAccent(skin))
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                skin.unlockModeColorMode = "custom"
                skin.unlockModeColor = { r = r, g = g, b = b, a = 1 }
                ApplyLegacySkinColorEdit()
            end,
            false
        ); by = by + h
        _, h = W:Dropdown(container, "Friend List Color", -by,
            { accent = "Accent", custom = "Custom" },
            function() return skin.friendListColorMode or "accent" end,
            function(v)
                skin.friendListColorMode = v
                ApplyLegacySkinColorEdit()
            end,
            { "accent", "custom" }
        ); by = by + h
        _, h = W:ColorSwatch(container, "Friend List Accent", -by,
            function()
                local mode = skin.friendListColorMode or "accent"
                local c = (mode == "accent") and (KT_GetActiveAccent(skin)) or (skin.friendListColor or KT_GetActiveAccent(skin))
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                skin.friendListColorMode = "custom"
                skin.friendListColor = { r = r, g = g, b = b, a = 1 }
                ApplyLegacySkinColorEdit()
            end,
            false
        ); by = by + h
        _, h = W:Dropdown(container, "Armory Color", -by,
            { accent = "Accent", custom = "Custom" },
            function() return skin.armoryColorMode or "accent" end,
            function(v)
                skin.armoryColorMode = v
                ApplyLegacySkinColorEdit()
            end,
            { "accent", "custom" }
        ); by = by + h
        _, h = W:ColorSwatch(container, "Armory Accent", -by,
            function()
                local mode = skin.armoryColorMode or "accent"
                local c = (mode == "accent") and (KT_GetActiveAccent(skin)) or (skin.armoryColor or KT_GetActiveAccent(skin))
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                skin.armoryColorMode = "custom"
                skin.armoryColor = { r = r, g = g, b = b, a = 1 }
                ApplyLegacySkinColorEdit()
            end,
            false
        ); by = by + h
        _, h = W:Dropdown(container, "Bags Color", -by,
            { accent = "Accent", custom = "Custom" },
            function() return skin.bagsColorMode or "accent" end,
            function(v)
                skin.bagsColorMode = v
                ApplyLegacySkinColorEdit()
            end,
            { "accent", "custom" }
        ); by = by + h
        _, h = W:ColorSwatch(container, "Bags Accent", -by,
            function()
                local mode = skin.bagsColorMode or "accent"
                local c = (mode == "accent") and (KT_GetActiveAccent(skin)) or (skin.bagsColor or KT_GetActiveAccent(skin))
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                skin.bagsColorMode = "custom"
                skin.bagsColor = { r = r, g = g, b = b, a = 1 }
                ApplyLegacySkinColorEdit()
            end,
            false
        ); by = by + h

        _, h = W:Dropdown(container, "Objective Tracker Color", -by,
            { accent = "Accent", custom = "Custom" },
            function() return profile.objectiveTracker.colorMode or "accent" end,
            function(v)
                profile.objectiveTracker.colorMode = v
                ApplyLegacySkinColorEdit()
                QueueTypographyRefresh()
            end,
            { "accent", "custom" }
        ); by = by + h
        _, h = W:ColorSwatch(container, "Objective Tracker Accent", -by,
            function()
                local obj = profile.objectiveTracker
                local c = obj.colorMode == "custom" and obj.customColor or KT_GetActiveAccent(skin)
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                profile.objectiveTracker.colorMode = "custom"
                profile.objectiveTracker.customColor = { r = r, g = g, b = b, a = 1 }
                ApplyLegacySkinColorEdit()
                QueueTypographyRefresh()
            end,
            false
        ); by = by + h

        return by
    end)

    AddOptionBlock(cols, "right", "Core Palette", function(container)
        local by = 0

        _, h = W:Label(container, "These are the three base colors that define the skin: window fill, border and the main accent used by the rest of the interface.", -by, 11); by = by + h
        _, h = W:ColorSwatch(container, "Window Background", -by,
            function()
                local palette = GetOptionsStylePalette()
                local c = palette.background or skin.backgroundColor
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a)
                skin.backgroundColor = { r = r, g = g, b = b, a = a }
                ApplyLegacySkinColorEdit()
            end,
            true
        ); by = by + h
        _, h = W:ColorSwatch(container, "Window Border", -by,
            function()
                local palette = GetOptionsStylePalette()
                local c = palette.border or skin.borderColor
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a)
                skin.borderColor = { r = r, g = g, b = b, a = a }
                ApplyLegacySkinColorEdit()
            end,
            true
        ); by = by + h
        _, h = W:ColorSwatch(container, "Accent Color", -by,
            function()
                local c = KT_GetActiveAccent(skin)
                return c.r, c.g, c.b, 1
            end,
            function(r, g, b)
                skin.accentColor = { r = r, g = g, b = b, a = 1 }
                skin.customBorderColor = { r = r, g = g, b = b, a = 1 }
                skin.kullthranUIColorByClass = false
                skin.borderTheme = "CUSTOM"
                skin.borderThemeBeforeClass = "CUSTOM"
                ApplyLegacySkinColorEdit()
            end,
            false
        ); by = by + h

        return by
    end)

    AddOptionBlock(cols, "left", "Interface Text & Tint", function(container)
        local by = 0
        by = AddColorChoice(container, "Header Surface", by, skin, "headerColor", { r = 0.1, g = 0.1, b = 0.1, a = 1 }, true, ApplyLegacySkinColorEdit)
        by = AddColorChoice(container, "Main Text", by, skin, "menuTextColor", { r = 0.98, g = 0.94, b = 0.96, a = 1 }, false, ApplyLegacySkinColorEdit)
        by = AddColorChoice(container, "Secondary Text", by, skin, "menuSubtextColor", { r = 0.74, g = 0.74, b = 0.78, a = 1 }, false, ApplyLegacySkinColorEdit)
        by = AddColorChoice(container, "Background Tint", by, skin, "menuBackgroundTint", { r = 1, g = 0.18, b = 0.39, a = 0.16 }, true, ApplyLegacySkinColorEdit)
        by = AddColorChoice(container, "Minimap Border", by, profile.minimap, "borderColor", { r = 0, g = 0, b = 0, a = 1 }, true)
        by = AddColorChoice(container, "Tooltip Text", by, profile.tooltip, "textColor", { r = 1, g = 1, b = 1, a = 1 }, true)
        by = AddColorChoice(container, "Bags Panel", by, profile.bags, "panelColor", { r = 0.05, g = 0.07, b = 0.09, a = 0.94 }, true)
        return by
    end)

    AddOptionBlock(cols, "right", "Action & Cast Colors", function(container)
        local by = 0
        by = AddColorChoice(container, "Action Button Background", by, profile.actionbars, "buttonBackdropColor", { r = 0.1, g = 0.1, b = 0.1, a = 0.73 }, true)
        by = AddColorChoice(container, "Action Count Text", by, profile.actionbars, "fontColor", { r = 1, g = 1, b = 1, a = 1 }, true)
        by = AddColorChoice(container, "Action Hotkey Text", by, profile.actionbars, "hotkeyFontColor", { r = 1, g = 1, b = 1, a = 1 }, true)
        by = AddColorChoice(container, "Action Macro Text", by, profile.actionbars, "macroFontColor", { r = 1, g = 1, b = 1, a = 1 }, true)
        by = AddColorChoice(container, "Cast Bar Fill", by, profile.castbar, "color", { r = 1, g = 0, b = 0.33, a = 1 }, true,
            function()
                profile.castbar.colorMode = "CUSTOM"
                profile.castbar.classColor = false
                QueueVisualRefresh()
            end)
        by = AddColorChoice(container, "Cast Bar Text", by, profile.castbar, "textColor", { r = 1, g = 1, b = 1, a = 1 }, true)
        return by
    end)

    AddOptionBlock(cols, "left", "Progress & Social Colors", function(container)
        local by = 0
        by = AddColorChoice(container, "Experience", by, profile.experienceBar, "xpColor", { r = 0.33, g = 0.38, b = 1, a = 1 }, true)
        by = AddColorChoice(container, "Honor", by, profile.experienceBar, "honorColor", { r = 1, g = 0.2, b = 0.2, a = 1 }, true)
        by = AddColorChoice(container, "Reputation", by, profile.experienceBar, "repColor", { r = 0, g = 0.8, b = 0, a = 1 }, true)
        by = AddColorChoice(container, "Rested Experience", by, profile.experienceBar, "restedColor", { r = 1, g = 0.2, b = 1, a = 0.5 }, true)
        by = AddColorChoice(container, "Chat Panel", by, profile.chat, "panelColor", { r = 0.05, g = 0.07, b = 0.09, a = 0.1 }, true)
        by = AddColorChoice(container, "Chat Highlight", by, profile.chat, "highlightColor", { r = 1, g = 0.18, b = 0.39, a = 1 }, false)
        return by
    end)

    AddOptionBlock(cols, "right", "Character Colors", function(container)
        local by = 0
        local armory = profile.armory
        by = AddColorChoice(container, "Item Slot Level", by, armory, "ilvlColor", { r = 1, g = 1, b = 1, a = 1 }, true)
        by = AddColorChoice(container, "Average Item Level", by, armory, "avgIlvlColor", { r = 0.76, g = 0, b = 1, a = 1 }, true)
        by = AddColorChoice(container, "Enchants", by, armory, "enchantColor", { r = 0, g = 1, b = 0.62, a = 1 }, true)
        by = AddColorChoice(container, "Attribute Header", by, armory, "attrHeaderColor", { r = 0.94, g = 0.78, b = 0.29, a = 1 }, true)
        by = AddColorChoice(container, "Secondary Header", by, armory, "enhHeaderColor", { r = 0.94, g = 0.78, b = 0.29, a = 1 }, true)
        by = AddColorChoice(container, "All Primary Stats", by, armory, "attrColor", { r = 1, g = 0.48, b = 0, a = 1 }, true,
            function(c)
                for _, key in ipairs({ "strengthColor", "agilityColor", "intellectColor", "staminaColor", "armorColor" }) do
                    armory[key] = { r = c.r, g = c.g, b = c.b, a = c.a }
                end
                QueueVisualRefresh()
            end)
        by = AddColorChoice(container, "All Secondary Stats", by, armory, "enhColor", { r = 0.2, g = 0.66, b = 0.9, a = 1 }, true,
            function(c)
                for _, key in ipairs({ "critColor", "hasteColor", "masteryColor", "versatilityColor", "leechColor", "avoidanceColor", "speedColor", "dodgeColor", "parryColor", "blockColor" }) do
                    armory[key] = { r = c.r, g = c.g, b = c.b, a = c.a }
                end
                QueueVisualRefresh()
            end)
        by = AddColorChoice(container, "Stat Separator", by, armory, "separatorColor", { r = 1, g = 0.18, b = 0.39, a = 1 }, true)
        return by
    end)

    AddOptionBlock(cols, "left", "Inspect Colors", function(container)
        local by = 0
        local inspect = profile.inspectArmory
        by = AddColorChoice(container, "Item Slot Level", by, inspect, "ilvlColor", { r = 1, g = 1, b = 1, a = 1 }, true)
        by = AddColorChoice(container, "Average Item Level", by, inspect, "avgIlvlColor", { r = 1, g = 0.82, b = 0, a = 1 }, true)
        by = AddColorChoice(container, "Average Level Label", by, inspect, "avgIlvlLabelColor", { r = 1, g = 1, b = 1, a = 1 }, true)
        by = AddColorChoice(container, "Enchants", by, inspect, "enchantColor", { r = 0, g = 1, b = 0, a = 1 }, true)
        by = AddColorChoice(container, "Primary Statistics", by, inspect, "attrColor", { r = 1, g = 0.82, b = 0, a = 1 }, true)
        by = AddColorChoice(container, "Secondary Statistics", by, inspect, "enhColor", { r = 0, g = 1, b = 0, a = 1 }, true)
        return by
    end)

    AddOptionBlock(cols, "right", "Options Menu", function(container)
        local by = 0

        _, h = W:Label(container, "Controls how the sidebar icons are tinted in the configuration menu.", -by, 11); by = by + h
        _, h = W:Dropdown(container, "Sidebar Icon Color", -by,
            { white = "White", accent = "KullThranUI" },
            function() return skin.menuIconColorMode or "accent" end,
            function(v)
                skin.menuIconColorMode = v
                skin.stylePreset = "custom"
                SyncSmartStyleDerivedTargets()
                RefreshMenuNavIcons()
                RefreshSmartStyleLive()
            end,
            { "white", "accent" }
        ); by = by + h
        _, h = W:Label(container, "Multicolor icons keep their original colors so the built-in backgrounds and small details do not break.", -by, 10); by = by + h

        return by
    end)

    local bottom = EndOptionBlocks(cols)
    return KT.BuildExtendedFontsColors and KT:BuildExtendedFontsColors(sc, W, bottom + 14) or bottom
end

local function BuildDisableModulesTab(sc, W, y)
    local h = 0
    KT.db.profile.minimap = KT.db.profile.minimap or { enable = true }
    KT.db.profile.actionbars = KT.db.profile.actionbars or { enable = true }
    KT.db.profile.buffsAndDebuffs = KT.db.profile.buffsAndDebuffs or { enable = true }
    KT.db.profile.castbar = KT.db.profile.castbar or { enable = true }
    KT.db.profile.tooltip = KT.db.profile.tooltip or { enable = true }
    KT.db.profile.armory = KT.db.profile.armory or { enable = true }
    KT.db.profile.dragonRiding = KT.db.profile.dragonRiding or { enable = true }
    KT.db.profile.experienceBar = KT.db.profile.experienceBar or { enable = true }
    KT.db.profile.chat = KT.db.profile.chat or { enable = true }
    KT.db.profile.bags = KT.db.profile.bags or { enable = true }
    KT.db.profile.objectiveTracker = KT.db.profile.objectiveTracker or { enable = true }
    KT.db.profile.enhancements = KT.db.profile.enhancements or { enable = true }
    KT.db.profile.externalAddons = KT.db.profile.externalAddons or { enable = true }
    KT.db.profile.enhancements.damageMeter = KT.db.profile.enhancements.damageMeter or { moduleEnabled = true }
    KT.db.profile.enhancements.mplusTracker = KT.db.profile.enhancements.mplusTracker or { enabled = true }
    if KT.db.profile.enhancements.mplusTracker.enabled == nil then KT.db.profile.enhancements.mplusTracker.enabled = true end
    KT.db.profile.unitFrames = KT.db.profile.unitFrames or { enable = true }
    KT.db.profile.partyFrames = KT.db.profile.partyFrames or { enable = true }
    KT.db.profile.cursor = KT.db.profile.cursor or { enable = true }
    KT.db.profile.teleportMenu = KT.db.profile.teleportMenu or { enable = true }
    KT.db.profile.inspectArmory = KT.db.profile.inspectArmory or { enable = true }
    KT.db.profile.cooldownManager = KT.db.profile.cooldownManager or { cdmBars = { enabled = true } }
    KT.db.profile.cooldownManager.cdmBars = KT.db.profile.cooldownManager.cdmBars or { enabled = true }
    KT.db.profile.resourceBars = KT.db.profile.resourceBars or {
        health = { enabled = false },
        primary = { enabled = true, hideMana = false },
        secondary = { enabled = true },
}

    local toggles = {
        { label = "Skins", get = function() return KT.db.profile.skin.enable end, set = function(v) KT.db.profile.skin.enable = v; Reload() end },
        { label = "Minimap", get = function() return KT.db.profile.minimap.enable end, set = function(v) KT.db.profile.minimap.enable = v; Reload() end },
        { label = "Action Bars", get = function() return KT.db.profile.actionbars.enable end, set = function(v) KT.db.profile.actionbars.enable = v; Reload() end },
        { label = "Buffs & Debuffs", get = function() return KT.db.profile.buffsAndDebuffs.enable end, set = function(v) KT.db.profile.buffsAndDebuffs.enable = v; Reload() end },
        { label = "Cast Bar", get = function() return KT.db.profile.castbar.enable end, set = function(v) KT.db.profile.castbar.enable = v; Reload() end },
        { label = "Tooltip", get = function() return KT.db.profile.tooltip.enable end, set = function(v) KT.db.profile.tooltip.enable = v; Reload() end },
        { label = "Armory", get = function() return KT.db.profile.armory.enable end, set = function(v) KT.db.profile.armory.enable = v; Reload() end },
        { label = "Dragon Riding", get = function() return KT.db.profile.dragonRiding.enable end, set = function(v) KT.db.profile.dragonRiding.enable = v; Reload() end },
        { label = "Experience Bar", get = function() return KT.db.profile.experienceBar.enable end, set = function(v) KT.db.profile.experienceBar.enable = v; Reload() end },
        { label = "Chat", get = function() return KT.db.profile.chat.enable end, set = function(v) KT.db.profile.chat.enable = v; Reload() end },
        { label = "Bags", get = function() return KT.db.profile.bags.enable end, set = function(v) KT.db.profile.bags.enable = v; Reload() end },
        { label = "Objective Tracker", get = function() return KT.db.profile.objectiveTracker.enable ~= false end, set = function(v) KT.db.profile.objectiveTracker.enable = v; Reload() end },
        { label = LText("Enhancements"), get = function() return KT.db.profile.enhancements.enable ~= false end, set = function(v) KT.db.profile.enhancements.enable = v; Reload() end },
        { label = "   - " .. LText("Damage Meter"), get = function() return KT.db.profile.enhancements.damageMeter.moduleEnabled ~= false end, set = function(v) KT.db.profile.enhancements.damageMeter.moduleEnabled = v and true or false; Reload() end },
        { label = "   - " .. LText("Mythic+ Timer"), get = function() return KT.db.profile.enhancements.mplusTracker.enabled ~= false end, set = function(v) KT.db.profile.enhancements.mplusTracker.enabled = v and true or false; Reload() end },
        { label = "External Addons", get = function() return KT.db.profile.externalAddons.enable ~= false end, set = function(v) KT.db.profile.externalAddons.enable = v; Reload() end },
        { label = "Unit Frames", get = function() return KT.db.profile.unitFrames.enable ~= false end, set = function(v) KT.db.profile.unitFrames.enable = v; Reload() end },
        { label = "Party Frames", get = function() return KT.db.profile.partyFrames.enable ~= false end, set = function(v) KT.db.profile.partyFrames.enable = v; Reload() end },
        { label = "Cursor", get = function() return KT.db.profile.cursor.enable ~= false end, set = function(v) KT.db.profile.cursor.enable = v; Reload() end },
        { label = "Teleport Menu", get = function() return KT.db.profile.teleportMenu.enable ~= false end, set = function(v) KT.db.profile.teleportMenu.enable = v; Reload() end },
        { label = "Inspect Armory", get = function() return KT.db.profile.inspectArmory.enable ~= false end, set = function(v) KT.db.profile.inspectArmory.enable = v; Reload() end },
        { label = "Aura Reminders", get = function() local db = _G._KUIAR_AceDB; local p = db and db.profile; return p == nil or p.enable ~= false end, set = function(v) local db = _G._KUIAR_AceDB; if db and db.profile then db.profile.enable = v and true or false end; Reload() end },
        { label = "Nameplates", get = function() return not (_G.KullThranUINameplatesDB and _G.KullThranUINameplatesDB.enable == false) end, set = function(v) _G.KullThranUINameplatesDB = _G.KullThranUINameplatesDB or {}; _G.KullThranUINameplatesDB.enable = v and true or false; Reload() end },
        { label = "Cooldown Manager", get = function() return KT.db.profile.cooldownManager.cdmBars.enabled end, set = function(v) KT.db.profile.cooldownManager.cdmBars.enabled = v; Reload() end },
        { label = "Resource Bars", get = function() return (KT.db.profile.resourceBars.primary.enabled or KT.db.profile.resourceBars.secondary.enabled or KT.db.profile.resourceBars.health.enabled) and true or false end, set = function(v) KT.db.profile.resourceBars.primary.enabled = v; KT.db.profile.resourceBars.secondary.enabled = v; KT.db.profile.resourceBars.health.enabled = v; Reload() end },
}

    _, h = W:SectionHeader(sc, "Disable Modules", -y); y = y + h
    _, h = W:Label(sc, "These toggles map to the module's master enable flag when the module supports one. A reload is recommended after changes.", -y, 11); y = y + h

    for index = 1, #toggles, 2 do
        local left = toggles[index]
        local right = toggles[index + 1]
        _, h = W:DualRow(sc, -y,
            {
                type = "toggle",
                text = left.label,
                getValue = left.get,
                setValue = left.set,
        },
            right and {
                type = "toggle",
                text = right.label,
                getValue = right.get,
                setValue = right.set,
        } or nil
        ); y = y + h
    end

    return y
end

RegisterPage("general", "General", 10, function(sc, W)
    local y, h = 0, 0

    EnsureProfileState()
    _, h = AddSubTabBar(sc, -y); y = y + h

    if generalSubTab == "general" then
        y = BuildGeneralCore(sc, W, y)
    elseif generalSubTab == "compatibility" then
        y = BuildCompatibilityTab(sc, W, y)
    elseif generalSubTab == "profiles" then
        y = BuildProfilesTab(sc, W, y)
    elseif generalSubTab == "quicksetup" then
        y = BuildQuickSetupTab(sc, W, y)
    elseif generalSubTab == "fontscolors" then
        y = BuildFontsColorsTab(sc, W, y)
    elseif generalSubTab == "disablemodules" then
        y = BuildDisableModulesTab(sc, W, y)
    end

    return y
end)

-- External page stubs (so they appear in the menu even if a module is disabled/missing).
-- NOTE: Installer is no longer LoadOnDemand; it should be loaded automatically at login.
if KT and KT.RegisterPage then
    KT:RegisterPage("installer", "Installer", 95, function(sc, W)
        local y, h = 0, 0
        _, h = W:SectionHeader(sc, "Installer", -y); y = y + h

        local addonName = "KullThranUI_Installer"
        local isLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(addonName))
            or (IsAddOnLoaded and IsAddOnLoaded(addonName))

        if isLoaded then
            _, h = W:Label(sc, "Module loaded. Refreshing page...", -y, 11); y = y + h
            C_Timer.After(0, function()
                if KT and KT.RefreshPage then
                    KT:RefreshPage()
                end
            end)
            return y
        end

        _, h = W:Label(sc, "The Installer module is not loaded. Enable KullThranUI_Installer in the AddOns list and reload the UI.", -y, 11); y = y + h
        _, h = W:Label(sc, "If the page does not appear, verify that KullThranUI_Installer is enabled.", -y, 11); y = y + h
        return y
    end)
end
