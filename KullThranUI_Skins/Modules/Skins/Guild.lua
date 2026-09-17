local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local pairs, next, select, ipairs = pairs, next, select, ipairs
local unpack = unpack or table.unpack
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local GuildControlGetNumRanks = GuildControlGetNumRanks
local GetNumGuildBankTabs = GetNumGuildBankTabs

local FONT_AVANT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local BLANK_TEX  = "Interface\\Buttons\\WHITE8x8"

local function InnerBackdrop(frame, transparent)
    if frame and not frame.backdrop then
        S:CreateFlatBackdrop(frame, transparent)
    end
end

local function HandleFont(obj)
    if not obj then return end
    local _, size = obj:GetFont()
    if not size or size <= 0 then size = 11 end
    obj:SetFont(FONT_AVANT, size, "OUTLINE")
end

local function HideDecos(frame)
    if not frame then return end
    for _, k in ipairs({
        "Background","Bg","BgTile","NineSlice","Inset","InsetBg",
        "TitleBg","TitleBgLeft","TitleBgRight",
        "TopBorder","BottomBorder","LeftBorder","RightBorder",
        "TopBorderLeft","TopBorderRight","BottomBorderLeft","BottomBorderRight",
        "TopFiligree","BottomFiligree","FilligreeOverlay",
        "PortraitOverlay","TopTileStreaks","BotTileStreaks",
        "Selection","SelectedTexture","SelectHighlight","SelectedHighlight",
        "HighlightCover","SelectionBorder",
    }) do
        if frame[k] then
            if frame[k].SetAlpha then frame[k]:SetAlpha(0) end
            if frame[k].Hide     then frame[k]:Hide()     end
        end
    end
    if frame.GetHighlightTexture and frame:GetHighlightTexture() then
        frame:GetHighlightTexture():SetColorTexture(1, 1, 1, 0.08)
        frame:GetHighlightTexture():SetBlendMode("ADD")
    end
end

-- Guild deliberately uses a neutral palette. The configurable accent is very
-- effective for compact action controls, but using it on every navigation and
-- selection state makes this large window unnecessarily noisy.
local GUILD_BG       = { 0.045, 0.045, 0.055, 0.97 }
local GUILD_PANEL    = { 0.070, 0.070, 0.082, 0.90 }
local GUILD_NAV      = { 0.105, 0.105, 0.125, 0.96 }
local GUILD_HOVER    = { 0.125, 0.125, 0.145, 0.98 }
local GUILD_SELECTED = { 0.175, 0.175, 0.200, 1.00 }
local GUILD_BORDER   = { 0.000, 0.000, 0.000, 1.00 }
local GUILD_EDGE     = { 0.300, 0.300, 0.340, 0.95 }
local GUILD_FOCUS    = { 0.620, 0.620, 0.660, 0.90 }

local function SetBackdrop(backdrop, background, border)
    if not backdrop then return end
    backdrop:SetBackdropColor(unpack(background or GUILD_PANEL))
    backdrop:SetBackdropBorderColor(unpack(border or GUILD_BORDER))
end

local function NeutralPanel(frame, transparent)
    if not frame then return end
    if not frame.backdrop then S:CreateFlatBackdrop(frame, transparent) end
    SetBackdrop(frame.backdrop, transparent and GUILD_PANEL or GUILD_BG, GUILD_EDGE)
    if not frame._ktGuildPanelTexture and frame.CreateTexture then
        local texture = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        texture:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
        texture:SetHorizTile(true)
        texture:SetVertTile(true)
        texture:SetVertexColor(0.30, 0.30, 0.34, 1)
        texture:SetAlpha(0.34)
        texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        frame._ktGuildPanelTexture = texture
    end
end

local function SkinNeutralButton(button)
    if not button then return end
    S:HandleButton(button)
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    local pushed = button.GetPushedTexture and button:GetPushedTexture()
    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if normal    then normal:SetVertexColor(0.11, 0.11, 0.125, 0.96) end
    if pushed    then pushed:SetVertexColor(0.30, 0.30, 0.34, 0.38) end
    if highlight then highlight:SetVertexColor(1, 1, 1, 0.08) end
    SetBackdrop(button.backdrop, GUILD_PANEL, GUILD_EDGE)
    if button._ktGuildNeutralButton then return end
    button:HookScript("OnEnter", function(self) SetBackdrop(self.backdrop, GUILD_HOVER, GUILD_FOCUS) end)
    button:HookScript("OnLeave", function(self) SetBackdrop(self.backdrop, GUILD_PANEL, GUILD_EDGE) end)
    button._ktGuildNeutralButton = true
end

local function SkinNeutralSymbolButton(button, symbol)
    if not button then return end
    SkinNeutralButton(button)
    button:SetSize(18, 18)
    if not button._ktGuildSymbol then
        local text = button:CreateFontString(nil, "OVERLAY")
        text:SetFont(FONT_AVANT, 13, "OUTLINE")
        text:SetText(symbol)
        text:SetTextColor(0.95, 0.95, 0.97, 1)
        text:SetPoint("CENTER", button, "CENTER", 0, 1)
        button._ktGuildSymbol = text
    end
end

local function SkinScrollStepper(button, pointsUp)
    if not button then return end
    if button.Texture then button.Texture:SetAlpha(0) end

    if not button._ktGuildArrow then
        local arrow = button:CreateTexture(nil, "OVERLAY", nil, 7)
        arrow:SetAtlas("common-dropdown-icon")
        arrow:SetSize(9, 9)
        arrow:SetPoint("CENTER")
        if pointsUp and arrow.SetRotation then arrow:SetRotation(3.14159265) end
        if arrow.SetDesaturated then arrow:SetDesaturated(true) end
        button._ktGuildArrow = arrow

        local function UpdateArrow(self)
            local enabled = not self.IsEnabled or self:IsEnabled()
            local over = enabled and self.IsMouseOver and self:IsMouseOver()
            if over then
                arrow:SetVertexColor(1, 1, 1, 1)
            elseif enabled then
                arrow:SetVertexColor(0.62, 0.62, 0.68, 0.95)
            else
                arrow:SetVertexColor(0.28, 0.28, 0.31, 0.70)
            end
        end
        button:HookScript("OnEnter", UpdateArrow)
        button:HookScript("OnLeave", UpdateArrow)
        button:HookScript("OnEnable", UpdateArrow)
        button:HookScript("OnDisable", UpdateArrow)
        UpdateArrow(button)
    end
end

