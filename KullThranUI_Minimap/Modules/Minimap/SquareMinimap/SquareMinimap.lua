-------------------------------------------------------------------------------
--  Minimap theme decor: what each Visual Style draws around the KUI minimap.
--
--    square frame   KUI keeps its pixel border; Retail a grey bevel with Blizzard's
--                   gold chevrons, Forever the bronze frame of its client's windows,
--                   Classic the gold dialog edge.
--    zone header    square shape: the zone name sits in a title bar joined to the
--                   style's frame; round shape: on a small plate in the style's
--                   colours (every style but KUI).
--    side buttons   Teleport / Guild / Friends / KUI options, plus Calendar, Mail and
--                   Tracking: KUI flat accent squares; Retail Blizzard GoldRing, Forever
--                   the bronze tracking ring, Classic the vanilla MiniMap-TrackingBorder.
--                   Calendar, Mail and Tracking keep their own icon art (keepIcon).
--
--  The look follows the "Minimap Style" cards (db.styleByTheme, per Visual Style; without
--  a choice, the Visual Style's own look). db.squareStyle / db.ringStyle still force one.
--  All art ships with KUI or is native to both clients. DrawSquareThemeFrame,
--  DrawSquareTitleBar and DrawZonePlate also paint the options preview (the first
--  two, the installer's as well).
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
-- Forever's window frame (UI-Frame-Metal, the -c60 art), baked as two panels:
-- with the windows' title bar, and closed under the top rim. 2 sheet px per unit.
local FOREVER_WINDOW_SHEET = MEDIA .. "minimap\\ForeverWindow.png"
local CHAT_RETAIL = MEDIA .. "chat\\chat_retail.tga"
local CHAT_FOREVER = MEDIA .. "chat\\chat_forever.tga"
local CLASSIC_EDGE = { file = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border", size = 18 }
local DISC = "Interface\\Minimap\\UI-Minimap-Background"
local ROUND_HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"

-- Sheet pieces: file, sheet w/h, rect { x, y, w, h }, nine-slice corner (sheet px)
local PIECES = {
    retailFrame = { file = CHAT_RETAIL, w = 256, h = 256, rect = { 1, 1, 22, 22 }, corner = 7 },
    retailChevronTop = { file = RETAIL_RING_SHEET, w = 512, h = 512, rect = { 186, 36, 68, 18 } },
    retailChevronBottom = { file = RETAIL_RING_SHEET, w = 512, h = 512, rect = { 192, 470, 56, 15 } },
    foreverWindow = { file = FOREVER_WINDOW_SHEET, w = 1024, h = 512, rect = { 4, 4, 440, 470 }, corner = 80 },
    foreverWindowPlain = { file = FOREVER_WINDOW_SHEET, w = 1024, h = 512, rect = { 452, 4, 440, 470 }, corner = 80 },
    foreverTab = { file = CHAT_FOREVER, w = 512, h = 256, rect = { 117, 1, 96, 30 }, corner = 10 },
    foreverChevron = { file = FOREVER_RING_SHEET, w = 512, h = 512, rect = { 103, 259, 49, 33 } },
    foreverRing = { file = FOREVER_RING_SHEET, w = 512, h = 512, rect = { 257, 257, 40, 40 } },
}

-- Forever's window frame around the square map, in map units: the bronze rim's
-- outer edge sits `rim` past the map (its corner cuts cover the map's corners);
-- the art's shadow reaches `shadow` further. Buttons beside the map stay
-- `buttonGap` outside the rim.
local WINDOW = { rim = 4, shadow = 6, corner = 40, buttonGap = 2 }

-- The square map's title bar, in map units above the map's top: `height` to its
-- outer edge, `frameTop` to the top of the style's frame art around it, and
-- `zoneLift` to the bottom of the 16 px zone line, centred in the dark band.
local TITLE = {
    kui = { height = 20, zoneLift = 2.5 },
    retail = { height = 21, frameTop = 24, zoneLift = 2.5 },
    forever = { height = 27, frameTop = 33, zoneLift = 4.5 }, -- the bar is part of the art
    classic = { height = 27, frameTop = 29, zoneLift = 5.5 },
}
-- The location line starts this far below the map's top, clear of the bar.
local LOCATION_DROP = 3

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

-- The minimap's own style: the "Minimap Style" card picked for the rendered
-- Visual Style, else that Visual Style's look.
function Mod:GetModuleStyleKey()
    local vt = KT.VisualThemes
    local key
    if vt and vt.ResolveModuleStyle then
        key = vt:ResolveModuleStyle(self.db)
    else
        key = vt and vt.GetRenderedTheme and vt:GetRenderedTheme()
    end
    return STYLES[key] and key or "kui"
end

function Mod:GetDecorStyleKey()
    local key = self.db and self.db.squareStyle
    if key == "kui" or STYLES[key] then return key end
    return self:GetModuleStyleKey()
end

function Mod:SquareThemeActive()
    return self.db and self.db.shape == "SQUARE" and self:GetDecorStyleKey() ~= "kui"
end

-- The square map wears Forever's window frame.
function Mod:SquareWindowActive()
    return self:SquareThemeActive() and self:GetDecorStyleKey() == "forever" or false
end

-- On the square map the zone name sits in the title bar.
function Mod:ZoneInTitleBar()
    return self.db and self.db.shape == "SQUARE" and self.db.showZone ~= false or false
end

-- How far the buttons around the map move out to clear its frame: beside and
-- below it, and above it.
function Mod:GetSideOutset()
    local side = self:SquareWindowActive() and (WINDOW.rim + WINDOW.buttonGap) or 0
    if not self:ZoneInTitleBar() then return side, side end
    local gap = side > 0 and WINDOW.buttonGap or 0
    return side, TITLE[self:GetDecorStyleKey()].height + gap
end

-- Style `key`'s title bar: how far the zone line rises over the map, and the gap
-- from it down to the location line.
function Mod:GetTitleBarMetrics(key)
    local title = TITLE[key or self:GetDecorStyleKey()] or TITLE.kui
    return title.zoneLift, title.zoneLift + LOCATION_DROP
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
-- Draws style `key`'s square frame on `frame` (a BackdropTemplate frame)
-- around `target`. `titleBar`: the frame also goes around the title bar above
-- it. Returns false for KUI, which keeps its pixel border.
function Mod:DrawSquareThemeFrame(frame, target, key, titleBar)
    frame.chevronTop = frame.chevronTop or frame:CreateTexture(nil, "OVERLAY")
    frame.chevronBottom = frame.chevronBottom or frame:CreateTexture(nil, "OVERLAY")
    HideSlices(frame.slices)
    frame.chevronTop:Hide()
    frame.chevronBottom:Hide()
    if frame.SetBackdrop then frame:SetBackdrop(nil) end
    frame:ClearAllPoints()
    frame:SetAllPoints(target)

    local title = titleBar and TITLE[key]
    if key == "retail" then
        local top = title and title.frameTop or 4
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", target, "TOPLEFT", -4, top)
        frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -4)
        LayoutSlices(EnsureSlices(frame, "slices", frame), "retailFrame", frame, 10, 0)
        SetPiece(frame.chevronTop, "retailChevronTop")
        frame.chevronTop:ClearAllPoints()
        frame.chevronTop:SetSize(34, 9)
        -- Over the bar it rises clear of the zone name.
        frame.chevronTop:SetPoint("BOTTOM", target, "TOP", 0, title and top - 5 or -4)
        frame.chevronTop:Show()
        SetPiece(frame.chevronBottom, "retailChevronBottom")
        frame.chevronBottom:ClearAllPoints()
        frame.chevronBottom:SetSize(28, 7.5)
        frame.chevronBottom:SetPoint("TOP", target, "BOTTOM", 0, -0.5)
        frame.chevronBottom:Show()
    elseif key == "forever" then
        local out = WINDOW.rim + WINDOW.shadow
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", target, "TOPLEFT", -out, title and title.frameTop or out)
        frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", out, -out)
        LayoutSlices(EnsureSlices(frame, "slices", frame), titleBar and "foreverWindow" or "foreverWindowPlain",
            frame, WINDOW.corner, 0)
    elseif key == "classic" and frame.SetBackdrop then
        frame:ClearAllPoints()
        frame:SetPoint("TOPLEFT", target, "TOPLEFT", -7, title and title.frameTop or 7)
        frame:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 7, -7)
        frame:SetBackdrop({ edgeFile = CLASSIC_EDGE.file, edgeSize = CLASSIC_EDGE.size })
        frame:SetBackdropBorderColor(1, 1, 1, 1)
    else
        return false
    end
    return true
end

-- Draws the body of style `key`'s title bar on `bar` (a plain frame, under the
-- style's frame) over `target`: the dark band and the line that closes it at the
-- map's top. Forever's bar is in its frame's art: nothing to draw, returns false.
function Mod:DrawSquareTitleBar(bar, target, key)
    bar.fill = bar.fill or bar:CreateTexture(nil, "BACKGROUND")
    if not bar.over then
        bar.over = CreateFrame("Frame", nil, bar)
        bar.over:SetAllPoints(bar)
        bar.over:EnableMouse(false)
        bar.divider = bar.over:CreateTexture(nil, "ARTWORK")
    end
    -- Retail's line joins its frame's edge over it; the others close under theirs.
    bar.over:SetFrameLevel(bar:GetFrameLevel() + (key == "retail" and 3 or 0))
    bar.edges = bar.edges or {}
    for _, name in ipairs({ "top", "left", "right" }) do
        bar.edges[name] = bar.edges[name] or bar:CreateTexture(nil, "OVERLAY")
        bar.edges[name]:Hide()
    end
    local title = TITLE[key]
    if not title or key == "forever" then
        bar:Hide()
        return false
    end
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOMLEFT", target, "TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 0, 0)
    bar:SetHeight(title.height)
    bar:Show()
    bar.fill:ClearAllPoints()
    bar.divider:ClearAllPoints()
    bar.divider:SetVertexColor(1, 1, 1, 1)

    if key == "retail" then
        -- The frame's own top edge, across the map's top.
        bar.fill:SetPoint("TOPLEFT", 0, -1)
        bar.fill:SetPoint("BOTTOMRIGHT", 0, 0)
        bar.fill:SetColorTexture(0.055, 0.055, 0.07, 0.95)
        local p = PIECES.retailFrame
        local x, y, width, c = p.rect[1], p.rect[2], p.rect[3], p.corner
        bar.divider:SetTexture(p.file)
        bar.divider:SetTexCoord((x + c) / p.w, (x + width - c) / p.w, y / p.h, (y + c) / p.h)
        bar.divider:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 4)
        bar.divider:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 4)
        bar.divider:SetHeight(10)
    elseif key == "classic" then
        -- The dialog edge's top strip. Edge files hold it standing up: the
        -- coordinates turn it, repeating along the bar. Its band is the 5 px
        -- that start 2 below the strip's top, seated on the map's top.
        bar.fill:SetPoint("TOPLEFT", 0, -3)
        bar.fill:SetPoint("BOTTOMRIGHT", 0, 2)
        bar.fill:SetColorTexture(0, 0, 0, 0.88)
        bar.divider:SetTexture(CLASSIC_EDGE.file, "REPEAT", "REPEAT")
        local tiles = math.max(1, (target:GetWidth() or 198) / CLASSIC_EDGE.size)
        bar.divider:SetTexCoord(0.25, tiles, 0.375, tiles, 0.25, 0, 0.375, 0)
        bar.divider:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 7)
        bar.divider:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 7)
        bar.divider:SetHeight(CLASSIC_EDGE.size)
    else
        -- KUI: the map's pixel border goes on around the bar, over an accent line.
        bar.fill:SetAllPoints()
        bar.fill:SetColorTexture(0.03, 0.03, 0.04, 0.9)
        local r, g, b = 1, 0.486275, 0.039216
        if KT.GetStyleAccentRGB then
            local ar, ag, ab = KT:GetStyleAccentRGB()
            if ar then r, g, b = ar, ag, ab end
        end
        bar.divider:SetColorTexture(r, g, b, 1)
        bar.divider:SetTexCoord(0, 1, 0, 1)
        bar.divider:SetPoint("BOTTOMLEFT", 0, 0)
        bar.divider:SetPoint("BOTTOMRIGHT", 0, 0)
        bar.divider:SetHeight(1)
        local color = self.db and type(self.db.borderColor) == "table" and self.db.borderColor or {}
        local scale = bar.GetEffectiveScale and bar:GetEffectiveScale() or 1
        if not scale or scale <= 0 then scale = 1 end
        local thickness = math.max(1, math.min(8, tonumber(self.db and self.db.borderSize) or 1)) / scale
        for _, edge in pairs(bar.edges) do
            edge:ClearAllPoints()
            edge:SetColorTexture(color.r or 0, color.g or 0, color.b or 0, color.a or 1)
            edge:Show()
        end
        local edges = bar.edges
        edges.top:SetPoint("TOPLEFT"); edges.top:SetPoint("TOPRIGHT"); edges.top:SetHeight(thickness)
        edges.left:SetPoint("TOPLEFT"); edges.left:SetPoint("BOTTOMLEFT"); edges.left:SetWidth(thickness)
        edges.right:SetPoint("TOPRIGHT"); edges.right:SetPoint("BOTTOMRIGHT"); edges.right:SetWidth(thickness)
    end
    return true
