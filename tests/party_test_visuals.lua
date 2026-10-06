local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames.lua"));local source=f:read("*a");f:close()
local a=assert(source:find("local function GetTestUnitData(",1,true));local b=assert(source:find("local function GetSpecInfo(",a,true))
local dataCode=source:sub(a,b-1)
a=assert(source:find("function Mod:RandomizeTestClasses()",1,true));b=assert(source:find("function Mod:SetTestMode(",a,true))
local shuffleCode=source:sub(a,b-1)
for _,forever in ipairs({true,false}) do
    local ns={}
    local mod={}
    local env=setmetatable({ns=ns,Mod=mod,IS_FOREVER_CLIENT=forever,
        TEST_UNITS={{name="Sample",class="PALADIN",role="DAMAGER",health=0.9,isPlayer=true}},
        UnitClass=function()return "Druid","DRUID" end,UnitName=function()return "Actual Player" end},{__index=_G})
    local fn=assert(loadstring(shuffleCode..dataCode.."\nreturn GetTestUnitData"));setfenv(fn,env);local sample=fn()
    mod:RandomizeTestClasses()
    local seen={}
    for index=1,40 do
        local u=sample({index=index},"party")
        assert(not u.isPlayer,"sample template does not mark a different member as player")
        assert(u.class==ns.PF_TestClassOverrides[index],"test and preview use the same class rotation")
        assert(u.class==sample({index=index},"party").class,"test class remains stable during animation")
        seen[u.class]=true
    end
    local total=0;for _ in pairs(seen)do total=total+1 end
    assert(total==(forever and 9 or 13),"client class pool is complete")
    local player=sample({index=3,isPlayer=true},"party")
    assert(player.class=="DRUID" and player.name=="Actual Player" and player.isPlayer)
end
-- Execute the test-frame color branch with a configured absorb tint.
a=assert(source:find("        local absorbColor = db.absorbBarColor or DEFAULT_ABSORB_COLOR",1,true))
b=assert(source:find("        frame.absorb:SetMinMaxValues",a,true))
local apply=assert(loadstring(source:sub(a,b-1)))
local actual
local env={db={absorbBarColor={r=0.2,g=0.4,b=0.6,a=0.5}},DEFAULT_ABSORB_COLOR={r=1,g=1,b=1,a=1},
    frame={absorb={SetStatusBarColor=function(_,...)actual={...}end}}}
setfenv(apply,env);apply()
assert(actual[1]==0.2 and actual[2]==0.4 and actual[3]==0.6 and actual[4]==0.5,"Party Test respects custom absorb colors")
print("party_test_visuals: player metadata, shared class rotation, client pools and absorb colors passed")
