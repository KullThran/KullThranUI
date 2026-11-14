-- Selection card shared by the Visual Theme cards and the Preset Colors grid.
-- WoW port of a "flip card" CSS:
--   * body #151515 with 5px rounded corners and a soft black drop shadow
--     (box-shadow: 0 0 10px 1px #000000ee);
--   * the border is a band of the card's accent rotating behind the body
--     (.back::before, linear-gradient band + rotation 5s linear infinite),
--     clipped to the card's rounded shape. It runs while the card is hovered
--     or in use; at rest the edge is a dim accent hairline;
--   * on hover, blurred accent circles float behind the content
--     (.circle, #bottom, #right + floating 2.6s). The CSS 3D flip has no
--     frame equivalent, so the circles carry the hover instead.
-- API: Style(card, { accent, inUse, fill }) -> { body }, SetHover, SetInUse.
local _, ns = ...
local KT = ns.KT
local BC = KT.BrutalCard or {}
KT.BrutalCard = BC

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local ROUND_TEX = MEDIA .. "CardRound.tga"        -- 32px rounded rect, 6px radius
local ROUND_MASK = MEDIA .. "CardRoundMask.tga"
local BAND_TEX = MEDIA .. "CardBand.tga"
local BLOB_TEX = MEDIA .. "CardBlob.tga"
local SHADOW_TEX = MEDIA .. "NavButtonGlow.tga"

local RADIUS = 5            -- border-radius: 5px
local INSET = 2             -- .back-content 99%: the band shows on this rim
local SHADOW = 10           -- box-shadow blur
local ROTATION_TIME = 5     -- rotation_481 5000ms
local FLOAT_TIME = 2.6      -- floating 2600ms
local BODY = { 0x15 / 255, 0x15 / 255, 0x15 / 255 }

-- 9-slice of CardRound.tga anchored to `owner`, so it follows any resize.
local function Rounded(owner, layer, sub)
    local c = 6 / 32
    local u = { 0, c, 1 - c, 1 }
    local parts = {}
    for row = 1, 3 do
        for col = 1, 3 do
            local t = owner:CreateTexture(nil, layer, nil, sub)
            t:SetTexture(ROUND_TEX)
            t:SetTexCoord(u[col], u[col + 1], u[row], u[row + 1])
            parts[#parts + 1] = t
        end
    end
    local tl, t, tr, l, m, r, bl, b, br = unpack(parts)
    tl:SetSize(RADIUS, RADIUS); tl:SetPoint("TOPLEFT", owner, "TOPLEFT")
    tr:SetSize(RADIUS, RADIUS); tr:SetPoint("TOPRIGHT", owner, "TOPRIGHT")
    bl:SetSize(RADIUS, RADIUS); bl:SetPoint("BOTTOMLEFT", owner, "BOTTOMLEFT")
    br:SetSize(RADIUS, RADIUS); br:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT")
    t:SetPoint("TOPLEFT", tl, "TOPRIGHT"); t:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    b:SetPoint("TOPLEFT", bl, "TOPRIGHT"); b:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    l:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); l:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    r:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); r:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    m:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT"); m:SetPoint("BOTTOMRIGHT", br, "TOPLEFT")
    return parts
end

local function Tint(parts, r, g, b, a)
    for _, t in ipairs(parts) do t:SetVertexColor(r, g, b, a or 1) end
end

-- Outer drop shadow: the glow 9-slice drawn outside the card, tinted black.
local function Shadow(card)
    local parts = {}
    for i = 1, 8 do
        local t = card:CreateTexture(nil, "BACKGROUND", nil, -8)
        t:SetTexture(SHADOW_TEX)
        t:SetVertexColor(0, 0, 0, 0.93)
        parts[i] = t
    end
    local tl, tr, bl, br, t, b, l, r = unpack(parts)
    tl:SetTexCoord(0, 0.5, 0, 0.5); tr:SetTexCoord(0.5, 1, 0, 0.5)
    bl:SetTexCoord(0, 0.5, 0.5, 1); br:SetTexCoord(0.5, 1, 0.5, 1)
    t:SetTexCoord(0.49, 0.51, 0, 0.5); b:SetTexCoord(0.49, 0.51, 0.5, 1)
    l:SetTexCoord(0, 0.5, 0.49, 0.51); r:SetTexCoord(0.5, 1, 0.49, 0.51)
    for _, corner in ipairs({ tl, tr, bl, br }) do corner:SetSize(SHADOW, SHADOW) end
    tl:SetPoint("BOTTOMRIGHT", card, "TOPLEFT"); tr:SetPoint("BOTTOMLEFT", card, "TOPRIGHT")
    bl:SetPoint("TOPRIGHT", card, "BOTTOMLEFT"); br:SetPoint("TOPLEFT", card, "BOTTOMRIGHT")
    t:SetPoint("BOTTOMLEFT", card, "TOPLEFT"); t:SetPoint("BOTTOMRIGHT", card, "TOPRIGHT"); t:SetHeight(SHADOW)
    b:SetPoint("TOPLEFT", card, "BOTTOMLEFT"); b:SetPoint("TOPRIGHT", card, "BOTTOMRIGHT"); b:SetHeight(SHADOW)
    l:SetPoint("TOPRIGHT", card, "TOPLEFT"); l:SetPoint("BOTTOMRIGHT", card, "BOTTOMLEFT"); l:SetWidth(SHADOW)
    r:SetPoint("TOPLEFT", card, "TOPRIGHT"); r:SetPoint("BOTTOMLEFT", card, "BOTTOMRIGHT"); r:SetWidth(SHADOW)
end

-- One floating blurred circle (.circle). size/x/y follow the CSS against a
-- 190x254 card and are scaled to the real card.
local function Blob(holder, size, x, y, delay)
    local tex = holder:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(BLOB_TEX)
    tex:SetBlendMode("ADD")
    local ag = tex:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local down = ag:CreateAnimation("Translation")
    down:SetOffset(0, -10)
    down:SetDuration(FLOAT_TIME / 2)
    down:SetSmoothing("IN_OUT")
    down:SetOrder(1)
    local up = ag:CreateAnimation("Translation")
    up:SetOffset(0, 10)
    up:SetDuration(FLOAT_TIME / 2)
    up:SetSmoothing("IN_OUT")
    up:SetOrder(2)
    return { tex = tex, anim = ag, size = size, x = x, y = y, delay = delay }
end

local function Layout(card)
    local v = card._ktBrutal
    local w, h = card:GetWidth(), card:GetHeight()
    if not (v and w and h and w > 0 and h > 0) then return end
    -- .back::before: 160px wide on a 190px card, 160% of its height.
    v.band:SetSize(math.max(24, w * 0.84), h * 1.6)
    local k = math.min(w / 190, h / 254)
    for _, blob in ipairs(v.blobs) do
        local s = math.max(12, blob.size * k)
        blob.tex:SetSize(s * 1.6, s * 1.6) -- the blur spreads past the circle
        blob.tex:ClearAllPoints()
        blob.tex:SetPoint("CENTER", v.blobHolder, "TOPLEFT", blob.x * w, -blob.y * h)
    end
end

local function Paint(card)
    local v = card._ktBrutal
    local r, g, b = v.accent[1], v.accent[2], v.accent[3]
    local running = v.hover or v.inUse
    Tint(v.rim, r, g, b, running and 0.55 or 0.28)
    v.band:SetVertexColor(r, g, b, 1)
    v.band:SetShown(running)
    if running then
        if not v.spin:IsPlaying() then v.spin:Play() end
    else
        v.spin:Stop()
    end
    -- #ffbb66 / #ff8866 / #ff2233 are a light, mid and deep shade of the
    -- CSS accent; each card uses the same three shades of its own accent.
    local shades = {
        { r + (1 - r) * 0.35, g + (1 - g) * 0.35, b + (1 - b) * 0.35 },
        { r, g, b },
        { r * 0.8, g * 0.35, b * 0.35 },
    }
    for i, blob in ipairs(v.blobs) do
        local c = shades[i]
        blob.tex:SetVertexColor(c[1], c[2], c[3], v.hover and 0.32 or 0)
        if v.hover then
            if not blob.anim:IsPlaying() then blob.anim:Play(false, blob.delay) end
        else
            blob.anim:Stop()
        end
    end
end

function BC.SetHover(card, on)
    local v = card and card._ktBrutal
    if not v then return end
    v.hover = on and true or false
    Paint(card)
end

function BC.SetInUse(card, on)
    local v = card and card._ktBrutal
    if not v then return end
    v.inUse = on and true or false
    Paint(card)
end

function BC.SetAccent(card, accent)
    local v = card and card._ktBrutal
    if not (v and accent) then return end
    v.accent = { accent[1] or accent.r or 1, accent[2] or accent.g or 1, accent[3] or accent.b or 1 }
    Paint(card)
end

function BC.Style(card, opts)
    opts = opts or {}
    if card._ktBrutal then return card._ktBrutal end
    local accent = opts.accent or { 1, 0.6, 0.4 }
    local v = {
        accent = { accent[1] or accent.r or 1, accent[2] or accent.g or 1, accent[3] or accent.b or 1 },
        inUse = opts.inUse and true or false,
        hover = false,
    }
    card._ktBrutal = v
    local level = card:GetFrameLevel()

    Shadow(card)
    v.rim = Rounded(card, "BACKGROUND", -6)

    -- The rotating band, clipped to the card and masked to its rounded shape.
    local bandClip = CreateFrame("Frame", nil, card)
    bandClip:SetAllPoints(card)
    bandClip:SetFrameLevel(level + 1)
    bandClip:SetClipsChildren(true)
    v.band = bandClip:CreateTexture(nil, "ARTWORK")
    v.band:SetTexture(BAND_TEX)
    v.band:SetPoint("CENTER", bandClip, "CENTER")
    local mask = bandClip:CreateMaskTexture()
    mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(bandClip)
    v.band:AddMaskTexture(mask)
    v.spin = v.band:CreateAnimationGroup()
    v.spin:SetLooping("REPEAT")
    local rotation = v.spin:CreateAnimation("Rotation")
    rotation:SetDegrees(-360)
    rotation:SetDuration(ROTATION_TIME)
    rotation:SetOrigin("CENTER", 0, 0)

    -- .back-content: the #151515 face over the band, with the hover circles.
    local face = CreateFrame("Frame", nil, card)
    face:SetPoint("TOPLEFT", card, "TOPLEFT", INSET, -INSET)
    face:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -INSET, INSET)
    face:SetFrameLevel(level + 2)
    face:SetClipsChildren(true)
    local fill = opts.fill or BODY
    Tint(Rounded(face, "BACKGROUND", 0), fill[1] or fill.r, fill[2] or fill.g, fill[3] or fill.b, 1)
    v.blobHolder = CreateFrame("Frame", nil, face)
    v.blobHolder:SetAllPoints(face)
    v.blobHolder:SetFrameLevel(level + 3)
    v.blobs = {
        Blob(v.blobHolder, 90, 0.30, 0.42, 0),      -- .circle
        Blob(v.blobHolder, 150, 0.62, 0.60, 0.8),   -- #bottom (left 50px, below)
        Blob(v.blobHolder, 30, 0.86, 0.20, 1.8),    -- #right
    }

    -- Content goes on `body`, above the face and its circles.
    v.body = CreateFrame("Frame", nil, card)
    v.body:SetAllPoints(face)
    v.body:SetFrameLevel(level + 4)

    card:HookScript("OnSizeChanged", Layout)
    Layout(card)
    Paint(card)
    return v
end
