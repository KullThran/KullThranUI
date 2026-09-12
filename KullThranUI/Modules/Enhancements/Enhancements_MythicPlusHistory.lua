local _, ns = ...
local KT = (ns and ns.KT) or _G.KT
local Mod = KT and KT:GetModule("Enhancements", true)
if not Mod then return end

local H = {}
Mod.MythicPlusHistory = H
local MAX_RUNS = 50
local slots = {1,2,3,5,6,7,8,9,10,11,12,13,14,15,16,17}
H.slots = slots
local cache, pendingInspect = {}, nil
local nextInspect, nextRoster = 0, 0
local ROSTER_INTERVAL = 10
local RATING_CACHE_INTERVAL = 30
local RIO_CACHE_INTERVAL = 60

local function plain(v)
    return not (issecretvalue and issecretvalue(v))
end
local function number(v)
    if plain(v) and type(v) == "number" and v == v and math.abs(v) < 1e12 then return v end
end
local function text(v)
    if plain(v) and type(v) == "string" then return v:sub(1, 2048) end
end
local function tbl(v)
    if plain(v) and type(v) == "table" then return v end
end
local function call(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, a,b,c,d,e,f = pcall(fn, ...)
    if ok then return a,b,c,d,e,f end
end
local function clone(value, depth)
    if not plain(value) then return end
    local kind = type(value)
    if kind == "string" then return text(value) end
    if kind == "number" then return number(value) end
    if kind == "boolean" then return value end
    if kind ~= "table" or (depth or 0) > 8 then return end
    local result = {}
    for k,v in pairs(value) do
        if plain(k) and (type(k) == "string" or type(k) == "number") then
            result[k] = clone(v, (depth or 0) + 1)
        end
    end
    return result
end
local function now() return number(call(GetServerTime)) or time() end
local function clock() return number(call(GetTime)) or 0 end
local function combat() return call(InCombatLockdown) == true end
local function guid(unit) return text(call(UnitGUID, unit)) end

function H:Config()
    local db = Mod:GetDB()
    db.mplusHistory = db.mplusHistory or {}
    local config = db.mplusHistory
    if not config.fontMigrationVersion then
        config.font = config.font or (KT.db and KT.db.global and KT.db.global.mythicPlusHistoryFont)
        config.fontMigrationVersion = 1
    end
    -- Opt-in during migration: this feature performs Blizzard history/party
    -- queries and must never add background work merely because Enhancements is
    -- loaded. Reset old enabled state once, then require an explicit enable.
    if config._safeCpuMigrationVersion ~= 1 then
        config.enabled = false
        config._safeCpuMigrationVersion = 1
    elseif config.enabled == nil then
        config.enabled = false
    end
    if config.autoShow == nil then config.autoShow = true end
    return config, db
end
function H:Enabled()
    local config, db = self:Config()
    return db.enable ~= false and config.enabled ~= false
end
function H:Store()
    local owner = guid("player")
    if not owner or not KT.db then return end
    KT.db.global = KT.db.global or {}
    local db = KT.db.global
    db.mythicPlusHistory = db.mythicPlusHistory or { version = 1, characters = {} }
    local root = db.mythicPlusHistory
    root.characters[owner] = root.characters[owner] or { runs = {}, sequence = 0 }
    return root.characters[owner]
end
function H:Runs()
    local store = self:Store()
    return store and store.runs or {}
end
-- Blizzard exposes retained completed runs, not the historical party/gear.
-- Import those facts only; never attach today's Raider.IO score or equipment.
local function calendarStamp(value)
    value = tbl(value)
    if not value then return end
    local y, m = number(value.year), number(value.month)
    local d = number(value.monthDay) or number(value.day)
    local h, minute = number(value.hour), number(value.minute)
    if not y or y < 2004 or y > 2200 or not m or m < 1 or m > 12
        or not d or d < 1 or d > 31 or not h or h < 0 or h > 23
        or not minute or minute < 0 or minute > 59 then return end
    return number(call(time, {year=y, month=m, day=d, hour=h, min=minute, sec=0}))
end

function H:ImportBlizzardHistory()
    if not self:Enabled() or self.completing
        or call(C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive) == true then return 0 end
    local api = C_MythicPlus
    -- "Incomplete" here includes depleted keys, as in Blizzard's vault list.
    local history = tbl(call(api and api.GetRunHistory, true, true, true))
    local store = self:Store()
    if not history or not store then return 0 end
    -- CalendarTime uses realm time; normalize it to the same epoch as live runs.
    local realmNow = calendarStamp(call(C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime))
    if not realmNow then return 0 end
    local offset = math.floor(now() / 60) * 60 - realmNow
    local added = 0
    local cutoff
    if #store.runs >= MAX_RUNS then
        cutoff = math.huge
        for _, saved in ipairs(store.runs) do
            cutoff = math.min(cutoff, saved.completedAt or 0)
        end
    end
    local playerSnapshot, capturedPlayer
    local function ImportedPlayer()
        if not capturedPlayer then
            capturedPlayer = true
            playerSnapshot = self:CaptureUnit("player", false)
        end
        return playerSnapshot
    end
    for _, raw in ipairs(history) do
        raw = tbl(raw)
        local mapID = raw and number(raw.mapChallengeModeID)
        local level = raw and number(raw.level)
        local seconds = raw and number(raw.durationSec)
        local stamp = raw and calendarStamp(raw.completionDate)
        if raw and plain(raw.completed) and type(raw.completed) == "boolean" and mapID and mapID > 0
            and level and level > 0 and seconds and seconds > 0 and stamp then
            local id = "blizzard:" .. tostring(number(raw.season) or 0) .. ":" .. mapID
                .. ":" .. level .. ":" .. string.format("%04d%02d%02d%02d%02d",
                    raw.completionDate.year, raw.completionDate.month,
                    number(raw.completionDate.monthDay) or number(raw.completionDate.day),
                    raw.completionDate.hour, raw.completionDate.minute) .. ":" .. seconds
            stamp = stamp + offset
            local match
            for _, saved in ipairs(store.runs) do
                if saved.id == id or (saved.mapID == mapID and saved.level == level
                    and saved.completedAt and math.abs(saved.completedAt - stamp) < 120
                    and saved.durationMS and math.abs(saved.durationMS / 1000 - seconds) < 1) then
                    match = saved
                    break
                end
            end
            if match then
                match.runScore = number(raw.runScore) or match.runScore
                if match.source == "blizzard" and #(match.members or {}) == 0 then
                    local m = ImportedPlayer()
                    if m then
                        match.members = { clone(m) }
                    end
                end
            elseif stamp <= now() + 60 and (not cutoff or stamp >= cutoff) then
                local name, _, limit = call(C_ChallengeMode.GetMapUIInfo, mapID)
                limit = number(limit)
                local run = {
                    id=id, source="blizzard", mapID=mapID, level=level,
                    completedAt=stamp, durationMS=seconds*1000, dungeon=text(name),
                    timeLimit=limit, runScore=number(raw.runScore), season=number(raw.season),
                    members={}, affixes={}, onTime=raw.completed,
                }
                local m = ImportedPlayer()
                if m then
                    run.members[1] = clone(m)
                end
                store.runs[#store.runs+1] = run
                added = added + 1
            end
        end
    end
    table.sort(store.runs, function(a,b)
        if a.completedAt == b.completedAt then return tostring(a.id) < tostring(b.id) end
        return (a.completedAt or 0) > (b.completedAt or 0)
    end)
    while #store.runs > MAX_RUNS do table.remove(store.runs) end
    return added
end

function H:RequestHistory()
    if not self:Enabled() then return end
    self:ImportBlizzardHistory()
    call(C_MythicPlus and C_MythicPlus.RequestMapInfo)
end

local function findMember(run, id)
    for _, member in ipairs(run.members or {}) do
        if member.guid == id then return member end
    end
end
local function unitFor(id)
    for _, unit in ipairs({"player","party1","party2","party3","party4"}) do
        if guid(unit) == id then return unit end
    end
end

function H:CaptureUnit(unit, inspectReady)
    local id = guid(unit)
    if not id then return end
    local m = cache[id] or { guid = id }
    cache[id] = m
    local name, realm = call(UnitFullName, unit)
    m.name = text(name) or m.name
    m.realm = text(realm)
    if not m.realm or m.realm == "" then m.realm = text(call(GetRealmName)) end
    local _, class = call(UnitClass, unit)
    m.class = text(class) or m.class
    m.role = text(call(UnitGroupRolesAssigned, unit)) or m.role
    -- A cached member may come from another dungeon; never reuse that map's score.
    m.mapScore = nil
    if not m.ratingCapturedAt or now() - m.ratingCapturedAt >= RATING_CACHE_INTERVAL then
        local summary = tbl(call(C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit))
        if summary then
            m.rating = number(summary.currentSeasonScore) or m.rating
            local store = self:Store()
            local active = store and store.active
            if active then
                for _, run in ipairs(tbl(summary.runs) or {}) do
                    if number(run.challengeModeID) == active.mapID then m.mapScore = number(run.mapScore) end
                end
            end
        end
        m.ratingCapturedAt = now()
    end
    if not m.rioCapturedAt or now() - m.rioCapturedAt >= RIO_CACHE_INTERVAL then
        local profile = tbl(call(RaiderIO and RaiderIO.GetProfile, unit))
        local rio = profile and tbl(profile.mythicKeystoneProfile)
        if rio and rio.blocked ~= true and rio.blockedPurged ~= true then
            m.rio = number(rio.currentScore)
            m.rioCapturedAt = now() -- addon database snapshot, not a live website lookup
        else
            m.rioCapturedAt = now()
        end
    end
    local own = unit == "player"
    if own or inspectReady then
        local spec
        if own then
            local index = number(call(GetSpecialization))
            if index then spec = number(call(GetSpecializationInfo, index)) end
        else
            spec = number(call(GetInspectSpecialization, unit))
        end
        if spec and spec > 0 then m.specID = spec end
        local ilvl
        if own then
            local _, equipped = call(GetAverageItemLevel)
            ilvl = number(equipped)
        else
            ilvl = number(call(C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel, unit))
        end
        if ilvl and ilvl > 0 then m.ilvl = ilvl end
        local gear, count = {}, 0
        for _, slot in ipairs(slots) do
            local link = text(call(GetInventoryItemLink, unit, slot))
            if link then gear[slot] = link; count = count + 1 end
        end
        -- Keep each equipment observation as a single snapshot, not a mixture
        -- of old and new slots. Partial results are explicitly displayed.
        if count > 0 then
            m.gear, m.gearCount, m.gearCapturedAt = gear, count, now()
        else
            m.gear, m.gearCount, m.gearCapturedAt = nil, nil, nil
        end
        m.inspectedAt = now()
    end
    m.seenAt = now()
    local store = self:Store()
    local active = store and store.active
    if active and not self.completing then
        local saved = findMember(active, id)
        if not saved and #active.members < 5 then
            saved = clone(m)
            active.members[#active.members + 1] = saved
        elseif saved then
            -- Initial scores are immutable. Equipment/spec observations may
            -- improve during the run, but never after completion.
            for _, key in ipairs({"name","realm","class","role","specID","ilvl","gear",
                "gearCount","gearCapturedAt","inspectedAt"}) do
                if m[key] ~= nil then saved[key] = clone(m[key]) end
            end
        end
    end
    return m
end

function H:CaptureParty()
    local profiler = KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("enh.mplusHistory.captureParty")
    for _, unit in ipairs({"player","party1","party2","party3","party4"}) do
        if guid(unit) then self:CaptureUnit(unit, false) end
    end
    if profileStarted then profiler:End("enh.mplusHistory.captureParty", profileStarted) end
end
function H:Begin()
    if not self:Enabled() then return end
    local mapID = number(call(C_ChallengeMode and C_ChallengeMode.GetActiveChallengeMapID))
    local level, affixes = call(C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo)
    level = number(level)
    local store = self:Store()
    if not store or not mapID or mapID <= 0 or not level or level <= 0 then return end
    if store.active and store.active.mapID == mapID and store.active.level == level then return end
    store.sequence = store.sequence + 1
    local name, _, limit = call(C_ChallengeMode.GetMapUIInfo, mapID)
    store.active = {
        id = guid("player") .. ":" .. now() .. ":" .. store.sequence,
        mapID = mapID, level = level, dungeon = text(name), timeLimit = number(limit),
        startedAt = now(), affixes = clone(tbl(affixes) or {}), members = {},
    }
    self.completing = nil
    self:CaptureParty()
    for _, m in ipairs(store.active.members) do
        if m.inspectedAt and now() - m.inspectedAt > 180 then
            m.specID, m.ilvl, m.gear, m.gearCount, m.gearCapturedAt = nil,nil,nil,nil,nil
        end
    end
    if self.window then self.window:Hide() end
end

function H:Complete()
    if not self:Enabled() then return false end
    local info = tbl(call(C_ChallengeMode and C_ChallengeMode.GetChallengeCompletionInfo))
    local mapID = info and number(info.mapChallengeModeID)
    local duration = info and number(info.time)
    local level = info and number(info.level)
    if not mapID or mapID <= 0 or not duration or duration <= 0 or not level or level <= 0 then return false end
    if not plain(info.practiceRun) or info.practiceRun then return true end
    local store = self:Store()
    if not store then return false end
    local signature = mapID .. ":" .. level .. ":" .. duration
    if store.lastCompletion and store.lastCompletion.signature == signature
        and now() - store.lastCompletion.at < 120 then return true end
    local active = store.active
    if active and (active.mapID ~= mapID or active.level ~= level) then return false end
    local run = clone(active or { members = {}, affixes = {} })
    run.id = run.id or (guid("player") .. ":finish:" .. now())
    run.mapID, run.level, run.durationMS, run.completedAt = mapID, level, duration, now()
    local name, _, limit = call(C_ChallengeMode.GetMapUIInfo, mapID)
    run.dungeon, run.timeLimit = text(name) or run.dungeon, number(limit) or run.timeLimit
    run.onTime = plain(info.onTime) and info.onTime == true
    run.upgrades = number(info.keystoneUpgradeLevels)
    run.oldScore, run.newScore = number(info.oldOverallDungeonScore), number(info.newOverallDungeonScore)
    local deaths, penalty = call(C_ChallengeMode.GetDeathCount)
    run.deaths, run.penalty = number(deaths) or run.deaths, number(penalty) or run.penalty
    -- info.members is the score-upgrade list, not the complete completion
    -- roster. Preserve the party captured throughout the run and use this
    -- list only to fill members that were not observed earlier.
    local members, memberByGUID = {}, {}
    for _, saved in ipairs(tbl(run.members) or {}) do
        local id = saved and text(saved.guid)
        if id and not memberByGUID[id] and #members < 5 then
            local m = clone(saved)
            members[#members + 1] = m
            memberByGUID[id] = m
        end
    end
    for _, member in ipairs(tbl(info.members) or {}) do
        local id = text(member.memberGUID)
        if id then
            local m = memberByGUID[id]
            if not m and #members < 5 then
                local cached = cache[id]
                if not cached or cached.seenAt < (run.startedAt or now() - 180) then cached = nil end
                m = clone(cached or {guid = id})
                members[#members + 1] = m
                memberByGUID[id] = m
            end
            if m then m.name = m.name or text(member.name) end
        end
    end

    -- Always retain the player even if capture started late or the upgrade
    -- list is empty (for example, when the completed key added no score).
    local playerID = guid("player")
    if playerID and not memberByGUID[playerID] and #members < 5 then
        local cached = cache[playerID]
        local m = clone(cached or {guid = playerID})
        m.name = m.name or text(call(UnitName, "player"))
        members[#members + 1] = m
        memberByGUID[playerID] = m
    end
    run.members = members
    for _, m in ipairs(run.members) do
        local unit = unitFor(m.guid)
        local summary = unit and tbl(call(C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary, unit))
        m.ratingAfter = summary and number(summary.currentSeasonScore) or nil
        if m.guid == guid("player") then m.ratingAfter = run.newScore or m.ratingAfter end
    end
    -- A map update may precede the completion event. Replace that imported
    -- summary with our richer recording instead of displaying the key twice.
    for i = #store.runs, 1, -1 do
        local old = store.runs[i]
        if old.source == "blizzard" and old.mapID == mapID and old.level == level
            and old.completedAt and math.abs(old.completedAt - run.completedAt) < 120
            and old.durationMS and math.abs(old.durationMS - duration) < 1000 then
            run.runScore = old.runScore
            table.remove(store.runs, i)
        end
    end

    local sessionTypes = Enum and Enum.DamageMeterSessionType
    local meterTypes = Enum and Enum.DamageMeterType
    if C_DamageMeter and sessionTypes and meterTypes then
        local session = tbl(call(C_DamageMeter.GetCombatSessionFromType, sessionTypes.Overall, meterTypes.DamageDone))
        local sources = session and tbl(session.combatSources)
        if sources then
            local damageMembers = {}
            for _, m in ipairs(run.members or {}) do
                m.damageRank, m.damageTotal, m.damageDPS = nil, nil, nil
                for _, raw in ipairs(sources) do
                    local src = tbl(raw)
                    local sourceGUID = src and text(src.sourceGUID)
                    local sourceName = src and text(src.name)
                    local matches = sourceGUID and m.guid and sourceGUID == m.guid
                    if not sourceGUID and sourceName and m.name then
                        matches = sourceName == m.name or sourceName == m.name .. "-" .. (m.realm or "")
                    end
                    local total = src and number(src.totalAmount)
                    if matches and total and total >= 0 then
                        m.damageTotal = total
                        m.damageDPS = number(src.amountPerSecond)
                        local seconds = number(session.durationSeconds)
                        if not m.damageDPS and seconds and seconds > 0 then m.damageDPS = total / seconds end
                        damageMembers[#damageMembers+1] = m
                        break
                    end
                end
            end
            table.sort(damageMembers, function(a,b) return a.damageTotal > b.damageTotal end)
            for rank = 1, math.min(3, #damageMembers) do damageMembers[rank].damageRank = rank end
        end
    end

    table.insert(store.runs, 1, run)
    while #store.runs > MAX_RUNS do table.remove(store.runs) end
    store.lastCompletion = { signature = signature, at = now() }
    store.active = nil
    self.completing, pendingInspect = nil, nil
    self.finished = true
    if self:Config().autoShow then self.pendingShow = { id = run.id, at = clock() + 3 } end
    if self.window and self.window:IsShown() and self.Render then self:Render(run.id) end
    return true
end

function H:InspectNext()
    local profiler = KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("enh.mplusHistory.inspectNext")
    local function done() if profileStarted then profiler:End("enh.mplusHistory.inspectNext", profileStarted) end end
    if combat() or self.completing or (InspectFrame and InspectFrame:IsShown()) then done(); return end
    if pendingInspect and clock() - pendingInspect.at < 5 then done(); return end
    pendingInspect = nil
    if clock() < nextInspect then done(); return end
    for _, unit in ipairs({"party1","party2","party3","party4"}) do
        local id = guid(unit)
        local m = id and cache[id]
        if m and (not m.inspectedAt or now() - m.inspectedAt > 90)
            and (not m.attemptAt or clock() - m.attemptAt > 15)
            and call(CanInspect, unit) == true then
            m.attemptAt = clock()
            pendingInspect = { guid = id, unit = unit, at = clock() }
            nextInspect = clock() + 3
            call(NotifyInspect, unit)
            done()
            return
        end
    end
    done()
end
function H:Tick()
    local profiler = KT.CombatProfiler
    local profileStarted = profiler and profiler:Begin("enh.mplusHistory.tick")
    if not self:Enabled() then
        local store = self:Store()
        if store then store.active = nil end
        self.pendingShow, self.completing, pendingInspect, self.finished = nil, nil, nil, nil
        self:StopTicker()
        if profileStarted then profiler:End("enh.mplusHistory.tick", profileStarted) end
        return
    end
    if self.completing then
        if self:Complete() then self.completing = nil
        elseif clock() > self.completing then self.completing = nil end
    end
    if self.pendingShow and clock() >= self.pendingShow.at and not combat() then
        local pending = self.pendingShow
        self.pendingShow = nil
        if self:Config().autoShow and self.Show then self:Show(pending.id) end
    end
    local active = call(C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive) == true
    local _, instanceType = call(IsInInstance)
    local keyed = instanceType == "party"
        and call(C_ChallengeMode and C_ChallengeMode.HasSlottedKeystone) == true
    if not active and not keyed and not self.completing and not self.pendingShow then
        self:StopTicker()
        if profileStarted then profiler:End("enh.mplusHistory.tick", profileStarted) end
        return
    end
    if active and not self.completing and not self.finished then self:Begin() end
    -- Only pre-scan a normal dungeon when a key is actually slotted; otherwise
    -- every 5-man (heroics, delves, leveling) triggered a continuous scan.
    if (active or keyed) and not self.completing and clock() >= nextRoster then
        nextRoster = clock() + ROSTER_INTERVAL
        for id, member in pairs(cache) do
            if now() - (member.seenAt or 0) > 300 then cache[id] = nil end
        end
        self:CaptureParty()
        self:InspectNext()
    end
    if profileStarted then profiler:End("enh.mplusHistory.tick", profileStarted) end
end

function H:StartTicker()
    if self.ticker or not self:Enabled() then return end
    self.ticker = C_Timer.NewTicker(1, function() H:Tick() end)
end

function H:StopTicker()
    if self.ticker and self.ticker.Cancel then self.ticker:Cancel() end
    self.ticker = nil
end
function H:Event(event, ...)
    if not self:Enabled() then return end
    local store = self:Store()
    if event == "CHALLENGE_MODE_START" then
        self:StartTicker()
        if store then store.active = nil end
        self.pendingShow, self.finished = nil, nil
        pendingInspect = nil
        self:Begin()
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        self:StartTicker()
        -- Freeze gear before anyone equips chest loot or leaves the instance.
        self:CaptureParty()
        self.completing = clock() + 10
        self:Complete()
    elseif event == "CHALLENGE_MODE_RESET" then
        if store then store.active = nil end
        self.completing, pendingInspect, self.finished = nil, nil, nil
        self:StopTicker()
    elseif event == "INSPECT_READY" then
        local id = text(...)
        if pendingInspect and id == pendingInspect.guid and guid(pendingInspect.unit) == id and not self.completing then
            self:CaptureUnit(pendingInspect.unit, true)
            pendingInspect = nil
        end
    elseif event == "CHALLENGE_MODE_DEATH_COUNT_UPDATED" then
        if store and store.active then
            local deaths, penalty = call(C_ChallengeMode.GetDeathCount)
            store.active.deaths, store.active.penalty = number(deaths), number(penalty)
        end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        if store and store.active and not self.completing then self:CaptureUnit("player", false) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:RequestHistory()
        if call(C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive) == true then
            self:StartTicker()
            self:Begin()
        elseif store and not self.completing then store.active = nil end
    elseif event == "GROUP_ROSTER_UPDATE" then
        self:StartTicker()
    elseif event == "CHALLENGE_MODE_MAPS_UPDATE" then
        self:ImportBlizzardHistory()
        if self.window and self.window:IsShown() and not self.demoRuns then self:Render(self.selectedID) end
    else
        nextRoster = 0
    end
end
function Mod:InitializeMythicPlusHistory()
    if H.events then return end
    H:Config()
    if not H:Enabled() then return end
    local f = CreateFrame("Frame")
    H.events = f
    for _, event in ipairs({"CHALLENGE_MODE_START","CHALLENGE_MODE_COMPLETED","CHALLENGE_MODE_RESET",
        "CHALLENGE_MODE_DEATH_COUNT_UPDATED","INSPECT_READY","PLAYER_ENTERING_WORLD",
        "GROUP_ROSTER_UPDATE","PLAYER_EQUIPMENT_CHANGED","PLAYER_SPECIALIZATION_CHANGED",
        "CHALLENGE_MODE_MAPS_UPDATE"}) do
        f:RegisterEvent(event)
    end
    f:SetScript("OnEvent", function(_, event, ...) H:Event(event, ...) end)
    -- Respect inspect requests from the inspect UI and other addons.
    if NotifyInspect and hooksecurefunc then
        hooksecurefunc("NotifyInspect", function(unit)
            if pendingInspect and guid(unit) ~= pendingInspect.guid then pendingInspect = nil end
            nextInspect = clock() + 3
        end)
    end
    H:RequestHistory()
    H:Tick()
end

-- Include imports and event dispatch in the lightweight capture, even at idle.
for _, method in ipairs({"ImportBlizzardHistory", "RequestHistory", "Event"}) do
    local original = H[method]
    local label = "enh.mplusHistory." .. method
    H[method] = function(self, ...)
        local profiler = KT.CombatProfiler
        if not (profiler and profiler.capturing) then return original(self, ...) end
        local started = profiler:Begin(label)
        local ok, result = pcall(original, self, ...)
        profiler:End(label, started)
        if not ok then error(result, 0) end
        return result
    end
end
