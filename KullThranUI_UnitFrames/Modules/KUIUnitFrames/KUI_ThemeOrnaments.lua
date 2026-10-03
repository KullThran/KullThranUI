-------------------------------------------------------------------------------
--  Per-style ornaments for the Player / Target frames:
--    * PvP backdrop circle drawn with each visual style's own art.
--    * Combo point art (Classic or Retail/Forever) and Blizzard's own combo
--      point positions around the target portrait.
-------------------------------------------------------------------------------
local _, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

local O = ns.KUIOrnaments or {}
ns.KUIOrnaments = O

local FOREVER_SHEET = [[Interface\AddOns\KullThranUI\Libraries\texture\media\portraits\forever_unitframe.tga]]
local CLASSIC_RING = [[Interface\Minimap\MiniMap-TrackingBorder]]
local COMBO_FILE = [[Interface\ComboFrame\ComboPoint]]

local function HasAtlas(name)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

local function RenderedTheme()
    local VT = KT.VisualThemes
    return VT and VT.GetRenderedTheme and VT:GetRenderedTheme() or "kui"
end

local function Unsnap(tex)
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
end

-------------------------------------------------------------------------------
--  PvP circle
-------------------------------------------------------------------------------
local function PvPArt(frame)
    local art = frame._kuiPvPThemeCircle
    if not art then
        local parent = frame._kuiPvPIcon and frame._kuiPvPIcon:GetParent() or frame
        art = parent:CreateTexture(nil, "OVERLAY", nil, -1)
        Unsnap(art)
        art:Hide()
        frame._kuiPvPThemeCircle = art
    end
    return art
end

-- Draws the style's own circle behind the PvP icon. Returns true when the
-- style art replaced the generic disc + border.
local function ApplyStyleCircle(frame, theme)
    local icon = frame._kuiPvPIcon
    local art = PvPArt(frame)
    art:ClearAllPoints()
    art:SetVertexColor(1, 1, 1, 1)
    if theme == "forever" then
        -- Forever's PvpBackgroundCircle (UI-HUD-UnitFrame-SmallCircle at 0.8
        -- scale), from the shipped Forever sheet: the Retail client's own
        -- atlas of that name is not the same art.
        art:SetTexture(FOREVER_SHEET)
        art:SetTexCoord(207 / 256, 242 / 256, 3 / 512, 38 / 512)
        art:SetSize(28, 28)
        art:SetPoint("CENTER", icon, "CENTER", 0, 0)
        return true
    elseif theme == "retail" then
        if not HasAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-IconRing") then return false end
        art:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-IconRing", false)
        art:SetSize(30, 30)
        art:SetPoint("CENTER", icon, "CENTER", 0, 0)
        return "ring"
    elseif theme == "classic" then
        -- Classic's round button border; its ring sits in the top-left of a
        -- 53x53 overlay drawn over a 31x31 button.
        art:SetTexture(CLASSIC_RING)
        art:SetTexCoord(0, 1, 0, 1)
        local k = 0.85
        art:SetSize(53 * k, 53 * k)
        art:SetPoint("TOPLEFT", icon, "CENTER", -15.5 * k, 14.5 * k)
        return "ring"
    end
    return false
end

function O.ApplyPvPCircle(frame)
    if not (frame and frame._kuiPvPIcon and frame._kuiPvPCircle) then return end
    local art = PvPArt(frame)
    local wanted = frame._kuiPvPIcon:IsShown() and frame._kuiPvPCircle:IsShown()
    if not wanted then
        art:Hide()
        return
    end
    local mode = ApplyStyleCircle(frame, RenderedTheme())
    if not mode then
        art:Hide()
        return
    end
    if frame._kuiPvPCircleBorder then frame._kuiPvPCircleBorder:Hide() end
    if mode == true then
        -- The Forever sprite is a filled disc with its own rim.
        frame._kuiPvPCircle:Hide()
    else
        frame._kuiPvPCircle:SetSize(22, 22)
    end
    art:Show()
end

