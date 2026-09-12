local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local ipairs = ipairs
local select = select
local type = type
local unpack = unpack or table.unpack
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local C_Timer = C_Timer

local FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local BLANK = "Interface\\Buttons\\WHITE8x8"
local BG = { 0.032, 0.032, 0.041, 0.98 }
local PANEL = { 0.060, 0.060, 0.074, 0.94 }
local EDGE = { 0.220, 0.220, 0.255, 0.95 }
local SELECTED = { 0.115, 0.115, 0.135, 1 }

local function Accent()
    return S:GetAccentColor()
end

local function Font(fontString, size, r, g, b)
    if not (fontString and fontString.SetFont) then return end
    local _, currentSize = fontString:GetFont()
    fontString:SetFont(FONT, size or currentSize or 11, "OUTLINE")
    fontString:SetShadowOffset(0, 0)
    if fontString.SetTextColor then fontString:SetTextColor(r or 1, g or 1, b or 1, 1) end
end

local function Panel(frame, alpha)
    if not frame then return end
    if not frame.backdrop then S:CreateFlatBackdrop(frame, true) end
    if frame.backdrop then
        frame.backdrop:SetBackdropColor(BG[1], BG[2], BG[3], alpha or BG[4])
        frame.backdrop:SetBackdropBorderColor(unpack(EDGE))
    end
    if not frame._ktBankTexture then
        local texture = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        texture:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
        texture:SetHorizTile(true)
        texture:SetVertTile(true)
        texture:SetVertexColor(0.28, 0.28, 0.32, 1)
        texture:SetAlpha(0.24)
        texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        frame._ktBankTexture = texture
    end
end

local function UpdateBankTab(tab)
    if not (tab and tab.backdrop) then return end
    -- PurchaseTab exists before BankPanel:SetBankType() initializes it. The
    -- Blizzard IsSelected implementation dereferences tabData.ID directly, so
    -- never call it while the pooled tab has no data yet.
    local initialized = tab.tabData ~= nil
    local selected = initialized and type(tab.IsSelected) == "function" and tab:IsSelected() or false
    local over = tab.IsMouseOver and tab:IsMouseOver()
    local color = Accent()
    if selected then
        tab.backdrop:SetBackdropColor(unpack(SELECTED))
        tab.backdrop:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    elseif over then
        tab.backdrop:SetBackdropColor(0.10, 0.10, 0.12, 0.98)
        tab.backdrop:SetBackdropBorderColor(0.72, 0.72, 0.78, 0.88)
    else
        tab.backdrop:SetBackdropColor(0.04, 0.04, 0.05, 0.96)
        tab.backdrop:SetBackdropBorderColor(0.08, 0.08, 0.10, 1)
    end
    if tab.Icon then
        tab.Icon:SetAlpha(selected and 1 or 0.76)
        if tab.Icon.SetDesaturated then tab.Icon:SetDesaturated(not selected) end
    end
end

local function SkinBankTab(tab)
    if not tab then return end
    if not tab._ktBankTab then
        if tab.Border then tab.Border:SetAlpha(0) end
        if tab.Background then tab.Background:SetAlpha(0) end
        if tab.SelectedTexture then tab.SelectedTexture:SetAlpha(0) end
        S:CreateFlatBackdrop(tab, true)
        if tab.backdrop then
            tab.backdrop:ClearAllPoints()
            tab.backdrop:SetPoint("TOPLEFT", tab, "TOPLEFT", -1, 1)
            tab.backdrop:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 1, -1)
        end
        if tab.Icon then
            tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        local highlight = tab.GetHighlightTexture and tab:GetHighlightTexture()
        if highlight then highlight:SetColorTexture(1, 1, 1, 0.08) end
        tab:HookScript("OnEnter", UpdateBankTab)
        tab:HookScript("OnLeave", UpdateBankTab)
        tab:HookScript("OnShow", UpdateBankTab)
        if type(tab.RefreshVisuals) == "function" then
            hooksecurefunc(tab, "RefreshVisuals", UpdateBankTab)
        end
        tab._ktBankTab = true
    end
    UpdateBankTab(tab)
end

