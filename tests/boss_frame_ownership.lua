local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames.lua"))
local source=f:read("*a");f:close()
source=source:gsub("\r\n","\n")
local first=assert(source:find("function Mod:IsUnitFramesBossActive()",1,true))
local last=assert(source:find("function Mod:GetContainerSize(mode, count)",first,true))

local encounter=true
local Mod={testMode={}}
local env=setmetatable({
    Mod=Mod,
    IsEncounterInProgress=function() return encounter end,
    GetLiveGroupMode=function() return nil end,
    IsRaidMode=function() return false end,
    IsInRaid=function() return false end,
},{__index=_G})
local chunk=assert(loadstring(source:sub(first,last-1)))
setfenv(chunk,env)
chunk()

local bossDB={enable=true}
function Mod:GetModeDB() return bossDB end
function Mod:HasActiveTestMode() return false end
function Mod:IsArenaContext() return false end

local function ufBoss(unit)
    return {GetAttribute=function(_,key) if key=="unit" then return unit end end}
end

-- Unit frames module not loaded: the party boss pool shows the encounter.
_G.KullThranUI_UF_Boss1=nil
assert(Mod:GetModeVisibility("boss")==true,"boss pool shows when nothing else draws bosses")

-- Unit frames boss frames bound to boss1: only one frame per boss.
_G.KullThranUI_UF_Boss1=ufBoss("boss1")
assert(Mod:GetModeVisibility("boss")==false,"boss pool must not duplicate the unit frames bosses")

-- Unit frames boss frames disabled (unit attribute cleared): pool takes over.
_G.KullThranUI_UF_Boss1=ufBoss(nil)
assert(Mod:GetModeVisibility("boss")==true,"boss pool returns when unit frames bosses are off")

-- No encounter: hidden either way.
encounter=false
assert(Mod:GetModeVisibility("boss")==false)

-- The boss test preview still works while the unit frames own the bosses.
encounter=true
_G.KullThranUI_UF_Boss1=ufBoss("boss1")
Mod.testMode.boss=true
assert(Mod:GetModeVisibility("boss")==true,"test mode preview stays available")
Mod.testMode.boss=nil
_G.KullThranUI_UF_Boss1=nil

print("boss_frame_ownership: ok")
