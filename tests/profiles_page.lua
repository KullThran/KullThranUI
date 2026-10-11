local root=arg[1] or "."
local f=assert(io.open(root.."/KullThranUI/Options.lua"));local source=f:read("*a");f:close()
local frames,selected,refreshes={}, {},0
local font="Avant Garde"
local function region(kind,parent)
    local r={kind=kind,parent=parent,w=900,h=32,scripts={},shown=true,enabled=true}
    function r:SetPoint(...) self.point={...} end
    function r:ClearAllPoints() end
    function r:SetAllPoints() end
    function r:SetSize(w,h) self.w,self.h=w,h end
    function r:GetWidth() return self.w end
    function r:SetWidth(v) self.w=v end
    function r:SetHeight(v) self.h=v end
    function r:SetTexCoord(...) self.uv={...} end
    function r:GetFrameLevel() return self.level or 10 end
    function r:SetFrameLevel(v) self.level=v end
    function r:EnableMouse(v) self.mouse=v end
    function r:GetStringWidth() return #(self.text or "")*6 end
    function r:Hide() self.shown=false end
    function r:SetTexture(v) self.texture=v end
    function r:SetVertexColor(...) self.color={...} end
    function r:SetTextColor(...) self.color={...} end
    function r:SetFont(...) self.font={...} end
    function r:SetFontString(v) self.label=v end
    function r:SetJustifyH() end
    function r:SetWordWrap() end
    function r:SetText(v)
        assert(self.kind ~= "font" or self.font, "FontString requires a font before SetText")
        self.text=v
    end
    function r:GetText() return self.text end
    function r:SetTextInsets() end
    function r:SetAutoFocus() end
    function r:ClearFocus() self.focus=false end
    function r:SetShown(v) self.shown=v end
    function r:SetScript(k,v) self.scripts[k]=v end
    function r:HookScript(k,v)
        local old=self.scripts[k];self.scripts[k]=function(...) if old then old(...) end;v(...) end
    end
    function r:IsEnabled() return self.enabled end
    function r:SetEnabled(v) self.enabled=v;if self.scripts[v and "OnEnable" or "OnDisable"] then self.scripts[v and "OnEnable" or "OnDisable"]() end end
    function r:CreateTexture() return region("texture",self) end
    function r:CreateFontString() return region("font",self) end
    frames[#frames+1]=r;return r
end
local kt={FONT_PATH="Avant Garde",ResolveFontPath=function() return font end,
    AddBackdrop=function() end,AddAccentBorder=function(_,r,a) r.borderAlpha=a end,
    RefreshPage=function() refreshes=refreshes+1 end}
local env=setmetatable({ns={PAGE_ICON_STYLE_MAP={}},UIParent=region("Frame"),KT=kt,CreateFrame=region,LText=function(v)return v end,
    GetMenuAccentColor=function() return .8,.3,.2 end,
    GetMenuIconVertexColor=function() return 1,1,1 end,
    ApplyTextureGradient=function(r,...) r.gradient={...} end},{__index=_G})
local a=assert(source:find('-- Profile controls:',1,true))
local b=assert(source:find('local COMPATIBILITY_ICON_NAME_BY_RULE',a,true))
local fn=assert(loadstring(source:sub(a,b-1)..'\nreturn AddProfilesSelectionGrid'));setfenv(fn,env)
local grid=fn();local ui=env.ns.ProfileUI
local entries={};for i=1,29 do entries[i]={id="m"..i,label="Module "..i} end
local parent=region("Frame")
local opts={searchable=true,getTitle=function(e)return e.label end,isSelected=function(e)return selected[e.id]==true end,
    onToggle=function(e,v) selected[e.id]=v end}
local function render()
    frames={};grid(parent,0,entries,opts)
    local buttons={};for _,r in ipairs(frames) do if r.kind=="Button" then buttons[#buttons+1]=r end end
    return buttons
end
local function find(buttons,label)
    for _,button in ipairs(buttons) do if button.label.text==label then return button end end
end
local buttons=render()
local modules=0;for _,button in ipairs(buttons) do if button.label.text:match('^Module ') then modules=modules+1 end end
assert(modules==6,"only six modules appear per page")
find(buttons,"Module 1").scripts.OnClick();assert(selected.m1)
assert(not find(buttons,"Previous").enabled and find(buttons,"Next").enabled)
find(buttons,"Next").scripts.OnClick();assert(ui.modulePage==2)
buttons=render();assert(find(buttons,"Module 7") and not find(buttons,"Module 1"))
assert(selected.m1,"selection persists across pages")
local search;for _,r in ipairs(frames) do if r.kind=="EditBox" then search=r end end
search:SetText("Module 29");search.scripts.OnEnterPressed()
buttons=render();assert(find(buttons,"Module 29") and not find(buttons,"Module 28"))
assert(ui.modulePage==1 and not find(buttons,"Next").enabled)
assert(#ui.FilterEntries(entries,"  MODULE 29  ")==1)
assert(#ui.FilterEntries(entries,"[")==0,"search treats punctuation literally")
font="Custom Global Font";local button=find(buttons,"Module 29")
button.scripts.OnEnter();assert(button.label.font[1]==font and button.profileLayers.rim[1].color[4]==0.9,"hover follows global font and accent")
local calls=0
local row,h=ui.WrapWidgets({}):DualRow(parent,0,{type="button",text="Export",onClick=function()calls=calls+1 end},
    {type="button",text="Import",onClick=function()calls=calls+10 end})
row.buttons[1].scripts.OnClick();row.buttons[2].scripts.OnClick();assert(calls==11,"profile actions remain wired")
assert(row.buttons[1].w < row.w*0.5,"short actions do not stretch across the panel")
assert(#row.buttons[1].profileLayers.fill==9,"rounded corners preserve their shape at any width")
for _,piece in ipairs(row.buttons[1].profileLayers.fill) do
    assert(piece.parent.level==row.buttons[1]:GetFrameLevel(),"background layers do not cover text")
end
frames={}
grid(parent,0,{{id="partyframes",label="Party Frames"}},{
    getTitle=function(e)return e.label end,getIconPath=function()return "party.png" end,
    getIconName=function()return "PartyFrames" end,isSelected=function()return false end})
local moduleIcon
for _,r in ipairs(frames) do if r.texture=="party.png" then moduleIcon=r end end
assert(moduleIcon and math.abs(moduleIcon.w/moduleIcon.h-1.5)<0.001,"module icons retain original aspect ratio")
local pageA=assert(source:find('local function BuildProfilesTab(sc, W, y)',1,true))
local pageB=assert(source:find('local function BuildQuickSetupTab',pageA,true))
local page=source:sub(pageA,pageB-1)
env.GetProfilesModule=function() return {
    GetModuleDefinitions=function()return entries end,GetCDMSpecEntries=function()return {} end,
    GetCurrentSpecAssignment=function()end} end
env.EnsureProfileState=function()end
env.BeginOptionBlocks=function()return {} end
env.EndOptionBlocks=function()return 0 end
local blocks={}
env.AddOptionBlock=function(_,column,title) blocks[#blocks+1]=title end
local make=assert(loadstring(page..'\nreturn BuildProfilesTab'));setfenv(make,env);local build=make()
blocks={};build(parent,{},0)
assert(#blocks==4,"all four groups remain on one page")
assert(blocks[1]=="KUI Profiles" and blocks[2]=="Profile Transfer" and blocks[3]=="Modules Export" and blocks[4]=="CDM Spell Profiles")
-- Exercise the tooltip API on the profile card and module selector.
local tipText
local tooltip={SetOwner=function()end,SetText=function(_,text,...)
    assert(select("#",...)==0,"tooltip SetText uses the signature shared by both clients")
    tipText=text
end,Show=function()end,Hide=function()end,AddLine=function()end}
env.GameTooltip=tooltip
env.GetCurrentSpecVisual=function()return 1,"Druid",134400 end
env.LTextFmt=string.format
kt.SetAccentTextColor=function()end
local cardStart=assert(source:find('local function AddProfileSpecCard(',1,true))
local cardEnd=assert(source:find('local PROFILE_MODULE_ICON_MAP',cardStart,true))
local cardFn=assert(loadstring(source:sub(cardStart,cardEnd-1)..'\nreturn AddProfileSpecCard'));setfenv(cardFn,env)
local card=cardFn()(parent,0,"My Profile",nil)
card.scripts.OnEnter(card);assert(tipText=="My Profile")
print("profiles_page: bounded selection, search, paging, global font, actions, one-page groups and tooltip signature passed")
