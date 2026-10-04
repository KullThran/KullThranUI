-- Nameplates_ThemeSkin.lua
-- Skin visual por tema SOLO para "classic" y "retail". kui/forever no se tocan.
-- Todo son texturas de color solido + gradientes (sin depender de ficheros del cliente).
local addonName, ns = ...
local KT = _G.KullThranUI

local WHITE = "Interface\\Buttons\\WHITE8x8"

-- Estilo de nameplate: preset elegido en Nameplates > General (kui/classic/retail/forever)
-- o, si no hay ninguno, el tema visual activo.
local VALID_STYLE = { kui = true, classic = true, retail = true, forever = true }
function ns.NameplateStyle()
    local st = KullThranUINameplatesDB and KullThranUINameplatesDB.nameplateStyle
    if st and VALID_STYLE[st] then return st end
    local VT = KT and KT.VisualThemes
    return VT and VT.GetRenderedTheme and VT:GetRenderedTheme() or nil
end
local RenderedTheme = ns.NameplateStyle

local function Solid(parent, layer, sub, r, g, b, a)
    local t = parent:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture(WHITE)
    t:SetVertexColor(r, g, b, a or 1)
    return t
end

local function Gradient(tex, orient, r1, g1, b1, a1, r2, g2, b2, a2)
    if tex.SetGradient and CreateColor then
        tex:SetGradient(orient, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    end
end

-- Marco fino de 1px (4 lados) alrededor de `bar`.
local function BuildOutline(f, bar, r, g, b, a, inset)
    inset = inset or 0
    local t = Solid(f, "OVERLAY", 6, r, g, b, a)
    t:SetPoint("TOPLEFT", bar, "TOPLEFT", -inset, inset); t:SetPoint("TOPRIGHT", bar, "TOPRIGHT", inset, inset); t:SetHeight(1)
    local bt = Solid(f, "OVERLAY", 6, r, g, b, a)
    bt:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -inset, -inset); bt:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", inset, -inset); bt:SetHeight(1)
    local l = Solid(f, "OVERLAY", 6, r, g, b, a)
    l:SetPoint("TOPLEFT", bar, "TOPLEFT", -inset, inset); l:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -inset, -inset); l:SetWidth(1)
    local rr = Solid(f, "OVERLAY", 6, r, g, b, a)
    rr:SetPoint("TOPRIGHT", bar, "TOPRIGHT", inset, inset); rr:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", inset, -inset); rr:SetWidth(1)
    return { t, bt, l, rr }
end

