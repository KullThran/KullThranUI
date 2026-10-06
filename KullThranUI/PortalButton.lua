-- PortalButton.lua
-- Botones largos de los modulos: port del boton uiverse "Discord card"
-- (backdrop-blur / indigo) con el color de accent del addon en lugar del indigo.
--
--   * reposo: tarjeta oscura con degradado de accent a negro, borde de 2px
--     (accent al 30%), esquinas redondeadas, titulo en accent claro, chevron
--     a la derecha al 40%;
--   * hover (0.5s): el boton sube y crece un 2%, el borde sube al 60%, sombra
--     de accent, velo de accent (10-20%), un destello recorre el boton de
--     izquierda a derecha (1s) y el chevron se desplaza y se ilumina;
--   * pulsado: escala 95%.
--   * opcional: un icono en un recuadro a la izquierda (opts.icon).
--
-- Las medidas del CSS se escalan al alto real del boton y todo va en pixeles
-- fisicos enteros, igual que KT.NavTabs.
local _, ns = ...
local KT = ns.KT

local PB = KT.PortalButton or {}
KT.PortalButton = PB

local floor, max, min = math.floor, math.max, math.min

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROUND_TEX = MEDIA .. "PortalRound.tga"      -- quarter disc, centre bottom-right
local CHEVRON_TEX = MEDIA .. "PortalChevron.tga"
local GLOW_TEX = MEDIA .. "NavButtonGlow.tga"

local HOVER_TIME = 0.5      -- duration-500
local PRESS_TIME = 0.5
local SHINE_TIME = 1.0      -- duration-1000
local DARK = 0.03

local function Px(region) return KT.NavTabs.PixelSize(region) end
local function Snap(value, region, minPixels) return (KT.NavTabs.Snap(value, region, minPixels)) end

local function AccentRGB()
    if KT.GetStyleAccentRGB then
        return KT:GetStyleAccentRGB()
    end
    return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333
end

local function FontPath()
    if type(KT.FONT_PATH) == "string" and KT.FONT_PATH ~= "" then
        return KT.FONT_PATH
    end
    if KT.ResolveFontPath then
        return KT:ResolveFontPath()
    end
    return "Fonts\\FRIZQT__.TTF"
end

local function Ease(p)
    local q = 1 - p
    return 1 - q * q * q          -- ease-out
end

local function Mix(a, b, t) return a + (b - a) * t end
local function Mix3(r1, g1, b1, r2, g2, b2, t)
    return r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t
end
local function ToPx(value, px) return floor(value / px + 0.5) * px end

local function Grad(tex, r0, g0, b0, a0, r1, g1, b1, a1)
    if tex.SetGradient and CreateColor then
        tex:SetGradient("HORIZONTAL", CreateColor(r0, g0, b0, a0), CreateColor(r1, g1, b1, a1))
    elseif tex.SetGradientAlpha then
        tex:SetGradientAlpha("HORIZONTAL", r0, g0, b0, a0, r1, g1, b1, a1)
    else
        tex:SetVertexColor((r0 + r1) / 2, (g0 + g1) / 2, (b0 + b1) / 2, (a0 + a1) / 2)
    end
end

-- ---------------------------------------------------------------------------
-- Rounded rectangle: 2 rects + 4 quarter discs, with a horizontal gradient
-- ---------------------------------------------------------------------------
local function NewRound(owner, layer, sub)
    local s = {}
    s.a = owner:CreateTexture(nil, layer, nil, sub); s.a:SetTexture(WHITE)
    s.b = owner:CreateTexture(nil, layer, nil, sub); s.b:SetTexture(WHITE)
    s.tl = owner:CreateTexture(nil, layer, nil, sub); s.tl:SetTexture(ROUND_TEX)
    s.tr = owner:CreateTexture(nil, layer, nil, sub); s.tr:SetTexture(ROUND_TEX)
    s.bl = owner:CreateTexture(nil, layer, nil, sub); s.bl:SetTexture(ROUND_TEX)
    s.br = owner:CreateTexture(nil, layer, nil, sub); s.br:SetTexture(ROUND_TEX)
    s.tr:SetTexCoord(1, 0, 1, 1, 0, 0, 0, 1)
    s.bl:SetTexCoord(0, 1, 0, 0, 1, 1, 1, 0)
    s.br:SetTexCoord(1, 1, 1, 0, 0, 1, 0, 0)
    return s
end

