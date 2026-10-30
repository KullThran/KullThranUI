-- Widgets.lua
-- Fábrica de widgets para la interfaz personalizada de KullThranUI.
local addonName, ns = ...
local KT            = ns.KT

KT.Widgets          = KT.Widgets or {}
local W             = KT.Widgets

local function CurrentFont()
    if KT and type(KT.FONT_PATH) == "string" and KT.FONT_PATH ~= "" then
        return KT.FONT_PATH
    end
    if KT and KT.ResolveFontPath then
        return KT:ResolveFontPath()
    end

    return KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
end
local ICON_PATH     = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"

local function CurrentAccentColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local accent = palette and palette.accent or nil
    return (accent and accent.r) or KT.C_R or 1,
        (accent and accent.g) or KT.C_G or 0,
        (accent and accent.b) or KT.C_B or 0.3333333333
end

local function CurrentTextColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local text = palette and palette.text or nil
    return (text and text.r) or 1,
        (text and text.g) or 1,
        (text and text.b) or 1
end

local function CurrentMutedColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local muted = palette and palette.muted or nil
    return (muted and muted.r) or 0.74,
        (muted and muted.g) or 0.74,
        (muted and muted.b) or 0.78
end

-- Small locale flags drawn from color layers. They stay independent from the
-- active font, so scripts unsupported by Avant Garde cannot turn them into
-- missing-glyph boxes and no external texture pack is required.
function KT:CreateLocaleFlag(parent, locale, width, height)
    if not parent then return nil end

    local flag = CreateFrame("Frame", nil, parent)
    flag:SetSize(width or 22, height or 14)
    if flag.SetClipsChildren then flag:SetClipsChildren(true) end

    local parts = {}
    local borders = {}

    local function AddPart(x, y, w, h, r, g, b, rotation)
        -- The first rectangle is the flag background. Keep it on a lower
        -- layer so white backgrounds (United Kingdom/Korea) cannot cover
        -- their crosses, symbols or stripes on some render configurations.
        local layer = (#parts == 0) and "BACKGROUND" or "ARTWORK"
        local subLevel = (layer == "ARTWORK") and math.min(7, #parts) or nil
        local texture = flag:CreateTexture(nil, layer, nil, subLevel)
        texture:SetColorTexture(r, g, b, 1)
        texture:SetSize(math.max(1, w), math.max(1, h))
        texture:SetPoint("TOPLEFT", flag, "TOPLEFT", x, -y)
        if rotation and texture.SetRotation then texture:SetRotation(rotation) end
        parts[#parts + 1] = texture
        return texture
    end

    local function AddBorder()
        if #borders > 0 then
            for _, texture in ipairs(borders) do texture:Show() end
            return
        end
        local function Line()
            local texture = flag:CreateTexture(nil, "OVERLAY")
            texture:SetColorTexture(0.02, 0.02, 0.025, 0.9)
            borders[#borders + 1] = texture
            return texture
        end
        local top = Line()
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")
        top:SetHeight(1)
        local bottom = Line()
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")
        bottom:SetHeight(1)
        local left = Line()
        left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
        left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
        left:SetWidth(1)
        local right = Line()
        right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
        right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
        right:SetWidth(1)
    end

    function flag:SetLocale(localeCode)
        localeCode = localeCode or "auto"
        if localeCode == "esMX" then localeCode = "esES" end
        if localeCode == "ptPT" then localeCode = "ptBR" end

        if self.localeCode == localeCode and #parts > 0 then
            for _, texture in ipairs(parts) do texture:Show() end
            AddBorder()
            return
        end
        self.localeCode = localeCode
        for _, texture in ipairs(parts) do texture:Hide() end
        wipe(parts)

        local w, h = self:GetWidth(), self:GetHeight()
        local white = { 0.96, 0.96, 0.96 }
        local red = { 0.82, 0.06, 0.10 }
        local blue = { 0.05, 0.20, 0.55 }
        local yellow = { 1.00, 0.78, 0.05 }

        if localeCode == "auto" then
            -- Auto is not a country: use a compact globe-style mark.
            AddPart(0, 0, w, h, 0.03, 0.28, 0.62)
            AddPart(w * 0.16, h * 0.20, w * 0.25, h * 0.28, 0.16, 0.72, 0.35)
            AddPart(w * 0.52, h * 0.48, w * 0.30, h * 0.30, 0.16, 0.72, 0.35)
            AddPart(w * 0.48, h * 0.08, 1, h * 0.84, 0.72, 0.90, 1.00)
            AddPart(w * 0.10, h * 0.48, w * 0.80, 1, 0.72, 0.90, 1.00)
        elseif localeCode == "enUS" or localeCode == "enGB" then
            -- English is represented by the United Kingdom.
            AddPart(0, 0, w, h, 0.02, 0.14, 0.42)
            AddPart(-w * 0.08, h * 0.38, w * 1.16, h * 0.24, 0.96, 0.96, 0.96, math.rad(32))
            AddPart(-w * 0.08, h * 0.38, w * 1.16, h * 0.24, 0.96, 0.96, 0.96, math.rad(-32))
            AddPart(-w * 0.08, h * 0.44, w * 1.16, h * 0.10, 0.82, 0.03, 0.10, math.rad(32))
            AddPart(-w * 0.08, h * 0.44, w * 1.16, h * 0.10, 0.82, 0.03, 0.10, math.rad(-32))
            AddPart(w * 0.38, 0, w * 0.24, h, 0.96, 0.96, 0.96)
            AddPart(0, h * 0.34, w, h * 0.32, 0.96, 0.96, 0.96)
            AddPart(w * 0.44, 0, w * 0.12, h, 0.82, 0.03, 0.10)
            AddPart(0, h * 0.42, w, h * 0.16, 0.82, 0.03, 0.10)
        elseif localeCode == "deDE" then
            AddPart(0, 0, w, h / 3, 0.03, 0.03, 0.03)
            AddPart(0, h / 3, w, h / 3, 0.82, 0.03, 0.09)
            AddPart(0, h * 2 / 3, w, h / 3, 1.00, 0.73, 0.00)
        elseif localeCode == "esES" then
            AddPart(0, 0, w, h / 4, 0.72, 0.03, 0.08)
            AddPart(0, h / 4, w, h / 2, 1.00, 0.78, 0.00)
            AddPart(0, h * 3 / 4, w, h / 4, 0.72, 0.03, 0.08)
            AddPart(w * 0.27, h * 0.38, math.max(2, w * 0.08), h * 0.24, 0.72, 0.08, 0.08)
        elseif localeCode == "frFR" then
            AddPart(0, 0, w / 3, h, 0.02, 0.20, 0.58)
            AddPart(w / 3, 0, w / 3, h, white[1], white[2], white[3])
            AddPart(w * 2 / 3, 0, w / 3, h, 0.90, 0.05, 0.12)
        elseif localeCode == "itIT" then
            AddPart(0, 0, w / 3, h, 0.00, 0.55, 0.27)
            AddPart(w / 3, 0, w / 3, h, white[1], white[2], white[3])
            AddPart(w * 2 / 3, 0, w / 3, h, 0.82, 0.04, 0.10)
        elseif localeCode == "ptBR" then
            AddPart(0, 0, w, h, 0.02, 0.55, 0.20)
            AddPart((w - h * 0.68) / 2, h * 0.16, h * 0.68, h * 0.68, yellow[1], yellow[2], yellow[3], math.rad(45))
            AddPart(w * 0.41, h * 0.30, w * 0.18, h * 0.40, 0.03, 0.20, 0.55)
            AddPart(w * 0.42, h * 0.46, w * 0.16, 1, 1, 1, 1)
        elseif localeCode == "ruRU" then
            AddPart(0, 0, w, h / 3, white[1], white[2], white[3])
            AddPart(0, h / 3, w, h / 3, 0.02, 0.25, 0.65)
            AddPart(0, h * 2 / 3, w, h / 3, 0.82, 0.04, 0.10)
        elseif localeCode == "koKR" then
            AddPart(0, 0, w, h, white[1], white[2], white[3])
            AddPart(w * 0.40, h * 0.20, h * 0.42, h * 0.42, red[1], red[2], red[3], math.rad(45))
            AddPart(w * 0.40, h * 0.48, h * 0.42, h * 0.42, 0.04, 0.23, 0.62, math.rad(45))
            AddPart(w * 0.10, h * 0.18, w * 0.22, 1.5, 0.04, 0.04, 0.04, math.rad(-25))
            AddPart(w * 0.68, h * 0.18, w * 0.22, 1.5, 0.04, 0.04, 0.04, math.rad(25))
            AddPart(w * 0.10, h * 0.72, w * 0.22, 1.5, 0.04, 0.04, 0.04, math.rad(25))
            AddPart(w * 0.68, h * 0.72, w * 0.22, 1.5, 0.04, 0.04, 0.04, math.rad(-25))
        elseif localeCode == "zhCN" then
            AddPart(0, 0, w, h, 0.86, 0.03, 0.08)
            AddPart(w * 0.16, h * 0.20, h * 0.25, h * 0.25, yellow[1], yellow[2], yellow[3], math.rad(45))
            AddPart(w * 0.33, h * 0.14, 1, 1, yellow[1], yellow[2], yellow[3])
            AddPart(w * 0.37, h * 0.30, 1, 1, yellow[1], yellow[2], yellow[3])
            AddPart(w * 0.34, h * 0.46, 1, 1, yellow[1], yellow[2], yellow[3])
        elseif localeCode == "zhTW" then
            AddPart(0, 0, w, h, 0.84, 0.03, 0.10)
            AddPart(0, 0, w * 0.48, h * 0.58, 0.02, 0.16, 0.47)
            AddPart(w * 0.18, h * 0.16, h * 0.24, h * 0.24, white[1], white[2], white[3], math.rad(45))
        else
            -- Unknown locales get the same neutral mark as Auto.
            AddPart(0, 0, w, h, 0.03, 0.28, 0.62)
            AddPart(w * 0.16, h * 0.20, w * 0.25, h * 0.28, 0.16, 0.72, 0.35)
            AddPart(w * 0.52, h * 0.48, w * 0.30, h * 0.30, 0.16, 0.72, 0.35)
            AddPart(w * 0.48, h * 0.08, 1, h * 0.84, 0.72, 0.90, 1.00)
            AddPart(w * 0.10, h * 0.48, w * 0.80, 1, 0.72, 0.90, 1.00)
        end

        AddBorder()
    end

    flag:SetLocale(locale)
    return flag
end

-- ============================================================================
-- HELPERS INTERNOS
-- ============================================================================
local function FW(parent) return parent:GetWidth() - 20 end

-- Defined in the LOCALIZATION section below; declared here so the card
-- helpers can use it.
local LText

-- Skin-painted textures and shapes remember their MenuSkins colour token so a
-- skin or accent change (MenuSkins:Repaint) recolours what is on screen.
local skinned = setmetatable({}, { __mode = "k" })
local skinnedCards = setmetatable({}, { __mode = "k" })

local function SkinColor(token)
    if KT.MenuSkins then return KT.MenuSkins:Color(token) end
    return 1, 1, 1, 0.03
end

local function PaintSkinned(tex, token)
    skinned[tex] = token
    tex._skinToken = token
    if tex._ktRound then
        tex:SetColor(SkinColor(token))
    else
        tex:SetColorTexture(SkinColor(token))
    end
end

local function PartPath(name)
    return (KT.MenuSkins and KT.MenuSkins.TEXTURE_PATH or "") .. name
end

-- ----------------------------------------------------------------------------
-- Rounded rectangle: nine slices of one white disc (quarter-circle corners,
-- thin edge strips, solid centre). Position it through rr:SetPoint/SetSize
-- like a texture; rr:SetColor tints every slice.
-- ----------------------------------------------------------------------------
local ROUND_COORDS = {
    { 0, 0.5, 0, 0.5 }, { 0.49, 0.51, 0, 0.5 }, { 0.5, 1, 0, 0.5 },
    { 0, 0.5, 0.49, 0.51 }, { 0.49, 0.51, 0.49, 0.51 }, { 0.5, 1, 0.49, 0.51 },
    { 0, 0.5, 0.5, 1 }, { 0.49, 0.51, 0.5, 1 }, { 0.5, 1, 0.5, 1 },
}
local RoundRect = {}
RoundRect.__index = RoundRect

function RoundRect:SetRadius(radius)
    self.radius = radius
    local box, p, r = self.box, self.pieces, radius
    for i = 1, 9 do p[i]:ClearAllPoints() end
    p[1]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0); p[1]:SetSize(r, r)
    p[3]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, 0); p[3]:SetSize(r, r)
    p[7]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0); p[7]:SetSize(r, r)
    p[9]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0); p[9]:SetSize(r, r)
    p[2]:SetPoint("TOPLEFT", box, "TOPLEFT", r, 0); p[2]:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", -r, -r)
    p[8]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", r, 0); p[8]:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -r, r)
    p[4]:SetPoint("TOPLEFT", box, "TOPLEFT", 0, -r); p[4]:SetPoint("BOTTOMRIGHT", box, "BOTTOMLEFT", r, r)
    p[6]:SetPoint("TOPRIGHT", box, "TOPRIGHT", 0, -r); p[6]:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", -r, r)
    p[5]:SetPoint("TOPLEFT", box, "TOPLEFT", r, -r); p[5]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -r, r)
    return self
end

function RoundRect:SetColor(r, g, b, a)
    if type(r) == "table" then r, g, b, a = r[1], r[2], r[3], r[4] end
    self.color = { r, g, b, a or 1 }
    for i = 1, 9 do self.pieces[i]:SetVertexColor(r, g, b, a or 1) end
end

function RoundRect:SetPoint(...) self.box:SetPoint(...) end
function RoundRect:ClearAllPoints() self.box:ClearAllPoints() end
function RoundRect:SetAllPoints(target) self.box:SetAllPoints(target) end
function RoundRect:SetSize(w, h) self.w, self.h = w, h; self.box:SetSize(w, h) end
function RoundRect:SetWidth(w) self.w = w; self.box:SetWidth(w) end
function RoundRect:SetHeight(h) self.h = h; self.box:SetHeight(h) end

function RoundRect:SetShown(shown)
    self.shown = shown and true or false
    for i = 1, 9 do self.pieces[i]:SetShown(self.shown) end
end
function RoundRect:Show() self:SetShown(true) end
function RoundRect:Hide() self:SetShown(false) end
function RoundRect:IsShown() return self.shown end

function W:RoundRect(parent, layer, sublevel, radius)
    local rr = setmetatable({ pieces = {}, shown = true, _ktRound = true }, RoundRect)
    rr.box = parent:CreateTexture(nil, layer, nil, sublevel)
    rr.box:SetColorTexture(0, 0, 0, 0)
    for i = 1, 9 do
        local t = parent:CreateTexture(nil, layer, nil, sublevel)
        t:SetTexture(PartPath("round_disc"))
        t:SetTexCoord(unpack(ROUND_COORDS[i]))
        rr.pieces[i] = t
    end
    rr:SetRadius(radius or 8)
    return rr
end

if KT.MenuSkins then
    KT.MenuSkins:RegisterRepaint(function()
        for tex, token in pairs(skinned) do
            if token then PaintSkinned(tex, token) end
        end
        for card in pairs(skinnedCards) do
            if card._ktSetHover then card._ktSetHover(card._ktHovered, true) end
        end
    end)
end

-- ----------------------------------------------------------------------------
-- Layered card: a back plate peeks out below the rounded front; on hover the
-- plate spreads and lights with the accent. The header holds a small pill and
-- the title in normal case.
-- ----------------------------------------------------------------------------
local CARD_RADIUS = 12
local CARD_HEADER_H = 34

-- Header icons: cells of MenuSkins/card_icons.tga (8x8 grid, rendered by
-- tools/photoshop/card_icons.py, same order). A card takes opts.icon or the
-- first rule whose word prefix appears in its English title; "claw" otherwise.
W.CARD_ICONS = {
    "claw", "palette", "typography", "layout", "dimensions", "eye", "photo",
    "user-circle", "brush", "clock", "sparkles", "chart-bar", "click",
    "adjustments", "plug", "gauge", "bell", "users", "sword", "id-badge",
    "map", "refresh", "wand", "puzzle", "list-check", "target", "route",
    "moon", "bookmark", "arrows-move", "bolt", "heart", "flame", "stairs-up",
    "layout-grid", "external-link", "settings", "device-desktop", "shield",
}
W.CARD_ICON_RULES = {
    { "external-link", { "open addon" } },
    { "bolt", { "spell queue" } },
    { "stairs-up", { "nameplate level" } },
    { "heart", { "health" } },
    { "flame", { "class resource", "resource" } },
    { "arrows-move", { "kuimove", "frame access", "unlock" } },
    { "moon", { "afk" } },
    { "target", { "reticle" } },
    { "route", { "trail" } },
    { "device-desktop", { "preview" } },
    { "map", { "minimap", "zone", "coordinate" } },
    { "refresh", { "update", "release" } },
    { "plug", { "compatib", "conflict", "integration" } },
    { "wand", { "install", "quick setup" } },
    { "bookmark", { "preset" } },
    { "puzzle", { "module" } },
    { "list-check", { "track", "objective" } },
    { "palette", { "colo", "palette", "threat" } },
    { "typography", { "typograph", "text", "font", "keybind", "hotkey" } },
    { "user-circle", { "profile" } },
    { "dimensions", { "dimension", "size" } },
    { "layout-grid", { "views" } },
    { "layout", { "position", "layout" } },
    { "eye", { "visib", "hide", "fade", "mouseover" } },
    { "sparkles", { "glow", "effect", "special" } },
    { "clock", { "cooldown", "timer", "swipe", "duration" } },
    { "brush", { "style", "theme", "appearance", "shape", "art", "skin", "window" } },
    { "chart-bar", { "bar", "progress", "cast" } },
    { "click", { "button" } },
    { "photo", { "icon", "aura catalog" } },
    { "bell", { "remind", "buff", "aura", "trigger" } },
    { "users", { "party", "raid", "friendly", "role", "group" } },
    { "sword", { "enemy", "dot", "damage" } },
    { "id-badge", { "nameplate", "unit" } },
    { "gauge", { "diagnostic", "monitor", "fps", "graphic", "render", "quality", "distance", "post processing", "display", "stats" } },
    { "settings", { "setting" } },
    { "adjustments", { "general", "misc", "advanced", "enhancement" } },
}

function W:CardIconFor(title)
    if type(title) ~= "string" then return "claw" end
    local text = " " .. title:lower():gsub("[^%w]+", " ")
    for _, rule in ipairs(W.CARD_ICON_RULES) do
        for _, word in ipairs(rule[2]) do
            if text:find(" " .. word, 1, true) then return rule[1] end
        end
    end
    return "claw"
end

function W:CardIconCoords(name)
    local index = 0
    for i, icon in ipairs(W.CARD_ICONS) do
        if icon == name then index = i - 1; break end
    end
    local col, row = index % 8, math.floor(index / 8)
    return col / 8, (col + 1) / 8, row / 8, (row + 1) / 8
end

local function Mix(a, b, t)
    return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t
end

-------------------------------------------------------------------------------
--  Live preview frame, after the border of a CSS card the user supplied:
--  rounded corners, a 1px border in the accent colour, a faint white veil over
--  the dark body and, on hover, a stronger border with a soft glow around the
--  card (0.3 s). It replaces the square KUI backdrop and border of the box.
--
--  The options window pins most previews inside one shared frame (Options.lua
--  _stickyPreviewHost): that outer frame wears the card, and a preview box
--  pinned in it only drops its own square so there is a single frame.
-------------------------------------------------------------------------------
local GLASS_TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\StyleCards\\"
local GLASS_RADIUS = 11          -- CSS 0.7rem
local GLASS_FADE = 1 / 0.3       -- hover transition (CSS 0.3 s)
local GLASS_BORDER = { 0.45, 0.9 } -- accent alpha at rest / hovered (CSS 0.222 / 0.454 white)
local GLASS_VEIL = 0.074         -- CSS rgba(255, 255, 255, 0.074)
local GLASS_GLOW = 0.25          -- CSS hover box-shadow 0 0 20px 1px, alpha 0x3f
local GLASS_NINE = {
    { 0, 0.25, 0, 0.25 }, { 0.25, 0.75, 0, 0.25 }, { 0.75, 1, 0, 0.25 },
    { 0, 0.25, 0.25, 0.75 }, { 0.25, 0.75, 0.25, 0.75 }, { 0.75, 1, 0.25, 0.75 },
    { 0, 0.25, 0.75, 1 }, { 0.25, 0.75, 0.75, 1 }, { 0.75, 1, 0.75, 1 },
}

local function GlassSlices(owner, file, layer, sublevel, skipCenter)
    local p = {}
    for i, c in ipairs(GLASS_NINE) do
        if not (skipCenter and i == 5) then
            local t = owner:CreateTexture(nil, layer, nil, sublevel)
            t:SetTexture(GLASS_TEX .. file)
            t:SetTexCoord(c[1], c[2], c[3], c[4])
            p[i] = t
        end
    end
    for _, i in ipairs({ 1, 3, 7, 9 }) do p[i]:SetSize(GLASS_RADIUS, GLASS_RADIUS) end
    p[1]:SetPoint("TOPLEFT"); p[3]:SetPoint("TOPRIGHT"); p[7]:SetPoint("BOTTOMLEFT"); p[9]:SetPoint("BOTTOMRIGHT")
    p[2]:SetPoint("TOPLEFT", p[1], "TOPRIGHT"); p[2]:SetPoint("BOTTOMRIGHT", p[3], "BOTTOMLEFT")
    p[8]:SetPoint("TOPLEFT", p[7], "TOPRIGHT"); p[8]:SetPoint("BOTTOMRIGHT", p[9], "BOTTOMLEFT")
    p[4]:SetPoint("TOPLEFT", p[1], "BOTTOMLEFT"); p[4]:SetPoint("BOTTOMRIGHT", p[7], "TOPRIGHT")
    p[6]:SetPoint("TOPLEFT", p[3], "BOTTOMLEFT"); p[6]:SetPoint("BOTTOMRIGHT", p[9], "TOPRIGHT")
    if p[5] then p[5]:SetPoint("TOPLEFT", p[1], "BOTTOMRIGHT"); p[5]:SetPoint("BOTTOMRIGHT", p[9], "TOPLEFT") end
    return p
end

-- Keeps the box's square KUI look off: modules may repaint it on refresh.
local function GlassClearSquare(frame)
    if frame.SetBackdrop and frame.GetBackdrop and frame:GetBackdrop() then frame:SetBackdrop(nil) end
    if frame.borderKT and frame.borderKT:IsShown() then frame.borderKT:Hide() end
    local bg = frame._ktBackdropTexture or frame.bgKT
    if bg and bg:IsShown() then bg:Hide() end
end

-- A preview box pinned inside the shared outer frame, which wears the card.
local function GlassPinned(frame)
    local menu = KT.MenuPrincipal
    local host = menu and menu._stickyPreviewHost
    return host ~= nil and host ~= frame and frame.GetParent and frame:GetParent() == host
end

local function GlassPaint(card, hover, visible)
    local r, g, b = CurrentAccentColor()
    local a = GLASS_BORDER[1] + (GLASS_BORDER[2] - GLASS_BORDER[1]) * hover
    for _, t in pairs(card.border) do t:SetVertexColor(r, g, b, visible and a or 0) end
    -- The pinned preview host covers options scrolling beneath it: fully opaque.
    local bodyAlpha = card.opaque and 1 or 0.92
    for _, t in pairs(card.body) do t:SetVertexColor(0.02, 0.02, 0.025, visible and bodyAlpha or 0) end
    for _, t in pairs(card.fill) do t:SetVertexColor(1, 1, 1, visible and GLASS_VEIL or 0) end
    card.glow:SetVertexColor(r, g, b, 1)
    card.glow:SetAlpha(visible and GLASS_GLOW * hover or 0)
