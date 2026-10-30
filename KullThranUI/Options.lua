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
    if KT.Widgets and KT.Widgets.DecorateScrollBar then
        KT.Widgets:DecorateScrollBar(scrollBar, accent.r or 1, accent.g or 0, accent.b or 0.3333333333)
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
    -- Sidebar entries paint their icon with their state (ns.PaintMenuNavIcon).
    local function Refresh(btn)
        if btn.UpdateVisual then btn:UpdateVisual() else ApplyMenuNavButtonIconStyle(btn) end
    end
    if type(ns.navButtons) == "table" then
        for _, btn in pairs(ns.navButtons) do Refresh(btn) end
    end
    if type(ns.categoryButtons) == "table" then
        for _, btn in pairs(ns.categoryButtons) do Refresh(btn) end
    end
    if KT and KT.MenuPrincipal and KT.MenuPrincipal._ktUnlockShortcut then
        Refresh(KT.MenuPrincipal._ktUnlockShortcut)
    end
end

-- ============================================================================
-- GENERAL: UnlockMode shortcut button (header action)
-- ============================================================================
local UNLOCKMODE_BUTTON_HEIGHT = 50
local UNLOCKMODE_ICON_NAME = "UnlockMode"
local NAV_SCROLL_TOP_GAP = 12
local NAV_SCROLL_BOTTOM_GAP = 18
local NAV_CONTENT_TOP_PADDING = 4

-- Sidebar icons: the accent while the entry is active, muted at rest; icons
-- drawn in their own colours keep them (dimmed at rest).
ns.PaintMenuNavIcon = function(btn, active, hovered)
    if not (btn and btn.ico) then return end
    if ns.MENU_ICON_PRESERVE_COLOR[btn._iconName or ""] then
        btn.ico:SetVertexColor(1, 1, 1, (active or hovered) and 1 or 0.7)
    elseif active then
        local r, g, b = GetMenuAccentColor()
        btn.ico:SetVertexColor(r, g, b, 1)
    elseif hovered then
        local _, _, _, text = GetMenuPaletteColors()
        btn.ico:SetVertexColor(text.r or 1, text.g or 1, text.b or 1, 1)
    else
        local _, _, _, _, muted = GetMenuPaletteColors()
        btn.ico:SetVertexColor(muted.r or 0.74, muted.g or 0.74, muted.b or 0.78, 0.9)
    end
end

