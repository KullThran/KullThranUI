-- Aura Reminders, aura reads: whether the player, or someone in the group, has a buff. Runs in combat under secret
-- value rules. An aura value may be a secret, so it is only stored, returned, tested against nil or given to
-- issecretvalue, and its fields are read only after that test says it is not secret.
-- One text for both clients. Every client difference is chosen once, at Setup, from ctx.client.

local _, ns = ...

local pcall, type, pairs, error = pcall, type, pairs, error
local gsub = string.gsub

local AuraRead = {}
ns.AuraRemindersAuraRead = AuraRead

-- The two game-fact IDs of the own-buff snapshot, as one-entry lists.
local SOURCE_OF_MAGIC, BLISTERING_SCALES = 369459, 360827
local SOURCE_OF_MAGIC_LIST, BLISTERING_SCALES_LIST = { SOURCE_OF_MAGIC }, { BLISTERING_SCALES }

-- Set at Setup, and the same tables for the session.
local nonSecretSpellIDs, preCombatAuraCache, preCombatOwnCache
local preCombatNameCache   -- Forever only: normalised name to boolean, private
local SafeSpellInfo        -- Forever only

-- Forever only: the answer of the last player test of a spell list in which every read was readable, keyed by the
-- list. While auras are secret a missing read falls back to it, so a buff up before the restriction began stays up.
-- Weak keys: lists built on the fly do not pile up.
local lastKnown = setmetatable({}, { __mode = "k" })

-- Expiry ------------------------------------------------------------------------------------------------------------
-- A buff the snapshot (or the last readable pass) saw up stands in for the live read while auras are secret. It
-- must not outlive the buff: when it was seen, its end time and instance were kept, so a buff that runs out or is
-- removed during the fight is missing again at once instead of after combat.
local EXPIRY_SLACK = 0.2                                     -- the removal and the clock may differ by a frame
local expiryByID = {}                                        -- spellID -> end time (GetTime), when it has one
local expiryByName = {}                                      -- normalised name -> end time (Forever)
local goneByID = {}                                          -- spellID -> true once its seen instance was removed
local goneByName = {}                                        -- normalised name -> the same, for the name entries (Forever)
local spellByInstance = {}                                   -- auraInstanceID -> spellID of a buff seen up
local lastKnownExpiry = setmetatable({}, { __mode = "k" })   -- list -> end time of the buff that answered it

-- The end time of a readable aura, or nil (none, unknown or secret).
local function readExpiry(aura)
    local isSecret = issecretvalue
    if type(aura) ~= "table" or (isSecret and isSecret(aura)) then return nil end
    local ends = aura.expirationTime
    if isSecret and isSecret(ends) then return nil end
    if type(ends) == "number" and ends > 0 then return ends end
    return nil
end

local function readInstance(aura)
    local isSecret = issecretvalue
    if type(aura) ~= "table" or (isSecret and isSecret(aura)) then return nil end
    local id = aura.auraInstanceID
    if isSecret and isSecret(id) then return nil end
    return id
end

local function expired(ends)
    return ends ~= nil and GetTime() >= ends - EXPIRY_SLACK
end

-- Records the end time and instance of a buff seen up.
local function rememberSeen(spellID, aura)
    expiryByID[spellID] = readExpiry(aura)
    goneByID[spellID] = nil
    local instance = readInstance(aura)
    if instance ~= nil then spellByInstance[instance] = spellID end
end

-- Whether a buff the snapshot saw up can still be up.
local function stillUp(spellID)
    return not goneByID[spellID] and not expired(expiryByID[spellID])
end

local function listGone(spellIDs)
    for i = 1, #spellIDs do
        if goneByID[spellIDs[i]] then return true end
    end
    return false
end

-- The client's versions, chosen at Setup, used by the shared tests below.
local readByID, unitHasBuff

-- Forever secrecy -----------------------------------------------------------------------------------------------

-- Whether aura reads can come back empty for a present aura now. The client says so (C_Secrets), also outside
-- combat (an instance); combat lockdown always counts. An error or a secret answer counts as secret.
local function aurasSecret()
    if InCombatLockdown and InCombatLockdown() then return true end
    local api = C_Secrets
    local should = api and api.ShouldAurasBeSecret
    if type(should) ~= "function" then return false end
    local ok, secret = pcall(should)
    if not ok then return true end
    local isSecret = issecretvalue
    if isSecret and isSecret(secret) then return true end
    return secret and true or false
