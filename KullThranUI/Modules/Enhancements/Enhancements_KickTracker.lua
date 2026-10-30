-------------------------------------------------------------------------------
--  Kick Tracker: the group's interrupts on the enemy nameplates.
--
--  When a cast is stopped, the interrupter's icon goes beside the nameplate of
--  the enemy that was casting, and counts down that player's interrupt
--  cooldown. A bar list shows every member with an interrupt, their cooldown
--  and the raid marker of the enemy they last kicked.
--
--  Who kicked is read from whatever the client leaves readable, best first:
--    1. the interrupter carried by the interrupt event itself;
--    2. the group's interrupt counts (C_DamageMeter), when one member's count
--       goes up by exactly one while one nameplate is interrupted;
--    3. a member's interrupt cast (always readable for your own).
--  Secret values are never compared: a signal that comes back secret is
--  skipped. An interrupt that stops several casts at once is not placed.
--
--  Focus marker: pick a raid marker; on a ready check it is sent to the group
--  (KUI users read it, everyone else gets a party chat line if enabled). When
--  that marker lands on an enemy, the member's icon shows there before any kick.
--
--  Runs in Mythic and Mythic+ dungeons and in arenas only (or in test mode).
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
-- Events of one interrupt arrive within this window, in any order; pairing
-- waits RESOLVE_DELAY so every plate one kick stopped is in before deciding.
local MATCH_WINDOW = 0.6
local RESOLVE_DELAY = 0.15

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
        nameSize = 10, timeSize = 10, titleSize = 10,
        barTexture = "Melli Reforged", -- SharedMedia name (Defaults.lua)
        showBackground = true, backgroundAlpha = 0.82, showTitle = true, showBarIcon = true,
        classColors = true, lockBars = false,
        focusMarker = 0, announceChat = true,
    }
    for key, value in pairs(defaults) do
        if cfg[key] == nil then cfg[key] = value end
    end
    return cfg
end

-------------------------------------------------------------------------------
--  Interrupts: class -> default, spec -> override. Cooldowns in seconds
--  (base values; your own kick always uses its real cooldown).
-------------------------------------------------------------------------------
local SPELLS = {
    mindFreeze = { id = 47528, cd = 15 },
    disrupt = { id = 183752, cd = 15 },
    skullBash = { id = 106839, cd = 15 },
    solarBeam = { id = 78675, cd = 60 },
    quell = { id = 351338, cd = 20 },
    counterShot = { id = 147362, cd = 24 },
    muzzle = { id = 187707, cd = 15 },
    counterspell = { id = 2139, cd = 24 },
    spearHand = { id = 116705, cd = 15 },
    rebuke = { id = 96231, cd = 15 },
    silence = { id = 15487, cd = 45 },
    kick = { id = 1766, cd = 15 },
    windShear = { id = 57994, cd = 12 },
    spellLock = { id = 19647, cd = 24 },
    spellLockSacrifice = { id = 132409, cd = 24 },
    axeToss = { id = 89766, cd = 30 },
    pummel = { id = 6552, cd = 15 },
}

-- Class default, then the specs that differ (false = that spec has none).
local CLASS_INTERRUPTS = {
    DEATHKNIGHT = { default = "mindFreeze" },
    DEMONHUNTER = { default = "disrupt" },
    DRUID = { default = "skullBash", specs = { [102] = "solarBeam", [105] = false } },
    EVOKER = { default = "quell" },
    HUNTER = { default = "counterShot", specs = { [255] = "muzzle" } },
    MAGE = { default = "counterspell" },
    MONK = { default = "spearHand" },
    PALADIN = { default = "rebuke" },
    PRIEST = { default = false, specs = { [258] = "silence" } },
    ROGUE = { default = "kick" },
    SHAMAN = { default = "windShear" },
    WARLOCK = { default = "spellLock", specs = { [266] = "axeToss" } },
    WARRIOR = { default = "pummel" },
}

-- Every interrupt spell ID -> its key (a member's cast of one of these is a kick).
local SPELL_BY_ID = {}
for key, spell in pairs(SPELLS) do SPELL_BY_ID[spell.id] = key end

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
    lastCounts = {},    -- member key -> last readable interrupt count
    pendingPlates = {}, -- { unit, time, marker } interrupted plates not yet attributed
    pendingKicks = {},  -- { guid, time } members known to have kicked, not yet placed
    debug = false,
    test = false,
}

local function Now() return GetTime and GetTime() or 0 end

local function Debug(...)
    if Engine.debug and KT.Print then KT:Print("|cff66ccff[Kicks]|r", ...) end
end

