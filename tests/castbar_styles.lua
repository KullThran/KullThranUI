local root = arg[1] or "."
local function eq(a, b, msg) assert(a == b, (msg or "value") .. ": " .. tostring(a) .. " ~= " .. tostring(b)) end
local frames = {}
local function Region(parent, kind)
    local r = { parent = parent, kind = kind, shown = true, points = {}, scripts = {}, width = 600, height = 25 }
    function r:GetWidth() return self.width end
    function r:GetHeight() return self.height end
    function r:SetWidth(v) self.width = v end
    function r:SetHeight(v) self.height = v end
    function r:SetSize(w, h) self.width, self.height = w, h end
    function r:SetScale(v) self.scale = v end
    function r:GetEffectiveScale() return self.scale or 1 end
    function r:SetPoint(...) self.points[#self.points+1] = {...} end
    function r:ClearAllPoints() self.points = {} end
    function r:SetAllPoints() end
    function r:SetStatusBarTexture(v) self.texture = v; self.fill = self.fill or Region(self, "texture") end
    function r:GetStatusBarTexture() return self.fill end
    function r:SetStatusBarColor(...) self.color = {...} end
    function r:SetTexture(v) self.texture = v; self.atlas = nil end
    function r:SetAtlas(v) self.atlas = v; self.texture = nil end
    function r:SetColorTexture(...) self.solid = {...} end
    function r:SetVertexColor(...) self.tint = {...} end
    function r:SetTexCoord(...) self.coords = {...} end
    function r:SetBlendMode(v) self.blend = v end
    function r:SetBackdrop(v) self.backdropDefinition = v end
    function r:SetBackdropColor(...) self.backdrop = {...} end
    function r:SetBackdropBorderColor(...) self.borderColor = {...} end
    function r:SetText(v) self.text = v end
    function r:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...) end
    function r:SetFont(...) self.font = {...} end
    function r:SetTextColor(...) self.textColor = {...} end
    function r:SetShadowOffset() end
    function r:SetJustifyH(v) self.justify = v end
    function r:SetDrawLayer(layer, sublevel) self.layer, self.sublevel = layer, sublevel end
    function r:SetDesaturated(v) self.desaturated = v end
    function r:SetWordWrap() end
    function r:SetHorizTile() end
    function r:SetVertTile() end
    function r:SetMinMaxValues(a, b) self.min, self.max = a, b end
    function r:SetValue(v) self.value = v end
    function r:SetAlpha(v) self.alpha = v end
    function r:GetParent() return self.parent end
    function r:SetParent(v) self.parent = v end
    function r:IsShown() return self.shown end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(v) self.shown = v end
    function r:GetFrameLevel() return self.level or 10 end
    function r:SetFrameLevel(v) self.level = v end
    function r:SetFrameStrata() end
    function r:CreateTexture() return Region(self, "texture") end
    function r:CreateFontString() return Region(self, "font") end
    function r:CreateMaskTexture() return Region(self, "mask") end
    function r:AddMaskTexture() end
    function r:SetScript(k, v) self.scripts[k] = v end
    function r:SetEnabled(v) self.enabled = v end
    return r
