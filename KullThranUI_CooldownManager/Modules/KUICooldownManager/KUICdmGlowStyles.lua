--------------------------------------------------------------------------------
--  KUICdmGlowStyles.lua
--  Extra glow styles for the Cooldown Manager and Bar Glows (built only from
--  Blizzard art):
--    ants      Pixel Glow: short lines that travel around the icon's border.
--    button    Action Button Glow: the classic marching ants plus the soft
--              outer halo of the old action-button proc.
--    gcd       GCD: Blizzard's rotation-helper ants flipbook.
--    classic   Classic WoW Glow: the IconAlertAnts flipbook on its own.
--    blackout  Blackout: a solid fill of the glow colour over the icon.
--  On icons with a custom shape, Pixel Glow, Action Button Glow, GCD and
--  Classic WoW Glow run along the shape's own outline (see StartTrace).
--  The existing styles (blizzard, autocast, pixel, shape) stay in
--  KUICooldownManager.lua. StartNativeGlow calls CDMStartExtraGlow first and
--  _StopAllGlowsOnOverlay calls CDMStopExtraGlows.
--------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local floor, max, min = math.floor, math.max, math.min
local WHITE = "Interface\\Buttons\\WHITE8x8"
local ANTS_TEX = "Interface\\SpellActivationOverlay\\IconAlertAnts"
local ALERT_TEX = "Interface\\SpellActivationOverlay\\IconAlert"
local ALERT_HALO_COORDS = { 0.0078125, 0.5078125, 0.27734375, 0.52734375 } -- outer glow cell

-- Every style the dropdowns offer, in display order.
ns.CDM_GLOW_STYLE_LIST = {
    { id = "blizzard", label = "Proc Glow (WoW)" },
    { id = "button",   label = "Action Button Glow" },
    { id = "classic",  label = "Classic WoW Glow" },
    { id = "gcd",      label = "GCD" },
    { id = "autocast", label = "AutoCast Shine" },
    { id = "ants",     label = "Pixel Glow" },
    { id = "pixel",    label = "Pixel Border" },
    { id = "shape",    label = "Shape Glow" },
    { id = "blackout", label = "Blackout" },
    { id = "none",     label = "None" },
}

