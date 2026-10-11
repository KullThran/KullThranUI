local root=arg[1] or "."
local file=assert(io.open(root.."/KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_AggroGlow.lua"))
local source=file:read("*a");file:close()
local info={width=190,height=68}
local theme="retail"
local env=setmetatable({KT={},Theme=function() return theme end,C_Texture={GetAtlasInfo=function(name)
    assert(name=="UI-HUD-UnitFrame-Player-PortraitOn-Status");return info
end}},{__index=_G})
local a=assert(source:find("local function LayoutRestGlow(",1,true))
local b=assert(source:find("local function Layout(frame, g)",a,true))
local chunk=assert(loadstring(source:sub(a,b-1).."\nreturn LayoutRestGlow"));setfenv(chunk,env)
local layout=chunk()
local backdrop={IsShown=function() return true end,GetWidth=function() return 60 end,GetParent=function() end}
local frame={Portrait={backdrop=backdrop},Health={}}
local g={resting=true,GetEffectiveScale=function() return 1 end}
function g:CreateTexture()
    local texture={parent=self}
    function texture:SetParent(parent) self.parent=parent end
    function texture:SetAtlas(atlas) self.atlas=atlas;return true end
    function texture:SetTexture(file) self.file=file;self.atlas=nil;return true end
    function texture:SetTexCoord(...) self.coords={...} end
    function texture:SetBlendMode(blend) self.blend=blend end
    function texture:SetVertexColor(...) self.color={...} end
    function texture:ClearAllPoints() end
    function texture:SetPoint(...) self.point={...} end
    function texture:SetSize(w,h) self.width,self.height=w,h end
    function texture:SetShown(shown) self.shown=shown end
    function texture:Hide() self.shown=false end
    function texture:Show() self.shown=true end
    function texture:SetAllPoints(region) self.anchor=region end
    function texture:AddMaskTexture(mask) self.mask=mask end
    function texture:RemoveMaskTexture(mask) assert(self.mask==mask);self.mask=nil end
    return texture
end
function g:CreateMaskTexture() return self:CreateTexture() end
env.PORTRAIT_MASK_DEFAULT="circle-mask"
env.CreateFrame=function(_,_,parent)
    local clip=parent:CreateTexture()
    clip.CreateTexture=g.CreateTexture
    function clip:SetClipsChildren(value) self.clipsChildren=value end
    return clip
end
g.clip={}
assert(layout(frame,g))
assert(g.restGlow.atlas=="UI-HUD-UnitFrame-Player-PortraitOn-Status")
assert(g.restGlow.parent==g.clip,"modern resting art clips to the portrait; name glow has its own fitted strip")
assert(g.restGlow.blend=="ADD" and g.restGlow.color[1]==1 and g.restGlow.color[2]==.82)
assert(g.restGlow.width==190 and g.restGlow.point[4]==-7 and g.restGlow.point[5]==5)
g.resting=false;assert(not layout(frame,g) and not g.restGlow.shown,"combat removes the gold native glow")
g.resting=true;info=nil;assert(layout(frame,g))
assert(g.restGlow.file==[[Interface\CharacterFrame\UI-Player-Status]],"non-HUD clients use original Blizzard glow art")
assert(g.restGlow.width==256 and g.restGlow.height==128)
theme="classic";info={width=190,height=68}
assert(layout(frame,g))
assert(g.restGlow.atlas=="UI-HUD-UnitFrame-Player-PortraitOn-Status", "Classic restores the previous glow atlas")
assert(g.restGlow.mask==g.restClassicMask and g.restClassicMask.file=="circle-mask", "only Classic clips away the square portrait corner")
assert(g.restHeaderClip.shown and g.restHeaderClip.clipsChildren and g.restHeaderGlow.anchor==g.restGlow, "name glow retains the original atlas and geometry")
theme="retail";assert(layout(frame,g))
assert(g.restGlow.mask==nil and not g.restHeaderClip.shown, "switching style removes the Classic-only clipping")
g.resting=false;assert(not layout(frame,g) and not g.restGlow.shown)
print("native_rested_glow: ok")
