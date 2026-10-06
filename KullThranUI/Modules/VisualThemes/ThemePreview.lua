local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

--[[
    ThemePreview.lua

    Live miniature of every visual theme, drawn with the SAME art sources the
    themes really render with: the real Blizzard atlas/texture each theme uses
    (classic's vanilla sheets, the HUD atlas family for forever and retail,
    retail resolved from its own sheet pixels when the client remaps that atlas
    name) and KullThranUI's own textures for the kui theme.

    Rules this file follows on purpose:
      - Nothing is a static image: every piece is built live from art, so
        it follows any future asset change.
      - Every atlas goes through C_Texture.GetAtlasInfo before it is drawn and
        every piece has its own fallback, so a client that does not expose one
        of them shows a complete, plainer card instead of a hole.
      - No saved-variable read or write, no re-parenting of live frames, no
        events and no OnUpdate. Previews are decoration only.
      - Layout follows the real 232x100 stock box the unit-frame themes seat
        themselves on, so the card is a scaled-down copy of the real frame and
        not an unrelated mock-up.
]]

-- This file loads (per the TOC) BEFORE GlobalFont.lua resolves the real
-- KT.FONT_PATH from the player's profile/locale, so a plain `local FONT =
-- KT.FONT_PATH or fallback` captured at file-load time froze on the
-- fallback permanently (every text in these cards rendered in WoW's
-- generic default font instead of the addon's own Avant Garde). A
-- function re-reads the live value on every actual use instead of a
-- one-time snapshot.
local function GetPreviewFont()
    return KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
end

-- Every visible string on the cards goes through the addon's active locale
-- (Locales/Modules/VisualStyles.lua holds the translations). Falls back to
-- the English key, like the rest of the options do.
local function T(text)
    if type(text) ~= "string" then return text end
    local L = KT.GetLocale and KT:GetLocale()
    if L then
        local value = L[text]
        if type(value) == "string" and value ~= "" then return value end
    end
    return text
end

-- Classic: real vanilla files. No atlas lookup needed, they always exist here.
local CLASSIC_FRAME_SHEET = "Interface\\TargetingFrame\\UI-TargetingFrame"
local CLASSIC_BAR_FILL    = "Interface\\TargetingFrame\\UI-StatusBar"
local CLASSIC_END_CAP     = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf"
local CLASSIC_SLOT        = "Interface\\Buttons\\UI-Quickslot"

-- kui: KullThranUI's own textures, the ones the kui theme renders with.
local KUI_BAR_FILL       = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\MelliReforged.tga"
local KUI_BAR_TRACK      = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga"
local KUI_PORTRAIT_MASK  = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_mask.tga"
local KUI_PORTRAIT_RING  = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_border.tga"

-- Stock HUD atlas family. Exactly the names ThemeClientAssets.lua seats on the
-- real unit frames, so the card shows the very pixels the theme renders.
local ATLAS_UNIT_ART    = "UI-HUD-UnitFrame-Player-PortraitOn"
local ATLAS_HEALTH_MASK = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Mask"
local ATLAS_MANA_MASK   = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Mask"
local ATLAS_CAP_LEFT    = "ui-hud-actionbar-gryphon-left"
local ATLAS_CAP_RIGHT   = "ui-hud-actionbar-gryphon-right"
local ATLAS_SLOT        = "UI-HUD-ActionBar-IconFrame-Slot"

-- The stock layout box every Blizzard-style theme draws inside.
local BOX_W, BOX_H = 232, 100

-- Per-theme scene. `kind` picks the renderer; the rest is this theme's own
-- palette and art names. Colors are the same fills the theme's adapter seeds.
local SCENES = {
    kui = {
        kind = "flat",
        panel = { 0.070, 0.070, 0.085, 1 },
        health = { 0.52, 0.12, 0.10, 0.95 },
        power = { 0.13, 0.31, 0.70, 0.95 },
    },
    classic = {
        kind = "sheet",
        panel = { 0.15, 0.10, 0.040, 1 },
        health = { 0.10, 0.72, 0.14, 1 },
        power = { 0.11, 0.22, 0.85, 1 },
    },
    forever = {
        kind = "hud",
        art = ATLAS_UNIT_ART,
        retail = false,
        panel = { 0.16, 0.10, 0.035, 1 },
        health = { 0.26, 0.62, 0.24, 1 },
        power = { 0.20, 0.38, 0.74, 1 },
    },
    retail = {
        kind = "hud",
        art = ATLAS_UNIT_ART,
        retail = true,
        panel = { 0.11, 0.09, 0.045, 1 },
        health = { 0.57, 1.00, 0.235, 1 },
        power = { 0.12, 0.36, 0.90, 1 },
    },
}

-- Real stock geometry inside the 232x100 box, per renderer kind. These are the
-- same rectangles ThemeClientAssets.lua uses on the live frames.
local GEO = {
    sheet = {
        art = { left = 1, right = 0.09375, top = 0, bottom = 0.78125,
            w = 232, h = 100, x = 0, y = 0 },
        portrait = { point = "TOPLEFT", x = 42, y = -12, size = 64 },
        health = { x = 106, y = 41, w = 119, h = 12 },
        power = { x = 106, y = 52, w = 119, h = 12 },
        name = { point = "CENTER", x = 50, y = 19, w = 100 },
    },
    hud = {
        portrait = { point = "TOPLEFT", x = 24, y = -19, size = 60 },
        health = { x = 85, y = 40, w = 124, h = 20, mask = ATLAS_HEALTH_MASK, mx = -2, my = 6 },
        power = { x = 85, y = 61, w = 124, h = 10, mask = ATLAS_MANA_MASK, mx = -2, my = 2 },
        name = { point = "TOPLEFT", x = 88, y = -27, w = 96 },
    },
}

-- KullThranUI's own flat layout: no stock box, so the scene gets its own
-- proportions that fit the same space.
local FLAT_GEO = {
    portrait = { size = 0.46 },
    health = { h = 0.30 },
    power = { h = 0.18 },
}

local function Clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

local function AtlasInfo(name)
    if type(name) ~= "string" then return nil end
    if not (C_Texture and C_Texture.GetAtlasInfo) then return nil end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    if not ok then return nil end
    return info
end

-- Real Retail pixels for an atlas name, when the client is drawing something
-- else for it (Forever remaps the HUD atlas family to its own bronze art).
-- Resolved independently of the rendered theme: a preview always has to show
-- the real Retail art, even while another theme is active.
local function RetailPixels(name)
    if not (KT.GetRetailAtlasPixels) then return nil end
    local ok, info = pcall(KT.GetRetailAtlasPixels, name)
    if not ok then return nil end
    return info
end

-- Draws real art on `tex`, preferring resolved Retail pixels, then the client's
-- own atlas. Returns the resolved pixel size, or nil when nothing is available
-- (caller falls back to its plain shape).
local function ApplyArt(tex, atlasName, useRetail, scale)
    local vt = KT.VisualThemes
    local foreverPixels = not useRetail and _G.WOW_PROJECT_MAINLINE
        and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE and vt and vt.GetForeverAtlasPixels
        and vt:GetForeverAtlasPixels(atlasName)
    local pixels = (useRetail and RetailPixels(atlasName)) or foreverPixels
    if pixels then
        tex:SetTexture(pixels.file)
        tex:SetTexCoord(
            pixels.leftTexCoord, pixels.rightTexCoord,
            pixels.topTexCoord, pixels.bottomTexCoord)
        tex:SetSize(pixels.width * scale, pixels.height * scale)
        return pixels.width, pixels.height
    end

    local info = AtlasInfo(atlasName)
    if not (info and info.width and info.height) then return nil end
    if info.file or info.filename then
        if info.leftTexCoord and info.rightTexCoord
            and info.topTexCoord and info.bottomTexCoord then
            tex:SetTexture(info.file or info.filename)
            tex:SetTexCoord(
                info.leftTexCoord, info.rightTexCoord,
                info.topTexCoord, info.bottomTexCoord)
        elseif tex.SetAtlas then
            tex:SetAtlas(atlasName, false)
            tex:SetTexCoord(0, 1, 0, 1)
        else
            return nil
        end
    elseif tex.SetAtlas then
        tex:SetAtlas(atlasName, false)
        tex:SetTexCoord(0, 1, 0, 1)
    else
        return nil
    end
    tex:SetSize(info.width * scale, info.height * scale)
    return info.width, info.height
end

local function Unsnap(tex)
    if not tex then return end
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end

-- End caps are faction-dependent on the live action bar, so the preview
-- picks the same pair the addon does rather than always drawing the
-- Alliance one.
local function ActionBarCapAtlases()
    local faction = UnitFactionGroup and UnitFactionGroup("player")
    if faction == "Horde" then
        return "ui-hud-actionbar-wyvern-left", "ui-hud-actionbar-wyvern-right"
    end
    return ATLAS_CAP_LEFT, ATLAS_CAP_RIGHT
end

-- The decorative action-bar end-cap art (not real icon art -- kui has no
-- real texture for icon slots, so it stays blank, same "nothing real to
-- show, don't fake it" rule as before) replaces the per-theme caption text
-- below each card's preview, with a small "mini action bar" of slot
-- squares filling the gap between the two caps -- matching the real
-- layout (end caps flank the bar, they don't sit next to each other with
-- nothing between them).
local MINI_SLOT_COUNT = 3

local KUI_SLOT_COUNT = 5

local function AddEndCapArt(card, kit, stage, y, capHeight)
    if kit.kind == "flat" then
        -- KullThranUI has no ornamental end caps, but its action bars are
        -- flat square buttons: draw a short row of those, in the same
        -- strip the other cards use for their end caps and slots. Plain
        -- dark squares with a hairline edge, matching the flat look of the
        -- unit frame above them.
        local slotSize = math.max(10, math.floor(capHeight * 0.78))
        local slotGap = 3
        local totalWidth = (KUI_SLOT_COUNT * slotSize) + ((KUI_SLOT_COUNT - 1) * slotGap)
        local firstX = -math.floor(totalWidth / 2)
        for index = 1, KUI_SLOT_COUNT do
            local slot = CreateFrame("Frame", nil, card)
            slot:SetSize(slotSize, slotSize)
            slot:SetPoint("TOP", stage, "BOTTOM",
                firstX + ((index - 1) * (slotSize + slotGap)) + slotSize / 2,
                -y - (capHeight - slotSize) / 2)
            local bg = slot:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0.045, 0.047, 0.058, 1)
            local sheen = slot:CreateTexture(nil, "ARTWORK")
            sheen:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
            sheen:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -1, -1)
            sheen:SetHeight(math.max(2, math.floor(slotSize * 0.4)))
            sheen:SetColorTexture(1, 1, 1, 0.035)
            -- MakeBorder is defined further down this file (after this
            -- function), so draw the hairline edge inline.
            for _, e in ipairs({
                { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
            }) do
                local edge = slot:CreateTexture(nil, "OVERLAY")
                edge:SetPoint(e[1], slot, e[1])
                edge:SetPoint(e[2], slot, e[2])
                if e[3] then edge:SetHeight(1) else edge:SetWidth(1) end
                edge:SetColorTexture(1, 1, 1, 0.17)
            end
        end
        return
    end
    -- Every branch measures (or, for Classic, deliberately caps) its own
    -- real size BEFORE positioning, and holders are spaced using that real
    -- width, not a guess. Otherwise: (1) an un-sized texture renders at
    -- its source FILE's own native pixel size, which for a real action-bar
    -- end-cap graphic is much bigger than this card (Classic's cap came out
    -- giant). (2) A fixed `capHeight/100` scale guess instead of the
    -- atlas's own real native height means the rendered size (and
    -- therefore how wide it actually is) never matches the `capWidth` the
    -- holders are spaced apart by (Retail's cap came out tiny, Forever's
    -- two caps touched in the middle).
    local slotSize = math.max(8, math.floor(capHeight * 0.65))
    local slotGap = 2
    local slotsWidth = (MINI_SLOT_COUNT * slotSize) + ((MINI_SLOT_COUNT - 1) * slotGap)
    local gap = slotsWidth + 12
    local holders, widths = {}, {}
    for side = 1, 2 do
        local holder = CreateFrame("Frame", nil, card)
        local tex = holder:CreateTexture(nil, "ARTWORK")
        Unsnap(tex)
        local w, h
        if kit.kind == "sheet" then
            tex:SetTexture(CLASSIC_END_CAP)
            if side == 2 then tex:SetTexCoord(1, 0, 0, 1) end
            -- capHeight*0.85 x capHeight still reads tiny, and raising the
            -- shared row height to compensate would also grow Forever's
            -- (already correct) end-cap. This Blizzard file almost
            -- certainly has real transparent padding baked into its canvas
            -- (same category of issue as circle_border.tga/
            -- circle_mask.tga), un-measurable the same way since it's
            -- inside the game client's own archives, not a loose file.
            -- Overshoots the row's nominal height, but is anchored by its
            -- CENTER on the row's own center point (see below) so the
            -- extra size is split evenly above and below instead of all
            -- landing on the button beneath it.
            w, h = capHeight * 1.3, capHeight * 1.7
        else
            local capLeft, capRight = ActionBarCapAtlases()
            local atlasName = (side == 1) and capLeft or capRight
            -- Retail keeps its own pixel resolution: forcing
            -- useRetail=false for both made Retail's end-cap show the exact
            -- same bronze art as Forever's, losing the real distinction
            -- entirely. The sizing fix is the height normalization right
            -- below (measure native size, then scale to hit capHeight
            -- exactly), which works correctly regardless of which source
            -- (RetailPixels or the plain atlas) the dimensions came from.
            local nativeW, nativeH = ApplyArt(tex, atlasName, kit.retail, 1)
            if nativeW and nativeH and nativeH > 0 then
                local targetScale = capHeight / nativeH
                w, h = nativeW * targetScale, nativeH * targetScale
            end
        end
        if w and h then
            tex:ClearAllPoints()
            tex:SetSize(w, h)
            tex:SetPoint("CENTER", holder, "CENTER")
            holder:SetSize(w, h)
            widths[side] = w
            holders[side] = holder
        else
            holder:Hide()
        end
    end
    -- Anchored by CENTER on the row's own vertical center (not TOP), so a
    -- holder taller than capHeight (Classic's padding compensation above)
    -- overshoots evenly in both directions instead of only growing
    -- downward into the button below it.
    local rowCenterY = -(y + capHeight / 2)
    if holders[1] and widths[1] then
        holders[1]:SetPoint("CENTER", stage, "BOTTOM", -(gap / 2 + widths[1] / 2), rowCenterY)
    end
    if holders[2] and widths[2] then
        holders[2]:SetPoint("CENTER", stage, "BOTTOM", (gap / 2 + widths[2] / 2), rowCenterY)
    end

    local usesAtlas = (kit.kind == "hud")
    local firstX = -math.floor(slotsWidth / 2)
    for index = 1, MINI_SLOT_COUNT do
        local slot = CreateFrame("Frame", nil, card)
        slot:SetSize(slotSize, slotSize)
        slot:SetPoint("TOP", stage, "BOTTOM",
            firstX + ((index - 1) * (slotSize + slotGap)) + slotSize / 2, -y - (capHeight - slotSize) / 2)
        local bg = slot:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture("Interface\\Buttons\\WHITE8X8")
        bg:SetColorTexture(0.09, 0.08, 0.05, 1)
        if usesAtlas then
            local slotArt = slot:CreateTexture(nil, "BACKGROUND", nil, 1)
            Unsnap(slotArt)
            if ApplyArt(slotArt, ATLAS_SLOT, kit.retail, slotSize / 45) then
                slotArt:ClearAllPoints()
                slotArt:SetAllPoints(slot)
            else
                slotArt:Hide()
            end
        else
            local slotArt = slot:CreateTexture(nil, "ARTWORK")
            Unsnap(slotArt)
            slotArt:SetTexture(CLASSIC_SLOT)
            slotArt:SetAllPoints(slot)
        end
    end
end

local function Solid(parent, layer, color)
    local tex = parent:CreateTexture(nil, layer or "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    return tex
end

-- KullThranUI's own hairline border, drawn as four edges so it can be
-- recoloured in place (hover, active card) without recreating anything.
local function MakeBorder(parent, key, color, size)
    local edges = parent[key]
    if not edges then
        edges = {}
        local points = {
            { "TOPLEFT", "TOPRIGHT", true },
            { "BOTTOMLEFT", "BOTTOMRIGHT", true },
            { "TOPLEFT", "BOTTOMLEFT", false },
            { "TOPRIGHT", "BOTTOMRIGHT", false },
        }
        for index, info in ipairs(points) do
            local edge = parent:CreateTexture(nil, "OVERLAY")
            edge:SetTexture("Interface\\Buttons\\WHITE8X8")
            edge:ClearAllPoints()
            edge:SetPoint(info[1], parent, info[1])
            edge:SetPoint(info[2], parent, info[2])
            edge:SetWidth(size or 1)
            edge:SetHeight(size or 1)
            edge:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
            edges[index] = edge
        end
        parent[key] = edges
    end
    return edges
end

local function PaintBorder(edges, color, size)
    if not edges then return end
    for _, edge in ipairs(edges) do
        edge:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        if size then
            edge:SetWidth(size)
            edge:SetHeight(size)
        end
    end
end

-- Each theme's REAL accent: Classic/Forever/Retail are seeded explicitly by
-- Adapters/UnitFrames.lua's seed() (gold, bronze, live class color); kui's
-- portrait ring has no such seeded field and instead follows the same
-- resolution as its health fill by default (ResolveCircularPortraitColor
-- in KUIUnitFrames.lua skips its custom-color branch whenever
-- circularPortraitBorderColor is nil, which is the default) -- so the
-- already-resolved `healthColor` passed in here IS the accurate kui ring
-- color, not a separate lookup. (Deriving it from kit.panel + a fixed
-- offset rendered a near-identical muddy brown for every theme, and
-- KT:GetStylePalette() is a generic "skin" accent unrelated to the frame.)
-- Class colors go through one shared resolver that tries
-- C_ClassColor.GetClassColor first, the same way Adapters/UnitFrames.lua's
-- retail-accent seed does; RAID_CLASS_COLORS isn't reliably
-- populated/available on every client. One resolver, used everywhere a
-- class color is needed, so this can't silently diverge again.
local function ResolveClassColorByToken(classToken, fallback)
    if not classToken then return fallback end
    local cc = (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken))
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken])
    if cc then
        return { cc.r or 1, cc.g or 1, cc.b or 1, 1 }
    end
    return fallback
end

local function ResolveThemeAccent(kit, healthColor)
    if kit.kind == "sheet" then
        return { 0.862745, 0.639216, 0, 1 }
    end
    if kit.kind == "hud" then
        if kit.retail then
            -- `and`/`or` always collapse a multi-return expression to one
            -- value -- wrapping UnitClass("player") in `UnitClass and ...`
            -- INSIDE select()'s argument list silently truncated it to
            -- just the localized name before select(2, ...) ever saw it,
            -- so classToken was nil on every call regardless of which
            -- color table was queried. Guard outside the call instead, as
            -- Adapters/UnitFrames.lua's own (already-correct) version does.
            local classToken = type(UnitClass) == "function" and select(2, UnitClass("player")) or nil
            return ResolveClassColorByToken(classToken, { 1.00, 0.82, 0.10, 1 })
        end
        -- Forever's preview accent reads as a brown close to the Warrior
        -- class color, not the darker/muddier #694836 the real theme seeds
        -- (Adapters/UnitFrames.lua) -- this only changes how the preview
        -- TAB represents the color, not the live in-game accent.
        return ResolveClassColorByToken("WARRIOR", { 0.780, 0.612, 0.431, 1 })
    end
    return healthColor
end

-- Fallback portrait art, only used when the client cannot resolve the
-- player's own portrait (no SetPortraitTexture, or not loaded yet).
local PORTRAIT_ICON = 134400

-- Always the real player portrait, never a placeholder: this is the same
-- texture the live unit frames seat.
local function ApplyPlayerPortrait(tex)
    -- Mainline/Classic expose this as a global helper. Some test shims or
    -- clients also provide it as a texture method, so keep that fallback.
    if type(_G.SetPortraitTexture) == "function" then
        local ok = pcall(_G.SetPortraitTexture, tex, "player")
        if ok then return true end
    end
    if type(tex.SetPortraitTexture) == "function" then
        local ok, applied = pcall(tex.SetPortraitTexture, tex, "player")
        if ok and applied ~= false then return true end
    end
    tex:SetTexture(PORTRAIT_ICON)
    return false
end

--- The health color the live player frame will actually use, mirroring how
--- KUIUnitFrames.lua resolves it (dark theme, then a custom fill when class
--- coloring is off, then the player's class color). The preview must not show
--- a seeded color the player is not going to get.
-- Each card owns its own health choice (class vs custom color), stored per
-- theme in profile.visualThemeHealth[themeKey] = { classColored, color }.
-- The live unit frames only follow the card of the RENDERED theme; the others
-- are applied from here the next time that theme is switched to
-- (Adapters/UnitFrames.lua validate). Without a saved choice the card falls
-- back to what its theme seeds: class color for kui, green for the others --
-- or the live profile when it is the rendered theme.
local function GetThemeHealthChoice(themeKey)
    local profile = KT.db and KT.db.profile
    local saved = profile and profile.visualThemeHealth and profile.visualThemeHealth[themeKey]
    if type(saved) == "table" then
        local c = saved.color
        return saved.classColored ~= false,
            { (c and c.r) or 0.10, (c and c.g) or 0.90, (c and c.b) or 0.10, 1 }
    end
    if KT.VisualThemes:GetRenderedTheme() == themeKey then
        local player = profile and profile.unitFrames and profile.unitFrames.player
        if type(player) == "table" then
            local c = player.customFillColor
            return player.healthClassColored ~= false,
                type(c) == "table" and { c.r or 1, c.g or 1, c.b or 1, 1 }
                or ((themeKey == "forever" or themeKey == "retail") and { 0.57, 1.00, 0.235, 1 } or { 0.10, 0.90, 0.10, 1 })
        end
    end
    return themeKey == "kui", ((themeKey == "forever" or themeKey == "retail") and { 0.57, 1.00, 0.235, 1 } or { 0.10, 0.90, 0.10, 1 })
end

local function ResolveThemeHealthColor(themeKey, fallback)
    local classColored, custom = GetThemeHealthChoice(themeKey)
    if not classColored then return custom end
    local unitFrames = KT.db and KT.db.profile and KT.db.profile.unitFrames
    if unitFrames and unitFrames.darkTheme and KT.VisualThemes:GetRenderedTheme() == themeKey then
        return { 0.16, 0.16, 0.18, 1 }
    end
    local classToken = type(UnitClass) == "function" and select(2, UnitClass("player")) or nil
    return ResolveClassColorByToken(classToken, fallback)
end

local function ResolveLiveHealthColor(fallback)
    local profile = KT.db and KT.db.profile
    local unitFrames = profile and profile.unitFrames
    if not unitFrames then return fallback end
    if unitFrames.darkTheme then
        return { 0.16, 0.16, 0.18, 1 }
    end

    local player = unitFrames.player
    if not player then return fallback end

    local custom = player.customFillColor
    if type(custom) == "table" and player.healthClassColored == false then
        return { custom.r or 1, custom.g or 1, custom.b or 1, 1 }
    end

    -- `and`/`or` always collapse a multi-return expression to one value.
    -- Wrapping UnitClass("player") in `UnitClass and ...` INSIDE select()'s
    -- own argument list silently truncates it to just the localized name
    -- before select(2, ...) ever runs, so classToken would be nil on every
    -- call and every class-color lookup would fall through to the
    -- hardcoded fallback. Guard outside the call instead, matching
    -- Adapters/UnitFrames.lua's own version of this exact lookup.
    local classToken = type(UnitClass) == "function" and select(2, UnitClass("player")) or nil
    return ResolveClassColorByToken(classToken, fallback)
end

-- The player's live class color, independent of any custom health-fill
-- override. Used both for Retail's real seeded accent (Adapters/
-- UnitFrames.lua seeds it the same way) and for kui's card, which shows
-- the theme's own default rather than mirroring the live profile's
-- current customization (see the kui branch of DrawScene below).
local function LivePlayerClassColor()
    local classToken = type(UnitClass) == "function" and select(2, UnitClass("player")) or nil
    return ResolveClassColorByToken(classToken, { 1.00, 0.82, 0.10, 1 })
end

-- Each card's own chrome color (title, tag, "IN USE" badge, top band,
-- border) -- a different concept from the mini-preview's internal
-- ring/health color above. kui defaults to Crimson (the exact
-- {1, 0, 0.333} already established as "Crimson" by
-- KUIUnitFrames.lua's MigrateLegacyCrimsonAccent), Retail to the player's
-- live class color, Forever to a brown close to the Warrior class color
-- (RAID_CLASS_COLORS.WARRIOR, #C79C6E), and Classic keeps the catalog's
-- own gold.
local function ResolveCardBrandColor(themeKey, catalogColor)
    if themeKey == "kui" then
        return { 1, 0, 0.333, 1 }
    end
    if themeKey == "retail" then
        return LivePlayerClassColor()
    end
    if themeKey == "forever" then
        return ResolveClassColorByToken("WARRIOR", { 0.780, 0.612, 0.431, 1 })
    end
    return { catalogColor.r or 1, catalogColor.g or 1, catalogColor.b or 1, 1 }
end

-- Portrait window. The HUD themes show a round player portrait, classic shows a
-- rectangular one, so only the round case is clipped by a circular mask.
local function AddPortrait(box, portrait, scale, circular)
    local holder = CreateFrame("Frame", nil, box)
    holder:SetSize(portrait.size * scale, portrait.size * scale)
    holder:SetPoint(portrait.point, box, portrait.point,
        portrait.x * scale, portrait.y * scale)
    if holder.SetClipsChildren then holder:SetClipsChildren(true) end

    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(holder)
    local native = ApplyPlayerPortrait(icon)
    if not native then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end

    if circular and holder.CreateMaskTexture then
        local mask = holder:CreateMaskTexture()
        mask:SetTexture(KUI_PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(holder)
        icon:AddMaskTexture(mask)
    end
    return holder
end

-- A masked bar: flat fill clipped by the theme's own real track mask, exactly
-- like the live StatusBar is masked. Without the mask the fill is still drawn,
-- just as a plain rectangle, so the card never loses its bars.
local function AddMaskedBar(box, geom, scale, color, cacheKey)
    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", box, "TOPLEFT", geom.x * scale, -geom.y * scale)
    fill:SetSize(geom.w * scale, geom.h * scale)
    fill:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
    Unsnap(fill)

    local info = AtlasInfo(geom.mask)
    if not (info and info.width and info.height and box.CreateMaskTexture) then
        return fill
    end

    local mask = box[cacheKey]
    if not mask then
        mask = box:CreateMaskTexture()
        box[cacheKey] = mask
        fill:AddMaskTexture(mask)
    end
    if mask.SetAtlas then
        mask:SetAtlas(geom.mask, false)
    else
        return fill
    end
    mask:ClearAllPoints()
    mask:SetPoint("TOPLEFT", fill, "TOPLEFT", (geom.mx or 0) * scale, (geom.my or 0) * scale)
    mask:SetSize(info.width * scale, info.height * scale)
    mask:Show()
    return fill
end

local function AddNameText(box, geom, scale, text, kit)
    if not geom then return end
    local fs = box:CreateFontString(nil, "OVERLAY")
    fs:SetFont(GetPreviewFont(), Clamp(math.floor(10 * scale), 7, 11), "OUTLINE")
    local point = geom.point or "TOPLEFT"
    fs:SetPoint(point, box, point, geom.x * scale, geom.y * scale)
    if geom.w then fs:SetWidth(geom.w * scale) end
    if geom.justify or point == "CENTER" then
        fs:SetJustifyH(geom.justify or "CENTER")
    end
    fs:SetText(text)
    fs:SetTextColor(1, 1, 1, 1)
    return fs
end

-- Flat, colored panel drawn first so a theme whose real art is unavailable on
-- this client still reads as a complete frame instead of an empty hole.
-- `drawBorder` defaults true; Classic's own real sheet art already draws a
-- decorative bordered frame (it's an image of the actual Blizzard
-- TargetingFrame), so adding this generic accent-colored rectangle on top
-- of it double-bordered the card and never quite lined up with the sheet's
-- own edge -- same category of issue as the portrait ring/mask padding,
-- just not independently measurable the same way since this one's a
-- Blizzard file, not one of ours. Forever/Retail's HUD atlas has no such
-- baked-in border, so they still need this one. `drawPanel` defaults true
-- too; Classic skips its own brown fill entirely -- the real sheet art is
-- meant to be the only visible background, same "no extra container"
-- philosophy already applied to kui.
local function AddPanel(box, kit, scale, accent, drawBorder, drawPanel)
    local panel
    if drawPanel ~= false then
        panel = Solid(box, "BACKGROUND", kit.panel)
    end
    if drawBorder == false then return panel end
    local edges = MakeBorder(box, "_ktPreviewBorder", accent, Clamp(math.ceil(scale), 1, 2))
    PaintBorder(edges, accent, Clamp(math.ceil(scale), 1, 2))
    return panel
end

-- Real level-circle ornament: a plain dark circle (NOT atlas art -- the
-- real one in KUIUnitFrames.lua's usingClassicLevelOrnament block is just
-- a WHITE8X8 texture tinted dark, masked round) with the gold level number
-- on top. ox/oy and the two nudges are copied verbatim from that block's
-- player-side anchor (CENTER, frame's BOTTOMLEFT, ox/oy) so this can never
-- drift from the real positions: 36/30.5 for Forever and Retail, 60/33 for
-- Classic. `box` here is sized exactly like the real `frame` (both are the
-- 232x100 stock box at the same scale), so the same anchor math applies
-- unchanged.
local function AddLevelBadge(box, scale, ox, oy)
    local levelTextXNudge = 2 * scale
    local levelXNudge = 4 * scale
    local circleSize = 30 * scale

    -- The badge goes on a separate, higher-FrameLevel child frame. Created
    -- on "OVERLAY" with no explicit sublevel next to the opaque sheet art,
    -- it was hidden entirely behind it on Classic: same-layer/same-sublevel
    -- draw order follows texture CREATION order, which is a convention,
    -- not a guarantee (same as KUIUnitFrames.lua's PvP-circle-vs-icon
    -- stacking). A higher-FrameLevel child always wins regardless of
    -- either side's own sublevel usage.
    local holder = CreateFrame("Frame", nil, box)
    holder:SetAllPoints(box)
    holder:SetFrameLevel(box:GetFrameLevel() + 1)

    local circle = holder:CreateTexture(nil, "OVERLAY")
    circle:SetTexture("Interface\\Buttons\\WHITE8X8")
    circle:SetVertexColor(0.06, 0.06, 0.06, 1)
    circle:SetSize(circleSize, circleSize)
    if holder.CreateMaskTexture then
        local mask = holder:CreateMaskTexture()
        mask:SetTexture(KUI_PORTRAIT_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(circle)
        circle:AddMaskTexture(mask)
    end
    circle:SetPoint("CENTER", holder, "BOTTOMLEFT", ox * scale - levelXNudge, oy * scale)

    local text = holder:CreateFontString(nil, "OVERLAY")
    text:SetFont(GetPreviewFont(), Clamp(math.floor(11 * scale), 7, 11), "OUTLINE")
    text:SetTextColor(1, 0.82, 0.20, 1)
    text:SetJustifyH("CENTER")
    text:SetSize(18 * scale, 14 * scale)
    text:SetPoint("CENTER", holder, "BOTTOMLEFT", ox * scale + levelTextXNudge - levelXNudge, oy * scale)
    text:SetText("60")
end

-- Vanilla sheet renderer: the real TargetingFrame sample with its real
-- UI-StatusBar fills showing through the sheet's transparent bar windows.
local function DrawSheetFrame(box, kit, scale, healthColor, accent)
    local geom = GEO.sheet
    AddPanel(box, kit, scale, accent, false, false)

    local health = box:CreateTexture(nil, "ARTWORK")
    health:SetTexture(CLASSIC_BAR_FILL)
    health:SetVertexColor(healthColor[1], healthColor[2], healthColor[3], healthColor[4])
    box._ktSetHealthColor = function(color)
        health:SetVertexColor(color[1], color[2], color[3], color[4])
    end
    health:SetPoint("TOPLEFT", box, "TOPLEFT", geom.health.x * scale, -geom.health.y * scale)
    health:SetSize(geom.health.w * scale, geom.health.h * scale)
    Unsnap(health)

    local power = box:CreateTexture(nil, "ARTWORK")
    power:SetTexture(CLASSIC_BAR_FILL)
    power:SetVertexColor(kit.power[1], kit.power[2], kit.power[3], kit.power[4])
    power:SetPoint("TOPLEFT", box, "TOPLEFT", geom.power.x * scale, -geom.power.y * scale)
    power:SetSize(geom.power.w * scale, geom.power.h * scale)
    Unsnap(power)

    local art = box:CreateTexture(nil, "OVERLAY")
    Unsnap(art)
    art:SetTexture(CLASSIC_FRAME_SHEET)
    art:SetTexCoord(geom.art.left, geom.art.right, geom.art.top, geom.art.bottom)
    art:SetPoint("CENTER", box, "CENTER", geom.art.x * scale, geom.art.y * scale)
    art:SetSize(geom.art.w * scale, geom.art.h * scale)
    art:Show()

    -- Classic's portrait sits inside its own rectangular window cut into the
    -- sheet, so it is drawn plain: no circular mask belongs on this theme.
    AddPortrait(box, geom.portrait, scale, false)
    AddNameText(box, geom.name, scale, "KULLTHRAN", kit)
    AddLevelBadge(box, scale, 60, 33)
end

-- HUD atlas renderer, shared by the forever and retail themes: the real unit
-- frame art atlas, the real bar track masks and the real circular portrait.
local function DrawHudFrame(box, kit, scale, healthColor, accent)
    local geom = GEO.hud
    AddPanel(box, kit, scale, accent)

    local art = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    Unsnap(art)
    local drawn = ApplyArt(art, kit.art, kit.retail, scale)
    if drawn then
        -- The atlas is centred in the stock box, which is what leaves the
        -- transparent margin the bar/portrait rectangles below are measured
        -- from.
        art:ClearAllPoints()
        art:SetPoint("CENTER", box, "CENTER", 0, 0)
    else
        art:Hide()
    end

    local healthFill = AddMaskedBar(box, geom.health, scale, healthColor, "_ktPreviewHealthMask")
    box._ktSetHealthColor = function(color)
        healthFill:SetColorTexture(color[1], color[2], color[3], color[4])
    end
    AddMaskedBar(box, geom.power, scale, kit.power, "_ktPreviewPowerMask")
    AddPortrait(box, geom.portrait, scale, true)
    AddNameText(box, geom.name, scale, kit.retail and "PLAYER" or "KULLTHRAN", kit)

    -- Forever and Retail use the same real ornament as Classic (they share
    -- the same 36/30.5 anchor in KUIUnitFrames.lua), unconditionally, not
    -- gated behind an atlas badge lookup. Centering it ON the portrait
    -- photo via an atlas lookup doesn't match how the real ornament renders
    -- at all, and left Retail with no level circle.
    AddLevelBadge(box, scale, 36, 30.5)
end

-- KullThranUI's own flat renderer. The real kui frame has no panel, it
-- just floats portrait+bars directly with no container, so no panel fill
-- or hairline border is drawn for this kit. KUIUnitFrames.lua sizes an
-- attached portrait as `playerTargetHeight + portraitSize` (the SAME
-- height as the combined health+power bar stack, by default), not a
-- fraction of the card, so portrait size is tied directly to the real bar
-- stack height and the two stay in the same ratio the real frame uses.
-- Name sits above the bars (the real frame's name text floats above, not
-- overlaid on the health fill) and the level is a small dark badge
-- overlapping the portrait's bottom-left corner, matching the real
-- level-circle ornament instead of a floating corner label.
local function DrawFlatFrame(box, kit, scale, w, h, healthColor, accent)
    -- KUI Style's card shows the health and power bars without a portrait.
    local barsH = math.max(14, h - math.floor(h * 0.16))
    local powerH = math.max(3, math.floor(barsH * 6 / 26))
    local healthH = barsH - powerH

    local barsLeft = 0
    local barsWidth = math.max(24, w - barsLeft)
    local barsTop = -math.floor((h - barsH) * 0.5)

    -- MelliDark.tga is a HEALTH FILL texture option, not a pre-darkened
    -- backdrop asset -- the real frame only ever draws it tinted to #4f4f4f
    -- (DARK_BG_R/G/B in KUIUnitFrames.lua's CreateHealthBar). Drawn untinted
    -- its own native (bright) pixels show through as solid white.
    local track = box:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(KUI_BAR_TRACK)
    track:SetVertexColor(0x4f / 255 * 0.55, 0x4f / 255 * 0.55, 0x4f / 255 * 0.55, 1)
    track:SetPoint("TOPLEFT", box, "TOPLEFT", barsLeft, barsTop)
    track:SetSize(barsWidth, healthH)
    Unsnap(track)

    local FILL_FRACTION, ABSORB_FRACTION = 0.55, 0.23
    local health = box:CreateTexture(nil, "ARTWORK")
    health:SetTexture(KUI_BAR_FILL)
    health:SetVertexColor(healthColor[1], healthColor[2], healthColor[3], healthColor[4])
    box._ktSetHealthColor = function(color)
        -- Preserve the bar texture when changing the card's health color.
        health:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    end
    health:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    health:SetSize(math.max(6, barsWidth * FILL_FRACTION), healthH)
    Unsnap(health)

    local absorb = box:CreateTexture(nil, "ARTWORK")
    absorb:SetColorTexture(0.10, 0.86, 0.52, 1)
    absorb:SetPoint("TOPLEFT", health, "TOPRIGHT", 0, 0)
    absorb:SetSize(math.max(3, barsWidth * ABSORB_FRACTION), healthH)

    local power = box:CreateTexture(nil, "ARTWORK")
    power:SetTexture(KUI_BAR_FILL)
    power:SetVertexColor(kit.power[1], kit.power[2], kit.power[3], kit.power[4])
    power:SetPoint("TOPLEFT", track, "BOTTOMLEFT", 0, 0)
    power:SetSize(barsWidth, powerH)
    Unsnap(power)

    local textSize = Clamp(math.floor(healthH * 0.46), 7, 12)
    local name = box:CreateFontString(nil, "OVERLAY")
    name:SetFont(GetPreviewFont(), textSize, "OUTLINE")
    name:SetPoint("LEFT", track, "LEFT", 6, 0)
    name:SetText("Player")
    name:SetTextColor(1, 1, 1, 1)

    local value = box:CreateFontString(nil, "OVERLAY")
    value:SetFont(GetPreviewFont(), textSize, "OUTLINE")
    value:SetPoint("RIGHT", track, "RIGHT", -5, 0)
    value:SetText("78%")
    value:SetTextColor(1, 1, 1, 1)
end

--- Builds one theme's miniature on `stage`.
local function DrawScene(stage, themeKey, width, height)
    local kit = SCENES[themeKey] or SCENES.kui

    local stageBg = stage:CreateTexture(nil, "BACKGROUND")
    stageBg:SetAllPoints()
    stageBg:SetColorTexture(0.035, 0.040, 0.050, 1)

    -- No slot row: its real-asset end caps barely read at this size on
    -- Classic (two glyphs stuck together with nothing between them) or
    -- Retail (end-cap art nearly invisible), so the vertical space goes to
    -- a bigger, more accurate main preview instead.
    local padX, padTop, padBottom = 6, 6, 6
    local frameBand = height - padTop - padBottom
    -- kui's card is a reference sample of the theme's own default look,
    -- not a mirror of whatever the live profile happens to be customized
    -- to right now (Classic/Forever/Retail's health color stays
    -- live-reflecting on purpose, since their cards carry an explicit
    -- HEALTH/CLASS COLOR toggle for it) -- always show class-colored health
    -- here regardless of customFillColor/darkTheme.
    local healthColor = ResolveThemeHealthColor(themeKey, kit.health)
    local accent = ResolveThemeAccent(kit, healthColor)

    local box
    local scale
    if kit.kind == "flat" then
        scale = 1
        box = CreateFrame("Frame", nil, stage)
        -- Sized like the real circular frame (portrait ~46px against the
        -- 100px-wide stock box's proportions), not stretched to fill the
        -- whole stage -- the old full-height box turned the bars into
        -- chunky blocks nothing like the Unit Frames live preview.
        local boxH = Clamp(math.floor(frameBand * 0.45), 34, 60)
        box:SetSize(math.max(60, width - (padX * 2)), boxH)
        box:SetPoint("CENTER", stage, "CENTER", 0, 0)
        DrawFlatFrame(box, kit, 1, box:GetWidth(), box:GetHeight(), healthColor, accent)
        stage._ktPreviewBox = box
    else
        scale = math.min((width - (padX * 2)) / BOX_W, frameBand / BOX_H)
        scale = math.max(Clamp(scale, 0.35, 1.2), 0.3)
        box = CreateFrame("Frame", nil, stage)
        box:SetSize(BOX_W * scale, BOX_H * scale)
        -- Classic's real geometry (GEO.sheet) leaves a 42-unit margin
        -- before the portrait but only 7 after the health bar (portrait at
        -- x=42, health ends at x=225, out of a 232-wide box) -- an
        -- asymmetric real layout that reads as "pushed to the right" once
        -- wrapped in this card's own symmetric bordered box (the real
        -- floating in-game frame has no such box drawing attention to it).
        -- Forever/Retail's GEO.hud doesn't have this problem (its content
        -- spans 24-209, center within half a unit of the box's own center)
        -- so only Classic's box gets re-centered on its actual content
        -- rather than on the raw 232-unit virtual canvas -- the content
        -- geometry itself (GEO.sheet) is untouched, still exactly what the
        -- real frame uses.
        local xOffset = 0
        if kit.kind == "sheet" then
            local contentCenter = (42 + 225) / 2
            xOffset = -(contentCenter - (BOX_W / 2)) * scale
        end
        box:SetPoint("TOP", stage, "TOP", xOffset, -padTop)
        if kit.kind == "sheet" then
            DrawSheetFrame(box, kit, scale, healthColor, accent)
        else
            DrawHudFrame(box, kit, scale, healthColor, accent)
        end
        stage._ktPreviewBox = box
    end

    -- No second border around the whole `stage` (the card's fixed
    -- stageHeight area): AddPanel already draws its own border tightly
    -- around `box` (the content-fitted area) for sheet/hud kinds, and
    -- `box` is shorter than `stage` whenever width, not height, is the
    -- limiting factor in the scale calc, so the two borders never lined
    -- up and Classic's card showed a second, badly-fitted rectangle.
    -- AddPanel's box-level border already frames the miniature on its own
    -- (and kui intentionally has none).
end

--- Creates a live miniature of `themeKey` inside `parent`.
--- @return Frame stage the miniature was built on
function KT.VisualThemes:CreatePreview(parent, themeKey, options)
    options = options or {}
    if not parent then return nil end

    local width = math.max(80, tonumber(options.width) or parent:GetWidth() or 140)
    local height = math.max(52, tonumber(options.height) or parent:GetHeight() or 90)

    local stage = CreateFrame("Frame", nil, parent)
    stage:SetSize(width, height)
    if options.point then
        stage:SetPoint(options.point[1], options.point[2], options.point[3],
            options.point[4] or 0, options.point[5] or 0)
    else
        stage:SetPoint("TOPLEFT")
    end
    if stage.SetClipsChildren then stage:SetClipsChildren(true) end
    stage.themeKey = themeKey

    DrawScene(stage, themeKey, width, height)
    return stage
end

--- Repaints only the health fill of an already built preview, so the card's
--- health color controls react without rebuilding the whole miniature.
function KT.VisualThemes:RepaintPreviewHealth(stage, themeKey)
    if not stage then return end
    local box = stage._ktPreviewBox
    local setter = box and box._ktSetHealthColor
    if not setter then return end
    local kit = SCENES[themeKey] or SCENES.kui
    local color = ResolveThemeHealthColor(themeKey, kit.health)
    setter(color)
end

-- Cards currently on screen, so a health color change made on one card can
-- repaint all of them. Reset by CreateSelector on every rebuild.
function KT.VisualThemes:ResetCardHealthViews()
    self._ktCardHealthViews = {}
end

function KT.VisualThemes:RegisterCardHealthView(preview, themeKey, paintToggle)
    local views = self._ktCardHealthViews
    if not views then
        views = {}
        self._ktCardHealthViews = views
    end
    views[#views + 1] = { preview = preview, themeKey = themeKey, paintToggle = paintToggle }
end

--- Repaints every registered card's miniature health fill and its
--- HEALTH/CLASS segments from the live profile.
function KT.VisualThemes:RefreshAllCardHealth()
    local views = self._ktCardHealthViews
    if not views then return end
    for _, view in ipairs(views) do
        self:RepaintPreviewHealth(view.preview, view.themeKey)
        if type(view.paintToggle) == "function" then view.paintToggle() end
    end
end

--- Rebuilds `preview` for a different theme, in place, on the same parent.
function KT.VisualThemes:UpdatePreview(preview, themeKey, options)
    if preview then
        preview:Hide()
        preview:ClearAllPoints()
    end
    local parent = preview and preview:GetParent()
    if not parent then return nil end
    return self:CreatePreview(parent, themeKey, options)
end

--- Hides a preview without destroying it.
function KT.VisualThemes:ReleasePreview(preview)
    if not preview then return end
    preview:Hide()
    preview:ClearAllPoints()
end

-- Bigger, more accurate previews and less caption text. Every description
-- here is one short sentence that never needed 3 wrapped lines, so that
-- reserved line goes to stageHeight instead, on top of the room already
-- reclaimed by removing the slot row below.
-- The per-theme caption description is replaced by the real action-bar
-- end-cap art (capRowHeight replaces the old captionLines/captionSize-driven
-- height). This height is shared by every theme's row, so Classic's own
-- padding compensation is handled inside AddEndCapArt's own sizing
-- instead of inflating the row every theme shares.
-- Title/tag hierarchy runs bigger (~17px/11px) and un-outlined, versus
-- the 12-14px/8-9px outlined pair this used before.
-- The action-bar art (end caps + mini slots, both driven by capRowHeight)
-- is 10% bigger across the board -- 22/26 -> 24/29.
local CARD_METRICS = {
    compact = {
        titleSize = 14, tagSize = 10, capRowHeight = 27,
        stageHeight = 106, buttonHeight = 24, buttonPad = 10, captionPad = 7,
    },
    full = {
        titleSize = 17, tagSize = 11, capRowHeight = 32,
        stageHeight = 142, buttonHeight = 28, buttonPad = 12, captionPad = 8,
    },
}

local function ComputeCardHeight(metrics)
    local titleBand = math.ceil(metrics.titleSize * 1.35) + 3
    -- Kept in sync with stageTop's own tag->stage gap in CreateThemeCard.
    local tagBand = math.ceil(metrics.tagSize * 1.5) + 12
    return 5 + titleBand + tagBand + metrics.stageHeight + metrics.captionPad
        + metrics.capRowHeight + metrics.buttonPad + metrics.buttonHeight + metrics.buttonPad
end

-- A real health color selector for the stock-art themes, whose health color
-- is otherwise fixed by the theme's own seed (healthClassColored=false,
-- customFillColor=green). It is a CLASS toggle plus a swatch wired to the
-- color picker, so any color can be picked. kui already exposes the same two
-- fields through its own general unit frame options, so it doesn't need a
-- duplicate control here.
local HEALTH_COLOR_TOGGLE_THEMES = { kui = true, classic = true, forever = true, retail = true }
-- Thinner and more readable than the original 30/38.
local HEALTH_TOGGLE_ROW_HEIGHT_COMPACT = 22
local HEALTH_TOGGLE_ROW_HEIGHT_FULL = 26

--- Builds one pickable theme card: accent band, title, tag, the live
--- miniature, a caption, an apply button and the IN USE state.
--- @return Frame card, number height
function KT.VisualThemes:CreateThemeCard(parent, themeKey, options)
    options = options or {}
    local catalog = self:GetThemeCatalog()
    local theme = catalog and catalog[themeKey]
    if not theme then return nil, 0 end

    local compact = options.compact == true
    local metrics = compact and CARD_METRICS.compact or CARD_METRICS.full
    local width = tonumber(options.width) or (compact and 190 or 200)
    local showHealthToggle = HEALTH_COLOR_TOGGLE_THEMES[themeKey] == true
    local healthToggleHeight = compact and HEALTH_TOGGLE_ROW_HEIGHT_COMPACT
        or HEALTH_TOGGLE_ROW_HEIGHT_FULL
    -- Every card must be the same size. kui has no health-color toggle
    -- row, so it used to come out shorter than the other three by exactly
    -- healthToggleHeight -- reserve that same footer space on every card
    -- regardless of whether it draws the row, rather than only on the
    -- themes that actually show one.
    local extraHeight = healthToggleHeight
    local height = tonumber(options.height) or (ComputeCardHeight(metrics) + extraHeight)

    local accent = ResolveCardBrandColor(themeKey, theme.color)
    local inUse = self:GetRenderedTheme() == themeKey

    local card = CreateFrame("Button", nil, parent)
    card:SetSize(width, height)
    card:SetFrameLevel((parent.GetFrameLevel and parent:GetFrameLevel() or 1) + 1)

    local fx = KT.BrutalCard and KT.BrutalCard.Style(card, { accent = accent, inUse = inUse })
    local body = fx and fx.body or card
    if not fx then Solid(card, "BACKGROUND", { 0.055, 0.065, 0.080, 0.98 }) end

    -- No OUTLINE on all three: an un-outlined typography hierarchy reads
    -- cleaner at the larger sizes above.
    local title = body:CreateFontString(nil, "OVERLAY")
    title:SetFont(GetPreviewFont(), metrics.titleSize)
    title:SetPoint("TOP", body, "TOP", 0, -(6 + math.ceil(metrics.titleSize * 0.6)))
    title:SetText(T(theme.name))
    title:SetTextColor(accent[1], accent[2], accent[3], 1)

    local tag = body:CreateFontString(nil, "OVERLAY")
    tag:SetFont(GetPreviewFont(), metrics.tagSize)
    tag:SetPoint("TOP", title, "BOTTOM", 0, -3)
    tag:SetText(T(theme.shortName or ""))
    tag:SetTextColor(accent[1], accent[2], accent[3], 0.7)

    -- IN USE used to sit in the card's top-right corner, where it ran into
    -- the centered title ("KULLTHRANUI STYLE" is nearly as wide as the card).
    -- It is now a small pill on the subtitle line, placed right after the
    -- subtitle text itself, so the two can never overlap; the pair is
    -- re-centered as a group so the card stays visually balanced.
    local badge = CreateFrame("Frame", nil, body)
    local badgeLabel = badge:CreateFontString(nil, "OVERLAY")
    badgeLabel:SetFont(GetPreviewFont(), math.max(8, metrics.tagSize - 1))
    badgeLabel:SetText(T("IN USE"))
    badgeLabel:SetTextColor(accent[1], accent[2], accent[3], 1)
    local badgeW = math.ceil(badgeLabel:GetStringWidth() or 30) + 12
    local badgeH = metrics.tagSize + 5
    badge:SetSize(badgeW, badgeH)
    badgeLabel:SetPoint("CENTER", badge, "CENTER", 0, 0)
    local badgeBg = badge:CreateTexture(nil, "BACKGROUND")
    badgeBg:SetAllPoints()
    badgeBg:SetColorTexture(accent[1], accent[2], accent[3], 0.16)
    for _, e in ipairs({
        { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
        { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
    }) do
        local edge = badge:CreateTexture(nil, "OVERLAY")
        edge:SetPoint(e[1], badge, e[1])
        edge:SetPoint(e[2], badge, e[2])
        if e[3] then edge:SetHeight(1) else edge:SetWidth(1) end
        edge:SetColorTexture(accent[1], accent[2], accent[3], 0.85)
    end
    if inUse then
        local tagW = tag:GetStringWidth() or 0
        local groupW = tagW + 8 + badgeW
        tag:ClearAllPoints()
        tag:SetPoint("TOPLEFT", title, "BOTTOM", -groupW / 2, -3)
        badge:SetPoint("LEFT", tag, "RIGHT", 8, 0)
    end
    badge:SetShown(inUse)

    -- Vertical rhythm matched to the reference: ~3px title->tag,
    -- ~12px tag->stage (was 5).
    local stageTop = 5 + math.ceil(metrics.titleSize * 1.35) + 3
        + math.ceil(metrics.tagSize * 1.5) + 12
    local stage = CreateFrame("Frame", nil, body)
    stage:SetPoint("TOPLEFT", body, "TOPLEFT", 8, -stageTop)
    stage:SetPoint("TOPRIGHT", body, "TOPRIGHT", -8, -stageTop)
    stage:SetHeight(metrics.stageHeight)
    local preview = self:CreatePreview(stage, themeKey, {
        width = math.max(80, width - 16),
        height = metrics.stageHeight,
    })

    -- No per-theme description text here -- the real action-bar end-cap
    -- art goes in its place instead.
    -- Lifted a little (the card keeps its height, so the extra room opens
    -- up above the Apply button): Classic's oversized end caps used to touch it.
    AddEndCapArt(body, SCENES[themeKey] or SCENES.kui, stage, math.max(1, metrics.captionPad - 5), metrics.capRowHeight)

    local button = CreateFrame("Button", nil, body)
    button:SetSize(width - 16, metrics.buttonHeight)
    button:SetPoint("BOTTOM", body, "BOTTOM", 0, metrics.buttonPad + extraHeight)

    -- Primary action: a dark base tinted with the card's own accent, a
    -- hairline accent border, a soft top highlight and a 2px accent bar
    -- along the bottom edge. Hover floods the tint and lights the border;
    -- the already-applied card dims all of it, so the one actionable button
    -- in the row stands out at a glance.
    local buttonBg = button:CreateTexture(nil, "BACKGROUND")
    buttonBg:SetAllPoints()
    local buttonTint = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    buttonTint:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    buttonTint:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    local buttonSheen = button:CreateTexture(nil, "ARTWORK")
    buttonSheen:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    buttonSheen:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
    buttonSheen:SetHeight(math.max(2, math.floor(metrics.buttonHeight * 0.4)))
    local buttonBar = button:CreateTexture(nil, "ARTWORK", nil, 1)
    buttonBar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    buttonBar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    buttonBar:SetHeight(2)
    local buttonLabel = button:CreateFontString(nil, "OVERLAY")
    buttonLabel:SetFont(GetPreviewFont(), metrics.tagSize + 2)
    buttonLabel:SetPoint("CENTER", button, "CENTER", 0, 1)
    buttonLabel:SetWidth(width - 28)
    buttonLabel:SetWordWrap(false)
    buttonLabel:SetText(T("APPLY TO ALL"))

    local buttonEdges = MakeBorder(button, "_ktPreviewButtonBorder", { 0, 0, 0, 1 }, 1)

    local hovered = false

    local function PaintButton()
        local r, g, b = accent[1], accent[2], accent[3]
        if inUse then
            buttonBg:SetColorTexture(0.05, 0.055, 0.065, 1)
            buttonTint:SetColorTexture(r, g, b, 0.05)
            buttonSheen:SetColorTexture(1, 1, 1, 0.015)
            buttonBar:SetColorTexture(r, g, b, 0.35)
            buttonLabel:SetTextColor(0.62, 0.65, 0.72, 1)
            PaintBorder(buttonEdges, { 1, 1, 1, 0.10 }, 1)
        else
            buttonBg:SetColorTexture(0.055, 0.06, 0.075, 1)
            buttonTint:SetColorTexture(r, g, b, hovered and 0.38 or 0.17)
            buttonSheen:SetColorTexture(1, 1, 1, hovered and 0.10 or 0.05)
            buttonBar:SetColorTexture(r, g, b, 1)
            buttonLabel:SetTextColor(1, 1, 1, 1)
            PaintBorder(buttonEdges, { r, g, b, hovered and 1 or 0.6 }, 1)
        end
    end

    local function Paint()
        local lit = inUse or hovered
        if not fx then PaintBorder(card._ktPreviewCardBorder, lit and accent or { 1, 1, 1, 0.16 }, lit and 2 or 1) end
        PaintButton()
        if fx then
            KT.BrutalCard.SetInUse(card, inUse)
            KT.BrutalCard.SetHover(card, hovered)
        end
    end

    if not fx then card._ktPreviewCardBorder = MakeBorder(card, "_ktPreviewCardBorder", { 1, 1, 1, 0.16 }, 1) end

    local function Apply()
        if inUse then return end
        KT.VisualThemes:RequestApply(themeKey)
    end

    card:SetScript("OnClick", Apply)
    card:SetScript("OnEnter", function(self)
        hovered = true
        Paint()
    end)
    card:SetScript("OnLeave", function()
        hovered = false
        Paint()
    end)

    button:SetScript("OnClick", Apply)
    button:SetScript("OnEnter", function(self)
        card:GetScript("OnEnter")(card)
    end)
    button:SetScript("OnLeave", function(self)
        card:GetScript("OnLeave")(card)
    end)

    if showHealthToggle then
        local function GetUFProfile()
            return KT.db and KT.db.profile and KT.db.profile.unitFrames
        end

        -- Read-only: this getter is called from IsClassColored()/
        -- GetCustomColor(), which PaintToggle() (and therefore every
        -- OnEnter/OnLeave hover handler) calls on every hover, not just on
        -- an actual click. Mutating profile.player into a fresh empty table
        -- here made hovering the controls change them on their own.
        -- Commit() below already creates the table properly when something
        -- is actually being written.
        local function IsClassColored()
            return (GetThemeHealthChoice(themeKey))
        end

        local function GetCustomColor()
            local _, custom = GetThemeHealthChoice(themeKey)
            return custom
        end

        -- Repaint only the two health elements changed by this selector.
        -- The full Mod:Refresh() path also reapplies frame positions/scales,
        -- which made Player/Target jump temporarily after a color click.
        local function RefreshUnitFrames()
            local Mod = KT.GetModule and KT:GetModule("UnitFrames", true)
            if not Mod then return end
            if type(Mod.RefreshHealthColors) == "function" then
                Mod:RefreshHealthColors()
            end
        end

        local function Commit(classColored, color)
            local profile = GetUFProfile()
            if not profile then return end
            -- This card's own choice, independent of the other themes.
            local root = KT.db.profile
            root.visualThemeHealth = type(root.visualThemeHealth) == "table" and root.visualThemeHealth or {}
            local _, previousColor = GetThemeHealthChoice(themeKey)
            local saved = color or previousColor
            root.visualThemeHealth[themeKey] = {
                classColored = classColored,
                color = { r = saved[1] or 1, g = saved[2] or 1, b = saved[3] or 1 },
            }
            -- The live frames only follow the theme that is actually
            -- rendered; the other cards just remember their choice.
            if self:GetRenderedTheme() ~= themeKey then
                self:RepaintPreviewHealth(preview, themeKey)
                return
            end
            -- Forever's former preset enabled darkTheme, whose renderer has
            -- higher priority than both class and custom health colors. Once
            -- either control is chosen, the selector must own the fill.
            if self:GetRenderedTheme() == themeKey then
                profile.darkTheme = false
            end
            for _, key in ipairs({ "player", "target" }) do
                profile[key] = type(profile[key]) == "table" and profile[key] or {}
                profile[key].healthClassColored = classColored
                if color then
                    profile[key].customFillColor = {
                        r = color[1] or 1, g = color[2] or 1, b = color[3] or 1,
                    }
                elseif not classColored and type(profile[key].customFillColor) ~= "table" then
                    profile[key].customFillColor = { r = 0.10, g = 0.90, b = 0.10 }
                end
            end
            self:RepaintPreviewHealth(preview, themeKey)
            RefreshUnitFrames()
        end

        local toggleRow = CreateFrame("Frame", nil, body)
        local rowWidth = width - 16
        local gap = 4
        local half = (rowWidth - gap) / 2
        toggleRow:SetSize(rowWidth, healthToggleHeight)
        toggleRow:SetPoint("BOTTOM", body, "BOTTOM", 0, metrics.buttonPad)

        -- Segmented control: one shared dark track with two halves. The
        -- active half gets a tinted background, a 2px color bar along its
        -- bottom edge and a bright label; the inactive one stays muted.
        -- Each half carries a small color chip so what it controls is
        -- readable at a glance (custom color / class color), instead of the
        -- old flat color blocks with outlined text.
        local trackBg = toggleRow:CreateTexture(nil, "BACKGROUND")
        trackBg:SetAllPoints()
        trackBg:SetColorTexture(0.03, 0.035, 0.045, 1)
        MakeBorder(toggleRow, "_ktPreviewToggleBorder", { 1, 1, 1, 0.14 }, 1)

        local segHalf = (rowWidth - 3) / 2
        local segHeight = healthToggleHeight - 2
        local chipSize = math.max(8, math.floor(healthToggleHeight * 0.42))

        local function BuildSegment(side, text)
            local seg = CreateFrame("Button", nil, toggleRow)
            seg:SetSize(segHalf, segHeight)
            seg:SetPoint(side, toggleRow, side, side == "LEFT" and 1 or -1, 0)
            seg.bg = seg:CreateTexture(nil, "BACKGROUND")
            seg.bg:SetAllPoints()
            seg.bar = seg:CreateTexture(nil, "ARTWORK")
            seg.bar:SetPoint("BOTTOMLEFT", seg, "BOTTOMLEFT", 0, 0)
            seg.bar:SetPoint("BOTTOMRIGHT", seg, "BOTTOMRIGHT", 0, 0)
            seg.bar:SetHeight(2)
            seg.chipEdge = seg:CreateTexture(nil, "ARTWORK")
            seg.chipEdge:SetSize(chipSize + 2, chipSize + 2)
            seg.chipEdge:SetPoint("LEFT", seg, "LEFT", 9, 1)
            seg.chip = seg:CreateTexture(nil, "ARTWORK", nil, 1)
            seg.chip:SetSize(chipSize, chipSize)
            seg.chip:SetPoint("CENTER", seg.chipEdge, "CENTER", 0, 0)
            seg.label = seg:CreateFontString(nil, "OVERLAY")
            seg.label:SetFont(GetPreviewFont(), metrics.tagSize + 1)
            seg.label:SetPoint("LEFT", seg.chipEdge, "RIGHT", 7, 0)
            seg.label:SetWidth(math.max(20, segHalf - chipSize - 26))
            seg.label:SetJustifyH("LEFT")
            seg.label:SetWordWrap(false)
            seg.label:SetText(T(text))
            return seg
        end

        local swatchOpt = BuildSegment("LEFT", "HEALTH")
        local classOpt = BuildSegment("RIGHT", "CLASS")

        local classHovered, swatchHovered = false, false

        local function PaintSegment(seg, active, hovered, color)
            local r, g, b = color[1], color[2], color[3]
            if active then
                seg.bg:SetColorTexture(0.06 + r * 0.20, 0.065 + g * 0.20, 0.08 + b * 0.20, 1)
                seg.bar:SetColorTexture(r, g, b, 1)
                seg.label:SetTextColor(1, 1, 1, 1)
                seg.chip:SetColorTexture(r, g, b, 1)
                seg.chipEdge:SetColorTexture(1, 1, 1, 0.55)
            else
                local shade = hovered and 0.115 or 0.065
                seg.bg:SetColorTexture(shade, shade + 0.005, shade + 0.018, 1)
                seg.bar:SetColorTexture(1, 1, 1, hovered and 0.28 or 0)
                seg.label:SetTextColor(0.66, 0.69, 0.76, 1)
                seg.chip:SetColorTexture(r * 0.8, g * 0.8, b * 0.8, 1)
                seg.chipEdge:SetColorTexture(0, 0, 0, 0.9)
            end
        end

        local function PaintToggle()
            local classColored = IsClassColored()
            PaintSegment(classOpt, classColored, classHovered, LivePlayerClassColor())
            PaintSegment(swatchOpt, not classColored, swatchHovered, GetCustomColor())
        end

        local function PickColor()
            local custom = GetCustomColor()
            -- Class coloring off first, otherwise the picked value lands in the
            -- profile but is never shown, which reads as a dead picker.
            Commit(false, custom)
            PaintToggle()

            local picker = _G.ColorPickerFrame
            if not picker then return end

            local function OnPicked(r, g, b)
                Commit(false, { r, g, b })
                PaintToggle()
            end

            local function ReadAndCommitPickerColor()
                local r, g, b = picker:GetColorRGB()
                OnPicked(r, g, b)
            end

            local function RestoreOriginalColor()
                Commit(false, custom)
                PaintToggle()
            end

            if type(picker.SetupColorPickerAndShow) == "function" then
                picker:SetupColorPickerAndShow({
                    r = custom[1],
                    g = custom[2],
                    b = custom[3],
                    hasOpacity = false,
                    swatchFunc = ReadAndCommitPickerColor,
                    cancelFunc = RestoreOriginalColor,
                })
            else
                picker.func = ReadAndCommitPickerColor
                picker.cancelFunc = RestoreOriginalColor
                picker.hasOpacity = false
                picker:SetColorRGB(custom[1], custom[2], custom[3])
                picker:Hide()
                picker:Show()
            end
        end

        classOpt:SetScript("OnClick", function()
            Commit(true, nil)
            PaintToggle()
        end)
        swatchOpt:SetScript("OnClick", PickColor)

        classOpt:SetScript("OnEnter", function()
            classHovered = true
            PaintToggle()
        end)
        classOpt:SetScript("OnLeave", function()
            classHovered = false
            PaintToggle()
        end)

        swatchOpt:SetScript("OnEnter", function()
            swatchHovered = true
            PaintToggle()
        end)
        swatchOpt:SetScript("OnLeave", function()
            swatchHovered = false
            PaintToggle()
        end)

        PaintToggle()
        self:RegisterCardHealthView(preview, themeKey, PaintToggle)
    end

    Paint()
    return card, height
end
