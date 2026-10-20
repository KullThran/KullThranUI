if KT_CLIENT_BLOCKED then return end

local _, ns = ...

-- DoT tracker for the pending DoT damage overlay (Nameplates_DotDamage.lua).
-- Ported from DoesItDie v0.6.1 by Joe Greive (MIT License, Copyright (c) 2026 Joe Greive):
-- https://github.com/swirllyman/DoesItDie
--
-- Auras, target health and the combat log are all out of reach in combat on these clients, so the DoTs
-- are tracked from what stays readable: your own casts (UNIT_SPELLCAST_SUCCEEDED) with their spell
-- descriptions, which give the DoT, its damage and duration, and UNIT_COMBAT damage on units, which
-- gives the real tick sizes. The tracking below is DoesItDie's, unchanged apart from the settings.

local DEFAULT_TICK_INTERVAL = 3
-- Seconds either side of an expected tick time. Observed on Forever: the first tick lands within ~0.1s of one
-- interval after the cast, and later ticks within ~0.1s of the first tick's rhythm. Tight windows keep melee
-- auto-attacks (same Physical school as bleeds, similar size, ~1s rhythm) from passing as ticks.
local TICK_MATCH_WINDOW = 0.45
local TICK_MATCH_WINDOW_ANCHORED = 0.25
local MISSED_TICKS_BEFORE_DROP = 2  -- a DoT that never ticks was resisted/immune
-- Projectile DoTs start when the projectile lands, not on the cast event: Serpent Sting's first tick came
-- 3.6-3.9s after the cast instead of 3s (log 253548.7, 12 casts). Their first tick may be this much later.
local PROJECTILE_TRAVEL = 1.5
local PROJECTILE_DOTS = {
    ["Serpent Sting"] = true, ["Fireball"] = true, ["Pyroblast"] = true, ["Frostfire Bolt"] = true,
}
-- Once a DoT's tick size is known, same-school hits further off than this are someone else's (the Imp's
-- Firebolt next to Immolate, white hits next to Rip). Ticks within one cast barely vary (15,15,15,16);
-- the minimum slack of 1 covers rounding (3 vs 4).
local TICK_AMOUNT_TOLERANCE = 0.25
-- Check for the first tick against a size learned on an earlier cast (gear/AP may have changed a little).
local FIRST_TICK_AMOUNT_TOLERANCE = 0.3
-- A crit tick is 1.5-2x a normal one; anything else flagged as a crit (white-hit crits) isn't this DoT.
local CRIT_MIN_RATIO, CRIT_MAX_RATIO = 1.3, 2.3
local DB_VERSION = 5                -- bump to discard learned data from older, buggier versions

-- Tick intervals that differ from the 3s default and aren't stated in the description.
local KNOWN_TICK_INTERVALS = {
    ["Insect Swarm"] = 2,
    ["Curse of Agony"] = 2,
    ["Bane of Agony"] = 2, -- Forever's name for Curse of Agony
    ["Fireball"] = 2,
    ["Holy Fire"] = 2,
    ["Rip"] = 2,
    ["Rupture"] = 2,
}

-- DoTs whose ticks aren't even: each tick is the average tick times its factor (factors average 1, so the
-- tooltip total still holds). Agony is back-loaded; seen in-game on Forever (log 166015.8, 72 over 24s):
-- ticks 3,3,3,3 then 6,6,... then 9s. Everything else ticks evenly.
local AGONY_SHAPE = { 0.5, 0.5, 0.5, 0.5, 1, 1, 1, 1, 1.5, 1.5, 1.5, 1.5 }
local TICK_SHAPES = {
    ["Bane of Agony"] = AGONY_SHAPE, -- Forever's name
    ["Curse of Agony"] = AGONY_SHAPE,
}

-- Descriptions that don't name their school.
local SCHOOL_BY_NAME = {
    ["Siphon Life"] = 32,
}

-- Read like DoTs but aren't one on the current target: ground/area effects, channels, traps, and
-- delayed damage (Wyvern Sting only starts after the sleep).
local IGNORED_SPELLS = {
    ["Rain of Fire"] = true, ["Hellfire"] = true, ["Blizzard"] = true, ["Flamestrike"] = true,
    ["Consecration"] = true, ["Hurricane"] = true, ["Volley"] = true,
    ["Drain Life"] = true, ["Drain Soul"] = true, ["Drain Mana"] = true, ["Health Funnel"] = true,
    ["Mind Flay"] = true, ["Arcane Missiles"] = true, ["Starshards"] = true,
    ["Immolation Trap"] = true, ["Explosive Trap"] = true, ["Wyvern Sting"] = true,
}

local SCHOOL_MASKS = {
    Physical = 1, Holy = 2, Fire = 4, Nature = 8, Frost = 16, Shadow = 32, Arcane = 64,
    Frostfire = 4 + 16, -- Forever's Frostfire Bolt: combined schools report as the OR of their masks
}

-- The tables above are keyed by English spell names. The same spells are also listed by spell ID, so
-- other client languages get their own names added at load (an ID the client lacks is skipped).
local SPELL_IDS = {
    ["Insect Swarm"] = 5570, ["Curse of Agony"] = 980, ["Fireball"] = 133, ["Holy Fire"] = 14914,
    ["Rip"] = 1079, ["Rupture"] = 1943, ["Serpent Sting"] = 1978, ["Pyroblast"] = 11366,
    ["Frostfire Bolt"] = 44614, ["Siphon Life"] = 18265,
    ["Rain of Fire"] = 5740, ["Hellfire"] = 1949, ["Blizzard"] = 10, ["Flamestrike"] = 2120,
    ["Consecration"] = 26573, ["Hurricane"] = 16914, ["Volley"] = 1510, ["Drain Life"] = 689,
    ["Drain Soul"] = 1120, ["Drain Mana"] = 5138, ["Health Funnel"] = 755, ["Mind Flay"] = 15407,
    ["Arcane Missiles"] = 5143, ["Starshards"] = 10797, ["Immolation Trap"] = 13795,
    ["Explosive Trap"] = 13813, ["Wyvern Sting"] = 19386,
}

