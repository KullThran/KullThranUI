local root=arg[1] or "."
local theme="retail"
local profile={}
local frames={}
local function region(parent,kind)
    local r={parent=parent,kind=kind,shown=true,width=220,height=18,level=1,bottom=0,top=20,points={},children={}}
    function r:GetFrameLevel() return self.level end
    function r:SetFrameLevel(v) self.level=v end
    function r:SetSize(w,h) self.width,self.height=w,h end
    function r:SetHeight(v) self.height=v end
    function r:SetWidth(v) self.width=v end
    function r:GetHeight() return self.height end
    function r:GetWidth() return self.width end
    function r:GetBottom() return self.bottom end
    function r:GetTop() return self.top end
    function r:GetParent() return self.parent end
    function r:IsShown() return self.shown end
    function r:Show() self.shown=true end
    function r:Hide() self.shown=false end
    function r:SetShown(v) self.shown=v end
    function r:ClearAllPoints() self.points={} end
    function r:SetPoint(...) self.points[#self.points+1]={...} end
    function r:SetAllPoints() end
    function r:SetTexture() end
    function r:SetVertexColor() end
    function r:SetColorTexture() end
    function r:SetAtlas() end
    function r:SetBackdrop() end
    function r:SetBackdropColor() end
    function r:SetBackdropBorderColor() end
    function r:SetFont() end
    function r:SetText(v) self.text=v end
    function r:SetStatusBarTexture() self.fill=region(self) end
    function r:GetStatusBarTexture() return self.fill end
    function r:SetStatusBarColor() end
    function r:SetMinMaxValues() end
    function r:SetValue(v) self.value=v end
    function r:CreateTexture() local c=region(self);self.children[#self.children+1]=c;return c end
    function r:CreateFontString() return self:CreateTexture() end
    function r:RegisterEvent() end
    function r:RegisterUnitEvent() end
    function r:SetScript(name,fn) self[name]=fn end
    return r
end
local KT={db={profile={unitFrames=profile}},VisualThemes={GetRenderedTheme=function() return theme end}}
local ns={frames={}}
local env=setmetatable({LibStub=function() return {GetAddon=function() return KT end} end,
    CreateFrame=function(kind,_,parent) local r=region(parent,kind);frames[#frames+1]=r;return r end,
    UnitClass=function() return "Rogue","ROGUE" end,UnitExists=function() return true end,
    UnitIsFriend=function() return false end,UnitPowerMax=function() return 5 end,UnitPower=function() return 3 end,
    SlashCmdList={}},{__index=_G})
local fn=assert(loadfile(root.."/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_ComboUnderFrame.lua"));setfenv(fn,env);fn("test",ns)
local c=ns.ComboUnderFrame
assert(c.ShowsRing("target") and c.GetBarStyle("target")=="off","Retail defaults to portrait ring only")
local f=region();f.Health=region(f);f.Power=region(f);f.Power.bottom=-10;f.bottom=-30
ns.frames.target=f
c:UpdateUnit("target");assert(not c.live.target,"Retail does not create a default lower row")
c.SetDisplay("target","modern",true);c.SetDisplay("target","classic",true)
assert(c.ShowsRing("target"),"enabling rows keeps ring enabled")
c:UpdateUnit("target")
assert(c.live.target.frame.shown and c.extraLive.target.frame.shown,"both independent rows visible")
local point=c.live.target.frame.points[1]
assert(point[2]==f.Health and point[5]==-13,"target row centres on bars and clears power rather than full portrait frame")
assert(c.extraLive.target.frame.points[1][5]<point[5]-c.live.target.frame.height,"extra row does not overlap primary")
f.Debuffs=region(f);f.Debuffs.bottom=-60;c:UpdateUnit("target")
assert(c.live.target.frame.points[1][2]==f.Health and c.live.target.frame.points[1][5]==-63,"visible auras only affect vertical clearance")
c.SetDisplay("target","modern",false);c:UpdateUnit("target")
assert(c.live.target.style=="classic" and not c.extraLive.target.frame.shown,"disabling one row preserves other and hides secondary")
c.SetDisplay("target","ring",false);assert(not c.ShowsRing("target"))
c.SetDisplay("target","classic",false);c:UpdateUnit("target");assert(not c.live.target.frame.shown)
theme="forever";assert(c.ShowsRing("target") and c.GetBarStyle("target")=="off","choices are isolated by theme")
assert(c.GetBarStyle("player")=="modern")
theme="retail";assert(not c.ShowsRing("target"),"Retail choices survive style round trip")
-- The actual picker tiles toggle independently, including Modern + Classic.
env.GetDB=function() return profile end;env.SetAndRefresh=function(cb) cb() end
env.CurrentAccentColor=function() return 1,.1,.3 end;env.LText=function(s) return s end
local input=assert(io.open(root.."/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_UnitFrames_Options.lua"));local source=input:read("*a");input:close()
local start=assert(source:find("function ns.BuildComboPicker(",1,true))
local stop=assert(source:find("local function FontValues()",start,true))
env.ns=ns;fn=assert(loadstring(source:sub(start,stop-1)));setfenv(fn,env);fn()
local w={Label=function() return nil,20 end,Dropdown=function() return nil,20 end,Slider=function() return nil,20 end}
local first=#frames;ns.BuildComboPicker(region(),w,0,"target")
local tiles={}
for i=first+1,#frames do
    local r=frames[i]
    if r.kind=="Button" then for _,child in ipairs(r.children) do if child.text then tiles[child.text]=r end end end
end
assert(tiles.Ring and tiles.Modern and tiles.Classic and not tiles.Off and not tiles["Ring + Pips"])
tiles.Ring.OnClick();tiles.Modern.OnClick();tiles.Classic.OnClick()
local selected=c.GetDisplays("target");assert(selected.ring and selected.modern and selected.classic,"all picker displays can be enabled together")
tiles.Modern.OnClick();selected=c.GetDisplays("target");assert(selected.ring and selected.classic and not selected.modern)
print("combo_displays: Retail defaults, independent tiles, stacking and theme isolation passed")
