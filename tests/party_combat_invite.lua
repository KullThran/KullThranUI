local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames.lua"))
local source=f:read("*a");f:close()
source=source:gsub("\r\n","\n")
local first=assert(source:find("function Mod:HideRosterMode(mode)",1,true))
local last=assert(source:find("function Mod:RefreshRosterLayout(mode)",first,true))

local combat=false
local inRaid=false
local existing={}
local Mod={frames={},testMode={}}
local env=setmetatable({
    Mod=Mod,
    InCombatLockdown=function() return combat end,
    IsInRaid=function() return inRaid end,
    IsUnitUsable=function(unit) return existing[unit]==true end,
},{__index=_G})
local chunk=assert(loadstring(source:sub(first,last-1)))
setfenv(chunk,env)
chunk()

local calls={positioned={},painted={}}
function Mod:IsArenaContext() return false end
function Mod:PositionFrame(frame,_,index,count) calls.positioned[#calls.positioned+1]={frame=frame,index=index,count=count} end
function Mod:SetFrameUnit(frame,unit) frame.unit=unit; return true end
function Mod:UpdateFrameVisual(frame) calls.painted[#calls.painted+1]=frame end
function Mod:UpdateFrameRange() end

local function frames(n)
    local list={}
    for i=1,n do list[i]={name="f"..i} end
    return list
end
local container={Hide=function() end}

-- Centered party layout of a duo: { [2]=party1, [3]=player }. The length
-- operator may report 0 for this table, which hid the whole container.
local units={}
units[#units+1]="party1";units[#units+1]="player"
for i=1,#units do units[i]=nil end
units[3]="player";units[2]="party1"
assert(Mod:CountRosterUnits(units)==2,"holes in a centered layout still count as occupants")
assert(Mod:CountRosterUnits({})==0)
assert(Mod:CountRosterUnits(nil)==0)

-- Solo out of combat: every free slot is pre-bound to a party token so the
-- secure UnitWatch can reveal a member that joins during combat.
local list=frames(5)
local solo={}
solo[3]="player"
assert(Mod:BindPartyStandbyFrames("party",container,list,solo,5,true)==true)
assert(list[1].unit=="party1" and list[2].unit=="party2" and list[4].unit=="party3" and list[5].unit=="party4")
assert(list[3].unit==nil,"occupied slot is left to the roster pass")
for _,i in ipairs({1,2,4,5}) do assert(list[i]._ktStandby==true and list[i].mode=="party") end
assert(#calls.positioned==4,"standby slots receive an anchor before combat")

-- Tokens already shown are never duplicated.
list=frames(5)
local duo={}
duo[2]="party1";duo[3]="player"
Mod:BindPartyStandbyFrames("party",container,list,duo,5,true)
for _,frame in ipairs(list) do assert(frame.unit~="party1") end
assert(list[1].unit=="party2" and list[4].unit=="party3" and list[5].unit=="party4")

-- No binding while locked, in raids, for other modes or when hidden.
combat=true
assert(Mod:BindPartyStandbyFrames("party",container,frames(5),{},0,true)==false)
combat=false
inRaid=true
assert(Mod:BindPartyStandbyFrames("party",container,frames(5),{},0,true)==false)
inRaid=false
assert(Mod:BindPartyStandbyFrames("raid",container,frames(5),{},0,true)==false)
assert(Mod:BindPartyStandbyFrames("party",container,frames(5),{},0,false)==false)
Mod.testMode.party=true
assert(Mod:BindPartyStandbyFrames("party",container,frames(5),{},0,true)==false)
Mod.testMode.party=nil

-- In combat, a member who appears in a standby slot is painted.
list=frames(5)
Mod.frames.party=list
Mod:BindPartyStandbyFrames("party",container,list,solo,5,true)
existing.party1=true
calls.painted={}
combat=true
Mod:PaintStandbyFrames()
assert(#calls.painted==1 and calls.painted[1]==list[1])

-- Leaving party mode releases the standby bindings (out of combat only).
Mod:HideRosterMode("party")
assert(list[1].unit=="party1","bindings are kept during lockdown")
combat=false
Mod:HideRosterMode("party")
for _,frame in ipairs(list) do assert(frame._ktStandby==nil) end
assert(list[1].unit==nil and list[2].unit==nil)

-- Wiring in the live roster paths.
local function body(name)
    local s=assert(source:find("function Mod:"..name.."(",1,true))
    local e=assert(source:find("\nend\n",s,true))
    return source:sub(s,e)
end
local refreshLive=body("RefreshLiveRoster")
assert(refreshLive:find("self.pendingRoster = true\n        self:PaintStandbyFrames()",1,true),"combat roster update paints standby frames")
local refreshLayout=body("RefreshRosterLayout")
assert(refreshLayout:find("frame:GetNumPoints() == 0",1,true),"newly occupied slots are anchored")
assert(refreshLayout:find("self:CountRosterUnits(units) > 0 or hasStandby",1,true))
assert(not refreshLayout:find("#units > 0",1,true))
local applyLayout=body("ApplyLayout")
assert(applyLayout:find("self:BindPartyStandbyFrames(mode, container, frames, units, layoutCount, visible)",1,true))
assert(not applyLayout:find("#units > 0",1,true))
print("party_combat_invite: ok")
