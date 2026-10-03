local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local ipairs = ipairs
local select = select
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local math_ceil = math.ceil
local math_abs = math.abs
local unpack = unpack or table.unpack

local FONT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local FONT_FALLBACK = "Fonts\\FRIZQT__.TTF"
local BLANK = "Interface\\Buttons\\WHITE8x8"

local PAD = 10
local GAP = 6
local TOP = -30
local LABEL_COLUMN = 66
local SLOT_SIZE = 37

local TEXT = { 0.95, 0.95, 0.95, 1 }
local MUTED = { 0.62, 0.63, 0.67, 1 }
local CARD_FILL = { 0, 0, 0, 0.32 }
local CARD_EDGE = { 1, 1, 1, 0.07 }
local FIELD_FILL = { 0, 0, 0, 0.5 }
local FIELD_EDGE = { 1, 1, 1, 0.11 }
local SLOT_FILL = { 0, 0, 0, 0.42 }
local SLOT_EDGE = { 1, 1, 1, 0.10 }
local ROW_FILL = { 1, 1, 1, 0.025 }
local ROW_HOVER = { 1, 1, 1, 0.06 }

local ScheduleMailSkin

local function Enabled()
    return S.db and S.db.enable and S.db.mail
end

local function Accent()
    local c = S:GetAccentColor()
    return c[1], c[2], c[3]
end

local function MarkSurface(region)
    if region and S.GetFFD then
        S:GetFFD(region).kuiSurfaceRegion = true
    end
    return region
end

local function NewTexture(host, layer, sublevel)
    local t = host:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 1)
    t:SetTexture(BLANK)
    return MarkSurface(t)
end

local function CreateBox(host, layer, sublevel)
    sublevel = sublevel or 1
    local box = { fill = NewTexture(host, layer, sublevel), edges = {} }
    for i = 1, 4 do
        box.edges[i] = NewTexture(host, layer, math_min(7, sublevel + 1))
    end
    local m = S.mult or 1
    local fill, e = box.fill, box.edges
    e[1]:SetPoint("TOPLEFT", fill, "TOPLEFT")
    e[1]:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    e[1]:SetHeight(m)
    e[2]:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT")
    e[2]:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    e[2]:SetHeight(m)
    e[3]:SetPoint("TOPLEFT", fill, "TOPLEFT")
    e[3]:SetPoint("BOTTOMLEFT", fill, "BOTTOMLEFT")
    e[3]:SetWidth(m)
    e[4]:SetPoint("TOPRIGHT", fill, "TOPRIGHT")
    e[4]:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT")
    e[4]:SetWidth(m)
    return box
end

local function ColorBox(box, fill, edge)
    if not box then return end
    if fill then box.fill:SetVertexColor(fill[1], fill[2], fill[3], fill[4] or 1) end
    if edge then
        for i = 1, 4 do
            box.edges[i]:SetVertexColor(edge[1], edge[2], edge[3], edge[4] or 1)
        end
    end
end

local function ShowBox(box, shown)
    if not box then return end
    box.fill:SetShown(shown)
    for i = 1, 4 do box.edges[i]:SetShown(shown) end
end

local function PlaceBox(box, p1, rel1, rp1, x1, y1, p2, rel2, rp2, x2, y2)
    box.fill:ClearAllPoints()
    box.fill:SetPoint(p1, rel1, rp1, x1, y1)
    box.fill:SetPoint(p2, rel2, rp2, x2, y2)
end

local function GetCard(host, key)
    if not host then return end
    local card = host[key]
    if not card then
        card = CreateBox(host, "BACKGROUND", 2)
        ColorBox(card, CARD_FILL, CARD_EDGE)
        host[key] = card
    end
    return card
end

local function StyleText(fs, size, color, flags)
    if not (fs and fs.SetFont) then return end
    if not size then
        local _, current = fs:GetFont()
        size = (current and current > 0) and current or 12
    end
    if not fs:SetFont(FONT, size, flags or "") then
        fs:SetFont(FONT_FALLBACK, size, flags or "")
    end
    if color and fs.SetTextColor then fs:SetTextColor(color[1], color[2], color[3], color[4] or 1) end
    if fs.SetShadowOffset then fs:SetShadowOffset(1, -1) end
    if fs.SetShadowColor then fs:SetShadowColor(0, 0, 0, 0.9) end
end

local function StyleRegionsText(frame, size, color)
    if not (frame and frame.GetNumRegions) then return end
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            StyleText(region, size, color)
        end
    end
