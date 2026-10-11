local root=arg[1] or "."
local file=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames_Styles.lua"))
local source=file:read("*a");file:close()
local cfg={frameWidth=235,frameHeight=41,customHealthColor={r=1,g=1,b=1}}
local mod={db={partyFrameStyle="kui"}}
function mod:GetModeDB() return cfg end
local KT={GetModule=function() return mod end}
local ns={PF_Portrait={}}
local chunk=assert(loadstring(source))
setfenv(chunk,setmetatable({LibStub=function() return {GetAddon=function() return KT end} end,
    InCombatLockdown=function() return false end},{__index=_G}))
chunk("KUI",ns)
local Styles=ns.PF_Styles
-- Fresh profiles and existing profiles grow exactly once. KUI keeps its size.
mod:GetModeDB("party")
local sizes=mod.db.partyFrameSizesByStyle
assert(sizes.kui.frameWidth==235 and sizes.kui.frameHeight==41)
for _,key in ipairs({"retail","forever","classic"}) do
    assert(sizes[key].frameWidth==235*1.25*1.25)
    assert(sizes[key].frameHeight==41*1.25*1.25)
end
mod.db={partyFrameStyle="classic",partyFrameSizesByStyle={
    kui={frameWidth=230,frameHeight=40},classic={frameWidth=300,frameHeight=52},
    retail={frameWidth=280,frameHeight=50},forever={frameWidth=310,frameHeight=54}}}
for n=1,10 do mod:GetModeDB("party") end
assert(cfg.frameWidth==375 and cfg.frameHeight==65)
assert(mod.db.partyFrameSizesByStyle.kui.frameWidth==230)
local function texture()
    local t={}
    function t:ClearAllPoints() self.points=nil;self.all=nil end
    function t:SetPoint(...) self.points={...} end
    function t:SetSize(w,h) self.w,self.h=w,h end
    function t:SetTexture(path) self.texture=path;self.solid=false end
    function t:SetTexCoord(...) self.coords={...} end
    function t:SetVertexColor(...) self.color={...} end
    function t:SetBlendMode(v) self.blend=v end
    function t:SetAllPoints(v) self.all=v end
    function t:SetColorTexture(...) self.solid=true end
    return t
end
local frame={hover=texture()};local host={}
for _,key in ipairs({"retail","forever","classic"}) do
    local art=texture();Styles.SetArt(art,key)
    local g,s=Styles.Geometry(key,375,65)
    Styles.ConfigureHover(frame,key,host,g,s)
    assert(frame.hover.texture==art.texture and not frame.hover.solid)
    assert(frame.hover.points[2]==host and frame.hover.w==g.artW*s and frame.hover.h==g.artH*s)
    for i=1,4 do assert(frame.hover.coords[i]==art.coords[i]) end
    assert(frame.hover.blend=="ADD")
    local _,oldScale=Styles.Geometry(key,300,52)
    assert(math.abs(s/oldScale-1.25)<0.000001,"visible atlas grows 25%, not just its click area")
end
Styles.ConfigureHover(frame,"kui")
assert(frame.hover.solid and frame.hover.all==frame and frame.hover.blend=="BLEND")
print("PASS: party atlas hover, exact 25% visible growth, one-shot migration and KUI restoration")
