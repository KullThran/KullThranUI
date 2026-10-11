local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_CastBar/Modules/CastBar/CastBar.lua"))
local source=f:read("*a");f:close()
source=source:gsub("\r\n","\n")
local first=assert(source:find("function Mod:ResyncOrHideBar()",1,true))
local last=assert(source:find("function Mod:UNIT_SPELLCAST_STOP(",first,true))

local now,casting,channeling=100,nil,nil
local Mod={bar={casting=true,castID="A"},hidden=0,started={}}
local env=setmetatable({
    Mod=Mod,GetTime=function() return now end,
    UnitCastingInfo=function() if casting then return unpack(casting) end end,
    UnitChannelInfo=function() if channeling then return unpack(channeling) end end,
},{__index=_G})
local chunk=assert(loadstring(source:sub(first,last-1)))
setfenv(chunk,env)
chunk()
function Mod:DebugCastBar() end
function Mod:HideBarNow() self.hidden=self.hidden+1; self.bar.casting=false; self.bar.castID=nil end
function Mod:UNIT_SPELLCAST_START(_,_,id) self.started[#self.started+1]=id; self.bar.castID=id end
function Mod:UNIT_SPELLCAST_CHANNEL_START() end

-- Stop of the previous cast while a second one is already running: keep the bar.
casting={"B","","",99000,101500,false,"B",false,2}
Mod:HandleCastStop("A")
assert(Mod.hidden==0 and Mod.started[1]=="B","chained cast must stay visible")

-- Stray failed event while the same cast is still running: keep the bar.
Mod.bar.casting=true; Mod.bar.castID="B"; Mod.started={}
Mod:HandleCastFailed("B")
assert(Mod.hidden==0 and Mod.started[1]=="B","failed event mid-cast must not hide")

-- Real end or interrupt: nothing left to show, hide.
casting=nil
Mod.bar.casting=true; Mod.bar.castID="B"
Mod:HandleCastStop("B")
assert(Mod.hidden==1,"finished cast must hide")
casting={"C","","",99000,100020,false,"C",false,3}
Mod.bar.casting=true; Mod.bar.castID="C"
Mod:HandleCastStop("C")
assert(Mod.hidden==2,"cast at its end must hide")
print("castbar_chained_casts ok")
