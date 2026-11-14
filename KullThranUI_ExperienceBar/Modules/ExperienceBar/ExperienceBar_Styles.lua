-- Experience Bar styles: one renderer shared by the live bar and the options preview.
--   kui      flat KUI bar: backdrop, 1 px border, LibSharedMedia texture, profile colors
--   forever  bronze rim with diamond studs, 20 segments
--   retail   slim steel rim, glassy fill, 10 segments
--   classic  the stock Classic XP bar, literally: the client's own UI-MainMenuBar-Dwarf
--            strips at their own 1024 x 13 size over a UI-StatusBar fill, with the
--            rested tick
-- Forever and Retail draw KullThranUI's own sheets (media\experiencebar, built from
-- tools\photoshop\experience_bar.jsx). Every style shares the flow, the text shade
-- and the text position. The style comes from
-- KT.VisualThemes:ResolveModuleStyle(db): a card picked on the options page for the
-- applied Visual Style, otherwise that Visual Style's own look.
local KT = _G.KT
if not KT then return end

local LSM = LibStub("LibSharedMedia-3.0", true)
local S = {}
KT.ExperienceBarStyles = S

local max, min = math.max, math.min

S.order = { "kui", "forever", "retail", "classic" }
local KNOWN = { kui = true, forever = true, retail = true, classic = true }

local WHITE = "Interface\\Buttons\\WHITE8x8"

-- One 256 x 64 sheet per native style, all with the same layout (x, y, w, h).
local PACK_DIR = [[Interface\AddOns\KullThranUI\Libraries\texture\media\experiencebar\]]
local SHEET_W, SHEET_H = 256, 64
-- Pattern that drifts along the fill (128 x 32, wraps horizontally), every style.
local FLOW = PACK_DIR .. "experiencebar_flow.tga"
local FLOW_W, FLOW_H = 128, 32
local FLOW_SPEED = 14    -- screen px per second
local PACKS = {
    forever = PACK_DIR .. "experiencebar_forever.tga",
    retail = PACK_DIR .. "experiencebar_retail.tga",
}
local RECT = {
    frame = { 0, 0, 64, 64 },     -- nine-slice rim, 16 px corners
    bg = { 69, 0, 46, 28 },       -- trough (1 px kept clear of the neighbours)
    fill = { 69, 32, 46, 28 },    -- grayscale gloss, tinted per value
    divider = { 120, 0, 8, 28 },  -- slanted "/" inlaid with the rim's material
    spark = { 132, 0, 16, 28 },   -- slanted glow; its line crosses x 9 halfway down
    fillcap = { 180, 32, 8, 28 }, -- the fill's slanted end, cut through x 4 halfway down
    shade = { 190, 0, 64, 28 },   -- soft dark pill behind the text
    stud = { 152, 0, 24, 32 },
}
local SRC_CORNER = 16

-- The rim hugs the bar: 3 px outside its edge plus a 1 px shade over it, so it
-- never floats away from the fill whatever the bar's size.
local OUTSET, CORNER = 3, 8
local SEGMENTS = { forever = 20, retail = 10 }
local STUDS = { forever = true }

-- Classic: the client's own textures, laid out like the stock MainMenuExpBar: four
-- 256 px strips of UI-MainMenuBar-Dwarf, five segments each, left to right, drawn
-- pixel for pixel. The bar keeps the stock size whatever the Width and Height.
local CLASSIC_DWARF = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf"
local CLASSIC_FILL = "Interface\\TargetingFrame\\UI-StatusBar"
local CLASSIC_TICK = "Interface\\MainMenuBar\\UI-ExhaustionTickNormal"
local CLASSIC_STRIPS = { 203, 139, 75, 11 }
-- 13 rows of each strip from its top: the rail (2), the bar (8) and the rail with
-- the notches under it (3). Four strips of 256 make the stock 1024 x 13 bar.
local CLASSIC_ROWS, CLASSIC_PIECE = 13, 256
local CLASSIC_W, CLASSIC_H = CLASSIC_PIECE * 4, CLASSIC_ROWS
local CLASSIC_TICK_SIZE = 32
S.CLASSIC_SIZE = { CLASSIC_W, CLASSIC_H }

