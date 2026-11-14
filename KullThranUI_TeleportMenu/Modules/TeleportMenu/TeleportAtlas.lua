-- ============================================================================
-- TeleportAtlas.lua
-- Modules/TeleportMenu/TeleportAtlas.lua
-- The "Atlas" look of the Teleport Menu: a map table in a dark tone of the
-- Visual Style accent (tiled grid, faint contour lines, compass emblem), the
-- categories as tabs on top
-- and every teleport as a waypoint: a round icon inside an accent ring with
-- its full name and a status line. Only drawing lives here; TeleportMenu.lua
-- keeps the catalog, the filters and the secure buttons of each client.
-- Shared byte for byte between the Retail and Forever workspaces.
-- Art: tools/photoshop/Build-TeleportAtlas.ps1 (TeleportAtlas.psd).
-- ============================================================================

local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")

local Atlas = {}
KT.TeleportAtlas = Atlas

local TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\TeleportMenu\\atlas_"
local ROUND_MASK = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
Atlas.TEX = TEX

local function Mix(a, b, p) return a + (b - a) * p end

-- Map colours. The tones of the map (base, vignette, lines, border, secondary
-- text, idle rings) come from the Visual Style accent, refreshed by
-- UpdateTones; names and the ready / cooldown dots stay fixed so the state
-- reads the same with any accent.
local C = {
    accent   = { 1, 0.55, 0.1 },
    base     = { 0, 0, 0 },
    vignette = { 0, 0, 0 },
    line     = { 0, 0, 0 },
    border   = { 0, 0, 0 },
    muted    = { 0, 0, 0 },
    dim      = { 0, 0, 0 },
    idle     = { 0, 0, 0 },
    text     = { 0.94, 0.94, 0.93 },
    ready    = { 0.35, 0.82, 0.51 },
    cooldown = { 0.90, 0.67, 0.24 },
    off      = { 0.40, 0.42, 0.44 },
}
Atlas.COLORS = C

local function SetTone(key, r, g, b)
    local t = C[key]
    t[1], t[2], t[3] = r, g, b
end

local function Accent()
    local palette = KT.GetStylePalette and KT:GetStylePalette()
    local accent = palette and palette.accent
    if accent then return accent.r, accent.g, accent.b end
    return KT.C_R or 1, KT.C_G or 0.55, KT.C_B or 0.1
end

-- r, g, b: the accent (read from the Visual Style when omitted).
local function UpdateTones(r, g, b)
    if not r then r, g, b = Accent() end
    SetTone("accent", r, g, b)
    SetTone("base", r * 0.085, g * 0.085, b * 0.085)
    SetTone("vignette", r * 0.25, g * 0.25, b * 0.25)
    SetTone("line", Mix(r, 1, 0.45), Mix(g, 1, 0.45), Mix(b, 1, 0.45))
    SetTone("border", Mix(r, 1, 0.25) * 0.7, Mix(g, 1, 0.25) * 0.7, Mix(b, 1, 0.25) * 0.7)
    SetTone("muted", Mix(r, 1, 0.5) * 0.78, Mix(g, 1, 0.5) * 0.78, Mix(b, 1, 0.5) * 0.78)
    SetTone("dim", Mix(r, 1, 0.5) * 0.56, Mix(g, 1, 0.5) * 0.56, Mix(b, 1, 0.5) * 0.56)
    SetTone("idle", Mix(r, 0.5, 0.65) * 0.75, Mix(g, 0.5, 0.65) * 0.75, Mix(b, 0.5, 0.65) * 0.75)
    return r, g, b
end
UpdateTones()

local HEADER_H   = 56
local TAB_TOP    = 60
local TAB_H      = 28
local TAB_GAP    = 14
local DIVIDER_Y  = 92
local CONTENT_Y  = 104
local FOOTER_H   = 34
local SIDE       = 18
local PIN_SCALE  = 1.5   -- the ring textures cover 1.5x the icon diameter
local NAME_WIDTH = 146

