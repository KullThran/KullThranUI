local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

-- Preset data is available before the optional Cast Bar addon loads.
-- The shared live/preview renderer lives in that module.
local S = {}
KT.CastBarStyles = S
S.order = { "kui", "classic", "forever", "retail" }
S.labels = { kui = "KUI Style", classic = "Classic", forever = "Forever", retail = "Retail" }
S.styleIcons = {
    kui = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUILogoCuadrado.png",
    classic = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\SEDbDUlE_400x400.png",
    retail = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\WoWRetail.png",
    forever = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\EnhacementsIcons\\WoWForever.png",
}
function S:ApplyStyleIcon(icon, key)
    icon:SetTexture(self.styleIcons[key] or self.styleIcons.kui)
    icon:SetVertexColor(1, 1, 1, 1)
end
S.ownedPaths = { "castbarStyle", "width", "height", "scale", "autoWidth", "texture",
    "iconShape", "iconPosition", "showIcon", "classColor", "colorMode", "color", "frameArtKit",
    "font", "fontSize", "fontOutline", "textColor" }

function S:GetStyle(db)
    return db and self.labels[db.castbarStyle] and db.castbarStyle or "kui"
end

function S:ShowsIcon(db)
    return db and db.showIcon ~= false and self:GetStyle(db) ~= "classic"
end

function S:Seed(profile, key)
    key = self.labels[key] and key or "kui"
    profile.castbarStyle = key
    profile.frameArtKit = "default"
    profile.autoWidth, profile.scale = false, 1
    profile.showIcon, profile.iconPosition, profile.iconShape = true, "LEFT", "SQUARE"
    profile.classColor, profile.fontOutline = false, "OUTLINE"
    profile.textColor = { r = 1, g = 1, b = 1, a = 1 }
    if key == "kui" then
        profile.width, profile.height = 250, 20
        profile.autoWidth = true
        profile.texture, profile.colorMode = "Melli", "THEME"
        profile.font = "AAA_ITC_Avant_Garde"
        profile.fontSize = 16
    else
        local classic = key == "classic"
        profile.width, profile.height = classic and 195 or 208, classic and 13 or 17
        profile.texture = classic and "Interface\\TargetingFrame\\UI-StatusBar" or "ui-castingbar-filling-standard"
        profile.colorMode = "CUSTOM"
        profile.color = classic and { r = 1, g = 0.7, b = 0, a = 1 } or { r = 1, g = 1, b = 1, a = 1 }
        profile.font, profile.fontSize = "AAA_ITC_Avant_Garde", classic and 10 or 12
        if classic then profile.showIcon = false end
    end
end

local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = Copy(v) end
    return result
end

function S:Select(profile, key)
    if not self.labels[key] then return end
    if self:GetStyle(profile) == "kui" and key ~= "kui" then
        profile.kuiStyleSettings = {}
        for _, path in ipairs(self.ownedPaths) do profile.kuiStyleSettings[path] = Copy(profile[path]) end
    end
    local saved = profile.kuiStyleSettings
    if key == "kui" and not saved then
        local state = KT.db and KT.db.profile and KT.db.profile.visualTheme
        saved = state and state.slots and state.slots.castbar and state.slots.castbar.kui
    end
    self:Seed(profile, key)
    if key == "kui" and saved then
        for _, path in ipairs(self.ownedPaths) do
            local value = saved[path]
            if value ~= nil and not (type(value) == "table" and value.__ktVisualThemeNil) then
                profile[path] = Copy(value)
            end
        end
        profile.castbarStyle = "kui"
    end
end

local function RepairClassicText(profile)
    if profile.castbarStyle == "classic" then
        profile.showIcon = false
        if not profile._ktClassicCastArtV4 then profile.fontOutline = "OUTLINE" end
        profile._ktClassicCastArtV4 = true
    end
    if profile._ktClassicCastArtV3 then return end
    if profile.castbarStyle == "classic" and profile.width == 195 and profile.height == 13
        and profile.font == "Friz Quadrata TT" and profile.fontSize == 12 then
        profile.fontSize = 10
    end
    profile._ktClassicCastArtV3 = true
end

local function RepairCastFont(profile)
    if profile.font == "Friz Quadrata TT" then profile.font = "AAA_ITC_Avant_Garde" end
end

-- Upgrade only the untouched thin modern preset from the first implementation.
local function RepairNativeArt(profile)
    if (profile.castbarStyle == "forever" or profile.castbarStyle == "retail")
        and profile.texture == "UI-CastingBar-Full-Standard" then
        profile.texture = "ui-castingbar-filling-standard"
    end
    if profile._ktNativeCastArtV2 then return end
    if (profile.castbarStyle == "forever" or profile.castbarStyle == "retail")
        and profile.width == 208 and profile.height == 11 and profile.fontSize == 10 then
        profile.height, profile.fontSize = 17, 12
        profile.texture = "ui-castingbar-filling-standard"
    end
    profile._ktNativeCastArtV2 = true
end

-- Backfill old theme slots once. KUI keeps its saved appearance;
-- the native presets receive the stock size, texture and typography.
function S:Migrate(profile, themeKey)
    local state = KT.db and KT.db.profile and KT.db.profile.visualTheme
    local active = themeKey or (state and state.active) or "kui"
    local slots = state and state.slots and state.slots.castbar
    for key, slot in pairs(slots or {}) do
        if self.labels[key] and slot.castbarStyle == nil then
            local defaults = {}; self:Seed(defaults, key)
            if key == "kui" then
                -- Size, font and class-color controls used to be shared by all
                -- themes, so their current values are the player's KUI choices.
                local previouslyOwned = { texture = true, iconShape = true, colorMode = true,
                    color = true, frameArtKit = true, castbarStyle = true }
                for _, path in ipairs(self.ownedPaths) do
                    if not previouslyOwned[path] and profile[path] ~= nil then defaults[path] = Copy(profile[path]) end
                end
            end
            for _, path in ipairs(self.ownedPaths) do
                if key ~= "kui" or slot[path] == nil then slot[path] = Copy(defaults[path]) end
            end
        end
    end
    for _, slot in pairs(slots or {}) do RepairNativeArt(slot); RepairClassicText(slot); RepairCastFont(slot) end
    if profile.castbarStyle == nil then
        if active == "kui" then profile.castbarStyle = "kui"
        else self:Seed(profile, active) end
    end
    RepairNativeArt(profile)
    RepairClassicText(profile)
    RepairCastFont(profile)
end

local function GetProfile()
    local profile = KT.db and KT.db.profile and KT.db.profile.castbar
    local state = KT.db and KT.db.profile and KT.db.profile.visualTheme
    if profile and (not state or (tonumber(state.schemaVersion) or 0) >= 2) then S:Migrate(profile) end
    return profile
end

KT.VisualThemes:RegisterModule("castbar", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = function() return S.ownedPaths end,
    seed = function(profile, themeKey) S:Seed(profile, themeKey) end,
    validate = function(profile, themeKey)
        S:Migrate(profile, themeKey)
        if not S.labels[profile.castbarStyle] then profile.castbarStyle = "kui" end
        if profile.iconShape ~= "SQUARE" and profile.iconShape ~= "CIRCLE" then profile.iconShape = "SQUARE" end
        local modes = { THEME = true, CLASS = true, CUSTOM = true }
        if not modes[profile.colorMode] then profile.colorMode = "THEME" end
        local broken = { KUI = true, kui = true, retail = true, forever = true, classic = true }
        if broken[profile.texture] then profile.texture = "Melli" end
    end,
})
