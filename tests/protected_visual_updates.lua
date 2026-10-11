local root=arg[1] or "."
local function read(path)
 local f=assert(io.open(root.."/"..path)); local s=f:read("*a"):gsub("\r\n","\n"); f:close(); return s
end
local combat=false
local timers,events={},{}
local function newFrame()
 local f={}
 function f:RegisterEvent(e) self.event=e end
 function f:UnregisterEvent(e) if self.event==e then self.event=nil end end
 function f:SetScript(_,fn) self.callback=fn end
 events[#events+1]=f; return f
end
local mod={db={enable=true}}
local minimap={calls=0}
function minimap:Hide() error("protected Hide must never be called") end
function minimap:Show() error("protected Show must never be called") end
function minimap:SetMaskTexture(v) assert(not combat,"mask changed in combat"); self.mask=v; self.calls=self.calls+1 end
local env=setmetatable({Mod=mod,Minimap=minimap,isSquare=true,CreateFrame=newFrame,
 InCombatLockdown=function() return combat end,C_Timer={After=function(_,fn) timers[#timers+1]=fn end}}, {__index=_G})
local source=read("KullThranUI_Minimap/Modules/Minimap/Minimap.lua")
local a=assert(source:find("function Mod:ApplyMask()",1,true)); local b=assert(source:find("function Mod:HandleBorders()",a,true))
local chunk=assert(loadstring(source:sub(a,b-1))); setfenv(chunk,env); chunk()
mod:ApplyMask(); assert(minimap.mask=="Interface\\Buttons\\WHITE8X8")
combat=true
-- A retry scheduled out of combat must also defer when combat starts.
timers[1](); local count=minimap.calls
for i=1,5 do mod:ApplyMask() end
assert(minimap.calls==count and #events==1)
env.isSquare=false
mod:ApplyMask()
combat=false; events[1].callback(events[1])
assert(minimap.mask==186178 and not events[1].event)
-- Old delayed requests cannot reinstate an earlier theme's mask.
for _,fn in ipairs(timers) do fn() end
assert(minimap.mask==186178)
combat=true; mod:ApplyMask(); mod.db.enable=false
combat=false; count=minimap.calls; events[1].callback(events[1]); assert(minimap.calls==count)
-- Test the real renderer entry guards and coalesced recovery queue.
local vt={}; env.KT={VisualThemes=vt}
source=read("KullThranUI/Modules/VisualThemes/ThemeClientAssets.lua")
a=assert(source:find("function KT.VisualThemes:DeferUnitFrameArt",1,true))
b=assert(source:find("function KT.VisualThemes:ApplyClassicUnitFrameArt",a,true))
chunk=assert(loadstring(source:sub(a,b-1))); setfenv(chunk,env); chunk()
for _,method in ipairs({"ApplyClassicUnitFrameArt","ApplyForeverUnitFrameArt"}) do
 a=assert(source:find("function KT.VisualThemes:"..method.."(",1,true))
 b=assert(source:find(method=="ApplyClassicUnitFrameArt" and "    local host =" or "    local renderedTheme =",a,true))
 chunk=assert(loadstring(source:sub(a,b-1).."end")); setfenv(chunk,env); chunk()
end
local target={CreateTexture=function() error("art created in combat") end}
local region={}
combat=true
vt:ApplyForeverUnitFrameArt(target,region,"target")
vt:ApplyClassicUnitFrameArt(target,region,"focus")
assert(#events==2 and vt._pendingUnitFrameArt[target].unit=="focus")
local updates=0
function target._refreshForeverMetadata() assert(not combat); updates=updates+1 end
combat=false; events[2].callback(events[2])
assert(updates==1 and next(vt._pendingUnitFrameArt)==nil)
-- Direct renderer clients without a metadata updater also get one final request.
combat=true; target._refreshForeverMetadata=nil
vt:ApplyForeverUnitFrameArt(target,region,"target")
function vt:ApplyForeverUnitFrameArt(frame,r,unit) assert(not combat); assert(frame==target and r==region and unit=="target"); updates=updates+1 end
combat=false; events[2].callback(events[2]); assert(updates==2)
-- Execute the complete real metadata function in combat: no layout work occurs.
source=read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua")
a=assert(source:find("    local function RefreshForeverMetadata()",1,true))
b=assert(source:find("    local function QueueForeverMetadataRefresh()",a,true))
chunk=assert(loadstring(source:sub(a,b-1).."return RefreshForeverMetadata"))
setfenv(chunk,env); local refresh=chunk()
env.frame={unit="target"}
local badgeUpdates=0
local pvpUpdates=0
env.RefreshPvPIcon=function(unit) assert(unit=="target");pvpUpdates=pvpUpdates+1 end
env.ns={RefreshLevelBadgeVisibility=function(_,unit) assert(unit=="target");badgeUpdates=badgeUpdates+1 end}
combat=true; refresh(); combat=false
assert(pvpUpdates==1,"combat refresh must update the PvP icon")
assert(badgeUpdates==1,"combat refresh must update level visibility while skipping geometry")
print("PASS: protected minimap visibility avoided; mask retries and art updates deferred/coalesced through combat")
