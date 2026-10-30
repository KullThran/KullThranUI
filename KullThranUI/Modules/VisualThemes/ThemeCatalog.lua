local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local ORDER = { "kui", "forever", "retail", "classic" }

local Catalog = {
    kui = {
        name = "KULLTHRANUI STYLE",
        shortName = "KUI",
        description = "Flat KullThranUI frames, textures and colors.",
        color = { r = 1.00, g = 0.49, b = 0.00 },
        accent = { r = 1.00, g = 0.49, b = 0.00 },
        capabilities = { nativeOn = { retail = true, forever = true } },
    },
    forever = {
        name = "WOW FOREVER",
        shortName = "FOREVER ART",
        description = "Bronze accents, round portraits and shaped icons.",
        color = { r = 0.862745, g = 0.521569, b = 0.376471 }, -- #DC8560
        accent = { r = 0.862745, g = 0.521569, b = 0.376471 },
        capabilities = { nativeOn = { forever = true }, emulatedOn = { retail = true } },
    },
    retail = {
        name = "WOW RETAIL",
        shortName = "BLIZZARD MODERN",
        description = "Modern Blizzard bars, clean borders and square icons.",
        color = { r = 0.20, g = 0.58, b = 1.00 },
        accent = { r = 0.20, g = 0.58, b = 1.00 },
        capabilities = { nativeOn = { retail = true }, emulatedOn = { forever = true } },
    },
    classic = {
        name = "WOW CLASSIC",
        shortName = "VANILLA ART",
        description = "Classic textures, attached portraits and square slots.",
        color = { r = 0.92, g = 0.72, b = 0.22 },
        accent = { r = 0.92, g = 0.72, b = 0.22 },
        capabilities = { emulatedOn = { retail = true, forever = true } },
    },
}

function KT.VisualThemes:GetThemeCatalog()
    return Catalog
end

function KT.VisualThemes:GetThemeOrder()
    return ORDER
end

function KT.VisualThemes:IsKnownTheme(themeKey)
    return type(themeKey) == "string" and Catalog[themeKey] ~= nil
end
