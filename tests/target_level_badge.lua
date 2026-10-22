local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua")); local source=f:read("*a");f:close()
local a=assert(source:find("ns.ShowCharacterLevel = function",1,true)); local b=assert(source:find("-- Classification artwork is directional.",a,true))
local ns={SafeCall=function(fn,...) return fn(...) end,StockStyleToggle=function() return true end,UnitInCombat=function() return true end}
local theme,value,exists="forever","90",true
local function region()
 return {SetShown=function(self,v) self.shown=v end,Hide=function(self) self.shown=false end,SetText=function(self,v) self.text=v end}
end
local frame={_kuiLevelText=region(),_kuiLevelCircle=region(),_kuiLevelCombatIcon=region(),Portrait={backdrop={IsShown=function() return true end}}}
local profile={portraitStyle="attached"}
local env=setmetatable({ns=ns,KT={VisualThemes={GetRenderedTheme=function() return theme end}},
 UnitExists=function() return exists end,GetSettingsForUnit=function() return {showPortrait=true} end,
 SafeUnitLevelText=function() return value end}, {__index=_G})
local chunk=assert(loadstring(source:sub(a,b-1)));setfenv(chunk,env);chunk()
for _,style in ipairs({"classic","forever","retail"}) do
 theme=style;ns.RefreshLevelBadgeVisibility(frame,"target",profile)
 assert(frame._kuiLevelCircle.shown and frame._kuiLevelCombatIcon.shown and not frame._kuiLevelText.shown)
 value=nil;ns.RefreshLevelBadgeVisibility(frame,"target",profile)
 assert(frame._kuiLevelCircle.shown,"a temporarily unavailable level must not remove the badge")
 frame._kuiLevelCombatIcon=nil;ns.RefreshLevelBadgeVisibility(frame,"target",profile)
 assert(frame._kuiLevelText.shown and frame._kuiLevelText.text=="??")
 value="26";ns.RefreshLevelBadgeVisibility(frame,"target",profile)
 assert(frame._kuiLevelText.text=="26" and frame._kuiLevelCircle.shown)
 exists=false;ns.RefreshLevelBadgeVisibility(frame,"target",profile)
 assert(not frame._kuiLevelText.shown and not frame._kuiLevelCircle.shown)
 exists=true;profile.showCharacterLevel=false;ns.RefreshLevelBadgeVisibility(frame,"target",profile)
 assert(not frame._kuiLevelCircle.shown)
 profile.showCharacterLevel=true;frame._kuiLevelCombatIcon=region()
end
print("PASS: target level badge, combat icon, unknown level, retarget, missing unit and manual disable")

env.KT.IS_FOREVER=false;theme="kui";profile.showCharacterLevel=true;value="26"
for _,unit in ipairs({"player","target","pet","focus"}) do
 -- With a portrait: the number shows on it, never the stock level circle.
 ns.RefreshLevelBadgeVisibility(frame,unit,profile,false)
 assert(frame._kuiLevelText.shown and frame._kuiLevelText.text=="26" and not frame._kuiLevelCircle.shown)
 -- Show Character Level off hides it.
 profile.showCharacterLevel=false;ns.RefreshLevelBadgeVisibility(frame,unit,profile,false)
 assert(not frame._kuiLevelText.shown)
 profile.showCharacterLevel=true
end
-- Without a portrait KUI Style has no place for the level.
profile.portraitStyle="none"
for _,unit in ipairs({"player","target","pet","focus"}) do
 ns.RefreshLevelBadgeVisibility(frame,unit,profile,false)
 assert(not frame._kuiLevelText.shown and not frame._kuiLevelCircle.shown)
end
assert(not ns.ShowCharacterLevel(profile,false) and ns.ShowCharacterLevel(profile,true))
env.KT.IS_FOREVER=true;assert(ns.ShowCharacterLevel(profile))
print("PASS: KUI Style level only on the portrait; Forever KUI levels retained")
