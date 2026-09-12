local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local ipairs = ipairs
local select = select
local unpack = unpack or table.unpack

local FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local BLANK = "Interface\\Buttons\\WHITE8x8"
local TEXT = { 1, 1, 1, 1 }
local TITLE = { 1, 0.82, 0, 1 }

local ScheduleMailSkin

local function Enabled()
    return S.db and S.db.enable and S.db.mail
end

local function SetBackdropBlack(frame, transparent)
    if not frame then return end
    S:CreateBackdrop(frame, transparent)
    if frame.backdrop then
        frame.backdrop:SetBackdropColor(unpack(S:GetBackgroundColor(transparent)))
        frame.backdrop:SetBackdropBorderColor(unpack(S:GetBorderColor()))
    end
end

local function DisableBackdrop(frame)
    if not frame or not frame.backdrop then return end
    frame.backdrop:SetAlpha(0)
    if frame.backdrop.SetBackdropColor then
        frame.backdrop:SetBackdropColor(0, 0, 0, 0)
    end
    if frame.backdrop.SetBackdropBorderColor then
        frame.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function GetPanel(parent, key)
    if not parent then return end

    local panel = parent[key]
    if not panel then
        panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        local level = (parent.GetFrameLevel and parent:GetFrameLevel() or 1) - 1
        if level < 1 then level = 1 end
        panel:SetFrameLevel(level)
        panel:SetBackdrop({
            bgFile = BLANK,
            edgeFile = BLANK,
            edgeSize = S.mult or 1,
            insets = { left = 0, right = 0, top = 0, bottom = 0 },
        })
        parent[key] = panel
    end

    panel:SetBackdropColor(unpack(S:GetBackgroundColor(false)))
    panel:SetBackdropBorderColor(unpack(S:GetBorderColor()))
    return panel
end

local function SetPanelShown(panel, shown)
    if not panel then return end
    if shown then
        panel:Show()
    else
        panel:Hide()
    end
end

local function GetMailWidthPanel()
    local MailFrame = _G.MailFrame
    if not MailFrame then return end

    return MailFrame._ktInboxContentPanel or MailFrame._ktSendContentPanel
end

local function StyleFont(fontString, color)
    if not fontString or not fontString.SetFont then return end

    local _, size = fontString:GetFont()
    size = (size and size > 0) and size or 12
    if not fontString:SetFont(FONT, size, "OUTLINE") then
        fontString:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    end

    fontString:SetTextColor(unpack(color or TEXT))
    if fontString.SetShadowOffset then fontString:SetShadowOffset(1, -1) end
    if fontString.SetShadowColor then fontString:SetShadowColor(0, 0, 0, 1) end
end

local function StyleFrameFonts(frame)
    if not frame or not frame.GetNumRegions then return end

    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            StyleFont(region)
        end
    end
end

local function HideTexture(texture)
    if texture and texture.SetAlpha then
        texture:SetAlpha(0)
    end
end

local function StyleIconButton(button, icon)
    if not button then return end

    icon = icon or button.Icon or button.icon or button.IconTexture or _G[(button:GetName() or "").."IconTexture"]

    if not button._ktMailIconSkinned then
        S:StripTextures(button)
        SetBackdropBlack(button, false)

        if button.SetHighlightTexture then
            button:SetHighlightTexture(BLANK)
            local highlight = button:GetHighlightTexture()
            if highlight then
                highlight:SetVertexColor(1, 1, 1, 0.18)
                if button.backdrop then S:SetInside(highlight, button.backdrop) end
            end
        end

        if button.SetPushedTexture then
            button:SetPushedTexture(BLANK)
            local pushed = button:GetPushedTexture()
            if pushed then
                pushed:SetVertexColor(0, 0, 0, 0.25)
                if button.backdrop then S:SetInside(pushed, button.backdrop) end
            end
        end

        button._ktMailIconSkinned = true
    end

    if icon then
        icon:SetAlpha(1)
        icon:SetDrawLayer("ARTWORK", 5)
        S:HandleIcon(icon)
        if button.backdrop then S:SetInside(icon, button.backdrop, 1) end
    end

    HideTexture(button.IconBorder)
    HideTexture(button.NormalTexture)
    HideTexture(button.normalTexture)
end

