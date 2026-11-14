-- Custom aura engine, trigger sources. Each source answers true, false or nil (unknown now) plus display data, and
-- says whether the client's aura engine can show it while Lua cannot read it. Shared byte for byte between the
-- Retail and Forever workspaces: both clients run the Mainline API with secret values.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local IsSecret, Field, ValidID = E.IsSecret, E.Field, E.ValidID

local NEVER_SECRET = (Enum and Enum.SecrecyLevel and Enum.SecrecyLevel.NeverSecret) or 0

E.Sources = E.Sources or {}

-- Aura --------------------------------------------------------------------------------------------------------------

-- Whether a read of this spell's aura comes back secret right now. Out of restriction every aura is readable; under
-- it only the spells Blizzard flags as never secret are.
function E.AuraReadIsSecret(spellID)
    local api = C_Secrets
    if not (api and api.ShouldAurasBeSecret) then return false end
    local ok, restricted = pcall(api.ShouldAurasBeSecret)
    if not ok or IsSecret(restricted) then return true end
    if not restricted then return false end
    if api.GetSpellAuraSecrecy then
        local found, level = pcall(api.GetSpellAuraSecrecy, spellID)
        if found and not IsSecret(level) and level == NEVER_SECRET then return false end
    end
    return true
end

-- The aura data (nil when absent) and whether the answer can be trusted. A lookup by spell ID answers nil for a
-- secret aura, which is not the same as absent, so a secret read is reported as unreadable before any lookup.
function E.ReadAura(unit, spellID, harmful)
    if not (unit and ValidID(spellID) and C_UnitAuras) then return nil, false end
    if E.AuraReadIsSecret(spellID) then return nil, false end

    local filter = harmful and "HARMFUL" or "HELPFUL"
    local ok, data
    if unit == "player" and not harmful and C_UnitAuras.GetPlayerAuraBySpellID then
        ok, data = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    elseif C_UnitAuras.GetUnitAuraBySpellID then
        ok, data = pcall(C_UnitAuras.GetUnitAuraBySpellID, unit, spellID)
    end
    if ok then return data, true end

    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if name and not IsSecret(name) and C_UnitAuras.GetAuraDataBySpellName then
        local found, byName = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, filter)
        if found then return byName, true end
    end
    return nil, false
end

