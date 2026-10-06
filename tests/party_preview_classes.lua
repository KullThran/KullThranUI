local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames_Options.lua"))
local source=f:read("*a");f:close()
local order=assert(source:match("local classOrderForRandomization =.-\nend\n"))
local units=assert(source:match("local PREVIEW_UNITS = %b{}"))
local first=assert(source:find("local function GetPreviewUnit(",1,true))
local last=assert(source:find("local function GetPlayerRealClass()",first,true))
local getUnit=source:sub(first,last-1)
local clients=order:find("IS_FOREVER_CLIENT",1,true) and {true,false} or {false}
for _,forever in ipairs(clients) do
    local env=setmetatable({IS_FOREVER_CLIENT=forever,ns={},UnitClass=function() return "Rogue","ROGUE" end},{__index=_G})
    env._G=env
    local fn=assert(loadstring("local memberColorOverrides={}\n"..units.."\n"..order.."\n"..getUnit.."\nreturn RandomizePartyMemberColors,GetPreviewUnit"))
    setfenv(fn,env)
    local shuffle,sample=fn();shuffle()
    -- Run the page entry code used when navigating back into Party Frames.
    local entry=assert(source:find('KT:RegisterPage("partyframes",',1,true))
    local begin=assert(source:find('function(sc, W)',entry,true))
    local finish=assert(source:find('    local previewMode =',begin,true))
    env.GetMod=function() return {} end
    local calls=0
    env.RandomizePartyMemberColors=function() calls=calls+1;shuffle() end
    local open=assert(loadstring('return '..source:sub(begin,finish-1)..'end'))
    setfenv(open,env);open=open()
    local previous=sample(1,40,"raid",false).class
    for i=1,3 do open({},{});sample(1,40,"raid",false) end
    assert(calls==3,"every module page opening shuffles classes")
    local seen={}
    for i=1,40 do
        local u=sample(i,40,"raid",false);seen[u.class]=true
        assert(u.class==sample(i,40,"raid",false).class,"class remains stable on refresh")
    end
    assert(seen.WARRIOR and seen.ROGUE and seen.PRIEST)
    assert((seen.DEATHKNIGHT==true)==not forever)
    assert((seen.DEMONHUNTER==true)==not forever)
    assert((seen.EVOKER==true)==not forever)
    assert((seen.MONK==true)==not forever)
    local count=0;for _ in pairs(seen) do count=count+1 end
    assert(count==(forever and 9 or 13),"all available classes are in rotation")
    assert(sample(3,4,"party",true).class=="ROGUE","player sample uses actual class")
end
assert(source:find('cardUnit.name, cardUnit.class = "Party Member", GetPlayerRealClass()',1,true))
print("party_preview_classes: player class, stable random samples and client class pools passed")