end

-- A spell the client flags as never secret is read the same under the restriction, so its absence there is an
-- answer too. The level does not change during a session; cached per ID.
local neverSecret = {}
local function absenceReadable(spellID)
    local known = neverSecret[spellID]
    if known ~= nil then return known end
    known = false
    local api = C_Secrets
    local get = api and api.GetSpellAuraSecrecy
    if type(get) == "function" then
        local ok, level = pcall(get, spellID)
        local isSecret = issecretvalue
        local levels = Enum and Enum.SecrecyLevel
        local never = (levels and levels.NeverSecret) or 0
        known = ok and not (isSecret and isSecret(level)) and level == never
    end
    neverSecret[spellID] = known
    return known
end

-- Retail reads ------------------------------------------------------------------------------------------------------

-- A first lookup that answers is final, nil included. The name path runs only after a raise or an absent field.
local function byIDRetail(unit, spellID)
    if not unit or not spellID then return nil, false end

    local api = C_UnitAuras
    if not api then return nil, false end

    local ok, aura
    if unit == "player" then
        local read = api.GetPlayerAuraBySpellID
        if read then ok, aura = pcall(read, spellID) end
    else
        local read = api.GetUnitAuraBySpellID
        if read then ok, aura = pcall(read, unit, spellID) end
    end
    if ok then return aura, true end

    -- Not protected (G6). The name's secret test comes before anything else touches it.
    local spellApi = C_Spell
    local getName = spellApi and spellApi.GetSpellName
    local name = getName and getName(spellID)
    if not issecretvalue(name) and name then
        local readByName = api.GetAuraDataBySpellName
        if readByName then
            local named, found = pcall(readByName, unit, name, "HELPFUL")
            if named then return found, true end
        end
    end
    return nil, false
end

-- A secret name reaches the API, whose raise is caught. A nil unit is answered here instead of reaching it.
local function byNameRetail(unit, name)
    if not name or unit == nil then return nil, false end
    local api = C_UnitAuras
    local read = api and api.GetAuraDataBySpellName
    if not read then return nil, false end
    local ok, aura = pcall(read, unit, name, "HELPFUL")
    if ok then return aura, true end
    return nil, false
end

-- Forever reads -----------------------------------------------------------------------------------------------------

-- Removes a rank suffix. A secret string raises at the first gsub (G11).
local function normalizeName(name)
    if type(name) ~= "string" then return nil end
    return (gsub(gsub(name, "%s*%(Rank%s*%d+%)%s*$", ""), "%s+[Rr]ank%s*%d+%s*$", ""))
end

-- Secret test first, then the exact lookup, the finder and, while auras are readable, the UnitAura walk. Absent
-- while auras are secret is unreadable.
local function byNameForever(unit, name)
    local isSecret = issecretvalue
    if isSecret and isSecret(name) then return nil, false end
    if not unit or not name then return nil, false end

    local api = C_UnitAuras
    local read = api and api.GetAuraDataBySpellName
    if type(read) == "function" then
        local ok, aura = pcall(read, unit, name, "HELPFUL")
        if ok and aura ~= nil then return aura, true end
    end

    local util = AuraUtil
    local finder = util and util.FindAuraByName
    if type(finder) == "function" then
        local ok, found = pcall(finder, name, unit, "HELPFUL")
        if ok and found ~= nil then return found, true end
    end

    local secret = aurasSecret()
    local walk = UnitAura
    if type(walk) == "function" and not secret then
        local wanted = normalizeName(name)
        for index = 1, 40 do
            local ok, auraName = pcall(walk, unit, index, "HELPFUL")
            if not ok or auraName == nil then break end
            if auraName == name or (wanted and normalizeName(auraName) == wanted) then
                return true, true
            end
        end
    end
    return nil, not secret
end

