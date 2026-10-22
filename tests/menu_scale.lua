local root=arg[1] or "."
local file=assert(io.open(root.."/KullThranUI/Options.lua"))
local source=file:read("*a");file:close()
local first=assert(source:find("-- MENU SCALE BEGIN",1,true),"scale block marker")
local last=assert(source:find("-- MENU SCALE END",first,true),"scale block end marker")
local fn=assert(loadstring(source:sub(first,last-1)..[[
return {SnapMenuScale=SnapMenuScale,InitialMenuScale=InitialMenuScale,
ComputeMenuFrameScale=ComputeMenuFrameScale,MigrateMenuSizeProfile=MigrateMenuSizeProfile,
GetMenuLayoutMetrics=GetMenuLayoutMetrics,MENU_W=MENU_W,MENU_H=MENU_H}]]))
setfenv(fn,setmetatable({},{__index=_G}))
local M=fn()
local function near(a,b)return math.abs(a-b)<1e-6 end

assert(M.MENU_W==1280 and M.MENU_H==900,"fixed 1280x900 window")
assert(near(M.SnapMenuScale(1.111),1.1) and near(M.SnapMenuScale(0.2),0.5) and near(M.SnapMenuScale(9),1.5))
assert(near(M.InitialMenuScale(1080),1.0) and near(M.InitialMenuScale(1440),1.0))
assert(near(M.InitialMenuScale(1600),1.1) and near(M.InitialMenuScale(2160),1.5))
assert(near(M.InitialMenuScale(nil),1.0),"unknown screen -> 100%")

-- 1080p at UI scale 0.64: 1200 x 675 logical units
local s=M.ComputeMenuFrameScale(1200,675,1920,1080,1.0)
assert(near(s,1200/1920),"100% is pixel-perfect")
s=M.ComputeMenuFrameScale(1200,675,1920,1080,1.5)
assert(M.MENU_H*s<=675*0.95+1e-6 and M.MENU_W*s<=1200*0.95+1e-6,"150% on 1080p still fits the screen")
s=M.ComputeMenuFrameScale(3840,2160,3840,2160,0.5)
assert(near(s,0.5),"small scales are not clamped up")

local p={menuCustomWidth=1540,menuCustomHeight=1080,menuPos={"CENTER",10,20}}
M.MigrateMenuSizeProfile(p,1080)
assert(p.menuCustomWidth==nil and p.menuCustomHeight==nil,"old window size dropped")
assert(near(p.menuScale,1.0) and p.menuFixedSizeMigrated,"scale seeded once")
assert(p.menuPos[2]==10,"position kept")
p.menuScale=1.3;M.MigrateMenuSizeProfile(p,2160)
assert(near(p.menuScale,1.3),"migration runs only once")
M.MigrateMenuSizeProfile(nil,1080)

local m=M.GetMenuLayoutMetrics(nil)
assert(m.navWidth==300 and m.topMargin==126 and m.bottomMargin==60)
assert(m.contentInsetLeft==330 and m.contentInsetRight==30 and m.contentWidth==920)
assert(m.contentInsetTop==126 and m.contentInsetBottom==60 and m.navContentWidth==290)
local wide={GetWidth=function()return 1700 end,GetHeight=function()return 1100 end}
assert(M.GetMenuLayoutMetrics(wide).contentWidth==920,"metrics no longer follow the frame size")

assert(not source:find("MENU_SIZE_PRESETS",1,true),"size presets removed")
assert(not source:find("StartSizing",1,true),"resize grip removed")
assert(not source:find("menuCustomWidth = width",1,true),"window size no longer saved")
print("menu_scale: fixed geometry, pixel-perfect scale, screen fit and migration passed")
