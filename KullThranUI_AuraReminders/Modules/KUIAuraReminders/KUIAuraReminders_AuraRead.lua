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

-- The client's versions, chosen at Setup, used by the shared tests below.
local readByID, unitHasBuff

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

-- Secret test first, then the exact lookup, the finder and, out of combat, the UnitAura walk.
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

    local inCombat = InCombatLockdown and InCombatLockdown()
    local walk = UnitAura
    if type(walk) == "function" and not inCombat then
        local wanted = normalizeName(name)
        for index = 1, 40 do
            local ok, auraName = pcall(walk, unit, index, "HELPFUL")
            if not ok or auraName == nil then break end
            if auraName == name or (wanted and normalizeName(auraName) == wanted) then
                return true, true
            end
        end
    end
    return nil, not inCombat
end

-- Exact lookup, name path, then the finder, or with no finder the out of combat walk. Absent in combat is unreadable.
local function byIDForever(unit, spellID)
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
            local aura, readable = byNameForever(unit, name)
            if aura ~= nil then return aura, true end
            if readable then return nil, true end
        end
    end

    local finder = util and util.FindAuraBySpellID
    local hasFinder = type(finder) == "function"
    if hasFinder then
        local ok, found = pcall(finder, spellID, unit, "HELPFUL")
        if ok and found ~= nil then return found, true end
    end

    local inCombat = InCombatLockdown and InCombatLockdown()
    local walk = UnitAura
    if not hasFinder and type(walk) == "function" and not inCombat then
        local isSecret = issecretvalue
        for index = 1, 40 do
            local ok, auraName, _, _, _, _, _, source, _, _, foundID = pcall(walk, unit, index, "HELPFUL")
            if not ok or auraName == nil then break end
            if not (isSecret and isSecret(foundID)) and foundID == spellID then
                return { sourceUnit = source }, true
            end
        end
    end
    return nil, not inCombat
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
            if inCombat and cache[spellID] then return true end
        elseif cache[spellID] then
            return true
        end
    end
    return false
end

-- Unreadable decides, not combat. The ID entry, then the entry of the normalised name, untested for secrecy (G11).
local function playerHasForever(spellIDs)
    if not spellIDs or spellIDs[1] == nil then return true end
    local cache = preCombatAuraCache
    for i = 1, #spellIDs do
        local spellID = spellIDs[i]
        local aura, readable = byIDForever("player", spellID)
        if readable then
            if aura ~= nil then return true end
        elseif cache[spellID] then
            return true
        else
            local info = SafeSpellInfo(spellID)
            local key = info and normalizeName(info.name)
            if key and preCombatNameCache[key] then return true end
        end
    end
    return false
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

-- Not in a group reads as solo, a raid included (G8). Only the living, connected count as missing a buff.
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
            and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player")
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
    for spellID in pairs(nonSecretSpellIDs) do
        cache[spellID] = C_UnitAuras.GetPlayerAuraBySpellID(spellID) ~= nil
    end
end

-- Protected and optional. Adds name entries, and a true entry is never overwritten in the pass.
local function snapshotPlayerForever()
    local cache, names = preCombatAuraCache, preCombatNameCache
    wipe(cache)
    wipe(names)
    for spellID in pairs(nonSecretSpellIDs) do
        local api = C_UnitAuras
        local read = api and api.GetPlayerAuraBySpellID
        local present = false
        if type(read) == "function" then
            local ok, aura = pcall(read, spellID)
            present = ok and aura ~= nil
        end
        cache[spellID] = present

        local info = SafeSpellInfo(spellID)
        local name = info and info.name
        if name then
            local isSecret = issecretvalue
            if not (isSecret and isSecret(name)) then
                -- A name that is not a string gets no entry.
                local key = normalizeName(name)
                if key then
                    local aura = byNameForever("player", name)
                    if aura ~= nil then
                        names[key] = true
                    elseif names[key] == nil then
                        names[key] = false
                    end
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
    end

    AuraRead.GetHelpfulAuraBySpellID = readByID
    AuraRead.PlayerHasSelfCastAuraByID = playerHasSelfCast
    AuraRead.IsGrouped = isGrouped
    AuraRead.AnyGroupMemberMissingBuff = anyMemberMissingBuff
    AuraRead.BuffExistsOnAnyGroupMember = buffExistsOnAnyMember
    AuraRead.PlayerOwnBuffOnAnyGroupMember = playerOwnBuffOnAnyMember
    AuraRead.SnapshotOwnOnRaidBuffs = snapshotOwnOnRaid
end
