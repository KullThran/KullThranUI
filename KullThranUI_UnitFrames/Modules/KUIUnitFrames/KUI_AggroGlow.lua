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

local function Enabled(resting)
    local t = Theme()
    if t ~= "forever" and t ~= "retail" and t ~= "classic" then return false end
    local db = KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
    if not resting and db and db.aggroGlow == false then return false end
    return true
end

local function HasAggro(unitKey)
    if not UnitAffectingCombat("player") then return false end
    -- Target frame: glow when you (or your pet) hold aggro on the hostile target.
    if unitKey == "target" then
        if not (UnitExists("target") and UnitCanAttack("player", "target")) then return false end
        local ok, fighting = pcall(UnitAffectingCombat, "target")
        if ok and not (issecretvalue and issecretvalue(fighting)) and fighting then return true end
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

local function CloneTexture(g, i, src, pool, host)
    pool, host = pool or g.clones, host or g.clip
    local dst = pool[i]
    if not dst then
        dst = host:CreateTexture(nil, "OVERLAY", nil, 6)
        -- BLEND (no ADD): el arte dorado de Retail/Forever sumaria a naranja y
        -- se confundiria con el propio marco; asi queda rojo y lo cubre.
        dst:SetBlendMode("BLEND")
        pool[i] = dst
    end
    dst:SetBlendMode("BLEND")
    local pad = PAD
    local ok, failure = pcall(function()
        local atlas = src.GetAtlas and src:GetAtlas()
        if atlas then
            if dst:SetAtlas(atlas, false) == false then error("atlas rejected") end
        else
            local file = src._ktGlowTextureFile or src:GetTexture()
            if dst:SetTexture(file) == false then error("texture rejected") end
        end
        if dst.SetDesaturated then dst:SetDesaturated(true) end
        dst:SetTexCoord(src:GetTexCoord())
        if dst._ktRestMaskAttached then
            dst:RemoveMaskTexture(dst._ktRestMask)
            dst._ktRestMask:Hide()
            dst._ktRestMaskAttached = nil
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
            if pt:find("LEFT") then x = x - pad elseif pt:find("RIGHT") then x = x + pad end
            if pt:find("TOP") then y = y + pad elseif pt:find("BOTTOM") then y = y - pad end
            dst:SetPoint(pt, rel, relPt, x, y)
        end
        -- Arte anclado con un solo punto + SetSize: copiar tambien el tamano.
        if n < 2 then
            local w, h = src:GetSize()
            if type(w) ~= "number" or type(h) ~= "number" or w <= 0 or h <= 0 then error("nosize") end
            dst:SetSize(w * r + pad * 2, h * r + pad * 2)
        end
        local color = g.color or { 1, 0.12, 0.12 }
        dst:SetVertexColor(color[1], color[2], color[3], 1)
    end)
    if not ok then
        dst:ClearAllPoints()
        local debug = KT.Portrait3DDebug
        g.lastCloneError = debug and debug.Value(failure) or "texture copy failed"
    end
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

    -- Los anillos Elite/Rara modernos y Retail viven en el overlay de
    -- indicadores (o justo debajo), que queda por encima del glow para que el
    -- nivel y el PvP se vean. Su copia tintada va en un recorte propio, por
    -- encima de esos anillos y por debajo de las insignias.
    local ringClip = CreateFrame("Frame", nil, g)
    ringClip:SetClipsChildren(true)
    ringClip:SetAllPoints(clip)
    g.ringClip = ringClip
    g.ringClones = {}

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

