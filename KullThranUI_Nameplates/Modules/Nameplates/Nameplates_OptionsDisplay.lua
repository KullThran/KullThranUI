-- Nameplates options, Display page: bars, health markers, cast rows, class resource,
-- combo point cards, general text, and the scroll-and-glow navigation of the preview's hit targets.
-- One text for both clients. Nothing runs at load; Setup resolves references, Build makes the widgets.

local _, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)

local Display = {}
ns.OptionsDisplay = Display

-- Resolved once by Setup
local P, PP, defaults, plates, BAR_W, SetLiveFont, LiveOutline

-- Opener of the most recent build's spell icon popup, shared by all builds
local latestSpellIconOpener

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE_MASK = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_mask.tga"
local CIRCLE_RING = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\circle_border.tga"

---------------------------------------------------------------------------
-- Saved value readers and writers
---------------------------------------------------------------------------
local function LT(text) return P.LText(text) end
local function Saved(k) return P.DBVal(k) end

local function SavedOr(k) return P.DBVal(k) or defaults[k] end

local function Stored(k)
    local db = P.DB()
    if db then return db[k] end
end

-- Stored value when not nil, otherwise the default
local function StoredOrDefault(k)
    local v = Stored(k)
    if v ~= nil then return v end
    return defaults[k]
end

-- Stored value when truthy, otherwise the default; a stored 0 stays 0
local function LiveRead(k)
    local db = P.DB()
    return (db and db[k]) or defaults[k]
end

local function Store(k, v)
    local db = P.DB()
    if db then db[k] = v end
end

local function StoreRGB(k, r, g, b) Store(k, { r = r, g = g, b = b }) end

local function SavedRGB(k)
    local c = P.DBRaw(k)
    return c.r, c.g, c.b
end

---------------------------------------------------------------------------
-- Running-offset widget helpers. b is the state of one Build.
---------------------------------------------------------------------------
local function Header(b, text)
    local frame, height = b.W:SectionHeader(b.parent, text, b.y)
    b.y = b.y - height
    return frame
end

local function Row(b, left, right)
    local row, height = b.W:DualRow(b.parent, b.y, left, right)
    b.y = b.y - height
    return row
end

local function Spacer(b)
    local _, height = b.W:Spacer(b.parent, b.y, 20)
    b.y = b.y - height
end

-- 26 by 26 cog button with its tinted icon; the tint needs the path set first
local function MakeCog(region, iconPath)
    local button = CreateFrame("Button", nil, region)
    button:SetSize(26, 26)
    button:SetFrameLevel(region:GetFrameLevel() + 5)
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints()
    icon:SetTexture(iconPath)
    P.ApplyAccentToIcon(icon)
    return button
end

---------------------------------------------------------------------------
-- Bars
---------------------------------------------------------------------------
local function ApplyClickArea()
    if ns.ApplyNamePlateClickArea then ns.ApplyNamePlateClickArea() end
end

local function BuildBars(b)
    b.barsHeader = Header(b, "SIZE")
    b.widthRow = Row(b, {
        type = "slider", text = LT("Health Bar Width"), min = BAR_W, max = BAR_W + 100, step = 1,
        getValue = function() return BAR_W + Saved("healthBarWidth") end,
        setValue = function(v)
            Store("healthBarWidth", v - BAR_W)
            for _, plate in pairs(plates) do
                PP.Width(plate.health, v)
                PP.Width(plate.absorb, v)
                PP.Width(plate.cast, v)
                plate:UpdateNameWidth()
            end
            ApplyClickArea()
            b.update()
        end,
    }, {
        type = "slider", text = LT("Health Bar Height"), min = 6, max = 45, step = 1,
        getValue = function() return Saved("healthBarHeight") end,
        setValue = function(v)
            Store("healthBarHeight", v)
            for _, plate in pairs(plates) do PP.Height(plate.health, v) end
            ApplyClickArea()
            b.update()
        end,
    })
end

---------------------------------------------------------------------------
-- Health markers
---------------------------------------------------------------------------
local function MarkersOff()
    local cfg = P.MarkerCfg()
    return not cfg or cfg.enabled ~= true
end

local function DimMarkerSwatch(swatch)
    local off = MarkersOff()
    swatch:SetAlpha(off and 0.15 or 1)
    swatch:EnableMouse(not off)
end

local function MarkerSlotSlider(b, i, text)
    return {
        type = "slider", text = text, min = 0, max = 100, step = 1,
        disabled = MarkersOff, disabledTooltip = LT("Enable Custom Health Markers"),
        getValue = function() return P.MarkerSlot(P.MarkerCfg(), i) end,
        setValue = function(v)
            P.SetMarkerSlot(P.MarkerCfg(), i, v)
            P.RefreshAllPlates()
            b.update()
        end,
    }