local function ValidSpells(src)
    local list = {}
    for _, id in ipairs(src.spells or {}) do
        if ValidID(id) then list[#list + 1] = id end
    end
    return list
end

-- "Cast by me": the flag, then the caster; when neither can be read the aura counts.
local function CasterMatches(src, data)
    if src.caster ~= "player" or IsSecret(data) then return true end
    local flag = Field(data, "isFromPlayerOrPlayerPet")
    if flag ~= nil then return flag == true end
    local caster = Field(data, "sourceUnit")
    if caster and type(UnitIsUnit) == "function" then
        local ok, same = pcall(UnitIsUnit, caster, "player")
        if ok and not IsSecret(same) then return same == true end
    end
    return true
end

local Aura = {}
E.Sources.aura = Aura

function Aura.Evaluate(src)
    local spells = ValidSpells(src)
    if #spells == 0 then return false, nil end
    local unit = src.unit or "player"
    local unknown = false
    for _, id in ipairs(spells) do
        local data, readable = E.ReadAura(unit, id, src.harmful)
        if not readable then
            unknown = true
        elseif data ~= nil and CasterMatches(src, data) then
            if src.missing then return false, nil end
            return true, data
        end
    end
    if unknown then return nil, nil end
    return src.missing == true, nil
end

-- Whether any of the source's spells is secret right now.
function Aura.IsRestricted(src)
    for _, id in ipairs(ValidSpells(src)) do
        if E.AuraReadIsSecret(id) then return true end
    end
    return false
end

-- The client's engine matches spell IDs only for buffs on friendly units and debuffs on hostile ones, and shows an
-- aura only while it is there: own or pet debuffs and "missing" cannot be delegated.
function Aura.CanDelegate(src)
    if src.kind ~= "aura" or src.missing then return false end
    if #ValidSpells(src) == 0 then return false end
    local unit = src.unit or "player"
    if src.harmful and (unit == "player" or unit == "pet") then return false end
    return true
end

-- What the delegated slot (and the engine sounds) need, and a signature that changes when any of it does.
function Aura.SlotSpec(src)
    local ids = E.ExpandSpellIDs(ValidSpells(src)) or {}
    local map, keys = {}, {}
    for _, id in ipairs(ids) do
        if ValidID(id) and not map[id] then
            map[id] = true
            keys[#keys + 1] = id
        end
    end
    table.sort(keys)
    local candidates = { includeSpellIDs = map }
    if src.caster == "player" then candidates.isFromPlayerOrPlayerPet = true end
    local unit = src.unit or "player"
    local filter = { src.harmful and "HARMFUL" or "HELPFUL" }
    local signature = table.concat({ unit, filter[1], src.caster or "any", table.concat(keys, ",") }, "|")
    return { unit = unit, filter = filter, candidateFilters = candidates, spells = keys, signature = signature }
end

-- Cooldown ----------------------------------------------------------------------------------------------------------

local function CooldownDurationObject(spellID)
    local api = C_Spell
    if not (api and api.GetSpellCooldownDuration) then return nil end
    local ok, duration = pcall(api.GetSpellCooldownDuration, spellID)
    if ok then return duration end
    return nil
end

local Cooldown = {}
E.Sources.cooldown = Cooldown

function Cooldown.Evaluate(src)
    if not ValidID(src.spell) then return false, nil end
    local api = C_Spell
    local ok, info = false, nil
    if api and api.GetSpellCooldown then ok, info = pcall(api.GetSpellCooldown, src.spell) end
    if not ok or IsSecret(info) then return nil, nil end

    local start = info and info.startTime or 0
    local duration = info and info.duration or 0
    local onCooldown, data
    if IsSecret(start) or IsSecret(duration) then
        -- isActive and isOnGCD are never secret.
        local isActive, onGCD = info.isActive, info.isOnGCD
        if isActive == nil or IsSecret(isActive) or IsSecret(onGCD) then return nil, nil end
        onCooldown = isActive == true and onGCD ~= true
        data = { durationObject = CooldownDurationObject(src.spell) }
    else
        onCooldown = start > 0 and duration > 1.5
        data = { expirationTime = start + duration, duration = duration, applications = 0 }
    end
    -- "Ready" keeps the timer while it is on cooldown, for an aura shown while inactive (swipe, duration text).
    if src.ready then return not onCooldown, (onCooldown and data or nil) end
    if not onCooldown then return false, nil end
    return true, data
end

-- Cooldown Manager --------------------------------------------------------------------------------------------------

-- A buff the Cooldown Manager tracks. Its item frames hold the aura instance they show; whether one is set is known
-- even while the aura itself is secret, so presence (and "missing") can be read in combat. Duration and stack text come
-- from the instance and are only shown. A spell no item tracks is unknown: the manager may be off or not show it.
local CDM_VIEWERS = { "EssentialCooldownViewer", "UtilityCooldownViewer", "BuffIconCooldownViewer", "BuffBarCooldownViewer" }

local Cdm = {}
E.Sources.cdm = Cdm

local hooked = setmetatable({}, { __mode = "k" })
local onChange

-- `fn` runs whenever a tracked item gains or loses its aura.
function Cdm.Watch(fn)
    onChange = fn
end

local function Changed()
    if onChange then onChange() end
end

local function Hook(item)
    if hooked[item] or type(hooksecurefunc) ~= "function" then return end
    hooked[item] = true
    if item.SetAuraInstanceInfo then pcall(hooksecurefunc, item, "SetAuraInstanceInfo", Changed) end
    if item.ClearAuraInstanceInfo then pcall(hooksecurefunc, item, "ClearAuraInstanceInfo", Changed) end
end

local function ItemFrames(viewer)
    if type(viewer.GetItemFrames) == "function" then
        local ok, items = pcall(viewer.GetItemFrames, viewer)
        if ok and type(items) == "table" then return items end
    end
    return {}
end

local function CooldownInfo(item)
    if type(item.GetCooldownInfo) == "function" then
        local ok, info = pcall(item.GetCooldownInfo, item)
        if ok then return info end
        return nil
    end
    return item.cooldownInfo
end

local function Matches(info, wanted)
    if type(info) ~= "table" or IsSecret(info) then return false end
    local function hit(id) return id ~= nil and not IsSecret(id) and wanted[id] == true end
    if hit(info.spellID) or hit(info.overrideSpellID) or hit(info.overrideTooltipSpellID) or hit(info.linkedSpellID) then
        return true
    end
    local linked = info.linkedSpellIDs
    if type(linked) == "table" and not IsSecret(linked) then
        for _, id in ipairs(linked) do
            if hit(id) then return true end
        end
    end
    return false
end

local function InstanceData(item, instanceID)
    if IsSecret(instanceID) then return nil end
    local unit = item.auraDataUnit
    if type(unit) ~= "string" or IsSecret(unit) then unit = "player" end
    local api = C_UnitAuras
    local data = {}
    if api and api.GetAuraDuration then
        local ok, duration = pcall(api.GetAuraDuration, unit, instanceID)
        if ok then data.durationObject = duration end
    end
    if api and api.GetAuraApplicationDisplayCount then
        local ok, text = pcall(api.GetAuraApplicationDisplayCount, unit, instanceID, 2)
        if ok then data.applicationsText = text end
    end
    return data
end

function Cdm.Evaluate(src)
    local wanted, any = {}, false
    for _, id in ipairs(E.ExpandSpellIDs(ValidSpells(src)) or {}) do
        if ValidID(id) then wanted[id], any = true, true end
    end
    if not any then return false, nil end

    local found = false
    for _, name in ipairs(CDM_VIEWERS) do
        local viewer = _G[name]
        if type(viewer) == "table" then
            for _, item in ipairs(ItemFrames(viewer)) do
                if type(item) == "table" and Matches(CooldownInfo(item), wanted) then
                    found = true
                    Hook(item)
                    local instanceID = item.auraInstanceID
                    -- A secret ID is still an ID: the item shows an aura.
                    if IsSecret(instanceID) or instanceID ~= nil then
                        if src.missing then return false, nil end
                        return true, InstanceData(item, instanceID)
                    end
                end
            end
        end
    end
    if not found then return nil, nil end
    return src.missing == true, nil
end

-- State -------------------------------------------------------------------------------------------------------------

local State = {}
E.Sources.state = State

local function Call(fn, ...)
    if type(fn) ~= "function" then return false end
    local ok, value = pcall(fn, ...)
    return ok and value == true
end

function State.Evaluate(src, env)
    local what = src.what
    if what == "combat" then return (env and env.inCombat) == true, nil end
    if what == "group" then return Call(IsInGroup) or Call(IsInRaid), nil end
    if what == "raid" then return Call(IsInRaid), nil end
    if what == "solo" then return not (Call(IsInGroup) or Call(IsInRaid)), nil end
    if what == "resting" then return Call(IsResting), nil end
    if what == "mounted" then return Call(IsMounted), nil end
    if what == "stealthed" then return Call(IsStealthed), nil end
    if what == "flying" then return Call(IsFlying), nil end
    if what == "target" then return Call(UnitExists, "target"), nil end
    if what == "attackable" then return Call(UnitCanAttack, "player", "target"), nil end
    return false, nil
end

-- Record ------------------------------------------------------------------------------------------------------------

-- The record's answer and the data of the first active source that has some (else of the first source), through the
-- record's stack filter (E.Stacks), and the answers of each source (for the condition rules).
function E.Evaluate(record, env)
    local answers, firstData, activeData = { n = 0 }, nil, nil
    for i, src in ipairs(record.sources or {}) do
        local source = E.Sources[src.kind]
        local answer, data
        if source then answer, data = source.Evaluate(src, env) else answer = false end
        answers[i], answers.n = answer, i
        if i == 1 then firstData = data end
        if answer and data ~= nil and activeData == nil then activeData = data end
    end
    local answer, data = E.Combine(record.logic, answers), activeData or firstData
    local stacks = E.Stacks
    if stacks then
        answer, data = stacks.Apply(record, answer, data)
    end
    return answer, data, answers
end

-- The spell whose icon the record shows: the region's own choice, else the first trigger's spell.
function E.IconSpell(record)
    local own = record.region and record.region.iconSpell
    if ValidID(own) then return own end
    for _, src in ipairs(record.sources or {}) do
        if src.kind == "aura" or src.kind == "cdm" then
            local id = src.spells and src.spells[1]
            if ValidID(id) then return id end
        elseif src.kind == "cooldown" or src.kind == "charges" or src.kind == "usable" or src.kind == "cast" then
            if ValidID(src.spell) then return src.spell end
        end
    end
    return 1
end

-- The icon of a trigger without a spell of its own, by kind. File paths present in both clients.
E.KIND_ICONS = {
    health = "Interface\\Icons\\Spell_Holy_FlashHeal",
    power = "Interface\\Icons\\Spell_Nature_Lightning",
    cast = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    state = "Interface\\Icons\\Ability_Warrior_Charge",
}

-- The texture the record shows: the region's spell, the icon a source read (a cast, an item), the first item, the
-- trigger's spell through `spellTexture`, or the first trigger's kind icon.
function E.IconTexture(record, data, spellTexture)
    local own = record.region and record.region.iconSpell
    if ValidID(own) then return spellTexture(own) end
    local icon = data ~= nil and not IsSecret(data) and type(data) == "table" and data.icon or nil
    if icon ~= nil then return icon end
    for _, src in ipairs(record.sources or {}) do
        if src.kind == "item" and E.Sources.item and ValidID(src.item) then
            local itemIcon = E.Sources.item.Icon(src.item)
            if itemIcon ~= nil then return itemIcon end
        end
    end
    local spell = E.IconSpell(record)
    local first = record.sources and record.sources[1]
    if spell == 1 and first and E.KIND_ICONS[first.kind] then return E.KIND_ICONS[first.kind] end
    return spellTexture(spell)
end

-- The one aura source of a record that the client's engine can show, or nil. A stack filter or a bar filled by
-- stacks is beyond it.
function E.DelegableSource(record)
    if E.Stacks and E.Stacks.BlocksDelegation(record) then return nil end
    local sources = record.sources or {}
    if #sources ~= 1 then return nil end
    local src = sources[1]
    if src.kind == "aura" and Aura.CanDelegate(src) then return src end
    return nil
end
