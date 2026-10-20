local file = assert(io.open('KullThranUI_CooldownManager/Modules/KUICooldownManager/KUICooldownManager.lua'))
local source = file:read('*a'); file:close()
local combat, protected, layouts, visuals = false, false, 0, 0
local ns, fd, hooks = {_nativeCDMFrameData = {}}, {}, {}
local container = {IsProtected = function() return false end}
local frame = {IsProtected = function() return protected end,
    ClearAllPoints = function(self) self.clears = (self.clears or 0) + 1 end}
function frame:SetPoint(...) self.point = {...}; hooks.SetPoint(self, ...) end
local env = setmetatable({ns=ns, fd=fd, frame=frame,
    InCombatLockdown=function() return combat end,
    hooksecurefunc=function(_, method, fn) hooks[method]=fn end,
    cdmBarFrames={cooldowns=container}, cdmBarIcons={cooldowns={frame}},
    GetHostedBarKeyForViewer=function() return 'cooldowns' end,
    LayoutCDMBar=function() layouts=layouts+1 end,
}, {__index=_G})
local function execute(code) local f=assert(loadstring(code)); setfenv(f,env); f() end
local start=assert(source:find('        hooksecurefunc(frame, "SetPoint", function', 1, true))
local stop=assert(source:find('\n        if frame.OnActiveStateChanged',start,true))
execute(source:sub(start,stop-1))
fd.anchor={'TOPLEFT',container,'TOPLEFT',60,-40}
frame:SetPoint('TOPLEFT',container,'TOPLEFT',0,-40)
assert(frame.point[4]==60, 'same-parent native layout must restore centered row offset')
local clears=frame.clears
frame:SetPoint(unpack(fd.anchor))
assert(frame.clears==clears,'KUI placement must not recurse')
combat=true
frame:SetPoint('TOPLEFT',container,'TOPLEFT',0,0)
assert(frame.point[4]==60 and frame.point[5]==-40,'unprotected combat anchors must stay centered')
protected=true
frame:SetPoint('TOPLEFT',container,'TOPLEFT',0,0)
assert(frame.point[4]==0 and ns._cdmLayoutPending,'protected combat layout must be deferred')
fd.anchor=nil; fd.decorated=false
frame:SetPoint('CENTER',container,'CENTER',0,0)
assert(frame.point[1]=='CENTER','released frames must keep native placement')
ns.NativeCDMHostingEnabled=function() return true end
ns.ApplyNativeCDMVisualState=function() visuals=visuals+1 end
local alphaSyncs=0
ns.SyncNativeCDMBarAlpha=function() alphaSyncs=alphaSyncs+1 end
ns._nativeCDMFrameData[frame]=fd
start=assert(source:find('function ns.ReassertNativeCDMViewerLayout(viewerName)',1,true))
stop=assert(source:find('function ns.NativeCDMViewerLayoutObserved',start,true))
execute(source:sub(start,stop-1))
protected=false; ns._cdmLayoutPending=nil
assert(ns.ReassertNativeCDMViewerLayout('EssentialCooldownViewer'))
assert(layouts==1 and visuals==1,'arena combat must reapply native layout and appearance')
protected=true
container._kuiNativeAlpha=0.5
local syncsBefore=alphaSyncs
assert(not ns.ReassertNativeCDMViewerLayout('EssentialCooldownViewer'))
assert(layouts==1 and ns._cdmLayoutPending)
assert(alphaSyncs==syncsBefore+1 and container._kuiNativeAlpha==nil,
    'protected combat must still restore hosted icon alpha (a late Blizzard Layout at combat start must not leave the row invisible)')
combat=false
assert(ns.ReassertNativeCDMViewerLayout('EssentialCooldownViewer') and layouts==2)
print('PASS: arena combat layout, same-parent offsets, recursion, protected deferral and released frames')

