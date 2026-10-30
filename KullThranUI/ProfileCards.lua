-- ProfileCards.lua
-- Widgets de la pagina Profiles (Options.lua, BuildProfilesTab). Todos toman
-- su color del accent del estilo (KT:GetStyleAccentRGB).
--
-- KT.WaveCard: port de una tarjeta CSS:
--   * tres "olas" (cuadrado de esquinas 40%, degradado de brillo, opacidad
--     0.6) teñidas con el accent, que giran despacio recortadas a la tarjeta;
--   * icono (se puede cambiar con un clic, KT.IconPicker), titulo y subtitulo.
--   La geometria es la del CSS (tarjeta de 240px) escalada al ancho real. Las
--   olas giran mucho mas lento que en el original: WAVE_PERIODS.
--
-- KT.GridButton: port de un boton CSS:
--   * fondo con degradado radial del accent y rejilla de 15px;
--   * bordes superior e inferior de 1px que se apagan hacia los lados;
--   * texto en mayusculas del accent;
--   * hover: la rejilla pasa de 15px a 10px (0.2s ease-in-out);
--   * pulsado: el accent se aclara (el hue-rotate(250deg) del CSS volvia
--     azul un accent rojo).
--
-- KT.SoftButton: port de un boton CSS neumorfico:
--   * fondo degradado #2e2d2d -> #212121, borde de 1px, sombras interiores;
--   * dos sombras exteriores teñidas con el accent (arriba-izquierda y
--     abajo-derecha); hover: sombras de 13px, texto mas claro (500ms);
--   * pulsado: la sombra clara crece a 33px (100ms).
-- Todo borde de 1px cae en pixeles fisicos enteros (KT.NavTabs).
local _, ns = ...
local KT = ns.KT

local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local WAVE_TEX = MEDIA .. "ProfileWave.tga"
local GRID_TEX = MEDIA .. "GridButtonCell.tga"
local RADIAL_TEX = MEDIA .. "PortalRadial.tga"
local GLOW_TEX = MEDIA .. "NavButtonGlow.tga"
local CHECK_TEX = MEDIA .. "icons\\Profiles\\check.tga"
local DANGER = { 0.90, 0.18, 0.22 }

local function FontPath()
    if type(KT.FONT_PATH) == "string" and KT.FONT_PATH ~= "" then return KT.FONT_PATH end
    if KT.ResolveFontPath then return KT:ResolveFontPath() end
    return "Fonts\\FRIZQT__.TTF"
end

local function Px(region) return KT.NavTabs.PixelSize(region) end

local function Upper(text)
    if KT.NavTabs and KT.NavTabs.Upper then return KT.NavTabs.Upper(text) end
    return tostring(text or ""):upper()
end

local function Accent()
    if KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        if r then return r, g, b end
    end
    return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333
end

local function Mix(r, g, b, tr, tg, tb, f)
    return r + (tr - r) * f, g + (tg - g) * f, b + (tb - b) * f
end

local function NoSnap(t)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    return t
end

-- 1px frame (top, bottom, left, right) on whole physical pixels.
local function NewEdges(owner, layer, sub)
    local edges = {}
    for i = 1, 4 do
        edges[i] = NoSnap(owner:CreateTexture(nil, layer, nil, sub))
        edges[i]:SetTexture(WHITE)
    end
    return edges
end

local function LayoutEdges(owner, edges, thickness)
    local e = thickness
    edges[1]:ClearAllPoints(); edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(e)
    edges[2]:ClearAllPoints(); edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(e)
    edges[3]:ClearAllPoints(); edges[3]:SetPoint("TOPLEFT", 0, -e); edges[3]:SetPoint("BOTTOMLEFT", 0, e); edges[3]:SetWidth(e)
    edges[4]:ClearAllPoints(); edges[4]:SetPoint("TOPRIGHT", 0, -e); edges[4]:SetPoint("BOTTOMRIGHT", 0, e); edges[4]:SetWidth(e)
end

local function ColorEdges(edges, r, g, b, a)
    for _, t in ipairs(edges) do t:SetVertexColor(r, g, b, a) end
end

