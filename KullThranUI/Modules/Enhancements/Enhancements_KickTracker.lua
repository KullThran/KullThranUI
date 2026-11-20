-------------------------------------------------------------------------------
--  Kick Tracker: the group's interrupts on the enemy nameplates.
--
--  When a cast is stopped, the interrupter's icon goes beside the nameplate of
--  the enemy that was casting, and counts down that player's interrupt
--  cooldown. A bar list shows every member with an interrupt, their cooldown
--  and the raid marker of the enemy they last kicked.
--
--  Who kicked: in a dungeon nothing names another player's kick (the
--  interrupter on the event is hidden and their casts never arrive). The
--  game's damage meter does change in the frame a kick lands, and what it
--  shows stays readable: its Interrupts rows (class, spec icon, "you") in
--  count order, and how many enemy spells each member has kicked this fight.
--  The engine compares each meter update with the one before:
--    1. one member's list of kicked spells grew: that member;
--    2. a row appeared (a member's first kick) or moved up past another: the
--       member that row names, when only one can own it;
--    3. your own kick cast a moment before;
--    4. nothing visible changed but the stopped cast's spell is readable and
--       only one member has kicked that spell before: that member.
--  Each list entry learns its spell from the one plate kicked with it. Only
--  those proofs place a kick; anything else is left unplaced, never guessed.
--  A growth of several entries, or several casts stopped at once, is a crowd
--  control on a pack, not a kick. Hidden values are never compared.
--
--  Focus marker: pick a raid marker; on a ready check it is sent to the group
--  (KUI users read it, everyone else gets a party chat line if enabled). When
--  that marker lands on an enemy, the member's icon shows there before any kick.
--
--  Runs in Mythic and Mythic+ dungeons and in arenas only (on WoW Forever, in
--  every dungeon), or in test mode.
--  /ktkicks debug prints which signals the client is giving.
-------------------------------------------------------------------------------
local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then return end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then return end

local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local GetTime = _G.GetTime
local issecretvalue = _G.issecretvalue or function() return false end
local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring

local PREFIX = "KUIKICK"
-- A plate's stopped cast and the meter update of the kick land in the same
-- frame; this is the slack allowed between them.
local PAIR_WINDOW = 0.25
-- A landed kick this soon after your own kick cast is yours.
local OWN_WINDOW = 1.0
-- A modeled cooldown may be off by this much (talents) before it rules a
-- member out.
local READY_SLACK = 1.5

local function LText(text)
    if type(text) == "string" and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] then return L[text] end
    end
    return text
end

local function IsSecret(value)
    return value ~= nil and issecretvalue(value) == true
end

-- A value that is present and readable.
local function Readable(value)
    return value ~= nil and not IsSecret(value)
end

local function Config()
    local db = Mod.GetDB and Mod:GetDB() or nil
    local cfg
    if db then
        db.kickTracker = db.kickTracker or {}
        cfg = db.kickTracker
    else
        cfg = {}
    end
    local defaults = {
        enable = false, showIcons = true, showBars = true,
        iconSize = 26, iconSide = "RIGHT", iconX = 4, iconY = 0, iconTextSize = 0, iconBorder = 1.5,
        barWidth = 190, barHeight = 18, barScale = 1, barSpacing = 3,
        nameSize = 12, timeSize = 12, titleSize = 12,
        barTexture = "Melli Reforged", -- SharedMedia name (Defaults.lua)
        showBackground = true, backgroundAlpha = 0.82, showTitle = true, showBarIcon = true,
        classColors = true, lockBars = false,
        focusMarker = 0, announceChat = true,
    }
    -- The text grew by 2: saved profiles hold their sizes, so raise them once.
    if cfg.textSizeVersion == nil then
        for _, key in ipairs({ "nameSize", "timeSize", "titleSize" }) do
            if tonumber(cfg[key]) then cfg[key] = math.min(20, cfg[key] + 2) end
        end
        if (tonumber(cfg.iconTextSize) or 0) > 0 then cfg.iconTextSize = math.min(24, cfg.iconTextSize + 2) end
        cfg.textSizeVersion = 1
    end
    -- Per-client, per-resolution default (Modules/DefaultLayout.lua).
    if cfg.barsPosition == nil then cfg.barsPosition = KT:GetDefaultLayoutPosition("kickTracker") end
    for key, value in pairs(defaults) do
        if cfg[key] == nil then cfg[key] = value end
    end
    return cfg
end

-------------------------------------------------------------------------------
--  Interrupts: class -> default, spec -> override. Cooldowns in seconds,
--  base values of patch 12.1.5 (your own kick always uses its real cooldown).
--  Healers have none, except Restoration Shaman (a longer Wind Shear). A
--  Protection Paladin's Avenger's Shield also interrupts; the meter cannot
--  tell it from Rebuke, so the paladin is tracked by Rebuke alone.
-------------------------------------------------------------------------------
local SPELLS = {
    mindFreeze = { id = 47528, cd = 15 },
    disrupt = { id = 183752, cd = 15 },
    skullBash = { id = 106839, cd = 15 },
    solarBeam = { id = 78675, cd = 60 },
    quell = { id = 351338, cd = 20 },
    counterShot = { id = 147362, cd = 24 },
    muzzle = { id = 187707, cd = 15 },
    counterspell = { id = 2139, cd = 25 },
    spearHand = { id = 116705, cd = 15 },
    rebuke = { id = 96231, cd = 15 },
    silence = { id = 15487, cd = 30 },
    kick = { id = 1766, cd = 15 },
    windShear = { id = 57994, cd = 12 },
    windShearResto = { id = 57994, cd = 30 },
    spellLock = { id = 19647, cd = 24, pet = true },
    spellLockSacrifice = { id = 132409, cd = 24 },
    axeToss = { id = 89766, cd = 30, pet = true },
    pummel = { id = 6552, cd = 15 },
}