-- Level badge: Forever draws its small circle (LevelBackgroundCircle) and
-- Classic shows the ring from its own frame sheet, instead of the generic
-- dark disc.
function O.ApplyLevelCircle(frame)
    local disc = frame and frame._kuiLevelCircle
    if not disc then return end
    local art = frame._kuiLevelThemeCircle
    if not art then
        art = disc:GetParent():CreateTexture(nil, "OVERLAY", nil, 0)
        Unsnap(art)
        art:Hide()
        frame._kuiLevelThemeCircle = art
    end
    local theme = RenderedTheme()
    if theme == "classic" then
        -- Classic's frame sheet already draws its own level ring at this spot.
        art:Hide()
        disc:SetAlpha(0)
        return
    end
    if not disc:IsShown() then
        art:Hide()
        disc:SetAlpha(1)
        return
    end
    local size = (disc:GetWidth() or 32)
    if theme == "forever" then
        art:SetTexture(FOREVER_SHEET)
        art:SetTexCoord(207 / 256, 242 / 256, 3 / 512, 38 / 512)
        art:SetVertexColor(1, 1, 1, 1)
        size = size + 2
        disc:SetAlpha(0)
    elseif theme == "retail" and HasAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-IconRing") then
        -- Retail's gold icon ring over the dark disc.
        art:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Boss-IconRing", false)
        art:SetVertexColor(1, 1, 1, 1)
        size = size + 2
        disc:SetAlpha(1)
    else
        art:Hide()
        disc:SetAlpha(1)
        return
    end
    art:ClearAllPoints()
    art:SetSize(size, size)
    art:SetPoint("CENTER", disc, "CENTER", 0, 0)
    art:Show()
end

-------------------------------------------------------------------------------
--  Combo point art
-------------------------------------------------------------------------------
-- "classic" (Interface\ComboFrame) or "modern" (Retail / Forever atlases).
function O.GetComboArt()
    local uf = KT.db and KT.db.profile and KT.db.profile.unitFrames
    local v = uf and uf.comboRingArt
    if v == "classic" or v == "modern" then return v end
    return RenderedTheme() == "classic" and "classic" or "modern"
end

-- Blizzard ComboFrame pip centres (ComboFrame.xml), measured from the centre
-- of the 64px Classic target portrait and divided by its 32px radius.
local BLIZZARD_PIPS = {
    { -15 / 32, 36 / 32 },
    { -2.5 / 32, 37 / 32 },
    { 10 / 32, 36 / 32 },
    { 21.5 / 32, 30.5 / 32 },
    { 30.5 / 32, 22 / 32 },
    { 36 / 32, 10.5 / 32 },
    { 38 / 32, -1 / 32 },
    { 36 / 32, -12 / 32 },
    { 48 / 32, -4 / 32 },
}

-- Same rule as ComboFrame_UpdateMax: 6 or 9 max points use the first slot,
-- otherwise it is skipped; points from `extra` on only show when filled.
function O.ComboSlots(maxPower)
    local start, extra = 2, 6
    if maxPower == 6 or maxPower == 9 then start, extra = 1, 7 end
    local slots = {}
    for i = 1, maxPower do
        local idx = start + i - 1
        if idx > #BLIZZARD_PIPS then break end
        slots[i] = { BLIZZARD_PIPS[idx][1], BLIZZARD_PIPS[idx][2], onlyFilled = i >= extra }
    end
    return slots
end

local function RegionBox(region, ref)
    if not (region and region.IsShown and region:IsShown() and region.GetCenter) then return nil end
    local cx, cy = region:GetCenter()
    local rx, ry = ref:GetCenter()
    if not (cx and rx) then return nil end
    local es, rs = region:GetEffectiveScale(), ref:GetEffectiveScale()
    local w, h = region:GetWidth() or 0, region:GetHeight() or 0
    if region.GetStringWidth then
        local sw = region:GetStringWidth()
        if sw and sw > 0 then w = math.min(w > 0 and w or sw, sw) end
        local sh = region.GetStringHeight and region:GetStringHeight()
        if sh and sh > 0 then h = sh end
    end
    return (cx * es - rx * rs) / rs, (cy * es - ry * rs) / rs, math.max(w, h) * es / rs * 0.5
end

