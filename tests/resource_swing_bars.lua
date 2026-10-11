_G.KT = {VisualThemes={}}
local now, weapon, offSpeed, rangedSpeed = 100, true, 2.5, 3
local driver, created
local nativeCVar, failCVar = "1", false
local frames = {}
local db = { enabled = true, general = { texture = 'Blizzard', bgA = 0.8, hideOOC = false }, primary = { borderSize = 1 } }
local mod, ns = {}, {}
ns.KRB = mod
local function Widget()
    local w = { shown = true }
    function w:SetPoint(...) self.point = { ... } end
    function w:ClearAllPoints() end
    function w:SetJustifyH(v) self.justify = v end
    function w:SetFont(font, size) assert(type(size) == 'number'); if font == 'invalid.ttf' then return false end; self.fontSize = size; return true end
    function w:SetText(v) assert(self.fontSize, "FontString:SetText(): Font not set"); self.text = v end
    function w:SetFontObject() self.fontSize = 11 end
    function w:SetTextColor() end
    function w:SetSize(width, height) self.width, self.height = width, height end
    function w:SetShown(v) self.shown = v end
    function w:IsShown() return self.shown end
    function w:Hide() self.shown = false end
    function w:Show() self.shown = true end
    function w:SetAlpha(v) self.alpha = v end
    function w:SetStatusBarTexture(v)
        self.texture = v
        if self.fill then
            self.fill.atlas = type(v)=='string' and v:match('^ui%-') and v or nil
        elseif type(v)=='string' and v:match('^ui%-') then
            self:GetStatusBarTexture().atlas=v
        end
    end
    function w:GetStatusBarTexture() self.fill=self.fill or Widget();self.fill._swingFillOwner=self;return self.fill end
    function w:CreateTexture() return Widget() end
    function w:SetAtlas(v)
        assert(not self._swingFillOwner,'fill atlas must be assigned through the StatusBar clipping API')
        self.atlas=v
    end
    function w:SetTexture(v) self.texture=v;self.atlas=nil end
    function w:SetTexCoord(...) self.coords={...} end
    function w:SetVertexColor(...) self.vertexColor={...} end
    function w:GetWidth() return self.width end
    function w:GetHeight() return self.height or 0 end
    function w:SetHeight(v) self.height=v end
    function w:SetFormattedText(format,...) self:SetText(string.format(format,...)) end
    function w:SetWidth(v) self.width=v end
    function w:SetStatusBarColor(...) self.color = { ... } end
    function w:SetColorTexture(...) self.bgColor = { ... } end
    function w:SetMinMaxValues(_, high) self.max = high end
    function w:SetValue(v) self.value = v end
    function w:CreateFontString(_, _, template)
        local text = Widget()
        if template then text:SetFontObject(template) end
        return text
    end
    return w
end
_G.LibStub = function() return { Fetch = function(_, _, name) return name end } end
_G.Enum = { PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 } }
_G.GetTime = function() return now end
_G.InCombatLockdown = function() return false end
_G.OffhandHasWeapon = function() return weapon end
_G.UnitAttackSpeed = function() return 2, offSpeed, rangedSpeed end
_G.UnitRangedDamage = function() return rangedSpeed end
local secret = {}
_G.issecretvalue = function(v) return v == secret end
_G._KRB_GetDB = function() ns.EnsureSwingDefaults(db); return db end
_G.C_Timer = { After = function(_, fn) fn() end }
_G.C_CVar = {
    GetCVar = function(name) assert(name == "showSwingTimer"); return nativeCVar end,
    SetCVar = function(name, value)
        assert(name == "showSwingTimer")
        if failCVar then error("blocked native CVar") end
        nativeCVar = value
        if driver and driver.scripts.OnEvent then driver.scripts.OnEvent(driver, "CVAR_UPDATE", name) end
    end,
}
_G.CreateFrame = function()
    local f = { scripts = {} }
    function f:RegisterEvent() return true end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    driver = f
    return f
end
ns.CreateResourceStatusBar = function(_, name)
    local bar = Widget()
    bar._text, bar._textFrame, bar._border, bar._bg = Widget(), Widget(), Widget(), Widget()
    bar._text:SetFont("font.ttf", 13)
    if name then frames[name] = bar end
    return bar
end
ns.GetResourceBarFont = function() return 'font.ttf' end
ns.ApplyResourceFrameArt = function(bar, _, art) bar.art = true; bar.themeArt = art end
function mod:BuildBars()
    self:BuildSwingBars(db, 250, function(bar) bar.stacked = true end)