-- Execute the actual grid renderer as icon composition changes in an arena.
local icons = {}
local function noop() end
local function setSize(self,w,h) self.width=w; self.height=h end
local grid={SetSize=setSize, ClearAllPoints=noop, SetPoint=noop, SetAlpha=noop}
local data={enabled=true, iconSize=36, spacing=2, numRows=2, growDirection='RIGHT'}
for i=1,14 do
    icons[i]={shown=true, IsShown=function(self) return self.shown end,
        SetSize=setSize, SetScale=noop, ClearAllPoints=noop, SetPoint=noop, SetAlpha=noop,
        GetFrameLevel=function() return 5 end}
end
env.cdmBarFrames={cooldowns=grid}; env.cdmBarIcons={cooldowns=icons}
env.barDataByKey={cooldowns=data}; env.KUI_CDM={}; env.KT={}
ns.BLIZZ_CDM_FRAMES={cooldowns='EssentialCooldownViewer',utility='UtilityCooldownViewer'}
env.SnapForScale=function(value) return value end
env.wipe=function(t) for k in pairs(t) do t[k]=nil end end
ns.CDM_SetProtectedFrameLayering=noop
ns.CDM_ResolveBarStrata=function() return 'MEDIUM' end
ns.SetCDMIconLayoutPoint=function(icon,point,parent,relativePoint,x,y)
    icon.x=x; icon.y=y
end
combat=true; protected=false
start=assert(source:find('LayoutCDMBar = function(barKey)',1,true))
stop=assert(source:find('\n--  VisualThemes: optional classic',start,true))
execute(source:sub(start,stop-1))
for _, direction in ipairs({'RIGHT','LEFT','DOWN','UP'}) do
    data.growDirection=direction
    for _, count in ipairs({14,13,12,9,3}) do
        for i,icon in ipairs(icons) do icon.shown=i<=count end
        env.LayoutCDMBar('cooldowns')
        local groups={}
        for i=1,count do
            local icon=icons[i]
            local horizontal=direction=='RIGHT' or direction=='LEFT'
            local cross=horizontal and icon.y or icon.x
            local position=horizontal and icon.x or icon.y
            local group=groups[cross] or {min=position,max=position}
            group.min=math.min(group.min,position);group.max=math.max(group.max,position)
            groups[cross]=group
        end
        local midpoint
        for _,group in pairs(groups) do
            local center=(group.min+group.max)/2
            assert(not midpoint or math.abs(center-midpoint)<=0.5,
                direction .. ': partial row lost centering for ' .. count .. ' icons')
            midpoint=center
        end
    end
end
print('PASS: actual grid keeps partial rows centered across arena icon counts and all growth directions')

data.growDirection='RIGHT'; data.numRows=1
for i,icon in ipairs(icons) do icon.shown=i<=8 end
env.KT._unlockActive=true
env.LayoutCDMBar('cooldowns')
local movingWidth=grid.width
assert(#grid._visibleIconsBuf==8,'moving native bars must not truncate their live footprint')
env.KT._unlockActive=false
env.LayoutCDMBar('cooldowns')
assert(grid.width==movingWidth,'leaving Unlock Mode must not expand the dragged bar')
print('PASS: native bar dimensions remain stable while moving and closing Unlock Mode')

assert(source:find('pcall(ns.eventFrame.RegisterEvent, ns.eventFrame, "PVP_MATCH_ACTIVE")',1,true),
    'must subscribe to arena match start')
start=assert(source:find('    if event == "PVP_MATCH_ACTIVE" then',1,true))
stop=assert(source:find('    if event == "PLAYER_REGEN_DISABLED" or',start,true))
local observed={}
ns.NativeCDMViewerLayoutObserved=function(name) observed[name]=true end
env.event='PVP_MATCH_ACTIVE'
execute(source:sub(start,stop-1))
assert(observed.EssentialCooldownViewer and observed.UtilityCooldownViewer and observed.BuffIconCooldownViewer,
    'match start must explicitly restore all three native viewers before combat begins')
print('PASS: opening arena gates requests layout restoration independently of combat transitions')
