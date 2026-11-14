-- Nameplates_ThemeSkin.lua
-- Native looks for the Classic, Retail and Forever nameplate styles, drawn with Blizzard's own
-- nameplate art and laid out as Blizzard_NamePlates lays it out. KUI keeps its own look.
--   Forever: the Forever client's modern plate (the -c60 atlases): metal frame, level box on the
--            right, yellow selection frame, elite dragon on the left.
--   Retail:  the Retail modern plate (same layout, Retail art, white selection frame).
--   Classic: the Classic plate (Interface\Tooltips\Nameplate-Border with the level in its pill).
-- Blizzard draws these at fixed bar heights (Forever 13, Retail 20, Classic 10); every offset and
-- size here is that layout scaled by the plate's bar height, rounded to whole screen pixels.
-- The frame pieces are set by texture file and crop, read from the client's UiTextureAtlasMember
-- table: SetAtlas takes the element name and the client picks the variant itself (-c60 in
-- Forever, -2x on large screens), so Retail art could not be asked for by name in Forever.
local addonName, ns = ...
local KT = _G.KullThranUI

local WHITE = "Interface\\Buttons\\WHITE8x8"

-- Estilo de nameplate: preset elegido en Nameplates > General (kui/classic/retail/forever)
-- o, si no hay ninguno, el tema visual activo.
local VALID_STYLE = { kui = true, classic = true, retail = true, forever = true }
function ns.NameplateStyle()
    if ns._styleOverride then return ns._styleOverride end
    local st = KullThranUINameplatesDB and KullThranUINameplatesDB.nameplateStyle
    if st and VALID_STYLE[st] then return st end
    local VT = KT and KT.VisualThemes
    return VT and VT.GetRenderedTheme and VT:GetRenderedTheme() or nil
end
local RenderedTheme = ns.NameplateStyle

-- Runs fn with every style lookup answering `style` (the options style samples draw
-- each style through the plates' own code). Always restored, even on error.
function ns.WithNameplateStyle(style, fn, ...)
    local prev = ns._styleOverride
    ns._styleOverride = VALID_STYLE[style] and style or nil
    local res = { pcall(fn, ...) }
    ns._styleOverride = prev
    if not res[1] then error(res[2], 0) end
    return unpack(res, 2, table.maxn(res))
end

local NATIVE = { classic = true, retail = true, forever = true }

-- Texture file, its size, the crop (left, top, right, bottom) in pixels and the pixels per
-- Blizzard unit (2 for the -2x art).
local function Crop(file, w, h, l, top, r, b, px)
    return { file = file, w = w, h = h, l = l, t = top, r = r, b = b, px = px or 1 }
end

-- Blizzard art and layout per style. Offsets are Blizzard's, at Blizzard's bar height `baseH`.
-- *Slice: the atlas nine-slice margins (left, top, right, bottom) in Blizzard units, from the
-- client's UiTextureAtlasElementSliceData; margins keep their size, only the middle stretches.
-- The Retail client has no Forever (-c60) art: its crops ship with the addon, laid out on one
-- sheet (frame 0,0; selection 0,40; level box 270,0; level selection 330,0), 2 px per unit.
local FOREVER_NAMEPLATE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\forever_nameplate.png"

local ART = {
    forever = {
        baseH = 13,                                            -- SMALL_HEALTH_BAR_HEIGHT (Forever)
        fill = "UI-HUD-CoolDownManager-Bar",                   -- element: Forever shows its -c60 variant
        bg = Crop(FOREVER_NAMEPLATE, 512, 128, 0, 0, 264, 38, 2),  -- ui-hud-cooldownmanager-bar-bg-c60-2x
        bgSlice = { 121, 7, 10, 11 },
        bgOffsets = { -2, 3, 6, -6 },                          -- bgTexture around the health bar
        selected = Crop(FOREVER_NAMEPLATE, 512, 128, 0, 40, 264, 72, 2), -- ui-hud-cooldownmanager-selected-yellow-c60-2x
        selectedSlice = { 8, 7, 8, 7 },
        selectedOffsets = { -3, 2, 0, 2 },                     -- SELECTED_BORDER_OFFSETS, on bgTexture
        level = Crop(FOREVER_NAMEPLATE, 512, 128, 270, 0, 326, 44, 2), -- ui-hud-nameplates-levelindicator-rectangle-c60-2x
        levelSelected = Crop(FOREVER_NAMEPLATE, 512, 128, 330, 0, 386, 44, 2), -- ...-rectangle-selected-c60-2x
        levelSelectedSlice = { 7, 7, 7, 7 },
    },
    retail = {
        baseH = 20,                                            -- LARGE_HEALTH_BAR_HEIGHT (Retail)
        fill = "UI-HUD-CoolDownManager-Bar",
        bg = Crop(6739577, 512, 256, 175, 1, 439, 39, 2),      -- ui-hud-cooldownmanager-bar-bg-2x
        bgSlice = { 121, 7, 10, 11 },
        bgOffsets = { -2, 3, 6, -6 },
        selected = Crop(7241122, 256, 256, 1, 102, 217, 120),  -- ui-hud-nameplates-selected
        selectedSlice = { 8, 8, 8, 8 },
        selectedOffsets = { -1, 1, -3, 3 },
    },
    classic = {
        baseH = 10,                                            -- CLASSIC_HEALTH_BAR_HEIGHT
        fill = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
    },
}
ns.NAMEPLATE_STYLE_ART = ART

local DESELECTED = Crop(7241122, 256, 256, 1, 136, 211, 148)   -- ui-hud-nameplates-deselected-overlay
local CLASSIC_BORDER = "Interface\\Tooltips\\Nameplate-Border"
local CLASSIC_BAR_FILL = ART.classic.fill
local CAST_FILL, CAST_BG = "UI-CastingBar-Full-Standard", "UI-CastingBar-Background"

-- Bar height to Blizzard's units for a style (k = 1 at Blizzard's own height).
local function Scale(style, bar)
    local a = ART[style]
    local h = bar and bar.GetHeight and bar:GetHeight() or nil
    if type(h) ~= "number" or h <= 0 then h = a and a.baseH or 10 end
    return h / ((a and a.baseH) or 10)
