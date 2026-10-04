local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
KT.VisualThemes = KT.VisualThemes or {}

--[[
    ThemeBorderKit.lua

    Shared rendering helper for the "classic" theme's 9-slice-style border.
    This is a rendering TOOL only -- it has no opinion about which theme uses
    it and does not read or write any saved-variable profile. Any module's own
    render path can call it once its own "border style" option gains a real
    value that points at this kit.

    The border is drawn from a single real, unmodified Blizzard-shipped sheet,
    Interface\CastingBar\UI-CastingBar-Border (256x64px), sliced into 8 pieces
    (4 corners + 4 edges). There is no center piece: callers already own their
    own bar/background fill and this kit only frames it.

    Texture-coordinate derivation (PROVISIONAL -- see note below):
    This environment has no running WoW client, so the crop below could not be
    confirmed by eye. The rectangles were chosen by reasoning about the sheet's
    own 256x64 proportions only (never by reusing another addon's previously
    reverse-engineered pixel values for this file):
      - The sheet is split into a 3x3 grid and the 4 corner cells are used
        as-is; the 4 edge-cells are used as the thin strips between corners;
        the center cell is unused (callers supply their own fill).
      - Corners are assumed to occupy 32px of the 256px width (12.5%, one
        eighth) and 16px of the 64px height (25%, one quarter) each. This
        follows the general shape of a horizontal cast-bar-style frame sheet,
        where the frame is much wider than it is tall and corners read as
        small square-ish caps relative to the whole strip -- but the exact
        pixel cut is a guess, not a measurement.
      - Top/bottom edge strips reuse the corners' 16px height band and span
        the remaining 192px (256 - 2*32) of width between the corners.
      - Left/right edge strips reuse the corners' 32px width band and span
        the remaining 32px (64 - 2*16) of height between the corners.
    OUTSTANDING MANUAL QA ITEM: these coordinates are unverified. They must be
    checked in-game (create a border on a throwaway frame, look at it, adjust
    SHEET_CORNER_* below if any piece looks stretched, cut off, or shows the
    wrong part of the sheet) before this is considered visually correct.
]]

local BORDER_TEXTURE = [[Interface\CastingBar\UI-CastingBar-Border]]

-- Source sheet dimensions, in pixels.
local SHEET_WIDTH = 256
local SHEET_HEIGHT = 64

-- Provisional corner crop, in source-sheet pixels. See derivation note above.
local SHEET_CORNER_W = 32
local SHEET_CORNER_H = 16

-- Piece index layout. Stored as border[1..8] on the returned table (plus the
-- non-numeric border.parent field), so ipairs() over the pieces still works
-- for callers that just want to iterate all 8 textures.
local TOPLEFT, TOPRIGHT, BOTTOMLEFT, BOTTOMRIGHT = 1, 2, 3, 4
local TOP, BOTTOM, LEFT, RIGHT = 5, 6, 7, 8
local NUM_PIECES = 8

-- Texture-coordinate rectangles per piece: { left, right, top, bottom }, each
-- a 0..1 fraction of the sheet. Derived from SHEET_CORNER_W/H above.
local function BuildTexCoords()
    local cornerU = SHEET_CORNER_W / SHEET_WIDTH
    local cornerV = SHEET_CORNER_H / SHEET_HEIGHT

    local coords = {}
    coords[TOPLEFT] = { 0, cornerU, 0, cornerV }
    coords[TOPRIGHT] = { 1 - cornerU, 1, 0, cornerV }
    coords[BOTTOMLEFT] = { 0, cornerU, 1 - cornerV, 1 }
    coords[BOTTOMRIGHT] = { 1 - cornerU, 1, 1 - cornerV, 1 }
    coords[TOP] = { cornerU, 1 - cornerU, 0, cornerV }
    coords[BOTTOM] = { cornerU, 1 - cornerU, 1 - cornerV, 1 }
    coords[LEFT] = { 0, cornerU, cornerV, 1 - cornerV }
    coords[RIGHT] = { 1 - cornerU, 1, cornerV, 1 - cornerV }
    return coords
end

local PIECE_TEXCOORDS = BuildTexCoords()

-- On-screen size of each corner square (and, matching it, the thickness of
-- each edge strip) at scale = 1, in UI pixels. This is a display choice,
-- independent of the source crop size above -- WoW stretches whatever pixel
-- rectangle SetTexCoord selects to fill whatever quad SetSize/SetPoint gives
-- it. Kept modest so the frame reads as a thin metal border rather than a
-- thick picture frame; also PROVISIONAL pending the same in-game check.
local BASE_RING_SIZE = 16