local function addLocalizedNames()
    local getName = (C_Spell and C_Spell.GetSpellName) or GetSpellInfo
    if not getName then return end
    for _, list in ipairs({ KNOWN_TICK_INTERVALS, TICK_SHAPES, SCHOOL_BY_NAME, IGNORED_SPELLS, PROJECTILE_DOTS }) do
        local added = {}
        for englishName, value in pairs(list) do
            local id = SPELL_IDS[englishName]
            local ok, name = pcall(getName, id or 0)
            if id and ok and type(name) == "string" and name ~= "" and list[name] == nil then added[name] = value end
        end
        for name, value in pairs(added) do list[name] = value end
    end
end

-- Learned tick sizes persist in the nameplate profile; DoTs count from the cast unless the profile says to
-- wait for their first tick.
local db = { ticks = {}, waitFirstTick = "off" }
local dotsByTarget = {}     -- targetKey -> { [spellName] = dot }
local warnedSecretGuid = false

-- Recent tracker events, kept in memory for /kuidot.
local MAX_TRACE_LINES = 40
local traceLines = {}
local function trace(msg)
    table.insert(traceLines, string.format("%.1f %s", GetTime(), msg))
    if #traceLines > MAX_TRACE_LINES then table.remove(traceLines, 1) end
end

local function isSecret(v)
    if type(issecretvalue) ~= "function" then return false end
    local ok, r = pcall(issecretvalue, v)
    return ok and r or false
end

