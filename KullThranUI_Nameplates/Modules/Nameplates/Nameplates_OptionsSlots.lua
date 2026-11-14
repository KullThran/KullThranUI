-- Nameplates options, Display page: Nameplate Level, Style, Core Positions and Core Text Positions,
-- the shared X / Y / Size / Grow cog popup, and the inline placement rule for widgets inside rows.
-- One text for both clients; the client is only what Setup receives.

local _, ns = ...
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
local LSM = LibStub("LibSharedMedia-3.0", true)

local max, min = math.max, math.min
local format = string.format

local Slots = {}
ns.OptionsSlots = Slots

-- Resolved by Setup.
local P, defaults, plates, client

-- The refreshes of the latest Build. Callbacks of older builds reach these too.
local currentEyeRefresh, currentCogRefresh

local NO_ITEMS = {}
local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local FALLBACK_COG_ICON = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\ConfigOptionsIcons\\Engranaje.png"
local EYE_ON = "Interface\\RaidFrame\\ReadyCheck-Ready"
local EYE_OFF = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local COG_OFF_TIP = "This option requires an aura or indicator to be assigned"
local TEXT_OFF_TIP = "This option requires a text to be assigned"
local OVERLAP_TIP = "Disabled when Enemy Name is centered on the health bar due to overlapping text"

-- Saved position keys in lookup order, with the element each one holds.
local POSITION_KEYS = { "debuffSlot", "buffSlot", "ccSlot", "raidMarkerPos", "classificationSlot" }
local ELEMENT_OF_KEY = {
    debuffSlot = "debuffs", buffSlot = "buffs", ccSlot = "ccs",
    raidMarkerPos = "raidmarker", classificationSlot = "classification",
}
local ELEMENT_TO_KEY = {
    debuffs = "debuffSlot", buffs = "buffSlot", ccs = "ccSlot",
    raidmarker = "raidMarkerPos", classification = "classificationSlot",
}
local ELEMENT_VALUES = {
    debuffs = "Debuffs", buffs = "Buffs", ccs = "CCs", raidmarker = "Raid Marker",
    classification = "Elite/Rare Indicator", none = "None",
}
local ELEMENT_ORDER = { "debuffs", "buffs", "ccs", "raidmarker", "classification", "none" }
local GROW_VALUES = {
    topleft = { { value = "left", label = "Left" }, { value = "right", label = "Right" }, { value = "up", label = "Up" } },
    topright = { { value = "right", label = "Right" }, { value = "left", label = "Left" }, { value = "up", label = "Up" } },
}

local TEXT_VALUES = {
    enemyName = "Enemy Name", healthPercent = "Health %", healthPercentNoSign = "Health % (No Sign)",
    healthNumber = "Health #", healthPctNum = "Health % | #", healthNumPct = "Health # | %", none = "None",
}
local TEXT_ORDER = { "none", "---", "enemyName", "healthPercent", "healthPercentNoSign", "healthNumber", "healthPctNum", "healthNumPct" }

local TIMER_VALUES = { topleft = "Top Left", center = "Center", topright = "Top Right", none = "None" }
local TIMER_ORDER = { "topleft", "center", "topright", "none" }

local OUTLINE_VALUES = {
    NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline",
    MONOCHROME = "Monochrome", OUTLINEMONOCHROME = "Monochrome Outline",
}
local OUTLINE_ORDER = { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "OUTLINEMONOCHROME" }

local GLOW_VALUES = { kullthranui = "KT", vibrant = "Vibrant", none = "None" }
local GLOW_ORDER = { "kullthranui", "vibrant", "none" }
local BORDER_VALUES = { kullthranui = "KT", simple = "Simple", none = "None" }
local BORDER_ORDER = { "kullthranui", "simple", "none" }

----------------------------------------------------------------------- Small helpers

local function L(text) return P.LText(text) end

local function SavedOr(key) return P.DBVal(key) or defaults[key] end

local function Store(key, value) P.DB()[key] = value end

-- Stored value when not nil, otherwise whether the default is exactly true.
local function StoredOrDefaultTrue(key)
    local stored = P.DB()[key]
    if stored ~= nil then return stored end
    return defaults[key] == true
end

local function SlotOf(key)
    local stored = P.DB()[key]
    if stored then return stored end
    return defaults[key]
end

local function AccentPaint(tex, alpha)
    if KT.SetAccentTexture then
        KT:SetAccentTexture(tex, alpha)
    else
        local accent = P.Accent
        tex:SetColorTexture(accent.r, accent.g, accent.b, alpha)
    end
end

local function RGBOf(key)
    local c = P.DBRaw(key)
    return c.r, c.g, c.b
end

local function StoreRGB(key, r, g, b) Store(key, { r = r, g = g, b = b }) end

local function HideAuras(frames, count)
    for i = 1, count do frames[i]:Hide() end
end

-- Off state of a swatch: dimmed and not clickable.
local function DimSwatch(swatch, off, offAlpha)
    swatch:SetAlpha(off and offAlpha or 1)
    swatch:EnableMouse(not off)
end

-- A cog's resting alpha.
local function CogAlpha(off, owner)
    if off then return 0.15 end
    if owner then return 0.7 end
    return 0.4
end

----------------------------------------------------------------------- Core positions

local function ElementAt(position)
    for _, key in ipairs(POSITION_KEYS) do
        if SlotOf(key) == position then return ELEMENT_OF_KEY[key] end
    end
    return "none"
end

-- Parks whoever holds the position, then writes the element's own key. Nothing is swapped.
local function PlaceElement(element, position)
    local ownKey = ELEMENT_TO_KEY[element]
    if element ~= "none" and not ownKey then return end
    for _, key in ipairs(POSITION_KEYS) do
        if key ~= ownKey and SlotOf(key) == position then Store(key, "none") end
    end
    if ownKey then Store(ownKey, position) end
end