-- Pip centres around `portrait` (ring-local offsets). Follows Blizzard's
-- arc, mirrored when the portrait sits on the left, and turned toward the
-- top just enough to clear the PvP badge and the level.
function O.LayoutRing(frame, portrait, maxPower, pipSize, above)
    local radius = (portrait:GetWidth() or 46) * 0.5
    local slots = O.ComboSlots(maxPower)
    local fx = frame.GetCenter and frame:GetCenter()
    local px = portrait:GetCenter()
    local mirror = fx and px and px < fx

    local obstacles = {}
    for _, key in ipairs({ "_kuiPvPThemeCircle", "_kuiPvPCircle", "_kuiPvPIcon",
        "_kuiLevelCircle", "_kuiLevelText" }) do
        local ox, oy, orad = RegionBox(frame[key], portrait)
        if ox then obstacles[#obstacles + 1] = { ox, oy, orad } end
    end

    local function Place(rotDeg)
        local a = math.rad(rotDeg)
        local ca, sa = math.cos(a), math.sin(a)
        local out, overlap = {}, 0
        for i, s in ipairs(slots) do
            local x, y = s[1] * radius, s[2] * radius
            x, y = x * ca - y * sa, x * sa + y * ca
            if mirror then x = -x end
            out[i] = { x, y, onlyFilled = s.onlyFilled }
            for _, o in ipairs(obstacles) do
                local d = math.sqrt((x - o[1]) ^ 2 + (y - o[2]) ^ 2)
                local need = pipSize * 0.5 + o[3] + 1
                if d < need then overlap = overlap + (need - d) end
            end
        end
        return out, overlap
    end

    local base = above and 40 or 0
    local best, bestOverlap
    for step = 0, 18 do
        local out, overlap = Place(base + step * 4)
        if overlap == 0 then return out end
        if not bestOverlap or overlap < bestOverlap then best, bestOverlap = out, overlap end
    end
    return best
end

-- One pip: socket + fill using the chosen art. `size` is the pip's width.
function O.StylePip(pip, art, size)
    if pip._ktArt == art and pip._ktArtSize == size then return end
    pip._ktArt, pip._ktArtSize = art, size
    if not pip._socket then
        pip._socket = pip:CreateTexture(nil, "BACKGROUND", nil, 1)
        pip._lit = pip:CreateTexture(nil, "ARTWORK", nil, 1)
        Unsnap(pip._socket)
        Unsnap(pip._lit)
    end
    local socket, lit = pip._socket, pip._lit
    socket:ClearAllPoints()
    lit:ClearAllPoints()
    if art == "classic" then
        -- ComboPointTemplate: 12x12 frame, 12x16 socket and 8x16 highlight
        -- hanging from its top-left corner.
        local k = size / 12
        socket:SetTexture(COMBO_FILE)
        socket:SetTexCoord(0, 0.375, 0, 1)
        socket:SetVertexColor(1, 1, 1, 1)
        socket:SetSize(12 * k, 16 * k)
        socket:SetPoint("TOPLEFT", pip, "TOPLEFT", 0, 0)
        lit:SetTexture(COMBO_FILE)
        lit:SetTexCoord(0.375, 0.5625, 0, 1)
        lit:SetSize(8 * k, 16 * k)
        lit:SetPoint("TOPLEFT", pip, "TOPLEFT", 2 * k, 0)
        lit:SetVertexColor(1, 1, 1, 1)
    elseif HasAtlas("uf-roguecp-bg") and HasAtlas("uf-roguecp-icon-red") then
        local bg = C_Texture.GetAtlasInfo("uf-roguecp-bg")
        local ic = C_Texture.GetAtlasInfo("uf-roguecp-icon-red")
        local k = size / math.max(1, bg.width or size)
        socket:SetAtlas("uf-roguecp-bg", false)
        socket:SetVertexColor(1, 1, 1, 1)
        socket:SetSize(size, (bg.height or size) * k)
        socket:SetPoint("CENTER", pip, "CENTER", 0, 0)
        lit:SetAtlas("uf-roguecp-icon-red", false)
        lit:SetSize((ic.width or size) * k, (ic.height or size) * k)
        lit:SetPoint("CENTER", pip, "CENTER", 0, 0)
        lit:SetVertexColor(1, 1, 1, 1)
    else
        socket:SetTexture("Interface\\COMMON\\Indicator-Gray")
        socket:SetTexCoord(0, 1, 0, 1)
        socket:SetVertexColor(0.08, 0.08, 0.08, 1)
        socket:SetSize(size, size)
        socket:SetPoint("CENTER", pip, "CENTER", 0, 0)
        lit:SetTexture("Interface\\COMMON\\Indicator-Red")
        lit:SetTexCoord(0, 1, 0, 1)
        lit:SetSize(size, size)
        lit:SetPoint("CENTER", pip, "CENTER", 0, 0)
    end
    if pip._secretBar then
        -- Secret values can only drive a StatusBar: give it a fill that
        -- reads as the lit point.
        local fill = (art == "classic" and HasAtlas("ComboPoints-ComboPoint") and "ComboPoints-ComboPoint")
            or (art ~= "classic" and HasAtlas("uf-roguecp-icon-red") and "uf-roguecp-icon-red") or nil
        local t = pip._secretBar:GetStatusBarTexture()
        if fill and t then
            t:SetAtlas(fill, false)
        else
            pip._secretBar:SetStatusBarTexture("Interface\\COMMON\\Indicator-Red")
        end
        pip._secretBar:ClearAllPoints()
        pip._secretBar:SetAllPoints(lit)
    end
end