-- Fill tints over the grayscale gloss: a deep blue for XP whether rested or not;
-- the rested part ahead of it is purple.
local NATIVE_COLORS = {
    xp = { 0.09, 0.22, 0.54, 1 },
    prediction = { 0.46, 0.16, 0.66, 0.6 },
    honor = { 0.95, 0.42, 0.12, 1 },
    rep = { 0.10, 0.75, 0.20, 1 },
}
local CLASSIC_COLORS = {
    xp = { 0.58, 0.0, 0.55, 1 },
    rested = { 0.0, 0.39, 0.88, 1 },
    prediction = { 0.0, 0.39, 0.88, 0.15 },  -- ExhaustionLevelFillBar
    honor = { 1.0, 0.24, 0.0, 1 },
    rep = { 0.0, 0.6, 0.1, 1 },
}

local function SetPiece(tex, style, key, x0, x1, y0, y1)
    local r = RECT[key]
    tex:SetTexture(PACKS[style])
    x0, x1 = r[1] + (x0 or 0), r[1] + (x1 or r[3])
    y0, y1 = r[2] + (y0 or 0), r[2] + (y1 or r[4])
    tex:SetTexCoord(x0 / SHEET_W, x1 / SHEET_W, y0 / SHEET_H, y1 / SHEET_H)
end

function S:Resolve(db)
    local vt = KT.VisualThemes
    local key = vt and vt.ResolveModuleStyle and vt:ResolveModuleStyle(db) or "kui"
    return KNOWN[key] and key or "kui"
end

-------------------------------------------------------------------------------
--  Construction
-------------------------------------------------------------------------------
local function Flow(bar)
    -- A pattern drifting slowly along the filled part, like the profession bars.
    -- The texture repeats along a strip one tile longer than the bar; a looping
    -- Translation moves it exactly one tile, so it never jumps. No OnUpdate, and it
    -- stops while the bar is hidden.
    local clip = CreateFrame("Frame", nil, bar)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    clip:EnableMouse(false)
    local strip = clip:CreateTexture(nil, "OVERLAY")
    strip:SetTexture(FLOW, "REPEAT", "REPEAT")
    strip:SetBlendMode("ADD")
    clip.strip = strip

    local group = strip:CreateAnimationGroup()
    group:SetLooping("REPEAT")
    local move = group:CreateAnimation("Translation")
    move:SetOrder(1)
    if move.SetSmoothing then move:SetSmoothing("NONE") end
    clip.group, clip.move = group, move
    return clip
end

-- Order of the nine-slice pieces: corners and edges, the centre stays open.
local SLICES = { "TL", "T", "TR", "L", "R", "BL", "B", "BR" }

