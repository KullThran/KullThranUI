-------------------------------------------------------------------------------
-- Aura Reminders options page inside the main KullThranUI settings panel.
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...
local KT = (ns and ns.KT) or LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
if not KT then return end

local PAGE_CONTROL     = "Control Center"
local PAGE_GROUP       = "Group Readiness"
local PAGE_CLASS       = "Class Upkeep"
local PAGE_CONSUMABLES = "Consumable Loadout"
local PAGE_TALENTS     = "Talent Reminders"
local PAGE_CUSTOM_AURAS = "Custom Auras"

local function AccentColorCode()
    local r, g, b = 1, 0, 0.3333333333
    if KT and KT.GetStyleAccentRGB then
        r, g, b = KT:GetStyleAccentRGB()
    end
    local function channel(value)
        return math.floor(math.max(0, math.min(1, tonumber(value) or 0)) * 255 + 0.5)
    end
    return string.format("|cff%02x%02x%02x", channel(r), channel(g), channel(b))
end

local SECTION_DISPLAY      = "LOOK & PLACEMENT"
local SECTION_RAID_BUFFS   = "GROUP COVERAGE"
local SECTION_AURAS        = "ASSIGNED & PERSONAL AURAS"
local SECTION_CONSUMABLES  = "LOADOUT CHECKLIST"
local SECTION_ROGUE        = "ROGUE PREPARATION"
local SECTION_PALADIN      = "PALADIN PREPARATION"
local SECTION_SHAMAN       = "SHAMAN PREPARATION"

KT.PanelPP = KT.PanelPP or KT.PP
KT.COGS_ICON = KT.COGS_ICON or "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\cogs.png"
KT.DIRECTIONS_ICON = KT.DIRECTIONS_ICON or "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\right_arrow.png"
KT.DARK_BG = KT.DARK_BG or { r = 0.05, g = 0.07, b = 0.09 }
KT.KUI_ACCENT = KT.KUI_ACCENT or setmetatable({}, {
    __index = function(_, key)
        local r, g, b
        if KT and KT.GetStyleAccentRGB then
            r, g, b = KT:GetStyleAccentRGB()
        else
            r, g, b = KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333
        end
        if key == "r" then return r end
        if key == "g" then return g end
        if key == "b" then return b end
        if key == "a" then return 1 end
        return nil
    end,
})
KT.TEXT_SECTION_R = KT.TEXT_SECTION_R or 0.45
KT.TEXT_SECTION_G = KT.TEXT_SECTION_G or 0.50
KT.TEXT_SECTION_B = KT.TEXT_SECTION_B or 0.55
KT.TEXT_SECTION_A = KT.TEXT_SECTION_A or 1
KT.lerp = KT.lerp or function(a, b, t) return a + ((b - a) * (t or 0)) end
KT.GetFontPath = KT.GetFontPath or function() return KT.FONT_PATH or "Fonts\\FRIZQT__.TTF" end
KT.GetFontOutlineFlag = KT.GetFontOutlineFlag or function() return "OUTLINE" end
KT.GetFontUseShadow = KT.GetFontUseShadow or function() return true end

local _kuiARPageState = {
    selectedPage = PAGE_CONTROL,
    content = nil,
    headerHost = nil,
    headerHeight = 0,
    headerBuilder = nil,
    refreshers = {},
}

local function RunPageRefreshers()
    for _, fn in ipairs(_kuiARPageState.refreshers) do
        if type(fn) == "function" then
            pcall(fn)
        end
    end
end

KT.RegisterWidgetRefresh = KT.RegisterWidgetRefresh or function(fn)
    if type(fn) ~= "function" then return end
    _kuiARPageState.refreshers[#_kuiARPageState.refreshers + 1] = fn
end

KT.ShowWidgetTooltip = KT.ShowWidgetTooltip or function(owner, text)
    if not owner or not text then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

KT.HideWidgetTooltip = KT.HideWidgetTooltip or function()
    GameTooltip:Hide()
end

KT.DisabledTooltip = KT.DisabledTooltip or function(reason)
    return "|cffff4444Disabled:|r requires " .. (reason or "another option")
end

KT.RowBg = KT.RowBg or function(frame, parent)
    if not parent.rowCounter then parent.rowCounter = 0 end
    parent.rowCounter = parent.rowCounter + 1
    local alpha = (parent.rowCounter % 2 == 0) and 0.05 or 0.02
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, alpha)
end

KT.BuildColorSwatch = KT.BuildColorSwatch or function(parent, level, getColor, setColor, _, size)
    size = size or 20
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button:SetFrameLevel(level or (parent:GetFrameLevel() + 1))
    KT:AddBackdrop(button, 0.08, 0.08, 0.11, 1)
    KT:AddBorder(button, 0.20, 0.20, 0.25, 1)

    local tex = button:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 2, -2)
    tex:SetPoint("BOTTOMRIGHT", -2, 2)

    local function UpdateSwatch()
        local r, g, b = getColor()
        tex:SetColorTexture(r or 1, g or 1, b or 1, 1)
    end

    UpdateSwatch()
    button:SetScript("OnClick", function()
        ColorPickerFrame:SetupColorPickerAndShow({
            r = select(1, getColor()),
            g = select(2, getColor()),
            b = select(3, getColor()),
            hasOpacity = false,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                setColor(r, g, b)
                UpdateSwatch()
            end,
            cancelFunc = function(prev)
                if prev then
                    setColor(prev.r, prev.g, prev.b)
                end
                UpdateSwatch()
            end,
        })
    end)

    return button, UpdateSwatch
end

if not KT.BuildCogPopup then
    function KT.BuildCogPopup(opts)
        opts = opts or {}
        local rows = opts.rows or {}

        local popup = CreateFrame("Frame", nil, UIParent)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetClampedToScreen(true)
        popup:Hide()
        KT:AddBackdrop(popup, 0.04, 0.04, 0.05, 0.98)
        KT:AddBorder(popup, 0, 0, 0, 1)

        local title = popup:CreateFontString(nil, "OVERLAY")
        title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        title:SetTextColor(1, 1, 1, 1)
        title:SetPoint("TOPLEFT", 10, -10)
        title:SetText(opts.title or "")

        local controls = {}
        local y = -32
        for _, row in ipairs(rows) do
            if row.type == "slider" then
                local label = popup:CreateFontString(nil, "OVERLAY")
                label:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
                label:SetTextColor(1, 1, 1, 0.85)
                label:SetPoint("TOPLEFT", 10, y)
                label:SetText(row.label or "")

                local slider = CreateFrame("Slider", nil, popup, "MinimalSliderTemplate")
                slider:SetPoint("TOPLEFT", 10, y - 18)
                slider:SetPoint("TOPRIGHT", -10, y - 18)
                slider:SetHeight(16)
                slider:SetMinMaxValues(row.min or 0, row.max or 1)
                slider:SetValueStep(row.step or 0.1)
                if slider.SetObeyStepOnDrag then
                    slider:SetObeyStepOnDrag(true)
                end

                local valueFS = popup:CreateFontString(nil, "OVERLAY")
                valueFS:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
                valueFS:SetTextColor(1, 1, 1, 0.5)
                valueFS:SetPoint("TOPRIGHT", -10, y)

                slider:SetScript("OnValueChanged", function(_, value)
                    if row.set then row.set(value) end
                    valueFS:SetText(type(value) == "number" and string.format("%.2f", value):gsub("%.?0+$", "") or tostring(value))
                end)

                controls[#controls + 1] = { kind = "slider", slider = slider, value = valueFS, row = row }
                y = y - 48
            end
        end

        popup:SetSize(math.max(220, opts.width or 260), math.max(70, -y + 10))

        local function RefreshControls()
            for _, control in ipairs(controls) do
                if control.kind == "slider" then
                    local value = control.row.get and control.row.get() or 0
                    control.slider:SetValue(value)
                    control.value:SetText(type(value) == "number" and string.format("%.2f", value):gsub("%.?0+$", "") or tostring(value))
                end
            end
        end

        local closer = CreateFrame("Frame", nil, UIParent)
        closer:SetAllPoints()
        closer:SetFrameStrata("FULLSCREEN_DIALOG")
        closer:EnableMouse(true)
        closer:Hide()
        closer:SetScript("OnMouseDown", function()
            popup:Hide()
            closer:Hide()
        end)

        popup:SetScript("OnHide", function() closer:Hide() end)

        local function Show(anchor)
            RefreshControls()
            popup:ClearAllPoints()
            if anchor then
                popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
            else
                popup:SetPoint("CENTER")
            end
            closer:Show()
            popup:Show()
        end

        return popup, Show
    end
end

KT.MakeDropdownArrow = KT.MakeDropdownArrow or function(parent, size)
    local tex = parent:CreateTexture(nil, "OVERLAY")
    tex:SetSize(size or 14, size or 14)
    tex:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\downarrow.png")
    tex:SetPoint("RIGHT", parent, "RIGHT", -8, 0)
    KT:SetAccentVertexColor(tex, 1)
    return tex
end

KT.BuildDropdownControl = KT.BuildDropdownControl or function(parent, width, frameLevel, values, order, getter, setter, options)
    options = options or {}
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 200, 30)
    button:SetFrameLevel(frameLevel or (parent:GetFrameLevel() + 1))
    KT:AddBackdrop(button, 0.075, 0.113, 0.141, 0.9)
    KT:AddBorder(button, 1, 1, 1, 0.20)

    local selectedIcon = button:CreateTexture(nil, "ARTWORK")
    selectedIcon:SetSize(options.iconSize or 18, options.iconSize or 18)
    selectedIcon:SetPoint("LEFT", button, "LEFT", 7, 0)
    selectedIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    selectedIcon:Hide()

    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 13, KT.GetFontOutlineFlag())
    label:SetTextColor(1, 1, 1, 0.50)
    label:SetPoint("RIGHT", button, "RIGHT", -28, 0)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetMaxLines(1)

    local arrow = KT.MakeDropdownArrow(button, 14)

    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(1000)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:Hide()
    KT:AddBackdrop(popup, 0.10, 0.10, 0.12, 0.97)
    KT:AddBorder(popup, 1, 1, 1, 0.12)

    local scrollFrame = CreateFrame("ScrollFrame", nil, popup)
    scrollFrame:SetFrameLevel(popup:GetFrameLevel() + 1)
    scrollFrame:SetPoint("TOPLEFT", 1, -1)
    scrollFrame:SetPoint("BOTTOMRIGHT", -1, 1)
    scrollFrame:EnableMouse(true)

    local child = CreateFrame("Frame", nil, scrollFrame)
    child:SetFrameLevel(popup:GetFrameLevel() + 2)
    scrollFrame:SetScrollChild(child)
    child:EnableMouse(true)

    local scrollBar = CreateFrame("Slider", nil, popup)
    scrollBar:SetFrameLevel(popup:GetFrameLevel() + 4)
    scrollBar:SetOrientation("VERTICAL")
    scrollBar:SetWidth(10)
    scrollBar:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -4)
    scrollBar:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -2, 4)
    scrollBar:SetValueStep(options.rowHeight or 24)
    if scrollBar.SetObeyStepOnDrag then scrollBar:SetObeyStepOnDrag(false) end

    local scrollTrack = scrollBar:CreateTexture(nil, "BACKGROUND")
    scrollTrack:SetPoint("TOP", 0, 0)
    scrollTrack:SetPoint("BOTTOM", 0, 0)
    scrollTrack:SetWidth(2)
    scrollTrack:SetColorTexture(1, 1, 1, 0.10)

    scrollBar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local scrollThumb = scrollBar:GetThumbTexture()
    scrollThumb:SetSize(8, 28)
    KT:SetAccentTexture(scrollThumb, 0.85)
    local popupMaxScroll = 0
    local function SetPopupScroll(value, syncSlider)
        value = math.max(0, math.min(popupMaxScroll, tonumber(value) or 0))
        scrollFrame:SetVerticalScroll(value)
        if syncSlider and scrollBar:GetValue() ~= value then
            scrollBar:SetValue(value)
        end
    end
    scrollBar:SetScript("OnValueChanged", function(_, value)
        SetPopupScroll(value, false)
    end)
    scrollBar:Hide()

    local function GetTextForValue(value)
        local source = values or {}
        return source[value] or source[tostring(value)] or tostring(value or "")
    end

    local function RefreshLabel()
        local value = getter and getter() or nil
        label:SetText(GetTextForValue(value))
        local icon = options.getIcon and options.getIcon(value)
        label:ClearAllPoints()
        if icon then
            selectedIcon:SetTexture(icon)
            selectedIcon:Show()
            label:SetPoint("LEFT", selectedIcon, "RIGHT", 6, 0)
        else
            selectedIcon:Hide()
            label:SetPoint("LEFT", button, "LEFT", 14, 0)
        end
        label:SetPoint("RIGHT", button, "RIGHT", -28, 0)
    end

    local function ScrollBy(delta)
        if not scrollBar:IsShown() then return end
        local current = scrollFrame:GetVerticalScroll() or 0
        local step = (options.rowHeight or 24) * 3
        SetPopupScroll(current - ((delta or 0) * step), true)
    end

    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)
    child:EnableMouseWheel(true)
    child:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)

    local function BuildPopup()
        for _, frame in ipairs({ child:GetChildren() }) do
            frame:Hide()
            frame:SetParent(UIParent)
        end

        local entries = {}
        if order then
            for _, key in ipairs(order) do
                entries[#entries + 1] = { key = key, label = GetTextForValue(key) }
            end
        else
            for key, value in pairs(values or {}) do
                entries[#entries + 1] = { key = key, label = value }
            end
            table.sort(entries, function(a, b) return tostring(a.label) < tostring(b.label) end)
        end

        local rowH = options.rowHeight or 24
        local totalH = 0
        for index, entry in ipairs(entries) do
            local item = CreateFrame("Button", nil, child)
            item:SetFrameLevel(popup:GetFrameLevel() + 3)
            item:SetHeight(rowH)
            item:SetPoint("TOPLEFT", 0, -((index - 1) * rowH))
            item:SetPoint("TOPRIGHT", 0, -((index - 1) * rowH))

            local bg = item:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(0, 0, 0, 0)

            local icon = item:CreateTexture(nil, "ARTWORK")
            local iconTexture = options.getIcon and options.getIcon(entry.key)
            if iconTexture then
                local iconSize = options.iconSize or 18
                icon:SetSize(iconSize, iconSize)
                icon:SetPoint("LEFT", item, "LEFT", 5, 0)
                icon:SetTexture(iconTexture)
                icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                icon:Show()
            else
                icon:Hide()
            end

            local text = item:CreateFontString(nil, "OVERLAY")
            text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "")
            text:SetTextColor(0.88, 0.88, 0.88, 1)
            if iconTexture then
                text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
            else
                text:SetPoint("LEFT", 8, 0)
            end
            text:SetPoint("RIGHT", -8, 0)
            text:SetJustifyH("LEFT")
            text:SetText(entry.label)

            item:SetScript("OnEnter", function() KT:SetAccentTexture(bg, 0.18) end)
            item:SetScript("OnLeave", function() bg:SetColorTexture(0, 0, 0, 0) end)
            item:EnableMouseWheel(true)
            item:SetScript("OnMouseWheel", function(_, delta) ScrollBy(delta) end)
            item:SetScript("OnClick", function()
                if setter then setter(entry.key) end
                RefreshLabel()
                popup:Hide()
            end)

            totalH = totalH + rowH
        end

        local visibleRows = math.min(#entries, options.maxVisibleRows or #entries)
        local viewportH = math.max(rowH, visibleRows * rowH)
        local hasOverflow = totalH > viewportH
        local rightInset = hasOverflow and 13 or 1

        scrollFrame:ClearAllPoints()
        scrollFrame:SetPoint("TOPLEFT", popup, "TOPLEFT", 1, -1)
        scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -rightInset, 1)
        child:SetSize(button:GetWidth() - rightInset - 1, math.max(totalH, viewportH))
        popup:SetSize(button:GetWidth(), viewportH + 2)

        popupMaxScroll = math.max(0, totalH - viewportH)
        scrollBar:SetMinMaxValues(0, popupMaxScroll)
        SetPopupScroll(0, true)
        scrollBar:SetShown(hasOverflow)
    end

    button:SetScript("OnClick", function()
        if popup:IsShown() then
            popup:Hide()
            return
        end

        BuildPopup()
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
        popup:Show()
    end)

    button.Refresh = RefreshLabel
    RefreshLabel()
    return button, label, arrow
end

KT.ShowInputPopup = KT.ShowInputPopup or function(opts)
    opts = opts or {}
    local popup = KT._kuiAuraRemindersInputPopup
    if not popup then
        popup = CreateFrame("Frame", "KT_AuraRemindersInputPopup", UIParent)
        popup:SetFrameStrata("FULLSCREEN_DIALOG")
        popup:SetSize(420, 220)
        popup:SetPoint("CENTER")
        popup:Hide()
        KT:AddBackdrop(popup, 0.04, 0.04, 0.05, 0.98)
        KT:AddBorder(popup, 0, 0, 0, 1)

        popup.title = popup:CreateFontString(nil, "OVERLAY")
        popup.title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        popup.title:SetTextColor(1, 1, 1, 1)
        popup.title:SetPoint("TOPLEFT", 14, -14)

        popup.message = popup:CreateFontString(nil, "OVERLAY")
        popup.message:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "")
        popup.message:SetTextColor(0.82, 0.82, 0.82, 1)
        popup.message:SetJustifyH("LEFT")
        popup.message:SetJustifyV("TOP")
        popup.message:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -10)
        popup.message:SetPoint("TOPRIGHT", -14, -40)

        popup.editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
        popup.editBox:SetAutoFocus(false)
        popup.editBox:SetHeight(24)
        popup.editBox:SetPoint("TOPLEFT", popup.message, "BOTTOMLEFT", 0, -12)
        popup.editBox:SetPoint("TOPRIGHT", -14, -84)
        popup.editBox:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "")
        popup.editBox:SetTextInsets(4, 4, 4, 4)

        popup.confirm = CreateFrame("Button", nil, popup)
        popup.confirm:SetSize(110, 28)
        popup.confirm:SetPoint("BOTTOMRIGHT", -14, 14)
        KT:AddBackdrop(popup.confirm, 0.08, 0.08, 0.11, 1)
        KT:AddAccentBorder(popup.confirm, 0.7)
        popup.confirm.text = popup.confirm:CreateFontString(nil, "OVERLAY")
        popup.confirm.text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        popup.confirm.text:SetTextColor(1, 1, 1, 1)
        popup.confirm.text:SetAllPoints()

        popup.extra = CreateFrame("Button", nil, popup)
        popup.extra:SetSize(130, 28)
        popup.extra:SetPoint("RIGHT", popup.confirm, "LEFT", -8, 0)
        KT:AddBackdrop(popup.extra, 0.08, 0.08, 0.11, 1)
        KT:AddBorder(popup.extra, 0.35, 0.35, 0.35, 0.7)
        popup.extra.text = popup.extra:CreateFontString(nil, "OVERLAY")
        popup.extra.text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        popup.extra.text:SetTextColor(1, 1, 1, 1)
        popup.extra.text:SetAllPoints()

        popup.cancel = CreateFrame("Button", nil, popup)
        popup.cancel:SetSize(90, 28)
        popup.cancel:SetPoint("RIGHT", popup.extra, "LEFT", -8, 0)
        KT:AddBackdrop(popup.cancel, 0.08, 0.08, 0.11, 1)
        KT:AddBorder(popup.cancel, 0.35, 0.35, 0.35, 0.7)
        popup.cancel.text = popup.cancel:CreateFontString(nil, "OVERLAY")
        popup.cancel.text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        popup.cancel.text:SetTextColor(1, 1, 1, 1)
        popup.cancel.text:SetAllPoints()
        popup.cancel.text:SetText(LText("Cancel"))
        popup.cancel:SetScript("OnClick", function() popup:Hide() end)

        KT._kuiAuraRemindersInputPopup = popup
    end

    popup.title:SetText(opts.title or "")
    popup.message:SetText(opts.message or "")
    popup.editBox:SetText(opts.initialText or "")
    popup.confirm.text:SetText(opts.confirmText or "Save")
    popup.confirm:SetScript("OnClick", function()
        if opts.onConfirm then
            opts.onConfirm(popup.editBox:GetText())
        end
        popup:Hide()
    end)

    if opts.extraButton then
        popup.extra:Show()
        popup.extra.text:SetText(opts.extraButton.text or "Extra")
        popup.extra:SetScript("OnClick", function()
            if opts.extraButton.onClick then
                opts.extraButton.onClick(popup.editBox)
            end
        end)
    else
        popup.extra:Hide()
    end

    popup:Show()
    popup.editBox:SetFocus()
    popup.editBox:HighlightText()