end

local function BuildMarkerSwatch(b, region)
    local swatch, repaint = P.BuildColorSwatch(region, region:GetFrameLevel() + 5, function()
        local cfg = P.MarkerCfg()
        if not cfg then return 1, 1, 1 end
        return cfg.colorR or 1, cfg.colorG or 1, cfg.colorB or 1
    end, function(r, g, bl)
        local cfg = P.MarkerCfg()
        if not cfg then return end
        cfg.colorR, cfg.colorG, cfg.colorB = r, g, bl
        P.RebuildMarkerValues(cfg)
        P.RefreshAllPlates()
        b.update()
    end, nil, 20)
    PP.Point(swatch, "RIGHT", region._control, "LEFT", -12, 0)
    DimMarkerSwatch(swatch)
    P.RegisterWidgetRefresh(function()
        DimMarkerSwatch(swatch)
        repaint()
    end)
end

local function BuildMarkers(b)
    Header(b, "HEALTH MARKERS")
    Row(b, {
        type = "toggle", text = LT("Enable Custom Health Markers"),
        getValue = function()
            local cfg = P.MarkerCfg()
            return cfg ~= nil and cfg.enabled == true
        end,
        setValue = function(v)
            local cfg = P.MarkerCfg()
            if cfg then
                cfg.enabled = v
                P.RebuildMarkerValues(cfg)
            end
            P.RefreshAllPlates()
            b.update()
            KT:RefreshPage()
        end,
    }, {
        type = "toggle", text = LT("Show on All Nameplates"),
        getValue = function()
            local state = P.MarkerState()
            return state ~= nil and state.showOn == "all"
        end,
        setValue = function(v)
            local state = P.MarkerState()
            if state then state.showOn = v and "all" or "target" end
            P.RefreshAllPlates()
            b.update()
        end,
    })
    Row(b, {
        type = "toggle", text = LT("Per-Spec Marker Profile"),
        getValue = function()
            local state = P.MarkerState()
            return ((state and state.mode) or "spec") == "spec"
        end,
        setValue = function(v)
            local state = P.MarkerState()
            if state then state.mode = v and "spec" or "character" end
            P.RefreshAllPlates()
            b.update()
            KT:RefreshPage()
        end,
    }, {
        type = "slider", text = LT("Marker Width"), min = 1, max = 6, step = 1,
        disabled = MarkersOff, disabledTooltip = LT("Enable Custom Health Markers"),
        getValue = function()
            local cfg = P.MarkerCfg()
            return (cfg and cfg.width) or 2
        end,
        setValue = function(v)
            local cfg = P.MarkerCfg()
            if cfg then
                cfg.width = v
                P.RebuildMarkerValues(cfg)
            end
            P.RefreshAllPlates()
            b.update()
        end,
    })
    Row(b, MarkerSlotSlider(b, 1, LT("Marker 1")), MarkerSlotSlider(b, 2, LT("Marker 2")))
    local last = Row(b, MarkerSlotSlider(b, 3, LT("Marker 3")), { type = "label", text = LT("Markers use % health (0 = off).") })
    BuildMarkerSwatch(b, last._leftRegion)
end

---------------------------------------------------------------------------
-- Cast row and spell icon popup
---------------------------------------------------------------------------
local function IconOff()
    local db = P.DB()
    return db ~= nil and db.showCastIcon == false
end

local function SpellCogAlpha() return IconOff() and 0.15 or 0.4 end

local function ApplyCastHeight(v)
    local barW = ns.GetHealthBarWidth()
    for _, plate in pairs(plates) do
        PP.Size(plate.cast, barW, v)
        plate.cast:ClearAllPoints()
        PP.Point(plate.cast, "TOPLEFT", plate.health, "BOTTOMLEFT", 0, 0)

        local iconFrame = plate.castIconFrame
        PP.Size(iconFrame, v, v)
        iconFrame:ClearAllPoints()
        local x, y = SavedOr("castIconXOffset"), SavedOr("castIconYOffset")
        if SavedOr("castIconSide") == "right" then
            PP.Point(iconFrame, "TOPLEFT", plate.cast, "TOPRIGHT", x, y)
        else
            PP.Point(iconFrame, "TOPRIGHT", plate.cast, "TOPLEFT", x, y)
        end

        plate.castSpark:SetHeight(v)
    end
end

