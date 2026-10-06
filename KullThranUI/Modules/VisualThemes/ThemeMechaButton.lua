-- ThemeMechaButton.lua
-- Animaciones del boton "mecanico" de uiverse (".post888-mecha") para las
-- tarjetas de Visual Styles. NO cambia el diseno de la tarjeta: se superponen
-- solo los movimientos del CSS, aplicados a la tarjeta completa.
--
--   * hover: un brazo articulado con garra se acerca y abre la garra, y la
--     tarjeta se ilumina un 5%;
--   * estilo en uso: el brazo agarra, la tarjeta se hunde 6px y se enciende un
--     LED verde (si se dan textos, el texto se desliza 8px de uno a otro);
--   * el brazo y la garra usan el color del tema de la tarjeta.
--
-- Las partes giradas usan Texture:SetRotation.
local _, ns = ...
local KT = ns.KT

local BM = KT.MechaButton or {}
KT.MechaButton = BM

local floor, max, min = math.floor, math.max, math.min
local cos, sin, rad = math.cos, math.sin, math.rad

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROUND_TEX = MEDIA .. "PortalRound.tga"
local DISC_TEX = MEDIA .. "PortalDisc.tga"
local RADIAL_TEX = MEDIA .. "PortalRadial.tga"

local CSS_H = 54                       -- default scale: a 28px-high button
local HOVER_TIME, ON_TIME = 0.3, 0.3

local FLIP = {
    tl = { 0, 0, 0, 1, 1, 0, 1, 1 },
    tr = { 1, 0, 1, 1, 0, 0, 0, 1 },
    bl = { 0, 1, 0, 0, 1, 1, 1, 0 },
    br = { 1, 1, 1, 0, 0, 1, 0, 0 },
}
local CORNERS = { "tl", "tr", "bl", "br" }

local function Px(region) return KT.NavTabs.PixelSize(region) end
local function ToPx(value, px) return floor(value / px + 0.5) * px end
local function Mix(a, b, t) return a + (b - a) * t end

local function FontPath()
    if type(KT.FONT_PATH) == "string" and KT.FONT_PATH ~= "" then return KT.FONT_PATH end
    return "Fonts\\FRIZQT__.TTF"
end

-- ---------------------------------------------------------------------------
-- Rounded rectangle (3 rects + 4 quarter discs)
-- ---------------------------------------------------------------------------
local function NewShape(owner, layer, sub)
    local s = { rects = {} }
    for i = 1, 3 do
        local t = owner:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(WHITE)
        s.rects[i] = t
    end
    for _, c in ipairs(CORNERS) do
        local t = owner:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(ROUND_TEX)
        t:SetTexCoord(unpack(FLIP[c]))
        s[c] = t
    end
    return s
end

local function Put(tex, owner, x0, y0, x1, y1)
    if x1 - x0 <= 0 or y1 - y0 <= 0 then tex:Hide(); return end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", owner, "TOPLEFT", x0, -y0)
    tex:SetSize(x1 - x0, y1 - y0)
    tex:Show()
end

local function ShapePlace(s, owner, x, y, W, H, r, px, cr, cg, cb, ca)
    r = max(0, min(r, floor(min(W, H) / 2 / px) * px))
    local x1, y1 = x + W, y + H
    Put(s.rects[1], owner, x, y + r, x1, y1 - r)
    Put(s.rects[2], owner, x + r, y, x1 - r, y + r)
    Put(s.rects[3], owner, x + r, y1 - r, x1 - r, y1)
    local pos = { tl = { x, y }, tr = { x1 - r, y }, bl = { x, y1 - r }, br = { x1 - r, y1 - r } }
    for _, c in ipairs(CORNERS) do
        local t = s[c]
        if r >= px then
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", owner, "TOPLEFT", pos[c][1], -pos[c][2])
            t:SetSize(r, r)
            t:Show()
        else
            t:Hide()
        end
    end
    for _, t in ipairs(s.rects) do t:SetVertexColor(cr, cg, cb, ca) end
    for _, c in ipairs(CORNERS) do s[c]:SetVertexColor(cr, cg, cb, ca) end
