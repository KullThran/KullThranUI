local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local W = KT.Widgets
local LSM = LibStub("LibSharedMedia-3.0", true)

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

local function GetDB()
    if not (KT and KT.db and KT.db.profile) then return nil end
    KT.db.profile.unitFrames = KT.db.profile.unitFrames or {}
    if KT.db.profile.unitFrames.enable == nil then
        KT.db.profile.unitFrames.enable = true
    end
    return KT.db.profile.unitFrames
end

local function GetModule()
    return KT:GetModule("UnitFrames", true)
end

local previewRefresh
local PREVIEW_DEFAULT_FONT = KT.FONT_PATH or KT.FALLBACK_FONT_PATH or "Fonts\\FRIZQT__.TTF"
local PREVIEW_FONT = PREVIEW_DEFAULT_FONT
local PREVIEW_FILL = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\MelliReforged.tga"
local PREVIEW_BG = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga"
local PREVIEW_CLASS_TEXTURE = "Interface\\TargetingFrame\\UI-Classes-Circles"
local PREVIEW_PORTRAIT_MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
local PREVIEW_CIRCLE_MASK = PREVIEW_PORTRAIT_MEDIA .. "circle_mask.tga"
local PREVIEW_CIRCLE_BORDER = PREVIEW_PORTRAIT_MEDIA .. "circle_border.tga"
local PREVIEW_ABSORB_VALUE = 22
local PREVIEW_DYNAMIC_UNITS = { "pet", "focus", "target", "totPet", "focustarget" }

-- Real stock geometry inside Blizzard's 232x100 unit-frame box. Mirrors
-- FOREVER_FRAME_GEOMETRY in ThemeClientAssets.lua so the preview can seat the
-- genuine stock artwork on the preview units. Only player and target have
-- verified geometry, so only those two ever get stock art.
-- Keyed by kit: Classic uses a completely different
-- raw-texture-with-texcoord-fractions technique (see CLASSIC_FRAME_GEOMETRY
-- in ThemeClientAssets.lua) and different portrait/health/power/name
-- positions than Forever/Retail's atlas-based art, so reusing one table for
-- every theme made the preview mismatch the active theme and sit
-- misaligned.
local PREVIEW_STOCK_GEOMETRY = {
    forever = {
        player = {
            w = 232, h = 100,
            art = "UI-HUD-UnitFrame-Player-PortraitOn",
            mirror = nil,
            portrait = { point = "TOPLEFT", x = 24, y = -19, size = 60 },
            health = { x = 85, y = 40, w = 124, h = 20 },
            power = { x = 85, y = 61, w = 124, h = 10 },
            name = { x = 88, y = -27, w = 96, h = 14 },
        },
        target = {
            w = 232, h = 100,
            art = "UI-HUD-UnitFrame-Player-PortraitOn",
            mirror = true,
            portrait = { point = "TOPRIGHT", x = -24, y = -19, size = 60 },
            health = { x = 23, y = 40, w = 124, h = 20 },
            power = { x = 23, y = 61, w = 124, h = 10 },
            name = { x = 48, y = -27, w = 96, h = 14 },
        },
        -- Pet: mini ToT atlas (mirrors PetArt.geom.forever in ThemeClientAssets.lua).
        pet = {
            w = 120, h = 49,
            art = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn",
            portrait = { point = "TOPLEFT", x = 5, y = -5, size = 37 },
            health = { x = 44, y = 17, w = 70, h = 10 },
            power = { x = 40, y = 28, w = 74, h = 7 },
            name = { x = 44, y = -5, w = 68 },
        },
    },
    -- Classic's art is a raw fixed-path texture addressed by texcoord
    -- fractions (l/r/t/b), not an atlas -- ApplyStockArtTexture can't
    -- render it, so `rawTexture` + `texCoord` are handled separately in
    -- ApplyStockLayoutToPreview.
    classic = {
        player = {
            w = 232, h = 100,
            rawTexture = [[Interface\TargetingFrame\UI-TargetingFrame]],
            texCoord = { l = 1, r = 0.09375, t = 0, b = 0.78125 },
            portrait = { point = "TOPLEFT", x = 42, y = -12, size = 64 },
            health = { x = 106, y = 41, w = 119, h = 12 },
            power = { x = 106, y = 52, w = 119, h = 12 },
            -- CLASSIC_FRAME_GEOMETRY's own real name anchor is CENTER-based
            -- (a different convention than Forever's TOPLEFT one this preview
            -- code expects); approximated here as a TOPLEFT offset sitting
            -- just above the health bar instead, close enough for a preview.
            name = { x = 106, y = -30, w = 100 },
        },
        target = {
            w = 232, h = 100,
            rawTexture = [[Interface\TargetingFrame\UI-TargetingFrame]],
            texCoord = { l = 0.09375, r = 1, t = 0, b = 0.78125 },
            portrait = { point = "TOPRIGHT", x = -42, y = -12, size = 64 },
            health = { x = 7, y = 41, w = 119, h = 12 },
            power = { x = 7, y = 52, w = 119, h = 12 },
            name = { x = 7, y = -30, w = 100 },
        },
        -- Pet: UI-SmallTargetingFrame (128x64 sheet in a 128x53 box); mirrors PetArt.geom.classic.
        pet = {
            w = 128, h = 53,
            rawTexture = [[Interface\TargetingFrame\UI-SmallTargetingFrame]],
            texCoord = { l = 0, r = 1, t = 0, b = 1 },
            artW = 128, artH = 64, artX = 0, artY = -2,
            portrait = { point = "TOPLEFT", x = 7, y = -6, size = 37 },
            health = { x = 47, y = 22, w = 69, h = 8 },
            power = { x = 47, y = 29, w = 69, h = 8 },
            name = { x = 50, y = -9, w = 70 },
        },
    },
}
PREVIEW_STOCK_GEOMETRY.retail = PREVIEW_STOCK_GEOMETRY.forever

-- Forward declarations. ApplyStockPreviewColors (below) needs these two, but
-- they are defined much further down this file. They MUST be declared local
-- here, above every use: a `local` declared later would only scope from that
-- point onward, so the earlier functions would resolve these names as globals
-- (nil) and fail with "attempt to call a nil value".
local GetPreviewClassColor
local ResolvePreviewBarTexture

-- Active visual theme, so the preview reflects what is actually applied
-- instead of always drawing KUI's Melli look.
local function ActiveVisualTheme()
    local vt = KT and KT.VisualThemes
    -- GetRenderedTheme is what the rest of the options already consult; it is
    -- the authoritative "what is on screen right now". Fall back to the engine
    -- state if that accessor is unavailable.
    if type(vt) == "table" and type(vt.GetRenderedTheme) == "function" then
        local ok, rendered = pcall(vt.GetRenderedTheme, vt)
        if ok and type(rendered) == "string" and rendered ~= "" then
            return rendered
        end
    end
    local state = vt and vt.state
    local active = type(state) == "table" and state.active or nil
    if type(active) ~= "string" or active == "" then
        return "kui"
    end
    return active
end

-- "kui" is the only theme that renders KUI's own attached/circular frames, so
-- it is the only one whose options stay editable (see ApplyThemeOwnershipLock).
local function ActiveThemeOwnsFrameArt()
    return ActiveVisualTheme() ~= "kui"
end

--- Disables a widget and everything under it, so a locked control cannot be
--- re-enabled by a child button/EditBox that still has its own mouse enabled.
--- @param frame table
local function DisableWidgetTree(frame)
    if type(frame) ~= "table" then return end
    if type(frame.SetEnabled) == "function" then frame:SetEnabled(false) end
    if type(frame.EnableMouse) == "function" then frame:EnableMouse(false) end
    local children = { "editBox", "input", "button", "btn", "slider", "track" }
    for index = 1, #children do
        local child = frame[children[index]]
        if type(child) == "table" then
            DisableWidgetTree(child)
        end
    end
end

--- Locks a widget when the active visual theme owns the setting it edits.
--- Ownership is read from the adapter's own getOwnedPaths contract (see
--- Adapters/UnitFrames.lua) rather than a duplicated list, so a setting the
--- theme rewrites on every switch cannot be silently edited into a value that
--- gets overwritten later. kui keeps everything editable.
--- @param widget table|nil
--- @param path string|nil db path, e.g. "player.frameScale"
--- @return table|nil widget
-- Color fields stay editable on every theme, not just kui -- seed() still
-- sets Classic/Forever/Retail's own default color on an explicit theme
-- switch (gold/bronze/class color), but the user can change it afterward
-- regardless of which theme owns the rest of the frame art/geometry. Only
-- the non-color fields in getOwnedPaths() (portraitStyle, frameArtKit,
-- healthBarTexture, frameScale, showPlayerCastbar, showPvPCircle) still
-- lock, since those genuinely are the theme's own real-asset
-- geometry/behavior, not a color choice.
local function IsColorOwnedPath(path)
    return path:match("%.borderColor%.[rgb]$") ~= nil
        or path:match("%.customFillColor%.[rgb]$") ~= nil
        or path:match("%.healthClassColored$") ~= nil
        -- Bar texture is a per-style user choice: the engine stores it in
        -- each theme's own slot (SaveSlot on switch), so it never locks.
        or path:match("%.healthBarTexture$") ~= nil
end

local function LockIfThemeOwned(widget, path)
    if not (widget and path) then return widget end
    if not ActiveThemeOwnsFrameArt() then return widget end
    if IsColorOwnedPath(path) then return widget end

    local vt = KT and KT.VisualThemes
    local adapter = (type(vt) == "table" and type(vt.GetModuleAdapter) == "function")
        and vt:GetModuleAdapter("unitframes") or nil
    if not (adapter and type(adapter.getOwnedPaths) == "function") then return widget end

    local owned = adapter.getOwnedPaths()
    if type(owned) ~= "table" then return widget end

    for index = 1, #owned do
        if owned[index] == path then
            DisableWidgetTree(widget)
            widget._ktThemeOwned = true
            break
        end
    end
    return widget
end

--- Points a texture at a real stock atlas, preferring the Retail pixel sheet
--- so the preview shows genuine Retail art even on a Forever client.
--- @param tex Texture
--- @param atlasName string
--- @param mirror boolean|nil
--- @return boolean applied
-- KT.GetRetailAtlasPixels is a theme-agnostic lookup -- it only compares
-- the CURRENT CLIENT's live atlas file against the known real-retail file,
-- with no idea which theme is asking for it. Called unconditionally, it's
-- exactly as likely to fire for Forever's own preview as for Retail's;
-- whichever one it doesn't apply cleanly to falls through to the plain
-- SetAtlas call, which always shows the client's own reskin regardless of
-- which theme that was meant for (Retail's preview showed Forever's
-- bronze art). The in-game renderer (ThemeClientAssets.lua) avoids this
-- by going through KT.ResolveRetailAtlasOverride, which explicitly gates
-- on GetRenderedTheme() == "retail" before ever attempting the override
-- -- this uses that same function.
local function ApplyStockArtTexture(tex, atlasName, mirror)
    if not (tex and atlasName) then return false end

    local info = (type(KT.ResolveRetailAtlasOverride) == "function" and KT.ResolveRetailAtlasOverride(atlasName))
        or (type(KT.ResolveForeverAtlasOverride) == "function" and KT.ResolveForeverAtlasOverride(atlasName))
        or nil
    if info and (info.file or info.filename) and info.leftTexCoord and info.rightTexCoord
        and info.topTexCoord and info.bottomTexCoord then
        tex:SetTexture(info.file or info.filename)
        if mirror then
            tex:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord, info.bottomTexCoord)
        else
            tex:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
        end
        return true, info.width, info.height
    end

    if type(tex.SetAtlas) == "function" then
        tex:SetAtlas(atlasName, false)
        -- This fallback path (taken for Forever specifically, since
        -- ResolveRetailAtlasOverride correctly gates to retail-only and
        -- returns nil here) used to ignore `mirror` -- target's ring
        -- rendered in the SAME orientation as player's instead of flipped
        -- to match its portrait sitting on the opposite side of the frame,
        -- so the portrait icon poked out past the ring in the Live
        -- Preview. SetAtlas has no native mirror argument; flipping the
        -- texcoords afterward achieves the same horizontal flip the
        -- RetailPixels branch above already does correctly.
        if mirror then
            tex:SetTexCoord(1, 0, 0, 1)
        else
            tex:SetTexCoord(0, 1, 0, 1)
        end
        local atlasInfo = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlasName)
        return true, atlasInfo and atlasInfo.width, atlasInfo and atlasInfo.height
    end
    return false
end

