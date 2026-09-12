-- Modules/Chat_Options.lua
-- Registers the "Chat" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local LSM = LibStub("LibSharedMedia-3.0", true)

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local GetFontValues = Opt.GetFontValues
local BeginOptionBlocks = Opt.BeginOptionBlocks
local AddOptionBlock = Opt.AddOptionBlock
local EndOptionBlocks = Opt.EndOptionBlocks

local PREVIEW_BG = "Interface\\Buttons\\WHITE8X8"
local KT_CHAT_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\chaticons\\"
local KT_CHAT_SEND_ICON = KT_CHAT_ICON_PATH .. "Send.png"
local KT_CHAT_SCROLL_TEXTURE = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up"
local PREVIEW_SIDEBAR_ICONS = {
    KT_CHAT_ICON_PATH .. "FriendList.png",
    KT_CHAT_ICON_PATH .. "VoiceChat.png",
    KT_CHAT_ICON_PATH .. "QuickChat.png",
    KT_CHAT_ICON_PATH .. "Search.png",
    KT_CHAT_ICON_PATH .. "CopyChat.png",
    KT_CHAT_ICON_PATH .. "Confrig.png",
    KT_CHAT_ICON_PATH .. "trash.png",
}
local PREVIEW_MESSAGES = {
    { chatType = "GUILD", label = "Guild", author = "Silvermage", class = "MAGE", text = "Portal ready in Stormwind after this key." },
    { chatType = "PARTY", label = "Party", author = "Leafsong", class = "DRUID", text = "Rebuffing and topping everyone now." },
    { chatType = "WHISPER", label = "Whisper", author = "Trumpsta", class = "ROGUE", text = "que pasa" },
    { chatType = "INSTANCE_CHAT", label = "Instance", author = "Forastero", class = "WARRIOR", text = "oda" },
    { chatType = "CHANNEL", label = "2. Trade - City", author = "Nikalmaj", text = "Busco craft |cffa335ee[Reprimenda de rompechizos]|r" },
    { chatType = "SYSTEM", text = "Total time played: 290 days, 18 hours, 56 minutes, 31 seconds" },
    { chatType = "SYSTEM", text = "You receive loot: |cff1eff00[Polished Ruby]|r" },
    { chatType = "BN_WHISPER", label = "Whisper", author = "BattleFriend", text = "Let's queue after this?" },
}

local previewRefresh = function() end

local function GetChatModule()
    return KT:GetModule("Chat", true)
end

local function RefreshChat()
    local M = GetChatModule()
    if M and M.Refresh then
        M:Refresh()
    end
    previewRefresh()
end

local function RestoreChatDefaults()
    if not (KT and KT.db and KT.db.profile) then
        return
    end

    KT.db.profile.chat = nil
    RefreshChat()

    if KT.RefreshPage then
        KT:RefreshPage()
    end
end

local function FetchPreviewFont(fontKey)
    local fontPath = fontKey
    if LSM and fontKey then
        local fetched = LSM:Fetch("font", fontKey)
        if fetched then
            fontPath = fetched
        end
    end

    if type(fontPath) ~= "string" or not fontPath:find("\\", 1, true) then
        return KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
    end

    return fontPath
end

local function GetClassColor(classTag)
    local classColors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {}
    local color = classTag and classColors[classTag]
    if color then
        return color.r or 1, color.g or 1, color.b or 1
    end
    return 0.95, 0.95, 0.98
end

local function GetChatTypeColor(chatType)
    local key = tostring(chatType or "")
    if key == "WHISPER" or key == "BN_WHISPER" then
        key = "WHISPER"
    elseif key == "INSTANCE_CHAT" then
        key = "INSTANCE_CHAT"
    elseif key == "CHANNEL" then
        key = "CHANNEL"
    elseif key == "SYSTEM" then
        key = "SYSTEM"
    end

    local info = ChatTypeInfo[key] or {}
    return info.r or 0.95, info.g or 0.95, info.b or 0.98
end

