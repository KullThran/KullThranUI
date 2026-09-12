-------------------------------------------------------------------------------
-- Aura reminder runtime for raid buffs, consumables, talents and secure icons.
-- Keeps combat-safe buttons separate from the live tracking state.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local KT = (ns and ns.KT) or (_G and (_G.KT or _G.KullThranUI)) or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
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

    local texture = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)) or GetSpellTexture(spellID)
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

-------------------------------------------------------------------------------
--  Font resolution (uses global font system)
-------------------------------------------------------------------------------
function AR.ResolveFontPath()
    return KT.FONT_PATH or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
end
function AR.GetABROutline()
    return "OUTLINE"
end
function AR.SetABRFont(fs, font, size)
    if not (fs and fs.SetFont) then return end
    local f = AR.GetABROutline()
    fs:SetFont(font, size, f)
    if f == "" then fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1)
    else fs:SetShadowOffset(0, 0) end
end

-------------------------------------------------------------------------------
-- Short label used on compact reminder icons.
-------------------------------------------------------------------------------
local LABEL_OVERRIDES = {
    ["Defensive Stance"]        = "Stance",
    ["Berserker Stance"]        = "Stance",
    ["Devotion Aura"]           = "Aura",
    ["Power Word: Fortitude"]   = "Fortitude",
    ["Arcane Intellect"]        = "Intellect",
    ["Battle Shout"]            = "Shout",
}
local LABEL_CLASS_OVERRIDES = {
    ROGUE  = "Poison",
    SHAMAN_IMBUE  = "Weapon",
    SHAMAN_SHIELD = "Shield",
}
function AR.GetReminderShortLabel(name, classOverride)
    local classLabel = classOverride and LABEL_CLASS_OVERRIDES[classOverride]
    if classLabel then
        return classLabel
    end

    local overrideLabel = LABEL_OVERRIDES[name]
    if overrideLabel then
        return overrideLabel
    end

    local firstWord = type(name) == "string" and name:match("^(%S+)")
    return firstWord or name
end

-------------------------------------------------------------------------------
--  Instance / Difficulty helpers
--  Cached per-frame: call AR.CacheInstanceInfo() at the start of Refresh()
-------------------------------------------------------------------------------
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

-- Retail 12.1 moved temporary weapon enchant data to C_PaperDollInfo. Preserve
-- the legacy tuple shape for callers and retain compatibility with older clients.
function AR.GetTemporaryWeaponEnchants()
    if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
        local mh = C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_MAINHAND)
        local oh = C_PaperDollInfo.GetTemporaryEnchantmentInfo(INVSLOT_OFFHAND)
        return mh ~= nil, mh and mh.remainingTimeMs, mh and mh.chargesRemaining, mh and mh.enchantID,
               oh ~= nil, oh and oh.remainingTimeMs, oh and oh.chargesRemaining, oh and oh.enchantID
    end
    return GetWeaponEnchantInfo()
end

function AR.IsMythicZeroOrMythicRaid()
    if _cachedIType == "party" then
        return PARTY_MYTHIC_DIFFICULTIES[_cachedDiffID] == true
    end

    return _cachedIType == "raid" and _cachedDiffID == 16
end

-- Tabla de dificultades heroicas/míticas por tipo de instancia
local HEROIC_MYTHIC_DIFF_TABLES = {
    party = PARTY_HEROIC_OR_HIGHER_DIFFICULTIES,
    raid  = RAID_HEROIC_OR_HIGHER_DIFFICULTIES,
}

function AR.IsHeroicOrMythicInstance()
    local diffMap = HEROIC_MYTHIC_DIFF_TABLES[_cachedIType]
    return diffMap ~= nil and diffMap[_cachedDiffID] == true
end

-------------------------------------------------------------------------------
--  Midnight Season 2 Dungeon & Raid Instance Names
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
--  Talent query helpers
-------------------------------------------------------------------------------
function AR.GetCurrentInstanceName()
    local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
    return name, tonumber(instanceID)
end

-------------------------------------------------------------------------------
--  Aura query helpers (secret-value safe)
--  Uses C_UnitAuras.GetPlayerAuraBySpellID for player checks takes a known
--  (non-secret) spell ID and returns nil or an AuraData table.  The table
--  reference itself is never secret, only its fields, so "if result then" is
--  safe even in combat.
--
--  NON_SECRET_SPELL_IDS: Blizzard-whitelisted spell IDs whose aura data
--  remains non-secret even during combat lockdown (Patch 12.0).
-------------------------------------------------------------------------------
local NON_SECRET_SPELL_IDS = {
    -- Preservation Evoker
    [355941]=true, [363502]=true, [364343]=true, [366155]=true,
    [367364]=true, [373267]=true, [376788]=true,
    -- Augmentation Evoker
    [360827]=true, [395152]=true, [410089]=true, [410263]=true,
    [410686]=true, [413984]=true,
    -- Resto Druid
    [774]=true, [8936]=true, [33763]=true, [48438]=true, [155777]=true,
    -- Disc Priest
    [17]=true, [194384]=true, [1253593]=true,
    -- Holy Priest
    [139]=true, [41635]=true, [77489]=true,
    -- Mistweaver Monk
    [115175]=true, [119611]=true, [124682]=true, [450769]=true,
    -- Restoration Shaman
    [974]=true, [383648]=true, [61295]=true,
    -- Holy Paladin
    [53563]=true, [156322]=true, [156910]=true, [1244893]=true,
    -- Long-term Raid Buffs
    [1126]=true, [1459]=true, [6673]=true, [21562]=true, [369459]=true,
    [462854]=true, [474754]=true,
    -- Alternate buff IDs (talent variants that provide the same effect)
    [432661]=true, [432778]=true,
    -- Paladin Auras Devotion Aura (465) is still ContextuallySecret as of
    -- Midnight 12.0; removed from whitelist so the reminder hides in combat.
    -- Blessing of the Bronze Auras
    [381732]=true, [381741]=true, [381746]=true, [381748]=true,
    [381749]=true, [381750]=true, [381751]=true, [381752]=true,
    [381753]=true, [381754]=true, [381756]=true, [381757]=true,
    [381758]=true,
    -- Long-term Self Buffs (Paladin Rites)
    [433568]=true, [433583]=true,
    -- Rogue Poisons
    [2823]=true, [8679]=true, [3408]=true, [5761]=true,
    [315584]=true, [381637]=true, [381664]=true,
    -- Shaman Imbuements
    [319773]=true, [319778]=true, [382021]=true, [382022]=true,
    [457496]=true, [457481]=true, [462757]=true, [462742]=true,
    -- Resource-like Auras
    [205473]=true, [260286]=true,
    -- Cooldowns
    [8690]=true, [20608]=true,
}

-------------------------------------------------------------------------------
--  Pre-combat aura snapshot
--  Snapshots player aura state before entering combat so we have a reliable
--  fallback for any whitelisted spell whose live API returns nil in combat.
-------------------------------------------------------------------------------
local _preCombatAuraCache = {}  -- [spellID] = true/false, snapshotted at REGEN_DISABLED
local _kuiarLogEnabled = false   -- toggled by /kuiarlog

local function _isRuntimeNonSecret(id)
    local secretAPI = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
    if not secretAPI then
        return true
    end

    local isSecret = secretAPI(id)
    return not isSecret
end

local function SnapshotPlayerAuras()
    wipe(_preCombatAuraCache)
    -- Snapshot every whitelisted spell ID before entering combat.
    -- GetPlayerAuraBySpellID returns nil for everything during combat,
    -- and UNIT_AURA payload spell IDs are all secret values in combat,
    -- so this snapshot is the ONLY reliable source of aura state.
    for id in pairs(NON_SECRET_SPELL_IDS) do
        local result = C_UnitAuras.GetPlayerAuraBySpellID(id)
        _preCombatAuraCache[id] = (result ~= nil)
    end
end

-- Pre-combat snapshot for "ownOnRaid" buffs (Source of Magic, etc.)
-- These are buffs the player casts on OTHER group members. sourceUnit is
-- unreadable in combat, so we snapshot the result of the full group scan
-- before entering combat.
local _preCombatOwnOnRaidCache = {}  -- [spellID] = true/false
local SnapshotOwnOnRaidBuffs  -- forward declaration; defined after _unitHasBuffFromPlayer

-- Pre-allocated scratch tables for hot per-Refresh functions (avoids GC churn)
local _idLookupScratch  = {}
local _lookupScratch    = {}

-- Patch 12.1: index/slot aura enumeration can raise a taint error whenever the
-- aura collection is secret, including some nominally out-of-combat states.
-- Direct spell lookup is the supported readable path.
local function GetHelpfulAuraBySpellID(unit, spellID)
    if not (unit and spellID and C_UnitAuras) then return nil, false end
    local fn
    if unit == "player" then
        fn = C_UnitAuras.GetPlayerAuraBySpellID
    else
        fn = C_UnitAuras.GetUnitAuraBySpellID
    end
    if fn then
        local ok, aura
        if unit == "player" then ok, aura = pcall(fn, spellID)
        else ok, aura = pcall(fn, unit, spellID) end
        if ok then return aura, true end
    end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
    if not issecretvalue(name) and name and C_UnitAuras.GetAuraDataBySpellName then
        local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, name, "HELPFUL")
        if ok then return aura, true end
    end
    return nil, false
end

local function GetHelpfulAuraByName(unit, auraName)
    if not (auraName and C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName) then return nil, false end
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, auraName, "HELPFUL")
    if ok then return aura, true end
    return nil, false
end

local function PlayerHasAuraByID(spellIDs)
    if not spellIDs or not spellIDs[1] then return true end
    local inCombat = InCombat()
    for j = 1, #spellIDs do
        local id = spellIDs[j]
        local aura, readable = GetHelpfulAuraBySpellID("player", id)
        if readable and aura ~= nil then return true end
        if (not readable or inCombat) and _preCombatAuraCache[id] then return true end
    end
    return false
end

-- Shared helpers for group aura scanning (hoisted to avoid per-call closure allocation)
local function _unitOk(u) return UnitExists(u) and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) end
local function _unitHasBuff(u, spellIDs)
    local inCombat = InCombat()
    for j = 1, #spellIDs do
        local id = spellIDs[j]
        local aura, readable = GetHelpfulAuraBySpellID(u, id)
        if readable and aura ~= nil then return true end
        if u == "player" and (not readable or inCombat) and _preCombatAuraCache[id] then return true end
    end
    return false
end

