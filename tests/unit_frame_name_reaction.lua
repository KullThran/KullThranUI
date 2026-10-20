local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI/Modules/VisualThemes/ThemeClientAssets.lua"));local source=f:read("*a");f:close()
local first=assert(source:find("function KT.VisualThemes:UpdateUnitFrameNameReaction",1,true))
local last=assert(source:find("function KT.VisualThemes:ApplyClassicUnitFrameArt",first,true))
local reaction,secret,combat,theme=5,false,false,"forever"
local selected,tapped,controlled={0.2,0.9,0.15},false,false
local VT={GetRenderedTheme=function() return theme end}
local strip={}
function strip:SetParent(p) self.parent=p end
function strip:ClearAllPoints() assert(not combat) end
function strip:SetPoint(...) assert(not combat);self.point={...} end
function strip:SetSize(w,h) assert(not combat);self.width,self.height=w,h end
function strip:SetColorTexture() error("reaction glow must not use solid fill") end
function strip:SetVertexColor(...) self.color={...} end
function strip:SetTexture(v) self.texture=v;self.atlas=nil end
function strip:SetAtlas(v) error("use original pixels, not client atlas remapping") end
function strip:SetTexCoord(...) self.uv={...} end
function strip:SetDrawLayer(layer,sublevel) self.layer,self.sublevel=layer,sublevel end
function strip:SetBlendMode(v) self.blend=v end
function strip:SetGradient(direction, bottom, top) self.gradient={direction,bottom,top} end
function strip:SetGradientAlpha(direction, r,g,b,a, r2,g2,b2,a2) self.gradient={direction,{r,g,b,a},{r2,g2,b2,a2}} end
function strip:Show() self.shown=true end
function strip:Hide() self.shown=false end
local host={CreateTexture=function() return strip end}
local frame={}
local env=setmetatable({KT={VisualThemes=VT},UnitReaction=function() return reaction end,
 UnitSelectionColor=function() return unpack(selected) end,
 UnitPlayerControlled=function() return controlled end,UnitIsTapDenied=function() return tapped end,
 issecretvalue=function() return secret end,UnitIsFriend=function() return false end,
 UnitCanAttack=function() return false end,CreateColor=function(...) return {...} end},{__index=_G})
local chunk=assert(loadstring(source:sub(first,last-1)));setfenv(chunk,env);chunk()
for _,style in ipairs({"classic","retail","forever"}) do
 theme=style
 local geom={name={w=96,h=14},health={x=85,y=40,w=124}}
 VT:ConfigureUnitFrameNameReaction(frame,host,"target",geom,1.25,0,0)
 assert(strip.width==(style=="classic" and 155 or 166.25) and strip.height==(style=="classic" and 23.75 or 15) and strip.point[4]==(style=="classic" and 106.25 or 107.5) and strip.point[5]==(style=="classic" and -26.25 or -33.75))
 combat=true
 for _,value in ipairs({5,2,4,8,1}) do
  reaction=value;VT:UpdateUnitFrameNameReaction(frame,"target")
  assert(strip.shown and strip.blend=="BLEND")
  if style=="classic" then assert(strip.layer=="BACKGROUND" and strip.sublevel==-8,"Classic name background sits beneath the frame art")
  else assert(strip.layer=="ARTWORK" and strip.sublevel==-7,"reaction tints the inset name interior") end
  if style=="classic" then assert(strip.texture=="Interface\\TargetingFrame\\UI-TargetingFrame-LevelBackground")
  else assert(strip.texture:find("UIUnitFrame-Retail.blp",1,true) and strip.uv[1]==195/1024 and strip.uv[2]==330/1024 and strip.uv[3]==235/512 and strip.uv[4]==249/512) end
  assert(not strip.gradient,"native shading must not be replaced by a white gradient")
  local color=strip.color
  assert(color[4]==1)
  if style~="classic" then assert(color[1]==selected[1] and color[2]==selected[2] and color[3]==selected[3])
  elseif value>=5 then assert(color[2]>color[1])
  elseif value==4 then assert(color[1]==1 and color[2]==1 and color[3]==0)
  else assert(color[1]>color[2]) end
 end
 if style~="classic" then
  tapped=true;VT:UpdateUnitFrameNameReaction(frame,"target");assert(strip.color[1]==0.5 and strip.color[2]==0.5 and strip.color[4]==1)
  controlled=true;VT:UpdateUnitFrameNameReaction(frame,"target");assert(strip.color[1]==selected[1])
  tapped=false;controlled=false
 end
 VT:UpdateUnitFrameNameReaction(frame,"player");assert(not strip.shown)
 secret=true;VT:UpdateUnitFrameNameReaction(frame,"target");assert(not strip.shown)
 secret=false;combat=false
 VT:ConfigureUnitFrameNameReaction(frame,host,"target",geom,1,0,0,true)
 assert(strip.color[1]>strip.color[2],"target preview shows enemy reaction")
 VT:ConfigureUnitFrameNameReaction(frame,host,"player",geom,1,0,0,true)
 assert(not strip.shown and (style=="classic" or not frame._ktNameReactionActive),"player preview has no glow")
end
theme="kui";VT:UpdateUnitFrameNameReaction(frame,"player");assert(not strip.shown)
theme="forever";frame._ktNameReactionActive=nil;VT:UpdateUnitFrameNameReaction(frame,"player");assert(not strip.shown)
-- Classic reproduces Vanilla rules without touching health or resource colours.
theme="classic";frame.Health={SetStatusBarColor=function() error("name rules changed class health colour") end}
frame.Power=frame.Health
VT:ConfigureUnitFrameNameReaction(frame,host,"target",{name={h=14},health={x=85,y=40,w=124}},1,0,0)
local function expect(r,g,b)
 VT:UpdateUnitFrameNameReaction(frame,"target")
 assert(strip.shown and strip.color[1]==r and strip.color[2]==g and strip.color[3]==b and strip.color[4]==1)
