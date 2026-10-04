local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local function GetProfile()
    if not (KT.db and KT.db.profile) then return nil end
    KT.db.profile.cooldownManager = KT.db.profile.cooldownManager or {}
    return KT.db.profile.cooldownManager
end

local function GetPaths(_, _, profile)
    local paths = { "reskinBorders", "cdmBars.barDefaults.iconShape", "cdmBars.barDefaults.frameArtKit" }
    local bars = profile and profile.cdmBars and profile.cdmBars.bars
    local barCount = math.max(4, type(bars) == "table" and #bars or 0)
    for index = 1, barCount do
        paths[#paths + 1] = "cdmBars.bars." .. index .. ".iconShape"
        paths[#paths + 1] = "cdmBars.bars." .. index .. ".borderSize"
        paths[#paths + 1] = "cdmBars.bars." .. index .. ".borderR"
        paths[#paths + 1] = "cdmBars.bars." .. index .. ".borderG"
        paths[#paths + 1] = "cdmBars.bars." .. index .. ".borderB"
        paths[#paths + 1] = "cdmBars.bars." .. index .. ".frameArtKit"
    end
    return paths
end

KT.VisualThemes:RegisterModule("cooldownmanager", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = GetPaths,
    seed = function(profile, themeKey)
        local shape, borderSize, r, g, b, frameArtKit
        if themeKey == "classic" then
            shape, borderSize, r, g, b, frameArtKit = "square", 1, 0, 0, 0, "default"
        elseif themeKey == "forever" then
            shape, borderSize, r, g, b, frameArtKit = "circle", 1, 0, 0, 0, "default"
        elseif themeKey == "retail" then
            shape, borderSize, r, g, b, frameArtKit = "csquare", 1, 0, 0, 0, "default"
        else
            -- kui: reset the classic-border field to the module's own default
            -- ("default", see KUICooldownManager.lua barDefaults) so a stale
            -- "classic" value can never survive into kui.
            shape, borderSize, r, g, b, frameArtKit = "none", 1, 0, 0, 0, "default"
        end
        profile.reskinBorders = (themeKey ~= "classic" and themeKey ~= "forever")
        profile.cdmBars = profile.cdmBars or {}
        profile.cdmBars.barDefaults = profile.cdmBars.barDefaults or {}
        profile.cdmBars.barDefaults.iconShape = shape
        profile.cdmBars.barDefaults.borderSize = borderSize
        profile.cdmBars.barDefaults.borderR = r
        profile.cdmBars.barDefaults.borderG = g
        profile.cdmBars.barDefaults.borderB = b
        if frameArtKit then
            profile.cdmBars.barDefaults.frameArtKit = frameArtKit
        end
        profile.cdmBars.bars = profile.cdmBars.bars or {}
        for index = 1, 4 do
            profile.cdmBars.bars[index] = profile.cdmBars.bars[index] or {}
        end
        -- Under Classic, Utility and Cooldowns default to no icon
        -- shape/mask (plain square icons), not the theme's general
        -- "square" masked shape used for other bars (e.g. Buffs).
        local noShapeBarKeys = { cooldowns = true, utility = true }
        for _, bar in ipairs(profile.cdmBars.bars) do
            bar.iconShape = (themeKey == "classic" and noShapeBarKeys[bar.key]) and "none" or shape
            bar.borderSize = borderSize
            bar.borderR, bar.borderG, bar.borderB = r, g, b
            if frameArtKit then
                bar.frameArtKit = frameArtKit
            end
        end
    end,
    validate = function(profile)
        -- Icon borders, reskin and frame art are the user's to edit in every style (the theme
        -- only seeds them); here we just repair invalid shapes.
        local valid = { none = true, cropped = true, square = true, circle = true, csquare = true, diamond = true, hexagon = true, portrait = true, shield = true }
        for _, bar in ipairs(profile.cdmBars and profile.cdmBars.bars or {}) do
            if not valid[bar.iconShape] then bar.iconShape = "none" end
        end
    end,
})
