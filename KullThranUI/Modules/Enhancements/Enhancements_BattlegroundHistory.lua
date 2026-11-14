local _, ns = ...
local KT = (ns and ns.KT) or _G.KT
local Mod = KT and KT:GetModule("Enhancements", true)
if not Mod then return end

-- Battleground History: one record per finished battleground (random, epic,
-- brawl, rated, Blitz), read from Blizzard's own end-of-match scoreboard.
-- Opt-in, like the arena history, and idle outside battlegrounds. The WoW
-- Forever client uses the same scoreboard API (C_PvP.GetScoreInfo and
-- PVP_MATCH_COMPLETE in its Blizzard_PVPMatch), so this file is shared.
local B = {}
Mod.BattlegroundHistory = B
local MAX_MATCHES = 100
local MAX_SCORES = 80
local CAPTURE_TIMEOUT = 15
local FACTIONS = { [0] = "Horde", [1] = "Alliance" }

local function plain(v)
    return not (issecretvalue and issecretvalue(v))
end
local function number(v)
    if plain(v) and type(v) == "number" and v == v and math.abs(v) < 1e15 then return v end
end
local function text(v)
    if plain(v) and type(v) == "string" and v ~= "" then return v:sub(1, 256) end
end
local function tbl(v)
    if plain(v) and type(v) == "table" then return v end
end
local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
end
local function now() return number(call(GetServerTime)) or time() end
local function clock() return number(call(GetTime)) or 0 end
local function guid(unit) return text(call(UnitGUID, unit)) end
local function pvp(name) return C_PvP and C_PvP[name] end

function B:Available()
    return type(pvp("GetScoreInfo")) == "function" and type(GetNumBattlefieldScores) == "function"
end

function B:Config()
    local db = Mod:GetDB()
    db.battlegroundHistory = db.battlegroundHistory or {}
    local config = db.battlegroundHistory
    if config.enabled == nil then config.enabled = false end
    if config.autoShow == nil then config.autoShow = true end
    return config, db
end
function B:Enabled()
    local config, db = self:Config()
    return self:Available() and db.enable ~= false and config.enabled == true
end
function B:Store()
    local owner = guid("player")
    if not owner or not KT.db then return end
    KT.db.global = KT.db.global or {}
    local root = KT.db.global.battlegroundHistory or { version = 1, characters = {} }
    KT.db.global.battlegroundHistory = root
    root.characters[owner] = root.characters[owner] or { matches = {} }
    return root.characters[owner]
end
function B:Matches()
    local store = self:Store()
    return store and store.matches or {}
end

-- Arenas are recorded by the arena history; everything else of instance type
-- "pvp" is a battleground.
local function InBattleground()
    if (call(IsActiveBattlefieldArena)) == true then return false end
    if call(pvp("IsBattleground")) == true then return true end
    local _, instanceType = call(GetInstanceInfo)
    return instanceType == "pvp"
end

local function Kind()
    if call(pvp("IsRatedSoloRBG")) == true then return "blitz", true end
    if call(pvp("IsRatedBattleground")) == true then return "rated", true end
    if call(pvp("IsInBrawl")) == true then return "brawl", false end
    return "normal", false
end

