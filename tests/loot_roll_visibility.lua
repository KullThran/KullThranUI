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
-- Interactive roll recovery must work with ordinary alerts enabled and with
-- cosmetic Enhancements disabled. Neither option is a loot replacement.
profile.visibility.hideAlerts = false
pending[14] = 10000; guard.events.event(nil, "START_LOOT_ROLL", 14, 10000); drain()
assert(opened == 2, "default alert settings cannot disable native roll recovery")
profile.visibility.hideAlerts = true; profile.enable = false
pending[15] = 10000; guard.events.event(nil, "START_LOOT_ROLL", 15, 10000); drain()
assert(opened == 3, "cosmetic module toggle cannot lose an interactive prompt")
env.InputUtil = { IsGamepadUIEnabled = function() return true end }
pending[16] = 10000; guard.events.event(nil, "START_LOOT_ROLL", 16, 10000); drain()
assert(opened == 3, "gamepad loot controller keeps ownership")
guard.events.event(nil, "CANCEL_LOOT_ROLL", 16); pending[16]=0
env.InputUtil = nil
-- More than four drops are queued once, preserving Blizzard's queue.
env.GroupLootContainer.waitingRolls = {}
env.GroupLootContainer_AddRoll = function(id, duration)
    opened = opened + 1
    table.insert(env.GroupLootContainer.waitingRolls, { rollID=id, rollTime=duration })
end
pending[17] = 10000; guard.events.event(nil, "START_LOOT_ROLL", 17, 10000); drain()
assert(opened == 4 and #env.GroupLootContainer.waitingRolls == 1, "no duplicate waiting rolls")
-- A cold item cache must not consume the one-time presentation marker.
local cached, requests = false, 0
env.GetLootRollItemInfo = function() return "icon", cached and "Item" or nil end
env.GetLootRollItemLink = function() return "item:123" end
env.GetItemInfoInstant = function() return 123 end
env.C_Item = { RequestLoadItemDataByID=function(id) assert(id==123);requests=requests+1 end }
pending[18]=10000;guard.events.event(nil,"START_LOOT_ROLL",18,10000);drain()
assert(opened==4 and not guard.presented[18] and requests==1, "cold cache waits without marking shown")
env.GroupLootContainer_AddRoll = function(id,duration)
 opened=opened+1;local r=frame();r.rollID=id;env.GroupLootFrame1=r;env.GroupLootContainer.rollFrames={r}
end
cached=true;guard.events.event(nil,"GET_ITEM_INFO_RECEIVED",123,true);drain()
assert(opened==5 and guard.presented[18], "item cache event opens the pending roll without reload")
-- Native OnShow can remove a frame even with cached item info. That attempt
-- must remain retryable; the presence of a stale rollID is not success.
local rejects=true
env.GroupLootContainer_AddRoll=function(id,duration)
 opened=opened+1;local r=frame();r.rollID=id
 r.Show=function(self) self.shown=not rejects;if rejects then env.GroupLootContainer.rollFrames={} end end
 env.GroupLootFrame1=r;env.GroupLootContainer.rollFrames={r}
end
pending[19]=10000;guard.events.event(nil,"START_LOOT_ROLL",19,10000);drain()
assert(not guard.presented[19], "removed OnShow is not recorded as presented")
rejects=false;guard.events.event(nil,"GET_ITEM_INFO_RECEIVED",123,true);drain()
assert(guard.presented[19], "failed first show can recover after cache notification")
-- Cache notifications must not recreate a submitted choice or cancelled roll.
local previous = opened
env.GroupLootFrame1=nil;env.GroupLootContainer.rollFrames={}
guard.events.event(nil,"GET_ITEM_INFO_RECEIVED",123,true);drain()
assert(opened==previous, "late cache update cannot reopen a presented choice")
cached=false;pending[20]=10000
guard.events.event(nil,"START_LOOT_ROLL",20,10000);drain()
guard.events.event(nil,"CANCEL_LOOT_ROLL",20);pending[20]=0
cached=true;guard.events.event(nil,"GET_ITEM_INFO_RECEIVED",123,true);drain()
assert(opened==previous and not guard.active[20], "cancel before item data cannot resurrect a roll")
-- Expired IDs are cleared even while another longer roll remains active.
cached=false;pending[21]=1000;pending[22]=60000
guard.events.event(nil,"START_LOOT_ROLL",21,1000)
guard.events.event(nil,"START_LOOT_ROLL",22,60000);drain()
now=113;pending[21]=0;guard:Restore()
assert(not guard.active[21] and guard.active[22], "expiry cleanup visits every pending roll")
guard.events.event(nil,"CANCEL_ALL_LOOT_ROLLS");drain()
assert(opened==previous, "cancel all stops deferred cache recovery")
-- Visibility flags do not imply valid screen geometry.
local r=frame()
local moves, clamps = 0, 0
r.GetRect=function() return 3000, 100, 277, 67 end
r.GetEffectiveScale=function() return 1 end
r.SetClampedToScreen=function(_,v) assert(v==false);clamps=clamps+1 end
r.ClearAllPoints=function() end
r.SetPoint=function(_,point,parent,relative,x,y) assert(point=="CENTER" and parent==env.UIParent);moves=moves+1 end
env.UIParent={GetRect=function() return 0,0,1920,1080 end,GetEffectiveScale=function() return 1 end}
guard:PrepareFrame(r)
assert(moves==1 and clamps==1, "shown but offscreen roll recovered")
r.GetRect=function() return 900,200,277,67 end
guard:PrepareFrame(r);assert(moves==1, "valid user position preserved")
r.GetRect=function() return nil,nil,277,67 end
guard:PrepareFrame(r);assert(moves==2, "unresolved anchor recovered")
r.GetRect=function() return 1000,100,277,67 end
r.GetEffectiveScale=function() return 0.5 end
guard:PrepareFrame(r);assert(moves==2, "bounds compare effective scales")
-- Native bottom manager geometry must be repaired before inspecting roll bounds.
local manager={}
local container=env.GroupLootContainer
local anchor={"TOP",manager,"TOP",0,0}
container.layoutParent=manager
container.GetParent=function() return manager end
container.GetPoint=function() return unpack(anchor) end
container.ClearAllPoints=function() anchor={} end
container.SetPoint=function(_,...) anchor={...} end
container.reservedSize=100;container.rollFrames={r}
r.GetRect=function() return 900,200,277,67 end
guard:PrepareFrame(r)
assert(anchor[1]=="BOTTOM" and anchor[2]==manager and anchor[3]=="BOTTOM", "native stack uses original lower origin")
assert(moves==2, "container repair preserves native roll slot")
anchor={"TOP",manager,"TOP",12,-40};container.ignoreFramePositionManager=true
guard:PrepareFrame(r)
assert(anchor[1]=="TOP" and anchor[4]==12, "custom mover container position preserved")
container.ignoreFramePositionManager=nil
r.GetRect=function() return 900,3000,277,67 end
r.SetPoint=function(_,point,parent,relative,x,y)
 assert(point=="CENTER" and parent==container and relative=="BOTTOM" and y==50)
 moves=moves+1
end
guard:PrepareFrame(r)
assert(moves==3, "invalid roll returns to native slot rather than arbitrary screen center")
print("loot_roll_visibility: default settings, bootstrap, queue, viewport, cancellation and no automatic roll passed")