local function RoundPlace(s, owner, x, y, W, H, rad, px)
    if W <= 0 or H <= 0 then return 0 end
    rad = min(rad, floor(min(W, H) / 2 / px) * px)
    for _, t in pairs(s) do t:ClearAllPoints() end
    local midH = max(px, H - 2 * rad)
    local midW = max(px, W - 2 * rad)
    s.a:SetPoint("TOPLEFT", owner, "TOPLEFT", x, -(y + rad)); s.a:SetSize(W, midH)
    s.b:SetPoint("TOPLEFT", owner, "TOPLEFT", x + rad, -y); s.b:SetSize(midW, H)
    local show = rad >= px
    for _, key in ipairs({ "tl", "tr", "bl", "br" }) do s[key]:SetShown(show) end
    if show then
        s.tl:SetPoint("TOPLEFT", owner, "TOPLEFT", x, -y); s.tl:SetSize(rad, rad)
        s.tr:SetPoint("TOPLEFT", owner, "TOPLEFT", x + W - rad, -y); s.tr:SetSize(rad, rad)
        s.bl:SetPoint("TOPLEFT", owner, "TOPLEFT", x, -(y + H - rad)); s.bl:SetSize(rad, rad)
        s.br:SetPoint("TOPLEFT", owner, "TOPLEFT", x + W - rad, -(y + H - rad)); s.br:SetSize(rad, rad)
    end
    return rad
end

local function RoundPaint(s, W, rad, r0, g0, b0, r1, g1, b1)
    local t0 = (W > 0) and (rad / W) or 0
    Grad(s.a, r0, g0, b0, 1, r1, g1, b1, 1)
    local ra, ga, ba = Mix3(r0, g0, b0, r1, g1, b1, t0)
    local rb, gb, bb = Mix3(r0, g0, b0, r1, g1, b1, 1 - t0)
    Grad(s.b, ra, ga, ba, 1, rb, gb, bb, 1)
    s.tl:SetVertexColor(r0, g0, b0, 1); s.bl:SetVertexColor(r0, g0, b0, 1)
    s.tr:SetVertexColor(r1, g1, b1, 1); s.br:SetVertexColor(r1, g1, b1, 1)
end

-- ---------------------------------------------------------------------------
-- Layout / animation
-- ---------------------------------------------------------------------------
local function Layout(btn)
    local v = btn._ktPortal
    if not v then return end
    local w, h = btn:GetWidth(), btn:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end
    local px = Px(btn)
    v.w, v.h, v.px = w, h, px
    v.bw = max(2 * px, ToPx(2, px))                            -- border-2
    v.r = max(3 * px, ToPx(h * 0.22, px))                      -- rounded-2xl
    v.pad = max(4 * px, ToPx(h * 0.38, px))                    -- p-4
    v.gap = max(2 * px, ToPx(h * 0.25, px))                    -- gap-4
    v.lift = max(2 * px, ToPx(h * 0.10, px))                   -- -translate-y-1
    v.cs = max(8 * px, ToPx(h * 0.50, px))                     -- chevron w-5
    v.csShift = max(px, ToPx(h * 0.12, px))                    -- translate-x-1
    v.glow = Snap(14, btn, 1)

    local g = v.glow
    local gTL, gTR, gBL, gBR, gT, gB, gL, gR = unpack(v.glowPieces)
    for _, t in ipairs(v.glowPieces) do t:ClearAllPoints() end
    gTL:SetSize(g, g); gTL:SetPoint("BOTTOMRIGHT", btn, "TOPLEFT", 0, 0)
    gTR:SetSize(g, g); gTR:SetPoint("BOTTOMLEFT", btn, "TOPRIGHT", 0, 0)
    gBL:SetSize(g, g); gBL:SetPoint("TOPRIGHT", btn, "BOTTOMLEFT", 0, 0)
    gBR:SetSize(g, g); gBR:SetPoint("TOPLEFT", btn, "BOTTOMRIGHT", 0, 0)
    gT:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 0); gT:SetPoint("BOTTOMRIGHT", btn, "TOPRIGHT", 0, 0); gT:SetHeight(g)
    gB:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, 0); gB:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, 0); gB:SetHeight(g)
    gL:SetPoint("TOPRIGHT", btn, "TOPLEFT", 0, 0); gL:SetPoint("BOTTOMRIGHT", btn, "BOTTOMLEFT", 0, 0); gL:SetWidth(g)
    gR:SetPoint("TOPLEFT", btn, "TOPRIGHT", 0, 0); gR:SetPoint("BOTTOMLEFT", btn, "BOTTOMRIGHT", 0, 0); gR:SetWidth(g)
end

