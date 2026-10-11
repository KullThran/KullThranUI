local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_Nameplates/Modules/Nameplates/Nameplates.lua"))
local s=f:read("*a");f:close()
local form=0
local env=setmetatable({classPowerFormReq=1,classPowerType=4,
 GetShapeshiftFormID=function() return form end,
 SetPipDecor=function(p,shown) p.decor=shown end},{__index=_G})
local start=assert(s:find("local function ShouldDisplayClassPower()",1,true))
local last=assert(s:find("    local cpScale",start,true))
local chunk=assert(loadstring(s:sub(start,last-1)..' return "render"\nend\nreturn UpdateClassPowerOnPlate, ShouldDisplayClassPower'))
setfenv(chunk,env);local update,allowed=chunk()
local function region() return {shown=true,Hide=function(self) self.shown=false end} end
local function plate()
 local p={_cpPips={},_cpBar=region()}
 for i=1,5 do local r=region();r._bg=region();r._circleBorder=region();r.decor=true;p._cpPips[i]=r end
 return p
end
-- Re-used target plates can be refreshed by health, cast and target events,
-- independently of the shapeshift watcher. Every route must enforce the gate.
for _,state in ipairs({0,5,31}) do
 form=state
 for _,event in ipairs({"health","cast","target","UNIT_POWER_UPDATE"}) do
  local p=plate();assert(update(p)==nil,event.." rendered combos outside cat")
  for _,pip in ipairs(p._cpPips) do
   assert(not pip.shown and not pip._bg.shown and not pip._circleBorder.shown and not pip.decor)
  end
  assert(not p._cpBar.shown)
 end
 assert(not allowed())
end
form=1;assert(allowed() and update(plate())=="render","cat form combos should remain available")
env.classPowerFormReq=nil;form=0
assert(allowed() and update(plate())=="render","rogue/other class resources should remain available")
env.classPowerFormReq=1;env.GetShapeshiftFormID=nil
assert(not allowed(),"missing form API must not show unverified druid combos")
local a=assert(s:find("GetClassPowerTopPush = function(plate)",1,true))
local b=assert(s:find("local function RefreshClassPowerPlates",a,true))
env.ShouldDisplayClassPower=allowed;env.GetShowClassPower=function() return true end
chunk=assert(loadstring(s:sub(a,b-1)));setfenv(chunk,env);chunk()
assert(env.GetClassPowerTopPush(plate())==0,"hidden combos must not reserve layout space")
print("PASS: druid combo render gated outside cat, stale pips/background/decor hidden, cat/other classes preserved and no empty layout gap")