end

local function GlassUpdate(self, elapsed)
    local card = self.card
    self.acc = (self.acc or 0) + (elapsed or 0)
    if self.acc < 0.03 then return end
    local step = self.acc * GLASS_FADE
    self.acc = 0
    local host = self.host
    GlassClearSquare(host)
    local visible = not GlassPinned(host)
    local over = visible and host.IsMouseOver and host:IsMouseOver() or false
    local target = over and 1 or 0
    if card.hover < target then card.hover = math.min(target, card.hover + step)
    elseif card.hover > target then card.hover = math.max(target, card.hover - step) end
    -- Repainted every tick so an accent change shows at once.
    GlassPaint(card, card.hover, visible)
end

-- Dresses a live preview frame (any frame) with the card in place of its
-- square KUI backdrop and border; the frame's own content stays as is.
function W:PreviewCard(frame)
    if not frame or frame._ktGlass then return frame and frame._ktGlass end
    GlassClearSquare(frame)
    local card = { hover = 0 }
    -- box-shadow on hover: a soft glow all around, no offset
    card.glow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    card.glow:SetTexture(GLASS_TEX .. "tile_glow")
    card.glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -22, 22)
    card.glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 22, -22)
    -- the dark body the square backdrop drew, rounded, with the white veil over it
    card.body = GlassSlices(frame, "fill", "BACKGROUND", -7)
    card.fill = GlassSlices(frame, "fill", "BACKGROUND", -6)
    -- border: 1px, accent, on top of the preview content
    local edge = CreateFrame("Frame", nil, frame)
    edge:SetAllPoints(frame)
    edge:SetFrameLevel((frame:GetFrameLevel() or 0) + 50)
    edge:EnableMouse(false)
    card.border = GlassSlices(edge, "border", "OVERLAY", 7, true)
    edge.card, edge.host = card, frame
    edge:SetScript("OnUpdate", GlassUpdate)
    card.edge = edge
    GlassPaint(card, 0, not GlassPinned(frame))
    frame._ktGlass = card
    return card
end

function W:StyleCard(frame, opts)
    opts = opts or {}
    skinnedCards[frame] = true

    local back = frame._backKT or W:RoundRect(frame, "BACKGROUND", -4, CARD_RADIUS)
    local border = frame._borderKT or W:RoundRect(frame, "BACKGROUND", -3, CARD_RADIUS + 1)
    local front = frame._frontKT or W:RoundRect(frame, "BACKGROUND", -2, CARD_RADIUS)
    frame._backKT, frame._borderKT, frame._frontKT = back, border, front

    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
    front:ClearAllPoints()
    front:SetAllPoints(frame)
    PaintSkinned(front, "card")

    local function PlaceBack(t)
        local side = 10 - 6 * t
        back:ClearAllPoints()
        back:SetPoint("TOPLEFT", frame, "TOPLEFT", side, -8)
        back:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -side, -(6 + 4 * t))
    end

    local function Paint(t)
        local ar, ag, ab = CurrentAccentColor()
        local accent = { ar, ag, ab, 1 }
        back:SetColor(Mix({ SkinColor("cardBack") }, accent, t))
        border:SetColor(Mix({ SkinColor("cardBorder") }, { ar * 0.45, ag * 0.45, ab * 0.45, 1 }, t))
        PlaceBack(t)
    end

    -- Hover polls the cursor (child controls take the mouse, so the card
    -- itself never gets OnEnter) and eases between rest (0) and lit (1).
    frame._ktHoverLevel = frame._ktHoverLevel or 0
    frame._ktSetHover = function(hovered, instant)
        frame._ktHovered = hovered and true or false
        frame._ktHoverTarget = hovered and 1 or 0
        if instant then frame._ktHoverLevel = frame._ktHoverTarget end
        Paint(frame._ktHoverLevel)
    end
    if not frame._ktHoverPoll then
        local acc = 0
        frame:SetScript("OnUpdate", function(self, elapsed)
            acc = acc + elapsed
            if acc >= 0.05 then
                acc = 0
                local over = self.IsMouseOver and self:IsMouseOver() or false
                if over ~= (self._ktHovered or false) then self._ktSetHover(over) end
            end
            local level, target = self._ktHoverLevel, self._ktHoverTarget or 0
            if level ~= target then
                local step = elapsed / 0.2
                level = (target > level) and math.min(target, level + step) or math.max(target, level - step)
                self._ktHoverLevel = level
                Paint(level)
            end
        end)
        frame._ktHoverPoll = true
    end
    frame._ktSetHover(frame._ktHovered, true)

    if opts.title then
        local pill = frame._pillKT or W:RoundRect(frame, "ARTWORK", 0, 7)
        pill:ClearAllPoints()
        pill:SetSize(22, 22)
        pill:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -7)
        local ar, ag, ab = CurrentAccentColor()
        pill:SetColor(ar * 0.22, ag * 0.22, ab * 0.22, 1)
        frame._pillKT = pill

        local mark = frame._pillMarkKT or frame:CreateTexture(nil, "OVERLAY")
        mark:ClearAllPoints()
        mark:SetTexture(PartPath("card_icons"))
        mark:SetTexCoord(W:CardIconCoords(opts.icon or W:CardIconFor(opts.title)))
        mark:SetSize(14, 14)
        mark:SetPoint("CENTER", pill.box, "CENTER", 0, 0)
        mark:SetVertexColor(ar, ag, ab, 1)
        frame._pillMarkKT = mark

        local title = frame._titleKT or frame:CreateFontString(nil, "OVERLAY")
        title:SetFont(CurrentFont(), 13)
        title:ClearAllPoints()
        title:SetPoint("LEFT", pill.box, "RIGHT", 9, 0)
        title:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(false)
        title:SetText(LText(opts.title))
        local tr, tg, tb = CurrentTextColor()
        title:SetTextColor(tr, tg, tb, 1)
        frame._titleKT = title
    end
    return front
end

W.CARD_HEADER_H = CARD_HEADER_H

-- ----------------------------------------------------------------------------
-- Window frame pieces: rounded frame buttons, sidebar entries and the
-- segmented tab control. Every piece repaints with MenuSkins.
-- ----------------------------------------------------------------------------
local framePieces = setmetatable({}, { __mode = "k" })

-- Rounded button for the window frame (footer, header).
-- opts: primary, danger, width, height, radius, fontSize, onClick, icon,
-- iconCoords, iconSize (an icon with no label sits in the centre).
function W:PillButton(parent, label, opts)
    opts = opts or {}
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(opts.width or 120, opts.height or 40)
    local radius = opts.radius or 9
    local border = W:RoundRect(btn, "BACKGROUND", 1, radius + 1)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 1, -1)
    local bg = W:RoundRect(btn, "BACKGROUND", 2, radius)
    bg:SetAllPoints(btn)
    btn._pillBorderKT, btn._pillBgKT = border, bg

    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetFont(CurrentFont(), opts.fontSize or 12)
    text:SetPoint("LEFT", btn, "LEFT", 8, 0)
    text:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)
    text:SetText(label or "")
    btn._pillTextKT = text

    if opts.icon then
        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(opts.iconSize or 14, opts.iconSize or 14)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        icon:SetTexture(opts.icon)
        if opts.iconCoords then icon:SetTexCoord(unpack(opts.iconCoords)) end
        btn._pillIconKT = icon
    end
    btn._pillPrimary = opts.primary and true or false
    btn._pillDanger = opts.danger and true or false
    btn._ringAlways = opts.ringAlways and true or false

    framePieces[btn] = "pill"
    btn:HookScript("OnEnter", function(self) W:PaintPillButton(self, true) end)
    btn:HookScript("OnLeave", function(self) W:PaintPillButton(self, false) end)
    if opts.onClick then btn:SetScript("OnClick", opts.onClick) end
    if opts.steam ~= false then
        -- The "steam" button (W:ApplySteamSkin) replaces the plain pill.
        border:Hide()
        bg:Hide()
        W:ApplySteamSkin(btn)
    end
    W:PaintPillButton(btn, false)
    return btn
end

function W:PaintPillButton(btn, hovered)
    if hovered == nil then hovered = btn._pillHovered end
    btn._pillHovered = hovered and true or false
    if btn._steamKT then return W:PaintSteam(btn) end
    local ar, ag, ab = CurrentAccentColor()
    local accent = { ar, ag, ab, 1 }
    local icon = btn._pillIconKT
    if btn._pillPrimary then
        -- Dark plate warmed by the accent with an accent edge: it leads the
        -- footer without a flat block of bright colour.
        btn._pillBgKT:SetColor(Mix({ SkinColor("controlBg") }, accent, hovered and 0.36 or 0.22))
        btn._pillBorderKT:SetColor(Mix({ SkinColor("cardBorder") }, accent, hovered and 0.95 or 0.6))
        local tr, tg, tb = Mix(accent, { 1, 1, 1, 1 }, hovered and 0.75 or 0.55)
        btn._pillTextKT:SetTextColor(tr, tg, tb, 1)
        if icon then icon:SetVertexColor(tr, tg, tb, 1) end
    else
        btn._pillBgKT:SetColor(SkinColor(hovered and "rowHover" or "controlBg"))
        btn._pillBorderKT:SetColor(Mix({ SkinColor("cardBorder") }, accent, hovered and 0.45 or 0))
        local tr, tg, tb = CurrentTextColor()
        if btn._pillDanger and hovered then tr, tg, tb = 1, 0.42, 0.42 end
        btn._pillTextKT:SetTextColor(tr, tg, tb, 1)
        if icon then
            if hovered then icon:SetVertexColor(ar, ag, ab, 1) else icon:SetVertexColor(CurrentMutedColor()) end
        end
    end
end

-- Sidebar entry skin: a rounded band behind the row with a soft accent halo
-- around it, a 3px accent bar at its left edge and, when opts.chip is set, a
-- rounded chip holding the icon. Hover and the active state ease in and out
-- (W:NavChipState); on hover the chip, and whatever the caller anchored to
-- it, slides a few pixels to the right.
-- opts: inset, right, radius, barHeight, chip ({ w, h, x, radius }), always
-- (the band also shows at rest), card ("full": front, border and back plate
-- like the option cards; "flat": front and border only; "gradient": the
-- accent gradient button, which also paints btn._navLabelKT, _navArrowKT
-- and _navIconKT unless btn._navIconKeep).
-- Gradient rows (opts.card = "gradient"), after the user's gradient button:
-- a 1px rounded ring with a vertical gradient, a faint inner glow line, a
-- face darkening from top to bottom with a lighter band across its middle,
-- and a sheen that fades in on hover. Every colour is a shade of the accent:
-- muted and deep at rest, bright for the selected entry.
local NAV_WHITE = "Interface\\Buttons\\WHITE8x8"
local GRADIENT_FADE = 0.22

local function TexGradient(tex, orientation, c1, c2)
    if tex.SetGradientAlpha then
        tex:SetGradientAlpha(orientation, c1[1], c1[2], c1[3], c1[4] or 1, c2[1], c2[2], c2[3], c2[4] or 1)
    elseif tex.SetGradient and CreateColor then
        tex:SetGradient(orientation, CreateColor(c1[1], c1[2], c1[3], c1[4] or 1), CreateColor(c2[1], c2[2], c2[3], c2[4] or 1))
    else
        tex:SetVertexColor((c1[1] + c2[1]) / 2, (c1[2] + c2[2]) / 2, (c1[3] + c2[3]) / 2, ((c1[4] or 1) + (c2[4] or 1)) / 2)
    end
end

-- Accent shade: grey pulls it towards its own grey, k darkens it.
local function Shade(c, k, grey, alpha)
    local l = c[1] * 0.3 + c[2] * 0.59 + c[3] * 0.11
    return { (c[1] + (l - c[1]) * grey) * k, (c[2] + (l - c[2]) * grey) * k, (c[3] + (l - c[3]) * grey) * k, alpha or 1 }
end

local function Lerp(a, b, t)
    return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, (a[4] or 1) + ((b[4] or 1) - (a[4] or 1)) * t }
end

-- Vertical gradient over a rounded rect: top-row slices take the top colour,
-- bottom-row slices the bottom one, the middle row blends between them.
local function RoundGradient(rr, top, bottom)
    local p = rr.pieces
    for i = 1, 3 do p[i]:SetVertexColor(top[1], top[2], top[3], top[4] or 1) end
    for i = 7, 9 do p[i]:SetVertexColor(bottom[1], bottom[2], bottom[3], bottom[4] or 1) end
    for i = 4, 6 do TexGradient(p[i], "VERTICAL", bottom, top) end
end

-- Horizontal gradient over a rounded rect: left-column slices take the left
-- colour, right-column slices the right one, the middle column blends.
local function RoundGradientH(rr, left, right)
    local p = rr.pieces
    for _, i in ipairs({ 1, 4, 7 }) do p[i]:SetVertexColor(left[1], left[2], left[3], left[4] or 1) end
    for _, i in ipairs({ 3, 6, 9 }) do p[i]:SetVertexColor(right[1], right[2], right[3], right[4] or 1) end
    for _, i in ipairs({ 2, 5, 8 }) do TexGradient(p[i], "HORIZONTAL", left, right) end
end

local function BuildGradientRow(btn, inset, right, radius)
    local function Rect(key, sublevel, r, pad)
        local rr = btn[key] or W:RoundRect(btn, "BACKGROUND", sublevel, r)
        rr:ClearAllPoints()
        rr:SetPoint("TOPLEFT", btn, "TOPLEFT", inset + pad, -1 - pad)
        rr:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -right - pad, 1 + pad)
        btn[key] = rr
        return rr
    end
    -- 1px ring, then a 1px inner glow line, then the face.
    Rect("_gRingKT", 1, radius, 0)
    Rect("_gGlowKT", 2, math.max(2, radius - 1), 1)
    Rect("_gFaceKT", 3, math.max(2, radius - 2), 2)
    -- Halves of the lighter middle band and of the hover sheen, fading out
    -- towards the sides so they never show a seam.
    local cx = (inset - right) / 2
    local function Half(key, sublevel, left)
        local t = btn[key] or btn:CreateTexture(nil, "BACKGROUND", nil, sublevel)
        t:SetTexture(NAV_WHITE)
        t:ClearAllPoints()
        if left then
            t:SetPoint("TOPLEFT", btn, "TOPLEFT", inset + 2, -3)
            t:SetPoint("BOTTOMRIGHT", btn, "BOTTOM", cx, 3)
        else
            t:SetPoint("TOPLEFT", btn, "TOP", cx, -3)
            t:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -right - 2, 3)
        end
        btn[key] = t
    end
    Half("_gMidL", 4, true); Half("_gMidR", 4, false)
    Half("_gHovL", 5, true); Half("_gHovR", 5, false)
end

local function PaintGradientRow(btn, t, a, o)
    local ar, ag, ab = CurrentAccentColor()
    local A = { ar, ag, ab, 1 }
    local W1 = { 1, 1, 1, 1 }
    -- Kept quiet: greyed, dark accent shades at rest; hover lifts them a
    -- little; only the selected entry gets the full accent.
    local lit = math.max(a, 0.2 * o)

    local ringTop = Lerp(Lerp(Shade(A, 0.32, 0.55), Shade(A, 0.46, 0.4), t), Lerp(A, W1, 0.05), lit)
    local ringBottom = Lerp(Lerp(Shade(A, 0.20, 0.4), Shade(A, 0.28, 0.3), t), Shade(A, 0.45, 0.1), lit)
    RoundGradient(btn._gRingKT, ringTop, ringBottom)
    btn._gGlowKT:SetColor(ar, ag, ab, 0.04 + 0.05 * t + 0.12 * a)

    local faceTop = Lerp(Lerp({ 0.05, 0.047, 0.052, 1 }, Shade(A, 0.30, 0.6), 0.18), Shade(A, 0.26, 0.2), 0.45 * a)
    local faceBottom = Lerp(Lerp({ 0.032, 0.03, 0.034, 1 }, Shade(A, 0.20, 0.4), 0.12), Shade(A, 0.16, 0.1), 0.45 * a)
    RoundGradient(btn._gFaceKT, faceTop, faceBottom)

    local mid = Shade(A, 0.12, 0.5, 0.45 + 0.25 * a)
    local edge = { mid[1], mid[2], mid[3], 0 }
    TexGradient(btn._gMidL, "HORIZONTAL", edge, mid)
    TexGradient(btn._gMidR, "HORIZONTAL", mid, edge)

    local sheen = { ar, ag, ab, 0.10 * t }
    local sheenEdge = { ar * 0.3, ag * 0.3, ab * 0.3, 0 }
    TexGradient(btn._gHovL, "HORIZONTAL", sheenEdge, sheen)
    TexGradient(btn._gHovR, "HORIZONTAL", sheen, sheenEdge)
    btn._gHovL:SetShown(t > 0.005)
    btn._gHovR:SetShown(t > 0.005)

    local halo = 0.08 * a
    btn._navGlowOutKT:SetColor(ar, ag, ab, halo)
    btn._navGlowOutKT:SetShown(halo > 0.005)
    btn._navGlowInKT:Hide()
    btn._activeBandKT:Hide()

    -- Label, chevron and icon in light accent tints; white when selected.
    -- Text: a near-white with only a hint of accent at rest.
    local text = Lerp(Lerp(Shade(A, 1, 0.75), W1, 0.62), Lerp(A, W1, 0.85), t)
    text = Lerp(text, W1, a)
    if btn._navLabelKT then btn._navLabelKT:SetTextColor(text[1], text[2], text[3], 1) end
    if btn._navArrowKT then btn._navArrowKT:SetVertexColor(text[1], text[2], text[3], 0.75 + 0.25 * t) end
    if btn._navIconKT and not btn._navIconKeep then
        local ic = Lerp(Lerp(Shade(A, 1, 0.65), W1, 0.45), Lerp(A, W1, 0.5), t)
        ic = Lerp(ic, Lerp(A, W1, 0.08), a)
        btn._navIconKT:SetVertexColor(ic[1], ic[2], ic[3], 1)
    end
    if btn._chipKT then
        btn._chipKT:SetColor(Lerp(Shade(A, 0.10, 0.55), Shade(A, 0.30, 0.1), a))
    end
end

local NAV_FADE, NAV_SLIDE = 0.2, 3

-- Progress is eased (smoothstep) before painting, so fades start and end
-- softly instead of moving at one constant speed.
local function NavEase(p) return p * p * (3 - 2 * p) end

local function PaintNavChip(btn)
    local band, bar, chip = btn._activeBandKT, btn._activeBarKT, btn._chipKT
    if not band then return end
    local t, a, o = NavEase(btn._navHoverP or 0), NavEase(btn._navActiveP or 0), NavEase(btn._navOpenP or 0)
    local ar, ag, ab = CurrentAccentColor()
    local accent = { ar, ag, ab, 1 }

    if btn._navCard == "shine" then
        W:_PaintShineRow(btn, t, a, o)
    elseif btn._navCard == "gradient" then
        PaintGradientRow(btn, t, a, o)
    elseif btn._navCard then
        -- Card rows, like the option cards: front plate, 1px rounded border
        -- and (full cards) a back plate peeking out below that warms with
        -- the accent and spreads on hover.
        local fr, fg, fb, fa = Mix({ SkinColor("card") }, { SkinColor("rowHover") }, 0.6 * t)
        fr, fg, fb = Mix({ fr, fg, fb, 1 }, accent, 0.12 * a)
        band:SetColor(fr, fg, fb, fa)
        band:Show()
        btn._navGlowInKT:SetColor(Mix({ SkinColor("cardBorder") }, { ar * 0.45, ag * 0.45, ab * 0.45, 1 }, math.max(0.6 * t, a)))
        btn._navGlowInKT:Show()
        local halo = 0.10 * a
        btn._navGlowOutKT:SetColor(ar, ag, ab, halo)
        btn._navGlowOutKT:SetShown(halo > 0.005)
        local back = btn._navBackKT
        if back then
            back:SetColor(Mix({ SkinColor("cardBack") }, accent, math.max(t, 0.7 * a)))
            local side = 8 - 4 * t
            back:ClearAllPoints()
            back:SetPoint("TOPLEFT", btn, "TOPLEFT", btn._navInset + side, -6)
            back:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -btn._navRight - side, -(2 + 2 * t))
        end
    else
    -- Hover only lifts the band a shade and draws a faint accent hairline
    -- round it; the warm fill and the halo belong to the active entry.
    local br, bg, bb = Mix({ SkinColor("rowHover") }, accent, 0.14 * a)
    br, bg, bb = Mix({ br, bg, bb, 1 }, { 1, 1, 1, 1 }, 0.035 * t * (1 - a))
    local alpha = math.max(t * 0.85, a, o * 0.55, btn._navAlways and 1 or 0)
    band:SetColor(br, bg, bb, alpha)
    band:SetShown(alpha > 0.01)
    local ring = math.max(0.16 * t, 0.30 * a)
    local halo = 0.11 * a
    btn._navGlowInKT:SetColor(ar, ag, ab, ring)
    btn._navGlowOutKT:SetColor(ar, ag, ab, halo)
    btn._navGlowInKT:SetShown(ring > 0.005)
    btn._navGlowOutKT:SetShown(halo > 0.005)
    end

    bar:SetColorTexture(ar, ag, ab, a)
    bar:SetHeight((btn._navBarH or 16) * (0.4 + 0.6 * a))
    bar:SetShown(a > 0.01)

    if chip then
        if btn._navCard ~= "gradient" and btn._navCard ~= "shine" then
            chip:SetColor(Mix({ SkinColor("controlBg") }, accent, 0.25 * a))
        end
        chip:ClearAllPoints()
        chip:SetSize(btn._navChipW, btn._navChipH)
        chip:SetPoint("LEFT", btn, "LEFT", btn._navChipX + NAV_SLIDE * t, 0)
    end
end

local function StepNavChip(btn, elapsed)
    local step = elapsed / (btn._navFade or NAV_FADE)
    local done = true
    for _, k in ipairs({ "Hover", "Active", "Open" }) do
        local cur, target = btn["_nav" .. k .. "P"] or 0, btn["_nav" .. k .. "T"] or 0
        if cur ~= target then
            cur = (target > cur) and math.min(target, cur + step) or math.max(target, cur - step)
            btn["_nav" .. k .. "P"] = cur
            if cur ~= target then done = false end
        end
    end
    if btn._navCard == "shine" and W:_StepShineRow(btn, elapsed) then done = false end
    PaintNavChip(btn)
    if done then btn:SetScript("OnUpdate", nil) end
end

function W:NavChip(btn, opts)
    opts = opts or {}
    local inset, right = opts.inset or 0, opts.right or 0
    local radius = opts.radius or 9
    local function Plate(key, sublevel, r, grow)
        local rr = btn[key] or W:RoundRect(btn, "BACKGROUND", sublevel, r)
        rr:ClearAllPoints()
        rr:SetPoint("TOPLEFT", btn, "TOPLEFT", inset - grow, -1 + grow)
        rr:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -right + grow, 1 - grow)
        btn[key] = rr
        return rr
    end
    Plate("_navGlowOutKT", -1, radius + 5, 5)
    Plate("_navGlowInKT", 0, radius + 1, 1)
    local band = Plate("_activeBandKT", 1, radius, 0)
    btn._navCard, btn._navInset, btn._navRight = opts.card, inset, right
    if opts.card == "full" then
        btn._navBackKT = btn._navBackKT or W:RoundRect(btn, "BACKGROUND", -2, radius)
    elseif opts.card == "gradient" then
        BuildGradientRow(btn, inset, right, radius)
        btn._navFade = GRADIENT_FADE
    elseif opts.card == "shine" then
        W:_BuildShineRow(btn, inset, right)
        btn._navFade = 0.2
    end

    local bar = btn._activeBarKT or btn:CreateTexture(nil, "ARTWORK", nil, 2)
    bar:ClearAllPoints()
    bar:SetWidth(3)
    bar:SetPoint("LEFT", btn, "LEFT", inset - 1, 0)
    btn._activeBarKT = bar
    btn._navBarH = opts.barHeight or 16

    if opts.chip then
        btn._chipKT = btn._chipKT or W:RoundRect(btn, "ARTWORK", 0, opts.chip.radius or 6)
        btn._navChipW, btn._navChipH = opts.chip.w, opts.chip.h or opts.chip.w
        btn._navChipX = inset + (opts.chip.x or 6)
    end
    btn._navAlways = opts.always and true or false
    framePieces[btn] = "nav"
    W:NavChipState(btn, btn._navState or "rest", btn._navHovered, true)
    return band
