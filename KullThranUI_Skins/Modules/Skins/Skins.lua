local addonName, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local S = KT:GetModule("Skins", true) or KT:NewModule("Skins", "AceEvent-3.0", "AceHook-3.0")

local _G = _G
local select, pairs, ipairs = select, pairs, ipairs
local type = type
local next = next
local CreateFrame = CreateFrame
local unpack = unpack or table.unpack
local GetPhysicalScreenSize = GetPhysicalScreenSize
local UIParent = UIParent
local hooksecurefunc = hooksecurefunc
local math_max = math.max
local tinsert = table.insert
local string_lower = string.lower
local string_find = string.find
local string_format = string.format
local geterrorhandler = geterrorhandler
local C_AddOns = C_AddOns
local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

S.SkinFuncs = {}
S.allowBypass = S.allowBypass or {}
S.addonsToLoad = S.addonsToLoad or {}
S.nonAddonsToLoad = S.nonAddonsToLoad or {}
S.loadedSkinCallbacks = S.loadedSkinCallbacks or {}
S.failedSkinCallbacks = S.failedSkinCallbacks or {}

-- ============================================================================
-- FRAME DATA & DEBOUNCE (ANTI-TAINT)
-- ============================================================================
local FFD = setmetatable({}, { __mode = "k" })
function S:GetFFD(frame)
    local d = FFD[frame]
    if not d then d = {}; FFD[frame] = d end
    return d
end

-- Bookkeeping stays outside Blizzard's frame tables. Native-art passes must
-- never fade or recolor the layers that implement the shared KUI surface.
function S:IsKuiSurfaceRegion(region)
    local data = region and FFD[region]
    return data and data.kuiSurfaceRegion == true or false
end

function S:FadeRegions(frame, keep)
    if not frame or frame:IsForbidden() then return end
    local regions = { frame:GetRegions() }
    for i = 1, #regions do
        local region = regions[i]
        if region.IsObjectType and region:IsObjectType("Texture")
            and not S:IsKuiSurfaceRegion(region) and not (keep and keep[region]) then
            region:SetAlpha(0)
        end
    end
    if frame.NineSlice then
        S:FadeRegions(frame.NineSlice, keep)
    end
end

function S:Debounce(func, wait)
    local timer
    return function(...)
        local args = { ... }
        if timer then timer:Cancel() end
        timer = C_Timer.NewTimer(wait or 0, function()
            func(unpack(args))
        end)
    end
end

-- ============================================================================
-- PREMIUM WINDOW STYLING
-- ============================================================================
function S:ContentShade(frame)
    if not frame or frame:IsForbidden() then return end
    if frame._ktContentShade then return end
    
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
    bg:SetColorTexture(0, 0, 0, 0.4)
    bg:SetAllPoints(frame)
    frame._ktContentShade = bg
end

function S:SkinPremiumWindow(frame)
    if not frame or frame:IsForbidden() then return end
    local d = S:GetFFD(frame)

    -- 1. Strip default art
    S:FadeRegions(frame)

    -- 2. Modern Dark Background (Textured Premium)
    if not d.modernBg then
        local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        bg:SetColorTexture(0.05, 0.05, 0.05, 0.98)
        bg:SetAllPoints(frame)
        d.modernBg = bg
    end

    -- 3. Modern accent border. Every Blizzard window using the shared
    -- portrait/premium helper must resolve its color through the dedicated
    -- Blizzard accent selector instead of retaining a fixed atlas tint.
    if not d.atlasBorderFrame then
        local ov = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        ov:SetAllPoints(frame)
        ov:SetFrameLevel(frame:GetFrameLevel() + 6)
        ov:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = S.mult or 1 })
        d.atlasBorderFrame = ov
    end
    S:RegisterBlizzardWindowBorder(d.atlasBorderFrame, function(border, enabled, color)
        border:SetBackdropBorderColor(color[1], color[2], color[3], color[4] or 1)
        border:SetAlpha(enabled and 1 or 0)
    end)
    S:RegisterBlizzardWindowBackground(d.modernBg, function(texture, color)
        texture:SetColorTexture(color[1], color[2], color[3], color[4])
    end)

    -- 4. KUI material (KT.Surface): tiled grain, vignette and the header sheen
    -- that replaces the old black top bar. The flat modernBg stays registered
    -- as the color source but is hidden by the surface callback.
    S:ApplyKuiSurface(frame)
    S:HandlePanelButtons(frame)
end

-- Neutral satin layer for windows that should preserve Blizzard artwork.
-- This intentionally uses only flat KUI surfaces: themed skins can gain depth
-- and a soft highlight without inheriting the wood grain used by Great Vault.
function S:ApplySatinSurface(frame, options)
    if not frame or frame:IsForbidden() or not frame.CreateTexture then return end
    options = options or {}

    local d = S:GetFFD(frame)
    if not d.satinBase then
        d.satinBase = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        d.satinBase:SetTexture("Interface\\Buttons\\WHITE8x8")

        d.satinSheen = frame:CreateTexture(nil, "BORDER", nil, -8)
        d.satinSheen:SetTexture("Interface\\Buttons\\WHITE8x8")

        d.satinLowerShade = frame:CreateTexture(nil, "BORDER", nil, -8)
        d.satinLowerShade:SetTexture("Interface\\Buttons\\WHITE8x8")

        d.satinTopEdge = frame:CreateTexture(nil, "BORDER", nil, -7)
        d.satinTopEdge:SetTexture("Interface\\Buttons\\WHITE8x8")
    end

    local inset = options.inset or 0
    local innerHeight = math_max(1, frame:GetHeight() - (inset * 2))

    local base = d.satinBase
    base:ClearAllPoints()
    base:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    base:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    base:SetColorTexture(
        options.r or 0.045,
        options.g or 0.050,
        options.b or 0.060,
        0)
    base:Show()

    local sheen = d.satinSheen
    sheen:ClearAllPoints()
    sheen:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + 1, -(inset + 1))
    sheen:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(inset + 1), -(inset + 1))
    sheen:SetHeight(math_max(4, innerHeight * (options.sheenHeight or 0.34)))
    sheen:SetColorTexture(1, 1, 1, 0)
    sheen:Show()

    local lowerShade = d.satinLowerShade
    lowerShade:ClearAllPoints()
    lowerShade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset + 1, inset + 1)
    lowerShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset + 1), inset + 1)
    lowerShade:SetHeight(math_max(3, innerHeight * 0.22))
    lowerShade:SetColorTexture(0, 0, 0, 0)
    lowerShade:Show()

    local topEdge = d.satinTopEdge
    topEdge:ClearAllPoints()
    topEdge:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + 1, -(inset + 1))
    topEdge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(inset + 1), -(inset + 1))
    topEdge:SetHeight(1)
    topEdge:SetColorTexture(1, 1, 1, options.edgeAlpha or 0.13)
    topEdge:Show()
end

-- One darkening for every skinned window. The KUI material is the window's
-- darkness; Blizzard art kept over it is shown opaque at a single tone (one
-- step up for pressed states and page ribbons), and the satin layers add no
-- veil or sheen of their own. Per-window alphas used to make some windows
-- lighter than others, and the satin veil shared the material's sublevel.
-- Tones are 20% under the first unified values (0.25 / 0.36), matching the
-- material's Surface.tokens.darken.
S.NATIVE_ART = { tone = 0.20, accent = 0.288, desaturation = 0.25 }

function S:ToneNativeArt(texture, accent, preserveVisibility)
    if not texture or not texture.SetVertexColor or S:IsKuiSurfaceRegion(texture) then return end
    if texture.IsForbidden and texture:IsForbidden() then return end
    local art = S.NATIVE_ART
    if texture.SetDesaturation then
        pcall(texture.SetDesaturation, texture, art.desaturation)
    elseif texture.SetDesaturated then
        pcall(texture.SetDesaturated, texture, false)
    end
    local tone = accent and art.accent or art.tone
    texture:SetVertexColor(tone, tone, tone, 1)
    if texture.SetAlpha then texture:SetAlpha(1) end
    if not preserveVisibility and texture.Show then texture:Show() end
end

-- Blizzard's parchment and leather book pages under KUI's light text: dark and
-- slightly desaturated, so the text and the full-colour icons carry the contrast.
-- brightness overrides the page tone for art that sits on a page (ribbons).
function S:ShadeBookPage(texture, brightness)
    S:ToneNativeArt(texture, brightness ~= nil and brightness > S.NATIVE_ART.tone, true)