local function SkinBankItem(button)
    if not button then return end
    if not button._ktBankItem then
        if button.Background then button.Background:SetAlpha(0) end
        if button.IconBorder then button.IconBorder:SetAlpha(0) end
        local icon = button.Icon or button.icon
        if icon then
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
            icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        end
        S:CreateFlatBackdrop(button, true)
        if button.backdrop then
            button.backdrop:SetBackdropColor(0.025, 0.025, 0.032, 0.98)
            button.backdrop:SetBackdropBorderColor(0.15, 0.15, 0.18, 1)
        end
        local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
        if highlight then highlight:SetColorTexture(1, 1, 1, 0.10) end
        button._ktBankItem = true
    end
end

local function SkinPool(pool, callback)
    if not (pool and pool.EnumerateActive) then return end
    for frame in pool:EnumerateActive() do callback(frame) end
end

local function SkinBankSettings(panel)
    local menu = panel and panel.TabSettingsMenu
    if not menu or menu._ktBankSettings then return end
    Panel(menu, 0.98)
    if menu.BorderBox then
        S:StripTextures(menu.BorderBox)
        local box = menu.BorderBox
        if box.IconSelectorEditBox then S:HandleEditBox(box.IconSelectorEditBox) end
        if box.IconTypeDropdown then S:HandleDropDownBox(box.IconTypeDropdown) end
        if box.OkayButton then S:HandleButton(box.OkayButton) end
        if box.CancelButton then S:HandleButton(box.CancelButton) end
    end
    local deposit = menu.DepositSettingsMenu
    if deposit then
        Panel(deposit, 0.92)
        if deposit.ExpansionFilterDropdown then S:HandleDropDownBox(deposit.ExpansionFilterDropdown) end
        if deposit.DepositSettingsCheckboxes then
            for _, checkBox in ipairs(deposit.DepositSettingsCheckboxes) do S:HandleCheckBox(checkBox) end
        end
    end
    menu._ktBankSettings = true
end

