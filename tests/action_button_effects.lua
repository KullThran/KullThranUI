local root=arg[1] or "."
local function region(parent)
    local r={parent=parent,w=140,h=34,level=1,shown=true,scripts={}}
    local methods={}
    function methods:CreateTexture()return region(self)end
    function methods:CreateFontString()return region(self)end
    function methods:GetWidth()return self.w end
    function methods:GetHeight()return self.h end
    function methods:GetFrameLevel()return self.level end
    function methods:SetSize(w,h)self.w,self.h=w,h end
    function methods:SetWidth(w)self.w=w end
    function methods:SetHeight(h)self.h=h end
    function methods:SetVertexColor(...)self.color={...}end
    function methods:SetTextColor(...)self.textColor={...}end
    function methods:SetAlpha(a)self.alpha=a end
    function methods:SetFont(path,size,flags)self.font,self.fontSize,self.flags=path,size,flags end
    function methods:EnableMouse(value)self.mouse=value end
    function methods:SetScale(value)self.scale=value end
    function methods:SetText(text)assert(self.font,"label requires font");self.text=text end
    function methods:SetScript(event,callback)self.scripts[event]=callback end
    function methods:HookScript(event,callback)self.scripts[event]=callback end
    function methods:IsEnabled()return true end
    function methods:Show()self.shown=true end
    function methods:Hide()self.shown=false end
    return setmetatable(r,{__index=function(_,key)
        if methods[key]then return methods[key]end
        if key:match("^Set") or key:match("^Clear") then return function()end end
    end})
end
local kt={FONT_PATH="Avant Garde",NavTabs={PixelSize=function()return 1 end,Upper=function(text)return text:upper()end}}
local env=setmetatable({CreateFrame=function(_,_,parent)return region(parent)end},{__index=_G})
local function load(name)
    local file=assert(io.open(root.."/KullThranUI/"..name));local src=file:read("*a");file:close()
    local fn=assert(loadstring(src));setfenv(fn,env);fn("KullThranUI",{KT=kt})
