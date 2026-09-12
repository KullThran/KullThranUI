-- Widgets.lua
-- Fábrica de widgets para la interfaz personalizada de KullThranUI.
local addonName, ns = ...
local KT            = ns.KT

KT.Widgets          = KT.Widgets or {}
local W             = KT.Widgets

local function CurrentFont()
    if KT and type(KT.FONT_PATH) == "string" and KT.FONT_PATH ~= "" then
        return KT.FONT_PATH
    end
    if KT and KT.ResolveFontPath then
        return KT:ResolveFontPath()
    end

    return KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
end
local ICON_PATH     = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"

local function CurrentAccentColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local accent = palette and palette.accent or nil
    return (accent and accent.r) or KT.C_R or 1,
        (accent and accent.g) or KT.C_G or 0,
        (accent and accent.b) or KT.C_B or 0.3333333333
end

local function CurrentTextColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local text = palette and palette.text or nil
    return (text and text.r) or 1,
        (text and text.g) or 1,
        (text and text.b) or 1
end

local function CurrentMutedColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local muted = palette and palette.muted or nil
    return (muted and muted.r) or 0.74,
        (muted and muted.g) or 0.74,
        (muted and muted.b) or 0.78
end

-- Small locale flags drawn from color layers. They stay independent from the
-- active font, so scripts unsupported by Avant Garde cannot turn them into
-- missing-glyph boxes and no external texture pack is required.
function KT:CreateLocaleFlag(parent, locale, width, height)
    if not parent then return nil end

    local flag = CreateFrame("Frame", nil, parent)
    flag:SetSize(width or 22, height or 14)
    if flag.SetClipsChildren then flag:SetClipsChildren(true) end

    local parts = {}
    local borders = {}

    local function AddPart(x, y, w, h, r, g, b, rotation)
        -- The first rectangle is the flag background. Keep it on a lower
        -- layer so white backgrounds (United Kingdom/Korea) cannot cover
        -- their crosses, symbols or stripes on some render configurations.
        local layer = (#parts == 0) and "BACKGROUND" or "ARTWORK"
        local subLevel = (layer == "ARTWORK") and math.min(7, #parts) or nil
        local texture = flag:CreateTexture(nil, layer, nil, subLevel)
        texture:SetColorTexture(r, g, b, 1)
        texture:SetSize(math.max(1, w), math.max(1, h))
        texture:SetPoint("TOPLEFT", flag, "TOPLEFT", x, -y)
        if rotation and texture.SetRotation then texture:SetRotation(rotation) end
        parts[#parts + 1] = texture
        return texture
    end

    local function AddBorder()
        if #borders > 0 then
            for _, texture in ipairs(borders) do texture:Show() end
            return
        end
        local function Line()
            local texture = flag:CreateTexture(nil, "OVERLAY")
            texture:SetColorTexture(0.02, 0.02, 0.025, 0.9)
            borders[#borders + 1] = texture
            return texture
        end
        local top = Line()
        top:SetPoint("TOPLEFT")
        top:SetPoint("TOPRIGHT")
        top:SetHeight(1)
        local bottom = Line()
        bottom:SetPoint("BOTTOMLEFT")
        bottom:SetPoint("BOTTOMRIGHT")
        bottom:SetHeight(1)
        local left = Line()
        left:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
        left:SetPoint("BOTTOMLEFT", bottom, "TOPLEFT")
        left:SetWidth(1)
        local right = Line()
        right:SetPoint("TOPRIGHT", top, "BOTTOMRIGHT")
        right:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")
        right:SetWidth(1)
    end

    function flag:SetLocale(localeCode)
        localeCode = localeCode or "auto"
        if localeCode == "esMX" then localeCode = "esES" end
        if localeCode == "ptPT" then localeCode = "ptBR" end

        if self.localeCode == localeCode and #parts > 0 then
            for _, texture in ipairs(parts) do texture:Show() end
            AddBorder()
            return
        end
        self.localeCode = localeCode
        for _, texture in ipairs(parts) do texture:Hide() end
        wipe(parts)

        local w, h = self:GetWidth(), self:GetHeight()
        local white = { 0.96, 0.96, 0.96 }
        local red = { 0.82, 0.06, 0.10 }
        local blue = { 0.05, 0.20, 0.55 }
        local yellow = { 1.00, 0.78, 0.05 }

        if localeCode == "auto" then
            -- Auto is not a country: use a compact globe-style mark.
            AddPart(0, 0, w, h, 0.03, 0.28, 0.62)
            AddPart(w * 0.16, h * 0.20, w * 0.25, h * 0.28, 0.16, 0.72, 0.35)
            AddPart(w * 0.52, h * 0.48, w * 0.30, h * 0.30, 0.16, 0.72, 0.35)
            AddPart(w * 0.48, h * 0.08, 1, h * 0.84, 0.72, 0.90, 1.00)
            AddPart(w * 0.10, h * 0.48, w * 0.80, 1, 0.72, 0.90, 1.00)
        elseif localeCode == "enUS" or localeCode == "enGB" then
            -- English is represented by the United Kingdom.
            AddPart(0, 0, w, h, 0.02, 0.14, 0.42)
            AddPart(-w * 0.08, h * 0.38, w * 1.16, h * 0.24, 0.96, 0.96, 0.96, math.rad(32))
            AddPart(-w * 0.08, h * 0.38, w * 1.16, h * 0.24, 0.96, 0.96, 0.96, math.rad(-32))
            AddPart(-w * 0.08, h * 0.44, w * 1.16, h * 0.10, 0.82, 0.03, 0.10, math.rad(32))
            AddPart(-w * 0.08, h * 0.44, w * 1.16, h * 0.10, 0.82, 0.03, 0.10, math.rad(-32))
            AddPart(w * 0.38, 0, w * 0.24, h, 0.96, 0.96, 0.96)
            AddPart(0, h * 0.34, w, h * 0.32, 0.96, 0.96, 0.96)
            AddPart(w * 0.44, 0, w * 0.12, h, 0.82, 0.03, 0.10)
            AddPart(0, h * 0.42, w, h * 0.16, 0.82, 0.03, 0.10)
        elseif localeCode == "deDE" then
            AddPart(0, 0, w, h / 3, 0.03, 0.03, 0.03)
            AddPart(0, h / 3, w, h / 3, 0.82, 0.03, 0.09)
            AddPart(0, h * 2 / 3, w, h / 3, 1.00, 0.73, 0.00)
        elseif localeCode == "esES" then
            AddPart(0, 0, w, h / 4, 0.72, 0.03, 0.08)
            AddPart(0, h / 4, w, h / 2, 1.00, 0.78, 0.00)
            AddPart(0, h * 3 / 4, w, h / 4, 0.72, 0.03, 0.08)
            AddPart(w * 0.27, h * 0.38, math.max(2, w * 0.08), h * 0.24, 0.72, 0.08, 0.08)
        elseif localeCode == "frFR" then
            AddPart(0, 0, w / 3, h, 0.02, 0.20, 0.58)
            AddPart(w / 3, 0, w / 3, h, white[1], white[2], white[3])
            AddPart(w * 2 / 3, 0, w / 3, h, 0.90, 0.05, 0.12)
        elseif localeCode == "itIT" then
            AddPart(0, 0, w / 3, h, 0.00, 0.55, 0.27)
            AddPart(w / 3, 0, w / 3, h, white[1], white[2], white[3])
            AddPart(w * 2 / 3, 0, w / 3, h, 0.82, 0.04, 0.10)
        elseif localeCode == "ptBR" then
            AddPart(0, 0, w, h, 0.02, 0.55, 0.20)
            AddPart((w - h * 0.68) / 2, h * 0.16, h * 0.68, h * 0.68, yellow[1], yellow[2], yellow[3], math.rad(45))
            AddPart(w * 0.41, h * 0.30, w * 0.18, h * 0.40, 0.03, 0.20, 0.55)
            AddPart(w * 0.42, h * 0.46, w * 0.16, 1, 1, 1, 1)
        elseif localeCode == "ruRU" then
            AddPart(0, 0, w, h / 3, white[1], white[2], white[3])
            AddPart(0, h / 3, w, h / 3, 0.02, 0.25, 0.65)
            AddPart(0, h * 2 / 3, w, h / 3, 0.82, 0.04, 0.10)
        elseif localeCode == "koKR" then
            AddPart(0, 0, w, h, white[1], white[2], white[3])
            AddPart(w * 0.40, h * 0.20, h * 0.42, h * 0.42, red[1], red[2], red[3], math.rad(45))
            AddPart(w * 0.40, h * 0.48, h * 0.42, h * 0.42, 0.04, 0.23, 0.62, math.rad(45))
            AddPart(w * 0.10, h * 0.18, w * 0.22, 1.5, 0.04, 0.04, 0.04, math.rad(-25))
            AddPart(w * 0.68, h * 0.18, w * 0.22, 1.5, 0.04, 0.04, 0.04, math.rad(25))
            AddPart(w * 0.10, h * 0.72, w * 0.22, 1.5, 0.04, 0.04, 0.04, math.rad(25))
            AddPart(w * 0.68, h * 0.72, w * 0.22, 1.5, 0.04, 0.04, 0.04, math.rad(-25))
        elseif localeCode == "zhCN" then
            AddPart(0, 0, w, h, 0.86, 0.03, 0.08)
            AddPart(w * 0.16, h * 0.20, h * 0.25, h * 0.25, yellow[1], yellow[2], yellow[3], math.rad(45))
            AddPart(w * 0.33, h * 0.14, 1, 1, yellow[1], yellow[2], yellow[3])
            AddPart(w * 0.37, h * 0.30, 1, 1, yellow[1], yellow[2], yellow[3])
            AddPart(w * 0.34, h * 0.46, 1, 1, yellow[1], yellow[2], yellow[3])
        elseif localeCode == "zhTW" then
            AddPart(0, 0, w, h, 0.84, 0.03, 0.10)
            AddPart(0, 0, w * 0.48, h * 0.58, 0.02, 0.16, 0.47)
            AddPart(w * 0.18, h * 0.16, h * 0.24, h * 0.24, white[1], white[2], white[3], math.rad(45))
        else
            -- Unknown locales get the same neutral mark as Auto.
            AddPart(0, 0, w, h, 0.03, 0.28, 0.62)
            AddPart(w * 0.16, h * 0.20, w * 0.25, h * 0.28, 0.16, 0.72, 0.35)
            AddPart(w * 0.52, h * 0.48, w * 0.30, h * 0.30, 0.16, 0.72, 0.35)
            AddPart(w * 0.48, h * 0.08, 1, h * 0.84, 0.72, 0.90, 1.00)
            AddPart(w * 0.10, h * 0.48, w * 0.80, 1, 0.72, 0.90, 1.00)
        end

        AddBorder()
    end

    flag:SetLocale(locale)
    return flag
end

-- ============================================================================
-- HELPERS INTERNOS
-- ============================================================================
local function FW(parent) return parent:GetWidth() - 20 end

local function RowBg(frame, parent)
    if not parent.rowCounter then parent.rowCounter = 0 end
    parent.rowCounter = parent.rowCounter + 1
    local alpha = (parent.rowCounter % 2 == 0) and 0.05 or 0.02
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, alpha)
end

local function MakeHoverFrame(f)
    local t = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    t:SetAllPoints(); t:SetColorTexture(1, 1, 1, 0)
    f.hoverKT = t
    f:SetScript("OnEnter", function() t:SetColorTexture(1, 1, 1, 0.04) end)
    f:SetScript("OnLeave", function() t:SetColorTexture(1, 1, 1, 0) end)
end

-- ============================================================================
-- LOCALIZATION
-- ============================================================================
local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] ~= nil then return L[text] end
    end
    return text
end

local function NormalizeDropdownLabel(key, label)
    if type(label) ~= "string" then
        return label
    end
    -- Language names are regular locale keys. Avoid forcing Spanish labels
    -- into every non-English configuration.
    return label
end

local function ShortMediaLabel(value)
    if type(value) ~= "string" then
        return value
    end

    -- Media paths are valid stored values, but are not useful option labels.
    local slash = string.char(92)
    if not value:find(slash, 1, true) and not value:find("/", 1, true) then
        return value
    end

    local normalized = value:gsub(slash, "/")
    local name = normalized:match("([^/]+)$") or normalized
    name = name:gsub("%.[^%.]+$", "")
    name = name:gsub("_", " ")
    return name
end
local function LocalizeDropdownLabel(key, label)
    label = NormalizeDropdownLabel(key, label)

    local localized = LText(label)
    if localized ~= label then
        return ShortMediaLabel(localized)
    end

    if type(key) == "string" then
        local keyLocalized = LText(key)
        if keyLocalized ~= key then
            return ShortMediaLabel(keyLocalized)
        end
    end

    return ShortMediaLabel(localized)
end

-- ============================================================================
-- SCROLL FRAME
-- ============================================================================
-- Shared scroll container for configuration panels. The scrollbar is parented
-- beside the ScrollFrame so it remains visible when the viewport clips its
-- scroll child. It appears only when the content is taller than the viewport.
function W:ScrollFrame(parent, opts)
    opts = opts or {}

    local scroll = CreateFrame("ScrollFrame", opts.name, parent)
    scroll:SetClipsChildren(true)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(math.max(1, tonumber(opts.contentWidth) or 1), 1)
    scroll:SetScrollChild(child)

    local barParent = opts.scrollBarParent or parent
    local bar = CreateFrame("Slider", opts.scrollBarName, barParent)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(tonumber(opts.scrollBarWidth) or 6)
    bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", tonumber(opts.scrollBarOffset) or 4, 0)
    bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", tonumber(opts.scrollBarOffset) or 4, 0)
    bar:SetValueStep(1)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(false) end
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:EnableMouse(true)
    bar:EnableMouseWheel(true)
    bar:SetFrameLevel(scroll:GetFrameLevel() + 5)

    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.035, 0.038, 0.05, 0.88)

    local left = bar:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    left:SetWidth(1)

    local right = bar:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    right:SetWidth(1)

    bar:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = bar:GetThumbTexture()
    if thumb then
        thumb:SetWidth(tonumber(opts.thumbWidth) or 4)
        thumb:SetHeight(32)
    end

    local accentR, accentG, accentB = CurrentAccentColor()
    if thumb then thumb:SetVertexColor(accentR, accentG, accentB, 0.88) end
    left:SetColorTexture(accentR, accentG, accentB, 0.38)
    right:SetColorTexture(accentR, accentG, accentB, 0.38)

    bar._thumb = thumb
    bar._trackBg = track
    bar._trackL = left
    bar._trackR = right
    scroll.ScrollBar = bar
    scroll.scrollBar = bar
    scroll.scrollChild = child

    local autoHide = opts.autoHide ~= false
    local wheelStep = math.max(1, tonumber(opts.wheelStep) or 60)

    local function SafeNumber(value)
        if issecretvalue and issecretvalue(value) then return 0 end
        return tonumber(value) or 0
    end

    local function UpdateBar(rangeOverride, preserveValue, restoreValue)
        local range = SafeNumber(rangeOverride)
        if rangeOverride == nil then range = SafeNumber(scroll:GetVerticalScrollRange()) end
        range = math.max(0, range)
        scroll._scrollRange = range

        bar:SetMinMaxValues(0, math.max(1, range))
        local value = preserveValue and SafeNumber(restoreValue ~= nil and restoreValue or bar:GetValue()) or 0
        value = math.max(0, math.min(range, value))
        if bar:GetValue() ~= value then bar:SetValue(value) end
        if scroll:GetVerticalScroll() ~= value then scroll:SetVerticalScroll(value) end

        local viewportHeight = math.max(1, SafeNumber(scroll:GetHeight()))
        local trackHeight = math.max(1, SafeNumber(bar:GetHeight()))
        if thumb then
            local ratio = viewportHeight / (viewportHeight + range)
            thumb:SetHeight(math.max(24, math.floor(trackHeight * ratio + 0.5)))
        end

        bar:SetShown(not autoHide or range > 0.5)
    end

    function scroll:UpdateScrollBar(preserveValue, restoreValue, rangeOverride)
        UpdateBar(rangeOverride, preserveValue, restoreValue)
    end

    scroll:SetScript("OnScrollRangeChanged", function(_, _, verticalRange)
        UpdateBar(verticalRange, true)
    end)
    scroll:SetScript("OnVerticalScroll", function(_, offset)
        offset = SafeNumber(offset)
        if bar:GetValue() ~= offset then bar:SetValue(offset) end
    end)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        local minValue, maxValue = bar:GetMinMaxValues()
        local value = SafeNumber(bar:GetValue()) - (SafeNumber(delta) * wheelStep)
        bar:SetValue(math.max(minValue, math.min(maxValue, value)))
    end)
    scroll:SetScript("OnSizeChanged", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if scroll then UpdateBar(nil, true) end
            end)
        else
            UpdateBar(nil, true)
        end
    end)

    bar:SetScript("OnValueChanged", function(_, value)
        value = math.max(0, math.min(scroll._scrollRange or 0, SafeNumber(value)))
        if bar:GetValue() ~= value then
            bar:SetValue(value)
            return
        end
        if scroll:GetVerticalScroll() ~= value then scroll:SetVerticalScroll(value) end
    end)
    bar:SetScript("OnMouseWheel", function(_, delta)
        local handler = scroll:GetScript("OnMouseWheel")
        if handler then handler(scroll, delta) end
    end)
    bar:SetScript("OnEnter", function()
        if thumb then thumb:SetVertexColor(accentR, accentG, accentB, 1) end
    end)
    bar:SetScript("OnLeave", function()
        if thumb then thumb:SetVertexColor(accentR, accentG, accentB, 0.88) end
    end)

    bar:Hide()
    return scroll, child, bar