local function SlotRefresh(page)
    P.RefreshAllAuras()
    for _, plate in pairs(plates) do
        local ds, bs, cs = ns.GetAuraSlots()
        local spacing = ns.GetAuraSpacing()
        if bs ~= "none" then
            local s = ns.GetBuffIconSize()
            local x, y = ns.GetSlotOffsets(bs)
            ns.PositionAuraSlot(plate.buffs, 4, bs, plate, s, s, spacing, x, y)
        else
            HideAuras(plate.buffs, 4)
        end
        if cs ~= "none" then
            local s = ns.GetCCIconSize()
            local x, y = ns.GetSlotOffsets(cs)
            ns.PositionAuraSlot(plate.cc, 2, cs, plate, s, s, spacing, x, y)
        else
            HideAuras(plate.cc, 2)
        end
        if ds == "none" then HideAuras(plate.debuffs, 4) end
        plate:UpdateRaidIcon()
        plate:UpdateClassification()
    end
    page.UpdatePreview()
    if currentEyeRefresh then currentEyeRefresh() end
    if currentCogRefresh then currentCogRefresh() end
end

-- The offset keys follow the element, looked at on every read and write.
local function OffsetKey(position, axis)
    if ElementAt(position) == "classification" then return "classification" .. axis .. "Offset" end
    return position .. "Slot" .. axis .. "Offset"
end

----------------------------------------------------------------------- Other refreshes

local function IndicatorRefresh(page)
    for _, plate in pairs(plates) do
        if ns.RefreshTargetIndicatorTextures then ns.RefreshTargetIndicatorTextures(plate) end
        plate:ApplyTarget()
        if plate.UpdateAuras then plate:UpdateAuras() end
    end
    for _, plate in pairs(ns.friendlyPlates or NO_ITEMS) do
        if ns.RefreshTargetIndicatorTextures then ns.RefreshTargetIndicatorTextures(plate) end
        if plate.ApplyTarget then plate:ApplyTarget() end
    end
    page.UpdatePreview()
end

local function TextRefresh(page)
    for _, plate in pairs(plates) do
        plate:RefreshNamePosition()
        plate:UpdateHealthValues()
    end
    page.UpdatePreview()
end

local function LevelRefresh(page)
    for _, plate in pairs(plates) do
        if plate.RefreshNamePosition then
            plate:RefreshNamePosition()
        elseif plate.UpdateLevel then
            plate:UpdateLevel()
        end
        if plate.UpdateClassification then plate:UpdateClassification() end
        if plate.UpdateRaidIcon then plate:UpdateRaidIcon() end
    end
    if ns.RefreshFriendlyPlayerLevels then ns.RefreshFriendlyPlayerLevels() end
    page.UpdatePreview()
end

----------------------------------------------------------------------- Inline widgets

-- Lays out one region: first in the list is rightmost, hidden widgets are skipped.
local function LayoutRegion(page, region)
    local x, reserved = -12, 0
    for _, widget in ipairs(page.inlineLists[region] or NO_ITEMS) do
        if widget:IsShown() then
            widget:ClearAllPoints()
            widget:SetPoint("RIGHT", region, "RIGHT", x, 0)
            local step = widget:GetWidth() + 8
            x = x - step
            reserved = reserved + step
        end
    end
    local control = region._control
    if not control then return end
    if control.SetReservedRightSpace then
        control:SetReservedRightSpace(reserved + 12)
    elseif control.SetWidth then
        control:SetWidth(max(120, region:GetWidth() - 20 - reserved - 12))
    end
end

local function DetachInlineWidget(page, widget)
    local region = page.inlineHome[widget]
    if not region then return end
    local list = page.inlineLists[region]
    for i, entry in ipairs(list) do
        if entry == widget then
            table.remove(list, i)
            break
        end
    end
    page.inlineHome[widget] = nil
    LayoutRegion(page, region)
end

local function AttachInlineWidget(page, region, widget)
    if not region or not widget then return end
    if page.inlineHome[widget] ~= region then
        DetachInlineWidget(page, widget)
        local list = page.inlineLists[region]
        if not list then
            list = {}
            page.inlineLists[region] = list
        end
        list[#list + 1] = widget
        page.inlineHome[widget] = region
    end
    LayoutRegion(page, region)
end

----------------------------------------------------------------------- Cog popup

local function PaintGrowButton(button, selected)
    if selected then
        button.bg:SetColorTexture(0.973, 0.839, 0.604, 0.25)
        button.label:SetTextColor(1, 1, 1)
    else
        button.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)
        button.label:SetTextColor(0.7, 0.7, 0.7)
    end
end

local function MakeCaption(frame, text, rowY)
    local caption = KT.MakeFont(frame, 12, nil, 1, 1, 1)
    caption:SetAlpha(0.6)
    caption:SetText(text)
    caption:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, rowY)
    return caption
end

-- A slider fires its setter from any SetValue, and the core pushes a first value as it builds one.
-- Showing a value is not a change, so while pop.showing is set nothing reaches a writer.
local function ShowValue(pop, slider, value)
    pop.showing = true
    slider:SetValue(value)
    pop.showing = false
end

-- X or Y row. The slider reads and writes through whatever the popup holds right now.
local function MakeOffsetRow(pop, caption, rowY, readerField, writerField)
    local frame = pop.frame
    MakeCaption(frame, caption, rowY)
    local slider, box = KT.BuildSliderCore(frame, pop.sliderW, 4, 12, 34, 24, 11, KT.NP_SL_INPUT_A, -80, 80, 1,
        function()
            local reader = pop[readerField]
            if reader then return reader() or 0 end
            return 0
        end,
        function(value)
            local writer = pop[writerField]
            if writer and not pop.showing then writer(value) end
        end,
        true)
    slider:SetPoint("TOPLEFT", frame, "TOPLEFT", pop.sliderLeft, rowY - 2)
    box:ClearAllPoints()
    box:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, rowY)
    return slider
end