local function SkinNeutralScrollBar(scrollBar)
    if not scrollBar then return end
    S:HandleScrollBar(scrollBar)
    scrollBar:SetWidth(10)

    -- Track is parented to the scrollbar itself. MinimalScrollBar disables all
    -- draw layers on its Track when skinned, so textures parented there vanish.
    if scrollBar._ktGuildTrack then scrollBar._ktGuildTrack:Hide() end
    if not scrollBar._ktGuildModernTrack then
        local track = scrollBar:CreateTexture(nil, "BACKGROUND", nil, 2)
        track:SetColorTexture(0.012, 0.012, 0.016, 0.96)
        track:SetPoint("TOP", scrollBar, "TOP", 0, -13)
        track:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 13)
        track:SetWidth(4)
        scrollBar._ktGuildModernTrack = track
    end

    local thumb = scrollBar.Track and scrollBar.Track.Thumb
    if thumb then
        if thumb.backdrop then
            thumb.backdrop:ClearAllPoints()
            thumb.backdrop:SetPoint("TOPLEFT", thumb, "TOPLEFT", 1, -1)
            thumb.backdrop:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -1, 1)
            thumb.backdrop:SetBackdropColor(0.43, 0.43, 0.49, 1)
            thumb.backdrop:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)
        end
        if not thumb._ktGuildModernFill then
            local fill = thumb:CreateTexture(nil, "ARTWORK", nil, 7)
            fill:SetColorTexture(0.43, 0.43, 0.49, 1)
            fill:SetPoint("TOPLEFT", thumb, "TOPLEFT", 2, -2)
            fill:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 2)
            thumb._ktGuildModernFill = fill

            thumb:HookScript("OnEnter", function(self)
                self._ktGuildModernFill:SetColorTexture(0.72, 0.72, 0.78, 1)
            end)
            thumb:HookScript("OnLeave", function(self)
                self._ktGuildModernFill:SetColorTexture(0.43, 0.43, 0.49, 1)
            end)
            thumb:HookScript("OnMouseDown", function(self)
                self._ktGuildModernFill:SetColorTexture(0.86, 0.86, 0.90, 1)
            end)
            thumb:HookScript("OnMouseUp", function(self)
                self._ktGuildModernFill:SetColorTexture(0.72, 0.72, 0.78, 1)
            end)
        end
    elseif scrollBar.ThumbTexture then
        scrollBar.ThumbTexture:SetColorTexture(0.43, 0.43, 0.49, 1)
        scrollBar.ThumbTexture:SetWidth(6)
    end

    SkinScrollStepper(scrollBar.Back or scrollBar.ScrollUpButton or scrollBar.UpButton, true)
    SkinScrollStepper(scrollBar.Forward or scrollBar.ScrollDownButton or scrollBar.DownButton, false)
    scrollBar._ktGuildModernScrollBar = true
end

local function SetNeutralFrameText(frame)
    if not (frame and frame.GetRegions) then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            HandleFont(region)
            region:SetTextColor(0.95, 0.95, 0.97, 1)
        end
    end
end

local function UpdateNeutralTab(tab)
    if not tab or not tab.backdrop then return end
    local checked = tab.GetChecked and tab:GetChecked()
    if checked then
        SetBackdrop(tab.backdrop, GUILD_SELECTED, GUILD_FOCUS)
    elseif tab.IsMouseOver and tab:IsMouseOver() then
        SetBackdrop(tab.backdrop, GUILD_HOVER, { 0.38, 0.38, 0.42, 0.85 })
    else
        SetBackdrop(tab.backdrop, GUILD_PANEL, GUILD_BORDER)
    end
    if tab._ktGuildSelectionBar then tab._ktGuildSelectionBar:SetShown(checked and true or false) end
    if tab.Icon then
        tab.Icon:SetAlpha(checked and 1 or 0.72)
        if tab.Icon.SetDesaturated then tab.Icon:SetDesaturated(not checked) end
        tab.Icon:SetVertexColor(1, 1, 1, 1)
    end
end

local function SkinNeutralTab(tab)
    if not tab then return end
    if not tab._ktGuildNeutralTab then
        S:StripTextures(tab)
        S:CreateBackdrop(tab)
        if tab.backdrop then
            tab.backdrop:ClearAllPoints()
            tab.backdrop:SetPoint("TOPLEFT", tab, "TOPLEFT", 2, -2)
            tab.backdrop:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -2, 2)
        end
        local marker = tab:CreateTexture(nil, "OVERLAY", nil, 7)
        marker:SetColorTexture(unpack(GUILD_FOCUS))
        marker:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -3)
        marker:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 1, 3)
        marker:SetWidth(2)
        tab._ktGuildSelectionBar = marker
        tab:HookScript("OnEnter", UpdateNeutralTab)
        tab:HookScript("OnLeave", UpdateNeutralTab)
        tab:HookScript("OnClick", function(self)
            if C_Timer then C_Timer.After(0, function() UpdateNeutralTab(self) end) end
        end)
        if tab.SetChecked then hooksecurefunc(tab, "SetChecked", UpdateNeutralTab) end
        tab._ktGuildNeutralTab = true
    end
    if tab.Icon then
        tab.Icon:SetAlpha(1)
        tab.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if tab.backdrop then S:SetInside(tab.Icon, tab.backdrop, 2) end
    end
    UpdateNeutralTab(tab)
end

local function LayoutNeutralTabs(frame)
    if not frame then return end
    local previousTab
    for _, name in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" }) do
        local tab = frame[name]
        if tab and tab:IsShown() then
            tab:ClearAllPoints()
            if previousTab then
                tab:SetPoint("TOPLEFT", previousTab, "BOTTOMLEFT", 0, -8)
            else
                tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 3, -39)
            end
            previousTab = tab
        end
    end
end

local function AddRowDivider(row)
    if not row or row._ktGuildDivider then return end
    local divider = row:CreateTexture(nil, "BACKGROUND", nil, 2)
    divider:SetColorTexture(1, 1, 1, 0.045)
    divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 0)
    divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3, 0)
    divider:SetHeight(1)
    row._ktGuildDivider = divider
end

