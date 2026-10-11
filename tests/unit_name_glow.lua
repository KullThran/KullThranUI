local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_AggroGlow.lua"));local source=f:read("*a");f:close()
local a=assert(source:find("local function LayoutNameGlow",1,true))
local b=assert(source:find("local function LayoutRestGlow",a,true))
local theme="forever"
local env=setmetatable({Theme=function() return theme end},{__index=_G})
local fn=assert(loadstring(source:sub(a,b-1).."\nreturn LayoutNameGlow"));setfenv(fn,env);local layout=fn()
local texture={}
function texture:SetParent(v) self.parent=v end
function texture:SetDrawLayer(a,b) self.layer,self.sublevel=a,b end
function texture:SetTexture(v) self.file=v end
function texture:SetBlendMode(v) self.blend=v end
function texture:ClearAllPoints() self.points={} end
function texture:SetAllPoints(v) self.anchor=v end
function texture:SetPoint(...) self.points[#self.points+1]={...} end
function texture:SetHeight(v) self.height=v end
function texture:SetTexCoord(...) self.coords={...} end
function texture:SetVertexColor(...) self.color={...} end
function texture:SetAlpha(v) self.alpha=v end
function texture:Show() self.shown=true end
function texture:Hide() self.shown=false end
local host={CreateTexture=function() return texture end}
local health={IsShown=function() return true end}
local strip={GetTexCoord=function() return 200/1024,320/1024,235/512,253/512 end}
local frame={Health=health,_ktForeverArtHost=host,_ktNameReaction=strip,_ktNameReactionActive=true}
local g={GetAlpha=function() return .42 end,color={1,.12,.12}}
for _,style in ipairs({"retail","forever"}) do
 theme=style;g.color={1,.12,.12};assert(layout(frame,g))
 assert(texture.parent==host and texture.layer=="BACKGROUND" and texture.sublevel==-1)
 assert(texture.anchor==strip and texture.coords[1]==200/1024 and texture.coords[4]==253/512)
 assert(texture.alpha==.42 and texture.color[1]==1 and texture.color[2]==.12)
 assert(texture.file==[[Interface\AddOns\KullThranUI\Libraries\texture\media\unitframes\UIUnitFrame-Retail.blp]])
 g.color={1,.82,.15};g.resting=true;assert(layout(frame,g));assert(texture.color[2]==.82)
end
frame._ktNameReactionActive=nil;frame.Portrait={backdrop={GetWidth=function() return 75 end}}
assert(layout(frame,g));assert(texture.points[1][2]==health and texture.height==17.5 and texture.coords[4]==249/512)
for _,style in ipairs({"classic","kui"}) do theme=style;assert(not layout(frame,g) and not texture.shown) end
assert(source:find("if self.nameGlow then self.nameGlow:SetAlpha(k) end",1,true))
assert(source:find("if g.nameGlow then g.nameGlow:Hide() end",source:find("local function UpdateUnit",1,true),true))
print("PASS: aggro/rest name glow follows native strip, rim layering, player sizing, pulse and cleanup")