local function MakeGrowButton(pop, index, fontPath)
    local button = CreateFrame("Button", nil, pop.frame)
    button:SetSize(52, 20)
    button:SetPoint("TOPLEFT", pop.frame, "TOPLEFT", pop.sliderLeft + (index - 1) * 56, -148)

    button.bg = button:CreateTexture(nil, "BACKGROUND")
    button.bg:SetAllPoints(button)
    button.bg:SetColorTexture(0.15, 0.15, 0.15, 0.8)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button)
    highlight:SetColorTexture(1, 1, 1, 0.06)

    button.label = button:CreateFontString(nil, "OVERLAY")
    button.label:SetFont(fontPath, 11, P.OptOutline())
    button.label:SetAllPoints(button)
    button.label:SetJustifyH("CENTER")
    button.label:SetJustifyV("MIDDLE")

    button:SetScript("OnClick", function()
        if pop.growWrite then pop.growWrite(pop.growValue[index]) end
        local selected = pop.growRead and pop.growRead() or ""
        for i, other in ipairs(pop.growButtons) do
            PaintGrowButton(other, pop.growValue[i] == selected)
        end
    end)
    return button
end

-- Measures the raw caption words and fixes the popup's columns and width.
local function MeasureColumns(pop, fontPath)
    local probe = pop.frame:CreateFontString(nil, "OVERLAY")
    probe:SetFont(fontPath, 12, P.OptOutline())
    local widest = 0
    for _, word in ipairs({ "X", "Y", "Size" }) do
        probe:SetText(word)
        widest = max(widest, probe:GetStringWidth())
    end
    probe:Hide()
    if widest < 10 then widest = 28 end
    pop.sliderLeft = 14 + widest + 12
    pop.sliderW = max(80, 260 - pop.sliderLeft - 8 - 34 - 14)
    return max(180, pop.sliderLeft + pop.sliderW + 8 + 34 + 14)
end

-- The two stages of the popup's only OnUpdate.
local function MakePopupUpdates(pop)
    local function clickOutside(self)
        local down = IsMouseButtonDown("LeftButton")
        local pressed = down and not pop.wasDown
        pop.wasDown = down
        if pressed and not self:IsMouseOver() and (pop.owner == nil or not pop.owner:IsMouseOver()) then
            self:Hide()
        end
    end
    local function fade(self, dt)
        pop.fadeClock = pop.fadeClock + dt
        local t = min(pop.fadeClock / 0.15, 1)
        self:SetAlpha(t)
        self:ClearAllPoints()
        self:SetPoint("BOTTOM", pop.fadeAnchor, "TOP", 0, 6 - 8 * (1 - t))
        if t >= 1 then self:SetScript("OnUpdate", clickOutside) end
    end
    return fade
end

local function BuildPopup(pop)
    local menu = KT.MenuPrincipal
    local frame = CreateFrame("Frame", nil, menu or UIParent)
    pop.frame = frame
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetFrameLevel(max(1200, (menu and menu:GetFrameLevel() or 0) + 80))
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()

    local bg = KT.SolidTex(frame, "BACKGROUND", 0.06, 0.08, 0.10, 0.95)
    bg:SetAllPoints(frame)
    local edge = KT.NP_BORDER_COLOR
    KT.MakeBorder(frame, edge.r, edge.g, edge.b, 0.15)

    pop.title = KT.MakeFont(frame, 11, "", 1, 1, 1)
    pop.title:SetAlpha(0.7)
    pop.title:SetPoint("TOP", frame, "TOP", 0, -14)

    local fontPath = KT.FONT_PATH or DEFAULT_FONT
    frame:SetSize(MeasureColumns(pop, fontPath), 151)

    pop.xSlider = MakeOffsetRow(pop, "X", -45, "xRead", "xWrite")
    pop.ySlider = MakeOffsetRow(pop, "Y", -79, "yRead", "yWrite")
    pop.sizeCaption = MakeCaption(frame, L("Size"), -113)
    pop.growCaption = MakeCaption(frame, L("Grow"), -147)

    pop.growButtons, pop.growValue = {}, {}
    for i = 1, 3 do pop.growButtons[i] = MakeGrowButton(pop, i, fontPath) end

    pop.fadeUpdate = MakePopupUpdates(pop)

    frame:SetScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        local old = pop.owner
        pop.owner = nil
        if old then old:SetAlpha(0.4) end
        if currentCogRefresh then currentCogRefresh() end
        if old and old._updateHighlight then old._updateHighlight() end
    end)

    if menu then
        menu:HookScript("OnHide", function()
            if frame:IsShown() then frame:Hide() end
        end)
    end
end

-- Size row. A range change rebuilds the slider, which reads from the new owner and writes to nobody.
local function ApplySizeRow(pop, opts)
    if not opts.sizeGet then
        pop.sizeCaption:Hide()
        if pop.sizeSlider then
            pop.sizeSlider:Hide()
            pop.sizeBox:Hide()
        end
        return
    end
    local step = opts.sizeStep or 1
    pop.sizeRead, pop.sizeWrite = opts.sizeGet, opts.sizeSet
    if not pop.sizeSlider or pop.sizeMin ~= opts.sizeMin or pop.sizeMax ~= opts.sizeMax or pop.sizeStep ~= step then
        if pop.sizeSlider then
            pop.sizeSlider:Hide()
            pop.sizeSlider:SetParent(nil)
            pop.sizeBox:Hide()
            pop.sizeBox:SetParent(nil)
        end
        local frame = pop.frame
        pop.showing = true
        pop.sizeSlider, pop.sizeBox = P.BuildSliderCore(frame, pop.sliderW, 4, 12, 34, 24, 11, KT.NP_SL_INPUT_A,
            opts.sizeMin, opts.sizeMax, step,
            function()
                if pop.sizeRead then return pop.sizeRead() or 0 end
                return 0
            end,
            function(value)
                if pop.sizeWrite and not pop.showing then pop.sizeWrite(value) end
            end,
            true)
        pop.showing = false
        pop.sizeMin, pop.sizeMax, pop.sizeStep = opts.sizeMin, opts.sizeMax, step
        pop.sizeSlider:ClearAllPoints()
        pop.sizeSlider:SetPoint("TOPLEFT", frame, "TOPLEFT", pop.sliderLeft, -115)
        pop.sizeBox:ClearAllPoints()
        pop.sizeBox:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -113)
    end
    ShowValue(pop, pop.sizeSlider, opts.sizeGet() or opts.sizeMin or 0)
    pop.sizeCaption:SetText(L(opts.sizeLabel or "Size"))
    pop.sizeCaption:Show()
    pop.sizeSlider:Show()
    pop.sizeBox:Show()