local function EnsureUnlockModeShortcut(menu)
    if not menu then return end
    if menu._ktUnlockShortcut then
        return menu._ktUnlockShortcut
    end

    local parent = menu._navHost or menu
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(UNLOCKMODE_BUTTON_HEIGHT)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -10)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -10)
    btn:SetFrameLevel((menu and menu.GetFrameLevel and menu:GetFrameLevel() or 0) + 50)

    -- A rounded pill that always shows; open Unlock Mode lights it like an
    -- active sidebar entry.
    KT.Widgets:NavChip(btn, { radius = 6, barHeight = 24, card = "shine", chip = { w = 42, h = 34, x = 8, radius = 9 } })

    local ico = btn:CreateTexture(nil, "OVERLAY")
    ico:SetSize(42, 28)
    ico:SetPoint("CENTER", btn._chipKT.box, "CENTER", 0, 0)
    ico:SetTexture(ICON_PATH .. UNLOCKMODE_ICON_NAME .. ".png")
    btn._iconName = UNLOCKMODE_ICON_NAME
    btn.ico = ico

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(KT.FONT_PATH, 14, "")
    label:SetPoint("LEFT", btn._chipKT.box, "RIGHT", 12, 0)
    label:SetPoint("RIGHT", btn, "RIGHT", -12, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetText(LocalizeText("KUI Unlock Mode"))
    btn.label = label

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
        local isHovered = btn.IsMouseOver and btn:IsShown() and btn:IsMouseOver()
        -- The shine row paints the label and icon in accent tints.
        btn._navLabelKT, btn._navIconKT = label, btn.ico
        btn._navIconKeep = ns.MENU_ICON_PRESERVE_COLOR[btn._iconName or ""]
        if btn._navIconKeep then ns.PaintMenuNavIcon(btn, isOpen, isHovered) end
        KT.Widgets:NavChipState(btn, isOpen and "active" or "rest", isHovered)
    end

    btn:SetScript("OnEnter", function(self)
        UpdateVisual()
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(LocalizeText("KUI Unlock Mode"), 1, 1, 1)
            GameTooltip:AddLine(LocalizeText("Click to toggle KullThranUI Unlock Mode."), 0.75, 0.75, 0.75, true)
            GameTooltip:Show()
        end
    end)
    btn:SetScript("OnLeave", function(self)
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
local CHANGELOG_LATEST_ARCHIVED_VERSION = "6.0.2"
-- AUTO-CHANGELOG-LATEST:END
-- AUTO-CHANGELOG:BEGIN
local CHANGELOG_ENTRIES = {
    ["6.0.2"] = {
        version = "6.0.2",
        published = "2026-10-28",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Action Bars: new Glows tab. Pick the style, colour and opacity of proc glows, of spells that glow while usable (such as Execute or Overpower) and of spells coming off cooldown, and give any spell its own look.",
            "Teleport Menu: new Atlas look, a map table in your accent colour with every teleport as a waypoint.",
            "Enhancements: new Arena History. It records every finished arena (rated, Solo Shuffle and skirmish) with both teams, damage, healing and rating changes. Open it with /ktarenas.",
            "Objective Tracker: a small arrow above the tracker hides or shows it entirely, background included.",
            "Profiles: right-click a profile card for a menu (load, assign to spec, change icon, export, save as, delete), and the new profile card creates a clean profile with the KUI defaults.",
            "Installer: the Unit Frames, Party Frames and Damage Meter previews show the Visual Style you pick and always fit their box. Party Frames gets the same style row as Unit Frames.",
            "Test buttons: new animated look in your accent colour, the same in every language.",
            "Options: section cards no longer touch or overlap, and the pinned live preview no longer shows the options scrolling behind it.",
            "Cooldown Manager: the KUI Tracker docks to the player frame as it is drawn, keeping room for the cast bar, the druid mana bar and combo points. Bars docked together keep their anchor when dragged in Unlock Mode.",
            "Translations: installer texts reviewed in every language, more option labels translated, and line breaks show correctly.",
        },
    },
    ["6.0.1"] = {
        version = "6.0.1",
        published = "2026-10-25",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Installer: redesigned in the KUI look, with a painted window, an animated progress bar, cut-corner buttons and holographic language switches with country flags. Its colours follow your KUI accent, also when you change it while it is open.",
            "Installer: the Enhanced Friend List, Bags and Damage Meter previews show the real windows, the Cooldown Manager preview stacks your bars as they sit on screen, and the welcome page shows your character with an accent glow.",
            "Installer: new \"Opening KullThranUI\" step that explains how to open the KUI options, KUI Unlock Mode and the installer, and a \"How do I move frames?\" guide on the scale step.",
            "Unlock Mode: redesigned side panel with its own art, Grid, Snap, Dark and Coords tiles, a filter for the element list, an icon for every element and a Guide that explains each control.",
            "Armory: its own look for each Visual Style (slot borders, stats panel, item level and PvP badge, tabs and header) with new icons, and a redesigned Progress page with your rating, dungeon tiles, the Great Vault and your raids.",
            "Style pickers: Armory, Bags, Chat and Party Frames share new style cards, and the Nameplates style cards show a live plate of each style.",
            "Enhancements: new Kick Tracker (your group's interrupts on the enemy nameplates, with cooldown bars, in Mythic, Mythic+ and arenas) and Spell History (the spells you cast as a row of icons).",
            "Enhanced Friend List: shows the exact WoW game each friend is playing.",
            "Cooldown Manager: KUI Tracker icons can be clicked to cast or use them.",
            "Minimap: style cards per Visual Style, a more faithful live preview, and KUI module options in the minimap button drawer.",
            "Bags: the options page shows a live preview of the window with your own items.",
            "Skins: gradient window borders and a cleaner group finder popup.",
            "Chat: messages stay left-aligned with the per-script font.",
            "Translations completed for every language, Bulk Buy included.",
        },
    },
    ["6.0.0"] = {
        version = "6.0.0",
        published = "2026-10-22",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Options window: redesigned, with its own look for each Visual Style (KUI, Forever, Retail, Classic). The Window Scale percentage can be typed in, and scrollbars have a soft glow.",
            "Profiles: new page with animated profile cards in your accent colour. Pick any game icon for each profile, and choose modules and Cooldown Manager specs from clear grids to export or import.",
            "Cooldown Manager: five new glow styles (Pixel Glow, Action Button Glow, GCD, Classic WoW Glow and Blackout). On icons with a custom shape, the glows follow the shape's outline.",
            "Cooldown Manager: glows on action buttons now sit exactly on the spell icon, and active cooldowns that buff you glow even without a target or when a talent replaces the spell.",
            "Nameplates: pending DoT damage marker on enemy plates, with an optional kill icon when your DoTs are enough to finish the target, and class icons over friendly players.",
            "Damage Meter: new toolbar on every window (new window, reset, data type, segment and options). The mode menu and the breakdown window use the KUI surface texture.",
            "Bags: a frame for each Visual Style, with a style picker on the Bags page that applies at once.",
            "Chat: messages fade one by one after a while, as in the default chat, while the window frame fades when idle. Private chat buttons follow the chat style, and Chinese, Korean and Cyrillic names keep the chat text size.",
            "Minimap: the Calendar, Mail and Tracking buttons follow the Visual Style, the zone name sits on its plate on the round minimap too, and the zone no longer shows twice.",
            "Visual Styles: the level on the style cards is shown in full again.",
            "Fixed a Lua error when switching the Cooldown Manager glow to Pixel Border or Shape Glow.",
            "Fixed the Cooldown Manager buff bar overlapping the Forever and Retail cast bars, and the Cooldown Manager tabs overlapping their header.",
        },
    },
    ["5.1.8"] = {
        version = "5.1.8",
        published = "2026-10-17",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Minimap: choose the side (left, right, top or bottom) for the Teleport Menu, Guild, Friends and KUI options icons and show or hide each one. The live preview now draws the real map of your zone inside the chosen shape, with the icons in place, and the shape picker no longer errors with the Retail ring.",
            "Party Frames: in the Classic, Retail and Forever styles the portrait fills its ring, the Dead, Offline and AFK icon sits on the portrait, debuffs get their own strip below the frame instead of covering the next one, and the live preview and Party Test show portraits again. These styles keep the portrait on, as their art needs it.",
            "Party Frames: fixed a Lua error that appeared when a party member was dead or offline.",
            "Unlock Mode: dragging the X or Y slider no longer sends the element away or makes it flicker, and editing X no longer makes Y sink.",
            "Nameplates: a friendly player who challenges you to a duel no longer shows two plates at once.",
            "Chat: Battle.net toasts (friend online, invites) are visible again.",
        },
    },
    ["5.1.7"] = {
        version = "5.1.7",
        published = "2026-10-17",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Minimap: choose the side (left, right, top or bottom) for the Teleport Menu, Guild, Friends and KUI options icons and show or hide each one. The live preview now draws the real map of your zone inside the chosen shape, with the icons in place, and the shape picker no longer errors with the Retail ring.",
            "Party Frames: in the Classic, Retail and Forever styles the portrait fills its ring, the Dead, Offline and AFK icon sits on the portrait, debuffs get their own strip below the frame instead of covering the next one, and the live preview and Party Test show portraits again. These styles keep the portrait on, as their art needs it.",
            "Party Frames: fixed a Lua error that appeared when a party member was dead or offline.",
            "Unlock Mode: dragging the X or Y slider no longer sends the element away or makes it flicker, and editing X no longer makes Y sink.",
            "Nameplates: a friendly player who challenges you to a duel no longer shows two plates at once.",
            "Chat: Battle.net toasts (friend online, invites) are visible again.",
        },
    },
    ["5.1.6"] = {
        version = "5.1.6",
        published = "2026-10-14",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Minimap: choose the side (left, right, top or bottom) for the Teleport Menu, Guild, Friends and KUI options icons and show or hide each one. The live preview now draws the real map of your zone inside the chosen shape, with the icons in place, and the shape picker no longer errors with the Retail ring.",
            "Party Frames: in the Classic, Retail and Forever styles the portrait fills its ring, the Dead, Offline and AFK icon sits on the portrait, debuffs get their own strip below the frame instead of covering the next one, and the live preview and Party Test show portraits again. These styles keep the portrait on, as their art needs it.",
            "Party Frames: fixed a Lua error that appeared when a party member was dead or offline.",
            "Unlock Mode: dragging the X or Y slider no longer sends the element away or makes it flicker, and editing X no longer makes Y sink.",
            "Nameplates: a friendly player who challenges you to a duel no longer shows two plates at once.",
            "Chat: Battle.net toasts (friend online, invites) are visible again.",
        },
    },
    ["5.1.5"] = {
        version = "5.1.5",
        published = "2026-10-11",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Minimap: choose the side (left, right, top or bottom) for the Teleport Menu, Guild, Friends and KUI options icons and show or hide each one. The live preview now draws the real map of your zone inside the chosen shape, with the icons in place, and the shape picker no longer errors with the Retail ring.",
            "Party Frames: in the Classic, Retail and Forever styles the portrait fills its ring, the Dead, Offline and AFK icon sits on the portrait, debuffs get their own strip below the frame instead of covering the next one, and the live preview and Party Test show portraits again. These styles keep the portrait on, as their art needs it.",
            "Party Frames: fixed a Lua error that appeared when a party member was dead or offline.",
            "Unlock Mode: dragging the X or Y slider no longer sends the element away or makes it flicker, and editing X no longer makes Y sink.",
            "Nameplates: a friendly player who challenges you to a duel no longer shows two plates at once.",
            "Chat: Battle.net toasts (friend online, invites) are visible again.",
        },
    },
    ["5.1.4"] = {
        version = "5.1.4",
        published = "2026-10-11",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Unlock Mode: right-clicking an element opens a complete Element Options menu. Width, height, X and Y have sliders and number boxes, and you can anchor the element to another one with its own offsets and extra width, pick the screen point positions are measured from, fade it on mouseover, center it, or reset its position and size.",
            "Unlock Mode: Unit Frames, Cast Bar and Party Frames resize with the same width and height settings used on their option pages.",
            "Unlock Mode: the unsaved changes dialog is back, with Exit Without Saving and Save & Exit. Esc or clicking outside returns you to editing.",
            "Unlock Mode: movers are more opaque, the element list uses flat rows, and hovering a row highlights its element on screen while clicking it makes it flash. Elements also have new hover, click and selection animations.",
            "Leaving Unlock Mode without saving no longer changes Unit Frame scale. The Player frame is restored once to 132% in the Classic, Forever and Retail styles.",
            "Resource Bars: new Autoattack Bars that replace Blizzard's autoattack bars while enabled, with fill or empty direction, color, a test button and artwork that follows the selected visual style.",
            "Damage Meter: new Visual Style selector (KUI, Retail, Forever, Classic). Only the look changes; every window keeps its own mode, session, size and position.",
            "Classic style: Holy Power, Soul Shards, Runes, Essence, Chi and Arcane Charges use a classic gem tray under the Player frame, aligned like the combo points.",
            "Retail and Forever styles keep Blizzard's own class resource art and animations under the Player frame.",
            "Target of Target and Focus Target use the small Blizzard frame with power bar and portrait in the Classic, Forever and Retail styles, and their previews match.",
            "Druid combo points are only shown in Cat Form, in every combo style.",
            "Party Frames: in the Classic, Retail and Forever styles, debuffs sit centered below the frame instead of over the health bar when the debuff anchor is Center.",
            "Cooldown Manager: the KUI Tracker no longer shows another class's interrupt or defensive (for example Kick on a Warlock) when characters share a profile.",
            "Cooldown Manager: bars keep their exact position after being dragged in Unlock Mode and when arena layouts reset.",
            "Unit Frames: AFK, Dead, Ghost and Offline badges update correctly when you switch target or focus.",
            "Unit Frames: names written in Korean, Chinese or Japanese characters display correctly instead of empty boxes.",
            "Target auras refresh reliably after target changes.",
            "Bags: using an item from the bags in combat no longer triggers a blocked-action warning. The bag updates as soon as combat ends.",
            "Bags: item categories (Equipment, Consumables, Reagents, Junk and the rest) are now built into KullThranUI and work on their own.",
            "Armory: the Stats, Titles, Equipment and Progress bar only appears on the Character tab and stays hidden on Reputation and Currency.",
            "Objective Tracker: the accent-colored bar under the Quests header is also shown in KUI style.",
            "Nameplates: KUI style bars no longer keep the fill texture left by a previously applied style, and group threat colors stay readable.",
            "Teleport Menu shows destination names in your client's language.",
            "Minimap layout refreshes with your current settings after combat.",
            "Tooltip, Installer previews, Inspect, Minimap and Aura Reminders texts are now translated in every supported language.",
        },
    },
    ["5.1.3"] = {
        version = "5.1.3",
        published = "2026-10-06",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Party Frames now offer KUI, Forever, Retail and Classic style cards with independent class-color or health-color selections.",
            "Reworked Party Test and live previews to match the selected style, with randomized classes appropriate to the client.",
            "Fixed KUI party portrait layering and aura placement; sample dispel overlays are limited to one frame.",
            "Forever, Retail and Classic party frames are 25% larger by default. KUI frame sizing remains unchanged.",
            "Debuff overlays default to disabled for Forever, Retail and Classic party styles.",
            "Raid group movers are available in Unlock Mode outside an active raid.",
            "Elite and Rare nameplate indicators fit the upper-right corner without reducing their size and support manual X/Y offsets.",
            "Focus, Target of Target and Focus Target frames and previews use matching frame artwork for the selected style.",
            "Cast Bar style controls have clearer icons and an Apply Style button matching the options interface.",
            "Refined the Profiles page layout and module export/import controls, with accent-colored borders and clearer text.",
            "Visual Style cards use rounded surfaces and a subtle hover effect, with no card tooltips.",
            "Refined the options search bar to fit the header; performance readings are now in Enhancements > System Tuning.",
            "Test buttons use transparent backgrounds, clean white text and outlined borders. Options text follows the global font.",
        },
    },
    ["5.1.2"] = {
        version = "5.1.2",
        published = "2026-10-05",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Cast Bar now offers KUI, Classic, Forever and Retail preview tabs with Apply controls; native styles use Blizzard casting art and colors. Classic has no icon, outlined text and a properly layered frame.",
            "New Visual Style selector (KUI, Classic, Retail, Forever) in the General tab and in the Installer. Applying a style restyles Unit Frames, Party Frames, Nameplates, Action Bars, Resource Bars, Cast Bar, Cooldown Manager, Minimap and Skins together, shows a live preview and reloads the interface.",
            "The Installer's color step is now Visual Style & Color and returns to that page after the reload.",
            "Nameplates: style presets in Nameplates > General with a preview of each. Classic has the original bronze border, a gold level pill and larger bars; Retail uses Blizzard's own nameplate art with the level inside the bar; Forever has taller bars with the name above, a bronze border and the level in a yellow box beside the bar.",
            "Nameplates mark enemies you still need for a quest with a yellow \"!\" in every style.",
            "The nameplate live preview shows the selected visual style.",
            "Unit Frames: authentic player, target and pet frame art per style, Blizzard-style name and level text, combat and resting icons, a frame-size option, and Rare/Elite indicators.",
            "Combo points under the Player and Target frames can be Off, Modern or Classic (Target also has a portrait ring), as circles or pips, placed below or above the frame with X/Y offsets. Each style picks its own look by default.",
            "Incoming heal prediction, combat text on the portrait (with an off toggle and a white-numbers option) and an aggro glow toggle that also lights the Target portrait overlays.",
            "Party Frames: portraits can be 2D, 3D or Class Theme, with zoom, rotation, offset, side, facing and border options.",
            "3D portraits in circular Unit Frame portraits.",
            "Action Bars: Action Bar Art selector with live previews (Forever or Classic end caps); cooldown swipes follow the button shape.",
            "Cooldown Manager: per-ability visibility rules (right-click an icon) such as hidden or glowing while on cooldown, usable-only display and charge controls; the KUI Tracker adapts to every style.",
            "Minimap: frame rings per style with a selector and Live Preview.",
            "The Objective Tracker headers show an accent-colored gradient bar in the Blizzard-art styles.",
            "Chat: left-click a channel tag to start typing in that channel.",
            "Redesigned Mail skin.",
            "Profiles remember whether they come from Retail or Forever; importing a string from the other variant works with a notice, and UI scale is no longer part of exported or imported profiles.",
            "KUI no longer changes your UI scale unless you choose a scale yourself, and module on/off toggles apply correctly.",
            "The changelog button now sits in the General tab header.",
            "Fixed KUI Tracker icons briefly showing a green swipe.",
            "Profile import notices, nameplate style prompts and visual style messages are now available in every supported language.",
            "KUI Style target combo points now form a separate row above the portrait.",
            "Classic Rare/Elite overlays fit KUI circular portraits without the stock level socket.",
            "Classic player health and power percentages appear inside their bars.",
            "Blue quest-objective nameplates use a darker shade in Classic.",
            "Aggro glow illuminates the complete Classic Rare/Elite decoration.",
            "Target arrows respect the frame and level badges in every nameplate style.",
            "Unit Frames live previews show the complete Rare/Elite artwork beneath the level.",
            "Cast Bar styles use Avant Garde text, with style icons in the tabs and preview.",
            "Fixed Hide Alerts suppressing loot-roll windows; pending rolls remain visible and selectable.",
            "Unit Frame combo displays can be toggled independently and combined; Target defaults to the portrait ring, with correctly aligned optional rows.",
            "Retail-style nameplates keep stable atlas geometry as camera scale changes.",
            "Fixed Nameplate Tip of the Spear and Whirlwind tracking on player lifecycle and spellcast events.",
            "Applying KUI Style on Retail keeps Unit Frame portraits disabled, including previously saved style settings.",
        },
    },
    ["5.1.1"] = {
        version = "5.1.1",
        published = "2026-09-27",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "KullThranUI 5.1.1",
            "KullThranUI 5.1.1.",
            "Added separate Only Name and instance-display controls for friendly players and NPCs, with KUI bars, name-only mode, and hidden friendly plates.",
            "Reduced active friendly nameplate health-bar dimensions and stabilized custom overlays, font handling, and Blizzard-frame suppression.",
            "Added a runtime /knpdebug comparison for nameplate ownership and layout.",
            "Added configurable elite/rare indicators, no-portrait placement, classification artwork, and refreshed level/PvP metadata for Unit Frames.",
            "Improved Unit Frames cast-bar cleanup, secret-value resource handling, dispel overlays, and metadata refresh after target or unit changes.",
            "Made Unlock Mode rescale saved positions when UI scale or display dimensions change.",
            "Added the KUI options icon setting and translations for the new indicator controls.",
            "Corrected the LFG skin right border and restored Minimap state across cinematic transitions.",
            "Hardened the stable release workflow with explicit release, beta, and alpha classification and dynamic package versioning.",
        },
    },
    ["5.1.0"] = {
        version = "5.1.0",
        published = "2026-09-25",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "KullThranUI 5.1.0",
            "Added a dedicated gold border highlight for quest items in Bags, with container metadata and item-class fallback detection.",
            "Corrected parent-scale handling for standard and friendly Nameplates so rendered plates keep the intended scale during reassignment and cleanup.",
            "Updated KUI and every module to the 5.1.0 release version.",
        },
    },
    ["5.0.9"] = {
        version = "5.0.9",
        published = "2026-09-24",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Added persistent drag-and-drop ordering for Aura Reminders preview icons and runtime reminder icons.",
            "Applied the KUI surface texture to Bags panels, with a darker 62% wash for better contrast.",
            "Improved secure whisper routing and duplicate-message protection in Chat.",
            "Added drag-and-drop ordering for Cooldown Manager tracker previews and custom tracker rows.",
            "Preserved the Minimap cluster position through cinematic and movie transitions.",
            "Added independent enemy and friendly nameplate level visibility, with level text positioned beside the rendered name.",
            "Cleaned up interrupted Unit Frames cast bars so stale icons, text, and tint layers are removed immediately.",
            "Added optional character-level display for Retail Nameplates, Unit Frames, and Party Frames, with independent font, size, outline, colour, and offset controls. The option remains disabled by default.",
            "Added an optional PvP faction icon for Nameplates and player or target frames, shown only while PvP is active and configurable from the relevant module settings.",
            "Integrated the former BlizzMove functionality as KUIMove with its own API, General settings page, frame library, safe defaults, movement controls, scale memory, and reset actions.",
            "Renamed KUIMove's user-facing and internal ownership paths throughout KullThranUI, including commands, profile handling, localization, options, and module loading.",
            "Added migration support for existing BlizzMove and KUIMove SavedVariables so previous window layouts can continue to be used without imposing new level or PvP display settings.",
            "Reworked the legacy KUIMove configuration into a KUI-style layout with clearer Control Center, Movement & Memory, Frame Library, and Safe Defaults sections.",
            "Removed duplicate KUIMove loading from the Enhancements package path, preventing conflicting ownership and reducing the chance of duplicate hooks or Lua errors.",
            "Hardened level, PvP, protected-value, and secret-value handling across Nameplates, Party Frames, and Unit Frames for current Retail and WoW Forever API behaviour.",
            "Updated module localization and profile import or export definitions to use KUIMove consistently while retaining compatibility with older profile keys.",
            "Added WoW Forever and WoW Forever Beta detection to Enhanced Friend List, including the dedicated WoW Forever artwork and distinct tooltip labels.",
            "Hardened Enhanced Friend List native tab handoff and embedded Raid navigation while preserving Blizzard's protected click path.",
            "Fixed Raid Warning taint caused by secret or unit-derived values by using a safe static warning message and protected-value checks.",
            "Improved Chat handling for protected and secret message data, including safer whisper capture and native channel integration.",
            "Refined Minimap utility-button collection and restoration so addon launchers are handled without disturbing Blizzard's map, waypoint, POI, or scanner controls.",
            "Reduced Cooldown Manager background work with coalesced event-driven refreshes and safer handling of protected cooldown values.",
            "Improved Mythic+ History damage matching and ranking fallbacks, added font fallback support, and added an option for LFG class-colour bars.",
            "Hardened Aura Reminders, Nameplates text rendering, and Modern KUI skins for current protected UI and Blizzard frame changes.",
            "New Feature: Mythic+ History. A detailed Mythic+ history has been added to the Enhancements module, allowing you to track completed keys and view a keystone summary breakdown, including a damage meter to see who did the most DPS during the run. NOTE: The Mythic+ History will only display all party members after activating the submodule, as KullThranUI needs to start saving the runs internally from that point forward.",
            "Localization updates: Translations have been applied across all KullThranUI modules. Localization and compatibility have been expanded to cover 97% of the addon and its features. Added country flags to easily     distinguish languages. Fixed translation errors across several Widget elements and the Enhancements submodule.",
            "Skins module update: New visual style applied. Improved the visibility and overall readability of the reskinned default Blizzard frames.",
            "Added a scrollbar to the Widget system. It will now appear automatically in all modules that have enough options to require scrolling.",
            "Added a Minimap button to open KUI options directly.",
            "Fixed an issue in the Objective Tracker where the 'Scenario' header would display even when not inside an instance.",
            "Fixed KUI Tracker behavior in the CooldownManager. Potion and Warlock Healthstone cooldowns will now properly reset after a raid boss wipe/reset (when the appropriate conditions are met).",
            "KullThranUI is now officially available on GitHub! Future updates for CurseForge and Wago will be deployed from there, and Pull Requests will soon be enabled so the community can help improve translations.",
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
            "Restored reliable per-conversation whisper capture on secure-chat builds by mirroring Blizzard-rendered whisper lines into KUI history, including Battle.net conversations, without bypassing the selected whisper thread.",
            "Hardened Chat integration for protected message and channel data by avoiding unsafe native filter and channel-list mutations, preventing taint attribution and protected-table failures during PvP and other restricted chat dispatches.",
            "Reworked first-time setup for new characters with a dedicated starting-profile choice, allowing existing saved profiles to be selected or KUI defaults to be used without forcing every character onto the KullThranUI profile.",
            "Improved Installer and profile startup handling with stable per-character tracking, safer specialization-profile transitions, correct layout imports into the active profile, and more reliable continuation through conflict detection and setup.",
            "Expanded the Fonts & Colors page with live font previews, a separate Launcher and Options font, individual typography controls for major HUD, social, character, and inspection areas, and additional color controls for interface surfaces, action bars, progress displays, Chat, Armory, and Inspect.",
            "Reworked global font inheritance so modules that still follow the global font update together while explicitly customized areas preserve their own selection, with combat-safe deferred refreshes across the supported interface.",
            "Refined the main configuration window with an accent-colored KUI logo, a new resize grip, a slimmer navigation scrollbar, immediate minimap social-icon recoloring, and a scalable nine-slice background that preserves its proportions at preset and custom window sizes.",
            "Redesigned KUI Unlock Mode with a wider and cleaner sidebar, clearer active-element feedback, improved mover menus, direct access to profile importing, an animated opening logo, and an automatically retracting sidebar that remains available from the edge of the screen.",
            "Improved the in-game changelog window so its complete ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œDonÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢t show againÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â row is clickable, the current patch suppression state is restored correctly, and enabling or disabling the option is saved immediately.",
            "Hardened Chat against protected edit-box state changes during combat, preventing unsafe whisper, Battle.net, and chat-type mutations while retaining the normal input flow outside combat.",
            "Reduced Cooldown Manager background work by replacing continuous glow polling with coalesced event-driven updates, refreshing only affected bars when possible, and avoiding redundant transition passes once BlizzardÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¾Ãƒâ€šÃ‚Â¢s Cooldown Viewer pools have stabilized.",
            "Improved Cooldown Manager trackers by hiding unavailable potion items, keeping owned potion ranks synchronized, stabilizing player and target frame anchoring around narrow CDM layouts, and making arena, battleground, specialization, and world-transition recovery more selective.",
            "Reworked centered horizontal Party and Arena layouts so the player remains in the intended middle position as the group fills, with a corrected bottom-center default position for horizontal Party Frames.",
            "Improved Party Frames range, phase, roster, aura, and encounter handling with more reliable out-of-range recovery, independent dispel indicators, properly layered AuraKit dispel effects, boss-frame activation during encounters, and fewer unnecessary full roster rebuilds while zoning.",
            "Refined Modern KUI group-interface skins with complete accent borders for selected LFG entries, clearer role-selection feedback, and a rebuilt Ready Check presentation with restored portraits, dedicated Ready and Not Ready buttons, consistent surfaces, and accent-aware artwork.",
            "Restored reliable first-run Installer startup for new users and brought back the visible \"Don't show again\" control, with synchronized login settings so the prompt can be disabled or re-enabled cleanly.",
            "Hardened Chat against protected and secret PvP payloads, preventing duplicated battleground system messages while preserving Blizzard's native message handling.",
            "Restored access to Blizzard's Group Management controls, including raid and world-marker tools, when KullThranUI Party Frames are active.",
            "Improved Party Frames during PvP and arena transitions with safer protected-unit handling and more reliable roster, role, raid-target, and aura refreshes.",
            "Fixed KullThranUI Bags tainting Blizzard's protected container click path, restoring item use, equipping, dragging, and background drops without UseContainerItem() forbidden-action errors.",
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
            "New Feature: Mythic+ History. A detailed Mythic+ history has been added to the Enhancements module, allowing you to track completed keys and view a keystone summary breakdown, including a damage meter to see who did the most DPS during the run. NOTE: The Mythic+ History will only display all party members after activating the submodule, as KullThranUI needs to start saving the runs internally from that point forward.",
            "Localization updates: Translations have been applied across all KullThranUI modules. Localization and compatibility have been expanded to cover 97% of the addon and its features. Added country flags to easily     distinguish languages. Fixed translation errors across several Widget elements and the Enhancements submodule.",
            "Skins module update: New visual style applied. Improved the visibility and overall readability of the reskinned default Blizzard frames.",
            "Added a scrollbar to the Widget system. It will now appear automatically in all modules that have enough options to require scrolling.",
            "Added a Minimap button to open KUI options directly.",
            "Fixed an issue in the Objective Tracker where the 'Scenario' header would display even when not inside an instance.",
            "Fixed KUI Tracker behavior in the CooldownManager. Potion and Warlock Healthstone cooldowns will now properly reset after a raid boss wipe/reset (when the appropriate conditions are met).",
            "KullThranUI is now officially available on GitHub! Future updates for CurseForge and Wago will be deployed from there, and Pull Requests will soon be enabled so the community can help improve translations.",
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
            "Restored reliable per-conversation whisper capture on secure-chat builds by mirroring Blizzard-rendered whisper lines into KUI history, including Battle.net conversations, without bypassing the selected whisper thread.",
            "Hardened Chat integration for protected message and channel data by avoiding unsafe native filter and channel-list mutations, preventing taint attribution and protected-table failures during PvP and other restricted chat dispatches.",
            "Reworked first-time setup for new characters with a dedicated starting-profile choice, allowing existing saved profiles to be selected or KUI defaults to be used without forcing every character onto the KullThranUI profile.",
            "Improved Installer and profile startup handling with stable per-character tracking, safer specialization-profile transitions, correct layout imports into the active profile, and more reliable continuation through conflict detection and setup.",
            "Expanded the Fonts & Colors page with live font previews, a separate Launcher and Options font, individual typography controls for major HUD, social, character, and inspection areas, and additional color controls for interface surfaces, action bars, progress displays, Chat, Armory, and Inspect.",
            "Reworked global font inheritance so modules that still follow the global font update together while explicitly customized areas preserve their own selection, with combat-safe deferred refreshes across the supported interface.",
            "Refined the main configuration window with an accent-colored KUI logo, a new resize grip, a slimmer navigation scrollbar, immediate minimap social-icon recoloring, and a scalable nine-slice background that preserves its proportions at preset and custom window sizes.",
            "Redesigned KUI Unlock Mode with a wider and cleaner sidebar, clearer active-element feedback, improved mover menus, direct access to profile importing, an animated opening logo, and an automatically retracting sidebar that remains available from the edge of the screen.",
            "Improved the in-game changelog window so its complete ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“DonÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢t show againÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â row is clickable, the current patch suppression state is restored correctly, and enabling or disabling the option is saved immediately.",
            "Hardened Chat against protected edit-box state changes during combat, preventing unsafe whisper, Battle.net, and chat-type mutations while retaining the normal input flow outside combat.",
            "Reduced Cooldown Manager background work by replacing continuous glow polling with coalesced event-driven updates, refreshing only affected bars when possible, and avoiding redundant transition passes once BlizzardÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢s Cooldown Viewer pools have stabilized.",
            "Improved Cooldown Manager trackers by hiding unavailable potion items, keeping owned potion ranks synchronized, stabilizing player and target frame anchoring around narrow CDM layouts, and making arena, battleground, specialization, and world-transition recovery more selective.",
            "Reworked centered horizontal Party and Arena layouts so the player remains in the intended middle position as the group fills, with a corrected bottom-center default position for horizontal Party Frames.",
            "Improved Party Frames range, phase, roster, aura, and encounter handling with more reliable out-of-range recovery, independent dispel indicators, properly layered AuraKit dispel effects, boss-frame activation during encounters, and fewer unnecessary full roster rebuilds while zoning.",
            "Refined Modern KUI group-interface skins with complete accent borders for selected LFG entries, clearer role-selection feedback, and a rebuilt Ready Check presentation with restored portraits, dedicated Ready and Not Ready buttons, consistent surfaces, and accent-aware artwork.",
            "Restored reliable first-run Installer startup for new users and brought back the visible \"Don't show again\" control, with synchronized login settings so the prompt can be disabled or re-enabled cleanly.",
            "Hardened Chat against protected and secret PvP payloads, preventing duplicated battleground system messages while preserving Blizzard's native message handling.",
            "Restored access to Blizzard's Group Management controls, including raid and world-marker tools, when KullThranUI Party Frames are active.",
            "Improved Party Frames during PvP and arena transitions with safer protected-unit handling and more reliable roster, role, raid-target, and aura refreshes.",
            "Fixed KullThranUI Bags tainting Blizzard's protected container click path, restoring item use, equipping, dragging, and background drops without UseContainerItem() forbidden-action errors.",
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
            "Added WoW Forever and WoW Forever Beta detection to Enhanced Friend List, including the dedicated WoW Forever artwork and distinct tooltip labels.",
            "Hardened Enhanced Friend List native tab handoff and embedded Raid navigation while preserving Blizzard's protected click path.",
            "Fixed Raid Warning taint caused by secret or unit-derived values by using a safe static warning message and protected-value checks.",
            "Improved Chat handling for protected and secret message data, including safer whisper capture and native channel integration.",
            "Refined Minimap utility-button collection and restoration so addon launchers are handled without disturbing Blizzard's map, waypoint, POI, or scanner controls.",
            "Reduced Cooldown Manager background work with coalesced event-driven refreshes and safer handling of protected cooldown values.",
            "Improved Mythic+ History damage matching and ranking fallbacks, added font fallback support, and added an option for LFG class-colour bars.",
            "Hardened Aura Reminders, Nameplates text rendering, and Modern KUI skins for current protected UI and Blizzard frame changes.",
            "New Feature: Mythic+ History. A detailed Mythic+ history has been added to the Enhancements module, allowing you to track completed keys and view a keystone summary breakdown, including a damage meter to see who did the most DPS during the run. NOTE: The Mythic+ History will only display all party members after activating the submodule, as KullThranUI needs to start saving the runs internally from that point forward.",
            "Localization updates: Translations have been applied across all KullThranUI modules. Localization and compatibility have been expanded to cover 97% of the addon and its features. Added country flags to easily     distinguish languages. Fixed translation errors across several Widget elements and the Enhancements submodule.",
            "Skins module update: New visual style applied. Improved the visibility and overall readability of the reskinned default Blizzard frames.",
            "Added a scrollbar to the Widget system. It will now appear automatically in all modules that have enough options to require scrolling.",
            "Added a Minimap button to open KUI options directly.",
            "Fixed an issue in the Objective Tracker where the 'Scenario' header would display even when not inside an instance.",
            "Fixed KUI Tracker behavior in the CooldownManager. Potion and Warlock Healthstone cooldowns will now properly reset after a raid boss wipe/reset (when the appropriate conditions are met).",
            "KullThranUI is now officially available on GitHub! Future updates for CurseForge and Wago will be deployed from there, and Pull Requests will soon be enabled so the community can help improve translations.",
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
            "Restored reliable per-conversation whisper capture on secure-chat builds by mirroring Blizzard-rendered whisper lines into KUI history, including Battle.net conversations, without bypassing the selected whisper thread.",
            "Hardened Chat integration for protected message and channel data by avoiding unsafe native filter and channel-list mutations, preventing taint attribution and protected-table failures during PvP and other restricted chat dispatches.",
            "Reworked first-time setup for new characters with a dedicated starting-profile choice, allowing existing saved profiles to be selected or KUI defaults to be used without forcing every character onto the KullThranUI profile.",
            "Improved Installer and profile startup handling with stable per-character tracking, safer specialization-profile transitions, correct layout imports into the active profile, and more reliable continuation through conflict detection and setup.",
            "Expanded the Fonts & Colors page with live font previews, a separate Launcher and Options font, individual typography controls for major HUD, social, character, and inspection areas, and additional color controls for interface surfaces, action bars, progress displays, Chat, Armory, and Inspect.",
            "Reworked global font inheritance so modules that still follow the global font update together while explicitly customized areas preserve their own selection, with combat-safe deferred refreshes across the supported interface.",
            "Refined the main configuration window with an accent-colored KUI logo, a new resize grip, a slimmer navigation scrollbar, immediate minimap social-icon recoloring, and a scalable nine-slice background that preserves its proportions at preset and custom window sizes.",
            "Redesigned KUI Unlock Mode with a wider and cleaner sidebar, clearer active-element feedback, improved mover menus, direct access to profile importing, an animated opening logo, and an automatically retracting sidebar that remains available from the edge of the screen.",
            "Improved the in-game changelog window so its complete ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“DonÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢t show againÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â row is clickable, the current patch suppression state is restored correctly, and enabling or disabling the option is saved immediately.",
            "Hardened Chat against protected edit-box state changes during combat, preventing unsafe whisper, Battle.net, and chat-type mutations while retaining the normal input flow outside combat.",
            "Reduced Cooldown Manager background work by replacing continuous glow polling with coalesced event-driven updates, refreshing only affected bars when possible, and avoiding redundant transition passes once BlizzardÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢s Cooldown Viewer pools have stabilized.",
            "Improved Cooldown Manager trackers by hiding unavailable potion items, keeping owned potion ranks synchronized, stabilizing player and target frame anchoring around narrow CDM layouts, and making arena, battleground, specialization, and world-transition recovery more selective.",
            "Reworked centered horizontal Party and Arena layouts so the player remains in the intended middle position as the group fills, with a corrected bottom-center default position for horizontal Party Frames.",
            "Improved Party Frames range, phase, roster, aura, and encounter handling with more reliable out-of-range recovery, independent dispel indicators, properly layered AuraKit dispel effects, boss-frame activation during encounters, and fewer unnecessary full roster rebuilds while zoning.",
            "Refined Modern KUI group-interface skins with complete accent borders for selected LFG entries, clearer role-selection feedback, and a rebuilt Ready Check presentation with restored portraits, dedicated Ready and Not Ready buttons, consistent surfaces, and accent-aware artwork.",
            "Restored reliable first-run Installer startup for new users and brought back the visible \"Don't show again\" control, with synchronized login settings so the prompt can be disabled or re-enabled cleanly.",
            "Hardened Chat against protected and secret PvP payloads, preventing duplicated battleground system messages while preserving Blizzard's native message handling.",
            "Restored access to Blizzard's Group Management controls, including raid and world-marker tools, when KullThranUI Party Frames are active.",
            "Improved Party Frames during PvP and arena transitions with safer protected-unit handling and more reliable roster, role, raid-target, and aura refreshes.",
            "Fixed KullThranUI Bags tainting Blizzard's protected container click path, restoring item use, equipping, dragging, and background drops without UseContainerItem() forbidden-action errors.",
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
            "New Feature: Mythic+ History. A detailed Mythic+ history has been added to the Enhancements module, allowing you to track completed keys and view a keystone summary breakdown, including a damage meter to see who did the most DPS during the run. NOTE: The Mythic+ History will only display all party members after activating the submodule, as KullThranUI needs to start saving the runs internally from that point forward.",
            "Localization updates: Translations have been applied across all KullThranUI modules. Localization and compatibility have been expanded to cover 97% of the addon and its features. Added country flags to easily     distinguish languages. Fixed translation errors across several Widget elements and the Enhancements submodule.",
            "Skins module update: New visual style applied. Improved the visibility and overall readability of the reskinned default Blizzard frames.",
            "Added a scrollbar to the Widget system. It will now appear automatically in all modules that have enough options to require scrolling.",
            "Added a Minimap button to open KUI options directly.",
            "Fixed an issue in the Objective Tracker where the 'Scenario' header would display even when not inside an instance.",
            "Fixed KUI Tracker behavior in the CooldownManager. Potion and Warlock Healthstone cooldowns will now properly reset after a raid boss wipe/reset (when the appropriate conditions are met).",
            "KullThranUI is now officially available on GitHub! Future updates for CurseForge and Wago will be deployed from there, and Pull Requests will soon be enabled so the community can help improve translations.",
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
            "Restored reliable per-conversation whisper capture on secure-chat builds by mirroring Blizzard-rendered whisper lines into KUI history, including Battle.net conversations, without bypassing the selected whisper thread.",
            "Hardened Chat integration for protected message and channel data by avoiding unsafe native filter and channel-list mutations, preventing taint attribution and protected-table failures during PvP and other restricted chat dispatches.",
            "Reworked first-time setup for new characters with a dedicated starting-profile choice, allowing existing saved profiles to be selected or KUI defaults to be used without forcing every character onto the KullThranUI profile.",
            "Improved Installer and profile startup handling with stable per-character tracking, safer specialization-profile transitions, correct layout imports into the active profile, and more reliable continuation through conflict detection and setup.",
            "Expanded the Fonts & Colors page with live font previews, a separate Launcher and Options font, individual typography controls for major HUD, social, character, and inspection areas, and additional color controls for interface surfaces, action bars, progress displays, Chat, Armory, and Inspect.",
            "Reworked global font inheritance so modules that still follow the global font update together while explicitly customized areas preserve their own selection, with combat-safe deferred refreshes across the supported interface.",
            "Refined the main configuration window with an accent-colored KUI logo, a new resize grip, a slimmer navigation scrollbar, immediate minimap social-icon recoloring, and a scalable nine-slice background that preserves its proportions at preset and custom window sizes.",
            "Redesigned KUI Unlock Mode with a wider and cleaner sidebar, clearer active-element feedback, improved mover menus, direct access to profile importing, an animated opening logo, and an automatically retracting sidebar that remains available from the edge of the screen.",
            "Improved the in-game changelog window so its complete ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œDonÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢t show againÃƒÂ¢Ã¢â€šÂ¬Ã‚Â row is clickable, the current patch suppression state is restored correctly, and enabling or disabling the option is saved immediately.",
            "Hardened Chat against protected edit-box state changes during combat, preventing unsafe whisper, Battle.net, and chat-type mutations while retaining the normal input flow outside combat.",
            "Reduced Cooldown Manager background work by replacing continuous glow polling with coalesced event-driven updates, refreshing only affected bars when possible, and avoiding redundant transition passes once BlizzardÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢s Cooldown Viewer pools have stabilized.",
            "Improved Cooldown Manager trackers by hiding unavailable potion items, keeping owned potion ranks synchronized, stabilizing player and target frame anchoring around narrow CDM layouts, and making arena, battleground, specialization, and world-transition recovery more selective.",
            "Reworked centered horizontal Party and Arena layouts so the player remains in the intended middle position as the group fills, with a corrected bottom-center default position for horizontal Party Frames.",
            "Improved Party Frames range, phase, roster, aura, and encounter handling with more reliable out-of-range recovery, independent dispel indicators, properly layered AuraKit dispel effects, boss-frame activation during encounters, and fewer unnecessary full roster rebuilds while zoning.",
            "Refined Modern KUI group-interface skins with complete accent borders for selected LFG entries, clearer role-selection feedback, and a rebuilt Ready Check presentation with restored portraits, dedicated Ready and Not Ready buttons, consistent surfaces, and accent-aware artwork.",
            "Restored reliable first-run Installer startup for new users and brought back the visible \"Don't show again\" control, with synchronized login settings so the prompt can be disabled or re-enabled cleanly.",
            "Hardened Chat against protected and secret PvP payloads, preventing duplicated battleground system messages while preserving Blizzard's native message handling.",
            "Restored access to Blizzard's Group Management controls, including raid and world-marker tools, when KullThranUI Party Frames are active.",
            "Improved Party Frames during PvP and arena transitions with safer protected-unit handling and more reliable roster, role, raid-target, and aura refreshes.",
            "Fixed KullThranUI Bags tainting Blizzard's protected container click path, restoring item use, equipping, dragging, and background drops without UseContainerItem() forbidden-action errors.",
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
    ["5.0.8"] = {
        version = "5.0.8",
        published = "2026-09-19",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Added optional character-level display for Retail Nameplates, Unit Frames, and Party Frames, with independent font, size, outline, colour, and offset controls. The option remains disabled by default.",
            "Added an optional PvP faction icon for Nameplates and player or target frames, shown only while PvP is active and configurable from the relevant module settings.",
            "Integrated the former BlizzMove functionality as KUIMove with its own API, General settings page, frame library, safe defaults, movement controls, scale memory, and reset actions.",
            "Renamed KUIMove's user-facing and internal ownership paths throughout KullThranUI, including commands, profile handling, localization, options, and module loading.",
            "Added migration support for existing BlizzMove and KUIMove SavedVariables so previous window layouts can continue to be used without imposing new level or PvP display settings.",
            "Reworked the legacy KUIMove configuration into a KUI-style layout with clearer Control Center, Movement & Memory, Frame Library, and Safe Defaults sections.",
            "Removed duplicate KUIMove loading from the Enhancements package path, preventing conflicting ownership and reducing the chance of duplicate hooks or Lua errors.",
            "Hardened level, PvP, protected-value, and secret-value handling across Nameplates, Party Frames, and Unit Frames for current Retail and WoW Forever API behaviour.",
            "Updated module localization and profile import or export definitions to use KUIMove consistently while retaining compatibility with older profile keys.",
            "Added WoW Forever and WoW Forever Beta detection to Enhanced Friend List, including the dedicated WoW Forever artwork and distinct tooltip labels.",
            "Hardened Enhanced Friend List native tab handoff and embedded Raid navigation while preserving Blizzard's protected click path.",
            "Fixed Raid Warning taint caused by secret or unit-derived values by using a safe static warning message and protected-value checks.",
            "Improved Chat handling for protected and secret message data, including safer whisper capture and native channel integration.",
            "Refined Minimap utility-button collection and restoration so addon launchers are handled without disturbing Blizzard's map, waypoint, POI, or scanner controls.",
            "Reduced Cooldown Manager background work with coalesced event-driven refreshes and safer handling of protected cooldown values.",
            "Improved Mythic+ History damage matching and ranking fallbacks, added font fallback support, and added an option for LFG class-colour bars.",
            "Hardened Aura Reminders, Nameplates text rendering, and Modern KUI skins for current protected UI and Blizzard frame changes.",
            "New Feature: Mythic+ History. A detailed Mythic+ history has been added to the Enhancements module, allowing you to track completed keys and view a keystone summary breakdown, including a damage meter to see who did the most DPS during the run. NOTE: The Mythic+ History will only display all party members after activating the submodule, as KullThranUI needs to start saving the runs internally from that point forward.",
            "Localization updates: Translations have been applied across all KullThranUI modules. Localization and compatibility have been expanded to cover 97% of the addon and its features. Added country flags to easily     distinguish languages. Fixed translation errors across several Widget elements and the Enhancements submodule.",
            "Skins module update: New visual style applied. Improved the visibility and overall readability of the reskinned default Blizzard frames.",
            "Added a scrollbar to the Widget system. It will now appear automatically in all modules that have enough options to require scrolling.",
            "Added a Minimap button to open KUI options directly.",
            "Fixed an issue in the Objective Tracker where the 'Scenario' header would display even when not inside an instance.",
            "Fixed KUI Tracker behavior in the CooldownManager. Potion and Warlock Healthstone cooldowns will now properly reset after a raid boss wipe/reset (when the appropriate conditions are met).",
            "KullThranUI is now officially available on GitHub! Future updates for CurseForge and Wago will be deployed from there, and Pull Requests will soon be enabled so the community can help improve translations.",
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
            "Restored reliable per-conversation whisper capture on secure-chat builds by mirroring Blizzard-rendered whisper lines into KUI history, including Battle.net conversations, without bypassing the selected whisper thread.",
            "Hardened Chat integration for protected message and channel data by avoiding unsafe native filter and channel-list mutations, preventing taint attribution and protected-table failures during PvP and other restricted chat dispatches.",
            "Reworked first-time setup for new characters with a dedicated starting-profile choice, allowing existing saved profiles to be selected or KUI defaults to be used without forcing every character onto the KullThranUI profile.",
            "Improved Installer and profile startup handling with stable per-character tracking, safer specialization-profile transitions, correct layout imports into the active profile, and more reliable continuation through conflict detection and setup.",
            "Expanded the Fonts & Colors page with live font previews, a separate Launcher and Options font, individual typography controls for major HUD, social, character, and inspection areas, and additional color controls for interface surfaces, action bars, progress displays, Chat, Armory, and Inspect.",
            "Reworked global font inheritance so modules that still follow the global font update together while explicitly customized areas preserve their own selection, with combat-safe deferred refreshes across the supported interface.",
            "Refined the main configuration window with an accent-colored KUI logo, a new resize grip, a slimmer navigation scrollbar, immediate minimap social-icon recoloring, and a scalable nine-slice background that preserves its proportions at preset and custom window sizes.",
            "Redesigned KUI Unlock Mode with a wider and cleaner sidebar, clearer active-element feedback, improved mover menus, direct access to profile importing, an animated opening logo, and an automatically retracting sidebar that remains available from the edge of the screen.",
            "Improved the in-game changelog window so its complete ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“DonÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢t show againÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â row is clickable, the current patch suppression state is restored correctly, and enabling or disabling the option is saved immediately.",
            "Hardened Chat against protected edit-box state changes during combat, preventing unsafe whisper, Battle.net, and chat-type mutations while retaining the normal input flow outside combat.",
            "Reduced Cooldown Manager background work by replacing continuous glow polling with coalesced event-driven updates, refreshing only affected bars when possible, and avoiding redundant transition passes once BlizzardÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢s Cooldown Viewer pools have stabilized.",
            "Improved Cooldown Manager trackers by hiding unavailable potion items, keeping owned potion ranks synchronized, stabilizing player and target frame anchoring around narrow CDM layouts, and making arena, battleground, specialization, and world-transition recovery more selective.",
            "Reworked centered horizontal Party and Arena layouts so the player remains in the intended middle position as the group fills, with a corrected bottom-center default position for horizontal Party Frames.",
            "Improved Party Frames range, phase, roster, aura, and encounter handling with more reliable out-of-range recovery, independent dispel indicators, properly layered AuraKit dispel effects, boss-frame activation during encounters, and fewer unnecessary full roster rebuilds while zoning.",
            "Refined Modern KUI group-interface skins with complete accent borders for selected LFG entries, clearer role-selection feedback, and a rebuilt Ready Check presentation with restored portraits, dedicated Ready and Not Ready buttons, consistent surfaces, and accent-aware artwork.",
            "Restored reliable first-run Installer startup for new users and brought back the visible \"Don't show again\" control, with synchronized login settings so the prompt can be disabled or re-enabled cleanly.",
            "Hardened Chat against protected and secret PvP payloads, preventing duplicated battleground system messages while preserving Blizzard's native message handling.",
            "Restored access to Blizzard's Group Management controls, including raid and world-marker tools, when KullThranUI Party Frames are active.",
            "Improved Party Frames during PvP and arena transitions with safer protected-unit handling and more reliable roster, role, raid-target, and aura refreshes.",
            "Fixed KullThranUI Bags tainting Blizzard's protected container click path, restoring item use, equipping, dragging, and background drops without UseContainerItem() forbidden-action errors.",
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
            "New Feature: Mythic+ History. A detailed Mythic+ history has been added to the Enhancements module, allowing you to track completed keys and view a keystone summary breakdown, including a damage meter to see who did the most DPS during the run. NOTE: The Mythic+ History will only display all party members after activating the submodule, as KullThranUI needs to start saving the runs internally from that point forward.",
            "Localization updates: Translations have been applied across all KullThranUI modules. Localization and compatibility have been expanded to cover 97% of the addon and its features. Added country flags to easily     distinguish languages. Fixed translation errors across several Widget elements and the Enhancements submodule.",
            "Skins module update: New visual style applied. Improved the visibility and overall readability of the reskinned default Blizzard frames.",
            "Added a scrollbar to the Widget system. It will now appear automatically in all modules that have enough options to require scrolling.",
            "Added a Minimap button to open KUI options directly.",
            "Fixed an issue in the Objective Tracker where the 'Scenario' header would display even when not inside an instance.",
            "Fixed KUI Tracker behavior in the CooldownManager. Potion and Warlock Healthstone cooldowns will now properly reset after a raid boss wipe/reset (when the appropriate conditions are met).",
            "KullThranUI is now officially available on GitHub! Future updates for CurseForge and Wago will be deployed from there, and Pull Requests will soon be enabled so the community can help improve translations.",
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
            "Restored reliable per-conversation whisper capture on secure-chat builds by mirroring Blizzard-rendered whisper lines into KUI history, including Battle.net conversations, without bypassing the selected whisper thread.",
            "Hardened Chat integration for protected message and channel data by avoiding unsafe native filter and channel-list mutations, preventing taint attribution and protected-table failures during PvP and other restricted chat dispatches.",
            "Reworked first-time setup for new characters with a dedicated starting-profile choice, allowing existing saved profiles to be selected or KUI defaults to be used without forcing every character onto the KullThranUI profile.",
            "Improved Installer and profile startup handling with stable per-character tracking, safer specialization-profile transitions, correct layout imports into the active profile, and more reliable continuation through conflict detection and setup.",
            "Expanded the Fonts & Colors page with live font previews, a separate Launcher and Options font, individual typography controls for major HUD, social, character, and inspection areas, and additional color controls for interface surfaces, action bars, progress displays, Chat, Armory, and Inspect.",
            "Reworked global font inheritance so modules that still follow the global font update together while explicitly customized areas preserve their own selection, with combat-safe deferred refreshes across the supported interface.",
            "Refined the main configuration window with an accent-colored KUI logo, a new resize grip, a slimmer navigation scrollbar, immediate minimap social-icon recoloring, and a scalable nine-slice background that preserves its proportions at preset and custom window sizes.",
            "Redesigned KUI Unlock Mode with a wider and cleaner sidebar, clearer active-element feedback, improved mover menus, direct access to profile importing, an animated opening logo, and an automatically retracting sidebar that remains available from the edge of the screen.",
            "Improved the in-game changelog window so its complete ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œDonÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢t show againÃƒÂ¢Ã¢â€šÂ¬Ã‚Â row is clickable, the current patch suppression state is restored correctly, and enabling or disabling the option is saved immediately.",
            "Hardened Chat against protected edit-box state changes during combat, preventing unsafe whisper, Battle.net, and chat-type mutations while retaining the normal input flow outside combat.",
            "Reduced Cooldown Manager background work by replacing continuous glow polling with coalesced event-driven updates, refreshing only affected bars when possible, and avoiding redundant transition passes once BlizzardÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢s Cooldown Viewer pools have stabilized.",
            "Improved Cooldown Manager trackers by hiding unavailable potion items, keeping owned potion ranks synchronized, stabilizing player and target frame anchoring around narrow CDM layouts, and making arena, battleground, specialization, and world-transition recovery more selective.",
            "Reworked centered horizontal Party and Arena layouts so the player remains in the intended middle position as the group fills, with a corrected bottom-center default position for horizontal Party Frames.",
            "Improved Party Frames range, phase, roster, aura, and encounter handling with more reliable out-of-range recovery, independent dispel indicators, properly layered AuraKit dispel effects, boss-frame activation during encounters, and fewer unnecessary full roster rebuilds while zoning.",
            "Refined Modern KUI group-interface skins with complete accent borders for selected LFG entries, clearer role-selection feedback, and a rebuilt Ready Check presentation with restored portraits, dedicated Ready and Not Ready buttons, consistent surfaces, and accent-aware artwork.",
            "Restored reliable first-run Installer startup for new users and brought back the visible \"Don't show again\" control, with synchronized login settings so the prompt can be disabled or re-enabled cleanly.",
            "Hardened Chat against protected and secret PvP payloads, preventing duplicated battleground system messages while preserving Blizzard's native message handling.",
            "Restored access to Blizzard's Group Management controls, including raid and world-marker tools, when KullThranUI Party Frames are active.",
            "Improved Party Frames during PvP and arena transitions with safer protected-unit handling and more reliable roster, role, raid-target, and aura refreshes.",
            "Fixed KullThranUI Bags tainting Blizzard's protected container click path, restoring item use, equipping, dragging, and background drops without UseContainerItem() forbidden-action errors.",
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
    ["5.0.7"] = {
        version = "5.0.7",
        published = "2026-09-17",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "Added WoW Forever and WoW Forever Beta detection to Enhanced Friend List, including the dedicated WoW Forever artwork and distinct tooltip labels.",
            "Hardened Enhanced Friend List native tab handoff and embedded Raid navigation while preserving Blizzard's protected click path.",
            "Fixed Raid Warning taint caused by secret or unit-derived values by using a safe static warning message and protected-value checks.",
            "Improved Chat handling for protected and secret message data, including safer whisper capture and native channel integration.",
            "Refined Minimap utility-button collection and restoration so addon launchers are handled without disturbing Blizzard's map, waypoint, POI, or scanner controls.",
            "Reduced Cooldown Manager background work with coalesced event-driven refreshes and safer handling of protected cooldown values.",
            "Improved Mythic+ History damage matching and ranking fallbacks, added font fallback support, and added an option for LFG class-colour bars.",
            "Hardened Aura Reminders, Nameplates text rendering, and Modern KUI skins for current protected UI and Blizzard frame changes.",
            "New Feature: Mythic+ History. A detailed Mythic+ history has been added to the Enhancements module, allowing you to track completed keys and view a keystone summary breakdown, including a damage meter to see who did the most DPS during the run. NOTE: The Mythic+ History will only display all party members after activating the submodule, as KullThranUI needs to start saving the runs internally from that point forward.",
            "Localization updates: Translations have been applied across all KullThranUI modules. Localization and compatibility have been expanded to cover 97% of the addon and its features. Added country flags to easily     distinguish languages. Fixed translation errors across several Widget elements and the Enhancements submodule.",
            "Skins module update: New visual style applied. Improved the visibility and overall readability of the reskinned default Blizzard frames.",
            "Added a scrollbar to the Widget system. It will now appear automatically in all modules that have enough options to require scrolling.",
            "Added a Minimap button to open KUI options directly.",
            "Fixed an issue in the Objective Tracker where the 'Scenario' header would display even when not inside an instance.",
            "Fixed KUI Tracker behavior in the CooldownManager. Potion and Warlock Healthstone cooldowns will now properly reset after a raid boss wipe/reset (when the appropriate conditions are met).",
            "KullThranUI is now officially available on GitHub! Future updates for CurseForge and Wago will be deployed from there, and Pull Requests will soon be enabled so the community can help improve translations.",
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
            "Restored reliable per-conversation whisper capture on secure-chat builds by mirroring Blizzard-rendered whisper lines into KUI history, including Battle.net conversations, without bypassing the selected whisper thread.",
            "Hardened Chat integration for protected message and channel data by avoiding unsafe native filter and channel-list mutations, preventing taint attribution and protected-table failures during PvP and other restricted chat dispatches.",
            "Reworked first-time setup for new characters with a dedicated starting-profile choice, allowing existing saved profiles to be selected or KUI defaults to be used without forcing every character onto the KullThranUI profile.",
            "Improved Installer and profile startup handling with stable per-character tracking, safer specialization-profile transitions, correct layout imports into the active profile, and more reliable continuation through conflict detection and setup.",
            "Expanded the Fonts & Colors page with live font previews, a separate Launcher and Options font, individual typography controls for major HUD, social, character, and inspection areas, and additional color controls for interface surfaces, action bars, progress displays, Chat, Armory, and Inspect.",
            "Reworked global font inheritance so modules that still follow the global font update together while explicitly customized areas preserve their own selection, with combat-safe deferred refreshes across the supported interface.",
            "Refined the main configuration window with an accent-colored KUI logo, a new resize grip, a slimmer navigation scrollbar, immediate minimap social-icon recoloring, and a scalable nine-slice background that preserves its proportions at preset and custom window sizes.",
            "Redesigned KUI Unlock Mode with a wider and cleaner sidebar, clearer active-element feedback, improved mover menus, direct access to profile importing, an animated opening logo, and an automatically retracting sidebar that remains available from the edge of the screen.",
            "Improved the in-game changelog window so its complete ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œDonÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢t show againÃƒÂ¢Ã¢â€šÂ¬Ã‚Â row is clickable, the current patch suppression state is restored correctly, and enabling or disabling the option is saved immediately.",
            "Hardened Chat against protected edit-box state changes during combat, preventing unsafe whisper, Battle.net, and chat-type mutations while retaining the normal input flow outside combat.",
            "Reduced Cooldown Manager background work by replacing continuous glow polling with coalesced event-driven updates, refreshing only affected bars when possible, and avoiding redundant transition passes once BlizzardÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢s Cooldown Viewer pools have stabilized.",
            "Improved Cooldown Manager trackers by hiding unavailable potion items, keeping owned potion ranks synchronized, stabilizing player and target frame anchoring around narrow CDM layouts, and making arena, battleground, specialization, and world-transition recovery more selective.",
            "Reworked centered horizontal Party and Arena layouts so the player remains in the intended middle position as the group fills, with a corrected bottom-center default position for horizontal Party Frames.",
            "Improved Party Frames range, phase, roster, aura, and encounter handling with more reliable out-of-range recovery, independent dispel indicators, properly layered AuraKit dispel effects, boss-frame activation during encounters, and fewer unnecessary full roster rebuilds while zoning.",
            "Refined Modern KUI group-interface skins with complete accent borders for selected LFG entries, clearer role-selection feedback, and a rebuilt Ready Check presentation with restored portraits, dedicated Ready and Not Ready buttons, consistent surfaces, and accent-aware artwork.",
            "Restored reliable first-run Installer startup for new users and brought back the visible \"Don't show again\" control, with synchronized login settings so the prompt can be disabled or re-enabled cleanly.",
            "Hardened Chat against protected and secret PvP payloads, preventing duplicated battleground system messages while preserving Blizzard's native message handling.",
            "Restored access to Blizzard's Group Management controls, including raid and world-marker tools, when KullThranUI Party Frames are active.",
            "Improved Party Frames during PvP and arena transitions with safer protected-unit handling and more reliable roster, role, raid-target, and aura refreshes.",
            "Fixed KullThranUI Bags tainting Blizzard's protected container click path, restoring item use, equipping, dragging, and background drops without UseContainerItem() forbidden-action errors.",
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
    ["5.0.6"] = {
        version = "5.0.6",
        published = "2026-09-13",
        sourceLabel = "Wago Addons",
        sourceUrl = CHANGELOG_WAGO_URL,
        notes = {
            "New Feature: Mythic+ History. A detailed Mythic+ history has been added to the Enhancements module, allowing you to track completed keys and view a keystone summary breakdown, including a damage meter to see who did the most DPS during the run. NOTE: The Mythic+ History will only display all party members after activating the submodule, as KullThranUI needs to start saving the runs internally from that point forward.",
            "Localization updates: Translations have been applied across all KullThranUI modules. Localization and compatibility have been expanded to cover 97% of the addon and its features. Added country flags to easily     distinguish languages. Fixed translation errors across several Widget elements and the Enhancements submodule.",
            "Skins module update: New visual style applied. Improved the visibility and overall readability of the reskinned default Blizzard frames.",
            "Added a scrollbar to the Widget system. It will now appear automatically in all modules that have enough options to require scrolling.",
            "Added a Minimap button to open KUI options directly.",
            "Fixed an issue in the Objective Tracker where the 'Scenario' header would display even when not inside an instance.",
            "Fixed KUI Tracker behavior in the CooldownManager. Potion and Warlock Healthstone cooldowns will now properly reset after a raid boss wipe/reset (when the appropriate conditions are met).",
            "KullThranUI is now officially available on GitHub! Future updates for CurseForge and Wago will be deployed from there, and Pull Requests will soon be enabled so the community can help improve translations.",
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
            "Restored reliable per-conversation whisper capture on secure-chat builds by mirroring Blizzard-rendered whisper lines into KUI history, including Battle.net conversations, without bypassing the selected whisper thread.",
            "Hardened Chat integration for protected message and channel data by avoiding unsafe native filter and channel-list mutations, preventing taint attribution and protected-table failures during PvP and other restricted chat dispatches.",
            "Reworked first-time setup for new characters with a dedicated starting-profile choice, allowing existing saved profiles to be selected or KUI defaults to be used without forcing every character onto the KullThranUI profile.",
            "Improved Installer and profile startup handling with stable per-character tracking, safer specialization-profile transitions, correct layout imports into the active profile, and more reliable continuation through conflict detection and setup.",
            "Expanded the Fonts & Colors page with live font previews, a separate Launcher and Options font, individual typography controls for major HUD, social, character, and inspection areas, and additional color controls for interface surfaces, action bars, progress displays, Chat, Armory, and Inspect.",
            "Reworked global font inheritance so modules that still follow the global font update together while explicitly customized areas preserve their own selection, with combat-safe deferred refreshes across the supported interface.",
            "Refined the main configuration window with an accent-colored KUI logo, a new resize grip, a slimmer navigation scrollbar, immediate minimap social-icon recoloring, and a scalable nine-slice background that preserves its proportions at preset and custom window sizes.",
            "Redesigned KUI Unlock Mode with a wider and cleaner sidebar, clearer active-element feedback, improved mover menus, direct access to profile importing, an animated opening logo, and an automatically retracting sidebar that remains available from the edge of the screen.",
            "Improved the in-game changelog window so its complete Ã¢â‚¬Å“DonÃ¢â‚¬â„¢t show againÃ¢â‚¬Â row is clickable, the current patch suppression state is restored correctly, and enabling or disabling the option is saved immediately.",
            "Hardened Chat against protected edit-box state changes during combat, preventing unsafe whisper, Battle.net, and chat-type mutations while retaining the normal input flow outside combat.",
            "Reduced Cooldown Manager background work by replacing continuous glow polling with coalesced event-driven updates, refreshing only affected bars when possible, and avoiding redundant transition passes once BlizzardÃ¢â‚¬â„¢s Cooldown Viewer pools have stabilized.",
            "Improved Cooldown Manager trackers by hiding unavailable potion items, keeping owned potion ranks synchronized, stabilizing player and target frame anchoring around narrow CDM layouts, and making arena, battleground, specialization, and world-transition recovery more selective.",
            "Reworked centered horizontal Party and Arena layouts so the player remains in the intended middle position as the group fills, with a corrected bottom-center default position for horizontal Party Frames.",
            "Improved Party Frames range, phase, roster, aura, and encounter handling with more reliable out-of-range recovery, independent dispel indicators, properly layered AuraKit dispel effects, boss-frame activation during encounters, and fewer unnecessary full roster rebuilds while zoning.",
            "Refined Modern KUI group-interface skins with complete accent borders for selected LFG entries, clearer role-selection feedback, and a rebuilt Ready Check presentation with restored portraits, dedicated Ready and Not Ready buttons, consistent surfaces, and accent-aware artwork.",
            "Restored reliable first-run Installer startup for new users and brought back the visible \"Don't show again\" control, with synchronized login settings so the prompt can be disabled or re-enabled cleanly.",
            "Hardened Chat against protected and secret PvP payloads, preventing duplicated battleground system messages while preserving Blizzard's native message handling.",
            "Restored access to Blizzard's Group Management controls, including raid and world-marker tools, when KullThranUI Party Frames are active.",
            "Improved Party Frames during PvP and arena transitions with safer protected-unit handling and more reliable roster, role, raid-target, and aura refreshes.",
            "Fixed KullThranUI Bags tainting Blizzard's protected container click path, restoring item use, equipping, dragging, and background drops without UseContainerItem() forbidden-action errors.",
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
}
-- AUTO-CHANGELOG:END

local function GetCurrentKUIVersion()
    local ver = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
        or KT.VERSION
        or "5.1.7"
    -- When loaded from the source tree without the release packager the TOC
    -- still contains the literal "@project-version@" token.  Fall back to the
    -- hardcoded release version so the changelog and options never display it.
    if ver and ver:find("@", 1, true) then
        ver = "5.1.6"
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
            local cleanNote = NormalizeNote(LText(note))
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

    return NormalizeVersionKey(changelogDb.lastDismissedVersion) == version
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

function KT:MarkChangelogVersionShown(version)
    if not self.db then
        return false
    end

    self.db.global = self.db.global or {}
    local currentVersion = NormalizeVersionKey(version or GetCurrentKUIVersion())
    if not currentVersion then
        return false
    end

    self.db.global.changelog = self.db.global.changelog or {}
    local changelogDb = self.db.global.changelog
    local rawChangelogDb = GetRawChangelogDB(true)

    local function UpdateStore(store)
        if type(store) == "table" then
            store.lastAutoShownVersion = currentVersion
        end
    end

    UpdateStore(changelogDb)
    if rawChangelogDb ~= changelogDb then
        UpdateStore(rawChangelogDb)
    end

    return true
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
            store.lastDismissedVersion = currentVersion
            store.dismissedVersions[currentVersion] = true
        else
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

    -- The Skins system's textured surface (KUISettingsSurface + dark wash)
    -- instead of a flat fill; the backdrop keeps only the accent border.
    if KT.ApplyTexturedSurface then
        if KT.AddBackdrop then KT:AddBackdrop(popup, 0, 0, 0, 0) end
        KT:ApplyTexturedSurface(popup, { background.r or 0.04, background.g or 0.04, background.b or 0.06, 1 })
    elseif KT.AddBackdrop then
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
    -- Over everything, the options window (FULLSCREEN_DIALOG) included.
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
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
    -- Opening the changelog counts as having shown this release once.
    -- Keep this separate from the optional "Don't show again" preference.
    if self.MarkChangelogVersionShown then
        self:MarkChangelogVersionShown(requestedVersion)
    end
    -- Above the options window and every piece of it, in its strata.
    local menu = KT.MenuPrincipal
    popup:SetFrameLevel(math.min(9000, ((menu and menu:GetFrameLevel()) or 0) + 500))
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
        frame.menuPerfDetails = string.format("%s %s | %s | %.0f FPS", LText("Mem"), memoryText, LText("Calibrating"), fps)
        frame.cpuUsageText:SetText(frame.menuPerfDetails)
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
        frame.menuPerfDetails = string.format("%s %.1f%% | %s %s | %s | %.0f FPS", LText("CPU"), cpuPercent or 0, LText("Mem"), memoryText, status, fps)
        frame.cpuUsageText:SetText(frame.menuPerfDetails)
    else
        frame.menuPerfDetails = string.format("%s %s | %s | %.0f FPS", LText("Mem"), memoryText, status, fps)
        frame.cpuUsageText:SetText(frame.menuPerfDetails)
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

-- Metrics belong to System Tuning; only sample while its readout is visible.
function KT:CreateAddonPerformanceReadout(parent, yOffset)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset or 0)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOffset or 0)
    frame:SetHeight(64)
    local r, g, b = GetMenuAccentColor()
    if self.AddBackdrop then self:AddBackdrop(frame, 0.025, 0.03, 0.045, 0.94) end
    if self.AddBorder then self:AddBorder(frame, r, g, b, 0.35) end
    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(self.FONT_PATH, 11, "OUTLINE")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(LText("KullThranUI") .. " | " .. LText("Performance"))
    title:SetTextColor(r, g, b, 1)
    frame.cpuUsageText = frame:CreateFontString(nil, "OVERLAY")
    frame.cpuUsageText:SetFont(self.FONT_PATH, 11, "OUTLINE")
    frame.cpuUsageText:SetPoint("TOPLEFT", 12, -32)
    frame.cpuUsageText:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
    frame.cpuUsageText:SetJustifyH("LEFT")
    frame.cpuUsageText:SetText(LText("Calibrating"))
    frame:HookScript("OnShow", function(self) StartMenuCpuUsageTicker(self) end)
    frame:HookScript("OnHide", function(self) StopMenuCpuUsageTicker(self) end)
    if frame:IsShown() then StartMenuCpuUsageTicker(frame) end
    return frame, 64
end

-- ============================================================================
-- Corrupted generated comment removed.
-- ============================================================================
-- MENU SCALE BEGIN
-- The window has one fixed size; only its scale changes. At menuScale 1 one
-- unit of the window is one physical pixel, so the painted skin stays sharp
-- at any UI scale (tests/menu_scale.lua loads this block on its own).
local MENU_W      = 1280
local MENU_H      = 900
local NAV_W       = 300
local HEADER_H    = 110
local TABS_H      = 16   -- gap under the header; page tab bars live in the page
local FOOTER_H    = 60
local CONTENT_PAD = 30
local TOP_MARGIN  = HEADER_H + TABS_H
local BOT_MARGIN  = FOOTER_H

local CONTENT_W = MENU_W - NAV_W - (CONTENT_PAD * 2)

local MENU_SCALE_MIN  = 0.5
local MENU_SCALE_MAX  = 1.5
local MENU_SCALE_STEP = 0.05
-- Share of the screen the window may cover at most, whatever the scale.
local MENU_SCREEN_FIT = 0.95

local function SnapMenuScale(value)
    value = tonumber(value) or 1
    value = math.floor(value / MENU_SCALE_STEP + 0.5) * MENU_SCALE_STEP
    return math.max(MENU_SCALE_MIN, math.min(MENU_SCALE_MAX, value))
end

-- 1440p is the reference look: physH / 1440 keeps the window the same share
-- of the screen on any display, never below 100%.
local function InitialMenuScale(physH)
    physH = tonumber(physH)
    if not physH or physH <= 0 then return 1 end
    return SnapMenuScale(math.max(1, math.min(physH / 1440, MENU_SCALE_MAX)))
end

local function ComputeMenuFrameScale(screenW, screenH, physW, physH, userScale)
    local pixelScale = 1
    if tonumber(screenW) and tonumber(physW) and physW > 0 then
        pixelScale = screenW / physW
    end
    local scale = pixelScale * (tonumber(userScale) or 1)
    if tonumber(screenW) and tonumber(screenH) and screenW > 0 and screenH > 0 then
        local fit = math.min(screenW * MENU_SCREEN_FIT / MENU_W, screenH * MENU_SCREEN_FIT / MENU_H)
        scale = math.min(scale, fit)
    end
    return scale
end

-- One-time move from the resizable window: drop the saved size and seed the
-- scale from the monitor. Everything else in the profile is left alone.
local function MigrateMenuSizeProfile(profile, physH)
    if type(profile) ~= "table" or profile.menuFixedSizeMigrated then return end
    profile.menuCustomWidth = nil
    profile.menuCustomHeight = nil
    profile.menuSizePreset = nil
    if profile.menuScale == nil then
        profile.menuScale = InitialMenuScale(physH)
    end
    profile.menuFixedSizeMigrated = true
end

local function GetMenuLayoutMetrics(frame)
    return {
        width = MENU_W,
        height = MENU_H,
        navWidth = NAV_W,
        topMargin = TOP_MARGIN,
        bottomMargin = BOT_MARGIN,
        contentInsetLeft = NAV_W + CONTENT_PAD,
        contentInsetRight = CONTENT_PAD,
        contentInsetTop = TOP_MARGIN,
        contentInsetBottom = BOT_MARGIN,
        contentWidth = CONTENT_W,
        navContentWidth = NAV_W - 10,
    }
end
-- MENU SCALE END

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

-- MENU SKIN ART BEGIN
-- The window background is the active skin's painted canvas (MenuSkins.lua):
-- base (never tinted), light (tinted with MenuSkins:LightColor()) and an
-- optional slowly pulsing glow. Every layer is 1440x1060 with the window
-- centred in it, so shadows and glows can spill 80px past the window edge.
-- Skins switch with a crossfade between two texture sets.
-- Kept in one block: Options.lua is close to Lua's 200-locals limit.
local ApplyMenuSkinArt, InstallMenuSkinArt
do
    local MENU_SKIN_ART_W = 1440
    local MENU_SKIN_ART_H = 1060
    local MENU_SKIN_FADE = 0.3
    local MENU_GLOW_PERIOD = 4
    local MENU_GLOW_MIN, MENU_GLOW_MAX = 0.6, 1.0

    local function CreateMenuSkinArtSet(frame, holder, sublevel)
        local set = { alpha = 1 }
        for _, layer in ipairs({ "base", "light", "glow" }) do
            local tex = holder:CreateTexture(nil, "BACKGROUND", nil, sublevel)
            tex:SetSize(MENU_SKIN_ART_W, MENU_SKIN_ART_H)
            tex:SetPoint("CENTER", frame, "CENTER", 0, 0)
            tex:Hide()
            set[layer] = tex
            sublevel = sublevel + 1
        end
        local fallback = holder:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        fallback:SetAllPoints(frame)
        fallback:Hide()
        set.fallback = fallback
        return set
    end

    local function MenuGlowEnabled()
        local profile = KT.db and KT.db.profile
        return not (profile and profile.menuGlow == false)
    end

    local function SetMenuSkinArtSetAlpha(set, alpha, pulse)
        set.alpha = alpha
        set.base:SetAlpha(alpha)
        set.light:SetAlpha(alpha * (set.lightAlpha or 1))
        set.glow:SetAlpha(alpha * (pulse or 1))
        set.fallback:SetAlpha(alpha)
    end

    local function PaintMenuSkinArtSet(set, skinId)
        local MS = KT.MenuSkins
        local files = MS:Files(skinId)
        if files and files.base then
            set.base:SetTexture(files.base)
            set.base:Show()
            if files.light then
                local r, g, b, a = MS:LightColor()
                set.light:SetTexture(files.light)
                set.light:SetVertexColor(r, g, b, 1)
                set.lightAlpha = a
                set.light:Show()
            else
                set.light:Hide()
            end
            if files.glow and MenuGlowEnabled() then
                local r, g, b = MS:LightColor()
                set.glow:SetTexture(files.glow)
                set.glow:SetVertexColor(r, g, b, 1)
                set.glow:Show()
            else
                set.glow:Hide()
            end
            set.fallback:Hide()
        else
            set.base:Hide()
            set.light:Hide()
            set.glow:Hide()
            set.fallback:SetColorTexture(MS:Color("card"))
            set.fallback:Show()
        end
        set.skinId = skinId
    end

    local function HideMenuSkinArtSet(set)
        set.base:Hide()
        set.light:Hide()
        set.glow:Hide()
        set.fallback:Hide()
    end

    local function MenuSkinArtOnUpdate(holder, elapsed)
        local frame = holder._menu
        local fade = frame._skinFade
        local pulse = 1
        holder._glowClock = (holder._glowClock or 0) + elapsed
        local wave = 0.5 + 0.5 * math.sin(holder._glowClock * 2 * math.pi / MENU_GLOW_PERIOD)
        pulse = MENU_GLOW_MIN + (MENU_GLOW_MAX - MENU_GLOW_MIN) * wave

        if fade then
            fade.elapsed = fade.elapsed + elapsed
            local t = math.min(1, fade.elapsed / MENU_SKIN_FADE)
            SetMenuSkinArtSetAlpha(fade.incoming, t, pulse)
            SetMenuSkinArtSetAlpha(fade.outgoing, 1 - t, pulse)
            if t >= 1 then
                HideMenuSkinArtSet(fade.outgoing)
                frame._skinFade = nil
            end
        else
            SetMenuSkinArtSetAlpha(frame._skinArt, 1, pulse)
        end

        if not frame._skinFade and not frame._skinArt.glow:IsShown() then
            holder:SetScript("OnUpdate", nil)
        end
    end

    function ApplyMenuSkinArt(frame, skinId, animate)
        if not (frame and frame._skinArtSets) then return end
        skinId = skinId or KT.MenuSkins:GetActive()
        local current = frame._skinArt
        local switching = animate and current and current.skinId and current.skinId ~= skinId

        if switching then
            local incoming = (current == frame._skinArtSets[1]) and frame._skinArtSets[2] or frame._skinArtSets[1]
            PaintMenuSkinArtSet(incoming, skinId)
            SetMenuSkinArtSetAlpha(incoming, 0)
            frame._skinFade = { incoming = incoming, outgoing = current, elapsed = 0 }
            frame._skinArt = incoming
        else
            -- Same skin: repaint in place. An animated call lets a running fade
            -- finish; an instant one (window just shown) ends it.
            if frame._skinFade and not animate then
                HideMenuSkinArtSet(frame._skinFade.outgoing)
                frame._skinFade = nil
            end
            current = current or frame._skinArtSets[1]
            PaintMenuSkinArtSet(current, skinId)
            if not frame._skinFade then SetMenuSkinArtSetAlpha(current, 1) end
            frame._skinArt = current
        end

        -- A painted canvas draws its own frame (and may cut corners), so the
        -- rectangular KT:AddBorder line only shows over the plain fallback.
        if frame.borderKT then
            frame.borderKT:SetShown(not frame._skinArt.base:IsShown())
        end

        local holder = frame._skinArtHolder
        if frame._skinFade or frame._skinArt.glow:IsShown() then
            holder:SetScript("OnUpdate", MenuSkinArtOnUpdate)
        else
            holder:SetScript("OnUpdate", nil)
        end
    end

    function InstallMenuSkinArt(frame)
        -- Its own holder: the canvas overhangs the window, so it must not sit in a
        -- clipping parent, and it stays below every window child.
        local holder = CreateFrame("Frame", nil, frame)
        holder:SetSize(MENU_SKIN_ART_W, MENU_SKIN_ART_H)
        holder:SetPoint("CENTER", frame, "CENTER", 0, 0)
        holder:SetFrameLevel(math.max(0, (frame:GetFrameLevel() or 1) - 5))
        holder._menu = frame
        frame._skinArtHolder = holder
        frame._skinArtSets = {
            CreateMenuSkinArtSet(frame, holder, -8),
            CreateMenuSkinArtSet(frame, holder, -4),
        }
        frame:HookScript("OnShow", function(self)
            ApplyMenuSkinArt(self, KT.MenuSkins:GetActive(), false)
        end)
        KT.MenuSkins:RegisterRepaint(function(skinId)
            if frame:IsShown() then
                ApplyMenuSkinArt(frame, skinId, true)
            end
        end)
        ApplyMenuSkinArt(frame, KT.MenuSkins:GetActive(), false)
    end
end
-- MENU SKIN ART END

local function UpdateMenuLayoutForSize(frame)
    if not frame then return end
    local metrics = GetMenuLayoutMetrics(frame)

    if frame._navHost then
        frame._navHost:ClearAllPoints()
        frame._navHost:SetWidth(metrics.navWidth)
        -- The sidebar starts right under the logo plate (it has no tab band).
        frame._navHost:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -HEADER_H)
        -- Reload UI keeps its place at the bottom-left, under the sidebar.
        frame._navHost:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 64)
    end

    if frame.scrollFrame then
        frame.scrollFrame:ClearAllPoints()
        frame.scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", metrics.contentInsetLeft, -(metrics.contentInsetTop + (frame._tabBandH or 0)))
        frame.scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -metrics.contentInsetRight, metrics.contentInsetBottom)
    end

    if frame.scrollChild then
        frame.scrollChild:SetWidth(metrics.contentWidth)
    end
    if frame._navContent then
        frame._navContent:SetWidth(metrics.navContentWidth)
    end

    if frame.searchBox then
        -- The search pill sits in the header, left of the scale control.
        frame.searchBox:ClearAllPoints()
        frame.searchBox:SetHeight(34)
        frame.searchBox:SetPoint("LEFT", frame, "TOPLEFT", metrics.contentInsetLeft + (frame._searchLeft or 170), -45)
        frame.searchBox:SetPoint("RIGHT", frame._searchHeaderRight, "LEFT", -18, 0)
    end
    if frame.RefreshNavigationScroll then
        frame:RefreshNavigationScroll()
    end
