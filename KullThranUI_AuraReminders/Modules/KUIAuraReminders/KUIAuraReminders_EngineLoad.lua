-- Custom aura engine, load checks of a v1 record. Never secret: combat, instance, known spell, map, boss fight, class,
-- specialization, role, group size, level and mount. Shared byte for byte between the Retail and Forever workspaces.

local _, ns = ...

local E = ns.AuraEngine or {}
ns.AuraEngine = E

-- `env.inCombat` comes from the combat events: InCombatLockdown() is still false inside PLAYER_REGEN_DISABLED.
-- `env.encounterID` is the boss fight in progress (ENCOUNTER_START to ENCOUNTER_END), nil outside one. Both clients
-- send these events.
function E.CheckLoad(record, env)
    if not record.enabled then return false end
    local load = record.load or {}
    local inCombat = env and env.inCombat

    if load.combat == "IN_COMBAT" and not inCombat then return false end
    if load.combat == "OUT_COMBAT" and inCombat then return false end

    -- Only a known-spell answer of false blocks; a client without the lookup does not.
    if E.ValidID(load.talent) and type(IsPlayerSpell) == "function" then
        local ok, known = pcall(IsPlayerSpell, load.talent)
        if ok and not E.IsSecret(known) and not known then return false end
    end

    local instance = load.instance
    if instance and instance ~= "ANY" then
        local _, instanceType = IsInInstance()
        if instance == "RAID" and instanceType ~= "raid" then return false end
        if instance == "PARTY" and instanceType ~= "party" then return false end
        if instance == "ARENA" and instanceType ~= "arena" then return false end
        if instance == "PVP" and instanceType ~= "pvp" then return false end
        if instance == "NONE" and instanceType ~= "none" then return false end
    end

    local boss = load.boss
    if boss == "BOSS" then
        local current = env and env.encounterID
        if current == nil then return false end
        if E.ValidID(load.encounterID) and current ~= load.encounterID then return false end
    elseif boss == "NO_BOSS" and env and env.encounterID ~= nil then
        return false
    end

    if E.ValidID(load.zone) then
        local currentMap = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
        if currentMap ~= load.zone then return false end
    end

    return E.CheckPlayerLoad(load)
end

-- A function's first result, nil when it is missing, raises or answers a secret.
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or E.IsSecret(value) then return nil end
    return value
end

-- The player's role: the one assigned in the group, else the specialization's. nil when neither is known.
function E.PlayerRole()
    local assigned = Read(UnitGroupRolesAssigned, "player")
    if assigned == "TANK" or assigned == "HEALER" or assigned == "DAMAGER" then return assigned end
    local spec = Read(GetSpecialization)
    if type(spec) == "number" and spec > 0 then
        local role = Read(GetSpecializationRole, spec)
        if role == "TANK" or role == "HEALER" or role == "DAMAGER" then return role end
    end
    return nil
end

-- Class, specialization, role, group size, level and mount. A check whose answer this client cannot give does not
-- block: a client without specializations loads an aura set to one.
function E.CheckPlayerLoad(load)
    if load.class then
        local class
        if type(UnitClass) == "function" then
            local ok, _, token = pcall(UnitClass, "player")
            if ok and not E.IsSecret(token) then class = token end
        end
        if class and class ~= load.class then return false end
    end

    if load.spec then
        local spec = Read(GetSpecialization)
        if type(spec) == "number" and spec ~= load.spec then return false end
    end

    if load.role then
        local role = E.PlayerRole()
        if role and role ~= load.role then return false end
    end

    if load.group then
        local raid, group = Read(IsInRaid) == true, Read(IsInGroup) == true
        if load.group == "SOLO" and (raid or group) then return false end
        if load.group == "PARTY" and (raid or not group) then return false end
        if load.group == "RAID" and not raid then return false end
        if load.group == "GROUP" and not (raid or group) then return false end
    end

    if load.minLevel then
        local level = Read(UnitLevel, "player")
        if type(level) == "number" and level < load.minLevel then return false end
    end

    if load.notMounted and Read(IsMounted) == true then return false end

    return true
end
