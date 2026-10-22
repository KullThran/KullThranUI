-------------------------------------------------------------------------------
--  Minimap theme decor: what each Visual Style draws around the KUI minimap.
--
--    square frame   KUI keeps its pixel border; Retail a grey bevel with Blizzard's
--                   gold chevrons, Forever the bronze frame, Classic the gold dialog edge.
--    zone header    the zone name sits on a small plate in the style's colours (square
--                   shape: every style; round shape: every style but KUI).
--    side buttons   Teleport / Guild / Friends / KUI options, plus Calendar, Mail and
--                   Tracking: KUI flat accent squares; Retail Blizzard GoldRing, Forever
--                   the bronze tracking ring, Classic the vanilla MiniMap-TrackingBorder.
--                   Calendar, Mail and Tracking keep their own icon art (keepIcon).
--
--  db.squareStyle = nil/"auto" follows the rendered Visual Style; "kui" / "retail" /
--  "forever" / "classic" force one. All art ships with KUI or is native to both clients.
-------------------------------------------------------------------------------
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local Mod = KT:GetModule("Minimap", true)
if not Mod then return end

local CreateFrame = _G.CreateFrame
local ipairs = _G.ipairs
local math = _G.math

local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
local RETAIL_RING_SHEET = MEDIA .. "minimap\\UIMinimap-Retail.blp"
local FOREVER_RING_SHEET = MEDIA .. "minimap\\UI-HUD-Minimap-Frame-C60.blp"
local CHAT_RETAIL = MEDIA .. "chat\\chat_retail.tga"
local CHAT_FOREVER = MEDIA .. "chat\\chat_forever.tga"
local DISC = "Interface\\Minimap\\UI-Minimap-Background"
local ROUND_HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

-- Sheet pieces: file, sheet w/h, rect { x, y, w, h }, nine-slice corner (sheet px)
local PIECES = {
    retailFrame = { file = CHAT_RETAIL, w = 256, h = 256, rect = { 1, 1, 22, 22 }, corner = 7 },
    retailChevronTop = { file = RETAIL_RING_SHEET, w = 512, h = 512, rect = { 186, 30, 68, 24 } },
    retailChevronBottom = { file = RETAIL_RING_SHEET, w = 512, h = 512, rect = { 192, 465, 56, 19 } },
    foreverFrame = { file = CHAT_FOREVER, w = 512, h = 256, rect = { 35, 1, 80, 80 }, corner = 14 },
    foreverTab = { file = CHAT_FOREVER, w = 512, h = 256, rect = { 117, 1, 96, 30 }, corner = 10 },
    foreverChevron = { file = FOREVER_RING_SHEET, w = 512, h = 512, rect = { 103, 259, 49, 33 } },
    foreverRing = { file = FOREVER_RING_SHEET, w = 512, h = 512, rect = { 257, 257, 40, 40 } },
}

-- Per-style look. ring: texture, size, anchor offset; iconTint for the KUI glyph icons.
local STYLES = {
    retail = {
        neutral = { 1, 0.82, 0 },
        ring = { file = "Interface\\Common\\GoldRing", size = 25, center = true },
        disc = 20, iconTint = { 1, 0.94, 0.80 },
    },
    forever = {
        neutral = { 0.94, 0.84, 0.67 },
        ring = { piece = "foreverRing", size = 25, center = true },
        disc = 21, iconTint = { 0.925, 0.815, 0.667 },
    },
    classic = {
        neutral = { 1, 0.82, 0 },
        -- LibDBIcon geometry: the ring sits in the top-left of its 64 px art.
        ring = { file = "Interface\\Minimap\\MiniMap-TrackingBorder", size = 36, center = false },
        disc = 18, iconTint = { 1, 0.82, 0.10 },
    },
}
Mod.ThemeDecorStyles = STYLES

local function SetPiece(texture, key)
    local p = PIECES[key]
    local r = p.rect
    texture:SetTexture(p.file)
    texture:SetTexCoord(r[1] / p.w, (r[1] + r[3]) / p.w, r[2] / p.h, (r[2] + r[4]) / p.h)
    texture:SetVertexColor(1, 1, 1, 1)
end

function Mod:GetDecorStyleKey()
    local key = self.db and self.db.squareStyle
    if key == "kui" or STYLES[key] then return key end
    local vt = KT.VisualThemes
    local theme = vt and vt.GetRenderedTheme and vt:GetRenderedTheme()
    return STYLES[theme] and theme or "kui"
end

function Mod:SquareThemeActive()
    return self.db and self.db.shape == "SQUARE" and self:GetDecorStyleKey() ~= "kui"
end

-- Zone name colour when the zone has no PvP colour of its own.
function Mod:GetZoneNeutralColor()
    local style = STYLES[self:GetDecorStyleKey()]
    if style then return style.neutral[1], style.neutral[2], style.neutral[3] end
    return 1, 1, 1
