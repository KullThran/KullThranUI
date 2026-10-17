-------------------------------------------------------------------------------
--  Crowd control spell catalog for the portrait auras.
--
--  The client flags most crowd control itself (CROWD_CONTROL), but not all of it, and a
--  spell-id list also catches the older ranked spells of the Forever client. These lists are
--  merged into one candidate filter at load, keeping ONLY ids that exist on the running
--  client (C_Spell.DoesSpellExist), so one catalog serves Retail and Forever:
--      * ids that only exist on Retail drop out on Forever, and the other way round;
--      * a ranked Classic spell keeps every rank id.
--
--  The engine only honours a harmful spell-id map on a unit you cannot assist, so this
--  catalog works on enemies; the client's own CROWD_CONTROL flag covers the rest.
--
--  Each entry is a spell (aura) id.
-------------------------------------------------------------------------------
local KT = _G.KullThranUI
local S = KT.PortraitAuraShared or {}
KT.PortraitAuraShared = S

local C = {}
S.Catalog = C


C.groups = {}

-- Stuns
C.groups.stun = {
    -- Death Knight
    108194, 221562, 91800, 91797, 207167,
    -- Demon Hunter
    179057, 200166, 211881, 208618,
    -- Druid
    5211, 6798, 8983, 22570, 49802, 203123, 9005, 9823, 9827, 27006, 163505,
    -- Hunter
    24394, 117526, 19577, 90337, 19410,
    -- Mage
    44572, 31661, 33041, 33042, 33043, 82691, 157997,
    -- Monk
    119381, 120086, 119392, 232055,
    -- Paladin
    853, 5588, 5589, 10308, 105421,
    -- Priest
    64044, 200200, 200196, 44041, 44043, 44044, 44045, 44046, 44047, 15269,
    -- Rogue
    408, 8643, 1833, 199804, 5530,
    -- Shaman
    118905, 305485, 39796, 204399, 197214,
    -- Warlock
    30283, 30413, 30414, 89766, 22703, 171017, 171018,
    -- Warrior
    132169, 132168, 105771, 107570, 7922, 12809, 20253, 20614, 20615, 25273, 25274, 12798, 46968,
    -- Evoker
    372245, 360806,
    -- Racial
    20549, 255723, 287712, 107079,
}

-- Incapacitates, polymorph and similar effects
C.groups.incapacitate = {
    -- Mage polymorph (and every ranked Classic polymorph)
    118, 12824, 12825, 12826, 28271, 28272, 61025, 61305, 61721, 61780, 126819,
    161353, 161354, 161355, 161372, 277787, 277792, 321395, 391622, 383121,
    -- Druid
    99, 2637, 18657, 18658, 33786, 209753,
    -- Hunter
    3355, 14308, 14309, 203337, 19386, 24132, 24133, 27068, 19503, 213691, 1513, 14326, 14327,
    -- Monk
    115078, 198909,
    -- Paladin
    20066, 2878, 5627, 10326,
    -- Priest
    9484, 9485, 10955, 605, 10911, 10912, 205364, 375901,
    -- Rogue
    1776, 6770, 2070, 11297, 51724, 2094,
    -- Shaman
    51514, 210873, 211004, 211010, 211015, 269352, 277778, 277784, 309328,
    -- Warlock
    710, 18647, 6358, 115268, 1098, 11725, 11726,
    -- Demon Hunter
    217832, 221527,
}

-- Fears, horrors and disorients
C.groups.fear = {
    -- Warlock
    5782, 6213, 6215, 118699, 5484, 17928, 6789, 17925, 17926,
    -- Priest
    8122, 8124, 10888, 10890,
    -- Warrior
    5246, 316593, 316595, 386071,
    -- Demon Hunter
    207685, 207684,
    -- Monk
    116844,
}

-- Roots
C.groups.root = {
    -- Druid
    339, 1062, 5195, 5196, 9852, 9853, 26989, 102359, 45334, 19675,
    16689, 16810, 16811, 16812, 16813, 17329, 27009,
    -- Mage
    122, 865, 6131, 10230, 27088, 33395, 12494, 12497, 199786, 228600, 378760,
    -- Hunter
    19185, 19306, 20909, 20910, 53148, 190925, 393456, 162480,
    -- Shaman
    64695, 51485, 285515,
    -- Priest
    108920, 114404,
    -- Death Knight
    233395,
    -- Evoker
    355689,
}

