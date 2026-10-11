local root = arg[1] or "."
local function read(path)
    local f = assert(io.open(root .. "/" .. path)); local s = f:read("*a"); f:close(); return s
end
local assets = read("KullThranUI/Modules/VisualThemes/ThemeClientAssets.lua")
local KT = {VisualThemes={}}
local env = setmetatable({KT=KT,C_Texture={GetAtlasInfo=function() return nil end}}, {__index=_G})
local chunk = assert(loadstring(assets:sub((assert(assets:find("-- Original Forever swing sheet",1,true))))))
setfenv(chunk,env);chunk()
local vt=KT.VisualThemes
local f=assert(io.open(root.."/KullThranUI/Libraries/texture/media/resourcebars/UISwingTimerBar-Forever.blp","rb"))
assert(f:read(4)=="BLP2");f:close()
local function texture()
 local t={}
 function t:SetTexture(file) self.file=file;self.atlas=nil end
 function t:SetAtlas(name) self.atlas=name;self.file=nil end
 function t:SetTexCoord(...) self.coords={...} end
 return t
end
for name, region in pairs(vt.ForeverSwingRegions) do
 local info=assert(vt:GetStyleAtlasInfo(name));assert(info.packaged)
 assert(info.leftTexCoord==region[1]/512 and info.bottomTexCoord==region[4]/256)
 assert(info.width>0 and info.height>0)
 local t=texture();assert(vt:ApplyStyleAtlas(t,name));assert(t.file==info.file and not t.atlas)
end
assert(not vt:GetStyleAtlasInfo("unknown") and not vt:ApplyStyleAtlas(texture(),"unknown"))
local native={file=123,width=213,height=15}
env.C_Texture.GetAtlasInfo=function() return native end
assert(vt:GetStyleAtlasInfo("ui-swingtimerbar-frame")==native)
local t=texture();assert(vt:ApplyStyleAtlas(t,"ui-swingtimerbar-frame"));assert(t.atlas=="ui-swingtimerbar-frame")
env.C_Texture.GetAtlasInfo=function() error("unavailable") end
assert(vt:GetStyleAtlasInfo("ui-swingtimerbar-frame").packaged)
-- Additional windows inherit only appearance, save independent choices for
-- each theme, and restore KUI when returning from a stock style.
local source=read("KullThranUI/Modules/Enhancements/Enhancements_DamageMeter.lua")
local start=assert(source:find("function Mod.SyncDamageMeterWindowTheme",1,true))
local stop=assert(source:find("local function GetFrameConfig",start,true))
local Mod={};local cfgEnv=setmetatable({Mod=Mod},{__index=_G})
chunk=assert(loadstring(source:sub(start,stop-1)));setfenv(chunk,cfgEnv);chunk()
local primary={barTexture="retail-material",showBackground=true}
local windows={}
for i=1,5 do
 windows[i]={barTexture="custom-"..i,showBackground=false,width=200+i,mode="healingDone",position={x=i},dock={target="main"}}
 local cfg=windows[i];local pos,dock=cfg.position,cfg.dock
 Mod.SyncDamageMeterWindowTheme(cfg,primary,"retail")
 assert(cfg.barTexture==primary.barTexture and cfg.showBackground)
 assert(cfg.width==200+i and cfg.position==pos and cfg.dock==dock and cfg.mode=="healingDone")
 cfg.barTexture="retail-choice-"..i
 primary.barTexture="classic-material"
 Mod.SyncDamageMeterWindowTheme(cfg,primary,"classic")
 assert(cfg.barTexture=="classic-material")
 Mod.SyncDamageMeterWindowTheme(cfg,primary,"kui")
 assert(cfg.barTexture=="custom-"..i and cfg.showBackground==false)
 Mod.SyncDamageMeterWindowTheme(cfg,primary,"retail")
 assert(cfg.barTexture=="retail-choice-"..i)
 primary.barTexture="retail-material"
end
local new={barTexture=primary.barTexture,showBackground=true}
Mod.SyncDamageMeterWindowTheme(new,primary,"retail");assert(new.barTexture==primary.barTexture)
assert(Mod.SyncDamageMeterWindowTheme(primary,primary,"forever")==primary)
print("PASS: packaged Forever artwork without client atlases; all secondary-window theme inheritance, independent settings and restoration")

-- Execute the real refresh entry point and check all additional windows receive
-- a style repaint, even when hidden. Layout and session methods remain separate.
local paints={}
Mod.additionalDamageMeterFrames=windows
Mod.damageMeterFrame=primary
function Mod:RegisterDamageMeterMover() end
function Mod:GetDamageMeterFrame() return self.damageMeterFrame end
function Mod:RestoreAdditionalDamageMeterWindows() end
function Mod:RefreshDamageMeterStyle(_,frame) paints[frame or self.damageMeterFrame]=true end
function Mod:ApplyDamageMeterPosition() end
function Mod:InvalidateDamageMeterDataCache() end
function Mod:RefreshVisibleDamageMeterWindows() end
function Mod:StopDamageMeterLiveRefresh() end
cfgEnv.IsDamageMeterModuleEnabled=function() return true end
cfgEnv.UnitAffectingCombat=function() return false end
start=assert(source:find("function Mod:RefreshDamageMeter()",1,true))
chunk=assert(loadstring(source:sub(start)));setfenv(chunk,cfgEnv);chunk()
Mod:RefreshDamageMeter()
assert(paints[primary])
for _,cfg in ipairs(windows) do assert(paints[cfg]) end
print("PASS: real Damage Meter refresh repaints primary and all five additional-window instances")