end

function Mod:UpdateSquareTitleBar()
    local holder = _G.KT_MinimapHolder_Main
    if not holder then return end
    local bar = holder.KT_TitleBar
    if not self:ZoneInTitleBar() then
        if bar then bar:Hide() end
        return
    end
    if not bar then
        bar = CreateFrame("Frame", nil, holder)
        bar:EnableMouse(false)
        holder.KT_TitleBar = bar
    end
    -- Under the style's frame (holder + 2) and the zone name (holder + 3).
    bar:SetFrameStrata(holder:GetFrameStrata())
    bar:SetFrameLevel(holder:GetFrameLevel() + 1)
    self:DrawSquareTitleBar(bar, holder, self:GetDecorStyleKey())
end

function Mod:UpdateSquareThemeFrame()
    local holder = _G.KT_MinimapHolder_Main
    if not holder then return end
    self:UpdateSquareTitleBar()
    local frame = holder.KT_ThemeFrame
    if not self:SquareThemeActive() then
        if frame then frame:Hide() end
        return
    end
    if not frame then
        frame = CreateFrame("Frame", nil, holder, "BackdropTemplate")
        frame:EnableMouse(false)
        holder.KT_ThemeFrame = frame
    end
    frame:SetFrameStrata(holder:GetFrameStrata())
    -- Under the zone name and the other texts (holder + 3 and up).
    frame:SetFrameLevel(holder:GetFrameLevel() + 2)
    frame:Show()
    self:DrawSquareThemeFrame(frame, holder, self:GetDecorStyleKey(), self:ZoneInTitleBar())