-- Silences and interrupt lockouts shown as auras
C.groups.silence = {
    -- Death Knight
    47476,
    -- Demon Hunter
    204490, 202137,
    -- Druid
    78675, 81261,
    -- Hunter
    34490, 202933,
    -- Mage
    18469, 55021,
    -- Monk
    116705,
    -- Paladin
    31935, 217824,
    -- Priest
    15487, 199683,
    -- Rogue
    1330, 18425,
    -- Warlock
    24259, 196364, 19647, 115781, 132409,
    -- Warrior
    72, 18498,
    -- Evoker
    351338,
    -- Racial: Arcane Torrent
    25046, 28730, 50613, 69179, 80483, 129597, 155145, 202719, 232633, 33390, 36022, 47779, 222783,
}

-- Disarms. The game does not flag these as anything, so this list is their only filter.
C.groups.disarm = {
    207777,  -- Dismantle (Rogue)
    236077,  -- Disarm (Warrior)
    233759,  -- Grapple Weapon (Monk)
    407032,  -- Sticky Tar Bomb (Hunter)
    407031,
    209749,  -- Faerie Swarm (Druid)
    676,     -- Disarm (Classic Warrior)
    14251,   -- Riposte (Classic Rogue)
    51722,   -- Dismantle (Wrath Rogue)
    50541,   -- Clench (Hunter pet)
}

-- Other effects worth a portrait icon on an enemy
C.groups.other = {
    383005,  -- Chrono Loop
    77606,   -- Dark Simulacrum
    356723,  -- Scorpid Venom
    212182, 359053,  -- Smoke Bomb
}

-------------------------------------------------------------------------------
--  Build the per-client sets
--
--  Sources: S.CatalogData (generated from the game's own spell tables, per class and kind of
--  crowd control, see PortraitAuraCatalogData.lua) plus the hand-written groups above for
--  racials, pets and anything the tables miss. Only ids that exist on the running client count.
-------------------------------------------------------------------------------
C.KIND_ORDER = { "stun", "incapacitate", "fear", "charm", "root", "silence", "disarm", "other" }
C.KIND_LABELS = {
    stun = "Stun", incapacitate = "Incapacitate", fear = "Fear / Disorient", charm = "Charm",
    root = "Root", silence = "Silence", disarm = "Disarm", other = "Other",
}
C.CLASS_ORDER = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN",
    "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER", "OTHER" }
-- Kept for the older "by type" view.
C.GROUP_ORDER = C.KIND_ORDER
C.GROUP_LABELS = C.KIND_LABELS

local function SpellExists(id)
    if C_Spell and C_Spell.DoesSpellExist then
        local ok, exists = pcall(C_Spell.DoesSpellExist, id)
        if ok then return exists and true or false end
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok then return name ~= nil end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)
        return ok and name ~= nil
    end
    return true
end
C.SpellExists = SpellExists

-- fn(classToken, kind, id) for every catalog id. The generated data comes first; a hand-written
-- id the data already holds is not repeated under "OTHER".
local function ForEachSource(fn)
    local data = S.CatalogData or {}
    local classOf = S.CatalogClass or {}
    local inData = {}
    for kind, list in pairs(data) do
        for _, id in ipairs(list) do
            inData[id] = true
            fn(classOf[id] or "OTHER", kind, id)
        end
    end
    for kind, list in pairs(C.groups) do
        for _, id in ipairs(list) do
            if type(id) == "number" and not inData[id] then fn("OTHER", kind, id) end
        end
    end
end

-- crowdControl: everything but disarms; disarm: the disarm list. Both are read-only tables
-- handed to the engine as includeSpellIDs candidate filters.
function C.Build(extraIds, disabled)
    local control, disarm = {}, {}
    ForEachSource(function(_, kind, id)
        if type(id) == "number" and id > 0 and not (disabled and disabled[id]) and SpellExists(id) then
            (kind == "disarm" and disarm or control)[id] = true
        end
    end)
    if type(extraIds) == "table" then
        for id in pairs(extraIds) do control[id] = true end
    end
    return control, disarm
end

