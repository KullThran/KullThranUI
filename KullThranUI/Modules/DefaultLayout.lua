local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

-- KUI's default positions differ per client (Retail / Forever) and per
-- resolution: the KUI scales (0.71 / 0.53 / 0.35) make one UI unit about one
-- physical pixel, so a single set of offsets cannot suit 1080p and 4K. The
-- data lives in Modules/DefaultLayoutData.lua (generated). Elements laid out
-- around a unit frame carry `relativeTo` (that frame's global name) and a
-- screen `fallback` for when the frame does not exist.

-- "1080p", "1440p" or "2160p", the same thresholds as the KUI UI scale.
function KT:GetDefaultLayoutResolution()
    local _, height = GetPhysicalScreenSize()
    if height and height >= 2160 then return "2160p" end
    if height and height >= 1440 then return "1440p" end
    return "1080p"
end

local function CopyPosition(pos)
    if type(pos) ~= "table" then return nil end
    return { point = pos.point, relativeTo = pos.relativeTo, relativePoint = pos.relativePoint, x = pos.x, y = pos.y,
        fallback = CopyPosition(pos.fallback) }
end

local function LayoutSet(data)
    local client = data and data[KT.IS_FOREVER == true and "forever" or "retail"]
    return client and client[KT:GetDefaultLayoutResolution()]
end

-- The default position of element `id` on this client and resolution, as a
-- fresh { point, relativeTo?, relativePoint, x, y, fallback? } table, or
-- `fallback` when there is none.
function KT:GetDefaultLayoutPosition(id, fallback)
    local set = LayoutSet(KT.DefaultLayoutData)
    local pos = set and set[id]
    if not pos then return fallback end
    return CopyPosition(pos)
end

-- SetPoint arguments for a stored position: its relativeTo frame when that
-- exists, else its screen fallback, else the position itself on UIParent.
-- Returns relativeFrame, point, relativePoint, x, y.
function KT:ResolveLayoutAnchor(pos)
    local frame = pos.relativeTo and _G[pos.relativeTo]
    if frame then
        return frame, pos.point, pos.relativePoint or pos.point, pos.x or 0, pos.y or 0
    end
    local screen = pos.relativeTo and pos.fallback or pos
    return UIParent, screen.point, screen.relativePoint or screen.point, screen.x or 0, screen.y or 0
end

-- True when a stored position still is `legacy` (the single-set default the
-- layout replaced, never moved by the user), so it may take the new default.
function KT:IsLegacyDefaultPosition(pos, legacy)
    if type(pos) ~= "table" or type(legacy) ~= "table" then return false end
    if pos.relativeTo ~= legacy.relativeTo then return false end
    if pos.point ~= legacy.point then return false end
    if (pos.relativePoint or pos.point) ~= (legacy.relativePoint or legacy.point) then return false end
    local x, y = tonumber(pos.x), tonumber(pos.y)
    return x ~= nil and y ~= nil and math.abs(x - (legacy.x or 0)) < 0.01 and math.abs(y - (legacy.y or 0)) < 0.01
end

-- True when a stored position still is element `id`'s screen default from
-- before it was anchored to a unit frame (Modules/DefaultLayoutPrevious.lua).
function KT:IsPreviousDefaultPosition(id, pos)
    local set = LayoutSet(KT.DefaultLayoutPrevious)
    return set ~= nil and set[id] ~= nil and KT:IsLegacyDefaultPosition(pos, set[id])
end

-- AceDB and MergeDefaults fill a stored table's missing keys from the
-- defaults, so a screen position saved without relativeTo picks up the
-- anchored default's relativeTo and fallback and lands off the unit frame.
-- Such a position keeps its own point/relativePoint: when they are not the
-- default's, it is that screen position. On element `id`'s previous screen
-- default it takes the anchored default; otherwise it stays on the screen,
-- marked relativeTo = false so no merge anchors it again. Edits `pos` in
-- place; true when it changed.
function KT:RepairLayoutPosition(id, pos)
    if type(pos) ~= "table" or type(pos.relativeTo) ~= "string" then return false end
    local default = KT:GetDefaultLayoutPosition(id)
    if not default or pos.relativeTo ~= default.relativeTo then return false end
    if pos.point == default.point and (pos.relativePoint or pos.point) == default.relativePoint then return false end
    -- An anchored default replaced later (DefaultLayoutPreviousAnchored).
    local anchored = LayoutSet(KT.DefaultLayoutPreviousAnchored)
    if anchored and KT:IsLegacyDefaultPosition(pos, anchored[id]) then
        pos.point, pos.relativePoint, pos.x, pos.y = default.point, default.relativePoint, default.x, default.y
        pos.fallback = default.fallback
        return true
    end
    local screen = { point = pos.point, relativePoint = pos.relativePoint, x = pos.x, y = pos.y }
    if KT:IsPreviousDefaultPosition(id, screen) then
        pos.point, pos.relativePoint, pos.x, pos.y = default.point, default.relativePoint, default.x, default.y
        pos.fallback = default.fallback
    else
        pos.relativeTo, pos.fallback = false, nil
    end
    return true
end