end

local function UpdateMenuBackgroundLayout(frame)
    -- The canvas has one size; a layout or theme pass only repaints it. A
    -- skin change on an open window crossfades.
    if frame and frame._skinArtSets then
        ApplyMenuSkinArt(frame, KT.MenuSkins:GetActive(), frame:IsShown())
    end
end

local function UpdateMenuThemeVisuals(menu)
    if not menu then return end

    local _, accent, background, text, muted = GetMenuPaletteColors()

    if KT.AddBorder then
        KT:AddBorder(menu, 0.03, 0.03, 0.04, 0.98)
    end

    for _, key in ipairs({ "_closeBtn", "_reloadBtn", "_resetBtn", "_discordBtn", "_closeFooterBtn" }) do
        if menu[key] and KT.Widgets and KT.Widgets.PaintPillButton then
            KT.Widgets:PaintPillButton(menu[key])
        end
    end
    if menu._pageTitle then
        menu._pageTitle:SetTextColor(text.r or 1, text.g or 1, text.b or 1, 1)
    end
    if menu._pageDesc then
        menu._pageDesc:SetTextColor(muted.r or 0.74, muted.g or 0.74, muted.b or 0.78, 1)
    end
    if menu._logoTex then
        if menu._logoTex.SetDesaturated then
            menu._logoTex:SetDesaturated(true)
        end
        menu._logoTex:SetVertexColor(accent.r or 1, accent.g or 1, accent.b or 1, 1)
    end
    if KT.ProfileTransferButton then KT.ProfileTransferButton.RefreshAll() end
    if menu.searchBox and menu.searchBox.RefreshSearchSkin then
        menu.searchBox:RefreshSearchSkin()
    end
    if menu._searchIcon and not (menu.searchBox and menu.searchBox.RefreshSearchSkin) then
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
	menu._versionText:SetText(string.format("|cff%02x%02x%02xv%s|r", vr, vg, vb, menu._versionValue or (KT.VERSION or "5.1.7")))
    end

    if menu._sizeSlider and menu._sizeSlider.Repaint then
        menu._sizeSlider:Repaint()
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
            if btn.UpdateVisual then btn:UpdateVisual() end
        end
    end

    UpdateMenuBackgroundLayout(menu)
