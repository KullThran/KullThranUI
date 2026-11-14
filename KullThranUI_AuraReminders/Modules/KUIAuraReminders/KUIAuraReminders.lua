-- KullThranUI :: Aura Reminders runtime
-- Decides which raid buffs, auras, consumables and talents are missing and
-- shows them as icons: secure click-to-cast buttons out of combat, plain
-- visual frames while in combat lockdown.
local ADDON_NAME, ns = ...
local KT = (ns and ns.KT) or (_G and (_G.KT or _G.KullThranUI)) or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
-- Current Retail clients no longer expose this global item helper.
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or _G.GetItemIcon
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local AceDB = LibStub("AceDB-3.0", true)
if not KT then return end

local Known = function(id) return id and (IsPlayerSpell(id) or IsSpellKnown(id)) end
local InCombat = function() return InCombatLockdown and InCombatLockdown() end
local AR = {}
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local texCache = {}
function AR.GetSpellTextureCached(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
        return nil
    end

    local cachedTexture = texCache[spellID]
    if cachedTexture then
        return cachedTexture
    end

    -- The global GetSpellTexture is gone from current clients; an ID that is not a spell (an icon file ID) gives nil.
    local texture = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
    if not texture and type(GetSpellTexture) == "function" then
        texture = GetSpellTexture(spellID)
    end
    if texture then
        texCache[spellID] = texture
    end

    return texture
end

function AR.GetPlayerClass()
    local _, cls = UnitClass("player"); return cls
end

function AR.GetActiveSpecID()
    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end

    return GetSpecializationInfo(specIndex)
end

local PET_REMINDER_CLASSES = {
    HUNTER = true,
    WARLOCK = true,
}

local PET_REMINDER_DEFS = {
    HUNTER = {
        icon = 132161,
        label = "Pet",
        buttons = {
            { spellID = 883, label = "Call 1" },
            { spellID = 83242, label = "Call 2" },
            { spellID = 83243, label = "Call 3" },
            { spellID = 83244, label = "Call 4" },
            { spellID = 83245, label = "Call 5" },
            { spellID = 982, label = "Revive" },
            { spellID = 2641, label = "Dismiss" },
        },
    },
    WARLOCK = {
        icon = 136218,
        label = "Pet",
        buttons = {
            { spellID = 688, label = "Imp" },
            { spellID = 697, label = "Void" },
            { spellID = 712, label = "Succubus" },
            { spellID = 691, label = "Felhunter" },
            { spellID = 30146, label = "Felguard", requireKnown = true },
        },
    },
}

-- Captions always use the KUI interface font with an outline.
function AR.ResolveFontPath()
    return KT.FONT_PATH or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
end
function AR.SetCaptionFont(fs, font, size)
    if not (fs and fs.SetFont) then return end
    fs:SetFont(font, size, "OUTLINE")
    fs:SetShadowOffset(0, 0)
end

-- Icon captions are a single word. A family (poisons, imbues, shields) shares
-- one word, a few spells get a hand-picked one, and anything else is
-- captioned with the first word of its name.
do
    local FAMILY_CAPTION = { ROGUE = "Poison", SHAMAN_IMBUE = "Weapon", SHAMAN_SHIELD = "Shield" }
    local CAPTION_FOR_SPELL = {}
    for caption, spellNames in pairs({
        Stance    = { "Defensive Stance", "Berserker Stance" },
        Aura      = { "Devotion Aura" },
        Fortitude = { "Power Word: Fortitude" },
        Intellect = { "Arcane Intellect" },
        Shout     = { "Battle Shout" },
    }) do
        for _, spellName in ipairs(spellNames) do CAPTION_FOR_SPELL[spellName] = caption end
    end

    function AR.GetReminderShortLabel(name, classOverride)
        local caption = (classOverride and FAMILY_CAPTION[classOverride]) or CAPTION_FOR_SPELL[name]
        if caption then return LText(caption) end
        return type(name) == "string" and name:match("^(%S+)") or name
    end
end

-- Instance type and difficulty are read once per Refresh (CacheInstanceInfo)
-- and the predicates below answer from that cache.
local _cachedIType, _cachedDiffID

function AR.CacheInstanceInfo()
    local _, iType, diffID = GetInstanceInfo()
    _cachedIType = iType
    _cachedDiffID = tonumber(diffID) or 0
end

function AR.InRealInstancedContent()
    if _cachedDiffID == 0 then return false end
    if C_Garrison and C_Garrison.IsOnGarrisonMap and C_Garrison.IsOnGarrisonMap() then return false end
    if _cachedIType == "party" or _cachedIType == "raid" or _cachedIType == "scenario" then return true end
    return false
end

local PARTY_MYTHIC_DIFFICULTIES = {
    [8] = true,
    [23] = true,
}

local PARTY_HEROIC_OR_HIGHER_DIFFICULTIES = {
    [2] = true,
    [8] = true,
    [23] = true,
}

local RAID_HEROIC_OR_HIGHER_DIFFICULTIES = {
    [5] = true,
    [6] = true,
    [15] = true,
    [16] = true,
}

function AR.IsMythicPlusActive()
    return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
end

function AR.InPvPInstance()
    return _cachedIType == "pvp" or _cachedIType == "arena"
end

function AR.IsMythicZeroOrMythicRaid()
    if _cachedIType == "party" then
        return PARTY_MYTHIC_DIFFICULTIES[_cachedDiffID] == true
    end

    return _cachedIType == "raid" and _cachedDiffID == 16
end

-- Heroic-or-higher difficulty IDs, looked up by instance type.
local HEROIC_MYTHIC_DIFF_TABLES = {
    party = PARTY_HEROIC_OR_HIGHER_DIFFICULTIES,
    raid  = RAID_HEROIC_OR_HIGHER_DIFFICULTIES,
}

function AR.IsHeroicOrMythicInstance()
    local diffMap = HEROIC_MYTHIC_DIFF_TABLES[_cachedIType]
    return diffMap ~= nil and diffMap[_cachedDiffID] == true
end

-- Instances offered by the talent reminder editor (current season).
local TALENT_REMINDER_ZONES = {
    { name="The Venomous Abyss",         type="raid",    instanceID=3004 },
    { name="Altar of Fangs",             type="dungeon", instanceID=2993 },
    { name="Murder Row",                 type="dungeon", instanceID=2813 },
    { name="Den of Nalorakk",            type="dungeon", instanceID=2825 },
    { name="The Blinding Vale",          type="dungeon", instanceID=2859 },
    { name="Voidscar Arena",             type="dungeon", instanceID=2923 },
    { name="Ruby Life Pools",            type="dungeon", instanceID=2521 },
    { name="Kings' Rest",                type="dungeon", instanceID=1762 },
    { name="Temple of Sethraliss",       type="dungeon", instanceID=1877 },
}

-- Stable instance ID to zone entry for locale-independent matching.
local TALENT_REMINDER_ZONE_BY_INSTANCE_ID = {}
for _, z in ipairs(TALENT_REMINDER_ZONES) do
    if z.instanceID then TALENT_REMINDER_ZONE_BY_INSTANCE_ID[z.instanceID] = z end
end

-- Name and numeric instance ID of the current instance.
function AR.GetCurrentInstanceName()
    local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    return name, tonumber(instanceID)
end

-- Aura reads, group scans and the combat-start snapshots are in
-- KUIAuraReminders_AuraRead.lua. NON_SECRET_SPELL_IDS holds the auras Blizzard
-- keeps readable during combat lockdown (12.0 whitelist). It is filled once the
-- spell tables further down exist, because most of it is made of those tables'
-- own buff IDs.
local AuraRead = ns.AuraRemindersAuraRead
AuraRead.Setup({ client = "retail" })
local NON_SECRET_SPELL_IDS = AuraRead.NonSecretSpellIDs
local _preCombatAuraCache = AuraRead.PreCombatAuraCache
local _preCombatOwnOnRaidCache = AuraRead.PreCombatOwnOnRaidCache
local _kuiarLogEnabled = false  -- /kuiarlog: log player aura updates in combat
local GetHelpfulAuraBySpellID = AuraRead.GetHelpfulAuraBySpellID
local GetHelpfulAuraByName = AuraRead.GetHelpfulAuraByName
local PlayerHasAuraByID = AuraRead.PlayerHasAuraByID
local PlayerHasSelfCastAuraByID = AuraRead.PlayerHasSelfCastAuraByID
local IsGrouped = AuraRead.IsGrouped
local AnyGroupMemberMissingBuff = AuraRead.AnyGroupMemberMissingBuff
local BuffExistsOnAnyGroupMember = AuraRead.BuffExistsOnAnyGroupMember
local PlayerOwnBuffOnAnyGroupMember = AuraRead.PlayerOwnBuffOnAnyGroupMember
local SnapshotPlayerAuras = AuraRead.SnapshotPlayerAuras
local SnapshotOwnOnRaidBuffs = AuraRead.SnapshotOwnOnRaidBuffs

-- Temporary weapon enchant items suit a weapon family (blade, blunt,
-- ranged); weapons outside every family take NEUTRAL items only.
do
    local WEAPON_ITEM_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
    local HELD_IN_OFFHAND = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
    local WEAPON_FAMILY_OF_SUBCLASS = {}
    local subclass = (Enum and Enum.ItemWeaponSubclass) or {}
    local families = {
        BLADED = { "Axe1H", "Axe2H", "Sword1H", "Sword2H", "Dagger", "Polearm", "Warglaive" },
        BLUNT  = { "Mace1H", "Mace2H", "Staff", "Fist" },
        RANGED = { "Bow", "Gun", "Crossbow", "Wand" },
    }
    for family, subclassNames in pairs(families) do
        for _, subclassName in ipairs(subclassNames) do
            local id = subclass[subclassName]
            if id ~= nil then WEAPON_FAMILY_OF_SUBCLASS[id] = family end
        end
    end

    -- Family of the weapon in an equipment slot; nil for an empty slot, a
    -- shield/off-hand frill or anything that is not a weapon.
    function AR.GetWeaponCategory(slotID)
        local itemID = GetInventoryItemID("player", slotID)
        if not itemID then return nil end
        local lookup = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
        local _, _, _, equipLoc, _, classID, subClassID = lookup(itemID)
        if classID ~= WEAPON_ITEM_CLASS or HELD_IN_OFFHAND[equipLoc] then return nil end
        return WEAPON_FAMILY_OF_SUBCLASS[subClassID] or "NEUTRAL"
    end
end


-- Spell catalogue. Each row is { key, name, castSpell, buffIDs?, fields? }:
-- buffIDs defaults to the cast spell itself, `fields` holds per-row extras
-- and `shared` the fields every row of a group has in common (scalars only).
-- The `key` is also the settings key, so it must never change.
local function AppendSpellRows(list, shared, rows)
    for _, row in ipairs(rows) do
        local entry = { key = row[1], name = row[2], castSpell = row[3], buffIDs = row[4] or { row[3] } }
        for field, value in pairs(shared) do entry[field] = value end
        for field, value in pairs(row[5] or {}) do entry[field] = value end
        list[#list + 1] = entry
    end
    return list
end

-- Class-wide raid buffs; all of them stay readable in combat.
local RAID_BUFFS = AppendSpellRows({}, { check = "raid" }, {
    { "motw",   "Mark of the Wild",       1126,   { 1126, 432661 }, { class = "DRUID" } },
    { "bshout", "Battle Shout",           6673,   nil,              { class = "WARRIOR" } },
    { "fort",   "Power Word: Fortitude",  21562,  nil,              { class = "PRIEST" } },
    { "ai",     "Arcane Intellect",       1459,   { 1459, 432778 }, { class = "MAGE" } },
    { "bronze", "Blessing of the Bronze", 364342, {
        381732, 381741, 381746, 381748, 381749, 381750, 381751,
        381752, 381753, 381754, 381756, 381757, 381758 },        { class = "EVOKER" } },
    { "sky",    "Skyfury",                462854, nil,              { class = "SHAMAN" } },
})

-- Personal auras, stances and ally buffs, grouped by class (the order is the
-- order icons and option rows appear in).
local AURAS = {}
-- Symbiotic Relationship sits on both the druid and the target, so the
-- druid's own copy answers for both; it is readable in combat.
AppendSpellRows(AURAS, { class = "DRUID", check = "player", combatOk = true, requireInstanceGroup = true }, {
    { "symbiotic", "Symbiotic Relationship", 474750, { 474754 } },
})
-- Stances are read from the shapeshift bar and only out of combat.
AppendSpellRows(AURAS, { class = "WARRIOR", check = "player", combatOk = false, isStance = true }, {
    { "battle_stance",  "Battle Stance",    386164, nil, { specs = { 71 } } },
    { "berserk_stance", "Berserker Stance", 386196, nil, { specs = { 72 } } },
    { "def_stance",     "Defensive Stance", 386208, nil, { specs = { 73 } } },
})
-- Void Form takes Shadowform's place while it lasts, so either counts.
AppendSpellRows(AURAS, { class = "PRIEST", check = "player", combatOk = false }, {
    { "shadowform", "Shadowform", 232698, { 232698, 194249 }, { specs = { 258 } } },
})
-- Only one paladin aura can be up; each stays its own option and
-- CollectAuras folds the group into a single icon.
AppendSpellRows(AURAS, { class = "PALADIN", check = "player", combatOk = false, noPvP = true, paladinAura = true }, {
    { "devo_aura",          "Devotion Aura",      465,    nil, { instanceBuffIDs = { 465 } } },
    { "crusader_aura",      "Crusader Aura",      32223 },
    { "concentration_aura", "Concentration Aura", 317920 },
})
-- Beacons are watched through the spell-activation overlay (beacon section
-- near the end of the file); the aura scan skips them.
AppendSpellRows(AURAS, { class = "PALADIN", standalone = true }, {
    { "bol", "Beacon of Light", 53563,  nil, { notIfKnown = 200025 } },
    { "bof", "Beacon of Faith", 156910 },
})
-- Evoker buffs placed on an ally: what matters is that the player's cast is
-- on someone in the group.
AppendSpellRows(AURAS, { class = "EVOKER", check = "ownOnRaid", requireInstanceGroup = true }, {
    { "som",               "Source of Magic",   369459, nil,        { combatOk = true } },
    { "blistering_scales", "Blistering Scales", 360827, nil,        { combatOk = true } },
    { "bestow_weyrnstone", "Bestow Weyrnstone", 408233, { 410318 }, { combatOk = false, specs = { 1473 } } },
    { "timelessness",      "Timelessness",      412710, nil,        { combatOk = false, specs = { 1473 } } },
})

-- Class upkeep counted as consumables: checked out of combat and never
-- inside a keystone. Poisons carry no buffIDs; the cast spell is the aura.
local ROGUE_POISONS = {}
for _, group in ipairs({
    { "lethal", {
        { "deadly",     "Deadly Poison",     2823 },
        { "amplifying", "Amplifying Poison", 381664 },
        { "instant",    "Instant Poison",    315584 },
        { "wound",      "Wound Poison",      8679 },
    } },
    { "nonlethal", {
        { "numbing",   "Numbing Poison",   5761 },
        { "atrophic",  "Atrophic Poison",  381637 },
        { "crippling", "Crippling Poison", 3408 },
    } },
}) do
    for _, row in ipairs(group[2]) do
        ROGUE_POISONS[#ROGUE_POISONS + 1] = { key = row[1], name = row[2], castSpell = row[3], cat = group[1] }
    end
end
local DRAGON_TEMPERED_BLADES = 381801  -- talent: two poisons of each kind

-- Weapon upkeep spells; wepEnchID is the temporary enchant they apply.
local PALADIN_RITES = AppendSpellRows({}, {}, {
    { "rite_adj",  "Rite of Adjuration",     433583, nil, { wepEnchID = { 7144 } } },
    { "rite_sanc", "Rite of Sanctification", 433568, nil, { wepEnchID = { 7143 } } },
})
local SHAMAN_IMBUES = AppendSpellRows({}, {}, {
    { "flametongue", "Flametongue Weapon", 318038, { 319778 },         { wepEnchID = { 5400 } } },
    { "windfury",    "Windfury Weapon",    33757,  { 319773 },         { wepEnchID = { 5401 } } },
    { "earthliving", "Earthliving Weapon", 382021, { 382021, 382022 }, { wepEnchID = { 6498 } } },
    { "tidecaller",  "Tidecaller's Guard", 457496, { 457496, 457481 }, { wepEnchID = { 7528 } } },
    { "tstrike",     "Thunderstrike Ward", 462757, { 462757, 462742 }, { wepEnchID = { 7587 } } },
})
-- Earth Shield with the orbit talent: one copy on the shaman (selfOrbitBuff)
-- and the shaman's own one on an ally (otherBuff).
local SHAMAN_SHIELDS = AppendSpellRows({}, {}, {
    { "ls", "Lightning Shield", 192106, nil, { specs = { 262 } } },
    { "ws", "Water Shield",     52127,  nil, { specs = { 264 } } },
    { "es", "Earth Shield",     974,    nil, { specs = { 264 }, orbitTalent = 383010, selfOrbitBuff = { 383648 }, otherBuff = { 974 } } },
})

-- Combat-readable aura whitelist. Raid buffs, rites, imbues and poisons
-- contribute their own IDs; the remainder is listed by role.
do
    local function allow(ids)
        for _, id in ipairs(ids) do NON_SECRET_SPELL_IDS[id] = true end
    end
    for _, family in ipairs({ RAID_BUFFS, PALADIN_RITES, SHAMAN_IMBUES }) do
        for _, entry in ipairs(family) do allow(entry.buffIDs) end
    end
    for _, poison in ipairs(ROGUE_POISONS) do allow({ poison.castSpell }) end
    -- Healer HoTs, absorbs and beacons by spec.
    allow({ 355941, 363502, 364343, 366155, 367364, 373267, 376788 })  -- Preservation Evoker
    allow({ 360827, 395152, 410089, 410263, 410686, 413984 })          -- Augmentation Evoker
    allow({ 774, 8936, 33763, 48438, 155777 })                         -- Restoration Druid
    allow({ 17, 194384, 1253593 })                                     -- Discipline Priest
    allow({ 139, 41635, 77489 })                                       -- Holy Priest
    allow({ 115175, 119611, 124682, 450769 })                          -- Mistweaver Monk
    allow({ 974, 383648, 61295 })                                      -- Restoration Shaman
    allow({ 53563, 156322, 156910, 1244893 })                          -- Holy Paladin
    -- Ally buffs (Source of Magic, Symbiotic Relationship), two resource
    -- auras and two cooldowns. Devotion Aura is deliberately absent: it is
    -- still secret in combat, so its reminder hides there.
    allow({ 369459, 474754, 205473, 260286, 8690, 20608 })
end

-- Temporary weapon enchant items. Spec rows are { name, weapon family,
-- icon, item IDs }; the flat list keeps one entry per item ID, in this order.
local WEAPON_ENCHANT_ITEMS = {}
for _, spec in ipairs({
    -- Midnight
    { "Refulgent Weightstone",     "BLUNT",   7548939, { 237367, 237369 } },
    { "Refulgent Whetstone",       "BLADED",  7548942, { 237370, 237371 } },
    { "Laced Zoomshots",           "RANGED",  249176,  { 257749, 257750 } },
    { "Weighted Boomshots",        "RANGED",  249175,  { 257751, 257752 } },
    { "Thalassian Phoenix Oil",    "NEUTRAL", 7548987, { 243733, 243734 } },
    { "Oil of Dawn",               "NEUTRAL", 7548985, { 243735, 243736 } },
    { "Smuggler's Enchanted Edge", "NEUTRAL", 7548986, { 243737, 243738 } },
    -- The War Within
    { "Ironclaw Whetstone",        "BLADED",  3622195, { 222504, 222503, 222502 } },
    { "Ironclaw Weightstone",      "BLUNT",   3622199, { 222510, 222509, 222508 } },
    { "Algari Mana Oil",           "NEUTRAL", 609892,  { 224107, 224106, 224105 } },
    { "Oil of Deep Toxins",        "NEUTRAL", 609897,  { 224113, 224112, 224111 } },
    { "Oil of Beledar's Grace",    "NEUTRAL", 609896,  { 224110, 224109, 224108 } },
    { "Bubbling Wax",              "NEUTRAL", 133778,  { 220156 } },
}) do
    for _, itemID in ipairs(spec[4]) do
        WEAPON_ENCHANT_ITEMS[#WEAPON_ENCHANT_ITEMS + 1] = { itemID = itemID, name = spec[1], weaponType = spec[2], icon = spec[3] }
    end
end

-- Settings key derived from an English item name: "Smuggler's Enchanted
-- Edge" becomes "smugglers_enchanted_edge".
local function SettingsKeyFor(name)
    return (name:lower():gsub("'", ""):gsub("[^%w]+", "_"))
end

-- The weapon enchant dropdown offers the current-expansion items by name;
-- the best matching item ID is looked up in the bags at runtime.
local WEAPON_ENCHANT_CHOICES = {}
local WEAPON_ENCHANT_NAME_BY_KEY = {}
for _, name in ipairs({
    "Thalassian Phoenix Oil", "Smuggler's Enchanted Edge", "Oil of Dawn",
    "Refulgent Weightstone", "Refulgent Whetstone", "Laced Zoomshots", "Weighted Boomshots",
}) do
    local key = SettingsKeyFor(name)
    WEAPON_ENCHANT_CHOICES[#WEAPON_ENCHANT_CHOICES + 1] = { key = key, name = name }
    WEAPON_ENCHANT_NAME_BY_KEY[key] = name
end

-- Midnight flasks: { buff spell, name, item IDs over quality ranks and fleeting
-- variants }. The settings key comes from the name, as for weapon enchants.
local FLASK_ITEMS = {}
for _, row in ipairs({
    { 1235110, "Flask of the Blood Knights",        { 241324, 241325, 245931, 245930 } },
    { 1235108, "Flask of the Magisters",            { 241322, 241323, 245933, 245932 } },
    { 1235111, "Flask of the Shattered Sun",        { 241326, 241327, 245929, 245928 } },
    { 1235057, "Flask of Thalassian Resistance",    { 241320, 241321, 245926, 245927 } },
    { 1239355, "Vicious Thalassian Flask of Honor", { 241334 } },
}) do
    FLASK_ITEMS[#FLASK_ITEMS + 1] = { key = SettingsKeyFor(row[2]), buffID = row[1], name = row[2], items = row[3] }
end

-- Auras that count as "a flask is active": the flasks above, then older
-- flasks and their PvP-morphed forms.
local FLASK_BUFF_IDS = {}
for _, flask in ipairs(FLASK_ITEMS) do FLASK_BUFF_IDS[#FLASK_BUFF_IDS + 1] = flask.buffID end
for _, id in ipairs({ 432473, 432021, 431974, 431973, 431972, 431971, 1235113, 1235114, 1235115, 1235116 }) do
    FLASK_BUFF_IDS[#FLASK_BUFF_IDS + 1] = id
end

-- Midnight food. Every dish has a Hearty version; the list holds all plain
-- dishes first, then the Hearty ones in the same order. Spec rows are
-- { name, item, hearty item, hearty name when it is not "Hearty <name>" }.
local FOOD_ITEMS = {}
do
    local dishes = {
        { "Royal Roast",                  242275, 242747 },
        { "Impossibly Royal Roast",       255847, 268679 },
        { "Flora Frenzy",                 255848, 268680 },
        { "Champion's Bento",             242274, 242746 },
        { "Warped Wise Wings",            242285, 242757 },
        { "Void-Kissed Fish Rolls",       242284, 242756 },
        { "Sun-Seared Lumifin",           242283, 242755 },
        { "Null and Void Plate",          242282, 242754 },
        { "Glitter Skewers",              242281, 242753 },
        { "Fel-Kissed Filet",             242286, 242758 },
        { "Buttered Root Crab",           242280, 242752 },
        { "Arcano Cutlets",               242287, 242759 },
        { "Tasty Smoked Tetra",           242278, 242750 },
        { "Crimson Calamari",             242277, 242749 },
        { "Braised Blood Hunter",         242276, 242748 },
        { "Harandar Celebration",         255846, 266996 },
        { "Silvermoon Parade",            255845, 266985 },
        { "Quel'dorei Medley",            242272, 242744 },
        { "Blooming Feast",               242273, 242745 },
        { "Sunwell Delight",              242293, 242765 },
        { "Hearthflame Supper",           242295, 242767 },
        { "Fried Bloomtail",              242291, 242763 },
        { "Felberry Figs",                242294, 242766 },
        { "Eversong Pudding",             242292, 242764 },
        { "Bloodthistle-wrapped Cutlets", 242296, 242768, "Hearty Bloodthistle-Wrapped Cutlets" },
        { "Wise Tails",                   242290, 242762 },
        { "Twilight Angler's Medley",     242288, 242760 },
        { "Spellfire Filet",              242289, 242761 },
        { "Spiced Biscuits",              242304, 242771 },
        { "Silvermoon Standard",          242305, 242772 },
        { "Quick Sandwich",               242307, 242774 },
        { "Portable Snack",               242308, 242775 },
        { "Mana-Infused Stew",            242303, 242770 },
        { "Forager's Medley",             242306, 242773 },
        { "Farstrider Rations",           242309, 242776 },
        { "Bloom Skewers",                242302, 242769 },
    }
    for _, dish in ipairs(dishes) do
        FOOD_ITEMS[#FOOD_ITEMS + 1] = { key = SettingsKeyFor(dish[1]), itemID = dish[2], name = dish[1] }
    end
    for _, dish in ipairs(dishes) do
        FOOD_ITEMS[#FOOD_ITEMS + 1] = { key = "hearty_" .. SettingsKeyFor(dish[1]), itemID = dish[3], name = dish[4] or ("Hearty " .. dish[1]) }
    end
end

-- Augment runes: Void-Touched (Midnight) is preferred over Ethereal (TWW).
local AUGMENT_RUNE_VOID   = 259085
local AUGMENT_RUNE_ETHER  = 243191
local RUNE_BUFF_IDS = {1264426, 453250, 1234969, 1242347, 393438, 347901}

-- Inky Black Potion (its buff is found by name, see CollectInkyBlack).
local INKY_BLACK_ITEM = 124640

-- Presence tests for stances, named buffs, Well Fed and flasks.
function AR.PlayerHasActiveStanceSpell(spellID)
    local count = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    for index = 1, count do
        local _, active, _, formSpellID = GetShapeshiftFormInfo(index)
        if active and formSpellID == spellID then return true end
    end
    return false
end

function AR.PlayerHasBuffByName(buffName)
    if AR.InPvPInstance() or AR.IsMythicPlusActive() then return true end
    local aura, readable = GetHelpfulAuraByName("player", buffName)
    if not readable then return true end -- avoid a false reminder when restricted
    return aura ~= nil
end

local function PlayerHasHelpfulAuraNamed(auraName)
    if not (auraName and C_UnitAuras) then return nil, false end

    -- GetAuraDataBySpellName can miss food variants (especially feast buffs),
    -- even though the aura is visible in the player's helpful-aura list.
    local aura, readable = GetHelpfulAuraByName("player", auraName)
    if readable and aura ~= nil then return true, true end
    if not (C_UnitAuras.GetAuraDataByIndex and not issecretvalue(auraName)) then
        return nil, readable
    end

    local expected = string.lower(auraName)
    for index = 1, 255 do
        local ok, indexedAura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
        if not ok then return nil, false end
        if not indexedAura then return false, true end

        local indexedName = indexedAura.name
        if not issecretvalue(indexedName) and indexedName then
            indexedName = string.lower(indexedName)
            if indexedName == expected or string.find(indexedName, expected, 1, true) then
                return true, true
            end
        end
    end

    return false, true
end

function AR.PlayerHasWellFed()
    if InCombat() or AR.InPvPInstance() or AR.IsMythicPlusActive() then return true end
    local wellFedName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(19705)
    if issecretvalue(wellFedName) or not wellFedName then return true end
    local hasWellFed, readable = PlayerHasHelpfulAuraNamed(wellFedName)
    if not readable then return true end -- avoid a false reminder when restricted
    return hasWellFed == true
end

function AR.PlayerHasFlaskBuff()
    if AR.InPvPInstance() or AR.IsMythicPlusActive() then return true end
    for _, id in ipairs(FLASK_BUFF_IDS) do
        local aura, readable = GetHelpfulAuraBySpellID("player", id)
        if readable and aura ~= nil then return true end
        if not readable then return true end
    end
    return false
end

-- Glow styles offered in the options. The index is what profiles store
-- (display.glowType), 0 meaning no glow, so new styles go at the end.
local GLOW_TYPES = {
    { name = "Action Button Glow",   buttonGlow = true },
    { name = "Pixel Glow",           procedural = true },
    { name = "Auto-Cast Shine",      autocast = true },
    { name = "GCD",                  atlas = "RotationHelper_Ants_Flipbook",  scale = 1.6 },
    { name = "Modern WoW Glow",      atlas = "UI-HUD-ActionBar-Proc-Loop-Flipbook",  scale = 1.6 },
    { name = "Classic WoW Glow",     texture = "Interface\\SpellActivationOverlay\\IconAlertAnts",
      rows = 5, columns = 5, frames = 25, duration = 0.3, frameW = 48, frameH = 48, scale = 1.09 },
}

local GLOW_VALUES = { [0] = LText("None") }
local GLOW_ORDER  = { 0 }
for i, entry in ipairs(GLOW_TYPES) do
    GLOW_VALUES[i] = LText(entry.name)
    GLOW_ORDER[#GLOW_ORDER + 1] = i
end

-- The glow drawing itself lives in KT.Glows; without it a wrapper is simply
-- kept invisible.
local _G_Glows = KT.Glows or {}

local function SafeGlowCall(method, wrapper, ...)
    local fn = _G_Glows and _G_Glows[method]
    if type(fn) == "function" then
        return fn(wrapper, ...)
    end

    if wrapper then
        wrapper:SetAlpha(0)
        wrapper:Hide()
    end
end

local StartPixelGlow, StartButtonGlow, StartAutoCastShine, StartFlipBookGlow, StopAllGlows
do
    function StartPixelGlow(wrapper, sz, cr, cg, cb)
        local N, th, period = 8, 2, 4
        local lineLen = floor((sz+sz)*(2/N-0.1)); lineLen = min(lineLen, sz); if lineLen < 1 then lineLen = 1 end
        SafeGlowCall("StartProceduralAnts", wrapper, N, th, period, lineLen, cr, cg, cb, sz)
    end
    local function StopPixelGlow(wrapper) SafeGlowCall("StopProceduralAnts", wrapper) end

    function StartButtonGlow(wrapper, sz, cr, cg, cb, scale)
        SafeGlowCall("StartButtonGlow", wrapper, sz, cr, cg, cb, scale)
    end
    local function StopButtonGlow(wrapper) SafeGlowCall("StopButtonGlow", wrapper) end

    function StartAutoCastShine(wrapper, sz, cr, cg, cb, scale)
        SafeGlowCall("StartAutoCastShine", wrapper, sz, cr, cg, cb, scale)
    end
    local function StopAutoCastShine(wrapper) SafeGlowCall("StopAutoCastShine", wrapper) end

    function StartFlipBookGlow(wrapper, sz, entry, cr, cg, cb)
        SafeGlowCall("StartFlipBookGlow", wrapper, sz, entry, cr, cg, cb)
    end
    local function StopFlipBookGlow(wrapper) SafeGlowCall("StopFlipBookGlow", wrapper) end

    function StopAllGlows(wrapper)
        if _G_Glows and type(_G_Glows.StopAllGlows) == "function" then
            _G_Glows.StopAllGlows(wrapper)
            return
        end

        StopPixelGlow(wrapper)
        StopButtonGlow(wrapper)
        StopAutoCastShine(wrapper)
        StopFlipBookGlow(wrapper)
    end
end


-- Profile defaults. Every reminder starts enabled; AllOn turns a word list
-- of settings keys into the { key = true } map AceDB stores.
local function AllOn(keys)
    local map = {}
    for key in keys:gmatch("%S+") do map[key] = true end
    return map
end

local defaults = {
    profile = {
        enable = true,
        display = {
            glowType = 0,
            glowColor = {r=1, g=0.776, b=0.376},
            scale = 1.0,
            xOffset = 0,
            yOffset = 200,
            showText = true,
            textColor = {r=1, g=1, b=1},
            textSize = 12,
            textFont = "Expressway",
            textXOffset = 0,
            textYOffset = -5,
            iconSpacing = 14,
            opacity = 1.0,
            frameStrata = "MEDIUM",
            cursorAttach = false,
            iconOrder = {},
        },
        raidBuffs = {
            -- Class-wide upkeep buffs are useful while questing, testing a
            -- profile or waiting for a group as well as inside instances.
            -- Keep the option user-configurable, but do not make Battle Shout
            -- and equivalent buffs disappear while personal stances remain.
            showNonInstanced = true,
            showOthersMissing = true,
            scale = 1.0,
            enabled = AllOn("motw bshout fort ai bronze sky"),
        },
        auras = {
            showNonInstanced = true,
            scale = 1.0,
            enabled = AllOn([[
                symbiotic battle_stance def_stance berserk_stance shadowform
                devo_aura crusader_aura concentration_aura bol bof
                som blistering_scales bestow_weyrnstone timelessness
            ]]),
        },
        customAuras = {},
        consumables = {
            showSpecialsNonInstanced = true,
            scale = 1.0,
            enabled = AllOn([[
                deadly instant wound amplifying crippling numbing atrophic
                rite_adj rite_sanc
                flametongue windfury earthliving tidecaller tstrike ls ws es
                augment_rune weapon_enchant inky_black flask food pet
            ]]),
            preferredFlask = "last_used",
            preferredFood = "last_used",
            preferredWeaponEnchant = "last_used",
            runeDisplayMode = "mythic",
            inkyBlackZones = "",
        },
        unlockPos = nil,
        previewHintDismissed = false,
        talentReminders = {},  -- array of {zoneIDs={}, zoneNames={}, spellID=number, spellName=string, showNotNeeded=bool}
        talentReminderYOffset = -50,
    },
    char = {
        lastUsedFlask = nil,
        lastUsedFood = nil,
        lastUsedWeaponEnchant = nil,
    },
}

local db  -- set at PLAYER_LOGIN
local optionsPanelVisible = false
-- Read by the beacon row on every refresh. Written beside db and optionsPanelVisible.
local BeaconLive = { db = nil, optionsVisible = false }

-- Weapon enchant reads, bag lookups and the item use memory are in
-- KUIAuraReminders_Items.lua. It is set up here because the catalogues are final
-- and the database local exists.
local Items = ns.AuraRemindersItems
Items.Setup({
    client = "retail",
    GetDB = function() return db end,
    FlaskItems = FLASK_ITEMS,
    FoodItems = FOOD_ITEMS,
    WeaponEnchantItems = WEAPON_ENCHANT_ITEMS,
    WeaponEnchantNameByKey = WEAPON_ENCHANT_NAME_BY_KEY,
})
local Owned = Items.Owned
local FirstFittingWeaponItem = Items.FirstFittingWeaponItem
AR.GetTemporaryWeaponEnchants = Items.GetTemporaryWeaponEnchants
AR.FindFlaskItem = Items.FindFlaskItem
AR.FindFoodItem = Items.FindFoodItem
AR.FindWeaponEnchantItem = Items.FindWeaponEnchantItem

-- Middle-clicking an icon hides that reminder until the next loading screen.
local _dismissedUntilLoad = {}  -- [dismissKey] = true

-- Icon frames. Out of combat reminders are SecureActionButtons on iconAnchor
-- (click to cast or use); talent reminders get their own row underneath.
-- In combat secure frames cannot be shown or hidden, so plain look-alike
-- frames on combatAnchor (or cursorAnchor, see below) take over.
local ICON_SIZE = 40
local iconAnchor
local iconPool = {}     -- every main-row button created so far
local activeIcons = {}  -- main-row buttons currently in use

local talentIconAnchor
local talentIconPool = {}
local talentActiveIcons = {}

local combatAnchor      -- created at PLAYER_LOGIN, pinned to iconAnchor
local combatIconPool = {}
local combatActiveIcons = {}

-- With display.cursorAttach, combat icons for the most important reminders
-- (every raid buff plus the keys below) are drawn at cursorAnchor instead.
local CURSOR_IMPORTANT = { es = true, som = true }
local cursorAnchor
local cursorIconPool = {}
local cursorActiveIcons = {}

local WHITE = { r = 1, g = 1, b = 1 }
local DEFAULT_GLOW_TINT = { r = 1, g = 0.776, b = 0.376 }

function AR.GetStrata()
    local strata = db and db.profile and db.profile.display and db.profile.display.frameStrata
    if not strata or strata == "" then
        return "MEDIUM"
    end
    return strata
end

-- Every reminder icon looks the same: a cropped texture, a 1px border and a
-- one-word caption hanging below.
local function DressIcon(frame)
    local art = frame:CreateTexture(nil, "ARTWORK")
    art:SetAllPoints()
    art:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame._icon = art
    local PP = KT and KT.PP
    if PP then PP.CreateBorder(frame, 0, 0, 0, 1, 1, "OVERLAY", 7) end
    local caption = frame:CreateFontString(nil, "OVERLAY")
    caption:SetPoint("TOP", frame, "BOTTOM", 0, -2)
    AR.SetCaptionFont(caption, AR.ResolveFontPath(), 11)
    caption:SetTextColor(1, 1, 1, 1)
    frame._text = caption
    return frame
end

-- Applies the caption settings (font, size, offset, colour) or hides the
-- caption when text is switched off. With text == nil the caption keeps
-- whatever the icon's setup function wrote into it.
local function StyleCaption(frame, text)
    local display = db and db.profile.display
    local caption = frame._text
    if not (display and display.showText) then
        caption:SetText("")
        caption:Hide()
        return
    end
    local color = display.textColor or WHITE
    AR.SetCaptionFont(caption, AR.ResolveFontPath(display.textFont), display.textSize or 11)
    caption:ClearAllPoints()
    caption:SetPoint("TOP", frame, "BOTTOM", display.textXOffset or 0, display.textYOffset or -2)
    caption:SetTextColor(color.r, color.g, color.b, 1)
    if text ~= nil then caption:SetText(text) end
    -- FadeOutSecureIcons zeroes caption alpha at combat start; undo it here.
    caption:SetAlpha(1)
    caption:Show()
end

-- Centres a row of icons on its anchor at the configured size, spacing and
-- opacity; sizeFactor scales one row on top of the global scale.
function AR.LayoutIconRow(iconList, anchorFrame, sizeFactor)
    local count = #iconList
    if count == 0 or not anchorFrame then
        return
    end
    local display = (db and db.profile.display) or {}
    local size = floor(ICON_SIZE * ((display.scale or 1.0) * (sizeFactor or 1)) + 0.5)
    local pitch = size + (display.iconSpacing or 8)
    local first = -(count - 1) * pitch / 2
    for index, frame in ipairs(iconList) do
        frame:SetSize(size, size)
        frame:SetAlpha(display.opacity or 1.0)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", anchorFrame, "CENTER", first + (index - 1) * pitch, 0)
    end
end

-- Combat and cursor icons are plain frames, safe to show and hide in combat.
local VISUAL_ROWS = {
    combat = {
        prefix = "KUIAR_CombatIcon", level = 120,
        frames = combatIconPool, shown = combatActiveIcons,
        anchor = function() return combatAnchor end,
    },
    cursor = {
        prefix = "KUIAR_CursorIcon", level = 9980, strata = "TOOLTIP",
        frames = cursorIconPool, shown = cursorActiveIcons,
        anchor = function() return cursorAnchor end,
    },
}

-- A hidden, non-secure icon frame (combat rows and beacons).
local function PlainIcon(name, parent, strata, level)
    local frame = CreateFrame("Frame", name, parent)
    frame:SetSize(ICON_SIZE, ICON_SIZE)
    frame:SetFrameStrata(strata)
    frame:SetFrameLevel(level)
    frame:Hide()
    return DressIcon(frame)
end

local function VisualIcon(row, index)
    if not row.frames[index] then
        row.frames[index] = PlainIcon(row.prefix .. index, row.anchor(), row.strata or AR.GetStrata(), row.level)
    end
    return row.frames[index]
end

local function ClearVisualRow(row)
    for _, frame in ipairs(row.shown) do
        frame._text:SetText("")
        frame:Hide()
    end
    wipe(row.shown)
    local anchor = row.anchor()
    if anchor then anchor:Hide() end
end

local function PushVisualIcon(row, index, spellID, texture, label)
    local frame = VisualIcon(row, index)
    frame._icon:SetTexture(texture or AR.GetSpellTextureCached(spellID) or 134400)
    StyleCaption(frame, label or "")
    frame:Show()
    row.shown[#row.shown + 1] = frame
end

function AR.GetOrCreateCombatIcon(index) return VisualIcon(VISUAL_ROWS.combat, index) end
function AR.HideCombatIcons() ClearVisualRow(VISUAL_ROWS.combat) end
function AR.ShowCombatIcon(iconIdx, spellID, texture, label) PushVisualIcon(VISUAL_ROWS.combat, iconIdx, spellID, texture, label) end
function AR.LayoutCombatIcons() AR.LayoutIconRow(combatActiveIcons, combatAnchor) end

function AR.GetOrCreateCursorIcon(index) return VisualIcon(VISUAL_ROWS.cursor, index) end
function AR.HideCursorIcons() ClearVisualRow(VISUAL_ROWS.cursor) end
function AR.ShowCursorIcon(iconIdx, spellID, texture, label) PushVisualIcon(VISUAL_ROWS.cursor, iconIdx, spellID, texture, label) end
function AR.LayoutCursorIcons() AR.LayoutIconRow(cursorActiveIcons, cursorAnchor) end

local function IsImportantBuff(m)
    if not m then
        return false
    end
    if m.cat == "raidbuff" then
        return true
    end
    local key = m.data and m.data.key
    return key ~= nil and CURSOR_IMPORTANT[key] == true
end

local function ApplyGlow(btn, glowType, cr, cg, cb)
    if glowType == 0 then return end
    local entry = GLOW_TYPES[glowType]; if not entry then return end
    if not btn._kuiarGlowOverlay then
        local w = CreateFrame("Frame", nil, btn); w:SetAllPoints(btn); w:SetFrameLevel(btn:GetFrameLevel()+1)
        btn._kuiarGlowOverlay = w
    end
    local wrapper = btn._kuiarGlowOverlay; local sz = btn:GetWidth() or ICON_SIZE
    StopAllGlows(wrapper)
    if entry.procedural then StartPixelGlow(wrapper, sz, cr, cg, cb)
    elseif entry.buttonGlow then StartButtonGlow(wrapper, sz, cr, cg, cb, 1.36)
    elseif entry.autocast then StartAutoCastShine(wrapper, sz, cr, cg, cb, 1.0)
    else StartFlipBookGlow(wrapper, sz, entry, cr, cg, cb) end
    wrapper:SetAlpha(1)  -- may still be zero from FadeOutSecureIcons
    wrapper:Show()
end

local function RemoveGlow(btn)
    local wrapper = btn and btn._kuiarGlowOverlay
    if not wrapper then
        return
    end
    StopAllGlows(wrapper)
    wrapper:Hide()
end

-- Glow in the configured style and colour (style 0 draws nothing).
local function GlowFromSettings(frame)
    local display = db and db.profile.display
    local tint = (display and display.glowColor) or DEFAULT_GLOW_TINT
    ApplyGlow(frame, (display and display.glowType) or 0, tint.r, tint.g, tint.b)
end

-- Secure rows. Only main-row icons can be middle-click dismissed; talent
-- icons let the middle button through.
local function DismissOnMiddleClick(self, button)
    if button == "MiddleButton" and self._dismissKey then
        _dismissedUntilLoad[self._dismissKey] = true
        if _G._KUIAR_RequestRefresh then _G._KUIAR_RequestRefresh() end
    end
end

local SECURE_ROWS = {
    main = {
        prefix = "KUIAR_Icon", frames = iconPool, shown = activeIcons, dismissable = true,
        clicks = { "LeftButtonDown", "LeftButtonUp", "MiddleButtonUp" }, passThrough = { "RightButton" },
        anchor = function() return iconAnchor end,
    },
    talent = {
        prefix = "KUIAR_TalentIcon", frames = talentIconPool, shown = talentActiveIcons,
        clicks = { "LeftButtonDown", "LeftButtonUp" }, passThrough = { "RightButton", "MiddleButton" },
        anchor = function() return talentIconAnchor end,
    },
}
local SECURE_ROW_ORDER = { SECURE_ROWS.main, SECURE_ROWS.talent }

local function SecureIcon(row, index)
    local btn = row.frames[index]
    if btn then return btn end
    btn = CreateFrame("Button", row.prefix .. index, row.anchor(), "SecureActionButtonTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:RegisterForClicks(unpack(row.clicks))
    btn:SetPassThroughButtons(unpack(row.passThrough))
    btn:SetFrameStrata(AR.GetStrata())
    btn:Hide()
    if row.dismissable then btn:HookScript("PostClick", DismissOnMiddleClick) end
    row.frames[index] = DressIcon(btn)
    return btn
end

-- Entering combat: secure buttons cannot be hidden any more, but they can be
-- made invisible. Their glows are plain frames and are stopped outright.
local function FadeOutSecureIcons()
    for _, row in ipairs(SECURE_ROW_ORDER) do
        for _, btn in ipairs(row.shown) do
            btn:SetAlpha(0)
            if btn._text then btn._text:SetAlpha(0) end
            local glow = btn._kuiarGlowOverlay
            if glow then StopAllGlows(glow); glow:SetAlpha(0) end
        end
    end
end

-- What a secure button does when clicked. Attributes a kind does not use
-- are cleared so a recycled button never keeps a stale action.
local ICON_ACTION_ATTRS = {
    spell = function(btn, id)
        btn:SetAttribute("type", "spell"); btn:SetAttribute("spell", id)
        btn:SetAttribute("item", nil); btn:SetAttribute("macrotext", nil)
        btn:SetAttribute("unit", "player")
    end,
    item = function(btn, id)
        btn:SetAttribute("type", "item"); btn:SetAttribute("item", string.format("item:%s", id))
        btn:SetAttribute("spell", nil); btn:SetAttribute("macrotext", nil)
        btn:SetAttribute("unit", nil)
    end,
    macro = function(btn, text)
        btn:SetAttribute("type", "macro"); btn:SetAttribute("macrotext", text)
        btn:SetAttribute("spell", nil); btn:SetAttribute("item", nil)
        btn:SetAttribute("unit", nil)
    end,
}

-- Display-only button (talent reminders, the pet menu opener).
local ACTION_ATTRIBUTES = { "type", "spell", "item", "macrotext" }
local function ClearIconAction(btn)
    for _, attribute in ipairs(ACTION_ATTRIBUTES) do
        btn:SetAttribute(attribute, nil)
    end
end

local function SetIconSpell(btn, spellID, texture, label)
    if not InCombat() then ICON_ACTION_ATTRS.spell(btn, spellID) end
    btn._icon:SetTexture(texture or AR.GetSpellTextureCached(spellID) or 134400)
    btn._tooltipSpell = spellID
    btn._tooltipItem = nil
    btn._petMenuClass = nil
end

local function SetIconItem(btn, itemID, texture, label)
    if not InCombat() then ICON_ACTION_ATTRS.item(btn, itemID) end
    btn._icon:SetTexture(texture or GetItemIcon(itemID) or 134400)
    btn._tooltipSpell = nil
    btn._tooltipItem = itemID
    btn._petMenuClass = nil
end

local function SetIconMacro(btn, macrotext, texture, spellID)
    if not InCombat() then ICON_ACTION_ATTRS.macro(btn, macrotext) end
    btn._icon:SetTexture(texture or AR.GetSpellTextureCached(spellID) or 134400)
    btn._tooltipSpell = spellID
    btn._tooltipItem = nil
    btn._petMenuClass = nil
end

local function HidePetMenu()
    if _G.KUIAR_PetMenu then
        _G.KUIAR_PetMenu:Hide()
    end
end

local TogglePetMenu
do
    local function GetPetMenuEntries(playerClass)
        local def = PET_REMINDER_DEFS[playerClass]
        local entries = {}
        if not def then
            return entries
        end

        for _, info in ipairs(def.buttons or {}) do
            if info.spellID and (info.requireKnown ~= true or Known(info.spellID)) then
                entries[#entries + 1] = info
            end
        end

        return entries
    end

    local function EnsurePetMenu()
        local menu = _G.KUIAR_PetMenu
        if menu then
            return menu
        end

        menu = CreateFrame("Frame", "KUIAR_PetMenu", UIParent, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetFrameLevel(500)
        menu:Hide()
        menu:SetClampedToScreen(true)
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        menu:SetBackdropColor(0.05, 0.06, 0.08, 0.97)
        menu:SetBackdropBorderColor(0, 0, 0, 1)
        menu.buttons = {}

        local title = menu:CreateFontString(nil, "OVERLAY")
        title:SetPoint("TOP", menu, "TOP", 0, -10)
        AR.SetCaptionFont(title, AR.ResolveFontPath(), 12)
        title:SetTextColor(1, 1, 1, 0.92)
        menu.Title = title

        menu:SetScript("OnHide", function(self)
            if self._anchorButton then
                self._anchorButton._petMenuOpen = nil
            end
        end)

        _G.KUIAR_PetMenu = menu
        return menu
    end

    local function ConfigurePetMenu(playerClass, anchorButton)
        local menu = EnsurePetMenu()
        local entries = GetPetMenuEntries(playerClass)
        local columns = 4
        local buttonSize = 54
        local spacing = 10
        local rows = math.max(1, math.ceil(#entries / columns))
        local contentWidth = (math.min(#entries, columns) * buttonSize) + (math.max(0, math.min(#entries, columns) - 1) * spacing)
        local width = math.max(160, contentWidth + 24)
        local height = 34 + (rows * buttonSize) + (math.max(0, rows - 1) * spacing) + 18
        local def = PET_REMINDER_DEFS[playerClass]

        menu:SetSize(width, height)
        menu.Title:SetText(LText((def and def.label) or "Pet"))
        menu._anchorButton = anchorButton

        for i, info in ipairs(entries) do
            local btn = menu.buttons[i]
            if not btn then
                btn = CreateFrame("Button", nil, menu, "SecureActionButtonTemplate,BackdropTemplate")
                btn:SetBackdrop({
                    bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                    insets = { left = 0, right = 0, top = 0, bottom = 0 },
                })
                btn:SetBackdropColor(0.08, 0.10, 0.14, 0.96)
                btn:SetBackdropBorderColor(0.12, 0.12, 0.15, 1)

                btn.Icon = btn:CreateTexture(nil, "ARTWORK")
                btn.Icon:SetPoint("TOPLEFT", 3, -3)
                btn.Icon:SetPoint("BOTTOMRIGHT", -3, 3)
                btn.Icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

                btn.Label = btn:CreateFontString(nil, "OVERLAY")
                btn.Label:SetPoint("TOP", btn, "BOTTOM", 0, -3)
                AR.SetCaptionFont(btn.Label, AR.ResolveFontPath(), 10)
                btn.Label:SetTextColor(1, 1, 1, 0.88)

                btn:SetScript("OnEnter", function(self)
                    if self._spellID then
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetSpellByID(self._spellID)
                        GameTooltip:Show()
                    end
                end)
                btn:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)
                btn:HookScript("PostClick", function()
                    HidePetMenu()
                end)

                menu.buttons[i] = btn
            end

            local col = (i - 1) % columns
            local row = math.floor((i - 1) / columns)
            btn:SetSize(buttonSize, buttonSize)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", menu, "TOPLEFT", 12 + (col * (buttonSize + spacing)), -(32 + (row * (buttonSize + 18 + spacing))))
            btn.Icon:SetTexture(AR.GetSpellTextureCached(info.spellID) or 134400)
            btn.Label:SetText(LText(info.label or ""))
            btn:SetAttribute("type", "spell")
            btn:SetAttribute("spell", info.spellID)
            btn._spellID = info.spellID
            btn:Show()
        end

        for i = #entries + 1, #menu.buttons do
            menu.buttons[i]:Hide()
        end
    end

    function TogglePetMenu(anchorButton, playerClass)
        if InCombat() or not anchorButton then
            return
        end

        local menu = EnsurePetMenu()
        if menu:IsShown() and menu._anchorButton == anchorButton then
            HidePetMenu()
            return
        end

        ConfigurePetMenu(playerClass, anchorButton)
        menu:ClearAllPoints()
        menu:SetPoint("TOP", anchorButton, "BOTTOM", 0, -12)
        menu:Show()
        anchorButton._petMenuOpen = true
    end
end

local function SetPetMenuButton(btn, playerClass, texture, label)
    local def = PET_REMINDER_DEFS[playerClass]
    ClearIconAction(btn)
    btn._tooltipSpell = nil
    btn._tooltipItem = nil
    btn._petMenuClass = playerClass
    btn._icon:SetTexture(texture or (def and def.icon) or 134400)
    btn._text:SetText(LText(label or (def and def.label) or "Pet"))

    if not btn._petMenuHooked then
        btn._petMenuHooked = true
        btn:HookScript("PostClick", function(self, mouseButton)
            if mouseButton == "LeftButton" and self._petMenuClass then
                TogglePetMenu(self, self._petMenuClass)
            end
        end)
    end
end

-- Reminder evaluation. Each Collect* function appends records describing a
-- missing reminder: { cat, data?, dismissKey?, scale, setup(btn) }. Refresh
-- then turns the records into secure or combat icons.
local refreshQueued = false

local function GetReminderOrderKey(reminder)
    if not reminder then return nil end
    if reminder.cat and reminder.data and reminder.data.key then
        return reminder.cat .. ":" .. reminder.data.key
    end
    if reminder.dismissKey then return reminder.dismissKey end
    return reminder.cat
end

local function ApplyReminderIconOrder(list)
    local order = db and db.profile and db.profile.display and db.profile.display.iconOrder
    if type(order) ~= "table" or #list < 2 then return end
    local rank = {}
    for index, key in ipairs(order) do
        if type(key) == "string" and rank[key] == nil then rank[key] = index end
    end
    for index, reminder in ipairs(list) do reminder._ktOriginalOrder = index end
    table.sort(list, function(left, right)
        local leftRank = rank[GetReminderOrderKey(left)]
        local rightRank = rank[GetReminderOrderKey(right)]
        if leftRank and rightRank then return leftRank < rightRank end
        if leftRank then return true end
        if rightRank then return false end
        return left._ktOriginalOrder < right._ktOriginalOrder
    end)
    for _, reminder in ipairs(list) do reminder._ktOriginalOrder = nil end
end

-- Secure buttons can only be hidden out of combat.
local function HideAllIcons()
    HidePetMenu()
    if InCombat() then return end
    for _, row in ipairs(SECURE_ROW_ORDER) do
        for _, btn in ipairs(row.shown) do
            RemoveGlow(btn)
            btn._text:SetText("")
            btn:Hide()
        end
        wipe(row.shown)
    end
    if talentIconAnchor then talentIconAnchor:Hide() end
end

-- Fills the next secure button of a row from a reminder record.
local function PlaceSecureIcon(row, index, setup, dismissKey)
    local btn = SecureIcon(row, index)
    if row.dismissable then btn._dismissKey = dismissKey end
    setup(btn)
    RemoveGlow(btn)
    GlowFromSettings(btn)
    StyleCaption(btn)
    btn:Show()
    row.shown[#row.shown + 1] = btn
end

-- Record for a reminder that casts entry.castSpell when clicked.
local function SpellReminder(cat, entry, scale, caption, dismissKey)
    return {
        cat = cat, data = entry, scale = scale, dismissKey = dismissKey,
        setup = function(btn)
            SetIconSpell(btn, entry.castSpell, AR.GetSpellTextureCached(entry.castSpell), entry.name)
            btn._text:SetText(caption)
        end,
    }
end

-- Record for a consumable that uses a bag item when clicked.
local function ItemReminder(itemID, texture, caption, dismissKey, scale)
    return {
        cat = "consumable", dismissKey = dismissKey, scale = scale,
        setup = function(btn)
            SetIconItem(btn, itemID, texture)
            btn._text:SetText(caption)
        end,
    }
end

-- True when every ID is on the combat-readable whitelist.
local function ReadableInCombat(spellIDs)
    for _, id in ipairs(spellIDs) do
        if not NON_SECRET_SPELL_IDS[id] then return false end
    end
    return true
end

local function SpecAllows(entry, specID)
    if not entry.specs then return true end
    for _, allowed in ipairs(entry.specs) do
        if allowed == specID then return true end
    end
    return false
end

-- Ally buffs only make sense in a group, and some only inside an instance.
local function GroupRequirementMet(entry, inInstance)
    if entry.requireInstanceGroup then return inInstance and IsGrouped() end
    if entry.requireGroup then return IsGrouped() end
    return true
end

-- With "show if others are missing" in a group, any member without the buff
-- triggers the reminder; otherwise only the player's own buffs count.
local function RaidBuffLacking(buff, settings)
    if settings.showOthersMissing and IsGrouped() then
        return AnyGroupMemberMissingBuff(buff.buffIDs)
    end
    return not PlayerHasAuraByID(buff.buffIDs)
end

local function CollectRaidBuffs(missing, playerClass, inInstance, inCombat)
    local settings = db.profile.raidBuffs
    if not (inInstance or settings.showNonInstanced) then return end
    for _, buff in ipairs(RAID_BUFFS) do
        if buff.class == playerClass and settings.enabled[buff.key] and Known(buff.castSpell)
            and (not inCombat or ReadableInCombat(buff.buffIDs))
            and RaidBuffLacking(buff, settings) then
            missing[#missing + 1] = SpellReminder("raidbuff", buff, settings.scale or 1.0, AR.GetReminderShortLabel(buff.name))
        end
    end
end

local CollectAuras, AuraIsMissing
do
    -- Missing-tests per aura kind. Ally-placed buffs are never reported while
    -- solo, and in combat their state comes from the pre-combat snapshot (or is
    -- not reported at all when no snapshot exists).
    local AURA_MISSING_BY_CHECK = {
        mineOnRaid = function(aura, inInstance, inCombat)
            if inCombat or not IsGrouped() then return false end
            return not BuffExistsOnAnyGroupMember(aura.buffIDs)
        end,
        ownOnRaid = function(aura, inInstance, inCombat)
            if not IsGrouped() then return false end
            if inCombat then return _preCombatOwnOnRaidCache[aura.buffIDs[1]] == false end
            return not PlayerOwnBuffOnAnyGroupMember(aura.buffIDs)
        end,
        playerSelfCast = function(aura)
            return not PlayerHasSelfCastAuraByID(aura.buffIDs)
        end,
    }

    function AuraIsMissing(aura, inInstance, inCombat)
        if aura.isStance then return not AR.PlayerHasActiveStanceSpell(aura.castSpell) end
        local test = AURA_MISSING_BY_CHECK[aura.check]
        if test then return test(aura, inInstance, inCombat) end
        return not PlayerHasAuraByID((inInstance and aura.instanceBuffIDs) or aura.buffIDs)
    end

    -- An aura can be judged in combat only when it is flagged combatOk and all
    -- of its IDs are readable.
    local function AuraCheckable(aura, inCombat)
        return not inCombat or (aura.combatOk and ReadableInCombat(aura.buffIDs))
    end

    local function PvPExcluded(aura)
        return aura.noPvP and AR.InPvPInstance()
    end

    -- Out of combat: is one of the enabled, known paladin auras already up?
    local function PaladinAuraAlreadyUp(enabled, inInstance)
        for _, aura in ipairs(AURAS) do
            if aura.paladinAura and enabled[aura.key] and Known(aura.castSpell) and not PvPExcluded(aura)
                and PlayerHasAuraByID((inInstance and aura.instanceBuffIDs) or aura.buffIDs) then
                return true
            end
        end
        return false
    end

    function CollectAuras(missing, playerClass, specID, inInstance, inCombat)
        local settings = db.profile.auras
        if not (inInstance or settings.showNonInstanced) then return end
        local enabled = settings.enabled
        -- The paladin auras exclude each other: no icon while one of them is up,
        -- otherwise a single icon for the first enabled one.
        local paladinCovered = playerClass == "PALADIN" and not inCombat and PaladinAuraAlreadyUp(enabled, inInstance)
        for _, aura in ipairs(AURAS) do
            if not aura.standalone and not (aura.paladinAura and paladinCovered)
                and aura.class == playerClass and enabled[aura.key] and Known(aura.castSpell)
                and not (aura.notIfKnown and Known(aura.notIfKnown)) and not PvPExcluded(aura)
                and SpecAllows(aura, specID) and GroupRequirementMet(aura, inInstance)
                and AuraCheckable(aura, inCombat) and AuraIsMissing(aura, inInstance, inCombat) then
                missing[#missing + 1] = SpellReminder("aura", aura, settings.scale or 1.0, AR.GetReminderShortLabel(aura.name))
                if aura.paladinAura then paladinCovered = true end
            end
        end
    end
end

-- Is this poison on the player's weapons right now?
local function PoisonApplied(poison)
    local ok, applied = pcall(C_UnitAuras.GetPlayerAuraBySpellID, poison.castSpell)
    return (ok and applied) and true or false
end

local CollectConsumables
do
    -- Rogue poisons are counted per kind (lethal / non-lethal) so one missing
    -- poison yields one icon per kind, not one per poison. Dragon-Tempered
    -- Blades raises the requirement to two of each kind.
    local POISON_KINDS = {
        { cat = "lethal",    dismissKey = "consumable:rogue_lethal" },
        { cat = "nonlethal", dismissKey = "consumable:rogue_utility" },
    }

    local function CollectRoguePoisons(missing, settings)
        local tally = { lethal = { known = 0, applied = 0 }, nonlethal = { known = 0, applied = 0 } }
        for _, poison in ipairs(ROGUE_POISONS) do
            if Known(poison.castSpell) then
                local kind = tally[poison.cat == "lethal" and "lethal" or "nonlethal"]
                kind.known = kind.known + 1
                if PoisonApplied(poison) then
                    kind.applied = kind.applied + 1
                elseif settings.enabled[poison.key] and not kind.suggestion then
                    kind.suggestion = poison
                end
            end
        end
        local wanted = Known(DRAGON_TEMPERED_BLADES) and 2 or 1
        for _, spec in ipairs(POISON_KINDS) do
            local kind = tally[spec.cat]
            if kind.suggestion and kind.applied < math.min(kind.known, wanted) then
                missing[#missing + 1] = SpellReminder("consumable", kind.suggestion, settings.scale or 1.0, LText("Poison"), spec.dismissKey)
            end
        end
    end

    -- Paladin rites and Shaman imbues put a temporary enchant on the main hand;
    -- with none present every enabled, known option is offered.
    local function CollectWeaponSpells(missing, settings, spells, family)
        if AR.GetTemporaryWeaponEnchants() then return end
        for _, spell in ipairs(spells) do
            if settings.enabled[spell.key] and Known(spell.castSpell) then
                missing[#missing + 1] = SpellReminder("consumable", spell, settings.scale or 1.0, AR.GetReminderShortLabel(spell.name, family))
            end
        end
    end

    local function ShamanShieldMissing(shield)
        if shield.orbitTalent and Known(shield.orbitTalent) then
            local onSelf = PlayerHasAuraByID(shield.selfOrbitBuff)
            local onAlly = PlayerOwnBuffOnAnyGroupMember(shield.otherBuff)
            return not onSelf or (not onAlly and IsGrouped())
        end
        return not PlayerHasAuraByID(shield.buffIDs)
    end

    -- Earth Shield's IDs (974, 383648) are readable in combat, so it is checked
    -- on every pass; Lightning and Water Shield only out of combat.
    local function CollectShamanShields(missing, settings, specID, earthShieldOnly)
        for _, shield in ipairs(SHAMAN_SHIELDS) do
            if (shield.key == "es") == earthShieldOnly and settings.enabled[shield.key] and Known(shield.castSpell)
                and SpecAllows(shield, specID) and ShamanShieldMissing(shield) then
                missing[#missing + 1] = SpellReminder("consumable", shield, settings.scale or 1.0, AR.GetReminderShortLabel(shield.name, "SHAMAN_SHIELD"))
            end
        end
    end

    -- runeDisplayMode -> where augment runes are expected.
    local RUNE_CONTENT = {
        mythic        = function() return AR.IsMythicZeroOrMythicRaid() end,
        heroic_mythic = function() return AR.IsHeroicOrMythicInstance() end,
        all           = function() return AR.InRealInstancedContent() end,
    }

    local function CollectAugmentRune(missing, settings)
        if not settings.enabled.augment_rune then return end
        local expected = RUNE_CONTENT[settings.runeDisplayMode or "mythic"]
        if not (expected and expected()) or PlayerHasAuraByID(RUNE_BUFF_IDS) then return end
        local rune = (Owned(AUGMENT_RUNE_VOID) and AUGMENT_RUNE_VOID) or (Owned(AUGMENT_RUNE_ETHER) and AUGMENT_RUNE_ETHER) or nil
        if rune then
            missing[#missing + 1] = ItemReminder(rune, GetItemIcon(rune), AR.GetReminderShortLabel("Augment Rune"), "consumable:rune", settings.scale or 1.0)
        end
    end

    -- Weapon oils and stones go on the main hand first, then on an off-hand
    -- weapon. The icon runs a macro that uses the item on that slot.
    local function CollectWeaponEnchant(missing, settings)
        if not settings.enabled.weapon_enchant then return end
        local mainEnchanted, _, _, _, offEnchanted = AR.GetTemporaryWeaponEnchants()
        local mainFamily, offFamily = AR.GetWeaponCategory(16), AR.GetWeaponCategory(17)
        local slot, family
        if mainFamily and not mainEnchanted then
            slot, family = 16, mainFamily
        elseif offFamily and mainEnchanted and not offEnchanted then
            slot, family = 17, offFamily
        end
        if not slot then return end

        local lastUsed = db.char and db.char.lastUsedWeaponEnchant or nil
        local itemID = AR.FindWeaponEnchantItem(settings.preferredWeaponEnchant or "last_used", lastUsed, family)
            or FirstFittingWeaponItem(family)
        if not itemID then return end
        local texture = GetItemIcon(itemID) or 134400
        local macro = "/use item:" .. itemID .. "\n/use " .. slot
        missing[#missing + 1] = {
            cat = "consumable", dismissKey = "consumable:weapon_enchant", scale = settings.scale or 1.0,
            setup = function(btn)
                SetIconMacro(btn, macro, texture, nil)
                btn._tooltipItem = itemID
                btn._text:SetText(AR.GetReminderShortLabel("Weapon Enchant"))
            end,
        }
    end

    -- Flask and food: the buff test, the bag pick, and the icon to fall back to.
    local BUFF_CONSUMABLES = {
        {
            enabledKey = "flask", dismissKey = "consumable:flask", fallbackIcon = 134830,
            caption = function() return LText("Flask") end,
            active = function() return AR.PlayerHasFlaskBuff() end,
            pick = function(settings)
                return AR.FindFlaskItem(settings.preferredFlask or "last_used", db.char and db.char.lastUsedFlask or nil)
            end,
        },
        {
            enabledKey = "food", dismissKey = "consumable:food", fallbackIcon = 136000,  -- 136000: Well Fed
            caption = function() return LText("Food") end,
            active = function() return AR.PlayerHasWellFed() end,
            pick = function(settings)
                return AR.FindFoodItem(settings.preferredFood or "last_used", db.char and db.char.lastUsedFood or nil)
            end,
        },
    }

    local function CollectBuffConsumables(missing, settings)
        for _, kind in ipairs(BUFF_CONSUMABLES) do
            if settings.enabled[kind.enabledKey] and not kind.active() then
                local itemID = kind.pick(settings)
                if itemID then
                    missing[#missing + 1] = ItemReminder(itemID, GetItemIcon(itemID) or kind.fallbackIcon, kind.caption(), kind.dismissKey, settings.scale or 1.0)
                end
            end
        end
    end

    -- Map IDs where the Inky Black Potion is wanted, typed as a comma or space
    -- separated list. The parsed set is cached per settings table (weakly, so
    -- nothing is written into the saved profile) until the string changes.
    local inkyZoneCache = setmetatable({}, { __mode = "k" })
    local function InkyBlackZones(settings)
        local source = settings.inkyBlackZones or ""
        if source == "" then return nil end
        local cached = inkyZoneCache[settings]
        if not cached or cached.source ~= source then
            local zones = {}
            for mapID in source:gmatch("[^,%s]+") do zones[mapID] = true end
            cached = { source = source, zones = zones }
            inkyZoneCache[settings] = cached
        end
        return cached.zones
    end

    local function CollectInkyBlack(missing, settings)
        if not settings.enabled.inky_black then return end
        local zones = InkyBlackZones(settings)
        if not (zones and zones[tostring(C_Map.GetBestMapForUnit("player") or 0)]) then return end
        if Owned(INKY_BLACK_ITEM) and not AR.PlayerHasBuffByName("Inky Black Potion") then
            missing[#missing + 1] = ItemReminder(INKY_BLACK_ITEM, GetItemIcon(INKY_BLACK_ITEM), AR.GetReminderShortLabel("Inky Black Potion"), "consumable:inky_black", settings.scale or 1.0)
        end
    end

    -- Bag consumables are only suggested inside instanced content, in this order.
    local INSTANCE_CONSUMABLES = { CollectAugmentRune, CollectWeaponEnchant, CollectBuffConsumables, CollectInkyBlack }

    -- Consumables are never suggested inside a keystone. Apart from Earth
    -- Shield they are evaluated out of combat only, because their auras are
    -- secret there. Class upkeep obeys showSpecialsNonInstanced.
    function CollectConsumables(missing, playerClass, specID, inInstance, inKeystone, inCombat)
        if inKeystone then return end
        local settings = db.profile.consumables
        local classUpkeep = inInstance or settings.showSpecialsNonInstanced
        if not inCombat then
            if classUpkeep then
                if playerClass == "ROGUE" then
                    CollectRoguePoisons(missing, settings)
                elseif playerClass == "PALADIN" then
                    CollectWeaponSpells(missing, settings, PALADIN_RITES)
                elseif playerClass == "SHAMAN" then
                    CollectWeaponSpells(missing, settings, SHAMAN_IMBUES, "SHAMAN_IMBUE")
                    CollectShamanShields(missing, settings, specID, false)
                end
            end
            if inInstance then
                for _, collect in ipairs(INSTANCE_CONSUMABLES) do collect(missing, settings) end
            end
        end
        if classUpkeep and playerClass == "SHAMAN" then
            CollectShamanShields(missing, settings, specID, true)
        end
    end
end

local function CollectPetReminders(missing, playerClass)
    if not PET_REMINDER_CLASSES[playerClass] then
        return
    end

    local co = db.profile.consumables
    if not (co and co.enabled and co.enabled.pet ~= false) then
        return
    end

    local def = PET_REMINDER_DEFS[playerClass]
    if not def then
        return
    end

    if playerClass == "WARLOCK" and Known(108503) and PlayerHasAuraByID({ 196099 }) then
        return
    end

    if UnitExists("pet") and not UnitIsDead("pet") then
        return
    end

    missing[#missing + 1] = {
        mode = "texture",
        texture = def.icon,
        label = def.label,
        cat = "consumable",
        dismissKey = "consumable:pet",
        scale = co.scale or 1.0,
        setup = function(btn)
            SetPetMenuButton(btn, playerClass, def.icon, def.label)
        end,
    }
end

local CollectTalentReminders
do
    -- Lookup sets for each saved talent reminder, kept in a weak table keyed
    -- by the reminder record so they never end up in SavedVariables. Zone IDs
    -- are the locale-proof match; zone names remain for reminders saved
    -- before IDs existed, compared against the canonical English zone name.
    local talentZoneCache = setmetatable({}, { __mode = "k" })
    local function TalentZoneSets(reminder)
        local sets = talentZoneCache[reminder]
        if not sets then
            sets = {}
            talentZoneCache[reminder] = sets
        end
        if not sets.names and reminder.zoneNames then
            local names = {}
            for _, zoneName in ipairs(reminder.zoneNames) do names[zoneName] = true end
            sets.names = names
        end
        if not sets.ids then
            local ids = {}
            for _, raw in ipairs(reminder.zoneIDs or {}) do
                local id = tonumber(raw)
                if id then ids[id] = true end
            end
            sets.ids = ids
        end
        return sets.ids, sets.names
    end

    local function TalentZoneMatches(reminder, instanceName, instanceID)
        local ids, names = TalentZoneSets(reminder)
        if instanceID then
            if ids[instanceID] then return true end
            local zone = TALENT_REMINDER_ZONE_BY_INSTANCE_ID[instanceID]
            if zone and names and names[zone.name] then return true end
        end
        return names ~= nil and names[instanceName] == true
    end

    -- Talent icons only display; the talent itself is changed in the talent UI.
    local function TalentReminderRecord(reminder, caption)
        local spellID = reminder.spellID
        local texture = AR.GetSpellTextureCached(spellID) or 134400
        return {
            cat = "talent", scale = 1.0,
            setup = function(btn)
                if not InCombat() then ClearIconAction(btn) end
                btn._icon:SetTexture(texture)
                btn._tooltipSpell = spellID
                btn._tooltipItem = nil
                btn._text:SetText(caption)
            end,
        }
    end

    -- In a listed zone a missing talent is reminded; with showNotNeeded, a
    -- talent still taken outside its zones is flagged "(N/N)" (not needed).
    function CollectTalentReminders(talentMissing, inInstance, inKeystone, inCombat)
        if inKeystone or inCombat or not inInstance then return end
        local reminders = db.profile.talentReminders
        if not (reminders and #reminders > 0) then return end
        local instanceName, instanceID = AR.GetCurrentInstanceName()
        -- GetInstanceInfo can lack the ID for a moment while zoning in.
        if not instanceID and C_Map and C_Map.GetBestMapForUnit then
            instanceID = C_Map.GetBestMapForUnit("player")
        end
        if not instanceName then return end
        for _, reminder in ipairs(reminders) do
            local inZone = TalentZoneMatches(reminder, instanceName, instanceID)
            local learned = IsPlayerSpell(reminder.spellID) or IsSpellKnown(reminder.spellID)
            local spellName = reminder.spellName or "Unknown"
            if inZone and not learned then
                talentMissing[#talentMissing + 1] = TalentReminderRecord(reminder, spellName)
            elseif not inZone and reminder.showNotNeeded and learned then
                talentMissing[#talentMissing + 1] = TalentReminderRecord(reminder, spellName .. " (N/N)")
            end
        end
    end
end

-- Scratch lists reused by every Refresh.
local _refreshMissing = {}
local _refreshTalentMissing = {}
local Beacons = ns.AuraRemindersBeacons

local function HideBeacons()
    Beacons.SetVisible(Beacons.BOL, false)
    Beacons.SetVisible(Beacons.BOF, false)
end

local Refresh
do
    -- Key a reminder is dismissed under (see DismissOnMiddleClick).
    local function DismissKeyOf(m)
        return m.dismissKey or (m.data and m.data.key and (m.cat .. ":" .. m.data.key)) or nil
    end

    local function IsDismissed(m)
        local key = DismissKeyOf(m)
        return key ~= nil and _dismissedUntilLoad[key] == true, key
    end

    -- In combat only texture reminders (the pet) and reminders whose buffs are
    -- all combat-readable may appear; everything else stays hidden.
    local function CombatDisplayable(m)
        if m.mode == "texture" then return true end
        return m.data ~= nil and m.data.buffIDs ~= nil and ReadableInCombat(m.data.buffIDs)
    end

    local function ShowCombatReminders(missing)
        local useCursor = db.profile.display.cursorAttach and cursorAnchor
        local placed = { [VISUAL_ROWS.combat] = 0, [VISUAL_ROWS.cursor] = 0 }
        for _, m in ipairs(missing) do
            if not IsDismissed(m) and CombatDisplayable(m) then
                local spellID = m.data and m.data.castSpell
                local texture, label
                if m.mode == "texture" then
                    texture, label = m.texture, LText(m.label)
                else
                    label = m.data and AR.GetReminderShortLabel(m.data.name)
                end
                texture = texture or (spellID and AR.GetSpellTextureCached(spellID)) or 134400
                local row = (useCursor and IsImportantBuff(m)) and VISUAL_ROWS.cursor or VISUAL_ROWS.combat
                placed[row] = placed[row] + 1
                PushVisualIcon(row, placed[row], spellID, texture, label or "")
            end
        end
        for _, row in ipairs({ VISUAL_ROWS.combat, VISUAL_ROWS.cursor }) do
            if placed[row] > 0 then
                row.anchor():Show()
                AR.LayoutIconRow(row.shown, row.anchor())
            end
        end
    end

    local function ShowSecureReminders(missing, talentMissing)
        local placed = 0
        for _, m in ipairs(missing) do
            local dismissed, key = IsDismissed(m)
            if not dismissed then
                placed = placed + 1
                PlaceSecureIcon(SECURE_ROWS.main, placed, m.setup, key)
            end
        end
        if placed > 0 then
            AR.LayoutIconRow(activeIcons, iconAnchor)
            iconAnchor:Show()
        end
        if #talentMissing > 0 and talentIconAnchor then
            for index, m in ipairs(talentMissing) do
                PlaceSecureIcon(SECURE_ROWS.talent, index, m.setup)
            end
            AR.LayoutIconRow(talentActiveIcons, talentIconAnchor)
            talentIconAnchor:Show()
        end
    end

    function Refresh()
        if not db then return end
        if db.profile and db.profile.enable == false then
            AR.HideCombatIcons()
            AR.HideCursorIcons()
            HideAllIcons()
            HideBeacons()
            return
        end
        HidePetMenu()
        if optionsPanelVisible then AR.HideCombatIcons(); HideAllIcons(); return end

        -- Nothing is shown in a vehicle or while skyriding; these checks are safe
        -- in combat, where the secure icons can only be faded.
        if UnitInVehicle("player") or (IsMounted() and IsFlying()) then
            AR.HideCombatIcons(); AR.HideCursorIcons()
            if InCombat() then
                FadeOutSecureIcons()
            else
                HideAllIcons()
            end
            return
        end

        AR.CacheInstanceInfo()
        local playerClass = AR.GetPlayerClass()
        local specID = AR.GetActiveSpecID()
        local inInstance = AR.InRealInstancedContent()
        local inKeystone = AR.IsMythicPlusActive()
        local inCombat = InCombat()

        local missing = _refreshMissing
        wipe(missing)
        CollectRaidBuffs(missing, playerClass, inInstance, inCombat)
        CollectAuras(missing, playerClass, specID, inInstance, inCombat)
        if not AR.InPvPInstance() then
            CollectConsumables(missing, playerClass, specID, inInstance, inKeystone, inCombat)
        end
        local talentMissing = _refreshTalentMissing
        wipe(talentMissing)
        CollectTalentReminders(talentMissing, inInstance, inKeystone, inCombat)
        CollectPetReminders(missing, playerClass)
        ApplyReminderIconOrder(missing)

        -- Lockdown: secure buttons are faded (alpha is allowed) and the plain
        -- combat frames show what is still known to be missing.
        if inCombat then
            FadeOutSecureIcons()
            AR.HideCombatIcons()
            AR.HideCursorIcons()
            if #missing > 0 then ShowCombatReminders(missing) end
            return
        end

        AR.HideCombatIcons()
        AR.HideCursorIcons()
        HideAllIcons()
        ShowSecureReminders(missing, talentMissing)
    end
end

-- Coalesces bursts of events into one Refresh on the next frame.
local function RequestRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        Refresh()
    end)
end


-- Unlock mode. The mover box is at least three icons wide and tall enough
-- for the caption; returns width, height, icon size and caption height.
local function MoverMetrics()
    local display = db.profile.display or {}
    local size = floor(ICON_SIZE * (display.scale or 1.0) + 0.5)
    local count = max(#activeIcons, 3)
    local width = count * size + (count - 1) * (display.iconSpacing or 8)
    local captionHeight = 0
    if display.showText then
        captionHeight = (display.textSize or 11) + abs(display.textYOffset or -2)
    end
    return width, size + captionHeight, size, captionHeight
end

local ApplyUnlockPos
do
    -- Older profiles saved the mover's TOPLEFT corner; positions are now kept as
    -- the centre of the first icon. Converted once, then marked.
    local function UpgradeSavedPosition(pos)
        if not (pos and pos.point) or pos._ktCenterAligned then
            return pos
        end
        if pos.point == "TOPLEFT" and (pos.relPoint == nil or pos.relPoint == "TOPLEFT") then
            local width, _, size = MoverMetrics()
            pos.point, pos.relPoint = "CENTER", "TOPLEFT"
            pos.x = (pos.x or 0) + width / 2
            pos.y = (pos.y or 0) - size / 2
        end
        pos._ktCenterAligned = true
        return pos
    end

    function ApplyUnlockPos()
        if not iconAnchor or not db then return end
        local pos = db.profile.unlockPos
        if pos and pos.point then
            pos = UpgradeSavedPosition(pos)
            db.profile.unlockPos = pos
            if pos.scale then pcall(function() iconAnchor:SetScale(pos.scale) end) end
            iconAnchor:ClearAllPoints()
            iconAnchor:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
        else
            local d = db.profile.display
            pcall(function() iconAnchor:SetScale(1) end)
            iconAnchor:ClearAllPoints()
            iconAnchor:SetPoint("CENTER", UIParent, "CENTER", d.xOffset or 0, d.yOffset or 0)
        end
    end
end

local function RegisterUnlockElements()
    if not KT or not KT.RegisterMovableElements then return end
    KT:RegisterMovableElements({
        {
            key = "KUIAR_Reminders",
            label = "Aura Reminders",
            group = "Aura Reminders",
            order = 600,
            getFrame = function() return iconAnchor end,
            getSize = function()
                local w, h = MoverMetrics()
                return w, h
            end,
            getRect = function()
                if not (iconAnchor and iconAnchor.GetCenter) then
                    return nil
                end
                local centerX, centerY = iconAnchor:GetCenter()
                if not centerX or not centerY then
                    return nil
                end
                local uiScale = UIParent:GetEffectiveScale()
                local frameScale = iconAnchor:GetEffectiveScale()
                centerX = centerX * frameScale / uiScale
                centerY = centerY * frameScale / uiScale
                local w, h, sz = MoverMetrics()
                return centerX - (w / 2), centerY + (sz / 2), w, h
            end,
            translateMoverPosition = function(_, pos)
                local w, _, sz = MoverMetrics()
                return {
                    point = "CENTER",
                    relativePoint = "TOPLEFT",
                    x = (pos.x or 0) + (w / 2),
                    y = (pos.y or 0) - (sz / 2),
                    scale = pos.scale,
                }
            end,
            savePosition = function(key, point, relPoint, x, y, scale)
                db.profile.unlockPos = {point=point, relPoint=relPoint, x=x, y=y, scale=scale, _ktCenterAligned=true}
                ApplyUnlockPos()
            end,
            loadPosition = function()
                if db.profile.unlockPos and not db.profile.unlockPos._ktCenterAligned then
                    ApplyUnlockPos()
                end
                return db.profile.unlockPos
            end,
            getScale = function()
                local pos = db.profile.unlockPos
                return pos and pos.scale or 1.0
            end,
            clearPosition = function()
                db.profile.unlockPos = nil
            end,
            applyPosition = function()
                ApplyUnlockPos()
            end,
        },
    })
end

-- Paladin beacons are in KUIAuraReminders_Beacons.lua. Set up here so its event
-- frame registers while this file loads; Init runs at the end of the login handler.
Beacons.Setup({
    client = "retail",
    Live = BeaconLive,
    GetCombatAnchor = function() return combatAnchor end,
    IsGrouped = IsGrouped,
    Known = Known,
    GetPlayerClass = AR.GetPlayerClass,
    GetSpellTexture = AR.GetSpellTextureCached,
    GetShortLabel = AR.GetReminderShortLabel,
    PlainIcon = PlainIcon,
    StyleCaption = StyleCaption,
    GlowFromSettings = GlowFromSettings,
    RemoveGlow = RemoveGlow,
    LayoutIconRow = AR.LayoutIconRow,
})

-- Event wiring. PLAYER_LOGIN builds the profile, the anchors and the
-- globals the options module reads; the other handlers below react to
-- combat, loading screens and unit changes. Any other registered event
-- simply asks for a refresh.
local mainFrame = CreateFrame("Frame")

local function OnLogin()
    if not AceDB then
        return
    end
    db = AceDB:New("KUIAuraRemindersDB", defaults, true)
    BeaconLive.db = db

    -- Migration: Source of Magic moved from raidBuffs to auras
    if db.profile.raidBuffs and db.profile.raidBuffs.enabled and db.profile.raidBuffs.enabled.som ~= nil then
        if db.profile.auras and db.profile.auras.enabled then
            if db.profile.auras.enabled.som == nil then
                db.profile.auras.enabled.som = db.profile.raidBuffs.enabled.som
            end
        end
        db.profile.raidBuffs.enabled.som = nil
    end

    -- Older builds cached parsed zone sets inside the profiles; tidy them out
    -- of every stored profile once. A preferred flask this build does not list
    -- goes back to the default.
    local flaskKeys = { last_used = true }
    for _, flask in ipairs(FLASK_ITEMS) do flaskKeys[flask.key] = true end
    local function ScrubRuntimeCaches(profile)
        if type(profile) ~= "table" then return end
        local consumables = rawget(profile, "consumables")
        if type(consumables) == "table" then
            consumables._inkyZoneSet, consumables._inkyZoneSrc = nil, nil
            if consumables.preferredFlask and not flaskKeys[consumables.preferredFlask] then
                consumables.preferredFlask = nil
            end
        end
        local reminders = rawget(profile, "talentReminders")
        if type(reminders) == "table" then
            for _, reminder in ipairs(reminders) do
                if type(reminder) == "table" then reminder._nameSet, reminder._instanceIDSet = nil, nil end
            end
        end
    end
    for _, profile in pairs(db.profiles or {}) do ScrubRuntimeCaches(profile) end
    ScrubRuntimeCaches(db.profile)

    -- Globals read by the options and custom-aura modules.
    _G._KUIAR_AceDB = db
    if _G.KUIAuraReminders_Custom and _G.KUIAuraReminders_Custom.Init then
        _G.KUIAuraReminders_Custom:Init(db)
    end
    _G._KUIAR_RequestRefresh = RequestRefresh
    _G._KUIAR_HideAllIcons = HideAllIcons
    _G._KUIAR_GLOW_VALUES = GLOW_VALUES
    _G._KUIAR_GLOW_ORDER = GLOW_ORDER
    _G._KUIAR_GLOW_TYPES = GLOW_TYPES
    _G._KUIAR_StartPixelGlow = StartPixelGlow
    _G._KUIAR_StartButtonGlow = StartButtonGlow
    _G._KUIAR_StartAutoCastShine = StartAutoCastShine
    _G._KUIAR_StartFlipBookGlow = StartFlipBookGlow
    _G._KUIAR_StopAllGlows = StopAllGlows
    _G._KUIAR_RegisterUnlock = RegisterUnlockElements
    _G._KUIAR_ApplyUnlockPos = ApplyUnlockPos
    _G._KUIAR_RAID_BUFFS = RAID_BUFFS
    _G._KUIAR_AURAS = AURAS
    _G._KUIAR_ROGUE_POISONS = ROGUE_POISONS
    _G._KUIAR_PALADIN_RITES = PALADIN_RITES
    _G._KUIAR_SHAMAN_IMBUES = SHAMAN_IMBUES
    _G._KUIAR_SHAMAN_SHIELDS = SHAMAN_SHIELDS
    _G._KUIAR_WEAPON_ENCHANT_ITEMS = WEAPON_ENCHANT_ITEMS
    _G._KUIAR_Tex = AR.GetSpellTextureCached
    _G._KUIAR_ICON_SIZE = ICON_SIZE
    _G._KUIAR_FLASK_ITEMS = FLASK_ITEMS
    _G._KUIAR_FOOD_ITEMS = FOOD_ITEMS
    _G._KUIAR_WEAPON_ENCHANT_CHOICES = WEAPON_ENCHANT_CHOICES
    _G._KUIAR_TALENT_REMINDER_ZONES = TALENT_REMINDER_ZONES

    local STRATA_VALUES = {
        BACKGROUND = "Background", LOW = "Low", MEDIUM = "Medium",
        HIGH = "High", DIALOG = "Dialog", FULLSCREEN = "Fullscreen",
        FULLSCREEN_DIALOG = "Fullscreen Dialog", TOOLTIP = "Tooltip",
    }
    local STRATA_ORDER = {
        "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG",
        "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP",
    }
    _G._KUIAR_STRATA_VALUES = STRATA_VALUES
    _G._KUIAR_STRATA_ORDER = STRATA_ORDER

    -- Create anchor
    iconAnchor = CreateFrame("Frame", "KUIAR_Anchor", UIParent)
    iconAnchor:SetSize(1, 1)
    iconAnchor:SetFrameStrata(AR.GetStrata())
    iconAnchor:EnableMouse(false)
    ApplyUnlockPos()

    -- Create combat anchor (non-secure, follows iconAnchor position)
    -- Parented to UIParent so Show/Hide is never blocked by combat lockdown.
    combatAnchor = CreateFrame("Frame", "KUIAR_CombatAnchor", UIParent)
    combatAnchor:SetSize(1, 1)
    combatAnchor:SetFrameStrata(AR.GetStrata())
    combatAnchor:SetFrameLevel(110)
    combatAnchor:EnableMouse(false)
    combatAnchor:SetAllPoints(iconAnchor)
    combatAnchor:Hide()

    -- Create cursor-attached anchor for important buffs.
    local cursorParent = UIParent
    cursorAnchor = CreateFrame("Frame", "KUIAR_CursorAnchor", cursorParent)
    cursorAnchor:SetSize(1, 1)
    cursorAnchor:SetFrameStrata("TOOLTIP")
    cursorAnchor:SetFrameLevel(9980)
    cursorAnchor:EnableMouse(false)
    cursorAnchor:SetPoint("CENTER", cursorParent, "CENTER", 0, 60)
    cursorAnchor:Hide()

    -- Create talent reminder anchor (offset below main anchor)
    talentIconAnchor = CreateFrame("Frame", "KUIAR_TalentAnchor", iconAnchor)
    talentIconAnchor:SetSize(1, 1)
    talentIconAnchor:SetFrameStrata(AR.GetStrata())
    talentIconAnchor:EnableMouse(false)
    talentIconAnchor:SetPoint("CENTER", iconAnchor, "CENTER", 0, db.profile.talentReminderYOffset or -50)
    talentIconAnchor:Hide()

    local function ApplyStrata()
        local strata = AR.GetStrata()
        iconAnchor:SetFrameStrata(strata)
        combatAnchor:SetFrameStrata(strata)
        talentIconAnchor:SetFrameStrata(strata)
        for _, btn in pairs(iconPool) do btn:SetFrameStrata(strata) end
        for _, btn in pairs(talentIconPool) do btn:SetFrameStrata(strata) end
        for _, f in pairs(combatIconPool) do f:SetFrameStrata(strata) end
    end
    _G._KUIAR_ApplyStrata = ApplyStrata

    if KT and KT.OpenMenu and not KT._kuiAuraRemindersMenuHook then
        KT._kuiAuraRemindersMenuHook = true
        hooksecurefunc(KT, "OpenMenu", function()
            C_Timer.After(0, function()
                if KT.MenuPrincipal and not KT.MenuPrincipal._kuiAuraRemindersHooked then
                    KT.MenuPrincipal._kuiAuraRemindersHooked = true
                    KT.MenuPrincipal:HookScript("OnHide", function()
                        optionsPanelVisible = false
                        BeaconLive.optionsVisible = false
                        RequestRefresh()
                        Beacons.Refresh()
                    end)
                end

                if KT.MenuPrincipal and KT.MenuPrincipal:IsShown() then
                    optionsPanelVisible = true
                    BeaconLive.optionsVisible = true
                    HideAllIcons()
                    Beacons.Refresh()
                else
                    optionsPanelVisible = false
                    BeaconLive.optionsVisible = false
                    RequestRefresh()
                    Beacons.Refresh()
                end
            end)
        end)
    end

    RequestRefresh()
    Beacons.Init()
    C_Timer.After(0.5, RegisterUnlockElements)
end

-- With /kuiarlog on, each player aura update during combat is summarised in
-- chat (full update flag and how many auras were added, changed, removed).
-- Only counts are printed: the aura contents may be secret in combat.
local function LogAuraUpdate(unit, updateInfo)
    if not (_kuiarLogEnabled and unit == "player" and InCombat()) then return end
    local ok, line = pcall(function()
        local function count(list) return type(list) == "table" and #list or 0 end
        local info = type(updateInfo) == "table" and updateInfo or {}
        return string.format("UNIT_AURA full=%s +%d ~%d -%d", tostring(info.isFullUpdate),
            count(info.addedAuras), count(info.updatedAuraInstanceIDs), count(info.removedAuraInstanceIDs))
    end)
    if ok then print("|cffff9900[KUIAR]|r " .. line) end
end

local function RefreshForPlayer(unit)
    if unit == "player" then RequestRefresh() end
end

local MAIN_EVENT_HANDLERS = {
    PLAYER_LOGIN = OnLogin,
    -- Combat starts: fade the secure icons at once and capture the aura
    -- state while it can still be read; the refresh then draws combat icons.
    PLAYER_REGEN_DISABLED = function()
        FadeOutSecureIcons()
        SnapshotPlayerAuras()
        SnapshotOwnOnRaidBuffs()
        RequestRefresh()
    end,
    -- Combat ends: drop the stand-in frames and rebuild the secure row.
    PLAYER_REGEN_ENABLED = function()
        AR.HideCombatIcons()
        AR.HideCursorIcons()
        RequestRefresh()
    end,
    -- A loading screen ends every middle-click dismissal.
    PLAYER_ENTERING_WORLD = function()
        wipe(_dismissedUntilLoad)
        RequestRefresh()
    end,
    UNIT_AURA = function(unit, updateInfo)
        LogAuraUpdate(unit, updateInfo)
        RefreshForPlayer(unit)
    end,
    UNIT_ENTERED_VEHICLE = RefreshForPlayer,
    UNIT_EXITED_VEHICLE = RefreshForPlayer,
}

mainFrame:SetScript("OnEvent", function(_, event, ...)
    local handler = MAIN_EVENT_HANDLERS[event]
    if handler then
        handler(...)
    else
        RequestRefresh()
    end
end)

-- Main frame events, grouped by what makes a reminder appear or vanish.
local MAIN_EVENTS = {
    -- session and combat
    "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    -- where the player is and with whom
    "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE",
    "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED", "CHALLENGE_MODE_RESET",
    -- spells and talents
    "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED",
    -- bags and weapons
    "BAG_UPDATE_DELAYED", "WEAPON_ENCHANT_CHANGED",
    -- mounting (skyriding hides everything)
    "PLAYER_MOUNT_DISPLAY_CHANGED",
}
local MAIN_PLAYER_EVENTS = {
    "PLAYER_SPECIALIZATION_CHANGED", "UNIT_AURA", "UNIT_INVENTORY_CHANGED",
    "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
}
for _, event in ipairs(MAIN_EVENTS) do mainFrame:RegisterEvent(event) end
for _, event in ipairs(MAIN_PLAYER_EVENTS) do mainFrame:RegisterUnitEvent(event, "player") end

-- Diagnostics. /kuiardebug walks every reminder category and prints why
-- each entry is or is not shown.
SLASH_KUIARDEBUG1 = "/kuiardebug"
SlashCmdList["KUIARDEBUG"] = function()

    local accentHex = string.format("%02x%02x%02x", (KT.C_R or 1) * 255, (KT.C_G or 0) * 255, (KT.C_B or 0.3333) * 255)
    local p = function(...) print("|cff" .. accentHex .. "[KUI AuraReminders Debug]|r", ...) end
    p(LText("--- Aura Reminders Debug ---"))

    if not db then p("|cffff4444" .. LText("db is nil: PLAYER_LOGIN never fired or AceDB failed") .. "|r"); return end

    local playerClass = AR.GetPlayerClass()
    local specID = AR.GetActiveSpecID()
    local specIdx = GetSpecialization()
    local specName = specIdx and select(2, GetSpecializationInfo(specIdx)) or "?"
    AR.CacheInstanceInfo()
    local inInstance = AR.InRealInstancedContent()
    local inKeystone = AR.IsMythicPlusActive()
    local inCombat = InCombat()
    local inGroup = IsInGroup()
    local inRaid = IsInRaid()

    p(LText("Class:"), playerClass, "| " .. LText("Spec:"), specID, "(" .. specName .. ")")
    p("InInstance:", tostring(inInstance), "| InKeystone:", tostring(inKeystone), "| InCombat:", tostring(inCombat))
    p("InGroup:", tostring(inGroup), "| InRaid:", tostring(inRaid))
    p(LText("Options panel visible:"), tostring(optionsPanelVisible))
    p("iconAnchor:", iconAnchor and LText("exists") or "|cffff4444NIL|r",
      iconAnchor and ("shown=" .. tostring(iconAnchor:IsShown())) or "")
    p(LText("Active icons:"), #activeIcons)
    p(LText("Combat icons:"), #combatActiveIcons)

    -- Raid Buffs
    local rb = db.profile.raidBuffs
    p(LText("--- Raid Buffs ---"))
    p("  showNonInstanced:", tostring(rb.showNonInstanced), "| showOthersMissing:", tostring(rb.showOthersMissing))
    local rbActive = inInstance or rb.showNonInstanced
    p("  " .. LText("Category active (inInstance or showNonInstanced):"), tostring(rbActive))
    if rbActive then
        for _, buff in ipairs(RAID_BUFFS) do
            local enabled = rb.enabled[buff.key]
            local classMatch = buff.class == playerClass
            local known = Known(buff.castSpell)
            local status = ""
            if not enabled then status = LText("DISABLED")
            elseif not classMatch then status = string.format(LText("wrong class (%s)"), buff.class)
            elseif not known then status = LText("spell not known")
            else
                local isMissing = RaidBuffLacking(buff, rb)
                status = isMissing and ("|cffff4444" .. LText("MISSING") .. "|r") or LText("buff present")
            end
            p("  " .. buff.key .. " (" .. buff.name .. "): " .. status)
        end
    end

    -- Auras
    local au = db.profile.auras
    p(LText("--- Auras ---"))
    p("  showNonInstanced:", tostring(au.showNonInstanced))
    local auActive = inInstance or au.showNonInstanced
    p("  " .. LText("Category active:"), tostring(auActive))
    if auActive then
        for _, aura in ipairs(AURAS) do
            local enabled = au.enabled[aura.key]
            local classMatch = aura.class == playerClass
            local known = Known(aura.castSpell)
            local specOk = SpecAllows(aura, specID)
            local status = ""
            if not enabled then status = LText("DISABLED")
            elseif not classMatch then status = string.format(LText("wrong class (%s)"), aura.class)
            elseif not known then status = LText("spell not known")
            elseif not specOk then status = LText("wrong spec")
            elseif aura.requireInstanceGroup and (not inInstance or not (inGroup or inRaid)) then status = LText("skipped (requireInstanceGroup: not in instance+group)")
            elseif inCombat and not aura.combatOk then status = LText("skipped (in combat, not combatOk)")
            else
                local allyBuff = aura.check == "mineOnRaid" or aura.check == "ownOnRaid"
                if aura.standalone then
                    status = "standalone (/beacondebug)"  -- beacons are not aura-scanned
                elseif aura.check == "mineOnRaid" and inCombat then
                    status = LText("skipped (in combat, mineOnRaid can't check others)")
                elseif allyBuff and not (inGroup or inRaid) then
                    status = LText("not in group")
                elseif aura.check == "ownOnRaid" and inCombat then
                    local cached = _preCombatOwnOnRaidCache[aura.buffIDs[1]]
                    status = string.format(LText("ownOnRaid (combat snapshot: %s)"), tostring(cached))
                end
                if status == "" then
                    -- Same test the reminder engine applies.
                    local isMissing = AuraIsMissing(aura, inInstance, inCombat)
                    status = isMissing and ("|cffff4444" .. LText("MISSING: should show icon") .. "|r") or LText("buff present")
                end
            end
            p("  " .. aura.key .. " (" .. aura.name .. "): " .. status)
        end
    end

    -- Consumables
    local co = db.profile.consumables
    p(LText("--- Consumables ---"))
    p("  inKeystone:", tostring(inKeystone), "| inInstance:", tostring(inInstance))
    p("  showSpecialsNonInstanced:", tostring(co.showSpecialsNonInstanced))
    local specialsActive = inInstance or co.showSpecialsNonInstanced
    local coActive = not inKeystone
    p("  " .. LText("Category active (not inKeystone):"), tostring(coActive), "| " .. LText("Specials active:"), tostring(specialsActive))
    if coActive and not inCombat then
        if playerClass == "ROGUE" then
            for _, poison in ipairs(ROGUE_POISONS) do
                local enabled = co.enabled[poison.key]
                local known = Known(poison.castSpell)
                local has = PoisonApplied(poison)
                p("  " .. poison.key .. ": enabled=" .. tostring(enabled) .. " known=" .. tostring(known) .. " hasBuff=" .. tostring(has))
            end
        end
        if playerClass == "SHAMAN" then
            for _, imbue in ipairs(SHAMAN_IMBUES) do
                p("  " .. imbue.key .. ": enabled=" .. tostring(co.enabled[imbue.key]) .. " known=" .. tostring(Known(imbue.castSpell)))
            end
        end
        p("  augment_rune enabled:", tostring(co.enabled.augment_rune), "| inM0/MythicRaid:", tostring(AR.IsMythicZeroOrMythicRaid()))
        p("  weapon_enchant enabled:", tostring(co.enabled.weapon_enchant))
        local hasMH = AR.GetTemporaryWeaponEnchants()
        p("  " .. LText("Main-hand enchant present:"), tostring(hasMH))
    elseif inCombat then
        p("  " .. LText("(skipped in combat)"))
    end

    p(LText("--- End Debug ---"))
end

-- /kuiarcombat probes the aura API for a few key spells (secrecy, raw
-- lookup, snapshot); it is meant to be typed during combat.
SLASH_KUIARCOMBAT1 = "/kuiarcombat"
SlashCmdList["KUIARCOMBAT"] = function()
    local p = function(...) print("|cffff9900[KUIAR Combat]|r", ...) end
    p(LText("--- Combat Aura Debug ---"))
    p("InCombatLockdown:", tostring(InCombatLockdown()))
    p("issecretvalue global:", type(issecretvalue))

    -- Test specific whitelisted spell IDs
    local testIDs = {465, 1126, 1459, 6673, 21562, 462854, 474754, 369459}
    local testNames = {
        [465]="Devotion Aura", [1126]="Mark of the Wild", [1459]="Arcane Intellect", [6673]="Battle Shout",
        [21562]="Fortitude", [462854]="Skyfury", [474754]="Symbiotic", [369459]="Source of Magic",
    }

    for _, id in ipairs(testIDs) do
        local name = testNames[id] or tostring(id)

        -- 1) Secrecy level
        local secrecyStr = "API_MISSING"
        if C_Secrets and C_Secrets.GetSpellAuraSecrecy then
            local secOk, sec = pcall(C_Secrets.GetSpellAuraSecrecy, id)
            if secOk then
                if sec == 0 then secrecyStr = "NeverSecret"
                elseif sec == 1 then secrecyStr = "AlwaysSecret"
                elseif sec == 2 then secrecyStr = "ContextuallySecret"
                else secrecyStr = tostring(sec) end
            else
                secrecyStr = "ERROR:" .. tostring(sec)
            end
        end

        -- 2) ShouldSpellAuraBeSecret
        local shouldBeSecret = "API_MISSING"
        if C_Secrets and C_Secrets.ShouldSpellAuraBeSecret then
            local sbsOk, sbsVal = pcall(C_Secrets.ShouldSpellAuraBeSecret, id)
            shouldBeSecret = sbsOk and tostring(sbsVal) or ("ERROR:" .. tostring(sbsVal))
        end

        -- 3) Raw API call
        local resultStr = "?"
        local resultType = "?"
        local isSecret = "?"
        local ok, result = pcall(C_UnitAuras.GetPlayerAuraBySpellID, id)
        if not ok then
            resultStr = "|cffff4444PCALL_ERROR: " .. tostring(result) .. "|r"
        else
            resultType = type(result)
            local isvOk, isvResult = pcall(issecretvalue, result)
            if not isvOk then
                isSecret = "ERROR:" .. tostring(isvResult)
            else
                isSecret = tostring(isvResult)
            end
            if result == nil then
                resultStr = "nil"
            elseif isvOk and isvResult then
                resultStr = "|cff00ff00SECRET (aura EXISTS)|r"
            elseif result then
                local fieldOk, fieldVal = pcall(function() return result.spellId end)
                if fieldOk then
                    resultStr = "|cff00ff00TABLE spellId=" .. tostring(fieldVal) .. "|r"
                else
                    resultStr = "|cff00ff00TABLE (field err)|r"
                end
            end
        end

        -- 4) Our wrapper
        local wrapperOk, wrapperResult = pcall(PlayerHasAuraByID, {id})
        local wrapperStr
        if not wrapperOk then
            wrapperStr = "|cffff4444ERROR: " .. tostring(wrapperResult) .. "|r"
        else
            wrapperStr = tostring(wrapperResult)
        end

        -- 5) Snapshot value
        local cached = _preCombatAuraCache[id]

        p(name .. " (" .. id .. "):")
        p("  Secrecy=" .. secrecyStr .. " ShouldBeSecret=" .. shouldBeSecret)
        p("  API: type=" .. resultType .. " isSecret=" .. isSecret .. " => " .. resultStr)
        p("  Snapshot=" .. tostring(cached) .. " | PlayerHasAuraByID=" .. wrapperStr)
    end

    p(LText("--- Icon counts ---"))
    p("  activeIcons:", #activeIcons, "combatActiveIcons:", #combatActiveIcons)
    p("  NON_SECRET_SPELL_IDS[465]:", tostring(NON_SECRET_SPELL_IDS[465]))

    p(LText("--- End Combat Debug ---"))
end

-- /kuiarlog switches the combat aura update log (see LogAuraUpdate).
SLASH_KUIARLOG1 = "/kuiarlog"
SlashCmdList["KUIARLOG"] = function()
    _kuiarLogEnabled = not _kuiarLogEnabled
    print("|cffff9900[KUIAR]|r " .. string.format(LText("Combat aura logging %s"), _kuiarLogEnabled and ("|cff00ff00" .. LText("ON") .. "|r") or ("|cffff4444" .. LText("OFF") .. "|r")))
end

-- /beacondebug prints the beacon subsystem's state.
SLASH_BEACONDEBUG1 = "/beacondebug"
SlashCmdList["BEACONDEBUG"] = function()
    local p = function(...) print("|cffffcc00[Beacon Debug]|r", ...) end
    local state = Beacons.State
    p(LText("--- Beacon Reminder Debug ---"))
    p("isPaladin:", tostring(state.isPaladin))
    p("db:", db and LText("exists") or "|cffff4444NIL|r")
    p("IsSpellOverlayed:", state.isSpellOverlayed and LText("exists") or "|cffff4444NIL|r")
    p("cachedInInstance:", tostring(state.inInstance))
    p("overlayEventsRegistered:", tostring(state.overlayRegistered))
    p("beaconAnchor:", state.anchor and LText("exists") or "|cffff4444NIL|r")
    p("InGroup:", tostring(IsInGroup()), "InRaid:", tostring(IsInRaid()))
    p("InCombat:", tostring(InCombatLockdown()))

    local _, iType, diffID = GetInstanceInfo()
    p("InstanceType:", tostring(iType), "DifficultyID:", tostring(diffID))

    local au = db and db.profile.auras
    local enabled = au and au.enabled
    p("auras.enabled.bol:", tostring(enabled and enabled.bol))
    p("auras.enabled.bof:", tostring(enabled and enabled.bof))

    p("Known(BOL 53563):", tostring(Known(Beacons.BOL)))
    p("Known(BOF 156910):", tostring(Known(Beacons.BOF)))
    p("Known(Virtue 200025):", tostring(Known(Beacons.VIRTUE)))

    if state.isSpellOverlayed then
        local bolOverlay = state.isSpellOverlayed(Beacons.BOL)
        local bofOverlay = state.isSpellOverlayed(Beacons.BOF)
        p("IsSpellOverlayed(BOL):", tostring(bolOverlay))
        p("IsSpellOverlayed(BOF):", tostring(bofOverlay))
    else
        p("|cffff4444" .. LText("IsSpellOverlayed function not available") .. "|r")
    end

    p("iconState[BOL]:", tostring(state.iconState[Beacons.BOL]))
    p("iconState[BOF]:", tostring(state.iconState[Beacons.BOF]))
    p(LText("icon frames:") .. " BOL=", state.icons[Beacons.BOL] and LText("exists") or "NIL",
      "BOF=", state.icons[Beacons.BOF] and LText("exists") or "NIL")

    p(LText("--- End Beacon Debug ---"))
end