end

local function FindLabel(frame, text)
    if not (frame and frame.GetNumRegions and text) then return end
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("FontString") and region:GetText() == text then
            return region
        end
    end
end

local function Hide(region)
    if region and region.SetAlpha then region:SetAlpha(0) end
end

local function HideNamedPieces(frame)
    local name = frame and frame.GetName and frame:GetName()
    if not name then return end
    for _, suffix in ipairs({ "Left", "Middle", "Right", "Mid" }) do
        local piece = _G[name .. suffix]
        if piece and piece.IsObjectType and piece:IsObjectType("Texture") then
            piece:SetAlpha(0)
        end
    end
end

local function HideLayer(frame, layer)
    if not (frame and frame.GetNumRegions) then return end
    for i = 1, frame:GetNumRegions() do
        local region = select(i, frame:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("Texture") and region:GetDrawLayer() == layer then
            region:SetAlpha(0)
        end
    end
end

local function SetFieldFocus(box, focused)
    local field = box and box._ktMailField
    if not field then return end
    if focused then
        local r, g, b = Accent()
        ColorBox(field, nil, { r, g, b, 0.9 })
    else
        ColorBox(field, nil, FIELD_EDGE)
    end
end

local function StyleField(box, height, keepRegions)
    if not box or box._ktMailField then return end
    if keepRegions then
        HideNamedPieces(box)
    else
        S:StripTextures(box)
    end

    local field = CreateBox(box, "BACKGROUND", 1)
    PlaceBox(field, "TOPLEFT", box, "TOPLEFT", 0, 0, "BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    ColorBox(field, FIELD_FILL, FIELD_EDGE)
    box._ktMailField = field

    if height and box.SetHeight then box:SetHeight(height) end
    if box.SetTextInsets and not keepRegions then box:SetTextInsets(6, 6, 0, 0) end
    if box.SetFont then
        local _, size = box:GetFont()
        size = (size and size > 0) and math_min(size, 13) or 12
        if not box:SetFont(FONT, size, "") then box:SetFont(FONT_FALLBACK, size, "") end
    end
    if box.SetTextColor then box:SetTextColor(unpack(TEXT)) end
    if box.SetShadowOffset then box:SetShadowOffset(1, -1) end
    if box.SetCursorColor then box:SetCursorColor(1, 1, 1, 1) end
    if box.HookScript then
        box:HookScript("OnEditFocusGained", function(self) SetFieldFocus(self, true) end)
        box:HookScript("OnEditFocusLost", function(self) SetFieldFocus(self, false) end)
    end
end

local function StyleButton(button)
    if not button then return end
    S:HandleButton(button)
    local text = button.GetFontString and button:GetFontString()
    if text then StyleText(text, 12, TEXT) end
end

local function StyleCheck(button)
    if not button then return end
    S:HandleCheckBox(button)
    local name = button.GetName and button:GetName()
    local text = button.Text or button.text or (name and _G[name .. "Text"])
    if text then StyleText(text, 11) end
    if button.backdrop then S:SetInside(button.backdrop, button, 2) end
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked and button.backdrop then S:SetInside(checked, button.backdrop, 2) end
end

local function StyleCloseButton(frame)
    if not frame then return end
    local name = frame.GetName and frame:GetName()
    local close = frame.CloseButton or (name and _G[name .. "CloseButton"])
    if not close then return end
    S:HandleCloseButton(close)
    close:ClearAllPoints()
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
end

local function StyleScrollFrame(scroll)
    if not scroll then return end
    S:StripTextures(scroll)
    local bar = scroll.ScrollBar or (scroll.GetName and scroll:GetName() and _G[scroll:GetName() .. "ScrollBar"])
    if not bar then return end
    S:HandleScrollBar(bar)
    local barName = bar.GetName and bar:GetName()
    for _, key in ipairs({ "Back", "Forward", "ScrollUpButton", "ScrollDownButton", "UpButton", "DownButton" }) do
        local arrow = bar[key] or (barName and _G[barName .. key])
        if arrow and arrow.SetAlpha then arrow:SetAlpha(0) end
    end
end

local function GetQualityEdge(button)
    local border = button and button.IconBorder
    if border and border.IsShown and border:IsShown() and border.GetVertexColor then
        local r, g, b = border:GetVertexColor()
        if r and not (r > 0.99 and g > 0.99 and b > 0.99) then
            return { r, g, b, 1 }
        end
    end
end

local function GetSlotIcon(button)
    local name = button.GetName and button:GetName()
    return button.Icon or button.icon or (name and (_G[name .. "IconTexture"] or _G[name .. "Icon"]))
end

local function RefreshSlot(button)
    if not (button and button._ktMailSlot) then return end
    local slot = button._ktMailSlot
    local icon = GetSlotIcon(button)
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    local inset = (S.mult or 1)

    local tex = icon or normal
    if icon and normal then normal:SetAlpha(0) end

    local filled = false
    if tex and tex.GetTexture and tex:GetTexture() then
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
        tex:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
        tex:SetAlpha(1)
        filled = tex:IsShown() and true or false
    end

    if button.IconBorder then button.IconBorder:SetAlpha(0) end
    local quality = GetQualityEdge(button)
    ColorBox(slot, filled and { 0, 0, 0, 0.6 } or SLOT_FILL, quality or SLOT_EDGE)
end

local function StyleSlot(button)
    if not button then return end
    if not button._ktMailSlot then
        HideLayer(button, "BACKGROUND")
        local name = button.GetName and button:GetName()
        if name and _G[name .. "Slot"] then Hide(_G[name .. "Slot"]) end
        if button.IconOverlay then button.IconOverlay:SetDrawLayer("OVERLAY", 2) end

        local slot = CreateBox(button, "BACKGROUND", 1)
        PlaceBox(slot, "TOPLEFT", button, "TOPLEFT", 0, 0, "BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button._ktMailSlot = slot

        if button.SetHighlightTexture then
            button:SetHighlightTexture(BLANK)
            local highlight = button:GetHighlightTexture()
            if highlight then
                highlight:SetVertexColor(1, 1, 1, 0.12)
                highlight:ClearAllPoints()
                highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
                highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            end
        end
        if button.SetPushedTexture then
            button:SetPushedTexture(BLANK)
            local pushed = button:GetPushedTexture()
            if pushed then
                pushed:SetVertexColor(0, 0, 0, 0.3)
                pushed:ClearAllPoints()
                pushed:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
                pushed:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            end
        end
        if button.SetCheckedTexture then
            button:SetCheckedTexture(BLANK)
            local checked = button:GetCheckedTexture()
            if checked then
                local r, g, b = Accent()
                checked:SetVertexColor(r, g, b, 0.28)
                checked:ClearAllPoints()
                checked:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
                checked:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
            end
        end

        local count = button.Count or (name and _G[name .. "Count"])
        if count then
            StyleText(count, 11, TEXT, "OUTLINE")
            count:ClearAllPoints()
            count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        end
    end
    RefreshSlot(button)
end

local function GetSendAttachments()
    local list = {}
    local max = _G.ATTACHMENTS_MAX_SEND or 12
    for i = 1, max do
        local button = _G["SendMailAttachment" .. i]
        if button then list[#list + 1] = button end
    end
    return list
end

local function LayoutSendMail()
    local MailFrame, SendMailFrame = _G.MailFrame, _G.SendMailFrame
    if not (MailFrame and SendMailFrame and SendMailFrame._ktMailSkinned) then return end

    local width = MailFrame:GetWidth()
    if not width or width < 200 then width = 338 end
    local inner = width - PAD * 2

    local header = GetCard(SendMailFrame, "_ktHeaderCard")
    PlaceBox(header, "TOPLEFT", MailFrame, "TOPLEFT", PAD, TOP, "BOTTOMRIGHT", MailFrame, "TOPRIGHT", -PAD, TOP - 58)

    local name, subject = _G.SendMailNameEditBox, _G.SendMailSubjectEditBox
    if name then
        name:ClearAllPoints()
        name:SetPoint("TOPLEFT", header.fill, "TOPLEFT", LABEL_COLUMN, -7)
        name:SetWidth(math_max(80, inner - LABEL_COLUMN - 112))
    end
    if subject then
        subject:ClearAllPoints()
        subject:SetPoint("TOPLEFT", header.fill, "TOPLEFT", LABEL_COLUMN, -32)
        subject:SetPoint("RIGHT", header.fill, "RIGHT", -8, 0)
    end
    local cost = _G.SendMailCostMoneyFrame
    if cost then
        cost:ClearAllPoints()
        cost:SetPoint("TOPRIGHT", header.fill, "TOPRIGHT", -8, -11)
    end

    local cancel, send = _G.SendMailCancelButton, _G.SendMailMailButton
    if cancel then
        cancel:ClearAllPoints()
        cancel:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -PAD, 7)
        cancel:SetSize(80, 22)
    end
    if send then
        send:ClearAllPoints()
        if cancel then
            send:SetPoint("RIGHT", cancel, "LEFT", -4, 0)
        else
            send:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -PAD, 7)
        end
        send:SetSize(80, 22)
    end
    local purse = _G.SendMailMoneyFrame
    if purse then
        purse:ClearAllPoints()
        purse:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", PAD + 4, 12)
    end

    local money = GetCard(SendMailFrame, "_ktMoneyCard")
    PlaceBox(money, "BOTTOMLEFT", MailFrame, "BOTTOMLEFT", PAD, 36, "TOPRIGHT", MailFrame, "BOTTOMRIGHT", -PAD, 90)

    local sendMoney, cod = _G.SendMailSendMoneyButton, _G.SendMailCODButton
    if sendMoney then
        sendMoney:ClearAllPoints()
        sendMoney:SetPoint("TOPLEFT", money.fill, "TOPLEFT", 6, -4)
    end
    if cod then
        cod:ClearAllPoints()
        if sendMoney then
            local label = sendMoney.Text or sendMoney.text or _G.SendMailSendMoneyButtonText
            local labelWidth = (label and label.GetStringWidth and label:GetStringWidth()) or 70
            cod:SetPoint("LEFT", sendMoney, "RIGHT", labelWidth + 18, 0)
        else
            cod:SetPoint("TOPLEFT", money.fill, "TOPLEFT", 110, -4)
        end
    end
    local moneyInput = _G.SendMailMoney
    if moneyInput then
        moneyInput:ClearAllPoints()
        moneyInput:SetPoint("BOTTOMLEFT", money.fill, "BOTTOMLEFT", 12, 7)
    end
    local errorText = _G.SendMailErrorText
    if errorText then
        errorText:ClearAllPoints()
        errorText:SetPoint("TOPRIGHT", money.fill, "TOPRIGHT", -20, -8)
        errorText:SetJustifyH("RIGHT")
    end

    local perRow = _G.ATTACHMENTS_PER_ROW_SEND or 7
    local attachments = GetSendAttachments()
    local shown = 0
    for _, button in ipairs(attachments) do
        if button:IsShown() then shown = shown + 1 end
    end
    local rows = math_max(1, math_ceil(shown / perRow))
    local slotGap = math_floor((inner - 16 - perRow * SLOT_SIZE) / math_max(1, perRow - 1))
    slotGap = math_max(2, math_min(8, slotGap))
    local rowWidth = perRow * SLOT_SIZE + (perRow - 1) * slotGap
    local slotLeft = math_floor((inner - rowWidth) / 2)
    local cardHeight = rows * SLOT_SIZE + (rows - 1) * 4 + 16

    local attach = GetCard(SendMailFrame, "_ktAttachCard")
    PlaceBox(attach, "BOTTOMLEFT", money.fill, "TOPLEFT", 0, GAP, "TOPRIGHT", money.fill, "TOPRIGHT", 0, GAP + cardHeight)

    local index = 0
    for _, button in ipairs(attachments) do
        if button:IsShown() then
            local col = index % perRow
            local row = math_floor(index / perRow)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", attach.fill, "TOPLEFT", slotLeft + col * (SLOT_SIZE + slotGap), -8 - row * (SLOT_SIZE + 4))
            button:SetSize(SLOT_SIZE, SLOT_SIZE)
            index = index + 1
        end
        StyleSlot(button)
    end

    local body = GetCard(SendMailFrame, "_ktBodyCard")
    PlaceBox(body, "TOPLEFT", header.fill, "BOTTOMLEFT", 0, -GAP, "BOTTOMRIGHT", attach.fill, "TOPRIGHT", 0, GAP)

    local scroll = _G.SendMailScrollFrame
    if scroll then
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", body.fill, "TOPLEFT", 6, -6)
        scroll:SetPoint("BOTTOMRIGHT", body.fill, "BOTTOMRIGHT", -24, 6)
        local scrollWidth = scroll:GetWidth()
        if scrollWidth and scrollWidth > 40 then
            local child = _G.SendMailScrollChildFrame
            if child then child:SetWidth(scrollWidth) end
            local editBox = _G.SendMailBodyEditBox
            if editBox then
                editBox:ClearAllPoints()
                editBox:SetPoint("TOPLEFT", child or scroll, "TOPLEFT", 4, -4)
                editBox:SetWidth(scrollWidth - 8)
            end
        end
    end
end

local function SetupSendMail()
    local SendMailFrame = _G.SendMailFrame
    if not SendMailFrame or SendMailFrame._ktMailSkinned then return end

    S:StripTextures(SendMailFrame)
    for _, key in ipairs({ "SendMailMoneyInset", "SendMailMoneyBg" }) do
        local frame = _G[key]
        if frame then
            S:StripTextures(frame)
            if frame.NineSlice then frame.NineSlice:SetAlpha(0) end
            frame:SetAlpha(0)
        end
    end
    StyleScrollFrame(_G.SendMailScrollFrame)
    Hide(_G.SendStationeryBackgroundLeft)
    Hide(_G.SendStationeryBackgroundRight)

    local name, subject = _G.SendMailNameEditBox, _G.SendMailSubjectEditBox
    StyleField(name, 22)
    StyleField(subject, 22)
    StyleText(FindLabel(name, _G.MAIL_TO_LABEL), 11, MUTED)
    StyleText(FindLabel(subject, _G.MAIL_SUBJECT_LABEL), 11, MUTED)

    local body = _G.SendMailBodyEditBox
    if body then
        StyleText(body, 13, TEXT)
        if body.SetTextColor then body:SetTextColor(unpack(TEXT)) end
        if body.SetCursorColor then body:SetCursorColor(1, 1, 1, 1) end
    end

    for _, suffix in ipairs({ "Gold", "Silver", "Copper" }) do
        StyleField(_G["SendMailMoney" .. suffix], nil, true)
    end
    Hide(_G.SendMailMoneyText)

    StyleRegionsText(_G.SendMailCostMoneyFrame, 11, MUTED)
    StyleButton(_G.SendMailMailButton)
    StyleButton(_G.SendMailCancelButton)
    StyleCheck(_G.SendMailSendMoneyButton)
    StyleCheck(_G.SendMailCODButton)
    StyleText(_G.SendMailErrorText, 10)

    SendMailFrame._ktMailSkinned = true
    SendMailFrame:HookScript("OnShow", function()
        if C_Timer and C_Timer.After then C_Timer.After(0, LayoutSendMail) else LayoutSendMail() end
    end)
end

local function SetRowHover(item, hovered)
    local row = item and item._ktMailRow
    if not row then return end
    ColorBox(row, hovered and ROW_HOVER or ROW_FILL, nil)
    if item._ktMailAccent then item._ktMailAccent:SetShown(hovered and true or false) end
end

local function StyleInboxItem(item)
    if not item or item._ktMailItem then return end
    S:StripTextures(item)

    local row = CreateBox(item, "BACKGROUND", 1)
    PlaceBox(row, "TOPLEFT", item, "TOPLEFT", 0, 0, "BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
    ColorBox(row, ROW_FILL, CARD_EDGE)
    item._ktMailRow = row

    local accent = NewTexture(item, "BACKGROUND", 4)
    accent:SetPoint("TOPLEFT", row.fill, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", row.fill, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(2)
    accent:SetVertexColor(Accent())
    accent:Hide()
    item._ktMailAccent = accent
    S:RegisterBlizzardAccentRefresh(item, function(self, color)
        if self._ktMailAccent then self._ktMailAccent:SetVertexColor(color[1], color[2], color[3], 1) end
    end)

    local button = item.Button or _G[(item:GetName() or "") .. "Button"]
    if button then
        StyleSlot(button)
        button:ClearAllPoints()
        button:SetPoint("LEFT", item, "LEFT", 6, 0)
        button:SetSize(34, 34)
        button:HookScript("OnEnter", function() SetRowHover(item, true) end)
        button:HookScript("OnLeave", function() SetRowHover(item, false) end)
        item._ktMailButton = button
    end

    local name = item:GetName()
    local sender = name and _G[name .. "Sender"]
    local subject = name and _G[name .. "Subject"]
    if sender then
        StyleText(sender, 12)
        sender:ClearAllPoints()
        sender:SetPoint("TOPLEFT", item, "TOPLEFT", 48, -7)
    end
    if subject then
        StyleText(subject, 11)
        subject:ClearAllPoints()
        subject:SetPoint("TOPLEFT", sender or item, sender and "BOTTOMLEFT" or "TOPLEFT", 0, -3)
    end
    local expire = item.ExpireTime or (name and _G[name .. "ExpireTime"])
    if expire then
        local text = expire.GetFontString and expire:GetFontString()
        if text then StyleText(text, 10) end
        expire:ClearAllPoints()
        expire:SetPoint("TOPRIGHT", item, "TOPRIGHT", -6, -6)
    end

    item._ktMailItem = true
end

local function RefreshInbox()
    local InboxFrame = _G.InboxFrame
    if not (InboxFrame and InboxFrame._ktMailSkinned) then return end
    local max = _G.INBOXITEMS_TO_DISPLAY or 7
    for i = 1, max do
        local item = _G["MailItem" .. i]
        if item then
            StyleInboxItem(item)
            local button = item._ktMailButton
            local used = button and button:IsShown()
            ShowBox(item._ktMailRow, used and true or false)
            if not used and item._ktMailAccent then item._ktMailAccent:Hide() end
            if button then RefreshSlot(button) end
            local name = item:GetName()
            local sender = name and _G[name .. "Sender"]
            local subject = name and _G[name .. "Subject"]
            if sender and subject then
                local r, _, b = sender:GetTextColor()
                local read = r and r < 0.8 and math_abs(r - b) < 0.05
                if read then
                    sender:SetTextColor(unpack(MUTED))
                    subject:SetTextColor(0.48, 0.49, 0.52, 1)
                else
                    sender:SetTextColor(unpack(TEXT))
                    subject:SetTextColor(0.78, 0.79, 0.82, 1)
                end
            end
        end
    end
end

local function LayoutInbox()
    local MailFrame, InboxFrame = _G.MailFrame, _G.InboxFrame
    if not (MailFrame and InboxFrame and InboxFrame._ktMailSkinned) then return end

    local height = MailFrame:GetHeight()
    if not height or height < 200 then height = 424 end
    local max = _G.INBOXITEMS_TO_DISPLAY or 7
    local spacing = 3
    local available = height + TOP - 40 - 12
    local rowHeight = math_floor((available - (max - 1) * spacing) / max)
    rowHeight = math_max(36, math_min(45, rowHeight))
    local listHeight = max * rowHeight + (max - 1) * spacing + 12

    local list = GetCard(InboxFrame, "_ktListCard")
    PlaceBox(list, "TOPLEFT", MailFrame, "TOPLEFT", PAD, TOP, "BOTTOMRIGHT", MailFrame, "TOPRIGHT", -PAD, TOP - listHeight)

    for i = 1, max do
        local item = _G["MailItem" .. i]
        if item then
            item:ClearAllPoints()
            item:SetPoint("TOPLEFT", list.fill, "TOPLEFT", 6, -6 - (i - 1) * (rowHeight + spacing))
            item:SetPoint("RIGHT", list.fill, "RIGHT", -6, 0)
            item:SetHeight(rowHeight)
        end
    end

    local prev, nextButton = _G.InboxPrevPageButton, _G.InboxNextPageButton
    if prev then
        prev:ClearAllPoints()
        prev:SetPoint("BOTTOMLEFT", MailFrame, "BOTTOMLEFT", PAD, 9)
    end
    if nextButton then
        nextButton:ClearAllPoints()
        nextButton:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -PAD, 9)
    end
    local page = _G.InboxCurrentPage
    if page then
        page:ClearAllPoints()
        page:SetJustifyH("RIGHT")
        if nextButton then
            page:SetPoint("RIGHT", nextButton, "LEFT", -8, 0)
        else
            page:SetPoint("BOTTOMRIGHT", MailFrame, "BOTTOMRIGHT", -PAD, 14)
        end
    end
    local openAll = _G.OpenAllMail
    if openAll then
        openAll:ClearAllPoints()
        openAll:SetPoint("BOTTOM", MailFrame, "BOTTOM", -18, 8)
        openAll:SetSize(120, 22)
    end
end

local function StylePageButton(button, glyph)
    if not button or button._ktMailPage then return end
    S:StripTextures(button)
    for _, method in ipairs({ "SetNormalTexture", "SetPushedTexture", "SetDisabledTexture" }) do
        if button[method] then button[method](button, BLANK) end
    end
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
        local tex = button[getter] and button[getter](button)
        if tex then tex:SetAlpha(0) end
    end
    for i = 1, button:GetNumRegions() do
        local region = select(i, button:GetRegions())
        if region and region.IsObjectType and region:IsObjectType("FontString") then region:SetAlpha(0) end
    end
    button:SetSize(22, 22)

    local box = CreateBox(button, "BACKGROUND", 1)
    PlaceBox(box, "TOPLEFT", button, "TOPLEFT", 0, 0, "BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    ColorBox(box, FIELD_FILL, FIELD_EDGE)
    button._ktMailBox = box

    if button.SetHighlightTexture then
        button:SetHighlightTexture(BLANK)
        local highlight = button:GetHighlightTexture()
        if highlight then
            highlight:SetVertexColor(1, 1, 1, 0.1)
            highlight:ClearAllPoints()
            highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        end
    end

    local arrow = button:CreateFontString(nil, "OVERLAY")
    StyleText(arrow, 13, TEXT)
    arrow:SetText(glyph)
    arrow:SetPoint("CENTER", button, "CENTER", 0, 0)
    button._ktMailArrow = arrow

    local function Refresh(self)
        local enabled = self:IsEnabled()
        if self._ktMailArrow then self._ktMailArrow:SetAlpha(enabled and 1 or 0.3) end
    end
    hooksecurefunc(button, "Enable", Refresh)
    hooksecurefunc(button, "Disable", Refresh)
    if button.SetEnabled then hooksecurefunc(button, "SetEnabled", Refresh) end
    Refresh(button)
    button._ktMailPage = true
end

local function SetupInbox()
    local InboxFrame = _G.InboxFrame
    if not InboxFrame or InboxFrame._ktMailSkinned then return end

    S:StripTextures(InboxFrame)
    Hide(_G.InboxFrameBg)
    StylePageButton(_G.InboxPrevPageButton, "<")
    StylePageButton(_G.InboxNextPageButton, ">")
    StyleText(_G.InboxCurrentPage, 11, MUTED)
    StyleRegionsText(_G.InboxTooMuchMail, 11)
    StyleButton(_G.OpenAllMail)

    InboxFrame._ktMailSkinned = true
    InboxFrame:HookScript("OnShow", function()
        LayoutInbox()
        RefreshInbox()
    end)
end

local function GetOpenAttachments()
    local list = { _G.OpenMailLetterButton, _G.OpenMailMoneyButton }
    local max = _G.ATTACHMENTS_MAX_RECEIVE or 16
    for i = 1, max do
        local button = _G["OpenMailAttachmentButton" .. i]
        if button then list[#list + 1] = button end
    end
    return list
end

local function RefreshOpenMail()
    local OpenMailFrame = _G.OpenMailFrame
    if not (OpenMailFrame and OpenMailFrame._ktMailSkinned) then return end
    for _, button in ipairs(GetOpenAttachments()) do
        StyleSlot(button)
    end
end

local function SetupOpenMail()
    local OpenMailFrame = _G.OpenMailFrame
    if not OpenMailFrame or OpenMailFrame._ktMailSkinned then return end

    S:HandlePortraitFrame(OpenMailFrame)
    StyleCloseButton(OpenMailFrame)
    local inset = OpenMailFrame.Inset or _G.OpenMailFrameInset
    if inset then
        S:StripTextures(inset)
        if inset.NineSlice then inset.NineSlice:SetAlpha(0) end
    end
    Hide(_G.OpenMailHorizontalBarLeft)

    local scroll = _G.OpenMailScrollFrame
    StyleScrollFrame(scroll)
    Hide(_G.OpenStationeryBackgroundLeft)
    Hide(_G.OpenStationeryBackgroundRight)
    if scroll then
        local card = GetCard(OpenMailFrame, "_ktBodyCard")
        PlaceBox(card, "TOPLEFT", scroll, "TOPLEFT", -4, 4, "BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 24, -4)
    end

    StyleText(_G.OpenMailSenderLabel, 11, MUTED)
    StyleText(_G.OpenMailSubjectLabel, 11, MUTED)
    StyleText(_G.OpenMailSubject, 12, TEXT)
    if _G.OpenMailSender and _G.OpenMailSender.Name then StyleText(_G.OpenMailSender.Name, 12, TEXT) end
    StyleText(_G.OpenMailAttachmentText, 11, MUTED)

    for _, button in ipairs({
        _G.OpenMailReportSpamButton,
        _G.OpenMailReplyButton,
        _G.OpenMailDeleteButton,
        _G.OpenMailCancelButton,
    }) do
        StyleButton(button)
    end

    OpenMailFrame._ktMailSkinned = true
    RefreshOpenMail()
end

local function SetupFonts()
    for _, key in ipairs({ "MailTextFontNormal", "InvoiceTextFontNormal", "InvoiceTextFontSmall" }) do
        local font = _G[key]
        if font and font.SetTextColor then
            font:SetTextColor(0.9, 0.9, 0.9)
            if font.SetShadowOffset then font:SetShadowOffset(1, -1) end
            if font.SetShadowColor then font:SetShadowColor(0, 0, 0, 0.9) end
        end
    end
end

local function SkinAutoComplete()
    local box = _G.AutoCompleteBox
    if not box or box._ktMailAutoComplete then return end

    if box.NineSlice then box.NineSlice:SetAlpha(0) end
    S:StripTextures(box)
    local frame = CreateBox(box, "BACKGROUND", 1)
    PlaceBox(frame, "TOPLEFT", box, "TOPLEFT", 0, 0, "BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
    ColorBox(frame, { 0.055, 0.055, 0.065, 0.97 }, { 1, 1, 1, 0.14 })

    local max = _G.AUTOCOMPLETE_MAX_BUTTONS or 5
    for i = 1, max do
        local button = _G["AutoCompleteButton" .. i]
        if button then
            local text = button.GetFontString and button:GetFontString()
            if text then StyleText(text, 12) end
            if button.SetHighlightTexture then
                button:SetHighlightTexture(BLANK)
                local highlight = button:GetHighlightTexture()
                if highlight then
                    local r, g, b = Accent()
                    highlight:SetVertexColor(r, g, b, 0.22)
                    highlight:ClearAllPoints()
                    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 6, 0)
                    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 0)
                end
            end
            S:RegisterBlizzardAccentRefresh(button, function(self, color)
                local highlight = self.GetHighlightTexture and self:GetHighlightTexture()
                if highlight then highlight:SetVertexColor(color[1], color[2], color[3], 0.22) end
            end)
        end
    end
    StyleText(_G.AutoCompleteInstructions, 10, MUTED)
    box._ktMailAutoComplete = true
end

local function SetupShell()
    local MailFrame = _G.MailFrame
    if not MailFrame or MailFrame._ktMailShell then return end

    S:HandlePortraitFrame(MailFrame)
    StyleCloseButton(MailFrame)
    for _, inset in ipairs({ MailFrame.Inset, _G.MailFrameInset }) do
        if inset then
            S:StripTextures(inset)
            if inset.NineSlice then inset.NineSlice:SetAlpha(0) end
        end
    end
    if MailFrame.TitleContainer then S:StripTextures(MailFrame.TitleContainer) end
    local title = MailFrame.TitleText or (MailFrame.TitleContainer and MailFrame.TitleContainer.TitleText) or _G.MailFrameTitleText
    if title then StyleText(title, 13, TEXT) end
    StyleText(_G.InboxTitleText, 13, TEXT)
    StyleText(_G.SendMailTitleText, 13, TEXT)

    S:HandleTab(_G.MailFrameTab1)
    S:HandleTab(_G.MailFrameTab2)

    MailFrame._ktMailShell = true
end

local function SkinMailFrame()
    if not Enabled() then return end
    local MailFrame = _G.MailFrame
    if not MailFrame then return end

    SetupShell()
    SetupFonts()
    SetupInbox()
    SetupSendMail()
    SetupOpenMail()
    SkinAutoComplete()

    LayoutInbox()
    RefreshInbox()
    LayoutSendMail()
    RefreshOpenMail()

    if not MailFrame._ktMailHooks then
        if _G.SendMailFrame_Update then hooksecurefunc("SendMailFrame_Update", LayoutSendMail) end
        if _G.InboxFrame_Update then hooksecurefunc("InboxFrame_Update", RefreshInbox) end
        if _G.OpenMail_Update then hooksecurefunc("OpenMail_Update", RefreshOpenMail) end
        if _G.MailFrameTab_OnClick then
            hooksecurefunc("MailFrameTab_OnClick", ScheduleMailSkin)
        else
            if _G.MailFrameTab1 then _G.MailFrameTab1:HookScript("OnClick", ScheduleMailSkin) end
            if _G.MailFrameTab2 then _G.MailFrameTab2:HookScript("OnClick", ScheduleMailSkin) end
        end
        MailFrame:HookScript("OnSizeChanged", ScheduleMailSkin)
        MailFrame._ktMailHooks = true
    end
end

ScheduleMailSkin = function()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, SkinMailFrame)
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