end

local function GetSavedMenuScale()
    local profile = KT and KT.db and KT.db.profile
    return SnapMenuScale(profile and profile.menuScale or 1)
end

local function GetTargetMenuFrameScale(userScale)
    local physW, physH = GetPhysicalScreenSize()
    local screenW = UIParent and UIParent:GetWidth() or nil
    local screenH = UIParent and UIParent:GetHeight() or nil
    return ComputeMenuFrameScale(screenW, screenH, tonumber(physW), tonumber(physH), userScale)
end

-- Moves the window to a new scale while its centre stays where it is on
-- screen. Animated changes glide for MENU_SCALE_GLIDE seconds; a new target
-- mid-glide carries on from the current scale.
local MENU_SCALE_GLIDE = 0.15

local function PlaceMenuAtScale(frame, scale, screenX, screenY)
    frame:SetScale(scale)
    if screenX and screenY then
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", screenX / scale, screenY / scale)
    end
end

local function SetMenuScale(frame, userScale, animate)
    if not frame then return end
    userScale = SnapMenuScale(userScale)
    local profile = KT and KT.db and KT.db.profile
    if profile then profile.menuScale = userScale end

    local target = GetTargetMenuFrameScale(userScale)
    local from = frame:GetScale() or target
    local cx, cy = frame:GetCenter()
    local screenX, screenY = cx and cx * from, cy and cy * from

    if not animate or math.abs(from - target) < 0.0005 then
        frame._scaleGlide = nil
        PlaceMenuAtScale(frame, target, screenX, screenY)
        return
    end

    frame._scaleGlide = { from = from, to = target, elapsed = 0, x = screenX, y = screenY }
    if not frame._scaleGlider then
        frame._scaleGlider = CreateFrame("Frame", nil, frame)
    end
    frame._scaleGlider:SetScript("OnUpdate", function(self, elapsed)
        local glide = frame._scaleGlide
        if not glide then self:SetScript("OnUpdate", nil) return end
        glide.elapsed = glide.elapsed + elapsed
        local t = math.min(1, glide.elapsed / MENU_SCALE_GLIDE)
        local eased = 1 - (1 - t) * (1 - t)
        PlaceMenuAtScale(frame, glide.from + (glide.to - glide.from) * eased, glide.x, glide.y)
        if t >= 1 then
            frame._scaleGlide = nil
            self:SetScript("OnUpdate", nil)
        end
    end)
end

local function ApplyFixedMenuMetrics(frame)
    if not frame then return end
    local profile = KT and KT.db and KT.db.profile
    local _, physH = GetPhysicalScreenSize()
    MigrateMenuSizeProfile(profile, physH)
    frame:SetSize(MENU_W, MENU_H)
    frame:SetScale(GetTargetMenuFrameScale(GetSavedMenuScale()))
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

-- Module buttons in the minimap's button drawer (MinimapButton.lua): the
-- module pages, in menu order, that may get one. Only pages registered on this
-- client are offered.
KT.MODULE_LAUNCHER_PAGES = {
    "skins", "enhancements", "external", "unitframes", "partyframes", "nameplates", "armory",
    "inspectarmory", "actionbars", "cooldownmanager", "aurareminders", "buffs", "castbar",
    "resourcebars", "objectivetracker", "expbar", "minimap", "dragonriding", "teleportmenu",
    "chat", "bags", "tooltip", "cursor",
}

-- The page's name and menu icon for its drawer button, or nil when the page
-- is not registered (the module is not on this client).
function KT:GetModuleLauncher(pageId)
    for _, page in ipairs(ns.pages) do
        if page.id == pageId then
            return {
                id = pageId,
                label = LocalizeText(page.label),
                icon = ICON_PATH .. (ns.PAGE_ICON_MAP[pageId] or "Config") .. ".png",
            }
        end
    end
    return nil
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
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, 40)
    frame:SetPoint("TOPLEFT", x, y)
    -- Layered card (Widgets.lua): rounded front, back plate that lights on
    -- hover, and a header with a pill and the title in normal case.
    KT.Widgets:StyleCard(frame, { title = title })

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 0, -KT.Widgets.CARD_HEADER_H)
    content:SetWidth(width)
    content:SetHeight(1)
    content.rowCounter = 0
    content._ktBlockContent = true

    return frame, content
end

local function FinalizeOptionBlock(frame, content, contentHeight)
    local headerH = KT.Widgets.CARD_HEADER_H
    local bottomPad = 10
    local total = headerH + contentHeight + bottomPad
    content:SetHeight(contentHeight)
    frame:SetHeight(total)
    return total
end