local function SetGradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    if tex.SetGradient and CreateColor then
        tex:SetGradient(orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    else
        tex:SetVertexColor((r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2, (a1 + a2) / 2)
    end
end

local function ShowTooltip(owner, tooltip)
    if not tooltip or not GameTooltip then return end
    GameTooltip:SetOwner(owner, "ANCHOR_TOP")
    if type(tooltip) == "function" then
        tooltip(GameTooltip)
    else
        GameTooltip:SetText(tooltip)
    end
    GameTooltip:Show()
end

-- ===========================================================================
-- Wave card
-- ===========================================================================
local WaveCard = KT.WaveCard or {}
KT.WaveCard = WaveCard

-- Seconds per full turn of each wave. The CSS uses 55/50/45s at rest and
-- 3/4/5s while "playing"; both are far too fast for an options page.
WaveCard.WAVE_PERIODS = { 140, 125, 110 }
WaveCard.SELECTED_SPEEDUP = 1.6   -- the selected card turns a bit faster
WaveCard.WAVE_ALPHA = 0.6
WaveCard.REST_DIM = 0.62          -- waves of unselected cards are dimmer
-- Each wave mixes the accent with white (+) or black (-), like the three
-- stops of the original gradient.
WaveCard.WAVE_SHADES = { 0.35, 0, -0.35 }

local CSS_W = 240                 -- reference card width of the CSS
local WAVE_W, WAVE_H = 540, 700
local WAVE_X, WAVE_Y = -120, -168 -- margin-left -50%, margin-top -70% (of 240)
local WAVE_LOW_TOP = 210          -- .wave:nth-child(2), (3) { top: 210px }

local function LayoutWaveCard(card)
    local w, h = card:GetWidth(), card:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end
    local s = w / CSS_W
    for i, wave in ipairs(card.waves) do
        local top = (i == 1) and 0 or WAVE_LOW_TOP
        wave:ClearAllPoints()
        wave:SetSize(WAVE_W * s, WAVE_H * s)
        wave:SetPoint("TOPLEFT", card.waveHolder, "TOPLEFT", WAVE_X * s, -(top + WAVE_Y) * s)
    end
    local px = Px(card)
    LayoutEdges(card, card.edges, px)
    LayoutEdges(card, card.ring, px * 2)
end

local function RestartWaves(card)
    for _, wave in ipairs(card.waves) do
        if wave.spin then
            wave.spin:Stop()
            wave.spin.rot:SetDuration(wave.period / (card.selected and WaveCard.SELECTED_SPEEDUP or 1))
            wave.spin:Play()
        end
    end
end

function WaveCard.SetSelected(card, selected)
    card.selected = selected and true or false
    local dim = card.selected and 1 or WaveCard.REST_DIM
    local r, g, b = Accent()
    for i, wave in ipairs(card.waves) do
        local shade = WaveCard.WAVE_SHADES[i] or 0
        local wr, wg, wb
        if shade >= 0 then
            wr, wg, wb = Mix(r, g, b, 1, 1, 1, shade)
        else
            wr, wg, wb = Mix(r, g, b, 0, 0, 0, -shade)
        end
        wave:SetVertexColor(wr * dim, wg * dim, wb * dim, WaveCard.WAVE_ALPHA)
    end
    for _, t in ipairs(card.ring) do t:SetShown(card.selected) end
    ColorEdges(card.edges, 1, 1, 1, card.selected and 0 or 0.16)
    card.check:SetShown(card.selected)
    card.title:SetAlpha(card.selected and 1 or 0.86)
    RestartWaves(card)
end

-- Sets the centre icon. icon: texture path or fileID; coords optional.
function WaveCard.SetIcon(card, icon, coords)
    local tex = card.icon
    tex:SetTexture(icon or 134400)
    if coords then tex:SetTexCoord(unpack(coords)) else tex:SetTexCoord(0, 1, 0, 1) end
end

-- opts: width, height, title, subtitle, icon (path or fileID), iconCoords,
-- iconSize, onIconClick(card) (makes the icon a button), badge (small text
-- top-right), selected, onClick(card), onDoubleClick(card), onRightClick(card),
-- tooltip (text or function(GameTooltip)), iconTooltip
function WaveCard.Create(parent, opts)
    opts = opts or {}
    local card = CreateFrame("Button", nil, parent)
    card:RegisterForClicks("LeftButtonUp")
    card:SetSize(opts.width or 130, opts.height or 104)
    card:SetClipsChildren(true)

    -- box-shadow 0 8px 28px -9px rgba(0,0,0,.45) does not fit inside a clipped
    -- frame; a dark plate behind the waves keeps the contrast instead.
    local plate = NoSnap(card:CreateTexture(nil, "BACKGROUND", nil, -8))
    plate:SetAllPoints()
    plate:SetColorTexture(0.035, 0.035, 0.045, 0.96)

    card.waveHolder = CreateFrame("Frame", nil, card)
    card.waveHolder:SetAllPoints()
    card.waveHolder:SetFrameLevel(card:GetFrameLevel())
    card.waves = {}
    for i = 1, 3 do
        local wave = card.waveHolder:CreateTexture(nil, "BACKGROUND", nil, i)
        wave:SetTexture(WAVE_TEX)
        -- Small random jitter so cards of the same page drift apart.
        wave.period = WaveCard.WAVE_PERIODS[i] * (0.9 + math.random() * 0.2)
        local spin = wave:CreateAnimationGroup()
        spin:SetLooping("REPEAT")
        local rot = spin:CreateAnimation("Rotation")
        rot:SetDegrees(-360) -- CSS rotate() turns clockwise
        rot:SetOrigin("CENTER", 0, 0)
        rot:SetDuration(wave.period)
        spin.rot = rot
        wave.spin = spin
        card.waves[i] = wave
    end

    local face = CreateFrame("Frame", nil, card)
    face:SetAllPoints()
    face:SetFrameLevel(card.waveHolder:GetFrameLevel() + 2)
    card.face = face

    -- Soft top-to-bottom shade so white text reads on the bright part.
    local shade = NoSnap(face:CreateTexture(nil, "BACKGROUND"))
    shade:SetAllPoints()
    shade:SetTexture(WHITE)
    SetGradient(shade, "VERTICAL", 0, 0, 0, 0.42, 0, 0, 0, 0.05)

    local hover = NoSnap(face:CreateTexture(nil, "ARTWORK", nil, -1))
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, 0.07)
    hover:Hide()
    card.hover = hover

    card.edges = NewEdges(face, "OVERLAY", 1)
    card.ring = NewEdges(face, "OVERLAY", 2)
    ColorEdges(card.ring, 1, 1, 1, 0.95)

    local fontPath = FontPath()
    local iconSize = opts.iconSize or 26
    -- The icon is its own button when it can be changed (KT.IconPicker).
    local iconHost = face
    if opts.onIconClick then
        local iconButton = CreateFrame("Button", nil, face)
        iconButton:SetSize(iconSize + 6, iconSize + 6)
        iconButton:SetFrameLevel(face:GetFrameLevel() + 1)
        local frameTex = NoSnap(iconButton:CreateTexture(nil, "BACKGROUND"))
        frameTex:SetAllPoints()
        frameTex:SetColorTexture(0, 0, 0, 0.45)
        local glow = NoSnap(iconButton:CreateTexture(nil, "HIGHLIGHT"))
        glow:SetAllPoints()
        glow:SetColorTexture(1, 1, 1, 0.22)
        iconButton:SetScript("OnClick", function() opts.onIconClick(card) end)
        iconButton:SetScript("OnEnter", function(self)
            card.hover:Show()
            ShowTooltip(self, opts.iconTooltip)
        end)
        iconButton:SetScript("OnLeave", function()
            if not card:IsMouseOver() then card.hover:Hide() end
            if GameTooltip then GameTooltip:Hide() end
        end)
        card.iconButton = iconButton
        iconHost = iconButton
    end
    local icon = iconHost:CreateTexture(nil, "ARTWORK")
    icon:SetSize(iconSize, iconSize)
    if card.iconButton then icon:SetPoint("CENTER", card.iconButton, "CENTER") end
    card.icon = icon
    WaveCard.SetIcon(card, opts.icon, opts.iconCoords)
    if opts.iconColor then icon:SetVertexColor(unpack(opts.iconColor)) end

    local title = face:CreateFontString(nil, "OVERLAY")
    title:SetFont(fontPath, opts.titleSize or 12, "OUTLINE")
    title:SetTextColor(1, 1, 1, 1)
    title:SetJustifyH("CENTER")
    title:SetWordWrap(false)
    title:SetText(opts.title or "")
    card.title = title

    local sub = face:CreateFontString(nil, "OVERLAY")
    sub:SetFont(fontPath, 9, "")
    sub:SetTextColor(1, 1, 1, 0.82)
    sub:SetJustifyH("CENTER")
    sub:SetWordWrap(false)
    sub:SetText(opts.subtitle and opts.subtitle:lower() or "")
    card.subtitle = sub

    -- Column centred a little above the middle, like .infotop.
    local iconBox = card.iconButton and (iconSize + 6) or iconSize
    local iconH = iconBox + 6
    local blockH = iconH + 14 + ((opts.subtitle and opts.subtitle ~= "") and 13 or 0)
    local topY = max(6, floor(((card:GetHeight() - blockH) / 2) - 1))
    if card.iconButton then
        card.iconButton:SetPoint("TOP", face, "TOP", 0, -topY)
    else
        icon:SetPoint("TOP", face, "TOP", 0, -topY)
    end
    title:SetPoint("TOPLEFT", face, "TOPLEFT", 6, -(topY + iconH))
    title:SetPoint("TOPRIGHT", face, "TOPRIGHT", -6, -(topY + iconH))
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    sub:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -3)

    local check = face:CreateTexture(nil, "OVERLAY", nil, 3)
    check:SetSize(12, 12)
    check:SetPoint("TOPLEFT", face, "TOPLEFT", 6, -6)
    check:SetTexture(CHECK_TEX)
    check:SetVertexColor(1, 1, 1, 1)
    card.check = check

    if opts.badge and opts.badge ~= "" then
        local badgeBg = face:CreateTexture(nil, "OVERLAY", nil, 2)
        local badge = face:CreateFontString(nil, "OVERLAY")
        badge:SetFont(fontPath, 8, "OUTLINE")
        badge:SetText(Upper(opts.badge))
        badge:SetTextColor(1, 1, 1, 1)
        badge:SetPoint("TOPRIGHT", face, "TOPRIGHT", -9, -8)
        badgeBg:SetColorTexture(0, 0, 0, 0.55)
        badgeBg:SetPoint("TOPLEFT", badge, "TOPLEFT", -4, 3)
        badgeBg:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", 4, -3)
        card.badge = badge
    end

    card:SetScript("OnSizeChanged", LayoutWaveCard)
    card:SetScript("OnShow", RestartWaves)
    card:SetScript("OnEnter", function(self)
        self.hover:Show()
        ShowTooltip(self, opts.tooltip)
    end)
    card:SetScript("OnLeave", function(self)
        self.hover:Hide()
        if GameTooltip then GameTooltip:Hide() end
    end)
    if opts.onRightClick then card:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
    card:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            if opts.onRightClick then opts.onRightClick(self) end
        elseif opts.onClick then
            opts.onClick(self)
        end
    end)
    if opts.onDoubleClick then
        card:SetScript("OnDoubleClick", function(self) opts.onDoubleClick(self) end)
    end

    LayoutWaveCard(card)
    WaveCard.SetSelected(card, opts.selected)
    return card