-- Builds the frame tree on `parent`: f._rested and f._bar (StatusBars), f._text,
-- the style's rim on f._art above the fill and the text above everything.
function S:Build(parent, name)
    local f = CreateFrame("Frame", name, parent)
    f:SetSize(300, 10)
    local level = f:GetFrameLevel() or 1

    f._nativeBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    f._nativeBg:SetAllPoints(f)
    f._nativeBg:Hide()

    -- Each layer is the child of the one below it (rested -> bar -> flow / art ->
    -- text), so the order holds even when something re-levels the frame tree.
    -- The rested overlay is emptied (value 0), never hidden: hiding it would hide the bar.
    local rested = CreateFrame("StatusBar", nil, f)
    rested:SetAllPoints(f)
    rested:SetFrameLevel(level + 1)
    rested:SetStatusBarTexture(WHITE)
    rested:SetMinMaxValues(0, 1)
    rested:SetValue(0)

    local bar = CreateFrame("StatusBar", nil, rested)
    bar:SetAllPoints(f)
    bar:SetFrameLevel(level + 2)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)

    -- The native fills are drawn by these textures (a piece of a packed sheet cannot be
    -- a StatusBar texture). The bars still hold the values and size the flow.
    f._fillTex = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    f._restTex = rested:CreateTexture(nil, "ARTWORK", nil, 1)
    -- The fills end on the dividers' slant: a cap cut on that angle closes each one.
    f._fillTex._cap = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    f._restTex._cap = rested:CreateTexture(nil, "ARTWORK", nil, 1)
    f._fillTex:Hide(); f._restTex:Hide()
    f._fillTex._cap:Hide(); f._restTex._cap:Hide()
    f._spark = bar:CreateTexture(nil, "ARTWORK", nil, 3)
    f._spark:SetBlendMode("ADD")
    f._spark:Hide()
    local function Sync() S:SyncFills(f) end
    for _, sb in ipairs({ bar, rested }) do
        sb:HookScript("OnValueChanged", Sync)
        sb:HookScript("OnMinMaxChanged", Sync)
    end
    f:HookScript("OnSizeChanged", function()
        Sync()
        if f._ktStyle and f._ktStyle ~= "kui" then S:LayoutArt(f) end
        if f._ktStyle then S:LayoutTextShade(f) end
    end)

    local flow = Flow(bar)

    local art = CreateFrame("Frame", nil, bar)
    art:SetAllPoints(f)
    art:SetFrameLevel(level + 5)
    art:EnableMouse(false)
    art.slices = {}
    for _, key in ipairs(SLICES) do
        art.slices[key] = art:CreateTexture(nil, "OVERLAY", nil, 0)
    end
    art.dividers = {}
    art.studL = art:CreateTexture(nil, "OVERLAY", nil, 2)
    art.studR = art:CreateTexture(nil, "OVERLAY", nil, 2)
    art.classic = {}
    art.tick = art:CreateTexture(nil, "OVERLAY", nil, 3)
    art.tick:SetTexture(CLASSIC_TICK)
    art.tick:Hide()

    local textHost = CreateFrame("Frame", nil, art)
    textHost:SetAllPoints(f)
    textHost:SetFrameLevel(level + 7)
    textHost:EnableMouse(false)
    local text = textHost:CreateFontString(nil, "OVERLAY")
    text:SetPoint("CENTER", f, "CENTER")
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    -- A soft dark pill behind the text, as wide as the text, so it reads over any fill.
    local shade = textHost:CreateTexture(nil, "BACKGROUND")
    f._textShade = shade
    if hooksecurefunc then
        for _, method in ipairs({ "SetText", "Show", "Hide", "SetShown" }) do
            hooksecurefunc(text, method, function() S:UpdateTextShade(f) end)
        end
    end

    f._rested, f._bar, f._art, f._text = rested, bar, art, text
    f._flow = flow
    f:HookScript("OnShow", function(self) S:UpdateFlow(self) end)
    f:HookScript("OnHide", function(self)
        if self._flow then self._flow.group:Stop() end
    end)
    if KT.AddBackdrop then KT:AddBackdrop(f, 0.07, 0.07, 0.07, 0.6) end
    if KT.AddBorder then KT:AddBorder(f, 0, 0, 0, 1) end
    return f
end

-------------------------------------------------------------------------------
--  Style art
-------------------------------------------------------------------------------
local function HideArt(art)
    for _, tex in pairs(art.slices) do tex:Hide() end
    for _, tex in ipairs(art.dividers) do tex:Hide() end
    art.studL:Hide(); art.studR:Hide()
    for _, tex in ipairs(art.classic) do tex:Hide() end
    art.tick:Hide()
end

local function SetKUIChrome(f, shown)
    if f._ktBackdropTexture then f._ktBackdropTexture:SetShown(shown) end
    local border = f._ktBorderFrame
    if border then
        border:SetShown(shown)
        -- Above the fill and its flow, below the text.
        if shown then border:SetFrameLevel((f._bar:GetFrameLevel() or 0) + 2) end
    end
end