-- Exact lookup, name path, then the finder, or with no finder the walk while auras are readable. Absent while auras
-- are secret is unreadable, unless the spell is never secret. namesSeen (optional) holds the names a caller already
-- found absent in this pass: the ranks of a spell share one name, which is then looked up once.
local function byIDForever(unit, spellID, namesSeen)
    if not unit or not spellID then return nil, false end

    local api, util = C_UnitAuras, AuraUtil
    if not api and not util and type(UnitAura) ~= "function" then return nil, false end

    if api then
        local ok, aura
        if unit == "player" then
            local read = api.GetPlayerAuraBySpellID
            if type(read) == "function" then ok, aura = pcall(read, spellID) end
        else
            local read = api.GetUnitAuraBySpellID
            if type(read) == "function" then ok, aura = pcall(read, unit, spellID) end
        end
        if ok and aura ~= nil then return aura, true end
    end

    local info = SafeSpellInfo(spellID)
    local name = info and info.name
    if name then
        local isSecret = issecretvalue
        if not (isSecret and isSecret(name)) then
            if namesSeen and namesSeen[name] then return nil, true end
            local aura, readable = byNameForever(unit, name)
            if aura ~= nil then return aura, true end
            if readable then
                if namesSeen then namesSeen[name] = true end
                return nil, true
            end
        end
    end

    local finder = util and util.FindAuraBySpellID
    local hasFinder = type(finder) == "function"
    if hasFinder then
        local ok, found = pcall(finder, spellID, unit, "HELPFUL")
        if ok and found ~= nil then return found, true end
    end

    local secret = aurasSecret()
    local walk = UnitAura
    if not hasFinder and type(walk) == "function" and not secret then
        local isSecret = issecretvalue
        for index = 1, 40 do
            local ok, auraName, _, _, _, _, _, source, _, _, foundID = pcall(walk, unit, index, "HELPFUL")
            if not ok or auraName == nil then break end
            if not (isSecret and isSecret(foundID)) and foundID == spellID then
                return { sourceUnit = source }, true
            end
        end
    end
    return nil, not secret or absenceReadable(spellID)
end

-- Player and plain unit tests ---------------------------------------------------------------------------------------

local function playerHasRetail(spellIDs)
    if not spellIDs or spellIDs[1] == nil then return true end
    local inCombat = InCombatLockdown and InCombatLockdown()
    local cache = preCombatAuraCache
    for i = 1, #spellIDs do
        local spellID = spellIDs[i]
        local aura, readable = byIDRetail("player", spellID)
        if readable then
            if aura ~= nil then return true end
            if inCombat and cache[spellID] and stillUp(spellID) then return true end
        elseif cache[spellID] and stillUp(spellID) then
            return true
        end
    end
    return false
end

-- Unreadable decides, not combat. The ID entry, then the entry of the normalised name, untested for secrecy (G11).
-- A pass in which every read was readable is remembered for the list; with an unreadable read and no entry, the
-- last such answer stands: a buff seen before auras turned secret is not reported missing.
local namesSeen = {}
local function playerHasForever(spellIDs)
    if not spellIDs or spellIDs[1] == nil then return true end
    local cache = preCombatAuraCache
    local allReadable = true
    wipe(namesSeen)
    for i = 1, #spellIDs do
        local spellID = spellIDs[i]
        local aura, readable = byIDForever("player", spellID, namesSeen)
        if readable then
            if aura ~= nil then
                lastKnown[spellIDs] = true
                lastKnownExpiry[spellIDs] = readExpiry(aura)
                rememberSeen(spellID, aura)
                return true
            end
        elseif cache[spellID] and stillUp(spellID) then
            return true
        else
            allReadable = false
            local info = SafeSpellInfo(spellID)
            local key = info and normalizeName(info.name)
            if key and preCombatNameCache[key] and not goneByName[key] and not expired(expiryByName[key]) then
                return true
            end
        end
    end
    if allReadable then
        lastKnown[spellIDs] = false
        return false
    end
    return lastKnown[spellIDs] == true and not expired(lastKnownExpiry[spellIDs]) and not listGone(spellIDs)
end

-- The name entry key of a spell (Forever), or nil.
local function nameKeyOf(spellID)
    if not SafeSpellInfo then return nil end
    local info = SafeSpellInfo(spellID)
    local name = info and info.name
    local isSecret = issecretvalue
    if isSecret and isSecret(name) then return nil end
    return normalizeName(name)
