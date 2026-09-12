local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:NewModule("GlobalFont", "AceEvent-3.0")
local LSM = LibStub("LibSharedMedia-3.0", true)

local _G = _G
local ipairs = ipairs
local pairs = pairs
local pcall = pcall
local type = type

local INHERITANCE_VERSION = 1
local REFRESH_TARGETS = {
    { "Minimap", "UpdateFonts" },
    { "Armory", "Refresh" },
    { "InspectArmory", "Refresh" },
    { "Bags", "Refresh" },
    { "CastBar", "Refresh" },
    { "Chat", "Refresh" },
    { "DragonRiding", "Refresh" },
{ "Enhancements", "RefreshCombatTextStyle" },
    { "BuffsAndDebuffs", "Refresh" },
    { "ActionBars", "StyleAllBars" },
    { "TeleportMenu", "Refresh" },
    { "Tooltip", "Refresh" },
    { "ExperienceBar", "Refresh" },
    { "UnitFrames", "Refresh" },
    { "PartyFrames", "RefreshAll" },
    { "ResourceBars", "RebuildFromAnchor" },
    { "EscapeMenu", "RequestRefresh" },
}

-- Lista de objetos de fuente globales de WoW
local FONT_OBJECTS = {
    "SystemFont_InverseShadow_Small", -- Removed SystemFont_Outline/Small to avoid UIWidget taint
    "SystemFont_Med1", "SystemFont_Med2", "SystemFont_Med3", "SystemFont_Large",
    "SystemFont_Huge1", "SystemFont_OutlineThick_Huge2", "SystemFont_OutlineThick_Huge4",
    "SystemFont_OutlineThick_WTF", "NumberFont_OutlineThick_Mono_Small",
    "NumberFont_Outline_Huge", "NumberFont_Outline_Large", "NumberFont_Outline_Med",
    "NumberFont_Shadow_Med", "NumberFont_Shadow_Small", "QuestFont_Large",
    "QuestFont_Huge", "QuestFont_Shadow_Huge", "QuestFont_Super_Huge",
    "QuestFont_Outline_Huge", "GameFont_Gigantic", "ChatFontNormal", "ChatFontSmall",
    "GameFontNormal", "GameFontNormalSmall", "GameFontNormalMed3", "GameFontNormalLarge",
    "GameFontNormalHuge", "GameFontHighlight", "GameFontHighlightSmall",
    "GameFontHighlightLarge", "GameFontDisable", "GameFontDisableSmall",
    "GameFontGreen", "GameFontGreenSmall", "GameFontRed", "GameFontRedSmall",
    "GameFontWhite", "GameFontDarkGraySmall",
    -- Adicionales comunes
    "RaidWarningFrameSlot1", "RaidWarningFrameSlot2",
    "ZoneTextFont", "SubZoneTextFont", "PVPInfoTextFont", 
    -- NOTE: TextStatusBarText and CombatLogFont are excluded to prevent DamageMeter taint.
    -- Modifying these from addon code taints "secret" combat-log strings used by
    -- DamageMeterEntry FontStrings, causing the error:
    --   attempt to compare local 'text' (a secret string value tainted by KullThranUI)
    "ErrorFont",
    "Tooltip_Med", "Tooltip_Small",
}

function Mod:OnInitialize()
    if not KT.db.profile.globalFont then
        KT.db.profile.globalFont = {
            font = (KT.GetDefaultFontName and KT:GetDefaultFontName()) or "Friz Quadrata TT",
        }
    end
    self.db = KT.db.profile.globalFont
end

function Mod:OnEnable()
    self:InitializeInheritance()
    self:ApplyGlobalFont()
    -- Module DBs (castbar, experienceBar, ...) merge their font defaults during
    -- module initialization, which runs AFTER core OnInitialize. Re-run the
    -- locale normalization here so stored Avant Garde names/paths are swapped to
    -- the compatible localized font on koKR/zhTW/zhCN/ruRU, then force a refresh.
    if KT.NormalizeProfileFontsForLocale then
        KT:NormalizeProfileFontsForLocale()
    end
    if KT.RefreshFontPath then
        KT:RefreshFontPath()
    end
end

function Mod:InitializeInheritance()
    local currentFont = self.db.font or KT.DEFAULT_FONT_NAME
    if self.db.inheritanceVersion ~= INHERITANCE_VERSION then
        self:SyncInheritedProfileFonts(self.db.inheritanceSource or KT.DEFAULT_FONT_NAME, currentFont, true)
    end
    self.db.inheritanceSource = currentFont
    self.db.inheritanceVersion = INHERITANCE_VERSION
end

function Mod:SyncInheritedProfileFonts(previousFont, nextFont, includeDefaults)
    local profile = KT.db and KT.db.profile
    if type(profile) ~= "table" or type(nextFont) ~= "string" or nextFont == "" then return end

    local defaultFont = KT.DEFAULT_FONT_NAME
    local localizedFont = KT.LOCALIZED_FONT_NAME
    local seen = {}

    local function Visit(tbl)
        if seen[tbl] then return end
        seen[tbl] = true

        for key, value in pairs(tbl) do
            if tbl == profile and key == "globalFont" then
                -- The global font table contains the inheritance metadata itself.
            elseif type(value) == "table" then
                Visit(value)
            elseif type(key) == "string" and type(value) == "string" then
                local isFontSetting = key:lower():find("font", 1, true) ~= nil
                local followsPrevious = value == previousFont
                local followsDefault = includeDefaults and (value == defaultFont or value == localizedFont)
                if isFontSetting and (followsPrevious or followsDefault) then
                    tbl[key] = nextFont
                end
            end
        end
    end

    Visit(profile)
    self.db.inheritanceSource = nextFont
    self.db.inheritanceVersion = INHERITANCE_VERSION