-- Class default, then the specs that differ (false = that spec has none).
local CLASS_INTERRUPTS = {
    DEATHKNIGHT = { default = "mindFreeze" },
    DEMONHUNTER = { default = "disrupt" },
    DRUID = { default = "skullBash", specs = { [102] = "solarBeam", [105] = false } },
    EVOKER = { default = "quell", specs = { [1468] = false } },
    HUNTER = { default = "counterShot", specs = { [255] = "muzzle" } },
    MAGE = { default = "counterspell" },
    MONK = { default = "spearHand", specs = { [270] = false } },
    PALADIN = { default = "rebuke", specs = { [65] = false } },
    PRIEST = { default = false, specs = { [258] = "silence" } },
    ROGUE = { default = "kick" },
    SHAMAN = { default = "windShear", specs = { [264] = "windShearResto" } },
    WARLOCK = { default = "spellLock", specs = { [266] = "axeToss" } },
    WARRIOR = { default = "pummel" },
}

-- A member whose spec is not known yet but who is in the healer role is read
-- as their class's healing spec.
local HEALER_SPEC = {
    PALADIN = 65,     -- Holy
    PRIEST = 257,     -- Holy (Discipline has none either)
    SHAMAN = 264,     -- Restoration
    DRUID = 105,      -- Restoration
    MONK = 270,       -- Mistweaver
    EVOKER = 1468,    -- Preservation
}

