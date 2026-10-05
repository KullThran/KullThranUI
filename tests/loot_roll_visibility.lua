local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI/Modules/Enhancements/Enhancements.lua"))
local source = f:read("*a"); f:close()
local now, queued, opened = 100, {}, 0
local profile = { enable = true, visibility = { hideAlerts = true } }
local env = setmetatable({ KT = { db = { profile = { enhancements = profile } } },
    GetTime = function() return now end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end end,
    C_Timer = { After = function(_, fn) queued[#queued+1] = fn end },
    CreateFrame = function() return { RegisterEvent = function() end, SetScript = function(self, _, fn) self.event = fn end } end,
    RollOnLoot = function() error("visibility recovery must never choose a roll") end }, { __index = _G })
env._G = env
local first = assert(source:find("local LootRollGuard =", 1, true))
local last = assert(source:find("local function LText", first, true))
local fn = assert(loadstring(source:sub(first, last - 1) .. " return LootRollGuard, ShouldHideAlerts"))
setfenv(fn, env)
local guard, shouldHide = fn()
local function frame()
    return { shown = false, alpha = 0, Show = function(self) self.shown = true end,
        SetAlpha = function(self, value) self.alpha = value end, IsShown = function(self) return self.shown end }
end
env.AlertFrame = frame(); env.GroupLootContainer = frame(); env.GroupLootContainer.rollFrames = {}
local pending = {}
env.GetLootRollTimeLeft = function(id) return pending[id] or 0 end
assert(shouldHide(profile), "ordinary alerts still respect the setting")
-- Native first-show ordering: START happens before a native frame exists.
pending[11] = 60000
guard.events.event(nil, "START_LOOT_ROLL", 11, 60000)
assert(not shouldHide(profile), "pending roll protects AlertFrame before frame creation")
env.GroupLootContainer_AddRoll = function(id, duration)
    opened = opened + 1
    local r = frame(); r.rollID = id; r.rollTime = duration
    env.GroupLootFrame1 = r; env.GroupLootContainer.rollFrames[1] = r
end
local function drain() local callbacks=queued; queued={}; for _,cb in ipairs(callbacks) do cb() end end
drain()
assert(opened == 1, "missing native roll recovered once, not duplicated by retries")
assert(env.AlertFrame.shown and env.AlertFrame.alpha == 1)
assert(env.GroupLootContainer.shown and env.GroupLootContainer.alpha == 1)
assert(env.GroupLootFrame1.shown and env.GroupLootFrame1.alpha == 1, "roll restored with normal native handlers")
-- A submitted choice can remove the UI while the server timer still runs.
env.GroupLootContainer.rollFrames = {}; env.GroupLootFrame1 = nil
guard:Restore(); assert(opened == 1, "a presented roll cannot be recreated after a user choice")
-- Cancellation before deferred recovery must not resurrect expired items.
env.GroupLootContainer.rollFrames = {}; env.GroupLootFrame1 = nil
pending[12] = 10000; guard.events.event(nil, "START_LOOT_ROLL", 12, 10000)
guard.events.event(nil, "CANCEL_ALL_LOOT_ROLLS"); pending[12] = 0; drain()
assert(opened == 1); assert(shouldHide(profile))
-- A completed/expired timer cannot recreate a missing roll.
pending[13] = 10000; guard.events.event(nil, "START_LOOT_ROLL", 13, 10000)
now = 111; pending[13] = 0; drain(); assert(opened == 1)
assert(shouldHide(profile), "normal filtering resumes once the pending deadline expires")
-- Disabling the feature leaves replacement loot addons untouched.
profile.visibility.hideAlerts = false
pending[14] = 10000; guard.events.event(nil, "START_LOOT_ROLL", 14, 10000); drain()
assert(opened == 1)
profile.visibility.hideAlerts = true; profile.enable = false
pending[15] = 10000; guard.events.event(nil, "START_LOOT_ROLL", 15, 10000); drain()
assert(opened == 1)
print("loot_roll_visibility: bootstrap, visibility, cancellation and no automatic roll passed")
