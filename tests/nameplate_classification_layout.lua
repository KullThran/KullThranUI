local root = arg[1] or "."
local function read(path)
    local f = assert(io.open(root .. "/" .. path)); local s = f:read("*a"); f:close(); return s
end
local source = read("KullThranUI_Nameplates/Modules/Nameplates/Nameplates.lua")
local skin = read("KullThranUI_Nameplates/Modules/Nameplates/Nameplates_ThemeSkin.lua")
local ns, theme = {}, "kui"
local db = { classificationXOffset = 0, classificationYOffset = 0, toprightSlotXOffset = 77 }
local env = setmetatable({ ns = ns, db = db, defaults = { topleftSlotSize = 36, rareEliteIconSize = 36 },
    RenderedTheme = function() return theme end,
    PP = { Point = function(region, ...) region.point = {...} end },
    UseDynamicNameplateLevelLayout = function() return false end,
    AnchorPlateAdornment = function() return true end,
}, { __index = _G })
local function section(s, first, last)
    local a = assert(s:find(first, 1, true)); local b = assert(s:find(last, a, true))
    local fn = assert(loadstring(s:sub(a, b-1))); setfenv(fn, env); fn()
end
section(skin, "function ns.ThemeLateralExtent(plate)", "-- Refresh the quest icons")
section(source, "local function AnchorClassificationAdornment", "local function GetTopNameReservedWidth")
ns._AuraLayout = {}
section(source, "function ns._AuraLayout.ResolveOffsets(slotKey)", "local GetTopTextVerticalLift")
local function region(w,h)
    return { IsShown = function(self) return self.shown ~= false end,
        GetWidth = function() return w end, GetHeight = function() return h end,
        ClearAllPoints = function() end }
end
local plate = { health = region(200,16) }
local icon = region(20,20); icon.GetParent = function() return plate end
for _, t in ipairs({ "kui", "retail", "classic", "forever" }) do
    theme = t
    plate._fvBadge = t == "forever" and region(24,24) or nil
    plate._clBadge = t == "classic" and region(34,20) or nil
    for _, width in ipairs({ 100, 200, 285 }) do
        plate.health = region(width,16)
        local x,y = ns._AuraLayout.ResolveOffsets("classification")
        ns.AnchorClassificationAdornment(icon, "topright", x, y, 0)
        assert(icon.point[1] == "CENTER" and icon.point[2] == plate.health and icon.point[3] == "TOPRIGHT")
        assert(icon.point[4] == 2 and icon.point[5] == 2, t .. " visual corner")
        ns.AnchorClassificationAdornment(icon, "topright", -10, 7, 5, plate)
        assert(icon.point[4] == -8 and icon.point[5] == 9, "preview/manual offsets")
    end
end
db.classificationXOffset = -23; db.classificationYOffset = 14
local x,y = ns._AuraLayout.ResolveOffsets("classification")
assert(x == -23 and y == 14, "classification owns its offsets")
-- Execute the migration twice: preserve an occupied corner and later user choices.
local a = assert(source:find("    if not KullThranUINameplatesDB._classificationSizeMigrated_v2 then",1,true))
local b = assert(source:find("    for k, v in pairs(defaults) do",a,true))
local migrate = assert(loadstring(source:sub(a,b-1))); setfenv(migrate,env)
env.KullThranUINameplatesDB = { classificationSlot = "topleft", buffSlot = "topright" }
migrate(); assert(env.KullThranUINameplatesDB.classificationSlot == "topright")
assert(env.KullThranUINameplatesDB.rareEliteIconSize == 36, "original default size preserved")
assert(env.KullThranUINameplatesDB.buffSlot == "topleft", "occupied slot retained")
env.KullThranUINameplatesDB.classificationSlot = "left"; migrate()
assert(env.KullThranUINameplatesDB.classificationSlot == "left", "user choice persists")
env.KullThranUINameplatesDB = { classificationSlot = "none" }; migrate()
assert(env.KullThranUINameplatesDB.classificationSlot == "none", "hidden indicator remains hidden")
env.KullThranUINameplatesDB = { classificationSlot = "left", leftSlotSize = 42 }
migrate(); assert(env.KullThranUINameplatesDB.rareEliteIconSize == 42, "original custom slot size preserved")
env.KullThranUINameplatesDB = { classificationSlot = "topright", _classificationCornerMigrated_v1 = true,
    rareEliteIconSize = 20, topleftSlotSize = 36 }
migrate(); assert(env.KullThranUINameplatesDB.rareEliteIconSize == 36, "repair undersized corner migration")
env.KullThranUINameplatesDB = { _classificationCornerMigrated_v1 = true, rareEliteIconSize = 45 }
migrate(); assert(env.KullThranUINameplatesDB.rareEliteIconSize == 45, "retain manual size changes")
env.KullThranUINameplatesDB.rareEliteIconSize = 32; migrate()
assert(env.KullThranUINameplatesDB.rareEliteIconSize == 32, "size migration runs once")
print("nameplate_classification_layout: ok")