local function BuildCastRow(b)
    b.castHeader = Header(b, "CAST BAR")
    b.castRow = Row(b, {
        type = "slider", text = LT("Cast Bar Height"), min = 10, max = 30, step = 1,
        getValue = function() return SavedOr("castBarHeight") end,
        setValue = function(v)
            Store("castBarHeight", v)
            ApplyCastHeight(v)
            b.update()
        end,
    }, {
        type = "toggle", text = LT("Spell Icon"),
        getValue = function() return StoredOrDefault("showCastIcon") end,
        setValue = function(v)
            Store("showCastIcon", v)
            ns.RefreshAllSettings()
            b.update()
            KT:RefreshPage()
        end,
    })
end

-- One popup row writing one saved key
local function SpellPopupRow(b, row, key)
    row.get = function() return SavedOr(key) end
    row.set = function(v)
        Store(key, v)
        if ns.RefreshAllSettings then ns.RefreshAllSettings() end
        b.update()
    end
    return row
end

local function BuildSpellPopup(b)
    local _, show = P.QuietCogPopup({
        title = "Spell Icon Settings",
        rows = {
            SpellPopupRow(b, { type = "slider", label = "Scale", min = 0.5, max = 2, step = 0.1 }, "castIconScale"),
            SpellPopupRow(b, { type = "dropdown", label = "Side", values = {
                { value = "left", label = "Left" },
                { value = "right", label = "Right" },
            } }, "castIconSide"),
            SpellPopupRow(b, { type = "slider", label = "X Offset", min = -30, max = 30, step = 1 }, "castIconXOffset"),
            SpellPopupRow(b, { type = "slider", label = "Y Offset", min = -20, max = 20, step = 1 }, "castIconYOffset"),
        },
    })

    local region = b.castRow._rightRegion
    local cog = MakeCog(region, KT.RESIZE_ICON)
    b.S.AttachInlineWidget(region, cog)
    cog:SetAlpha(SpellCogAlpha())
    cog:SetScript("OnEnter", function(self)
        if IconOff() then
            P.ShowTooltip(self, P.DisabledTooltip("Spell Icon"))
        else
            self:SetAlpha(0.7)
        end
    end)
    cog:SetScript("OnLeave", function(self)
        P.HideTooltip()
        self:SetAlpha(SpellCogAlpha())
    end)
    cog:SetScript("OnClick", function(self)
        if not IconOff() then show(self) end
    end)
    P.RegisterWidgetRefresh(function() cog:SetAlpha(SpellCogAlpha()) end)

    latestSpellIconOpener = function(anchor) show(anchor or cog) end
end

---------------------------------------------------------------------------
-- Class resource
---------------------------------------------------------------------------
local function ClassOff() return Saved("showClassPower") ~= true end

local function WithClassPair(descriptor)
    descriptor.disabled = ClassOff
    descriptor.disabledTooltip = LT("Show Class Resource")
    return descriptor
end

local function BuildPositionCog(b, region)
    local cog = MakeCog(region, KT.KUI_NavArrowGlyph)
    b.S.AttachInlineWidget(region, cog)
    cog:SetAlpha(ClassOff() and 0.15 or 0.4)

    local opts = {
        title = "Position Settings",
        xGet = function() return SavedOr("classPowerXOffset") end,
        xSet = function(v)
            Store("classPowerXOffset", v)
            b.resourceRefresh()
        end,
        yGet = function() return SavedOr("classPowerYOffset") end,
        ySet = function(v)
            Store("classPowerYOffset", v)
            b.resourceRefresh()
        end,
    }

    cog:SetScript("OnEnter", function(self)
        if ClassOff() then
            P.ShowTooltip(self, P.DisabledTooltip("Show Class Resource"))
        else
            self:SetAlpha(0.7)
        end
    end)
    cog:SetScript("OnLeave", function(self)
        P.HideTooltip()
        if b.S.PopupOwner() ~= self then self:SetAlpha(ClassOff() and 0.15 or 0.4) end
    end)
    cog:SetScript("OnClick", function(self)
        if not ClassOff() then b.S.ShowCogPopup(self, opts) end
    end)
    P.RegisterWidgetRefresh(function()
        if ClassOff() then
            cog:SetAlpha(0.15)
        elseif b.S.PopupOwner() == cog then
            cog:SetAlpha(0.7)
        else
            cog:SetAlpha(0.4)
        end
    end)
end

local function ResourceSlider(b, text, min, max, step, key)
    return WithClassPair({
        type = "slider", text = LT(text), min = min, max = max, step = step,
        getValue = function() return SavedOr(key) end,
        setValue = function(v)
            Store(key, v)
            b.resourceRefresh()
        end,
    })