local function Size(f)
    local db = f._ktDB
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    if w <= 0 then w = tonumber(db and db.width) or 300 end
    if h <= 0 then h = tonumber(db and db.height) or 10 end
    return w, h
end

-- Classic: the four Dwarf strips side by side at their own size, over the bar.
local function LayoutClassic(f)
    local art = f._art
    for i, top in ipairs(CLASSIC_STRIPS) do
        local tex = art.classic[i]
        if not tex then
            tex = art:CreateTexture(nil, "OVERLAY", nil, 0)
            art.classic[i] = tex
        end
        tex:SetTexture(CLASSIC_DWARF)
        tex:SetTexCoord(0, 1, top / 256, (top + CLASSIC_ROWS) / 256)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", f, "TOPLEFT", (i - 1) * CLASSIC_PIECE, 0)
        tex:SetSize(CLASSIC_PIECE, CLASSIC_ROWS)
        tex:SetVertexColor(1, 1, 1, 1)
        tex:Show()
    end
end

-- Rim, segment ticks and studs of the current native style, laid out on f's size.
function S:LayoutArt(f)
    local style = f._ktStyle
    if style == "classic" then
        LayoutClassic(f)
        return
    end
    if not PACKS[style] then return end
    local art = f._art
    local w, h = Size(f)
    local o = OUTSET
    local c = min(CORNER, (h + o * 2) / 2, (w + o * 2) / 2)
    local s, sc = art.slices, SRC_CORNER
    local edge = 64 - sc

    -- Corners keep their size; the edges between them stretch.
    SetPiece(s.TL, style, "frame", 0, sc, 0, sc)
    SetPiece(s.TR, style, "frame", edge, 64, 0, sc)
    SetPiece(s.BL, style, "frame", 0, sc, edge, 64)
    SetPiece(s.BR, style, "frame", edge, 64, edge, 64)
    SetPiece(s.T, style, "frame", sc, edge, 0, sc)
    SetPiece(s.B, style, "frame", sc, edge, edge, 64)
    SetPiece(s.L, style, "frame", 0, sc, sc, edge)
    SetPiece(s.R, style, "frame", edge, 64, sc, edge)
    for _, tex in pairs(s) do tex:ClearAllPoints(); tex:SetVertexColor(1, 1, 1, 1); tex:Show() end
    s.TL:SetPoint("TOPLEFT", f, "TOPLEFT", -o, o); s.TL:SetSize(c, c)
    s.TR:SetPoint("TOPRIGHT", f, "TOPRIGHT", o, o); s.TR:SetSize(c, c)
    s.BL:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -o, -o); s.BL:SetSize(c, c)
    s.BR:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", o, -o); s.BR:SetSize(c, c)
    s.T:SetPoint("TOPLEFT", s.TL, "TOPRIGHT"); s.T:SetPoint("BOTTOMRIGHT", s.TR, "BOTTOMLEFT")
    s.B:SetPoint("TOPLEFT", s.BL, "TOPRIGHT"); s.B:SetPoint("BOTTOMRIGHT", s.BR, "BOTTOMLEFT")
    s.L:SetPoint("TOPLEFT", s.TL, "BOTTOMLEFT"); s.L:SetPoint("BOTTOMRIGHT", s.BL, "TOPRIGHT")
    s.R:SetPoint("TOPLEFT", s.TR, "BOTTOMLEFT"); s.R:SetPoint("BOTTOMRIGHT", s.BR, "TOPRIGHT")

    local segments = SEGMENTS[style] or 10
    for i = 1, segments - 1 do
        local tex = art.dividers[i]
        if not tex then
            tex = art:CreateTexture(nil, "OVERLAY", nil, 1)
            art.dividers[i] = tex
        end
        SetPiece(tex, style, "divider")
        tex:ClearAllPoints()
        local x = w * i / segments
        tex:SetPoint("TOP", f, "TOPLEFT", x, 0)
        tex:SetPoint("BOTTOM", f, "BOTTOMLEFT", x, 0)
        -- Same aspect as in the sheet, so the slant keeps its angle at any height.
        tex:SetWidth(h * RECT.divider[3] / RECT.divider[4])
        tex:Show()
    end
    for i = segments, #art.dividers do art.dividers[i]:Hide() end

    if STUDS[style] then
        local sh = min(h + 8, 20)
        local sw = sh * RECT.stud[3] / RECT.stud[4]
        for side, tex in pairs({ L = art.studL, R = art.studR }) do
            SetPiece(tex, style, "stud")
            tex:ClearAllPoints()
            tex:SetSize(sw, sh)
            if side == "L" then
                tex:SetPoint("CENTER", f, "LEFT", 1 - o, 0)
            else
                tex:SetPoint("CENTER", f, "RIGHT", o - 1, 0)
            end
            tex:Show()
        end
    else
        art.studL:Hide(); art.studR:Hide()
    end