end

-- ============================================================================
-- SECTION HEADER
-- ============================================================================
function W:SectionHeader(parent, text, yOffset)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(FW(parent), 30)
    f:SetPoint("TOPLEFT", 10, yOffset)

    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
    do
        local ar, ag, ab = CurrentAccentColor()
        line:SetColorTexture(ar, ag, ab, 0.35)
    end

    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFont(CurrentFont(), 10, "OUTLINE")
    do
        local ar, ag, ab = CurrentAccentColor()
        t:SetTextColor(ar, ag, ab, 1)
    end
    local header = LText(text) or ""
    if type(header) == "string" then
        header = header:upper()
    end
    t:SetText(header)
    t:SetPoint("BOTTOMLEFT", 0, 5)

    parent.rowCounter = 0

    return f, 36
end

-- ============================================================================
-- SPACER
-- ============================================================================
function W:Spacer(parent, yOffset, h)
    h = h or 8
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(FW(parent), h)
    f:SetPoint("TOPLEFT", 10, yOffset)
    return f, h
end

-- ============================================================================
-- LABEL
-- ============================================================================
function W:Label(parent, text, yOffset, fontSize, color)
    fontSize = fontSize or 11
    if not color then
        local mr, mg, mb = CurrentMutedColor()
        color = { r = mr, g = mg, b = mb }
    end
    local f  = CreateFrame("Frame", nil, parent)
    f:SetSize(FW(parent), 18)
    f:SetPoint("TOPLEFT", 10, yOffset)
    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetFont(CurrentFont(), fontSize)
    t:SetText(LText(text))
    t:SetTextColor(color.r, color.g, color.b, 1)
    t:SetPoint("LEFT", 4, 0)
    t:SetWidth(FW(parent) - 8)
    t:SetWordWrap(true)
    local lineH = math.max(20, t:GetStringHeight() + 4)
    f:SetHeight(lineH)
    return f, lineH + 2
