local KT = _G.KT

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function CreateSliderControl(parent, label, yOffset, min, max, step, key, callback)
    local container = CreateFrame("Frame", nil, parent)
    container:SetPoint("TOPLEFT", 15, yOffset)
    container:SetPoint("TOPRIGHT", -15, yOffset)
    container:SetHeight(35)
    
    local text = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 5, -5)
    text:SetText(LText(label))
    
    local valueText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valueText:SetPoint("TOPRIGHT", -5, -5)
    
    local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -20)
    slider:SetPoint("TOPRIGHT", 0, -20)
    slider:SetHeight(15)
    slider:SetMinMaxValues(min, max)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    
    -- Midnight 12.0 compatible text clearing
    if slider.Low then slider.Low:SetText("") end
    if slider.High then slider.High:SetText("") end
    if slider.Text then slider.Text:SetText("") end
    
    slider:SetScript("OnValueChanged", function(self, value)
        if step >= 1 then
            valueText:SetFormattedText("%.0f", value)
        else
            valueText:SetFormattedText("%.2f", value)
        end
        if callback then callback(key, value) end
    end)
    
    return slider
end

local function CreateCheckboxControl(parent, label, yOffset, key, callback)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", 20, yOffset)
    check:SetSize(24, 24)
    
    local text = check:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", check, "RIGHT", 5, 0)
    text:SetText(LText(label))
    
    check:SetScript("OnClick", function(self)
        if callback then callback(key, self:GetChecked()) end
    end)
    
    return check
end

local function CreateColorPicker(parent, label, yOffset, callback)
    local colorLabel = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    colorLabel:SetPoint("TOPLEFT", 20, yOffset)
    colorLabel:SetText(LText(label))
    
    local colorButton = CreateFrame("Button", nil, parent, "BackdropTemplate")
    colorButton:SetSize(30, 20)
    colorButton:SetPoint("TOPLEFT", 100, yOffset + 2)
    colorButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1
    })
    
    colorButton:SetScript("OnClick", function()
        if callback then callback(colorButton) end
    end)
    
    return colorButton
end

local function MakeFrameDraggable(frame, titleFrame)
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and ((_G.MouseIsOver and _G.MouseIsOver(titleFrame)) or (titleFrame.IsMouseOver and titleFrame:IsMouseOver())) then
            self:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(self)
        self:StopMovingOrSizing()
    end)
end

-- ============================================================================
-- ACTION BAR EDITOR
-- ============================================================================

-- Helper: Obtener nombre de fuente desde path
local function GetFontNameFromPath(path)
    local LSM = LibStub("LibSharedMedia-3.0", true)
    if not LSM or not path then return "Default" end
    
    -- Buscar en la lista de fuentes registradas
    local fonts = LSM:List("font")
    for _, fontName in ipairs(fonts) do
        local fontPath = LSM:Fetch("font", fontName)
        if fontPath and fontPath:lower() == path:lower() then
            return fontName
        end
    end
    
    -- Si no se encuentra, extraer nombre del archivo
    local fileName = path:match("([^\\]+)%.ttf$") or path:match("([^\\]+)%.TTF$") or "Default"
    return fileName
end

function KT:ShowBarEditor(bar)
    if not bar then return end
    if not self.BarEditorFrame then self:CreateBarEditor() end
    
    local f = self.BarEditorFrame
    f.currentBar = bar
    
    -- Update all values
    f.scaleSlider:SetValue(bar.sets.scale or 1)
    f.colsSlider:SetValue(bar.sets.cols or 12)
    f.countSlider:SetValue(bar.sets.count or 12)
    f.alphaSlider:SetValue(bar.sets.alpha or 1)
    f.spacingSlider:SetValue(bar.sets.spacing or 6)
    f.paddingSlider:SetValue(bar.sets.padding or 2)
    f.macroSizeSlider:SetValue(bar.sets.macroSize or 12)
    f.bindSizeSlider:SetValue(bar.sets.bindSize or 12)
    
    f.fadeCheck:SetChecked(bar.sets.fade or false)
    f.gridCheck:SetChecked(bar.sets.showGrid)
    f.hideMacroCheck:SetChecked(bar.sets.hideMacro or false)
    f.hideBindCheck:SetChecked(bar.sets.hideKeybind or false)
    
    -- Update font dropdown (usando helper function)
    local currentFont = bar.sets.font or KT.db.profile.font or "Fonts\\FRIZQT__.TTF"
    local fontName = GetFontNameFromPath(currentFont)
    UIDropDownMenu_SetText(f.fontDropdown, fontName)
    
    -- Update color
    local color = bar.sets.fontColor or {r=1, g=1, b=1, a=1}
    f.colorButton:SetBackdropColor(color.r, color.g, color.b, color.a)
    
    f:ClearAllPoints()
    f:SetPoint("TOP", bar.header, "BOTTOM", 0, -10)
    f:Show()
