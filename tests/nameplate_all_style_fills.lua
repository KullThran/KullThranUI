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
local classic="Interface\\TargetingFrame\\UI-StatusBar"
local kui="Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\MelliReforged.tga"
local forever="Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga"
local function bar()
 local b=region()
 function b:SetStatusBarTexture(path)
  self.fill=self.fill or region(self)
  self.fill.texture=path;self.fill.atlas=nil
 end
 b:SetStatusBarTexture("old")
 function b.fill:SetTexCoord(...) self.coords={...} end
 function b.fill:SetAtlas(name) self.atlas=name;self.coords={.1,.8,.2,.7} end
 return b
end
local function apply(p,style)
 theme=style
 -- Exercise both the profile texture pass and the final skin writer.
 profile.healthBarTexture="Blizzard";profile.castBarTexture="Blizzard"
 profile.friendlyPlayerHealthTexture="Blizzard";profile.friendlyNPCHealthTexture="Blizzard"
 ns.ApplyHealthBarTexture(p);ns.ApplyCastBarTexture(p);ns.ApplyThemeSkin(p)
end
local function expect(p,style)
 for key,b in pairs({health=p.health,cast=p.cast}) do
  local fill=b.fill
  if style=="classic" then assert(fill.texture==classic and not fill.atlas)
  elseif style=="kui" then assert(fill.texture==kui and not fill.atlas)
  else
   assert(fill.atlas==(key=="cast" and "UI-CastingBar-Full-Standard" or "UI-HUD-CoolDownManager-Bar"))
   assert(fill.texture~=classic and fill.coords[1]==.1,"Retail atlas crop must be retained")
  end
  if style=="classic" or style=="kui" then assert(fill.coords[1]==0 and fill.coords[2]==1,"old atlas crop leaked") end
 end
 if style=="kui" and p._skinHealth then
  assert(not p._skinHealth.shown and not p._skinHealth.bg.shown and not p._skinHealth.interior.shown)
 end
end
for _,from in ipairs({"kui","classic","forever","retail"}) do
 for _,to in ipairs({"kui","classic","forever","retail"}) do
  local p={health=bar(),cast=bar(),healthBG=region(),castBG=region(),borderFrame=region(),_simpleBorderFrame=region()}
  for repeatIndex=1,3 do apply(p,from);expect(p,from);apply(p,to);expect(p,to) end
 end
end
local asset=assert(io.open(root.."/KullThranUI/Libraries/texture/MelliDark.tga","rb"));asset:close()
print("PASS: all 16 style transitions repeated; real fill paths, Retail atlas/crop, Classic exclusivity and native background cleanup")
