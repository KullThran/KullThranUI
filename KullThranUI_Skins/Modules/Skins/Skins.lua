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
    for i = 1, select("#", frame:GetRegions()) do
        local r = select(i, frame:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture") and not S:IsKuiSurfaceRegion(r) and not (keep and keep[r]) then
            r:SetAlpha(0)
        end
    end
    if frame.NineSlice then self:FadeRegions(frame.NineSlice, keep) end
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

        local topBar = frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        topBar:SetColorTexture(0, 0, 0, 0.35)
        topBar:SetPoint("TOPLEFT")
        topBar:SetPoint("TOPRIGHT")
        topBar:SetHeight(25)
        d.topBar = topBar
        S:GetFFD(topBar).kuiSurfaceRegion = true
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

    -- 4. KUI artwork surface: same textured backdrop as the Options window,
    -- darkened by the wash. The flat modernBg stays registered as the color
    -- source but is hidden by the surface callback.
    S:ApplyKuiSurface(frame)
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
        options.baseAlpha or 0.28)
    base:Show()

    local sheen = d.satinSheen
    sheen:ClearAllPoints()
    sheen:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + 1, -(inset + 1))
    sheen:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(inset + 1), -(inset + 1))
    sheen:SetHeight(math_max(4, innerHeight * (options.sheenHeight or 0.34)))
    sheen:SetColorTexture(1, 1, 1, options.sheenAlpha or 0.055)
    sheen:Show()

    local lowerShade = d.satinLowerShade
    lowerShade:ClearAllPoints()
    lowerShade:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset + 1, inset + 1)
    lowerShade:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(inset + 1), inset + 1)
    lowerShade:SetHeight(math_max(3, innerHeight * 0.22))
    lowerShade:SetColorTexture(0, 0, 0, options.lowerAlpha or 0.09)
    lowerShade:Show()

    local topEdge = d.satinTopEdge
    topEdge:ClearAllPoints()
    topEdge:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + 1, -(inset + 1))
    topEdge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(inset + 1), -(inset + 1))
    topEdge:SetHeight(1)
    topEdge:SetColorTexture(1, 1, 1, options.edgeAlpha or 0.13)
    topEdge:Show()
end

-- KUI artwork surface used by the Options window (KUISettingsSurface.png plus a
-- dark wash). Reusable for other premium Blizzard shells so they share the same
-- textured backdrop instead of the flat modern background.
-- options:
--   washAlpha   - opacity of the dark wash (default 0.55)
--   flat        - object registered for the window background refresher
--                 (defaults to the premium modernBg created by SkinPremiumWindow)
function S:ApplyKuiSurface(frame, options)
    if not frame or frame:IsForbidden() or not frame.CreateTexture then return end
    options = options or {}
    local d = S:GetFFD(frame)
    if options.washAlpha ~= nil then d.kuiWashAlpha = options.washAlpha end
    d.kuiArtwork, d.kuiWash = KT:ApplyTexturedSurface(frame,
        S:GetWindowBackgroundColor(false), d.kuiWashAlpha)
    S:GetFFD(d.kuiArtwork).kuiSurfaceRegion = true
    S:GetFFD(d.kuiWash).kuiSurfaceRegion = true

    local flat = options.flat or d.modernBg
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
        KT:ApplyTexturedSurface(frame, color, d.kuiWashAlpha)
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
local COLOR_HOVER          = { 1.00, 1.00, 1.00, 1.00 } -- Borde blanco al pasar el ratón
local COLOR_CLOSE_BG       = { 0.55, 0.12, 0.12, 1.00 }
local COLOR_CLOSE_HOVER    = { 0.78, 0.15, 0.15, 1.00 }
local COLOR_THUMB          = { 0.30, 0.30, 0.30, 1.00 }
local COLOR_CHECK          = { 1.00, 0.76, 0.00, 1.00 }
local COLOR_CHECK_DIS      = { 0.45, 0.45, 0.45, 1.00 }
local COLOR_CLASSIC_YELLOW = { 1.00, 0.82, 0.00, 1.00 }

local hiddenFrame = CreateFrame("Frame")
hiddenFrame:Hide()