end

-- ---------------------------------------------------------------------------
-- Rotated pill (rect + 2 end discs) and rotated disc, centred at (cx, cy)
-- measured from the button's top-left (y down).
-- ---------------------------------------------------------------------------
local function NewPill(owner, layer, sub)
    local p = {}
    p.rect = owner:CreateTexture(nil, layer, nil, sub); p.rect:SetTexture(WHITE)
    p.a = owner:CreateTexture(nil, layer, nil, sub); p.a:SetTexture(DISC_TEX)
    p.b = owner:CreateTexture(nil, layer, nil, sub); p.b:SetTexture(DISC_TEX)
    return p
end

local function Rot(tex, ang)
    if tex.SetRotation then tex:SetRotation(-ang) end
end

local function Center(tex, owner, cx, cy, w, h)
    tex:ClearAllPoints()
    tex:SetSize(max(1, w), max(1, h))
    tex:SetPoint("CENTER", owner, "TOPLEFT", cx, -cy)
end

-- Pill of length L and thickness T whose axis passes through (cx, cy) at angle `ang`.
local function PillPlace(p, owner, cx, cy, L, T, ang, cr, cg, cb)
    local body = max(1, L - T)
    Center(p.rect, owner, cx, cy, body, T); Rot(p.rect, ang)
    local dx, dy = cos(ang) * (body / 2), sin(ang) * (body / 2)
    Center(p.a, owner, cx - dx, cy - dy, T, T)
    Center(p.b, owner, cx + dx, cy + dy, T, T)
    p.rect:SetVertexColor(cr, cg, cb, 1)
    p.a:SetVertexColor(cr, cg, cb, 1)
    p.b:SetVertexColor(cr, cg, cb, 1)
end