end

-- ============================================================================
-- TOGGLE
-- ============================================================================
function W:Toggle(parent, text, yOffset, get, set)
    local w   = FW(parent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(w, 36)
    btn:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(btn, parent)
    btn:EnableMouse(true)
    MakeHoverFrame(btn)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 12)
    label:SetText(LText(text))
    label:SetPoint("LEFT", 12, 0)
    label:SetJustifyH("LEFT")
    label:SetWidth(w - 68)

    local pill = CreateFrame("Frame", nil, btn)
    pill:SetSize(38, 20)
    pill:SetPoint("RIGHT", -12, 0)

    local pillBg = pill:CreateTexture(nil, "BACKGROUND")
    pillBg:SetAllPoints()

    local knob = pill:CreateTexture(nil, "ARTWORK")
    knob:SetSize(16, 16)
    knob:SetColorTexture(1, 1, 1, 1)

    local function Update()
        local val = get and get() or false
        knob:ClearAllPoints()
        if val then
            local tr, tg, tb = CurrentTextColor()
            local ar, ag, ab = CurrentAccentColor()
            knob:SetPoint("RIGHT", pill, "RIGHT", -2, 0)
            pillBg:SetColorTexture(ar, ag, ab, 1)
            label:SetTextColor(tr, tg, tb, 1)
        else
            local mr, mg, mb = CurrentMutedColor()
            knob:SetPoint("LEFT", pill, "LEFT", 2, 0)
            pillBg:SetColorTexture(0.12, 0.12, 0.15, 1)
            label:SetTextColor(mr * 0.72, mg * 0.72, mb * 0.72, 1)
        end
    end

    btn:SetScript("OnClick", function()
        if set then set(not (get and get() or false)) end
        Update()
    end)

    btn._baseWidth = w
    btn._label = label
    function btn:SetReservedRightSpace(pixels)
        local reserved = math.max(0, pixels or 0)
        local newWidth = math.max(120, (self._baseWidth or w) - reserved)
        self:SetWidth(newWidth)
        if self._label then
            self._label:SetWidth(math.max(40, newWidth - 68))
        end
    end
    btn:SetReservedRightSpace(0)

    Update()
    btn.Update = Update
    return btn, 38
end