end

-- KUI material (KT.Surface) shared by every skinned Blizzard window.
-- opts:
--   level  - "window" (default), "inset" or "control"
--   header - false hides the header sheen on a window
--   flat   - object registered for the window background refresher
--            (defaults to the premium modernBg created by SkinPremiumWindow)
function S:ApplyKuiSurface(frame, opts)
    if not frame or frame:IsForbidden() or not frame.CreateTexture then return end
    opts = opts or {}
    local d = S:GetFFD(frame)
    d.kuiLevel = opts.level or d.kuiLevel or "window"
    if opts.header ~= nil then d.kuiHeader = opts.header end
    local tile, vignette, header = KT.Surface:Apply(frame, d.kuiLevel,
        { color = S:GetWindowBackgroundColor(false), header = d.kuiHeader })
    if not tile then return end
    -- kuiArtwork / kuiWash keep their names for the skins that read them.
    d.kuiArtwork, d.kuiWash, d.kuiHeaderTexture = tile, vignette, header
    for _, region in ipairs({ tile, vignette, header }) do
        S:GetFFD(region).kuiSurfaceRegion = true
    end

    local flat = opts.flat or d.modernBg
    if not flat then
        if not d.kuiFlat then
            d.kuiFlat = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
            d.kuiFlat:SetAllPoints(frame)
        end
        flat = d.kuiFlat
    end
    S:GetFFD(flat).kuiSurfaceRegion = true
    S:RegisterBlizzardWindowBackground(flat, function(surface, color)
        if surface.SetBackdropColor then
            -- Keep the frame and its border/children, hide only its flat fill.
            surface:SetBackdropColor(0, 0, 0, 0)
        elseif surface.SetAlpha and surface.IsObjectType and surface:IsObjectType("Texture") then
            surface:SetAlpha(0)
        end
        KT.Surface:Apply(frame, d.kuiLevel, { color = color, header = d.kuiHeader })
    end)
    d.kuiSurfaceApplied = true
    return d.kuiArtwork
end

function S:ContentShade(frame, p1, x1, y1, p2, x2, y2, alpha)
    if not frame or frame:IsForbidden() then return end
    local d = S:GetFFD(frame)
    if d.rightShade then return d.rightShade end
    local shade = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
    shade:SetColorTexture(0, 0, 0, alpha or 0.12)
    shade:SetPoint(p1 or "TOPLEFT", frame, p1 or "TOPLEFT", x1 or 0, y1 or 0)
    shade:SetPoint(p2 or "BOTTOMRIGHT", frame, p2 or "BOTTOMRIGHT", x2 or 0, y2 or 0)
    d.rightShade = shade
    return shade
end

-- ============================================================================
-- PALETA Y CONSTANTES GLOBALES
-- ============================================================================
local FONT_AVANT    = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local FONT_FALLBACK = "Fonts\\FRIZQT__.TTF"
local BLANK_TEX     = "Interface\\Buttons\\WHITE8x8"

local COLOR_TEXT           = { 1.00, 1.00, 1.00, 1.00 }
local COLOR_BG             = { 0.09, 0.09, 0.09, 0.97 }
local COLOR_BG_TRANS       = { 0.09, 0.09, 0.09, 0.82 }
local COLOR_THUMB          = { 0.30, 0.30, 0.30, 1.00 }
local COLOR_CHECK          = { 1.00, 0.76, 0.00, 1.00 }
local COLOR_CHECK_DIS      = { 0.45, 0.45, 0.45, 1.00 }
local COLOR_CLASSIC_YELLOW = { 1.00, 0.82, 0.00, 1.00 }

local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()

local DEFAULT_BLIZZARD_SKINS = {
    enable = true,
    showWindowBorders = true,
    gradientWindowBorders = true,
    windowBackgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.98 },
    auctionhouse = true,
    addonManager = true,
    friends = true,
    armory = true,
    bank = true,
    inspect = true,
    gamemenu = true,
    settings = true,
    housing = true,
    spellbook = true,
    achievement = true,
    alerts = true,
    lfg = true,
    guild = true,
    encounterjournal = true,
    quest = true,
    gossip = true,
    merchant = true,
    trade = true,
    mail = true,
    worldmap = true,
    professions = true,
    battlenet = true,
    collections = true,
    popups = true,
    timers = true,
    lossofcontrol = true,
    cooldownmanager = true,
    weeklyrewards = true,
    macro = true,
}

local PROTECTED_NAMES = {
    "uuf", "unhalted", "bcm", "bettercooldown", "memberdetail", "communitiesguildmember",
    "dropdownlist", "menumanager", "questoffer", "areapoi", "worldquest", "vignette",
    "storyline", "dungeonentrance", "bonusevent", "flightpoint", "gametooltip",
    "tooltipmoneyframe", "actionbutton", "multibar", "multibaraction", "bonusaction",
    "petaction", "stancebutton", "possess", "extrabutton", "zoneability", "vehicle",
    "overrideactionbar", "spellflyout", "mainmenubar", "overridebar", "quickkeybind",
}


-- ============================================================================
-- SEGURIDAD
-- ============================================================================
local function IsProtected(obj)
    if not obj then return false end
    if obj.IsProtected and obj:IsProtected() then return true end
    if obj.IsForbidden and obj:IsForbidden() then return true end

    local current = obj
    for i=1, 15 do
        if not current then break end
        if current.GetName then
            local name = current:GetName()
            if type(name) == "string" then
                name = string_lower(name)
                for _, pattern in ipairs(PROTECTED_NAMES) do
                    if string_find(name, pattern, 1, true) then return true end
                end
            end
        end
        current = current.GetParent and current:GetParent()
    end
    return false
end

-- ============================================================================
-- FUNCIONES NÚCLEO (Colores y Escalas)
-- ============================================================================
local function GetPixelScale()
    local _, height = GetPhysicalScreenSize()
    local scale = UIParent:GetScale()
    return 768 / height / scale
end
S.mult = GetPixelScale()

local resize = CreateFrame("Frame")
resize:RegisterEvent("UI_SCALE_CHANGED")
resize:RegisterEvent("DISPLAY_SIZE_CHANGED")
resize:SetScript("OnEvent", function() S.mult = GetPixelScale() end)

function S:GetBorderColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local border = palette and palette.border or nil
    if border then return { border.r, border.g, border.b, border.a or 1 } end

    local accent = palette and palette.accent or nil
    if accent then return { accent.r, accent.g, accent.b, 1 } end

    if KT.C_R and KT.C_G and KT.C_B then
        return { KT.C_R, KT.C_G, KT.C_B, 1 }
    end
    return { 0.8, 0.1, 0.1, 1 }
end

function S:ApplyBorderColor(backdrop)
    if not backdrop then return end
    backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor()))
end

function S:GetAccentColor()
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin
    if skin and skin.blizzard and skin.blizzard.classicYellowAccent then
        return { unpack(COLOR_CLASSIC_YELLOW) }
    end

    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local accent = palette and palette.accent or nil
    return {
        (accent and accent.r) or KT.C_R or 1,
        (accent and accent.g) or KT.C_G or 0,
        (accent and accent.b) or KT.C_B or 0.3333333333,
        1
    }
end

local BLIZZARD_ACCENT_REFRESHERS = setmetatable({}, { __mode = "k" })
local BLIZZARD_WINDOW_BORDER_REFRESHERS = setmetatable({}, { __mode = "k" })
local BLIZZARD_WINDOW_BACKGROUND_REFRESHERS = setmetatable({}, { __mode = "k" })