local function LayoutRestGlow(frame, g)
    local backdrop = frame.Portrait and frame.Portrait.backdrop
    if not (g.resting and backdrop and backdrop:IsShown()) then
        if g.restGlow then g.restGlow:Hide() end
        if g.restHeaderClip then g.restHeaderClip:Hide() end
        return false
    end
    local atlas = "UI-HUD-UnitFrame-Player-PortraitOn-Status"
    local classic = Theme() == "classic"
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    local texture = g.restGlow
    if not texture then
        texture = g:CreateTexture(nil, "OVERLAY", nil, 6)
        g.restGlow = texture
    end
    local ok, failure = pcall(function()
        local native = info and info.width and info.height
        if native then
            if texture:SetAtlas(atlas, false) == false then error("rest atlas rejected") end
        elseif classic then
            if texture:SetTexture([[Interface\TargetingFrame\UI-TargetingFrame-Flash]]) == false then
                error("classic flash texture rejected")
            end
            texture:SetTexCoord(0.9453125, 0, 0, 0.181640625)
        else
            -- Original Blizzard status art for clients without the HUD atlas.
            if texture:SetTexture([[Interface\CharacterFrame\UI-Player-Status]]) == false then
                error("classic rest texture rejected")
            end
            texture:SetTexCoord(0, 1, 0, 1)
        end
        texture:SetBlendMode("ADD")
        if texture.SetDesaturated then texture:SetDesaturated(true) end
        texture:SetVertexColor(1, 0.82, 0.25, 0.8)
        local scale = backdrop:GetWidth() / 60
        local bp = backdrop:GetParent()
        local bs = bp and bp.GetEffectiveScale and bp:GetEffectiveScale() or 1
        local gs = g:GetEffectiveScale() or 1
        scale = scale * bs / gs
        texture:ClearAllPoints()
        if native then
            -- Native HUD portrait (24,-19), status art (17,-14).
            texture:SetPoint("TOPLEFT", backdrop, "TOPLEFT", -7 * scale, 5 * scale)
            texture:SetSize(info.width * scale, info.height * scale)
        elseif classic then
            -- Mirror the native Target flash around its portrait center for Player.
            texture:SetPoint("TOPLEFT", backdrop, "TOPLEFT", -28 * scale, 13 * scale)
            texture:SetSize(242 * scale, 93 * scale)
        else
            texture:SetPoint("TOPLEFT", backdrop, "TOPLEFT", -16 * scale, 12 * scale)
            texture:SetSize(256 * scale, 128 * scale)
        end
    end)
    local debug = KT.Portrait3DDebug
    g.lastNativeRestError = not ok and (debug and debug.Value(failure) or "native rest glow failed") or nil
    if g.restHeaderClip then g.restHeaderClip:Hide() end
    if classic and ok then
        local mask = g.restClassicMask
        if not mask then
            mask = g:CreateMaskTexture()
            mask:SetTexture(PORTRAIT_MASK_DEFAULT, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            g.restClassicMask = mask
        end
        mask:ClearAllPoints()
        mask:SetPoint("CENTER", backdrop, "CENTER", 0, 0)
        -- circle_mask's visible alpha spans 104 of its 128 pixels.
        local diameter = (backdrop:GetWidth() + 10) * 128 / 104
        local bp = backdrop:GetParent()
        diameter = diameter * ((bp and bp.GetEffectiveScale and bp:GetEffectiveScale()) or 1) / (g:GetEffectiveScale() or 1)
        mask:SetSize(diameter, diameter)
        mask:Show()
        if not g.restClassicMaskAttached then
            texture:AddMaskTexture(mask)
            g.restClassicMaskAttached = true
        end
        local health = frame.Health
        if health then
            local clip = g.restHeaderClip
            if not clip then
                clip = CreateFrame("Frame", nil, g)
                clip:SetClipsChildren(true)
                g.restHeaderClip = clip
                g.restHeaderGlow = clip:CreateTexture(nil, "OVERLAY", nil, 6)
            end
            clip:ClearAllPoints()
            clip:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 40)
            clip:SetPoint("BOTTOMRIGHT", health, "TOPRIGHT", 0, 0)
            local header = g.restHeaderGlow
            if info and info.width then header:SetAtlas(atlas, false)
            else header:SetTexture([[Interface\CharacterFrame\UI-Player-Status]]); header:SetTexCoord(0, 1, 0, 1) end
            header:ClearAllPoints(); header:SetAllPoints(texture)
            header:SetBlendMode("ADD"); header:SetVertexColor(1, 0.82, 0.25, 0.8)
            if header.SetDesaturated then header:SetDesaturated(true) end
            header:Show(); clip:Show()
        end
    elseif g.restClassicMaskAttached then
        texture:RemoveMaskTexture(g.restClassicMask)
        g.restClassicMask:Hide()
        g.restClassicMaskAttached = nil
    end
    texture:SetShown(ok)
    return ok
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
        local st, lv = f:GetFrameStrata(), f._ktGlowBaseLevel or f:GetFrameLevel()
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
    g:SetFrameLevel(math.min(bestLevel + 2, 64990))
    local glowLevel = g:GetFrameLevel()
    for _, key in ipairs({"_kuiIndicatorOverlay", "_kuiLevelOverlay", "_kuiLevelRingHost"}) do
        local badgeHost = frame[key]
        if badgeHost then
            badgeHost._ktGlowBaseLevel = badgeHost._ktGlowBaseLevel or badgeHost:GetFrameLevel()
            badgeHost:SetFrameStrata(bestStrata)
            -- Indicadores (anillo Elite/Rara) +3, copia roja del anillo +4, nivel y
            -- PvP +5, aro del nivel +6, numero del nivel +7: el anillo nunca tapa el PvP.
            local offset = (key == "_kuiLevelRingHost" and 6) or (key == "_kuiLevelOverlay" and 5) or 3
            badgeHost:SetFrameLevel(glowLevel + offset)
        end
    end
    g.ringClip:SetFrameStrata(bestStrata)
    g.ringClip:SetFrameLevel(glowLevel + 4)
    for _, key in ipairs({"_kuiLevelText", "_kuiLevelCombatIcon"}) do
        local badge = frame[key]
        local parent = badge and badge.GetParent and badge:GetParent()
        if parent and parent ~= frame then
            parent._ktGlowBaseLevel = parent._ktGlowBaseLevel or parent:GetFrameLevel()
            parent:SetFrameStrata(bestStrata)
            parent:SetFrameLevel(math.max(parent:GetFrameLevel(), glowLevel + 7))
        end
    end

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
    elseif frame.unit ~= "target" and frame._ktClassicSheetPath and bdp and bdp:IsShown() then
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
            g.clip:SetPoint("TOPLEFT", bdp, "TOPLEFT", frame.unit == "target" and -4 or -8, 8)
            g.clip:SetPoint("BOTTOMRIGHT", bdp, "BOTTOMRIGHT", frame.unit == "target" and 8 or 4, -8)
        else
            g.clip:SetAllPoints(g)
        end
    end

    -- La zona de recorte nunca debe entrar en las barras: el arte copiado
    -- incluye el panel de barras del atlas y lo teÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â±iria de rojo. Se corta en
    -- el borde izquierdo de Health (la cabeza del dragon queda por encima).
    if hb and hb:IsShown() then
        pcall(function()
            if frame.unit == "target" then
                local hr, cl = hb:GetRight(), g.clip:GetLeft()
                if hr and cl and cl < hr then
                    local pt, rel, relPt, x, y = g.clip:GetPoint(1)
                    if pt then g.clip:SetPoint(pt, rel, relPt, (x or 0) + (hr - cl), y or 0) end
                end
                return
            end
            local hl, cr = hb:GetLeft(), g.clip:GetRight()
            if hl and cr and cr > hl then
                local pt, rel, relPt, x, y = g.clip:GetPoint(2)
                if pt then
                    g.clip:SetPoint(pt, rel, relPt, (x or 0) + (hl - cr), y or 0)
                end
            end
        end)
    end

    -- El anillo Elite/Rara no pasa por el corte de las barras: su copia solo
    -- pinta sus propios pixeles, asi que puede brillar entero (cola del dragon).
    g.ringClip:ClearAllPoints()
    if ringAnchor then
        g.ringClip:SetPoint("TOPLEFT", ringAnchor, "TOPLEFT", -6, 6)
        g.ringClip:SetPoint("BOTTOMRIGHT", ringAnchor, "BOTTOMRIGHT", 6, -6)
    else
        g.ringClip:SetAllPoints(g.clip)
    end

    local nativeRest = LayoutRestGlow(frame, g)
    if nativeRest then g.top:Hide() end

    -- Copia tintada del arte, recortada al retrato (no colorea el resto del atlas).
    g.tinted = {}
    local used, ringUsed = 0, 0
    g.lastCloneError = nil
    local ringSources = {}
    for _, key in ipairs({ "_kuiClassificationPortraitRing", "_kuiClassificationIndicator",
        "_kuiNativeClassRing", "_kuiClassicRingTex" }) do
        if frame[key] then ringSources[frame[key]] = true end
    end
    for _, src in ipairs(sources) do
        if not nativeRest and src and src.IsShown and src:IsShown() and src.GetTexture then
            if ringSources[src] then
                local idx = ringUsed + 1
                if CloneTexture(g, idx, src, g.ringClones, g.ringClip) then ringUsed = idx end
            else
                local idx = used + 1
                if CloneTexture(g, idx, src) then used = idx end
            end
        end
    end
    for k = used + 1, #g.clones do g.clones[k]:Hide() end
    for k = ringUsed + 1, #g.ringClones do g.ringClones[k]:Hide() end
    used = used + ringUsed
    g.clonesUsed = used

    -- Fallback circular solo si no se pudo copiar nada
    local backdrop = frame.Portrait and frame.Portrait.backdrop
    local anchor = (not nativeRest and used == 0 and backdrop and backdrop:IsShown()) and backdrop or nil
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
    local resting = unitKey == "player" and IsResting and IsResting() and not UnitAffectingCombat("player")
    if unitKey == "player" and AG.debugRestUntil and GetTime and GetTime() < AG.debugRestUntil
        and not UnitAffectingCombat("player") then resting = true end
    local aggro = HasAggro(unitKey)
    if not (Enabled(resting) and (aggro or resting) and frame:IsShown()) then
        if g then
            for src, o in pairs(g.saved or {}) do pcall(src.SetVertexColor, src, o[1], o[2], o[3], o[4]) end
            g.saved, g.tinted = {}, {}
            g:Hide()
        end
        return
    end
    if not g then g = Build(frame); frame._kuiAggroGlow = g end
    g.resting = resting and not aggro or false
    g.color = aggro and { 1, 0.12, 0.12 } or { 1, 0.82, 0.15 }
    Layout(frame, g)
    local color = g.color
    if g.top.SetGradient and CreateColor then
        g.top:SetGradient("VERTICAL", CreateColor(color[1], color[2], color[3], 0.55), CreateColor(color[1], color[2], color[3], 0))
    else g.top:SetVertexColor(color[1], color[2], color[3], 0.3) end
    for _, ring in ipairs(g.rings) do ring:SetVertexColor(color[1], color[2], color[3], 1) end
    g:Show()
    if not g.pulse:IsPlaying() then g.pulse:Play() end
