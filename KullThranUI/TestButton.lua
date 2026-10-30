-- Test button, after a Uiverse CSS button by StealthWorm: a pill whose border
-- runs a slowly shifting gradient, with stars drifting inside and two soft
-- glows pulsing behind it. KUI keeps only the border (no solid fill) and draws
-- every colour from the Visual Style accent: the gradient runs through lighter
-- and darker shades of it. Hover grows it toward 110% (at most 4 px a side, so
-- it never leaves its card); pressing turns the border
-- the solid accent.
--
-- Cost: one shared driver animates every visible Test button and stops when
-- none is on screen. The slow loops (gradient, stars, glow) repaint at 24 fps;
-- only the hover/press transitions run every frame. The CSS blurs are baked
-- into textures.
local _, ns = ...
local KT = ns.KT

local TB = KT.TestButton or {}
KT.TestButton = TB

local floor, max, min, cos, pi = math.floor, math.max, math.min, math.cos, math.pi

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Shared\\"
local BORDER, BLOB, STARS = MEDIA .. "TestPillBorder.tga", MEDIA .. "TestGlowBlob.tga", MEDIA .. "TestStars.tga"

local TICK = 1 / 24              -- repaint rate of the slow loops
local GRADIENT_PERIOD = 5        -- @keyframes gradient_301 5s ease infinite
local PULSE_PERIOD = 4           -- @keyframes pulse_3011 4s infinite
local HOVER_TIME, PRESS_TIME = 0.5, 0.12
local SEGMENTS = 6               -- top/bottom border split so the gradient keeps its four stops
local STAR_TILE = 50             -- background-size: 50px 50px
local STAR_RISE = 36             -- animStar: 135rem in 60s
local STAR_DRIFT = 4             -- animStarRotate (90s) read as a slow sideways drift

-- The CSS gradient's four stops (10%, 45%, 67%, 87%), each a shade of the
-- accent: light, accent, dark, accent. Filled from the accent on every repaint.
local STOPS = { { 0.10, 1, 1, 1 }, { 0.45, 1, 1, 1 }, { 0.67, 1, 1, 1 }, { 0.87, 1, 1, 1 } }
local SHADES = { 0.40, 0, -0.35, 0 }      -- toward white (+) or black (-)
local ACCENT = { 1, 1, 1 }                -- :active border and the glows
local GLOW_ALPHA = { 0.636, 0.704 }       -- .circle:nth-of-type(1), (2)
local GLOW_SHADE = { 0.25, -0.25 }

local function Shade(r, g, b, k)
    if k >= 0 then return r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k end
    return r * (1 + k), g * (1 + k), b * (1 + k)
end

-- Reads the accent once per repaint into the stop table (no allocation).
local function LoadAccent()
    local r, g, b
    if KT.GetStyleAccentRGB then r, g, b = KT:GetStyleAccentRGB() end
    r, g, b = r or 1, g or 0.5, b or 0.1
    ACCENT[1], ACCENT[2], ACCENT[3] = r, g, b
    for i = 1, 4 do
        STOPS[i][2], STOPS[i][3], STOPS[i][4] = Shade(r, g, b, SHADES[i])
    end
end

local EDGE = 1 / 64
local UV = { 0, 0.5 - EDGE, 0.5 + EDGE, 1 }

local function Px(region) return KT.NavTabs.PixelSize(region) end
local function ToPx(value, px) return floor(value / px + 0.5) * px end

local function FontPath()
    if type(KT.FONT_PATH) == "string" and KT.FONT_PATH ~= "" then return KT.FONT_PATH end
    if KT.ResolveFontPath then return KT:ResolveFontPath() end
    return "Fonts\\FRIZQT__.TTF"
end