end
ns.NameplateStyleScale = Scale

-- Puts a cropped texture file on a texture region.
local function SetArt(tex, art)
    tex:SetTexture(art.file)
    if tex.SetTexCoord then tex:SetTexCoord(art.l / art.w, art.r / art.w, art.t / art.h, art.b / art.h) end
end
ns.SetNameplateArt = SetArt

-- Rounds a length to whole screen pixels for `region` (KT.PP.Scale), so the art stays sharp.
local function Px(v, region)
    local PP = KT and KT.PP
    if PP and PP.Scale then return PP.Scale(v, region) end
    return math.floor(v + 0.5)
end

-- Nine-slice texture, drawn the way the client draws a sliced atlas. The returned texture only
-- holds the box (it draws nothing); `pieces` are the nine parts around it.
local function NewSliced(parent, layer, sub)
    local box = parent:CreateTexture(nil, layer, nil, sub or 0)
    box:SetAlpha(0)
    box.pieces = {}
    for i = 1, 9 do box.pieces[i] = parent:CreateTexture(nil, layer, nil, sub or 0) end
    return box
end

local function ShowSliced(t, show)
    if not t then return end
    t:SetShown(show and true or false)
    if t.pieces then
        for _, p in ipairs(t.pieces) do p:SetShown(show and true or false) end
    end
end

local function ColorSliced(t, r, g, b, a)
    for _, p in ipairs(t.pieces or {}) do p:SetVertexColor(r, g, b, a or 1) end
end

-- Lays the nine pieces on `t`'s box. m: margins in Blizzard units, k: style scale, w/h: the box
-- size when known. A box narrower than both side margins keeps the right end whole and cuts the
-- long left part, as the art there is a straight edge.
local function LayoutSliced(t, art, m, k, w, h, region)
    local L, T, R, B = m[1] * k, m[2] * k, m[3] * k, m[4] * k
    if w and w > 0 and L + R > w then
        R = math.min(R, w); L = w - R
    end
    if h and h > 0 and T + B > h then
        local s = h / (T + B); T, B = T * s, B * s
    end
    L, T, R, B = Px(L, region), Px(T, region), Px(R, region), Px(B, region)
    local px = art.px or 1
    local us = { art.l, art.l + L / k * px, art.r - R / k * px, art.r }
    local vs = { art.t, art.t + T / k * px, art.b - B / k * px, art.b }
    local cols = { { "LEFT", 0, "LEFT", L }, { "LEFT", L, "RIGHT", -R }, { "RIGHT", -R, "RIGHT", 0 } }
    local rows = { { "TOP", 0, "TOP", -T }, { "TOP", -T, "BOTTOM", B }, { "BOTTOM", B, "BOTTOM", 0 } }
    for r = 1, 3 do
        for c = 1, 3 do
            local p, col, row = t.pieces[(r - 1) * 3 + c], cols[c], rows[r]
            p:SetTexture(art.file)
            p:SetTexCoord(us[c] / art.w, us[c + 1] / art.w, vs[r] / art.h, vs[r + 1] / art.h)
            p:ClearAllPoints()
            p:SetPoint("TOPLEFT", t, row[1] .. col[1], col[2], row[2])
            p:SetPoint("BOTTOMRIGHT", t, row[3] .. col[3], col[4], row[4])
        end
    end
    return L, T, R, B