local function StyleCommunityRow(row, communitiesFrame)
    if not row then return end
    if row.Background then
        row.Background:SetColorTexture(unpack(GUILD_NAV))
        row.Background:SetAlpha(1)
    end
    if row.CircleMask    then row.CircleMask:Hide() end
    if row.SelectedGlow then row.SelectedGlow:SetAlpha(0) end
    if row.NineSlice    then row.NineSlice:SetAlpha(0) end
    if not row._ktGuildSelection then
        local selection = row:CreateTexture(nil, "BACKGROUND", nil, 3)
        selection:SetColorTexture(unpack(GUILD_SELECTED))
        selection:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
        selection:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
        row._ktGuildSelection = selection
        local marker = row:CreateTexture(nil, "ARTWORK", nil, 4)
        marker:SetColorTexture(unpack(GUILD_FOCUS))
        marker:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -2)
        marker:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 2)
        marker:SetWidth(2)
        row._ktGuildSelectionMarker = marker
    end
    local selected = communitiesFrame and row.clubId and communitiesFrame.GetSelectedClubId
        and row.clubId == communitiesFrame:GetSelectedClubId()
    row._ktGuildSelection:SetShown(selected and true or false)
    row._ktGuildSelectionMarker:SetShown(selected and true or false)
    if row.Selection then row.Selection:SetAlpha(0) end
    if row.IconRing then row.IconRing:SetAlpha(1) end
    if row.GuildTabardBorder then
        if row.GuildTabardBorder.SetDesaturated then row.GuildTabardBorder:SetDesaturated(false) end
        row.GuildTabardBorder:SetVertexColor(1, 1, 1, 1)
    end
    if row.GetHighlightTexture and row:GetHighlightTexture() then
        row:GetHighlightTexture():SetColorTexture(1, 1, 1, 0.075)
        row:GetHighlightTexture():SetBlendMode("ADD")
    end
    if row.Icon then
        row.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        row.Icon:SetAlpha(1)
        row.Icon:Show()
        if row.Icon.SetDesaturated then row.Icon:SetDesaturated(false) end
        row.Icon:SetVertexColor(1, 1, 1, 1)
    end
    if row.Name then
        HandleFont(row.Name)
        row.Name:SetTextColor(0.95, 0.95, 0.97, 1)
    end
    AddRowDivider(row)
end

local function StyleMemberRow(row)
    if not row then return end
    local normal = row.GetNormalTexture and row:GetNormalTexture()
    if normal then
        normal:SetColorTexture(0.055, 0.055, 0.066, 0.72)
        normal:SetAllPoints(row)
    end
    if row.NameFrame and row.NameFrame.Name then HandleFont(row.NameFrame.Name) end
    for _, field in ipairs({ "Name", "Zone", "Level", "Rank", "Note", "GuildInfo" }) do
        if row[field] then HandleFont(row[field]) end
    end
    if row.GetHighlightTexture and row:GetHighlightTexture() then
        row:GetHighlightTexture():SetColorTexture(1, 1, 1, 0.055)
        row:GetHighlightTexture():SetBlendMode("ADD")
    end
    AddRowDivider(row)
end

local function GuildBankOnShow(frame)
    if frame.IsSkinned then return end
    S:StripTextures(frame)
    S:CreateBackdrop(frame, true)
    if frame.BorderBox then S:StripTextures(frame.BorderBox) end
    S:HandleButton(_G.GuildBankPopupCancelButton)
    S:HandleButton(_G.GuildBankPopupOkayButton)
    S:HandleEditBox(_G.GuildBankPopupEditBox)
    frame.IsSkinned = true
end

local function UpdateGuildBankSideTab(button)
    if not (button and button.backdrop) then return end
    local checked = button.GetChecked and button:GetChecked()
    if checked then
        SetBackdrop(button.backdrop, GUILD_SELECTED, GUILD_FOCUS)
    elseif button.IsMouseOver and button:IsMouseOver() then
        SetBackdrop(button.backdrop, GUILD_HOVER, GUILD_FOCUS)
    else
        SetBackdrop(button.backdrop, GUILD_PANEL, GUILD_BORDER)
    end
    if button.IconTexture then
        button.IconTexture:SetAlpha(checked and 1 or 0.72)
        if button.IconTexture.SetDesaturated then button.IconTexture:SetDesaturated(not checked) end
    end
end

local function SkinGuildBankSideTab(button)
    if not button then return end
    local icon = button.IconTexture
    local texture = icon and icon:GetTexture()
    if not button._ktGuildBankSideTab then
        S:StripTextures(button)
        S:CreateFlatBackdrop(button, true)
        if button.backdrop then
            button.backdrop:ClearAllPoints()
            button.backdrop:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            button.backdrop:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        end
        button:HookScript("OnEnter", UpdateGuildBankSideTab)
        button:HookScript("OnLeave", UpdateGuildBankSideTab)
        button:HookScript("OnClick", function(self)
            if C_Timer then C_Timer.After(0, function() UpdateGuildBankSideTab(self) end) end
        end)
        if button.SetChecked then hooksecurefunc(button, "SetChecked", UpdateGuildBankSideTab) end
        button._ktGuildBankSideTab = true
    end
    if icon then
        if texture then icon:SetTexture(texture) end
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if button.backdrop then S:SetInside(icon, button.backdrop, 2) end
    end
    UpdateGuildBankSideTab(button)
end

local function SkinGuildRegistrar()
    if not (S.db.enable and S.db.guild) then return end
    local GuildRegistrarFrame = _G.GuildRegistrarFrame
    if not GuildRegistrarFrame then return end
    S:HandlePortraitFrame(GuildRegistrarFrame)
    if GuildRegistrarFrame.ScrollBar then SkinNeutralScrollBar(GuildRegistrarFrame.ScrollBar) end
    local EditBox = _G.GuildRegistrarFrameEditBox
    if EditBox then
        S:StripTextures(EditBox)
        if _G.GuildRegistrarGreetingFrame then S:StripTextures(_G.GuildRegistrarGreetingFrame) end
        S:HandleButton(_G.GuildRegistrarFrameGoodbyeButton)
        S:HandleButton(_G.GuildRegistrarFrameCancelButton)
        S:HandleButton(_G.GuildRegistrarFramePurchaseButton)
        S:HandleEditBox(EditBox)
        for _, region in next, { EditBox:GetRegions() } do
            if region:IsObjectType("Texture") then
                local tex = region:GetTexture()
                if tex == [[Interface\ChatFrame\UI-ChatInputBorder-Left]]
                or tex == [[Interface\ChatFrame\UI-ChatInputBorder-Right]] then
                    S:Kill(region)
                end
            end
        end
        EditBox:SetHeight(20)
    end
    for i = 1, 2 do
        local btn = _G["GuildRegistrarButton"..i]
        if btn and btn.GetFontString then btn:GetFontString():SetTextColor(1, 1, 1) end
    end
    if _G.GuildRegistrarPurchaseText then _G.GuildRegistrarPurchaseText:SetTextColor(1, 1, 1) end
    if _G.AvailableServicesText      then _G.AvailableServicesText:SetTextColor(1, 1, 0)    end