end

-- ===========================================================================
-- Grid button
-- ===========================================================================
local GridButton = KT.GridButton or {}
KT.GridButton = GridButton

GridButton.PRESS_LIGHTEN = 0.4 -- :active: accent mixed with white
GridButton.REST_MIX = 0.45    -- unselected: accent mixed with grey
GridButton.BG_ALPHA = 0.36    -- --main-bg-color alpha
GridButton.PATTERN_ALPHA = 0.073
local CELL, CELL_HOVER = 15, 10
local HOVER_TIME = 0.2

local function Ease(p) -- ease-in-out
    return p < 0.5 and 2 * p * p or 1 - ((-2 * p + 2) ^ 2) / 2
end

local function ApplyGrid(btn)
    local cell = btn._cell or CELL
    local w, h = btn:GetWidth(), btn:GetHeight()
    if not w or w <= 0 then return end
    -- background-position: center -> the pattern grows from the centre.
    local u, v = w / cell, h / cell
    btn.grid:SetTexCoord(0.5 - u / 2, 0.5 + u / 2, 0.5 - v / 2, 0.5 + v / 2)
end

local function CurrentColor(btn)
    local r, g, b = Accent()
    if btn._pressed then
        return Mix(r, g, b, 1, 1, 1, GridButton.PRESS_LIGHTEN)
    end
    if not btn.selected then
        r, g, b = Mix(r, g, b, 0.62, 0.62, 0.62, GridButton.REST_MIX)
    end
    return r, g, b
