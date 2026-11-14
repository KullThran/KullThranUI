-- Custom aura engine, schema: the v1 record, the conversion from the v0 record the options page still writes, the
-- secret-safe helpers and the three-valued combination of trigger answers. Shared byte for byte between the Retail
-- and Forever workspaces.
--
-- v1 record:
--   { v = 1, name, enabled, logic = "all" | "any",
--     sources = { { kind = "aura", spells = {id...}, unit, harmful, missing, caster = "any" | "player" },
--                 { kind = "cooldown", spell, ready },
--                 { kind = "cdm", spells = {id...}, missing },   -- a buff the Cooldown Manager tracks
--                 { kind = "state", what = "combat" | "group" | "raid" | "solo" | "resting" | "mounted"
--                                          | "stealthed" | "flying" | "target" | "attackable" },
--                 { kind = "health", unit, op, value, percent },          -- E.Triggers
--                 { kind = "power", unit, powerType, op, value, percent },
--                 { kind = "charges", spell, op, value },
--                 { kind = "item", item, mode = "ready" | "cooldown" | "count", op, value },
--                 { kind = "cast", unit, spell },                        -- spell nil for any cast
--                 { kind = "usable", spell, range } },
--     load = { combat = "ANY" | "IN_COMBAT" | "OUT_COMBAT", instance, talent, zone,
--              boss = "ANY" | "BOSS" | "NO_BOSS", encounterID, class, spec, role, group, minLevel, notMounted },
--     stacks = { op = "ge" | "le" | "eq", value },     -- shown only at these stacks (E.Stacks), nil for any
--     region = { kind = "icon" | "text" | "bar", size, alpha, glow, nameLabel,
--                text = { mode = "NONE" | "STATIC" | "STACKS" | "DURATION" | "TOKENS", value, point, size },
--                bar = { width, color = { r, g, b }, fill = "time" | "stacks" | "value", max },
--                swipe, inactive = "hide" | "desaturate" | "dim", iconSpell, anchorFrame,
--                group, groupOrder, point, relativePoint, x, y },
--     animations = { start = "fade" | "zoom", main = "pulse" | "flash" | "shake", finish = "fade" | "shrink" },
--     rules = { { check = "remaining" | "stacks" | "value" | "percent" | "count" | "trigger", trigger, op, value,
--                 color, glow, desaturate, alpha }... },             -- E.Conditions
--     sound = { applied, removed, channel },          -- LibSharedMedia sound names, nil for none
--     conditions = { lowTime, lowTimeColor = { r, g, b },   -- lowTime in seconds, nil for off
--                    stackAlert, stackAlertColor },          -- alert colour and glow from stackAlert stacks, nil off
--     unknown = "last" | "hide" | "dim" }  -- what an answer that cannot be read now shows
-- A trigger answer is true, false, or nil when it cannot be known now (a secret value).
--
-- v0 (what the options page writes) keeps trigger 1 in the record's own trigger fields and triggers 2 to 4 in
-- `extraTriggers`, a list of tables with the same trigger fields; `triggerLogic` is "ALL" or "ANY".

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

E.SCHEMA_VERSION = 1

local function IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end
E.IsSecret = IsSecret

-- A field of a possibly secret table, or nil when the table or the field is secret.
function E.Field(data, key)
    if data == nil or IsSecret(data) then return nil end
    local value = data[key]
    if IsSecret(value) then return nil end
    return value
end

function E.ValidID(id)
    return type(id) == "number" and id > 0
end

-- Hook for the client's spell ranks: one buff can have an ID per rank (Forever). Identity by default.
function E.ExpandSpellIDs(ids)
    return ids
end

E.BAR_WIDTH = 180
E.BAR_COLOR = { r = 0.25, g = 0.55, b = 0.95 }
E.LOW_TIME_COLOR = { r = 1, g = 0.2, b = 0.2 }
E.STACK_ALERT_COLOR = { r = 0.3, g = 1, b = 0.3 }
E.STACK_MAX = 5