end

function AG:Update()
    UpdateUnit("player")
    UpdateUnit("target")
end

function KT.DebugUnitFrameGlowState(unit)
    local debug = KT.Portrait3DDebug
    if not debug then return {} end
    local frame = ns.frames and ns.frames[unit]
    local glow = frame and frame._kuiAggroGlow
    local lines = {
        "nativeRest atlas=" .. debug.Call(glow and glow.restGlow, "GetAtlas")
            .. " shown=" .. debug.Call(glow and glow.restGlow, "IsShown")
            .. " size=" .. debug.Call(glow and glow.restGlow, "GetSize")
            .. " error=" .. debug.Value(glow and glow.lastNativeRestError),
        "glow frameRegistered=" .. tostring(frame ~= nil)
            .. " resting=" .. debug.API(IsResting) .. " combat=" .. debug.API(UnitAffectingCombat, "player")
            .. " enabled=" .. tostring(Enabled(true)) .. " theme=" .. debug.Value(Theme()),
        "glow exists=" .. tostring(glow ~= nil) .. " shown=" .. debug.Call(glow, "IsShown")
            .. " visible=" .. debug.Call(glow, "IsVisible") .. " alpha=" .. debug.Call(glow, "GetAlpha")
            .. " effectiveAlpha=" .. debug.Call(glow, "GetEffectiveAlpha")
            .. " level=" .. debug.Call(glow, "GetFrameLevel") .. " strata=" .. debug.Call(glow, "GetFrameStrata"),
        "glow mode=" .. debug.Value(glow and glow.resting) .. " clonesUsed=" .. debug.Value(glow and glow.clonesUsed)
            .. " error=" .. debug.Value(glow and glow.lastCloneError),
        "glow clip left=" .. debug.Call(glow and glow.clip, "GetLeft")
            .. " right=" .. debug.Call(glow and glow.clip, "GetRight")
            .. " top=" .. debug.Call(glow and glow.clip, "GetTop")
            .. " bottom=" .. debug.Call(glow and glow.clip, "GetBottom"),
    }
    for _, key in ipairs({ "_ktForeverPortraitArt", "_ktClassicPortraitArt", "_kuiClassificationPortraitRing" }) do
        local art = frame and frame[key]
        lines[#lines + 1] = key .. " shown=" .. debug.Call(art, "IsShown")
            .. " visible=" .. debug.Call(art, "IsVisible") .. " texture=" .. debug.Call(art, "GetTexture")
            .. " atlas=" .. debug.Call(art, "GetAtlas") .. " coords=" .. debug.Call(art, "GetTexCoord")
    end
    for i, clone in ipairs(glow and glow.clones or {}) do
        lines[#lines + 1] = "glow clone " .. i .. " shown=" .. debug.Call(clone, "IsShown")
            .. " visible=" .. debug.Call(clone, "IsVisible") .. " texture=" .. debug.Call(clone, "GetTexture")
            .. " coords=" .. debug.Call(clone, "GetTexCoord") .. " blend=" .. debug.Call(clone, "GetBlendMode")
            .. " restMask=" .. tostring(clone._ktRestMaskAttached == true)
            .. " color=" .. debug.Call(clone, "GetVertexColor") .. " size=" .. debug.Call(clone, "GetSize")
    end
    return lines
end
function KT.DebugProbeRestedGlow()
    AG.debugRestUntil = GetTime() + 20
    AG:Update()
    C_Timer.After(20, function() AG:Update() end)
end
local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE", "UNIT_PET", "PLAYER_TARGET_CHANGED", "PLAYER_UPDATE_RESTING" }) do
    ev:RegisterEvent(e)
end
ev:SetScript("OnEvent", function() AG:Update() end)
local elapsed = 0
ev:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed < 0.5 then return end
    elapsed = 0
    AG:Update()
end)
