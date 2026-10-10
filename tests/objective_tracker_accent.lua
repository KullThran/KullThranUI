local root=arg[1] or "."
local source=assert(io.open(root.."/KullThranUI_ObjectiveTracker/Modules/Skin.lua")):read("*a")
local first=assert(source:find("local function GetAccent()",1,true))
local last=assert(source:find("local function GetQuestTitleColor()",first,true))
local theme="kui"
local palette={kui={1,0,0.3333},classic={0.86,0.62,0.16},retail={0.78,0.61,0.43},forever={0.862745,0.521569,0.376471}}
local KT={
    db={profile={objectiveTracker={colorMode="accent"},skin={accentColor={r=1,g=0,b=0.3333}}}},
    VisualThemes={GetRenderedTheme=function()return theme end},
    GetStyleAccentRGB=function()return unpack(palette[theme])end,
}
local fn=assert(loadstring(source:sub(first,last-1).."\nreturn GetAccent"))
setfenv(fn,setmetatable({KT=KT},{__index=_G}))
local GetAccent=fn()
local function same(a,b)return math.abs(a-b)<0.001 end
for _,key in ipairs({"kui","classic","retail","forever"})do
    theme=key
    local r,g,b=GetAccent()
    local e=palette[key]
    assert(same(r,e[1]) and same(g,e[2]) and same(b,e[3]),"tracker accent follows the "..key.." style")
end
theme="classic"
KT.db.profile.objectiveTracker.colorMode="custom"
KT.db.profile.objectiveTracker.customColor={r=0.1,g=0.2,b=0.3}
local r,g,b=GetAccent()
assert(same(r,0.1) and same(g,0.2) and same(b,0.3),"custom tracker color still wins outside Forever")
print("objective_tracker_accent: tracker accent follows every visual style")