end

-- Text inside the bar (default), or just above / below it, clear of the rim.
local TEXT_GAP = OUTSET + 2
function S:PlaceText(f, position)
    local text = f._text
    text:ClearAllPoints()
    if position == "ABOVE" then
        text:SetPoint("BOTTOM", f, "TOP", 0, TEXT_GAP)
    elseif position == "BELOW" then
        text:SetPoint("TOP", f, "BOTTOM", 0, -TEXT_GAP)
    else
        position = "INSIDE"
        text:SetPoint("CENTER", f, "CENTER")
    end
    f._textPosition = position
    self:UpdateTextShade(f)
end

-- The text shade: the same dark pill in every sheet (KUI borrows Forever's).
function S:LayoutTextShade(f)
    local shade, text = f._textShade, f._text
    local _, h = Size(f)
    SetPiece(shade, PACKS[f._ktStyle] and f._ktStyle or "forever", "shade")
    shade:ClearAllPoints()
    shade:SetPoint("LEFT", text, "LEFT", -h, 0)
    shade:SetPoint("RIGHT", text, "RIGHT", h, 0)
    shade:SetHeight(h)
    self:UpdateTextShade(f)
end

function S:UpdateTextShade(f)
    local text = f._text
    local label = text.GetText and text:GetText()
    -- Only inside the bar: above or below it the text sits on the world.
    f._textShade:SetShown(f._textPosition ~= "ABOVE" and f._textPosition ~= "BELOW"
        and text:IsShown() and type(label) == "string" and label ~= "")
end

-- Draws the chrome of `style` around f (sized already). db: the module profile.
function S:Apply(f, db, style)
    style = KNOWN[style] and style or self:Resolve(db)
    f._ktStyle, f._ktDB = style, db
    HideArt(f._art)

    if style == "kui" or style == "classic" then
        -- Plain StatusBar fills: none of the sheet's gloss, caps or spark.
        f._fillTex._native, f._restTex._native = nil, nil
        f._fillTex:Hide(); f._restTex:Hide(); f._spark:Hide()
        f._fillTex._cap:Hide(); f._restTex._cap:Hide()
    end
    if style == "classic" then
        SetKUIChrome(f, false)
        f:SetSize(CLASSIC_W, CLASSIC_H)
        local bg = f._nativeBg
        bg:SetTexture(WHITE)
        bg:SetTexCoord(0, 1, 0, 1)
        bg:SetVertexColor(0, 0, 0, 0.5)
        bg:Show()
        self:LayoutArt(f)
    elseif style == "kui" then
        SetKUIChrome(f, true)
        f._nativeBg:Hide()
        local tex = (LSM and db and db.texture and LSM:Fetch("statusbar", db.texture, true)) or WHITE
        f._bar:SetStatusBarTexture(tex)
        f._rested:SetStatusBarTexture(tex)
    else
        SetKUIChrome(f, false)
        local bg = f._nativeBg
        SetPiece(bg, style, "bg")
        bg:SetVertexColor(1, 1, 1, 1)
        bg:Show()
        SetPiece(f._fillTex, style, "fill")
        SetPiece(f._restTex, style, "fill")
        SetPiece(f._spark, style, "spark")
        SetPiece(f._fillTex._cap, style, "fillcap")
        SetPiece(f._restTex._cap, style, "fillcap")
        self:LayoutArt(f)
    end
    self:PlaceText(f, db and db.textPosition or "ABOVE")
    self:LayoutTextShade(f)
    self:LayoutFlow(f)
end

-------------------------------------------------------------------------------
--  Fills
-------------------------------------------------------------------------------
local function ColorOf(c, fallback)
    c = type(c) == "table" and c or fallback
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

local KUI_DEFAULTS = {
    xp = { r = 0.33, g = 0.38, b = 1, a = 1 },
    rested = { r = 1, g = 0.2, b = 1, a = 0.5 },
    honor = { r = 1, g = 0.2, b = 0.2, a = 1 },
    rep = { r = 0, g = 0.8, b = 0, a = 1 },
}

-- The StatusBar keeps an invisible full-height fill (it still sizes the flow);
-- `tex` draws the style's gloss over the filled part, tinted `color`.
local function SetNativeFill(statusBar, tex, color)
    statusBar:SetStatusBarTexture(WHITE)
    statusBar:SetStatusBarColor(1, 1, 1, 0)
    tex._native = color
    tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    tex._cap:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
end

local function SetClassicFill(statusBar, color)
    statusBar:SetStatusBarTexture(CLASSIC_FILL)
    local fill = statusBar:GetStatusBarTexture()
    if fill then fill:SetTexCoord(0, 1, 0, 1) end
    statusBar:SetStatusBarColor(color[1], color[2], color[3], color[4] or 1)
end

-- kind: "xp" | "honor" | "rep". isRested: the player has rested XP (Classic turns
-- the main fill blue like its stock bar). reaction: standing id for reputation colors.
function S:SetFill(f, db, kind, isRested, reaction)
    local style = f._ktStyle or self:Resolve(db)
    local bar, rested = f._bar, f._rested
    if style == "kui" then
        f._flow.strip:SetVertexColor(1, 1, 1, 0.22)
        local key = kind == "xp" and "xpColor" or (kind == "honor" and "honorColor" or "repColor")
        bar:SetStatusBarColor(ColorOf(db and db[key], KUI_DEFAULTS[kind] or KUI_DEFAULTS.xp))
        rested:SetStatusBarColor(ColorOf(db and db.restedColor, KUI_DEFAULTS.rested))
    else
        local colors = style == "classic" and CLASSIC_COLORS or NATIVE_COLORS
        local color = colors[kind] or colors.xp
        if kind == "xp" and isRested and colors.rested then color = colors.rested end
        if kind == "rep" and reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction] then
            local c = FACTION_BAR_COLORS[reaction]
            color = { c.r, c.g, c.b, 1 }
        end
        if style == "classic" then
            SetClassicFill(bar, color)
            SetClassicFill(rested, colors.prediction)
        else
            SetNativeFill(bar, f._fillTex, color)
            SetNativeFill(rested, f._restTex, colors.prediction)
        end
        -- The spark and the flow take a light version of the fill color.
        f._spark:SetVertexColor(0.6 + color[1] * 0.4, 0.6 + color[2] * 0.4, 0.6 + color[3] * 0.4, 0.7)
        f._flow.strip:SetVertexColor(0.3 + color[1] * 0.7, 0.3 + color[2] * 0.7, 0.3 + color[3] * 0.7, 0.28)
        self:SyncFills(f)
    end
    -- The fill region may be a new object after a texture swap.
    self:LayoutFlow(f)
