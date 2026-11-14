-- Friendly bar lifecycle and target/hover tracking for the Nameplates runtime.
-- The four unit functions are only ever reached through ctx: there they are the main file's secret guards.

local _, ns = ...

local M = {}
ns.NameplatesFriendlyBars = M

local ctx               -- the main file's interface
local isRetail          -- true for "retail", false for "forever"
local bars              -- unit token to bar, owned by the main file
local records           -- unit token to parked Blizzard frame record, owned by the main file
local pool              -- the main file's frame pool
local watcher           -- the one event frame
local enabled = false   -- the switch; listening always follows it
local targetBar         -- the bar last told it shows the target
local hoverBar          -- the bar whose highlight is shown

-- Moves the switch and the watcher's listening together. The same state again does nothing.
local function SetEnabled(on)
    on = not not on
    if on == enabled then return end
    enabled = on
    if on then
        watcher:RegisterEvent("PLAYER_TARGET_CHANGED")
        watcher:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
        watcher:RegisterEvent("RAID_TARGET_UPDATE")
    else
        watcher:UnregisterAllEvents()
    end
end

-- The bar on an event token, or nil. The exists guard comes first, so no nameplate is asked for an absent unit.
local function BarOnToken(token)
    if not ctx.UnitExists(token) then return nil end
    local nameplate = C_NamePlate.GetNamePlateForUnit(token)
    if not nameplate then return nil end
    return ns.friendlyPlatesByNameplate[nameplate]
end

local function OnEvent(_, event)
    if event == "PLAYER_TARGET_CHANGED" then
        local newBar = BarOnToken("target")
        local oldBar = targetBar
        if oldBar and oldBar ~= newBar then oldBar:ApplyTarget() end
        if newBar then newBar:ApplyTarget() end
        targetBar = newBar
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        -- The old highlight goes before the lookup, so the same bar hides and shows again.
        if hoverBar then
            hoverBar.highlight:Hide()
            hoverBar = nil
        end
        local newBar = BarOnToken("mouseover")
        if newBar then
            newBar.highlight:Show()
            hoverBar = newBar
        end
    elseif event == "RAID_TARGET_UPDATE" then
        for _, bar in pairs(bars) do
            bar:UpdateRaidIcon()
        end
    end
end

local function TryAddFriendlyPlate(unit)
    if not enabled then
        if not ctx.IsFriendlyEnabled() then return end
        SetEnabled(true)
    end

    if ctx.UnitCanAttack("player", unit) then return end
    if ctx.UnitIsUnit(unit, "player") then return end

    if isRetail then
        if not ctx.IsFriendlyBarForUnit(unit) then return end
    else
        if ctx.IsFriendlyUnitNameOnly(unit) then return end
        if not ctx.UnitIsPlayer(unit) and not ctx.IsFriendlyNPCEnabled() then return end
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate or bars[unit] then return end

    local bar = pool:Acquire()
    if not bar._mixedIn then
        Mixin(bar, ctx.FriendlyFrame)
        bar._mixedIn = true
    end

    -- Both tables hold the bar before its bind runs.
    bars[unit] = bar
    ns.friendlyPlatesByNameplate[nameplate] = bar
    bar:SetUnit(unit, nameplate)
end

-- Normal release: the bar's own clear restores Blizzard's frame, and the bars table holds the bar until the end.
local function RemoveFriendlyPlate(unit)
    local bar = bars[unit]
    if not bar then return end

    if hoverBar == bar then hoverBar = nil end
    if targetBar == bar then targetBar = nil end
    local nameplate = bar.nameplate
    if nameplate then ns.friendlyPlatesByNameplate[nameplate] = nil end

    bar:ClearUnit()
    pool:Release(bar)
    bars[unit] = nil
end

-- Promotion to an enemy plate: Blizzard's frame stays parked and untouched. Everything that can find the bar is
-- unlinked before the bar itself is touched.
local function RemoveFriendlyPlateNoRestore(unit)
    local bar = bars[unit]
    if not bar then return end

    bars[unit] = nil
    records[unit] = nil
    local nameplate = bar.nameplate
    if nameplate then ns.friendlyPlatesByNameplate[nameplate] = nil end
    if hoverBar == bar then hoverBar = nil end
    if targetBar == bar then targetBar = nil end

    bar:UnregisterAllEvents()
    bar:Hide()
    bar.unit = nil
    bar.nameplate = nil

    if isRetail then
        bar.name:SetText("")
        ctx.BlankBarLine(bar.description)
    else
        ctx.ClearFriendlyText(bar.name, 11)
        ctx.ClearFriendlyText(bar.description, 11)
    end

    ctx.HideBarIndicators(bar)
    bar:ClearAllPoints()
    bar:SetParent(UIParent)
    pool:Release(bar)
end

local function ClearAll()
    for unit, bar in pairs(bars) do
        bar:ClearUnit()
        pool:Release(bar)
        bars[unit] = nil
    end
    wipe(ns.friendlyPlatesByNameplate)
    targetBar = nil
    hoverBar = nil
end

local function IsEnabled()
    return enabled
end

function M.Setup(setupCtx)
    if type(setupCtx) ~= "table" then
        error("NameplatesFriendlyBars.Setup: ctx is required", 2)
    end
    local client = setupCtx.client
    if client ~= "retail" and client ~= "forever" then
        error("NameplatesFriendlyBars.Setup: ctx.client must be retail or forever", 2)
    end

    ctx = setupCtx
    isRetail = client == "retail"
    bars = setupCtx.friendlyPlates
    records = setupCtx.suppressedUFs
    pool = setupCtx.pool

    watcher = CreateFrame("Frame")
    watcher:SetScript("OnEvent", OnEvent)

    ns.TryAddFriendlyPlate = TryAddFriendlyPlate
    ns.RemoveFriendlyPlate = RemoveFriendlyPlate
    ns.RemoveFriendlyPlateNoRestore = RemoveFriendlyPlateNoRestore

    M.ClearAll = ClearAll
    M.IsEnabled = IsEnabled
    M.SetEnabled = SetEnabled
end