end

-- state: "active" (warm band, accent bar and halo), "open" (a faint band,
-- for an open category) or "rest"; "hover" is short for rest + hovered.
-- hovered adds the hover band and halo. instant skips the easing.
function W:NavChipState(btn, state, hovered, instant)
    if state == "hover" then state, hovered = "rest", true end
    btn._navState, btn._navHovered = state, hovered and true or false
    btn._navHoverT = hovered and 1 or 0
    btn._navActiveT = (state == "active") and 1 or 0
    btn._navOpenT = (state == "open") and 1 or 0
    if not btn._activeBandKT then return end
    if instant then
        btn._navHoverP, btn._navActiveP, btn._navOpenP = btn._navHoverT, btn._navActiveT, btn._navOpenT
        PaintNavChip(btn)
    else
        btn:SetScript("OnUpdate", StepNavChip)
        StepNavChip(btn, 0)
    end
end

-- Tabs as a segmented control: a dark rounded track with one rounded segment
-- per tab, the selected one lit with the accent. Rows wrap when the tabs do
-- not fit; opts.single returns nil instead of wrapping.
-- opts: localize, width, single, fontSize. Returns the bar and its height.
local SEG_H, SEG_PAD, SEG_GAP, SEG_TEXT_PAD, SEG_ICON = 28, 3, 4, 12, 14

local function PaintSegments(bar)
    local ar, ag, ab = CurrentAccentColor()
    local accent = { ar, ag, ab, 1 }
    bar._trackKT:SetColor(SkinColor("segmentTrack"))
    for _, seg in ipairs(bar._segmentsKT) do
        local selected = seg._tabId == bar.selectedId
        local r, g, b
        if selected then
            seg._bgKT:Show()
            seg._bgKT:SetColor(Mix({ SkinColor("rowHover") }, accent, 0.16))
            r, g, b = Mix(accent, { 1, 1, 1, 1 }, 0.2)
        elseif seg._hovered then
            seg._bgKT:Show()
            seg._bgKT:SetColor(SkinColor("rowHover"))
            r, g, b = CurrentTextColor()
        else
            seg._bgKT:Hide()
            r, g, b = CurrentMutedColor()
        end
        seg._textKT:SetTextColor(r, g, b, 1)
        if seg._iconKT then seg._iconKT:SetVertexColor(r, g, b, 1) end
    end
end