end
local function Load()
    assert(loadfile('KullThranUI_ResourceBars/Modules/KUIResourceBars/KUIResourceBars_Swing.lua'))('ResourceBars', ns)
    ns.EnsureSwingDefaults(db)
end
local function Event(...) driver.scripts.OnEvent(driver, ...) end
local function Tick(time) now = time; if driver.scripts.OnUpdate then driver.scripts.OnUpdate(driver, 0.04) end end
Load()
assert(ns.SwingTimersSupported)
assert(db.swing.enabled == false)
db.swing.enabled = true
db.swing.fillMode = "remaining"
mod:BuildBars()
local main, off, ranged = frames.KUI_SwingBar_main, frames.KUI_SwingBar_off, frames.KUI_SwingBar_ranged
assert(main:IsShown() and off:IsShown() and ranged:IsShown())
assert(nativeCVar == "0" and db.swing.nativeCVarRestore == "1", "active KUI replaces native bars and saves preference")
assert(main.width == 250 and main.height == 18 and main.art and main.stacked)
assert(main._text.justify == 'RIGHT' and main._label.justify == 'LEFT')
assert(main._label.fontSize, 'label must have a font before its first text')
assert(main._text.text == '0.0' and not driver.scripts.OnUpdate, 'idle timers must not poll')
nativeCVar = '1'
Event('CVAR_UPDATE', 'showSwingTimer')
assert(nativeCVar == '0', 'native display stays suppressed while KUI owns it')
Event('PLAYER_SWING', 2, 0)
Event('PLAYER_SWING', 3, 1)
Tick(101)
assert(main.value == 1 and off.value == 2 and ranged.value == 0, 'hands must have independent clocks')
Event('PLAYER_SWING', 4, 2)
Tick(102)
assert(main.value == 0 and off.value == 1 and ranged.value == 3)
Event('WEAPON_SLOT_CHANGED')
assert(ranged.value == 3 and ranged._text.text == '3.0', 'weapon slot reset uses the equipped ranged speed')
local beforeSpeedChange = ranged.value
Event('UNIT_ATTACK_SPEED', 'player')
assert(ranged.value == beforeSpeedChange, 'attack speed refresh alone does not start an extra swing')
Event('PLAYER_EQUIPMENT_CHANGED', 1)
assert(ranged.value == 3, 'non-weapon equipment must not reset swings')
local beforeSecret = main.value
Event('PLAYER_SWING', secret, 0)
Event('PLAYER_SWING', 2, secret)
assert(main.value == beforeSecret, 'secret payload must not enter arithmetic or indexing')
db.swing.fillMode = 'elapsed'
Event('PLAYER_SWING', 4, 0)
Tick(103)
assert(main.value == 1 and main._text.text == '3.0', 'elapsed fill still shows remaining time')
db.swing.fillMode = 'remaining'
Tick(110)
assert(main.value == 0 and off.value == 0 and ranged.value == 0 and not driver.scripts.OnUpdate, 'do not invent recurring swings')
weapon = false
Event('PLAYER_EQUIPMENT_CHANGED', 17)
assert(not off:IsShown(), 'shield must not get an off-hand timer')
db.general.hideOOC = true
mod:UpdateSwingVisibility(db)
assert(main.alpha == 0)
db.general.hideOOC = false
mod:TestSwingBars()
assert(off:IsShown() and driver.scripts.OnUpdate, 'test must preview all selected hands')
Tick(117)
assert(not off:IsShown() and not driver.scripts.OnUpdate, 'test expires and restores equipment visibility')
db.enabled = false
mod:BuildBars()
assert(not main:IsShown() and not ranged:IsShown())
assert(nativeCVar == '1' and db.swing.nativeCVarRestore == nil, 'disabling module restores native preference')
db.enabled = true; db.swing.enabled = false
mod:BuildBars()
Event('PLAYER_SWING', 2, 0)
assert(not main:IsShown() and not driver.scripts.OnUpdate, 'disabled feature ignores swings')
-- Preview must neither change native display nor overwrite real swing clocks.
db.swing.enabled = true
mod:BuildBars()
Event('PLAYER_SWING', 20, 0)
mod:TestSwingBars()
Tick(124)
assert(main._text.text == '13.0', 'preview expiration resumes real countdown')
mod:OnDisable()
assert(nativeCVar == '1', 'module lifecycle restores native display')
db.swing.enabled = false
mod:TestSwingBars()
assert(nativeCVar == '1', 'disabled-feature preview leaves Blizzard alone')
Tick(131)
assert(not main:IsShown() and nativeCVar == '1')
-- Never enable native bars that the player had disabled before using KUI.
nativeCVar = '0'
db.swing.enabled = true
mod:BuildBars()
db.swing.enabled = false
mod:BuildBars()
assert(nativeCVar == '0', 'restore the actual original preference, including off')
-- A saved restoration value survives a UI reload with the native CVar off.
nativeCVar = '0'; db.swing.nativeCVarRestore = '1'; db.swing.enabled = true
Load(); mod:BuildBars()
db.swing.enabled = false; mod:BuildBars()
assert(nativeCVar == '1' and db.swing.nativeCVarRestore == nil, 'reload keeps the original native preference')
-- Font fallback must cover rejected custom font paths.
ns.GetResourceBarFont = function() return 'invalid.ttf' end
Load(); db.swing.enabled = true; mod:BuildBars()
ns.GetResourceBarFont = function() return 'font.ttf' end
-- Failed CVar writes remain recoverable and never change the saved preference.
mod:OnDisable(); failCVar = true; db.swing.enabled = true; mod:BuildBars()
assert(nativeCVar == '1' and ns.SwingNativeVisibilityError)
failCVar = false; mod:BuildBars()
assert(nativeCVar == '0' and not ns.SwingNativeVisibilityError)
Event('PLAYER_LOGOUT')
assert(nativeCVar == '1', 'logout releases native display before saving')
-- Every hand and the live test use the rendered theme, without modifying the
-- manual color, dimensions, timer settings or shared Resource Bars profile.
local expected = {
 classic = { 'Blizzard', 1, 'classic', .86, .62, .16 },
 forever = { 'Melli Dark', 2, 'default', .82, .65, .23 },
 retail = { 'Blizzard Raid Bar', 0, 'default', .12, .48, .95 },
 kui = { 'Melli Reforged', 1, 'default', .86, .62, .16 },
}
db.swing.useThemeAppearance = true
weapon,offSpeed,rangedSpeed=true,2.5,3
db.swing.fillR,db.swing.fillG,db.swing.fillB = .2,.3,.4
for _, theme in ipairs({'classic','forever','retail','kui','classic'}) do
 ns.GetResourceBarTheme=function() return theme end
 mod:BuildBars()
 for _,hand in ipairs({'main','off','ranged'}) do
  local bar=frames['KUI_SwingBar_'..hand];local style=expected[theme]
  assert(bar.texture==style[1] and bar._border.width==style[2] and bar.themeArt==style[3],theme..' material/chrome')
  assert(bar._border.shown==(style[2]>0),theme..' border visibility')
  for i=1,3 do assert(bar.color[i]==style[i+3],theme..' color') end
  assert(bar.width==250 and bar.height==18 and bar._label.fontSize==db.swing.textSize)
 end
 assert(db.general.texture=='Blizzard' and db.primary.borderSize==1, 'shared resources remain unchanged')
 assert(db.swing.fillR==.2 and db.swing.fillG==.3 and db.swing.fillB==.4,'manual color survives theme switches')