local function GetPreviewTabs(db)
    local M = GetChatModule()
    if M and M.BuildConfiguredTabs then
        local built = M:BuildConfiguredTabs()
        if type(built) == "table" and #built > 0 then
            return built
        end
    end

    local tabs = {}
    for index, config in ipairs(db.tabConfigs or {}) do
        if config.hidden ~= true and strtrim(tostring(config.label or "")) ~= "" then
            tabs[#tabs + 1] = {
                id = config.id or ("slot" .. index),
                label = config.label,
                prompt = config.prompt,
                filterMode = config.filterMode,
                channelMatch = config.channelMatch,
            }
        end
    end
    return tabs
end

local function GetPreviewTabColor(tabInfo)
    local M = GetChatModule()
    if M and M.GetTabTextColor then
        return M:GetTabTextColor((tabInfo and tabInfo.filterMode) or (tabInfo and tabInfo.id))
    end
    return 0.9, 0.9, 0.95
end

local function GetPreferredPreviewTabIndex(tabs)
    for index, tabInfo in ipairs(tabs) do
        local mode = strupper(tostring(tabInfo.filterMode or tabInfo.id or ""))
        if mode == "GENERAL" then
            return index
        end
    end
    return 1
end

local function MessageMatchesPreviewTab(messageInfo, tabInfo)
    if not tabInfo then
        return true
    end

    local mode = strupper(tostring(tabInfo.filterMode or tabInfo.id or "GENERAL"))
    local chatType = strupper(tostring(messageInfo.chatType or "SYSTEM"))

    if mode == "GENERAL" then
        return chatType ~= "COMBAT"
    elseif mode == "COMBAT" then
        return chatType == "COMBAT"
    elseif mode == "GUILD" then
        return chatType == "GUILD" or chatType == "OFFICER"
    elseif mode == "GROUP" then
        return chatType == "PARTY" or chatType == "PARTY_LEADER" or chatType == "RAID" or chatType == "RAID_LEADER" or chatType == "INSTANCE_CHAT" or chatType == "INSTANCE_CHAT_LEADER"
    elseif mode == "WHISPER" then
        return chatType == "WHISPER" or chatType == "BN_WHISPER" or chatType == "WHISPER_INFORM" or chatType == "BN_WHISPER_INFORM"
    elseif mode == "CHANNEL" or mode == "TRADE" then
        return chatType == "CHANNEL"
    elseif mode == "SYSTEM" then
        return chatType == "SYSTEM"
    end

    return true
end

local function BuildPreviewMessages(activeTab)
    local filtered = {}
    for _, info in ipairs(PREVIEW_MESSAGES) do
        if MessageMatchesPreviewTab(info, activeTab) then
            filtered[#filtered + 1] = info
        end
    end
    if #filtered == 0 then
        return PREVIEW_MESSAGES
    end
    return filtered
end

local function FormatPreviewAuthor(info, db)
    local author = tostring(info.author or "")
    if author == "" then
        return ""
    end
    if db.classColorNames == false or not info.class then
        return author
    end

    local r, g, b = GetClassColor(info.class)
    return string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), author)
end