function S:RegisterBlizzardAccentRefresh(object, callback)
    if not object or type(callback) ~= "function" then return end
    local callbacks = BLIZZARD_ACCENT_REFRESHERS[object]
    if not callbacks then
        callbacks = {}
        BLIZZARD_ACCENT_REFRESHERS[object] = callbacks
    end
    for i = 1, #callbacks do
        if callbacks[i] == callback then return end
    end
    callbacks[#callbacks + 1] = callback
end

function S:RefreshBlizzardAccents()
    local color = self:GetAccentColor()
    for object, callbacks in pairs(BLIZZARD_ACCENT_REFRESHERS) do
        for _, callback in ipairs(callbacks) do
            pcall(callback, object, color)
        end
    end
end

function S:RefreshBlizzardTheme()
    self:RefreshBlizzardAccents()
    self:RefreshBlizzardWindowBorders()
end

function S:AreBlizzardWindowBordersEnabled()
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin
    local blizzard = skin and skin.blizzard
    return not blizzard or blizzard.showWindowBorders ~= false
end

function S:AreGradientWindowBordersEnabled()
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin
    local blizzard = skin and skin.blizzard
    return not blizzard or blizzard.gradientWindowBorders ~= false
end

-- Gradient window borders: each side melts from the border colour at both
-- corners to black in its middle. Two pieces per side (corner -> middle), on
-- top of the window's own border, which goes transparent while they show.
-- Works for the two shapes the skins register: a BackdropTemplate border
-- (its edge colour and size are read back) and a set of four edge textures.
local GRADIENT_PIECES = {
    -- side, corner point, middle point, orientation, corner at the max end
    { "top", "TOPLEFT", "TOP", "HORIZONTAL", false },
    { "top", "TOPRIGHT", "TOP", "HORIZONTAL", true },
    { "bottom", "BOTTOMLEFT", "BOTTOM", "HORIZONTAL", false },
    { "bottom", "BOTTOMRIGHT", "BOTTOM", "HORIZONTAL", true },
    { "left", "TOPLEFT", "LEFT", "VERTICAL", true },
    { "left", "BOTTOMLEFT", "LEFT", "VERTICAL", false },
    { "right", "TOPRIGHT", "RIGHT", "VERTICAL", true },
    { "right", "BOTTOMRIGHT", "RIGHT", "VERTICAL", false },
}

local function WindowBorderEdges(object)
    return object._ktEdges or object.KT_AccentEdges or object._ktModernBorder
end

local function PaintGradientPiece(texture, orientation, cornerAtMax, r, g, b, a)
    texture:SetColorTexture(1, 1, 1, 1)
    local corner = CreateColor and CreateColor(r, g, b, a)
    local middle = CreateColor and CreateColor(0, 0, 0, a)
    local ok = corner and texture.SetGradient and pcall(texture.SetGradient, texture, orientation,
        cornerAtMax and middle or corner, cornerAtMax and corner or middle)
    if not ok and texture.SetGradientAlpha then
        if cornerAtMax then
            texture:SetGradientAlpha(orientation, 0, 0, 0, a, r, g, b, a)
        else
            texture:SetGradientAlpha(orientation, r, g, b, a, 0, 0, 0, a)
        end
    end
end

function S:ApplyWindowGradientBorder(object, enabled, color)
    if type(object) ~= "table" or not object.CreateTexture then return end
    if object.IsForbidden and object:IsForbidden() then return end

    local edges = WindowBorderEdges(object)
    local backdrop = object.GetBackdrop and object:GetBackdrop()
    local size, source, host
    if backdrop and backdrop.edgeFile and object.GetBackdropBorderColor then
        size = backdrop.edgeSize or S.mult or 1
        local r, g, b, a = object:GetBackdropBorderColor()
        -- Read the colour the skin just set; once hidden it reads back as 0.
        if a and a > 0 then object._ktGradientSource = { r, g, b, a } end
        source = object._ktGradientSource or color
        host = object
    elseif type(edges) == "table" then
        local top = edges[1] or edges.top
        size = top and top.GetHeight and top:GetHeight() or 1
        if not size or size <= 0 then size = S.mult or 1 end
        source = color
        host = top and top.GetParent and top:GetParent() or object
    else
        return
    end

    local useGradient = self:AreGradientWindowBordersEnabled()
    local pieces = object._ktGradientPieces
    if not pieces then
        if not useGradient then return end
        pieces = {}
        for index in ipairs(GRADIENT_PIECES) do
            pieces[index] = host:CreateTexture(nil, "OVERLAY", nil, 7)
        end
        object._ktGradientPieces = pieces
    end

    -- Size every piece from its corner to the middle of its side.
    for index, spec in ipairs(GRADIENT_PIECES) do
        local piece = pieces[index]
        piece:ClearAllPoints()
        piece:SetPoint(spec[2], object, spec[2], 0, 0)
        if spec[4] == "HORIZONTAL" then
            local down = spec[1] == "top" and -size or size
            piece:SetPoint(spec[2] == "TOPLEFT" and "BOTTOMRIGHT" or spec[2] == "TOPRIGHT" and "BOTTOMLEFT"
                or spec[2] == "BOTTOMLEFT" and "TOPRIGHT" or "TOPLEFT", object, spec[3], 0, down)
        else
            local inward = spec[1] == "left" and size or -size
            piece:SetPoint(spec[2] == "TOPLEFT" and "BOTTOMRIGHT" or spec[2] == "BOTTOMLEFT" and "TOPRIGHT"
                or spec[2] == "TOPRIGHT" and "BOTTOMLEFT" or "TOPLEFT", object, spec[3], inward, 0)
        end
    end

    local show = useGradient and enabled ~= false
    local r, g, b, a = source[1] or 1, source[2] or 0, source[3] or 0.333, source[4] or 1
    for index, spec in ipairs(GRADIENT_PIECES) do
        local piece = pieces[index]
        PaintGradientPiece(piece, spec[4], spec[5], r, g, b, a)
        piece:SetShown(show)
    end

    -- The flat border stays only when the gradient is off.
    if useGradient then
        if host == object and backdrop then
            object:SetBackdropBorderColor(r, g, b, 0)
        elseif type(edges) == "table" then
            for _, edge in pairs(edges) do
                if edge.SetAlpha then edge:SetAlpha(0) end
            end
        end
    end
end

function S:RegisterBlizzardWindowBorder(object, callback)
    if not (object and type(callback) == "function") then return end
    BLIZZARD_WINDOW_BORDER_REFRESHERS[object] = callback
    local enabled, color = self:AreBlizzardWindowBordersEnabled(), self:GetAccentColor()
    pcall(callback, object, enabled, color)
    pcall(self.ApplyWindowGradientBorder, self, object, enabled, color)
end

-- Repaint one registered border (its own callback, then the gradient). Skins
-- that restyle a window on every show call this instead of recolouring the
-- edges themselves, which would paint the flat border over the gradient.
function S:RefreshBlizzardWindowBorder(object)
    local callback = object and BLIZZARD_WINDOW_BORDER_REFRESHERS[object]
    if not callback then return end
    local enabled, color = self:AreBlizzardWindowBordersEnabled(), self:GetAccentColor()
    pcall(callback, object, enabled, color)
    pcall(self.ApplyWindowGradientBorder, self, object, enabled, color)
end

function S:RefreshBlizzardWindowBorders()
    local enabled = self:AreBlizzardWindowBordersEnabled()
    local color = self:GetAccentColor()
    for object, callback in pairs(BLIZZARD_WINDOW_BORDER_REFRESHERS) do
        pcall(callback, object, enabled, color)
        pcall(self.ApplyWindowGradientBorder, self, object, enabled, color)
    end
end

function S:GetWindowBackgroundColor(transparent)
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin
    local blizzard = skin and skin.blizzard
    local color = blizzard and blizzard.windowBackgroundColor
    local alpha = color and color.a
    if alpha == nil then
        alpha = transparent and COLOR_BG_TRANS[4] or 0.98
    elseif transparent then
        alpha = math.min(alpha, COLOR_BG_TRANS[4])
    end

    return {
        (color and color.r) or 0.05,
        (color and color.g) or 0.05,
        (color and color.b) or 0.05,
        alpha,
    }
end

function S:RegisterBlizzardWindowBackground(object, callback)
    if not object then return end
    -- Explicit window registrations (not generic control backdrops) also use
    -- the textured surface, including the minimal portrait shell.
    if not callback and object.SetBackdropColor and object.CreateTexture then
        self:ApplyKuiSurface(object, { flat = object })
        return
    end
    callback = callback or function(surface, color)
        if surface.SetBackdropColor then
            surface:SetBackdropColor(color[1], color[2], color[3], color[4])
        elseif surface.SetVertexColor then
            surface:SetVertexColor(color[1], color[2], color[3], color[4])
        end
    end
    BLIZZARD_WINDOW_BACKGROUND_REFRESHERS[object] = callback
    pcall(callback, object, self:GetWindowBackgroundColor(false))
end

function S:RefreshBlizzardWindowBackgrounds()
    local color = self:GetWindowBackgroundColor(false)
    for object, callback in pairs(BLIZZARD_WINDOW_BACKGROUND_REFRESHERS) do
        pcall(callback, object, color)
    end
end

function S:Kill(object)
    if not object or IsProtected(object) or object._ktKilled then return end

    local isTexture = object.IsObjectType and (
        object:IsObjectType("Texture") or object:IsObjectType("MaskTexture")
    )

    if isTexture and object.SetTexture then
        object:SetTexture(nil)
    elseif object.IsObjectType and object:IsObjectType("FontString") and object.SetText then
        object:SetText("")
    end

    if object.SetAlpha then
        object:SetAlpha(0)
    end
    if object.Hide then
        object:Hide()
    end
    if object.Show and not object._ktKillShowHooked then
        hooksecurefunc(object, "Show", function(self)
            if self.SetAlpha then
                self:SetAlpha(0)
            end
        end)
        object._ktKillShowHooked = true
    end

    object._ktKilled = true
end

function S:StripTextures(object, kill, deep)
    if not object or IsProtected(object) or S:IsKuiSurfaceRegion(object) then return end
    local success, isTexture = pcall(function() return object.IsObjectType and object:IsObjectType("Texture") end)
    if not success then return end
    if isTexture then if kill then S:Kill(object) else object:SetAlpha(0) end return end
    
    if object.GetNumRegions then
        for i = 1, object:GetNumRegions() do
            local region = select(i, object:GetRegions())
            if region and region.IsObjectType and not S:IsKuiSurfaceRegion(region) then
                if region:IsObjectType("Texture") then
                    if kill then S:Kill(region) else region:SetAlpha(0) end
                elseif region:IsObjectType("MaskTexture") then
                    if kill then
                        S:Kill(region)
                    elseif region.SetAlpha then
                        region:SetAlpha(0)
                    end
                end
            end
        end
    end

    local name = object.GetName and object:GetName()
    if name then
        for _, suffix in ipairs({"Left","Middle","Right","Mid","TopLeft","TopRight","BottomLeft","BottomRight"}) do
            local obj = _G[name .. suffix]
            if obj and obj.IsObjectType and obj:IsObjectType("Texture") then
                if kill then S:Kill(obj) else obj:SetAlpha(0) end
            end
        end
    end

    if object.NineSlice then
        if kill then
            S:Kill(object.NineSlice)
        elseif object.NineSlice.SetAlpha then
            object.NineSlice:SetAlpha(0)
        end
        S:StripTextures(object.NineSlice, kill)
    end
    
    if deep and object.GetChildren then
        for _, child in pairs({object:GetChildren()}) do
            if not IsProtected(child) then
                S:StripTextures(child, kill, false)
            end
        end
    end
end
function S:SetOutside(obj, anchor, offset)
    if not obj or not anchor then return end
    if IsProtected(obj) or IsProtected(anchor) then return end
    offset = offset or 0
    local mult = S.mult or 1
    if obj.ClearAllPoints then obj:ClearAllPoints() end
    obj:SetPoint("TOPLEFT", anchor, "TOPLEFT", -(offset + mult), (offset + mult))
    obj:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", (offset + mult), -(offset + mult))
end

function S:SetInside(obj, anchor, offset)
    if not obj or not anchor then return end
    if IsProtected(obj) or IsProtected(anchor) then return end
    offset = offset or 0
    local mult = S.mult or 1
    if obj.ClearAllPoints then obj:ClearAllPoints() end
    obj:SetPoint("TOPLEFT", anchor, "TOPLEFT", (offset + mult), -(offset + mult))
    obj:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", -(offset + mult), (offset + mult))
end

function S:HandleFont(obj)
    if not obj or IsProtected(obj) then return end
    local function ApplyFont(fs)
        if not (fs and fs.IsObjectType and fs:IsObjectType("FontString")) then return end
        local _, size = fs:GetFont()
        size = (size and size > 0) and size or 12
        if not fs:SetFont(FONT_AVANT, size, "OUTLINE") then
            fs:SetFont(FONT_FALLBACK, size, "OUTLINE")
        end
        fs:SetTextColor(unpack(COLOR_TEXT))
    end

    if obj.IsObjectType and obj:IsObjectType("FontString") then
        ApplyFont(obj)
        return
    end

    if obj.GetNumRegions then
        for i = 1, obj:GetNumRegions() do 
            ApplyFont(select(i, obj:GetRegions())) 
        end
    end
end

-- "Neutro" look shared by every handled control (chosen with the user): the
-- KT.Surface control face, a neutral 1 px border at rest and the accent when
-- hovered, pressed, selected or focused.
S.NEUTRO = {
    border = { 0.204, 0.196, 0.196 },
    text = { 0.886, 0.863, 0.831 },
    disabledText = { 0.55, 0.55, 0.60 },
}
local NEUTRO_ACTIVE_TEXT = { 1, 1, 1 }
local pressedButtons = setmetatable({}, { __mode = "k" })
local tabButtons = setmetatable({}, { __mode = "k" })
local raisedTabs = setmetatable({}, { __mode = "k" })

-- State paint for faces that are not Neutro buttons (scroll thumbs):
-- accent border when hovered or pressed.
local function UpdateNeutroFace(backdrop, state)
    if not backdrop then return end
    local border = (state == "hover" or state == "pressed") and S:GetAccentColor() or S.NEUTRO.border
    backdrop:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    if KT.Surface then KT.Surface:SetControlState(backdrop, state) end
end
local STATE_TEXTURE_GETTERS = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }

