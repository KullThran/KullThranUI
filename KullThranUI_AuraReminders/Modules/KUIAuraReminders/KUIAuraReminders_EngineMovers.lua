-- Custom aura engine, KUI unlock mode: one movable element per aura outside a group and one per group, registered
-- with KT:RegisterMovableElements and kept in step with the saved auras on every pass. A drag is saved as the centre
-- point of the aura (its point, relativePoint, xOffset, yOffset) or of the group's first cell (the group's settings),
-- the same fields the editor and the placing mode use. Shared byte for byte between the Retail and Forever workspaces.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local Movers = {}
E.Movers = Movers

Movers.SIDEBAR_GROUP = "Aura Reminders"
Movers.AURA_PREFIX = "KUIAR_Custom_"
Movers.GROUP_PREFIX = "KUIAR_CustomGroup_"
Movers.ORDER = 610

-- Size -----------------------------------------------------------------------------------------------------------------

-- The aura's frame size, as Icon.ApplyLayout sets it.
function Movers.AuraSize(region)
    region = region or {}
    local size = region.size or 40
    if region.kind == "bar" then
        local width = (region.bar and region.bar.width) or E.BAR_WIDTH or 180
        return math.max(width, size + 20), size
    end
    return size, size
end

-- The box around a group's cells (E.Group.Layout) and where its anchor, the first cell's centre, sits in it: width,
-- height, and the anchor's distance from the box's left and top edges.
function Movers.GroupBox(settings, regions)
    local direction = settings.direction or "RIGHT"
    local spacing = settings.spacing or 4
    local horizontal = direction == "RIGHT" or direction == "LEFT"
    local cell, across = 0, 0
    for _, region in ipairs(regions or {}) do
        local w, h = Movers.AuraSize(region)
        if horizontal then
            cell, across = math.max(cell, w), math.max(across, h)
        else
            cell, across = math.max(cell, h), math.max(across, w)
        end
    end
    if cell == 0 then cell, across = 40, 40 end
    local count = math.max(#(regions or {}), 1)
    -- With a wrap, the cells of one line and the lines that hold them all; lines grow down or to the right.
    local wrap = settings.wrap or 0
    local perLine, lines = count, 1
    if wrap > 0 and count > wrap then perLine, lines = wrap, math.ceil(count / wrap) end
    local length = perLine * cell + (perLine - 1) * spacing
    local depth = lines * across + (lines - 1) * spacing
    if horizontal then
        local ax = direction == "RIGHT" and cell / 2 or length - cell / 2
        return length, depth, ax, across / 2
    end
    local ay = direction == "DOWN" and cell / 2 or length - cell / 2
    return depth, length, across / 2, ay
end

local function Round(value)
    return math.floor(value * 10 + 0.5) / 10
end

local function UISize()
    local parent = UIParent
    local w = parent and parent.GetWidth and parent:GetWidth() or 0
    local h = parent and parent.GetHeight and parent:GetHeight() or 0
    return w, h
end

-- The unlock mode hands a mover's top left as TOPLEFT offsets from the UI's top left. The aura or group keeps a centre
-- point: the point at (ax, ay) inside the box, as an offset from the UI's centre.
function Movers.ToCenter(pos, ax, ay)
    local uiW, uiH = UISize()
    local left, top = pos.x or 0, (pos.y or 0) + uiH
    return {
        point = "CENTER", relativePoint = "CENTER",
        x = Round(left + ax - uiW / 2), y = Round(top - ay - uiH / 2),
        scale = pos.scale,
    }
end

-- Elements ---------------------------------------------------------------------------------------------------------

-- ctx: { profile(), auraFrame(uid), groupFrame(name), changed(), label(text) }.

local function AuraConf(ctx, uid)
    local profile = ctx.profile()
    return profile and type(profile.customAuras) == "table" and profile.customAuras[uid] or nil
end

local function AuraRegion(ctx, uid)
    local record = E.Migrate(AuraConf(ctx, uid))
    return record and record.region or {}
end

local function GroupSettings(ctx, name, create)
    local profile = ctx.profile()
    if not profile then return nil end
    if type(profile.customGroups) ~= "table" then
        if not create then return nil end
        profile.customGroups = {}
    end
    local settings = profile.customGroups[name]
    if type(settings) ~= "table" and create then
        settings = {}
        profile.customGroups[name] = settings
    end
    return type(settings) == "table" and settings or nil
end

local function GroupRegions(ctx, name)
    local list = {}
    local profile = ctx.profile()
    for _, conf in pairs(profile and profile.customAuras or {}) do
        local record = E.Migrate(conf)
        if record and record.region.group == name then list[#list + 1] = record.region end
    end
    return list
end

local function GroupBoxOf(ctx, name)
    local settings = E.Group and E.Group.Settings(ctx.profile(), name) or {}
    return Movers.GroupBox(settings, GroupRegions(ctx, name))
end

-- A pending drag is drawn on the frame and kept there until it is saved or the unlock mode closes (moverPoint).
local function Pend(frame, pos)
    if not frame then return end
    frame.moverPoint = pos
    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or pos.point or "CENTER", pos.x or 0, pos.y or 0)
end

local function AuraElement(ctx, uid, label)
    local key = Movers.AURA_PREFIX .. uid
    local function Save(point, relativePoint, x, y)
        local conf = AuraConf(ctx, uid)
        if not conf then return end
        conf.point, conf.relativePoint, conf.xOffset, conf.yOffset = point, relativePoint, x, y
        local frame = ctx.auraFrame(uid)
        if frame then frame.moverPoint = nil end
        ctx.changed()
    end
    return {
        key = key, label = label, group = Movers.SIDEBAR_GROUP, order = Movers.ORDER,
        noScale = true, noResize = true,
        getFrame = function() return ctx.auraFrame(uid) end,
        getSize = function() return Movers.AuraSize(AuraRegion(ctx, uid)) end,
        isHidden = function()
            local conf = AuraConf(ctx, uid)
            return not (conf and conf.enabled)
        end,
        translateMoverPosition = function(_, pos)
            local w, h = Movers.AuraSize(AuraRegion(ctx, uid))
            return Movers.ToCenter(pos, w / 2, h / 2)
        end,
        applyPendingPosition = function(_, pos) Pend(ctx.auraFrame(uid), pos) end,
        loadPosition = function()
            local conf = AuraConf(ctx, uid) or {}
            return {
                point = conf.point or "CENTER", relativePoint = conf.relativePoint or conf.point or "CENTER",
                x = conf.xOffset or 0, y = conf.yOffset or 0,
            }
        end,
        savePosition = function(_, point, relativePoint, x, y) Save(point, relativePoint, x, y) end,
        resetPosition = function()
            Save("CENTER", "CENTER", 0, 0)
            return true
        end,
        clearPosition = function() Save("CENTER", "CENTER", 0, 0) end,
        applyPosition = function() ctx.changed() end,
    }
end

local function GroupElement(ctx, name, label)
    local key = Movers.GROUP_PREFIX .. name
    local function Save(point, relativePoint, x, y)
        local settings = GroupSettings(ctx, name, true)
        if not settings then return end
        settings.point, settings.relativePoint, settings.xOffset, settings.yOffset = point, relativePoint, x, y
        local g = ctx.groupFrame(name)
        if g then g.moverPoint, g.anchorKey = nil, nil end
        ctx.changed()
    end
    return {
        key = key, label = label, group = Movers.SIDEBAR_GROUP, order = Movers.ORDER + 1,
        noScale = true, noResize = true,
        getFrame = function() return ctx.groupFrame(name) end,
        getSize = function()
            local w, h = GroupBoxOf(ctx, name)
            return w, h
        end,
        -- The whole row of cells, from the anchor's centre.
        getRect = function()
            local w, h, ax, ay = GroupBoxOf(ctx, name)
            local g = ctx.groupFrame(name)
            local cx, cy
            if g and g.GetCenter then cx, cy = g:GetCenter() end
            if not (cx and cy) then
                local settings = E.Group and E.Group.Settings(ctx.profile(), name) or {}
                local uiW, uiH = UISize()
                cx, cy = uiW / 2 + (settings.xOffset or 0), uiH / 2 + (settings.yOffset or 0)
            end
            return cx - ax, cy + ay, w, h
        end,
        translateMoverPosition = function(_, pos)
            local _, _, ax, ay = GroupBoxOf(ctx, name)
            return Movers.ToCenter(pos, ax, ay)
        end,
        applyPendingPosition = function(_, pos) Pend(ctx.groupFrame(name), pos) end,
        loadPosition = function()
            local settings = E.Group and E.Group.Settings(ctx.profile(), name) or {}
            return {
                point = settings.point or "CENTER", relativePoint = settings.relativePoint or "CENTER",
                x = settings.xOffset or 0, y = settings.yOffset or 0,
            }
        end,
        savePosition = function(_, point, relativePoint, x, y) Save(point, relativePoint, x, y) end,
        resetPosition = function()
            Save("CENTER", "CENTER", 0, 0)
            return true
        end,
        clearPosition = function() Save("CENTER", "CENTER", 0, 0) end,
        applyPosition = function() ctx.changed() end,
    }
end

-- Registry -----------------------------------------------------------------------------------------------------------

local registered = {}   -- key -> the label it was registered with

-- Registers what is new or renamed and removes what is gone. `entries` lists { uid, record } of this pass.
function Movers.Sync(kt, ctx, entries)
    if not (kt and type(kt.RegisterMovableElements) == "function" and type(kt.UnlockElements) == "table") then return end
    local wanted, groups = {}, {}
    for _, entry in ipairs(entries) do
        local record = entry.record
        local group = record and record.region and record.region.group
        local anchored = record and E.Icon and E.Icon.AnchorOf and E.Icon.AnchorOf(record.region) ~= nil
        if group then
            groups[group] = (groups[group] or 0) + 1
        elseif record and not anchored then
            wanted[Movers.AURA_PREFIX .. entry.uid] = { uid = entry.uid, label = record.name or ctx.label("Custom Aura") }
        end
    end
    for name, count in pairs(groups) do
        wanted[Movers.GROUP_PREFIX .. name] = { group = name, label = string.format(ctx.label("Group: %s (%d)"), name, count) }
    end

    local add = {}
    for key, item in pairs(wanted) do
        if registered[key] ~= item.label or kt.UnlockElements[key] == nil then
            registered[key] = item.label
            if item.group then
                add[#add + 1] = GroupElement(ctx, item.group, item.label)
            else
                add[#add + 1] = AuraElement(ctx, item.uid, item.label)
            end
        end
    end
    local removed = false
    for key in pairs(registered) do
        if not wanted[key] then
            registered[key] = nil
            kt.UnlockElements[key] = nil
            removed = true
        end
    end
    if #add > 0 then kt:RegisterMovableElements(add) end
    if removed then
        local um = Movers.UnlockModule(kt)
        if um and um.UpdateRegistry then pcall(um.UpdateRegistry, um) end
    end
end

function Movers.UnlockModule(kt)
    if not (kt and type(kt.GetModule) == "function") then return nil end
    local ok, um = pcall(kt.GetModule, kt, "UnlockMode", true)
    if ok then return um end
    return nil
end