end

-- Rounds a length UP to whole screen pixels for `region`.
local function PxUp(v, region)
    local s = region and region.GetEffectiveScale and region:GetEffectiveScale()
    if type(s) ~= "number" or s <= 0 then s = 1 end
    return math.ceil(v * s - 0.01) / s
end

local function Solid(parent, layer, sub, r, g, b, a)
    local t = parent:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture(WHITE)
    t:SetVertexColor(r, g, b, a or 1)
    return t
end

-- ---------------------------------------------------------------------------------------------
-- Classic border: Nameplate-Border's lower half, cut in three so the bar part stretches with the
-- bar and the ends keep their shape. Texel columns 0-6 left end, 6-104 bar, 104-136 level pill;
-- rows 16-32. One texel is one Blizzard unit; the bar sits from column 3.5 to 107.5 and its
-- centre on row 23.5 (Blizzard: bar inset 3.5 / 20.75 in a 128-wide container, border centred).
-- ---------------------------------------------------------------------------------------------
local CLASSIC_SLICES = { { 0, 6 }, { 6, 104 }, { 104, 136 } }
local CLASSIC_BAR_LEFT, CLASSIC_BAR_RIGHT, CLASSIC_BAR_MID = 3.5, 107.5, 23.5
local CLASSIC_LEVEL_X = 120.5        -- centre of the level pill in the art (columns 106-135)

local function LayoutClassicBorder(f, bar, s)
    local half = (bar:GetHeight() or 10) / 2
    local top = Px((CLASSIC_BAR_MID - 16) * s - half, bar)     -- border top above the bar top
    local bottom = Px((32 - CLASSIC_BAR_MID) * s - half, bar)  -- border bottom below the bar bottom
    local left, mid, right = f.classicBorder[1], f.classicBorder[2], f.classicBorder[3]
    local leftEdge = Px(CLASSIC_BAR_LEFT * s, bar)
    local capEnd = Px((6 - CLASSIC_BAR_LEFT) * s, bar)
    local pillStart = Px((CLASSIC_BAR_RIGHT - 104) * s, bar)
    local pillEnd = Px((136 - CLASSIC_BAR_RIGHT) * s, bar)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", bar, "TOPLEFT", -leftEdge, top)
    left:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", capEnd, -bottom)
    mid:ClearAllPoints()
    mid:SetPoint("TOPLEFT", bar, "TOPLEFT", capEnd, top)
    mid:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -pillStart, -bottom)
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT", bar, "TOPRIGHT", -pillStart, top)
    right:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", pillEnd, -bottom)
end

