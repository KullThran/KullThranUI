local root=arg[1] or "."
local kt={FONT_PATH="Avant Garde",ResolveFontPath=function(self) return self.FONT_PATH end}
local env=setmetatable({LibStub=function()return {GetAddon=function() return kt end}end},{__index=_G})
local source=assert(io.open(root.."/KullThranUI/SearchInput.lua")):read("*a")
local fn=assert(loadstring(source));setfenv(fn,env);fn()
local function region()
    local r={scripts={},width=600,height=32,shown=true}
    function r:CreateTexture() return region() end
    function r:SetTexture(v) self.texture=v end
    function r:SetTexCoord(...) self.uv={...} end
    function r:SetPoint(...) self.point={...} end
    function r:ClearAllPoints() self.point=nil end
    function r:SetSize(w,h) self.width,self.height=w,h end
    function r:GetFrameLevel()return 1 end
    function r:SetFrameLevel(n)self.level=n end
    function r:SetClipsChildren(v)self.clips=v end
    function r:EnableMouse(v)self.mouse=v end
    function r:SetHeight(h)self.height=h end
    function r:SetWidth(w)self.width=w end
    function r:GetWidth()return self.width end
    function r:GetHeight()return self.height end
    function r:SetVertexColor(...)self.color={...}end
    function r:SetColorTexture(...)self.color={...}end
    function r:SetShown(v)self.shown=v end
    function r:Show()self.shown=true end
    function r:Hide()self.shown=false end
    function r:SetFont(path,size,flags)self.font=path end
    function r:SetScript(event,callback)self.scripts[event]=callback end
    function r:HookScript(event,callback)self.scripts[event]=callback end
    function r:HasFocus()return self.focus end
    function r:GetText()return self.text or "" end
    function r:SetText(text)self.text=text;if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
    function r:SetFocus()self.focus=true;self.scripts.OnEditFocusGained()end
    function r:ClearFocus()self.focus=false;self.scripts.OnEditFocusLost()end
    return r
end
env.CreateFrame=function()return region()end
local accent={0.8,0.2,0.4}
local box=region();box.height=35
kt:StyleOptionsSearch(box,function()return unpack(accent)end)
local skin=box._searchSkin
local hint,icon=region(),region()
box:BindSearchParts(hint,icon)
assert(#skin.border==9 and skin.border[1].width==12)
assert(not skin.button and skin.clip.clips and not skin.clip.mouse)
assert(not skin.filterIcon,"unused filter removed")
assert(not skin.separator,"search has no trailing filter or separator")
assert(not box.scripts.OnUpdate,"idle search must not animate")
assert(icon.color[1]==accent[1] and skin.leftGlow.color[2]==accent[2])
box.scripts.OnEnter();box.scripts.OnUpdate(box,0.15)
assert(skin.hover>0 and skin.hover<1 and skin.shine.color[4]>0)
local sweepX=skin.shine.point[4]
box.scripts.OnUpdate(box,0.15)
assert(skin.hover==1 and skin.shine.point[4]>sweepX)
box.scripts.OnUpdate(box,0.2)
assert(not box.scripts.OnUpdate and skin.shine.color[4]==0,"shine stops after 500ms")
assert(skin.border[1].width==12,"hover keeps rounded corners")
box.scripts.OnLeave();box.scripts.OnUpdate(box,0.5)
assert(skin.hover==0 and skin.border[1].color[4]==0.25)
box:SetFocus();box.scripts.OnUpdate(box,0.3)
assert(not hint.shown and skin.hover==1)
box:ClearFocus();assert(hint.shown)
box.width=350;box.scripts.OnSizeChanged()
assert(skin.border[2].width==326)
accent={0.2,0.8,0.3};kt.FONT_PATH="User Font";box:RefreshSearchSkin()
assert(box.font=="User Font" and skin.border[1].color[2]==0.8 and skin.rightGlow.color[2]==0.8)
box.scripts.OnEnter();box.scripts.OnUpdate(box,0.05);box.scripts.OnHide()
assert(not box.scripts.OnUpdate and skin.hover==0)
local options=assert(io.open(root.."/KullThranUI/Options.lua")):read("*a")
local a=assert(options:find('    searchBox:SetScript("OnTextChanged"',1,true))
local b=assert(options:find('    local searchMouseWasDown',a,true))
local hint,clear=region(),region()
box:BindSearchParts(hint,icon)
local menu={_searchFilter="active"}
local queries,reflows={},0
local handlers=setmetatable({searchBox=box,searchHint=hint,searchClear=clear,f=menu,
    UpdateSearchResults=function(query)queries[#queries+1]=query end,
    RequestMenuPageReflow=function()reflows=reflows+1 end},{__index=_G})
local events=assert(loadstring(options:sub(a,b-1)));setfenv(events,handlers);events()
box.text="Cast Bar";box.scripts.OnTextChanged(box,true)
assert(clear.shown and not hint.shown and queries[#queries]=="Cast Bar")
clear.scripts.OnClick()
assert(box:GetText()=="" and not clear.shown and not hint.shown and box:HasFocus())
assert(menu._searchFilter==nil and queries[#queries]=="" and reflows==1)
box.text="Party";box.scripts.OnEscapePressed(box)
assert(box:GetText()=="" and not box:HasFocus() and reflows==2)
local first=assert(options:find("    local function SubmitSearch()",1,true))
local last=assert(options:find("    f.searchBox = searchBox",first,true))
local submit=assert(loadstring(options:sub(first,last-1)));setfenv(submit,handlers);submit()
box.text="Nameplates";box.scripts.OnEnterPressed(box)
assert(queries[#queries]=="Nameplates")
assert(options:find('searchIcon:SetSize(21, 21)',1,true))
assert(options:find('searchClear:SetPoint("RIGHT", searchBox, "RIGHT", -12, 0)',1,true))
local toc=assert(io.open(root.."/KullThranUI/KullThranUI.toc")):read("*a")
assert(toc:find("SearchInput.lua",1,true)<toc:find("Options.lua",1,true))
print("options_search_skin: rounded surface, accent halos, 500ms sheen, hover, accent, font, clear, Escape, Enter passed")
