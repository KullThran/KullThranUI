local root = arg[1] or "."
local f=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames_Options.lua"))
local source=f:read("*a");f:close()
assert(not source:find("SetEdgeBorder(unit,",1,true),"preview units must not draw cyan rectangles")
-- The constructor runs before a fit scale exists; only RefreshLivePreview scales icons.
local constructorEnd = assert(source:find("local function RefreshLivePreview",1,true))
local constructor = source:sub(1,constructorEnd-1)
local sizeCall = assert(constructor:match("unit%.roleIcon:SetSize%([^\n]+"))
local initializedSize
local initEnv = setmetatable({unit={roleIcon={SetSize=function(_,w,h) initializedSize={w,h} end}}},{__index=_G})
local init=assert(loadstring(sizeCall));setfenv(init,initEnv);init()
assert(initializedSize[1]==18 and initializedSize[2]==18)
local function region(parent)
    local r={w=800,h=385,parent=parent,scripts={},shown=true,points={}}
    function r:GetWidth() return self.w end
    function r:GetHeight() return self.h end
    function r:SetWidth(v) self.w=v end
    function r:SetSize(w,h) self.w,self.h=w,h end
    function r:SetPoint(...) self.points[#self.points+1]={...} end
    function r:ClearAllPoints() self.points={} end
    function r:SetAllPoints(p) self.all=p end
    function r:SetScript(k,v) self.scripts[k]=v end
    function r:HookScript(k,v) self.scripts[k]=v end
    function r:CreateFontString() return region(self) end
    function r:CreateTexture() return region(self) end
    function r:SetColorTexture(...) self.color={...} end
    function r:SetText(v) self.text=v end
    function r:SetFont(path,size,outline) self.font={path,size,outline} end
    function r:SetTextColor(...) self.textColor={...} end
    function r:SetJustifyH() end
    function r:SetClipsChildren() end
    function r:EnableMouseWheel() end
    function r:EnableMouse(v) self.mouse=v end
    function r:Hide() self.shown=false end
    return r
end
local chosen="kui"
local styles={ tabs={{id="kui",label="KUI"},{id="retail",label="Retail"},{id="forever",label="Forever"},{id="classic",label="Classic"}},
    Current=function() return chosen end, Select=function(key) chosen=key;return true end }
local accent={0.2,0.6,0.9}
local colors={}
for _,style in ipairs(styles.tabs) do colors[style.id]={colorByClass=true,customHealthColor={r=0.1,g=0.9,b=0.1}} end
styles.GetHealthSettings=function(key) return colors[key] end
styles.SetHealthColor=function(key,classColor,color)
    colors[key].colorByClass=classColor
    if color then colors[key].customHealthColor=color end
end
local kt={StyleActionButton=function()end,GetStyleAccentRGB=function() return unpack(accent) end,AttachStickyPreview=function(self,frame,opts) self.sticky,self.opts=frame,opts end}
local env=setmetatable({ns={PF_Styles=styles},KT=kt,activeMode="party",
    CLASS_COLORS={DRUID={1,0.4,0}},playerRealClass="DRUID",DEFAULT_FONT_PATH="Avant Garde",
    CreateFrame=function(_,_,parent) return region(parent) end,
    AddSimpleBorder=function() end,SetEdgeBorder=function(card,...) card.border={...} end,LText=function(v)return v end,
    RefreshLivePreview=function(frame) frame.refreshes=(frame.refreshes or 0)+1;frame.units=frame.units or {region(frame)} end,
}, {__index=_G})
local a=assert(source:find("local function CreateLivePreview(",1,true))
local b=assert(source:find("_G.KullThranUI_PartyFramesOptions",a,true))
local chunk=assert(loadstring(source:sub(a,b-1).."\nreturn CreateLivePreview, CreateStyleCards"));setfenv(chunk,env)
local create,createCards=chunk()
local page=region()
local main,height=create(page,0)
local selector=createCards(page,height)
assert(not main.styleCards and #selector.styleCards==4 and kt.sticky==main and kt.opts.height==285)
assert(main.canvas.points[1][3]==-34,"preview canvas has no theme cards")
assert(selector.parent==page and selector.parent~=main,"cards belong to scrollable options outside sticky preview")
for i,card in ipairs(selector.styleCards) do
    assert(card.parent==selector,"card stays in the separate selector")
    assert(card.colorSelector.parent==selector,"selector sits below the card, outside the preview")
    assert(card.colorSelector.points[1][2]==card and card.colorSelector.points[1][3]=="BOTTOMLEFT")
    assert(#card.colorButtons==2)
    local pickerInfo
    ColorPickerFrame={SetupColorPickerAndShow=function(_,info) pickerInfo=info end,GetColorRGB=function() return 0.4,0.5,0.6 end}
    local selectedBefore=chosen
    card.colorButtons[1].scripts.OnClick()
    assert(not colors[card.key].colorByClass and chosen==selectedBefore,"color control edits its own style without selecting it")
    assert(pickerInfo,"health color opens the picker")
    pickerInfo.swatchFunc()
    assert(colors[card.key].customHealthColor.r==0.4)
    pickerInfo.cancelFunc()
    assert(colors[card.key].customHealthColor.r==0.1,"cancel restores the previous color")
    ColorPickerFrame=nil
    card.colorButtons[2].scripts.OnClick()
    assert(colors[card.key].colorByClass)

    assert(card.preview.styleOverride==styles.tabs[i].id and card.preview.cardSample)
    assert(card.preview.canvas.all==card.preview and not card.preview.title.shown)
    assert(card.preview.mouse==false and card.preview.units[1].mouse==false,"sample clicks pass to its card")
    assert(card.border[1]==accent[1] and card.border[2]==accent[2] and card.border[3]==accent[3])
    card.scripts.OnEnter(card)
    assert(card.border[4]==1 and card.hoverGlow.color[4]==0.14)
    card.scripts.OnLeave(card)
    assert(card.hoverGlow.color[4]~=0.14)
    card.scripts.OnClick();assert(chosen==card.key)
end
accent={0.8,0.2,0.6}
selector:SetSize(640,100);selector.scripts.OnSizeChanged(selector)
for _,card in ipairs(selector.styleCards) do assert(card.border[1]==0.8 and card.border[3]==0.6) end
assert(selector.styleCards[1].w==(640-36)/4,"cards resize with panel")
-- Exercise the actual sizing calculation with a KUI portrait extending outside its frame.
a=assert(source:find("    local rawW =",1,true));b=assert(source:find("    if preview.title then",a,true))
local size=assert(loadstring("return function(preview,cfg,canvasW,canvasH,cols,rows,configMode) local count=rows\n"..source:sub(a,b-1).."\nreturn w,h,startX,startY,gridW,gridH,fit,leftRoom,rightRoom end"))
env.GetPreviewExternalAuraReserve=function()return 0 end;setfenv(size,env);local calc=size()
chosen="kui"
local cfg={frameWidth=280,frameHeight=46,frameScale=1,frameSpacing=6,growDirection="VERTICAL",showPortrait=true,portraitStyle="circular"}
local w,h,x,y,gw,gh,fit,left=calc({canvas={GetWidth=function()return 780 end,GetHeight=function()return 211 end}},cfg,780,211,1,5,"party")
assert(x-left*fit>=0 and x+w<=780,"KUI portrait and bar remain inside canvas")
assert(gh<=211 and y<=0 and -y+gh<=211,"all five preview members fit vertically")
-- A sample refresh must hide buttons even after the arena/party branch showed them.
a=assert(source:find("    if preview.controlsEnabled == false then",1,true))
b=assert(source:find("    if preview.units then",a,true))
local sample={controlsEnabled=false}
for _,key in ipairs({"partyBtn","raidBtn","raid40Btn","arenaBtn","arenaEnemyBtn","stopBtn","scaleDown","scaleUp"}) do sample[key]=region() end
env.preview=sample
local hide=assert(loadstring(source:sub(a,b-1)));setfenv(hide,env);hide()
for _,key in ipairs({"partyBtn","raidBtn","raid40Btn","arenaBtn","arenaEnemyBtn","stopBtn","scaleDown","scaleUp"}) do assert(not sample[key].shown) end
print("party_preview_cards: separate cards, clicks, hidden sample controls and KUI bounds passed")
