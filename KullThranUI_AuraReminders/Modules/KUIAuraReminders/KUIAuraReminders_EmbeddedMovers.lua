-- KUI unlock mode for the embedded aura engine: one movable element per display placed on the screen (a top-level
-- aura or group; a group's children move with it). A drag keeps the display's own anchor points and saves only its
-- offsets, in the display's own units, as the engine's editor would.

local _, ns = ...
local KT = ns.KT
local E = ns.EmbeddedAuraEngine
if not KT or not E then return end

local M = {}
ns.AuraRemindersEmbeddedMovers = M

M.PREFIX = "KUIAR_EngineAura_"
M.SIDEBAR_GROUP = "Aura Reminders"
M.ORDER = 620

-- Anchored to the screen (the engine's full-screen frame or UIParent): the only displays the unlock mode can place.
local SCREEN = { SCREEN = true, UIPARENT = true }

local function L(text)
    return KT.Options and KT.Options.LText and KT.Options.LText(text) or text
end

local function API()
    return E.API and E.API()
end

-- The saved displays themselves, not copies: an edit here is what the engine saves.
local function Displays()
    local saved = _G.KUIAR_EngineSaved
    return type(saved) == "table" and type(saved.displays) == "table" and saved.displays or {}
end

local ids = {} -- uid -> id, refreshed on every pass

local function DataOf(uid)
    local displays = Displays()
    local id = ids[uid]
    local data = id and displays[id]
    if data and data.uid == uid then return data end
    for otherID, other in pairs(displays) do
        if type(other) == "table" and other.uid == uid then
            ids[uid] = otherID
            return other
        end
    end
    return nil
end

local function RegionOf(uid)
    local data, api = DataOf(uid), API()
    if not (data and api and api.GetRegion) then return nil end
    local ok, region = pcall(api.GetRegion, data.id)
    return ok and region or nil
end

-- Whether the unlock mode can place a display.
function M.Placeable(data)
    if type(data) ~= "table" or not data.uid or not data.id or data.parent then return false end
    return SCREEN[data.anchorFrameType or "SCREEN"] == true
end

-- How far into a box a point sits: 0 at the left / top edge, 1 at the right / bottom edge.
function M.Fractions(point)
    point = type(point) == "string" and point:upper() or "CENTER"
    local fx = point:find("LEFT") and 0 or (point:find("RIGHT") and 1 or 0.5)
    local fy = point:find("TOP") and 0 or (point:find("BOTTOM") and 1 or 0.5)
    return fx, fy
end

local function Round(value)
    return math.floor(value * 10 + 0.5) / 10
end

-- The offsets that put a box of w x h with its top left at (x, y) - offsets from the UI's top left, y downwards
-- negative - where the display's selfPoint meets the screen's anchorPoint. uiW and uiH: the UI's size in the same
-- units as everything else (the display's own).
function M.Offsets(selfPoint, anchorPoint, x, y, w, h, uiW, uiH)
    local sx, sy = M.Fractions(selfPoint)
    local ax, ay = M.Fractions(anchorPoint)
    local px, py = x + sx * w, y - sy * h
    return Round(px - ax * uiW), Round(py + ay * uiH)
end

local function UIRatio(region)
    local ui = UIParent
    local uiScale = ui and ui.GetEffectiveScale and ui:GetEffectiveScale() or 1
    local scale = region and region.GetEffectiveScale and region:GetEffectiveScale() or uiScale
    if not scale or scale <= 0 then return 1 end
    return uiScale / scale
end

-- Puts the display where its saved data says (also after a cancelled drag).
local function Reanchor(uid)
    local data, region = DataOf(uid), RegionOf(uid)
    if not (data and region) then return end
    if region.SetOffset then
        region:SetOffset(data.xOffset or 0, data.yOffset or 0)
    end
end

local function Save(uid, point, relativePoint, x, y)
    local data = DataOf(uid)
    if not data then return end
    data.xOffset, data.yOffset = x or 0, y or 0
    local api = API()
    if api and api.Add then
        local ok, err = pcall(api.Add, data)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    else
        Reanchor(uid)
    end
end

local function Element(uid, label)
    return {
        key = M.PREFIX .. uid, label = label, group = M.SIDEBAR_GROUP, order = M.ORDER,
        noScale = true, noResize = true,
        getFrame = function() return RegionOf(uid) end,
        getSize = function()
            local region = RegionOf(uid)
            local w = region and region.GetWidth and region:GetWidth()
            local h = region and region.GetHeight and region:GetHeight()
            if w and h and w > 0 and h > 0 then return w, h end
            local data = DataOf(uid) or {}
            return data.width or 64, data.height or 32
        end,
        -- A display with no frame (never loaded on this character) cannot be dragged.
        isHidden = function()
            local data = DataOf(uid)
            if not M.Placeable(data) then return true end
            if type(data.load) == "table" and data.load.use_never then return true end
            return RegionOf(uid) == nil
        end,
        translateMoverPosition = function(_, pos)
            local data, region = DataOf(uid), RegionOf(uid)
            if not (data and region) then return nil end
            local ratio = UIRatio(region)
            local uiW = (UIParent and UIParent:GetWidth() or 0) * ratio
            local uiH = (UIParent and UIParent:GetHeight() or 0) * ratio
            local x, y = M.Offsets(data.selfPoint, data.anchorPoint, pos.x or 0, pos.y or 0,
                region:GetWidth() or 0, region:GetHeight() or 0, uiW, uiH)
            return { point = data.selfPoint or "CENTER", relativePoint = data.anchorPoint or "CENTER", x = x, y = y }
        end,
        applyPendingPosition = function(_, pos)
            local region = RegionOf(uid)
            if region and region.SetOffset then region:SetOffset(pos.x or 0, pos.y or 0) end
        end,
        loadPosition = function()
            local data = DataOf(uid) or {}
            return {
                point = data.selfPoint or "CENTER", relativePoint = data.anchorPoint or "CENTER",
                x = data.xOffset or 0, y = data.yOffset or 0,
            }
        end,
        savePosition = function(_, point, relativePoint, x, y) Save(uid, point, relativePoint, x, y) end,
        resetPosition = function()
            Save(uid, nil, nil, 0, 0)
            return true
        end,
        clearPosition = function() Save(uid, nil, nil, 0, 0) end,
        applyPosition = function() Reanchor(uid) end,
    }
end

local registered = {} -- key -> label

local function UnlockModule()
    if type(KT.GetModule) ~= "function" then return nil end
    local ok, um = pcall(KT.GetModule, KT, "UnlockMode", true)
    return ok and um or nil
end
M.UnlockModule = UnlockModule

-- Registers what is new or renamed and removes what is gone.
function M.Sync()
    if not (type(KT.RegisterMovableElements) == "function" and type(KT.UnlockElements) == "table") then return end
    local wanted = {}
    wipe(ids)
    for id, data in pairs(Displays()) do
        if M.Placeable(data) then
            ids[data.uid] = id
            wanted[M.PREFIX .. data.uid] = { uid = data.uid, label = data.id }
        end
    end
    local add = {}
    for key, item in pairs(wanted) do
        if registered[key] ~= item.label or KT.UnlockElements[key] == nil then
            registered[key] = item.label
            add[#add + 1] = Element(item.uid, item.label)
        end
    end
    local removed = false
    for key in pairs(registered) do
        if not wanted[key] then
            registered[key] = nil
            KT.UnlockElements[key] = nil
            removed = true
        end
    end
    if #add > 0 then KT:RegisterMovableElements(add) end
    if removed then
        local um = UnlockModule()
        if um and um.UpdateRegistry then pcall(um.UpdateRegistry, um) end
    end
end

-- Many displays change at once (an import, a login): one pass after them.
local pending
local function Queue()
    if pending then return end
    pending = true
    C_Timer.After(0, function()
        pending = nil
        local ok, err = pcall(M.Sync)
        if not ok and geterrorhandler then geterrorhandler()(err) end
    end)
end
M.Queue = Queue

-- Opens KUI's unlock mode; true when it did.
function M.Open()
    local um = UnlockModule()
    if not (um and um.OpenUnlockMode) then return false end
    M.Sync()
    um:OpenUnlockMode()
    return true
end

local core = E.Core and E.Core()
local callbacks = core and core.callbacks
if callbacks and callbacks.RegisterCallback then
    for _, event in ipairs({ "Add", "Delete", "Rename" }) do callbacks:RegisterCallback(event, Queue) end
end
if CreateFrame then
    local events = CreateFrame("Frame")
    events:RegisterEvent("PLAYER_ENTERING_WORLD")
    events:SetScript("OnEvent", function() C_Timer.After(1, Queue) end)
end
