local root=arg[1] or "."
local file=assert(io.open(root.."/KullThranUI/Options.lua"))
local source=file:read("*a");file:close()
local first=assert(source:find("local function IsScriptProfilingEnabled()",1,true))
local last=assert(source:find("local function StopMenuCpuUsageTicker",first,true))
local now, profiling, cpu, memoryCalls=100,false,1000,0
local env=setmetatable({
    LText=function(text)return text end,
    MENU_HEAVY_PERF_SAMPLE_INTERVAL=10,
    KT={baseName="KullThranUI"},addonName="KullThranUI",
    GetTime=function()return now end,
    GetFramerate=function()return 60 end,
    GetCVarBool=function()return profiling end,
    UpdateAddOnMemoryUsage=function()memoryCalls=memoryCalls+1 end,
    GetAddOnMemoryUsage=function()return 30720 end,
    UpdateAddOnCPUUsage=function()end,
    GetAddOnCPUUsage=function()return cpu end,
},{__index=_G})
local fn=assert(loadstring(source:sub(first,last-1).."\nreturn UpdateMenuCpuUsageText"))
setfenv(fn,env)
local update=fn()
local label={SetText=function(self,text)self.text=text end,SetTextColor=function()end}
local frame={cpuUsageText=label}
update(frame,true)
assert(label.text:find("Mem 30.0 MB",1,true) and label.text:find("60 FPS",1,true),"System Tuning readout keeps memory and FPS")
assert(frame.menuPerfDetails:find("Mem 30.0 MB",1,true) and frame.menuPerfDetails:find("Perf OK",1,true),"full diagnostics retained for tooltip")
now=101;update(frame,false)
assert(memoryCalls==1,"layout does not increase heavy sampling frequency")
profiling=true;update(frame,true)
assert(frame.menuPerfDetails:find("Calibrating",1,true))
now=111;cpu=1100;update(frame,false)
assert(frame.menuPerfDetails:find("CPU 1.0%",1,true) and label.text==frame.menuPerfDetails,"CPU remains visible in System Tuning")
assert(not source:find("local customBgHeaderTint =",1,true),"hard-edged header wash removed")
assert(source:find('frame.searchBox:SetPoint("LEFT", frame, "TOPLEFT", metrics.contentInsetLeft - 4, -49)',1,true),"search follows navigation when resizing")
assert(source:find('searchBox:SetPoint("RIGHT", f._searchHeaderRight, "LEFT", -20, 0)',1,true),"header search extends to size controls")
assert(not source:find("f._perfBox =",1,true) and not source:find("f.cpuUsageText =",1,true),"main menu has no metrics")
local options=assert(io.open(root.."/KullThranUI/Modules/Enhancements/Enhancements_Options.lua")):read("*a")
assert(options:find("KT:CreateAddonPerformanceReadout(parent, -y)",1,true),"metrics are built in System Tuning")
print("menu_header: metrics relocated, full diagnostics, sampling cadence and search alignment passed")

-- The relocated readout starts/stops its own sampler as the tab appears/disappears.
local first=assert(source:find("local function IsScriptProfilingEnabled()",1,true))
local last=assert(source:find("-- ============================================================================",source:find("function KT:CreateAddonPerformanceReadout",1,true),true))
env.MENU_CPU_SAMPLE_INTERVAL=1
env.GetMenuAccentColor=function()return 0.8,0.2,0.4 end
env.KT.FONT_PATH="Avant Garde"
local ticks={}
env.C_Timer={NewTicker=function(interval,callback)
    local ticker={callback=callback,Cancel=function(self)self.cancelled=true end}
    ticks[#ticks+1]=ticker
    return ticker
end}
local function region()
    local r={shown=false,scripts={}}
    function r:CreateFontString()return region()end
    function r:SetFont(path)self.font=path end
    function r:SetText(value)assert(self.font,"font before text");self.text=value end
    function r:IsShown()return self.shown end
    function r:HookScript(event,callback)self.scripts[event]=callback end
    return setmetatable(r,{__index=function(_,key)if key:match("^Set")then return function()end end end})
end
env.CreateFrame=function()return region()end
local init=assert(loadstring(source:sub(first,last-1)));setfenv(init,env);init()
local readout=env.KT:CreateAddonPerformanceReadout(region(),-20)
assert(#ticks==0,"hidden System Tuning does not sample")
readout.shown=true;readout.scripts.OnShow(readout)
assert(#ticks==1 and readout.cpuUsageText.text:find("30.0 MB",1,true))
readout.shown=false;readout.scripts.OnHide(readout)
assert(ticks[1].cancelled and not readout.cpuUsageTicker,"leaving the tab stops its timer")
readout.shown=true;readout.scripts.OnShow(readout)
assert(#ticks==2 and not ticks[2].cancelled)
readout.shown=false;ticks[2].callback()
assert(ticks[2].cancelled,"timer also stops if an ancestor hides")
print("menu_header: relocated readout visibility and sampler lifecycle passed")
