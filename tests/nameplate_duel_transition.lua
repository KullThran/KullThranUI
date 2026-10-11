local root=arg[1] or "."
local function read(rel) local f=assert(io.open(root.."/"..rel));local s=f:read("*a");f:close();return s end
local function run(env,s) local c=assert(loadstring(s));setfenv(c,env);return c() end
local log,canAttack,handlers={}, false,{}
local nameplate={}
local env=setmetatable({log=log},{__index=_G}); env._G=env
env.ns={plates={}, IsEnemyNameplateUnit=function() return canAttack end, TryAddFriendlyPlate=function(u) log[#log+1]="friendlyBar" end,
  RemoveFriendlyPlateNoRestore=function() log[#log+1]="removeBar" end,
  RemoveFriendlyNameOnlyPresentation=function() log[#log+1]="removeNameOnly" end,
  TrySuppressNPCHealthBar=function() log[#log+1]="npcNameOnly" end,
  TrySuppressFriendlyPlayerNameplate=function() log[#log+1]="playerNameOnly" end,
  UpdateFriendlyPlayerLevel=function() log[#log+1]="friendlyLevel" end}
env.transitionState={pendingUnits={},pendingWatchers={},enemyWatchers={}}
env.GetSafeNamePlateForUnit=function() return nameplate end
env.AcquireEnemyPlate=function() log[#log+1]="acquireEnemy" end
env.ReleaseEnemyPlate=function() log[#log+1]="releaseEnemy" end
env.RestoreBlizzardFrame=function() log[#log+1]="restoreBlizz" end
env.CreateFrame=function() local f={} function f:RegisterUnitEvent() end function f:UnregisterAllEvents() end
  function f:SetScript(_,fn) self.fn=fn end function f:GetScript() return self.fn end return f end
local src=read("KullThranUI_Nameplates/Modules/Nameplates/Nameplates.lua")
local a=assert(src:find("local function RemoveFriendlyPresentation(unit)",1,true))
local b=assert(src:find("-- Activa o desactiva el listener de UNIT_FACTION",a,true))
run(env,src:sub(a,b-1))
local ts=env.transitionState
-- duel starts: friendly name-only plate must be dropped before the enemy bar plate is acquired
local w=ts.CreatePendingWatcher("nameplate1",nameplate)
canAttack=false; w.fn(w,"UNIT_FLAGS","nameplate1"); assert(#log==0,"still friendly: nothing happens")
canAttack=true; w.fn(w,"UNIT_FLAGS","nameplate1")
assert(table.concat(log,",")=="removeNameOnly,removeBar,acquireEnemy","got "..table.concat(log,","))
assert(ts.enemyWatchers["nameplate1"],"enemy watcher chained")
-- duel ends: enemy plate released, Blizzard UF restored, name-only look re-applied
for i=#log,1,-1 do log[i]=nil end
local e=ts.enemyWatchers["nameplate1"]
canAttack=true; e.fn(e,"UNIT_FLAGS","nameplate1"); assert(#log==0)
canAttack=false; e.fn(e,"UNIT_FLAGS","nameplate1")
local got=table.concat(log,",")
assert(got=="releaseEnemy,restoreBlizz,friendlyBar,npcNameOnly,playerNameOnly,friendlyLevel","got "..got)
assert(ts.pendingWatchers["nameplate1"],"pending watcher re-armed")
-- friendly module exposes the name-only teardown
local fr=read("KullThranUI_Nameplates/Modules/Nameplates/Nameplates_Friendly.lua")
assert(fr:find("function ns.RemoveFriendlyNameOnlyPresentation",1,true))
print("PASS: duel start removes name-only friendly look before the enemy plate; duel end restores it")
