-- SolidButton.lua
-- Boton solido (Reload UI / Reset Profile): port del CSS ".button.x" de uiverse.
--
--   * relleno liso con esquinas de 8px y borde de 1px (color base al 25%);
--   * texto blanco en mayusculas;
--   * hover (0.6s): crece un 2% y el relleno se aclara y se desatura;
--   * pulsado: se encoge un 2% y baja al 80% de opacidad.
--
-- El color NO es fijo: lo da `opts.color` ({r,g,b} o funcion que los devuelve),
-- asi cada boton conserva su color y el tema. Pixeles fisicos enteros, igual
-- que KT.NavTabs.
local _, ns = ...
local KT = ns.KT

local SB = KT.SolidButton or {}
KT.SolidButton = SB

local floor, max, min = math.floor, math.max, math.min

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROUND_TEX = MEDIA .. "PortalRound.tga"

local RADIUS = 8
local BORDER = 1
local HOVER_SCALE = 0.02
local PRESS_SCALE = -0.02
local FADE_TIME = 0.6
local HOVER_GRAY, HOVER_MIX = 156 / 255, 0.47         -- rgb(86,98,246) -> rgb(119,133,204)

local FLIP = {
    tl = { 0, 0, 0, 1, 1, 0, 1, 1 },
    tr = { 1, 0, 1, 1, 0, 0, 0, 1 },
    bl = { 0, 1, 0, 0, 1, 1, 1, 0 },
    br = { 1, 1, 1, 0, 0, 1, 0, 0 },
}
local CORNERS = { "tl", "tr", "bl", "br" }

local function Px(region) return KT.NavTabs.PixelSize(region) end
local function ToPx(value, px) return floor(value / px + 0.5) * px end

local function FontPath()
    if type(KT.FONT_PATH) == "string" and KT.FONT_PATH ~= "" then return KT.FONT_PATH end
    if KT.ResolveFontPath then return KT:ResolveFontPath() end
    return "Fonts\\FRIZQT__.TTF"
end

local function NewShape(owner, sub)
    local s = { rects = {} }
    for i = 1, 3 do
        local t = owner:CreateTexture(nil, "BACKGROUND", nil, sub)
        t:SetTexture(WHITE)
        s.rects[i] = t
    end
    for _, c in ipairs(CORNERS) do
        local t = owner:CreateTexture(nil, "BACKGROUND", nil, sub)
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

-- Rounded rectangle (x, y, W, H) with radius r, painted r,g,b,a.
local function ShapePlace(s, owner, x, y, W, H, r, px, cr, cg, cb, ca)
    r = max(0, min(r, floor(min(W, H) / 2 / px) * px))
    local x1, y1 = x + W, y + H
    Put(s.rects[1], owner, x, y + r, x1, y1 - r)
    Put(s.rects[2], owner, x + r, y, x1 - r, y + r)
    Put(s.rects[3], owner, x + r, y1 - r, x1 - r, y1)
    local pos = {
        tl = { x, y }, tr = { x1 - r, y }, bl = { x, y1 - r }, br = { x1 - r, y1 - r },
    }
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

local function ColorOf(c)
    if type(c) == "function" then
        local r, g, b = c()
        if r then return r, g, b end
        return 0.5, 0.5, 0.5
    end
    if type(c) == "table" then return c[1] or c.r or 0.5, c[2] or c.g or 0.5, c[3] or c.b or 0.5 end
    return 0.5, 0.5, 0.5
end

local function BaseColor(v) return ColorOf(v.color) end

local function Apply(btn)
    local v = btn._ktSolid
    if not v then return end
    local w, h = btn:GetWidth(), btn:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end
    local px = Px(btn)
    local hov, prs = v.hoverP, v.pressP

    local grow = HOVER_SCALE * hov + PRESS_SCALE * prs
    local gx = ToPx(w * grow / 2, px)
    local gy = ToPx(h * grow / 2, px)
    v.vis:ClearAllPoints()
    v.vis:SetPoint("TOPLEFT", btn, "TOPLEFT", -gx, gy)
    v.vis:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", gx, -gy)
    v.vis:SetAlpha(1 - 0.2 * prs)
    local W, H = w + 2 * gx, h + 2 * gy

    local r, g, b = BaseColor(v)
    local fr = r + (HOVER_GRAY - r) * HOVER_MIX * hov
    local fg = g + (HOVER_GRAY - g) * HOVER_MIX * hov
    local fb = b + (HOVER_GRAY - b) * HOVER_MIX * hov
    local bd = max(px, ToPx(BORDER, px))
    local rad = ToPx(RADIUS, px)
    local br, bg, bb = ColorOf(v.borderColor or v.color)
    ShapePlace(v.border, v.vis, 0, 0, W, H, rad, px, br, bg, bb, v.borderAlpha or 0.25)
    ShapePlace(v.fill, v.vis, bd, bd, W - 2 * bd, H - 2 * bd, max(0, rad - bd), px, fr, fg, fb, 1)

    v.text:ClearAllPoints()
    v.text:SetPoint("CENTER", v.vis, "CENTER", 0, 0)