end

local function BuildClassRows(b)
    b.classHeader = Header(b, "CLASS RESOURCE")
    b.classTop = b.y
    Row(b, {
        type = "toggle", text = LT("Show Class Resource"),
        getValue = function() return Saved("showClassPower") == true end,
        setValue = function(v)
            Store("showClassPower", v)
            ns.ApplyClassPowerSetting()
            b.update()
            KT:RefreshPage()
        end,
    }, WithClassPair({
        type = "multiSwatch", text = LT("Fill Color"),
        swatches = P.ClassTintSwatches({
            flag = "classPowerClassColors",
            tintedTip = LT("Resource Color"),
            tintedColor = function()
                if ns.PlayerClassPowerColor then return ns.PlayerClassPowerColor() end
            end,
            isTinted = function() return Saved("classPowerClassColors") end,
            customGet = function() return SavedRGB("classPowerCustomColor") end,
            customSet = function(r, g, bl) StoreRGB("classPowerCustomColor", r, g, bl) end,
            apply = b.resourceRefresh,
            extra = { disabled = ClassOff, disabledTooltip = LT("Show Class Resource") },
        }),
    }))
    local positionRow = Row(b, WithClassPair({
        type = "dropdown", text = LT("Position"),
        values = { top = "Top", bottom = "Bottom" }, order = { "top", "bottom" },
        getValue = function() return SavedOr("classPowerPos") end,
        setValue = function(v)
            Store("classPowerPos", v)
            b.resourceRefresh()
        end,
    }), ResourceSlider(b, "Size", 0.5, 3.0, 0.1, "classPowerScale"))
    BuildPositionCog(b, positionRow._leftRegion)
    Row(b, ResourceSlider(b, "Bar Spacing", 0, 10, 1, "classPowerGap"), WithClassPair({
        type = "colorpicker", text = LT("Background Color"), hasAlpha = true,
        getValue = function()
            local c = P.DBRaw("classPowerBgColor")
            return c.r, c.g, c.b, c.a
        end,
        setValue = function(r, g, bl, a)
            Store("classPowerBgColor", { r = r, g = g, b = bl, a = a })
            b.resourceRefresh()
        end,
    }))
end

---------------------------------------------------------------------------
-- Combo point shape cards
---------------------------------------------------------------------------
-- Sample points: the class's own piece, or circles with a ring and flat bars
local function BuildCardArt(card, w, h, round, art)
    local count = art and art.piece.pips or 5
    local gap = art and 3 or 6
    if art and round then w, h = 18 * art.piece.aspect, 18 end
    if art then
        local fit = (132 - (count - 1) * gap) / count
        if w > fit then w, h = fit, h * fit / w end
    end
    local total = count * w + (count - 1) * gap
    for i = 1, count do
        local tex = card:CreateTexture(nil, "ARTWORK")
        tex:SetSize(w, h)
        tex:SetPoint("TOPLEFT", card, "TOPLEFT", (140 - total) / 2 + (i - 1) * (w + gap), -14 - (16 - h) / 2)
        if art and not round then
            local dim = i <= 3 and 1 or 0.25
            tex:SetColorTexture(art.r * dim, art.g * dim, art.b * dim, 1)
        elseif art then
            ns.PaintClassPowerArt(tex, art.piece, i, i <= 3, art.r, art.g, art.b, false)
        elseif i <= 3 then
            tex:SetColorTexture(1, 0.05, 0.05, 1)
        else
            tex:SetColorTexture(0.22, 0.02, 0.02, 1)
        end
        if round and not art then
            local mask = card:CreateMaskTexture()
            mask:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            mask:SetAllPoints(tex)
            tex:AddMaskTexture(mask)
            local ring = card:CreateTexture(nil, "OVERLAY")
            ring:SetAllPoints(tex)
            ring:SetTexture(CIRCLE_RING)
            ring:SetVertexColor(1, 0.82, 0.08, 1)
        end
    end
end

