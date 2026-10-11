local root = arg[1] or "."
local function read(path)
    local f = assert(io.open(root .. "/" .. path)); local s = f:read("*a"); f:close(); return s
end
local source = read("KullThranUI/Modules/Enhancements/Enhancements_DamageMeter.lua")
local start = assert(source:find("function Mod.ApplyDamageMeterAtlasArt",1,true))
local stop = assert(source:find("local function ApplyDamageMeterSkin",start,true))
local missing = {}
local function node()
    local n = {shown=true, color={1,1,1,1}, points={}}
    function n:CreateTexture() return node() end
    function n:SetAtlas(value) self.atlas=value end
    function n:SetTexture(value) self.texture=value; self.atlas=nil end
    function n:SetColorTexture(...) self.color={...}; self.atlas=nil end
    function n:SetVertexColor(...) self.color={...} end
    function n:GetVertexColor() return unpack(self.color) end
    function n:SetTexCoord(...) self.coords={...} end
    function n:SetAllPoints(target) self.target=target end
    function n:ClearAllPoints() self.points={} end
    function n:SetPoint(...) self.points[#self.points+1]={...} end
    function n:SetSize(w,h) self.width=w; self.height=h end
    function n:SetWidth(w) self.width=w end
    function n:SetHeight(h) self.height=h end
    function n:SetAlpha(a) self.alpha=a end
    function n:SetBackdropColor(...) self.bg={...} end
    function n:SetBackdrop(value) self.backdrop=value end
    function n:SetBackdropBorderColor(...) self.border={...} end
    function n:SetFontObject(f) self.font=f end
    function n:Hide() self.shown=false end
    function n:Show() self.shown=true end
    function n:IsShown() return self.shown end
    return n
end
local Mod = {}
local env = setmetatable({KT={}, Mod=Mod, C_Texture={GetAtlasInfo=function(name)
    if missing[name] then return nil end
    return {file=123, width=256, height=32, leftTexCoord=.1, rightTexCoord=.9, topTexCoord=.2, bottomTexCoord=.6}
end}, GameFontNormalMed1="native-header", NumberFontNormal="native-row"}, {__index=_G})
local chunk = assert(loadstring(source:sub(start,stop-1))); setfenv(chunk,env); chunk()
local function meter(live)
    local frame = node()
    local row = node()
    row.background=node(); row.icon=node(); row.bar=node(); row.textLayer=row
    row.name=node(); row.rank=node(); row.value=node()
    if live then
        row.fill=node()
        function row.bar:GetStatusBarTexture() return row.fill end
    end
    local fill = row.fill or row.bar
    fill:SetVertexColor(.8,.2,.1,.72)
    frame.rows={row}; frame.borderKT=node(); frame._skinPanelEdges={node(),node(),node(),node()}
    frame.modeButton={text=node()}; frame.sessionButton={text=node()}
    frame.resizeHandle=node(); frame.resizeHandle.texture=node()
    return frame,row,fill
end
for _, live in ipairs({true,false}) do
    local frame,row,fill = meter(live)
    Mod.ApplyDamageMeterAtlasArt(frame,{},"forever",20)
    assert(#frame._meterSwingEdges==8 and frame._meterSwingEdges[1].width==16)
    assert(frame._meterSwingEdges[1].height==8, "ornament corners retain their size")
    assert(row._meterSwingFrame.atlas=="ui-swingtimerbar-frame")
    assert(not frame._skinPanelEdges[1]:IsShown())
    Mod.ApplyDamageMeterAtlasArt(frame,{},"retail",20)
    assert(not row._meterSwingFrame:IsShown() and not frame._meterSwingEdges[1]:IsShown())
    assert(frame._meterNativeHeader.atlas=="ui-damagemeters-header-bar")
    assert(frame._meterNativeBackground.atlas=="damagemeters-background")
    assert(row.background.atlas=="ui-damagemeters-bar-shadowbg")
    assert(row._meterNativeEdge.atlas=="ui-damagemeters-bar-shadowedge")
    assert(fill.atlas=="UI-HUD-CoolDownManager-Bar")
    assert(fill.color[1]==.8 and fill.color[4]==.72, "native fill preserves class tint and alpha")
    assert(row.name.font=="native-row" and frame.modeButton.text.font=="native-header")
    assert(frame.resizeHandle._meterNativeAtlas and frame.resizeHandle.width==60)
    Mod.ApplyDamageMeterAtlasArt(frame,{showBackground=false},"retail",0)
    assert(frame._meterNativeBackground.alpha==0)
    Mod.ApplyDamageMeterAtlasArt(frame,{},"kui",20)
    assert(not frame._meterNativeHeader:IsShown() and not row._meterNativeEdge:IsShown())
    assert(not frame.resizeHandle._meterNativeAtlas and frame.resizeHandle.width==16)
    missing["ui-swingtimerbar-frame"]=true
    Mod.ApplyDamageMeterAtlasArt(frame,{},"forever",20)
    assert(not row._meterSwingFrame:IsShown(), "missing atlas falls back without stale art")
    missing["ui-swingtimerbar-frame"]=nil
    missing["UI-HUD-CoolDownManager-Bar"]=true
    fill:SetTexture("custom-fill")
    Mod.ApplyDamageMeterAtlasArt(frame,{},"retail",20)
    assert(fill.texture=="custom-fill" and fill:IsShown(), "missing native fill keeps functional fallback")
    missing["UI-HUD-CoolDownManager-Bar"]=nil
end
-- Run the complete skin entry point used by the preview and the live refresh,
-- including the generic edge cleanup around the atlas renderer.
local theme = "forever"
env.KT = {VisualThemes={GetRenderedTheme=function() return theme end},
    AddBackdrop=function(_, frame, ...) frame:SetBackdropColor(...) end}
env.HEADER_HEIGHT=30
env.SetVerticalGradient=function() end
local skinsStart = assert(source:find("local METER_SKINS =",1,true))
local skinsStop = assert(source:find("local function SetVerticalGradient",skinsStart,true))
local applyStart = assert(source:find("local function ApplyDamageMeterSkin",1,true))
local applyStop = assert(source:find("function Mod:RefreshDamageMeterStyle",applyStart,true))
chunk = assert(loadstring(source:sub(skinsStart,skinsStop-1) .. source:sub(applyStart,applyStop-1)))
setfenv(chunk,env); chunk()
local frame,row,fill = meter(false)
for _, key in ipairs({"forever","retail","classic","kui","forever"}) do
    theme=key
    -- The layout resets material/font before painting a different skin.
    fill:SetTexture("selected-fill")
    row.background:SetColorTexture(0,0,0,1)
    Mod.ApplyDamageMeterSkin(frame,{},20)
    assert(row._meterSwingFrame:IsShown() == (key=="forever"))
    assert(frame._meterNativeHeader:IsShown() == (key=="retail"))
    if key~="retail" then assert(fill.texture=="selected-fill") end
end
local options = read("KullThranUI/Modules/Enhancements/Enhancements_Options.lua")
assert(options:find("Mod.ApplyDamageMeterSkin(meter, cfg",1,true), "preview shares live skin")
print("PASS: Damage Meter native atlases, fixed ornament corners, theme cleanup, class tint, preview and missing-atlas fallback")

-- Retail has no native swing atlases: exercise the production packaged resolver
-- through the complete meter skin, including its fixed-size perimeter slices.
local assets=read("KullThranUI/Modules/VisualThemes/ThemeClientAssets.lua")
chunk=assert(loadstring(assets:sub((assert(assets:find("-- Original Forever swing sheet",1,true))))))
setfenv(chunk,env);chunk()
missing["ui-swingtimerbar-frame"]=true
theme="forever"
frame,row,fill=meter(false)
Mod.ApplyDamageMeterSkin(frame,{},20)
assert(row._meterSwingFrame:IsShown() and row._meterSwingFrame.texture:find("UISwingTimerBar-Forever.blp",1,true))
assert(frame._meterSwingEdges[1]:IsShown() and frame._meterSwingEdges[1].width==16)
assert(not frame._skinPanelEdges[1]:IsShown())
theme="kui";Mod.ApplyDamageMeterSkin(frame,{},20)
assert(not row._meterSwingFrame:IsShown() and not frame._meterSwingEdges[1]:IsShown())
print("PASS: full Damage Meter skin uses packaged Forever ornaments on Retail and cleans up on theme switch")
