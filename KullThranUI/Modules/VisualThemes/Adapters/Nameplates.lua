local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local function GetProfile()
    local profile = _G.KullThranUINameplatesDB
    if type(profile) ~= "table" then profile = _G.KullThranUINameplatesDB_Forever end
    if type(profile) ~= "table" then
        if not (KT.db and KT.db.profile) then return nil end
        profile = {}
        _G.KullThranUINameplatesDB = profile
    end
    return profile
end

-- Enemy plate geometry written by the nameplate style presets. Listed as owned
-- so each style keeps its own sizes (KullThranUI Style keeps the player's).
local SIZE_KEY_PREFIXES = { "healthBar", "castBar", "cast", "enemyName", "level", "name", "classPower",
    "textSlot", "raidMarker", "rareElite", "targetArrow", "focusCast" }

-- Keys the KullThranUI Style seed restores from the nameplate module's own defaults.
local KUI_DEFAULT_KEYS = {
    "healthBarTexture", "friendlyPlayerHealthTexture", "friendlyNPCHealthTexture", "castBarTexture",
    "borderStyle", "borderColor", "targetGlowStyle", "hostile", "enemyInCombat", "friendly", "neutral",
    "miniboss", "boss", "elite", "trivial",
}

KT.VisualThemes:RegisterModule("nameplates", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = function(_, _, profile)
        local paths = {
            "healthBarTexture", "friendlyPlayerHealthTexture", "friendlyNPCHealthTexture",
            "castBarTexture", "classPowerShape", "borderStyle", "borderColor", "targetGlowStyle",
            "hostile", "enemyInCombat", "friendly", "neutral", "miniboss", "boss", "elite", "trivial",
            "nameplateStyle", "classPowerPos",
        }
        local seen = {}
        for _, path in ipairs(paths) do seen[path] = true end
        if type(profile) == "table" then
            for key, value in pairs(profile) do
                if type(key) == "string" and not seen[key] and type(value) ~= "table"
                    and not key:find("^friendly") then
                    for _, prefix in ipairs(SIZE_KEY_PREFIXES) do
                        if key:sub(1, #prefix) == prefix then
                            paths[#paths + 1] = key
                            seen[key] = true
                            break
                        end
                    end
                end
            end
        end
        return paths
    end,
    seed = function(profile, themeKey)
        profile.classPowerShape = (themeKey == "kui" or (themeKey ~= "classic" and themeKey ~= "forever" and themeKey ~= "retail")) and "pip" or "circle"
        if themeKey == "classic" then
            profile.healthBarTexture = "Blizzard"
            profile.friendlyPlayerHealthTexture = "Blizzard"
            profile.friendlyNPCHealthTexture = "Blizzard"
            profile.castBarTexture = "Blizzard"
            profile.borderStyle = "simple"
            profile.borderColor = { r = 0.28, g = 0.18, b = 0.07 }
            profile.targetGlowStyle = "vibrant"
            profile.hostile = { r = 0.82, g = 0.07, b = 0.07 }
            profile.friendly = { r = 0.10, g = 0.75, b = 0.10 }
            profile.neutral = { r = 0.95, g = 0.85, b = 0.10 }
            profile.miniboss = { r = 1.00, g = 0.28, b = 0.20 }
            profile.boss = { r = 0.95, g = 0.20, b = 0.25 }
            profile.elite = { r = 1.00, g = 0.68, b = 0.18 }
            profile.trivial = { r = 0.68, g = 0.68, b = 0.68 }
        elseif themeKey == "forever" then
            profile.healthBarTexture = "Melli Dark"
            profile.friendlyPlayerHealthTexture = "Melli Dark"
            profile.friendlyNPCHealthTexture = "Melli Dark"
            profile.castBarTexture = "Melli Dark"
            profile.borderStyle = "kullthran"
            profile.borderColor = { r = 0.82, g = 0.65, b = 0.23 }
            profile.targetGlowStyle = "kullthranui"
            profile.hostile = { r = 1.00, g = 0.00, b = 0.00 }
            profile.friendly = { r = 0.25, g = 0.90, b = 0.40 }
            profile.neutral = { r = 1.00, g = 0.78, b = 0.18 }
            profile.miniboss = { r = 1.00, g = 0.34, b = 0.20 }
            profile.boss = { r = 1.00, g = 0.30, b = 0.20 }
            profile.elite = { r = 1.00, g = 0.72, b = 0.25 }
            profile.trivial = { r = 0.72, g = 0.72, b = 0.72 }
        elseif themeKey == "retail" then
            profile.healthBarTexture = "Blizzard Raid Bar"
            profile.friendlyPlayerHealthTexture = "Blizzard Raid Bar"
            profile.friendlyNPCHealthTexture = "Blizzard Raid Bar"
            profile.castBarTexture = "Blizzard Raid Bar"
            profile.borderStyle = "none"
            profile.borderColor = { r = 0.03, g = 0.05, b = 0.09 }
            profile.targetGlowStyle = "none"
            profile.hostile = { r = 1.00, g = 0.00, b = 0.00 }
            profile.friendly = { r = 0.20, g = 0.90, b = 0.35 }
            profile.neutral = { r = 1.00, g = 0.76, b = 0.18 }
            profile.miniboss = { r = 1.00, g = 0.34, b = 0.20 }
            profile.boss = { r = 1.00, g = 0.30, b = 0.20 }
            profile.elite = { r = 1.00, g = 0.72, b = 0.25 }
            profile.trivial = { r = 0.70, g = 0.70, b = 0.70 }
        else
            -- KullThranUI Style: exactly the Retail nameplate defaults, never a separate look.
            local defaults = _G.KullThranUINameplatesDefaults
            if type(defaults) == "table" then
                for _, key in ipairs(KUI_DEFAULT_KEYS) do
                    local v = defaults[key]
                    if type(v) == "table" then
                        local copy = {}
                        for k2, v2 in pairs(v) do copy[k2] = v2 end
                        profile[key] = copy
                    else
                        profile[key] = v
                    end
                end
                return
            end
            profile.healthBarTexture = "Melli Reforged"
            profile.friendlyPlayerHealthTexture = "Melli Reforged"
            profile.friendlyNPCHealthTexture = "Melli Reforged"
            profile.castBarTexture = "Melli Reforged"
            profile.borderStyle = "kullthran"
            profile.borderColor = { r = 0.067, g = 0.067, b = 0.067 }
            profile.targetGlowStyle = "kullthranui"
            profile.hostile = { r = 0.85, g = 0.10, b = 0.10 }
            profile.friendly = { r = 0.22, g = 0.90, b = 0.38 }
            profile.neutral = { r = 1.00, g = 0.78, b = 0.18 }
            profile.miniboss = { r = 1.00, g = 0.34, b = 0.20 }
            profile.boss = { r = 1.00, g = 0.30, b = 0.20 }
            profile.elite = { r = 1.00, g = 0.72, b = 0.25 }
            profile.trivial = { r = 0.70, g = 0.70, b = 0.70 }
        end
        -- the plate fill of a generic enemy comes from enemyInCombat (GetReactionColor fallback), not
        -- from "hostile" (only used by the optional color override): follow the theme's hostile color
        if type(profile.hostile) == "table" then
            profile.enemyInCombat = { r = profile.hostile.r, g = profile.hostile.g, b = profile.hostile.b }
        end
    end,
    validate = function(profile)
        local valid = { kullthran = true, simple = true, none = true }
        if not valid[profile.borderStyle] then profile.borderStyle = "kullthran" end
        local glowStyles = { kullthranui = true, vibrant = true, none = true }
        if not glowStyles[profile.targetGlowStyle] then profile.targetGlowStyle = "kullthranui" end
    end,
})
