local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames_Styles.lua"));local source=f:read("*a");f:close()
local a=assert(source:find("function Styles.ApplyReadableFills(frame, key)",1,true))
local b=assert(source:find("function Styles.Apply(frame,",a,true))
local Styles={Current=function() return "retail" end}
local token="MANA"
local env=setmetatable({Styles=Styles,UnitPowerType=function() return 0,token end, PowerBarColor={RAGE={r=1,g=0,b=0}}},{__index=_G})
local chunk=assert(loadstring(source:sub(a,b-1)));setfenv(chunk,env);chunk()
local function bar(r,g,b)
 local texture={}
 function texture:SetTexCoord(...) self.coords={...} end
 function texture:SetDesaturated(v) self.desaturated=v end
 local t={color={r,g,b,.9},fill=texture}
 function t:SetStatusBarTexture(v) self.texture=v end
 function t:GetStatusBarTexture() return self.fill end
 function t:GetStatusBarColor() return unpack(self.color) end
 function t:SetStatusBarColor(...) self.color={...} end
 return t
end
for _,style in ipairs({"classic","retail","forever","kui"}) do
 for _,color in ipairs({{1,.1,.1},{.1,.4,1},{1,1,.1},{.1,1,.6}}) do
  local frame={unit="party1",health=bar(unpack(color)),power=bar(.22,.45,.95)}
  frame.health.texture="configured";frame.power.texture="configured"
  for _,resource in ipairs({"MANA","RAGE","ENERGY","FOCUS","RUNIC_POWER"}) do
   token=resource
   for n=1,4 do Styles.ApplyReadableFills(frame,style) end
   if style=="kui" then
    assert(frame.health.texture=="configured" and frame.power.texture=="configured")
   elseif style=="classic" then
    assert(frame.health.texture=="Interface\\TargetingFrame\\UI-StatusBar")
    assert(frame.health.fill.coords[1]==0 and frame.health.fill.coords[2]==1)
    if resource=="RAGE" then assert(frame.power.color[1]==1 and frame.power.color[2]==0) end
   else
    assert(frame.health.texture=="UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status")
    local suffix={MANA="Mana",RAGE="Rage",ENERGY="Energy",FOCUS="Focus",RUNIC_POWER="RunicPower"}
    assert(frame.power.texture=="UI-HUD-UnitFrame-Party-PortraitOn-Bar-"..suffix[resource])
    assert(frame.power.color[1]==1 and frame.power.color[2]==1 and frame.power.color[3]==1)
    assert(not frame.health.fill.coords,"native UVs must remain owned by StatusBar")
   end
   for i=1,3 do assert(frame.health.color[i]==color[i]) end
  end
 end
end
local nativeStart=assert(source:find("local g, s, x, y = Styles.Geometry",1,true))
local native=source:sub(nativeStart)
assert(native:find("frame.health:SetFrameLevel(base + 5)",1,true))
assert(native:find("frame.power:SetFrameLevel(base + 5)",1,true))
assert(native:find("host:SetFrameLevel(base + 4)",1,true))
print("PASS: all four Party styles, native neutral health, five native resources, custom colours, clipping UV ownership and layers")
