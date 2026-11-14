-- Custom aura engine, import and export. A string is "!KUIAuras:1!" followed by Base64(Deflate(CBOR(payload))), made
-- with the client's C_EncodingUtil:
--   payload = { kind = "auras", v = 1, client = "retail" | "forever", auras = { record... }, groups = { [name] = ... } }
-- Records are the saved v0 fields. Both ways every field goes through a whitelist: unknown keys are dropped, wrong
-- types are dropped, numbers are clamped or dropped, text is cut. A string carries data only, never code.
-- Errors and warnings are English option strings for the page to localise. Shared byte for byte between the Retail and
-- Forever workspaces.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

local Codec = {}
E.Codec = Codec

local PREFIX = "!KUIAuras:1!"
local MAX_TEXT = 500000
local MAX_AURAS = 200
local MAX_GROUPS = 50

Codec.PREFIX = PREFIX
Codec.ERR_ENCODER = "This client cannot read or write aura strings."
Codec.ERR_NOTHING = "There are no auras to export."
Codec.ERR_PREFIX = "This is not a KUI aura string."
Codec.ERR_DAMAGED = "The string is damaged or incomplete."
Codec.WARN_CLIENT = "Made in the other game client: spell IDs can differ, check each aura."

-- The running client, from the interface version: Forever reports 1.x (16001), Retail 12.x.
function Codec.Client()
    if type(GetBuildInfo) ~= "function" then return "retail" end
    local _, _, _, toc = GetBuildInfo()
    if type(toc) == "number" and toc < 100000 then return "forever" end
    return "retail"
end

-- Field rules -------------------------------------------------------------------------------------------------------