-- A colour saved as { r, g, b } or { [1], [2], [3] }, or the fallback.
local function Color(value, fallback)
    if type(value) ~= "table" then return fallback end
    local r, g, b = value.r or value[1], value.g or value[2], value.b or value[3]
    if type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return fallback end
    return { r = r, g = g, b = b }
end
E.Color = Color

local function SoundName(value)
    if value == nil or value == "" or value == "None" then return nil end
    return value
end

local UNKNOWN = { LAST = "last", HIDE = "hide", DIM = "dim" }

local function GroupName(value)
    if type(value) ~= "string" or value == "" then return nil end
    return value
end

-- A whole number of stacks from 1 to 99, or nil.
local function StackNumber(value)
    if type(value) ~= "number" then return nil end
    value = math.floor(value)
    if value < 1 then return nil end
    return math.min(value, 99)
end

local STACK_OPS = { GE = "ge", LE = "le", EQ = "eq" }

-- The stack filter of an aura that is there (not "missing"); cooldowns have no stacks.
local function StackFilter(conf, source)
    local op = STACK_OPS[conf.stacksOp]
    if not (op and source) or source.missing then return nil end
    if source.kind ~= "aura" and source.kind ~= "cdm" then return nil end
    return { op = op, value = StackNumber(conf.stacksValue) or 1 }
end

local function RegionKind(style)
    if style == "TEXT" then return "text" end
    if style == "BAR" then return "bar" end
    return "icon"
end

E.MAX_TRIGGERS = 4
E.MAX_RULES = 4

-- Comparisons of the value triggers and the condition rules. NONE (or unset) compares nothing.
local OPS = { LE = "le", GE = "ge", EQ = "eq", LT = "lt", GT = "gt" }
E.OPS = OPS

local function Op(value)
    return OPS[value]
end

local function Num(value)
    if type(value) ~= "number" or value ~= value then return nil end
    return value
end

local STATES = {
    combat = true, group = true, raid = true, solo = true, resting = true, mounted = true, stealthed = true,
    flying = true, target = true, attackable = true,
}
local ITEM_MODES = { READY = "ready", COOLDOWN = "cooldown", COUNT = "count" }

-- The v1 source of one saved trigger: the record itself (trigger 1) or an entry of its extraTriggers. nil for an
-- unknown type.
function E.SourceOf(t)
    if type(t) ~= "table" then return nil end
    local kind = t.triggerType
    local unit = t.triggerUnit or "player"
    if kind == "AURA" then
        return {
            kind = "aura",
            spells = { t.triggerSpellID },
            unit = unit,
            -- The options store HELPFUL/HARMFUL; DEBUFF is a legacy value of existing profiles.
            harmful = t.triggerAuraType == "HARMFUL" or t.triggerAuraType == "DEBUFF",
            missing = t.triggerAuraMissing == true,
            caster = t.triggerCaster == "PLAYER" and "player" or "any",
        }
    elseif kind == "COOLDOWN" then
        return { kind = "cooldown", spell = t.triggerSpellID, ready = t.triggerCooldownReady == true }
    elseif kind == "CDM" then
        return { kind = "cdm", spells = { t.triggerSpellID }, missing = t.triggerAuraMissing == true }
    elseif kind == "STATE" then
        return { kind = "state", what = STATES[t.triggerState] and t.triggerState or "combat" }
    elseif kind == "HEALTH" then
        return { kind = "health", unit = unit, op = Op(t.triggerOp), value = Num(t.triggerValue) or 0,
            percent = t.triggerValueMode ~= "VALUE" }
    elseif kind == "POWER" then
        local powerType = Num(t.triggerPowerType)
        if powerType and powerType < 0 then powerType = nil end
        return { kind = "power", unit = unit, powerType = powerType, op = Op(t.triggerOp),
            value = Num(t.triggerValue) or 0, percent = t.triggerValueMode == "PERCENT" }
    elseif kind == "CHARGES" then
        return { kind = "charges", spell = t.triggerSpellID, op = Op(t.triggerOp), value = Num(t.triggerValue) or 0 }
    elseif kind == "ITEM" then
        return { kind = "item", item = t.triggerItemID, mode = ITEM_MODES[t.triggerItemMode] or "ready",
            op = Op(t.triggerOp), value = Num(t.triggerValue) or 0 }
    elseif kind == "CAST" then
        local spell = t.triggerSpellID
        if not E.ValidID(spell) then spell = nil end
        return { kind = "cast", unit = unit == "player" and "player" or unit, spell = spell }
    elseif kind == "USABLE" then
        return { kind = "usable", spell = t.triggerSpellID, range = t.triggerInRange == true }
    end
    return nil
