local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local BLIZZARD_BAR_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local KUI_BAR_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"

local function GetProfile()
    local enhancements = KT:GetModule("Enhancements", true)
    local db = enhancements and enhancements.GetDB and enhancements:GetDB()
    if not db then return nil end
    db.damageMeter = db.damageMeter or {}
    return db.damageMeter
end

KT.VisualThemes:RegisterModule("damagemeter", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = function()
        return { "barTexture", "showBackground" }
    end,
    -- classic/retail/forever share the same real "Blizzard style" bar texture.
    -- The header/border recolor (gold for classic/retail, bronze for forever)
    -- lives in ThemeEngine:GetDamageMeterAccentColor, not in the seed, so
    -- class colors and any user texture choice under kui stay untouched.
    seed = function(profile, themeKey)
        if themeKey == "classic" or themeKey == "retail" or themeKey == "forever" then
            profile.barTexture = BLIZZARD_BAR_TEXTURE
            profile.showBackground = true
        else
            profile.barTexture = KUI_BAR_TEXTURE
            profile.showBackground = true
        end
    end,
    validate = function() end,
})