-------------------------------------------------------------------------------
--  Visual catalog: one entry per spell NAME (every rank / variant id of it), with its icon
--  and kind, for the options page. Only spells that exist on this client are listed.
-------------------------------------------------------------------------------
local function SpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        local ok, name = pcall(C_Spell.GetSpellName, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if GetSpellInfo then
        local ok, name = pcall(GetSpellInfo, id)
        if ok and type(name) == "string" then return name end
    end
end

local function SpellIcon(id)
    if C_Spell and C_Spell.GetSpellTexture then
        local ok, icon = pcall(C_Spell.GetSpellTexture, id)
        if ok and icon then return icon end
    end
    if GetSpellTexture then
        local ok, icon = pcall(GetSpellTexture, id)
        if ok and icon then return icon end
    end
    return 134400   -- question mark
end

local KIND_RANK = {}
for rank, kind in ipairs(C.KIND_ORDER) do KIND_RANK[kind] = rank end

-- Entries for a filter(classToken, kind) -> boolean, sorted by name.
local function CollectEntries(filter)
    local byName, entries = {}, {}
    ForEachSource(function(classToken, kind, id)
        if not (type(id) == "number" and filter(classToken, kind) and SpellExists(id)) then return end
        local name = SpellName(id) or ("Spell " .. id)
        local entry = byName[name]
        if not entry then
            entry = { name = name, icon = SpellIcon(id), ids = {}, kind = kind, class = classToken }
            byName[name] = entry
            entries[#entries + 1] = entry
        else
            if (KIND_RANK[kind] or 99) < (KIND_RANK[entry.kind] or 99) then entry.kind = kind end
            if entry.class == "OTHER" and classToken ~= "OTHER" then entry.class = classToken end
        end
        for _, known in ipairs(entry.ids) do if known == id then return end end
        entry.ids[#entry.ids + 1] = id
    end)
    for _, e in ipairs(entries) do table.sort(e.ids) end
    table.sort(entries, function(a, b) return a.name < b.name end)
    return entries
end

local function Complete(entries)
    for _, e in ipairs(entries) do if e.name:find("^Spell %d+$") then return false end end
    return true
end

local kindCache, classCache = {}, {}
-- Forget the built entry lists (spell names or the available spells changed).
function C.ResetCache()
    kindCache, classCache = {}, {}
end
-- By kind of crowd control (all classes).
function C.GetEntries(group)
    if kindCache[group] then return kindCache[group] end
    local entries = CollectEntries(function(_, kind) return kind == group end)
    -- Spell names can be missing right after login; do not freeze a half-loaded list.
    if Complete(entries) then kindCache[group] = entries end
    return entries
end

-- By class token ("ROGUE", ..., "OTHER" for racials and extras).
function C.GetClassEntries(classToken)
    if classCache[classToken] then return classCache[classToken] end
    local entries = CollectEntries(function(token) return token == classToken end)
    if Complete(entries) then classCache[classToken] = entries end
    return entries
end

-- Entries of every class whose name contains `text` (case-insensitive), for the search box.
function C.Search(text)
    text = type(text) == "string" and text:lower() or ""
    local out = {}
    if text == "" then return out end
    local seen = {}
    for _, kind in ipairs(C.KIND_ORDER) do
        for _, entry in ipairs(C.GetEntries(kind)) do
            if not seen[entry] and entry.name:lower():find(text, 1, true) then
                seen[entry] = true
                out[#out + 1] = entry
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Kinds of crowd control that have at least one spell on this client, in display order.
function C.GetKinds()
    local out = {}
    for _, kind in ipairs(C.KIND_ORDER) do
        if #C.GetEntries(kind) > 0 then out[#out + 1] = kind end
    end
    return out
end

-- Classes that have at least one spell on this client, in display order.
function C.GetClasses()
    local out = {}
    for _, token in ipairs(C.CLASS_ORDER) do
        if #C.GetClassEntries(token) > 0 then out[#out + 1] = token end
    end
    return out
end

-- "123, 456 789" -> { [123] = true, [456] = true, [789] = true }
function C.ParseIds(text)
    local ids
    if type(text) == "string" then
        for token in text:gmatch("%d+") do
            local id = tonumber(token)
            if id and id > 0 and id < 100000000 then
                ids = ids or {}
                ids[id] = true
            end
        end
    end
    return ids
end