end

local function ApplyColors(btn)
    local r, g, b = CurrentColor(btn)
    local bgA = btn.selected and GridButton.BG_ALPHA or GridButton.BG_ALPHA * 0.45
    btn.radial:SetVertexColor(r, g, b, bgA)
    btn.grid:SetVertexColor(r, g, b, GridButton.PATTERN_ALPHA * (btn.selected and 1.6 or 1))
    -- border-image: radial-gradient(main 0%, transparent 100%)
    local a = btn.selected and 1 or 0.7
    for _, pair in ipairs(btn.borders) do
        SetGradient(pair[1], "HORIZONTAL", r, g, b, 0, r, g, b, a)
        SetGradient(pair[2], "HORIZONTAL", r, g, b, a, r, g, b, 0)
    end
    btn.text:SetTextColor(r, g, b, 1)
    if btn.icon:IsShown() then btn.icon:SetVertexColor(r, g, b, 1) end
    btn.check:SetVertexColor(r, g, b, 1)
    btn.check:SetShown(btn.selected)
end

local function LayoutGridButton(btn)
    local w = btn:GetWidth()
    if not w or w <= 0 then return end
    local px = Px(btn)
    local half = floor((w / px) / 2) * px
    for i, pair in ipairs(btn.borders) do
        local point = (i == 1) and "TOP" or "BOTTOM"
        pair[1]:ClearAllPoints(); pair[2]:ClearAllPoints()
        pair[1]:SetPoint(point .. "LEFT"); pair[1]:SetSize(half, px)
        pair[2]:SetPoint(point .. "RIGHT"); pair[2]:SetPoint(point .. "LEFT", pair[1], point .. "RIGHT"); pair[2]:SetHeight(px)
    end
    ApplyGrid(btn)
end

local function HoverUpdate(btn, elapsed)
    btn._t = min(HOVER_TIME, max(0, btn._t + (btn._hovered and elapsed or -elapsed)))
    local p = Ease(btn._t / HOVER_TIME)
    btn._cell = CELL + (CELL_HOVER - CELL) * p
    ApplyGrid(btn)
    if (btn._hovered and btn._t >= HOVER_TIME) or (not btn._hovered and btn._t <= 0) then
        btn:SetScript("OnUpdate", nil)
    end
end

function GridButton.SetSelected(btn, selected)
    btn.selected = selected and true or false
    ApplyColors(btn)
end

