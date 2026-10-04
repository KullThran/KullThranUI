local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local function GetProfile()
    if not (KT.db and KT.db.profile) then return nil end
    KT.db.profile.minimap = KT.db.profile.minimap or {}
    return KT.db.profile.minimap
end

-- Only forever/classic get a fixed circular identity for now; retail and kui
-- are intentionally left untouched (the
-- retail port is a later pass once this is validated in Forever).
KT.VisualThemes:RegisterModule("minimap", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = function()
        return { "shape", "borderColor", "ringStyle" }
    end,
    seed = function(profile, themeKey)
        profile.ringStyle = nil -- auto: each style wears its own ring (KUI none)
        if themeKey == "retail" then
            profile.shape = "ROUND" -- the Retail ring art is circular
        elseif themeKey == "forever" then
            profile.shape = "ROUND"
            profile.borderColor = { r = 0.862745, g = 0.521569, b = 0.376471, a = 1 } -- Forever #DC8560
        elseif themeKey == "classic" then
            profile.shape = "ROUND"
            profile.borderColor = { r = 0.92, g = 0.72, b = 0.22, a = 1 }
        end
    end,
    validate = function(profile)
        -- Forever's ring color moved to #DC8560: migrate the earlier gold / bronze values.
        local c = profile and profile.borderColor
        local VT = KT.VisualThemes
        if c and VT and VT.GetRenderedTheme and VT:GetRenderedTheme() == "forever" then
            local function near(r, g, b)
                return math.abs((c.r or 0) - r) < 0.01 and math.abs((c.g or 0) - g) < 0.01
                    and math.abs((c.b or 0) - b) < 0.01
            end
            if near(0.82, 0.65, 0.23) or near(0.80, 0.56, 0.24) then
                profile.borderColor = { r = 0.862745, g = 0.521569, b = 0.376471, a = c.a or 1 }
            end
        end
    end,
})
