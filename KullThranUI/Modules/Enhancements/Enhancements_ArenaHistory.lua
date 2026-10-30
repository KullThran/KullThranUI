local _, ns = ...
local KT = (ns and ns.KT) or _G.KT
local Mod = KT and KT:GetModule("Enhancements", true)
if not Mod then return end

-- Arena History: one record per finished arena (rated, skirmish, Solo Shuffle,
-- brawl), read from Blizzard's own end-of-match scoreboard. Opt-in, like the
-- Mythic+ history, and idle outside arenas.
local A = {}
Mod.ArenaHistory = A
local MAX_MATCHES = 100
local CAPTURE_TIMEOUT = 15

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

-- The WoW Forever client has no arenas: Blizzard_PVPUI is excluded there
-- (ExcludeLoadGameType: camelot), and C_GameRules.GetForeverExperiencePreset
-- exists only on that client. Decided by the client, never by KT.IS_FOREVER.
function A:Available()
    if C_GameRules and C_GameRules.GetForeverExperiencePreset then return false end
    return type(pvp("GetScoreInfo")) == "function" and type(IsActiveBattlefieldArena) == "function"
end

function A:Config()
    local db = Mod:GetDB()
    db.arenaHistory = db.arenaHistory or {}
    local config = db.arenaHistory
    if config.enabled == nil then config.enabled = false end
    if config.autoShow == nil then config.autoShow = true end
    return config, db
end
function A:Enabled()
    local config, db = self:Config()
    return self:Available() and db.enable ~= false and config.enabled == true
end
function A:Store()
    local owner = guid("player")
    if not owner or not KT.db then return end
    KT.db.global = KT.db.global or {}
    local root = KT.db.global.arenaHistory or { version = 1, characters = {} }
    KT.db.global.arenaHistory = root
    root.characters[owner] = root.characters[owner] or { matches = {} }
    return root.characters[owner]
end
function A:Matches()
    local store = self:Store()
    return store and store.matches or {}
end

local function InArena()
    return (call(IsActiveBattlefieldArena)) == true
end

-- Solo Shuffle has no team winner: rounds won decide it (6 rounds, 3 is even).
local function Bracket()
    if call(pvp("IsRatedSoloShuffle")) == true then return "shuffle", true end
    if call(pvp("IsSoloShuffle")) == true or call(pvp("IsBrawlSoloShuffle")) == true then return "shuffle", false end
    if call(IsArenaSkirmish) == true then return "skirmish", false end
    if call(pvp("IsRatedArena")) == true then return "rated", true end
    return "arena", false
end

local function RoundsWon(info)
    local statID = number(call(pvp("GetCustomVictoryStatID")))
    if not statID then return end
    for _, stat in ipairs(tbl(info.stats) or {}) do
        stat = tbl(stat)
        if stat and number(stat.pvpStatID) == statID then return number(stat.pvpStatValue) end
    end
end

local function ReadPlayer(info)
    return {
        name = text(info.name), guid = text(info.guid), class = text(info.classToken),
        spec = text(info.talentSpec), team = number(info.faction), role = number(info.roleAssigned),
        damage = number(info.damageDone), healing = number(info.healingDone),
        kills = number(info.killingBlows), deaths = number(info.deaths),
        rating = number(info.rating), ratingChange = number(info.ratingChange),
        mmrBefore = number(info.prematchMMR), mmrAfter = number(info.postmatchMMR),
        rounds = RoundsWon(info),
    }
end