-- Blizzard re-textures some buttons when they enable or disable; keep its
-- state art invisible so only the material face shows.
local function HideStateTextures(button)
    for _, getter in ipairs(STATE_TEXTURE_GETTERS) do
        local texture = button[getter] and button[getter](button)
        if texture and texture.SetAlpha then texture:SetAlpha(0) end
    end
end

-- Tab border: a closed frame lit from the tab's outer edge. That edge is a solid
-- line in the tab's colour, both sides melt from it into black, and the top of
-- the sides and the edge facing the window stay black.
local TAB_SIDE_PIXELS, TAB_LINE_PIXELS = 1, 1
local TAB_SIDE_BLACK_PART = 0.25
local tabFadeBorders = setmetatable({}, { __mode = "k" })

-- Tabs at rest carry the accent too, dimmed so the selected one stands out.
function S:GetTabRestColor()
    local accent = S:GetAccentColor()
    return { accent[1] * 0.5, accent[2] * 0.5, accent[3] * 0.5 }
end

local function FitTabSideBlack(pieces, backdrop)
    local height = math_max(1, backdrop:GetHeight() * TAB_SIDE_BLACK_PART)
    pieces.blackLeft:SetHeight(height)
    pieces.blackRight:SetHeight(height)
end

function S:SetTabFadeBorder(tab, r, g, b, a)
    local backdrop = tab and tab.backdrop
    if not backdrop then return end
    tabButtons[tab] = true
    a = a or 1
    local onTop = tab.isTabOnTop
    local pieces = tabFadeBorders[tab]
    if not pieces then
        local outer, inner = onTop and "TOP" or "BOTTOM", onTop and "BOTTOM" or "TOP"
        pieces = {}
        local function Piece(key)
            local piece = backdrop:CreateTexture(nil, "OVERLAY", nil, 7)
            pieces[key] = piece
            return piece
        end
        local line = Piece("line")
        line:SetPoint(outer .. "LEFT")
        line:SetPoint(outer .. "RIGHT")
        local cap = Piece("cap")
        cap:SetPoint(inner .. "LEFT")
        cap:SetPoint(inner .. "RIGHT")
        for _, side in ipairs({ "Left", "Right" }) do
            local point = side:upper()
            local black = Piece("black" .. side)
            black:SetPoint(inner .. point)
            local fade = Piece("fade" .. side)
            fade:SetPoint(inner .. point, black, outer .. point)
            fade:SetPoint(outer .. point)
        end
        tabFadeBorders[tab] = pieces
        backdrop:HookScript("OnSizeChanged", function() FitTabSideBlack(pieces, backdrop) end)
    end
    backdrop:SetBackdropBorderColor(0, 0, 0, 0)
    -- Sized in physical pixels at this tab's own scale. S.mult only knows
    -- UIParent's, and in a scaled window a side could snap away.
    local _, physicalHeight = GetPhysicalScreenSize()
    local pixel = 768 / physicalHeight / backdrop:GetEffectiveScale()
    pieces.line:SetHeight(pixel * TAB_LINE_PIXELS)
    pieces.cap:SetHeight(pixel * TAB_SIDE_PIXELS)
    for _, key in ipairs({ "blackLeft", "blackRight", "fadeLeft", "fadeRight" }) do
        pieces[key]:SetWidth(pixel * TAB_SIDE_PIXELS)
    end
    FitTabSideBlack(pieces, backdrop)

    pieces.line:SetColorTexture(r, g, b, a)
    pieces.cap:SetColorTexture(0, 0, 0, a)
    pieces.blackLeft:SetColorTexture(0, 0, 0, a)
    pieces.blackRight:SetColorTexture(0, 0, 0, a)
    -- SetGradient takes the bottom colour first.
    local lit, dark = CreateColor(r, g, b, a), CreateColor(0, 0, 0, a)
    for _, fade in ipairs({ pieces.fadeLeft, pieces.fadeRight }) do
        fade:SetColorTexture(1, 1, 1, 1)
        fade:SetGradient("VERTICAL", onTop and dark or lit, onTop and lit or dark)
    end