-- ---------------------------------------------------------------------------
local function Apply(btn)
    local v = btn._ktMecha
    if not v then return end
    local W, Hb = btn:GetWidth(), btn:GetHeight()
    if not W or W <= 0 or not Hb or Hb <= 0 then return end
    local px = Px(btn)
    local s = v.scale or (Hb / CSS_H)
    local hov, onP = v.hoverP, v.onP
    local ar, ag, ab = v.accent[1], v.accent[2], v.accent[3]

    -- the button sinks 6px when "on" (translateY(6px)); everything is anchored to it
    -- (the anchor is read lazily: a card gets its anchor after it is built)
    local press = ToPx(6 * s * onP, px)
    if press ~= (v.pressApplied or 0) then
        if not v.basePoint and btn:GetNumPoints() > 0 then
            local point, rel, relPoint, x, y = btn:GetPoint(1)
            v.basePoint, v.baseRel, v.baseRelPoint, v.baseX, v.baseY = point, rel, relPoint, x or 0, y or 0
        end
        if v.basePoint then
            v.pressApplied = press
            btn:ClearAllPoints()
            btn:SetPoint(v.basePoint, v.baseRel, v.baseRelPoint, v.baseX, v.baseY - press)
        end
    end

    -- hover: filter brightness(1.05)
    v.bright:SetAllPoints(btn)
    v.bright:SetColorTexture(1, 1, 1, 0.05 * hov)

    -- text: OFF slides up and fades, ON rises into place
    v.off:ClearAllPoints()
    v.off:SetPoint("CENTER", btn, "CENTER", 0, (v.hasText and 1 or 0) + 8 * s * onP)
    v.off:SetAlpha(1 - onP)
    v.on:ClearAllPoints()
    v.on:SetPoint("CENTER", btn, "CENTER", 0, (v.hasText and 1 or 0) - 8 * s * (1 - onP))
    v.on:SetAlpha(onP)

    -- LED (top right of the button)
    local ls = max(px * 3, ToPx(10 * s, px))
    local lx, ly = W - ls / 2 - 6 * s, Hb / 2
    if v.ledCorner then lx, ly = W - ls / 2 - 8, ls / 2 + 8 end
    Center(v.led, btn, lx, ly, ls, ls)
    v.led:SetVertexColor(Mix(0.2, 0.52, onP), Mix(0.255, 0.94, onP), Mix(0.33, 0.67, onP), 1)
    local gs = ls * 3
    Center(v.ledGlow, btn, lx, ly, gs, gs)
    v.ledGlow:SetVertexColor(0.13, 0.77, 0.37, 1)
    v.ledGlow:SetAlpha(0.8 * onP)

    -- arm: pivot (24,24) of a 140x110 box placed at (-2, -10)*s from the button
    local ox, oy = -2 * s, -10 * s
    if v.armInside then ox, oy = 4, 2 end
    local theta = rad(Mix(Mix(-17, 2, hov), 10, onP))
    local tx = Mix(Mix(0, 6, hov), 12, onP)
    local ty = Mix(0, 6, onP)
    local ct, st = cos(theta), sin(theta)
    local function world(px_, py_)                 -- arm-local point -> button coords
        local lx_, ly_ = (px_ - 24) + tx, (py_ - 24) + ty
        return ox + (24 + lx_ * ct - ly_ * st) * s, oy + (24 + lx_ * st + ly_ * ct) * s
    end
    local dark = { Mix(0.11, ar, 0.25), Mix(0.135, ag, 0.25), Mix(0.22, ab, 0.25) }
    local mid = { Mix(0.135, ar, 0.35), Mix(0.17, ag, 0.35), Mix(0.27, ab, 0.35) }
    local light = { Mix(0.165, ar, 0.5), Mix(0.21, ag, 0.5), Mix(0.32, ab, 0.5) }

    local bx, by = world(10 + 18, 14 + 18)
    Center(v.armBase, btn, bx, by, 36 * s, 36 * s); Rot(v.armBase, theta)
    v.armBase:SetVertexColor(dark[1], dark[2], dark[3], 1)
    local jx, jy = world(36 + 9, 28 + 9)
    Center(v.jointOuter, btn, jx, jy, 18 * s, 18 * s)
    Center(v.jointInner, btn, jx, jy, 9 * s, 9 * s)
    v.jointOuter:SetVertexColor(dark[1], dark[2], dark[3], 1)
    v.jointInner:SetVertexColor(ar, ag, ab, 1)

    local fx, fy = world(44 + 31, 32 + 6)
    PillPlace(v.fore, btn, fx, fy, 62 * s, 12 * s, theta, mid[1], mid[2], mid[3])

    local cdx = 6 * hov
    local phiTop = rad(Mix(Mix(22, 6, hov), 34, onP))
    local phiBot = rad(Mix(Mix(-20, -6, hov), -34, onP))
    local function finger(set, pivotY, phi)
        local gx, gy = 98 + cdx + 12 * cos(phi), pivotY + 12 * sin(phi)
        local wx, wy = world(gx, gy)
        PillPlace(set, btn, wx, wy, 28 * s, 8 * s, theta + phi, light[1], light[2], light[3])
    end
    finger(v.fingerTop, 29, phiTop)
    finger(v.fingerBot, 46, phiBot)
end

local function Approach(cur, target, step)
    if cur < target then return min(target, cur + step) end
    if cur > target then return max(target, cur - step) end
    return cur
end

local function OnUpdate(btn, elapsed)
    local v = btn._ktMecha
    v.hoverP = Approach(v.hoverP, v.hoverTarget, elapsed / HOVER_TIME)
    v.onP = Approach(v.onP, v.onTarget, elapsed / ON_TIME)
    Apply(btn)
    if v.hoverP == v.hoverTarget and v.onP == v.onTarget then btn:SetScript("OnUpdate", nil) end
end

local function Kick(btn) btn:SetScript("OnUpdate", OnUpdate) end