end

local function IsGuildInviteIconTexture(region)
    if not (region and region.IsObjectType and region:IsObjectType("Texture")) then return false end
    local name = region.GetName and region:GetName()
    if type(name) ~= "string" then return false end
    name = name:lower()
    if name:find("button", 1, true) or name:find("highlight", 1, true)
        or name:find("normal", 1, true) or name:find("disabled", 1, true) then
        return false
    end
    return name:find("icon", 1, true) or name:find("emblem", 1, true)
        or name:find("tabard", 1, true) or name:find("logo", 1, true)
end

local function CollectGuildInviteIconTextures(frame)
    local textures = {}
    local seen = {}
    local function Add(region)
        if region and not seen[region] and region.IsObjectType and region:IsObjectType("Texture") then
            seen[region] = true
            textures[#textures + 1] = region
        end
    end
    local function Scan(container, depth)
        if not (container and container.GetRegions) then return end
        for i = 1, container:GetNumRegions() do
            local region = select(i, container:GetRegions())
            if IsGuildInviteIconTexture(region) then Add(region) end
        end
        if depth > 0 and container.GetChildren then
            for _, child in ipairs({ container:GetChildren() }) do
                Scan(child, depth - 1)
            end
        end
    end

    for _, key in ipairs({ "Icon", "GuildIcon", "GuildEmblem", "Emblem", "Tabard", "GuildTabard", "GuildLogo", "Logo" }) do
        local candidate = frame[key] or _G["GuildInviteFrame" .. key]
        if candidate and candidate.IsObjectType and candidate:IsObjectType("Texture") then
            Add(candidate)
        elseif candidate then
            Scan(candidate, 1)
        end
    end
    Scan(frame, 1)
    return textures
end

local function RestoreGuildInviteIconTextures(textures)
    for _, icon in ipairs(textures or {}) do
        if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        if icon.SetDrawLayer then icon:SetDrawLayer("OVERLAY", 7) end
        if icon.SetAlpha then icon:SetAlpha(1) end
        if icon.Show then icon:Show() end
    end
end

local function SkinGuildInvite()
    if not (S.db.enable and S.db.guild) then return end
    local GuildInviteFrame = _G.GuildInviteFrame
    if not GuildInviteFrame then return end

    local iconTextures = CollectGuildInviteIconTextures(GuildInviteFrame)
    if not GuildInviteFrame._ktGuildInviteSkinned then
        S:StripTextures(GuildInviteFrame)
        GuildInviteFrame._ktGuildInviteSkinned = true
    end
    RestoreGuildInviteIconTextures(iconTextures)
    S:CreateBackdrop(GuildInviteFrame, true)
    if GuildInviteFrame.Points then
        GuildInviteFrame.Points:ClearAllPoints()
        GuildInviteFrame.Points:SetPoint("TOP", GuildInviteFrame, "CENTER", 15, -25)
    end
    S:HandleButton(_G.GuildInviteFrameJoinButton)
    S:HandleButton(_G.GuildInviteFrameDeclineButton)
    GuildInviteFrame:SetHeight(225)
if not GuildInviteFrame._ktGuildInviteEventHooked then
        GuildInviteFrame:HookScript("OnEvent", function(frame, event)
            -- Deferred: this popup's OnEvent may run inside Blizzard's protected
            -- context; a synchronous SetHeight here dirties UIParent's layout and
            -- taints a later MultiBar ActionButton update.
            C_Timer.After(0, function()
                if not (frame.IsForbidden and frame:IsForbidden()) then
                    frame:SetHeight(225)
                end
            end)
            if event == "GUILD_INVITE_REQUEST" then
                C_Timer.After(0, function()
                    RestoreGuildInviteIconTextures(CollectGuildInviteIconTextures(frame))
                end)
            end
        end)
        GuildInviteFrame._ktGuildInviteEventHooked = true
    end
    if _G.GuildInviteFrameWarningText then S:Kill(_G.GuildInviteFrameWarningText) end
end
local function SkinGuildBank()
    if not (S.db.enable and S.db.guild) then return end
    local frame = _G.GuildBankFrame
    if not frame then return end
    S:StripTextures(frame)
    S:SkinPremiumWindow(frame)
    if not frame.backdrop then S:CreateFlatBackdrop(frame, true) end
    SetBackdrop(frame.backdrop, GUILD_BG, GUILD_EDGE)
    S:RegisterBlizzardWindowBackground(frame.backdrop)
    S:RegisterBlizzardWindowBorder(frame.backdrop, function(self, enabled)
        self:SetBackdropBorderColor(GUILD_EDGE[1], GUILD_EDGE[2], GUILD_EDGE[3], enabled and (GUILD_EDGE[4] or 1) or 0)
    end)
    local shellData = S:GetFFD(frame)
    if shellData.atlasBorderFrame then shellData.atlasBorderFrame:Hide() end
    if shellData.topBar then
        shellData.topBar:SetColorTexture(0, 0, 0, 0.35)
        shellData.topBar:SetHeight(24)
    end
    if not frame._ktGuildBankDivider then
        local divider = frame:CreateTexture(nil, "ARTWORK", nil, 6)
        local color = S:GetAccentColor()
        divider:SetColorTexture(color[1], color[2], color[3], 0.48)
        divider:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -24)
        divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -24)
        divider:SetHeight(1)
        frame._ktGuildBankDivider = divider
    end
    if frame.CloseButton  then S:HandleCloseButton(frame.CloseButton) end
    if frame.Emblem       then S:Kill(frame.Emblem) end
    if frame.MoneyFrameBG then
        S:StripTextures(frame.MoneyFrameBG)
        NeutralPanel(frame.MoneyFrameBG, true)
    end
    if frame.TitleText then HandleFont(frame.TitleText); frame.TitleText:SetTextColor(0.95, 0.95, 0.97, 1) end
    if frame.TabTitle then HandleFont(frame.TabTitle); frame.TabTitle:SetTextColor(1, 1, 1, 1) end
    if frame.LimitLabel then HandleFont(frame.LimitLabel); frame.LimitLabel:SetTextColor(0.78, 0.78, 0.82, 1) end
    S:HandleButton(frame.DepositButton)
    S:HandleButton(frame.WithdrawButton)
    S:HandleButton(_G.GuildBankInfoSaveButton)
    S:HandleButton(frame.BuyInfo.PurchaseButton)
    frame.WithdrawButton:ClearAllPoints()
    frame.WithdrawButton:SetPoint("RIGHT", frame.DepositButton, "LEFT", -2, 0)
    if _G.GuildBankInfoScrollFrame then
        _G.GuildBankInfoScrollFrame:SetPoint("TOPLEFT", _G.GuildBankInfo, "TOPLEFT", -10, 12)
        S:StripTextures(_G.GuildBankInfoScrollFrame)
        _G.GuildBankInfoScrollFrame:SetWidth(_G.GuildBankInfoScrollFrame:GetWidth() - 8)
    end
    if frame.BlackBG then
        InnerBackdrop(frame.BlackBG)
        if frame.BlackBG.backdrop then
            SetBackdrop(frame.BlackBG.backdrop, GUILD_BG, GUILD_EDGE)
            frame.BlackBG.backdrop:SetPoint("TOPLEFT",      frame.BlackBG, "TOPLEFT",      4,  0)
            frame.BlackBG.backdrop:SetPoint("BOTTOMRIGHT", frame.BlackBG, "BOTTOMRIGHT", -3,  3)
        end
    end
    if frame.Log and frame.Log.ScrollBar and frame.BlackBG and frame.BlackBG.backdrop then
        SkinNeutralScrollBar(frame.Log.ScrollBar)
        frame.Log.ScrollBar:ClearAllPoints()
        frame.Log.ScrollBar:SetPoint("TOPRIGHT",    frame.BlackBG.backdrop, -8, -4)
        frame.Log.ScrollBar:SetPoint("BOTTOMRIGHT", frame.BlackBG.backdrop, -8,  4)
    end
    if _G.GuildBankInfoScrollFrame and _G.GuildBankInfoScrollFrame.ScrollBar
    and frame.BlackBG and frame.BlackBG.backdrop then
        SkinNeutralScrollBar(_G.GuildBankInfoScrollFrame.ScrollBar)
        _G.GuildBankInfoScrollFrame.ScrollBar:ClearAllPoints()
        _G.GuildBankInfoScrollFrame.ScrollBar:SetPoint("TOPRIGHT",    frame.BlackBG.backdrop, -8, -4)
        _G.GuildBankInfoScrollFrame.ScrollBar:SetPoint("BOTTOMRIGHT", frame.BlackBG.backdrop, -8,  4)
    end
    for i = 1, _G.MAX_GUILDBANK_TABS or 8 do
        local tab = _G["GuildBankTab"..i]
        if tab then
            S:StripTextures(tab)
            local button  = tab.Button
            SkinGuildBankSideTab(button)
        end
    end
    for i = 1, 7 do
        local column = frame["Column"..i]
        S:StripTextures(column)
        for x = 1, 14 do
            local button = column["Button"..x]
            local normal = button.GetNormalTexture and button:GetNormalTexture()
            if normal then normal:SetAlpha(0) end
            local pushed = button.GetPushedTexture and button:GetPushedTexture()
            if pushed then pushed:SetVertexColor(1, 1, 1, 0.12) end
            local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
            if highlight then highlight:SetColorTexture(1, 1, 1, 0.10) end
            InnerBackdrop(button)
            SetBackdrop(button.backdrop, { 0.025, 0.025, 0.032, 0.98 }, { 0.15, 0.15, 0.18, 1 })
            if button.icon then
                S:SetInside(button.icon)
                button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end
            if button.IconBorder then button.IconBorder:SetAlpha(0) end
        end
    end
    for i = 1, 4 do S:HandleTab(_G["GuildBankFrameTab"..i]) end
    local GuildItemSearchBox = _G.GuildItemSearchBox
    if GuildItemSearchBox then
        if GuildItemSearchBox.Left       then S:Kill(GuildItemSearchBox.Left)       end
        if GuildItemSearchBox.Middle     then S:Kill(GuildItemSearchBox.Middle)     end
        if GuildItemSearchBox.Right      then S:Kill(GuildItemSearchBox.Right)      end
        if GuildItemSearchBox.searchIcon then S:Kill(GuildItemSearchBox.searchIcon) end
        S:HandleEditBox(GuildItemSearchBox)
    end
    if not _G.ArkInventory then
        _G.GuildBankPopupFrame:HookScript("OnShow", GuildBankOnShow)
    end
