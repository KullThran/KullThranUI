-- Custom aura engine, stacks: the count of an aura's applications, the record's stack filter (show only at N stacks)
-- and what the stack bar and the stack alert read. A count comes from readable aura data or from the client's own
-- count text (Cooldown Manager bridge); a secret one is unknown and never compared. Shared byte for byte between the
-- Retail and Forever workspaces.
--
-- v1 fields (E.Migrate): record.stacks = { op = "ge" | "le" | "eq", value } or nil,
--   region.bar = { fill = "time" | "stacks", max }, conditions = { stackAlert, stackAlertColor }.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local IsSecret = E.IsSecret

local Stacks = {}
E.Stacks = Stacks

Stacks.MAX = 99

-- The number of applications, nil when it cannot be read now. An aura that does not stack counts as one.
function Stacks.Count(data)
    if data == nil or IsSecret(data) or type(data) ~= "table" then return nil end
    local text = data.applicationsText
    if IsSecret(text) then return nil end
    if type(text) == "string" then
        if text == "" then return 1 end
        return tonumber(text)
    end
    local count = data.applications
    if IsSecret(count) or type(count) ~= "number" then return nil end
    if count < 1 then return 1 end
    return count
end

-- Whether `count` passes the filter: true without a filter, nil when the count is unknown.
function Stacks.Test(filter, count)
    if not filter then return true end
    if count == nil then return nil end
    local value = filter.value or 1
    if filter.op == "le" then return count <= value end
    if filter.op == "eq" then return count == value end
    return count >= value
end

-- The record's answer through its stack filter: an active aura with the wrong count is off, with an unknown count
-- unknown.
function Stacks.Apply(record, active, data)
    local filter = record and record.stacks
    if not filter or active ~= true then return active, data end
    local pass = Stacks.Test(filter, Stacks.Count(data))
    if pass == nil then return nil, data end
    return pass, data
end

-- Whether the record's bar is filled by its stacks.
function Stacks.FillsBar(region)
    return region ~= nil and region.kind == "bar" and region.bar ~= nil and region.bar.fill == "stacks"
end

-- Whether the record uses its stacks at all: the filter, the stack bar or the stack alert.
function Stacks.Uses(record)
    if not record then return false end
    if record.stacks ~= nil or Stacks.FillsBar(record.region) then return true end
    return record.conditions ~= nil and record.conditions.stackAlert ~= nil
end

-- What the client's aura engine cannot do: it shows an aura whatever its count, and fills its bar by time.
function Stacks.BlocksDelegation(record)
    return record ~= nil and (record.stacks ~= nil or Stacks.FillsBar(record.region))
end