-- Stable key for the mob behind a unit token, or nil if the unit can't be tracked.
-- The same hit arrives for target, nameplateN and softenemy, and their GUIDs may not all be readable,
-- so a hidden GUID only affects that one unit token.
local function unitKey(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and not isSecret(guid) then return guid end
    if unit ~= "target" then return nil end
    if not warnedSecretGuid then
        warnedSecretGuid = true
        trace("Target GUID is secret; tracking DoTs on the current target only")
    end
    return "target"
end

-- The parsing below reads English descriptions. On a Spanish client the description is first rewritten
-- into the same English phrases ("25 p. de daño de Fuego durante 15 s" -> "25 Fire damage over 15 sec").
local SPANISH_SCHOOLS = {
    { "[Ff]\195\173sic[oa]", "Physical" }, { "[Ss]agrad[oa]", "Holy" }, { "[Ff]uego", "Fire" },
    { "[Nn]aturaleza", "Nature" }, { "[Ee]scarcha", "Frost" }, { "[Ss]ombras?", "Shadow" },
    { "[Aa]rcan[oa]", "Arcane" },
}

local function normalizeSpanish(desc)
    desc = desc:gsub("(%d)%.(%d%d%d)", "%1%2")               -- 1.234 -> 1234
    desc = desc:gsub("(%d),(%d)", "%1.%2")                    -- 1,5 -> 1.5
    desc = desc:gsub("[Mm]ovimiento final", "Finishing move")
    desc = desc:gsub("[Oo]torga (%d+) puntos? de combo", "Awards %1 combo point")
    desc = desc:gsub("^[Rr]ecubre", "Coats a weapon")
    desc = desc:gsub("^[Ss]ana", "Heals"):gsub("^[Cc]ura", "Heals")
    for _, school in ipairs(SPANISH_SCHOOLS) do desc = desc:gsub(school[1], school[2]) end
    desc = desc:gsub("p%. de ", ""):gsub("pts%. de ", "")
    local damageWord = "da" .. string.char(195, 177) .. "o"
    desc = desc:gsub("de " .. damageWord, "damage"):gsub(damageWord, "damage")
    desc = desc:gsub("de salud", "health"):gsub("salud", "health")
    desc = desc:gsub("damage de (%a+)", "%1 damage"):gsub("damage (%u%a+)", "%1 damage")
    desc = desc:gsub("(%d+) puntos?%s*:", "%1 points:")
    desc = desc:gsub("durante ", "over "):gsub("a lo largo de ", "over "):gsub("damage en (%d)", "damage over %1")
    desc = desc:gsub("cada ", "every "):gsub("[Dd]ura ", "Lasts ")
    desc = desc:gsub("(%d+%.?%d*) seg%a*%.?", "%1 sec."):gsub("(%d+%.?%d*) s%f[^%a]", "%1 sec")
    return desc
end

local function normalizeDescription(desc)
    if type(desc) ~= "string" or isSecret(desc) then return desc end
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "esES" or locale == "esMX" then return normalizeSpanish(desc) end
    return desc
end

local function spellNameAndDescription(spellID)
    local name, desc
    if C_Spell and C_Spell.GetSpellName then
        name = C_Spell.GetSpellName(spellID)
    else
        name = GetSpellInfo(spellID)
    end
    local descFn = (C_Spell and C_Spell.GetSpellDescription) or GetSpellDescription
    if descFn then desc = descFn(spellID) end
    return name, normalizeDescription(desc)
end

local function schoolFromWords(words)
    local school = SCHOOL_MASKS.Physical
    for word in words:gmatch("%a+") do
        if SCHOOL_MASKS[word] then school = SCHOOL_MASKS[word] end
    end
    return school
end

-- Finishers (Rip, Rupture) list their DoT per combo point:
--   "1 point : 243 damage over 12 sec. 2 points: 396 damage over 12 sec. ..."   (Rip; note the stray space)
--   "1 point: 25 damage over 8 secs\n ... 5 points: 87 damage over 16 secs"      (Rupture)
-- Returns total, school, duration for the given points (clamped to the listed range), or nil if the
-- finisher has no per-point DoT (e.g. Eviscerate).
local function parseFinisher(desc, comboPoints)
    local byPoints, highest = {}, 0
    for pointsText, amount, secs in desc:gmatch("(%d+) points?%s*:%s*(%d+) damage over (%d+%.?%d*) sec") do
        local points = tonumber(pointsText)
        byPoints[points] = { total = tonumber(amount), duration = tonumber(secs) }
        highest = math.max(highest, points)
    end
    if highest == 0 then return nil end
    local entry = byPoints[math.max(1, math.min(comboPoints, highest))] or byPoints[highest]
    return entry.total, SCHOOL_MASKS.Physical, entry.duration
end

-- Returns total damage, school mask, duration and (if the description states it) tick interval.
--   "... 10 Nature damage over 15 sec."  Takes the last such clause, so Immolate's
--       "11 Fire damage and then an additional 20 Fire damage over 15 sec" yields the periodic part.
--   "Transfers 15 health from the target to the caster every 3 sec. Lasts 30 sec."  (Siphon Life)
-- comboPoints is only used for finishers. (Rake/Garrote merely award a combo point, so finishers are
-- recognised by "Finishing move", not "combo point".)
local function parseEnglishDot(desc, comboPoints)
    if type(desc) ~= "string" or isSecret(desc) then return nil end
    if desc:find("Finishing move") then return parseFinisher(desc, comboPoints or 5) end
    -- Weapon enchants (rogue poisons) describe a proc DoT but aren't cast on the target. Match the enchant
    -- wording only: Lacerate's tooltip also mentions "weapon damage".
    if desc:find("[Cc]oats a weapon") then return nil end
    -- Heals over time: Forever's Renew reads "Heals the target of 830 damage over 15 sec".
    if desc:find("^Heals") then return nil end

    local total, school, duration
    for amount, words, secs in desc:gmatch("(%d+)%s*([%a ]-)%s*damage over (%d+%.?%d*) sec") do
        total, school, duration = tonumber(amount), schoolFromWords(words), tonumber(secs)
    end
    if total and duration > 0 then return total, school, duration end

    local amount, words, every = desc:match("(%d+)%s*([%a ]-)%s*damage every (%d+%.?%d*) sec")
    if not amount then
        amount, every = desc:match("(%d+) health.-every (%d+%.?%d*) sec")
        words = ""
    end
    local lasts = desc:match("[Ll]asts (%d+%.?%d*) sec")
    if amount and every and lasts then
        every, lasts = tonumber(every), tonumber(lasts)
        if every > 0 and lasts > 0 then
            return tonumber(amount) * math.floor(lasts / every + 0.5), schoolFromWords(words), lasts, every
        end
    end
end

---------------------------------------------------------------------------
-- Language-independent parsing
---------------------------------------------------------------------------

-- Other client languages word DoT descriptions differently, so when the English phrases above don't match,
-- the description is read by its numbers: in a sentence that names damage, a number followed by a time unit
-- is the duration (a second, smaller one is the tick interval) and the number closest to the damage word is
-- the damage. Finishers list "N <points>: damage ... duration" once per combo point count. The school is
-- left unknown unless the description names it in English, and is taken from the first tick instead.
local DAMAGE_WORDS = {
    "damage",
    "Damage",
    "da" .. string.char(195, 177) .. "o",
    "Da" .. string.char(195, 177) .. "o",
    "Schaden",
    "schaden",
    "d" .. string.char(195, 169) .. "g" .. string.char(195, 162) .. "ts",
    "D" .. string.char(195, 169) .. "g" .. string.char(195, 162) .. "ts",
    "danni",
    "danno",
    "dano",
    string.char(209, 131) .. string.char(209, 128) .. string.char(208, 190) .. string.char(208, 189),
    string.char(208, 163) .. string.char(209, 128) .. string.char(208, 190) .. string.char(208, 189),
    string.char(237, 148, 188) .. string.char(237, 149, 180),
    string.char(228, 188, 164) .. string.char(229, 174, 179),
    string.char(229, 130, 183) .. string.char(229, 174, 179),
}
local TIME_UNITS = {
    "seconds",
    "second",
    "secs",
    "sec",
    "segundos",
    "seg",
    "Sekunden",
    "Sek",
    "sek",
    "secondes",
    "seconde",
    "secondi",
    string.char(209, 129) .. string.char(208, 181) .. string.char(208, 186) .. string.char(209, 131) .. string.char(208, 189) .. string.char(208, 180),
    string.char(209, 129) .. string.char(208, 181) .. string.char(208, 186),
    string.char(236, 180, 136),
    string.char(231, 167, 146),
    "s",
}
local NBSP = string.char(194, 160)
local CJK_STOP = string.char(227, 128, 130) -- the ideographic full stop

local function normalizeNumbers(desc)
    local previous
    repeat
        previous = desc
        desc = desc:gsub("(%d)[%.,' ](%d%d%d)(%f[%D])", "%1%2%3"):gsub("(%d)" .. NBSP .. "(%d%d%d)", "%1%2")
    until desc == previous
    return (desc:gsub("(%d),(%d)", "%1.%2"))
end

local function isTimeUnit(rest)
    rest = rest:gsub("^[%s]+", ""):gsub("^" .. NBSP, "")
    for _, unit in ipairs(TIME_UNITS) do
        if rest:sub(1, #unit) == unit then
            local after = rest:sub(#unit + 1, #unit + 1)
            if unit:byte(1) > 127 or after == "" or not after:find("^%a") then return true end
        end
    end
    return false
end

-- Numbers in the description with their sentence, position and what follows them.
local function tokenize(desc)
    -- A sentence ends at a full stop followed by a capital letter: "15 Sek. 60 Schaden" is one sentence.
    local text = normalizeNumbers(desc):gsub("%.%s+(%u)", "\n%1"):gsub(CJK_STOP, "\n")
    local tokens, sentences = {}, {}
    local index = 0
    for sentence in text:gmatch("[^\n]+") do
        index = index + 1
        sentences[index] = sentence
        for start, number, stop in sentence:gmatch("()(%d+%.?%d*)()") do
            local rest = sentence:sub(stop)
            local between = rest:match("^([^%d]-)[:" .. string.char(239, 188, 154) .. "]")
            table.insert(tokens, {
                value = tonumber(number), sentence = index, at = start,
                percent = rest:find("^%s*%%") ~= nil,
                time = isTimeUnit(rest),
                colon = between ~= nil and #between <= 16,
            })
        end
    end
    return tokens, sentences
end

local function damageWordAt(sentence)
    for _, word in ipairs(DAMAGE_WORDS) do
        local at = sentence:find(word, 1, true)
        if at then return at end
    end
end

local function englishSchool(desc)
    for word, mask in pairs(SCHOOL_MASKS) do
        if desc:find("%f[%a]" .. word .. "%f[%A]") then return mask end
    end
end

-- Per combo point entries: { [points] = { total, duration } }, or nil if the description has fewer than two.
local function genericFinisher(tokens)
    local byPoints, count, highest = {}, 0, 0
    for i, token in ipairs(tokens) do
        local amount, duration = tokens[i + 1], tokens[i + 2]
        if token.colon and token.value >= 1 and token.value <= 5 and token.value % 1 == 0
            and amount and not amount.time and duration and duration.time then
            byPoints[token.value] = { total = amount.value, duration = duration.value }
            count, highest = count + 1, math.max(highest, token.value)
        end
    end
    if count < 2 then return nil end
    return byPoints, highest
end

local function parseGeneric(desc, comboPoints)
    local tokens, sentences = tokenize(desc)
    local school = englishSchool(desc)
    local byPoints, highest = genericFinisher(tokens)
    if byPoints then
        local entry = byPoints[math.max(1, math.min(comboPoints or 1, highest))] or byPoints[highest]
        return entry.total, school or SCHOOL_MASKS.Physical, entry.duration
    end
    local found
    for index, sentence in ipairs(sentences) do
        local damageAt = damageWordAt(sentence)
        if damageAt then
            local amount, times = nil, {}
            for _, token in ipairs(tokens) do
                if token.sentence == index and not token.percent then
                    if token.time then
                        table.insert(times, token.value)
                    elseif not amount or math.abs(token.at - damageAt) < math.abs(amount.at - damageAt) then
                        amount = token
                    end
                end
            end
            if amount and #times > 0 then found = { amount = amount.value, times = times, sentence = index } end
        end
    end
    if not found then return nil end
    local times = found.times
    if #times == 1 then
        -- "every 3 sec. Lasts 30 sec.": the duration is in a later sentence.
        for _, token in ipairs(tokens) do
            if token.sentence > found.sentence and token.time and token.value > times[1] then
                times[2] = token.value
                break
            end
        end
    end
    if #times >= 2 then
        local every, lasts = math.min(times[1], times[2]), math.max(times[1], times[2])
        if every <= 0 then return nil end
        return found.amount * math.floor(lasts / every + 0.5), school, lasts, every
    end
    if times[1] <= 0 then return nil end
    return found.amount, school, times[1]
end

local function parseDot(desc, comboPoints)
    if type(desc) ~= "string" or isSecret(desc) then return nil end
    local total, school, duration, interval = parseEnglishDot(desc, comboPoints)
    if total then return total, school, duration, interval end
    if desc:find("Finishing move") or desc:find("[Cc]oats a weapon") or desc:find("^Heals") then return nil end
    return parseGeneric(desc, comboPoints)
end

---------------------------------------------------------------------------
-- DoT tracking
---------------------------------------------------------------------------

-- Best known average damage per tick: observed average of non-crit ticks, else learned from earlier casts,
-- else the description. Crits are one-offs, so they never raise the expectation for later ticks. For shaped
-- DoTs (TICK_SHAPES) ticks are stored divided by their factor, so this is the average tick, not the latest.
local function expectedTick(dot)
    if dot.normalTicks > 0 then return dot.tickSum / dot.normalTicks end
    return (dot.tickKey and db.ticks[dot.tickKey]) or (dot.total / dot.totalTicks)
end

-- Which tick of the DoT (1 = first) lands around `when`.
local function tickNumberAt(dot, when)
    return math.max(1, math.floor((when - dot.appliedAt) / dot.interval + 0.5))
end

-- The factor for tick `number` (1 for evenly ticking DoTs). Shapes are stretched to the DoT's tick count.
local function tickShape(dot, number)
    local shape = dot.shape
    if not shape then return 1 end
    local i = math.ceil(math.min(math.max(number, 1), dot.totalTicks) / dot.totalTicks * #shape)
    return shape[math.max(1, math.min(i, #shape))]
end

-- A waiting DoT doesn't count toward the marker until its first tick lands (see WAIT_MODES).
-- A doubtful DoT (an avoid right after the cast that may not have been its own) always waits.
local function isWaiting(dot)
    if dot.ticksSeen > 0 then return false end
    if dot.doubtful or db.waitFirstTick == "always" then return true end
    return db.waitFirstTick == "unsure" and dot.unsure
end

-- Combo points, for finishers. By UNIT_SPELLCAST_SUCCEEDED they're already spent, so they're read when the
-- cast is sent. They were unreadable in combat on the Forever beta, so the addon also counts them itself:
-- builders say "Awards N combo point(s)" in their tooltips; a dodge/parry/miss right after takes them back;
-- a finisher or a target change resets the count. If neither source knows, finishers assume the lowest
-- entry, so the estimate errs low (no false skull) and nothing is learned from that cast.
local COMBO_CAP = 5
local COMBO_CACHE_SECONDS = 3
local comboAtSend, lastComboPoints, lastComboAt = nil, nil, 0
local countedPoints = 0

-- Cast outcomes. UNIT_COMBAT reports a dodge/parry/miss/resist/immune on the target, but not which attack it
-- belongs to. A cast's own result arrives almost at once (same frame in the logs), so the first outcome on the
-- target right after a cast decides: a hit means it landed, an avoid means it didn't. A melee auto-attack
-- avoided in that instant is rare; it makes the addon drop a DoT that landed, which errs low (never a false
-- kill). Results can also arrive just before the cast event, hence the short look-back.
local OUTCOME_WINDOW = 0.4
local OUTCOME_LOOKBACK = 0.25
local AVOIDED_ACTIONS = {
    MISS = true, DODGE = true, PARRY = true, EVADE = true, IMMUNE = true, DEFLECT = true, RESIST = true, REFLECT = true,
}
-- Spells can't be dodged or parried: next to a spell DoT, these were someone's melee (usually the pet's).
local MELEE_ONLY_AVOIDS = { DODGE = true, PARRY = true, DEFLECT = true }
local lastBuilder    -- { key, points, at }: builder whose outcome isn't known yet
local lastDotCast    -- { key, name, dot, previous, at }: DoT cast whose outcome isn't known yet
local lastOutcome    -- { key, avoided, action, school, at }: most recent outcome on a mob
-- The mob each cast was aimed at, by cast GUID, taken when the cast is sent. An instant DoT's
-- UNIT_SPELLCAST_SUCCEEDED comes a server round trip later, and a player who tabs to the next mob straight
-- away has changed target by then: the DoT used to be put on the new target.
local sentTargets = {} -- castGUID -> { key, at }
local SENT_TARGET_SECONDS = 10

local function describeReading(ok, value)
    if not ok then return "error" end
    if value == nil then return "nil" end
    if isSecret(value) then return "secret" end
    return tostring(value)
end

-- Returns the best plain reading (or nil) and a description of what each API returned, for the log.
local function readComboPoints()
    local best, parts = nil, {}
    local function consider(label, ok, points)
        table.insert(parts, label .. "=" .. describeReading(ok, points))
        if ok and type(points) == "number" and not isSecret(points) then best = math.max(best or 0, points) end
    end
    if GetComboPoints then consider("GetComboPoints", pcall(GetComboPoints, "player", "target")) end
    if UnitPower and Enum and Enum.PowerType and Enum.PowerType.ComboPoints then
        consider("UnitPower", pcall(UnitPower, "player", Enum.PowerType.ComboPoints))
    end
    return best, table.concat(parts, " ")
end

local function rememberComboPoints()
    local points = readComboPoints()
    if points and points > 0 then lastComboPoints, lastComboAt = points, GetTime() end
    return points
end

local function isFinisherDescription(desc)
    if type(desc) ~= "string" or isSecret(desc) then return false end
    return desc:find("Finishing move") ~= nil or genericFinisher((tokenize(desc))) ~= nil
end

local function onCastSent(spellID, castGUID)
    local now = GetTime()
    for guid, sent in pairs(sentTargets) do
        if now - sent.at > SENT_TARGET_SECONDS then sentTargets[guid] = nil end
    end
    if castGUID and not isSecret(castGUID) then sentTargets[castGUID] = { key = unitKey("target"), at = now } end
    local ok, _, desc = pcall(spellNameAndDescription, spellID)
    if not ok or not isFinisherDescription(desc) then return end
    local points, readings = readComboPoints()
    comboAtSend = points
    trace("COMBO at send: " .. readings .. ", counted=" .. countedPoints)
end

-- The mob a cast went to: the target when it was sent, else (no send seen) the target now.
local function castTargetKey(castGUID)
    local sent = castGUID and not isSecret(castGUID) and sentTargets[castGUID]
    if not sent then return unitKey("target") end
    sentTargets[castGUID] = nil
    return sent.key
end

-- An avoid on `key` that arrived just before the cast event (see OUTCOME_LOOKBACK), or nil.
local function avoidJustBefore(key)
    if lastOutcome and lastOutcome.avoided and lastOutcome.key == key
        and GetTime() - lastOutcome.at <= OUTCOME_LOOKBACK then
        return lastOutcome
    end
end

-- A builder was cast: count its points unless it was already avoided, else wait for its outcome.
local function onBuilderCast(key, points)
    local avoided = avoidJustBefore(key)
    if avoided then
        trace("COMBO builder " .. avoided.action .. " (before cast event), counted=" .. countedPoints)
        return
    end
    countedPoints = math.min(COMBO_CAP, countedPoints + points)
    lastBuilder = { key = key, points = points, at = GetTime() }
end

-- A DoT cast whose result was avoided isn't on the target: drop it. (Waiting for a first tick to prove it
-- instead doesn't work for bleeds: melee white hits look just like ticks.) A recast replaced a DoT that is
-- still ticking, so that one is put back.
-- Spell DoTs are different: the pet and other players' melee miss all the time, and their ticks are told apart
-- from melee by school. So an avoid that can't be the spell's is ignored, and one that might not be (not
-- reported in the spell's school) makes a new DoT wait for its first tick instead of dropping it.
-- Returns false if the avoid was ignored, so the cast's own outcome may still come.
local function removeAvoidedDot(cast, action, school)
    local dot = cast.dot
    local dots = dotsByTarget[cast.key]
    if not dots or dots[cast.name] ~= dot then return true end
    local spellSchool = type(school) == "number" and not isSecret(school) and school == dot.school
    if dot.school ~= SCHOOL_MASKS.Physical and not spellSchool then
        if MELEE_ONLY_AVOIDS[action] then
            trace(string.format("AVOID %s (school %s) right after %s: not the spell, ignored", action,
                tostring(school), cast.name))
            return false
        end
        if not cast.previous then
            dot.doubtful = true
            trace(string.format("AVOID %s (school %s) right after %s: may be someone else's, waiting for its first tick",
                action, tostring(school), cast.name))
            return true
        end
    end
    if cast.previous then
        dots[cast.name] = cast.previous
        trace(string.format("AVOID %s (school %s) right after %s recast; keeping the earlier one", action,
            tostring(school), cast.name))
    else
        dots[cast.name] = nil
        trace(string.format("AVOID %s (school %s) right after %s; dropped", action, tostring(school), cast.name))
    end
    return true
end

local function onAvoided(key, action, school)
    local now = GetTime()
    lastOutcome = { key = key, avoided = true, action = action, school = school, at = now }
    if lastBuilder and lastBuilder.key == key then
        if now - lastBuilder.at <= OUTCOME_WINDOW then
            countedPoints = math.max(0, countedPoints - lastBuilder.points)
            trace("COMBO builder " .. action .. ", counted=" .. countedPoints)
        end
        lastBuilder = nil
    end
    if lastDotCast and lastDotCast.key == key then
        if now - lastDotCast.at > OUTCOME_WINDOW or removeAvoidedDot(lastDotCast, action, school) then
            lastDotCast = nil
        end
    end
end

-- A hit on a mob: the pending casts on it landed (a later avoid belongs to something else). For a spell DoT
-- only a hit in its school says so (Immolate's direct damage); a melee hit is someone else's.
local function onHit(key, school)
    lastOutcome = { key = key, avoided = false, at = GetTime() }
    if lastBuilder and lastBuilder.key == key then lastBuilder = nil end
    if lastDotCast and lastDotCast.key == key
        and (lastDotCast.dot.school == SCHOOL_MASKS.Physical or lastDotCast.dot.school == school) then
        lastDotCast = nil
    end
end

local function resetComboCount()
    countedPoints, lastBuilder = 0, nil
end

-- Returns points and where they came from, or nil and "unknown".
local function comboPointsForCast()
    local points, source = comboAtSend, "read"
    if not (points and points > 0) then
        if lastComboPoints and GetTime() - lastComboAt <= COMBO_CACHE_SECONDS then
            points, source = lastComboPoints, "cached"
        elseif countedPoints > 0 then
            points, source = countedPoints, "counted"
        else
            points, source = nil, "unknown"
        end
    end
    comboAtSend = nil
    resetComboCount()
    return points, source
end

-- Returns the target key the DoT was applied to, or nil if the cast wasn't a tracked DoT.
local function onPlayerCast(spellID, castGUID)
    local key = castTargetKey(castGUID)
    local ok, name, desc = pcall(spellNameAndDescription, spellID)
    if not ok or not name or isSecret(name) then
        trace("CAST spell " .. (isSecret(spellID) and "secret" or tostring(spellID)) .. ": name not readable")
        return
    end
    if type(desc) == "string" and not isSecret(desc) then
        local awarded = tonumber(desc:match("Awards (%d+) combo point"))
        if awarded then onBuilderCast(key, awarded) end
    end
    if IGNORED_SPELLS[name] then return end
    local isFinisher = isFinisherDescription(desc)
    local comboPoints, comboSource
    if isFinisher then comboPoints, comboSource = comboPointsForCast() end
    -- Unknown points: parse the lowest entry (errs low), and don't use or teach learned tick sizes.
    local total, school, duration, statedInterval = parseDot(desc, comboPoints or 1)
    if not total then
        local text = (type(desc) == "string" and not isSecret(desc)) and desc:sub(1, 90) or "unreadable"
        trace("SKIP " .. name .. ": no DoT found in: " .. text)
        return
    end
    -- A finisher's tick size depends on the points spent, so learned sizes are kept per point count.
    local tickKey = spellID
    if isFinisher then tickKey = comboPoints and (spellID .. "x" .. comboPoints) or nil end

    if not key then return end

    local now = GetTime()
    local interval = statedInterval or KNOWN_TICK_INTERVALS[name] or DEFAULT_TICK_INTERVAL
    school = SCHOOL_BY_NAME[name] or school
    dotsByTarget[key] = dotsByTarget[key] or {}
    local previous = dotsByTarget[key][name]
    dotsByTarget[key][name] = {
        spellID = spellID,
        tickKey = tickKey,
        school = school,
        total = total,
        duration = duration,
        interval = interval,
        totalTicks = math.max(1, math.floor(duration / interval + 0.5)),
        shape = TICK_SHAPES[name],
        travel = PROJECTILE_DOTS[name] and PROJECTILE_TRAVEL or nil,
        appliedAt = now,
        expiresAt = now + duration,
        nextTickAt = now + interval,
        tickSum = 0,        -- non-crit ticks only
        normalTicks = 0,
        ticksSeen = 0,      -- including crits
        missed = 0,
    }
    local dot = dotsByTarget[key][name]
    lastDotCast = { key = key, name = name, dot = dot, previous = previous, at = now }
    local learned = tickKey and db.ticks[tickKey]
    -- The starting estimate is shaky without a learned tick size (description numbers leave out spell power
    -- and attack power) or, for finishers, without knowing the combo points.
    dot.unsure = not learned
    trace(string.format("CAST %s (id %d)%s: %d dmg over %ss, school %s, tick every %ss, per-tick %s%s%s", name, spellID,
        isFinisher and string.format(" %s combo points (%s)", comboPoints or "?", comboSource) or "",
        total, duration, tostring(school or "unknown"), interval, learned and ("learned " .. learned) or "from description",
        isWaiting(dot) and ", waiting for first tick" or "",
        key ~= unitKey("target") and (" on " .. tostring(key) .. ", the target when sent") or ""))
    local avoided = avoidJustBefore(key)
    if avoided and removeAvoidedDot(lastDotCast, avoided.action, avoided.school) then
        lastDotCast = nil
        if dotsByTarget[key] and dotsByTarget[key][name] == dot then return key, isWaiting(dot) end
        return nil
    end
    return key, isWaiting(dot)
end

-- Seconds between now and the nearest expected tick time, and that tick's index. Anchored on the first tick
-- once seen (ticks keep its rhythm; anchoring on the latest tick would let jitter add up), else on the cast.
-- Using the nearest multiple of the interval means one missed tick doesn't lose the DoT.
local function distanceToExpectedTick(dot, now)
    local anchor = dot.firstTickAt or dot.appliedAt
    if not dot.firstTickAt and dot.travel then
        -- Still in flight: the DoT started anywhere up to `travel` seconds after the cast.
        local late = now - (anchor + dot.interval)
        if late > 0 then anchor = anchor + math.min(late, dot.travel) end
    end
    local k =math.max(1, math.floor((now - anchor) / dot.interval + 0.5))
    return math.abs(now - (anchor + k * dot.interval)), k
end

local function plausibleTickAmount(dot, amount, isCrit, number)
    local known, tolerance
    if dot.normalTicks > 0 then
        known, tolerance = dot.tickSum / dot.normalTicks, TICK_AMOUNT_TOLERANCE
    else
        known, tolerance = dot.tickKey and db.ticks[dot.tickKey], FIRST_TICK_AMOUNT_TOLERANCE
    end
    if not known then return true end
    known = known * tickShape(dot, number)
    if isCrit then
        return amount >= known * CRIT_MIN_RATIO - 1 and amount <= known * CRIT_MAX_RATIO + 1
    end
    return math.abs(amount - known) <= math.max(1, known * tolerance)
end

-- Tick size to judge a same-slot collision by: the average of the DoT's earlier ticks, or with fewer than two
-- ticks the description's per-tick share. Deliberately not the learned size, which is what a collision can
-- corrupt.
local function referenceTickSize(dot)
    if dot.normalTicks > 1 then
        return (dot.tickSum - dot.lastTickAmount / dot.lastTickShape) / (dot.normalTicks - 1)
    end
    return dot.total / dot.totalTicks
end

local function saveLearnedTick(dot)
    if dot.tickKey and dot.normalTicks > 0 then
        db.ticks[dot.tickKey] = math.floor(dot.tickSum / dot.normalTicks * 10 + 0.5) / 10
        local profile = _G.KullThranUINameplatesDB
        if type(profile) == "table" and profile.dotDamageTicks == nil then profile.dotDamageTicks = db.ticks end
    end
end

-- Moves a DoT's tick bookkeeping to the tick in slot `index` that landed at `now`.
local function anchorTick(dot, index, now)
    dot.missed = 0
    if dot.firstTickAt then
        dot.lastTickIndex = index
    else
        dot.firstTickAt, dot.lastTickIndex = now, 0
        -- A projectile DoT started when it landed: count its ticks from there.
        if dot.travel then dot.appliedAt = now - index * dot.interval end
    end
    dot.lastTickAt = now
    dot.nextTickAt = now + dot.interval
    -- Re-anchor expiry on the observed tick: ticks arrive slightly after their nominal time, and an
    -- expiry based on the cast event would otherwise cut off the final tick.
    local tickIndex = math.max(1, math.floor((now - dot.appliedAt) / dot.interval + 0.5))
    dot.expiresAt = now + (dot.totalTicks - tickIndex) * dot.interval
    return tickIndex
end

-- Two same-school hits in one tick slot (e.g. Shadow Bolt landing with a Corruption tick, log 123506.4): the
-- first one was taken as the tick. If this one is closer to the expected size, it was the real tick.
local SAME_SLOT_SECONDS = 0.2
local function trySwapSameSlot(dot, name, amount, isCrit, now)
    if isCrit or dot.lastTickCrit or not dot.lastTickAt or now - dot.lastTickAt > SAME_SLOT_SECONDS then
        return false
    end
    local factor = dot.lastTickShape
    local reference = referenceTickSize(dot) * factor
    if math.abs(amount - reference) >= math.abs(dot.lastTickAmount - reference) then return false end
    trace(string.format("SWAP %s tick: %d was another hit, %d is the tick", name, dot.lastTickAmount, amount))
    dot.tickSum = dot.tickSum + (amount - dot.lastTickAmount) / factor
    dot.lastTickAmount = amount
    saveLearnedTick(dot)
    return true
end

-- A learned size that's wrong rejects every real tick (log: Corruption learned 29 from Shadow Bolts, real ticks
-- 10-11, every cast dropped). Hits rejected only on size, but landing on the DoT's rhythm in two consecutive
-- slots and agreeing with each other, are the real ticks: relearn from them.
local function tryRelearn(dot, name, amount, isCrit, index, distance, now)
    local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
    local freshSlot = not dot.firstTickAt or index > dot.lastTickIndex
    if isCrit or not freshSlot or distance > window then return false end
    local previous = dot.offBeatCandidate
    local factor = tickShape(dot, tickNumberAt(dot, now))
    local average = amount / factor
    dot.offBeatCandidate = { index = index, amount = amount, average = average, at = now }
    if not previous or index ~= previous.index + 1
        or math.abs(average - previous.average) > math.max(1, previous.average * TICK_AMOUNT_TOLERANCE) then
        return false
    end
    trace(string.format("RELEARN %s: ticks of %d and %d on its rhythm didn't fit %.1f/tick", name,
        previous.amount, amount, expectedTick(dot)))
    dot.offBeatCandidate = nil
    dot.tickSum, dot.normalTicks = previous.average + average, 2
    dot.ticksSeen = dot.ticksSeen + 2
    dot.lastTickAmount, dot.lastTickShape, dot.lastTickCrit = amount, factor, false
    saveLearnedTick(dot)
    if not dot.firstTickAt then
        dot.firstTickAt, dot.lastTickIndex = previous.at, 0
        index = 1
    end
    anchorTick(dot, index, now)
    return true
end

-- Returns the target key when this hit was the first tick of a DoT that was waiting for it (so the display
-- can flash now that the DoT shows), else nil.
local lastCombatSignature
local function onUnitCombat(unit, action, flag, amount, school)
    if isSecret(action) then return end
    if not AVOIDED_ACTIONS[action] and action ~= "WOUND" then return end
    local key = unitKey(unit)
    if not key then return end
    if AVOIDED_ACTIONS[action] then return onAvoided(key, action, school) end
    onHit(key, school)
    if isSecret(amount) or isSecret(school) or type(amount) ~= "number" then return end
    local isCrit = not isSecret(flag) and flag == "CRITICAL"
    local dots = dotsByTarget[key]
    if not dots then return end

    -- The same hit fires for target, nameplateN, softenemy...: handle it once.
    local now = GetTime()
    local signature = key .. ":" .. amount .. ":" .. school .. ":" .. now
    if signature == lastCombatSignature then return end
    lastCombatSignature = signature

    local best, bestName, bestDistance, bestIndex
    for name, dot in pairs(dots) do
        -- A DoT read from a description without a school takes the school of its first tick.
        if (dot.school == school or dot.school == nil) and plausibleTickAmount(dot, amount, isCrit, tickNumberAt(dot, now)) then
            local distance, index = distanceToExpectedTick(dot, now)
            local window = dot.firstTickAt and TICK_MATCH_WINDOW_ANCHORED or TICK_MATCH_WINDOW
            -- Each tick slot takes one hit: a second hit near an already-matched tick is someone else's.
            local freshSlot = not dot.firstTickAt or index > dot.lastTickIndex
            if freshSlot and distance <= window and (not bestDistance or distance < bestDistance) then
                best, bestName, bestDistance, bestIndex = dot, name, distance, index
            end
        end
    end
    if not best then
        -- Not a tick as things stand; it may still correct one (same-slot swap, or a wrong learned size).
        for name, dot in pairs(dots) do
            if dot.school == school or dot.school == nil then
                local distance, index = distanceToExpectedTick(dot, now)
                local wasWaiting = isWaiting(dot)
                if trySwapSameSlot(dot, name, amount, isCrit, now) then return end
                if tryRelearn(dot, name, amount, isCrit, index, distance, now) then
                    return wasWaiting and key or nil
                end
            end
        end
        trace(string.format("HIT %d%s school %d on %s not matched to a DoT", amount, isCrit and " (crit)" or "",
            school, unit))
        return
    end

    local wasWaiting = isWaiting(best)
    best.school = best.school or school
    local factor = tickShape(best, tickNumberAt(best, now))
    best.ticksSeen = best.ticksSeen + 1
    best.lastTickAmount, best.lastTickShape, best.lastTickCrit = amount, factor, isCrit
    best.offBeatCandidate = nil
    if not isCrit then
        best.tickSum = best.tickSum + amount / factor
        best.normalTicks = best.normalTicks + 1
        saveLearnedTick(best)
    end
    local tickIndex = anchorTick(best, bestIndex, now)
    trace(string.format("TICK %s %d%s on %s (tick %d/%d, expecting %.1f for this tick)%s", bestName, amount,
        isCrit and " CRIT" or "", unit, tickIndex, best.totalTicks, expectedTick(best) * factor,
        wasWaiting and ", now shown" or ""))
    if wasWaiting then return key end
end

-- Whether hits on a mob reach the addon right now. UNIT_COMBAT only reports unit tokens (the target, focus and
-- visible nameplates), so a mob you tabbed away from, with nameplates off or out of their range, ticks unseen.
-- Its DoTs used to be dropped as "never ticked", which lost every earlier mob when chain pulling.
local function isObservable(key)
    if unitKey("target") == key or unitKey("focus") == key then return true end
    for i = 1, 40 do
        local unit = "nameplate" .. i
        if UnitExists(unit) and unitKey(unit) == key then return true end
    end
    return false
end

local function housekeep(now)
    for key, dots in pairs(dotsByTarget) do
        for name, dot in pairs(dots) do
            local late = (dot.ticksSeen == 0 and dot.travel) or 0
            while dot.nextTickAt < now - TICK_MATCH_WINDOW - late and dot.nextTickAt <= dot.expiresAt do
                dot.nextTickAt = dot.nextTickAt + dot.interval
                -- Only a tick that could have been seen counts as missed.
                if dot.ticksSeen == 0 and isObservable(key) then dot.missed = dot.missed + 1 end
            end
            if now > dot.expiresAt + TICK_MATCH_WINDOW then
                dots[name] = nil
                trace("EXPIRE " .. name)
            elseif dot.ticksSeen == 0 and dot.missed >= MISSED_TICKS_BEFORE_DROP then
                dots[name] = nil
                trace("DROP " .. name .. " never ticked (resisted or immune?)")
            end
        end
        if next(dots) == nil then dotsByTarget[key] = nil end
    end
end

local function remainingDamage(dot)
    if dot.nextTickAt > dot.expiresAt + dot.interval / 2 then return 0 end
    local ticksLeft = math.floor((dot.expiresAt - dot.nextTickAt) / dot.interval + 0.5) + 1
    if not dot.shape then return ticksLeft * expectedTick(dot) end
    local average, total = expectedTick(dot), 0
    for number = math.max(1, dot.totalTicks - ticksLeft + 1), dot.totalTicks do
        total = total + average * tickShape(dot, number)
    end
    return total
end

-- Remaining damage per DoT on a mob (by unitKey), oldest application first. DoTs still waiting for their first
-- tick are left out.
local function dotBreakdown(key)
    local dots = key and dotsByTarget[key]
    local list = {}
    if not dots then return list end
    for name, dot in pairs(dots) do
        if not isWaiting(dot) then
            table.insert(list, { name = name, school = dot.school, appliedAt = dot.appliedAt,
                damage = remainingDamage(dot) })
        end
    end
    table.sort(list, function(a, b) return a.appliedAt < b.appliedAt end)
    return list
end

---------------------------------------------------------------------------
-- Public API and events
---------------------------------------------------------------------------

local function IsEnabled()
    local profile = _G.KullThranUINameplatesDB
    return profile and profile.dotDamageEnabled == true
end

local lastHousekeep = 0

-- What your DoTs on the mob behind `unit` will still deal, and how many DoTs count toward it.
function ns.DotBreakdownForUnit(unit)
    local now = GetTime()
    if now ~= lastHousekeep then
        lastHousekeep = now
        housekeep(now)
    end
    local list = dotBreakdown(unitKey(unit))
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.damage end
    return list, total
end

function ns.DotTrackerLog()
    return traceLines
end

function ns.ResetDotTicks()
    wipe(db.ticks)
end

function ns.DotDamageForUnit(unit)
    local list, total = ns.DotBreakdownForUnit(unit)
    return math.floor(total + 0.5), #list
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
frame:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")   -- combo points, before a finisher spends them
frame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")   -- keeps a recent combo point reading as backup
frame:RegisterEvent("UNIT_COMBAT")
-- Never register COMBAT_LOG_EVENT_UNFILTERED: it is a protected call on these clients.

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        addLocalizedNames()
        return
    end
    if not IsEnabled() then return end
    -- Learned tick sizes are read from the profile, never written at login: on Forever the nameplate module
    -- only adopts the saved profile if the table is still empty when it initializes.
    local profile = _G.KullThranUINameplatesDB
    if type(profile) == "table" and type(profile.dotDamageTicks) == "table" then db.ticks = profile.dotDamageTicks end
    db.waitFirstTick = _G.KullThranUINameplatesDB.dotDamageWaitFirstTick or "off"
    if event == "PLAYER_TARGET_CHANGED" then
        dotsByTarget.target = nil -- only used when the target's GUID is secret
        resetComboCount() -- combo points belong to the target they were built on
    elseif event == "UNIT_SPELLCAST_SENT" then
        local _, _, castGUID, spellID = ...
        onCastSent(spellID, castGUID)
    elseif event == "UNIT_POWER_FREQUENT" then
        local _, powerType = ...
        if not isSecret(powerType) and powerType == "COMBO_POINTS" then rememberComboPoints() end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, castGUID, spellID = ...
        onPlayerCast(spellID, castGUID)
    elseif event == "UNIT_COMBAT" then
        onUnitCombat(...)
    end
end)
