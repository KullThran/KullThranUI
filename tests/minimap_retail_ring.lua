local root=arg[1] or "."
local function read(path)
    local f=assert(io.open(root.."/"..path,"rb"));local s=f:read("*a");f:close();return s
end
local source=read("KullThranUI_Minimap/Modules/Minimap/Minimap.lua")
local a=assert(source:find("KT.MinimapRingStyles =",1,true))
local b=assert(source:find("function Mod:GetRingStyleKey()",a,true))
local KT={}
local env=setmetatable({KT=KT,C_Texture={GetAtlasInfo=function(name)
    -- Forever's remapped bronze atlas must never influence the Retail crop.
    return {file=8026705,width=253,height=253}
end}}, {__index=_G})
local chunk=assert(loadstring(source:sub(a,b-1)));setfenv(chunk,env);chunk()
local function region()
    local r={}
    function r:ClearAllPoints() self.point=nil end
    function r:SetDesaturated(v) self.desaturated=v end
    function r:SetVertexColor(...) self.color={...} end
    function r:SetAtlas(v) self.atlas=v end
    function r:SetTexture(v) self.texture=v;self.atlas=nil end
    function r:SetTexCoord(...) self.coords={...} end
    function r:SetPoint(...) self.point={...} end
    function r:SetSize(w,h) self.width=w;self.height=h end
    return r
end
local defs={}
for _,def in ipairs(KT.MinimapRingStyles) do defs[def.key]=def end
local ring,tex,target=region(),region(),region()
local retail=defs.retail
assert(retail.file:find("UIMinimap-Retail.blp",1,true) and not retail.atlases)
for _,diameter in ipairs({40,140,198,260,360}) do
    assert(KT.DrawMinimapRing(retail,ring,tex,target,diameter))
    assert(tex.texture==retail.file and not tex.desaturated)
    assert(tex.color[1]==1 and tex.color[2]==1 and tex.color[3]==1)
    assert(math.abs(ring.width-215*diameter/198)<.000001 and math.abs(ring.height-226*diameter/198)<.000001)
    assert(tex.coords[1]==1/512 and tex.coords[2]==439/512)
    assert(tex.coords[3]==36/512 and tex.coords[4]==496/512)
    assert(ring.point[2]==target and ring.point[4]==0 and ring.point[5]==0)
end
assert(KT.DrawMinimapRing(defs.forever,ring,tex,target,198))
assert(tex.texture==defs.forever.file and defs.forever.file:find("UI-HUD-Minimap-Frame-C60.blp",1,true) and ring.width==253)
assert(KT.DrawMinimapRing(defs.classic,ring,tex,target,140))
assert(ring.width==192 and ring.height==192 and ring.point[4]==-8 and ring.point[5]==-24)
assert(KT.DrawMinimapRing(retail,ring,tex,target,198))
assert(not tex.atlas and tex.color[2]==1 and ring.height==226)
local asset=read("KullThranUI/Libraries/texture/media/minimap/UIMinimap-Retail.blp")
assert(asset:sub(1,4)=="BLP2" and #asset==1049748)
local options=read("KullThranUI_Minimap/Modules/Minimap/Minimap_Options.lua")
assert(options:find("KT.DrawMinimapRing(d, previewRing",1,true))
assert(options:find("KT.DrawMinimapRing(def, rg",1,true))
print("PASS: original Retail ring crop, neutral colors, native geometry, theme switches, preview and packaged BLP")
