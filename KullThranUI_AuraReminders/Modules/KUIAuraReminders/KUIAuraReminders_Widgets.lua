-- Aura Reminders options: shared widgets. Publishes fallbacks on KT and the table ns.AuraRemindersWidgets.
-- Same text for every client. Loading only writes tables and functions; frames appear when a widget is called.

local _, ns = ...
local KT = ns.KT or (LibStub and LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true))
if not KT then return end

local abs, floor, max, min = math.abs, math.floor, math.max, math.min

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"
local ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"
local CROP_LOW, CROP_HIGH = 0.07, 0.93

-- Session state: selected page, page frames, header height, refreshers.
local selectedPage = "Control Center"
local headerBuilder
local headerHost, pageContent, contentBaseY
local headerHeight = 0
local refreshers = {}
-- Set while a page build's navigation put the preview in a column beside the settings: { previewWidth, gap }.
local sideLayout
local SIDE_CAPTION_HEIGHT = 22

-----------------------------------------------------------------------------------------------------------------------
-- Small helpers
-----------------------------------------------------------------------------------------------------------------------

-- Current core font path.
local function CoreFont()
    return KT.FONT_PATH or DEFAULT_FONT
end

-- A font string that has its font from the moment it exists.
local function NewText(parent, path, size, flags, r, g, b, a)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(path, size, flags)
    fs:SetTextColor(r, g, b, a)
    return fs
end

local function Clamp(value, low, high)
    return max(low, min(high, value))
end

-- Writes value unless the name already holds something truthy.
local function Keep(name, value)
    if not KT[name] then KT[name] = value end
end

-- Normalises the colon and dot call forms of the header functions.
local function ArgAfterSelf(a, b)
    if a == KT then return b end
    return a
end

-----------------------------------------------------------------------------------------------------------------------
-- Functions for the ns table
-----------------------------------------------------------------------------------------------------------------------

-- Translates through the locale table, read on every use.
local function LText(text)
    if type(text) ~= "string" then return text end
    if KT.GetLocale then
        local locale = KT:GetLocale()
        if locale then
            local entry = locale[text]
            if entry ~= nil then return entry end
        end
    end
    return text
end

-- Asks the core's reload dialog.
local function Reload()
    if StaticPopup_Show then StaticPopup_Show("KULLTHRANUI_RELOAD") end
    local changed = ns.AuraRemindersWidgets and ns.AuraRemindersWidgets.OnSettingChanged
    if changed then changed() end
end

-- One channel as two lowercase hex digits.
local function HexChannel(value)
    return string.format("%02x", floor(Clamp(tonumber(value) or 0, 0, 1) * 255 + 0.5))
end

-- Colour escape of the current accent.
local function AccentColorCode()
    local r, g, b = 1, 0, 0.3333333333
    if KT.GetStyleAccentRGB then r, g, b = KT:GetStyleAccentRGB() end
    return "|cff" .. HexChannel(r) .. HexChannel(g) .. HexChannel(b)
end

-- Accent down arrow on the right of a button.
local function AddChevron(button)
    local tex = button:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(ICON_PATH .. "downarrow.png")
    tex:SetSize(14, 14)
    tex:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    KT:SetAccentVertexColor(tex, 1)
    return tex
end

-----------------------------------------------------------------------------------------------------------------------
-- Constants, utilities, tooltips, row background
-----------------------------------------------------------------------------------------------------------------------

Keep("KUI_SettingsCogGlyph", ICON_PATH .. "cogs.png")
Keep("KUI_NavArrowGlyph", ICON_PATH .. "right_arrow.png")
Keep("KUI_PanelBaseColor", { r = 0.05, g = 0.07, b = 0.09 })
Keep("TEXT_SECTION_R", 0.45)
Keep("TEXT_SECTION_G", 0.50)
Keep("TEXT_SECTION_B", 0.55)
Keep("TEXT_SECTION_A", 1)

-- Accent colour computed on every field read, so a style change is seen at once.
Keep("KUI_ACCENT", setmetatable({}, { __index = function(_, field)
    if field == "a" then return 1 end
    if field ~= "r" and field ~= "g" and field ~= "b" then return nil end
    local r, g, b
    if KT.GetStyleAccentRGB then
        r, g, b = KT:GetStyleAccentRGB()
    else
        r, g, b = KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333
    end
    if field == "r" then return r end
    if field == "g" then return g end
    return b
end }))