-- ============================================================================
-- SLIDER
-- ============================================================================
function W:Slider(parent, text, yOffset, get, set, minVal, maxVal, step, fmt, opts)
    if type(fmt) == "table" and opts == nil then
        opts = fmt
        fmt = opts.fmt
    end
    opts = type(opts) == "table" and opts or {}

    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 50)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 11)
    label:SetText(LText(text))
    do
        local mr, mg, mb = CurrentMutedColor()
        label:SetTextColor(mr, mg, mb, 1)
    end
    label:SetPoint("TOPLEFT", 12, -4)
    -- Reserve space for the default/value fields so long labels cannot
    -- overlap them in narrow two-column option blocks.
    label:SetWidth(math.max(72, w - 160))
    label:SetWordWrap(true)

    local valText = CreateFrame("EditBox", nil, f)
    valText:SetSize(50, 18)
    valText:SetFont(CurrentFont(), 11, "OUTLINE")
    valText:SetAutoFocus(false)
    valText:SetJustifyH("RIGHT")
    valText:SetJustifyV("MIDDLE")
    valText:EnableMouse(true)
    if valText.SetTextInsets then
        valText:SetTextInsets(2, 2, 0, 0)
    end
    do
        local ar, ag, ab = CurrentAccentColor()
        valText:SetTextColor(ar, ag, ab, 1)
    end
    valText:SetPoint("TOPRIGHT", -12, -4)
    KT:AddBackdrop(valText, 0.02, 0.02, 0.03, 0)
    do
        local ar, ag, ab = CurrentAccentColor()
        KT:AddBorder(valText, ar, ag, ab, 0)
    end

    local defaultText = f:CreateFontString(nil, "OVERLAY")
    defaultText:SetFont(CurrentFont(), 10)
    do
        local mr, mg, mb = CurrentMutedColor()
        defaultText:SetTextColor(mr * 0.76, mg * 0.76, mb * 0.76, 1)
    end
    -- Keep the default and current value on one reserved top row. This
    -- prevents wrapped labels in narrow two-column blocks from colliding
    -- with their metadata.
    defaultText:SetSize(68, 18)
    defaultText:SetPoint("TOPRIGHT", valText, "TOPLEFT", -12, -4)
    defaultText:SetJustifyH("RIGHT")
    defaultText:SetJustifyV("MIDDLE")

    label:SetJustifyH("LEFT")
    label:ClearAllPoints()
    label:SetPoint("TOPLEFT", 12, -4)

    local track = f:CreateTexture(nil, "ARTWORK")
    track:SetHeight(3)
    track:SetPoint("BOTTOMLEFT", 16, 14)
    track:SetPoint("BOTTOMRIGHT", -16, 14)
    track:SetColorTexture(0.18, 0.18, 0.20, 1)

    local slider = CreateFrame("Slider", nil, f)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetSize(w - 32, 24)
    slider:SetPoint("BOTTOM", 0, 4)
    if slider.SetHitRectInsets then
        slider:SetHitRectInsets(0, 0, -6, -6)
    end

    slider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(8, 16); thumb:SetVertexColor(1, 1, 1, 1)
    end

    for i = 1, slider:GetNumRegions() do
        local r = select(i, slider:GetRegions())
        if r and r.IsObjectType and r:IsObjectType("Texture") then
            local tex = r:GetTexture()
            if tex and (type(tex) == "string") and tex ~= "" then
                if r ~= thumb then r:SetAlpha(0) end
            end
        end
    end

    local function FormatVal(v)
        if fmt then
            return string.format(fmt, v)
        elseif step and step < 0.05 then
            return string.format("%.2f", v)
        elseif step and step < 1 then
            return string.format("%.1f", v)
        else
            return tostring(math.floor(v + 0.5))
        end
    end

    local function CoerceVal(v)
        v = tonumber(v)
        if not v then return nil end
        if minVal ~= nil then v = math.max(minVal, v) end
        if maxVal ~= nil then v = math.min(maxVal, v) end
        if step and step > 0 then
            v = math.floor((v / step) + 0.5) * step
        end
        return v
    end

    local function SetValueText(v)
        valText:SetText(FormatVal(v))
        valText:SetCursorPosition(0)
    end

    local function ApplyValueFromEdit()
        if valText._committing then return end
        valText._committing = true
        local value = CoerceVal(valText:GetText())
        if not value then
            SetValueText(slider:GetValue() or minVal or 0)
            valText._committing = nil
            return
        end
        slider.isInitializing = true
        slider:SetValue(value)
        slider.isInitializing = false
        if set then set(value) end
        SetValueText(value)
        valText._committing = nil
    end

    slider:SetScript("OnValueChanged", function(self, v)
        if self.isInitializing then return end
        if set then set(v) end
        if not valText:HasFocus() then
            SetValueText(v)
        end
    end)

    local ok, cur = pcall(get)
    local initialValue = ok and (cur or minVal) or minVal
    local defaultValue = initialValue
    if opts.defaultGet then
        local okDefault, resolvedDefault = pcall(opts.defaultGet)
        if okDefault and resolvedDefault ~= nil then
            defaultValue = resolvedDefault
        end
    elseif opts.defaultValue ~= nil then
        defaultValue = opts.defaultValue
    end
    defaultText:SetText(string.format("%s: %s", LText("Default"), FormatVal(defaultValue)))
    slider.isInitializing = true
    slider:SetValue(initialValue)
    slider.isInitializing = false
    SetValueText(initialValue)

    slider:HookScript("OnMouseDown", function()
        valText:ClearFocus()
    end)

    valText:SetScript("OnEditFocusGained", function(self)
        local ar, ag, ab = CurrentAccentColor()
        KT:AddBackdrop(self, 0.02, 0.02, 0.03, 0.94)
        KT:AddBorder(self, ar, ag, ab, 0.85)
        self:HighlightText()
    end)
    valText:SetScript("OnEditFocusLost", function(self)
        KT:AddBackdrop(self, 0.02, 0.02, 0.03, 0)
        local ar, ag, ab = CurrentAccentColor()
        KT:AddBorder(self, ar, ag, ab, 0)
        if self._skipNextCommit then
            self._skipNextCommit = nil
        else
            ApplyValueFromEdit()
        end
        self:HighlightText(0, 0)
    end)
    valText:SetScript("OnEnterPressed", function(self)
        ApplyValueFromEdit()
        self._skipNextCommit = true
        self:ClearFocus()
    end)
    valText:SetScript("OnEscapePressed", function(self)
        SetValueText(slider:GetValue() or initialValue)
        self._skipNextCommit = true
        self:ClearFocus()
    end)

    f.Refresh = function()
        local ok2, v = pcall(get)
        if ok2 and v ~= nil then
            slider.isInitializing = true
            slider:SetValue(v)
            slider.isInitializing = false
            SetValueText(v)
        end
    end
    return f, 54
end

