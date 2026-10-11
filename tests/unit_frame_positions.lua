local root = arg[1] or "."
local f = assert(io.open(arg[2] or (root .. "/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua")))
local source = f:read("*a"):gsub("\r\n", "\n"); f:close()
local function extract(first, last)
    local a = assert(source:find(first, 1, true)); local b = assert(source:find(last, a, true))
    return source:sub(a,b-1)
end
local frame = {scale=1,width=200,height=60,scripts={}}
function frame:GetScale() return self.scale end
function frame:SetScale(v) self.scale=v end
function frame:GetWidth() return self.width end
function frame:GetHeight() return self.height end
function frame:ClearAllPoints() self.point=nil end
function frame:SetPoint(...) self.point={...} end
function frame:GetPoint() return unpack(self.point or {"CENTER",{},"CENTER",-999,-999}) end
function frame:GetScript(k) return self.scripts[k] end
function frame:SetScript(k,v) self.scripts[k]=v end
local db={profile={positions={player={point="CENTER",x=-300,y=-145}},player={frameScale=100}}}
local unlock={pendingPositions={}}
local kt={db={profile={editMode={frames={}}}},defs={}}
function kt:GetModule() return unlock end
function kt.RegisterUnlockElement(key,def) kt.defs[key]=def end
local combat,queuedLayout=false,0
local env=setmetatable({KT=kt,db=db,frames={player=frame},UIParent={},ns={QueueUnitFrameLayoutRefresh=function() queuedLayout=queuedLayout+1 end},SCALE_ANIM_DURATION=.15,
    InCombatLockdown=function() return combat end,
    defaults={profile={positions={player={point="CENTER",x=-300,y=-145}}}},
    GetSettingsForUnit=function(k) return db.profile[k] end, UpdateBordersForScale=function() end}, {__index=_G})
local code=extract("local function ApplyFramePosition(frame, unit)","-- Recalculate all element sizes")
    .. extract("local function ApplyFrameScaleCentered(frame, unit, newScale, animate)","-- ToggleLock removed")
    .. extract("local function RegisterUnitFramesWithEditMode()","local function SetupOptionsPanel()")
    .. "\nreturn ApplyFramePosition, ApplyFrameScaleCentered, RegisterUnitFramesWithEditMode"
local chunk=assert(loadstring(code)); setfenv(chunk,env)
local position,scale,register=chunk(); register()
local def=assert(kt.defs.unitframes_player)
local function near(a,b) assert(math.abs(a-b)<.00001,tostring(a).." ~= "..tostring(b)) end
-- Restoration must save its arguments, never the stale live frame's point.
def.savePosition(nil,"TOPLEFT","CENTER",170,-220,1)
assert(db.profile.positions.player.x==170 and db.profile.positions.player.y==-220)
def.applyPosition(); assert(frame.point[3]=="CENTER"); near(frame.point[4],170)
-- Native and canonical stores retain the capture coordinates across scale cycles.
local saved=db.profile.positions.player
local canonical=kt.db.profile.editMode.frames.unitframes_player
for _,new in ipairs({1.32,.8,1.5,1}) do
    db.profile.player.frameScale=new*100
    scale(frame,"player",new,true)
    for i=1,20 do local tick=frame:GetScript("OnUpdate"); if tick then tick(frame,.02) end end
    near(frame.point[4]*new+frame.width*new/2,270)
    near(frame.point[5]*new-frame.height*new/2,-250)
    assert(saved.x==170 and saved.y==-220 and canonical.x==170 and canonical.y==-220)
end
-- Interrupted animations derive from the same saved anchor.
scale(frame,"player",1.4,true); frame:GetScript("OnUpdate")(frame,.03)
scale(frame,"player",.9,true)
for i=1,20 do local tick=frame:GetScript("OnUpdate"); if tick then tick(frame,.02) end end
near(frame.point[4]*.9+frame.width*.9/2,270)
-- No refresh may replace an uncommitted drag.
unlock.pendingPositions.unitframes_player={x=420,y=-360}
frame:SetPoint("TOPLEFT",env.UIParent,"TOPLEFT",420,-360)
position(frame,"player"); near(frame.point[4],420)
local dragScale=frame:GetScale(); scale(frame,"player",1.6,true); near(frame:GetScale(),dragScale)
unlock.pendingPositions={}
-- A drag beginning during an existing animation also retains its live scale.
scale(frame,"player",1.4,true)
frame:GetScript("OnUpdate")(frame,.03)
local midScale=frame:GetScale()
unlock.pendingPositions.unitframes_player={x=420,y=-360}
for i=1,20 do local tick=frame:GetScript("OnUpdate"); if tick then tick(frame,.02) end end
near(frame:GetScale(),midScale)
unlock.pendingPositions={}
-- Explicit mover scale updates the settings, avoiding a subsequent reload reversal.
def.setScale(nil,1.2); near(db.profile.player.frameScale,120)
-- Reset clears the override and restores shipped offsets without erasing scale.
def.resetPosition(); assert(not kt.db.profile.editMode.frames.unitframes_player)
near(frame.point[4],-300); near(frame.point[5],-145)
-- A new profile rebind must use its own values, not cached old coordinates.
db.profile={positions={player={point="CENTER",x=-40,y=80}},player={frameScale=120}}
position(frame,"player"); near(frame.point[4],-40); near(frame.point[5],80)
-- Boss stacking must preserve distinct relative anchors and the resolved scale.
local boss1=setmetatable({scale=1.3,width=200,height=60,scripts={}}, {__index=frame})
local boss2=setmetatable({scale=1.3,width=200,height=60,scripts={}}, {__index=frame})
env.frames.boss1=boss1; env.frames.boss2=boss2
db.profile.positions.boss={point="RIGHT",x=-326,y=251}
register()
kt.defs.unitframes_boss.savePosition(nil,"TOPRIGHT","CENTER",350,90,1)
kt.defs.unitframes_boss.applyPosition()
assert(boss1.point[3]=="CENTER" and boss2.point[3]=="CENTER")
near(boss1.point[5]-boss2.point[5],60)
assert(db.profile.positions.boss.x==350 and db.profile.positions.boss.y==90)
print("PASS: unit frame save/restore, relative anchors, scale cycles, interrupted animation, pending drag, reset and profile switch")

local point,oldScale=frame.point,frame.scale
combat=true;position(frame,"player");scale(frame,"player",2,false)
assert(frame.point==point and frame.scale==oldScale and queuedLayout==2,
    "combat position/scale must queue restoration without changing protected geometry")
combat=false
print("PASS: protected position and scale deferred during combat")