end
load("TestButton.lua");load("ShineButton.lua")
local btn=region();local clicked=0
btn:SetScript("OnClick",function()clicked=clicked+1 end)
kt.TestButton.Style(btn,{label="Party Test",fontSize=11})
local v=btn._ktTest
assert(v.text.text=="PARTY TEST" and v.text.font=="Avant Garde")
assert(#v.topEdge==9 and not v.topFill,"transparent rounded stroke without solid fill")
assert(v.text.flags=="","test text has no thick outline")
local idleLift=v.lift
assert(idleLift>0)
assert(v.topEdge[1].color[1]==1 and v.topEdge[1].color[2]==1,"white outline")
btn.scripts.OnEnter(btn);btn.scripts.OnUpdate(btn,0.05)
assert(v.hoverP==0.5 and btn.scripts.OnUpdate,"hover animates for 100ms")
btn.scripts.OnUpdate(btn,0.05)
assert(v.lift>idleLift and not btn.scripts.OnUpdate)
btn.scripts.OnMouseDown(btn,"LeftButton");btn.scripts.OnUpdate(btn,0.1)
assert(v.lift==0 and v.pressP==1,"pressed top sits flush with base")
btn.scripts.OnMouseUp(btn);btn.scripts.OnUpdate(btn,0.1)
assert(v.lift>idleLift and v.pressP==0)
assert(v.text.textColor[1]==1,"readable white text without fill")
btn.scripts.OnClick(btn);assert(clicked==1,"style preserves the test action")
btn.scripts.OnLeave(btn);btn.scripts.OnUpdate(btn,0.1)
assert(v.hoverP==0 and v.lift==idleLift and not btn.scripts.OnUpdate)
kt.FONT_PATH="Custom Global Font";kt.TestButton.Refresh(btn);assert(v.text.font==kt.FONT_PATH)
local shine=region()
kt.ShineButton.Style(shine,{label="Reload UI",color={1,0.3,0.5}})
local s=shine._ktShine
s.hoverP,s.shineT=1,0.5
kt.ShineButton.Refresh(shine)
assert(s.fill.rects[1].color[4]==0.2,"fill brightness reduced 80 percent")
assert(math.abs(s.glowPieces[1].alpha-0.06)<0.001,"glow brightness reduced 80 percent")
assert(s.shine.alpha==0.2,"shine brightness reduced 80 percent")
s.pressP=1;kt.ShineButton.Refresh(shine);assert(s.glowPieces[1].alpha==0)
print("action_button_effects: dimmed highlights, transparent outlined test buttons, font and callbacks passed")

load("Modules/VisualThemes/ThemeBrutalCard.lua")
local card=region();local callback=function()clicked=clicked+1 end
card:SetScript("OnClick",callback)
local c=kt.BrutalCard.Style(card,{accent={0.9,0.4,0.1},inUse=false})
assert(c.body.scale==1 and c.radius==19 and not c.shadow and not c.disc,"previous effects removed")
kt.BrutalCard.SetHover(card,true);card.scripts.OnUpdate(card,0.125)
assert(c.body.scale<1 and c.body.scale>0.98 and c.radius<19 and c.radius>18)
card.scripts.OnUpdate(card,0.125)
assert(c.body.scale==0.98 and c.radius==18 and not card.scripts.OnUpdate,"250ms package hover")
assert(c.glow.color[1]==0.9 and c.glow.color[2]==0.4 and c.glow.color[4]==0.3,"halo retains existing theme accent")
assert(card.scripts.OnClick==callback and card.w==140,"hover preserves layout and apply callback")
kt.BrutalCard.SetHover(card,false);card.scripts.OnUpdate(card,0.25)
assert(c.body.scale==1 and c.glow.color[4]==0)
print("visual_style_cards: replacement package hover, rounded inner body, accent and callbacks passed")

local themeSource=assert(io.open(root.."/KullThranUI/Modules/VisualThemes/ThemePreview.lua")):read("*a")
local cardStart=assert(themeSource:find("function KT.VisualThemes:CreateThemeCard",1,true))
local cardEnd=assert(themeSource:find("    return card, height",cardStart,true))
assert(not themeSource:sub(cardStart,cardEnd):find("GameTooltip:",1,true),"visual style cards and their controls do not show tooltips")
print("visual_style_cards: seamless idle radii and no card tooltips passed")

local transferAccent={0.8,0.3,0.2}
kt.GetStyleAccentRGB=function()return unpack(transferAccent)end
load("ProfileTransferButton.lua")
local transfer=region();transfer:SetScript("OnClick",callback)
kt.ProfileTransferButton.Style(transfer,{label="Export"})
local pv=transfer._ktProfileTransfer
assert(pv.text.text=="EXPORT" and pv.text.flags=="" and pv.text.textColor[1]==1)
assert(pv.edges[1].color[1]==0.8 and pv.edges[1].h==2)
transferAccent={0.2,0.7,0.9};kt.ProfileTransferButton.RefreshAll()
for _,edge in ipairs(pv.edges)do assert(edge.color[1]==0.2 and edge.color[2]==0.7)end
assert(pv.text.textColor[1]==1,"accent changes affect borders while text stays white")
assert(pv.before.color[1]==0.13 and pv.beforeProgress==0 and not transfer.scripts.OnUpdate)
transfer.scripts.OnEnter(transfer);transfer.scripts.OnUpdate(transfer,0.15)
assert(pv.beforeProgress>0 and pv.afterProgress==0,"second mask waits 150ms")
transfer.scripts.OnUpdate(transfer,0.3)
assert(pv.before.color[4]==0 and pv.after.color[4]==0 and not transfer.scripts.OnUpdate,"both masks retract and idle animation stops")
assert(transfer.scripts.OnClick==callback,"styling preserves export/import callback")
transfer.scripts.OnLeave(transfer);transfer.scripts.OnUpdate(transfer,0.45)
assert(pv.beforeProgress==0 and pv.afterProgress==0)
local options=assert(io.open(root.."/KullThranUI/Options.lua")):read("*a")
local a=assert(options:find("local function AppendModuleProfileTools(",1,true))
local b=assert(options:find("KT.Options.AppendModuleProfileTools",a,true))
local footer=options:sub(a,b-1)
local _,variants=footer:gsub('variant = "moduleProfile"','')
assert(variants==2,"both footer actions get the dedicated style")
local calls={}
kt.GetModule=function()return {
    GetPageProfileInfo=function()return {label="Enhancements"}end,
    ExportPageProfileString=function(_,page)calls.exportPage=page;return "test data"end,
    ShowExportPopup=function(_,title,data)calls.exportData=data end,
    ShowImportPopup=function(_,title,help,fn)calls.import=fn end,
    ImportPageProfileString=function(_,page,data)calls.importPage,calls.importData=page,data;return true end,
}end
local widgets={SectionHeader=function()return nil,22 end,Label=function()return nil,24 end,
    DualRow=function(_,parent,y,left,right)calls.left,calls.right=left,right;return nil,44 end}
local footerEnv=setmetatable({KT=kt,LText=function(text)return text end},{__index=_G})
local fn=assert(loadstring(footer.."\nreturn AppendModuleProfileTools"));setfenv(fn,footerEnv)
fn()(region(),widgets,"enhancements",100)
calls.left.onClick();assert(calls.exportPage=="enhancements" and calls.exportData=="test data")
calls.right.onClick();calls.import("import data")
assert(calls.importPage=="enhancements" and calls.importData=="import data")
print("module_profile_buttons: timed accent-border reveal, typography, footer wiring and transfer actions passed")
