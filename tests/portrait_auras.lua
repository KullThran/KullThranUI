local root = arg[1] or "."

-- Minimal frame stub: every method exists and returns the frame, numbers for geometry.
local function Stub(extra)
    local f = setmetatable({}, { __index = function(t, k)
        return function(self, ...) return self end
    end })
    f.GetWidth = function() return 60 end
    f.GetHeight = function() return 60 end
    f.GetFrameLevel = function() return 10 end
    f.CreateTexture = function() return Stub() end
    f.CreateMaskTexture = function() return Stub() end
    for k, v in pairs(extra or {}) do f[k] = v end
    return f
end
function CreateFrame() return Stub() end
local KT = { db = { profile = { unitFrames = {} } } }
LibStub = function() return { GetAddon = function() return KT end } end
AuraContainerSortMethod = { ExpirationOnly = 1 }
AuraContainerSortDirection = { Reverse = 1 }
local unitState = {
    target = { exists = true, assist = false },
    focus = { exists = true, assist = true },
    player = { exists = true, assist = true },
    pet = { exists = true, assist = true },
    targettarget = { exists = true, assist = false },
    focustarget = { exists = true, assist = true },
}
function UnitExists(u) return unitState[u] and unitState[u].exists end
function UnitCanAssist(_, u) return unitState[u].assist end
function UnitIsVisible() return true end
function issecretvalue() return false end
function GetTime() return 100 end
local existing = { [118] = true, [2094] = true, [207777] = true, [5211] = true }
local names = { [118] = "Polymorph", [12824] = "Polymorph", [2094] = "Blind", [5211] = "Bash", [207777] = "Dismantle" }
C_Spell = {
    DoesSpellExist = function(id) return existing[id] == true end,
    GetSpellName = function(id) return names[id] end,
    GetSpellTexture = function(id) return id end,
}
C_Timer = { NewTicker = function() return { Cancel = function() end } end }

local created = {}
local AK = { styles = {} }
function AK.RestyleSoon() end
function AK.CreateContainer() end
function AK.RequestContainer(parent, unit, spec, callback)
    local rec = { unit = unit, spec = spec, enabled = {}, filters = {}, shown = nil, updates = 0 }
    created[unit] = rec
    local container = Stub({
        SetAuraSlotEnabled = function(_, key, on) rec.enabled[key] = on end,
        SetAuraSlotCandidateFilters = function(_, key, filters) rec.filters[key] = filters end,
        SetEnabled = function(_, on) rec.containerEnabled = on end,
        SetShown = function(_, on) rec.shown = on end,
        UpdateAllAuras = function() rec.updates = rec.updates + 1 end,
    })
    -- the real container creates its slot buttons at once, through each slot's extraInit
    for _, slot in ipairs(spec.slots) do
        slot.extraInit(Stub(), { icon = Stub(), cooldown = Stub() })
    end
    callback(container)
end
_G.KTAuraKit = AK

local ns = { frames = {} }
for _, unit in ipairs({ "player", "target", "focus", "pet", "targettarget", "focustarget" }) do
    ns.frames[unit] = { Portrait = { backdrop = Stub({ _shapeMask = Stub(), _3d = false }) } }
end
_G.KullThranUI = KT
assert(loadfile(root .. "/KullThranUI/Modules/PortraitAuraCatalogData.lua"))("test", ns)
assert(loadfile(root .. "/KullThranUI/Modules/PortraitAuraCatalog.lua"))("test", ns)
assert(loadfile(root .. "/KullThranUI/Modules/PortraitAuraShared.lua"))("test", ns)
assert(loadfile(root .. "/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_PortraitAuras.lua"))("test", ns)
local PA = ns.PortraitAuras

-- Disabled: nothing is built.
PA.RefreshAll()
assert(next(created) == nil, "a disabled module builds no containers")

-- Enabled for every unit.
PA.SetOption("enabled", true)
PA.SetSub("units", "pet", true)
PA.SetSub("units", "targettarget", true)
PA.SetSub("units", "focustarget", true)
PA.RefreshAll()
for _, unit in ipairs({ "player", "target", "focus", "pet", "targettarget", "focustarget" }) do
    assert(created[unit], unit .. " gets a container")