end

local function UpdateNeutroButton(button)
    local backdrop = button and button.backdrop
    if not backdrop then return end
    HideStateTextures(button)
    local enabled = not (button.IsEnabled and not button:IsEnabled())
    -- Blizzard disables the selected tab: for tabs that means selected.
    local selectedTab = tabButtons[button] and not enabled
    local state = (selectedTab and "normal")
        or (not enabled and "disabled")
        or (pressedButtons[button] and "pressed")
        or (button.IsMouseOver and button:IsMouseOver() and "hover")
        or "normal"
    local active = button.KT_Selected or selectedTab or state == "hover" or state == "pressed"
    local border = active and S:GetAccentColor() or S.NEUTRO.border
    if tabButtons[button] then
        if not active then border = S:GetTabRestColor() end
        S:SetTabFadeBorder(button, border[1], border[2], border[3], 1)
        -- Neighbouring tabs share an edge: the accented one draws over the others.
        local raised = active and true or nil
        if raisedTabs[button] ~= raised then
            raisedTabs[button] = raised
            button:SetFrameLevel(button:GetFrameLevel() + (raised and 1 or -1))
        end
    else
        backdrop:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    end
    if KT.Surface then KT.Surface:SetControlState(backdrop, state) end
    local text = (state == "disabled" and S.NEUTRO.disabledText) or (active and NEUTRO_ACTIVE_TEXT) or S.NEUTRO.text
    local fontString = button.GetFontString and button:GetFontString()
    if not fontString and button.Text and button.Text.IsObjectType and button.Text:IsObjectType("FontString") then
        fontString = button.Text
    end
    if fontString and fontString.SetTextColor then fontString:SetTextColor(text[1], text[2], text[3], 1) end
end

-- Selected buttons (active tabs, chosen entries) keep the accent border.
function S:SetButtonActive(button, active)
    if not button then return end
    button.KT_Selected = active and true or nil
    UpdateNeutroButton(button)
end

-- UIPanelButtonTemplate draws its red face with these regions, not with the
-- state textures, and MagicButtonTemplate adds gold separators. Blizzard only
-- swaps their file on state changes, so alpha 0 lasts.
local BUTTON_ART_KEYS = {
    "Left", "Middle", "Right", "Center",
    "LeftDisabled", "MiddleDisabled", "RightDisabled",
    "LeftSeparator", "RightSeparator",
}

local function HideButtonArt(button)
    local name = button.GetName and button:GetName()
    for _, key in ipairs(BUTTON_ART_KEYS) do
        local texture = button[key] or (name and _G[name .. key])
        if texture and texture.IsObjectType and texture:IsObjectType("Texture") then
            texture:SetAlpha(0)
        end
    end
end

function S:HandleButton(button)
    if not button or button.isSkinned or IsProtected(button) then return end

    S:CreateBackdrop(button, true)
    if not button.backdrop then return end
    -- The material face replaces the flat fill.
    button.backdrop:SetBackdropColor(0, 0, 0, 0)
    if KT.Surface then KT.Surface:Apply(button.backdrop, "control") end
    HideButtonArt(button)

    S:HandleFont(button)

    button:HookScript("OnEnter", function(self) UpdateNeutroButton(self) end)
    button:HookScript("OnLeave", function(self) UpdateNeutroButton(self) end)
    button:HookScript("OnMouseDown", function(self)
        pressedButtons[self] = true
        UpdateNeutroButton(self)
    end)
    button:HookScript("OnMouseUp", function(self)
        pressedButtons[self] = nil
        UpdateNeutroButton(self)
    end)
    button:HookScript("OnEnable", function(self) UpdateNeutroButton(self) end)
    button:HookScript("OnDisable", function(self) UpdateNeutroButton(self) end)
    button:HookScript("OnHide", function(self) pressedButtons[self] = nil end)

    S:RegisterBlizzardAccentRefresh(button, function(self) UpdateNeutroButton(self) end)

    button.isSkinned = true
    UpdateNeutroButton(button)
end

-- Panel buttons the window code does not name: list rows, dialogs and buttons
-- created later. Identified by the template's own script, so tabs and column
-- headers with the same region names stay out.
local function IsPanelButton(frame)
    if not frame:IsObjectType("Button") then return false end
    local onDisable = frame:GetScript("OnDisable")
    return onDisable ~= nil and onDisable == _G.UIPanelButton_OnDisable
end

local function SweepPanelButtons(frame)
    for _, child in ipairs({ frame:GetChildren() }) do
        if not (child.IsForbidden and child:IsForbidden()) then
            if not child.isSkinned and IsPanelButton(child) then S:HandleButton(child) end
            SweepPanelButtons(child)
        end
    end
end

local sweptWindows = setmetatable({}, { __mode = "k" })

function S:HandlePanelButtons(frame)
    if not frame or frame:IsForbidden() then return end
    SweepPanelButtons(frame)
    if not sweptWindows[frame] then
        sweptWindows[frame] = true
        frame:HookScript("OnShow", SweepPanelButtons)
    end
end

function S:HandleCheckBox(checkbox)
    if not checkbox or checkbox.isSkinned or IsProtected(checkbox) then return end
    S:StripTextures(checkbox)
    S:CreateBackdrop(checkbox)
    if checkbox.backdrop then
        S:SetInside(checkbox.backdrop, checkbox, 4)
        checkbox.backdrop:SetBackdropColor(0, 0, 0, 0)
        if KT.Surface then KT.Surface:Apply(checkbox.backdrop, "control") end
    end

    if checkbox.SetCheckedTexture then
        checkbox:SetCheckedTexture(BLANK_TEX)
        local t = checkbox:GetCheckedTexture()
        if t then
            local color = S:GetAccentColor()
            t:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
            if checkbox.backdrop then S:SetInside(t, checkbox.backdrop, 3) end
        end
    end
    if checkbox.SetDisabledCheckedTexture then
        checkbox:SetDisabledCheckedTexture(BLANK_TEX)
        local t = checkbox:GetDisabledCheckedTexture()
        if t then
            t:SetVertexColor(unpack(COLOR_CHECK_DIS))
            if checkbox.backdrop then S:SetInside(t, checkbox.backdrop, 3) end
        end
    end

    -- Neutral border at rest, accent while hovered.
    local function Paint(self, hovered)
        if not self.backdrop then return end
        local c = hovered and S:GetAccentColor() or S.NEUTRO.border
        self.backdrop:SetBackdropBorderColor(c[1], c[2], c[3], 1)
        if KT.Surface then KT.Surface:SetControlState(self.backdrop, hovered and "hover" or "normal") end
    end
    Paint(checkbox, false)
    checkbox:HookScript("OnEnter", function(self) Paint(self, true) end)
    checkbox:HookScript("OnLeave", function(self) Paint(self, false) end)
    S:RegisterBlizzardAccentRefresh(checkbox, function(self, color)
        local checked = self.GetCheckedTexture and self:GetCheckedTexture()
        if checked then checked:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
        Paint(self, self.IsMouseOver and self:IsMouseOver())
    end)
    checkbox.isSkinned = true
end