end

KT.SetContentHeader = function(selfOrBuilder, maybeBuilder)
    local builder = maybeBuilder
    if type(selfOrBuilder) == "function" or selfOrBuilder == nil then
        builder = selfOrBuilder
    end

    _kuiARPageState.headerBuilder = builder
    local host = _kuiARPageState.headerHost
    if not host then return end

    for _, child in ipairs({ host:GetChildren() }) do
        child:Hide()
        child:SetParent(UIParent)
    end

    if type(builder) ~= "function" then
        host:Hide()
        _kuiARPageState.headerHeight = 0
        if _kuiARPageState.content then
            _kuiARPageState.content:ClearAllPoints()
            _kuiARPageState.content:SetPoint("TOPLEFT", host:GetParent(), "TOPLEFT", 0, _kuiARPageState.content._baseYOffset or 0)
            _kuiARPageState.content:SetPoint("TOPRIGHT", host:GetParent(), "TOPRIGHT", 0, _kuiARPageState.content._baseYOffset or 0)
        end
        return
    end

    local width = host:GetParent():GetWidth()
    local height = builder(host, width) or 0
    _kuiARPageState.headerHeight = height
    host:SetHeight(height)
    host:Show()

    if _kuiARPageState.content then
        _kuiARPageState.content:ClearAllPoints()
        _kuiARPageState.content:SetPoint("TOPLEFT", host, "BOTTOMLEFT", 0, -10)
        _kuiARPageState.content:SetPoint("TOPRIGHT", host, "BOTTOMRIGHT", 0, -10)
    end
end

KT.SetContentHeaderHeightSilent = function(selfOrHeight, maybeHeight)
    local height = maybeHeight
    if type(selfOrHeight) == "number" or selfOrHeight == nil then
        height = selfOrHeight
    end

    local host = _kuiARPageState.headerHost
    if not host then return end
    _kuiARPageState.headerHeight = height or 0
    host:SetHeight(_kuiARPageState.headerHeight)
    if _kuiARPageState.headerHeight > 0 then
        host:Show()
    else
        host:Hide()
    end
end