local function GradientAt(t)
    if t <= STOPS[1][1] then return STOPS[1][2], STOPS[1][3], STOPS[1][4] end
    for i = 2, #STOPS do
        local a, b = STOPS[i - 1], STOPS[i]
        if t <= b[1] then
            local k = (t - a[1]) / (b[1] - a[1])
            return a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, a[4] + (b[4] - a[4]) * k
        end
    end
    local last = STOPS[#STOPS]
    return last[2], last[3], last[4]
end

-- background-size 300%, background-position 0% -> 100% -> 0% with ease: the
-- visible third of the gradient slides back and forth.
local function GradientOffset(clock)
    local phase = (clock % GRADIENT_PERIOD) / GRADIENT_PERIOD
    local k = phase < 0.5 and phase * 2 or (1 - phase) * 2
    return k * k * (3 - 2 * k)
end

local shared = { clock = 0, acc = 0, active = {} }

local function Piece(owner, col, row, sub)
    local t = owner:CreateTexture(nil, "BORDER", nil, sub or 0)
    t:SetTexture(BORDER)
    t:SetTexCoord(UV[col], UV[col + 1], UV[row], UV[row + 1])
    return t
end

local function Build(btn, extText)
    local v = { hoverP = 0, hoverTarget = 0, pressP = 0, pressTarget = 0, fontSize = 13 }
    btn._ktTest = v
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end

    -- Single CENTER anchor so SetScale grows the button around its centre.
    v.vis = CreateFrame("Frame", nil, btn)
    v.vis:SetPoint("CENTER", btn, "CENTER", 0, 0)

    v.glows = {}
    for i = 1, 2 do
        local glow = v.vis:CreateTexture(nil, "BACKGROUND", nil, -7)
        glow:SetTexture(BLOB)
        v.glows[i] = glow
    end

    -- Stars, clipped to the inside of the pill.
    v.clip = CreateFrame("Frame", nil, v.vis)
    if v.clip.SetClipsChildren then v.clip:SetClipsChildren(true) end
    v.starHolder = CreateFrame("Frame", nil, v.clip)
    v.starHolder:SetAllPoints(v.clip)
    v.stars = {}
    for i = 1, 2 do
        local layer = v.starHolder:CreateTexture(nil, "ARTWORK", nil, i)
        layer:SetTexture(STARS, "REPEAT", "REPEAT")
        if layer.SetHorizTile then layer:SetHorizTile(true); layer:SetVertTile(true) end
        layer:SetAllPoints(v.starHolder)
        v.stars[i] = layer
    end

    -- Border: corners, sides, and top/bottom split into segments.
    v.corners = { Piece(v.vis, 1, 1), Piece(v.vis, 3, 1), Piece(v.vis, 1, 3), Piece(v.vis, 3, 3) }
    v.sides = { Piece(v.vis, 1, 2), Piece(v.vis, 3, 2) }
    v.top, v.bottom = {}, {}
    for i = 1, SEGMENTS do
        v.top[i] = Piece(v.vis, 2, 1)
        v.bottom[i] = Piece(v.vis, 2, 3)
    end

    v.content = CreateFrame("Frame", nil, v.vis)
    v.content:SetAllPoints(v.vis)
    v.content:SetFrameLevel(v.vis:GetFrameLevel() + 3)
    if extText then
        v.text = extText
        extText:SetParent(v.content)
    else
        v.text = v.content:CreateFontString(nil, "OVERLAY")
    end
    v.text:SetDrawLayer("OVERLAY", 7)
    v.text:SetWordWrap(false)
    v.text:SetJustifyH("CENTER")
    v.text:SetJustifyV("MIDDLE")
    v.text:SetTextColor(1, 1, 1, 1)
    -- text-shadow: 0 0 4px white
    v.text:SetShadowColor(1, 1, 1, 0.55)
    v.text:SetShadowOffset(0, 0)
    return v
end

-- The font must exist before any SetText.
local function EnsureFont(v)
    local flags = v.text.GetFont and select(3, v.text:GetFont())
    if v.fontSet ~= v.fontSize or v.fontPath ~= FontPath() or (flags and flags ~= "") then
        v.fontSet, v.fontPath = v.fontSize, FontPath()
        v.text:SetFont(v.fontPath, v.fontSize, "")
        v.fitW = nil
    end
end

-- Long translations step the font down until the label fits (cached).
local function FitLabel(v, maxW)
    local label = v.text.GetText and v.text:GetText()
    if v.fitW == maxW and v.fitLabel == label then return end
    v.fitW, v.fitLabel = maxW, label
    local size = v.fontSize
    v.text:SetFont(v.fontPath or FontPath(), size, "")
    while size > 7 and v.text.GetUnboundedStringWidth and (v.text:GetUnboundedStringWidth() or 0) > maxW do
        size = size - 1
        v.text:SetFont(v.fontPath or FontPath(), size, "")
    end
end

-- Placement: runs on size, label and font changes only, never per frame.
local function Layout(btn)
    local v = btn._ktTest
    if not v then return end
    EnsureFont(v)
    local w, h = btn:GetWidth(), btn:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end
    local px = Px(btn)
    w, h = ToPx(w, px), ToPx(h, px)
    v.w, v.h = w, h
    v.vis:SetSize(w, h)
    local r = ToPx(h / 2, px)
    local mid = max(0.01, w - 2 * r)

    local function put(t, x, y, pw, ph)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", v.vis, "TOPLEFT", x, -y)
        t:SetSize(max(0.01, pw), max(0.01, ph))
        t.x0, t.x1 = x / w, (x + pw) / w   -- horizontal span, for the gradient
    end
    put(v.corners[1], 0, 0, r, r); put(v.corners[2], w - r, 0, r, r)
    put(v.corners[3], 0, h - r, r, r); put(v.corners[4], w - r, h - r, r, r)
    put(v.sides[1], 0, r, r, h - 2 * r); put(v.sides[2], w - r, r, r, h - 2 * r)
    for i = 1, SEGMENTS do
        local x = r + mid * (i - 1) / SEGMENTS
        put(v.top[i], x, 0, mid / SEGMENTS, r)
        put(v.bottom[i], x, h - r, mid / SEGMENTS, r)
    end

    -- Stars stay off the rounded ends and the border itself.
    local inset = ToPx(max(2, h * 0.12), px)
    v.clip:ClearAllPoints()
    v.clip:SetPoint("TOPLEFT", v.vis, "TOPLEFT", ToPx(r * 0.45, px), -inset)
    v.clip:SetPoint("BOTTOMRIGHT", v.vis, "BOTTOMRIGHT", -ToPx(r * 0.45, px), inset)

    FitLabel(v, max(10, w - 2 * r * 0.8))
    v.text:ClearAllPoints()
    v.text:SetPoint("CENTER", v.vis, "CENTER", 0, 0)
end

-- Repainting must not allocate: two reused colours (SetGradient copies them)
-- and no closures or tables inside the loop.
local fromColour = CreateColor and CreateColor(1, 1, 1, 1)
local toColour = CreateColor and CreateColor(1, 1, 1, 1)
local paintOffset, paintPress = 0, 0

local function Colour(u)
    local r, g, b = GradientAt((u + 2 * paintOffset) / 3)
    local p = paintPress
    if p > 0 then
        r, g, b = r + (ACCENT[1] - r) * p, g + (ACCENT[2] - g) * p, b + (ACCENT[3] - b) * p
    end
    return r, g, b
end

local function PaintPiece(t)
    local r0, g0, b0 = Colour(t.x0)
    local r1, g1, b1 = Colour(t.x1)
    if fromColour and t.SetGradient then
        fromColour:SetRGBA(r0, g0, b0, 1)
        toColour:SetRGBA(r1, g1, b1, 1)
        t:SetGradient("HORIZONTAL", fromColour, toColour)
    else
        t:SetVertexColor((r0 + r1) / 2, (g0 + g1) / 2, (b0 + b1) / 2, 1)
    end
end

-- The slow loops: gradient border, stars, glow pulse. 24 fps.
local function Paint(btn)
    local v = btn._ktTest
    if not (v and v.w) then return end
    local clock = shared.clock
    local press = v.pressP
    local hover = v.hoverP

    LoadAccent()
    paintOffset, paintPress = GradientOffset(clock), press
    for i = 1, 4 do PaintPiece(v.corners[i]) end
    PaintPiece(v.sides[1]); PaintPiece(v.sides[2])
    for i = 1, SEGMENTS do PaintPiece(v.top[i]); PaintPiece(v.bottom[i]) end

    -- Stars: one layer rising, a fainter one drifting; brighter on hover.
    local w, h = v.w, v.h
    local tilesU, tilesV = w / STAR_TILE, h / STAR_TILE
    local rise = (clock * STAR_RISE / STAR_TILE) % 1
    local drift = (clock * STAR_DRIFT / STAR_TILE) % 1
    v.stars[1]:SetTexCoord(drift, drift + tilesU, 0.37, 0.37 + tilesV)
    v.stars[1]:SetVertexColor(1, 1, 1, 0.45 + 0.35 * hover)
    v.stars[2]:SetTexCoord(0.5, 0.5 + tilesU, rise, rise + tilesV)
    v.stars[2]:SetVertexColor(1, 1, 1, 0.22 + 0.2 * hover)

    -- Two blurred circles behind, scale 0.75 -> 1 at 70% of the loop.
    local phase = (clock % PULSE_PERIOD) / PULSE_PERIOD
    local grow = phase < 0.7 and phase / 0.7 or (1 - phase) / 0.3
    local scale = 0.75 + 0.25 * (0.5 - 0.5 * cos(pi * grow))
    for i = 1, 2 do
        local glow = v.glows[i]
        -- Two shades of the accent; the plain accent while pressed.
        local r, g, b = ACCENT[1], ACCENT[2], ACCENT[3]
        local alpha = 0.7
        if press <= 0.5 then
            r, g, b = Shade(r, g, b, GLOW_SHADE[i])
            alpha = GLOW_ALPHA[i]
        end
        glow:ClearAllPoints()
        glow:SetPoint("CENTER", v.vis, "LEFT", w * (i == 1 and 0.32 or 0.68), 0)
        glow:SetSize(w * 0.62 * scale, h * 2.2 * scale)
        glow:SetVertexColor(r, g, b, alpha * 0.55)
    end
end

-- Hover: transform: scale(1.1), capped at MAX_GROW px per side, raised above
-- its neighbours while it grows.
-- The level is taken from the button every time: menus re-level their
-- contents after the button is built, so a level remembered at build time
-- can sit below the card behind the button and hide it.
local MAX_GROW = 4 -- px per side: a full-width 110% would leave its card

local function ApplyScale(btn)
    local v = btn._ktTest
    local w = v.w or btn:GetWidth() or 0
    local grow = w > 0 and min(0.1, 2 * MAX_GROW / w) or 0.1
    v.vis:SetScale(1 + grow * v.hoverP)
    v.vis:SetFrameLevel((btn:GetFrameLevel() or 0) + 1 + (v.hoverP > 0 and 20 or 0))
end

local function Approach(cur, target, step)
    if cur < target then return min(target, cur + step) end
    if cur > target then return max(target, cur - step) end
    return cur
end

-- One driver for every visible Test button.
local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(_, elapsed)
    shared.clock = shared.clock + elapsed
    shared.acc = shared.acc + elapsed
    local repaint = shared.acc >= TICK
    if repaint then shared.acc = 0 end
    for btn in pairs(shared.active) do
        local v = btn._ktTest
        local moving = v.hoverP ~= v.hoverTarget or v.pressP ~= v.pressTarget
        if moving then
            v.hoverP = Approach(v.hoverP, v.hoverTarget, elapsed / HOVER_TIME)
            v.pressP = Approach(v.pressP, v.pressTarget, elapsed / PRESS_TIME)
            ApplyScale(btn)
        end
        if repaint or moving then Paint(btn) end
    end
end)