-- Sample combo points with a shape's own art (ns.NameplatesClassPower.COMBO_ART): 3 of 5 lit.
local function BuildComboArtCard(card, kind)
    local cp = ns.NameplatesClassPower
    local a = cp and cp.COMBO_ART and cp.COMBO_ART[kind]
    if not a then return BuildCardArt(card, 16, 16, true, nil) end
    local size, gap = 18, 6
    local total = 5 * size + 4 * gap
    local function Crop(tex, c)
        tex:SetTexture(a.file)
        tex:SetTexCoord(c[1] / a.w, c[3] / a.w, c[2] / a.h, c[4] / a.h)
    end
    for i = 1, 5 do
        local socket = card:CreateTexture(nil, "ARTWORK", nil, 0)
        socket:SetSize(size, size)
        socket:SetPoint("TOPLEFT", card, "TOPLEFT", (140 - total) / 2 + (i - 1) * (size + gap), -13)
        Crop(socket, i <= 3 and a.on or a.off)
        if i <= 3 then
            local gem = card:CreateTexture(nil, "ARTWORK", nil, 1)
            gem:SetSize(size * a.gemSize, size * a.gemSize)
            gem:SetPoint("CENTER", socket, "CENTER", 0, 0)
            Crop(gem, a.gem)
            if a.tinted then gem:SetVertexColor(1, 0.05, 0.05, 1) end
        end
    end
end

