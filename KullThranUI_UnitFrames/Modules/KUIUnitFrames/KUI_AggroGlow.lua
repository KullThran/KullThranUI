-------------------------------------------------------------------------------
--  Aggro glow on the Player unit frame (Forever / Retail / Classic visual styles).
--  When the player or the pet has aggro (threat status >= 2) in combat, the
--  portrait ring and the area above the health bar glow red and pulse, like
--  Blizzard's default frame flash. It is drawn on its own overlay frame, so it
--  works with any Elite/Rare border style (or none).
--  Disable with KT.db.profile.unitFrames.aggroGlow = false.
-------------------------------------------------------------------------------
local _, ns = ...
local KT = _G.KullThranUI

local CIRCLE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_border.tga"
local WHITE = "Interface\\Buttons\\WHITE8x8"
local R, G, B = 1.0, 0.08, 0.08
local PORTRAIT_MASK_DEFAULT = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_mask.tga"

local AG = {}
ns.AggroGlow = AG

local function Theme()
    local VT = KT and KT.VisualThemes
    return VT and VT.GetRenderedTheme and VT:GetRenderedTheme() or nil
end

local function Enabled()
    local t = Theme()
    if t ~= "forever" and t ~= "retail" and t ~= "classic" then return false end
    local db = KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
    if db and db.aggroGlow == false then return false end
    return true
end

local function HasAggro(unitKey)
    if not UnitAffectingCombat("player") then return false end
    -- Target frame: glow when you (or your pet) hold aggro on the hostile target.
    if unitKey == "target" then
        if not (UnitExists("target") and UnitCanAttack("player", "target")) then return false end
        for _, u in ipairs({ "player", "pet" }) do
            if UnitExists(u) then
                local ok, v = pcall(UnitThreatSituation, u, "target")
                if ok and type(v) == "number" then
                    local ok2, hot = pcall(function() return v >= 2 end)
                    if ok2 and hot then return true end
                end
            end
        end
        return false
    end
    for _, u in ipairs({ "player", "pet" }) do
        if UnitExists(u) then
            local ok, v = pcall(UnitThreatSituation, u)
            if ok and type(v) == "number" then
                local ok2, hot = pcall(function() return v >= 2 end)
                if ok2 and hot then return true end
            end
        end
    end
    return false
end

-- El glow es una COPIA tintada de rojo (mezcla ADD) de las texturas reales del
-- frame (arte del atlas Forever/Retail/Classic, anillo Elite/Rara, borde del
-- retrato), ligeramente ensanchada, para que siga exactamente su forma.
local PAD = 0

local function CloneTexture(g, i, src)
    local dst = g.clones[i]
    if not dst then
        dst = g.clip:CreateTexture(nil, "OVERLAY", nil, 6)
        -- BLEND (no ADD): el arte dorado de Retail/Forever sumaria a naranja y
        -- se confundiria con el propio marco; asi queda rojo y lo cubre.
        dst:SetBlendMode("BLEND")
        g.clones[i] = dst
    end
    local ok = pcall(function()
        local atlas = src.GetAtlas and src:GetAtlas()
        if atlas then
            dst:SetAtlas(atlas, false)
        else
            dst:SetTexture(src:GetTexture())
            dst:SetTexCoord(src:GetTexCoord())
        end
        dst:ClearAllPoints()
        -- El arte puede vivir en un frame con otra escala: compensarla.
        local par = src.GetParent and src:GetParent() or nil
        local ss = par and par.GetEffectiveScale and par:GetEffectiveScale() or 1
        local gs = g:GetEffectiveScale() or 1
        local r = (gs > 0) and (ss / gs) or 1
        local n = src:GetNumPoints()
        if n == 0 then error("nopoints") end
        for k = 1, n do
            local pt, rel, relPt, x, y = src:GetPoint(k)
            x, y = (x or 0) * r, (y or 0) * r
            if pt:find("LEFT") then x = x - PAD elseif pt:find("RIGHT") then x = x + PAD end
            if pt:find("TOP") then y = y + PAD elseif pt:find("BOTTOM") then y = y - PAD end
            dst:SetPoint(pt, rel, relPt, x, y)
        end
        -- Arte anclado con un solo punto + SetSize: copiar tambien el tamano.
        if n < 2 then
            local w, h = src:GetSize()
            if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then error("nosize") end
            dst:SetSize(w * r + PAD * 2, h * r + PAD * 2)
        end
        dst:SetVertexColor(1, 0.12, 0.12, 1)
    end)
    if not ok then dst:ClearAllPoints() end
    dst:SetShown(ok)
    return ok
end

