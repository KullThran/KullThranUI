-- Custom aura engine, groups. Auras that share a group name are placed in a row or column of equal cells from the
-- group's anchor, which the placing mode drags as one. Settings live in profile.customGroups[name]:
--   { point, relativePoint, xOffset, yOffset, direction = "RIGHT" | "LEFT" | "UP" | "DOWN", spacing, dynamic,
--     wrap, sort = "ORDER" | "REMAINING" }
-- A dynamic group closes the gaps of hidden auras. With `wrap`, a row (or column) holds that many cells and the next
-- ones start a new row below (or a new column to the right). Sorted by remaining time, the aura that ends first
-- takes the first cell; an aura whose time cannot be read follows the readable ones in its usual order. An aura
-- holding a delegated slot always keeps a cell, since the client may show it at any moment, and in combat it is never
-- moved: the other auras take the free cells around it. Shared byte for byte between the Retail and Forever workspaces.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local Group = {}
E.Group = Group

local DEFAULTS = {
    direction = "RIGHT", spacing = 4, dynamic = true, wrap = 0, sort = "ORDER",
    point = "CENTER", relativePoint = "CENTER", xOffset = 0, yOffset = 0,
}
local AXIS = { RIGHT = { 1, 0 }, LEFT = { -1, 0 }, UP = { 0, 1 }, DOWN = { 0, -1 } }
Group.DEFAULTS = DEFAULTS

local anchors = {}

-- The group's settings, the saved ones over the defaults; a wrong saved value is ignored.
function Group.Settings(profile, name)
    local settings = {}
    for k, v in pairs(DEFAULTS) do settings[k] = v end
    local saved = profile and type(profile.customGroups) == "table" and profile.customGroups[name]
    if type(saved) ~= "table" then return settings end
    if AXIS[saved.direction] then settings.direction = saved.direction end
    if type(saved.spacing) == "number" and saved.spacing >= 0 then settings.spacing = saved.spacing end
    if type(saved.dynamic) == "boolean" then settings.dynamic = saved.dynamic end
    if type(saved.wrap) == "number" and saved.wrap >= 0 then settings.wrap = math.min(math.floor(saved.wrap), 40) end
    if saved.sort == "ORDER" or saved.sort == "REMAINING" then settings.sort = saved.sort end
    if type(saved.point) == "string" then settings.point = saved.point end
    if type(saved.relativePoint) == "string" then settings.relativePoint = saved.relativePoint end
    if type(saved.xOffset) == "number" then settings.xOffset = saved.xOffset end
    if type(saved.yOffset) == "number" then settings.yOffset = saved.yOffset end
    return settings
end

function Group.FrameOf(name, create)
    local g = anchors[name]
    if not g and create then
        g = CreateFrame("Frame", nil, UIParent)
        g:SetSize(40, 40)
        g:SetMovable(true)
        g:SetClampedToScreen(true)
        g.groupName = name
        anchors[name] = g
    end
    return g
end

-- Drops a frame's group placement: it no longer belongs to one.
function Group.Release(f)
    f.groupFrame, f.groupName, f.groupCell, f.groupKey = nil, nil, nil, nil
end

local function Extent(region, horizontal)
    local size = region.size or 40
    if horizontal and region.kind == "bar" then
        local width = (region.bar and region.bar.width) or E.BAR_WIDTH or 180
        return math.max(width, size + 20)
    end
    return size
end

local function Before(a, b)
    local ra, rb = a.record.region, b.record.region
    if ra.groupOrder ~= rb.groupOrder then return (ra.groupOrder or 0) < (rb.groupOrder or 0) end
    local na, nb = tostring(a.record.name or ""), tostring(b.record.name or "")
    if na ~= nb then return na < nb end
    return tostring(a.uid) < tostring(b.uid)
end

-- Where a cell goes from the anchor: along the direction, and with `wrap` row after row (or column after column).
function Group.Offset(cell, step, crossStep, axis, wrap)
    local along, line = cell, 0
    if wrap and wrap > 0 then
        along, line = cell % wrap, math.floor(cell / wrap)
    end
    -- Rows grow downwards, columns to the right.
    local cross = axis[1] ~= 0 and { 0, -1 } or { 1, 0 }
    return along * step * axis[1] + line * crossStep * cross[1], along * step * axis[2] + line * crossStep * cross[2]