end

function KT:CreateBarEditor()
    local f = CreateFrame("Frame", "KT_BarEditor", UIParent, "BackdropTemplate")
    f:SetSize(320, 620)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(1, 0.8, 0, 1)
    
    local titleBg = CreateFrame("Frame", nil, f)
    titleBg:SetPoint("TOPLEFT", 0, 0)
    titleBg:SetPoint("TOPRIGHT", 0, 0)
    titleBg:SetHeight(30)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
    title:SetText(LText("Bar Configuration"))
    
    MakeFrameDraggable(f, titleBg)
    
    local function OnBarChange(key, value)
        if f.currentBar then
            f.currentBar.sets[key] = value
            KT:RefreshConfig()
        end
    end
    
    local yPos = -35
    
    f.scaleSlider = CreateSliderControl(f, "Scale", yPos, 0.5, 2, 0.05, "scale", OnBarChange)
    yPos = yPos - 40
    
    f.colsSlider = CreateSliderControl(f, "Columns", yPos, 1, 12, 1, "cols", OnBarChange)
    yPos = yPos - 40
    
    f.countSlider = CreateSliderControl(f, "Visible Buttons", yPos, 1, 12, 1, "count", OnBarChange)
    yPos = yPos - 40
    
    f.alphaSlider = CreateSliderControl(f, "Opacity", yPos, 0, 1, 0.1, "alpha", OnBarChange)
    yPos = yPos - 40
    
    f.spacingSlider = CreateSliderControl(f, "Spacing", yPos, 0, 20, 1, "spacing", OnBarChange)
    yPos = yPos - 40
    
    f.paddingSlider = CreateSliderControl(f, "Padding", yPos, 0, 20, 1, "padding", OnBarChange)
    yPos = yPos - 40
    
    f.macroSizeSlider = CreateSliderControl(f, "Macro Text Size", yPos, 8, 20, 1, "macroSize", OnBarChange)
    yPos = yPos - 40
    
    f.bindSizeSlider = CreateSliderControl(f, "Keybind Text Size", yPos, 8, 20, 1, "bindSize", OnBarChange)
    yPos = yPos - 50
    
    -- Font dropdown
    local fontLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", 20, yPos)
    fontLabel:SetText(LText("Font"))
    
    local fontDropdown = CreateFrame("Frame", "KT_BarEditor_FontDropdown", f, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", 10, yPos - 20)
    UIDropDownMenu_SetWidth(fontDropdown, 200)
    
    UIDropDownMenu_Initialize(fontDropdown, function(self)
        local LSM = LibStub("LibSharedMedia-3.0", true)
        local all = LSM and LSM:List("font") or {"Friz Quadrata TT"}
        local fonts = {}
        for _, n in ipairs(all) do
            if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(n) then
                fonts[#fonts + 1] = n
            end
        end
        if not next(fonts) then
            local def = (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "Friz Quadrata TT"
            fonts[#fonts + 1] = def
        end
        
        for _, fontName in ipairs(fonts) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = fontName
            info.func = function()
                if f.currentBar then
                    f.currentBar.sets.font = LSM and LSM:Fetch("font", fontName) or "Fonts\\FRIZQT__.TTF"
                    UIDropDownMenu_SetText(fontDropdown, fontName)
                    KT:RefreshConfig()
                end
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    f.fontDropdown = fontDropdown
    yPos = yPos - 35
    
    -- Color picker
    f.colorButton = CreateColorPicker(f, "Text Color", yPos, function(btn)
        if not f.currentBar then return end
        local color = f.currentBar.sets.fontColor or {r=1, g=1, b=1, a=1}
        
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color.r, g = color.g, b = color.b,
            opacity = color.a, hasOpacity = true,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                f.currentBar.sets.fontColor = {r=r, g=g, b=b, a=a}
                btn:SetBackdropColor(r, g, b, a)
                KT:RefreshConfig()
            end,
            opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                f.currentBar.sets.fontColor = {r=r, g=g, b=b, a=a}
                btn:SetBackdropColor(r, g, b, a)
                KT:RefreshConfig()
            end,
            cancelFunc = function() btn:SetBackdropColor(color.r, color.g, color.b, color.a) end
        })
    end)
    yPos = yPos - 35
    
    f.fadeCheck = CreateCheckboxControl(f, "Fade Out", yPos, "fade", OnBarChange)
    yPos = yPos - 28
    
    f.gridCheck = CreateCheckboxControl(f, "Show Grid", yPos, "showGrid", OnBarChange)
    yPos = yPos - 28
    
    f.hideMacroCheck = CreateCheckboxControl(f, "Hide Macro Text", yPos, "hideMacro", OnBarChange)
    yPos = yPos - 28
    
    f.hideBindCheck = CreateCheckboxControl(f, "Hide Keybinds", yPos, "hideKeybind", OnBarChange)
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 15, 15)
    resetBtn:SetText(LText("Reset to Defaults"))
    resetBtn:SetScript("OnClick", function()
        if f.currentBar then
            KT:ResetBarToDefaults(f.currentBar)
        end
    end)
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -15, 15)
    closeBtn:SetText(LText("Close"))
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    f:Hide()
    self.BarEditorFrame = f
end

-- ============================================================================
-- EXP/HONOR BAR EDITOR
-- ============================================================================

function KT:ShowExpBarEditor()
    if not self.ExpBarEditorFrame then self:CreateExpBarEditor() end
    
    local f = self.ExpBarEditorFrame
    local settings = self.db.profile.expBar or {}
    
    f.scaleSlider:SetValue(settings.scale or 1)
    f.widthSlider:SetValue(settings.width or 1024)
    f.heightSlider:SetValue(settings.height or 12)
    f.alphaSlider:SetValue(settings.alpha or 1)
    f.hideTextCheck:SetChecked(settings.hideText or false)
    
    f:Show()
end

function KT:CreateExpBarEditor()
    local f = CreateFrame("Frame", "KT_ExpBarEditor", UIParent, "BackdropTemplate")
    f:SetSize(320, 300)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0, 0.8, 1, 1)
    
    local titleBg = CreateFrame("Frame", nil, f)
    titleBg:SetPoint("TOPLEFT", 0, 0)
    titleBg:SetPoint("TOPRIGHT", 0, 0)
    titleBg:SetHeight(30)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
    title:SetText(LText("EXP/Honor Bar"))
    
    MakeFrameDraggable(f, titleBg)
    
    if not KT.db.profile.expBar then
        KT.db.profile.expBar = { scale = 1, width = 1024, height = 12, alpha = 1, hideText = false }
    end
    
    local function OnExpBarChange(key, value)
        KT.db.profile.expBar[key] = value
        KT:ApplyExpBarSettings()
    end
    
    local yPos = -35
    
    f.scaleSlider = CreateSliderControl(f, "Scale", yPos, 0.5, 2, 0.05, "scale", OnExpBarChange)
    yPos = yPos - 40
    
    f.widthSlider = CreateSliderControl(f, "Width", yPos, 200, 2000, 10, "width", OnExpBarChange)
    yPos = yPos - 40
    
    f.heightSlider = CreateSliderControl(f, "Height", yPos, 8, 40, 1, "height", OnExpBarChange)
    yPos = yPos - 40
    
    f.alphaSlider = CreateSliderControl(f, "Opacity", yPos, 0, 1, 0.1, "alpha", OnExpBarChange)
    yPos = yPos - 50
    
    f.hideTextCheck = CreateCheckboxControl(f, "Hide Text", yPos, "hideText", OnExpBarChange)
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 15, 15)
    resetBtn:SetText(LText("Reset to Defaults"))
    resetBtn:SetScript("OnClick", function()
        KT:ResetExpBarToDefaults()
    end)
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -15, 15)
    closeBtn:SetText(LText("Close"))
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    f:Hide()
    self.ExpBarEditorFrame = f
