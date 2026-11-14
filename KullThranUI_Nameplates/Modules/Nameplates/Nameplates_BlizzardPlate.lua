-- Nameplates runtime, Blizzard suppression: makes Blizzard's unit frame on a hostile plate invisible while it stays
-- alive, and brings its parts back on release. Three secure post-hooks per plate, once per frame object.

local _, ns = ...

local module = {}
ns.NameplatesBlizzardPlate = module

-- The published list itself is what the loops walk. Both spellings of the soft target frame are real entries.
local CHILD = { "healthBar", "HealthBarsContainer", "castBar", "name", "selectionHighlight", "aggroHighlight",
    "softTargetFrame", "SoftTargetFrame", "ClassificationFrame", "RaidTargetFrame", "PlayerLevelDiffFrame", "BuffFrame" }
local CHILD_COUNT = #CHILD

local LISTS = { "DebuffListFrame", "BuffListFrame", "CrowdControlListFrame", "LossOfControlFrame" }
local LIST_COUNT = #LISTS

local holdingFrame

-- Once-only records, for the session.
local hookedUnitFrames = {}
local hookedHighlights = {}

local function moveToOffscreen(element)
    if not element then return end
    local parents = ns._offscreenParents
    -- The first parent stays on record. G6: a nil parent makes no record.
    if not parents[element] then
        parents[element] = element:GetParent()
    end
    element:SetParent(holdingFrame)
end

local function restoreFromOffscreen(element)
    if not element then return end
    local parents = ns._offscreenParents
    local parent = parents[element]
    if parent then
        element:SetParent(parent)
        parents[element] = nil
    end
end

-- The two highlight hooks carry the same body, with no shared helper, since they run on each target change.
-- G7: the holding frame test is unreachable today, and kept. G5: nothing guards a secret unit.
local function onHighlightShow(self)
    local owner = self:GetParent()
    if not owner or owner == holdingFrame then return end
    local unit = owner.unit
    if not unit and owner.GetUnit then unit = owner:GetUnit() end
    if unit and UnitExists(unit) and UnitCanAttack("player", unit) then
        self:SetAlpha(0)
        self:Hide()
    end
end

local function onHighlightSetShown(self, shown)
    if not shown then return end
    local owner = self:GetParent()
    if not owner or owner == holdingFrame then return end
    local unit = owner.unit
    if not unit and owner.GetUnit then unit = owner:GetUnit() end
    if unit and UnitExists(unit) and UnitCanAttack("player", unit) then
        self:SetAlpha(0)
        self:Hide()
    end
end

-- First time for a unit frame only: the one closure, holding this frame's own re-entry guard.
-- G5: a raise leaves the guard set, and this frame's hook dead. The argument of SetAlpha is never read.
local function installAlphaHook(unitFrame)
    local busy = false
    hooksecurefunc(unitFrame, "SetAlpha", function(self)
        if busy then return end
        busy = true
        local unit = self.unit
        if not unit and self.GetUnit then unit = self:GetUnit() end
        if unit and UnitExists(unit) and UnitCanAttack("player", unit) then
            self:SetAlpha(0)
        end
        busy = false
    end)
end

-- Only what suppression hid comes back on restore.
local suppressedChildren = setmetatable({}, { __mode = "k" })

local function hideBlizzardFrame(nameplate, unit)
    if not nameplate then return end
    local unitFrame = nameplate.UnitFrame
    if not unitFrame then return end

    if unit and UnitCanAttack("player", unit) then
        -- Before the alpha hook exists, so the first suppression does not run it.
        unitFrame:SetAlpha(0)

        for i = 1, CHILD_COUNT do
            local child = unitFrame[CHILD[i]]
            if child then
                child:SetAlpha(0)
                child:Hide()
                suppressedChildren[child] = true
            end
        end

        -- Only the lists move: the auras frame itself stays untouched, so Blizzard's updates go on running.
        local auras = unitFrame.AurasFrame
        if auras then
            for i = 1, LIST_COUNT do
                local list = auras[LISTS[i]]
                if list then ns.MoveToOffscreen(list) end
            end
        end

        local widgets = unitFrame.WidgetContainer
        if widgets then widgets:SetParent(nameplate) end
    end

    -- G8: reached on any call, friendly plate and no unit included.
    if not hookedUnitFrames[unitFrame] then
        hookedUnitFrames[unitFrame] = true
        installAlphaHook(unitFrame)
    end

    local highlight = unitFrame.selectionHighlight
    if highlight and not hookedHighlights[highlight] then
        hookedHighlights[highlight] = true
        hooksecurefunc(highlight, "Show", onHighlightShow)
        hooksecurefunc(highlight, "SetShown", onHighlightSetShown)
    end
end

-- G3: the container goes to the unit frame. A plate still hostile gets its alpha back to 0 from the alpha hook.
local function restoreFrame(nameplate)
    if not nameplate then return end
    local unitFrame = nameplate.UnitFrame
    if not unitFrame then return end

    unitFrame:SetAlpha(1)

    for i = 1, CHILD_COUNT do
        local child = unitFrame[CHILD[i]]
        if child and suppressedChildren[child] then
            suppressedChildren[child] = nil
            child:SetAlpha(1)
            child:Show()
        end
    end

    local widgets = unitFrame.WidgetContainer
    if widgets then widgets:SetParent(unitFrame) end

    local auras = unitFrame.AurasFrame
    if auras then
        for i = 1, LIST_COUNT do
            local list = auras[LISTS[i]]
            if list then ns.RestoreFromOffscreen(list) end
        end
    end
end

function module.Setup(ctx)
    if type(ctx) ~= "table" then
        error("NameplatesBlizzardPlate.Setup: ctx required", 2)
    end
    if ctx.client ~= "retail" and ctx.client ~= "forever" then
        error("NameplatesBlizzardPlate.Setup: client must be retail or forever", 2)
    end

    holdingFrame = CreateFrame("Frame")
    holdingFrame:Hide()

    ns._offscreenParents = ns._offscreenParents or {}
    ns._BLIZZARD_UF_CHILDREN = CHILD
    ns.MoveToOffscreen = moveToOffscreen
    ns.RestoreFromOffscreen = restoreFromOffscreen
    ns.HideBlizzardFrame = hideBlizzardFrame
    module.HideBlizzardFrame = hideBlizzardFrame
    module.RestoreFrame = restoreFrame
end
