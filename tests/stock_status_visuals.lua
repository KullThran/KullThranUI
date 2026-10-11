local root=arg[1] or "."
local function read(path) local f=assert(io.open(root.."/"..path));local s=f:read("*a");f:close();return s end
local source=read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua")
local ns={SafeCall=function(fn,...) if fn then return fn(...) end end}
local theme,resting="retail",true
local env=setmetatable({ns=ns,KT={VisualThemes={GetRenderedTheme=function() return theme end}},
    C_Texture={GetAtlasInfo=function() return {} end},IsResting=function() return resting end,
    KUI_ICON_PATH="icons/",UnitIsUnit=function(a,b) return a==b end,
    UnitCanAttack=function() return false end},{__index=_G})
local function extract(first,last,tail)
    local a=assert(source:find(first,1,true));local b=assert(source:find(last,a,true))
    local run=assert(loadstring(source:sub(a,b-1)..(tail or "")));setfenv(run,env);return run()
end
extract("function ns.BlizzardLevelColor(","function ns.UnitInCombat(")
local circle={GetWidth=function() return 32 end,GetHeight=function() return 32 end}
local level={}
function level:ClearAllPoints() self.point=nil end
function level:SetPoint(...) self.point={...} end
function level:SetSize(w,h) self.width,self.height=w,h end
function level:SetJustifyH(value) self.horizontal=value end
function level:SetJustifyV(value) self.vertical=value end
function level:SetWordWrap(value) self.wrap=value end
for _,style in ipairs({"forever","retail"}) do
    assert(ns.CenterStockLevelText(level,circle,style))
    assert(level.point[1]=="CENTER" and level.point[2]==circle and level.point[4]==0 and level.point[5]==0)
    assert(level.horizontal=="CENTER" and level.vertical=="MIDDLE" and level.width==32 and level.height==32)
end
local point=level.point
assert(not ns.CenterStockLevelText(level,circle,"classic") and level.point==point)
assert(not ns.CenterStockLevelText(level,circle,"kui") and level.point==point)
for _,t in ipairs({"forever","retail"}) do
    local r,g,b=ns.BlizzardLevelColor("player",t);assert(r==1 and g==1 and b==1)
    r,g,b=ns.BlizzardLevelColor("target",t);assert(r==1 and g==.82 and b==0)
end
local r,g,b=ns.BlizzardLevelColor(nil,"classic");assert(r==1 and g==.82 and b==0)
extract("function ns.EnableTarget3D(","local function ResolveActivePortraitMode(")
local profile={player={portraitMode="3d"},target={portraitMode="2d"}}
ns.EnableTarget3D(profile)
assert(profile.target.portraitMode=="3d" and profile._ktTarget3DInitialized)
profile.target.portraitMode="2d";ns.EnableTarget3D(profile)
assert(profile.target.portraitMode=="2d","subsequent explicit 2D choice stays independent")
local apply=extract("        local function ApplyRestingTexture(","        ApplyRestingTexture(resting)","\nreturn ApplyRestingTexture")
ns.IsStockStyle=function() return theme~="kui" end
local tex={}
function tex:SetAtlas(value) self.atlas=value end
function tex:SetTexture(value) self.texture=value end
function tex:SetTexCoord(...) self.coords={...} end
function tex:CreateAnimationGroup()
    local group={}
    function group:SetLooping(v) self.loop=v end
    function group:Play() self.playing=true end
    function group:Stop() self.playing=false end
    function group:CreateAnimation()
        local flip={}
        for _,key in ipairs({"Target","Duration","FlipBookRows","FlipBookColumns","FlipBookFrames"}) do
            flip["Set"..key]=function(self,v) self[key]=v end
        end
        self.flip=flip;return flip
    end
    return group
end
apply(tex)
assert(tex.atlas=="UI-HUD-UnitFrame-Player-Rest-Flipbook")
assert(tex._ktRestAnimation.playing and tex._ktRestAnimation.flip.FlipBookFrames==42)
resting=false;apply(tex);assert(not tex._ktRestAnimation.playing)
theme="classic";apply(tex);assert(tex.texture=="Interface\\CharacterFrame\\UI-StateIcon")
source=read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_AggroGlow.lua")
local aggro=false
local frame={IsShown=function() return true end}
env.ns={frames={player=frame,target={IsShown=function() return true end}}}
env.IsResting=function() return resting end
env.UnitAffectingCombat=function() return aggro end
env.HasAggro=function() return aggro end
env.Enabled=function() return true end
env.AG={}
env.Layout=function() end
env.Build=function()
    local glow={rings={},top={},pulse={IsPlaying=function() return true end}}
    function glow.top:SetVertexColor(...) self.color={...} end
    function glow:Show() self.shown=true end
    function glow:Hide() self.shown=false end
    return glow
end
local update=extract("local function UpdateUnit(","function AG:Update()","\nreturn UpdateUnit")
for _, visualStyle in ipairs({"forever","retail","classic"}) do
    theme=visualStyle;resting=true;update("player")
    assert(frame._kuiAggroGlow.shown and frame._kuiAggroGlow.resting and frame._kuiAggroGlow.color[2]==.82)
end
resting=true;update("player")
assert(frame._kuiAggroGlow.shown and frame._kuiAggroGlow.color[2]==.82,"resting glow is gold")
aggro=true;update("player")
assert(frame._kuiAggroGlow.color[2]==.12,"combat glow has priority")
aggro=false;resting=false;update("player")
assert(not frame._kuiAggroGlow.shown,"leaving rest/combat hides glow")
print("stock_status_visuals: ok")