Keep("lerp", function(a, b, t)
    return a + (b - a) * (t or 0)
end)

-- Core font path; arguments are ignored.
Keep("GetFontPath", function()
    return CoreFont()
end)

Keep("GetFontOutlineFlag", function()
    return "OUTLINE"
end)

Keep("GetFontUseShadow", function()
    return true
end)

-- Adds a function to the current build's refresher list.
Keep("RegisterWidgetRefresh", function(fn)
    if type(fn) == "function" then refreshers[#refreshers + 1] = fn end
end)

Keep("ShowWidgetTooltip", function(owner, text)
    if owner == nil or text == nil then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end)

Keep("HideWidgetTooltip", function()
    GameTooltip:Hide()
end)

Keep("DisabledTooltip", function(reason)
    return "|cffff4444" .. LText("Disabled:") .. "|r " .. string.format(LText("requires %s"), tostring(reason or LText("another option")))
end)

-- Alternating row stripe, counted on the parent's shared rowCounter field.
Keep("RowBg", function(frame, parent)
    local count = (parent.rowCounter or 0) + 1
    parent.rowCounter = count
    local tex = frame:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetColorTexture(1, 1, 1, count % 2 == 0 and 0.05 or 0.02)
end)

-----------------------------------------------------------------------------------------------------------------------
-- Colour swatch
-----------------------------------------------------------------------------------------------------------------------

-- Button showing a colour; returns the button and its repaint function.
local function BuildColorSwatch(parent, level, getColor, setColor, _, size)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size or 20, size or 20)
    button:SetFrameLevel(level or parent:GetFrameLevel() + 1)
    KT:AddBackdrop(button, 0.08, 0.08, 0.11, 1)
    KT:AddBorder(button, 0.20, 0.20, 0.25, 1)

    local swatch = button:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("TOPLEFT", 2, -2)
    swatch:SetPoint("BOTTOMRIGHT", -2, 2)

    local function repaint()
        local r, g, b = getColor()
        swatch:SetColorTexture(r or 1, g or 1, b or 1, 1)
    end
    repaint()

    button:SetScript("OnClick", function()
        local r, g, b = getColor()
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b,
            hasOpacity = false,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                setColor(nr, ng, nb)
                repaint()
            end,
            cancelFunc = function(prev)
                if prev then setColor(prev.r, prev.g, prev.b) end
                repaint()
            end,
        })
    end)

    return button, repaint
end
Keep("BuildColorSwatch", BuildColorSwatch)

-----------------------------------------------------------------------------------------------------------------------
-- Cog popup
-----------------------------------------------------------------------------------------------------------------------

-- Number with two decimals, without trailing zeros or a bare point; anything else as a string.
local function FormatValue(value)
    if type(value) ~= "number" then return tostring(value) end
    local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
    return text
end

-- One slider row. The change script goes on after the range, so the build itself writes nothing.
-- Showing a value is not a change, however the client delivers it. state.showing holds back a change fired inside the
-- SetValue. One delivered later carries userInput false, or at least the value that was shown, which entry.shown remembers.
local function AddCogSlider(popup, row, y, path, state)
    local label = NewText(popup, path, 11, "OUTLINE", 1, 1, 1, 0.85)
    label:SetPoint("TOPLEFT", 10, y)
    label:SetText(row.label or "")

    local slider = CreateFrame("Slider", nil, popup, "MinimalSliderTemplate")
    slider:SetPoint("TOPLEFT", 10, y - 18)
    slider:SetPoint("TOPRIGHT", -10, y - 18)
    slider:SetHeight(16)
    slider:SetMinMaxValues(row.min or 0, row.max or 1)
    slider:SetValueStep(row.step or 0.1)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end

    local valueText = NewText(popup, path, 11, "OUTLINE", 1, 1, 1, 0.5)
    valueText:SetPoint("TOPRIGHT", -10, y)

    local entry = { row = row, slider = slider, valueText = valueText }
    slider:SetScript("OnValueChanged", function(_, value, userInput)
        if row.set and not state.showing and userInput ~= false and value ~= entry.shown then row.set(value) end
        if value ~= entry.shown then entry.shown = nil end
        valueText:SetText(FormatValue(value))
    end)

    return entry
end