local function Apply(btn)
    local v = btn._ktPortal
    if not v or not v.w then return end
    local px, w, h = v.px, v.w, v.h
    local e = Ease(v.hoverP)
    local pv = Ease(v.pressP)
    local sh = Ease(v.shineP)
    local ar, ag, ab = v.accR, v.accG, v.accB
    local lr, lg, lb = v.lightR, v.lightG, v.lightB       -- indigo-400 equivalent
    local hr, hg, hb = v.hiR, v.hiG, v.hiB               -- indigo-300 equivalent

    -- hover:scale-[1.02] hover:-translate-y-1 active:scale-95
    local sc = (1 + 0.02 * e) * (1 - 0.05 * pv)
    local ex = ToPx((sc - 1) * w / 2, px)
    local ey = ToPx((sc - 1) * h / 2, px)
    local lift = ToPx(v.lift * e, px)
    v.vis:ClearAllPoints()
    v.vis:SetPoint("TOPLEFT", btn, "TOPLEFT", -ex, ey + lift)
    v.vis:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", ex, -ey + lift)
    local W, H = w + 2 * ex, h + 2 * ey
    local bw, r = v.bw, v.r

    -- Border 30% -> 60% and gradient fill (accent -> black), both opaque.
    local br0, bg0, bb0 = Mix3(DARK, DARK, DARK, ar, ag, ab, 0.30)
    local br1, bg1, bb1 = Mix3(DARK, DARK, DARK, lr, lg, lb, 0.60)
    local cr, cg, cb = Mix3(br0, bg0, bb0, br1, bg1, bb1, e)
    RoundPlace(v.ring, v.vis, 0, 0, W, H, r, px)
    RoundPaint(v.ring, W, r, cr, cg, cb, cr, cg, cb)

    local Wi, Hi = W - 2 * bw, H - 2 * bw
    local ri = max(px, r - bw)
    RoundPlace(v.inner, v.vis, bw, bw, Wi, Hi, ri, px)
    local fr, fg, fb = Mix3(0.02, 0.02, 0.03, ar, ag, ab, 0.16)
    RoundPaint(v.inner, Wi, ri, fr, fg, fb, 0.012, 0.012, 0.016)

    -- Inner content (overflow: hidden).
    v.clip:ClearAllPoints()
    v.clip:SetPoint("TOPLEFT", v.vis, "TOPLEFT", bw, -bw)
    v.clip:SetPoint("BOTTOMRIGHT", v.vis, "BOTTOMRIGHT", -bw, bw)

    -- hover veil: from accent/10 via /20 to /10, fades in.
    local half = ToPx(Wi / 2, px)
    v.veilL:ClearAllPoints(); v.veilL:SetPoint("TOPLEFT", v.clip, "TOPLEFT", 0, 0); v.veilL:SetSize(half, Hi)
    v.veilR:ClearAllPoints(); v.veilR:SetPoint("TOPLEFT", v.clip, "TOPLEFT", half, 0); v.veilR:SetSize(Wi - half, Hi)
    Grad(v.veilL, lr, lg, lb, 0.10, lr, lg, lb, 0.20)
    Grad(v.veilR, lr, lg, lb, 0.20, lr, lg, lb, 0.10)
    v.veilL:SetAlpha(e); v.veilR:SetAlpha(e)

    -- shine band: translateX(-100% -> +100%).
    local sx = ToPx(Mix(-Wi, Wi, sh), px)
    v.shineL:ClearAllPoints(); v.shineL:SetPoint("TOPLEFT", v.clip, "TOPLEFT", sx, 0); v.shineL:SetSize(half, Hi)
    v.shineR:ClearAllPoints(); v.shineR:SetPoint("TOPLEFT", v.clip, "TOPLEFT", sx + half, 0); v.shineR:SetSize(Wi - half, Hi)
    Grad(v.shineL, lr, lg, lb, 0, lr, lg, lb, 0.30)
    Grad(v.shineR, lr, lg, lb, 0.30, lr, lg, lb, 0)

    -- Optional icon tile.
    local textX = v.pad
    if v.icon then
        local ts = ToPx(max(10 * px, Hi - 2 * ToPx(Hi * 0.14, px)), px)
        local ty = ToPx((Hi - ts) / 2, px)
        local tr = max(px, ToPx(ts * 0.25, px))
        RoundPlace(v.tile, v.clip, v.pad, ty, ts, ts, tr, px)
        local t0r, t0g, t0b = Mix3(DARK, DARK, DARK, ar, ag, ab, 0.28)
        local t1r, t1g, t1b = Mix3(DARK, DARK, DARK, lr, lg, lb, 0.40)
        local tcr, tcg, tcb = Mix3(t0r, t0g, t0b, t1r, t1g, t1b, e)
        RoundPaint(v.tile, ts, tr, tcr, tcg, tcb, tcr, tcg, tcb)
        local isz = ToPx(ts * 0.62 * (1 + 0.10 * e), px)
        v.iconTex:ClearAllPoints()
        v.iconTex:SetPoint("CENTER", v.clip, "TOPLEFT", v.pad + ts / 2, -(ty + ts / 2))
        v.iconTex:SetSize(isz, isz)
        local ir, ig, ib = Mix3(lr, lg, lb, hr, hg, hb, e)
        v.iconTex:SetVertexColor(ir, ig, ib, 1)
        for _, t in pairs(v.tile) do t:Show() end
        v.iconTex:Show()
        textX = v.pad + ts + v.gap
    else
        for _, t in pairs(v.tile) do t:Hide() end
        v.iconTex:Hide()
    end

    -- Chevron: 40% -> 100% opacity, translateX(4px).
    local cs = v.cs
    local cx = ToPx(v.pad - v.csShift * e, px)
    v.chev:ClearAllPoints()
    v.chev:SetPoint("RIGHT", v.clip, "RIGHT", -cx, 0)
    v.chev:SetSize(cs, cs)
    v.chev:SetVertexColor(lr, lg, lb, Mix(0.40, 1, e))

    -- Title: accent-400 -> accent-300.
    local tr_, tg_, tb_ = Mix3(lr, lg, lb, hr, hg, hb, e)
    v.text:ClearAllPoints()
    v.text:SetPoint("LEFT", v.clip, "LEFT", textX, 0)
    v.text:SetPoint("RIGHT", v.clip, "RIGHT", -(v.pad + cs + v.gap), 0)
    v.text:SetTextColor(tr_, tg_, tb_, 1)

    -- Drop shadow around the resting position.
    local ga = e * (1 - pv) * 0.55
    for _, t in ipairs(v.glowPieces) do t:SetAlpha(ga) end
