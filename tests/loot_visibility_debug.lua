local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI/Modules/Enhancements/Enhancements_LootDebug.lua"))
local source=f:read("*a");f:close()
local now, stack, queued, timer, prints=10,"native/start.lua:10",{},nil,{}
local env=setmetatable({},{__index=_G});env._G=env
local KT={db={global={}},Print=function(_,s) prints[#prints+1]=s end}
function KT:RegisterChatCommand(name,cb) self.command=cb;assert(name=="ktlootdebug") end
local function frame(name,parent)
 local t={name=name,parent=parent,shown=true,alpha=1,scripts={},writes=0}
 function t:GetName() return self.name end
 function t:GetParent() return self.parent end
 function t:GetPoint() return "CENTER",self.parent,"CENTER",0,0 end
 function t:IsShown() return self.shown end
 function t:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
 function t:GetAlpha() return self.alpha end
 function t:GetEffectiveScale() return 1 end
 function t:Hide() self.shown=false;self.writes=self.writes+1;if self.scripts.OnHide then self.scripts.OnHide(self) end end
 function t:SetAlpha(a) self.alpha=a;self.writes=self.writes+1 end
 function t:SetShown(v) if not v then self:Hide() else self.shown=true;self.writes=self.writes+1 end end
 function t:SetParent(p) self.parent=p;self.writes=self.writes+1 end
 function t:HookScript(event,cb) self.scripts[event]=cb end
 function t:RegisterEvent(event) self.events=self.events or {};self.events[event]=true end
 function t:SetScript(event,cb) self.scripts[event]=cb end
 return t
end
function env.hooksecurefunc(target,method,cb)
 if type(target)=="string" then
  local name=target;local callback=method;local old=env[name]
  env[name]=function(...) old(...);callback(...) end
 else
  local old=target[method]
  target[method]=function(...) old(...);cb(...) end
 end
end
env.GetTime=function() return now end
env.GetLootRollTimeLeft=function() return 120000-now*1000 end
env.InCombatLockdown=function() return false end
env.debugstack=function() return stack end
env.CreateFrame=function() return frame("debug events") end
env.C_Timer={After=function(_,cb) queued[#queued+1]=cb end,NewTicker=function(_,cb)
 timer={tick=cb,Cancel=function(self) self.cancelled=true end};return timer end}
local chosen=0
env.RollOnLoot=function() chosen=chosen+1 end
env.GroupLootContainer_AddRoll=function() end
env.GroupLootContainer_RemoveFrame=function() end
env.GroupLootContainer_Update=function() end
env.AlertFrame=frame("AlertFrame")
env.AlertFrame.fullscreenFrame=frame("fullscreen",env.AlertFrame)
env.GroupLootContainer=frame("GroupLootContainer",env.AlertFrame)
env.GroupLootFrame1=frame("GroupLootFrame1",env.GroupLootContainer)
local chunk=assert(loadstring(source));setfenv(chunk,env);chunk("addon",{KT=KT})
local d=KT.LootDebug
local function records() return KT.db.global.lootVisibilityDebug end
assert(env.AlertFrame.writes==0 and env.GroupLootFrame1.writes==0,"observer must not modify loot visibility")
d.events.scripts.OnEvent(nil,"START_LOOT_ROLL",23,120000)
for _,cb in ipairs(queued) do cb() end;queued={}
assert(timer and d.rolls[23])
local count=#records();now=11;timer.tick()
assert(#records()==count,"timer countdown alone must not erase causal logs")
stack="OtherAddon/HideLoot.lua:44"
env.GroupLootFrame1:Hide()
local last=records().lastHides[#records().lastHides]
assert(last.action=="Hide GroupLootFrame1" and last.stack==stack,"record hide caller")
assert(last.detail:find("shown=false",1,true))
stack="OtherAddon/ParentFade.lua:22"
env.AlertFrame:SetAlpha(0)
assert(records().lastHides[#records().lastHides].stack==stack,"record parent opacity caller")
local writes=env.GroupLootFrame1.writes
now=12;timer.tick();assert(env.GroupLootFrame1.writes==writes,"debug must not reopen hidden rolls")
stack="Blizzard/NeedClick.lua:1";env.RollOnLoot(23,1)
assert(chosen==1 and records()[#records()].action=="RollOnLoot","observe choice without choosing")
env.GroupLootFrame2=frame("GroupLootFrame2",env.GroupLootContainer)
env.GroupLootContainer_AddRoll(24,60000)
assert(d.hooked[env.GroupLootFrame2],"late native roll frame must acquire hooks")
d.events.scripts.OnEvent(nil,"CANCEL_LOOT_ROLL",23)
assert(not d.rolls[23]);timer.tick();assert(timer.cancelled)
for i=1,200 do d:Record("noise",tostring(i)) end
assert(#records()==160 and #records().lastHides>=2,"bounded log retains last hide callers")
KT.command("dump");assert(#prints>0)
KT.command("off");count=#records();env.GroupLootFrame2:Hide();assert(#records()==count)
KT.command("on");assert(d.enabled)
KT.command("clear");assert(not records().lastHides)
assert(env.AlertFrame.writes==1 and chosen==1,"debug made no extra parent writes or loot choices")
print("PASS: loot debug captures hide callers/parent fades/choices/late frames; bounded retained logs, no visibility writes and no automatic rolls")