end

local function Approach(cur, target, step)
    if cur < target then return min(target, cur + step) end
    if cur > target then return max(target, cur - step) end
    return cur
end

local function OnUpdate(btn, elapsed)
    local v = btn._ktSolid
    local step = elapsed / FADE_TIME
    v.hoverP = Approach(v.hoverP, v.hoverTarget, step)
    v.pressP = Approach(v.pressP, v.pressTarget, step)
    Apply(btn)
    if v.hoverP == v.hoverTarget and v.pressP == v.pressTarget then
        btn:SetScript("OnUpdate", nil)
    end
end

local function Start(btn) btn:SetScript("OnUpdate", OnUpdate) end

local function Build(btn, extText)
    local v = { hoverP = 0, pressP = 0, hoverTarget = 0, pressTarget = 0, fontSize = 12 }
    btn._ktSolid = v
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end

    v.vis = CreateFrame("Frame", nil, btn)
    v.vis:SetAllPoints(btn)
    v.border = NewShape(v.vis, -2)
    v.fill = NewShape(v.vis, -1)

    v.content = CreateFrame("Frame", nil, v.vis)
    v.content:SetAllPoints(v.vis)
    if extText then
        v.text = extText
        extText:SetParent(v.content)
    else
        v.text = v.content:CreateFontString(nil, "OVERLAY")
    end
    v.text:SetDrawLayer("OVERLAY", 7)
    v.text:SetTextColor(1, 1, 1, 1)
    v.text:SetWordWrap(false)
    v.text:SetJustifyH("CENTER")
    v.text:SetJustifyV("MIDDLE")

    btn:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        v.hoverTarget = 1; Start(self)
    end)
    btn:HookScript("OnLeave", function(self)
        v.hoverTarget, v.pressTarget = 0, 0; Start(self)
    end)
    btn:HookScript("OnMouseDown", function(self) v.pressTarget = 1; Start(self) end)
    btn:HookScript("OnMouseUp", function(self) v.pressTarget = 0; Start(self) end)
    btn:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        v.hoverP, v.pressP, v.hoverTarget, v.pressTarget = 0, 0, 0, 0
        Apply(self)
    end)
    btn:HookScript("OnShow", function(self) Apply(self) end)
    btn:HookScript("OnSizeChanged", function(self) Apply(self) end)
    return v
end

function SB.SetLabel(btn, text, fontSize)
    local v = btn and btn._ktSolid
    if not v then return end
    if fontSize then v.fontSize = fontSize end
    v.text:SetFont(FontPath(), v.fontSize, "OUTLINE")
    local s = tostring(text or "")
    local up = KT.NavTabs and KT.NavTabs.Upper
    v.text:SetText(up and up(s) or s:upper())
end

-- Repaint after a theme / colour change.
function SB.Refresh(btn)
    if btn and btn._ktSolid then Apply(btn) end
end

-- opts: label, fontSize, text (FontString to reuse), color / borderColor
-- ({r,g,b} | function), borderAlpha
function SB.Style(btn, opts)
    if not btn then return end
    opts = opts or {}
    local v = btn._ktSolid or Build(btn, opts.text)
    if opts.color ~= nil then v.color = opts.color end
    if opts.borderColor ~= nil then v.borderColor = opts.borderColor end
    if opts.borderAlpha ~= nil then v.borderAlpha = opts.borderAlpha end
    if opts.fontSize then v.fontSize = opts.fontSize end
    v.text:SetFont(FontPath(), v.fontSize, "OUTLINE")
    if opts.label ~= nil then SB.SetLabel(btn, opts.label, opts.fontSize) end
    Apply(btn)
    return btn
end