end

-------------------------------------------------------------------------------
--  Nine-slice frame (border only) drawn `outset` px outside `target`.
-------------------------------------------------------------------------------
local SLICES = { "TL", "T", "TR", "L", "R", "BL", "B", "BR" }

local function EnsureSlices(owner, key, parent, layer)
    owner[key] = owner[key] or {}
    local set = owner[key]
    for _, name in ipairs(SLICES) do
        set[name] = set[name] or parent:CreateTexture(nil, layer or "ARTWORK")
    end
    return set
end

local function HideSlices(set)
    if not set then return end
    for _, name in ipairs(SLICES) do
        if set[name] then set[name]:Hide() end
    end
end

local function LayoutSlices(set, pieceKey, target, edge, outset, includeCenter)
    local p = PIECES[pieceKey]
    local x, y, w, h = p.rect[1], p.rect[2], p.rect[3], p.rect[4]
    local c = p.corner
    local L, R = x / p.w, (x + w) / p.w
    local T, B = y / p.h, (y + h) / p.h
    local cl, cr = (x + c) / p.w, (x + w - c) / p.w
    local ct, cb = (y + c) / p.h, (y + h - c) / p.h
    local coords = {
        TL = { L, cl, T, ct }, T = { cl, cr, T, ct }, TR = { cr, R, T, ct },
        L = { L, cl, ct, cb }, R = { cr, R, ct, cb },
        BL = { L, cl, cb, B }, B = { cl, cr, cb, B }, BR = { cr, R, cb, B },
    }
    for _, name in ipairs(SLICES) do
        local t = set[name]
        t:SetTexture(p.file)
        t:SetTexCoord(unpack(coords[name]))
        t:SetVertexColor(1, 1, 1, 1)
        t:ClearAllPoints()
        t:Show()
    end
    local o = outset or 0
    set.TL:SetPoint("TOPLEFT", target, "TOPLEFT", -o, o); set.TL:SetSize(edge, edge)
    set.TR:SetPoint("TOPRIGHT", target, "TOPRIGHT", o, o); set.TR:SetSize(edge, edge)
    set.BL:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", -o, -o); set.BL:SetSize(edge, edge)
    set.BR:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", o, -o); set.BR:SetSize(edge, edge)
    set.T:SetPoint("TOPLEFT", set.TL, "TOPRIGHT"); set.T:SetPoint("BOTTOMRIGHT", set.TR, "BOTTOMLEFT")
    set.B:SetPoint("TOPLEFT", set.BL, "TOPRIGHT"); set.B:SetPoint("BOTTOMRIGHT", set.BR, "BOTTOMLEFT")
    set.L:SetPoint("TOPLEFT", set.TL, "BOTTOMLEFT"); set.L:SetPoint("BOTTOMRIGHT", set.BL, "TOPRIGHT")
    set.R:SetPoint("TOPLEFT", set.TR, "BOTTOMLEFT"); set.R:SetPoint("BOTTOMRIGHT", set.BR, "TOPRIGHT")
    if includeCenter then
        set.C = set.C or set.T:GetParent():CreateTexture(nil, "BACKGROUND")
        set.C:SetTexture(p.file)
        set.C:SetTexCoord(cl, cr, ct, cb)
        set.C:ClearAllPoints()
        set.C:SetPoint("TOPLEFT", set.TL, "BOTTOMRIGHT")
        set.C:SetPoint("BOTTOMRIGHT", set.BR, "TOPLEFT")
        set.C:Show()
    elseif set.C then
        set.C:Hide()
    end
end

-------------------------------------------------------------------------------
--  Square frame
-------------------------------------------------------------------------------
function Mod:UpdateSquareThemeFrame()
    local holder = _G.KT_MinimapHolder_Main
    if not holder then return end
    local frame = holder.KT_ThemeFrame
    if not self:SquareThemeActive() then
        if frame then frame:Hide() end
        return
    end
    if not frame then
        frame = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        frame:EnableMouse(false)
        frame.chevronTop = frame:CreateTexture(nil, "OVERLAY")
        frame.chevronBottom = frame:CreateTexture(nil, "OVERLAY")
        holder.KT_ThemeFrame = frame
    end
    frame:SetAllPoints(holder)
    frame:SetFrameStrata(holder:GetFrameStrata())
    frame:SetFrameLevel(holder:GetFrameLevel() + 4)
    frame:Show()

    local key = self:GetDecorStyleKey()
    HideSlices(frame.slices)
    frame.chevronTop:Hide()
    frame.chevronBottom:Hide()
    if frame.SetBackdrop then frame:SetBackdrop(nil) end

    if key == "retail" then
        LayoutSlices(EnsureSlices(frame, "slices", frame), "retailFrame", holder, 7, 3)
        SetPiece(frame.chevronTop, "retailChevronTop")
        frame.chevronTop:ClearAllPoints()
        frame.chevronTop:SetSize(34, 12)
        frame.chevronTop:SetPoint("BOTTOM", holder, "TOP", 0, -3)
        frame.chevronTop:Show()
        SetPiece(frame.chevronBottom, "retailChevronBottom")
        frame.chevronBottom:ClearAllPoints()
        frame.chevronBottom:SetSize(28, 9.5)
        frame.chevronBottom:SetPoint("TOP", holder, "BOTTOM", 0, 1)
        frame.chevronBottom:Show()
    elseif key == "forever" then
        LayoutSlices(EnsureSlices(frame, "slices", frame), "foreverFrame", holder, 8, 5)
    elseif key == "classic" and frame.SetBackdrop then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", holder, "TOPLEFT", -6, 6)
        frame:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 6, -6)
        frame:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", edgeSize = 14 })
        frame:SetBackdropBorderColor(1, 1, 1, 1)
    end
