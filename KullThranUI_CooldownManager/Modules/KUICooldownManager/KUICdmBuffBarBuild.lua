-- Rebuilds the tracked buff bars from saved settings, owns the tick frame, and registers bars with unlock mode.
local _, ns = ...

local REBUILD_LABEL = "cdm.buff_bars.rebuild"

-- How a follower attaches to the previous link, with the sign of the gap on each axis.
local FOLLOW = {
    DOWN = { point = "TOP", relPoint = "BOTTOM", x = 0, y = -1 },
    UP = { point = "BOTTOM", relPoint = "TOP", x = 0, y = 1 },
    RIGHT = { point = "LEFT", relPoint = "RIGHT", x = 1, y = 0 },
    LEFT = { point = "RIGHT", relPoint = "LEFT", x = -1, y = 0 },
}

-- The saved direction, upper-cased. Anything can be in an imported value.
local function GrowDirection(tbb)
    return string.upper(tostring(tbb.groupGrowDirection or "DOWN"))
end

-- Key of a bar in the saved positions.
local function BarKey(cfg, index)
    return cfg.id or tostring(index)
end

-- The positions table of the current profile, or nil.
local function SavedPositions(ctx)
    local profile = ctx.GetProfile()
    return profile and profile.tbbPositions
end

-- Spell info for a saved spell id above 0, nil when there is none or no API.
local function LookUpSpell(spellID)
    if not spellID or spellID <= 0 then return nil end
    local api = C_Spell
    local getInfo = api and api.GetSpellInfo
    return getInfo and getInfo(spellID)
end

-- Sets the icon from the popular list, then from the spell. Finding nothing leaves the texture alone.
local function ApplyIcon(ctx, bar, cfg)
    local holder = bar._icon
    local texture = holder and holder._tex
    if not texture then return end

    local icon
    local popularKey = cfg.popularKey
    if popularKey then
        for _, entry in ipairs(ctx.PopularBuffs or {}) do
            if entry.key == popularKey then
                icon = entry.icon
                break
            end
        end
    end
    if not icon then
        local info = LookUpSpell(cfg.spellID)
        icon = info and info.iconID
    end
    if icon then texture:SetTexture(icon) end
end

-- Sets the name text, unless the position rule says there is no name, which keeps the old text.
local function ApplyName(bar, cfg)
    local label = bar._nameText
    if not label then return end

    local position = cfg.namePosition
    if position == nil then
        position = cfg.showName == false and "none" or "left"
    end
    if position == "none" then return end

    local text = cfg.name
    if text == nil or text == "" then
        local info = LookUpSpell(cfg.spellID)
        text = info and info.name or ""
    end
    label:SetText(text)
end

-- Saved scale, contained so that a bad value cannot stop the anchor that follows.
local function ApplyScale(frame, scale)
    if scale then pcall(frame.SetScale, frame, scale) end
end

-- Anchors a bar at its own saved position, or at the default stacked spot.
local function PlaceAlone(bar, cfg, index, positions)
    local saved = positions[BarKey(cfg, index)]
    if saved and saved.point then
        ApplyScale(bar, saved.scale)
        bar:SetPoint(saved.point, UIParent, saved.relPoint or saved.point, saved.x or 0, saved.y or 0)
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, 200 - (index - 1) * ((cfg.height or 24) + 4))
    end
end

-- Anchors a follower to the previous link. An unknown direction leaves it with no anchor.
local function PlaceFollower(bar, previous, tbb)
    local follow = FOLLOW[GrowDirection(tbb)]
    if not follow then return end
    local gap = tbb.groupSpacing or 2
    bar:SetPoint(follow.point, previous, follow.relPoint, follow.x * gap, follow.y * gap)
end

-- Makes the tick frame's script: the opacity pass each frame, then the timers every 0.2 s. The accumulator stays in
-- this closure. All maths is inline, so a frame adds no helper call and allocates nothing.
local function NewTickScript(ctx)
    local accumulated = 0

    return function(self, elapsed)
        local frames = ctx.frames
        local index = 1
        local wrap = frames[1]
        while wrap do
            local target = wrap._opacityTarget
            if target then
                local alpha = wrap:GetAlpha()
                local delta = target - alpha
                if delta > 0.005 or delta < -0.005 then
                    local rate = elapsed * 8
                    if rate > 1 then rate = 1 end
                    wrap:SetAlpha(alpha + delta * rate)
                elseif alpha ~= target then
                    wrap:SetAlpha(target)
                end
            end
            index = index + 1
            wrap = frames[index]
        end

        accumulated = accumulated + elapsed
        if accumulated < 0.2 then return end

        self._lastDt = accumulated
        accumulated = 0
        local updateTimers = ctx.UpdateTimers
        if updateTimers then updateTimers() end
    end