local function Build(plate, bar, key)
    local f = CreateFrame("Frame", nil, bar)
    f:SetAllPoints(bar)
    f:SetFrameLevel(bar:GetFrameLevel() + 6)
    f.key = key
    f.classic, f.retail = {}, {}

    -- ===== CLASSIC: marco dorado fino (1px) + filete oscuro, brillo glossy sobre el color real =====
    local c = f.classic
    -- Classic real: marco fino dorado/bronce con esquinas REDONDEADAS (escalera de pixeles, radio ~4)
    local function Px(color, corner, x, y, a)
        local t = Solid(f, "OVERLAY", 6, color[1], color[2], color[3], a or 1)
        t:SetSize(1, 1)
        local sx = corner:find("LEFT") and 1 or -1
        local sy = corner:find("TOP") and -1 or 1
        t:SetPoint(corner, bar, corner, sx * x, sy * y)
        c[#c + 1] = t
    end
    local function Line(color, p1, x1, y1, p2, x2, y2, horizontal)
        local t = Solid(f, "OVERLAY", 6, color[1], color[2], color[3], 1)
        t:SetPoint(p1, bar, p1, x1, y1)
        t:SetPoint(p2, bar, p2, x2, y2)
        if horizontal then t:SetHeight(1) else t:SetWidth(1) end
        c[#c + 1] = t
    end
    local BLACK, GOLD = { 0.02, 0.02, 0.02 }, { 0.80, 0.66, 0.38 }
    -- lineas (acortadas para dejar sitio a la curva)
    Line(BLACK, "TOPLEFT", 4, 2, "TOPRIGHT", -4, 2, true)
    Line(BLACK, "BOTTOMLEFT", 4, -2, "BOTTOMRIGHT", -4, -2, true)
    Line(BLACK, "TOPLEFT", -2, -4, "BOTTOMLEFT", -2, 4, false)
    Line(BLACK, "TOPRIGHT", 2, -4, "BOTTOMRIGHT", 2, 4, false)
    Line(GOLD, "TOPLEFT", 3, 1, "TOPRIGHT", -3, 1, true)
    Line(GOLD, "BOTTOMLEFT", 3, -1, "BOTTOMRIGHT", -3, -1, true)
    Line(GOLD, "TOPLEFT", -1, -3, "BOTTOMLEFT", -1, 3, false)
    Line(GOLD, "TOPRIGHT", 1, -3, "BOTTOMRIGHT", 1, 3, false)
    for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        for _, q in ipairs({ { 2, 0 }, { 1, 1 }, { 0, 2 } }) do Px(GOLD, corner, q[1], q[2]) end
        for _, q in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 2, -1 }, { 3, -2 }, { -1, 2 }, { -2, 3 } }) do
            Px(BLACK, corner, q[1], q[2])
        end
    end
    local cg = Solid(f, "OVERLAY", 3, 1, 1, 1, 1)
    cg:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    cg:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    cg:SetHeight(math.max(2, math.floor((bar:GetHeight() or 10) * 0.5)))
    Gradient(cg, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0)       -- Classic original: sin brillo extra
    c.gloss = cg
    local cs = Solid(f, "OVERLAY", 3, 0, 0, 0, 1)
    cs:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    cs:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    cs:SetHeight(math.max(2, math.floor((bar:GetHeight() or 10) * 0.4)))
    Gradient(cs, "VERTICAL", 0, 0, 0, 0, 0, 0, 0, 0)
    c.shade = cs

    -- ===== RETAIL / FOREVER: look Blizzard (borde claro fino, rojo glossy) =====
    local r = f.retail
    -- RETAIL / FOREVER: Blizzard's own nameplate atlases.
    --   health: fill "UI-HUD-CoolDownManager-Bar" + background/border "UI-HUD-CoolDownManager-Bar-BG"
    --   cast:   fill "UI-CastingBar-Full-Standard" + background "UI-CastingBar-Background"
    local bgTex = bar:CreateTexture(nil, "BACKGROUND", nil, -7)
    bgTex:SetAtlas(key == "cast" and "UI-CastingBar-Background" or "UI-HUD-CoolDownManager-Bar-BG")
    f.bg = bgTex
    -- El interior del atlas BG de Blizzard es azulado: se cubre con un rojo oscuro bajo el relleno (solo vida).
    if key ~= "cast" then
        local interior = bar:CreateTexture(nil, "BACKGROUND", nil, -6)
        interior:SetAllPoints(bar)
        interior:SetColorTexture(0.16, 0.03, 0.03, 1)
        f.interior = interior
    end
    -- Forever: 2px bronze band between two black lines; corners softly rounded
    -- (each ring is cut one pixel more than the one inside it).
    local fv = {}
    f.forever = fv
    local function Tex(color)
        local t = Solid(f, "OVERLAY", 6, color[1], color[2], color[3], 1)
        fv[#fv + 1] = t
        return t
    end
    local CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
    local BRONZE = { 0.56, 0.35, 0.16 }
    for _, ring in ipairs({ { 1, 0, { 0, 0, 0 } }, { 2, 1, BRONZE }, { 3, 1, BRONZE }, { 4, 2, { 0, 0, 0 } } }) do
        local d, c, color = ring[1], ring[2], ring[3]
        local t = Tex(color)
        t:SetPoint("TOPLEFT", bar, "TOPLEFT", -(d - c), d); t:SetPoint("TOPRIGHT", bar, "TOPRIGHT", d - c, d); t:SetHeight(1)
        t = Tex(color)
        t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -(d - c), -d); t:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", d - c, -d); t:SetHeight(1)
        t = Tex(color)
        t:SetPoint("TOPLEFT", bar, "TOPLEFT", -d, d - c); t:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", -d, -(d - c)); t:SetWidth(1)
        t = Tex(color)
        t:SetPoint("TOPRIGHT", bar, "TOPRIGHT", d, d - c); t:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", d, -(d - c)); t:SetWidth(1)
        -- staircase pixels closing the cut corner
        for i = 1, c - 1 do
            local x, y = d - c + i, d - i
            for _, corner in ipairs(CORNERS) do
                local p = Tex(color)
                p:SetSize(1, 1)
                p:SetPoint(corner, bar, corner, (corner:find("LEFT") and -x or x), (corner:find("TOP") and y or -y))
            end
        end
    end
    local gloss = Solid(f, "OVERLAY", 3, 1, 1, 1, 1)
    gloss:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0)
    gloss:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
    gloss:SetHeight(math.max(2, math.floor((bar:GetHeight() or 10) * 0.5)))
    Gradient(gloss, "VERTICAL", 1, 1, 1, 0.02, 1, 1, 1, 0.18)
    r.gloss = gloss
    local shade = Solid(f, "OVERLAY", 3, 0, 0, 0, 1)
    shade:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    shade:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    shade:SetHeight(math.max(2, math.floor((bar:GetHeight() or 10) * 0.4)))
    Gradient(shade, "VERTICAL", 0, 0, 0, 0.28, 0, 0, 0, 0)
    r.shade = shade
    if key == "cast" then
        local g1 = Solid(f, "OVERLAY", 5, 1.00, 0.85, 0.35, 0.8)
        g1:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, 0); g1:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0); g1:SetHeight(1)
        r[#r + 1] = g1
    end
    return f
end

local function SetShown(list, show)
    for _, t in ipairs(list) do t:SetShown(show) end
    if list.fallback then
        for _, t in ipairs(list.fallback) do t:SetShown(show and not list.blizz) end
    end
    if list.gloss then list.gloss:SetShown(show) end
    if list.shade then list.shade:SetShown(show) end
end

local function SkinBar(plate, bar, bg, field, key, theme)
    if not bar then return end
    local f = plate[field]
    if theme ~= "classic" and theme ~= "retail" and theme ~= "forever" then
        if f then f:Hide() end
        if bg and plate["_skinBG" .. key] then
            local o = plate["_skinBG" .. key]
            bg:SetColorTexture(o[1], o[2], o[3], o[4]); plate["_skinBG" .. key] = nil
        end
        return false
    end
    if not f then f = Build(plate, bar, key); plate[field] = f end
    f:Show()
    SetShown(f.classic, theme == "classic")
    SetShown(f.retail, false)   -- gloss/shade manuales: el atlas de Blizzard ya los trae
    if f.forever then SetShown(f.forever, theme == "forever") end
    local blizzLook = theme == "retail"
    if f.interior then f.interior:SetShown(theme ~= "classic") end
    if f.bg then
        f.bg:SetShown(blizzLook)
        if blizzLook then
            local H = bar:GetHeight() or 12
            f.bg:ClearAllPoints()
            if key == "cast" then
                f.bg:SetAllPoints(bar)
            else
                -- Blizzard: fondo/borde = barra + 0.25H a cada lado en X y 0.28H en Y
                local ex, ey = H * 0.25, H * 0.281
                f.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -ex, ey)
                f.bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", ex, -ey)
            end
        end
    end
    if bg then
        if not plate["_skinBG" .. key] then
            plate["_skinBG" .. key] = (key == "health") and { 0.12, 0.12, 0.12, 1 } or { 0.1, 0.1, 0.1, 0.9 }
        end
        if theme == "classic" then
            bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)       -- resto vacio oscuro (Classic real)
        elseif theme == "forever" and key == "cast" then
            bg:SetColorTexture(0.06, 0.06, 0.06, 0.9)
        else
            bg:SetColorTexture(0, 0, 0, 0)                   -- el atlas BG de Blizzard pinta el fondo
        end
    end
    return true
