local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

local UNIT_KEYS = { "player", "target", "focus", "pet", "boss" }

local function GetProfile()
    if not (KT.db and KT.db.profile) then return nil end
    KT.db.profile.unitFrames = KT.db.profile.unitFrames or {}
    local profile = KT.db.profile.unitFrames
    KT.VisualThemes:PrepareModernNumberSlots(profile)
    return profile
end

local function SetUnitValues(profile, showPortrait, texture)
    for _, key in ipairs(UNIT_KEYS) do
        profile[key] = type(profile[key]) == "table" and profile[key] or {}
        local unit = profile[key]
        unit.showPortrait = showPortrait
        unit.healthBarTexture = texture
    end
end

local function SetUnitBorderColor(profile, colorR, colorG, colorB)
    for _, key in ipairs(UNIT_KEYS) do
        profile[key] = type(profile[key]) == "table" and profile[key] or {}
        local unit = profile[key]
        unit.borderColor = { r = colorR, g = colorG, b = colorB }
    end
end

-- Player/target default frameScale under
-- Retail/Classic/Forever (module's own baseline default is 100).
local PLAYER_TARGET_FRAME_SCALE = 132
local function SetPlayerTargetScale(profile, scale)
    for _, key in ipairs({ "player", "target" }) do
        profile[key] = type(profile[key]) == "table" and profile[key] or {}
        profile[key].frameScale = scale
    end
end

-- Class power is part of the Player UnitFrame's visual language.  Keep its
-- initial state in the per-theme slot so Classic can opt into the attached
-- combo-point ornament without leaking that choice into the other themes.
local function SetClassPowerDefaults(profile, enabled)
    profile.player = type(profile.player) == "table" and profile.player or {}
    profile.player.showClassPowerBar = enabled == true
    profile.player.classPowerStyle = enabled and "modern" or "none"
    profile.player.classPowerPosition = enabled and "bottom" or "top"
    profile.player.lockClassPowerToFrame = true
    profile.player.classPowerBarX = 0
    profile.player.classPowerBarY = 0
end

local function SetModernNumbers(profile)
    profile._ktModernNumbersV1 = true
    for _, key in ipairs({ "player", "target" }) do
        local unit = profile[key]
        unit.leftTextContent = "perhp"
        unit.rightTextContent = "curhp"
        unit.centerTextContent = "name"
        unit.powerPercentText = "right"
        unit.powerTextFormat = "curpp"
        unit.powerShowPercent = false
        unit.leftTextX, unit.leftTextY = 0, 0
        unit.rightTextX, unit.rightTextY = 0, 0
        unit.powerPercentX, unit.powerPercentY = 0, 0
    end
end

local NUMBER_FIELDS = { "leftTextContent", "rightTextContent", "centerTextContent",
    "powerPercentText", "powerTextFormat", "powerShowPercent", "leftTextX", "leftTextY",
    "rightTextX", "rightTextY", "powerPercentX", "powerPercentY" }
function KT.VisualThemes:PrepareModernNumberSlots(profile)
    if profile._ktNumberBaseline then return end
    local baseline = {}
    for _, key in ipairs({ "player", "target" }) do
        local unit = profile[key] or {}
        for _, field in ipairs(NUMBER_FIELDS) do
            local value = unit[field]
            baseline[key .. "." .. field] = value == nil and { __ktVisualThemeNil = true } or value
        end
    end
    profile._ktNumberBaseline = baseline
    local state = KT.db.profile.visualTheme
    local slots = state and state.slots and state.slots.unitframes
    for _, slot in pairs(slots or {}) do
        for path, value in pairs(baseline) do
            if slot[path] == nil then slot[path] = value end
        end
        if slot._ktModernNumbersV1 == nil then slot._ktModernNumbersV1 = false end
    end
end

KT.VisualThemes:RegisterModule("unitframes", {
    isAvailable = function() return GetProfile() ~= nil end,
    getProfile = GetProfile,
    getOwnedPaths = function()
        local paths = {
            "portraitStyle", "darkTheme", "healthBarTexture", "frameArtKit",
            "target.portraitSide", "_ktModernNumbersV1",
        }
        for _, key in ipairs(UNIT_KEYS) do
            paths[#paths + 1] = key .. ".showPortrait"
            paths[#paths + 1] = key .. ".healthBarTexture"
            paths[#paths + 1] = key .. ".borderColor.r"
            paths[#paths + 1] = key .. ".borderColor.g"
            paths[#paths + 1] = key .. ".borderColor.b"
        end
        paths[#paths + 1] = "player.showPlayerCastbar"
        paths[#paths + 1] = "player.showClassPowerBar"
        paths[#paths + 1] = "player.classPowerStyle"
        paths[#paths + 1] = "player.classPowerPosition"
        paths[#paths + 1] = "player.lockClassPowerToFrame"
        paths[#paths + 1] = "player.classPowerBarX"
        paths[#paths + 1] = "player.classPowerBarY"
        paths[#paths + 1] = "player.frameScale"
        paths[#paths + 1] = "target.frameScale"
        paths[#paths + 1] = "player.customFillColor.r"
        paths[#paths + 1] = "player.customFillColor.g"
        paths[#paths + 1] = "player.customFillColor.b"
        paths[#paths + 1] = "player.healthClassColored"
        paths[#paths + 1] = "target.customFillColor.r"
        paths[#paths + 1] = "target.customFillColor.g"
        paths[#paths + 1] = "target.customFillColor.b"
        paths[#paths + 1] = "target.healthClassColored"
        paths[#paths + 1] = "showPvPCircle"
        for _, key in ipairs({ "player", "target" }) do
            for _, field in ipairs({ "leftTextContent", "rightTextContent", "centerTextContent",
                "powerPercentText", "powerTextFormat", "powerShowPercent", "leftTextX", "leftTextY",
                "rightTextX", "rightTextY", "powerPercentX", "powerPercentY" }) do
                paths[#paths + 1] = key .. "." .. field
            end
        end
        return paths
    end,
    seed = function(profile, themeKey, clientFlavor)
        if themeKey == "retail" or themeKey == "forever" then
            profile.player = profile.player or {}
            profile.target = profile.target or {}
            SetModernNumbers(profile)
        elseif profile._ktModernNumbersV1 and profile._ktNumberBaseline then
            for _, key in ipairs({ "player", "target" }) do
                for _, field in ipairs(NUMBER_FIELDS) do
                    local value = profile._ktNumberBaseline[key .. "." .. field]
                    if type(value) == "table" and value.__ktVisualThemeNil then value = nil end
                    profile[key][field] = value
                end
            end
            profile._ktModernNumbersV1 = false
        end
        if themeKey == "classic" then
            -- Classic's real stock box (ApplyClassicUnitFrameArt) assumes a
            -- round-clipped portrait, same as Forever's -- Blizzard's real
            -- TargetingFrame portrait is round too. "attached" takes
            -- ApplyDetachedPortraitShape's fast path, which explicitly
            -- REMOVES any mask, so the portrait would render
            -- fully unmasked and bleed outside the ring.
            profile.portraitStyle = "circular"
            profile.darkTheme = false
            -- The PvP icon's backdrop circle
            -- defaults ON for the 3 real-stock-art themes, OFF for kui
            -- (which has its own toggle to opt back in).
            profile.showPvPCircle = true
            profile.healthBarTexture = "Blizzard"
            SetUnitValues(profile, true, "Blizzard")
            -- Classic's default accent is #DCA300.
            SetUnitBorderColor(profile, 0.862745, 0.639216, 0)
            profile.frameArtKit = "classic"
            if profile.target then profile.target.portraitSide = "right" end
            -- showPlayerCastbar defaults to false module-wide, so cast bars
            -- don't appear under Classic/Forever.
            -- Real stock geometry anchors the cast bar below Power already
            -- (CreateCastBar); it just never turns on unless the player
            -- opts in manually. Real per-client themes should show it.
            profile.player = profile.player or {}
            profile.player.showPlayerCastbar = true
            SetClassPowerDefaults(profile, true)
            SetPlayerTargetScale(profile, PLAYER_TARGET_FRAME_SCALE)
            -- Classic's health bar defaults to green
            -- too, same mechanism as Retail below.
            for _, key in ipairs({ "player", "target" }) do
                profile[key] = type(profile[key]) == "table" and profile[key] or {}
                profile[key].customFillColor = { r = 0.10, g = 0.90, b = 0.10 }
                profile[key].healthClassColored = false
            end
        elseif themeKey == "forever" then
            profile.portraitStyle = "circular"
            -- The stock-theme health selector owns the fill color. Leaving
            -- darkTheme enabled here forced #111111 after every class/custom
            -- color update, so Forever always rendered black.
            profile.darkTheme = false
            profile.showPvPCircle = true
            -- Forever's bar texture should match
            -- Retail's rather than keep its own separate LSM choice.
            profile.healthBarTexture = "Blizzard Raid Bar"
            SetUnitValues(profile, true, "Blizzard Raid Bar")
            -- Forever's default accent is #694836.
            SetUnitBorderColor(profile, 0.411765, 0.282353, 0.211765)
            profile.frameArtKit = "default"
            if profile.target then profile.target.portraitSide = "right" end
            profile.player = profile.player or {}
            profile.player.showPlayerCastbar = true
            SetClassPowerDefaults(profile, false)
            SetPlayerTargetScale(profile, PLAYER_TARGET_FRAME_SCALE)
            -- Forever's health bar defaults to green
            -- too, same mechanism as Retail below.
            for _, key in ipairs({ "player", "target" }) do
                profile[key] = type(profile[key]) == "table" and profile[key] or {}
                profile[key].customFillColor = { r = 0.57, g = 1.00, b = 0.235 }
                profile[key].healthClassColored = false
            end
        elseif themeKey == "retail" then
            -- Retail is the same real per-client
            -- stock geometry as Forever (same atlas name, ApplyForeverUnitFrameArt
            -- in ThemeClientAssets.lua is reused for both), NOT the bare
            -- fixed-accent-color ceiling kui already covers. The only real
            -- difference is the ring's own color -- gold, not bronze -- and
            -- that comes for free from the atlas itself: this same atlas
            -- name only renders bronze on the Forever CLIENT specifically
            -- (which remaps it), so a genuine Retail client renders the
            -- genuine gold Retail art natively with no recoloring needed.
            profile.portraitStyle = "circular"
            profile.darkTheme = false
            profile.showPvPCircle = true
            profile.healthBarTexture = "Blizzard Raid Bar"
            SetUnitValues(profile, true, "Blizzard Raid Bar")
            -- Retail's default accent is the
            -- player's own class color -- a snapshot taken when the theme
            -- is applied (seed only runs on an explicit theme switch, same
            -- as every other seeded field in this module), not a live
            -- per-unit tracker -- it will not follow whichever unit is
            -- currently targeted.
            do
                local playerClass = type(UnitClass) == "function" and select(2, UnitClass("player")) or nil
                local cc = (playerClass and C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(playerClass))
                    or (playerClass and RAID_CLASS_COLORS and RAID_CLASS_COLORS[playerClass])
                    or { r = 1.00, g = 0.82, b = 0.10 }
                SetUnitBorderColor(profile, cc.r, cc.g, cc.b)
            end
            profile.frameArtKit = "default"
            if profile.target then profile.target.portraitSide = "right" end
            profile.player = profile.player or {}
            profile.player.showPlayerCastbar = true
            SetClassPowerDefaults(profile, false)
            SetPlayerTargetScale(profile, PLAYER_TARGET_FRAME_SCALE)
            -- Retail's health bar defaults to green
            -- (KUIUnitFrames.lua's existing customFillColor/healthClassColored
            -- mechanism -- healthClassColored=false makes the custom fill win
            -- over class/reaction coloring).
            for _, key in ipairs({ "player", "target" }) do
                profile[key] = type(profile[key]) == "table" and profile[key] or {}
                profile[key].customFillColor = { r = 0.57, g = 1.00, b = 0.235 }
                profile[key].healthClassColored = false
            end
        else
            profile.portraitStyle = clientFlavor == "forever" and "circular" or "none"
            profile.darkTheme = false
            profile.showPvPCircle = false
            profile.healthBarTexture = "Melli Reforged"
            SetUnitValues(profile, clientFlavor == "forever", "Melli Reforged")
            if profile.target and clientFlavor == "forever" then profile.target.portraitSide = "right" end
            -- kui: reset the classic-border field to UnitFrames' own default
            -- (KUIUnitFrames.lua defaults: frameArtKit = "default").
            profile.frameArtKit = "default"
            SetClassPowerDefaults(profile, false)
            -- kui must NOT get Retail/Forever/Classic's
            -- bigger 132% default: switching TO kui would otherwise leave a
            -- stale 132 behind from whichever real-stock theme was active
            -- before, since this branch never touched frameScale at all.
            -- Reset explicitly to the module's own baseline (100). A baseline of 75
            -- was rejected: a frameScale below
            -- 100 exposed a bug elsewhere (buffs rendering huge --
            -- see KUIUnitFrames.lua), so kui stays at 100.
            SetPlayerTargetScale(profile, 100)
            -- kui's health bar should be just the class color. Previously this
            -- branch never reset
            -- healthClassColored/customFillColor, so switching to kui from
            -- Classic/Forever/Retail (all three force healthClassColored
            -- = false + a green customFillColor) left that green stuck in
            -- place. kui's own default is class-colored health, in no
            -- case the green the other three force -- applies to every
            -- unit this module seeds (UNIT_KEYS), not just player/target.
            for _, key in ipairs(UNIT_KEYS) do
                profile[key] = type(profile[key]) == "table" and profile[key] or {}
                profile[key].healthClassColored = true
            end
        end
    end,
    validate = function(profile, themeKey)
        if themeKey == "retail" or themeKey == "forever" then
            profile.player = profile.player or {}
            profile.target = profile.target or {}
            SetModernNumbers(profile)
        end
        local valid = { attached = true, detached = true, circular = true, none = true }
        if not valid[profile.portraitStyle] then profile.portraitStyle = "circular" end
        -- Repair existing Forever slots seeded with the obsolete dark-health
        -- default. A black bar remains available through the custom picker.
        if themeKey == "forever" then profile.darkTheme = false end
        -- The frame kit is part of the visual theme. Repair old slots that
        -- were captured before Classic's real stock frame was added.
        profile.frameArtKit = themeKey == "classic" and "classic" or "default"
        -- Re-apply this theme's own HEALTH/CLASS choice from its card
        -- (profile.visualThemeHealth, written by ThemePreview.lua), so each
        -- theme keeps its own color mode instead of the seed's default.
        local root = KT.db and KT.db.profile
        local saved = root and type(root.visualThemeHealth) == "table" and root.visualThemeHealth[themeKey]
        if type(saved) == "table" then
            local c = saved.color or {}
            for _, key in ipairs({ "player", "target" }) do
                profile[key] = type(profile[key]) == "table" and profile[key] or {}
                profile[key].healthClassColored = saved.classColored ~= false
                local fb = (themeKey == "forever" or themeKey == "retail") and { 0.57, 1.00, 0.235 } or { 0.10, 0.90, 0.10 }
                profile[key].customFillColor = { r = c.r or fb[1], g = c.g or fb[2], b = c.b or fb[3] }
            end
            if saved.classColored == false then profile.darkTheme = false end
        end
    end,
})
