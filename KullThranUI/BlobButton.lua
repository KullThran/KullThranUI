-- BlobButton.lua
-- Botones Reload UI / Reset Profile: port del boton Tailwind de las dos manchas
-- difuminadas.
--
--   * fondo oscuro, borde de 2px, esquinas de 12px, texto blanco en negrita a
--     la izquierda;
--   * dos manchas difuminadas a la derecha (la pequena y la grande), pegadas al
--     boton y recortadas por el;
--   * hover (0.5s): crece un 5%, el borde y el texto se aclaran, la mancha
--     pequena baja hacia la izquierda y la grande sale por la derecha y crece.
--
-- El color NO es fijo: lo da `opts.color` ({r,g,b} o funcion), asi cada boton
-- conserva el suyo y el tema. Pixeles fisicos enteros, igual que KT.NavTabs.
local _, ns = ...
local KT = ns.KT

local BB = KT.BlobButton or {}
KT.BlobButton = BB

local floor, max, min = math.floor, math.max, math.min

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROUND_TEX = MEDIA .. "PortalRound.tga"
local RADIAL_TEX = MEDIA .. "PortalRadial.tga"

local CSS_H = 64                      -- h-16
local RADIUS, BORDER = 12, 2          -- rounded-xl, border-2
local HOVER_SCALE = 0.05
local FADE_TIME = 0.5
local BG = { 0.06, 0.07, 0.10 }

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
        return c[1] or c.r or 0.5, c[2] or c.g or 0.5, c[3] or c.b or 0.5
    end
    return 0.5, 0.5, 0.5
end

local function Ease(p) return p * p * (3 - 2 * p) end

local function Apply(btn)
    local v = btn._ktBlob
    if not v then return end
    local w, h = btn:GetWidth(), btn:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end
    local px = Px(btn)
    local p = Ease(v.hoverP)
    local s = h / CSS_H

    local gx = ToPx(w * HOVER_SCALE * p / 2, px)
    local gy = ToPx(h * HOVER_SCALE * p / 2, px)
    v.vis:ClearAllPoints()
    v.vis:SetPoint("TOPLEFT", btn, "TOPLEFT", -gx, gy)
    v.vis:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", gx, -gy)
    local W, H = w + 2 * gx, h + 2 * gy

    local r, g, b = ColorOf(v.color)
    local lr, lg, lb = Mix(r, 1, 0.45), Mix(g, 1, 0.45), Mix(b, 1, 0.45)    -- border-emerald-400
    local tr, tg, tb = Mix(r, 1, 0.75), Mix(g, 1, 0.75), Mix(b, 1, 0.75)    -- text-emerald-300
    local bd = max(2 * px, ToPx(BORDER, px))
    local rad = ToPx(RADIUS * max(0.6, s), px)
    ShapePlace(v.border, v.vis, 0, 0, W, H, rad, px, Mix(r, lr, p), Mix(g, lg, p), Mix(b, lb, p), 1)
    ShapePlace(v.fill, v.vis, bd, bd, W - 2 * bd, H - 2 * bd, max(0, rad - bd), px, BG[1], BG[2], BG[3], 1)

    -- Interior clipped to the border: the blobs live in it.
    v.clip:ClearAllPoints()
    v.clip:SetPoint("TOPLEFT", v.vis, "TOPLEFT", bd, -bd)
    v.clip:SetPoint("BOTTOMRIGHT", v.vis, "BOTTOMRIGHT", -bd, bd)

    -- Small blob (indigo): right-2 top-2 40px -> right-10 bottom-4 (blur -> sharper)
    local b1 = ToPx(40 * s, px)
    local b1R = Mix(8, 40, p) * s
    local b1Y = Mix(8, (CSS_H - 40 + 16), p) * s            -- top-2 -> bottom:-16px
    v.blob1:ClearAllPoints()
    v.blob1:SetSize(b1, b1)
    v.blob1:SetPoint("TOPRIGHT", v.clip, "TOPRIGHT", -ToPx(b1R, px), -ToPx(b1Y, px))
    v.blob1:SetVertexColor(r, g, b, 0.75 + 0.25 * p)

    -- Big blob (teal): right-6 top-4 64px -> right:-24px, scale 1.1
    local b2 = ToPx(64 * s * (1 + 0.1 * p), px)
    local b2R = Mix(24, -24, p) * s
    v.blob2:ClearAllPoints()
    v.blob2:SetSize(b2, b2)
    v.blob2:SetPoint("TOPRIGHT", v.clip, "TOPRIGHT", -ToPx(b2R, px), -ToPx(16 * s, px))
    v.blob2:SetVertexColor(lr, lg, lb, 0.8)

    v.text:ClearAllPoints()
    v.text:SetPoint("LEFT", v.vis, "LEFT", ToPx(12 * max(0.7, s) + bd, px), 0)
    v.text:SetTextColor(Mix(1, tr, p), Mix(1, tg, p), Mix(1, tb, p), 1)