end
db.swing.useThemeAppearance=false;mod:BuildBars()
local manual=frames.KUI_SwingBar_main
assert(manual.texture=='Blizzard' and manual.color[1]==.2 and manual.color[3]==.4 and manual.themeArt==nil)
db.swing.useThemeAppearance=true;ns.GetResourceBarTheme=function() return 'retail' end
mod:TestSwingBars()
assert(frames.KUI_SwingBar_ranged.texture=='Blizzard Raid Bar' and frames.KUI_SwingBar_ranged.themeArt=='default','preview follows selected theme')
_G.C_Texture={GetAtlasInfo=function(name)
 if name=='ui-castingbar-textshadow-left' then return nil end
 return {}
end}
ns.GetResourceBarTheme=function() return 'forever' end
mod:BuildBars()
for hand,suffix in pairs({main='mainhand',off='offhand',ranged='ranged'}) do
 local bar=frames['KUI_SwingBar_'..hand]
 assert(bar.fill.atlas=='ui-swingtimerbar-filling-'..suffix,'native fill per weapon')
 assert(bar._swingArt.border.atlas=='ui-swingtimerbar-frame' and bar._swingArt.border.shown)
 assert(bar._swingArt.background.atlas=='ui-swingtimerbar-background')
 assert(bar._swingArt.shadow.atlas=='ui-swingtimerbar-textshadow-left')
 assert(bar.color[1]==1 and bar.color[2]==1 and bar.color[3]==1,'do not tint precolored native atlas')
 assert(not bar._border.shown and not bar._bg.shown)