end

-- A cast of the buff while auras are secret (the player's own spell ID is readable): the list counts as up until a
-- readable pass says otherwise. Its new end time is unknown, so none is kept.
local function markPresent(spellIDs)
    if not spellIDs then return end
    lastKnown[spellIDs] = true
    lastKnownExpiry[spellIDs] = nil
    for i = 1, #spellIDs do
        expiryByID[spellIDs[i]] = nil
        goneByID[spellIDs[i]] = nil
        local key = nameKeyOf(spellIDs[i])
        if key then goneByName[key], expiryByName[key] = nil, nil end
    end
end

-- A list of the update that can be walked: Forever hands the whole list over as a secret table in combat, and
-- even its length must not be read then (the read raises and taints). A secret list is skipped: the end time
-- still decides for that buff.
local function readableList(list)
    local isSecret = issecretvalue
    if type(list) ~= "table" or (isSecret and isSecret(list)) then return nil end
    return list
end

-- A player UNIT_AURA during the restriction: a removed instance of a buff seen up makes it missing; an updated one
-- (refreshed) has an unknown new end; an added readable one is seen up again. Secret fields are skipped.
local function noteAuraUpdate(updateInfo)
    local isSecret = issecretvalue
    if type(updateInfo) ~= "table" or (isSecret and isSecret(updateInfo)) then return end
    local removed = readableList(updateInfo.removedAuraInstanceIDs)
    if removed then
        for i = 1, #removed do
            local id = removed[i]
            if not (isSecret and isSecret(id)) and spellByInstance[id] then
                local spellID = spellByInstance[id]
                goneByID[spellID] = true
                local key = nameKeyOf(spellID)
                if key then goneByName[key] = true end
                spellByInstance[id] = nil
            end
        end
    end
    local updated = readableList(updateInfo.updatedAuraInstanceIDs)
    if updated then
        for i = 1, #updated do
            local id = updated[i]
            local spellID = not (isSecret and isSecret(id)) and spellByInstance[id]
            if spellID then
                expiryByID[spellID] = nil
                for list in pairs(lastKnownExpiry) do
                    for j = 1, #list do
                        if list[j] == spellID then lastKnownExpiry[list] = nil break end
                    end
                end
            end
        end
    end
    local added = readableList(updateInfo.addedAuras)
    if added then
        for i = 1, #added do
            local aura = added[i]
            if type(aura) == "table" and not (isSecret and isSecret(aura)) then
                local spellID = aura.spellId
                if not (isSecret and isSecret(spellID)) and spellID and nonSecretSpellIDs[spellID] then
                    rememberSeen(spellID, aura)
                    local key = nameKeyOf(spellID)
                    if key then goneByName[key], expiryByName[key] = nil, readExpiry(aura) end
                end
            end
        end
    end
end

-- The soonest end time still ahead among the buffs seen up, for a refresh when it comes.
local function nextExpiry()
    local now, soonest
    local function consider(ends)
        now = now or GetTime()
        if ends > now and (not soonest or ends < soonest) then soonest = ends end
    end
    for _, ends in pairs(expiryByID) do consider(ends) end
    for _, ends in pairs(expiryByName) do consider(ends) end
    for list, ends in pairs(lastKnownExpiry) do
        if lastKnown[list] == true then consider(ends) end
    end
    return soonest
end

-- Snapshot only for the literal player token, when unreadable or in combat.
local function unitHasRetail(unit, spellIDs)
    local isPlayer = unit == "player"
    local inCombat = isPlayer and InCombatLockdown and InCombatLockdown()
    local cache = preCombatAuraCache
    for i = 1, #spellIDs do
        local spellID = spellIDs[i]
        local aura, readable = byIDRetail(unit, spellID)
        if readable then
            if aura ~= nil then return true end
            if inCombat and cache[spellID] then return true end
        elseif isPlayer and cache[spellID] then
            return true
        end
    end
    return false
end

-- Snapshot only for the literal player token, when unreadable. Name entries are not consulted (G4).
local function unitHasForever(unit, spellIDs)
    local isPlayer = unit == "player"
    local cache = preCombatAuraCache
    for i = 1, #spellIDs do
        local spellID = spellIDs[i]
        local aura, readable = byIDForever(unit, spellID)
        if readable then
            if aura ~= nil then return true end
        elseif isPlayer and cache[spellID] then
            return true
        end
    end
    return false
end

-- Credit rule -------------------------------------------------------------------------------------------------------

-- Readable and present, then credited to the player: secret aura, flag, caster, then lean to yes out of combat.
local function unitHasOwnBuff(unit, spellIDs)
    for i = 1, #spellIDs do
        local aura, readable = readByID(unit, spellIDs[i])
        if readable then
            if issecretvalue(aura) then return true end
            if aura ~= nil then
                local fromPlayer = aura.isFromPlayerOrPlayerPet
                if not issecretvalue(fromPlayer) and fromPlayer == true then return true end
                local caster = aura.sourceUnit
                if not issecretvalue(caster) and caster and UnitIsUnit(caster, "player") then return true end
                -- Out of combat, lean to yes only when the caster cannot be read: a known other caster is not ours.
                local unknown = issecretvalue(fromPlayer) or issecretvalue(caster) or caster == nil
                if unknown and not (InCombatLockdown and InCombatLockdown()) then return true end
            end
        end
    end
    return false
end

-- Out of combat only. No lean to yes and no flag here (G9).
local function playerHasSelfCast(spellIDs)
    if not spellIDs or spellIDs[1] == nil then return true end
    if InCombatLockdown and InCombatLockdown() then return false end
    for i = 1, #spellIDs do
        local aura, readable = readByID("player", spellIDs[i])
        if readable then
            if issecretvalue(aura) then return true end
            if aura ~= nil then
                local caster = aura.sourceUnit
                if issecretvalue(caster) then return true end
                if caster and UnitIsUnit(caster, "player") then return true end
            end
        end
    end
    return false
end

-- Group scans -------------------------------------------------------------------------------------------------------

local function isGrouped()
    return IsInGroup() or IsInRaid()
end

local function buffExistsOnAnyMember(spellIDs)
    if unitHasBuff("player", spellIDs) then return true end
    local prefix, count
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    elseif IsInGroup() then
        prefix, count = "party", GetNumSubgroupMembers()
    else
        return false
    end
    for i = 1, count do
        if unitHasBuff(prefix .. i, spellIDs) then return true end
    end
    return false
end

local function playerOwnBuffOnAnyMember(spellIDs)
    if unitHasOwnBuff("player", spellIDs) then return true end
    local prefix, count
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    elseif IsInGroup() then
        prefix, count = "party", GetNumSubgroupMembers()
    else
        return false
    end
    for i = 1, count do
        if unitHasOwnBuff(prefix .. i, spellIDs) then return true end
    end
    return false
end

-- A member out of visibility range or in another phase: the client has no aura data for them, so an absent buff
-- there says nothing.
local function isVisible(unit)
    local visible = UnitIsVisible
    if type(visible) ~= "function" then return true end
    return visible(unit) and true or false
end

-- Not in a group reads as solo, a raid included (G8). Only the living, connected and visible count as missing a buff.
local function anyMemberMissingBuff(spellIDs)
    if not IsInGroup() then return not unitHasBuff("player", spellIDs) end

    if UnitExists("player") and UnitIsConnected("player") and not UnitIsDeadOrGhost("player")
        and not unitHasBuff("player", spellIDs) then
        return true
    end

    local prefix, count
    if IsInRaid() then
        prefix, count = "raid", GetNumGroupMembers()
    else
        prefix, count = "party", GetNumSubgroupMembers()
    end
    for i = 1, count do
        local unit = prefix .. i
        if UnitExists(unit) and UnitIsConnected(unit) and not UnitIsDeadOrGhost(unit)
            and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player") and isVisible(unit)
            and not unitHasBuff(unit, spellIDs) then
            return true
        end
    end
    return false
end

-- Snapshots ---------------------------------------------------------------------------------------------------------

-- Unprotected: a raise or a missing API propagates and leaves what it had so far (G1).
local function snapshotPlayerRetail()
    local cache = preCombatAuraCache
    wipe(cache)
    wipe(expiryByID)
    wipe(goneByID)
    wipe(spellByInstance)
    for spellID in pairs(nonSecretSpellIDs) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        cache[spellID] = aura ~= nil
        if aura ~= nil then rememberSeen(spellID, aura) end
    end
end

-- Protected and optional. Adds name entries, each name read once per pass (the ranks of a spell share it). Taken
-- only while auras are readable: at the pull they can already be secret, and a pass then would record every buff
-- as missing. Then the entries are only cleared, and the last readable answer of each list decides.
local function snapshotPlayerForever()
    local cache, names = preCombatAuraCache, preCombatNameCache
    wipe(cache)
    wipe(names)
    if aurasSecret() then return end
    -- (only a readable pass replaces what the last one saw: removals seen since still count)
    wipe(expiryByID)
    wipe(expiryByName)
    wipe(goneByID)
    wipe(goneByName)
    wipe(spellByInstance)
    for spellID in pairs(nonSecretSpellIDs) do
        local api = C_UnitAuras
        local read = api and api.GetPlayerAuraBySpellID
        local present = false
        if type(read) == "function" then
            local ok, aura = pcall(read, spellID)
            present = ok and aura ~= nil
            if present then rememberSeen(spellID, aura) end
        end
        cache[spellID] = present

        local info = SafeSpellInfo(spellID)
        local name = info and info.name
        if name then
            local isSecret = issecretvalue
            if not (isSecret and isSecret(name)) then
                -- A name that is not a string gets no entry.
                local key = normalizeName(name)
                if key and names[key] == nil then
                    local aura = byNameForever("player", name)
                    names[key] = aura ~= nil
                    expiryByName[key] = readExpiry(aura)
                end
            end
        end
    end
end

local function snapshotOwnOnRaid()
    local cache = preCombatOwnCache
    wipe(cache)
    cache[SOURCE_OF_MAGIC] = playerOwnBuffOnAnyMember(SOURCE_OF_MAGIC_LIST)
    cache[BLISTERING_SCALES] = playerOwnBuffOnAnyMember(BLISTERING_SCALES_LIST)
end

-- Setup -------------------------------------------------------------------------------------------------------------

function AuraRead.Setup(ctx)
    local client = ctx and ctx.client
    if client ~= "retail" and client ~= "forever" then
        error("KUIAuraReminders_AuraRead: ctx.client must be \"retail\" or \"forever\"", 2)
    end

    nonSecretSpellIDs, preCombatAuraCache, preCombatOwnCache = {}, {}, {}
    AuraRead.NonSecretSpellIDs = nonSecretSpellIDs
    AuraRead.PreCombatAuraCache = preCombatAuraCache
    AuraRead.PreCombatOwnOnRaidCache = preCombatOwnCache

    if client == "retail" then
        readByID, unitHasBuff = byIDRetail, unitHasRetail
        AuraRead.GetHelpfulAuraByName = byNameRetail
        AuraRead.PlayerHasAuraByID = playerHasRetail
        AuraRead.SnapshotPlayerAuras = snapshotPlayerRetail
    else
        SafeSpellInfo = ctx.SafeSpellInfo
        preCombatNameCache = {}
        readByID, unitHasBuff = byIDForever, unitHasForever
        AuraRead.GetHelpfulAuraByName = byNameForever
        AuraRead.PlayerHasAuraByID = playerHasForever
        AuraRead.SnapshotPlayerAuras = snapshotPlayerForever
        AuraRead.MarkPlayerBuffPresent = markPresent
    end

    AuraRead.NoteAuraUpdate = noteAuraUpdate
    AuraRead.NextExpiry = nextExpiry
    AuraRead.GetHelpfulAuraBySpellID = readByID
    AuraRead.PlayerHasSelfCastAuraByID = playerHasSelfCast
    AuraRead.IsGrouped = isGrouped
    AuraRead.AnyGroupMemberMissingBuff = anyMemberMissingBuff
    AuraRead.BuffExistsOnAnyGroupMember = buffExistsOnAnyMember
    AuraRead.PlayerOwnBuffOnAnyGroupMember = playerOwnBuffOnAnyMember
    AuraRead.SnapshotOwnOnRaidBuffs = snapshotOwnOnRaid
end
