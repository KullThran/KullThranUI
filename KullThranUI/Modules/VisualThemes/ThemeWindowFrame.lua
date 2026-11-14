local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

--[[
    ThemeWindowFrame.lua

    Outer frame of the active Visual Style around a KUI window (Bags, ...),
    built like the chat styles (KullThranUI_Chat/Modules/Chat_Styles.lua) and
    the minimap's square frame:
      forever  nine-slice of the bronze frame packaged in media\chat\chat_forever.tga
      retail   nine-slice of the grey frame packaged in media\chat\chat_retail.tga
      classic  the gold dialog edge (UI-DialogBox-Gold-Border), as a backdrop
      kui      nothing: the window keeps its own flat border
    The packaged art is cropped from each client's own atlases, so Retail and
    Forever look the same on either client. The frame sits just outside the
    window and never takes the mouse.
]]

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\chat\\"

-- rect = { x, y, w, h } in sheet pixels; corner = corner size in the sheet;
-- edge = drawn corner size; outset = how far the frame sits outside the window.
local FRAMES = {
    forever = { file = MEDIA .. "chat_forever.tga", w = 512, h = 256, rect = { 35, 1, 80, 80 },
        corner = 14, edge = 10, outset = 5 },
    retail = { file = MEDIA .. "chat_retail.tga", w = 256, h = 256, rect = { 1, 1, 22, 22 },
        corner = 7, edge = 8, outset = 3 },
}
local CLASSIC = { edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 16, outset = 6 }

local SLICES = { "TL", "T", "TR", "L", "R", "BL", "B", "BR" }

local function EnsureFrame(window)
    local frame = window._ktThemeWindowFrame
    if frame then return frame end
    frame = CreateFrame("Frame", nil, window, "BackdropTemplate")
    frame:EnableMouse(false)
    frame.slices = {}
    for _, name in ipairs(SLICES) do
        frame.slices[name] = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    end
    window._ktThemeWindowFrame = frame
    return frame
end

local function LayoutSlices(frame, def)
    local x, y, w, h = def.rect[1], def.rect[2], def.rect[3], def.rect[4]
    local c = def.corner
    local L, R, T, B = x / def.w, (x + w) / def.w, y / def.h, (y + h) / def.h
    local cl, cr = (x + c) / def.w, (x + w - c) / def.w
    local ct, cb = (y + c) / def.h, (y + h - c) / def.h
    local coords = {
        TL = { L, cl, T, ct }, T = { cl, cr, T, ct }, TR = { cr, R, T, ct },
        L = { L, cl, ct, cb }, R = { cr, R, ct, cb },
        BL = { L, cl, cb, B }, B = { cl, cr, cb, B }, BR = { cr, R, cb, B },
    }
    local s, e = frame.slices, def.edge
    for _, name in ipairs(SLICES) do
        s[name]:SetTexture(def.file)
        s[name]:SetTexCoord(unpack(coords[name]))
        s[name]:SetVertexColor(1, 1, 1, 1)
        s[name]:ClearAllPoints()
        s[name]:Show()
    end
    s.TL:SetSize(e, e); s.TL:SetPoint("TOPLEFT")
    s.TR:SetSize(e, e); s.TR:SetPoint("TOPRIGHT")
    s.BL:SetSize(e, e); s.BL:SetPoint("BOTTOMLEFT")
    s.BR:SetSize(e, e); s.BR:SetPoint("BOTTOMRIGHT")
    s.T:SetPoint("TOPLEFT", s.TL, "TOPRIGHT"); s.T:SetPoint("BOTTOMRIGHT", s.TR, "BOTTOMLEFT")
    s.B:SetPoint("TOPLEFT", s.BL, "TOPRIGHT"); s.B:SetPoint("BOTTOMRIGHT", s.BR, "BOTTOMLEFT")
    s.L:SetPoint("TOPLEFT", s.TL, "BOTTOMLEFT"); s.L:SetPoint("BOTTOMRIGHT", s.BL, "TOPRIGHT")
    s.R:SetPoint("TOPLEFT", s.TR, "BOTTOMLEFT"); s.R:SetPoint("BOTTOMRIGHT", s.BR, "TOPRIGHT")