end

local function SkinGuildRanks()
    for i = 1, GuildControlGetNumRanks() do
        local rankFrame = _G["GuildControlUIRankOrderFrameRank"..i]
        if rankFrame then
            if not rankFrame.nameBox.backdrop then
                S:HandleEditBox(rankFrame.nameBox)
                S:HandleButton(rankFrame.downButton)
                S:HandleButton(rankFrame.upButton)
                S:HandleButton(rankFrame.deleteButton)
            end
            if rankFrame.nameBox.backdrop then
                rankFrame.nameBox.backdrop:ClearAllPoints()
                rankFrame.nameBox.backdrop:SetPoint("TOPLEFT",     -2, -4)
                rankFrame.nameBox.backdrop:SetPoint("BOTTOMRIGHT",  4,  4)
            end
        end
    end
end

local function SkinBankTabs()
    local numTabs = GetNumGuildBankTabs()
    if numTabs < (_G.MAX_BUY_GUILDBANK_TABS or 8) then numTabs = numTabs + 1 end
    for i = 1, numTabs do
        local tab = _G["GuildControlBankTab"..i]
        if not tab then break end
        local buy = tab.buy
        if buy and buy.button and not buy.button.IsSkinned then
            S:HandleButton(buy.button); buy.button.IsSkinned = true
        end
        local owned = tab.owned
        if owned then
            if owned.tabIcon   then owned.tabIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)           end
            if owned.editBox   and not owned.editBox.backdrop    then S:HandleEditBox(owned.editBox)   end
            if owned.viewCB    and not owned.viewCB.isSkinned    then S:HandleCheckBox(owned.viewCB)   end
            if owned.depositCB and not owned.depositCB.isSkinned then S:HandleCheckBox(owned.depositCB) end
        end
    end
end