end

function ns.ApplyThemeSkin(plate)
    if not plate or not plate.health then return end
    local theme = RenderedTheme()
    local skinned = SkinBar(plate, plate.health, plate.healthBG, "_skinHealth", "health", theme)
    SkinBar(plate, plate.cast, plate.castBG, "_skinCast", "cast", theme)
    -- el borde generico de KUI se oculta cuando el skin del tema manda
    if skinned then
        if plate.borderFrame then plate.borderFrame:Hide() end
        if plate._simpleBorderFrame then plate._simpleBorderFrame:Hide() end
        if theme == "classic" then
            -- Textura original de las barras de Blizzard Classic (mate, sin brillo)
            plate.health:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
            if plate.cast then pcall(plate.cast.SetStatusBarTexture, plate.cast, "Interface\\TargetingFrame\\UI-StatusBar") end
        else
            -- Retail and Forever: Blizzard's nameplate bar fills
            pcall(plate.health.SetStatusBarTexture, plate.health, "UI-HUD-CoolDownManager-Bar")
            if plate.cast then pcall(plate.cast.SetStatusBarTexture, plate.cast, "UI-CastingBar-Full-Standard") end
        end
        if (theme == "classic" or theme == "forever") and plate.name then
            local nf, _, nfl = plate.name:GetFont()
            local sz = ((ns.GetEnemyNameTextSize and ns.GetEnemyNameTextSize()) or 10) + (theme == "classic" and 3 or 2)
            if nf then plate.name:SetFont(nf, sz, nfl or "OUTLINE") end
        end
    elseif plate._skinHealth and plate.ApplyBorderStyle then
        plate:ApplyBorderStyle()
    end
