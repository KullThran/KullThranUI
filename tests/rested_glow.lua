local root=arg[1] or "."
local file=assert(io.open(root.."/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_AggroGlow.lua"))
local source=file:read("*a");file:close()
local env=setmetatable({PAD=0}, {__index=_G})
local a=assert(source:find("local function CloneTexture(",1,true))
local b=assert(source:find("local function Build(",a,true))
local run=assert(loadstring(source:sub(a,b-1).."\nreturn CloneTexture"));setfenv(run,env)
local clone=run()
local src={}
function src:GetAtlas() return "native-portrait-atlas" end
function src:GetTexCoord() return .8,.2,.1,.9 end
function src:GetParent() return nil end
function src:GetNumPoints() return 1 end
function src:GetPoint() return "TOPLEFT",self,"TOPLEFT",0,0 end
function src:GetSize() return 60,60 end
local dst={}
function dst:SetBlendMode(v) self.blend=v end
function dst:SetAtlas(v) self.atlas=v end
function dst:SetTexCoord(...) self.coords={...} end
function dst:ClearAllPoints() end
function dst:SetPoint(...) self.point={...} end
function dst:SetSize(w,h) self.width,self.height=w,h end
function dst:SetVertexColor(...) self.color={...} end
function dst:SetShown(v) self.shown=v end
function dst:SetColorTexture(...) self.emission={...} end
function dst:AddMaskTexture(mask) self.mask=mask end
function dst:RemoveMaskTexture(mask) assert(self.mask==mask);self.mask=nil end
local clip={}
function clip:CreateMaskTexture()
    local mask={}
    function mask:SetAtlas(atlas) self.atlas=atlas end
    function mask:SetTexture(file) self.texture=file;return type(file)=="string" end
    function mask:SetTexCoord(...) self.coords={...} end
    function mask:ClearAllPoints() end
    function mask:SetAllPoints(region) self.anchor=region end
    function mask:Show() self.shown=true end
    function mask:Hide() self.shown=false end
    return mask
end
local glow={clones={dst},clip=clip,resting=true,color={1,.82,.15}}
function glow:GetEffectiveScale() return 1 end
assert(clone(glow,1,src))
assert(dst.blend=="BLEND" and dst.color[4]==1, "resting uses the same rendering as aggro with a gold color")
assert(dst.width==60 and dst.height==60,"resting follows the exact atlas size")
assert(dst.coords[1]==.8 and dst.coords[2]==.2,"atlas clipping and mirroring stay intact")
assert(dst.mask==nil and dst.emission==nil,"resting cannot replace art with a solid color or portrait mask")
dst._ktRestMask=clip:CreateMaskTexture(); dst._ktRestMask:Show()
dst._ktRestMaskAttached=true; dst.mask=dst._ktRestMask
assert(clone(glow,1,src))
assert(dst.mask==nil and not dst._ktRestMask.shown,"old resting masks are detached")
glow.resting=false;glow.color={1,.12,.12}
assert(clone(glow,1,src))
assert(dst.blend=="BLEND" and dst.width==60, "combat restores its existing red overlay")
assert(dst.mask==nil and not dst._ktRestMask.shown,"combat removes the resting silhouette")
src.GetAtlas=function() return nil end
src.GetTexture=function() return -4765 end
src._ktGlowTextureFile=[=[Interface\AddOns\KullThranUI\Libraries\texture\media\portraits\forever_unitframe.tga]=]
function dst:SetTexture(file) self.texture=file; return type(file)=="string" end
assert(clone(glow,1,src) and dst.texture==src._ktGlowTextureFile, "local textures use the file path instead of the internal negative handle")
src._ktGlowTextureFile=nil
env.KT={Portrait3DDebug={Value=tostring}}
assert(not clone(glow,1,src) and not dst.shown and glow.lastCloneError:find("texture rejected",1,true))
print("rested_glow: ok")