-- WoW Forever: its own interrupts, read from the Forever client's spell data
-- (build 1.60.1.70399: class skill lines and spell cooldowns). Every rank has
-- its own spell ID; `id` is the highest rank, the one whose icon shows. There
-- are no specializations here: each class has one interrupt, and a second one
-- (a warrior's Shield Bash, a druid's Skull Bash) is followed once you cast it.
-- A Felhunter's Spell Lock is a pet spell.
local IS_FOREVER = KT.IS_FOREVER == true
if IS_FOREVER then
    SPELLS = {
        kick = { ranks = { 1766, 1767, 1768, 1769 }, cd = 10 },
        pummel = { ranks = { 6552, 6554 }, cd = 10 },
        shieldBash = { ranks = { 72, 1671, 1672 }, cd = 12 },
        counterspell = { ranks = { 2139 }, cd = 30 },
        earthShock = { ranks = { 8042, 8044, 8045, 8046, 10412, 10413, 10414 }, cd = 6 },
        silence = { ranks = { 15487 }, cd = 45 },
        spellLock = { ranks = { 19244, 19647 }, cd = 30, pet = true },
        feralCharge = { ranks = { 1238122 }, cd = 15 },
        skullBash = { ranks = { 410176 }, cd = 10 },
        rebuke = { ranks = { 425609 }, cd = 15 },
    }
    for _, spell in pairs(SPELLS) do spell.id = spell.ranks[#spell.ranks] end
    CLASS_INTERRUPTS = {
        ROGUE = { default = "kick" },
        WARRIOR = { default = "pummel" },
        MAGE = { default = "counterspell" },
        SHAMAN = { default = "earthShock" },
        PRIEST = { default = "silence" },
        WARLOCK = { default = "spellLock" },
        DRUID = { default = "feralCharge" },
        PALADIN = { default = "rebuke" },
    }
    HEALER_SPEC = {}
end

-- The class each interrupt belongs to (a cast of another class's spell is
-- never a member's kick).
local SPELL_CLASS = { shieldBash = "WARRIOR", skullBash = "DRUID" }
for class, entry in pairs(CLASS_INTERRUPTS) do
    if entry.default then SPELL_CLASS[entry.default] = class end
    for _, key in pairs(entry.specs or {}) do
        if key then SPELL_CLASS[key] = class end
    end
end
SPELL_CLASS.spellLockSacrifice = "WARLOCK"

-- Every interrupt spell ID (every rank) -> its key: your cast of one of these
-- is a kick. Retail adds the warlock's Command Demon versions.
local SPELL_BY_ID = {}
for key, spell in pairs(SPELLS) do
    for _, id in ipairs(spell.ranks or { spell.id }) do
        if not SPELL_BY_ID[id] then SPELL_BY_ID[id] = key end
    end
end
if not IS_FOREVER then
    SPELL_BY_ID[119910] = "spellLock"
    SPELL_BY_ID[119914] = "axeToss"
end

-- The rank of an interrupt you know (the highest), for its real cooldown.
local function KnownRank(spell)
    local known = _G.IsPlayerSpell or _G.IsSpellKnown
    if not (spell.ranks and known) then return spell.id end
    for i = #spell.ranks, 1, -1 do
        if known(spell.ranks[i]) then return spell.ranks[i] end
    end
    return spell.id
end

-- The interrupt of a class / spec (nil when that spec has none).
local function InterruptFor(class, specID)
    local entry = CLASS_INTERRUPTS[class]
    if not entry then return nil end
    local key = entry.default
    if specID and entry.specs and entry.specs[specID] ~= nil then key = entry.specs[specID] end
    if not key then return nil end
    return key, SPELLS[key]
end

-------------------------------------------------------------------------------
--  State
-------------------------------------------------------------------------------
local Engine = {
    members = {},       -- guid -> member
    order = {},         -- guid list in roster order
    plateKicks = {},    -- nameplate unit -> { guid, ... } (kicks placed on that enemy)
    meter = { rows = {}, entries = {} }, -- the last meter read: row keys, guid -> kicked-spell count
    meterReadAt = -1,   -- GetTime() of that read (one per frame)
    evidence = nil,     -- what the last meter update changed, waiting for its plates
    batch = { plates = {}, spells = {}, at = -1 }, -- plates whose cast was just kicked
    ownAt = -1,         -- GetTime() of your last kick cast
    ownPending = false, -- that cast has not been matched to a landed kick yet
    specs = {},         -- guid -> specID (an inspected spec does not stay readable)
    inspected = {},     -- guid -> true, asked for already
    debug = false,
    test = false,
}

local function Now() return GetTime and GetTime() or 0 end

local function Debug(...)
    if Engine.debug and KT.Print then KT:Print("|cff66ccff[Kicks]|r", ...) end
end

-- Mythic / Mythic+ dungeons and arenas. WoW Forever has no Mythic
-- difficulty: there it runs in every dungeon.
function Engine:IsActiveContext()
    if self.test then return true end
    if not _G.IsInInstance then return false end
    local inInstance, instanceType = _G.IsInInstance()
    if not inInstance then return false end
    if instanceType == "arena" then return true end
    if instanceType ~= "party" then return false end
    if IS_FOREVER then return true end
    local difficultyID = select(3, _G.GetInstanceInfo())
    return difficultyID == 8 or difficultyID == 23
end

local function GroupUnits()
    local units = { "player" }
    local count = _G.GetNumSubgroupMembers and _G.GetNumSubgroupMembers() or 0
    for i = 1, math.min(4, count) do units[#units + 1] = "party" .. i end
    return units
end

local function SpecOf(unit)
    if unit == "player" then
        local index = _G.GetSpecialization and _G.GetSpecialization()
        local specID = index and _G.GetSpecializationInfo and _G.GetSpecializationInfo(index)
        return Readable(specID) and specID or nil
    end
    local specID = _G.GetInspectSpecialization and _G.GetInspectSpecialization(unit)
    if Readable(specID) and specID > 0 then return specID end
    return nil
end

-- The meter's rows name a spec by its icon: class ID -> { icon -> specID }.
local specOfIcon = {}
local function IconSpecs(classID)
    if not classID then return nil end
    local map = specOfIcon[classID]
    if map then return map end
    map = {}
    local count = _G.GetNumSpecializationsForClassID and _G.GetNumSpecializationsForClassID(classID) or 0
    for i = 1, count do
        local specID, _, _, icon = _G.GetSpecializationInfoForClassID(classID, i)
        if Readable(specID) and Readable(icon) then map[icon] = specID end
    end
    specOfIcon[classID] = map
    return map
end

local function IconOfSpec(classID, specID)
    for icon, id in pairs(IconSpecs(classID) or {}) do
        if id == specID then return icon end
    end
    return nil
end

-- Rebuilds the roster from the group (keeps cooldowns and focus markers).
function Engine:RefreshRoster()
    if self.test then return end
    local old = self.members
    self.members, self.order = {}, {}
    for _, unit in ipairs(GroupUnits()) do
        local guid = _G.UnitGUID and _G.UnitGUID(unit)
        local _, class, classID = _G.UnitClass(unit)
        if Readable(guid) and Readable(class) then
            local specID = SpecOf(unit) or self.specs[guid]
            self.specs[guid] = specID
            local role = _G.UnitGroupRolesAssigned and _G.UnitGroupRolesAssigned(unit)
            local readSpec = specID
            if not readSpec and role == "HEALER" then readSpec = HEALER_SPEC[class] end
            local key, spell = InterruptFor(class, readSpec)
            if spell then
                local name = _G.UnitName and _G.UnitName(unit)
                local member = old[guid] or {}
                member.guid, member.unit, member.class, member.specID = guid, unit, class, specID
                member.classID = Readable(classID) and classID or nil
                member.specIcon = specID and IconOfSpec(member.classID, specID) or nil
                member.name = Readable(name) and name or member.name or "?"
                member.isPlayer = unit == "player"
                -- Your second interrupt, once you cast it, stays yours.
                if member.isPlayer and member.castKey and SPELL_CLASS[member.castKey] == class and SPELLS[member.castKey] then
                    key, spell = member.castKey, SPELLS[member.castKey]
                end
                member.spellKey, member.cd = key, spell.cd
                member.spellID = member.isPlayer and KnownRank(spell) or spell.id
                member.readyAt = member.readyAt or 0
                self.members[guid] = member
                self.order[#self.order + 1] = guid
            end
        end
    end
    self:Changed()
end

-- Asks for the next spec the roster needs (classes whose interrupt depends on it),
-- one at a time: INSPECT_READY brings the following one.
function Engine:InspectNext()
    if not (_G.NotifyInspect and _G.CanInspect) then return end
    if _G.InspectFrame and _G.InspectFrame:IsShown() then return end
    for _, unit in ipairs(GroupUnits()) do
        local guid = _G.UnitGUID and _G.UnitGUID(unit)
        local _, class = _G.UnitClass(unit)
        local entry = Readable(class) and CLASS_INTERRUPTS[class]
        if unit ~= "player" and entry and (entry.specs or not entry.default) and Readable(guid)
            and not self.specs[guid] and not self.inspected[guid] and _G.CanInspect(unit) then
            self.inspected[guid] = true
            pcall(_G.NotifyInspect, unit)
            return
        end
    end
end

-- Seconds left on a member's interrupt (0 = ready). Your own reads the real cooldown.
function Engine:Remaining(member, now)
    now = now or Now()
    if member.isPlayer and not self.test and _G.C_Spell and _G.C_Spell.GetSpellCooldown then
        local info = _G.C_Spell.GetSpellCooldown(member.spellID)
        local start, duration = info and info.startTime, info and info.duration
        if Readable(start) and Readable(duration) and duration > 1.5 then
            return math.max(0, start + duration - now), duration
        end
    end
    return math.max(0, (member.readyAt or 0) - now), member.cd
end

-------------------------------------------------------------------------------
--  Placing kicks
-------------------------------------------------------------------------------
local function RemoveFromPlates(self, guid)
    for unit, list in pairs(self.plateKicks) do
        for i = #list, 1, -1 do
            if list[i] == guid then table.remove(list, i) end
        end
        if #list == 0 then self.plateKicks[unit] = nil end
    end
end

-- A member used their interrupt (cooldown starts) and, when known, on which plate.
function Engine:RecordKick(guid, unit, now)
    local member = self.members[guid]
    if not member then return false end
    now = now or Now()
    member.readyAt = now + (member.cd or 15)
    member.focusPending = nil
    if unit then
        RemoveFromPlates(self, guid)
        self.plateKicks[unit] = self.plateKicks[unit] or {}
        table.insert(self.plateKicks[unit], guid)
        local marker = _G.GetRaidTargetIndex and _G.GetRaidTargetIndex(unit)
        member.lastMarker = Readable(marker) and marker or nil
    end
    Debug("kick", member.name, unit or "(no plate)")
    self:Changed()
    return true
end

-- Still on cooldown from a kick that was theirs: it cannot be theirs again.
function Engine:StillDown(member, now)
    return (member.readyAt or 0) - now > READY_SLACK
end

function Engine:OwnPending(now)
    return self.ownPending and now >= self.ownAt and now - self.ownAt <= OWN_WINDOW
end

function Engine:PlayerGUID()
    for guid, member in pairs(self.members) do
        if member.isPlayer then return guid end
    end
    return nil
end

-------------------------------------------------------------------------------
--  The meter: rows and each member's list of kicked spells
-------------------------------------------------------------------------------
-- A row's key: class, spec icon and whether it is you ("?" where hidden).
local function RowKey(row)
    if type(row) ~= "table" or IsSecret(row) then return "?" end
    local class = IsSecret(row.classFilename) and "?" or tostring(row.classFilename or "-")
    local icon = IsSecret(row.specIconID) and "?" or tostring(row.specIconID or "-")
    local mine = (not IsSecret(row.isLocalPlayer)) and row.isLocalPlayer == true
    return class .. "|" .. icon .. (mine and "|me" or "")
end

local function MeterEnums()
    local api, enum = _G.C_DamageMeter, _G.Enum
    if not (api and api.GetCombatSessionFromType and enum and enum.DamageMeterSessionType and enum.DamageMeterType) then return nil end
    return api, enum.DamageMeterSessionType.Current, enum.DamageMeterType.Interrupts
end

-- How many enemy spells a source has kicked this fight (plain), or nil.
local function KickedSpells(api, session, kind, guid)
    if not (api.GetCombatSessionSourceFromType and Readable(guid)) then return nil end
    local ok, source = pcall(api.GetCombatSessionSourceFromType, session, kind, guid)
    if not (ok and type(source) == "table" and not IsSecret(source)) then return nil end
    local spells = source.combatSpells
    if type(spells) ~= "table" or IsSecret(spells) then return nil end
    return #spells
end

-- The member's demon, whose kicks the meter keeps as a source of its own.
local function DemonGUID(member)
    local spell = member.spellKey and SPELLS[member.spellKey]
    if not (spell and spell.pet) then return nil end
    local pet = member.unit == "player" and "pet" or (member.unit and member.unit:gsub("^party", "partypet"))
    local guid = pet and _G.UnitExists and _G.UnitExists(pet) and _G.UnitGUID(pet)
    return Readable(guid) and guid or nil
end

-- One read of the meter. A member that could not be read keeps the last count.
function Engine:ReadMeter()
    local read = { rows = {}, entries = {} }
    local api, session, kind = MeterEnums()
    if not api then return read end
    local ok, data = pcall(api.GetCombatSessionFromType, session, kind)
    local sources = ok and type(data) == "table" and not IsSecret(data) and data.combatSources
    if type(sources) == "table" and not IsSecret(sources) then
        for i, row in ipairs(sources) do read.rows[i] = RowKey(row) end
    end
    for guid, member in pairs(self.members) do
        local count = KickedSpells(api, session, kind, guid)
        local demon = DemonGUID(member)
        local demonCount = demon and KickedSpells(api, session, kind, demon)
        if count or demonCount then
            read.entries[guid] = (count or 0) + (demonCount or 0)
        else
            read.entries[guid] = self.meter.entries[guid]
        end
    end
    return read
end

-- What changed from one read to the next.
local function Compare(before, after)
    local change = { grown = {}, growth = {}, shrank = #after.rows < #before.rows }
    for guid, count in pairs(after.entries) do
        local was = before.entries[guid] or 0
        if count < was then
            change.shrank = true
        elseif count > was then
            change.grown[#change.grown + 1] = guid
            change.growth[guid] = count - was
        end
    end
    if #after.rows > #before.rows then
        local left = {}
        for _, key in ipairs(before.rows) do left[key] = (left[key] or 0) + 1 end
        change.newRows = 0
        for _, key in ipairs(after.rows) do
            if (left[key] or 0) > 0 then
                left[key] = left[key] - 1
            else
                change.rowKey, change.newRows = key, change.newRows + 1
            end
        end
        change.rowHow = "new row"
    elseif #after.rows == #before.rows then
        for i, key in ipairs(after.rows) do
            if key ~= before.rows[i] then
                change.rowKey, change.rowHow = key, "row moved"
                break
            end
        end
    end
    return change
end

-- Each member's list of kicked spells: `known` (spell -> true) and how many
-- entries are still `unknown` (they landed with no plate to name them).
function Engine:ForgetLists(read)
    for guid, member in pairs(self.members) do
        member.known, member.unknown = {}, read.entries[guid] or 0
    end
end

function Engine:GrowLists(before, after)
    for guid, member in pairs(self.members) do
        if not member.known then
            member.known, member.unknown = {}, after.entries[guid] or 0
        else
            local grew = (after.entries[guid] or 0) - (before.entries[guid] or 0)
            if grew > 0 then member.unknown = member.unknown + grew end
        end
    end
end

-- The members a row can belong to: of its class, with an interrupt, and of
-- its spec where both are known. A row marked "you" is yours.
function Engine:RowMembers(key)
    local list = {}
    local class, icon, mine = key:match("^([^|]+)|([^|]+)(|?m?e?)$")
    if mine == "|me" then
        local guid = self:PlayerGUID()
        if guid then list[1] = guid end
        return list
    end
    icon = tonumber(icon)
    for _, guid in ipairs(self.order) do
        local member = self.members[guid]
        if not member.isPlayer and member.class == class
            and (icon == nil or member.specIcon == nil or member.specIcon == icon) then
            list[#list + 1] = guid
        end
    end
    return list
end

-- A row named one member for sure: an unknown spec is read from its icon.
function Engine:LearnRow(guid, key)
    local member = self.members[guid]
    if not member or member.specID then return end
    local icon = tonumber(key:match("^[^|]+|([^|]+)"))
    local specID = icon and (IconSpecs(member.classID) or {})[icon]
    if specID then
        self.specs[guid] = specID
        self:RefreshRoster()
    end
end

-- Out of combat the rows' GUIDs are readable: every member's spec from them.
function Engine:LearnSpecs()
    local api, session, kind = MeterEnums()
    if not api then return end
    local ok, data = pcall(api.GetCombatSessionFromType, session, kind)
    local sources = ok and type(data) == "table" and not IsSecret(data) and data.combatSources
    if type(sources) ~= "table" or IsSecret(sources) then return end
    local changed = false
    for _, row in ipairs(sources) do
        local guid = type(row) == "table" and not IsSecret(row) and row.sourceGUID
        local member = Readable(guid) and self.members[guid]
        if member and not member.specID and Readable(row.specIconID) then
            local specID = (IconSpecs(member.classID) or {})[row.specIconID]
            if specID then self.specs[guid], changed = specID, true end
        end
    end
    if changed then self:RefreshRoster() end
end

-------------------------------------------------------------------------------
--  Deciding who kicked
-------------------------------------------------------------------------------
-- The meter updated. Read once per frame; a fall in any count is a new fight.
function Engine:OnMeterUpdate(now)
    now = now or Now()
    if self.meterReadAt == now then return end
    self.meterReadAt = now
    local before, after = self.meter, self:ReadMeter()
    local change = Compare(before, after)
    self.meter = after
    if self.debug then Debug("meter:", #after.rows, table.concat(after.rows, " ")) end
    if change.shrank then
        self:ForgetLists(after)
        return
    end
    self:GrowLists(before, after)
    if #change.grown == 0 and not change.rowKey then return end
    change.at = now
    self.evidence = change
    self:QueueSettle()
end

-- A new meter session (or a reset): a fresh baseline. A session update that
-- shows a kick is left to that kick's own update.
function Engine:Rebase(force)
    local after = self:ReadMeter()
    if not force then
        local change = Compare(self.meter, after)
        if not change.shrank and (#change.grown > 0 or change.rowKey) then return end
        if not change.shrank then
            self:GrowLists(self.meter, after)
            self.meter = after
            return
        end
    end
    self.meter = after
    self:ForgetLists(after)
end

local function IsNameplateUnit(unit)
    return type(unit) == "string" and unit:find("^nameplate%d+$") ~= nil
end

-- A plate's cast stopped. An interrupter (hidden or not) is a kick; none is a
-- stun, a death or the cast ending. Several plates in one batch are a pack.
function Engine:OnPlateInterrupted(unit, interruptedBy, now, spellID)
    if IsSecret(unit) or not IsNameplateUnit(unit) then return end
    Debug("interrupt event:", unit,
        IsSecret(interruptedBy) and "interrupter secret" or ("interrupter " .. tostring(interruptedBy)))
    if interruptedBy == nil or (not IsSecret(interruptedBy) and interruptedBy == "") then return end
    now = now or Now()
    if Readable(interruptedBy) and self.members[interruptedBy] then
        Debug("signal: interrupter on the event")
        if self.members[interruptedBy].isPlayer then self.ownPending = false end
        return self:RecordKick(interruptedBy, unit, now)
    end
    local batch = self.batch
    if batch.at < 0 or now - batch.at > PAIR_WINDOW then
        if #batch.plates > 0 then self:Decide(nil, batch) end
        self.batch = { plates = {}, spells = {}, at = now }
        batch = self.batch
    end
    for _, plate in ipairs(batch.plates) do
        if plate == unit then return end
    end
    batch.plates[#batch.plates + 1] = unit
    batch.spells[#batch.plates] = (type(spellID) == "number" and not IsSecret(spellID)) and spellID or false
    self:QueueSettle()
end

-- Decides at the end of the frame, once the plates and the meter of a kick
-- are both in; plates still waiting for the meter wait out PAIR_WINDOW.
function Engine:QueueSettle(delay)
    if self.settleQueued then return end
    self.settleQueued = true
    C_Timer.After(delay or 0, function()
        self.settleQueued = nil
        self:Settle()
    end)
end

function Engine:Settle()
    local now = Now()
    local change, batch = self.evidence, self.batch
    local hasPlates = #batch.plates > 0
    if change then
        self.evidence = nil
        local paired = hasPlates and math.abs(batch.at - change.at) <= PAIR_WINDOW
        if paired then self.batch = { plates = {}, spells = {}, at = -1 } end
        return self:Decide(change, paired and batch or nil)
    end
    if not hasPlates then return end
    local left = PAIR_WINDOW - (now - batch.at)
    if left > 0 then return self:QueueSettle(left + 0.01) end
    self.batch = { plates = {}, spells = {}, at = -1 }
    return self:Decide(nil, batch)
end

-- Nothing on the meter moved, so the kick repeated a spell its kicker had
-- kicked before: the one member whose list holds that spell, when no other
-- ready member's list could hold it (entries never named, or never read).
function Engine:Holder(spell, now)
    local holder
    for guid, member in pairs(self.members) do
        if not member.isPlayer and not self:StillDown(member, now) then
            local holds = member.known and member.known[spell]
            local mayHold = not member.known or (member.unknown or 0) > 0
            if holds then
                if holder then return nil end
                holder = guid
            elseif mayHold then
                return nil
            end
        end
    end
    return holder
end

function Engine:Decide(change, batch)
    local at = (change and change.at) or (batch and batch.at) or Now()
    local plates = batch and #batch.plates or 0
    local plate = plates == 1 and batch.plates[1] or nil
    local spell = plates == 1 and batch.spells[1] or nil
    local who, how
    if change and #change.grown == 1 then
        who, how = change.grown[1], "list grew"
        local member = self.members[who]
        if change.growth[who] > 1 or plates > 1 then
            Debug("several casts stopped at once: crowd control, not a kick")
            return false
        end
        if member.isPlayer then
            if not self:OwnPending(at) then Debug("yours without a kick cast: not a kick") return false end
        elseif self:StillDown(member, at) then
            Debug(member.name, "still on cooldown: not a kick")
            return false
        end
        if change.rowKey and (change.rowHow == "row moved" or change.newRows == 1) then self:LearnRow(who, change.rowKey) end
        if spell and member.known and (member.unknown or 0) > 0 then
            member.known[spell], member.unknown = true, member.unknown - 1
        end
    elseif change and #change.grown > 1 then
        -- Each of them kicked; which one stopped this plate is not known.
        for _, guid in ipairs(change.grown) do self:RecordKick(guid, nil, at) end
        Debug("several members kicked at once: cooldowns only")
        return false
    elseif change and change.rowKey then
        local list = self:RowMembers(change.rowKey)
        if #list == 1 then
            who, how = list[1], change.rowHow
            self:LearnRow(who, change.rowKey)
        end
    end
    if not who and plates > 0 and self:OwnPending(at) then who, how = self:PlayerGUID(), "your cast" end
    if not who and spell then
        who = self:Holder(spell, at)
        how = who and "spell kicked before" or nil
    end
    if not who then
        Debug("kicker unknown: nothing placed")
        return false
    end
    local member = self.members[who]
    if not member then return false end
    if member.isPlayer then
        self.ownPending = false
        at = math.min(at, self.ownAt >= 0 and self.ownAt or at)
    end
    Debug("signal:", how, member.name)
    return self:RecordKick(who, plate, at)
end

-- The member a unit belongs to: pets (Spell Lock) count for their owner.
local function OwnerUnit(unit)
    if unit == "pet" then return "player" end
    return unit
end

-- Your own kick (or your demon's): its cooldown starts now; the plate comes
-- with the landed kick.
function Engine:OnOwnCast(unit, spellID, now)
    if IsSecret(spellID) or not SPELL_BY_ID[spellID] then return end
    local guid = _G.UnitGUID and _G.UnitGUID(OwnerUnit(unit))
    local member = Readable(guid) and self.members[guid]
    if not member then return end
    local key = SPELL_BY_ID[spellID]
    if key ~= member.spellKey and SPELL_CLASS[key] == member.class and SPELLS[key] then
        -- Your other interrupt (Shield Bash, Skull Bash): track that one now.
        member.castKey, member.spellKey, member.cd = key, key, SPELLS[key].cd
        member.spellID = spellID
    end
    now = now or Now()
    self.ownAt, self.ownPending = now, true
    Debug("signal: your kick cast")
    member.readyAt = now + (member.cd or 15)
    self:Changed()
end

function Engine:OnPlateRemoved(unit)
    if self.plateKicks[unit] then
        self.plateKicks[unit] = nil
        self:Changed()
    end
end

-- The kickers on a plate, ready ones first (nearest the plate), then by time left.
function Engine:PlateIcons(unit, now)
    now = now or Now()
    local list = {}
    for _, guid in ipairs(self.plateKicks[unit] or {}) do
        local member = self.members[guid]
        if member then list[#list + 1] = member end
    end
    -- Focus markers: members who announced this plate's marker and have not kicked yet.
    local marker = _G.GetRaidTargetIndex and _G.GetRaidTargetIndex(unit)
    if Readable(marker) and marker > 0 then
        for _, guid in ipairs(self.order) do
            local member = self.members[guid]
            if member and member.focusMarker == marker and member.focusPending then
                local present = false
                for _, m in ipairs(list) do if m == member then present = true end end
                if not present then list[#list + 1] = member end
            end
        end
    end
    table.sort(list, function(a, b)
        local ra, rb = self:Remaining(a, now), self:Remaining(b, now)
        if (ra == 0) ~= (rb == 0) then return ra == 0 end
        if ra ~= rb then return ra < rb end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

function Engine:Members()
    local list = {}
    for _, guid in ipairs(self.order) do list[#list + 1] = self.members[guid] end
    return list
end

function Engine:Reset()
    self.plateKicks, self.evidence = {}, nil
    self.batch = { plates = {}, spells = {}, at = -1 }
    self.ownAt, self.ownPending = -1, false
    for _, member in pairs(self.members) do member.readyAt = 0; member.lastMarker = nil end
    self:Rebase(true)
    self:Changed()
end

-- The UI sets this; the engine calls it after any change.
function Engine:Changed()
    if self.onChanged then self.onChanged() end
end

-------------------------------------------------------------------------------
--  Focus marker announce
-------------------------------------------------------------------------------
local MARKER_ICONS = {}
for i = 1, 8 do MARKER_ICONS[i] = "{rt" .. i .. "}" end

function Engine:SetFocusMarker(guid, marker)
    local member = self.members[guid]
    if not member then return end
    marker = tonumber(marker) or 0
    member.focusMarker = marker > 0 and marker or nil
    member.focusPending = marker > 0 or nil
    self:Changed()
end

function Engine:AnnounceFocus()
    local marker = tonumber(Config().focusMarker) or 0
    if marker <= 0 or not (_G.IsInGroup and _G.IsInGroup()) then return end
    local playerGUID = _G.UnitGUID and _G.UnitGUID("player")
    if Readable(playerGUID) then self:SetFocusMarker(playerGUID, marker) end
    if _G.C_ChatInfo and _G.C_ChatInfo.SendAddonMessage then
        pcall(_G.C_ChatInfo.SendAddonMessage, PREFIX, "F:" .. marker, "PARTY")
    end
    if Config().announceChat and _G.SendChatMessage then
        pcall(_G.SendChatMessage, string.format(LText("My kick: %s"), MARKER_ICONS[marker]), "PARTY")
    end
end

function Engine:OnAddonMessage(message, sender)
    if IsSecret(message) or type(message) ~= "string" then return end
    local marker = message:match("^F:(%d)$")
    if not marker then return end
    for _, member in pairs(self.members) do
        local name = member.unit and _G.UnitName and _G.UnitName(member.unit)
        local full = member.unit and _G.GetUnitName and _G.GetUnitName(member.unit, true)
        if Readable(name) and (sender == name or sender == full or (type(sender) == "string" and sender:match("^[^-]+") == name)) then
            self:SetFocusMarker(member.guid, marker)
        end
    end
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local events = CreateFrame("Frame")
local EVENTS = {
    -- roster and specs
    "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "INSPECT_READY", "PLAYER_REGEN_ENABLED",
    -- enemy casts stopped
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_EMPOWER_STOP", "NAME_PLATE_UNIT_REMOVED",
    -- the damage meter
    "DAMAGE_METER_RESET", "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
    -- markers and the group
    "RAID_TARGET_UPDATE", "READY_CHECK", "CHAT_MSG_ADDON", "CHALLENGE_MODE_START",
}

local function UpdateRegistration()
    local on = Config().enable and Engine:IsActiveContext()
    local wasActive = Engine.active
    for _, event in ipairs(EVENTS) do
        if on or event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
            pcall(events.RegisterEvent, events, event)
        else
            pcall(events.UnregisterEvent, events, event)
        end
    end
    -- Only your own casts (and your demon's) are ever heard.
    if on and events.RegisterUnitEvent then
        pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player", "pet")
    else
        pcall(events.UnregisterEvent, events, "UNIT_SPELLCAST_SUCCEEDED")
    end
    Engine.active = on and true or false
    if on then
        Engine:RefreshRoster()
        if not wasActive then Engine:Rebase(true) end
    else
        Engine:Changed()
    end
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        UpdateRegistration()
        if event == "PLAYER_ENTERING_WORLD" then Engine.inspected = {} end
        if Engine.active then Engine:InspectNext() end
        return
    end
    if not Engine.active then return end
    if event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        -- A channel that ends on its own has no interrupter.
        local unit, _, spellID, interruptedBy = ...
        Engine:OnPlateInterrupted(unit, interruptedBy, nil, spellID)
    elseif event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        local unit, _, spellID, _, interruptedBy = ...
        Engine:OnPlateInterrupted(unit, interruptedBy, nil, spellID)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if unit == "player" or unit == "pet" then Engine:OnOwnCast(unit, spellID) end
    elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        local meterType = ...
        local enum = _G.Enum and _G.Enum.DamageMeterType
        if Readable(meterType) and enum and meterType == enum.Interrupts then Engine:OnMeterUpdate() end
    elseif event == "DAMAGE_METER_CURRENT_SESSION_UPDATED" then
        Engine:Rebase(false)
    elseif event == "DAMAGE_METER_RESET" then
        Engine:Rebase(true)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Engine:OnPlateRemoved(...)
    elseif event == "RAID_TARGET_UPDATE" then
        Engine:Changed()
    elseif event == "READY_CHECK" then
        Engine:AnnounceFocus()
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, _, sender = ...
        if prefix == PREFIX then Engine:OnAddonMessage(message, sender) end
    elseif event == "CHALLENGE_MODE_START" then
        Engine:Reset()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        local unit = ...
        local guid = Readable(unit) and _G.UnitGUID and _G.UnitGUID(unit)
        if Readable(guid) then Engine.specs[guid], Engine.inspected[guid] = nil, nil end
        Engine:RefreshRoster()
        Engine:InspectNext()
    elseif event == "INSPECT_READY" then
        Engine:RefreshRoster()
        Engine:InspectNext()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Whoever was out of range gets another try; the meter's GUIDs are
        -- readable again and name the specs still unknown.
        Engine.inspected = {}
        Engine:RefreshRoster()
        Engine:LearnSpecs()
        Engine:InspectNext()
    end
end)
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE" }) do events:RegisterEvent(event) end
if _G.C_ChatInfo and _G.C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(_G.C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
end

_G.SLASH_KTKICKS1 = "/ktkicks"
_G.SlashCmdList.KTKICKS = function(msg)
    msg = type(msg) == "string" and msg:lower() or ""
    if msg == "debug" then
        Engine.debug = not Engine.debug
        KT:Print(LText("Kick Tracker debug:"), Engine.debug and "on" or "off")
        if Engine.debug then
            for _, unit in ipairs(GroupUnits()) do
                local name, guid = _G.UnitName(unit), _G.UnitGUID(unit)
                local _, class = _G.UnitClass(unit)
                Debug(unit, Readable(name) and name or "name secret", Readable(class) and class or "class secret",
                    Readable(guid) and (Engine.members[guid] and "tracked" or "not tracked") or "guid secret")
            end
        end
    elseif msg == "test" then
        if Mod.KickTracker.StartTest then Mod.KickTracker.StartTest() end
    elseif msg == "stop" then
        if Mod.KickTracker.StopTest then Mod.KickTracker.StopTest() end
    else
        KT:Print(LText("Usage: /ktkicks test | stop | debug"))
    end
end

Mod.KickTracker = {
    Config = Config,
    Engine = Engine,
    InterruptFor = InterruptFor,
    SPELLS = SPELLS,
    Refresh = UpdateRegistration,
}
