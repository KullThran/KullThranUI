local root = arg[1] or "."
local function read(path)
    local f = assert(io.open(root .. "/" .. path)); local s = f:read("*a"); f:close(); return s
end
local ns = { _AuraLayout = { MeasureLateralExtent = function() return 0, 0 end } }
local theme = "forever"
local env = setmetatable({ ns = ns, RenderedTheme = function() return theme end,
    PP = { Point = function(region, ...) region.point = {...} end } }, { __index = _G })
local function loadSection(source, first, last)
    local start = assert(source:find(first, 1, true))
    local stop = assert(source:find(last, start, true))
    local fn = assert(loadstring(source:sub(start, stop - 1))); setfenv(fn, env); fn()
end
local skin = read("KullThranUI_Nameplates/Modules/Nameplates/Nameplates_ThemeSkin.lua")
loadSection(skin, "function ns.ThemeLateralExtent(plate)", "-- Refresh the quest icons")
local source = read("KullThranUI_Nameplates/Modules/Nameplates/Nameplates.lua")
loadSection(source, "function ns._AuraLayout.CommitArrowAnchors(plate)", "-- Compatibilidad: alias legado")
local function region(w, h)
    return { shown = true, IsShown = function(self) return self.shown end,
        GetWidth = function() return w end, GetHeight = function() return h end,
        ClearAllPoints = function() end }
end
local plate = { health = region(200, 16), leftArrow = region(24, 24), rightArrow = region(24, 24), _fvBadge = region(24, 24) }
ns._AuraLayout.CommitArrowAnchors(plate)
assert(plate.rightArrow.point[4] == 38, "Forever arrow includes external badge and gap")
assert(plate.leftArrow.point[4] == -12, "frame edge included")
theme = "classic"; plate._fvBadge.shown = false; plate._clBadge = region(34, 20)
ns._AuraLayout.CommitArrowAnchors(plate)
assert(plate.rightArrow.point[4] == 32, "Classic arrow includes overlapping pill's outer edge")
plate._clBadge.shown = false; ns._AuraLayout.CommitArrowAnchors(plate)
assert(plate.rightArrow.point[4] == 12, "hidden badge releases its space")
plate.leftArrow.shown = false; plate._clBadge.shown = true; ns._AuraLayout.CommitArrowAnchors(plate)
assert(plate.rightArrow.point[4] == 32, "right-only visibility still updates")
-- Exercise the actual first-show commit, without an aura event afterwards.
env.HideTargetArrows = function() error("unexpected hide") end
ns._AcquireVisualLayer = function() end; ns.RefreshTargetIndicatorTextures = function() end
ns.SetTargetIndicatorShown = function(p) p.leftArrow.shown = true; p.rightArrow.shown = true end
local start = assert(source:find("local function CommitTargetArrows(frame, desc)", 1, true))
local stop = assert(source:find("-- Paso 3 commit: muestra u oculta los pips", start, true))
local fn = assert(loadstring(source:sub(start, stop - 1) .. " return CommitTargetArrows")); setfenv(fn, env)
plate.leftArrow.shown = false; plate.rightArrow.shown = false; plate.rightArrow.point = nil
fn()(plate, { arrowsNeeded = true })
assert(plate.rightArrow.point[4] == 32, "first target show positions both arrows immediately")
print("nameplate_arrow_layout: ok")
