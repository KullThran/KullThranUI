local root = arg[1] or "."
local function read(path)
    local f = assert(io.open(root .. "/" .. path)); local s = f:read("*a"); f:close(); return s
end
local mod, unlock = {}, { isOpen = true, pendingPositions = {} }
local kt = { db = { profile = { enhancements = { combatTimer = { enabled = true } } } } }
function kt:GetModule(name) if name == "Enhancements" then return mod elseif name == "UnlockMode" then return unlock end end
function kt:RegisterMovableElements(entries) self.mover = entries[1] end
local text = {}
function text:SetFont() end
function text:GetFont() return "font",22,"OUTLINE" end
function text:SetText(value) self.value=value end
function text:GetStringWidth() return 40 end
function text:SetTextColor() end
local frame = { timerText = text }
function frame:ClearAllPoints() self.point=nil end
function frame:SetPoint(...) self.point={...} end
function frame:SetWidth() end
function frame:SetScale() end
function frame:SetScript() end
function frame:Show() end
function frame:Hide() end
mod.combatTimerFrame=frame
local env = setmetatable({ KT=kt, UIParent={}, format=string.format,
    GetTime=function() return 100 end, InCombatLockdown=function() return false end }, {__index=_G})
env._G=env
local chunk=assert(loadstring(read("KullThranUI/Modules/Enhancements/Enhancements_CombatTimer.lua")))
setfenv(chunk,env); chunk("KullThranUI", {KT=kt, Enhancements=mod})
mod:RegisterCombatTimerMover()
local key="ENH_COMBAT_TIMER"
local function expect(x,y)
    assert(frame.point[4]==x and frame.point[5]==y, "timer reset its position")
end
-- A previously saved Unlock Mode position wins over module defaults on reload/combat.
kt.db.profile.editMode={frames={[key]={point="TOPLEFT",relativePoint="TOPLEFT",x=375,y=-218}}}
mod:InitCombatTimer(); expect(375,-218)
mod:StartCombatTimer(); expect(375,-218)
-- Showing/starting during editing must retain the pending drag without saving it yet.
unlock.pendingPositions[key]={point="TOPLEFT",relativePoint="TOPLEFT",x=412,y=-276}
mod:ShowCombatTimer(); expect(412,-276)
mod:StartCombatTimer(); expect(412,-276)
assert(kt.db.profile.editMode.frames[key].x==375)
-- Exercise the real Unlock Mode commit and timer callbacks together.
local source=read("KullThranUI/Modules/KT_UnlockMode.lua")
local a=assert(source:find("function UM:SaveElementPosition",1,true))
local b=source:find("function UM:BackupPersistedPositionsToGlobal",a,true)
    or assert(source:find("function UM:GetSnapTarget",a,true))
local c=assert(source:find("function UM:CommitPositions",1,true))
local d=assert(source:find("function UM:RevertPositions",c,true))
env.UM=unlock; env.SafeCall=pcall; env.wipe=function(t) for k in pairs(t) do t[k]=nil end end
function unlock:SaveStoredDBPosition(k,point,rp,x,y,scale)
    kt.db.profile.editMode.frames[k]={point=point,relativePoint=rp,x=x,y=y,scale=scale}
end
function unlock:RememberPositionReference() end
function unlock:GetElementDef() return kt.mover end
function unlock:BackupPersistedPositionsToGlobal() end
chunk=assert(loadstring(source:sub(a,b-1)..source:sub(c,d-1))); setfenv(chunk,env); chunk()
unlock:CommitPositions(); unlock.isOpen=false
mod:ShowCombatTimer(); expect(412,-276)
mod:InitCombatTimer(); expect(412,-276)
-- Config creation must persist into the live profile, including after switching profiles.
kt.db.profile={}
kt.mover.savePosition(key,"CENTER","CENTER",-140,0)
mod:ApplyCombatTimerPosition(); expect(-140,0)
assert(kt.db.profile.enhancements.combatTimer.position.x==-140)
kt.db.profile={enhancements={combatTimer={position={point="CENTER",relativePoint="CENTER",x=0,y=150}}},
    editMode={frames={[key]={point="CENTER",relativePoint="CENTER",x=80,y=-90}}}}
mod:StartCombatTimer(); expect(80,-90)
print("combat timer Unlock Mode persistence checks passed")