-- Mythic / Mythic+ dungeons and arenas.
function Engine:IsActiveContext()
    if self.test then return true end
    if not _G.IsInInstance then return false end
    local inInstance, instanceType = _G.IsInInstance()
    if not inInstance then return false end
    if instanceType == "arena" then return true end
    if instanceType ~= "party" then return false end
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

-- Rebuilds the roster from the group (keeps cooldowns and focus markers).
function Engine:RefreshRoster()
    if self.test then return end
    local old = self.members
    self.members, self.order = {}, {}
    for _, unit in ipairs(GroupUnits()) do
        local guid = _G.UnitGUID and _G.UnitGUID(unit)
        local _, class = _G.UnitClass(unit)
        if Readable(guid) and Readable(class) then
            local specID = SpecOf(unit)
            local key, spell = InterruptFor(class, specID)
            if spell then
                local name = _G.UnitName and _G.UnitName(unit)
                local member = old[guid] or {}
                member.guid, member.unit, member.class, member.specID = guid, unit, class, specID
                member.name = Readable(name) and name or member.name or "?"
                member.spellKey, member.spellID, member.cd = key, spell.id, spell.cd
                member.isPlayer = unit == "player"
                member.readyAt = member.readyAt or 0
                self.members[guid] = member
                self.order[#self.order + 1] = guid
            end
        end
    end
    self:Changed()
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

local function Prune(list, now)
    for i = #list, 1, -1 do
        if now - list[i].time > MATCH_WINDOW then table.remove(list, i) end
    end
end

-- Pairs one known kicker with one interrupted plate when the window holds
-- exactly one of each; several plates at once are a pack and are not placed.
function Engine:Resolve(now)
    now = now or Now()
    Prune(self.pendingPlates, now)
    -- A kick that found no interrupted plate in time hit nothing placeable:
    -- its cooldown still starts.
    for i = #self.pendingKicks, 1, -1 do
        local kick = self.pendingKicks[i]
        if now - kick.time > MATCH_WINDOW then
            table.remove(self.pendingKicks, i)
            self:RecordKick(kick.guid, nil, kick.time)
        end
    end
    if #self.pendingKicks == 1 and #self.pendingPlates == 1 then
        local kick, plate = self.pendingKicks[1], self.pendingPlates[1]
        self.pendingKicks, self.pendingPlates = {}, {}
        return self:RecordKick(kick.guid, plate.unit, now)
    end
    if #self.pendingKicks >= 1 and #self.pendingPlates > 1 then
        -- One kick stopping a pack: start the cooldown, place nothing.
        for _, kick in ipairs(self.pendingKicks) do self:RecordKick(kick.guid, nil, now) end
        self.pendingKicks, self.pendingPlates = {}, {}
    end
    return false
end

-- Once the window closes, a kick with no interrupted plate (it missed or hit
-- no cast) still starts its cooldown.
function Engine:ScheduleExpiry()
    C_Timer.After(MATCH_WINDOW + 0.05, function() self:Resolve() end)
end

function Engine:ScheduleResolve()
    if self.resolveQueued then return end
    self.resolveQueued = true
    C_Timer.After(RESOLVE_DELAY, function()
        self.resolveQueued = nil
        self:Resolve()
    end)
end

local function IsNameplateUnit(unit)
    return type(unit) == "string" and unit:find("^nameplate%d+$") ~= nil
end

-- Signal: a nameplate's cast was interrupted (interruptedBy may be secret).
function Engine:OnPlateInterrupted(unit, interruptedBy, now)
    Debug("interrupt event:", IsSecret(unit) and "unit secret" or tostring(unit),
        IsSecret(interruptedBy) and "interrupter secret" or ("interrupter " .. tostring(interruptedBy)))
    if IsSecret(unit) or not IsNameplateUnit(unit) then return end
    now = now or Now()
    if Readable(interruptedBy) and self.members[interruptedBy] then
        Debug("signal: interrupter on the event")
        return self:RecordKick(interruptedBy, unit, now)
    end
    self.pendingPlates[#self.pendingPlates + 1] = { unit = unit, time = now }
    self:ScheduleResolve()
end

-- The member a unit belongs to: pets (Spell Lock) count for their owner.
local function OwnerUnit(unit)
    if unit == "pet" then return "player" end
    local index = type(unit) == "string" and unit:match("^partypet(%d)$")
    if index then return "party" .. index end
    return unit
end

-- Signal: a member cast their interrupt (readable for yourself, maybe for others).
function Engine:OnMemberCast(unit, spellID, now)
    if IsSecret(spellID) or not SPELL_BY_ID[spellID] then return end
    unit = OwnerUnit(unit)
    local guid = _G.UnitGUID and _G.UnitGUID(unit)
    if not (Readable(guid) and self.members[guid]) then return end
    now = now or Now()
    Debug("signal: interrupt cast", self.members[guid].name)
    self.pendingKicks[#self.pendingKicks + 1] = { guid = guid, time = now }
    self:ScheduleResolve()
    self:ScheduleExpiry()
end

-- Signal: the group's interrupt counts changed. Only readable counts are
-- compared; a jump of more than one is a pack and is not placed.
function Engine:OnCounts(sources, now)
    now = now or Now()
    for _, source in ipairs(sources or {}) do
        local amount = source.totalAmount
        local guid = source.sourceGUID
        if Readable(amount) and Readable(guid) and self.members[guid] then
            local last = self.lastCounts[guid]
            self.lastCounts[guid] = amount
            if last and amount > last then
                if amount - last == 1 then
                    Debug("signal: interrupt count", self.members[guid].name)
                    local already = false
                    for _, kick in ipairs(self.pendingKicks) do
                        if kick.guid == guid then already = true end
                    end
                    if not already then
                        self.pendingKicks[#self.pendingKicks + 1] = { guid = guid, time = now }
                        self:ScheduleExpiry()
                    end
                else
                    self:RecordKick(guid, nil, now)
                end
            end
        end
    end
    self:ScheduleResolve()
end

function Engine:ReadCounts()
    local api = _G.C_DamageMeter
    local enum = _G.Enum
    if not (api and api.GetCombatSessionFromType and enum and enum.DamageMeterSessionType and enum.DamageMeterType) then return end
    local ok, session = pcall(api.GetCombatSessionFromType, enum.DamageMeterSessionType.Current, enum.DamageMeterType.Interrupts)
    if ok and type(session) == "table" and not IsSecret(session.combatSources) then
        if self.debug then
            for _, source in ipairs(session.combatSources) do
                Debug("count:", IsSecret(source.totalAmount) and "secret" or tostring(source.totalAmount),
                    IsSecret(source.sourceGUID) and "(guid secret)" or "")
            end
        end
        self:OnCounts(session.combatSources)
    else
        Debug("counts unreadable")
    end
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
    self.plateKicks, self.pendingPlates, self.pendingKicks, self.lastCounts = {}, {}, {}, {}
    for _, member in pairs(self.members) do member.readyAt = 0; member.lastMarker = nil end
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
    "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED", "INSPECT_READY",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED",
    "DAMAGE_METER_COMBAT_SESSION_UPDATED", "NAME_PLATE_UNIT_REMOVED", "RAID_TARGET_UPDATE",
    "READY_CHECK", "CHAT_MSG_ADDON", "CHALLENGE_MODE_START", "PLAYER_REGEN_ENABLED",
}

local function UpdateRegistration()
    local on = Config().enable and Engine:IsActiveContext()
    for _, event in ipairs(EVENTS) do
        if on or event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
            pcall(events.RegisterEvent, events, event)
        else
            pcall(events.UnregisterEvent, events, event)
        end
    end
    Engine.active = on and true or false
    if on then Engine:RefreshRoster() else Engine:Changed() end
end

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then
        UpdateRegistration()
        if Engine.active and _G.NotifyInspect then
            -- Specs of the group (an interrupt can depend on it); one request is enough.
            for _, unit in ipairs(GroupUnits()) do
                if unit ~= "player" and _G.CanInspect and _G.CanInspect(unit) then pcall(_G.NotifyInspect, unit) break end
            end
        end
        return
    end
    if not Engine.active then return end
    if event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit, _, _, interruptedBy = ...
        Engine:OnPlateInterrupted(unit, interruptedBy)
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        local unit, _, _, interruptedBy = ...
        -- A channel that ends on its own has no interrupter.
        if interruptedBy ~= nil then Engine:OnPlateInterrupted(unit, interruptedBy) end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, _, spellID = ...
        if type(unit) == "string" and (unit == "player" or unit == "pet" or unit:find("^party%d$") or unit:find("^partypet%d$")) then
            Engine:OnMemberCast(unit, spellID)
        end
    elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        local meterType = ...
        local enum = _G.Enum and _G.Enum.DamageMeterType
        if Readable(meterType) and enum and meterType == enum.Interrupts then Engine:ReadCounts() end
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
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "INSPECT_READY" or event == "PLAYER_REGEN_ENABLED" then
        Engine:RefreshRoster()
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
    elseif msg == "test" then
        if Mod.KickTracker.StartTest then Mod.KickTracker.StartTest() end
    elseif msg == "stop" then
        if Mod.KickTracker.StopTest then Mod.KickTracker.StopTest() end
    else
        KT:Print("/ktkicks test | stop | debug")
    end
end

Mod.KickTracker = {
    Config = Config,
    Engine = Engine,
    InterruptFor = InterruptFor,
    SPELLS = SPELLS,
    Refresh = UpdateRegistration,
}