end

-------------------------------------------------------------------------------
--  Zone header plate
-------------------------------------------------------------------------------
local PLATE_HEIGHT = { kui = 17, retail = 20, forever = 22, classic = 20 }

function Mod:UpdateZoneHeaderStyle()
    local zone = _G.KT_MinimapZoneText
    local text = zone and zone.text
    if not text then return end
    local plate = zone.KT_Plate
    -- Square shape: every style. Round shape: the Visual Styles only (KUI keeps
    -- its bare text over the round map).
    local isSquare = self.db and self.db.shape == "SQUARE"
    if not self.db or (not isSquare and self:GetDecorStyleKey() == "kui") then
        if plate then plate:Hide() end
        return
    end
    if not plate then
        plate = CreateFrame("Frame", nil, zone, "BackdropTemplate")
        plate:EnableMouse(false)
        plate:SetFrameLevel(math.max(0, zone:GetFrameLevel() - 1))
        plate.fill = plate:CreateTexture(nil, "BACKGROUND")
        plate.line = plate:CreateTexture(nil, "ARTWORK")
        plate.chevron = plate:CreateTexture(nil, "OVERLAY")
        zone.KT_Plate = plate
    end
    local key = self:GetDecorStyleKey()
    local height = PLATE_HEIGHT[key] or 18
    local width = math.max(96, math.floor((text:GetStringWidth() or 0) + 30))
    plate:ClearAllPoints()
    plate:SetPoint("CENTER", zone, "CENTER", 0, 0)
    plate:SetSize(width, height)
    plate:Show()

    HideSlices(plate.slices)
    plate.line:Hide()
    plate.chevron:Hide()
    plate.fill:Show()
    if plate.SetBackdrop then plate:SetBackdrop(nil) end
    plate.fill:ClearAllPoints()

    if key == "retail" then
        plate.fill:SetPoint("TOPLEFT", 2, -2)
        plate.fill:SetPoint("BOTTOMRIGHT", -2, 2)
        plate.fill:SetColorTexture(0.055, 0.055, 0.07, 0.92)
        LayoutSlices(EnsureSlices(plate, "slices", plate), "retailFrame", plate, 7, 0)
        plate.line:ClearAllPoints()
        plate.line:SetPoint("BOTTOMLEFT", 6, 3)
        plate.line:SetPoint("BOTTOMRIGHT", -6, 3)
        plate.line:SetHeight(1)
        plate.line:SetColorTexture(1, 0.78, 0.16, 0.9)
        plate.line:Show()
    elseif key == "forever" then
        plate.fill:Hide()
        LayoutSlices(EnsureSlices(plate, "slices", plate), "foreverTab", plate, 7, 0, true)
        SetPiece(plate.chevron, "foreverChevron")
        plate.chevron:ClearAllPoints()
        plate.chevron:SetSize(20, 13.5)
        plate.chevron:SetPoint("BOTTOM", plate, "TOP", 0, -4.5)
        plate.chevron:Show()
    elseif key == "classic" and plate.SetBackdrop then
        plate.fill:SetPoint("TOPLEFT", 3, -3)
        plate.fill:SetPoint("BOTTOMRIGHT", -3, 3)
        plate.fill:SetColorTexture(0, 0, 0, 0.85)
        plate:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
        plate:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    else
        plate.fill:SetAllPoints()
        plate.fill:SetColorTexture(0.03, 0.03, 0.04, 0.78)
        local r, g, b = 1, 0.486275, 0.039216
        if KT.GetStyleAccentRGB then
            local ar, ag, ab = KT:GetStyleAccentRGB()
            if ar then r, g, b = ar, ag, ab end
        end
        plate.line:ClearAllPoints()
        plate.line:SetPoint("BOTTOMLEFT", 0, 0)
        plate.line:SetPoint("BOTTOMRIGHT", 0, 0)
        plate.line:SetHeight(1)
        plate.line:SetColorTexture(r, g, b, 1)
        plate.line:Show()
    end

    -- The location line below the plate keeps clear of its taller bottom edge.
    local location = _G.KT_MinimapLocation
    if location then
        location:ClearAllPoints()
        location:SetPoint("TOP", zone, "BOTTOM", 0, -1 - math.max(0, (height - (zone:GetHeight() or 16)) / 2))
    end