end
reaction=3;expect(1,.5,0)
reaction=nil;expect(0,0,1)
tapped=true;expect(.5,.5,.5);tapped=false
reaction=5;expect(0,1,0)
controlled=true
local outgoing,incoming,pvp=false,false,false
env.UnitCanAttack=function(a,b) return a=="player" and outgoing or a=="target" and incoming end
env.UnitIsPVP=function() return pvp end
expect(0,0,1)
pvp=true;expect(0,1,0)
outgoing=true;expect(1,1,0)
incoming=true;expect(1,0,0)
outgoing=false;expect(0,0,1)
env.UnitIsCivilian=function() return true end;expect(1,1,1)
env.UnitIsCivilian=nil;controlled=false;reaction=5
secret=true;VT:UpdateUnitFrameNameReaction(frame,"target");assert(not strip.shown);secret=false
-- Missing colour API falls back safely; native pixels do not require SetAtlas.
theme="retail";reaction=5;strip.SetAtlas=nil;env.UnitSelectionColor=nil
VT:ConfigureUnitFrameNameReaction(frame,host,"target",{name={h=14},health={x=85,y=40,w=124}},1,0,0)
assert(strip.color[1]==0 and strip.color[2]==1 and strip.color[4]==1 and not strip.gradient)
-- The curved name end extends 11 native pixels beyond the health track.
for _,style in ipairs({"retail","forever"}) do
 theme=style
 for _,scale in ipairs({0.8,1,1.25}) do
  VT:ConfigureUnitFrameNameReaction(frame,host,"target",{name={h=14},health={x=23,y=40,w=124}},scale,-4,8,true)
  assert(strip.point[4]==20*scale and strip.width==141*scale)
  assert(strip.point[5]==-27*scale and strip.height==12*scale)
 end
end
-- Classic: green health moves the class colour to the name background.
theme="classic";reaction=5;controlled=false;tapped=false
env.UnitIsPlayer=function() return true end
env.UnitClass=function() return "Druid","DRUID" end
env.RAID_CLASS_COLORS={DRUID={r=1,g=0.49,b=0.04}}
env.KT.db={profile={unitFrames={target={healthClassColored=false}}}}
VT:ConfigureUnitFrameNameReaction(frame,host,"target",{name={h=14},health={x=7,y=41,w=119}},1,0,0)
assert(strip.color[1]==1 and strip.color[2]==0.49 and strip.color[3]==0.04,"green health shows class colour in the name")
assert(strip.point[5]==-22 and strip.height==19 and strip.width==119,"Classic name background fills the native 119x19 window")
env.KT.db.profile.unitFrames.target.healthClassColored=true
VT:UpdateUnitFrameNameReaction(frame,"target");assert(strip.color[1]==0 and strip.color[2]==1,"class health keeps the reaction colour")
env.KT.db.profile.unitFrames.target.healthClassColored=false;env.UnitIsPlayer=function() return false end
VT:UpdateUnitFrameNameReaction(frame,"target");assert(strip.color[1]==0 and strip.color[2]==1,"NPCs keep the reaction colour")
frame._ktNameReactionPreviewClassColor={0.25,0.78,0.92}
VT:ConfigureUnitFrameNameReaction(frame,host,"target",{name={h=14},health={x=7,y=41,w=119}},1,0,0,true)
assert(strip.color[1]==0.25 and strip.color[3]==0.92,"preview follows the same rule")
theme="retail";VT:ConfigureUnitFrameNameReaction(frame,host,"target",{name={h=14},health={x=7,y=41,w=119}},1,0,0,true)
assert(strip.color[1]~=0.25,"modern styles keep the selection colour")
-- Classic Player: same rule, class colour only when health is not class coloured.
theme="classic";env.UnitIsPlayer=function() return true end
env.KT.db.profile.unitFrames.player={healthClassColored=false}
VT:ConfigureUnitFrameNameReaction(frame,host,"player",{name={h=14},health={x=106,y=41,w=119}},1,0,0)
assert(strip.shown and strip.color[1]==1 and strip.color[2]==0.49,"green Player health shows class colour in the name")
assert(strip.point[4]==106 and strip.point[5]==-22 and strip.height==19,"Player name background fills its window")
env.KT.db.profile.unitFrames.player.healthClassColored=true
VT:UpdateUnitFrameNameReaction(frame,"player");assert(not strip.shown,"class coloured Player health keeps the native name window")
VT:ConfigureUnitFrameNameReaction(frame,host,"player",{name={h=14},health={x=106,y=41,w=119}},1,0,0,true)
assert(not strip.shown)
env.KT.db.profile.unitFrames.player.healthClassColored=false
VT:UpdateUnitFrameNameReaction(frame,"player");assert(strip.shown and strip.color[1]==0.25,"Player preview follows the rule")
theme="retail";VT:ConfigureUnitFrameNameReaction(frame,host,"player",{name={h=14},health={x=106,y=41,w=119}},1,0,0,true)
assert(not strip.shown and not frame._ktNameReactionActive,"modern Player keeps no name tint")
frame._ktNameReactionPreviewClassColor=nil;env.KT.db=nil;env.UnitIsPlayer=nil;env.UnitClass=nil;env.RAID_CLASS_COLORS=nil
local asset=assert(io.open(root.."/KullThranUI/Libraries/texture/media/unitframes/UIUnitFrame-Retail.blp","rb"))
assert(asset:read(4)=="BLP2");asset:close()
print("PASS: native name strip pixels, selection colours, tap denial, combat, preview, fallback and Classic preservation")