-- values/order for W:Dropdown. localize: LText or nil.
function ns.CDMGlowStyleDropdown(localize)
    local values, order = {}, {}
    for _, style in ipairs(ns.CDM_GLOW_STYLE_LIST) do
        values[style.id] = localize and localize(style.label) or style.label
        order[#order + 1] = style.id
    end
    return values, order
end

-- Flipbook definitions (Blizzard art facts: grid, frames, loop time, and how
-- much transparent padding each frame carries around the icon).
local FLIPBOOKS = {
    gcd = { atlas = "RotationHelper_Ants_Flipbook", rows = 6, columns = 5, frames = 30, duration = 1.0, padding = 1.6 },
    classic = { texture = ANTS_TEX, rows = 5, columns = 5, frames = 22, duration = 0.3,
        frameW = 48, frameH = 48, padding = 1.25 },
}
FLIPBOOKS.button = FLIPBOOKS.classic

-- Pixel Glow look.
local ANTS_LINES = 8
local ANTS_THICKNESS = 2
local ANTS_PERIOD = 4      -- seconds for one lap
local ANTS_OUTSET = 0      -- on the icon's own edge

local function HasAtlas(name)
    if not (C_Texture and C_Texture.GetAtlasInfo) then return true end
    local ok, info = pcall(C_Texture.GetAtlasInfo, name)
    return ok and info ~= nil
end

local function ShapeMask(target)
    local parent = target.GetParent and target:GetParent()
    return parent and parent._shapeMask or nil
end

local function SetMask(tex, mask)
    if tex._kuiMask == mask then return end
    if tex._kuiMask then pcall(tex.RemoveMaskTexture, tex, tex._kuiMask) end
    if mask then pcall(tex.AddMaskTexture, tex, mask) end
    tex._kuiMask = mask
end

-- One holder frame per target, right above it.
local function Holder(target)
    local holder = target._kuiExtraGlow
    if not holder then
        holder = CreateFrame("Frame", nil, target)
        holder:SetAllPoints(target)
        holder:EnableMouse(false)
        target._kuiExtraGlow = holder
    end
    local strata = target.GetFrameStrata and target:GetFrameStrata() or "MEDIUM"
    pcall(holder.SetFrameStrata, holder, strata)
    pcall(holder.SetFrameLevel, holder, (target:GetFrameLevel() or 0) + 4)
    holder:Show()
    return holder
end

-- ---------------------------------------------------------------------------
-- Pixel Glow
-- ---------------------------------------------------------------------------
-- Draws the stretch [a, b] of the perimeter (clockwise from the top-left
-- corner) with up to three pieces, one per edge it crosses.
local function PlaceSegment(frame, pieces, a, b, w, h, th)
    local P = 2 * (w + h)
    local used = 0
    local edges = {
        { 0, w }, { w, w + h }, { w + h, 2 * w + h }, { 2 * w + h, P },
    }
    local function Draw(edge, s, t)
        used = used + 1
        local tex = pieces[used]
        if not tex then return end
        tex:ClearAllPoints()
        local len = t - s
        if edge == 1 then
            tex:SetPoint("TOPLEFT", frame, "TOPLEFT", s, 0); tex:SetSize(len, th)
        elseif edge == 2 then
            tex:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -s); tex:SetSize(th, len)
        elseif edge == 3 then
            tex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -s, 0); tex:SetSize(len, th)
        else
            tex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, s); tex:SetSize(th, len)
        end
        tex:Show()
    end
    for pass = 0, 1 do
        local lo, hi = a - pass * P, b - pass * P
        for i, e in ipairs(edges) do
            local s, t = max(lo, e[1]), min(hi, e[2])
            if t - s > 0.01 then Draw(i, s - e[1], t - e[1]) end
        end
    end
    for i = used + 1, #pieces do pieces[i]:Hide() end
end

local function AntsOnUpdate(frame, elapsed)
    frame.phase = (frame.phase + elapsed / ANTS_PERIOD) % 1
    local w, h = frame:GetWidth(), frame:GetHeight()
    if not w or w < 2 or not h or h < 2 then return end
    local P = 2 * (w + h)
    local len = min(P / ANTS_LINES * 0.5, w, h)
    for i, pieces in ipairs(frame.lines) do
        local a = (frame.phase + (i - 1) / ANTS_LINES) * P
        PlaceSegment(frame, pieces, a % P, a % P + len, w, h, ANTS_THICKNESS)
    end
end

local function StartAnts(target, r, g, b)
    local holder = Holder(target)
    local frame = holder.ants
    if not frame then
        frame = CreateFrame("Frame", nil, holder)
        frame.lines = {}
        for i = 1, ANTS_LINES do
            local pieces = {}
            for j = 1, 3 do
                local tex = frame:CreateTexture(nil, "OVERLAY", nil, 7)
                tex:SetTexture(WHITE)
                pieces[j] = tex
            end
            frame.lines[i] = pieces
        end
        frame.phase = 0
        holder.ants = frame
    end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", target, "TOPLEFT", -ANTS_OUTSET, ANTS_OUTSET)
    frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", ANTS_OUTSET, -ANTS_OUTSET)
    for _, pieces in ipairs(frame.lines) do
        for _, tex in ipairs(pieces) do tex:SetVertexColor(r, g, b, 1) end
    end
    frame:SetScript("OnUpdate", AntsOnUpdate)
    frame:Show()
    AntsOnUpdate(frame, 0)
    return true
end

