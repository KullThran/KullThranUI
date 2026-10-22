local root=arg[1] or "."
local file=assert(io.open(root.."/KullThranUI/Options.lua"))
local source=file:read("*a");file:close()
local first=assert(source:find("-- MENU SKIN ART BEGIN",1,true),"skin art marker")
local last=assert(source:find("-- MENU SKIN ART END",first,true),"skin art end marker")

local accentR=0.8
local KT={db={profile={}}}
function KT:GetStylePalette()return {accent={r=accentR,g=0.2,b=0.4}}end
assert(loadfile(root.."/KullThranUI/MenuSkins.lua"))("KullThranUI",{KT=KT})
local MS=KT.MenuSkins
local skin="kui"
KT.VisualThemes={GetRenderedTheme=function()return skin end}

local function texture()
    local t={shown=true,alpha=1}
    function t:SetTexture(p)self.texture=p end
    function t:SetColorTexture(r,g,b,a)self.color={r,g,b,a} end
    function t:SetVertexColor(r,g,b,a)self.vertex={r,g,b,a} end
    function t:SetSize(w,h)self.w,self.h=w,h end
    function t:SetAlpha(a)self.alpha=a end
    function t:GetAlpha()return self.alpha end
    function t:Show()self.shown=true end
    function t:Hide()self.shown=false end
    function t:IsShown()return self.shown end
    return setmetatable(t,{__index=function(_,k)if k:match("^%u")then return function()end end end})
end
local function frame()
    local f={shown=true,scripts={},level=5}
    function f:CreateTexture()return texture() end
    function f:HookScript(e,fn)self.scripts[e]=fn end
    function f:SetScript(e,fn)self.scripts[e]=fn end
    function f:IsShown()return self.shown end
    function f:GetFrameLevel()return self.level end
    return setmetatable(f,{__index=function(_,k)if k:match("^%u")then return function()end end end})
end
local env=setmetatable({KT=KT,CreateFrame=function()return frame()end,GetTime=function()return 0 end},{__index=_G})
local fn=assert(loadstring(source:sub(first,last-1).."\nreturn ApplyMenuSkinArt, InstallMenuSkinArt"))
setfenv(fn,env)
local ApplyMenuSkinArt,InstallMenuSkinArt=fn()

local f=frame()
f.borderKT=frame()
function f.borderKT:SetShown(v)self.shown=v and true or false end
InstallMenuSkinArt(f)
MS.skins.kui.files=nil
ApplyMenuSkinArt(f,"kui",false)
assert(f._skinArt.fallback.shown and not f._skinArt.base.shown,"no art anywhere -> plain card colour")
assert(f._skinArt.fallback.color and f._skinArt.fallback.color[4]>0)
assert(f.borderKT.shown,"plain fallback keeps the rectangular border")

MS.skins.kui.files={base="kui_base",light="kui_light"}
ApplyMenuSkinArt(f,"classic",false)
assert(not f._skinArt.fallback.shown and f._skinArt.base.shown)
assert(f._skinArt.base.texture:find("kui_base",1,true),"skin without art uses kui")
assert(f._skinArt.base.w==1440 and f._skinArt.base.h==1060,"canvas is 1440x1060")
assert(f._skinArt.light.vertex[1]==0.8,"kui light follows the accent")
assert(not f._skinArt.glow.shown,"no glow declared -> hidden")
assert(not f.borderKT.shown,"painted skin hides the rectangular border (cut corners)")

MS.skins.kui.files.glow="kui_glow"
ApplyMenuSkinArt(f,"kui",false)
assert(f._skinArt.glow.shown,"declared glow is shown")
KT.db.profile.menuGlow=false
ApplyMenuSkinArt(f,"kui",false)
assert(not f._skinArt.glow.shown,"glow can be switched off")

skin="kui";accentR=0.1;f.shown=false
MS:Repaint()
f.shown=true;f.scripts.OnShow(f)
assert(f._skinArt.light.vertex[1]==0.1,"accent changed while closed is applied on open")

skin="forever";MS.skins.forever.files={base="forever_base",light="forever_light"}
MS:Repaint()
assert(f._skinArt.base.texture:find("forever_base",1,true),"skin change repaints an open window")
assert(f._skinArt.light.vertex[1]==0.45,"forever light keeps its own colour")

assert(not source:find("CapasFondo",1,true),"old layered background removed")
assert(not source:find("CreateMenuBackgroundLayer",1,true))
print("menu_frame: skin canvas, kui fallback, plain fallback, glow and repaint passed")
