local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local MODES = { "party", "raid", "raid40", "arena", "arenaEnemy", "boss" }

local function GetProfile()
    if not (KT.db and KT.db.profile) then return nil end
    KT.db.profile.partyFrames = KT.db.profile.partyFrames or {}
    return KT.db.profile.partyFrames
end

KT.VisualThemes:RegisterModule("partyframes", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = function()
        local paths = {}
        for _, mode in ipairs(MODES) do
            paths[#paths + 1] = mode .. ".healthTexture"
            paths[#paths + 1] = mode .. ".absorbBarTexture"
            paths[#paths + 1] = mode .. ".absorbBarColor.r"
            paths[#paths + 1] = mode .. ".absorbBarColor.g"
            paths[#paths + 1] = mode .. ".absorbBarColor.b"
        end
        return paths
    end,
    seed = function(profile, themeKey)
        -- healthTexture/absorbBarTexture are already one shared value written
        -- to all 6 modes (party/raid/raid40/arena/arenaEnemy/boss) -- see
        -- PartyFrames.lua:380 (ResolveStatusbarTexture) for the LSM resolve.
        -- absorbBarColor is a real, always-rendered field too (confirmed at
        -- PartyFrames.lua:6001-6003, frame.absorb:SetStatusBarColor with no
        -- gameplay meaning attached -- it is a static shield-overlay tint,
        -- not a class/power/spec color), so it gets the same shared-value
        -- treatment as the texture fields rather than a per-mode color: all
        -- 6 modes render the same absorb shield, and a party frame and its
        -- raid-frame counterpart having different shield tints would read as
        -- a bug, not a feature, to a player grouping/regrouping mid-session.
        local texture
        local accentR, accentG, accentB
        if themeKey == "classic" then
            texture = "Blizzard"
            accentR, accentG, accentB = 0.86, 0.62, 0.16
        elseif themeKey == "forever" then
            texture = "Melli Dark"
            accentR, accentG, accentB = 0.82, 0.65, 0.23
        elseif themeKey == "retail" then
            texture = "Blizzard Raid Bar"
            accentR, accentG, accentB = 0.12, 0.48, 0.95
        else
            texture = "Melli Reforged"
        end
        for _, mode in ipairs(MODES) do
            profile[mode] = type(profile[mode]) == "table" and profile[mode] or {}
            profile[mode].healthTexture = texture
            profile[mode].absorbBarTexture = texture
            if accentR then
                profile[mode].absorbBarColor = type(profile[mode].absorbBarColor) == "table" and profile[mode].absorbBarColor or {}
                profile[mode].absorbBarColor.r = accentR
                profile[mode].absorbBarColor.g = accentG
                profile[mode].absorbBarColor.b = accentB
            end
        end
    end,
})