-- ---------------------------------------------------------------------------
-- Flipbooks (GCD, Classic WoW Glow, Action Button Glow)
-- ---------------------------------------------------------------------------
local function StartFlipbook(target, style, r, g, b)
    local def = FLIPBOOKS[style]
    if def.atlas and not HasAtlas(def.atlas) then return false end
    local holder = Holder(target)
    local fb = holder.flip
    if not fb then
        fb = {}
        fb.tex = holder:CreateTexture(nil, "OVERLAY", nil, 7)
        fb.tex:SetPoint("CENTER", holder, "CENTER")
        fb.group = fb.tex:CreateAnimationGroup()
        fb.group:SetLooping("REPEAT")
        fb.anim = fb.group:CreateAnimation("FlipBook")
        fb.halo = holder:CreateTexture(nil, "OVERLAY", nil, 6)
        fb.halo:SetTexture(ALERT_TEX)
        fb.halo:SetTexCoord(unpack(ALERT_HALO_COORDS))
        fb.halo:SetBlendMode("ADD")
        fb.halo:SetPoint("CENTER", holder, "CENTER")
        holder.flip = fb
    end
    local w = target:GetWidth() or 36
    local h = target:GetHeight() or w
    if w < 4 then w = 36 end
    if h < 4 then h = w end
    local tex = fb.tex
    tex:SetSize(w * def.padding, h * def.padding)
    if def.atlas then tex:SetAtlas(def.atlas) else tex:SetTexture(def.texture) end
    tex:SetBlendMode("ADD")
    tex:SetDesaturated(true)
    tex:SetVertexColor(r, g, b, 1)
    SetMask(tex, ShapeMask(target))
    fb.anim:SetFlipBookRows(def.rows)
    fb.anim:SetFlipBookColumns(def.columns)
    fb.anim:SetFlipBookFrames(def.frames)
    fb.anim:SetDuration(def.duration)
    fb.anim:SetFlipBookFrameWidth(def.frameW or 0)
    fb.anim:SetFlipBookFrameHeight(def.frameH or 0)
    tex:Show()
    if fb.group:IsPlaying() then fb.group:Stop() end
    fb.group:Play()

    -- Action Button Glow: the ants stay white, the halo carries the colour.
    if style == "button" then
        tex:SetDesaturated(false)
        tex:SetVertexColor(1, 1, 1, 1)
        fb.halo:SetSize(w * def.padding * 1.3, h * def.padding * 1.3)
        fb.halo:SetDesaturated(true)
        fb.halo:SetVertexColor(r, g, b, 1)
        fb.halo:Show()
    else
        fb.halo:Hide()
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Shape tracing: on icons with a custom shape (circle, hexagon, shield, ...)
-- the border-hugging styles follow the shape's own outline instead of the
-- square frame. A square texture of soft spokes (or comets) turns under a
-- mask made from the shape's border ring, so only the lit pieces that cross
-- the ring show: they run along any outline.
-- ---------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local TRACE = {
    ants    = { tex = MEDIA .. "GlowTraceAnts8.tga",   period = 4 },
    classic = { tex = MEDIA .. "GlowTraceAnts12.tga",  period = 1.2 },
    button  = { tex = MEDIA .. "GlowTraceAnts12.tga",  period = 1.2, halo = true },
    gcd     = { tex = MEDIA .. "GlowTraceComet2.tga",  period = 1.0 },
}

-- The icon that carries the shape: the target itself, its icon shortcuts, or
-- the same on its parent / grandparent (CDM overlays and Bar Glows overlays).
local function ShapedIcon(target)
    local frame = target
    for _ = 1, 3 do
        if not frame then return nil end
        for _, candidate in ipairs({ frame, frame.__KUIIcon, frame._icon }) do
            if candidate and candidate._shapeApplied and candidate._shapeName then
                return candidate
            end
        end
        frame = frame.GetParent and frame:GetParent()
    end
end

local function TraceOnUpdate(frame, elapsed)
    frame.angle = (frame.angle - elapsed * 6.2832 / frame.period) % 6.2832 -- clockwise
    frame.spokes:SetRotation(frame.angle)
end