end

local function Place(f, g, name, cell, x, y)
    f.groupFrame, f.groupName, f.groupCell = g, name, cell
    local key = table.concat({ tostring(g), cell, x, y }, "|")
    if f.groupKey == key then return end
    f.groupKey = key
    f:ClearAllPoints()
    f:SetPoint("CENTER", g, "CENTER", x, y)
end

-- The readable remaining time of a shown aura, nil otherwise.
local function RemainingOf(f)
    if not (f.IsShown and f:IsShown()) then return nil end
    local expiration = f.expirationTime
    if type(expiration) == "number" and expiration > 0 and type(GetTime) == "function" then
        return expiration - GetTime()
    end
    return nil
end

-- By remaining time, then the usual order.
local function SortByRemaining(list)
    local order = {}
    for i, m in ipairs(list) do order[m] = i end
    table.sort(list, function(a, b)
        local ra, rb = RemainingOf(a.f), RemainingOf(b.f)
        if ra and rb and ra ~= rb then return ra < rb end
        if ra and not rb then return true end
        if rb and not ra then return false end
        return order[a] < order[b]
    end)
end

local function Holds(f)
    return f.delegate ~= nil and f.delegate.container ~= nil
end

-- Places every grouped aura of this pass. `members` lists { uid, f, record } of auras whose record has a group.
function Group.Layout(profile, members, inCombat)
    local byName = {}
    for _, m in ipairs(members) do
        local name = m.record.region.group
        local list = byName[name]
        if not list then
            list = {}
            byName[name] = list
        end
        list[#list + 1] = m
    end

    for name, list in pairs(byName) do
        table.sort(list, Before)
        local settings = Group.Settings(profile, name)
        local g = Group.FrameOf(name, true)
        local axis = AXIS[settings.direction]
        local horizontal = axis[1] ~= 0

        -- The anchor moves only out of combat, and never under a drag (the placing mode's, or one pending in KUI's
        -- unlock mode).
        local anchorKey = table.concat({ settings.point, settings.relativePoint, settings.xOffset, settings.yOffset }, "|")
        if g.anchorKey ~= anchorKey and not g.dragging and not g.moverPoint and not inCombat then
            g:ClearAllPoints()
            g:SetPoint(settings.point, UIParent, settings.relativePoint, settings.xOffset, settings.yOffset)
            g.anchorKey = anchorKey
        end

        if settings.sort == "REMAINING" then SortByRemaining(list) end

        local cellSize, crossSize = 0, 0
        for _, m in ipairs(list) do
            cellSize = math.max(cellSize, Extent(m.record.region, horizontal))
            crossSize = math.max(crossSize, Extent(m.record.region, not horizontal))
        end
        local step = cellSize + settings.spacing
        local crossStep = crossSize + settings.spacing

        -- Cells held in combat by auras with a slot.
        local taken = {}
        local pinned = {}
        if inCombat then
            for _, m in ipairs(list) do
                if Holds(m.f) and m.f.groupCell ~= nil and m.f.groupName == name then
                    taken[m.f.groupCell] = true
                    pinned[m] = true
                end
            end
        end

        local index = -1
        for _, m in ipairs(list) do
            index = index + 1
            local f = m.f
            if pinned[m] then
                f.groupFrame = g
            elseif settings.dynamic and not (f:IsShown() or Holds(f)) then
                -- Hidden and gives up its cell; placed again when it shows.
                f.groupFrame, f.groupName, f.groupCell = g, name, nil
            else
                local cell = index
                if settings.dynamic then
                    cell = 0
                    while taken[cell] do cell = cell + 1 end
                end
                taken[cell] = true
                local x, y = Group.Offset(cell, step, crossStep, axis, settings.wrap)
                Place(f, g, name, cell, x, y)
            end
        end
    end
end