end

local function ApplyGrowRow(pop, opts)
    pop.growRead, pop.growWrite = opts.growthGet, opts.growthSet
    if not opts.growthGet then
        pop.growCaption:Hide()
        for _, button in ipairs(pop.growButtons) do button:Hide() end
        return
    end
    local selected = opts.growthGet()
    local entries = opts.growthValues or NO_ITEMS
    for i, button in ipairs(pop.growButtons) do
        local entry = entries[i]
        if entry then
            pop.growValue[i] = entry.value
            button.label:SetText(L(entry.label))
            PaintGrowButton(button, entry.value == selected)
            button:Show()
        else
            button:Hide()
        end
    end
    pop.growCaption:Show()
end

local function ShowCogPopup(pop, anchor, opts)
    if not pop.frame then BuildPopup(pop) end
    local frame = pop.frame

    if pop.owner == anchor and frame:IsShown() then
        frame:Hide()
        return
    end

    pop.xRead, pop.xWrite = opts.xGet, opts.xSet
    pop.yRead, pop.yWrite = opts.yGet, opts.ySet
    pop.title:SetText(L(opts.title))
    ShowValue(pop, pop.xSlider, opts.xGet() or 0)
    ShowValue(pop, pop.ySlider, opts.yGet() or 0)

    pop.owner = anchor
    if currentCogRefresh then currentCogRefresh() end
    if anchor._updateHighlight then anchor._updateHighlight() end

    ApplySizeRow(pop, opts)
    ApplyGrowRow(pop, opts)

    frame:SetHeight(117 + (opts.sizeGet and 34 or 0) + (opts.growthGet and 32 or 0))
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
    frame:SetAlpha(0)
    frame:Show()

    pop.fadeClock, pop.fadeAnchor = 0, anchor
    frame:SetScript("OnUpdate", pop.fadeUpdate)
end

----------------------------------------------------------------------- Page building blocks

local function AddHeader(page, text)
    local frame, height = page.W:SectionHeader(page.parent, text, page.y)
    page.y = page.y - height
    return frame
end

local function AddRow(page, left, right)
    local row, height = page.W:DualRow(page.parent, page.y, left, right)
    page.y = page.y - height
    return row
end

local function AddSpacer(page)
    local _, height = page.W:Spacer(page.parent, page.y, 20)
    page.y = page.y - height
end

-- Places the subtitle beside the header's font string, which holds the text upper-cased and localised.
local function AddSubtitle(header, englishHeader, text)
    local shown = L(englishHeader):upper()
    local regions = { header:GetRegions() }
    for _, region in ipairs(regions) do
        if region:IsObjectType("FontString") and region:GetText() == shown then
            local subtitle = header:CreateFontString(nil, "OVERLAY")
            subtitle:SetFont(region:GetFont())
            subtitle:SetTextColor(1, 1, 1, 0.25)
            subtitle:SetText(L(text))
            subtitle:SetPoint("LEFT", region, "RIGHT", 6, 0)
            return
        end
    end
end

-- A swatch built on the region and attached straight away.
local function AddSwatch(page, region, get, set)
    local swatch, repaint = P.BuildColorSwatch(region, region:GetFrameLevel() + 5, get, set, nil, 20)
    page.Attach(region, swatch)
    return swatch, repaint
end

-- A show/hide eye. The tint comes before the path, so the helper does not resize the icon.
local function MakeEye(parent, level, flag, onClick)
    local eye = CreateFrame("Button", nil, parent)
    eye:SetSize(26, 26)
    eye:SetFrameLevel(level)
    eye:SetAlpha(0.4)
    local icon = eye:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(eye)
    P.ApplyAccentToIcon(icon)
    icon:SetTexture(P.flags[flag] and EYE_ON or EYE_OFF)
    eye:SetScript("OnClick", function()
        P.flags[flag] = not P.flags[flag]
        icon:SetTexture(P.flags[flag] and EYE_ON or EYE_OFF)
        onClick()
    end)
    return eye
end

-- A cog button. The path comes before the tint, so the helper centres and sizes the icon.
local function MakeCogButton(region)
    local button = CreateFrame("Button", nil, region)
    button:SetSize(26, 26)
    button:SetFrameLevel(region:GetFrameLevel() + 5)
    button:SetAlpha(0.4)
    local icon = button:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(button)
    icon:SetTexture(KT.RESIZE_ICON or FALLBACK_COG_ICON)
    P.ApplyAccentToIcon(icon)
    return button
end

local function CoverButton(tex, button)
    tex:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
end

local function MakePulse(tex, fromAlpha)
    local group = tex:CreateAnimationGroup()
    group:SetLooping("BOUNCE")
    local alpha = group:CreateAnimation("Alpha")
    alpha:SetFromAlpha(fromAlpha)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.7)
    return group
end

-- Shows and plays the pulse only while its cog is on.
local function UpdatePulse(tex, group, off, alpha)
    if off then
        tex:Hide()
        if group:IsPlaying() then group:Stop() end
    else
        AccentPaint(tex, alpha)
        tex:Show()
        if not group:IsPlaying() then group:Play() end
    end
end

----------------------------------------------------------------------- Level section

