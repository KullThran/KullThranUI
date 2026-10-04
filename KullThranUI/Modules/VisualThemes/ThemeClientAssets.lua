local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}
KT.VisualThemes.NativeStockFonts = {}
for _, name in ipairs({ "TextStatusBarText", "GameNormalNumberFont", "GameFontNormalSmall" }) do
    local font = _G[name]
    if font and font.GetFont then
        local path, size, flags = font:GetFont()
        KT.VisualThemes.NativeStockFonts[name] = { path, size, flags or "" }
    end
end
function KT.VisualThemes:GetNativeStockFont(name, path, size, flags)
    local native = self.NativeStockFonts[name]
    if native and native[1] then return native[1], native[2], native[3] end
    return path, size, flags
end

--[[
    ThemeClientAssets.lua

    Shared rendering helpers that draw REAL per-client texture/atlas art onto
    KullThranUI's own custom-built UnitFrame widgets. Rendering TOOLS only --
    no saved-variable reads/writes, no opinion about which theme calls them.

    Classic uses the real fixed-path Blizzard sheet
    Interface\TargetingFrame\UI-TargetingFrame. Player and target use its
    verified 230x99 stock frame samples and exact 232x100 layout rectangles.
    Units without a verified full-frame entry retain the older provisional
    58x58 portrait-only crop; that fallback still requires in-game visual QA.
    Decorative art is seated on a dedicated child frame (see EnsureArtHost),
    because textures created directly on the outer frame render behind its
    child bars and portrait. Its strata and level are resolved from the live
    Health bar on every pass: portrait, art, bars and text therefore remain
    in one local stack even when UnitFrames changes the frame tree's strata.
]]

local PORTRAIT_FRAME_TEXTURE = [[Interface\TargetingFrame\UI-TargetingFrame]]

-- Real circular mask already shipped with (and already used elsewhere by)
-- this addon for its own "circular" portraitStyle -- see KUIUnitFrames.lua's
-- PORTRAIT_MASKS.circle. Reused here as-is so the classic/forever portrait
-- art reads as a clean circle regardless of what its underlying crop/atlas
-- actually contains (round, not square).
local PORTRAIT_MASK_TEXTURE = [[Interface\AddOns\KullThranUI\Libraries\texture\media\portraits\circle_mask.tga]]