end

function KT:ApplyExpBarSettings()
    local bar = _G["StatusTrackingBarManager"]
    if not bar then return end
    
    local settings = self.db.profile.expBar or {}
    
    bar:SetScale(settings.scale or 1)
    
    if settings.width and settings.height then
        bar:SetSize(settings.width, settings.height)
        -- Midnight 12.0: Los StatusBars pueden tener diferente estructura
        for i = 0, 2 do
            local statusBar = bar["StatusBar"..i]
            if statusBar then statusBar:SetHeight(settings.height) end
        end
    end
    
    bar:SetAlpha(settings.alpha or 1)
    
    if settings.hideText then
        if bar.SingleBarLargeUpper then bar.SingleBarLargeUpper:SetAlpha(0) end
        if bar.SingleBarSmallUpper then bar.SingleBarSmallUpper:SetAlpha(0) end
    else
        if bar.SingleBarLargeUpper then bar.SingleBarLargeUpper:SetAlpha(1) end
        if bar.SingleBarSmallUpper then bar.SingleBarSmallUpper:SetAlpha(1) end
    end
end

-- ============================================================================
-- QUEST TRACKER EDITOR
-- ============================================================================

function KT:ShowQuestTrackerEditor()
    if not self.QuestTrackerEditorFrame then self:CreateQuestTrackerEditor() end
    
    local f = self.QuestTrackerEditorFrame
    local settings = self.db.profile.questTracker or {}
    
    f.scaleSlider:SetValue(settings.scale or 1)
    
    -- Usar helper function para obtener nombre de fuente
    if settings.font then
        local fontName = GetFontNameFromPath(settings.font)
        UIDropDownMenu_SetText(f.fontDropdown, fontName)
    else
        UIDropDownMenu_SetText(f.fontDropdown, LText("Default"))
    end
    
    f.hideHeaderCheck:SetChecked(settings.hideHeader or false)
    
    f:Show()