-- ============================================================================
-- DROPDOWN
-- ============================================================================
function W:Dropdown(parent, text, yOffset, values, get, set, order, fontPreview)
    local DROPDOWN_ITEM_HEIGHT = 22
    local DROPDOWN_MAX_VISIBLE_ITEMS = 12
    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 50)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 11)
    label:SetText(LText(text))
    do
        local mr, mg, mb = CurrentMutedColor()
        label:SetTextColor(mr, mg, mb, 1)
    end
    label:SetPoint("TOPLEFT", 12, -4)
    label:SetWidth(w - 24)

    local btn = CreateFrame("Button", nil, f)
    btn:SetHeight(24)
    btn:SetPoint("BOTTOMLEFT", 12, 4)
    btn:SetPoint("BOTTOMRIGHT", -12, 4)
    KT:AddBackdrop(btn, 0.08, 0.08, 0.11, 1)
    KT:AddBorder(btn, 0.20, 0.20, 0.25, 1)

    local selText = btn:CreateFontString(nil, "OVERLAY")
    selText:SetFont(CurrentFont(), 11)
    selText:SetTextColor(1, 1, 1, 1)
    selText:SetPoint("LEFT", 8, 0)
    selText:SetPoint("RIGHT", -22, 0)
    selText:SetJustifyH("LEFT")

    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetSize(16, 16)
    arrow:SetTexture(ICON_PATH .. "downarrow.png")
    do
        local ar, ag, ab = CurrentAccentColor()
        arrow:SetVertexColor(ar, ag, ab, 1)
    end
    arrow:SetPoint("RIGHT", -6, 0)

    local previewConfig = type(fontPreview) == "table" and fontPreview or nil

    local function GetBaseVals()
        local result = type(values) == "function" and values() or values
        return type(result) == "table" and result or nil
    end

    local function GetMenuOptions(tbl)
        local opts = tbl and rawget(tbl, "_menuOpts")
        return type(opts) == "table" and opts or nil
    end

    local function GetSharedMedia()
        return LibStub and LibStub("LibSharedMedia-3.0", true) or nil
    end

    local function NormalizePreviewKind(kind)
        kind = type(kind) == "string" and kind:lower() or nil
        if kind == "statusbar" or kind == "background" then return "texture" end
        if kind == "texture" or kind == "font" then return kind end
        return nil
    end

    local function GetPreviewKind(tbl)
        local explicitKind
        if type(fontPreview) == "string" then
            explicitKind = fontPreview
        elseif previewConfig then
            explicitKind = previewConfig.kind or previewConfig.type or previewConfig.mediaType
        elseif fontPreview then
            explicitKind = "font"
        end
        explicitKind = NormalizePreviewKind(explicitKind)
        if explicitKind then return explicitKind end

        local menuOptions = GetMenuOptions(tbl)
        local menuKind = menuOptions and NormalizePreviewKind(
            menuOptions.kind or menuOptions.type or menuOptions.mediaType
        )
        if menuKind then return menuKind end
        if menuOptions and type(menuOptions.background) == "function" then return "texture" end

        -- Legacy media selectors only supplied their label and values table.
        -- Infer them conservatively and verify at least one resolvable entry.
        local lowered = tostring(text or ""):lower()
        local inferred
        if lowered:find("textur", 1, true) then
            inferred = "texture"
        elseif lowered:find("font", 1, true)
            or lowered:find("fuente", 1, true)
            or lowered:find("schrift", 1, true)
            or lowered:find("police", 1, true)
            or lowered:find("fonte", 1, true)
        then
            inferred = "font"
        end
        if not inferred or not tbl then return nil end

        local mediaType = inferred == "texture" and "statusbar" or "font"
        local LSM = GetSharedMedia()
        for key in pairs(tbl) do
            if key ~= "_menuOpts" and type(key) == "string" then
                if key:find("\\", 1, true) or key:find("/", 1, true) then return inferred end
                if LSM and LSM:Fetch(mediaType, key, true) then return inferred end
            end
        end
        return nil
    end

    local function UsesSharedMedia(tbl, kind)
        if not kind then return false end
        local menuOptions = GetMenuOptions(tbl)
        if previewConfig and previewConfig.sharedMedia ~= nil then
            return previewConfig.sharedMedia == true
        end
        if menuOptions and menuOptions.sharedMedia ~= nil then
            return menuOptions.sharedMedia == true
        end
        if (previewConfig and type(previewConfig.resolve) == "function")
            or (menuOptions and (
                type(menuOptions.resolve) == "function"
                or type(menuOptions.background) == "function"
            ))
        then
            return false
        end
        return GetSharedMedia() ~= nil
    end

    local function GetVals()
        local source = GetBaseVals()
        if not source then return nil end
        local kind = GetPreviewKind(source)
        if not UsesSharedMedia(source, kind) then return source end

        local LSM = GetSharedMedia()
        local mediaType = kind == "texture" and "statusbar" or "font"
        local mediaList = LSM and LSM:List(mediaType)
        if not mediaList then return source end

        -- Build on open so media registered later by other addons is included.
        local merged = {}
        for key, value in pairs(source) do merged[key] = value end
        for i = 1, #mediaList do
            local name = mediaList[i]
            if merged[name] == nil then merged[name] = name end
        end
        return merged
    end
    local function FontEntryLabel(key, lbl)
        if KT and KT.GetLocalizedFontDisplayName then
            local display = KT:GetLocalizedFontDisplayName()
            local isLegacyDefault = key == "AAA_ITC_Avant_Garde"
                or (KT.LOCALIZED_FONT_NAME and key == KT.LOCALIZED_FONT_NAME)
            if display and isLegacyDefault then
                return display
            end
        end
        return LocalizeDropdownLabel(key, lbl)
    end
    local function GetLabel()
        local v   = get and get() or ""
        local tbl = GetVals()
        local lbl = tbl and tbl[v] or tostring(v)
        return FontEntryLabel(v, lbl)
    end

    local previewTexture = btn:CreateTexture(nil, "ARTWORK")
    previewTexture:SetSize(
        (previewConfig and (previewConfig.selectedWidth or previewConfig.width)) or 54,
        (previewConfig and (previewConfig.selectedHeight or previewConfig.height)) or 10
    )
    previewTexture:SetPoint("LEFT", 8, 0)
    previewTexture:Hide()
    local localeFlag
    if previewConfig and previewConfig.localeFlags and KT.CreateLocaleFlag then
        localeFlag = KT:CreateLocaleFlag(btn, get and get() or "auto", 22, 14)
        localeFlag:SetPoint("LEFT", 8, 0)
        localeFlag:Hide()
    end

    local function ResolvePreviewPath(value, kind)
        if type(value) ~= "string" or value == "" then
            return nil
        end
        local tbl = GetBaseVals()
        local menuOptions = GetMenuOptions(tbl)
        if previewConfig and type(previewConfig.resolve) == "function" then
            local ok, result = pcall(previewConfig.resolve, value)
            if ok and type(result) == "string" and result ~= "" then
                return result
            end
        elseif menuOptions and type(menuOptions.resolve) == "function" then
            local ok, result = pcall(menuOptions.resolve, value)
            if ok and type(result) == "string" and result ~= "" then
                return result
            end
        elseif kind == "texture" and menuOptions and type(menuOptions.background) == "function" then
            local ok, result = pcall(menuOptions.background, value)
            if ok and type(result) == "string" and result ~= "" then
                return result
            end
        elseif kind == "font" and type(fontPreview) == "function" then
            local ok, result = pcall(fontPreview, value)
            if ok and type(result) == "string" and result ~= "" then
                return result
            end
        end
        if value:find("\\", 1, true) or value:find("/", 1, true) then
            return value
        end
        local mediaType = kind == "texture" and "statusbar" or "font"
        local LSM = GetSharedMedia()
        return LSM and LSM:Fetch(mediaType, value, true) or nil
    end

    local function ApplyPreview(fontString, value)
        if not fontString then return end
        if localeFlag then
            previewTexture:Hide()
            localeFlag:SetLocale(value)
            localeFlag:Show()
            fontString:ClearAllPoints()
            fontString:SetPoint("LEFT", localeFlag, "RIGHT", 7, 0)
            fontString:SetPoint("RIGHT", -22, 0)
            return
        end
        local kind = GetPreviewKind(GetBaseVals())
        local path = ResolvePreviewPath(value, kind)
        if kind == "texture" then
            if path then
                pcall(previewTexture.SetTexture, previewTexture, path)
                previewTexture:Show()
            else
                previewTexture:Hide()
            end
            fontString:ClearAllPoints()
            fontString:SetPoint("LEFT", previewTexture, "RIGHT", 6, 0)
            fontString:SetPoint("RIGHT", -22, 0)
        else
            previewTexture:Hide()
            fontString:ClearAllPoints()
            fontString:SetPoint("LEFT", 8, 0)
            fontString:SetPoint("RIGHT", -22, 0)
            if kind == "font" and path then
                local _, size, flags = fontString:GetFont()
                pcall(fontString.SetFont, fontString, path, size or 11, flags or "")
            end
        end
    end

    selText:SetText(GetLabel())
    ApplyPreview(selText, get and get() or nil)

    local list = CreateFrame("Frame", nil, UIParent)
    list:SetFrameStrata("TOOLTIP")
    list:SetFrameLevel(1000)
    list:SetClampedToScreen(true)
    list:Hide()
    KT:AddBackdrop(list, 0.04, 0.05, 0.07, 0.98)
    do
        local ar, ag, ab = CurrentAccentColor()
        KT:AddBorder(list, ar, ag, ab, 0.6)
    end

    local closer = CreateFrame("Frame", nil, UIParent)
    closer:SetAllPoints()
    closer:SetFrameStrata("FULLSCREEN_DIALOG")
    closer:SetFrameLevel(900)
    closer:EnableMouse(true)
    closer:Hide()
    closer:SetScript("OnMouseDown", function()
        list:Hide()
        closer:Hide()
    end)

    local listScroll = CreateFrame("ScrollFrame", nil, list, "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 2, -2)
    listScroll:SetPoint("BOTTOMRIGHT", -26, 2)
    listScroll:EnableMouseWheel(true)

    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetPoint("TOPLEFT", 0, 0)
    listContent:SetPoint("TOPRIGHT", 0, 0)
    listScroll:SetScrollChild(listContent)

    listScroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local step = (list._itemHeight or DROPDOWN_ITEM_HEIGHT) * 2
        local nextValue = current - (delta * step)
        local maxScroll = math.max(0, (listContent:GetHeight() or 0) - (self:GetHeight() or 0))
        nextValue = math.max(0, math.min(maxScroll, nextValue))
        if self.ScrollBar then self.ScrollBar:SetValue(nextValue) end
        self:SetVerticalScroll(nextValue)
    end)

    local function BuildList()
        for _, c in ipairs({ listContent:GetChildren() }) do
            c:Hide(); c:SetParent(UIParent)
        end

        local tbl = GetVals()
        if not tbl then return end

        local entries = {}
        local included = {}
        local previewKind = GetPreviewKind(tbl)
        local menuOptions = GetMenuOptions(tbl)
        local itemHeight = tonumber(menuOptions and menuOptions.itemHeight) or DROPDOWN_ITEM_HEIGHT
        itemHeight = math.max(18, math.min(40, itemHeight))
        list._itemHeight = itemHeight
        local listOrder = type(order) == "function" and order() or order
        if listOrder then
            for _, k in ipairs(listOrder) do
                if k ~= "---" and tbl[k] ~= nil then
                    table.insert(entries, { k = k, l = FontEntryLabel(k, tbl[k]) })
                    included[k] = true
                end
            end
            -- Preserve native ordering and append external SharedMedia entries.
            if UsesSharedMedia(tbl, previewKind) then
                local extras = {}
                for k, lbl in pairs(tbl) do
                    if k ~= "_menuOpts" and not included[k] then
                        table.insert(extras, { k = k, l = FontEntryLabel(k, lbl) })
                    end
                end
                table.sort(extras, function(a, b) return tostring(a.l) < tostring(b.l) end)
                for i = 1, #extras do table.insert(entries, extras[i]) end
            end
        else
            for k, lbl in pairs(tbl) do
                if k ~= "_menuOpts" then
                    table.insert(entries, { k = k, l = FontEntryLabel(k, lbl) })
                end
            end
            table.sort(entries, function(a, b) return tostring(a.l) < tostring(b.l) end)
        end

        local ly = 0
        for _, entry in ipairs(entries) do
            local item = CreateFrame("Button", nil, listContent)
            item:SetHeight(itemHeight)
            item:SetPoint("TOPLEFT", 0, -ly)
            item:SetPoint("TOPRIGHT", 0, -ly)

            local ibg = item:CreateTexture(nil, "BACKGROUND")
            ibg:SetAllPoints(); ibg:SetColorTexture(0, 0, 0, 0)

            local itext = item:CreateFontString(nil, "OVERLAY")
            itext:SetFont(CurrentFont(), 11)
            local display = entry.l
            itext:SetText(display)
            itext:SetJustifyH("LEFT")
            itext:SetJustifyV("MIDDLE")
            local itemPreview = item:CreateTexture(nil, "ARTWORK")
            itemPreview:SetSize(
                (previewConfig and (previewConfig.itemWidth or previewConfig.width)) or 48,
                (previewConfig and (previewConfig.itemHeight or previewConfig.height)) or 8
            )
            itemPreview:SetPoint("LEFT", 8, 0)
            itemPreview:Hide()
            local previewPath = ResolvePreviewPath(entry.k, previewKind)
            if previewConfig and previewConfig.localeFlags and KT.CreateLocaleFlag then
                local itemFlag = KT:CreateLocaleFlag(item, entry.k, 22, 14)
                itemFlag:SetPoint("LEFT", 8, 0)
                itext:SetPoint("LEFT", itemFlag, "RIGHT", 7, 0)
            elseif previewKind == "texture" then
                if previewPath then
                    pcall(itemPreview.SetTexture, itemPreview, previewPath)
                    itemPreview:Show()
                end
                itext:ClearAllPoints()
                itext:SetPoint("LEFT", itemPreview, "RIGHT", 6, 0)
            elseif previewKind == "font" then
                if previewPath then
                    local _, size, flags = itext:GetFont()
                    pcall(itext.SetFont, itext, previewPath, size or 11, flags or "")
                end
                itext:SetPoint("LEFT", 8, 0)
            else
                itext:SetPoint("LEFT", 8, 0)
            end
            do
                local tr, tg, tb = CurrentTextColor()
                itext:SetTextColor(tr, tg, tb, 1)
            end
            itext:SetPoint("RIGHT", -8, 0)

            local k, lbl = entry.k, display
            item:SetScript("OnClick", function()
                selText:SetText(lbl)
                ApplyPreview(selText, k)
                list:Hide()
                closer:Hide()
                if set then set(k) end
            end)
            item:SetScript("OnEnter", function()
                local ar, ag, ab = CurrentAccentColor()
                ibg:SetColorTexture(ar, ag, ab, 0.18)
            end)
            item:SetScript("OnLeave", function() ibg:SetColorTexture(0, 0, 0, 0) end)
            item:EnableMouseWheel(true)
            item:SetScript("OnMouseWheel", function(_, delta)
                local wheelHandler = listScroll:GetScript("OnMouseWheel")
                if wheelHandler then wheelHandler(listScroll, delta) end
            end)

            ly = ly + itemHeight
        end

        local viewportHeight = math.min(ly, itemHeight * DROPDOWN_MAX_VISIBLE_ITEMS)
        local showScrollBar = ly > viewportHeight
        local scrollBarWidth = showScrollBar and 20 or 0
        local contentWidth = math.max(80, (list:GetWidth() or btn:GetWidth()) - 6 - scrollBarWidth)

        listContent:SetWidth(contentWidth)
        listContent:SetHeight(ly)
        listScroll:SetVerticalScroll(0)
        list:SetHeight(viewportHeight + 4)

        if listScroll.ScrollBar then
            listScroll.ScrollBar:SetMinMaxValues(0, math.max(0, ly - viewportHeight))
            listScroll.ScrollBar:SetValue(0)
            if showScrollBar then
                listScroll.ScrollBar:Show()
            else
                listScroll.ScrollBar:Hide()
            end
        end
    end

    btn:SetScript("OnClick", function()
        if list:IsShown() then
            list:Hide()
            closer:Hide()
            return
        end
        list:SetWidth(btn:GetWidth())
        BuildList()
        list:ClearAllPoints()
        local buttonBottom = btn.GetBottom and btn:GetBottom()
        local listHeight = list:GetHeight() or 0
        if buttonBottom and listHeight > buttonBottom then
            list:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 2)
        else
            list:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
        end
        closer:Show()
        list:Show()
    end)

    f._baseWidth = w
    f._label = label
    function f:SetReservedRightSpace(pixels)
        local reserved = math.max(0, pixels or 0)
        local newWidth = math.max(120, (self._baseWidth or w) - reserved)
        self:SetWidth(newWidth)
        if self._label then
            self._label:SetWidth(math.max(60, newWidth - 24))
        end
    end
    f:SetReservedRightSpace(0)

    f.Refresh = function()
        local value = get and get() or nil
        selText:SetText(GetLabel())
        ApplyPreview(selText, value)
    end
    return f, 50
