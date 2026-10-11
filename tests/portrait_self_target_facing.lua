local root=arg[1] or "."
local f=assert(io.open(arg[2] or (root.."/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua")))
local source=f:read("*a");f:close()
local theme, form, selfTarget="forever",0,true
local playerClass="DRUID"
local settings={player={portraitMode="2d"},target={portraitMode="2d"}}
local ns={SafeCall=function(fn,...) local ok,result=pcall(fn,...);return ok and result end}
local env=setmetatable({ns=ns,db={profile={portraitStyle="circular"}},
    KT={VisualThemes={GetRenderedTheme=function() return theme end}},
    GetShapeshiftForm=function() return form end,
    UnitClass=function() return playerClass,playerClass end,
    UnitIsUnit=function(a,b) return a=="target" and b=="player" and selfTarget end,
    GetSettingsForUnit=function(unit) return settings[unit] end}, {__index=_G})
local a=assert(source:find("local function GetDefaultPortraitFacing",1,true))
local b=assert(source:find("-- Classification artwork is directional.",a,true))
local chunk=assert(loadstring(source:sub(a,b-1).."\nreturn GetPortraitFacing"));setfenv(chunk,env)
local resolver=chunk();env.GetPortraitFacing=resolver
local c=assert(source:find("local function ApplyPortraitFacing",1,true))
local d=assert(source:find("-- Re-resolve class token",c,true))
chunk=assert(loadstring(source:sub(c,d-1).."\nreturn ApplyPortraitFacing"));setfenv(chunk,env)
local apply=chunk()
local texture={SetTexCoord=function(self,...) self.coords={...} end}
for _,style in ipairs({"kui","classic","forever","retail"}) do
    theme=style
    for _,shape in ipairs({0,1}) do
        form=shape;selfTarget=true
        apply(texture,"player",settings.player)
        assert(texture.coords[1]==(shape==0 and 0 or 1) and texture.coords[2]==(shape==0 and 1 or 0),"Player must preserve humanoid/form-specific automatic facing")
        apply(texture,"target",settings.target)
        assert(texture.coords[1]==(shape==0 and 1 or 0) and texture.coords[2]==(shape==0 and 0 or 1),"self-target must mirror the resolved humanoid/form facing")
        selfTarget=false
        local previous=resolver("target",settings.target)
        assert(previous=="flipped", "unrelated NPC must not inherit player's current form facing")
        apply(texture,"target",settings.target)
        assert(texture.coords[1]==(previous=="flipped" and 1 or 0),"NPC facing must remain unchanged")
    end
end
-- Warrior stances and paladin auras can also use the shapeshift bar.
-- They must never select the druid-form texture convention.
form=1
for _,class in ipairs({"WARRIOR","PALADIN","ROGUE"}) do
    playerClass=class
    apply(texture,"player",settings.player)
    assert(texture.coords[1]==0 and texture.coords[2]==1,"a stance is not a druid portrait")
end
playerClass="DRUID"
for _,mode in ipairs({"normal","flipped"}) do
    selfTarget=true
    for _,unit in ipairs({"player","target"}) do
        settings[unit].portraitFacingMode=mode
        apply(texture,unit,settings[unit])
        assert(texture.coords[1]==(mode=="flipped" and 1 or 0),"explicit facing wins")
        settings[unit].portraitFacingMode=nil
    end
end
form=0;selfTarget=true
local previous=resolver("player",settings.player)
apply(texture,"player",settings.player,true)
assert(texture.coords[1]==(previous=="flipped" and 1 or 0),"class artwork must retain its own facing")
texture._classCoords={0.2,0.4,0.6,0.8}
apply(texture,"player",settings.player,true)
assert(texture.coords[1]==0.2 and texture.coords[2]==0.4 and texture.coords[3]==0.6)
print("humanoid, self-target, NPC and druid-form portrait facing checks passed across all styles")
-- Model capture conventions differ: humanoids need mirroring, creature
-- captures already face left. Resolve fresh model data across retargets.
env.KT.PortraitMirrorModels={[101]=true}
local guid, pendingID="humanoid",101
local probe, captures
captures=0
env.UnitGUID=function() return guid end
env.SetPortraitTexture=function(tex) captures=captures+1;tex:SetTexCoord(0,1,0,1) end
env.CreateFrame=function(kind)
 assert(kind=="PlayerModel")
 local p={loads=0}
 function p:SetSize() end
 function p:Hide() end
 function p:SetKeepModelOnHide() end
 function p:SetScript(_,fn) self.onLoaded=fn end
 function p:ClearModel() self.id=nil end
 function p:SetUnit(unit) assert(unit=="target");self.loads=self.loads+1 end
 function p:GetModelFileID() return self.id end
 probe=p;return p
end
local targetTexture={SetTexCoord=texture.SetTexCoord}
selfTarget=false;form=0
apply(targetTexture,"target",settings.target)
assert(probe.loads==1)
probe.id=101;probe.onLoaded(probe)
assert(targetTexture.coords[1]==1 and captures==1,"late humanoid capture is mirrored after native reset")
apply(targetTexture,"target",settings.target)
assert(probe.loads==1,"unchanged portrait does not reload its model each paint")
guid="creature"
apply(targetTexture,"target",settings.target)
assert(probe.id==nil and probe.loads==2,"retarget clears previous model orientation")
probe.id=202;probe.onLoaded(probe)
assert(targetTexture.coords[1]==0,"native left-facing creature must not be flipped right")
form=1;apply(targetTexture,"target",settings.target)
assert(targetTexture.coords[1]==0,"player shapeshift cannot change unrelated creature direction")
guid="other-humanoid"
local before=captures
probe.onLoaded(probe)
assert(captures==before,"obsolete model callback cannot overwrite a newly selected target")
apply(targetTexture,"target",settings.target);probe.id=101;probe.onLoaded(probe)
assert(targetTexture.coords[1]==1,"next humanoid returns to correct left-facing convention")
-- Model/form changes can retain the same GUID and must invalidate the probe.
targetTexture._ktFacingGuid=nil;apply(targetTexture,"target",settings.target)
probe.id=202;probe.onLoaded(probe)
assert(targetTexture.coords[1]==0,"same-unit model change refreshes orientation")
settings.target.portraitFacingMode="flipped"
probe.onLoaded(probe)
assert(targetTexture.coords[1]==1,"late callbacks respect current explicit settings")
settings.target.portraitFacingMode=nil
assert(source:find('if hasStateChanged then self._ktFacingGuid = nil end',1,true))
print("PASS: 2D target model conventions, asynchronous captures, stale callbacks and same-GUID model changes")
