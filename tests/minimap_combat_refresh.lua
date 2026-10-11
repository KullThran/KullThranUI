local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_Minimap/Modules/Minimap/Minimap.lua"))
local source=f:read("*a"):gsub("\r\n","\n");f:close()
local combat=true
local frames={}
local mod={db={enable=true}}
local kt={db={profile={minimap={enable=true,scale=1.1}}}}
local env=setmetatable({Mod=mod,KT=kt,InCombatLockdown=function() return combat end,
 CreateFrame=function()
  local f={}
  function f:RegisterEvent(e) self.event=e end
  function f:UnregisterEvent() self.event=nil end
  function f:SetScript(_,fn) self.callback=fn end
  frames[#frames+1]=f;return f
 end}, {__index=_G})
local function loadFunction(name)
 local a=assert(source:find("function Mod:"..name.."(",1,true))
 local b=source:find("\nfunction Mod:",a+1,true)
 b=b or (#source+1)
 local code=source:sub(a,b-1)
 local chunk=assert(loadstring(code));setfenv(chunk,env);chunk()
end
loadFunction("DeferProtectedLayout")
-- Execute real refresh/layout functions: forbidden globals would fail if reached.
for _,name in ipairs({"Refresh","RefreshAfterUIShow","ApplyTrackingAnchor","HandleBorders","UpdateIcons","RestoreClusterSize","RestoreConfiguredClusterPosition","RestoreMinimapInteraction","RestoreEditModeMinimapPosition","ApplyElementOffsets"}) do
 loadFunction(name)
 for i=1,3 do mod[name](mod) end
end
assert(#frames==1,"layout requests were not coalesced")
local runs=0
mod.Refresh=function(self) assert(not combat);runs=runs+1;assert(kt.db.profile.minimap.scale==1.4) end
kt.db.profile.minimap={enable=true,scale=1.4}
-- A spurious regen event in combat must never apply geometry.
frames[1].callback(frames[1]);assert(runs==0)
combat=false;frames[1].callback(frames[1]);assert(runs==1 and not frames[1].event)
combat=true;assert(mod:DeferProtectedLayout())
kt.db.profile.minimap.enable=false
combat=false;frames[1].callback(frames[1]);assert(runs==1)
-- Disabling cancels both waiting events and invalidates delayed mask writes.
loadFunction("OnDisable")
mod._ktMaskCombatWaiter=env.CreateFrame()
mod._ktMaskCombatWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
mod._ktMaskApplyToken=7
mod:OnDisable()
assert(not frames[1].event and not mod._ktMaskCombatWaiter.event and mod._ktMaskApplyToken==8)
print("PASS: all minimap refresh entries defer before protected layout; one latest-profile refresh; disable cancels pending work")