function W:SegmentedTabs(parent, tabs, selectedId, onSelect, opts)
    opts = opts or {}
    local localize = opts.localize or LText
    local maxW = opts.width or FW(parent)
    if not maxW or maxW <= 0 then maxW = 600 end
    local bar = CreateFrame("Frame", nil, parent)
    bar._trackKT = W:RoundRect(bar, "BACKGROUND", 0, 11)
    bar._trackKT:SetAllPoints(bar)
    bar._segmentsKT = {}
    bar.selectedId = selectedId

    local x, y, rows, widest = SEG_PAD, SEG_PAD, 1, 0
    for _, tab in ipairs(tabs or {}) do
        local seg = CreateFrame("Button", nil, bar)
        local text = seg:CreateFontString(nil, "OVERLAY")
        text:SetFont(CurrentFont(), opts.fontSize or 12)
        text:SetWordWrap(false)
        text:SetText(localize(tab.label or tab.id or ""))
        local iconW = tab.icon and (SEG_ICON + 6) or 0
        local w = math.ceil(text:GetStringWidth() or 0) + SEG_TEXT_PAD * 2 + iconW
        w = math.min(w, maxW - SEG_PAD * 2)
        if x > SEG_PAD and x + w + SEG_PAD > maxW then
            if opts.single then
                bar:Hide()
                return nil, 0
            end
            widest = math.max(widest, x - SEG_GAP + SEG_PAD)
            x, y, rows = SEG_PAD, y + SEG_H + SEG_GAP, rows + 1
        end
        seg:SetSize(w, SEG_H)
        seg:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -y)
        seg._bgKT = W:RoundRect(seg, "BACKGROUND", 1, 8)
        seg._bgKT:SetAllPoints(seg)
        if tab.icon then
            local icon = seg:CreateTexture(nil, "OVERLAY")
            icon:SetSize(SEG_ICON, SEG_ICON)
            icon:SetPoint("LEFT", seg, "LEFT", SEG_TEXT_PAD, 0)
            icon:SetTexture(tab.icon)
            seg._iconKT = icon
        end
        text:SetPoint("LEFT", seg, "LEFT", SEG_TEXT_PAD + iconW, 0)
        text:SetPoint("RIGHT", seg, "RIGHT", -SEG_TEXT_PAD, 0)
        text:SetJustifyH(tab.icon and "LEFT" or "CENTER")
        seg._textKT = text
        seg._tabId, seg._tab = tab.id, tab
        seg:SetScript("OnClick", function(self)
            bar.selectedId = self._tabId
            PaintSegments(bar)
            if onSelect then onSelect(self._tabId, self._tab) end
        end)
        seg:SetScript("OnEnter", function(self) self._hovered = true; PaintSegments(bar) end)
        seg:SetScript("OnLeave", function(self) self._hovered = nil; PaintSegments(bar) end)
        bar._segmentsKT[#bar._segmentsKT + 1] = seg
        x = x + w + SEG_GAP
    end
    widest = math.max(widest, x - SEG_GAP + SEG_PAD)
    local h = rows * SEG_H + (rows - 1) * SEG_GAP + SEG_PAD * 2
    bar:SetSize(widest, h)
    framePieces[bar] = "tabs"
    PaintSegments(bar)
    return bar, h
end

-- Page tab bar after the user's "steam" CSS button: a dark rounded face
-- (#141414, 8px corners) inside a 2px rounded ring painted with a diagonal
-- black / grey / light-grey gradient, plus a soft halo standing in for the
-- blurred copy. The gradient only travels while the cursor is over the tab
-- or it is pressed; at rest the ring sits still and nearly black. The
-- selected tab keeps an accent ring and accent-tinted label. Tabs size to
-- their labels and fill the width; returns nil when they cannot fit a row.
-- opts: localize, width, height, gap, fontSize. Returns the bar and its height.
local STEAM_STOPS = {
    { 0.078, 0.078, 0.078 }, { 0.106, 0.106, 0.106 }, { 0.180, 0.180, 0.180 },
    { 0.882, 0.882, 0.882 }, { 0.180, 0.180, 0.180 }, { 0.106, 0.106, 0.106 },
    { 0.078, 0.078, 0.078 }, { 0.078, 0.078, 0.078 },
}
local STEAM_FACE = { 0.078, 0.078, 0.078, 1 }
local STEAM_RING, STEAM_RADIUS, STEAM_SEGMENTS = 2, 10, 8
local STEAM_PERIOD = 2.4    -- there and back (the CSS takes 20s; too slow under a cursor)
local STEAM_FADE = 0.12     -- quicker than the CSS .2s so hover feels immediate
local TAB_ICON = 14
local WHITE_TEX = "Interface\\Buttons\\WHITE8x8"

-- The light stop and the greys next to it take the accent, so the travelling
-- light is the accent colour; the dark stops stay near black.
local function SetSteamAccent()
    local ar, ag, ab = CurrentAccentColor()
    STEAM_STOPS[3] = { 0.06 + ar * 0.22, 0.06 + ag * 0.22, 0.06 + ab * 0.22 }
    STEAM_STOPS[4] = { ar + (1 - ar) * 0.25, ag + (1 - ag) * 0.25, ab + (1 - ab) * 0.25 }
    STEAM_STOPS[5] = STEAM_STOPS[3]
end

-- The gradient is 4x the button (background-size: 400%); s runs over it.
local function SteamColor(s)
    local t = (s % 4) / 4 * 7
    local i = math.floor(t)
    local f = t - i
    local a, b = STEAM_STOPS[i + 1], STEAM_STOPS[math.min(i + 2, #STEAM_STOPS)]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

local function SetTexGradient(tex, orientation, r1, g1, b1, r2, g2, b2)
    if tex.SetGradientAlpha then
        tex:SetGradientAlpha(orientation, r1, g1, b1, 1, r2, g2, b2, 1)
    elseif tex.SetGradient and CreateColor then
        tex:SetGradient(orientation, CreateColor(r1, g1, b1, 1), CreateColor(r2, g2, b2, 1))
    else
        tex:SetVertexColor((r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2, 1)
    end
end

-- Ring colour at (x, y) of the ring box (y down from the top): the 45deg
-- gradient position plus the travelling phase, eased between the still
-- rest look and the moving one, and pulled to the accent on the selected tab.
local function RingColor(tab, x, y)
    local u = ((x / tab._ringW) + (1 - y / tab._ringH)) / 2
    local hp = tab._hoverP or 0
    local r0, g0, b0 = SteamColor(u)
    if tab._ringAlways then
        -- Always-on border: a still accent gradient at rest.
        local ar, ag, ab = CurrentAccentColor()
        local k = 0.38 + 0.32 * u
        r0, g0, b0 = ar * k, ag * k, ab * k
    end
    local r1, g1, b1 = SteamColor(u + (tab._phase or 0))
    local r, g, b = r0 + (r1 - r0) * hp, g0 + (g1 - g0) * hp, b0 + (b1 - b0) * hp
    if tab._selected then
        local ar, ag, ab = CurrentAccentColor()
        local k = 0.75 - 0.45 * hp
        r, g, b = r + (ar - r) * k, g + (ag - g) * k, b + (ab - b) * k
    end
    return r, g, b
end

-- Paints a ring built by BuildPageTabRing with colour(x, y) over the ring
-- box (y down from the top): corners take their centre, edge segments blend.
local function PaintRingWith(tab, colour)
    local ring = tab._ringKT
    local W, H, R = tab._ringW, tab._ringH, tab._ringR or STEAM_RADIUS
    local cx = { R / 2, W - R / 2, R / 2, W - R / 2 }
    local cy = { R / 2, R / 2, H - R / 2, H - R / 2 }
    for i = 1, 4 do ring.corners[i]:SetVertexColor(colour(cx[i], cy[i])) end
    local segW = (W - 2 * R) / STEAM_SEGMENTS
    for i = 1, STEAM_SEGMENTS do
        local x1, x2 = R + (i - 1) * segW, R + i * segW
        local r1, g1, b1 = colour(x1, 0)
        local r2, g2, b2 = colour(x2, 0)
        SetTexGradient(ring.top[i], "HORIZONTAL", r1, g1, b1, r2, g2, b2)
        r1, g1, b1 = colour(x1, H)
        r2, g2, b2 = colour(x2, H)
        SetTexGradient(ring.bottom[i], "HORIZONTAL", r1, g1, b1, r2, g2, b2)
    end
    -- VERTICAL gradients go from the bottom colour to the top one.
    local rb, gb, bb = colour(0, H - R)
    local rt, gt, bt = colour(0, R)
    SetTexGradient(ring.left, "VERTICAL", rb, gb, bb, rt, gt, bt)
    rb, gb, bb = colour(W, H - R)
    rt, gt, bt = colour(W, R)
    SetTexGradient(ring.right, "VERTICAL", rb, gb, bb, rt, gt, bt)
end

local function PaintPageTab(tab)
    SetSteamAccent()
    local W, H = tab._ringW, tab._ringH
    PaintRingWith(tab, function(x, y) return RingColor(tab, x, y) end)

    -- Halo: the blurred copy, bright only while the light passes by.
    local light = 0
    for _, p in ipairs({ { 0, 0 }, { W, 0 }, { 0, H }, { W, H }, { W / 2, 0 }, { W / 2, H } }) do
        local r, g, b = RingColor(tab, p[1], p[2])
        light = math.max(light, r, g, b)
    end
    local hp = tab._hoverP or 0
    local glow = math.max(0, light - 0.18) * 0.22 * hp
    local ar, ag, ab = CurrentAccentColor()
    tab._haloInKT:SetColor(ar, ag, ab, glow)
    tab._haloOutKT:SetColor(ar, ag, ab, glow * 0.45)
    tab._haloInKT:SetShown(glow > 0.003)
    tab._haloOutKT:SetShown(glow > 0.003)

    if tab._selected then
        tab._faceKT:SetColor(Mix(STEAM_FACE, { ar, ag, ab, 1 }, 0.12))
        tab._textKT:SetTextColor(Mix({ ar, ag, ab, 1 }, { 1, 1, 1, 1 }, 0.3))
    else
        tab._faceKT:SetColor(unpack(STEAM_FACE))
        tab._textKT:SetTextColor(1, 1, 1, 1)
    end
    if tab._iconKT then tab._iconKT:SetVertexColor(ar, ag, ab, 1) end
    if tab._pillDanger and tab._hovered then tab._textKT:SetTextColor(1, 0.42, 0.42, 1) end
end

local function StepPageTab(tab, elapsed)
    elapsed = elapsed or 0
    local target = (tab._hovered or tab._pressed) and 1 or 0
    local hp = tab._hoverP or 0
    local step = elapsed / STEAM_FADE
    hp = (target > hp) and math.min(target, hp + step) or math.max(target, hp - step)
    tab._hoverP = hp
    if hp > 0 then
        -- background-position 0 -> 400% -> 0: the phase runs 0..3 and back.
        tab._clock = ((tab._clock or 0) + elapsed) % STEAM_PERIOD
        local half = STEAM_PERIOD / 2
        local t = tab._clock < half and tab._clock / half or (STEAM_PERIOD - tab._clock) / half
        tab._phase = 3 * t
    end
    PaintPageTab(tab)
    if hp == 0 and target == 0 then tab:SetScript("OnUpdate", nil) end
end

local function BuildPageTabRing(tab)
    local ring = { corners = {}, top = {}, bottom = {} }
    local disc = PartPath("round_disc")
    local quarter = { ROUND_COORDS[1], ROUND_COORDS[3], ROUND_COORDS[7], ROUND_COORDS[9] }
    local points = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
    local k = tab._ringK or STEAM_RING
    local off = { { -k, k }, { k, k }, { -k, -k }, { k, -k } }
    for i = 1, 4 do
        local t = tab:CreateTexture(nil, "BACKGROUND", nil, 0)
        t:SetTexture(disc)
        t:SetTexCoord(unpack(quarter[i]))
        t:SetSize(tab._ringR or STEAM_RADIUS, tab._ringR or STEAM_RADIUS)
        t:SetPoint(points[i], tab, points[i], off[i][1], off[i][2])
        ring.corners[i] = t
    end
    for i = 1, STEAM_SEGMENTS do
        ring.top[i] = tab:CreateTexture(nil, "BACKGROUND", nil, 0)
        ring.bottom[i] = tab:CreateTexture(nil, "BACKGROUND", nil, 0)
        ring.top[i]:SetTexture(WHITE_TEX)
        ring.bottom[i]:SetTexture(WHITE_TEX)
    end
    ring.left = tab:CreateTexture(nil, "BACKGROUND", nil, 0)
    ring.right = tab:CreateTexture(nil, "BACKGROUND", nil, 0)
    ring.left:SetTexture(WHITE_TEX)
    ring.right:SetTexture(WHITE_TEX)
    -- Segment edges fall on fractions of a pixel; letting the client snap
    -- each one again opened 1px gaps in the ring.
    local function NoSnap(t)
        if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
        if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
    end
    for i = 1, 4 do NoSnap(ring.corners[i]) end
    for i = 1, STEAM_SEGMENTS do NoSnap(ring.top[i]); NoSnap(ring.bottom[i]) end
    NoSnap(ring.left); NoSnap(ring.right)
    tab._ringKT = ring
end

local function LayoutPageTabRing(tab, w, h)
    local ring, R, k = tab._ringKT, tab._ringR or STEAM_RADIUS, tab._ringK or STEAM_RING
    tab._ringW, tab._ringH = w + 2 * k, h + 2 * k
    local segW = (tab._ringW - 2 * R) / STEAM_SEGMENTS
    -- Each segment (and the side strips) overlaps its neighbours and the
    -- corners by 1px so no seam can open between them.
    for i = 1, STEAM_SEGMENTS do
        local x = -k + R + (i - 1) * segW - 1
        ring.top[i]:ClearAllPoints()
        ring.top[i]:SetPoint("TOPLEFT", tab, "TOPLEFT", x, k)
        ring.top[i]:SetSize(segW + 2, k + 2)
        ring.bottom[i]:ClearAllPoints()
        ring.bottom[i]:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", x, -k)
        ring.bottom[i]:SetSize(segW + 2, k + 2)
    end
    ring.left:ClearAllPoints()
    ring.left:SetPoint("TOPLEFT", tab, "TOPLEFT", -k, -(R - k) + 1)
    ring.left:SetSize(k + 2, tab._ringH - 2 * R + 2)
    ring.right:ClearAllPoints()
    ring.right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", k, -(R - k) + 1)
    ring.right:SetSize(k + 2, tab._ringH - 2 * R + 2)
end

local function AddSteamHalo(btn)
    btn._haloOutKT = W:RoundRect(btn, "BACKGROUND", -2, 17)
    btn._haloOutKT:SetPoint("TOPLEFT", btn, "TOPLEFT", -9, 9)
    btn._haloOutKT:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 9, -9)
    btn._haloInKT = W:RoundRect(btn, "BACKGROUND", -1, 12)
    btn._haloInKT:SetPoint("TOPLEFT", btn, "TOPLEFT", -4, 4)
    btn._haloInKT:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 4, -4)
end

-- The same "steam" look on a frame button (W:PillButton): a primary button
-- keeps the accent ring the selected tab has.
function W:ApplySteamSkin(btn)
    AddSteamHalo(btn)
    BuildPageTabRing(btn)
    btn._faceKT = W:RoundRect(btn, "BACKGROUND", 2, 8)
    btn._faceKT:SetAllPoints(btn)
    btn._textKT = btn._pillTextKT
    btn._iconKT = btn._pillIconKT
    btn._selected = btn._pillPrimary
    btn._steamKT = true
    LayoutPageTabRing(btn, btn:GetWidth() or 0, btn:GetHeight() or 0)
    btn:HookScript("OnSizeChanged", function(self, w, h) LayoutPageTabRing(self, w or self:GetWidth(), h or self:GetHeight()); PaintPageTab(self) end)
    local function Animate(self) self:SetScript("OnUpdate", StepPageTab) end
    btn:HookScript("OnEnter", function(self) self._hovered = true; Animate(self) end)
    btn:HookScript("OnLeave", function(self) self._hovered = nil; self._pressed = nil; Animate(self) end)
    btn:HookScript("OnMouseDown", function(self) self._pressed = true; Animate(self) end)
    btn:HookScript("OnMouseUp", function(self) self._pressed = nil; Animate(self) end)
    PaintPageTab(btn)
end

function W:PaintSteam(btn) PaintPageTab(btn) end

-- Shine rows (NavChip card = "shine"), after the user's "Get Started"
-- button: a black rounded face over a 2px ring cut from a soft two-tone
-- accent gradient (deep to light) that spins while the cursor is over the
-- row. (The CSS streak sweeping across on hover is left out on request;
-- _shineSweep still drives it if set.)
-- The selected entry gets a brighter ring. Its layers live on a frame below
-- the button, so the button's own icon and label stay on top.
local SHINE_SPIN = 1.4      -- seconds per turn while hovered
local SHINE_RADIUS = 6      -- squarer than the tabs: corners only softened
local NAV_GLOW_TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\PortalRadial.tga"
local SHINE_SWEEP = 0.7

function W:_BuildShineRow(btn, inset, right)
    local host = btn._shineHostKT
    if not host then
        local level = btn:GetFrameLevel() or 3
        host = CreateFrame("Frame", nil, btn)
        host:SetFrameLevel(math.max(0, level - 3))
        host._ringR = SHINE_RADIUS
        BuildPageTabRing(host)
        host._faceKT = W:RoundRect(host, "BACKGROUND", 2, SHINE_RADIUS - 2)
        host._faceKT:SetAllPoints(host)
        -- Selected entry: an accent wash fading from left to right.
        host._fillKT = W:RoundRect(host, "BACKGROUND", 3, SHINE_RADIUS - 2)
        host._fillKT:SetAllPoints(host)
        local clip = CreateFrame("Frame", nil, host)
        clip:SetFrameLevel(math.max(0, level - 2))
        clip:SetPoint("TOPLEFT", host, "TOPLEFT", 2, -2)
        clip:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 2)
        if clip.SetClipsChildren then clip:SetClipsChildren(true) end
        local sheen = CreateFrame("Frame", nil, clip)
        sheen:SetFrameLevel(math.max(0, level - 1))
        sheen:SetAllPoints(clip)
        local streak = sheen:CreateTexture(nil, "ARTWORK")
        streak:SetTexture(WHITE_TEX)
        streak:Hide()
        host._streakKT, host._clipKT = streak, clip
        host:SetScript("OnSizeChanged", function(self, w, h)
            if (w or 0) > 0 and (h or 0) > 0 then
                LayoutPageTabRing(self, w, h)
                W:_PaintShineRow(btn)
            end
        end)
        btn._shineHostKT = host
    end
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", btn, "TOPLEFT", inset + STEAM_RING, -1 - STEAM_RING)
    host:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -right - STEAM_RING, 1 + STEAM_RING)
    local w, h = host:GetWidth() or 0, host:GetHeight() or 0
    if w > 0 and h > 0 then LayoutPageTabRing(host, w, h) end
end

function W:_PaintShineRow(btn, t, a, o)
    if t then btn._shineState = { t, a, o } end
    local st = btn._shineState or { 0, 0, 0 }
    t, a, o = st[1], st[2], st[3]
    local host = btn._shineHostKT
    local ar, ag, ab = CurrentAccentColor()
    local A, W1 = { ar, ag, ab, 1 }, { 1, 1, 1, 1 }
    local lit = math.max(a, 0.25 * o)

    if host and host._ringW and host._ringW > 0 then
        local c1 = Lerp(Shade(A, 0.42, 0.2), Shade(A, 0.75, 0), lit)
        local c2 = Lerp(Lerp(A, W1, 0.25), Lerp(A, W1, 0.45), lit)
        local k = 0.55 + 0.45 * math.max(t, lit)
        -- The spin only shows while hovered: at rest every row paints the
        -- same still gradient, wherever its last spin stopped.
        local rot = btn._shineRot or 0
        local w, h = host._ringW, host._ringH
        PaintRingWith(host, function(x, y)
            local ang = math.atan2(h / 2 - y, x - w / 2)
            local m = 0.5 + 0.5 * (math.cos(ang) + (math.cos(ang - rot) - math.cos(ang)) * t)
            return (c1[1] + (c2[1] - c1[1]) * m) * k, (c1[2] + (c2[2] - c1[2]) * m) * k, (c1[3] + (c2[3] - c1[3]) * m) * k
        end)
        -- The blurred blob shows faintly through the 90% face.
        host._faceKT:SetColor(Lerp({ 0.018, 0.017, 0.02, 0.93 }, Shade(A, 0.22, 0.2, 0.93), 0.16))
        if host._fillKT then
            RoundGradientH(host._fillKT, { ar, ag, ab, 0.17 * a }, { ar, ag, ab, 0 })
            host._fillKT:SetShown(a > 0.01)
        end

        local streak = host._streakKT
        local sweep = btn._shineSweep
        local cw = host._clipKT:GetWidth() or 0
        if sweep and cw > 0 then
            local e = sweep * sweep
            local sw = math.max(40, cw * 0.35)
            streak:ClearAllPoints()
            streak:SetPoint("TOPLEFT", host._clipKT, "TOPLEFT", -sw + (cw + sw) * e, 0)
            streak:SetPoint("BOTTOMLEFT", host._clipKT, "BOTTOMLEFT", -sw + (cw + sw) * e, 0)
            streak:SetWidth(sw)
            local g = Lerp({ 0.42, 0.42, 0.45, 1 }, A, 0.35)
            TexGradient(streak, "HORIZONTAL", { g[1], g[2], g[3], 0.30 }, { 1, 1, 1, 0.03 })
            streak:Show()
        else
            streak:Hide()
        end
    end

    local halo = 0.08 * a
    btn._navGlowOutKT:SetColor(ar, ag, ab, halo)
    btn._navGlowOutKT:SetShown(halo > 0.005)
    btn._navGlowInKT:Hide()
    btn._activeBandKT:Hide()

    -- Only the selected entry lights its icon and label with the accent;
    -- the rest stay neutral grey and brighten a little under the cursor.
    local neutral = Lerp({ 0.80, 0.80, 0.82, 1 }, W1, t)
    local text = Lerp(neutral, Lerp(A, W1, 0.35), a)
    if btn._navLabelKT then btn._navLabelKT:SetTextColor(text[1], text[2], text[3], 1) end
    if btn._navArrowKT then btn._navArrowKT:SetVertexColor(neutral[1], neutral[2], neutral[3], 0.7 + 0.3 * t) end
    -- Flat icon in the accent (a little lighter under the cursor); the
    -- selected entry gets a soft accent glow behind it.
    if btn._navIconKT and not btn._navIconKeep then
        local ic = Lerp(A, W1, 0.25 * t * (1 - a))
        btn._navIconKT:SetVertexColor(ic[1], ic[2], ic[3], 1)
    end
    if btn._chipKT then
        btn._chipKT:Hide()
        local glow = btn._iconGlowKT
        if not glow then
            glow = btn:CreateTexture(nil, "ARTWORK", nil, 0)
            glow:SetTexture(NAV_GLOW_TEX)
            btn._iconGlowKT = glow
        end
        local d = (btn._navChipH or 30) * 1.45
        glow:ClearAllPoints()
        glow:SetPoint("CENTER", btn._chipKT.box, "CENTER", 0, 0)
        glow:SetSize(d, d)
        glow:SetVertexColor(ar, ag, ab, 0.32 * a)
        glow:SetShown(a > 0.01)
    end
end

-- Spin and sweep clocks, run from the row's OnUpdate. Returns true while
-- something still moves.
function W:_StepShineRow(btn, elapsed)
    local moving = false
    if btn._navHoverT == 1 then
        btn._shineRot = ((btn._shineRot or 0) + elapsed * 2 * math.pi / SHINE_SPIN) % (2 * math.pi)
        moving = true
    end
    if btn._shineSweep then
        btn._shineSweep = btn._shineSweep + elapsed / SHINE_SWEEP
        if btn._shineSweep >= 1 then btn._shineSweep = nil else moving = true end
    end
    return moving
end

-- Module cards for the category pages, after the user's gradient-border
-- card CSS, in accent shades instead of the rainbow: a face fading from
-- near black at the bottom to dark grey at the top (10px corners) inside a
-- 2px ring painted with a 45-degree band of accent shades that travels
-- there and back (background-size 400%), and a soft accent halo for the
-- blurred copy. The ring always moves, slowly; hover brightens it and the
-- halo. Icon, name and description sit centred.
-- opts: width, height, icon (texture path), iconCoords, iconKeep (icon has
-- its own colours), title, description, onClick. Returns the card.
local MCARD_PERIOD, MCARD_FADE = 12, 0.2

local function CardRingColour(card)
    local ar, ag, ab = CurrentAccentColor()
    local A, W1 = { ar, ag, ab, 1 }, { 1, 1, 1, 1 }
    local stops = { Shade(A, 0.35, 0), A, Lerp(A, W1, 0.45), Shade(A, 0.6, 0), A }
    local n = #stops
    local k = 0.72 + 0.28 * NavEase(card._hoverP or 0)
    local W, H = card._ringW, card._ringH
    local phase = card._phase or 0
    return function(x, y)
        -- 45deg position over a gradient four times the card (400%).
        local u = (((x / W) + (1 - y / H)) / 2 + phase) / 4
        local t = (u % 1) * (n - 1)
        local i = math.floor(t)
        local a, b = stops[i + 1], stops[math.min(i + 2, n)]
        local f = t - i
        return (a[1] + (b[1] - a[1]) * f) * k, (a[2] + (b[2] - a[2]) * f) * k, (a[3] + (b[3] - a[3]) * f) * k
    end
end

local function PaintModuleCard(card)
    local ar, ag, ab = CurrentAccentColor()
    if card._ringW and card._ringW > 0 then PaintRingWith(card, CardRingColour(card)) end
    -- linear-gradient(0deg, #000, #272727): black at the bottom.
    RoundGradient(card._faceKT, { 0.153, 0.153, 0.153, 1 }, { 0, 0, 0, 1 })
    local e = NavEase(card._hoverP or 0)
    card._haloInKT:SetColor(ar, ag, ab, 0.10 + 0.10 * e)
    card._haloOutKT:SetColor(ar, ag, ab, 0.05 + 0.05 * e)
    if not card._iconKeep then card._iconKT:SetVertexColor(ar, ag, ab, 1) end
    card._titleKT:SetTextColor(1, 1, 1, 1)
    local mr, mg, mb = CurrentMutedColor()
    card._descKT:SetTextColor(mr, mg, mb, 1)
end

local function StepModuleCard(card, elapsed)
    elapsed = elapsed or 0
    card._clock = ((card._clock or 0) + elapsed) % MCARD_PERIOD
    local half = MCARD_PERIOD / 2
    local p = card._clock < half and card._clock / half or (MCARD_PERIOD - card._clock) / half
    card._phase = 3 * p   -- background-position 0 -> 400% -> 0
    local target = card._hovered and 1 or 0
    local h = card._hoverP or 0
    local step = elapsed / MCARD_FADE
    card._hoverP = (target > h) and math.min(target, h + step) or math.max(target, h - step)
    PaintModuleCard(card)
end

function W:ModuleCard(parent, opts)
    opts = opts or {}
    local w, h = opts.width or 296, opts.height or 200
    local card = CreateFrame("Button", nil, parent)
    card:SetSize(w, h)
    AddSteamHalo(card)
    BuildPageTabRing(card)
    LayoutPageTabRing(card, w, h)
    card._faceKT = W:RoundRect(card, "BACKGROUND", 2, 8)
    card._faceKT:SetAllPoints(card)

    card._iconKT = card:CreateTexture(nil, "ARTWORK")
    if opts.icon then card._iconKT:SetTexture(opts.icon) end
    if opts.iconCoords then card._iconKT:SetTexCoord(unpack(opts.iconCoords)) end
    card._iconKT:SetSize(66, 44)
    card._iconKT:SetPoint("CENTER", card, "CENTER", 0, 26)
    card._iconKeep = opts.iconKeep and true or false
    card._titleKT = card:CreateFontString(nil, "OVERLAY")
    card._titleKT:SetFont(CurrentFont(), 16, "OUTLINE")
    card._titleKT:SetJustifyH("CENTER")
    card._titleKT:SetWordWrap(false)
    card._titleKT:SetWidth(w - 30)
    card._titleKT:SetText(opts.title or "")
    card._titleKT:SetPoint("TOP", card._iconKT, "BOTTOM", 0, -12)
    card._descKT = card:CreateFontString(nil, "OVERLAY")
    card._descKT:SetFont(CurrentFont(), 11, "")
    card._descKT:SetJustifyH("CENTER")
    card._descKT:SetWordWrap(true)
    if card._descKT.SetMaxLines then card._descKT:SetMaxLines(2) end
    card._descKT:SetWidth(w - 40)
    card._descKT:SetText(opts.description or "")
    card._descKT:SetPoint("TOP", card._titleKT, "BOTTOM", 0, -6)

    card:SetScript("OnEnter", function(self) self._hovered = true end)
    card:SetScript("OnLeave", function(self) self._hovered = nil end)
    card:SetScript("OnSizeChanged", function(self, cw, ch)
        if (cw or 0) > 0 and (ch or 0) > 0 then LayoutPageTabRing(self, cw, ch) end
    end)
    if opts.onClick then card:SetScript("OnClick", opts.onClick) end
    -- The ring keeps travelling while the card is shown (OnUpdate pauses
    -- while it is hidden).
    card:SetScript("OnUpdate", StepModuleCard)

    framePieces[card] = "mcard"
    card._clock, card._phase = 0, 0
    PaintModuleCard(card)
    return card
end

-- Enhancements focus cards, after the user's spinning-border card CSS, in
-- accent shades: a dark rounded face inside a 4px ring painted by four
-- radial blobs sitting at the corners (light, accent, mid and deep accent)
-- that wander round (bg-spin, 3s), a blurred copy of it as a soft halo, and
-- ten accent points drifting down and to the right inside the card, fading
-- out as they go (floating-points). The selected card burns brighter;
-- hover lifts the ring and the halo.
-- opts: width, title, description, icon, iconCoords, iconColor ({r,g,b},
-- the accent when absent), active, onClick. Returns the card and its height.
local FOCUS_R, FOCUS_RING, FOCUS_SPIN = 12, 4, 3
-- A sparse, faint selection of the CSS points (four of ten, at ~35%), so
-- they never compete with the text drawn above them.
local FOCUS_POINTS = {
    { left = 0.10, alpha = 0.35, dur = 2.35, delay = 0.2 },
    { left = 0.44, alpha = 0.25, dur = 2.05, delay = 0 },
    { left = 0.75, alpha = 0.20, dur = 1.5, delay = 1.5 },
    { left = 0.98, alpha = 0.25, dur = 2.6, delay = 0.1 },
}

local function FocusRingColour(card)
    local ar, ag, ab = CurrentAccentColor()
    local A, W1 = { ar, ag, ab, 1 }, { 1, 1, 1, 1 }
    local W, H = card._ringW, card._ringH
    local lit = math.max(card._active and 1 or 0, 0.6 * NavEase(card._hoverP or 0))
    local k = 0.55 + 0.45 * lit
    -- Four corner blobs (0 100%, 100% 0, 100% 100%, 0 0) whose centres
    -- wander as the 400% background moves.
    local ph = (card._clock or 0) / FOCUS_SPIN * 2 * math.pi
    local dx, dy = math.sin(ph) * W * 0.35, math.cos(ph) * H * 0.35
    local blobs = {
        { 0 + dx, H - dy, Lerp(A, W1, 0.35) },
        { W - dx, 0 + dy, A },
        { W + dy, H + dx, Shade(A, 0.62, 0) },
        { 0 - dy, 0 - dx, Shade(A, 0.35, 0.1) },
    }
    local reach = math.max(W, H) * 0.85
    return function(x, y)
        local r, g, b = 0, 0, 0
        for _, blob in ipairs(blobs) do
            local d = math.sqrt((x - blob[1]) ^ 2 + (y - blob[2]) ^ 2)
            local f = math.max(0, 1 - d / reach)
            r, g, b = r + blob[3][1] * f, g + blob[3][2] * f, b + blob[3][3] * f
        end
        return math.min(1, r) * k, math.min(1, g) * k, math.min(1, b) * k
    end
end

local function PaintFocusCard(card)
    local ar, ag, ab = CurrentAccentColor()
    if card._ringW and card._ringW > 0 then PaintRingWith(card, FocusRingColour(card)) end
    card._faceKT:SetColor(0.075, 0.072, 0.082, 1)
    local lit = math.max(card._active and 1 or 0, 0.6 * NavEase(card._hoverP or 0))
    card._haloInKT:SetColor(ar, ag, ab, 0.08 + 0.14 * lit)
    card._haloOutKT:SetColor(ar, ag, ab, 0.04 + 0.08 * lit)
    local ic = card._iconColor
    card._iconKT:SetVertexColor(ic and ic[1] or ar, ic and ic[2] or ag, ic and ic[3] or ab, 1)
    local tr, tg, tb = CurrentTextColor()
    local t = Lerp({ 0.86, 0.86, 0.88, 1 }, { tr, tg, tb, 1 }, lit)
    card._titleKT:SetTextColor(t[1], t[2], t[3], 1)
    local mr, mg, mb = CurrentMutedColor()
    card._descKT:SetTextColor(mr, mg, mb, 1)
    local pc = Lerp({ ar, ag, ab, 1 }, { 1, 1, 1, 1 }, 0.3)
    for _, pt in ipairs(card._pointsKT) do pt.tex:SetVertexColor(pc[1], pc[2], pc[3], 1) end
end

local function StepFocusCard(card, elapsed)
    elapsed = elapsed or 0
    card._clock = (card._clock or 0) + elapsed
    local target = card._hovered and 1 or 0
    local h = card._hoverP or 0
    card._hoverP = (target > h) and math.min(target, h + elapsed / 0.5) or math.max(target, h - elapsed / 0.5)
    -- floating-points: each point travels (h/1.75, h/1.5) and fades at 95%.
    local ch = card:GetHeight() or 0
    local cw = card._pointsW or 0
    for _, pt in ipairs(card._pointsKT) do
        local t = card._clock - pt.delay
        local u = t < 0 and 0 or ((t % pt.dur) / pt.dur)
        local e = u * u * (3 - 2 * u)
        pt.tex:ClearAllPoints()
        pt.tex:SetPoint("TOPLEFT", card._pointLayerKT, "TOPLEFT", cw * pt.left + e * ch / 1.75, 8 - e * ch / 1.5)
        local fade = u < 0.95 and 1 or 0
        pt.tex:SetAlpha(pt.alpha * fade * (t < 0 and 0 or 1))
    end
    PaintFocusCard(card)
end

function W:FocusCard(parent, opts)
    opts = opts or {}
    local w = opts.width or 198
    local pad = 12
    local card = CreateFrame("Button", nil, parent)
    card._active = opts.active and true or false
    AddSteamHalo(card)
    card._ringR, card._ringK = FOCUS_R, FOCUS_RING
    BuildPageTabRing(card)
    card._faceKT = W:RoundRect(card, "BACKGROUND", 2, FOCUS_R - 4)
    card._faceKT:SetAllPoints(card)

    -- Points float inside the face, clipped to it.
    local clip = CreateFrame("Frame", nil, card)
    clip:SetAllPoints(card)
    if clip.SetClipsChildren then clip:SetClipsChildren(true) end
    local layer = CreateFrame("Frame", nil, clip)
    layer:SetAllPoints(clip)
    card._pointLayerKT = layer
    card._pointsKT = {}
    for _, def in ipairs(FOCUS_POINTS) do
        local tex = layer:CreateTexture(nil, "ARTWORK")
        tex:SetTexture(PartPath("round_disc"))
        tex:SetSize(3, 3)
        card._pointsKT[#card._pointsKT + 1] = { tex = tex, left = def.left, alpha = def.alpha, dur = def.dur, delay = def.delay }
    end

    -- Texts well above the points' layer.
    local text = CreateFrame("Frame", nil, card)
    text:SetAllPoints(card)
    text:SetFrameLevel((layer:GetFrameLevel() or 1) + 8)
    card._iconColor = opts.iconColor
    card._iconKT = text:CreateTexture(nil, "OVERLAY")
    if opts.icon then card._iconKT:SetTexture(opts.icon) end
    if opts.iconCoords then card._iconKT:SetTexCoord(unpack(opts.iconCoords)) end
    card._iconKT:SetSize(22, 22)
    card._iconKT:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -pad)
    card._titleKT = text:CreateFontString(nil, "OVERLAY")
    card._titleKT:SetFont(CurrentFont(), 12, "OUTLINE")
    card._titleKT:SetJustifyH("LEFT")
    card._titleKT:SetWordWrap(true)
    card._titleKT:SetWidth(w - pad * 2 - 30)
    card._titleKT:SetPoint("LEFT", card._iconKT, "RIGHT", 8, 0)
    card._titleKT:SetText(opts.title or "")
    card._descKT = text:CreateFontString(nil, "OVERLAY")
    card._descKT:SetFont(CurrentFont(), 9, "")
    card._descKT:SetJustifyH("LEFT")
    card._descKT:SetJustifyV("TOP")
    card._descKT:SetWordWrap(true)
    card._descKT:SetWidth(w - pad * 2)
    card._descKT:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -(pad + 22 + 8))
    card._descKT:SetText(opts.description or "")

    local height = math.max(88, pad + 22 + 8 + math.max(22, card._descKT:GetStringHeight() or 0) + 14)
    card:SetSize(w, height)
    -- The ring sits just outside the face, like the CSS padding border.
    LayoutPageTabRing(card, w, height)
    card._pointsW = w

    function card:SetActive(active)
        self._active = active and true or false
        PaintFocusCard(self)
    end
    card:SetScript("OnEnter", function(self) self._hovered = true end)
    card:SetScript("OnLeave", function(self) self._hovered = nil end)
    if opts.onClick then card:SetScript("OnClick", opts.onClick) end
    -- The border and the points keep moving while the card is shown.
    card:SetScript("OnUpdate", StepFocusCard)

    framePieces[card] = "focus"
    card._clock = 0
    StepFocusCard(card, 0)
    return card, height
end

-- Cut-corner button, after the user's gradient-border button CSS, in accent
-- shades: corners cut at the top left and bottom right (like the window),
-- a 2px border of an accent gradient that drifts (move-bg, 5s), a near
-- black face, and a light accent label. On hover the face draws back into
-- the bottom-right corner, uncovering the gradient underneath, kept deeply
-- darkened so the label (now white) still reads.
-- opts: width, height, onClick. Returns the button.
local CUT_SIZE, CUT_BORDER, CUT_BAND, CUT_FILL_DIM = 6, 2, 5, 0.3
-- The glow under a chosen choice button: how far it spreads above and below,
-- how far it sits lower than the button, the width of its end caps, its alpha.
local CHOICE_GLOW_TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\InstallerWindow\\ProgressGlow.png"
local CHOICE_GLOW_SPREAD, CHOICE_GLOW_DROP, CHOICE_GLOW_CAP, CHOICE_GLOW_ALPHA = 12, 3, 22, 0.55

-- One cut-corner shape: three strips and two corner triangles.
local function CutShape(parent, layer, sublevel)
    local shape = { parts = {} }
    for _, k in ipairs({ "top", "mid", "bot", "tl", "br" }) do
        local t = parent:CreateTexture(nil, layer, nil, sublevel)
        t:SetTexture((k == "tl" or k == "br") and PartPath("cut_tri") or NAV_WHITE)
        shape.parts[k] = t
    end
    shape.parts.tl:SetTexCoord(1, 0, 0, 1)   -- lower-right half: cut at the top left
    shape.parts.br:SetTexCoord(0, 1, 1, 0)   -- upper-left half: cut at the bottom right
    return shape
end

-- x0/y0 from the parent's top left; colour(x) gives the colour at x.
local function LayoutCutShape(shape, parent, x0, y0, w, h, s, colour)
    local p = shape.parts
    local visible = w > 1 and h > 1
    for _, t in pairs(p) do t:SetShown(visible) end
    if not visible then return end
    s = math.min(s, w / 2, h / 2)
    local function Place(t, x, y, pw, ph)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
        t:SetSize(math.max(0.01, pw), math.max(0.01, ph))
    end
    Place(p.top, x0 + s, y0, w - s, s)
    Place(p.mid, x0, y0 + s, w, h - 2 * s)
    Place(p.bot, x0, y0 + h - s, w - s, s)
    Place(p.tl, x0, y0, s, s)
    Place(p.br, x0 + w - s, y0 + h - s, s, s)
    local function Grad(t, xa, xb)
        TexGradient(t, "HORIZONTAL", colour(xa), colour(xb))
    end
    Grad(p.top, x0 + s, x0 + w)
    Grad(p.mid, x0, x0 + w)
    Grad(p.bot, x0, x0 + w - s)
    local a, b = colour(x0 + s / 2), colour(x0 + w - s / 2)
    p.tl:SetVertexColor(a[1], a[2], a[3], a[4] or 1)
    p.br:SetVertexColor(b[1], b[2], b[3], b[4] or 1)
end

local function StepCutButton(btn, elapsed)
    elapsed = elapsed or 0
    btn._clock = (btn._clock or 0) + elapsed
    -- Skinned buttons (W:SkinCutButton) can be disabled, marked active and
    -- take their accent from the caller.
    -- Only an explicit false disables (frames without the method count as enabled).
    local enabled = not btn.IsEnabled or btn:IsEnabled() ~= false
    -- Choice buttons (one of a set is active) only half-fill on hover, so the
    -- chosen one still reads as chosen while the cursor is on another.
    local hoverTarget = (btn._choiceKT and not btn._activeKT) and 0.5 or 1
    local target = enabled and (btn._activeKT and 1 or (btn._hovered and hoverTarget)) or 0
    local h = btn._hoverP or 0
    local speed = target > h and 0.2 or 0.5   -- 200ms in, 500ms back
    btn._hoverP = (target > h) and math.min(target, h + elapsed / speed) or math.max(target, h - elapsed / speed)
    local e = NavEase(btn._hoverP)

    local ar, ag, ab
    if btn._accentKT then ar, ag, ab = btn._accentKT() else ar, ag, ab = CurrentAccentColor() end
    local A, W1 = { ar, ag, ab, 1 }, { 1, 1, 1, 1 }
    local stops = { Lerp(A, W1, 0.35), Shade(A, 0.45, 0), A }
    local c = (btn._clock % CUT_BAND) / CUT_BAND
    local phase = 0.31 + 0.39 * (c < 0.5 and c * 2 or (1 - c) * 2)
    local w, hh = btn._w or btn:GetWidth() or 0, btn._h or btn:GetHeight() or 0
    local function Band(x, dim)
        local u = ((x / w) * 0.5 + phase) % 1
        local t = u * (#stops - 1)
        local i = math.floor(t)
        local a, b = stops[i + 1], stops[math.min(i + 2, #stops)]
        local f = t - i
        local k = dim or 1
        return { (a[1] + (b[1] - a[1]) * f) * k, (a[2] + (b[2] - a[2]) * f) * k, (a[3] + (b[3] - a[3]) * f) * k, 1 }
    end
    local b, s = CUT_BORDER, CUT_SIZE
    LayoutCutShape(btn._borderKT, btn, 0, 0, w, hh, s, function(x) return Band(x) end)
    LayoutCutShape(btn._fillKT, btn, b, b, w - 2 * b, hh - 2 * b, s - 1, function(x) return Band(x, CUT_FILL_DIM) end)
    -- The face shrinks into the bottom-right corner as the cursor arrives.
    local fw, fh = (w - 2 * b) * (1 - e), (hh - 2 * b) * (1 - e)
    LayoutCutShape(btn._faceKT, btn, w - b - fw, hh - b - fh, fw, fh, (s - 1) * (1 - e),
        function() return { 0.035, 0.03, 0.042, 1 } end)

    local tc = Lerp(Lerp(A, W1, 0.55), W1, e)
    btn._textKT:SetTextColor(tc[1], tc[2], tc[3], enabled and 1 or 0.4)

    -- Choice buttons: the chosen one sits on a soft accent glow, gets a check
    -- mark and keeps white text; the others drop to muted text. The fill
    -- alone (shared with hover) did not tell the chosen option apart.
    if btn._choiceKT then
        local selected = btn._activeKT and enabled
        if selected and not btn._selGlowKT then
            -- ProgressGlow.png: a blurred bar, its two 64px ends kept as caps
            -- and the middle stretched under the button, a little low.
            local glow = {}
            for i = 1, 3 do
                glow[i] = btn:CreateTexture(nil, "BACKGROUND", nil, -1)
                glow[i]:SetTexture(CHOICE_GLOW_TEX)
            end
            glow[1]:SetTexCoord(0, 0.25, 0, 1)
            glow[2]:SetTexCoord(0.25, 0.75, 0, 1)
            glow[3]:SetTexCoord(0.75, 1, 0, 1)
            glow[2]:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, CHOICE_GLOW_SPREAD - CHOICE_GLOW_DROP)
            glow[2]:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -4, -CHOICE_GLOW_SPREAD - CHOICE_GLOW_DROP)
            glow[1]:SetPoint("TOPRIGHT", glow[2], "TOPLEFT")
            glow[1]:SetPoint("BOTTOMRIGHT", glow[2], "BOTTOMLEFT")
            glow[1]:SetWidth(CHOICE_GLOW_CAP)
            glow[3]:SetPoint("TOPLEFT", glow[2], "TOPRIGHT")
            glow[3]:SetPoint("BOTTOMLEFT", glow[2], "BOTTOMRIGHT")
            glow[3]:SetWidth(CHOICE_GLOW_CAP)
            local check = btn:CreateTexture(nil, "OVERLAY", nil, 7)
            check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            check:SetSize(18, 18)
            check:SetPoint("LEFT", btn, "LEFT", 6, 0)
            btn._selGlowKT, btn._selCheckKT = glow, check
        end
        if btn._selGlowKT then
            for _, piece in ipairs(btn._selGlowKT) do
                piece:SetVertexColor(ar, ag, ab, CHOICE_GLOW_ALPHA)
                piece:SetShown(selected)
            end
            btn._selCheckKT:SetVertexColor(1, 1, 1, 1)
            btn._selCheckKT:SetShown(selected)
        end
        if selected then
            btn._textKT:SetTextColor(1, 1, 1, 1)
        elseif not btn._hovered then
            btn._textKT:SetTextColor(0.58, 0.56, 0.55, enabled and 1 or 0.4)
        end
    end
end

function W:CutButton(parent, label, opts)
    opts = opts or {}
    local w, h = opts.width or 150, opts.height or 26
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w, h)
    btn._w, btn._h = w, h
    btn._borderKT = CutShape(btn, "BACKGROUND", 0)
    btn._fillKT = CutShape(btn, "BACKGROUND", 1)
    btn._faceKT = CutShape(btn, "BACKGROUND", 2)
    btn._textKT = btn:CreateFontString(nil, "OVERLAY")
    btn._textKT:SetFont(CurrentFont(), 11, "")
    btn._textKT:SetPoint("CENTER", btn, "CENTER", 0, 0)
    btn._textKT:SetText(KT.NavTabs and KT.NavTabs.Upper and KT.NavTabs.Upper(label or "") or (label or ""):upper())
    -- Fit the label inside the button instead of spilling past its edges.
    if btn._textKT.GetUnboundedStringWidth then
        local size = 11
        while size > 7 and (btn._textKT:GetUnboundedStringWidth() or 0) > w - 16 do
            size = size - 1
            btn._textKT:SetFont(CurrentFont(), size, "")
        end
    end
    btn:SetScript("OnEnter", function(self) self._hovered = true end)
    btn:SetScript("OnLeave", function(self) self._hovered = nil end)
    if opts.onClick then btn:SetScript("OnClick", opts.onClick) end
    -- The border band keeps drifting while the button is shown.
    btn:SetScript("OnUpdate", StepCutButton)
    framePieces[btn] = "cutbtn"
    btn._clock = 0
    StepCutButton(btn, 0)
    return btn
end

-- Gives an existing Button the CutButton look, keeping its own size, label
-- (its FontString) and scripts. opts.accent: function returning r, g, b
-- (default: the style accent). btn:SetCutActive(true) holds the hovered look,
-- for buttons that mark a selection.
function W:SkinCutButton(btn, opts)
    if btn._borderKT then return btn end
    opts = opts or {}
    btn._accentKT = opts.accent
    btn._borderKT = CutShape(btn, "BACKGROUND", 0)
    btn._fillKT = CutShape(btn, "BACKGROUND", 1)
    btn._faceKT = CutShape(btn, "BACKGROUND", 2)
    btn._textKT = btn:GetFontString()
    if not btn._textKT then
        btn._textKT = btn:CreateFontString(nil, "OVERLAY")
        btn._textKT:SetFont(CurrentFont(), 11, "")
        btn._textKT:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn:SetFontString(btn._textKT)
    end
    btn:HookScript("OnEnter", function(self) self._hovered = true end)
    btn:HookScript("OnLeave", function(self) self._hovered = nil end)
    btn:HookScript("OnHide", function(self)
        self._hovered = nil
        self._hoverP = 0
    end)
    function btn:SetCutActive(active)
        self._activeKT = active and true or nil
    end
    btn:HookScript("OnUpdate", StepCutButton)
    framePieces[btn] = "cutbtn"
    btn._clock = 0
    StepCutButton(btn, 0)
    return btn
end

-- Category header after the user's starfield CSS: a radial glow rising from
-- the bottom (a deep accent tone into near black), three layers of stars
-- drifting upwards at different speeds (1px fastest, 3px slowest), and the
-- texts fading up into place once when the page opens (1.2s, ease-out).
-- opts: width, height, eyebrow, title, subtitle. Returns the frame.
local STAR_LAYERS = { { size = 1, count = 110, speed = 9, alpha = 0.55 },
                      { size = 2, count = 36, speed = 5, alpha = 0.7 },
                      { size = 3, count = 12, speed = 3, alpha = 0.85 } }
local STAR_INTRO = 1.2
local RADIAL_TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\PortalRadial.tga"

local function PaintStarHero(hero)
    local ar, ag, ab = CurrentAccentColor()
    local A, W1 = { ar, ag, ab, 1 }, { 1, 1, 1, 1 }
    hero._baseKT:SetColorTexture(0.028, 0.027, 0.032, 1)
    local glow = Shade(A, 0.5, 0)
    hero._glowKT:SetVertexColor(glow[1], glow[2], glow[3], 0.85)
    local star = Lerp(W1, A, 0.2)
    for _, s in ipairs(hero._starsKT) do s.tex:SetVertexColor(star[1], star[2], star[3], s.alpha) end
    for _, t in ipairs(hero._edgeKT) do
        t:SetColorTexture(ar, ag, ab, 0.55)
    end
    hero._eyebrowKT:SetTextColor(ar, ag, ab, 1)
    local tr, tg, tb = CurrentTextColor()
    hero._titleKT:SetTextColor(tr, tg, tb, 1)
    local mr, mg, mb = CurrentMutedColor()
    hero._subKT:SetTextColor(mr, mg, mb, 1)
end

local function StepStarHero(hero, elapsed)
    elapsed = elapsed or 0
    hero._clock = (hero._clock or 0) + elapsed
    local h = hero:GetHeight() or 0
    for _, s in ipairs(hero._starsKT) do
        local y = (s.y - hero._clock * s.speed) % h
        s.tex:ClearAllPoints()
        s.tex:SetPoint("TOPLEFT", hero._skyKT, "TOPLEFT", s.x, -y)
    end
    -- Intro: the texts rise 30px into place and fade in.
    hero._intro = (hero._intro or 0) + elapsed
    local p = math.min(1, hero._intro / STAR_INTRO)
    local e = 1 - (1 - p) * (1 - p)
    local dy = 30 * (1 - e)
    hero._textKT:ClearAllPoints()
    hero._textKT:SetPoint("CENTER", hero, "CENTER", 0, -dy)
    hero._textKT:SetAlpha(e)
end

function W:StarHero(parent, opts)
    opts = opts or {}
    local w, h = opts.width or 920, opts.height or 110
    local hero = CreateFrame("Frame", nil, parent)
    hero:SetSize(w, h)
    hero._baseKT = hero:CreateTexture(nil, "BACKGROUND", nil, 0)
    hero._baseKT:SetAllPoints(hero)

    -- Sky: clipped so the glow and the stars never leave the card.
    local sky = CreateFrame("Frame", nil, hero)
    sky:SetAllPoints(hero)
    if sky.SetClipsChildren then sky:SetClipsChildren(true) end
    local layer = CreateFrame("Frame", nil, sky)
    layer:SetAllPoints(sky)
    hero._skyKT = layer
    hero._glowKT = layer:CreateTexture(nil, "BACKGROUND", nil, 1)
    hero._glowKT:SetTexture(RADIAL_TEX)
    hero._glowKT:SetPoint("CENTER", layer, "BOTTOM", 0, 0)
    hero._glowKT:SetSize(w * 1.25, h * 2.4)

    -- Stars: fixed pseudo-random positions so every page looks the same.
    hero._starsKT = {}
    local seed = 1985
    local function Rand()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end
    for _, L in ipairs(STAR_LAYERS) do
        for _ = 1, math.max(1, math.floor(L.count * w / 920)) do
            local tex = layer:CreateTexture(nil, "ARTWORK")
            tex:SetTexture(NAV_WHITE)
            tex:SetSize(L.size, L.size)
            hero._starsKT[#hero._starsKT + 1] = { tex = tex, x = Rand() * w, y = Rand() * h, speed = L.speed, alpha = L.alpha }
        end
    end

    hero._edgeKT = {}
    for i = 1, 4 do hero._edgeKT[i] = hero:CreateTexture(nil, "BORDER") end
    local e = hero._edgeKT
    e[1]:SetPoint("TOPLEFT"); e[1]:SetPoint("TOPRIGHT"); e[1]:SetHeight(1)
    e[2]:SetPoint("BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT"); e[2]:SetHeight(1)
    e[3]:SetPoint("TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT"); e[3]:SetWidth(1)
    e[4]:SetPoint("TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT"); e[4]:SetWidth(1)

    -- Texts, centred like the CSS title, above the sky.
    local text = CreateFrame("Frame", nil, hero)
    text:SetSize(w - 40, h - 16)
    text:SetFrameLevel((layer:GetFrameLevel() or 1) + 2)
    hero._textKT = text
    hero._eyebrowKT = text:CreateFontString(nil, "OVERLAY")
    hero._eyebrowKT:SetFont(CurrentFont(), 9, "OUTLINE")
    hero._eyebrowKT:SetText(opts.eyebrow or "")
    hero._titleKT = text:CreateFontString(nil, "OVERLAY")
    hero._titleKT:SetFont(CurrentFont(), 24, "")
    hero._titleKT:SetText(opts.title or "")
    if hero._titleKT.SetSpacing then hero._titleKT:SetSpacing(2) end
    hero._subKT = text:CreateFontString(nil, "OVERLAY")
    hero._subKT:SetFont(CurrentFont(), 11, "")
    hero._subKT:SetText(opts.subtitle or "")
    hero._titleKT:SetPoint("CENTER", text, "CENTER", 0, 2)
    hero._eyebrowKT:SetPoint("BOTTOM", hero._titleKT, "TOP", 0, 6)
    hero._subKT:SetPoint("TOP", hero._titleKT, "BOTTOM", 0, -7)

    framePieces[hero] = "stars"
    PaintStarHero(hero)
    hero._clock, hero._intro = 0, 0
    StepStarHero(hero, 0)
    -- Stars drift for as long as the card is shown (OnUpdate stops while
    -- it is hidden); the intro replays each time the page opens.
    hero:SetScript("OnUpdate", StepStarHero)
    hero:SetScript("OnShow", function(self) self._intro = 0 end)
    return hero
end

function W:PageTabs(parent, tabs, selectedId, onSelect, opts)
    opts = opts or {}
    local localize = opts.localize or LText
    local width = opts.width or FW(parent)
    if not width or width <= 0 then width = 600 end
    local height, gap = opts.height or 40, opts.gap or 10
    local count = #(tabs or {})
    if count == 0 then return nil, 0 end

    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, height)
    bar._tabsKT = {}
    bar.selectedId = selectedId

    local function Refresh()
        for _, tab in ipairs(bar._tabsKT) do
            tab._selected = tab._tabId == bar.selectedId
            PaintPageTab(tab)
        end
    end
    bar.Refresh = Refresh

    for _, def in ipairs(tabs) do
        local tab = CreateFrame("Button", nil, bar)
        AddSteamHalo(tab)
        BuildPageTabRing(tab)
        tab._faceKT = W:RoundRect(tab, "BACKGROUND", 2, 8)
        tab._faceKT:SetAllPoints(tab)

        local text = tab:CreateFontString(nil, "OVERLAY")
        text:SetWordWrap(false)
        local label = localize(def.label or def.id or "")
        tab._labelKT = KT.NavTabs and KT.NavTabs.Upper and KT.NavTabs.Upper(label) or label
        tab._textKT = text
        if def.icon then
            local icon = tab:CreateTexture(nil, "OVERLAY")
            icon:SetSize(TAB_ICON, TAB_ICON)
            icon:SetTexture(def.icon)
            tab._iconKT = icon
        end

        tab._tabId, tab._tab = def.id, def
        local function Animate(self) self:SetScript("OnUpdate", StepPageTab) end
        tab:SetScript("OnEnter", function(self) self._hovered = true; Animate(self) end)
        tab:SetScript("OnLeave", function(self) self._hovered = nil; self._pressed = nil; Animate(self) end)
        tab:SetScript("OnMouseDown", function(self) self._pressed = true; Animate(self) end)
        tab:SetScript("OnMouseUp", function(self) self._pressed = nil; Animate(self) end)
        tab:SetScript("OnClick", function(self)
            bar.selectedId = self._tabId
            Refresh()
            if onSelect then onSelect(self._tabId, self._tab) end
        end)
        bar._tabsKT[#bar._tabsKT + 1] = tab
    end

    -- Each tab needs its label, icon and padding (0 15px, gap 10px); a shared
    -- font size shrinks until the row fits, then spare width is shared out.
    local avail = width - gap * (count - 1)
    local needs, total
    local size = opts.fontSize or 12
    while true do
        needs, total = {}, 0
        for i, tab in ipairs(bar._tabsKT) do
            tab._textKT:SetFont(CurrentFont(), size, "OUTLINE")
            tab._textKT:SetText(tab._labelKT)
            local need = math.ceil(tab._textKT:GetStringWidth() or 0) + (tab._iconKT and (TAB_ICON + 10) or 0) + 30
            needs[i] = need
            total = total + need
        end
        if total <= avail or size <= 9 then break end
        size = size - 0.5
    end
    if total > avail then
        bar:Hide()
        return nil, 0
    end
    local extra = math.floor((avail - total) / count)
    local x = 0
    for i, tab in ipairs(bar._tabsKT) do
        local w = needs[i] + extra
        if i == count then w = width - x end
        tab:SetSize(w, height)
        tab:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
        LayoutPageTabRing(tab, w, height)
        local textW = math.ceil(tab._textKT:GetStringWidth() or 0)
        local iconW = tab._iconKT and (TAB_ICON + 10) or 0
        local left = math.floor((w - (textW + iconW)) / 2)
        if tab._iconKT then tab._iconKT:SetPoint("LEFT", tab, "LEFT", left, 0) end
        tab._textKT:SetPoint("LEFT", tab, "LEFT", left + iconW, 0)
        x = x + w + gap
    end

    framePieces[bar] = "pagetabs"
    Refresh()
    return bar, height
end


-- Info hint, after a Uiverse tooltip by themrsami, in the accent: a rounded
-- accent button (info icon + label, a soft coloured wash) and, on hover, a
-- glassy card that rises 8px into place and fades in (0.3s, ease-out): an
-- accent disc with the info glyph and a title, a paragraph, and check-marked
-- lines, with an accent glow round it and an arrow pointing at the button.
-- opts: label, title, text, items (list of strings), width (card, 288),
--       height (button, 32), side ("TOP" or "RIGHT"), accent (function -> r, g, b).
--       With side "RIGHT": edge (a frame whose right edge the card clears,
--       default the button) and align ("TOP": the card hangs down from the
--       button; "BOTTOM": it grows up from it, for buttons low on screen).
-- Returns the button; btn:Peek(seconds) shows the card on its own for a while.
local HINT_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\InfoHint\\"
local HINT_FADE = 0.3
local HINT_RISE = 8
local HINT_GAP = 12
local HINT_PAD = 16

local function HintTexture(parent, layer, sublevel, file, margin)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(HINT_PATH .. file .. ".png")
    if margin then
        -- Nine-slice so the corners keep their radius at any size; a plain
        -- square where the client cannot slice.
        local sliced = tex.SetTextureSliceMargins
            and pcall(tex.SetTextureSliceMargins, tex, margin, margin, margin, margin)
        if sliced and tex.SetTextureSliceMode then
            pcall(tex.SetTextureSliceMode, tex, 0)
        elseif not sliced then
            tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        end
    end
    return tex
end

local function HintEaseOut(p)
    return 1 - (1 - p) * (1 - p)
end

function W:InfoHint(parent, opts)
    opts = opts or {}
    local side = opts.side == "RIGHT" and "RIGHT" or "TOP"
    local cardW = opts.width or 288
    local function Accent()
        if opts.accent then return opts.accent() end
        return CurrentAccentColor()
    end

    -- Button.
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(opts.height or 32)
    btn._fill = HintTexture(btn, "BACKGROUND", 0, "round12", 12)
    btn._fill:SetAllPoints()
    btn._wash = HintTexture(btn, "BACKGROUND", 1, "glow")
    btn._wash:SetPoint("TOPLEFT", -6, 6)
    btn._wash:SetPoint("BOTTOMRIGHT", 6, -6)
    btn._wash:SetBlendMode("ADD")
    btn._icon = HintTexture(btn, "ARTWORK", 0, "info_line")
    btn._icon:SetSize(14, 14)
    btn._icon:SetPoint("LEFT", 16, 0)
    btn._label = btn:CreateFontString(nil, "OVERLAY")
    btn._label:SetFont(CurrentFont(), 12, "")
    btn._label:SetPoint("LEFT", btn._icon, "RIGHT", 7, 0)
    btn._label:SetText(opts.label or "")
    btn._label:SetTextColor(1, 1, 1, 1)
    local labelW = btn._label.GetUnboundedStringWidth and btn._label:GetUnboundedStringWidth() or btn._label:GetStringWidth()
    btn:SetWidth(16 + 14 + 7 + (labelW or 60) + 18)

    -- Card (on UIParent so no parent clips it; scaled like the button).
    local card = CreateFrame("Frame", nil, UIParent)
    card:SetFrameStrata("TOOLTIP")
    card:SetFrameLevel(500)
    card:SetWidth(cardW)
    card:Hide()
    btn.card = card

    card._shadow = HintTexture(card, "BACKGROUND", -8, "glow")
    card._shadow:SetPoint("TOPLEFT", -34, 34)
    card._shadow:SetPoint("BOTTOMRIGHT", 34, -34)
    card._fill = HintTexture(card, "BACKGROUND", 0, "round16", 16)
    card._fill:SetAllPoints()
    card._wash = HintTexture(card, "BACKGROUND", 1, "glow")
    card._wash:SetPoint("TOPLEFT", 6, -6)
    card._wash:SetPoint("BOTTOMRIGHT", -6, 6)
    card._wash:SetBlendMode("ADD")
    card._edge = HintTexture(card, "BORDER", 0, "round16_edge", 16)
    card._edge:SetAllPoints()
    card._edge:SetVertexColor(1, 1, 1, 0.10)
    card._pointer = HintTexture(card, "BACKGROUND", 2, "pointer")
    card._pointer:SetSize(18, 9)
    card._pointerEdge = HintTexture(card, "BORDER", 1, "pointer_edge")
    card._pointerEdge:SetSize(18, 9)
    card._pointerEdge:SetVertexColor(1, 1, 1, 0.10)
    if side == "RIGHT" then
        -- Down-pointing art turned a quarter clockwise points at the button.
        card._pointer:SetRotation(math.rad(-90))
        card._pointerEdge:SetRotation(math.rad(-90))
    end

    local disc = HintTexture(card, "ARTWORK", 0, "disc")
    disc:SetSize(32, 32)
    disc:SetPoint("TOPLEFT", HINT_PAD, -HINT_PAD)
    local glyph = HintTexture(card, "ARTWORK", 1, "info_solid")
    glyph:SetSize(16, 16)
    glyph:SetPoint("CENTER", disc, "CENTER")
    local title = card:CreateFontString(nil, "OVERLAY")
    title:SetFont(CurrentFont(), 13, "")
    title:SetPoint("LEFT", disc, "RIGHT", 12, 0)
    title:SetPoint("RIGHT", card, "RIGHT", -HINT_PAD, 0)
    title:SetJustifyH("LEFT")
    title:SetTextColor(1, 1, 1, 1)
    title:SetText(opts.title or "")

    local innerW = cardW - HINT_PAD * 2
    local y = HINT_PAD + 32 + 8
    if opts.text and opts.text ~= "" then
        local body = card:CreateFontString(nil, "OVERLAY")
        body:SetFont(CurrentFont(), 12, "")
        body:SetWidth(innerW)
        body:SetPoint("TOPLEFT", HINT_PAD, -y)
        body:SetJustifyH("LEFT")
        body:SetSpacing(2)
        body:SetTextColor(0.82, 0.83, 0.86, 1)
        body:SetText(opts.text)
        y = y + math.ceil(body:GetStringHeight() or 14) + 8
    end
    for _, item in ipairs(opts.items or {}) do
        local check = HintTexture(card, "ARTWORK", 0, "check")
        check:SetSize(13, 13)
        check:SetPoint("TOPLEFT", HINT_PAD, -(y + 1))
        check:SetVertexColor(0.61, 0.64, 0.69, 1)
        local line = card:CreateFontString(nil, "OVERLAY")
        line:SetFont(CurrentFont(), 11, "")
        line:SetWidth(innerW - 21)
        line:SetPoint("TOPLEFT", HINT_PAD + 21, -y)
        line:SetJustifyH("LEFT")
        line:SetSpacing(2)
        line:SetTextColor(0.61, 0.64, 0.69, 1)
        line:SetText(item)
        y = y + math.ceil(line:GetStringHeight() or 12) + 6
    end
    card:SetHeight(y - 6 + HINT_PAD)

    local function Paint(hover)
        local r, g, b = Accent()
        local A, Wt = { r, g, b, 1 }, { 1, 1, 1, 1 }
        local light = Lerp(A, Wt, 0.35)
        local k = hover and 0.82 or 1
        btn._fill:SetVertexColor(r * k, g * k, b * k, 0.9)
        TexGradient(btn._wash, "HORIZONTAL", { A[1], A[2], A[3], 0.2 }, { light[1], light[2], light[3], 0.2 })
        TexGradient(card._fill, "VERTICAL", { 0.105, 0.098, 0.094, 0.95 }, { 0.058, 0.054, 0.052, 0.95 })
        card._pointer:SetVertexColor(side == "TOP" and 0.105 or 0.08, side == "TOP" and 0.098 or 0.075, side == "TOP" and 0.094 or 0.072, 0.95)
        card._shadow:SetVertexColor(r, g, b, 0.22)
        TexGradient(card._wash, "HORIZONTAL", { A[1], A[2], A[3], 0.06 }, { light[1], light[2], light[3], 0.06 })
        disc:SetVertexColor(r, g, b, 0.2)
        glyph:SetVertexColor(light[1], light[2], light[3], 1)
    end

    -- Show progress 0..1: fade in and rise (TOP) or slide in (RIGHT).
    local progress, target, pinnedUntil = 0, 0, nil
    local function Place()
        local e = HintEaseOut(progress)
        local shift = HINT_RISE * (1 - e)
        card:SetAlpha(e)
        card:SetScale((btn:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1))
        card:ClearAllPoints()
        card._pointer:ClearAllPoints()
        if side == "RIGHT" then
            -- Horizontal distance from the button's right edge to the edge
            -- the card has to clear (both in the button's own units).
            local dx = 0
            local edge = opts.edge
            if edge and edge.GetRight and edge:GetRight() and btn:GetRight() then
                dx = (edge:GetRight() * edge:GetEffectiveScale() - btn:GetRight() * btn:GetEffectiveScale())
                    / btn:GetEffectiveScale()
            end
            if opts.align == "BOTTOM" then
                card:SetPoint("BOTTOMLEFT", btn, "BOTTOMRIGHT", dx + HINT_GAP + shift, -18)
            else
                card:SetPoint("TOPLEFT", btn, "TOPRIGHT", dx + HINT_GAP + shift, 18)
            end
            card._pointer:SetPoint("CENTER", btn, "RIGHT", dx + HINT_GAP + shift - 4, 0)
        else
            card:SetPoint("BOTTOM", btn, "TOP", 0, HINT_GAP - shift)
            card._pointer:SetPoint("TOP", card, "BOTTOM", 0, 1)
        end
        card._pointerEdge:ClearAllPoints()
        card._pointerEdge:SetPoint("CENTER", card._pointer, "CENTER")
    end

    local driver = CreateFrame("Frame", nil, btn)
    local function Step(_, elapsed)
        if pinnedUntil and GetTime() >= pinnedUntil then
            pinnedUntil = nil
            if not btn:IsMouseOver() then target = 0 end
        end
        local d = (elapsed or 0) / HINT_FADE
        progress = target > progress and math.min(1, progress + d) or math.max(0, progress - d)
        Place()
        if progress <= 0 and target == 0 then
            card:Hide()
            driver:SetScript("OnUpdate", nil)
        end
    end
    local function Open()
        target = 1
        Paint(true)
        card:Show()
        Place()
        driver:SetScript("OnUpdate", Step)
    end
    local function Close()
        if pinnedUntil then return end
        target = 0
        Paint(false)
        driver:SetScript("OnUpdate", Step)
    end

    btn:SetScript("OnEnter", Open)
    btn:SetScript("OnLeave", Close)
    btn:HookScript("OnHide", function()
        pinnedUntil, target, progress = nil, 0, 0
        card:Hide()
        driver:SetScript("OnUpdate", nil)
    end)

    -- Shows the card without hovering (a first look when a window opens).
    function btn:Peek(seconds)
        pinnedUntil = GetTime() + (seconds or 6)
        Open()
    end
    function btn:Repaint() Paint(btn:IsMouseOver()) end

    framePieces[btn] = "infohint"
    Paint(false)
    return btn
end

if KT.MenuSkins then
    KT.MenuSkins:RegisterRepaint(function()
        for piece, kind in pairs(framePieces) do
            if kind == "pill" then W:PaintPillButton(piece)
            elseif kind == "nav" then PaintNavChip(piece)
            elseif kind == "tabs" then PaintSegments(piece)
            elseif kind == "mcard" then PaintModuleCard(piece)
            elseif kind == "stars" then PaintStarHero(piece)
            elseif kind == "focus" then PaintFocusCard(piece)
            elseif kind == "cutbtn" then StepCutButton(piece, 0)
            elseif kind == "infohint" then piece:Repaint()
            elseif kind == "pagetabs" then
                for _, tab in ipairs(piece._tabsKT) do PaintPageTab(tab) end
            end
        end
    end)
end

-- Stretches the open card of `parent` down to the bottom of `row`.
local CARD_BOTTOM_PAD = 8
local CARD_MIN_GAP = 18  -- room between a card's last row and the next header

local function GrowCard(parent, row)
    local card = parent._ktCard
    if not card then return end
    local _, _, _, rowX = row:GetPoint(1)
    card:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", (card._ktLeft or 4) - (rowX or 0), -CARD_BOTTOM_PAD)
    card._ktLastRow, card._ktLastRowX = row, rowX or 0
    card:Show()
end

-- Where the last row of `card` ends, in its parent's offsets (rows hang from
-- the parent's TOPLEFT), or nil when unknown.
local function CardLastRowBottom(card)
    local row = card and card._ktLastRow
    if not row then return nil end
    local point, relativeTo, relativePoint, _, rowY = row:GetPoint(1)
    if type(relativeTo) == "number" then
        rowY = relativePoint -- SetPoint("TOPLEFT", x, y) as stored by test stubs
    elseif relativePoint ~= "TOPLEFT" or relativeTo ~= card:GetParent() then
        return nil
    end
    if point ~= "TOPLEFT" or type(rowY) ~= "number" then return nil end
    return rowY - (row:GetHeight() or 0)
end

-- Rows are open (no stripes); a transparent band is kept for callers that
-- look for it. Halves of a dual row skip it.
local function RowBg(frame, parent, left, right)
    if parent._ktNoRowBg then return end
    if not parent.rowCounter then parent.rowCounter = 0 end
    parent.rowCounter = parent.rowCounter + 1
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    if left then
        bg:SetPoint("TOPLEFT", frame, "TOPLEFT", left, 0)
        bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(right or left), 0)
    else
        bg:SetAllPoints()
    end
    PaintSkinned(bg, (parent.rowCounter % 2 == 0) and "rowB" or "rowA")
    frame._rowBgKT = bg
    GrowCard(parent, frame)
    return bg
end

-- Hover: a rounded pill lights up behind the row.
local function MakeHoverFrame(f)
    local pill = W:RoundRect(f, "BACKGROUND", 1, 8)
    pill:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -1)
    pill:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 1)
    PaintSkinned(pill, "rowHover")
    pill:Hide()
    f.hoverKT = pill
    f:SetScript("OnEnter", function() pill:Show() end)
    f:SetScript("OnLeave", function() pill:Hide() end)
