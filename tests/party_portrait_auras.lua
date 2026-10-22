local root = arg[1] or "."

-- Minimal frame stub: every method exists and returns the frame, numbers for geometry.
local function Stub(extra)
    local f = setmetatable({}, { __index = function(t, k)
        return function(self, ...) return self end
    end })
    f.GetWidth = function() return 60 end
    f.GetHeight = function() return 60 end
    f.GetFrameLevel = function(self) return self._level or 10 end
    f.SetFrameLevel = function(self, level) self._level = level end
    f.CreateTexture = function() return Stub() end
    f.CreateMaskTexture = function() return Stub() end
    for k, v in pairs(extra or {}) do f[k] = v end
    return f
end
function CreateFrame() return Stub() end
local KT = { db = { profile = {} } }
_G.KullThranUI = KT
LibStub = function() return { GetAddon = function() return KT end } end
AuraContainerSortMethod = { ExpirationOnly = 1 }
AuraContainerSortDirection = { Reverse = 1 }
local unitState = {
    party1 = { exists = true, assist = true },
    party2 = { exists = true, assist = true },
    arena1 = { exists = true, assist = false },
}
function UnitExists(u) return unitState[u] and unitState[u].exists end
function UnitCanAssist(_, u) return unitState[u].assist end
function UnitIsVisible() return true end
function issecretvalue() return false end
function GetTime() return 100 end
C_Spell = { DoesSpellExist = function(id) return id == 118 or id == 2094 or id == 207777 end }
local tickers = 0
C_Timer = { NewTicker = function() tickers = tickers + 1; return { Cancel = function() tickers = tickers - 1 end } end }

-- AuraKit: the real build is staged through a queue, one job step per tick.
local containers = {}
local AK = { styles = {} }
function AK.RestyleSoon() end
function AK.QueueBuildJob(fn)
    while fn() == "again" do end