-- Popup with slider rows; returns the popup and its show function. Creation order sets click stacking.
local function BuildCogPopup(opts)
    opts = opts or {}
    local path = CoreFont()

    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetClampedToScreen(true)
    popup:Hide()
    KT:AddBackdrop(popup, 0.04, 0.04, 0.05, 0.98)
    KT:AddBorder(popup, 0, 0, 0, 1)

    local title = NewText(popup, path, 12, "OUTLINE", 1, 1, 1, 1)
    title:SetPoint("TOPLEFT", 10, -10)
    title:SetText(opts.title or "")

    local y = -32
    local sliders = {}
    local state = { showing = false }
    for _, row in ipairs(opts.rows or {}) do
        if row.type == "slider" then
            sliders[#sliders + 1] = AddCogSlider(popup, row, y, path, state)
            y = y - 48
        end
    end
    popup:SetSize(max(220, opts.width or 260), max(70, -y + 10))

    local closer = CreateFrame("Frame", nil, UIParent)
    closer:SetAllPoints()
    closer:SetFrameStrata("FULLSCREEN_DIALOG")
    closer:EnableMouse(true)
    closer:Hide()
    closer:SetScript("OnMouseDown", function()
        popup:Hide()
        closer:Hide()
    end)
    popup:SetScript("OnHide", function()
        closer:Hide()
    end)

    local function show(anchor)
        state.showing = true
        for _, entry in ipairs(sliders) do
            local value = entry.row.get and entry.row.get() or 0
            entry.slider:SetValue(value)
            entry.shown = entry.slider:GetValue()
            entry.valueText:SetText(FormatValue(value))
        end
        state.showing = false
        popup:ClearAllPoints()
        if anchor then
            popup:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
        else
            popup:SetPoint("CENTER")
        end
        closer:Show()
        popup:Show()
    end

    return popup, show
end
Keep("BuildCogPopup", BuildCogPopup)

-----------------------------------------------------------------------------------------------------------------------
-- Dropdown
-----------------------------------------------------------------------------------------------------------------------

-- Frames of a dropdown's list, built once with the button.
local function BuildDropdownList(rowHeight)
    local popup = CreateFrame("Frame", nil, UIParent)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(1000)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:EnableMouseWheel(true)
    popup:Hide()
    KT:AddBackdrop(popup, 0.10, 0.10, 0.12, 0.97)
    KT:AddBorder(popup, 1, 1, 1, 0.12)

    local scroll = CreateFrame("ScrollFrame", nil, popup)
    scroll:SetFrameLevel(popup:GetFrameLevel() + 1)
    scroll:EnableMouse(true)
    scroll:EnableMouseWheel(true)

    local child = CreateFrame("Frame", nil, scroll)
    child:SetFrameLevel(popup:GetFrameLevel() + 2)
    child:EnableMouse(true)
    child:EnableMouseWheel(true)
    scroll:SetScrollChild(child)

    local bar = CreateFrame("Slider", nil, popup)
    bar:SetFrameLevel(popup:GetFrameLevel() + 4)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(10)
    bar:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -2, -4)
    bar:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -2, 4)
    bar:SetValueStep(rowHeight)
    if bar.SetObeyStepOnDrag then bar:SetObeyStepOnDrag(false) end

    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetPoint("TOP", 0, 0)
    track:SetPoint("BOTTOM", 0, 0)
    track:SetWidth(2)
    track:SetColorTexture(1, 1, 1, 0.10)

    bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb = bar:GetThumbTexture()
    thumb:SetSize(8, 28)
    KT:SetAccentTexture(thumb, 0.85)
    bar:Hide()

    return popup, scroll, child, bar
end

