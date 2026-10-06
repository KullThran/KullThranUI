-- NavTabs.lua
-- Botones de pestañas compartidos para todas las barras de navegación del menú.
--
-- Port del botón CSS uiverse "mrhyddenn/stale-cheetah-42":
--   * borde de 1px con esquinas redondeadas, fondo casi transparente;
--   * texto en mayúsculas;
--   * hover: relleno con el color de accent + glow difuso (transición 0.2s);
--   * hover: destello blanco inclinado (skewX -20deg) que barre el botón de
--     izquierda a derecha en 0.5s (alpha 0 -> 1 -> 0), recortado al botón;
--   * pulsado: el glow desaparece.
--
-- Todo tamaño y offset se ajusta a píxeles físicos enteros. Las líneas de 1px
-- dibujadas en unidades de UI caen entre píxeles cuando la escala efectiva no
-- es entera (0.71, 0.53, ...) y WoW las redondea a 0px: ese era el origen de
-- los bordes "cortados" en las barras de pestañas.
local _, ns = ...
local KT = ns.KT

local NavTabs = KT.NavTabs or {}
KT.NavTabs = NavTabs

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local GLOW_TEX = MEDIA .. "NavButtonGlow.tga"
local SHINE_TEX = MEDIA .. "NavButtonShine.tga"
local RING_TEX = MEDIA .. "PortalRing.tga"      -- quarter ring, centre bottom-right

local FADE_TIME = 0.2      -- transition: all 0.2s
local SHORT_FADE = 0.4     -- variante "short": transition 0.4s
local SHORT_GLOW_SIZE = 16 -- variante "short": box-shadow 0 0 20px
local SHORT_GRAY = 0.255   -- variante "short": borde en reposo #414141
local SHINE_TIME = 0.5     -- animation: sh02 0.5s linear
local GLOW_SIZE = 10       -- extent of the halo, in UI units
local GLOW_ALPHA = 0.85
local HOVER_DARKEN = 0.46   -- hover fill = accent * 0.46
local MIN_FONT = 7
local DANGER_R, DANGER_G, DANGER_B = 0.90, 0.18, 0.22

-- ---------------------------------------------------------------------------
-- Pixel helpers
-- ---------------------------------------------------------------------------
local function PixelToUIFactor()
    if PixelUtil and PixelUtil.GetPixelToUIUnitFactor then
        local ok, factor = pcall(PixelUtil.GetPixelToUIUnitFactor)
        if ok and type(factor) == "number" and factor > 0 then
            return factor
        end
    end
    local _, physH = GetPhysicalScreenSize()
    if physH and physH > 0 then
        return 768 / physH
    end
    return 1
end

-- Size of one physical pixel expressed in the coordinate space of `region`.
function NavTabs.PixelSize(region)
    local scale = (region and region.GetEffectiveScale and region:GetEffectiveScale()) or 1
    if not scale or scale <= 0 then scale = 1 end
    return PixelToUIFactor() / scale
end

-- Rounds `value` to the nearest whole number of physical pixels.
function NavTabs.Snap(value, region, minPixels)
    local px = NavTabs.PixelSize(region)
    local pixels = floor(((value or 0) / px) + 0.5)
    if minPixels and pixels < minPixels then pixels = minPixels end
    return pixels * px, pixels
end

-- ---------------------------------------------------------------------------
-- Colors / text
-- ---------------------------------------------------------------------------
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

-- string.upper only knows ASCII; map the accented letters our locales use.
local UPPER_UTF8 = {
    ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú",
    ["à"] = "À", ["è"] = "È", ["ì"] = "Ì", ["ò"] = "Ò", ["ù"] = "Ù",
    ["â"] = "Â", ["ê"] = "Ê", ["î"] = "Î", ["ô"] = "Ô", ["û"] = "Û",
    ["ä"] = "Ä", ["ë"] = "Ë", ["ï"] = "Ï", ["ö"] = "Ö", ["ü"] = "Ü",
    ["ñ"] = "Ñ", ["ç"] = "Ç",
}

local function Upper(text)
    text = tostring(text or "")
    text = text:gsub("[\195][\128-\191]", UPPER_UTF8)
    return (text:upper())
end
NavTabs.Upper = Upper