end

-- ============================================================================
-- COLOR SWATCH
-- ============================================================================
function W:ColorSwatch(parent, text, yOffset, get, set, hasAlpha)
    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 36)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)
    MakeHoverFrame(f)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 12)
    label:SetText(LText(text))
    do
        local mr, mg, mb = CurrentMutedColor()
        label:SetTextColor(mr, mg, mb, 1)
    end
    label:SetPoint("LEFT", 12, 0)

    local swatch = CreateFrame("Button", nil, f)
    swatch:SetSize(24, 24)
    swatch:SetPoint("RIGHT", -12, 0)
    KT:AddBorder(swatch, 0.35, 0.35, 0.35, 1)

    local swTex = swatch:CreateTexture(nil, "ARTWORK")
    swTex:SetPoint("TOPLEFT", 1, -1)
    swTex:SetPoint("BOTTOMRIGHT", -1, 1)

    local function UpdateSwatch()
        local ok, r, g, b, a = pcall(get)
        if ok and r then swTex:SetColorTexture(r, g, b or 1, a or 1) end
    end
    UpdateSwatch()

    swatch:SetScript("OnClick", function()
        if ColorPickerFrame and ColorPickerFrame.SetFrameStrata then
            ColorPickerFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        end
        if ColorPickerFrame and ColorPickerFrame.SetClampedToScreen then
            ColorPickerFrame:SetClampedToScreen(true)
        end
        local ok, r, g, b, a = pcall(get)
        if not ok then return end
        r = r or 1; g = g or 1; b = b or 1; a = a or 1

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r,
                g = g,
                b = b,
                hasOpacity = hasAlpha,
                opacity    = hasAlpha and a or nil,
                swatchFunc = function()
                    local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                    local na = hasAlpha and ColorPickerFrame:GetColorAlpha() or 1
                    if set then set(nr, ng, nb, na) end
                    UpdateSwatch()
                end,
                cancelFunc = function()
                    if set then set(r, g, b, a) end
                    UpdateSwatch()
                end,
            })
        else
            ColorPickerFrame.func       = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = hasAlpha and (1 - OpacitySliderFrame:GetValue()) or 1
                if set then set(nr, ng, nb, na) end; UpdateSwatch()
            end
            ColorPickerFrame.cancelFunc = function()
                if set then set(r, g, b, a) end; UpdateSwatch()
            end
            ColorPickerFrame.hasOpacity = hasAlpha
            ColorPickerFrame.opacity    = hasAlpha and (1 - a) or nil
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame:Hide(); ColorPickerFrame:Show()
        end
    end)

    f.Refresh = UpdateSwatch
    return f, 38