function S:HandleStatusBar(frame)
    if not frame or frame.isSkinned or IsProtected(frame) then return end
    S:StripTextures(frame)
    S:CreateBackdrop(frame)
    if frame.SetStatusBarTexture then
        frame:SetStatusBarTexture(BLANK_TEX)
    end
    if frame.backdrop then
        S:SetOutside(frame.backdrop, frame)
    end
    frame.isSkinned = true
end

function S:HandleIcon(icon, createBackdrop)
    if not icon then return end
    if icon.GetParent and icon:GetParent() and IsProtected(icon:GetParent()) then return end
    
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    
    local parent = icon:GetParent()
    if parent and parent.GetNumRegions then
        for i = 1, parent:GetNumRegions() do
            local region = select(i, parent:GetRegions())
            if region and region ~= icon and region.IsObjectType and region:IsObjectType("MaskTexture") then
                region:Hide()
            end
        end
    end

    if createBackdrop and not icon.backdrop then
        local bd = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        bd:SetFrameLevel(parent:GetFrameLevel() or 1)
        S:SetOutside(bd, icon, 1)
        bd:SetBackdrop({ bgFile = BLANK_TEX, edgeFile = BLANK_TEX, edgeSize = S.mult or 1 })
        bd:SetBackdropColor(0, 0, 0, 0)
        bd:SetBackdropBorderColor(unpack(S:GetBorderColor()))
        icon.backdrop = bd

        icon:SetDrawLayer("OVERLAY", 7)
        icon:SetAlpha(1)
    end
end

local function KT_ApplyArrowTexture(texture)
    if not texture then return end
    texture:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    texture:SetTexCoord(0, 1, 0, 1)
    texture:SetVertexColor(1, 1, 1, 1)
end

do
    local function HoldNavButtonSpacing(button)
        local point, relativeTo, relativePoint, _, y = button:GetPoint()
        if point then
            button:SetPoint(point, relativeTo, relativePoint, button._ktNavSpacing or 4, y)
        end
        hooksecurefunc(button, "SetPoint", function(self, newPoint, anchor, relPoint, _, newY, skip)
            if skip or not self or self._ktAdjustingPoint or not newPoint then return end
            self._ktAdjustingPoint = true
            self:SetPoint(newPoint, anchor, relPoint, self._ktNavSpacing or 4, newY, true)
            self._ktAdjustingPoint = nil
        end)
    end

    function S:SkinNavBarButton(button, index)
        if not button or button._ktNavButtonSkinned then return end
        S:HandleButton(button)

        local faded = { "Left", "arrowUp", "arrowDown", "selected" }
        for i = 1, #faded do
            local part = button[faded[i]]
            if part and part.SetAlpha then
                part:SetAlpha(0)
            end
        end

        local text = button.GetFontString and button:GetFontString()
        if text then
            text:SetTextColor(1, 1, 1, 1)
        end

        local arrow = button.MenuArrowButton
        if arrow then
            S:StripTextures(arrow)
            local art = arrow.Art or arrow.Icon
            if art then
                KT_ApplyArrowTexture(art)
                if art.ClearAllPoints then
                    art:ClearAllPoints()
                    art:SetPoint("CENTER")
                end
                if art.SetSize then
                    art:SetSize(12, 12)
                end
            end
        end

        if index and index > 1 then
            HoldNavButtonSpacing(button)
        end
        button._ktNavButtonSkinned = true
    end

    function S:HandleNavBarButtons(data)
        local navList = self and self.navList
        if not navList then return end
        if data then
            local last = #navList
            S:SkinNavBarButton(navList[last], last)
        else
            for key, button in next, navList do
                S:SkinNavBarButton(button, key)
            end
        end
    end
end

local function KT_GetConfiguredBorderColor()
    return { 0, 0, 0, 1 }
end

local function KT_GetConfiguredAccentColor()
    if KT.db and KT.db.profile and KT.db.profile.skin and KT.db.profile.skin.blizzard
        and KT.db.profile.skin.blizzard.classicYellowAccent then
        return { unpack(COLOR_CLASSIC_YELLOW) }
    end

    if KT.db and KT.db.profile and KT.db.profile.skin and KT.db.profile.skin.accentColor then
        local c = KT.db.profile.skin.accentColor
        return { c.r or 1, c.g or 1, c.b or 1, c.a or 1 }
    end

    return KT_GetConfiguredBorderColor()
end

local function KT_GetConfiguredBackgroundColor(transparent)
    -- Internal controls use a stable Modern KUI neutral. The configurable
    -- Blizzard window fill is intentionally handled by its own registry.
    if transparent then
        return { unpack(COLOR_BG_TRANS) }
    end

    return { unpack(COLOR_BG) }
end
function S:GetBorderColor()
    return KT_GetConfiguredBorderColor()
end



function S:GetBackgroundColor(transparent)
    return KT_GetConfiguredBackgroundColor(transparent)
end

local function MakeFrameBackdrop(frame, transparent)
    if not frame or IsProtected(frame) then return end
    if not frame.IsObjectType or not frame:IsObjectType("Frame") or frame.backdrop then return end
    local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop:SetFrameLevel(math_max(1, frame:GetFrameLevel() - 1))
    S:SetOutside(backdrop, frame)
    backdrop:SetBackdrop({
        bgFile = BLANK_TEX,
        edgeFile = BLANK_TEX,
        edgeSize = S.mult or 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    backdrop:SetBackdropColor(unpack(S:GetBackgroundColor(transparent)))
    frame.backdrop = backdrop
    return backdrop
end

function S:CreateBackdrop(frame, transparent)
    local backdrop = MakeFrameBackdrop(frame, transparent)
    if backdrop then
        backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor()))
    end
end

function S:CreateFlatBackdrop(frame, transparent)
    local backdrop = MakeFrameBackdrop(frame, transparent)
    if backdrop then
        backdrop:SetBackdropBorderColor(0.09, 0.09, 0.09, 0)
    end
end

function S:HandleDropDownBox(frame, width)
    if not frame or frame.isSkinned or IsProtected(frame) then return end
    if width then frame:SetWidth(width) end
    S:StripTextures(frame, true)

    local frameName = frame.GetName and frame:GetName()
    local button = frame.Button or (frameName and _G[frameName.."Button"])
    local text = frame.Text or (frameName and _G[frameName.."Text"])

    if not text then
        for _, region in ipairs({frame:GetRegions()}) do
            if region:IsObjectType("FontString") then
                text = region
                break
            end
        end
    end

    if not frame.backdrop then
        S:CreateBackdrop(frame)
    end

    if frame.backdrop then
        frame.backdrop:SetFrameLevel(math_max(0, frame:GetFrameLevel() - 1))
        frame.backdrop:ClearAllPoints()
        frame.backdrop:SetBackdropColor(0, 0, 0, 0)
        if KT.Surface then KT.Surface:Apply(frame.backdrop, "inset") end
        local border = S.NEUTRO.border
        frame.backdrop:SetBackdropBorderColor(border[1], border[2], border[3], 1)

        if button then
            frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -2)
            frame.backdrop:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)

            button:ClearAllPoints()
            button:SetPoint("RIGHT", frame, "RIGHT", -10, 3)

            S:HandleButton(button)
            button:SetSize(16, 16)

            if not button._ktArrow then
                local arrow = button:CreateTexture(nil, "OVERLAY")
                KT_ApplyArrowTexture(arrow)
                arrow:SetSize(12, 12)
                S:SetInside(arrow, button)
                button._ktArrow = arrow
            end

            button:SetNormalTexture("")
            button:SetPushedTexture("")
            button:SetHighlightTexture("")
        else
            if frame.Arrow then frame.Arrow:SetAlpha(0) end

            frame.backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -2)
            frame.backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 2)

            if not frame._ktArrow then
                local arrow = frame:CreateTexture(nil, "ARTWORK")
                KT_ApplyArrowTexture(arrow)
                arrow:SetSize(14, 14)
                arrow:SetPoint("RIGHT", frame.backdrop, "RIGHT", -3, 0)
                frame._ktArrow = arrow
            end
        end
    end

    if text then
        S:HandleFont(text)
        text:SetDrawLayer("OVERLAY", 7)
        text:SetAlpha(1)
        text:SetTextColor(unpack(COLOR_TEXT))
    end

    -- Accent border while hovered.
    frame:HookScript("OnEnter", function(self)
        local c = S:GetAccentColor()
        if self.backdrop then self.backdrop:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
    end)
    frame:HookScript("OnLeave", function(self)
        local c = S.NEUTRO.border
        if self.backdrop then self.backdrop:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
    end)

    frame.isSkinned = true