-- Objective columns (flags, bases, carts...) as { name = value } lists.
local function ReadStats(info)
    local stats = {}
    for _, stat in ipairs(tbl(info.stats) or {}) do
        stat = tbl(stat)
        local name, value = stat and text(stat.name), stat and number(stat.pvpStatValue)
        if name and value then
            stats[#stats + 1] = { name = name, value = value, order = number(stat.orderIndex) or #stats }
        end
    end
    table.sort(stats, function(x, y) return x.order < y.order end)
    for _, stat in ipairs(stats) do stat.order = nil end
    return stats
end

local function ReadPlayer(info)
    return {
        name = text(info.name), guid = text(info.guid), class = text(info.classToken),
        spec = text(info.talentSpec), team = number(info.faction),
        kills = number(info.killingBlows), honorableKills = number(info.honorableKills),
        deaths = number(info.deaths), damage = number(info.damageDone), healing = number(info.healingDone),
        honor = number(info.honorGained), rating = number(info.rating), ratingChange = number(info.ratingChange),
        stats = ReadStats(info),
    }
end

local SUMMED = { "kills", "honorableKills", "deaths", "damage", "healing" }
local function AddToTeam(teams, player)
    local index = player.team
    if index ~= 0 and index ~= 1 then return end
    local team = teams[index + 1]
    team.players = team.players + 1
    for _, key in ipairs(SUMMED) do
        if player[key] then team[key] = (team[key] or 0) + player[key] end
    end
    for _, stat in ipairs(player.stats) do
        local entry
        for _, existing in ipairs(team.stats) do
            if existing.name == stat.name then entry = existing; break end
        end
        if not entry then
            entry = { name = stat.name, value = 0 }
            team.stats[#team.stats + 1] = entry
        end
        entry.value = entry.value + stat.value
    end
end

-- Builds the record from the scoreboard; nil while the scoreboard is not ready.
function B:Read(winner, duration)
    if not InBattleground() then return end
    local count = number(call(GetNumBattlefieldScores)) or 0
    if count <= 0 then return end
    local myGUID = guid("player")
    local teams = { { players = 0, stats = {} }, { players = 0, stats = {} } }
    local me
    for index = 1, math.min(count, MAX_SCORES) do
        local info = tbl(call(pvp("GetScoreInfo"), index))
        if info then
            local player = ReadPlayer(info)
            AddToTeam(teams, player)
            if player.guid and player.guid == myGUID then me = player end
        end
    end
    if not me and myGUID then
        local info = tbl(call(pvp("GetScoreInfoByPlayerGuid"), myGUID))
        if info then me = ReadPlayer(info) end
    end
    if not me then return end

    local kind, rated = Kind()
    local myTeam = me.team or number(call(GetBattlefieldArenaFaction))
    winner = number(winner) or number(call(pvp("GetActiveMatchWinner")))
    local result
    if winner and myTeam then
        if winner == myTeam then result = "win"
        elseif winner == (myTeam + 1) % 2 then result = "loss"
        else result = "draw" end
    end
    for index = 0, 1 do
        local info = tbl(call(pvp("GetTeamInfo"), index))
        local team = teams[index + 1]
        team.faction = FACTIONS[index]
        if info then
            team.size = number(info.size)
            team.rating, team.ratingNew, team.mmr = number(info.rating), number(info.ratingNew), number(info.ratingMMR)
        end
    end
    duration = number(call(pvp("GetActiveMatchDuration"))) or number(duration)
    if (not duration or duration <= 0) and self.startedAt then duration = math.floor(clock() - self.startedAt) end
    local map, _, _, _, _, _, _, instanceID = call(GetInstanceInfo)
    me.guid = nil
    return {
        map = text(map) or text(call(GetRealZoneText)), instanceID = number(instanceID),
        kind = kind, rated = rated, duration = duration, result = result, winner = winner,
        team = myTeam, faction = FACTIONS[myTeam or -1],
        player = me, teams = teams,
    }
end

function B:Capture()
    local pending = self.pending
    if not pending or not self:Enabled() then return false end
    local match = self:Read(pending.winner, pending.duration)
    if not match then
        if clock() > pending.deadline then self:StopCapture() end
        return false
    end
    local store = self:Store()
    if not store then return false end
    -- PVP_MATCH_COMPLETE can arrive twice; one record per match.
    local p = match.player
    local signature = table.concat({ match.instanceID or 0, match.duration or 0, p.kills or 0,
        p.deaths or 0, p.damage or 0, p.honor or 0 }, ":")
    if store.lastSignature == signature and now() - (store.lastAt or 0) < 300 then
        self:StopCapture()
        return true
    end
    store.sequence = (store.sequence or 0) + 1
    match.id = (guid("player") or "?") .. ":" .. now() .. ":" .. store.sequence
    match.completedAt = now()
    table.insert(store.matches, 1, match)
    while #store.matches > MAX_MATCHES do table.remove(store.matches) end
    store.lastSignature, store.lastAt = signature, now()
    self.startedAt = nil
    self:StopCapture()
    if self:Config().autoShow then self.pendingShow = match.id end
    if self.window and self.window:IsShown() and self.Render then self:Render(match.id) end
    return true
end

-- The scoreboard is only listened to between the end of a match and its capture.
function B:StartCapture(winner, duration)
    self.pending = { winner = winner, duration = duration, deadline = clock() + CAPTURE_TIMEOUT }
    if self.events then self.events:RegisterEvent("UPDATE_BATTLEFIELD_SCORE") end
    call(RequestBattlefieldScoreData)
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function() B:Capture() end)
        C_Timer.After(4, function() B:Capture() end)
        C_Timer.After(CAPTURE_TIMEOUT + 1, function() if B.pending then B:StopCapture() end end)
    end
end
function B:StopCapture()
    self.pending = nil
    if self.events then self.events:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE") end
end

function B:Event(event, ...)
    if not self:Enabled() then return end
    if event == "PVP_MATCH_COMPLETE" then
        if InBattleground() then self:StartCapture(...) end
    elseif event == "PVP_MATCH_ACTIVE" then
        -- Only a fallback for the duration, if the client does not report it.
        if InBattleground() then self.startedAt = clock() end
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        self:Capture()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Open the recorded match once the player is back out of the battleground.
        if self.pendingShow and not InBattleground() and not (InCombatLockdown and InCombatLockdown()) then
            local id = self.pendingShow
            self.pendingShow = nil
            if self.Show then self:Show(id) end
        end
    end
end

function Mod:InitializeBattlegroundHistory()
    if B.events then return end
    B:Config()
    if not B:Enabled() then return end
    local f = CreateFrame("Frame")
    B.events = f
    f:RegisterEvent("PVP_MATCH_COMPLETE")
    f:RegisterEvent("PVP_MATCH_ACTIVE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event, ...) B:Event(event, ...) end)
end