local function Number(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function Text(max)
    return function(value)
        if type(value) ~= "string" then return nil end
        value = value:gsub("%c", "")
        if #value > max then value = value:sub(1, max) end
        return value
    end
end

local function Bool(value)
    if type(value) == "boolean" then return value end
    return nil
end

local function OneOf(...)
    local set = {}
    for _, v in ipairs({ ... }) do set[v] = true end
    return function(value)
        if type(value) == "string" and set[value] then return value end
        return nil
    end
end

local function Clamp(min, max)
    return function(value)
        if not Number(value) then return nil end
        if value < min then return min end
        if value > max then return max end
        return value
    end
end

-- Out of range is dropped (IDs).
local function Range(min, max)
    return function(value)
        if not Number(value) or value < min or value > max then return nil end
        return math.floor(value)
    end
end

local function Color(value)
    if type(value) ~= "table" then return nil end
    local out = {}
    for _, k in ipairs({ "r", "g", "b" }) do
        local c = value[k]
        if not Number(c) then return nil end
        out[k] = math.max(0, math.min(1, c))
    end
    return out
end

local ANCHOR = OneOf("TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT")
local ID = Range(0, 2147483647)

-- A frame's global name: letters, digits and underscores only.
local function FrameName(value)
    local text = Text(60)(value)
    if text and text:match("^[%w_]*$") then return text end
    return nil
end

local function Clean(source, rules)
    local out = {}
    if type(source) ~= "table" then return out end
    for key, rule in pairs(rules) do
        local value = rule(source[key])
        if value ~= nil then out[key] = value end
    end
    return out
end

-- A list of at most `max` tables, each cleaned by `rules`; nil when empty.
local function List(rules, max)
    return function(value)
        if type(value) ~= "table" then return nil end
        local out = {}
        for _, entry in ipairs(value) do
            if #out >= max then break end
            if type(entry) == "table" then out[#out + 1] = Clean(entry, rules) end
        end
        if #out == 0 then return nil end
        return out
    end
end

-- The fields of one trigger: the record's own (trigger 1) and each entry of extraTriggers.
local TRIGGER_FIELDS = {
    triggerType = OneOf("AURA", "COOLDOWN", "CDM", "STATE", "HEALTH", "POWER", "CHARGES", "ITEM", "CAST", "USABLE"),
    triggerSpellID = ID,
    triggerUnit = OneOf("player", "target", "focus", "pet"), triggerAuraType = OneOf("HELPFUL", "HARMFUL", "DEBUFF"),
    triggerAuraMissing = Bool, triggerCooldownReady = Bool, triggerCaster = OneOf("ANY", "PLAYER"),
    triggerState = OneOf("combat", "group", "raid", "solo", "resting", "mounted", "stealthed", "flying", "target",
        "attackable"),
    triggerOp = OneOf("NONE", "LE", "GE", "EQ", "LT", "GT"), triggerValue = Clamp(-1000000000, 1000000000),
    triggerValueMode = OneOf("PERCENT", "VALUE"), triggerPowerType = Range(-1, 40),
    triggerItemID = ID, triggerItemMode = OneOf("READY", "COOLDOWN", "COUNT"), triggerInRange = Bool,
}

local RULE_FIELDS = {
    check = OneOf("REMAINING", "STACKS", "VALUE", "PERCENT", "COUNT", "TRIGGER"), trigger = Range(1, 4),
    op = OneOf("LE", "GE", "EQ", "LT", "GT"), value = Clamp(-1000000000, 1000000000),
    useColor = Bool, color = Color, glow = Bool, desaturate = Bool, alpha = Clamp(0, 1),
}

local AURA_FIELDS = {
    name = Text(100), enabled = Bool,
    triggerLogic = OneOf("ALL", "ANY"), extraTriggers = List(TRIGGER_FIELDS, 3), rules = List(RULE_FIELDS, 4),
    loadCombat = OneOf("ANY", "IN_COMBAT", "OUT_COMBAT"),
    loadInstance = OneOf("ANY", "NONE", "PARTY", "RAID", "ARENA", "PVP"),
    loadTalent = ID, loadZoneID = ID, loadBoss = OneOf("ANY", "BOSS", "NO_BOSS"), loadEncounterID = ID,
    loadClass = OneOf("ANY", "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE",
        "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER"),
    loadSpec = Range(0, 4), loadRole = OneOf("ANY", "TANK", "HEALER", "DAMAGER"),
    loadGroup = OneOf("ANY", "SOLO", "PARTY", "RAID", "GROUP"), loadMinLevel = Range(0, 200), loadNotMounted = Bool,
    customTextType = OneOf("NONE", "STATIC", "STACKS", "DURATION", "TOKENS"), customTextValue = Text(100),
    textPoint = ANCHOR, textSize = Clamp(6, 64),
    showSwipe = Bool, inactiveMode = OneOf("HIDE", "DESATURATE", "DIM"), iconSpellID = ID, anchorFrame = FrameName,
    animStart = OneOf("NONE", "FADE", "ZOOM"), animMain = OneOf("NONE", "PULSE", "FLASH", "SHAKE"),
    animFinish = OneOf("NONE", "FADE", "SHRINK"),
    displayStyle = OneOf("ICON", "TEXT", "BAR"), size = Clamp(10, 100), opacity = Clamp(0, 1),
    showGlow = Bool, showNameLabel = Bool,
    point = ANCHOR, relativePoint = ANCHOR, xOffset = Clamp(-4000, 4000), yOffset = Clamp(-4000, 4000),
    barWidth = Clamp(60, 400), barColor = Color,
    soundApplied = Text(100), soundRemoved = Text(100),
    soundChannel = OneOf("Master", "SFX", "Music", "Ambience", "Dialog"),
    lowTime = Clamp(0, 30), lowTimeColor = Color,
    stacksOp = OneOf("GE", "LE", "EQ"), stacksValue = Clamp(1, 99), barFill = OneOf("TIME", "STACKS", "VALUE"),
    stackMax = Clamp(1, 99), stackAlert = Clamp(0, 99), stackAlertColor = Color,
    unknownMode = OneOf("LAST", "HIDE", "DIM"),
    group = Text(40), groupOrder = Clamp(-1000, 1000),
}

for key, rule in pairs(TRIGGER_FIELDS) do AURA_FIELDS[key] = rule end

local GROUP_FIELDS = {
    point = ANCHOR, relativePoint = ANCHOR, xOffset = Clamp(-4000, 4000), yOffset = Clamp(-4000, 4000),
    direction = OneOf("RIGHT", "LEFT", "UP", "DOWN"), spacing = Clamp(0, 40), dynamic = Bool,
    wrap = Clamp(0, 40), sort = OneOf("ORDER", "REMAINING"),
}

function Codec.CleanAura(conf)
    local out = Clean(conf, AURA_FIELDS)
    if out.group == "" then out.group = nil end
    return out
end

function Codec.CleanGroup(settings)
    return Clean(settings, GROUP_FIELDS)
end

-- Encoding ----------------------------------------------------------------------------------------------------------

local function Api()
    local api = C_EncodingUtil
    if type(api) ~= "table" then return nil end
    for _, name in ipairs({ "SerializeCBOR", "DeserializeCBOR", "CompressString", "DecompressString",
        "EncodeBase64", "DecodeBase64" }) do
        if type(api[name]) ~= "function" then return nil end
    end
    return api
end

-- Whether this client can read and write aura strings.
function Codec.Available()
    return Api() ~= nil
end

local function Pack(payload)
    local api = Api()
    if not api then return nil, Codec.ERR_ENCODER end
    local ok, data = pcall(api.SerializeCBOR, payload)
    if not ok or type(data) ~= "string" then return nil, Codec.ERR_ENCODER end
    ok, data = pcall(api.CompressString, data)
    if not ok or type(data) ~= "string" then return nil, Codec.ERR_ENCODER end
    ok, data = pcall(api.EncodeBase64, data)
    if not ok or type(data) ~= "string" then return nil, Codec.ERR_ENCODER end
    return PREFIX .. data
end

local function Unpack(text)
    local api = Api()
    if not api then return nil, Codec.ERR_ENCODER end
    if type(text) ~= "string" or #text > MAX_TEXT then return nil, Codec.ERR_PREFIX end
    text = text:gsub("%s", "")
    if text:sub(1, #PREFIX) ~= PREFIX then return nil, Codec.ERR_PREFIX end
    local ok, data = pcall(api.DecodeBase64, text:sub(#PREFIX + 1))
    if not ok or type(data) ~= "string" then return nil, Codec.ERR_DAMAGED end
    ok, data = pcall(api.DecompressString, data)
    if not ok or type(data) ~= "string" then return nil, Codec.ERR_DAMAGED end
    ok, data = pcall(api.DeserializeCBOR, data)
    if not ok or type(data) ~= "table" or data.kind ~= "auras" or not Number(data.v) or data.v > 1 then
        return nil, Codec.ERR_DAMAGED
    end
    if type(data.auras) ~= "table" then return nil, Codec.ERR_DAMAGED end
    return data
end

-- Export and import -------------------------------------------------------------------------------------------------

-- The string for the auras `ids` of `profile` and their groups, or nil and an error.
function Codec.Export(profile, ids)
    local auras = profile and profile.customAuras
    if type(auras) ~= "table" then return nil, Codec.ERR_NOTHING end
    local list, groups, count = {}, {}, 0
    for _, id in ipairs(ids or {}) do
        local conf = auras[id]
        if type(conf) == "table" and count < MAX_AURAS then
            local clean = Codec.CleanAura(conf)
            count = count + 1
            list[count] = clean
            local name = clean.group
            if name and type(profile.customGroups) == "table" and type(profile.customGroups[name]) == "table" then
                groups[name] = Codec.CleanGroup(profile.customGroups[name])
            end
        end
    end
    if count == 0 then return nil, Codec.ERR_NOTHING end
    return Pack({ kind = "auras", v = 1, client = Codec.Client(), auras = list, groups = groups })
end

local function NewID(auras)
    local stamp = type(GetTime) == "function" and tostring(GetTime()):gsub("%.", "") or "0"
    local base = "aura_" .. stamp
    local id, n = base, 1
    while auras[id] ~= nil do
        n = n + 1
        id = base .. "_" .. n
    end
    return id
end

-- Adds the string's auras to `profile` under new IDs. Returns the new IDs and a list of warnings, or nil and an error.
-- A group already in the profile keeps its own settings.
function Codec.Import(profile, text)
    if type(profile) ~= "table" then return nil, Codec.ERR_DAMAGED end
    local payload, err = Unpack(text)
    if not payload then return nil, err end

    if type(profile.customAuras) ~= "table" then profile.customAuras = {} end
    local auras = profile.customAuras
    local ids, warnings = {}, {}
    for _, conf in ipairs(payload.auras) do
        if #ids >= MAX_AURAS then break end
        if type(conf) == "table" then
            local id = NewID(auras)
            auras[id] = Codec.CleanAura(conf)
            ids[#ids + 1] = id
        end
    end
    if #ids == 0 then return nil, Codec.ERR_NOTHING end

    if type(payload.groups) == "table" then
        local added = 0
        for name, settings in pairs(payload.groups) do
            local clean = Text(40)(name)
            if clean and clean ~= "" and added < MAX_GROUPS then
                if type(profile.customGroups) ~= "table" then profile.customGroups = {} end
                if profile.customGroups[clean] == nil then
                    profile.customGroups[clean] = Codec.CleanGroup(settings)
                    added = added + 1
                end
            end
        end
    end

    if payload.client ~= nil and payload.client ~= Codec.Client() then
        warnings[#warnings + 1] = Codec.WARN_CLIENT
    end
    return ids, warnings
end
