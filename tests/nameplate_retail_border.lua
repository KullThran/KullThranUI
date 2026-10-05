local root = arg[1] or "."
local f=assert(io.open(root .. "/KullThranUI_Nameplates/Modules/Nameplates/Nameplates_ThemeSkin.lua"))
local source=f:read("*a");f:close()
local theme="retail"
local function region(parent)
    local r={parent=parent,width=200,height=16,level=1,shown=true,snap=true,bias=1,points={}}
    function r:CreateTexture() return region(self) end
    function r:SetTexture(v) self.texture=v end
    function r:SetAtlas(v) self.atlas=v end
    function r:SetColorTexture() end
    function r:SetVertexColor() end
    function r:SetAllPoints() end
    function r:SetPoint(...) self.points[#self.points+1]={...} end
    function r:ClearAllPoints() self.points={} end
    function r:SetSize(w,h) self.width,self.height=w,h end
    function r:SetHeight(v) self.height=v end
    function r:SetWidth(v) self.width=v end
    function r:GetHeight() return self.height end
    function r:GetFrameLevel() return self.level end
    function r:SetFrameLevel(v) self.level=v end
    function r:SetSnapToPixelGrid(v) self.snap=v end
    function r:SetTexelSnappingBias(v) self.bias=v end
    function r:SetShown(v) self.shown=v end
    function r:Show() self.shown=true end
    function r:Hide() self.shown=false end
    function r:SetStatusBarTexture(v) self.fill=region(self);self.fill.texture=v end
    function r:GetStatusBarTexture() return self.fill end
    return r
end
local ns={}
local env=setmetatable({KullThranUI={VisualThemes={GetRenderedTheme=function() return theme end}},
    CreateFrame=function(_,_,parent) return region(parent) end},{__index=_G})
env._G=env
local stop=assert(source:find("function ns.RefreshThemeSkin()",1,true))
local fn=assert(loadstring(source:sub(1,stop-1)));setfenv(fn,env);fn("test",ns)
local plate={health=region(),healthBG=region(),cast=region(),castBG=region(),borderFrame=region(),_simpleBorderFrame=region()}
for _,height in ipairs({16,17.25,24,12.5}) do
    plate.health.height=height
    ns.ApplyThemeSkin(plate)
    local skin=plate._skinHealth
    assert(skin.bg.snap==true and skin.bg.bias==1,"native border sampling retained")
    assert(skin.interior.snap==true and skin.interior.bias==1,"native interior sampling retained")
    assert(plate.health.fill.snap==true and plate.health.fill.bias==1,"native fill sampling retained")
    assert(plate.cast.fill.snap==true and plate._skinCast.bg.snap==true)
    assert(skin.bg.atlas=="UI-HUD-CoolDownManager-Bar-BG","native border retained")
    assert(math.abs(skin.bg.points[2][5]+height*.281)<.00001,"original atlas geometry retained")
    assert(not plate.borderFrame.shown and not plate._simpleBorderFrame.shown,"generic borders stay hidden")
end
theme="classic";ns.ApplyThemeSkin(plate)
assert(not plate._skinHealth.bg.shown,"Retail border hidden on style change")
assert(plate.health.fill.snap==true,"Classic sampling unchanged")
theme="retail";ns.ApplyThemeSkin(plate)
assert(plate._skinHealth.bg.shown and plate.health.fill.snap,"Retail sampling restored after style switch")
-- Exercise the real layout and camera-scale refresh, with the same rounding
-- used by KT.PP. A moving camera must not resize Retail's atlas-backed bars.
local nf=assert(io.open(root .. "/KullThranUI_Nameplates/Modules/Nameplates/Nameplates.lua"))
local nameplates=nf:read("*a");nf:close()
local methods={}
local scale=1
local width,height,castHeight,yOffset=200,16,12,3
local function rounded(v) return math.floor(v*scale+.5)/scale end
local pp={}
function pp.Size(frame,w,h) frame:SetSize(rounded(w),rounded(h)) end
function pp.Point(frame,p,relative,rp,x,y) frame:SetPoint(p,relative,rp,rounded(x),rounded(y)) end
function pp.Width(frame,w) frame:SetWidth(rounded(w)) end
function pp.Height(frame,h) frame:SetHeight(rounded(h)) end
local layoutEnv=setmetatable({NameplateFrame=methods,ns=ns,PP=pp,
 GetHealthBarWidth=function() return width end,GetHealthBarHeight=function() return height end,
 GetCastBarHeight=function() return castHeight end,GetNameplateYOffset=function() return yOffset end,
 UnitIsUnit=function() return false end,GetShowCastIcon=function() return false end},{__index=_G})
local function loadMethod(startMarker,endMarker)
 local start=assert(nameplates:find(startMarker,1,true))
 local stop=assert(nameplates:find(endMarker,start+1,true))
 local chunk=assert(loadstring(nameplates:sub(start,stop-1)))
 setfenv(chunk,layoutEnv);chunk()
end
loadMethod("function NameplateFrame:LayoutCoreBars(unit)","function NameplateFrame:ApplyEnemyNameTint()")
loadMethod("function NameplateFrame:RefreshPixelPerfectLayout()","function NameplateFrame:RefreshPlateState()")
for _,key in ipairs({"absorb","castIconFrame","castLeftBorder","castSpark","kickMarker","absorbOverflow"}) do plate[key]=region() end
plate.unit="nameplate1";plate.nameplate={}
plate.GetEffectiveScale=function() return scale end
setmetatable(plate,{__index=methods})
local layoutCalls=0
plate.LayoutCoreBars=function(self,unit) layoutCalls=layoutCalls+1;methods.LayoutCoreBars(self,unit) end
for _,key in ipairs({"RefreshStackBounds","RefreshNamePosition","UpdateRaidIcon","RefreshTargetClassPowerPosition","RefreshCastTextAnchors"}) do plate[key]=function() end end
plate.isCasting=true
for _,s in ipairs({1,.83,.91,1.07,.77,1.12}) do
 scale=s
 -- Explicit refreshes (including style/settings changes) must be stable too.
 plate:LayoutCoreBars(plate.unit);ns.ApplyThemeSkin(plate)
 local before=layoutCalls
 local borderY=plate._skinHealth.bg.points[1][5]
 plate:RefreshPixelPerfectLayout()
 assert(layoutCalls==before,"camera scale refresh must not relayout Retail bars")
 assert(plate.health.width==width and plate.health.height==height,"Retail health geometry stays logical")
 assert(plate.absorb.width==width and plate.absorb.height==height,"absorb matches the fill")
 assert(plate.cast.width==width and plate.cast.height==castHeight,"cast geometry stays logical")
 assert(plate.health.points[1][5]==yOffset,"Retail bar offset stays logical")
 assert(borderY==height*.281,"atlas margins agree with current bar height")
end
width,height=240,20
plate:LayoutCoreBars(plate.unit);ns.ApplyThemeSkin(plate)
assert(plate.health.width==240 and plate._skinHealth.bg.points[1][5]==20*.281,"explicit resizing updates bar and atlas")
theme="classic";scale=.89
local before=layoutCalls
plate:RefreshPixelPerfectLayout()
assert(layoutCalls==before+1,"other styles retain pixel layout refresh")
assert(plate.health.height==rounded(height),"Classic pixel rounding unchanged")
theme="retail"
plate:LayoutCoreBars(plate.unit);ns.ApplyThemeSkin(plate)
assert(plate.health.height==20,"returning to Retail restores logical dimensions")
print("nameplate_retail_border: scale stability, explicit resize and style switches passed")