end

-- Frames `window` for `styleKey` (default: the rendered Visual Style).
-- Returns the frame, or nil when the style draws none (KUI Style).
function KT.VisualThemes:ApplyWindowFrame(window, styleKey)
    if not (window and window.CreateTexture) then return nil end
    styleKey = styleKey or (self.GetRenderedTheme and self:GetRenderedTheme()) or "kui"
    local def, classic = FRAMES[styleKey], styleKey == "classic"
    local frame = window._ktThemeWindowFrame
    if not def and not classic then
        if frame then frame:Hide() end
        return nil
    end
    frame = EnsureFrame(window)
    for _, name in ipairs(SLICES) do frame.slices[name]:Hide() end
    if frame.SetBackdrop then frame:SetBackdrop(nil) end

    local outset = def and def.outset or CLASSIC.outset
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", window, "TOPLEFT", -outset, outset)
    frame:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", outset, -outset)
    -- Above the window's own panels: only its outer few pixels overlap them.
    frame:SetFrameStrata(window:GetFrameStrata())
    frame:SetFrameLevel((window:GetFrameLevel() or 0) + 20)

    if def then
        LayoutSlices(frame, def)
    elseif frame.SetBackdrop then
        frame:SetBackdrop({ edgeFile = CLASSIC.edgeFile, edgeSize = CLASSIC.edgeSize })
        frame:SetBackdropBorderColor(1, 1, 1, 1)
    end
    frame:Show()
    return frame
end

-------------------------------------------------------------------------------
--  Per-module style choice (like the Chat and Cast Bar styles)
--  db.styleByTheme[<visual style>] = "kui" | "forever" | "retail" | "classic";
--  without a choice every Visual Style uses its own look.
-------------------------------------------------------------------------------
local STYLE_ORDER = { "kui", "forever", "retail", "classic" }
local STYLE_LABELS = { kui = "KUI Style", forever = "Forever", retail = "Retail", classic = "Classic" }
local STYLE_ACCENTS = { forever = { 0.862745, 0.521569, 0.376471 }, classic = { 1.00, 0.82, 0.10 } }
KT.VisualThemes.WINDOW_STYLE_ORDER = STYLE_ORDER

local function ActiveTheme(vt)
    return (vt.GetRenderedTheme and vt:GetRenderedTheme()) or "kui"
end

function KT.VisualThemes:ResolveModuleStyle(db)
    local theme = ActiveTheme(self)
    local map = db and db.styleByTheme
    local choice = type(map) == "table" and map[theme] or nil
    if STYLE_LABELS[choice] then return choice end
    return STYLE_LABELS[theme] and theme or "kui"
end

function KT.VisualThemes:SetModuleStyle(db, key)
    if not db then return end
    db.styleByTheme = type(db.styleByTheme) == "table" and db.styleByTheme or {}
    db.styleByTheme[ActiveTheme(self)] = STYLE_LABELS[key] and key or nil
end

local function StyleAccent(key)
    if STYLE_ACCENTS[key] then return unpack(STYLE_ACCENTS[key]) end
    if key == "retail" then
        local _, class = UnitClass("player")
        local color = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if color then return color.r, color.g, color.b end
    end
    return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333
end