-- ---------------------------------------------------------------------------
-- Visual construction
-- ---------------------------------------------------------------------------
local function NewTex(owner, layer, sublevel, path)
    local t = owner:CreateTexture(nil, layer, nil, sublevel)
    t:SetTexture(path or WHITE)
    -- Sizes and offsets are already whole physical pixels. Letting the client
    -- snap every edge again rounds the far side of a 1px border to 0px when the
    -- scale is fractional, which is what cut the right/bottom borders.
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    return t
end

local function BuildVisual(btn)
    local v = {}
    btn._ktNav = v

    -- Halo (box-shadow). 9-slice outside the button; the center is not drawn,
    -- like a CSS outer shadow.
    v.glow = {}
    for i = 1, 8 do
        local t = NewTex(btn, "BACKGROUND", -8, GLOW_TEX)
        t:SetBlendMode("ADD")
        v.glow[i] = t
    end
    local gTL, gTR, gBL, gBR, gT, gB, gL, gR = unpack(v.glow)
    gTL:SetTexCoord(0, 0.5, 0, 0.5)
    gTR:SetTexCoord(0.5, 1, 0, 0.5)
    gBL:SetTexCoord(0, 0.5, 0.5, 1)
    gBR:SetTexCoord(0.5, 1, 0.5, 1)
    gT:SetTexCoord(0.49, 0.51, 0, 0.5)
    gB:SetTexCoord(0.49, 0.51, 0.5, 1)
    gL:SetTexCoord(0, 0.5, 0.49, 0.51)
    gR:SetTexCoord(0.5, 1, 0.49, 0.51)

    -- Base fill (state background) and hover fill (accent).
    v.bg = NewTex(btn, "BACKGROUND", -6)
    v.hover = NewTex(btn, "BACKGROUND", -5)

    -- 1px border: 4 edges + 4 corner dots -> 2px rounded corners.
    v.edges = {}
    for i = 1, 8 do
        v.edges[i] = NewTex(btn, "BORDER", 1)
    end

    -- Shine: clip frame (overflow: hidden) -> moving holder -> skewed band.
    v.clip = CreateFrame("Frame", nil, btn)
    v.clip:SetClipsChildren(true)
    v.shine = CreateFrame("Frame", nil, v.clip)
    v.shine:Hide()
    v.shineTex = NewTex(v.shine, "ARTWORK", 0, SHINE_TEX)
    v.shineTex:SetAllPoints(v.shine)
    v.shineTex:SetBlendMode("ADD")

    local ag = v.shine:CreateAnimationGroup()
    local move = ag:CreateAnimation("Translation")
    move:SetDuration(SHINE_TIME)
    move:SetOrder(1)
    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(SHINE_TIME / 2)
    fadeIn:SetOrder(1)
    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(SHINE_TIME / 2)
    fadeOut:SetStartDelay(SHINE_TIME / 2)
    fadeOut:SetOrder(1)
    ag:SetScript("OnFinished", function() v.shine:Hide() end)
    ag:SetScript("OnStop", function() v.shine:Hide() end)
    v.shineAnim, v.shineMove = ag, move

    -- Optional icon (see NavTabs.SetContent).
    v.icon = btn:CreateTexture(nil, "OVERLAY")
    v.icon:Hide()

    -- Label.
    v.text = btn:CreateFontString(nil, "OVERLAY")
    v.text:SetWordWrap(false)
    v.text:SetJustifyH("CENTER")
    v.text:SetJustifyV("MIDDLE")
    v.text:SetShadowOffset(0, 0)

    v.hoverP, v.hoverTarget = 0, 0     -- 0..1 progress of the hover transition
    v.pressP, v.pressTarget = 0, 0     -- 0..1 progress of the pressed transition
    v.fontSize = 11
    v.baseText = 0.84
    v.selected, v.danger = false, false
    return v
end

