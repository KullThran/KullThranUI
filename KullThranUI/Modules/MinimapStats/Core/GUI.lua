local _, MS = ...
local AG = LibStub("AceGUI-3.0")
local GUIActive = false
local GUIFrame = nil
local LSM = MS.LSM

local function ThemeAccentMarkup(text)
    if type(text) ~= "string" then return text end
    local r, g, b = 1, 0, 0.3333333333
    local KT = _G.KT
    if KT and KT.GetStyleAccentRGB then
        r, g, b = KT:GetStyleAccentRGB()
    end
    local function channel(value)
        return math.floor(math.max(0, math.min(1, tonumber(value) or 0)) * 255 + 0.5)
    end
    local code = string.format("|cFF%02X%02X%02X", channel(r), channel(g), channel(b))
    return text:gsub("{KUI_ACCENT}", code):gsub("|cFF8080FF", code):gsub("|cff8080ff", code)
end

local function LT(text)
    if type(text) ~= "string" then
        return text
    end

    local translated = text
    local KT = _G.KT
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] ~= nil then
            translated = L[text]
        end
    end

    return ThemeAccentMarkup(translated)
end

local function LocalizeMap(map)
    local localized = {}
    for key, value in pairs(map) do
        localized[key] = LT(value)
    end
    return localized
end