end

function ns.RefreshThemeSkin()
    if not ns.plates then return end
    for _, plate in pairs(ns.plates) do
        ns.ApplyThemeSkin(plate)
        if plate.RefreshPlateState then pcall(plate.RefreshPlateState, plate) end
    end
end

if KT then KT.RefreshNameplateTheme = function() ns.RefreshThemeSkin() end end

-- Yellow "!" just left of the bar on mobs you still need for a quest (every style).
function ns.ApplyThemeQuestIcon(plate, th)
    local health = plate and plate.health
    if not health then return end
    local qi = plate._fvQuest
    th = th or RenderedTheme()
    local show = plate._previewQuest or (plate.unit and ns.IsQuestMob and ns.IsQuestMob(plate.unit))
    if not show then
        if qi then qi:Hide() end
        return
    end
    if not qi then
        qi = plate:CreateFontString(nil, "OVERLAY")
        plate._fvQuest = qi
    end
    local barH = health:GetHeight() or 16
    local font = plate.level and plate.level:GetFont() or STANDARD_TEXT_FONT
    qi:SetFont(font, math.floor(barH + 4), "OUTLINE")
    qi:SetText("!")
    qi:SetTextColor(1, 0.86, 0.10, 1)
    qi:ClearAllPoints()
    -- Retail's Blizzard border sticks out 0.25H to the left of the bar
    local gap = (th == "retail") and math.floor(barH * 0.25 + 4) or (th == "forever") and 7 or 5
    qi:SetPoint("RIGHT", health, "LEFT", -gap, 0)
    qi:Show()
end

-- Small level box with a two-tone border and 1px-cut (rounded) corners.
local function BuildLevelBox(plate, outer, rim, fill)
    local box = CreateFrame("Frame", nil, plate)
    local function Rect(sub, c, l, t, r, b)
        local tx = box:CreateTexture(nil, "BACKGROUND", nil, sub)
        tx:SetColorTexture(c[1], c[2], c[3], 1)
        tx:SetPoint("TOPLEFT", l, -t)
        tx:SetPoint("BOTTOMRIGHT", -r, b)
    end
    -- Same layering as the Forever bar frame: outer line, rim line, black line, dark inside.
    -- A ring cut by c pixels at each corner is the union of c + 1 overlapping rectangles.
    local function Ring(sub, color, base, c)
        for i = 0, c do Rect(sub, color, base + c - i, base + i, base + c - i, base + i) end
    end
    Ring(-5, outer, 0, 2)
    Ring(-4, rim, 1, 1)
    Ring(-3, { 0, 0, 0 }, 2, 0)
    Rect(-2, fill, 3, 3, 3, 3)
    box.txt = box:CreateFontString(nil, "OVERLAY")
    box.txt:SetPoint("CENTER", box, "CENTER", 1, 0)
    box.txt:SetJustifyH("CENTER")
    return box
end