-- Hand-authored mask matching the real gap between the ring's flat dome
-- corner and the circular portrait mask
-- (concave arc, opaque toward the corner, fading toward the round side) --
-- replaces the plain square guess, which needed several rounds of margin
-- tuning and still either fell short of the corner or overshot the round
-- edge. `_LEFT` fits a corner whose solid side faces left (target's
-- bottom-left, health bar on its left); `_RIGHT` is its horizontal mirror
-- (player's bottom-right, health bar on its right), pre-flipped as its own
-- file rather than mirrored at runtime (MaskTexture:SetTexCoord flips make
-- the whole portrait vanish when applied to the portrait's own mask, so
-- never risk that on this one either).
local DOME_CORNER_MASK_LEFT = [[Interface\AddOns\KullThranUI\Libraries\texture\media\portraits\dome_corner_mask.tga]]
local DOME_CORNER_MASK_RIGHT = [[Interface\AddOns\KullThranUI\Libraries\texture\media\portraits\dome_corner_mask_mirrored.tga]]
-- Native pixel size of both files above (same for both: one is a plain
-- horizontal flip of the other). Used to keep the patch's aspect ratio
-- correct while only one knob (scale) controls its overall size.
local DOME_CORNER_MASK_W, DOME_CORNER_MASK_H = 40, 33

-- Assumed source sheet dimensions, in pixels. See derivation note above.
local PORTRAIT_ART_SHEET_WIDTH = 256
local PORTRAIT_ART_SHEET_HEIGHT = 128

-- Assumed portrait/frame ring crop, in source-sheet pixels, top-left corner.
local PORTRAIT_ART_CROP_W = 58
local PORTRAIT_ART_CROP_H = 58

-- Texture-coordinate rectangle for the portrait/frame ring piece, as a 0..1
-- fraction of the sheet: { left, right, top, bottom }.
local PORTRAIT_ART_TEXCOORD = {
    0,
    PORTRAIT_ART_CROP_W / PORTRAIT_ART_SHEET_WIDTH,
    0,
    PORTRAIT_ART_CROP_H / PORTRAIT_ART_SHEET_HEIGHT,
}

-- Classic's aura row belongs above the opaque stock frame. Keeping this as
-- a separate gap from the Forever name-tab gap makes the intent explicit:
-- the row must clear the top edge of the Classic texture, not sit on top of
-- its name panel.
local CLASSIC_BUFFS_ABOVE_FRAME_GAP = 4

local CLASSIC_FRAME_GEOMETRY = {
    player = {
        w = 232, h = 100,
        -- Keep the stock FrameXML rectangles intact. Enlarging/recentering the
        -- portrait makes its circular texture escape the ornament's aperture.
        art = { l = 1, r = 0.09375, t = 0, b = 0.78125, w = 232, h = 100, x = 0, y = 0 },
        portrait = { point = "TOPLEFT", x = 42, y = -12, size = 64 },
        health = { x = 106, y = 41, w = 119, h = 12 },
        power = { x = 106, y = 52, w = 119, h = 12 },
        name = { point = "CENTER", x = 50, y = 19, w = 100, justify = "CENTER" },
    },
    target = {
        w = 232, h = 100,
        art = { l = 0.09375, r = 1, t = 0, b = 0.78125, w = 232, h = 100, x = 0, y = 0 },
        portrait = { point = "TOPRIGHT", x = -42, y = -12, size = 64 },
        health = { x = 7, y = 41, w = 119, h = 12 },
        power = { x = 7, y = 52, w = 119, h = 12 },
        name = { point = "CENTER", x = -50, y = 19, w = 100, justify = "CENTER" },
    },
}
--- Creates (once, cached on `frame[cacheKey]`) a child frame positioned to
--- fully cover `frame`. Its actual strata/level is resolved by
--- SyncArtLayers from the live Health bar; hardcoded strata are incorrect
--- here because UnitFrames can move the whole tree to another strata.
--- @param frame Frame the unit frame's outer frame (owns the cache)
--- @param cacheKey string the field name this host is cached under on `frame`
--- @return Frame|nil host
local function EnsureArtHost(frame, cacheKey)
    local host = frame[cacheKey]
    if host then return host end

    host = CreateFrame("Frame", nil, frame)
    host:SetAllPoints(frame)
    host:EnableMouse(false)
    host._kuiThemeArtHost = true
    frame[cacheKey] = host
    return host
end

--- Keeps the stock-art stack internally ordered without assuming a global
--- strata or an absolute frame level. The intended order is:
--- portrait -> frame art -> bars -> text. Classic's opaque window frame is
--- the one exception: its art belongs immediately above the bars.
local function SyncArtLayers(frame, host, artAboveBars)
    local health = frame and frame.Health
    if not (health and host) then return end

    local strata = (health.GetFrameStrata and health:GetFrameStrata())
        or (frame.GetFrameStrata and frame:GetFrameStrata())
        or "LOW"
    local healthLevel = (health.GetFrameLevel and health:GetFrameLevel()) or 2
    local power = frame.Power
    local powerLevel = (power and power.GetFrameLevel and power:GetFrameLevel()) or healthLevel
    local topBarLevel = math.max(healthLevel, powerLevel)
    local artLevel = artAboveBars and (topBarLevel + 1) or math.max(0, healthLevel - 1)

    host:SetFrameStrata(strata)
    host:SetFrameLevel(artLevel)

    local portrait = frame.Portrait and frame.Portrait.backdrop
    if portrait then
        portrait:SetFrameStrata(strata)
        portrait:SetFrameLevel(math.max(0, math.min(healthLevel, artLevel) - 1))
    end

    local textOverlay = frame._textOverlay
    if textOverlay then
        textOverlay:SetFrameStrata(strata)
        textOverlay:SetFrameLevel(math.max(topBarLevel + 12, artLevel + 1))
    end
end
-- A font sized for the outer stock box's uniform scale can still be taller
-- than the real bar it sits on: Classic's real health/power bars are only
-- 12px tall (vs Forever's 20px), but both use the same 232x100 outer box, so
-- the same scale factor leaves Classic's text sized for a bar nearly twice
-- as tall as the one it actually renders on, so the text overflows a bar
-- far shorter than it. The value is a first-pass estimate; adjust this
-- single constant if it proves too large or too small.
local STOCK_BAR_TEXT_HEIGHT_RATIO = 0.8
local CLASSIC_BAR_TEXT_HEIGHT_RATIO = 0.65

--- Scales a health/power text FontString's font size by `scale`, from its
--- OWN unscaled base size (cached on the FontString the first time this
--- runs), never from its current size -- reapplying this on every render
--- pass must never compound (shrinking further each time), and the base
--- must survive `scale` changing between calls (e.g. a change in
--- portrait size). Also caps the result to a fraction of the real bar's own
--- pixel height (`maxHeightPx`), when given, so a font sized for the outer
--- box's uniform scale never renders taller than the bar it actually sits
--- on. Nil-safe; does nothing if `fs` has no font set yet.
local function ScaleStockBarText(fs, scale, maxHeightPx, heightRatio, shrinkPx)
    if type(fs) ~= "table" or type(fs.GetFont) ~= "function" or type(fs.SetFont) ~= "function" then return end
    local path, currentSize, flags = fs:GetFont()
    if not path or not currentSize then return end
    local base = fs._ktStockBaseFontSize
    if not base then
        base = currentSize
        fs._ktStockBaseFontSize = base
    end
    local size = base * scale
    if maxHeightPx and maxHeightPx > 0 then
        size = math.min(size, maxHeightPx * (heightRatio or STOCK_BAR_TEXT_HEIGHT_RATIO))
    end
    if shrinkPx and shrinkPx > 0 then size = math.max(6, size - shrinkPx) end
    fs:SetFont(path, size, flags)
    if shrinkPx and shrinkPx > 0 then
        -- Later SetFont calls (settings/font refresh) must not undo the reduction.
        fs._ktStockCastCap = size
        if not fs._ktStockCastCapHook and hooksecurefunc then
            fs._ktStockCastCapHook = true
            hooksecurefunc(fs, "SetFont", function(self, p2, s2, f2)
                local cap = self._ktStockCastCap
                if cap and type(s2) == "number" and s2 > cap and not self._ktStockCastBusy then
                    self._ktStockCastBusy = true
                    self:SetFont(p2, cap, f2)
                    self._ktStockCastBusy = nil
                end
            end)
        end
    elseif fs._ktStockCastCap then
        fs._ktStockCastCap = nil
    end
end

--- Shrinks a FontString's font size further, on top of whatever it already
--- is, only when its CURRENT rendered text actually overflows `maxWidth` --
--- e.g. a long character name that doesn't fit the real name tab's real
--- width even at the theme's normal uniform scale. Never grows text back;
--- a short name at the normal scale is left alone. Nil-safe/no-op if the
--- FontString has no text or font yet, or if it already fits.
local function FitTextToWidth(fs, maxWidth)
    if type(fs) ~= "table" or type(fs.GetStringWidth) ~= "function" then return end
    if type(fs.GetFont) ~= "function" or type(fs.SetFont) ~= "function" then return end
    if not maxWidth or maxWidth <= 0 then return end
    local path, currentSize, flags = fs:GetFont()
    if not path or not currentSize then return end
    -- Cache the ORIGINAL font size once (a separate field from
    -- ScaleStockBarText's own cache, so the two never fight over the same
    -- slot) and always re-measure from THAT size, never from whatever size
    -- the last call left behind -- otherwise repeated calls within the same
    -- refresh (a target change fires this more than once, as in
    -- KUIUnitFrames.lua's equivalent helper) would shrink an
    -- already-shrunk font further each time, never recovering.
    local base = fs._ktForeverFitBaseFontSize
    if not base then
        base = currentSize
        fs._ktForeverFitBaseFontSize = base
    end
    fs:SetFont(path, base, flags)
    local width = fs:GetStringWidth()
    -- A FontString showing text derived from a secure/protected context can
    -- return a tainted "secret" number here; comparing it throws "attempt to
    -- compare ... a secret number value" (the equivalent helper in
    -- KUIUnitFrames.lua threw the same error and broke the addon on enable).
    if type(issecretvalue) == "function" and issecretvalue(width) then return end
    if not width or width <= 0 or width <= maxWidth then return end
    fs:SetFont(path, math.max(6, base * (maxWidth / width)), flags)
end

--- Blizzard's own name text for the stock-art styles: GameFontNormalSmall
--- (sized with the frame art) in Blizzard yellow. Later font or color writes
--- from the generic text pass are held to that look while it is active, but
--- a smaller size (fitting a long name into the tab) is still allowed.
--- Turned off with unitFrames.blizzardNameStyle = false.
function KT.VisualThemes:ApplyBlizzardBarText(fs, scale, maxHeight, fontName)
    if type(fs) ~= "table" or not fs.SetFont then return end
    fs._ktBlizzName = nil
    local path, size, flags = self:GetNativeStockFont(fontName or "TextStatusBarText", "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    size = size * scale
    if maxHeight then size = math.min(size, maxHeight * 0.9) end
    fs._ktBlizzBar = { path = path, size = math.max(6, size), flags = flags }
    if not fs._ktBlizzBarHook and hooksecurefunc then
        fs._ktBlizzBarHook = true
        hooksecurefunc(fs, "SetFont", function(text, p, n, f)
            local style = text._ktBlizzBar
            local vt = KT.VisualThemes
            local theme = vt.GetRenderedTheme and vt:GetRenderedTheme()
            if not style or text._ktBlizzBarBusy or (theme ~= "retail" and theme ~= "forever") then return end
            if p ~= style.path or n ~= style.size or f ~= style.flags then
                text._ktBlizzBarBusy = true
                text:SetFont(style.path, style.size, style.flags)
                text._ktBlizzBarBusy = nil
            end
        end)
    end
    fs:SetFont(path, math.max(6, size), flags)
    if fs.SetTextColor then fs:SetTextColor(1, 1, 1, 1) end
    if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 1) end
    if fs.SetShadowOffset then fs:SetShadowOffset(scale, -scale) end
end

function KT.VisualThemes:ApplyBlizzardNameText(fs, scale, maxWidth)
    if fs then fs._ktBlizzBar = nil end
    if type(fs) ~= "table" or type(fs.SetFont) ~= "function" then return end
    local uf = KT.db and KT.db.profile and KT.db.profile.unitFrames
    if uf and uf.blizzardNameStyle == false then
        if fs._ktBlizzName then
            fs._ktBlizzName = nil
            fs._ktStockBaseFontSize, fs._ktForeverFitBaseFontSize, fs._ktStockFitBaseFontSize = nil, nil, nil
        end
        return
    end
    local path, size, flags = "Fonts\\FRIZQT__.TTF", 10, ""
    local obj = _G.GameFontNormalSmall
    if obj and obj.GetFont then
        local ok, p2, s2, f2 = pcall(obj.GetFont, obj)
        if ok and type(p2) == "string" and type(s2) == "number" and s2 > 0 then
            path, size, flags = p2, s2, f2 or ""
        end
    end
    size = math.max(6, size * ((type(scale) == "number" and scale > 0) and scale or 1))
    fs._ktBlizzName = { path = path, size = size, flags = flags }
    if not fs._ktBlizzNameHooked and hooksecurefunc then
        fs._ktBlizzNameHooked = true
        hooksecurefunc(fs, "SetFont", function(self, p3, s3, f3)
            local b = self._ktBlizzName
            if not b or self._ktBlizzBusy then return end
            local want = (type(s3) == "number" and s3 < b.size) and s3 or b.size
            if p3 ~= b.path or f3 ~= b.flags or s3 ~= want then
                self._ktBlizzBusy = true
                self:SetFont(b.path, want, b.flags)
                self._ktBlizzBusy = nil
            end
        end)
        hooksecurefunc(fs, "SetTextColor", function(self)
            if not self._ktBlizzName or self._ktBlizzBusy then return end
            self._ktBlizzBusy = true
            self:SetTextColor(1, 0.82, 0)
            self._ktBlizzBusy = nil
        end)
    end
    fs._ktBlizzBusy = true
    fs:SetFont(path, size, flags)
    fs:SetTextColor(1, 0.82, 0)
    fs._ktBlizzBusy = nil
    if fs.SetShadowOffset then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    end
    if maxWidth and maxWidth > 0 then
        fs._ktForeverFitBaseFontSize = size
        FitTextToWidth(fs, maxWidth)
    end
end

local function ResolveStockScale(frame, geom)
    local width = frame.GetWidth and frame:GetWidth()
    local height = frame.GetHeight and frame:GetHeight()
    local desiredWidth = width

    -- KUI's attached layout adds the portrait width to the outer frame.
    -- Before the stock pass its aspect ratio therefore differs sharply from
    -- the stock box; in that state the configured Health width is the stable
    -- width control shared by attached, circular and portrait-free presets.
    local health = frame.Health
    local healthWidth = health and health.GetWidth and health:GetWidth()
    local ratio = (width and width > 0 and height) and (height / width) or nil
    local stockRatio = geom.h / geom.w
    if ratio and math.abs(ratio - stockRatio) > 0.05
        and healthWidth and healthWidth > 0 then
        desiredWidth = healthWidth
    end

    return (desiredWidth and desiredWidth > 0) and (desiredWidth / geom.w) or 1
end
--- Sizes and anchors `art` as a SQUARE centered on `unitRegion`, instead of
--- stretching it to whatever rect `unitRegion` happens to have. A portrait
--- ring/frame piece reads as distorted the moment its container isn't
--- exactly square, and `unitRegion` (a real unit frame's portrait container)
--- is not guaranteed to be -- forcing a square derived from its own height
--- (falling back to width if height isn't available) and centering on it is
--- robust regardless of the container's actual shape or any layout timing
--- around when this is first called.
--- @param art Texture the texture to size/anchor
--- @param unitRegion Frame|Region the region to center the square art on
local function SeatSquareArt(art, unitRegion)
    art:ClearAllPoints()
    local size = unitRegion.GetHeight and unitRegion:GetHeight()
    if not size or size <= 0 then
        size = (unitRegion.GetWidth and unitRegion:GetWidth()) or 0
    end
    if size and size > 0 then
        art:SetSize(size, size)
        art:SetPoint("CENTER", unitRegion, "CENTER", 0, 0)
    else
        -- unitRegion has no usable size yet (e.g. not laid out this pass) --
        -- fall back to the previous stretch-to-fill behavior rather than
        -- leaving art with a stale or zero size.
        art:SetAllPoints(unitRegion)
    end
end

local function SeatStockPortrait(unitRegion, frame, portrait, scale, maskExpand)
    unitRegion._ktStockPortraitAnchor = true
    if frame._ktNativeClassificationKind and frame._ktNativeClassificationScale then
        maskExpand = -portrait.size * (1 - frame._ktNativeClassificationScale) / 2
    end
    unitRegion._ktStockPortraitMaskExpand = (maskExpand == nil and 5 or maskExpand) * scale
    if unitRegion._shapeBorderTex then unitRegion._shapeBorderTex:Hide() end
    unitRegion:ClearAllPoints()
    local nativeRaise = frame._ktNativeClassificationKind and portrait.point == "TOPLEFT" and 5 or 0
    local nativeRight = nativeRaise ~= 0 and 3 or 0
    unitRegion:SetPoint(portrait.point, frame, portrait.point,
        (portrait.x + nativeRight) * scale, (portrait.y + nativeRaise) * scale)
    unitRegion:SetSize(portrait.size * scale, portrait.size * scale)
    if frame._ktNativeClassificationKind and unitRegion._3d then
        local nativeScale = frame._ktNativeClassificationScale or 1
        local inset = portrait.size * scale * ((1 - nativeScale) / 2 + 2 / 58 * nativeScale)
        unitRegion._3d:ClearAllPoints()
        unitRegion._3d:SetPoint("TOPLEFT", unitRegion, "TOPLEFT", inset, -inset)
        unitRegion._3d:SetPoint("BOTTOMRIGHT", unitRegion, "BOTTOMRIGHT", -inset, inset)
        unitRegion._ktNativeModelViewport = true
    elseif unitRegion._ktNativeModelViewport and unitRegion._3d then
        unitRegion._ktNativeModelViewport = nil
        unitRegion._3d:ClearAllPoints()
        unitRegion._3d:SetPoint("TOPLEFT", unitRegion, "TOPLEFT", 0, 0)
        unitRegion._3d:SetPoint("BOTTOMRIGHT", unitRegion, "BOTTOMRIGHT", 0, 0)
    end
    if unitRegion._shapeMask then
        local expand = unitRegion._ktStockPortraitMaskExpand
        unitRegion._shapeMask:ClearAllPoints()
        unitRegion._shapeMask:SetPoint("TOPLEFT", unitRegion, "TOPLEFT", -expand, expand)
        unitRegion._shapeMask:SetPoint("BOTTOMRIGHT", unitRegion, "BOTTOMRIGHT", expand, -expand)
    end
end

local function ReleaseStockPortrait(frame)
    local backdrop = frame and frame.Portrait and frame.Portrait.backdrop
    if backdrop then backdrop._ktStockPortraitAnchor = nil end
end

-- Classic's own border/background accent (bronze/gold), matching the same
-- color already used for its unit-frame border (SetUnitBorderColor in
-- Adapters/UnitFrames.lua). Without it the cast bar would use a
-- generic black border/background shared with every other theme.
local CLASSIC_CASTBAR_BORDER = { r = 0.92, g = 0.72, b = 0.22, a = 1 }
local CLASSIC_CASTBAR_BG = { r = 0.20, g = 0.14, b = 0.04, a = 0.6 }

--- Widens/narrows the player/target cast bar's own background frame
--- (CreateCastBar in KUIUnitFrames.lua returns the StatusBar; its parent is
--- the actual sized/anchored background) to match the real stock Power
--- bar's width AND position. CreateCastBar's own anchor
--- (`SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", -healthOff, 0)`, where
--- healthOff = frame.Health._xOffset) was written for KUI's generic
--- attached-portrait layout, where _xOffset compensates for the portrait
--- eating into the frame's width -- it does NOT keep the left edges
--- aligned under real stock geometry, where _xOffset instead means the
--- health bar's own real offset within the box, so the generic anchor left
--- both dimensions AND position wrong for player and target under Classic.
--- Re-anchoring fresh, directly below Power with no
--- extra offset, sidesteps that mismatch entirely. Also gives Classic its
--- own bronze border/background instead of the generic black one shared
--- with every other theme, restoring the plain
--- black look if the frame later switches to a different theme.
--- @param frame Frame the unit frame's outer frame
--- @param geom table this unit's FOREVER_FRAME_GEOMETRY/CLASSIC_FRAME_GEOMETRY entry
--- @param scale number the resolved stock box scale
local function SeatStockCastbar(frame, geom, scale)
    local castbar = frame.Castbar
    local bg = castbar and castbar.GetParent and castbar:GetParent()
    if not (bg and bg.SetWidth and bg.SetPoint and geom.power) then return end
    if frame.Power then
        bg:ClearAllPoints()
        bg:SetPoint("TOPLEFT", frame.Power, "BOTTOMLEFT", 0, 0)
    end
    bg:SetWidth(geom.power.w * scale)
    -- KUI's generic castbarHeight (14+) is disproportionate against the real
    -- stock box's much slimmer bars (the cast bar reads as too thick and
    -- clipped). Matched to Power's own real height for the same slender
    -- proportions.
    if bg.SetHeight and geom.power.h then
        bg:SetHeight(geom.power.h * scale)
    end

    local isClassic = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme() == "classic"
    if isClassic then
        if bg._bgTex then bg._bgTex:SetColorTexture(
            CLASSIC_CASTBAR_BG.r, CLASSIC_CASTBAR_BG.g, CLASSIC_CASTBAR_BG.b, CLASSIC_CASTBAR_BG.a) end
        if bg._ppBorders then
            for i = 1, #bg._ppBorders do
                bg._ppBorders[i]:SetColorTexture(
                    CLASSIC_CASTBAR_BORDER.r, CLASSIC_CASTBAR_BORDER.g, CLASSIC_CASTBAR_BORDER.b, CLASSIC_CASTBAR_BORDER.a)
            end
            bg._ppBorderColor = CLASSIC_CASTBAR_BORDER
        end
    elseif bg._ktCastbarThemed then
        -- Switched away from Classic after having themed it -- restore the
        -- generic black look so a later theme switch doesn't leave the
        -- bronze accent behind.
        if bg._bgTex then bg._bgTex:SetColorTexture(0, 0, 0, 0.5) end
        if bg._ppBorders then
            for i = 1, #bg._ppBorders do
                bg._ppBorders[i]:SetColorTexture(0, 0, 0, 1)
            end
            bg._ppBorderColor = { r = 0, g = 0, b = 0, a = 1 }
        end
    end
    bg._ktCastbarThemed = isClassic or nil

    -- Castbar.Text/.Time use a flat, unscaled font size from settings
    -- (KUIUnitFrames.lua's castSpellNameSize/castDurationSize, default 11)
    -- with no awareness of the real stock bar's actual height set just
    -- above -- exactly the same "font sized for the outer box, not the real
    -- slim bar" problem ScaleStockBarText already solves for health/power
    -- text. With the bar genuinely thin, the untouched text would overflow and
    -- clip against it, so cap it the same way.
    local cbHeight = bg.GetHeight and bg:GetHeight()
    if castbar and cbHeight and cbHeight > 0 then
        local ratio = isClassic and CLASSIC_BAR_TEXT_HEIGHT_RATIO or STOCK_BAR_TEXT_HEIGHT_RATIO
        -- Forever/Retail: spell name and timer read too big, so they are 2px smaller.
        local shrink = (not isClassic) and 2 or nil
        ScaleStockBarText(castbar.Text, scale, cbHeight, ratio, shrink)
        ScaleStockBarText(castbar.Time, scale, cbHeight, ratio, shrink)
    end
end
-- circle_mask.tga's painted circle only fills the inner ~94px of its 128px
-- canvas (17px of transparent padding per edge -- the same real value this
-- addon already relies on via KUIUnitFrames.lua's MASK_INSETS.circle). A
-- mask SetAllPoints'd directly to its target therefore crops the visible
-- circle to ~73% of the target's own size, leaving a real on-screen gap
-- between the portrait photo and whatever ring art frames it. Expanding the
-- mask itself (never the portrait content, which must stay exactly sized to
-- the stock ring's real aperture) by this ratio makes the mask's PAINTED
-- circle land exactly on the target's bounds instead.
-- 17/94 is exact only for a perfectly circular aperture. A radial pixel scan
-- around the full ring shows that Classic's real
-- UI-TargetingFrame aperture isn't perfectly round -- a thin background
-- crescent remained in the lower-right quadrant specifically, the same kind
-- of hand-painted irregularity that already forced Forever's dome ring into
-- its own corner patch, and that already forced the Options live-preview's
-- copy of this same fix from the theoretical 1.2308 up to 1.55. The ring art
-- is drawn ON TOP of this portrait (SyncArtLayers keeps the portrait below
-- both the ring and the bars), so over-expanding here is safe: any overshoot
-- past the ring's real opaque paint is simply clipped by that opaque paint,
-- it can never show as an escaping/misaligned portrait. Matching that same
-- proven 1.55 total scale here instead of re-deriving a new one.
local PORTRAIT_MASK_EXPAND_RATIO = 0.275

local function ExpandMaskToCompensatePadding(mask, target)
    mask:ClearAllPoints()
    local w, h = target:GetWidth(), target:GetHeight()
    if w and w > 0 and h and h > 0 then
        local expandX = w * PORTRAIT_MASK_EXPAND_RATIO
        local expandY = h * PORTRAIT_MASK_EXPAND_RATIO
        mask:SetPoint("TOPLEFT", target, "TOPLEFT", -expandX, expandY)
        mask:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", expandX, -expandY)
    else
        -- Target has no usable size yet (not laid out this pass) -- fall
        -- back to an exact fit rather than a zero/degenerate mask.
        mask:SetAllPoints(target)
    end
end

--- Creates (once, cached on `host[cacheKey]`) a circular mask matching
--- PORTRAIT_MASK_TEXTURE and applies it to `art`, then keeps the mask
--- anchored to `art`'s current rect, expanded to compensate for the mask
--- texture's own real padding (SetPoint tracks `art` live, so this is safe
--- to call every refresh even after SeatSquareArt resizes `art`).
--- @param art Texture the texture to mask circular
--- @param host Frame the frame the mask texture is created on
--- @param cacheKey string the field name this mask is cached under on `host`
local function ApplyCircleMask(art, host, cacheKey)
    local mask = host[cacheKey]
    if not mask then
        mask = host:CreateMaskTexture()
        mask:SetTexture(PORTRAIT_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        host[cacheKey] = mask
        art:AddMaskTexture(mask)
    end
    ExpandMaskToCompensatePadding(mask, art)
end

local function ApplyClassicRoundPortraitMask(backdrop)
    if not (backdrop and backdrop.CreateMaskTexture) then return end

    local mask = backdrop._ktClassicRoundMask
    if not mask then
        mask = backdrop:CreateMaskTexture()
        backdrop._ktClassicRoundMask = mask
    end
    mask:SetTexture(PORTRAIT_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ExpandMaskToCompensatePadding(mask, backdrop)
    mask:Show()

    -- backdrop._bg is a flat near-black fallback fill normally anchored
    -- exactly to backdrop's own bounds (zero expansion). _2d/_class must
    -- stay exactly at backdrop's real stock-geometry bounds -- enlarging
    -- those risks the portrait photo escaping the ring's real aperture
    -- (see CLASSIC_FRAME_GEOMETRY's own warning on this). That left the
    -- mask's expanded ring with nothing behind it: _bg itself never
    -- reached that far, so the ring's real aperture leaked straight
    -- through to the world background instead of to a dark fallback --
    -- (a visible sky-colored gap, not black).
    -- Expanding only _bg (never the photo) to match the mask backs that
    -- ring with the same dark fill already used elsewhere, instead of
    -- leaving it as a hole.
    if backdrop._bg then
        ExpandMaskToCompensatePadding(backdrop._bg, backdrop)
    end

    for _, tex in ipairs({ backdrop._2d, backdrop._class, backdrop._bg }) do
        if tex and tex.AddMaskTexture then
            if tex.RemoveMaskTexture then
                pcall(tex.RemoveMaskTexture, tex, mask)
            end
            pcall(tex.AddMaskTexture, tex, mask)
        end
    end
    if backdrop.SetClipsChildren then
        backdrop:SetClipsChildren(true)
    end
end

local function ClearClassicRoundPortraitMask(frame)
    local backdrop = frame and frame.Portrait and frame.Portrait.backdrop
    local mask = backdrop and backdrop._ktClassicRoundMask
    if not mask then return end
    for _, tex in ipairs({ backdrop._2d, backdrop._class, backdrop._bg }) do
        if tex and tex.RemoveMaskTexture then
            pcall(tex.RemoveMaskTexture, tex, mask)
        end
    end
    mask:Hide()
end
-- Classic's real UI-TargetingFrame aperture is wider than the 64px stock
-- portrait square. The portrait backdrop clips its own regions to that
-- square (SetClipsChildren, needed for druid forms / model swaps), so the
-- earlier "expand _bg" fix could never reach past it, and a thin see-through
-- crescent remained between the ring art and
-- the photo. This dedicated, unclipped filler frame sits one level BELOW
-- the portrait backdrop (and therefore below the ring art too) and paints a
-- dark disc slightly larger than the portrait, filling that gap. Any
-- overshoot is hidden by the ring's opaque paint drawn on top.
-- Per-side padding in native 232x100 units; tune here if QA finds the disc
-- peeking outside the ring (too big) or the gap still visible (too small).
local CLASSIC_PORTRAIT_FILL_PAD = 3
-- circle_mask.tga paints its circle in the inner 94px of a 128px canvas.
local CIRCLE_MASK_PAD_RATIO = 17 / 94

local function SyncClassicPortraitFill(frame, unitRegion, scale, innerSide)
    if not (frame and unitRegion and CreateFrame) then return end
    local fill = frame._ktClassicPortraitFill
    if not fill then
        fill = CreateFrame("Frame", nil, frame)
        fill:EnableMouse(false)
        local tex = fill:CreateTexture(nil, "BACKGROUND")
        tex:SetAllPoints(fill)
        tex:SetColorTexture(0.1, 0.1, 0.1, 1)
        fill._tex = tex
        if fill.CreateMaskTexture then
            local mask = fill:CreateMaskTexture()
            mask:SetTexture(PORTRAIT_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            fill._mask = mask
            pcall(tex.AddMaskTexture, tex, mask)
        end
        frame._ktClassicPortraitFill = fill
        if unitRegion.HookScript and not unitRegion._ktClassicFillHooked then
            unitRegion._ktClassicFillHooked = true
            unitRegion:HookScript("OnShow", function()
                local f = frame._ktClassicPortraitFill
                if f and frame._ktClassicFillActive then f:Show() end
            end)
            unitRegion:HookScript("OnHide", function()
                local f = frame._ktClassicPortraitFill
                if f then f:Hide() end
            end)
        end
    end

    -- The real aperture is not centred on the portrait square: the gap is on
    -- the bottom and on the side facing the bars (player: right, target:
    -- left); the top/outer sides already reach the ring, and padding them
    -- made the dark disc poke out past the ring's outer edge.
    -- Pad only the bottom and the inner side.
    local pad = (innerSide and CLASSIC_PORTRAIT_FILL_PAD or 0) * (scale or 1)
    local padL = (innerSide == "left") and pad or 0
    local padR = (innerSide == "right") and pad or 0
    local padB = pad
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", unitRegion, "TOPLEFT", -padL, 0)
    fill:SetPoint("BOTTOMRIGHT", unitRegion, "BOTTOMRIGHT", padR, -padB)

    if fill._mask then
        local w = (unitRegion.GetWidth and unitRegion:GetWidth() or 0) + padL + padR
        local h = (unitRegion.GetHeight and unitRegion:GetHeight() or 0) + padB
        local ex, ey = w * CIRCLE_MASK_PAD_RATIO, h * CIRCLE_MASK_PAD_RATIO
        fill._mask:ClearAllPoints()
        fill._mask:SetPoint("TOPLEFT", fill, "TOPLEFT", -ex, ey)
        fill._mask:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", ex, -ey)
    end

    local strata = (unitRegion.GetFrameStrata and unitRegion:GetFrameStrata()) or "LOW"
    local level = (unitRegion.GetFrameLevel and unitRegion:GetFrameLevel()) or 1
    fill:SetFrameStrata(strata)
    fill:SetFrameLevel(math.max(0, level - 1))

    frame._ktClassicFillActive = true
    if unitRegion.IsShown and not unitRegion:IsShown() then
        fill:Hide()
    else
        fill:Show()
    end
end

local function ClearClassicPortraitFill(frame)
    if not frame then return end
    frame._ktClassicFillActive = nil
    local fill = frame._ktClassicPortraitFill
    if fill then fill:Hide() end
end
--- Applies the Classic theme's verified player/target stock box from the
--- real UI-TargetingFrame sheet. The outer box, portrait, health, power and
--- name all share one uniform scale; KUI keeps ownership of bar fills and
--- gameplay behavior. Units without verified full geometry retain the older
--- portrait-only fallback.
--- @param frame Frame the unit frame's outer frame
--- @param unitRegion Frame|Region the portrait region
--- @param unit string|nil unit key
function KT.VisualThemes:ApplyClassicUnitFrameArt(frame, unitRegion, unit)
    if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then return end
    if type(unitRegion) ~= "table" then return end

    local host = EnsureArtHost(frame, "_ktClassicArtHost")
    if not host then return end

    local geom = unit and CLASSIC_FRAME_GEOMETRY[unit]
    if not geom then
        -- Verified full-frame geometry currently exists only for player and
        -- target. Other units keep the earlier portrait-only fallback.
        SyncArtLayers(frame, host, true)
        local art = frame._ktClassicPortraitArt
        if not art then
            art = host:CreateTexture(nil, "OVERLAY")
            art:SetTexture(frame._ktClassicSheetPath or PORTRAIT_FRAME_TEXTURE)
            art:SetTexCoord(PORTRAIT_ART_TEXCOORD[1], PORTRAIT_ART_TEXCOORD[2], PORTRAIT_ART_TEXCOORD[3], PORTRAIT_ART_TEXCOORD[4])
            frame._ktClassicPortraitArt = art
        end
        SeatSquareArt(art, unitRegion)
        ApplyClassicRoundPortraitMask(unitRegion)
        ApplyCircleMask(art, host, "_ktClassicPortraitMask")
        SyncClassicPortraitFill(frame, unitRegion, 1, nil)
        art:Show()
        return
    end

    -- Classic uses the native 232x100 sheet coordinates. Keep the art,
    -- portrait and empty level ornament on that exact coordinate system;
    -- global frame scaling is applied by UnitFrames separately.
    local scale = 1
    local nativePlayer = unit == "player" and frame._ktNativeClassificationKind ~= nil
    local portraitExtension = 0
    if nativePlayer then
        local radius = geom.portrait.size / 2 * (frame._ktNativeClassificationScale or 1)
        local centreX = geom.portrait.x + geom.portrait.size / 2 + 3
        local centreY = -geom.portrait.y + geom.portrait.size / 2 - 5
        local dy = geom.power.y + geom.power.h - centreY
        local reach = math.sqrt(math.max(0, radius * radius - dy * dy))
        portraitExtension = math.max(0, geom.power.x - centreX - reach + 2)
    end

    frame:SetSize(geom.w * scale, geom.h * scale)
    SyncArtLayers(frame, host, true)

    local art = frame._ktClassicPortraitArt
    if not art then
        art = host:CreateTexture(nil, "BACKGROUND")
        frame._ktClassicPortraitArt = art
    end
    local artGeom = geom.art
    art._ktGlowTextureFile = frame._ktClassicSheetPath or PORTRAIT_FRAME_TEXTURE
    art:SetTexture(art._ktGlowTextureFile)
    art:SetTexCoord(artGeom.l, artGeom.r, artGeom.t, artGeom.b)
    art:ClearAllPoints()
    art:SetPoint("CENTER", frame, "CENTER", artGeom.x * scale, artGeom.y * scale)
    art:SetSize(artGeom.w * scale, artGeom.h * scale)
    if nativePlayer then
        -- The Classic sheet includes its portrait ring. Retain only its
        -- bar/name fragment so no second ring shows behind the dragon.
        local crop = geom.health.x / artGeom.w
        art:SetTexCoord(artGeom.l + (artGeom.r - artGeom.l) * crop,
            artGeom.r, artGeom.t, artGeom.b)
        art:ClearAllPoints()
        art:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        art:SetSize((artGeom.w - geom.health.x + portraitExtension) * scale, artGeom.h * scale)
        -- Keep this opaque bar fragment out of the portrait, regardless of
        -- later frame-level refreshes. Clip at the original bar boundary.
        local clip = frame._ktClassicNativeBarClip
        if not clip then
            clip = CreateFrame("Frame", nil, host)
            clip:SetClipsChildren(true)
            frame._ktClassicNativeBarClip = clip
        end
        clip:SetFrameStrata(host:GetFrameStrata())
        clip:SetFrameLevel(host:GetFrameLevel())
        clip:ClearAllPoints()
        clip:SetPoint("TOPLEFT", frame, "TOPLEFT", geom.health.x * scale, 0)
        clip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        art:SetParent(clip)
        clip:Show()
    else
        art:SetParent(host)
        if frame._ktClassicNativeBarClip then frame._ktClassicNativeBarClip:Hide() end
    end
    art:Show()

    local portrait = geom.portrait
    SeatStockPortrait(unitRegion, frame, portrait, scale, 0)
    -- The stock portrait is already circularly masked by KUI. Classic's
    -- frame art is opaque around that opening, so keep the portrait region
    -- clipped even after a unit changes model/shape (notably druid forms).
    -- Classification rings are re-enabled deliberately by the metadata pass
    -- when they need to extend outside this region.
    if nativePlayer then
        ClearClassicRoundPortraitMask(frame)
        ClearClassicPortraitFill(frame)
        if unitRegion._shapeMask then
            unitRegion._shapeMask:SetAtlas("CircleMask", false)
            unitRegion._shapeMask:SetTexCoord(0, 1, 0, 1)
            unitRegion._shapeMask:Show()
            for _, key in ipairs({"_2d", "_class", "_bg"}) do
                local region = unitRegion[key]
                if region and region.AddMaskTexture then
                    if region.RemoveMaskTexture then region:RemoveMaskTexture(unitRegion._shapeMask) end
                    region:AddMaskTexture(unitRegion._shapeMask)
                end
            end
        end
        local topBarLevel = math.max(frame.Health and frame.Health:GetFrameLevel() or 0,
            frame.Power and frame.Power:GetFrameLevel() or 0)
        unitRegion:SetFrameLevel(topBarLevel + 2)
        if unitRegion._3d then unitRegion._3d:SetFrameLevel(topBarLevel + 3) end
    else
        ApplyClassicRoundPortraitMask(unitRegion)
        SyncClassicPortraitFill(frame, unitRegion, scale,
            (portrait.point == "TOPRIGHT") and "left" or "right")
    end

    local health = frame.Health
    if health then
        health:ClearAllPoints()
        health:SetPoint("TOPLEFT", frame, "TOPLEFT",
            (geom.health.x - portraitExtension) * scale, -geom.health.y * scale)
        health:SetSize((geom.health.w + portraitExtension) * scale, geom.health.h * scale)
        health._xOffset = (geom.health.x - portraitExtension) * scale
        health._rightInset = (geom.w - geom.health.x - geom.health.w) * scale
        health._topOffset = geom.health.y * scale
        local absorb = frame.HealthPrediction and frame.HealthPrediction.damageAbsorb
        if absorb and absorb.SetSize then
            absorb:SetSize((geom.health.w + portraitExtension) * scale, geom.health.h * scale)
        end
    end

    local power = frame.Power
    if power then
        power:ClearAllPoints()
        power:SetPoint("TOPLEFT", frame, "TOPLEFT",
            (geom.power.x - portraitExtension) * scale, -geom.power.y * scale)
        power:SetSize((geom.power.w + portraitExtension) * scale, geom.power.h * scale)
    end

    SeatStockCastbar(frame, geom, scale)

    -- Whichever FontString actually holds "name" content is a per-profile
    -- choice resolved by KUIUnitFrames.lua (which has access to `settings`)
    -- and handed over via frame._ktStockNameText -- falling back to
    -- frame.LeftText, KUI's own default assignment, when that isn't set
    -- (e.g. in the test harness, or before KUIUnitFrames.lua resolves it).
    local nameText = frame._ktStockNameText or frame.LeftText
    if nameText and geom.name then
        -- frame.Health has SetClipsChildren(true) (CreateAbsorbBar, so the
        -- absorb shield never overflows the bar) -- nameText's own parent
        -- chain (frame.LeftText -> _textOverlay -> frame.Health) inherits
        -- that clip. Positioning it in the real name tab, ABOVE Health's own
        -- rectangle, put it outside that clip region: the FontString's own
        -- position/size/text were all correct, but it was
        -- simply invisible. Name text needs to anchor directly to the
        -- frame, never inside any bar-clipping container. Reparenting onto
        -- `host` (already correctly leveled by SyncArtLayers, and never
        -- clipped) escapes Health's clip without losing proper stacking.
        if nameText.SetParent then nameText:SetParent(host) end
        nameText:ClearAllPoints()
        nameText:SetPoint(geom.name.point, frame, geom.name.point,
            geom.name.x * scale, geom.name.y * scale)
        if nameText.SetWidth then nameText:SetWidth(geom.name.w * scale) end
        if nameText.SetJustifyH then nameText:SetJustifyH(geom.name.justify) end
    end

    local barTextMaxHeight = geom.health.h * scale
    ScaleStockBarText(frame.LeftText, scale, barTextMaxHeight, CLASSIC_BAR_TEXT_HEIGHT_RATIO)
    ScaleStockBarText(frame.RightText, scale, barTextMaxHeight, CLASSIC_BAR_TEXT_HEIGHT_RATIO)
    ScaleStockBarText(frame.CenterText, scale, barTextMaxHeight, CLASSIC_BAR_TEXT_HEIGHT_RATIO)
    if nameText and geom.name then
        self:ApplyBlizzardNameText(nameText, scale, geom.name.w * scale)
    end

    -- Classic's name tab is part of the opaque texture. Its buffs therefore
    -- need their own row above the whole stock frame; the normal aura refresh
    -- (which is relative to Health/frame) would otherwise put them over the
    -- name tab. Align the row with the real name tab and mirror the x origin
    -- for the target frame.
    local buffs = frame.Buffs
    if type(buffs) == "table" and buffs.ClearAllPoints and geom.name then
        local tabWidth = geom.name.w * scale
        local iconSize = buffs.size or (buffs.GetHeight and buffs:GetHeight()) or (geom.health.h * scale)
        iconSize = math.max(8, iconSize)
        local gap = buffs.spacing or 1
        -- geom.name.x is relative to the frame centre, while this anchor is
        -- relative to TOPLEFT. Convert between both coordinate spaces.
        local tabLeft = (geom.w * 0.5) + geom.name.x - (geom.name.w * 0.5)
        buffs:ClearAllPoints()
        buffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT",
            tabLeft * scale, CLASSIC_BUFFS_ABOVE_FRAME_GAP * scale)
        buffs:SetSize(tabWidth, iconSize)
        buffs.size = iconSize
        buffs.spacing = gap
        buffs["size-x"] = math.max(1, math.floor((tabWidth + gap) / (iconSize + gap)))
        if buffs.ForceUpdate then buffs:ForceUpdate() end
        -- Height of the aura row above the frame's top edge: KUI Tracker bars
        -- anchored above the player frame read this to stack over the buffs.
        frame._ktAuraRowLift = (CLASSIC_BUFFS_ABOVE_FRAME_GAP + iconSize) * scale
    else
        frame._ktAuraRowLift = nil
    end
    frame._ktClassicLayoutActive = true
    return true
end
--- Hides (does not destroy) the Classic portrait/frame art created by
--- ApplyClassicUnitFrameArt, if any. Nil-safe if it was never created.
--- @param frame Frame|Region the unit frame passed to ApplyClassicUnitFrameArt
function KT.VisualThemes:ClearClassicUnitFrameArt(frame)
    if type(frame) ~= "table" then return end
    local art = frame._ktClassicPortraitArt
    if art then
        art:Hide()
    end
    ClearClassicRoundPortraitMask(frame)
    ClearClassicPortraitFill(frame)
    ReleaseStockPortrait(frame)
    frame._ktClassicLayoutActive = nil
    frame._ktAuraRowLift = nil
end

--[[
    Forever stock UnitFrame art.

    The atlas is the visible artwork inside a 232x100 layout box; it is not
    itself the box. Player and target use fixed portrait, health, power and
    name rectangles in that coordinate space. One uniform scale is applied
    to all of them, the real atlas is centred at its native visible size, and
    the stock masks shape KUI's existing bar textures without replacing their
    colors or fills.

    Only player and target have verified geometry. Other units deliberately
    keep KUI's normal rendering instead of receiving guessed artwork.
]]

local FOREVER_FRAME_GEOMETRY = {
    player = {
        w = 232, h = 100,
        art = "UI-HUD-UnitFrame-Player-PortraitOn",
        portrait = { point = "TOPLEFT", x = 24, y = -19, size = 60 },
        health = {
            x = 85, y = 40, w = 124, h = 20,
            mask = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Mask",
            mx = -2, my = 6,
        },
        power = {
            x = 85, y = 61, w = 124, h = 10,
            mask = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Mask",
            mx = -2, my = 2,
        },
        name = { x = 88, y = -27, w = 96, h = 14 },
    },
    target = {
        w = 232, h = 100,
        -- Target's own real atlas (UI-HUD-UnitFrame-Target-PortraitOn, 192x67)
        -- genuinely lacks a decorative corner point that player's (198x71) has;
        -- this is a property of the art, not a code bug, and both atlases are
        -- drawn full/unmodified. Reusing player's own atlas, mirrored,
        -- guarantees the identical ring art. Mirroring target's OWN atlas does not
        -- work, since that asset is already correctly oriented for its own use.
        -- Player's atlas was not designed to be mirrored either, so this remains an
        -- experimental approach that needs visual verification.
        art = "UI-HUD-UnitFrame-Player-PortraitOn",
        mirror = true,
        -- Every offset below is the exact horizontal mirror of player's own
        -- (x -> w - x - elementWidth, TOPLEFT anchor kept throughout so the
        -- anchor math stays identical between units); y/w/h are unchanged
        -- from player since the box is only flipped horizontally. Bar masks
        -- reuse player's own mask names too, on the assumption a bar-track
        -- mask is left-right symmetric -- unverified without a client.
        portrait = { point = "TOPRIGHT", x = -24, y = -19, size = 60 },
        health = {
            x = 23, y = 40, w = 124, h = 20,
            mask = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Health-Mask",
            mx = -2, my = 6,
        },
        power = {
            x = 23, y = 61, w = 124, h = 10,
            mask = "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Mask",
            mx = -2, my = 2,
        },
        name = { x = 48, y = -27, w = 96, h = 14 },
    },
}

-- Retail's target portrait is player's own real atlas, mirrored -- not a
-- separate target-native atlas. Target's own real atlas genuinely lacks the
-- decorative ring point (see FOREVER_FRAME_GEOMETRY.target's comment), and
-- the separate "-Type" reputation-strip atlas this used to layer on top
-- was never verified against a real client and drew a yellow/gold-tinted
-- patch over the portrait (a plain gold circle with no ring). Retail target
-- now reuses FOREVER_FRAME_GEOMETRY.target as-is (mirror=true, player's
-- atlas name); ResolveRetailAtlasOverride substitutes the real gold Retail
-- pixels for that same atlas name, already proven working for player.

-- Buffs and the name tab would otherwise share the exact same Y (buffs grow
-- up from the tab's top edge, name grows down from it), leaving zero margin
-- -- icon borders/glow and text ascenders overlap a little on both units.
-- A first-pass estimate; adjust this single constant if it proves too
-- large or too small.
local BUFFS_TAB_GAP = 3

local function UnsnapTexture(texture)
    if not texture then return end
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
end

local function SeatMaskOnTexture(texture, mask)
    if not (texture and mask and texture.AddMaskTexture) then return end
    if texture.RemoveMaskTexture then
        pcall(texture.RemoveMaskTexture, texture, mask)
    end
    texture:AddMaskTexture(mask)
end



local function ApplyForeverBarMask(bar, geom, scale, portraitExtension, dropOnExtension)
    if not (bar and geom and geom.mask and C_Texture and C_Texture.GetAtlasInfo) then return end
    -- Power bar with a Rare/Elite ring: the stock Mana mask has a transparent left
    -- section (that part is tucked under the stock ring), so once the base art is hidden
    -- the bar showed only a thin sliver at its far left and a gap after it. Drop the
    -- mask for this case and let the bar be a plain rectangle.
    if dropOnExtension and portraitExtension and portraitExtension ~= 0 then
        local m = bar._ktForeverMask
        if m then
            local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
            if fill and fill.RemoveMaskTexture then pcall(fill.RemoveMaskTexture, fill, m) end
            if bar.bg and bar.bg.RemoveMaskTexture then pcall(bar.bg.RemoveMaskTexture, bar.bg, m) end
            m:Hide()
        end
        return
    end
    local info = C_Texture.GetAtlasInfo(geom.mask)
    if not info then
        -- Same late-binding GetAtlasInfo problem as
        -- ApplyForeverUnitFrameArt: nil very early after login, valid
        -- moments later. Retry instead of leaving the bar unmasked until
        -- the next manual /reload.
        local retries = bar._ktForeverMaskRetries or 0
        if retries < 3 and type(C_Timer) == "table" and C_Timer.After then
            bar._ktForeverMaskRetries = retries + 1
            local delay = ({ 0.2, 0.5, 1.5 })[retries + 1] or 1.5
            C_Timer.After(delay, function()
                ApplyForeverBarMask(bar, geom, scale, portraitExtension)
            end)
        end
        return
    end
    bar._ktForeverMaskRetries = nil

    local mask = bar._ktForeverMask
    if not mask then
        mask = bar:CreateMaskTexture()
        bar._ktForeverMask = mask
    end
    mask:SetAtlas(geom.mask, true)
    mask:Show()
    UnsnapTexture(mask)
    mask:ClearAllPoints()
    mask:SetPoint("TOPLEFT", bar, "TOPLEFT", (geom.mx or 0) * scale, (geom.my or 0) * scale)
    if info.width and info.height then
        -- Rare/Elite portrait rings extend Health/Power only toward the
        -- portrait. Widen the stock mask by the same amount or the new part
        -- of the StatusBar remains clipped and the visual gap survives.
        mask:SetSize(info.width * scale + (portraitExtension or 0), info.height * scale)
    end

    SeatMaskOnTexture(bar.GetStatusBarTexture and bar:GetStatusBarTexture(), mask)
    SeatMaskOnTexture(bar.bg, mask)
end

local function ResizeHealthPrediction(frame, width, height)
    local absorb = frame.HealthPrediction and frame.HealthPrediction.damageAbsorb
    if not absorb then return end
    if absorb.SetSize then absorb:SetSize(width, height) end
    local mask = frame.Health and frame.Health._ktForeverMask
    if mask and absorb.GetStatusBarTexture then
        SeatMaskOnTexture(absorb:GetStatusBarTexture(), mask)
    end
end
-- Real Retail unit-frame art, resolved independently of C_Texture.GetAtlasInfo.
-- A Forever-flavored client remaps this
-- atlas name to its own bronze sheet -- GetAtlasInfo/SetAtlas on such a
-- client return Forever's bronze file regardless of which visual theme is
-- selected in the addon. Genuine gold Retail art needs
-- the real sheet file and pixel sub-rect instead, sourced directly from
-- Blizzard's own retail texture sheets (facts about the game client, not
-- any third party's material): file ID, full sheet pixel dimensions, and
-- the region's pixel rect within that sheet.
-- Optional explicit width/height override the DISPLAYED atlas size when it
-- differs from the raw pixel rect's own span (Blizzard pads some of these
-- sheet regions with extra transparent margin around the actual art).
local RETAIL_ATLAS_OVERRIDES = {
    ["ui-hud-unitframe-player-portraiton"] = {
        file = 4631591, sheetW = 1024, sheetH = 512,
        left = 1, right = 199, top = 87, bottom = 158,
    },
    ["ui-hud-unitframe-target-portraiton"] = {
        file = 4631591, sheetW = 1024, sheetH = 512,
        left = 1, right = 193, top = 229, bottom = 296,
    },
    ["ui-hud-actionbar-iconframe"] = {
        file = 4613342, sheetW = 256, sheetH = 1024,
        left = 181, right = 227, top = 254, bottom = 299,
    },
    ["ui-hud-actionbar-iconframe-addrow"] = {
        file = 4613342, sheetW = 256, sheetH = 1024,
        left = 181, right = 232, top = 305, bottom = 356,
    },
    ["ui-hud-actionbar-iconframe-slot"] = {
        file = 4613342, sheetW = 256, sheetH = 1024,
        left = 181, right = 245, top = 136, bottom = 198,
        width = 45, height = 45,
    },
    ["ui-hud-actionbar-iconframe-down"] = {
        file = 4613342, sheetW = 256, sheetH = 1024,
        left = 181, right = 227, top = 521, bottom = 566,
    },
    ["ui-hud-actionbar-gryphon-left"] = {
        file = 4613342, sheetW = 256, sheetH = 1024,
        left = 1, right = 179, top = 136, bottom = 303,
        width = 100, height = 94,
    },
    ["ui-hud-actionbar-gryphon-right"] = {
        file = 4613342, sheetW = 256, sheetH = 1024,
        left = 1, right = 179, top = 305, bottom = 472,
        width = 100, height = 94,
    },
    ["ui-hud-actionbar-wyvern-left"] = {
        file = 4613342, sheetW = 256, sheetH = 1024,
        left = 1, right = 179, top = 474, bottom = 641,
        width = 100, height = 94,
    },
    ["ui-hud-actionbar-wyvern-right"] = {
        file = 4613342, sheetW = 256, sheetH = 1024,
        left = 1, right = 179, top = 643, bottom = 810,
        width = 100, height = 94,
    },
}

local RETAIL_PLAYER_PORTRAIT_MASK = "UI-HUD-UnitFrame-Player-Portrait-Mask"

--- Applies player's real, unmirrored Retail portrait cutout to KUI's
--- existing portrait mask (its squared lower-right opening). Target reuses
--- the plain round mask instead -- never flip a MaskTexture: inverted
--- coordinates clip the portrait fully.
--- @param shapeMask MaskTexture
--- @param atlasName string
--- @return boolean applied
local function ApplyRetailStockPortraitMask(shapeMask, atlasName)
    if not (shapeMask and atlasName and C_Texture and C_Texture.GetAtlasInfo) then return false end
    local info = C_Texture.GetAtlasInfo(atlasName)
    if not info then return false end

    local file = info.file or info.filename
    if file and info.leftTexCoord and info.rightTexCoord
        and info.topTexCoord and info.bottomTexCoord
    then
        shapeMask:SetTexture(file, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        shapeMask:SetTexCoord(
            info.leftTexCoord, info.rightTexCoord,
            info.topTexCoord, info.bottomTexCoord)
        return true
    end

    -- Both masks are unmirrored, so the atlas path is a safe fallback when
    -- this client does not expose its backing sheet coordinates.
    if shapeMask.SetAtlas then
        shapeMask:SetAtlas(atlasName, false)
        return true
    end
    return false
end

--- Resolves an atlas name to real Retail pixel data when (and only when)
--- the Retail visual theme is active on a Forever-flavored client -- on a
--- genuine Retail client this returns nil unconditionally and callers fall
--- through to the normal GetAtlasInfo/SetAtlas path, since that already
--- draws the real thing natively there.
--- @param atlasName string
--- @return table|nil info shaped like C_Texture.GetAtlasInfo's own return

--- Resolves an atlas name to real Retail pixel data, ignoring which theme is
--- currently rendered. Returns nil when the client already draws the genuine
--- Retail art for that name (so the native path stays untouched) or when the
--- name has no known Retail region. Used by the theme preview cards, which
--- must always show real Retail art even while another theme is active.
--- @param atlasName string
--- @return table|nil info shaped like C_Texture.GetAtlasInfo's own return
function KT.VisualThemes:GetForeverAtlasPixels(atlasName)
    if type(atlasName) ~= "string" or atlasName:lower() ~= "ui-hud-unitframe-player-portraiton" then return nil end
    return {
        file = [[Interface\AddOns\KullThranUI\Libraries\texture\media\portraits\forever_unitframe.tga]],
        width = 198, height = 71,
        leftTexCoord = 1 / 256, rightTexCoord = 199 / 256,
        topTexCoord = 246 / 512, bottomTexCoord = 317 / 512,
    }
end

function KT.GetRetailAtlasPixels(atlasName)
    if type(atlasName) ~= "string" then return nil end
    local entry = RETAIL_ATLAS_OVERRIDES[atlasName:lower()]
    if not entry then return nil end
    local liveInfo = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlasName)
    local liveFile = liveInfo and (liveInfo.file or liveInfo.filename)
    if liveFile and liveFile == entry.file then return nil end
    return {
        file = entry.file,
        width = entry.width or (entry.right - entry.left),
        height = entry.height or (entry.bottom - entry.top),
        leftTexCoord = entry.left / entry.sheetW,
        rightTexCoord = entry.right / entry.sheetW,
        topTexCoord = entry.top / entry.sheetH,
        bottomTexCoord = entry.bottom / entry.sheetH,
        tilesHorizontally = false,
        tilesVertically = false,
    }
end

local function ResolveRetailAtlasOverride(atlasName)
    local renderedTheme = KT.VisualThemes and KT.VisualThemes.GetRenderedTheme
        and KT.VisualThemes:GetRenderedTheme()
    if renderedTheme ~= "retail" then return nil end
    local entry = atlasName and RETAIL_ATLAS_OVERRIDES[atlasName:lower()]
    if not entry then return nil end
    -- Ask the client what this atlas resolves to right now instead of
    -- trusting a client-flavor flag, which can be wrong. If the live file
    -- already matches the expected file, nothing remapped the atlas and the
    -- normal path draws it natively.
    local liveInfo = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlasName)
    local liveFile = liveInfo and (liveInfo.file or liveInfo.filename)
    if liveFile == entry.file then return nil end
    return {
        file = entry.file,
        width = entry.width or (entry.right - entry.left),
        height = entry.height or (entry.bottom - entry.top),
        leftTexCoord = entry.left / entry.sheetW,
        rightTexCoord = entry.right / entry.sheetW,
        topTexCoord = entry.top / entry.sheetH,
        bottomTexCoord = entry.bottom / entry.sheetH,
        tilesHorizontally = false,
        tilesVertically = false,
    }
end
-- Exposed on the shared KT object: ActionBars.lua is a separate addon/TOC
-- with its own private `ns` from its own `...`, so it can't see this file's
-- local `ResolveRetailAtlasOverride` directly -- KT is the one object every
-- KullThranUI sub-addon fetches identically via LibStub.
KT.ResolveRetailAtlasOverride = ResolveRetailAtlasOverride

--- Applies the Forever theme's real per-client UnitFrame art: creates
--- (once, cached on `frame`) the real player/target frame-art box texture,
--- scaled and anchored so its own known internal portrait sub-rect lines up
--- with `unitRegion`'s real on-screen position and size, gated on both
--- `unit` having a known real geometry entry and the atlas name actually
--- resolving in this client. Falls back to ClearForeverUnitFrameArt (no
--- art -- today's already-shipped fixed-accent-color look) for any other
--- unit or when the atlas doesn't resolve, rather than guessing.
--- @param frame Frame the unit frame's outer frame (owns the cache)
--- @param unitRegion Frame|Region the real portrait region to align the box's internal portrait to
--- @param unit string|nil the unit key ("player"/"target"); any other value clears
--- @return boolean|nil true when the real box art was actually drawn (the caller can use this to hide its own generic border, now redundant); nil otherwise
function KT.VisualThemes:ApplyForeverUnitFrameArt(frame, unitRegion, unit)
    if type(frame) ~= "table" or type(frame.CreateTexture) ~= "function" then return end
    if type(unitRegion) ~= "table" then return end

    local renderedTheme = self.GetRenderedTheme and self:GetRenderedTheme()
    local isRetailTheme = renderedTheme == "retail"
    local geom = unit and FOREVER_FRAME_GEOMETRY[unit]
    if not geom then
        self:ClearForeverUnitFrameArt(frame)
        return
    end

    local retailOverrideInfo = ResolveRetailAtlasOverride(geom.art)
    local foreverOverrideInfo = renderedTheme == "forever" and _G.WOW_PROJECT_MAINLINE
        and _G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE and self:GetForeverAtlasPixels(geom.art)
    local info = foreverOverrideInfo or retailOverrideInfo
        or (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(geom.art))
    if not info then
        -- C_Texture.GetAtlasInfo can return nil very early after login,
        -- before all game data tables are populated, even for a perfectly
        -- valid atlas name that resolves fine moments later: Forever
        -- rendered black on first entering the game and only
        -- looked right after a manual /reload, which re-runs this from
        -- scratch later in the loading sequence once the atlas IS
        -- available. Same retry pattern this codebase already uses for an
        -- identical late-binding problem elsewhere
        -- (RequestAnchorPlayerFrameToCDM's 0/0.5/1.5s retries). Retry a
        -- bounded number of times before actually giving up and clearing.
        local retries = frame._ktForeverArtRetries or 0
        if retries < 3 and type(C_Timer) == "table" and C_Timer.After then
            frame._ktForeverArtRetries = retries + 1
            local delay = ({ 0.2, 0.5, 1.5 })[retries + 1] or 1.5
            C_Timer.After(delay, function()
                KT.VisualThemes:ApplyForeverUnitFrameArt(frame, unitRegion, unit)
            end)
            return
        end
        frame._ktForeverArtRetries = nil
        self:ClearForeverUnitFrameArt(frame)
        return
    end
    frame._ktForeverArtRetries = nil
    frame._ktStockArtSelection = {
        theme = renderedTheme, atlas = geom.art, file = info.file or info.filename,
        source = foreverOverrideInfo and "packaged-forever" or (retailOverrideInfo and "retail-override" or "client-atlas"),
        width = info.width, height = info.height,
    }

    -- The same stock-box scale resolver is shared with Classic, so attached
    -- and circular layouts interpret the configured width identically.
    local scale = ResolveStockScale(frame, geom)
    local circularPortrait = frame._ktCircularPortrait and true or false
    -- PLAYER's Rare/Elite overlay replaces the Forever/Retail portrait art.
    -- Keep this decision inside the renderer as well as the metadata pass:
    -- delayed atlas retries and later layout reapplies must not resurrect the
    -- base ornament after the classification border has hidden it.
    local showBasePortraitArt = frame._ktHideForeverPortraitArt ~= true
    -- Signed near-edge extension set by KUIUnitFrames while a Rare/Elite ring
    -- is shown. Player uses a negative value (extend left), target a positive
    -- one (extend right). The bars grow only toward the portrait, preserving
    -- their outer edge instead of translating the whole StatusBar.
    local ringShiftX = (frame._ktRingHugShift and (tonumber(frame._ktRingHugShift) or 0)) or 0
    local nativeClassification = frame._ktNativeClassificationKind ~= nil
    local nameShiftX = nativeClassification and 0 or ringShiftX
    local nameWidth = geom.name and geom.name.w * scale or 0
    if nativeClassification and geom.name then
        -- Use the opening's measured head-side reach, independently of
        -- padding on the opposite side of the atlas.
        local headReach = (frame._ktNativeClassificationHeadReach or 36) * geom.portrait.size / 58
        if unit == "player" then
            local headRight = geom.portrait.x + 3 + geom.portrait.size / 2 + headReach
            nameShiftX = math.max(0, headRight + 2 - geom.name.x) * scale
            nameWidth = math.max(1, nameWidth - nameShiftX)
        elseif unit == "target" then
            local headLeft = geom.w + geom.portrait.x - geom.portrait.size / 2 - headReach
            nameWidth = math.max(1, math.min(nameWidth, (headLeft - 2 - geom.name.x) * scale))
        end
    end
    local portraitExtension = 0
    local barShiftX = 0
    if unit == "player" and ringShiftX < 0 then
        portraitExtension = -ringShiftX
        barShiftX = ringShiftX
    elseif unit == "target" and ringShiftX > 0 then
        portraitExtension = ringShiftX
    end

    frame:SetSize(geom.w * scale, geom.h * scale)

    local host = EnsureArtHost(frame, "_ktForeverArtHost")
    if not host then return end
    SyncArtLayers(frame, host, false)
    if unit == "player" and nativeClassification then
        -- The extended bars run behind the circular portrait. Its mask
        -- exposes the bars only outside the opening instead of cutting a
        -- rectangular bite into the photo/model at the near edge.
        local topBarLevel = math.max(frame.Health and frame.Health:GetFrameLevel() or 0,
            frame.Power and frame.Power:GetFrameLevel() or 0)
        unitRegion:SetFrameLevel(topBarLevel + 1)
        if unitRegion._3d then unitRegion._3d:SetFrameLevel(topBarLevel + 2) end
    end

    local art = frame._ktForeverPortraitArt
    if not art then
        art = host:CreateTexture(nil, "BACKGROUND")
        UnsnapTexture(art)
        frame._ktForeverPortraitArt = art
    end
    -- A full-box solid fill behind `art` does not work: the real atlas is the
    -- whole bar-area background graphic and is genuinely transparent over
    -- large parts of the box. Seating the patch on `host` behind `art`'s own
    -- sublevel is also wrong: `host`
    -- (SyncArtLayers) sits at a higher frame level than `unitRegion`
    -- (frame.Portrait.backdrop), so anything opaque on `host` covers the
    -- portrait photo entirely wherever the ring art is transparent, not
    -- just the small edge gap. The photo itself is on `unitRegion`'s own
    -- frame level; a patch needs to live THERE, below the photo's own
    -- sublevel, for the photo to draw over it normally and reveal it only
    -- where neither the photo nor the ring draws anything. It is masked with its
    -- own circular MaskTexture (expanded a few px past the portrait) so it
    -- does not show as a square block.
    local fill = frame._ktForeverPortraitArtFill
    if not fill then
        fill = unitRegion:CreateTexture(nil, "BACKGROUND", nil, -8)
        UnsnapTexture(fill)
        frame._ktForeverPortraitArtFill = fill
    end
    fill:SetColorTexture(0, 0, 0, 1)
    local fillMask = frame._ktForeverPortraitArtFillMask
    if not fillMask then
        fillMask = unitRegion:CreateMaskTexture()
        frame._ktForeverPortraitArtFillMask = fillMask
    end
    fillMask:SetTexture(PORTRAIT_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    fillMask:ClearAllPoints()
    -- Reverted 10 -> 6: enlarging the CIRCLE enough to reach the dome's
    -- flat-bottom corner overshot past the ring's own round top/sides --
    -- so a black crescent peeked out past the gold ring
    -- there. A circle can't fit both without distortion; the corners are
    -- handled separately below with their own small square patches instead
    -- of stretching this one.
    local fillMargin = 6 * scale
    fillMask:SetPoint("TOPLEFT", unitRegion, "TOPLEFT", -fillMargin, fillMargin)
    fillMask:SetPoint("BOTTOMRIGHT", unitRegion, "BOTTOMRIGHT", fillMargin, -fillMargin)
    if fill.RemoveMaskTexture then pcall(fill.RemoveMaskTexture, fill, fillMask) end
    fill:AddMaskTexture(fillMask)
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", unitRegion, "TOPLEFT", -fillMargin, fillMargin)
    fill:SetPoint("BOTTOMRIGHT", unitRegion, "BOTTOMRIGHT", fillMargin, -fillMargin)
    if showBasePortraitArt then fill:Show() else fill:Hide() end

    -- Patch for the dome's one real flat-bottom corner, shaped with the
    -- hand-authored concave mask above instead of a plain square -- a
    -- square/circle needed several rounds of margin tuning and still either
    -- fell short of the corner or overshot the round edge.
    -- Both bottom corners are not patched on every call: the "redundant"
    -- side meant to stay invisibly hidden behind the ring's own opaque
    -- corner is not actually hidden. The level
    -- badge (_kuiLevelCircle) sits right in that same corner and its own
    -- texture has a transparent square margin around its round art, so the
    -- redundant patch would peek out through THAT corner -- a second,
    -- unrelated collision the ring-opacity reasoning doesn't cover. The
    -- other side never fixes a real gap to begin with (the ring
    -- already covers it natively), so only the real corner gets a patch;
    -- the other is explicitly hidden.
    local cornerOverlap = 4 * scale
    local cornerScale = 1.25
    local cornerW, cornerH = DOME_CORNER_MASK_W * scale * cornerScale, DOME_CORNER_MASK_H * scale * cornerScale
    local leftIsActive = geom.mirror and true or false

    local cornerPatch = frame._ktForeverPortraitCornerPatch
    if not cornerPatch then
        cornerPatch = unitRegion:CreateTexture(nil, "BACKGROUND", nil, -8)
        UnsnapTexture(cornerPatch)
        frame._ktForeverPortraitCornerPatch = cornerPatch
    end
    if leftIsActive and showBasePortraitArt then
        cornerPatch:SetColorTexture(0, 0, 0, 1)
        cornerPatch:ClearAllPoints()
        cornerPatch:SetPoint("BOTTOMLEFT", unitRegion, "BOTTOMLEFT", -cornerOverlap, -cornerOverlap)
        cornerPatch:SetSize(cornerW, cornerH)
        local cornerMask = frame._ktForeverPortraitCornerMask
        if not cornerMask then
            cornerMask = unitRegion:CreateMaskTexture()
            frame._ktForeverPortraitCornerMask = cornerMask
        end
        cornerMask:SetTexture(DOME_CORNER_MASK_LEFT, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        cornerMask:ClearAllPoints()
        cornerMask:SetAllPoints(cornerPatch)
        if cornerPatch.RemoveMaskTexture then pcall(cornerPatch.RemoveMaskTexture, cornerPatch, cornerMask) end
        cornerPatch:AddMaskTexture(cornerMask)
        cornerPatch:Show()
    else
        cornerPatch:Hide()
    end

    local cornerPatch2 = frame._ktForeverPortraitCornerPatch2
    if not cornerPatch2 then
        cornerPatch2 = unitRegion:CreateTexture(nil, "BACKGROUND", nil, -8)
        UnsnapTexture(cornerPatch2)
        frame._ktForeverPortraitCornerPatch2 = cornerPatch2
    end
    if not leftIsActive and showBasePortraitArt then
        cornerPatch2:SetColorTexture(0, 0, 0, 1)
        cornerPatch2:ClearAllPoints()
        cornerPatch2:SetPoint("BOTTOMRIGHT", unitRegion, "BOTTOMRIGHT", cornerOverlap, -cornerOverlap)
        cornerPatch2:SetSize(cornerW, cornerH)
        local cornerMask2 = frame._ktForeverPortraitCornerMask2
        if not cornerMask2 then
            cornerMask2 = unitRegion:CreateMaskTexture()
            frame._ktForeverPortraitCornerMask2 = cornerMask2
        end
        cornerMask2:SetTexture(DOME_CORNER_MASK_RIGHT, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        cornerMask2:ClearAllPoints()
        cornerMask2:SetAllPoints(cornerPatch2)
        if cornerPatch2.RemoveMaskTexture then pcall(cornerPatch2.RemoveMaskTexture, cornerPatch2, cornerMask2) end
        cornerPatch2:AddMaskTexture(cornerMask2)
        cornerPatch2:Show()
    else
        cornerPatch2:Hide()
    end

    local shapeMask = unitRegion._shapeMask
    if shapeMask then
        -- Player-only: target now mirrors player's own atlas (see the
        -- comment above FOREVER_FRAME_GEOMETRY.target), and MaskTexture
        -- mirroring via SetTexCoord makes the
        -- whole portrait disappear -- never attempt it on target's mask.
        local appliedRetailMask = isRetailTheme and unit == "player" and not circularPortrait
            and ApplyRetailStockPortraitMask(shapeMask, RETAIL_PLAYER_PORTRAIT_MASK)
        if nativeClassification then
            shapeMask:SetAtlas("CircleMask", false)
            shapeMask:SetTexCoord(0, 1, 0, 1)
        elseif not appliedRetailMask then
            -- Reset texcoord too, not just the texture -- a stale flip from
            -- the mirrored Retail target would otherwise persist onto the
            -- plain round mask after switching themes or hitting a fallback.
            shapeMask:SetTexture(PORTRAIT_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            shapeMask:SetTexCoord(0, 1, 0, 1)
        end
    end
    -- SetAtlas alone can't be flipped (its own SetTexCoord addresses the
    -- atlas's normalized sub-rect, not the sheet, so resolving to the real
    -- file first is required to mirror it). geom.mirror is EXPERIMENTAL
    -- (see the comment on FOREVER_FRAME_GEOMETRY.target). Also: this must
    -- run whenever `info` has real texcoord/file data, not only when
    -- mirrored -- a RETAIL_ATLAS_OVERRIDES entry populates exactly those
    -- fields, and calling SetAtlas here instead would go through the
    -- client's own (possibly Forever-remapped) atlas resolution, silently
    -- discarding the override for the unmirrored (player) case.
    if info.leftTexCoord and info.rightTexCoord
        and info.topTexCoord and info.bottomTexCoord and (info.file or info.filename) then
        art._ktGlowTextureFile = info.file or info.filename
        art:SetTexture(art._ktGlowTextureFile)
        if geom.mirror then
            art:SetTexCoord(info.rightTexCoord, info.leftTexCoord, info.topTexCoord, info.bottomTexCoord)
        else
            art:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
        end
    else
        art._ktGlowTextureFile = nil
        art:SetAtlas(geom.art)
    end
    art:ClearAllPoints()
    art:SetPoint("CENTER", host, "CENTER", 0, 0)
    -- Reverted: forcing geom.w/geom.h here stretched the Retail override's
    -- texture (198x71) to fill a box sized for Forever's own remap (~230x99),
    -- distorting the whole ring instead of just closing the small corner
    -- gap. Back to sizing from the resolved info, matching what worked
    -- before the gap was reported.
    art:SetSize((info.width or geom.w) * scale, (info.height or geom.h) * scale)
    if showBasePortraitArt then art:Show() else art:Hide() end
    frame._ktDebugArtCalc = string.format(
        "mirrored=%s infoW=%s infoH=%s setW=%.4f setH=%.4f postSetGetWidth=%s postSetGetHeight=%s",
        tostring(geom.mirror and info.leftTexCoord ~= nil), tostring(info.width), tostring(info.height),
        (info.width or geom.w) * scale, (info.height or geom.h) * scale,
        tostring(art.GetWidth and art:GetWidth()), tostring(art.GetHeight and art:GetHeight()))

    -- The outer frame is now the stable stock box. Portrait and bars are all
    -- siblings anchored to that same box, so no element depends on Health
    -- while Health is being repositioned (the previous portrait -> art ->
    -- health feedback loop could drift on every refresh).
    local portrait = geom.portrait
    -- Retail's native masks already describe their exact frame openings.
    -- Keep them flush to the 60px player or 58px target portrait rectangle
    -- so no pixels escape above the gold ring.
    -- frame._ktCircularPortrait (set by KUIUnitFrames while a rare/elite ring is
    -- shown): plain round shape instead of Retail's drop-shaped stock mask, so
    -- it needs the normal mask-padding compensation (nil) instead of 0.
    SeatStockPortrait(unitRegion, frame, portrait, scale,
        (nativeClassification or (isRetailTheme and not circularPortrait)) and 0 or nil)

    local health = frame.Health
    if geom.health and type(health) == "table" and health.ClearAllPoints then
        health:ClearAllPoints()
        health:SetPoint("TOPLEFT", frame, "TOPLEFT",
            geom.health.x * scale + barShiftX, -geom.health.y * scale)
        health:SetSize(geom.health.w * scale + portraitExtension, geom.health.h * scale)
        health._xOffset = geom.health.x * scale + barShiftX
        health._rightInset = (geom.w - geom.health.x - geom.health.w) * scale
            - ((unit == "target") and portraitExtension or 0)
        health._topOffset = geom.health.y * scale
        ApplyForeverBarMask(health, geom.health, scale, portraitExtension)
        ResizeHealthPrediction(frame, geom.health.w * scale + portraitExtension, geom.health.h * scale)
        -- TEMPORARY debug: cache the exact arithmetic that just ran, and the
        -- width immediately after SetSize, so the diagnostic dump can show whether
        -- something ELSE changes it before it is inspected later.
        frame._ktDebugHealthCalc = string.format(
            "scale=%.4f geomW=%.2f geomH=%.2f setW=%.4f setH=%.4f postSetGetWidth=%s",
            scale, geom.health.w, geom.health.h,
            geom.health.w * scale + portraitExtension, geom.health.h * scale,
            tostring(health.GetWidth and health:GetWidth()))
    end

    local power = frame.Power
    if geom.power and type(power) == "table" and power.ClearAllPoints then
        power:ClearAllPoints()
        power:SetPoint("TOPLEFT", frame, "TOPLEFT",
            geom.power.x * scale + barShiftX, -geom.power.y * scale)
        power:SetSize(geom.power.w * scale + portraitExtension, geom.power.h * scale)
        ApplyForeverBarMask(power, geom.power, scale, portraitExtension, true)
    end

    SeatStockCastbar(frame, geom, scale)

    -- Whichever FontString actually holds "name" content is a per-profile
    -- choice resolved by KUIUnitFrames.lua (which has access to `settings`)
    -- and handed over via frame._ktStockNameText -- falling back to
    -- frame.LeftText, KUI's own default assignment, when that isn't set
    -- (e.g. in the test harness, or before KUIUnitFrames.lua resolves it).
    local nameText = frame._ktStockNameText or frame.LeftText
    if geom.name and type(nameText) == "table" and nameText.ClearAllPoints then
        local point = geom.name.point or "TOPLEFT"
        -- frame.Health has SetClipsChildren(true) (CreateAbsorbBar); nameText's
        -- normal parent chain (frame.LeftText -> _textOverlay -> frame.Health)
        -- inherits that clip. See the identical comment in
        -- ApplyClassicUnitFrameArt for why this reparent is needed: the name
        -- was correctly positioned/sized/texted and still
        -- invisible until this fix.
        if nameText.SetParent then nameText:SetParent(host) end
        nameText:ClearAllPoints()
        nameText:SetPoint(point, frame, point,
            geom.name.x * scale + nameShiftX, geom.name.y * scale)
        if nameText.SetWidth then nameText:SetWidth(nameWidth) end
        if nameText.SetJustifyH then nameText:SetJustifyH(geom.name.justify or "LEFT") end
        frame._ktDebugNameCalc = string.format(
            "point=%s x=%.4f y=%.4f w=%.4f postSetGetWidth=%s postSetText=%s",
            tostring(point), geom.name.x * scale + nameShiftX, geom.name.y * scale, nameWidth,
            tostring(nameText.GetWidth and nameText:GetWidth()),
            tostring(nameText.GetText and nameText:GetText()))
    end

    local barTextMaxHeight = geom.health.h * scale
    self:ApplyBlizzardBarText(frame.LeftText, scale, barTextMaxHeight)
    self:ApplyBlizzardBarText(frame.RightText, scale, barTextMaxHeight)
    self:ApplyBlizzardBarText(frame.CenterText, scale, barTextMaxHeight)
    self:ApplyBlizzardBarText(frame.Power and frame.Power._ppFS, scale, geom.power.h * scale)
    -- A name long enough to overflow the real tab's
    -- real width shrinks further, on top of the uniform theme scale above,
    -- rather than spilling past the tab or overlapping the buffs below it.
    -- Must target the SAME object just positioned in the tab (`nameText`,
    -- which may be RightText/CenterText, not always LeftText) -- fitting
    -- frame.LeftText unconditionally here was a real bug when the two
    -- differ (that FontString was never moved, so fitting it did nothing
    -- useful and left the actual tab text unfitted).
    if geom.name then
        FitTextToWidth(nameText, nameWidth)
        self:ApplyBlizzardNameText(nameText, scale, nameWidth)
    end

    -- Buffs move into the same real name tab --
    -- Forever-only for now (Classic/Retail keep their existing Health-bar-
    -- relative anchor untouched). Anchored so the icon ROW's bottom edge
    -- sits on the tab's own top edge, growing upward from it -- the tab
    -- itself is the name's real rect, not the buffs' rect, so buffs sit
    -- immediately above it rather than overlapping the name text.
    local buffs = frame.Buffs
    if geom.name and type(buffs) == "table" and buffs.ClearAllPoints then
        local tabW = geom.health.w * scale
        local iconSize = math.max(8, geom.health.h * scale)
        local gap = buffs.spacing or 1
        -- Sharing the exact same Y as the name tab's own top
        -- edge left zero margin between buffs (growing up from that line)
        -- and the name text (growing down from it) -- close enough that
        -- icon borders/glow and text ascenders overlapped a little, on both
        -- player and target. Nudging buffs' own anchor a few pixels further
        -- up (name's own position is untouched) opens a small gap.
        local buffsY = geom.name.y + BUFFS_TAB_GAP
        -- Target's buffs sat
        -- visibly lower than player's despite sharing this same formula
        -- (geom.name.y is identical for both in FOREVER_FRAME_GEOMETRY) --
        -- a small target-only nudge upward to match.
        if unit == "target" then buffsY = buffsY + 4 end
        buffs:ClearAllPoints()
        buffs:SetPoint("BOTTOMLEFT", frame, "TOPLEFT",
            geom.name.x * scale, buffsY * scale)
        buffs:SetSize(tabW, iconSize)
        buffs.size = iconSize
        buffs.spacing = gap
        buffs["size-x"] = math.max(1, math.floor((tabW + gap) / (iconSize + gap)))
        if buffs.ForceUpdate then buffs:ForceUpdate() end
        frame._ktAuraRowLift = math.max(0, buffsY * scale + iconSize)
        frame._ktDebugBuffsCalc = string.format(
            "tabW=%.4f iconSize=%.4f x=%.4f y=%.4f postSetGetWidth=%s postSetGetHeight=%s",
            tabW, iconSize, geom.name.x * scale, buffsY * scale,
            tostring(buffs.GetWidth and buffs:GetWidth()), tostring(buffs.GetHeight and buffs:GetHeight()))
    end

    frame._ktForeverLayoutActive = true
    return true
end
--- Hides (does not destroy) the Forever frame-art box created by
--- ApplyForeverUnitFrameArt, if any. Nil-safe if it was never created.
--- @param frame Frame|Region the unit frame passed to ApplyForeverUnitFrameArt
function KT.VisualThemes:ClearForeverUnitFrameArt(frame)
    if type(frame) ~= "table" then return end
    for _, fs in pairs({ frame.LeftText, frame.RightText, frame.CenterText,
        frame.Power and frame.Power._ppFS, frame._kuiLevelText }) do
        fs._ktBlizzBar = nil
    end

    local art = frame._ktForeverPortraitArt
    if art then art:Hide() end
    local artFill = frame._ktForeverPortraitArtFill
    if artFill then artFill:Hide() end
    local cornerPatch = frame._ktForeverPortraitCornerPatch
    if cornerPatch then cornerPatch:Hide() end
    local cornerPatch2 = frame._ktForeverPortraitCornerPatch2
    if cornerPatch2 then cornerPatch2:Hide() end

    local function ClearBarMask(bar)
        local mask = bar and bar._ktForeverMask
        if not mask then return end
        local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
        if fill and fill.RemoveMaskTexture then pcall(fill.RemoveMaskTexture, fill, mask) end
        if bar.bg and bar.bg.RemoveMaskTexture then pcall(bar.bg.RemoveMaskTexture, bar.bg, mask) end
        mask:Hide()
    end

    ClearBarMask(frame.Health)
    ClearBarMask(frame.Power)
    local absorb = frame.HealthPrediction and frame.HealthPrediction.damageAbsorb
    local healthMask = frame.Health and frame.Health._ktForeverMask
    local absorbFill = absorb and absorb.GetStatusBarTexture and absorb:GetStatusBarTexture()
    if healthMask and absorbFill and absorbFill.RemoveMaskTexture then
        pcall(absorbFill.RemoveMaskTexture, absorbFill, healthMask)
    end
    -- ApplyClassicFrameArt applies Classic first and then clears any stale
    -- Forever surfaces. Do not release the stock portrait ownership that the
    -- Classic pass has just established, or the next generic circular refresh
    -- will move it back beside Health and show KUI's circular border again.
    if not frame._ktClassicLayoutActive then
        ReleaseStockPortrait(frame)
    end
    frame._ktForeverLayoutActive = nil
    if not frame._ktClassicLayoutActive then frame._ktAuraRowLift = nil end
end

--[[
    Pet frame art (Classic / Forever / Retail).

    The pet frame is a "mini" frame, so it gets its own small stock box
    instead of the player/target ones. Geometry follows the client's own
    small frames:
      * classic: Interface\TargetingFrame\UI-SmallTargetingFrame (128x64 sheet,
        drawn over the bars, round portrait on the left);
      * forever/retail: atlas UI-HUD-UnitFrame-TargetofTarget-PortraitOn
        (120x49) with the Party bar masks. The atlas has no Retail pixel
        override table entry, so a Forever client draws Forever's own art for
        both themes {unverified}.
    Shape/texture are fixed by the theme; size (frame width), bar colours,
    fonts, texts and border settings stay user-editable.
]]
local PetArt = {}
PetArt.geom = {
    classic = {
        w = 128, h = 53,
        art = { file = "Interface\\TargetingFrame\\UI-SmallTargetingFrame", w = 128, h = 64, x = 0, y = -2 },
        portrait = { point = "TOPLEFT", x = 7, y = -6, size = 37 },
        health = { x = 47, y = 22, w = 69, h = 8 },
        power = { x = 47, y = 29, w = 69, h = 8 },
        name = { x = 50, y = -9, w = 70 },
    },
    forever = {
        w = 120, h = 49,
        atlas = "UI-HUD-UnitFrame-TargetofTarget-PortraitOn",
        portrait = { point = "TOPLEFT", x = 5, y = -5, size = 37 },
        health = { x = 44, y = 17, w = 70, h = 10,
            mask = "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Mask", mx = -29, my = 3 },
        power = { x = 40, y = 28, w = 74, h = 7,
            mask = "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana-Mask", mx = -27, my = 4 },
        name = { x = 44, y = -5, w = 68 },
    },
}

local function PetSavePoints(region)
    local t = {}
    if not (region and region.GetNumPoints) then return t end
    for i = 1, region:GetNumPoints() do
        local p, rel, rp, x, y = region:GetPoint(i)
        t[#t + 1] = { p, rel, rp, x, y }
    end
    return t
end

local function PetRestorePoints(region, pts)
    if not (region and pts and #pts > 0) then return end
    region:ClearAllPoints()
    for i = 1, #pts do
        region:SetPoint(pts[i][1], pts[i][2], pts[i][3], pts[i][4], pts[i][5])
    end
end

--- @param kind string "classic" | "forever" (forever geometry serves Retail too)
--- @param opts table|nil { scale = number }
--- @return boolean|nil true when the art was drawn
function KT.VisualThemes:ApplyPetFrameArt(frame, unitRegion, kind, opts)
    if type(frame) ~= "table" or type(unitRegion) ~= "table" then return end
    local geom = PetArt.geom[kind]
    if not (geom and frame.Health) then return end
    if kind == "forever" then
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(geom.atlas)
        if not info then return end
    end
    local scale = tonumber(opts and opts.scale) or 1
    scale = math.max(0.5, math.min(3, scale))

    -- Snapshot only what the generic reload pass never re-seats.
    if not frame._ktPetSaved then
        frame._ktPetSaved = {
            power = PetSavePoints(frame.Power),
            portrait = PetSavePoints(unitRegion),
        }
    end

    -- Drop the other kind's leftovers first.
    if kind == "classic" then
        self:ClearForeverUnitFrameArt(frame)
    else
        ClearClassicRoundPortraitMask(frame)
        ClearClassicPortraitFill(frame)
    end

    local host = EnsureArtHost(frame, "_ktPetArtHost")
    if not host then return end
    frame:SetSize(geom.w * scale, geom.h * scale)
    SyncArtLayers(frame, host, kind == "classic")

    local art = frame._ktPetArt
    if not art then
        art = host:CreateTexture(nil, "BACKGROUND")
        UnsnapTexture(art)
        frame._ktPetArt = art
    end
    art:ClearAllPoints()
    if kind == "classic" then
        art:SetTexture(geom.art.file)
        art:SetTexCoord(0, 1, 0, 1)
        art:SetPoint("TOPLEFT", frame, "TOPLEFT", geom.art.x * scale, geom.art.y * scale)
        art:SetSize(geom.art.w * scale, geom.art.h * scale)
    else
        art:SetAtlas(geom.atlas)
        art:SetPoint("CENTER", host, "CENTER", 0, 0)
        local info = C_Texture.GetAtlasInfo(geom.atlas)
        art:SetSize((info.width or geom.w) * scale, (info.height or geom.h) * scale)
    end
    art:Show()

    -- Portrait: the art's aperture needs a portrait even if the pet's own
    -- "show portrait" is off (its default), same as party frames.
    if unitRegion.IsShown and not unitRegion:IsShown() then
        unitRegion:Show()
        frame._ktPetPortraitForced = true
    end
    SeatStockPortrait(unitRegion, frame, geom.portrait, scale, nil)
    if kind == "classic" then
        ApplyClassicRoundPortraitMask(unitRegion)
        SyncClassicPortraitFill(frame, unitRegion, scale, "right")
    elseif unitRegion._shapeMask then
        unitRegion._shapeMask:SetTexture(PORTRAIT_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        unitRegion._shapeMask:SetTexCoord(0, 1, 0, 1)
    end

    local health = frame.Health
    health:ClearAllPoints()
    health:SetPoint("TOPLEFT", frame, "TOPLEFT", geom.health.x * scale, -geom.health.y * scale)
    health:SetSize(geom.health.w * scale, geom.health.h * scale)
    health._xOffset = geom.health.x * scale
    health._rightInset = (geom.w - geom.health.x - geom.health.w) * scale
    health._topOffset = geom.health.y * scale
    if kind == "forever" then ApplyForeverBarMask(health, geom.health, scale) end
    ResizeHealthPrediction(frame, geom.health.w * scale, geom.health.h * scale)

    local power = frame.Power
    if power then
        power:ClearAllPoints()
        power:SetPoint("TOPLEFT", frame, "TOPLEFT", geom.power.x * scale, -geom.power.y * scale)
        power:SetSize(geom.power.w * scale, geom.power.h * scale)
        if kind == "forever" then ApplyForeverBarMask(power, geom.power, scale) end
    end

    local nameText = frame._ktStockNameText or frame.LeftText
    if type(nameText) == "table" and nameText.ClearAllPoints then
        if nameText.SetParent then nameText:SetParent(host) end
        nameText:ClearAllPoints()
        nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", geom.name.x * scale, geom.name.y * scale)
        if nameText.SetWidth then nameText:SetWidth(geom.name.w * scale) end
        if nameText.SetJustifyH then nameText:SetJustifyH("LEFT") end
    end
    local ratio = (kind == "classic") and CLASSIC_BAR_TEXT_HEIGHT_RATIO or STOCK_BAR_TEXT_HEIGHT_RATIO
    local barMax = geom.health.h * scale
    if nameText then
        ScaleStockBarText(nameText, scale, math.max(barMax, 11 * scale), 0.8)
        FitTextToWidth(nameText, geom.name.w * scale)
        self:ApplyBlizzardNameText(nameText, scale, geom.name.w * scale)
    end
    for _, fs in ipairs({ frame.LeftText, frame.RightText, frame.CenterText }) do
        if fs and fs ~= nameText then ScaleStockBarText(fs, scale, barMax, ratio) end
    end

    if kind == "classic" then
        frame._ktClassicLayoutActive = true
        frame._ktForeverLayoutActive = nil
    else
        frame._ktForeverLayoutActive = true
        frame._ktClassicLayoutActive = nil
    end
    return true
end

--- Removes the pet art and gives back what the generic reload pass does not
--- re-seat (power/portrait anchors, text parents). Size, health anchors and
--- text positions are re-applied by the caller's normal layout pass.
function KT.VisualThemes:ClearPetFrameArt(frame)
    if type(frame) ~= "table" or not frame._ktPetSaved then return end
    local saved = frame._ktPetSaved
    frame._ktPetSaved = nil
    if frame._ktPetArt then frame._ktPetArt:Hide() end
    ClearClassicRoundPortraitMask(frame)
    ClearClassicPortraitFill(frame)
    frame._ktClassicLayoutActive = nil
    frame._ktForeverLayoutActive = nil
    self:ClearForeverUnitFrameArt(frame)
    ReleaseStockPortrait(frame)

    local backdrop = frame.Portrait and frame.Portrait.backdrop
    PetRestorePoints(backdrop, saved.portrait)
    PetRestorePoints(frame.Power, saved.power)
    if backdrop and frame._ktPetPortraitForced then
        frame._ktPetPortraitForced = nil
        backdrop:Hide()
    end
    local overlay = frame._textOverlay
    if overlay then
        for _, fs in ipairs({ frame.LeftText, frame.RightText, frame.CenterText }) do
            if fs and fs.SetParent then fs:SetParent(overlay) end
        end
    end
end
