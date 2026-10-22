local root = arg[1] or "."

local function Region(kind)
    local o = { shown = true, alpha = 1, points = {}, kind = kind }
    setmetatable(o, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") and not key:find("^KT_") then return function() end end
    end })
    function o:Show() self.shown = true end
    function o:Hide() self.shown = false end
    function o:SetAlpha(a) self.alpha = a end
    function o:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function o:ClearAllPoints() self.points = {} end
    function o:SetSize(w, h) self.w, self.h = w, h end
    function o:SetTexture(path) self.texture = path end
    function o:SetTexCoord(...) self.coords = { ... } end
    function o:SetVertexColor(r, g, b) self.color = { r, g, b } end
    function o:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
    function o:SetBackdrop(b) self.backdrop = b end
    function o:GetFrameLevel() return 5 end
    function o:GetHeight() return 16 end
    function o:GetStringWidth() return 60 end
    function o:GetParent() return self.parent end
    function o:CreateTexture() local t = Region("texture"); t.parent = self; return t end
    return o
end

local theme = "kui"
local Mod = { db = { shape = "SQUARE" } }
local KT = {
    VisualThemes = { GetRenderedTheme = function() return theme end },
    GetModule = function() return Mod end,
    GetStyleAccentRGB = function() return 0.2, 0.6, 1 end,
}
_G.LibStub = function(name)
    if name == "AceAddon-3.0" then return { GetAddon = function() return KT end } end
    return nil
end
_G.CreateFrame = function() return Region("frame") end
local holder = Region("frame")
_G.KT_MinimapHolder_Main = holder
local zone = Region("frame")
zone.text = Region("font")
_G.KT_MinimapZoneText = zone
_G.KT_MinimapLocation = Region("frame")

assert(loadfile(root .. "/KullThranUI_Minimap/Modules/Minimap/SquareMinimap/SquareMinimap.lua"))()

local function Button()
    local b = Region("button")
    b._ktModernIconBackground = b:CreateTexture()
    b._ktModernIconHighlight = b:CreateTexture()
    b.Icon = b:CreateTexture()
    return b
end
Mod.guildMinimapButton, Mod.friendsMinimapButton, Mod.kuiSettingsButton = Button(), Button(), Button()

-- KUI: plain square, flat buttons, white neutral zone colour.
assert(Mod:GetDecorStyleKey() == "kui" and not Mod:SquareThemeActive())
assert(select(1, Mod:GetZoneNeutralColor()) == 1)
Mod:UpdateThemeDecor()
assert(not Mod.guildMinimapButton.KT_ThemeDeco, "KUI keeps the flat accent squares")
assert(zone.KT_Plate and zone.KT_Plate.shown and zone.KT_Plate.line.shown, "KUI zone plate with accent line")

-- Each Visual Style: its own ring, frame and zone colour.
local rings = { retail = "GoldRing", forever = "C60", classic = "TrackingBorder" }
for style, ringFile in pairs(rings) do
    theme = style
    assert(Mod:SquareThemeActive())
    Mod:UpdateThemeDecor()
    local deco = Mod.guildMinimapButton.KT_ThemeDeco
    assert(deco and deco.ring.shown and deco.ring.texture:find(ringFile), style .. " ring")
    assert(not Mod.guildMinimapButton._ktModernIconBackground.shown, style .. " hides the flat square")
    assert(Mod.guildMinimapButton.Icon.w == 14)
    assert(holder.KT_ThemeFrame and holder.KT_ThemeFrame.shown, style .. " square frame")
end
theme = "retail"
Mod:UpdateThemeDecor()
assert(holder.KT_ThemeFrame.chevronTop.shown and holder.KT_ThemeFrame.slices.TL.texture:find("chat_retail"))
theme = "forever"
Mod:UpdateThemeDecor()
assert(not holder.KT_ThemeFrame.chevronTop.shown and holder.KT_ThemeFrame.slices.TL.texture:find("chat_forever"))
assert(zone.KT_Plate.chevron.shown, "Forever zone banner carries the bronze chevron")
theme = "classic"
Mod:UpdateThemeDecor()
assert(holder.KT_ThemeFrame.backdrop.edgeFile:find("Gold%-Border"))
assert(not holder.KT_ThemeFrame.slices.TL.shown)
local r, g = Mod:GetZoneNeutralColor()
assert(r == 1 and g == 0.82, "Classic zone text is Blizzard gold")

-- Back to KUI restores the flat buttons; the round shape drops the plate.
theme = "kui"
Mod:UpdateThemeDecor()
assert(not Mod.guildMinimapButton.KT_ThemeDeco.ring.shown and Mod.guildMinimapButton._ktModernIconBackground.shown)
assert(not holder.KT_ThemeFrame.shown)
Mod.db.shape = "ROUND"
Mod:UpdateThemeDecor()
assert(not zone.KT_Plate.shown)

-- A forced style overrides the Visual Style.
Mod.db.squareStyle = "forever"
assert(Mod:GetDecorStyleKey() == "forever")

print("PASS: minimap square frame, zone plate and side buttons follow each Visual Style")