-- Button with a list opened on click; returns the button, its label and its chevron.
local function BuildDropdownControl(parent, width, frameLevel, values, order, getter, setter, options)
    values = values or {}
    options = options or {}
    local rowHeight = options.rowHeight or 24
    local iconSize = options.iconSize or 18
    local getIcon = options.getIcon
    local path = CoreFont()

    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 200, 30)
    button:SetFrameLevel(frameLevel or parent:GetFrameLevel() + 1)
    KT:AddBackdrop(button, 0.075, 0.113, 0.141, 0.9)
    KT:AddBorder(button, 1, 1, 1, 0.20)

    local selectedIcon = button:CreateTexture(nil, "ARTWORK")
    selectedIcon:SetSize(iconSize, iconSize)
    selectedIcon:SetPoint("LEFT", button, "LEFT", 7, 0)
    selectedIcon:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
    selectedIcon:Hide()

    local chevron = AddChevron(button)

    local label = NewText(button, path, 13, KT.GetFontOutlineFlag(), 1, 1, 1, 0.50)
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)
    label:SetMaxLines(1)
    label:SetPoint("RIGHT", button, "RIGHT", -28, 0)

    local function labelFor(value)
        return values[value] or values[tostring(value)] or tostring(value or "")
    end

    -- Shows the current value and places the label beside the icon, when there is one.
    local function refresh()
        local value
        if getter then value = getter() end
        label:SetText(labelFor(value))
        local icon = getIcon and getIcon(value)
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
    button.Refresh = refresh
    refresh()

    local popup, scroll, child, bar = BuildDropdownList(rowHeight)
    local maxScroll = 0
    local rows = {}

    -- Wheel handler shared by the list's frames and rows.
    local function onWheel(_, delta)
        if not bar:IsShown() then return end
        local target = Clamp(scroll:GetVerticalScroll() - delta * rowHeight * 3, 0, maxScroll)
        scroll:SetVerticalScroll(target)
        if bar:GetValue() ~= target then bar:SetValue(target) end
    end
    popup:SetScript("OnMouseWheel", onWheel)
    scroll:SetScript("OnMouseWheel", onWheel)
    child:SetScript("OnMouseWheel", onWheel)
    bar:SetScript("OnValueChanged", function(_, value)
        scroll:SetVerticalScroll(Clamp(value, 0, maxScroll))
    end)

    -- Entries in display order: given keys, or all values sorted by label.
    local function collectEntries()
        local entries = {}
        if order then
            for i, key in ipairs(order) do
                entries[i] = { key = key, label = labelFor(key) }
            end
        else
            for key, text in pairs(values) do
                entries[#entries + 1] = { key = key, label = text }
            end
            table.sort(entries, function(a, b) return tostring(a.label) < tostring(b.label) end)
        end
        return entries
    end

    local function addRow(i, entry)
        local top = -(i - 1) * rowHeight
        local row = CreateFrame("Button", nil, child)
        row:SetFrameLevel(popup:GetFrameLevel() + 3)
        row:SetHeight(rowHeight)
        row:SetPoint("TOPLEFT", 0, top)
        row:SetPoint("TOPRIGHT", 0, top)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", onWheel)

        local background = row:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0, 0, 0, 0)

        local icon = row:CreateTexture(nil, "ARTWORK")
        local iconFile = getIcon and getIcon(entry.key)
        if iconFile then
            icon:SetSize(iconSize, iconSize)
            icon:SetPoint("LEFT", row, "LEFT", 5, 0)
            icon:SetTexture(iconFile)
            icon:SetTexCoord(CROP_LOW, CROP_HIGH, CROP_LOW, CROP_HIGH)
            icon:Show()
        else
            icon:Hide()
        end

        local text = NewText(row, CoreFont(), 11, "", 0.88, 0.88, 0.88, 1)
        if iconFile then
            text:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        else
            text:SetPoint("LEFT", 8, 0)
        end
        text:SetPoint("RIGHT", -8, 0)
        text:SetJustifyH("LEFT")
        text:SetText(entry.label)

        row:SetScript("OnEnter", function() KT:SetAccentTexture(background, 0.18) end)
        row:SetScript("OnLeave", function() background:SetColorTexture(0, 0, 0, 0) end)
        row:SetScript("OnClick", function()
            if setter then setter(entry.key) end
            refresh()
            popup:Hide()
        end)
        rows[i] = row
    end

    -- Drops the old rows, measures from the button's width now, builds the new rows.
    local function rebuildRows()
        for i, row in ipairs(rows) do
            row:Hide()
            row:SetParent(UIParent)
            rows[i] = nil
        end

        local entries = collectEntries()
        local listWidth = button:GetWidth()
        local total = #entries * rowHeight
        local visible = min(#entries, options.maxVisibleRows or #entries)
        local viewport = max(rowHeight, visible * rowHeight)
        local overflow = total > viewport
        local inset = overflow and 13 or 1

        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", popup, "TOPLEFT", 1, -1)
        scroll:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -inset, 1)
        child:SetSize(listWidth - inset - 1, max(total, viewport))
        popup:SetSize(listWidth, viewport + 2)

        maxScroll = max(0, total - viewport)
        bar:SetMinMaxValues(0, maxScroll)
        scroll:SetVerticalScroll(0)
        bar:SetValue(0)
        if overflow then bar:Show() else bar:Hide() end

        for i, entry in ipairs(entries) do addRow(i, entry) end
    end

    button:SetScript("OnClick", function()
        if popup:IsShown() then
            popup:Hide()
            return
        end
        rebuildRows()
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
        popup:Show()
    end)

    return button, label, chevron