local function SkinBankFrame()
    if not (S.db and S.db.enable and S.db.bank) then return end
    local frame = _G.BankFrame
    local panel = frame and (frame.BankPanel or _G.BankPanel)
    if not (frame and panel) then return end

    if not frame._ktBankShell then
        S:SkinPremiumWindow(frame)
        local data = S:GetFFD(frame)
        if data.atlasBorderFrame then data.atlasBorderFrame:Hide() end
        if data.topBar then
            data.topBar:SetColorTexture(0, 0, 0, 0.35)
            data.topBar:SetHeight(24)
        end
        for _, art in ipairs({ frame.NineSlice, frame.PortraitContainer, frame.Portrait, frame.Background, frame.Bg, frame.TitleBg, frame.TopTileStreaks }) do
            if art then
                if art.SetAlpha then art:SetAlpha(0) end
                if art.Hide then art:Hide() end
            end
        end
        if frame.CloseButton then S:HandleCloseButton(frame.CloseButton) end
        Font(frame.TitleText or _G.BankFrameTitleText, 14, 1, 1, 1)

        local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        border:SetAllPoints(frame)
        border:SetFrameLevel(frame:GetFrameLevel() + 20)
        border:SetBackdrop({ edgeFile = BLANK, edgeSize = S.mult or 1 })
        local color = Accent()
        border:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        frame._ktBankOuterBorder = border
        S:RegisterBlizzardWindowBorder(border, function(self, enabled, accent)
            self:SetBackdropBorderColor(accent[1], accent[2], accent[3], accent[4] or 1)
            self:SetAlpha(enabled and 1 or 0)
        end)

        local divider = frame:CreateTexture(nil, "ARTWORK", nil, 6)
        divider:SetColorTexture(color[1], color[2], color[3], 0.86)
        divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -24)
        divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -24)
        divider:SetHeight(1)
        frame._ktBankHeaderDivider = divider
        frame._ktBankShell = true
    end

    if frame.BankItemSearchBox then S:HandleEditBox(frame.BankItemSearchBox) end
    if frame.TabSystem and frame.TabSystem.GetChildren then
        for i = 1, select("#", frame.TabSystem:GetChildren()) do
            local tab = select(i, frame.TabSystem:GetChildren())
            if tab and tab.IsObjectType and tab:IsObjectType("Button") then S:HandleTab(tab) end
        end
    end

    Panel(panel, 0.92)
    if panel.NineSlice then panel.NineSlice:SetAlpha(0) end
    if panel.EdgeShadows then panel.EdgeShadows:SetAlpha(0) end
    if panel.Header then
        Panel(panel.Header, 0.92)
        Font(panel.Header.Text, 13, 1, 1, 1)
    end
    if panel.MoneyFrame then
        if panel.MoneyFrame.Border then S:StripTextures(panel.MoneyFrame.Border) end
        Panel(panel.MoneyFrame, 0.90)
        S:HandleButton(panel.MoneyFrame.WithdrawButton)
        S:HandleButton(panel.MoneyFrame.DepositButton)
    end
    if panel.AutoDepositFrame then
        Panel(panel.AutoDepositFrame, 0.88)
        S:HandleButton(panel.AutoDepositFrame.DepositButton)
        S:HandleCheckBox(panel.AutoDepositFrame.IncludeReagentsCheckbox)
    end
    if panel.AutoSortButton and not panel.AutoSortButton._ktBankAutoSort then
        S:CreateFlatBackdrop(panel.AutoSortButton, true)
        if panel.AutoSortButton.backdrop then
            panel.AutoSortButton.backdrop:SetBackdropColor(unpack(PANEL))
            panel.AutoSortButton.backdrop:SetBackdropBorderColor(unpack(EDGE))
        end
        local highlight = panel.AutoSortButton:GetHighlightTexture()
        if highlight then highlight:SetColorTexture(1, 1, 1, 0.10) end
        panel.AutoSortButton._ktBankAutoSort = true
    end
    if panel.PurchasePrompt then
        if not panel.PurchasePrompt._ktBankPrompt then
            S:StripTextures(panel.PurchasePrompt)
            panel.PurchasePrompt._ktBankPrompt = true
        end
        Panel(panel.PurchasePrompt, 0.96)
    end
    if panel.LockPrompt then
        if not panel.LockPrompt._ktBankPrompt then
            S:StripTextures(panel.LockPrompt)
            panel.LockPrompt._ktBankPrompt = true
        end
        Panel(panel.LockPrompt, 0.96)
    end
    if panel.PurchasePrompt and panel.PurchasePrompt.TabCostFrame and panel.PurchasePrompt.TabCostFrame.PurchaseButton then
        S:HandleButton(panel.PurchasePrompt.TabCostFrame.PurchaseButton)
    end

    SkinPool(panel.bankTabPool, SkinBankTab)
    SkinBankTab(panel.PurchaseTab)
    SkinPool(panel.itemButtonPool, SkinBankItem)
    SkinBankSettings(panel)

    local cleanup = _G.BankCleanUpConfirmationPopup
    if cleanup and not cleanup._ktBankCleanup then
        S:StripTextures(cleanup)
        Panel(cleanup, 0.98)
        if cleanup.Border then S:StripTextures(cleanup.Border) end
        if cleanup.HidePopupCheckbox and cleanup.HidePopupCheckbox.Checkbox then
            S:HandleCheckBox(cleanup.HidePopupCheckbox.Checkbox)
        end
        S:HandleButton(cleanup.AcceptButton)
        S:HandleButton(cleanup.CancelButton)
        Font(cleanup.Text, 12, 1, 1, 1)
        cleanup._ktBankCleanup = true
    end

    if not panel._ktBankRefreshHooked then
        local function Refresh()
            SkinPool(panel.bankTabPool, SkinBankTab)
            SkinBankTab(panel.PurchaseTab)
            SkinPool(panel.itemButtonPool, SkinBankItem)
            if panel.Header then Font(panel.Header.Text, 13, 1, 1, 1) end
        end
        for _, method in ipairs({ "RefreshBankTabs", "GenerateItemSlotsForSelectedTab", "RefreshBankPanel" }) do
            if type(panel[method]) == "function" then hooksecurefunc(panel, method, Refresh) end
        end
        panel:HookScript("OnShow", function()
            if C_Timer then C_Timer.After(0, Refresh) else Refresh() end
        end)
        panel._ktBankRefreshHooked = true
    end
end

S:AddCallback("BankFrame", SkinBankFrame)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()
    if C_Timer then C_Timer.After(0, SkinBankFrame) else SkinBankFrame() end
end)