-- Classic cast bar keeps a thin gold rim (the Classic cast border needs an icon slot we do not have).
local function BuildClassicCastRim(f, bar)
    local list = {}
    local BLACK, GOLD = { 0.02, 0.02, 0.02 }, { 0.56, 0.51, 0.40 }
    local function Line(color, p1, x1, y1, p2, x2, y2, horizontal)
        local t = Solid(f, "OVERLAY", 6, color[1], color[2], color[3], 1)
        t:SetPoint(p1, bar, p1, x1, y1)
        t:SetPoint(p2, bar, p2, x2, y2)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
        list[#list + 1] = t
    end
    Line(BLACK, "TOPLEFT", 1, 2, "TOPRIGHT", -1, 2, true)
    Line(BLACK, "BOTTOMLEFT", 1, -2, "BOTTOMRIGHT", -1, -2, true)
    Line(BLACK, "TOPLEFT", -2, -1, "BOTTOMLEFT", -2, 1, false)
    Line(BLACK, "TOPRIGHT", 2, -1, "BOTTOMRIGHT", 2, 1, false)
    Line(GOLD, "TOPLEFT", 0, 1, "TOPRIGHT", 0, 1, true)
    Line(GOLD, "BOTTOMLEFT", 0, -1, "BOTTOMRIGHT", 0, -1, true)
    Line(GOLD, "TOPLEFT", -1, 0, "BOTTOMLEFT", -1, 0, false)
    Line(GOLD, "TOPRIGHT", 1, 0, "BOTTOMRIGHT", 1, 0, false)
    return list
end

local function Build(plate, bar, key)
    local f = CreateFrame("Frame", nil, bar)
    f:SetAllPoints(bar)
    f:SetFrameLevel(bar:GetFrameLevel() + 6)
    f.key = key

    -- Blizzard background / frame atlas, under the fill (Retail and Forever).
    if key == "cast" then
        f.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
        f.bg:SetAtlas(CAST_BG)
        f.classicRim = BuildClassicCastRim(f, bar)
        return f
    end
    f.bg = NewSliced(bar, "BACKGROUND", -7)


    -- Selection frame (target), drawn over the bar frame.
    f.selected = NewSliced(f, "OVERLAY", 6)
    ShowSliced(f.selected, false)
    -- Blizzard darkens every plate that is not the target.
    f.deselected = f:CreateTexture(nil, "OVERLAY", nil, 1)
    SetArt(f.deselected, DESELECTED)
    f.deselected:Hide()

    -- Classic: the border in three slices, over the fill (Blizzard draws it on ARTWORK 1).
    f.classicBorder = {}
    for i, sl in ipairs(CLASSIC_SLICES) do
        local t = f:CreateTexture(nil, "ARTWORK", nil, 1)
        t:SetTexture(CLASSIC_BORDER)
        t:SetTexCoord(sl[1] / 256, sl[2] / 256, 0.5, 1)
        f.classicBorder[i] = t
    end
    -- Classic target highlight: the bar fill texture added on top at 25%.
    f.classicHighlight = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.classicHighlight:SetTexture(CLASSIC_BAR_FILL)
    f.classicHighlight:SetAllPoints(bar)
    if f.classicHighlight.SetBlendMode then f.classicHighlight:SetBlendMode("ADD") end
    f.classicHighlight:SetAlpha(0.25)
    f.classicHighlight:Hide()
    return f
end

local function ShowList(list, show)
    if not list then return end
    for _, t in ipairs(list) do t:SetShown(show) end
end

local function LayoutAtlasFrame(f, bar, style)
    local a = ART[style]
    local k = Scale(style, bar)
    local o = a.bgOffsets
    local bx1, by1, bx2, by2 = Px(o[1] * k, bar), Px(o[2] * k, bar), Px(o[3] * k, bar), Px(o[4] * k, bar)
    f.bg:ClearAllPoints()
    f.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", bx1, by1)
    f.bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", bx2, by2)
    -- Box size for the slices; unknown (nil) while the bar has no size yet.
    local barW = bar.GetWidth and bar:GetWidth() or 0
    local barH = bar.GetHeight and bar:GetHeight() or 0
    local bw = barW > 0 and barW + bx2 - bx1 or nil
    local bh = barH > 0 and barH + by1 - by2 or nil
    -- The frame's inner rim sits inside its slice margins (at offset / margin of each one). Rounded
    -- on their own, the margins and the offsets can put the rim a pixel inside the bar, and the fill
    -- then covers it. Place the frame from the rounded margins, rim always outside the fill.
    local m = a.bgSlice
    local L, T, R, B = LayoutSliced(f.bg, a.bg, m, k, bw, bh, bar)
    bx1, by1 = -PxUp(L * -o[1] / m[1], bar), PxUp(T * o[2] / m[2], bar)
    bx2, by2 = PxUp(R * o[3] / m[3], bar), -PxUp(B * -o[4] / m[4], bar)
    f.bg:ClearAllPoints()
    f.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", bx1, by1)
    f.bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", bx2, by2)
    bw = barW > 0 and barW + bx2 - bx1 or nil
    bh = barH > 0 and barH + by1 - by2 or nil
    LayoutSliced(f.bg, a.bg, m, k, bw, bh, bar)
    local so = a.selectedOffsets
    local sx1, sy1, sx2, sy2 = Px(so[1] * k, bar), Px(so[2] * k, bar), Px(so[3] * k, bar), Px(so[4] * k, bar)
    f.selected:ClearAllPoints()
    f.selected:SetPoint("TOPLEFT", f.bg, "TOPLEFT", sx1, sy1)
    f.selected:SetPoint("BOTTOMRIGHT", f.bg, "BOTTOMRIGHT", sx2, sy2)
    LayoutSliced(f.selected, a.selected, a.selectedSlice, k,
        bw and bw + sx2 - sx1, bh and bh + sy1 - sy2, bar)
    f.deselected:ClearAllPoints()
    f.deselected:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, Px(k, bar))
    f.deselected:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -Px(k, bar))
end