end
Keep("BuildDropdownControl", BuildDropdownControl)

-----------------------------------------------------------------------------------------------------------------------
-- Text input popup
-----------------------------------------------------------------------------------------------------------------------

local inputParts

-- One backdrop button with its centred text.
local function NewInputButton(popup, path, width)
    local button = CreateFrame("Button", nil, popup)
    button:SetSize(width, 28)
    KT:AddBackdrop(button, 0.08, 0.08, 0.11, 1)
    local text = NewText(button, path, 11, "OUTLINE", 1, 1, 1, 1)
    text:SetAllPoints()
    return button, text
end

-- Makes the session's single input popup.
local function BuildInputPopup()
    local path = CoreFont()
    local popup = CreateFrame("Frame", "KT_AuraRemindersInputPopup", UIParent)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetSize(420, 220)
    popup:SetPoint("CENTER")
    popup:Hide()
    KT:AddBackdrop(popup, 0.04, 0.04, 0.05, 0.98)
    KT:AddBorder(popup, 0, 0, 0, 1)

    local title = NewText(popup, path, 12, "OUTLINE", 1, 1, 1, 1)
    title:SetPoint("TOPLEFT", 14, -14)

    local message = NewText(popup, path, 11, "", 0.82, 0.82, 0.82, 1)
    message:SetJustifyH("LEFT")
    message:SetJustifyV("TOP")
    message:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    message:SetPoint("TOPRIGHT", -14, -40)

    local edit = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
    edit:SetAutoFocus(false)
    edit:SetHeight(24)
    edit:SetPoint("TOPLEFT", message, "BOTTOMLEFT", 0, -12)
    edit:SetPoint("TOPRIGHT", -14, -84)
    edit:SetFont(path, 11, "")
    edit:SetTextInsets(4, 4, 4, 4)

    local confirm, confirmText = NewInputButton(popup, path, 110)
    confirm:SetPoint("BOTTOMRIGHT", -14, 14)
    KT:AddAccentBorder(confirm, 0.7)

    local extra, extraText = NewInputButton(popup, path, 130)
    extra:SetPoint("RIGHT", confirm, "LEFT", -8, 0)
    KT:AddBorder(extra, 0.35, 0.35, 0.35, 0.7)

    local cancel, cancelText = NewInputButton(popup, path, 90)
    cancel:SetPoint("RIGHT", extra, "LEFT", -8, 0)
    KT:AddBorder(cancel, 0.35, 0.35, 0.35, 0.7)
    cancelText:SetText(LText("Cancel"))
    cancel:SetScript("OnClick", function() popup:Hide() end)

    return {
        popup = popup, title = title, message = message, edit = edit,
        confirm = confirm, confirmText = confirmText, extra = extra, extraText = extraText,
    }
end

-- Fills and shows the popup; the options in force are this call's.
local function ShowInputPopup(opts)
    opts = opts or {}
    inputParts = inputParts or BuildInputPopup()
    local p = inputParts

    p.title:SetText(opts.title or "")
    p.message:SetText(opts.message or "")
    p.edit:SetText(opts.initialText or "")
    p.confirmText:SetText(opts.confirmText or LText("Save"))
    p.confirm:SetScript("OnClick", function()
        if opts.onConfirm then opts.onConfirm(p.edit:GetText()) end
        p.popup:Hide()
    end)

    local extraButton = opts.extraButton
    if extraButton then
        p.extra:Show()
        p.extraText:SetText(extraButton.text or LText("Extra"))
        p.extra:SetScript("OnClick", function()
            if extraButton.onClick then extraButton.onClick(p.edit) end
        end)
    else
        p.extra:Hide()
    end

    p.popup:Show()
    p.edit:SetFocus()
    p.edit:HighlightText()