--- Reseats a preview unit onto the real stock 232x100 layout: genuine atlas
--- artwork, the stock portrait cutout, and the stock bar rectangles. Returns
--- false when the unit has no verified stock geometry, so the caller falls
--- back to KUI's own layout.
--- @param frame table preview unit
--- @param unitKey string
--- @param settings table
--- @return boolean handled
local function ApplyStockLayoutToPreview(frame, unitKey, settings)
    local themeKey = ActiveVisualTheme()
    local kit = PREVIEW_STOCK_GEOMETRY[themeKey] or PREVIEW_STOCK_GEOMETRY.forever
    local geom = kit[unitKey]
    if not geom then return false end

    local scale = (settings.frameScale or 100) / 100
    if unitKey == "pet" then
        -- Same rule as the live pet art: frame width scales the stock box (101 = default).
        scale = scale * math.max(0.5, math.min(3, (tonumber(settings.frameWidth) or 101) / 101))
    end
    frame:ClearAllPoints()
    frame:SetSize(geom.w * scale, geom.h * scale)

    local artApplied, nativeW, nativeH
    if geom.rawTexture then
        -- Classic's real art is a fixed-path texture cropped by texcoord
        -- fractions, not an atlas -- ApplyStockArtTexture only knows atlases.
        frame.stockArt:SetTexture(geom.rawTexture)
        local tc = geom.texCoord
        frame.stockArt:SetTexCoord(tc.l, tc.r, tc.t, tc.b)
        artApplied = true
    else
        artApplied, nativeW, nativeH = ApplyStockArtTexture(frame.stockArt, geom.art, geom.mirror)
    end
    if artApplied then
        frame.stockArt:ClearAllPoints()
        if geom.rawTexture then
            frame.stockArt:SetSize((geom.artW or geom.w) * scale, (geom.artH or geom.h) * scale)
            frame.stockArt:SetPoint("TOPLEFT", frame, "TOPLEFT", (geom.artX or 0) * scale, (geom.artY or 0) * scale)
        else
            -- Like the real frame (ApplyForeverUnitFrameArt): the atlas is
            -- the visible artwork at its NATIVE size, centred in the 232x100
            -- box -- stretching it to the box (as this did) pushed the ring
            -- and the bar tracks away from the bars seated on the box rects.
            frame.stockArt:SetSize((nativeW or geom.w) * scale, (nativeH or geom.h) * scale)
            frame.stockArt:SetPoint("CENTER", frame, "CENTER", 0, 0)
        end
        frame.stockArt:Show()
    else
        frame.stockArt:Hide()
    end

    local portraitGeom = geom.portrait
    local portraitSize = portraitGeom.size * scale
    frame.portraitFrame:ClearAllPoints()
    frame.portraitFrame:SetSize(portraitSize, portraitSize)
    frame.portraitFrame:SetPoint(
        portraitGeom.point, frame, portraitGeom.point,
        portraitGeom.x * scale, portraitGeom.y * scale)
    frame.portraitFrame:Show()

    -- circle_mask.tga's own measured padding (1.23x) alone still leaves a
    -- visible gap. This ring's own silhouette is NOT a plain circle (it
    -- has a flat/pointed bottom corner, same dome shape as the real
    -- in-game ornament), which defeats a simple horizontal pixel scan for
    -- measuring it precisely, so the compensation is larger: this layer
    -- sits ABOVE the ring (frame.portraitFrame's level is +20 over
    -- frame's own), so overshoot would cover part of the ring's gold
    -- edge, while undershoot leaves the background gap.
    local MASK_PAD_RATIO = 1.55
    -- Classic's real frame (ThemeClientAssets.lua ApplyClassicUnitFrameArt)
    -- keeps the photo at exactly the stock 64px box, clipped to it, and only
    -- expands the circular MASK around it. Scaling the photo itself by 1.55
    -- here (as Forever/Retail's preview does) made Classic's preview portrait
    -- spill outside the ring. Mirror the real frame for Classic instead.
    local isClassicPreview = themeKey == "classic"
    -- Forever/Retail too: the real frame keeps the photo at the stock size,
    -- clipped to it, with the mask expanded 5 units around it
    -- (SeatStockPortrait). Scaling the photo itself by MASK_PAD_RATIO made
    -- the preview face spill past the ring.
    local iconSize = portraitSize
    frame.portraitFrame:SetClipsChildren(true)
    frame.portrait:ClearAllPoints()
    frame.portrait:SetSize(iconSize, iconSize)
    frame.portrait:SetPoint("CENTER", frame.portraitFrame, "CENTER")

    -- This whole function returns true to ApplyPreviewUnit's caller, which
    -- then RETURNS EARLY (see the `if ... and ApplyStockLayoutToPreview(...)
    -- then ... return end` gate) -- the generic layout path's own
    -- applyPortraitTexture() call (which sets the real unit/class-icon
    -- texture) never runs for the stock-art branch, so the player's
    -- portrait showed as a flat gray circle. Set the real content here.
    -- GetDefaultPortraitFacing itself is a forward-declared local further
    -- down this file (its real `local` statement comes after this
    -- function), so referencing it here would resolve to a nonexistent
    -- global instead -- its logic is this one-liner, inlined directly
    -- instead of restructuring the file's declaration order.
    local applyPortraitTexture = ApplyPreviewPortraitTexture or _G.ApplyPreviewPortraitTexture
    if applyPortraitTexture then
        local facing = (KT.ResolvePortraitFacing and KT.ResolvePortraitFacing(unitKey))
            or settings.portraitFacing or (unitKey == "target" and "flipped" or "normal")
        applyPortraitTexture(frame.portrait, unitKey, facing)
    end

    local function SeatBar(bar, rect)
        bar:ClearAllPoints()
        bar:SetSize(rect.w * scale, rect.h * scale)
        bar:SetPoint("TOPLEFT", frame, "TOPLEFT", rect.x * scale, -rect.y * scale)
        -- The power bar rendered under the stock atlas's own bar-track art
        -- once that art moved to stockArtFrame (19). Elevate the bars above
        -- it here, specifically for the stock-art path only (the
        -- generic/kui path resets this below, so kui's own
        -- circular-portrait-over-bar overlap stays exactly as it was).
        bar:SetFrameLevel(frame:GetFrameLevel() + 20)
    end
    SeatBar(frame.health, geom.health)
    SeatBar(frame.power, geom.power)

    -- Name/value sit above the name tab, outside Health's own rectangle, so
    -- Health's clipping hid them (same reason the real frame reparents its
    -- name text). The level frame is above the art and never clipped.
    if frame.levelFrame then
        frame.name:SetParent(frame.levelFrame)
        frame.value:SetParent(frame.levelFrame)
    end
    frame.name:ClearAllPoints()
    frame.name:SetPoint("TOPLEFT", frame, "TOPLEFT", geom.name.x * scale, geom.name.y * scale)
    frame.value:ClearAllPoints()
    frame.value:SetPoint("TOPRIGHT", frame, "TOPRIGHT",
        -(geom.w - (geom.name.x + geom.name.w)) * scale, geom.name.y * scale)
    frame.value:Show()
    if unitKey == "pet" then
        -- Small frame: value (when enabled) sits on the bar; no level badge.
        frame.value:ClearAllPoints()
        frame.value:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
        frame.value:SetJustifyH("CENTER")
        frame.value:SetShown((settings.rightTextContent or "none") ~= "none")
    elseif themeKey == "classic" then
        -- Classic: the health percentage sits in the middle of the health bar, not beside the name.
        frame.value:ClearAllPoints()
        frame.value:SetPoint("CENTER", frame.health, "CENTER", 0, 0)
        frame.value:SetJustifyH("CENTER")
    end

    -- The stock atlas carries its own decorative ring, so KUI's circle
    -- BORDER outline must go -- but the portrait photo still needs the
    -- circular MASK (the ring is a frame with a transparent hole, not a
    -- crop by itself; the real in-game renderer applies this same mask to
    -- the live 3D portrait via ThemeClientAssets.lua's _shapeMask). Without
    -- it, the preview's placeholder portrait showed as a plain gray square
    -- floating inside the ring instead of a circle matching its hole.
    if not frame._portraitMaskApplied then
        frame.portrait:AddMaskTexture(frame.portraitMask)
        frame._portraitMaskApplied = true
    end
    frame.portraitMask:ClearAllPoints()
    if isClassicPreview then
        -- Same 0.275 expansion the real frame uses (PORTRAIT_MASK_EXPAND_RATIO).
        local expand = portraitSize * 0.275
        frame.portraitMask:SetPoint("TOPLEFT", frame.portraitFrame, "TOPLEFT", -expand, expand)
        frame.portraitMask:SetPoint("BOTTOMRIGHT", frame.portraitFrame, "BOTTOMRIGHT", expand, -expand)
    else
        local expand = 5 * scale
        frame.portraitMask:SetPoint("TOPLEFT", frame.portraitFrame, "TOPLEFT", -expand, expand)
        frame.portraitMask:SetPoint("BOTTOMRIGHT", frame.portraitFrame, "BOTTOMRIGHT", expand, -expand)
    end
    frame.portraitMask:Show()
    frame.portraitBorder:Hide()

    -- Dark filler behind the Classic photo, same idea and same asymmetric
    -- padding as the real frame's _ktClassicPortraitFill.
    if isClassicPreview then
        if not frame.portraitFill then
            frame.portraitFill = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
            frame.portraitFill:SetColorTexture(0.1, 0.1, 0.1, 1)
            frame.portraitFillMask = frame:CreateMaskTexture()
            frame.portraitFillMask:SetTexture(PREVIEW_CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            frame.portraitFill:AddMaskTexture(frame.portraitFillMask)
        end
        local pad = 3 * scale
        local inner = portraitGeom.point == "TOPRIGHT" and "left" or "right"
        local padL = inner == "left" and pad or 0
        local padR = inner == "right" and pad or 0
        frame.portraitFill:ClearAllPoints()
        frame.portraitFill:SetPoint("TOPLEFT", frame.portraitFrame, "TOPLEFT", -padL, 0)
        frame.portraitFill:SetPoint("BOTTOMRIGHT", frame.portraitFrame, "BOTTOMRIGHT", padR, -pad)
        local ex = (portraitSize + padL + padR) * (17 / 94)
        local ey = (portraitSize + pad) * (17 / 94)
        frame.portraitFillMask:ClearAllPoints()
        frame.portraitFillMask:SetPoint("TOPLEFT", frame.portraitFill, "TOPLEFT", -ex, ey)
        frame.portraitFillMask:SetPoint("BOTTOMRIGHT", frame.portraitFill, "BOTTOMRIGHT", ex, -ey)
        frame.portraitFill:Show()
    elseif frame.portraitFill then
        frame.portraitFill:Hide()
    end

    if unitKey == "pet" then
        if frame.levelCircle then frame.levelCircle:Hide() end
        if frame.levelText then frame.levelText:Hide() end
        return true
    end

    -- Same ox/oy pair as KUIUnitFrames.lua's usingClassicLevelOrnament
    -- block: 36/30.5 for Forever/Retail, 60/33 for Classic, anchored to the
    -- frame's own BOTTOMLEFT (mirrored to BOTTOMRIGHT for target, same as
    -- the real frame).
    local ox, oy = 36, 30.5
    if themeKey == "classic" then
        ox, oy = 60, 33
    end
    local levelTextXNudge = 2 * scale
    local levelXNudge = 4 * scale
    local circleSize = 30 * scale
    frame.levelFrame:ClearAllPoints()
    frame.levelFrame:SetAllPoints(frame)
    frame.levelCircle:ClearAllPoints()
    frame.levelCircle:SetSize(circleSize, circleSize)
    -- levelCircleMask must be sized/positioned: with an undefined/zero mask
    -- shape the whole circle is masked fully invisible, leaving bare level
    -- text with no dark circle behind it.
    frame.levelCircleMask:ClearAllPoints()
    frame.levelCircleMask:SetAllPoints(frame.levelCircle)
    frame.levelText:SetFont(PREVIEW_FONT, math.max(7, math.floor(11 * scale)), "OUTLINE")
    frame.levelText:ClearAllPoints()
    frame.levelText:SetSize(18 * scale, 14 * scale)
    if unitKey == "target" then
        frame.levelCircle:SetPoint("CENTER", frame, "BOTTOMRIGHT", -ox * scale + levelXNudge, oy * scale)
        frame.levelText:SetPoint("CENTER", frame, "BOTTOMRIGHT",
            -ox * scale + levelTextXNudge + levelXNudge, oy * scale)
    else
        frame.levelCircle:SetPoint("CENTER", frame, "BOTTOMLEFT", ox * scale - levelXNudge, oy * scale)
        frame.levelText:SetPoint("CENTER", frame, "BOTTOMLEFT",
            ox * scale + levelTextXNudge - levelXNudge, oy * scale)
    end
    frame.levelCircle:Show()
    frame.levelText:Show()
    return true
end

--- Colour/text pass for the stock-art layout. Deliberately separate from the
--- KUI tail of ApplyPreviewUnit so the stock branch never depends on KUI-only
--- layout locals (circularOverlap, portraitSide, ...).
--- @param frame table
--- @param settings table
--- @param globalDB table
--- @param unitKey string
--- @param nameText string|nil
--- @param valueText string|nil
local function ApplyStockPreviewColors(frame, settings, globalDB, unitKey, nameText, valueText)
    frame.health:SetMinMaxValues(0, 100)
    local showAbsorbPreview = unitKey == "player" and settings.showPlayerAbsorb == true
    local healthValue = showAbsorbPreview and (100 - PREVIEW_ABSORB_VALUE) or 100
    frame.health:SetStatusBarTexture(ResolvePreviewBarTexture(settings.healthBarTexture, PREVIEW_FILL))
    frame.health:SetValue(healthValue)

    local fillR, fillG, fillB
    local bgR, bgG, bgB
    if globalDB.darkTheme == true then
        fillR, fillG, fillB = 0x11 / 255, 0x11 / 255, 0x11 / 255
        bgR, bgG, bgB = 0x4f / 255, 0x4f / 255, 0x4f / 255
    elseif settings.healthClassColored ~= false then
        fillR, fillG, fillB = GetPreviewClassColor(unitKey)
        bgR, bgG, bgB = fillR * 0.2, fillG * 0.2, fillB * 0.2
    elseif settings.customFillColor then
        local c = settings.customFillColor
        fillR, fillG, fillB = c.r or 1, c.g or 1, c.b or 1
        if settings.customBgColor then
            local bg = settings.customBgColor
            bgR, bgG, bgB = bg.r or 0.08, bg.g or 0.08, bg.b or 0.08
        else
            bgR, bgG, bgB = fillR * 0.2, fillG * 0.2, fillB * 0.2
        end
    else
        fillR, fillG, fillB = 0.95, 0.53, 0.02
        bgR, bgG, bgB = 0.08, 0.08, 0.08
    end

    frame.health:SetStatusBarColor(fillR, fillG, fillB, 1)
    frame.health.bg:SetTexture(PREVIEW_BG)
    frame.health.bg:SetVertexColor(bgR, bgG, bgB, 1)
    frame.power:SetStatusBarTexture(
        ResolvePreviewBarTexture(settings.powerBarTexture or settings.healthBarTexture, PREVIEW_FILL))
    frame.power.bg:SetTexture(PREVIEW_BG)

    local textSize = settings.textSize or 14
    frame.name:SetFont(PREVIEW_FONT, settings.leftTextSize or textSize, "OUTLINE")
    frame.value:SetFont(PREVIEW_FONT, settings.rightTextSize or textSize, "OUTLINE")
    frame.name:SetText(nameText or "")
    if showAbsorbPreview then
        frame.value:SetText(string.format("%d%%", healthValue))
    else
        frame.value:SetText(valueText or "")
    end
end
local PREVIEW_CLASS_POOL = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK",
    "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}
local previewClassAssignments = {}
local GetDefaultPortraitFacing
local ApplyPreviewPortraitTexture

local function RerollPreviewClassAssignments()
    local pool = {}
    for index, classToken in ipairs(PREVIEW_CLASS_POOL) do
        pool[index] = classToken
    end
    for index = #pool, 2, -1 do
        local swapIndex = math.random(index)
        pool[index], pool[swapIndex] = pool[swapIndex], pool[index]
    end
    for index, unitKey in ipairs(PREVIEW_DYNAMIC_UNITS) do
        previewClassAssignments[unitKey] = pool[index]
    end
end

RerollPreviewClassAssignments()

local function CurrentAccentColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local accent = palette and palette.accent or nil
    return (accent and accent.r) or KT.C_R or 1,
        (accent and accent.g) or KT.C_G or 0,
        (accent and accent.b) or KT.C_B or 0.3333333333
end

local ACCENT = setmetatable({}, {
    __index = function(_, key)
        local r, g, b = CurrentAccentColor()
        if key == "r" then return r end
        if key == "g" then return g end
        if key == "b" then return b end
        return nil
    end,
})

local PAGE_BUTTON_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Button.png"
local TAB_H = 36
local TAB_GAP = 2
local _tabBarFrame
local ufActiveTab = "general"

local function GetSCSafeWidth(sc)
    return sc:GetWidth() or 300
end

local function FindButtonLabel(button)
    if not button then return nil end
    for _, region in ipairs({ button:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            return region
        end
    end
end

local MENU_BTN_TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\MenuButton.png"
local MENU_BTN_minX  = 12 / 601
local MENU_BTN_maxX  = 586 / 601
local MENU_BTN_minY  = 8 / 147
local MENU_BTN_maxY  = 136 / 147
local MENU_BTN_cx    = 8 / 601
local MENU_BTN_cy    = 8 / 147
local MENU_BTN_cs    = 4  -- cornerScreen pixels

local function Apply9SliceTabButton(button, isActive)
    if not button then return end
    local ar, ag, ab = CurrentAccentColor()

    if not button._kui9slices then
        -- Build 9-slice the first time
        local visual = CreateFrame("Frame", nil, button)
        visual:SetAllPoints()
        visual:SetFrameLevel(math.max(1, button:GetFrameLevel() - 1))
        visual:SetClipsChildren(false)
        button._kui9visual = visual

        local slices = {}
        for i = 1, 9 do
            local t = visual:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(MENU_BTN_TEX)
            slices[i] = t
        end
        local TL,TR,BL,BR,T,B,L,R,C = unpack(slices)

        TL:SetSize(MENU_BTN_cs, MENU_BTN_cs); TR:SetSize(MENU_BTN_cs, MENU_BTN_cs)
        BL:SetSize(MENU_BTN_cs, MENU_BTN_cs); BR:SetSize(MENU_BTN_cs, MENU_BTN_cs)
        TL:SetPoint("TOPLEFT"); TR:SetPoint("TOPRIGHT")
        BL:SetPoint("BOTTOMLEFT"); BR:SetPoint("BOTTOMRIGHT")
        T:SetPoint("TOPLEFT",TL,"TOPRIGHT");  T:SetPoint("BOTTOMRIGHT",TR,"BOTTOMLEFT")
        B:SetPoint("TOPLEFT",BL,"TOPRIGHT");  B:SetPoint("BOTTOMRIGHT",BR,"BOTTOMLEFT")
        L:SetPoint("TOPLEFT",TL,"BOTTOMLEFT"); L:SetPoint("BOTTOMRIGHT",BL,"TOPRIGHT")
        R:SetPoint("TOPLEFT",TR,"BOTTOMLEFT"); R:SetPoint("BOTTOMRIGHT",BR,"TOPRIGHT")
        C:SetPoint("TOPLEFT",TL,"BOTTOMRIGHT"); C:SetPoint("BOTTOMRIGHT",BR,"TOPLEFT")

        TL:SetTexCoord(MENU_BTN_minX, MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_minY, MENU_BTN_minY+MENU_BTN_cy)
        TR:SetTexCoord(MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_maxX, MENU_BTN_minY, MENU_BTN_minY+MENU_BTN_cy)
        BL:SetTexCoord(MENU_BTN_minX, MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_maxY-MENU_BTN_cy, MENU_BTN_maxY)
        BR:SetTexCoord(MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_maxX, MENU_BTN_maxY-MENU_BTN_cy, MENU_BTN_maxY)
        T:SetTexCoord(MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_minY, MENU_BTN_minY+MENU_BTN_cy)
        B:SetTexCoord(MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_maxY-MENU_BTN_cy, MENU_BTN_maxY)
        L:SetTexCoord(MENU_BTN_minX, MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_minY+MENU_BTN_cy, MENU_BTN_maxY-MENU_BTN_cy)
        R:SetTexCoord(MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_maxX, MENU_BTN_minY+MENU_BTN_cy, MENU_BTN_maxY-MENU_BTN_cy)
        C:SetTexCoord(MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_minY+MENU_BTN_cy, MENU_BTN_maxY-MENU_BTN_cy)

        button._kui9slices = slices

        button:HookScript("OnEnter", function(self)
            local r,g,b = CurrentAccentColor()
            for _, t in ipairs(self._kui9slices) do t:SetVertexColor(r,g,b,1) end
            local lbl = self._kuiPageLabel or FindButtonLabel(self)
            if lbl then lbl:SetTextColor(1,1,1,1) end
        end)
        button:HookScript("OnLeave", function(self)
            local r,g,b = CurrentAccentColor()
            local alpha = self._kuiIsActive and 1 or 0.4
            for _, t in ipairs(self._kui9slices) do t:SetVertexColor(r,g,b,alpha) end
            local lbl = self._kuiPageLabel or FindButtonLabel(self)
            if lbl then lbl:SetTextColor(alpha == 1 and 1 or 0.7, alpha == 1 and 1 or 0.7, alpha == 1 and 1 or 0.7, 1) end
        end)
    end

    button._kuiIsActive = isActive
    local alpha = isActive and 1 or 0.4
    for _, t in ipairs(button._kui9slices) do
        t:SetVertexColor(ar, ag, ab, alpha)
    end
    local lbl = button._kuiPageLabel or FindButtonLabel(button)
    if lbl then
        lbl:SetTextColor(isActive and 1 or 0.7, isActive and 1 or 0.7, isActive and 1 or 0.7, 1)
    end
end

-- Compatibility shims so existing call sites still work
local function ApplyModernButtonVisual(button, mode, hovered)
    Apply9SliceTabButton(button, mode == "active")
end

local function StyleModernPageButton(button, mode, fontSize)
    if not button then return end
    button._kuiPageLabel = button._kuiPageLabel or FindButtonLabel(button)
    if button._kuiPageLabel and fontSize then
        button._kuiPageLabel:SetFont(PREVIEW_DEFAULT_FONT, fontSize, "OUTLINE")
    end
    button._kuiPageMode = mode or "inactive"
    Apply9SliceTabButton(button, mode == "active")
end

local function BuildTabBar(sc, yOff)
    local tabs = {
        { id = "general",     label = LText("General") },
        { id = "player",      label = LText("Player & Pet") },
        { id = "target",      label = LText("Targeting") },
        { id = "boss",        label = LText("Boss") },
    }
    local containerH = TAB_H + 6
    local container
    if _tabBarFrame and _tabBarFrame:GetParent() == sc then
        container = _tabBarFrame
        for _, child in ipairs({ container:GetChildren() }) do child:Hide() end
    else
        if _tabBarFrame then _tabBarFrame:Hide() end
        container = CreateFrame("Frame", nil, sc)
        _tabBarFrame = container
    end
    container:SetHeight(containerH)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, yOff)
    container:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -20, yOff)
    container:Show()

    local scW = GetSCSafeWidth(sc) - 30
    local totalWidth = math.max(1, scW)
    local usableWidth = totalWidth - ((#tabs - 1) * TAB_GAP)
    local tabWidth = math.floor(usableWidth / #tabs)
    local usedWidth = (tabWidth * #tabs) + ((#tabs - 1) * TAB_GAP)
    local remainder = totalWidth - usedWidth

    local previousButton
    for i, tab in ipairs(tabs) do
        local isActive = (tab.id == ufActiveTab)
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetHeight(TAB_H)
        btn:SetWidth(tabWidth + ((i == #tabs) and remainder or 0))
        if i == 1 then
            btn:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", previousButton, "RIGHT", TAB_GAP, 0)
        end

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(PREVIEW_DEFAULT_FONT, 11, "OUTLINE")
        lbl:SetText(tab.label); lbl:SetAllPoints(); lbl:SetJustifyH("CENTER")
        btn._kuiPageLabel = lbl
        StyleModernPageButton(btn, isActive and "active" or "inactive", 11)

        local tid = tab.id
        btn:SetScript("OnClick", function()
            ufActiveTab = tid; if KT.RefreshPage then KT:RefreshPage(true) end
        end)
        btn:Show()
        previousButton = btn
    end
    return container, containerH + 8
end


local function RefreshFrames()
    local Mod = GetModule()
    if Mod and Mod.Reload then
        Mod:Reload()
    elseif ns.ReloadFrames then
        ns.ReloadFrames()
    end
    if previewRefresh then
        previewRefresh()
    end
end

local function SetAndRefresh(setter)
    setter()
    RefreshFrames()
end

local function ApplyHealthDisplayToText(settings)
    if not settings then return end
    local hd = settings.healthDisplay or "both"
    local namePos = settings.namePosition or "left"
    local hpPos = settings.healthTextPosition or "right"

    if namePos == "left" then
        settings.leftTextContent = "name"
        settings.rightTextContent = (hpPos == "right") and hd or "none"
    elseif namePos == "right" then
        settings.rightTextContent = "name"
        settings.leftTextContent = (hpPos == "left") and hd or "none"
    else
        settings.leftTextContent = (hpPos == "left") and hd or "none"
        settings.rightTextContent = (hpPos == "right") and hd or "none"
    end
end

local function CreatePreviewUnit(parent)
    local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    frame:RegisterForClicks("AnyUp")
    frame:EnableMouse(true)
    KT:AddBorder(frame, 0, 0, 0, 1)

    -- The portrait goes underneath the ring art, matching
    -- ThemeClientAssets.lua's own documented stacking order (SyncArtLayers:
    -- "portrait -> frame art -> bars -> text"). Full level order below,
    -- lowest to highest: portraitFrame (18) < stockArtFrame (19, created
    -- further down) < health/power (20, explicitly elevated below) <
    -- levelFrame (21, unchanged).
    frame.portraitFrame = CreateFrame("Frame", nil, frame)
    frame.portraitFrame:SetFrameLevel(frame:GetFrameLevel() + 18)
    frame.portrait = frame.portraitFrame:CreateTexture(nil, "ARTWORK")
    frame.portrait:SetAllPoints(frame.portraitFrame)
    frame.portrait:SetColorTexture(0.35, 0.35, 0.35, 1)
    frame.portraitMask = frame.portraitFrame:CreateMaskTexture()
    frame.portraitMask:SetTexture(PREVIEW_CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    frame.portraitMask:Hide()
    frame.portraitBorder = frame.portraitFrame:CreateTexture(nil, "OVERLAY")
    frame.portraitBorder:SetTexture(PREVIEW_CIRCLE_BORDER)
    frame.portraitBorder:Hide()

    -- Level ornament for the stock-art themes in this preview. Same
    -- technique as KUIUnitFrames.lua's own usingClassicLevelOrnament block:
    -- a plain dark circle (not atlas art) with the gold level number on
    -- top, on its own higher-level frame so it reliably draws above the
    -- stock art regardless of either side's own layer/sublevel.
    frame.levelFrame = CreateFrame("Frame", nil, frame)
    frame.levelFrame:SetFrameLevel(frame:GetFrameLevel() + 21)
    frame.levelCircle = frame.levelFrame:CreateTexture(nil, "OVERLAY")
    frame.levelCircle:SetTexture("Interface\\Buttons\\WHITE8X8")
    frame.levelCircle:SetVertexColor(0.06, 0.06, 0.06, 1)
    frame.levelCircleMask = frame.levelFrame:CreateMaskTexture()
    frame.levelCircleMask:SetTexture(PREVIEW_CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    frame.levelCircle:AddMaskTexture(frame.levelCircleMask)
    frame.levelCircle:Hide()
    -- SetText() before any SetFont() call ever ran on this FontString
    -- throws "Font not set" -- ApplyStockLayoutToPreview's own SetFont call
    -- happens later (only when a stock theme is actually active), too late
    -- for this creation-time SetText. Give it a safe font right here first.
    frame.levelText = frame.levelFrame:CreateFontString(nil, "OVERLAY")
    frame.levelText:SetFont(PREVIEW_FONT, 11, "OUTLINE")
    frame.levelText:SetTextColor(1, 0.82, 0.20, 1)
    frame.levelText:SetJustifyH("CENTER")
    frame.levelText:SetText("60")
    frame.levelText:Hide()

    -- Real stock artwork (retail/forever/classic). Hidden for kui, which draws
    -- its own border + circle instead. On its own frame, above portraitFrame
    -- (18) but below the bars (20) -- see the stacking-order note above.
    frame.stockArtFrame = CreateFrame("Frame", nil, frame)
    frame.stockArtFrame:SetFrameLevel(frame:GetFrameLevel() + 19)
    frame.stockArt = frame.stockArtFrame:CreateTexture(nil, "ARTWORK")
    frame.stockArt:SetAllPoints(frame)
    frame.stockArt:Hide()

    -- health/power's FrameLevel is left at its default here (unelevated,
    -- matching this preview's original kui-style behavior, where the
    -- circular portrait is meant to overlap the bar's own edge) -- only
    -- ApplyStockLayoutToPreview elevates them above stockArtFrame (19),
    -- and only while a stock theme is actually active, specifically so
    -- this doesn't change anything about kui's own portrait/bar overlap.
    frame.health = CreateFrame("StatusBar", nil, frame)
    frame.health:SetStatusBarTexture(PREVIEW_FILL)
    frame.health.bg = frame.health:CreateTexture(nil, "BACKGROUND")
    frame.health.bg:SetTexture(PREVIEW_BG)
    frame.health.bg:SetAllPoints()
    frame.health.bg:SetVertexColor(0.1, 0.1, 0.1, 1)
    frame.health:SetClipsChildren(true)

    frame.absorb = CreateFrame("StatusBar", nil, frame.health)
    frame.absorb:SetMinMaxValues(0, 100)
    frame.absorb:SetReverseFill(true)
    frame.absorb:SetFrameLevel(frame.health:GetFrameLevel() + 1)
    frame.absorb:Hide()

    frame.power = CreateFrame("StatusBar", nil, frame)
    frame.power:SetStatusBarTexture(PREVIEW_FILL)
    frame.power.bg = frame.power:CreateTexture(nil, "BACKGROUND")
    frame.power.bg:SetTexture(PREVIEW_BG)
    frame.power.bg:SetAllPoints()
    frame.power.bg:SetVertexColor(0.08, 0.08, 0.08, 1)
    frame.power:SetStatusBarColor(0.22, 0.45, 0.95, 1)

    frame.name = frame.health:CreateFontString(nil, "OVERLAY")
    frame.name:SetFont(PREVIEW_DEFAULT_FONT, 14, "OUTLINE")
    frame.name:SetTextColor(1, 1, 1, 1)
    frame.name:SetPoint("LEFT", 6, 0)
    frame.name:SetJustifyH("LEFT")

    frame.value = frame.health:CreateFontString(nil, "OVERLAY")
    frame.value:SetFont(PREVIEW_DEFAULT_FONT, 14, "OUTLINE")
    frame.value:SetTextColor(1, 1, 1, 1)
    frame.value:SetPoint("RIGHT", -6, 0)
    frame.value:SetJustifyH("RIGHT")

    frame.levelText = frame:CreateFontString(nil, "OVERLAY")
    frame.levelText:SetJustifyH("LEFT")
    frame.levelText:SetWordWrap(false)
    frame.levelText:SetWidth(38)
    frame.levelText:SetHeight(14)
    frame.levelText:Hide()
    frame.pvpIcon = frame:CreateTexture(nil, "OVERLAY")
    frame.pvpIcon:SetSize(16, 16)
    frame.pvpIcon:Hide()

    frame.hover = frame:CreateTexture(nil, "HIGHLIGHT")
    frame.hover:SetAllPoints()
    KT:SetAccentTexture(frame.hover, 0.12)

    return frame
end

local function ScrollToOptionBlock(block)
    local menu = KT and KT.MenuPrincipal
    local sf = menu and menu.scrollFrame
    local sb = sf and sf.ScrollBar
    local sc = menu and menu.scrollChild
    if not (block and sf and sb and sc) then return end

    local function ApplyScroll()
        local scTop = sc:GetTop()
        local blockTop = block:GetTop()
        if not (scTop and blockTop) then return end

        local minVal, maxVal = sb:GetMinMaxValues()
        local target = math.floor((scTop - blockTop) + 8 + 0.5)
        if minVal and target < minVal then
            target = minVal
        end
        if maxVal and target > maxVal then
            target = maxVal
        end

        if KT.SmoothScrollTo then
            KT.SmoothScrollTo(target)
        else
            sb:SetValue(target)
        end
    end

    ApplyScroll()
    C_Timer.After(0.05, ApplyScroll)

    if not block._previewHighlight then
        local hl = block:CreateTexture(nil, "OVERLAY")
        hl:SetAllPoints()
        local r, g, b = CurrentAccentColor()
        hl:SetColorTexture(r, g, b, 0.4)
        hl:SetBlendMode("ADD")
        hl:Hide()
        block._previewHighlight = hl
        
        local ag = hl:CreateAnimationGroup()
        local a1 = ag:CreateAnimation("Alpha")
        a1:SetFromAlpha(0)
        a1:SetToAlpha(1)
        a1:SetDuration(0.15)
        a1:SetOrder(1)
        local a2 = ag:CreateAnimation("Alpha")
        a2:SetFromAlpha(1)
        a2:SetToAlpha(0)
        a2:SetDuration(0.6)
        a2:SetOrder(2)
        ag:SetScript("OnFinished", function() hl:Hide() end)
        ag:SetScript("OnPlay", function() hl:Show() end)
        block._previewHighlightAnim = ag
    end
    
    if block._previewHighlightAnim then
        block._previewHighlightAnim:Stop()
        block._previewHighlightAnim:Play()
    end
end

local function BindPreviewClick(frame, label, targetTab, getTargetBlock)
    if not frame then return end

    frame:SetScript("OnClick", function()
        local needsDelay = false
        if targetTab and ufActiveTab ~= targetTab then
            ufActiveTab = targetTab
            needsDelay = true
            if KT.RefreshPage then KT:RefreshPage(true) end
        end
        C_Timer.After(needsDelay and 0.15 or 0.05, function()
            local target = getTargetBlock and getTargetBlock()
            if target then
                ScrollToOptionBlock(target)
            end
        end)
    end)

    frame:SetScript("OnEnter", function(self)
        KT:AddAccentBorder(self, 1)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label or LText("Unit Frame Preview"), 1, 1, 1)
            GameTooltip:AddLine(LText("Click to jump to its settings block."), 0.75, 0.82, 0.9, true)
            GameTooltip:Show()
        end
    end)

    frame:SetScript("OnLeave", function(self)
        KT:AddBorder(self, 0, 0, 0, 1)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

function GetPreviewClassColor(unitKey)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {}

    local function colorFor(classToken)
        local c = classToken and colors[classToken]
        if c then
            return c.r, c.g, c.b
        end
        return nil
    end

    if unitKey == "player" then
        local _, classToken = UnitClass("player")
        local r, g, b = colorFor(classToken)
        if r then
            return r, g, b
        end
    end

    local assignedClass = previewClassAssignments[unitKey]
    if assignedClass then
        local r, g, b = colorFor(assignedClass)
        if r then
            return r, g, b
        end
    end

    local previewClasses = {
        target = "MAGE",
        focus = "PRIEST",
        pet = "HUNTER",
        totPet = "ROGUE",
        focustarget = "DRUID",
        boss = "WARRIOR",
    }

    local r, g, b = colorFor(previewClasses[unitKey])
    if r then
        return r, g, b
    end

    return 0.95, 0.53, 0.02
end

function ResolvePreviewBarTexture(textureKey, fallbackPath)
    local textures = ns.healthBarTextures or {}
    if textureKey and textures[textureKey] then
        return textures[textureKey]
    end
    if textureKey and LSM then
        local sharedPath = LSM:Fetch("statusbar", textureKey, true)
        if sharedPath then return sharedPath end
    end
    return fallbackPath or PREVIEW_FILL
end

local function ResolvePreviewFont(fontName)
    if KT and KT.ResolveFontPath then
        local resolved = KT:ResolveFontPath(fontName, PREVIEW_DEFAULT_FONT)
        if resolved and resolved ~= "" then
            return resolved
        end
    end

    if LSM and fontName then
        local resolved = LSM:Fetch("font", fontName, true)
        if resolved and resolved ~= "" then
            return resolved
        end
    end

    return PREVIEW_DEFAULT_FONT
end

local function ApplyPreviewUnitBase(frame, unitKey, settings, globalDB, nameText, valueText)
    -- A stock-art theme (retail/forever/classic) renders Blizzard's own frames,
    -- not KUI's. Seat the real artwork instead of the Melli layout, otherwise
    -- the preview would lie about what the chosen theme actually looks like.
    if ActiveThemeOwnsFrameArt() and ApplyStockLayoutToPreview(frame, unitKey, settings) then
        ApplyStockPreviewColors(frame, settings, globalDB, unitKey, nameText, valueText)
        return
    end
    frame.stockArt:Hide()
    if frame.name and frame.name:GetParent() ~= frame.health then frame.name:SetParent(frame.health) end
    if frame.value and frame.value:GetParent() ~= frame.health then frame.value:SetParent(frame.health) end
    -- Undo the Classic-only portrait treatment from the stock path.
    if frame.portraitFill then frame.portraitFill:Hide() end
    frame.portraitFrame:SetClipsChildren(false)
    frame.portrait:ClearAllPoints()
    frame.portrait:SetAllPoints(frame.portraitFrame)
    -- The level badge only exists for the real-stock-art path above; hide
    -- it here so it doesn't persist from an earlier run (e.g. switching
    -- away from a stock theme, or a unit like pet/focus with no stock
    -- geometry at all).
    if frame.levelCircle then frame.levelCircle:Hide() end
    if frame.levelText then frame.levelText:Hide() end
    -- Undo the stock-art path's bar elevation too, so kui's own circular-
    -- portrait-over-bar overlap (which relies on the bars being at their
    -- normal, unelevated level) isn't affected by a previous stock-theme run.
    frame.health:SetFrameLevel(frame:GetFrameLevel())
    frame.power:SetFrameLevel(frame:GetFrameLevel())

    local showPortrait = globalDB.portraitStyle ~= "none" and settings.showPortrait ~= false
    local powerHeight = ((settings.powerPosition or "below") ~= "none") and (settings.powerHeight or 6) or 0
    local totalBarHeight = (settings.healthHeight or 20) + powerHeight
    local isCircular = globalDB.portraitStyle == "circular"
    local portraitWidth = showPortrait and (totalBarHeight + (isCircular and 10 or 0)) or 0
    local circularOverlap = portraitWidth * 0.5
    local totalWidth = (settings.frameWidth or 100)
        + (isCircular and math.max(0, portraitWidth - circularOverlap) or portraitWidth)
    local totalHeight = isCircular and math.max(totalBarHeight, portraitWidth) or totalBarHeight
    local portraitSide = settings.portraitSide or "left"

    frame:SetSize(totalWidth, totalHeight)
    frame.health:ClearAllPoints()
    frame.health:SetSize(settings.frameWidth or 100, settings.healthHeight or 20)
    frame.power:ClearAllPoints()
    frame.power:SetSize(settings.frameWidth or 100, powerHeight)
    frame.portraitFrame:ClearAllPoints()
    local applyPortraitTexture = ApplyPreviewPortraitTexture or _G.ApplyPreviewPortraitTexture
    if applyPortraitTexture then
        applyPortraitTexture(frame.portrait, unitKey,
            (KT.ResolvePortraitFacing and KT.ResolvePortraitFacing(unitKey))
            or settings.portraitFacing or GetDefaultPortraitFacing(unitKey))
    end

    if showPortrait then
        frame.portraitFrame:Show()
        frame.portraitFrame:SetSize(portraitWidth, portraitWidth)
        if isCircular then
            local verticalOffset = (totalHeight - totalBarHeight) * 0.5
            if portraitSide == "right" then
                frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -verticalOffset)
                frame.portraitFrame:SetPoint("LEFT", frame.health, "RIGHT", -circularOverlap, 0)
            else
                frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", portraitWidth - circularOverlap, -verticalOffset)
                frame.portraitFrame:SetPoint("RIGHT", frame.health, "LEFT", circularOverlap, 0)
            end

            if not frame._portraitMaskApplied then
                frame.portrait:AddMaskTexture(frame.portraitMask)
                frame._portraitMaskApplied = true
            end
            frame.portraitMask:ClearAllPoints()
            frame.portraitMask:SetAllPoints(frame.portrait)
            frame.portraitMask:Show()
            frame.portraitBorder:ClearAllPoints()
            frame.portraitBorder:SetPoint("TOPLEFT", frame.portrait, "TOPLEFT", -1, 1)
            frame.portraitBorder:SetPoint("BOTTOMRIGHT", frame.portrait, "BOTTOMRIGHT", 1, -1)
            frame.portraitBorder:Show()
        elseif portraitSide == "right" then
            frame.portraitFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        else
            frame.portraitFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", portraitWidth, 0)
        end
    else
        frame.portraitFrame:Hide()
        frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    end

    if not isCircular then
        if frame._portraitMaskApplied then
            frame.portrait:RemoveMaskTexture(frame.portraitMask)
            frame._portraitMaskApplied = false
        end
        frame.portraitMask:Hide()
        frame.portraitBorder:Hide()
    end

    if powerHeight > 0 then
        frame.power:Show()
        frame.power:SetPoint("TOPLEFT", frame.health, "BOTTOMLEFT", 0, 0)
    else
        frame.power:Hide()
    end

    frame.health:SetMinMaxValues(0, 100)
    local previewHealthValue = 100
    local showAbsorbPreview = unitKey == "player" and settings.showPlayerAbsorb == true
    if showAbsorbPreview then
        previewHealthValue = 100 - PREVIEW_ABSORB_VALUE
    end
    frame.health:SetStatusBarTexture(ResolvePreviewBarTexture(settings.healthBarTexture, PREVIEW_FILL))
    frame.health:SetValue(previewHealthValue)

    local fillR, fillG, fillB
    local bgR, bgG, bgB
    if globalDB.darkTheme == true then
        fillR, fillG, fillB = 0x11 / 255, 0x11 / 255, 0x11 / 255
        bgR, bgG, bgB = 0x4f / 255, 0x4f / 255, 0x4f / 255
    elseif settings.healthClassColored ~= false then
        fillR, fillG, fillB = GetPreviewClassColor(unitKey)
        bgR, bgG, bgB = fillR * 0.2, fillG * 0.2, fillB * 0.2
    elseif settings.customFillColor then
        local c = settings.customFillColor
        fillR, fillG, fillB = c.r or 1, c.g or 1, c.b or 1
        if settings.customBgColor then
            local bg = settings.customBgColor
            bgR, bgG, bgB = bg.r or 0.08, bg.g or 0.08, bg.b or 0.08
        else
            bgR, bgG, bgB = fillR * 0.2, fillG * 0.2, fillB * 0.2
        end
    else
        fillR, fillG, fillB = 0.95, 0.53, 0.02
        bgR, bgG, bgB = 0.08, 0.08, 0.08
    end

    frame.health:SetStatusBarColor(fillR, fillG, fillB, 1)
    if isCircular then
        local borderColor = globalDB.circularPortraitBorderColor
        if globalDB.circularPortraitBorderUseCustomColor == true and type(borderColor) == "table" then
            frame.portraitBorder:SetVertexColor(borderColor.r or 1, borderColor.g or 1, borderColor.b or 1, borderColor.a or 1)
        else
            frame.portraitBorder:SetVertexColor(fillR, fillG, fillB, 1)
        end
    end
    frame.health.bg:SetTexture(PREVIEW_BG)
    frame.health.bg:SetVertexColor(bgR, bgG, bgB, 1)
    frame.power:SetStatusBarTexture(ResolvePreviewBarTexture(settings.powerBarTexture or settings.healthBarTexture, PREVIEW_FILL))
    frame.power.bg:SetTexture(PREVIEW_BG)
    frame.name:ClearAllPoints()
    frame.value:ClearAllPoints()
    local nameInset = (isCircular and portraitSide ~= "right") and (circularOverlap + 5) or 6
    local valueInset = (isCircular and portraitSide == "right") and (circularOverlap + 5) or 6
    frame.name:SetPoint("LEFT", frame.health, "LEFT", nameInset, 0)
    frame.value:SetPoint("RIGHT", frame.health, "RIGHT", -valueInset, 0)
    local metadataAnchor = showPortrait and frame.portraitFrame or frame.health
    frame.levelText:ClearAllPoints()
    if unitKey == "target" then
        frame.levelText:SetPoint("BOTTOMRIGHT", metadataAnchor, "TOPRIGHT", -(tonumber(globalDB.levelX) or 2), tonumber(globalDB.levelY) or 2)
    else
        frame.levelText:SetPoint("BOTTOMLEFT", metadataAnchor, "TOPLEFT", tonumber(globalDB.levelX) or 2, tonumber(globalDB.levelY) or 2)
    end
    local levelOutline = globalDB.levelFontOutline
    if levelOutline == "NONE" then levelOutline = "" end
    frame.levelText:SetFont(ResolvePreviewFont(globalDB.levelFont), tonumber(globalDB.levelFontSize) or 11, levelOutline or "OUTLINE")
    local levelColor = globalDB.levelColor or { r = 1, g = 0.82, b = 0.20, a = 1 }
    frame.levelText:SetTextColor(levelColor.r or 1, levelColor.g or 1, levelColor.b or 1, levelColor.a or 1)
    frame.levelText:SetText(unitKey == "player" and "80" or "70")
    frame.levelText:SetShown(globalDB.showCharacterLevel ~= false)
    frame.pvpIcon:ClearAllPoints()
    if unitKey == "target" then
        frame.pvpIcon:SetPoint("LEFT", metadataAnchor, "RIGHT", 2, 1)
        frame.pvpIcon:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\Horde.png")
    else
        frame.pvpIcon:SetPoint("RIGHT", metadataAnchor, "LEFT", -2, 1)
        frame.pvpIcon:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\Alliance.png")
    end
    frame.pvpIcon:SetShown(globalDB.showPvPIcon == true and (unitKey == "player" or unitKey == "target"))
    frame.name:SetFont(PREVIEW_DEFAULT_FONT, settings.leftTextSize or settings.textSize or 14, "OUTLINE")
    frame.value:SetFont(PREVIEW_DEFAULT_FONT, settings.rightTextSize or settings.textSize or 14, "OUTLINE")
    frame.name:SetText(nameText)
    if showAbsorbPreview then
        frame.value:SetText(string.format("%d%%", previewHealthValue))
    else
        frame.value:SetText(valueText)
    end

    frame.absorb:ClearAllPoints()
    frame.absorb:SetPoint("TOPRIGHT", frame.health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    frame.absorb:SetPoint("BOTTOMRIGHT", frame.health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    frame.absorb:SetWidth(settings.frameWidth or 100)
    frame.absorb:SetStatusBarTexture(ResolvePreviewBarTexture(settings.absorbBarTexture, PREVIEW_FILL))
    if showAbsorbPreview then
        local c = settings.absorbBarColor or { r = 0.11, g = 1.00, b = 0.62, a = 1.00 }
        frame.absorb:SetStatusBarColor(c.r or 0.11, c.g or 1.00, c.b or 0.62, c.a or 1.00)
        frame.absorb:SetValue(PREVIEW_ABSORB_VALUE)
        frame.absorb:Show()
    else
        frame.absorb:Hide()
    end
end

-- Rare/Elite ring in the live preview (Player only, every style). Lives on ns so
-- this chunk does not take another file-level local.
local RING_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\UnitFramesIcons\\"
ns.RING_ICON_PATH = RING_ICON_PATH

function ns.ApplyPreviewUnit(frame, unitKey, settings, globalDB, nameText, valueText)
    ApplyPreviewUnitBase(frame, unitKey, settings, globalDB, nameText, valueText)

    local ring = frame.classificationRing
    -- The option lives at the profile root (not in db.player): read globalDB.
    local choice = (unitKey == "player" and globalDB and globalDB.playerClassificationBorder) or "none"
    local portraitShown = frame.portraitFrame
        and (frame.portraitFrame:IsShown() or (frame.portrait and frame.portrait:IsShown()))
    if (choice ~= "rare" and choice ~= "elite" and choice ~= "classicrare" and choice ~= "classicelite")
        or not portraitShown then
        if ring then ring:Hide() end
        return
    end
    if not ring then
        ring = (frame.levelFrame or frame):CreateTexture(nil, "OVERLAY", nil, 7)
        frame.classificationRing = ring
    end
    local theme = ActiveVisualTheme and ActiveVisualTheme() or nil
    -- Classic's own Rare/Elite sheet: crop of the portrait side (same numbers as the live frame).
    local CR = ns.ClassicRing
    local classicKind = (choice == "classicrare" and "rare") or (choice == "classicelite" and "elite") or nil
    if CR and classicKind then
        ring:SetTexture(CR.sheets[classicKind])
        local sc = (frame.portraitFrame:GetWidth() or 40) * CR.scale / 64
        ring:SetTexCoord(CR.uLeft, CR.uRight, CR.vTop, CR.vBottom)
        ring:ClearAllPoints()
        ring:SetSize(CR.cropW * sc, CR.cropH * sc)
        ring:SetPoint("TOPLEFT", frame.portraitFrame, "CENTER", -CR.portraitCX * sc, CR.portraitCY * sc)
        -- Below the level text (OVERLAY) so the number stays readable over the sheet.
        if ring.SetDrawLayer then ring:SetDrawLayer("ARTWORK", 7) end
        ring:Show()
        -- Seat the level in the sheet's own empty level circle (same offsets as the live frame).
        if frame.levelText then
            frame.levelText:ClearAllPoints()
            frame.levelText:SetSize(40, 16)
            frame.levelText:SetPoint("CENTER", frame.portraitFrame, "CENTER", CR.levelDX * sc + 1, CR.levelDY * sc)
            frame.levelText:SetJustifyH("CENTER")
            frame.levelText:Show()
        end
        if frame.levelCircle then frame.levelCircle:Hide() end
        if (theme == "forever" or theme == "retail") and frame.stockArt then frame.stockArt:Hide() end
        return
    end
    if ring.SetDrawLayer then ring:SetDrawLayer("OVERLAY", 7) end
    local scale = 1.18
    if theme == "classic" then scale = 1.18 * 1.12
    elseif theme == "forever" or theme == "retail" then scale = 1.18 * 1.10 * 1.10
    else scale = 1.18 * 0.95 end
    local size = math.max(24, (frame.portraitFrame:GetWidth() or 40) * scale)
    ring:SetTexture(RING_ICON_PATH .. (choice == "rare" and "RARE.png" or "ELITE.png"))
    -- Same rule as the live frame: the ring points the way the portrait looks.
    local facing = KT.ResolvePortraitFacing and KT.ResolvePortraitFacing("player") or "normal"
    -- Same rule as the live frame: shapeshift (2D form art) is baked the other way,
    -- and the preview shows the live portrait (e.g. a druid's eagle form).
    local shapeshifted = false
    if type(GetShapeshiftForm) == "function" then
        local okSS, formSS = pcall(GetShapeshiftForm)
        shapeshifted = okSS and type(formSS) == "number" and formSS > 0
    end
    local looksRight = (facing == "normal") ~= shapeshifted
    ring:SetTexCoord(looksRight and 1 or 0, looksRight and 0 or 1, 0, 1)
    ring:ClearAllPoints()
    ring:SetSize(size, size)
    -- The art's opening is not centred in the PNG (measured ~0.44, 0.52): re-centre it.
    ring:SetPoint("CENTER", frame.portraitFrame, "CENTER", (looksRight and -0.06 or 0.06) * size, 0.02 * size)
    ring:Show()
    -- Forever/Retail hide their bronze/gold base art while the ring is shown.
    if (theme == "forever" or theme == "retail") and frame.stockArt then
        frame.stockArt:Hide()
    end
end

-- Combo points under the frame (Player preview), drawn after the
-- Rare/Elite ring logic so its early returns do not skip it.
do
    local rawApplyPreviewUnit = ns.ApplyPreviewUnit
    ns.ApplyPreviewUnit = function(frame, unitKey, ...)
        rawApplyPreviewUnit(frame, unitKey, ...)
        if ns.ComboUnderFrame then ns.ComboUnderFrame.ApplyPreview(frame, unitKey) end
    end
end

-- Combo point style picker (tiles) for Player / Target.  Player: Off, Modern,
-- Classic.  Target: Off, Ring (circle around the portrait), Modern, Classic.
-- PvP icon style picker (graphic tiles): Modern = ours, Classic = stock banner.
-- Independent for Player (pvpIconStyle) and Target (pvpIconStyleTarget).
function ns.BuildPvPPicker(container, W, by, unitKey)
    local db = GetDB()
    local isTarget = unitKey == 'target'
    local dbKey = isTarget and 'pvpIconStyleTarget' or 'pvpIconStyle'
        local _, lh = W:Label(container, isTarget and 'PvP Icon Style (Target)' or 'PvP Icon Style (Player)', -by, 12)
        by = by + lh
        local holder = CreateFrame("Frame", nil, container)
        holder:SetPoint("TOPLEFT", 10, -by)
        holder:SetSize(200, 96)
        local buttons = {}
        local faction = (UnitFactionGroup and UnitFactionGroup("player")) or "Horde"
        if faction ~= "Alliance" then faction = "Horde" end
        local function Current()
            if db[dbKey] == 'modern' or db[dbKey] == 'classic' then return db[dbKey] end
            -- Same render-time default as KUIUnitFrames.lua: Classic theme -> classic.
            local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
                and KT.VisualThemes:GetRenderedTheme()
            return renderedTheme == 'classic' and 'classic' or 'modern'
        end
        local function PaintButtons()
            local current = Current()
            local ar, ag, ab = CurrentAccentColor()
            for key, btn in pairs(buttons) do
                local on = current == key
                btn:SetBackdropColor(on and ar * 0.25 or 0.06, on and ag * 0.25 or 0.06, on and ab * 0.25 or 0.08, 1)
                btn:SetBackdropBorderColor(on and ar or 0.22, on and ag or 0.22, on and ab or 0.26, 1)
            end
        end
        local defs = { { key = 'modern', label = 'Modern' }, { key = 'classic', label = 'Classic' } }
        for index, def in ipairs(defs) do
            local btn = CreateFrame("Button", nil, holder, "BackdropTemplate")
            btn:SetSize(92, 96)
            btn:SetPoint("TOPLEFT", (index - 1) * 100, 0)
            btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetSize(56, 56)
            tex:SetPoint("TOP", 0, -8)
            if def.key == 'classic' then
                tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. faction)
                tex:SetTexCoord(0, 0.65625, 0, 0.65625)
            else
                tex:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\" .. faction .. ".png")
            end
            local fs = btn:CreateFontString(nil, "OVERLAY")
            fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
            fs:SetPoint("BOTTOM", 0, 8)
            fs:SetText(LText(def.label))
            btn:SetScript("OnClick", function()
                SetAndRefresh(function() db[dbKey] = def.key end)
                PaintButtons()
            end)
            buttons[def.key] = btn
        end
        PaintButtons()
        by = by + 104
    return by
end

function ns.BuildComboPicker(container, W, by, unitKey)
    local CUF = ns.ComboUnderFrame
    local db = GetDB()
    local isTarget = unitKey == 'target'
    local dbKey = isTarget and 'comboTargetStyle' or 'comboUnderFrame'
    local _, lh = W:Label(container, isTarget and 'Combo Points (Target)' or 'Combo Points Under Player Frame', -by, 12)
    by = by + lh
    local holder = CreateFrame("Frame", nil, container)
    holder:SetPoint("TOPLEFT", 10, -by)
    holder:SetSize(310, 96)
    local buttons = {}
    local function Current()
        return db[dbKey] or (CUF and CUF.GetStyle(unitKey)) or 'off'
    end
    local function PaintButtons()
        local current = Current()
        local ar, ag, ab = CurrentAccentColor()
        for key, btn in pairs(buttons) do
            local on = current == key
            btn:SetBackdropColor(on and ar * 0.25 or 0.06, on and ag * 0.25 or 0.06, on and ab * 0.25 or 0.08, 1)
            btn:SetBackdropBorderColor(on and ar or 0.22, on and ag or 0.22, on and ab or 0.26, 1)
        end
    end
    local defs = { { key = 'off', label = 'Off', hint = 'Hidden' } }
    if isTarget then defs[#defs + 1] = { key = 'ring', label = 'Ring' } end
    defs[#defs + 1] = { key = 'modern', label = 'Modern' }
    defs[#defs + 1] = { key = 'classic', label = 'Classic' }
    local count = #defs
    local tileW = (count > 3) and 72 or 92
    local step = tileW + 6
    for index, def in ipairs(defs) do
        local btn = CreateFrame("Button", nil, holder, "BackdropTemplate")
        btn:SetSize(tileW, 96)
        btn:SetPoint("TOPLEFT", (index - 1) * step, 0)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        local function Pip(atlas, fallback, x, y, size)
            local t = btn:CreateTexture(nil, "ARTWORK")
            t:SetSize(size, size)
            t:SetPoint("TOP", x, y)
            if CUF and CUF.HasAtlas(atlas) then t:SetAtlas(atlas, false) else t:SetTexture(fallback) end
            return t
        end
        if def.key == 'modern' and CUF then
            Pip(CUF.ATLAS.modernFill, "Interface\\COMMON\\Indicator-Red", -12, -16, 22)
            Pip(CUF.ATLAS.modernEmpty, "Interface\\COMMON\\Indicator-Gray", 12, -16, 22)
        elseif def.key == 'classic' and CUF then
            local plate = btn:CreateTexture(nil, "ARTWORK")
            plate:SetSize(tileW - 12, 13)
            plate:SetPoint("TOP", 0, -20)
            if CUF.HasAtlas(CUF.ATLAS.plate) then plate:SetAtlas(CUF.ATLAS.plate, false)
            else plate:SetColorTexture(0.05, 0.05, 0.05, 1) end
        elseif def.key == 'ring' then
            for k = 1, 4 do
                local a = math.rad(100 - (k - 1) * 28)
                local t = btn:CreateTexture(nil, "ARTWORK")
                t:SetSize(11, 11)
                t:SetPoint("CENTER", btn, "TOP", math.cos(a) * 22 - 6, -34 + math.sin(a) * 16)
                t:SetTexture(k <= 2 and "Interface\\COMMON\\Indicator-Red" or "Interface\\COMMON\\Indicator-Gray")
                if k > 2 then t:SetVertexColor(0.1, 0.1, 0.1, 1) end
            end
        else
            local hint = btn:CreateFontString(nil, "OVERLAY")
            hint:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            hint:SetPoint("TOP", 0, -24)
            hint:SetWidth(tileW - 8)
            hint:SetText(LText(def.hint))
        end
        local fs = btn:CreateFontString(nil, "OVERLAY")
        fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        fs:SetPoint("BOTTOM", 0, 8)
        fs:SetText(LText(def.label))
        btn:SetScript("OnClick", function()
            SetAndRefresh(function() db[dbKey] = def.key end)
            PaintButtons()
        end)
        buttons[def.key] = btn
    end
    PaintButtons()
    by = by + 104
    -- Position preset (below / above the frame) and fine X / Y offsets.
    local suffix = isTarget and 'Target' or 'Player'
    local _, ph = W:Dropdown(container, 'Combo Points Position', -by,
        { below = 'Below Frame', above = 'Above Frame' },
        function() return db['comboPos' .. suffix] == 'above' and 'above' or 'below' end,
        function(v) SetAndRefresh(function() db['comboPos' .. suffix] = v end) end)
    by = by + ph
    local _, xh = W:Slider(container, 'Combo Points X', -by,
        function() return db['comboX' .. suffix] or 0 end,
        function(v) SetAndRefresh(function() db['comboX' .. suffix] = v end) end,
        -150, 150, 1, '%d')
    by = by + xh
    local _, yh = W:Slider(container, 'Combo Points Y', -by,
        function() return db['comboY' .. suffix] or 0 end,
        function(v) SetAndRefresh(function() db['comboY' .. suffix] = v end) end,
        -150, 150, 1, '%d')
    return by + yh
end

local function FontValues()
    local vals = {}
    local compat = ns.KUIUFCompat
    local paths = compat and compat.fontPaths or {}
    for name in pairs(paths) do
        if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(name) then
            vals[name] = name
        end
    end
    if LSM then
        local sharedFonts = LSM:List("font")
        for i = 1, #(sharedFonts or {}) do
            local name = sharedFonts[i]
            if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(name) then
                vals[name] = name
            end
        end
    end
    if not next(vals) then
        local def = (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "AAA_ITC_Avant_Garde"
        vals[def] = def
    end
    vals._menuOpts = {
        kind = "font",
        sharedMedia = true,
        resolve = function(name)
            return paths[name] or (LSM and LSM:Fetch("font", name, true))
        end,
    }
    return vals
end

local function TextureValues(includeNone)
    local values = {}
    local order = ns.healthBarTextureOrder or {}
    local names = ns.healthBarTextureNames or {}

    for _, key in ipairs(order) do
        if includeNone or key ~= "none" then
            values[key] = names[key] or key
        end
    end

    if next(values) == nil then
        values["Melli Reforged"] = "Melli Reforged"
    end

    values._menuOpts = {
        kind = "texture",
        sharedMedia = true,
        itemHeight = 28,
        background = function(key)
            return (ns.healthBarTextures and ns.healthBarTextures[key])
                or (LSM and LSM:Fetch("statusbar", key, true))
        end,
    }

    return values
end

local PREVIEW_LIVE_UNITS = {
    player = "player",
    pet = "pet",
    target = "target",
    focus = "focus",
    totPet = "targettarget",
    focustarget = "focustarget",
}

local PREVIEW_CLASS_FALLBACKS = {
    target = "MAGE",
    focus = "PRIEST",
    totPet = "ROGUE",
    focustarget = "DRUID",
    boss = "WARRIOR",
}

local PREVIEW_ICON_FALLBACKS = {
    pet = "Interface\\Icons\\Ability_Hunter_BeastCall",
}

ApplyPreviewPortraitTexture = function(texture, unitKey, portraitFacing)
    if not texture then
        return
    end

    texture:SetTexCoord(0, 1, 0, 1)

    local liveUnit = PREVIEW_LIVE_UNITS[unitKey]
    if liveUnit and UnitExists(liveUnit) then
        SetPortraitTexture(texture, liveUnit)
        if portraitFacing == "flipped" then
            texture:SetTexCoord(1, 0, 0, 1)
        end
        return
    end

    local classToken = PREVIEW_CLASS_FALLBACKS[unitKey]
    if classToken and _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[classToken] then
        texture:SetTexture(PREVIEW_CLASS_TEXTURE)
        texture:SetTexCoord(unpack(_G.CLASS_ICON_TCOORDS[classToken]))
        return
    end

    texture:SetTexture(PREVIEW_ICON_FALLBACKS[unitKey] or "Interface\\Icons\\INV_Misc_QuestionMark")
end
_G.ApplyPreviewPortraitTexture = ApplyPreviewPortraitTexture

local PORTRAIT_STYLES = {
    none = "Hidden",
    attached = "Attached",
    detached = "Detached",
    circular = "Circular",
}

local CLASSIFICATION_NO_PORTRAIT_STYLES = {
    nameplate = "Nameplate Dragon",
    unitframes = "Unit Frames Elite/Rare",
}

local CLASSIFICATION_ANCHORS = {
    TOPLEFT = "Top Left",
    TOP = "Top",
    TOPRIGHT = "Top Right",
    LEFT = "Left",
    CENTER = "Center",
    RIGHT = "Right",
    BOTTOMLEFT = "Bottom Left",
    BOTTOM = "Bottom",
    BOTTOMRIGHT = "Bottom Right",
}

local PORTRAIT_MODES = {
    ["2d"] = "2D Portrait",
    ["3d"] = "3D Portrait",
    ["class"] = "Class Theme",
}
local CIRCULAR_PORTRAIT_MODES = {
    ["2d"] = "2D Portrait",
    ["class"] = "Class Theme",
}

local PORTRAIT_FACING = {
    normal = "Normal",
    flipped = "Flipped",
}

local PORTRAIT_SIDES = {
    left = "Left",
    right = "Right",
}

local POWER_POSITIONS = {
    none = "Hidden",
    above = "Above",
    below = "Below",
}

local HEALTH_TEXT = {
    none = "None",
    curhpshort = "Current (Abbrev)",
    curhp = "Current (Full)",
    perhp = "Percent",
    both = "Current (Abbrev) + Percent",
    curhp_perhp = "Current (Full) + Percent",
    deficit = "Deficit",
}

local CLASS_POWER_STYLES = {
    none = "Disabled",
    blizzard = "Blizzard",
    modern = "Modern",
}

local COMBAT_INDICATOR_STYLES = {
    none = "Disabled",
    standard = "Blizzard",
}

local function NormalizeCombatIndicatorStyle(style)
    if style == "none" then
        return "none"
    end

    return "standard"
end

local function AddVisibilityControls(sc, unitKey, y)
    local db = GetDB()
    local s = db[unitKey]
    local h
    _, h = W:Toggle(sc, "Show Solo", -y, function() return s.showSolo ~= false end, function(v) SetAndRefresh(function() s.showSolo = v end) end); y = y + h
    _, h = W:Toggle(sc, "Show In Party", -y, function() return s.showInParty ~= false end, function(v) SetAndRefresh(function() s.showInParty = v end) end); y = y + h
    _, h = W:Toggle(sc, "Show In Raid", -y, function() return s.showInRaid ~= false end, function(v) SetAndRefresh(function() s.showInRaid = v end) end); y = y + h
    return y
end

GetDefaultPortraitFacing = function(unitKey)
    if unitKey == "target" then
        return "flipped"
    end
    return "normal"
end

local function AddCommonUnitControls(sc, unitKey, label, y, opts)
    local db = GetDB()
    local s = db[unitKey]
    local enabledKey = opts.enabledKey or unitKey
    local h

    if opts.showHeader ~= false then
        _, h = W:SectionHeader(sc, label, -y); y = y + h
    else
        sc.rowCounter = 0
    end
    _, h = W:Toggle(sc, "Enable Frame", -y,
        function()
            if opts.enabledGet then return opts.enabledGet(db) end
            return db.enabledFrames[enabledKey] ~= false
        end,
        function(v)
            SetAndRefresh(function()
                if opts.enabledSet then
                    opts.enabledSet(db, v)
                else
                    db.enabledFrames[enabledKey] = v
                end
            end)
        end); y = y + h
    _, h = W:Slider(sc, "Frame Width", -y,
        function() return s.frameWidth or 100 end,
        function(v) SetAndRefresh(function() s.frameWidth = v end) end, 60, 320, 1); y = y + h
    _, h = W:Slider(sc, "Health Height", -y,
        function() return s.healthHeight or 20 end,
        function(v) SetAndRefresh(function() s.healthHeight = v end) end, 12, 80, 1); y = y + h
    if opts.showFrameScale then
        -- Size control for this specific frame. frameScale is an overall
        -- percentage multiplier on top of Frame Width/Health Height,
        -- clamped 25-300 elsewhere. Scoped to player/target only (opts
        -- flag).
        local scaleWidget
        scaleWidget, h = W:Slider(sc, "Frame Size", -y,
            function() return s.frameScale or 100 end,
            function(v) SetAndRefresh(function() s.frameScale = v end) end, 25, 300, 1)
        LockIfThemeOwned(scaleWidget, unitKey .. ".frameScale")
        y = y + h
    end
    local widget
    widget, h = W:Toggle(sc, "Class Colored Health", -y,
        function() return s.healthClassColored ~= false end,
        function(v) SetAndRefresh(function() s.healthClassColored = v end) end)
    LockIfThemeOwned(widget, unitKey .. ".healthClassColored")
    y = y + h
    _, h = W:ColorSwatch(sc, "Health Fill Color", -y,
        function()
            local c = s.customFillColor or { r = 0.22, g = 0.55, b = 0.95, a = 1 }
            return c.r, c.g, c.b, c.a
        end,
        function(r, g, b, a)
            SetAndRefresh(function()
                s.customFillColor = { r = r, g = g, b = b, a = a }
            end)
        end, true); y = y + h
    _, h = W:ColorSwatch(sc, "Health Background Color", -y,
        function()
            local c = s.customBgColor or { r = 0.08, g = 0.08, b = 0.08, a = 1 }
            return c.r, c.g, c.b, c.a
        end,
        function(r, g, b, a)
            SetAndRefresh(function()
                s.customBgColor = { r = r, g = g, b = b, a = a }
            end)
        end, true); y = y + h

    if opts.hasPower then
        _, h = W:Dropdown(sc, "Power Bar Position", -y, POWER_POSITIONS,
            function() return s.powerPosition or "below" end,
            function(v) SetAndRefresh(function() s.powerPosition = v end) end); y = y + h
        _, h = W:Slider(sc, "Power Height", -y,
            function() return s.powerHeight or 6 end,
            function(v) SetAndRefresh(function() s.powerHeight = v end) end, 0, 24, 1); y = y + h
    end

    local widget
    widget, h = W:Toggle(sc, "Show Portrait", -y,
        function() return s.showPortrait ~= false end,
        function(v) SetAndRefresh(function() s.showPortrait = v end) end)
    LockIfThemeOwned(widget, unitKey .. ".showPortrait")
    y = y + h
    widget, h = W:Dropdown(sc, "Portrait Style", -y, PORTRAIT_STYLES,
        function() return db.portraitStyle or "attached" end,
        function(v) SetAndRefresh(function() db.portraitStyle = v end) end)
    LockIfThemeOwned(widget, "portraitStyle")
    y = y + h
    local portraitModes = db.portraitStyle == "circular" and CIRCULAR_PORTRAIT_MODES or PORTRAIT_MODES
    _, h = W:Dropdown(sc, "Portrait Mode", -y, portraitModes,
        function()
            local mode = s.portraitMode or "2d"
            return (db.portraitStyle == "circular" and mode == "3d") and "2d" or mode
        end,
        function(v) SetAndRefresh(function() s.portraitMode = v end) end); y = y + h
    
    -- Portrait Side (for attached and circular portraits)
    if db.portraitStyle ~= "none" then
        widget, h = W:Dropdown(sc, "Portrait Side", -y, PORTRAIT_SIDES,
            function()
                local defaultSide = (unitKey == "player" or unitKey == "pet") and "left" or "right"
                return s.portraitSide or defaultSide 
            end,
            function(v) SetAndRefresh(function() s.portraitSide = v end) end)
        LockIfThemeOwned(widget, "target.portraitSide")
        y = y + h
    end
    
    if opts.allowPortraitFacing then
        _, h = W:Dropdown(sc, "Portrait Facing", -y,
            { auto = "Auto", normal = "Normal", flipped = "Flipped" },
            function() return s.portraitFacingMode or "auto" end,
            function(v) SetAndRefresh(function()
                s.portraitFacingMode = (v ~= "auto") and v or nil
            end) end,
            { "auto", "normal", "flipped" }); y = y + h
    end
    
    -- Portrait position and size controls (always shown when portrait options exist)
    _, h = W:Slider(sc, "Portrait Size Adjustment", -y,
        function() return s.portraitSize or 0 end,
        function(v) SetAndRefresh(function() s.portraitSize = v end) end, -40, 300, 1); y = y + h
    _, h = W:Slider(sc, "Portrait X Offset", -y,
        function() return s.portraitX or 0 end,
        function(v) SetAndRefresh(function() s.portraitX = v end) end, -250, 250, 1); y = y + h
    _, h = W:Slider(sc, "Portrait Y Offset", -y,
        function() return s.portraitY or 0 end,
        function(v) SetAndRefresh(function() s.portraitY = v end) end, -250, 250, 1); y = y + h

    if opts.hasCastbar then
        local castToggleKey = opts.castToggleKey or "showCastbar"
        widget, h = W:Toggle(sc, "Show Castbar", -y,
            function() return s[castToggleKey] ~= false end,
            function(v) SetAndRefresh(function() s[castToggleKey] = v end) end)
        -- Player's cast bar visibility is seeded ON by the stock-art themes, but the user can
        -- switch it off in every style (the choice is stored per theme slot), so it is not locked.
        y = y + h
    end

    if opts.showBuffsKey then
        _, h = W:Toggle(sc, opts.showBuffsLabel or "Show Buffs", -y,
            function() return s[opts.showBuffsKey] ~= false end,
            function(v) SetAndRefresh(function() s[opts.showBuffsKey] = v end) end); y = y + h
    end

    if opts.showDebuffsKey then
        _, h = W:Toggle(sc, opts.showDebuffsLabel or "Show Debuffs", -y,
            function() return s[opts.showDebuffsKey] ~= false end,
            function(v) SetAndRefresh(function() s[opts.showDebuffsKey] = v end) end); y = y + h
    end

    if opts.showDispelOverlayKey then
        _, h = W:Toggle(sc, opts.showDispelOverlayLabel or "Dispel Overlay", -y,
            function() return s[opts.showDispelOverlayKey] ~= false end,
            function(v) SetAndRefresh(function() s[opts.showDispelOverlayKey] = v end) end); y = y + h
            
        local function AddColorSwatch(key, label, defR, defG, defB)
            _, h = W:ColorSwatch(sc, label, -y,
                function()
                    local c = s[key]
                    if c then return c.r, c.g, c.b, 1 else return defR, defG, defB, 1 end
                end,
                function(r, g, b)
                    SetAndRefresh(function() s[key] = {r=r, g=g, b=b} end)
                end, false); y = y + h
        end
        AddColorSwatch("dispelColorMagic", "Magic Color", 0.349, 0.475, 1.0)
        AddColorSwatch("dispelColorCurse", "Curse Color", 0.636, 0.0, 0.640)
        AddColorSwatch("dispelColorDisease", "Disease Color", 0.671, 0.384, 0.098)
        AddColorSwatch("dispelColorPoison", "Poison Color", 0.0, 0.706, 0.286)
        AddColorSwatch("dispelColorBleed", "Bleed Color", 0.750, 0.150, 0.150)
    end


    _, h = W:Dropdown(sc, "Health Text", -y, HEALTH_TEXT,
        function() return s.healthDisplay or "both" end,
        function(v) SetAndRefresh(function()
            s.healthDisplay = v
            ApplyHealthDisplayToText(s)
        end) end); y = y + h
    _, h = W:Slider(sc, "Text Size", -y,
        function() return s.textSize or s.leftTextSize or 12 end,
        function(v) SetAndRefresh(function() s.textSize = v; s.leftTextSize = v; s.rightTextSize = v; s.centerTextSize = v end) end, 8, 24, 1); y = y + h

    if opts.hasVisibility then
        y = AddVisibilityControls(sc, unitKey, y)
    end

    return y
end

local function CreateOptionBlock(parent, title, x, y, width)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 40)
    frame:SetPoint("TOPLEFT", x, y)
    KT:AddBackdrop(frame, 0.04, 0.04, 0.05, 0.95)
    KT:AddBorder(frame, 0.18, 0.18, 0.22, 1)

    local titleText = frame:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(KT.FONT_PATH, 10, "OUTLINE")
    KT:SetAccentTextColor(titleText, 1)
    titleText:SetPoint("TOPLEFT", 10, -8)
    titleText:SetText(string.upper(title))

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 0, -24)
    content:SetWidth(width)
    content:SetHeight(1)
    content.rowCounter = 0

    return frame, content
end

local function FinalizeOptionBlock(frame, content, contentHeight)
    local headerH = 24
    local bottomPad = 10
    local total = headerH + contentHeight + bottomPad
    content:SetHeight(contentHeight)
    frame:SetHeight(total)
    return total
end

local function CreateUnitFramesLivePreview(parent, options)
    options = options or {}
    local db = GetDB()
    if not db then return nil end

    local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    preview:SetSize(options.width or (parent:GetWidth() - 20), options.height or 180)
    preview:SetPoint("TOPLEFT", options.x or 10, -(options.y or 10))
    KT:AddBackdrop(preview, 0.04, 0.04, 0.05, 0.95)
    KT:AddBorder(preview, 0.18, 0.18, 0.22, 1)
    if options.attachSticky ~= false and KT.AttachStickyPreview then
        KT:AttachStickyPreview(preview, { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 10, y = -10 })
    end

    local previewTitle = preview:CreateFontString(nil, "OVERLAY")
    previewTitle:SetFont(PREVIEW_DEFAULT_FONT, 10, "OUTLINE")
    KT:SetAccentTextColor(previewTitle, 1)
    previewTitle:SetPoint("TOPLEFT", 10, -8)
    previewTitle:SetText(LText("LIVE PREVIEW"))

    local playerPreview = CreatePreviewUnit(preview)
    local targetPreview = CreatePreviewUnit(preview)
    local focusPreview = CreatePreviewUnit(preview)
    local petPreview = CreatePreviewUnit(preview)
    local targetTargetPreview = CreatePreviewUnit(preview)
    local focusTargetPreview = CreatePreviewUnit(preview)

    preview.Refresh = function()
        local previewWidth = preview:GetWidth()
        ns.ApplyPreviewUnit(playerPreview, "player", db.player, db, "Player", "100%")
        ns.ApplyPreviewUnit(targetPreview, "target", db.target, db, "Target", "100%")
        ns.ApplyPreviewUnit(focusPreview, "focus", db.focus, db, "Focus", "100%")
        ns.ApplyPreviewUnit(petPreview, "pet", db.pet, db, "Pet", "100%")
        ns.ApplyPreviewUnit(targetTargetPreview, "totPet", db.totPet, db, "ToT", "100%")
        ns.ApplyPreviewUnit(focusTargetPreview, "focustarget", db.totPet, db, "Focus Target", "100%")

        playerPreview:ClearAllPoints()
        playerPreview:SetPoint("TOPLEFT", preview, "TOPLEFT", 18, -34)
        targetPreview:ClearAllPoints()
        targetPreview:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -18, -34)
        petPreview:ClearAllPoints()
        petPreview:SetPoint("TOPLEFT", playerPreview, "BOTTOMLEFT", 0, -12)
        focusPreview:ClearAllPoints()
        focusPreview:SetPoint("TOPLEFT", petPreview, "BOTTOMLEFT", 0, -20)
        targetTargetPreview:ClearAllPoints()
        targetTargetPreview:SetPoint("TOPRIGHT", targetPreview, "BOTTOMRIGHT", -5, -8)
        focusTargetPreview:ClearAllPoints()
        focusTargetPreview:SetPoint("TOPRIGHT", targetTargetPreview, "BOTTOMRIGHT", 0, -12)

        if previewWidth > 0 then
            local leftStackHeight = (playerPreview:GetHeight() or 0) + (petPreview:GetHeight() or 0) + (focusPreview:GetHeight() or 0) + 86
            local rightStackHeight = (targetPreview:GetHeight() or 0) + (targetTargetPreview:GetHeight() or 0) + (focusTargetPreview:GetHeight() or 0) + 66
            preview:SetHeight(math.max(leftStackHeight, rightStackHeight))
        end
    end
    preview:Refresh()
    
    -- Store preview frames for external access
    preview.playerPreview = playerPreview
    preview.targetPreview = targetPreview
    preview.focusPreview = focusPreview
    preview.petPreview = petPreview
    preview.targetTargetPreview = targetTargetPreview
    preview.focusTargetPreview = focusTargetPreview
    
    return preview
end

_G.KullThranUI_UnitFramesOptions = _G.KullThranUI_UnitFramesOptions or {}
_G.KullThranUI_UnitFramesOptions.CreateLivePreview = CreateUnitFramesLivePreview
KT:RegisterPage("unitframes", "Unit Frames", 11, function(sc, W)
    W = W or (KT and KT.Widgets)
    if not W then return 0 end
    local db = GetDB()
    if not db then return 0 end
    local y, h = 0, 0

    local optionsFrame = KT.MenuPrincipal
    if optionsFrame and not optionsFrame._kuiUFPreviewClassHooked then
        optionsFrame._kuiUFPreviewClassHooked = true
        optionsFrame:HookScript("OnShow", function()
            RerollPreviewClassAssignments()
            C_Timer.After(0, function()
                if previewRefresh then previewRefresh() end
            end)
        end)
    end

    local preview = CreateUnitFramesLivePreview(sc)
    previewRefresh = function() preview:Refresh() end    previewRefresh()
    local previewBottomGap = 24
    y = y + preview:GetHeight() + previewBottomGap

    local gap = 12
    local columnGap = 14
    local fullW = sc:GetWidth()
    local blockW = math.floor((fullW - 20 - columnGap) / 2)
    local leftX = 10
    local rightX = leftX + blockW + columnGap
    local leftUsed = 0
    local rightUsed = 0

    for _, child in ipairs({ sc:GetChildren() }) do
        if child ~= _tabBarFrame and child ~= preview then child:Hide() end
    end
    local tabContainer, tabH = BuildTabBar(sc, -y)
    y = y + tabH + 6

    local optionBlocks = {}

    local function AddBlock(column, title, buildFn, key)
        local x = (column == 'right') and rightX or leftX
        local yOff = -(y + ((column == 'right') and rightUsed or leftUsed))
        local frame, content = CreateOptionBlock(sc, title, x, yOff, blockW)
        local contentH = buildFn(content)
        local totalH = FinalizeOptionBlock(frame, content, contentH)
        optionBlocks[key or title] = frame
        if column == 'right' then
            rightUsed = rightUsed + totalH + gap
        else
            leftUsed = leftUsed + totalH + gap
        end
        return frame
    end

    if ufActiveTab == 'general' then
        AddBlock('left', 'Global', function(container)
            local by = 0
            _, h = W:Toggle(container, 'Enable Module', -by,
                function() return db.enable ~= false end,
                function(v)
                    db.enable = v
                    ReloadUI()
                end); by = by + h
            _, h = W:Toggle(container, 'Show Character Level', -by,
                function() return db.showCharacterLevel ~= false end,
                function(v) SetAndRefresh(function() db.showCharacterLevel = v and true or false end) end); by = by + h
            _, h = W:Toggle(container, 'Show PvP Faction Icon', -by,
                function() return db.showPvPIcon == true end,
                function(v) SetAndRefresh(function() db.showPvPIcon = v and true or false end) end); by = by + h
            _, h = W:Toggle(container, 'Show Elite/Rare Indicator', -by,
                function() return db.showClassification ~= false end,
                function(v) SetAndRefresh(function() db.showClassification = v and true or false end) end); by = by + h
            _, h = W:Dropdown(container, 'No-Portrait Indicator Style', -by, CLASSIFICATION_NO_PORTRAIT_STYLES,
                function() return db.classificationNoPortraitStyle or 'nameplate' end,
                function(v) SetAndRefresh(function() db.classificationNoPortraitStyle = v end) end); by = by + h
            _, h = W:Slider(container, 'Indicator Size', -by,
                function() return tonumber(db.classificationNoPortraitSize) or 52 end,
                function(v) SetAndRefresh(function() db.classificationNoPortraitSize = v end) end, 8, 128, 1); by = by + h
            _, h = W:Dropdown(container, 'Indicator Anchor', -by, CLASSIFICATION_ANCHORS,
                function() return db.classificationNoPortraitAnchor or 'TOPRIGHT' end,
                function(v) SetAndRefresh(function() db.classificationNoPortraitAnchor = v end) end); by = by + h
            _, h = W:Slider(container, 'Indicator X Offset', -by,
                function() return tonumber(db.classificationNoPortraitX) or -8 end,
                function(v) SetAndRefresh(function() db.classificationNoPortraitX = v end) end, -300, 300, 1); by = by + h
            _, h = W:Slider(container, 'Indicator Y Offset', -by,
                function() return tonumber(db.classificationNoPortraitY) or 0 end,
                function(v) SetAndRefresh(function() db.classificationNoPortraitY = v end) end, -300, 300, 1); by = by + h
            local levelOutlineValues = { NONE = 'None', OUTLINE = 'Outline', THICKOUTLINE = 'Thick Outline', MONOCHROME = 'Monochrome', OUTLINEMONOCHROME = 'Monochrome Outline' }
            do
                local _, lh = W:Label(container, 'Player Rare / Elite Border', -by, 12)
                by = by + lh
                local holder = CreateFrame("Frame", nil, container)
                holder:SetPoint("TOPLEFT", 10, -by)
                holder:SetSize(300, 204)
                local buttons = {}
                local function PaintButtons()
                    local current = db.playerClassificationBorder or 'none'
                    local ar, ag, ab = CurrentAccentColor()
                    for key, btn in pairs(buttons) do
                        local on = current == key
                        btn:SetBackdropColor(on and ar * 0.25 or 0.06, on and ag * 0.25 or 0.06, on and ab * 0.25 or 0.08, 1)
                        btn:SetBackdropBorderColor(on and ar or 0.22, on and ag or 0.22, on and ab or 0.26, 1)
                    end
                end
                local defs = { { key = 'none', label = 'Default', hint = 'Theme portrait' },
                               { key = 'rare', file = 'RARE.png', label = 'Rare' },
                               { key = 'elite', file = 'ELITE.png', label = 'Elite' },
                               { key = 'classicrare', sheet = 'rare', label = 'Classic Rare' },
                               { key = 'classicelite', sheet = 'elite', label = 'Classic Elite' } }
                for index, def in ipairs(defs) do
                    local btn = CreateFrame("Button", nil, holder, "BackdropTemplate")
                    btn:SetSize(92, 96)
                    btn:SetPoint("TOPLEFT", ((index - 1) % 3) * 100, -math.floor((index - 1) / 3) * 104)
                    btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
                        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
                    local tex = btn:CreateTexture(nil, "ARTWORK")
                    tex:SetSize(64, 64)
                    tex:SetPoint("TOP", 0, -8)
                    if def.file then
                        tex:SetTexture(ns.RING_ICON_PATH .. def.file)
                    elseif def.sheet and ns.ClassicRing then
                        local CR = ns.ClassicRing
                        tex:SetTexture(CR.sheets[def.sheet])
                        tex:SetTexCoord(CR.uLeft, CR.uRight, CR.vTop, CR.vBottom)
                        tex:SetSize(68, 50)
                    else
                        local hint = btn:CreateFontString(nil, "OVERLAY")
                        hint:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
                        hint:SetPoint("CENTER", tex, "CENTER", 0, 0)
                        hint:SetWidth(80)
                        hint:SetText(LText(def.hint))
                    end
                    local fs = btn:CreateFontString(nil, "OVERLAY")
                    fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
                    fs:SetPoint("BOTTOM", 0, 8)
                    fs:SetText(LText(def.label))
                    btn:SetScript("OnClick", function()
                        SetAndRefresh(function() db.playerClassificationBorder = def.key end)
                        PaintButtons()
                    end)
                    buttons[def.key] = btn
                end
                PaintButtons()
                -- Greyed out (and not clickable) while the Player portrait is off.
                local function UpdateEnabled()
                    local portraitOn = (db.portraitStyle or "attached") ~= "none"
                        and not (db.player and db.player.showPortrait == false)
                    holder:SetAlpha(portraitOn and 1 or 0.35)
                    for _, btn in pairs(buttons) do
                        btn:SetEnabled(portraitOn)
                    end
                end
                holder._acc = 0
                holder:SetScript("OnUpdate", function(self, elapsed)
                    self._acc = self._acc + elapsed
                    if self._acc > 0.25 then
                        self._acc = 0
                        UpdateEnabled()
                    end
                end)
                UpdateEnabled()
                by = by + 212
            end
            _, h = W:Toggle(container, 'Smooth Health/Power Bars', -by,
                function() return db.smoothBars ~= false end,
                function(v) SetAndRefresh(function() db.smoothBars = v and true or false end) end); by = by + h
            _, h = W:Toggle(container, 'Combat Text on Portrait (Dodge / Miss / damage)', -by,
                function()
                    if db.hitText ~= nil then return db.hitText ~= false end
                    local th = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme and KT.VisualThemes:GetRenderedTheme()
                    return th == "classic" or th == "forever" or th == "retail"
                end,
                function(v) SetAndRefresh(function() db.hitText = v and true or false end) end); by = by + h
            _, h = W:Toggle(container, '    Numbers in White (damage and healing)', -by,
                function() return db.hitTextWhiteNumbers == true end,
                function(v) SetAndRefresh(function() db.hitTextWhiteNumbers = v and true or false end) end); by = by + h
            _, h = W:Toggle(container, 'Aggro Glow (red pulse on player frame)', -by,
                function() return db.aggroGlow ~= false end,
                function(v)
                    SetAndRefresh(function() db.aggroGlow = v and true or false end)
                    if ns.AggroGlow and ns.AggroGlow.Update then pcall(ns.AggroGlow.Update, ns.AggroGlow) end
                end); by = by + h
            local widget
            widget, h = W:Toggle(container, 'Show PvP Icon Backdrop Circle', -by,
                function()
                    if db.showPvPCircle ~= nil then return db.showPvPCircle end
                    -- Matches KUIUnitFrames.lua's own render-time default:
                    -- off for kui until the user explicitly picks a value.
                    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
                        and KT.VisualThemes:GetRenderedTheme()
                    return renderedTheme ~= "kui"
                end,
                function(v) SetAndRefresh(function() db.showPvPCircle = v and true or false end) end)
            LockIfThemeOwned(widget, "showPvPCircle")
            by = by + h
            _, h = W:Dropdown(container, 'Level Font', -by, FontValues,
                function() return db.levelFont or 'AAA_ITC_Avant_Garde' end,
                function(v) SetAndRefresh(function() db.levelFont = v end) end); by = by + h
            _, h = W:Slider(container, 'Level Font Size', -by,
                function() return tonumber(db.levelFontSize) or 11 end,
                function(v) SetAndRefresh(function() db.levelFontSize = v end) end, 6, 48, 1); by = by + h
            _, h = W:Dropdown(container, 'Level Text Outline', -by, levelOutlineValues,
                function() return db.levelFontOutline or 'OUTLINE' end,
                function(v) SetAndRefresh(function() db.levelFontOutline = v end) end); by = by + h
            _, h = W:ColorSwatch(container, 'Level Text Color', -by,
                function() local c = db.levelColor or { r = 1, g = 0.82, b = 0.20, a = 1 }; return c.r, c.g, c.b, c.a end,
                function(r, g, b, a) SetAndRefresh(function() db.levelColor = { r = r, g = g, b = b, a = a or 1 } end) end, true); by = by + h
            _, h = W:Slider(container, 'Level X Offset', -by,
                function() return tonumber(db.levelX) or 2 end,
                function(v) SetAndRefresh(function() db.levelX = v end) end, -200, 200, 1); by = by + h
            _, h = W:Slider(container, 'Level Y Offset', -by,
                function() return tonumber(db.levelY) or 2 end,
                function(v) SetAndRefresh(function() db.levelY = v end) end, -100, 200, 1); by = by + h
            local widget
            widget, h = W:Dropdown(container, 'Portrait Style', -by, PORTRAIT_STYLES,
                function() return db.portraitStyle or 'attached' end,
                function(v) SetAndRefresh(function() db.portraitStyle = v end) end)
            LockIfThemeOwned(widget, "portraitStyle")
            by = by + h
            _, h = W:Toggle(container, 'Custom Circular Portrait Border', -by,
                function() return db.circularPortraitBorderUseCustomColor == true end,
                function(v) SetAndRefresh(function() db.circularPortraitBorderUseCustomColor = v and true or false end) end); by = by + h
            _, h = W:ColorSwatch(container, 'Circular Portrait Border Color', -by,
                function()
                    local c = db.circularPortraitBorderColor
                    if c then return c.r, c.g, c.b, c.a end
                    local r, g, b = CurrentAccentColor()
                    return r, g, b, 1
                end,
                function(r, g, b, a)
                    SetAndRefresh(function()
                        db.circularPortraitBorderColor = { r = r, g = g, b = b, a = a or 1 }
                    end)
                end, false); by = by + h
            widget, h = W:Toggle(container, 'Dark Theme', -by,
                function() return db.darkTheme == true end,
                function(v) SetAndRefresh(function() db.darkTheme = v end) end)
            LockIfThemeOwned(widget, "darkTheme")
            by = by + h
            _, h = W:Slider(container, 'Castbar Opacity', -by,
                function() return math.floor((db.castbarOpacity or 1) * 100 + 0.5) end,
                function(v) SetAndRefresh(function() db.castbarOpacity = v / 100 end) end, 0, 100, 1); by = by + h
            _, h = W:ColorSwatch(container, 'Castbar Color', -by,
                function()
                    local c = db.castbarColor
                    if c then return c.r, c.g, c.b, c.a end
                    local r, g, b = CurrentAccentColor()
                    return r, g, b, 1
                end,
                function(r, g, b, a) SetAndRefresh(function() db.castbarColor = { r = r, g = g, b = b, a = a } end) end, true); by = by + h
            _, h = W:Dropdown(container, 'Default Font', -by, FontValues,
                function() return db.player and db.player.selectedFont or 'AAA_ITC_Avant_Garde' end,
                function(v) SetAndRefresh(function()
                    for _, key in ipairs({ 'player', 'target', 'focus', 'boss', 'pet', 'totPet' }) do
                        if db[key] then db[key].selectedFont = v end
                    end
                end) end); by = by + h
            local widget
            widget, h = W:Dropdown(container, 'Default Texture', -by, TextureValues(false),
                function() return db.player and db.player.healthBarTexture or 'Melli Reforged' end,
                function(v) SetAndRefresh(function()
                    for _, key in ipairs({ 'player', 'target', 'focus', 'boss', 'pet', 'totPet' }) do
                        if db[key] then db[key].healthBarTexture = v end
                    end
                end) end)
            -- Texture is independent per Visual Style (stored in the theme slot).
            by = by + h
            return by
        end, 'global')

        AddBlock('right', 'Positions', function(container)
            local by = 0
            _, h = W:Label(container, 'Use Unlock Mode to drag Unit Frames registered by KullThranUI.', -by, 11); by = by + h
            _, h = W:Button(container, 'Open Unlock Mode', -by, function()
                local UM = KT and KT.GetModule and KT:GetModule('UnlockMode', true)
                if UM and not UM.isOpen and UM.OpenUnlockMode then
                    UM:OpenUnlockMode()
                elseif UM and UM.isOpen and UM.RefreshMovers then
                    UM:RefreshMovers()
                end
            end); by = by + h
            _, h = W:Button(container, 'Reset Unit Frames Defaults', -by, function()
                StaticPopup_Show('KULLTHRANUI_UF_RESET_DEFAULTS')
            end); by = by + h
            return by
        end, 'positions')
    end

    if ufActiveTab == 'player' then
        AddBlock('left', 'Player', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'player', 'Player', by, {
                hasPower = true,
                hasCastbar = true,
                allowPortraitFacing = true,
                castToggleKey = 'showPlayerCastbar',
                showBuffsKey = 'showBuffs',
                showBuffsLabel = 'Show Buffs',
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = true,
                showHeader = false,
                showFrameScale = true,
            })

            _, h = W:Toggle(container, 'Show Absorb Bar', -by,
                function() return db.player.showPlayerAbsorb == true end,
                function(v) SetAndRefresh(function() db.player.showPlayerAbsorb = v end) end); by = by + h
            _, h = W:Dropdown(container, 'Absorb Texture', -by, TextureValues(true),
                function() return db.player.absorbBarTexture or 'glass' end,
                function(v) SetAndRefresh(function() db.player.absorbBarTexture = v end) end); by = by + h
            _, h = W:ColorSwatch(container, 'Absorb Color', -by,
                function()
                    local c = db.player.absorbBarColor or { r = 0.74, g = 0.92, b = 1, a = 0.82 }
                    return c.r, c.g, c.b, c.a
                end,
                function(r, g, b, a)
                    SetAndRefresh(function()
                        db.player.absorbBarColor = { r = r, g = g, b = b, a = a }
                    end)
                end, true); by = by + h
            _, h = W:Toggle(container, 'Show Class Power', -by,
                function() return db.player.showClassPowerBar == true end,
                function(v) SetAndRefresh(function() db.player.showClassPowerBar = v end) end); by = by + h
            _, h = W:Dropdown(container, 'Class Power Style', -by, CLASS_POWER_STYLES,
                function() return db.player.classPowerStyle or 'none' end,
                function(v) SetAndRefresh(function() db.player.classPowerStyle = v; db.player.showClassPowerBar = (v ~= 'none') end) end); by = by + h
            by = ns.BuildComboPicker(container, W, by, 'player')
            by = ns.BuildPvPPicker(container, W, by, 'player')
            _, h = W:Dropdown(container, 'Combat Indicator', -by, COMBAT_INDICATOR_STYLES,
                function() return NormalizeCombatIndicatorStyle(db.player.combatIndicatorStyle) end,
                function(v) SetAndRefresh(function() db.player.combatIndicatorStyle = v end) end); by = by + h
            return by
        end, 'player')

        AddBlock('right', 'Pet', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'pet', 'Pet', by, {
                hasPower = false,
                hasCastbar = false,
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = false,
                showHeader = false,
            })
            return by
        end, 'pet')
    end

    if ufActiveTab == 'target' then
        AddBlock('left', 'Target', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'target', 'Target', by, {
                hasPower = true,
                hasCastbar = true,
                allowPortraitFacing = true,
                showBuffsKey = 'showBuffs',
                showBuffsLabel = 'Show Buffs',
                showDebuffsKey = 'onlyPlayerDebuffs',
                showDebuffsLabel = 'Only Player Debuffs',
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = true,
                showHeader = false,
                showFrameScale = true,
            })
            by = ns.BuildComboPicker(container, W, by, 'target')
            by = ns.BuildPvPPicker(container, W, by, 'target')
            return by
        end, 'target')

        AddBlock('right', 'Focus', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'focus', 'Focus', by, {
                hasPower = true,
                hasCastbar = true,
                showDebuffsKey = 'onlyPlayerDebuffs',
                showDebuffsLabel = 'Only Player Debuffs',
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = true,
                showHeader = false,
            })
            return by
        end, 'focus')

        AddBlock('left', 'Target Of Target / Focus Target', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'totPet', 'Target Of Target / Focus Target', by, {
                enabledGet = function(dbRef)
                    return dbRef.enabledFrames.targettarget ~= false or dbRef.enabledFrames.focustarget ~= false
                end,
                enabledSet = function(dbRef, v)
                    dbRef.enabledFrames.targettarget = v
                    dbRef.enabledFrames.focustarget = v
                end,
                hasPower = false,
                hasCastbar = false,
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = false,
                showHeader = false,
            })
            return by
        end, 'totPet')
    end

    if ufActiveTab == 'boss' then
        AddBlock('left', 'Boss', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'boss', 'Boss', by, {
                enabledKey = 'boss',
                hasPower = true,
                hasCastbar = false,
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = false,
                showHeader = false,
            })
            _, h = W:Slider(container, 'Boss Spacing', -by,
                function() return db.bossSpacing or 60 end,
                function(v) SetAndRefresh(function() db.bossSpacing = v end) end, 20, 120, 1); by = by + h
            return by
        end, 'boss')
    end

    BindPreviewClick(preview.playerPreview, 'Player Preview', 'player', function() return optionBlocks.player end)
    BindPreviewClick(preview.targetPreview, 'Target Preview', 'target', function() return optionBlocks.target end)
    BindPreviewClick(preview.focusPreview, 'Focus Preview', 'target', function() return optionBlocks.focus end)
    BindPreviewClick(preview.petPreview, 'Pet Preview', 'player', function() return optionBlocks.pet end)
    BindPreviewClick(preview.targetTargetPreview, 'Target Of Target / Focus Target Preview', 'target', function() return optionBlocks.totPet end)
    BindPreviewClick(preview.focusTargetPreview, 'Target Of Target / Focus Target Preview', 'target', function() return optionBlocks.totPet end)

    y = y + math.max(leftUsed, rightUsed)

    return y
end)