end

-- ============================================================================
-- BUTTON — rellena la fila completa por defecto
-- ============================================================================
local function OpenMultiColorPicker(get, set, hasAlpha, onUpdate)
    local ok, r, g, b, a = pcall(get)
    if not ok then return end
    r, g, b, a = r or 1, g or 1, b or 1, a or 1
    local picker = ColorPickerFrame
    if not picker then return end
    if picker.SetFrameStrata then picker:SetFrameStrata("FULLSCREEN_DIALOG") end
    if picker.SetClampedToScreen then picker:SetClampedToScreen(true) end
    local function ApplyCurrent()
        local okColor, nr, ng, nb = pcall(picker.GetColorRGB, picker)
        if not okColor then return end
        local na = 1
        if hasAlpha and picker.GetColorAlpha then
            local okAlpha, value = pcall(picker.GetColorAlpha, picker)
            if okAlpha and value then na = value end
        end
        if set then pcall(set, nr or 1, ng or 1, nb or 1, na) end
        if onUpdate then onUpdate() end
    end
    local function RestoreOriginal()
        if set then pcall(set, r, g, b, a) end
        if onUpdate then onUpdate() end
    end
    if picker.SetupColorPickerAndShow then
        picker:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = hasAlpha == true,
            opacity = hasAlpha and a or nil,
            swatchFunc = ApplyCurrent,
            cancelFunc = RestoreOriginal,
        })
    else
        picker.func = ApplyCurrent
        picker.cancelFunc = RestoreOriginal
        picker.hasOpacity = hasAlpha == true
        picker.opacity = hasAlpha and (1 - a) or nil
        picker:SetColorRGB(r, g, b)
        picker:Hide()
        picker:Show()
    end
end

function W:MultiSwatch(parent, text, yOffset, swatches)
    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 36)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)
    MakeHoverFrame(f)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 12)
    label:SetText(LText(text or ""))
    do
        local mr, mg, mb = CurrentMutedColor()
        label:SetTextColor(mr, mg, mb, 1)
    end
    label:SetPoint("LEFT", 12, 0)

    local buttons = {}
    local size, gap = 20, 5
    for index, info in ipairs(swatches or {}) do
        local button = CreateFrame("Button", nil, f)
        button:SetSize(size, size)
        button:SetPoint("RIGHT", f, "RIGHT", -12 - ((index - 1) * (size + gap)), 0)
        button:SetFrameLevel(f:GetFrameLevel() + 5)
        if KT.AddBorder then KT:AddBorder(button, 0.35, 0.35, 0.35, 1) end
        local texture = button:CreateTexture(nil, "ARTWORK")
        texture:SetPoint("TOPLEFT", 1, -1)
        texture:SetPoint("BOTTOMRIGHT", -1, 1)
        button._texture = texture
        button._info = info
        button:SetScript("OnClick", function(self)
            local spec = self._info
            OpenMultiColorPicker(spec.getValue, spec.setValue, spec.hasAlpha, function()
                local ok, r, g, b = pcall(spec.getValue)
                if ok and r then self._texture:SetColorTexture(r or 1, g or 1, b or 1, 1) end
            end)
        end)
        buttons[index] = button
    end

    local function Refresh()
        local reserved = (#buttons * size) + (math.max(0, #buttons - 1) * gap) + 24
        label:SetWidth(math.max(40, w - reserved - 12))
        for _, button in ipairs(buttons) do
            local spec = button._info
            local ok, r, g, b = pcall(spec.getValue)
            if ok then button._texture:SetColorTexture(r or 1, g or 1, b or 1, 1) end
            local disabled = spec.disabled
            if type(disabled) == "function" then
                local okDisabled, value = pcall(disabled)
                disabled = okDisabled and value or false
            end
            button:SetAlpha(disabled and 0.15 or 1)
            button:EnableMouse(not disabled)
        end
    end
    Refresh()
    f.Refresh = Refresh
    return f, 38
end
function W:Button(parent, text, yOffset, func, btnWidth, confirm, confirmText, align, btnHeight)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(FW(parent), 42)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)

    local btn = CreateFrame("Button", nil, f)
    btn:SetHeight(btnHeight or 32)

    if btnWidth and btnWidth ~= "FULL" then
        btn:SetWidth(btnWidth)
        if align == "CENTER" then
            btn:SetPoint("CENTER", f, "CENTER", 0, 0)
        else
            btn:SetPoint("LEFT", 12, 0)
        end
    else
        btn:SetPoint("LEFT", f, "LEFT", 12, 0)
        btn:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    end

    local function Apply9SliceSkin(btn)
        local visual = CreateFrame("Frame", nil, btn)
        visual:SetAllPoints()
        visual:SetFrameLevel(btn:GetFrameLevel() - 1)
        visual:SetClipsChildren(false)

        local tex = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\MenuButton.png"
        local minX = 12 / 601
        local maxX = 586 / 601
        local minY = 8 / 147
        local maxY = 136 / 147
        local cx = 8 / 601
        local cy = 8 / 147
        local cornerScreen = 4

        local slices = {}
        for i = 1, 9 do
            local t = visual:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(tex)
            slices[i] = t
        end
        local TL, TR, BL, BR, T, B, L, R, C = unpack(slices)

        TL:SetSize(cornerScreen, cornerScreen)
        TR:SetSize(cornerScreen, cornerScreen)
        BL:SetSize(cornerScreen, cornerScreen)
        BR:SetSize(cornerScreen, cornerScreen)
        
        TL:SetPoint("TOPLEFT")
        TR:SetPoint("TOPRIGHT")
        BL:SetPoint("BOTTOMLEFT")
        BR:SetPoint("BOTTOMRIGHT")

        T:SetPoint("TOPLEFT", TL, "TOPRIGHT")
        T:SetPoint("BOTTOMRIGHT", TR, "BOTTOMLEFT")
        B:SetPoint("TOPLEFT", BL, "TOPRIGHT")
        B:SetPoint("BOTTOMRIGHT", BR, "BOTTOMLEFT")
        L:SetPoint("TOPLEFT", TL, "BOTTOMLEFT")
        L:SetPoint("BOTTOMRIGHT", BL, "TOPRIGHT")
        R:SetPoint("TOPLEFT", TR, "BOTTOMLEFT")
        R:SetPoint("BOTTOMRIGHT", BR, "TOPRIGHT")
        C:SetPoint("TOPLEFT", TL, "BOTTOMRIGHT")
        C:SetPoint("BOTTOMRIGHT", BR, "TOPLEFT")

        TL:SetTexCoord(minX, minX + cx, minY, minY + cy)
        TR:SetTexCoord(maxX - cx, maxX, minY, minY + cy)
        BL:SetTexCoord(minX, minX + cx, maxY - cy, maxY)
        BR:SetTexCoord(maxX - cx, maxX, maxY - cy, maxY)
        T:SetTexCoord(minX + cx, maxX - cx, minY, minY + cy)
        B:SetTexCoord(minX + cx, maxX - cx, maxY - cy, maxY)
        L:SetTexCoord(minX, minX + cx, minY + cy, maxY - cy)
        R:SetTexCoord(maxX - cx, maxX, minY + cy, maxY - cy)
        C:SetTexCoord(minX + cx, maxX - cx, minY + cy, maxY - cy)

        btn.slices = slices
    end

    Apply9SliceSkin(btn)
    
    do
        local ar, ag, ab = CurrentAccentColor()
        for _, t in ipairs(btn.slices) do
            t:SetVertexColor(ar, ag, ab, 0.5)
        end
    end

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(CurrentFont(), 11, "OUTLINE")
    lbl:SetText(LText(text))
    do
        local tr, tg, tb = CurrentTextColor()
        lbl:SetTextColor(tr, tg, tb, 1)
    end
    lbl:SetAllPoints(); lbl:SetJustifyH("CENTER"); lbl:SetJustifyV("MIDDLE")

    btn:SetScript("OnEnter", function(self)
        local ar, ag, ab = CurrentAccentColor()
        for _, t in ipairs(self.slices) do
            t:SetVertexColor(ar, ag, ab, 1)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        local ar, ag, ab = CurrentAccentColor()
        for _, t in ipairs(self.slices) do
            t:SetVertexColor(ar, ag, ab, 0.5)
        end
    end)
    btn:SetScript("OnClick", function()
        if confirm then
            StaticPopupDialogs["KT_CONFIRM_ACTION"] = {
                text = LText(confirmText or "Are you sure?"),
                button1 = LText("Yes"),
                button2 = LText("No"),
                OnAccept = func,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
            }
            StaticPopup_Show("KT_CONFIRM_ACTION")
        else
            if func then func() end
        end
    end)

    return f, 44
