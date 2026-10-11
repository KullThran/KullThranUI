local root = arg[1] or "."
local function region()
    local r = { points = {}, masks = {}, shown = true, w = 160, h = 70, level = 1 }
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = {...} end
    function r:SetSize(w,h) self.w,self.h = w,h end
    function r:SetScale(v) self.scale=v end
    function r:GetWidth() return self.w end
    function r:GetHeight() return self.h end
    function r:SetAllPoints(other) self.all = other end
    function r:GetFrameLevel() return self.level end
    function r:SetFrameLevel(v) self.level = v end
    function r:EnableMouse(v) self.mouse = v end
    function r:CreateTexture() return region() end
    function r:CreateMaskTexture() return region() end
    function r:CreateFontString() return region() end
    function r:SetTexture(v) self.texture = v end
    function r:SetStatusBarTexture(v) self:GetStatusBarTexture():SetTexture(v) end
    function r:SetAtlas(v) self.atlas = v end
    function r:SetTexCoord(...) self.coords = {...} end
    function r:SetVertexColor(...) self.color = {...} end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:SetShown(v) self.shown = v end
    function r:AddMaskTexture(v) self.masks[v] = true end
    function r:RemoveMaskTexture(v) self.masks[v] = nil end
    function r:GetStatusBarTexture() self.fill = self.fill or region(); return self.fill end
    function r:GetStatusBarColor() return unpack(self.barColor or {1,1,1,1}) end
    function r:SetStatusBarColor(...) self.barColor={...} end
    function r:GetFont() return "Fonts/FRIZQT__.TTF", 12, "OUTLINE" end
    function r:SetFont(path,size,outline) self.fontSize = size end
    function r:SetJustifyH(v) self.justify = v end
    function r:SetTextColor(...) self.textColor = {...} end
    function r:SetFormattedText(fmt,...) self.text = string.format(fmt,...) end
    function r:SetText(v) self.text = v end
    function r:GetValue() return 73 end
    function r:GetMinMaxValues() return 0,100 end
    return r
end
local cfg = { showPortrait = true, portraitStyle = "circular", showPowerBar = true }
local combat, globalTheme = false, "kui"
local mod = { db = { party = cfg }, refreshes = 0 }
function mod:GetModeDB(mode) return cfg end
function mod:EnsureDB() end
function mod:SetConfigValue(mode,key,value) self:GetModeDB(mode)[key]=value;return true end
function mod:RefreshAll() self.refreshes = self.refreshes + 1 end
function mod:PositionFrame(frame,parent,index,count,mode) frame.originalMode=mode; return "layout" end
function mod:UpdateFrameVisual(frame) frame.originalPaint = true; return "paint" end
function mod:UpdateFramePowerEvent(frame, event) frame.power:SetShown(event ~= "hide"); return "power" end
local kt = { GetModule = function() return mod end,
    VisualThemes = { GetRenderedTheme = function() return globalTheme end } }
