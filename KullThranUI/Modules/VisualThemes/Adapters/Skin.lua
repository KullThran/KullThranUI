local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local function GetProfile()
    if not (KT.db and KT.db.profile) then return nil end
    KT.db.profile.skin = KT.db.profile.skin or {}
    return KT.db.profile.skin
end

KT.VisualThemes:RegisterModule("skin", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = function()
        return {
            "borderTheme", "borderThemeBeforeClass", "customBorderColor", "kullthranUIColorByClass",
            "accentColor.r", "accentColor.g", "accentColor.b", "accentColor.a",
        }
    end,
    seed = function(profile, themeKey)
        if themeKey == "classic" then
            profile.borderTheme = "CUSTOM"
            profile.borderThemeBeforeClass = "CUSTOM"
            profile.customBorderColor = { r = 0.86, g = 0.62, b = 0.16, a = 1 }
            profile.kullthranUIColorByClass = false
        elseif themeKey == "forever" then
            profile.borderTheme = "CUSTOM"
            profile.borderThemeBeforeClass = "CUSTOM"
            profile.customBorderColor = { r = 0.862745, g = 0.521569, b = 0.376471, a = 1 } -- #DC8560
            -- Forever's accent defaults to bronze. borderTheme="CUSTOM"
            -- already makes GetStylePalette() use customBorderColor for the
            -- effective accent, but the raw accentColor (the base value
            -- CUSTOM overrides, and what a plain "custom accent color"
            -- picker would show) was left at whatever it was before -- set
            -- it to the same bronze so both read consistently.
            profile.accentColor = { r = 0.862745, g = 0.521569, b = 0.376471, a = 1 } -- #DC8560
            profile.kullthranUIColorByClass = false
        elseif themeKey == "retail" then
            profile.borderTheme = "CLASS"
            profile.borderThemeBeforeClass = "KULLTHRAN"
            profile.kullthranUIColorByClass = true
        else
            profile.borderTheme = "KULLTHRAN"
            profile.borderThemeBeforeClass = "KULLTHRAN"
            profile.kullthranUIColorByClass = false
        end
    end,
    validate = function(profile)
        local valid = { KULLTHRAN = true, CLASS = true, CUSTOM = true }
        if not valid[profile.borderTheme] then profile.borderTheme = "KULLTHRAN" end
        -- Forever's accent moved from the old gold/bronze to #DC8560: migrate stored values.
        local VT = KT.VisualThemes
        if VT and VT.GetRenderedTheme and VT:GetRenderedTheme() == "forever" then
            local function old(c)
                return type(c) == "table" and math.abs((c.r or 0) - 0.82) < 0.01
                    and math.abs((c.g or 0) - 0.65) < 0.01 and math.abs((c.b or 0) - 0.23) < 0.01
            end
            if old(profile.customBorderColor) then
                profile.customBorderColor = { r = 0.862745, g = 0.521569, b = 0.376471, a = 1 }
            end
            if old(profile.accentColor) then
                profile.accentColor = { r = 0.862745, g = 0.521569, b = 0.376471, a = 1 }
            end
        end
    end,
})