end

local function Approach(cur, target, step)
    if cur < target then return min(target, cur + step) end
    if cur > target then return max(target, cur - step) end
    return cur
end

local function OnUpdate(btn, elapsed)
    local v = btn._ktBlob
    v.hoverP = Approach(v.hoverP, v.hoverTarget, elapsed / FADE_TIME)
    Apply(btn)
    if v.hoverP == v.hoverTarget then btn:SetScript("OnUpdate", nil) end
end

local function Build(btn, extText)
    local v = { hoverP = 0, hoverTarget = 0, fontSize = 12 }
    btn._ktBlob = v
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end

    v.vis = CreateFrame("Frame", nil, btn)
    v.vis:SetAllPoints(btn)
    v.border = NewShape(v.vis, -3)
    v.fill = NewShape(v.vis, -2)

    v.clip = CreateFrame("Frame", nil, v.vis)
    if v.clip.SetClipsChildren then v.clip:SetClipsChildren(true) end
    v.blob1 = v.clip:CreateTexture(nil, "ARTWORK")
    v.blob1:SetTexture(RADIAL_TEX)
    v.blob2 = v.clip:CreateTexture(nil, "ARTWORK")
    v.blob2:SetTexture(RADIAL_TEX)

    v.content = CreateFrame("Frame", nil, v.vis)
    v.content:SetAllPoints(v.vis)
    v.content:SetFrameLevel(v.clip:GetFrameLevel() + 2)
    if extText then
        v.text = extText
        extText:SetParent(v.content)
    else
        v.text = v.content:CreateFontString(nil, "OVERLAY")
    end
    v.text:SetDrawLayer("OVERLAY", 7)
    v.text:SetWordWrap(false)
    v.text:SetJustifyH("LEFT")
    v.text:SetJustifyV("MIDDLE")

    btn:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        v.hoverTarget = 1; self:SetScript("OnUpdate", OnUpdate)
    end)
    btn:HookScript("OnLeave", function(self)
        v.hoverTarget = 0; self:SetScript("OnUpdate", OnUpdate)
    end)
    btn:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        v.hoverP, v.hoverTarget = 0, 0
        Apply(self)
    end)
    btn:HookScript("OnShow", function(self) Apply(self) end)
    btn:HookScript("OnSizeChanged", function(self) Apply(self) end)
    return v
end

function BB.SetLabel(btn, text, fontSize)
    local v = btn and btn._ktBlob
    if not v then return end
    if fontSize then v.fontSize = fontSize end
    v.text:SetFont(FontPath(), v.fontSize, "OUTLINE")
    local s = tostring(text or "")
    local up = KT.NavTabs and KT.NavTabs.Upper
    v.text:SetText(up and up(s) or s:upper())
end

function BB.Refresh(btn)
    if btn and btn._ktBlob then Apply(btn) end
end

-- opts: label, fontSize, text (FontString to reuse), color ({r,g,b} | function)
function BB.Style(btn, opts)
    if not btn then return end
    opts = opts or {}
    local v = btn._ktBlob or Build(btn, opts.text)
    if opts.color ~= nil then v.color = opts.color end
    if opts.fontSize then v.fontSize = opts.fontSize end
    v.text:SetFont(FontPath(), v.fontSize, "OUTLINE")
    if opts.label ~= nil then BB.SetLabel(btn, opts.label, opts.fontSize) end
    Apply(btn)
    return btn
end