end

-- The work of a build out of combat.
local function RebuildBars(ctx, profile)
    local tbb = ctx.GetTrackedBuffBars()
    local bars = tbb and tbb.bars or {}

    -- Read after the bar list, since that call may migrate positions.
    local positions = profile.tbbPositions
    if not positions then
        positions = {}
        profile.tbbPositions = positions
    end

    local frames = ctx.frames
    local extra = #bars + 1
    while frames[extra] do
        frames[extra]:Hide()
        extra = extra + 1
    end

    local anyEnabled = false
    local lastLink
    for index, cfg in ipairs(bars) do
        local bar = frames[index]
        if not bar then
            bar = ctx.Frame.CreateBar(ctx, UIParent, index)
            frames[index] = bar
        end

        if cfg.enabled == false then
            bar:Hide()
        else
            anyEnabled = true
            ctx.Frame.ApplySettings(ctx, bar, cfg)
            ApplyIcon(ctx, bar, cfg)
            ApplyName(bar, cfg)

            bar:ClearAllPoints()
            local grouped = ctx.IsGrouped(cfg)
            if grouped and lastLink then
                PlaceFollower(bar, lastLink, tbb)
            else
                PlaceAlone(bar, cfg, index, positions)
            end
            if grouped then lastLink = bar end

            -- Arm for the timers, dropping what the last run left behind. The timers show the bar when needed.
            bar._tbbReady = true
            bar._isPassive = nil
            bar._resolvedAuraID = nil
            bar._blizzChild = nil
            bar._customStart = nil
            bar._activeDuration = nil
            bar._lastLiveIcon = nil
            bar._lastLiveName = nil
            bar:Hide()
        end
    end

    local state = ctx.state
    if anyEnabled then
        if not state.tickFrame then
            local tickFrame = CreateFrame("Frame")
            state.tickFrame = tickFrame
            tickFrame:SetScript("OnUpdate", NewTickScript(ctx))
        end
        local updateTimers = ctx.UpdateTimers
        if updateTimers then
            updateTimers()
        else
            ctx.RefreshTickState()
        end
    elseif state.tickFrame then
        state.tickFrame:Hide()
    end

    if ctx.RegisterUnlock then ctx.RegisterUnlock() end
    if ctx.RefreshResolvedIDs then ctx.RefreshResolvedIDs() end
    ctx.RefreshGating()
end

-- Rebuilds all bars, or marks the rebuild as pending when in combat.
local function Build(ctx)
    local profile = ctx.GetProfile()
    if not profile then return end

    local profiler = ctx.GetProfiler()
    local token = profiler and profiler:Begin(REBUILD_LABEL)

    if InCombatLockdown() then
        ctx.state.rebuildPending = true
    else
        ctx.state.rebuildPending = false
        RebuildBars(ctx, profile)
    end

    if token then profiler:End(REBUILD_LABEL, token) end
end

-- The bar at an index of the live list, or nil.
local function LiveBar(ctx, index)
    local tbb = ctx.GetTrackedBuffBars()
    local bars = tbb and tbb.bars
    return bars and bars[index]
end

-- Size of the whole group for its mover, from the live list. Returns nothing when there is no positive size.
local function GroupMoverSize(ctx)
    local tbb = ctx.GetTrackedBuffBars()
    local bars = tbb and tbb.bars
    if not bars then return end

    local count, sumWidth, sumHeight, maxWidth, maxHeight = 0, 0, 0, 0, 0
    for _, cfg in ipairs(bars) do
        if cfg.enabled ~= false and ctx.IsGrouped(cfg) then
            local thickness = cfg.height or 24
            local length = cfg.width or 200
            if (cfg.iconDisplay or "left") ~= "none" then length = length + thickness end

            local boxWidth, boxHeight = length, thickness
            if cfg.verticalOrientation then boxWidth, boxHeight = thickness, length end

            count = count + 1
            sumWidth = sumWidth + boxWidth
            sumHeight = sumHeight + boxHeight
            if boxWidth > maxWidth then maxWidth = boxWidth end
            if boxHeight > maxHeight then maxHeight = boxHeight end
        end
    end

    local gaps = (tbb.groupSpacing or 2) * (count - 1)
    local direction = GrowDirection(tbb)
    local width, height
    if direction == "DOWN" or direction == "UP" then
        width, height = maxWidth, sumHeight + gaps
    else
        width, height = sumWidth + gaps, maxHeight
    end
    if width > 0 and height > 0 then return width, height end