end

-- The record's saved triggers in order: the record, then its extra ones (at most MAX_TRIGGERS in all).
function E.TriggersOf(conf)
    local list = { conf }
    if type(conf.extraTriggers) == "table" then
        for _, t in ipairs(conf.extraTriggers) do
            if #list >= E.MAX_TRIGGERS then break end
            if type(t) == "table" then list[#list + 1] = t end
        end
    end
    return list
end

local RULE_CHECKS = {
    REMAINING = "remaining", STACKS = "stacks", VALUE = "value", PERCENT = "percent", COUNT = "count", TRIGGER = "trigger",
}

-- Condition rules: { check, trigger, op, value, color, glow, desaturate, alpha }. A rule without a comparison or any
-- effect is dropped.
local function Rules(list)
    local out = {}
    if type(list) ~= "table" then return out end
    for _, r in ipairs(list) do
        if #out >= E.MAX_RULES then break end
        if type(r) == "table" and RULE_CHECKS[r.check] then
            local check = RULE_CHECKS[r.check]
            local rule = {
                check = check,
                trigger = math.max(1, math.min(E.MAX_TRIGGERS, math.floor(Num(r.trigger) or 1))),
                op = Op(r.op) or "ge",
                value = Num(r.value) or 0,
                color = r.useColor and Color(r.color, nil) or nil,
                glow = r.glow == true or nil,
                desaturate = r.desaturate == true or nil,
                alpha = Num(r.alpha),
            }
            -- "Trigger N is active" has no comparison of its own.
            if check == "trigger" then rule.op, rule.value = nil, nil end
            if rule.color or rule.glow or rule.desaturate or rule.alpha then out[#out + 1] = rule end
        end
    end
    return out
end

local START_ANIMS = { FADE = "fade", ZOOM = "zoom" }
local MAIN_ANIMS = { PULSE = "pulse", FLASH = "flash", SHAKE = "shake" }
local FINISH_ANIMS = { FADE = "fade", SHRINK = "shrink" }
local INACTIVE = { DESATURATE = "desaturate", DIM = "dim" }
local TEXT_POINTS = {
    CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true, TOPLEFT = true, TOPRIGHT = true,
    BOTTOMLEFT = true, BOTTOMRIGHT = true,
}

local function BarFill(value)
    if value == "STACKS" then return "stacks" end
    if value == "VALUE" then return "value" end
    return "time"
end

local function AnchorFrame(value)
    if type(value) ~= "string" then return nil end
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    if value == "" or not value:match("^[%w_]+$") then return nil end
    return value
end

-- v0 to v1. Pure: a v1 record is returned as is, a v0 record is read into a new table and left unchanged.
function E.Migrate(conf)
    if type(conf) ~= "table" then return nil end
    if conf.v == E.SCHEMA_VERSION then return conf end

    -- Each trigger keeps its place: an unknown type still counts, as a source that never answers.
    local sources = {}
    for i, t in ipairs(E.TriggersOf(conf)) do
        sources[i] = E.SourceOf(t) or { kind = "none" }
    end
    if #sources == 1 and sources[1].kind == "none" then sources = {} end

    local load = {
        combat = conf.loadCombat or "ANY",
        instance = conf.loadInstance or "ANY",
        talent = conf.loadTalent,
        zone = conf.loadZoneID,
        boss = conf.loadBoss or "ANY",
        encounterID = conf.loadEncounterID,
        class = (type(conf.loadClass) == "string" and conf.loadClass ~= "ANY") and conf.loadClass or nil,
        spec = (Num(conf.loadSpec) and conf.loadSpec > 0) and math.floor(conf.loadSpec) or nil,
        role = (conf.loadRole == "TANK" or conf.loadRole == "HEALER" or conf.loadRole == "DAMAGER") and conf.loadRole
            or nil,
        group = (conf.loadGroup == "SOLO" or conf.loadGroup == "PARTY" or conf.loadGroup == "RAID"
            or conf.loadGroup == "GROUP") and conf.loadGroup or nil,
        minLevel = (Num(conf.loadMinLevel) and conf.loadMinLevel > 0) and math.floor(conf.loadMinLevel) or nil,
        notMounted = conf.loadNotMounted == true or nil,
    }

    return {
        v = E.SCHEMA_VERSION,
        name = conf.name,
        enabled = conf.enabled and true or false,
        logic = conf.triggerLogic == "ANY" and "any" or "all",
        sources = sources,
        load = load,
        region = {
            kind = RegionKind(conf.displayStyle),
            size = conf.size or 40,
            alpha = conf.opacity or 1.0,
            glow = conf.showGlow == true,
            -- The placing mode always showed it as off when unset; play now agrees.
            nameLabel = conf.showNameLabel == true,
            text = {
                mode = conf.customTextType or "NONE", value = conf.customTextValue,
                point = TEXT_POINTS[conf.textPoint] and conf.textPoint or nil,
                size = (Num(conf.textSize) and conf.textSize >= 6) and math.min(conf.textSize, 64) or nil,
            },
            bar = {
                width = (type(conf.barWidth) == "number" and conf.barWidth > 0) and conf.barWidth or E.BAR_WIDTH,
                color = Color(conf.barColor, E.BAR_COLOR),
                fill = BarFill(conf.barFill),
                max = StackNumber(conf.stackMax) or E.STACK_MAX,
            },
            swipe = conf.showSwipe == true,
            inactive = INACTIVE[conf.inactiveMode] or "hide",
            iconSpell = (E.ValidID(conf.iconSpellID)) and conf.iconSpellID or nil,
            anchorFrame = AnchorFrame(conf.anchorFrame),
            group = GroupName(conf.group),
            groupOrder = type(conf.groupOrder) == "number" and conf.groupOrder or 0,
            point = conf.point, relativePoint = conf.relativePoint, x = conf.xOffset, y = conf.yOffset,
        },
        animations = {
            start = START_ANIMS[conf.animStart],
            main = MAIN_ANIMS[conf.animMain],
            finish = FINISH_ANIMS[conf.animFinish],
        },
        rules = Rules(conf.rules),
        sound = {
            applied = SoundName(conf.soundApplied),
            removed = SoundName(conf.soundRemoved),
            channel = conf.soundChannel or "Master",
        },
        conditions = {
            lowTime = (type(conf.lowTime) == "number" and conf.lowTime > 0) and conf.lowTime or nil,
            lowTimeColor = Color(conf.lowTimeColor, E.LOW_TIME_COLOR),
            stackAlert = StackNumber(conf.stackAlert),
            stackAlertColor = Color(conf.stackAlertColor, E.STACK_ALERT_COLOR),
        },
        unknown = UNKNOWN[conf.unknownMode] or "last",
        stacks = StackFilter(conf, sources[1]),
    }
end

-- Combines answers: "all" is false if any is false, "any" is true if any is true; otherwise an unknown keeps the
-- result unknown. No answers is never active. `answers.n` counts trailing nils.
function E.Combine(logic, answers)
    local count = answers.n or #answers
    if count == 0 then return false end
    local unknown = false
    if logic == "any" then
        for i = 1, count do
            local a = answers[i]
            if a == true then return true end
            if a == nil then unknown = true end
        end
        if unknown then return nil end
        return false
    end
    for i = 1, count do
        local a = answers[i]
        if a == false then return false end
        if a == nil then unknown = true end
    end
    if unknown then return nil end
    return true
end