-------------------------------------------------------------------------------
--  Style card skin (the module style pickers: Armory, Bags, Chat, Party Frames)
--  White art baked by tools/style_cards.py, tinted with the card's accent:
--    fill       rounded dark body (nine-slice)
--    glow_*     colour pooling low on the card (side blobs + a lighter middle)
--    shine      inset light rising from the bottom edge
--    border     rounded ring, dim at the top and bright at the bottom
--    beam       a band of light that turns behind the ring (masked by it)
-------------------------------------------------------------------------------
local CARD_TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\StyleCards\\"
local CARD_RADIUS = 12
-- The KUI Style card is always crimson, whatever the KUI accent is.
local KUI_CRIMSON = { 0.86, 0.08, 0.24 }
local function CardAccent(key, r, g, b)
    if key == "kui" then return KUI_CRIMSON[1], KUI_CRIMSON[2], KUI_CRIMSON[3] end
    return r, g, b
end
local BEAM_SPEED = math.pi / 4 -- one turn every 8 seconds
local NINE = {
    { "TOPLEFT", 0, 0.25, 0, 0.25 }, { "TOP", 0.25, 0.75, 0, 0.25 }, { "TOPRIGHT", 0.75, 1, 0, 0.25 },
    { "LEFT", 0, 0.25, 0.25, 0.75 }, { "CENTER", 0.25, 0.75, 0.25, 0.75 }, { "RIGHT", 0.75, 1, 0.25, 0.75 },
    { "BOTTOMLEFT", 0, 0.25, 0.75, 1 }, { "BOTTOM", 0.25, 0.75, 0.75, 1 }, { "BOTTOMRIGHT", 0.75, 1, 0.75, 1 },
}

local function Gradient(tex, bottom, top, alpha)
    if tex.SetGradient and CreateColor then
        tex:SetGradient("VERTICAL", CreateColor(bottom[1], bottom[2], bottom[3], alpha),
            CreateColor(top[1], top[2], top[3], alpha))
    else
        tex:SetVertexColor(top[1], top[2], top[3], alpha)
    end
end