local DEFAULT_BLIZZARD_SKINS = {
    enable = true,
    showWindowBorders = true,
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
    cooldownmanager = true,
    weeklyrewards = true,
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
    if not (object and type(callback) == "function") then return end
    local callbacks = BLIZZARD_ACCENT_REFRESHERS[object]
    if not callbacks then
        callbacks = {}
        BLIZZARD_ACCENT_REFRESHERS[object] = callbacks
    end

    -- A skinned control can own several independently colored layers (generic
    -- button state, separators, selection markers, role feedback, etc.). Keep
    -- every refresher instead of silently replacing the previous one.
    for _, registered in ipairs(callbacks) do
        if registered == callback then return end
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

function S:RegisterBlizzardWindowBorder(object, callback)
    if not (object and type(callback) == "function") then return end
    BLIZZARD_WINDOW_BORDER_REFRESHERS[object] = callback
    pcall(callback, object, self:AreBlizzardWindowBordersEnabled(), self:GetAccentColor())
end

function S:RefreshBlizzardWindowBorders()
    local enabled = self:AreBlizzardWindowBordersEnabled()
    local color = self:GetAccentColor()
    for object, callback in pairs(BLIZZARD_WINDOW_BORDER_REFRESHERS) do
        pcall(callback, object, enabled, color)
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

function S:HandleButton(button)
    if not button or button.isSkinned or IsProtected(button) then return end

    S:CreateBackdrop(button, true)
    if button.backdrop then
        button.backdrop:SetBackdropColor(0.075, 0.075, 0.085, 0.96)
    end

    -- Use flat textures here. Tinting Blizzard's baked button artwork made the
    -- bevel and corners almost black on several modern frames.
    if button.SetNormalTexture then
        button:SetNormalTexture(BLANK_TEX)
        local t = button:GetNormalTexture()
        if t then
            t:SetVertexColor(0.12, 0.12, 0.14, 0.92)
            S:SetInside(t, button.backdrop or button, 1)
        end
    end
    if button.SetPushedTexture then
        button:SetPushedTexture(BLANK_TEX)
        local t = button:GetPushedTexture()
        if t then
            local c = S:GetAccentColor()
            t:SetVertexColor(c[1], c[2], c[3], 0.24)
            S:SetInside(t, button.backdrop or button, 1)
        end
    end
    if button.SetDisabledTexture then
        button:SetDisabledTexture(BLANK_TEX)
        local t = button:GetDisabledTexture()
        if t then
            t:SetVertexColor(0.035, 0.035, 0.04, 0.82)
            S:SetInside(t, button.backdrop or button, 1)
        end
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture(BLANK_TEX)
        local t = button:GetHighlightTexture()
        if t then
            local c = S:GetAccentColor()
            t:SetVertexColor(c[1], c[2], c[3], 0.18)
            S:SetInside(t, button.backdrop or button, 1)
        end
    end

    S:HandleFont(button)

    button:HookScript("OnEnter", function(self)
        if self.backdrop and not self.KT_Selected then
            local c = S:GetAccentColor()
            self.backdrop:SetBackdropBorderColor(c[1], c[2], c[3], 0.8)
            self.backdrop:SetBackdropColor(0.105, 0.105, 0.12, 0.98)
        end
    end)
    button:HookScript("OnLeave", function(self)
        if self.backdrop and not self.KT_Selected then
            self.backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor()))
            self.backdrop:SetBackdropColor(0.075, 0.075, 0.085, 0.96)
        end
    end)

    S:RegisterBlizzardAccentRefresh(button, function(self, color)
        local pushed = self.GetPushedTexture and self:GetPushedTexture()
        if pushed then pushed:SetVertexColor(color[1], color[2], color[3], 0.24) end
        local highlight = self.GetHighlightTexture and self:GetHighlightTexture()
        if highlight then highlight:SetVertexColor(color[1], color[2], color[3], 0.18) end
        if self.backdrop and (self.KT_Selected or (self.IsMouseOver and self:IsMouseOver())) then
            self.backdrop:SetBackdropBorderColor(color[1], color[2], color[3], 0.8)
        end
    end)

    button.isSkinned = true
end