end

-- ============================================================================
-- LOCALIZATION
-- ============================================================================
function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] ~= nil then return L[text] end
    end
    return text
end

local function NormalizeDropdownLabel(key, label)
    if type(label) ~= "string" then
        return label
    end
    -- Language names are regular locale keys. Avoid forcing Spanish labels
    -- into every non-English configuration.
    return label
end

local function ShortMediaLabel(value)
    if type(value) ~= "string" then
        return value
    end

    -- Media paths are valid stored values, but are not useful option labels.
    local slash = string.char(92)
    if not value:find(slash, 1, true) and not value:find("/", 1, true) then
        return value
    end

    local normalized = value:gsub(slash, "/")
    local name = normalized:match("([^/]+)$") or normalized
    name = name:gsub("%.[^%.]+$", "")
    name = name:gsub("_", " ")
    return name
end
local function LocalizeDropdownLabel(key, label)
    label = NormalizeDropdownLabel(key, label)

    local localized = LText(label)
    if localized ~= label then
        return ShortMediaLabel(localized)
    end

    if type(key) == "string" then
        local keyLocalized = LText(key)
        if keyLocalized ~= key then
            return ShortMediaLabel(keyLocalized)
        end
    end

    return ShortMediaLabel(localized)
end

-- ============================================================================
-- SCROLL FRAME
-- ============================================================================
-- Glow and relief for a scrollbar's thumb (W:ScrollFrame and the menu's own
-- bars): a soft accent halo around the thumb, a light top half with a bright
-- top edge and a dark bottom edge on it, and a sunken shade at both ends of
-- the track. Safe to call again (recolors only). The halo brightens while the
-- bar is hovered or dragged.
local SCROLL_GLOW_TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\NavButtonGlow.tga"
local SCROLL_WHITE = "Interface\\Buttons\\WHITE8x8"
local SCROLL_GLOW_SIZE = 6