local function SkinGuildControl()
    if not (S.db.enable and S.db.guild) then return end
    if _G.GuildControlUI then
        S:StripTextures(_G.GuildControlUI)
        S:CreateBackdrop(_G.GuildControlUI, true)
    end
    local RankSettingsFrameGoldBox = _G.GuildControlUIRankSettingsFrameGoldBox
    if RankSettingsFrameGoldBox then
        S:HandleEditBox(RankSettingsFrameGoldBox)
        if RankSettingsFrameGoldBox.backdrop then
            RankSettingsFrameGoldBox.backdrop:SetPoint("TOPLEFT",     -2, -4)
            RankSettingsFrameGoldBox.backdrop:SetPoint("BOTTOMRIGHT",  2,  4)
        end
        S:StripTextures(RankSettingsFrameGoldBox)
    end
    S:HandleButton(_G.GuildControlUIRankOrderFrameNewButton)
    S:HandleButton(_G.GuildControlUICloseButton)
    S:HandleDropDownBox(_G.GuildControlUIRankBankFrameRankDropdown, 180)
    S:HandleDropDownBox(_G.GuildControlUINavigationDropdown)
    S:HandleDropDownBox(_G.GuildControlUIRankSettingsFrameRankDropdown, 180)
    if _G.GuildControlUIRankBankFrameInsetScrollFrame then
        SkinNeutralScrollBar(_G.GuildControlUIRankBankFrameInsetScrollFrame.ScrollBar)
    end
    for _, name in ipairs({
        "GuildControlUIRankBankFrame","GuildControlUIRankBankFrameInset",
        "GuildControlUIRankBankFrameInsetScrollFrame","GuildControlUIHbar",
    }) do
        if _G[name] then S:StripTextures(_G[name]) end
    end
    _G.GuildControlUIRankOrderFrameNewButton:HookScript("OnClick", function()
        C_Timer.After(0.1, SkinGuildRanks)
    end)
    S:HandleCheckBox(_G.GuildControlUIRankSettingsFrameOfficerCheckbox)
    for i = 1, _G.NUM_RANK_FLAGS or 20 do
        local checkbox = _G["GuildControlUIRankSettingsFrameCheckbox"..i]
        if checkbox then S:HandleCheckBox(checkbox) end
    end
    hooksecurefunc("GuildControlUI_BankTabPermissions_Update", SkinBankTabs)
    hooksecurefunc("GuildControlUI_RankOrder_Update", SkinGuildRanks)
end

