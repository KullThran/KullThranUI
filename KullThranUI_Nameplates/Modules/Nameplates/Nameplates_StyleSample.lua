-- Nameplates_StyleSample.lua
-- Live sample of a style's enemy plate for the Style Presets cards (Nameplates > General).
-- It is the plate a style gives you after picking it: the module defaults plus the
-- Visual Styles seed, drawn by the plates' own skin, level, border and combo code with
-- that style forced (ns.WithNameplateStyle), so the card cannot drift from the game.
local addonName, ns = ...
local KT = _G.KullThranUI

local WHITE = "Interface\\Buttons\\WHITE8x8"
local SAMPLE_HP, SAMPLE_CAST = 0.72, 0.55
local SAMPLE_PIPS, SAMPLE_LIT = 5, 3

-- What picking `style` leaves in the profile: module defaults + the adapter's seed.
local function StyleProfile(style)
    local P = {}
    for k, v in pairs(_G.KullThranUINameplatesDefaults or {}) do P[k] = v end
    local VT = KT and KT.VisualThemes
    local ad = VT and VT.GetModuleAdapter and VT:GetModuleAdapter("nameplates")
    if ad and ad.seed then pcall(ad.seed, P, style) end
    return P
end

local function Color(c, r, g, b)
    if type(c) == "table" then return c.r or c[1] or r, c.g or c[2] or g, c.b or c[3] or b end
    return r, g, b
end

