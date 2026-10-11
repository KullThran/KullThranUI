local root=arg[1] or "."
local function read(p) local f=assert(io.open(root.."/"..p));local s=f:read("*a");f:close();return s end
local uf=read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua")
local combo=read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_ComboUnderFrame.lua")
local rb=read("KullThranUI_ResourceBars/Modules/KUIResourceBars/KUIResourceBars.lua")
local form,class,spec=0,"DRUID",103
local env=setmetatable({CUF={},ns={KTTargetCombo={}},Enum={PowerType={ComboPoints=4,SoulShards=7}},PT={COMBO=4,ENERGY=3,LUNAR_POWER=8},
 UnitClass=function() return "Druid",class end,GetShapeshiftFormID=function() return form end,
 GetSpecID=function() return spec end,UnitPowerType=function() return 3 end,
 GetPowerMax=function(_,_,fallback) return fallback end,
 UnitExists=function() return true end,UnitIsFriend=function() return false end},{__index=_G})
local function compile(s) local c=assert(loadstring(s));setfenv(c,env);return c() end
local a=assert(combo:find("function CUF.PlayerHasCombo()",1,true))
local b=assert(combo:find("--  Other class resources",a,true))
compile(combo:sub(a,b-1))
a=assert(uf:find("function ns.KTTargetCombo:Refresh(frame)",1,true))
b=assert(uf:find("    local renderedTheme",a,true))
compile(uf:sub(a,b-1)..' return "render"\nend')
function env.ns.KTTargetCombo:_Hide(frame) frame.ring=false;frame.bar=false end
a=assert(rb:find("local function GetSecondaryResource()",1,true))
b=assert(rb:find('-- When "Combo Points Under Frame"',a,true))
local secondary=compile(rb:sub(a,b-1)..'return GetSecondaryResource')
a=assert(uf:find('    local function UpdatePips()',uf:find('local function CreateCustomClassPower',1,true),true))
b=assert(uf:find('        if isCustom then',a,true))
local update=compile(uf:sub(a,b-1)..'\nend\nreturn UpdatePips')
env.playerClass="DRUID";env.powerType=4;env.container={SetAlpha=function(self,v) self.alpha=v end}
for _,state in ipairs({0,5,27,31,197,1,0,1,5}) do
 form=state
 assert(env.CUF.PlayerHasCombo()==(state==1))
 for _,style in ipairs({"kui","retail","forever","classic"}) do
  local frame={unit="target",ring=true,bar=true}
  local result=env.ns.KTTargetCombo:Refresh(frame)
  if state==1 then assert(result=="render") else assert(not frame.ring and not frame.bar and not result) end
 end
 local res=secondary();assert((res and res.power==4 or false)==(state==1))
 update();assert(env.container.alpha==(state==1 and 1 or 0))
end
form=0;spec=102;assert(secondary().power==8,"Balance astral secondary preserved")
form=197;assert(secondary()==nil,"Moonkin does not duplicate primary resource")
env.GetShapeshiftFormID=nil;assert(not env.CUF.PlayerHasCombo());update();assert(env.container.alpha==0)
local frame={unit="target",ring=true,bar=true};env.ns.KTTargetCombo:Refresh(frame);assert(not frame.bar)
class="ROGUE";assert(env.CUF.PlayerHasCombo() and secondary().power==4)
assert(env.ns.KTTargetCombo:Refresh({unit="target"})=="render")
class="WARLOCK";assert(env.ns.KTTargetCombo:Refresh({unit="target"})=="render","target soul shards preserved")
assert(uf:find('if powerType == Enum.PowerType.ComboPoints and playerClass == "DRUID" then\n            eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")',1,true))
print("PASS: druid combos gated to Cat in Target ring/bar, under-frame and all custom Player styles, Resource Bars; form transitions and other classes preserved")
