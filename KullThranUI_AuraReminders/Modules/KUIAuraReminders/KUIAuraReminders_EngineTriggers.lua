-- Custom aura engine, value triggers: unit health and power, spell charges, items, casts and usable spells. Each
-- source answers true, false or nil (unknown now) plus display data, as the sources of E.Sources do:
--   data = { value, max, percent, count, icon, durationObject | expirationTime + duration }
-- A value that is secret is never compared: a comparison on it is unknown and follows the record's While Secret. It
-- is still handed to the widgets (a status bar takes a secret value and a secret maximum). Shared byte for byte
-- between the Retail and Forever workspaces.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local IsSecret, Field, ValidID = E.IsSecret, E.Field, E.ValidID

E.Sources = E.Sources or {}

-- Helpers -------------------------------------------------------------------------------------------------------------

-- Calls `fn` safely; nothing when it is missing or raises.
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local result = { pcall(fn, ...) }
    if not result[1] then return nil end
    return unpack(result, 2, table.maxn(result))
end

-- Whether `value` passes `op value`: true without a comparison, nil when the value is secret or not a number.
function E.Compare(op, value, wanted)
    if op == nil then return true end
    if value == nil or IsSecret(value) or type(value) ~= "number" then return nil end
    wanted = wanted or 0
    if op == "le" then return value <= wanted end
    if op == "lt" then return value < wanted end
    if op == "eq" then return value == wanted end
    if op == "gt" then return value > wanted end
    return value >= wanted
end
local Compare = E.Compare

local function Readable(value)
    return value ~= nil and not IsSecret(value)
end

local function UnitThere(unit)
    if unit == "player" then return true end
    local exists = Call(UnitExists, unit)
    if exists == nil or IsSecret(exists) then return true end
    return exists == true
end

-- A cooldown as a duration object when the client has one for it, else start and duration in seconds.
local function TimerData(data, start, duration, object)
    if object ~= nil then
        data.durationObject = object
    elseif Readable(start) and Readable(duration) and start > 0 and duration > 0 then
        data.expirationTime, data.duration = start + duration, duration
    end
    return data
end

-- Health and power --------------------------------------------------------------------------------------------------

-- The answer of a value source from `current` and `maximum`, which may be secret. A percentage is compared only when
-- both are readable.
local function ValueAnswer(src, current, maximum)
    local data = { value = current, max = maximum }
    if Readable(current) and Readable(maximum) and type(current) == "number" and type(maximum) == "number" then
        if maximum > 0 then data.percent = current / maximum * 100 else data.percent = 0 end
    end
    if src.op == nil then return true, data end
    local measured = current
    if src.percent then measured = data.percent end
    if src.percent and data.percent == nil then return nil, data end
    return Compare(src.op, measured, src.value), data
end

local Health = {}
E.Sources.health = Health

function Health.Evaluate(src)
    local unit = src.unit or "player"
    if not UnitThere(unit) then return false, nil end
    local current, maximum = Call(UnitHealth, unit), Call(UnitHealthMax, unit)
    if current == nil or maximum == nil then return nil, nil end
    return ValueAnswer(src, current, maximum)
end

local Power = {}
E.Sources.power = Power

function Power.Evaluate(src)
    local unit = src.unit or "player"
    if not UnitThere(unit) then return false, nil end
    local current, maximum
    if src.powerType then
        current, maximum = Call(UnitPower, unit, src.powerType), Call(UnitPowerMax, unit, src.powerType)
    else
        current, maximum = Call(UnitPower, unit), Call(UnitPowerMax, unit)
    end
    if current == nil or maximum == nil then return nil, nil end
    return ValueAnswer(src, current, maximum)
end

-- Spell charges -------------------------------------------------------------------------------------------------------

local Charges = {}
E.Sources.charges = Charges

-- The charges of a spell; while one is recharging, the recharge timer. A spell without charges counts one while it is
-- off cooldown.
function Charges.Evaluate(src)
    if not ValidID(src.spell) then return false, nil end
    local api = C_Spell
    local info = api and Call(api.GetSpellCharges, src.spell)
    if info == nil then return false, nil end
    if IsSecret(info) then return nil, nil end
    local current, most = Field(info, "currentCharges"), Field(info, "maxCharges")
    local data = { count = info.currentCharges, value = info.currentCharges, max = info.maxCharges }
    local object = api.GetSpellChargeDuration and Call(api.GetSpellChargeDuration, src.spell) or nil
    local recharging = current ~= nil and most ~= nil and current < most
    if recharging or (current == nil and object ~= nil) then
        TimerData(data, info.cooldownStartTime, info.cooldownDuration, object)
    end
    if src.op == nil then return true, data end
    return Compare(src.op, current, src.value), data
end

-- Items ---------------------------------------------------------------------------------------------------------------