local function StartTrace(target, style, r, g, b)
    local def = TRACE[style]
    local shapes = ns.CDM_SHAPES
    local icon = def and shapes and ShapedIcon(target)
    local borderPath = icon and shapes.borders and shapes.borders[icon._shapeName]
    if not borderPath then return false end

    local holder = Holder(target)
    local frame = holder.trace
    if not frame then
        frame = CreateFrame("Frame", nil, holder)
        frame:SetAllPoints(holder)
        frame.spokes = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        frame.spokes:SetBlendMode("ADD")
        frame.spokes:SetPoint("CENTER", frame, "CENTER")
        frame.ring = frame:CreateMaskTexture()
        frame.spokes:AddMaskTexture(frame.ring)
        frame.halo = frame:CreateTexture(nil, "OVERLAY", nil, 5)
        frame.halo:SetBlendMode("ADD")
        frame.angle = 0
        holder.trace = frame
    end
    frame.ring:SetTexture(borderPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    frame.ring:ClearAllPoints()
    frame.ring:SetAllPoints(icon)
    local w, h = icon:GetWidth() or 36, icon:GetHeight() or 36
    local side = math.max(w, h) * 1.5 -- covers the corners while it turns
    frame.spokes:SetTexture(def.tex)
    frame.spokes:SetSize(side, side)
    frame.spokes:ClearAllPoints()
    frame.spokes:SetPoint("CENTER", icon, "CENTER")
    frame.spokes:SetVertexColor(r, g, b, 1)
    frame.period = def.period

    local maskPath = shapes.masks and shapes.masks[icon._shapeName]
    if def.halo and maskPath then
        local extend = math.min(w, h) * 0.12
        frame.halo:SetTexture(maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        frame.halo:ClearAllPoints()
        frame.halo:SetPoint("TOPLEFT", icon, "TOPLEFT", -extend, extend)
        frame.halo:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", extend, -extend)
        frame.halo:SetVertexColor(r, g, b, 0.35)
        frame.halo:Show()
    else
        frame.halo:Hide()
    end
    frame:SetScript("OnUpdate", TraceOnUpdate)
    frame:Show()
    TraceOnUpdate(frame, 0)
    return true
end

-- ---------------------------------------------------------------------------
-- Blackout
-- ---------------------------------------------------------------------------
local function StartBlackout(target, r, g, b)
    local holder = Holder(target)
    local tex = holder.fill
    if not tex then
        tex = holder:CreateTexture(nil, "OVERLAY", nil, 7)
        tex:SetAllPoints(target)
        holder.fill = tex
    end
    tex:SetColorTexture(r, g, b, 1)
    SetMask(tex, ShapeMask(target))
    tex:Show()
    return true
end

-- ---------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------
-- Returns true when `style` is one of the styles above and it is now showing.
function ns.CDMStartExtraGlow(target, style, r, g, b)
    if not target then return false end
    r, g, b = r or 1, g or 0.82, b or 0.1
    local ok = false
    if TRACE[style] and StartTrace(target, style, r, g, b) then
        ok = true
    elseif style == "ants" then
        ok = StartAnts(target, r, g, b)
    elseif FLIPBOOKS[style] then
        ok = StartFlipbook(target, style, r, g, b)
    elseif style == "blackout" then
        ok = StartBlackout(target, r, g, b)
    else
        return false
    end
    if ok then target._kuiExtraGlowActive = style end
    return ok
end

function ns.CDMStopExtraGlows(target)
    local holder = target and target._kuiExtraGlow
    if not holder or not target._kuiExtraGlowActive then return end
    if holder.ants then
        holder.ants:SetScript("OnUpdate", nil)
        holder.ants:Hide()
    end
    if holder.flip then
        holder.flip.group:Stop()
        holder.flip.tex:Hide()
        holder.flip.halo:Hide()
    end
    if holder.fill then holder.fill:Hide() end
    if holder.trace then
        holder.trace:SetScript("OnUpdate", nil)
        holder.trace:Hide()
    end
    holder:Hide()
    target._kuiExtraGlowActive = nil
end
