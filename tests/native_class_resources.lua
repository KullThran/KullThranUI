local root=arg[1] or "."
local function read(path) local f=assert(io.open(root.."/"..path)); local s=f:read("*a"); f:close(); return s end
local ns, class, combat, devourer = {}, "PALADIN", false, true
local kt={IS_FOREVER=false,VisualThemes={GetRenderedTheme=function() return "retail" end}}
local function frame()
    local f={scale=1,shown=true,hooks={}}
    function f:GetScale() return self.scale end
    function f:SetScale(v) self.scale=v end
    function f:ClearAllPoints() self.point=nil end
    function f:SetPoint(...) self.point={...}; if self.hooks.SetPoint then self.hooks.SetPoint() end end
    function f:SetParent(p) self.parent=p; if self.hooks.SetParent then self.hooks.SetParent() end end
    function f:GetFrameStrata() return "LOW" end
    function f:GetFrameLevel() return 5 end
    function f:SetFrameStrata() end
    function f:SetFrameLevel() end
    function f:Hide() self.shown=false end
    function f:SetShown(v) self.shown=v end
    function f:RegisterEvent() end
    function f:SetScript(k,v) self[k]=v end
    function f:HookScript(k,v) self[k]=v end
    return f
end
local env=setmetatable({UIParent=frame(), UnitClass=function() return "Player",class end,
    InCombatLockdown=function() return combat end,UnitHasVehicleUI=function() return false end,
    LibStub=function() return {GetAddon=function() return kt end} end,
    CreateFrame=frame, C_Timer={After=function(_,fn) fn() end},
    hooksecurefunc=function(f,k,fn) f.hooks[k]=fn end}, {__index=_G})
env._G=env
for _,name in ipairs({"PaladinPowerBarFrame","RuneFrame","EssencePlayerFrame","DemonHunterSoulFragmentsBar"}) do
    local f=frame(); env[name]=f
    f.layoutParent={RemoveManagedFrame=function(_,bar) bar.removed=true end}
end
function env.PaladinPowerBarFrame:Setup() self.setups=(self.setups or 0)+1; self:SetShown(true) end
function env.EssencePlayerFrame:Setup() self.setups=(self.setups or 0)+1; self:SetShown(true) end
function env.RuneFrame:UpdateRunes() self.updates=(self.updates or 0)+1 end
function env.DemonHunterSoulFragmentsBar:EvaluateUnit() self.enabled=devourer end
function env.DemonHunterSoulFragmentsBar:IsBarEnabled() return self.enabled end
local chunk=assert(loadstring(read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_NativeClassResources.lua")))
setfenv(chunk,env);chunk("KUI",ns)
local native=ns.NativeClassResources
local player=frame(); player.Power=frame()
local profile={player={classPowerStyle="none",lockClassPowerToFrame=true,classPowerBarX=7,classPowerBarY=-2}}
native:ApplyDefaults(profile)
assert(profile.player.classPowerStyle=="blizzard" and profile.player.showClassPowerBar)
profile.player.classPowerStyle="none"; native:ApplyDefaults(profile)
assert(profile.player.classPowerStyle=="none","manual disable must persist after migration")
profile.player.classPowerStyle="blizzard"
for c,name in pairs({PALADIN="PaladinPowerBarFrame",DEATHKNIGHT="RuneFrame",EVOKER="EssencePlayerFrame",DEMONHUNTER="DemonHunterSoulFragmentsBar"}) do
    native:Deactivate();class=c;native:Prepare()
    local bar=native:Activate(player,profile)
    assert(bar==env[name] and bar._ktNativeResourceOwned and bar.unit=="player")
    assert(bar.removed and bar.ignoreFramePositionManager and bar.parent==player)
    assert(bar.point[1]=="TOP" and bar.point[2]==player.Power and bar.point[3]=="BOTTOM")
    assert(bar.point[4]==7 and bar.point[5]==-6 and bar.shown)
    bar:SetPoint("CENTER",env.UIParent,"CENTER",99,99)
    assert(bar.point[2]==player.Power,"Blizzard relayout must retain custom anchor")
    combat=true; bar:SetPoint("CENTER",env.UIParent,"CENTER",99,99)
    assert(native.pending and bar.point[2]==env.UIParent)
    combat=false; native.events.OnEvent(); assert(bar.point[2]==player.Power)
end
native:Deactivate();class="DEMONHUNTER";devourer=false;native:Activate(player,profile)
assert(not native.bar.shown,"Havoc/Vengeance must not get a Devourer resource")
devourer=true;native:Refresh();assert(native.bar.shown)
native:Deactivate();local old=env.DemonHunterSoulFragmentsBar
assert(not old.shown and old.parent==native.hidden)
native:Activate(player,profile);assert(old.shown,"reactivation retains native state")
profile.player.lockClassPowerToFrame=false;profile.positions={classPower={point="CENTER",x=55,y=-77}}
native:Refresh();assert(old.parent==env.UIParent and old.point[4]==55 and old.point[5]==-77)
-- Forever can use the Retail visual style and the same available native resources.
kt.IS_FOREVER=true
for c,name in pairs({PALADIN="PaladinPowerBarFrame",DEATHKNIGHT="RuneFrame",EVOKER="EssencePlayerFrame",DEMONHUNTER="DemonHunterSoulFragmentsBar"}) do
    native:Deactivate();class=c
    assert(native:IsSupported(), "available resource must work in Forever")
    local foreverProfile={player={classPowerStyle="none",lockClassPowerToFrame=true}}
    native:ApplyDefaults(foreverProfile)
    assert(foreverProfile.player.classPowerStyle=="blizzard")
    local bar=native:Activate(player,foreverProfile)
    assert(bar==env[name] and bar.parent==player and bar.point[2]==player.Power)
end
native:Deactivate();class="EVOKER"
local essence=env.EssencePlayerFrame;env.EssencePlayerFrame=nil
assert(not native:IsSupported(),"missing client resources must be skipped")
assert(native:Activate(player,profile)==nil)
env.EssencePlayerFrame=essence
class="MAGE";assert(not native:IsSupported())
-- Applying Retail must seed native resources in both client flavors.
function kt.VisualThemes:RegisterModule(_,adapter) self.adapter=adapter end
chunk=assert(loadstring(read("KullThranUI/Modules/VisualThemes/Adapters/UnitFrames.lua")))
setfenv(chunk,env);chunk("KUI",ns)
for _,flavor in ipairs({"forever","retail"}) do
    for _,theme in ipairs({"forever","retail"}) do
        local p={player={},target={}}
        kt.VisualThemes.adapter.seed(p,theme,flavor)
        assert(p.player.showClassPowerBar and p.player.classPowerStyle=="blizzard")
        assert(p.player.classPowerPosition=="bottom" and p.player.lockClassPowerToFrame)
    end
end
-- Existing Forever settings need their own migration, even after Retail was migrated.
class="PALADIN"
kt.VisualThemes.GetRenderedTheme=function() return "forever" end
local existing={_ktRetailNativeResourcesV1=true,player={classPowerStyle="none"}}
native:ApplyDefaults(existing)
assert(existing.player.classPowerStyle=="blizzard" and existing._ktForeverNativeResourcesV1)
existing.player.classPowerStyle="none";native:ApplyDefaults(existing)
assert(existing.player.classPowerStyle=="none","later manual choices must persist")
local ouf=read("KullThranUI/Libraries/oUF/blizzard.lua")
assert(ouf:find("if(classPowerBar and not classPowerBar._ktNativeResourceOwned) then",1,true),"oUF must preserve native events")
print("native class resource layout and lifecycle checks passed")