local Item = {}
E.Sources.item = Item

local function ItemCooldown(item)
    if C_Item and C_Item.GetItemCooldown then return Call(C_Item.GetItemCooldown, item) end
    if C_Container and C_Container.GetItemCooldown then return Call(C_Container.GetItemCooldown, item) end
    return nil
end

local function ItemCount(item)
    if C_Item and C_Item.GetItemCount then return Call(C_Item.GetItemCount, item, false, true) end
    return Call(_G.GetItemCount, item, false, true)
end

function Item.Icon(item)
    if not ValidID(item) then return nil end
    if C_Item and C_Item.GetItemIconByID then
        local icon = Call(C_Item.GetItemIconByID, item)
        if icon ~= nil then return icon end
    end
    return Call(_G.GetItemIcon, item)
end

-- "ready": owned and off cooldown; "cooldown": on cooldown; "count": the number owned against the comparison.
function Item.Evaluate(src)
    if not ValidID(src.item) then return false, nil end
    local count = ItemCount(src.item)
    local start, duration = ItemCooldown(src.item)
    local data = { count = count, value = count, icon = Item.Icon(src.item) }
    local onCooldown
    if Readable(start) and Readable(duration) then
        onCooldown = start > 0 and duration > 1.5
        if onCooldown then TimerData(data, start, duration) end
    end
    if src.mode == "count" then
        if src.op == nil then return true, data end
        return Compare(src.op, count, src.value), data
    end
    if onCooldown == nil then return nil, data end
    if src.mode == "cooldown" then return onCooldown, data end
    if not Readable(count) then return nil, data end
    return (count > 0 and not onCooldown), (onCooldown and data or { count = count, value = count, icon = data.icon })
end

-- Casts ---------------------------------------------------------------------------------------------------------------

local Cast = {}
E.Sources.cast = Cast

-- A value that is there: a secret one is there too.
local function Present(value)
    return IsSecret(value) or value ~= nil
end

local function CastDuration(unit, channel)
    local fn = channel and _G.UnitChannelDuration or _G.UnitCastingDuration
    return Call(fn, unit)
end

-- The unit is casting or channelling (a spell, or any). The cast's icon and timer are shown even while secret.
function Cast.Evaluate(src)
    local unit = src.unit or "player"
    if not UnitThere(unit) then return false, nil end
    local channel = false
    local name, _, texture, startMS, endMS, _, _, _, spellID = Call(UnitCastingInfo, unit)
    if not Present(name) then
        local cName, _, cTexture, cStart, cEnd, _, _, cSpell = Call(UnitChannelInfo, unit)
        name, texture, startMS, endMS, spellID, channel = cName, cTexture, cStart, cEnd, cSpell, true
    end
    if not Present(name) then return false, nil end
    local data = { icon = texture }
    local object = CastDuration(unit, channel)
    if object ~= nil then
        data.durationObject = object
    elseif Readable(startMS) and Readable(endMS) and endMS > startMS then
        data.expirationTime, data.duration = endMS / 1000, (endMS - startMS) / 1000
    end
    if src.spell then
        if not Readable(spellID) then return nil, data end
        if spellID ~= src.spell then return false, nil end
    end
    return true, data
end

-- Usable spells -------------------------------------------------------------------------------------------------------

local Usable = {}
E.Sources.usable = Usable

-- Usable now (resources, form, reactive conditions); with `range`, also in range of the target.
function Usable.Evaluate(src)
    if not ValidID(src.spell) then return false, nil end
    local api = C_Spell
    local usable = api and Call(api.IsSpellUsable, src.spell)
    if usable == nil and _G.IsUsableSpell then usable = Call(_G.IsUsableSpell, src.spell) end
    if usable == nil or IsSecret(usable) then return nil, nil end
    if not usable then return false, nil end
    if src.range then
        local inRange = api and Call(api.IsSpellInRange, src.spell, "target")
        if IsSecret(inRange) then return nil, nil end
        -- nil: no target, or the spell has no range to check.
        if inRange ~= true then return false, nil end
    end
    return true, nil
end

-- Which units each source reads, for the unit events (E.UnitsOf).
local UNIT_KINDS = { aura = true, health = true, power = true, cast = true }

-- The units the record's sources read; the Cooldown Manager bridge reads the player.
function E.UnitsOf(record)
    local units = {}
    for _, src in ipairs(record.sources or {}) do
        if UNIT_KINDS[src.kind] then units[src.unit or "player"] = true end
        if src.kind == "cdm" then units.player = true end
        if src.kind == "usable" and src.range then units.target = true end
    end
    return units
end

-- Whether the record needs the range ticker: range is not sent as an event.
function E.NeedsTicker(record)
    for _, src in ipairs(record.sources or {}) do
        if src.kind == "usable" and src.range then return true end
    end
    return false
end