local function BeginOptionBlocks(sc, startY, opts)
    -- Room for the card back plates that peek out (and spread on hover).
    local gap = (opts and opts.gap) or 18
    local columnGap = (opts and opts.columnGap) or 16
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
    return frame, content, totalH
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
    -- The pinned preview must sit above every scrolled option widget. Those
    -- nest several frame levels deep inside the scroll child, so the old fixed
    -- +20 let them draw over (and through) the preview while scrolling.
    local sf = menu.scrollFrame
    if sf then
        host:SetFrameLevel(math.min((sf:GetFrameLevel() or 1) + 200, 9000))
    end
    host:Show()

    frame:SetParent(host)
    frame:SetFrameStrata(host:GetFrameStrata())
    frame:SetFrameLevel(host:GetFrameLevel() + 1)
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
            variant = "moduleProfile",
            text = LText("Export"),
            onClick = function()
                local exportString, err = profileMod:ExportPageProfileString(pageId)
                if not exportString then
                    if KT and KT.Print then KT:Print(err or LText("Could not export the module.")) end
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
            variant = "moduleProfile",
            text = LText("Import"),
            onClick = function()
                profileMod:ShowImportPopup(
                    LText("Import") .. " - " .. LText(info.label),
                    LText("|cffff5555Only this module's settings will be replaced. Other modules contained in the string will be ignored.|r"),
                    function(text)
                        local ok, err = profileMod:ImportPageProfileString(pageId, text)
                        if not ok then
                            error(err or LText("Could not import the module."), 0)
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

local function CreateCategoryOverviewModuleButton(parent, menu, page, x, y, width, height, index)
    -- Gradient-border module card (Widgets.lua W:ModuleCard).
    local iconTexture, iconName = GetOverviewModuleIcon(page.id)
    local style = ns.PAGE_ICON_STYLE_MAP[page.id] or {}
    local btn = KT.Widgets:ModuleCard(parent, {
        width = width,
        height = height,
        icon = iconTexture,
        iconCoords = style.texCoord,
        iconKeep = ns.MENU_ICON_PRESERVE_COLOR[iconName or ""],
        title = LText(page.label or page.id),
        description = LText(ns.MODULE_DESCRIPTION_MAP[page.id] or "Open this module's configuration options."),
        button = LText("Open"),
        index = string.format("%02d", index or 0),
        onClick = function() LoadPage(menu, page.id) end,
    })
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    btn._iconName = iconName
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

    -- Starfield header card (Widgets.lua W:StarHero).
    local hero = KT.Widgets:StarHero(sc, {
        width = contentWidth,
        height = 110,
        eyebrow = LText("MODULE CATEGORY"),
        title = LText(category.label),
        subtitle = LText(ns.CATEGORY_DESCRIPTION_MAP[categoryId] or "Choose a module to open its configuration."),
    })
    hero:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)

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

    local gap = 16
    local columns = (contentWidth >= 820 and 3) or (contentWidth >= 540 and 2) or 1
    local cardWidth = math.floor((contentWidth - (gap * (columns - 1))) / columns)
    local cardHeight = 200
    local rowGap = 18

    for index, page in ipairs(categoryPages) do
        local column = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        CreateCategoryOverviewModuleButton(sc, menu, page, 10 + column * (cardWidth + gap), y + row * (cardHeight + rowGap), cardWidth, cardHeight, index)
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
    if menu._tabBand then menu._tabBand:Clear() end
    if menu.SetPageHeading then
        menu:SetPageHeading(LText(CATEGORY_BY_ID[categoryId].label), LText(ns.CATEGORY_DESCRIPTION_MAP[categoryId] or ""))
    end
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

    for _, btn in pairs(ns.navButtons) do
        if btn.UpdateVisual then btn:UpdateVisual() end
    end

    local sc = menu.scrollChild
    ClearStickyPreview(menu)
    if menu._tabBand then menu._tabBand:Clear() end
    if menu.SetPageHeading then
        local label, description = pageId, nil
        for _, page in ipairs(ns.pages) do
            if page.id == pageId then
                label, description = page.label or page.id, page.description
                break
            end
        end
        local category = CATEGORY_BY_ID[categoryId]
        description = description or ns.MODULE_DESCRIPTION_MAP[pageId] or (category and category.label) or ""
        menu:SetPageHeading(LText(label), LText(description))
    end
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
    -- Blizzard popups (reload, confirmations) live in DIALOG, below this
    -- window: lift them over it while the menu is open.
    for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
        local popup = _G["StaticPopup" .. i]
        if popup and popup.HookScript then
            popup:HookScript("OnShow", function(self)
                self:SetFrameStrata(f:IsShown() and "TOOLTIP" or "DIALOG")
            end)
        end
    end
    f:SetMovable(true)
    f:SetResizable(false)
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

    InstallMenuSkinArt(f)
    -- Alias retained for the existing background-ready checks.
    f._customBg = f._skinArt.base

    local logoTex = f:CreateTexture(nil, "ARTWORK", nil, 1)
    logoTex:SetSize(80, 80)
    logoTex:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -14)
    logoTex:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png")
    f._logoTex = logoTex

    -- Corrupted generated comment removed.
    local closeBtn = KT.Widgets:PillButton(f, "", {
        width = 30, height = 30, radius = 8, iconSize = 14,
        icon = ICON_PATH .. "kui-close.png",
        onClick = function() KT:OpenMenu() end,
    })
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -26, -30)
    f._closeBtn = closeBtn

    -- Window scale: the window keeps one size and this slider zooms it,
    -- MENU_SCALE_MIN..MAX in MENU_SCALE_STEP steps. Dragging only previews the
    -- percentage; the scale is applied when the drag ends. The mouse wheel
    -- steps one notch and applies at once.
    local accentR, accentG, accentB = GetMenuAccentColor()
    -- One header line, vertically centred on the close button like the
    -- search box (which anchors its right edge to this group, so the two
    -- must share that centre): "Window Scale  [slider]  100%  X".
    -- The percentage is an edit box: type a value and press Enter.
    local sizeValue = CreateFrame("EditBox", nil, f)
    sizeValue:SetFont(KT.FONT_PATH or STANDARD_TEXT_FONT, 11, "")
    sizeValue:SetSize(42, 18)
    sizeValue:SetJustifyH("RIGHT")
    sizeValue:SetTextInsets(2, 3, 0, 0)
    sizeValue:SetAutoFocus(false)
    sizeValue:SetMaxLetters(5)
    sizeValue:SetPoint("RIGHT", closeBtn, "LEFT", -12, 0)
    sizeValue:SetFrameLevel(closeBtn:GetFrameLevel())
    local sizeValueLine = sizeValue:CreateTexture(nil, "BORDER")
    sizeValueLine:SetPoint("BOTTOMLEFT", 0, 0)
    sizeValueLine:SetPoint("BOTTOMRIGHT", 0, 0)
    sizeValueLine:SetHeight(1)
    f._sizeValue = sizeValue

    local scaleMinPct = math.floor(MENU_SCALE_MIN * 100 + 0.5)
    local scaleMaxPct = math.floor(MENU_SCALE_MAX * 100 + 0.5)
    local scaleStepPct = math.floor(MENU_SCALE_STEP * 100 + 0.5)

    local sizeSlider = CreateFrame("Slider", nil, f)
    sizeSlider:SetOrientation("HORIZONTAL")
    sizeSlider:SetSize(80, 16)
    sizeSlider:SetPoint("RIGHT", sizeValue, "LEFT", -8, 0)
    sizeSlider:SetFrameLevel(closeBtn:GetFrameLevel())
    sizeSlider:SetMinMaxValues(scaleMinPct, scaleMaxPct)
    sizeSlider:SetValueStep(scaleStepPct)
    if sizeSlider.SetObeyStepOnDrag then sizeSlider:SetObeyStepOnDrag(true) end
    sizeSlider:EnableMouseWheel(true)

    local sizeTrack = KT.Widgets:RoundRect(sizeSlider, "BACKGROUND", 0, 2)
    sizeTrack:SetPoint("LEFT", sizeSlider, "LEFT", 0, 0)
    sizeTrack:SetPoint("RIGHT", sizeSlider, "RIGHT", 0, 0)
    sizeTrack:SetHeight(4)
    sizeTrack:SetColor(KT.MenuSkins:Color("controlTrack"))
    local sizeFill = KT.Widgets:RoundRect(sizeSlider, "ARTWORK", 0, 2)
    sizeFill:SetPoint("LEFT", sizeSlider, "LEFT", 0, 0)
    sizeFill:SetHeight(4)
    local sizeThumb = sizeSlider:CreateTexture(nil, "OVERLAY")
    sizeThumb:SetTexture(KT.MenuSkins.TEXTURE_PATH .. "round_disc")
    sizeThumb:SetSize(12, 12)
    sizeSlider:SetThumbTexture(sizeThumb)
    local sizeCaption = f:CreateFontString(nil, "OVERLAY")
    sizeCaption:SetFont(KT.FONT_PATH or STANDARD_TEXT_FONT, 11, "")
    sizeCaption:SetPoint("RIGHT", sizeSlider, "LEFT", -10, 0)
    sizeCaption:SetText(LText("Window Scale"))
    f._sizeCaption = sizeCaption

    local function PaintSize(value)
        local w = sizeSlider:GetWidth()
        local t = ((value or scaleMinPct) - scaleMinPct) / (scaleMaxPct - scaleMinPct)
        sizeFill:SetWidth(math.max(0.01, w * math.max(0, math.min(1, t))))
        if not sizeValue:HasFocus() then
            sizeValue:SetText(string.format("%d%%", value or 100))
        end
    end
    function sizeSlider:Repaint()
        local r, g, b = GetMenuAccentColor()
        local _, _, _, _, muted = GetMenuPaletteColors()
        sizeFill:SetColor(r, g, b, 1)
        sizeTrack:SetColor(KT.MenuSkins:Color("controlTrack"))
        sizeThumb:SetVertexColor(1, 1, 1, 1)
        sizeValue:SetTextColor(muted.r or 0.74, muted.g or 0.74, muted.b or 0.78, 1)
        sizeValueLine:SetColorTexture(r, g, b, sizeValue:HasFocus() and 1 or 0.35)
        sizeCaption:SetTextColor(muted.r or 0.74, muted.g or 0.74, muted.b or 0.78, 1)
        PaintSize(math.floor(self:GetValue() + 0.5))
    end
    function sizeSlider:Sync()
        self._ktSyncing = true
        self:SetValue(math.floor(GetSavedMenuScale() * 100 + 0.5))
        self._ktSyncing = nil
        PaintSize(math.floor(self:GetValue() + 0.5))
    end
    local function ApplySliderScale()
        SetMenuScale(f, sizeSlider:GetValue() / 100, true)
    end
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        PaintSize(math.floor(value + 0.5))
        if self._ktSyncing or self._ktDragging then return end
        ApplySliderScale()
    end)
    sizeSlider:SetScript("OnMouseDown", function(self) self._ktDragging = true end)
    sizeSlider:SetScript("OnMouseUp", function(self)
        self._ktDragging = nil
        ApplySliderScale()
    end)
    sizeSlider:SetScript("OnMouseWheel", function(self, delta)
        local step = delta > 0 and scaleStepPct or -scaleStepPct
        self:SetValue(math.max(scaleMinPct, math.min(scaleMaxPct, self:GetValue() + step)))
    end)
    f:HookScript("OnShow", function() sizeSlider:Sync() end)
    f._sizeSlider = sizeSlider
    sizeValue:SetScript("OnEditFocusGained", function(self)
        self:SetText(tostring(math.floor(sizeSlider:GetValue() + 0.5)))
        self:HighlightText()
        sizeSlider:Repaint()
    end)
    sizeValue:SetScript("OnEditFocusLost", function()
        sizeSlider:Repaint()
    end)
    sizeValue:SetScript("OnEnterPressed", function(self)
        local typed = tonumber((self:GetText() or ""):match("%d+"))
        self:ClearFocus()
        if typed then
            local value = math.max(scaleMinPct, math.min(scaleMaxPct, math.floor(typed + 0.5)))
            if math.floor(sizeSlider:GetValue() + 0.5) ~= value then
                sizeSlider:SetValue(value) -- OnValueChanged applies the scale
            end
        end
        sizeSlider:Repaint()
    end)
    sizeValue:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sizeSlider:Sync()
    sizeSlider:Repaint()
    local presetAnchor = sizeCaption

    f._searchHeaderRight = presetAnchor

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

    -- Wide search pill on the title line, from after the page title to the
    -- scale control; the description runs underneath at full width.
    local searchBox = CreateFrame("EditBox", nil, f)
    searchBox:SetHeight(34)
    searchBox:SetPoint("LEFT", f, "TOPLEFT", NAV_W + CONTENT_PAD + 170, -45)
    searchBox:SetPoint("RIGHT", f._searchHeaderRight, "LEFT", -18, 0)
    searchBox:SetFont(KT.FONT_PATH, 12, "OUTLINE")
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(44, 42, 0, 0)
    KT:StyleOptionsSearch(searchBox, GetMenuAccentColor)

    local searchIcon = searchBox:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(21, 21)
    searchIcon:SetPoint("LEFT", searchBox, "LEFT", 13, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetVertexColor(accentR, accentG, accentB, 1)
    f._searchIcon = searchIcon

    local searchHint = searchBox:CreateFontString(nil, "OVERLAY")
    searchHint:SetFont(KT.FONT_PATH, 12, "OUTLINE")
    searchHint:SetTextColor(accentR, accentG, accentB, 0.55)
    searchHint:SetPoint("LEFT", 44, 0)
    searchHint:SetText(LocalizeText("Search..."))
    f._searchHint = searchHint
    searchBox:BindSearchParts(searchHint, searchIcon)

    local searchClear = CreateFrame("Button", nil, searchBox)
    searchClear:SetSize(24, 24)
    searchClear:SetPoint("RIGHT", searchBox, "RIGHT", -12, 0)
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
    searchDropdown:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -6)
    searchDropdown:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -6)
    searchDropdown:SetHeight(240)
    -- Above every page widget (cards and previews raise their own levels).
    searchDropdown:SetFrameStrata("TOOLTIP")
    searchDropdown:SetFrameLevel((f:GetFrameLevel() or 1) + 60)
    searchDropdown:EnableMouse(true)
    searchDropdown:Hide()
    if KT.AddBackdrop then KT:AddBackdrop(searchDropdown, 0.05, 0.05, 0.06, 0.98) end
    if KT.AddBorder then KT:AddBorder(searchDropdown, accentR, accentG, accentB, 0.8) end

    local dropdownScroll = CreateFrame("ScrollFrame", "KT_SearchScroll", searchDropdown)
    dropdownScroll:SetPoint("TOPLEFT", 4, -4)
    dropdownScroll:SetPoint("BOTTOMRIGHT", -20, 4)
    
    local dropdownContent = CreateFrame("Frame", nil, dropdownScroll)
    dropdownContent:SetSize(math.max(200, (searchDropdown:GetWidth() or 0) - 24), 1)
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
        dropdownContent:SetWidth(searchDropdown:GetWidth() - 24)
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
            searchHint:SetShown(not self:HasFocus())
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
    
    local function SubmitSearch()
        searchBox:SetFocus()
        UpdateSearchResults(searchBox:GetText())
    end
    searchBox:SetScript("OnEnterPressed", SubmitSearch)
    f.searchBox = searchBox

    -- Page heading: the module (or category) name and a one-line summary.
    local pageTitle = f:CreateFontString(nil, "OVERLAY")
    pageTitle:SetFont(KT.FONT_PATH, 24, "")
    pageTitle:SetPoint("LEFT", f, "TOPLEFT", NAV_W + CONTENT_PAD, -45)
    pageTitle:SetWidth(320)
    pageTitle:SetJustifyH("LEFT")
    pageTitle:SetWordWrap(false)
    f._pageTitle = pageTitle

    local pageDesc = f:CreateFontString(nil, "OVERLAY")
    pageDesc:SetFont(KT.FONT_PATH, 12, "")
    -- Its own line under the title row, clear of the search pill.
    pageDesc:SetPoint("TOPLEFT", f, "TOPLEFT", NAV_W + CONTENT_PAD, -73)
    pageDesc:SetWidth(CONTENT_W)
    pageDesc:SetJustifyH("LEFT")
    pageDesc:SetJustifyV("TOP")
    pageDesc:SetWordWrap(true)
    if pageDesc.SetMaxLines then pageDesc:SetMaxLines(1) end
    f._pageDesc = pageDesc

    -- The search pill starts right after the title, so it is as wide as the
    -- title allows (the title is cut with "..." past 320px).
    function f:SetPageHeading(title, description)
        pageTitle:SetWidth(320)
        pageTitle:SetText(title or "")
        pageDesc:SetText(description or "")
        local titleW = math.min(320, math.ceil(pageTitle:GetStringWidth() or 0))
        pageTitle:SetWidth(math.max(1, titleW))
        self._searchLeft = math.max(130, titleW + 32)
        UpdateMenuLayoutForSize(self)
    end

    -- Corrupted generated comment removed.
    local titleTex = f:CreateFontString(nil, "OVERLAY")
    titleTex:SetFont(KT.FONT_PATH, 13, "OUTLINE")
    local verColor = string.format("%02x%02x%02x", accentR*255, accentG*255, accentB*255)
	titleTex:SetText("|cff" .. verColor .. "v" .. (KT.VERSION or "5.1.7") .. "|r")
    titleTex:SetPoint("TOPLEFT", f, "TOPLEFT", 94, -68)
    titleTex:SetWidth(190)
    titleTex:SetJustifyH("LEFT")
    f._versionText = titleTex
	f._versionValue = KT.VERSION or "5.1.7"

    -- Corrupted generated comment removed.
    local nav = CreateFrame("Frame", nil, f)
    nav:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
    nav:SetWidth(NAV_W)
    nav:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -HEADER_H)
    nav:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 64)
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
                f._navContent:SetWidth(math.max(180, (nav:GetWidth() or NAV_W) - 20))
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
    local CATEGORY_BTN_GAP = 8
    local MODULE_BTN_H = 42
    local MODULE_BTN_GAP = 4

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

    -- Category rows: the category icon in a rounded chip, the name and a
    -- chevron that points down while open and left while folded. An open
    -- category keeps a faint band; hover lights a halo and slides the row.
    local function CreateCategoryButton(category)
        local btn = CreateFrame("Button", nil, navContent)
        local categoryId = category.id
        btn.categoryId = categoryId
        btn:SetHeight(CATEGORY_BTN_H)
        KT.Widgets:NavChip(btn, { inset = 6, right = 8, radius = 6, card = "shine", chip = { w = 48, h = 40, x = 8, radius = 9 } })

        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(48, 32)
        icon:SetPoint("CENTER", btn._chipKT.box, "CENTER", 0, 0)
        icon:SetTexture(CATEGORY_ICON_PATH .. category.icon .. ".png")
        btn._iconName = category.icon
        btn.ico = icon

        local arrow = btn:CreateTexture(nil, "ARTWORK")
        arrow:SetSize(12, 12)
        arrow:SetPoint("RIGHT", btn, "RIGHT", -18, 0)
        arrow:SetTexture(ICON_PATH .. "EnhancedFriendList\\ArrowDown.png")
        btn.arrow = arrow
        btn._chevronKT = arrow

        local label = btn:CreateFontString(nil, "OVERLAY")
        label:SetFont(KT.FONT_PATH, 13, "")
        label:SetText(LText(category.label))
        label:SetPoint("LEFT", btn._chipKT.box, "RIGHT", 12, 0)
        label:SetPoint("RIGHT", arrow, "LEFT", -6, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        btn.lbl = label

        btn.UpdateVisual = function(self)
            local isOpen = IsCategoryOpen(categoryId)
            local isActiveCategory = GetActiveCategoryId() == categoryId
            local hovered = self:IsMouseOver()
            -- The shine row paints the label, chevron and icon in accent tints.
            self._navLabelKT, self._navArrowKT, self._navIconKT = self.lbl, self.arrow, self.ico
            self._navIconKeep = ns.MENU_ICON_PRESERVE_COLOR[self._iconName or ""]
            if self._navIconKeep then ns.PaintMenuNavIcon(self, isOpen or isActiveCategory, hovered) end
            self.arrow:SetRotation(isOpen and 0 or (-math.pi / 2))
            KT.Widgets:NavChipState(self, (isOpen or isActiveCategory) and "open" or "rest", hovered)
        end

        local function ToggleCategory()
            f:SetOpenCategory(categoryId, nil, false)
            LoadCategoryOverview(f, categoryId)
        end

        btn:SetScript("OnEnter", function(self) self:UpdateVisual() end)
        btn:SetScript("OnLeave", function(self) self:UpdateVisual() end)
        btn:SetScript("OnClick", ToggleCategory)

        btn:UpdateVisual()
        return btn
    end

    -- Module rows: icon in a rounded chip and the name; the active one gets a
    -- warm band, an accent icon and a 3px accent bar at its left edge.
    local function CreateModuleButton(page, categoryId)
        local btn = CreateFrame("Button", nil, navContent)
        local pageId = page.id
        btn.pageId = pageId
        btn.categoryId = categoryId
        btn.isModuleButton = true
        btn:SetHeight(MODULE_BTN_H)
        KT.Widgets:NavChip(btn, { inset = 18, right = 8, radius = 6, barHeight = 20, card = "shine", chip = { w = 40, h = 30, x = 8, radius = 8 } })

        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(39, 26)
        icon:SetPoint("CENTER", btn._chipKT.box, "CENTER", 0, 0)
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
        label:SetFont(KT.FONT_PATH, 13, "")
        label:SetText(LText(page.label))
        label:SetPoint("LEFT", btn._chipKT.box, "RIGHT", 11, 0)
        label:SetPoint("RIGHT", btn, "RIGHT", -24, 0)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)
        btn.lbl = label

        btn.UpdateVisual = function(self)
            local isActive = ns.activePageId == pageId
            local hovered = self:IsMouseOver()
            self._navLabelKT, self._navIconKT = self.lbl, self.ico
            self._navIconKeep = ns.MENU_ICON_PRESERVE_COLOR[self._iconName or ""]
            if self._navIconKeep then ns.PaintMenuNavIcon(self, isActive, hovered) end
            KT.Widgets:NavChipState(self, isActive and "active" or "rest", hovered)
        end

        btn:SetScript("OnEnter", function(self) self:UpdateVisual() end)
        btn:SetScript("OnLeave", function(self) self:UpdateVisual() end)
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

    -- Reload UI and Discord stay at the bottom-left, under the sidebar; the
    -- footer under the content holds Reset Profile and Close (the one
    -- primary button), clear of the claw marks painted at the bottom-right cut.
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", NAV_W, 10)
    footer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 10)
    footer:SetHeight(FOOTER_H - 10)
    footer:SetFrameLevel((f:GetFrameLevel() or 1) + 14)
    f._footer = footer

    local reloadBtn = KT.Widgets:PillButton(f, LText("Reload UI"), { width = 178, height = 34, ringAlways = true, onClick = ReloadUI })
    reloadBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 18, 18)
    reloadBtn:SetFrameLevel((f:GetFrameLevel() or 1) + 14)
    f._reloadBtn = reloadBtn

    local discordBtn = KT.Widgets:PillButton(f, "", {
        width = 34, height = 34, iconSize = 18, icon = ICON_PATH .. "discord-2.png", onClick = ShowDiscordPopup,
    })
    discordBtn:SetPoint("LEFT", reloadBtn, "RIGHT", 8, 0)
    discordBtn:SetFrameLevel((f:GetFrameLevel() or 1) + 14)
    f._discordBtn = discordBtn

    local closeFooterBtn = KT.Widgets:PillButton(footer, LText("Close"), {
        width = 124, height = 34, primary = true, onClick = function() KT:OpenMenu() end,
    })
    closeFooterBtn:SetPoint("RIGHT", footer, "RIGHT", -80, 0)
    f._closeFooterBtn = closeFooterBtn

    local resetBtn = KT.Widgets:PillButton(footer, LText("Reset Profile"), { width = 124, height = 34, danger = true, ringAlways = true, onClick = ResetConfirm })
    resetBtn:SetPoint("RIGHT", closeFooterBtn, "LEFT", -10, 0)
    f._resetBtn = resetBtn

    -- Fixed tab bar under the header: an options page puts its top tab bar
    -- here (AddPageSubTabBar), it stays put while the page scrolls, and the
    -- page content moves down to make room for it.
    local tabBand = CreateFrame("Frame", nil, f)
    tabBand:SetPoint("TOPLEFT", f, "TOPLEFT", NAV_W + CONTENT_PAD, -(HEADER_H + 15))
    tabBand:SetSize(CONTENT_W, 40)
    tabBand:SetFrameLevel((f:GetFrameLevel() or 1) + 14)
    function tabBand:SetUsed(used)
        f._tabBandH = used and 54 or 0
        UpdateMenuLayoutForSize(f)
    end
    function tabBand:Clear()
        for _, child in ipairs({ self:GetChildren() }) do
            child:Hide()
            child:SetParent(ns.OPTIONS_RECYCLER)
        end
        self:SetUsed(false)
    end
    f._tabBand = tabBand

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
    -- The outer preview frame wears the card (Widgets.lua W:PreviewCard) in
    -- place of its square backdrop and accent border.
    if KT.Widgets and KT.Widgets.PreviewCard then
        local glass = KT.Widgets:PreviewCard(previewHost)
        -- Options scroll underneath the pinned preview: it must not show them through.
        if glass then glass.opaque = true end
    end
    KT._scrollFrame = sf
    f.RefreshTheme = function(self)
        UpdateMenuThemeVisuals(self)
        -- Skinned widgets (and the canvas) listen to MenuSkins.
        if KT.MenuSkins then KT.MenuSkins:Repaint() end
    end
    f:SetScript("OnSizeChanged", function(self)
        UpdateMenuLayoutForSize(self)
        UpdateMenuBackgroundLayout(self)
        UpdateStickyPreviewLayout(self)
        RequestMenuPageReflow(self)
    end)
    f:HookScript("OnShow", function(self)
        -- The menu can be hidden by Unlock Mode and shown again without
        -- reloading the active page. Refresh the shortcut here so its
        -- selected state always reflects the real Unlock Mode state.
        if self._ktUnlockShortcut and self._ktUnlockShortcut.UpdateVisual then
            self._ktUnlockShortcut:UpdateVisual()
        end
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
    ApplyFixedMenuMetrics(f)
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
    if not (KT and KT.IsUIScaleManaged and KT:IsUIScaleManaged()) then
        return
    end
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
            ApplyFixedMenuMetrics(f)
            f:Show()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, CloseGameMenuForKUIOptions)
            end

            if UIParent and KT._scaleLockValue and KT.IsUIScaleManaged and KT:IsUIScaleManaged()
                and not (KT.db and KT.db.profile and KT.db.profile.useBlizzardUIScale) then
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
    -- NOTE: do NOT use geterrorhandler() here. It logs the error but returns
    -- nil, so `error(err)` below re-raises nil and the real message is lost --
    -- all the user ever sees is "UNKNOWN ERROR". Return a real string instead
    -- and append the original stack, so the failure is actually diagnosable.
    end, function(menuErr)
        local message = (type(menuErr) == "string") and menuErr or tostring(menuErr)
        if type(debugstack) == "function" then
            message = message .. "\n" .. debugstack(2, 3, 3)
        end
        return message
    end)

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