local function SkinCommunities()
    if not (S.db.enable and S.db.guild) then return end
    local CF = _G.CommunitiesFrame
    if not CF then return end

    if CF.Bg then CF.Bg:SetAlpha(0) end
    if CF.NineSlice then CF.NineSlice:SetAlpha(0) end
    if CF.Background then CF.Background:SetAlpha(0) end
    if CF.PortraitContainer then CF.PortraitContainer:SetAlpha(0) end

    S:HandlePortraitFrame(CF)
    HideDecos(CF)
    if CF.PortraitOverlay then S:Kill(CF.PortraitOverlay) end

    -- Replace the premium/Blizzard chrome with a restrained Modern KUI shell.
    local data = S:GetFFD(CF)
    if data.atlasBorderFrame then data.atlasBorderFrame:Hide() end
    if data.topBar then data.topBar:SetColorTexture(0, 0, 0, 0.35) end

    if not CF._ktGuildShellBorder then
        local border = CreateFrame("Frame", nil, CF, "BackdropTemplate")
        border:SetAllPoints(CF)
        border:SetFrameLevel(CF:GetFrameLevel() + 20)
        border:SetBackdrop({ edgeFile = BLANK_TEX, edgeSize = S.mult or 1 })
        border:SetBackdropBorderColor(unpack(GUILD_EDGE))
        CF._ktGuildShellBorder = border
        S:RegisterBlizzardWindowBorder(border, function(self, enabled)
            self:SetBackdropBorderColor(unpack(GUILD_EDGE))
            self:SetAlpha(enabled and 1 or 0)
        end)

        local divider = CF:CreateTexture(nil, "BACKGROUND", nil, -3)
        divider:SetColorTexture(0.32, 0.32, 0.35, 0.72)
        divider:SetPoint("TOPLEFT", CF, "TOPLEFT", 1, -25)
        divider:SetPoint("TOPRIGHT", CF, "TOPRIGHT", -1, -25)
        divider:SetHeight(1)
        CF._ktGuildHeaderDivider = divider
    end
    local title = CF.TitleText or (CF.TitleContainer and CF.TitleContainer.TitleText)
    if title then
        HandleFont(title)
        title:SetTextColor(0.92, 0.92, 0.95, 1)
    end
    if CF.CloseButton then S:HandleCloseButton(CF.CloseButton) end
    if CF.MaximizeMinimizeFrame then
        SkinNeutralSymbolButton(CF.MaximizeMinimizeFrame.MaximizeButton, "+")
        SkinNeutralSymbolButton(CF.MaximizeMinimizeFrame.MinimizeButton, "-")
    end
    if CF.Inset then S:StripTextures(CF.Inset) end

    for _, name in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" }) do
        local tab = CF[name]
        if tab then
            SkinNeutralTab(tab)
        end
    end
    LayoutNeutralTabs(CF)

    if CF.CommunitiesList then
        local CL = CF.CommunitiesList
        HideDecos(CL)
        if CL.ScrollBar  then SkinNeutralScrollBar(CL.ScrollBar) end
        if CL.InsetFrame then S:StripTextures(CL.InsetFrame) end
        NeutralPanel(CL, true)

        if CL.ScrollBox then
            local function UpdateCommunityRows(self)
                self:ForEachFrame(function(child)
                    StyleCommunityRow(child, CF)
                end)
            end
            hooksecurefunc(CL.ScrollBox, "Update", UpdateCommunityRows)
            UpdateCommunityRows(CL.ScrollBox)
        end
    end

    if CF.MemberList then
        local ML = CF.MemberList
        if ML.ListScrollFrame and ML.ListScrollFrame.ScrollBar then
            SkinNeutralScrollBar(ML.ListScrollFrame.ScrollBar)
        end
        if ML.ShowOfflineButton then S:HandleCheckBox(ML.ShowOfflineButton) end
        if ML.InviteButton      then SkinNeutralButton(ML.InviteButton) end
        if CF.InviteButton      then SkinNeutralButton(CF.InviteButton) end
        if ML.ColumnDisplay     then S:StripTextures(ML.ColumnDisplay) end
        if ML.InsetFrame        then HideDecos(ML.InsetFrame) end
        if ML.MemberCount       then HandleFont(ML.MemberCount) end
        NeutralPanel(ML.ListScrollFrame, true)

        if ML.ScrollBox then
            local function UpdateMemberRows(self)
                self:ForEachFrame(function(child)
                    StyleMemberRow(child)
                end)
            end
            hooksecurefunc(ML.ScrollBox, "Update", UpdateMemberRows)
            UpdateMemberRows(ML.ScrollBox)
        end
    end

    if CF.Chat then
        local Chat = CF.Chat
        if Chat.MessageEntryBox then S:HandleEditBox(Chat.MessageEntryBox); HandleFont(Chat.MessageEntryBox) end
        if Chat.InsetFrame      then HideDecos(Chat.InsetFrame); S:StripTextures(Chat.InsetFrame) end
        if Chat.MessageFrame    then Chat.MessageFrame:SetFont(FONT_AVANT, 12, "OUTLINE") end
        if Chat.ScrollBar       then SkinNeutralScrollBar(Chat.ScrollBar) end
        if Chat.JumpToUnreadButton then SkinNeutralButton(Chat.JumpToUnreadButton) end
        NeutralPanel(Chat.MessageFrame, true)
    end

    if CF.ChatEditBox then
        S:HandleEditBox(CF.ChatEditBox)
        SetBackdrop(CF.ChatEditBox.backdrop, { 0.035, 0.035, 0.044, 0.98 }, GUILD_EDGE)
        CF.ChatEditBox:SetTextInsets(7, 7, 0, 0)
    end

    if CF.GuildBenefitsFrame then
        local B = CF.GuildBenefitsFrame
        HideDecos(B)
        if B.Perks then
            HideDecos(B.Perks)
            NeutralPanel(B.Perks, true)
            if B.Perks.ScrollBar then SkinNeutralScrollBar(B.Perks.ScrollBar) end
            if B.Perks.ScrollBox then
                hooksecurefunc(B.Perks.ScrollBox, "Update", function(self)
                    self:ForEachFrame(function(child)
                        HideDecos(child)
                        if child.Icon then child.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); child.Icon:SetAlpha(1) end
                        if child.Name        then HandleFont(child.Name)        end
                        if child.Description then HandleFont(child.Description) end
                        AddRowDivider(child)
                    end)
                end)
            end
        end
        if B.Rewards then
            HideDecos(B.Rewards)
            NeutralPanel(B.Rewards, true)
            if B.Rewards.ScrollBar then SkinNeutralScrollBar(B.Rewards.ScrollBar) end
            if B.Rewards.ScrollBox then
                hooksecurefunc(B.Rewards.ScrollBox, "Update", function(self)
                    self:ForEachFrame(function(child)
                        HideDecos(child)
                        if child.Icon then child.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92); child.Icon:SetAlpha(1) end
                        if child.Name        then HandleFont(child.Name)        end
                        if child.Description then HandleFont(child.Description) end
                        AddRowDivider(child)
                    end)
                end)
            end
        end
        if B.FactionBar then
            S:StripTextures(B.FactionBar)
            if B.FactionBar.Bar then
                S:StripTextures(B.FactionBar.Bar)
                S:HandleStatusBar(B.FactionBar.Bar)
            end
            if B.FactionBar.Label then HandleFont(B.FactionBar.Label) end
        end
    end

    if CF.GuildLog then
        local GL = CF.GuildLog
        HideDecos(GL)
        if GL.ScrollBar then SkinNeutralScrollBar(GL.ScrollBar) end
        if GL.Container then
            S:StripTextures(GL.Container)
            NeutralPanel(GL.Container, true)
        end
        if GL.ScrollBox then
            hooksecurefunc(GL.ScrollBox, "Update", function(self)
                self:ForEachFrame(function(child)
                    if child.Text then HandleFont(child.Text) end
                end)
            end)
        end
    end

    if CF.GuildInfoFrame then
        local I = CF.GuildInfoFrame
        HideDecos(I)
        if I.Info then
            S:StripTextures(I.Info)
            NeutralPanel(I.Info, true)
        end
        if I.Name        then HandleFont(I.Name)        end
        if I.Description then HandleFont(I.Description) end
        if I.MotD        then HandleFont(I.MotD)        end
        if I.MotDScrollFrame and I.MotDScrollFrame.Child and I.MotDScrollFrame.Child.Text then
            HandleFont(I.MotDScrollFrame.Child.Text)
        end
    end

    for _, control in ipairs({
        CF.StreamDropdown, CF.GuildMemberListDropdown,
        CF.CommunityMemberListDropdown, CF.CommunitiesListDropdown,
    }) do
        if control then
            S:HandleDropDownBox(control)
            SetBackdrop(control.backdrop, GUILD_PANEL, GUILD_EDGE)
            if control.Button then SkinNeutralButton(control.Button) end
            SetNeutralFrameText(control)
        end
    end

    if CF.AddToChatButton       then SkinNeutralButton(CF.AddToChatButton)       end
    if CF.CommunityFinderButton then SkinNeutralButton(CF.CommunityFinderButton) end
    if CF.InviteButton          then SkinNeutralButton(CF.InviteButton)          end
    if CF.GuildLogButton        then SkinNeutralButton(CF.GuildLogButton)        end

    local controlFrame = CF.CommunitiesControlFrame
    if controlFrame then
        for _, key in ipairs({ "CommunitiesSettingsButton", "GuildControlButton", "GuildRecruitmentButton" }) do
            SkinNeutralButton(controlFrame[key])
        end
    end

    local function LayoutGuildChatEditBox()
        local editBox = CF.ChatEditBox
        local chat = CF.Chat
        if not (editBox and chat and editBox:IsShown()) then return end

        -- Blizzard uses the same bottom strip for the 32px chat input and the
        -- guild action buttons. With a flat backdrop the overlap becomes very
        -- obvious, so reserve the area occupied by the leftmost visible action.
        if CF.GetWidth and CF:GetWidth() < 500 then return end

        -- Compact Modern KUI footer controls leave substantially more room for
        -- typing than Blizzard's fixed 130/165px buttons.
        if CF.InviteButton then CF.InviteButton:SetWidth(112) end
        if CF.GuildLogButton then CF.GuildLogButton:SetWidth(108) end
        if controlFrame then
            if controlFrame.CommunitiesSettingsButton then controlFrame.CommunitiesSettingsButton:SetWidth(126) end
            if controlFrame.GuildRecruitmentButton then controlFrame.GuildRecruitmentButton:SetWidth(104) end
            if controlFrame.GuildControlButton then controlFrame.GuildControlButton:SetWidth(108) end
        end

        local leftmostButton
        for _, button in ipairs({
            controlFrame and controlFrame.CommunitiesSettingsButton,
            controlFrame and controlFrame.GuildRecruitmentButton,
            controlFrame and controlFrame.GuildControlButton,
            CF.InviteButton,
            CF.GuildLogButton,
        }) do
            if button and button:IsShown() and button:GetLeft() then
                if not leftmostButton or button:GetLeft() < leftmostButton:GetLeft() then
                    leftmostButton = button
                end
            end
        end

        editBox:ClearAllPoints()
        editBox:SetHeight(20)
        editBox:SetPoint("BOTTOMLEFT", chat, "BOTTOMLEFT", -4, -23)
        if leftmostButton then
            editBox:SetPoint("BOTTOMRIGHT", leftmostButton, "BOTTOMLEFT", -6, 0)
        else
            editBox:SetPoint("BOTTOMRIGHT", chat, "BOTTOMRIGHT", 3, -23)
        end
    end

    local function QueueGuildFooterLayout()
        if C_Timer then C_Timer.After(0, LayoutGuildChatEditBox) else LayoutGuildChatEditBox() end
    end

    if not CF._ktGuildFooterHooked then
        if controlFrame and controlFrame.Update then
            hooksecurefunc(controlFrame, "Update", QueueGuildFooterLayout)
        end
        if CF.SetDisplayMode then hooksecurefunc(CF, "SetDisplayMode", QueueGuildFooterLayout) end
        CF.ChatEditBox:HookScript("OnShow", QueueGuildFooterLayout)
        CF:HookScript("OnSizeChanged", QueueGuildFooterLayout)
        for _, button in ipairs({
            controlFrame and controlFrame.CommunitiesSettingsButton,
            controlFrame and controlFrame.GuildRecruitmentButton,
            controlFrame and controlFrame.GuildControlButton,
            CF.InviteButton,
            CF.GuildLogButton,
        }) do
            if button then
                button:HookScript("OnShow", QueueGuildFooterLayout)
                button:HookScript("OnHide", QueueGuildFooterLayout)
            end
        end
        CF._ktGuildFooterHooked = true
    end
    QueueGuildFooterLayout()

    local function RefreshGuildSkin()
        LayoutNeutralTabs(CF)
        for _, name in ipairs({ "ChatTab", "RosterTab", "GuildBenefitsTab", "GuildInfoTab" }) do
            UpdateNeutralTab(CF[name])
        end
        if CF.CommunitiesList and CF.CommunitiesList.ScrollBox then
            CF.CommunitiesList.ScrollBox:ForEachFrame(function(child)
                StyleCommunityRow(child, CF)
            end)
        end
        for _, control in ipairs({
            CF.StreamDropdown, CF.GuildMemberListDropdown,
            CF.CommunityMemberListDropdown, CF.CommunitiesListDropdown,
        }) do
            SetNeutralFrameText(control)
        end
        if CF.ChatEditBox and CF.ChatEditBox.backdrop then
            SetBackdrop(CF.ChatEditBox.backdrop, { 0.035, 0.035, 0.044, 0.98 }, GUILD_EDGE)
        end
        QueueGuildFooterLayout()
    end

    if not CF._ktGuildRefreshHooked then
        if CF.UpdateCommunitiesTabs then hooksecurefunc(CF, "UpdateCommunitiesTabs", RefreshGuildSkin) end
        CF:HookScript("OnShow", function()
            if C_Timer then C_Timer.After(0, RefreshGuildSkin) else RefreshGuildSkin() end
        end)
        CF._ktGuildRefreshHooked = true
    end
    RefreshGuildSkin()