-- opts: width, height, label, icon (path), iconWidth, iconHeight, selected,
-- onClick(btn), tooltip (text or function(GameTooltip)), fontSize
function GridButton.Create(parent, opts)
    opts = opts or {}
    local btn = CreateFrame("Button", nil, parent)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetSize(opts.width or 160, opts.height or 40)
    btn._t, btn._cell = 0, CELL

    local base = NoSnap(btn:CreateTexture(nil, "BACKGROUND", nil, -8))
    base:SetAllPoints()
    base:SetColorTexture(0.02, 0.025, 0.03, 0.55)

    btn.radial = NoSnap(btn:CreateTexture(nil, "BACKGROUND", nil, -6))
    btn.radial:SetAllPoints()
    btn.radial:SetTexture(RADIAL_TEX)

    btn.grid = NoSnap(btn:CreateTexture(nil, "BACKGROUND", nil, -4))
    btn.grid:SetAllPoints()
    btn.grid:SetTexture(GRID_TEX, "REPEAT", "REPEAT", "NEAREST")
    if btn.grid.SetHorizTile then btn.grid:SetHorizTile(true); btn.grid:SetVertTile(true) end

    btn.borders = {}
    for i = 1, 2 do
        local left = NoSnap(btn:CreateTexture(nil, "BORDER"))
        local right = NoSnap(btn:CreateTexture(nil, "BORDER"))
        left:SetTexture(WHITE); right:SetTexture(WHITE)
        btn.borders[i] = { left, right }
    end

    local hasIcon = opts.icon ~= nil
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetPoint("LEFT", btn, "LEFT", 12, 0)
    btn.icon:SetSize(opts.iconWidth or 24, opts.iconHeight or 16)
    if hasIcon then btn.icon:SetTexture(opts.icon) else btn.icon:Hide() end

    btn.check = btn:CreateTexture(nil, "ARTWORK")
    btn.check:SetSize(12, 12)
    btn.check:SetPoint("RIGHT", btn, "RIGHT", -10, 0)
    btn.check:SetTexture(CHECK_TEX)

    btn.text = btn:CreateFontString(nil, "OVERLAY")
    btn.text:SetFont(FontPath(), opts.fontSize or 10, "OUTLINE")
    btn.text:SetWordWrap(false)
    btn.text:SetJustifyH(hasIcon and "LEFT" or "CENTER")
    btn.text:SetPoint("LEFT", btn, "LEFT", hasIcon and (12 + (opts.iconWidth or 24) + 8) or 26, 0)
    btn.text:SetPoint("RIGHT", btn, "RIGHT", -26, 0)
    btn.text:SetText(Upper(opts.label))

    btn:SetScript("OnSizeChanged", LayoutGridButton)
    btn:SetScript("OnEnter", function(self)
        self._hovered = true
        self:SetScript("OnUpdate", HoverUpdate)
        ShowTooltip(self, opts.tooltip)
    end)
    btn:SetScript("OnLeave", function(self)
        self._hovered = false
        self._pressed = false
        ApplyColors(self)
        self:SetScript("OnUpdate", HoverUpdate)
        if GameTooltip then GameTooltip:Hide() end
    end)
    btn:SetScript("OnMouseDown", function(self) self._pressed = true; ApplyColors(self) end)
    btn:SetScript("OnMouseUp", function(self) self._pressed = false; ApplyColors(self) end)
    btn:SetScript("OnClick", function(self) if opts.onClick then opts.onClick(self) end end)

    LayoutGridButton(btn)
    GridButton.SetSelected(btn, opts.selected)
    return btn
end

-- ===========================================================================
-- Soft button
-- ===========================================================================
local SoftButton = KT.SoftButton or {}
KT.SoftButton = SoftButton