--- Creates the 8 border texture pieces on `parent`. Callers are responsible
--- for caching the returned table themselves and not calling this twice for
--- the same parent (this function does not guard against double-creation).
--- @param parent Frame|Region a frame that can own textures (CreateTexture)
--- @param layer string|nil WoW draw layer (default "OVERLAY")
--- @param sublevel number|nil draw sublevel within that layer (default 0)
--- @return table|nil border border[1..8] textures plus border.parent
function KT.VisualThemes:CreateClassicBorder(parent, layer, sublevel)
    if type(parent) ~= "table" or type(parent.CreateTexture) ~= "function" then
        return nil
    end

    layer = layer or "OVERLAY"
    sublevel = tonumber(sublevel) or 0

    local border = { parent = parent }
    for index = 1, NUM_PIECES do
        local piece = parent:CreateTexture(nil, layer, nil, sublevel)
        piece:SetTexture(BORDER_TEXTURE)
        local coord = PIECE_TEXCOORDS[index]
        piece:SetTexCoord(coord[1], coord[2], coord[3], coord[4])
        piece:Hide()
        border[index] = piece
    end

    return border
end

--- Positions the 8 pieces so they frame `rect` (sitting just outside its
--- edges, like a picture frame, so the pieces never overlap the caller's own
--- bar fill drawn on `rect` itself). Idempotent: memoized on rect/scale/size
--- so redundant SetPoint calls are skipped when a caller invokes this every
--- refresh tick with nothing actually changed (same spirit as Minimap.lua's
--- UpdatePixelPerfectBorder, adapted to this simpler hollow-ring case -- no
--- horizontal/vertical orientation switch, since every bar in this addon is
--- always horizontal).
--- @param border table a table returned by CreateClassicBorder
--- @param rect Frame|Region the region to surround
--- @param scale number|nil uniform scale multiplier for ring thickness (default 1)
function KT.VisualThemes:SeatClassicBorder(border, rect, scale)
    if type(border) ~= "table" or type(rect) ~= "table" then return end
    if type(rect.GetWidth) ~= "function" or type(rect.GetHeight) ~= "function" then return end

    scale = tonumber(scale) or 1
    if scale <= 0 then scale = 1 end

    local width = rect:GetWidth() or 0
    local height = rect:GetHeight() or 0

    if border._ktSeatRect == rect and border._ktSeatScale == scale
        and border._ktSeatWidth == width and border._ktSeatHeight == height then
        return
    end

    local ringSize = BASE_RING_SIZE * scale

    local topLeft = border[TOPLEFT]
    local topRight = border[TOPRIGHT]
    local bottomLeft = border[BOTTOMLEFT]
    local bottomRight = border[BOTTOMRIGHT]
    local top = border[TOP]
    local bottom = border[BOTTOM]
    local left = border[LEFT]
    local right = border[RIGHT]

    if not (topLeft and topRight and bottomLeft and bottomRight and top and bottom and left and right) then
        return
    end

    topLeft:ClearAllPoints()
    topLeft:SetSize(ringSize, ringSize)
    topLeft:SetPoint("BOTTOMRIGHT", rect, "TOPLEFT", 0, 0)

    topRight:ClearAllPoints()
    topRight:SetSize(ringSize, ringSize)
    topRight:SetPoint("BOTTOMLEFT", rect, "TOPRIGHT", 0, 0)

    bottomLeft:ClearAllPoints()
    bottomLeft:SetSize(ringSize, ringSize)
    bottomLeft:SetPoint("TOPRIGHT", rect, "BOTTOMLEFT", 0, 0)

    bottomRight:ClearAllPoints()
    bottomRight:SetSize(ringSize, ringSize)
    bottomRight:SetPoint("TOPLEFT", rect, "BOTTOMRIGHT", 0, 0)

    -- Edge pieces span the FULL length of their side, right up to the rect's
    -- corner points -- not inset by ringSize -- so they abut the corner
    -- pieces exactly with no gap and no overlap. (The corner pieces above are
    -- already sized ringSize x ringSize and anchored flush with these same
    -- corner points, extending outward from them; anchoring the edges to the
    -- unshifted corner points, rather than inset by ringSize, is what closes
    -- the gap a previous version of this function left at all 4 corners.)
    top:ClearAllPoints()
    top:SetHeight(ringSize)
    top:SetPoint("BOTTOMLEFT", rect, "TOPLEFT", 0, 0)
    top:SetPoint("BOTTOMRIGHT", rect, "TOPRIGHT", 0, 0)

    bottom:ClearAllPoints()
    bottom:SetHeight(ringSize)
    bottom:SetPoint("TOPLEFT", rect, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("TOPRIGHT", rect, "BOTTOMRIGHT", 0, 0)

    left:ClearAllPoints()
    left:SetWidth(ringSize)
    left:SetPoint("TOPRIGHT", rect, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMRIGHT", rect, "BOTTOMLEFT", 0, 0)

    right:ClearAllPoints()
    right:SetWidth(ringSize)
    right:SetPoint("TOPLEFT", rect, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMLEFT", rect, "BOTTOMRIGHT", 0, 0)

    border._ktSeatRect = rect
    border._ktSeatScale = scale
    border._ktSeatWidth = width
    border._ktSeatHeight = height
end

--- Shows or hides all 8 pieces as one unit.
--- @param border table a table returned by CreateClassicBorder
--- @param shown boolean
function KT.VisualThemes:ShowClassicBorder(border, shown)
    if type(border) ~= "table" then return end
    for index = 1, NUM_PIECES do
        local piece = border[index]
        if piece then
            if shown then
                piece:Show()
            else
                piece:Hide()
            end
        end
    end
end