end

-- One unlock mode element. Grouped state, index and key are fixed here; everything else is read when called.
local function NewElement(ctx, index, cfg, grouped)
    local positionKey = BarKey(cfg, index)

    local name = cfg.name
    if name == nil then name = string.format(ctx.LText("Bar %d"), index) end
    local labelFormat = ctx.LText(grouped and "Buff Bar: %s (Group)" or "Buff Bar: %s")

    return {
        key = "TBB_" .. positionKey,
        label = string.format(labelFormat, name),
        group = "Cooldown Manager",
        order = 650,

        getFrame = function()
            return ctx.frames[index]
        end,

        getMoverSize = function()
            if not grouped then return end
            return GroupMoverSize(ctx)
        end,

        getSize = function()
            local current = LiveBar(ctx, index)
            if current then return current.width or 200, current.height or 24 end
            return 200, 24
        end,

        setEditableSize = function(_, width, height)
            local current = LiveBar(ctx, index)
            if not current then return end
            current.width, current.height = width, height
            ctx.Rebuild()
        end,

        savePosition = function(_, point, relPoint, x, y, scale)
            local profile = ctx.GetProfile()
            if profile then
                local positions = profile.tbbPositions
                if not positions then
                    positions = {}
                    profile.tbbPositions = positions
                end
                positions[positionKey] = { point = point, relPoint = relPoint, relativePoint = relPoint, x = x, y = y, scale = scale }
            end

            local frame = ctx.frames[index]
            if frame then
                ApplyScale(frame, scale)
                frame:ClearAllPoints()
                frame:SetPoint(point, UIParent, relPoint or point, x, y)
            end
            ctx.Rebuild()
        end,

        loadPosition = function()
            local positions = SavedPositions(ctx)
            local saved = positions and positions[positionKey]
            if not saved then return nil end
            if saved.relPoint and not saved.relativePoint then
                saved.relativePoint = saved.relPoint
            end
            return saved
        end,

        getScale = function()
            local positions = SavedPositions(ctx)
            local saved = positions and positions[positionKey]
            return saved and saved.scale or 1
        end,

        clearPosition = function()
            local positions = SavedPositions(ctx)
            if positions then positions[positionKey] = nil end
        end,

        applyPosition = function()
            ctx.Rebuild()
        end,
    }
end

-- Registers each ungrouped bar and the group's anchor bar with unlock mode, and
-- drops the elements of bars that were deleted or now follow the group anchor.
local function RegisterUnlock(ctx)
    local kt = ctx.KT
    if not kt or not kt.RegisterMovableElements then return end
    if not ctx.GetProfile() then return end

    local tbb = ctx.GetTrackedBuffBars()
    local bars = tbb and tbb.bars or {}

    local anchorIndex = ctx.GroupAnchorIndex()
    local elements, wanted = {}, {}
    for index, cfg in ipairs(bars) do
        local grouped = ctx.IsGrouped(cfg)
        if (not grouped or index == anchorIndex) and ctx.frames[index] then
            local element = NewElement(ctx, index, cfg, grouped)
            elements[#elements + 1] = element
            wanted[element.key] = true
        end
    end

    local registry = kt.UnlockElements
    if registry and kt.UnregisterUnlockElement then
        local stale = {}
        for key in pairs(registry) do
            if type(key) == "string" and key:find("^TBB_") and not wanted[key] then
                stale[#stale + 1] = key
            end
        end
        for _, key in ipairs(stale) do kt:UnregisterUnlockElement(key) end
    end

    if #elements > 0 then kt:RegisterMovableElements(elements) end
end

ns.CdmBuffBarBuild = { Build = Build, RegisterUnlock = RegisterUnlock }