-- kind: "retail" / "forever" / "circle" (combo art), "piece" (the class's own piece) or "pip".
local function BuildCard(holder, index, themes, labelText, art, kind)
    local card = CreateFrame("Button", nil, holder, "BackdropTemplate")
    card:SetSize(140, 70)
    card:SetPoint("TOPLEFT", ((index - 1) % 2) * 148, -math.floor((index - 1) / 2) * 78)
    card:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    if kind == "pip" then
        BuildCardArt(card, art and 20 or 18, 7, false, art)
    elseif kind == "piece" then
        BuildCardArt(card, 18, 18, true, art)
    else
        BuildComboArtCard(card, kind)
    end
    -- The font goes on before the text: the client raises "Font not set" otherwise
    local label = card:CreateFontString(nil, "OVERLAY")
    label:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    label:SetPoint("BOTTOM", 0, 8)
    label:SetText(LT(labelText))
    if themes and themes.SkinGlowTile then themes:SkinGlowTile(card, label) end
    return card
end

local function BuildShapeCards(b)
    local art
    if ns.PlayerClassPowerArt then
        local piece, r, g, bl = ns.PlayerClassPowerArt()
        if piece then art = { piece = piece, r = r, g = g, b = bl } end
    end
    local _, labelHeight = b.W:Label(b.parent, art and "Resource Style" or "Combo Point Shape", b.y, 12)
    b.y = b.y - labelHeight

    -- Combo points: Retail and Forever points from the client, KUI Style's own, or pips.
    local defs = art and { { "circle", art.piece.label, "piece" }, { "pip", "Pips", "pip" } }
        or { { "retail", "Retail", "retail" }, { "forever", "Forever", "forever" },
             { "circle", "KUI", "circle" }, { "pip", "Pips", "pip" } }
    local rows = math.ceil(#defs / 2)

    -- A label row carries the cards, so the section's card grows around them.
    local slot = b.W:Label(b.parent, " ", b.y, 12)
    slot:SetHeight(rows * 78)
    local holder = CreateFrame("Frame", nil, slot)
    holder:SetPoint("TOP", slot, "TOP", 0, -2)
    holder:SetSize(288, rows * 78 - 8)

    local themes = KT.VisualThemes
    local cards = {}
    for index, def in ipairs(defs) do
        cards[def[1]] = BuildCard(holder, index, themes, def[2], art, def[3])
    end

    local function PaintCard(card, on, ar, ag, ab)
        if themes and themes.PaintGlowTile then
            themes:PaintGlowTile(card, { ar, ag, ab }, nil, on)
        elseif on then
            card:SetBackdropColor(ar * 0.25, ag * 0.25, ab * 0.25, 1)
            card:SetBackdropBorderColor(ar, ag, ab, 1)
        else
            card:SetBackdropColor(0.06, 0.06, 0.08, 1)
            card:SetBackdropBorderColor(0.22, 0.22, 0.26, 1)
        end
    end

    local function Paint()
        local shape = ns.GetClassPowerShape()
        -- A class piece has no Retail / Forever art: those shapes show it as the round piece.
        if art and shape ~= "pip" then shape = "circle" end
        local ar, ag, ab = P.AccentRGB()
        for key, card in pairs(cards) do PaintCard(card, shape == key, ar, ag, ab) end
    end

    local function ClickShape(key)
        if ClassOff() then return end
        Store("classPowerShape", key)
        b.resourceRefresh()
        Paint()
    end
    for key, card in pairs(cards) do
        card:SetScript("OnClick", function() ClickShape(key) end)
    end

    local function DimAndPaint()
        holder:SetAlpha(ClassOff() and 0.35 or 1)
        Paint()
    end
    DimAndPaint()
    P.RegisterWidgetRefresh(DimAndPaint)

    b.y = b.y - rows * 78
end

-- Invisible frame over the class resource section, used only as a glow target
local function BuildSectionFrame(b)
    local pad = KT.CONTENT_PAD or 20
    local top = b.classTop
    local frame = CreateFrame("Frame", nil, b.parent)
    frame:SetPoint("TOPLEFT", b.parent, "TOPLEFT", pad, top)
    frame:SetPoint("TOPRIGHT", b.parent, "TOPRIGHT", -pad, top)
    frame:SetHeight(math.abs(top - b.y))
    frame._isSpacer = true
    b.sectionFrame = frame
end

---------------------------------------------------------------------------
-- Live text refresh on the plates
---------------------------------------------------------------------------
local function StyleTimer(aura, position, style)
    local cd = aura and aura.cd
    local fs = cd and cd.text
    if not fs then return end
    if position == "none" then
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        return
    end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(false) end
    SetLiveFont(fs, style.size, "OUTLINE")
    fs:SetTextColor(style.color.r, style.color.g, style.color.b, 1)
    fs:ClearAllPoints()
    local x, y = style.x, style.y
    if position == "center" then
        fs:SetPoint("CENTER", aura, "CENTER", x, y)
        fs:SetJustifyH("CENTER")
    elseif position == "topright" then
        PP.Point(fs, "TOPRIGHT", aura, "TOPRIGHT", 3 + x, 4 + y)
        fs:SetJustifyH("RIGHT")
    else
        PP.Point(fs, "TOPLEFT", aura, "TOPLEFT", -3 + x, 4 + y)
        fs:SetJustifyH("LEFT")
    end
end

local function StyleStack(aura, baseX, baseY, style)
    local fs = aura and aura.count
    if not fs then return end
    SetLiveFont(fs, style.stackSize, "OUTLINE")
    fs:SetTextColor(style.stackColor.r, style.stackColor.g, style.stackColor.b, 1)
    fs:ClearAllPoints()
    PP.Point(fs, "BOTTOMRIGHT", aura, "BOTTOMRIGHT", baseX + style.stackX, baseY + style.stackY)
    fs:SetJustifyH("RIGHT")
end

local function FamilyPosition(key, base)
    return Stored(key) or base or defaults[key]
end

local function LiveAuraRefresh()
    local style = {
        size = LiveRead("auraDurationTextSize"),
        color = LiveRead("auraDurationTextColor"),
        stackSize = LiveRead("auraStackTextSize"),
        stackColor = LiveRead("auraStackTextColor"),
        x = LiveRead("auraDurationXOffset") or 0,
        y = LiveRead("auraDurationYOffset") or 0,
        stackX = LiveRead("auraStackXOffset") or 0,
        stackY = LiveRead("auraStackYOffset") or 0,
    }
    local base = Stored("auraTextPosition") or Stored("debuffTextPosition") or defaults.auraTextPosition
    local debuffPos = FamilyPosition("debuffTimerPosition", base)
    local buffPos = FamilyPosition("buffTimerPosition", base)
    local ccPos = FamilyPosition("ccTimerPosition", base)

    for _, plate in pairs(plates) do
        for i = 1, 4 do
            StyleTimer(plate.debuffs[i], debuffPos, style)
            StyleStack(plate.debuffs[i], 1, 1, style)
            StyleTimer(plate.buffs[i], buffPos, style)
            StyleStack(plate.buffs[i], 2, -2, style)
        end
        for i = 1, 2 do
            StyleTimer(plate.cc[i], ccPos, style)
        end
    end
end

local function LiveCastRefresh()
    local nameSize, targetSize = LiveRead("castNameSize"), LiveRead("castTargetSize")
    local nameColor, targetColor = LiveRead("castNameColor"), LiveRead("castTargetColor")
    local classColored = StoredOrDefault("castTargetClassColor")

    for _, plate in pairs(plates) do
        if plate.castName then
            SetLiveFont(plate.castName, nameSize, LiveOutline())
            plate.castName:SetTextColor(nameColor.r, nameColor.g, nameColor.b, 1)
        end
        if plate.castTarget then
            SetLiveFont(plate.castTarget, targetSize, LiveOutline())
            if not classColored then
                plate.castTarget:SetTextColor(targetColor.r, targetColor.g, targetColor.b, 1)
            end
        end
        if plate.ApplyCastTextAnchors then plate:ApplyCastTextAnchors() end
        if plate.isCasting or plate._interrupted then plate:UpdateCast() end
    end
end

---------------------------------------------------------------------------
-- General text
---------------------------------------------------------------------------
-- Cog opening the shared offset and size popup; refresh is one of the live refreshes above
local function BuildTextCog(b, region, title, xKey, yKey, sizeKey, sizeMax, refresh)
    local cog = MakeCog(region, KT.RESIZE_ICON)
    b.S.AttachInlineWidget(region, cog)
    cog:SetAlpha(0.4)

    local function Setter(key)
        return function(v)
            Store(key, v)
            refresh()
            b.update()
        end
    end
    local opts = {
        title = title,
        xGet = function() return SavedOr(xKey) or 0 end,
        xSet = Setter(xKey),
        yGet = function() return SavedOr(yKey) or 0 end,
        ySet = Setter(yKey),
        sizeGet = function() return SavedOr(sizeKey) end,
        sizeSet = Setter(sizeKey),
        sizeMin = 6,
        sizeMax = sizeMax,
        sizeLabel = "Size",
    }

    cog:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
    cog:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
    cog:SetScript("OnClick", function(self) b.S.ShowCogPopup(self, opts) end)
end

local function BuildDurationSwatch(b, region)
    local swatch, repaint = P.BuildColorSwatch(region, region:GetFrameLevel() + 5, function()
        return SavedRGB("auraDurationTextColor")
    end, function(r, g, bl)
        StoreRGB("auraDurationTextColor", r, g, bl)
        StoreRGB("debuffTimerColor", r, g, bl)
        Store("debuffTextWhite", nil)
        LiveAuraRefresh()
        b.update()
    end, nil, 20)
    P.RegisterWidgetRefresh(function() repaint() end)
    return swatch
end

local function BuildAuraRow(b)
    local S = b.S
    b.auraRow = Row(b, {
        type = "dropdown", text = LT("Aura Duration"), values = S.timerPosValues, order = S.timerPosOrder,
        getValue = function() return Saved("debuffTimerPosition") or S.timerFallback end,
        setValue = function(v)
            Store("debuffTimerPosition", v)
            Store("buffTimerPosition", v)
            Store("ccTimerPosition", v)
            Store("auraTextPosition", v)
            LiveAuraRefresh()
            b.update()
        end,
    }, {
        type = "colorpicker", text = LT("Aura Stacks"),
        getValue = function() return SavedRGB("auraStackTextColor") end,
        setValue = function(r, g, bl)
            StoreRGB("auraStackTextColor", r, g, bl)
            LiveAuraRefresh()
            b.update()
        end,
    })

    -- The swatch is made first and attached second, so the cog ends up rightmost
    local left, right = b.auraRow._leftRegion, b.auraRow._rightRegion
    local swatch = BuildDurationSwatch(b, left)
    BuildTextCog(b, left, "Aura Duration Settings", "auraDurationXOffset", "auraDurationYOffset",
        "auraDurationTextSize", 20, LiveAuraRefresh)
    S.AttachInlineWidget(left, swatch)
    BuildTextCog(b, right, "Aura Stacks Settings", "auraStackXOffset", "auraStackYOffset",
        "auraStackTextSize", 20, LiveAuraRefresh)
end

local function BuildSpellTextRow(b)
    b.spellRow = Row(b, {
        type = "colorpicker", text = LT("Spell Name"),
        getValue = function() return P.DBColor("castNameColor") end,
        setValue = function(r, g, bl)
            StoreRGB("castNameColor", r, g, bl)
            LiveCastRefresh()
            b.update()
        end,
    }, {
        type = "multiSwatch", text = LT("Spell Target"),
        swatches = P.ClassTintSwatches({
            flag = "castTargetClassColor",
            isTinted = function() return Saved("castTargetClassColor") end,
            -- Indexes the saved table with no guard, and falls to the default on a saved false
            clickTinted = function()
                local stored = P.DB().castTargetClassColor
                if stored then return stored end
                return defaults.castTargetClassColor
            end,
            customGet = function() return P.DBColor("castTargetColor") end,
            customSet = function(r, g, bl) StoreRGB("castTargetColor", r, g, bl) end,
            apply = function()
                LiveCastRefresh()
                b.update()
            end,
        }),
    })
    BuildTextCog(b, b.spellRow._leftRegion, "Spell Name Settings", "castNameXOffset", "castNameYOffset",
        "castNameSize", 16, LiveCastRefresh)
    BuildTextCog(b, b.spellRow._rightRegion, "Spell Target Settings", "castTargetXOffset", "castTargetYOffset",
        "castTargetSize", 16, LiveCastRefresh)
end

---------------------------------------------------------------------------
-- Navigation and glow
---------------------------------------------------------------------------
local CORE_ELEMENTS = {
    debuffIcon = "debuffs", buffIcon = "buffs", ccIcon = "ccs", raidMarker = "raidmarker", classIcon = "classification",
}
local CORE_POSITIONS = {
    top = { "coreRow1", "_leftRegion" },
    right = { "coreRow1", "_rightRegion" },
    left = { "coreRow2", "_leftRegion" },
    topright = { "coreRow2", "_rightRegion" },
    topleft = { "coreRow3", "_leftRegion" },
    bottom = { "coreRow3", "_rightRegion" },
}
local HEALTH_ELEMENTS = { "healthPercent", "healthPercentNoSign", "healthNumber", "healthPctNum", "healthNumPct" }
local TEXT_POSITIONS = {
    textSlotTop = { "textRow1", "_leftRegion" },
    textSlotRight = { "textRow1", "_rightRegion" },
    textSlotLeft = { "textRow2", "_leftRegion" },
    textSlotCenter = { "textRow2", "_rightRegion" },
}

local function CoreTarget(S, element)
    local place = CORE_POSITIONS[S.SlotOf(S.elementToKey[element])]
    if place then return S[place[1]][place[2]] end
    return S.coreRow1
end

local function HealthTextTarget(S)
    for _, element in ipairs(HEALTH_ELEMENTS) do
        for _, slotKey in ipairs(S.textSlotKeys) do
            if S.SlotOf(slotKey) == element then
                local place = TEXT_POSITIONS[slotKey]
                if place then return S[place[1]][place[2]] end
                return S.textRow1
            end
        end
    end
    return S.textRow1
end

-- Preview targets that live in the Slots sections built on this card.
local function RegisterSlotTargets(S)
    local register = ns.OptionsGroups.Register
    if S.coreHeader then
        for key, element in pairs(CORE_ELEMENTS) do
            register(key, S.coreHeader, function() return CoreTarget(S, element) end)
        end
    end
    if S.coreTextHeader then
        local function healthText() return HealthTextTarget(S) end
        register("healthText", S.coreTextHeader, healthText)
        register("healthNumber", S.coreTextHeader, healthText)
    end
    if S.styleHeader then
        register("targetArrows", S.styleHeader, (S.targetIndicatorRow or S.targetGlowRow)._leftRegion)
    end
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------
function Display.Setup(client)
    if client ~= "retail" and client ~= "forever" then
        error("OptionsDisplay.Setup: client must be \"retail\" or \"forever\"", 2)
    end
    P = ns.OptionsPreview
    PP = KT.PP
    defaults = ns.defaults or _G.KullThranUINameplatesDefaults or {}
    plates = ns.plates
    BAR_W = tonumber(ns.BAR_W) or 168
    SetLiveFont = ns.SetFSFont
    LiveOutline = ns.GetNPOutline or function() return "OUTLINE" end
end

function Display.Build(ctx)
    local want = ctx.sections
    local b = { parent = ctx.parent, y = ctx.y, W = ctx.W, S = ctx.slots, update = ctx.UpdatePreview }
    local register = ns.OptionsGroups.Register
    b.resourceRefresh = function()
        ns.RefreshClassPower()
        b.update()
    end

    if want.bars then
        BuildBars(b)
        register("healthBar", b.barsHeader, b.widthRow._leftRegion)
        Spacer(b)
    end
    if want.markers then
        BuildMarkers(b)
        Spacer(b)
    end
    if want.castRow then
        BuildCastRow(b)
        BuildSpellPopup(b)
        register("castBar", b.castHeader, b.castRow._leftRegion)
        register("castIcon", b.castHeader, nil, function() latestSpellIconOpener() end)
    end
    if want.castColors then
        b.y = P.BuildCastBarColorSection(b.parent, b.y, b.W, ctx.UpdatePreview)
        Spacer(b)
    end
    if want.class then
        BuildClassRows(b)
        BuildShapeCards(b)
        BuildSectionFrame(b)
        register("classResource", b.classHeader, b.sectionFrame)
        Spacer(b)
    end
    if want.auraText then
        local header = Header(b, "AURA TEXT")
        BuildAuraRow(b)
        register("auraDuration", header, b.auraRow._leftRegion)
        register("auraStack", header, b.auraRow._rightRegion)
        Spacer(b)
    end
    if want.spellText then
        local header = Header(b, "SPELL TEXT")
        BuildSpellTextRow(b)
        register("castName", header, b.spellRow._leftRegion)
        register("castTarget", header, b.spellRow._rightRegion)
        Spacer(b)
    end
    if want.slotTargets then RegisterSlotTargets(ctx.slots) end
    return { y = b.y }
end
