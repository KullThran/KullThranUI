local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc

local FONT_AVANT = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local BROADCAST_ICON = "|TInterface\\FriendsFrame\\BroadcastIcon:14|t"
local AWAY_ICON = "|TInterface\\FriendsFrame\\StatusIcon-Away:14|t"
local BUSY_ICON = "|TInterface\\FriendsFrame\\StatusIcon-DnD:14|t"
local MOBILE_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat:14|t"
local MOBILE_AWAY_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat-AwayMobile:14|t"
local MOBILE_BUSY_ICON = "|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat-BusyMobile:14|t"
local FRIENDS_TEXT_COLOR = {1, 0.82, 0}

local function GetElementData(button)
    if button.GetElementData then
        local ok, data = pcall(button.GetElementData, button)
        if ok then
            return data
        end
    end

    return button.elementData or button.data
end

local function GetStatusPrefix(button)
    local data = GetElementData(button)
    if not data then
        return ""
    end

    local isMobile = data.isMobile or data.mobile or data.clientProgram == "BSAp" or data.clientProgram == "App"
    local isAFK = data.afk or data.isAFK or data.isBnetAFK
    local isDND = data.dnd or data.isDND or data.isBnetDND
    local hasBroadcast = data.broadcastText or data.customMessage or data.hasBroadcast

    local icons = {}

    if hasBroadcast then
        icons[#icons + 1] = BROADCAST_ICON
    end

    if isMobile then
        if isDND then
            icons[#icons + 1] = MOBILE_BUSY_ICON
        elseif isAFK then
            icons[#icons + 1] = MOBILE_AWAY_ICON
        else
            icons[#icons + 1] = MOBILE_ICON
        end
    elseif isDND then
        icons[#icons + 1] = BUSY_ICON
    elseif isAFK then
        icons[#icons + 1] = AWAY_ICON
    end

    return table.concat(icons, " ")
end

local function UpdateFriendInfoText(button)
    if not button.info then return end

    local infoText = button.info:GetText() or ""
    local previousPrefix = button.ktStatusPrefix
    if previousPrefix and previousPrefix ~= "" and infoText:sub(1, #previousPrefix) == previousPrefix then
        infoText = infoText:sub(#previousPrefix + 1):gsub("^%s+", "")
    end

    local prefix = GetStatusPrefix(button)
    button.ktStatusPrefix = prefix ~= "" and prefix or nil
    button.info:SetText(prefix ~= "" and (prefix.." "..infoText) or infoText)
end

local function SkinFriendButton(button)
    if button.isSkinned then return end

    S:CreateBackdrop(button)
    if button.backdrop then
        button.backdrop:ClearAllPoints()
        button.backdrop:SetPoint("TOPLEFT", 2, -2)
        button.backdrop:SetPoint("BOTTOMRIGHT", -2, 2)
        button.backdrop:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
        button.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
    end

    if button.gameIcon then
        local iconBg = CreateFrame("Frame", nil, button)
        iconBg:SetAllPoints(button.gameIcon)
        S:CreateBackdrop(iconBg)
        if iconBg.backdrop then
            iconBg.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end

        button.gameIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        button.gameIcon:SetParent(iconBg)

        hooksecurefunc(button.gameIcon, "SetShown", function(_, shown) iconBg:SetShown(shown) end)
        hooksecurefunc(button.gameIcon, "Show", function() iconBg:Show() end)
        hooksecurefunc(button.gameIcon, "Hide", function() iconBg:Hide() end)
        iconBg:SetShown(button.gameIcon:IsShown())
    end

    local function SetFont(fs)
        if not fs then return end
        local _, size = fs:GetFont()
        fs:SetFont(FONT_AVANT, size, "OUTLINE")
    end

    SetFont(button.name)
    SetFont(button.info)
    UpdateFriendInfoText(button)

    button.isSkinned = true
end

local function SkinFriends()
    if not (S.db.enable and S.db.friends) then return end

    local FriendsFrame = _G.FriendsFrame
    if not FriendsFrame then return end

    S:HandlePortraitFrame(FriendsFrame)

    if FriendsFrame.TitleContainer and FriendsFrame.TitleContainer.TitleText then
        S:HandleFont(FriendsFrame.TitleContainer.TitleText)
    elseif FriendsFrame.TitleText then
        S:HandleFont(FriendsFrame.TitleText)
    end

    if _G.FriendsTabHeader and _G.FriendsTabHeader.TabSystem then
        for _, tab in ipairs({_G.FriendsTabHeader.TabSystem:GetChildren()}) do
            if tab and tab:IsObjectType("Button") then
                S:HandleTab(tab)
            end
        end
    end

    for i = 1, 4 do
        local tab = _G["FriendsFrameTab"..i]
        if tab then
            S:HandleTab(tab)
            local text = tab.Text or (tab.GetFontString and tab:GetFontString())
            if text then
                S:HandleFont(text)
            end
        end
    end

    if _G.FriendsFrameRecruitAFriendButton then
        local raf = _G.FriendsFrameRecruitAFriendButton
        S:HandleTab(raf)
        if raf.Icon then
            raf.Icon:SetAlpha(1)
            S:HandleIcon(raf.Icon)
            raf.Icon:SetDrawLayer("ARTWORK")
        end
    end

    if _G.FriendsFrameStatusDropDown then
        S:HandleDropDownBox(_G.FriendsFrameStatusDropDown)
    end

    for _, name in pairs({
        "FriendsFrameAddFriendButton",
        "FriendsFrameSendMessageButton",
        "FriendsFrameIgnorePlayerButton",
        "FriendsFrameUnsquelchButton",
    }) do
        local btn = _G[name]
        if btn then
            S:HandleButton(btn)
            local text = btn.Text or (btn.GetFontString and btn:GetFontString())
            if text then
                S:HandleFont(text)
                text:SetTextColor(unpack(FRIENDS_TEXT_COLOR))
            end
        end
    end

    if FriendsFrame.BattlenetFrame then
        local bnet = FriendsFrame.BattlenetFrame
        S:StripTextures(bnet)

        if bnet.BroadcastButton then
            S:HandleButton(bnet.BroadcastButton)
        end

        if bnet.UnavailableInfoFrame then
            S:StripTextures(bnet.UnavailableInfoFrame)
            S:CreateBackdrop(bnet.UnavailableInfoFrame)
        end
    end

    if _G.FriendsListFrame and _G.FriendsListFrame.ScrollBox then
        hooksecurefunc(_G.FriendsListFrame.ScrollBox, "Update", function(self)
            self:ForEachFrame(function(button)
                SkinFriendButton(button)
                UpdateFriendInfoText(button)
            end)
        end)
    end
end

hooksecurefunc(S, "OnEnable", SkinFriends)