local function SkinBar(plate, bar, bg, field, key, theme)
    if not bar then return end
    local f = plate[field]
    if not NATIVE[theme] then
        if f then
            f:Hide()
            -- These background textures belong to the bar, not the skin frame.
            ShowSliced(f.bg, false)
        end
        if bg and plate["_skinBG" .. key] then
            local o = plate["_skinBG" .. key]
            bg:SetColorTexture(o[1], o[2], o[3], o[4]); plate["_skinBG" .. key] = nil
        end
        return false
    end
    if not f then f = Build(plate, bar, key); plate[field] = f end
    f:Show()
    f.style = theme
    local classic = theme == "classic"
    if key == "cast" then
        ShowList(f.classicRim, classic)
        f.bg:SetShown(not classic)
        if not classic then
            f.bg:ClearAllPoints()
            f.bg:SetAllPoints(bar)
        end
    else
        ShowSliced(f.bg, not classic)
        ShowList(f.classicBorder, classic)
        if classic then
            LayoutClassicBorder(f, bar, Scale("classic", bar))
            ShowSliced(f.selected, false); f.deselected:Hide()
        else
            f.classicHighlight:Hide()
            LayoutAtlasFrame(f, bar, theme)
        end
    end
    if bg then
        if not plate["_skinBG" .. key] then
            plate["_skinBG" .. key] = (key == "health") and { 0.12, 0.12, 0.12, 1 } or { 0.1, 0.1, 0.1, 0.9 }
        end
        if classic then
            bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)       -- empty part of the Classic bar
        else
            bg:SetColorTexture(0, 0, 0, 0)                   -- Blizzard's background atlas paints it
        end
    end
    return true
end

-- Target selection on a native plate: Forever / Retail show Blizzard's selection frame and darken
-- the other plates; Classic adds its highlight to the bar. Returns true when the style draws its
-- own selection (the generic glow then stays hidden).
function ns.ApplyThemeTargetGlow(plate, isTarget, wanted)
    local f = plate and plate._skinHealth
    local style = RenderedTheme()
    if not (f and NATIVE[style] and f.style == style) then return false end
    local show = isTarget and wanted ~= false
    if style == "classic" then
        f.classicHighlight:SetShown(show)
    else
        ColorSliced(f.selected, 1, 1, 1, 1)
        ShowSliced(f.selected, show)
        f.deselected:SetShown(wanted ~= false and not isTarget)
    end
    local box = plate._fvBadge
    if box and box.selected then ShowSliced(box.selected, style == "forever" and show) end
    return true
end

function ns.RestoreKuiBarTextures(plate)
    -- Theme refreshes/previews do not always run RefreshPlateState first.
    -- Re-resolve the current profile instead of retaining the native fill.
    if ns.ApplyHealthBarTexture then ns.ApplyHealthBarTexture(plate) end
    if ns.ApplyCastBarTexture then ns.ApplyCastBarTexture(plate) end
    for _, bar in ipairs({ plate.health, plate.cast }) do
        local fill = bar:GetStatusBarTexture()
        if fill and fill.SetTexCoord then fill:SetTexCoord(0, 1, 0, 1) end
    end
end

function ns.ApplyThemeBarFill(bar, key, theme)
    if not bar then return end
    if theme == "classic" then
        bar:SetStatusBarTexture(key == "cast" and "Interface\\TargetingFrame\\UI-StatusBar" or CLASSIC_BAR_FILL)
        local fill = bar:GetStatusBarTexture()
        if fill and fill.SetTexCoord then fill:SetTexCoord(0, 1, 0, 1) end
    elseif theme == "retail" or theme == "forever" then
        -- Atlas names are not file paths. Bind a neutral fill, then apply the
        -- atlas to that texture so Blizzard's crop coordinates are retained.
        bar:SetStatusBarTexture(WHITE)
        local fill = bar:GetStatusBarTexture()
        if fill and fill.SetAtlas then
            pcall(fill.SetAtlas, fill, key == "cast" and CAST_FILL or ART[theme].fill)
        end
    end
end

function ns.ApplyThemeSkin(plate)
    if not plate or not plate.health then return end
    local theme = RenderedTheme()
    local skinned = SkinBar(plate, plate.health, plate.healthBG, "_skinHealth", "health", theme)
    SkinBar(plate, plate.cast, plate.castBG, "_skinCast", "cast", theme)
    -- el borde generico de KUI se oculta cuando el skin del tema manda
    if skinned then
        if plate.borderFrame then plate.borderFrame:Hide() end
        if plate._simpleBorderFrame then plate._simpleBorderFrame:Hide() end
        ns.ApplyThemeBarFill(plate.health, "health", theme)
        ns.ApplyThemeBarFill(plate.cast, "cast", theme)
        if (theme == "classic" or theme == "forever") and plate.name then
            local nf, _, nfl = plate.name:GetFont()
            local sz = ((ns.GetEnemyNameTextSize and ns.GetEnemyNameTextSize()) or 10) + (theme == "classic" and 3 or 2)
            if nf then plate.name:SetFont(nf, sz, nfl or "OUTLINE") end
        end
    else
        -- Also normalize profiles loaded directly into KUI, without a prior skin.
        ns.RestoreKuiBarTextures(plate)
        if plate._skinHealth and plate.ApplyBorderStyle then plate:ApplyBorderStyle() end
    end