local function LevelFontList()
    local values, order = {}, {}
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            values[name] = name
            order[#order + 1] = name
        end
    end
    local saved = SavedOr("levelFont")
    if saved and not values[saved] then
        values[saved] = saved
        order[#order + 1] = saved
    end
    return values, order
end

local function BuildLevelSection(page)
    local function refresh() LevelRefresh(page) end
    local function writer(key)
        return function(value)
            Store(key, value)
            refresh()
        end
    end
    local function coercedWriter(key)
        return function(value)
            Store(key, value and true or false)
            refresh()
        end
    end
    local function numberReader(key, fallback)
        return function() return tonumber(P.DBVal(key)) or fallback end
    end
    local function notFalse(key)
        return function() return P.DBVal(key) ~= false end
    end
    local fontValues, fontOrder = LevelFontList()

    AddHeader(page, "NAMEPLATE LEVEL")
    AddRow(page,
        { type = "toggle", text = L("Show Level"), getValue = notFalse("showLevel"), setValue = coercedWriter("showLevel") },
        { type = "dropdown", text = L("Level Font"), values = fontValues, order = fontOrder,
          getValue = function() return SavedOr("levelFont") end, setValue = writer("levelFont") })
    AddRow(page,
        { type = "toggle", text = L("Dynamic Level Layout"),
          getValue = function() return P.DBVal("useDynamicNameplateLevelLayout") == true end,
          setValue = coercedWriter("useDynamicNameplateLevelLayout") },
        { type = "toggle", text = L("Color Enemy Level by Difficulty"),
          tooltip = L("Colors the level of enemies by their level compared to yours, in every Visual Style: grey is far below you, then green, yellow, orange and red."),
          getValue = notFalse("levelTextDifficultyColor"), setValue = coercedWriter("levelTextDifficultyColor") })
    AddRow(page,
        { type = "slider", text = L("Level Font Size"), min = 6, max = 48, step = 1,
          getValue = numberReader("levelFontSize", 11), setValue = writer("levelFontSize") },
        { type = "dropdown", text = L("Level Text Outline"), values = OUTLINE_VALUES, order = OUTLINE_ORDER,
          getValue = function() return P.DBVal("levelFontOutline") or "OUTLINE" end, setValue = writer("levelFontOutline") })
    AddRow(page,
        { type = "toggle", text = L("Level Text Shadow"), getValue = notFalse("levelShadow"), setValue = coercedWriter("levelShadow") },
        { type = "colorpicker", text = L("Level Text Color"),
          getValue = function()
              local c = SavedOr("levelColor")
              return c.r or 1, c.g or 1, c.b or 1
          end,
          setValue = function(r, g, b)
              Store("levelColor", { r = r, g = g, b = b, a = 1 })
              refresh()
          end })
    AddRow(page,
        { type = "slider", text = L("Level X Offset"), min = -200, max = 200, step = 1,
          getValue = numberReader("levelXOffset", 24), setValue = writer("levelXOffset") },
        { type = "slider", text = L("Level Y Offset"), min = -100, max = 200, step = 1,
          getValue = numberReader("levelYOffset", 4), setValue = writer("levelYOffset") })

    local _, height = page.W:Label(page.parent, L("Default: level above the nameplate on the left; Elite/Rare at the top right."),
        page.y, 10, { r = 0.75, g = 0.75, b = 0.78 })
    page.y = page.y - height
    AddSpacer(page)
end

----------------------------------------------------------------------- Style section

local function IndicatorStyleList()
    local styles = ns.targetIndicatorStyles
    local order = ns.targetIndicatorOrder or { "arrows" }
    local values, any = {}, false
    for _, key in ipairs(order) do
        local style = styles and styles[key]
        if style and style.label then
            values[key] = style.label
            any = true
        end
    end
    if not any then return { arrows = "Arrows" }, { "arrows" } end
    return values, order
end

local function ResolveIndicatorPreview(key)
    if ns.GetTargetIndicatorPreviewTexture then return ns.GetTargetIndicatorPreviewTexture(key) end
    local style = ns.targetIndicatorStyles and ns.targetIndicatorStyles[key]
    if style then return style.preview or style.right or style.texture or style.left end
end

local function ReadGlowColor()
    local c = P.DBRaw("targetGlowColor")
    if not c then return 0.4117, 0.6667, 1.0 end
    return c.r or c[1], c.g or c[2], c.b or c[3]
end

local function ApplyTargetOnPlates()
    for _, plate in pairs(plates) do plate:ApplyTarget() end
end

local function NotifyColorPreviews(page, method)
    for _, preview in ipairs(page.ColorPreviews() or NO_ITEMS) do
        if preview[method] then preview[method](preview) end
    end
end

local function BuildTargetSection(page, result)
    local UpdatePreview = page.UpdatePreview
    local function indicators() IndicatorRefresh(page) end
    local function indicatorWriter(key)
        return function(value)
            Store(key, value)
            indicators()
        end
    end
    local refreshGlowSwatch -- assigned once the swatch exists

    result.styleHeader = AddHeader(page, "TARGET")

    local styleValues, styleOrder = IndicatorStyleList()

    local row1 = AddRow(page,
        { type = "dropdown", text = L("Target Glow Style"), values = GLOW_VALUES, order = GLOW_ORDER,
          getValue = function()
              if ns.GetTargetGlowStyle then return ns.GetTargetGlowStyle() end
              return SavedOr("targetGlowStyle")
          end,
          setValue = function(value)
              Store("targetGlowStyle", value)
              ApplyTargetOnPlates()
              UpdatePreview()
              refreshGlowSwatch()
          end },
        { type = "toggle", text = L("Show Target Indicator"),
          getValue = function() return P.DBVal("showTargetArrows") == true end,
          setValue = indicatorWriter("showTargetArrows") })
    result.targetGlowRow = row1

    local glowRegion = row1._leftRegion
    local glowSwatch, glowRepaint = AddSwatch(page, glowRegion, ReadGlowColor, function(r, g, b)
        StoreRGB("targetGlowColor", r, g, b)
        ApplyTargetOnPlates()
        UpdatePreview()
    end)
    refreshGlowSwatch = function()
        DimSwatch(glowSwatch, SavedOr("targetGlowStyle") == "none", 0.2)
        glowRepaint()
    end
    refreshGlowSwatch()
    P.RegisterWidgetRefresh(function() refreshGlowSwatch() end)

    result.targetIndicatorRow = AddRow(page,
        { type = "dropdown", text = L("Target Indicator Style"), values = styleValues, order = styleOrder,
          getValue = function()
              if ns.GetTargetIndicatorStyle then return ns.GetTargetIndicatorStyle() end
              return SavedOr("targetIndicatorStyle") or "arrows"
          end,
          setValue = indicatorWriter("targetIndicatorStyle"),
          preview = { kind = "texture", selectedWidth = 20, selectedHeight = 20, itemWidth = 18, itemHeight = 18,
                      resolve = ResolveIndicatorPreview } },
        { type = "slider", text = L("Target Indicator Scale"), min = 0.5, max = 3.0, step = 0.1,
          getValue = function() return SavedOr("targetArrowScale") or 1.0 end,
          setValue = indicatorWriter("targetArrowScale") })

    local row3 = AddRow(page,
        { type = "toggle", text = L("Reverse Indicator Direction"),
          getValue = function() return StoredOrDefaultTrue("targetIndicatorReversed") end,
          setValue = indicatorWriter("targetIndicatorReversed") },
        { type = "toggle", text = L("Indicator Shadow Glow"),
          getValue = function() return StoredOrDefaultTrue("targetIndicatorGlow") end,
          setValue = function(value)
              Store("targetIndicatorGlow", value)
              indicators()
              KT:RefreshPage()
          end })

    local shadowSwatch, shadowRepaint = AddSwatch(page, row3._rightRegion,
        function() return RGBOf("targetIndicatorGlowColor") end,
        function(r, g, b)
            StoreRGB("targetIndicatorGlowColor", r, g, b)
            indicators()
        end)
    local function refreshShadowSwatch()
        local stored = P.DB().targetIndicatorGlow
        local off
        if stored ~= nil then off = stored == false else off = defaults.targetIndicatorGlow ~= true end
        DimSwatch(shadowSwatch, off, 0.15)
        shadowRepaint()
    end
    refreshShadowSwatch()
    P.RegisterWidgetRefresh(function() refreshShadowSwatch() end)

    local glowEye = MakeEye(glowRegion, glowRegion:GetFrameLevel() + 5, "targetGlow", UpdatePreview)
    page.Attach(glowRegion, glowEye)
    P.FadeOnHover(glowEye)
    AddSpacer(page)
end

-- Border style beside the bar texture cell the panel passes in.
local function BuildBorderSection(page)
    local UpdatePreview = page.UpdatePreview
    AddHeader(page, "APPEARANCE")
    local borderRow = AddRow(page,
        { type = "dropdown", text = L("Border Style"), values = BORDER_VALUES, order = BORDER_ORDER,
          -- The plates ship and accept "kullthran"; this list's name for that look is "kullthranui"
          getValue = function()
              local style = SavedOr("borderStyle")
              if style == "kullthran" then return "kullthranui" end
              return style
          end,
          setValue = function(value)
              Store("borderStyle", value)
              ns.RefreshBorderStyle()
              UpdatePreview()
              NotifyColorPreviews(page, "RefreshBorderStyle")
              KT:RefreshPage()
          end },
        page.textureCell)
    local borderRegion = borderRow._leftRegion
    local readBorder, writeBorder = P.ColorAccess("borderColor", function()
        ns.RefreshBorderColor()
        UpdatePreview()
        NotifyColorPreviews(page, "RefreshBorderColor")
    end)
    P.DimmableSwatch(borderRegion, readBorder, writeBorder,
        function() return SavedOr("borderStyle") == "none" end,
        function(swatch) page.Attach(borderRegion, swatch) end)

    AddSpacer(page)
end

----------------------------------------------------------------------- Core positions section

local function PositionDropdown(page, position, label)
    return {
        type = "dropdown", text = L(label), values = ELEMENT_VALUES, order = ELEMENT_ORDER,
        getValue = function() return ElementAt(position) end,
        setValue = function(element)
            PlaceElement(element, position)
            page.SlotRefresh()
            -- The second pass anchors an eye coming back from hidden (EYE-5).
            if currentEyeRefresh then currentEyeRefresh() end
        end,
    }
end

-- Options of a position cog, with the element read at the click.
local function CoreCogOptions(page, position, label)
    local element = ElementAt(position)
    local isElite = element == "classification"
    local sizeKey = isElite and "rareEliteIconSize" or (position .. "SlotSize")
    local function refreshAgain()
        page.SlotRefresh()
        page.UpdatePreview()
    end
    local function offsetReader(axis)
        return function() return P.DBVal(OffsetKey(position, axis)) or 0 end
    end
    local function offsetWriter(axis)
        return function(value)
            Store(OffsetKey(position, axis), value)
            page.SlotRefresh()
        end
    end
    local opts = {
        title = isElite and L("Elite/Rare Indicator") or format(L("%s Slot Settings"), L(label)),
        xGet = offsetReader("X"), xSet = offsetWriter("X"),
        yGet = offsetReader("Y"), ySet = offsetWriter("Y"),
        sizeGet = function() return SavedOr(sizeKey) end,
        sizeSet = function(value)
            Store(sizeKey, value)
            refreshAgain()
        end,
        sizeMin = 10, sizeMax = 50,
    }
    if GROW_VALUES[position] and not isElite then
        local growKey = position .. "SlotGrowth"
        opts.growthGet = function() return SavedOr(growKey) end
        opts.growthSet = function(value)
            Store(growKey, value)
            refreshAgain()
        end
        opts.growthValues = GROW_VALUES[position]
    end
    return opts
end

local function AddCoreCog(page, region, position, label)
    local pop = page.pop
    local button = MakeCogButton(region)

    -- The underline is painted but stays hidden for good (G7).
    local underline = region:CreateTexture(nil, "ARTWORK")
    underline:SetSize(26, 2)
    underline:SetPoint("TOP", button, "BOTTOM", 0, -2)
    AccentPaint(underline, 0.65)
    underline:Hide()

    local pulse = region:CreateTexture(nil, "BACKGROUND", nil, -7)
    CoverButton(pulse, button)
    local accent = P.Accent
    pulse:SetColorTexture(accent.r, accent.g, accent.b, 0.16)
    local group = MakePulse(pulse, 0.45)

    local function isOff() return ElementAt(position) == "none" end
    local function isOwner() return pop.owner == button end

    local function updateHighlight()
        local off = isOff()
        AccentPaint(underline, off and 0.12 or (isOwner() and 1 or 0.65))
        UpdatePulse(pulse, group, off, 0.16)
    end
    button._updateHighlight = updateHighlight

    button:SetScript("OnEnter", function(self)
        if isOff() then
            P.ShowTooltip(self, COG_OFF_TIP)
        else
            self:SetAlpha(0.7)
        end
        updateHighlight()
    end)
    button:SetScript("OnLeave", function(self)
        P.HideTooltip()
        if not isOwner() then self:SetAlpha(isOff() and 0.15 or 0.4) end
        updateHighlight()
    end)
    button:SetScript("OnClick", function(self)
        if isOff() then return end
        ShowCogPopup(pop, self, CoreCogOptions(page, position, label))
        updateHighlight()
    end)

    if isOff() then button:SetAlpha(0.15) end
    updateHighlight()
    page.Attach(region, button)

    P.RegisterWidgetRefresh(function()
        button:SetAlpha(CogAlpha(isOff(), isOwner()))
        updateHighlight()
    end)

    page.coreCogs[#page.coreCogs + 1] = { button = button, isOff = isOff, isOwner = isOwner, updateHighlight = updateHighlight }
end

-- Core cog refresh: closes the popup of a cog gone off, then alpha and highlight of each.
local function RefreshCoreCogs(page)
    local frame = page.pop.frame
    for _, cog in ipairs(page.coreCogs) do
        local off = cog.isOff()
        if off and cog.isOwner() and frame:IsShown() then frame:Hide() end
        cog.button:SetAlpha(CogAlpha(off, cog.isOwner()))
        cog.updateHighlight()
    end
end

-- Eye refresh, raid marker then elite. Show comes after the attach (EYE-5).
local function RefreshEyes(page)
    for _, entry in ipairs(page.eyes) do
        local position = SavedOr(entry.key)
        local region = page.positionRegions[position]
        if position == "none" or not region then
            DetachInlineWidget(page, entry.eye)
            entry.eye:Hide()
        else
            entry.eye:SetParent(region)
            entry.eye:SetFrameLevel(region:GetFrameLevel() + 5)
            page.Attach(region, entry.eye)
            entry.eye:Show()
        end
    end
end

local function AddPositionEye(page, key, flag)
    local parent = page.parent
    local eye = MakeEye(parent, parent:GetFrameLevel() + 10, flag, page.UpdatePreview)
    eye:SetScript("OnEnter", function(self)
        self:SetAlpha(0.7)
        P.ShowTooltip(self, "Show/Hide on Preview", { width = 155 })
    end)
    eye:SetScript("OnLeave", function(self)
        self:SetAlpha(0.4)
        P.HideTooltip()
    end)
    page.eyes[#page.eyes + 1] = { eye = eye, key = key }
end

local function AddPositionRow(page, leftPos, leftLabel, rightPos, rightLabel)
    local row = AddRow(page, PositionDropdown(page, leftPos, leftLabel), PositionDropdown(page, rightPos, rightLabel))
    page.positionRegions[leftPos] = row._leftRegion
    page.positionRegions[rightPos] = row._rightRegion
    AddCoreCog(page, row._leftRegion, leftPos, leftLabel)
    AddCoreCog(page, row._rightRegion, rightPos, rightLabel)
    return row
end

local function BuildCorePositions(page, result)
    local header = AddHeader(page, "AURA POSITIONS")
    result.coreHeader = header
        result.coreRow1 = AddPositionRow(page, "top", "Top", "right", "Right")
    result.coreRow2 = AddPositionRow(page, "left", "Left", "topright", "Top Right")
    result.coreRow3 = AddPositionRow(page, "topleft", "Top Left", "bottom", "Bottom")
    AddPositionEye(page, "raidMarkerPos", "raidMarker")
    AddPositionEye(page, "classificationSlot", "classification")
    RefreshEyes(page)
    AddSpacer(page)
end

----------------------------------------------------------------------- Core text positions section

local function OverlapReason(key)
    if (key == "healthPctNum" or key == "healthNumPct") and P.DBVal("textSlotCenter") == "enemyName" then
        return OVERLAP_TIP
    end
    return nil
end

local function TextDropdown(page, slot, label, guardOverlap)
    return {
        type = "dropdown", text = L(label), values = TEXT_VALUES, order = TEXT_ORDER,
        getValue = function() return P.DBVal(slot) end,
        setValue = function(value)
            if value ~= "none" then
                for _, key in ipairs(ns.textSlotKeys) do
                    if key ~= slot and SlotOf(key) == value then Store(key, "none") end
                end
            end
            Store(slot, value)
            TextRefresh(page)
            KT:RefreshPage()
        end,
        disabled = function() return P.DBVal(slot) == "none" end,
        disabledTooltip = L(TEXT_OFF_TIP),
        labelOnlyDisabled = true,
        disabledValues = guardOverlap and OverlapReason or nil,
    }
end

local function TextCogOptions(page, slot, label)
    local sizeKey = slot .. "Size"
    local function offsetReader(key)
        return function() return P.DBVal(key) or 0 end
    end
    local function writer(key)
        return function(value)
            Store(key, value)
            TextRefresh(page)
        end
    end
    return {
        title = format(L("%s Settings"), L(label)),
        xGet = offsetReader(slot .. "XOffset"), xSet = writer(slot .. "XOffset"),
        yGet = offsetReader(slot .. "YOffset"), ySet = writer(slot .. "YOffset"),
        sizeGet = function() return SavedOr(sizeKey) end,
        sizeSet = writer(sizeKey),
        sizeMin = 6, sizeMax = 20, sizeLabel = "Size",
    }
end

-- Cog and colour swatch of one text slot. These cogs stay out of the core cog refresh (G6).
local function AddTextSlotWidgets(page, region, slot, label)
    local pop = page.pop
    local button = MakeCogButton(region)

    local highlight = region:CreateTexture(nil, "ARTWORK")
    highlight:SetSize(26, 2)
    highlight:SetPoint("TOP", button, "BOTTOM", 0, -2)
    AccentPaint(highlight, 0.65)
    highlight:ClearAllPoints()
    highlight:SetDrawLayer("BACKGROUND", -7)
    CoverButton(highlight, button)
    local group = MakePulse(highlight, 0.55)

    local function isOff() return P.DBVal(slot) == "none" end
    local function isOwner() return pop.owner == button end

    local function updateHighlight()
        UpdatePulse(highlight, group, isOff(), isOwner() and 0.24 or 0.14)
    end
    button._updateHighlight = updateHighlight

    button:SetScript("OnEnter", function(self)
        if isOff() then
            P.ShowTooltip(self, TEXT_OFF_TIP)
        else
            self:SetAlpha(0.7)
        end
        updateHighlight()
    end)
    button:SetScript("OnLeave", function(self)
        P.HideTooltip()
        if not isOwner() then self:SetAlpha(isOff() and 0.15 or 0.4) end
        updateHighlight()
    end)
    button:SetScript("OnClick", function(self)
        if isOff() then return end
        ShowCogPopup(pop, self, TextCogOptions(page, slot, label))
    end)

    if isOff() then button:SetAlpha(0.15) end
    updateHighlight()
    page.Attach(region, button)

    P.RegisterWidgetRefresh(function()
        button:SetAlpha(CogAlpha(isOff(), isOwner()))
        updateHighlight()
    end)

    local colorKey = slot .. "Color"
    local swatch, repaint = AddSwatch(page, region,
        function() return RGBOf(colorKey) end,
        function(r, g, b)
            StoreRGB(colorKey, r, g, b)
            TextRefresh(page)
        end)
    DimSwatch(swatch, isOff(), 0.15)
    P.RegisterWidgetRefresh(function()
        DimSwatch(swatch, isOff(), 0.15)
        repaint()
    end)
end

local function BuildCoreText(page, result)
    local header = AddHeader(page, "TEXT POSITIONS")
    result.coreTextHeader = header
    
    local row1 = AddRow(page, TextDropdown(page, "textSlotTop", "Top Text", false), TextDropdown(page, "textSlotRight", "Right Text", true))
    AddTextSlotWidgets(page, row1._leftRegion, "textSlotTop", "Top Text")
    AddTextSlotWidgets(page, row1._rightRegion, "textSlotRight", "Right Text")
    result.textRow1 = row1

    local row2 = AddRow(page, TextDropdown(page, "textSlotLeft", "Left Text", true), TextDropdown(page, "textSlotCenter", "Center Text", false))
    AddTextSlotWidgets(page, row2._leftRegion, "textSlotLeft", "Left Text")
    AddTextSlotWidgets(page, row2._rightRegion, "textSlotCenter", "Center Text")
    result.textRow2 = row2

    AddSpacer(page)
end

----------------------------------------------------------------------- Exports

function Slots.Setup(clientName)
    if clientName ~= "retail" and clientName ~= "forever" then
        error("OptionsSlots.Setup: client must be \"retail\" or \"forever\"", 2)
    end
    client = clientName
    P = ns.OptionsPreview
    defaults = ns.defaults or _G.KullThranUINameplatesDefaults or {}
    plates = ns.plates
end

function Slots.Build(ctx)
    local parent = ctx.parent
    parent._showRowDivider = true

    local page = {
        parent = parent, y = ctx.y, W = ctx.W,
        UpdatePreview = ctx.UpdatePreview, ColorPreviews = ctx.ColorPreviews,
        pop = { wasDown = false },
        inlineLists = {}, inlineHome = {},
        coreCogs = {}, eyes = {}, positionRegions = {},
        textureCell = ctx.textureCell,
    }
    page.Attach = function(region, widget) AttachInlineWidget(page, region, widget) end
    page.SlotRefresh = function() SlotRefresh(page) end

    -- From here on, callbacks of older builds reach this build's refreshes (G8).
    currentEyeRefresh = function() RefreshEyes(page) end
    currentCogRefresh = function() RefreshCoreCogs(page) end

    local pop = page.pop
    local result = {
        AttachInlineWidget = page.Attach,
        ShowCogPopup = function(anchor, opts) ShowCogPopup(pop, anchor, opts) end,
        PopupOwner = function() return pop.owner end,
        SlotOf = SlotOf,
        elementToKey = ELEMENT_TO_KEY,
        textSlotKeys = ns.textSlotKeys,
        timerPosValues = TIMER_VALUES,
        timerPosOrder = TIMER_ORDER,
        timerFallback = P.DBVal("auraTextPosition") or P.DBVal("debuffTextPosition") or defaults.auraTextPosition,
    }

    local want = ctx.sections or NO_ITEMS
    if want.level and client == "forever" then BuildLevelSection(page) end
    if want.target then BuildTargetSection(page, result) end
    if want.border then BuildBorderSection(page) end
    if want.core then BuildCorePositions(page, result) end
    if want.text then BuildCoreText(page, result) end

    result.y = page.y
    return result
end