local function Texture(parent, layer, sublevel, file)
    local tex = parent:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(TEX .. file .. ".tga")
    return tex
end

-- Nine-slice keeps the radius at any size; a plain square where the client
-- cannot slice.
local function Sliced(parent, layer, sublevel, file, margin)
    local tex = Texture(parent, layer, sublevel, file)
    local sliced = tex.SetTextureSliceMargins
        and pcall(tex.SetTextureSliceMargins, tex, margin, margin, margin, margin)
    if sliced and tex.SetTextureSliceMode then
        pcall(tex.SetTextureSliceMode, tex, 0)
    elseif not sliced then
        tex:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    return tex
end

local function Round(parent, tex)
    if not parent.CreateMaskTexture then return end
    local mask = parent:CreateMaskTexture()
    if not mask then return end
    mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
    return mask
end

local function Rule(parent)
    local tex = parent:CreateTexture(nil, "BORDER")
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetHeight(1)
    return tex
end

-- ── Window ────────────────────────────────────────────────────────────────────
-- opts: categories, title, hint, label(cat) -> text, setIcon(texture, cat),
-- onSelect(cat), onSettings(), settingsTip.
function Atlas:BuildWindow(f, opts)
    local a = {}
    f.atlas = a
    f._atlasOpts = opts
    if f.SetBackdrop then f:SetBackdrop(nil) end

    a.fill = Sliced(f, "BACKGROUND", -8, "window", 10)
    a.fill:SetAllPoints()
    a.vignette = Texture(f, "BACKGROUND", -7, "vignette")
    a.vignette:SetAllPoints()
    a.grid = Texture(f, "BACKGROUND", -6, "grid")
    a.grid:SetPoint("TOPLEFT", 6, -6)
    a.grid:SetPoint("BOTTOMRIGHT", -6, 6)
    a.grid:SetTexture(TEX .. "grid.tga", "REPEAT", "REPEAT")
    a.grid:SetHorizTile(true)
    a.grid:SetVertTile(true)
    a.contours = Texture(f, "BACKGROUND", -5, "contours")
    a.contours:SetSize(460, 460)
    a.contours:SetPoint("CENTER", f, "BOTTOMRIGHT", -250, 200)
    a.edge = Sliced(f, "BORDER", 0, "windowedge", 10)
    a.edge:SetAllPoints()
    a.edgeInner = Sliced(f, "BORDER", 0, "windowedge", 10)
    a.edgeInner:SetPoint("TOPLEFT", 3, -3)
    a.edgeInner:SetPoint("BOTTOMRIGHT", -3, 3)

    -- Header: compass emblem, title, subtitle.
    a.emblemRing = Texture(f, "ARTWORK", 0, "emblemring")
    a.emblemRing:SetSize(30, 30)
    a.emblemRing:SetPoint("CENTER", f, "TOPLEFT", 34, -30)
    a.emblem = Texture(f, "ARTWORK", 1, "emblem")
    a.emblem:SetSize(30, 30)
    a.emblem:SetPoint("CENTER", a.emblemRing, "CENTER")

    local title = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT, 15, "")
    title:SetShadowOffset(1, -1)
    title:SetPoint("LEFT", f, "TOPLEFT", 58, -22)
    title:SetText(string.upper(opts.title or ""))
    title:SetTextColor(C.text[1], C.text[2], C.text[3])
    f.title = title
    local subtitle = f:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(FONT, 10, "")
    subtitle:SetShadowOffset(1, -1)
    subtitle:SetPoint("LEFT", f, "TOPLEFT", 58, -41)
    f.subtitle = subtitle

    -- Close and settings.
    local close = CreateFrame("Button", nil, f)
    close:SetSize(26, 26)
    close:SetPoint("TOPRIGHT", -16, -16)
    close.ring = Texture(close, "ARTWORK", 0, "ring")
    close.ring:SetPoint("CENTER")
    close.ring:SetSize(36, 36)
    close.glyph = Texture(close, "ARTWORK", 1, "close")
    close.glyph:SetAllPoints()
    local function CloseState(hover)
        local r, g, b = C.line[1], C.line[2], C.line[3]
        close.ring:SetVertexColor(r, g, b, hover and 0.85 or 0.45)
        local glyph = C.line
        close.glyph:SetVertexColor(hover and 1 or glyph[1], hover and 1 or glyph[2], hover and 1 or glyph[3], 1)
    end
    close:SetScript("OnEnter", function() CloseState(true) end)
    close:SetScript("OnLeave", function() CloseState(false) end)
    close:SetScript("OnClick", function() f:Hide() end)
    close.Paint = CloseState
    f.closeBtn = close

    local gear = CreateFrame("Button", nil, f)
    gear:SetSize(22, 22)
    gear:SetPoint("RIGHT", close, "LEFT", -8, 0)
    gear.icon = gear:CreateTexture(nil, "ARTWORK")
    gear.icon:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\ConfigOptionsIcons\\Engranaje.png")
    gear.icon:SetPoint("CENTER")
    gear.icon:SetSize(17, 17)
    gear:SetScript("OnClick", function() if opts.onSettings then opts.onSettings() end end)
    gear:SetScript("OnEnter", function(s)
        s.icon:SetVertexColor(1, 1, 1, 1)
        GameTooltip:SetOwner(s, "ANCHOR_LEFT")
        GameTooltip:AddLine(opts.settingsTip or "", 1, 1, 1)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function(s)
        s.icon:SetVertexColor(C.muted[1], C.muted[2], C.muted[3], 1)
        GameTooltip:Hide()
    end)
    f.gearBtn = gear
    f.gearIcon = gear.icon

    -- Tabs.
    f.tabs = {}
    for _, cat in ipairs(opts.categories or {}) do
        local tab = CreateFrame("Button", nil, f)
        tab:SetHeight(TAB_H)
        tab.category = cat
        tab.icon = tab:CreateTexture(nil, "ARTWORK")
        tab.icon:SetSize(18, 18)
        tab.icon:SetPoint("LEFT", 0, 0)
        if opts.setIcon then opts.setIcon(tab.icon, cat) end
        Round(tab, tab.icon)
        tab.text = tab:CreateFontString(nil, "OVERLAY")
        tab.text:SetFont(FONT, 10, "")
        tab.text:SetShadowOffset(1, -1)
        tab.text:SetPoint("LEFT", tab.icon, "RIGHT", 5, 0)
        tab.text:SetWordWrap(false)
        tab.text:SetText(opts.label and opts.label(cat) or cat)
        tab.underline = tab:CreateTexture(nil, "ARTWORK", nil, 1)
        tab.underline:SetHeight(2)
        tab.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", -2, -3)
        tab.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 2, -3)
        tab.underline:SetColorTexture(1, 1, 1, 1)
        tab:SetScript("OnClick", function() if opts.onSelect then opts.onSelect(cat) end end)
        tab:SetScript("OnEnter", function(s)
            if s._atlasState ~= "active" then Atlas:SetTabState(s, "hover") end
            if s._atlasCompact then
                GameTooltip:SetOwner(s, "ANCHOR_BOTTOM")
                GameTooltip:AddLine(s.text:GetText() or "", 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        tab:SetScript("OnLeave", function(s)
            if s._atlasState ~= "active" then Atlas:SetTabState(s, "inactive") end
            GameTooltip:Hide()
        end)
        tinsert(f.tabs, tab)
        Atlas:SetTabState(tab, "inactive")
    end

    a.dividerTop = Rule(f)
    a.dividerTop:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -DIVIDER_Y)
    a.dividerTop:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -DIVIDER_Y)
    a.dividerBottom = Rule(f)
    a.dividerBottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 16, FOOTER_H)
    a.dividerBottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, FOOTER_H)
    a.dividerBottom:SetAlpha(0.6)

    -- Content and footer.
    local contentOuter = CreateFrame("Frame", nil, f)
    contentOuter:SetPoint("TOPLEFT", f, "TOPLEFT", SIDE, -CONTENT_Y)
    contentOuter:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -SIDE + 6, FOOTER_H + 8)
    f.contentOuter = contentOuter

    local scroll = CreateFrame("ScrollFrame", f:GetName() and (f:GetName() .. "Scroll") or nil, contentOuter, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", contentOuter, "TOPLEFT", 0, 0)
    scroll:SetPoint("BOTTOMRIGHT", contentOuter, "BOTTOMRIGHT", -20, 0)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    f.scroll, f.content = scroll, content

    local count = f:CreateFontString(nil, "OVERLAY")
    count:SetFont(FONT, 10, "")
    count:SetShadowOffset(1, -1)
    count:SetPoint("LEFT", f, "BOTTOMLEFT", 20, FOOTER_H / 2)
    f.countLabel = count
    local hint = f:CreateFontString(nil, "OVERLAY")
    hint:SetFont(FONT, 10, "")
    hint:SetShadowOffset(1, -1)
    hint:SetPoint("RIGHT", f, "BOTTOMRIGHT", -20, FOOTER_H / 2)
    hint:SetText(opts.hint or "")
    f.hintLabel = hint

    f:HookScript("OnSizeChanged", function() Atlas:LayoutTabs(f) end)
    Atlas:LayoutTabs(f)
    return f
end

-- Tabs run left to right with their natural width. When they do not fit,
-- the gaps shrink, and then only the active tab keeps its name (the others
-- show it as a tooltip).
function Atlas:LayoutTabs(f)
    local tabs = f.tabs
    if not tabs or #tabs == 0 then return end
    local available = (f:GetWidth() or 720) - SIDE * 2 - 60
    local function Natural(tab, compact)
        if compact then return 18 end
        return 23 + (tab.text:GetStringWidth() or 40)
    end
    local function Total(gap, compactInactive)
        local sum = 0
        for _, tab in ipairs(tabs) do
            sum = sum + Natural(tab, compactInactive and tab._atlasState ~= "active") + gap
        end
        return sum - gap
    end
    local gap, compact = TAB_GAP, false
    if Total(gap, false) > available then gap = 8 end
    if Total(gap, false) > available then compact = true end
    local x = SIDE
    for _, tab in ipairs(tabs) do
        local isCompact = compact and tab._atlasState ~= "active"
        tab._atlasCompact = isCompact or nil
        tab.text:SetShown(not isCompact)
        tab:SetWidth(Natural(tab, isCompact))
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", f, "TOPLEFT", x, -TAB_TOP)
        x = x + tab:GetWidth() + gap
    end
    f._atlasCompactTabs = compact or nil
end

function Atlas:SetTabState(tab, state, r, g, b)
    if not tab then return end
    r, g, b = UpdateTones(r, g, b)
    local was = tab._atlasState
    tab._atlasState = state
    if state == "active" then
        tab.text:SetTextColor(0.96, 0.96, 0.94)
        tab.icon:SetVertexColor(1, 1, 1, 1)
        tab.underline:SetVertexColor(r, g, b, 1)
        tab.underline:Show()
    else
        local hover = state == "hover"
        local tone = hover and C.line or C.muted
        tab.text:SetTextColor(tone[1], tone[2], tone[3])
        tab.icon:SetVertexColor(hover and 1 or 0.85, hover and 1 or 0.85, hover and 1 or 0.85, 1)
        tab.underline:SetShown(hover)
        tab.underline:SetVertexColor(C.line[1], C.line[2], C.line[3], 0.45)
    end
    -- In compact mode the active tab is the only one with a name.
    local f = tab:GetParent()
    if f and f._atlasCompactTabs and (was == "active") ~= (state == "active") then
        Atlas:LayoutTabs(f)
    end
end

-- bg: the user's background colour, used flat when it is not the default.
-- border: {r, g, b, a} for a custom border, or nil for the map border.
function Atlas:Paint(f, r, g, b, bg, border)
    local a = f.atlas
    if not a then return end
    r, g, b = UpdateTones(r, g, b)
    local custom = bg and (math.abs((bg.r or 0) - 0.07) > 0.02 or math.abs((bg.g or 0) - 0.07) > 0.02
        or math.abs((bg.b or 0) - 0.07) > 0.02)
    local alpha = bg and bg.a or 0.97
    if custom then
        a.fill:SetVertexColor(bg.r, bg.g, bg.b, alpha)
        a.vignette:Hide()
    else
        a.fill:SetVertexColor(C.base[1], C.base[2], C.base[3], alpha)
        a.vignette:SetVertexColor(C.vignette[1], C.vignette[2], C.vignette[3], alpha)
        a.vignette:Show()
    end
    if border then
        a.edge:SetVertexColor(border[1], border[2], border[3], border[4] or 1)
        a.edgeInner:SetVertexColor(border[1], border[2], border[3], 0.25)
    else
        a.edge:SetVertexColor(C.border[1], C.border[2], C.border[3], 0.47)
        a.edgeInner:SetVertexColor(C.border[1], C.border[2], C.border[3], 0.14)
    end
    a.emblem:SetVertexColor(r, g, b, 0.95)
    local line, muted, dim = C.line, C.muted, C.dim
    a.grid:SetVertexColor(line[1], line[2], line[3], 0.09)
    a.contours:SetVertexColor(line[1], line[2], line[3], 0.13)
    a.emblemRing:SetVertexColor(line[1], line[2], line[3], 0.35)
    a.dividerTop:SetColorTexture(line[1], line[2], line[3], 0.27)
    a.dividerBottom:SetColorTexture(line[1], line[2], line[3], 0.27)
    f.subtitle:SetTextColor(muted[1], muted[2], muted[3])
    f.countLabel:SetTextColor(muted[1], muted[2], muted[3])
    f.hintLabel:SetTextColor(dim[1], dim[2], dim[3])
    f.gearIcon:SetVertexColor(muted[1], muted[2], muted[3], 1)
    f.closeBtn.Paint(false)
    for _, tab in ipairs(f.tabs or {}) do
        self:SetTabState(tab, tab._atlasState or "inactive", r, g, b)
    end
end

function Atlas:SetHeader(f, categoryText, total)
    if not f.subtitle then return end
    local L = KT.GetLocale and KT:GetLocale()
    local fmt = (L and L["%d destinations"]) or "%d destinations"
    f.subtitle:SetText((categoryText or "") .. "  ·  " .. string.format(fmt, total or 0))
end

-- ── Waypoints ─────────────────────────────────────────────────────────────────
function Atlas:CellSize(iconSize, showLabels)
    local pin = math.floor(iconSize * PIN_SCALE + 0.5)
    if not showLabels then return pin + 8, pin + 8 end
    return pin + 8 + NAME_WIDTH, pin + 6
end

-- Builds the regions of a waypoint on `btn` (a secure or plain Button): it
-- sets btn.icon, btn.dimmer, btn.cooldown and btn.nameLabel, the names
-- TeleportMenu.lua already uses.
function Atlas:CreatePin(btn)
    btn.hoverFill = Sliced(btn, "BACKGROUND", 0, "row", 8)
    btn.hoverFill:SetAllPoints()
    btn.hoverEdge = Sliced(btn, "BORDER", 0, "rowedge", 8)
    btn.hoverEdge:SetAllPoints()
    btn.hoverFill:Hide()
    btn.hoverEdge:Hide()

    btn.glow = Texture(btn, "BACKGROUND", 1, "glow")
    btn.glow:Hide()
    btn.icon = btn:CreateTexture(nil, "ARTWORK", nil, 0)
    btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    btn.dimmer = btn:CreateTexture(nil, "ARTWORK", nil, 1)
    btn.dimmer:SetColorTexture(0, 0, 0, 0.45)
    btn.dimmer:SetAllPoints(btn.icon)
    btn.dimmer:Hide()
    local mask = Round(btn, btn.icon)
    if mask then btn.dimmer:AddMaskTexture(mask) end
    btn.ring = Texture(btn, "ARTWORK", 2, "ring")
    btn.ringDash = Texture(btn, "ARTWORK", 2, "ringdash")

    btn.cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    btn.cooldown:SetAllPoints(btn.ring)
    if btn.cooldown.SetSwipeTexture then btn.cooldown:SetSwipeTexture(TEX .. "ring.tga") end
    if btn.cooldown.SetDrawEdge then btn.cooldown:SetDrawEdge(false) end
    if btn.cooldown.SetDrawBling then btn.cooldown:SetDrawBling(false) end

    btn.nameLabel = btn:CreateFontString(nil, "OVERLAY")
    btn.nameLabel:SetJustifyH("LEFT")
    btn.nameLabel:SetJustifyV("BOTTOM")
    btn.nameLabel:SetWordWrap(true)
    if btn.nameLabel.SetMaxLines then btn.nameLabel:SetMaxLines(2) end
    btn.nameLabel:SetSpacing(1)
    btn.statusDot = Texture(btn, "OVERLAY", 0, "dot")
    btn.statusDot:SetSize(6, 6)
    btn.statusLabel = btn:CreateFontString(nil, "OVERLAY")
    btn.statusLabel:SetJustifyH("LEFT")
    btn.statusLabel:SetWordWrap(false)
end

function Atlas:LayoutPin(btn, iconSize, cellW, cellH, showLabels)
    local pin = math.floor(iconSize * PIN_SCALE + 0.5)
    local cx = 4 + pin / 2
    btn._atlasIconSize = iconSize
    btn.ring:ClearAllPoints()
    btn.ring:SetPoint("CENTER", btn, "LEFT", cx, 0)
    btn.ring:SetSize(pin, pin)
    btn.ringDash:ClearAllPoints()
    btn.ringDash:SetAllPoints(btn.ring)
    btn.icon:ClearAllPoints()
    btn.icon:SetPoint("CENTER", btn.ring, "CENTER")
    btn.icon:SetSize(iconSize, iconSize)
    btn.glow:ClearAllPoints()
    btn.glow:SetPoint("CENTER", btn.ring, "CENTER")
    btn.glow:SetSize(pin * 1.35, pin * 1.35)

    local textX = 4 + pin + 6
    btn.nameLabel:ClearAllPoints()
    btn.nameLabel:SetPoint("BOTTOMLEFT", btn, "LEFT", textX, 1)
    btn.nameLabel:SetWidth(cellW - textX - 6)
    btn.nameLabel:SetHeight(cellH / 2)
    btn.statusDot:ClearAllPoints()
    btn.statusDot:SetPoint("LEFT", btn, "LEFT", textX, -9)
    btn.statusLabel:ClearAllPoints()
    btn.statusLabel:SetPoint("LEFT", btn.statusDot, "RIGHT", 4, 0)
    btn.statusLabel:SetPoint("RIGHT", btn, "RIGHT", -6, 0)
    btn.nameLabel:SetShown(showLabels)
    btn.statusDot:SetShown(showLabels)
    btn.statusLabel:SetShown(showLabels)
end

local function L(text)
    local loc = KT.GetLocale and KT:GetLocale()
    return (loc and loc[text]) or text
end

local KIND_LABELS = { spell = "Spell", item = "Item", toy = "Toy", housing = "House" }

-- itemType: the entry type, shown (localized) before the state.
function Atlas:SetPinKind(btn, itemType)
    local font, size, outline = btn.nameLabel:GetFont()
    btn.statusLabel:SetFont(font or FONT, math.max(8, (size or 12) - 2), outline or "")
    btn._atlasKind = KIND_LABELS[itemType] and L(KIND_LABELS[itemType]) or nil
    self:RefreshPinStatus(btn)
end

function Atlas:RefreshPinStatus(btn)
    local state = btn._atlasState or "ready"
    local word = (state == "cooldown" and L("Cooldown")) or (state == "unavailable" and (btn._atlasOffText or ""))
        or L("Ready")
    local kind = btn._atlasKind
    btn.statusLabel:SetText((kind and kind ~= "") and (kind .. "  ·  " .. word) or word)
end

-- state: "ready", "cooldown" or "unavailable" (listed but not usable yet;
-- offText names why). Cooldown keeps "unavailable" when the pin has it.
function Atlas:SetPinState(btn, state, offText)
    local r, g, b = UpdateTones()
    local line = C.line
    btn.hoverFill:SetVertexColor(line[1], line[2], line[3], 0.055)
    btn.hoverEdge:SetVertexColor(line[1], line[2], line[3], 0.16)
    btn.ringDash:SetVertexColor(line[1], line[2], line[3], 0.27)
    btn._atlasState = state
    if offText then btn._atlasOffText = offText end
    local dot
    if state == "ready" then
        btn.ring:SetVertexColor(r, g, b, 1)
        btn.icon:SetDesaturated(false)
        btn.icon:SetVertexColor(1, 1, 1, 1)
        dot = C.ready
    elseif state == "cooldown" then
        btn.ring:SetVertexColor(C.idle[1], C.idle[2], C.idle[3], 1)
        btn.icon:SetDesaturated(true)
        btn.icon:SetVertexColor(0.85, 0.85, 0.85, 1)
        dot = C.cooldown
    else
        btn.ring:SetVertexColor(C.idle[1], C.idle[2], C.idle[3], 0.8)
        btn.icon:SetDesaturated(true)
        btn.icon:SetVertexColor(0.55, 0.55, 0.55, 1)
        dot = C.off
    end
    if btn.cooldown.SetSwipeColor then btn.cooldown:SetSwipeColor(r, g, b, 1) end
    btn.glow:SetVertexColor(r, g, b, 0.55)
    btn.statusDot:SetVertexColor(dot[1], dot[2], dot[3], 1)
    btn.statusLabel:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    self:SetPinHover(btn, btn._atlasHover)
    self:RefreshPinStatus(btn)
end

-- Cooldowns only change ready pins; an unavailable pin stays as it is.
function Atlas:SetPinCooldown(btn, active)
    btn.dimmer:SetShown(active)
    if btn._atlasState == "unavailable" then return end
    local state = active and "cooldown" or "ready"
    if btn._atlasState ~= state then self:SetPinState(btn, state) end
end

function Atlas:SetPinHover(btn, hover)
    btn._atlasHover = hover or nil
    btn.hoverFill:SetShown(hover and true or false)
    btn.hoverEdge:SetShown(hover and true or false)
    btn.glow:SetShown((hover and btn._atlasState ~= "unavailable") and true or false)
    local r, g, b = C.accent[1], C.accent[2], C.accent[3]
    if btn._atlasState == "unavailable" then
        btn.nameLabel:SetTextColor(0.62, 0.62, 0.62)
    elseif hover then
        btn.nameLabel:SetTextColor(Mix(1, r, 0.35), Mix(1, g, 0.35), Mix(1, b, 0.35))
    else
        btn.nameLabel:SetTextColor(C.text[1], C.text[2], C.text[3])
    end
end

function Atlas:StyleGroupHeader(header)
    UpdateTones()
    header.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3], 1)
    header.line:SetColorTexture(C.line[1], C.line[2], C.line[3], 0.25)
end