local ns = { PF_Portrait = { PlaceBadges=function(frame,opts)
    if not opts.pvpAnchor or opts.pvpAnchor=="AUTO" then
        frame.pvpIcon:ClearAllPoints()
        frame.pvpIcon:SetPoint("RIGHT",frame.portraitFrame,"LEFT",-2,0)
    end
end } }
local env = setmetatable({ LibStub = function() return { GetAddon = function() return kt end } end,
    CreateFrame = function() return region() end,
    InCombatLockdown = function() return combat end,
    UnitPower = function() return 25 end, UnitPowerMax = function() return 50 end,
}, { __index = _G })
local f=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames_Styles.lua"))
local code=f:read("*a");f:close()
local fn=assert(loadstring(code));setfenv(fn,env);fn("KullThranUI_PartyFrames",ns)
local S=ns.PF_Styles
assert(#S.tabs == 4)
local frame=region();frame.mode="party";frame.unit="party1"
for _,key in ipairs({"health","power","portraitFrame","portrait","portraitBG","portraitClass","portraitBorder","overlayFrame","auraFrame","absorb","nameText","valueText","statusText","leaderIcon","roleIcon","levelText","pvpIcon","borderKT"}) do frame[key]=region() end
frame.health.bg=region();frame.power.bg=region()
frame.portraitBorderFrame=region()
for _,key in ipairs({"retail","forever","classic"}) do
    assert(S.Select(key));assert(S.Current()==key)
    mod:PositionFrame(frame,nil,1,4,"party")
    assert(not frame.portraitBorderFrame.shown,"native Party art owns the portrait border")
    assert(mod:PositionFrame(frame,nil,1,4,"party") == "layout")
    assert(frame.originalMode == "party")
    assert(mod:UpdateFrameVisual(frame) == "paint" and frame.originalPaint)
    assert(frame._pfNativeArt.shown and not frame.borderKT.shown and not frame.portraitBorder.shown)
    assert(frame.nameText.justify == "LEFT" and frame.valueText.justify == "CENTER")
    assert(frame._pfNativePowerText.text == "25 / 50")
    mod:UpdateFramePowerEvent(frame, "hide"); assert(not frame._pfNativePowerText.shown)
    assert(mod:UpdateFramePowerEvent(frame, "UNIT_POWER_FREQUENT") == "power" and frame._pfNativePowerText.shown)
    assert(frame.health.points[1][2] == frame._pfNativeArt)
    if key=="retail" then assert(frame._pfNativeArt.texture.texture == 4681512)
    elseif key=="forever" then assert(frame._pfNativeArt.texture.texture:find("forever_unitframe.tga",1,true))
    else assert(frame._pfNativeArt.texture.texture == "Interface\\TargetingFrame\\UI-PartyFrame") end
    for _,size in ipairs({{120,53},{240,106},{160,90},{300,40}}) do
        local g,s,x,y=S.Geometry(key,size[1],size[2])
        assert(math.abs(g.w*s + x*2-size[1]) < 0.0001)
        assert(math.abs(g.h*s + y*2-size[2]) < 0.0001)
    end
end
-- Generic visual refreshes and combat must never replace native PvP anchors.
for _,key in ipairs({"retail","forever","classic"}) do
 S.Select(key);mod:PositionFrame(frame,nil,1,4,"party")
 ns.PF_Portrait.PlaceBadges(frame,{pvpAnchor="AUTO",pvpX=2,pvpY=-1})
 local point=frame.pvpIcon.points[1]
 assert(point[1]=="CENTER" and point[2]==frame.portraitFrame and point[3]=="BOTTOMLEFT")
 local pad=frame._pfNativePad or 0
 assert(point[4]==3*frame._pfNativeScale+pad+2 and point[5]==3*frame._pfNativeScale+pad-1)
 combat=true
 local clear=frame.pvpIcon.ClearAllPoints
 frame.pvpIcon.ClearAllPoints=function() error("secure PvP anchor changed in combat") end
 ns.PF_Portrait.PlaceBadges(frame,{pvpAnchor="AUTO"})
 mod:UpdateFrameVisual(frame)
 frame.pvpIcon.ClearAllPoints=clear;combat=false
 -- Explicit anchors belong to the user's generic layout.
 frame.pvpIcon:ClearAllPoints();frame.pvpIcon:SetPoint("TOPRIGHT",frame,"TOPRIGHT",9,8)
 ns.PF_Portrait.PlaceBadges(frame,{pvpAnchor="TOPRIGHT"})
 assert(frame.pvpIcon.points[1][1]=="TOPRIGHT" and frame.pvpIcon.points[1][4]==9)
end
S.Select("kui");mod:PositionFrame(frame,nil,1,4,"party")
assert(not frame._pfNativeArt.shown and frame.borderKT.shown)
assert(frame.portraitBorderFrame.shown,"KUI restores its portrait border host")
assert(next(frame.health:GetStatusBarTexture().masks)==nil and next(frame.portrait.masks)==nil)
assert(not frame._pfNativePowerText.shown and frame.nameText.textColor[2]==1)
S.Select("retail");combat=true;local refreshes=mod.refreshes
S.Select("classic");assert(S.Current()=="retail" and mod.pendingAll and mod.refreshes==refreshes)
combat=false;assert(S.Current()=="classic")
mod:PositionFrame(frame,nil,1,4,"raid")
assert(not frame._pfNativeArt.shown,"native Party art never leaks into compact raid frames")
assert(not S.Select("unknown"))
mod.db.partyFrameStyle=nil;globalTheme="forever";assert(S.Current()=="forever")
mod.db.partyFrameStyle="kui";assert(S.Current()=="kui","local style overrides global theme")
S.Apply(frame,cfg,"party",true,true,"retail")
assert(frame._pfNativeStyle=="retail" and S.Current()=="kui","card uses its own theme without changing live selection")
frame.buffIcons={region(),region()};frame.debuffIcons={region()}
frame.ccIcon,frame.missingBuffIcon=region(),region()
frame.model3D,frame.ringFrame=region(),region()
S.Apply(frame,cfg,"party",true,true,"kui")
assert(not frame._pfNativeArt.shown and frame.portraitFrame.level>frame.health.level and frame.portraitFrame.level>frame.power.level,"KUI preview restores portrait layering")
assert(frame.model3D.level>frame.health.level and frame.ringFrame.level>frame.model3D.level,"3D face and ring stay above bars")
assert(not ns.PF_Portrait.IsBelowHealth(),"live portraits stay above the bars too")
for _,icon in ipairs({frame.buffIcons[1],frame.buffIcons[2],frame.debuffIcons[1],frame.ccIcon,frame.missingBuffIcon}) do
    assert(icon.level>frame.health.level and icon.level>frame.power.level and icon.level>frame.ringFrame.level,"KUI preview icons remain above frame bars")
end
local previewIconFields={"ccIcon","missingBuffIcon","roleIcon","leaderIcon","raidTargetIcon","readyCheckIcon","statusIcon","pvpIcon"}
for _,field in ipairs(previewIconFields) do frame[field]=frame[field] or region() end
local function showSampleIcons()
    for _,field in ipairs(previewIconFields) do frame[field]:Show() end
    for _,pool in ipairs({frame.buffIcons,frame.debuffIcons}) do
        for _,icon in ipairs(pool) do icon:Show() end
    end
end
for _,key in ipairs({"retail","forever","classic"}) do
    showSampleIcons()
    S.Apply(frame,cfg,"party",true,true,key)
    for _,field in ipairs(previewIconFields) do assert(not frame[field]:IsShown(),key.." preview hides "..field) end
    for _,pool in ipairs({frame.buffIcons,frame.debuffIcons}) do
        for _,icon in ipairs(pool) do assert(not icon:IsShown(),key.." preview hides aura icons") end
    end
    showSampleIcons()
    S.Apply(frame,cfg,"party",false,true,key)
    for _,field in ipairs(previewIconFields) do
        assert(frame[field]:IsShown()==(field~="missingBuffIcon"),"live icons preserve native reminder suppression")
    end
end
showSampleIcons()
S.Apply(frame,cfg,"party",true,true,"kui")
for _,field in ipairs(previewIconFields) do assert(frame[field]:IsShown(),"KUI preview retains "..field) end
mod.db.partyDispelOverlayByStyle=nil
for _,key in ipairs({"kui","retail","forever","classic"}) do
    S.Select(key)
    assert(mod:GetModeDB("party").showDispelOverlay==(key=="kui"),"overlay defaults by theme")
end
S.Select("retail");mod:SetConfigValue("party","showDispelOverlay",true)
S.Select("classic");assert(not mod:GetModeDB("party").showDispelOverlay)
S.Select("retail");assert(mod:GetModeDB("party").showDispelOverlay,"manual overlay choice survives theme switches")
S.PreviewCardLevel(frame,"kui",0.5)
local point=frame.levelText.points[1]
assert(point[1]=="TOP" and point[2]==frame.portraitFrame and point[5]<0 and frame.levelText.justify=="CENTER","KUI card level sits at top of portrait")
for _,key in ipairs({"retail","forever","classic"}) do
    S.PreviewCardLevel(frame,key,0.5)
    point=frame.levelText.points[1]
    assert(point[1]=="BOTTOMLEFT" and point[2]==frame.portraitFrame and frame.levelText.justify=="LEFT","native card digits use portrait left side")
end
S.Select("kui")
local kuiWidth,kuiHeight=mod:GetModeDB("party").frameWidth,mod:GetModeDB("party").frameHeight
for _,key in ipairs({"retail","forever","classic"}) do
    S.Select(key)
    local native=mod:GetModeDB("party")
    assert(native.frameWidth==kuiWidth*1.25*1.25 and native.frameHeight==kuiHeight*1.25*1.25,"native defaults include the existing size migration")
    mod:GetModeDB("party")
    assert(native.frameWidth==kuiWidth*1.25*1.25,"refresh must not compound the size increase")
end
S.Select("retail");mod:SetConfigValue("party","frameWidth",320)
S.Select("kui");assert(mod:GetModeDB("party").frameWidth==kuiWidth,"KUI size stays unchanged")
S.Select("retail");assert(mod:GetModeDB("party").frameWidth==320,"manual size survives theme switching")
S.Select("kui")
frame.dispelBorderFrame=region();frame.dispelBorderFrame.level=40
frame.portraitModel=region()
S.Apply(frame,cfg,"party",false,true)
assert(frame.portraitFrame.level>40,"Party Test portrait stays above the dispel overlay")
assert(frame.portraitModel.level>frame.portraitFrame.level)
assert(frame.portraitBorderFrame.level>frame.portraitFrame.level)
assert(frame.auraFrame.level>frame.portraitBorderFrame.level)
S.SetHealthColor("classic",false,{r=0.3,g=0.7,b=0.2})
assert(S.Current()=="kui","editing another card must not switch the live theme")
S.Select("classic")
assert(mod:GetModeDB("party").colorByClass==false)
assert(mod:GetModeDB("party").customHealthColor.g==0.7)
S.Select("kui");assert(mod:GetModeDB("party").colorByClass)
S.Select("classic");assert(not mod:GetModeDB("party").colorByClass)
mod:SetConfigValue("party","colorByClass",true)
assert(S.GetHealthSettings("classic").colorByClass,"existing class color option stays in sync")
print("party_frame_styles: art, geometry, cleanup, preview skin and combat selection passed")
-- Model secure child frames rejecting geometry changes during combat. Full
-- repaint resets generic alignment/fills; the native skin must repair only paint.
for _,key in ipairs({"retail","forever","classic"}) do
    S.Select(key)
    S.Apply(frame,cfg,"party",false,true)
    local healthPoint=frame.health.points[1]
    local powerPoint=frame.power.points[1]
    local protected={frame,frame.health,frame.power,frame.portraitFrame,frame._pfNativeArt,frame.absorb}
    local saved={}
    for _,r in ipairs(protected) do
        saved[r]={r.ClearAllPoints,r.SetPoint,r.SetSize}
        r.ClearAllPoints=function() error("combat changed secure anchors") end
        r.SetPoint=function() error("combat changed secure anchors") end
        r.SetSize=function() error("combat changed secure size") end
    end
    combat=true
    for _,state in ipairs({"Alive","AFK","Alive","Dead","Alive","Offline","Alive"}) do
        frame.statusText:SetShown(state=="Dead" or state=="Offline")
        frame.statusIcon:SetShown(state~="Alive")
        frame.valueText:SetJustifyH("RIGHT")
        frame.health:SetStatusBarTexture("generic")
        mod:UpdateFrameVisual(frame)
        assert(frame.valueText.justify=="CENTER",key.." health remains centered in combat")
        assert(frame.valueText.points[1][2]==frame.health)
        if state=="Alive" then assert(frame.valueText.w==70*frame._pfNativeScale,"status transition restores full health width") end
        assert(frame.health.points[1]==healthPoint and frame.power.points[1]==powerPoint)
        assert(frame.health.fill.texture==(key=="classic" and "Interface\\TargetingFrame\\UI-StatusBar" or "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Health-Status"))
    end
    combat=false
    for r,methods in pairs(saved) do r.ClearAllPoints,r.SetPoint,r.SetSize=unpack(methods) end
end
print("PASS: native party combat repaint preserves secure bar geometry, centered health, status transitions and fills")
-- Execute the real UNIT_HEALTH fast path, including its unchanged-value return.
-- A stale generic alignment must be repaired even when health stays at 100%.
local core=assert(io.open(root.."/KullThranUI_PartyFrames/Modules/PartyFrames/PartyFrames.lua"))
local coreSource=core:read("*a");core:close()
local a=assert(coreSource:find("function Mod:UpdateFrameHealthEvent(frame)",1,true))
local b=assert(coreSource:find("function Mod:UpdateFramePowerEvent",a,true))
env.Mod=mod;env.ns=ns
env.IsUnitUsable=function() return true end
env.SafeUnitBoolean=function(fn) return fn() end
env.UnitIsDeadOrGhost=function() return false end
env.UnitIsConnected=function() return true end
env.UnitHealthPercent=function() return 100 end
env.CurveConstants={ScaleTo100={}}
env.IsSecretValue=function() return false end
env.SetHealthText=function(text) text:SetText("1.4K/1.4K") end
fn=assert(loadstring(coreSource:sub(a,b-1)));setfenv(fn,env);fn()
function frame.health:SetValue(value) self.value=value end
for _,key in ipairs({"retail","forever","classic"}) do
    S.Select(key);S.Apply(frame,cfg,"party",false,true)
    frame._ktEventDead=false;frame._ktEventConnected=true
    frame.statusIcon:Hide();frame.statusText:Hide()
    local healthPoint=frame.health.points[1]
    for _,unchanged in ipairs({false,true}) do
        frame._ktHealthPct=unchanged and 100 or 50
        frame.valueText:SetJustifyH("RIGHT")
        frame.valueText:ClearAllPoints()
        frame.valueText:SetPoint("RIGHT",frame.health,"RIGHT",-6,0)
        combat=true
        mod:UpdateFrameHealthEvent(frame)
        combat=false
        assert(frame.valueText.justify=="CENTER",key.." fast health event centers text")
        assert(frame.valueText.points[1][1]=="CENTER" and frame.valueText.points[1][4]==0)
        assert(frame.valueText.w==70*frame._pfNativeScale)
        assert(frame.health.points[1]==healthPoint,"health event must retain bar anchors")
    end
end
S.Select("kui");S.Apply(frame,cfg,"party",false,true)
frame.valueText:SetJustifyH("RIGHT");mod:UpdateFrameHealthEvent(frame)
assert(frame.valueText.justify=="RIGHT","KUI health keeps its alignment")
assert(coreSource:find('if centeredStatus or (frame.mode == "party" and frame._pfNativeStyle) then',1,true))
print("PASS: real native UNIT_HEALTH path repairs alignment including unchanged health; KUI remains unchanged")