end

function Mod:ApplyGlobalFont()
    local fontName = self.db.font
    local interfaceFont = self.db.interfaceFont
    local appliedFont = (type(interfaceFont) == "string" and interfaceFont ~= "") and interfaceFont or fontName
    local fontPath, resolvedName

    if KT.ResolveFontPath then
        fontPath, resolvedName = KT:ResolveFontPath(appliedFont)
    elseif LSM then
        fontPath = LSM:Fetch("font", appliedFont)
    end

    if not fontPath or fontPath == "" then
        fontPath = "Fonts\\FRIZQT__.TTF"
    end

    if KT.RefreshFontPath then
        KT:RefreshFontPath(appliedFont)
    else
        KT.FONT_PATH = fontPath
    end

    if not interfaceFont and resolvedName and (not self.db.font or self.db.font == KT.DEFAULT_FONT_NAME) then
        self.db.font = resolvedName
    end

    -- TAINT SAFETY: Do NOT call SetFont() on global Blizzard font objects.
    -- Those objects (GameFontNormal, GameFontHighlight, NumberFont_*, etc.) are
    -- inherited by FontStrings in Blizzard secure UI systems (DamageMeter SessionTimer,
    -- CombatLog, etc.). Modifying them from addon code taints the font objects and
    -- propagates taint to any value those FontStrings contain or compare, causing:
    --   "attempt to compare local 'durationSeconds' (a secret number value tainted by KullThranUI)"
    -- in DamageMeterSessionWindow.lua:871 SetSessionDuration().
    --
    -- KT.FONT_PATH is set above so individual modules can apply the custom font
    -- directly to FontStrings they own (via fs:SetFont(KT.FONT_PATH, size, flags)).
    -- do NOT re-enable this loop.
    --
    -- for _, objectName in ipairs(FONT_OBJECTS) do
    --     local fontObject = _G[objectName]
    --     if fontObject and fontObject.SetFont then
    --         local _, size, flags = fontObject:GetFont()
    --         if size then fontObject:SetFont(fontPath, size, flags) end
    --     end
    -- end
end

function Mod:SetFont(fontName)
    local previousFont = self.db.inheritanceSource or self.db.font or KT.DEFAULT_FONT_NAME
    self:SyncInheritedProfileFonts(previousFont, fontName, self.db.inheritanceVersion ~= INHERITANCE_VERSION)
    self.db.font = fontName
    self:ApplyGlobalFont()
    self:QueueConsumerRefresh()
end

function Mod:SetInterfaceFont(fontName)
    self.db.interfaceFont = (type(fontName) == "string" and fontName ~= "") and fontName or nil
    self:ApplyGlobalFont()
    self:QueueConsumerRefresh()
end

function Mod:RefreshConsumers()
    for _, target in ipairs(REFRESH_TARGETS) do
        local module = KT:GetModule(target[1], true)
        local refresh = module and module[target[2]]
        if refresh and (not module.IsEnabled or module:IsEnabled()) then
            pcall(refresh, module)
        end
    end

    if KT.ObjectiveTrackerSkin_Refresh then
        pcall(KT.ObjectiveTrackerSkin_Refresh)
    end
    local enhancements = KT:GetModule("Enhancements", true)
    local friendList = enhancements and enhancements.EnhancedFriendList
    if friendList and friendList.Refresh then
        pcall(friendList.Refresh, friendList, false)
    end
    if KT.RefreshMenuFonts then
        pcall(KT.RefreshMenuFonts, KT)
    end
    if KT.RefreshPage then
        pcall(KT.RefreshPage, KT, true)
    end
end

function Mod:QueueConsumerRefresh()
    if InCombatLockdown and InCombatLockdown() then
        self.pendingConsumerRefresh = true
        self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerRegenEnabled")
        return
    end

    if self.consumerRefreshQueued then return end
    self.consumerRefreshQueued = true

    C_Timer.After(0, function()
        if self then self.consumerRefreshQueued = nil end
        if self and self:IsEnabled() then
            self:RefreshConsumers()
        end
    end)
end

function Mod:OnPlayerRegenEnabled()
    if not self.pendingConsumerRefresh then return end
    self.pendingConsumerRefresh = nil
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:QueueConsumerRefresh()
end

function Mod:GetOptions()
    local fonts = {}
    if LSM then
        for _, font in ipairs(LSM:List("font")) do
            if not KT.IsFontOptionVisible or KT:IsFontOptionVisible(font) then
                fonts[font] = (font == "Friz Quadrata TT") and "Friz Quadrata TT (Blizzard)" or font
            end
        end
    else
        fonts["Friz Quadrata TT"] = "Friz Quadrata TT (Blizzard)"
    end

    return {
        name = "Global Font",
        type = "group",
        args = {
            header = { order = 1, type = "header", name = "Global Font Settings" },
            desc = { order = 2, type = "description", name = "Select the font to be applied to all UI elements." },
            font = {
                order = 3, type = "select", name = "Font",
                desc = "Select the global font.",
                values = fonts,
                get = function() return self.db.font end,
                set = function(_, value) self:SetFont(value) end,
            },
            reload = { order = 4, type = "execute", name = "Reload UI", func = function() ReloadUI() end },
        }
    }
end