end

-------------------------------------------------------------------------------
--  Zone header plate
-------------------------------------------------------------------------------
local PLATE_HEIGHT = { retail = 20, forever = 22, classic = 20 }

function Mod:UpdateZoneHeaderStyle()
    local zone = _G.KT_MinimapZoneText
    local text = zone and zone.text
    if not text then return end
    local plate = zone.KT_Plate
    local db = self.db
    local function PlaceLocation(y)
        local location = _G.KT_MinimapLocation
        if not location then return end
        location:ClearAllPoints()
        location:SetPoint("TOP", zone, "BOTTOM", tonumber(db.locationOffsetX) or 0,
            y + (tonumber(db.locationOffsetY) or 0))
    end
    -- In the title bar the name never runs past the bar.
    local inTitleBar = db and self:ZoneInTitleBar()
    local holder = _G.KT_MinimapHolder_Main
    local barWidth = inTitleBar and holder and holder:GetWidth() or 0
    text:SetWidth(barWidth > 16 and barWidth - 8 or 0)
    if inTitleBar then
        if plate then plate:Hide() end
        local _, gap = self:GetTitleBarMetrics()
        PlaceLocation(-gap)
        return
    end
    -- The plate: round map, Visual Styles only (KUI keeps its bare text there).
    if not db or db.shape == "SQUARE" or self:GetDecorStyleKey() == "kui" then
        if plate then plate:Hide() end
        if db then PlaceLocation(-1) end -- back to its plain place (Mod:ApplyElementOffsets)
        return
    end
    if not plate then
        plate = CreateFrame("Frame", nil, zone, "BackdropTemplate")
        plate:EnableMouse(false)
        plate:SetFrameLevel(math.max(0, zone:GetFrameLevel() - 1))
        zone.KT_Plate = plate
    end
    plate:ClearAllPoints()
    plate:SetPoint("CENTER", zone, "CENTER", 0, 0)
    local height = self:DrawZonePlate(plate, self:GetDecorStyleKey(), text:GetStringWidth())

    -- The location line below the plate keeps clear of its taller bottom edge.
    PlaceLocation(-1 - math.max(0, (height - (zone:GetHeight() or 16)) / 2))
