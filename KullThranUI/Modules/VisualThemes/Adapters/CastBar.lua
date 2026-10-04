local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local function GetProfile()
    return KT.db and KT.db.profile and KT.db.profile.castbar
end

KT.VisualThemes:RegisterModule("castbar", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = function()
        return { "texture", "iconShape", "colorMode", "color", "frameArtKit" }
    end,
    seed = function(profile, themeKey)
        if themeKey == "classic" then
            profile.texture = "Blizzard"
            profile.iconShape = "SQUARE"
            profile.colorMode = "CUSTOM"
            profile.color = { r = 0.86, g = 0.62, b = 0.16, a = 1 }
            profile.frameArtKit = "classic"
        elseif themeKey == "forever" then
            profile.texture = "Melli Dark"
            profile.iconShape = "CIRCLE"
            profile.colorMode = "CUSTOM"
            profile.color = { r = 0.82, g = 0.65, b = 0.23, a = 1 }
            profile.frameArtKit = "default"
        elseif themeKey == "retail" then
            profile.texture = "Blizzard Raid Bar"
            profile.iconShape = "SQUARE"
            profile.colorMode = "CUSTOM"
            profile.color = { r = 0.12, g = 0.48, b = 0.95, a = 1 }
            profile.frameArtKit = "default"
        else
            profile.texture = "Melli"
            profile.iconShape = "SQUARE"
            profile.colorMode = "THEME"
            -- kui: reset the classic-border field to CastBar's own default
            -- (CastBar.lua defaults: frameArtKit = "default").
            profile.frameArtKit = "default"
        end
    end,
    validate = function(profile)
        if profile.iconShape ~= "SQUARE" and profile.iconShape ~= "CIRCLE" then
            profile.iconShape = "SQUARE"
        end
        local modes = { THEME = true, CLASS = true, CUSTOM = true }
        if not modes[profile.colorMode] then profile.colorMode = "THEME" end
        local brokenTextures = { KUI = true, kui = true, retail = true, forever = true, classic = true }
        if brokenTextures[profile.texture] then profile.texture = "Melli" end
    end,
})
