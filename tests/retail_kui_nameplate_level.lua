local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_Nameplates/Modules/Nameplates/Nameplates.lua"));local source=f:read("*a");f:close()
local theme="kui"
local ns={NameplateStyle=function() return theme end}
local KT={IS_FOREVER=false}
local methods={}
local queried=0
local env=setmetatable({ns=ns,KT=KT,NameplateFrame=methods,
 KullThranUINameplatesDB={showEnemyLevel=true,showFriendlyLevel=true,showLevel=true},defaults={},
 SyncPlateUnitToken=function() return "nameplate1" end,GetLevelConfigValue=function() return true end,
 SafeUnitLevelText=function() queried=queried+1;return "90" end,
 ApplyLevelTextStyle=function() end,PP={Height=function() end}},{__index=_G})
local code=""
local a=source:find("local function ShouldShowNameplateLevel(isFriendly)",1,true)
if a then
 local b=assert(source:find("ns.ShouldShowNameplateLevel = ShouldShowNameplateLevel",a,true))
 code=source:sub(a,b-1)
else
 a=assert(source:find("function ns.HideRetailKuiLevel()",1,true))
 local b=assert(source:find("function NameplateFrame:UpdateLevel()",a,true))
 code=source:sub(a,b-1)
end
local a=assert(source:find("function NameplateFrame:UpdateLevel()",1,true))
local b=assert(source:find("function NameplateFrame:UpdateClassification()",a,true))
local chunk=assert(loadstring(code..source:sub(a,b-1)));setfenv(chunk,env);chunk()
local level={SetText=function(self,v) self.text=v end,Hide=function(self) self.shown=false end,Show=function(self) self.shown=true end}
local frame=setmetatable({level=level,UpdateLevelAnchor=function() end},{__index=methods})
for _,forever in ipairs({false,true}) do
 KT.IS_FOREVER=forever
 for _,style in ipairs({"kui","classic","forever","retail"}) do
  theme=style;queried=0;frame:UpdateLevel()
  if not forever and style=="kui" then
   assert(not level.shown and level.text=="" and queried==0)
  else assert(level.shown and level.text=="90") end
 end
end
print("PASS: Retail KUI nameplate level hidden; other themes and Forever retained")