local function StylePageButton(button, direction)
    if not button or button._ktMailPageSkinned then return end

    S:StripTextures(button)
    SetBackdropBlack(button, false)
    button:SetSize(22, 22)

    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetDisabledTexture then button:SetDisabledTexture("") end
    if button.SetHighlightTexture then
        button:SetHighlightTexture(BLANK)
        local highlight = button:GetHighlightTexture()
        if highlight then
            highlight:SetVertexColor(1, 1, 1, 0.15)
            if button.backdrop then S:SetInside(highlight, button.backdrop) end
        end
    end

    local arrow = button:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(FONT, 14, "OUTLINE")
    arrow:SetText(direction)
    arrow:SetTextColor(1, 1, 1, 1)
    arrow:SetPoint("CENTER", button.backdrop or button, "CENTER", 0, 1)
    button._ktMailArrow = arrow
    button._ktMailPageSkinned = true
end

local function StyleStandardButton(button)
    if not button then return end
    S:HandleButton(button)
    StyleFrameFonts(button)
end

local function StyleCheckButton(button)
    if not button then return end
    S:HandleCheckBox(button)
    StyleFrameFonts(button)
end

local function SkinSendMailAttachments()
    local max = _G.ATTACHMENTS_MAX_SEND or 12
    for i = 1, max do
        local button = _G["SendMailAttachment"..i]
        if button then
            StyleIconButton(button, button.Icon or button.icon or _G["SendMailAttachment"..i.."IconTexture"])
        end
    end
end

local function SkinOpenMailAttachments()
    local max = _G.ATTACHMENTS_MAX_RECEIVE or 16
    for i = 1, max do
        local button = _G["OpenMailAttachmentButton"..i]
        if button then
            StyleIconButton(button, button.Icon or button.icon or _G["OpenMailAttachmentButton"..i.."IconTexture"])
        end
    end
end

local function SkinInboxItems()
    local max = _G.INBOXITEMS_TO_DISPLAY or 7
    for i = 1, max do
        local item = _G["MailItem"..i]
        if item then
            if not item._ktMailItemSkinned then
                S:StripTextures(item)
                SetBackdropBlack(item, false)
                if item.backdrop then
                    item.backdrop:SetPoint("TOPLEFT", item, "TOPLEFT", 0, -1)
                    item.backdrop:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", -1, 1)
                    item.backdrop:SetBackdropColor(0, 0, 0, 0.35)
                end
                item._ktMailItemSkinned = true
            end

            StyleFrameFonts(item)
            if item.Button then
                StyleIconButton(item.Button, item.Button.Icon or item.Button.icon)
            end
            if item.ItemButton then
                StyleIconButton(item.ItemButton, item.ItemButton.Icon or item.ItemButton.icon)
            end
            if item.Icon then
                item.Icon:SetAlpha(1)
                S:HandleIcon(item.Icon)
            end
        end
    end
end

local function SkinInbox()
    local InboxFrame = _G.InboxFrame
    if not InboxFrame then return end

    S:StripTextures(InboxFrame)
    DisableBackdrop(InboxFrame)

    if _G.MailFrameInset then HideTexture(_G.MailFrameInset) end
    if _G.InboxFrameBg then HideTexture(_G.InboxFrameBg) end
    if _G.InboxFrame.Inset then S:StripTextures(_G.InboxFrame.Inset) end

    StylePageButton(_G.InboxPrevPageButton, "<")
    StylePageButton(_G.InboxNextPageButton, ">")
    StyleFont(_G.InboxTitleText, TITLE)
    StyleFont(_G.InboxTooMuchMail, TEXT)
    SkinInboxItems()

    local panel = GetPanel(_G.MailFrame, "_ktInboxContentPanel")
    local lastItem = _G["MailItem"..(_G.INBOXITEMS_TO_DISPLAY or 7)]
    if panel and _G.MailItem1 then
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", _G.MailItem1, "TOPLEFT", -5, 5)
        if _G.InboxNextPageButton then
            panel:SetPoint("BOTTOMRIGHT", _G.InboxNextPageButton, "BOTTOMRIGHT", 5, -5)
        elseif lastItem then
            panel:SetPoint("BOTTOMRIGHT", lastItem, "BOTTOMRIGHT", 5, -5)
        else
            panel:SetPoint("BOTTOMRIGHT", InboxFrame, "BOTTOMRIGHT", -8, 8)
        end
        SetPanelShown(panel, not InboxFrame.IsShown or InboxFrame:IsShown())
    end
end