-- Places every texture on whole pixels for the current size/scale.
local function LayoutVisual(btn)
    local v = btn._ktNav
    if not v then return end
    local px = NavTabs.PixelSize(btn)
    local w, h = btn:GetWidth(), btn:GetHeight()
    if not w or w <= 0 or not h or h <= 0 then return end
    local short = v.variant == "short"
    local bw = short and 2 * px or px          -- grosor del borde
    local r = short and 2 * px or 2 * px       -- radio de las esquinas
    if short then
        -- border 2px / radius 10px: radio = 5x el grosor, esquinas de anillo reales.
        r = max(4 * px, min(5 * bw, floor(min(w, h) / 2 / px) * px))
    end
    local g = NavTabs.Snap(short and SHORT_GLOW_SIZE or GLOW_SIZE, btn, 1)

    local gTL, gTR, gBL, gBR, gT, gB, gL, gR = unpack(v.glow)
    for _, t in ipairs(v.glow) do t:ClearAllPoints() end
    gTL:SetSize(g, g); gTL:SetPoint("BOTTOMRIGHT", btn, "TOPLEFT", 0, 0)
    gTR:SetSize(g, g); gTR:SetPoint("BOTTOMLEFT", btn, "TOPRIGHT", 0, 0)
    gBL:SetSize(g, g); gBL:SetPoint("TOPRIGHT", btn, "BOTTOMLEFT", 0, 0)
    gBR:SetSize(g, g); gBR:SetPoint("TOPLEFT", btn, "BOTTOMRIGHT", 0, 0)
    gT:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 0); gT:SetPoint("BOTTOMRIGHT", btn, "TOPRIGHT", 0, 0); gT:SetHeight(g)
    gB:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, 0); gB:SetPoint("TOPRIGHT", btn, "BOTTOMRIGHT", 0, 0); gB:SetHeight(g)
    gL:SetPoint("TOPRIGHT", btn, "TOPLEFT", 0, 0); gL:SetPoint("BOTTOMRIGHT", btn, "BOTTOMLEFT", 0, 0); gL:SetWidth(g)
    gR:SetPoint("TOPLEFT", btn, "TOPRIGHT", 0, 0); gR:SetPoint("BOTTOMLEFT", btn, "BOTTOMRIGHT", 0, 0); gR:SetWidth(g)

    for _, t in ipairs({ v.bg, v.hover }) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", btn, "TOPLEFT", bw, -bw)
        t:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -bw, bw)
    end

    local eT, eB, eL, eR, cTL, cTR, cBL, cBR = unpack(v.edges)
    for _, t in ipairs(v.edges) do t:ClearAllPoints() end
    eT:SetPoint("TOPLEFT", btn, "TOPLEFT", r, 0); eT:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -r, 0); eT:SetHeight(bw)
    eB:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", r, 0); eB:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -r, 0); eB:SetHeight(bw)
    eL:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, -r); eL:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, r); eL:SetWidth(bw)
    eR:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, -r); eR:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, r); eR:SetWidth(bw)
    if short then
        for _, c in ipairs({ cTL, cTR, cBL, cBR }) do c:SetTexture(RING_TEX) end
        cTL:SetTexCoord(0, 1, 0, 1)
        cTR:SetTexCoord(1, 0, 1, 1, 0, 0, 0, 1)
        cBL:SetTexCoord(0, 1, 0, 0, 1, 1, 1, 0)
        cBR:SetTexCoord(1, 1, 1, 0, 0, 1, 0, 0)
        cTL:SetSize(r, r); cTL:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
        cTR:SetSize(r, r); cTR:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
        cBL:SetSize(r, r); cBL:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
        cBR:SetSize(r, r); cBR:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    else
        local cd = r - bw
        cTL:SetSize(bw, bw); cTL:SetPoint("TOPLEFT", btn, "TOPLEFT", cd, -cd)
        cTR:SetSize(bw, bw); cTR:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -cd, -cd)
        cBL:SetSize(bw, bw); cBL:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", cd, cd)
        cBR:SetSize(bw, bw); cBR:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -cd, cd)
    end

    v.clip:ClearAllPoints()
    v.clip:SetPoint("TOPLEFT", btn, "TOPLEFT", px, -px)
    v.clip:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -px, px)
    v.clip:SetFrameLevel(btn:GetFrameLevel() + 1)
    v.clip:SetShown(not short)

    -- CSS: height 86%, top 7%, band starts at left 0% and ends at left 100%.
    local shineH = max(px, floor((h * 0.86) / px + 0.5) * px)
    local shineW = shineH
    v.shine:ClearAllPoints()
    v.shine:SetSize(shineW, shineH)
    v.shine:SetPoint("LEFT", v.clip, "LEFT", -shineW / 2, 0)
    v.shineMove:SetOffset(w, 0)

    local textL, textR, textY = 3 * px, 3 * px, 0
    local c = v.content
    if c and c.icon then
        local iw = NavTabs.Snap(c.iconSize or 14, btn, 1)
        local ix
        if c.iconCenter then
            ix = NavTabs.Snap((w - iw) / 2, btn, 0)
        else
            ix = NavTabs.Snap(c.iconInset or 8, btn, 1)
        end
        local iy = NavTabs.Snap((h - iw) / 2, btn, 0)
        v.icon:ClearAllPoints()
        v.icon:SetSize(iw, iw)
        v.icon:SetPoint("TOPLEFT", btn, "TOPLEFT", ix, -iy)
        v.icon:Show()
    else
        v.icon:Hide()
    end
    if c then
        if c.textLeft then textL = NavTabs.Snap(c.textLeft, btn, 1) end
        if c.textRight then textR = NavTabs.Snap(c.textRight, btn, 1) end
        textY = c.textY or 0
        v.text:SetJustifyH(c.align or "CENTER")
    end
    v.text:ClearAllPoints()
    v.text:SetPoint("LEFT", btn, "LEFT", textL, textY)
    v.text:SetPoint("RIGHT", btn, "RIGHT", -textR, textY)