end
Keep("ShowInputPopup", ShowInputPopup)

-----------------------------------------------------------------------------------------------------------------------
-- Content header host
-----------------------------------------------------------------------------------------------------------------------

-- Runs a header builder on the current host and anchors the content to the result.
local function ApplyContentHeader(builder)
    headerBuilder = builder
    if not headerHost then return end

    for _, oldChild in ipairs({ headerHost:GetChildren() }) do
        oldChild:Hide()
        oldChild:SetParent(UIParent)
    end

    local hostParent = headerHost:GetParent()
    if type(builder) ~= "function" then
        headerHost:Hide()
        headerHeight = 0
        if sideLayout then return end
        pageContent:ClearAllPoints()
        pageContent:SetPoint("TOPLEFT", hostParent, "TOPLEFT", 0, contentBaseY)
        pageContent:SetPoint("TOPRIGHT", hostParent, "TOPRIGHT", 0, contentBaseY)
        return
    end

    local height = builder(headerHost, sideLayout and sideLayout.previewWidth or hostParent:GetWidth()) or 0
    headerHeight = height
    headerHost:SetHeight(height)
    headerHost:Show()
    if sideLayout then return end
    pageContent:ClearAllPoints()
    pageContent:SetPoint("TOPLEFT", headerHost, "BOTTOMLEFT", 0, -10)
    pageContent:SetPoint("TOPRIGHT", headerHost, "BOTTOMRIGHT", 0, -10)
end

function KT.SetContentHeader(a, b)
    ApplyContentHeader(ArgAfterSelf(a, b))
end

-- Changes only the host's height, so a restyle keeps the scroll position.
function KT.SetContentHeaderHeightSilent(a, b)
    if not headerHost then return end
    local height = ArgAfterSelf(a, b) or 0
    headerHeight = height
    headerHost:SetHeight(height)
    if height > 0 then headerHost:Show() else headerHost:Hide() end
end

-----------------------------------------------------------------------------------------------------------------------
-- Page registration
-----------------------------------------------------------------------------------------------------------------------

-- Runs the current refresher list; one error does not stop the rest.
local function RunRefreshers()
    for _, fn in ipairs(refreshers) do pcall(fn) end
end

local function SelectPage(name)
    selectedPage = name
    KT:RefreshPage(false)
end

-- Adds the sub-tab bar when it applies and returns the height it takes.
local function AddPageTabs(sc, pages)
    if not KT.AddOptionsSubTabBar or #pages <= 1 then return 0 end
    local tabs = {}
    for i, name in ipairs(pages) do
        tabs[i] = { id = name, label = LText(name) }
    end
    local _, height = KT.AddOptionsSubTabBar(sc, 0, tabs, selectedPage, SelectPage)
    return height or 0
end

-- Makes this build's host and content under the tab bar.
local function NewPageFrames(sc, y)
    headerHost = CreateFrame("Frame", nil, sc)
    headerHost:SetWidth(sc:GetWidth())
    headerHost:SetHeight(1)
    headerHost:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, y)
    headerHost:Hide()

    pageContent = CreateFrame("Frame", nil, sc)
    pageContent:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, y)
    pageContent:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, y)
    pageContent:SetHeight(1)

    contentBaseY = y
    headerHeight = 0
end