end

-- How far the zone name moves up: into the square map's title bar,
-- or on a round minimap of `diameter` px so that
-- it, its plate and the location line below it clear the style's ring.
local ZONE_LINE, LOCATION_LINE, LIFT_MARGIN = 16, 15, 2
-- Art units the ring's band rises above the map's top edge, measured on the art
-- 12 units off centre: Forever and Retail top out in a narrow spike, which may
-- tuck behind the location line; the band itself must stay clear.
local RING_CLEAR = { forever = 10.5, retail = 0 }
function Mod:GetZoneLift(diameter)
    if not self.db then return 0 end
    if self.db.shape == "SQUARE" then return self:ZoneInTitleBar() and (self:GetTitleBarMetrics()) or 0 end
    local lift = 0
    local key = self.GetRingStyleKey and self:GetRingStyleKey()
    for _, def in ipairs(KT.MinimapRingStyles or {}) do
        if def.key == key and def.base then
            local k = (tonumber(diameter) or def.base) / def.base
            -- Ring top above the map's top edge (the ring is centred, dy up).
            local ringTop = RING_CLEAR[key]
                or ((def.height or def.size or def.base) / 2 + (def.dy or 0) - def.base / 2)
            lift = math.max(0, ringTop * k)
        end
    end
    local style = self:GetDecorStyleKey()
    if lift == 0 and style == "kui" and key == "none" then return 0 end
    if self.db.showZone ~= false then lift = lift + LOCATION_LINE end
    if style ~= "kui" then lift = lift + math.max(0, ((PLATE_HEIGHT[style] or 18) - ZONE_LINE) / 2) end
    return math.floor(lift + LIFT_MARGIN + 0.5)