end

local function Ease(p)
    -- ease-out entering / ease-in leaving share this curve on the progress value.
    return 1 - (1 - p) * (1 - p)
end

local function ApplyAnimated(btn)
    local v = btn._ktNav
    local hv = Ease(v.hoverP)
    local pv = Ease(v.pressP)
    if v.variant == "short" then
        -- Borde gris -> accent y resplandor al hover; pulsado: glow a la mitad.
        local ar, ag, ab = v.accR or 1, v.accG or 1, v.accB or 1
        local cr = SHORT_GRAY + (ar - SHORT_GRAY) * hv
        local cg = SHORT_GRAY + (ag - SHORT_GRAY) * hv
        local cb = SHORT_GRAY + (ab - SHORT_GRAY) * hv
        for i, t in ipairs(v.edges) do
            if i > 4 then t:SetVertexColor(cr, cg, cb, 1) else t:SetColorTexture(cr, cg, cb, 1) end
        end
        v.hover:SetAlpha(0)
        local ga = hv * (1 - pv * 0.5) * GLOW_ALPHA
        for _, t in ipairs(v.glow) do t:SetAlpha(ga) end
        v.text:SetTextColor(1, 1, 1, 1)
        return
    end
    local fillMax = v.selected and 0.35 or 0.92
    v.hover:SetAlpha(hv * fillMax)
    local glowA = hv * (1 - pv) * GLOW_ALPHA
    for _, t in ipairs(v.glow) do t:SetAlpha(glowA) end
    local tc = v.baseText + (1 - v.baseText) * hv
    v.text:SetTextColor(tc, tc, tc, 1)
    if v.content and v.content.icon then
        -- Icon: accent at rest, white once the accent fill takes over.
        local k = v.selected and 1 or hv
        local ar, ag, ab = v.accR or 1, v.accG or 1, v.accB or 1
        v.icon:SetVertexColor(ar + (1 - ar) * k, ag + (1 - ag) * k, ab + (1 - ab) * k, 1)
    end
end

local function OnUpdate(btn, elapsed)
    local v = btn._ktNav
    local step = elapsed / (v.variant == "short" and SHORT_FADE or FADE_TIME)
    if v.hoverP < v.hoverTarget then
        v.hoverP = min(v.hoverTarget, v.hoverP + step)
    elseif v.hoverP > v.hoverTarget then
        v.hoverP = max(v.hoverTarget, v.hoverP - step)
    end
    if v.pressP < v.pressTarget then
        v.pressP = min(v.pressTarget, v.pressP + step)
    elseif v.pressP > v.pressTarget then
        v.pressP = max(v.pressTarget, v.pressP - step)
    end
    ApplyAnimated(btn)
    if v.hoverP == v.hoverTarget and v.pressP == v.pressTarget then
        btn:SetScript("OnUpdate", nil)   -- no per-frame cost once settled
    end
end

local function StartTween(btn)
    btn:SetScript("OnUpdate", OnUpdate)
end

