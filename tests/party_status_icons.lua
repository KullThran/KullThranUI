local root = arg[1] or "."
local f = assert(io.open(root .. "/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames_Styles.lua"))
local source = f:read("*a"); f:close()
local a = assert(source:find("function Styles.LayoutStatusIndicators(frame, g, scale)", 1, true))
local b = assert(source:find("function Styles.ApplyReadableFills(frame, key)", a, true))
local Styles = {}
local env = setmetatable({Styles=Styles}, {__index=_G})
local chunk = assert(loadstring(source:sub(a,b-1))); setfenv(chunk,env); chunk()
local function region(shown)
 local t = {shown=shown}
 function t:IsShown() return self.shown end
 function t:ClearAllPoints() self.point=nil end
 function t:SetPoint(...) self.point={...} end
 function t:SetSize(w,h) self.width=w; self.height=h end
 function t:SetTexCoord(...) self.coords={...} end
 function t:SetJustifyH(v) self.justify=v end
 function t:SetScale(v) self.scale=v end
 function t:SetFrameLevel(v) self.level=v end
 function t:GetFrameLevel() return self.level or 5 end
 return t
end
for _,height in ipairs({8,10}) do
 for _,scale in ipairs({1,1.25,1.5625,2}) do
  for _,state in ipairs({"Dead","Offline","AFK","Alive"}) do
   local icon=region(state~="Alive")
   local status=region(state=="Dead" or state=="Offline")
   local value=region(not status.shown)
   local frame={health=region(true),statusIcon=icon,statusText=status,valueText=value,
    statusIconFrame=region(true),readyCheckIcon=region(true)}
   local g={health={45,19,70,height}}
   Styles.LayoutStatusIndicators(frame,g,scale)
   local text=status.shown and status or value
   assert(icon.point[2]==text and icon.point[3]=="LEFT")
   assert(icon.height==height*scale and icon.coords[1]==0 and icon.coords[2]==1)
   assert(frame.statusIconFrame.level==7)
   if icon.shown then
    assert(text.point[2]==frame.health and text.point[3]=="CENTER")
    local center=text.point[4]
    local left=center-text.width/2-2*scale-icon.width
    local right=center+text.width/2
    assert(math.abs(left+right)<.00001, "status group is not centered")
    assert(left>=-35*scale and right<=35*scale, "status overlaps portrait or bar edge")
    assert(icon.width==height*scale*(state=="AFK" and 2 or 1))
   else
    assert(not value.point, "healthy value should retain the full bar layout")
   end
   local ready=frame.readyCheckIcon
   assert(ready.scale==1 and ready.width==12*scale)
   assert(ready.point[1]=="LEFT" and ready.point[2]==frame.health and ready.point[3]=="RIGHT")
  end
 end
end
-- The options preview uses the same helper through its alternate field names.
local preview={health=region(true),status=region(true),value=region(false),statusIcon=region(true)}
Styles.LayoutStatusIndicators(preview,{health={47,12,70,8}},1.25)
assert(preview.statusIcon.point[2]==preview.status)
assert(source:find("Styles.LayoutStatusIndicators(frame, g, s)",b,true))
-- With a portrait the state icon sits on it and the label stays centred on the bar.
do
 local portrait=region(true); function portrait:GetWidth() return 40 end
 local icon,status=region(true),region(true)
 local frame={health=region(true),statusIcon=icon,statusText=status,valueText=region(false),
  statusIconFrame=region(true),portraitFrame=portrait}
 Styles.LayoutStatusIndicators(frame,{health={45,19,70,10}},1)
 assert(icon.point[1]=="CENTER" and icon.point[2]==portrait and icon.point[3]=="CENTER","icon must sit on the portrait")
 assert(status.point[2]==frame.health and status.point[4]==0,"label must stay centred on the bar")
 assert(frame.statusIconFrame.level>=portrait:GetFrameLevel()+8,"icon must draw above the portrait")
end
print("PASS: native party Dead/Offline/AFK placement, scale, layering, healthy values and preview aliases")