end

local function SkinLookingForGuild()
    if not (S.db.enable and S.db.guild) then return end
    local LookingForGuildFrame = _G.LookingForGuildFrame
    if not LookingForGuildFrame then return end
    S:HandlePortraitFrame(LookingForGuildFrame)
    for _, name in ipairs({
        "LookingForGuildPvPButton","LookingForGuildWeekendsButton","LookingForGuildWeekdaysButton",
        "LookingForGuildRPButton","LookingForGuildRaidButton","LookingForGuildQuestButton","LookingForGuildDungeonButton",
    }) do S:HandleCheckBox(_G[name]) end
    for _, name in ipairs({ "LookingForGuildTankButton","LookingForGuildHealerButton","LookingForGuildDamagerButton" }) do
        if _G[name] then S:HandleCheckBox(_G[name].checkButton) end
    end
    if _G.LookingForGuildBrowseFrameContainerScrollBar then
        SkinNeutralScrollBar(_G.LookingForGuildBrowseFrameContainerScrollBar)
    end
    S:HandleButton(_G.LookingForGuildBrowseButton)
    S:HandleButton(_G.LookingForGuildRequestButton)
    if _G.LookingForGuildCommentInputFrame then
        S:StripTextures(_G.LookingForGuildCommentInputFrame)
        S:ContentShade(_G.LookingForGuildCommentInputFrame)
    end
    for i = 1, 5 do
        local btn = _G["LookingForGuildBrowseFrameContainerButton"..i]
        if btn then InnerBackdrop(btn) end
        btn = _G["LookingForGuildAppsFrameContainerButton"..i]
        if btn then InnerBackdrop(btn) end
    end
    for i = 1, 3 do S:HandleTab(_G["LookingForGuildFrameTab"..i]) end
    if _G.GuildFinderRequestMembershipFrame then
        S:StripTextures(_G.GuildFinderRequestMembershipFrame, true)
        S:CreateBackdrop(_G.GuildFinderRequestMembershipFrame, true)
        S:HandleButton(_G.GuildFinderRequestMembershipFrameAcceptButton)
        S:HandleButton(_G.GuildFinderRequestMembershipFrameCancelButton)
        if _G.GuildFinderRequestMembershipFrameInputFrame then
            S:StripTextures(_G.GuildFinderRequestMembershipFrameInputFrame)
        S:ContentShade(_G.GuildFinderRequestMembershipFrameInputFrame)
        end
    end
end

S.SkinFuncs["Blizzard_LookingForGuildUI"] = SkinLookingForGuild
S.SkinFuncs["Blizzard_GuildUI"] = function()
    SkinGuildInvite()
    SkinGuildRegistrar()
end
S.SkinFuncs["Blizzard_GuildBankUI"]       = SkinGuildBank
S.SkinFuncs["Blizzard_GuildControlUI"]    = SkinGuildControl
S.SkinFuncs["Blizzard_Communities"] = function()
    SkinCommunities()
    SkinGuildInvite()
end

hooksecurefunc(S, "OnEnable", function(self)
    SkinGuildInvite()
    SkinGuildRegistrar()
    if self.RegisterEvent and not self._ktGuildInviteRequestRegistered then
        self:RegisterEvent("GUILD_INVITE_REQUEST", function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, SkinGuildInvite)
            else
                SkinGuildInvite()
            end
        end)
        self._ktGuildInviteRequestRegistered = true
    end
end)