-- The same frames as two columns: a captioned preview panel on the left, the settings on the right.
local function NewSideFrames(sc, y)
    local previewWidth, gap = sideLayout.previewWidth, sideLayout.gap
    local caption = CreateFrame("Frame", nil, sc)
    caption:SetSize(previewWidth, SIDE_CAPTION_HEIGHT)
    caption:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, y)
    local captionText = NewText(caption, CoreFont(), 11, KT.GetFontOutlineFlag(),
        KT.TEXT_SECTION_R, KT.TEXT_SECTION_G, KT.TEXT_SECTION_B, KT.TEXT_SECTION_A)
    captionText:SetPoint("LEFT", caption, "LEFT", 4, 0)
    captionText:SetText(LText("Preview"))

    headerHost = CreateFrame("Frame", nil, sc)
    headerHost:SetWidth(previewWidth)
    headerHost:SetHeight(1)
    headerHost:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, 0)
    headerHost:Hide()

    -- A sibling behind the host: a header change sends every child of the host away.
    local panel = CreateFrame("Frame", nil, sc)
    panel:SetPoint("TOPLEFT", headerHost, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", headerHost, "BOTTOMRIGHT", 0, 0)
    KT:AddBackdrop(panel, 0.13, 0.13, 0.13, 0.6)
    KT:AddBorder(panel, 1, 1, 1, 0.12)
    headerHost:SetFrameLevel(panel:GetFrameLevel() + 1)

    pageContent = CreateFrame("Frame", nil, sc)
    pageContent:SetPoint("TOPLEFT", sc, "TOPLEFT", previewWidth + gap, y)
    pageContent:SetPoint("TOPRIGHT", sc, "TOPRIGHT", 0, y)
    pageContent:SetHeight(1)

    contentBaseY = y
    headerHeight = 0
end

-- The page's navigation: the module's own when it has one, otherwise the tab bar. Returns the y under it.
-- Only a page with a preview gets the two columns; the others keep the whole width.
local function BuildPageNavigation(sc, def)
    sideLayout = nil
    if def.buildNavigation then
        local height, previewWidth, gap = def.buildNavigation(sc, SelectPage)
        if def.hasPreview and def.hasPreview(selectedPage) then
            sideLayout = { previewWidth = previewWidth, gap = gap }
            NewSideFrames(sc, -height)
        else
            NewPageFrames(sc, -height)
        end
        return -height
    end
    local y = -AddPageTabs(sc, def.pages or {})
    NewPageFrames(sc, y)
    return y
end

-- The whole height of a build: the columns side by side, or the header over the content.
local function PageHeight(y, contentHeight)
    if sideLayout then
        return max(1, abs(y) + max(SIDE_CAPTION_HEIGHT + headerHeight, contentHeight) + 40)
    end
    return max(1, abs(y) + headerHeight + contentHeight + 40)
end

-- Registers the one options page; its builder runs on every page build.
Keep("RegisterModule", function(_, _, def)
    KT:RegisterPage("aurareminders", LText("Aura Reminders"), 15, function(sc)
        refreshers = {}
        sc._kuiFixedViewport = def.usesViewport and def.usesViewport(selectedPage) or false

        local y = BuildPageNavigation(sc, def)

        if def.getHeaderBuilder then
            local builder = def.getHeaderBuilder(selectedPage)
            ApplyContentHeader(builder)
        else
            ApplyContentHeader(nil)
        end

        local contentHeight = 0
        if def.buildPage then
            contentHeight = def.buildPage(selectedPage, pageContent, 0) or 0
        end

        C_Timer.After(0, RunRefreshers)
        if def.onPageCacheRestore then
            C_Timer.After(0, function() def.onPageCacheRestore(selectedPage) end)
        end
        if def.onShow then
            C_Timer.After(0, function() def.onShow() end)
        end

        return PageHeight(y, contentHeight)
    end)
end)

-----------------------------------------------------------------------------------------------------------------------
-- The table the later option files read
-----------------------------------------------------------------------------------------------------------------------

ns.AuraRemindersWidgets = {
    Pages = {
        CONTROL = "Control Center",
        GROUP = "Group Readiness",
        CLASS = "Class Upkeep",
        CONSUMABLES = "Consumable Loadout",
        TALENTS = "Talent Reminders",
        CUSTOM_AURAS = "Custom Auras",
    },
    Sections = {
        DISPLAY = "LOOK & PLACEMENT",
        RAID_BUFFS = "GROUP COVERAGE",
        AURAS = "ASSIGNED & PERSONAL AURAS",
        CONSUMABLES = "LOADOUT CHECKLIST",
        ROGUE = "ROGUE PREPARATION",
        PALADIN = "PALADIN PREPARATION",
        SHAMAN = "SHAMAN PREPARATION",
    },
    LText = LText,
    Reload = Reload,
    AccentColorCode = AccentColorCode,
    AddChevron = AddChevron,
    GetSelectedPage = function() return selectedPage end,
    SetSelectedPage = function(name) selectedPage = name end,
    GetAvailableContentHeight = function()
        local viewport = KT._scrollFrame
        if not viewport or not viewport.GetHeight then return nil end
        return math.max(1, viewport:GetHeight() - math.abs(contentBaseY or 0) - 70)
    end,
}
