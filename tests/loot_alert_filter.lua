local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI/Modules/Enhancements/Enhancements.lua"))
local source=f:read("*a");f:close()
local first=assert(source:find("function Mod:FilterCosmeticAlert(frame)",1,true))
local last=assert(source:find("function Mod:InstallHooks()",first,true))
local queued, hooks={},{}
local enabled, hideAlerts=true,true
local Mod={}
function Mod:GetDB() return {visibility={hideAlerts=hideAlerts}} end
local env=setmetatable({Mod=Mod,runtime={},IsModuleEnabled=function() return enabled end,
 ShouldHideAlerts=function(db) return db.visibility.hideAlerts end,
 C_Timer={After=function(_,fn) queued[#queued+1]=fn end}}, {__index=_G})
env._G=env
function env.hooksecurefunc(target,method,cb)
 if type(target)=="string" then hooks[target]=method
 else hooks[method]=cb end
end
local chunk=assert(loadstring(source:sub(first,last-1)));setfenv(chunk,env);chunk()
local function frame(name,parent)
 local r={name=name,shown=true,parent=parent,alpha=1}
 function r:GetName() return self.name end
 function r:IsShown() return self.shown end
 function r:Show() self.shown=true end
 function r:Hide() self.shown=false; self.hideCount=(self.hideCount or 0)+1 end
 function r:SetAlpha(a) self.alpha=a end
 function r:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
 return r
end
local function drain()
 for n=1,10 do
  if #queued==0 then return end
  local jobs=queued;queued={};for _,fn in ipairs(jobs) do fn() end
 end
 error("unbounded filter callbacks")
end
local manager=frame("AlertFrame"); manager.shown=false; manager.alpha=0
manager.AddAlertFrame=function() end
env.AlertFrame=manager
local loot=frame("GroupLootContainer",manager);env.GroupLootContainer=loot
local roll=frame("GroupLootFrame1",loot);roll.rollID=123
local toast=frame("BNToastFrame",manager);env.BNToastFrame=toast
local cosmetic=frame("LootWonAlertFrame1",manager);cosmetic.queue={}
local pool={EnumerateActive=function() return ipairs({cosmetic}) end}
-- The real pool iterator yields frames, not numeric indices.
pool.EnumerateActive=function() local done=false;return function() if not done then done=true;return cosmetic end end end
manager.alertFrameSubSystems={{alertFramePool=pool},{anchorFrame=loot}}
Mod:EnsureAlertFiltering();Mod:EnsureAlertFiltering();drain()
assert(manager.shown and manager.alpha==1,"shared manager stays available before roll events")
assert(roll:IsVisible(),"native roll cannot inherit a hidden manager")
assert(not cosmetic.shown,"cosmetic filtering is preserved")
assert(not manager.hideCount and not loot.hideCount and not roll.hideCount and toast.shown)
assert(hooks.AddAlertFrame,"late-created alerts are filtered")
local new=frame("AnonymousCosmetic",manager);new.queue={}
hooks.AddAlertFrame(manager,new)
assert(new.shown,"filter must defer writes out of native setup")
drain();assert(not new.shown)
for _,interactive in ipairs({manager,loot,roll,toast,frame("BonusRollFrame",manager)}) do
 Mod:FilterCosmeticAlert(interactive)
end
drain();assert(roll:IsVisible() and toast.shown and not manager.hideCount)
hideAlerts=false;new.shown=true;hooks.AddAlertFrame(manager,new);drain();assert(new.shown)
hideAlerts=true;enabled=false;hooks.AddAlertFrame(manager,new);drain();assert(new.shown)
enabled=true
local protected=frame("LootWonAlertFrame2",manager)
function protected:IsProtected() return true end
Mod:FilterCosmeticAlert(protected);drain();assert(protected.shown)
assert(not source:find('_G.AlertFrame:Hide()',1,true),"old manager-wide hiding remains")
assert(not source:find('_G.AlertFrame:HookScript("OnShow"',1,true),"old OnShow filter remains")
print("PASS: loot manager restored before events, native roll/buttons untouched, deferred cosmetic filtering and settings preserved")
