-- ShineButton.lua
-- Botones Reload UI / Reset Profile: port del boton CSS de brillo con barrido
-- de uiverse.
--
--   * fondo transparente, borde de 1px del color del boton, esquinas de 7px,
--     texto blanco en mayusculas;
--   * hover (0.2s): el fondo se rellena del color del boton y aparece un
--     resplandor suave de 10px del mismo color;
--   * hover: una franja blanca difuminada cruza el boton de izquierda a derecha
--     en 0.5s (aparece, llega al maximo a la mitad y se apaga);
--   * pulsado: el resplandor desaparece.
--
-- El color NO es fijo: lo da `opts.color` ({r,g,b} o funcion), asi cada boton
-- conserva el suyo y el tema. Pixeles fisicos enteros, igual que KT.NavTabs.
local _, ns = ...
local KT = ns.KT

local SB = KT.ShineButton or {}
KT.ShineButton = SB

local floor, max, min = math.floor, math.max, math.min

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ROUND_TEX = MEDIA .. "PortalRound.tga"      -- quarter disc, centre bottom-right
local RING_TEX = MEDIA .. "PortalRing.tga"        -- quarter ring (thickness = 1/5 radius)
local RADIAL_TEX = MEDIA .. "PortalRadial.tga"
local GLOW_TEX = MEDIA .. "NavButtonGlow.tga"

local GLOW, SPREAD = 10, 0
local FADE_IN, FADE_OUT = 0.2, 0.2
local SHINE_TIME = 0.5
local HIGHLIGHT_INTENSITY = 0.2 -- 80% less hover fill, glow and shine

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

local function ColorOf(c)
    if type(c) == "function" then
        local r, g, b = c()
        if r then return r, g, b end
    elseif type(c) == "table" then
        return c[1] or c.r or 0.5, c[2] or c.g or 0.5, c[3] or c.b or 0.5
    end
    return 0.5, 0.5, 0.5
end

local function NewFill(owner, sub)
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

local function FillPlace(s, owner, W, H, r, px, cr, cg, cb, ca)
    r = max(0, min(r, floor(min(W, H) / 2 / px) * px))
    Put(s.rects[1], owner, 0, r, W, H - r)
    Put(s.rects[2], owner, r, 0, W - r, r)
    Put(s.rects[3], owner, r, H - r, W - r, H)
    local pos = { tl = { 0, 0 }, tr = { W - r, 0 }, bl = { 0, H - r }, br = { W - r, H - r } }
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

-- 1px outline: 4 edge bars + 4 quarter rings (radius = 5 x thickness).
local function NewBorder(owner)
    local s = { edges = {} }
    for i = 1, 4 do
        local t = owner:CreateTexture(nil, "BORDER")
        t:SetTexture(WHITE)
        s.edges[i] = t
    end
    for _, c in ipairs(CORNERS) do
        local t = owner:CreateTexture(nil, "BORDER")
        t:SetTexture(RING_TEX)
        t:SetTexCoord(unpack(FLIP[c]))
        s[c] = t
    end
    return s
end

local function BorderPlace(s, owner, W, H, bd, px, cr, cg, cb)
    local r = bd * 5
    r = min(r, floor(min(W, H) / 2 / px) * px)
    local e = s.edges
    Put(e[1], owner, r, 0, W - r, bd)                 -- top
    Put(e[2], owner, r, H - bd, W - r, H)             -- bottom
    Put(e[3], owner, 0, r, bd, H - r)                 -- left
    Put(e[4], owner, W - bd, r, W, H - r)             -- right
    local pos = { tl = { 0, 0 }, tr = { W - r, 0 }, bl = { 0, H - r }, br = { W - r, H - r } }
    for _, c in ipairs(CORNERS) do
        local t = s[c]
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", owner, "TOPLEFT", pos[c][1], -pos[c][2])
        t:SetSize(r, r)
        t:Show()
    end
    for _, t in ipairs(e) do t:SetVertexColor(cr, cg, cb, 1) end
    for _, c in ipairs(CORNERS) do s[c]:SetVertexColor(cr, cg, cb, 1) end
    return r
end