-- Shadow states: { dx, dy, size, shade, alpha } per shadow. "shade" is how
-- much of the accent the shadow takes over the CSS greys (#41465b, #545b78,
-- #20232e). dy is in WoW coordinates (up is positive).
local SHADOW_REST = {
    { -1, 5, 15, 0.45, 0.55 },    -- -1px -5px 15px #41465b
    { 5, -5, 15, 0.45, 0.55 },    --  5px  5px 15px #41465b
}
local SHADOW_HOVER = {
    { -1, 1, 13, 0.60, 0.65 },    -- -1px -1px 13px #545b78
    { 1, -1, 13, 0, 0.85 },       --  1px  1px 13px #20232e
}
local ACTIVE_GROW = 20            -- :active -> 33px
local HOVER_FADE, ACTIVE_FADE = 0.5, 0.1
local TEXT_REST, TEXT_HOVER = 161 / 255, 214 / 255

-- Halo: 9-slice of the soft glow around a rect, centre filled (box-shadow).
local function NewHalo(owner, sub)
    local parts = {}
    for i = 1, 9 do
        local t = NoSnap(owner:CreateTexture(nil, "BACKGROUND", nil, sub))
        t:SetTexture(GLOW_TEX)
        parts[i] = t
    end
    local TL, TR, BL, BR, T, B, L, R, C = unpack(parts)
    TL:SetTexCoord(0, 0.5, 0, 0.5); TR:SetTexCoord(0.5, 1, 0, 0.5)
    BL:SetTexCoord(0, 0.5, 0.5, 1); BR:SetTexCoord(0.5, 1, 0.5, 1)
    T:SetTexCoord(0.49, 0.51, 0, 0.5); B:SetTexCoord(0.49, 0.51, 0.5, 1)
    L:SetTexCoord(0, 0.5, 0.49, 0.51); R:SetTexCoord(0.5, 1, 0.49, 0.51)
    C:SetTexCoord(0.49, 0.51, 0.49, 0.51)
    return parts
end

local function LayoutHalo(parts, btn, dx, dy, g)
    local TL, TR, BL, BR, T, B, L, R, C = unpack(parts)
    for _, t in ipairs(parts) do t:ClearAllPoints() end
    C:SetPoint("TOPLEFT", btn, "TOPLEFT", dx, dy)
    C:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", dx, dy)
    TL:SetSize(g, g); TL:SetPoint("BOTTOMRIGHT", C, "TOPLEFT")
    TR:SetSize(g, g); TR:SetPoint("BOTTOMLEFT", C, "TOPRIGHT")
    BL:SetSize(g, g); BL:SetPoint("TOPRIGHT", C, "BOTTOMLEFT")
    BR:SetSize(g, g); BR:SetPoint("TOPLEFT", C, "BOTTOMRIGHT")
    T:SetPoint("BOTTOMLEFT", C, "TOPLEFT"); T:SetPoint("BOTTOMRIGHT", C, "TOPRIGHT"); T:SetHeight(g)
    B:SetPoint("TOPLEFT", C, "BOTTOMLEFT"); B:SetPoint("TOPRIGHT", C, "BOTTOMRIGHT"); B:SetHeight(g)
    L:SetPoint("TOPRIGHT", C, "TOPLEFT"); L:SetPoint("BOTTOMRIGHT", C, "BOTTOMLEFT"); L:SetWidth(g)
    R:SetPoint("TOPLEFT", C, "TOPRIGHT"); R:SetPoint("BOTTOMLEFT", C, "BOTTOMRIGHT"); R:SetWidth(g)
end

local function SoftColor(btn)
    if btn.danger then return DANGER[1], DANGER[2], DANGER[3] end
    return Accent()
end

local function ApplySoft(btn)
    local h, a = btn._hover, btn._active
    local r, g, b = SoftColor(btn)
    -- CSS greys for the shadows: #41465b / #545b78 / #20232e.
    local greys = { { 0.255, 0.275, 0.357 }, { 0.329, 0.357, 0.471 } }
    local dark = { 0.125, 0.137, 0.180 }
    for i, halo in ipairs(btn.halos) do
        local s0, s1 = SHADOW_REST[i], SHADOW_HOVER[i]
        local dx = s0[1] + (s1[1] - s0[1]) * h
        local dy = s0[2] + (s1[2] - s0[2]) * h
        local size = s0[3] + (s1[3] - s0[3]) * h
        local shade = s0[4] + (s1[4] - s0[4]) * h
        local alpha = s0[5] + (s1[5] - s0[5]) * h
        if i == 1 then size = size + ACTIVE_GROW * a end
        -- shadow 1 goes from #41465b to #545b78, shadow 2 from #41465b to #20232e
        local base = greys[1]
        local target = (i == 1) and greys[2] or dark
        local cr = base[1] + (target[1] - base[1]) * h
        local cg = base[2] + (target[2] - base[2]) * h
        local cb = base[3] + (target[3] - base[3]) * h
        cr, cg, cb = Mix(cr, cg, cb, r * 0.7, g * 0.7, b * 0.7, shade)
        LayoutHalo(halo, btn, dx, dy, max(1, size))
        for _, t in ipairs(halo) do t:SetVertexColor(cr, cg, cb, alpha) end
    end
    local tc = TEXT_REST + (TEXT_HOVER - TEXT_REST) * max(h, a)
    btn.text:SetTextColor(tc, tc, tc, 1)
    if btn.icon then
        local ir, ig, ib = Mix(r, g, b, tc, tc, tc, 0.35)
        btn.icon:SetVertexColor(ir, ig, ib, 1)
    end
end

local function SoftUpdate(btn, elapsed)
    local done = true
    local function Step(current, target, time)
        if current == target then return current end
        local step = elapsed / time
        if current < target then current = min(target, current + step) else current = max(target, current - step) end
        if current ~= target then done = false end
        return current
    end
    btn._hover = Step(btn._hover, btn._hoverTarget, HOVER_FADE)
    btn._active = Step(btn._active, btn._activeTarget, btn._activeTarget > 0 and ACTIVE_FADE or HOVER_FADE)
    ApplySoft(btn)
    if done then btn:SetScript("OnUpdate", nil) end
end

local function LayoutSoft(btn)
    local px = Px(btn)
    LayoutEdges(btn, btn.edges, px)
    local inset = 5 -- inset 5px 5px 10px #212121
    for i, t in ipairs(btn.insets) do
        t:ClearAllPoints()
        if i == 1 then t:SetPoint("TOPLEFT", px, -px); t:SetPoint("TOPRIGHT", -px, -px); t:SetHeight(inset)
        elseif i == 2 then t:SetPoint("BOTTOMLEFT", px, px); t:SetPoint("BOTTOMRIGHT", -px, px); t:SetHeight(inset)
        elseif i == 3 then t:SetPoint("TOPLEFT", px, -px); t:SetPoint("BOTTOMLEFT", px, px); t:SetWidth(inset)
        else t:SetPoint("TOPRIGHT", -px, -px); t:SetPoint("BOTTOMRIGHT", -px, px); t:SetWidth(inset) end
    end
    ApplySoft(btn)
end

-- opts: label, icon (path), iconSize, danger, fontSize, onClick(btn), tooltip
function SoftButton.Create(parent, opts)
    opts = opts or {}
    local btn = CreateFrame("Button", nil, parent)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetSize(opts.width or 120, opts.height or 32)
    btn.danger = opts.danger and true or false
    btn._hover, btn._active, btn._hoverTarget, btn._activeTarget = 0, 0, 0, 0

    btn.halos = { NewHalo(btn, -8), NewHalo(btn, -7) }

    -- linear-gradient(145deg, #2e2d2d, #212121)
    local bg = NoSnap(btn:CreateTexture(nil, "BACKGROUND", nil, -4))
    bg:SetAllPoints()
    bg:SetTexture(WHITE)
    SetGradient(bg, "VERTICAL", 0.129, 0.129, 0.129, 1, 0.180, 0.176, 0.176, 1)

    -- inset shadows: darker #212121 along every inner edge
    btn.insets = {}
    for i = 1, 4 do
        local t = NoSnap(btn:CreateTexture(nil, "BACKGROUND", nil, -3))
        t:SetTexture(WHITE)
        btn.insets[i] = t
    end
    local d = 0.129
    SetGradient(btn.insets[1], "VERTICAL", d, d, d, 0, d, d, d, 0.9)
    SetGradient(btn.insets[2], "VERTICAL", d, d, d, 0.9, d, d, d, 0)
    SetGradient(btn.insets[3], "HORIZONTAL", d, d, d, 0.9, d, d, d, 0)
    SetGradient(btn.insets[4], "HORIZONTAL", d, d, d, 0, d, d, d, 0.9)

    -- border: solid #404c5d 1px, tinted with the accent
    btn.edges = NewEdges(btn, "BORDER", 1)
    local r, g, b = SoftColor(btn)
    local er, eg, eb = Mix(0.251, 0.298, 0.365, r, g, b, 0.55)
    ColorEdges(btn.edges, er, eg, eb, 1)

    local textLeft = 10
    if opts.icon then
        local icon = btn:CreateTexture(nil, "ARTWORK")
        icon:SetSize(opts.iconSize or 14, opts.iconSize or 14)
        icon:SetPoint("LEFT", btn, "LEFT", 10, 0)
        icon:SetTexture(opts.icon)
        btn.icon = icon
        textLeft = 10 + (opts.iconSize or 14) + 6
    end
    btn.text = btn:CreateFontString(nil, "OVERLAY")
    btn.text:SetFont(FontPath(), opts.fontSize or 11, "")
    btn.text:SetWordWrap(false)
    btn.text:SetJustifyH("CENTER")
    btn.text:SetPoint("LEFT", btn, "LEFT", textLeft, 0)
    btn.text:SetPoint("RIGHT", btn, "RIGHT", -(opts.icon and textLeft or 10), 0)
    btn.text:SetText(opts.label or "")

    local function Animate(self) self:SetScript("OnUpdate", SoftUpdate) end
    btn:SetScript("OnSizeChanged", LayoutSoft)
    btn:SetScript("OnEnter", function(self)
        self._hoverTarget = 1
        Animate(self)
        ShowTooltip(self, opts.tooltip)
    end)
    btn:SetScript("OnLeave", function(self)
        self._hoverTarget, self._activeTarget = 0, 0
        Animate(self)
        if GameTooltip then GameTooltip:Hide() end
    end)
    btn:SetScript("OnMouseDown", function(self) self._activeTarget = 1; Animate(self) end)
    btn:SetScript("OnMouseUp", function(self) self._activeTarget = 0; Animate(self) end)
    btn:SetScript("OnClick", function(self) if opts.onClick then opts.onClick(self) end end)
    btn:SetScript("OnDisable", function(self) self:SetAlpha(0.4) end)
    btn:SetScript("OnEnable", function(self) self:SetAlpha(1) end)

    LayoutSoft(btn)
    return btn
end

-- ===========================================================================
-- Icon picker: every icon the macro window offers (spells, then items).
-- ===========================================================================
local IconPicker = KT.IconPicker or {}
KT.IconPicker = IconPicker

local PICKER_COLS, PICKER_ROWS, PICKER_ICON, PICKER_GAP = 12, 7, 32, 4

local function CollectIcons()
    if IconPicker.icons then return IconPicker.icons end
    local list = {}
    if type(GetMacroIcons) == "function" then pcall(GetMacroIcons, list) end
    if type(GetMacroItemIcons) == "function" then pcall(GetMacroItemIcons, list) end
    -- Drop duplicates, keep the order of the macro window.
    local seen, icons = {}, {}
    for _, icon in ipairs(list) do
        -- Older clients return bare names ("INV_Misc_QuestionMark").
        if type(icon) == "string" and not icon:find("\\", 1, true) then
            icon = "Interface\\Icons\\" .. icon
        end
        if icon and not seen[icon] then
            seen[icon] = true
            icons[#icons + 1] = icon
        end
    end
    if #icons == 0 then icons[1] = 134400 end
    IconPicker.icons = icons
    return icons
end

local function PageOf(icon)
    if not icon then return 1 end
    for index, value in ipairs(CollectIcons()) do
        if value == icon then return floor((index - 1) / (PICKER_COLS * PICKER_ROWS)) + 1 end
    end
    return 1
end

local function RefreshPicker(frame)
    local icons = CollectIcons()
    local perPage = PICKER_COLS * PICKER_ROWS
    local pages = max(1, math.ceil(#icons / perPage))
    frame.page = max(1, min(pages, frame.page or 1))
    local first = (frame.page - 1) * perPage
    for i, cell in ipairs(frame.cells) do
        local icon = icons[first + i]
        cell.iconID = icon
        if icon then
            cell.tex:SetTexture(icon)
            cell.sel:SetShown(icon == frame.current)
            cell:Show()
        else
            cell:Hide()
        end
    end
    frame.pageText:SetText(string.format("%d / %d", frame.page, pages))
    frame.prev:SetEnabled(frame.page > 1)
    frame.next:SetEnabled(frame.page < pages)
end

local function BuildPicker()
    local LText = KT.Options and KT.Options.LText or function(text) return text end
    local gridW = PICKER_COLS * PICKER_ICON + (PICKER_COLS - 1) * PICKER_GAP
    local gridH = PICKER_ROWS * PICKER_ICON + (PICKER_ROWS - 1) * PICKER_GAP
    local frame = CreateFrame("Frame", "KullThranUIProfileIconPicker", UIParent, "BackdropTemplate")
    frame:SetSize(gridW + 32, gridH + 112)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if KT.AddBackdrop then KT:AddBackdrop(frame, 0.03, 0.03, 0.04, 0.97) end
    if KT.AddAccentBorder then KT:AddAccentBorder(frame, 0.6) end
    tinsert(UISpecialFrames, frame:GetName())

    frame.title = frame:CreateFontString(nil, "OVERLAY")
    frame.title:SetFont(FontPath(), 13, "OUTLINE")
    frame.title:SetPoint("TOPLEFT", 16, -14)
    frame.title:SetText(LText("Choose an icon"))

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    frame.cells = {}
    for i = 1, PICKER_COLS * PICKER_ROWS do
        local col, row = (i - 1) % PICKER_COLS, floor((i - 1) / PICKER_COLS)
        local cell = CreateFrame("Button", nil, frame)
        cell:SetSize(PICKER_ICON, PICKER_ICON)
        cell:SetPoint("TOPLEFT", 16 + col * (PICKER_ICON + PICKER_GAP), -40 - row * (PICKER_ICON + PICKER_GAP))
        cell.tex = cell:CreateTexture(nil, "ARTWORK")
        cell.tex:SetAllPoints()
        cell.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local hl = cell:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.25)
        cell.sel = CreateFrame("Frame", nil, cell)
        cell.sel:SetAllPoints()
        local selEdges = NewEdges(cell.sel, "OVERLAY", 1)
        LayoutEdges(cell.sel, selEdges, 2)
        ColorEdges(selEdges, Accent())
        cell.sel.edges = selEdges
        cell:SetScript("OnClick", function(self)
            if frame.onPick then frame.onPick(self.iconID) end
            frame:Hide()
        end)
        frame.cells[i] = cell
    end

    local footerY = 40 + gridH + 14
    local function Footer(label, x, width, onClick)
        local b = SoftButton.Create(frame, { label = LText(label), width = width, height = 26, onClick = onClick })
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -footerY)
        return b
    end
    frame.prev = Footer("<", 16, 40, function() frame.page = frame.page - 1; RefreshPicker(frame) end)
    frame.next = Footer(">", 16 + gridW - 40, 40, function() frame.page = frame.page + 1; RefreshPicker(frame) end)
    frame.pageText = frame:CreateFontString(nil, "OVERLAY")
    frame.pageText:SetFont(FontPath(), 11, "OUTLINE")
    frame.pageText:SetPoint("CENTER", frame, "TOPLEFT", 16 + gridW / 2, -(footerY + 13))
    frame.reset = Footer("Default Icon", 16 + 52, 120, function()
        if frame.onPick then frame.onPick(nil) end
        frame:Hide()
    end)

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(self, delta)
        self.page = self.page - delta
        RefreshPicker(self)
    end)
    -- onClose runs once however the picker closes (pick, Default Icon, X or Escape).
    frame:SetScript("OnHide", function(self)
        local onClose = self.onClose
        self.onClose = nil
        if onClose then onClose() end
    end)
    return frame
end

-- Opens the picker. current: the icon in use (fileID) or nil;
-- onPick(icon) gets the chosen fileID, or nil for "Default Icon".
-- onClose (optional) runs after the picker hides, picked or not.
function IconPicker.Open(current, onPick, onClose)
    IconPicker.frame = IconPicker.frame or BuildPicker()
    local frame = IconPicker.frame
    if frame:IsShown() then frame:Hide() end
    frame.current, frame.onPick, frame.onClose = current, onPick, onClose
    frame.page = PageOf(current)
    for _, cell in ipairs(frame.cells) do ColorEdges(cell.sel.edges, Accent()) end
    RefreshPicker(frame)
    frame:Show()
    frame:Raise()
end

-- ===========================================================================
-- Grid layout shared by the widgets: equal columns on whole pixels.
-- opts: width, columns, cellWidth (fixed width instead of filling the row),
-- height, gap, y. Returns the height used.
-- ===========================================================================
function KT.LayoutCardGrid(container, items, opts)
    local n = #items
    if n == 0 then return 0 end
    local px = Px(container)
    local width = opts.width or container:GetWidth()
    local cols = max(1, min(opts.columns or n, n))
    local gapPx = max(1, floor((opts.gap or 10) / px + 0.5))
    local wPx = floor(width / px + 0.0001)
    local cellPx = floor((wPx - gapPx * (cols - 1)) / cols)
    if opts.cellWidth then cellPx = min(cellPx, floor(opts.cellWidth / px + 0.5)) end
    local hPx = floor((opts.height or 40) / px + 0.5)
    local y0Px = floor((opts.y or 0) / px + 0.5)
    for i, item in ipairs(items) do
        local col = (i - 1) % cols
        local row = floor((i - 1) / cols)
        item:ClearAllPoints()
        item:SetSize(cellPx * px, hPx * px)
        item:SetPoint("TOPLEFT", container, "TOPLEFT", col * (cellPx + gapPx) * px, -(y0Px + row * (hPx + gapPx)) * px)
    end
    local rows = floor((n - 1) / cols) + 1
    return (rows * hPx + (rows - 1) * gapPx) * px
end