end

local function Percent(statusBar)
    local lo, hi = statusBar:GetMinMaxValues()
    local value = statusBar:GetValue()
    if type(lo) == "number" and type(hi) == "number" and type(value) == "number" and hi > lo then
        return min(1, max(0, (value - lo) / (hi - lo)))
    end
    return 0
end

local function CapWidth(h)
    return h * RECT.fillcap[3] / RECT.fillcap[4]
end

-- Draws the filled part up to x = w * pct: the stretched gloss, then the slanted cap
-- whose cut crosses that x halfway down (a full bar ends square under the rim).
local function SyncFill(f, statusBar, tex)
    local cap = tex._cap
    if not tex._native then tex:Hide(); cap:Hide(); return 0, false end
    local pct = Percent(statusBar)
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    if pct <= 0 or w <= 0 then tex:Hide(); cap:Hide(); return 0, false end
    local x, cw = w * pct, CapWidth(h)
    local body = x
    local capped = pct < 1 and x >= cw / 2
    if capped then
        body = x - cw / 2
        cap:ClearAllPoints()
        cap:SetPoint("TOPLEFT", f, "TOPLEFT", body, 0)
        cap:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", body, 0)
        cap:SetWidth(cw)
        cap:Show()
    else
        cap:Hide()
    end
    if body > 0 then
        -- Full height of the bar; the gloss is even along its length, so it just stretches.
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", f, "TOPLEFT")
        tex:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT")
        tex:SetWidth(body)
        tex:Show()
    else
        tex:Hide()
    end
    return pct, capped
