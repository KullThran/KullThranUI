local root=arg[1] or "."
local function read(path)local f=assert(io.open(root.."/"..path));local s=f:read("*a");f:close();return s end
local source=read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUI_UnitFrames_Options.lua")
local a=assert(source:find("local PREVIEW_STOCK_GEOMETRY",1,true));local b=assert(source:find("-- Forward declarations.",a,true))
local env=setmetatable({},{__index=_G})
local geometry=assert(loadstring(source:sub(a,b-1).."\nreturn PREVIEW_STOCK_GEOMETRY"));setfenv(geometry,env);local kits=geometry()
local function region()
    local r={points={},shown=true,w=120,h=49,parent=nil}
    local methods={}
    function methods:ClearAllPoints()self.points={}end
    function methods:SetPoint(...)self.points[#self.points+1]={...}end
    function methods:SetSize(w,h)self.w,self.h=w,h end
    function methods:SetTexture(file)self.file=file end
    function methods:SetAtlas(atlas)self.atlas=atlas end
    function methods:SetTexCoord(...)self.coords={...}end
    function methods:GetFrameLevel()return 1 end
    function methods:GetParent()return self.parent end
    function methods:SetParent(p)self.parent=p end
    function methods:IsShown()return self.shown end
    function methods:Show()self.shown=true end
    function methods:Hide()self.shown=false end
    function methods:SetShown(v)self.shown=v end
    function methods:CreateTexture()return region()end
    function methods:CreateMaskTexture()return region()end
    setmetatable(r,{__index=function(_,key) if methods[key] then return methods[key] end; if key:match("^Set") or key:match("^Add") or key:match("^Remove") then return function()end end end})
    return r
end
local theme="classic"
env.PREVIEW_STOCK_GEOMETRY=kits
env.ActiveVisualTheme=function()return theme end
env.ApplyStockArtTexture=function(texture,name)texture:SetAtlas(name);return true,120,49 end
env.KT={};env.ns={BlizzardFont=function()return "Avant Garde",10,"OUTLINE"end,BlizzardLevelColor=function()return 1,1,0 end}
env.ns.ApplyPreview3D=function()end
env.ns.CenterStockLevelText=function()end
env.PREVIEW_FONT="Avant Garde";env.PREVIEW_CIRCLE_MASK="CircleMask"
a=assert(source:find("local function ApplyStockLayoutToPreview(",1,true));b=assert(source:find("local function ApplyStockPreviewColors(",a,true))
local fn=assert(loadstring(source:sub(a,b-1).."\nreturn ApplyStockLayoutToPreview"));setfenv(fn,env);local apply=fn()
for _,key in ipairs({"classic","retail","forever"})do
    theme=key
    for _,unit in ipairs({"focus","totPet","focustarget"})do
        local frame=region()
        for _,field in ipairs({"stockArt","portraitFrame","portrait","health","power","name","value","levelFrame","portraitMask","portraitBorder","levelCircle","levelCircleMask","levelText"})do frame[field]=region()end
        local cfg={frameScale=100,frameWidth=101}
        assert(apply(frame,unit,cfg),key.." preview renders "..unit)
        assert(frame.stockArt.shown and frame.portraitFrame.shown)
        if unit~="focus"then
            assert(not frame.levelText.shown and not frame.levelCircle.shown,"mini frames do not get a large level ornament")
            assert(frame.w==kits[key].pet.w)
        else assert(frame.levelCircle.points[1][3]=="BOTTOMRIGHT","focus badge follows its right portrait") end
    end
end
source=read("KullThranUI_UnitFrames/Modules/KUIUnitFrames/KUIUnitFrames.lua")
a=assert(source:find("local function ApplyClassicFrameArt(",1,true));b=assert(source:find("local function CreateUnifiedBorder(",a,true))
local calls={}
local vt={GetRenderedTheme=function()return theme end,
    ApplyPetFrameArt=function(_,frame,portrait,kind)calls.small=kind;return true end,ClearPetFrameArt=function()end,
    ApplyClassicUnitFrameArt=function(_,frame,portrait,unit)calls.classic=unit;return true end,ClearClassicUnitFrameArt=function()end,
    ApplyForeverUnitFrameArt=function(_,frame,portrait,unit)calls.modern=unit;return true end,ClearForeverUnitFrameArt=function()end}
env.KT={VisualThemes=vt,ApplyStockUFHealthTextGeometry=function()end}
env.db={profile={}}
env.ns.ApplyClassicStatusText=function()end
env.GetSettingsForUnit=function()return {frameWidth=101}end
env.PP={Height=function()end}
fn=assert(loadstring(source:sub(a,b-1).."\nreturn ApplyClassicFrameArt"));setfenv(fn,env);apply=fn()
for _,key in ipairs({"classic","forever","retail","kui"})do
    theme=key
    for _,unit in ipairs({"focus","targettarget","focustarget"})do
        calls={}
        local frame={Portrait={backdrop={}},unifiedBorder={Hide=function()end}}
        apply(frame,unit)
        if key~="kui"then
            if unit=="focus"then assert((key=="classic" and calls.classic or calls.modern)=="target")
            else assert(calls.small==(key=="classic" and "classic" or "forever"))end
        else assert(not calls.small and not calls.classic and not calls.modern,"KUI retains its own art")end
    end
end
print("secondary_unit_art: Focus, ToT and Focus Target live / preview theme routing passed")