local Anchors = {
    {
        ["TOPLEFT"] = "Top Left",
        ["TOP"] = "Top",
        ["TOPRIGHT"] = "Top Right",
        ["LEFT"] = "Left",
        ["CENTER"] = "Center",
        ["RIGHT"] = "Right",
        ["BOTTOMLEFT"] = "Bottom Left",
        ["BOTTOM"] = "Bottom",
        ["BOTTOMRIGHT"] = "Bottom Right",
    },
    { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
}

local LuaDateFormats = {
    {
        ["%a"] = "Abbreviated Week Day (Eg. Mon)",
        ["%A"] = "Full Week Day (Eg. Monday)",
        ["%b"] = "Abbreviated Month (Eg. Jan)",
        ["%B"] = "Full Month (Eg. January)",
        ["%d"] = "Numerical Day (Eg. 01–31)",
        ["%m"] = "Numerical Month (Eg. 01–12)",
        ["%y"] = "Two-Digit Year (Eg. 25)",
        ["%Y"] = "Four-Digit Year (Eg. 2024)",
        ["%H"] = "Military Hour (Eg. 00–24)",
        ["%I"] = "Standard Hour (Eg. 01–12)",
        ["%M"] = "Minute (Eg. 00–59)",
        ["%p"] = "AM/PM",
        ["%j"] = "Day of the Year (Eg. 001–366)",
        ["%W"] = "Week Number (Eg. 01–52)",
        ["%Z"] = "Time Zone (Eg. UTC)",
    },
    {
        "%a", "%A", "%b", "%B",
        "%d", "%m", "%y", "%Y",
        "%H", "%I", "%M", "%p",
        "%j", "%W", "%Z",
    }
}

LuaDateFormats[1] = {
    ["%a"] = "Abbreviated Week Day (e.g. Mon)",
    ["%A"] = "Full Week Day (e.g. Monday)",
    ["%b"] = "Abbreviated Month (e.g. Jan)",
    ["%B"] = "Full Month (e.g. January)",
    ["%d"] = "Numerical Day (e.g. 01-31)",
    ["%m"] = "Numerical Month (e.g. 01-12)",
    ["%y"] = "Two-Digit Year (e.g. 25)",
    ["%Y"] = "Four-Digit Year (e.g. 2024)",
    ["%H"] = "24-Hour Format (e.g. 00-24)",
    ["%I"] = "12-Hour Format (e.g. 01-12)",
    ["%M"] = "Minute (e.g. 00-59)",
    ["%p"] = "AM/PM",
    ["%j"] = "Day of the Year (e.g. 001-366)",
    ["%W"] = "Week Number (e.g. 01-52)",
    ["%Z"] = "Time Zone (e.g. UTC)",
}

local function CreateInfoTag(Description)
    local InfoDesc = AG:Create("Label")
    InfoDesc:SetText(MS.InfoButton .. LT(Description))
    InfoDesc:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    InfoDesc:SetFullWidth(true)
    InfoDesc:SetJustifyH("CENTER")
    InfoDesc:SetHeight(24)
    InfoDesc:SetJustifyV("MIDDLE")
    return InfoDesc
end

local function DeepDisable(widget, disabled)
    if widget.SetDisabled then widget:SetDisabled(disabled) end
    if widget.children then
        for _, child in ipairs(widget.children) do
            DeepDisable(child, disabled)
        end
    end
end

local function DisableElements(parentContainer, widget, value)
    for _, child in ipairs(parentContainer.children) do
        if child ~= widget then
            DeepDisable(child, not value)
        end
    end
end

local function UpdateRateWarning(rate, defaultRate)
    if rate < (defaultRate) then
        return LT("Update Interval (Seconds) - |cFFFF4040High CPU Usage|r")
    end
    return LT("Update Interval (Seconds)")
end

local function SetupTabGroup(parentContainer, headingTitle)
    local ContainerScrollFrame = AG:Create("ScrollFrame")
    ContainerScrollFrame:SetLayout("Flow")
    ContainerScrollFrame:SetFullHeight(true)
    ContainerScrollFrame:SetFullWidth(true)
    parentContainer:AddChild(ContainerScrollFrame)

    return ContainerScrollFrame
end

local function ShowConfigTooltip(owner, point, relativeTo, relativePoint, xOffset, yOffset, text)
    local tooltip = MS:GetTooltipFrame("Config")
    tooltip:SetOwner(owner, "ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint(point, relativeTo or owner, relativePoint or point, xOffset or 0, yOffset or 0)
    tooltip:SetText(LT(text), 1, 1, 1, 1, false)
    tooltip:Show()
end

local function HideConfigTooltip()
    MS:HideTooltipFrame("Config")
end

local function CreateLayoutGroup(parentContainer, dbValue, updateFunction)
    local AnchorFromDropdown = AG:Create("Dropdown")
    AnchorFromDropdown:SetLabel(LT("Anchor From"))
    AnchorFromDropdown:SetList(LocalizeMap(Anchors[1]), Anchors[2])
    AnchorFromDropdown:SetValue(dbValue[1])
    AnchorFromDropdown:SetRelativeWidth(0.5)
    AnchorFromDropdown:SetCallback("OnValueChanged", function(_, _, value) dbValue[1] = value updateFunction() end)
    parentContainer:AddChild(AnchorFromDropdown)

    local AnchorToDropdown = AG:Create("Dropdown")
    AnchorToDropdown:SetLabel(LT("Anchor To"))
    AnchorToDropdown:SetList(LocalizeMap(Anchors[1]), Anchors[2])
    AnchorToDropdown:SetValue(dbValue[2])
    AnchorToDropdown:SetRelativeWidth(0.5)
    AnchorToDropdown:SetCallback("OnValueChanged", function(_, _, value) dbValue[2] = value updateFunction() end)
    parentContainer:AddChild(AnchorToDropdown)

    local XOffsetSlider = AG:Create("Slider")
    XOffsetSlider:SetLabel(LT("X Offset"))
    XOffsetSlider:SetValue(dbValue[3])
    XOffsetSlider:SetSliderValues(-200, 200, 1)
    XOffsetSlider:SetRelativeWidth(0.33)
    XOffsetSlider:SetCallback("OnValueChanged", function(_, _, value) dbValue[3] = value updateFunction() end)
    parentContainer:AddChild(XOffsetSlider)

    local YOffsetSlider = AG:Create("Slider")
    YOffsetSlider:SetLabel(LT("Y Offset"))
    YOffsetSlider:SetValue(dbValue[4])
    YOffsetSlider:SetSliderValues(-200, 200, 1)
    YOffsetSlider:SetRelativeWidth(0.33)
    YOffsetSlider:SetCallback("OnValueChanged", function(_, _, value) dbValue[4] = value updateFunction() end)
    parentContainer:AddChild(YOffsetSlider)

    local FontSizeSlider = AG:Create("Slider")
    FontSizeSlider:SetLabel(LT("Font Size"))
    FontSizeSlider:SetValue(dbValue[5])
    FontSizeSlider:SetSliderValues(6, 32, 1)
    FontSizeSlider:SetRelativeWidth(0.33)
    FontSizeSlider:SetCallback("OnValueChanged", function(_, _, value) dbValue[5] = value updateFunction()end)
    parentContainer:AddChild(FontSizeSlider)
end

local function GetPreviewText(frameObject, fallbackText)
    if frameObject and frameObject.Text and frameObject.Text.GetText then
        local text = frameObject.Text:GetText()
        if text ~= nil and text ~= "" then
            return ThemeAccentMarkup(text)
        end
    end

    return ThemeAccentMarkup(fallbackText or "")
end

local function ApplyPreviewStyle(fontString, dbSection, previewAnchor)
    local GeneralDB = MS.db.global.General
    local SectionDB = MS.db.global[dbSection]
    if not (fontString and SectionDB and previewAnchor) then return end

    fontString:ClearAllPoints()
    fontString:SetPoint(SectionDB.Layout[1], previewAnchor, SectionDB.Layout[2], SectionDB.Layout[3], SectionDB.Layout[4])
    fontString:SetJustifyH(MS:SetJustification(SectionDB.Layout[1]))
    fontString:SetFont(MS.ResolveFont(GeneralDB.Font), SectionDB.Layout[5], GeneralDB.FontFlag)
    fontString:SetShadowColor((GeneralDB.FontShadow.Colour[1] or 0) / 255, (GeneralDB.FontShadow.Colour[2] or 0) / 255, (GeneralDB.FontShadow.Colour[3] or 0) / 255, 1)
    fontString:SetShadowOffset(GeneralDB.FontShadow.OffsetX or 0, GeneralDB.FontShadow.OffsetY or 0)
    fontString:SetTextColor((SectionDB.Colour[1] or 255) / 255, (SectionDB.Colour[2] or 255) / 255, (SectionDB.Colour[3] or 255) / 255, 1)
end

function MS:RefreshMinimapStatsPreview()
    local preview = MS.MinimapStatsPreview
    if not preview then return end

    local DB = MS.db.global
    local defaults = {
        Time = "13:37",
        SystemStats = "144{KUI_ACCENT}FPS|r | 23{KUI_ACCENT}MS|r",
        Location = "|cFF80FF80Stormwind City|r",
        Coordinates = "{KUI_ACCENT}45.3|r|cFFFFFFFF,|r {KUI_ACCENT}62.7|r",
        InstanceDifficulty = "25{KUI_ACCENT}H|r",
    }

    local mapping = {
        { key = "Time", frame = MS.TimeFrame, fallback = defaults.Time },
        { key = "SystemStats", frame = MS.SystemStatsFrame, fallback = defaults.SystemStats },
        { key = "Location", frame = MS.LocationFrame, fallback = defaults.Location },
        { key = "Coordinates", frame = MS.CoordinatesFrame, fallback = defaults.Coordinates },
        { key = "InstanceDifficulty", frame = MS.InstanceDifficultyFrame, fallback = defaults.InstanceDifficulty },
    }

    for _, info in ipairs(mapping) do
        local fontString = preview.text[info.key]
        if fontString then
            ApplyPreviewStyle(fontString, info.key, preview.minimap)
            fontString:SetText(GetPreviewText(info.frame, info.fallback))
            if DB[info.key] and DB[info.key].Enable then
                fontString:Show()
            else
                fontString:Hide()
            end
        end
    end
end

local function CreateMinimapStatsPreview(parentContainer)
    local PreviewContainer = AG:Create("InlineGroup")
    PreviewContainer:SetTitle(LT("KUI Preview"))
    PreviewContainer:SetLayout("Fill")
    PreviewContainer:SetFullWidth(true)
    PreviewContainer:SetHeight(300)
    parentContainer:AddChild(PreviewContainer)

    local PreviewRoot = CreateFrame("Frame", nil, PreviewContainer.content, "BackdropTemplate")
    PreviewRoot:SetAllPoints(PreviewContainer.content)

    local PreviewMinimap = CreateFrame("Frame", nil, PreviewRoot, "BackdropTemplate")
    PreviewMinimap:SetSize(220, 220)
    PreviewMinimap:SetPoint("CENTER", PreviewRoot, "CENTER", 0, -4)
    PreviewMinimap:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    PreviewMinimap:SetBackdropColor(0.06, 0.08, 0.11, 0.92)
    PreviewMinimap:SetBackdropBorderColor(0.22, 0.26, 0.32, 0.9)

    local PreviewMapTexture = PreviewMinimap:CreateTexture(nil, "BACKGROUND")
    PreviewMapTexture:SetAllPoints()
    PreviewMapTexture:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    PreviewMapTexture:SetVertexColor(0.14, 0.18, 0.24, 0.55)

    local PreviewHighlight = PreviewMinimap:CreateTexture(nil, "ARTWORK")
    PreviewHighlight:SetPoint("TOPLEFT", PreviewMinimap, "TOPLEFT", 1, -1)
    PreviewHighlight:SetPoint("BOTTOMRIGHT", PreviewMinimap, "BOTTOMRIGHT", -1, 1)
    PreviewHighlight:SetTexture("Interface\\Buttons\\WHITE8x8")
    PreviewHighlight:SetVertexColor(1, 1, 1, 0.03)

    local PreviewLabel = PreviewRoot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    PreviewLabel:SetPoint("TOP", PreviewMinimap, "BOTTOM", 0, -10)
    PreviewLabel:SetText(LT("Live layout around minimap"))
    PreviewLabel:SetTextColor(0.8, 0.82, 0.88, 0.85)

    MS.MinimapStatsPreview = {
        container = PreviewContainer,
        root = PreviewRoot,
        minimap = PreviewMinimap,
        text = {
            Time = PreviewRoot:CreateFontString(nil, "OVERLAY"),
            SystemStats = PreviewRoot:CreateFontString(nil, "OVERLAY"),
            Location = PreviewRoot:CreateFontString(nil, "OVERLAY"),
            Coordinates = PreviewRoot:CreateFontString(nil, "OVERLAY"),
            InstanceDifficulty = PreviewRoot:CreateFontString(nil, "OVERLAY"),
        },
        elapsed = 0,
    }

    PreviewRoot:SetScript("OnUpdate", function(_, elapsed)
        local preview = MS.MinimapStatsPreview
        if not preview then return end

        preview.elapsed = (preview.elapsed or 0) + elapsed
        if preview.elapsed >= 0.2 then
            preview.elapsed = 0
            MS:RefreshMinimapStatsPreview()
        end
    end)

    MS:RefreshMinimapStatsPreview()
end

function MS:CreateGUI(TabToOpen)
    local DB = MS.db.global
    if GUIActive then return end
    if TabToOpen == nil then TabToOpen = "General" end
    MS.TestInstanceDifficulty = true
    GUIActive = true
    GUIFrame = AG:Create("Frame")
    GUIFrame:SetTitle(MS.AddOnName)
    GUIFrame:SetStatusText("MinimapStats v" .. MS.Version)
    GUIFrame:SetLayout("Flow")
    GUIFrame:SetWidth(720)
    GUIFrame:SetHeight(480)
    GUIFrame:SetCallback("OnClose", function() MS.TestInstanceDifficulty = false MS:UpdateInstanceDifficulty() GUIActive = false MS.MinimapStatsPreview = nil AG:Release(GUIFrame) end)
    GUIFrame:EnableResize(false)
    GUIFrame:Show()
    MS:UpdateInstanceDifficulty()

    function MS:CreateGeneralOptions(Container)
        local ScrollFrame = SetupTabGroup(Container, "General Options")

        local GlobalContainer = AG:Create("InlineGroup")
        GlobalContainer:SetTitle(LT("Global"))
        GlobalContainer:SetLayout("Flow")
        GlobalContainer:SetFullWidth(true)
        ScrollFrame:AddChild(GlobalContainer)

        local ClassColour = AG:Create("CheckBox")
        ClassColour:SetLabel(LT("Class Colour Accent"))
        ClassColour:SetValue(DB.General.ClassColour)
        ClassColour:SetRelativeWidth(0.33)
        ClassColour:SetCallback("OnValueChanged", function(_, _, value) DB.General.ClassColour = value MS:UpdateAll() MS.AccentColourPicker:SetDisabled(value) if value then MS.AccentColourPicker:SetColor(MS.CLASS_COLOUR[1] / 255, MS.CLASS_COLOUR[2] / 255, MS.CLASS_COLOUR[3] / 255) else MS.AccentColourPicker:SetColor(DB.General.AccentColour[1]/255, DB.General.AccentColour[2]/255, DB.General.AccentColour[3]/255) end end)
        GlobalContainer:AddChild(ClassColour)

        local AccentColourPicker = AG:Create("ColorPicker")
        AccentColourPicker:SetLabel(LT("Accent Colour"))
        AccentColourPicker:SetColor(DB.General.ClassColour and (MS.CLASS_COLOUR[1] / 255) or (DB.General.AccentColour[1]/255), DB.General.ClassColour and (MS.CLASS_COLOUR[2] / 255) or (DB.General.AccentColour[2]/255), DB.General.ClassColour and (MS.CLASS_COLOUR[3] / 255) or (DB.General.AccentColour[3]/255))
        AccentColourPicker:SetHasAlpha(false)
        AccentColourPicker:SetRelativeWidth(0.33)
        AccentColourPicker:SetCallback("OnValueChanged", function(_, _, r, g, b) DB.General.AccentColour = {r*255, g*255, b*255} MS:UpdateAll() end)
        AccentColourPicker:SetDisabled(DB.General.ClassColour)
        MS.AccentColourPicker = AccentColourPicker
        GlobalContainer:AddChild(AccentColourPicker)

        local FrameStrataDropdown = AG:Create("Dropdown")
        FrameStrataDropdown:SetLabel(LT("Frame Strata"))
        FrameStrataDropdown:SetList(LocalizeMap({ ["BACKGROUND"] = "Background", ["LOW"] = "Low", ["MEDIUM"] = "Medium", ["HIGH"] = "High", ["DIALOG"] = "Dialog", ["FULLSCREEN"] = "Fullscreen", ["FULLSCREEN_DIALOG"] = "Fullscreen Dialog", ["TOOLTIP"] = "Tooltip" }), { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" })
        FrameStrataDropdown:SetValue(DB.General.FrameStrata)
        FrameStrataDropdown:SetRelativeWidth(0.33)
        FrameStrataDropdown:SetCallback("OnValueChanged", function(_, _, value) DB.General.FrameStrata = value MS:UpdateAll() end)
        GlobalContainer:AddChild(FrameStrataDropdown)

        local FontContainer = AG:Create("InlineGroup")
        FontContainer:SetTitle(LT("Font"))
        FontContainer:SetLayout("Flow")
        FontContainer:SetFullWidth(true)
        ScrollFrame:AddChild(FontContainer)

        local FontDropdown = AG:Create("LSM30_Font")
        FontDropdown:SetLabel(LT("Font"))
        FontDropdown:SetList(LSM:HashTable("font"))
        FontDropdown:SetValue(DB.General.Font)
        FontDropdown:SetRelativeWidth(0.5)
        FontDropdown:SetCallback("OnValueChanged", function(widget, _, value) widget:SetValue(value) DB.General.Font = value MS:UpdateAll() end)
        FontContainer:AddChild(FontDropdown)

        local FontFlagDropdown = AG:Create("Dropdown")
        FontFlagDropdown:SetLabel(LT("Font Outline"))
        FontFlagDropdown:SetList(LocalizeMap({ ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline", ["MONOCHROME"] = "Monochrome" }), { "NONE", "OUTLINE", "THICKOUTLINE", "MONOCHROME" })
        FontFlagDropdown:SetValue(DB.General.FontFlag)
        FontFlagDropdown:SetRelativeWidth(0.5)
        FontFlagDropdown:SetCallback("OnValueChanged", function(_, _, value) DB.General.FontFlag = value MS:UpdateAll() end)
        FontContainer:AddChild(FontFlagDropdown)

        local FontShadowHeading = AG:Create("Heading")
        FontShadowHeading:SetText(LT("Font Shadow"))
        FontShadowHeading:SetFullWidth(true)
        FontContainer:AddChild(FontShadowHeading)

        local ShadowColourColourPicker = AG:Create("ColorPicker")
        ShadowColourColourPicker:SetLabel(LT("Font Shadow Colour"))
        ShadowColourColourPicker:SetColor(DB.General.FontShadow.Colour and (DB.General.FontShadow.Colour[1]/255) or 0, DB.General.FontShadow.Colour and (DB.General.FontShadow.Colour[2]/255) or 0, DB.General.FontShadow.Colour and (DB.General.FontShadow.Colour[3]/255) or 0)
        ShadowColourColourPicker:SetHasAlpha(false)
        ShadowColourColourPicker:SetRelativeWidth(0.33)
        ShadowColourColourPicker:SetCallback("OnValueChanged", function(_, _, r, g, b) DB.General.FontShadow.Colour = {r*255, g*255, b*255} MS:UpdateAll() end)
        FontContainer:AddChild(ShadowColourColourPicker)

        local ShadowXOffsetSlider = AG:Create("Slider")
        ShadowXOffsetSlider:SetLabel(LT("Font Shadow X Offset"))
        ShadowXOffsetSlider:SetValue(DB.General.FontShadow.OffsetX or 1)
        ShadowXOffsetSlider:SetSliderValues(-5, 5, 1)
        ShadowXOffsetSlider:SetRelativeWidth(0.33)
        ShadowXOffsetSlider:SetCallback("OnValueChanged", function(_, _, value) DB.General.FontShadow.OffsetX = value MS:UpdateAll() end)
        FontContainer:AddChild(ShadowXOffsetSlider)

        local ShadowYOffsetSlider = AG:Create("Slider")
        ShadowYOffsetSlider:SetLabel(LT("Font Shadow Y Offset"))
        ShadowYOffsetSlider:SetValue(DB.General.FontShadow.OffsetY or -1)
        ShadowYOffsetSlider:SetSliderValues(-5, 5, 1)
        ShadowYOffsetSlider:SetRelativeWidth(0.33)
        ShadowYOffsetSlider:SetCallback("OnValueChanged", function(_, _, value) DB.General.FontShadow.OffsetY = value MS:UpdateAll() end)
        FontContainer:AddChild(ShadowYOffsetSlider)

        local ResetOptionsContainer = AG:Create("InlineGroup")
        ResetOptionsContainer:SetTitle(LT("Reset Options"))
        ResetOptionsContainer:SetLayout("Flow")
        ResetOptionsContainer:SetFullWidth(true)
        ScrollFrame:AddChild(ResetOptionsContainer)

        local ResetOptions = {"All", "General", "Time", "System Stats", "Coordinates", "Location", "Instance Difficulty", "Tooltip"}
        local ResetSelections = {}
        local Checkboxes = {}

        for _, options in ipairs(ResetOptions) do
            local OptionCheckBox = AG:Create("CheckBox")
            OptionCheckBox:SetLabel(LT(options))
            OptionCheckBox:SetValue(false)
            OptionCheckBox:SetRelativeWidth(0.25)
            Checkboxes[options] = OptionCheckBox

            OptionCheckBox:SetCallback("OnValueChanged", function(_, _, isSelected)
                ResetSelections[options] = isSelected
                if options == "All" then
                    for _, otherOptions in ipairs(ResetOptions) do
                        if otherOptions ~= "All" then
                            ResetSelections[otherOptions] = isSelected
                            Checkboxes[otherOptions]:SetValue(isSelected)
                            Checkboxes[otherOptions]:SetDisabled(isSelected)
                        end
                    end
                else
                    if not isSelected then ResetSelections["All"] = false Checkboxes["All"]:SetValue(false) end
                end

                local resetButtonLabel = ""
                if ResetSelections["All"] then resetButtonLabel = LT("Reset All")
                else
                    local selectedOptions = {}
                    for key, value in pairs(ResetSelections) do
                        if value and key ~= "All" then
                            table.insert(selectedOptions, LT(key))
                        end
                    end

                    if #selectedOptions == 0 then
                        resetButtonLabel = LT("Select Options to Reset...")
                    else
                        resetButtonLabel = string.format(LT("Reset: %s"), table.concat(selectedOptions, ", "))
                    end
                end

                MS.ResetButton:SetText(resetButtonLabel)
            end)

            ResetOptionsContainer:AddChild(OptionCheckBox)
        end

        local ResetButton = AG:Create("Button")
        ResetButton:SetText(LT("Select Options to Reset..."))
        ResetButton:SetRelativeWidth(1)
        MS.ResetButton = ResetButton

        ResetButton:SetCallback("OnClick", function()
            local selectedOptions = {}
            for key, value in pairs(ResetSelections) do
                if value then table.insert(selectedOptions, key) end
            end

            if tContains(selectedOptions, "All") then
                MS:Reset("All")
                return
            end

            for _, option in ipairs(selectedOptions) do
                MS:Reset(option)
            end
        end)

        ResetOptionsContainer:AddChild(ResetButton)

        CreateMinimapStatsPreview(ScrollFrame)

        GlobalContainer:DoLayout()
        FontContainer:DoLayout()
        ScrollFrame:DoLayout()
    end

    function MS:CreateTimeOptions(Container)
        local ScrollFrame = SetupTabGroup(Container, "Time Options")

        local Enable = AG:Create("CheckBox")
        Enable:SetLabel(LT("Enable {KUI_ACCENT}Time|r"))
        Enable:SetValue(DB.Time.Enable)
        Enable:SetRelativeWidth(1)
        Enable:SetCallback("OnValueChanged", function(_, _, value) DB.Time.Enable = value MS:UpdateTime() DisableElements(ScrollFrame, Enable, value) end)
        ScrollFrame:AddChild(Enable)

        local ElementOptionsContainer = AG:Create("InlineGroup")
        ElementOptionsContainer:SetTitle(LT("Element Options"))
        ElementOptionsContainer:SetLayout("Flow")
        ElementOptionsContainer:SetFullWidth(true)
        ScrollFrame:AddChild(ElementOptionsContainer)

        local ColourPicker = AG:Create("ColorPicker")
        ColourPicker:SetLabel(LT("Text Colour"))
        ColourPicker:SetColor(DB.Time.Colour[1]/255, DB.Time.Colour[2]/255, DB.Time.Colour[3]/255)
        ColourPicker:SetHasAlpha(false)
        ColourPicker:SetRelativeWidth(0.5)
        ColourPicker:SetCallback("OnValueChanged", function(_, _, r, g, b) DB.Time.Colour = {r*255, g*255, b*255} MS:UpdateTime() end)
        ElementOptionsContainer:AddChild(ColourPicker)

        local UpdateIntervalSlider = AG:Create("Slider")
        UpdateIntervalSlider:SetLabel(UpdateRateWarning(DB.Time.UpdateInterval, 30.0))
        UpdateIntervalSlider:SetValue(DB.Time.UpdateInterval)
        UpdateIntervalSlider:SetSliderValues(0.1, 60.0, 0.1)
        UpdateIntervalSlider:SetRelativeWidth(0.5)
        UpdateIntervalSlider:SetCallback("OnValueChanged", function(_, _, value) DB.Time.UpdateInterval = value MS:UpdateTime() UpdateIntervalSlider:SetLabel(UpdateRateWarning(value, 30.0)) end)
        ElementOptionsContainer:AddChild(UpdateIntervalSlider)

        local TimeZoneDropdown = AG:Create("Dropdown")
        TimeZoneDropdown:SetLabel(LT("Time Zone"))
        TimeZoneDropdown:SetList(LocalizeMap({ ["Local"] = "Local", ["Realm"] = "Realm" }))
        TimeZoneDropdown:SetValue(DB.Time.TimeZone)
        TimeZoneDropdown:SetRelativeWidth(0.5)
        TimeZoneDropdown:SetCallback("OnValueChanged", function(_, _, value) DB.Time.TimeZone = value MS:UpdateTime() end)
        ElementOptionsContainer:AddChild(TimeZoneDropdown)

        local TimeFormatDropdown = AG:Create("Dropdown")
        TimeFormatDropdown:SetLabel(LT("Time Format"))
        TimeFormatDropdown:SetList(LocalizeMap({ ["12H"] = "12-Hour", ["24H"] = "24-Hour" }))
        TimeFormatDropdown:SetValue(DB.Time.Format)
        TimeFormatDropdown:SetRelativeWidth(0.5)
        TimeFormatDropdown:SetCallback("OnValueChanged", function(_, _, value) DB.Time.Format = value MS:UpdateTime() end)
        ElementOptionsContainer:AddChild(TimeFormatDropdown)

        local LayoutContainer = AG:Create("InlineGroup")
        LayoutContainer:SetTitle(LT("Layout"))
        LayoutContainer:SetLayout("Flow")
        LayoutContainer:SetFullWidth(true)
        ScrollFrame:AddChild(LayoutContainer)

        CreateLayoutGroup(LayoutContainer, DB.Time.Layout, function() MS:UpdateTime() end)
        CreateMinimapStatsPreview(ScrollFrame)

        DisableElements(ScrollFrame, Enable, DB.Time.Enable)
        LayoutContainer:DoLayout()
        ScrollFrame:DoLayout()
    end

    function MS:CreateSystemStatsOptions(Container)
        local ScrollFrame = SetupTabGroup(Container, "System Stats Options")

        local Enable = AG:Create("CheckBox")
        Enable:SetLabel(LT("Enable {KUI_ACCENT}System Stats|r"))
        Enable:SetValue(DB.SystemStats.Enable)
        Enable:SetRelativeWidth(1)
        Enable:SetCallback("OnValueChanged", function(_, _, value) DB.SystemStats.Enable = value MS:UpdateSystemStats() DisableElements(ScrollFrame, Enable, value) end)
        ScrollFrame:AddChild(Enable)

        local ElementOptionsContainer = AG:Create("InlineGroup")
        ElementOptionsContainer:SetTitle(LT("Element Options"))
        ElementOptionsContainer:SetLayout("Flow")
        ElementOptionsContainer:SetFullWidth(true)
        ScrollFrame:AddChild(ElementOptionsContainer)

        local ColourPicker = AG:Create("ColorPicker")
        ColourPicker:SetLabel(LT("Text Colour"))
        ColourPicker:SetColor(DB.SystemStats.Colour[1]/255, DB.SystemStats.Colour[2]/255, DB.SystemStats.Colour[3]/255)
        ColourPicker:SetHasAlpha(false)
        ColourPicker:SetRelativeWidth(0.5)
        ColourPicker:SetCallback("OnValueChanged", function(_, _, r, g, b) DB.SystemStats.Colour = {r*255, g*255, b*255} MS:UpdateSystemStats() end)
        ElementOptionsContainer:AddChild(ColourPicker)

        local UpdateIntervalSlider = AG:Create("Slider")
        UpdateIntervalSlider:SetLabel(UpdateRateWarning(DB.SystemStats.UpdateInterval, 3.0))
        UpdateIntervalSlider:SetValue(DB.SystemStats.UpdateInterval)
        UpdateIntervalSlider:SetSliderValues(0.1, 60.0, 0.1)
        UpdateIntervalSlider:SetRelativeWidth(0.5)
        UpdateIntervalSlider:SetCallback("OnValueChanged", function(_, _, value) DB.SystemStats.UpdateInterval = value MS:UpdateSystemStats() UpdateIntervalSlider:SetLabel(UpdateRateWarning(value, 3.0)) end)
        ElementOptionsContainer:AddChild(UpdateIntervalSlider)

        local StringCreationContainer = AG:Create("InlineGroup")
        StringCreationContainer:SetTitle(LT("Stats Creation"))
        StringCreationContainer:SetLayout("Flow")
        StringCreationContainer:SetFullWidth(true)
        ElementOptionsContainer:AddChild(StringCreationContainer)

        local StringChoices = {
            {
                [""] = "None",
                ["%fps"] = "FPS",
                ["%world"] = "MS (World)",
                ["%home"] = "MS (Home)",
                ["%down"] = "Bandwidth (Down)",
                ["%up"] = "Bandwidth (Up)",
                ["%shortdate"] = "Date (01 Jan 99)",
                ["%longdate"] = "Date (01 January 1999)",
            },
            { "", "%fps", "%home", "%world", "%down", "%up", "%shortdate", "%longdate"}
        }

        local DisplayStringEditBox = AG:Create("EditBox")
        DisplayStringEditBox:SetLabel(LT("Display String"))
        DisplayStringEditBox:SetText(DB.SystemStats.String)
        DisplayStringEditBox:SetRelativeWidth(0.5)
        DisplayStringEditBox:SetCallback("OnTextChanged", function(_, _, value) DB.SystemStats.String = value MS:UpdateSystemStats() end)
        DisplayStringEditBox:SetCallback("OnEnterPressed", function(_, _, value) DB.SystemStats.String = value MS:UpdateSystemStats() DisplayStringEditBox:ClearFocus() end)
        DisplayStringEditBox:SetCallback("OnLeave", function() HideConfigTooltip() end)
        DisplayStringEditBox:SetCallback("OnEnter", function() local tooltipText = "" for _, token in ipairs(StringChoices[2]) do if token ~= "" then tooltipText = tooltipText .. "- {KUI_ACCENT}" .. token .. "|r - " .. LT(StringChoices[1][token]) .. "\n" end end tooltipText = tooltipText .. "\n|cFFFFFFFF" .. LT("Supported Date Tokens:") .. "|r\n" for _, code in ipairs(LuaDateFormats[2]) do tooltipText = tooltipText .. "- {KUI_ACCENT}" .. code .. "|r - " .. LT(LuaDateFormats[1][code]) .. "\n" end tooltipText = tooltipText .. "\n" .. MS.InfoButton .. "{KUI_ACCENT}" .. LT("New Line ('\\n') is also supported!") .. "|r" ShowConfigTooltip(DisplayStringEditBox.frame, "LEFT", DisplayStringEditBox.frame, "RIGHT", 3, 0, tooltipText) end)
        StringCreationContainer:AddChild(DisplayStringEditBox)

        local StatDropdown = AG:Create("Dropdown")
        StatDropdown:SetLabel(LT("Add Stat"))
        StatDropdown:SetList(LocalizeMap(StringChoices[1]), StringChoices[2])
        StatDropdown:SetValue("")
        StatDropdown:SetRelativeWidth(0.5)
        StatDropdown:SetCallback("OnValueChanged", function(_, _, value) DisplayStringEditBox:SetText(DisplayStringEditBox:GetText() .. value) DB.SystemStats.String = DisplayStringEditBox:GetText() MS:UpdateSystemStats() StatDropdown:SetValue("") end)
        StringCreationContainer:AddChild(StatDropdown)

        local LayoutContainer = AG:Create("InlineGroup")
        LayoutContainer:SetTitle(LT("Layout"))
        LayoutContainer:SetLayout("Flow")
        LayoutContainer:SetFullWidth(true)
        ScrollFrame:AddChild(LayoutContainer)

        CreateLayoutGroup(LayoutContainer, DB.SystemStats.Layout, function() MS:UpdateSystemStats() end)
        CreateMinimapStatsPreview(ScrollFrame)

        DisableElements(ScrollFrame, Enable, DB.SystemStats.Enable)

        StringCreationContainer:DoLayout()
        LayoutContainer:DoLayout()
        ScrollFrame:DoLayout()
    end

    function MS:CreateLocationOptions(Container)
        local ScrollFrame = SetupTabGroup(Container, "Location Options")

        local Enable = AG:Create("CheckBox")
        Enable:SetLabel(LT("Enable {KUI_ACCENT}Location|r"))
        Enable:SetValue(DB.Location.Enable)
        Enable:SetRelativeWidth(1)
        Enable:SetCallback("OnValueChanged", function(_, _, value) DB.Location.Enable = value MS:UpdateLocation() DisableElements(ScrollFrame, Enable, value) end)
        ScrollFrame:AddChild(Enable)

        local ElementOptionsContainer = AG:Create("InlineGroup")
        ElementOptionsContainer:SetTitle(LT("Element Options"))
        ElementOptionsContainer:SetLayout("Flow")
        ElementOptionsContainer:SetFullWidth(true)
        ScrollFrame:AddChild(ElementOptionsContainer)

        local ShowSubZone = AG:Create("CheckBox")
        ShowSubZone:SetLabel(LT("Display Sub Zone"))
        ShowSubZone:SetValue(DB.Location.SubZone)
        ShowSubZone:SetRelativeWidth(0.33)
        ShowSubZone:SetCallback("OnEnter", function() ShowConfigTooltip(ShowSubZone.frame, "LEFT", ShowSubZone.text, "LEFT", 120, 0, MS.InfoButton .. LT("This shows you the {KUI_ACCENT}sub zone|r instead of the {KUI_ACCENT}main zone|r.")) end)
        ShowSubZone:SetCallback("OnLeave", function() HideConfigTooltip() end)
        ShowSubZone:SetCallback("OnValueChanged", function(_, _, value) DB.Location.SubZone = value MS:UpdateLocation() end)
        ElementOptionsContainer:AddChild(ShowSubZone)

        local ColourByDropdown = AG:Create("Dropdown")
        ColourByDropdown:SetLabel(LT("Colour By"))
        ColourByDropdown:SetList(LocalizeMap({ ["REACTION"] = "Reaction", ["CUSTOM"] = "Custom", ["ACCENT"] = "Accent" }), { "REACTION", "ACCENT", "CUSTOM" })
        ColourByDropdown:SetValue(DB.Location.ColourBy)
        ColourByDropdown:SetRelativeWidth(0.33)
        ColourByDropdown:SetCallback("OnValueChanged", function(_, _, value) DB.Location.ColourBy = value MS:UpdateLocation() if value == "CUSTOM" then MS.ColourPicker:SetDisabled(false) else MS.ColourPicker:SetDisabled(true) end end)
        ElementOptionsContainer:AddChild(ColourByDropdown)

        local ColourPicker = AG:Create("ColorPicker")
        ColourPicker:SetLabel(LT("Text Colour"))
        ColourPicker:SetColor(DB.Location.Colour[1]/255, DB.Location.Colour[2]/255, DB.Location.Colour[3]/255)
        ColourPicker:SetHasAlpha(false)
        ColourPicker:SetRelativeWidth(0.33)
        ColourPicker:SetCallback("OnValueChanged", function(_, _, r, g, b) DB.Location.Colour = {r*255, g*255, b*255} MS:UpdateLocation() end)
        MS.ColourPicker = ColourPicker
        ElementOptionsContainer:AddChild(ColourPicker)

        local LayoutContainer = AG:Create("InlineGroup")
        LayoutContainer:SetTitle(LT("Layout"))
        LayoutContainer:SetLayout("Flow")
        LayoutContainer:SetFullWidth(true)
        ScrollFrame:AddChild(LayoutContainer)

        CreateLayoutGroup(LayoutContainer, DB.Location.Layout, function() MS:UpdateLocation() end)
        CreateMinimapStatsPreview(ScrollFrame)

        DisableElements(ScrollFrame, Enable, DB.Location.Enable)

        if DB.Location.ColourBy == "CUSTOM" then ColourPicker:SetDisabled(false) else ColourPicker:SetDisabled(true) end

        LayoutContainer:DoLayout()
        ScrollFrame:DoLayout()
    end

    function MS:CreateInstanceDifficultyOptions(Container)
        local ScrollFrame = SetupTabGroup(Container, "Instance Difficulty Options")

        local Enable = AG:Create("CheckBox")
        Enable:SetLabel(LT("Enable {KUI_ACCENT}Instance Difficulty|r"))
        Enable:SetValue(DB.InstanceDifficulty.Enable)
        Enable:SetRelativeWidth(1)
        Enable:SetCallback("OnValueChanged", function(_, _, value) DB.InstanceDifficulty.Enable = value MS:UpdateInstanceDifficulty() DisableElements(ScrollFrame, Enable, value) end)
        ScrollFrame:AddChild(Enable)

        local ElementOptionsContainer = AG:Create("InlineGroup")
        ElementOptionsContainer:SetTitle(LT("Element Options"))
        ElementOptionsContainer:SetLayout("Flow")
        ElementOptionsContainer:SetFullWidth(true)
        ScrollFrame:AddChild(ElementOptionsContainer)

        local ColourPicker = AG:Create("ColorPicker")
        ColourPicker:SetLabel(LT("Text Colour"))
        ColourPicker:SetColor(DB.InstanceDifficulty.Colour[1]/255, DB.InstanceDifficulty.Colour[2]/255, DB.InstanceDifficulty.Colour[3]/255)
        ColourPicker:SetHasAlpha(false)
        ColourPicker:SetRelativeWidth(0.33)
        ColourPicker:SetCallback("OnValueChanged", function(_, _, r, g, b) DB.InstanceDifficulty.Colour = {r*255, g*255, b*255} MS:UpdateInstanceDifficulty() end)
        ElementOptionsContainer:AddChild(ColourPicker)

        local AbbreviatedCheckbox = AG:Create("CheckBox")
        AbbreviatedCheckbox:SetLabel(LT("Abbreviated Difficulty"))
        AbbreviatedCheckbox:SetValue(DB.InstanceDifficulty.Abbreviate)
        AbbreviatedCheckbox:SetRelativeWidth(0.33)
        AbbreviatedCheckbox:SetCallback("OnValueChanged", function(_, _, value) DB.InstanceDifficulty.Abbreviate = value MS:UpdateInstanceDifficulty() end)
        ElementOptionsContainer:AddChild(AbbreviatedCheckbox)

        local HideBlizzardInstanceDifficultyCheckbox = AG:Create("CheckBox")
        HideBlizzardInstanceDifficultyCheckbox:SetLabel(LT("Force Hide Blizzard Banner"))
        HideBlizzardInstanceDifficultyCheckbox:SetValue(DB.InstanceDifficulty.HideBlizzardInstanceBanner)
        HideBlizzardInstanceDifficultyCheckbox:SetRelativeWidth(0.33)
        HideBlizzardInstanceDifficultyCheckbox:SetCallback("OnValueChanged", function(_, _, value) DB.InstanceDifficulty.HideBlizzardInstanceBanner = value MS:ReloadPrompt() end)
        ElementOptionsContainer:AddChild(HideBlizzardInstanceDifficultyCheckbox)

        local LayoutContainer = AG:Create("InlineGroup")
        LayoutContainer:SetTitle(LT("Layout"))
        LayoutContainer:SetLayout("Flow")
        LayoutContainer:SetFullWidth(true)
        ScrollFrame:AddChild(LayoutContainer)

        CreateLayoutGroup(LayoutContainer, DB.InstanceDifficulty.Layout, function() MS:UpdateInstanceDifficulty() end)
        CreateMinimapStatsPreview(ScrollFrame)

        DisableElements(ScrollFrame, Enable, DB.InstanceDifficulty.Enable)

        LayoutContainer:DoLayout()
        ScrollFrame:DoLayout()
    end

    function MS:CreateCoordinatesOptions(Container)
        local ScrollFrame = SetupTabGroup(Container, "Coordinates Options")

        local Enable = AG:Create("CheckBox")
        Enable:SetLabel(LT("Enable {KUI_ACCENT}Coordinates|r"))
        Enable:SetValue(DB.Coordinates.Enable)
        Enable:SetRelativeWidth(1)
        Enable:SetCallback("OnValueChanged", function(_, _, value) DB.Coordinates.Enable = value MS:UpdateCoordinates() DisableElements(ScrollFrame, Enable, value) end)
        ScrollFrame:AddChild(Enable)

        local ElementOptionsContainer = AG:Create("InlineGroup")
        ElementOptionsContainer:SetTitle(LT("Element Options"))
        ElementOptionsContainer:SetLayout("Flow")
        ElementOptionsContainer:SetFullWidth(true)
        ScrollFrame:AddChild(ElementOptionsContainer)

        local ColourByDropdown = AG:Create("Dropdown")
        ColourByDropdown:SetLabel(LT("Colour By"))
        ColourByDropdown:SetList(LocalizeMap({ ["CUSTOM"] = "Custom", ["ACCENT"] = "Accent" }), { "CUSTOM", "ACCENT" })
        ColourByDropdown:SetValue(DB.Coordinates.ColourBy)
        ColourByDropdown:SetRelativeWidth(0.5)
        ColourByDropdown:SetCallback("OnValueChanged", function(_, _, value) DB.Coordinates.ColourBy = value MS:UpdateCoordinates() if value == "CUSTOM" then MS.ColourPicker:SetDisabled(false) else MS.ColourPicker:SetDisabled(true) end end)
        ElementOptionsContainer:AddChild(ColourByDropdown)

        local ColourPicker = AG:Create("ColorPicker")
        ColourPicker:SetLabel(LT("Text Colour"))
        ColourPicker:SetColor(DB.Coordinates.Colour[1]/255, DB.Coordinates.Colour[2]/255, DB.Coordinates.Colour[3]/255)
        ColourPicker:SetHasAlpha(false)
        ColourPicker:SetRelativeWidth(0.5)
        ColourPicker:SetCallback("OnValueChanged", function(_, _, r, g, b) DB.Coordinates.Colour = {r*255, g*255, b*255} MS:UpdateCoordinates() end)
        MS.ColourPicker = ColourPicker
        ElementOptionsContainer:AddChild(ColourPicker)

        local FormatDropdown = AG:Create("Dropdown")
        FormatDropdown:SetLabel(LT("Coordinate Format"))
        FormatDropdown:SetList({ ["NONE"] = "0, 0", ["SINGLE"] = "0.0, 0.0", ["DOUBLE"] = "0.00, 0.00" }, { "NONE", "SINGLE", "DOUBLE" })
        FormatDropdown:SetValue(DB.Coordinates.Format)
        FormatDropdown:SetRelativeWidth(0.5)
        FormatDropdown:SetCallback("OnValueChanged", function(_, _, value) DB.Coordinates.Format = value MS:UpdateCoordinates() end)
        ElementOptionsContainer:AddChild(FormatDropdown)

        local UpdateIntervalSlider = AG:Create("Slider")
        UpdateIntervalSlider:SetLabel(UpdateRateWarning(DB.Coordinates.UpdateInterval, 1.0))
        UpdateIntervalSlider:SetValue(DB.Coordinates.UpdateInterval)
        UpdateIntervalSlider:SetSliderValues(0.1, 60.0, 0.1)
        UpdateIntervalSlider:SetRelativeWidth(0.5)
        UpdateIntervalSlider:SetCallback("OnValueChanged", function(_, _, value) DB.Coordinates.UpdateInterval = value MS:UpdateCoordinates() UpdateRateWarning(value, 1.0) end)
        ElementOptionsContainer:AddChild(UpdateIntervalSlider)

        local LayoutContainer = AG:Create("InlineGroup")
        LayoutContainer:SetTitle(LT("Layout"))
        LayoutContainer:SetLayout("Flow")
        LayoutContainer:SetFullWidth(true)
        ScrollFrame:AddChild(LayoutContainer)

        CreateLayoutGroup(LayoutContainer, DB.Coordinates.Layout, function() MS:UpdateCoordinates() end)
        CreateMinimapStatsPreview(ScrollFrame)

        DisableElements(ScrollFrame, Enable, DB.Coordinates.Enable)

        if DB.Coordinates.ColourBy == "CUSTOM" then ColourPicker:SetDisabled(false) else ColourPicker:SetDisabled(true) end

        LayoutContainer:DoLayout()
        ScrollFrame:DoLayout()
    end

    function MS:CreateShareOptions(Container)
        local ScrollFrame = SetupTabGroup(Container, "Share Options")

        local ExportingHeading = AG:Create("Heading")
        ExportingHeading:SetText(LT("Exporting"))
        ExportingHeading:SetFullWidth(true)
        ScrollFrame:AddChild(ExportingHeading)

        local ExportingImportingDesc = CreateInfoTag("You can export your profile by pressing {KUI_ACCENT}Export Profile|r button below & share the string with other {KUI_ACCENT}MinimapStats|r users.")
        ScrollFrame:AddChild(ExportingImportingDesc)

        local ExportingEditBox = AG:Create("EditBox")
        ExportingEditBox:SetLabel(LT("Export String..."))
        ExportingEditBox:SetText("")
        ExportingEditBox:SetFullWidth(true)
        ExportingEditBox:DisableButton(true)
        ExportingEditBox:SetCallback("OnEnterPressed", function() ExportingEditBox:ClearFocus() end)
        ScrollFrame:AddChild(ExportingEditBox)

        local ExportProfileButton = AG:Create("Button")
        ExportProfileButton:SetText(LT("Export Profile"))
        ExportProfileButton:SetFullWidth(true)
        ExportProfileButton:SetCallback("OnClick", function() ExportingEditBox:SetText(MS:ExportSavedVariables()) ExportingEditBox:HighlightText() ExportingEditBox:SetFocus() end)
        ScrollFrame:AddChild(ExportProfileButton)

        local ImportingHeading = AG:Create("Heading")
        ImportingHeading:SetText(LT("Importing"))
        ImportingHeading:SetFullWidth(true)
        ScrollFrame:AddChild(ImportingHeading)

        local ImportingDesc = CreateInfoTag("If you have an exported string, paste it in the {KUI_ACCENT}Import String|r box below & press {KUI_ACCENT}Import Profile|r.")
        ScrollFrame:AddChild(ImportingDesc)

        local ImportingEditBox = AG:Create("EditBox")
        ImportingEditBox:SetLabel(LT("Import String..."))
        ImportingEditBox:SetText("")
        ImportingEditBox:SetFullWidth(true)
        ImportingEditBox:DisableButton(true)
        ImportingEditBox:SetCallback("OnEnterPressed", function() ImportingEditBox:ClearFocus() end)
        ScrollFrame:AddChild(ImportingEditBox)

        local ImportProfileButton = AG:Create("Button")
        ImportProfileButton:SetText(LT("Import Profile"))
        ImportProfileButton:SetFullWidth(true)
        ImportProfileButton:SetCallback("OnClick", function() if ImportingEditBox:GetText() ~= "" then MS:ImportSavedVariables(ImportingEditBox:GetText()) ImportingEditBox:SetText("") end end)
        ScrollFrame:AddChild(ImportProfileButton)
    end

    function MS:CreateTooltipOptions(Container)
        local ScrollFrame = SetupTabGroup(Container, "Tooltip Options")

        local TimeTooltipOptions = AG:Create("InlineGroup")
        TimeTooltipOptions:SetTitle(LT("{KUI_ACCENT}Time Frame|r Options"))
        TimeTooltipOptions:SetLayout("Flow")
        TimeTooltipOptions:SetFullWidth(true)
        ScrollFrame:AddChild(TimeTooltipOptions)

        local ShowDateInTooltip = AG:Create("CheckBox")
        local DateStringEditBox = AG:Create("EditBox")
        local DateStringOutputExample = AG:Create("Label")

        local function PositionDateStringExample()
            DateStringOutputExample:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
            DateStringOutputExample:SetJustifyH("LEFT")
            DateStringOutputExample:SetJustifyV("MIDDLE")
            TimeTooltipOptions:DoLayout() 
            ScrollFrame:DoLayout()
        end

        local DateInlineGroup = AG:Create("InlineGroup")
        DateInlineGroup:SetTitle(LT("Date Options"))
        DateInlineGroup:SetLayout("Flow")
        DateInlineGroup:SetFullWidth(true)
        TimeTooltipOptions:AddChild(DateInlineGroup)

        ShowDateInTooltip:SetLabel(LT("Show Date"))
        ShowDateInTooltip:SetValue(DB.Tooltip.Time.Date)
        ShowDateInTooltip:SetRelativeWidth(0.33)
        ShowDateInTooltip:SetCallback("OnValueChanged", function(_, _, value) DB.Tooltip.Time.Date = value DateStringEditBox:SetDisabled(not value) DateStringOutputExample:SetText(value and " " .. date(DB.Tooltip.Time.DateString) or "") PositionDateStringExample() end)
        DateInlineGroup:AddChild(ShowDateInTooltip)

        DateStringEditBox:SetLabel(LT("Date Format"))
        DateStringEditBox:SetText(DB.Tooltip.Time.DateString)
        DateStringEditBox:SetRelativeWidth(0.33)
        DateStringEditBox:SetCallback("OnEnterPressed", function(_, _, value) DB.Tooltip.Time.DateString = value DateStringEditBox:ClearFocus() DateStringOutputExample:SetText(" " .. date(DB.Tooltip.Time.DateString)) end)
        DateStringEditBox:SetCallback("OnLeave", function() HideConfigTooltip() end)
        DateStringEditBox:SetDisabled(not DB.Tooltip.Time.Date)
        DateStringEditBox:SetCallback("OnEnter", function() local tooltipText = "" local Formats = LuaDateFormats[1] local Order = LuaDateFormats[2] tooltipText = tooltipText .. "|cFFFFFFFF" .. LT("Supported Date Tokens:") .. "|r\n" for _, identifier in ipairs(Order) do tooltipText = tooltipText .. "- {KUI_ACCENT}" .. identifier .. "|r - " .. LT(Formats[identifier]) .. "\n" end ShowConfigTooltip(DateStringEditBox.frame, "TOPLEFT", DateStringEditBox.frame, "BOTTOMLEFT", 0, -3, tooltipText) end)
        DateInlineGroup:AddChild(DateStringEditBox)

        DateStringOutputExample:SetText(DB.Tooltip.Time.Date and " " .. date(DB.Tooltip.Time.DateString) or "")
        PositionDateStringExample()
        DateStringOutputExample:SetRelativeWidth(0.33)
        DateInlineGroup:AddChild(DateStringOutputExample)

        local ShowAlternateTimeInTooltip = AG:Create("CheckBox")
        ShowAlternateTimeInTooltip:SetLabel(LT("Show Alternate Time Zone"))
        ShowAlternateTimeInTooltip:SetValue(DB.Tooltip.Time.AlternateTime)
        ShowAlternateTimeInTooltip:SetRelativeWidth(0.5)
        ShowAlternateTimeInTooltip:SetCallback("OnValueChanged", function(_, _, value) DB.Tooltip.Time.AlternateTime = value end)
        ShowAlternateTimeInTooltip:SetCallback("OnEnter", function() ShowConfigTooltip(ShowAlternateTimeInTooltip.frame, "LEFT", ShowAlternateTimeInTooltip.text, "LEFT", 200, 0, MS.InfoButton .. LT("This will show you the alternate time zone from your selection in the {KUI_ACCENT}Time|r Tab.")) end)
        ShowAlternateTimeInTooltip:SetCallback("OnLeave", function() HideConfigTooltip() end)
        TimeTooltipOptions:AddChild(ShowAlternateTimeInTooltip)

        local ShowLockoutsInTooltip = AG:Create("CheckBox")
        ShowLockoutsInTooltip:SetLabel(LT("Show Instance Lockouts"))
        ShowLockoutsInTooltip:SetValue(DB.Tooltip.Time.Lockouts)
        ShowLockoutsInTooltip:SetRelativeWidth(0.5)
        ShowLockoutsInTooltip:SetCallback("OnValueChanged", function(_, _, value) DB.Tooltip.Time.Lockouts = value end)
        TimeTooltipOptions:AddChild(ShowLockoutsInTooltip)

        local SystemStatsTooltipOptions = AG:Create("InlineGroup")
        SystemStatsTooltipOptions:SetTitle(LT("{KUI_ACCENT}SystemStats|r Frame Options"))
        SystemStatsTooltipOptions:SetLayout("Flow")
        SystemStatsTooltipOptions:SetFullWidth(true)
        ScrollFrame:AddChild(SystemStatsTooltipOptions)

        local VaultOptionsInlineGroup = AG:Create("InlineGroup")
        VaultOptionsInlineGroup:SetTitle(LT("Vault Options"))
        VaultOptionsInlineGroup:SetLayout("Flow")
        VaultOptionsInlineGroup:SetFullWidth(true)
        SystemStatsTooltipOptions:AddChild(VaultOptionsInlineGroup)

        local VaultDisplayOptionsInlineGroup = AG:Create("InlineGroup")
        VaultDisplayOptionsInlineGroup:SetTitle(LT("Vault Display Options"))
        VaultDisplayOptionsInlineGroup:SetLayout("Flow")
        VaultDisplayOptionsInlineGroup:SetFullWidth(true)
        
        local ShowVaultInfoInTooltip = AG:Create("CheckBox")
        ShowVaultInfoInTooltip:SetLabel(LT("Show Vault Information"))
        ShowVaultInfoInTooltip:SetValue(DB.Tooltip.SystemStats.Vault.Enable)
        ShowVaultInfoInTooltip:SetRelativeWidth(1)
        ShowVaultInfoInTooltip:SetCallback("OnValueChanged", function(_, _, value) DB.Tooltip.SystemStats.Vault.Enable = value DeepDisable(VaultDisplayOptionsInlineGroup, not value) end)
        VaultOptionsInlineGroup:AddChild(ShowVaultInfoInTooltip)
        VaultOptionsInlineGroup:AddChild(VaultDisplayOptionsInlineGroup)
        
        local VaultOptions = {
            ["Raid"] = "Raid",
            ["MythicPlus"] = "Mythic Plus",
            ["World"] = "World",
        }
        
        for key, label in pairs(VaultOptions) do
            local OptionCheckBox = AG:Create("CheckBox")
            OptionCheckBox:SetLabel(LT(label))
            OptionCheckBox:SetValue(DB.Tooltip.SystemStats.Vault.Options[key])
            OptionCheckBox:SetRelativeWidth(0.33)
            OptionCheckBox:SetCallback("OnValueChanged", function(_, _, value) DB.Tooltip.SystemStats.Vault.Options[key] = value end)
            OptionCheckBox:SetDisabled(not DB.Tooltip.SystemStats.Vault.Enable)
            VaultDisplayOptionsInlineGroup:AddChild(OptionCheckBox)
        end

        ScrollFrame:DoLayout()
    end

    local function SelectTabGroup(GUIContainer, _, TabGroup)
        GUIContainer:ReleaseChildren()
        if TabGroup == "General" then
            MS:CreateGeneralOptions(GUIContainer)
        elseif TabGroup == "Time" then
            MS:CreateTimeOptions(GUIContainer)
        elseif TabGroup == "SystemStats" then
            MS:CreateSystemStatsOptions(GUIContainer)
        elseif TabGroup == "Location" then
            MS:CreateLocationOptions(GUIContainer)
        elseif TabGroup == "InstanceDifficulty" then
            MS:CreateInstanceDifficultyOptions(GUIContainer)
        elseif TabGroup == "Coordinates" then
            MS:CreateCoordinatesOptions(GUIContainer)
        elseif TabGroup == "Tooltips" then
            MS:CreateTooltipOptions(GUIContainer)
        elseif TabGroup == "Share" then
            MS:CreateShareOptions(GUIContainer)
        end
        if not MS.GUIContainer then MS.GUIContainer = GUIContainer end
        MS:UpdateInstanceDifficulty()
    end

    local TabGroup = AG:Create("TabGroup")
    TabGroup:SetLayout("Flow")
    TabGroup:SetTabs({
        { text = LT("General"), value = "General" },
        { text = LT("Time"), value = "Time" },
        { text = LT("System Stats"), value = "SystemStats" },
        { text = LT("Location"), value = "Location" },
        { text = LT("Coordinates"), value = "Coordinates" },
        { text = LT("Instance Difficulty"), value = "InstanceDifficulty" },
        { text = LT("Tooltips"), value = "Tooltips" },
        { text = LT("Sharing"), value = "Share" },
    })
    TabGroup:SetCallback("OnGroupSelected", SelectTabGroup)
    TabGroup:SetFullHeight(true)
    TabGroup:SetFullWidth(true)
    TabGroup:SelectTab(TabToOpen)
    GUIFrame:AddChild(TabGroup)
end

function MS:RedrawGUI()
    MS.GUIContainer:ReleaseChildren()
    MS:CreateGeneralOptions(MS.GUIContainer)
end

function MSG:CreateGUI()
    MS:CreateGUI("General")
end