local function FormatPreviewLine(info, db)
    if info.chatType == "SYSTEM" then
        return string.format("|cff%02x%02x%02x%s|r", 255, 224, 72, tostring(info.text or ""))
    end

    local r, g, b = GetChatTypeColor(info.chatType)
    local prefix = string.format("|cff%02x%02x%02x(%s)|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), tostring(info.label or info.chatType or "Chat"))
    local author = FormatPreviewAuthor(info, db)

    if info.chatType == "CHANNEL" then
        return string.format("%s (%s): %s", prefix, author ~= "" and author or "Player", tostring(info.text or ""))
    end

    if author ~= "" then
        return string.format("%s %s: %s", prefix, author, tostring(info.text or ""))
    end

    return string.format("%s %s", prefix, tostring(info.text or ""))
end

local function SetPreviewBackdropColor(frame, r, g, b, a)
    if frame and frame.bgKT then
        frame.bgKT:SetColorTexture(r or 0, g or 0, b or 0, a or 0)
    end
end

local function SetPreviewBorderColor(frame, r, g, b, a)
    if not (frame and frame.borderKT) then
        return
    end

    for _, edge in ipairs(frame.borderKT) do
        edge:SetVertexColor(r or 0, g or 0, b or 0, a or 0)
    end
end

KT:RegisterPage("chat", "Chat", 72, function(sc, W)
    local y, h = 0, 0
    local db = KT.db and KT.db.profile and KT.db.profile.chat
    if not db then
        KT.db.profile.chat = KT.db.profile.chat or {}
        db = KT.db.profile.chat
    end

    db.window = db.window or {}
    db.tabConfigs = db.tabConfigs or {}

    local prevContainer = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    prevContainer:SetSize((sc:GetWidth() or 1) - 20, 250)
    prevContainer:SetPoint("TOP", sc, "TOP", 0, -10)
    prevContainer:SetClipsChildren(true)
    if KT.AddBackdrop then
        KT:AddBackdrop(prevContainer, 0.05, 0.05, 0.05, 0.35)
    end
    if KT.AddBorder then
        KT:AddBorder(prevContainer, 0, 0, 0, 1)
    end
    if KT.AttachStickyPreview then
        KT:AttachStickyPreview(prevContainer, { point = "TOP", relativePoint = "TOP", x = 0, y = -10 })
    end
    SetPreviewBackdropColor(prevContainer, 0.03, 0.03, 0.03, 0.28)

    local lblPrev = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPrev:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 8, -6)
    lblPrev:SetText(LText("LIVE PREVIEW"))
    KT:SetAccentTextColor(lblPrev, 1)

    local subLabel = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    subLabel:SetPoint("TOPRIGHT", prevContainer, "TOPRIGHT", -10, -6)
    subLabel:SetJustifyH("RIGHT")
    subLabel:SetTextColor(0.72, 0.72, 0.78, 0.9)
    subLabel:SetText(LText("Mirrors KUI chrome and Blizzard live chat font settings"))

    local previewHost = CreateFrame("Frame", nil, prevContainer)
    previewHost:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 18, -26)
    previewHost:SetPoint("BOTTOMRIGHT", prevContainer, "BOTTOMRIGHT", -18, 18)

    local previewWindow = CreateFrame("Frame", nil, previewHost, "BackdropTemplate")
    previewWindow:SetPoint("CENTER", previewHost, "CENTER", 18, 2)
    if KT.AddBackdrop then
        KT:AddBackdrop(previewWindow, 0.05, 0.07, 0.09, 0.22)
    end
    if KT.AddBorder then
        KT:AddBorder(previewWindow, 0, 0, 0, 0)
    end

    local glassTop = previewWindow:CreateTexture(nil, "ARTWORK", nil, -1)
    glassTop:SetPoint("TOPLEFT", 1, -1)
    glassTop:SetPoint("TOPRIGHT", -1, -1)

    local leftShade = previewWindow:CreateTexture(nil, "ARTWORK", nil, -1)
    leftShade:SetPoint("TOPLEFT", 1, -1)
    leftShade:SetPoint("BOTTOMLEFT", 1, 1)

    local glassBottom = previewWindow:CreateTexture(nil, "ARTWORK", nil, -1)
    glassBottom:SetPoint("BOTTOMLEFT", 1, 1)
    glassBottom:SetPoint("BOTTOMRIGHT", -1, 1)

    local tabsHolder = CreateFrame("Frame", nil, previewWindow)
    tabsHolder:SetPoint("BOTTOMLEFT", previewWindow, "TOPLEFT", 2, -2)
    tabsHolder:SetPoint("BOTTOMRIGHT", previewWindow, "TOPRIGHT", -4, -2)
    tabsHolder:SetHeight(34)

    local contentArea = CreateFrame("Frame", nil, previewWindow, "BackdropTemplate")
    contentArea:SetPoint("TOPLEFT", previewWindow, "TOPLEFT", 0, 0)
    contentArea:SetPoint("BOTTOMRIGHT", previewWindow, "BOTTOMRIGHT", 0, 0)
    if KT.AddBackdrop then
        KT:AddBackdrop(contentArea, 0, 0, 0, 0)
    end
    if KT.AddBorder then
        KT:AddBorder(contentArea, 0, 0, 0, 0)
    end

    local backdropFade = contentArea:CreateTexture(nil, "BACKGROUND")
    backdropFade:SetAllPoints()

    local contentTopGlow = contentArea:CreateTexture(nil, "ARTWORK")
    contentTopGlow:SetPoint("TOPLEFT", 0, 0)
    contentTopGlow:SetPoint("TOPRIGHT", 0, 0)
    contentTopGlow:SetHeight(38)

    local contentBottomShade = contentArea:CreateTexture(nil, "BORDER")
    contentBottomShade:SetPoint("BOTTOMLEFT", 0, 0)
    contentBottomShade:SetPoint("BOTTOMRIGHT", 0, 0)
    contentBottomShade:SetHeight(72)

    local messageArea = CreateFrame("Frame", nil, contentArea)
    messageArea:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 14, -12)
    messageArea:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -16, 42)

    local sideBar = CreateFrame("Frame", nil, previewWindow)
    sideBar:SetPoint("TOPRIGHT", previewWindow, "TOPLEFT", 2, -2)
    sideBar:SetPoint("BOTTOMRIGHT", previewWindow, "BOTTOMLEFT", 2, 2)
    sideBar:SetWidth(32)

    local footer = CreateFrame("Frame", nil, previewWindow, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", previewWindow, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", previewWindow, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(40)
    if KT.AddBackdrop then
        KT:AddBackdrop(footer, 0, 0, 0, 0)
    end
    if KT.AddBorder then
        KT:AddBorder(footer, 0, 0, 0, 0)
    end

    local footerGlow = footer:CreateTexture(nil, "ARTWORK")
    footerGlow:SetPoint("TOPLEFT", 0, 0)
    footerGlow:SetPoint("TOPRIGHT", 0, 0)
    footerGlow:SetHeight(24)

    local inputBar = CreateFrame("Frame", nil, footer, "BackdropTemplate")
    inputBar:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, -2)
    inputBar:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -58, 0)
    if KT.AddBackdrop then
        KT:AddBackdrop(inputBar, 0, 0, 0, 0)
    end
    if KT.AddBorder then
        KT:AddBorder(inputBar, 0, 0, 0, 0)
    end

    local inputGlow = inputBar:CreateTexture(nil, "ARTWORK")
    inputGlow:SetPoint("TOPLEFT", 0, 0)
    inputGlow:SetPoint("TOPRIGHT", 0, 0)
    inputGlow:SetHeight(18)

    local inputPrompt = inputBar:CreateFontString(nil, "OVERLAY")
    inputPrompt:SetPoint("LEFT", inputBar, "LEFT", 8, 0)
    inputPrompt:SetJustifyH("LEFT")
    inputPrompt:SetTextColor(0.72, 0.72, 0.78, 0.9)

    local sendButton = CreateFrame("Frame", nil, footer, "BackdropTemplate")
    sendButton:SetPoint("RIGHT", footer, "RIGHT", -4, -1)
    sendButton:SetSize(42, 30)
    if KT.AddBackdrop then
        KT:AddBackdrop(sendButton, 0, 0, 0, 0)
    end
    if KT.AddBorder then
        KT:AddBorder(sendButton, 0, 0, 0, 0)
    end
    sendButton.icon = sendButton:CreateTexture(nil, "ARTWORK")
    sendButton.icon:SetTexture(KT_CHAT_SEND_ICON)
    sendButton.icon:SetSize(18, 18)
    sendButton.icon:SetPoint("CENTER")

    local scrollButton = CreateFrame("Frame", nil, contentArea, "BackdropTemplate")
    scrollButton:SetSize(26, 26)
    scrollButton:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", -8, 48)
    if KT.AddBackdrop then
        KT:AddBackdrop(scrollButton, 0, 0, 0, 0)
    end
    if KT.AddBorder then
        KT:AddBorder(scrollButton, 0, 0, 0, 0)
    end
    scrollButton.icon = scrollButton:CreateTexture(nil, "ARTWORK")
    scrollButton.icon:SetTexture(KT_CHAT_SCROLL_TEXTURE)
    scrollButton.icon:SetSize(14, 14)
    scrollButton.icon:SetPoint("CENTER")

    local hintText = previewWindow:CreateFontString(nil, "OVERLAY")
    hintText:SetPoint("BOTTOMRIGHT", previewWindow, "BOTTOMRIGHT", -12, 38)
    hintText:SetJustifyH("RIGHT")
    hintText:SetTextColor(0.74, 0.74, 0.8, 0.9)

    local previewButtons = {}
    local function CreateSideButton(texturePath, yOffset)
        local btn = CreateFrame("Frame", nil, sideBar, "BackdropTemplate")
        btn:SetSize(32, 32)
        btn:SetPoint("TOPRIGHT", sideBar, "TOPRIGHT", 0, yOffset)
        if KT.AddBackdrop then
            KT:AddBackdrop(btn, 0, 0, 0, 0)
        end
        if KT.AddBorder then
            KT:AddBorder(btn, 0, 0, 0, 0)
        end

        btn.shadow = btn:CreateTexture(nil, "BACKGROUND")
        btn.shadow:SetPoint("TOPLEFT", 3, -3)
        btn.shadow:SetPoint("BOTTOMRIGHT", -1, 1)
        btn.shadow:SetColorTexture(0, 0, 0, 0.35)

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetTexture(texturePath)
        btn.icon:SetPoint("CENTER")
        btn.icon:SetSize(18, 18)
        return btn
    end

    for index, texturePath in ipairs(PREVIEW_SIDEBAR_ICONS) do
        previewButtons[index] = CreateSideButton(texturePath, -((index - 1) * 38))
    end

    local tabs = {}
    local function EnsurePreviewTab(index)
        if tabs[index] then
            return tabs[index]
        end

        local tab = CreateFrame("Frame", nil, tabsHolder, "BackdropTemplate")
        tab:SetHeight(22)
        if KT.AddBackdrop then
            KT:AddBackdrop(tab, 0, 0, 0, 0)
        end
        if KT.AddBorder then
            KT:AddBorder(tab, 0, 0, 0, 0)
        end
        tab.gloss = tab:CreateTexture(nil, "ARTWORK")
        tab.gloss:SetPoint("TOPLEFT", 1, -1)
        tab.gloss:SetPoint("TOPRIGHT", -1, -1)
        tab.gloss:SetHeight(14)
        tab.text = tab:CreateFontString(nil, "OVERLAY")
        tab.text:SetPoint("LEFT", tab, "LEFT", 8, 0)
        tab.text:SetPoint("RIGHT", tab, "RIGHT", -8, 0)
        tab.text:SetJustifyH("CENTER")
        tab.text:SetJustifyV("MIDDLE")
        if tab.text.SetWordWrap then tab.text:SetWordWrap(false) end
        if tab.text.SetNonSpaceWrap then tab.text:SetNonSpaceWrap(false) end
        tabs[index] = tab
        return tab
    end

    local messageLines = {}
    for index = 1, 8 do
        local line = messageArea:CreateFontString(nil, "OVERLAY")
        line:SetJustifyH("LEFT")
        line:SetPoint("TOPLEFT", messageArea, "TOPLEFT", 0, -((index - 1) * 24))
        line:SetPoint("RIGHT", messageArea, "RIGHT", 0, 0)
        messageLines[index] = line
    end

    local function UpdatePreview()
        local fontPath = FetchPreviewFont(db.font or "AAA_ITC_Avant_Garde")
        local fontSize = db.fontSize or 12
        local fontOutline = db.fontOutline or "OUTLINE"
        local panelColor = db.panelColor or { r = 0.04, g = 0.06, b = 0.08, a = 0.18 }
        local width = math.max(300, db.window.width or 500)
        local height = math.max(150, db.window.height or 280)
        local fitWidth = math.max(280, (previewHost:GetWidth() or 560) - 36)
        local fitHeight = math.max(150, (previewHost:GetHeight() or 190) - 18)
        local scale = math.min(fitWidth / width, fitHeight / height, 1)
        local tabsData = GetPreviewTabs(db)
        local activeTabIndex = GetPreferredPreviewTabIndex(tabsData)
        local activeTab = tabsData[activeTabIndex]
        local previewMessages = BuildPreviewMessages(activeTab)
        local hint = (db.fadeEnabled ~= false) and string.format(LText("Window fade: %.0fs + %.0fs"), db.fadeTimeVisible or 24, db.fadeDuration or 8) or LText("Window fade: Off")

        previewWindow:ClearAllPoints()
        previewWindow:SetPoint("CENTER", previewHost, "CENTER", 18, 2)
        previewWindow:SetScale(scale)
        previewWindow:SetSize(width, height)

        SetPreviewBackdropColor(previewWindow, panelColor.r or 0.04, panelColor.g or 0.06, panelColor.b or 0.08, panelColor.a or 0.18)
        SetPreviewBorderColor(previewWindow, 0, 0, 0, 0)
        SetPreviewBackdropColor(contentArea, (panelColor.r or 0.04) * 0.36, (panelColor.g or 0.06) * 0.36, (panelColor.b or 0.08) * 0.36, panelColor.a or 0.18)
        SetPreviewBackdropColor(footer, (panelColor.r or 0.04) * 0.34, (panelColor.g or 0.06) * 0.34, (panelColor.b or 0.08) * 0.34, panelColor.a or 0.18)
        SetPreviewBackdropColor(inputBar, (panelColor.r or 0.04) * 0.52, (panelColor.g or 0.06) * 0.52, (panelColor.b or 0.08) * 0.52, panelColor.a or 0.18)
        SetPreviewBackdropColor(scrollButton, (panelColor.r or 0.04) * 0.5, (panelColor.g or 0.06) * 0.5, (panelColor.b or 0.08) * 0.5, (panelColor.a or 0.18) * 0.12)
        SetPreviewBackdropColor(sendButton, 1, 1, 1, panelColor.a or 0.18)

        leftShade:SetWidth(math.floor(width * 0.22))
        glassTop:SetHeight(math.floor(height * 0.45))
        glassBottom:SetHeight(math.floor(height * 0.42))

        if backdropFade.SetGradientAlpha then
            backdropFade:SetTexture(PREVIEW_BG)
            backdropFade:SetGradientAlpha("VERTICAL", panelColor.r or 0.04, panelColor.g or 0.06, panelColor.b or 0.08, (panelColor.a or 0.18) * 0.18, panelColor.r or 0.04, panelColor.g or 0.06, panelColor.b or 0.08, (panelColor.a or 0.18) * 0.02)
            contentTopGlow:SetTexture(PREVIEW_BG)
            contentTopGlow:SetGradientAlpha("VERTICAL", 1, 1, 1, (panelColor.a or 0.18) * 0.08, 1, 1, 1, 0)
            contentBottomShade:SetTexture(PREVIEW_BG)
            contentBottomShade:SetGradientAlpha("VERTICAL", 0, 0, 0, 0, 0, 0, 0, (panelColor.a or 0.18) * 0.16)
            footerGlow:SetTexture(PREVIEW_BG)
            footerGlow:SetGradientAlpha("VERTICAL", 1, 1, 1, (panelColor.a or 0.18) * 0.06, 1, 1, 1, 0.01)
            inputGlow:SetTexture(PREVIEW_BG)
            inputGlow:SetGradientAlpha("VERTICAL", 1, 1, 1, (panelColor.a or 0.18) * 0.05, 1, 1, 1, 0)
            glassTop:SetTexture(PREVIEW_BG)
            glassTop:SetGradientAlpha("VERTICAL", 1, 1, 1, (panelColor.a or 0.18) * 0.09, 1, 1, 1, (panelColor.a or 0.18) * 0.01)
            glassBottom:SetTexture(PREVIEW_BG)
            glassBottom:SetGradientAlpha("VERTICAL", 0, 0, 0, (panelColor.a or 0.18) * 0.02, 0, 0, 0, (panelColor.a or 0.18) * 0.18)
            leftShade:SetTexture(PREVIEW_BG)
            leftShade:SetGradientAlpha("HORIZONTAL", 0, 0, 0, (panelColor.a or 0.18) * 0.16, 0, 0, 0, 0)
        else
            backdropFade:SetColorTexture(panelColor.r or 0.04, panelColor.g or 0.06, panelColor.b or 0.08, (panelColor.a or 0.18) * 0.12)
            contentTopGlow:SetColorTexture(1, 1, 1, 0.04)
            contentBottomShade:SetColorTexture(0, 0, 0, 0.06)
            footerGlow:SetColorTexture(1, 1, 1, 0.03)
            inputGlow:SetColorTexture(1, 1, 1, 0.03)
            glassTop:SetColorTexture(1, 1, 1, 0.04)
            glassBottom:SetColorTexture(0, 0, 0, 0.08)
            leftShade:SetColorTexture(0, 0, 0, 0.06)
        end

        inputPrompt:SetFont(fontPath, math.max(fontSize - 1, 10), fontOutline)
        inputPrompt:SetText(string.format("%s:", tostring((activeTab and activeTab.prompt) or LText("Say"))))
        hintText:SetFont(fontPath, math.max(fontSize - 3, 9), fontOutline)
        hintText:SetText(hint)

        local tabCount = math.min(#tabsData, 6)
        local spacing = 3
        local holderWidth = math.max(0, tabsHolder:GetWidth() or 0)
        local padding = 28
        local widths = {}
        local totalIdeal = 0
        for index = 1, tabCount do
            local tabInfo = tabsData[index]
            local tab = EnsurePreviewTab(index)
            tab.text:SetFont(fontPath, math.max(fontSize - 2, 10), fontOutline)
            tab.text:SetText(tostring(tabInfo.label or "Tab"))
            widths[index] = math.max(74, (tab.text:GetStringWidth() or 0) + padding)
            totalIdeal = totalIdeal + widths[index]
        end
        local available = holderWidth - (spacing * math.max(tabCount - 1, 0))
        local compressedWidth = (tabCount > 0 and totalIdeal > available and available > 0) and math.max(10, math.floor(available / tabCount)) or nil

        local previousTab = nil
        for index = 1, tabCount do
            local tabInfo = tabsData[index]
            local tab = EnsurePreviewTab(index)
            local tabWidth = compressedWidth or widths[index] or 78
            tab:ClearAllPoints()
            if previousTab then
                tab:SetPoint("LEFT", previousTab, "RIGHT", spacing, 0)
            else
                tab:SetPoint("BOTTOMLEFT", tabsHolder, "BOTTOMLEFT", 10, 0)
            end
            tab:SetWidth(tabWidth)
            tab:Show()

            local isActive = index == activeTabIndex
            local textR, textG, textB = GetPreviewTabColor(tabInfo)
            if isActive then
                SetPreviewBackdropColor(tab, (panelColor.r or 0.04) * 0.32, (panelColor.g or 0.06) * 0.32, (panelColor.b or 0.08) * 0.32, 0.108)
                tab.text:SetTextColor(textR, textG, textB, 1)
                if tab.gloss.SetGradientAlpha then
                    tab.gloss:SetTexture(PREVIEW_BG)
                    tab.gloss:SetGradientAlpha("VERTICAL", 1, 1, 1, 0.03, 1, 1, 1, 0)
                else
                    tab.gloss:SetColorTexture(1, 1, 1, 0.03)
                end
            else
                SetPreviewBackdropColor(tab, (panelColor.r or 0.04) * 0.25, (panelColor.g or 0.06) * 0.25, (panelColor.b or 0.08) * 0.25, 0.05)
                tab.text:SetTextColor(textR, textG, textB, 0.92)
                if tab.gloss.SetGradientAlpha then
                    tab.gloss:SetTexture(PREVIEW_BG)
                    tab.gloss:SetGradientAlpha("VERTICAL", 1, 1, 1, 0.015, 1, 1, 1, 0)
                else
                    tab.gloss:SetColorTexture(1, 1, 1, 0.015)
                end
            end
            SetPreviewBorderColor(tab, 0, 0, 0, 0)
            previousTab = tab
        end
        for index = tabCount + 1, #tabs do
            tabs[index]:Hide()
        end

        for _, btn in ipairs(previewButtons) do
            SetPreviewBackdropColor(btn, 0, 0, 0, 0)
            SetPreviewBorderColor(btn, 0, 0, 0, 0)
        end

        for index, line in ipairs(messageLines) do
            local info = previewMessages[index]
            line:SetFont(fontPath, fontSize, fontOutline)
            if info then
                line:SetText(FormatPreviewLine(info, db))
                line:Show()
            else
                line:SetText("")
                line:Hide()
            end
        end
    end

    previewRefresh = UpdatePreview
    UpdatePreview()
    y = y + (prevContainer:GetHeight() or 250) + 20

    _, h = W:Button(sc, LText("Open Blizzard Chat Settings"), -y, function()
        local M = GetChatModule()
        if M and M.OpenBlizzardSettings then
            M:OpenBlizzardSettings()
        else
            RefreshChat()
        end
    end)
    y = y + h + 6

    _, h = W:Button(sc, LText("Restore Chat Defaults"), -y, function()
        RestoreChatDefaults()
    end)
    y = y + h + 10

    if not (BeginOptionBlocks and AddOptionBlock and EndOptionBlocks) then
        return y
    end

    local cols = BeginOptionBlocks(sc, y + 10)

    AddOptionBlock(cols, "left", "General", function(container)
        local by = 0
        _, h = W:Toggle(container, "Enable Module", -by,
            function() return db.enable ~= false end,
            function(v) db.enable = v; Reload() end); by = by + h
        _, h = W:Slider(container, "Max Lines", -by,
            function() return db.maxLines or 500 end,
            function(v) db.maxLines = v; RefreshChat() end, 100, 5000, 10); by = by + h
        _, h = W:Toggle(container, "Class Color Names", -by,
            function() return db.classColorNames ~= false end,
            function(v) db.classColorNames = v; RefreshChat() end); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", "Typography", function(container)
        local by = 0
        _, h = W:Dropdown(container, "Font", -by, GetFontValues,
            function() return db.font or "AAA_ITC_Avant_Garde" end,
            function(v) db.font = v; RefreshChat() end); by = by + h
        _, h = W:Slider(container, "Font Size", -by,
            function() return db.fontSize or 12 end,
            function(v) db.fontSize = v; RefreshChat() end, 8, 24, 1); by = by + h
        _, h = W:Dropdown(container, "Outline", -by,
            { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
            function() return db.fontOutline or "OUTLINE" end,
            function(v) db.fontOutline = v; RefreshChat() end); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "Window Fade", function(container)
        local by = 0
        _, h = W:Toggle(container, "Auto Fade Window", -by,
            function() return db.fadeEnabled ~= false end,
            function(v) db.fadeEnabled = v; RefreshChat() end); by = by + h
        _, h = W:Slider(container, "Visible Delay", -by,
            function() return db.fadeTimeVisible or 24 end,
            function(v) db.fadeTimeVisible = v; RefreshChat() end, 1, 120, 1); by = by + h
        _, h = W:Slider(container, "Fade Duration", -by,
            function() return db.fadeDuration or 8 end,
            function(v) db.fadeDuration = v; RefreshChat() end, 1, 60, 1); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "Colors", function(container)
        local by = 0
        _, h = W:ColorSwatch(container, "Panel Color", -by,
            function()
                local c = db.panelColor or { r = 0.05, g = 0.07, b = 0.09, a = 0.18 }
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a) db.panelColor = { r = r, g = g, b = b, a = a }; RefreshChat() end, true); by = by + h
        _, h = W:ColorSwatch(container, "Highlight Color", -by,
            function()
                local c = db.highlightColor or { r = KT.C_R, g = KT.C_G, b = KT.C_B }
                return c.r, c.g, c.b
            end,
            function(r, g, b) db.highlightColor = { r = r, g = g, b = b }; RefreshChat() end, false); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", "Window", function(container)
        local by = 0
        _, h = W:Slider(container, "Width", -by,
            function() return db.window.width or 500 end,
            function(v) db.window.width = v; RefreshChat() end, 300, 1200, 1); by = by + h
        _, h = W:Slider(container, "Height", -by,
            function() return db.window.height or 280 end,
            function(v) db.window.height = v; RefreshChat() end, 150, 800, 1); by = by + h
        return by
    end)

    return EndOptionBlocks(cols)
end)