function S:HandleCheckBox(checkbox)
    if not checkbox or checkbox.isSkinned or IsProtected(checkbox) then return end
    S:StripTextures(checkbox)
    S:CreateBackdrop(checkbox)
    if checkbox.backdrop then S:SetInside(checkbox.backdrop, checkbox, 4) end

    if checkbox.SetCheckedTexture then
        checkbox:SetCheckedTexture(BLANK_TEX)
        local t = checkbox:GetCheckedTexture()
        if t then
            local color = S:GetAccentColor()
            t:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
            if checkbox.backdrop then S:SetInside(t, checkbox.backdrop) end
        end
    end
    if checkbox.SetDisabledCheckedTexture then
        checkbox:SetDisabledCheckedTexture(BLANK_TEX)
        local t = checkbox:GetDisabledCheckedTexture()
        if t then
            t:SetVertexColor(unpack(COLOR_CHECK_DIS))
            if checkbox.backdrop then S:SetInside(t, checkbox.backdrop) end
        end
    end

    checkbox:HookScript("OnEnter", function(self) if self.backdrop then self.backdrop:SetBackdropBorderColor(unpack(COLOR_HOVER)) end end)
    checkbox:HookScript("OnLeave", function(self) if self.backdrop then self.backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor())) end end)
    S:RegisterBlizzardAccentRefresh(checkbox, function(self, color)
        local checked = self.GetCheckedTexture and self:GetCheckedTexture()
        if checked then checked:SetVertexColor(color[1], color[2], color[3], color[4] or 1) end
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
        S:SetOutside(frame.backdrop, frame, 0)
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
    local function NavButtonXOffset(button, point, anchor, point2, _, yoffset, skip)
        if skip or not button or button._ktAdjustingPoint or not point then return end

        button._ktAdjustingPoint = true
        button:SetPoint(point, anchor, point2, button._ktNavSpacing or 4, yoffset, true)
        button._ktAdjustingPoint = nil
    end

    function S:SkinNavBarButton(button, index)
        if not button or button._ktNavButtonSkinned then return end

        S:HandleButton(button)

        -- The default breadcrumb chevrons extend outside each button and leave
        -- large purple wedges between otherwise flat KUI panels. The button
        -- backdrop already communicates each navigation step more clearly.
        for _, key in ipairs({ 'Left', 'arrowUp', 'arrowDown', 'selected' }) do
            local texture = button[key]
            if texture and texture.SetAlpha then
                texture:SetAlpha(0)
            end
        end

        local fontString = button.GetFontString and button:GetFontString()
        if fontString then
            fontString:SetTextColor(unpack(COLOR_TEXT))
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
            NavButtonXOffset(button, button:GetPoint())
            hooksecurefunc(button, "SetPoint", NavButtonXOffset)
        end

        button._ktNavButtonSkinned = true
    end

    function S:HandleNavBarButtons(data)
        if not self or not self.navList then return end

        if not data then
            for index, navButton in next, self.navList do
                S:SkinNavBarButton(navButton, index)
            end
        else
            local lastIndex = #self.navList
            S:SkinNavBarButton(self.navList[lastIndex], lastIndex)
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

function S:CreateBackdrop(frame, transparent)
    if not frame or IsProtected(frame) then return end
    if not (frame.IsObjectType and frame:IsObjectType("Frame")) then return end
    if frame.backdrop then return end

    local backdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    backdrop:SetFrameLevel(math_max(1, frame:GetFrameLevel() - 1))
    S:SetOutside(backdrop, frame, 0)
    backdrop:SetBackdrop({ bgFile = BLANK_TEX, edgeFile = BLANK_TEX, edgeSize = S.mult or 1, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    backdrop:SetBackdropColor(unpack(S:GetBackgroundColor(transparent)))
    backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor()))
    frame.backdrop = backdrop
end

function S:CreateFlatBackdrop(frame, transparent)
    if not frame or IsProtected(frame) then return end
    if not (frame.IsObjectType and frame:IsObjectType("Frame")) then return end
    if frame.backdrop then return end

    local bd = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    bd:SetFrameLevel(math_max(1, frame:GetFrameLevel() - 1))
    S:SetOutside(bd, frame, 0)
    bd:SetBackdrop({ bgFile = BLANK_TEX, edgeFile = BLANK_TEX, edgeSize = S.mult or 1, insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    bd:SetBackdropColor(unpack(S:GetBackgroundColor(transparent)))
    bd:SetBackdropBorderColor(COLOR_BG[1], COLOR_BG[2], COLOR_BG[3], 0)
    frame.backdrop = bd
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

    frame.isSkinned = true
end

local function TintHandledTabTexture(texture, color, alpha)
    if not (texture and texture.SetVertexColor) then return end

    if texture.SetDesaturated then
        pcall(texture.SetDesaturated, texture, true)
    elseif texture.SetDesaturation then
        pcall(texture.SetDesaturation, texture, 1)
    end

    texture:SetVertexColor(color[1], color[2], color[3], alpha or 1)
end

function S:HandleTab(tab)
    if not tab or tab._ktTabSkinned or IsProtected(tab) then return end

    local tabName = tab.GetName and tab:GetName()
    local neutral = { 0.55, 0.53, 0.50, 1 }

    local function GetTexture(suffix)
        return tab[suffix] or (tabName and _G[tabName .. suffix])
    end

    local function ApplyTabColors()
        local accent = S:GetAccentColor()
        for _, suffix in ipairs({
            "Left", "Middle", "Right", "Mid",
            "NormalTexture", "Background"
        }) do
            TintHandledTabTexture(GetTexture(suffix), neutral, 1)
        end

        for _, suffix in ipairs({
            "LeftDisabled", "MiddleDisabled", "RightDisabled",
            "LeftActive", "MiddleActive", "RightActive",
            "ActiveLeft", "ActiveMiddle", "ActiveRight",
            "SelectedLeft", "SelectedMiddle", "SelectedRight",
            "DisabledTexture", "ActiveTexture", "SelectedTexture", "Selection"
        }) do
            TintHandledTabTexture(GetTexture(suffix), accent, 1)
        end

        local highlight = tab.GetHighlightTexture and tab:GetHighlightTexture()
        TintHandledTabTexture(highlight, accent, 0.45)
    end

    ApplyTabColors()

    local text = tab.Text
    local textKind = type(text)
    if not ((textKind == "table" or textKind == "userdata") and text.IsObjectType and text:IsObjectType("FontString")) then
        text = tab.GetFontString and tab:GetFontString()
    end
    if text then
        S:HandleFont(text)
        if text.SetTextColor then text:SetTextColor(1, 1, 1, 1) end
    end

    tab._ktTabSkinned = true
    S:RegisterBlizzardAccentRefresh(tab, function() ApplyTabColors() end)
    tab:HookScript("OnShow", ApplyTabColors)
    if tab.IsObjectType and tab:IsObjectType("Button") then
        tab:HookScript("OnClick", function()
            if C_Timer then C_Timer.After(0, ApplyTabColors) else ApplyTabColors() end
        end)
    end
end

function S:HandleScrollBar(frame)
    if not frame or frame._ktScrollBarSkinned or IsProtected(frame) then return end
    if frame.Track then
        for _, layer in ipairs({"ARTWORK","BORDER","BACKGROUND","OVERLAY"}) do
            pcall(function() frame.Track:DisableDrawLayer(layer) end)
        end
        local thumb = frame.Track.Thumb
        if thumb then
            for _, k in ipairs({"Begin","Middle","End"}) do
                if thumb[k] then thumb[k]:Hide() end
            end
            if not thumb.backdrop then
                S:CreateBackdrop(thumb)
                if thumb.backdrop then
                    thumb.backdrop:SetBackdropColor(unpack(COLOR_THUMB))
                    thumb.backdrop:SetPoint("TOPLEFT", thumb, "TOPLEFT", 2, -2)
                    thumb.backdrop:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 2)
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
        button.backdrop:SetBackdropColor(unpack(COLOR_CLOSE_BG))
    end

    button:SetSize(18, 18)

    if not button._ktX then
        local fs = button:CreateFontString(nil, "OVERLAY")
        fs:SetFont(FONT_AVANT, 14, "OUTLINE")
        fs:SetText("X")
        fs:SetTextColor(unpack(COLOR_TEXT))
        fs:SetPoint("CENTER", button.backdrop or button, "CENTER", 0, 1)
        button._ktX = fs
    end

    button:HookScript("OnEnter", function(self)
        if self.backdrop then self.backdrop:SetBackdropColor(unpack(COLOR_CLOSE_HOVER)) end
    end)
    button:HookScript("OnLeave", function(self)
        if self.backdrop then self.backdrop:SetBackdropColor(unpack(COLOR_CLOSE_BG)) end
    end)
    button._ktCloseSkinned = true
end

function S:HandleEditBox(box)
    if not box or box._ktEditBoxSkinned or IsProtected(box) then return end
    S:StripTextures(box)
    S:CreateBackdrop(box)
    S:HandleFont(box)
    if box.backdrop then
        S:SetOutside(box.backdrop, box, 0)
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
            if box.backdrop then box.backdrop:SetBackdropBorderColor(unpack(COLOR_HOVER)) end
        end)
        editBox:HookScript("OnEditFocusLost", function()
            if box.backdrop then box.backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor())) end
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
    local callbackName = type(name) == "string" and name or addonName
    local callbackFunc = type(name) == "function" and name or func
    self:RegisterSkin(addonName, callbackFunc, forceLoad, bypass, position, callbackName)
end

function S:AddCallback(name, func, position)
    local callbackName = type(name) == "string" and name or "KullThranUI_Skins"
    local callbackFunc = type(name) == "function" and name or func
    self:RegisterSkin("KullThranUI_Skins", callbackFunc, nil, nil, position, callbackName)
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
    for addonName, func in pairs(self.SkinFuncs) do
        self:RegisterSkin(addonName, func, nil, nil, nil, addonName)
        self.SkinFuncs[addonName] = nil
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
    if not self.Initialized or not self.db or not self.db.enable then return end

    local callbacks = self.addonsToLoad[addonName]
    if callbacks then
        self:CallLoadedAddon(addonName, callbacks)
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