end
ns.GetResourceBarTheme=function() return 'retail' end;mod:BuildBars()
local bar=frames.KUI_SwingBar_main
assert(bar._swingArt.border.texture:find('UICastingBar-Retail.blp',1,true) and bar.fill.atlas=='ui-castingbar-filling-standard')
assert(bar._swingArt.border.coords[1]==1/512 and bar._swingArt.border.coords[4]==47/256)
assert(not bar._swingArt.background.shown and bar._bg.shown,'Retail has a plain dark empty background')
assert(not bar._swingArt.shadow.shown,'unavailable optional atlas is hidden')
for _,theme in ipairs({'classic','kui'}) do
 ns.GetResourceBarTheme=function() return theme end;mod:BuildBars()
 for _,texture in pairs(bar._swingArt) do assert(not texture.shown,'old native decoration hidden') end
 assert(bar.fill.atlas==nil and bar._bg.shown,'file material restored')
end
ns.GetResourceBarTheme=function() return 'forever' end
db.swing.useThemeAppearance=false;mod:BuildBars()
assert(not bar._swingArt.border.shown and bar.color[1]==.2,'manual mode removes atlas art')
_G.C_Texture.GetAtlasInfo=function() return nil end
db.swing.useThemeAppearance=true;mod:BuildBars()
assert(not bar._swingArt.border.shown and bar.texture=='Melli Dark','missing atlas falls back to valid theme material')
-- Load the real core resolver with all client swing atlases absent.
local assetFile=assert(io.open((arg[1] or ".").."/KullThranUI/Modules/VisualThemes/ThemeClientAssets.lua"))
local assetSource=assetFile:read("*a");assetFile:close()
local helper=assert(loadstring(assetSource:sub((assert(assetSource:find("-- Original Forever swing sheet",1,true))))))
helper()
mod:BuildBars()
for _,hand in ipairs({'main','off','ranged'}) do
 local packaged=frames['KUI_SwingBar_'..hand]
 assert(packaged._swingArt.border.shown and packaged._swingArt.border.texture:find('UISwingTimerBar-Forever.blp',1,true))
 assert(packaged.texture:find('UISwingTimerBar-Forever.blp',1,true))
 assert(packaged.fill.coords[1]==1/512 and packaged.fill.coords[2]==419/512)
 ns.PaintSwingPreviewBar(packaged,db,1)
end
print('PASS: actual swing bars use packaged frame, background and per-hand fill without native atlases')
mod:HideSwingBars()
-- Embedded preview uses separate frames and the same style function, without
-- enabling live bars, touching Blizzard's CVar or waking the real swing driver.
_G.C_Texture.GetAtlasInfo=function() return {} end
db.swing.enabled=false
local savedCVar=nativeCVar
local previewParent=Widget()
local previews={}
for index,hand in ipairs({'main','off','ranged'}) do
 local preview=ns.CreateSwingPreviewBar(previewParent,db,hand)
 previews[index]=preview
 for _,theme in ipairs({'forever','retail','classic','kui'}) do
  ns.GetResourceBarTheme=function() return theme end
  ns.StyleSwingBar(preview,db,hand,190)
  ns.PaintSwingPreviewBar(preview,db,index)
  assert(preview.width==190 and preview.height==db.swing.height)
  assert(preview.value>=0 and preview.value<=index+1 and preview._text.text)
  if theme=='forever' then assert(preview._swingArt.border.atlas=='ui-swingtimerbar-frame') end
  if theme=='retail' then
   assert(not preview._swingArt.background.shown and preview._bg.shown,'preview has the same dark Retail background')
   assert(preview._swingArt.border.texture:find('UICastingBar-Retail.blp',1,true),'preview uses the original Retail border')
  end
 end
end
assert(nativeCVar==savedCVar and not driver.scripts.OnUpdate,'embedded preview cannot claim native bars or live clocks')
local optionsFile=assert(io.open('KullThranUI_ResourceBars/Modules/KUIResourceBars/KUI_ResourceBars_Options.lua'))
local options=optionsFile:read('*a');optionsFile:close()
local layoutStart=assert(options:find('        local swingAnchor =',1,true))
local layoutEnd=assert(options:find('        lblPreview:SetText',layoutStart,true))
local pane=Widget()
local health,power,class,pips,anchor=Widget(),Widget(),Widget(),Widget(),Widget()
health:SetSize(190,25);power:SetSize(190,25);class:Hide();pips:Hide()
local mode='stack'
db.swing.enabled=true
local env=setmetatable({fakeHealth=health,fakePower=power,fakeClassBar=class,fakePips=pips,fakeAnchor=anchor,
 fakeSwingBars=previews,swingHands={'main','off','ranged'},previewModeAvailability={swing=true},
 previewMode=mode,previewContainer=pane,db=db,ns=ns,w=190},{__index=_G})
