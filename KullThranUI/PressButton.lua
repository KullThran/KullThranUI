-- PressButton.lua
-- Botones Reload UI / Reset Profile: port del boton CSS 3D de uiverse
-- (".button_top" sobre una base negra).
--
--   * base negra con esquinas de 0.75em; la cara (borde negro de 2px, relleno de
--     color, texto oscuro) queda levantada 0.2em;
--   * hover: la cara sube hasta 0.33em; pulsado: baja hasta 0 (0.1s);
--   * el color de la cara lo da `opts.color` ({r,g,b} o funcion), asi cada boton
--     conserva el suyo y el tema.
--
-- Pixeles fisicos enteros, igual que KT.NavTabs.
local _, ns = ...
local KT = ns.KT

local PB = KT.PressButton or {}
KT.PressButton = PB

local floor, max, min = math.floor, math.max, math.min

local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROUND_TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\PortalRound.tga"

local BORDER = 2
local LIFT_REST, LIFT_HOVER = 0.20, 0.33     -- em
local RADIUS = 0.75                           -- em
local FADE_TIME = 0.1
local OUTLINE = 0.0
local TEXT = 0.04

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

local function ColorOf(c)
    if type(c) == "function" then
        local r, g, b = c()
        if r then return r, g, b end
    elseif type(c) == "table" then
        return c[1] or c.r or 0.91, c[2] or c.g or 0.91, c[3] or c.b or 0.91
    end
    return 0.91, 0.91, 0.91
end

local function EnsureFont(v)
    if v.fontSet ~= v.fontSize then
        v.fontSet = v.fontSize
        v.text:SetFont(FontPath(), v.fontSize, "")
    end
end

local function Apply(btn)
    local v = btn._ktPress
    if not v then return end
    EnsureFont(v)
    local w, h = btn:GetWidth(), btn:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end
    local px = Px(btn)
    local em = v.fontSize
    local lift = LIFT_REST + (LIFT_HOVER - LIFT_REST) * v.hoverP
    lift = lift * (1 - v.pressP)                              -- active: translateY(0)
    local d = ToPx(lift * em, px)
    local dMax = ToPx(LIFT_HOVER * em, px)
    local fh = h - dMax                                       -- face height
    local fy = dMax - d                                       -- face top
    local rad = ToPx(RADIUS * em, px)
    local bd = max(px, ToPx(BORDER, px))

    ShapePlace(v.base, v.vis, 0, 0, w, h, rad, px, OUTLINE, OUTLINE, OUTLINE, 1)
    ShapePlace(v.edge, v.vis, 0, fy, w, fh, rad, px, OUTLINE, OUTLINE, OUTLINE, 1)
    local r, g, b = ColorOf(v.color)
    ShapePlace(v.fill, v.vis, bd, fy + bd, w - 2 * bd, fh - 2 * bd, max(0, rad - bd), px, r, g, b, 1)

    v.text:ClearAllPoints()
    v.text:SetPoint("CENTER", v.vis, "TOP", 0, -(fy + fh / 2))
end

local function Approach(cur, target, step)
    if cur < target then return min(target, cur + step) end
    if cur > target then return max(target, cur - step) end
    return cur
end

local function OnUpdate(btn, elapsed)
    local v = btn._ktPress
    v.hoverP = Approach(v.hoverP, v.hoverTarget, elapsed / FADE_TIME)
    v.pressP = Approach(v.pressP, v.pressTarget, elapsed / FADE_TIME)
    Apply(btn)
    if v.hoverP == v.hoverTarget and v.pressP == v.pressTarget then
        btn:SetScript("OnUpdate", nil)
    end
end

local function Build(btn, extText)
    local v = { hoverP = 0, pressP = 0, hoverTarget = 0, pressTarget = 0, fontSize = 12 }
    btn._ktPress = v
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end

    v.vis = CreateFrame("Frame", nil, btn)
    v.vis:SetAllPoints(btn)
    v.base = NewShape(v.vis, -4)
    v.edge = NewShape(v.vis, -3)
    v.fill = NewShape(v.vis, -2)

    v.content = CreateFrame("Frame", nil, v.vis)
    v.content:SetAllPoints(v.vis)
    if extText then
        v.text = extText
        extText:SetParent(v.content)
    else
        v.text = v.content:CreateFontString(nil, "OVERLAY")
    end
    v.text:SetDrawLayer("OVERLAY", 7)
    v.text:SetTextColor(TEXT, TEXT, TEXT, 1)
    v.text:SetWordWrap(false)
    v.text:SetJustifyH("CENTER")
    v.text:SetJustifyV("MIDDLE")
    v.text:SetShadowOffset(0, 0)

    btn:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        v.hoverTarget = 1; self:SetScript("OnUpdate", OnUpdate)
    end)
    btn:HookScript("OnLeave", function(self)
        v.hoverTarget, v.pressTarget = 0, 0; self:SetScript("OnUpdate", OnUpdate)
    end)
    btn:HookScript("OnMouseDown", function(self) v.pressTarget = 1; self:SetScript("OnUpdate", OnUpdate) end)
    btn:HookScript("OnMouseUp", function(self) v.pressTarget = 0; self:SetScript("OnUpdate", OnUpdate) end)
    btn:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        v.hoverP, v.pressP, v.hoverTarget, v.pressTarget = 0, 0, 0, 0
        Apply(self)
    end)
    btn:HookScript("OnShow", function(self) Apply(self) end)
    btn:HookScript("OnSizeChanged", function(self) Apply(self) end)
    return v
end

function PB.SetLabel(btn, text, fontSize)
    local v = btn and btn._ktPress
    if not v then return end
    if fontSize then v.fontSize = fontSize end
    EnsureFont(v)
    local s = tostring(text or "")
    local up = KT.NavTabs and KT.NavTabs.Upper
    v.text:SetText(up and up(s) or s:upper())
end

function PB.Refresh(btn)
    if btn and btn._ktPress then Apply(btn) end
end

-- opts: label, fontSize, text (FontString to reuse), color ({r,g,b} | function)
function PB.Style(btn, opts)
    if not btn then return end
    opts = opts or {}
    local v = btn._ktPress or Build(btn, opts.text)
    if opts.color ~= nil then v.color = opts.color end
    if opts.fontSize then v.fontSize = opts.fontSize end
    EnsureFont(v)
    if opts.label ~= nil then PB.SetLabel(btn, opts.label, opts.fontSize) end
    Apply(btn)
    return btn
end