-- Fills a level box with the plate's level text (difficulty colour, yellow fallback) and sizes it.
local function FillLevelBox(box, level, health, h, size, anchorX)
    box:SetFrameLevel(health:GetFrameLevel() + 8)
    local okT, txt = pcall(level.GetText, level)
    if not okT then txt = nil end
    local w = h
    if type(txt) == "string" and not (issecretvalue and issecretvalue(txt)) then
        w = math.max(h, math.floor(#txt * size * 0.62 + 8))
    end
    box:SetSize(w, h)
    box:ClearAllPoints()
    box:SetPoint("LEFT", health, "RIGHT", anchorX, 0)
    box.txt:SetFont(level:GetFont() or STANDARD_TEXT_FONT, size, "OUTLINE")
    local okC, cr, cg, cb = pcall(level.GetTextColor, level)
    if okC and cr and not (cr == 0 and cg == 0 and cb == 0) then box.txt:SetTextColor(cr, cg, cb, 1) else box.txt:SetTextColor(1, 0.82, 0, 1) end
    box.txt:SetText(txt or "")
    level:SetAlpha(0)
    box:SetShown(level:IsShown() and true or false)
end

-- Forever: yellow level box just right of the bar (original Forever plate).
local function ApplyForeverLevel(plate, level, health)
    local fb = plate._fvBadge
    if not fb then
        fb = BuildLevelBox(plate, { 0, 0, 0 }, { 1, 0.82, 0 }, { 0.02, 0.02, 0.02 })
        plate._fvBadge = fb
    end
    local barH = health:GetHeight() or 16
    -- as tall as the bar with its 4px frame
    FillLevelBox(fb, level, health, math.floor(barH + 8), math.max(9, math.floor(barH * 0.7)), 6)
    fb.txt:SetTextColor(1, 0.82, 0, 1)
end

-- Classic: filled gold pill (black edge, light gold rim, darker gold inside); the ends are circles.
local CIRCLE_MASK = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_mask.tga"
local PILL_LAYERS = {
    { 0, 0.02, 0.02, 0.02, -4 },
    { 1, 0.88, 0.74, 0.36, -3 },
    { 2, 0.58, 0.46, 0.15, -2 },
}
local function BuildClassicPill(plate)
    local box = CreateFrame("Frame", nil, plate)
    box.layers = {}
    for _, L in ipairs(PILL_LAYERS) do
        local parts = { inset = L[1] }
        for i = 1, 3 do
            local t = box:CreateTexture(nil, "BACKGROUND", nil, L[5])
            t:SetColorTexture(L[2], L[3], L[4], 1)
            if i ~= 2 then
                -- circle_mask.tga is a MASK: applied over a solid colour texture
                local m = box:CreateMaskTexture()
                m:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                m:SetAllPoints(t)
                t:AddMaskTexture(m)
            end
            parts[i] = t
        end
        box.layers[#box.layers + 1] = parts
    end
    box.txt = box:CreateFontString(nil, "OVERLAY")
    box.txt:SetPoint("CENTER", box, "CENTER", 0, 0)
    box.txt:SetJustifyH("CENTER")
    box.txt:SetShadowColor(0, 0, 0, 1)
    box.txt:SetShadowOffset(1, -1)
    return box
end

local function LayoutClassicPill(box, w, h)
    w = math.max(w, h)
    box:SetSize(w, h)
    for _, p in ipairs(box.layers) do
        local i = p.inset
        local d = h - 2 * i
        p[1]:ClearAllPoints(); p[1]:SetSize(d, d); p[1]:SetPoint("LEFT", box, "LEFT", i, 0)
        p[3]:ClearAllPoints(); p[3]:SetSize(d, d); p[3]:SetPoint("RIGHT", box, "RIGHT", -i, 0)
        p[2]:ClearAllPoints()
        p[2]:SetPoint("TOPLEFT", box, "TOPLEFT", i + d / 2, -i)
        p[2]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -(i + d / 2), i)
    end
end

-- Classic: el nivel va en una pildora dorada que solapa el extremo derecho de la barra.
function ns.ApplyThemeLevel(plate)
    local level, health = plate and plate.level, plate and plate.health
    if not (level and health) then return end
    local badge = plate._clBadge
    local th = RenderedTheme()
    ns.ApplyThemeQuestIcon(plate, th)
    if th == "forever" then
        if badge then badge:Hide() end
        if plate._blzBadge then plate._blzBadge:Hide() end
        ApplyForeverLevel(plate, level, health)
        return
    end
    if plate._fvBadge then plate._fvBadge:Hide() end
    if th ~= "classic" then
        level:SetAlpha(1)
        if badge then badge:Hide() end
        local bb = plate._blzBadge
        if th ~= "retail" then
            if bb then bb:Hide() end
            level:SetJustifyH("RIGHT")
            return
        end
        -- Retail: nivel en BLANCO, sin placa ni textura, dentro de la barra al inicio y tan grande como la barra;
        -- el nombre se desplaza a su derecha (ns.ThemeLevelInset).
        if not bb then
            bb = CreateFrame("Frame", nil, plate)
            bb.txt = bb:CreateFontString(nil, "OVERLAY")
            bb.txt:SetPoint("CENTER", bb, "CENTER", 0, 0)
            bb.txt:SetJustifyH("CENTER")
            plate._blzBadge = bb
        end
        bb:SetFrameLevel(health:GetFrameLevel() + 8)
        local barH = health:GetHeight() or 16
        local size = math.max(8, math.floor(barH * 0.85))
        bb:SetSize(size * 1.4, barH)
        bb:ClearAllPoints()
        bb:SetPoint("LEFT", health, "LEFT", 3, 0)
        local font = level:GetFont()
        if font then bb.txt:SetFont(font, size, "OUTLINE") end
        bb.txt:SetTextColor(1, 1, 1, 1)
        local okT, txt = pcall(level.GetText, level)
        bb.txt:SetText((okT and txt) or "")
        level:SetAlpha(0)
        bb:SetShown(level:IsShown() and true or false)
        return
    end
    if plate._blzBadge then plate._blzBadge:Hide() end
    if not badge then
        badge = BuildClassicPill(plate)
        plate._clBadge = badge
    end
    badge:SetFrameLevel(health:GetFrameLevel() + 8)
    local barH = health:GetHeight() or 10
    local h = math.floor(barH + 5)
    local size = math.max(9, math.min(13, math.floor(barH * 0.95)))
    local okT, txt = pcall(level.GetText, level)
    if not okT then txt = nil end
    local w = math.floor(h * 1.7)
    if type(txt) == "string" and not (issecretvalue and issecretvalue(txt)) then
        w = math.max(w, math.floor(#txt * size * 0.6 + h * 0.7))
    end
    LayoutClassicPill(badge, w, h)
    badge:ClearAllPoints()
    badge:SetPoint("LEFT", health, "RIGHT", -math.floor(h * 0.5), 0)   -- solapa el extremo derecho de la barra
    badge.txt:SetFont(level:GetFont() or STANDARD_TEXT_FONT, size, "")
    badge.txt:SetTextColor(1, 0.86, 0.32, 1)
    badge.txt:SetText(txt or "")
    level:SetAlpha(0)
    badge:SetShown(level:IsShown() and true or false)
end

-- Espacio que ocupa la placa de nivel interna (Retail) a la izquierda del nombre.
function ns.ThemeLevelInset(plate)
    local th = RenderedTheme()
    if th ~= "retail" then return 0 end
    local lv, health = plate and plate.level, plate and plate.health
    if not (lv and health and lv:IsShown()) then return 0 end
    local size = math.max(8, math.floor((health:GetHeight() or 16) * 0.85))
    return size * 1.4 + 3
end

-- Altura de barra por tema (solo si el usuario no fijo healthBarHeight).
function ns.ThemeBarHeight()
    local th = RenderedTheme()
    if th == "classic" then return 15 end
    if th == "retail" then return 23 end
    if th == "forever" then return 17 end
    return nil
end

-- Options live preview: applies the active style to the preview's own bars, texts and border.
function ns.ApplyThemePreview(pf, health, healthBG, cast, castBG, nameFS, levelFS, border, simpleBorder)
    if not (pf and health) then return end
    local p = pf._themeProxy
    if not p then
        p = CreateFrame("Frame", nil, pf)
        p:SetAllPoints(pf)
        p._previewQuest = true
        pf._themeProxy = p
    end
    p.health, p.healthBG, p.cast, p.castBG = health, healthBG, cast, castBG
    p.name, p.level = nameFS, levelFS
    p.borderFrame, p._simpleBorderFrame = border, simpleBorder
    ns.ApplyThemeSkin(p)
    ns.ApplyThemeLevel(p)
end

-- Ancho extra de barra por tema (solo si el usuario no fijo healthBarWidth).
function ns.ThemeBarWidthExtra()
    if RenderedTheme() == "classic" then return 85 end
    return nil
end

-- Room the Forever quest icon and level badge take beside the bar, so the target arrows sit outside them.
function ns.ThemeLateralExtent(plate)
    local l, r = 0, 0
    local qi, fb = plate and plate._fvQuest, plate and plate._fvBadge
    if qi and qi:IsShown() then
        local gap = (RenderedTheme() == "retail") and math.floor((plate.health:GetHeight() or 16) * 0.25 + 4) or 5
        l = gap + (qi:GetStringWidth() or 0)
    end
    if fb and fb:IsShown() then r = 6 + (fb:GetWidth() or 0) end
    return l, r
end

-- Refresh the quest icons when the quest log changes.
local questRefresh = CreateFrame("Frame")
questRefresh:RegisterEvent("QUEST_LOG_UPDATE")
questRefresh:SetScript("OnEvent", function(self)
    if self.pending or not ns.plates then return end
    self.pending = true
    C_Timer.After(0.2, function()
        self.pending = nil
        for _, plate in pairs(ns.plates) do ns.ApplyThemeQuestIcon(plate) end
    end)
end)

function ns.ThemeBlizzText()
    return RenderedTheme() == "retail"
end