end

-------------------------------------------------------------------------------
--  Side buttons (Teleport, Guild, Friends, KUI options)
-------------------------------------------------------------------------------
local function ButtonParts(button)
    local background = button._ktModernIconBackground or button._ktModernBackground
    local icon = button.Icon or button._ktPortalIcon
    local highlight = button._ktModernIconHighlight
    return background, icon, highlight
end

-- keepIcon: only the frame changes (round disc + ring); the icon keeps its own
-- size, position and colours (Calendar, Mail, Tracking).
function Mod:DecorateSideButton(button, isPortal, keepIcon)
    if not button then return end
    local key = self:GetDecorStyleKey()
    local style = STYLES[key]
    local background, icon, highlight = ButtonParts(button)
    local deco = button.KT_ThemeDeco
    if not style then
        if deco then
            deco.disc:Hide(); deco.ring:Hide(); deco.glow:Hide()
            if isPortal and icon and not keepIcon then
                icon:ClearAllPoints()
                icon:SetPoint("CENTER", button, "CENTER", 0, 0)
                icon:SetSize(16, 16)
            end
        end
        if background then background:Show() end
        if highlight then highlight:SetAlpha(1) end
        return
    end
    if not deco then
        deco = {
            disc = button:CreateTexture(nil, "BACKGROUND", nil, 1),
            ring = button:CreateTexture(nil, "OVERLAY", nil, 2),
            glow = button:CreateTexture(nil, "HIGHLIGHT"),
        }
        button.KT_ThemeDeco = deco
    end
    if background then background:Hide() end
    if highlight then highlight:SetAlpha(0) end
    -- The Teleport button hides every texture it does not own: undo that for ours.
    deco.disc:SetAlpha(1); deco.ring:SetAlpha(1); deco.glow:SetAlpha(1)

    deco.disc:SetTexture(DISC)
    deco.disc:ClearAllPoints()
    deco.disc:SetSize(style.disc, style.disc)
    deco.disc:SetPoint("CENTER", button, "CENTER", 0, 0)
    deco.disc:Show()

    local ring = style.ring
    if ring.piece then
        SetPiece(deco.ring, ring.piece)
    else
        deco.ring:SetTexture(ring.file)
        deco.ring:SetTexCoord(0, 1, 0, 1)
        deco.ring:SetVertexColor(1, 1, 1, 1)
    end
    deco.ring:ClearAllPoints()
    deco.ring:SetSize(ring.size, ring.size)
    if ring.center then
        deco.ring:SetPoint("CENTER", button, "CENTER", 0, 0)
    else
        deco.ring:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    end
    deco.ring:Show()

    deco.glow:SetTexture(ROUND_HIGHLIGHT)
    deco.glow:SetBlendMode("ADD")
    deco.glow:ClearAllPoints()
    deco.glow:SetSize(style.disc + 4, style.disc + 4)
    deco.glow:SetPoint("CENTER", button, "CENTER", 0, 0)
    deco.glow:Show()

    if icon and not keepIcon then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", button, "CENTER", 0, 0)
        icon:SetSize(14, 14)
        if not isPortal then
            icon:SetVertexColor(style.iconTint[1], style.iconTint[2], style.iconTint[3], 1)
        end
    end
end

function Mod:ApplyThemedSideIcons()
    for _, button in ipairs({ self.guildMinimapButton, self.friendsMinimapButton, self.kuiSettingsButton }) do
        self:DecorateSideButton(button, false)
    end
    local LDBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
    local teleport = (LDBIcon and LDBIcon.GetMinimapButton and LDBIcon:GetMinimapButton("KT_Teleport"))
        or _G.KT_TeleportNativeButton
    if teleport and teleport._ktPortalIcon then
        self:DecorateSideButton(teleport, true)
    end
    local tracking = (_G.MinimapCluster and _G.MinimapCluster.Tracking) or _G.MiniMapTracking
    for _, button in ipairs({ self.calendarButton, self.mailButton, tracking }) do
        if button and button._ktModernIconBackground then
            self:DecorateSideButton(button, false, true)
        end
    end
end

-- One call after a minimap refresh or a Visual Style change.
function Mod:UpdateThemeDecor()
    self:UpdateSquareThemeFrame()
    self:UpdateZoneHeaderStyle()
    self:ApplyThemedSideIcons()
end