-- Builds the record from the scoreboard; nil while the scoreboard is not ready.
function A:Read(winner)
    if not InArena() then return end
    local count = number(call(GetNumBattlefieldScores)) or 0
    if count <= 0 then return end
    local myGUID = guid("player")
    local players, me = {}, nil
    for index = 1, math.min(count, 10) do
        local info = tbl(call(pvp("GetScoreInfo"), index))
        if info then
            local player = ReadPlayer(info)
            players[#players + 1] = player
            if player.guid and player.guid == myGUID then me = player end
        end
    end
    if not me then return end

    local bracket, rated = Bracket()
    local myTeam = me.team or number(call(GetBattlefieldArenaFaction))
    winner = number(winner) or number(call(pvp("GetActiveMatchWinner")))
    local result
    if bracket == "shuffle" then
        if me.rounds then
            result = me.rounds > 3 and "win" or (me.rounds < 3 and "loss" or "even")
        end
    elseif winner and myTeam then
        if winner == myTeam then result = "win"
        elseif winner == (myTeam + 1) % 2 then result = "loss"
        else result = "draw" end
    end

    local size = 0
    for _, player in ipairs(players) do
        if player.team == myTeam then size = size + 1 end
    end
    local teams = {}
    for index = 0, 1 do
        local info = tbl(call(pvp("GetTeamInfo"), index))
        if info then
            teams[index + 1] = { name = text(info.name), rating = number(info.rating),
                ratingNew = number(info.ratingNew), mmr = number(info.ratingMMR) }
        end
    end
    local map, _, _, _, _, _, _, instanceID = call(GetInstanceInfo)
    return {
        map = text(map), instanceID = number(instanceID), bracket = bracket, rated = rated,
        size = bracket == "shuffle" and 3 or size, duration = number(call(pvp("GetActiveMatchDuration"))),
        result = result, winner = winner, team = myTeam, rounds = me.rounds,
        rating = me.rating, ratingChange = me.ratingChange,
        mmrBefore = me.mmrBefore, mmrAfter = me.mmrAfter,
        players = players, teams = teams,
    }
end

function A:Capture()
    local pending = self.pending
    if not pending or not self:Enabled() then return false end
    local match = self:Read(pending.winner)
    if not match then
        if clock() > pending.deadline then self:StopCapture() end
        return false
    end
    local store = self:Store()
    if not store then return false end
    -- PVP_MATCH_COMPLETE can arrive twice; one record per match.
    local signature = table.concat({ match.instanceID or 0, match.duration or 0, #match.players,
        match.ratingChange or 0 }, ":")
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
    self:StopCapture()
    if self:Config().autoShow then self.pendingShow = match.id end
    if self.window and self.window:IsShown() and self.Render then self:Render(match.id) end
    return true
end

-- The scoreboard is only listened to between the end of a match and its capture.
function A:StartCapture(winner)
    self.pending = { winner = winner, deadline = clock() + CAPTURE_TIMEOUT }
    if self.events then self.events:RegisterEvent("UPDATE_BATTLEFIELD_SCORE") end
    call(RequestBattlefieldScoreData)
    if C_Timer and C_Timer.After then
        C_Timer.After(1, function() A:Capture() end)
        C_Timer.After(4, function() A:Capture() end)
        C_Timer.After(CAPTURE_TIMEOUT + 1, function() if A.pending then A:StopCapture() end end)
    end
end
function A:StopCapture()
    self.pending = nil
    if self.events then self.events:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE") end
end

function A:Event(event, ...)
    if not self:Enabled() then return end
    if event == "PVP_MATCH_COMPLETE" then
        if InArena() then self:StartCapture((...)) end
    elseif event == "UPDATE_BATTLEFIELD_SCORE" then
        self:Capture()
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Open the recorded match once the player is back out of the arena.
        if self.pendingShow and not InArena() and not (InCombatLockdown and InCombatLockdown()) then
            local id = self.pendingShow
            self.pendingShow = nil
            if self.Show then self:Show(id) end
        end
    end
end

function Mod:InitializeArenaHistory()
    if A.events then return end
    A:Config()
    if not A:Enabled() then return end
    local f = CreateFrame("Frame")
    A.events = f
    f:RegisterEvent("PVP_MATCH_COMPLETE")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function(_, event, ...) A:Event(event, ...) end)
end
