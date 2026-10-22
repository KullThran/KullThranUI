-- MenuSkins.lua
-- Skins for the options window: painted canvas files plus the colour tokens
-- the window and Widgets.lua read. The active skin follows the visual style
-- chosen for the unit frames (KT.VisualThemes:GetRenderedTheme()).
local addonName, ns = ...
local KT = ns.KT

KT.MenuSkins = KT.MenuSkins or {}
local MS = KT.MenuSkins

MS.TEXTURE_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\MenuSkins\\"
MS.DEFAULT = "kui"

local GOLD = { 1.00, 0.82, 0.10 }

-- kui holds every token; the themed skins override only what differs and
-- fall back to kui for the rest.
MS.skins = {
    kui = {
        files  = { base = "kui_base", light = "kui_light", glow = "kui_glow" },
        accent = "user",
        light  = { color = "accent", alpha = 0.9 },
        logo   = "code",
        colors = {
            text         = { 1, 1, 1, 1 },
            muted        = { 0.74, 0.74, 0.78, 1 },
            sectionText  = { 0.74, 0.74, 0.78, 1 },
            card         = { 0.086, 0.078, 0.073, 0.97 },
            cardBorder   = { 0.150, 0.135, 0.122, 1 },
            cardBack     = { 0.130, 0.100, 0.082, 1 },  -- plate peeking out behind a card
            rowA         = { 1, 1, 1, 0 },     -- rows are open; hover lights a pill
            rowB         = { 1, 1, 1, 0 },
            rowHover     = { 0.125, 0.112, 0.098, 1 },
            divider      = { 1, 1, 1, 0.06 },
            controlTrack = { 0.227, 0.208, 0.196, 1 },
            controlOff   = { 0.160, 0.150, 0.170, 1 },
            controlBg    = { 0.135, 0.122, 0.110, 1 },  -- dropdown, input and value boxes
            segmentTrack = { 0.040, 0.036, 0.034, 0.92 }, -- track behind the page tabs
        },
        fonts  = {},
    },
    forever = {
        accent = { 0.862745, 0.521569, 0.376471 }, -- #DC8560, as ThemeEngine's Forever chrome
        light  = { color = { 0.45, 0.75, 1.0 }, alpha = 0.9 },
        logo   = "art",
        colors = {},
    },
    retail = {
        accent = GOLD,
        light  = { color = GOLD, alpha = 0.9 },
        logo   = "art",
        colors = {},
    },
    classic = {
        accent = GOLD,
        light  = { color = GOLD, alpha = 0.9 },
        logo   = "art",
        colors = {},
    },
}

local listeners = {}

function MS:GetActive()
    local themes = KT.VisualThemes
    local id = themes and themes.GetRenderedTheme and themes:GetRenderedTheme()
    if id and self.skins[id] then return id end
    return self.DEFAULT
end

local function ActiveSkin(self)
    return self.skins[self:GetActive()] or self.skins[self.DEFAULT]
end

function MS:Token(name)
    local skin = ActiveSkin(self)
    local base = self.skins[self.DEFAULT]
    local value = skin.colors and skin.colors[name]
    if value == nil then value = skin[name] end
    if value == nil then value = base.colors[name] end
    if value == nil then value = base[name] end
    return value
end

function MS:Color(name)
    local c = self:Token(name)
    if type(c) ~= "table" then return 1, 1, 1, 1 end
    return c[1], c[2], c[3], c[4] or 1
end

local function UserAccent()
    local palette = KT.GetStylePalette and KT:GetStylePalette() or KT.STYLE_PALETTE
    local accent = palette and palette.accent
    if accent and accent.r then return accent.r, accent.g, accent.b end
    return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333
end

function MS:Accent()
    local accent = ActiveSkin(self).accent
    if type(accent) == "table" then return accent[1], accent[2], accent[3] end
    return UserAccent()
end

function MS:LightColor()
    local light = self:Token("light") or {}
    local alpha = light.alpha or 1
    if type(light.color) == "table" then
        return light.color[1], light.color[2], light.color[3], alpha
    end
    local r, g, b = self:Accent()
    return r, g, b, alpha
end

function MS:Files(id)
    local skin = self.skins[id or self:GetActive()] or self.skins[self.DEFAULT]
    local files = skin.files or self.skins[self.DEFAULT].files
    if not files then return nil end
    local paths = {}
    for layer, name in pairs(files) do
        paths[layer] = self.TEXTURE_PATH .. name
    end
    return paths
end

function MS:RegisterRepaint(fn)
    listeners[#listeners + 1] = fn
end

function MS:Repaint()
    local id = self:GetActive()
    for _, fn in ipairs(listeners) do
        pcall(fn, id)
    end
end