end

-- Paints the zone name plate of style `key` on `plate` (a BackdropTemplate
-- frame the caller anchors; every style but KUI), sized for a text `textWidth`
-- wide. Returns its height.
function Mod:DrawZonePlate(plate, key, textWidth)
    plate.fill = plate.fill or plate:CreateTexture(nil, "BACKGROUND")
    plate.line = plate.line or plate:CreateTexture(nil, "ARTWORK")
    plate.chevron = plate.chevron or plate:CreateTexture(nil, "OVERLAY")
    local height = PLATE_HEIGHT[key] or 18
    local width = math.max(96, math.floor((textWidth or 0) + 30))
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
    end
    return height
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

-- Calendar and Mail, beside the map's top-left corner (Tracking sits between
-- them: ApplyTrackingAnchor in Minimap.lua).
function Mod:PlaceCornerIcons()
    local holder = _G.KT_MinimapHolder_Main
    if not holder then return end
    local side = self:GetSideOutset()
    local function Place(button, y)
        if not button then return end
        button:ClearAllPoints()
        button:SetPoint("TOPRIGHT", holder, "TOPLEFT", -side, y)
    end
    Place(self.calendarButton, 0)
    Place(self.mailButton, -44)
end

-- One call after a minimap refresh or a Visual Style change.
function Mod:UpdateThemeDecor()
    if self.ApplyZoneAnchor then self:ApplyZoneAnchor() end
    self:UpdateSquareThemeFrame()
    self:PlaceCornerIcons()
    self:UpdateZoneHeaderStyle()
    self:ApplyThemedSideIcons()
end