function W:DecorateScrollBar(bar, r, g, b)
    if not bar then return end
    local thumb = bar._thumb or (bar.GetThumbTexture and bar:GetThumbTexture())
    if not thumb then return end
    if not r then r, g, b = CurrentAccentColor() end
    local deco = bar._ktScrollDeco
    if not deco then
        deco = { glow = {} }
        local coords = {
            { 0, 0.5, 0, 0.5 }, { 0.5, 1, 0, 0.5 }, { 0, 0.5, 0.5, 1 }, { 0.5, 1, 0.5, 1 },
            { 0.49, 0.51, 0, 0.5 }, { 0.49, 0.51, 0.5, 1 }, { 0, 0.5, 0.49, 0.51 }, { 0.5, 1, 0.49, 0.51 },
        }
        for i = 1, 8 do
            local t = bar:CreateTexture(nil, "ARTWORK", nil, -2)
            t:SetTexture(SCROLL_GLOW_TEX)
            t:SetTexCoord(unpack(coords[i]))
            t:SetBlendMode("ADD")
            deco.glow[i] = t
        end
        local s = SCROLL_GLOW_SIZE
        local TL, TR, BL, BR, T, B, L, R = unpack(deco.glow)
        TL:SetSize(s, s); TL:SetPoint("BOTTOMRIGHT", thumb, "TOPLEFT")
        TR:SetSize(s, s); TR:SetPoint("BOTTOMLEFT", thumb, "TOPRIGHT")
        BL:SetSize(s, s); BL:SetPoint("TOPRIGHT", thumb, "BOTTOMLEFT")
        BR:SetSize(s, s); BR:SetPoint("TOPLEFT", thumb, "BOTTOMRIGHT")
        T:SetPoint("BOTTOMLEFT", thumb, "TOPLEFT"); T:SetPoint("BOTTOMRIGHT", thumb, "TOPRIGHT"); T:SetHeight(s)
        B:SetPoint("TOPLEFT", thumb, "BOTTOMLEFT"); B:SetPoint("TOPRIGHT", thumb, "BOTTOMRIGHT"); B:SetHeight(s)
        L:SetPoint("TOPRIGHT", thumb, "TOPLEFT"); L:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMLEFT"); L:SetWidth(s)
        R:SetPoint("TOPLEFT", thumb, "TOPRIGHT"); R:SetPoint("BOTTOMLEFT", thumb, "BOTTOMRIGHT"); R:SetWidth(s)

        local function Gradient(tex, a1, a2, fallback)
            if tex.SetGradient and CreateColor then
                tex:SetGradient("VERTICAL", CreateColor(a1[1], a1[2], a1[3], a1[4]), CreateColor(a2[1], a2[2], a2[3], a2[4]))
            else
                tex:SetVertexColor(fallback[1], fallback[2], fallback[3], fallback[4])
            end
        end

        -- Relief on the thumb.
        deco.shine = bar:CreateTexture(nil, "OVERLAY", nil, 1)
        deco.shine:SetTexture(SCROLL_WHITE)
        deco.shine:SetPoint("TOPLEFT", thumb, "TOPLEFT")
        deco.shine:SetPoint("BOTTOMRIGHT", thumb, "RIGHT")
        Gradient(deco.shine, { 1, 1, 1, 0 }, { 1, 1, 1, 0.28 }, { 1, 1, 1, 0.14 })
        deco.top = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        deco.top:SetColorTexture(1, 1, 1, 0.55)
        deco.top:SetPoint("TOPLEFT", thumb, "TOPLEFT")
        deco.top:SetPoint("TOPRIGHT", thumb, "TOPRIGHT")
        deco.top:SetHeight(1)
        deco.bottom = bar:CreateTexture(nil, "OVERLAY", nil, 2)
        deco.bottom:SetColorTexture(0, 0, 0, 0.55)
        deco.bottom:SetPoint("BOTTOMLEFT", thumb, "BOTTOMLEFT")
        deco.bottom:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT")
        deco.bottom:SetHeight(1)

        -- Sunken track: dark shade at both ends.
        deco.trackTop = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
        deco.trackTop:SetTexture(SCROLL_WHITE)
        deco.trackTop:SetPoint("TOPLEFT"); deco.trackTop:SetPoint("TOPRIGHT"); deco.trackTop:SetHeight(10)
        Gradient(deco.trackTop, { 0, 0, 0, 0 }, { 0, 0, 0, 0.5 }, { 0, 0, 0, 0.25 })
        deco.trackBottom = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
        deco.trackBottom:SetTexture(SCROLL_WHITE)
        deco.trackBottom:SetPoint("BOTTOMLEFT"); deco.trackBottom:SetPoint("BOTTOMRIGHT"); deco.trackBottom:SetHeight(10)
        Gradient(deco.trackBottom, { 0, 0, 0, 0.5 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0.25 })

        local function SetHot(hot)
            for _, t in ipairs(deco.glow) do t:SetAlpha(hot and 1 or 0.55) end
        end
        if bar.HookScript then
            bar:HookScript("OnEnter", function() SetHot(true) end)
            bar:HookScript("OnLeave", function() if not deco.dragging then SetHot(false) end end)
            bar:HookScript("OnMouseDown", function() deco.dragging = true; SetHot(true) end)
            bar:HookScript("OnMouseUp", function(self)
                deco.dragging = nil
                SetHot(self:IsMouseOver())
            end)
        end
        SetHot(false)
        bar._ktScrollDeco = deco
    end
    for _, t in ipairs(deco.glow) do t:SetVertexColor(r, g, b, 0.75) end
end

-- Shared scroll container for configuration panels. The scrollbar is parented
-- beside the ScrollFrame so it remains visible when the viewport clips its
-- scroll child. It appears only when the content is taller than the viewport.
function W:ScrollFrame(parent, opts)
    opts = opts or {}

    local scroll = CreateFrame("ScrollFrame", opts.name, parent)
    scroll:SetClipsChildren(true)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(math.max(1, tonumber(opts.contentWidth) or 1), 1)
    scroll:SetScrollChild(child)

    local barParent = opts.scrollBarParent or parent
    local bar = CreateFrame("Slider", opts.scrollBarName, barParent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(tonumber(opts.scrollBarWidth) or 6)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", tonumber(opts.scrollBarOffset) or 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", tonumber(opts.scrollBarOffset) or 4, 0)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(false) end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:EnableMouse(true)
    bar:EnableMouseWheel(true)
    bar:SetFrameLevel(scroll:GetFrameLevel() + 5)

    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.035, 0.038, 0.05, 0.88)

    local left = bar:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = bar:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)

    bar:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = bar:GetThumbTexture()
    if thumb then
        thumb:SetWidth(tonumber(opts.thumbWidth) or 4)
        thumb:SetHeight(32)
    end

    local accentR, accentG, accentB = CurrentAccentColor()
    if thumb then thumb:SetVertexColor(accentR, accentG, accentB, 0.88) end
    left:SetColorTexture(accentR, accentG, accentB, 0.38)
    right:SetColorTexture(accentR, accentG, accentB, 0.38)

    bar._thumb = thumb
    bar._trackBg = track
    bar._trackL = left
    bar._trackR = right
    W:DecorateScrollBar(bar, accentR, accentG, accentB)
    scroll.ScrollBar = bar
    scroll.scrollBar = bar
    scroll.scrollChild = child

    local autoHide = opts.autoHide ~= false
    local wheelStep = math.max(1, tonumber(opts.wheelStep) or 60)

    local function SafeNumber(value)
        if issecretvalue and issecretvalue(value) then return 0 end
        return tonumber(value) or 0
    end

    local function UpdateBar(rangeOverride, preserveValue, restoreValue)
        local range = SafeNumber(rangeOverride)
        if rangeOverride == nil then range = SafeNumber(scroll:GetVerticalScrollRange()) end
        range = math.max(0, range)
        scroll._scrollRange = range

        bar:SetMinMaxValues(0, math.max(1, range))
        local value = preserveValue and SafeNumber(restoreValue ~= nil and restoreValue or bar:GetValue()) or 0
        value = math.max(0, math.min(range, value))
        if bar:GetValue() ~= value then bar:SetValue(value) end
        if scroll:GetVerticalScroll() ~= value then scroll:SetVerticalScroll(value) end

        local viewportHeight = math.max(1, SafeNumber(scroll:GetHeight()))
        local trackHeight = math.max(1, SafeNumber(bar:GetHeight()))
        if thumb then
            local ratio = viewportHeight / (viewportHeight + range)
            thumb:SetHeight(math.max(24, math.floor(trackHeight * ratio + 0.5)))
        end

        bar:SetShown(not autoHide or range > 0.5)
    end

    function scroll:UpdateScrollBar(preserveValue, restoreValue, rangeOverride)
        UpdateBar(rangeOverride, preserveValue, restoreValue)
    end

    scroll:SetScript("OnScrollRangeChanged", function(_, _, verticalRange)
        UpdateBar(verticalRange, true)
    end)
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        offset = SafeNumber(offset)
        if bar:GetValue() ~= offset then bar:SetValue(offset) end
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local minValue, maxValue = bar:GetMinMaxValues()
        local value = SafeNumber(bar:GetValue()) - (SafeNumber(delta) * wheelStep)
        bar:SetValue(math.max(minValue, math.min(maxValue, value)))
    end)
    scroll:SetScript("OnSizeChanged", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if scroll then UpdateBar(nil, true) end
            end)
        else
            UpdateBar(nil, true)
        end
    end)

    bar:SetScript("OnValueChanged", function(_, value)
        value = math.max(0, math.min(scroll._scrollRange or 0, SafeNumber(value)))
        if bar:GetValue() ~= value then
            bar:SetValue(value)
            return
        end
        if scroll:GetVerticalScroll() ~= value then scroll:SetVerticalScroll(value) end
    end)
    bar:SetScript("OnMouseWheel", function(_, delta)
        local handler = scroll:GetScript("OnMouseWheel")
        if handler then handler(scroll, delta) end
    end)
    bar:SetScript("OnEnter", function()
        if thumb then thumb:SetVertexColor(accentR, accentG, accentB, 1) end
    end)
    bar:SetScript("OnLeave", function()
        if thumb then thumb:SetVertexColor(accentR, accentG, accentB, 0.88) end
    end)

    bar:Hide()
    return scroll, child, bar
end

-- ============================================================================
-- SECTION HEADER
-- ============================================================================
function W:SectionHeader(parent, text, yOffset)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(FW(parent), 30)
    f:SetPoint("TOPLEFT", 10, yOffset)

    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFont(CurrentFont(), 10, "OUTLINE")
    local header = LText(text) or ""
    if type(header) == "string" then
        header = header:upper()
    end
    t:SetText(header)
    t:SetPoint("BOTTOMLEFT", 0, 5)

    parent.rowCounter = 0

    if parent._ktBlockContent then
        -- Inside an option block (already a card): a sub-header with a divider.
        t:SetTextColor(SkinColor("sectionText"))
        local line = f:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
        PaintSkinned(line, "divider")
        f._dividerKT = line
        return f, 36
    end

    -- On a plain page the header opens a card that holds the title and is
    -- filled by the rows below; it stays hidden until the first row joins.
    t:Hide()
    -- A header placed right under the previous card's last row (no spacer)
    -- would make the two cards touch or overlap: push this header, and the
    -- rows the caller adds after it, down to the same gap a spacer gives.
    local shift = 0
    local previous = parent._ktCard
    local lastBottom = previous and previous:IsShown() and CardLastRowBottom(previous)
    if lastBottom and lastBottom - yOffset < CARD_MIN_GAP then
        shift = CARD_MIN_GAP - (lastBottom - yOffset)
        f:SetPoint("TOPLEFT", 10, yOffset - shift)
    end
    local cardTop = yOffset - shift + 2
    local card = CreateFrame("Frame", nil, parent)
    card:SetFrameLevel(math.max(0, (parent:GetFrameLevel() or 1)))
    card._ktLeft = 4
    card:SetPoint("TOPLEFT", parent, "TOPLEFT", 4, cardTop)
    card:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -4, cardTop)
    card:SetHeight(W.CARD_HEADER_H)
    W:StyleCard(card, { title = text })
    card:Hide()
    parent._ktCard = card
    f._cardKT = card

    return f, 36 + shift
end

-- ============================================================================
-- SPACER
-- ============================================================================
function W:Spacer(parent, yOffset, h)
    h = h or 8
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(FW(parent), h)
    f:SetPoint("TOPLEFT", 10, yOffset)
    return f, h
end

-- ============================================================================
-- LABEL
-- ============================================================================
function W:Label(parent, text, yOffset, fontSize, color)
    fontSize = fontSize or 11
    if not color then
        local mr, mg, mb = CurrentMutedColor()
        color = { r = mr, g = mg, b = mb }
    end
    local f  = CreateFrame("Frame", nil, parent)
    f:SetSize(FW(parent), 18)
    f:SetPoint("TOPLEFT", 10, yOffset)
    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFont(CurrentFont(), fontSize)
    t:SetText(LText(text))
    t:SetTextColor(color.r, color.g, color.b, 1)
    t:SetPoint("LEFT", 4, 0)
    t:SetWidth(FW(parent) - 8)
    t:SetWordWrap(true)
    local lineH = math.max(20, t:GetStringHeight() + 4)
    f:SetHeight(lineH)
    -- A note under a card's rows belongs to that card.
    GrowCard(parent, f)
    return f, lineH + 2
end

-- ============================================================================
-- TOGGLE
-- ============================================================================
function W:Toggle(parent, text, yOffset, get, set)
    local w   = FW(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w, 36)
    btn:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(btn, parent)
    btn:EnableMouse(true)
    MakeHoverFrame(btn)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 12)
    label:SetText(LText(text))
    label:SetPoint("LEFT", 12, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetWidth(w - 68)

    -- Pill switch: the round knob slides between the two ends.
    local TRACK_W, TRACK_H, KNOB = 34, 18, 14
    local KNOB_TRAVEL = TRACK_W - KNOB - 4
    local track = W:RoundRect(btn, "ARTWORK", 0, TRACK_H / 2)
    track:SetSize(TRACK_W, TRACK_H)
    track:SetPoint("RIGHT", btn, "RIGHT", -12, 0)
    local knob = W:RoundRect(btn, "OVERLAY", 0, KNOB / 2)
    knob:SetSize(KNOB, KNOB)
    btn._trackKT = track
    btn._knobKT = knob

    local knobPos
    local function PlaceKnob(pos)
        knobPos = pos
        knob:ClearAllPoints()
        knob:SetPoint("LEFT", track.box, "LEFT", 2 + KNOB_TRAVEL * pos, 0)
    end

    local function Update(animate)
        local val = get and get() or false
        local target = val and 1 or 0
        if val then
            local tr, tg, tb = CurrentTextColor()
            local ar, ag, ab = CurrentAccentColor()
            skinned[track] = nil
            track:SetColor(ar, ag, ab, 1)
            knob:SetColor(1, 1, 1, 1)
            label:SetTextColor(tr, tg, tb, 1)
        else
            local mr, mg, mb = CurrentMutedColor()
            PaintSkinned(track, "controlOff")
            knob:SetColor(0.55, 0.55, 0.6, 1)
            label:SetTextColor(mr * 0.72, mg * 0.72, mb * 0.72, 1)
        end
        if not animate or knobPos == nil then
            btn:SetScript("OnUpdate", nil)
            PlaceKnob(target)
            return
        end
        local from, elapsed = knobPos, 0
        btn:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local t = math.min(1, elapsed / 0.12)
            PlaceKnob(from + (target - from) * t)
            if t >= 1 then self:SetScript("OnUpdate", nil) end
        end)
    end

    btn:SetScript("OnClick", function()
        if set then set(not (get and get() or false)) end
        Update(true)
    end)

    btn._baseWidth = w
    btn._label = label
    function btn:SetReservedRightSpace(pixels)
        local reserved = math.max(0, pixels or 0)
        local newWidth = math.max(120, (self._baseWidth or w) - reserved)
        self:SetWidth(newWidth)
        if self._label then
            self._label:SetWidth(math.max(40, newWidth - 68))
        end
    end
    btn:SetReservedRightSpace(0)

    Update()
    btn.Update = Update
    return btn, 38
end

-- ============================================================================
-- WHEEL SWITCH: a small on/off selector after a CSS "wheel selector": a dark
-- sunken pill with a striped wheel turning behind the words, a glowing accent
-- dot and a glass sheen. The chosen word sits in front; the other one fades up
-- or down the wheel. Returns the button (52x22); place it with SetPoint.
-- opts: tooltip (title), tooltipText (second line), onText, offText.
-- ============================================================================
local WHEEL_W, WHEEL_H = 52, 22
local WHEEL_ART = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\StyleCards\\"
local WHEEL_DOT = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local WHEEL_TIME = 0.45            -- CSS 0.7 s, quicker at this size
local WHEEL_TURN = math.rad(30)    -- CSS rotates the wheel 30 degrees per step
local WHEEL_STEP = 11              -- how far the idle word sits up/down the wheel