local function OnEnter(btn)
    local v = btn._ktNav
    if not v or (btn.IsEnabled and not btn:IsEnabled()) then return end
    v.hoverTarget = 1
    StartTween(btn)
    LayoutVisual(btn)
    if v.variant == "short" then
        NavTabs.SetState(btn, false, v.danger)   -- recoge el accent actual
        return
    end
    v.shineAnim:Stop()
    v.shine:Show()
    v.shineAnim:Play()
end

local function OnLeave(btn)
    local v = btn._ktNav
    if not v then return end
    v.hoverTarget, v.pressTarget = 0, 0
    StartTween(btn)
end

local function OnMouseDown(btn)
    local v = btn._ktNav
    if not v then return end
    v.pressTarget = 1
    StartTween(btn)
end

local function OnMouseUp(btn)
    local v = btn._ktNav
    if not v then return end
    v.pressTarget = 0
    StartTween(btn)
end

local function OnHide(btn)
    local v = btn._ktNav
    if not v then return end
    btn:SetScript("OnUpdate", nil)
    v.hoverP, v.hoverTarget, v.pressP, v.pressTarget = 0, 0, 0, 0
    v.shineAnim:Stop()
    ApplyAnimated(btn)
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

-- Turns any Button into a nav tab. opts: label, fontSize, uppercase (default
-- true), selected, danger.
function NavTabs.StyleButton(btn, opts)
    if not btn then return end
    opts = opts or {}
    local v = btn._ktNav
    if not v then
        v = BuildVisual(btn)
        if opts.text then
            -- Reuses a label owned by the caller (it keeps calling text:SetText).
            v.text:Hide()
            v.text = opts.text
            v.text:SetWordWrap(false)
            v.text:SetJustifyH("CENTER")
            v.text:SetFont(FontPath(), opts.fontSize or 11, "OUTLINE")
        end
        if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
        if btn.SetBackdrop then btn:SetBackdrop(nil) end
        btn:HookScript("OnEnter", OnEnter)
        btn:HookScript("OnLeave", OnLeave)
        btn:HookScript("OnMouseDown", OnMouseDown)
        btn:HookScript("OnMouseUp", OnMouseUp)
        btn:HookScript("OnHide", OnHide)
        btn:HookScript("OnSizeChanged", LayoutVisual)
    end
    if opts.variant then v.variant = opts.variant end
    v.uppercase = opts.uppercase ~= false
    if opts.fontSize then v.fontSize = opts.fontSize end
    if opts.label ~= nil then NavTabs.SetLabel(btn, opts.label) end
    NavTabs.SetState(btn, opts.selected, opts.danger)
    LayoutVisual(btn)
    return btn
end

function NavTabs.SetLabel(btn, text, fontSize)
    local v = btn and btn._ktNav
    if not v then return end
    if fontSize then v.fontSize = fontSize end
    v.label = text
    v.text:SetFont(FontPath(), v.fontSize, "OUTLINE")
    v.text:SetText(v.uppercase and Upper(text) or tostring(text or ""))
end

function NavTabs.SetFontSize(btn, size)
    local v = btn and btn._ktNav
    if not v then return end
    v.fontSize = size
    v.text:SetFont(FontPath(), size, "OUTLINE")
end

function NavTabs.GetTextWidth(btn)
    local v = btn and btn._ktNav
    if not v then return 0 end
    if v.text.GetUnboundedStringWidth then
        return v.text:GetUnboundedStringWidth() or 0
    end
    return v.text:GetStringWidth() or 0
end