-- Like _unitHasBuff but only returns true if the buff's source is the player.
-- Used for Source of Magic, Earth Shield (orbit) we need to verify it's OUR
-- buff, not another caster's.
-- Works in combat for non-secret spell IDs via GetUnitAuraBySpellID (direct
-- lookup only; index enumeration is forbidden for secret aura collections.
local function _unitHasBuffFromPlayer(u, spellIDs)
    local inCombat = InCombat()
    local idLookup = _idLookupScratch
    wipe(idLookup)
    for j = 1, #spellIDs do idLookup[spellIDs[j]] = true end

    -- Direct lookup by spell is the only supported 12.1 path here.
    for id in pairs(idLookup) do
        local aura, ok = GetHelpfulAuraBySpellID(u, id)
        if ok and issecretvalue(aura) then
            -- Exact spell lookup confirmed presence but hid ownership. Avoid a
            -- false missing-buff reminder when source attribution is forbidden.
            return true
        end
        if ok and aura ~= nil then
                -- Check isFromPlayerOrPlayerPet first (simple boolean, always
                -- present).  Fall back to sourceUnit if available.
                local fromMe = aura.isFromPlayerOrPlayerPet
                if not issecretvalue(fromMe) and fromMe == true then
                    return true
                end
                local src = aura.sourceUnit
                if not issecretvalue(src) and src and UnitIsUnit(src, "player") then
                    return true
                end
                -- Direct lookup found the aura but couldn't verify source.
                -- OOC: can't disprove ownership, so assume it's ours.
                -- In combat we fall through to the snapshot path instead.
                if not inCombat then
                    return true
                end
        end
    end
    return false
end

-- Assign the SnapshotOwnOnRaidBuffs function (forward-declared earlier,
-- now that _unitHasBuffFromPlayer is defined).
SnapshotOwnOnRaidBuffs = function()
    wipe(_preCombatOwnOnRaidCache)
    local ownOnRaidIDs = { 369459 }
    for _, id in ipairs(ownOnRaidIDs) do
        local found = false
        if _unitHasBuffFromPlayer("player", {id}) then found = true end
        if not found then
            if IsInRaid() then
                for i = 1, GetNumGroupMembers() do
                    if _unitHasBuffFromPlayer("raid"..i, {id}) then found = true; break end
                end
            elseif IsInGroup() then
                for i = 1, GetNumSubgroupMembers() do
                    if _unitHasBuffFromPlayer("party"..i, {id}) then found = true; break end
                end
            end
        end
        _preCombatOwnOnRaidCache[id] = found
    end
end

-- Like PlayerHasAuraByID but only returns true if the buff's source is the
-- player themselves.  Used for Devotion Aura Holy Paladins need their OWN
-- aura active for Aura Mastery, and Lightsmith Prot Paladins need their own
-- aura for amplification.  Another paladin's Devotion Aura on the player
-- does NOT satisfy this check.
-- IMPORTANT: This only works out of combat (aura iteration).  The caller
-- must ensure combatOk=false on the aura entry so this is never called
-- during combat where aura data is secret/restricted.
local function PlayerHasSelfCastAuraByID(spellIDs)
    if not spellIDs or not spellIDs[1] then return true end
    if InCombat() then return false end  -- safety: can't read sourceUnit in combat
    for j = 1, #spellIDs do
        local aura, readable = GetHelpfulAuraBySpellID("player", spellIDs[j])
        if readable and issecretvalue(aura) then return true end
        if readable and aura ~= nil then
            local src = aura.sourceUnit
            if not issecretvalue(src) and src and UnitIsUnit(src, "player") then
                return true
            end
            if issecretvalue(src) then return true end
        end
    end
    return false
end

-- Check if ANY group/raid member is missing a buff (for "show if others missing")
local function AnyGroupMemberMissingBuff(spellIDs)
    if not IsInGroup() then return not _unitHasBuff("player", spellIDs) end
    if _unitOk("player") and not _unitHasBuff("player", spellIDs) then return true end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local u = "raid"..i
            if _unitOk(u) and UnitIsPlayer(u) and not UnitIsUnit(u, "player") and not _unitHasBuff(u, spellIDs) then return true end
        end
    else
        for i = 1, GetNumSubgroupMembers() do
            local u = "party"..i
            if _unitOk(u) and UnitIsPlayer(u) and not _unitHasBuff(u, spellIDs) then return true end
        end
    end
    return false
end

-- Check if the buff exists on ANY group/raid member (any source).
-- Used for Symbiotic Relationship just needs to exist on someone.
local function BuffExistsOnAnyGroupMember(spellIDs)
    if _unitHasBuff("player", spellIDs) then
        return true
    end

    local prefix, total
    if IsInRaid() then
        prefix = "raid"
        total = GetNumGroupMembers()
    elseif IsInGroup() then
        prefix = "party"
        total = GetNumSubgroupMembers()
    else
        return false
    end

    for index = 1, total do
        if _unitHasBuff(prefix .. index, spellIDs) then
            return true
        end
    end

    return false
end

-- Check if the PLAYER'S buff exists on ANY group/raid member (source must be player).
-- Returns true if at least one member has the buff cast by the player.
-- Used for Source of Magic, Earth Shield (orbit other).
local function PlayerOwnBuffOnAnyGroupMember(spellIDs)
    if _unitHasBuffFromPlayer("player", spellIDs) then return true end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if _unitHasBuffFromPlayer("raid"..i, spellIDs) then return true end
        end
    elseif IsInGroup() then
        for i = 1, GetNumSubgroupMembers() do
            if _unitHasBuffFromPlayer("party"..i, spellIDs) then return true end
        end
    end
    return false
end

-------------------------------------------------------------------------------
--  Weapon type classification (for weapon enchant matching)
-------------------------------------------------------------------------------
local WEAPON_CLASS_ID = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2
local W = (Enum and Enum.ItemWeaponSubclass) or {}

local function setFrom(...)
    local t = {}
    for i = 1, select("#", ...) do local v = select(i, ...); if v ~= nil then t[v] = true end end
    return t
end

-- Mapa unificado subClassID → categoría (en lugar de 3 sets separados)
local WEAPON_CATEGORY_MAP = {}
for _, id in ipairs({W.Axe1H, W.Axe2H, W.Sword1H, W.Sword2H, W.Dagger, W.Polearm, W.Warglaive}) do WEAPON_CATEGORY_MAP[id] = "BLADED" end
for _, id in ipairs({W.Mace1H, W.Mace2H, W.Staff, W.Fist}) do WEAPON_CATEGORY_MAP[id] = "BLUNT" end
for _, id in ipairs({W.Bow, W.Gun, W.Crossbow, W.Wand}) do WEAPON_CATEGORY_MAP[id] = "RANGED" end

local OFFHAND_EQUIPLOCS = { INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

function AR.GetWeaponCategory(slotID)
    local itemID = GetInventoryItemID("player", slotID)
    if not itemID then return nil end
    local infoFn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local _, _, _, equipLoc, _, classID, subClassID = infoFn(itemID)
    if classID ~= WEAPON_CLASS_ID then return nil end
    if OFFHAND_EQUIPLOCS[equipLoc] then return nil end
    return WEAPON_CATEGORY_MAP[subClassID] or "NEUTRAL"
end


-------------------------------------------------------------------------------
--  SPELL DATA Raid Buffs (all non-secret in 12.0, work in combat)
-------------------------------------------------------------------------------
local RAID_BUFFS = {
    { key="motw",   class="DRUID",   name="Mark of the Wild",       castSpell=1126,   buffIDs={1126,432661},    check="raid" },
    { key="bshout", class="WARRIOR", name="Battle Shout",           castSpell=6673,   buffIDs={6673},    check="raid" },
    { key="fort",   class="PRIEST",  name="Power Word: Fortitude",  castSpell=21562,  buffIDs={21562},   check="raid" },
    { key="ai",     class="MAGE",    name="Arcane Intellect",       castSpell=1459,   buffIDs={1459,432778},    check="raid" },
    { key="bronze", class="EVOKER",  name="Blessing of the Bronze", castSpell=364342,
      buffIDs={381732,381741,381746,381748,381749,381750,381751,381752,381753,381754,381756,381757,381758},
      check="raid" },
    { key="sky",    class="SHAMAN",  name="Skyfury",                castSpell=462854, buffIDs={462854},  check="raid" },
}

-------------------------------------------------------------------------------
--  SPELL DATA Auras (some non-secret, some still OOC-only)
-------------------------------------------------------------------------------
local AURAS = {
    -- Symbiotic Relationship: non-secret (474754) player-only check
    -- (applies to both player and target; if player has it, target does too)
    { key="symbiotic",  class="DRUID",   name="Symbiotic Relationship", castSpell=474750, buffIDs={474754},
      check="player", combatOk=true, requireInstanceGroup=true },
    -- Warrior stances: NOT on non-secret list, OOC only
    { key="battle_stance", class="WARRIOR", name="Battle Stance", castSpell=386164, buffIDs={386164},
      check="player", specs={71}, combatOk=false, isStance=true },
    { key="berserk_stance", class="WARRIOR", name="Berserker Stance", castSpell=386196, buffIDs={386196},
      check="player", specs={72}, combatOk=false, isStance=true },
    { key="def_stance",  class="WARRIOR", name="Defensive Stance",  castSpell=386208, buffIDs={386208},
      check="player", specs={73}, combatOk=false, isStance=true },
    -- Shadowform: NOT on non-secret list, OOC only
    -- Void Form (194249) replaces Shadowform visually while in Void Form,
    -- so either buff satisfies the "in Shadowform" requirement.
    { key="shadowform", class="PRIEST",  name="Shadowform",        castSpell=232698, buffIDs={232698, 194249},
      check="player", specs={258}, combatOk=false },
    -- Devotion Aura: simple player buff check, OOC only
    { key="devo_aura",  class="PALADIN", name="Devotion Aura", castSpell=465,
      buffIDs={465,32223,317920}, instanceBuffIDs={465}, check="player", combatOk=false, noPvP=true },
    -- Beacon of Light: standalone IsSpellOverlayed system (not checked by CollectAuras)
    { key="bol",        class="PALADIN", name="Beacon of Light",   castSpell=53563,  buffIDs={53563},
      standalone=true, notIfKnown=200025 },
    -- Beacon of Faith: standalone IsSpellOverlayed system (not checked by CollectAuras)
    { key="bof",        class="PALADIN", name="Beacon of Faith",   castSpell=156910, buffIDs={156910},
      standalone=true },
    -- Source of Magic: non-secret (369459) applied to a specific healer,
    -- not the caster; check if player's cast exists on any group member.
    { key="som",        class="EVOKER",  name="Source of Magic",   castSpell=369459, buffIDs={369459},
      check="ownOnRaid", combatOk=true, requireInstanceGroup=true },
    { key="blistering_scales", class="EVOKER", name="Blistering Scales", castSpell=360827,
      buffIDs={360827}, check="ownOnRaid", combatOk=true, requireInstanceGroup=true },
    { key="bestow_weyrnstone", class="EVOKER", name="Bestow Weyrnstone", castSpell=408233,
      buffIDs={410318}, check="ownOnRaid", combatOk=false, specs={1473}, requireInstanceGroup=true },
    { key="timelessness", class="EVOKER", name="Timelessness", castSpell=412710,
      buffIDs={412710}, check="ownOnRaid", combatOk=false, specs={1473}, requireInstanceGroup=true },
}

-------------------------------------------------------------------------------
--  SPELL DATA Consumables (OOC only, not during keystones)
-------------------------------------------------------------------------------
-- Rogue Poisons (all non-secret in 12.0 but we treat as consumable = OOC check)
local ROGUE_POISONS = {
    { key="deadly",     name="Deadly Poison",     castSpell=2823,   cat="lethal" },
    { key="amplifying", name="Amplifying Poison", castSpell=381664, cat="lethal" },
    { key="instant",    name="Instant Poison",    castSpell=315584, cat="lethal" },
    { key="wound",      name="Wound Poison",      castSpell=8679,   cat="lethal" },
    { key="numbing",    name="Numbing Poison",    castSpell=5761,   cat="nonlethal" },
    { key="atrophic",   name="Atrophic Poison",   castSpell=381637, cat="nonlethal" },
    { key="crippling",  name="Crippling Poison",  castSpell=3408,   cat="nonlethal" },
}
local DRAGON_TEMPERED_BLADES = 381801

-- Paladin Rites (non-secret in 12.0)
local PALADIN_RITES = {
    { key="rite_adj",  name="Rite of Adjuration",     castSpell=433583, buffIDs={433583}, wepEnchID={7144} },
    { key="rite_sanc", name="Rite of Sanctification",  castSpell=433568, buffIDs={433568}, wepEnchID={7143} },
}

-- Shaman Imbues (non-secret in 12.0)
local SHAMAN_IMBUES = {
    { key="flametongue", name="Flametongue Weapon", castSpell=318038, buffIDs={319778}, wepEnchID={5400} },
    { key="windfury",    name="Windfury Weapon",    castSpell=33757,  buffIDs={319773},  wepEnchID={5401} },
    { key="earthliving", name="Earthliving Weapon", castSpell=382021, buffIDs={382021, 382022}, wepEnchID={6498} },
    { key="tidecaller",  name="Tidecaller's Guard", castSpell=457496, buffIDs={457496, 457481}, wepEnchID={7528} },
    { key="tstrike",     name="Thunderstrike Ward", castSpell=462757, buffIDs={462757, 462742}, wepEnchID={7587} },
}

-- Shaman Shields (elemental orbit support)
local SHAMAN_SHIELDS = {
    { key="ls", name="Lightning Shield", castSpell=192106, buffIDs={192106}, specs={262} },
    { key="ws", name="Water Shield",     castSpell=52127,  buffIDs={52127},  specs={264} },
    { key="es", name="Earth Shield",     castSpell=974,    buffIDs={974}, specs={264},
      orbitTalent=383010, selfOrbitBuff={383648}, otherBuff={974} },
}

-- Weapon Enchant Items (temporary weapon enchants applied from items)
-- weaponType: BLADED, BLUNT, RANGED, NEUTRAL (NEUTRAL fits any weapon)
local WEAPON_ENCHANT_ITEMS = {
    -- Midnight
    {itemID=237367, name="Refulgent Weightstone",     weaponType="BLUNT",   icon=7548939},
    {itemID=237369, name="Refulgent Weightstone",     weaponType="BLUNT",   icon=7548939},
    {itemID=237370, name="Refulgent Whetstone",       weaponType="BLADED",  icon=7548942},
    {itemID=237371, name="Refulgent Whetstone",       weaponType="BLADED",  icon=7548942},
    {itemID=257749, name="Laced Zoomshots",           weaponType="RANGED",  icon=249176},
    {itemID=257750, name="Laced Zoomshots",           weaponType="RANGED",  icon=249176},
    {itemID=257751, name="Weighted Boomshots",        weaponType="RANGED",  icon=249175},
    {itemID=257752, name="Weighted Boomshots",        weaponType="RANGED",  icon=249175},
    {itemID=243733, name="Thalassian Phoenix Oil",    weaponType="NEUTRAL", icon=7548987},
    {itemID=243734, name="Thalassian Phoenix Oil",    weaponType="NEUTRAL", icon=7548987},
    {itemID=243735, name="Oil of Dawn",               weaponType="NEUTRAL", icon=7548985},
    {itemID=243736, name="Oil of Dawn",               weaponType="NEUTRAL", icon=7548985},
    {itemID=243737, name="Smuggler's Enchanted Edge", weaponType="NEUTRAL", icon=7548986},
    {itemID=243738, name="Smuggler's Enchanted Edge", weaponType="NEUTRAL", icon=7548986},
    -- TWW
    {itemID=222504, name="Ironclaw Whetstone",     weaponType="BLADED",  icon=3622195},
    {itemID=222503, name="Ironclaw Whetstone",     weaponType="BLADED",  icon=3622195},
    {itemID=222502, name="Ironclaw Whetstone",     weaponType="BLADED",  icon=3622195},
    {itemID=222510, name="Ironclaw Weightstone",   weaponType="BLUNT",   icon=3622199},
    {itemID=222509, name="Ironclaw Weightstone",   weaponType="BLUNT",   icon=3622199},
    {itemID=222508, name="Ironclaw Weightstone",   weaponType="BLUNT",   icon=3622199},
    {itemID=224107, name="Algari Mana Oil",        weaponType="NEUTRAL", icon=609892},
    {itemID=224106, name="Algari Mana Oil",        weaponType="NEUTRAL", icon=609892},
    {itemID=224105, name="Algari Mana Oil",        weaponType="NEUTRAL", icon=609892},
    {itemID=224113, name="Oil of Deep Toxins",     weaponType="NEUTRAL", icon=609897},
    {itemID=224112, name="Oil of Deep Toxins",     weaponType="NEUTRAL", icon=609897},
    {itemID=224111, name="Oil of Deep Toxins",     weaponType="NEUTRAL", icon=609897},
    {itemID=224110, name="Oil of Beledar's Grace", weaponType="NEUTRAL", icon=609896},
    {itemID=224109, name="Oil of Beledar's Grace", weaponType="NEUTRAL", icon=609896},
    {itemID=224108, name="Oil of Beledar's Grace", weaponType="NEUTRAL", icon=609896},
    {itemID=220156, name="Bubbling Wax",           weaponType="NEUTRAL", icon=133778},
}

-- Flask Items (Midnight) each flask has multiple item IDs across quality ranks + fleeting variants
local FLASK_ITEMS = {
    { key="blood_knights",         buffID=1235110, name="Flask of the Blood Knights",
      items={241324, 241325, 245931, 245930} },
    { key="magisters",             buffID=1235108, name="Flask of the Magisters",
      items={241322, 241323, 245933, 245932} },
    { key="shattered_sun",         buffID=1235111, name="Flask of the Shattered Sun",
      items={241326, 241327, 245929, 245928} },
    { key="thalassian_resistance", buffID=1235057, name="Flask of Thalassian Resistance",
      items={241320, 241321, 245926, 245927} },
    { key="thalassian_horror", buffID=1239355, name="Vicious Thalassian Flask of Honor",
      items={241334} },
}
local FLASK_BUFF_IDS = {}
local FLASK_BUFF_ID_SET = {}
local FLASK_NAME_SET = {}
for _, f in ipairs(FLASK_ITEMS) do
    FLASK_BUFF_IDS[#FLASK_BUFF_IDS+1] = f.buffID
    FLASK_BUFF_ID_SET[f.buffID] = true
    local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(f.buffID)
    if spellInfo and spellInfo.name then FLASK_NAME_SET[spellInfo.name] = true end
    FLASK_NAME_SET[f.name] = true
end
-- Previous-season and PvP-morphed variants count as an active flask too.
for _, id in ipairs({432473,432021,431974,431973,431972,431971,1235113,1235114,1235115,1235116}) do
    FLASK_BUFF_IDS[#FLASK_BUFF_IDS+1] = id
    FLASK_BUFF_ID_SET[id] = true
end

-- Food Items (Midnight)
local FOOD_ITEMS = {
    { key="royal_roast",           itemID=242275, name="Royal Roast" },
    { key="impossibly_royal_roast", itemID=255847, name="Impossibly Royal Roast" },
    { key="flora_frenzy",          itemID=255848, name="Flora Frenzy" },
    { key="champions_bento",       itemID=242274, name="Champion's Bento" },
    { key="warped_wise_wings",     itemID=242285, name="Warped Wise Wings" },
    { key="void_kissed_fish_rolls", itemID=242284, name="Void-Kissed Fish Rolls" },
    { key="sun_seared_lumifin",    itemID=242283, name="Sun-Seared Lumifin" },
    { key="null_and_void_plate",   itemID=242282, name="Null and Void Plate" },
    { key="glitter_skewers",       itemID=242281, name="Glitter Skewers" },
    { key="fel_kissed_filet",      itemID=242286, name="Fel-Kissed Filet" },
    { key="buttered_root_crab",    itemID=242280, name="Buttered Root Crab" },
    { key="arcano_cutlets",        itemID=242287, name="Arcano Cutlets" },
    { key="tasty_smoked_tetra",    itemID=242278, name="Tasty Smoked Tetra" },
    { key="crimson_calamari",      itemID=242277, name="Crimson Calamari" },
    { key="braised_blood_hunter",  itemID=242276, name="Braised Blood Hunter" },
    { key="harandar_celebration",  itemID=255846, name="Harandar Celebration" },
    { key="silvermoon_parade",     itemID=255845, name="Silvermoon Parade" },
    { key="queldorei_medley",      itemID=242272, name="Quel'dorei Medley" },
    { key="blooming_feast",        itemID=242273, name="Blooming Feast" },
    { key="sunwell_delight",       itemID=242293, name="Sunwell Delight" },
    { key="hearthflame_supper",    itemID=242295, name="Hearthflame Supper" },
    { key="fried_bloomtail",       itemID=242291, name="Fried Bloomtail" },
    { key="felberry_figs",         itemID=242294, name="Felberry Figs" },
    { key="eversong_pudding",      itemID=242292, name="Eversong Pudding" },
    { key="bloodthistle_wrapped_cutlets", itemID=242296, name="Bloodthistle-wrapped Cutlets" },
    { key="wise_tails",            itemID=242290, name="Wise Tails" },
    { key="twilight_anglers_medley", itemID=242288, name="Twilight Angler's Medley" },
    { key="spellfire_filet",       itemID=242289, name="Spellfire Filet" },
    { key="spiced_biscuits",       itemID=242304, name="Spiced Biscuits" },
    { key="silvermoon_standard",   itemID=242305, name="Silvermoon Standard" },
    { key="quick_sandwich",        itemID=242307, name="Quick Sandwich" },
    { key="portable_snack",        itemID=242308, name="Portable Snack" },
    { key="mana_infused_stew",     itemID=242303, name="Mana-Infused Stew" },
    { key="foragers_medley",       itemID=242306, name="Forager's Medley" },
    { key="farstrider_rations",    itemID=242309, name="Farstrider Rations" },
    { key="bloom_skewers",         itemID=242302, name="Bloom Skewers" },
    -- Hearty Food Items
    { key="hearty_royal_roast",            itemID=242747, name="Hearty Royal Roast" },
    { key="hearty_impossibly_royal_roast",  itemID=268679, name="Hearty Impossibly Royal Roast" },
    { key="hearty_flora_frenzy",            itemID=268680, name="Hearty Flora Frenzy" },
    { key="hearty_champions_bento",         itemID=242746, name="Hearty Champion's Bento" },
    { key="hearty_warped_wise_wings",       itemID=242757, name="Hearty Warped Wise Wings" },
    { key="hearty_void_kissed_fish_rolls",  itemID=242756, name="Hearty Void-Kissed Fish Rolls" },
    { key="hearty_sun_seared_lumifin",      itemID=242755, name="Hearty Sun-Seared Lumifin" },
    { key="hearty_null_and_void_plate",     itemID=242754, name="Hearty Null and Void Plate" },
    { key="hearty_glitter_skewers",         itemID=242753, name="Hearty Glitter Skewers" },
    { key="hearty_fel_kissed_filet",        itemID=242758, name="Hearty Fel-Kissed Filet" },
    { key="hearty_buttered_root_crab",      itemID=242752, name="Hearty Buttered Root Crab" },
    { key="hearty_arcano_cutlets",          itemID=242759, name="Hearty Arcano Cutlets" },
    { key="hearty_tasty_smoked_tetra",      itemID=242750, name="Hearty Tasty Smoked Tetra" },
    { key="hearty_crimson_calamari",        itemID=242749, name="Hearty Crimson Calamari" },
    { key="hearty_braised_blood_hunter",    itemID=242748, name="Hearty Braised Blood Hunter" },
    { key="hearty_harandar_celebration",    itemID=266996, name="Hearty Harandar Celebration" },
    { key="hearty_silvermoon_parade",       itemID=266985, name="Hearty Silvermoon Parade" },
    { key="hearty_queldorei_medley",        itemID=242744, name="Hearty Quel'dorei Medley" },
    { key="hearty_blooming_feast",          itemID=242745, name="Hearty Blooming Feast" },
    { key="hearty_sunwell_delight",         itemID=242765, name="Hearty Sunwell Delight" },
    { key="hearty_hearthflame_supper",      itemID=242767, name="Hearty Hearthflame Supper" },
    { key="hearty_fried_bloomtail",         itemID=242763, name="Hearty Fried Bloomtail" },
    { key="hearty_felberry_figs",           itemID=242766, name="Hearty Felberry Figs" },
    { key="hearty_eversong_pudding",        itemID=242764, name="Hearty Eversong Pudding" },
    { key="hearty_bloodthistle_wrapped_cutlets", itemID=242768, name="Hearty Bloodthistle-Wrapped Cutlets" },
    { key="hearty_wise_tails",              itemID=242762, name="Hearty Wise Tails" },
    { key="hearty_twilight_anglers_medley", itemID=242760, name="Hearty Twilight Angler's Medley" },
    { key="hearty_spellfire_filet",         itemID=242761, name="Hearty Spellfire Filet" },
    { key="hearty_spiced_biscuits",         itemID=242771, name="Hearty Spiced Biscuits" },
    { key="hearty_silvermoon_standard",     itemID=242772, name="Hearty Silvermoon Standard" },
    { key="hearty_quick_sandwich",          itemID=242774, name="Hearty Quick Sandwich" },
    { key="hearty_portable_snack",          itemID=242775, name="Hearty Portable Snack" },
    { key="hearty_mana_infused_stew",       itemID=242770, name="Hearty Mana-Infused Stew" },
    { key="hearty_foragers_medley",         itemID=242773, name="Hearty Forager's Medley" },
    { key="hearty_farstrider_rations",      itemID=242776, name="Hearty Farstrider Rations" },
    { key="hearty_bloom_skewers",           itemID=242769, name="Hearty Bloom Skewers" },
}

-- Weapon Enchant dropdown choices (name best itemID lookup at runtime)
local WEAPON_ENCHANT_CHOICES = {
    { key="thalassian_phoenix_oil",  name="Thalassian Phoenix Oil" },
    { key="smugglers_enchanted_edge", name="Smuggler's Enchanted Edge" },
    { key="oil_of_dawn",             name="Oil of Dawn" },
    { key="refulgent_weightstone",   name="Refulgent Weightstone" },
    { key="refulgent_whetstone",     name="Refulgent Whetstone" },
    { key="laced_zoomshots",         name="Laced Zoomshots" },
    { key="weighted_boomshots",      name="Weighted Boomshots" },
}

-- Augment Runes
local AUGMENT_RUNE_VOID   = 259085  -- Void-Touched Augment Rune (Midnight)
local AUGMENT_RUNE_ETHER  = 243191  -- Ethereal Augment Rune (TWW)
local RUNE_BUFF_IDS = {1264426, 453250, 1234969, 1242347, 393438, 347901}

-- Inky Black Potion
local INKY_BLACK_ITEM = 124640
local INKY_BLACK_BUFF = {124640}  -- The buff from Inky Black Potion

-------------------------------------------------------------------------------
--  Helpers: Well Fed / Flask buff detection (by name, not spell ID secret)
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
--  Helpers: Find best item in bags for a preferred choice
-------------------------------------------------------------------------------
function AR.FindFlaskItem(preferredKey, lastUsedItemID)
    if preferredKey == "last_used" then
        if lastUsedItemID and (GetItemCount(lastUsedItemID, false) or 0) > 0 then
            return lastUsedItemID
        end
    end

    for _, flaskGroup in ipairs(FLASK_ITEMS) do
        local shouldScanGroup = preferredKey == "last_used" or flaskGroup.key == preferredKey
        if shouldScanGroup then
            for _, itemID in ipairs(flaskGroup.items) do
                if (GetItemCount(itemID, false) or 0) > 0 then
                    return itemID
                end
            end
        end
    end

    return nil
end

function AR.FindFoodItem(preferredKey, lastUsedItemID)
    if preferredKey == "last_used" then
        if lastUsedItemID and (GetItemCount(lastUsedItemID, false) or 0) > 0 then
            return lastUsedItemID
        end
    end

    for _, food in ipairs(FOOD_ITEMS) do
        local matchesChoice = preferredKey == "last_used" or food.key == preferredKey
        if matchesChoice and (GetItemCount(food.itemID, false) or 0) > 0 then
            return food.itemID
        end
    end

    return nil
end

function AR.FindWeaponEnchantItem(preferredKey, lastUsedItemID, targetCat)
    if preferredKey == "last_used" then
        if lastUsedItemID and (GetItemCount(lastUsedItemID, false) or 0) > 0 then
            return lastUsedItemID
        end
    end

    local function MatchesWeaponCategory(entry)
        return entry.weaponType == "NEUTRAL" or entry.weaponType == targetCat
    end

    if preferredKey == "last_used" then
        for _, enchant in ipairs(WEAPON_ENCHANT_ITEMS) do
            if MatchesWeaponCategory(enchant) and (GetItemCount(enchant.itemID, false) or 0) > 0 then
                return enchant.itemID
            end
        end
        return nil
    end

    for _, choice in ipairs(WEAPON_ENCHANT_CHOICES) do
        if choice.key == preferredKey then
            for _, enchant in ipairs(WEAPON_ENCHANT_ITEMS) do
                local hasItem = (GetItemCount(enchant.itemID, false) or 0) > 0
                if hasItem and enchant.name == choice.name and MatchesWeaponCategory(enchant) then
                    return enchant.itemID
                end
            end
            break
        end
    end
    return nil
end


-------------------------------------------------------------------------------
--  Glow Types (shared with options)
-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
--  Glow engines provided by the shared KullThranUI helpers
-------------------------------------------------------------------------------
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

local function StartPixelGlow(wrapper, sz, cr, cg, cb)
    local N, th, period = 8, 2, 4
    local lineLen = floor((sz+sz)*(2/N-0.1)); lineLen = min(lineLen, sz); if lineLen < 1 then lineLen = 1 end
    SafeGlowCall("StartProceduralAnts", wrapper, N, th, period, lineLen, cr, cg, cb, sz)
end
local function StopPixelGlow(wrapper) SafeGlowCall("StopProceduralAnts", wrapper) end

local function StartButtonGlow(wrapper, sz, cr, cg, cb, scale)
    SafeGlowCall("StartButtonGlow", wrapper, sz, cr, cg, cb, scale)
end
local function StopButtonGlow(wrapper) SafeGlowCall("StopButtonGlow", wrapper) end

local function StartAutoCastShine(wrapper, sz, cr, cg, cb, scale)
    SafeGlowCall("StartAutoCastShine", wrapper, sz, cr, cg, cb, scale)
end
local function StopAutoCastShine(wrapper) SafeGlowCall("StopAutoCastShine", wrapper) end

local function StartFlipBookGlow(wrapper, sz, entry, cr, cg, cb)
    SafeGlowCall("StartFlipBookGlow", wrapper, sz, entry, cr, cg, cb)
end
local function StopFlipBookGlow(wrapper) SafeGlowCall("StopFlipBookGlow", wrapper) end

local function StopAllGlows(wrapper)
    if _G_Glows and type(_G_Glows.StopAllGlows) == "function" then
        _G_Glows.StopAllGlows(wrapper)
        return
    end

    StopPixelGlow(wrapper)
    StopButtonGlow(wrapper)
    StopAutoCastShine(wrapper)
    StopFlipBookGlow(wrapper)
end


-------------------------------------------------------------------------------
--  Defaults
-------------------------------------------------------------------------------
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
        },
        raidBuffs = {
            -- Class-wide upkeep buffs are useful while questing, testing a
            -- profile or waiting for a group as well as inside instances.
            -- Keep the option user-configurable, but do not make Battle Shout
            -- and equivalent buffs disappear while personal stances remain.
            showNonInstanced = true,
            showOthersMissing = true,
            scale = 1.0,
            enabled = {
                motw=true, bshout=true, fort=true, ai=true, bronze=true, sky=true,
            },
        },
        auras = {
            showNonInstanced = true,
            scale = 1.0,
            enabled = {
                symbiotic=true, battle_stance=true, def_stance=true, berserk_stance=true, shadowform=true,
                devo_aura=true, bol=true, bof=true, som=true, blistering_scales=true,
                bestow_weyrnstone=true, timelessness=true,
            },
        },
        customAuras = {},
        consumables = {
            showSpecialsNonInstanced = true,
            scale = 1.0,
            enabled = {
                deadly=true, instant=true, wound=true, amplifying=true,
                crippling=true, numbing=true, atrophic=true,
                rite_adj=true, rite_sanc=true,
                flametongue=true, windfury=true, earthliving=true, tidecaller=true, tstrike=true,
                ls=true, ws=true, es=true,
                augment_rune=true,
                weapon_enchant=true,
                inky_black=true,
                flask=true,
                food=true,
                pet=true,
            },
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

-------------------------------------------------------------------------------
--  Middle-click dismiss hide a reminder until the next loading screen
-------------------------------------------------------------------------------
local _dismissedUntilLoad = {}  -- [dismissKey] = true

-------------------------------------------------------------------------------
--  Icon Pool SecureActionButton based for click-to-cast
-------------------------------------------------------------------------------
local ICON_SIZE = 40
local iconAnchor
local iconPool = {}     -- all created icon buttons
local activeIcons = {}  -- currently visible icons

-- Separate anchor + pool for talent reminder icons (shown below main icons)
local talentIconAnchor
local talentIconPool = {}
local talentActiveIcons = {}

-------------------------------------------------------------------------------
--  Combat Icon Pool non-secure frames for visual-only display during combat
--  Parented to a separate combatAnchor (not iconAnchor) so Show/Hide is
--  never blocked by combat lockdown.
-------------------------------------------------------------------------------
local combatAnchor      -- created at PLAYER_LOGIN, follows iconAnchor position
local combatIconPool = {}
local combatActiveIcons = {}

-------------------------------------------------------------------------------
--  Cursor-attached combat icons "important" buffs shown at the cursor
--  when cursorAttach is enabled.
-------------------------------------------------------------------------------
local CURSOR_IMPORTANT = {
    -- All raid buffs are important (checked by cat == "raidbuff")
    -- Specific aura/consumable keys:
    es = true, som = true,
}
local cursorAnchor
local cursorIconPool = {}
local cursorActiveIcons = {}

function AR.GetStrata()
    local strata = db and db.profile and db.profile.display and db.profile.display.frameStrata
    if not strata or strata == "" then
        return "MEDIUM"
    end
    return strata
end

function AR.GetOrCreateCombatIcon(index)
    if combatIconPool[index] then return combatIconPool[index] end
    local f = CreateFrame("Frame", "KUIAR_CombatIcon"..index, combatAnchor)
    f:SetSize(ICON_SIZE, ICON_SIZE)
    f:SetFrameStrata(AR.GetStrata())
    f:SetFrameLevel(120)
    f:Hide()
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f._icon = icon
    local PP = KT and KT.PP
    if PP then PP.CreateBorder(f, 0, 0, 0, 1, 1, "OVERLAY", 7) end
    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOP", f, "BOTTOM", 0, -2)
    AR.SetABRFont(text, AR.ResolveFontPath(), 11)
    text:SetTextColor(1, 1, 1, 1)
    f._text = text
    combatIconPool[index] = f
    return f
end

function AR.HideCombatIcons()
    for i = 1, #combatActiveIcons do
        local f = combatActiveIcons[i]
        if f then f._text:SetText(""); f:Hide() end
    end
    wipe(combatActiveIcons)
    if combatAnchor then combatAnchor:Hide() end
end

function AR.ShowCombatIcon(iconIdx, spellID, texture, label)
    local f = AR.GetOrCreateCombatIcon(iconIdx)
    f._icon:SetTexture(texture or AR.GetSpellTextureCached(spellID) or 134400)
    if db and db.profile.display.showText then
        local p = db.profile.display
        local tc = p.textColor or {r=1, g=1, b=1}
        local fontPath = AR.ResolveFontPath(p.textFont)
        local textSize = p.textSize or 11
        local xOff = p.textXOffset or 0
        local yOff = p.textYOffset or -2
        AR.SetABRFont(f._text, fontPath, textSize)
        f._text:ClearAllPoints()
        f._text:SetPoint("TOP", f, "BOTTOM", xOff, yOff)
        f._text:SetTextColor(tc.r, tc.g, tc.b, 1)
        f._text:SetText(label or "")
        f._text:Show()
    else
        f._text:SetText("")
        f._text:Hide()
    end
    f:Show()
    combatActiveIcons[#combatActiveIcons+1] = f
end

function AR.LayoutIconRow(iconList, anchorFrame)
    local count = #iconList
    if count == 0 or not anchorFrame then
        return
    end

    local p = db.profile.display
    local spacing = p.iconSpacing or 8
    local baseScale = p.scale or 1.0
    local iconSize = floor(ICON_SIZE * baseScale + 0.5)
    local step = iconSize + spacing
    local startX = -(((count - 1) * step) / 2)

    for index, frame in ipairs(iconList) do
        frame:SetSize(iconSize, iconSize)
        frame:SetAlpha(p.opacity or 1.0)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", anchorFrame, "CENTER", startX + ((index - 1) * step), 0)
    end
end

function AR.LayoutCombatIcons()
    AR.LayoutIconRow(combatActiveIcons, combatAnchor)
end

-------------------------------------------------------------------------------
--  Cursor Icon Pool same visual style as combat icons, parented to
--  cursorAnchor which follows the cursor frame.
-------------------------------------------------------------------------------
function AR.GetOrCreateCursorIcon(index)
    if cursorIconPool[index] then return cursorIconPool[index] end
    local f = CreateFrame("Frame", "KUIAR_CursorIcon"..index, cursorAnchor)
    f:SetSize(ICON_SIZE, ICON_SIZE)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(9980)
    f:Hide()
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f._icon = icon
    local PP = KT and KT.PP
    if PP then PP.CreateBorder(f, 0, 0, 0, 1, 1, "OVERLAY", 7) end
    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOP", f, "BOTTOM", 0, -2)
    AR.SetABRFont(text, AR.ResolveFontPath(), 11)
    text:SetTextColor(1, 1, 1, 1)
    f._text = text
    cursorIconPool[index] = f
    return f
end

function AR.HideCursorIcons()
    for i = 1, #cursorActiveIcons do
        local f = cursorActiveIcons[i]
        if f then f._text:SetText(""); f:Hide() end
    end
    wipe(cursorActiveIcons)
    if cursorAnchor then cursorAnchor:Hide() end
end

function AR.ShowCursorIcon(iconIdx, spellID, texture, label)
    local f = AR.GetOrCreateCursorIcon(iconIdx)
    f._icon:SetTexture(texture or AR.GetSpellTextureCached(spellID) or 134400)
    if db and db.profile.display.showText then
        local p = db.profile.display
        local tc = p.textColor or {r=1, g=1, b=1}
        local fontPath = AR.ResolveFontPath(p.textFont)
        local textSize = p.textSize or 11
        local xOff = p.textXOffset or 0
        local yOff = p.textYOffset or -2
        AR.SetABRFont(f._text, fontPath, textSize)
        f._text:ClearAllPoints()
        f._text:SetPoint("TOP", f, "BOTTOM", xOff, yOff)
        f._text:SetTextColor(tc.r, tc.g, tc.b, 1)
        f._text:SetText(label or "")
        f._text:Show()
    else
        f._text:SetText("")
        f._text:Hide()
    end
    f:Show()
    cursorActiveIcons[#cursorActiveIcons+1] = f
end

function AR.LayoutCursorIcons()
    AR.LayoutIconRow(cursorActiveIcons, cursorAnchor)
end

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

-- Hide stale secure buttons by zeroing their alpha (safe during combat).
-- Also stops glow animations (glow wrappers are plain Frames, not secure).
-- Oculta todos los iconos seguros: alpha 0 + apagar glows
local FADE_TARGET_LISTS = { "activeIcons", "talentActiveIcons" }
local function FadeOutSecureIcons()
    for _, listName in ipairs(FADE_TARGET_LISTS) do
        local list = (listName == "activeIcons") and activeIcons or talentActiveIcons
        for idx = 1, #list do
            local btn = list[idx]
            if btn then
                btn:SetAlpha(0)
                if btn._text then btn._text:SetAlpha(0) end
                local glow = btn._kuiarGlowOverlay
                if glow then StopAllGlows(glow); glow:SetAlpha(0) end
            end
        end
    end
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

local function GetOrCreateIcon(index)
    if iconPool[index] then return iconPool[index] end
    -- SecureActionButtonTemplate for click-to-cast in combat
    local btn = CreateFrame("Button", "KUIAR_Icon"..index, iconAnchor, "SecureActionButtonTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "MiddleButtonUp")
    btn:SetPassThroughButtons("RightButton")
    btn:SetFrameStrata(AR.GetStrata())
    btn:Hide()

    -- Middle-click dismiss: hide this reminder until the next loading screen
    btn:HookScript("PostClick", function(self, button)
        if button == "MiddleButton" and self._dismissKey then
            _dismissedUntilLoad[self._dismissKey] = true
            if _G._KUIAR_RequestRefresh then _G._KUIAR_RequestRefresh() end
        end
    end)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn._icon = icon
    local PP = KT and KT.PP
    if PP then PP.CreateBorder(btn, 0, 0, 0, 1, 1, "OVERLAY", 7) end

    -- Text label below icon
    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    AR.SetABRFont(text, AR.ResolveFontPath(), 11)
    text:SetTextColor(1, 1, 1, 1)
    btn._text = text



    iconPool[index] = btn
    return btn
end

local function GetOrCreateTalentIcon(index)
    if talentIconPool[index] then return talentIconPool[index] end
    local btn = CreateFrame("Button", "KUIAR_TalentIcon"..index, talentIconAnchor, "SecureActionButtonTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:RegisterForClicks("LeftButtonDown", "LeftButtonUp")
    btn:SetPassThroughButtons("RightButton", "MiddleButton")
    btn:SetFrameStrata(AR.GetStrata())
    btn:Hide()
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn._icon = icon
    local PP = KT and KT.PP
    if PP then PP.CreateBorder(btn, 0, 0, 0, 1, 1, "OVERLAY", 7) end
    local text = btn:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    AR.SetABRFont(text, AR.ResolveFontPath(), 11)
    text:SetTextColor(1, 1, 1, 1)
    btn._text = text
    talentIconPool[index] = btn
    return btn
end

-- Esqueletos de atributos por tipo de acción (los nil se limpian explícitamente)
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
    AR.SetABRFont(title, AR.ResolveFontPath(), 12)
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
    menu.Title:SetText((def and def.label) or "Pet")
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
            AR.SetABRFont(btn.Label, AR.ResolveFontPath(), 10)
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
        btn.Label:SetText(info.label or "")
        btn:SetAttribute("type", "spell")
        btn:SetAttribute("spell", info.spellID)
        btn._spellID = info.spellID
        btn:Show()
    end

    for i = #entries + 1, #menu.buttons do
        menu.buttons[i]:Hide()
    end
end

local function TogglePetMenu(anchorButton, playerClass)
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

local function SetPetMenuButton(btn, playerClass, texture, label)
    local def = PET_REMINDER_DEFS[playerClass]
    btn:SetAttribute("type", nil)
    btn:SetAttribute("spell", nil)
    btn:SetAttribute("item", nil)
    btn:SetAttribute("macrotext", nil)
    btn._tooltipSpell = nil
    btn._tooltipItem = nil
    btn._petMenuClass = playerClass
    btn._icon:SetTexture(texture or (def and def.icon) or 134400)
    btn._text:SetText(label or (def and def.label) or "Pet")

    if not btn._petMenuHooked then
        btn._petMenuHooked = true
        btn:HookScript("PostClick", function(self, mouseButton)
            if mouseButton == "LeftButton" and self._petMenuClass then
                TogglePetMenu(self, self._petMenuClass)
            end
        end)
    end
end


-------------------------------------------------------------------------------
--  Core Refresh Logic
-------------------------------------------------------------------------------
local refreshQueued = false
local pendingOOCRefresh = false

local function HideAllIcons()
    HidePetMenu()
    if InCombat() then return end  -- cannot hide SecureActionButtons in combat
    for i = 1, #activeIcons do
        local btn = activeIcons[i]
        if btn then RemoveGlow(btn); btn._text:SetText(""); btn:Hide() end
    end
    wipe(activeIcons)
    for i = 1, #talentActiveIcons do
        local btn = talentActiveIcons[i]
        if btn then RemoveGlow(btn); btn._text:SetText(""); btn:Hide() end
    end
    wipe(talentActiveIcons)
    if talentIconAnchor then talentIconAnchor:Hide() end
end

local function LayoutIcons()
    local count = #activeIcons; if count == 0 then return end
    local p = db.profile.display
    local spacing = p.iconSpacing or 8
    local baseScale = p.scale or 1.0
    local sz = floor(ICON_SIZE * baseScale + 0.5)
    local totalW = (count * sz) + ((count-1) * spacing)
    local startX = -(totalW/2) + (sz/2)
    for i, btn in ipairs(activeIcons) do
        btn:SetSize(sz, sz)
        btn:SetAlpha(p.opacity or 1.0)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", iconAnchor, "CENTER", startX + (i-1)*(sz+spacing), 0)
    end
end

local function ShowIcon(iconIdx, setupFn, dismissKey)
    local btn = GetOrCreateIcon(iconIdx)
    btn._dismissKey = dismissKey or nil
    setupFn(btn)
    local p = db.profile.display
    local glowType = p.glowType or 0
    local gc = p.glowColor or {r=1, g=0.776, b=0.376}
    RemoveGlow(btn)
    ApplyGlow(btn, glowType, gc.r, gc.g, gc.b)
    if p.showText then
        local tc = p.textColor or {r=1, g=1, b=1}
        local fontPath = AR.ResolveFontPath(p.textFont)
        local textSize = p.textSize or 11
        local xOff = p.textXOffset or 0
        local yOff = p.textYOffset or -2
        AR.SetABRFont(btn._text, fontPath, textSize)
        btn._text:ClearAllPoints()
        btn._text:SetPoint("TOP", btn, "BOTTOM", xOff, yOff)
        btn._text:SetTextColor(tc.r, tc.g, tc.b, 1)
        btn._text:Show()
    else
        btn._text:SetText("")
        btn._text:Hide()
    end
    btn:Show()
    activeIcons[#activeIcons+1] = btn
end

local function LayoutTalentIcons()
    local count = #talentActiveIcons; if count == 0 then return end
    local p = db.profile.display
    local spacing = p.iconSpacing or 8
    local baseScale = p.scale or 1.0
    local sz = floor(ICON_SIZE * baseScale + 0.5)
    local totalW = (count * sz) + ((count-1) * spacing)
    local startX = -(totalW/2) + (sz/2)
    for i, btn in ipairs(talentActiveIcons) do
        btn:SetSize(sz, sz)
        btn:SetAlpha(p.opacity or 1.0)
        btn:ClearAllPoints()
        btn:SetPoint("CENTER", talentIconAnchor, "CENTER", startX + (i-1)*(sz+spacing), 0)
    end
end

local function ShowTalentIcon(iconIdx, setupFn)
    local btn = GetOrCreateTalentIcon(iconIdx)
    setupFn(btn)
    local p = db.profile.display
    local glowType = p.glowType or 0
    local gc = p.glowColor or {r=1, g=0.776, b=0.376}
    RemoveGlow(btn)
    ApplyGlow(btn, glowType, gc.r, gc.g, gc.b)
    if p.showText then
        local tc = p.textColor or {r=1, g=1, b=1}
        local fontPath = AR.ResolveFontPath(p.textFont)
        local textSize = p.textSize or 11
        local xOff = p.textXOffset or 0
        local yOff = p.textYOffset or -2
        AR.SetABRFont(btn._text, fontPath, textSize)
        btn._text:ClearAllPoints()
        btn._text:SetPoint("TOP", btn, "BOTTOM", xOff, yOff)
        btn._text:SetTextColor(tc.r, tc.g, tc.b, 1)
        btn._text:Show()
    else
        btn._text:SetText("")
        btn._text:Hide()
    end
    btn:Show()
    talentActiveIcons[#talentActiveIcons+1] = btn
end

local function CollectRaidBuffs(missing, playerClass, inInstance, inCombat)
local rb = db.profile.raidBuffs
if inInstance or rb.showNonInstanced then
    for _, buff in ipairs(RAID_BUFFS) do
        if rb.enabled[buff.key] and (buff.class == playerClass) and Known(buff.castSpell) then
            -- In combat, skip buffs whose IDs are not all whitelisted
            local canCheck = true
            if inCombat then
                for _, id in ipairs(buff.buffIDs) do
                    if not NON_SECRET_SPELL_IDS[id] then canCheck = false; break end
                end
            end
            if canCheck then
                local isMissing = false
                if rb.showOthersMissing and (IsInGroup() or IsInRaid()) then
                    isMissing = AnyGroupMemberMissingBuff(buff.buffIDs)
                else
                    isMissing = not PlayerHasAuraByID(buff.buffIDs)
                end
                if isMissing then
                    missing[#missing+1] = {
                        cat = "raidbuff", data = buff, scale = rb.scale or 1.0,
                        setup = function(btn)
                            SetIconSpell(btn, buff.castSpell, AR.GetSpellTextureCached(buff.castSpell), buff.name)
                            btn._text:SetText(AR.GetReminderShortLabel(buff.name))
                        end,
                    }
                end
            end
        end
    end
end

end

local function CollectAuras(missing, playerClass, specID, inInstance, inCombat)
local au = db.profile.auras
if inInstance or au.showNonInstanced then
    for _, aura in ipairs(AURAS) do
        if aura.standalone then
            -- Handled by standalone system, skip
        elseif au.enabled[aura.key] and (aura.class == playerClass) and Known(aura.castSpell)
           and not (aura.notIfKnown and Known(aura.notIfKnown))
           and not (aura.noPvP and AR.InPvPInstance()) then
            -- Spec check
            local specOk = true
            if aura.specs then
                specOk = false
                for _, s in ipairs(aura.specs) do if s == specID then specOk = true; break end end
            end
            if specOk then
                -- Skip auras that require instance + group when not in both
                if aura.requireInstanceGroup and (not inInstance or not (IsInGroup() or IsInRaid())) then
                    specOk = false
                elseif aura.requireGroup and not (IsInGroup() or IsInRaid()) then
                    specOk = false
                end
            end
            if specOk then
                -- Combat: skip if not combatOk or buffIDs not all whitelisted
                local canCheck = true
                if inCombat then
                    if not aura.combatOk then
                        canCheck = false
                    else
                        for _, id in ipairs(aura.buffIDs) do
                            if not NON_SECRET_SPELL_IDS[id] then canCheck = false; break end
                        end
                    end
                end
                if canCheck then
                    local isMissing = false
                    local checkIDs = (inInstance and aura.instanceBuffIDs) or aura.buffIDs
                    if aura.isStance then
                        isMissing = not AR.PlayerHasActiveStanceSpell(aura.castSpell)
                    elseif aura.check == "mineOnRaid" then
                        if inCombat then
                            isMissing = false
                        else
                            isMissing = not BuffExistsOnAnyGroupMember(aura.buffIDs)
                            if not (IsInGroup() or IsInRaid()) then isMissing = false end
                        end
                    elseif aura.check == "ownOnRaid" then
                        if inCombat then
                            -- In combat, sourceUnit is unreliable; use pre-combat snapshot
                            local cached = _preCombatOwnOnRaidCache[aura.buffIDs[1]]
                            isMissing = (cached == false)
                        else
                            isMissing = not PlayerOwnBuffOnAnyGroupMember(aura.buffIDs)
                        end
                        if not (IsInGroup() or IsInRaid()) then isMissing = false end
                    elseif aura.check == "playerSelfCast" then
                        -- Player must have the buff from their OWN cast
                        isMissing = not PlayerHasSelfCastAuraByID(aura.buffIDs)
                    else
                        isMissing = not PlayerHasAuraByID(checkIDs)
                    end
                    if isMissing then
                        missing[#missing+1] = {
                            cat = "aura", data = aura, scale = au.scale or 1.0,
                            setup = function(btn)
                                SetIconSpell(btn, aura.castSpell, AR.GetSpellTextureCached(aura.castSpell), aura.name)
                                btn._text:SetText(AR.GetReminderShortLabel(aura.name))
                            end,
                        }
                    end
                end
            end
        end
    end
end

end

local function CollectConsumables(missing, playerClass, specID, inInstance, inKeystone, inCombat)
local co = db.profile.consumables
local specialsActive = inInstance or co.showSpecialsNonInstanced
if not inKeystone then
    -- Only check consumables out of combat (secret value protection)
    if not inCombat then

        -- === SPECIALS (respect showSpecialsNonInstanced) ===
        if specialsActive then
            -- Rogue poisons are tracked by category. This prevents one missing
            -- poison from creating several duplicate icons and supports the two
            -- lethal/two non-lethal requirement from Dragon-Tempered Blades.
            if playerClass == "ROGUE" then
                local activeLethal, activeUtility, knownLethal, knownUtility = 0, 0, 0, 0
                local missingLethal, missingUtility
                for _, poison in ipairs(ROGUE_POISONS) do
                    if Known(poison.castSpell) then
                        local lethal = poison.cat == "lethal"
                        if lethal then knownLethal = knownLethal + 1 else knownUtility = knownUtility + 1 end
                        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, poison.castSpell)
                        if ok and aura then
                            if lethal then activeLethal = activeLethal + 1 else activeUtility = activeUtility + 1 end
                        elseif co.enabled[poison.key] then
                            if lethal and not missingLethal then missingLethal = poison end
                            if not lethal and not missingUtility then missingUtility = poison end
                        end
                    end
                end
                local doublePoisons = Known(DRAGON_TEMPERED_BLADES)
                local requiredLethal = math.min(knownLethal, doublePoisons and 2 or 1)
                local requiredUtility = math.min(knownUtility, doublePoisons and 2 or 1)
                if missingLethal and activeLethal < requiredLethal then
                    local poison = missingLethal
                    missing[#missing+1] = { cat="consumable", data=poison, dismissKey="consumable:rogue_lethal", scale=co.scale or 1.0,
                        setup=function(btn) SetIconSpell(btn, poison.castSpell, AR.GetSpellTextureCached(poison.castSpell), poison.name); btn._text:SetText(LText("Poison")) end }
                end
                if missingUtility and activeUtility < requiredUtility then
                    local poison = missingUtility
                    missing[#missing+1] = { cat="consumable", data=poison, dismissKey="consumable:rogue_utility", scale=co.scale or 1.0,
                        setup=function(btn) SetIconSpell(btn, poison.castSpell, AR.GetSpellTextureCached(poison.castSpell), poison.name); btn._text:SetText(LText("Poison")) end }
                end
            end

            -- Paladin Rites
            if playerClass == "PALADIN" then
                for _, rite in ipairs(PALADIN_RITES) do
                    if co.enabled[rite.key] and Known(rite.castSpell) then
                        local hasMH = AR.GetTemporaryWeaponEnchants()
                        if not hasMH then
                            missing[#missing+1] = {
                                cat = "consumable", data = rite, scale = co.scale or 1.0,
                                setup = function(btn)
                                    SetIconSpell(btn, rite.castSpell, AR.GetSpellTextureCached(rite.castSpell), rite.name)
                                    btn._text:SetText(AR.GetReminderShortLabel(rite.name))
                                end,
                            }
                        end
                    end
                end
            end

            -- Shaman Imbues
            if playerClass == "SHAMAN" then
                for _, imbue in ipairs(SHAMAN_IMBUES) do
                    if co.enabled[imbue.key] and Known(imbue.castSpell) then
                        local hasMH = AR.GetTemporaryWeaponEnchants()
                        if not hasMH then
                            missing[#missing+1] = {
                                cat = "consumable", data = imbue, scale = co.scale or 1.0,
                                setup = function(btn)
                                    SetIconSpell(btn, imbue.castSpell, AR.GetSpellTextureCached(imbue.castSpell), imbue.name)
                                    btn._text:SetText(AR.GetReminderShortLabel(imbue.name, "SHAMAN_IMBUE"))
                                end,
                            }
                        end
                    end
                end

                -- Shaman Shields (OOC only LS, WS are not non-secret)
                -- Earth Shield is handled separately below (combat-safe).
                for _, shield in ipairs(SHAMAN_SHIELDS) do
                    if shield.key ~= "es" and co.enabled[shield.key] and Known(shield.castSpell) then
                        local specOk = true
                        if shield.specs then
                            specOk = false
                            for _, s in ipairs(shield.specs) do if s == specID then specOk = true; break end end
                        end
                        if specOk then
                            if not PlayerHasAuraByID(shield.buffIDs) then
                                missing[#missing+1] = {
                                    cat = "consumable", data = shield, scale = co.scale or 1.0,
                                    setup = function(btn)
                                        SetIconSpell(btn, shield.castSpell, AR.GetSpellTextureCached(shield.castSpell), shield.name)
                                        btn._text:SetText(AR.GetReminderShortLabel(shield.name, "SHAMAN_SHIELD"))
                                    end,
                                }
                            end
                        end
                    end
                end

            end
        end -- end specialsActive

        -- === INSTANCE-ONLY CONSUMABLES (runes, weapon enchants, flask, food, inky black) ===
        if inInstance then

        -- Augment Runes (display mode: mythic, heroic_mythic, or all)
        if co.enabled.augment_rune then
            local runeMode = co.runeDisplayMode or "mythic"
            local showRune = false
            if runeMode == "mythic" then
                showRune = AR.IsMythicZeroOrMythicRaid()
            elseif runeMode == "heroic_mythic" then
                showRune = AR.IsHeroicOrMythicInstance()
            elseif runeMode == "all" then
                showRune = AR.InRealInstancedContent()
            end
            if showRune then
                local hasRuneBuff = PlayerHasAuraByID(RUNE_BUFF_IDS)
                if not hasRuneBuff then
                    local voidCount = GetItemCount(AUGMENT_RUNE_VOID, false) or 0
                    local etherCount = GetItemCount(AUGMENT_RUNE_ETHER, false) or 0
                    local runeItem = nil
                    if voidCount > 0 then runeItem = AUGMENT_RUNE_VOID
                    elseif etherCount > 0 then runeItem = AUGMENT_RUNE_ETHER end
                    if runeItem then
                        missing[#missing+1] = {
                            cat = "consumable", dismissKey = "consumable:rune", scale = co.scale or 1.0,
                            setup = function(btn)
                                SetIconItem(btn, runeItem, GetItemIcon(runeItem), "Augment Rune")
                                btn._text:SetText(AR.GetReminderShortLabel("Augment Rune"))
                            end,
                        }
                    end
                end
            end
        end

        -- Weapon Enchants (temp weapon enchant items)
        if co.enabled.weapon_enchant then
            local hasMH, _, _, _, hasOH = AR.GetTemporaryWeaponEnchants()
            local mhCat = AR.GetWeaponCategory(16)
            local ohCat = AR.GetWeaponCategory(17)

            -- Determine which slot needs an enchant: prefer MH, fall back to OH
            local targetSlot, targetCat
            if mhCat and not hasMH then
                targetSlot = 16
                targetCat = mhCat
            elseif ohCat and hasMH and not hasOH then
                targetSlot = 17
                targetCat = ohCat
            end

            if targetSlot and targetCat then
                local preferredKey = co.preferredWeaponEnchant or "last_used"
                local lastUsedID = db.char and db.char.lastUsedWeaponEnchant or nil
                local bestItemID = AR.FindWeaponEnchantItem(preferredKey, lastUsedID, targetCat)
                if not bestItemID then
                    -- Fallback: any matching weapon enchant in bags
                    for _, we in ipairs(WEAPON_ENCHANT_ITEMS) do
                        local wt = we.weaponType
                        if ((wt == "NEUTRAL") or (wt == targetCat)) and (GetItemCount(we.itemID, false) or 0) > 0 then
                            bestItemID = we.itemID; break
                        end
                    end
                end
                if bestItemID then
                    local slot = targetSlot
                    local bestIcon = GetItemIcon(bestItemID) or 134400
                    missing[#missing+1] = {
                        cat = "consumable", dismissKey = "consumable:weapon_enchant", scale = co.scale or 1.0,
                        setup = function(btn)
                            local macro = "/use item:" .. bestItemID .. "\n/use " .. slot
                            SetIconMacro(btn, macro, bestIcon, nil)
                            btn._tooltipItem = bestItemID
                            btn._text:SetText(AR.GetReminderShortLabel("Weapon Enchant"))
                        end,
                    }
                end
            end
        end

        -- Flask (OOC only, not during keystones buff is secret)
        if co.enabled.flask then
            if not AR.PlayerHasFlaskBuff() then
                local preferredKey = co.preferredFlask or "last_used"
                local lastUsedID = db.char and db.char.lastUsedFlask or nil
                local flaskItemID = AR.FindFlaskItem(preferredKey, lastUsedID)
                if flaskItemID then
                    local flaskIcon = GetItemIcon(flaskItemID) or 134830
                    missing[#missing+1] = {
                        cat = "consumable", dismissKey = "consumable:flask", scale = co.scale or 1.0,
                        setup = function(btn)
                            SetIconItem(btn, flaskItemID, flaskIcon, "Flask")
                            btn._text:SetText(LText("Flask"))
                        end,
                    }
                end
            end
        end

        -- Food / Well Fed (OOC only, not during keystones buff is secret)
        if co.enabled.food then
            if not AR.PlayerHasWellFed() then
                local preferredKey = co.preferredFood or "last_used"
                local lastUsedID = db.char and db.char.lastUsedFood or nil
                local foodItemID = AR.FindFoodItem(preferredKey, lastUsedID)
                if foodItemID then
                    local foodIcon = GetItemIcon(foodItemID) or 136000 -- spell_misc_food (Well Fed)
                    missing[#missing+1] = {
                        cat = "consumable", dismissKey = "consumable:food", scale = co.scale or 1.0,
                        setup = function(btn)
                            SetIconItem(btn, foodItemID, foodIcon, "Food")
                            btn._text:SetText(LText("Food"))
                        end,
                    }
                end
            end
        end

        -- Inky Black Potion (zone-specific)
        if co.enabled.inky_black then
            local zones = co.inkyBlackZones or ""
            if zones ~= "" then
                -- Cache parsed zone set on the string itself
                if not co._inkyZoneSet or co._inkyZoneSrc ~= zones then
                    local s = {}
                    for zid in zones:gmatch("[^,%s]+") do s[zid] = true end
                    co._inkyZoneSet = s
                    co._inkyZoneSrc = zones
                end
                local currentZone = tostring(C_Map.GetBestMapForUnit("player") or 0)
                if co._inkyZoneSet[currentZone] then
                    local hasPotion = (GetItemCount(INKY_BLACK_ITEM, false) or 0) > 0
                    local hasBuff = AR.PlayerHasBuffByName("Inky Black Potion")
                    if not hasBuff and hasPotion then
                        missing[#missing+1] = {
                            cat = "consumable", dismissKey = "consumable:inky_black", scale = co.scale or 1.0,
                            setup = function(btn)
                                SetIconItem(btn, INKY_BLACK_ITEM, GetItemIcon(INKY_BLACK_ITEM), "Inky Black Potion")
                                btn._text:SetText(AR.GetReminderShortLabel("Inky Black Potion"))
                            end,
                        }
                    end
                end
            end
        end
        end -- end inInstance
    end -- end not inCombat

    -- Earth Shield (elemental orbit) safe in combat, spell IDs 974 and
    -- 383648 are non-secret.  Uses GetUnitAuraBySpellID for group checks.
    -- Other shaman shields (LS, WS) remain OOC-only above.
    if specialsActive and playerClass == "SHAMAN" then
        for _, shield in ipairs(SHAMAN_SHIELDS) do
            if shield.key == "es" and co.enabled[shield.key] and Known(shield.castSpell) then
                local specOk = true
                if shield.specs then
                    specOk = false
                    for _, s in ipairs(shield.specs) do if s == specID then specOk = true; break end end
                end
                if specOk then
                    local isMissing = false
                    if shield.orbitTalent and Known(shield.orbitTalent) then
                        local selfHas = PlayerHasAuraByID(shield.selfOrbitBuff)
                        local otherHas = PlayerOwnBuffOnAnyGroupMember(shield.otherBuff)
                        isMissing = not selfHas or (not otherHas and (IsInGroup() or IsInRaid()))
                    else
                        isMissing = not PlayerHasAuraByID(shield.buffIDs)
                    end
                    if isMissing then
                        missing[#missing+1] = {
                            cat = "consumable", data = shield, scale = co.scale or 1.0,
                            setup = function(btn)
                                SetIconSpell(btn, shield.castSpell, AR.GetSpellTextureCached(shield.castSpell), shield.name)
                                btn._text:SetText(AR.GetReminderShortLabel(shield.name, "SHAMAN_SHIELD"))
                            end,
                        }
                    end
                end
            end
        end
    end

end -- end consumables

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

local function CollectTalentReminders(talentMissing, inInstance, inKeystone, inCombat)
if not inKeystone and not inCombat and inInstance then
    local reminders = db.profile.talentReminders
    if reminders and #reminders > 0 then
        local currentInstance, currentInstanceID = AR.GetCurrentInstanceName()
        -- Fallback for the brief transition where GetInstanceInfo has no ID yet.
        if not currentInstanceID and C_Map and C_Map.GetBestMapForUnit then
            currentInstanceID = C_Map.GetBestMapForUnit("player")
        end
        if currentInstance then
            for _, reminder in ipairs(reminders) do
                -- Build name set cache once per reminder
                if not reminder._nameSet and reminder.zoneNames then
                    local s = {}
                    for _, zn in ipairs(reminder.zoneNames) do s[zn] = true end
                    reminder._nameSet = s
                end

                -- New reminders persist stable IDs; old reminders keep working
                -- through the canonical-name compatibility path below.
                if not reminder._instanceIDSet then
                    local s = {}
                    for _, id in ipairs(reminder.zoneIDs or {}) do
                        id = tonumber(id)
                        if id then s[id] = true end
                    end
                    reminder._instanceIDSet = s
                end

                -- Match by stable instance ID first (multilanguage-safe).
                local zoneMatch = false
                if currentInstanceID then
                    zoneMatch = reminder._instanceIDSet[currentInstanceID] or false
                    if not zoneMatch then
                        local instanceZone = TALENT_REMINDER_ZONE_BY_INSTANCE_ID[currentInstanceID]
                        if instanceZone and reminder._nameSet then
                            zoneMatch = reminder._nameSet[instanceZone.name] or false
                        end
                    end
                end
                if not zoneMatch and reminder._nameSet then
                    zoneMatch = reminder._nameSet[currentInstance] or false
                end

                local hasTalent = IsPlayerSpell(reminder.spellID) or IsSpellKnown(reminder.spellID)

                if zoneMatch and not hasTalent then
                    local rSpellID = reminder.spellID
                    local rSpellName = reminder.spellName or "Unknown"
                    local rIcon = AR.GetSpellTextureCached(rSpellID) or 134400
                    talentMissing[#talentMissing+1] = {
                        cat = "talent", scale = 1.0,
                        setup = function(btn)
                            if not InCombat() then
                                btn:SetAttribute("type", nil)
                                btn:SetAttribute("spell", nil)
                                btn:SetAttribute("item", nil)
                                btn:SetAttribute("macrotext", nil)
                            end
                            btn._icon:SetTexture(rIcon)
                            btn._tooltipSpell = rSpellID
                            btn._tooltipItem = nil
                            btn._text:SetText(rSpellName)
                        end,
                    }
                elseif not zoneMatch and reminder.showNotNeeded and hasTalent then
                    local rSpellID = reminder.spellID
                    local rSpellName = (reminder.spellName or "Unknown")
                    local rIcon = AR.GetSpellTextureCached(rSpellID) or 134400
                    talentMissing[#talentMissing+1] = {
                        cat = "talent", scale = 1.0,
                        setup = function(btn)
                            if not InCombat() then
                                btn:SetAttribute("type", nil)
                                btn:SetAttribute("spell", nil)
                                btn:SetAttribute("item", nil)
                                btn:SetAttribute("macrotext", nil)
                            end
                            btn._icon:SetTexture(rIcon)
                            btn._tooltipSpell = rSpellID
                            btn._tooltipItem = nil
                            btn._text:SetText(rSpellName .. " (N/N)")
                        end,
                    }
                end
            end
        end
    end
end

end

-- Reusable tables wiped each Refresh() call to avoid per-call allocation.
local _refreshMissing = {}
local _refreshTalentMissing = {}
-- Refresh is defined before the optional paladin beacon subsystem. Forward
-- declarations keep this branch valid when the module is disabled early.
local BeaconSetVisible = function() end
local BEACON_BOL, BEACON_BOF

local function Refresh()
    if not db then return end
    if db.profile and db.profile.enable == false then
        AR.HideCombatIcons()
        AR.HideCursorIcons()
        HideAllIcons()
        BeaconSetVisible(BEACON_BOL, false)
        BeaconSetVisible(BEACON_BOF, false)
        return
    end
    HidePetMenu()
    if optionsPanelVisible then AR.HideCombatIcons(); HideAllIcons(); return end

    -- Hide all reminders while skyriding (mounted + flying) or in a vehicle.
    -- Both IsMounted/IsFlying/UnitInVehicle are safe in combat (no taint).
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

    -- Collect missing reminders
    local missing = _refreshMissing
    wipe(missing)

    ---------------------------------------------------------------------------
    --  1) Raid Buffs
    ---------------------------------------------------------------------------
    CollectRaidBuffs(missing, playerClass, inInstance, inCombat)

    ---------------------------------------------------------------------------
    --  2) Auras
    ---------------------------------------------------------------------------
    CollectAuras(missing, playerClass, specID, inInstance, inCombat)

    ---------------------------------------------------------------------------
    --  3) Consumables
    ---------------------------------------------------------------------------
    if not AR.InPvPInstance() then
        CollectConsumables(missing, playerClass, specID, inInstance, inKeystone, inCombat)
    end

    ---------------------------------------------------------------------------
    --  4) Talent Reminders
    ---------------------------------------------------------------------------
    local talentMissing = _refreshTalentMissing
    wipe(talentMissing)
    CollectTalentReminders(talentMissing, inInstance, inKeystone, inCombat)

    ---------------------------------------------------------------------------
    --  5) Pet Reminder
    ---------------------------------------------------------------------------
    CollectPetReminders(missing, playerClass)


    ---------------------------------------------------------------------------
    --  Apply results
    ---------------------------------------------------------------------------
    if inCombat then
        -- Combat path: use non-secure visual-only icons.
        -- Fade out stale secure buttons (SetAlpha is safe during combat).
        FadeOutSecureIcons()
        AR.HideCombatIcons()
        AR.HideCursorIcons()
        if #missing > 0 then
            local useCursor = db.profile.display.cursorAttach and cursorAnchor
            local combatIdx, cursorIdx = 0, 0
            for _, m in ipairs(missing) do
                -- Skip middle-click dismissed reminders
                local dk = m.dismissKey or (m.data and m.data.key and (m.cat .. ":" .. m.data.key)) or nil
                if not (dk and _dismissedUntilLoad[dk]) then
                    -- Only show reminders whose buff IDs are ALL whitelisted non-secret.
                    -- Anything else must never appear during combat.
                    local safe = m.mode == "texture"
                    if not safe and m.data and m.data.buffIDs then
                        safe = true
                        for _, id in ipairs(m.data.buffIDs) do
                            if not NON_SECRET_SPELL_IDS[id] then safe = false; break end
                        end
                    end
                    if safe then
                        local spellID = m.data and m.data.castSpell
                        local texture = (m.mode == "texture" and m.texture) or (spellID and AR.GetSpellTextureCached(spellID)) or 134400
                        local label = (m.mode == "texture" and m.label) or (m.data and AR.GetReminderShortLabel(m.data.name)) or ""
                        if useCursor and IsImportantBuff(m) then
                            cursorIdx = cursorIdx + 1
                            AR.ShowCursorIcon(cursorIdx, spellID, texture, label)
                        else
                            combatIdx = combatIdx + 1
                            AR.ShowCombatIcon(combatIdx, spellID, texture, label)
                        end
                    end
                end
            end
            if combatIdx > 0 then combatAnchor:Show(); AR.LayoutCombatIcons() end
            if cursorIdx > 0 then cursorAnchor:Show(); AR.LayoutCursorIcons() end
        end
        return
    end

    -- OOC path: full secure button display
    AR.HideCombatIcons()
    AR.HideCursorIcons()
    HideAllIcons()

    if #missing > 0 then
        local iconIdx = 0
        for _, m in ipairs(missing) do
            local dk = m.dismissKey or (m.data and m.data.key and (m.cat .. ":" .. m.data.key)) or nil
            if not dk or not _dismissedUntilLoad[dk] then
                iconIdx = iconIdx + 1
                ShowIcon(iconIdx, m.setup, dk)
            end
        end
        if iconIdx > 0 then
            LayoutIcons()
            iconAnchor:Show()
        end
    end

    -- Talent reminders on a separate anchor below the main icons
    if #talentMissing > 0 and talentIconAnchor then
        for i, m in ipairs(talentMissing) do
            ShowTalentIcon(i, m.setup)
        end
        LayoutTalentIcons()
        talentIconAnchor:Show()
    end
end

local function RequestRefresh()
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        Refresh()
    end)
end


-------------------------------------------------------------------------------
--  Unlock Mode
-------------------------------------------------------------------------------
local function ApplyUnlockPos()
    if not iconAnchor or not db then return end
    local pos = db.profile.unlockPos
    local function GetUnlockMoverMetrics()
        local p = db.profile.display or {}
        local baseScale = p.scale or 1.0
        local sz = floor(ICON_SIZE * baseScale + 0.5)
        local spacing = p.iconSpacing or 8
        local count = max(#activeIcons, 3)
        local w = count * sz + (count - 1) * spacing
        local textH = 0
        if p.showText then
            textH = (p.textSize or 11) + abs(p.textYOffset or -2)
        end
        local h = sz + textH
        return w, h, sz, textH
    end
    local function NormalizeUnlockPos(savedPos)
        if not (savedPos and savedPos.point) then
            return savedPos
        end
        if savedPos._ktCenterAligned then
            return savedPos
        end
        if savedPos.point == "TOPLEFT" and (savedPos.relPoint == nil or savedPos.relPoint == "TOPLEFT") then
            local w, _, sz = GetUnlockMoverMetrics()
            savedPos.point = "CENTER"
            savedPos.relPoint = "TOPLEFT"
            savedPos.x = (savedPos.x or 0) + (w / 2)
            savedPos.y = (savedPos.y or 0) - (sz / 2)
        end
        savedPos._ktCenterAligned = true
        return savedPos
    end
    if pos and pos.point then
        pos = NormalizeUnlockPos(pos)
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

local function RegisterUnlockElements()
    if not KT or not KT.RegisterMovableElements then return end
    local function GetUnlockMoverMetrics()
        local p = db.profile.display
        local baseScale = p.scale or 1.0
        local sz = floor(ICON_SIZE * baseScale + 0.5)
        local spacing = p.iconSpacing or 8
        local count = max(#activeIcons, 3)
        local w = count * sz + (count - 1) * spacing
        local textH = 0
        if p.showText then
            textH = (p.textSize or 11) + abs(p.textYOffset or -2)
        end
        local h = sz + textH
        return w, h, sz, textH
    end
    KT:RegisterMovableElements({
        {
            key = "KUIAR_Reminders",
            label = "Aura Reminders",
            group = "Aura Reminders",
            order = 600,
            getFrame = function() return iconAnchor end,
            getSize = function()
                local w, h = GetUnlockMoverMetrics()
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
                local w, h, sz = GetUnlockMoverMetrics()
                return centerX - (w / 2), centerY + (sz / 2), w, h
            end,
            translateMoverPosition = function(_, pos)
                local w, _, sz = GetUnlockMoverMetrics()
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

-------------------------------------------------------------------------------
--  Last-Used Item Tracking (per-character)
-------------------------------------------------------------------------------
local FLASK_ITEM_SET = {}
for _, f in ipairs(FLASK_ITEMS) do
    for _, id in ipairs(f.items) do FLASK_ITEM_SET[id] = true end
end

local FOOD_ITEM_SET = {}
for _, f in ipairs(FOOD_ITEMS) do FOOD_ITEM_SET[f.itemID] = true end

local WEAPON_ENCHANT_ITEM_SET = {}
for _, we in ipairs(WEAPON_ENCHANT_ITEMS) do WEAPON_ENCHANT_ITEM_SET[we.itemID] = true end

local function TrackItemUse(itemID)
    if not db or not db.char then return end
    if FLASK_ITEM_SET[itemID] then
        db.char.lastUsedFlask = itemID
    elseif FOOD_ITEM_SET[itemID] then
        db.char.lastUsedFood = itemID
    elseif WEAPON_ENCHANT_ITEM_SET[itemID] then
        db.char.lastUsedWeaponEnchant = itemID
    end
end

-------------------------------------------------------------------------------
--  STANDALONE BEACON REMINDERS (IsSpellOverlayed-based, fully combat-safe)
--  Completely independent from the aura/buff reminder system above.
--  Uses Blizzard's spell activation overlay to detect missing beacons.
-------------------------------------------------------------------------------
local _beaconFrame = CreateFrame("Frame")
local _beaconIsPaladin = false
local _beaconOverlayRegistered = false
local _beaconAnchor
local _beaconIcons = {}       -- [spellID] = frame
local _beaconIconState = {}   -- [spellID] = true/false
local _beaconGlowState = {}  -- [spellID] = true/false

BEACON_BOL = 53563
BEACON_BOF = 156910
local BEACON_VIRTUE = 200025
local BEACON_ALL = { BEACON_BOL, BEACON_BOF }

local IsSpellOverlayed = (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) or IsSpellOverlayed

local _beaconCachedInInstance = false

local function BeaconUpdateInstanceCache()
    local _, instanceType, difficultyID = GetInstanceInfo()
    difficultyID = tonumber(difficultyID) or 0
    if difficultyID == 0 then _beaconCachedInInstance = false; return end
    if C_Garrison and C_Garrison.IsOnGarrisonMap and C_Garrison.IsOnGarrisonMap() then
        _beaconCachedInInstance = false; return
    end
    _beaconCachedInInstance = (instanceType == "party" or instanceType == "raid")
end

local function BeaconUpdateOverlayEvents()
    if _beaconCachedInInstance and _beaconIsPaladin then
        if not _beaconOverlayRegistered then
            _beaconFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
            _beaconFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
            _beaconOverlayRegistered = true
        end
    else
        if _beaconOverlayRegistered then
            _beaconFrame:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
            _beaconFrame:UnregisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
            _beaconOverlayRegistered = false
        end
    end
end

local function BeaconMakeIcon(spellID)
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(ICON_SIZE, ICON_SIZE)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(120)
    f:Hide()
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(AR.GetSpellTextureCached(spellID))
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    f._icon = icon
    f._spellID = spellID
    local PP = KT and KT.PP
    if PP then PP.CreateBorder(f, 0, 0, 0, 1, 1, "OVERLAY", 7) end
    local text = f:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOP", f, "BOTTOM", 0, -2)
    AR.SetABRFont(text, AR.ResolveFontPath(), 11)
    text:SetTextColor(1, 1, 1, 1)
    f._text = text
    return f
end

local function BeaconLayoutIcons()
    local visible = {}
    for _, id in ipairs(BEACON_ALL) do
        if _beaconIconState[id] then visible[#visible+1] = _beaconIcons[id] end
    end
    local count = #visible
    if count == 0 then if _beaconAnchor then _beaconAnchor:Hide() end; return end
    if not _beaconAnchor then return end
    _beaconAnchor:Show()
    local p = db and db.profile.display
    local spacing = p and p.iconSpacing or 8
    local baseScale = (p and p.scale or 1.0) * (db and db.profile.auras and db.profile.auras.scale or 1.0)
    local sz = floor(ICON_SIZE * baseScale + 0.5)
    local totalW = (count * sz) + ((count - 1) * spacing)
    local startX = -(totalW / 2) + (sz / 2)
    for i, f in ipairs(visible) do
        f:SetSize(sz, sz)
        f:SetAlpha(p and p.opacity or 1.0)
        f:ClearAllPoints()
        f:SetPoint("CENTER", _beaconAnchor, "CENTER", startX + (i - 1) * (sz + spacing), 0)
    end
end

local function BeaconApplyGlow(f, show)
    if show then
        local p = db and db.profile.display
        local glowType = p and p.glowType or 0
        if glowType > 0 then
            local gc = p and p.glowColor or {r=1, g=0.776, b=0.376}
            ApplyGlow(f, glowType, gc.r, gc.g, gc.b)
        end
        _beaconGlowState[f._spellID] = true
    else
        if _beaconGlowState[f._spellID] then
            RemoveGlow(f)
            _beaconGlowState[f._spellID] = false
        end
    end
end

local function BeaconApplyText(f)
    local p = db and db.profile.display
    if p and p.showText then
        local tc = p.textColor or {r=1, g=1, b=1}
        local fontPath = AR.ResolveFontPath(p.textFont)
        local textSize = p.textSize or 11
        local xOff = p.textXOffset or 0
        local yOff = p.textYOffset or -2
        AR.SetABRFont(f._text, fontPath, textSize)
        f._text:ClearAllPoints()
        f._text:SetPoint("TOP", f, "BOTTOM", xOff, yOff)
        f._text:SetTextColor(tc.r, tc.g, tc.b, 1)
        f._text:SetText(AR.GetReminderShortLabel(f._spellID == BEACON_BOL and "Beacon of Light" or "Beacon of Faith"))
        f._text:Show()
    else
        f._text:SetText("")
        f._text:Hide()
    end
end

BeaconSetVisible = function(spellID, show)
    local f = _beaconIcons[spellID]
    if not f then return end
    local changed = false
    if show then
        if not _beaconIconState[spellID] then
            BeaconApplyText(f)
            f:Show()
            _beaconIconState[spellID] = true
            BeaconApplyGlow(f, true)
            changed = true
        end
    else
        if _beaconIconState[spellID] then
            BeaconApplyGlow(f, false)
            f._text:SetText("")
            f:Hide()
            _beaconIconState[spellID] = false
            changed = true
        end
    end
    if changed then BeaconLayoutIcons() end
end

local function BeaconRefresh()
    if not _beaconIsPaladin then return end
    if not (db and db.profile and db.profile.enable ~= false) then
        BeaconSetVisible(BEACON_BOL, false)
        BeaconSetVisible(BEACON_BOF, false)
        return
    end
    if optionsPanelVisible or not IsSpellOverlayed then
        BeaconSetVisible(BEACON_BOL, false)
        BeaconSetVisible(BEACON_BOF, false)
        return
    end
    if UnitInVehicle("player") or (IsMounted() and IsFlying()) then
        BeaconSetVisible(BEACON_BOL, false)
        BeaconSetVisible(BEACON_BOF, false)
        return
    end
    if not _beaconCachedInInstance or not (IsInGroup() or IsInRaid()) then
        BeaconSetVisible(BEACON_BOL, false)
        BeaconSetVisible(BEACON_BOF, false)
        return
    end

    local au = db and db.profile.auras
    local enabled = au and au.enabled

    local trackBOL = enabled and enabled.bol ~= false
                     and Known(BEACON_BOL) and not Known(BEACON_VIRTUE)
    local trackBOF = enabled and enabled.bof ~= false
                     and Known(BEACON_BOF)

    BeaconSetVisible(BEACON_BOL, trackBOL and IsSpellOverlayed(BEACON_BOL))
    BeaconSetVisible(BEACON_BOF, trackBOF and IsSpellOverlayed(BEACON_BOF))
end

local _beaconRefreshPending = false
local function BeaconRefreshSoon()
    if _beaconRefreshPending then return end
    _beaconRefreshPending = true
    C_Timer.After(0, function()
        _beaconRefreshPending = false
        BeaconRefresh()
    end)
end

local function BeaconInit()
    local _, classFile = UnitClass("player")
    _beaconIsPaladin = (classFile == "PALADIN")
    if not _beaconIsPaladin then return end

    _beaconIcons[BEACON_BOL] = BeaconMakeIcon(BEACON_BOL)
    _beaconIcons[BEACON_BOF] = BeaconMakeIcon(BEACON_BOF)

    -- Anchor follows the main combat anchor position
    _beaconAnchor = CreateFrame("Frame", "KUIAR_BeaconAnchor", UIParent)
    _beaconAnchor:SetSize(1, 1)
    _beaconAnchor:SetFrameStrata("HIGH")
    _beaconAnchor:EnableMouse(false)
    _beaconAnchor:Hide()
    -- Anchor to the combat anchor (created by mainFrame PLAYER_LOGIN before this call)
    if combatAnchor then
        _beaconAnchor:SetPoint("CENTER", combatAnchor, "CENTER", 0, -60)
    else
        _beaconAnchor:SetPoint("CENTER", UIParent, "CENTER", 0, 200)
    end

    BeaconUpdateInstanceCache()
    BeaconUpdateOverlayEvents()
    BeaconRefresh()
end

-- Expose for options and anchor positioning
_G._KUIAR_BeaconRefresh = BeaconRefresh
_G._KUIAR_BeaconAnchor = function() return _beaconAnchor end

_beaconFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
_beaconFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
_beaconFrame:RegisterEvent("SPELLS_CHANGED")
_beaconFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
_beaconFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
_beaconFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
_beaconFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
_beaconFrame:SetScript("OnEvent", function(_, e, id)
    if not _beaconIsPaladin then return end
    if e == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or e == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        if id == BEACON_BOL or id == BEACON_BOF then
            BeaconRefresh()
        end
        return
    end
    if e == "PLAYER_ENTERING_WORLD" or e == "ZONE_CHANGED_NEW_AREA" then
        BeaconUpdateInstanceCache()
        BeaconUpdateOverlayEvents()
    end
    if e == "TRAIT_CONFIG_UPDATED" or e == "PLAYER_TALENT_UPDATE"
       or e == "SPELLS_CHANGED" or e == "PLAYER_SPECIALIZATION_CHANGED" then
        BeaconRefreshSoon()
        return
    end
    BeaconRefresh()
end)

-------------------------------------------------------------------------------
--  MAIN EVENT HANDLER
-------------------------------------------------------------------------------
local mainFrame = CreateFrame("Frame")

mainFrame:SetScript("OnEvent", function(_, e, arg1, arg2)
    if e == "PLAYER_LOGIN" then
        if not AceDB then
            return
        end
        db = AceDB:New("KUIAuraRemindersDB", defaults, true)

        -- Migration: Source of Magic moved from raidBuffs to auras
        if db.profile.raidBuffs and db.profile.raidBuffs.enabled and db.profile.raidBuffs.enabled.som ~= nil then
            if db.profile.auras and db.profile.auras.enabled then
                if db.profile.auras.enabled.som == nil then
                    db.profile.auras.enabled.som = db.profile.raidBuffs.enabled.som
                end
            end
            db.profile.raidBuffs.enabled.som = nil
        end


        -- Expose globals for options
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
                            RequestRefresh()
                            BeaconRefresh()
                        end)
                    end

                    if KT.MenuPrincipal and KT.MenuPrincipal:IsShown() then
                        optionsPanelVisible = true
                        HideAllIcons()
                        BeaconRefresh()
                    else
                        optionsPanelVisible = false
                        RequestRefresh()
                        BeaconRefresh()
                    end
                end)
            end)
        end

        RequestRefresh()
        BeaconInit()
        C_Timer.After(0.5, RegisterUnlockElements)
        return
    end

    if e == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: immediately hide OOC secure icons, snapshot, then refresh
        FadeOutSecureIcons()
        SnapshotPlayerAuras()
        SnapshotOwnOnRaidBuffs()
        RequestRefresh()
        return
    end

    if e == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat: clean up combat icons, do full OOC refresh with secure buttons
        AR.HideCombatIcons()
        AR.HideCursorIcons()
        pendingOOCRefresh = false
        RequestRefresh()
        return
    end

    if e == "PLAYER_ENTERING_WORLD" then
        -- Loading screen completed: clear middle-click dismissed reminders
        wipe(_dismissedUntilLoad)
        RequestRefresh()
        return
    end

    if e == "UNIT_AURA" then
        if arg1 == "player" then
            RequestRefresh()
        end
        return
    end

    if e == "UNIT_ENTERED_VEHICLE" or e == "UNIT_EXITED_VEHICLE" then
        if arg1 == "player" then RequestRefresh() end
        return
    end

    -- All other events: just refresh
    RequestRefresh()
end)

-- Item use tracking via bag snapshot diffing on BAG_UPDATE_DELAYED
local lastBagSnapshot = {}

local function SnapshotBags()
    local snap = {}
    for bag = 0, 4 do
        local numSlots = C_Container and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, numSlots do
            local info = C_Container and C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                snap[info.itemID] = (snap[info.itemID] or 0) + info.stackCount
            end
        end
    end
    return snap
end

local function DetectUsedItem()
    if not db or not db.char then return end
    local newSnap = SnapshotBags()
    for itemID, oldCount in pairs(lastBagSnapshot) do
        local newCount = newSnap[itemID] or 0
        if newCount < oldCount then
            TrackItemUse(itemID)
        end
    end
    lastBagSnapshot = newSnap
end

local bagTrackFrame = CreateFrame("Frame")
bagTrackFrame:RegisterEvent("BAG_UPDATE_DELAYED")
bagTrackFrame:RegisterEvent("PLAYER_LOGIN")
bagTrackFrame:SetScript("OnEvent", function(_, ev)
    if ev == "PLAYER_LOGIN" then
        C_Timer.After(1, function() lastBagSnapshot = SnapshotBags() end)
    elseif ev == "BAG_UPDATE_DELAYED" then
        DetectUsedItem()
    end
end)

mainFrame:RegisterEvent("PLAYER_LOGIN")
mainFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
mainFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
mainFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
mainFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
mainFrame:RegisterEvent("SPELLS_CHANGED")
mainFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
mainFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
mainFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
mainFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
mainFrame:RegisterUnitEvent("UNIT_AURA", "player")
mainFrame:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
mainFrame:RegisterEvent("CHALLENGE_MODE_START")
mainFrame:RegisterEvent("CHALLENGE_MODE_COMPLETED")
mainFrame:RegisterEvent("CHALLENGE_MODE_RESET")
mainFrame:RegisterEvent("BAG_UPDATE_DELAYED")
mainFrame:RegisterEvent("WEAPON_ENCHANT_CHANGED")
mainFrame:RegisterUnitEvent("UNIT_ENTERED_VEHICLE", "player")
mainFrame:RegisterUnitEvent("UNIT_EXITED_VEHICLE", "player")
mainFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

-------------------------------------------------------------------------------
--  /kuiar debug prints full diagnostic state to chat
-------------------------------------------------------------------------------
SLASH_KUIARDEBUG1 = "/kuiardebug"
SlashCmdList["KUIARDEBUG"] = function()

    local accentHex = string.format("%02x%02x%02x", (KT.C_R or 1) * 255, (KT.C_G or 0) * 255, (KT.C_B or 0.3333) * 255)
    local p = function(...) print("|cff" .. accentHex .. "[KUI AuraReminders Debug]|r", ...) end
    p("--- Aura Reminders Debug ---")

    if not db then p("|cffff4444db is nil PLAYER_LOGIN never fired or AceDB failed|r"); return end

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

    p("Class:", playerClass, "| Spec:", specID, "(" .. specName .. ")")
    p("InInstance:", tostring(inInstance), "| InKeystone:", tostring(inKeystone), "| InCombat:", tostring(inCombat))
    p("InGroup:", tostring(inGroup), "| InRaid:", tostring(inRaid))
    p("Options panel visible:", tostring(optionsPanelVisible))
    p("iconAnchor:", iconAnchor and "exists" or "|cffff4444NIL|r",
      iconAnchor and ("shown=" .. tostring(iconAnchor:IsShown())) or "")
    p("Active icons:", #activeIcons)
    p("Combat icons:", #combatActiveIcons)

    -- Raid Buffs
    local rb = db.profile.raidBuffs
    p("--- Raid Buffs ---")
    p("  showNonInstanced:", tostring(rb.showNonInstanced), "| showOthersMissing:", tostring(rb.showOthersMissing))
    local rbActive = inInstance or rb.showNonInstanced
    p("  Category active (inInstance or showNonInstanced):", tostring(rbActive))
    if rbActive then
        for _, buff in ipairs(RAID_BUFFS) do
            local enabled = rb.enabled[buff.key]
            local classMatch = buff.class == playerClass
            local known = Known(buff.castSpell)
            local status = ""
            if not enabled then status = "DISABLED"
            elseif not classMatch then status = "wrong class (" .. buff.class .. ")"
            elseif not known then status = "spell not known"
            else
                local isMissing
                if rb.showOthersMissing and (inGroup or inRaid) then
                    isMissing = AnyGroupMemberMissingBuff(buff.buffIDs)
                else
                    isMissing = not PlayerHasAuraByID(buff.buffIDs)
                end
                status = isMissing and "|cffff4444MISSING|r" or "buff present"
            end
            p("  " .. buff.key .. " (" .. buff.name .. "): " .. status)
        end
    end

    -- Auras
    local au = db.profile.auras
    p("--- Auras ---")
    p("  showNonInstanced:", tostring(au.showNonInstanced))
    local auActive = inInstance or au.showNonInstanced
    p("  Category active:", tostring(auActive))
    if auActive then
        for _, aura in ipairs(AURAS) do
            local enabled = au.enabled[aura.key]
            local classMatch = aura.class == playerClass
            local known = Known(aura.castSpell)
            local specOk = true
            if aura.specs then
                specOk = false
                for _, s in ipairs(aura.specs) do if s == specID then specOk = true; break end end
            end
            local status = ""
            if not enabled then status = "DISABLED"
            elseif not classMatch then status = "wrong class (" .. aura.class .. ")"
            elseif not known then status = "spell not known"
            elseif not specOk then status = "wrong spec"
            elseif aura.requireInstanceGroup and (not inInstance or not (inGroup or inRaid)) then status = "skipped (requireInstanceGroup: not in instance+group)"
            elseif inCombat and not aura.combatOk then status = "skipped (in combat, not combatOk)"
            else
                local isMissing
                if aura.check == "mineOnRaid" then
                    if inCombat then
                        status = "skipped (in combat, mineOnRaid can't check others)"
                    else
                        isMissing = not BuffExistsOnAnyGroupMember(aura.buffIDs)
                        if not (inGroup or inRaid) then isMissing = false; status = "not in group"; end
                    end
                elseif aura.check == "ownOnRaid" then
                    if inCombat then
                        local cached = _preCombatOwnOnRaidCache[aura.buffIDs[1]]
                        isMissing = (cached == false)
                        status = "ownOnRaid (combat snapshot: " .. tostring(cached) .. ")"
                    else
                        isMissing = not PlayerOwnBuffOnAnyGroupMember(aura.buffIDs)
                    end
                    if not (inGroup or inRaid) then isMissing = false; status = "not in group"; end
                elseif aura.check == "playerSelfCast" then
                    isMissing = not PlayerHasSelfCastAuraByID(aura.buffIDs)
                end
                if status == "" then
                    if aura.check ~= "mineOnRaid" and aura.check ~= "ownOnRaid" and aura.check ~= "playerSelfCast" then
                        isMissing = not PlayerHasAuraByID(checkIDs)
                    end
                    status = isMissing and "|cffff4444MISSING should show icon|r" or "buff present"
                end
            end
            p("  " .. aura.key .. " (" .. aura.name .. "): " .. status)
        end
    end

    -- Consumables
    local co = db.profile.consumables
    p("--- Consumables ---")
    p("  inKeystone:", tostring(inKeystone), "| inInstance:", tostring(inInstance))
    p("  showSpecialsNonInstanced:", tostring(co.showSpecialsNonInstanced))
    local specialsActive = inInstance or co.showSpecialsNonInstanced
    local coActive = not inKeystone
    p("  Category active (not inKeystone):", tostring(coActive), "| Specials active:", tostring(specialsActive))
    if coActive and not inCombat then
        if playerClass == "ROGUE" then
            for _, poison in ipairs(ROGUE_POISONS) do
                local enabled = co.enabled[poison.key]
                local known = Known(poison.castSpell)
                local has = PlayerHasAuraByID(poison.buffIDs)
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
        p("  MH enchant present:", tostring(hasMH))
    elseif inCombat then
        p("  (skipped in combat)")
    end

    p("--- End Debug ---")
end

-------------------------------------------------------------------------------
--  /kuiarcombat targeted combat aura API debug
--  Run this IN COMBAT with Devotion Aura active to diagnose the issue.
-------------------------------------------------------------------------------
SLASH_KUIARCOMBAT1 = "/kuiarcombat"
SlashCmdList["KUIARCOMBAT"] = function()
    local p = function(...) print("|cffff9900[KUIAR Combat]|r", ...) end
    p("--- Combat Aura Debug ---")
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

    p("--- Icon counts ---")
    p("  activeIcons:", #activeIcons, "combatActiveIcons:", #combatActiveIcons)
    p("  NON_SECRET_SPELL_IDS[465]:", tostring(NON_SECRET_SPELL_IDS[465]))

    p("--- End Combat Debug ---")
end

-------------------------------------------------------------------------------
--  /kuiarlog toggle live UNIT_AURA payload logging during combat
-------------------------------------------------------------------------------
SLASH_KUIARLOG1 = "/kuiarlog"
SlashCmdList["KUIARLOG"] = function()
    _kuiarLogEnabled = not _kuiarLogEnabled
    print("|cffff9900[KUIAR]|r Combat aura logging " .. (_kuiarLogEnabled and "|cff00ff00ON|r" or "|cffff4444OFF|r"))
end

-------------------------------------------------------------------------------
--  /beacondebug standalone beacon system diagnostics
-------------------------------------------------------------------------------
SLASH_BEACONDEBUG1 = "/beacondebug"
SlashCmdList["BEACONDEBUG"] = function()
    local p = function(...) print("|cffffcc00[Beacon Debug]|r", ...) end
    p("--- Beacon Reminder Debug ---")
    p("isPaladin:", tostring(_beaconIsPaladin))
    p("db:", db and "exists" or "|cffff4444NIL|r")
    p("IsSpellOverlayed:", IsSpellOverlayed and "exists" or "|cffff4444NIL|r")
    p("cachedInInstance:", tostring(_beaconCachedInInstance))
    p("overlayEventsRegistered:", tostring(_beaconOverlayRegistered))
    p("beaconAnchor:", _beaconAnchor and "exists" or "|cffff4444NIL|r")
    p("InGroup:", tostring(IsInGroup()), "InRaid:", tostring(IsInRaid()))
    p("InCombat:", tostring(InCombatLockdown()))

    local _, iType, diffID = GetInstanceInfo()
    p("InstanceType:", tostring(iType), "DifficultyID:", tostring(diffID))

    local au = db and db.profile.auras
    local enabled = au and au.enabled
    p("auras.enabled.bol:", tostring(enabled and enabled.bol))
    p("auras.enabled.bof:", tostring(enabled and enabled.bof))

    p("Known(BOL 53563):", tostring(Known(BEACON_BOL)))
    p("Known(BOF 156910):", tostring(Known(BEACON_BOF)))
    p("Known(Virtue 200025):", tostring(Known(BEACON_VIRTUE)))

    if IsSpellOverlayed then
        local bolOverlay = IsSpellOverlayed(BEACON_BOL)
        local bofOverlay = IsSpellOverlayed(BEACON_BOF)
        p("IsSpellOverlayed(BOL):", tostring(bolOverlay))
        p("IsSpellOverlayed(BOF):", tostring(bofOverlay))
    else
        p("|cffff4444IsSpellOverlayed function not available|r")
    end

    p("iconState[BOL]:", tostring(_beaconIconState[BEACON_BOL]))
    p("iconState[BOF]:", tostring(_beaconIconState[BEACON_BOF]))
    p("icon frames: BOL=", _beaconIcons[BEACON_BOL] and "exists" or "NIL",
      "BOF=", _beaconIcons[BEACON_BOF] and "exists" or "NIL")

    p("--- End Beacon Debug ---")
end
