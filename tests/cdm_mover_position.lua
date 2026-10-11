local file=assert(io.open('KullThranUI_CooldownManager/Modules/KUICooldownManager/KUICooldownManager.lua'))
local source=file:read('*a');file:close()
local ui={GetSize=function() return 1920,1080 end, GetEffectiveScale=function() return 0.8 end}
local frame={GetSize=function() return 334,40 end,
    GetWidth=function() return 334 end,GetHeight=function() return 40 end,
    ClearAllPoints=function() end}
function frame:SetPoint(point,parent,relative,x,y) self.x=x;self.y=y;self.point=point end
local env=setmetatable({UIParent=ui,frame=frame}, {__index=_G})
local function compile(code) local f=assert(loadstring(code));setfenv(f,env);return f() end
local start=assert(source:find('                translateMoverPosition = function(_, pos)',1,true))
local stop=assert(source:find('                applyPendingPosition = function',start,true))
local callback=source:sub(start,stop-1):match('translateMoverPosition = (.-),%s*$')
local translate=compile('return '..assert(callback))
start=assert(source:find('local function ApplyBarPositionCentered(',1,true))
stop=assert(source:find('local function SaveCDMBarPosition',start,true))
local apply=compile(source:sub(start,stop-1)..'\nreturn ApplyBarPositionCentered')
for _,scale in ipairs({0.75,1,1.32,2}) do
    frame.GetEffectiveScale=function() return 0.8*scale end
    local left,top=500,700
    local pos={point='TOPLEFT',relativePoint='TOPLEFT',x=left/scale,y=(top-1080)/scale,scale=scale}
    local moved=translate(nil,pos)
    local expectedX=(left+334*scale/2-960)/scale
    local expectedY=(top-40*scale/2-540)/scale
    assert(math.abs(moved.x-expectedX)<0.00001 and math.abs(moved.y-expectedY)<0.00001,
        'drag conversion must preserve on-screen center at scale '..scale)
    apply(frame,{point='TOPLEFT',relPoint='TOPLEFT',x=pos.x,y=pos.y})
    assert(math.abs(frame.x-moved.x)<0.00001 and math.abs(frame.y-moved.y)<0.00001,
        'legacy saved corner positions must match live drag geometry')
    apply(frame,{point=moved.point,relPoint=moved.relativePoint,x=moved.x,y=moved.y})
    assert(frame.point=='CENTER' and frame.x==moved.x and frame.y==moved.y,
        'saving and reapplying a drag must preserve center')
end
print('PASS: drag, legacy saved positions and reapply preserve center at 75%, 100%, 132% and 200% scales')