local function Build(frame)
    local g = CreateFrame("Frame", nil, frame)
    g:SetAllPoints(frame)
    g:SetFrameLevel(frame:GetFrameLevel() + 20)
    g:Hide()
    g.clones = {}

    -- Fallback si no hay arte que copiar: anillos circulares suaves en el retrato.
    g.rings = {}
    for i, a in ipairs({ 1.0, 0.5, 0.22 }) do
        local t = g:CreateTexture(nil, "OVERLAY", nil, 6)
        t:SetTexture(CIRCLE)
        t:SetVertexColor(R, G, B, a)
        t:SetBlendMode("ADD")
        g.rings[i] = t
    end

    -- Recorte: la copia tintada del arte solo se ve sobre la zona del retrato.
    local clip = CreateFrame("Frame", nil, g)
    clip:SetClipsChildren(true)
    clip:SetAllPoints(g)
    g.clip = clip

    -- Glow suave arriba de la barra (zona del nombre), degradado hacia arriba.
    local top = g:CreateTexture(nil, "OVERLAY", nil, 5)
    top:SetTexture(WHITE)
    top:SetBlendMode("ADD")
    if top.SetGradient and CreateColor then
        top:SetGradient("VERTICAL", CreateColor(R, G, B, 0.55), CreateColor(R, G, B, 0))
    else
        top:SetVertexColor(R, G, B, 0.3)
    end
    g.top = top

    -- Velo rojo SOBRE la cara del retrato, recortado con la forma de su mascara.
    local ov = g:CreateTexture(nil, "OVERLAY", nil, 7)
    ov:SetTexture(WHITE)
    ov:SetVertexColor(R, G, B, 0.45)
    ov:SetBlendMode("ADD")
    ov:Hide()
    g.overlay = ov
    local mask = g:CreateMaskTexture()
    mask:SetTexture(PORTRAIT_MASK_DEFAULT, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    ov:AddMaskTexture(mask)
    g.mask = mask

    -- Pulso: OnUpdate modula la opacidad del glow.
    local t0 = 0
    g:SetScript("OnUpdate", function(self, dt)
        t0 = t0 + dt
        -- Coseno suave (periodo ~1.4 s), mismo valor para retrato y glow superior.
        local k = 0.575 + 0.425 * math.cos(t0 * 4.5)
        self:SetAlpha(k)
    end)
    g.pulse = { Play = function() end, Stop = function() end, IsPlaying = function() return true end }
    return g
end

local function Layout(frame, g)
    local sources = {
        frame._ktForeverPortraitArt or false, frame._ktClassicPortraitArt or false,
        frame._kuiClassificationPortraitRing or false, frame._kuiClassificationIndicator or false,
        frame._kuiNativeClassRing or false, frame._kuiClassicRingTex or false,
    }
    -- Por encima del retrato y del arte: igualar strata y nivel maximos.
    local order = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5, FULLSCREEN = 6,
        FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }
    local bestStrata, bestRank, bestLevel = frame:GetFrameStrata(), 0, frame:GetFrameLevel()
    local function Consider(f)
        if not (f and f.GetFrameStrata and f.GetFrameLevel) then return end
        local st, lv = f:GetFrameStrata(), f:GetFrameLevel()
        local rk = order[st] or 3
        if rk > (order[bestStrata] or 3) then bestStrata, bestLevel = st, lv
        elseif rk == (order[bestStrata] or 3) and lv > bestLevel then bestLevel = lv end
    end
    for _, src in ipairs(sources) do Consider(src and src.GetParent and src:GetParent()) end
    local bd = frame.Portrait and frame.Portrait.backdrop
    Consider(bd); Consider(frame.Portrait)
    local function Kids(f)
        if not (f and f.GetChildren) then return end
        for _, c in ipairs({ f:GetChildren() }) do Consider(c) end
    end
    Kids(bd); Kids(frame.Portrait)
    Consider(frame._ktForeverArtHost); Consider(frame._ktClassicArtHost)
    g:SetFrameStrata(bestStrata)
    g:SetFrameLevel(math.min(bestLevel + 2, 65000))

    -- Velo sobre el retrato (con cualquier borde Elite/Rara).
    -- El velo sobre toda la cara se descarta: solo brilla el borde (copias del arte).
    if false and bd and bd:IsShown() then
        local sm = bd._shapeMask
        pcall(function()
            local atlas = sm and sm.GetAtlas and sm:GetAtlas()
            if atlas then g.mask:SetAtlas(atlas)
            elseif sm and sm.GetTexture and sm:GetTexture() then
                g.mask:SetTexture(sm:GetTexture(), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            end
        end)
        g.mask:ClearAllPoints(); g.mask:SetAllPoints(bd)
        g.overlay:ClearAllPoints(); g.overlay:SetAllPoints(bd)
        g.overlay:Show()
    else
        g.overlay:Hide()
    end

    local hb = frame.Health
    if hb and hb:IsShown() then
        g.top:ClearAllPoints()
        g.top:SetPoint("BOTTOMLEFT", hb, "TOPLEFT", 0, 0)
        g.top:SetPoint("BOTTOMRIGHT", hb, "TOPRIGHT", 0, 0)
        g.top:SetHeight(20)
        g.top:Show()
    else
        g.top:Hide()
    end
    -- Zona de recorte: el retrato, ampliada al anillo Elite/Rara (dragon, etc.)
    -- o a la hoja Classic Elite/Rara cuando estan activos.
    local bdp = frame.Portrait and frame.Portrait.backdrop
    local ringAnchor
    for _, r in ipairs({ frame._kuiClassificationPortraitRing or false, frame._kuiClassificationIndicator or false,
        frame._kuiNativeClassRing or false, frame._kuiClassicRingTex or false }) do
        if r and r.IsShown and r:IsShown() and (r:GetWidth() or 0) > 1 then
            if not ringAnchor or (r:GetWidth() or 0) > (ringAnchor:GetWidth() or 0) then ringAnchor = r end
        end
    end
    g.clip:ClearAllPoints()
    local placed = false
    if ringAnchor then
        g.clip:SetPoint("TOPLEFT", ringAnchor, "TOPLEFT", -6, 6)
        g.clip:SetPoint("BOTTOMRIGHT", ringAnchor, "BOTTOMRIGHT", 6, -6)
        placed = true
    elseif frame._ktClassicSheetPath and bdp and bdp:IsShown() then
        -- Hoja Classic Elite/Rara: toda la zona del retrato, sin la barra.
        local art = frame._ktClassicPortraitArt
        if art and art:IsShown() then
            local ok = pcall(function()
                local aL, aR = art:GetLeft(), art:GetRight()
                local bR = bdp:GetRight()
                if not (aL and aR and bR) then error("noGeom") end
                g.clip:SetPoint("TOPLEFT", art, "TOPLEFT", -6, 6)
                g.clip:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", (bR + 22) - aR, -6)
            end)
            placed = ok
        end
    end
    if not placed then
        g.clip:ClearAllPoints()
        if bdp and bdp:IsShown() then
            g.clip:SetPoint("TOPLEFT", bdp, "TOPLEFT", -8, 8)
            g.clip:SetPoint("BOTTOMRIGHT", bdp, "BOTTOMRIGHT", 4, -8)
        else
            g.clip:SetAllPoints(g)
        end
    end

    -- Copia tintada del arte, recortada al retrato (no colorea el resto del atlas).
    g.tinted = {}
    local used = 0
    for _, src in ipairs(sources) do
        if src and src.IsShown and src:IsShown() and src.GetTexture then
            local idx = used + 1
            if CloneTexture(g, idx, src) then used = idx end
        end
    end
    for k = used + 1, #g.clones do g.clones[k]:Hide() end

    -- Fallback circular solo si no se pudo copiar nada
    local backdrop = frame.Portrait and frame.Portrait.backdrop
    local anchor = (used == 0 and backdrop and backdrop:IsShown()) and backdrop or nil
    local size = anchor and (anchor:GetWidth() or 46) * 1.18
    local mult = { 1.0, 1.12, 1.26 }
    for i, t in ipairs(g.rings) do
        t:SetShown(anchor ~= nil)
        if anchor then
            t:ClearAllPoints(); t:SetPoint("CENTER", anchor, "CENTER", 0, 0)
            t:SetSize(size * mult[i], size * mult[i])
        end
    end
end

local function UpdateUnit(unitKey)
    local frame = ns.frames and ns.frames[unitKey]
    if not frame then return end
    local g = frame._kuiAggroGlow
    if not (Enabled() and HasAggro(unitKey) and frame:IsShown()) then
        if g then
            for src, o in pairs(g.saved or {}) do pcall(src.SetVertexColor, src, o[1], o[2], o[3], o[4]) end
            g.saved, g.tinted = {}, {}
            g:Hide()
        end
        return
    end
    if not g then g = Build(frame); frame._kuiAggroGlow = g end
    Layout(frame, g)
    g:Show()
    if not g.pulse:IsPlaying() then g.pulse:Play() end
end

function AG:Update()
    UpdateUnit("player")
    UpdateUnit("target")
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_PET", "PLAYER_TARGET_CHANGED" }) do
    ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function() AG:Update() end)