end

function ns.RefreshThemeSkin()
    if not ns.plates then return end
    for _, plate in pairs(ns.plates) do
        ns.ApplyThemeSkin(plate)
        if plate.RefreshPlateState then pcall(plate.RefreshPlateState, plate) end
    end
end

if KT then KT.RefreshNameplateTheme = function() ns.RefreshThemeSkin() end end

-- ---------------------------------------------------------------------------------------------
-- Elite / rare icon: Blizzard puts it left of the bar (right edge on the bar's left edge, Classic:
-- on its border's left edge), 20 units square, centred on the bar.
-- ---------------------------------------------------------------------------------------------
function ns.ThemeClassificationLeft()
    return NATIVE[RenderedTheme()] == true
end

-- Blizzard's dragon atlases leave about 4% empty on each side.
local CLASSIFICATION_VISIBLE = 0.92

function ns.PlaceThemeClassification(frame, health)
    if not (frame and health) then return end
    local style = RenderedTheme()
    local k = Scale(style, health)
    local size = Px(20 * k, health)
    frame:SetSize(size, size)
    if frame.SetFrameLevel then frame:SetFrameLevel(health:GetFrameLevel() + 9) end   -- over the bar frame (+6)
    frame:ClearAllPoints()
    if style == "classic" then
        frame:SetPoint("RIGHT", health, "LEFT", -Px(CLASSIC_BAR_LEFT * k, health), -Px(0.5 * k, health))
    else
        frame:SetPoint("RIGHT", health, "LEFT", 0, 0)
    end
    frame._themeVisibleWidth = size * CLASSIFICATION_VISIBLE
    frame._themeLeftInset = (style == "classic") and Px(CLASSIC_BAR_LEFT * k, health) or 0
end

-- Room the classification icon takes left of the bar (0 when hidden or in KUI).
function ns.ThemeClassificationWidth(plate)
    local cf = plate and plate.classFrame
    if not (cf and cf:IsShown() and ns.ThemeClassificationLeft()) then return 0 end
    return (cf._themeLeftInset or 0) + (cf._themeVisibleWidth or cf:GetWidth() or 0)
end

-- Yellow "!" just left of the bar on mobs you still need for a quest (every style).
function ns.ApplyThemeQuestIcon(plate, th)
    local health = plate and plate.health
    if not health then return end
    local qi = plate._fvQuest
    th = th or RenderedTheme()
    local show = plate._previewQuest or (plate.unit and ns.IsQuestMob and ns.IsQuestMob(plate.unit))
    if not show then
        if qi then qi:Hide() end
        return
    end
    if not qi then
        qi = plate:CreateFontString(nil, "OVERLAY")
        plate._fvQuest = qi
    end
    local barH = health:GetHeight() or 16
    local font = plate.level and plate.level:GetFont() or STANDARD_TEXT_FONT
    qi:SetFont(font, math.floor(barH + 4), "OUTLINE")
    qi:SetText("!")
    qi:SetTextColor(1, 0.86, 0.10, 1)
    qi:ClearAllPoints()
    qi:SetPoint("RIGHT", health, "LEFT", -ns.ThemeQuestGap(plate, th), 0)
    qi:Show()
end

-- Gap between the bar and the quest icon: past the style's frame and the elite icon.
function ns.ThemeQuestGap(plate, th)
    th = th or RenderedTheme()
    local health = plate and plate.health
    local gap = 5
    if (th == "retail" or th == "forever") and health then
        gap = Px(-ART[th].bgOffsets[1] * Scale(th, health), health) + 3
    elseif th == "classic" and health then
        gap = Px(CLASSIC_BAR_LEFT * Scale(th, health), health) + 3
    end
    local dragon = ns.ThemeClassificationWidth(plate)
    if dragon > 0 then gap = math.max(gap, dragon + 3) end
    return gap
end

-- Difficulty colour of the plate's unit level (yellow when unknown), as Blizzard colours it.
-- Enemies by difficulty (ns.LevelTextDifficultyColor), everyone else in the style's colour.
local function LevelColor(plate, r, g, b)
    if plate.unit and ns.LevelTextDifficultyColor then
        local dr, dg, db = ns.LevelTextDifficultyColor(plate.unit)
        if dr then return dr, dg, db end
    end
    return r or 1, g or 0.82, b or 0
end

local function LevelText(level)
    local okT, txt = pcall(level.GetText, level)
    if not okT or (issecretvalue and issecretvalue(txt)) then return "" end
    return txt or ""
end

-- Forever: Blizzard's level box right of the bar (NameplateLevelFrame), with its own selection frame.
local function ApplyForeverLevel(plate, level, health)
    local box = plate._fvBadge
    if not box then
        box = CreateFrame("Frame", nil, plate)
        box.bg = box:CreateTexture(nil, "BACKGROUND")
        box.bg:SetAllPoints(box)
        box.selected = NewSliced(box, "OVERLAY", 2)
        ShowSliced(box.selected, false)
        box.txt = box:CreateFontString(nil, "OVERLAY")
        box.txt:SetPoint("CENTER", box, "CENTER", 0, 0)
        box.txt:SetJustifyH("CENTER")
        plate._fvBadge = box
    end
    local a = ART.forever
    local k = Scale("forever", health)
    SetArt(box.bg, a.level)
    box:SetFrameLevel(health:GetFrameLevel() + 8)
    box:ClearAllPoints()
    -- Blizzard: TOPLEFT at the bar's TOPRIGHT (+5, +3), BOTTOMLEFT at its BOTTOMRIGHT (+5, -2), 28 wide.
    local top, bottom, width = Px(3 * k, health), Px(2 * k, health), Px(28 * k, health)
    box:SetPoint("TOPLEFT", health, "TOPRIGHT", Px(5 * k, health), top)
    box:SetPoint("BOTTOMLEFT", health, "BOTTOMRIGHT", Px(5 * k, health), -bottom)
    box:SetWidth(width)
    local s3, s4 = Px(3 * k, health), Px(4 * k, health)
    box.selected:ClearAllPoints()
    box.selected:SetPoint("TOPLEFT", box, "TOPLEFT", -s3, s3)
    box.selected:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", s3, -s4)
    local barH = health.GetHeight and health:GetHeight() or 0
    LayoutSliced(box.selected, a.levelSelected, a.levelSelectedSlice, k, width + 2 * s3,
        barH > 0 and barH + top + bottom + s3 + s4 or nil, health)
    ColorSliced(box.selected, 1, 1, 1, 1)
    box.txt:SetFont(level:GetFont() or STANDARD_TEXT_FONT, math.max(8, math.floor(10 * k + 0.5)), "OUTLINE")
    box.txt:SetTextColor(LevelColor(plate))
    box.txt:SetText(LevelText(level))
    box._themeWidth = Px(5 * k, health) + Px(28 * k, health)
    level:SetAlpha(0)
    box:SetShown(level:IsShown() and true or false)
end

-- Classic: the level sits in the border's pill.
local function ApplyClassicLevel(plate, level, health)
    local holder = plate._clBadge
    if not holder then
        holder = CreateFrame("Frame", nil, plate)
        holder.txt = holder:CreateFontString(nil, "OVERLAY")
        holder.txt:SetPoint("CENTER", holder, "CENTER", 0, 0)
        holder.txt:SetJustifyH("CENTER")
        holder.txt:SetShadowColor(0, 0, 0, 1)
        holder.txt:SetShadowOffset(1, -1)
        plate._clBadge = holder
    end
    local s = Scale("classic", health)
    holder:SetFrameLevel(health:GetFrameLevel() + 8)
    holder:SetSize(Px(26 * s, health), Px(12 * s, health))
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", health, "RIGHT", Px((CLASSIC_LEVEL_X - CLASSIC_BAR_RIGHT) * s, health), -Px(0.5 * s, health))
    holder.txt:SetFont(level:GetFont() or STANDARD_TEXT_FONT, math.max(8, math.floor(9 * s + 0.5)), "")
    holder.txt:SetTextColor(LevelColor(plate))
    holder.txt:SetText(LevelText(level))
    holder._themeWidth = Px((136 - CLASSIC_BAR_RIGHT) * s, health)
    level:SetAlpha(0)
    holder:SetShown(level:IsShown() and true or false)
end

function ns.ApplyThemeLevel(plate)
    local level, health = plate and plate.level, plate and plate.health
    if not (level and health) then return end
    local th = RenderedTheme()
    ns.ApplyThemeQuestIcon(plate, th)
    if plate._fvBadge and th ~= "forever" then plate._fvBadge:Hide() end
    if plate._clBadge and th ~= "classic" then plate._clBadge:Hide() end
    if plate._blzBadge and th ~= "retail" then plate._blzBadge:Hide() end
    if th == "forever" then return ApplyForeverLevel(plate, level, health) end
    if th == "classic" then return ApplyClassicLevel(plate, level, health) end
    if th ~= "retail" then
        level:SetAlpha(1)
        level:SetJustifyH("RIGHT")
        return
    end
    -- Retail: Blizzard's Modern plate has no level; KUI adds it in white at the start of the bar,
    -- as tall as the bar, and the name moves right of it (ns.ThemeLevelInset).
    local bb = plate._blzBadge
    if not bb then
        bb = CreateFrame("Frame", nil, plate)
        bb.txt = bb:CreateFontString(nil, "OVERLAY")
        bb.txt:SetPoint("CENTER", bb, "CENTER", 0, 0)
        bb.txt:SetJustifyH("CENTER")
        plate._blzBadge = bb
    end
    bb:SetFrameLevel(health:GetFrameLevel() + 8)
    local barH = health:GetHeight() or 16
    local size = math.max(8, math.floor(barH * 0.85))
    bb:SetSize(size * 1.4, barH)
    bb:ClearAllPoints()
    bb:SetPoint("LEFT", health, "LEFT", 3, 0)
    local font = level:GetFont()
    if font then bb.txt:SetFont(font, size, "OUTLINE") end
    bb.txt:SetTextColor(LevelColor(plate, 1, 1, 1))
    bb.txt:SetText(LevelText(level))
    level:SetAlpha(0)
    bb:SetShown(level:IsShown() and true or false)
end

-- Room the Retail level inside the bar takes left of the name.
function ns.ThemeLevelInset(plate)
    local th = RenderedTheme()
    if th ~= "retail" then return 0 end
    local lv, health = plate and plate.level, plate and plate.health
    if not (lv and health and lv:IsShown()) then return 0 end
    local size = math.max(8, math.floor((health:GetHeight() or 16) * 0.85))
    return size * 1.4 + 3
end

-- Default bar height per style (the player's own height wins). The art scales from
-- Blizzard's height (ART[style].baseH) to this one.
local DEFAULT_BAR_HEIGHT = { classic = 15, retail = 23, forever = 17 }

function ns.ThemeBarHeight()
    return DEFAULT_BAR_HEIGHT[RenderedTheme()]
end

-- Options live preview: applies the active style to the preview's own bars, texts and border.
function ns.ApplyThemePreview(pf, health, healthBG, cast, castBG, nameFS, levelFS, border, simpleBorder)
    if not (pf and health) then return end
    local p = pf._themeProxy
    if not p then
        p = CreateFrame("Frame", nil, pf)
        p:SetAllPoints(pf)
        p._previewQuest = true
        pf._themeProxy = p
    end
    p.health, p.healthBG, p.cast, p.castBG = health, healthBG, cast, castBG
    p.name, p.level = nameFS, levelFS
    p.borderFrame, p._simpleBorderFrame = border, simpleBorder
    ns.ApplyThemeSkin(p)
    ns.ApplyThemeLevel(p)
end

-- Ancho extra de barra por tema (solo si el usuario no fijo healthBarWidth).
function ns.ThemeBarWidthExtra()
    if RenderedTheme() == "classic" then return 85 end
    return nil
end

-- Room the quest icon, elite icon and level box take beside the bar: side auras start after it.
function ns.ThemeSideOccupied(plate)
    local l, r = 0, 0
    local qi = plate and plate._fvQuest
    if qi and qi:IsShown() then
        l = math.max(l, ns.ThemeQuestGap(plate) + (qi:GetStringWidth() or 0))
    end
    l = math.max(l, ns.ThemeClassificationWidth(plate))
    for _, key in ipairs({ "_fvBadge", "_clBadge" }) do
        local b = plate and plate[key]
        if b and b:IsShown() then r = math.max(r, b._themeWidth or b:GetWidth() or 0) end
    end
    return l, r
end

-- The same room with the style's frame edge, so the target arrows sit outside it.
function ns.ThemeLateralExtent(plate)
    local th = RenderedTheme()
    local el, er = 0, 0
    local health = plate and plate.health
    if (th == "retail" or th == "forever") and health then
        local k, o = Scale(th, health), ART[th].bgOffsets
        el, er = -o[1] * k, o[3] * k
    elseif th == "classic" and health then
        local s = Scale("classic", health)
        el, er = CLASSIC_BAR_LEFT * s, (136 - CLASSIC_BAR_RIGHT) * s
    end
    local l, r = ns.ThemeSideOccupied(plate)
    return math.max(el, l), math.max(er, r)
end

-- Refresh the quest icons when the quest log changes.
local questRefresh = CreateFrame("Frame")
questRefresh:RegisterEvent("QUEST_LOG_UPDATE")
questRefresh:SetScript("OnEvent", function(self)
    if self.pending or not ns.plates then return end
    self.pending = true
    C_Timer.After(0.2, function()
        self.pending = nil
        for _, plate in pairs(ns.plates) do
            ns.ApplyThemeQuestIcon(plate)
            if ns.NPC_AnchorSides then ns.NPC_AnchorSides(plate) end
        end
    end)
end)

function ns.ThemeBlizzText()
    return RenderedTheme() == "retail"
end
