local root = arg[1] or "."
local f=assert(io.open(root .. "/KullThranUI_Nameplates/Modules/Nameplates/Nameplates_ThemeSkin.lua"))
local source=f:read("*a");f:close()
local theme="retail"
local function region(parent)
    local r={parent=parent,width=200,height=16,level=1,shown=true,snap=true,bias=1,points={}}
    function r:CreateTexture() return region(self) end
    function r:SetTexture(v) self.texture=v end
    function r:SetAtlas(v) self.atlas=v end
    function r:SetColorTexture() end
    function r:SetVertexColor() end
    function r:SetAllPoints() end
    function r:SetPoint(...) self.points[#self.points+1]={...} end
    function r:ClearAllPoints() self.points={} end
    function r:SetSize(w,h) self.width,self.height=w,h end
    function r:SetHeight(v) self.height=v end
    function r:SetWidth(v) self.width=v end
    function r:GetHeight() return self.height end
    function r:GetFrameLevel() return self.level end
    function r:SetFrameLevel(v) self.level=v end
    function r:SetSnapToPixelGrid(v) self.snap=v end
    function r:SetTexelSnappingBias(v) self.bias=v end
    function r:SetShown(v) self.shown=v end
    function r:Show() self.shown=true end
    function r:Hide() self.shown=false end
    function r:SetStatusBarTexture(v) self.fill=region(self);self.fill.texture=v end
    function r:GetStatusBarTexture() return self.fill end
    return r
end
local ns={}
local env=setmetatable({KullThranUI={VisualThemes={GetRenderedTheme=function() return theme end}},
    CreateFrame=function(_,_,parent) return region(parent) end},{__index=_G})
env._G=env
local stop=assert(source:find("function ns.RefreshThemeSkin()",1,true))
local fn=assert(loadstring(source:sub(1,stop-1)));setfenv(fn,env);fn("test",ns)
local nf=assert(io.open(root.."/KullThranUI_Nameplates/Modules/Nameplates/Nameplates.lua"))
local main=nf:read("*a");nf:close()
local a=assert(main:find("function ns.ResolveNameplateBarTexture(key)",1,true))
local b=assert(main:find("ns.ApplyCastBarTexture = ApplyCastBarTexture",a,true))
local finish=b+#"ns.ApplyCastBarTexture = ApplyCastBarTexture"-1
local profile={healthBarTexture="customEnemy",friendlyPlayerHealthTexture="customPlayer",friendlyNPCHealthTexture="customNPC",castBarTexture="customCast"}
ns.healthBarTextures={customEnemy="EnemyTexture",customPlayer="PlayerTexture",customNPC="NPCTexture",customCast="CastTexture"}
local tenv=setmetatable({ns=ns,db=profile,defaults={},
 UnitCanAttack=function(_,unit) return unit=="enemy" end,
 UnitIsPlayer=function(unit) return unit=="friendPlayer" end,
 ResolveTexturePath=function(lookup,key,fallback) return lookup[key] or fallback end},{__index=_G})
local apply=assert(loadstring(main:sub(a,finish)));setfenv(apply,tenv);apply()
for _,native in ipairs({"classic","forever","retail"}) do
 for _,unit in ipairs({"enemy","friendPlayer","friendNPC","preview"}) do
  local plate={health=region(),healthBG=region(),cast=region(),castBG=region(),borderFrame=region(),_simpleBorderFrame=region()}
  if unit~="preview" then plate.unit=unit end
  local borders=0
  if unit~="preview" then function plate:ApplyBorderStyle() borders=borders+1 end end
  local expected=unit=="friendPlayer" and "PlayerTexture" or unit=="friendNPC" and "NPCTexture" or "EnemyTexture"
  for cycle=1,3 do
   theme="kui";ns.ApplyHealthBarTexture(plate);ns.ApplyCastBarTexture(plate)
   assert(plate.health.fill.texture==expected)
   theme=native;ns.ApplyThemeSkin(plate)
   if native=="classic" then assert(plate.health.fill.texture=="Interface\\TargetingFrame\\UI-StatusBar")
   elseif native=="forever" then assert(plate.health.fill.atlas=="UI-HUD-CoolDownManager-Bar")
   else assert(plate.health.fill.atlas=="UI-HUD-CoolDownManager-Bar") end
   theme="kui";ns.ApplyThemeSkin(plate)
   assert(plate.health.fill.texture==expected,"native fill leaked into KUI "..native.." "..unit)
   assert(plate.cast.fill.texture=="CastTexture","native cast texture leaked into KUI")
   assert(not plate._skinHealth.shown and not plate._skinCast.shown,"native art remains visible")
   assert(not plate._skinHealth.bg.shown and not plate._skinHealth.interior.shown,"bar-owned native backgrounds leaked into KUI")
  end
  if unit~="preview" then assert(borders==3) end
 end
end
-- A texture edited while a native theme is active must win over a stale snapshot.
local plate={health=region(),cast=region()}
theme="classic";ns.ApplyThemeSkin(plate)
profile.healthBarTexture="edited";ns.healthBarTextures.edited="EditedTexture"
theme="kui";ns.ApplyThemeSkin(plate)
assert(plate.health.fill.texture=="EditedTexture")
print("PASS: Classic/Forever/Retail -> KUI restores current health/cast textures for enemy/friendly/reused plates and preview without border methods")

-- Reproduce old KUI slots that still hold Classic/Blizzard values, even on cold login.
local kuiPath="Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\MelliReforged.tga"
local classicPath="Interface\\TargetingFrame\\UI-StatusBar"
ns.healthBarTextures.Blizzard=classicPath
ns.healthBarTextures["Blizzard Raid Bar"]=classicPath
-- A stale SharedMedia/cache entry must not override KUI's bundled default.
ns.healthBarTextures["Melli Reforged"]=classicPath
for _,key in ipairs({"Blizzard","Blizzard Raid Bar",classicPath,"Melli Reforged"}) do
 for _,unit in ipairs({"enemy","friendPlayer","friendNPC","preview"}) do
  profile.healthBarTexture=key;profile.castBarTexture=key
  profile.friendlyPlayerHealthTexture=key;profile.friendlyNPCHealthTexture=key
  local p={health=region(),cast=region()}
  if unit~="preview" then p.unit=unit end
  theme="kui";ns.ApplyThemeSkin(p)
  assert(p.health.fill.texture==kuiPath,"cold KUI still uses native texture: "..key)
  assert(p.cast.fill.texture==kuiPath)
  theme="classic";ns.ApplyThemeSkin(p)
  assert(p.health.fill.texture==classicPath,"Classic should keep its native texture")
  theme="kui";ns.ApplyThemeSkin(p)
  assert(p.health.fill.texture==kuiPath,"KUI inherits Classic saved key after switch")
 end
end
-- The texture lookup follows a replaced active profile instead of a cached local table.
tenv.KullThranUINameplatesDB={healthBarTexture="customEnemy",castBarTexture="customCast"}
local p={health=region(),cast=region()}
theme="kui";ns.ApplyThemeSkin(p)
assert(p.health.fill.texture=="EnemyTexture" and p.cast.fill.texture=="CastTexture")
local asset=assert(io.open(root.."/KullThranUI/Libraries/KUITextures/CustomTextures/MelliReforged.tga","rb"))
assert(#asset:read("*a")>100);asset:close()
print("PASS: real bundled KUI asset replaces stale Classic keys/cache on login, live/preview and profile swaps; Classic/custom textures preserved")