end

-- Blizzard's tab art; hidden so the Neutro face draws the tab.
local TAB_ART_SUFFIXES = {
    "Left", "Middle", "Right", "Mid", "NormalTexture", "Background",
    "LeftDisabled", "MiddleDisabled", "RightDisabled",
    "LeftActive", "MiddleActive", "RightActive",
    "ActiveLeft", "ActiveMiddle", "ActiveRight",
    "SelectedLeft", "SelectedMiddle", "SelectedRight",
    "LeftHighlight", "MiddleHighlight", "RightHighlight",
    "DisabledTexture", "ActiveTexture", "SelectedTexture", "Selection",
}

-- Bottom tabs overlap their window by a couple of pixels, so the window's
-- border ran through them and hid their top edge. Start the face at the
-- window's lower edge. Tabs elsewhere keep their anchors.
local function FitTabBelowWindow(tab)
    local backdrop = tab.backdrop
    local top, bottom = tab:GetTop(), tab:GetBottom()
    if not (backdrop and top and bottom) then return end
    local scale = tab:GetEffectiveScale()
    local center = (top + bottom) / 2
    local parent = tab:GetParent()
    while parent and parent ~= UIParent do
        local parentBottom = parent:GetBottom()
        local edge = parentBottom and parentBottom * parent:GetEffectiveScale() / scale
        if edge and edge > center then
            local overlap = top - edge
            local mult = S.mult or 1
            if overlap >= -mult and overlap < 12 then
                backdrop:ClearAllPoints()
                backdrop:SetPoint("TOPLEFT", tab, "TOPLEFT", -mult, -overlap)
                backdrop:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", mult, -mult)
            end
            return
        end
        parent = parent:GetParent()
    end
end

function S:HandleTab(tab)
    if not tab or tab._ktTabSkinned or IsProtected(tab) then return end

    local tabName = tab.GetName and tab:GetName()
    local function HideTabArt()
        for _, suffix in ipairs(TAB_ART_SUFFIXES) do
            local texture = tab[suffix] or (tabName and _G[tabName .. suffix])
            if texture and texture.SetAlpha then texture:SetAlpha(0) end
        end
    end
    HideTabArt()

    tabButtons[tab] = true
    if tab.IsObjectType and tab:IsObjectType("Button") then
        S:HandleButton(tab)
    end
    -- TabSystem tabs report their selection here instead of disabling.
    if tab.SetTabSelected then
        hooksecurefunc(tab, "SetTabSelected", function(self, selected) S:SetButtonActive(self, selected) end)
        if tab.isSelected ~= nil then S:SetButtonActive(tab, tab.isSelected) end
    end

    tab._ktTabSkinned = true
    FitTabBelowWindow(tab)
    tab:HookScript("OnShow", function(self)
        HideTabArt()
        UpdateNeutroButton(self)
        FitTabBelowWindow(self)
        -- Anchors may only resolve once the window has been laid out.
        C_Timer.After(0, function() FitTabBelowWindow(self) end)
    end)
end

function S:HandleScrollBar(frame)
    if not frame or frame._ktScrollBarSkinned or IsProtected(frame) then return end
    if frame.Track then
        for _, layer in ipairs({"ARTWORK","BORDER","BACKGROUND","OVERLAY"}) do
            pcall(function() frame.Track:DisableDrawLayer(layer) end)
        end
        -- Inset track on the material.
        if not frame.Track.backdrop then S:CreateBackdrop(frame.Track) end
        if frame.Track.backdrop then
            frame.Track.backdrop:SetBackdropColor(0, 0, 0, 0)
            if KT.Surface then KT.Surface:Apply(frame.Track.backdrop, "inset") end
            local border = S.NEUTRO.border
            frame.Track.backdrop:SetBackdropBorderColor(border[1], border[2], border[3], 1)
        end
        local thumb = frame.Track.Thumb
        if thumb then
            for _, k in ipairs({"Begin","Middle","End"}) do
                if thumb[k] then thumb[k]:Hide() end
            end
            if not thumb.backdrop then
                S:CreateBackdrop(thumb)
                if thumb.backdrop then
                    thumb.backdrop:SetBackdropColor(0, 0, 0, 0)
                    thumb.backdrop:SetPoint("TOPLEFT", thumb, "TOPLEFT", 2, -2)
                    thumb.backdrop:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 2)
                    if KT.Surface then KT.Surface:Apply(thumb.backdrop, "control") end
                    UpdateNeutroFace(thumb.backdrop, "normal")
                    thumb:HookScript("OnEnter", function(self) UpdateNeutroFace(self.backdrop, "hover") end)
                    thumb:HookScript("OnLeave", function(self) UpdateNeutroFace(self.backdrop, "normal") end)
                    thumb:HookScript("OnMouseDown", function(self) UpdateNeutroFace(self.backdrop, "pressed") end)
                    thumb:HookScript("OnMouseUp", function(self)
                        UpdateNeutroFace(self.backdrop, self:IsMouseOver() and "hover" or "normal")
                    end)
                end
            end
        end
    elseif frame.ThumbTexture then
        S:StripTextures(frame)
        frame.ThumbTexture:SetTexture(BLANK_TEX)
        frame.ThumbTexture:SetVertexColor(unpack(COLOR_THUMB))
        frame.ThumbTexture:SetWidth(6)
    end
    frame._ktScrollBarSkinned = true
end

function S:HandleCloseButton(button)
    if not button or button._ktCloseSkinned or IsProtected(button) then return end
    S:StripTextures(button, true)

    if not button.backdrop then
        S:CreateBackdrop(button)
    end
    if button.backdrop then
        button.backdrop:SetPoint("TOPLEFT", button, "TOPLEFT", 5, -5)
        button.backdrop:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
        button.backdrop:SetBackdropColor(0, 0, 0, 0)
        if KT.Surface then KT.Surface:Apply(button.backdrop, "control") end
    end

    button:SetSize(18, 18)

    if not button._ktX then
        local fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetFont(FONT_AVANT, 14, "OUTLINE")
        fs:SetText("X")
        fs:SetPoint("CENTER", button.backdrop or button, "CENTER", 0, 1)
        button._ktX = fs
    end

    -- Current glyph; border and glyph take the accent while hovered.
    local function Paint(self, hovered)
        local border = hovered and S:GetAccentColor() or S.NEUTRO.border
        local glyph = hovered and S:GetAccentColor() or S.NEUTRO.text
        if self.backdrop then
            self.backdrop:SetBackdropBorderColor(border[1], border[2], border[3], 1)
            if KT.Surface then KT.Surface:SetControlState(self.backdrop, hovered and "hover" or "normal") end
        end
        if self._ktX then self._ktX:SetTextColor(glyph[1], glyph[2], glyph[3], 1) end
    end
    Paint(button, false)
    button:HookScript("OnEnter", function(self) Paint(self, true) end)
    button:HookScript("OnLeave", function(self) Paint(self, false) end)
    button._ktCloseSkinned = true
end

