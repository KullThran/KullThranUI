local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local SHAPE_KEYS = {
    "shapeBar1", "shapeBar2", "shapeBar3", "shapeBar4", "shapeBar5",
    "shapeBar6", "shapeBar7", "shapeBar8", "shapePet", "shapeStance",
}

local function GetProfile()
    return KT.db and KT.db.profile and KT.db.profile.actionbars
end

KT.VisualThemes:RegisterModule("actionbars", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = function()
        local paths = { "buttonStyle", "buttonShape", "buttonBackdropColor", "frameArtKit" }
        for _, key in ipairs(SHAPE_KEYS) do paths[#paths + 1] = key end
        return paths
    end,
    seed = function(profile, themeKey)
        for _, key in ipairs(SHAPE_KEYS) do profile[key] = "GLOBAL" end
        if themeKey == "classic" then
            profile.buttonStyle = "BLIZZARD"
            profile.buttonShape = "NONE"
            profile.buttonBackdropColor = { r = 0.13, g = 0.09, b = 0.05, a = 1 }
            profile.frameArtKit = "classic"
        elseif themeKey == "forever" then
            profile.buttonStyle = "SIMPLICITY"
            profile.buttonShape = "CIRCLE"
            profile.buttonBackdropColor = { r = 0.12, g = 0.08, b = 0.03, a = 1 }
            profile.frameArtKit = "default"
        elseif themeKey == "retail" then
            profile.buttonStyle = "BLIZZARD"
            profile.buttonShape = "NONE"
            profile.buttonBackdropColor = { r = 0.02, g = 0.03, b = 0.06, a = 1 }
            profile.frameArtKit = "retail"
        else
            profile.buttonStyle = "KUI"
            profile.buttonShape = "NONE"
            profile.buttonBackdropColor = { r = 0, g = 0, b = 0, a = 1 }
            profile.frameArtKit = "default"
        end
    end,
    validate = function(profile, themeKey)
        local styles = { BLIZZARD = true, KUI = true, SIMPLICITY = true }
        local shapes = { NONE = true, CIRCLE = true, CSQUARE = true, HEXAGON = true, DIAMOND = true, SHIELD = true }
        if not styles[profile.buttonStyle] then profile.buttonStyle = "BLIZZARD" end
        if not shapes[profile.buttonShape] then profile.buttonShape = "NONE" end
        -- frameArtKit is the user's choice (Action Bar Art cards); only repair invalid values.
        local kits = { default = true, classic = true, retail = true }
        if not kits[profile.frameArtKit] then
            profile.frameArtKit = themeKey == "classic" and "classic"
                or (themeKey == "retail" and "retail" or "default")
        end
    end,
})