local function Build(btn)
    local v = { hoverP = 0, hoverTarget = 0, onP = 0, onTarget = 0, fontSize = 11 }
    btn._ktMecha = v

    v.over = CreateFrame("Frame", nil, btn)
    v.over:SetAllPoints(btn)
    v.over:SetFrameLevel(btn:GetFrameLevel() + 3)

    v.bright = v.over:CreateTexture(nil, "BACKGROUND")
    v.bright:SetColorTexture(1, 1, 1, 0)

    v.off = v.over:CreateFontString(nil, "OVERLAY")
    v.on = v.over:CreateFontString(nil, "OVERLAY")
    v.on:SetTextColor(0.65, 0.95, 0.82, 1)

    v.led = v.over:CreateTexture(nil, "ARTWORK")
    v.led:SetTexture(DISC_TEX)
    v.ledGlow = v.over:CreateTexture(nil, "BACKGROUND", nil, 1)
    v.ledGlow:SetTexture(RADIAL_TEX)
    v.ledGlow:SetBlendMode("ADD")

    -- the arm lives above the rest, as in the original
    v.arm = CreateFrame("Frame", nil, btn)
    v.arm:SetAllPoints(btn)
    v.arm:SetFrameLevel(v.over:GetFrameLevel() + 2)
    v.armBase = v.arm:CreateTexture(nil, "ARTWORK", nil, 0); v.armBase:SetTexture(WHITE)
    v.fore = NewPill(v.arm, "ARTWORK", 1)
    v.jointOuter = v.arm:CreateTexture(nil, "ARTWORK", nil, 2); v.jointOuter:SetTexture(DISC_TEX)
    v.jointInner = v.arm:CreateTexture(nil, "ARTWORK", nil, 3); v.jointInner:SetTexture(DISC_TEX)
    v.fingerTop = NewPill(v.arm, "ARTWORK", 4)
    v.fingerBot = NewPill(v.arm, "ARTWORK", 4)

    btn:HookScript("OnShow", function(self) Apply(self) end)
    btn:HookScript("OnSizeChanged", function(self) Apply(self) end)
    btn:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        v.hoverP, v.hoverTarget = 0, 0
        v.onP = v.onTarget
        Apply(self)
    end)
    return v
end

function BM.SetHover(btn, on)
    local v = btn and btn._ktMecha
    if not v then return end
    v.hoverTarget = on and 1 or 0
    Kick(btn)
end

function BM.SetOn(btn, on)
    local v = btn and btn._ktMecha
    if not v then return end
    v.onTarget = on and 1 or 0
    Kick(btn)
end

-- Colour of the OFF label (the state the existing button paints itself).
function BM.SetOffColor(btn, r, g, b)
    local v = btn and btn._ktMecha
    if v then v.off:SetTextColor(r, g, b, 1) end
end

-- opts: accent {r,g,b}, label, onLabel, fontSize, font, on
-- opts.scale: arm / sink scale (default: frame height / 54); opts.ledCorner puts
-- the LED in the top-right corner; opts.armInside keeps the arm inside the frame.
function BM.Style(btn, opts)
    if not btn then return end
    opts = opts or {}
    local v = btn._ktMecha or Build(btn)
    v.accent = opts.accent or { 0.49, 0.98, 1 }
    v.scale = opts.scale
    v.ledCorner = opts.ledCorner
    v.armInside = opts.armInside
    v.hasText = (opts.label ~= nil)
    v.fontSize = opts.fontSize or v.fontSize
    -- the font must exist before any SetText
    local font = opts.font or FontPath()
    v.off:SetFont(font, v.fontSize, "")
    v.on:SetFont(font, v.fontSize, "")
    v.off:SetTextColor(1, 1, 1, 1)
    v.off:SetText(tostring(opts.label or ""))
    v.on:SetText(tostring(opts.onLabel or ""))
    if opts.on ~= nil then
        v.onTarget = opts.on and 1 or 0
        v.onP = v.onTarget
    end
    Apply(btn)
    return v
end