local function Apply(btn)
    local v = btn._ktShine
    if not v then return end
    if v.fontSet ~= v.fontSize then
        v.fontSet = v.fontSize
        v.text:SetFont(FontPath(), v.fontSize, "OUTLINE")
    end
    local w, h = btn:GetWidth(), btn:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end
    local px = Px(btn)
    local p = v.hoverP
    local r, g, b = ColorOf(v.color)
    local bd = max(px, ToPx(1, px))

    local rad = BorderPlace(v.border, v.vis, w, h, bd, px, r, g, b)
    FillPlace(v.fill, v.vis, w, h, rad, px, r, g, b, p * HIGHLIGHT_INTENSITY)

    -- Glow: soft shadow (kept subtle), off while pressed.
    local spread = max(px, ToPx(SPREAD, px))
    local g30 = max(px, ToPx(GLOW, px))
    v.spread:ClearAllPoints()
    v.spread:SetPoint("TOPLEFT", v.vis, "TOPLEFT", -spread, spread)
    v.spread:SetPoint("BOTTOMRIGHT", v.vis, "BOTTOMRIGHT", spread, -spread)
    local gp = v.glowPieces
    local gTL, gTR, gBL, gBR, gT, gB, gL, gR = unpack(gp)
    local sp = v.spread
    for _, t in ipairs(gp) do t:ClearAllPoints() end
    gTL:SetSize(g30, g30); gTL:SetPoint("BOTTOMRIGHT", sp, "TOPLEFT", 0, 0)
    gTR:SetSize(g30, g30); gTR:SetPoint("BOTTOMLEFT", sp, "TOPRIGHT", 0, 0)
    gBL:SetSize(g30, g30); gBL:SetPoint("TOPRIGHT", sp, "BOTTOMLEFT", 0, 0)
    gBR:SetSize(g30, g30); gBR:SetPoint("TOPLEFT", sp, "BOTTOMRIGHT", 0, 0)
    gT:SetPoint("BOTTOMLEFT", sp, "TOPLEFT", 0, 0); gT:SetPoint("BOTTOMRIGHT", sp, "TOPRIGHT", 0, 0); gT:SetHeight(g30)
    gB:SetPoint("TOPLEFT", sp, "BOTTOMLEFT", 0, 0); gB:SetPoint("TOPRIGHT", sp, "BOTTOMRIGHT", 0, 0); gB:SetHeight(g30)
    gL:SetPoint("TOPRIGHT", sp, "TOPLEFT", 0, 0); gL:SetPoint("BOTTOMRIGHT", sp, "BOTTOMLEFT", 0, 0); gL:SetWidth(g30)
    gR:SetPoint("TOPLEFT", sp, "TOPRIGHT", 0, 0); gR:SetPoint("BOTTOMLEFT", sp, "BOTTOMRIGHT", 0, 0); gR:SetWidth(g30)
    local ga = 0.3 * p * (1 - v.pressP) * HIGHLIGHT_INTENSITY
    for _, t in ipairs(gp) do t:SetVertexColor(r, g, b, 1); t:SetAlpha(ga) end
    v.spreadFill:ClearAllPoints()
    v.spreadFill:SetAllPoints(v.spread)
    v.spreadFill:SetVertexColor(r, g, b, 1)
    v.spreadFill:SetAlpha(0)

    -- Shine band: left 0% -> 100%, opacity 0 -> 1 -> 0.
    local t = v.shineT
    if t and t < 1 then
        local a = (t < 0.5) and (t * 2) or ((1 - t) * 2)
        local bw = max(px, ToPx(h * 1.6, px))
        local bh = max(px, ToPx(h * 0.86, px))
        local x = (w + bw) * t - bw / 2
        v.shine:ClearAllPoints()
        v.shine:SetSize(bw, bh)
        v.shine:SetPoint("CENTER", v.clip, "LEFT", x, 0)
        v.shine:SetAlpha(a * HIGHLIGHT_INTENSITY)
        v.shine:Show()
    else
        v.shine:Hide()
    end

    v.text:ClearAllPoints()
    v.text:SetPoint("CENTER", v.vis, "CENTER", 0, 0)
end

local function Approach(cur, target, step)
    if cur < target then return min(target, cur + step) end
    if cur > target then return max(target, cur - step) end
    return cur
end