function S:HandleEditBox(box)
    if not box or box._ktEditBoxSkinned or IsProtected(box) then return end
    S:StripTextures(box)
    S:CreateBackdrop(box)
    S:HandleFont(box)
    if box.backdrop then
        S:SetOutside(box.backdrop, box, 0)
        box.backdrop:SetBackdropColor(0, 0, 0, 0)
        if KT.Surface then KT.Surface:Apply(box.backdrop, "inset") end
        local border = S.NEUTRO.border
        box.backdrop:SetBackdropBorderColor(border[1], border[2], border[3], 1)
    end

    local editBox = box
    if not box:IsObjectType("EditBox") and box.EditBox then
        editBox = box.EditBox
    end

    -- Make the typed text legible on the dark KUI backdrop. EditBoxes hold their
    -- own font/text separately from any FontString regions, so HandleFont() alone
    -- left them on Blizzard's default grey -- hard to read. Force a bright white
    -- with an outline, keeping the caret spacing below.
    if editBox then
        if editBox.GetFontString then
            local fs = editBox:GetFontString()
            if fs then
                local _, size = fs:GetFont()
                size = (size and size > 0) and size or 14
                if not fs:SetFont(FONT_AVANT, size, "OUTLINE") then
                    fs:SetFont(FONT_FALLBACK, size, "OUTLINE")
                end
            end
        end
        if editBox.SetFont then
            local _, size = editBox:GetFont()
            size = (size and size > 0) and size or 14
            if not editBox:SetFont(FONT_AVANT, size, "OUTLINE") then
                editBox:SetFont(FONT_FALLBACK, size, "OUTLINE")
            end
        end
        if editBox.SetTextColor then
            editBox:SetTextColor(COLOR_TEXT[1], COLOR_TEXT[2], COLOR_TEXT[3], COLOR_TEXT[4])
        end
        -- Caret and select highlight stay visible on the dark backdrop.
        if editBox.SetCursorColor then editBox:SetCursorColor(1, 1, 1, 1) end
        if editBox.SetHighlightColor then editBox:SetHighlightColor(0.32, 0.34, 0.45, 1) end
    end

    if editBox and editBox.HookScript then
        -- A little glyph spacing keeps the blinking caret visually separate
        -- from the last character with the Modern KUI font.
        if editBox.SetSpacing then editBox:SetSpacing(1) end
        editBox:HookScript("OnEditFocusGained", function()
            local c = S:GetAccentColor()
            if box.backdrop then box.backdrop:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
        end)
        editBox:HookScript("OnEditFocusLost", function()
            local c = S.NEUTRO.border
            if box.backdrop then box.backdrop:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
        end)
    end
    box._ktEditBoxSkinned = true
end

function S:HandlePortraitFrame(frame)
    if not frame or frame._ktPortraitSkinned or IsProtected(frame) then return end
    S:SkinPremiumWindow(frame)
    if frame.PortraitContainer then frame.PortraitContainer:SetAlpha(0) end
    if frame.CloseButton then
        S:HandleCloseButton(frame.CloseButton)
    end
    if frame.TitleText then S:HandleFont(frame.TitleText) end
    frame._ktPortraitSkinned = true
end

function S:HandleMinimalPortraitFrame(frame)
    if not frame or frame._ktMinimalPortraitSkinned or IsProtected(frame) then return end
    
    S:StripTextures(frame)
    S:CreateFlatBackdrop(frame, true)
    
    if frame.backdrop then
        S:RegisterBlizzardWindowBackground(frame.backdrop)
        frame.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
    end
    
    if frame.PortraitContainer then frame.PortraitContainer:SetAlpha(0) end
    if frame.Portrait then frame.Portrait:SetAlpha(0) end
    if frame.PortraitOverlay then frame.PortraitOverlay:SetAlpha(0) end
    if frame.Bg then frame.Bg:Hide() end
    if frame.TitleBg then frame.TitleBg:Hide() end
    if frame.CloseButton then
        S:HandleCloseButton(frame.CloseButton)
    end
    if frame.TitleText then S:HandleFont(frame.TitleText) end
    S:HandlePanelButtons(frame)
    frame._ktMinimalPortraitSkinned = true
end

-- ============================================================================
-- INICIALIZACIÓN
-- ============================================================================
local function BuildSkinCallbackId(addonName, callbackName, func)
    local name = callbackName or tostring(func)
    return string_format("%s::%s", tostring(addonName or "KullThranUI_Skins"), tostring(name))
end

local function InsertCallback(target, entry, position)
    for _, existing in ipairs(target) do
        if existing.id == entry.id then
            return
        end
    end

    if position then
        tinsert(target, position, entry)
    else
        tinsert(target, entry)
    end
end

function S:RunSkinCallback(addonName, callbackName, func)
    if type(func) ~= "function" then
        return false
    end

    local ok, err = pcall(func)
    local callbackId = BuildSkinCallbackId(addonName, callbackName, func)

    if ok then
        self.loadedSkinCallbacks[callbackId] = true
        self.failedSkinCallbacks[callbackId] = nil
        return true
    end

    self.failedSkinCallbacks[callbackId] = err

    local handler = geterrorhandler and geterrorhandler()
    if handler then
        handler(string_format("KUI Skins: error while loading '%s' for '%s': %s", tostring(callbackName or addonName), tostring(addonName), tostring(err)))
    end

    return false
end

function S:RegisterSkin(addonName, func, forceLoad, bypass, position, callbackName)
    if type(func) ~= "function" then return end

    if bypass then
        self.allowBypass[addonName] = true
    end

    local entry = {
        id = BuildSkinCallbackId(addonName, callbackName, func),
        name = callbackName or addonName,
        func = func,
    }

    if self.loadedSkinCallbacks[entry.id] then
        return
    end

    if forceLoad then
        self:RunSkinCallback(addonName, entry.name, func)
        return
    end

    if addonName == "KullThranUI" or addonName == "KullThranUI_Skins" then
        InsertCallback(self.nonAddonsToLoad, entry, position)
        return
    end

    local addonCallbacks = self.addonsToLoad[addonName]
    if not addonCallbacks then
        addonCallbacks = {}
        self.addonsToLoad[addonName] = addonCallbacks
    end

    InsertCallback(addonCallbacks, entry, position)
end

function S:AddCallbackForAddon(addonName, name, func, forceLoad, bypass, position)
    local callbackName, callback = addonName, func
    if type(name) == "string" then
        callbackName = name
    elseif type(name) == "function" then
        callback = name
    end
    S:RegisterSkin(addonName, callback, forceLoad, bypass, position, callbackName)
end

function S:AddCallback(name, func, position)
    local callbackName, callback = "KullThranUI_Skins", func
    if type(name) == "string" then
        callbackName = name
    elseif type(name) == "function" then
        callback = name
    end
    S:RegisterSkin("KullThranUI_Skins", callback, nil, nil, position, callbackName)
end

function S:CallLoadedAddon(addonName, callbacks)
    if not callbacks then return end

    local remaining
    for _, entry in ipairs(callbacks) do
        if not self.loadedSkinCallbacks[entry.id] then
            local ok = self:RunSkinCallback(addonName, entry.name, entry.func)
            if not ok then
                remaining = remaining or {}
                tinsert(remaining, entry)
            end
        end
    end

    self.addonsToLoad[addonName] = remaining
end

function S:AdoptLegacySkinFuncs()
    local legacy = S.SkinFuncs
    for addon, func in pairs(legacy) do
        S:RegisterSkin(addon, func, nil, nil, nil, addon)
        legacy[addon] = nil
    end
end

function S:FlushPendingSkins()
    if not self.db or not self.db.enable then return end

    for index, entry in next, self.nonAddonsToLoad do
        if entry and not self.loadedSkinCallbacks[entry.id] then
            self:RunSkinCallback("KullThranUI_Skins", entry.name, entry.func)
        end
        self.nonAddonsToLoad[index] = nil
    end

    for addonName, callbacks in pairs(self.addonsToLoad) do
        if IsAddOnLoaded and IsAddOnLoaded(addonName) then
            self:CallLoadedAddon(addonName, callbacks)
        end
    end
end

function S:OnEnable() 
    if not self.db.enable then return end 
    self:RegisterEvent("ADDON_LOADED")

    self.Initialized = true
    self:AdoptLegacySkinFuncs()
    self:FlushPendingSkins()
end

function S:ADDON_LOADED(_, addonName)
    if not (S.Initialized and S.db and S.db.enable) then return end
    local queued = S.addonsToLoad[addonName]
    if queued then
        S:CallLoadedAddon(addonName, queued)
    end
end

function S:OnInitialize()
    local skin = KT.db.profile.skin
    if not skin.blizzard then
        skin.blizzard = {}
    end

    -- Migrate the old top-level value. The option belongs exclusively to the
    -- Blizzard-frame reskins and must never participate in KUI's main palette.
    if skin.classicYellowAccent == true then
        skin.blizzard.classicYellowAccent = true
        skin.classicYellowAccent = nil
    end

    for key, value in pairs(DEFAULT_BLIZZARD_SKINS) do
        if skin.blizzard[key] == nil then
            if type(value) == "table" then
                skin.blizzard[key] = { r = value.r, g = value.g, b = value.b, a = value.a }
            else
                skin.blizzard[key] = value
            end
        end
    end

    self.db = skin.blizzard
    self:SetEnabledState(skin.enable)
end