if not KT.RegisterModule then
    function KT:RegisterModule(id, def)
        local pageId = "aurareminders"
        local label = LText("Aura Reminders")
        local order = 15

        self:RegisterPage(pageId, label, order, function(sc, W)
            _kuiARPageState.refreshers = {}
            _kuiARPageState.selectedPage = _kuiARPageState.selectedPage or (def.pages and def.pages[1]) or PAGE_CONTROL

            local y = 0
            if self.AddOptionsSubTabBar and def.pages and #def.pages > 1 then
                local tabs = {}
                for _, pageName in ipairs(def.pages) do
                    tabs[#tabs + 1] = { id = pageName, label = LText(pageName) }
                end
                local _, tabH = self.AddOptionsSubTabBar(sc, y, tabs, _kuiARPageState.selectedPage, function(tabId)
                    _kuiARPageState.selectedPage = tabId
                    self:RefreshPage()
                end)
                y = y - tabH
            end

            local headerHost = CreateFrame("Frame", nil, sc)
            headerHost:SetWidth(sc:GetWidth())
            headerHost:SetHeight(1)
            headerHost:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, y)
            headerHost:Hide()

            local content = CreateFrame("Frame", nil, sc)
            content:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, y)
            content:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, y)
            content:SetHeight(1)
            content._baseYOffset = y

            _kuiARPageState.headerHost = headerHost
            _kuiARPageState.content = content
            _kuiARPageState.headerHeight = 0

            if def.getHeaderBuilder then
                KT.SetContentHeader(def.getHeaderBuilder(_kuiARPageState.selectedPage))
            else
                KT.SetContentHeader(nil)
            end

            local contentHeight = 0
            if def.buildPage then
                contentHeight = def.buildPage(_kuiARPageState.selectedPage, content, 0) or 0
            end

            C_Timer.After(0, RunPageRefreshers)
            if def.onPageCacheRestore then
                C_Timer.After(0, function()
                    def.onPageCacheRestore(_kuiARPageState.selectedPage)
                end)
            end
            if def.onShow then
                C_Timer.After(0, def.onShow)
            end

            return math.max(1, math.abs(y) + (_kuiARPageState.headerHeight or 0) + contentHeight + 40)
        end)
    end
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")

    if not KT or not KT.RegisterModule then return end
    local PP = KT.PP

    local function GetABROptOutline()
        return (KT and KT.GetFontOutlineFlag and KT.GetFontOutlineFlag()) or "OUTLINE"
    end
    local function SetPVFont(fs, font, size)
        if not (fs and fs.SetFont) then return end
        local f = GetABROptOutline()
        fs:SetFont(font, size, f)
        if f == "" then fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 1)
        else fs:SetShadowOffset(0, 0) end
    end

    ---------------------------------------------------------------------------
    --  DB helpers
    ---------------------------------------------------------------------------
    local db
    C_Timer.After(0, function() db = _G._KUIAR_AceDB end)

    local function DB()
        if not db then db = _G._KUIAR_AceDB end
        return db and db.profile
    end
    local function DDB()  local p = DB(); return p and p.display end
    local function RDB()  local p = DB(); return p and p.raidBuffs end
    local function ADB()  local p = DB(); return p and p.auras end
    local function CDB()  local p = DB(); return p and p.consumables end

    ---------------------------------------------------------------------------
    --  Refresh
    ---------------------------------------------------------------------------
    local function RefreshAll()
        if _G._KUIAR_RequestRefresh then _G._KUIAR_RequestRefresh() end
    end

    ---------------------------------------------------------------------------
    --  Preview Header shows potential buff/aura icons for current class/spec
    ---------------------------------------------------------------------------
    local _previewHeaderBuilder
    local _previewIcons = {}
    local _previewContainer
    local _previewHintFS

    local function IsPreviewHintDismissed()
        local profile = DB()
        return profile and profile.previewHintDismissed == true
    end

    local Known = function(id) return id and (IsPlayerSpell(id) or IsSpellKnown(id)) end
    local Tex = function(id) return _G._KUIAR_Tex and _G._KUIAR_Tex(id) or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400 end
    local ItemTex = function(itemID, fallback)
        return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)) or fallback or 134400
    end

    --- Shorten a buff/aura label to its first word, with special overrides.
    local LABEL_OVERRIDES = {
        ["Defensive Stance"]        = "Stance",
        ["Berserker Stance"]        = "Stance",
        ["Devotion Aura"]           = "Aura",
        ["Power Word: Fortitude"]   = "Fortitude",
        ["Arcane Intellect"]        = "Intellect",
        ["Battle Shout"]            = "Shout",
    }
    local LABEL_CLASS_OVERRIDES = {
        ROGUE  = "Poison",   -- all rogue poisons
        SHAMAN_IMBUE  = "Weapon",  -- all shaman weapon imbues
        SHAMAN_SHIELD = "Shield",  -- all shaman shields
    }
    local function ShortLabel(name, classOverride, spellID)
        local localizedName = name
        if spellID then
            local spellInfo = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID)
            if spellInfo and spellInfo.name then localizedName = spellInfo.name end
        end
        if classOverride and LABEL_CLASS_OVERRIDES[classOverride] then
            return LText(LABEL_CLASS_OVERRIDES[classOverride])
        end
        local label = LABEL_OVERRIDES[name] or localizedName:match("^(%S+)") or localizedName
        return LText(label)
    end

    --- Collect all potential preview icons for the player's class/spec
    local function CollectPreviewIcons()
        local icons = {}
        local _, playerClass = UnitClass("player")
        local specIdx = GetSpecialization()
        local specID = specIdx and GetSpecializationInfo(specIdx) or nil
        local rb = RDB()
        local au = ADB()
        local co = CDB()

        -- 1) Raid buffs for this class (only enabled ones)
        local RAID_BUFFS = _G._KUIAR_RAID_BUFFS or {}
        for _, buff in ipairs(RAID_BUFFS) do
            if buff.class == playerClass and Known(buff.castSpell) then
                if rb and rb.enabled and rb.enabled[buff.key] then
                    icons[#icons+1] = { texture = Tex(buff.castSpell), label = ShortLabel(buff.name, nil, buff.castSpell), cat = "raidbuff", itemKey = buff.key }
                end
            end
        end

        -- 2) Auras valid for this class/spec (only enabled ones)
        local AURAS = _G._KUIAR_AURAS or {}
        local beaconAdded = false
        for _, aura in ipairs(AURAS) do
            if aura.class == playerClass and Known(aura.castSpell) then
                if au and au.enabled and au.enabled[aura.key] then
                    local specOk = true
                    if aura.specs then
                        specOk = false
                        for _, s in ipairs(aura.specs) do if s == specID then specOk = true; break end end
                    end
                    if specOk then
                        if aura.key == "bol" or aura.key == "bof" then
                            if not beaconAdded then
                                icons[#icons+1] = { texture = Tex(aura.castSpell), label = ShortLabel(aura.name, nil, aura.castSpell), cat = "aura", itemKey = aura.key }
                                beaconAdded = true
                            end
                        else
                            icons[#icons+1] = { texture = Tex(aura.castSpell), label = ShortLabel(aura.name, nil, aura.castSpell), cat = "aura", itemKey = aura.key }
                        end
                    end
                end
            end
        end

        -- 3) Consumables (only show enabled ones, one per type)
        -- Rogue poisons: show first enabled
        if playerClass == "ROGUE" then
            local POISONS = _G._KUIAR_ROGUE_POISONS or {}
            for _, poison in ipairs(POISONS) do
                if Known(poison.castSpell) and co and co.enabled and co.enabled[poison.key] then
                    icons[#icons+1] = { texture = Tex(poison.castSpell), label = ShortLabel(poison.name, "ROGUE", poison.castSpell), cat = "consumable", itemKey = poison.key }
                    break
                end
            end
        end

        -- Paladin rites: show first enabled
        if playerClass == "PALADIN" then
            local RITES = _G._KUIAR_PALADIN_RITES or {}
            for _, rite in ipairs(RITES) do
                if Known(rite.castSpell) and co and co.enabled and co.enabled[rite.key] then
                    icons[#icons+1] = { texture = Tex(rite.castSpell), label = ShortLabel(rite.name, nil, rite.castSpell), cat = "consumable", itemKey = rite.key }
                    break
                end
            end
        end

        -- Shaman imbues: show first enabled
        if playerClass == "SHAMAN" then
            local IMBUES = _G._KUIAR_SHAMAN_IMBUES or {}
            for _, imbue in ipairs(IMBUES) do
                if Known(imbue.castSpell) and co and co.enabled and co.enabled[imbue.key] then
                    icons[#icons+1] = { texture = Tex(imbue.castSpell), label = ShortLabel(imbue.name, "SHAMAN_IMBUE", imbue.castSpell), cat = "consumable", itemKey = imbue.key }
                    break
                end
            end
        end

        -- Weapon oil (if player doesn't have a class weapon imbue)
        if playerClass ~= "ROGUE" and playerClass ~= "PALADIN" and playerClass ~= "SHAMAN" then
            if co and co.enabled and co.enabled.weapon_enchant then
                icons[#icons+1] = { texture = ItemTex(243733, 7548987), label = LText("Weapon"), cat = "consumable", itemKey = "weapon_enchant" }
            end
        end

        -- Flask
        if co and co.enabled and co.enabled.flask then
            icons[#icons+1] = { texture = ItemTex(241326, 463530), label = LText("Flask"), cat = "consumable", itemKey = "flask" }
        end

        -- Food
        if co and co.enabled and co.enabled.food then
            icons[#icons+1] = { texture = 136000, label = LText("Food"), cat = "consumable", itemKey = "food" }
        end

        if (playerClass == "HUNTER" or playerClass == "WARLOCK") and co and co.enabled and co.enabled.pet then
            icons[#icons+1] = {
                texture = (playerClass == "WARLOCK") and 136218 or 132161,
                label = LText("Pet"),
                cat = "consumable",
                itemKey = "pet",
            }
        end

        return icons
    end

    local function UpdatePreviewHeader()
        if not _previewIcons or #_previewIcons == 0 then return end
        local d = DDB()
        if not d then return end
        local baseScale = d.scale or 1.0
        local ICON_SIZE = _G._KUIAR_ICON_SIZE or 40
        local sz = math.floor(ICON_SIZE * baseScale + 0.5)
        local spacing = d.iconSpacing or 8
        local glowType = d.glowType or 0
        local gc = d.glowColor or {r=1, g=0.776, b=0.376}
        local showText = d.showText
        local tc = d.textColor or {r=1, g=1, b=1}
        local opacity = d.opacity or 1.0
        local GT = _G._KUIAR_GLOW_TYPES
        local Stop = _G._KUIAR_StopAllGlows

        local count = #_previewIcons
        local totalW = (count * sz) + ((count - 1) * spacing)

        for i, pIcon in ipairs(_previewIcons) do
            local btn = pIcon.frame
            if not btn then break end
            btn:SetSize(sz, sz)
            btn:SetAlpha(opacity)
            btn:ClearAllPoints()
            local startX = -(totalW / 2) + (sz / 2)
            btn:SetPoint("TOP", btn:GetParent(), "TOP", startX + (i - 1) * (sz + spacing), 0)

            -- Glow
            if not btn._glowWrapper then
                local w = CreateFrame("Frame", nil, btn)
                w:SetAllPoints(btn); w:SetFrameLevel(btn:GetFrameLevel() + 1)
                btn._glowWrapper = w
            end
            if Stop then Stop(btn._glowWrapper) end

            if glowType > 0 and GT then
                local entry = GT[glowType]
                if entry then
                    if entry.procedural and _G._KUIAR_StartPixelGlow then
                        _G._KUIAR_StartPixelGlow(btn._glowWrapper, sz, gc.r, gc.g, gc.b)
                    elseif entry.buttonGlow and _G._KUIAR_StartButtonGlow then
                        _G._KUIAR_StartButtonGlow(btn._glowWrapper, sz, gc.r, gc.g, gc.b, 1.36)
                    elseif entry.autocast and _G._KUIAR_StartAutoCastShine then
                        _G._KUIAR_StartAutoCastShine(btn._glowWrapper, sz, gc.r, gc.g, gc.b, 1.0)
                    elseif _G._KUIAR_StartFlipBookGlow then
                        -- FlipBook glow (GCD, Modern WoW, Classic WoW) use shared live function
                        _G._KUIAR_StartFlipBookGlow(btn._glowWrapper, sz, entry, gc.r, gc.g, gc.b)
                    end
                    btn._glowWrapper:Show()
                end
            else
                btn._glowWrapper:Hide()
            end

            -- Text
            if showText then
                local fontPath = (KT and KT.GetFontPath and KT.GetFontPath("auraReminders")) or "Fonts\\ARIALN.TTF"
                local textSize = d and d.textSize or 11
                local textXOff = d and d.textXOffset or 0
                local textYOff = d and d.textYOffset or -2
                SetPVFont(btn._text, fontPath, textSize)
                btn._text:ClearAllPoints()
                btn._text:SetPoint("TOP", btn, "BOTTOM", textXOff, textYOff)
                btn._text:SetTextColor(tc.r, tc.g, tc.b, 1)
                btn._text:Show()
            else
                btn._text:Hide()
            end

            btn:Show()
        end

        -- Recalculate total preview height: hardcoded 80px
        do
            local textYOff2 = d.textYOffset or -2
            local textSz2 = d.textSize or 11
            local textOverhang2 = showText and (math.abs(textYOff2) + textSz2) or 0
            local CONTAINER_H = sz + textOverhang2
            if _previewContainer then
                _previewContainer:SetHeight(CONTAINER_H)
                _previewContainer:ClearAllPoints()
                _previewContainer:SetPoint("CENTER", _previewContainer:GetParent(), "CENTER", 0, 0)
            end
            local TOTAL_H = 80
            _kuiarHeaderBaseH = TOTAL_H
            local hintH = (_previewHintFS and _previewHintFS:IsShown()) and 35 or 0
            -- Use the silent variant so resizing the header never triggers
            -- scroll compensation (the height rarely changes here).
            KT:SetContentHeaderHeightSilent(TOTAL_H + hintH)
        end
    end

    ---------------------------------------------------------------------------
    --  Preview click-to-scroll infrastructure
    ---------------------------------------------------------------------------
    local _kuiarHeaderBaseH = 0

    --- Rebuild the preview header with scroll compensation.
    --- SetContentHeader tears down and rebuilds, which can cause scroll jumps.
    --- This wrapper saves the scroll position, rebuilds, then compensates.
    local function RebuildPreviewHeader()
        KT:SetContentHeader(_previewHeaderBuilder)
    end

    --- Lightweight relayout: reposition existing preview icons without
    --- tearing down and rebuilding the header (avoids scroll jumps).
    local function RelayoutPreviewIcons()
        if not _previewIcons or #_previewIcons == 0 then return end
        local d = DDB()
        local baseScale = d and d.scale or 1.0
        local ICON_SIZE = _G._KUIAR_ICON_SIZE or 40
        local sz = math.floor(ICON_SIZE * baseScale + 0.5)
        local spacing = d and d.iconSpacing or 8
        local count = #_previewIcons
        local totalW = (count * sz) + ((count - 1) * spacing)
        local startX = -(totalW / 2) + (sz / 2)
        for i, pIcon in ipairs(_previewIcons) do
            local btn = pIcon.frame
            if btn then
                btn:ClearAllPoints()
                btn:SetPoint("TOP", btn:GetParent(), "TOP", startX + (i - 1) * (sz + spacing), 0)
            end
        end
    end

    local _kuiarGlowFrame
    local _kuiarClickMappings = {}
    local _kuiarHitOverlays = {}

    local function KUIARPlaySettingGlow(targetFrame)
        if not targetFrame then return end
        if not _kuiarGlowFrame then
            _kuiarGlowFrame = CreateFrame("Frame")
            local c = KT.KUI_ACCENT
            local function MkEdge()
                local t = _kuiarGlowFrame:CreateTexture(nil, "OVERLAY", nil, 7)
                t:SetColorTexture(c.r, c.g, c.b, 1)
                return t
            end
            _kuiarGlowFrame._top = MkEdge()
            _kuiarGlowFrame._bot = MkEdge()
            _kuiarGlowFrame._lft = MkEdge()
            _kuiarGlowFrame._rgt = MkEdge()
            _kuiarGlowFrame._top:SetHeight(2)
            _kuiarGlowFrame._top:SetPoint("TOPLEFT"); _kuiarGlowFrame._top:SetPoint("TOPRIGHT")
            _kuiarGlowFrame._bot:SetHeight(2)
            _kuiarGlowFrame._bot:SetPoint("BOTTOMLEFT"); _kuiarGlowFrame._bot:SetPoint("BOTTOMRIGHT")
            _kuiarGlowFrame._lft:SetWidth(2)
            _kuiarGlowFrame._lft:SetPoint("TOPLEFT", _kuiarGlowFrame._top, "BOTTOMLEFT")
            _kuiarGlowFrame._lft:SetPoint("BOTTOMLEFT", _kuiarGlowFrame._bot, "TOPLEFT")
            _kuiarGlowFrame._rgt:SetWidth(2)
            _kuiarGlowFrame._rgt:SetPoint("TOPRIGHT", _kuiarGlowFrame._top, "BOTTOMRIGHT")
            _kuiarGlowFrame._rgt:SetPoint("BOTTOMRIGHT", _kuiarGlowFrame._bot, "TOPRIGHT")
        end
        _kuiarGlowFrame:SetParent(targetFrame)
        _kuiarGlowFrame:SetAllPoints(targetFrame)
        _kuiarGlowFrame:SetFrameLevel(targetFrame:GetFrameLevel() + 5)
        _kuiarGlowFrame:SetAlpha(1)
        _kuiarGlowFrame:Show()
        local elapsed = 0
        _kuiarGlowFrame:SetScript("OnUpdate", function(self, dt)
            elapsed = elapsed + dt
            if elapsed >= 0.75 then
                self:Hide(); self:SetScript("OnUpdate", nil); return
            end
            self:SetAlpha(1 - elapsed / 0.75)
        end)
    end

    local function PreviewDestination(key)
        if key == "raidbuff" or key == "aura" then return PAGE_GROUP end
        if key == "consumable" then return PAGE_CONSUMABLES end
        local itemKey = type(key) == "string" and key:match("^item:(.+)$")
        if not itemKey then return nil end
        for _, entry in ipairs(_G._KUIAR_RAID_BUFFS or {}) do if entry.key == itemKey then return PAGE_GROUP end end
        for _, entry in ipairs(_G._KUIAR_AURAS or {}) do if entry.key == itemKey then return PAGE_GROUP end end
        for _, list in ipairs({
            _G._KUIAR_ROGUE_POISONS or {}, _G._KUIAR_PALADIN_RITES or {},
            _G._KUIAR_SHAMAN_IMBUES or {}, _G._KUIAR_SHAMAN_SHIELDS or {},
        }) do
            for _, entry in ipairs(list) do if entry.key == itemKey then return PAGE_CLASS end end
        end
        return PAGE_CONSUMABLES
    end

    local function KUIARNavigateToSetting(key)
        local m = _kuiarClickMappings[key]
        if not m or not m.section or not m.target then
            local destination = PreviewDestination(key)
            if destination and destination ~= _kuiARPageState.selectedPage then
                _kuiARPageState.selectedPage = destination
                KT:RefreshPage()
                C_Timer.After(0.1, function() KUIARNavigateToSetting(key) end)
            end
            return
        end

        -- Dismiss the hint text on first click
        if not IsPreviewHintDismissed() and _previewHintFS and _previewHintFS:IsShown() then
            local profile = DB()
            if profile then
                profile.previewHintDismissed = true
            end
            local hint = _previewHintFS
            local _, anchorTo, _, _, startY = hint:GetPoint(1)
            startY = startY or 5
            anchorTo = anchorTo or hint:GetParent()
            local startHeaderH = _kuiarHeaderBaseH + 35
            local targetHeaderH = _kuiarHeaderBaseH
            local steps = 0
            local ticker
            ticker = C_Timer.NewTicker(0.016, function()
                steps = steps + 1
                local progress = steps * 0.016 / 0.3
                if progress >= 1 then
                    hint:Hide(); ticker:Cancel()
                    if targetHeaderH > 0 then
                        KT:SetContentHeaderHeightSilent(targetHeaderH)
                    end
                    return
                end
                hint:SetAlpha(0.45 * (1 - progress))
                hint:ClearAllPoints()
                hint:SetPoint("BOTTOM", anchorTo, "BOTTOM", 0, startY + progress * 12)
                local hh = startHeaderH - 35 * progress
                if hh > 0 then
                    KT:SetContentHeaderHeightSilent(hh)
                end
            end)
        end

        local sf = KT._scrollFrame
        if not sf then return end

        local child = sf.GetScrollChild and sf:GetScrollChild()
        local sectionTop = m.section.GetTop and m.section:GetTop()
        local childTop = child and child.GetTop and child:GetTop()
        if sectionTop and childTop then
            local scrollPos = math.max(0, (childTop - sectionTop) - 40)
            KT.SmoothScrollTo(scrollPos)
        end
        C_Timer.After(0.15, function() KUIARPlaySettingGlow(m.target) end)
    end

    local function KUIARCreateHitOverlay(element, mappingKey, frameLevelOverride)
        local anchor = element
        if not anchor.CreateTexture then anchor = anchor:GetParent() end
        local btn = CreateFrame("Button", nil, anchor)
        btn:SetAllPoints(element)
        btn:SetFrameLevel(frameLevelOverride or (anchor:GetFrameLevel() + 20))
        btn:RegisterForClicks("LeftButtonDown")
        local c = KT.KUI_ACCENT
        local brd = KT.PP.CreateBorder(btn, c.r, c.g, c.b, 1, 2, "OVERLAY", 7)
        brd:Hide()
        btn:SetScript("OnEnter", function() brd:Show() end)
        btn:SetScript("OnLeave", function() brd:Hide() end)
        btn:SetScript("OnMouseDown", function() KUIARNavigateToSetting(mappingKey) end)
        _kuiarHitOverlays[#_kuiarHitOverlays + 1] = btn
        return btn
    end

    _previewHeaderBuilder = function(hdr, hdrW)
        local icons = CollectPreviewIcons()
        local d = DDB()
        local baseScale = d and d.scale or 1.0
        local ICON_SIZE = _G._KUIAR_ICON_SIZE or 40
        local sz = math.floor(ICON_SIZE * baseScale + 0.5)
        local spacing = d and d.iconSpacing or 8
        local showText = d and d.showText
        local tc = d and d.textColor or {r=1, g=1, b=1}
        local opacity = d and d.opacity or 1.0

        -- Container for icons (centered within hardcoded 80px header)
        local textYOff = d and d.textYOffset or -2
        local textSz = d and d.textSize or 11
        local textOverhang = showText and (math.abs(textYOff) + textSz) or 0
        local container = CreateFrame("Frame", nil, hdr)
        container:SetSize(hdrW, sz + textOverhang)
        container:SetPoint("CENTER", hdr, "CENTER", 0, 0)
        _previewContainer = container

        -- Create icon frames
        wipe(_previewIcons)
        local count = #icons
        local totalW = (count * sz) + ((count - 1) * spacing)

        for i, iconData in ipairs(icons) do
            local btn = CreateFrame("Button", nil, container)
            btn:SetSize(sz, sz)
            btn:EnableMouse(true)
            local startX = -(totalW / 2) + (sz / 2)
            btn:SetPoint("TOP", container, "TOP", startX + (i - 1) * (sz + spacing), 0)
            btn:SetAlpha(opacity)

            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetAllPoints(); icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            icon:SetTexture(iconData.texture or 134400)
            if icon.SetSnapToPixelGrid then icon:SetSnapToPixelGrid(false); icon:SetTexelSnappingBias(0) end
            btn._icon = icon

            -- Pixel-perfect 1px black border
            KT.MakeBorder(btn, 0, 0, 0, 1, KT.PanelPP)

            -- Text label below icon
            local fontPath = (KT and KT.GetFontPath and KT.GetFontPath("auraReminders")) or "Fonts\\ARIALN.TTF"
            local textSize = d and d.textSize or 11
            local textXOff = d and d.textXOffset or 0
            local textYOff = d and d.textYOffset or -2
            local text = btn:CreateFontString(nil, "OVERLAY")
            text:SetPoint("TOP", btn, "BOTTOM", textXOff, textYOff)
            SetPVFont(text, fontPath, textSize)
            text:SetTextColor(tc.r, tc.g, tc.b, 1)
            text:SetText(iconData.label or "")
            if not showText then text:Hide() end
            btn._text = text

            _previewIcons[i] = { frame = btn, data = iconData }
        end

        -- Apply glows
        UpdatePreviewHeader()

        -- Create hit overlays on each preview icon
        wipe(_kuiarHitOverlays)
        local overlayLevel = container:GetFrameLevel() + 20
        for i, pIcon in ipairs(_previewIcons) do
            if pIcon.frame and pIcon.data then
                -- Use per-item key if available, fall back to category
                local mappingKey = pIcon.data.itemKey and ("item:" .. pIcon.data.itemKey) or (pIcon.data.cat or "display")
                KUIARCreateHitOverlay(pIcon.frame, mappingKey, overlayLevel)
                -- Hit overlay on text label scrolls to Show Text setting
                if pIcon.frame._text and showText then
                    KUIARCreateHitOverlay(pIcon.frame._text, "showText", overlayLevel)
                end
            end
        end

        -- Hint text
        if _previewHintFS and not _previewHintFS:GetParent() then
            _previewHintFS = nil
        end
        local hintShown = not IsPreviewHintDismissed()
        local TOTAL_H = 80
        _kuiarHeaderBaseH = TOTAL_H

        if hintShown then
            if not _previewHintFS then
                _previewHintFS = KT.MakeFont(container, 11, nil, 1, 1, 1)
                _previewHintFS:SetAlpha(0.45)
                _previewHintFS:SetText(LText("Click an icon to open its settings"))
            end
            _previewHintFS:SetParent(container)
            _previewHintFS:ClearAllPoints()
            _previewHintFS:SetPoint("BOTTOM", hdr, "BOTTOM", 0, 15)
            _previewHintFS:Show()
            TOTAL_H = TOTAL_H + 35
        elseif _previewHintFS then
            _previewHintFS:Hide()
        end

        return TOTAL_H
    end

    ---------------------------------------------------------------------------
    --  MakeCogBtn helper (inline cog button next to a DualRow region)
    ---------------------------------------------------------------------------
    local function MakeCogBtn(rgn, showFn, anchorTo, iconPath)
        local cogBtn = CreateFrame("Button", nil, rgn)
        cogBtn:SetSize(26, 26)
        cogBtn:SetPoint("RIGHT", anchorTo or rgn._lastInline or rgn._control, "LEFT", -8, 0)
        rgn._lastInline = cogBtn
        cogBtn:SetFrameLevel(rgn:GetFrameLevel() + 5)
        cogBtn:SetAlpha(0.4)
        local cogTex = cogBtn:CreateTexture(nil, "OVERLAY")
        if not iconPath or iconPath == KT.COGS_ICON then
            cogTex:SetSize(16, 12)
            cogTex:SetPoint("CENTER")
            cogTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        else
            cogTex:SetSize(16, 16)
            cogTex:SetPoint("CENTER")
        end
        cogTex:SetTexture(iconPath or KT.COGS_ICON)
        cogBtn:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
        cogBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
        cogBtn:SetScript("OnClick", function(self) showFn(self) end)
        return cogBtn
    end

    ---------------------------------------------------------------------------
    --  4-column checkbox grid (DualRow-style rows with RowBg + dividers)
    --  items = { { label, classToken, getVal, setVal }, ... }
    ---------------------------------------------------------------------------
    local GRID_COLS     = 4
    local GRID_ROW_H    = 50
    local GRID_BOX_SZ   = 18
    local GRID_PAD      = KT.CONTENT_PAD or 16
    local GRID_SIDE_PAD = 20

    local function BuildCheckboxGrid(parent, y, items, refreshFn, cellRefTable)
        local totalRows = math.ceil(#items / GRID_COLS)
        local totalW = parent:GetWidth() - GRID_PAD * 2
        local colW = math.floor(totalW / GRID_COLS)
        local eg = KT.KUI_ACCENT or KT.KUI_ACCENT

        for row = 0, totalRows - 1 do
            -- Create one full-width row frame per grid row (like DualRow)
            local rowFrame = CreateFrame("Frame", nil, parent)
            PP.Size(rowFrame, totalW, GRID_ROW_H)
            PP.Point(rowFrame, "TOPLEFT", parent, "TOPLEFT", GRID_PAD, y - row * GRID_ROW_H)
            rowFrame._skipRowDivider = true
            KT.RowBg(rowFrame, parent)

            -- 1px dividers at column boundaries (full height, matching _showRowDivider style)
            for d = 1, GRID_COLS - 1 do
                local div = rowFrame:CreateTexture(nil, "ARTWORK")
                div:SetColorTexture(1, 1, 1, 0.06)
                if div.SetSnapToPixelGrid then div:SetSnapToPixelGrid(false); div:SetTexelSnappingBias(0) end
                div:SetWidth(1)
                local xPos = d * colW
                PP.Point(div, "TOP", rowFrame, "TOPLEFT", xPos, 0)
                PP.Point(div, "BOTTOM", rowFrame, "BOTTOMLEFT", xPos, 0)
            end

            -- Build each cell in this row
            for col = 0, GRID_COLS - 1 do
                local idx = row * GRID_COLS + col + 1
                local item = items[idx]
                if not item then break end

                local cell = CreateFrame("Frame", nil, rowFrame)
                cell:SetSize(colW, GRID_ROW_H)
                cell:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", col * colW, 0)

                -- Class color for label
                local cr, cg, cb = 1, 1, 1
                if item.classToken then
                    local cc = RAID_CLASS_COLORS and RAID_CLASS_COLORS[item.classToken]
                    if cc then cr, cg, cb = cc.r, cc.g, cc.b end
                end

                -- Label (left)
                local label = KT.MakeFont(cell, 12, nil, cr, cg, cb)
                label:SetPoint("LEFT", cell, "LEFT", GRID_SIDE_PAD, 0)
                label:SetPoint("RIGHT", cell, "RIGHT", -(GRID_SIDE_PAD + GRID_BOX_SZ + 12), 0)
                label:SetJustifyH("LEFT")
                label:SetWordWrap(false)
                label:SetMaxLines(1)
                label:SetText(item.label)

                -- Checkbox box (right)
                local box = CreateFrame("Frame", nil, cell)
                box:SetSize(GRID_BOX_SZ, GRID_BOX_SZ)
                box:SetPoint("RIGHT", cell, "RIGHT", -GRID_SIDE_PAD, 0)

                local boxBg = box:CreateTexture(nil, "BACKGROUND")
                boxBg:SetAllPoints()
                boxBg:SetColorTexture(0.12, 0.12, 0.14, 1)
                if boxBg.SetSnapToPixelGrid then boxBg:SetSnapToPixelGrid(false); boxBg:SetTexelSnappingBias(0) end

                local boxBrd = KT.MakeBorder(box, 0.25, 0.25, 0.28, 0.6, KT.PanelPP)

                local check = box:CreateTexture(nil, "ARTWORK")
                check:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
                check:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
                check:SetColorTexture(eg.r, eg.g, eg.b, 1)
                if check.SetSnapToPixelGrid then check:SetSnapToPixelGrid(false); check:SetTexelSnappingBias(0) end

                -- Click area covers the whole cell
                local btn = CreateFrame("Button", nil, cell)
                btn:SetAllPoints(cell)
                btn:SetFrameLevel(cell:GetFrameLevel() + 2)

                local function ApplyVisual()
                    local on = item.getVal()
                    if on then
                        check:Show()
                        label:SetAlpha(1)
                        boxBrd:SetColor(eg.r, eg.g, eg.b, 0.15)
                    else
                        check:Hide()
                        label:SetAlpha(0.5)
                        boxBrd:SetColor(0.25, 0.25, 0.28, 0.6)
                    end
                end
                ApplyVisual()

                btn:SetScript("OnClick", function()
                    item.setVal(not item.getVal())
                    ApplyVisual()
                    if refreshFn then refreshFn() end
                end)
                btn:SetScript("OnEnter", function()
                    if not item.getVal() then label:SetAlpha(0.8) end
                end)
                btn:SetScript("OnLeave", function()
                    if not item.getVal() then label:SetAlpha(0.5) end
                end)

                KT.RegisterWidgetRefresh(ApplyVisual)

                -- Store cell reference for preview click navigation
                if cellRefTable and item.key then
                    cellRefTable[item.key] = cell
                end
            end
        end

        return totalRows * GRID_ROW_H
    end

    ---------------------------------------------------------------------------
    --  Auras, Buffs & Consumables page
    ---------------------------------------------------------------------------
    local function BuildRemindersPage(pageName, parent, yOffset)
        local W = KT.Widgets
        local y = yOffset
        local _, h, row
        local fontPath = (KT and KT.GetFontPath and KT.GetFontPath("auraReminders"))
            or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"

        -- Cell reference table for preview icon specific toggle navigation
        local _gridCellRefs = {}

        -- Set up the preview header
        KT:SetContentHeader(_previewHeaderBuilder)

        parent._showRowDivider = true

        if pageName == PAGE_CONTROL then
        _, h = W:SectionHeader(parent, LText("MODULE STATUS"), y); y = y - h
        _, h = W:Toggle(parent, LText("Enable Module"), y,
            function()
                local p = DB()
                return p == nil or p.enable ~= false
            end,
            function(v)
                local p = DB()
                if not p then return end
                p.enable = v and true or false
                Reload()
            end); y = y - h

        -----------------------------------------------------------------------
        --  DISPLAY section
        -----------------------------------------------------------------------
        local displaySection
        displaySection, h = W:SectionHeader(parent, LText(SECTION_DISPLAY), y);  y = y - h

        -- Glow Type (dropdown + inline color swatch) | Show Text (inline color swatch + cog)
        local displayFirstRow
        displayFirstRow, h = W:DualRow(parent, y,
            { type="dropdown", text=LText("Glow Type"),
              values=_G._KUIAR_GLOW_VALUES or {[0]="None"},
              order=_G._KUIAR_GLOW_ORDER or {0},
              getValue=function() local d = DDB(); return d and d.glowType or 0 end,
              setValue=function(v)
                  local d = DDB(); if not d then return end; d.glowType = v
                  RefreshAll(); UpdatePreviewHeader()
                  KT:RefreshPage()
              end },
            { type="toggle", text=LText("Show Text"),
              getValue=function() local d = DDB(); return d and d.showText end,
              setValue=function(v)
                  local d = DDB(); if not d then return end; d.showText = v
                  RefreshAll()
                  UpdatePreviewHeader()
                  KT:RefreshPage()
              end }
        );  y = y - h
        row = displayFirstRow

        -- Inline color swatch on Glow Type (left)
        do
            local rgn = row._leftRegion
            local swatch = KT.BuildColorSwatch(rgn, rgn:GetFrameLevel()+5,
                function()
                    local d = DDB()
                    local gc = d and d.glowColor or {r=1, g=0.776, b=0.376}
                    return gc.r, gc.g, gc.b, 1
                end,
                function(r, g, b)
                    local d = DDB(); if not d then return end
                    d.glowColor = {r=r, g=g, b=b}
                    RefreshAll(); UpdatePreviewHeader()
                end, false, 20)
            swatch:SetPoint("RIGHT", rgn._lastInline or rgn._control, "LEFT", -12, 0)
            rgn._lastInline = swatch

            -- Disabled overlay when glow type is None
            local swatchBlock = CreateFrame("Frame", nil, swatch)
            swatchBlock:SetAllPoints()
            swatchBlock:SetFrameLevel(swatch:GetFrameLevel() + 10)
            swatchBlock:EnableMouse(true)
            swatchBlock:SetScript("OnEnter", function()
                KT.ShowWidgetTooltip(swatch, KT.DisabledTooltip(LText("a Glow Type other than None")))
            end)
            swatchBlock:SetScript("OnLeave", function() KT.HideWidgetTooltip() end)
            local function UpdateSwatchDisabled()
                local d = DDB()
                local isNone = not d or (d.glowType or 0) == 0
                if isNone then
                    swatch:SetAlpha(0.3)
                    swatchBlock:Show()
                else
                    swatch:SetAlpha(1)
                    swatchBlock:Hide()
                end
            end
            UpdateSwatchDisabled()
            KT.RegisterWidgetRefresh(UpdateSwatchDisabled)
        end

        -- Inline color swatch + cog on Show Text (right of row 1)
        do
            local rgn = row._rightRegion
            local swatch = KT.BuildColorSwatch(rgn, rgn:GetFrameLevel()+5,
                function()
                    local d = DDB()
                    local tc = d and d.textColor or {r=1, g=1, b=1}
                    return tc.r, tc.g, tc.b, 1
                end,
                function(r, g, b)
                    local d = DDB(); if not d then return end
                    d.textColor = {r=r, g=g, b=b}
                    RefreshAll(); UpdatePreviewHeader()
                end, false, 20)
            -- Anchor relative to the region RIGHT edge so the swatch sits
            -- just left of the toggle pill (pill = RIGHT-12, 38px wide).
            -- swatch offset: -(12 pill gap + 38 pill width + 12 gap) = -62
            swatch:SetPoint("RIGHT", rgn, "RIGHT", -62, 0)
            rgn._lastInline = swatch

            -- Disabled overlay for swatch when Show Text is off
            local swatchBlock = CreateFrame("Frame", nil, swatch)
            swatchBlock:SetAllPoints()
            swatchBlock:SetFrameLevel(swatch:GetFrameLevel() + 10)
            swatchBlock:EnableMouse(true)
            swatchBlock:SetScript("OnEnter", function()
                KT.ShowWidgetTooltip(swatch, KT.DisabledTooltip(LText("Show Text")))
            end)
            swatchBlock:SetScript("OnLeave", function() KT.HideWidgetTooltip() end)

            -- Inline cog for text settings (size, x/y offset)
            local _, cogShow = KT.BuildCogPopup({
                title = LText("Text Settings"),
                rows = {
                    { type="slider", label=LText("Text Size"), min=6, max=24, step=1,
                      get=function() local d = DDB(); return d and d.textSize or 11 end,
                      set=function(v) local d = DDB(); if not d then return end; d.textSize = v; RefreshAll(); UpdatePreviewHeader() end },
                    { type="slider", label=LText("X Offset"), min=-50, max=50, step=1,
                      get=function() local d = DDB(); return d and d.textXOffset or 0 end,
                      set=function(v) local d = DDB(); if not d then return end; d.textXOffset = v; RefreshAll(); UpdatePreviewHeader() end },
                    { type="slider", label=LText("Y Offset"), min=-50, max=50, step=1,
                      get=function() local d = DDB(); return d and d.textYOffset or -2 end,
                      set=function(v) local d = DDB(); if not d then return end; d.textYOffset = v; RefreshAll(); UpdatePreviewHeader() end },
                },
            })
            -- cogBtn sits left of swatch: swatch ends at -62+20=-42 from RIGHT,
            -- gap 8px, so cogBtn RIGHT at -(62 + 20 + 8) = -90 from rgn RIGHT.
            local cogBtn = MakeCogBtn(rgn, cogShow, nil)

            -- Disabled overlay for cog when Show Text is off
            local cogBlock = CreateFrame("Frame", nil, cogBtn)
            cogBlock:SetAllPoints()
            cogBlock:SetFrameLevel(cogBtn:GetFrameLevel() + 10)
            cogBlock:EnableMouse(true)
            cogBlock:SetScript("OnEnter", function()
                KT.ShowWidgetTooltip(cogBtn, KT.DisabledTooltip(LText("Show Text")))
            end)
            cogBlock:SetScript("OnLeave", function() KT.HideWidgetTooltip() end)

            -- Shared refresh for both swatch and cog disabled states
            local function UpdateTextInlinesDisabled()
                local d = DDB()
                local off = not d or not d.showText
                if off then
                    swatch:SetAlpha(0.3)
                    swatchBlock:Show()
                    cogBtn:SetAlpha(0.15)
                    cogBlock:Show()
                else
                    swatch:SetAlpha(1)
                    swatchBlock:Hide()
                    cogBtn:SetAlpha(0.4)
                    cogBlock:Hide()
                end
            end
            UpdateTextInlinesDisabled()
            KT.RegisterWidgetRefresh(UpdateTextInlinesDisabled)
        end

        -- Scale | Icon Spacing (inline DIRECTIONS cog, Y offset only)
        local displaySecondRow
        displaySecondRow, h = W:DualRow(parent, y,
            { type="slider", text=LText("Scale"), min=0.5, max=3.0, step=0.05,
              getValue=function() local d = DDB(); return d and d.scale or 1.0 end,
              setValue=function(v)
                  local d = DDB(); if not d then return end; d.scale = v
                  RefreshAll()
                  UpdatePreviewHeader()
              end },
            { type="slider", text=LText("Icon Spacing"), min=0, max=50, step=1,
              getValue=function() local d = DDB(); return d and d.iconSpacing or 8 end,
              setValue=function(v)
                  local d = DDB(); if not d then return end; d.iconSpacing = v
                  RefreshAll()
                  RelayoutPreviewIcons()
              end }
        );  y = y - h

        -- Inline DIRECTIONS cog on Icon Spacing (right) for Y offset only
        do
            local rgn = displaySecondRow._rightRegion
            local _, cogShow = KT.BuildCogPopup({
                title = LText("Layout Settings"),
                rows = {
                    { type="slider", label="Y", min=-600, max=600, step=1,
                      get=function() local d = DDB(); return d and d.yOffset or 0 end,
                      set=function(v) local d = DDB(); if not d then return end; d.yOffset = v
                          if _G._KUIAR_ApplyUnlockPos then _G._KUIAR_ApplyUnlockPos() end end },
                },
            })
            MakeCogBtn(rgn, cogShow, nil, KT.DIRECTIONS_ICON)
        end

        -- Attach Important Buffs to Cursor | Opacity
        _, h = W:DualRow(parent, y,
            { type="toggle", text=LText("Attach Important Buffs to Cursor"),
              getValue=function() local d = DDB(); return d and d.cursorAttach end,
              setValue=function(v) local d = DDB(); if not d then return end; d.cursorAttach = v; RefreshAll() end },
            { type="slider", text=LText("Opacity"), min=0, max=1, step=0.05,
              getValue=function() local d = DDB(); return d and d.opacity or 1 end,
              setValue=function(v)
                  local d = DDB(); if not d then return end; d.opacity = v
                  RefreshAll(); UpdatePreviewHeader()
              end }
        );  y = y - h

        -- Frame Strata
        _, h = W:DualRow(parent, y,
            { type="dropdown", text=LText("Frame Strata"),
              values=_G._KUIAR_STRATA_VALUES or {MEDIUM="Medium"},
              order=_G._KUIAR_STRATA_ORDER or {"MEDIUM"},
              getValue=function() local d = DDB(); return d and d.frameStrata or "MEDIUM" end,
              setValue=function(v)
                  local d = DDB(); if not d then return end; d.frameStrata = v
                  if _G._KUIAR_ApplyStrata then _G._KUIAR_ApplyStrata() end
              end },
            { type="label", text="" }
        );  y = y - h

        _, h = W:Spacer(parent, y, 20);  y = y - h

        wipe(_kuiarClickMappings)
        _kuiarClickMappings.display = { section = displaySection, target = displayFirstRow }
        _kuiarClickMappings.showText = { section = displaySection, target = showTextRow }
        return math.abs(y)
        end

        if pageName == PAGE_GROUP then
        -----------------------------------------------------------------------
        --  GROUP READINESS: shared buffs and assigned auras
        -----------------------------------------------------------------------
        local raidBufHdr
        raidBufHdr, h = W:SectionHeader(parent, LText(SECTION_RAID_BUFFS), y);  y = y - h

        -- Show Others Missing | Show Buffs Outside Instances
        local raidBufFirstRow
        raidBufFirstRow, h = W:DualRow(parent, y,
            { type="toggle", text=LText("Show Others Missing"),
              getValue=function() local r = RDB(); return r and r.showOthersMissing end,
              setValue=function(v) local r = RDB(); if r then r.showOthersMissing = v; RefreshAll() end end },
            { type="toggle", text=LText("Show Buffs Outside Instances"),
              getValue=function() local r = RDB(); return r and r.showNonInstanced end,
              setValue=function(v) local r = RDB(); if r then r.showNonInstanced = v; RefreshAll() end end }
        );  y = y - h

        -- 4-column checkbox grid for individual raid buffs
        do
            local RAID_BUFFS = _G._KUIAR_RAID_BUFFS or {}
            local gridItems = {}
            for _, buff in ipairs(RAID_BUFFS) do
                gridItems[#gridItems+1] = {
                    label = buff.name,
                    classToken = buff.class,
                    key = buff.key,
                    getVal = function() local r = RDB(); return r and r.enabled and r.enabled[buff.key] end,
                    setVal = function(v) local r = RDB(); if r and r.enabled then r.enabled[buff.key] = v end end,
                }
            end
            h = BuildCheckboxGrid(parent, y, gridItems, function() RefreshAll(); RebuildPreviewHeader() end, _gridCellRefs)
            y = y - h
        end

        _, h = W:Spacer(parent, y, 20);  y = y - h

        -----------------------------------------------------------------------
        --  AURAS section
        -----------------------------------------------------------------------
        local auraHdr
        auraHdr, h = W:SectionHeader(parent, LText(SECTION_AURAS), y);  y = y - h

        -- Show Auras Outside Instances | Show Specials Outside Instances
        local auraFirstRow
        auraFirstRow, h = W:DualRow(parent, y,
            { type="toggle", text=LText("Show Auras Outside Instances"),
              getValue=function() local a = ADB(); return a and a.showNonInstanced end,
              setValue=function(v) local a = ADB(); if a then a.showNonInstanced = v; RefreshAll() end end },
            { type="toggle", text=LText("Show Specials Outside Instances"),
              getValue=function() local c = CDB(); return c and c.showSpecialsNonInstanced end,
              setValue=function(v) local c = CDB(); if c then c.showSpecialsNonInstanced = v; RefreshAll() end end }
        );  y = y - h

        -- 4-column checkbox grid for individual auras
        do
            local AURAS = _G._KUIAR_AURAS or {}
            local gridItems = {}
            for _, aura in ipairs(AURAS) do
                gridItems[#gridItems+1] = {
                    label = aura.name,
                    classToken = aura.class,
                    key = aura.key,
                    getVal = function() local a = ADB(); return a and a.enabled and a.enabled[aura.key] end,
                    setVal = function(v) local a = ADB(); if a and a.enabled then a.enabled[aura.key] = v end end,
                }
            end
            h = BuildCheckboxGrid(parent, y, gridItems, function() RefreshAll(); RebuildPreviewHeader() end, _gridCellRefs)
            y = y - h
        end

        _, h = W:Spacer(parent, y, 20);  y = y - h

        wipe(_kuiarClickMappings)
        _kuiarClickMappings.raidbuff = { section = raidBufHdr, target = raidBufFirstRow }
        _kuiarClickMappings.aura = { section = auraHdr, target = auraFirstRow }
        for k, cell in pairs(_gridCellRefs) do
            _kuiarClickMappings["item:" .. k] = { section = cell, target = cell }
        end
        return math.abs(y)
        end

        if pageName == PAGE_CLASS then
        -----------------------------------------------------------------------
        --  CLASS UPKEEP: poisons, rites, imbues and shields
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, LText(SECTION_ROGUE), y);  y = y - h

        do
            local POISONS = _G._KUIAR_ROGUE_POISONS or {}
            local gridItems = {}
            for _, poison in ipairs(POISONS) do
                gridItems[#gridItems+1] = {
                    label = poison.name,
                    classToken = "ROGUE",
                    key = poison.key,
                    getVal = function() local c = CDB(); return c and c.enabled and c.enabled[poison.key] end,
                    setVal = function(v) local c = CDB(); if c and c.enabled then c.enabled[poison.key] = v end end,
                }
            end
            h = BuildCheckboxGrid(parent, y, gridItems, function() RefreshAll(); RebuildPreviewHeader() end, _gridCellRefs)
            y = y - h
        end

        _, h = W:Spacer(parent, y, 10);  y = y - h

        -----------------------------------------------------------------------
        --  PALADIN RITES sub-section
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, LText(SECTION_PALADIN), y);  y = y - h

        do
            local RITES = _G._KUIAR_PALADIN_RITES or {}
            local gridItems = {}
            for _, rite in ipairs(RITES) do
                gridItems[#gridItems+1] = {
                    label = rite.name,
                    classToken = "PALADIN",
                    key = rite.key,
                    getVal = function() local c = CDB(); return c and c.enabled and c.enabled[rite.key] end,
                    setVal = function(v) local c = CDB(); if c and c.enabled then c.enabled[rite.key] = v end end,
                }
            end
            h = BuildCheckboxGrid(parent, y, gridItems, function() RefreshAll(); RebuildPreviewHeader() end, _gridCellRefs)
            y = y - h
        end

        _, h = W:Spacer(parent, y, 10);  y = y - h

        -----------------------------------------------------------------------
        --  SHAMAN IMBUES & SHIELDS sub-section
        -----------------------------------------------------------------------
        _, h = W:SectionHeader(parent, LText(SECTION_SHAMAN), y);  y = y - h

        do
            local gridItems = {}
            local IMBUES = _G._KUIAR_SHAMAN_IMBUES or {}
            for _, imbue in ipairs(IMBUES) do
                gridItems[#gridItems+1] = {
                    label = imbue.name,
                    classToken = "SHAMAN",
                    key = imbue.key,
                    getVal = function() local c = CDB(); return c and c.enabled and c.enabled[imbue.key] end,
                    setVal = function(v) local c = CDB(); if c and c.enabled then c.enabled[imbue.key] = v end end,
                }
            end
            local SHIELDS = _G._KUIAR_SHAMAN_SHIELDS or {}
            for _, shield in ipairs(SHIELDS) do
                gridItems[#gridItems+1] = {
                    label = shield.name,
                    classToken = "SHAMAN",
                    key = shield.key,
                    getVal = function() local c = CDB(); return c and c.enabled and c.enabled[shield.key] end,
                    setVal = function(v) local c = CDB(); if c and c.enabled then c.enabled[shield.key] = v end end,
                }
            end
            h = BuildCheckboxGrid(parent, y, gridItems, function() RefreshAll(); RebuildPreviewHeader() end, _gridCellRefs)
            y = y - h
        end

        _, h = W:Spacer(parent, y, 10);  y = y - h

        wipe(_kuiarClickMappings)
        for k, cell in pairs(_gridCellRefs) do
            _kuiarClickMappings["item:" .. k] = { section = cell, target = cell }
        end
        return math.abs(y)
        end

        -----------------------------------------------------------------------
        --  CONSUMABLE LOADOUT
        -----------------------------------------------------------------------
        local consumHdr
        consumHdr, h = W:SectionHeader(parent, LText(SECTION_CONSUMABLES), y);  y = y - h

        -- Flask toggle | Preferred Click to Buff dropdown
        local consumFirstRow
        local flaskRow
        do
            local FLASK_ITEMS = _G._KUIAR_FLASK_ITEMS or {}
            local flaskValues = { last_used = LText("Last Used") }
            local flaskOrder = { "last_used" }
            for _, f in ipairs(FLASK_ITEMS) do
                flaskValues[f.key] = (C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(f.buffID) and C_Spell.GetSpellInfo(f.buffID).name) or LText(f.name)
                flaskOrder[#flaskOrder+1] = f.key
            end
            flaskRow, h = W:DualRow(parent, y,
                { type="toggle", text=LText("Flask"),
                  getValue=function() local c = CDB(); return c and c.enabled and c.enabled.flask end,
                  setValue=function(v) local c = CDB(); if c and c.enabled then c.enabled.flask = v; RefreshAll(); RebuildPreviewHeader() end end },
                { type="dropdown", text=LText("Preferred Click to Buff"), dropdownWidth=220,
                  values=flaskValues, order=flaskOrder,
                  getValue=function() local c = CDB(); return c and c.preferredFlask or "last_used" end,
                  setValue=function(v) local c = CDB(); if c then c.preferredFlask = v; RefreshAll() end end }
            );  y = y - h
            consumFirstRow = flaskRow
        end

        -- Food toggle | Preferred Click to Buff dropdown
        local foodRow
        do
            local FOOD_ITEMS = _G._KUIAR_FOOD_ITEMS or {}
            local foodValues = { last_used = LText("Last Used") }
            local foodOrder = { "last_used" }
            for _, f in ipairs(FOOD_ITEMS) do
                foodValues[f.key] = (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(f.itemID)) or (GetItemInfo and GetItemInfo(f.itemID)) or LText(f.name)
                foodOrder[#foodOrder+1] = f.key
            end
            foodRow, h = W:DualRow(parent, y,
                { type="toggle", text=LText("Food"),
                  getValue=function() local c = CDB(); return c and c.enabled and c.enabled.food end,
                  setValue=function(v) local c = CDB(); if c and c.enabled then c.enabled.food = v; RefreshAll(); RebuildPreviewHeader() end end },
                { type="dropdown", text=LText("Preferred Click to Buff"), dropdownWidth=220,
                  values=foodValues, order=foodOrder,
                  getValue=function() local c = CDB(); return c and c.preferredFood or "last_used" end,
                  setValue=function(v) local c = CDB(); if c then c.preferredFood = v; RefreshAll() end end }
            );  y = y - h
        end

        local petRow
        do
            local _, playerClass = UnitClass("player")
            if playerClass == "HUNTER" or playerClass == "WARLOCK" then
                petRow, h = W:DualRow(parent, y,
                    { type="toggle", text=LText("Pet Reminder"),
                      getValue=function() local c = CDB(); return c and c.enabled and c.enabled.pet end,
                      setValue=function(v) local c = CDB(); if c and c.enabled then c.enabled.pet = v; RefreshAll(); RebuildPreviewHeader() end end },
                    nil
                );  y = y - h

                local hint = petRow._leftRegion and petRow._leftRegion._control
                if hint then
                    local hintFS = petRow:CreateFontString(nil, "OVERLAY")
                    hintFS:SetPoint("RIGHT", petRow, "RIGHT", -18, 0)
                    hintFS:SetFont(fontPath, 11, GetABROptOutline())
                    hintFS:SetTextColor(1, 1, 1, 0.45)
                    hintFS:SetText(LText("Click reminder icon to open pet menu"))
                end
            end
        end

        -- Weapon Enhancement toggle | Preferred Click to Buff dropdown
        local weaponEnchantRow
        do
            local WE_CHOICES = _G._KUIAR_WEAPON_ENCHANT_CHOICES or {}
            local weValues = { last_used = LText("Last Used") }
            local weOrder = { "last_used" }
            for _, we in ipairs(WE_CHOICES) do
                weValues[we.key] = LText(we.name)
                weOrder[#weOrder+1] = we.key
            end
            weaponEnchantRow, h = W:DualRow(parent, y,
                { type="toggle", text=LText("Weapon Enhancement"),
                  getValue=function() local c = CDB(); return c and c.enabled and c.enabled.weapon_enchant end,
                  setValue=function(v) local c = CDB(); if c and c.enabled then c.enabled.weapon_enchant = v; RefreshAll(); RebuildPreviewHeader() end end },
                { type="dropdown", text=LText("Preferred Click to Buff"), dropdownWidth=220,
                  values=weValues, order=weOrder,
                  getValue=function() local c = CDB(); return c and c.preferredWeaponEnchant or "last_used" end,
                  setValue=function(v) local c = CDB(); if c then c.preferredWeaponEnchant = v; RefreshAll() end end }
            );  y = y - h
        end

        -- Augment Rune toggle | Display In dropdown
        _, h = W:DualRow(parent, y,
            { type="toggle", text=LText("Augment Rune"),
              getValue=function() local c = CDB(); return c and c.enabled and c.enabled.augment_rune end,
              setValue=function(v) local c = CDB(); if c and c.enabled then c.enabled.augment_rune = v; RefreshAll(); RebuildPreviewHeader() end end },
            { type="dropdown", text=LText("Display In:"),
              values={ mythic=LText("Mythic Only"), heroic_mythic=LText("Heroic and Mythic"), all=LText("All Instanced Content") },
              order={ "mythic", "heroic_mythic", "all" },
              getValue=function() local c = CDB(); return c and c.runeDisplayMode or "mythic" end,
              setValue=function(v) local c = CDB(); if c then c.runeDisplayMode = v; RefreshAll() end end }
        );  y = y - h

        -- Inky Black Potion toggle + inline "Choose Zones" button | empty right
        row, h = W:DualRow(parent, y,
            { type="toggle", text=LText("Inky Black Potion"),
              getValue=function() local c = CDB(); return c and c.enabled and c.enabled.inky_black end,
              setValue=function(v)
                  local c = CDB(); if c and c.enabled then c.enabled.inky_black = v; RefreshAll(); RebuildPreviewHeader() end
                  KT:RefreshPage()
              end },
            nil
        );  y = y - h

        -- Inline "Choose Zones" button on the left region
        do
            local rgn = row._leftRegion
            local eg = KT.KUI_ACCENT or KT.KUI_ACCENT
            local lerp = KT.lerp
            local DARK_BG = KT.DARK_BG or { r = 0.05, g = 0.07, b = 0.09 }

            local zoneBtn = CreateFrame("Button", nil, rgn)
            zoneBtn:SetSize(110, 24)
            zoneBtn:SetPoint("RIGHT", rgn._lastInline or rgn._control, "LEFT", -10, 0)
            zoneBtn:SetFrameLevel(rgn:GetFrameLevel() + 5)
            rgn._lastInline = zoneBtn

            local zoneBrd = KT.MakeBorder(zoneBtn, 1, 1, 1, 0.3, KT.PanelPP)
            local zoneBg = KT.SolidTex(zoneBtn, "BACKGROUND", DARK_BG.r, DARK_BG.g, DARK_BG.b, 0.92)
            zoneBg:SetAllPoints()
            local zoneLbl = KT.MakeFont(zoneBtn, 12, nil, 1, 1, 1)
            zoneLbl:SetPoint("CENTER")
            zoneLbl:SetText(LText("Choose Zones"))

            -- Hover animation
            do
                local FADE_DUR = 0.1
                local progress, target = 0, 0
                local function Apply(t)
                    zoneLbl:SetTextColor(1, 1, 1, lerp(0.5, 0.8, t))
                    zoneBrd:SetColor(1, 1, 1, lerp(0.3, 0.5, t))
                end
                local function OnUpdate(self, elapsed)
                    local dir = (target == 1) and 1 or -1
                    progress = progress + dir * (elapsed / FADE_DUR)
                    if (dir == 1 and progress >= 1) or (dir == -1 and progress <= 0) then
                        progress = target; self:SetScript("OnUpdate", nil)
                    end
                    Apply(progress)
                end
                zoneBtn:SetScript("OnEnter", function(self) target = 1; self:SetScript("OnUpdate", OnUpdate) end)
                zoneBtn:SetScript("OnLeave", function(self) target = 0; self:SetScript("OnUpdate", OnUpdate) end)
            end

            zoneBtn:SetScript("OnClick", function()
                local c = CDB()
                local current = c and c.inkyBlackZones or ""
                KT:ShowInputPopup({
                    title = LText("Inky Black Potion Zone IDs"),
                    message = "Enter map zone IDs separated by commas.\nThe potion reminder will only show in these zones.",
                    placeholder = "e.g. 2248, 2339",
                    initialText = current,
                    maxLetters = 500,
                    confirmText = LText("Save"),
                    extraButton = {
                        text = LText("Add Current Zone"),
                        onClick = function(editBox)
                            local mapID = C_Map.GetBestMapForUnit("player")
                            if not mapID then return end
                            local txt = editBox:GetText() or ""
                            local idStr = tostring(mapID)
                            if txt == "" then
                                editBox:SetText(idStr)
                            else
                                editBox:SetText(txt .. ", " .. idStr)
                            end
                        end,
                    },
                    onConfirm = function(text)
                        local cc = CDB(); if cc then cc.inkyBlackZones = text or ""; RefreshAll() end
                    end,
                })
            end)

            -- Disabled overlay when Inky Black Potion is off
            local blockFrame = CreateFrame("Frame", nil, zoneBtn)
            blockFrame:SetAllPoints()
            blockFrame:SetFrameLevel(zoneBtn:GetFrameLevel() + 10)
            blockFrame:EnableMouse(true)
            blockFrame:SetScript("OnEnter", function()
                KT.ShowWidgetTooltip(zoneBtn, KT.DisabledTooltip("Inky Black Potion"))
            end)
            blockFrame:SetScript("OnLeave", function() KT.HideWidgetTooltip() end)
            local function UpdateZoneBtnDisabled()
                local c = CDB()
                local off = not c or not c.enabled or not c.enabled.inky_black
                if off then
                    zoneBtn:SetAlpha(0.3)
                    blockFrame:Show()
                else
                    zoneBtn:SetAlpha(1)
                    blockFrame:Hide()
                end
            end
            UpdateZoneBtnDisabled()
            KT.RegisterWidgetRefresh(UpdateZoneBtnDisabled)
        end

        -- Consumable rows are direct navigation targets on this page.
        wipe(_kuiarClickMappings)
        _kuiarClickMappings.consumable = { section = consumHdr, target = consumFirstRow }
        if flaskRow then _kuiarClickMappings["item:flask"] = { section = flaskRow, target = flaskRow } end
        if foodRow then _kuiarClickMappings["item:food"] = { section = foodRow, target = foodRow } end
        if petRow then _kuiarClickMappings["item:pet"] = { section = petRow, target = petRow } end
        if weaponEnchantRow then _kuiarClickMappings["item:weapon_enchant"] = { section = weaponEnchantRow, target = weaponEnchantRow } end

        return math.abs(y)
    end

    ---------------------------------------------------------------------------
    --  Talent Reminders Page
    ---------------------------------------------------------------------------
    local function BuildTalentRemindersPage(pageName, parent, yOffset)
        local W = KT.Widgets
        local y = yOffset
        local _, h
        local fontPath = (KT and KT.GetFontPath and KT.GetFontPath("auraReminders"))
            or "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"

        parent._showRowDivider = true

        _, h = W:SectionHeader(parent, LText("TALENT REMINDER STATUS"), y); y = y - h
        _, h = W:Toggle(parent, LText("Enable Module"), y,
            function()
                local p = DB()
                return p == nil or p.enable ~= false
            end,
            function(v)
                local p = DB()
                if not p then return end
                p.enable = v and true or false
                Reload()
            end); y = y - h

        -- State for the add-reminder form
        local selectedZoneMap = {}  -- [zoneIdx] = true/false
        local selectedTalentSpellID = nil
        local selectedTalentName = nil
        local selectedTalentSource = nil  -- "class" or "spec"

        -- Zone data
        local zones = _G._KUIAR_TALENT_REMINDER_ZONES or {}

        -----------------------------------------------------------------------
        --  Talent enumeration helpers (live from C_Traits)
        -----------------------------------------------------------------------
        local function GetTalentList(treeType)
            local talents = {}
            local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
            if not configID then return talents end
            local configInfo = C_Traits and C_Traits.GetConfigInfo and C_Traits.GetConfigInfo(configID)
            if not configInfo or not configInfo.treeIDs or not configInfo.treeIDs[1] then return talents end
            local treeID = configInfo.treeIDs[1]
            local nodes = C_Traits.GetTreeNodes(treeID)
            if not nodes then return talents end

            -- Gather all node posX values to find the class/spec split point
            -- Class nodes are on the left half, spec nodes on the right half
            local nodeInfos = {}
            local allPosX = {}
            for _, nodeID in ipairs(nodes) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                if nodeInfo and nodeInfo.ID and nodeInfo.ID > 0 and nodeInfo.entryIDs and #nodeInfo.entryIDs > 0 then
                    nodeInfos[#nodeInfos + 1] = nodeInfo
                    allPosX[#allPosX + 1] = nodeInfo.posX
                end
            end

            -- Find the gap between class and spec trees
            -- Sort posX values and find the largest gap
            table.sort(allPosX)
            local splitX = 0
            local maxGap = 0
            for i = 2, #allPosX do
                local gap = allPosX[i] - allPosX[i-1]
                if gap > maxGap then
                    maxGap = gap
                    splitX = (allPosX[i-1] + allPosX[i]) / 2
                end
            end

            local seenSpells = {}
            for _, nodeInfo in ipairs(nodeInfos) do
                local isClassNode = nodeInfo.posX < splitX
                -- Skip hero talent subtree nodes
                if nodeInfo.subTreeID then
                    -- skip
                elseif (treeType == "class" and isClassNode) or (treeType == "spec" and not isClassNode) then
                    for _, entryID in ipairs(nodeInfo.entryIDs) do
                        local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                        if entryInfo and entryInfo.definitionID then
                            local defInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                            if defInfo and defInfo.spellID and not seenSpells[defInfo.spellID] then
                                local spellName = C_Spell.GetSpellName(defInfo.spellID)
                                if spellName and spellName ~= "" then
                                    seenSpells[defInfo.spellID] = true
                                    talents[#talents + 1] = { spellID = defInfo.spellID, name = spellName }
                                end
                            end
                        end
                    end
                end
            end

            table.sort(talents, function(a, b) return a.name < b.name end)
            return talents
        end

        -----------------------------------------------------------------------
        --  SECTION: ADD REMINDER (no header clean layout)
        -----------------------------------------------------------------------

        -- Helper: build comma-separated zone label from selectedZoneMap
        local function GetSelectedZoneLabel()
            local names = {}
            for idx in pairs(selectedZoneMap) do
                if selectedZoneMap[idx] then
                    local z = zones[idx]
                    if z then names[#names + 1] = z.name end
                end
            end
            if #names == 0 then return "Select Dungeon/Raid" end
            table.sort(names)
            return table.concat(names, ", ")
        end

        -- Wide centered zone dropdown (no label, multi-select checkbox popup)
        local CONTENT_PAD = 45
        local ZONE_DD_W = 350
        local ZONE_DD_H = 38
        y = y - 30  -- 30px space above dropdown
        local ZONE_ROW_H = ZONE_DD_H + 30
        local zoneRow = CreateFrame("Frame", nil, parent)
        local zoneRowW = parent:GetWidth() - CONTENT_PAD * 2
        PP.Size(zoneRow, zoneRowW, ZONE_ROW_H)
        PP.Point(zoneRow, "TOPLEFT", parent, "TOPLEFT", CONTENT_PAD, y)

        local zoneDDBtn = CreateFrame("Button", nil, zoneRow)
        PP.Size(zoneDDBtn, ZONE_DD_W, ZONE_DD_H)
        PP.Point(zoneDDBtn, "TOP", zoneRow, "TOP", 0, 0)
        zoneDDBtn:SetFrameLevel(zoneRow:GetFrameLevel() + 1)
        local zoneDDBg = zoneDDBtn:CreateTexture(nil, "BACKGROUND")
        zoneDDBg:SetAllPoints()
        zoneDDBg:SetColorTexture(0.075, 0.113, 0.141, 0.9)
        KT.MakeBorder(zoneDDBtn, 1, 1, 1, 0.20, KT.PanelPP)

        local zoneDDLbl = zoneDDBtn:CreateFontString(nil, "OVERLAY")
        zoneDDLbl:SetFont(fontPath, 13, GetABROptOutline())
        zoneDDLbl:SetTextColor(1, 1, 1, 0.50)
        zoneDDLbl:SetMaxLines(1)
        zoneDDLbl:SetJustifyH("LEFT")
        zoneDDLbl:SetWordWrap(false)
        zoneDDLbl:SetText(LText("Select Dungeon/Raid"))

        local zoneArrow = KT.MakeDropdownArrow(zoneDDBtn, 14, KT.PanelPP)
        zoneDDLbl:SetPoint("LEFT", zoneDDBtn, "LEFT", 14, 0)
        zoneDDLbl:SetPoint("RIGHT", zoneArrow, "LEFT", -5, 0)

        -- Multi-select checkbox popup
        local zonePopup = CreateFrame("Frame", nil, UIParent)
        zonePopup:SetFrameStrata("FULLSCREEN_DIALOG")
        zonePopup:SetFrameLevel(200)
        zonePopup:SetClampedToScreen(true)
        local ITEM_H = 28
        local popupH = math.min(#zones * ITEM_H + 8, 300)
        zonePopup:SetSize(ZONE_DD_W, popupH)
        zonePopup:Hide()

        local popupBg = zonePopup:CreateTexture(nil, "BACKGROUND")
        popupBg:SetAllPoints()
        popupBg:SetColorTexture(0.10, 0.10, 0.12, 0.97)
        KT.MakeBorder(zonePopup, 1, 1, 1, 0.12, KT.PanelPP)

        -- Scroll frame for items
        local sf = CreateFrame("ScrollFrame", nil, zonePopup)
        sf:SetPoint("TOPLEFT", zonePopup, "TOPLEFT", 0, -4)
        sf:SetPoint("BOTTOMRIGHT", zonePopup, "BOTTOMRIGHT", 0, 4)
        local child = CreateFrame("Frame", nil, sf)
        child:SetWidth(ZONE_DD_W)
        sf:SetScrollChild(child)

        local scrollOffset = 0
        sf:SetScript("OnMouseWheel", function(_, delta)
            local maxScroll = math.max(0, child:GetHeight() - sf:GetHeight())
            scrollOffset = math.max(0, math.min(maxScroll, scrollOffset - delta * ITEM_H * 2))
            sf:SetVerticalScroll(scrollOffset)
        end)
        zonePopup:SetScript("OnMouseWheel", function(_, delta)
            sf:GetScript("OnMouseWheel")(sf, delta)
        end)

        local eg = KT.KUI_ACCENT or KT.KUI_ACCENT
        local checkItems = {}
        for i, z in ipairs(zones) do
            local item = CreateFrame("Button", nil, child)
            item:SetHeight(ITEM_H)
            item:SetPoint("TOPLEFT", child, "TOPLEFT", 1, -(i - 1) * ITEM_H)
            item:SetPoint("TOPRIGHT", child, "TOPRIGHT", -1, -(i - 1) * ITEM_H)

            local hl = item:CreateTexture(nil, "ARTWORK")
            hl:SetAllPoints()
            hl:SetColorTexture(1, 1, 1, 0)

            -- Checkbox square
            local cb = CreateFrame("Frame", nil, item)
            cb:SetSize(14, 14)
            cb:SetPoint("LEFT", item, "LEFT", 10, 0)
            local cbBg = cb:CreateTexture(nil, "BACKGROUND")
            cbBg:SetAllPoints()
            cbBg:SetColorTexture(0.06, 0.06, 0.08, 1)
            KT.MakeBorder(cb, 1, 1, 1, 0.12, KT.PanelPP)
            local cbCheck = cb:CreateTexture(nil, "OVERLAY")
            cbCheck:SetSize(10, 10)
            cbCheck:SetPoint("CENTER")
            cbCheck:SetColorTexture(eg.r, eg.g, eg.b, 1)
            cbCheck:Hide()
            item._cbCheck = cbCheck

            local lbl = item:CreateFontString(nil, "OVERLAY")
            lbl:SetFont(fontPath, 11, GetABROptOutline())
            lbl:SetTextColor(0.75, 0.75, 0.78, 1)
            lbl:SetPoint("LEFT", cb, "RIGHT", 8, 0)
            lbl:SetPoint("RIGHT", item, "RIGHT", -8, 0)
            lbl:SetJustifyH("LEFT")
            lbl:SetWordWrap(false)
            lbl:SetText(z.name .. (z.type == "raid" and " (Raid)" or ""))

            local function UpdateCheck()
                cbCheck:SetShown(selectedZoneMap[i] == true)
            end
            UpdateCheck()

            item:SetScript("OnClick", function()
                selectedZoneMap[i] = not selectedZoneMap[i]
                UpdateCheck()
                zoneDDLbl:SetText(GetSelectedZoneLabel())
            end)
            item:SetScript("OnEnter", function()
                lbl:SetTextColor(1, 1, 1, 1)
                hl:SetColorTexture(1, 1, 1, 0.08)
            end)
            item:SetScript("OnLeave", function()
                lbl:SetTextColor(0.75, 0.75, 0.78, 1)
                hl:SetColorTexture(1, 1, 1, 0)
            end)
            checkItems[i] = item
        end
        child:SetHeight(math.max(1, #zones * ITEM_H))

        zonePopup:SetScript("OnShow", function()
            zonePopup:ClearAllPoints()
            zonePopup:SetPoint("TOPLEFT", zoneDDBtn, "BOTTOMLEFT", 0, -2)
            scrollOffset = 0
            sf:SetVerticalScroll(0)
            -- Refresh checks
            for i, item in ipairs(checkItems) do
                item._cbCheck:SetShown(selectedZoneMap[i] == true)
            end
        end)
        -- Close when clicking outside
        zonePopup:SetScript("OnUpdate", function()
            if not zonePopup:IsMouseOver() and not zoneDDBtn:IsMouseOver() and IsMouseButtonDown("LeftButton") then
                zonePopup:Hide()
            end
        end)

        zoneDDBtn:SetScript("OnClick", function()
            if zonePopup:IsShown() then zonePopup:Hide() else zonePopup:Show() end
        end)
        zoneDDBtn:SetScript("OnEnter", function()
            zoneDDBg:SetColorTexture(0.095, 0.143, 0.181, 1)
        end)
        zoneDDBtn:SetScript("OnLeave", function()
            zoneDDBg:SetColorTexture(0.075, 0.113, 0.141, 0.9)
        end)

        y = y - ZONE_ROW_H

        -- Row 2: Class Talents | Spec Talents (standard DualRow dropdowns)
        local classTalents, specTalents = {}, {}

        local function RebuildTalentLists()
            classTalents = GetTalentList("class")
            specTalents = GetTalentList("spec")
        end
        RebuildTalentLists()

        local selectedClassTalent = 0
        local selectedSpecTalent = 0

        -- Forward references for cross-dropdown updates
        local _classDDBtn, _specDDBtn

        -- Build talent value tables for standard dropdowns
        local classTalentValues, classTalentOrder = {}, {}
        local specTalentValues, specTalentOrder = {}, {}

        local function RebuildTalentDropdownValues()
            wipe(classTalentValues); wipe(classTalentOrder)
            wipe(specTalentValues); wipe(specTalentOrder)
            classTalentValues[0] = LText("Select a talent...")
            specTalentValues[0] = LText("Select a talent...")
            classTalentOrder[1] = 0
            specTalentOrder[1] = 0
            for _, t in ipairs(classTalents) do
                classTalentValues[t.spellID] = t.name
                classTalentOrder[#classTalentOrder + 1] = t.spellID
            end
            for _, t in ipairs(specTalents) do
                specTalentValues[t.spellID] = t.name
                specTalentOrder[#specTalentOrder + 1] = t.spellID
            end
        end
        RebuildTalentDropdownValues()

        -- Talent dropdowns: two side-by-side with labels above
        local TALENT_DD_W = 200
        local TALENT_DD_H = 30
        local TALENT_LABEL_H = 16
        local TALENT_GAP_Y = 6
        local TALENT_GAP_X = 50
        local TALENT_ROW_H = TALENT_LABEL_H + TALENT_GAP_Y + TALENT_DD_H + 12
        local talentDropdownOptions = {
            rowHeight = 24,
            maxVisibleRows = 10,
            iconSize = 18,
            getIcon = function(spellID)
                spellID = tonumber(spellID)
                if not spellID or spellID <= 0 then return nil end
                return C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID)
            end,
        }
        local talentRow = CreateFrame("Frame", nil, parent)
        local talentRowW = parent:GetWidth() - CONTENT_PAD * 2
        PP.Size(talentRow, talentRowW, TALENT_ROW_H)
        PP.Point(talentRow, "TOPLEFT", parent, "TOPLEFT", CONTENT_PAD, y)

        local totalTalentW = TALENT_DD_W * 2 + TALENT_GAP_X
        local talentStartX = (talentRowW - totalTalentW) / 2

        -- Class Talent label + dropdown
        local classLabel = talentRow:CreateFontString(nil, "OVERLAY")
        classLabel:SetFont(fontPath, 11, GetABROptOutline())
        classLabel:SetTextColor(KT.TEXT_SECTION_R or 0.45, KT.TEXT_SECTION_G or 0.50, KT.TEXT_SECTION_B or 0.55, KT.TEXT_SECTION_A or 1)
        PP.Point(classLabel, "TOP", talentRow, "TOPLEFT", talentStartX + TALENT_DD_W / 2, 0)
        classLabel:SetText(LText("Class Talent"))

        local classDDBtn, classDDLbl = KT.BuildDropdownControl(
            talentRow, TALENT_DD_W, talentRow:GetFrameLevel() + 1,
            classTalentValues, classTalentOrder,
            function() return selectedClassTalent end,
            function(v)
                selectedClassTalent = v
                if v ~= 0 then
                    selectedSpecTalent = 0
                    selectedTalentSpellID = v
                    selectedTalentName = classTalentValues[v]
                    selectedTalentSource = "class"
                    if _specDDBtn and _specDDBtn.Refresh then _specDDBtn.Refresh() end
                else
                    selectedTalentSpellID = nil
                    selectedTalentName = nil
                    selectedTalentSource = nil
                end
            end,
            talentDropdownOptions
        )
        PP.Point(classDDBtn, "TOPLEFT", talentRow, "TOPLEFT", talentStartX, -(TALENT_LABEL_H + TALENT_GAP_Y))
        _classDDBtn = classDDBtn

        -- Spec Talent label + dropdown
        local specLabel = talentRow:CreateFontString(nil, "OVERLAY")
        specLabel:SetFont(fontPath, 11, GetABROptOutline())
        specLabel:SetTextColor(KT.TEXT_SECTION_R or 0.45, KT.TEXT_SECTION_G or 0.50, KT.TEXT_SECTION_B or 0.55, KT.TEXT_SECTION_A or 1)
        PP.Point(specLabel, "TOP", talentRow, "TOPLEFT", talentStartX + TALENT_DD_W + TALENT_GAP_X + TALENT_DD_W / 2, 0)
        specLabel:SetText(LText("Spec Talent"))

        local specDDBtn, specDDLbl = KT.BuildDropdownControl(
            talentRow, TALENT_DD_W, talentRow:GetFrameLevel() + 1,
            specTalentValues, specTalentOrder,
            function() return selectedSpecTalent end,
            function(v)
                selectedSpecTalent = v
                if v ~= 0 then
                    selectedClassTalent = 0
                    selectedTalentSpellID = v
                    selectedTalentName = specTalentValues[v]
                    selectedTalentSource = "spec"
                    if _classDDBtn and _classDDBtn.Refresh then _classDDBtn.Refresh() end
                else
                    selectedTalentSpellID = nil
                    selectedTalentName = nil
                    selectedTalentSource = nil
                end
            end,
            talentDropdownOptions
        )
        PP.Point(specDDBtn, "TOPLEFT", talentRow, "TOPLEFT", talentStartX + TALENT_DD_W + TALENT_GAP_X, -(TALENT_LABEL_H + TALENT_GAP_Y))
        _specDDBtn = specDDBtn

        y = y - TALENT_ROW_H

        -- "Add Reminder" button (styled like Done button)
        _, h = W:Spacer(parent, y, 10); y = y - h

        local addBtnFrame = CreateFrame("Frame", nil, parent)
        PP.Size(addBtnFrame, parent:GetWidth() or 400, 36)
        PP.Point(addBtnFrame, "TOPLEFT", parent, "TOPLEFT", 0, y)

        local addBtn = CreateFrame("Button", nil, addBtnFrame)
        addBtn:SetSize(160, 36)
        addBtn:SetPoint("CENTER", addBtnFrame, "CENTER", 0, 0)

        local DARK_BG = KT.DARK_BG or { r = 0.05, g = 0.07, b = 0.09 }
        local addBtnBg = KT.SolidTex(addBtn, "BACKGROUND", DARK_BG.r, DARK_BG.g, DARK_BG.b, 0.92)
        addBtnBg:SetAllPoints()

        local eg = KT.KUI_ACCENT or KT.KUI_ACCENT
        local addBtnBorder = KT.MakeBorder(addBtn, eg.r, eg.g, eg.b, 0.7, KT.PanelPP)

        local addBtnText = addBtn:CreateFontString(nil, "OVERLAY")
        addBtnText:SetPoint("CENTER")
        addBtnText:SetFont(fontPath, 13, GetABROptOutline())
        addBtnText:SetTextColor(eg.r, eg.g, eg.b, 0.7)
        addBtnText:SetText(LText("Add Reminder"))

        do
            local lerp = KT.lerp
            local FADE_DUR = 0.1
            local progress, target = 0, 0
            local function Apply(t)
                addBtnText:SetTextColor(eg.r, eg.g, eg.b, lerp(0.7, 1, t))
                addBtnBorder:SetColor(eg.r, eg.g, eg.b, lerp(0.7, 1, t))
            end
            local function OnUpdate(self, elapsed)
                local dir = (target == 1) and 1 or -1
                progress = progress + dir * (elapsed / FADE_DUR)
                if (dir == 1 and progress >= 1) or (dir == -1 and progress <= 0) then
                    progress = target; self:SetScript("OnUpdate", nil)
                end
                Apply(progress)
            end
            addBtn:SetScript("OnEnter", function(self) target = 1; self:SetScript("OnUpdate", OnUpdate) end)
            addBtn:SetScript("OnLeave", function(self) target = 0; self:SetScript("OnUpdate", OnUpdate) end)
        end

        y = y - 36

        -----------------------------------------------------------------------
        --  Red border pulse animation for validation
        -----------------------------------------------------------------------
        local pulseTarget = nil
        local pulseAG = nil

        local function PulseRedBorder(targetRow)
            if not targetRow then return end
            -- Create a red border overlay on the row
            if not targetRow._redPulse then
                local rf = CreateFrame("Frame", nil, targetRow)
                rf:SetAllPoints()
                rf:SetFrameLevel(targetRow:GetFrameLevel() + 10)
                local border = KT.MakeBorder(rf, 1, 0.2, 0.2, 1, KT.PanelPP)
                rf._border = border
                targetRow._redPulse = rf
            end
            local rf = targetRow._redPulse
            rf:Show()
            rf:SetAlpha(1)
            -- Fade out after 1.5 seconds
            local elapsed = 0
            rf:SetScript("OnUpdate", function(self, dt)
                elapsed = elapsed + dt
                if elapsed < 0.8 then
                    -- Pulse: oscillate alpha
                    local a = 0.5 + 0.5 * math.sin(elapsed * 10)
                    self:SetAlpha(a)
                elseif elapsed < 1.5 then
                    self:SetAlpha(math.max(0, 1 - (elapsed - 0.8) / 0.7))
                else
                    self:SetScript("OnUpdate", nil)
                    self:Hide()
                end
            end)
        end

        -----------------------------------------------------------------------
        --  Reminder list (dynamic, rebuilt on add/remove)
        -----------------------------------------------------------------------
        local MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\"
        local listContainer = CreateFrame("Frame", nil, parent)
        listContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        listContainer:SetSize(parent:GetWidth() or 400, 1)  -- height grows dynamically

        local listRows = {}
        local listRowCount = 0  -- manual alternating row counter

        local function RebuildReminderList()
            -- Clear existing rows
            for _, row in ipairs(listRows) do row:Hide() end
            wipe(listRows)
            listRowCount = 0

            local p = DB()
            if not p then return 0 end
            local reminders = p.talentReminders or {}

            if #reminders == 0 then
                listRowCount = listRowCount + 1
                local ROW_H = 50
                local CONTENT_PAD = 45
                local totalW = listContainer:GetWidth() - CONTENT_PAD * 2
                local emptyRow = CreateFrame("Frame", nil, listContainer)
                PP.Size(emptyRow, totalW, ROW_H)
                PP.Point(emptyRow, "TOPLEFT", listContainer, "TOPLEFT", CONTENT_PAD, 0)
                local alpha = (listRowCount % 2 == 0) and 0.2 or 0.1
                local bg = emptyRow:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0, 0, 0, alpha)
                local div = emptyRow:CreateTexture(nil, "ARTWORK")
                div:SetColorTexture(1, 1, 1, 0.06)
                div:SetWidth(1)
                PP.Point(div, "TOP", emptyRow, "TOP", 0, 0)
                PP.Point(div, "BOTTOM", emptyRow, "BOTTOM", 0, 0)
                local emptyFS = emptyRow:CreateFontString(nil, "OVERLAY")
                emptyFS:SetFont(fontPath, 13, GetABROptOutline())
                emptyFS:SetTextColor(0.5, 0.5, 0.5, 1)
                emptyFS:SetPoint("CENTER")
                emptyFS:SetText(LText("No talent reminders configured"))
                emptyRow:Show()
                listRows[1] = emptyRow
                listContainer:SetHeight(ROW_H)
                return ROW_H
            end

            local ROW_H = 50
            local SIDE_PAD = 20
            local CONTENT_PAD = 45
            local totalW = listContainer:GetWidth() - CONTENT_PAD * 2
            local totalH = 0

            -- Helper: create a DualRow-styled frame
            local function MakeListRow(yOff)
                listRowCount = listRowCount + 1
                local row = CreateFrame("Frame", nil, listContainer)
                PP.Size(row, totalW, ROW_H)
                PP.Point(row, "TOPLEFT", listContainer, "TOPLEFT", CONTENT_PAD, yOff)
                -- Alternating row background
                local alpha = (listRowCount % 2 == 0) and 0.2 or 0.1
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(0, 0, 0, alpha)
                -- Center divider
                local div = row:CreateTexture(nil, "ARTWORK")
                div:SetColorTexture(1, 1, 1, 0.06)
                div:SetWidth(1)
                PP.Point(div, "TOP", row, "TOP", 0, 0)
                PP.Point(div, "BOTTOM", row, "BOTTOM", 0, 0)
                return row
            end

            -- Data rows (single row per reminder)
            local Tex = function(id) return _G._KUIAR_Tex and _G._KUIAR_Tex(id) or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400 end
            local eg2 = KT.KUI_ACCENT or KT.KUI_ACCENT
            local ICON_SIZE = 14
            for idx, reminder in ipairs(reminders) do
                local row = MakeListRow(-totalH)
                local capturedIdx = idx

                -- === LEFT HALF: delete (—) | zone name | talent name + icon ===

                -- Delete button (far left)
                local delBtn = CreateFrame("Button", nil, row)
                delBtn:SetSize(ICON_SIZE + 6, ICON_SIZE + 6)
                PP.Point(delBtn, "LEFT", row, "LEFT", SIDE_PAD - 6, 0)
                delBtn:SetFrameLevel(row:GetFrameLevel() + 5)
                local delIcon = delBtn:CreateTexture(nil, "OVERLAY")
                PP.Size(delIcon, ICON_SIZE, ICON_SIZE)
                PP.Point(delIcon, "CENTER", delBtn, "CENTER", 0, 0)
                if delIcon.SetSnapToPixelGrid then delIcon:SetSnapToPixelGrid(false); delIcon:SetTexelSnappingBias(0) end
                delIcon:SetTexture(MEDIA .. "icons\\kui-close.png")
                delBtn:SetAlpha(0.75)
                delBtn:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
                delBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.75) end)
                delBtn:SetScript("OnClick", function()
                    local p2 = DB()
                    if not p2 then return end
                    table.remove(p2.talentReminders, capturedIdx)
                    RebuildReminderList()
                    RefreshAll()
                end)

                -- Zone name (after delete icon, truncated to fit left portion)
                local zoneStr
                if reminder.zoneNames and #reminder.zoneNames > 0 then
                    zoneStr = table.concat(reminder.zoneNames, ", ")
                else
                    zoneStr = reminder.zoneName or "Unknown"
                end
                local zoneFS = row:CreateFontString(nil, "OVERLAY")
                zoneFS:SetFont(fontPath, 14, GetABROptOutline())
                zoneFS:SetTextColor(1, 1, 1, 1)
                zoneFS:SetPoint("LEFT", delBtn, "RIGHT", 6, 0)
                zoneFS:SetJustifyH("LEFT")
                zoneFS:SetWordWrap(false)
                zoneFS:SetMaxLines(1)

                -- Talent name + icon (right portion of left half, anchored to center)
                local spellName = reminder.spellName or "Unknown"
                local spellFS = row:CreateFontString(nil, "OVERLAY")
                spellFS:SetFont(fontPath, 14, GetABROptOutline())
                spellFS:SetTextColor(1, 1, 1, 1)
                spellFS:SetJustifyH("RIGHT")
                spellFS:SetWordWrap(false)
                spellFS:SetMaxLines(1)
                spellFS:SetText(spellName)

                local spellIcon = row:CreateTexture(nil, "ARTWORK")
                spellIcon:SetSize(22, 22)
                spellIcon:SetPoint("RIGHT", row, "CENTER", -SIDE_PAD, 0)
                spellIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                spellIcon:SetTexture(Tex(reminder.spellID))

                spellFS:SetPoint("RIGHT", spellIcon, "LEFT", -6, 0)

                -- Constrain zone text: from after delete to before talent name
                zoneFS:SetPoint("RIGHT", spellFS, "LEFT", -8, 0)
                zoneFS:SetText(zoneStr)

                -- === RIGHT HALF: "Show 'Not Needed' Reminder" label + checkbox ===

                -- Hit area covers the entire right half of the row
                local toggleHit = CreateFrame("Button", nil, row)
                toggleHit:SetPoint("LEFT", row, "CENTER", 0, 0)
                toggleHit:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
                toggleHit:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
                toggleHit:SetFrameLevel(row:GetFrameLevel() + 3)

                local toggleLabel = row:CreateFontString(nil, "OVERLAY")
                toggleLabel:SetFont(fontPath, 14, GetABROptOutline())
                toggleLabel:SetPoint("LEFT", row, "CENTER", SIDE_PAD, 0)
                toggleLabel:SetText(LText("Show 'Not Needed' Reminder"))

                -- Checkbox (far right of right half)
                local toggleBox = CreateFrame("Frame", nil, row)
                toggleBox:SetSize(18, 18)
                toggleBox:SetPoint("RIGHT", row, "RIGHT", -SIDE_PAD, 0)
                local toggleBg = toggleBox:CreateTexture(nil, "BACKGROUND")
                toggleBg:SetAllPoints()
                toggleBg:SetColorTexture(0.06, 0.06, 0.08, 1)
                KT.MakeBorder(toggleBox, 1, 1, 1, 0.12, KT.PanelPP)
                local toggleCheck = toggleBox:CreateTexture(nil, "OVERLAY")
                toggleCheck:SetSize(12, 12)
                toggleCheck:SetPoint("CENTER")
                toggleCheck:SetColorTexture(eg2.r, eg2.g, eg2.b, 1)

                local isChecked = reminder.showNotNeeded == true
                toggleCheck:SetShown(isChecked)

                local function ApplyToggleVisual(checked, hovered)
                    if checked then
                        toggleLabel:SetTextColor(1, 1, 1, 1)
                    elseif hovered then
                        toggleLabel:SetTextColor(1, 1, 1, 0.8)
                    else
                        toggleLabel:SetTextColor(1, 1, 1, 0.4)
                    end
                end
                ApplyToggleVisual(isChecked, false)

                local function DoToggle()
                    local p2 = DB()
                    if not p2 or not p2.talentReminders[capturedIdx] then return end
                    p2.talentReminders[capturedIdx].showNotNeeded = not p2.talentReminders[capturedIdx].showNotNeeded
                    local nowChecked = p2.talentReminders[capturedIdx].showNotNeeded == true
                    toggleCheck:SetShown(nowChecked)
                    ApplyToggleVisual(nowChecked, true)
                    RefreshAll()
                end

                toggleHit:SetScript("OnClick", DoToggle)
                toggleHit:SetScript("OnEnter", function()
                    local checked = false
                    local p2 = DB()
                    if p2 and p2.talentReminders[capturedIdx] then checked = p2.talentReminders[capturedIdx].showNotNeeded == true end
                    ApplyToggleVisual(checked, true)
                end)
                toggleHit:SetScript("OnLeave", function()
                    local checked = false
                    local p2 = DB()
                    if p2 and p2.talentReminders[capturedIdx] then checked = p2.talentReminders[capturedIdx].showNotNeeded == true end
                    ApplyToggleVisual(checked, false)
                end)

                -- Tooltip only on the label itself
                local tooltipHit = CreateFrame("Frame", nil, row)
                tooltipHit:SetPoint("LEFT", toggleLabel, "LEFT", 0, 0)
                tooltipHit:SetPoint("RIGHT", toggleLabel, "RIGHT", 0, 0)
                tooltipHit:SetPoint("TOP", toggleLabel, "TOP", 0, 4)
                tooltipHit:SetPoint("BOTTOM", toggleLabel, "BOTTOM", 0, -4)
                tooltipHit:SetFrameLevel(toggleHit:GetFrameLevel() + 1)
                tooltipHit:EnableMouse(true)
                tooltipHit:SetScript("OnEnter", function()
                    KT.ShowWidgetTooltip(toggleLabel, "Enable this to display a reminder to untalent\nout of this when it is not needed\n(all other dungeons/raids not selected).")
                end)
                tooltipHit:SetScript("OnLeave", function()
                    KT.HideWidgetTooltip()
                end)

                listRows[#listRows + 1] = row
                totalH = totalH + ROW_H
            end

            listContainer:SetHeight(totalH)
            return totalH
        end

        -- Add button click handler
        addBtn:SetScript("OnClick", function()
            -- Validate: must have at least one zone selected
            local hasZone = false
            for idx, sel in pairs(selectedZoneMap) do
                if sel then hasZone = true; break end
            end
            if not hasZone then
                PulseRedBorder(zoneDDBtn)
                return
            end

            -- Validate: must have a talent selected
            if not selectedTalentSpellID or selectedTalentSpellID == 0 then
                PulseRedBorder(classDDBtn)
                PulseRedBorder(specDDBtn)
                return
            end

            local p = DB()
            if not p then return end
            if not p.talentReminders then p.talentReminders = {} end

            -- Collect selected zone IDs and names
            local selZoneNames = {}
            local selZoneIDs = {}
            for idx, sel in pairs(selectedZoneMap) do
                if sel then
                    local z = zones[idx]
                    if z then
                        selZoneNames[#selZoneNames + 1] = z.name
                        if z.instanceID then
                            selZoneIDs[#selZoneIDs + 1] = z.instanceID
                        end
                    end
                end
            end
            table.sort(selZoneNames)
            table.sort(selZoneIDs)

            -- Check for duplicate (same spellID with same zone set)
            for _, r in ipairs(p.talentReminders) do
                if r.spellID == selectedTalentSpellID then
                    -- Merge: if same talent, just skip (user can delete and re-add)
                    return
                end
            end

            p.talentReminders[#p.talentReminders + 1] = {
                zoneNames = selZoneNames,
                zoneIDs = selZoneIDs,
                spellID = selectedTalentSpellID,
                spellName = selectedTalentName,
                showNotNeeded = false,
            }

            -- Reset selection
            wipe(selectedZoneMap)
            selectedClassTalent = 0
            selectedSpecTalent = 0
            selectedTalentSpellID = nil
            selectedTalentName = nil
            selectedTalentSource = nil
            zoneDDLbl:SetText(LText("Select Dungeon/Raid"))
            if classDDBtn.Refresh then classDDBtn.Refresh() end
            if specDDBtn.Refresh then specDDBtn.Refresh() end

            RebuildReminderList()
            RefreshAll()
        end)

        -- Spacer before list
        _, h = W:Spacer(parent, y, 15); y = y - h

        -- Section header for the list
        _, h = W:SectionHeader(parent, LText("ACTIVE REMINDERS"), y); y = y - h

        -- Position the list container
        listContainer:ClearAllPoints()
        listContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)

        local listH = RebuildReminderList()
        y = y - listH

        _, h = W:Spacer(parent, y, 20); y = y - h

        return math.abs(y)
    end

    ---------------------------------------------------------------------------
    --  Register the module
    ---------------------------------------------------------------------------
    
-------------------------------------------------------------------------------
--  CUSTOM AURAS PAGE
-------------------------------------------------------------------------------
local _selectedCustomAuraID = nil

local function BuildCustomAurasPage(pageName, parent, yOffset)
    local LText = KT.Options and KT.Options.LText or function(t) return t end
    local db = _G._KUIAR_AceDB.profile
    if type(db.customAuras) ~= 'table' then db.customAuras = {} end
    local W = KT.Widgets

    local function RefreshCustomAurasUI()
        if KT and KT.RefreshPage then
            KT:RefreshPage(true)
        end
        if _G.KUIAuraReminders_Custom and _G.KUIAuraReminders_Custom.ForceUpdate then
            _G.KUIAuraReminders_Custom:ForceUpdate()
        end
    end

    local mainH = 0
    local _, descH = W:Label(parent, LText("Create standalone custom auras with specific load conditions. They can be freely positioned anywhere on the screen."), -yOffset, 12)
    yOffset = yOffset + descH + 10
    mainH = mainH + descH + 10

    -- Unlock button
    local unlockText = (_G.KUIAuraReminders_Custom and _G.KUIAuraReminders_Custom.UnlockMode) and LText("Lock Custom Auras") or LText("Unlock Custom Auras")
    local _, btnH = W:Button(parent, unlockText, -yOffset, function()
        if _G.KUIAuraReminders_Custom then
            _G.KUIAuraReminders_Custom:SetUnlockMode(not _G.KUIAuraReminders_Custom.UnlockMode)
            RefreshCustomAurasUI()
        end
    end, 200, nil, nil, "LEFT")
    yOffset = yOffset + btnH + 10
    mainH = mainH + btnH + 10

    local leftColWidth = 200
    local rightColWidth = parent:GetWidth() - leftColWidth - 20

    -- Left Column: List
    local leftContainer = CreateFrame("Frame", nil, parent)
    leftContainer:SetSize(leftColWidth, 500)
    leftContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -yOffset)
    
    local leftY = 0
    local function CreateAuraFromTemplate(tmpl)
        local id = "aura_"..tostring(GetTime()):gsub("%.", "")
        local defs = { enabled = true, opacity = 1.0, size = 40, showGlow = false, point = "CENTER", relativePoint = "CENTER", xOffset = 0, yOffset = 0, loadInstance = "ANY" }
        if tmpl == "blank" then
            defs.name = "New Aura"
            defs.triggerType = "AURA"
            defs.triggerSpellID = 17
            defs.triggerAuraType = "HELPFUL"
            defs.triggerUnit = "player"
            defs.triggerAuraMissing = false
            defs.loadCombat = "ANY"
        elseif tmpl == "defensive" then
            defs.name = "Defensive CD"
            defs.triggerType = "COOLDOWN"
            defs.triggerSpellID = 108271
            defs.loadCombat = "IN_COMBAT"
        elseif tmpl == "offensive" then
            defs.name = "Offensive Buff"
            defs.triggerType = "AURA"
            defs.triggerSpellID = 31884
            defs.triggerAuraType = "HELPFUL"
            defs.triggerUnit = "player"
            defs.triggerAuraMissing = false
            defs.loadCombat = "IN_COMBAT"
        elseif tmpl == "debuff" then
            defs.name = "Important Debuff"
            defs.triggerType = "AURA"
            defs.triggerSpellID = 0
            defs.triggerAuraType = "HARMFUL"
            defs.triggerUnit = "player"
            defs.triggerAuraMissing = false
            defs.loadCombat = "ANY"
            defs.size = 55
            defs.showGlow = true
        end
        db.customAuras[id] = defs
        _selectedCustomAuraID = id
        RefreshCustomAurasUI()
    end

    local function CurrentFont() return KT and KT.ResolveFontPath and KT:ResolveFontPath() or "Fonts\\FRIZQT__.TTF" end
    local function MakeTemplateButton(label, desc, iconId, tmplKey)
        local b = CreateFrame("Button", nil, leftContainer)
        b:SetSize(leftColWidth - 10, 44)
        b:SetPoint("TOPLEFT", 5, -leftY)
        if KT and KT.AddBackdrop then KT:AddBackdrop(b, 0.08, 0.10, 0.13, 0.9) end
        if KT and KT.AddBorder then KT:AddBorder(b, 0.2, 0.2, 0.2, 1) end

        local tex = b:CreateTexture(nil, "ARTWORK")
        tex:SetSize(28, 28)
        tex:SetPoint("LEFT", b, "LEFT", 8, 0)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        local GetTex = function(id) return _G._KUIAR_Tex and _G._KUIAR_Tex(id) or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400 end
        tex:SetTexture(GetTex(iconId))

        local tLabel = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tLabel:SetPoint("TOPLEFT", tex, "TOPRIGHT", 8, -2)
        tLabel:SetText(label)
        tLabel:SetFont(CurrentFont(), 12)
        local aR, aG, aB = 1, 1, 1
        if KT and KT.GetStyleAccentRGB then aR, aG, aB = KT:GetStyleAccentRGB() end
        tLabel:SetTextColor(aR, aG, aB)

        local tDesc = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        tDesc:SetPoint("BOTTOMLEFT", tex, "BOTTOMRIGHT", 8, 2)
        tDesc:SetText(desc)
        tDesc:SetFont(CurrentFont(), 10)
        tDesc:SetTextColor(0.5, 0.5, 0.5)

        b:SetScript("OnEnter", function(self) if KT and KT.AddBorder then KT:AddBorder(self, 0.5, 0.5, 0.5, 1) end end)
        b:SetScript("OnLeave", function(self) if KT and KT.AddBorder then KT:AddBorder(self, 0.2, 0.2, 0.2, 1) end end)
        b:SetScript("OnClick", function() CreateAuraFromTemplate(tmplKey) end)
        leftY = leftY + 44 + 5
    end

    local _, hdr = W:Label(leftContainer, AccentColorCode() .. LText("CREATE TEMPLATE") .. "|r", -leftY, 14)
    leftY = leftY + hdr + 5
    MakeTemplateButton(LText("Blank Canvas"), LText("Start from scratch"), 134400, "blank")
    MakeTemplateButton(LText("Defensive CD"), LText("Tracks a cooldown"), 108271, "defensive")
    MakeTemplateButton(LText("Offensive Buff"), LText("Tracks your buff"), 31884, "offensive")
    MakeTemplateButton(LText("Big Debuff"), LText("Important warning"), 136116, "debuff")
    leftY = leftY + 15
    local _, hdr2 = W:Label(leftContainer, AccentColorCode() .. LText("YOUR AURAS") .. "|r", -leftY, 14)
    leftY = leftY + hdr2 + 5

    local sortedIds = {}
    if db.customAuras then
        for id, conf in pairs(db.customAuras) do
            table.insert(sortedIds, {id=id, name=conf.name or "Unnamed"})
        end
        table.sort(sortedIds, function(a,b) return a.name < b.name end)
    end

    for _, entry in ipairs(sortedIds) do
        local id = entry.id
        local conf = db.customAuras[id]
        local prefix = (id == _selectedCustomAuraID) and "> " or ""
        local color = conf.enabled and {r=1,g=1,b=1} or {r=0.5,g=0.5,b=0.5}
        
        local btn = CreateFrame("Button", nil, leftContainer)
        btn:SetSize(leftColWidth - 10, 24)
        btn:SetPoint("TOPLEFT", 5, -leftY)
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(1, 1, 1, (id == _selectedCustomAuraID) and 0.1 or 0.05)
        local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        t:SetPoint("LEFT", 5, 0)
        t:SetText(prefix .. (conf.name or "Unnamed"))
        t:SetTextColor(color.r, color.g, color.b)
        
        btn:SetScript("OnClick", function()
            _selectedCustomAuraID = id
            RefreshCustomAurasUI()
        end)
        leftY = leftY + 26
    end

    -- Right Column: Editor
    local rightContainer = CreateFrame("Frame", nil, parent)
    rightContainer:SetSize(rightColWidth, 500)
    rightContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", leftColWidth + 10, -yOffset)

    local rightY = 0
    if _selectedCustomAuraID and db.customAuras[_selectedCustomAuraID] then
        local conf = db.customAuras[_selectedCustomAuraID]

        local previewSize = 56
        local previewBg = CreateFrame("Frame", nil, rightContainer)
        previewBg:SetSize(previewSize, previewSize)
        previewBg:SetPoint("TOP", rightContainer, "TOP", 0, -5)
        if KT and KT.AddBackdrop then KT:AddBackdrop(previewBg, 0.05, 0.07, 0.09, 1) end
        if KT and KT.AddBorder then KT:AddBorder(previewBg, 0.4, 0.4, 0.4, 1) end
        local GetTex = function(id) return _G._KUIAR_Tex and _G._KUIAR_Tex(id) or (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)) or 134400 end
        local previewTex = previewBg:CreateTexture(nil, "ARTWORK")
        previewTex:SetPoint("TOPLEFT", 1, -1)
        previewTex:SetPoint("BOTTOMRIGHT", -1, 1)
        previewTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        previewTex:SetTexture(GetTex(conf.triggerSpellID))

        -- Main Controls
        rightY = rightY + 70 -- Avoid overlapping with the absolute positioned preview frame

        local _, rowH = W:DualRow(rightContainer, -rightY,
            { type="toggle", text=LText("Enabled"), getValue=function() return conf.enabled end, setValue=function(v) conf.enabled=v; RefreshCustomAurasUI() end },
            { type="button", text=LText("Delete Aura"), onClick=function() db.customAuras[_selectedCustomAuraID] = nil; _selectedCustomAuraID = nil; RefreshCustomAurasUI() end }
        )
        rightY = rightY + rowH + 10

        _, rowH = W:Input(rightContainer, LText("Aura Name (Internal)"), -rightY, function() return conf.name end, function(v) conf.name=v; RefreshCustomAurasUI() end)
        rightY = rightY + rowH + 15

        -- Trigger Category
        local _, lblH = W:Label(rightContainer, AccentColorCode() .. LText("TRIGGER") .. "|r", -rightY, 14)
        rightY = rightY + lblH + 5

        _, rowH = W:Dropdown(rightContainer, LText("Trigger Type"), -rightY, 
            {AURA="Aura (Buff/Debuff)", COOLDOWN="Spell Cooldown"},
            function() return conf.triggerType or "AURA" end,
            function(v) conf.triggerType=v; RefreshCustomAurasUI() end,
            {"AURA", "COOLDOWN"}
        )
        rightY = rightY + rowH + 5

        _, rowH = W:Input(rightContainer, LText("Spell ID"), -rightY, function() return tostring(conf.triggerSpellID or "") end, function(v) conf.triggerSpellID=tonumber(v) or 0; RefreshCustomAurasUI() end)
        rightY = rightY + rowH + 5

        if conf.triggerType == "AURA" then
            _, rowH = W:DualRow(rightContainer, -rightY,
                { type="dropdown", text=LText("Unit"), values={player=LText("Player"), target=LText("Target"), focus=LText("Focus"), pet=LText("Pet")}, getValue=function() return conf.triggerUnit or "player" end, setValue=function(v) conf.triggerUnit=v; RefreshCustomAurasUI() end, order={"player","target","focus","pet"} },
                { type="dropdown", text=LText("Aura Type"), values={HELPFUL=LText("Buff"), HARMFUL=LText("Debuff")}, getValue=function() return conf.triggerAuraType or "HELPFUL" end, setValue=function(v) conf.triggerAuraType=v; RefreshCustomAurasUI() end, order={"HELPFUL","HARMFUL"} }
            )
            rightY = rightY + rowH + 5
            _, rowH = W:Toggle(rightContainer, LText("Trigger when Missing"), -rightY, function() return conf.triggerAuraMissing end, function(v) conf.triggerAuraMissing=v; RefreshCustomAurasUI() end)
            rightY = rightY + rowH + 15
        elseif conf.triggerType == "COOLDOWN" then
            _, rowH = W:Toggle(rightContainer, LText("Trigger when Ready (Not on Cooldown)"), -rightY, function() return conf.triggerCooldownReady end, function(v) conf.triggerCooldownReady=v; RefreshCustomAurasUI() end)
            rightY = rightY + rowH + 15
        end

        -- Load Conditions
        _, lblH = W:Label(rightContainer, AccentColorCode() .. LText("LOAD CONDITIONS") .. "|r", -rightY, 14)
        rightY = rightY + lblH + 5

        _, rowH = W:Dropdown(rightContainer, LText("Combat Status"), -rightY, 
            {ANY="Any", IN_COMBAT="In Combat", OUT_COMBAT="Out of Combat"},
            function() return conf.loadCombat or "ANY" end,
            function(v) conf.loadCombat=v; RefreshCustomAurasUI() end,
            {"ANY", "IN_COMBAT", "OUT_COMBAT"}
        )
        rightY = rightY + rowH + 5

        _, rowH = W:Dropdown(rightContainer, LText("Instance Type"), -rightY, 
            {ANY="Any", NONE="None (World)", PARTY="Party/Dungeon", RAID="Raid", ARENA="Arena", PVP="Battleground"},
            function() return conf.loadInstance or "ANY" end,
            function(v) conf.loadInstance=v; RefreshCustomAurasUI() end,
            {"ANY", "NONE", "PARTY", "RAID", "ARENA", "PVP"}
        )
        rightY = rightY + rowH + 5

        _, rowH = W:Input(rightContainer, LText("Talent Spell ID (0 to ignore)"), -rightY, function() return tostring(conf.loadTalent or "0") end, function(v) conf.loadTalent=tonumber(v) or 0; RefreshCustomAurasUI() end)
        rightY = rightY + rowH + 5

        _, rowH = W:Input(rightContainer, LText("Zone Map ID (0 to ignore)"), -rightY, function() return tostring(conf.loadZoneID or "0") end, function(v) conf.loadZoneID=tonumber(v) or 0; RefreshCustomAurasUI() end)
        rightY = rightY + rowH + 15

        -- Custom Text Settings
        _, lblH = W:Label(rightContainer, AccentColorCode() .. LText("CUSTOM TEXT") .. "|r", -rightY, 14)
        rightY = rightY + lblH + 5

        _, rowH = W:Dropdown(rightContainer, LText("Text Mode"), -rightY, 
            {NONE="None", STATIC="Static Text", STACKS="Aura Stacks", DURATION="Remaining Duration"},
            function() return conf.customTextType or "NONE" end,
            function(v) conf.customTextType=v; RefreshCustomAurasUI() end,
            {"NONE", "STATIC", "STACKS", "DURATION"}
        )
        rightY = rightY + rowH + 5

        if conf.customTextType == "STATIC" then
            _, rowH = W:Input(rightContainer, LText("Static Text Value"), -rightY, function() return conf.customTextValue or "" end, function(v) conf.customTextValue=v; RefreshCustomAurasUI() end)
            rightY = rightY + rowH + 5
        end
        rightY = rightY + 10

        -- Display Settings
        _, lblH = W:Label(rightContainer, AccentColorCode() .. LText("DISPLAY & STYLE") .. "|r", -rightY, 14)
        rightY = rightY + lblH + 5

        _, rowH = W:Dropdown(rightContainer, LText("Display Style"), -rightY, 
            {ICON=LText("Icon (Default)"), TEXT=LText("Text Only")},
            function() return conf.displayStyle or "ICON" end,
            function(v) conf.displayStyle=v; RefreshCustomAurasUI() end,
            {"ICON", "TEXT"}
        )
        rightY = rightY + rowH + 5

        _, rowH = W:Slider(rightContainer, LText("Size"), -rightY, function() return conf.size or 40 end, function(v) conf.size=v; RefreshCustomAurasUI() end, 10, 100, 1, "%d")
        rightY = rightY + rowH + 5

        _, rowH = W:Slider(rightContainer, LText("Opacity"), -rightY, function() return conf.opacity or 1.0 end, function(v) conf.opacity=v; RefreshCustomAurasUI() end, 0, 1, 0.05, "%.2f")
        rightY = rightY + rowH + 5

        _, rowH = W:Toggle(rightContainer, LText("Show Glow Action"), -rightY, function() return conf.showGlow end, function(v) conf.showGlow=v; RefreshCustomAurasUI() end)
        rightY = rightY + rowH + 5

        _, rowH = W:Toggle(rightContainer, LText("Show Name Label Below"), -rightY, function() return conf.showNameLabel == true end, function(v) conf.showNameLabel=v; RefreshCustomAurasUI() end)
        rightY = rightY + rowH + 5

    else
        _, rowH = W:Label(rightContainer, LText("Select or create a Custom Aura to edit its properties."), -rightY, 12, {r=0.6, g=0.6, b=0.6})
        rightY = rightY + rowH + 5
    end

    local maxH = math.max(leftY, rightY)
    return mainH + maxH
end

    KT:RegisterModule("KUIAuraReminders", {
        title       = LText("Aura Readiness"),
        description = LText("Prepare group buffs, class upkeep and consumables from one KUI workspace."),
        pages       = { PAGE_CONTROL, PAGE_GROUP, PAGE_CLASS, PAGE_CONSUMABLES, PAGE_TALENTS, PAGE_CUSTOM_AURAS },
        buildPage   = function(pageName, parent, yOffset)
            if pageName == PAGE_CONTROL or pageName == PAGE_GROUP or pageName == PAGE_CLASS or pageName == PAGE_CONSUMABLES then
                return BuildRemindersPage(pageName, parent, yOffset)
            elseif pageName == PAGE_TALENTS then
                return BuildTalentRemindersPage(pageName, parent, yOffset)
            elseif pageName == PAGE_CUSTOM_AURAS then
                return BuildCustomAurasPage(pageName, parent, yOffset)
            end
        end,
        getHeaderBuilder = function(pageName)
            if pageName == PAGE_CONTROL then
                return _previewHeaderBuilder
            end
            return nil
        end,
        onPageCacheRestore = function(pageName)
            if pageName == PAGE_CONTROL then
                UpdatePreviewHeader()
                -- Refresh hint visibility never recreate here, just show/hide
                local dismissed = IsPreviewHintDismissed()
                if _previewHintFS then
                    if dismissed then
                        _previewHintFS:Hide()
                    else
                        _previewHintFS:SetAlpha(0.45)
                        _previewHintFS:Show()
                    end
                end
                -- Set correct header height based on current hint state
                if _kuiarHeaderBaseH > 0 then
                    KT:SetContentHeaderHeightSilent(_kuiarHeaderBaseH + (dismissed and 0 or 35))
                end
            end
        end,
        onShow = function()
            if _G._KUIAR_HideAllIcons then _G._KUIAR_HideAllIcons() end
        end,
        onHide = function()
            if _G._KUIAR_RequestRefresh then _G._KUIAR_RequestRefresh() end
        end,
        onReset = function()
            if _G._KUIAR_AceDB then
                _G._KUIAR_AceDB:ResetProfile()
            end
            if _G._KUIAR_RequestRefresh then _G._KUIAR_RequestRefresh() end
        end,
    })

    -- Register unlock elements after a short delay
    C_Timer.After(0.5, function()
        if _G._KUIAR_RegisterUnlock then _G._KUIAR_RegisterUnlock() end
    end)

    ---------------------------------------------------------------------------
    --  Slash commands
    ---------------------------------------------------------------------------
    SLASH_KUIAR1 = "/kuiar"
    SLASH_KUIAR2 = "/kuir"
    SlashCmdList.KUIAR = function()
        if InCombatLockdown and InCombatLockdown() then return end
        KT:ShowModule("KUIAuraReminders")
    end
end)
