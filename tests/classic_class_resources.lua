local root=arg[1] or "."
local theme="classic"
local class, spec, power, maxPower = "PALADIN", 70, 3, 5
local profile={player={classPowerStyle="modern"}}
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
    function r:GetEffectiveScale() return 0.71 end
    function r:IsShown() return self.shown end
    function r:Show() self.shown=true end
    function r:Hide() self.shown=false end
    function r:SetShown(v) self.shown=v end
    function r:ClearAllPoints() self.points={} end
    function r:SetPoint(...) self.points[#self.points+1]={...} end
    function r:SetAllPoints() end
    function r:SetTexture(v) self.texture=v end
    function r:SetTexCoord(...) self.coords={...} end
    function r:GetTexCoord() return 0,0,0,1,1,0,1,1 end
    function r:SetVertexColor() end
    function r:SetColorTexture() end
    function r:SetAtlas(v) self.atlas=v end
    function r:SetStatusBarTexture(v) self.fill=region(self);self.fill.texture=v end
    function r:GetStatusBarTexture() return self.fill end
    function r:SetStatusBarColor() end
    function r:SetMinMaxValues() end
    function r:SetValue(v) self.value=v end
    function r:CreateTexture() local c=region(self);self.children[#self.children+1]=c;return c end
    function r:RegisterEvent() end
    function r:RegisterUnitEvent() end
    function r:SetScript(name,fn) self[name]=fn end
    return r
end
local KT={db={profile={unitFrames=profile}},VisualThemes={GetRenderedTheme=function() return theme end}}
local ns={frames={}}
local toggled
ns.frames._toggleClassPower=function(style) toggled=style end
local ATLAS={file=1234,leftTexCoord=0.1,rightTexCoord=0.6,topTexCoord=0.2,bottomTexCoord=0.3}
local env=setmetatable({LibStub=function() return {GetAddon=function() return KT end} end,
    CreateFrame=function(kind,_,parent) return region(parent,kind) end,
    UnitClass=function() return "x",class end,UnitExists=function() return true end,
    UnitIsFriend=function() return false end,InCombatLockdown=function() return false end,
    UnitPowerMax=function() return maxPower end,UnitPower=function() return power end,
    GetRuneCooldown=function(i) return 0,0,i<=4 end,
    C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return spec end},
    C_Texture={GetAtlasInfo=function(name) if name:find("^ComboPoints") then return ATLAS end end},
    Enum={PowerType={ComboPoints=4,HolyPower=9,SoulShards=7,Runes=5,Essence=19,Chi=12,ArcaneCharges=16}},
    SlashCmdList={}},{__index=_G})
local fn=assert(loadfile(root.."/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_ComboUnderFrame.lua"));setfenv(fn,env);fn("test",ns)
local c=ns.ComboUnderFrame
local f=region();f.Health=region(f);f.Power=region(f);f.Power.bottom=-10;f.bottom=-30
ns.frames.player=f

-- Classic: holy power takes the combo tray with its own gem.
assert(c.OwnsClassResource(),"Classic display owns holy power")
c:RefreshAll()
local w=c.live.player
assert(w and w.frame.shown and w.style=="classic","holy power uses the classic tray")
assert(w.gem:find("ClassicResourceHolyPower.tga",1,true),"holy power gem")
assert(w.count==5 and w.pips[1].bar.fill.texture==w.gem,"five holy power points filled with the gem")
assert(w.plate.shown and w.plate.atlas=="ComboPoints-AllPointsBG","five points keep the native tray")
assert(w.frame.points[1][2]==f.Health,"tray spans the bars, not the portrait")

-- Death knight: six runes, ready ones filled, tray rebuilt with six openings.
class,spec,maxPower="DEATHKNIGHT",251,6
c:RefreshAll()
assert(w.gem:find("RuneFrost",1,true),"frost runes are blue")
assert(w.count==6 and w.pips[1].bar.value==4,"ready runes fill the slots")
assert(not w.plate.shown and #w.plateSegs==8,"cap + six cells + cap")
local es=0.71
for i,seg in ipairs(w.plateSegs) do
    assert(seg.shown and seg.texture==1234)
    local x=seg.points[1][4]
    assert(math.abs(x*es-math.floor(x*es+0.5))<1e-6,"slices start on whole physical pixels")
    if i>1 then
        local prev=w.plateSegs[i-1]
        assert(math.abs(prev.points[1][4]+prev.width-x)<1e-9,"no seam between slices")
    end
end
local last=w.plateSegs[8];assert(math.abs(last.points[1][4]+last.width-w.frame.width)<1/es,"tray fills the bar width")

-- Turning the class power bar off or to Blizzard's own bar hands it back.
profile.player.classPowerStyle="blizzard";toggled=nil
assert(not c.OwnsClassResource());c:RefreshAll()
assert(toggled=="blizzard" and not w.frame.shown,"native bar keeps the resource")
profile.player.classPowerStyle="modern";c:RefreshAll()

-- Other styles keep their pips unless the Classic display is chosen.
theme="retail";assert(not c.OwnsClassResource(),"Retail keeps the native/modern bar")
theme="classic"
-- Non-arcane mage and rogues are untouched.
class,spec="MAGE",63;assert(not c.OwnsClassResource())
class="ROGUE";assert(not c.OwnsClassResource())
print("classic_class_resources: tray ownership, gems, rune slices and pixel snapping passed")