-- Each tab carries its own icon (media\\icons\\GeneralTabs, used nowhere
-- else). Quick Setup is no longer a tab: its layout installers live in the
-- Profiles tab (BuildProfilesTab).
local GENERAL_TAB_ICON = ICON_PATH .. "GeneralTabs\\"
local GENERAL_SUBTABS = {
    { id = "general", label = "General", icon = GENERAL_TAB_ICON .. "General.tga" },
    { id = "kuimove", label = "KUIMove", icon = GENERAL_TAB_ICON .. "KUIMove.tga" },
    { id = "disablemodules", label = "Manage Modules", icon = GENERAL_TAB_ICON .. "DisableModules.tga" },
    { id = "compatibility", label = "Compatibility", icon = GENERAL_TAB_ICON .. "Compatibility.tga" },
    { id = "profiles", label = "Profiles", icon = GENERAL_TAB_ICON .. "Profiles.tga" },
    { id = "fontscolors", label = "Fonts & Colors", icon = GENERAL_TAB_ICON .. "FontsColors.tga" },
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
    -- A bar at the top of an options page goes to the fixed band under the
    -- header (W:PageTabs); one further down, or too wide for one row, stays
    -- in the page as shared nav tabs (KullThranUI/NavTabs.lua).
    local menu = KT.MenuPrincipal
    local band = menu and menu._tabBand
    if band and parent == menu.scrollChild and (tonumber(yOffset) or 0) >= -16 then
        local bar = KT.Widgets:PageTabs(band, tabs, selectedId, onSelect, { localize = LText, width = band:GetWidth() })
        if bar then
            bar:SetPoint("TOPLEFT", band, "TOPLEFT", 0, 0)
            band:SetUsed(true)
            return bar, 0
        end
    end
    return KT.NavTabs.CreateBar(parent, yOffset, tabs, selectedId, onSelect, {
        localize = LText,
        height = 34,
        gap = 6,
        fontSize = 11,
    })
end

function KT.AddOptionsSubTabBar(parent, yOffset, tabs, selectedId, onSelect)
    return AddPageSubTabBar(parent, yOffset, tabs, selectedId, onSelect)
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
    local displayName = (KT.GetProfileDisplayName and KT:GetProfileDisplayName(currentProfileName))
        or currentProfileName or LText("Unknown")
    local height = 104
    -- Gap under the block header, so the card does not touch it.
    local topGap = 10

    -- Same starfield card as the General page header ("Interface Control
    -- Center", Widgets.lua W:StarHero), with the spec icon on its left.
    local hero = KT.Widgets:StarHero(parent, {
        width = parent:GetWidth() - 20,
        height = height,
        eyebrow = LText("CURRENT PROFILE"),
        title = displayName,
        subtitle = LTextFmt("Spec: %s", specName or LText("Unknown")) .. "     "
            .. LTextFmt("Assigned: %s", assignedProfileName or LText("None")),
    })
    hero:SetPoint("TOPLEFT", 10, yOffset - topGap)

    local top = CreateFrame("Frame", nil, hero)
    top:SetAllPoints(hero)
    top:SetFrameLevel(((hero._textKT and hero._textKT:GetFrameLevel()) or hero:GetFrameLevel()) + 2)
    local r, g, b = GetMenuAccentColor()
    local iconBorder = top:CreateTexture(nil, "ARTWORK", nil, 0)
    iconBorder:SetSize(48, 48)
    iconBorder:SetPoint("LEFT", hero, "LEFT", 18, 0)
    iconBorder:SetColorTexture(r, g, b, 0.85)
    local iconBack = top:CreateTexture(nil, "ARTWORK", nil, 1)
    iconBack:SetPoint("TOPLEFT", iconBorder, "TOPLEFT", 1, -1)
    iconBack:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", -1, 1)
    iconBack:SetColorTexture(0.02, 0.02, 0.03, 1)
    local icon = top:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetPoint("TOPLEFT", iconBorder, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", iconBorder, "BOTTOMRIGHT", -2, 2)
    icon:SetTexture(specIcon or 134400)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return hero, topGap + height + 8
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
    kuimove = "UnlockMode",
    cursor = "Cursor",
    teleportmenu = "TeleportMenu",
}

-- Profile controls: every button is a KT.NavTabs button (accent rim, accent fill + glow and a shine sweep on hover), so the 1px
-- borders stay on whole physical pixels at fractional UI scales. Action rows,
-- module cards and the pager all go through KT.NavTabs.Layout to stay aligned.
ns.ProfileUI = ns.ProfileUI or { activeTab = "profiles", moduleQuery = "", modulePage = 1 }

local PROFILE_ICON_PATH = ICON_PATH .. "Profiles\\"
local PROFILE_ACTION_ICONS = {
    ["Load Selected"] = "load",
    ["Delete Selected"] = "delete",
    ["Save As"] = "save",
    ["Assign To Spec"] = "assign",
    ["Clear Spec Assign"] = "clear",
    ["Export Current Profile"] = "export",
    ["Import Profile"] = "import",
    ["Select All"] = "selectall",
    ["Clear Selection"] = "clearsel",
    ["Load Modules"] = "modules",
    ["Export Modules"] = "export",
    ["Import Modules"] = "import",
    ["Export Spells"] = "export",
    ["Import Spells"] = "import",
    ["Search"] = "search",
}
local PROFILE_DANGER_ACTIONS = { ["Delete Selected"] = true }

local PROFILE_ACTION_FONT = 11
local PROFILE_ACTION_HEIGHT = 30
local PROFILE_ICON_SIZE = 14
local PROFILE_ICON_PAD = 28 -- icon inset + icon + gap; text is padded the same on both sides

-- opts: icon (file name in icons\Profiles), danger, fontSize, iconOnly
function ns.ProfileUI.CreateButton(parent, x, y, width, height, text, onClick, selected, opts)
    opts = opts or {}
    local NT = KT.NavTabs
    local btn = CreateFrame("Button", nil, parent)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    btn:SetSize(width, height)
    local function IsSelected()
        if type(selected) == "function" then return selected() and true or false end
        return selected == true
    end
    local danger = opts.danger
    if danger == nil then danger = PROFILE_DANGER_ACTIONS[text] end
    NT.StyleButton(btn, {
        label = opts.iconOnly and "" or LText(text or ""),
        fontSize = opts.fontSize or PROFILE_ACTION_FONT,
        selected = IsSelected(),
        danger = danger,
    })
    local icon = opts.icon or PROFILE_ACTION_ICONS[text]
    if icon then
        NT.SetContent(btn, {
            icon = PROFILE_ICON_PATH .. icon .. ".tga",
            iconSize = opts.iconSize or PROFILE_ICON_SIZE,
            iconInset = 8,
            iconCenter = opts.iconOnly,
            textLeft = PROFILE_ICON_PAD,
            textRight = PROFILE_ICON_PAD,
        })
    end
    btn:SetScript("OnClick", function() if onClick then onClick(btn) end end)
    if opts.tooltip then
        btn:HookScript("OnEnter", function(self)
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(LText(opts.tooltip))
                GameTooltip:Show()
            end
        end)
        btn:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    end
    btn.Refresh = function() NT.SetState(btn, IsSelected(), danger) end
    return btn
end

-- One row of equal-width action buttons, aligned with the rows built by W:*.
-- specs: { { text =, onClick =, icon =, danger =, confirm =, confirmText = }, ... }
function ns.ProfileUI.ActionRow(parent, yOffset, specs)
    local NT = KT.NavTabs
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 10, yOffset)
    row:SetSize(parent:GetWidth() - 20, PROFILE_ACTION_HEIGHT + 8)
    local buttons = {}
    for index, spec in ipairs(specs) do
        local onClick = spec.onClick
        if spec.confirm then
            local run = spec.onClick
            onClick = function()
                StaticPopupDialogs.KT_CONFIRM_ACTION = {
                    text = LText(spec.confirmText or "Are you sure?"), button1 = LText("Yes"), button2 = LText("No"),
                    OnAccept = run, timeout = 0, whileDead = 1, hideOnEscape = 1,
                }
                StaticPopup_Show("KT_CONFIRM_ACTION")
            end
        end
        buttons[index] = ns.ProfileUI.CreateButton(row, 0, 0, 40, PROFILE_ACTION_HEIGHT, spec.text, onClick, false, spec)
    end
    local used = NT.Layout(row, buttons, {
        width = row:GetWidth(), height = PROFILE_ACTION_HEIGHT, gap = 8, padding = PROFILE_ICON_PAD,
        fontSize = PROFILE_ACTION_FONT, y = 4, perRow = #buttons,
    })
    row:SetHeight(used + 8)
    row.buttons = buttons
    return row, used + 8 + 4
end

function ns.ProfileUI.WrapWidgets(W)
    local proxy = setmetatable({}, { __index = W })
    function proxy:Button(parent, text, yOffset, func, width, confirm, confirmText)
        return ns.ProfileUI.ActionRow(parent, yOffset, {
            { text = text, onClick = func, confirm = confirm, confirmText = confirmText },
        })
    end
    function proxy:DualRow(parent, yOffset, left, right)
        if left.type ~= "button" or right.type ~= "button" then return W:DualRow(parent, yOffset, left, right) end
        return ns.ProfileUI.ActionRow(parent, yOffset, {
            { text = left.text, onClick = left.onClick },
            { text = right.text, onClick = right.onClick },
        })
    end
    return proxy
end

function ns.ProfileUI.FilterEntries(entries, query)
    local filtered = {}
    query = (query or ""):lower():match("^%s*(.-)%s*$")
    for _, entry in ipairs(entries) do
        local name = LText(entry.label or entry.name or ""):lower()
        if query == "" or name:find(query, 1, true) or tostring(entry.id or ""):lower():find(query, 1, true) then
            filtered[#filtered + 1] = entry
        end
    end
    return filtered
end

-- Search box + Search button on one line, both inside the 10px content inset.
function ns.ProfileUI.AddSearchRow(parent, yOffset, query, onSearch)
    local NT = KT.NavTabs
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 10, yOffset)
    row:SetSize(parent:GetWidth() - 20, PROFILE_ACTION_HEIGHT + 8)
    local px = NT.PixelSize(row)
    local gap = NT.Snap(8, row, 1)
    local btnW = NT.Snap(PROFILE_ACTION_HEIGHT + 4, row, 1)
    local boxW = (NT.Snap(row:GetWidth() - btnW - gap, row, 1))

    local box = CreateFrame("EditBox", nil, row, "BackdropTemplate")
    box:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -NT.Snap(4, row, 0))
    box:SetSize(boxW, (NT.Snap(PROFILE_ACTION_HEIGHT, row, 1)))
    KT:AddBackdrop(box, 0.02, 0.02, 0.03, 0.9)
    KT:AddAccentBorder(box, 0.45)
    box:SetFont(KT.ResolveFontPath and KT:ResolveFontPath() or KT.FONT_PATH, 11, "")
    box:SetTextInsets(10, 8, 0, 0)
    box:SetAutoFocus(false)
    box:SetText(query or "")

    local hint = box:CreateFontString(nil, "OVERLAY")
    hint:SetFont(KT.ResolveFontPath and KT:ResolveFontPath() or KT.FONT_PATH, 11, "")
    hint:SetPoint("LEFT", box, "LEFT", 10, 0)
    hint:SetTextColor(0.5, 0.5, 0.55, 1)
    hint:SetText(LText("Search modules..."))
    local function UpdateHint() hint:SetShown((box:GetText() or "") == "" and not box:HasFocus()) end
    box:SetScript("OnEditFocusGained", UpdateHint)
    box:SetScript("OnEditFocusLost", UpdateHint)
    box:SetScript("OnTextChanged", UpdateHint)
    UpdateHint()

    local function Search() box:ClearFocus(); onSearch(box:GetText()) end
    box:SetScript("OnEnterPressed", Search)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local btn = ns.ProfileUI.CreateButton(row, boxW + gap, NT.Snap(4, row, 0), btnW, PROFILE_ACTION_HEIGHT, "Search", Search, false,
        { icon = "search", iconOnly = true, tooltip = "Search", iconSize = 16 })
    btn:SetHeight((NT.Snap(PROFILE_ACTION_HEIGHT, row, 1)))
    return row, PROFILE_ACTION_HEIGHT + 8 + 4
end

-- Page pills: [<] [1] [2] ... [>], centered, every size a whole number of pixels.
function ns.ProfileUI.AddPager(parent, yOffset, page, pages, onPage)
    local NT = KT.NavTabs
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 10, yOffset)
    row:SetSize(parent:GetWidth() - 20, 26 + 8)
    local px = NT.PixelSize(row)
    local gapPx = math.max(1, math.floor(6 / px + 0.5))
    local hPx = math.floor(26 / px + 0.5)
    local arrowPx = math.floor(34 / px + 0.5)
    local pillPx = math.floor(28 / px + 0.5)
    local specs = {}
    specs[#specs + 1] = { w = arrowPx, text = "Previous", icon = "prev", iconOnly = true, enabled = page > 1,
        click = function() onPage(page - 1) end, tooltip = "Previous" }
    if pages <= 7 then
        for p = 1, pages do
            specs[#specs + 1] = { w = pillPx, text = tostring(p), selected = p == page, enabled = true,
                click = function() onPage(p) end }
        end
    else
        specs[#specs + 1] = { w = math.floor(72 / px + 0.5), text = string.format("%d / %d", page, pages),
            selected = true, enabled = true, click = function() end }
    end
    specs[#specs + 1] = { w = arrowPx, text = "Next", icon = "next", iconOnly = true, enabled = page < pages,
        click = function() onPage(page + 1) end, tooltip = "Next" }
    local totalPx = gapPx * (#specs - 1)
    for _, s in ipairs(specs) do totalPx = totalPx + s.w end
    local xPx = math.max(0, math.floor((row:GetWidth() / px - totalPx) / 2))
    local yPx = math.floor(4 / px + 0.5)
    for _, s in ipairs(specs) do
        local btn = ns.ProfileUI.CreateButton(row, xPx * px, yPx * px, s.w * px, hPx * px, s.text, s.click,
            s.selected or false, { icon = s.icon, iconOnly = s.iconOnly, fontSize = 10, tooltip = s.tooltip })
        if not s.enabled then
            btn:SetEnabled(false)
            btn:SetAlpha(0.35)
        end
        xPx = xPx + s.w + gapPx
    end
    return row, 26 + 8 + 4
end

-- Profiles page grids (KullThranUI/ProfileCards.lua): wave cards for saved
-- profiles and CDM specs, grid buttons for modules.
-- Kept in ns.ProfileUI: the main chunk of this file is at Lua's 200-local limit.
ns.ProfileUI.Grid = {
    pageIcon = GENERAL_TAB_ICON .. "Profiles.tga",
    cardMinW = 118,
    cardRatio = 0.8,    -- height / width (the CSS card is 240x330)
    cardMaxH = 104,
    actionH = 32,       -- KT.SoftButton action rows
    moduleMinW = 190,
    moduleH = 42,
    gap = 10,
}

function ns.ProfileUI.GetWaveCardSize(usable)
    local cols = math.max(1, math.min(6, math.floor((usable + ns.ProfileUI.Grid.gap) / (ns.ProfileUI.Grid.cardMinW + ns.ProfileUI.Grid.gap))))
    local cardW = (usable - ns.ProfileUI.Grid.gap * (cols - 1)) / cols
    return cols, cardW, math.floor(math.min(ns.ProfileUI.Grid.cardMaxH, cardW * ns.ProfileUI.Grid.cardRatio))
end

-- entries -> wave cards. opts: getTitle, getSubtitle, getIcon, getIconCoords,
-- getBadge, getTooltip, isSelected, onClick, onDoubleClick, onRightClick, onIconClick,
-- iconTooltip. Returns the new y.
function ns.ProfileUI.WaveGrid(parent, startY, entries, opts)
    local usable = parent:GetWidth() - 20
    local cols, cardW, cardH = ns.ProfileUI.GetWaveCardSize(usable)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", 10, -startY)
    holder:SetWidth(usable)
    local cards = {}
    for _, entry in ipairs(entries) do
        cards[#cards + 1] = KT.WaveCard.Create(holder, {
            width = cardW, height = cardH,
            title = opts.getTitle(entry),
            subtitle = opts.getSubtitle and opts.getSubtitle(entry) or nil,
            icon = opts.getIcon and opts.getIcon(entry) or nil,
            iconCoords = opts.getIconCoords and opts.getIconCoords(entry) or opts.iconCoords,
            onIconClick = opts.onIconClick and function() opts.onIconClick(entry) end or nil,
            iconTooltip = opts.iconTooltip,
            badge = opts.getBadge and opts.getBadge(entry) or nil,
            selected = opts.isSelected(entry),
            onClick = function() opts.onClick(entry) end,
            onDoubleClick = opts.onDoubleClick and function() opts.onDoubleClick(entry) end or nil,
            onRightClick = opts.onRightClick and function(card) opts.onRightClick(entry, card) end or nil,
            tooltip = opts.getTooltip and function(tip) opts.getTooltip(entry, tip) end or nil,
        })
    end
    -- opts.addCard = { title, subtitle, icon, onClick }: one more card at the end.
    if opts.addCard then
        cards[#cards + 1] = KT.WaveCard.Create(holder, {
            width = cardW, height = cardH,
            title = opts.addCard.title,
            subtitle = opts.addCard.subtitle,
            icon = opts.addCard.icon,
            selected = false,
            onClick = opts.addCard.onClick,
        })
    end
    local used = KT.LayoutCardGrid(holder, cards, {
        width = usable, columns = cols, height = cardH, gap = ns.ProfileUI.Grid.gap, y = 4,
    })
    holder:SetHeight(math.max(1, used + 4))
    return startY + used + 4 + 12
end

-- One row of KT.SoftButton (accent shadows), equal widths.
-- specs: { { text =, onClick =, icon =, danger =, confirm =, confirmText = }, ... }
function ns.ProfileUI.SoftActionRow(parent, yOffset, specs)
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", 10, yOffset)
    row:SetSize(parent:GetWidth() - 20, ns.ProfileUI.Grid.actionH)
    local buttons = {}
    for index, spec in ipairs(specs) do
        local onClick = spec.onClick
        if spec.confirm then
            local run = spec.onClick
            onClick = function()
                StaticPopupDialogs.KT_CONFIRM_ACTION = {
                    text = LText(spec.confirmText or "Are you sure?"), button1 = LText("Yes"), button2 = LText("No"),
                    OnAccept = run, timeout = 0, whileDead = 1, hideOnEscape = 1,
                }
                StaticPopup_Show("KT_CONFIRM_ACTION")
            end
        end
        local icon = spec.icon or PROFILE_ACTION_ICONS[spec.text]
        buttons[index] = KT.SoftButton.Create(row, {
            label = LText(spec.text),
            icon = icon and (PROFILE_ICON_PATH .. icon .. ".tga") or nil,
            danger = spec.danger or PROFILE_DANGER_ACTIONS[spec.text],
            onClick = function() if onClick then onClick() end end,
        })
    end
    -- 8px above and below for the shadows.
    local used = KT.LayoutCardGrid(row, buttons, {
        width = row:GetWidth(), columns = #buttons, height = ns.ProfileUI.Grid.actionH, gap = 14, y = 8,
    })
    row:SetHeight(used + 16)
    return row, used + 16 + 4
end

function ns.ProfileUI.Summary(parent, y, text)
    local summary = parent:CreateFontString(nil, "OVERLAY")
    summary:SetFont(KT.ResolveFontPath and KT:ResolveFontPath() or KT.FONT_PATH, 10, "OUTLINE")
    summary:SetTextColor(0.68, 0.68, 0.74, 1)
    summary:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -y - 2)
    summary:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -y - 2)
    summary:SetJustifyH("CENTER")
    summary:SetText(text)
    return y + 20
end

