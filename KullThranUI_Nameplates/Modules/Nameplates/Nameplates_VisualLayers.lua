-- Nameplates runtime, visual layers: answers what a plate needs for target adornments, and builds the glow, arrows and
-- focus stripes the first time each is asked for. Showing, hiding and recolouring stay in the main file.

local _, ns = ...

local module = {}
ns.NameplatesVisualLayers = module

local MEDIA = "Interface\\AddOns\\KullThranUI_Nameplates\\Modules\\Nameplates\\Media\\"
local GLOW_TEXTURE = MEDIA .. "background.png"
local ARROW_LEFT_TEXTURE = MEDIA .. "arrow_left.png"
local ARROW_RIGHT_TEXTURE = MEDIA .. "arrow_right.png"
local STRIPE_TEXTURE = MEDIA .. "striped-v2.png"

-- Texture coordinates of the glow's nine-slice edge.
local M = 0.48
local I = 1 - M

local ctx

-- The one descriptor. Every resolve rewrites all seven fields, so a resolve allocates nothing and a previous target
-- leaves nothing behind. Callers read it straight away, and must not keep it across another resolve.
local descriptor = {}

local function resolveTargetVisuals(_, unit)
    local isTarget = false
    if unit then
        isTarget = UnitIsUnit(unit, "target")
    end

    -- G2: a plain truth test on an answer that can be secret. Kept as specified.
    if isTarget then
        local style = ctx.GetTargetGlowStyle()
        local arrows = ns.GetShowTargetArrows()
        local db = ctx.GetDB()
        local scale = db and db.targetArrowScale or 1.0
        local indicator = ns.GetTargetIndicatorStyle()
        -- G1: reads the global, which a normal client leaves nil. Kept as specified.
        local classPower = ctx.GetShowClassPower()
        classPower = classPower and classPowerType ~= nil

        descriptor.isTarget = isTarget
        descriptor.glowNeeded = style ~= "none"
        descriptor.vibrantBorder = style == "vibrant"
        descriptor.arrowsNeeded = arrows
        descriptor.arrowScale = scale
        descriptor.indicatorStyle = indicator
        descriptor.classPowerNeeded = classPower
    else
        descriptor.isTarget = isTarget
        descriptor.glowNeeded = false
        descriptor.vibrantBorder = false
        descriptor.arrowsNeeded = false
        descriptor.arrowScale = 1.0
        descriptor.indicatorStyle = ctx.defaults.targetIndicatorStyle
        descriptor.classPowerNeeded = false
    end
    return descriptor
end

-- Build path only: one glow piece without its size and anchors.
local function newGlowPiece(host, r, g, b, left, right, top, bottom)
    local piece = host:CreateTexture(nil, "BACKGROUND")
    piece:SetTexture(GLOW_TEXTURE)
    piece:SetVertexColor(r, g, b, 1)
    piece:SetBlendMode("ADD")
    piece:SetTexCoord(left, right, top, bottom)
    return piece
end

local function buildGlow(plate)
    local health = plate.health
    local host = CreateFrame("Frame", nil, plate)
    host:SetFrameStrata("BACKGROUND")
    host:SetFrameLevel(1)
    host:SetPoint("TOPLEFT", health, "TOPLEFT", -6, 6)
    host:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 6, -6)

    -- One colour for all eight pieces: working profile, then defaults, never the saved global.
    local db = ctx.GetDB()
    local color = (db and db.targetGlowColor) or ctx.defaults.targetGlowColor or {}
    local r = color.r or color[1] or 0.4117
    local g = color.g or color[2] or 0.6667
    local b = color.b or color[3] or 1.0

    local topLeft = newGlowPiece(host, r, g, b, 0, M, 0, M)
    topLeft:SetSize(12, 12)
    topLeft:SetPoint("TOPLEFT")

    local topRight = newGlowPiece(host, r, g, b, I, 1, 0, M)
    topRight:SetSize(12, 12)
    topRight:SetPoint("TOPRIGHT")

    local bottomLeft = newGlowPiece(host, r, g, b, 0, M, I, 1)
    bottomLeft:SetSize(12, 12)
    bottomLeft:SetPoint("BOTTOMLEFT")

    local bottomRight = newGlowPiece(host, r, g, b, I, 1, I, 1)
    bottomRight:SetSize(12, 12)
    bottomRight:SetPoint("BOTTOMRIGHT")

    local top = newGlowPiece(host, r, g, b, M, I, 0, M)
    top:SetHeight(12)
    top:SetPoint("TOPLEFT", topLeft, "TOPRIGHT")
    top:SetPoint("TOPRIGHT", topRight, "TOPLEFT")

    local bottom = newGlowPiece(host, r, g, b, M, I, I, 1)
    bottom:SetHeight(12)
    bottom:SetPoint("BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")

    local left = newGlowPiece(host, r, g, b, 0, M, M, I)
    left:SetWidth(12)
    left:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT")
    left:SetPoint("BOTTOMLEFT", bottomLeft, "TOPLEFT")

    local right = newGlowPiece(host, r, g, b, I, 1, M, I)
    right:SetWidth(12)
    right:SetPoint("TOPRIGHT", topRight, "BOTTOMRIGHT")
    right:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")

    host._textures = { topLeft, topRight, bottomLeft, bottomRight, top, bottom, left, right }
    host:Hide()

    plate.glow = host
    plate.glowFrame = host
    return host