end

function KT:CreateQuestTrackerEditor()
    local f = CreateFrame("Frame", "KT_QuestTrackerEditor", UIParent, "BackdropTemplate")
    f:SetSize(320, 200)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0.6, 0.4, 0.8, 1)
    
    local titleBg = CreateFrame("Frame", nil, f)
    titleBg:SetPoint("TOPLEFT", 0, 0)
    titleBg:SetPoint("TOPRIGHT", 0, 0)
    titleBg:SetHeight(30)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
    title:SetText(LText("Quest Tracker"))
    
    MakeFrameDraggable(f, titleBg)
    
    if not KT.db.profile.questTracker then
        KT.db.profile.questTracker = { scale = 1, hideHeader = false }
    end
    
    local function OnQTChange(key, value)
        KT.db.profile.questTracker[key] = value
        KT:ApplyQuestTrackerSettings()
    end
    
    local yPos = -35
    f.scaleSlider = CreateSliderControl(f, "Scale", yPos, 0.5, 2, 0.05, "scale", OnQTChange)
    yPos = yPos - 40
    
    -- Font dropdown
    local fontLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", 20, yPos)
    fontLabel:SetText(LText("Font"))
    
    local fontDropdown = CreateFrame("Frame", "KT_QTEditor_FontDropdown", f, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", 10, yPos - 20)
    UIDropDownMenu_SetWidth(fontDropdown, 200)
    
    UIDropDownMenu_Initialize(fontDropdown, function(self)
        local LSM = LibStub("LibSharedMedia-3.0", true)
        local all = LSM and LSM:List("font") or {"Friz Quadrata TT"}
        local fonts = {}
        for _, n in ipairs(all) do
            if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(n) then
                fonts[#fonts + 1] = n
            end
        end
        if not next(fonts) then
            local def = (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "Friz Quadrata TT"
            fonts[#fonts + 1] = def
        end
        
        for _, fontName in ipairs(fonts) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = fontName
            info.func = function()
                KT.db.profile.questTracker.font = LSM and LSM:Fetch("font", fontName)
                UIDropDownMenu_SetText(fontDropdown, fontName)
                KT:ApplyQuestTrackerSettings()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)
    
    f.fontDropdown = fontDropdown
    yPos = yPos - 35
    
    f.hideHeaderCheck = CreateCheckboxControl(f, "Hide 'All Objectives' Header", yPos, "hideHeader", OnQTChange)
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 15, 15)
    resetBtn:SetText(LText("Reset to Defaults"))
    resetBtn:SetScript("OnClick", function()
        KT:ResetQuestTrackerToDefaults()
    end)
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -15, 15)
    closeBtn:SetText(LText("Close"))
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    f:Hide()
    self.QuestTrackerEditorFrame = f
end

function KT:ApplyQuestTrackerSettings()
    local tracker = _G["ObjectiveTrackerFrame"]
    if not tracker then return end
    
    local settings = self.db.profile.questTracker or {}
    tracker:SetScale(settings.scale or 1)

    -- Do not mutate ObjectiveTracker FontStrings directly. Blizzard reuses tracker
    -- text regions and font objects in protected flows, and touching them here can
    -- taint unrelated widget/tooltips later in the session.
    
    if tracker.Header then
        if settings.hideHeader then
            tracker.Header:SetAlpha(0)
        else
            tracker.Header:SetAlpha(1)
        end
    end
end

-- ============================================================================
-- BUFFS/DEBUFFS EDITOR
-- ============================================================================

function KT:ShowBuffsEditor()
    self:ShowAuraEditor("buffs", "BuffFrame")
end

function KT:ShowDebuffsEditor()
    self:ShowAuraEditor("debuffs", "DebuffFrame")
end

function KT:ShowAuraEditor(auraType, frameName)
    local editorName = auraType:gsub("^%l", string.upper).."EditorFrame"
    
    if not self[editorName] then
        self:CreateAuraEditor(auraType, frameName)
    end
    
    local f = self[editorName]
    local settings = self.db.profile[auraType] or {}
    
    f.spacingSlider:SetValue(settings.spacing or 2)
    f.iconSizeSlider:SetValue(settings.iconSize or 32)
    f.paddingSlider:SetValue(settings.padding or 2)
    f.alphaSlider:SetValue(settings.alpha or 1)
    f.scaleSlider:SetValue(settings.scale or 1)
    
    local color = settings.textColor or {r=1, g=1, b=1, a=1}
    f.colorButton:SetBackdropColor(color.r, color.g, color.b, color.a)
    
    f:Show()
end

function KT:CreateAuraEditor(auraType, frameName)
    local f = CreateFrame("Frame", "KT_"..auraType:gsub("^%l", string.upper).."Editor", UIParent, "BackdropTemplate")
    f:SetSize(320, 350)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    f:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
    f:SetBackdropBorderColor(0.2, 0.8, 0.2, 1)
    
    local titleBg = CreateFrame("Frame", nil, f)
    titleBg:SetPoint("TOPLEFT", 0, 0)
    titleBg:SetPoint("TOPRIGHT", 0, 0)
    titleBg:SetHeight(30)
    
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER", titleBg, "CENTER", 0, 0)
    title:SetText(LText(auraType:gsub("^%l", string.upper)))
    
    MakeFrameDraggable(f, titleBg)
    
    if not KT.db.profile[auraType] then
        KT.db.profile[auraType] = {
            spacing = 2, iconSize = 32, padding = 2,
            alpha = 1, scale = 1,
            textColor = {r=1, g=1, b=1, a=1}
        }
    end
    
    local function OnAuraChange(key, value)
        KT.db.profile[auraType][key] = value
        KT:ApplyAuraSettings(auraType, frameName)
    end
    
    local yPos = -35
    
    f.spacingSlider = CreateSliderControl(f, "Spacing", yPos, 0, 20, 1, "spacing", OnAuraChange)
    yPos = yPos - 40
    
    f.iconSizeSlider = CreateSliderControl(f, "Icon Size", yPos, 16, 64, 1, "iconSize", OnAuraChange)
    yPos = yPos - 40
    
    f.paddingSlider = CreateSliderControl(f, "Padding", yPos, 0, 20, 1, "padding", OnAuraChange)
    yPos = yPos - 40
    
    f.alphaSlider = CreateSliderControl(f, "Opacity", yPos, 0, 1, 0.1, "alpha", OnAuraChange)
    yPos = yPos - 40
    
    f.scaleSlider = CreateSliderControl(f, "Scale", yPos, 0.5, 2, 0.05, "scale", OnAuraChange)
    yPos = yPos - 50
    
    f.colorButton = CreateColorPicker(f, "Text Color", yPos, function(btn)
        local color = KT.db.profile[auraType].textColor or {r=1, g=1, b=1, a=1}
        
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color.r, g = color.g, b = color.b,
            opacity = color.a, hasOpacity = true,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                KT.db.profile[auraType].textColor = {r=r, g=g, b=b, a=a}
                btn:SetBackdropColor(r, g, b, a)
                KT:ApplyAuraSettings(auraType, frameName)
            end,
            opacityFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                KT.db.profile[auraType].textColor = {r=r, g=g, b=b, a=a}
                btn:SetBackdropColor(r, g, b, a)
                KT:ApplyAuraSettings(auraType, frameName)
            end,
            cancelFunc = function() btn:SetBackdropColor(color.r, color.g, color.b, color.a) end
        })
    end)
    
    -- Reset button
    local resetBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    resetBtn:SetSize(120, 22)
    resetBtn:SetPoint("BOTTOMLEFT", 15, 15)
    resetBtn:SetText(LText("Reset to Defaults"))
    resetBtn:SetScript("OnClick", function()
        KT:ResetAuraToDefaults(auraType, frameName)
    end)
    
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(80, 22)
    closeBtn:SetPoint("BOTTOMRIGHT", -15, 15)
    closeBtn:SetText(LText("Close"))
    closeBtn:SetScript("OnClick", function() f:Hide() end)
    
    f:Hide()
    self[auraType:gsub("^%l", string.upper).."EditorFrame"] = f