-- Close to the CSS cubic-bezier(0.19, 1, 0.22, 1): fast start, long settle.
local function WheelEase(t) return 1 - (1 - t) ^ 4 end

function W:WheelSwitch(parent, get, set, opts)
    opts = opts or {}
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(WHEEL_W, WHEEL_H)
    f:EnableMouse(true)

    -- Pill body (CSS #111 with a #333 edge).
    local edge = W:RoundRect(f, "BACKGROUND", 0, WHEEL_H / 2)
    edge:SetAllPoints(f)
    local body = W:RoundRect(f, "BACKGROUND", 1, WHEEL_H / 2 - 1)
    body:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    body:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    body:SetColor(0.067, 0.067, 0.07, 1)

    -- Everything inside keeps to the pill.
    local mask = f:CreateMaskTexture()
    mask:SetTexture(WHEEL_ART .. "pill", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    mask:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)

    -- The striped wheel, centred on the right edge, half of it showing.
    local wheel = f:CreateTexture(nil, "ARTWORK", nil, 0)
    wheel:SetTexture(WHEEL_ART .. "wheel")
    wheel:SetSize(WHEEL_W * 1.5, WHEEL_W * 1.5)
    wheel:SetPoint("CENTER", f, "RIGHT", 0, 0)
    wheel:SetVertexColor(0.16, 0.16, 0.17, 0.9)
    wheel:AddMaskTexture(mask)

    -- Glass sheen: light from the top, darker towards the bottom.
    local glass = f:CreateTexture(nil, "ARTWORK", nil, 5)
    glass:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    glass:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    glass:SetTexture("Interface\\Buttons\\WHITE8X8")
    if glass.SetGradient and CreateColor then
        glass:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.2), CreateColor(1, 1, 1, 0.1))
    else
        glass:SetVertexColor(1, 1, 1, 0.05)
    end
    glass:AddMaskTexture(mask)

    -- The accent dot on the left, with its glow.
    local glow = f:CreateTexture(nil, "OVERLAY", nil, 0)
    glow:SetTexture(WHEEL_ART .. "tile_glow")
    glow:SetBlendMode("ADD")
    glow:SetSize(18, 18)
    glow:SetPoint("CENTER", f, "LEFT", 7, 0)
    local dot = f:CreateTexture(nil, "OVERLAY", nil, 1)
    dot:SetTexture(WHEEL_DOT)
    dot:SetSize(4, 4)
    dot:SetPoint("CENTER", f, "LEFT", 7, 0)

    -- The two words travel on the wheel inside a clipped strip.
    local strip = CreateFrame("Frame", nil, f)
    strip:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    strip:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    strip:SetClipsChildren(true)
    strip:EnableMouse(false)
    local onText = strip:CreateFontString(nil, "OVERLAY")
    local offText = strip:CreateFontString(nil, "OVERLAY")
    for _, text in ipairs({ onText, offText }) do
        text:SetFont(CurrentFont(), 9, "OUTLINE")
        text:SetJustifyH("LEFT")
        text:SetTextColor(1, 1, 1, 1)
    end
    onText:SetText(LText(opts.onText or "ON"))
    offText:SetText(LText(opts.offText or "OFF"))

    local pos
    local function Place(p)
        pos = p
        local ar, ag, ab = CurrentAccentColor()
        onText:ClearAllPoints()
        onText:SetPoint("LEFT", strip, "LEFT", 13 + 2 * p, (1 - p) * WHEEL_STEP)
        onText:SetAlpha(0.12 + 0.88 * p)
        offText:ClearAllPoints()
        offText:SetPoint("LEFT", strip, "LEFT", 13 + 2 * (1 - p), -p * WHEEL_STEP)
        offText:SetAlpha(0.12 + 0.88 * (1 - p))
        wheel:SetRotation((p * 2 - 1) * WHEEL_TURN)
        local mr, mg, mb = CurrentMutedColor()
        dot:SetVertexColor(mr + (ar - mr) * p, mg + (ag - mg) * p, mb + (ab - mb) * p, 1)
        glow:SetVertexColor(ar, ag, ab, 1)
        glow:SetAlpha(0.85 * p)
    end

    local hovered = false
    local function PaintEdge()
        if hovered then
            local ar, ag, ab = CurrentAccentColor()
            edge:SetColor(ar, ag, ab, 0.75)
        else
            edge:SetColor(0.2, 0.2, 0.21, 1)
        end
    end

    local function Update(animate)
        PaintEdge()
        local target = (get and get()) and 1 or 0
        if not animate or pos == nil then
            f:SetScript("OnUpdate", nil)
            Place(target)
            return
        end
        local from, elapsed = pos, 0
        f:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            local t = math.min(1, elapsed / WHEEL_TIME)
            Place(from + (target - from) * WheelEase(t))
            if t >= 1 then self:SetScript("OnUpdate", nil) end
        end)
    end

    f:SetScript("OnClick", function()
        if set then set(not (get and get() or false)) end
        Update(true)
    end)
    f:SetScript("OnEnter", function(self)
        hovered = true
        PaintEdge()
        if opts.tooltip and GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(LText(opts.tooltip), 1, 1, 1)
            if opts.tooltipText then
                GameTooltip:AddLine(LText(opts.tooltipText), 0.75, 0.75, 0.8, true)
            end
            GameTooltip:Show()
        end
    end)
    f:SetScript("OnLeave", function()
        hovered = false
        PaintEdge()
        if GameTooltip then GameTooltip:Hide() end
    end)

    Update()
    f.Update = Update
    f._onTextKT, f._offTextKT, f._wheelKT, f._dotKT, f._glowKT, f._edgeKT = onText, offText, wheel, dot, glow, edge
    return f
end

-- ============================================================================
-- SLIDER
-- ============================================================================
function W:Slider(parent, text, yOffset, get, set, minVal, maxVal, step, fmt, opts)
    if type(fmt) == "table" and opts == nil then
        opts = fmt
        fmt = opts.fmt
    end
    opts = type(opts) == "table" and opts or {}

    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 50)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 11)
    label:SetText(LText(text))
    do
        local mr, mg, mb = CurrentMutedColor()
        label:SetTextColor(mr, mg, mb, 1)
    end
    label:SetPoint("TOPLEFT", 12, -4)
    -- Reserve space for the default/value fields so long labels cannot
    -- overlap them in narrow two-column option blocks.
    label:SetWidth(math.max(72, w - 160))
    label:SetWordWrap(true)

    local valText = CreateFrame("EditBox", nil, f)
    valText:SetSize(50, 18)
    valText:SetFont(CurrentFont(), 11, "OUTLINE")
    valText:SetAutoFocus(false)
    valText:SetJustifyH("RIGHT")
    valText:SetJustifyV("MIDDLE")
    valText:EnableMouse(true)
    if valText.SetTextInsets then
        valText:SetTextInsets(2, 2, 0, 0)
    end
    do
        local ar, ag, ab = CurrentAccentColor()
        valText:SetTextColor(ar, ag, ab, 1)
    end
    valText:SetPoint("TOPRIGHT", -12, -4)
    valText:SetWidth(46)
    -- Value box: a rounded chip, so it reads as editable; it brightens while
    -- focused.
    local valueChip = W:RoundRect(valText, "BACKGROUND", 0, 5)
    valueChip:SetPoint("TOPLEFT", valText, "TOPLEFT", -2, 1)
    valueChip:SetPoint("BOTTOMRIGHT", valText, "BOTTOMRIGHT", 2, -1)
    local function IdleValueBox()
        PaintSkinned(valueChip, "controlBg")
    end
    IdleValueBox()
    f._valueBoxKT = valText

    local defaultText = f:CreateFontString(nil, "OVERLAY")
    defaultText:SetFont(CurrentFont(), 10)
    do
        local mr, mg, mb = CurrentMutedColor()
        defaultText:SetTextColor(mr * 0.76, mg * 0.76, mb * 0.76, 1)
    end
    -- Keep the default and current value on one reserved top row. This
    -- prevents wrapped labels in narrow two-column blocks from colliding
    -- with their metadata.
    defaultText:SetSize(68, 18)
    defaultText:SetPoint("TOPRIGHT", valText, "TOPLEFT", -12, -4)
    defaultText:SetJustifyH("RIGHT")
    defaultText:SetJustifyV("MIDDLE")

    label:SetJustifyH("LEFT")
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", 12, -4)

    local track = W:RoundRect(f, "ARTWORK", 0, 2)
    track:SetHeight(4)
    track:SetPoint("BOTTOMLEFT", 16, 14)
    track:SetPoint("BOTTOMRIGHT", -16, 14)
    PaintSkinned(track, "controlTrack")
    f._trackKT = track

    -- Accent fill from the left end of the track to the thumb.
    local fill = W:RoundRect(f, "ARTWORK", 1, 2)
    fill:SetHeight(4)
    fill:SetPoint("BOTTOMLEFT", track.box, "BOTTOMLEFT", 0, 0)
    do
        local ar, ag, ab = CurrentAccentColor()
        fill:SetColor(ar, ag, ab, 1)
    end
    f._fillKT = fill
    local function PaintFill(v)
        local lo, hi = minVal or 0, maxVal or 1
        local t = (hi > lo) and math.max(0, math.min(1, ((tonumber(v) or lo) - lo) / (hi - lo))) or 0
        local width = track.box:GetWidth()
        if not width or width <= 0 then width = w - 32 end
        fill:SetWidth(math.max(4, width * t))
    end

    local slider = CreateFrame("Slider", nil, f)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetSize(w - 32, 24)
    slider:SetPoint("BOTTOM", 0, 4)
    if slider.SetHitRectInsets then
        slider:SetHitRectInsets(0, 0, -6, -6)
    end

    slider:SetThumbTexture(PartPath("round_disc"))
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetTexture(PartPath("round_disc"))
        thumb:SetSize(14, 14); thumb:SetVertexColor(1, 1, 1, 1)
    end
    f._thumbKT = thumb

    for i = 1, slider:GetNumRegions() do
        local r = select(i, slider:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture") then
            local tex = r:GetTexture()
            if tex and (type(tex) == "string") and tex ~= "" then
                if r ~= thumb then r:SetAlpha(0) end
            end
        end
    end

    local function FormatVal(v)
        if fmt then
            return string.format(fmt, v)
        elseif step and step < 0.05 then
            return string.format("%.2f", v)
        elseif step and step < 1 then
            return string.format("%.1f", v)
        else
            return tostring(math.floor(v + 0.5))
        end
    end

    local function CoerceVal(v)
        v = tonumber(v)
        if not v then return nil end
        if minVal ~= nil then v = math.max(minVal, v) end
        if maxVal ~= nil then v = math.min(maxVal, v) end
        if step and step > 0 then
            v = math.floor((v / step) + 0.5) * step
        end
        return v
    end

    local function SetValueText(v)
        valText:SetText(FormatVal(v))
        valText:SetCursorPosition(0)
    end

    local function ApplyValueFromEdit()
        if valText._committing then return end
        valText._committing = true
        local value = CoerceVal(valText:GetText())
        if not value then
            SetValueText(slider:GetValue() or minVal or 0)
            valText._committing = nil
            return
        end
        slider.isInitializing = true
        slider:SetValue(value)
        slider.isInitializing = false
        if set then set(value) end
        SetValueText(value)
        valText._committing = nil
    end

    slider:SetScript("OnValueChanged", function(self, v)
        PaintFill(v)
        if self.isInitializing then return end
        if set then set(v) end
        if not valText:HasFocus() then
            SetValueText(v)
        end
    end)

    local ok, cur = pcall(get)
    local initialValue = ok and (cur or minVal) or minVal
    local defaultValue = initialValue
    if opts.defaultGet then
        local okDefault, resolvedDefault = pcall(opts.defaultGet)
        if okDefault and resolvedDefault ~= nil then
            defaultValue = resolvedDefault
        end
    elseif opts.defaultValue ~= nil then
        defaultValue = opts.defaultValue
    end
    defaultText:SetText(string.format("%s: %s", LText("Default"), FormatVal(defaultValue)))
    slider.isInitializing = true
    slider:SetValue(initialValue)
    slider.isInitializing = false
    SetValueText(initialValue)

    slider:HookScript("OnMouseDown", function()
        valText:ClearFocus()
    end)

    valText:SetScript("OnEditFocusGained", function(self)
        skinned[valueChip] = nil
        local r, g, b, a = SkinColor("controlBg")
        valueChip:SetColor(math.min(1, r + 0.08), math.min(1, g + 0.08), math.min(1, b + 0.08), a)
        self:HighlightText()
    end)
    valText:SetScript("OnEditFocusLost", function(self)
        IdleValueBox()
        if self._skipNextCommit then
            self._skipNextCommit = nil
        else
            ApplyValueFromEdit()
        end
        self:HighlightText(0, 0)
    end)
    valText:SetScript("OnEnterPressed", function(self)
        ApplyValueFromEdit()
        self._skipNextCommit = true
        self:ClearFocus()
    end)
    valText:SetScript("OnEscapePressed", function(self)
        SetValueText(slider:GetValue() or initialValue)
        self._skipNextCommit = true
        self:ClearFocus()
    end)

    f.Refresh = function()
        local ok2, v = pcall(get)
        if ok2 and v ~= nil then
            slider.isInitializing = true
            slider:SetValue(v)
            slider.isInitializing = false
            SetValueText(v)
        end
    end
    return f, 54
end

-- ============================================================================
-- DROPDOWN
-- ============================================================================
function W:Dropdown(parent, text, yOffset, values, get, set, order, fontPreview)
    local DROPDOWN_ITEM_HEIGHT = 22
    local DROPDOWN_MAX_VISIBLE_ITEMS = 12
    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 50)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 11)
    label:SetText(LText(text))
    do
        local mr, mg, mb = CurrentMutedColor()
        label:SetTextColor(mr, mg, mb, 1)
    end
    -- Label on the left, a 210px box on the right; each is one clipped line.
    -- Narrow rows shrink the box so the label always keeps some room.
    local DROPDOWN_BOX_W = math.min(210, math.floor(w * 0.55))
    label:SetPoint("LEFT", 12, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetWidth(math.max(40, w - (DROPDOWN_BOX_W + 50)))
    f._labelKT = label

    local btn = CreateFrame("Button", nil, f)
    btn:SetHeight(24)
    btn:SetWidth(DROPDOWN_BOX_W)
    btn:SetPoint("RIGHT", -12, 0)
    local boxRound = W:RoundRect(btn, "BACKGROUND", 0, 6)
    boxRound:SetAllPoints(btn)
    PaintSkinned(boxRound, "controlBg")
    f._boxKT = btn
    f._boxRoundKT = boxRound

    local selText = btn:CreateFontString(nil, "OVERLAY")
    selText:SetFont(CurrentFont(), 11)
    selText:SetTextColor(1, 1, 1, 1)
    selText:SetPoint("LEFT", 8, 0)
    selText:SetPoint("RIGHT", -22, 0)
    selText:SetJustifyH("LEFT")
    selText:SetWordWrap(false)
    selText:SetMaxLines(1)

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(16, 16)
    arrow:SetTexture(ICON_PATH .. "downarrow.png")
    do
        local ar, ag, ab = CurrentAccentColor()
        arrow:SetVertexColor(ar, ag, ab, 1)
    end
    arrow:SetPoint("RIGHT", -6, 0)

    local previewConfig = type(fontPreview) == "table" and fontPreview or nil

    local function GetBaseVals()
        local result = type(values) == "function" and values() or values
        return type(result) == "table" and result or nil
    end

    local function GetMenuOptions(tbl)
        local opts = tbl and rawget(tbl, "_menuOpts")
        return type(opts) == "table" and opts or nil
    end

    local function GetSharedMedia()
        return LibStub and LibStub("LibSharedMedia-3.0", true) or nil
    end

    local function NormalizePreviewKind(kind)
        kind = type(kind) == "string" and kind:lower() or nil
        if kind == "statusbar" or kind == "background" then return "texture" end
        if kind == "texture" or kind == "font" then return kind end
        return nil
    end

    local function GetPreviewKind(tbl)
        local explicitKind
        if type(fontPreview) == "string" then
            explicitKind = fontPreview
        elseif previewConfig then
            explicitKind = previewConfig.kind or previewConfig.type or previewConfig.mediaType
        elseif fontPreview then
            explicitKind = "font"
        end
        explicitKind = NormalizePreviewKind(explicitKind)
        if explicitKind then return explicitKind end

        local menuOptions = GetMenuOptions(tbl)
        local menuKind = menuOptions and NormalizePreviewKind(
            menuOptions.kind or menuOptions.type or menuOptions.mediaType
        )
        if menuKind then return menuKind end
        if menuOptions and type(menuOptions.background) == "function" then return "texture" end

        -- Legacy media selectors only supplied their label and values table.
        -- Infer them conservatively and verify at least one resolvable entry.
        local lowered = tostring(text or ""):lower()
        local inferred
        if lowered:find("textur", 1, true) then
            inferred = "texture"
        elseif lowered:find("font", 1, true)
            or lowered:find("fuente", 1, true)
            or lowered:find("schrift", 1, true)
            or lowered:find("police", 1, true)
            or lowered:find("fonte", 1, true)
        then
            inferred = "font"
        end
        if not inferred or not tbl then return nil end

        local mediaType = inferred == "texture" and "statusbar" or "font"
        local LSM = GetSharedMedia()
        for key in pairs(tbl) do
            if key ~= "_menuOpts" and type(key) == "string" then
                if key:find("\\", 1, true) or key:find("/", 1, true) then return inferred end
                if LSM and LSM:Fetch(mediaType, key, true) then return inferred end
            end
        end
        return nil
    end

    local function UsesSharedMedia(tbl, kind)
        if not kind then return false end
        local menuOptions = GetMenuOptions(tbl)
        if previewConfig and previewConfig.sharedMedia ~= nil then
            return previewConfig.sharedMedia == true
        end
        if menuOptions and menuOptions.sharedMedia ~= nil then
            return menuOptions.sharedMedia == true
        end
        if (previewConfig and type(previewConfig.resolve) == "function")
            or (menuOptions and (
                type(menuOptions.resolve) == "function"
                or type(menuOptions.background) == "function"
            ))
        then
            return false
        end
        return GetSharedMedia() ~= nil
    end

    local function GetVals()
        local source = GetBaseVals()
        if not source then return nil end
        local kind = GetPreviewKind(source)
        if not UsesSharedMedia(source, kind) then return source end

        local LSM = GetSharedMedia()
        local mediaType = kind == "texture" and "statusbar" or "font"
        local mediaList = LSM and LSM:List(mediaType)
        if not mediaList then return source end

        -- Build on open so media registered later by other addons is included.
        local merged = {}
        for key, value in pairs(source) do merged[key] = value end
        for i = 1, #mediaList do
            local name = mediaList[i]
            if merged[name] == nil then merged[name] = name end
        end
        return merged
    end
    local function FontEntryLabel(key, lbl)
        if KT and KT.GetLocalizedFontDisplayName then
            local display = KT:GetLocalizedFontDisplayName()
            local isLegacyDefault = key == "AAA_ITC_Avant_Garde"
                or (KT.LOCALIZED_FONT_NAME and key == KT.LOCALIZED_FONT_NAME)
            if display and isLegacyDefault then
                return display
            end
        end
        return LocalizeDropdownLabel(key, lbl)
    end
    local function GetLabel()
        local v   = get and get() or ""
        local tbl = GetVals()
        local lbl = tbl and tbl[v] or tostring(v)
        return FontEntryLabel(v, lbl)
    end

    local previewTexture = btn:CreateTexture(nil, "ARTWORK")
    previewTexture:SetSize(
        (previewConfig and (previewConfig.selectedWidth or previewConfig.width)) or 54,
        (previewConfig and (previewConfig.selectedHeight or previewConfig.height)) or 10
    )
    previewTexture:SetPoint("LEFT", 8, 0)
    previewTexture:Hide()
    local localeFlag
    if previewConfig and previewConfig.localeFlags and KT.CreateLocaleFlag then
        localeFlag = KT:CreateLocaleFlag(btn, get and get() or "auto", 22, 14)
        localeFlag:SetPoint("LEFT", 8, 0)
        localeFlag:Hide()
    end

    local function ResolvePreviewPath(value, kind)
        if type(value) ~= "string" or value == "" then
            return nil
        end
        local tbl = GetBaseVals()
        local menuOptions = GetMenuOptions(tbl)
        if previewConfig and type(previewConfig.resolve) == "function" then
            local ok, result = pcall(previewConfig.resolve, value)
            if ok and type(result) == "string" and result ~= "" then
                return result
            end
        elseif menuOptions and type(menuOptions.resolve) == "function" then
            local ok, result = pcall(menuOptions.resolve, value)
            if ok and type(result) == "string" and result ~= "" then
                return result
            end
        elseif kind == "texture" and menuOptions and type(menuOptions.background) == "function" then
            local ok, result = pcall(menuOptions.background, value)
            if ok and type(result) == "string" and result ~= "" then
                return result
            end
        elseif kind == "font" and type(fontPreview) == "function" then
            local ok, result = pcall(fontPreview, value)
            if ok and type(result) == "string" and result ~= "" then
                return result
            end
        end
        if value:find("\\", 1, true) or value:find("/", 1, true) then
            return value
        end
        local mediaType = kind == "texture" and "statusbar" or "font"
        local LSM = GetSharedMedia()
        return LSM and LSM:Fetch(mediaType, value, true) or nil
    end

    local function ApplyPreview(fontString, value)
        if not fontString then return end
        if localeFlag then
            previewTexture:Hide()
            localeFlag:SetLocale(value)
            localeFlag:Show()
            fontString:ClearAllPoints()
            fontString:SetPoint("LEFT", localeFlag, "RIGHT", 7, 0)
            fontString:SetPoint("RIGHT", -22, 0)
            return
        end
        local kind = GetPreviewKind(GetBaseVals())
        local path = ResolvePreviewPath(value, kind)
        if kind == "texture" then
            if path then
                pcall(previewTexture.SetTexture, previewTexture, path)
                previewTexture:Show()
            else
                previewTexture:Hide()
            end
            fontString:ClearAllPoints()
            fontString:SetPoint("LEFT", previewTexture, "RIGHT", 6, 0)
            fontString:SetPoint("RIGHT", -22, 0)
        else
            previewTexture:Hide()
            fontString:ClearAllPoints()
            fontString:SetPoint("LEFT", 8, 0)
            fontString:SetPoint("RIGHT", -22, 0)
            if kind == "font" and path then
                local _, size, flags = fontString:GetFont()
                pcall(fontString.SetFont, fontString, path, size or 11, flags or "")
            end
        end
    end

    selText:SetText(GetLabel())
    ApplyPreview(selText, get and get() or nil)

    local list = CreateFrame("Frame", nil, UIParent)
    list:SetFrameStrata("TOOLTIP")
    list:SetFrameLevel(1000)
    list:SetClampedToScreen(true)
    list:Hide()
    do
        local cr, cg, cb = SkinColor("card")
        KT:AddBackdrop(list, cr, cg, cb, 0.98)
        local ar, ag, ab = CurrentAccentColor()
        KT:AddBorder(list, ar, ag, ab, 0.6)
    end

    local closer = CreateFrame("Frame", nil, UIParent)
    closer:SetAllPoints()
    closer:SetFrameStrata("FULLSCREEN_DIALOG")
    closer:SetFrameLevel(900)
    closer:EnableMouse(true)
    closer:Hide()
    closer:SetScript("OnMouseDown", function()
        list:Hide()
        closer:Hide()
    end)

    local listScroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 2, -2)
    listScroll:SetPoint("BOTTOMRIGHT", -26, 2)
    listScroll:EnableMouseWheel(true)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetPoint("TOPLEFT", 0, 0)
    listContent:SetPoint("TOPRIGHT", 0, 0)
    listScroll:SetScrollChild(listContent)

    listScroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local step = (list._itemHeight or DROPDOWN_ITEM_HEIGHT) * 2
        local nextValue = current - (delta * step)
        local maxScroll = math.max(0, (listContent:GetHeight() or 0) - (self:GetHeight() or 0))
        nextValue = math.max(0, math.min(maxScroll, nextValue))
        if self.ScrollBar then self.ScrollBar:SetValue(nextValue) end
        self:SetVerticalScroll(nextValue)
    end)

    local function BuildList()
        for _, c in ipairs({ listContent:GetChildren() }) do
            c:Hide(); c:SetParent(UIParent)
        end

        local tbl = GetVals()
        if not tbl then return end

        local entries = {}
        local included = {}
        local previewKind = GetPreviewKind(tbl)
        local menuOptions = GetMenuOptions(tbl)
        local itemHeight = tonumber(menuOptions and menuOptions.itemHeight) or DROPDOWN_ITEM_HEIGHT
        itemHeight = math.max(18, math.min(40, itemHeight))
        list._itemHeight = itemHeight
        local listOrder = type(order) == "function" and order() or order
        if listOrder then
            for _, k in ipairs(listOrder) do
                if k ~= "---" and tbl[k] ~= nil then
                    table.insert(entries, { k = k, l = FontEntryLabel(k, tbl[k]) })
                    included[k] = true
                end
            end
            -- Preserve native ordering and append external SharedMedia entries.
            if UsesSharedMedia(tbl, previewKind) then
                local extras = {}
                for k, lbl in pairs(tbl) do
                    if k ~= "_menuOpts" and not included[k] then
                        table.insert(extras, { k = k, l = FontEntryLabel(k, lbl) })
                    end
                end
                table.sort(extras, function(a, b) return tostring(a.l) < tostring(b.l) end)
                for i = 1, #extras do table.insert(entries, extras[i]) end
            end
        else
            for k, lbl in pairs(tbl) do
                if k ~= "_menuOpts" then
                    table.insert(entries, { k = k, l = FontEntryLabel(k, lbl) })
                end
            end
            table.sort(entries, function(a, b) return tostring(a.l) < tostring(b.l) end)
        end

        local ly = 0
        for _, entry in ipairs(entries) do
            local item = CreateFrame("Button", nil, listContent)
            item:SetHeight(itemHeight)
            item:SetPoint("TOPLEFT", 0, -ly)
            item:SetPoint("TOPRIGHT", 0, -ly)

            local ibg = item:CreateTexture(nil, "BACKGROUND")
            ibg:SetAllPoints(); ibg:SetColorTexture(0, 0, 0, 0)

            local itext = item:CreateFontString(nil, "OVERLAY")
            itext:SetFont(CurrentFont(), 11)
            local display = entry.l
            itext:SetText(display)
            itext:SetJustifyH("LEFT")
            itext:SetJustifyV("MIDDLE")
            local itemPreview = item:CreateTexture(nil, "ARTWORK")
            itemPreview:SetSize(
                (previewConfig and (previewConfig.itemWidth or previewConfig.width)) or 48,
                (previewConfig and (previewConfig.itemHeight or previewConfig.height)) or 8
            )
            itemPreview:SetPoint("LEFT", 8, 0)
            itemPreview:Hide()
            local previewPath = ResolvePreviewPath(entry.k, previewKind)
            if previewConfig and previewConfig.localeFlags and KT.CreateLocaleFlag then
                local itemFlag = KT:CreateLocaleFlag(item, entry.k, 22, 14)
                itemFlag:SetPoint("LEFT", 8, 0)
                itext:SetPoint("LEFT", itemFlag, "RIGHT", 7, 0)
            elseif previewKind == "texture" then
                if previewPath then
                    pcall(itemPreview.SetTexture, itemPreview, previewPath)
                    itemPreview:Show()
                end
                itext:ClearAllPoints()
                itext:SetPoint("LEFT", itemPreview, "RIGHT", 6, 0)
            elseif previewKind == "font" then
                if previewPath then
                    local _, size, flags = itext:GetFont()
                    pcall(itext.SetFont, itext, previewPath, size or 11, flags or "")
                end
                itext:SetPoint("LEFT", 8, 0)
            else
                itext:SetPoint("LEFT", 8, 0)
            end
            do
                local tr, tg, tb = CurrentTextColor()
                itext:SetTextColor(tr, tg, tb, 1)
            end
            itext:SetPoint("RIGHT", -8, 0)

            local k, lbl = entry.k, display
            item:SetScript("OnClick", function()
                selText:SetText(lbl)
                ApplyPreview(selText, k)
                list:Hide()
                closer:Hide()
                if set then set(k) end
            end)
            item:SetScript("OnEnter", function()
                local ar, ag, ab = CurrentAccentColor()
                ibg:SetColorTexture(ar, ag, ab, 0.18)
            end)
            item:SetScript("OnLeave", function() ibg:SetColorTexture(0, 0, 0, 0) end)
            item:EnableMouseWheel(true)
            item:SetScript("OnMouseWheel", function(_, delta)
                local wheelHandler = listScroll:GetScript("OnMouseWheel")
                if wheelHandler then wheelHandler(listScroll, delta) end
            end)

            ly = ly + itemHeight
        end

        local viewportHeight = math.min(ly, itemHeight * DROPDOWN_MAX_VISIBLE_ITEMS)
        local showScrollBar = ly > viewportHeight
        local scrollBarWidth = showScrollBar and 20 or 0
        local contentWidth = math.max(80, (list:GetWidth() or btn:GetWidth()) - 6 - scrollBarWidth)

        listContent:SetWidth(contentWidth)
        listContent:SetHeight(ly)
        listScroll:SetVerticalScroll(0)
        list:SetHeight(viewportHeight + 4)

        if listScroll.ScrollBar then
            listScroll.ScrollBar:SetMinMaxValues(0, math.max(0, ly - viewportHeight))
            listScroll.ScrollBar:SetValue(0)
            if showScrollBar then
                listScroll.ScrollBar:Show()
            else
                listScroll.ScrollBar:Hide()
            end
        end
    end

    btn:SetScript("OnClick", function()
        if list:IsShown() then
            list:Hide()
            closer:Hide()
            return
        end
        list:SetWidth(btn:GetWidth())
        BuildList()
        list:ClearAllPoints()
        local buttonBottom = btn.GetBottom and btn:GetBottom()
        local listHeight = list:GetHeight() or 0
        if buttonBottom and listHeight > buttonBottom then
            list:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
        else
            list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        end
        closer:Show()
        list:Show()
    end)

    f._baseWidth = w
    f._label = label
    function f:SetReservedRightSpace(pixels)
        local reserved = math.max(0, pixels or 0)
        local newWidth = math.max(120, (self._baseWidth or w) - reserved)
        self:SetWidth(newWidth)
        if self._label then
            self._label:SetWidth(math.max(40, newWidth - (DROPDOWN_BOX_W + 50)))
        end
    end
    f:SetReservedRightSpace(0)

    f.Refresh = function()
        local value = get and get() or nil
        selText:SetText(GetLabel())
        ApplyPreview(selText, value)
    end
    return f, 50