-- Module defs -> searchable, paged grid of grid buttons. Returns the new y.
function ns.ProfileUI.ModuleGrid(parent, startY, defs, isSelected, onToggle)
    local filtered = ns.ProfileUI.FilterEntries(defs, ns.ProfileUI.moduleQuery)
    local usable = parent:GetWidth() - 20
    local cols = math.max(1, math.min(4, math.floor((usable + ns.ProfileUI.Grid.gap) / (ns.ProfileUI.Grid.moduleMinW + ns.ProfileUI.Grid.gap))))
    local y = startY
    local function Refresh() if KT.RefreshPage then KT:RefreshPage() end end

    local _, sh = ns.ProfileUI.AddSearchRow(parent, -y, ns.ProfileUI.moduleQuery, function(text)
        ns.ProfileUI.moduleQuery, ns.ProfileUI.modulePage = text, 1
        Refresh()
    end)
    y = y + sh

    local pageSize = cols * 4
    local pages = math.max(1, math.ceil(#filtered / pageSize))
    local page = math.max(1, math.min(pages, ns.ProfileUI.modulePage))
    ns.ProfileUI.modulePage = page
    local first = (page - 1) * pageSize + 1
    local last = math.min(#filtered, first + pageSize - 1)

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", 10, -y)
    holder:SetWidth(usable)
    local buttons = {}
    for index = first, last do
        local def = filtered[index]
        local iconName = PROFILE_MODULE_ICON_MAP[def.id] or "Config"
        local style = ns.PAGE_ICON_STYLE_MAP[iconName:lower()] or {}
        local iw, ih = style.width or 60, style.height or 40
        local scale = math.min(28 / iw, 18 / ih)
        buttons[#buttons + 1] = KT.GridButton.Create(holder, {
            height = ns.ProfileUI.Grid.moduleH,
            label = LText(def.label),
            icon = ICON_PATH .. iconName .. ".png",
            iconWidth = iw * scale, iconHeight = ih * scale,
            selected = isSelected(def),
            onClick = function() onToggle(def, not isSelected(def)) end,
        })
    end
    local used = 0
    if #buttons > 0 then
        used = KT.LayoutCardGrid(holder, buttons, {
            width = usable, columns = cols, height = ns.ProfileUI.Grid.moduleH, gap = 8, y = 4,
        }) + 4
    end
    holder:SetHeight(math.max(1, used))
    y = y + used + 8

    if pages > 1 then
        local _, ph = ns.ProfileUI.AddPager(parent, -y, page, pages, function(p)
            ns.ProfileUI.modulePage = math.max(1, math.min(pages, p))
            Refresh()
        end)
        y = y + ph
    end

    local totalSelected = 0
    for _, def in ipairs(defs) do if isSelected(def) then totalSelected = totalSelected + 1 end end
    if #filtered == 0 then
        return ns.ProfileUI.Summary(parent, y, LText("No modules found"))
    end
    return ns.ProfileUI.Summary(parent, y, string.format("%d / %d %s", totalSelected, #defs, LText("selected")))
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
                    KT:Print(string.format(LText("%s disabled. Reload UI to apply the change."), label or (entry.rule and entry.rule.title) or "KUI module"))
                end
                if KT and KT.RefreshPage then
                    KT:RefreshPage()
                end
            elseif KT and KT.Print then
                KT:Print(LText("Could not disable the KUI module from the Compatibility panel."))
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
                    KT:Print(string.format(LText("%s disabled. Reload UI to apply the change."), addon.title or addon.name or "Addon"))
                end
                if KT and KT.RefreshPage then
                    KT:RefreshPage()
                end
            elseif KT and KT.Print then
                KT:Print(string.format(LText("Could not disable %s from the Compatibility panel."), addon.title or addon.name or "Addon"))
            end
        end)
    elseif detector and detector.EnableAddonAndDisableKUIRule and entry.rule and entry.rule.id and entry.rule.canDisableKUI ~= false then
        AddCompatibilityActionButton(frame, LText("Use Addon"), { "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 14 }, "kui", function()
            local ok, addonEnabled, moduleDisabled, label = detector:EnableAddonAndDisableKUIRule(addon.name, entry.rule.id)
            if ok then
                if KT and KT.Print then
                    KT:Print(string.format(LText("%s enabled and %s disabled. Reload UI to apply both changes."),
                        addon.title or addon.name or "Addon",
                        label or (entry.rule and entry.rule.title) or "KUI module"))
                end
                if KT and KT.RefreshPage then
                    KT:RefreshPage()
                end
            elseif KT and KT.Print then
                if addonEnabled and not moduleDisabled then
                    KT:Print(string.format(LText("%s was enabled, but the KUI module could not be disabled."), addon.title or addon.name or "Addon"))
                elseif moduleDisabled and not addonEnabled then
                    KT:Print(string.format(LText("%s was disabled, but %s could not be enabled."), label or "KUI module", addon.title or addon.name or "Addon"))
                else
                    KT:Print(string.format(LText("Could not enable %s or disable the KUI module from the Compatibility panel."), addon.title or addon.name or "Addon"))
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

-- Pulsing accent frame around the recommended action of a page.
local function AddPulseGlow(button)
    if not button or button._ktPulseGlow then return end
    local r, g, b = KT:GetStyleAccentRGB()
    local glow = CreateFrame("Frame", nil, button)
    glow:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
    glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
    glow:SetFrameLevel(button:GetFrameLevel() + 2)
    glow:EnableMouse(false)
    KT:AddBorder(glow, r, g, b, 1, 2)
    local fill = glow:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints()
    fill:SetColorTexture(r, g, b, 0.14)
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.2)
    fade:SetDuration(0.85)
    fade:SetSmoothing("IN_OUT")
    pulse:Play()
    button._ktPulseGlow = glow
end

local function BuildCompatibilityTab(sc, W, y)
    local h = 0
    local detector = GetConflictDetectorModule()
    if not detector then
        _, h = W:SectionHeader(sc, LText("Compatibility"), -y); y = y + h
        _, h = W:Label(sc, LText("Compatibility detector module not available."), -y, 11, { r = 1, g = 0.35, b = 0.35 }); y = y + h
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
        -- One click and one reload for every incompatible addon, instead of
        -- disabling them one by one.
        local pendingDisable = 0
        do
            local seen = {}
            for _, entry in ipairs(active) do
                for _, addon in ipairs(entry.addons or {}) do
                    if addon and addon.name and not seen[addon.name] and (addon.loaded or addon.enabled)
                        and not (detector.HasPendingReload and detector:HasPendingReload(addon.name)) then
                        seen[addon.name] = true
                        pendingDisable = pendingDisable + 1
                    end
                end
            end
        end
        if pendingDisable > 0 and detector.DisableAllConflicts then
            local row
            row, h = W:Button(container, LTextFmt("Disable All Incompatible (%s)", tostring(pendingDisable)), -by, function()
                local disabled = detector:DisableAllConflicts(active)
                if disabled > 0 then ReloadUI() end
            end, "FULL", true, LText("Disable every incompatible addon listed below and reload the UI now?")); by = by + h
            AddPulseGlow(row and select(1, row:GetChildren()))
        end
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
        _, h = W:SectionHeader(sc, LText("Installed Compatibility Options"), -y); y = y + h
        _, h = W:Label(sc, LText("These installed addons are disabled. Use Addon enables the addon and disables the overlapping KUI module before the same reload."), -y, 11); y = y + h

        for _, entry in ipairs(inactive) do
            local block, content = CreateOptionBlock(sc, LText(entry.rule and entry.rule.title or "Compatibility Option"), 10, -y, sc:GetWidth() - 22)
            local by = 0
            _, h = W:Label(content, entry.rule and LText(entry.rule.reason) or "", -by, 11); by = by + h
            for _, addon in ipairs(entry.addons or {}) do
                local _, usedH = AddCompatibilityAddonCard(content, by, content:GetWidth(), detector, entry, addon)
                by = by + usedH
            end
            y = y + FinalizeOptionBlock(block, content, by) + 12
        end
    end

    return y
end

local kuiMoveFrameSearch = ""
local kuiMoveFrameGroup = nil

local function GetKUIMoveModule()
    return KT and KT.GetModule and KT:GetModule("KUIMove", true)
end

local function SetKUIMoveConfig(mod, key, value)
    if not (mod and mod.DB) then return end
    if mod.Config and mod.Config.SetConfig then
        mod.Config:SetConfig(key, value)
    else
        mod.DB[key] = value
    end
end

local function BuildKUIMoveTab(sc, W, y)
    local mod = GetKUIMoveModule()
    local h = 0
    if not (mod and mod.DB) then
        _, h = W:SectionHeader(sc, "KUIMove", -y); y = y + h
        _, h = W:Label(sc, "KUIMove is not available. Reload the UI after enabling the main KullThranUI addon.", -y, 11, { r = 1, g = 0.35, b = 0.35 }); y = y + h
        return y
    end

    local api = KT and KT.KUIMoveAPI
    local db = mod.DB
    if not api or not api.GetRegisteredAddOns then
        _, h = W:SectionHeader(sc, "KUIMove", -y); y = y + h
        _, h = W:Label(sc, "KUIMove frame registry is not available yet.", -y, 11, { r = 1, g = 0.35, b = 0.35 }); y = y + h
        return y
    end

    local addOns = {}
    for addOnName in pairs(api:GetRegisteredAddOns() or {}) do
        addOns[#addOns + 1] = addOnName
    end
    table.sort(addOns)

    local addOnValues = { ["__all"] = LText("All registered add-ons") }
    for _, addOnName in ipairs(addOns) do
        addOnValues[addOnName] = addOnName
    end
    if not kuiMoveFrameGroup or (kuiMoveFrameGroup ~= "__all" and not addOnValues[kuiMoveFrameGroup]) then
        kuiMoveFrameGroup = addOnValues.KullThranUI and "KullThranUI" or "__all"
    end

    local search = string.lower(kuiMoveFrameSearch or "")
    local filteredFrames = {}
    for _, addOnName in ipairs(addOns) do
        if kuiMoveFrameGroup == "__all" or kuiMoveFrameGroup == addOnName then
            for frameName in pairs(api:GetRegisteredFrames(addOnName) or {}) do
                if search == "" or string.lower(frameName):find(search, 1, true) then
                    filteredFrames[#filteredFrames + 1] = {
                        addOnName = addOnName,
                        frameName = frameName,
                    }
                end
            end
        end
    end
    table.sort(filteredFrames, function(a, b)
        if a.addOnName == b.addOnName then return a.frameName < b.frameName end
        return a.addOnName < b.addOnName
    end)

    _, h = W:SectionHeader(sc, "KUIMove", -y); y = y + h
    _, h = W:Label(sc, "Move Blizzard windows by dragging them. The controls below are grouped by purpose so the common actions stay visible.", -y, 11); y = y + h

    local cols = BeginOptionBlocks(sc, y, { gap = 14, columnGap = 14 })
    AddOptionBlock(cols, "left", LText("Move Windows"), function(container)
        local by = 0
        _, h = W:Toggle(container, "Require SHIFT to move frames", -by,
            function() return db.requireMoveModifier == true end,
            function(v) SetKUIMoveConfig(mod, "requireMoveModifier", v and true or false) end
        ); by = by + h
        _, h = W:Label(container, "When enabled, hold SHIFT while dragging to prevent accidental moves.", -by, 10); by = by + h
        _, h = W:Label(container, "CTRL + mouse wheel changes the scale. SHIFT + right-click resets a position.", -by, 10); by = by + h
        _, h = W:Button(container, "Open Detailed Legacy Settings", -by, function()
            if mod.Config and mod.Config.OpenConfig then mod.Config:OpenConfig() end
        end, "FULL"); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", LText("Remember Layout"), function(container)
        local by = 0
        _, h = W:Dropdown(container, "Frame Positions", -by,
            {
                off = LText("Do not remember"),
                session = LText("Until UI reload"),
                permanent = LText("Remember permanently"),
            },
            function() return db.savePosStrategy or "session" end,
            function(v) SetKUIMoveConfig(mod, "savePosStrategy", v) end
        ); by = by + h
        _, h = W:Dropdown(container, "Frame Scales", -by,
            {
                session = LText("Until UI reload"),
                permanent = LText("Remember permanently"),
            },
            function() return db.saveScaleStrategy or "session" end,
            function(v) SetKUIMoveConfig(mod, "saveScaleStrategy", v) end
        ); by = by + h
        _, h = W:Button(container, "Reset Saved Positions", -by, function()
            if mod.ResetPointStorage then mod:ResetPointStorage() end
            if ReloadUI then ReloadUI() end
        end, "FULL", true, "Reset all permanently saved frame positions and reload the UI?"); by = by + h
        _, h = W:Button(container, "Reset Saved Scales", -by, function()
            if mod.ResetScaleStorage then mod:ResetScaleStorage() end
            if ReloadUI then ReloadUI() end
        end, "FULL", true, "Reset all permanently saved frame scales and reload the UI?"); by = by + h
        return by
    end)
    y = EndOptionBlocks(cols) + 8

    _, h = W:SectionHeader(sc, "Frame Access", -y); y = y + h
    _, h = W:Label(sc, "Choose one frame group, filter by name, then enable only the windows you actually use.", -y, 11); y = y + h

    local filterCols = BeginOptionBlocks(sc, y, { gap = 14, columnGap = 14 })
    AddOptionBlock(filterCols, "left", LText("Find Frames"), function(container)
        local by = 0
        _, h = W:Dropdown(container, "Frame Group", -by, addOnValues,
            function() return kuiMoveFrameGroup end,
            function(value)
                kuiMoveFrameGroup = value
                if KT and KT.RefreshPage then KT:RefreshPage() end
            end
        ); by = by + h
        _, h = W:Input(container, "Name Filter", -by,
            function() return kuiMoveFrameSearch end,
            function(value)
                kuiMoveFrameSearch = tostring(value or "")
                if KT and KT.RefreshPage then KT:RefreshPage() end
            end
        ); by = by + h
        return by
    end)

    AddOptionBlock(filterCols, "right", LText("Bulk Actions"), function(container)
        local by = 0
        _, h = W:Label(container, LTextFmt("%d matching frame(s). Changes apply immediately.", #filteredFrames), -by, 11); by = by + h
        _, h = W:Button(container, "Enable Matching Frames", -by, function()
            for _, entry in ipairs(filteredFrames) do
                api:SetFrameDisabled(entry.addOnName, entry.frameName, false)
            end
            if KT and KT.RefreshPage then KT:RefreshPage() end
        end, "FULL"); by = by + h
        _, h = W:Button(container, "Disable Matching Frames", -by, function()
            for _, entry in ipairs(filteredFrames) do
                api:SetFrameDisabled(entry.addOnName, entry.frameName, true)
            end
            if KT and KT.RefreshPage then KT:RefreshPage() end
        end, "FULL", true, "Disable all matching frames?"); by = by + h
        return by
    end)
    y = EndOptionBlocks(filterCols) + 8

    local title = kuiMoveFrameGroup == "__all" and "All Registered Frames" or kuiMoveFrameGroup
    local frameBlock, frameContent = CreateOptionBlock(sc, title, 10, -y, sc:GetWidth() - 22)
    local by = 0
    if #filteredFrames == 0 then
        _, h = W:Label(frameContent, search == "" and "No supported frames are registered." or "No frames match the current filter.", -by, 11); by = by + h
    else
        for _, entry in ipairs(filteredFrames) do
            local frameAddon = entry.addOnName
            local frameName = entry.frameName
            _, h = W:Toggle(frameContent, frameName, -by,
                function() return not api:IsFrameDisabled(frameAddon, frameName) end,
                function(value) api:SetFrameDisabled(frameAddon, frameName, not value) end
            ); by = by + h
        end
    end
    y = y + FinalizeOptionBlock(frameBlock, frameContent, by) + 12

    _, h = W:Label(sc, "Protected or secret-value-sensitive Blizzard windows are intentionally excluded to avoid taint errors.", -y, 10, { r = 1, g = 0.68, b = 0.32 }); y = y + h

    return y
end

local function BuildGeneralCore(sc, W, y)
    local h = 0
    local currentVersion, changelogEntry, latestChangelogEntry, isFallback = GetChangelogDisplayInfo()
    local accentR, accentG, accentB = GetMenuAccentColor()
    local profileName = KT.db and KT.db:GetCurrentProfile() or LText("Unknown")
    local profileMod = GetProfilesModule()
    local assigned = profileMod and profileMod:GetCurrentSpecAssignment() or nil

    -- Landing card in the starfield style of the category headers
    -- (Widgets.lua W:StarHero); profile, version, spec and the changelog
    -- button sit on a layer above its sky.
    -- The real widget, not the search proxy, so the layer above can use its text frame.
    local hero = KT.Widgets:StarHero(sc, {
        width = sc:GetWidth() - 20,
        height = 118,
        eyebrow = LText("KULLTHRANUI CONFIGURATION"),
        title = LText("Interface Control Center"),
        subtitle = LText("Configure the foundation of KUI here. Module-specific behavior remains in the sections on the left."),
    })
    hero:SetPoint("TOPLEFT", 10, -y)
    local heroTop = CreateFrame("Frame", nil, hero)
    heroTop:SetAllPoints(hero)
    heroTop:SetFrameLevel((hero._textKT:GetFrameLevel() or 1) + 2)

    local heroProfile = heroTop:CreateFontString(nil, "OVERLAY")
    heroProfile:SetFont(KT.FONT_PATH, 10, "OUTLINE")
    heroProfile:SetPoint("BOTTOMLEFT", 22, 13)
    heroProfile:SetText(LTextFmt("PROFILE  %s", profileName))
    heroProfile:SetTextColor(0.92, 0.92, 0.95, 1)

    local heroVersion = heroTop:CreateFontString(nil, "OVERLAY")
    heroVersion:SetFont(KT.FONT_PATH, 10, "OUTLINE")
    heroVersion:SetPoint("BOTTOMRIGHT", -18, 13)
    heroVersion:SetText(LTextFmt("VERSION  %s", currentVersion))
    heroVersion:SetTextColor(accentR, accentG, accentB, 1)

    -- Compact changelog access in the corner of the landing card.
    -- Cut-corner gradient button (Widgets.lua W:CutButton).
    local changelogBtn = KT.Widgets:CutButton(heroTop, LText("Open Changelog"), { width = 150, height = 26 })
    changelogBtn:SetPoint("TOPRIGHT", hero, "TOPRIGHT", -16, -12)

    changelogBtn:SetScript("OnClick", function()
        if KT and KT.ShowChangelogPopup then
            KT:ShowChangelogPopup(currentVersion)
        end
    end)
    changelogBtn:HookScript("OnEnter", function(self)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
            GameTooltip:SetText(LText("Updates & Release Notes"), 1, 1, 1)
            GameTooltip:AddLine(LTextFmt("Installed Version: %s", currentVersion), accentR, accentG, accentB)
            if changelogEntry then
                GameTooltip:AddLine(LTextFmt("Release notes are available for version %s.", changelogEntry.version), 0.75, 0.75, 0.75, true)
            elseif latestChangelogEntry then
                GameTooltip:AddLine(LTextFmt("Latest archived release notes: %s", latestChangelogEntry.version), 0.75, 0.75, 0.75, true)
            end
            if isFallback then
                GameTooltip:AddLine(LText("The current release has not been published to the Wago archive yet. CurseForge and Discord sources remain available inside the changelog."), 1, 0.62, 0.32, true)
            end
            GameTooltip:Show()
        end
    end)
    changelogBtn:HookScript("OnLeave", function(self)
        if GameTooltip then GameTooltip:Hide() end
    end)

    if assigned then
        local heroSpec = heroTop:CreateFontString(nil, "OVERLAY")
        heroSpec:SetFont(KT.FONT_PATH, 9, "")
        heroSpec:SetPoint("RIGHT", changelogBtn, "LEFT", -10, 0)
        heroSpec:SetText(LTextFmt("SPEC ASSIGNMENT  %s", assigned))
        heroSpec:SetTextColor(0.72, 0.72, 0.76, 1)
    end

    y = y + 132

    local coreCols = BeginOptionBlocks(sc, y, { gap = 14, columnGap = 14 })

    AddOptionBlock(coreCols, "left", "Interface Scale", function(container)
        local by = 0
        _, h = W:Label(container, LText("Match KUI to your display first. This controls the scale used by every module."), -by, 10); by = by + h
        _, h = W:Toggle(container, "KUI controls the UI scale", -by,
            function()
                return KT.IsUIScaleManaged and KT:IsUIScaleManaged() or false
            end,
            function(v)
                if v then
                    if KT.MarkUIScaleUserSet then KT:MarkUIScaleUserSet() end
                    KT:ApplyUIScale()
                elseif KT.ReleaseUIScale then
                    KT:ReleaseUIScale()
                end
            end
        ); by = by + h
        _, h = W:Toggle(container, "Use Blizzard UI Scale", -by,
            function()
                return KT.db.profile.useBlizzardUIScale
            end,
            function(v)
                KT.db.profile.useBlizzardUIScale = v
                if v then
                    KT.db.profile.autoResolutionScale = false
                end
                if KT.MarkUIScaleUserSet then KT:MarkUIScaleUserSet() end
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
                        if KT.MarkUIScaleUserSet then KT:MarkUIScaleUserSet() end
                        KT:ApplyUIScale()
                    end
                end
            end
        ); by = by + h
        _, h = W:Slider(container, "Manual UI Scale", -by,
            function()
                local scale
                if not (KT.IsUIScaleManaged and KT:IsUIScaleManaged()) then
                    scale = UIParent and UIParent:GetScale() or nil
                elseif KT.db.profile.useBlizzardUIScale and KT.GetBlizzardUIScale then
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
                    if KT.MarkUIScaleUserSet then KT:MarkUIScaleUserSet() end
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

    -- No section header here: on a plain page it opens a card that stays
    -- hidden until a row joins it, which only left an empty band.
    y = EndOptionBlocks(coreCols) + 8
    _, h = W:Label(sc, "Build a complete visual preset for KUI or fine tune the palette manually. These settings affect the entire addon.", -y, 11); y = y + h
    -- Visual Theme sits on top, full width: it decides the geometry and assets.
    local themeFrame, themeContent = CreateOptionBlock(sc, "Visual Theme", 10, -y, sc:GetWidth() - 22)
    local themeY = 0
    -- The addon's own general accent color (this tab's "Accent Color"
    -- swatch, used for Unlock Mode/Friend List/Armory/Objective
    -- Tracker/Bags) no longer gets silently overridden by whichever Unit
    -- Frame visual theme happens to be active (see the removed themeAccent
    -- block in KT:GetStylePalette) -- it's yours to pick regardless of
    -- which style is selected here, not just on kui.
    _, h = W:Label(themeContent, "Select the visual theme. This sets the geometry and assets for Unit Frames. The addon's own accent color below stays yours to customize regardless of which style you pick.", -themeY, 11); themeY = themeY + h
    if KT.VisualThemes and KT.VisualThemes.CreateSelector then
        -- The cards used to be laid out edge to edge across the whole block,
        -- flush against its accent rail and right border, so they read as
        -- pasted over the section instead of belonging to it. They now sit
        -- in an inset tray with even padding, like the rest of the blocks'
        -- content, with a clear gap under the description.
        local trayLeft, trayRight, trayPad, trayGap = 12, 10, 10, 8
        local trayW = (sc:GetWidth() - 22) - trayLeft - trayRight
        local tray = CreateFrame("Frame", nil, themeContent, "BackdropTemplate")
        tray:SetPoint("TOPLEFT", themeContent, "TOPLEFT", trayLeft, -(themeY + trayGap))
        tray:SetWidth(trayW)
        KT:AddBackdrop(tray, 0.012, 0.014, 0.020, 0.95)
        KT:AddBorder(tray, 1, 1, 1, 0.07)
        h = KT.VisualThemes:CreateSelector(tray, {
            columns = 4, compact = true,
            xOffset = trayPad, yOffset = trayPad,
            width = trayW - (trayPad * 2),
        })
        -- CreateSelector reports its content height plus 4px of slack.
        local trayH = trayPad + (h - 4) + trayPad
        tray:SetHeight(trayH)
        themeY = themeY + trayGap + trayH
    end
    y = y + FinalizeOptionBlock(themeFrame, themeContent, themeY) + 14

    -- Colors follow, full width, enabled only for KullThranUI Style.
    local presetFrame, presetContent = CreateOptionBlock(sc, "Preset Colors", 10, -y, sc:GetWidth() - 22)
    local presetBuild = function(container)
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
        local gridHeight = KT:CreateAccentPresetGrid(container, {
            columns = 3,
            width = container:GetWidth() - 20,
            xOffset = 10,
            yOffset = by + 4,
            cardHeight = 46,
            gap = 10,
            fontPath = KT.FONT_PATH,
            localize = LText,
            isSelected = function(presetKey)
                return KT.IsAccentPresetActive(KT.db.profile.skin, presetKey)
            end,
            onSelect = function(presetKey)
                ApplySmartStylePreset(presetKey)
            end,
        })
        by = by + gridHeight + 14
        _, h = W:Label(container, LText("Preset selection also updates accent-driven fields like tracker highlights, chat highlight and castbar color."), -by, 10); by = by + h
        return by
    end
    y = y + FinalizeOptionBlock(presetFrame, presetContent, presetBuild(presetContent)) + 14

    -- Color presets/manual colors stay fully usable regardless of which
    -- Unit Frame visual theme is active, not just kui -- this full-section
    -- mouse-blocking overlay (plus its twin below, for the Manual Colors
    -- section) was the actual mechanism making the controls unselectable;
    -- GetStylePalette no longer overrides the result anyway (see the
    -- removed themeAccent block there), so gating input here too was
    -- doubly wrong.

    -- Manual colours: two cards side by side. "Palette" pairs the window
    -- colours two per row; "Module Colors" gives each module one row with an
    -- Accent/Custom switch and its swatch.
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

    local function ColorOf(mode, own)
        local c = (mode == "custom" and own) or KT_GetActiveAccent(skin)
        return c.r, c.g, c.b, 1
    end

    _, h = W:SectionHeader(sc, "Manual Colors", -y); y = y + h
    _, h = W:Label(sc, LText("Fine tune the smart recolor palette manually if you want a custom style."), -y, 11); y = y + h
    local manualCols = BeginOptionBlocks(sc, y)

    AddOptionBlock(manualCols, "left", "Palette", function(container)
        local by = 0
        _, h = W:DualRow(container, -by,
            { type = "colorpicker", text = "Accent Color",
              getValue = function() local c = KT_GetActiveAccent(skin); return c.r, c.g, c.b, 1 end,
              setValue = function(r, g, b)
                  skin.accentColor = MakeStyleColor(r, g, b, 1)
                  skin.customBorderColor = MakeStyleColor(r, g, b, 1)
                  skin.kullthranUIColorByClass = false
                  skin.borderTheme = "CUSTOM"
                  skin.borderThemeBeforeClass = "CUSTOM"
                  ApplyManualStyle()
              end },
            { type = "colorpicker", text = "Window Background", hasAlpha = true,
              getValue = function() local c = skin.backgroundColor or STYLE_PRESETS.kui_crimson.background; return c.r, c.g, c.b, c.a end,
              setValue = function(r, g, b, a) skin.backgroundColor = MakeStyleColor(r, g, b, a); ApplyManualStyle() end }
        ); by = by + h
        _, h = W:DualRow(container, -by,
            { type = "colorpicker", text = "Main Text",
              getValue = function() local c = skin.menuTextColor or STYLE_PRESETS.kui_crimson.text; return c.r, c.g, c.b, 1 end,
              setValue = function(r, g, b) skin.menuTextColor = MakeStyleColor(r, g, b, 1); ApplyManualStyle() end },
            { type = "colorpicker", text = "Secondary Text",
              getValue = function() local c = skin.menuSubtextColor or STYLE_PRESETS.kui_crimson.muted; return c.r, c.g, c.b, 1 end,
              setValue = function(r, g, b) skin.menuSubtextColor = MakeStyleColor(r, g, b, 1); ApplyManualStyle() end }
        ); by = by + h
        _, h = W:DualRow(container, -by,
            { type = "colorpicker", text = "Background Tint", hasAlpha = true,
              getValue = function() local c = skin.menuBackgroundTint or STYLE_PRESETS.kui_crimson.backgroundTint; return c.r, c.g, c.b, c.a end,
              setValue = function(r, g, b, a) skin.menuBackgroundTint = MakeStyleColor(r, g, b, a); ApplyManualStyle() end },
            { type = "dropdown", text = "Menu Icons",
              values = { accent = "Accent", white = "White" }, order = { "accent", "white" },
              getValue = function() return skin.menuIconColorMode or "accent" end,
              setValue = function(v) skin.menuIconColorMode = v; ApplyManualStyle() end }
        ); by = by + h
        return by
    end)

    AddOptionBlock(manualCols, "right", "Module Colors", function(container)
        local by = 0
        _, h = W:ModeColorRow(container, "Unlock Mode", -by,
            function() return skin.unlockModeColorMode or "accent" end,
            function(v) skin.unlockModeColorMode = v; ApplyManualStyle() end,
            function() return ColorOf(skin.unlockModeColorMode, skin.unlockModeColor) end,
            function(r, g, b) skin.unlockModeColorMode = "custom"; skin.unlockModeColor = MakeStyleColor(r, g, b, 1); ApplyManualStyle() end
        ); by = by + h
        _, h = W:ModeColorRow(container, "Friend List", -by,
            function() return skin.friendListColorMode or "accent" end,
            function(v) skin.friendListColorMode = v; ApplyManualStyle() end,
            function() return ColorOf(skin.friendListColorMode, skin.friendListColor) end,
            function(r, g, b) skin.friendListColorMode = "custom"; skin.friendListColor = MakeStyleColor(r, g, b, 1); ApplyManualStyle() end
        ); by = by + h
        _, h = W:ModeColorRow(container, "Armory", -by,
            function() return skin.armoryColorMode or "accent" end,
            function(v) skin.armoryColorMode = v; ApplyLegacySkinColorEdit() end,
            function() return ColorOf(skin.armoryColorMode, skin.armoryColor) end,
            function(r, g, b) skin.armoryColorMode = "custom"; skin.armoryColor = { r = r, g = g, b = b, a = 1 }; ApplyLegacySkinColorEdit() end
        ); by = by + h
        _, h = W:ModeColorRow(container, "Objective Tracker", -by,
            function() return KT.db.profile.objectiveTracker and KT.db.profile.objectiveTracker.colorMode or "accent" end,
            function(v)
                if KT.db.profile.objectiveTracker then KT.db.profile.objectiveTracker.colorMode = v end
                ApplyLegacySkinColorEdit()
            end,
            function()
                local obj = KT.db.profile.objectiveTracker
                return ColorOf(obj and obj.colorMode, obj and obj.customColor)
            end,
            function(r, g, b)
                local obj = KT.db.profile.objectiveTracker
                if obj then
                    obj.colorMode = "custom"
                    obj.customColor = { r = r, g = g, b = b, a = 1 }
                end
                ApplyLegacySkinColorEdit()
            end
        ); by = by + h
        _, h = W:ModeColorRow(container, "Bags", -by,
            function() return skin.bagsColorMode or "accent" end,
            function(v) skin.bagsColorMode = v; ApplyManualStyle() end,
            function() return ColorOf(skin.bagsColorMode, skin.bagsColor) end,
            function(r, g, b) skin.bagsColorMode = "custom"; skin.bagsColor = MakeStyleColor(r, g, b, 1); ApplyManualStyle() end
        ); by = by + h
        return by
    end)

    y = EndOptionBlocks(manualCols)
    _, h = W:Label(sc, "If some live module keeps the previous palette, use Reload UI after saving the style.", -y, 10); y = y + h + 8



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
    local function Report(ok, err)
        if not ok and err then KT:Print(err) return false end
        return true
    end

    W = ns.ProfileUI.WrapWidgets(W)
    local defs = profileMod:GetModuleDefinitions()
    local specEntries = profileMod:GetCDMSpecEntries()
    local assignedProfile = profileMod:GetCurrentSpecAssignment()
    local currentProfile = KT.db and KT.db:GetCurrentProfile() or "Unknown"
    local _, profileList = profileMod:GetProfileValues()
    local _, specName, specIcon = GetCurrentSpecVisual()

    -- One full-width block per section, stacked: the grids need the width.
    local blockX, blockW = 10, sc:GetWidth() - 22
    local function AddSection(title, buildFn)
        local frame, content = CreateOptionBlock(sc, title, blockX, -y, blockW)
        y = y + FinalizeOptionBlock(frame, content, buildFn(content)) + 16
    end

    local function DisplayName(name)
        return (KT.GetProfileDisplayName and KT:GetProfileDisplayName(name)) or name
    end
    local function LoadProfile(name)
        if name == currentProfile then return end
        if Report(profileMod:SwitchProfile(name)) then
            profilesSelectionName = KT.db:GetCurrentProfile()
            profilesDraftName = profilesSelectionName or ""
            RefreshProfilesPage()
        end
    end

    AddSection("KUI Profiles", function(container)
        local by = 0
        _, h = AddProfileSpecCard(container, -by, currentProfile, assignedProfile); by = by + h
        _, h = W:Label(container, "Click a profile to load it. It stays selected for the buttons below.", -by, 11); by = by + h
        by = ns.ProfileUI.WaveGrid(container, by, profileList, {
            getTitle = DisplayName,
            getSubtitle = function(name)
                if name == assignedProfile then
                    return LTextFmt("Assigned to %s", specName or LText("Unknown"))
                end
                return name == currentProfile and LText("Active profile") or LText("Saved profile")
            end,
            getIcon = function(name)
                local custom = profileMod.GetProfileIcon and profileMod:GetProfileIcon(name)
                if custom then return custom end
                if name == assignedProfile and specIcon then return specIcon end
                return ns.ProfileUI.Grid.pageIcon
            end,
            getIconCoords = function(name)
                local custom = profileMod.GetProfileIcon and profileMod:GetProfileIcon(name)
                if custom or (name == assignedProfile and specIcon) then return { 0.08, 0.92, 0.08, 0.92 } end
                return nil
            end,
            iconTooltip = LText("Click to choose this profile's icon."),
            onIconClick = profileMod.SetProfileIcon and function(name)
                KT.IconPicker.Open(profileMod:GetProfileIcon(name), function(icon)
                    profileMod:SetProfileIcon(name, icon)
                    RefreshProfilesPage()
                end)
            end or nil,
            getBadge = function(name) return name == currentProfile and LText("Active") or nil end,
            getTooltip = function(name, tip)
                tip:SetText(DisplayName(name))
                if name == currentProfile then tip:AddLine(LText("Active profile"), 0.4, 1, 0.5) end
                if name == assignedProfile then tip:AddLine(LTextFmt("Assigned to %s", specName or LText("Unknown")), 1, 0.82, 0.3) end
                tip:AddLine(LText("Click to load this profile."), 0.8, 0.8, 0.8, true)
                tip:AddLine(LText("Right-click for more options."), 0.8, 0.8, 0.8, true)
            end,
            isSelected = function(name) return name == profilesSelectionName end,
            onClick = function(name)
                profilesSelectionName = name
                RefreshProfilesPage()
                if name == currentProfile then return end
                StaticPopupDialogs.KT_CONFIRM_ACTION = {
                    text = LTextFmt("Load profile %s?", DisplayName(name)), button1 = LText("Yes"), button2 = LText("No"),
                    OnAccept = function() LoadProfile(name) end, timeout = 0, whileDead = 1, hideOnEscape = 1,
                }
                StaticPopup_Show("KT_CONFIRM_ACTION")
            end,
            -- Right-click: a menu of what can be done with this profile, built
            -- from the Profiles module's own actions (Blizzard's context menu,
            -- as Armory, Chat and Inspect use it).
            onRightClick = function(name, card)
                local function Confirm(text, onAccept)
                    StaticPopupDialogs.KT_CONFIRM_ACTION = {
                        text = text, button1 = LText("Yes"), button2 = LText("No"),
                        OnAccept = onAccept, timeout = 0, whileDead = 1, hideOnEscape = 1,
                    }
                    StaticPopup_Show("KT_CONFIRM_ACTION")
                end
                local function Delete()
                    Confirm(LTextFmt("Delete profile %s?", DisplayName(name)), function()
                        if Report(profileMod:DeleteProfile(name)) then
                            if profilesSelectionName == name then profilesSelectionName = KT.db:GetCurrentProfile() end
                            RefreshProfilesPage()
                        end
                    end)
                end
                if not (MenuUtil and MenuUtil.CreateContextMenu and card) then
                    -- Clients without the menu API keep the old direct action.
                    if name == currentProfile then
                        KT:Print(LText("You cannot delete the active profile."))
                    else
                        Delete()
                    end
                    return
                end
                -- No page refresh here: it would rebuild the card the menu hangs from.
                MenuUtil.CreateContextMenu(card, function(_, root)
                    root:CreateTitle(DisplayName(name))
                    if name ~= currentProfile then
                        root:CreateButton(LText("Load"), function()
                            Confirm(LTextFmt("Load profile %s?", DisplayName(name)), function() LoadProfile(name) end)
                        end)
                    end
                    if name == assignedProfile then
                        root:CreateButton(LText("Clear Spec Assign"), function()
                            if Report(profileMod:ClearCurrentSpecAssignment()) then RefreshProfilesPage() end
                        end)
                    else
                        root:CreateButton(LText("Assign To Spec"), function()
                            if Report(profileMod:AssignCurrentSpec(name)) then RefreshProfilesPage() end
                        end)
                    end
                    if profileMod.SetProfileIcon and KT.IconPicker then
                        root:CreateButton(LText("Change Icon"), function()
                            KT.IconPicker.Open(profileMod:GetProfileIcon(name), function(icon)
                                profileMod:SetProfileIcon(name, icon)
                                RefreshProfilesPage()
                            end)
                        end)
                    end
                    -- Export and Save As work on the active profile only.
                    if name == currentProfile then
                        root:CreateButton(LText("Export Current Profile"), function()
                            local exportString, err = profileMod:ExportCurrentProfileString()
                            if not exportString then
                                KT:Print(err)
                            else
                                profileMod:ShowExportPopup(LText("Export Current Profile"), exportString)
                            end
                        end)
                        if profileMod.PromptSaveCurrentAs then
                            root:CreateButton(LText("Save As"), function()
                                profileMod:PromptSaveCurrentAs(function()
                                    profilesSelectionName = KT.db:GetCurrentProfile()
                                    profilesDraftName = profilesSelectionName or ""
                                    RefreshProfilesPage()
                                end)
                            end)
                        end
                    end
                    root:CreateDivider()
                    if name == currentProfile then
                        root:CreateTitle(LText("You cannot delete the active profile."))
                    else
                        root:CreateButton(LText("Delete"), Delete)
                    end
                end)
            end,
            addCard = profileMod.PromptNewProfile and {
                title = "+ " .. LText("New Profile"),
                subtitle = LText("KUI defaults"),
                icon = ns.ProfileUI.Grid.pageIcon,
                onClick = function()
                    profileMod:PromptNewProfile(function()
                        profilesSelectionName = KT.db:GetCurrentProfile()
                        profilesDraftName = profilesSelectionName or ""
                        RefreshProfilesPage()
                    end)
                end,
            } or nil,
        })

        local selectedLabel = DisplayName(profilesSelectionName or currentProfile)
        _, h = W:Label(container, LTextFmt("Selected: %s", selectedLabel), -by, 11, { r = 1, g = 1, b = 1 }); by = by + h
        _, h = ns.ProfileUI.SoftActionRow(container, -by, {
            { text = "Assign To Spec", onClick = function()
                local target = profilesSelectionName or currentProfile
                if Report(profileMod:AssignCurrentSpec(target)) then
                    profilesSelectionName = target
                    RefreshProfilesPage()
                end
            end },
            { text = "Clear Spec Assign", onClick = function()
                if Report(profileMod:ClearCurrentSpecAssignment()) then RefreshProfilesPage() end
            end },
            { text = "Delete Selected", confirm = true,
                confirmText = LTextFmt("Delete profile %s?", selectedLabel),
                onClick = function()
                    if Report(profileMod:DeleteProfile(profilesSelectionName)) then
                        profilesSelectionName = KT.db:GetCurrentProfile()
                        RefreshProfilesPage()
                    end
                end },
        }); by = by + h

        _, h = W:Input(container, "Save Current As", -by,
            function() return profilesDraftName end,
            function(v) profilesDraftName = v end
        ); by = by + h
        _, h = ns.ProfileUI.SoftActionRow(container, -by, {
            { text = "Save As", onClick = function()
                if Report(profileMod:SaveCurrentAsProfile(profilesDraftName)) then
                    profilesSelectionName = KT.db:GetCurrentProfile()
                    profilesDraftName = profilesSelectionName or ""
                    RefreshProfilesPage()
                end
            end },
            { text = "Export Current Profile", onClick = function()
                local exportString, err = profileMod:ExportCurrentProfileString()
                if not exportString then
                    KT:Print(err)
                else
                    profileMod:ShowExportPopup(LText("Export Current Profile"), exportString)
                end
            end },
            { text = "Import Profile", onClick = function()
                profileMod:ShowImportPopup(
                    LText("Import Profile"),
                    LText("|cffff5555This overwrites the active KullThranUI profile.|r"),
                    function(text)
                        if Report(profileMod:ImportProfileString(text)) then
                            profilesSelectionName = KT.db:GetCurrentProfile()
                            profilesDraftName = profilesSelectionName or ""
                            RefreshProfilesPage()
                        end
                    end
                )
            end },
        }); by = by + h
        return by
    end)

    AddSection("Modules Export", function(container)
        local by = 0
        _, h = W:Label(container, "Pick the KUI modules you want to export or merge into the current profile.", -by, 11); by = by + h
        by = ns.ProfileUI.ModuleGrid(container, by, defs,
            function(def) return selectedModuleExports[def.id] == true end,
            function(def, selected)
                selectedModuleExports[def.id] = selected and true or false
                RefreshProfilesPage()
            end)
        _, h = ns.ProfileUI.SoftActionRow(container, -by, {
            { text = "Select All", onClick = function()
                SetAllSelections(selectedModuleExports, defs, true)
                RefreshProfilesPage()
            end },
            { text = "Clear Selection", onClick = function()
                SetAllSelections(selectedModuleExports, defs, false)
                RefreshProfilesPage()
            end },
            { text = "Load Modules", onClick = function()
                if Report(profileMod:ApplyModulesFromProfile(profilesSelectionName, CollectSelectedKeys(selectedModuleExports))) then
                    RefreshProfilesPage()
                end
            end },
            { text = "Export Modules", onClick = function()
                local exportString, err = profileMod:ExportModulesString(CollectSelectedKeys(selectedModuleExports))
                if not exportString then
                    KT:Print(err)
                else
                    profileMod:ShowExportPopup(LText("Export Modules"), exportString)
                end
            end },
            { text = "Import Modules", onClick = function()
                profileMod:ShowImportPopup(
                    LText("Import Module Profile"),
                    LText("|cffff5555This merges the imported modules into the active profile.|r"),
                    function(text)
                        if Report(profileMod:ImportProfileString(text)) then RefreshProfilesPage() end
                    end
                )
            end },
        }); by = by + h
        return by
    end)

    AddSection("CDM Spell Profiles", function(container)
        local by = 0
        _, h = W:Label(container, "Each card is a specialization. Export only the specs you actually want to move.", -by, 11); by = by + h
        by = ns.ProfileUI.WaveGrid(container, by, specEntries, {
            iconCoords = { 0.08, 0.92, 0.08, 0.92 },
            getTitle = function(spec) return spec.name end,
            getSubtitle = function(spec)
                return spec.hasData and LText("CDM data saved") or LText("No CDM data yet")
            end,
            getIcon = function(spec) return spec.icon or 134400 end,
            getTooltip = function(spec, tip)
                tip:SetText(spec.name)
                tip:AddLine(spec.hasData and LText("CDM data saved") or LText("No CDM data yet"), 0.8, 0.8, 0.8)
            end,
            isSelected = function(spec) return selectedCDMSpecExports[spec.key] == true end,
            onClick = function(spec)
                selectedCDMSpecExports[spec.key] = not selectedCDMSpecExports[spec.key]
                RefreshProfilesPage()
            end,
        })
        local totalSelected = 0
        for _, spec in ipairs(specEntries) do if selectedCDMSpecExports[spec.key] then totalSelected = totalSelected + 1 end end
        by = ns.ProfileUI.Summary(container, by - 8, string.format("%d / %d %s", totalSelected, #specEntries, LText("selected")))
        _, h = ns.ProfileUI.SoftActionRow(container, -by, {
            { text = "Select All", onClick = function()
                SetAllSelections(selectedCDMSpecExports, specEntries, true)
                RefreshProfilesPage()
            end },
            { text = "Clear Selection", onClick = function()
                SetAllSelections(selectedCDMSpecExports, specEntries, false)
                RefreshProfilesPage()
            end },
            { text = "Export Spells", onClick = function()
                local exportString, err = profileMod:ExportCDMSpellsString(CollectSelectedKeys(selectedCDMSpecExports))
                if not exportString then
                    KT:Print(err)
                else
                    profileMod:ShowExportPopup(LText("Export Spells"), exportString)
                end
            end },
            { text = "Import Spells", onClick = function()
                profileMod:ShowImportPopup(
                    LText("Import CDM Spell Profile"),
                    LText("|cffff5555This overwrites imported CDM specs.|r"),
                    function(text)
                        if Report(profileMod:ImportCDMSpellsString(text)) then RefreshProfilesPage() end
                    end
                )
            end },
        }); by = by + h
        return by
    end)

    -- Quick Setup (formerly its own tab): the resolution layout installers.
    if ns.ProfileData and ns.Handlers then
        AddSection("Quick Setup", function(container)
            local by = 0
            _, h = W:Label(container, "|cffFF5555Warning:|r These installers overwrite the target profile and reload the UI.", -by, 11); by = by + h
            local buttons = {}
            for _, res in ipairs({ "1080p", "2K", "4K" }) do
                local preset = res
                buttons[#buttons + 1] = {
                    text = LTextFmt("%s Layout", preset),
                    confirm = true,
                    confirmText = LTextFmt("Apply %s layout? UI will reload.", preset),
                    onClick = function()
                        ns.Handlers.Layout("KullThranUI", ns.ProfileData.Layouts[preset])
                        KT:ForceSetProfile("KullThranUI", "KullThranUI")
                        ReloadUI()
                    end,
                }
            end
            _, h = ns.ProfileUI.SoftActionRow(container, -by, buttons); by = by + h
            return by
        end)
    end

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

-- The options page each Manage Modules row opens from its minimap button.
local MODULE_ROW_PAGES = {
    ["Skins"] = "skins", ["Minimap"] = "minimap", ["Action Bars"] = "actionbars",
    ["Buffs & Debuffs"] = "buffs", ["Cast Bar"] = "castbar", ["Tooltip"] = "tooltip",
    ["Armory"] = "armory", ["Dragon Riding"] = "dragonriding", ["Experience Bar"] = "expbar",
    ["Chat"] = "chat", ["Bags"] = "bags", ["Objective Tracker"] = "objectivetracker",
    ["External Addons"] = "external", ["Unit Frames"] = "unitframes",
    ["Party Frames"] = "partyframes", ["Cursor"] = "cursor", ["Inspect Armory"] = "inspectarmory",
    ["Aura Reminders"] = "aurareminders", ["Nameplates"] = "nameplates",
    ["Cooldown Manager"] = "cooldownmanager", ["Resource Bars"] = "resourcebars",
    ["Teleport Menu"] = "teleportmenu", ["Enhancements"] = "enhancements",
}

-- Some rows carry a localized label: find their page through the English key.
local function ModuleRowPage(label)
    if MODULE_ROW_PAGES[label] then return MODULE_ROW_PAGES[label] end
    for key, pageId in pairs(MODULE_ROW_PAGES) do
        if LocalizeText(key) == label then return pageId end
    end
    return nil
end

-- Parts of a module listed under it ("   - Damage Meter"): their own icons.
local ENHANCEMENT_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\EnhacementsIcons\\"
local MODULE_PART_ICONS = {
    ["Damage Meter"] = ENHANCEMENT_ICON_PATH .. "DamageMeter.tga",
    ["Mythic+ Timer"] = ENHANCEMENT_ICON_PATH .. "MythicPlusTimer.tga",
}
local function ModulePartIcon(label)
    for key, icon in pairs(MODULE_PART_ICONS) do
        if key == label or LocalizeText(key) == label then return icon end
    end
    return nil
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
        { label = "Resource Bars", get = function() return KT.db.profile.resourceBars.enabled ~= false and (KT.db.profile.resourceBars.primary.enabled or KT.db.profile.resourceBars.secondary.enabled or KT.db.profile.resourceBars.health.enabled) and true or false end, set = function(v) KT.db.profile.resourceBars.enabled = v and true or false; KT.db.profile.resourceBars.primary.enabled = v; KT.db.profile.resourceBars.secondary.enabled = v; KT.db.profile.resourceBars.health.enabled = v; Reload() end },
}

    _, h = W:SectionHeader(sc, "Manage Modules", -y); y = y + h
    _, h = W:Label(sc, "Turn each module on or off, and give it a button in the minimap's button drawer that opens its options. A reload is recommended after turning a module on or off.", -y, 11); y = y + h

    -- Two modules per row: the module's icon and switch, and a small wheel
    -- switch for its button in the minimap's button drawer.
    KT.db.profile.minimapButton = KT.db.profile.minimapButton or {}
    local drawerDb = KT.db.profile.minimapButton
    drawerDb.moduleIcons = drawerDb.moduleIcons or {}
    local function RefreshDrawer()
        local M = KT:GetModule("MinimapButton", true)
        if M and M.buttonBag and M.CollectButtons then M:CollectButtons() end
    end
    local function MinimapIconAccess(entry)
        local pageId = ModuleRowPage(entry.label)
        if not (pageId and KT:GetModuleLauncher(pageId)) then return nil end
        return function() return drawerDb.moduleIcons[pageId] == true end,
            function(v) drawerDb.moduleIcons[pageId] = v and true or nil; RefreshDrawer() end
    end

    local MINIMAP_GLYPH = ICON_PATH .. (ns.PAGE_ICON_MAP.minimap or "Minimap") .. ".png"
    local function DecorateModuleRow(control, entry)
        if not control then return end
        local pageId = ModuleRowPage(entry.label)
        local iconName = pageId and ns.PAGE_ICON_MAP[pageId]
        local partIcon = entry.part and ModulePartIcon(entry.label)
        local labelLeft = 12
        if iconName or partIcon then
            local icon = control:CreateTexture(nil, "ARTWORK")
            if partIcon then
                icon:SetTexture(partIcon)
                icon:SetSize(16, 16)
                icon:SetPoint("LEFT", control, "LEFT", 12, 0)
                icon:SetVertexColor(GetMenuIconVertexColor(""))
            else
                icon:SetTexture(ICON_PATH .. iconName .. ".png")
                icon:SetSize(21, 14)
                icon:SetPoint("LEFT", control, "LEFT", 10, 0)
                icon:SetVertexColor(GetMenuIconVertexColor(iconName))
            end
            labelLeft = 38
        end
        local get, set = MinimapIconAccess(entry)
        local reserved = 68
        if get then
            -- Left of the module's switch: a minimap glyph and the wheel.
            local wheel = W:WheelSwitch(control, get, set, {
                tooltip = "Minimap Icon",
                tooltipText = "A button in the minimap's button drawer that opens this module's options.",
            })
            wheel:SetPoint("RIGHT", control, "RIGHT", -56, 0)
            local glyph = control:CreateTexture(nil, "ARTWORK")
            glyph:SetTexture(MINIMAP_GLYPH)
            glyph:SetSize(18, 12)
            glyph:SetPoint("RIGHT", wheel, "LEFT", -6, 0)
            glyph:SetVertexColor(0.62, 0.62, 0.68, 0.9)
            reserved = 68 + 52 + 32
        end
        local label = control._label
        if label then
            label:ClearAllPoints()
            label:SetPoint("LEFT", control, "LEFT", labelLeft, 0)
            label:SetWidth(math.max(40, (control:GetWidth() or 200) - labelLeft - reserved))
        end
    end

    -- A module's parts ("   - Damage Meter") share its row: the module on the
    -- left half, its parts side by side on the right half.
    local items = {}
    for _, entry in ipairs(toggles) do
        local partLabel = entry.label:match("^%s+%-%s+(.+)$")
        local owner = items[#items]
        if partLabel and owner then
            owner.parts = owner.parts or {}
            owner.parts[#owner.parts + 1] = { label = partLabel, get = entry.get, set = entry.set, part = true }
        else
            items[#items + 1] = { entry = entry }
        end
    end

    local function ToggleSpec(entry)
        return { type = "toggle", text = entry.label, getValue = entry.get, setValue = entry.set }
    end
    local pending
    local function FlushPair(right)
        if not pending then return end
        local row
        row, h = W:DualRow(sc, -y, ToggleSpec(pending), right and ToggleSpec(right) or nil); y = y + h
        DecorateModuleRow(row._leftRegion and row._leftRegion._control, pending)
        if right then DecorateModuleRow(row._rightRegion and row._rightRegion._control, right) end
        pending = nil
    end
    for _, item in ipairs(items) do
        if item.parts then
            FlushPair(nil)
            local row
            row, h = W:DualRow(sc, -y, ToggleSpec(item.entry), nil)
            DecorateModuleRow(row._leftRegion and row._leftRegion._control, item.entry)
            local half = row._rightRegion
            local count = #item.parts
            local slot = ((half:GetWidth() or 0) - 20) / count
            for index, part in ipairs(item.parts) do
                local holder = CreateFrame("Frame", nil, half)
                holder._ktNoRowBg = true
                holder:SetSize(slot + 20, h)
                holder:SetPoint("TOPLEFT", half, "TOPLEFT", (index - 1) * slot, 0)
                local control = W:Toggle(holder, part.label, 0, part.get, part.set)
                DecorateModuleRow(control, part)
            end
            y = y + h
        elseif pending then
            FlushPair(item.entry)
        else
            pending = item.entry
        end
    end
    FlushPair(nil)

    return y
end

RegisterPage("general", "General", 10, function(sc, W)
    local y, h = 0, 0

    EnsureProfileState()
    _, h = AddSubTabBar(sc, -y); y = y + h

    if generalSubTab == "general" then
        y = BuildGeneralCore(sc, W, y)
    elseif generalSubTab == "kuimove" then
        y = BuildKUIMoveTab(sc, W, y)
    elseif generalSubTab == "compatibility" then
        y = BuildCompatibilityTab(sc, W, y)
    elseif generalSubTab == "profiles" then
        y = BuildProfilesTab(sc, W, y)
    elseif generalSubTab == "quicksetup" then
        generalSubTab = "profiles"
        y = BuildProfilesTab(sc, W, y)
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
