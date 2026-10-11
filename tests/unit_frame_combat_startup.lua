local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua"))
local source=f:read("*a");f:close()
local first=assert(source:find("function ns.QueueUnitFrameLayoutRefresh()",1,true))
local last=assert(source:find("function Mod:OnEnable()",first,true))
local ns,logged,combat={},false,false
local mod={enabled=true,starts=0,refreshes=0,profile="initial"}
function mod:IsEnabled() return self.enabled end
function mod:OnEnable() self.starts=self.starts+1;self.appliedProfile=self.profile end
function mod:Refresh() self.refreshes=self.refreshes+1;self.appliedProfile=self.profile end
local env=setmetatable({ns=ns,Mod=mod,KT={},
 IsLoggedIn=function() return logged end,InCombatLockdown=function() return combat end,
 CreateFrame=function()
  local frame={events={}}
  function frame:RegisterEvent(e) self.events[e]=true end
  function frame:UnregisterEvent(e) self.events[e]=nil end
  function frame:UnregisterAllEvents() self.events={} end
  function frame:SetScript(_,fn) self.OnEvent=fn end
  return frame
 end},{__index=_G})
local chunk=assert(loadstring(source:sub(first,last-1)));setfenv(chunk,env);chunk()
assert(ns.DeferUnitFrameStartup() and mod.starts==0)
logged=true;combat=true
ns._startupLayoutWaiter:OnEvent("PLAYER_ENTERING_WORLD")
assert(ns._startupLayoutPending and mod.starts==0,"combat reload must never spawn displaced protected frames")
ns.DeferUnitFrameStartup();mod.profile="persisted latest"
combat=false;ns._startupLayoutWaiter:OnEvent("PLAYER_REGEN_ENABLED")
assert(mod.starts==1 and mod.appliedProfile=="persisted latest" and not ns._startupLayoutPending)
assert(next(ns._startupLayoutWaiter.events)==nil)
assert(not ns.DeferUnitFrameStartup(),"normal enable after login starts immediately")
combat=true;ns.QueueUnitFrameLayoutRefresh();ns.QueueUnitFrameLayoutRefresh()
assert(ns._layoutRestorePending)
ns._layoutRestoreWaiter:OnEvent("PLAYER_REGEN_ENABLED");assert(mod.refreshes==0)
mod.profile="profile changed in combat";combat=false
ns._layoutRestoreWaiter:OnEvent("PLAYER_REGEN_ENABLED")
assert(mod.refreshes==1 and mod.appliedProfile==mod.profile and not ns._layoutRestorePending)
combat=true;ns.DeferUnitFrameStartup();mod.enabled=false;combat=false
ns._startupLayoutWaiter:OnEvent("PLAYER_REGEN_ENABLED");assert(mod.starts==1)
print("PASS: world-ready startup, combat reload deferral, latest profile restoration, coalescing and disable")
