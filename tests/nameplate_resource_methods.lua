local root=arg[1] or "."
local function read(path)
 local f=assert(io.open(root.."/"..path));local s=f:read("*a");f:close();return s
end
local core=read("KullThranUI/KullThranUI.lua")
local source=read("KullThranUI_Nameplates/Modules/Nameplates/Nameplates.lua")
local kt={_resourceState={tip=0,tipMax=3,whirlwind=0,whirlwindMax=4}}
local ns={}
local stacks=2
local refreshes=0
local env=setmetatable({KT=kt,KullThranUI=kt,ns=ns,
 getPlayerAuraStacks=function(id) assert(id==260286);return stacks end,
 RefreshClassPower=function() refreshes=refreshes+1 end,
 RefreshClassPowerFull=function() end,
 DisableClassPowerWatcher=function() end,ApplyClassPowerSetting=function() end},{__index=_G})
env._G=env
local function run(code) local fn=assert(loadstring(code));setfenv(fn,env);return fn() end
local first=assert(core:find("function KT:GetTipOfTheSpear()",1,true))
local last=assert(core:find("local function showGenericGlow",first,true))
run(core:sub(first,last-1))
first=assert(source:find("local function RouteManualTrackers(event, ...)",1,true))
last=assert(source:find('classPowerWatcher:SetScript("OnEvent"',first,true))
local dispatch=run(source:sub(first,last-1).."\nreturn STRING_EVENT_DISPATCH")
-- Reproduce the reported lifecycle event against the real fallback methods.
for _,event in ipairs({"PLAYER_ALIVE","PLAYER_DEAD","PLAYER_REGEN_ENABLED"}) do
 kt._resourceState.tip=2;kt._resourceState.whirlwind=4
 dispatch[event](event)
 assert(kt._resourceState.whirlwind==0,event.." resets Whirlwind")
 if event~="PLAYER_REGEN_ENABLED" then assert(kt._resourceState.tip==0,event.." resets Tip") end
end
dispatch.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED","player","cast1",1680)
assert(kt._resourceState.whirlwind==4 and kt._resourceState.tip==2,"spell ID and aura stacks reach the tracker")
dispatch.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED","player","cast2",12345)
assert(kt._resourceState.whirlwind==3,"player casts consume Whirlwind stacks")
dispatch.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED","target","cast3",12345)
assert(kt._resourceState.whirlwind==3,"other units do not consume stacks")
-- Execute the actual resource getter calls used by Nameplates in each repo.
for _,name in ipairs({"GetTipOfTheSpear","GetWhirlwindStacks"}) do
 local line=assert(source:match("local c, m = (KullThranUI[%.:]"..name.."%(%))"))
 local c,m=run("local c,m="..line..";return c,m")
 assert(c==(name=="GetTipOfTheSpear" and 2 or 3))
 assert(m==(name=="GetTipOfTheSpear" and 3 or 4))
end
-- The compatibility path must receive the event as its first argument too.
local seen={}
ns.KUIUFCompat={
 HandleTipOfTheSpear=function(event,unit,guid,id) seen.tip={event,unit,guid,id} end,
 HandleWhirlwindStacks=function(event,unit,unused,id) seen.whirlwind={event,unit,unused,id} end}
dispatch.UNIT_SPELLCAST_SUCCEEDED("UNIT_SPELLCAST_SUCCEEDED","player","cast4",1680)
assert(seen.tip[1]=="UNIT_SPELLCAST_SUCCEEDED" and seen.tip[2]=="player" and seen.tip[4]==1680)
assert(seen.whirlwind[1]=="UNIT_SPELLCAST_SUCCEEDED" and seen.whirlwind[2]=="player" and seen.whirlwind[4]==1680)
seen={};env._ERB_AceDB={}
dispatch.PLAYER_ALIVE("PLAYER_ALIVE")
assert(not seen.tip and not seen.whirlwind,"ResourceBars owns tracking when loaded")
assert(refreshes>0)
print("nameplate_resource_methods: lifecycle, casts, getters and compatibility passed")
