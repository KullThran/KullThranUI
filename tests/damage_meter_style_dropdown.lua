local root=arg[1] or "."
local function read(rel) local f=assert(io.open(root.."/"..rel));local s=f:read("*a");f:close();return s end
local source=read("KullThranUI/Modules/Enhancements/Enhancements_DamageMeter.lua")
local cfg={barTexture="custom",showBackground=false}
local global="retail"
local Mod={refreshes=0}
function Mod:RefreshDamageMeter() self.refreshes=self.refreshes+1 end
local KT={VisualThemes={GetRenderedTheme=function() return global end}}
local env=setmetatable({Mod=Mod,KT=KT,GetConfig=function() return cfg end},{__index=_G})
local a=assert(source:find("function Mod:GetDamageMeterStyle()",1,true))
local b=assert(source:find("-- Only appearance follows",a,true))
local chunk=assert(loadstring(source:sub(a,b-1)));setfenv(chunk,env);chunk()
assert(Mod:GetDamageMeterStyle()=="retail")
assert(not Mod:SetDamageMeterStyle("invalid") and Mod.refreshes==0)
for _,key in ipairs({"forever","classic","kui","retail"}) do
 assert(Mod:SetDamageMeterStyle(key));assert(Mod:GetDamageMeterStyle()==key)
 assert(global=="retail", "module selection must not change global theme")
end
assert(cfg.barTexture=="custom" and cfg.showBackground==false, "per-style appearance restores")
assert(Mod.refreshes==4)
-- Exercise the actual options builder through creation of both dropdowns.
local options=read("KullThranUI/Modules/Enhancements/Enhancements_Options.lua")
a=assert(options:find('local selectedDamageMeterWindow = "main"',1,true))
b=assert(options:find('    _, h = W:Button(container, LText("Create New Window")',a,true))
local dropdowns,rebuilds={},0
local W={}
function W:Dropdown(_,label,_,values,get,set,order)
 dropdowns[label]={values=values,get=get,set=set,order=order};return {},25
end
local uiEnv=setmetatable({Mod=Mod,LText=function(v) return v end,
 CreateDamageMeterLivePreview=function() return {},100 end,
 Refresh=function(opts) assert(opts.rebuild);rebuilds=rebuilds+1 end},{__index=_G})
chunk=assert(loadstring(options:sub(a,b-1)..'\nend\nreturn BuildDamageMeterBlock'))
setfenv(chunk,uiEnv);local build=chunk();build({},W,{damageMeter=cfg})
local style=assert(dropdowns["Visual Style"])
for i,key in ipairs({"kui","retail","forever","classic"}) do assert(style.order[i]==key and style.values[key]) end
style.set("forever");assert(style.get()=="forever" and rebuilds==1 and Mod.refreshes==5)
assert(dropdowns["Configure Window"], "existing window controls remain available")
-- Renderer uses the module style even when the global theme differs.
a=assert(source:find("local METER_SKINS =",1,true));b=assert(source:find("local function SetVerticalGradient",a,true))
chunk=assert(loadstring(source:sub(a,b-1)..'\nreturn GetMeterSkin'))
setfenv(chunk,env);local skin=chunk();local _,key=skin();assert(key=="forever")
print("PASS: four-option meter dropdown, persisted module style, per-style appearance, preview rebuild and independent skin selection")