local function OnUpdate(btn, elapsed)
    local v = btn._ktShine
    v.hoverP = Approach(v.hoverP, v.hoverTarget, elapsed / (v.hoverTarget == 1 and FADE_IN or FADE_OUT))
    v.pressP = Approach(v.pressP, v.pressTarget, elapsed / 0.2)
    if v.shineT then
        v.shineT = v.shineT + elapsed / SHINE_TIME
        if v.shineT >= 1 then v.shineT = nil end
    end
    Apply(btn)
    if v.hoverP == v.hoverTarget and v.pressP == v.pressTarget and not v.shineT then
        btn:SetScript("OnUpdate", nil)
    end
end

local function Build(btn, extText)
    local v = { hoverP = 0, pressP = 0, hoverTarget = 0, pressTarget = 0, fontSize = 12 }
    btn._ktShine = v
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end

    v.vis = CreateFrame("Frame", nil, btn)
    v.vis:SetAllPoints(btn)

    v.spread = CreateFrame("Frame", nil, v.vis)
    v.glowPieces = {}
    for i = 1, 8 do
        local t = v.vis:CreateTexture(nil, "BACKGROUND", nil, -8)
        t:SetTexture(GLOW_TEX)
        t:SetBlendMode("ADD")
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
    -- The 5px spread is a solid halo under the soft shadow.
    v.spreadFill = v.vis:CreateTexture(nil, "BACKGROUND", nil, -7)
    v.spreadFill:SetTexture(WHITE)
    v.spreadFill:SetBlendMode("ADD")

    v.fill = NewFill(v.vis, -2)
    v.border = NewBorder(v.vis)

    v.clip = CreateFrame("Frame", nil, v.vis)
    v.clip:SetAllPoints(v.vis)
    if v.clip.SetClipsChildren then v.clip:SetClipsChildren(true) end
    v.shine = v.clip:CreateTexture(nil, "ARTWORK")
    v.shine:SetTexture(RADIAL_TEX)
    v.shine:SetVertexColor(1, 1, 1, 1)
    v.shine:SetBlendMode("ADD")
    v.shine:Hide()

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
    v.text:SetTextColor(1, 1, 1, 1)
    v.text:SetWordWrap(false)
    v.text:SetJustifyH("CENTER")
    v.text:SetJustifyV("MIDDLE")

    btn:HookScript("OnEnter", function(self)
        if self.IsEnabled and not self:IsEnabled() then return end
        v.hoverTarget = 1
        v.shineT = 0
        self:SetScript("OnUpdate", OnUpdate)
    end)
    btn:HookScript("OnLeave", function(self)
        v.hoverTarget, v.pressTarget = 0, 0
        self:SetScript("OnUpdate", OnUpdate)
    end)
    btn:HookScript("OnMouseDown", function(self) v.pressTarget = 1; self:SetScript("OnUpdate", OnUpdate) end)
    btn:HookScript("OnMouseUp", function(self) v.pressTarget = 0; self:SetScript("OnUpdate", OnUpdate) end)
    btn:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        v.hoverP, v.pressP, v.hoverTarget, v.pressTarget, v.shineT = 0, 0, 0, 0, nil
        Apply(self)
    end)
    btn:HookScript("OnShow", function(self) Apply(self) end)
    btn:HookScript("OnSizeChanged", function(self) Apply(self) end)
    return v
end

function SB.SetLabel(btn, text, fontSize)
    local v = btn and btn._ktShine
    if not v then return end
    if fontSize then v.fontSize = fontSize end
    if v.fontSet ~= v.fontSize then
        v.fontSet = v.fontSize
        v.text:SetFont(FontPath(), v.fontSize, "OUTLINE")
    end
    local s = tostring(text or "")
    local up = KT.NavTabs and KT.NavTabs.Upper
    v.text:SetText(up and up(s) or s:upper())
end

function SB.Refresh(btn)
    if btn and btn._ktShine then Apply(btn) end
end

-- opts: label, fontSize, text (FontString to reuse), color ({r,g,b} | function)
function SB.Style(btn, opts)
    if not btn then return end
    opts = opts or {}
    local v = btn._ktShine or Build(btn, opts.text)
    if opts.color ~= nil then v.color = opts.color end
    if opts.fontSize then v.fontSize = opts.fontSize end
    if v.fontSet ~= v.fontSize then
        v.fontSet = v.fontSize
        v.text:SetFont(FontPath(), v.fontSize, "OUTLINE")
    end
    if opts.label ~= nil then SB.SetLabel(btn, opts.label, opts.fontSize) end
    Apply(btn)
    return btn
end