-- Recolors for the state and the current accent (call after a theme change).
function NavTabs.SetState(btn, selected, danger)
    local v = btn and btn._ktNav
    if not v then return end
    v.selected, v.danger = selected and true or false, danger and true or false
    local r, g, b = AccentRGB()
    if v.danger then r, g, b = DANGER_R, DANGER_G, DANGER_B end
    v.accR, v.accG, v.accB = r, g, b

    local borderR, borderG, borderB, borderA
    if v.selected then
        -- Active tab: dark tinted fill, bright (accent mixed with white) border.
        v.bg:SetColorTexture(0.02 + r * 0.22, 0.02 + g * 0.22, 0.03 + b * 0.22, 0.92)
        borderR, borderG, borderB, borderA = r + (1 - r) * 0.45, g + (1 - g) * 0.45, b + (1 - b) * 0.45, 1
        v.baseText = 1
    elseif v.variant == "short" then
        v.bg:SetColorTexture(0, 0, 0, 0)   -- background: transparent
        borderR, borderG, borderB, borderA = SHORT_GRAY, SHORT_GRAY, SHORT_GRAY, 1
        v.baseText = 1
    else
        v.bg:SetColorTexture(0.02, 0.02, 0.03, 0.45)
        borderR, borderG, borderB, borderA = r, g, b, v.danger and 0.85 or 0.6
        v.baseText = 0.84
    end
    for i, t in ipairs(v.edges) do
        if v.variant == "short" and i > 4 then
            t:SetVertexColor(borderR, borderG, borderB, borderA)
        else
            t:SetColorTexture(borderR, borderG, borderB, borderA)
        end
    end
    -- Relleno del hover algo mas oscuro que el accent: el icono y el texto
    -- (claros) siguen destacando sobre el fondo.
    v.hover:SetColorTexture(r * HOVER_DARKEN, g * HOVER_DARKEN, b * HOVER_DARKEN, 1)
    for _, t in ipairs(v.glow) do t:SetVertexColor(r, g, b, 1) end
    v.shineTex:SetVertexColor(1, 1, 1, 0.9)
    ApplyAnimated(btn)
end

-- Extra content for a styled button. c: icon (texture path), iconSize,
-- iconInset, iconCenter (icon-only buttons), textLeft, textRight, textY,
-- align ("CENTER" | "LEFT"). Pass nil to go back to a plain label.
function NavTabs.SetContent(btn, c)
    local v = btn and btn._ktNav
    if not v then return end
    v.content = c
    if c and c.icon then v.icon:SetTexture(c.icon) end
    LayoutVisual(btn)
    ApplyAnimated(btn)
end

function NavTabs.IsSelected(btn)
    return btn and btn._ktNav and btn._ktNav.selected or false
end

