local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local function GetProfile()
    if not (KT.db and KT.db.profile) then return nil end
    KT.db.profile.resourceBars = KT.db.profile.resourceBars or {}
    return KT.db.profile.resourceBars
end

KT.VisualThemes:RegisterModule("resourcebars", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = function()
        return {
            "general.texture", "general.frameArtKit",
            "health.texture", "health.borderSize",
            "health.fillR", "health.fillG", "health.fillB",
            "primary.texture", "primary.borderSize",
            "secondary.texture", "secondary.borderSize",
            "health.textFormat", "primary.textFormat", "secondary.showText",
        }
    end,
    seed = function(profile, themeKey)
        -- health/primary/secondary share one texture+borderSize seed and
        -- one shared classic-border toggle (general.frameArtKit): the three
        -- sub-bars stack into a single resource-bar identity, not three
        -- independent widgets, so one switch frames all three.
        --
        -- Only health gets a per-theme accent color: it is the one section
        -- with a real, always-rendered static color field (fillR/fillG/fillB
        -- in KUIResourceBars.lua) with no gameplay meaning attached.
        -- primary/secondary default to colorMode == "power" (a real,
        -- currently-accurate class/power-type color -- e.g. mana blue,
        -- rage red) and are left untouched so re-theming doesn't strip that
        -- information from the player.
        local texture, borderSize, frameArtKit
        local healthR, healthG, healthB
        if themeKey == "classic" then
            texture, borderSize, frameArtKit = "Blizzard", 1, "classic"
            healthR, healthG, healthB = 0.86, 0.62, 0.16
        elseif themeKey == "forever" then
            texture, borderSize, frameArtKit = "Melli Dark", 2, "default"
            healthR, healthG, healthB = 0.82, 0.65, 0.23
        elseif themeKey == "retail" then
            texture, borderSize, frameArtKit = "Blizzard Raid Bar", 0, "default"
            healthR, healthG, healthB = 0.12, 0.48, 0.95
        else
            -- kui: reset the classic-border field to ResourceBars' own
            -- default (KUIResourceBars.lua general defaults: frameArtKit = "default").
            texture, borderSize, frameArtKit = "Melli Reforged", 1, "default"
        end
        profile.general = profile.general or {}
        profile.general.texture = texture
        if frameArtKit then profile.general.frameArtKit = frameArtKit end
        -- `profile[key] = profile[key] or {}` below, when a key was
        -- genuinely nil (this adapter running before KUIResourceBars.lua's
        -- own OnInitialize populates its complete defaults), created a
        -- SPARSE table with only texture/borderSize/fill set -- no
        -- height/pipHeight. That sparse table is no longer nil, so
        -- KUIResourceBars.lua's own `db.health = db.health or {...with
        -- height...}` default-merge never ran either, leaving height unset
        -- and crashing (first the options panel's preview animation, then
        -- BuildBars' own SetSize). The table isn't always "new" by the time
        -- this runs either (an already-existing table can still be missing
        -- this one field, e.g. from before pipHeight existed at all) -- so
        -- this must run every time, unconditionally, not just on first
        -- creation. `x = x or default` is already a no-op once a real value
        -- is set, so there is no cost to always checking.
        local heightDefaults = { health = 25, primary = 25 }
        for _, key in ipairs({ "health", "primary", "secondary" }) do
            profile[key] = profile[key] or {}
            profile[key].texture = texture
            profile[key].borderSize = borderSize
            if key == "secondary" then
                profile[key].pipHeight = profile[key].pipHeight or 14
            else
                profile[key].height = profile[key].height or heightDefaults[key]
            end
        end
        -- every theme shows the resource / power texts by default
        profile.health.textFormat = "both"
        profile.primary.textFormat = "curpp"
        profile.secondary.showText = true
        if healthR then
            profile.health.fillR, profile.health.fillG, profile.health.fillB = healthR, healthG, healthB
        end
    end,
    validate = function(profile)
        for _, key in ipairs({ "health", "primary", "secondary" }) do
            profile[key] = profile[key] or {}
            profile[key].borderSize = math.max(0, math.min(5, tonumber(profile[key].borderSize) or 1))
        end
    end,
})