local function SkinSendMail()
    local SendMailFrame = _G.SendMailFrame
    if not SendMailFrame then return end

    S:StripTextures(SendMailFrame)
    DisableBackdrop(SendMailFrame)

    if _G.SendMailScrollFrame then
        S:StripTextures(_G.SendMailScrollFrame)
        DisableBackdrop(_G.SendMailScrollFrame)
        if _G.SendMailScrollFrame.ScrollBar then S:HandleScrollBar(_G.SendMailScrollFrame.ScrollBar) end
    end

    for _, box in ipairs({
        _G.SendMailNameEditBox,
        _G.SendMailSubjectEditBox,
        _G.SendMailMoneyGold,
        _G.SendMailMoneySilver,
        _G.SendMailMoneyCopper,
    }) do
        S:HandleEditBox(box)
    end

    StyleFont(_G.SendMailTitleText, TITLE)
    StyleFont(_G.SendMailBodyEditBox, TEXT)
    StyleFont(_G.SendMailCostMoneyFrame, TEXT)

    HideTexture(_G.SendMailMoneyBg)
    if _G.SendMailMoneyInset then S:StripTextures(_G.SendMailMoneyInset) end
    if _G.SendMailMoney then S:StripTextures(_G.SendMailMoney) end

    StyleStandardButton(_G.SendMailMailButton)
    StyleStandardButton(_G.SendMailCancelButton)
    StyleCheckButton(_G.SendMailSendMoneyButton)
    StyleCheckButton(_G.SendMailCODButton)

    SkinSendMailAttachments()

    local panel = GetPanel(_G.MailFrame, "_ktSendContentPanel")
    if panel then
        panel:ClearAllPoints()
        local widthPanel = _G.MailFrame and _G.MailFrame._ktInboxContentPanel
        if widthPanel then
            panel:SetPoint("LEFT", widthPanel, "LEFT", 0, 0)
            panel:SetPoint("RIGHT", widthPanel, "RIGHT", 0, 0)
        elseif _G.SendMailNameEditBox then
            panel:SetPoint("LEFT", _G.SendMailNameEditBox, "LEFT", -82, 0)
        else
            panel:SetPoint("LEFT", SendMailFrame, "LEFT", 8, 0)
            panel:SetPoint("RIGHT", SendMailFrame, "RIGHT", -8, 0)
        end

        if _G.SendMailNameEditBox then
            panel:SetPoint("TOP", _G.SendMailNameEditBox, "TOP", 0, 34)
        else
            panel:SetPoint("TOP", SendMailFrame, "TOP", 0, -22)
        end

        panel:SetPoint("BOTTOM", SendMailFrame, "BOTTOM", 0, 36)

        if _G.SendMailCancelButton then
            _G.SendMailCancelButton:ClearAllPoints()
            _G.SendMailCancelButton:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 6)
        end
        if _G.SendMailMailButton and _G.SendMailCancelButton then
            _G.SendMailMailButton:ClearAllPoints()
            _G.SendMailMailButton:SetPoint("RIGHT", _G.SendMailCancelButton, "LEFT", -2, 0)
        end
        SetPanelShown(panel, SendMailFrame.IsShown and SendMailFrame:IsShown())
    end
end

local function SkinOpenMail()
    local OpenMailFrame = _G.OpenMailFrame
    if not OpenMailFrame then return end

    S:StripTextures(OpenMailFrame)
    SetBackdropBlack(OpenMailFrame, false)
    if OpenMailFrame.backdrop then
        S:RegisterBlizzardWindowBackground(OpenMailFrame.backdrop)
    end

    if _G.OpenMailFrameInset then S:StripTextures(_G.OpenMailFrameInset) end
    if _G.OpenMailScrollFrame then
        S:StripTextures(_G.OpenMailScrollFrame)
        DisableBackdrop(_G.OpenMailScrollFrame)
        if _G.OpenMailScrollFrame.ScrollBar then S:HandleScrollBar(_G.OpenMailScrollFrame.ScrollBar) end
    end

    S:HandleCloseButton(_G.OpenMailFrameCloseButton)

    for _, button in ipairs({
        _G.OpenMailReportSpamButton,
        _G.OpenMailReplyButton,
        _G.OpenMailDeleteButton,
        _G.OpenMailCancelButton,
        _G.OpenAllMail,
    }) do
        StyleStandardButton(button)
    end

    StyleFont(_G.OpenMailTitleText, TITLE)
    StyleFont(_G.MailTextFontNormal, TEXT)
    StyleFont(_G.InvoiceTextFontNormal, TEXT)

    HideTexture(_G.OpenMailArithmeticLine)
    StyleIconButton(_G.OpenMailLetterButton, _G.OpenMailLetterButtonIconTexture)
    StyleIconButton(_G.OpenMailMoneyButton, _G.OpenMailMoneyButtonIconTexture)
    SkinOpenMailAttachments()
