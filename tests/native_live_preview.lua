local root = arg[1] or "."
local function read(path)
    local f=assert(io.open(root.."/"..path)); local s=f:read("*a"); f:close(); return s
end
local ns={}
local function Region(parent)
    local r={parent=parent, level=1, shown=true, w=60,h=60,points={}}
    function r:GetFrameLevel() return self.level end
    function r:SetFrameLevel(v) self.level=v end
    function r:GetFrameStrata() return "DIALOG" end
    function r:SetFrameStrata() end
    function r:SetAllPoints() end
    function r:EnableMouse() end
    function r:SetParent(v) self.parent=v end
    function r:SetClipsChildren(v) self.clip=v end
    function r:IsShown() return self.shown end
    function r:Show() self.shown=true end
    function r:Hide() self.shown=false end
    function r:SetSize(w,h) self.w,self.h=w,h end
    function r:GetWidth() return self.w end
    function r:GetHeight() return self.h end
    function r:ClearAllPoints() self.points={} end
    function r:SetPoint(...) self.points[#self.points+1]={...} end
    function r:SetTexture(v) self.texture=v end
    function r:SetDrawLayer(layer, sublevel) self.layer,self.sublevel=layer,sublevel end
    function r:SetJustifyH() end
    function r:SetWidth(v) self.w=v end
    function r:SetBlendMode() end
    function r:SetAtlas(v) self.atlas=v end
    function r:SetTexCoord(...) self.coords={...} end
    function r:AddMaskTexture(v) self.mask=v end
    function r:RemoveMaskTexture(v) if self.mask==v then self.mask=nil end end
    function r:CreateTexture() return Region(self) end
    return r
end
local theme="classic"
local env=setmetatable({ns=ns, CreateFrame=function(_,_,parent) return Region(parent) end,
    C_Texture={GetAtlasInfo=function() return {width=94,height=82,file=123,
        leftTexCoord=.1,rightTexCoord=.3,topTexCoord=.2,bottomTexCoord=.4} end}}, {__index=_G})
local source=read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua")
local first=assert(source:find("ns.NATIVE_PLAYER_DRAGON_SCALE =",1,true))
local last=assert(source:find("-- One time per profile:",first,true))
local run=assert(loadstring(source:sub(first,last-1)));setfenv(run,env);run()
source=read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_UnitFrames_Options.lua")
first=assert(source:find("function ns.ApplyPreviewUnit(frame,",1,true))
last=assert(source:find("-- Combo points under the frame",first,true))
env.KT={}
env.RING_ICON_PATH="Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\UnitFramesIcons\\"
env.ActiveVisualTheme=function() return theme end
env.PREVIEW_STOCK_GEOMETRY={classic={player={health={x=106}}},forever={player={health={x=85}}},retail={player={health={x=85}}}}
env.ApplyPreviewUnitBase=function(frame)
    frame.portraitFrame:Show();frame.portraitMask:SetAtlas("normal-mask")
    frame.health:SetSize(124,20);frame.power:SetSize(124,10)
    frame.health:SetFrameLevel(20);frame.power:SetFrameLevel(20)
    frame.stockArt:SetSize(232,100);frame.stockArt.shown=theme~="kui"
    frame.model3D:SetSize(60,60)
end
run=assert(loadstring(source:sub(first,last-1)));setfenv(run,env);run()
local function Frame()
    local f=Region()
    for _,key in ipairs({"portraitFrame","portraitMask","portrait","portraitBorder","portraitFill","stockArtFrame","stockArt","levelFrame","model3D","health","power"}) do f[key]=Region(f) end
    f.stockArt:SetParent(f.stockArtFrame)
    return f
end
local function near(a,b) assert(math.abs(a-b)<.00001,tostring(a).." != "..tostring(b)) end
for _,style in ipairs({"classic","forever","retail","kui"}) do
    theme=style
    for _,choice in ipairs({"nativeelite","nativerare"}) do
        local f=Frame()
        ns.ApplyPreviewUnit(f,"player",{frameScale=100},{playerClassificationBorder=choice})
        assert(f.unit=="player" and f._ktNativeClassificationScale==1,"preview keeps the portrait at full size")
        near(f._kuiNativeClassRing.w,94*60*ns.ClassificationRingReach(style)/29*((style=="kui" or style=="classic") and ns.NATIVE_KUI_FIT.scale or 1))
        assert(f.portraitMask.atlas=="normal-mask","preview keeps the style's own aperture")
        near(f.health:GetWidth(),124);near(f.power:GetWidth(),124)
        if style~="kui" then
            assert(f.stockArt.parent==f.stockArtFrame and f.stockArt.shown,"style frame stays under the dragon")
        end
        ns.ApplyPreviewUnit(f,"player",{},{playerClassificationBorder="none"})
        assert(not f._kuiNativeClassRing.shown,"removing selection hides native preview")
        assert(f.stockArt.parent==f.stockArtFrame,"removing selection restores art parent")
        assert(f.portraitMask.atlas=="normal-mask","removing selection restores normal aperture")
        ns.ApplyPreviewUnit(f,"target",{},{playerClassificationBorder=choice})
        assert(f._ktNativeClassificationScale==1 and not f._kuiNativeClassRing.shown,"Player selection cannot affect Target preview")
    end
end
theme="classic"
ns.ClassicRing={sheets={rare="classic-rare-sheet",elite="classic-elite-sheet"}}
for _,choice in ipairs({"classicrare","classicelite"}) do
    local f=Frame()
    ns.ApplyPreviewUnit(f,"player",{},{playerClassificationBorder=choice})
    assert(f.stockArt.texture==ns.ClassicRing.sheets[choice=="classicrare" and "rare" or "elite"])
    assert(f.stockArt.shown and not f.classificationRing.shown,"Classic uses one full sheet")
    assert(not f.portraitBorder.shown,"Classic preview hides generic rim")
end
theme="kui"
ns.ModernClassificationRing = { holeRadius=.405, centerX=.04, centerY=.02 }
ns.ModernRingReach = function() return .405 end
ns.ModernRingNudge = function() return 0,0 end
for _,choice in ipairs({"elite","rare"}) do
    local f=Frame()
    ns.ApplyPreviewUnit(f,"player",{},{playerClassificationBorder=choice})
    assert(f.classificationRing.parent==f._ktPreviewClassificationHost,"Modern art uses its independent host")
    assert(f.classificationRing.parent:GetFrameLevel()<f.levelFrame:GetFrameLevel(),"level stays above Modern dragon")
    assert(f.classificationRing.parent:GetFrameLevel()>f.portraitFrame:GetFrameLevel(),"full dragon stays above portrait")
    assert(f.classificationRing.parent.parent==f and not f.classificationRing.parent.clip,"dragon bypasses portrait clipping")
    -- Repair previews created with the old parent as well.
    f.classificationRing:SetParent(f.portraitFrame)
    ns.ApplyPreviewUnit(f,"player",{},{playerClassificationBorder=choice})
    assert(f.classificationRing.parent==f._ktPreviewClassificationHost,"existing clipped preview parent repaired")
end
print("native_live_preview: ok")