local function Track(btn, on)
    shared.active[btn] = on or nil
    if next(shared.active) then driver:Show() else driver:Hide() end
end

local function Hook(btn, v)
    btn:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        v.hoverTarget = 1
    end)
    btn:HookScript("OnLeave", function() v.hoverTarget, v.pressTarget = 0, 0 end)
    btn:HookScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or (self.IsEnabled and not self:IsEnabled()) then return end
        v.pressTarget = 1
    end)
    btn:HookScript("OnMouseUp", function() v.pressTarget = 0 end)
    btn:HookScript("OnShow", function(self) Layout(self); Paint(self); Track(self, true) end)
    btn:HookScript("OnHide", function(self)
        Track(self, false)
        v.hoverP, v.hoverTarget, v.pressP, v.pressTarget = 0, 0, 0, 0
        ApplyScale(self)
    end)
    btn:HookScript("OnSizeChanged", function(self) Layout(self); Paint(self) end)
    -- Callers that change the label directly ("Party Test" <-> "Stop Party Test").
    hooksecurefunc(v.text, "SetText", function() Layout(btn) end)
end

-- The label keeps its own case.
function TB.SetLabel(btn, text, fontSize)
    local v = btn and btn._ktTest
    if not v then return end
    if fontSize then v.fontSize = fontSize end
    EnsureFont(v)
    v.text:SetText(tostring(text or ""))
    Layout(btn); Paint(btn)
end

function TB.Refresh(btn)
    if btn and btn._ktTest then Layout(btn); Paint(btn) end
end

-- opts: label, fontSize, text (existing FontString to reuse)
function TB.Style(btn, opts)
    if not btn then return end
    opts = opts or {}
    local v = btn._ktTest
    if not v then
        v = Build(btn, opts.text)
        Hook(btn, v)
        if btn.IsVisible and btn:IsVisible() then Track(btn, true) end
    end
    if opts.fontSize then v.fontSize = opts.fontSize end
    EnsureFont(v)
    if opts.label ~= nil then
        TB.SetLabel(btn, opts.label, opts.fontSize)
    else
        Layout(btn); Paint(btn)
    end
    return btn
end

-- For tests and diagnostics: how many buttons the shared driver animates.
function TB.ActiveCount()
    local n = 0
    for _ in pairs(shared.active) do n = n + 1 end
    return n, driver:IsShown()
end
TB._shared, TB._driver = shared, driver