end

function S:SyncFills(f)
    local pct, capped = SyncFill(f, f._bar, f._fillTex)
    SyncFill(f, f._rested, f._restTex)
    local w, h = f:GetWidth() or 0, f:GetHeight() or 0
    local spark = f._spark
    if capped then
        -- The glow runs along the cap's cut.
        local sw = h * RECT.spark[3] / RECT.spark[4]
        local left = w * pct - sw * 9 / RECT.spark[3]
        spark:ClearAllPoints()
        spark:SetPoint("TOPLEFT", f, "TOPLEFT", left, 0)
        spark:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", left, 0)
        spark:SetWidth(sw)
        spark:Show()
    else
        spark:Hide()
    end
    -- Classic: the stock rested tick where the rested XP ends.
    local tick = f._art.tick
    local restPct = Percent(f._rested)
    if f._ktStyle == "classic" and restPct > Percent(f._bar) and w > 0 then
        tick:ClearAllPoints()
        tick:SetPoint("CENTER", f, "LEFT", w * restPct, 0)
        tick:SetSize(CLASSIC_TICK_SIZE, CLASSIC_TICK_SIZE)
        tick:Show()
    else
        tick:Hide()
    end
end

-------------------------------------------------------------------------------
--  Flow
-------------------------------------------------------------------------------
function S:LayoutFlow(f)
    local clip = f._flow
    if not clip then return end
    -- Clipped to the filled part: the StatusBar's own (invisible) fill tracks the value.
    local fill = f._bar:GetStatusBarTexture()
    clip:ClearAllPoints()
    clip:SetPoint("TOPLEFT", f, "TOPLEFT")
    if fill then
        clip:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    else
        clip:SetPoint("BOTTOMRIGHT", f._bar, "BOTTOMRIGHT")
    end
    local w, h = f:GetWidth() or 300, f:GetHeight() or 10
    h = max(1, h)
    local tile = FLOW_W * h / FLOW_H
    local strip = clip.strip
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", f, "TOPLEFT", -tile, 0)
    strip:SetSize(w + tile, h)
    strip:SetTexCoord(0, (w + tile) / tile, 0, 1)
    if clip._tile ~= tile then
        clip._tile = tile
        clip.move:SetOffset(tile, 0)
        clip.move:SetDuration(tile / FLOW_SPEED)
        if clip.group:IsPlaying() then clip.group:Stop(); clip.group:Play() end
    end
    self:UpdateFlow(f)
end

function S:UpdateFlow(f)
    local clip = f._flow
    if not clip then return end
    local db = f._ktDB
    local on = f:IsVisible() and not (db and db.animate == false)
    clip:SetShown(on)
    if on then
        if not clip.group:IsPlaying() then clip.group:Play() end
    else
        clip.group:Stop()
    end
end