end
local function slotKeys(rec)
    local keys = {}
    for _, s in ipairs(rec.spec.slots) do keys[#keys + 1] = s.key end
    return table.concat(keys, ",")
end
assert(slotKeys(created.target) == "Important,ExtDef,BigDef,Disarm,OtherCC,CC", "target stacks every category, flagged CC on top: " .. slotKeys(created.target))
assert(slotKeys(created.targettarget) == slotKeys(created.target), "target of target can show every category")
assert(created.targettarget.enabled.Disarm ~= false, "disarm is on for a hostile target of target")
unitState.focustarget.assist = false
PA.RefreshUnit("focustarget", true)
assert(created.focustarget.enabled.Disarm == true, "disarm follows the focus target hostility")
unitState.focustarget.assist = true
PA.RefreshUnit("focustarget", true)
assert(slotKeys(created.player) == "Important,ExtDef,BigDef,CC", "player has no disarm slot (always assistable)")
assert(slotKeys(created.pet) == "Important,ExtDef,BigDef,CC", "pet has no disarm slot (always assistable)")

-- Filters are the client's flags, CC drops the blacklist.
local cc = created.target.spec.slots[6]
assert(table.concat(cc.filter, "|") == "HARMFUL|CROWD_CONTROL", "CC uses the CROWD_CONTROL flag")
assert(cc.candidateFilters and cc.candidateFilters.excludeSpellIDs[1280457], "Mind Flay is not crowd control")
local ext = created.target.spec.slots[2]
assert(table.concat(ext.filter, "|") == "HELPFUL|EXTERNAL_DEFENSIVE|!BIG_DEFENSIVE", "external defensive never repeats a big defensive")

-- Spell catalog: only ids that exist on this client, per client.
local control = created.target.spec.slots[5].candidateFilters.includeSpellIDs
assert(control[118] and control[2094] and control[5211], "existing catalog ids are tracked")
assert(not control[1833] and not control[8122], "ids missing on this client drop out")
local disarm = created.target.spec.slots[4].candidateFilters.includeSpellIDs
assert(disarm[207777] and not disarm[676], "disarm catalog follows the client too")
assert(not disarm[118] and not control[207777], "disarms and control stay apart")
-- A Forever-like client: only ranked Classic ids exist.
local retailControl = PA.Catalog.Build()
existing = { [12824] = true, [10308] = true, [676] = true }
local foreverControl, foreverDisarm = PA.Catalog.Build()
assert(foreverControl[12824] and foreverControl[10308] and not foreverControl[118], "Forever keeps its own ranks")
assert(foreverDisarm[676] and not foreverDisarm[207777], "Forever disarm list")
assert(retailControl[118] and not retailControl[12824], "Retail keeps its own ids")
existing = { [118] = true, [2094] = true, [207777] = true, [5211] = true }
-- Custom ids are merged and parsed leniently.
local ids = PA.Catalog.ParseIds("999001, 999002;abc 3x")
assert(ids[999001] and ids[999002] and ids[3] and not ids[0], "custom id parsing")
PA.SetOption("customSpells", "999001, 999002")
PA.RefreshUnit("target", true)
local pushed = created.target.filters.OtherCC
assert(pushed and pushed.includeSpellIDs[999001] and pushed.includeSpellIDs[999002] and pushed.includeSpellIDs[118],
    "custom ids reach the crowd control slot without a reload")
PA.SetOption("customSpells", "")
PA.RefreshUnit("target", true)

-- Visual catalog: one entry per spell name with every id of it, and a switch per entry.
existing[12824] = true
local entries = PA.Catalog.GetEntries("incapacitate")
local poly
for _, e in ipairs(entries) do if e.name == "Polymorph" then poly = e end end
assert(poly and #poly.ids == 2 and poly.icon, "ranks of one spell share a single catalog entry")
assert(PA.Catalog.GetEntries("charm")[1] == nil, "an empty group lists nothing")
assert(PA.IsEntryEnabled(poly), "entries start enabled")
PA.SetEntryEnabled(poly, false)
local sets = PA.GetCatalogSets()
assert(not sets.control[118] and not sets.control[12824] and sets.control[2094], "a switched-off entry leaves the filter, every rank")
PA.RefreshUnit("target", true)
assert(created.target.filters.OtherCC and not created.target.filters.OtherCC.includeSpellIDs[118], "the slot filter follows the catalog switch")
PA.SetGroupEnabled("incapacitate", true)
assert(PA.GetCatalogSets().control[118], "enabling the group restores it")
existing[12824] = nil

-- Generated game data: kinds, classes, names and search.
local data = KT.PortraitAuraShared.CatalogData
local classOf = KT.PortraitAuraShared.CatalogClass
local function kindOf(id)
    for kind, list in pairs(data) do for _, v in ipairs(list) do if v == id then return kind end end end
end
assert(kindOf(1833) == "stun" and classOf[1833] == "ROGUE", "Cheap Shot is a rogue stun")
assert(kindOf(853) == "stun" and classOf[853] == "PALADIN", "Hammer of Justice is a paladin stun")
assert(kindOf(118) == "incapacitate" and classOf[118] == "MAGE", "Polymorph is a mage incapacitate")
assert(kindOf(8122) == "fear" and classOf[8122] == "PRIEST", "Psychic Scream is a priest fear")
assert(kindOf(102359) == "root", "Mass Entanglement is a root")
assert(kindOf(119381) == "stun" and classOf[119381] == "MONK", "Leg Sweep is a monk stun")
local total, seenKind = 0, {}
for kind, list in pairs(data) do
    for _, id in ipairs(list) do
        assert(type(id) == "number" and id > 0, "ids are positive numbers")
        assert(seenKind[id] == nil, "an id belongs to one kind only: " .. id)
        seenKind[id] = kind
        total = total + 1
    end
end
assert(total > 900, "the catalog is large: " .. total)
-- On a client where a handful of those ids exist the catalog lists them with names and class.
local saved = {}
for k, v in pairs(existing) do saved[k] = v end
existing = { [1833] = true, [408] = true, [118] = true, [8122] = true }
names[1833], names[408], names[8122] = "Cheap Shot", "Kidney Shot", "Psychic Scream"
PA.Catalog.ResetCache()
local kinds = PA.Catalog.GetKinds()
assert(#kinds >= 2, "kinds with spells on this client are listed")
local stun = PA.Catalog.GetEntries("stun")
local sawRogue
for _, e in ipairs(stun) do if e.name == "Cheap Shot" and e.class == "ROGUE" and e.ids[1] == 1833 then sawRogue = true end end
assert(sawRogue, "entries carry the name, ids and class")
local hits = PA.Catalog.Search("kidney")
assert(#hits == 1 and hits[1].name == "Kidney Shot", "search finds a spell by part of its name")
assert(#PA.Catalog.Search("zzz") == 0 and #PA.Catalog.Search("") == 0, "no match, no result")
existing = saved
PA.Catalog.ResetCache()

-- Category switches (defaults: important off).
assert(created.target.enabled.Important == false, "important is off by default")
assert(created.target.enabled.CC ~= false and created.target.enabled.BigDef ~= false, "cc and big defensive stay on")
assert(created.target.shown == true and created.target.containerEnabled == true, "container shows while a category is on")

-- Disarm only on a hostile unit.
assert(created.target.enabled.Disarm ~= false, "disarm is on for a hostile target")
unitState.target.assist = true
PA.RefreshUnit("target", true)
assert(created.target.enabled.Disarm == false, "disarm turns off on a friendly target")
unitState.target.assist = false
PA.RefreshUnit("target", true)
assert(created.target.enabled.Disarm == true, "disarm comes back on a hostile target")

-- A switched-off category and a switched-off unit.
PA.SetSub("categories", "crowdControl", false)
PA.RefreshUnit("target", true)
assert(created.target.enabled.CC == false, "crowd control off")
PA.SetSub("units", "focus", false)
PA.RefreshUnit("focus", true)
assert(created.focus.shown == false and created.focus.containerEnabled == false, "a unit switched off hides its container")
PA.SetSub("categories", "crowdControl", true)

-- Whole module off.
PA.SetOption("enabled", false)
PA.RefreshAll()
assert(created.target.shown == false and created.player.shown == false, "module off hides every container")
PA.SetOption("enabled", true)
PA.RefreshAll()
assert(created.target.shown == true, "module back on")

-- Style follows the options.
PA.SetOption("showNumbers", false)
PA.SetOption("reverseSwipe", false)
PA.SetOption("fontScale", 2)
PA.RefreshUnit("target", true)
local style = AK.styles["kuiuf:portrait:target"]
assert(style.hideDurationText == true and style.cooldownReverse == false, "style follows the switches")
assert(style.durationFontSize == 36, "timer text scales with the portrait and the font scale: " .. tostring(style.durationFontSize))

-- Preview.
PA.SetPreview(true)
assert(PA.IsPreviewOn(), "preview on")
PA.SetPreview(false)
assert(not PA.IsPreviewOn(), "preview off")

-- Live preview of the options page: a fake icon on the mock frames' portraits.
local mock = { portraitFrame = Stub({ IsShown = function() return true end }), portraitMask = Stub({ IsShown = function() return true end }) }
PA.ApplyPreview(mock, "player")
assert(mock._ktPortraitAuraPreview == nil, "no preview icon while the preview is off")
PA.SetPreview(true)
PA.ApplyPreview(mock, "player")
assert(mock._ktPortraitAuraPreview and mock._ktPortraitAuraPreview.preview, "the mock portrait gets the fake icon")
local totMock = { portraitFrame = Stub({ IsShown = function() return true end }) }
PA.ApplyPreview(totMock, "totPet")
assert(totMock._ktPortraitAuraPreview, "target of target maps to its own switch")
PA.SetSub("units", "targettarget", false)
local shown = true
totMock._ktPortraitAuraPreview.preview.Hide = function() shown = false end
PA.ApplyPreview(totMock, "totPet")
assert(shown == false, "a unit switched off hides its preview icon")
local hidden = { portraitFrame = Stub({ IsShown = function() return false end }) }
PA.ApplyPreview(hidden, "player")
assert(hidden._ktPortraitAuraPreview == nil, "no preview on a hidden portrait")
PA.SetPreview(false)
PA.SetSub("units", "targettarget", true)

print("portrait_auras: ok")