-- Nine slices of a 64x64 sheet with 16 px corners, drawn with `corner` px
-- corners, `inset` px inside the frame's edges.
local function NineSlice(frame, file, layer, sublevel, corner, skipCenter, inset)
    local pieces = {}
    for index, def in ipairs(NINE) do
        if not (skipCenter and def[1] == "CENTER") then
            local tex = frame:CreateTexture(nil, layer, nil, sublevel)
            tex:SetTexture(file)
            tex:SetTexCoord(def[2], def[3], def[4], def[5])
            pieces[index] = tex
        end
    end
    local p = pieces
    for _, i in ipairs({ 1, 3, 7, 9 }) do p[i]:SetSize(corner, corner) end
    local i = inset or 0
    p[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", i, -i); p[3]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -i, -i)
    p[7]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", i, i); p[9]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -i, i)
    p[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT"); p[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT")
    p[8]:SetPoint("TOPLEFT", p[7], "TOPRIGHT"); p[8]:SetPoint("BOTTOMRIGHT", p[9], "BOTTOMLEFT")
    p[4]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT"); p[4]:SetPoint("BOTTOMRIGHT", p[7], "TOPRIGHT")
    p[6]:SetPoint("TOPLEFT", p[3], "BOTTOMLEFT"); p[6]:SetPoint("BOTTOMRIGHT", p[9], "TOPRIGHT")
    if p[5] then p[5]:SetPoint("TOPLEFT", p[1], "BOTTOMRIGHT"); p[5]:SetPoint("BOTTOMRIGHT", p[9], "TOPLEFT") end
    return pieces
end

local function Stretched(frame, name, layer, sublevel)
    local tex = frame:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(CARD_TEX .. name)
    tex:SetAllPoints(frame)
    return tex
end

local function SpinBeam(spinner, elapsed)
    local skin = spinner.skin
    skin.angle = (skin.angle + (elapsed or 0) * BEAM_SPEED) % (2 * math.pi)
    skin.beam:SetRotation(skin.angle)
end

-- Gives `card` (any frame) the style card body. Content goes on top of it.
function KT.VisualThemes:SkinStyleCard(card)
    if card.skin then return card.skin end
    local skin = { angle = 0 }
    skin.fill = NineSlice(card, CARD_TEX .. "fill", "BACKGROUND", 0, CARD_RADIUS)
    skin.glowSide = Stretched(card, "glow_side", "BACKGROUND", 1)
    skin.glowMid = Stretched(card, "glow_mid", "BACKGROUND", 2)
    skin.shine = Stretched(card, "shine", "BACKGROUND", 3)
    skin.border = NineSlice(card, CARD_TEX .. "border", "BORDER", 0, CARD_RADIUS, true)
    -- The beam turns in its own clipped frame; the ring mask lets it show
    -- only where the border is.
    local spinner = CreateFrame("Frame", nil, card)
    spinner:SetAllPoints(card)
    if spinner.SetClipsChildren then spinner:SetClipsChildren(true) end
    spinner:EnableMouse(false)
    spinner.skin = skin
    skin.spinner = spinner
    skin.beam = spinner:CreateTexture(nil, "ARTWORK")
    skin.beam:SetTexture(CARD_TEX .. "beam")
    skin.beam:SetPoint("CENTER", card, "CENTER")
    skin.beam:SetBlendMode("ADD")
    skin.mask = spinner:CreateMaskTexture()
    skin.mask:SetTexture(CARD_TEX .. "ringmask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    skin.mask:SetAllPoints(card)
    skin.beam:AddMaskTexture(skin.mask)
    skin.beam:Hide()
    spinner:SetScript("OnUpdate", SpinBeam)
    card.skin = skin
    return skin
end

-- Paints the skin for accent r, g, b. Selected cards glow fully and run the
-- beam; a hovered idle card lights halfway.
function KT.VisualThemes:PaintStyleCard(card, r, g, b, selected, hovered)
    local skin = card.skin or self:SkinStyleCard(card)
    r, g, b = CardAccent(card.key, r, g, b)
    local w, h = card:GetWidth() or 0, card:GetHeight() or 0
    local glow = selected and 1 or (hovered and 0.7 or 0.4)
    for _, tex in pairs(skin.fill) do tex:SetVertexColor(0.055, 0.055, 0.07, 0.97) end
    skin.glowSide:SetVertexColor(r, g, b, 0.6 * glow)
    skin.glowMid:SetVertexColor(r + (1 - r) * 0.55, g + (1 - g) * 0.55, b + (1 - b) * 0.55, 0.45 * glow)
    skin.shine:SetVertexColor(1, 1, 1, selected and 0.22 or 0.1)
    -- Border in the accent: dark at the top, lighter at the bottom.
    local a = selected and 1 or (hovered and 0.75 or 0.5)
    local dim = { r * 0.35, g * 0.35, b * 0.35 }
    local lift = selected and 0.3 or 0
    local bright = { r + (1 - r) * lift, g + (1 - g) * lift, b + (1 - b) * lift }
    if not selected then bright = { r * 0.7, g * 0.7, b * 0.7 } end
    for i, tex in pairs(skin.border) do
        if i <= 3 then tex:SetVertexColor(dim[1], dim[2], dim[3], a)
        elseif i >= 7 then tex:SetVertexColor(bright[1], bright[2], bright[3], a)
        else Gradient(tex, bright, dim, a) end
    end
    local d = math.sqrt(w * w + h * h)
    if d > 0 then skin.beam:SetSize(d, d) end
    skin.beam:SetVertexColor(r, g, b, 1)
    skin.beam:SetAlpha(selected and 1 or 0.55)
    skin.beam:SetShown(selected or hovered)
end

-------------------------------------------------------------------------------
--  Picker tiles (Elite/Rare portrait borders, minimap rings), after a CSS card
--  the user supplied: a dark card inside a frame painted with a left-to-right
--  gradient, and the same gradient blurred under it as a glow. Hovering fades
--  the glow out and tints the title with the gradient. Colours come from the
--  caller (each style's own, not the CSS's).
-------------------------------------------------------------------------------
local TILE_RADIUS, TILE_INNER_RADIUS, TILE_BORDER = 10, 7, 3
local TILE_FADE = 2 -- glow alpha per second (the CSS fades in 0.5 s)
local TILE_GLOW = 0.45

local function HGradient(tex, left, right, alpha)
    if tex.SetGradient and CreateColor then
        tex:SetGradient("HORIZONTAL", CreateColor(left[1], left[2], left[3], alpha),
            CreateColor(right[1], right[2], right[3], alpha))
    else
        tex:SetVertexColor((left[1] + right[1]) / 2, (left[2] + right[2]) / 2, (left[3] + right[3]) / 2, alpha)
    end
end

local function Lighten(c, k)
    return { c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k }
end

local function FadeGlow(driver, elapsed)
    local g = driver.tile.ktGlowTile
    local step = (elapsed or 0) * TILE_FADE
    if g.glowAlpha < g.glowTarget then
        g.glowAlpha = math.min(g.glowTarget, g.glowAlpha + step)
    else
        g.glowAlpha = math.max(g.glowTarget, g.glowAlpha - step)
    end
    g.glow:SetAlpha(g.glowAlpha)
    if g.glowAlpha == g.glowTarget then driver:SetScript("OnUpdate", nil) end
end

local function PaintTile(tile)
    local g = tile.ktGlowTile
    if not g.left then return end
    -- Idle tiles keep a dim frame; the selected one is fully lit.
    local k = g.selected and 1 or (g.hovered and 0.7 or 0.4)
    local left = { g.left[1] * k, g.left[2] * k, g.left[3] * k }
    local right = { g.right[1] * k, g.right[2] * k, g.right[3] * k }
    for index, tex in pairs(g.frame) do
        local col = (index - 1) % 3
        if col == 0 then tex:SetVertexColor(left[1], left[2], left[3], 1)
        elseif col == 2 then tex:SetVertexColor(right[1], right[2], right[3], 1)
        else HGradient(tex, left, right, 1) end
    end
    for _, tex in pairs(g.inner) do tex:SetVertexColor(0.094, 0.094, 0.094, 1) end
    HGradient(g.glow, g.left, g.right, 1)
    g.glowTarget = (g.selected and not g.hovered) and TILE_GLOW or 0
    g.driver:SetScript("OnUpdate", FadeGlow)
    if g.label then
        if g.hovered then
            g.label:SetTextColor(g.right[1], g.right[2], g.right[3], 1)
        else
            local v = g.selected and 1 or 0.75
            g.label:SetTextColor(v, v, v, 1)
        end
    end
end

-- Gives a picker tile (a Button) the frame, inner card and glow. `label` is
-- its title FontString (tinted on hover). Content drawn at ARTWORK stays on top.
function KT.VisualThemes:SkinGlowTile(tile, label)
    if tile.ktGlowTile then
        tile.ktGlowTile.label = label or tile.ktGlowTile.label
        return tile.ktGlowTile
    end
    if tile.SetBackdrop then tile:SetBackdrop(nil) end
    local g = { label = label, glowAlpha = 0, glowTarget = 0 }
    -- CSS: the glow is the card blurred and pushed down; kept tight here so it
    -- never spills over the options below a picker.
    g.glow = tile:CreateTexture(nil, "BACKGROUND", nil, -8)
    g.glow:SetTexture(CARD_TEX .. "tile_glow")
    g.glow:SetPoint("TOPLEFT", tile, "TOPLEFT", -6, -4)
    g.glow:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", 6, -8)
    g.glow:SetAlpha(0)
    g.frame = NineSlice(tile, CARD_TEX .. "fill", "BACKGROUND", 1, TILE_RADIUS)
    g.inner = NineSlice(tile, CARD_TEX .. "fill", "BACKGROUND", 2, TILE_INNER_RADIUS, false, TILE_BORDER)
    g.driver = CreateFrame("Frame", nil, tile)
    g.driver.tile = tile
    tile.ktGlowTile = g
    tile:HookScript("OnEnter", function(self) self.ktGlowTile.hovered = true; PaintTile(self) end)
    tile:HookScript("OnLeave", function(self) self.ktGlowTile.hovered = nil; PaintTile(self) end)
    return g
end

-- Paints a skinned tile: gradient from `left` to `right` ({r, g, b}; right
-- defaults to `left` lightened), lit and glowing when `selected`.
function KT.VisualThemes:PaintGlowTile(tile, left, right, selected)
    local g = tile.ktGlowTile or self:SkinGlowTile(tile)
    g.left, g.right = left, right or Lighten(left, 0.45)
    g.selected = selected and true or false
    PaintTile(tile)
end

-- Gradient ends for a style key ("kui" / "forever" / "retail" / "classic";
-- anything else: the KUI accent). KUI is crimson, like its style card.
function KT.VisualThemes:GlowTileColors(key)
    local base
    if key == "kui" or key == "none" then
        base = { KUI_CRIMSON[1], KUI_CRIMSON[2], KUI_CRIMSON[3] }
    elseif STYLE_LABELS[key] then
        base = { StyleAccent(key) }
    else
        base = { KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.333 }
    end
    return base, Lighten(base, 0.45)
end

local CARD_W, CARD_H, CARD_GAP, CARD_PAD = 140, 76, 10, 10

local function CardFont()
    return (KT.ResolveFontPath and KT:ResolveFontPath()) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

-- Three-slice pill (64x32 sheet, 16 px caps) for the card's state button:
-- the dark fill and, above it, its border ring.
local function Pill(card, file, sublevel)
    local pieces = {}
    local coords = { { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }
    for i = 1, 3 do
        pieces[i] = card:CreateTexture(nil, "ARTWORK", nil, sublevel)
        pieces[i]:SetTexture(CARD_TEX .. file)
        pieces[i]:SetTexCoord(coords[i][1], coords[i][2], 0, 1)
    end
    pieces[1]:SetSize(9, 18); pieces[3]:SetSize(9, 18)
    pieces[1]:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", CARD_PAD, 10)
    pieces[3]:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -CARD_PAD, 10)
    pieces[2]:SetPoint("TOPLEFT", pieces[1], "TOPRIGHT"); pieces[2]:SetPoint("BOTTOMRIGHT", pieces[3], "BOTTOMLEFT")
    return pieces
end

-- A centred row of style cards (icon + name, a rule, and a pill showing the
-- state). opts: title, order, labels, icons, accent(key) -> r, g, b,
-- current() -> key, select(key), and optionally active() -> key when the
-- lit card (being browsed) can differ from the applied one, whose pill says
-- Active. Returns the y below the row and the row.
function KT.VisualThemes:CreateStyleCardRow(parent, y, opts)
    local vt = self
    local LText = KT.Options and KT.Options.LText or function(t) return t end
    local row = CreateFrame("Frame", nil, parent)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, -y)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, -y)
    row:SetHeight(24 + CARD_H)
    row.cards = {}
    parent.ktStyleCardRow = row
    local caption = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    caption:SetText(opts.title or "")
    caption:SetTextColor(1, 1, 1, 1)
    row.caption = caption

    local function Paint()
        local current = opts.current()
        local active = opts.active and opts.active() or current
        local font = CardFont()
        for _, card in ipairs(row.cards) do
            local r, g, b = CardAccent(card.key, opts.accent(card.key))
            local selected = card.key == current
            vt:PaintStyleCard(card, r, g, b, selected, card.hovered)
            local v = selected and 1 or 0.75
            card.label:SetFont(font, 12, "OUTLINE")
            card.label:SetTextColor(v, v, v, 1)
            card.rule:SetColorTexture(r * 0.3, g * 0.3, b * 0.3, 1)
            local applied = card.key == active
            for _, tex in ipairs(card.pill) do
                if applied then
                    Gradient(tex, { r * 0.22, g * 0.22, b * 0.22 }, { r * 0.5, g * 0.5, b * 0.5 }, 1)
                else
                    local k = card.hovered and 0.1 or 0.06
                    tex:SetVertexColor(k, k, k + 0.01, 1)
                end
            end
            for _, tex in ipairs(card.pillBorder) do
                if applied then
                    tex:SetVertexColor(r + (1 - r) * 0.35, g + (1 - g) * 0.35, b + (1 - b) * 0.35, 1)
                else
                    local k = card.hovered and 0.45 or 0.3
                    tex:SetVertexColor(k, k, k, 1)
                end
            end
            card.pillText:SetFont(font, 10, "OUTLINE")
            card.pillText:SetText(LText(applied and "Active" or "Select"))
            local t = applied and 1 or (card.hovered and 0.8 or 0.6)
            card.pillText:SetTextColor(t, t, t, 1)
        end
    end
    row.Paint = Paint

    local function Layout(self)
        local n = #self.cards
        local width = self:GetWidth() or 0
        local w = math.min(CARD_W, math.max(60, (width - (n - 1) * CARD_GAP) / n))
        local left = (width - (n * w + (n - 1) * CARD_GAP)) / 2
        for index, card in ipairs(self.cards) do
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", self, "TOPLEFT", left + (index - 1) * (w + CARD_GAP), -24)
            card:SetSize(w, CARD_H)
        end
        caption:ClearAllPoints()
        caption:SetPoint("TOPLEFT", self, "TOPLEFT", left, 0)
        Paint()
    end
    row:SetScript("OnSizeChanged", Layout)

    for _, key in ipairs(opts.order) do
        local card = CreateFrame("Button", nil, row)
        card.key = key
        card:SetSize(CARD_W, CARD_H)
        vt:SkinStyleCard(card)
        card.icon = card:CreateTexture(nil, "ARTWORK")
        card.icon:SetSize(22, 22)
        card.icon:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -9)
        card.icon:SetTexture(opts.icons[key] or opts.icons.kui)
        card.label = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.label:SetPoint("LEFT", card.icon, "RIGHT", 7, 0)
        card.label:SetPoint("RIGHT", card, "RIGHT", -CARD_PAD, 0)
        card.label:SetJustifyH("LEFT")
        card.label:SetText(LText(opts.labels[key] or key))
        card.rule = card:CreateTexture(nil, "ARTWORK")
        card.rule:SetHeight(1)
        card.rule:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_PAD, -39)
        card.rule:SetPoint("TOPRIGHT", card, "TOPRIGHT", -CARD_PAD, -39)
        card.pill = Pill(card, "pill", 1)
        card.pillBorder = Pill(card, "pill_border", 2)
        card.pillText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        card.pillText:SetPoint("CENTER", card.pill[2], "CENTER", 0, 0)
        card:SetScript("OnClick", function()
            opts.select(key)
            Paint()
        end)
        card:SetScript("OnEnter", function(self) self.hovered = true; Paint() end)
        card:SetScript("OnLeave", function(self) self.hovered = nil; Paint() end)
        row.cards[#row.cards + 1] = card
    end
    Layout(row)
    return y + 24 + CARD_H + 14, row
end

-- One card per Visual Style for a module's db (Armory, Bags). Picking a card
-- stores it for the current Visual Style and calls onPick(key).
-- Returns the y below the cards.
function KT.VisualThemes:AddStyleCards(parent, y, title, db, onPick)
    local vt = self
    return self:CreateStyleCardRow(parent, y, {
        title = title,
        order = STYLE_ORDER,
        labels = STYLE_LABELS,
        icons = (KT.CastBarStyles and KT.CastBarStyles.styleIcons) or {},
        accent = StyleAccent,
        current = function() return vt:ResolveModuleStyle(db) end,
        select = function(key)
            vt:SetModuleStyle(db, key)
            if onPick then onPick(key) end
        end,
    })
end