end

local function RefreshColors(btn)
    local v = btn._ktPortal
    local r, g, b = AccentRGB()
    v.accR, v.accG, v.accB = r, g, b
    v.lightR, v.lightG, v.lightB = Mix3(r, g, b, 1, 1, 1, 0.35)
    v.hiR, v.hiG, v.hiB = Mix3(r, g, b, 1, 1, 1, 0.60)
    for _, t in ipairs(v.glowPieces) do t:SetVertexColor(r, g, b, 1) end
end

local function Approach(cur, target, step)
    if cur < target then return min(target, cur + step) end
    if cur > target then return max(target, cur - step) end
    return cur
end

local function OnUpdate(btn, elapsed)
    local v = btn._ktPortal
    v.hoverP = Approach(v.hoverP, v.hoverTarget, elapsed / HOVER_TIME)
    v.pressP = Approach(v.pressP, v.pressTarget, elapsed / PRESS_TIME)
    v.shineP = Approach(v.shineP, v.hoverTarget, elapsed / SHINE_TIME)
    Apply(btn)
    if v.hoverP == v.hoverTarget and v.pressP == v.pressTarget and v.shineP == v.hoverTarget then
        btn:SetScript("OnUpdate", nil)   -- no per-frame cost once settled
    end
end

local function Start(btn) btn:SetScript("OnUpdate", OnUpdate) end