local function Build(parent, style, opts)
    local P = StyleProfile(style)
    local W = (ns.BAR_W or 150) + ((ns.ThemeBarWidthExtra and ns.ThemeBarWidthExtra()) or P.healthBarWidth or 45)
    local H = (ns.ThemeBarHeight and ns.ThemeBarHeight()) or P.healthBarHeight or 30
    local CH = P.castBarHeight or 17
    local kui = style == "kui"

    -- `s` doubles as the plate the skin code reads (health, cast, name, level, badges).
    local s = CreateFrame("Frame", nil, parent)
    local health = CreateFrame("StatusBar", nil, s)
    health:SetSize(W, H)
    health:SetMinMaxValues(0, 100)
    health:SetValue(SAMPLE_HP * 100)
    s.health = health
    s.healthBG = health:CreateTexture(nil, "BACKGROUND")
    s.healthBG:SetAllPoints()
    s.healthBG:SetColorTexture(0.12, 0.12, 0.12, 1)
    health:SetStatusBarTexture(kui and ns.ResolveNameplateBarTexture(P.healthBarTexture) or WHITE)
    local r, g, b = Color(P.enemyInCombat, 0.8, 0.137, 0.137)
    if ns.BrightenNameplateColor then r, g, b = ns.BrightenNameplateColor(r, g, b) end
    health:SetStatusBarColor(r, g, b, 1)

    local cast = CreateFrame("StatusBar", nil, s)
    cast:SetSize(W, CH)
    cast:SetPoint("TOPLEFT", health, "BOTTOMLEFT", 0, 0)
    cast:SetMinMaxValues(0, 1)
    cast:SetValue(SAMPLE_CAST)
    s.cast = cast
    s.castBG = cast:CreateTexture(nil, "BACKGROUND")
    s.castBG:SetAllPoints()
    s.castBG:SetColorTexture(0.1, 0.1, 0.1, 0.9)
    cast:SetStatusBarTexture(kui and ns.ResolveNameplateBarTexture(P.castBarTexture) or WHITE)
    local edge = cast:CreateTexture(nil, "OVERLAY", nil, 7)
    edge:SetColorTexture(0, 0, 0, 1)
    edge:SetWidth(1)
    edge:SetPoint("TOPLEFT", cast, "TOPLEFT", 0, 0)
    edge:SetPoint("BOTTOMLEFT", cast, "BOTTOMLEFT", 0, 0)
    local iconFrame = CreateFrame("Frame", nil, cast)
    iconFrame:SetSize(CH, CH)
    iconFrame:SetPoint("TOPRIGHT", cast, "TOPLEFT", 0, 0)
    if KT and KT.PP and KT.PP.CreateBorder then KT.PP.CreateBorder(iconFrame, 0, 0, 0, 1, 1, "OVERLAY", 5) end
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(opts.icon)
    s.castIconFrame = iconFrame
    s.castName = cast:CreateFontString(nil, "OVERLAY")
    ns.SetFSFont(s.castName, P.castNameSize or 10)
    s.castName:SetPoint("LEFT", cast, "LEFT", 5, 0)
    s.castName:SetTextColor(Color(P.castNameColor, 1, 1, 1))
    s.castName:SetText(opts.spell or "")

    -- texts sit above the bars, like the plate's healthTextFrame
    local texts = CreateFrame("Frame", nil, s)
    texts:SetAllPoints(health)
    texts:SetFrameLevel(health:GetFrameLevel() + 12)
    s.name = texts:CreateFontString(nil, "OVERLAY")
    s.level = texts:CreateFontString(nil, "OVERLAY")
    ns.SetFSFont(s.level, P.levelFontSize or 11)
    s.level:SetText(tostring(opts.level or 60))
    s.level:SetShown(not kui)   -- the KUI look never shows the level
    local pct = texts:CreateFontString(nil, "OVERLAY")
    local blizzText = ns.ThemeBlizzText and ns.ThemeBlizzText()
    ns.SetFSFont(pct, (P.textSlotRightSize or 10) + (blizzText and 2 or 0))
    pct:SetPoint("RIGHT", health, "RIGHT", -2, 0)
    pct:SetTextColor(Color(P.textSlotRightColor, 1, 1, 1))
    pct:SetText(math.floor(SAMPLE_HP * 100 + 0.5) .. "%")
    s.pct = pct

    if kui then
        local tex = ns.PLATE_BORDER_TEX and ns.PLATE_BORDER_TEX[P.borderStyle]
        if tex and ns.BuildPlateBorder then
            s.borderFrame = ns.BuildPlateBorder(health, tex, P.borderColor or { r = 0, g = 0, b = 0 })
        end
        ns.SetFSFont(s.name, P.textSlotTopSize or 12)
    else
        ns.SetFSFont(s.name, blizzText and ((P.textSlotLeftSize or 10) + 2) or (P.textSlotTopSize or 12))
        ns.ApplyThemeSkin(s)
        ns.ApplyThemeLevel(s)
    end
    -- cast tint goes on the fill, after the skin bound its texture/atlas (ApplyCastColor)
    cast:SetStatusBarColor(1, 1, 1, 1)
    local cr, cg, cb = Color(P.castBar, 0.7, 0.4, 0.9)
    cast:GetStatusBarTexture():SetVertexColor(cr, cg, cb)
    s.name:SetTextColor(Color(P.textSlotTopColor, 1, 1, 1))
    s.name:SetText(opts.name or "")
    if blizzText then
        local inset = (ns.ThemeLevelInset and ns.ThemeLevelInset(s)) or 0
        s.name:SetPoint("LEFT", health, "LEFT", 4 + inset, 0)
        s.name:SetJustifyH("LEFT")
    else
        s.name:SetPoint("BOTTOM", health, "TOP", 0, 4)
        s.name:SetJustifyH("CENTER")
    end

    -- combo points under the cast bar, as on the target plate (classPowerPos "bottom")
    local cpScale = (P.classPowerScale or 1) * (style == "classic" and 0.8 or 1)
    local pw, ph, gap, round, comboPips = ns.ClassPowerPipLayout(true, cpScale, P.classPowerGap or 2, P.classPowerShape)
    local _, class = UnitClass("player")
    local cc = (P.classPowerClassColors ~= false) and ns.CP_CLASS_COLORS and ns.CP_CLASS_COLORS[class]
        or ns.CP_DEFAULT_COLOR or { 1, 0.84, 0.3 }
    local er, eg, eb = Color(P.classPowerEmptyColor, 0.2, 0.2, 0.2)
    local br, bgc, bb = Color(P.classPowerBgColor, 0.082, 0.082, 0.082)
    local cpY = P.classPowerYOffset or 3
    local half = (SAMPLE_PIPS * pw + (SAMPLE_PIPS - 1) * gap) / 2
    s.pips = {}
    for i = 1, SAMPLE_PIPS do
        local bg = s:CreateTexture(nil, "OVERLAY", nil, 2)
        local pip = s:CreateTexture(nil, "OVERLAY", nil, 3)
        pip._bg = bg
        pip:SetSize(pw, ph)
        pip:SetPoint("TOPLEFT", cast, "BOTTOM", (i - 1) * (pw + gap) - half, -cpY)
        ns.ApplyClassPowerPipShape(pip, round)
        bg:ClearAllPoints()
        bg:SetAllPoints(pip)
        bg:SetColorTexture(comboPips and 0.22 or br, comboPips and 0.02 or bgc, comboPips and 0.02 or bb, 1)
        local lit = i <= SAMPLE_LIT
        if lit then
            pip:SetColorTexture(comboPips and 1.0 or cc[1], comboPips and 0.05 or cc[2], comboPips and 0.05 or cc[3], 1)
        else
            pip:SetColorTexture(comboPips and 0.22 or er, comboPips and 0.02 or eg, comboPips and 0.02 or eb, 1)
        end
        ns.StyleForeverComboPip(pip, lit)
        s.pips[i] = pip
    end

    -- holder = the plate's bounding box; the bar is placed inside it
    local _, nameSize = s.name:GetFont()
    local top = blizzText and math.ceil(H * 0.281) or (4 + (nameSize or 12) + 2)
    local left = CH
    local right = 0
    if ns.ThemeLateralExtent and not kui then
        local _, rr = ns.ThemeLateralExtent(s)
        right = rr or 0
    end
    if style == "retail" then right = math.max(right, math.ceil(H * 0.25)) end
    local bottom = H + CH + cpY + ph
    s:SetSize(left + W + right, top + bottom)
    health:SetPoint("TOPLEFT", s, "TOPLEFT", left, -top)
    return s
end

-- Builds the sample for `style` under `parent` (opts: name, level, icon, spell).
-- Returns the holder frame, sized in plate pixels: the caller scales and places it.
function ns.BuildNameplateStyleSample(parent, style, opts)
    return ns.WithNameplateStyle(style, Build, parent, style, opts or {})
end

-- The installer draws its style preview with the same sample.
_G.KullThranUI_NameplatesOptions = _G.KullThranUI_NameplatesOptions or {}
_G.KullThranUI_NameplatesOptions.BuildStyleSample = function(parent, style, opts)
    return ns.BuildNameplateStyleSample(parent, style, opts)
end