end
UIParent = Region(nil, "frame")
CreateFrame = function(kind, name, parent)
    local f = Region(parent, kind); frames[#frames+1] = f; return f
end
local M = {}
local KT = { db = { profile = { visualTheme = { active = "kui", requested = "kui", schemaVersion = 3,
    slots = {}, modules = {}, applied = {} } } }, VisualThemes = {}, DEFAULT_FONT_NAME = "KUI Font" }
_G.KT = KT
function KT:NewModule() return M end
function KT:GetModule(name) if name == "CastBar" then return M end end
function KT:GetStyleAccentRGB() return .4, .5, .6 end
function KT:SetAccentTextColor() end
function KT:ResolveFontForLocale(font) return font end
function KT:RefreshPage() self.pageRefreshes = (self.pageRefreshes or 0) + 1 end
function KT:RegisterPage(key, label, order, callback) self.page = callback end
local lsm = { Fetch = function(_, kind, key) return key end }
LibStub = function(name)
    if name == "AceAddon-3.0" then return { GetAddon = function() return KT end } end
    if name == "LibSharedMedia-3.0" then return lsm end
end
UnitClass = function() return "Mage", "MAGE" end
RAID_CLASS_COLORS = { MAGE = { r = .1, g = .2, b = 1 } }
GetTime = function() return 11 end
UnitCastingInfo = function() return "Polymorph", "Polymorph", 123, 10000, 13000 end
UnitChannelInfo = function() return "Channel", "Channel", 123, 10000, 13000, nil, nil, 5143, false end
GetNetStats = function() return 0, 0, 0, 0 end
C_Texture = { GetAtlasInfo = function() return { width = 208, height = 11 } end }
WOW_PROJECT_MAINLINE, WOW_PROJECT_ID = 1, 1
ReloadUI = function() end
InCombatLockdown = function() return false end
C_Timer = { After = function() end }
SlashCmdList = {}
local function load(path) return assert(loadfile(root .. "/" .. path))("KullThranUI", {}) end
load("KullThranUI/Modules/VisualThemes/ThemeCatalog.lua")
load("KullThranUI/Modules/VisualThemes/ThemeSlots.lua")
load("KullThranUI/Modules/VisualThemes/ThemeRegistry.lua")
load("KullThranUI/Modules/VisualThemes/ThemeEngine.lua")
load("KullThranUI/Modules/VisualThemes/Adapters/CastBar.lua")
load("KullThranUI_CastBar/Modules/CastBar/CastBar_Styles.lua")
local S = KT.CastBarStyles
local db = { castbarStyle = "kui", width = 321, height = 27, scale = 1.2, autoWidth = false,
    autoPosition = false, position = { point = "CENTER", x = 14, y = 26 }, enable = true,
    texture = "My Texture", colorMode = "CUSTOM", color = { r = .2, g = .3, b = .4, a = 1 },
    classColor = true, font = "My Font", fontSize = 15, textColor = { r = 1, g = 1, b = 1, a = 1 },
    showIcon = true, iconShape = "SQUARE" }
KT.db.profile.castbar = db
S:Select(db, "classic")
eq(db.width, 195); eq(db.height, 13); eq(db.autoWidth, false)
eq(db.position.x, 14, "style leaves mover position alone"); eq(db.autoPosition, false)
S:Select(db, "retail"); eq(db.width, 208); eq(db.height, 17)
S:Select(db, "kui"); eq(db.width, 321); eq(db.texture, "My Texture"); eq(db.classColor, true)
eq(db.color.r, .2, "KUI custom colors restored")
-- Actual theme engine round trips: native sizes/colors are owned and KUI is restored.
eq(KT.VisualThemes:ApplyAll("classic"), true)
eq(db.width, 195); eq(db.castbarStyle, "classic")
eq(KT.VisualThemes:ApplyAll("forever"), true)
eq(db.width, 208); eq(db.castbarStyle, "forever")
eq(KT.VisualThemes:ApplyAll("kui"), true)
eq(db.width, 321); eq(db.texture, "My Texture"); eq(db.position.y, 26)
-- Persisted profiles with an already-applied theme still migrate once.
local state = KT.db.profile.visualTheme
state.active, state.requested = "classic", "classic"
state.applied.castbar = "classic"
state.slots.castbar = { kui = { texture = "Saved KUI", colorMode = "CUSTOM", color = { r = .3 } },
    classic = { texture = "Old Native" } }
db.castbarStyle = nil
KT.VisualThemes:ApplyCurrentThemeToModule("castbar")
eq(db.width, 195); eq(state.slots.castbar.kui.texture, "Saved KUI")
eq(state.slots.castbar.kui.width, 321, "old shared KUI size survives native migration")
eq(state.slots.castbar.kui.font, "My Font", "old shared KUI typography survives migration")
eq(state.slots.castbar.classic.width, 195)
db.width = 240; S:Migrate(db); eq(db.width, 240, "migration is idempotent")
db.kuiStyleSettings = nil
S:Select(db, "kui")
eq(db.texture, "Saved KUI", "module KUI picker can restore its global theme slot")
eq(db.width, 321)

load("KullThranUI_CastBar/Modules/CastBar/CastBar.lua")
local bar = Region(UIParent, "StatusBar")
bar.Text, bar.Time, bar.Spark = Region(bar), Region(bar), Region(bar)
bar.Icon, bar.IconBg = Region(bar), Region(bar)
bar.SafeZone = Region(bar)
M.bar, M.db = bar, db
function M:ClearChannelTicks() end
function M:UpdateChannelTicks() end
function M:StartBarUpdates() end
function M:DebugCastBar() end
for _, key in ipairs({ "classic", "forever", "retail", "kui" }) do
    S:Seed(db, key)
    db.color = db.color or { r = .4, g = .5, b = .6, a = 1 }
    M:ApplySettings()
    M:UNIT_SPELLCAST_START("UNIT_SPELLCAST_START", "player", "cast-1", 118)
    M:OnUpdate(bar, .01)
    eq(bar.value, 11, "real casting progress preserved")
    if key == "classic" then
        eq(bar.texture, "Interface\\TargetingFrame\\UI-StatusBar")
        eq(bar._ktCastStyleArt.border.texture, "Interface\\CastingBar\\UI-CastingBar-Border")
        eq(bar._ktCastStyleArt.border.width, 256)
        eq(bar.color[1], 1); eq(bar.color[2], .7)
        eq(bar.fill.tint[1], 1); eq(bar.fill.tint[2], .7); eq(bar.fill.tint[3], 0,
            "Classic yellow is applied to the actual fill region")
        eq(bar.Text.font[2], 10, "Classic text fits the 13px interior")
        eq(bar.Text.font[3], "OUTLINE", "Classic text has its outline")
        eq(bar.Time.font[2], 10)
        eq(bar.Icon.shown, false, "Classic has no spell icon")
        eq(bar.IconBg.shown, false, "Classic has no icon border")
        eq(bar._ktCastStyleArt.border.layer, "ARTWORK", "Classic frame covers the interior edges")
        eq(bar.fill.sublevel, 0); eq(bar.SafeZone.sublevel, 1)
        eq(bar.SafeZone.layer, "ARTWORK"); eq(bar._ktCastStyleArt.border.sublevel, 2)
        eq(bar._ktCastStyleArt.border.points[1][5], 28, "stock frame anchor retained")
        eq(bar.fill.layer, "ARTWORK"); eq(bar.fill.desaturated, false)
        eq(bar.fill.coords[1], 0); eq(bar.fill.coords[2], 1)
        eq(bar.Text.layer, "OVERLAY"); eq(bar.Text.sublevel, 7)
        eq(bar.Time.sublevel, 7, "time stays above the border and spark")
        eq(bar.Text.justify, "CENTER", "Classic name centered in its text area")
        eq(bar.Text.points[#bar.Text.points][5], 1, "Classic name raised one pixel")
        eq(bar.Time.points[#bar.Time.points][5], 1, "Classic time raised one pixel")
        eq(bar.Spark.points[#bar.Spark.points][5], 2)
    elseif key ~= "kui" then
        eq(bar.texture, "ui-castingbar-filling-standard", "progressing casts retain Blizzard striped Filling atlas")
        eq(bar._ktCastStyleArt.border.atlas, "ui-castingbar-frame")
        eq(bar.height, 17, "modern reference has room for its internal text")
        eq(bar.SafeZone.layer, "OVERLAY", "modern latency layer restored after Classic")
        eq(bar.Text.justify, "CENTER")
        eq(bar.color[1], 1, "global class/accent colors do not tint native atlas")
    else
        eq(bar._ktCastStyleArt.border.shown, false, "KUI hides native art")
    end
    eq(bar.Time.text, key == "kui" and "2.0" or "2.0 / 3.0")
    M:UNIT_SPELLCAST_CHANNEL_START("UNIT_SPELLCAST_CHANNEL_START", "player", "channel-1", 5143)
    M:OnUpdate(bar, .01)
    eq(bar.value, 2, "channel runs backwards")
    if key == "classic" then eq(bar.color[2], 1, "Classic channel green")
    elseif key ~= "kui" then eq(bar.texture, "ui-castingbar-filling-channel") end
end
CASTBAR_CLASSIC_YELLOW = { GetRGBA = function() return 1, 1, 1, 1 end }
bar.fill:SetVertexColor(1, 1, 1, 1)
bar.fill:SetTexCoord(.2, .4, .6, .8)
bar.fill:SetDesaturated(true)
bar.channeling, bar.empowering = false, false
S:Seed(db, "classic"); M:ApplySettings()
eq(bar.fill.coords[1], 0); eq(bar.fill.coords[2], 1)
eq(bar.fill.desaturated, false, "Classic repair resets inherited atlas crop and greyscale")
eq(bar.fill.tint[2], .7); eq(bar.fill.tint[3], 0, "inherited white tint cannot wash out Classic yellow")
local oldClassic = { castbarStyle = "classic", width = 195, height = 13,
    font = "Friz Quadrata TT", fontSize = 12, fontOutline = "OUTLINE" }
S:Migrate(oldClassic)
eq(oldClassic.fontSize, 10); eq(oldClassic.fontOutline, "OUTLINE")
eq(oldClassic.showIcon, false)
local previousClassic = { castbarStyle = "classic", _ktClassicCastArtV3 = true, fontSize = 10, fontOutline = "NONE", showIcon = true }
S:Migrate(previousClassic)
eq(previousClassic.fontOutline, "OUTLINE"); eq(previousClassic.showIcon, false)
previousClassic.fontOutline = "THICKOUTLINE"; S:Migrate(previousClassic)
eq(previousClassic.fontOutline, "THICKOUTLINE", "outline migration preserves subsequent custom flags")
db.showIcon = true; M:ApplySettings()
eq(bar.Icon.shown, false, "stale icon preference cannot show an icon in Classic")
oldClassic.fontSize = 14; S:Migrate(oldClassic)
eq(oldClassic.fontSize, 14, "text repair preserves subsequent customization")
local oldNative = { castbarStyle = "retail", width = 208, height = 11, fontSize = 10 }
S:Migrate(oldNative)
eq(oldNative.height, 17); eq(oldNative.fontSize, 12)
oldNative.height = 11; S:Migrate(oldNative)
eq(oldNative.height, 11, "native repair runs once and then preserves user sizing")
local customizedNative = { castbarStyle = "forever", width = 320, height = 24, fontSize = 14 }
S:Migrate(customizedNative)
eq(customizedNative.height, 24, "custom native sizes are preserved")
-- Browse each tab without touching the actual bar; Apply updates it immediately.
state.active = "kui"
S:Seed(db, "kui")
function M:Refresh() self.db = db; self:ApplySettings() end
KT.Options = { LText = function(s) return s end }
load("KullThranUI_CastBar/Modules/CastBar/CastBar_Options.lua")
local widgets = { Label = function() return nil, 20 end }
local first = #frames
KT.page(Region(UIParent), widgets)
local tabs, apply, preview = {}, nil, nil
for i = first+1, #frames do
    local f = frames[i]
    if f.key then tabs[f.key] = f end
    if f.kind == "Button" and f.text == "Applied" then apply = f end
    if f.kind == "StatusBar" then preview = f end
end
assert(apply and preview)
for _, key in ipairs({ "classic", "forever", "retail" }) do
    tabs[key].scripts.OnClick()
    eq(db.castbarStyle, "kui", "browsing never changes the live style")
    eq(preview.width, key == "classic" and 195 or 208)
    if key == "classic" then
        eq(preview.Icon.shown, false); eq(preview.IconBg.shown, false)
        eq(preview.Text.font[3], "OUTLINE")
    end
    eq(apply.enabled, true)
end
apply.scripts.OnClick()
eq(db.castbarStyle, "retail"); eq(bar.width, 208)
eq(KT.pageRefreshes, 1, "Apply refreshes the controls for the selected style")
eq(preview._ktCastStyleArt.border.atlas, bar._ktCastStyleArt.border.atlas, "live and preview share native art")
print("castbar_styles: presets, migration, live casts/channels, previews and Apply passed")