end

function KT:ApplyAuraSettings(auraType, frameName)
    local frame = _G[frameName]
    if not frame then return end
    
    local settings = self.db.profile[auraType] or {}
    
    frame:SetScale(settings.scale or 1)
    frame:SetAlpha(settings.alpha or 1)
end

-- ============================================================================
-- RESET TO DEFAULTS
-- ============================================================================

function KT:ResetBarToDefaults(bar)
    if not bar then return end
    
    local defaults = {
        scale = 1,
        padding = 2,
        spacing = 6,
        cols = 12,
        count = 12,
        alpha = 1,
        fade = false,
        showGrid = true,
        hideMacro = false,
        hideKeybind = false,
        macroSize = 12,
        bindSize = 12,
        fontColor = {r = 1, g = 1, b = 1, a = 1},
        font = nil
    }
    
    for k, v in pairs(defaults) do
        bar.sets[k] = v
    end
    
    KT:RefreshConfig()
    
    if self.BarEditorFrame and self.BarEditorFrame:IsShown() and self.BarEditorFrame.currentBar == bar then
        self:ShowBarEditor(bar)
    end
end

function KT:ResetExpBarToDefaults()
    self.db.profile.expBar = {
        scale = 1,
        width = 1024,
        height = 12,
        alpha = 1,
        hideText = false
    }
    
    self:ApplyExpBarSettings()
    
    if self.ExpBarEditorFrame and self.ExpBarEditorFrame:IsShown() then
        self:ShowExpBarEditor()
    end
end

function KT:ResetQuestTrackerToDefaults()
    self.db.profile.questTracker = {
        scale = 1,
        hideHeader = false,
        font = nil
    }
    
    self:ApplyQuestTrackerSettings()
    
    if self.QuestTrackerEditorFrame and self.QuestTrackerEditorFrame:IsShown() then
        self:ShowQuestTrackerEditor()
    end
end

function KT:ResetAuraToDefaults(auraType, frameName)
    self.db.profile[auraType] = {
        spacing = 2,
        iconSize = 32,
        padding = 2,
        alpha = 1,
        scale = 1,
        textColor = {r = 1, g = 1, b = 1, a = 1}
    }
    
    self:ApplyAuraSettings(auraType, frameName)
    
    if auraType == "buffs" and self.BuffsEditorFrame and self.BuffsEditorFrame:IsShown() then
        self:ShowBuffsEditor()
    elseif auraType == "debuffs" and self.DebuffsEditorFrame and self.DebuffsEditorFrame:IsShown() then
        self:ShowDebuffsEditor()
    end
end