end

local function buildArrows(plate)
    local health = plate.health
    local PP = ctx.PP

    local left = plate:CreateTexture(nil, "OVERLAY")
    left:SetTexture(ARROW_LEFT_TEXTURE)
    PP.Size(left, 11, 16)
    PP.Point(left, "RIGHT", health, "LEFT", -8, 0)
    left:Hide()

    local right = plate:CreateTexture(nil, "OVERLAY")
    right:SetTexture(ARROW_RIGHT_TEXTURE)
    PP.Size(right, 11, 16)
    PP.Point(right, "LEFT", health, "RIGHT", 8, 0)
    right:Hide()

    plate.leftArrow = left
    plate.rightArrow = right
    return left, right
end

-- Build path only: one clip frame at the given level, without its anchors.
local function newFocusClip(health, level)
    local clip = CreateFrame("Frame", nil, health)
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(level)
    return clip
end

-- Build path only: one stripe, anchored to the bar so the two line up as the fill moves. G3: fixed size, kept.
local function newFocusStripe(clip, health, sublevel, alpha, color)
    local stripe = clip:CreateTexture(nil, "ARTWORK", nil, sublevel)
    stripe:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
    stripe:SetSize(200, 24)
    stripe:SetTexture(STRIPE_TEXTURE)
    stripe:SetAlpha(alpha)
    stripe:SetVertexColor(color.r, color.g, color.b)
    return stripe
end

local function buildFocus(plate)
    local health = plate.health
    local fill = health:GetStatusBarTexture()
    local level = health:GetFrameLevel() + 1

    -- Saved global, then defaults, never the working profile (G4).
    local saved = KullThranUINameplatesDB
    local defaults = ctx.defaults
    local alpha = saved and saved.focusOverlayAlpha or defaults.focusOverlayAlpha
    local color = saved and saved.focusOverlayColor or defaults.focusOverlayColor

    -- Fill's clip first: the two share a level.
    local clipFill = newFocusClip(health, level)
    clipFill:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, -1)
    clipFill:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, 1)
    local overlayFill = newFocusStripe(clipFill, health, 2, alpha, color)
    clipFill:Hide()

    local clipBg = newFocusClip(health, level)
    clipBg:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, -1)
    clipBg:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 1)
    local overlayBg = newFocusStripe(clipBg, health, 1, alpha * 0.3, color)
    clipBg:Hide()

    plate.focusClipFill = clipFill
    plate.focusClipBg = clipBg
    plate.focusOverlayFill = overlayFill
    plate.focusOverlayBg = overlayBg
end

-- Built-once fields decide. A built layer returns here, with no further call.
local function acquireVisualLayer(plate, layerName)
    if layerName == "glow" then
        local host = plate.glow
        if host then return host end
        return buildGlow(plate)
    elseif layerName == "arrows" then
        local left = plate.leftArrow
        if left then return left, plate.rightArrow end
        return buildArrows(plate)
    elseif layerName == "focus" then
        if not plate.focusClipFill then buildFocus(plate) end
        return true
    end
end

function module.Setup(setupCtx)
    if type(setupCtx) ~= "table" then
        error("NameplatesVisualLayers.Setup: ctx required", 2)
    end
    if setupCtx.client ~= "retail" and setupCtx.client ~= "forever" then
        error("NameplatesVisualLayers.Setup: client must be retail or forever", 2)
    end
    ctx = setupCtx
    ns._ResolveTargetVisuals = resolveTargetVisuals
    ns._AcquireVisualLayer = acquireVisualLayer
end