end

local function SkinShellPanels()
    local MailFrame = _G.MailFrame
    if not MailFrame then return end
    local widthPanel = GetMailWidthPanel()

    local header = GetPanel(MailFrame, "_ktHeaderPanel")
    if header then
        header:ClearAllPoints()
        if widthPanel then
            header:SetPoint("LEFT", widthPanel, "LEFT", 0, 0)
            header:SetPoint("RIGHT", widthPanel, "RIGHT", 0, 0)
        else
            header:SetPoint("LEFT", MailFrame, "LEFT", 20, 0)
            header:SetPoint("RIGHT", MailFrame, "RIGHT", -18, 0)
        end
        header:SetPoint("TOP", MailFrame, "TOP", 0, -16)
        header:SetHeight(68)
        header:Show()
    end

    local footer = GetPanel(MailFrame, "_ktFooterPanel")
    if footer then
        footer:ClearAllPoints()
        if widthPanel then
            footer:SetPoint("LEFT", widthPanel, "LEFT", 0, 0)
            footer:SetPoint("RIGHT", widthPanel, "RIGHT", 0, 0)
        else
            footer:SetPoint("LEFT", MailFrame, "LEFT", 20, 0)
            footer:SetPoint("RIGHT", MailFrame, "RIGHT", -18, 0)
        end

        if _G.MailFrameTab1 and _G.MailFrameTab2 then
            footer:SetPoint("TOP", _G.MailFrameTab1, "TOP", 0, 5)
            footer:SetPoint("BOTTOM", _G.MailFrameTab1, "BOTTOM", 0, -5)
        else
            footer:SetPoint("TOP", MailFrame, "BOTTOM", 0, 38)
            footer:SetPoint("BOTTOM", MailFrame, "BOTTOM", 0, 6)
        end
        footer:Show()
    end
end

local function SkinMailFrame()
    if not Enabled() then return end

    local MailFrame = _G.MailFrame
    if not MailFrame then return end

    S:HandlePortraitFrame(MailFrame)
    DisableBackdrop(MailFrame)

    if MailFrame.NineSlice then S:StripTextures(MailFrame.NineSlice) end
    if MailFrame.Inset then S:StripTextures(MailFrame.Inset) end
    if MailFrame.TitleContainer then S:StripTextures(MailFrame.TitleContainer) end
    if MailFrame.TitleText then StyleFont(MailFrame.TitleText, TITLE) end

    S:HandleTab(_G.MailFrameTab1)
    S:HandleTab(_G.MailFrameTab2)

    SkinInbox()
    SkinSendMail()
    SkinOpenMail()
    SkinShellPanels()

    if MailFrame._ktInboxContentPanel then
        SetPanelShown(MailFrame._ktInboxContentPanel, _G.InboxFrame and _G.InboxFrame:IsShown())
    end
    if MailFrame._ktSendContentPanel then
        SetPanelShown(MailFrame._ktSendContentPanel, _G.SendMailFrame and _G.SendMailFrame:IsShown())
    end

    if not MailFrame._ktMailHooks then
        if _G.SendMailFrame_Update then hooksecurefunc("SendMailFrame_Update", SkinSendMailAttachments) end
        if _G.OpenMail_Update then hooksecurefunc("OpenMail_Update", SkinOpenMailAttachments) end
        if _G.InboxFrame_Update then hooksecurefunc("InboxFrame_Update", SkinInboxItems) end
        if _G.MailFrameTab1 then _G.MailFrameTab1:HookScript("OnClick", ScheduleMailSkin) end
        if _G.MailFrameTab2 then _G.MailFrameTab2:HookScript("OnClick", ScheduleMailSkin) end
        MailFrame._ktMailHooks = true
    end
end

ScheduleMailSkin = function()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, SkinMailFrame)
        C_Timer.After(0.05, SkinMailFrame)
    else
        SkinMailFrame()
    end
end

S.SkinFuncs["Blizzard_Mail"] = SkinMailFrame
S:AddCallback("MailFrame", SkinMailFrame)
S:AddCallback("KullThranUIMailBootstrap", function()
    SkinMailFrame()

    if not S._ktMailEventFrame then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("MAIL_SHOW")
        frame:RegisterEvent("MAIL_INBOX_UPDATE")
        frame:RegisterEvent("MAIL_SEND_INFO_UPDATE")
        frame:RegisterEvent("MAIL_SUCCESS")
        frame:SetScript("OnEvent", ScheduleMailSkin)
        S._ktMailEventFrame = frame
    end
end)
