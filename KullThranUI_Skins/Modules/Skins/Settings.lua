local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")

-- Only decorate the Settings shell; Blizzard owns the option controls and
-- their callbacks. Keep bookkeeping outside the native frame tables.
local installed = false

local function StyleSettingsBackground(panel)
    local data = S:GetFFD(panel)
    if data.settingsArtwork then return end

    -- Original generated KUI artwork with a light wash for text readability.
    S:ApplyKuiSurface(panel)
    data.settingsArtwork = data.kuiArtwork or true
    if data.topBar then data.topBar:SetColorTexture(0, 0, 0, 0.5) end
end

local function PinTexture(texture)
    if not texture then return end
    local data = S:GetFFD(texture)
    texture:SetAlpha(0)
    if data.settingsHidden then return end
    data.settingsHidden = true
    for _, method in ipairs({ "SetAtlas", "SetTexture", "Show" }) do
        if type(texture[method]) == "function" then
            hooksecurefunc(texture, method, function(self) self:SetAlpha(0) end)
        end
    end
end

local function StyleTextButton(button)
    if not button then return end
    S:HandleButton(button)
    local label = button.GetFontString and button:GetFontString() or button.Text
    if label then label:SetTextColor(1, 1, 1) end
end

local function SkinSettings()
    if installed or not (S.db and S.db.enable and S.db.settings) then return end
    local panel = _G.SettingsPanel
    if not panel or panel:IsForbidden() then return end

    -- CloseButton is the footer text button, not the window's close X.
    S:SkinPremiumWindow(panel)
    StyleSettingsBackground(panel)
    if panel.Bg then PinTexture(panel.Bg) end
    S:HandleCloseButton(panel.ClosePanelButton)
    S:HandleEditBox(panel.SearchBox)
    StyleTextButton(panel.ApplyButton)
    StyleTextButton(panel.CloseButton)

    local tabs = {}
    for _, key in ipairs({ "GameTab", "AddOnsTab" }) do
        local tab = panel[key]
        if tab then
            -- Capture only Blizzard textures before creating the KUI artwork.
            for _, region in ipairs({ tab:GetRegions() }) do
                if region:IsObjectType("Texture") then PinTexture(region) end
            end
            local data = S:GetFFD(tab)
            data.settingsBackground = tab:CreateTexture(nil, "BACKGROUND")
            data.settingsBackground:SetAllPoints()
            data.settingsUnderline = tab:CreateTexture(nil, "OVERLAY")
            data.settingsUnderline:SetPoint("BOTTOMLEFT", 1, 0)
            data.settingsUnderline:SetPoint("BOTTOMRIGHT", -1, 0)
            data.settingsUnderline:SetHeight(2)
            S:RegisterBlizzardAccentRefresh(data.settingsUnderline, function(texture, color)
                texture:SetColorTexture(color[1], color[2], color[3], 1)
            end)
            S:HandleFont(tab)
            tabs[#tabs + 1] = tab
        end
    end

    local function PaintTab(tab)
        local data = S:GetFFD(tab)
        local active = data.settingsSelected
        local hover = data.settingsHovered
        data.settingsBackground:SetColorTexture(
            active and 0.24 or 0.18, active and 0.22 or 0.17,
            active and 0.19 or 0.15, hover and 0.92 or 0.78)
        data.settingsUnderline:SetShown(active == true)
        local label = tab.GetFontString and tab:GetFontString() or tab.Text
        if label then
            local value = (active or hover) and 1 or 0.88
            label:SetTextColor(value, value, value)
        end
    end

    local function SyncTabs(clicked)
        local category = panel.GetCurrentCategory and panel:GetCurrentCategory()
        for index, tab in ipairs(tabs) do
            local selected
            if clicked then
                selected = tab == clicked
            elseif category and category.categorySet ~= nil then
                selected = tab.categorySet == category.categorySet
            elseif tab.isSelected ~= nil then
                selected = tab.isSelected == true
            else
                selected = index == 1
            end
            S:GetFFD(tab).settingsSelected = selected
            PaintTab(tab)
        end
    end

    local function LayoutTabs()
        for index, tab in ipairs(tabs) do
            local label = tab.GetFontString and tab:GetFontString() or tab.Text
            local textWidth = label and label:GetStringWidth() or 0
            tab:SetSize(math.max(88, textWidth + 24), 28)
            tab:ClearAllPoints()
            if index == 1 then
                -- Match the search field's vertical center and the sidebar inset.
                tab:SetPoint("LEFT", panel, "TOPLEFT", 32, -45)
            else
                tab:SetPoint("LEFT", tabs[index - 1], "RIGHT", 6, 0)
            end
            if label then
                label:ClearAllPoints()
                label:SetPoint("CENTER", tab, "CENTER", 0, 0)
                label:SetJustifyH("CENTER")
            end
        end
    end

    for _, tab in ipairs(tabs) do
        tab:HookScript("OnClick", function(self) SyncTabs(self) end)
        tab:HookScript("OnEnter", function(self)
            S:GetFFD(self).settingsHovered = true
            PaintTab(self)
        end)
        tab:HookScript("OnLeave", function(self)
            S:GetFFD(self).settingsHovered = false
            PaintTab(self)
        end)
    end
    if type(panel.SetCurrentCategory) == "function" then
        hooksecurefunc(panel, "SetCurrentCategory", function() SyncTabs() end)
    end

    local categoryList = panel.CategoryList
    local function RefreshCategories()
        local box = categoryList and categoryList.ScrollBox
        if box and box.ForEachFrame and box:IsVisible() then
            box:ForEachFrame(function(row)
                -- Preserve native selection/highlight and new-feature badges.
                if row.Background then row.Background:SetAlpha(0) end
            end)
        end
    end
    if categoryList then
        S:FadeRegions(categoryList)
        S:HandleScrollBar(categoryList.ScrollBar)
        local box = categoryList.ScrollBox
        if box and type(box.Update) == "function" then
            hooksecurefunc(box, "Update", S:Debounce(RefreshCategories))
        end
    end

    local container = panel.Container
    if container then
        S:FadeRegions(container)
        local list = container.SettingsList
        if list then
            S:FadeRegions(list)
            S:HandleScrollBar(list.ScrollBar)
            local header = list.Header
            if header then
                StyleTextButton(header.DefaultsButton)
                if header.Title then
                    S:HandleFont(header.Title)
                    header.Title:SetTextColor(1, 1, 1)
                end
            end
        end
    end

    panel:HookScript("OnShow", function()
        LayoutTabs()
        SyncTabs()
        RefreshCategories()
    end)
    LayoutTabs()
    SyncTabs()
    RefreshCategories()
    installed = true
end

-- Covers an already-created SettingsPanel and delayed Blizzard loading.
S:AddCallback("Settings", SkinSettings)
S:AddCallbackForAddon("Blizzard_Settings_Shared", "Settings", SkinSettings)
S:AddCallbackForAddon("Blizzard_Settings", "Settings", SkinSettings)