end
function AK.CreateContainerShell(parent, spec)
    local rec = { enabled = {}, filters = {}, units = {}, updates = 0, slots = {} }
    containers[#containers + 1] = rec
    local c = Stub({
        SetUnit = function(_, unit) rec.unit = unit; rec.units[#rec.units + 1] = unit end,
        SetAuraSlotEnabled = function(_, key, on) rec.enabled[key] = on end,
        SetAuraSlotCandidateFilters = function(_, key, filters) rec.filters[key] = filters end,
        SetEnabled = function(_, on) rec.containerEnabled = on end,
        SetShown = function(_, on) rec.shown = on end,
        UpdateAllAuras = function() rec.updates = rec.updates + 1 end,
    })
    rec.container = c
    return c
end
function AK.AddSlotToContainer(container, slot)
    local rec
    for _, r in ipairs(containers) do if r.container == container then rec = r end end
    rec.slots[#rec.slots + 1] = slot
    slot.extraInit(Stub(), { icon = Stub(), cooldown = Stub() })
end
function AK.FinishContainer(container, unit)
    for _, r in ipairs(containers) do
        if r.container == container then r.unit = unit; r.finished = true end
    end
end
_G.KTAuraKit = AK

local ns = { PF_Portrait = {
    SyncLevels = function() end,
    media = "media\\",
    Point = function(region, ...) region:SetPoint(...) end,
} }
assert(loadfile(root .. "/KullThranUI/Modules/PortraitAuraCatalog.lua"))("test", ns)
assert(loadfile(root .. "/KullThranUI/Modules/PortraitAuraShared.lua"))("test", ns)
assert(loadfile(root .. "/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames_PortraitAuras.lua"))("test", ns)
local M = ns.PF_PortraitAuras
assert(M, "module loads")

local function NewFrame(mode, unit)
    -- a plain table: the module stores its host in a field, which a stub would answer for
    return ({
        mode = mode, unit = unit, portraitFrame = Stub(), portraitMask = Stub(),
        _portraitMaskAdded = true, _portraitCircular = true,
        GetName = function() return "frame" .. tostring(mode) .. tostring(unit) end,
    })
end
local function slotKeys(rec)
    local keys = {}
    for _, s in ipairs(rec.slots) do keys[#keys + 1] = s.key end
    return table.concat(keys, ",")
end

-- Off by default: nothing is built.
local db = {}
local f1 = NewFrame("party", "party1")
M.Sync(f1, db, true)
assert(#containers == 0 and not f1._ktPortraitAuras, "disabled builds nothing")

-- On, portrait hidden: still nothing.
db.portraitAurasEnabled = true
M.Sync(f1, db, false)
assert(#containers == 0, "no portrait, no host")

-- On with a portrait: a host with the assistable tiers only, bound to the frame's unit.
M.Sync(f1, db, true)
assert(#containers == 1 and containers[1].finished, "host is built")
assert(slotKeys(containers[1]) == "Important,ExtDef,BigDef,CC", "party frames have no disarm slot: " .. slotKeys(containers[1]))
assert(containers[1].unit == "party1", "container reads the frame unit")
assert(containers[1].enabled.Important == false, "important is off by default")
assert(containers[1].enabled.CC ~= false and containers[1].shown == true, "crowd control shows")
assert(M.LevelGap(f1) == 7, "levels are reserved while on")

-- Frame recycling: the host follows the new unit.
f1.unit = "party2"
M.Bind(f1, "party2")
assert(containers[1].unit == "party2", "container follows the recycled frame")
local updates = containers[1].updates
f1.unit = nil
M.Bind(f1, nil)
assert(containers[1].unit == "none", "empty frame unbinds")
f1.unit = "party1"
M.Bind(f1, "party1")
assert(containers[1].unit == "party1" and containers[1].updates > updates, "frame back on a unit")

-- Out of range: unbound until the frame binds again.
M.Unbind(f1)
assert(containers[1].unit == "none", "out of range unbinds")
M.Sync(f1, db, true)
assert(containers[1].unit == "none", "a repaint does not rebind an out-of-range unit")
M.Bind(f1, "party1")
assert(containers[1].unit == "party1", "back in range rebinds")

-- Category switches and style follow the mode table.
db.portraitAurasImportant = true
db.portraitAurasCC = false
M.Sync(f1, db, true)
assert(containers[1].enabled.Important == true and containers[1].enabled.CC == false, "category switches")
db.portraitAurasNumbers = false
db.portraitAurasReverse = false
db.portraitAurasFontScale = 2
M.Sync(f1, db, true)
local style = AK.styles["ktpf:portrait:frameparty" .. "party2"] or AK.styles["ktpf:portrait:frameparty" .. "party1"]
assert(style and style.hideDurationText == true and style.cooldownReverse == false, "style follows the switches")
assert(style.durationFontSize == 36, "timer scales with the portrait: " .. tostring(style.durationFontSize))

-- Portrait turned off: container hidden, levels released.
M.Sync(f1, db, false)
assert(containers[1].shown == false and containers[1].containerEnabled == false, "hidden with the portrait")
assert(M.LevelGap(f1) == 0, "levels released")
M.Sync(f1, db, true)
assert(containers[1].shown == true, "back with the portrait")

-- Enemy arena frames keep the spell-id tiers.
db.portraitAurasCC = true
local arena = NewFrame("arenaEnemy", "arena1")
M.Sync(arena, db, true)
assert(slotKeys(containers[2]) == "Important,ExtDef,BigDef,Disarm,OtherCC,CC", "arena enemies get every tier: " .. slotKeys(containers[2]))
assert(containers[2].enabled.Disarm ~= false, "disarm on for an enemy")
unitState.arena1.assist = true
M.Sync(arena, db, true)
assert(containers[2].enabled.Disarm == false, "disarm off on a friendly unit")
unitState.arena1.assist = false
db.portraitAurasSpells = "999001"
M.Sync(arena, db, true)
assert(containers[2].filters.OtherCC.includeSpellIDs[999001], "custom ids reach the crowd control slot")

-- Test frames: a preview icon, no unit.
local test = NewFrame("party", nil)
test.fakeUnit = { fake = true }
M.Sync(test, db, true)
local host = test._ktPortraitAuras
assert(host and host.preview and #containers == 3, "test frame builds a host")
assert(containers[3].unit == "none", "test frame reads no unit")
assert(tickers == 1, "preview ticker runs")
db.portraitAurasEnabled = false
M.Sync(test, db, true)
assert(tickers == 0, "preview ticker stops")

-- Placement: the icon, its mask and its swipe cover what shows of the portrait.
local function Recorder()
    local rec = { points = {} }
    rec.stub = Stub({
        ClearAllPoints = function(self) rec.points = {}; return self end,
        SetPoint = function(self, ...) rec.points[#rec.points + 1] = { ... }; return self end,
        SetAllPoints = function(self, target) rec.points = { { "ALL", target } }; return self end,
        SetSize = function(self, w, h) rec.w, rec.h = w, h; return self end,
        SetTexture = function(self, path) rec.texture = path; return self end,
        SetSwipeTexture = function(self, path) rec.swipe = path; return self end,
        AddMaskTexture = function(self, mask) rec.mask = mask; return self end,
        RemoveMaskTexture = function(self, mask) if rec.mask == mask then rec.mask = nil end; return self end,
    })
    return rec
end
db.portraitAurasEnabled = true
local placed = NewFrame("party", "party1")
local made = {}
local savedCreate = CreateFrame
CreateFrame = function()
    local r = Recorder()
    r.stub.CreateMaskTexture = function()
        local m = Recorder(); made.mask = m; return m.stub
    end
    made.root = made.root or r
    return r.stub
end
M.Sync(placed, db, true)
CreateFrame = savedCreate
local pHost = placed._ktPortraitAuras
local icon, cooldown = Recorder(), Recorder()
pHost.icons[#pHost.icons + 1] = icon.stub
pHost.cooldowns[#pHost.cooldowns + 1] = cooldown.stub
pHost.maskSeated = nil

-- KUI circular portrait: the 1px inset rect of frame.portraitMask, its shape for icon and swipe.
placed._portraitMaskPath = "media\\circle_mask.tga"
M.Place(placed)
assert(made.root.points[1][1] == "TOPLEFT" and made.root.points[1][4] == 1, "KUI: same inset as the portrait mask")
assert(made.mask.texture == "media\\circle_mask.tga", "KUI: mask follows the portrait shape")
assert(icon.mask == made.mask.stub, "KUI: icon masked")
assert(cooldown.swipe == "media\\circle_mask.tga", "KUI: swipe has the icon's shape, not a bigger disc")

-- Detached portraits keep their own shape.
placed._portraitMaskPath = "media\\portrait_mask.tga"
M.Place(placed)
assert(made.mask.texture == "media\\portrait_mask.tga" and cooldown.swipe == "media\\portrait_mask.tga", "detached shape")

-- Square portraits: whole frame, no mask, square swipe.
placed._portraitMaskAdded = false
M.Place(placed)
assert(made.root.points[1][4] == 0 and icon.mask == nil, "square: no mask")
assert(cooldown.swipe == "Interface\\Buttons\\WHITE8X8", "square swipe")

-- Native card (Forever): the 60px frame overscans a 36px hole by 12px a side; the icon is a
-- circle a little smaller than the hole, centred, not the whole overscanned frame.
placed._portraitMaskAdded = true
placed._pfNativeStyle, placed._pfNativePad = "forever", 12
M.Place(placed)
local circle = made.root.w * 102 / 128
assert(made.root.points[1][1] == "CENTER", "native: centred on the portrait")
assert(circle < 36 and circle > 32, "native: circle fits the hole: " .. circle)
assert(made.mask.texture == "media\\circle_mask.tga" and cooldown.swipe == "media\\circle_mask.tga", "native: round")
-- Native card (Retail): the frame is the ring opening, the icon matches the portrait circle.
placed._pfNativeStyle, placed._pfNativePad = "retail", 5.7
M.Place(placed)
circle = made.root.w * 102 / 128
assert(circle <= 60 * 102 / 128 + 1e-6 and circle > 44, "retail: circle within the portrait: " .. circle)

print("party_portrait_auras: ok")