end

-- ============================================================================
-- COLOR SWATCH
-- ============================================================================
function W:ColorSwatch(parent, text, yOffset, get, set, hasAlpha)
    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 36)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)
    MakeHoverFrame(f)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 12)
    label:SetText(LText(text))
    do
        local mr, mg, mb = CurrentMutedColor()
        label:SetTextColor(mr, mg, mb, 1)
    end
    label:SetPoint("LEFT", 12, 0)

    local swatch = CreateFrame("Button", nil, f)
    swatch:SetSize(22, 22)
    swatch:SetPoint("RIGHT", -12, 0)
    f._swatchKT = swatch

    local swTex = W:RoundRect(swatch, "ARTWORK", 0, 5)
    swTex:SetAllPoints(swatch)
    f._swatchRoundKT = swTex

    local function UpdateSwatch()
        local ok, r, g, b, a = pcall(get)
        if ok and r then swTex:SetColor(r, g, b or 1, a or 1) end
    end
    UpdateSwatch()

    swatch:SetScript("OnClick", function()
        if ColorPickerFrame and ColorPickerFrame.SetFrameStrata then
            ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        end
        if ColorPickerFrame and ColorPickerFrame.SetClampedToScreen then
            ColorPickerFrame:SetClampedToScreen(true)
        end
        local ok, r, g, b, a = pcall(get)
        if not ok then return end
        r = r or 1; g = g or 1; b = b or 1; a = a or 1

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r,
                g = g,
                b = b,
                hasOpacity = hasAlpha,
                opacity    = hasAlpha and a or nil,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = hasAlpha and ColorPickerFrame:GetColorAlpha() or 1
                    if set then set(nr, ng, nb, na) end
                    UpdateSwatch()
                end,
                cancelFunc = function()
                    if set then set(r, g, b, a) end
                    UpdateSwatch()
                end,
            })
        else
            ColorPickerFrame.func       = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = hasAlpha and (1 - OpacitySliderFrame:GetValue()) or 1
                if set then set(nr, ng, nb, na) end; UpdateSwatch()
            end
            ColorPickerFrame.cancelFunc = function()
                if set then set(r, g, b, a) end; UpdateSwatch()
            end
            ColorPickerFrame.hasOpacity = hasAlpha
            ColorPickerFrame.opacity    = hasAlpha and (1 - a) or nil
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Hide(); ColorPickerFrame:Show()
        end
    end)

    f.Refresh = UpdateSwatch
    return f, 38
end

-- ============================================================================
-- BUTTON — rellena la fila completa por defecto
-- ============================================================================
local function OpenMultiColorPicker(get, set, hasAlpha, onUpdate)
    local ok, r, g, b, a = pcall(get)
    if not ok then return end
    r, g, b, a = r or 1, g or 1, b or 1, a or 1
    local picker = ColorPickerFrame
    if not picker then return end
    if picker.SetFrameStrata then picker:SetFrameStrata("FULLSCREEN_DIALOG") end
    if picker.SetClampedToScreen then picker:SetClampedToScreen(true) end
    local function ApplyCurrent()
        local okColor, nr, ng, nb = pcall(picker.GetColorRGB, picker)
        if not okColor then return end
        local na = 1
        if hasAlpha and picker.GetColorAlpha then
            local okAlpha, value = pcall(picker.GetColorAlpha, picker)
            if okAlpha and value then na = value end
        end
        if set then pcall(set, nr or 1, ng or 1, nb or 1, na) end
        if onUpdate then onUpdate() end
    end
    local function RestoreOriginal()
        if set then pcall(set, r, g, b, a) end
        if onUpdate then onUpdate() end
    end
    if picker.SetupColorPickerAndShow then
        picker:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = hasAlpha == true,
            opacity = hasAlpha and a or nil,
            swatchFunc = ApplyCurrent,
            cancelFunc = RestoreOriginal,
        })
    else
        picker.func = ApplyCurrent
        picker.cancelFunc = RestoreOriginal
        picker.hasOpacity = hasAlpha == true
        picker.opacity = hasAlpha and (1 - a) or nil
        picker:SetColorRGB(r, g, b)
        picker:Hide()
        picker:Show()
    end
end

function W:MultiSwatch(parent, text, yOffset, swatches)
    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 36)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)
    MakeHoverFrame(f)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 12)
    label:SetText(LText(text or ""))
    do
        local mr, mg, mb = CurrentMutedColor()
        label:SetTextColor(mr, mg, mb, 1)
    end
    label:SetPoint("LEFT", 12, 0)

    local buttons = {}
    local size, gap = 20, 5
    for index, info in ipairs(swatches or {}) do
        local button = CreateFrame("Button", nil, f)
        button:SetSize(size, size)
        button:SetPoint("RIGHT", f, "RIGHT", -12 - ((index - 1) * (size + gap)), 0)
        button:SetFrameLevel(f:GetFrameLevel() + 5)
        if KT.AddBorder then KT:AddBorder(button, 0.35, 0.35, 0.35, 1) end
        local texture = button:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("TOPLEFT", 1, -1)
        texture:SetPoint("BOTTOMRIGHT", -1, 1)
        button._texture = texture
        button._info = info
        button:SetScript("OnClick", function(self)
            local spec = self._info
            OpenMultiColorPicker(spec.getValue, spec.setValue, spec.hasAlpha, function()
                local ok, r, g, b = pcall(spec.getValue)
                if ok and r then self._texture:SetColorTexture(r or 1, g or 1, b or 1, 1) end
            end)
        end)
        buttons[index] = button
    end

    local function Refresh()
        local reserved = (#buttons * size) + (math.max(0, #buttons - 1) * gap) + 24
        label:SetWidth(math.max(40, w - reserved - 12))
        for _, button in ipairs(buttons) do
            local spec = button._info
            local ok, r, g, b = pcall(spec.getValue)
            if ok then button._texture:SetColorTexture(r or 1, g or 1, b or 1, 1) end
            local disabled = spec.disabled
            if type(disabled) == "function" then
                local okDisabled, value = pcall(disabled)
                disabled = okDisabled and value or false
            end
            button:SetAlpha(disabled and 0.15 or 1)
            button:EnableMouse(not disabled)
        end
    end
    Refresh()
    f.Refresh = Refresh
    return f, 38
end
function W:Button(parent, text, yOffset, func, btnWidth, confirm, confirmText, align, btnHeight, variant)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(FW(parent), 42)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)

    local btn = CreateFrame("Button", nil, f)
    btn:SetHeight(btnHeight or 32)

    if btnWidth and btnWidth ~= "FULL" then
        btn:SetWidth(btnWidth)
        if align == "CENTER" then
            btn:SetPoint("CENTER", f, "CENTER", 0, 0)
        else
            btn:SetPoint("LEFT", 12, 0)
        end
    else
        btn:SetPoint("LEFT", f, "LEFT", 12, 0)
        btn:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    end

    -- Botones largos (ancho completo) y cortos (ancho fijo pequeno o mitad de
    -- fila) comparten el motor de KT.NavTabs, pero con aspecto distinto.
    if not variant then
        variant = (type(btnWidth) == "number" and btnWidth < 200) and "short" or "long"
    end
    if KT.TestButton and tostring(text or ""):lower():find("%f[%a]test") then
        variant = "test"
    end
    if variant == "moduleProfile" and KT.ProfileTransferButton then
        KT.ProfileTransferButton.Style(btn, { label = LText(text), fontSize = 12 })
    elseif variant == "test" and KT.TestButton then
        KT.TestButton.Style(btn, { label = LText(text), fontSize = 13 })
    elseif variant == "long" and KT.PortalButton then
        KT.PortalButton.Style(btn, { label = LText(text), fontSize = 13 })
    elseif KT.NavTabs then
        KT.NavTabs.StyleButton(btn, {
            label = LText(text),
            fontSize = 13,
            variant = (variant == "short") and "short" or nil,
        })
    end

    btn:SetScript("OnClick", function()
        if confirm then
            StaticPopupDialogs["KT_CONFIRM_ACTION"] = {
                text = LText(confirmText or "Are you sure?"),
                button1 = LText("Yes"),
                button2 = LText("No"),
                OnAccept = func,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
            }
            StaticPopup_Show("KT_CONFIRM_ACTION")
        else
            if func then func() end
        end
    end)

    return f, 44
end

-- ============================================================================
-- MODE + COLOUR ROW: "Accent | Custom" pill switch and a swatch on one line.
-- The swatch is dimmed while the module follows the accent; picking a colour
-- (or "Custom") makes it the module's own.
-- ============================================================================
function W:ModeColorRow(parent, text, yOffset, getMode, setMode, getColor, setColor)
    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 36)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)
    MakeHoverFrame(f)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 12)
    label:SetText(LText(text))
    label:SetPoint("LEFT", 12, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetWidth(math.max(40, w - 210))

    local swatch = CreateFrame("Button", nil, f)
    swatch:SetSize(22, 22)
    swatch:SetPoint("RIGHT", -12, 0)
    local swTex = W:RoundRect(swatch, "ARTWORK", 0, 5)
    swTex:SetAllPoints(swatch)
    f._swatchKT = swatch

    local OPTION_W, OPTION_H = 60, 20
    local track = W:RoundRect(f, "ARTWORK", 0, 8)
    track:SetSize(OPTION_W * 2 + 4, OPTION_H + 4)
    track:SetPoint("RIGHT", swatch, "LEFT", -10, 0)
    PaintSkinned(track, "controlBg")

    local options = {}
    local Update
    local function MakeOption(key, caption, index)
        local opt = CreateFrame("Button", nil, f)
        opt:SetSize(OPTION_W, OPTION_H)
        opt:SetPoint("LEFT", track.box, "LEFT", 2 + (index - 1) * OPTION_W, 0)
        opt._pillKT = W:RoundRect(opt, "OVERLAY", 0, 6)
        opt._pillKT:SetAllPoints(opt)
        opt._textKT = opt:CreateFontString(nil, "OVERLAY", nil, 1)
        opt._textKT:SetFont(CurrentFont(), 11)
        opt._textKT:SetPoint("CENTER", opt, "CENTER", 0, 0)
        opt._textKT:SetText(LText(caption))
        opt:SetScript("OnClick", function()
            if setMode then setMode(key) end
            Update()
        end)
        opt._key = key
        options[#options + 1] = opt
        return opt
    end
    f._modeAccentKT = MakeOption("accent", "Accent", 1)
    f._modeCustomKT = MakeOption("custom", "Custom", 2)

    Update = function()
        local mode = getMode and getMode() or "accent"
        local ar, ag, ab = CurrentAccentColor()
        local mr, mg, mb = CurrentMutedColor()
        for _, opt in ipairs(options) do
            opt._selected = (opt._key == mode)
            opt._pillKT:SetShown(opt._selected)
            opt._pillKT:SetColor(ar * 0.3, ag * 0.3, ab * 0.3, 1)
            if opt._selected then
                opt._textKT:SetTextColor(ar, ag, ab, 1)
            else
                opt._textKT:SetTextColor(mr, mg, mb, 1)
            end
        end
        swatch._dimmed = (mode ~= "custom")
        swatch:SetAlpha(swatch._dimmed and 0.35 or 1)
        local ok, r, g, b = pcall(getColor)
        if ok and r then swTex:SetColor(r, g, b, 1) end
        label:SetTextColor(swatch._dimmed and mr or 1, swatch._dimmed and mg or 1, swatch._dimmed and mb or 1, 1)
    end

    swatch:SetScript("OnClick", function()
        OpenMultiColorPicker(getColor, function(r, g, b)
            if setColor then setColor(r, g, b) end
        end, false, Update)
    end)

    Update()
    f.Refresh = Update
    return f, 38
end

function W:SubTabBar(parent, yOffset, tabs, selectedId, onSelect)
    if KT and KT.AddOptionsSubTabBar then
        return KT.AddOptionsSubTabBar(parent, yOffset, tabs, selectedId, onSelect)
    end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(parent:GetWidth() - 20, 44)
    frame:SetPoint("TOPLEFT", 10, yOffset)
    return frame, 50
end
-- ============================================================================
-- INPUT (SEGURO CONTRA CRASHEOS DE SETFONT)
-- ============================================================================
function W:Input(parent, text, yOffset, get, set, opts)
    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 48)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 11)
    label:SetText(LText(text))
    do
        local mr, mg, mb = CurrentMutedColor()
        label:SetTextColor(mr, mg, mb, 1)
    end
    label:SetPoint("TOPLEFT", 12, -4)

    local box = CreateFrame("EditBox", nil, f)
    box:SetHeight(22)
    box:SetPoint("BOTTOMLEFT", 12, 4)
    box:SetPoint("BOTTOMRIGHT", -12, 4)
    -- FIX: pcall for SetFont to prevent library crash if font string is invalid
    pcall(function() box:SetFont(CurrentFont(), 11, "") end)
    do
        local tr, tg, tb = CurrentTextColor()
        box:SetTextColor(tr, tg, tb, 1)
    end
    box:SetAutoFocus(false)
    local boxRound = W:RoundRect(box, "BACKGROUND", 0, 6)
    boxRound:SetAllPoints(box)
    PaintSkinned(boxRound, "controlBg")
    f._boxRoundKT = boxRound
    box:SetTextInsets(4, 4, 2, 2)
    f._boxKT = box

    local lastCommittedValue = get and get() or ""
    box:SetText(lastCommittedValue)

    local function CommitValue(self)
        local value = self:GetText() or ""
        if value == lastCommittedValue then
            return
        end
        lastCommittedValue = value
        if set then
            set(value)
        end
    end

    if opts and opts.commitOnTextChanged then
        box:SetScript("OnTextChanged", function(self)
            CommitValue(self)
        end)
    end

    box:SetScript("OnEnterPressed", function(self)
        CommitValue(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(lastCommittedValue)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusGained", function(self)
        skinned[boxRound] = nil
        local r, g, b, a = SkinColor("controlBg")
        boxRound:SetColor(math.min(1, r + 0.08), math.min(1, g + 0.08), math.min(1, b + 0.08), a)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        CommitValue(self)
        PaintSkinned(boxRound, "controlBg")
    end)

    f.Refresh = function()
        lastCommittedValue = get and get() or ""
        box:SetText(lastCommittedValue)
    end
    return f, 52
end

-- ============================================================================
-- DUAL ROW (Two columns)
-- ============================================================================
function W:DualRow(parent, yOffset, leftData, rightData)
    local fullW = parent:GetWidth()
    local gap = 10
    local itemW = (fullW - 20 - gap) / 2

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(fullW, 40)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    -- One band across both halves, with a divider between them.
    row._bandKT = RowBg(row, parent, 10, 10)
    local divider = row:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOP", row, "TOPLEFT", itemW + 10 + gap / 2, -6)
    divider:SetPoint("BOTTOM", row, "BOTTOMLEFT", itemW + 10 + gap / 2, 6)
    PaintSkinned(divider, "divider")
    row._dividerKT = divider

    local leftC = CreateFrame("Frame", nil, row)
    leftC:SetSize(itemW + 20, 40)
    leftC:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)

    local rightC = CreateFrame("Frame", nil, row)
    rightC:SetSize(itemW + 20, 40)
    rightC:SetPoint("TOPLEFT", row, "TOPLEFT", itemW + gap, 0)
    leftC._ktNoRowBg = true
    rightC._ktNoRowBg = true

    local function Create(p, d)
        if not d then return 0 end
        local ctrl, h = nil, 0
        if d.type == "toggle" then
            ctrl, h = W:Toggle(p, d.text, 0, d.getValue, d.setValue)
        elseif d.type == "slider" then
            ctrl, h = W:Slider(p, d.text, 0, d.getValue, d.setValue, d.min, d.max, d.step, d.fmt, d.sliderOptions)
        elseif d.type == "dropdown" then
            ctrl, h = W:Dropdown(p, d.text, 0, d.values, d.getValue, d.setValue, d.order,
                d.preview or d.fontPreview)
        elseif d.type == "colorpicker" then
            ctrl, h = W:ColorSwatch(p, d.text, 0, d.getValue, d.setValue, d.hasAlpha)
        elseif d.type == "multiSwatch" then
            ctrl, h = W:MultiSwatch(p, d.text, 0, d.swatches)
        elseif d.type == "button" then
            ctrl, h = W:Button(p, d.text, 0, d.onClick, nil, nil, nil, "CENTER", nil, d.variant or "short")
        end
        p._control = ctrl
        return h
    end

    local h1 = Create(leftC, leftData)
    local h2 = Create(rightC, rightData)
    local maxH = math.max(h1, h2)

    row:SetHeight(maxH)
    leftC:SetHeight(maxH)
    rightC:SetHeight(maxH)

    row._leftRegion = leftC
    row._rightRegion = rightC

    return row, maxH
end
