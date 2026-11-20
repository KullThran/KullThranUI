-- Threshold marks of a tracked buff bar: the secret-safe threshold overlay and the white tick lines.
local _, ns = ...

local WHITE8 = "Interface\\Buttons\\WHITE8x8"

local Marks = {}
ns.CdmBuffBarMarks = Marks

-- Turns "1, 2.5,0x10" into a sorted list of unique numbers above zero, or nil when none survive.
local function ParseTickList(text)
    if type(text) ~= "string" or text == "" then return nil end

    local values, seen, count = {}, {}, 0
    for segment in string.gmatch(text, "[^,]+") do
        local number = tonumber(string.match(segment, "^%s*(.-)%s*$"))
        if number and number > 0 and not seen[number] then
            seen[number] = true
            count = count + 1
            values[count] = number
        end
    end
    if count == 0 then return nil end

    table.sort(values)
    return values
end
Marks.ParseTickList = ParseTickList

-- A hidden white line. Each tick stays hidden until the walk below places it.
local function NewTick(host)
    local tick = host:CreateTexture(nil, "OVERLAY", nil, 7)
    tick:SetColorTexture(1, 1, 1, 1)
    tick:SetSnapToPixelGrid(false)
    tick:SetTexelSnappingBias(0)
    tick:Hide()
    return tick
end

-- Hides every cached tick, then places one per tick value up to the max stack count.
function Marks.UpdateTickMarks(ctx, sb, cfg, tickCache, isVert, tickParent)
    local maxStacks = cfg.stackThresholdMax or 10

    local cached = tickCache and #tickCache or 0
    for i = 1, cached do
        tickCache[i]:Hide()
    end

    if not cfg.stackThresholdEnabled or not cfg.stackThresholdMaxEnabled or not tickCache or maxStacks < 1 then return end
    local values = ParseTickList(cfg.stackThresholdTicks)
    if not values then return end

    -- Values above max get a texture too: growth comes before the walk stops.
    local host = tickParent or sb
    for i = cached + 1, #values do
        tickCache[i] = NewTick(host)
    end

    local pp = ctx.PP
    local thickness = 1
    if pp then thickness = pp.Scale(1) end
    local width, height = sb:GetWidth(), sb:GetHeight()

    for i = 1, #values do
        local value = values[i]
        if value > maxStacks then break end

        local tick = tickCache[i]
        local offset = (isVert and height or width) * (value / maxStacks)
        if pp then offset = pp.Scale(offset) end

        tick:ClearAllPoints()
        if isVert then
            tick:SetSize(width, thickness)
            tick:SetPoint("BOTTOMLEFT", sb, "BOTTOMLEFT", 0, offset)
        else
            tick:SetSize(thickness, height)
            tick:SetPoint("TOPLEFT", sb, "TOPLEFT", offset, 0)
        end
        tick:Show()
    end
end

-- The saved texture key through the map, White8 when that gives no usable path.
local function OverlayTexture(map, key)
    local path = map and map[key or "none"]
    if type(path) == "string" and path ~= "" then return path end
    return WHITE8
end

-- Sets up the overlay from settings. Its range makes the client decide "count reached threshold": empty at or
-- below threshold - 1, full at or above threshold.
function Marks.RefreshThresholdOverlay(ctx, bar, cfg)
    local overlay = bar._threshOverlay
    if not cfg.stackThresholdEnabled then
        if overlay then overlay:Hide() end
        return
    end

    local statusBar = bar._bar
    if not overlay then
        if not statusBar then return end
        overlay = CreateFrame("StatusBar", nil, statusBar)
        overlay:SetFrameLevel(statusBar:GetFrameLevel() + 2)
        bar._threshOverlay = overlay
    end

    overlay:SetStatusBarTexture(OverlayTexture(ctx.Textures, cfg.texture))
    overlay:SetOrientation(cfg.verticalOrientation and "VERTICAL" or "HORIZONTAL")
    overlay:GetStatusBarTexture():SetVertexColor(
        cfg.stackThresholdR or 0.8,
        cfg.stackThresholdG or 0.1,
        cfg.stackThresholdB or 0.1,
        cfg.stackThresholdA or 1)

    -- Following the main fill clips the overlay to the filled part of the bar.
    overlay:ClearAllPoints()
    overlay:SetAllPoints(statusBar:GetStatusBarTexture())

    local threshold = cfg.stackThreshold or 5
    overlay:SetMinMaxValues(threshold - 1, threshold)
    overlay:SetValue(0)
    overlay:Show()
end

-- Feeds the possibly secret count to the shown overlay as it is. The fallback is its only test.
function Marks.UpdateThresholdValue(bar)
    local overlay = bar._threshOverlay
    if overlay and overlay:IsShown() then
        overlay:SetValue(bar._stackCount or 0)
    end
end