-- Lays out `buttons` in rows inside `container`, every edge on whole physical
-- pixels so widths and gaps always add up exactly.
-- opts: width, x, y, height, gap, rowGap, perRow, padding, fontSize, minFontSize
-- Returns the total height used (UI units).
function NavTabs.Layout(container, buttons, opts)
    opts = opts or {}
    local n = #buttons
    if n == 0 then return 0 end
    local px = NavTabs.PixelSize(container)
    local width = opts.width or container:GetWidth() or 0
    if width <= 0 then width = 600 end
    local Wpx = floor(width / px + 0.0001)
    local gapPx = max(1, floor((opts.gap or 4) / px + 0.5))
    local rowGapPx = max(1, floor((opts.rowGap or opts.gap or 4) / px + 0.5))
    local hPx = max(4, floor((opts.height or 28) / px + 0.5))
    local x0Px = floor((opts.x or 0) / px + 0.5)
    local y0Px = floor((opts.y or 0) / px + 0.5)
    local perRow = max(1, min(opts.perRow or n, n))
    local padPx = max(2, floor((opts.padding or 8) / px + 0.5))
    local fontSize = opts.fontSize or (buttons[1]._ktNav and buttons[1]._ktNav.fontSize) or 11
    local minFont = opts.minFontSize or MIN_FONT

    local rows = {}
    for i = 1, n, perRow do
        local row = {}
        for j = i, min(n, i + perRow - 1) do row[#row + 1] = buttons[j] end
        rows[#rows + 1] = row
    end

    -- Shared font size for the whole bar: shrink until every row fits.
    local function Needs(row)
        local need, total = {}, 0
        for i, btn in ipairs(row) do
            need[i] = ceil(NavTabs.GetTextWidth(btn) / px) + padPx * 2
            total = total + need[i]
        end
        return need, total
    end
    local size = fontSize
    while true do
        for _, btn in ipairs(buttons) do NavTabs.SetFontSize(btn, size) end
        local fits = true
        for _, row in ipairs(rows) do
            local _, total = Needs(row)
            if total > Wpx - gapPx * (#row - 1) then fits = false; break end
        end
        if fits or size <= minFont then break end
        size = max(minFont, size - 0.5)
    end

    for rowIndex, row in ipairs(rows) do
        local count = #row
        local avail = Wpx - gapPx * (count - 1)
        local need, total = Needs(row)
        local widths = {}
        local maxNeed = 0
        for i = 1, count do maxNeed = max(maxNeed, need[i]) end
        -- The tabs of the first row define the column width so later rows line up.
        local cols = (#rows > 1) and perRow or count
        local colAvail = Wpx - gapPx * (cols - 1)
        local eq = floor(colAvail / cols)
        if eq >= maxNeed then
            local rem = (#rows > 1) and 0 or (colAvail - eq * cols)
            for i = 1, count do widths[i] = eq + ((i <= rem) and 1 or 0) end
        else
            -- Not enough room for equal widths: size to the text, share the rest.
            local extra = avail - total
            local share = extra > 0 and floor(extra / count) or 0
            local rem = extra > 0 and (extra - share * count) or 0
            for i = 1, count do
                widths[i] = max(padPx * 2, need[i] + share + ((i <= rem) and 1 or 0))
            end
            if extra < 0 then
                -- Still too wide at the minimum font: scale down, text clips with "...".
                local scaleDown = avail / total
                local used = 0
                for i = 1, count do
                    widths[i] = max(padPx * 2, floor(need[i] * scaleDown))
                    used = used + widths[i]
                end
                widths[count] = widths[count] + max(0, avail - used)
            end
        end

        local xPx = x0Px
        local yPx = y0Px + (rowIndex - 1) * (hPx + rowGapPx)
        for i, btn in ipairs(row) do
            btn:ClearAllPoints()
            btn:SetSize(widths[i] * px, hPx * px)
            btn:SetPoint("TOPLEFT", container, "TOPLEFT", xPx * px, -yPx * px)
            xPx = xPx + widths[i] + gapPx
            LayoutVisual(btn)
        end
    end

    return (#rows * hPx + (#rows - 1) * rowGapPx) * px
end

-- Creates (or reuses) the tab buttons inside `container` and lays them out.
-- tabs: { { id =, label =, danger = }, ... }
-- opts: selectedId, onSelect(id, tab), localize(fn), fontSize + NavTabs.Layout opts.
-- Returns the height used and the button list.
function NavTabs.Populate(container, tabs, opts)
    opts = opts or {}
    local pool = container._ktNavButtons or {}
    container._ktNavButtons = pool
    local localize = opts.localize or function(text) return text end
    local list = {}
    for index, tab in ipairs(tabs) do
        local btn = pool[index]
        -- Hosts that clear themselves orphan their children (SetParent(nil)).
        if btn and btn:GetParent() ~= container then btn = nil end
        if not btn then
            btn = CreateFrame("Button", nil, container)
            btn:RegisterForClicks("LeftButtonUp")
            pool[index] = btn
        end
        btn._ktNavTab = tab
        NavTabs.StyleButton(btn, {
            label = localize(tab.label or tab.id or ""),
            fontSize = opts.fontSize or 11,
            selected = opts.selectedId ~= nil and tab.id == opts.selectedId,
            danger = tab.danger,
        })
        btn:SetScript("OnClick", function(self)
            if opts.onSelect then opts.onSelect(self._ktNavTab.id, self._ktNavTab) end
        end)
        btn:Show()
        list[index] = btn
    end
    for index = #tabs + 1, #pool do
        pool[index]:Hide()
    end
    return NavTabs.Layout(container, list, opts), list
end

-- One-call tab bar used by the options pages.
-- Returns the bar frame and the vertical space it consumes.
function NavTabs.CreateBar(parent, yOffset, tabs, selectedId, onSelect, opts)
    opts = opts or {}
    local inset = opts.inset or 10
    local height = opts.height or 32
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetClipsChildren(false)
    bar:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, yOffset or 0)
    local width = opts.width or ((parent:GetWidth() or 0) - inset * 2)
    if width <= 0 then width = 600 end
    bar:SetSize(width, height)

    local layout = {}
    for k, val in pairs(opts) do layout[k] = val end
    layout.width = width
    layout.height = height
    -- Leave room for the hover glow above and below.
    layout.y = opts.y or 2
    layout.selectedId = selectedId
    layout.onSelect = onSelect
    local used = NavTabs.Populate(bar, tabs, layout)
    local total = used + layout.y * 2
    bar:SetHeight(total)
    return bar, total + (opts.spacing or 8)
end