local function Build(btn, extText)
    local v = { hoverP = 0, hoverTarget = 0, pressP = 0, pressTarget = 0, shineP = 0 }
    btn._ktPortal = v
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end

    v.glowPieces = {}
    for i = 1, 8 do
        local t = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
        t:SetTexture(GLOW_TEX)
        t:SetBlendMode("ADD")
        t:SetAlpha(0)
        v.glowPieces[i] = t
    end
    local gTL, gTR, gBL, gBR, gT, gB, gL, gR = unpack(v.glowPieces)
    gTL:SetTexCoord(0, 0.5, 0, 0.5)
    gTR:SetTexCoord(0.5, 1, 0, 0.5)
    gBL:SetTexCoord(0, 0.5, 0.5, 1)
    gBR:SetTexCoord(0.5, 1, 0.5, 1)
    gT:SetTexCoord(0.49, 0.51, 0, 0.5)
    gB:SetTexCoord(0.49, 0.51, 0.5, 1)
    gL:SetTexCoord(0, 0.5, 0.49, 0.51)
    gR:SetTexCoord(0.5, 1, 0.49, 0.51)

    v.vis = CreateFrame("Frame", nil, btn)
    v.vis:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    v.vis:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    v.ring = NewRound(v.vis, "BACKGROUND", -3)
    v.inner = NewRound(v.vis, "BACKGROUND", -2)

    -- overflow: hidden
    v.clip = CreateFrame("Frame", nil, v.vis)
    v.clip:SetClipsChildren(true)
    v.veilL = v.clip:CreateTexture(nil, "ARTWORK", nil, 0); v.veilL:SetTexture(WHITE); v.veilL:SetBlendMode("ADD")
    v.veilR = v.clip:CreateTexture(nil, "ARTWORK", nil, 0); v.veilR:SetTexture(WHITE); v.veilR:SetBlendMode("ADD")
    v.shineL = v.clip:CreateTexture(nil, "ARTWORK", nil, 1); v.shineL:SetTexture(WHITE); v.shineL:SetBlendMode("ADD")
    v.shineR = v.clip:CreateTexture(nil, "ARTWORK", nil, 1); v.shineR:SetTexture(WHITE); v.shineR:SetBlendMode("ADD")
    v.tile = NewRound(v.clip, "ARTWORK", 2)
    v.iconTex = v.clip:CreateTexture(nil, "ARTWORK", nil, 3)
    v.chev = v.clip:CreateTexture(nil, "ARTWORK", nil, 3)
    v.chev:SetTexture(CHEVRON_TEX)

    if extText then
        -- Reuses a label owned by the caller (it keeps calling text:SetText).
        v.text = extText
        extText:SetParent(v.clip)
    else
        v.text = v.clip:CreateFontString(nil, "OVERLAY")
    end
    v.text:SetDrawLayer("OVERLAY", 7)
    v.text:SetWordWrap(false)
    v.text:SetJustifyH("LEFT")
    v.text:SetJustifyV("MIDDLE")
    v.text:SetShadowOffset(0, 0)
    v.fontSize = 13

    RefreshColors(btn)

    btn:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        RefreshColors(self)
        v.hoverTarget = 1; Start(self)
    end)
    btn:HookScript("OnLeave", function(self)
        v.hoverTarget, v.pressTarget = 0, 0; Start(self)
    end)
    btn:HookScript("OnMouseDown", function(self) v.pressTarget = 1; Start(self) end)
    btn:HookScript("OnMouseUp", function(self) v.pressTarget = 0; Start(self) end)
    btn:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        v.hoverP, v.hoverTarget, v.pressP, v.pressTarget, v.shineP = 0, 0, 0, 0, 0
        Apply(self)
    end)
    btn:HookScript("OnSizeChanged", function(self) Layout(self); Apply(self) end)
    return v
end

function PB.SetLabel(btn, text, fontSize)
    local v = btn and btn._ktPortal
    if not v then return end
    if fontSize then v.fontSize = fontSize end
    v.text:SetFont(FontPath(), v.fontSize, "OUTLINE")
    local up = KT.NavTabs and KT.NavTabs.Upper
    v.text:SetText(up and up(text) or tostring(text or ""):upper())
end

-- Optional icon (texture path) shown in a tile on the left; nil removes it.
function PB.SetIcon(btn, texture)
    local v = btn and btn._ktPortal
    if not v then return end
    v.icon = texture
    if texture then v.iconTex:SetTexture(texture) end
    Apply(btn)
end

-- opts: label, fontSize, text (existing FontString to reuse), icon
function PB.Style(btn, opts)
    if not btn then return end
    opts = opts or {}
    local v = btn._ktPortal or Build(btn, opts.text)
    if opts.text then v.text:SetFont(FontPath(), opts.fontSize or v.fontSize, "OUTLINE") end
    if opts.label ~= nil then PB.SetLabel(btn, opts.label, opts.fontSize) end
    if opts.icon then PB.SetIcon(btn, opts.icon) end
    RefreshColors(btn)
    Layout(btn)
    Apply(btn)
    return btn
end

-- Restyles a Button that already owns a `.text` FontString (preview/test
-- buttons built by hand in module option screens). kind: "short" | "long".
function KT.StyleActionButton(btn, kind, fontSize)
    if not btn or not btn.text then return end
    local text = btn.text
    local upper = KT.NavTabs and KT.NavTabs.Upper
    if upper and not text._ktUpperWrapped then
        local rawSetText = text.SetText
        text.SetText = function(self, value) rawSetText(self, upper(value)) end
        text._ktUpperWrapped = true
    end
    btn._ktActionButton = true
    if kind == "test" and KT.TestButton then
        KT.TestButton.Style(btn, { text = text, fontSize = fontSize or 11 })
    elseif kind == "long" and KT.PortalButton then
        PB.Style(btn, { text = text, fontSize = fontSize or 12 })
    elseif KT.NavTabs then
        KT.NavTabs.StyleButton(btn, { text = text, fontSize = fontSize or 11, variant = "short" })
    end
end