local layout=assert(loadstring(options:sub(layoutStart,layoutEnd-1)));setfenv(layout,env);layout()
assert(previews[1].point[2]==health and previews[2].point[2]==previews[1] and previews[3].point[2]==previews[2])
assert(pane.height>=60+45+25+25+3*db.swing.height,'preview expands to contain the full stack')
health:Hide();power:Hide();env.previewMode='swing';layout()
assert(previews[1].point[2]==pane and previews[2].point[2]==previews[1],'dedicated preview stacks without hidden resource anchors')
db.swing.off=false;layout();assert(not previews[2].shown and previews[3].point[2]==previews[1])
env.previewModeAvailability.swing=false;layout()
for _,preview in ipairs(previews) do assert(not preview.shown,'disabled preview bars are hidden') end
print('PASS: embedded swing preview shares theme atlas renderer, isolated animation and responsive stack layout')
-- Real atlas bars must clear their fill at expiry, even when restyled while
-- already idle. Check all hands and both fill directions through native events.
mod._swingPreviewUntil=nil
db.swing.enabled=true;db.swing.main=true;db.swing.off=true;db.swing.ranged=true
db.swing.useThemeAppearance=true
for _,theme in ipairs({'forever','retail'}) do
 ns.GetResourceBarTheme=function() return theme end
 for _,mode in ipairs({'elapsed','remaining'}) do
  db.swing.fillMode=mode;now=500;mod:BuildBars()
  for _,swingType in ipairs({0,1,2}) do Event('PLAYER_SWING',2,swingType) end
  Tick(501)
  for _,hand in ipairs({'main','off','ranged'}) do
   local live=frames['KUI_SwingBar_'..hand]
   assert(live.value==1 and live.fill.shown,'running atlas timer has a partial visible fill')
  end
  Tick(503)
  for _,hand in ipairs({'main','off','ranged'}) do
   local live=frames['KUI_SwingBar_'..hand]
   assert(live.value==0 and not live.fill.shown and not live._swingArt.pip.shown,'expired atlas timer is empty')
   assert(live._text.text=='0.0')
  end
  mod:BuildBars()
  assert(not frames.KUI_SwingBar_main.fill.shown and not driver.scripts.OnUpdate,'reskinning idle zero cannot show a full fill')
 end
end
db.swing.fillMode='elapsed';now=600
local preview=previews[1]
ns.StyleSwingBar(preview,db,'main',190)
ns.PaintSwingPreviewBar(preview,db,1)
assert(preview.value==0 and not preview.fill.shown,'zero preview fill is empty too')
now=600.5;ns.PaintSwingPreviewBar(preview,db,1)
assert(preview.fill.shown and preview.value==.5,'preview fill returns as its cycle advances')
mod:HideSwingBars()
print('PASS: native atlas clipping, zero/expired fills, idle reskin and preview restart')
local asset=assert(io.open('KullThranUI/Libraries/texture/media/resourcebars/UICastingBar-Retail.blp','rb'))
local bytes=asset:read('*a');asset:close()
assert(bytes:sub(1,4)=='BLP2' and #bytes==525460,'original Retail sheet is packaged')
_G.Enum = nil
Load()
db.swing.enabled = true
mod:BuildBars()
assert(not ns.SwingTimersSupported and not main:IsShown(), 'unsupported client must not show simulated live timers')
print('Resource Bars native swing tests passed')

-- The saved order drives both the actual bars and the stack preview.
_G.Enum = { PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 } }
Load()
db.swing.main=true;db.swing.off=true;db.swing.ranged=true;db.swing.order={"ranged","main","off"}
weapon=true;offSpeed=2.5;rangedSpeed=3
local stacked={}
mod:BuildSwingBars(db,250,function(bar)
 for _,hand in ipairs({"main","off","ranged"}) do if frames["KUI_SwingBar_"..hand]==bar then stacked[#stacked+1]=hand end end
end)
assert(table.concat(stacked,",")=="ranged,main,off","live layout must use the saved hand order")
env.previewModeAvailability.swing=true;env.previewMode="swing";layout()
assert(previews[3].point[2]==pane and previews[1].point[2]==previews[3] and previews[2].point[2]==previews[1],"preview must use the same reordered stack")
print("PASS: actual swing bar build and live preview agree on persisted custom order")