end

function W:SubTabBar(parent, yOffset, tabs, selectedId, onSelect)
    if KT and KT.AddOptionsSubTabBar then
        return KT.AddOptionsSubTabBar(parent, yOffset, tabs, selectedId, onSelect)
    end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(parent:GetWidth() - 20, 44)
    frame:SetPoint("TOPLEFT", 10, yOffset)
    return frame, 50
end
-- ============================================================================
-- INPUT (SEGURO CONTRA CRASHEOS DE SETFONT)
-- ============================================================================
function W:Input(parent, text, yOffset, get, set, opts)
    local w = FW(parent)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(w, 48)
    f:SetPoint("TOPLEFT", 10, yOffset)
    RowBg(f, parent)

    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetFont(CurrentFont(), 11)
    label:SetText(LText(text))
    do
        local mr, mg, mb = CurrentMutedColor()
        label:SetTextColor(mr, mg, mb, 1)
    end
    label:SetPoint("TOPLEFT", 12, -4)

    local box = CreateFrame("EditBox", nil, f)
    box:SetHeight(22)
    box:SetPoint("BOTTOMLEFT", 12, 4)
    box:SetPoint("BOTTOMRIGHT", -12, 4)
    -- FIX: pcall for SetFont to prevent library crash if font string is invalid
    pcall(function() box:SetFont(CurrentFont(), 11, "") end)
    do
        local tr, tg, tb = CurrentTextColor()
        box:SetTextColor(tr, tg, tb, 1)
    end
    box:SetAutoFocus(false)
    KT:AddBackdrop(box, 0.06, 0.06, 0.08, 1)
    KT:AddBorder(box, 0.20, 0.20, 0.25, 1)
    box:SetTextInsets(4, 4, 2, 2)

    local lastCommittedValue = get and get() or ""
    box:SetText(lastCommittedValue)

    local function CommitValue(self)
        local value = self:GetText() or ""
        if value == lastCommittedValue then
            return
        end
        lastCommittedValue = value
        if set then
            set(value)
        end
    end

    if opts and opts.commitOnTextChanged then
        box:SetScript("OnTextChanged", function(self)
            CommitValue(self)
        end)
    end

    box:SetScript("OnEnterPressed", function(self)
        CommitValue(self)
        self:ClearFocus()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:SetText(lastCommittedValue)
        self:ClearFocus()
    end)
    box:SetScript("OnEditFocusGained", function(self)
        local ar, ag, ab = CurrentAccentColor()
        KT:AddBorder(self, ar, ag, ab, 0.8)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        CommitValue(self)
        KT:AddBorder(self, 0.20, 0.20, 0.25, 1)
    end)

    f.Refresh = function()
        lastCommittedValue = get and get() or ""
        box:SetText(lastCommittedValue)
    end
    return f, 52
end

-- ============================================================================
-- DUAL ROW (Two columns)
-- ============================================================================
function W:DualRow(parent, yOffset, leftData, rightData)
    local fullW = parent:GetWidth()
    local gap = 10
    local itemW = (fullW - 20 - gap) / 2

    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(fullW, 40)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOffset)

    local leftC = CreateFrame("Frame", nil, row)
    leftC:SetSize(itemW + 20, 40)
    leftC:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)

    local rightC = CreateFrame("Frame", nil, row)
    rightC:SetSize(itemW + 20, 40)
    rightC:SetPoint("TOPLEFT", row, "TOPLEFT", itemW + gap, 0)

    local function Create(p, d)
        if not d then return 0 end
        local ctrl, h = nil, 0
        if d.type == "toggle" then
            ctrl, h = W:Toggle(p, d.text, 0, d.getValue, d.setValue)
        elseif d.type == "slider" then
            ctrl, h = W:Slider(p, d.text, 0, d.getValue, d.setValue, d.min, d.max, d.step, d.fmt, d.sliderOptions)
        elseif d.type == "dropdown" then
            ctrl, h = W:Dropdown(p, d.text, 0, d.values, d.getValue, d.setValue, d.order,
                d.preview or d.fontPreview)
        elseif d.type == "colorpicker" then
            ctrl, h = W:ColorSwatch(p, d.text, 0, d.getValue, d.setValue, d.hasAlpha)
        elseif d.type == "multiSwatch" then
            ctrl, h = W:MultiSwatch(p, d.text, 0, d.swatches)
        elseif d.type == "button" then
            ctrl, h = W:Button(p, d.text, 0, d.onClick, nil, nil, nil, "CENTER")
        end
        p._control = ctrl
        return h
    end

    local h1 = Create(leftC, leftData)
    local h2 = Create(rightC, rightData)
    local maxH = math.max(h1, h2)

    row:SetHeight(maxH)
    leftC:SetHeight(maxH)
    rightC:SetHeight(maxH)

    row._leftRegion = leftC
    row._rightRegion = rightC

    return row, maxH
end
