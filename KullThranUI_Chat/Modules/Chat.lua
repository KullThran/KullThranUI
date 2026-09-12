-- Chat.lua
-- Purpose: Provide KullThranUI's native chat module, own the chat window and
-- message history, and mirror that history into the external chat bridge
-- while that compatibility adapter remains in use.
-- Dependencies: external chat bridge public API only, loaded after ADDON_LOADED.
-- Minimum compatible version: 195.

local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local LSM = LibStub("LibSharedMedia-3.0", true)
local Mod = KT:NewModule("Chat", "AceEvent-3.0")

local KT_MODULE_NAME = "KullThranUI"
local KT_CHATTYNATOR_NAME = "Chattynator"
local KT_CHATTYNATOR_MIN_VERSION = 195
local KT_CHAT_TAB_LABEL = "KullThran Chat"
local KT_CHAT_TAB_ID = "kullthran_main"
local KT_CHAT_HISTORY_LINES = 500
local KT_CHAT_WINDOW_WIDTH = 500
local KT_CHAT_WINDOW_HEIGHT = 280
local KT_CHAT_WINDOW_MIN_WIDTH = 270
local KT_CHAT_WINDOW_MIN_HEIGHT = 165
local KT_CHAT_WINDOW_DEFAULT_X = 54
local KT_CHAT_WINDOW_DEFAULT_Y = 45
local KT_CHAT_DB_KEY = "kullthran_chat_window"
local KT_CHAT_POSITION_DEBUG_MAX = 80
local KT_BRAND_COLOR = { r = KT.C_R or 1, g = KT.C_G or 0, b = KT.C_B or 0.333 }
local KT_DEFAULT_FONT = KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
local KT_DEFAULT_FONT_NAME = "AAA_ITC_Avant_Garde"
local KT_CHAT_SCROLL_TEXTURE = "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up"
local KT_CHAT_DEFAULT_PANEL_COLOR = { r = 0.04, g = 0.06, b = 0.08, a = 0.1 }
local KT_CHAT_DEFAULT_HIGHLIGHT_COLOR = { r = KT.C_R or 1, g = KT.C_G or 0, b = KT.C_B or 0.333 }
local KT_CHAT_DEFAULT_TAB_HIGHLIGHT_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\title_background_png.tga"
local KT_CHAT_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\chaticons\\"
local KT_CHAT_SEND_ICON = KT_CHAT_ICON_PATH .. "Send.png"
local KT_BNET_PLACEHOLDER = "Battle.net"
local KT_LText
local KT_SetTooltip
local KT_ResolveBNetWhisperTarget
local KT_ResolveBNetAccountIDLoose
local KT_ColorizePlayerName
local KT_CHAT_GRADIENT_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local KT_CHAT_HIDDEN_PARENT
local KT_CHAT_HIDE_REGEN_FRAME
local KT_CHAT_HIDE_QUEUED
local KT_COPY_DIALOG_NAME = "KT_ChatCopyDialog"
local KT_COPY_POPUP_KEY = "KT_CHAT_COPY"
local KT_SEARCH_POPUP_KEY = "KT_CHAT_SEARCH"
local KT_NATIVE_CHAT_WINDOW_NAMES = {
    trade = "KUI Trade",
    guild = "KUI Guild",
    group = "KUI Group",
    whisper = "KUI Whisper",
}

local KT_NATIVE_CHAT_WINDOW_IDS = {
    trade = 3,
    guild = 4,
    group = 5,
    whisper = 6,
}

local KT_NATIVE_CHAT_MESSAGE_GROUPS = {
    trade = { "CHANNEL" },
    guild = { "GUILD", "OFFICER" },
    group = { "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER" },
    whisper = { "WHISPER", "BN_WHISPER" },
}

local CHAT_EVENTS = {
    "CHAT_MSG_SYSTEM",
    "CHAT_MSG_SAY",
    "CHAT_MSG_YELL",
    "CHAT_MSG_EMOTE",
    "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_RAID_WARNING",
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_WHISPER_INFORM",
    "CHAT_MSG_BN_WHISPER",
    "CHAT_MSG_BN_WHISPER_INFORM",
    "CHAT_MSG_CHANNEL",
    "CHAT_MSG_COMMUNITIES_CHANNEL",
    "CHAT_MSG_LOOT",
    "CHAT_MSG_MONEY",
    "CHAT_MSG_CURRENCY",
}

local CHAT_EVENT_LOOKUP = {}
for i = 1, #CHAT_EVENTS do
    CHAT_EVENT_LOOKUP[CHAT_EVENTS[i]] = true
end

local CHAT_LABELS = {
    SYSTEM = "System",
    SAY = "Say",
    YELL = "Yell",
    EMOTE = "Emote",
    GUILD = "Guild",
    OFFICER = "Officer",
    PARTY = "Party",
    PARTY_LEADER = "Party",
    RAID = "Raid",
    RAID_LEADER = "Raid",
    RAID_WARNING = "Warning",
    INSTANCE_CHAT = "Instance",
    INSTANCE_CHAT_LEADER = "Instance",
    WHISPER = "Whisper",
    WHISPER_INFORM = "To",
    BN_WHISPER = "Whisper",
    BN_WHISPER_INFORM = "To",
    CHANNEL = "Channel",
    COMMUNITIES_CHANNEL = "Community",
    LOOT = "Loot",
    MONEY = "Money",
    CURRENCY = "Currency",
    ADDON = "Addon",
}

local COPY_SUBSTITUTIONS = {
    { "%f[|]|K.-%f[|]|k", "???" },
    { "%f[|]|W.-%f[|]|w", "???" },
    { "%f[|]|T.-%f[|]|t", "???" },
    { "%f[|]|A:Professions%-ChatIcon%-Quality%-Tier(%d):.-%f[|]|a", "%1*" },
    { "%f[|]|A.-%f[|]|a", "???" },
    { "%f[|]|H.-%f[|]|h(.-)%f[|]|h", "%1" },
}

local tinsert = table.insert
local tremove = table.remove
local wipe = wipe
local format = string.format
local strtrim = strtrim
local strfind = string.find
local strlower = string.lower
local strupper = string.upper
local securecallfunction = securecallfunction
local issecretvalue = issecretvalue or function()
    return false
end
local hasanysecretvalues = hasanysecretvalues or function()
    return false
end
local canaccessvalue = canaccessvalue or function(value)
    return value ~= nil
end
local canaccessallvalues = canaccessallvalues or function()
    return true
end
local scrubsecretvalues = scrubsecretvalues or function(...)
    return ...
end
local KT_SECRET_PLACEHOLDER = "<secret>"

local function KT_IsSecureChatSafeMode()
    if type(_G.issecretvalue) == "function"
        or type(_G.hasanysecretvalues) == "function"
        or type(_G.canaccessvalue) == "function"
        or type(_G.canaccessallvalues) == "function" then
        return true
    end

    local _, _, _, interfaceVersion = _G.GetBuildInfo and _G.GetBuildInfo()
    interfaceVersion = tonumber(interfaceVersion) or 0
    return interfaceVersion >= 110200
end

local function KT_UpdateChatEditHeader(editBox)
    if not editBox then return false end
    if KT_IsSecureChatSafeMode()
        or (InCombatLockdown and InCombatLockdown())
        or (_G.C_ChatInfo
            and _G.C_ChatInfo.InChatMessagingLockdown
            and _G.C_ChatInfo.InChatMessagingLockdown()) then
        return false
    end
    if editBox.SetAttribute then
        if editBox.chatType then
            pcall(editBox.SetAttribute, editBox, "chatType", editBox.chatType)
        end
        if editBox.tellTarget then
            pcall(editBox.SetAttribute, editBox, "tellTarget", editBox.tellTarget)
        end
    end
    if _G.ChatEdit_UpdateHeader then
        _G.ChatEdit_UpdateHeader(editBox)
        return true
    end
    return false
end

local function KT_IsApproxEqual(value, target)
    return type(value) == "number" and math.abs(value - target) < 0.001
end

local function KT_IsSecretValue(value)
    return value ~= nil and issecretvalue(value)
end

local function KT_CanAccessValue(value)
    if value == nil or KT_IsSecretValue(value) then
        return false
    end

    local ok, canAccess = pcall(canaccessvalue, value)
    return ok and canAccess == true
end

local function KT_GetAccessibleString(value, fallback)
    if type(value) ~= "string" or not KT_CanAccessValue(value) then
        return fallback
    end

    return value
end

local function KT_GetNonEmptyAccessibleString(value, fallback)
    local text = KT_GetAccessibleString(value, fallback)
    if type(text) ~= "string" or text == "" then
        return fallback
    end

    return text
end

local function KT_GetAccessibleNumber(value, fallback)
    if type(value) ~= "number" or not KT_CanAccessValue(value) then
        return fallback
    end

    return value
end

local function KT_SafeString(value, fallback)
    if value == nil or not KT_CanAccessValue(value) then
        return fallback
    end

    local ok, text = pcall(tostring, value)
    if ok and type(text) == "string" then
        return text
    end

    return fallback
end

local function KT_AmbiguateAccessibleName(name, fallback)
    local text = KT_GetNonEmptyAccessibleString(name)
    if not text then
        return fallback
    end

    local ok, shortName = pcall(Ambiguate, text, "short")
    return ok and KT_GetNonEmptyAccessibleString(shortName, text) or text
end

local function KT_ShouldUseMirrorOnlyCapture(chatType)
    if not KT_IsSecureChatSafeMode() or type(chatType) ~= "string" then
        return false
    end

    return chatType ~= "COMBAT"
end

local function KT_GetDefaultChatWindowScale()
    if not GetPhysicalScreenSize then
        return 1
    end

    local _, height = GetPhysicalScreenSize()
    if type(height) ~= "number" then
        return 1
    end

    if height <= 1080 then
        return 0.9
    end

    return 1
end

local function KT_IsChatMessagingLocked()
    return C_ChatInfo
        and C_ChatInfo.InChatMessagingLockdown
        and C_ChatInfo.InChatMessagingLockdown()
end

local function KT_ActivateChat(editBox)
    if not editBox then
        return false
    end

    if ChatFrameUtil and ChatFrameUtil.ActivateChat then
        ChatFrameUtil.ActivateChat(editBox)
        return true
    end

    if _G.ChatEdit_ActivateChat then
        _G.ChatEdit_ActivateChat(editBox)
        return true
    end

    editBox:SetFocus()
    return true
end

local function KT_ProcessMessageEventFilters(chatFrame, event, ...)
    if ChatFrameUtil and ChatFrameUtil.ProcessMessageEventFilters then
        return ChatFrameUtil.ProcessMessageEventFilters(chatFrame, event, ...)
    end

    local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14 = ...
    local filters = ChatFrame_GetMessageEventFilters and ChatFrame_GetMessageEventFilters(event)
    if filters then
        -- The filter registry is a shared Blizzard table that can become
        -- tainted when C_AddOnProfiler (!!AddonProfiler) or similar addons
        -- mark the execution path. Iterating a tainted table inside a
        -- protected context (common in BG/Arena) throws
        -- "attempted to iterate a table that cannot be accessed while tainted".
        -- Snapshot the list via pcall so a tainted registry is skipped
        -- gracefully instead of cascading into thousands of UI errors.
        local ok, safeList = pcall(function()
            local list = {}
            for _, f in next, filters do list[#list + 1] = f end
            return list
        end)
        for _, filterFunc in ipairs(ok and safeList or {}) do
            local filtered
            filtered, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14 =
                filterFunc(chatFrame, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14)
            if filtered then
                return true
            end
        end
    end

    return false, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14
end

local function KT_ProcessSenderName(event, name, ...)
    if not (ChatFrameUtil and ChatFrameUtil.ProcessSenderNameFilters) then
        return name
    end

    local ok, filtered = pcall(ChatFrameUtil.ProcessSenderNameFilters, event, name, ...)
    if not ok then
        return name
    end

    return KT_GetNonEmptyAccessibleString(filtered, name) or name
end

local function KT_ResolveChannelDisplayName(chatType, channelName, channelBaseName)
    local resolvedName = KT_GetNonEmptyAccessibleString(channelName)
        or KT_GetNonEmptyAccessibleString(channelBaseName)

    if not resolvedName then
        return nil
    end

    if chatType == "CHANNEL" then
        local resolver = _G.ChatFrame_ResolvePrefixedChannelName
            or (ChatFrameUtil and ChatFrameUtil.ResolvePrefixedChannelName)
        if resolver then
            local ok, resolved = pcall(resolver, resolvedName)
            if ok then
                resolvedName = KT_GetNonEmptyAccessibleString(resolved, resolvedName) or resolvedName
            end
        end
    end

    return resolvedName
end

local function KT_IsInlineToastChannel(channelName)
    return type(channelName) == "string" and channelName:find("^BN_INLINE_TOAST", 1, false) ~= nil
end

local function KT_IsInternalMessageToken(message)
    return type(message) == "string" and message ~= "" and message:match("^[A-Z0-9_]+$") ~= nil
end

local function KT_ToDisplayWords(token)
    if type(token) ~= "string" or token == "" then
        return token
    end

    local words = strlower(token:gsub("_", " "))
    return (words:gsub("(%a)([%w']*)", function(first, rest)
        return strupper(first) .. rest
    end))
end

local function KT_GetDisplayChatLabel(chatType)
    if type(chatType) ~= "string" or chatType == "" then
        return nil
    end

    local explicit = CHAT_LABELS[chatType]
    if explicit ~= nil then
        return explicit
    end

    local monsterVariant = chatType:match("^MONSTER_(.+)$")
    if monsterVariant then
        return CHAT_LABELS[monsterVariant] or KT_ToDisplayWords(monsterVariant)
    end

    return KT_ToDisplayWords(chatType)
end

local function KT_GetInlineToastTemplate(channelName, token)
    if not KT_IsInlineToastChannel(channelName) or not KT_IsInternalMessageToken(token) then
        return nil
    end

    local lookupKeys = {
        channelName .. "_" .. token,
        "BN_INLINE_TOAST_" .. token,
        token,
    }

    for i = 1, #lookupKeys do
        local key = lookupKeys[i]
        local template = _G[key]
        if type(template) == "string" and template ~= "" and template ~= key then
            return template
        end
    end

    return nil
end

local function KT_FormatInlineToastMessage(channelName, message, author)
    if not KT_IsInlineToastChannel(channelName) then
        return nil
    end

    local token = KT_GetNonEmptyAccessibleString(message)
    if not token then
        return nil
    end

    local template = KT_GetInlineToastTemplate(channelName, token)
    if template then
        if author and author ~= "" and template:find("%%", 1, true) then
            local ok, rendered = pcall(format, template, author)
            if ok and type(rendered) == "string" and rendered ~= "" then
                return rendered
            end
        end

        return template
    end

    if token == "FRIEND_ONLINE" and author and author ~= "" then
        return author .. " connected."
    elseif token == "FRIEND_OFFLINE" and author and author ~= "" then
        return author .. " disconnected."
    end

    return nil
end

local function KT_NormalizeChatEventForDisplay(chatType, message, author, channelName, senderGUID)
    local normalizedType = chatType
    local normalizedMessage = message
    local normalizedAuthor = author
    local normalizedChannel = channelName
    local normalizedSenderGUID = senderGUID
    local normalizedLabel = KT_GetDisplayChatLabel(chatType)

    if KT_IsInlineToastChannel(channelName) then
        local inlineToastMessage = KT_FormatInlineToastMessage(channelName, message, author)
        if inlineToastMessage then
            return "SYSTEM", inlineToastMessage, nil, nil, nil, nil
        end
    end

    if chatType == "OPENING" or chatType == "TRADESKILLS" or chatType == "SKILL" then
        if type(normalizedAuthor) == "string" and normalizedAuthor ~= "" then
            normalizedMessage = normalizedAuthor .. " " .. tostring(normalizedMessage or "")
        end

        return "SYSTEM", normalizedMessage, nil, nil, nil, nil
    end

    return normalizedType, normalizedMessage, normalizedAuthor, normalizedLabel, normalizedChannel, normalizedSenderGUID
end

local function KT_NormalizeMirrorCompareText(text)
    if type(text) ~= "string" or text == "" then
        return nil
    end

    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:gsub("|H.-|h(.-)|h", "%1")
    text = text:gsub("^%s*%[%d%d:%d%d%]%s*", "")
    text = strtrim(text):gsub("%s+", " ")
    if text == "" then
        return nil
    end

    return strlower(text)
end

local function KT_IsRenderedMirrorDuplicate(renderedText, entry)
    if type(entry) ~= "table" then
        return false
    end

    local normalizedRendered = KT_NormalizeMirrorCompareText(renderedText)
    local normalizedLabel = KT_NormalizeMirrorCompareText(entry.label or KT_GetDisplayChatLabel(entry.chatType))
    local normalizedAuthor = KT_NormalizeMirrorCompareText(entry.authorFull or entry.authorRaw or entry.author)
    local normalizedMessage = KT_NormalizeMirrorCompareText(entry.rawMessage or entry.message)
    if not normalizedRendered or not normalizedAuthor or not normalizedMessage then
        return false
    end

    local labelMatches = normalizedLabel and normalizedRendered:find(normalizedLabel, 1, true)
    local chatType = tostring(entry.chatType or "")
    if not labelMatches then
        if chatType == "PARTY_LEADER" then
            labelMatches = normalizedRendered:find("party leader", 1, true) or normalizedRendered:find("party", 1, true)
        elseif chatType == "RAID_LEADER" then
            labelMatches = normalizedRendered:find("raid leader", 1, true) or normalizedRendered:find("raid", 1, true)
        elseif chatType == "INSTANCE_CHAT_LEADER" then
            labelMatches = normalizedRendered:find("instance leader", 1, true) or normalizedRendered:find("instance", 1, true)
        end
    end

    return labelMatches
        and normalizedRendered:find(normalizedAuthor, 1, true)
        and normalizedRendered:find(normalizedMessage, 1, true)
end

local function KT_IsRenderedTextDuplicate(firstText, secondText)
    local firstNormalized = KT_NormalizeMirrorCompareText(firstText)
    local secondNormalized = KT_NormalizeMirrorCompareText(secondText)
    return firstNormalized ~= nil and firstNormalized == secondNormalized
end

local function KT_GetDuplicateChatFamily(chatType)
    chatType = tostring(chatType or "")
    if chatType == "PARTY" or chatType == "PARTY_LEADER" then
        return "PARTY"
    elseif chatType == "RAID" or chatType == "RAID_LEADER" then
        return "RAID"
    elseif chatType == "INSTANCE_CHAT" or chatType == "INSTANCE_CHAT_LEADER" then
        return "INSTANCE_CHAT"
    end

    return chatType
end

local function KT_GetDuplicateChatPriority(chatType)
    if chatType == "PARTY_LEADER" or chatType == "RAID_LEADER" or chatType == "RAID_WARNING" or chatType == "INSTANCE_CHAT_LEADER" then
        return 2
    end

    return 1
end

local function KT_IsStructuredChatDuplicate(previousEntry, entry)
    if type(previousEntry) ~= "table" or type(entry) ~= "table" then
        return false
    end

    if previousEntry.preformatted or entry.preformatted then
        return false
    end

    if KT_GetDuplicateChatFamily(previousEntry.chatType) ~= KT_GetDuplicateChatFamily(entry.chatType) then
        return false
    end

    local previousAuthor = KT_NormalizeMirrorCompareText(previousEntry.senderGUID or previousEntry.authorFull or previousEntry.authorRaw or previousEntry.author)
    local currentAuthor = KT_NormalizeMirrorCompareText(entry.senderGUID or entry.authorFull or entry.authorRaw or entry.author)
    local previousMessage = KT_NormalizeMirrorCompareText(previousEntry.rawMessage or previousEntry.message)
    local currentMessage = KT_NormalizeMirrorCompareText(entry.rawMessage or entry.message)
    local previousTimestamp = tostring(previousEntry.timestamp or "")
    local currentTimestamp = tostring(entry.timestamp or "")

    return previousAuthor and currentAuthor
        and previousMessage and currentMessage
        and previousAuthor == currentAuthor
        and previousMessage == currentMessage
        and previousTimestamp == currentTimestamp
end

local function KT_ReplaceChatExpressions(message, chatType, shouldSuppressRaidIcons)
    local replacer = _G.ChatFrame_ReplaceIconAndGroupExpressions
        or (C_ChatInfo and C_ChatInfo.ReplaceIconAndGroupExpressions)
    if not replacer or type(message) ~= "string" then
        return message
    end

    local canExpand = _G.ChatFrame_CanChatGroupPerformExpressionExpansion
        or (ChatFrameUtil and ChatFrameUtil.CanChatGroupPerformExpressionExpansion)
    local disableGroupExpansion = false
    if canExpand then
        local groupKey = chatType == "CHANNEL" and "CHANNEL" or chatType
        local ok, expansionAllowed = pcall(canExpand, groupKey)
        if ok then
            disableGroupExpansion = not expansionAllowed
        end
    end

    local ok, replaced = pcall(replacer, message, shouldSuppressRaidIcons, disableGroupExpansion)
    if ok then
        return KT_GetNonEmptyAccessibleString(replaced, message) or message
    end

    return message
end

local function KT_UpdateLastTellTarget(name, chatType)
    -- Disabled to prevent Lua Taint from insecure attribute setting on ChatFrame EditBox
end

local function KT_IsBNetWhisperEvent(event)
    return event == "CHAT_MSG_BN_WHISPER" or event == "CHAT_MSG_BN_WHISPER_INFORM"
end

local function KT_GetBNetWhisperSenderID(arg13, arg14)
    if type(arg14) == "number" then
        return arg14
    end

    if type(arg13) == "number" then
        return arg13
    end

    return nil
end

local function KT_GetWhisperEventLineID(event, lineID)
    if KT_IsBNetWhisperEvent(event) then
        return nil
    end

    return type(lineID) == "number" and lineID or nil
end

local function KT_BuildWhisperEventDedupeKey(event, ...)
    local lineID = KT_GetWhisperEventLineID(event, select(11, ...))
    if lineID then
        return "line:" .. tostring(lineID)
    end

    local message = KT_GetAccessibleString(select(1, ...), "") or ""
    local sender = KT_GetAccessibleString(select(2, ...), "") or ""
    local presenceID = select(11, ...)
    local arg13 = select(13, ...)
    local arg14 = select(14, ...)
    local bnSenderID = KT_GetBNetWhisperSenderID(arg13, arg14)

    return table.concat({
        tostring(event or ""),
        KT_SafeString(presenceID, ""),
        KT_SafeString(bnSenderID, ""),
        sender,
        message,
    }, "|")
end

local function KT_ShouldUseNativeWhisperWindow(chatType)
    chatType = tostring(chatType or "")
    return chatType == "WHISPER"
        or chatType == "WHISPER_INFORM"
        or chatType == "BN_WHISPER"
        or chatType == "BN_WHISPER_INFORM"
end

local function KT_BuildWhisperDisplayLink(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local authorText = KT_GetAccessibleString(entry.author, KT_GetAccessibleString(entry.authorRaw, nil))
    if type(entry.bnSenderID) == "number" then
        local target = KT_ResolveBNetWhisperTarget(entry.bnSenderID) or authorText
        target = KT_GetNonEmptyAccessibleString(target)
        if not target then
            return nil
        end
        local senderID = KT_SafeString(entry.bnSenderID, nil)
        if not senderID then
            return nil
        end
        return "|HBNplayer:" .. target .. ":" .. senderID .. "|h" .. target .. "|h"
    end

    local target = KT_GetNonEmptyAccessibleString(entry.authorFull, authorText)
    if not target then
        return nil
    end

    local displayTarget = target
    if KT and KT.db and KT.db.profile and KT.db.profile.chat and KT.db.profile.chat.classColorNames ~= false and type(KT_ColorizePlayerName) == "function" then
        local coloredTarget = KT_ColorizePlayerName(target, entry.senderGUID)
        if type(coloredTarget) == "string" and coloredTarget ~= "" and coloredTarget ~= target then
            displayTarget = coloredTarget
        else
            displayTarget = "|cffffffff" .. target .. "|r"
        end
    end

    local lineID = type(entry.lineID) == "number" and entry.lineID or 0
    local chatType = KT_GetNonEmptyAccessibleString(entry.chatType, "WHISPER") or "WHISPER"
    local senderGUID = KT_GetNonEmptyAccessibleString(entry.senderGUID, "") or ""
    -- Keep Blizzard's player-link context fields so right-click can build the
    -- native player/report menu for this exact chat line.
    local linkData = table.concat({
        target, tostring(lineID), chatType, target, "", "0", "0", "", "", senderGUID,
    }, ":")
    return "|Hplayer:" .. linkData .. "|h" .. displayTarget .. "|h"
end
local function KT_GetLastTellTarget()
    local getter = _G.ChatEdit_GetLastTellTarget
        or (ChatFrameUtil and ChatFrameUtil.GetLastTellTarget)
    if not getter then
        return nil
    end

    local ok, target = pcall(getter)
    if not ok then
        return nil
    end

    return KT_GetNonEmptyAccessibleString(target)
end

local function KT_IsTradeChannelName(value)
    local text = strlower(tostring(value or ""))
    return text:find("trade", 1, true) ~= nil
        or text:find("comerc", 1, true) ~= nil
        or text:find("city", 1, true) ~= nil
        or text:find("ciudad", 1, true) ~= nil
end

local function KT_CollectTradeChannels(sourceFrame)
    local channels = {}
    if KT_IsSecureChatSafeMode() then
        return channels
    end

    local seen = {}

    local function addChannel(channelName, channelID)
        if type(channelName) ~= "string" or channelName == "" or not KT_IsTradeChannelName(channelName) then
            return
        end

        local id = type(channelID) == "number" and channelID or nil
        if not id and _G.GetChannelName then
            local ok, resolvedID = pcall(_G.GetChannelName, channelName)
            if ok and type(resolvedID) == "number" then
                id = resolvedID
            end
        end

        if type(id) ~= "number" or id <= 0 or seen[id] then
            return
        end

        seen[id] = true
        channels[#channels + 1] = { id = id, name = channelName }
    end

    local channelList = sourceFrame and sourceFrame.channelList
    if type(channelList) == "table" then
        for key, value in pairs(channelList) do
            if type(key) == "string" then
                addChannel(key, type(value) == "number" and value or nil)
            elseif type(value) == "string" then
                addChannel(value, type(key) == "number" and key or nil)
            end
        end
    end

    if _G.GetChannelList then
        local result = { pcall(_G.GetChannelList) }
        if result[1] then
            for index = 2, #result, 2 do
                addChannel(result[index + 1], result[index])
            end
        end
    end

    return channels
end

local function KT_GetTradeChannelCommand()
    local channels = KT_CollectTradeChannels(_G.ChatFrame1)
    if channels[1] then
        return "/" .. channels[1].id .. " "
    end
    return "/2 "
end

local function KT_RefreshTradeNativeChannels(frame)
    if KT_IsSecureChatSafeMode() then
        return 0
    end

    if not (frame and _G.ChatFrame_AddChannel) then
        return 0
    end
    if _G.ChatFrame_RemoveAllChannels then
        pcall(_G.ChatFrame_RemoveAllChannels, frame)
    end

    local channels = KT_CollectTradeChannels(_G.ChatFrame1)
    for _, channel in ipairs(channels) do
        pcall(_G.ChatFrame_AddChannel, frame, channel.name)
    end
    return #channels
end

local function KT_GetGroupCommand()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        return "/i "
    end

    if IsInRaid and IsInRaid() then
        return "/raid "
    end

    if IsInGroup and IsInGroup() then
        return "/p "
    end

    return "/p "
end

local function KT_GetTabCommand(tab)
    if not tab then
        return ""
    end

    local mode = strupper(tostring(tab.filterMode or ""))
    local tabId = strlower(strtrim(tostring(tab.id or "")))
    local baseCommand = tostring(tab.command or "")

    if mode == "WHISPER" then
        local selectedThread = Mod and Mod.selectedWhisperThread or nil
        if (selectedThread and type(selectedThread.bnetIDAccount) == "number")
            or (Mod and type(Mod.activeWhisperBNetAccountID) == "number") then
            return ""
        end

        local target = (Mod and Mod.GetActiveWhisperTargetForInput and Mod:GetActiveWhisperTargetForInput()) or KT_GetLastTellTarget()
        if target then
            return "/w " .. target .. " "
        end
    elseif mode == "CHANNEL" or tabId == "trade" then
        return KT_GetTradeChannelCommand()
    elseif mode == "GROUP" or tabId == "group" then
        return KT_GetGroupCommand()
    end

    return baseCommand
end

local function KT_SendEditText(editBox)
    if not editBox or KT_IsChatMessagingLocked() then
        return false
    end

    if Mod and Mod.NormalizeBNetEditBoxStateForSend then
        pcall(Mod.NormalizeBNetEditBoxStateForSend, Mod, editBox)
    end

    if type(editBox.SendText) == "function" then
        local ok = pcall(editBox.SendText, editBox, 0)
        if ok then
            return true
        end
    end

    if type(_G.ChatEdit_SendText) == "function" then
        local ok = pcall(_G.ChatEdit_SendText, editBox, 0)
        if ok then
            return true
        end
    end

    return false
end

local function KT_IsBNetWhisperKind(chatType, bnetIDAccount)
    if type(bnetIDAccount) == "number" and bnetIDAccount > 0 then
        return true
    end

    return type(chatType) == "string" and chatType:find("BN_", 1, true) ~= nil
end

local function KT_GetWhisperTargetKey(target, chatType, bnetIDAccount)
    local prefix = KT_IsBNetWhisperKind(chatType, bnetIDAccount) and "bn:" or "w:"
    if prefix == "bn:" and type(bnetIDAccount) == "number" and bnetIDAccount > 0 then
        return prefix .. KT_SafeString(bnetIDAccount, "")
    end

    target = KT_GetNonEmptyAccessibleString(target)
    if not target then
        return nil
    end

    return prefix .. strlower(target)
end

local function KT_GetBattleTagBase(target)
    target = KT_GetNonEmptyAccessibleString(target)
    if not target then
        return nil
    end

    local base = target:match("^([^#]+)") or target
    base = strtrim(base)
    if base == "" then
        return nil
    end

    return strlower(base)
end

local function KT_TargetMatchesBNetTarget(target, candidate)
    local normalizedTarget = KT_GetBattleTagBase(target)
    local normalizedCandidate = KT_GetBattleTagBase(candidate)
    if not normalizedTarget or not normalizedCandidate then
        return false
    end

    return normalizedTarget == normalizedCandidate
end

local function KT_GetWhisperTargetAbbrev(target)
    local text = KT_GetNonEmptyAccessibleString(target, "?") or "?"
    text = text:gsub("%-.+$", "")
    text = text:gsub("[^%a%d]", "")
    if text == "" then
        return "?"
    end
    return strupper(text:sub(1, 3))
end

local function KT_GetWhisperThreadTargetText(target)
    target = KT_GetNonEmptyAccessibleString(target)
    if not target then
        return nil
    end
    return strlower(target)
end

local function KT_IsSecretWhisperTarget(target)
    target = KT_GetNonEmptyAccessibleString(target)
    return type(target) == "string" and target:match("^|K.-|k$") ~= nil
end

local function KT_DoesEntryMatchWhisperThread(entry, thread)
    if not entry or not thread then
        return true
    end

    if type(thread.threadKey) == "string" and type(entry.whisperThreadKey) == "string" then
        return entry.whisperThreadKey == thread.threadKey
    end

    if type(thread.bnetIDAccount) == "number" and type(entry.bnSenderID) == "number" then
        return entry.bnSenderID == thread.bnetIDAccount
    end

    local threadTarget = KT_GetWhisperThreadTargetText(thread.target)
    if not threadTarget then
        return false
    end

    local candidates = { entry.whisperTarget, entry.authorRaw, entry.authorFull, entry.author }
    for _, candidate in ipairs(candidates) do
        if KT_GetWhisperThreadTargetText(candidate) == threadTarget then
            return true
        end
    end

    return false
end

function Mod:GetActiveWhisperTargetForInput()
    if type(self.activeWhisperBNetAccountID) == "number" then
        return nil
    end
    return KT_GetNonEmptyAccessibleString(self.activeWhisperTarget) or KT_GetLastTellTarget()
end

function Mod:GetInputPromptText(editBox)
    local tab = self:GetActiveTab()
    local prompt = tab and (tab.prompt or tab.label) or nil
    local mode = strupper(strtrim(tostring(tab and tab.filterMode or "")))
    local chatType = tostring(editBox and editBox.chatType or "")
    local tellTarget = KT_GetNonEmptyAccessibleString(editBox and editBox.tellTarget)
    local bnetIDAccount = tonumber(editBox and editBox.bnetAccountID)

    if editBox and editBox.GetAttribute then
        local okChatType, attrChatType = pcall(editBox.GetAttribute, editBox, "chatType")
        if okChatType and type(attrChatType) == "string" and attrChatType ~= "" then
            chatType = attrChatType
        end

        local okTellTarget, attrTellTarget = pcall(editBox.GetAttribute, editBox, "tellTarget")
        if okTellTarget then
            tellTarget = KT_GetNonEmptyAccessibleString(attrTellTarget) or tellTarget
        end

        local okBNetID, attrBNetID = pcall(editBox.GetAttribute, editBox, "bnetAccountID")
        if okBNetID and tonumber(attrBNetID) then
            bnetIDAccount = tonumber(attrBNetID)
        end
    end

    local target = tellTarget
    if not target and type(bnetIDAccount) == "number" then
        target = KT_GetNonEmptyAccessibleString(KT_ResolveBNetWhisperTarget(bnetIDAccount))
    end
    if not target and type(self.selectedWhisperThread) == "table" then
        target = KT_GetNonEmptyAccessibleString(self.selectedWhisperThread.target)
    end
    if not target then
        target = KT_GetNonEmptyAccessibleString(self.activeWhisperTarget)
    end
    if not target and (chatType == "REPLY" or mode == "WHISPER") then
        target = KT_GetLastTellTarget()
    end

    if mode == "WHISPER" or chatType == "WHISPER" or chatType == "BN_WHISPER" or chatType == "REPLY" then
        local whisperPrompt = tostring(prompt or CHAT_LABELS.WHISPER or "Whisper")
        if target then
            if chatType == "BN_WHISPER" or type(bnetIDAccount) == "number" then
                return format("%s %s:", whisperPrompt, target)
            end
            return "/w " .. target
        end
        return whisperPrompt .. ":"
    end

    if prompt and prompt ~= "" then
        return tostring(prompt) .. ":"
    end

    return nil
end

function Mod:UpdateInputPrompt(editBox)
    local window = _G.KT_ChatWindow
    editBox = editBox or _G.ChatFrame1EditBox
    if not editBox then
        return
    end

    if window and window.KT_InputPromptLabel then
        window.KT_InputPromptLabel:Hide()
    end
    if window and window.KT_InputPromptFrame then
        window.KT_InputPromptFrame:Hide()
    end

    -- We rely entirely on the native SetTextInsets which is hooked to provide +8px padding
end

function Mod:KT_UpdateInputPrompt_OLD(editBox)
    local window = _G.KT_ChatWindow
    editBox = editBox or _G.ChatFrame1EditBox
    if not editBox then
        return
    end

    local promptText = self:GetInputPromptText(editBox)
    local currentText = (editBox.GetText and editBox:GetText()) or ""
    if type(currentText) == "string" and currentText:find("^%s*/") then
        promptText = nil
    end
    local promptWidth = 0
    if window and window.KT_InputHost then
        local promptFrame = window.KT_InputPromptFrame
        if not promptFrame then
            promptFrame = CreateFrame("Frame", nil, window.KT_InputHost)
            promptFrame:SetAllPoints(window.KT_InputHost)
            promptFrame:EnableMouse(false)
            window.KT_InputPromptFrame = promptFrame
        end

        if promptFrame.SetFrameStrata and editBox.GetFrameStrata then
            promptFrame:SetFrameStrata(editBox:GetFrameStrata())
        end
        if promptFrame.SetFrameLevel and editBox.GetFrameLevel then
            promptFrame:SetFrameLevel((editBox:GetFrameLevel() or 0) + 8)
        end

        local label = window.KT_InputPromptLabel
        if not label then
            label = promptFrame:CreateFontString(nil, "OVERLAY")
            label:SetPoint("LEFT", promptFrame, "LEFT", 10, 0)
            label:SetJustifyH("LEFT")
            label:SetJustifyV("MIDDLE")
            label:SetWordWrap(false)
            label:SetAlpha(0.92)
            window.KT_InputPromptLabel = label
        elseif label:GetParent() ~= promptFrame then
            label:SetParent(promptFrame)
            label:ClearAllPoints()
            label:SetPoint("LEFT", promptFrame, "LEFT", 10, 0)
        end

        local fontPath, fontSize, fontOutline = self:GetResolvedFont()
        label:SetFont(fontPath, fontSize, fontOutline)
        label:SetTextColor(0.94, 0.94, 0.98, 0.92)

        if promptText and promptText ~= "" then
            label:SetText(promptText)
            label:Show()
            promptFrame:Show()
            promptWidth = math.floor((label:GetStringWidth() or 0) + 18)
        else
            label:SetText("")
            label:Hide()
            promptFrame:Hide()
        end
    elseif window and window.KT_InputPromptLabel then
        window.KT_InputPromptLabel:SetText("")
        window.KT_InputPromptLabel:Hide()
    end

    if editBox.SetTextInsets then
        local leftInset = math.max(8, promptWidth or 0)
        editBox:SetTextInsets(leftInset, 8, 5, 5)
    end
end

function Mod:RestoreBlizzardEditBoxHeader(editBox)
    self:UpdateInputPrompt(editBox)
end

function Mod:GetWhisperTabIndex()
    for index, tab in ipairs(self.tabs or {}) do
        if tab and (tab.id == "whisper" or tab.filterMode == "WHISPER") then
            return index
        end
    end
    return nil
end

function Mod:GetWhisperStripReservedWidth(parent)
    local window = parent and parent:GetParent()
    local strip = window and window.KT_WhisperStrip
    if strip and strip:IsShown() then
        return (strip:GetWidth() or KT_CHAT_WHISPER_STRIP_WIDTH) + 10
    end
    return 0
end

function Mod:GetChatContentInsets(parent)
    local whisperInset = self:GetWhisperStripReservedWidth(parent)
    return 14, -12, -(16 + whisperInset), 42
end

function Mod:ApplyNormalChatFrameLayout()
    local window = _G.KT_ChatWindow
    local frame = _G.KT_ChatFrame
    local content = window and window.KT_Content
    if not (frame and content) then
        return
    end

    local leftInset, topInset, rightInset, bottomInset = self:GetChatContentInsets(content)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", content, "TOPLEFT", leftInset, topInset)
    frame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", rightInset, bottomInset)
end

function Mod:RefreshWhisperStrip()
    local window = _G.KT_ChatWindow
    local strip = window and window.KT_WhisperStrip
    local buttons = window and window.KT_WhisperStripButtons
    if not (window and strip and buttons) then
        return
    end

    local targets = self.whisperTargets or {}
    local selectedThread = self.selectedWhisperThread
    local activeTarget = selectedThread and KT_GetNonEmptyAccessibleString(selectedThread.target)
    local shown = 0
    local maxButtons = tonumber(KT_CHAT_WHISPER_STRIP_MAX_BUTTONS) or 6

    for i = 1, maxButtons do
        local button = buttons[i]
        local data = targets[i]
        if button and data and data.target then
            shown = shown + 1
            button.KT_Target = data.target
            button.KT_BNetAccountID = data.bnetIDAccount
            button.KT_ChatType = data.chatType

            local chatTypeText = tostring(data.chatType or "")
            if chatTypeText:find("BN_", 1, true) then
                if type(data.bnetIDAccount) ~= "number" then
                    data.bnetIDAccount = KT_ResolveBNetAccountIDLoose(data.target)
                end
            else
                data.bnetIDAccount = nil
            end
            button.KT_BNetAccountID = data.bnetIDAccount
            local isActive = activeTarget and activeTarget == data.target
            local isBNet = KT_IsBNetWhisperKind(data.chatType, data.bnetIDAccount)
            if button.KT_Label then
                button.KT_Label:SetText(KT_GetWhisperTargetAbbrev(data.target))
                if isBNet then
                    button.KT_Label:SetTextColor(0.92, 0.96, 1, isActive and 1 or 0.95)
                else
                    button.KT_Label:SetTextColor(1, 0.78, 0.9, isActive and 1 or 0.95)
                end
            end
            if button.KT_Icon then
                if button.KT_Icon.SetDesaturated then
                    button.KT_Icon:SetDesaturated(true)
                end
                if isBNet then
                    button.KT_Icon:SetVertexColor(0.42, 0.78, 1, isActive and 1 or 0.9)
                else
                    button.KT_Icon:SetVertexColor(1, 0.35, 0.67, isActive and 1 or 0.9)
                end
            end

            if isBNet then
                button:SetBackdropColor(isActive and 0.08 or 0.04, isActive and 0.20 or 0.12, isActive and 0.36 or 0.22, isActive and 0.95 or 0.82)
                button:SetBackdropBorderColor(isActive and 0.25 or 0.12, isActive and 0.72 or 0.35, 1, isActive and 0.95 or 0.85)
            else
                button:SetBackdropColor(isActive and 0.22 or 0.12, isActive and 0.08 or 0.04, isActive and 0.18 or 0.1, isActive and 0.95 or 0.82)
                button:SetBackdropBorderColor(isActive and 1 or 0.7, isActive and 0.45 or 0.28, isActive and 0.72 or 0.5, isActive and 0.95 or 0.85)
            end
            button:SetAlpha(isActive and 1 or 0.9)
            if button.KT_Close then
                button.KT_Close:Show()
            end
            button:Show()
            button:Show()
            KT_SetTooltip(button, data.target)
        elseif button then
            button.KT_Target = nil
            button.KT_BNetAccountID = nil
            button.KT_ChatType = nil
            if button.KT_Close then
                button.KT_Close:Hide()
            end
            button:Hide()
        end
    end

    local hasAnyTargets = shown > 0
    strip:SetShown(hasAnyTargets)
    self:ApplyNormalChatFrameLayout()
    self:RefreshChatFrameMode()
    self:UpdateScrollButtonVisibility()
end

function Mod:ReflowChatLayout()
    local window = _G.KT_ChatWindow
    if not window or not self.db or self.db.enable == false then
        return
    end

    self:ApplyNormalChatFrameLayout()
    self:AttachBlizzardEditBox()
    self:RefreshChatFrameMode()
    self:UpdateSidebarLayout()
    self:UpdateSocialButton()
    self:UpdateScrollButtonVisibility()
end

function Mod:QueueChatLayoutReflow()
    self.chatLayoutReflowToken = (tonumber(self.chatLayoutReflowToken) or 0) + 1
    local token = self.chatLayoutReflowToken

    local function run()
        if not (Mod and Mod.IsEnabled and Mod:IsEnabled()) then
            return
        end
        if token ~= Mod.chatLayoutReflowToken then
            return
        end
        Mod:ReflowChatLayout()
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(0, run)
        C_Timer.After(0.05, run)
        C_Timer.After(0.2, run)
        C_Timer.After(0.5, run)
    else
        run()
    end
end

function Mod:AddWhisperTarget(target, chatType, makeActive, bnetIDAccount, skipPersist)
    local isBNet = KT_IsBNetWhisperKind(chatType, bnetIDAccount)
    local rawTarget = target
    target = KT_GetNonEmptyAccessibleString(target)

    if isBNet and type(bnetIDAccount) == "number" then
        target = KT_ResolveBNetWhisperTarget(bnetIDAccount) or target
        if not target and type(rawTarget) == "string" then
            target = rawTarget
        end
        target = target or KT_BNET_PLACEHOLDER
    elseif isBNet then
        bnetIDAccount = KT_ResolveBNetAccountIDLoose(target)
    end

    if not target then
        return
    end

    if isBNet and type(bnetIDAccount) ~= "number" and KT_IsSecretWhisperTarget(target) then
        return
    end

    self.whisperTargets = self.whisperTargets or {}
    self.whisperTargetLookup = self.whisperTargetLookup or {}

    local key = KT_GetWhisperTargetKey(target, chatType, bnetIDAccount)
    if not key then
        return
    end

    local normalizedTarget = KT_GetWhisperThreadTargetText(target)
    local existingIndex = self.whisperTargetLookup[key]
    if not existingIndex then
        for index, data in ipairs(self.whisperTargets) do
            local sameBNet = type(bnetIDAccount) == "number"
                and type(data.bnetIDAccount) == "number"
                and data.bnetIDAccount == bnetIDAccount
            local sameType = isBNet == KT_IsBNetWhisperKind(data.chatType, data.bnetIDAccount)
            local sameTarget = sameType and normalizedTarget and KT_GetWhisperThreadTargetText(data.target) == normalizedTarget
            if sameBNet or sameTarget then
                existingIndex = index
                break
            end
        end
    end

    local entry = nil
    if existingIndex then
        entry = tremove(self.whisperTargets, existingIndex)
        entry.target = target
        entry.chatType = chatType or entry.chatType
        if type(bnetIDAccount) == "number" then
            entry.bnetIDAccount = bnetIDAccount
        else
            entry.bnetIDAccount = nil
        end
        entry.threadKey = key
    else
        entry = {
            target = target,
            chatType = chatType,
            bnetIDAccount = bnetIDAccount,
            threadKey = key,
        }
    end
    table.insert(self.whisperTargets, 1, entry)

    wipe(self.whisperTargetLookup)
    for index, data in ipairs(self.whisperTargets) do
        local dataKey = KT_GetWhisperTargetKey(data.target, data.chatType, data.bnetIDAccount)
        if dataKey then
            self.whisperTargetLookup[dataKey] = index
        end
    end

    local maxButtons = tonumber(KT_CHAT_WHISPER_STRIP_MAX_BUTTONS) or 6
    while #self.whisperTargets > maxButtons do
        table.remove(self.whisperTargets)
    end

    if self.selectedWhisperThread then
        local selectedTarget = KT_GetWhisperThreadTargetText(self.selectedWhisperThread.target)
        local sameSelectedBNet = type(bnetIDAccount) == "number"
            and type(self.selectedWhisperThread.bnetIDAccount) == "number"
            and self.selectedWhisperThread.bnetIDAccount == bnetIDAccount
        local sameSelectedType = isBNet == KT_IsBNetWhisperKind(self.selectedWhisperThread.chatType, self.selectedWhisperThread.bnetIDAccount)
        local sameSelectedTarget = sameSelectedType and normalizedTarget and selectedTarget == normalizedTarget
        if sameSelectedBNet or sameSelectedTarget then
            self.selectedWhisperThread.target = target
            self.selectedWhisperThread.chatType = chatType or self.selectedWhisperThread.chatType
            if type(bnetIDAccount) == "number" then
                self.selectedWhisperThread.bnetIDAccount = bnetIDAccount
            else
                self.selectedWhisperThread.bnetIDAccount = nil
            end
            self.selectedWhisperThread.threadKey = key
        end
    end

    if makeActive then
        self.activeWhisperTarget = target
        self.selectedWhisperThread = {
            target = target,
            chatType = chatType,
            bnetIDAccount = bnetIDAccount,
            threadKey = key,
        }
        self.activeWhisperBNetAccountID = (type(bnetIDAccount) == "number") and bnetIDAccount or nil
        KT_UpdateLastTellTarget(target, chatType)
    end

    self:RefreshWhisperStrip()
    if not skipPersist then
        self:PersistPrivateChatState()
    end
end

function Mod:RemoveWhisperTarget(target, bnetIDAccount)
    local normalizedTarget = KT_GetWhisperThreadTargetText(target)
    local removed = false

    for index = #(self.whisperTargets or {}), 1, -1 do
        local data = self.whisperTargets[index]
        local sameBNet = type(bnetIDAccount) == "number" and type(data.bnetIDAccount) == "number" and data.bnetIDAccount == bnetIDAccount
        local sameType = (type(bnetIDAccount) == "number") == (type(data.bnetIDAccount) == "number")
        local sameTarget = sameType and normalizedTarget and KT_GetWhisperThreadTargetText(data.target) == normalizedTarget
        if sameBNet or sameTarget then
            table.remove(self.whisperTargets, index)
            removed = true
            break
        end
    end

    if not removed then
        return
    end

    wipe(self.whisperTargetLookup or {})
    for index, data in ipairs(self.whisperTargets or {}) do
        local dataKey = KT_GetWhisperTargetKey(data.target, data.chatType, data.bnetIDAccount)
        if dataKey then
            self.whisperTargetLookup[dataKey] = index
        end
    end

    if self.selectedWhisperThread then
        local sameSelectedBNet = type(bnetIDAccount) == "number" and type(self.selectedWhisperThread.bnetIDAccount) == "number" and self.selectedWhisperThread.bnetIDAccount == bnetIDAccount
        local sameSelectedTarget = normalizedTarget and KT_GetWhisperThreadTargetText(self.selectedWhisperThread.target) == normalizedTarget
        if sameSelectedBNet or sameSelectedTarget then
            self.selectedWhisperThread = nil
            self.activeWhisperTarget = nil
            self.activeWhisperBNetAccountID = nil
        end
    end

    self:RefreshWhisperStrip()
    self:PersistPrivateChatState()
    self:RenderAllFrames()
    self:RefreshChatFrameMode()
    self:UpdateScrollButtonVisibility()
end

function Mod:HandleWhisperStripClick(target, bnetIDAccount, chatType)
    if not target then
        return
    end

    chatType = KT_IsBNetWhisperKind(chatType, bnetIDAccount) and "BN_WHISPER" or "WHISPER"
    if chatType == "BN_WHISPER" and type(bnetIDAccount) ~= "number" then
        bnetIDAccount = KT_ResolveBNetAccountIDLoose(target)
    end
    self.selectedWhisperThread = {
        target = target,
        chatType = chatType,
        bnetIDAccount = bnetIDAccount,
        threadKey = KT_GetWhisperTargetKey(target, chatType, bnetIDAccount),
    }
    self.activeWhisperTarget = target
    self.activeWhisperBNetAccountID = (type(bnetIDAccount) == "number") and bnetIDAccount or nil
    self:AddWhisperTarget(target, chatType, true, bnetIDAccount)

    local whisperTabIndex = self:GetWhisperTabIndex()
    if whisperTabIndex then
        self.selectedTabIndex = whisperTabIndex
        self:SelectTab(whisperTabIndex)
        self:RenderAllFrames()
    else
        self:RenderAllFrames()
    end

    self:OpenDirectWhisperTarget(target, bnetIDAccount)
end

local function KT_GetReplyChatFrame()
    return (_G.ChatFrame1 and _G.ChatFrame1.editBox and _G.ChatFrame1)
        or (_G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.editBox and _G.DEFAULT_CHAT_FRAME)
        or nil
end

local function KT_NormalizeWhisperRealmName(realmName)
    realmName = KT_GetNonEmptyAccessibleString(realmName)
    if not realmName then
        return nil
    end

    realmName = realmName:gsub("[%s%-']+", "")
    return realmName ~= "" and realmName or nil
end
local function KT_GetResolvedWoWWhisperTargets(target)
    target = KT_GetNonEmptyAccessibleString(target)
    if not target then
        return nil, nil
    end

    local namePart, realmPart = strsplit("-", target, 2)
    local shortTarget = KT_GetNonEmptyAccessibleString(namePart, target)
    local fullTarget = target

    local playerRealm = nil
    if UnitFullName then
        local _, unitRealm = UnitFullName("player")
        playerRealm = KT_NormalizeWhisperRealmName(unitRealm)
    end
    if not playerRealm and GetRealmName then
        playerRealm = KT_NormalizeWhisperRealmName(GetRealmName())
    end

    local normalizedTargetRealm = KT_NormalizeWhisperRealmName(realmPart)
    if normalizedTargetRealm and playerRealm and normalizedTargetRealm == playerRealm then
        fullTarget = shortTarget
    end

    if _G.Ambiguate then
        local ok, shortened = pcall(_G.Ambiguate, target, "short")
        if ok then
            shortTarget = KT_GetNonEmptyAccessibleString(shortened, shortTarget)
        end
    end

    return fullTarget, shortTarget
end


local function KT_ResolveBNetAccountID(target)
    target = KT_GetNonEmptyAccessibleString(target)
    if not target or not target:find("#", 1, true) then
        return nil
    end

    if not C_BattleNet or not C_BattleNet.GetFriendAccountInfo or not BNGetNumFriends then
        return nil
    end

    local normalized = strlower(target)
    local friendCount = BNGetNumFriends() or 0
    for index = 1, friendCount do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(index)
        if accountInfo then
            local battleTag = KT_GetNonEmptyAccessibleString(accountInfo.battleTag)
            local accountName = KT_GetNonEmptyAccessibleString(accountInfo.accountName)
            if (battleTag and strlower(battleTag) == normalized) or (accountName and strlower(accountName) == normalized) then
                return tonumber(accountInfo.bnetAccountID) or tonumber(accountInfo.accountID)
            end
        end
    end

    return nil
end

KT_ResolveBNetAccountIDLoose = function(target)
    target = KT_GetNonEmptyAccessibleString(target)
    if not target then
        return nil
    end

    if not C_BattleNet or not C_BattleNet.GetFriendAccountInfo or not BNGetNumFriends then
        return nil
    end

    local normalized = strlower(target)
    local normalizedBase = KT_GetBattleTagBase(target)
    local friendCount = BNGetNumFriends() or 0
    for index = 1, friendCount do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(index)
        if accountInfo then
            local battleTag = KT_GetNonEmptyAccessibleString(accountInfo.battleTag)
            local accountName = KT_GetNonEmptyAccessibleString(accountInfo.accountName)
            local battleTagBase = KT_GetBattleTagBase(battleTag)
            local accountNameBase = KT_GetBattleTagBase(accountName)
            if (battleTag and strlower(battleTag) == normalized)
                or (accountName and strlower(accountName) == normalized)
                or (normalizedBase and battleTagBase == normalizedBase)
                or (normalizedBase and accountNameBase == normalizedBase) then
                return tonumber(accountInfo.bnetAccountID) or tonumber(accountInfo.accountID)
            end
        end
    end

    return nil
end
KT_ResolveBNetWhisperTarget = function(bnetIDAccount)
    if type(bnetIDAccount) ~= "number" or not C_BattleNet or not C_BattleNet.GetAccountInfoByID then
        return nil
    end

    local accountInfo = C_BattleNet.GetAccountInfoByID(bnetIDAccount)
    if not accountInfo then
        return nil
    end

    local battleTag = KT_GetNonEmptyAccessibleString(accountInfo.battleTag)
    local accountName = KT_GetNonEmptyAccessibleString(accountInfo.accountName)
    if accountName then
        return accountName
    end
    if battleTag then
        return KT_GetBattleTagBase(battleTag) or battleTag
    end

    local gameAccountInfo = accountInfo.gameAccountInfo
    if not gameAccountInfo or gameAccountInfo.clientProgram ~= BNET_CLIENT_WOW then
        return nil
    end

    local characterName = KT_GetNonEmptyAccessibleString(gameAccountInfo.characterName)
    if not characterName then
        return nil
    end

    if _G.BNet_GetValidatedCharacterName then
        local ok, validatedName = pcall(_G.BNet_GetValidatedCharacterName, characterName, battleTag)
        characterName = ok and KT_GetNonEmptyAccessibleString(validatedName, characterName) or characterName
    end

    local realmName = KT_NormalizeWhisperRealmName(gameAccountInfo.realmName or gameAccountInfo.realmDisplayName)
    if realmName and not characterName:find("-", 1, true) then
        characterName = characterName .. "-" .. realmName
    end

    return characterName
end

function Mod:RegisterRuntimeEvent(eventName, methodName)
    if type(eventName) ~= "string" or eventName == "" then
        return
    end
    self.runtimeEventHandlers = self.runtimeEventHandlers or {}
    self.runtimeEventHandlers[eventName] = methodName

    if self.runtimeEventFrameRegistered and self.runtimeEventFrame and self.runtimeEventFrame.RegisterEvent then
        pcall(self.runtimeEventFrame.RegisterEvent, self.runtimeEventFrame, eventName)
    end
end

function Mod:UnregisterRuntimeEvent(eventName)
    if type(eventName) ~= "string" or eventName == "" then
        return
    end

    if self.runtimeEventHandlers then
        self.runtimeEventHandlers[eventName] = nil
    end

    if self.runtimeEventFrame and self.runtimeEventFrame.UnregisterEvent then
        pcall(self.runtimeEventFrame.UnregisterEvent, self.runtimeEventFrame, eventName)
    end
end

function Mod:UnregisterAllRuntimeEvents()
    if self.runtimeEventFrame and self.runtimeEventFrame.UnregisterAllEvents then
        self.runtimeEventFrame:UnregisterAllEvents()
    end
    self.runtimeEventFrameRegistered = false

    if self.runtimeEventHandlers then
        wipe(self.runtimeEventHandlers)
    end
    if self.pendingRuntimeEvents then
        wipe(self.pendingRuntimeEvents)
    end
    if self.runtimeEventRegisterTimer and self.runtimeEventRegisterTimer.Cancel then
        self.runtimeEventRegisterTimer:Cancel()
    end
    self.runtimeEventRegisterTimer = nil
end

function Mod:TryFlushPendingRuntimeEvents()
    self.pendingRuntimeEvents = nil
end

function Mod:RequestRenderedMirror()
    self.pendingRenderedMirrors = (self.pendingRenderedMirrors or 0) + 1
end

function Mod:RequestSecretMirror(metadata)
    self.pendingSecretMirrors = (self.pendingSecretMirrors or 0) + 1
    self.pendingSecretMirrorEntries = self.pendingSecretMirrorEntries or {}
    tinsert(self.pendingSecretMirrorEntries, metadata or {})
end

function Mod:EnsureRuntimeEventFrame()
    if self.runtimeEventFrame then
        return
    end

    local frame = _G.CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, ...)
        if not (Mod and Mod.runtimeEventHandlers and Mod.IsEnabled and Mod:IsEnabled()) then
            return
        end

        local handler = Mod.runtimeEventHandlers[event]
        if type(handler) == "string" and type(Mod[handler]) == "function" then
            Mod[handler](Mod, event, ...)
        elseif type(handler) == "function" then
            handler(Mod, event, ...)
        end
    end)

    self.runtimeEventFrame = frame
end

function Mod:ActivateRuntimeEventFrame()
    self:EnsureRuntimeEventFrame()
    if not self.runtimeEventFrame then
        return
    end
    if self.runtimeEventFrameRegistered then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self.runtimeInitializationBlocked = true
        if self.ScheduleFinishEnableRuntime then
            self:ScheduleFinishEnableRuntime(0.5)
        end
        return
    end

    if self.runtimeEventHandlers then
        for eventName in pairs(self.runtimeEventHandlers) do
            self.runtimeEventFrame:RegisterEvent(eventName)
        end
    end

    self.runtimeEventFrameRegistered = true
end

function Mod:ShouldCaptureCombatLog()
    return self:IsCombatTab(self:GetActiveTab())
end

function Mod:UpdateCombatLogRegistration()
    -- Intentionally static. COMBAT_LOG_EVENT_UNFILTERED stays registered on
    -- the module-owned runtime frame, and OnCombatLogEvent early-outs unless
    -- the combat tab is actually active.
end

function Mod:ScheduleRuntimeEventFrameRegistration(delay)
    -- No-op.  The runtime event frame is permanently marked as registered
    -- in OnEnable; no timer-based frame:RegisterEvent() calls are needed.
end

function Mod:HookBlizzardChatEvents()
    if self.blizzardChatEventsHooked or not hooksecurefunc then
        return
    end

    if KT_IsSecureChatSafeMode() then
        self.blizzardChatEventsHooked = true
        return
    end

    local function handleChatFrameEvent(_, event, ...)
        if not (Mod and Mod.runtimeInitialized and Mod.chatEventsRegistered) then
            return
        end

        if not event or not event:find("^CHAT_MSG_", 1, false) then
            return
        end

        if not CHAT_EVENT_LOOKUP[event] then
            if Mod.RequestRenderedMirror then
                Mod:RequestRenderedMirror()
            end
            return
        end

        local payload = { ... }
        C_Timer.After(0, function()
            if Mod and Mod.OnChatEvent and Mod.runtimeInitialized and Mod.chatEventsRegistered then
                Mod:OnChatEvent(event, unpack(payload))
            end
        end)
    end

    if _G.ChatFrame1 and _G.ChatFrame1.HookScript then
        _G.ChatFrame1:HookScript("OnEvent", handleChatFrameEvent)
    end

    self.blizzardChatEventsHooked = true
end

function Mod:ScheduleFinishEnableRuntime(delay)
    if self.runtimeInitialized then
        return
    end

    if self.runtimeInitTimer and self.runtimeInitTimer.Cancel then
        self.runtimeInitTimer:Cancel()
    end

    self.runtimeInitTimer = C_Timer.NewTimer(delay or 0, function()
        if Mod.runtimeInitTimer and Mod.runtimeInitTimer.Cancel then
            Mod.runtimeInitTimer:Cancel()
        end
        Mod.runtimeInitTimer = nil

        if not (Mod and Mod.IsEnabled and Mod:IsEnabled()) then
            return
        end

        if Mod.runtimeInitialized then
            return
        end

        if InCombatLockdown and InCombatLockdown() then
            Mod.runtimeInitializationBlocked = true
            Mod:ScheduleFinishEnableRuntime(0.5)
            return
        end

        Mod.runtimeInitializationBlocked = false

        if Mod.TryFlushPendingRuntimeEvents then
            Mod:TryFlushPendingRuntimeEvents()
        end

        if Mod.FinishEnableRuntime then
            Mod:FinishEnableRuntime()
        end
    end)
end

local function KT_SafeCallback(func, ...)
    return xpcall(func, CallErrorHandler, ...)
end

local function KT_GetPublicAddon()
    _G.KullThranUI = _G.KullThranUI or _G.KT or KT
    return _G.KullThranUI
end

local function KT_IsChattynatorActive()
    if C_AddOns.IsAddOnLoaded(KT_CHATTYNATOR_NAME) and _G.Chattynator and _G.Chattynator.API then
        return _G.Chattynator.API
    end
    return nil
end

local function KT_GetAddonVersionNumber(addonName)
    local versionString = C_AddOns.GetAddOnMetadata(addonName, "Version")
    if type(versionString) ~= "string" then
        return nil
    end

    return tonumber(versionString:match("(%d+)"))
end

KT_SetTooltip = function(widget, text)
    widget:SetScript("OnEnter", function(self)
        if GameTooltip and GameTooltip.ktIcon then
            if GameTooltip.ktIconBorder then GameTooltip.ktIconBorder:Hide() end
            GameTooltip.ktIcon:SetTexture(nil)
            GameTooltip.ktIcon:Hide()
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function KT_IsChattynatorCompatible()
    local versionNumber = KT_GetAddonVersionNumber(KT_CHATTYNATOR_NAME)
    return versionNumber == nil or versionNumber >= KT_CHATTYNATOR_MIN_VERSION
end

local function KT_NormalizePublicSendArgs(first, second, third, fourth, fifth)
    if type(first) == "table" and second ~= nil then
        return second, third, fourth, fifth
    end

    return first, second, third, fourth
end

local function KT_ColorizeMessage(message)
    local r = math.floor(KT_BRAND_COLOR.r * 255 + 0.5)
    local g = math.floor(KT_BRAND_COLOR.g * 255 + 0.5)
    local b = math.floor(KT_BRAND_COLOR.b * 255 + 0.5)
    return format("|cff%02x%02x%02x%s|r", r, g, b, message)
end

KT_ColorizePlayerName = function(name, senderGUID)
    name = KT_GetNonEmptyAccessibleString(name)
    senderGUID = KT_GetNonEmptyAccessibleString(senderGUID)
    if not name or not senderGUID then
        return name
    end

    if not senderGUID:match("^Player") then
        return name
    end

    local _, classTag = GetPlayerInfoByGUID(senderGUID)
    if not classTag then
        return name
    end

    local classColors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS
    local color = classColors and classColors[classTag]
    if not color then
        return name
    end

    local r = math.floor((color.r or 1) * 255 + 0.5)
    local g = math.floor((color.g or 1) * 255 + 0.5)
    local b = math.floor((color.b or 1) * 255 + 0.5)
    return format("|cff%02x%02x%02x%s|r", r, g, b, name)
end

KT_SetTooltip = function(widget, text)
    widget:SetScript("OnEnter", function(self)
        if GameTooltip and GameTooltip.ktIcon then
            if GameTooltip.ktIconBorder then GameTooltip.ktIconBorder:Hide() end
            GameTooltip.ktIcon:SetTexture(nil)
            GameTooltip.ktIcon:Hide()
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text, 1, 1, 1)
        GameTooltip:Show()
    end)
    widget:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function KT_SetButtonBackdrop(button)
    button:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
end

local function KT_StyleActionButton(button)
    KT_SetButtonBackdrop(button)
    button:SetBackdropColor(0.05, 0.05, 0.06, 0.82)
    button:SetBackdropBorderColor(0.14, 0.14, 0.14, 0.95)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetVertexColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 0.16)
    end
end

local function KT_SetActionButtonHighlight(button, color)
    if not button or not color then
        return
    end

    button:SetBackdropBorderColor(color.r, color.g, color.b, 0.2)

    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetVertexColor(color.r, color.g, color.b, 0.18)
    end
end

local function KT_ApplyGradient(texture, orientation, startColor, endColor)
    if not texture then
        return
    end

    local startAlpha = startColor.a or 0
    local endAlpha = endColor.a or 0
    if texture.SetGradientAlpha then
        texture:SetTexture(KT_CHAT_GRADIENT_TEXTURE)
        texture:SetGradientAlpha(
            orientation or "VERTICAL",
            startColor.r or 0, startColor.g or 0, startColor.b or 0, startAlpha,
            endColor.r or 0, endColor.g or 0, endColor.b or 0, endAlpha
        )
    else
        texture:SetColorTexture(startColor.r or 0, startColor.g or 0, startColor.b or 0, math.max(startAlpha, endAlpha))
    end
end

local function KT_SetTabBorderVisual(tab, texturePath, color, alpha)
    if not tab or not tab.KT_SelectedEdges then
        return
    end

    for _, edge in ipairs(tab.KT_SelectedEdges) do
        edge:SetTexture(texturePath)
        edge:SetVertexColor(color.r, color.g, color.b, alpha or 0)
    end
end

local function KT_StyleActionTexture(button, texturePath, useTexCoord)
    local texture = button:CreateTexture(nil, "ARTWORK")
    texture:SetPoint("CENTER")
    texture:SetSize(16, 16)
    texture:SetTexture(texturePath)
    texture:SetVertexColor(0.95, 0.95, 0.98, 0.95)
    if useTexCoord then
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    button.KT_Icon = texture
    return texture
end

local function KT_StyleActionText(button, text, fontSize)
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFont(KT_DEFAULT_FONT, fontSize or 12, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetText(text)
    label:SetTextColor(0.95, 0.95, 0.98, 0.98)
    button.KT_Text = label
    return label
end

local function KT_SanitizeCopyText(text)
    local value = KT_GetAccessibleString(text, "")
    for _, pattern in ipairs(COPY_SUBSTITUTIONS) do
        value = value:gsub(pattern[1], pattern[2])
    end
    return value
end

local function KT_OpenBlizzardChatSettings()
    if InCombatLockdown and InCombatLockdown() then
        if KT and KT.Print then
            KT:Print(KT_LText("Chat settings are unavailable in combat."))
        end
        return
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ChatFrame")
    elseif _G.LoadAddOn then
        pcall(_G.LoadAddOn, "Blizzard_ChatFrame")
    end

    local chatFrame = _G.ChatFrame1 or _G.DEFAULT_CHAT_FRAME
    if _G.FCF_SelectDockFrame and chatFrame then
        pcall(_G.FCF_SelectDockFrame, chatFrame)
    end

    if _G.FCF_OpenChatConfigFrame and chatFrame then
        local ok = pcall(_G.FCF_OpenChatConfigFrame, chatFrame)
        if ok then
            return
        end
    end

    if _G.ChatConfigFrame then
        local ok = pcall(ShowUIPanel, _G.ChatConfigFrame)
        if ok then
            return
        end
    end

    if KT and KT.OpenMenu then
        KT:OpenMenu("chat")
        return
    end

    if KT and KT.ToggleConfig then
        KT:ToggleConfig()
    end
end

local function KT_LoadBlizzardFriendsFrame()
    if _G.FriendsFrame then
        return true
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_FriendsFrame")
    elseif _G.LoadAddOnWithErrorHandling then
        pcall(_G.LoadAddOnWithErrorHandling, "Blizzard_FriendsFrame")
    elseif _G.LoadAddOn then
        pcall(_G.LoadAddOn, "Blizzard_FriendsFrame")
    end

    return _G.FriendsFrame ~= nil
end

local function KT_GetEnhancedFriendList()
    local enhancements = KT and KT.GetModule and KT:GetModule("Enhancements", true)
    local enhancedFriendList = enhancements and enhancements.EnhancedFriendList
    if type(enhancedFriendList) ~= "table" then
        return nil
    end
    return enhancedFriendList
end

local function KT_OpenFriendsList()
    local enhancedFriendList = KT_GetEnhancedFriendList()
    local hasFriendsFrame = KT_LoadBlizzardFriendsFrame()

    if enhancedFriendList and enhancedFriendList.OnAddonLoaded then
        pcall(enhancedFriendList.OnAddonLoaded, enhancedFriendList, "Blizzard_FriendsFrame")
    end

    if _G.ToggleQuickJoinPanel then
        pcall(_G.ToggleQuickJoinPanel)
    elseif _G.ToggleFriendsFrame then
        pcall(_G.ToggleFriendsFrame, 1)
    elseif hasFriendsFrame and _G.FriendsFrame then
        if _G.FriendsFrame.IsShown and _G.FriendsFrame:IsShown() then
            if enhancedFriendList and enhancedFriendList.frame and enhancedFriendList.frame.Hide then
                pcall(enhancedFriendList.frame.Hide, enhancedFriendList.frame)
            end
            if _G.HideUIPanel then
                pcall(_G.HideUIPanel, _G.FriendsFrame)
            elseif _G.FriendsFrame.Hide then
                pcall(_G.FriendsFrame.Hide, _G.FriendsFrame)
            end
        else
            if _G.ShowUIPanel then
                pcall(_G.ShowUIPanel, _G.FriendsFrame)
            elseif _G.FriendsFrame.Show then
                pcall(_G.FriendsFrame.Show, _G.FriendsFrame)
            end
        end
    end
end

local function KT_HideBlizzardChatChromeFrame(frame, moveOffscreen)
    if not frame then
        return
    end

    if moveOffscreen then
        if frame.ClearAllPoints then
            frame:ClearAllPoints()
        end
        if frame.SetPoint then
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -4000, -4000)
        end
    end

    if frame.SetAlpha then
        frame:SetAlpha(0)
    end
    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
    if frame.Hide then
        frame:Hide()
    end

    if frame.HookScript and not frame.KT_HideHooked then
        frame:HookScript("OnShow", function(widget)
            if widget.KT_KeepVisible then
                return
            end
            if moveOffscreen then
                if widget.ClearAllPoints then
                    widget:ClearAllPoints()
                end
                if widget.SetPoint then
                    widget:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -4000, -4000)
                end
            end
            if widget.SetAlpha then
                widget:SetAlpha(0)
            end
            if widget.EnableMouse then
                widget:EnableMouse(false)
            end
            if widget.Hide then
                widget:Hide()
            end
        end)
        frame.KT_HideHooked = true
    end
end

local function KT_HideBlizzardChatNativeChrome()
    KT_HideBlizzardChatChromeFrame(_G.ChatFrame1Tab)
    KT_HideBlizzardChatChromeFrame(_G.ChatFrame1ButtonFrame)
    KT_HideBlizzardChatChromeFrame(_G.GeneralDockManager)

    local numWindows = NUM_CHAT_WINDOWS or 10
    for index = 2, numWindows do
        KT_HideBlizzardChatChromeFrame(_G["ChatFrame" .. index .. "Tab"])
        KT_HideBlizzardChatChromeFrame(_G["ChatFrame" .. index .. "ButtonFrame"])
        KT_HideBlizzardChatChromeFrame(_G["ChatFrame" .. index .. "Background"])
    end
end

local function KT_HideBlizzardChatUtilityButtons()
    local transientFrames = {
        _G.ChatFrameMenuButton,
        _G.ChatFrameToggleVoiceDeafenButton,
        _G.ChatFrameToggleVoiceMuteButton,
        _G.ChatFrameChannelButton,
        _G.FriendsMicroButton,
    }

    for _, frame in ipairs(transientFrames) do
        KT_HideBlizzardChatChromeFrame(frame)
    end
end

local function KT_HideBlizzardChatFrames()
    KT_HideBlizzardChatUtilityButtons()
    KT_HideBlizzardChatNativeChrome()
    if InCombatLockdown and InCombatLockdown() then
        KT_CHAT_HIDE_QUEUED = true
        if not KT_CHAT_HIDE_REGEN_FRAME then
            KT_CHAT_HIDE_REGEN_FRAME = CreateFrame("Frame")
            KT_CHAT_HIDE_REGEN_FRAME:SetScript("OnEvent", function()
                KT_CHAT_HIDE_REGEN_FRAME:UnregisterEvent("PLAYER_REGEN_ENABLED")
                if KT_CHAT_HIDE_QUEUED then
                    KT_CHAT_HIDE_QUEUED = nil
                    KT_HideBlizzardChatFrames()
                end
            end)
        end
        KT_CHAT_HIDE_REGEN_FRAME:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    local primaryChatFrame = _G.ChatFrame1
    if primaryChatFrame then
        if not primaryChatFrame.KT_UseAsPrimary then
            primaryChatFrame:ClearAllPoints()
            primaryChatFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -4000, -4000)
            primaryChatFrame:SetAlpha(0)
            if primaryChatFrame.EnableMouse then
                primaryChatFrame:EnableMouse(false)
            end
            primaryChatFrame:Hide()
        end

        if primaryChatFrame.HookScript and not primaryChatFrame.KT_PrimaryVisibilityHooked then
            primaryChatFrame:HookScript("OnShow", function(widget)
                if widget.KT_UseAsPrimary then
                    widget:SetAlpha(1)
                    if widget.EnableMouse then
                        widget:EnableMouse(true)
                    end
                    return
                end

                widget:SetAlpha(0)
                if widget.EnableMouse then
                    widget:EnableMouse(false)
                end
                widget:Hide()
            end)
            primaryChatFrame.KT_PrimaryVisibilityHooked = true
        end
    end

    local persistentFrames = {
        _G.ChatFrame1Tab,
        _G.ChatFrame1ButtonFrame,
        _G.GeneralDockManager,
    }

    for _, frame in ipairs(persistentFrames) do
        if frame then
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -4000, -4000)
            frame:SetAlpha(0)
            if frame.EnableMouse then
                frame:EnableMouse(false)
            end
            frame:Hide()
            if frame.HookScript and not frame.KT_HideHooked then
                frame:HookScript("OnShow", function(widget)
                    widget:SetAlpha(0)
                    widget:Hide()
                end)
                frame.KT_HideHooked = true
            end
        end
    end

    -- Hide only the standard chat frames (2..NUM_CHAT_WINDOWS).
    -- Temporary whisper frames created beyond that range can carry protected
    -- "secret string" values on retail, and touching them taints Blizzard's
    -- own message handling path.
    local numWindows = NUM_CHAT_WINDOWS or 10
    local index = 2
    while index <= numWindows do
        for _, frame in ipairs({
            _G["ChatFrame" .. index],
            _G["ChatFrame" .. index .. "Tab"],
            _G["ChatFrame" .. index .. "ButtonFrame"],
            _G["DockedChatFrame" .. index],
        }) do
            if frame and not frame.KT_KeepVisible then
                if frame.ClearAllPoints then
                    frame:ClearAllPoints()
                end
                if frame.SetPoint then
                    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -4000, -4000)
                end
                frame:SetAlpha(0)
                if frame.EnableMouse then
                    frame:EnableMouse(false)
                end
                frame:Hide()
                -- Don't permanently hook-hide ChatFrame2: we reuse it for our Combat tab.
                if frame.HookScript and not frame.KT_HideHooked and frame ~= _G.ChatFrame2 then
                    frame:HookScript("OnShow", function(widget)
                        if widget.KT_KeepVisible then
                            return
                        end
                        widget:SetAlpha(0)
                        widget:Hide()
                    end)
                    frame.KT_HideHooked = true
                end
            end
        end
        index = index + 1
    end
end

local function KT_IsGroupChatType(chatType)
    return chatType == "PARTY"
        or chatType == "PARTY_LEADER"
        or chatType == "RAID"
        or chatType == "RAID_LEADER"
        or chatType == "RAID_WARNING"
        or chatType == "INSTANCE_CHAT"
        or chatType == "INSTANCE_CHAT_LEADER"
end

KT_LText = function(text)
    if type(text) ~= "string" then
        return text
    end

    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] then
            return L[text]
        end
    end

    return text
end

local function KT_GetDefaultChatTabConfigs()
    return {
        { id = "general", label = KT_LText("General"), prompt = KT_LText("Say"), command = "", filterMode = "GENERAL", channelMatch = "", hidden = false },
        { id = "combat", label = KT_LText("Combat"), prompt = KT_LText("Combat Log"), command = "", filterMode = "COMBAT", channelMatch = "", hidden = false },
        { id = "trade", label = KT_LText("Trade"), prompt = KT_LText("Trade"), command = "/2 ", filterMode = "CHANNEL", channelMatch = "", hidden = false },
        { id = "guild", label = KT_LText("Guild"), prompt = KT_LText("Guild"), command = "/g ", filterMode = "GUILD", channelMatch = "", hidden = false },
        { id = "group", label = KT_LText("Group"), prompt = KT_LText("Group"), command = "/p ", filterMode = "GROUP", channelMatch = "", hidden = false },
        { id = "whisper", label = KT_LText("Whisp"), prompt = KT_LText("Whisper"), command = "/w ", filterMode = "WHISPER", channelMatch = "", hidden = false },
    }
end

local function KT_CreateDefaultTabs()
    local tabs = {}
    for _, config in ipairs(KT_GetDefaultChatTabConfigs()) do
        tabs[#tabs + 1] = {
            id = config.id,
            label = config.label,
            prompt = config.prompt,
            command = config.command,
            filterMode = config.filterMode,
            channelMatch = config.channelMatch,
        }
    end
    return tabs
end

local function KT_CreateDefaultTabConfigs()
    return KT_GetDefaultChatTabConfigs()
end

local function KT_CopyTabConfig(config)
    return {
        id = config.id,
        label = config.label,
        prompt = config.prompt,
        command = config.command,
        filterMode = config.filterMode,
        channelMatch = config.channelMatch,
        hidden = config.hidden == true,
    }
end

local function KT_NormalizeTabText(value)
    local normalized = strupper(strtrim(tostring(value or "")))
    normalized = normalized:gsub("%s+", " ")
    return normalized
end

local function KT_IsBuiltInTabText(value, aliases)
    local normalized = KT_NormalizeTabText(value)
    if normalized == "" then
        return true
    end

    for _, alias in ipairs(aliases or {}) do
        if normalized == alias then
            return true
        end
    end

    return false
end

local function KT_GetTabRole(config)
    local id = strlower(strtrim(tostring(config and config.id or "")))
    local mode = strupper(strtrim(tostring(config and config.filterMode or "")))

    if id == "general" or mode == "GENERAL" then
        return "general"
    elseif id == "combat" or mode == "COMBAT" then
        return "combat"
    elseif id == "city" or id == "trade" or mode == "CHANNEL" then
        return "trade"
    elseif id == "guild" or mode == "GUILD" then
        return "guild"
    elseif id == "group" or mode == "GROUP" or mode == "PARTY" or mode == "RAID" or mode == "INSTANCE" then
        return "group"
    elseif id == "whisper" or mode == "WHISPER" then
        return "whisper"
    end

    return nil
end

local function KT_ShouldMigrateBuiltInTabs(configs)
    if type(configs) ~= "table" then
        return true
    end

    local second = configs[2]
    if type(second) == "table" then
        local secondRole = KT_GetTabRole(second)
        if secondRole == "trade" then
            return true
        end
    end

    for _, config in ipairs(configs) do
        if KT_GetTabRole(config) == "combat" then
            return false
        end
    end

    return true
end

local function KT_MergeBuiltInTab(existing, template, role)
    local labelAliases = {
        general = { "GENERAL" },
        combat = { "COMBAT", "COMBAT LOG", "REGISTRO DE COMBATE", "COMBATE" },
        trade = { "CITY", "CIUDAD", "TRADE", "COMERCIO" },
        guild = { "GUILD", "HERMANDAD" },
        group = { "GROUP", "GRUPO" },
        whisper = { "WHISP", "WHISPER", "SUSURRO" },
    }
    local promptAliases = {
        general = { "SAY", "DECIR", "GENERAL" },
        combat = { "COMBAT LOG", "REGISTRO DE COMBATE", "COMBATE" },
        trade = { "CITY", "CIUDAD", "TRADE", "COMERCIO" },
        guild = { "GUILD", "HERMANDAD" },
        group = { "GROUP", "GRUPO" },
        whisper = { "WHISPER", "WHISP", "SUSURRO" },
    }

    local merged = KT_CopyTabConfig(template)
    if type(existing) == "table" then
        if not KT_IsBuiltInTabText(existing.label, labelAliases[role]) then
            merged.label = strtrim(tostring(existing.label or merged.label))
        end
        if not KT_IsBuiltInTabText(existing.prompt, promptAliases[role]) then
            merged.prompt = strtrim(tostring(existing.prompt or merged.prompt))
        end
        if existing.command ~= nil then
            merged.command = tostring(existing.command)
        end
        if existing.channelMatch ~= nil then
            merged.channelMatch = strtrim(tostring(existing.channelMatch))
        end
        if existing.hidden ~= nil then
            merged.hidden = existing.hidden == true
        end
    end
    return merged
end

local function KT_MigrateBuiltInTabConfigs(configs)
    local templates = KT_CreateDefaultTabConfigs()
    local byRole = {}

    if type(configs) == "table" then
        for _, config in ipairs(configs) do
            local role = KT_GetTabRole(config)
            if role and not byRole[role] then
                byRole[role] = config
            end
        end
    end

    return {
        KT_MergeBuiltInTab(byRole.general, templates[1], "general"),
        KT_MergeBuiltInTab(byRole.combat, templates[2], "combat"),
        KT_MergeBuiltInTab(byRole.trade, templates[3], "trade"),
        KT_MergeBuiltInTab(byRole.guild, templates[4], "guild"),
        KT_MergeBuiltInTab(byRole.group, templates[5], "group"),
        KT_MergeBuiltInTab(byRole.whisper, templates[6], "whisper"),
    }
end

function Mod:EnsureDB()
    KT.db.profile.chat = KT.db.profile.chat or {
        enable = true,
        maxLines = KT_CHAT_HISTORY_LINES,
        history = {},
        privateWindows = {},
        panelColor = CopyTable(KT_CHAT_DEFAULT_PANEL_COLOR),
        highlightColor = CopyTable(KT_CHAT_DEFAULT_HIGHLIGHT_COLOR),
        tabHighlightTexture = KT_CHAT_DEFAULT_TAB_HIGHLIGHT_TEXTURE,
        font = KT_DEFAULT_FONT_NAME,
        fontSize = 12,
        fontOutline = "OUTLINE",
        classColorNames = true,
        fadeEnabled = true,
        fadeTimeVisible = 24,
        fadeDuration = 8,
        window = {
            visible = true,
            width = KT_CHAT_WINDOW_WIDTH,
            height = KT_CHAT_WINDOW_HEIGHT,
            scale = KT_GetDefaultChatWindowScale(),
            migratedLayoutV10 = true,
            migratedLayoutV11 = true,
            migratedLayoutV12 = true,
            migratedLayoutV13 = true,
            migratedLayoutV14 = true,
            migratedLayoutV15 = true,
        },
    }

    KT.db.profile.chat.window = KT.db.profile.chat.window or {}
    if KT.db.profile.chat.window.visible == nil then
        KT.db.profile.chat.window.visible = true
    end
    if KT.db.profile.chat.window.scale == nil then
        KT.db.profile.chat.window.scale = KT_GetDefaultChatWindowScale()
    end
    KT.db.profile.chat.panelColor = KT.db.profile.chat.panelColor or CopyTable(KT_CHAT_DEFAULT_PANEL_COLOR)
    KT.db.profile.chat.highlightColor = KT.db.profile.chat.highlightColor or CopyTable(KT_CHAT_DEFAULT_HIGHLIGHT_COLOR)
    KT.db.profile.chat.tabHighlightTexture = KT.db.profile.chat.tabHighlightTexture or KT_CHAT_DEFAULT_TAB_HIGHLIGHT_TEXTURE
    KT.db.profile.chat.history = type(KT.db.profile.chat.history) == "table" and KT.db.profile.chat.history or {}
    KT.db.profile.chat.privateWindows = type(KT.db.profile.chat.privateWindows) == "table" and KT.db.profile.chat.privateWindows or {}
    KT.db.profile.chat.font = KT.db.profile.chat.font or KT_DEFAULT_FONT_NAME
    KT.db.profile.chat.fontSize = KT.db.profile.chat.fontSize or 12
    local chatFontOutline = tostring(KT.db.profile.chat.fontOutline or "")
    if chatFontOutline ~= "OUTLINE" and chatFontOutline ~= "NONE" and chatFontOutline ~= "THICKOUTLINE" then
        chatFontOutline = "OUTLINE"
    end
    KT.db.profile.chat.fontOutline = chatFontOutline
    if KT.db.profile.chat.classColorNames == nil then
        KT.db.profile.chat.classColorNames = true
    end
    KT.db.profile.chat.tabConfigs = KT.db.profile.chat.tabConfigs or KT_CreateDefaultTabConfigs()
    if KT.db.profile.chat.migratedTabLayoutV16 ~= true or KT_ShouldMigrateBuiltInTabs(KT.db.profile.chat.tabConfigs) then
        KT.db.profile.chat.tabConfigs = KT_MigrateBuiltInTabConfigs(KT.db.profile.chat.tabConfigs)
        KT.db.profile.chat.migratedTabLayoutV16 = true
    end
    if KT.db.profile.chat.migratedFontSizeV17 ~= true then
        KT.db.profile.chat.fontSize = 12
        KT.db.profile.chat.migratedFontSizeV17 = true
    end
    if KT.db.profile.chat.fadeEnabled == nil then
        KT.db.profile.chat.fadeEnabled = true
    end
    KT.db.profile.chat.fadeTimeVisible = KT.db.profile.chat.fadeTimeVisible or 24
    KT.db.profile.chat.fadeDuration = KT.db.profile.chat.fadeDuration or 8
    if not KT.db.profile.chat.window.migratedLayoutV10 then
        KT.db.profile.chat.window.width = KT_CHAT_WINDOW_WIDTH
        KT.db.profile.chat.window.height = KT_CHAT_WINDOW_HEIGHT
        KT.db.profile.chat.window.migratedLayoutV10 = true

        KT.db.profile.editMode = KT.db.profile.editMode or {}
        KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}
        local saved = KT.db.profile.editMode.frames[KT_CHAT_DB_KEY]
        if saved and saved.point then
            saved.x = (saved.x or 0) + 15
            saved.y = (saved.y or 0) - 55
        end
    end

    if not KT.db.profile.chat.window.migratedLayoutV11 then
        KT.db.profile.editMode = KT.db.profile.editMode or {}
        KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}

        local saved = KT.db.profile.editMode.frames[KT_CHAT_DB_KEY]
        if saved and saved.point then
            saved.y = (saved.y or 0) - 10
        end

        local panelColor = KT.db.profile.chat.panelColor
        if type(panelColor) == "table" and (panelColor.a == nil or KT_IsApproxEqual(panelColor.a, 0.72) or KT_IsApproxEqual(panelColor.a, 0.9) or KT_IsApproxEqual(panelColor.a, 0.25)) then
            panelColor.a = KT_CHAT_DEFAULT_PANEL_COLOR.a
        end

        KT.db.profile.chat.window.migratedLayoutV11 = true
    end

    if not KT.db.profile.chat.window.migratedLayoutV12 then
        KT.db.profile.editMode = KT.db.profile.editMode or {}
        KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}

        local saved = KT.db.profile.editMode.frames[KT_CHAT_DB_KEY]
        if saved and saved.point then
            saved.y = (saved.y or 0) - 5
        end

        KT.db.profile.chat.window.migratedLayoutV12 = true
    end

    if not KT.db.profile.chat.window.migratedLayoutV13 then
        local panelColor = KT.db.profile.chat.panelColor
        if type(panelColor) == "table" and (panelColor.a == nil or KT_IsApproxEqual(panelColor.a, 0)) then
            panelColor.a = KT_CHAT_DEFAULT_PANEL_COLOR.a
        end

        KT.db.profile.chat.window.migratedLayoutV13 = true
    end

    if not KT.db.profile.chat.window.migratedLayoutV14 then
        local panelColor = KT.db.profile.chat.panelColor
        if type(panelColor) == "table" and (panelColor.a == nil or KT_IsApproxEqual(panelColor.a, 0.9)) then
            panelColor.a = KT_CHAT_DEFAULT_PANEL_COLOR.a
        end

        KT.db.profile.chat.window.migratedLayoutV14 = true
    end

    if not KT.db.profile.chat.window.migratedLayoutV15 then
        KT.db.profile.editMode = KT.db.profile.editMode or {}
        KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}

        local saved = KT.db.profile.editMode.frames[KT_CHAT_DB_KEY]
        if saved and saved.point then
            saved.y = (saved.y or 0) - 5
        end

        KT.db.profile.chat.window.migratedLayoutV15 = true
    end

    KT.db.profile.chat.window.width = KT.db.profile.chat.window.width or KT_CHAT_WINDOW_WIDTH
    KT.db.profile.chat.window.height = KT.db.profile.chat.window.height or KT_CHAT_WINDOW_HEIGHT
    if type(KT.db.profile.chat.window.width) == "number" then
        KT.db.profile.chat.window.width = math.max(KT_CHAT_WINDOW_MIN_WIDTH, KT.db.profile.chat.window.width)
    end
    if type(KT.db.profile.chat.window.height) == "number" then
        KT.db.profile.chat.window.height = math.max(KT_CHAT_WINDOW_MIN_HEIGHT, KT.db.profile.chat.window.height)
    end
    KT.db.profile.chat.maxLines = KT.db.profile.chat.maxLines or KT_CHAT_HISTORY_LINES

    local defaults = KT_CreateDefaultTabConfigs()
    local configs = {}
    for index = 1, 6 do
        local source = KT.db.profile.chat.tabConfigs[index] or defaults[index]
        local fallback = defaults[index]
        local label = strtrim(tostring((source and source.label) or fallback.label or ("Tab " .. index)))
        local prompt = strtrim(tostring((source and source.prompt) or fallback.prompt or label))
        local command = tostring((source and source.command) or fallback.command or "")
        local filterMode = strupper(tostring((source and source.filterMode) or fallback.filterMode or "ALL"))
        local channelMatch = strtrim(tostring((source and source.channelMatch) or fallback.channelMatch or ""))
        local hidden = (source and source.hidden) == true

        configs[index] = {
            id = fallback.id or ("slot" .. index),
            label = label ~= "" and label or fallback.label or ("Tab " .. index),
            prompt = prompt ~= "" and prompt or label or fallback.prompt or ("Tab " .. index),
            command = command,
            filterMode = filterMode,
            channelMatch = channelMatch,
            hidden = hidden,
        }
    end
    KT.db.profile.chat.tabConfigs = configs

    self.db = KT.db.profile.chat
end
function Mod:BuildSearchText(parts)
    local normalized = {}

    for _, value in ipairs(parts or {}) do
        local text = KT_GetAccessibleString(value, nil)
        if type(text) == "string" then
            text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
            text = text:gsub("|r", "")
            text = text:gsub("|H.-|h(.-)|h", "%1")
            text = text:gsub("|T.-|t", " ")
            text = text:gsub("|A.-|a", " ")
            text = strtrim(text)
            if text ~= "" then
                normalized[#normalized + 1] = strlower(text)
            end
        end
    end

    return table.concat(normalized, " ")
end


function Mod:SanitizeHistoryEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local persist = entry.persist ~= false
    local rawMessage = KT_GetAccessibleString(entry.rawMessage, nil)
    local message = KT_GetAccessibleString(entry.message, rawMessage)
    local chatType = KT_GetAccessibleString(entry.chatType, nil)
    local event = KT_GetAccessibleString(entry.event, nil)

    if type(message) ~= "string" or message == "" then
        return nil
    end

    local sanitized = {
        preformatted = entry.preformatted == true or nil,
        persist = persist and true or false,
        message = message,
        rawMessage = rawMessage or message,
        r = type(entry.r) == "number" and entry.r or 1,
        g = type(entry.g) == "number" and entry.g or 1,
        b = type(entry.b) == "number" and entry.b or 1,
        event = event,
        chatType = chatType,
        timestamp = KT_GetAccessibleString(entry.timestamp, ""),
        label = KT_GetAccessibleString(entry.label, ""),
        channelName = KT_GetAccessibleString(entry.channelName, nil),
        author = KT_GetAccessibleString(entry.author, nil),
        authorRaw = KT_GetAccessibleString(entry.authorRaw, nil),
        authorFull = KT_GetAccessibleString(entry.authorFull, nil),
        senderGUID = KT_GetAccessibleString(entry.senderGUID, nil),
        lineID = type(entry.lineID) == "number" and entry.lineID or nil,
        bnSenderID = type(entry.bnSenderID) == "number" and entry.bnSenderID or nil,
        whisperTarget = KT_GetAccessibleString(entry.whisperTarget, nil),
        whisperThreadKey = KT_GetAccessibleString(entry.whisperThreadKey, nil),
    }

    sanitized.searchText = self:BuildSearchText({
        sanitized.timestamp,
        sanitized.label,
        sanitized.channelName,
        sanitized.author,
        sanitized.rawMessage,
    })

    if type(sanitized.chatType) ~= "string" or sanitized.chatType == "" then
        sanitized.chatType = sanitized.preformatted and "MIRROR" or "SYSTEM"
    end

    return sanitized
end

function Mod:PersistHistory()
    if not (self and self.db) then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    self.db.history = self.db.history or {}
    wipe(self.db.history)

    local maxLines = self.db.maxLines or KT_CHAT_HISTORY_LINES
    local startIndex = math.max(1, (#self.history or 0) - maxLines + 1)
    for index = startIndex, #self.history do
        local sanitized = self:SanitizeHistoryEntry(self.history[index])
        if sanitized and sanitized.persist ~= false then
            tinsert(self.db.history, sanitized)
        end
    end
end

function Mod:LoadPersistedHistory()
    self.history = {}

    local stored = self.db and self.db.history
    if type(stored) ~= "table" then
        return
    end

    for _, entry in ipairs(stored) do
        local sanitized = self:SanitizeHistoryEntry(entry)
        if sanitized then
            tinsert(self.history, sanitized)
        end
    end

    local maxLines = self.db and self.db.maxLines or KT_CHAT_HISTORY_LINES
    while #self.history > maxLines do
        tremove(self.history, 1)
    end
end

function Mod:PersistPrivateChatState()
    if not (self and self.db) then
        return
    end

    self.db.privateWindows = self.db.privateWindows or {}
    local state = self.db.privateWindows
    state.targets = {}

    local function serializeTarget(data)
        if type(data) ~= "table" then
            return nil
        end

        local bnetIDAccount = type(data.bnetIDAccount) == "number" and data.bnetIDAccount or nil
        local isBNet = KT_IsBNetWhisperKind(data.chatType, bnetIDAccount)
        local target = KT_GetNonEmptyAccessibleString(data.target)

        if isBNet and bnetIDAccount then
            local threadKey = KT_GetWhisperTargetKey(target, "BN_WHISPER", bnetIDAccount)
            if threadKey then
                return {
                    target = target,
                    chatType = "BN_WHISPER",
                    bnetIDAccount = bnetIDAccount,
                    threadKey = threadKey,
                }
            end
        elseif target and not KT_IsSecretWhisperTarget(target) then
            local threadKey = KT_GetWhisperTargetKey(target, "WHISPER", nil)
            if threadKey then
                return {
                    target = target,
                    chatType = "WHISPER",
                    threadKey = threadKey,
                }
            end
        end

        return nil
    end

    for _, data in ipairs(self.whisperTargets or {}) do
        local saved = serializeTarget(data)
        if saved then
            tinsert(state.targets, saved)
        end
    end

    state.active = serializeTarget(self.selectedWhisperThread)
end

function Mod:LoadPersistedPrivateChatState()
    self.whisperTargets = {}
    self.whisperTargetLookup = {}

    local state = self.db and self.db.privateWindows
    if type(state) ~= "table" then
        return
    end

    local function restoreTarget(data, makeActive)
        if type(data) ~= "table" then
            return
        end

        local bnetIDAccount = type(data.bnetIDAccount) == "number" and data.bnetIDAccount or nil
        local isBNet = KT_IsBNetWhisperKind(data.chatType, bnetIDAccount)
        local target = KT_GetNonEmptyAccessibleString(data.target)

        if isBNet and bnetIDAccount then
            target = target or KT_ResolveBNetWhisperTarget(bnetIDAccount) or KT_BNET_PLACEHOLDER
        end

        if target and (isBNet or not KT_IsSecretWhisperTarget(target)) then
            self:AddWhisperTarget(target, isBNet and "BN_WHISPER" or "WHISPER", makeActive, bnetIDAccount, true)
        end
    end

    for index = #(state.targets or {}), 1, -1 do
        restoreTarget(state.targets[index], false)
    end

    restoreTarget(state.active, true)
end
function Mod:IsPrivateChatEntry(entry)
    if type(entry) ~= "table" then
        return false
    end

    local chatType = tostring(entry.chatType or "")
    return chatType:find("WHISPER", 1, true) ~= nil
        or entry.whisperTarget ~= nil
        or entry.whisperThreadKey ~= nil
end

function Mod:ClearPrivateChatSession()
    self.whisperTargets = {}
    self.whisperTargetLookup = {}
    self.activeWhisperTarget = nil
    self.activeWhisperBNetAccountID = nil
    self.selectedWhisperThread = nil

    if self.db then
        self.db.privateWindows = {}
    end

    local retainedHistory = {}
    for _, entry in ipairs(self.history or {}) do
        if not self:IsPrivateChatEntry(entry) then
            tinsert(retainedHistory, entry)
        end
    end
    self.history = retainedHistory
    self:PersistHistory()
    self:RefreshWhisperStrip()
    self:RenderAllFrames()
    self:RefreshChatFrameMode()
end

function Mod:PushHistory(entry)
    local sanitized = self:SanitizeHistoryEntry(entry)
    if not sanitized then
        return nil
    end

    self.history = self.history or {}
    local lastEntry = self.history[#self.history]
    if lastEntry and KT_IsStructuredChatDuplicate(lastEntry, sanitized) then
        return lastEntry
    end

    tinsert(self.history, sanitized)

    local maxLines = (self.db and self.db.maxLines) or KT_CHAT_HISTORY_LINES
    while #self.history > maxLines do
        tremove(self.history, 1)
    end

    self:PersistHistory()
    return sanitized
end

function Mod:HandleIncomingEntry(entry)
    local pushed = self:PushHistory(entry)
    if not pushed then
        return nil
    end

    self:RecordChatActivity()
    local chatType = tostring(pushed.chatType or entry.chatType or "")
    local isIncomingWhisper = chatType == "WHISPER" or chatType == "BN_WHISPER"
    -- Incoming private messages must surface the KUI chat window so the
    -- conversation button created by AddWhisperTarget is immediately visible.
    -- Normal chat traffic and outgoing whispers only wake the existing window.
    self:ShowWindowForActivity(isIncomingWhisper)
    self:AddEntryToFrames(pushed)
    self:ScheduleWindowFade()
    self:UpdateScrollButtonVisibility()
    return pushed
end

function Mod:GetHighlightColor()
    return self.db.highlightColor or KT_CHAT_DEFAULT_HIGHLIGHT_COLOR
end

function Mod:GetResolvedFont()
    local fontName = self.db.font or KT_DEFAULT_FONT_NAME
    local fontPath = KT_DEFAULT_FONT

    if LSM and LSM.Fetch then
        local fetched = LSM:Fetch("font", fontName, true)
        if fetched then
            fontPath = fetched
        end
    end

    local fontOutline = tostring(self.db.fontOutline or "")
    if fontOutline ~= "OUTLINE" and fontOutline ~= "NONE" and fontOutline ~= "THICKOUTLINE" then
        fontOutline = "OUTLINE"
    end

    return fontPath, self.db.fontSize or 12, fontOutline
end

function Mod:ApplyConfiguredFontToFrame(frame, fontPath, fontSize, fontOutline)
    if not frame then
        return
    end

    if not fontPath or not fontSize or not fontOutline then
        fontPath, fontSize, fontOutline = self:GetResolvedFont()
    end

    if frame.SetMaxLines then
        frame:SetMaxLines(self.db.maxLines or KT_CHAT_HISTORY_LINES)
    end

    -- Native Blizzard chat frames persist their text size separately from the
    -- current font object. If we only call SetFont(), Blizzard can restore the
    -- old saved size on reload or another addon can push the old size back in.
    -- Persist the window size directly, then reapply the KUI font styling.
    if _G.SetChatWindowSize and frame.GetID then
        local ok, id = pcall(frame.GetID, frame)
        if ok and type(id) == "number" and id > 0 then
            pcall(_G.SetChatWindowSize, id, fontSize)
        end
    end

    if frame.SetFont then
        pcall(frame.SetFont, frame, fontPath, fontSize, fontOutline)
    end

    self:ApplyFrameFading(frame)
end

function Mod:RefreshManagedChatFrames()
    local fontPath, fontSize, fontOutline = self:GetResolvedFont()

    for _, frame in ipairs(self.messageFrames or {}) do
        self:ApplyConfiguredFontToFrame(frame, fontPath, fontSize, fontOutline)
    end

    -- KUI now displays Blizzard's live chat frames inside our chrome, so the
    -- native frames also need to receive font/max-lines updates from the KUI
    -- options panel.
    self:ApplyConfiguredFontToFrame(_G.ChatFrame1, fontPath, fontSize, fontOutline)
    self:ApplyConfiguredFontToFrame(_G.ChatFrame2, fontPath, fontSize, fontOutline)

    for _, frame in pairs(self.nativeTabFrames or {}) do
        self:ApplyConfiguredFontToFrame(frame, fontPath, fontSize, fontOutline)
    end

    if _G.ChatFrame1EditBox then
        self:AttachBlizzardEditBox()
    end
end

function Mod:GetTabHighlightTexture()
    return self.db.tabHighlightTexture or KT_CHAT_DEFAULT_TAB_HIGHLIGHT_TEXTURE
end

function Mod:GetTabTextColor(tabId)
    local key = strupper(strtrim(tostring(tabId or "")))

    if key == "GENERAL" then
        return 1, 0.82, 0.12
    elseif key == "COMBAT" then
        return 1, 0.42, 0.16
    elseif key == "CITY" or key == "TRADE" or key == "CHANNEL" then
        local info = ChatTypeInfo.CHANNEL or {}
        return info.r or 1, info.g or 0.75, info.b or 0.25
    elseif key == "GUILD" or key == "OFFICER" then
        local info = ChatTypeInfo.GUILD or {}
        return info.r or 0.25, info.g or 1, info.b or 0.25
    elseif key == "GROUP" or key == "PARTY" or key == "RAID" or key == "INSTANCE" then
        local info = ChatTypeInfo.PARTY or {}
        return info.r or 0.66, info.g or 0.66, info.b or 1
    elseif key == "WHISPER" then
        local info = ChatTypeInfo.WHISPER or {}
        return info.r or 1, info.g or 0.5, info.b or 1
    end

    return 0.9, 0.9, 0.95
end
function Mod:BuildTabFilter(config)
    local mode = strupper(tostring(config and config.filterMode or "ALL"))
    local channelMatch = strlower(strtrim(tostring(config and config.channelMatch or "")))

    if mode == "GENERAL" then
        return function(entry)
            return entry ~= nil and entry.chatType ~= "COMBAT"
        end
    elseif mode == "COMBAT" then
        return function(entry)
            return entry.chatType == "COMBAT"
        end
    elseif mode == "CHANNEL" then
        return function(entry)
            if entry.chatType ~= "CHANNEL" and entry.chatType ~= "COMMUNITIES_CHANNEL" then
                return false
            end
            if channelMatch == "" then
                return true
            end
            local haystack = strlower(tostring(entry.channelName or entry.label or ""))
            return strfind(haystack, channelMatch, 1, true) ~= nil
        end
    elseif mode == "GUILD" then
        return function(entry)
            return entry.chatType == "GUILD" or entry.chatType == "OFFICER"
        end
    elseif mode == "GROUP" then
        return function(entry)
            return KT_IsGroupChatType(entry.chatType)
        end
    elseif mode == "WHISPER" then
        return function(entry)
            local chatType = tostring(entry.chatType or "")
            local isWhisperEntry = chatType:find("WHISPER") ~= nil

            if not isWhisperEntry then
                return false
            end

            local selectedThread = self.selectedWhisperThread
            if not selectedThread then
                return true
            end

            return KT_DoesEntryMatchWhisperThread(entry, selectedThread)
        end
    elseif mode == "PARTY" then
        return function(entry)
            return entry.chatType == "PARTY" or entry.chatType == "PARTY_LEADER"
        end
    elseif mode == "RAID" then
        return function(entry)
            return entry.chatType == "RAID" or entry.chatType == "RAID_LEADER" or entry.chatType == "RAID_WARNING"
        end
    elseif mode == "INSTANCE" then
        return function(entry)
            return entry.chatType == "INSTANCE_CHAT" or entry.chatType == "INSTANCE_CHAT_LEADER"
        end
    elseif mode == "SYSTEM" then
        return function(entry)
            return entry.chatType == "SYSTEM" or entry.chatType == "MONEY" or entry.chatType == "CURRENCY"
        end
    elseif mode == "LOOT" then
        return function(entry)
            return entry.chatType == "LOOT"
        end
    elseif mode == "SAY" then
        return function(entry)
            return entry.chatType == "SAY" or entry.chatType == "YELL" or entry.chatType == "EMOTE"
        end
    end

    return function()
        return true
    end
end

function Mod:BuildConfiguredTabs()
    local tabs = {}
    for index, config in ipairs(self.db.tabConfigs or {}) do
        if config.hidden ~= true and strtrim(tostring(config.label or "")) ~= "" then
            tabs[#tabs + 1] = {
                id = config.id or ("slot" .. index),
                label = config.label,
                prompt = config.prompt,
                command = config.command,
                filterMode = config.filterMode,
                channelMatch = config.channelMatch,
                filter = self:BuildTabFilter(config),
            }
        end
    end
    return tabs
end

function Mod:ApplyFrameFading(frame)
    if not frame then
        return
    end

    local enabled = self.db and self.db.fadeEnabled ~= false
    frame:SetFading(enabled)
    if frame.SetTimeVisible then frame:SetTimeVisible((self.db and self.db.fadeTimeVisible) or 24) end
    if frame.SetFadeDuration then frame:SetFadeDuration((self.db and self.db.fadeDuration) or 8) end
end

function Mod:RecordChatActivity()
    self.lastChatActivityAt = GetTime and GetTime() or 0
end

function Mod:CancelWindowFade()
    if self.windowFadeTimer and self.windowFadeTimer.Cancel then
        self.windowFadeTimer:Cancel()
    end
    self.windowFadeTimer = nil
    if self.windowAlphaFadeTicker and self.windowAlphaFadeTicker.Cancel then
        self.windowAlphaFadeTicker:Cancel()
    end
    self.windowAlphaFadeTicker = nil
end

function Mod:StartWindowAlphaFade(window, targetAlpha, duration)
    if not window then return end
    if self.windowAlphaFadeTicker and self.windowAlphaFadeTicker.Cancel then
        self.windowAlphaFadeTicker:Cancel()
    end
    self.windowAlphaFadeTicker = nil

    local fromAlpha = window:GetAlpha() or 1
    duration = math.max(0, tonumber(duration) or 0)
    if duration == 0 or not (C_Timer and C_Timer.NewTicker and GetTime) then
        window:SetAlpha(targetAlpha)
        return
    end

    local startedAt = GetTime()
    local ticker
    ticker = C_Timer.NewTicker(0.03, function()
        if window ~= _G.KT_ChatWindow then
            if ticker then ticker:Cancel() end
            self.windowAlphaFadeTicker = nil
            return
        end

        local progress = math.min(1, math.max(0, (GetTime() - startedAt) / duration))
        window:SetAlpha(fromAlpha + ((targetAlpha - fromAlpha) * progress))
        if progress >= 1 then
            if ticker then ticker:Cancel() end
            self.windowAlphaFadeTicker = nil
        end
    end)
    self.windowAlphaFadeTicker = ticker
end

function Mod:ShowWindowForActivity(forceVisible)
    local window = self:CreateNativeWindow()
    if not window then
        return
    end

    self:CancelWindowFade()
    -- Fades keep the window shown and animate only alpha. A real Show() is
    -- reserved for explicit visibility changes outside combat.
    if forceVisible ~= false and not (InCombatLockdown and InCombatLockdown()) then
        window:Show()
    end
    self:StartWindowAlphaFade(window, 1, 0.15)

    if forceVisible ~= false then
        self.db.window.visible = true
    end
end

function Mod:ScheduleWindowFade()
    local window = _G.KT_ChatWindow
    local editBox = _G.ChatFrame1EditBox
    if not window or self.db.fadeEnabled == false or self.db.window.visible == false then
        return
    end
    if editBox and editBox:IsShown() then
        return
    end

    local lastActivityAt = self.lastChatActivityAt or 0
    local fadeDelay = self.db.fadeTimeVisible or 24
    local elapsed = (GetTime and GetTime() or 0) - lastActivityAt
    local remaining = fadeDelay - elapsed

    self:CancelWindowFade()
    self.windowFadeTimer = C_Timer.NewTimer(math.max(0, remaining), function()
        local liveWindow = _G.KT_ChatWindow
        local liveEditBox = _G.ChatFrame1EditBox
        if not liveWindow or self.db.fadeEnabled == false or self.db.window.visible == false then
            return
        end
        if liveEditBox and liveEditBox:IsShown() then
            return
        end

        self:StartWindowAlphaFade(liveWindow, 0, self.db.fadeDuration or 8)
    end)
end
function Mod:RegisterPopups()
    if not StaticPopupDialogs[KT_COPY_POPUP_KEY] then
        StaticPopupDialogs[KT_COPY_POPUP_KEY] = {
            text = KT_LText("Copy Chat"),
            button1 = CLOSE or "Close",
            hasEditBox = true,
            editBoxWidth = 360,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            OnShow = function(dialog, data)
                local textRegion = dialog.text or dialog.Text
                if textRegion then
                    textRegion:SetText(KT_LText("Copy Chat"))
                end
                local editBox = dialog.editBox or dialog.EditBox
                if editBox then
                    editBox:SetText(type(data) == "table" and tostring(data.text or "") or "")
                    editBox:SetFocus()
                    editBox:HighlightText()
                end
            end,
            EditBoxOnEscapePressed = function(editBox)
                editBox:GetParent():Hide()
            end,
        }
    end

    if not StaticPopupDialogs[KT_SEARCH_POPUP_KEY] then
        StaticPopupDialogs[KT_SEARCH_POPUP_KEY] = {
            text = KT_LText("Search Chat"),
            button1 = SEARCH,
            button2 = CANCEL,
            hasEditBox = true,
            maxLetters = 255,
            editBoxWidth = 240,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
            OnShow = function(dialog, data)
                local title = KT_LText("Search Chat")
                if type(data) == "table" and data.title and data.title ~= "" then
                    title = data.title
                end
                local textRegion = dialog.text or dialog.Text
                if not textRegion and dialog.GetName then
                    textRegion = _G[dialog:GetName() .. "Text"]
                end
                if textRegion then
                    textRegion:SetText(title)
                end
                local editBox = dialog.editBox or dialog.EditBox
                if editBox then
                    editBox:SetText("")
                    editBox:SetFocus()
                    editBox:HighlightText()
                end
            end,
            OnAccept = function(dialog, data)
                local editBox = dialog.editBox or dialog.EditBox
                if type(data) == "table" and data.handler and editBox then
                    data.handler(editBox:GetText())
                end
            end,
            EditBoxOnEscapePressed = function(editBox)
                editBox:GetParent():Hide()
            end,
            EditBoxOnEnterPressed = function(editBox)
                local dialog = editBox:GetParent()
                local data = dialog.data
                if type(data) == "table" and data.handler then
                    data.handler(editBox:GetText())
                end
                dialog:Hide()
            end,
        }
    end
end

function Mod:ResetTabs()
    self.tabs = self:BuildConfiguredTabs()
    if not self.tabs or #self.tabs == 0 then
        if self.db and type(self.db.tabConfigs) == "table" and type(self.db.tabConfigs[1]) == "table" then
            self.db.tabConfigs[1].hidden = false
            self.tabs = self:BuildConfiguredTabs()
        end
    end
    if not self.tabs or #self.tabs == 0 then
        self.db.tabConfigs = KT_CreateDefaultTabConfigs()
        self.tabs = self:BuildConfiguredTabs()
    end
    if not self.selectedTabIndex or self.selectedTabIndex < 1 or self.selectedTabIndex > #self.tabs then
        self.selectedTabIndex = 1
    end
end

function Mod:GetActiveTab()
    if not self.tabs or #self.tabs == 0 then
        self:ResetTabs()
    end
    return self.tabs[self.selectedTabIndex or 1]
end

function Mod:IsCombatTab(tab)
    return tab ~= nil and (tab.filterMode == "COMBAT" or tab.id == "combat")
end

function Mod:IsBlizzardPrimaryTab(tab)
    if not tab then
        return false
    end

    local id = strlower(strtrim(tostring(tab.id or "")))
    local mode = strupper(strtrim(tostring(tab.filterMode or "")))

    return mode == "GENERAL" or id == "general"
end

function Mod:GetDedicatedNativeTabRole(tab)
    if not tab then
        return nil
    end

    local id = strlower(strtrim(tostring(tab.id or "")))
    local mode = strupper(strtrim(tostring(tab.filterMode or "")))

    if id == "trade" or mode == "CHANNEL" then
        return "trade"
    elseif id == "guild" or mode == "GUILD" then
        return "guild"
    elseif id == "group" or mode == "GROUP" or mode == "PARTY" or mode == "RAID" or mode == "INSTANCE" then
        return "group"
    elseif id == "whisper" or mode == "WHISPER" then
        return "whisper"
    end

    return nil
end

function Mod:GetActiveDedicatedNativeTabRole(tab)
    local role = self:GetDedicatedNativeTabRole(tab)

    -- On secure-chat builds whispers are mirrored from Blizzard's already
    -- rendered whisper frame into KUI history. Keeping the native frame as
    -- the visible Whisp tab would bypass KUI's per-conversation filter.
    if role == "whisper" and KT_IsSecureChatSafeMode() then
        return nil
    end

    return role
end
function Mod:IsCommandOnlyText(text)
    local value = strtrim(text or "")
    if value == "" then
        return true
    end

    if not value:find("^/") then
        return false
    end

    local command, remainder = value:match("^(%S+)%s*(.-)%s*$")
    if not command then
        return false
    end

    if remainder == "" then
        return true
    end

    for _, tab in ipairs(self.tabs or {}) do
        local tabCommand = strtrim(tab.command or "")
        if tabCommand ~= "" and strlower(command) == strlower(strtrim(tabCommand)) and remainder == "" then
            return true
        end
    end

    return false
end

function Mod:RemoveTemporaryTabs()
    if not self.tabs then
        return
    end

    for index = #self.tabs, 1, -1 do
        if self.tabs[index].temporary then
            tremove(self.tabs, index)
            if self.selectedTabIndex and self.selectedTabIndex > index then
                self.selectedTabIndex = self.selectedTabIndex - 1
            elseif self.selectedTabIndex == index then
                self.selectedTabIndex = math.max(1, index - 1)
            end
        end
    end

    if not self.selectedTabIndex or self.selectedTabIndex < 1 then
        self.selectedTabIndex = 1
    end
end

function Mod:AddTemporarySearchTab(query)
    local text = strtrim(query or "")
    if text == "" then
        return
    end

    self:RemoveTemporaryTabs()

    local activeTab = self:GetActiveTab()
    local baseFilter = activeTab and activeTab.filter
    local queryLower = strlower(text)
    local insertIndex = math.min(#self.tabs + 1, (self.selectedTabIndex or 1) + 1)

    tinsert(self.tabs, insertIndex, {
        id = "search",
        label = KT_LText("Search"),
        prompt = activeTab and activeTab.prompt or KT_LText("Search"),
        command = activeTab and activeTab.command or "",
        temporary = true,
        tooltip = format(KT_LText("Search: %s"), text),
        filter = function(entry)
            if baseFilter and not baseFilter(entry) then
                return false
            end
            return strfind(entry.searchText or "", queryLower, 1, true) ~= nil
        end,
    })

    self.selectedTabIndex = insertIndex
    self:RefreshTabButtons()
    self:SelectTab(insertIndex)
    self:RenderAllFrames()
end

function Mod:OnInitialize()
    self:EnsureDB()
    self:RegisterPopups()

    self.history = {}
    self.messageFrames = {}
    self.bridgeFrames = {}
    self.bridgeRegistered = false
    self.chatEventsRegistered = false
    self.whisperTargets = {}
    self.whisperTargetLookup = {}
    self.activeWhisperTarget = nil
    self.selectedWhisperThread = nil
    self.unlockRegistered = false
    self.sidebarRegistered = false
    self.editBoxHooked = false
    self.editBoxSyncing = false
    self:LoadPersistedHistory()
    self:LoadPersistedPrivateChatState()
    self:ResetTabs()

    self.bridgeModifier = function(data)
        local ok = KT_SafeCallback(function()
            if type(data) ~= "table" then
                return
            end
            if data.type ~= "ADDON" or data.source ~= KT_MODULE_NAME then
                return
            end

            if type(data.message) == "string" and not data.ktKullThranColorized then
                data.message = KT_ColorizeMessage(data.message)
                data.ktKullThranColorized = true
            elseif type(data.text) == "string" and not data.ktKullThranColorized then
                data.text = KT_ColorizeMessage(data.text)
                data.ktKullThranColorized = true
            end

            data.r = KT_BRAND_COLOR.r
            data.g = KT_BRAND_COLOR.g
            data.b = KT_BRAND_COLOR.b
        end)

        if not ok then
            local api = KT_IsChattynatorActive()
            if api then
                api.RemoveModifier(self.bridgeModifier)
            end
        end
    end

    local publicAddon = KT_GetPublicAddon()
    publicAddon.SendToChat = function(first, second, third, fourth, fifth)
        local message, r, g, b = KT_NormalizePublicSendArgs(first, second, third, fourth, fifth)
        return self:SendMessageToChat(message, r, g, b)
    end

    _G.KT_ToggleChatWindow = function()
        local module = KT:GetModule("Chat", true)
        if module then
            module:ToggleWindow()
        end
    end
end

function Mod:OnEnable()
    self:EnsureDB()
    if self.db.enable == false then
        return
    end

    self.positionDebugEnabled = self.db.positionDebugEnabled == true
    self.positionDebugLog = type(self.db.positionDebugLog) == "table" and self.db.positionDebugLog or {}
    self.db.positionDebugLog = self.positionDebugLog

    if KT.db and KT.db.RegisterCallback then
        KT.db.RegisterCallback(self, "OnProfileChanged", "OnProfileUpdate")
        KT.db.RegisterCallback(self, "OnProfileCopied", "OnProfileUpdate")
        KT.db.RegisterCallback(self, "OnProfileReset", "OnProfileUpdate")
    end

    self.runtimeEventHandlers = self.runtimeEventHandlers or {}

    if InCombatLockdown and InCombatLockdown() then
        self.runtimeInitializationBlocked = true
        self:ScheduleFinishEnableRuntime(0.5)
    else
        self.runtimeInitializationBlocked = false
        self:ScheduleFinishEnableRuntime(0)
    end

    self:CreateNativeWindow()
    self:InstallPositionDebugHooks()
    self:StartPositionDebugWatch()
    self:RegisterWithUnlockMode()
    self:ApplySavedWindowPosition()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "QueueWorldLayoutRecovery")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "QueueWorldLayoutRecovery")
    self:RegisterEvent("UPDATE_CHAT_WINDOWS", "QueueWorldLayoutRecovery")
    self:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", "QueueWorldLayoutRecovery")
    self:RegisterEvent("CHANNEL_UI_UPDATE", "QueueTradeNativeChannelRefresh")
    self:RegisterEvent("CHANNEL_ROSTER_UPDATE", "QueueTradeNativeChannelRefresh")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "PLAYER_REGEN_ENABLED")

    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("whisperMode", "inline")
    end

    KT_HideBlizzardChatFrames()
    self:SuppressTemporaryWhisperWindows()
    self:HookBlizzardEditBox()
    self:ApplyPanelColor()
    self:AttachSidebarControls()
    self:UpdateSocialButton()

    KT:RegisterChatCommand("ktchat", function()
        self:ToggleWindow()
    end)
    KT:RegisterChatCommand("ktchatdebug", function(input)
        self:HandlePositionDebugCommand(input)
    end)
end

function Mod:EnsureWindowFadeWake(window)
    if not window or window.KT_FadeWakeWatcher then return end
    local watcher = CreateFrame("Frame", nil, UIParent)
    watcher.elapsed = 0
    watcher.wasInside = false
    watcher:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed < 0.08 then return end
        self.elapsed = 0
        if not window:IsShown() then return end
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        x, y = x / scale, y / scale
        local left, right, bottom, top = window:GetLeft(), window:GetRight(), window:GetBottom(), window:GetTop()
        local inside = left and right and bottom and top and x >= left and x <= right and y >= bottom and y <= top
        if inside and not self.wasInside then
            Mod:ShowWindowForActivity(false)
        elseif not inside and self.wasInside then
            Mod:RecordChatActivity()
            Mod:ScheduleWindowFade()
        end
        self.wasInside = inside and true or false
    end)
    window.KT_FadeWakeWatcher = watcher
end

function Mod:RestoreBlizzardBNWhispers()
    if KT_IsSecureChatSafeMode() then
        return
    end

    if _G.FCFManager_UnregisterDedicatedFrame then
        for index = 1, 10 do
            local candidate = _G["ChatFrame" .. index]
            if candidate then
                pcall(_G.FCFManager_UnregisterDedicatedFrame, candidate, "WHISPER")
                pcall(_G.FCFManager_UnregisterDedicatedFrame, candidate, "BN_WHISPER")
                candidate.KT_WhisperDedicatedRegistered = nil
            end
        end
    end

end
function Mod:FinishEnableRuntime()
    if self.runtimeInitialized then
        return
    end

    if self.runtimeInitializationBlocked then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self.runtimeInitializationBlocked = true
        return
    end

    self.runtimeInitialized = true
    self.runtimeEventFrameRegistered = false
    self:RegisterChatEvents()
    self:RestoreBlizzardBNWhispers()
    self:PrimeDedicatedNativeTabFrames()
    self:StartNativeWhisperScanner()
    self:HookItemRefWhisperLinks()
    self:HookBlizzardHyperlinkClicks()
    -- Retail's protected chat path can carry secret payloads in instances.
    -- Do not append an addon callback to ChatFrame1:AddMessage there: even a
    -- post-hook which normally early-outs joins KUI to Blizzard's shared chat
    -- execution chain and can make protected filter/history tables inaccessible
    -- to whichever addon happens to run next.
    if not KT_IsSecureChatSafeMode() then
        self:HookBlizzardMessageMirror()
    end

    if C_AddOns.IsAddOnLoaded(KT_CHATTYNATOR_NAME) then
        self:RegisterChattynatorBridge()
    end
end

function Mod:GetWindowScale()
    local scale = self.db and self.db.window and tonumber(self.db.window.scale)
    if not scale or scale <= 0 then
        scale = KT_GetDefaultChatWindowScale()
    end
    return scale
end

function Mod:ApplyWindowGeometry(window)
    window = window or _G.KT_ChatWindow
    if not window then
        return
    end

    window:SetScale(self:GetWindowScale())
    window:SetSize(self.db.window.width, self.db.window.height)

    if window.KT_GlassTop then
        window.KT_GlassTop:SetHeight(math.floor(self.db.window.height * 0.45))
    end
    if window.KT_LeftShade then
        window.KT_LeftShade:SetWidth(math.floor(self.db.window.width * 0.22))
    end
    if window.KT_GlassBottom then
        window.KT_GlassBottom:SetHeight(math.floor(self.db.window.height * 0.42))
    end
end

local function KT_DebugFrameName(frame)
    if frame == nil then return "nil" end
    if type(frame) == "string" then return frame end
    if frame.GetName then
        local ok, name = pcall(frame.GetName, frame)
        if ok and name and name ~= "" then return name end
    end
    return tostring(frame)
end

local function KT_DebugNumber(value)
    local number = tonumber(value)
    return number and format("%.3f", number) or "nil"
end

function Mod:GetPositionDebugSnapshot()
    local window = _G.KT_ChatWindow
    if not window then return "window=nil" end

    local point, relativeTo, relativePoint, x, y = window:GetPoint(1)
    local saved = KT.db and KT.db.profile and KT.db.profile.editMode
        and KT.db.profile.editMode.frames
        and KT.db.profile.editMode.frames[KT_CHAT_DB_KEY]
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or nil

    return format(
        "live=%s>%s:%s x=%s y=%s left=%s bottom=%s size=%sx%s scale=%s effective=%s ui=%s | saved=%s>%s x=%s y=%s scale=%s",
        tostring(point or "nil"), KT_DebugFrameName(relativeTo), tostring(relativePoint or "nil"),
        KT_DebugNumber(x), KT_DebugNumber(y), KT_DebugNumber(window:GetLeft()), KT_DebugNumber(window:GetBottom()),
        KT_DebugNumber(window:GetWidth()), KT_DebugNumber(window:GetHeight()), KT_DebugNumber(window:GetScale()),
        KT_DebugNumber(window:GetEffectiveScale()), KT_DebugNumber(uiScale),
        tostring(saved and saved.point or "nil"), tostring(saved and saved.relativePoint or "nil"),
        KT_DebugNumber(saved and saved.x), KT_DebugNumber(saved and saved.y), KT_DebugNumber(saved and saved.scale)
    )
end

function Mod:GetPositionDebugSignature()
    local window = _G.KT_ChatWindow
    if not window then return "window=nil" end
    local point, relativeTo, relativePoint, x, y = window:GetPoint(1)
    local uiScale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or nil
    return table.concat({
        tostring(point), KT_DebugFrameName(relativeTo), tostring(relativePoint),
        KT_DebugNumber(x), KT_DebugNumber(y), KT_DebugNumber(window:GetLeft()), KT_DebugNumber(window:GetBottom()),
        KT_DebugNumber(window:GetWidth()), KT_DebugNumber(window:GetHeight()), KT_DebugNumber(window:GetScale()),
        KT_DebugNumber(window:GetEffectiveScale()), KT_DebugNumber(uiScale),
    }, "|")
end

function Mod:RecordPositionDebug(reason, stack)
    if not self.positionDebugEnabled then return end

    self.positionDebugLog = self.positionDebugLog or {}
    local timestamp = date and date("%H:%M:%S") or tostring(GetTime and GetTime() or 0)
    local snapshot = self:GetPositionDebugSnapshot()
    local trace = stack
    if not trace and _G.debugstack then
        trace = _G.debugstack(3, 7, 7)
    end
    trace = KT_SafeString(trace, "stack unavailable")
    local entry = format("[%s] %s\n%s\n%s", timestamp, tostring(reason or "unknown"), snapshot, trace)
    tinsert(self.positionDebugLog, entry)
    if #self.positionDebugLog > KT_CHAT_POSITION_DEBUG_MAX then
        tremove(self.positionDebugLog, 1)
    end
    if self.db then
        self.db.positionDebugLog = self.positionDebugLog
    end

    if self.positionDebugVerbose then
        local message = "|cff33ccff[KT Chat Position]|r " .. tostring(reason or "unknown") .. " | " .. snapshot
        if KT and KT.Print then
            KT:Print(message)
        else
            print(message)
        end
    end
end

function Mod:StopPositionDebugWatch()
    if self.positionDebugTicker then
        self.positionDebugTicker:Cancel()
        self.positionDebugTicker = nil
    end
end

function Mod:StartPositionDebugWatch()
    self:StopPositionDebugWatch()
    if not self.positionDebugEnabled or not C_Timer or not C_Timer.NewTicker then return end

    self.positionDebugLastSignature = self:GetPositionDebugSignature()
    self.positionDebugTicker = C_Timer.NewTicker(1, function()
        if not (Mod and Mod.positionDebugEnabled) then return end
        local signature = Mod:GetPositionDebugSignature()
        if signature ~= Mod.positionDebugLastSignature then
            Mod.positionDebugLastSignature = signature
            Mod:RecordPositionDebug("watchdog detected geometry change")
        end
    end)
end

function Mod:InstallPositionDebugHooks()
    local window = _G.KT_ChatWindow
    if not window or window.KT_PositionDebugHooked or not hooksecurefunc then return end

    window.KT_PositionDebugHooked = true
    for _, methodName in ipairs({ "ClearAllPoints", "SetPoint", "SetScale", "SetSize" }) do
        local hookedMethod = methodName
        if type(window[hookedMethod]) == "function" then
            hooksecurefunc(window, hookedMethod, function()
                if not (Mod and Mod.positionDebugEnabled) then return end
                local trace = _G.debugstack and _G.debugstack(3, 7, 7) or nil
                Mod:RecordPositionDebug("KT_ChatWindow:" .. hookedMethod, trace)
            end)
        end
    end
end

function Mod:OpenPositionDebugLog()
    local dialog = self:EnsureCopyDialog()
    local textBox = dialog and dialog.KT_TextBox
    local editBox = textBox and textBox.GetEditBox and textBox:GetEditBox()
    if not (dialog and textBox and editBox) then return end

    if dialog.TitleText then
        dialog.TitleText:SetText(LText("KT Chat Position Debug"))
    elseif dialog.SetTitle then
        dialog:SetTitle(LText("KT Chat Position Debug"))
    end

    local lines = {
        "Current: " .. self:GetPositionDebugSnapshot(),
        "Entries: " .. tostring(self.positionDebugLog and #self.positionDebugLog or 0),
        "",
    }
    for _, entry in ipairs(self.positionDebugLog or {}) do
        tinsert(lines, entry)
        tinsert(lines, "")
    end

    textBox:SetText(table.concat(lines, "\n"))
    editBox:SetCursorPosition(0)
    editBox:HighlightText(0, #editBox:GetText())
    if textBox.ScrollToBegin then textBox:ScrollToBegin() end
    dialog:Show()
end

function Mod:HandlePositionDebugCommand(input)
    local command = strlower(strtrim(tostring(input or "")))
    if command == "dump" then
        self:OpenPositionDebugLog()
        return
    elseif command == "clear" then
        wipe(self.positionDebugLog or {})
        if self.db then self.db.positionDebugLog = self.positionDebugLog end
        if KT and KT.Print then KT:Print("KT Chat position debug log cleared.") end
        return
    elseif command == "verbose" then
        self.positionDebugVerbose = not self.positionDebugVerbose
        if KT and KT.Print then KT:Print("KT Chat position debug verbose: " .. (self.positionDebugVerbose and "ON" or "OFF")) end
        return
    end

    if command == "on" then
        self.positionDebugEnabled = true
    elseif command == "off" then
        self.positionDebugEnabled = false
    else
        self.positionDebugEnabled = not self.positionDebugEnabled
    end

    if self.positionDebugEnabled then
        self.positionDebugLog = self.positionDebugLog or {}
        if self.db then
            self.db.positionDebugEnabled = true
            self.db.positionDebugLog = self.positionDebugLog
        end
        self:InstallPositionDebugHooks()
        self:StartPositionDebugWatch()
        self:RecordPositionDebug("debug enabled")
        if KT and KT.Print then
            KT:Print("KT Chat position debug ON and persistent across reloads. Use /ktchatdebug dump after the chat moves.")
        end
    else
        if self.db then self.db.positionDebugEnabled = false end
        self:StopPositionDebugWatch()
        if KT and KT.Print then
            KT:Print("KT Chat position debug OFF. Use /ktchatdebug dump to inspect the captured log.")
        end
    end
end

function Mod:SaveWindowPosition()
    local window = _G.KT_ChatWindow
    if not (window and KT.db and KT.db.profile) then return end

    KT.db.profile.editMode = KT.db.profile.editMode or {}
    KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}
    KT.db.profile.chat = KT.db.profile.chat or {}
    KT.db.profile.chat.window = KT.db.profile.chat.window or {}

    local point, relativeTo, relativePoint, x, y = window:GetPoint(1)
    local left, bottom = window:GetLeft(), window:GetBottom()
    if left and bottom and UIParent then
        local frameScale = window.GetEffectiveScale and window:GetEffectiveScale() or 1
        local uiScale = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
        if not uiScale or uiScale == 0 then uiScale = 1 end
        point, relativeTo, relativePoint = "BOTTOMLEFT", UIParent, "BOTTOMLEFT"
        x = left * frameScale / uiScale
        y = bottom * frameScale / uiScale
    end

    local scale = window.GetScale and window:GetScale() or self:GetWindowScale()
    KT.db.profile.chat.window.scale = scale
    KT.db.profile.editMode.frames[KT_CHAT_DB_KEY] = {
        point = point or "BOTTOMLEFT",
        relativePoint = relativePoint or point or "BOTTOMLEFT",
        x = x or KT_CHAT_WINDOW_DEFAULT_X,
        y = y or KT_CHAT_WINDOW_DEFAULT_Y,
        scale = scale,
    }
    self:RecordPositionDebug("SaveWindowPosition")
end

function Mod:ApplySavedWindowPosition()
    local window = _G.KT_ChatWindow
    local saved = KT.db and KT.db.profile and KT.db.profile.editMode
        and KT.db.profile.editMode.frames
        and KT.db.profile.editMode.frames[KT_CHAT_DB_KEY]
    if not (window and saved and saved.point and UIParent) then return end

    if saved.scale and window.SetScale then
        window:SetScale(saved.scale)
        self.db.window.scale = saved.scale
    end
    window:ClearAllPoints()
    window:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    self:RecordPositionDebug("ApplySavedWindowPosition")
end
function Mod:OnProfileUpdate()
    self:EnsureDB()
    self:LoadPersistedHistory()
    self:LoadPersistedPrivateChatState()
    self:ResetTabs()

    if _G.KT_ChatWindow then
        self:ApplyWindowGeometry(_G.KT_ChatWindow)
        if self.db.window.visible then
            _G.KT_ChatWindow:Show()
        else
            _G.KT_ChatWindow:Hide()
        end
    end

    KT_HideBlizzardChatFrames()
    self:SuppressTemporaryWhisperWindows()
    self:HookBlizzardEditBox()
    self:RefreshTabButtons()
    self:ApplyPanelColor()
    self:AttachSidebarControls()
    self:UpdateSocialButton()
    self:RefreshWhisperStrip()
    self:RefreshManagedChatFrames()
    self:PrimeDedicatedNativeTabFrames()
    self:QueueChatLayoutReflow()

    self:RenderAllFrames()
    self:ScheduleWindowFade()
end

function Mod:Refresh()
    self:EnsureDB()

    if self.db.enable == false then
        local window = _G.KT_ChatWindow
        if window then
            window:Hide()
        end
        return
    end

    if self.IsEnabled and not self:IsEnabled() and self.Enable then
        local ok = pcall(self.Enable, self)
        if ok then
            return
        end
    end

    if not self.runtimeInitializationBlocked and not self.runtimeInitialized and not (InCombatLockdown and InCombatLockdown()) and self.ScheduleFinishEnableRuntime then
        self:ScheduleFinishEnableRuntime(0)
    end

    self:OnProfileUpdate()
end

function Mod:OnDisable()
    if KT.db and KT.db.UnregisterAllCallbacks then
        KT.db:UnregisterAllCallbacks(self)
    end
    if self._deferredEnableTicker and self._deferredEnableTicker.Cancel then
        self._deferredEnableTicker:Cancel()
    end
    self._deferredEnableTicker = nil
    if self.runtimeInitTimer and self.runtimeInitTimer.Cancel then
        self.runtimeInitTimer:Cancel()
    end
    self.runtimeInitTimer = nil
    self.runtimeInitialized = false
    self.runtimeInitializationBlocked = false
    self.chatEventsRegistered = false
    if self.nativeWhisperScanner and self.nativeWhisperScanner.Cancel then
        self.nativeWhisperScanner:Cancel()
    end
    self.nativeWhisperScanner = nil
    self.nativeWhisperMessageCount = nil
    self.nativeWhisperLastText = nil
    self.nativeWhisperSeenLookup = nil
    self.nativeWhisperSeenOrder = nil
    self:UnregisterAllRuntimeEvents()
    self:UnregisterAllEvents()
end

function Mod:ApplyPanelColor()
    local window = _G.KT_ChatWindow
    if not window then
        return
    end

    local color = self.db.panelColor or KT_CHAT_DEFAULT_PANEL_COLOR
    local alpha = color.a or 0
    if window.bgKT then
        window.bgKT:SetColorTexture(color.r, color.g, color.b, alpha)
    end
    if window.KT_GlassTop then
        window.KT_GlassTop:SetHeight(math.floor(window:GetHeight() * 0.45))
    end
    if window.KT_GlassBottom then
        window.KT_GlassBottom:SetHeight(math.floor(window:GetHeight() * 0.42))
    end
    if window.KT_LeftShade then
        window.KT_LeftShade:SetWidth(math.floor(window:GetWidth() * 0.22))
    end
    if window.borderKT then
        for _, edge in ipairs(window.borderKT) do
            edge:SetAlpha(0)
        end
    end
    if window.KT_Header then
        window.KT_Header:SetBackdropColor(0, 0, 0, 0)
        window.KT_Header:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if window.KT_Content then
        window.KT_Content:SetBackdropColor(color.r * 0.36, color.g * 0.36, color.b * 0.36, alpha)
        window.KT_Content:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if window.KT_Footer then
        window.KT_Footer:SetBackdropColor(color.r * 0.34, color.g * 0.34, color.b * 0.34, alpha)
        window.KT_Footer:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if window.KT_InputHost then
        window.KT_InputHost:SetBackdropColor(color.r * 0.52, color.g * 0.52, color.b * 0.52, alpha)
        window.KT_InputHost:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if window.KT_ScrollButton then
        window.KT_ScrollButton:SetBackdropColor(color.r * 0.5, color.g * 0.5, color.b * 0.5, alpha * 0.12)
    end
    if window.KT_SendButton then
        window.KT_SendButton:SetBackdropColor(1, 1, 1, alpha)
        window.KT_SendButton:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if window.KT_BackdropFade then
        KT_ApplyGradient(window.KT_BackdropFade, "VERTICAL", { r = color.r, g = color.g, b = color.b, a = alpha * 0.18 }, { r = color.r, g = color.g, b = color.b, a = alpha * 0.02 })
    end
    if window.KT_ContentTopGlow then
        KT_ApplyGradient(window.KT_ContentTopGlow, "VERTICAL", { r = 1, g = 1, b = 1, a = alpha * 0.08 }, { r = 1, g = 1, b = 1, a = 0 })
    end
    if window.KT_ContentBottomShade then
        KT_ApplyGradient(window.KT_ContentBottomShade, "VERTICAL", { r = 0, g = 0, b = 0, a = 0 }, { r = 0, g = 0, b = 0, a = alpha * 0.16 })
    end
    if window.KT_GlassTop then
        KT_ApplyGradient(window.KT_GlassTop, "VERTICAL", { r = 1, g = 1, b = 1, a = alpha * 0.09 }, { r = 1, g = 1, b = 1, a = alpha * 0.01 })
    end
    if window.KT_GlassBottom then
        KT_ApplyGradient(window.KT_GlassBottom, "VERTICAL", { r = 0, g = 0, b = 0, a = alpha * 0.02 }, { r = 0, g = 0, b = 0, a = alpha * 0.18 })
    end
    if window.KT_FooterGlow then
        KT_ApplyGradient(window.KT_FooterGlow, "VERTICAL", { r = 1, g = 1, b = 1, a = alpha * 0.06 }, { r = 1, g = 1, b = 1, a = alpha * 0.01 })
    end
    if window.KT_LeftShade then
        KT_ApplyGradient(window.KT_LeftShade, "HORIZONTAL", { r = 0, g = 0, b = 0, a = alpha * 0.16 }, { r = 0, g = 0, b = 0, a = 0 })
    end
    if window.KT_InputGlow then
        KT_ApplyGradient(window.KT_InputGlow, "VERTICAL", { r = 1, g = 1, b = 1, a = alpha * 0.05 }, { r = 1, g = 1, b = 1, a = 0 })
    end

    if window.KT_ActionButtons then
        for _, button in ipairs(window.KT_ActionButtons) do
            button:SetBackdropColor(0, 0, 0, 0)
            button:SetBackdropBorderColor(0, 0, 0, 0)
            if button.KT_Shadow then
                button.KT_Shadow:SetAlpha(0.35 + (alpha * 0.15))
            end
        end
    end

    self:ApplyHighlightColor()
end

function Mod:ApplyHighlightColor()
    local window = _G.KT_ChatWindow
    if not window then
        return
    end

    local color = self:GetHighlightColor()

    if window.KT_ActionButtons then
        for _, button in ipairs(window.KT_ActionButtons) do
            button:SetBackdropBorderColor(0, 0, 0, 0)
            local actionHighlight = button:GetHighlightTexture()
            if actionHighlight then
                actionHighlight:SetVertexColor(1, 1, 1, 0.08)
            end
        end
    end

    KT_SetActionButtonHighlight(window.KT_ScrollButton, color)

    if window.KT_SendButton then
        window.KT_SendButton:SetBackdropBorderColor(0, 0, 0, 0)
        local sendHighlight = window.KT_SendButton:GetHighlightTexture()
        if sendHighlight then
            sendHighlight:SetVertexColor(1, 1, 1, 0.08)
        end
    end

    self:SelectTab(self.selectedTabIndex or 1)
end

function Mod:AttachBlizzardEditBox()
    local window = _G.KT_ChatWindow
    local editBox = _G.ChatFrame1EditBox
    if not window or not editBox or not window.KT_InputHost then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self.attachBlizzardEditBoxAfterCombat = true
        return
    end
    self.attachBlizzardEditBoxAfterCombat = nil
    local fontPath, fontSize, fontOutline = self:GetResolvedFont()

    self.suppressEditBoxLayoutWatch = true
    editBox:SetParent(window.KT_InputHost)
    if editBox.SetFrameStrata then
        editBox:SetFrameStrata(window:GetFrameStrata())
    end
    if editBox.SetFrameLevel then
        editBox:SetFrameLevel(window.KT_InputHost:GetFrameLevel() + 2)
    end
    editBox:ClearAllPoints()
    editBox:SetPoint("TOPLEFT", window.KT_InputHost, "TOPLEFT", 0, 0)
    editBox:SetPoint("BOTTOMRIGHT", window.KT_InputHost, "BOTTOMRIGHT", 0, 0)
    editBox:SetAltArrowKeyMode(false)
    editBox:SetFont(fontPath, fontSize, fontOutline)
    -- editBox:SetTextInsets(8, 8, 5, 5) -- Comentado para no romper el espaciado nativo del canal
    
    if not editBox.KT_TextInsetsHooked then
        editBox.KT_TextInsetsHooked = true
        hooksecurefunc(editBox, "SetTextInsets", function(self, left, right, top, bottom)
            if InCombatLockdown and InCombatLockdown() then
                return
            end
            if type(left) == "number" and not self.KT_SettingInsets then
                self.KT_SettingInsets = true
                -- Extra padding so the cursor doesn't touch the colon, and a minimum of 8px for the left border
                local newLeft = math.max(8, left + 8)
                self:SetTextInsets(newLeft, right, top, bottom)
                self.KT_SettingInsets = false
            end
        end)
        -- Force a re-evaluation of current insets
        local l, r, t, b = editBox:GetTextInsets()
        editBox.KT_SettingInsets = true
        editBox:SetTextInsets(math.max(8, l + 8), r, t, b)
        editBox.KT_SettingInsets = false
    end

    if editBox.SetBackdrop then
        editBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        editBox:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
        editBox:SetBackdropBorderColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 1)
    end

    for _, region in ipairs({ editBox:GetRegions() }) do
        if region.IsObjectType and region:IsObjectType("Texture") then
            local name = region.GetName and region:GetName()
            if name and (name:find("Left") or name:find("Mid") or name:find("Right") or name:find("Focus")) then
                region:SetAlpha(0)
            end
        elseif region.IsObjectType and region:IsObjectType("FontString") then
            region:SetFont(fontPath, fontSize, fontOutline)
        end
    end
    if self.RestoreBlizzardEditBoxHeader then
        self:RestoreBlizzardEditBoxHeader(editBox)
    elseif self.CollapseBlizzardEditBoxHeader then
        self:CollapseBlizzardEditBoxHeader(editBox)
    else
        self:UpdateInputPrompt(editBox)
    end
    self.suppressEditBoxLayoutWatch = nil
end

function Mod:CollapseBlizzardEditBoxHeader(editBox)
    self:RestoreBlizzardEditBoxHeader(editBox)
end

function Mod:QueueAttachBlizzardEditBox()
    if self.attachBlizzardEditBoxQueued then
        return
    end

    self.attachBlizzardEditBoxQueued = true
    C_Timer.After(0, function()
        self.attachBlizzardEditBoxQueued = nil
        if not (Mod and Mod.IsEnabled and Mod:IsEnabled()) then
            return
        end

        Mod:AttachBlizzardEditBox()
        if Mod.QueueChatLayoutReflow then
            Mod:QueueChatLayoutReflow()
        end
    end)
end

function Mod:RecoverChatLayoutAfterWorldChange(trigger)
    local window = _G.KT_ChatWindow
    if not window or not self.db or self.db.enable == false then
        return
    end

    self:RecordPositionDebug("RecoverChatLayout begin: " .. tostring(trigger or "scheduled"))
    self:ApplySavedWindowPosition()
    KT_HideBlizzardChatFrames()
    self:RefreshChatFrameMode()
    self:QueueTradeNativeChannelRefresh()
    self:AttachBlizzardEditBox()
    self:RefreshWhisperStrip()
    self:RefreshManagedChatFrames()
    self:UpdateSidebarLayout()
    self:UpdateSocialButton()
    self:UpdateScrollButtonVisibility()
    self:EnsureWindowFadeWake(window)
    self:QueueChatLayoutReflow()
    self:RecordPositionDebug("RecoverChatLayout end: " .. tostring(trigger or "scheduled"))
end

function Mod:RefreshTradeNativeChannels()
    local frame = self.nativeTabFrames and self.nativeTabFrames.trade
    if not frame or frame.KT_NativeTabRole ~= "trade" then
        return
    end
    if InCombatLockdown and InCombatLockdown() then
        self.tradeChannelRefreshPending = true
        return
    end
    self.tradeChannelRefreshPending = nil
    KT_RefreshTradeNativeChannels(frame)
end

function Mod:QueueTradeNativeChannelRefresh()
    if self.tradeChannelRefreshQueued then
        return
    end
    self.tradeChannelRefreshQueued = true
    C_Timer.After(0, function()
        Mod.tradeChannelRefreshQueued = nil
        if not (Mod and Mod.IsEnabled and Mod:IsEnabled()) then
            return
        end
        Mod:RefreshTradeNativeChannels()
    end)
end

function Mod:QueueWorldLayoutRecovery(event, isInitialLogin, isReloadingUi)
    if event == "PLAYER_ENTERING_WORLD" and isInitialLogin == true and isReloadingUi ~= true then
        self:ClearPrivateChatSession()
    end

    self:RecordPositionDebug("QueueWorldLayoutRecovery: " .. tostring(event or "manual"))
    self.worldLayoutRecoveryToken = (tonumber(self.worldLayoutRecoveryToken) or 0) + 1
    local token = self.worldLayoutRecoveryToken

    local function runRecovery()
        if not (Mod and Mod.IsEnabled and Mod:IsEnabled()) then
            return
        end
        if token ~= Mod.worldLayoutRecoveryToken then
            return
        end

        Mod:RecoverChatLayoutAfterWorldChange(event)
    end

    C_Timer.After(0, runRecovery)
    C_Timer.After(0.1, runRecovery)
    C_Timer.After(0.5, runRecovery)
end

function Mod:HookBlizzardEditBoxLayout()
    local editBox = _G.ChatFrame1EditBox
    if self.editBoxLayoutHooked or not editBox or not hooksecurefunc then
        return
    end

    self.editBoxLayoutHooked = true

    local function requestReanchor(widget)
        if widget ~= _G.ChatFrame1EditBox then
            return
        end
        if self.suppressEditBoxLayoutWatch then
            return
        end

        self:QueueAttachBlizzardEditBox()
    end

    if type(editBox.SetParent) == "function" then
        hooksecurefunc(editBox, "SetParent", requestReanchor)
    end
    if type(editBox.ClearAllPoints) == "function" then
        hooksecurefunc(editBox, "ClearAllPoints", requestReanchor)
    end
    if type(editBox.SetAllPoints) == "function" then
        hooksecurefunc(editBox, "SetAllPoints", requestReanchor)
    end
    if type(editBox.SetPoint) == "function" then
        hooksecurefunc(editBox, "SetPoint", requestReanchor)
    end
end

function Mod:GetTabIndexForLiveChatType(chatType)
    local normalized = strupper(strtrim(tostring(chatType or "")))
    if normalized == "" then
        return nil
    end

    for index, tab in ipairs(self.tabs or {}) do
        local filterMode = strupper(strtrim(tostring(tab.filterMode or "")))
        if normalized == "GUILD" or normalized == "OFFICER" then
            if filterMode == "GUILD" then
                return index
            end
        elseif normalized == "WHISPER" or normalized == "BN_WHISPER" or normalized == "REPLY" then
            if filterMode == "WHISPER" then
                return index
            end
        elseif normalized == "PARTY" or normalized == "PARTY_LEADER"
            or normalized == "RAID" or normalized == "RAID_LEADER"
            or normalized == "INSTANCE_CHAT" or normalized == "INSTANCE_CHAT_LEADER"
            or normalized == "GROUP" then
            if filterMode == "GROUP" or filterMode == "PARTY" or filterMode == "RAID" or filterMode == "INSTANCE" then
                return index
            end
        elseif normalized == "CHANNEL" then
            if filterMode == "CHANNEL" then
                return index
            end
        elseif normalized == "COMBAT" then
            if filterMode == "COMBAT" then
                return index
            end
        elseif normalized == "SAY" or normalized == "EMOTE" or normalized == "YELL" or normalized == "GENERAL" then
            if filterMode == "GENERAL" then
                return index
            end
        end
    end

    return nil
end

function Mod:GetLiveEditBoxTabIndex(editBox, currentText)
    if not editBox then
        return nil
    end

    local liveChatType
    if editBox.GetAttribute then
        local ok, value = pcall(editBox.GetAttribute, editBox, "chatType")
        if ok and type(value) == "string" and value ~= "" then
            liveChatType = value
        end
    end

    local normalized = strupper(strtrim(tostring(liveChatType or "")))
    if normalized == "" then
        local lowerText = strlower(strtrim(tostring(currentText or (editBox.GetText and editBox:GetText()) or "")))
        if lowerText == "" then
            return nil
        elseif lowerText:find("^/w%s+") or lowerText:find("^/whisper%s+") or lowerText:find("^/whisp%s+")
            or lowerText:find("^/r%s+") or lowerText:find("^/reply%s+") then
            normalized = "WHISPER"
        elseif lowerText:find("^/g%s+") or lowerText:find("^/guild%s+")
            or lowerText:find("^/o%s+") or lowerText:find("^/officer%s+") then
            normalized = "GUILD"
        elseif lowerText:find("^/p%s+") or lowerText:find("^/party%s+")
            or lowerText:find("^/raid%s+") or lowerText:find("^/ra%s+")
            or lowerText:find("^/rw%s+") or lowerText:find("^/i%s+")
            or lowerText:find("^/instance%s+") then
            normalized = "GROUP"
        elseif lowerText:find("^/%d+%s+") or lowerText:find("^/trade%s+") then
            normalized = "CHANNEL"
        else
            normalized = "GENERAL"
        end
    end

    return self:GetTabIndexForLiveChatType(normalized), normalized
end

function Mod:SyncVisibleEditBoxTarget(force, respectLiveState)
    local editBox = _G.ChatFrame1EditBox
    local chatFrame = _G.ChatFrame1
    local tab = self:GetActiveTab()
    if self.editBoxSyncing or not editBox or not chatFrame or not editBox:IsShown() or not tab then
        return
    end

    if self:IsCombatTab(tab) then
        return
    end

    if self.activeWhisperBNetAccountID and type(self.selectedWhisperThread) == "table" and type(self.selectedWhisperThread.bnetIDAccount) == "number" then
        return
    end

    local currentText = editBox:GetText() or ""
    local shouldRespectLiveState = respectLiveState ~= false
    if shouldRespectLiveState then
        local liveTabIndex = self:GetLiveEditBoxTabIndex(editBox, currentText)

        -- Respect the live Blizzard chat target in the edit box, but do not
        -- auto-switch KUI's selected tab just because the player typed /p, /g,
        -- /w, etc. from General. Tab changes should come from explicit user
        -- clicks or dedicated actions, not from the transient chat mode.
        if liveTabIndex then
            return
        end

        if currentText ~= "" and not self:IsCommandOnlyText(currentText) then
            return
        end
    else
        if not force and not self:IsCommandOnlyText(currentText) then
            return
        end
    end

    if not _G.ChatFrame_OpenChat then
        return
    end

    if strupper(strtrim(tostring(tab.filterMode or ""))) == "WHISPER" then
        local thread = self.selectedWhisperThread
        if type(thread) == "table" and (KT_GetNonEmptyAccessibleString(thread.target) or type(thread.bnetIDAccount) == "number") then
            self:OpenDirectWhisperTarget(thread.target, thread.bnetIDAccount)
            return
        end
        if KT_GetNonEmptyAccessibleString(self.activeWhisperTarget) or type(self.activeWhisperBNetAccountID) == "number" then
            self:OpenDirectWhisperTarget(self.activeWhisperTarget, self.activeWhisperBNetAccountID)
            return
        end
    end

    self.editBoxSyncing = true
    _G.ChatFrame_OpenChat(KT_GetTabCommand(tab), chatFrame)
    self.editBoxSyncing = false
    self:UpdateInputPrompt(editBox)
end

function Mod:FocusInputForActiveTab()
    local editBox = _G.ChatFrame1EditBox
    if not editBox then
        return
    end

    local tab = self:GetActiveTab()
    if self:IsCombatTab(tab) then
        return
    end

    self:ShowWindowForActivity()

    local whisperMode = strupper(strtrim(tostring(tab and tab.filterMode or ""))) == "WHISPER"
    if whisperMode then
        local thread = self.selectedWhisperThread
        if type(thread) == "table" and tostring(thread.chatType or ""):find("BN_", 1, true) ~= nil and type(thread.bnetIDAccount) ~= "number" then
            thread.bnetIDAccount = KT_ResolveBNetAccountIDLoose(thread.target)
        end
        if type(thread) == "table" and type(thread.bnetIDAccount) ~= "number" then
            self.activeWhisperBNetAccountID = nil
        elseif type(self.activeWhisperBNetAccountID) ~= "number" and type(thread) == "table" and type(thread.bnetIDAccount) == "number" then
            self.activeWhisperBNetAccountID = thread.bnetIDAccount
        end
        if type(thread) == "table" and (KT_GetNonEmptyAccessibleString(thread.target) or type(thread.bnetIDAccount) == "number") then
            self:OpenDirectWhisperTarget(thread.target, thread.bnetIDAccount)
            self:SelectTab(self.selectedTabIndex or 1)
            return
        end
        if KT_GetNonEmptyAccessibleString(self.activeWhisperTarget) or type(self.activeWhisperBNetAccountID) == "number" then
            self:OpenDirectWhisperTarget(self.activeWhisperTarget, self.activeWhisperBNetAccountID)
            self:SelectTab(self.selectedTabIndex or 1)
            return
        end
    end

    local command = KT_GetTabCommand(tab)
    local nonWhisperMode = not whisperMode
    self.suppressEditBoxActivateSync = true
    if nonWhisperMode then
        if not KT_IsSecureChatSafeMode() and not (InCombatLockdown and InCombatLockdown()) then
            self.activeWhisperBNetAccountID = nil
            editBox.chatType = nil
            editBox.tellTarget = nil
            editBox.bnetAccountID = nil
            editBox.KT_FullTellTarget = nil
        end
        if _G.ChatEdit_DeactivateChat and editBox.IsShown and editBox:IsShown() then
            pcall(_G.ChatEdit_DeactivateChat, editBox)
        end
    end
    if _G.ChatFrame_OpenChat then
        pcall(_G.ChatFrame_OpenChat, type(command) == "string" and command or "", _G.ChatFrame1)
    elseif not editBox:IsShown() then
        KT_ActivateChat(editBox)
    else
        editBox:SetFocus()
    end
    self.suppressEditBoxActivateSync = nil

    if editBox and editBox.SetCursorPosition and type(command) == "string" then
        editBox:SetCursorPosition(strlen(command))
    end

    local activeMode = strupper(strtrim(tostring(tab and tab.filterMode or "")))
    local activeTabID = strlower(strtrim(tostring(tab and tab.id or "")))
    if activeMode == "GENERAL" or activeTabID == "general" then
        if not KT_IsSecureChatSafeMode() and not (InCombatLockdown and InCombatLockdown()) then
            editBox.chatType = "SAY"
            editBox.tellTarget = nil
            editBox.bnetAccountID = nil
            editBox.KT_FullTellTarget = nil
        end
        KT_UpdateChatEditHeader(editBox)
        self:UpdateInputPrompt(editBox)
    end

    self:SelectTab(self.selectedTabIndex or 1)
end

function Mod:NormalizeBNetEditBoxStateForSend(editBox)
    if not editBox then
        return false
    end

    if KT_IsSecureChatSafeMode() or (InCombatLockdown and InCombatLockdown()) then
        return false
    end

    local liveChatType = tostring(editBox.chatType or "")
    if editBox.GetAttribute then
        local ok, value = pcall(editBox.GetAttribute, editBox, "chatType")
        if ok and type(value) == "string" and value ~= "" then
            liveChatType = value
        end
    end

    local bnetID = tonumber(editBox.bnetAccountID)
    if editBox.GetAttribute and type(bnetID) ~= "number" then
        local ok, value = pcall(editBox.GetAttribute, editBox, "bnetAccountID")
        if ok and tonumber(value) then
            bnetID = tonumber(value)
        end
    end

    local tellTarget = KT_GetNonEmptyAccessibleString(editBox.tellTarget)
    if editBox.GetAttribute and not tellTarget then
        local ok, value = pcall(editBox.GetAttribute, editBox, "tellTarget")
        if ok then
            tellTarget = KT_GetNonEmptyAccessibleString(value)
        end
    end

    local selectedThread = type(self.selectedWhisperThread) == "table" and self.selectedWhisperThread or nil
    if type(bnetID) ~= "number" and type(self.activeWhisperBNetAccountID) == "number" then
        bnetID = self.activeWhisperBNetAccountID
    end
    if type(bnetID) ~= "number" and selectedThread and type(selectedThread.bnetIDAccount) == "number" then
        bnetID = selectedThread.bnetIDAccount
    end

    if not tellTarget and selectedThread and type(selectedThread.bnetIDAccount) == "number" then
        if type(bnetID) ~= "number" or selectedThread.bnetIDAccount == bnetID then
            tellTarget = KT_GetNonEmptyAccessibleString(selectedThread.target)
        end
    end
    if not tellTarget then
        tellTarget = KT_GetNonEmptyAccessibleString(self.activeWhisperTarget)
    end

    if not tellTarget and selectedThread then
        tellTarget = KT_GetNonEmptyAccessibleString(selectedThread.target)
    end

    if not tellTarget then
        tellTarget = KT_GetLastTellTarget()
    end

    local activeTab = self.GetActiveTab and self:GetActiveTab() or nil
    local activeMode = strupper(strtrim(tostring(activeTab and activeTab.filterMode or "")))
    local activeTabID = strlower(strtrim(tostring(activeTab and activeTab.id or "")))

    local function ResetEditBoxToSay()
        editBox.chatType = "SAY"
        editBox.tellTarget = nil
        editBox.bnetAccountID = nil
        editBox.KT_FullTellTarget = nil
        self.activeWhisperBNetAccountID = nil

        KT_UpdateChatEditHeader(editBox)
        self:UpdateInputPrompt(editBox)
        return false
    end

    if activeMode ~= "WHISPER" and activeTabID == "general" and (liveChatType == "BN_WHISPER" or type(bnetID) == "number") and not tellTarget then
        return ResetEditBoxToSay()
    end

    if type(bnetID) == "number" and bnetID > 0 then
        local resolvedTarget = KT_GetNonEmptyAccessibleString(KT_ResolveBNetWhisperTarget(bnetID))
        if resolvedTarget then
            tellTarget = resolvedTarget
        end

        if tellTarget then
            editBox.chatType = "BN_WHISPER"
            editBox.tellTarget = tellTarget
            editBox.bnetAccountID = bnetID

            self.activeWhisperTarget = tellTarget
            self.activeWhisperBNetAccountID = bnetID
            if selectedThread and type(selectedThread.bnetIDAccount) == "number" and selectedThread.bnetIDAccount == bnetID then
                selectedThread.target = tellTarget
                selectedThread.chatType = "BN_WHISPER"
            end

            KT_UpdateChatEditHeader(editBox)
            self:UpdateInputPrompt(editBox)
            return true
        end

        if activeMode ~= "WHISPER" then
            return ResetEditBoxToSay()
        end
    end

    if liveChatType == "WHISPER" or liveChatType == "REPLY" then
        local fullWowTarget, shortWowTarget = KT_GetResolvedWoWWhisperTargets(tellTarget)
        local replyTarget = fullWowTarget or tellTarget
        if replyTarget then
            editBox.chatType = "WHISPER"
            editBox.tellTarget = replyTarget
            editBox.bnetAccountID = nil
            editBox.KT_FullTellTarget = replyTarget

            self.activeWhisperTarget = replyTarget
            self.activeWhisperBNetAccountID = nil
            if selectedThread and type(selectedThread.bnetIDAccount) ~= "number" then
                selectedThread.target = replyTarget
                selectedThread.chatType = "WHISPER"
            end
            KT_UpdateChatEditHeader(editBox)
            self:UpdateInputPrompt(editBox)
            return true
        end
    end

    if activeMode ~= "WHISPER" and activeTabID == "general" and (liveChatType == "BN_WHISPER" or liveChatType == "WHISPER" or liveChatType == "REPLY") then
        return ResetEditBoxToSay()
    end

    return liveChatType == "BN_WHISPER" or liveChatType == "WHISPER"
end

function Mod:HookBlizzardEditBox()
    if self.editBoxHooked or not _G.ChatFrame1EditBox then
        return
    end

    self.editBoxHooked = true
    self:AttachBlizzardEditBox()
    self:HookBlizzardEditBoxLayout()
    self:CollapseBlizzardEditBoxHeader(_G.ChatFrame1EditBox)
    -- BNet whisper pre-intercept: runs BEFORE Blizzard's ChatEdit_SendText
    -- via the editbox's own OnEnterPressed chain.  We send the BNet whisper
    -- ourselves and blank the editbox so the original handler has nothing
    -- left to send.  This avoids replacing _G.ChatEdit_SendText (taint risk).
    if _G.ChatFrame1EditBox and not self._bnetPreHooked then
        self._bnetPreHooked = true
        local editBoxRef = _G.ChatFrame1EditBox
        editBoxRef:HookScript("OnEnterPressed", function(eb)
            if eb ~= _G.ChatFrame1EditBox then return end
            if not (Mod and Mod.IsEnabled and Mod:IsEnabled()) then return end

            if Mod.NormalizeBNetEditBoxStateForSend then
                pcall(Mod.NormalizeBNetEditBoxStateForSend, Mod, eb)
            end

            local chatType = tostring(eb.chatType or "")
            local text = eb.GetText and eb:GetText() or ""
            if type(text) == "string" then text = strtrim(text) end

            local activeTab = Mod.GetActiveTab and Mod:GetActiveTab() or nil
            local activeMode = strupper(strtrim(tostring(activeTab and activeTab.filterMode or "")))
            if chatType == "WHISPER" and activeMode ~= "WHISPER" and type(text) == "string" and text:find("^/") then
                if not (InCombatLockdown and InCombatLockdown()) then
                    eb.chatType = nil
                    eb.tellTarget = nil
                    eb.bnetAccountID = nil
                end
                eb.KT_FullTellTarget = nil
            end

            eb.KT_FullTellTarget = nil
        end)
    end
    -- Post-hook for BNet whisper send: handle KUI-routed BNet whispers
    -- that Blizzard's default handler may not know about.
    if type(_G.ChatEdit_SendText) == "function" and not self._chatEditSendHooked then
        self._chatEditSendHooked = true
        hooksecurefunc("ChatEdit_SendText", function(editBox, addHistory)
            if not (Mod and Mod.IsEnabled and Mod:IsEnabled()) then return end
            if editBox ~= _G.ChatFrame1EditBox then return end
            if not (InCombatLockdown and InCombatLockdown()) then
                editBox.KT_FullTellTarget = nil
            end
        end)
    end

    local function onActivate(editBox)
        if editBox ~= _G.ChatFrame1EditBox then
            return
        end

        self:ShowWindowForActivity()
        self:AttachBlizzardEditBox()
        self:QueueAttachBlizzardEditBox()
        if self.suppressEditBoxActivateSync then
            self:SelectTab(self.selectedTabIndex or 1)
            return
        end
        self:SyncVisibleEditBoxTarget(true, true)
        self:SelectTab(self.selectedTabIndex or 1)
    end

    local function onDeactivate(editBox)
        if editBox == _G.ChatFrame1EditBox then
            self:AttachBlizzardEditBox()
            self:QueueAttachBlizzardEditBox()
            self:SelectTab(self.selectedTabIndex or 1)
            self:ScheduleWindowFade()
        end
    end

    local editBox = _G.ChatFrame1EditBox
    editBox:HookScript("OnEditFocusGained", onActivate)
    editBox:HookScript("OnEditFocusLost", onDeactivate)
    editBox:HookScript("OnShow", function(widget)
        if widget == _G.ChatFrame1EditBox then
            self:AttachBlizzardEditBox()
            self:QueueAttachBlizzardEditBox()
        end
    end)
    editBox:HookScript("OnTextChanged", function(widget)
        if widget == _G.ChatFrame1EditBox then
            -- The native edit box resolves /w targets while the player types.
            -- Do not turn that transient state into conversation entries; the
            -- corresponding whisper event confirms the target after sending.
            self:UpdateInputPrompt(widget)
        end
    end)

    if ChatFrameUtil and ChatFrameUtil.ActivateChat and hooksecurefunc then
        hooksecurefunc(ChatFrameUtil, "ActivateChat", function(editBoxArg)
            onActivate(editBoxArg or _G.ChatFrame1EditBox)
        end)
    end
    if ChatEdit_DeactivateChat and hooksecurefunc then
        hooksecurefunc("ChatEdit_DeactivateChat", function(editBoxArg)
            onDeactivate(editBoxArg or _G.ChatFrame1EditBox)
        end)
    end
    if _G.ChatFrame_OpenChat and hooksecurefunc then
        hooksecurefunc("ChatFrame_OpenChat", function()
            self:QueueAttachBlizzardEditBox()
        end)
    end
end

function Mod:SuppressTemporaryWhisperWindows()
    if KT_IsSecureChatSafeMode() then
        self.temporaryWhisperWindowsSuppressed = false
        return
    end

    if C_CVar and C_CVar.SetCVar then
        C_CVar.SetCVar("whisperMode", "inline")
    end

    -- Do not override Blizzard's temporary whisper window creation path.
    -- Replacing FCF_OpenTemporaryWindow taints secret whisper targets in
    -- Mainline and breaks FCF_SetWindowName / FloatingChatFrame internals.
    if self._temporaryWhisperWindowOverrideInstalled and self._originalOpenTemporaryWindow == nil then
        self._originalOpenTemporaryWindow = _G.FCF_OpenTemporaryWindow
    end

    if self._temporaryWhisperWindowOverrideInstalled and type(self._originalOpenTemporaryWindow) == "function" then
        _G.FCF_OpenTemporaryWindow = self._originalOpenTemporaryWindow
        self._temporaryWhisperWindowOverrideInstalled = nil
    end

    self.temporaryWhisperWindowsSuppressed = true
    self:HookTemporaryWhisperWindowCleanup()
    self:HideUnmanagedTemporaryWhisperWindows()
end

function Mod:SuppressTemporaryWhisperSystemEvents()
    local baseWindowCount = tonumber(_G.NUM_CHAT_WINDOWS) or 10
    local maxWindowCount = baseWindowCount + 20

    for index = baseWindowCount + 1, maxWindowCount do
        local frame = _G["ChatFrame" .. index]
        if frame and frame.isTemporary and type(frame.privateMessageList) == "table" and frame.UnregisterEvent then
            pcall(frame.UnregisterEvent, frame, "CHAT_MSG_SYSTEM")
        end
    end
end

function Mod:HideUnmanagedTemporaryWhisperWindows()
    if KT_IsSecureChatSafeMode() then
        return
    end

    local baseWindowCount = tonumber(_G.NUM_CHAT_WINDOWS) or 10
    local maxWindowCount = baseWindowCount + 10

    for index = baseWindowCount + 1, maxWindowCount do
        local frame = _G["ChatFrame" .. index]
        if frame and frame ~= _G.ChatFrame1 and frame ~= _G.ChatFrame2 and not frame.KT_KeepVisible and not frame.KT_UseAsPrimary then
            self:HideNativeChatChrome(frame)
            self:HideDetachedNativeChatFrame(frame)

            local dock = _G["DockedChatFrame" .. index]
            if dock and dock ~= frame then
                dock:SetAlpha(0)
                if dock.EnableMouse then
                    dock:EnableMouse(false)
                end
                dock:Hide()
            end
        end
    end
end

function Mod:HookTemporaryWhisperWindowCleanup()
    if KT_IsSecureChatSafeMode() or self.temporaryWhisperWindowCleanupHooked or type(_G.FCF_OpenTemporaryWindow) ~= "function" or not hooksecurefunc then
        return
    end

    self.temporaryWhisperWindowCleanupHooked = true
    hooksecurefunc("FCF_OpenTemporaryWindow", function(chatType)
        if chatType ~= "WHISPER" and chatType ~= "BN_WHISPER" then
            return
        end

        local function cleanup()
            if not (Mod and Mod.IsEnabled and Mod:IsEnabled()) then
                return
            end

            if KT_IsSecureChatSafeMode() then
                Mod:SuppressTemporaryWhisperSystemEvents()
            else
                Mod:HideUnmanagedTemporaryWhisperWindows()
                Mod:RefreshChatFrameMode()
            end
        end

        if C_Timer and C_Timer.After then
            C_Timer.After(0, cleanup)
            C_Timer.After(0.1, cleanup)
        else
            cleanup()
        end
    end)
end

function Mod:OpenDirectWhisperTarget(target, bnetIDAccount, forceWoWWhisper)
    if (InCombatLockdown and InCombatLockdown()) or KT_IsChatMessagingLocked() then
        return false
    end

    local chatFrame = KT_GetReplyChatFrame()
    local whisperTabIndex = self:GetWhisperTabIndex()
    local editBox = nil

    target = KT_GetNonEmptyAccessibleString(target) or ((type(bnetIDAccount) == "number" and bnetIDAccount > 0) and KT_ResolveBNetWhisperTarget(bnetIDAccount) or nil)
    if not forceWoWWhisper and type(bnetIDAccount) ~= "number" and type(self.selectedWhisperThread) == "table" and type(self.selectedWhisperThread.bnetIDAccount) == "number" and KT_TargetMatchesBNetTarget(target, self.selectedWhisperThread.target) then
        bnetIDAccount = self.selectedWhisperThread.bnetIDAccount
    end
    if not forceWoWWhisper and type(bnetIDAccount) ~= "number" and type(self.activeWhisperBNetAccountID) == "number" and KT_TargetMatchesBNetTarget(target, self.activeWhisperTarget) then
        bnetIDAccount = self.activeWhisperBNetAccountID
    end
    if not forceWoWWhisper and type(bnetIDAccount) ~= "number" then
        bnetIDAccount = KT_ResolveBNetAccountID(target) or KT_ResolveBNetAccountIDLoose(target)
    end

    local wantsBNet = (not forceWoWWhisper) and (
        KT_IsBNetWhisperKind((type(self.selectedWhisperThread) == "table" and self.selectedWhisperThread.chatType) or nil, bnetIDAccount)
        or (type(target) == "string" and target:find("#", 1, true) ~= nil)
    ) or false
    local whisperType = wantsBNet and "BN_WHISPER" or "WHISPER"

    if target then
        self.activeWhisperTarget = target
        self.selectedWhisperThread = {
            target = target,
            chatType = whisperType,
            bnetIDAccount = ((not forceWoWWhisper) and type(bnetIDAccount) == "number" and bnetIDAccount > 0) and bnetIDAccount or nil,
            threadKey = KT_GetWhisperTargetKey(target, whisperType, ((not forceWoWWhisper) and type(bnetIDAccount) == "number" and bnetIDAccount > 0) and bnetIDAccount or nil),
        }
    end
    self.activeWhisperBNetAccountID = ((not forceWoWWhisper) and type(bnetIDAccount) == "number" and bnetIDAccount > 0) and bnetIDAccount or nil

    self:ShowWindowForActivity()
    if whisperTabIndex then
        self:SelectTab(whisperTabIndex)
    end
    self:AttachBlizzardEditBox()

    if type(bnetIDAccount) == "number" and bnetIDAccount > 0 then
        KT_UpdateLastTellTarget(target, whisperType)

        if _G.ChatEdit_SetLastTellTarget then
            pcall(_G.ChatEdit_SetLastTellTarget, target, "BN_WHISPER")
        end
        if _G.ChatFrame_ReplyTell then
            pcall(_G.ChatFrame_ReplyTell, chatFrame or _G.DEFAULT_CHAT_FRAME)
        end
        
        editBox = _G.ChatFrame1EditBox or (chatFrame and chatFrame.editBox) or nil
        if editBox then
            if editBox.SetFocus then
                pcall(editBox.SetFocus, editBox)
            end
            self:UpdateInputPrompt(editBox)
        end
        return true
    end

    if not target then
        return false
    end

    if wantsBNet and type(bnetIDAccount) ~= "number" then
        return false
    end

    local fullWowTarget, shortWowTarget = KT_GetResolvedWoWWhisperTargets(target)
    KT_UpdateLastTellTarget(fullWowTarget or target, whisperType)
    self.activeWhisperTarget = target
    self.activeWhisperBNetAccountID = nil

    if _G.ChatEdit_SetLastTellTarget then
        pcall(_G.ChatEdit_SetLastTellTarget, fullWowTarget or target, "WHISPER")
    end
    if _G.ChatFrame_ReplyTell then
        pcall(_G.ChatFrame_ReplyTell, chatFrame or _G.DEFAULT_CHAT_FRAME)
    end

    editBox = _G.ChatFrame1EditBox or (chatFrame and chatFrame.editBox) or nil
    if editBox then
        if editBox.SetFocus then
            pcall(editBox.SetFocus, editBox)
        end
        self:RefreshChatFrameMode()
        return true
    end

    return false
end

function Mod:OpenDirectChannelTarget(channelTarget)
    local chatFrame = KT_GetReplyChatFrame()
    local channelTabIndex = self:GetTabIndexForLiveChatType("CHANNEL")
    local channelToken = KT_GetNonEmptyAccessibleString(channelTarget)
    local editBox = nil
    if not channelToken then
        return false
    end

    channelToken = strtrim(channelToken)
    if channelToken == "" then
        return false
    end

    self:ShowWindowForActivity()
    if channelTabIndex then
        self:SelectTab(channelTabIndex)
    end
    self:AttachBlizzardEditBox()

    local command = "/" .. channelToken .. " "
    if _G.ChatFrame_OpenChat and chatFrame then
        local ok, openedEditBox = pcall(_G.ChatFrame_OpenChat, command, chatFrame)
        if ok then
            editBox = openedEditBox or _G.ChatFrame1EditBox or (chatFrame and chatFrame.editBox) or nil
            if editBox then
                KT_ActivateChat(editBox)
                if editBox.SetFocus then
                    editBox:SetFocus()
                end
            end
            self:SyncVisibleEditBoxTarget(true, true)
            return true
        end
    end

    editBox = _G.ChatFrame1EditBox or (chatFrame and chatFrame.editBox) or nil
    if not editBox then
        return false
    end

    editBox:SetText(command)
    KT_ActivateChat(editBox)
    if editBox.SetFocus then
        editBox:SetFocus()
    end
    self:SyncVisibleEditBoxTarget(true, true)
    return true
end

function Mod:HandleWhisperHyperlink(link)
    if type(link) ~= "string" then
        return false
    end

    local linkType, linkData = link:match("^(.-):(.*)$")
    linkType = strlower(tostring(linkType or ""))
    if linkType == "player" then
        local target = KT_GetNonEmptyAccessibleString((strsplit(":", linkData)))
        if not target then
            return false
        end
        return self:OpenDirectWhisperTarget(target, nil, true)
    elseif linkType == "bnplayer" then
        local playerName, bnetIDAccount = strsplit(":", linkData)
        bnetIDAccount = tonumber(bnetIDAccount)
        local target = KT_ResolveBNetWhisperTarget(bnetIDAccount) or KT_GetNonEmptyAccessibleString(playerName)
        return self:OpenDirectWhisperTarget(target, bnetIDAccount)
    elseif linkType == "channel" then
        local _, channelTarget = strsplit(":", linkData)
        return self:OpenDirectChannelTarget(channelTarget)
    end

    return false
end

function Mod:HookBlizzardHyperlinkClicks()
    if self.blizzardHyperlinkHooked then
        return
    end

    self.blizzardHyperlinkHooked = true
    local function handle(_, link)
        local linkType = strlower(tostring((type(link) == "string" and link:match("^(.-):")) or ""))
        if linkType == "player" or linkType == "bnplayer" then
            return
        end
        if Mod and Mod.HandleWhisperHyperlink then
            pcall(Mod.HandleWhisperHyperlink, Mod, link)
        end
    end

    if _G.ChatFrame1 and _G.ChatFrame1.HookScript then
        _G.ChatFrame1:HookScript("OnHyperlinkClick", handle)
    end
end

function Mod:HookItemRefWhisperLinks()
    if self.itemRefWhisperHooked then
        return
    end

    self.itemRefWhisperHooked = true

    hooksecurefunc("SetItemRef", function(link)
        if Mod and Mod.itemRefWhisperBypass then return end
        local linkType = strlower(tostring((type(link) == "string" and link:match("^(.-):")) or ""))
        if linkType == "player" or linkType == "bnplayer" then
            return
        end
        if Mod and Mod.IsEnabled and Mod:IsEnabled() then
            pcall(Mod.HandleWhisperHyperlink, Mod, link)
        end
    end)

    if type(_G.ChatFrame_OnHyperlinkShow) == "function" then
        hooksecurefunc("ChatFrame_OnHyperlinkShow", function(_, link)
            if Mod and Mod.itemRefWhisperBypass then return end
            local linkType = strlower(tostring((type(link) == "string" and link:match("^(.-):")) or ""))
            if linkType == "player" or linkType == "bnplayer" then
                return
            end
            if Mod and Mod.IsEnabled and Mod:IsEnabled() then
                pcall(Mod.HandleWhisperHyperlink, Mod, link)
            end
        end)
    end
end

function Mod:OpenBlizzardSettings()
    KT_OpenBlizzardChatSettings()
end

function Mod:OpenPanelColorPicker()
    local color = self.db.panelColor or CopyTable(KT_CHAT_DEFAULT_PANEL_COLOR)
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = color.r,
            g = color.g,
            b = color.b,
            opacity = color.a or 1,
            hasOpacity = true,
            swatchFunc = function()
                local r, g, b = ColorPickerFrame:GetColorRGB()
                local a = ColorPickerFrame:GetColorAlpha()
                self.db.panelColor = { r = r, g = g, b = b, a = a }
                self:ApplyPanelColor()
            end,
            cancelFunc = function(previous)
                if previous then
                    self.db.panelColor = { r = previous.r, g = previous.g, b = previous.b, a = previous.opacity or 1 }
                    self:ApplyPanelColor()
                end
            end,
        })
    end
end

function Mod:OpenSearchDialog()
    local tab = self:GetActiveTab()
    local title = KT_LText("Search Chat")
    if tab and tab.label then
        title = format(KT_LText("Search in %s"), tab.label)
    end
    StaticPopup_Show(KT_SEARCH_POPUP_KEY, nil, nil, {
        title = title,
        handler = function(text)
            self:AddTemporarySearchTab(text)
        end,
    })
end

local function GetCopyDialogBackgroundColor()
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin
    local color = skin and skin.blizzard and skin.blizzard.windowBackgroundColor
    return {
        (color and color.r) or 0.05,
        (color and color.g) or 0.05,
        (color and color.b) or 0.05,
        (color and color.a) or 0.98,
    }
end

function Mod:ApplyCopyDialogStyle()
    local dialog = self.copyDialog
    if not dialog then
        return
    end

    local color = self.db.panelColor or KT_CHAT_DEFAULT_PANEL_COLOR
    local alpha = color.a or 0
    local bgColor = GetCopyDialogBackgroundColor()

    if dialog.KT_Flat then
        dialog.KT_Flat:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    end
    if KT and KT.ApplyTexturedSurface then
        dialog.KT_Wash = KT:ApplyTexturedSurface(dialog, bgColor, 0.55)
    end
    if dialog.KT_BackdropFade then
        KT_ApplyGradient(dialog.KT_BackdropFade, "VERTICAL", { r = color.r, g = color.g, b = color.b, a = alpha * 0.18 }, { r = color.r, g = color.g, b = color.b, a = alpha * 0.02 })
    end
    if dialog.KT_ContentTopGlow then
        KT_ApplyGradient(dialog.KT_ContentTopGlow, "VERTICAL", { r = 1, g = 1, b = 1, a = alpha * 0.08 }, { r = 1, g = 1, b = 1, a = 0 })
    end
    if dialog.KT_ContentBottomShade then
        KT_ApplyGradient(dialog.KT_ContentBottomShade, "VERTICAL", { r = 0, g = 0, b = 0, a = 0 }, { r = 0, g = 0, b = 0, a = alpha * 0.16 })
    end
    if dialog.KT_GlassTop then
        KT_ApplyGradient(dialog.KT_GlassTop, "VERTICAL", { r = 1, g = 1, b = 1, a = alpha * 0.09 }, { r = 1, g = 1, b = 1, a = alpha * 0.01 })
    end
    if dialog.KT_GlassBottom then
        KT_ApplyGradient(dialog.KT_GlassBottom, "VERTICAL", { r = 0, g = 0, b = 0, a = alpha * 0.02 }, { r = 0, g = 0, b = 0, a = alpha * 0.18 })
    end
    if dialog.KT_FooterGlow then
        KT_ApplyGradient(dialog.KT_FooterGlow, "VERTICAL", { r = 1, g = 1, b = 1, a = alpha * 0.06 }, { r = 1, g = 1, b = 1, a = alpha * 0.01 })
    end
    if dialog.KT_LeftShade then
        KT_ApplyGradient(dialog.KT_LeftShade, "HORIZONTAL", { r = 0, g = 0, b = 0, a = alpha * 0.16 }, { r = 0, g = 0, b = 0, a = 0 })
    end
    if dialog.borderKT then
        for _, edge in ipairs(dialog.borderKT) do
            edge:SetVertexColor(0.9, 0.92, 1, 0.16)
        end
    end
    if dialog.KT_Title then
        dialog.KT_Title:SetTextColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, math.max(0.85, 1 - alpha))
    end
    if dialog.KT_HeaderLine then
        dialog.KT_HeaderLine:SetVertexColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 0.5 + alpha * 0.15)
    end
end

function Mod:EnsureCopyDialog()
    if self.copyDialog and self.copyDialog.KT_TextBox then
        return self.copyDialog
    end

    local dialog = CreateFrame("Frame", KT_COPY_DIALOG_NAME, UIParent, "BackdropTemplate")
    dialog:Hide()
    dialog:SetToplevel(true)
    dialog:SetFrameStrata("DIALOG")
    dialog:SetSize(820, 560)
    dialog:SetPoint("CENTER")
    dialog:EnableMouse(true)
    if dialog.SetPropagateMouseEvents then
        dialog:SetPropagateMouseEvents(false)
    end
    if not tContains(UISpecialFrames, KT_COPY_DIALOG_NAME) then
        tinsert(UISpecialFrames, KT_COPY_DIALOG_NAME)
    end

    local bgColor = GetCopyDialogBackgroundColor()
    KT:AddBorder(dialog, 0.9, 0.92, 1, 0.16, 1)
    if not dialog.KT_Flat then
        dialog.KT_Flat = dialog:CreateTexture(nil, "BACKGROUND", nil, -8)
        dialog.KT_Flat:SetAllPoints(dialog)
    end
    dialog.KT_Flat:SetColorTexture(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
    if KT and KT.ApplyTexturedSurface then
        dialog.KT_Wash = KT:ApplyTexturedSurface(dialog, bgColor, 0.55)
    end

    local glassTop = dialog:CreateTexture(nil, "ARTWORK", nil, -1)
    glassTop:SetPoint("TOPLEFT", 1, -1)
    glassTop:SetPoint("TOPRIGHT", -1, -1)
    glassTop:SetHeight(math.floor(dialog:GetHeight() * 0.45))
    dialog.KT_GlassTop = glassTop

    local leftShade = dialog:CreateTexture(nil, "ARTWORK", nil, -1)
    leftShade:SetPoint("TOPLEFT", 1, -1)
    leftShade:SetPoint("BOTTOMLEFT", 1, 1)
    leftShade:SetWidth(math.floor(dialog:GetWidth() * 0.22))
    dialog.KT_LeftShade = leftShade

    local glassBottom = dialog:CreateTexture(nil, "ARTWORK", nil, -1)
    glassBottom:SetPoint("BOTTOMLEFT", 1, 1)
    glassBottom:SetPoint("BOTTOMRIGHT", -1, 1)
    glassBottom:SetHeight(math.floor(dialog:GetHeight() * 0.42))
    dialog.KT_GlassBottom = glassBottom

    local content = CreateFrame("Frame", nil, dialog)
    content:SetPoint("TOPLEFT", dialog, "TOPLEFT", 12, -44)
    content:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 46)
    content:SetFrameLevel((dialog:GetFrameLevel() or 0) + 1)

    local fade = content:CreateTexture(nil, "BACKGROUND", nil, -1)
    fade:SetAllPoints()
    dialog.KT_BackdropFade = fade

    local contentTopGlow = content:CreateTexture(nil, "ARTWORK")
    contentTopGlow:SetPoint("TOPLEFT", 0, 0)
    contentTopGlow:SetPoint("TOPRIGHT", 0, 0)
    contentTopGlow:SetHeight(38)
    dialog.KT_ContentTopGlow = contentTopGlow

    local contentBottomShade = content:CreateTexture(nil, "BORDER")
    contentBottomShade:SetPoint("BOTTOMLEFT", 0, 0)
    contentBottomShade:SetPoint("BOTTOMRIGHT", 0, 0)
    contentBottomShade:SetHeight(72)
    dialog.KT_ContentBottomShade = contentBottomShade

    local footerGlow = dialog:CreateTexture(nil, "BORDER", nil, -1)
    footerGlow:SetPoint("BOTTOMLEFT", 1, 1)
    footerGlow:SetPoint("BOTTOMRIGHT", -1, 1)
    footerGlow:SetHeight(46)
    dialog.KT_FooterGlow = footerGlow

    local title = dialog:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT_DEFAULT_FONT, 14, "OUTLINE")
    title:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -12)
    title:SetText(KT_LText("Copy Chat"))
    title:SetTextColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 0.9)
    dialog.KT_Title = title

    local headerLine = dialog:CreateTexture(nil, "OVERLAY")
    headerLine:SetPoint("TOPLEFT", dialog, "TOPLEFT", 18, -36)
    headerLine:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -48, -36)
    headerLine:SetHeight(2)
    headerLine:SetTexture("Interface\\Buttons\\WHITE8X8")
    headerLine:SetVertexColor(KT_BRAND_COLOR.r, KT_BRAND_COLOR.g, KT_BRAND_COLOR.b, 0.55)
    dialog.KT_HeaderLine = headerLine

    local closeButton = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -10, -10)
    closeButton:SetFrameLevel((dialog:GetFrameLevel() or 0) + 6)
    KT_SetButtonBackdrop(closeButton)
    closeButton:SetBackdropColor(0.1, 0.03, 0.04, 0.9)
    closeButton:SetBackdropBorderColor(0.55, 0.2, 0.24, 0.9)
    closeButton:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local xHighlight = closeButton:GetHighlightTexture()
    if xHighlight then
        xHighlight:SetVertexColor(1, 0.35, 0.35, 0.25)
    end
    closeButton.Text = closeButton:CreateFontString(nil, "OVERLAY")
    closeButton.Text:SetFont(KT_DEFAULT_FONT, 13, "OUTLINE")
    closeButton.Text:SetPoint("CENTER", 0, 0)
    closeButton.Text:SetText("x")
    closeButton.Text:SetTextColor(1, 0.9, 0.9, 1)
    closeButton:SetScript("OnClick", function()
        dialog:Hide()
        if _G.PlaySound then
            _G.PlaySound(_G.SOUNDKIT and _G.SOUNDKIT.IG_MAINMENU_CLOSE or 852)
        end
    end)
    if KT_SetTooltip then
        pcall(KT_SetTooltip, closeButton, KT_LText("Close"))
    end
    dialog.KT_CloseButton = closeButton

    local textBox = CreateFrame("Frame", nil, dialog, "ScrollingEditBoxTemplate")
    textBox:SetPoint("TOPLEFT", dialog, "TOPLEFT", 16, -46)
    textBox:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -38, 44)

    local scrollBar = textBox.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", dialog, "TOPRIGHT", -22, -38)
        scrollBar:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -22, 50)
        scrollBar:Show()
        if scrollBar.SetWidth then
            scrollBar:SetWidth(18)
        end
    end

    local copyButton = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    copyButton:SetSize(118, 26)
    copyButton:SetPoint("BOTTOMRIGHT", dialog, "BOTTOMRIGHT", -12, 10)
    copyButton:SetFrameLevel((dialog:GetFrameLevel() or 0) + 6)
    KT_StyleActionButton(copyButton)
    copyButton.KT_Icon = KT_StyleActionTexture(copyButton, KT_CHAT_ICON_PATH .. "CopyChat.png", true)
    copyButton.KT_Icon:SetSize(14, 14)
    copyButton.KT_Icon:SetPoint("LEFT", copyButton, "LEFT", 9, 0)
    copyButton.KT_Text = KT_StyleActionText(copyButton, KT_LText("Copy All"), 11)
    copyButton.KT_Text:SetPoint("CENTER", copyButton, "CENTER", 8, 0)
    if KT_SetTooltip then
        pcall(KT_SetTooltip, copyButton, KT_LText("Copy Chat"))
    end
    copyButton:SetScript("OnClick", function()
        local editBox = textBox:GetEditBox()
        if editBox and editBox.GetText then
            local text = editBox:GetText()
            if text and text ~= "" then
                editBox:SetFocus()
                editBox:HighlightText()
                if editBox.Copy then
                    pcall(editBox.Copy, editBox)
                end
            end
        end
    end)
    dialog.KT_CopyButton = copyButton

    local clearButton = CreateFrame("Button", nil, dialog, "BackdropTemplate")
    clearButton:SetSize(100, 26)
    clearButton:SetPoint("BOTTOMRIGHT", copyButton, "BOTTOMLEFT", -6, 0)
    clearButton:SetFrameLevel((dialog:GetFrameLevel() or 0) + 6)
    KT_StyleActionButton(clearButton)
    clearButton.KT_Icon = KT_StyleActionTexture(clearButton, KT_CHAT_ICON_PATH .. "trash.png", false)
    clearButton.KT_Icon:SetSize(14, 14)
    clearButton.KT_Icon:SetPoint("LEFT", clearButton, "LEFT", 9, 0)
    clearButton.KT_Text = KT_StyleActionText(clearButton, KT_LText("Clear All"), 11)
    clearButton.KT_Text:SetPoint("CENTER", clearButton, "CENTER", 7, 0)
    if KT_SetTooltip then
        pcall(KT_SetTooltip, clearButton, KT_LText("Clear Chat"))
    end
    clearButton:SetScript("OnClick", function()
        local editBox = textBox:GetEditBox()
        if editBox and editBox.SetText then
            editBox:SetText("")
        end
    end)
    dialog.KT_ClearButton = clearButton

    dialog.KT_Content = content
    dialog.KT_TextBox = textBox
    dialog.KT_TextScrollBar = scrollBar

    self.copyDialog = dialog
    self:ApplyCopyDialogStyle()
    return dialog
end

function Mod:OpenCopyDialog()
    local dialog = self:EnsureCopyDialog()
    local textBox = dialog.KT_TextBox
    if not textBox or not textBox.GetEditBox then
        return
    end

    if dialog.KT_Title then
        dialog.KT_Title:SetText(KT_LText("Copy Chat"))
    end

    self:ApplyCopyDialogStyle()

    local messages = {}
    local seenFrames = {}

    local function AppendFrameMessages(frame)
        if not frame or seenFrames[frame] then
            return
        end
        seenFrames[frame] = true

        if frame.GetNumMessages and frame.GetMessageInfo then
            local okCount, numMessages = pcall(frame.GetNumMessages, frame)
            if okCount and type(numMessages) == "number" and numMessages > 0 then
                for index = 1, numMessages do
                    local okInfo, text = pcall(frame.GetMessageInfo, frame, index)
                    local accessibleText = okInfo and KT_GetNonEmptyAccessibleString(text) or nil
                    if accessibleText then
                        tinsert(messages, KT_SanitizeCopyText(accessibleText))
                    end
                end
            end
        end
    end

    local activeFrame = self.GetActiveMessageFrame and self:GetActiveMessageFrame() or nil
    AppendFrameMessages(activeFrame)
    AppendFrameMessages(_G.DEFAULT_CHAT_FRAME)
    AppendFrameMessages(_G.ChatFrame1)

    if #messages == 0 then
        local activeTab = self:GetActiveTab()
        local filter = activeTab and activeTab.filter

        for _, entry in ipairs(self.history) do
            if not filter or filter(entry) then
                tinsert(messages, KT_SanitizeCopyText(self:GetEntryMessage(entry, false)))
            end
        end
    end

    local text = table.concat(messages, "\n")
    if text == "" then
        text = KT_LText("No chat text available to copy.")
    end

    textBox:SetText(text)
    local editBox = textBox:GetEditBox()
    if editBox then
        if editBox.SetCursorPosition then
            editBox:SetCursorPosition(0)
        end
        editBox:HighlightText(0, #editBox:GetText())
        C_Timer.After(0, function()
            if textBox.ScrollToBegin then
                textBox:ScrollToBegin()
            elseif dialog.KT_TextScrollBar and dialog.KT_TextScrollBar.SetValue then
                local minValue = 0
                if dialog.KT_TextScrollBar.GetMinMaxValues then
                    minValue = dialog.KT_TextScrollBar:GetMinMaxValues()
                end
                dialog.KT_TextScrollBar:SetValue(minValue or 0)
            end
            editBox:SetFocus()
            editBox:HighlightText(0, #editBox:GetText())
        end)
    end

    dialog:Show()
    if _G.PlaySound then
        _G.PlaySound(_G.SOUNDKIT and _G.SOUNDKIT.IG_MAINMENU_OPEN or 856)
    end
end

function Mod:ClearHistory()
    local activeFrame = self.GetActiveMessageFrame and self:GetActiveMessageFrame() or nil
    local isNativeFrame = activeFrame == _G.ChatFrame1 or activeFrame == self.combatLogChatFrame
    if not isNativeFrame then
        for _, frame in pairs(self.nativeTabFrames or {}) do
            if frame == activeFrame then
                isNativeFrame = true
                break
            end
        end
    end

    local wipeFunc = _G.wipe or table.wipe

    self.history = self.history or {}
    if wipeFunc then
        wipeFunc(self.history)
    else
        self.history = {}
    end

    if self.db then
        self.db.history = self.db.history or {}
        if wipeFunc then
            wipeFunc(self.db.history)
        else
            self.db.history = {}
        end
    end

    if isNativeFrame and activeFrame then
        if _G.FCF_ClearChatWindow then
            pcall(_G.FCF_ClearChatWindow, activeFrame)
        elseif activeFrame.Clear then
            pcall(activeFrame.Clear, activeFrame)
        end
        self:RenderAllFrames()
        self:UpdateScrollButtonVisibility()
        if KT and KT.Print then
            KT:Print(KT_LText("Chat cleared."))
        end
        return
    end

    for _, frame in ipairs(self.messageFrames or {}) do
        if frame and frame.Clear then
            pcall(frame.Clear, frame)
        end
    end

    for _, frame in pairs(self.nativeTabFrames or {}) do
        self:ClearNativeChatFrameContent(frame)
    end

    self:RenderAllFrames()

    local activeFrame = self.GetActiveMessageFrame and self:GetActiveMessageFrame() or nil
    if activeFrame and activeFrame.ScrollToBottom then
        pcall(activeFrame.ScrollToBottom, activeFrame)
    end

    self:UpdateScrollButtonVisibility()
    if KT and KT.Print then
        KT:Print(KT_LText("Chat cleared."))
    end
end

function Mod:OpenQuickChatMenu(anchor)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchor, function(_, rootDescription)
            rootDescription:CreateButton(KT_LText("Focus Input"), function()
                self:FocusInputForActiveTab()
            end)
            rootDescription:CreateButton(KT_LText("Search This Tab"), function()
                self:OpenSearchDialog()
            end)
            rootDescription:CreateButton(KT_LText("Copy Chat"), function()
                self:OpenCopyDialog()
            end)
            rootDescription:CreateButton(KT_LText("Clear Chat"), function()
                self:ClearHistory()
            end)
            rootDescription:CreateButton(KT_LText("Chat Settings"), function()
                KT_OpenBlizzardChatSettings()
            end)
            rootDescription:CreateButton(KT_LText("Panel Color"), function()
                self:OpenPanelColorPicker()
            end)
        end)
        return
    end

    self:FocusInputForActiveTab()
end

function Mod:OpenTabMenu(tabButton, tabIndex)
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(tabButton, function(_, rootDescription)
            rootDescription:CreateButton(KT_LText("Search This Tab"), function()
                self:OpenSearchDialog()
            end)
            if self.tabs and self.tabs[tabIndex] and self.tabs[tabIndex].temporary then
                rootDescription:CreateButton(KT_LText("Close Search Tab"), function()
                    tremove(self.tabs, tabIndex)
                    self.selectedTabIndex = math.max(1, tabIndex - 1)
                    self:RefreshTabButtons()
                    self:SelectTab(self.selectedTabIndex)
                    self:RenderAllFrames()
                end)
            end
            rootDescription:CreateButton(KT_LText("Chat Settings"), function()
                KT_OpenBlizzardChatSettings()
            end)
            rootDescription:CreateButton(KT_LText("Panel Color"), function()
                self:OpenPanelColorPicker()
            end)
        end)
        return
    end

    KT_OpenBlizzardChatSettings()
end

function Mod:SelectTab(selectedIndex)
    self.selectedTabIndex = selectedIndex
    local window = _G.KT_ChatWindow
    if not window or not window.KT_Tabs then
        return
    end

    local editBox = _G.ChatFrame1EditBox
    local inputTabAlpha = (editBox and editBox:IsShown()) and 0.18 or 0.108

    for index, tab in ipairs(window.KT_Tabs) do
        if tab:IsShown() then
            local panelColor = self.db.panelColor or KT_CHAT_DEFAULT_PANEL_COLOR
            local highlightColor = self:GetHighlightColor()
            local highlightTexture = self:GetTabHighlightTexture()
            local tabInfo = self.tabs and self.tabs[index]
            local baseR, baseG, baseB = self:GetTabTextColor((tabInfo and tabInfo.filterMode) or (tabInfo and tabInfo.id))
            if index == selectedIndex then
                tab:SetBackdropColor(panelColor.r * 0.32, panelColor.g * 0.32, panelColor.b * 0.32, inputTabAlpha)
                tab:SetBackdropBorderColor(0, 0, 0, 0)
                tab.Text:SetTextColor(baseR, baseG, baseB, 1)
                if tab.KT_SelectedBorder then
                    tab.KT_SelectedBorder:Hide()
                end
                if tab.KT_Gloss then
                    KT_ApplyGradient(tab.KT_Gloss, "VERTICAL", { r = 1, g = 1, b = 1, a = 0.03 }, { r = 1, g = 1, b = 1, a = 0 })
                end
            else
                tab:SetBackdropColor(panelColor.r * 0.25, panelColor.g * 0.25, panelColor.b * 0.25, 0.05)
                tab:SetBackdropBorderColor(0, 0, 0, 0)
                tab.Text:SetTextColor(baseR, baseG, baseB, 0.92)
                if tab.KT_SelectedBorder then
                    tab.KT_SelectedBorder:Hide()
                end
                if tab.KT_Gloss then
                    KT_ApplyGradient(tab.KT_Gloss, "VERTICAL", { r = 1, g = 1, b = 1, a = 0.015 }, { r = 1, g = 1, b = 1, a = 0 })
                end
            end
        end
    end

    local frame = _G.KT_ChatFrame
    if frame then
        local tab = self:GetActiveTab()
        frame.KT_FilterFunc = tab and tab.filter or nil
    end

    if self.bridgeFrames then
        local tab = self:GetActiveTab()
        for _, bFrame in pairs(self.bridgeFrames) do
            if bFrame then
                bFrame.KT_FilterFunc = tab and tab.filter or nil
            end
        end
    end

    -- Toggle whisper strip visibility based on active tab.
    local window = _G.KT_ChatWindow
    local strip = window and window.KT_WhisperStrip
    if strip then
        local hasTargets = self.whisperTargets and #self.whisperTargets > 0
        strip:SetShown(hasTargets == true)
        self:ApplyNormalChatFrameLayout()
    end

    self:RefreshChatFrameMode()
    self:UpdateCombatLogRegistration()

    -- Re-render KT_ChatFrame with the current tab filter when it is the
    -- active visible frame (e.g. Whisper or Search tabs). Without this,
    -- switching tabs would leave stale entries from a previous filter.
    if frame and frame:IsShown() then
        self:RenderFrame(frame)
    end
    self:UpdateInputPrompt(_G.ChatFrame1EditBox)
end

function Mod:ActivateTab(index)
    if not self.tabs or not self.tabs[index] then
        return
    end

    local tabInfo = self.tabs[index]
    if tabInfo then
        local idLower = tostring(tabInfo.id or ""):lower()
        local modeUpper = tostring(tabInfo.filterMode or ""):upper()
        if idLower:find("whisp") or modeUpper:find("WHISP") then
            self.selectedWhisperThread = nil
            self.activeWhisperTarget = nil
            self.activeWhisperBNetAccountID = nil
        end
    end

    self:SelectTab(index)

    local tab = self:GetActiveTab()
    if tab and not self:IsCombatTab(tab) then
        self:FocusInputForActiveTab()
    end
    self:RenderAllFrames()
end

function Mod:EnsureTabButton(index)
    local window = _G.KT_ChatWindow
    if not window or not window.KT_TabsHolder then
        return nil
    end

    window.KT_Tabs = window.KT_Tabs or {}
    if window.KT_Tabs[index] then
        return window.KT_Tabs[index]
    end

    local tab = CreateFrame("Button", nil, window.KT_TabsHolder, "BackdropTemplate")
    KT_SetButtonBackdrop(tab)
    tab:SetHeight(28)
    tab:SetBackdropBorderColor(0, 0, 0, 0)
    tab:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    tab.KT_SelectedBorder = CreateFrame("Frame", nil, tab)
    tab.KT_SelectedBorder:SetAllPoints(tab)
    tab.KT_SelectedBorder:SetFrameLevel(tab:GetFrameLevel() + 1)
    tab.KT_SelectedEdges = {}
    tab.KT_SelectedEdges[1] = tab.KT_SelectedBorder:CreateTexture(nil, "OVERLAY")
    tab.KT_SelectedEdges[1]:SetPoint("TOPLEFT", 0, 0)
    tab.KT_SelectedEdges[1]:SetPoint("TOPRIGHT", 0, 0)
    tab.KT_SelectedEdges[1]:SetHeight(2)
    tab.KT_SelectedEdges[2] = tab.KT_SelectedBorder:CreateTexture(nil, "OVERLAY")
    tab.KT_SelectedEdges[2]:SetPoint("BOTTOMLEFT", 0, 0)
    tab.KT_SelectedEdges[2]:SetPoint("BOTTOMRIGHT", 0, 0)
    tab.KT_SelectedEdges[2]:SetHeight(2)
    tab.KT_SelectedEdges[3] = tab.KT_SelectedBorder:CreateTexture(nil, "OVERLAY")
    tab.KT_SelectedEdges[3]:SetPoint("TOPLEFT", 0, -2)
    tab.KT_SelectedEdges[3]:SetPoint("BOTTOMLEFT", 0, 2)
    tab.KT_SelectedEdges[3]:SetWidth(2)
    tab.KT_SelectedEdges[4] = tab.KT_SelectedBorder:CreateTexture(nil, "OVERLAY")
    tab.KT_SelectedEdges[4]:SetPoint("TOPRIGHT", 0, -2)
    tab.KT_SelectedEdges[4]:SetPoint("BOTTOMRIGHT", 0, 2)
    tab.KT_SelectedEdges[4]:SetWidth(2)
    tab.KT_SelectedBorder:Hide()
    tab.KT_Gloss = tab:CreateTexture(nil, "ARTWORK")
    tab.KT_Gloss:SetPoint("TOPLEFT", 1, -1)
    tab.KT_Gloss:SetPoint("TOPRIGHT", -1, -1)
    tab.KT_Gloss:SetHeight(14)
    tab.Text = tab:CreateFontString(nil, "OVERLAY")
    tab.Text:SetFont(KT_DEFAULT_FONT, 13, "OUTLINE")
    tab.Text:SetPoint("LEFT", tab, "LEFT", 8, 0)
    tab.Text:SetPoint("RIGHT", tab, "RIGHT", -8, 0)
    tab.Text:SetJustifyH("CENTER")
    tab.Text:SetJustifyV("MIDDLE")
    if tab.Text.SetWordWrap then tab.Text:SetWordWrap(false) end
    if tab.Text.SetNonSpaceWrap then tab.Text:SetNonSpaceWrap(false) end
    if tab.Text.SetMaxLines then pcall(tab.Text.SetMaxLines, tab.Text, 1) end
    window.KT_Tabs[index] = tab
    return tab
end

function Mod:RefreshTabButtons()
    local window = _G.KT_ChatWindow
    if not window or not window.KT_TabsHolder then
        return
    end

    window.KT_Tabs = window.KT_Tabs or {}

    local tabs = self.tabs or {}
    local tabCount = #tabs
    if tabCount == 0 then
        self:ResetTabs()
        tabs = self.tabs or {}
        tabCount = #tabs
    end
    if tabCount == 0 then
        return
    end

    if not self.selectedTabIndex or self.selectedTabIndex < 1 or self.selectedTabIndex > tabCount then
        self.selectedTabIndex = 1
    end

    local spacing = 3
    local holderWidth = math.max(0, window.KT_TabsHolder:GetWidth() or 0)
    if holderWidth <= 0 and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            local win = _G.KT_ChatWindow
            if win and win:IsShown() then
                self:RefreshTabButtons()
            end
        end)
    end

    local padding = 28
    local idealWidths = {}
    local totalIdeal = 0
    for index, tabInfo in ipairs(tabs) do
        local tab = self:EnsureTabButton(index)
        local label = tabInfo.label or "Tab"
        tab.Text:SetText(label)
        local width = math.max(74, (tab.Text:GetStringWidth() or 0) + padding)
        idealWidths[index] = width
        totalIdeal = totalIdeal + width
    end

    local available = holderWidth - (spacing * (tabCount - 1))
    local useCompressed = (holderWidth > 0) and (totalIdeal > available)
    local perTabWidth
    if useCompressed then
        perTabWidth = math.max(10, math.floor(available / tabCount))
    end

    local previous
    for index, tabInfo in ipairs(tabs) do
        local tab = self:EnsureTabButton(index)
        local label = tabInfo.label or "Tab"
        tab:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                self:OpenTabMenu(tab, index)
            elseif button == "MiddleButton" and tabInfo.temporary then
                tremove(tabs, index)
                self.selectedTabIndex = math.max(1, index - 1)
                self:RefreshTabButtons()
                self:SelectTab(self.selectedTabIndex)
                self:RenderAllFrames()
            else
                self:ActivateTab(index)
            end
        end)
        KT_SetTooltip(tab, tabInfo.tooltip or label)

        tab:ClearAllPoints()
        tab:Show()
        tab:SetWidth(useCompressed and perTabWidth or (idealWidths[index] or 74))
        if previous then
            tab:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
        else
            tab:SetPoint("LEFT", window.KT_TabsHolder, "LEFT", 0, 0)
        end
        previous = tab
    end

    for index = tabCount + 1, #window.KT_Tabs do
        window.KT_Tabs[index]:Hide()
    end

    self:SelectTab(self.selectedTabIndex)
end
function Mod:ADDON_LOADED(event, addonName)
    if addonName ~= KT_CHATTYNATOR_NAME then
        return
    end

    self:RegisterChattynatorBridge()
end

function Mod:RegisterChatEvents()
    if self.chatEventsRegistered then
        return
    end

    -- In the native-Blizzard chat model we no longer mirror CHAT_MSG_* through
    -- addon-controlled handlers. Leaving ChatFrame1's own OnEvent path alone
    -- avoids retail HistoryKeeper taint on secret party/raid payloads.
    --
    -- On secure-chat retail builds, avoid Blizzard's
    -- ChatFrame_AddMessageEventFilter path entirely. Also avoid registering an
    -- addon-owned frame for whisper events: touching BN_WHISPER's secret
    -- payload before Blizzard's MessageEventHandler can taint HistoryKeeper's
    -- protected access-ID tables.
    self.chatEventsRegistered = true

    if KT_IsSecureChatSafeMode() then
        -- KUI Chat: We no longer UnregisterAllEvents as it breaks whisper flow.
        -- Let Blizzard's native frames own the complete message path. In
        -- particular, do not register ChatFrame_AddMessageEventFilter callbacks:
        -- its registry is shared by every addon and may be protected while raid,
        -- instance and Battleground messages contain secret values.
        return
    end

    if ChatFrame_AddMessageEventFilter then
        local function privateSystemFilter(chatFrame, event, message)
            if event ~= "CHAT_MSG_SYSTEM" or not chatFrame or type(chatFrame.privateMessageList) ~= "table" then
                return false
            end

            -- Blizzard's private whisper frames lowercase system text while
            -- checking player-specific notices. Secret strings fault there
            -- if the chat path is already tainted, so drop only those hidden
            -- system payloads before the native handler reaches strlower().
            if type(message) == "string" and not KT_CanAccessValue(message) then
                return true
            end

            return false
        end

        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", privateSystemFilter)

        local lastWhisperDedupeKey
        local lastWhisperDedupeAt = 0
        local function whisperFilter(chatFrame, event, ...)
            if not (Mod and Mod.runtimeInitialized and Mod.chatEventsRegistered) then
                return false
            end

            -- Filters fire once per ChatFrame receiving the event.
            -- BN whispers do not expose the same payload layout as regular
            -- whispers, so we use a short-lived composite key instead.
            local dedupeKey = KT_BuildWhisperEventDedupeKey(event, ...)
            local now = GetTime and GetTime() or 0
            local isDuplicate = dedupeKey ~= "" and dedupeKey == lastWhisperDedupeKey and (now - lastWhisperDedupeAt) < 0.1

            -- Profanity-filtered whispers can arrive as protected values. Do
            -- not read or suppress them; mirror Blizzard's already-rendered
            -- yellow clickable placeholder from ChatFrame1 instead.
            local rawMessage = select(1, ...)
            if not KT_GetNonEmptyAccessibleString(rawMessage) then
                if not isDuplicate and Mod.RequestSecretMirror then
                    local chatType = tostring(event or ""):gsub("^CHAT_MSG_", "")
                    local sender = KT_GetNonEmptyAccessibleString(select(2, ...))
                    Mod:RequestSecretMirror({
                        event = event,
                        chatType = chatType,
                        timestamp = date("%H:%M"),
                        label = KT_GetDisplayChatLabel(chatType) or chatType,
                        author = sender and KT_AmbiguateAccessibleName(sender, sender) or nil,
                        authorRaw = sender,
                        senderGUID = KT_GetNonEmptyAccessibleString(select(12, ...)),
                    })
                end
                return false
            end

            local handled = isDuplicate
            if not isDuplicate then
                lastWhisperDedupeKey = dedupeKey
                lastWhisperDedupeAt = now
                local ok, result = pcall(Mod.OnWhisperEvent, Mod, event, ...)
                handled = ok and result == true
            end

            -- Suppress Blizzard only after KUI accepted the message. This
            -- preserves outgoing whispers when an AFK/system payload prevents
            -- KUI from constructing its own entry.
            return handled
        end
        ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", whisperFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", whisperFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", whisperFilter)
        ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", whisperFilter)
    end
end

function Mod:HookBlizzardMessageMirror()
    if self.blizzardMessageMirrorHooked or not _G.ChatFrame1 or not hooksecurefunc then
        return
    end

    self.blizzardMessageMirrorHooked = true
    hooksecurefunc(_G.ChatFrame1, "AddMessage", function(_, text, r, g, b)
        if not Mod then
            return
        end

        local pendingRendered = Mod.pendingRenderedMirrors or 0
        local pendingSecret = Mod.pendingSecretMirrors or 0
        if pendingRendered <= 0 and pendingSecret <= 0 then
            return
        end

        local rendered = KT_GetNonEmptyAccessibleString(text)
        if not rendered then
            return
        end

        local lastEntry = Mod.history and Mod.history[#Mod.history]
        if lastEntry then
            if lastEntry.preformatted and KT_IsRenderedTextDuplicate(lastEntry.message, rendered) then
                if pendingRendered > 0 then
                    Mod.pendingRenderedMirrors = math.max(0, pendingRendered - 1)
                elseif pendingSecret > 0 then
                    Mod.pendingSecretMirrors = math.max(0, pendingSecret - 1)
                end
                return
            end

            if not lastEntry.preformatted and KT_IsRenderedMirrorDuplicate(rendered, lastEntry) then
                if pendingRendered > 0 then
                    Mod.pendingRenderedMirrors = math.max(0, pendingRendered - 1)
                elseif pendingSecret > 0 then
                    Mod.pendingSecretMirrors = math.max(0, pendingSecret - 1)
                end
                return
            end
        end

        if pendingRendered > 0 then
            Mod.pendingRenderedMirrors = math.max(0, pendingRendered - 1)
        elseif pendingSecret > 0 then
            Mod.pendingSecretMirrors = math.max(0, pendingSecret - 1)
        end

        local secretMirrorMeta = nil
        if pendingSecret > 0 and Mod.pendingSecretMirrorEntries and #Mod.pendingSecretMirrorEntries > 0 then
            secretMirrorMeta = tremove(Mod.pendingSecretMirrorEntries, 1)
        end

        local entry = {
            preformatted = true,
            message = rendered,
            rawMessage = rendered,
            r = r or 1,
            g = g or 1,
            b = b or 1,
            event = (secretMirrorMeta and secretMirrorMeta.event) or "CHAT_MSG_MIRROR",
            chatType = (secretMirrorMeta and secretMirrorMeta.chatType) or "MIRROR",
            timestamp = (secretMirrorMeta and secretMirrorMeta.timestamp) or date("%H:%M"),
            label = (secretMirrorMeta and secretMirrorMeta.label) or "",
            channelName = secretMirrorMeta and secretMirrorMeta.channelName or nil,
            author = secretMirrorMeta and secretMirrorMeta.author or nil,
            authorRaw = secretMirrorMeta and secretMirrorMeta.authorRaw or nil,
            senderGUID = secretMirrorMeta and secretMirrorMeta.senderGUID or nil,
            persist = false,
            searchText = Mod:BuildSearchText({
                secretMirrorMeta and secretMirrorMeta.label or "",
                secretMirrorMeta and secretMirrorMeta.channelName or "",
                secretMirrorMeta and secretMirrorMeta.author or "",
                rendered,
            }),
        }

        Mod:RecordChatActivity()
        Mod:PushHistory(entry)
        Mod:ShowWindowForActivity(false)
        Mod:AddEntryToFrames(entry)
        Mod:ScheduleWindowFade()
        Mod:UpdateScrollButtonVisibility()
    end)
end

local function KT_GetHiddenChatParent()
    if KT_CHAT_HIDDEN_PARENT and KT_CHAT_HIDDEN_PARENT.GetObjectType then
        return KT_CHAT_HIDDEN_PARENT
    end

    local parent = CreateFrame("Frame", "KT_ChatHiddenParent", UIParent)
    parent:SetSize(1, 1)
    parent:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -5000, -5000)
    parent:Hide()
    KT_CHAT_HIDDEN_PARENT = parent
    return parent
end

function Mod:EnsureMessageMonitor()
    if self.messageMonitor and self.messageMonitor.MessageEventHandler then
        return self.messageMonitor
    end

    local frame = CreateFrame("ScrollingMessageFrame", "KT_ChatMessageMonitor", KT_GetHiddenChatParent(), "ChatFrameTemplate")
    frame:SetMaxLines(128)
    frame:SetFading(false)
    frame:SetIndentedWordWrap(true)
    frame:SetInsertMode("BOTTOM")
    frame:SetJustifyH("LEFT")
    frame:SetFont(STANDARD_TEXT_FONT or KT_DEFAULT_FONT, 12, "")
    frame:Hide()

    frame.editBox = _G.ChatFrame1EditBox
    frame.channelList = frame.channelList or {}
    frame.zoneChannelList = frame.zoneChannelList or {}
    frame.messageTypeList = frame.messageTypeList or {}
    frame.privateMessageList = frame.privateMessageList or {}
    frame.historyBuffer = frame.historyBuffer or { elements = { 1 } }

    frame.KT_OriginalAddMessage = frame.AddMessage
    frame.AddMessage = function(widget, renderedText, r, g, b)
        local capture = widget.KT_Capture
        if not capture then
            return
        end

        local rendered = KT_GetNonEmptyAccessibleString(renderedText)
        if not rendered then
            return
        end

        tinsert(capture.entries, {
            message = rendered,
            r = r or 1,
            g = g or 1,
            b = b or 1,
        })
    end

    self.messageMonitor = frame
    return frame
end

function Mod:BuildPreformattedEntryFromMonitor(event, renderedMessage, r, g, b, ...)
    local rendered = KT_GetNonEmptyAccessibleString(renderedMessage)
    if not rendered then
        return nil
    end

    local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14 = ...
    local chatType = tostring(event or ""):gsub("^CHAT_MSG_", "")
    local sender = KT_GetNonEmptyAccessibleString(arg2)
    local senderFull = sender
    local bnSenderID = KT_IsBNetWhisperEvent(event) and KT_GetBNetWhisperSenderID(arg13, arg14) or nil
    local author = nil
    if sender then
        if chatType:find("^BN_", 1, true) then
            author = (type(bnSenderID) == "number" and KT_ResolveBNetWhisperTarget(bnSenderID)) or sender
        else
            local ok, shortened = pcall(Ambiguate, sender, "short")
            author = ok and KT_GetNonEmptyAccessibleString(shortened, sender) or sender
        end
    end

    local channelName = KT_ResolveChannelDisplayName(chatType, arg4, arg9)
    local senderGUID = KT_GetNonEmptyAccessibleString(arg12)
    local lineID = KT_GetWhisperEventLineID(event, arg11)
    local timestamp = date("%H:%M")
    local hasSecrets = false
    local hasSecretsOk, hasSecretsValue = pcall(hasanysecretvalues, ...)
    if hasSecretsOk and hasSecretsValue then
        hasSecrets = true
    end

    local normalizedType, normalizedMessage, normalizedAuthor, normalizedLabel, normalizedChannel, normalizedSenderGUID =
        KT_NormalizeChatEventForDisplay(chatType, rendered, author, channelName, senderGUID)

    normalizedType = normalizedType or chatType
    normalizedMessage = normalizedMessage or rendered
    local isWhisperType = normalizedType == "WHISPER"
        or normalizedType == "WHISPER_INFORM"
        or normalizedType == "BN_WHISPER"
        or normalizedType == "BN_WHISPER_INFORM"

    return {
        preformatted = (not isWhisperType) and true or nil,
        persist = not hasSecrets,
        message = normalizedMessage,
        rawMessage = normalizedMessage,
        r = r or 1,
        g = g or 1,
        b = b or 1,
        event = event,
        chatType = normalizedType,
        timestamp = timestamp,
        label = normalizedLabel or KT_GetDisplayChatLabel(normalizedType) or normalizedType,
        channelName = normalizedChannel,
        author = normalizedAuthor,
        authorRaw = sender,
        authorFull = (senderFull and not tostring(normalizedType):find("^BN_", 1, true)) and senderFull or nil,
        senderGUID = normalizedSenderGUID,
        lineID = lineID,
        bnSenderID = bnSenderID,
        renderedMessage = rendered,
        searchText = self:BuildSearchText({
            timestamp,
            normalizedLabel or "",
            normalizedChannel or "",
            normalizedAuthor or "",
            KT_SanitizeCopyText(normalizedMessage),
        }),
    }
end

function Mod:BuildEntryFromEvent(event, ...)
    -- KUI now relies on Blizzard's native chat frames for live channel/guild/group
    -- handling. Replaying events through a hidden ChatFrameTemplate can taint
    -- Blizzard's HistoryKeeper globals, which then explodes later on normal
    -- CHANNEL/PARTY traffic. Build the entry directly from the event payload
    -- instead of calling MessageEventHandler on a synthetic frame.
    local chatType = tostring(event or ""):gsub("^CHAT_MSG_", "")
    local info = ChatTypeInfo[chatType] or ChatTypeInfo.SYSTEM or {}
    local rawMessage = KT_GetNonEmptyAccessibleString(select(1, ...))
    if not rawMessage then
        return nil
    end

    local replaced = KT_ReplaceChatExpressions(rawMessage, chatType, false)
    return self:BuildPreformattedEntryFromMonitor(event, replaced, info.r or 1, info.g or 1, info.b or 1, ...)
end


function Mod:CaptureEntriesFromMessageMonitor(event, ...)
    local monitor = self:EnsureMessageMonitor()
    if not monitor then
        return nil
    end

    local messageHandler = monitor.MessageEventHandler or (ChatFrameMixin and ChatFrameMixin.MessageEventHandler)
    if type(messageHandler) ~= "function" then
        return nil
    end

    local liveFrame = _G.ChatFrame1
    monitor.editBox = _G.ChatFrame1EditBox
    monitor.channelList = (liveFrame and liveFrame.channelList) or monitor.channelList or {}
    monitor.zoneChannelList = (liveFrame and liveFrame.zoneChannelList) or monitor.zoneChannelList or {}
    monitor.messageTypeList = (liveFrame and liveFrame.messageTypeList) or monitor.messageTypeList or {}
    monitor.privateMessageList = (liveFrame and liveFrame.privateMessageList) or monitor.privateMessageList or {}
    monitor.defaultLanguage = (liveFrame and liveFrame.defaultLanguage) or (GetDefaultLanguage and GetDefaultLanguage()) or monitor.defaultLanguage
    monitor.alternativeDefaultLanguage = (liveFrame and liveFrame.alternativeDefaultLanguage) or (GetAlternativeDefaultLanguage and GetAlternativeDefaultLanguage()) or monitor.alternativeDefaultLanguage

    local capture = { entries = {} }
    local eventArgs = { ... }
    local eventArgCount = select("#", ...)
    monitor.KT_Capture = capture
    monitor.lineID = eventArgs[11]
    monitor.playerGUID = eventArgs[12]

    local ok = pcall(function()
        local systemHandler = ChatFrame_SystemEventHandler or (ChatFrameMixin and ChatFrameMixin.SystemEventHandler)
        local handled = false
        if type(systemHandler) == "function" then
            handled = systemHandler(monitor, event, unpack(eventArgs, 1, eventArgCount)) == true
        end
        if not handled then
            messageHandler(monitor, event, unpack(eventArgs, 1, eventArgCount))
        end
    end)

    monitor.KT_Capture = nil
    monitor.lineID = nil
    monitor.playerGUID = nil

    if not ok or #capture.entries == 0 then
        return nil
    end

    local builtEntries = {}
    for _, captured in ipairs(capture.entries) do
        local entry = self:BuildPreformattedEntryFromMonitor(event, captured.message, captured.r, captured.g, captured.b, ...)
        if entry then
            tinsert(builtEntries, entry)
        end
    end

    return #builtEntries > 0 and builtEntries or nil
end

function Mod:RefreshAfterUIShow()
    local window = _G.KT_ChatWindow
    if not window or not self.db or self.db.enable == false then
        return
    end

    self:AttachBlizzardEditBox()
    self:ApplyPanelColor()
    self:RefreshTabButtons()
    self:RenderAllFrames()
    self:UpdateSocialButton()
    if self.db.window and self.db.window.visible ~= false then
        window:Show()
    end
    self:QueueChatLayoutReflow()
    self:ScheduleWindowFade()
end

function Mod:OnRuntimeCVarUpdate(_, name)
    if name ~= "SHOW_UI" then
        return
    end

    C_Timer.After(0, function()
        if Mod and Mod.RefreshAfterUIShow then
            Mod:RefreshAfterUIShow()
        end
    end)
end

function Mod:CreateMessageFrame(parent, globalName)
    local fontPath, fontSize, fontOutline = self:GetResolvedFont()
    local frame = CreateFrame("ScrollingMessageFrame", globalName, parent)
    frame:SetMaxLines(self.db.maxLines or KT_CHAT_HISTORY_LINES)
    self:ApplyFrameFading(frame)
    frame:SetIndentedWordWrap(true)
    frame:SetInsertMode("BOTTOM")
    frame:SetJustifyH("LEFT")
    frame:SetJustifyV("TOP")
    frame:SetFont(fontPath, fontSize, fontOutline)
    frame:SetHyperlinksEnabled(true)
    frame:EnableMouse(true)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnHyperlinkClick", function(widget, link, text, button)
        -- Preserve KUI navigation on left-click, but delegate right-click to
        -- Blizzard for the standard player/report context menu.
        if button ~= "RightButton" and self:HandleWhisperHyperlink(link) then
            return
        end

        local chatFrame = KT_GetReplyChatFrame()
        if _G.SetItemRef then
            _G.SetItemRef(link, text, button, chatFrame or widget)
        elseif _G.ChatFrame_OnHyperlinkShow and chatFrame then
            _G.ChatFrame_OnHyperlinkShow(chatFrame, link, text, button)
        end
    end)
    frame:SetScript("OnMouseWheel", function(widget, delta)
        if delta > 0 then
            widget:ScrollUp()
        else
            widget:ScrollDown()
        end
        self:UpdateScrollButtonVisibility()
    end)

    if hooksecurefunc then
        hooksecurefunc(frame, "ScrollToBottom", function()
            self:UpdateScrollButtonVisibility()
        end)
        hooksecurefunc(frame, "ScrollUp", function()
            self:UpdateScrollButtonVisibility()
        end)
        hooksecurefunc(frame, "ScrollDown", function()
            self:UpdateScrollButtonVisibility()
        end)
    end

    return frame
end

function Mod:GetEntryMessage(entry, includeTimestamp)
    if type(entry) ~= "table" then
        return ""
    end

    local message = KT_GetAccessibleString(entry.rawMessage, KT_GetAccessibleString(entry.message, "")) or ""
    if entry.preformatted == true then
        return message
    end

    local parts = {}
    local showTimestamp = includeTimestamp ~= false
    local timestamp = KT_GetAccessibleString(entry.timestamp, nil)
    local label = KT_GetAccessibleString(entry.label, nil)
    local author = KT_GetAccessibleString(entry.author, KT_GetAccessibleString(entry.authorRaw, nil))
    local authorLink = nil
    if KT_SafeString(entry.chatType, ""):find("WHISPER", 1, true) then
        authorLink = KT_BuildWhisperDisplayLink(entry)
    end
    if type(authorLink) == "string" and authorLink ~= "" then
        author = authorLink
    end
    if showTimestamp and type(timestamp) == "string" and timestamp ~= "" then
        parts[#parts + 1] = "[" .. timestamp .. "]"
    end
    if type(label) == "string" and label ~= "" then
        parts[#parts + 1] = "[" .. label .. "]"
    end
    if type(author) == "string" and author ~= "" then
        parts[#parts + 1] = author .. ":"
    end
    if message ~= "" then
        parts[#parts + 1] = message
    end

    local rendered = table.concat(parts, " ")
    if rendered == "" then
        return message
    end
    return rendered
end

function Mod:RegisterMessageFrame(frame, filterFunc)
    for _, existing in ipairs(self.messageFrames) do
        if existing == frame then
            existing.KT_FilterFunc = filterFunc
            return frame
        end
    end

    frame.KT_FilterFunc = filterFunc
    tinsert(self.messageFrames, frame)
    self:RenderFrame(frame)
    return frame
end

function Mod:AddEntryToFrames(entry)
    if not entry then
        return
    end

    for _, frame in ipairs(self.messageFrames) do
        if not frame.KT_FilterFunc or frame.KT_FilterFunc(entry) then
            local wasAtBottom = not frame.AtBottom or frame:AtBottom()
            frame:AddMessage(self:GetEntryMessage(entry), entry.r, entry.g, entry.b)
            if wasAtBottom and frame.ScrollToBottom then
                frame:ScrollToBottom()
            end
        end
    end
end

function Mod:RenderFrame(frame)
    if not frame then
        return
    end

    local wasAtBottom = true
    if frame.AtBottom then
        wasAtBottom = frame:AtBottom()
    end

    frame:Clear()
    for _, entry in ipairs(self.history) do
        if not frame.KT_FilterFunc or frame.KT_FilterFunc(entry) then
            local ok, msg = pcall(self.GetEntryMessage, self, entry)
            if ok and type(msg) == "string" and msg ~= "" then
                pcall(frame.AddMessage, frame, msg, entry.r, entry.g, entry.b)
            end
        end
    end

    if wasAtBottom and frame.ScrollToBottom then
        frame:ScrollToBottom()
    end
end

function Mod:RenderAllFrames()
    for _, frame in ipairs(self.messageFrames) do
        self:RenderFrame(frame)
    end
    self:UpdateScrollButtonVisibility()
end

function Mod:UpdateScrollButtonVisibility()
    local window = _G.KT_ChatWindow
    local frame = self:GetActiveMessageFrame()
    if not window or not window.KT_ScrollButton or not frame then
        return
    end

    local atBottom = true
    if frame.AtBottom then
        atBottom = frame:AtBottom()
    end
    window.KT_ScrollButton:SetShown(not atBottom)
end

function Mod:HideDetachedNativeChatFrame(frame)
    if not frame then
        return
    end

    frame.KT_ManagedLayoutActive = nil
    self.suppressNativeChatFrameLayoutWatch = true
    frame:ClearAllPoints()
    frame:SetParent(UIParent)
    frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -4000, -4000)
    self.suppressNativeChatFrameLayoutWatch = nil
    frame:SetAlpha(0)
    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(false)
    end
    frame:Hide()

    if frame.editBox and frame.editBox ~= _G.ChatFrame1EditBox then
        frame.editBox:Hide()
    end
end

function Mod:HookManagedNativeChatFrameLayout(frame)
    if not frame or frame.KT_ManagedLayoutHooked or not hooksecurefunc then
        return
    end

    frame.KT_ManagedLayoutHooked = true
    local function requestReanchor(widget)
        if self.suppressNativeChatFrameLayoutWatch or not widget.KT_ManagedLayoutActive then
            return
        end
        self:RecordPositionDebug("native chat layout changed: " .. tostring(widget.GetName and widget:GetName() or widget))
        self:QueueChatLayoutReflow()
    end

    for _, methodName in ipairs({ "SetParent", "ClearAllPoints", "SetAllPoints", "SetPoint", "SetSize", "SetWidth", "SetHeight", "SetScale" }) do
        if type(frame[methodName]) == "function" then
            hooksecurefunc(frame, methodName, requestReanchor)
        end
    end
end

function Mod:ApplyNativeChatFrameLayout(frame, parent, topOffset, bottomInset)
    if not frame or not parent then
        return nil
    end

    self:HookManagedNativeChatFrameLayout(frame)
    self.suppressNativeChatFrameLayoutWatch = true
    frame.KT_ManagedLayoutActive = true

    if frame:GetParent() ~= parent then
        frame:SetParent(parent)
    end

    local leftInset, defaultTopInset, rightInset, defaultBottomInset = self:GetChatContentInsets(parent)
    local top = (type(topOffset) == "number") and topOffset or defaultTopInset
    local bottom = (type(bottomInset) == "number") and bottomInset or defaultBottomInset

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", leftInset, top)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", rightInset, bottom)
    frame:SetAlpha(1)
    if frame.EnableMouse then
        frame:EnableMouse(true)
    end
    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(true)
    end
    if frame.SetWidth then
        local targetWidth = math.max(1, (parent:GetWidth() or 0) - leftInset + rightInset)
        pcall(frame.SetWidth, frame, targetWidth)
    end
    if frame.SetHeight then
        local targetHeight = math.max(1, (parent:GetHeight() or 0) + top - bottom)
        pcall(frame.SetHeight, frame, targetHeight)
    end
    if frame.SetClampedToScreen then
        frame:SetClampedToScreen(false)
    end
    self.suppressNativeChatFrameLayoutWatch = nil

    return frame
end

function Mod:HideNativeChatChrome(frame)
    if not frame or not frame.GetID then
        return
    end

    local id = frame:GetID()
    local tab = _G["ChatFrame" .. id .. "Tab"]
    local buttonFrame = _G["ChatFrame" .. id .. "ButtonFrame"]
    local background = _G["ChatFrame" .. id .. "Background"]

    KT_HideBlizzardChatChromeFrame(tab)
    KT_HideBlizzardChatChromeFrame(buttonFrame)
    KT_HideBlizzardChatChromeFrame(background)
end

function Mod:ClearNativeChatFrameContent(frame)
    if not frame then
        return
    end

    if frame.Clear then
        pcall(frame.Clear, frame)
    end

    local historyBuffer = frame.historyBuffer
    if historyBuffer then
        if type(historyBuffer.Clear) == "function" then
            pcall(historyBuffer.Clear, historyBuffer)
        else
            local wipeFunc = _G.wipe or table.wipe
            if wipeFunc and type(historyBuffer.elements) == "table" then
                pcall(wipeFunc, historyBuffer.elements)
            end
        end
    end

    local wipeFunc = _G.wipe or table.wipe
    if wipeFunc and type(frame.visibleLines) == "table" then
        pcall(wipeFunc, frame.visibleLines)
    end
end

function Mod:ConfigureDedicatedNativeTabFrame(frame, role)
    if not frame or not role then
        return nil
    end

    local groups = KT_NATIVE_CHAT_MESSAGE_GROUPS[role]
    if not groups then
        return frame
    end

    -- Mainline secret chat payloads make Blizzard's messageTypeList and
    -- channelList protected while PvP messages are dispatched. Mutating those
    -- tables from addon code poisons the later native iteration, which then
    -- attributes the failure to whichever addon happened to run last.
    if KT_IsSecureChatSafeMode() then
        -- GROUP still needs its complete native subscription on Retail. Add
        -- the missing message groups through Blizzard's API only while chat is
        -- unlocked; do not inspect, clear or iterate the protected lists.
        if role == "group"
            and frame.KT_NativeTabConfigured ~= true
            and not (InCombatLockdown and InCombatLockdown())
            and not KT_IsChatMessagingLocked()
            and _G.ChatFrame_AddMessageGroup then
            local configured = true
            for _, messageGroup in ipairs(groups) do
                configured = pcall(_G.ChatFrame_AddMessageGroup, frame, messageGroup) and configured
            end
            if configured then
                frame.KT_NativeTabConfigured = true
                frame.KT_NativeTabRole = role
            end
        end

        frame.KT_KeepVisible = true
        self:HideNativeChatChrome(frame)
        self:ApplyConfiguredFontToFrame(frame)
        return frame
    end

    if frame.KT_WhisperDedicatedRegistered and role ~= "whisper" and _G.FCFManager_UnregisterDedicatedFrame then
        pcall(_G.FCFManager_UnregisterDedicatedFrame, frame, "WHISPER")
        pcall(_G.FCFManager_UnregisterDedicatedFrame, frame, "BN_WHISPER")
        frame.KT_WhisperDedicatedRegistered = nil
    end

    local needsReconfigure = (frame.KT_NativeTabRole ~= role) or (frame.KT_NativeTabConfigured ~= true)

    if _G.FCF_UnDockFrame then
        pcall(_G.FCF_UnDockFrame, frame)
    end

    if needsReconfigure then
        if _G.FCF_SetWindowName and KT_NATIVE_CHAT_WINDOW_NAMES[role] and not (role == "whisper" and KT_IsSecureChatSafeMode()) then
            pcall(_G.FCF_SetWindowName, frame, KT_NATIVE_CHAT_WINDOW_NAMES[role], true)
        end

        if _G.ChatFrame_RemoveAllMessageGroups then
            pcall(_G.ChatFrame_RemoveAllMessageGroups, frame)
        elseif _G.ChatFrame_RemoveMessageGroup and frame.messageTypeList then
            local oldGroups = {}
            for _, g in ipairs(frame.messageTypeList) do tinsert(oldGroups, g) end
            for _, g in ipairs(oldGroups) do pcall(_G.ChatFrame_RemoveMessageGroup, frame, g) end
        end

        if _G.ChatFrame_RemoveAllChannels then
            pcall(_G.ChatFrame_RemoveAllChannels, frame)
        elseif _G.ChatFrame_RemoveChannel and frame.channelList then
            local oldChannels = {}
            for _, c in ipairs(frame.channelList) do tinsert(oldChannels, c) end
            for _, c in ipairs(oldChannels) do pcall(_G.ChatFrame_RemoveChannel, frame, c) end
        end

        for _, messageGroup in ipairs(groups) do
            if _G.ChatFrame_AddMessageGroup then
                pcall(_G.ChatFrame_AddMessageGroup, frame, messageGroup)
            end
        end



        -- Only flush when a frame is first assigned/reassigned to a role.
        -- If we clear on every tab switch, Guild/Group/Whisp lose their live messages
        -- as soon as you leave and come back.
        self:ClearNativeChatFrameContent(frame)
        frame.KT_NativeTabConfigured = true
    end

    if role == "trade" then
        KT_RefreshTradeNativeChannels(frame)
    end

    if role == "whisper" and not KT_IsSecureChatSafeMode() and _G.FCFManager_RegisterDedicatedFrame and not frame.KT_WhisperDedicatedRegistered then
        pcall(_G.FCFManager_RegisterDedicatedFrame, frame, "WHISPER")
        pcall(_G.FCFManager_RegisterDedicatedFrame, frame, "BN_WHISPER")
        frame.KT_WhisperDedicatedRegistered = true
    end

    frame.KT_KeepVisible = true
    self:HideNativeChatChrome(frame)
    self:ApplyConfiguredFontToFrame(frame)
    frame.KT_NativeTabRole = role
    return frame
end

function Mod:EnsureDedicatedNativeTabFrame(role, parent)
    if not role then
        return nil
    end

    self.nativeTabFrames = self.nativeTabFrames or {}
    local frame = self.nativeTabFrames[role]
    if not (frame and frame.GetObjectType) then
        local frameID = KT_NATIVE_CHAT_WINDOW_IDS[role]
        frame = frameID and _G["ChatFrame" .. frameID] or nil
        if not frame then
            return nil
        end
        self.nativeTabFrames[role] = frame
    end

    self:ConfigureDedicatedNativeTabFrame(frame, role)
    self:ApplyNativeChatFrameLayout(frame, parent)
    return frame
end

function Mod:PrimeDedicatedNativeTabFrames(parent)
    local window = _G.KT_ChatWindow
    local content = parent or (window and window.KT_Content)
    if not content then
        return
    end

    local roles = { "trade", "guild", "group", "whisper" }
    for _, role in ipairs(roles) do
        local frame = self:EnsureDedicatedNativeTabFrame(role, content)
        if frame then
            self:HideDetachedNativeChatFrame(frame)
        end
    end
end

local function KT_GetNativeWhisperTarget(renderedText)
    renderedText = KT_GetNonEmptyAccessibleString(renderedText)
    if not renderedText then
        return nil
    end

    for linkType, linkData in renderedText:gmatch("|H([^:|]+):([^|]-)|h") do
        linkType = strlower(linkType)
        if linkType == "player" then
            local target = KT_GetNonEmptyAccessibleString((strsplit(":", linkData)))
            if target then
                return target, "WHISPER", nil
            end
        elseif linkType == "bnplayer" then
            local playerName, bnetIDAccount = strsplit(":", linkData)
            bnetIDAccount = tonumber(bnetIDAccount)
            local target = (bnetIDAccount and KT_ResolveBNetWhisperTarget(bnetIDAccount))
                or KT_GetNonEmptyAccessibleString(playerName)
            if target then
                return target, "BN_WHISPER", bnetIDAccount
            end
        end
    end

    return nil
end

function Mod:RememberNativeWhisperMessage(signature)
    if type(signature) ~= "string" or signature == "" then
        return false
    end

    self.nativeWhisperSeenLookup = self.nativeWhisperSeenLookup or {}
    self.nativeWhisperSeenOrder = self.nativeWhisperSeenOrder or {}
    if self.nativeWhisperSeenLookup[signature] then
        return false
    end

    self.nativeWhisperSeenLookup[signature] = true
    tinsert(self.nativeWhisperSeenOrder, signature)
    while #self.nativeWhisperSeenOrder > 64 do
        local expired = tremove(self.nativeWhisperSeenOrder, 1)
        self.nativeWhisperSeenLookup[expired] = nil
    end
    return true
end

local function KT_IsNativeWhisperColor(r, g, b)
    r = KT_GetAccessibleNumber(r)
    g = KT_GetAccessibleNumber(g)
    b = KT_GetAccessibleNumber(b)
    if not r or not g or not b then
        return false
    end

    for _, chatType in ipairs({ "WHISPER", "WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM" }) do
        local info = ChatTypeInfo and ChatTypeInfo[chatType]
        local infoR = info and KT_GetAccessibleNumber(info.r)
        local infoG = info and KT_GetAccessibleNumber(info.g)
        local infoB = info and KT_GetAccessibleNumber(info.b)
        if infoR and infoG and infoB
            and math.abs(r - infoR) < 0.01
            and math.abs(g - infoG) < 0.01
            and math.abs(b - infoB) < 0.01 then
            return true
        end
    end

    return false
end

function Mod:ImportNativeWhisperMessage(renderedText, r, g, b, messageID)
    renderedText = KT_GetNonEmptyAccessibleString(renderedText)
    local accessibleMessageID = KT_SafeString(messageID, nil)
    local signature = accessibleMessageID and ("id:" .. accessibleMessageID) or renderedText
    if not renderedText or not KT_IsNativeWhisperColor(r, g, b)
        or not self:RememberNativeWhisperMessage(signature) then
        return false
    end

    local target, chatType, bnetIDAccount = KT_GetNativeWhisperTarget(renderedText)
    if not target then
        return false
    end

    local threadKey = KT_GetWhisperTargetKey(target, chatType, bnetIDAccount)
    if not threadKey then
        return false
    end

    self:AddWhisperTarget(target, chatType, false, bnetIDAccount)
    local entry = {
        preformatted = true,
        persist = true,
        message = renderedText,
        rawMessage = renderedText,
        r = KT_GetAccessibleNumber(r, 1),
        g = KT_GetAccessibleNumber(g, 0.5),
        b = KT_GetAccessibleNumber(b, 1),
        event = "CHAT_MSG_NATIVE_WHISPER",
        chatType = chatType,
        timestamp = date("%H:%M"),
        label = KT_GetDisplayChatLabel(chatType) or chatType,
        author = target,
        authorRaw = target,
        bnSenderID = bnetIDAccount,
        whisperTarget = target,
        whisperThreadKey = threadKey,
    }

    return self:HandleIncomingEntry(entry) ~= nil
end

function Mod:ScanNativeWhisperMessages()
    if not KT_IsSecureChatSafeMode() or not self.runtimeInitialized then
        return
    end

    -- ChatFrame1 is owned and populated entirely by Blizzard. Reading its
    -- rendered output avoids registering events or mutating protected lists.
    local frame = _G.ChatFrame1
    if not (frame and frame.GetNumMessages and frame.GetMessageInfo) then
        return
    end

    local okCount, count = pcall(frame.GetNumMessages, frame)
    count = okCount and KT_GetAccessibleNumber(count) or nil
    if not count or count < 0 then
        return
    end

    local previousCount = tonumber(self.nativeWhisperMessageCount) or 0
    local firstIndex = previousCount + 1
    if count < previousCount then
        firstIndex = 1
        wipe(self.nativeWhisperSeenLookup or {})
        wipe(self.nativeWhisperSeenOrder or {})
    elseif count == previousCount then
        if count == 0 then
            self.nativeWhisperMessageCount = 0
            self.nativeWhisperLastText = nil
            return
        end

        local okLast, lastText = pcall(frame.GetMessageInfo, frame, count)
        lastText = okLast and KT_GetNonEmptyAccessibleString(lastText) or nil
        if lastText == self.nativeWhisperLastText then
            return
        end

        -- ScrollingMessageFrame keeps a fixed line count once full. Inspect a
        -- small tail when it rolls over so bursts cannot skip a conversation.
        firstIndex = math.max(1, count - 7)
    end

    for index = math.max(1, firstIndex), count do
        local okInfo, text, r, g, b, _, messageID = pcall(frame.GetMessageInfo, frame, index)
        if okInfo then
            self:ImportNativeWhisperMessage(text, r, g, b, messageID)
        end
    end

    self.nativeWhisperMessageCount = count
    if count > 0 then
        local okLast, lastText = pcall(frame.GetMessageInfo, frame, count)
        self.nativeWhisperLastText = okLast and KT_GetNonEmptyAccessibleString(lastText) or nil
    else
        self.nativeWhisperLastText = nil
    end
end

function Mod:StartNativeWhisperScanner()
    if not KT_IsSecureChatSafeMode() or self.nativeWhisperScanner or not (C_Timer and C_Timer.NewTicker) then
        return
    end

    self.nativeWhisperMessageCount = 0
    self.nativeWhisperLastText = nil
    self.nativeWhisperSeenLookup = {}
    self.nativeWhisperSeenOrder = {}
    self:ScanNativeWhisperMessages()
    self.nativeWhisperScanner = C_Timer.NewTicker(0.2, function()
        if Mod and Mod.IsEnabled and Mod:IsEnabled() then
            Mod:ScanNativeWhisperMessages()
        end
    end)
end

function Mod:SetDedicatedNativeTabVisible(activeRole)
    local window = _G.KT_ChatWindow
    local normalFrame = _G.KT_ChatFrame
    if not window or not window.KT_Content or not normalFrame then
        return
    end

    self.nativeTabFrames = self.nativeTabFrames or {}
    local activeFrame = nil

    for role, frame in pairs(self.nativeTabFrames) do
        if role == activeRole then
            activeFrame = self:EnsureDedicatedNativeTabFrame(role, window.KT_Content) or frame
        else
            self:HideDetachedNativeChatFrame(frame)
        end
    end

    if activeRole and not activeFrame then
        activeFrame = self:EnsureDedicatedNativeTabFrame(activeRole, window.KT_Content)
    end

    if activeFrame then
        normalFrame:Hide()
        normalFrame:SetAlpha(0)
        if normalFrame.EnableMouse then
            normalFrame:EnableMouse(false)
        end
        if normalFrame.EnableMouseWheel then
            normalFrame:EnableMouseWheel(false)
        end
        activeFrame:Show()
        self:HideNativeChatChrome(activeFrame)
        if window.KT_InputHost then
            window.KT_InputHost:Show()
        end
        if window.KT_SendButton then
            window.KT_SendButton:Show()
        end
    else
        for _, frame in pairs(self.nativeTabFrames) do
            self:HideDetachedNativeChatFrame(frame)
        end

        if not self:ShouldUseBlizzardPrimaryFrame() and not self:IsCombatTab(self:GetActiveTab()) then
            normalFrame:SetAlpha(1)
            if normalFrame.EnableMouse then
                normalFrame:EnableMouse(true)
            end
            if normalFrame.EnableMouseWheel then
                normalFrame:EnableMouseWheel(true)
            end
            normalFrame:Show()
        end
    end
end

function Mod:GetActiveMessageFrame()
    local tab = self:GetActiveTab()
    local window = _G.KT_ChatWindow
    local content = window and window.KT_Content

    if self:IsCombatTab(tab) then
        local combatFrame = self:EnsureCombatLogFrame(content)
        if combatFrame then
            return combatFrame
        end
    end

    if self:ShouldUseBlizzardPrimaryFrame() then
        local primaryFrame = self:EnsurePrimaryChatFrame(content)
        if primaryFrame then
            return primaryFrame
        end
    end

    local dedicatedRole = self:GetActiveDedicatedNativeTabRole(tab)
    if dedicatedRole then
        local dedicatedFrame = self:EnsureDedicatedNativeTabFrame(dedicatedRole, content)
        if dedicatedFrame then
            return dedicatedFrame
        end
    end

    return _G.KT_ChatFrame
end

function Mod:ShouldUseBlizzardPrimaryFrame()
    return self:IsBlizzardPrimaryTab(self:GetActiveTab())
end

function Mod:EnsurePrimaryChatFrame(parent)
    local frame = _G.ChatFrame1
    if not frame then
        return nil
    end

    frame.KT_UseAsPrimary = true
    self:ApplyNativeChatFrameLayout(frame, parent)
    self:HideNativeChatChrome(frame)
    return frame
end

function Mod:SetPrimaryChatVisible(visible)
    local window = _G.KT_ChatWindow
    local normalFrame = _G.KT_ChatFrame
    local primaryFrame = _G.ChatFrame1
    if not window or not window.KT_Content or not normalFrame or not primaryFrame then
        return
    end

    if visible then
        self:EnsurePrimaryChatFrame(window.KT_Content)
        normalFrame:Hide()
        normalFrame:SetAlpha(0)
        if normalFrame.EnableMouse then
            normalFrame:EnableMouse(false)
        end
        if normalFrame.EnableMouseWheel then
            normalFrame:EnableMouseWheel(false)
        end
        primaryFrame.KT_UseAsPrimary = true
        primaryFrame:Show()
        self:HideNativeChatChrome(primaryFrame)
    else
        normalFrame:SetAlpha(1)
        if normalFrame.EnableMouse then
            normalFrame:EnableMouse(true)
        end
        if normalFrame.EnableMouseWheel then
            normalFrame:EnableMouseWheel(true)
        end
        normalFrame:Show()
        primaryFrame.KT_UseAsPrimary = false
        self:HideDetachedNativeChatFrame(primaryFrame)
    end
end

function Mod:EnsureCombatLogFrame(parent)
    if not parent then
        return self.combatLogChatFrame
    end

    local frame = _G.ChatFrame2
    if not frame then
        return self.combatLogChatFrame
    end

    self:ApplyNativeChatFrameLayout(frame, parent, -18, 72)
    self:HideNativeChatChrome(frame)
    self.combatLogChatFrame = frame
    return frame
end

function Mod:SetCombatLogVisible(visible)
    local window = _G.KT_ChatWindow
    local normalFrame = _G.KT_ChatFrame
    if not window or not normalFrame or not window.KT_Content then
        return
    end

    local combatFrame = self:EnsureCombatLogFrame(window.KT_Content)
    local combatButtons = _G.CombatLogQuickButtonFrame_Custom
    local combatTab = _G.ChatFrame2Tab
    local combatButtonFrame = _G.ChatFrame2ButtonFrame

    if visible and combatFrame then
        normalFrame:Hide()
        combatFrame:Show()
        if combatButtons then
            combatButtons:SetParent(window.KT_Content)
            combatButtons:ClearAllPoints()
            combatButtons:SetPoint("BOTTOMLEFT", window.KT_Content, "BOTTOMLEFT", 12, 8)
            combatButtons:Show()
        end
        if combatTab then combatTab:Hide() end
        if combatButtonFrame then combatButtonFrame:Hide() end
        if window.KT_InputHost then
            window.KT_InputHost:Hide()
        end
        if window.KT_SendButton then
            window.KT_SendButton:Hide()
        end
    else
        if self:ShouldUseBlizzardPrimaryFrame() or self:GetActiveDedicatedNativeTabRole(self:GetActiveTab()) then
            normalFrame:Hide()
        else
            normalFrame:Show()
        end
        if combatFrame then
            self:HideDetachedNativeChatFrame(combatFrame)
        end
        if combatButtons then
            combatButtons:Hide()
        end
        if combatTab then combatTab:Hide() end
        if combatButtonFrame then combatButtonFrame:Hide() end
        if window.KT_InputHost then
            window.KT_InputHost:Show()
        end
        if window.KT_SendButton then
            window.KT_SendButton:Show()
        end
    end
end

function Mod:RefreshChatFrameMode()
    local activeTab = self:GetActiveTab()
    local showCombat = self:IsCombatTab(activeTab)
    local showBlizzardPrimary = (not showCombat) and self:ShouldUseBlizzardPrimaryFrame()
    local dedicatedRole = (not showCombat and not showBlizzardPrimary) and self:GetActiveDedicatedNativeTabRole(activeTab) or nil

    self:SetPrimaryChatVisible(showBlizzardPrimary)
    self:SetCombatLogVisible(showCombat)
    self:SetDedicatedNativeTabVisible(dedicatedRole)
    self:UpdateScrollButtonVisibility()
    self:UpdateInputPrompt(_G.ChatFrame1EditBox)
end

function Mod:PLAYER_REGEN_DISABLED()
    self:RefreshChatFrameMode()
end

function Mod:PLAYER_REGEN_ENABLED()
    if self.attachBlizzardEditBoxAfterCombat then
        self:AttachBlizzardEditBox()
    end
    self:RefreshChatFrameMode()
    if self.tradeChannelRefreshPending then
        self:QueueTradeNativeChannelRefresh()
    end
    self:PersistHistory()
end

function Mod:CreateSidebarButton(parent, tooltip, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(32, 32)
    button:EnableMouse(true)
    if button.RegisterForClicks then
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    end
    if parent and parent.GetFrameStrata then
        button:SetFrameStrata(parent:GetFrameStrata())
    end
    if parent and parent.GetFrameLevel then
        button:SetFrameLevel((parent:GetFrameLevel() or 0) + 10)
    end
    KT_StyleActionButton(button)
    button:SetBackdropColor(0, 0, 0, 0)
    button:SetBackdropBorderColor(0, 0, 0, 0)
    button.KT_Shadow = button:CreateTexture(nil, "BACKGROUND")
    button.KT_Shadow:SetPoint("TOPLEFT", 3, -3)
    button.KT_Shadow:SetPoint("BOTTOMRIGHT", -1, 1)
    button.KT_Shadow:SetColorTexture(0, 0, 0, 0.35)
    local function runClick(clickedButton, mouseButton, down)
        local now = GetTimePreciseSec and GetTimePreciseSec() or GetTime()
        if clickedButton.KT_LastSidebarClick and (now - clickedButton.KT_LastSidebarClick) < 0.05 then
            return
        end
        clickedButton.KT_LastSidebarClick = now
        if type(onClick) == "function" then
            onClick(clickedButton, mouseButton, down)
        end
    end
    button:SetScript("OnClick", runClick)
    KT_SetTooltip(button, tooltip)
    return button
end

function Mod:ClickHiddenButton(button, fallback)
    local clicked = false
    if button and button.Click then
        local canClick = true
        if button.IsShown and not button:IsShown() then
            canClick = false
        end
        if button.IsEnabled and not button:IsEnabled() then
            canClick = false
        end

        if canClick then
            local ok = pcall(button.Click, button)
            clicked = ok == true
        end
    end

    if not clicked and fallback then
        fallback()
    end
end

function Mod:UpdateSocialButton()
    local window = _G.KT_ChatWindow
    local button = window and window.KT_FriendsButton
    if not button or not button.KT_Count then
        return
    end

    local total = 0
    if _G.FriendsMicroButtonCount and _G.FriendsMicroButtonCount.GetText then
        total = tonumber(_G.FriendsMicroButtonCount:GetText()) or 0
    elseif C_FriendList and C_FriendList.GetNumOnlineFriends then
        total = C_FriendList.GetNumOnlineFriends() or 0
    end

    if total > 0 then
        button.KT_Count:SetText(total)
        button.KT_Count:Show()
    else
        button.KT_Count:Hide()
    end
end

function Mod:AttachSidebarControls()
    local window = _G.KT_ChatWindow
    if not window or not window.KT_SideBar then
        return
    end

    if window.KT_ActionButtons then
        self:UpdateSocialButton()
        self:UpdateSidebarLayout()
        return
    end

    local sideBar = window.KT_SideBar
    sideBar:SetWidth(32)
    window.KT_ActionButtons = {}

    local buttonDefs = {
        {
            key = "KT_FriendsButton",
            tooltip = KT_LText("Friends List"),
            build = function(button)
                KT_StyleActionTexture(button, KT_CHAT_ICON_PATH .. "FriendList.png", false)
                local count = button:CreateFontString(nil, "OVERLAY")
                count:SetFont(KT_DEFAULT_FONT, 10, "OUTLINE")
                count:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -2)
                count:SetTextColor(1, 1, 1, 1)
                button.KT_Count = count
                self:UpdateSocialButton()
            end,
            onClick = function()
                KT_OpenFriendsList()
            end,
        },
        {
            key = "KT_VoiceButton",
            tooltip = KT_LText("Voice Chat"),
            build = function(button)
                KT_StyleActionTexture(button, KT_CHAT_ICON_PATH .. "VoiceChat.png", false)
            end,
            onClick = function()
                self:ClickHiddenButton(_G.ChatFrameChannelButton, function()
                    if KT_IsChatMessagingLocked() or InCombatLockdown() then
                        if KT and KT.Print then
                            KT:Print(KT_LText("Channel access is unavailable right now."))
                        end
                        return
                    end
                    if ChannelFrame then
                        ShowUIPanel(ChannelFrame)
                    end
                end)
            end,
        },
        {
            key = "KT_QuickChatButton",
            tooltip = KT_LText("Quick Chat"),
            build = function(button)
                KT_StyleActionTexture(button, KT_CHAT_ICON_PATH .. "QuickChat.png", false)
            end,
            onClick = function(button)
                self:OpenQuickChatMenu(button)
            end,
        },
        {
            key = "KT_SearchButton",
            tooltip = SEARCH,
            build = function(button)
                KT_StyleActionTexture(button, KT_CHAT_ICON_PATH .. "Search.png", false)
            end,
            onClick = function()
                self:OpenSearchDialog()
            end,
        },
        {
            key = "KT_CopyButton",
            tooltip = KT_LText("Copy Chat"),
            build = function(button)
                KT_StyleActionTexture(button, KT_CHAT_ICON_PATH .. "CopyChat.png", false)
            end,
            onClick = function()
                self:OpenCopyDialog()
            end,
        },
        {
            key = "KT_SettingsButton",
            tooltip = KT_LText("Chat Settings"),
            build = function(button)
                KT_StyleActionTexture(button, KT_CHAT_ICON_PATH .. "Confrig.png", false)
            end,
            onClick = function()
                KT_OpenBlizzardChatSettings()
            end,
        },
        {
            key = "KT_ClearButton",
            tooltip = KT_LText("Clear Chat"),
            build = function(button)
                KT_StyleActionTexture(button, KT_CHAT_ICON_PATH .. "trash.png", false)
            end,
            onClick = function()
                self:ClearHistory()
            end,
        },
    }

    for index, definition in ipairs(buttonDefs) do
        local button = self:CreateSidebarButton(sideBar, definition.tooltip, definition.onClick)
        button:SetPoint("TOP", sideBar, "TOP", 0, -((index - 1) * 38))
        definition.build(button)
        window[definition.key] = button
        tinsert(window.KT_ActionButtons, button)
    end

    self:ApplyPanelColor()
    self:UpdateSocialButton()
    self:UpdateSidebarLayout()
end

function Mod:UpdateSidebarLayout()
    local window = _G.KT_ChatWindow
    local sideBar = window and window.KT_SideBar
    if not window or not sideBar or not window.KT_ActionButtons then
        return
    end

    sideBar:ClearAllPoints()
    sideBar:SetPoint("TOPRIGHT", window, "TOPLEFT", 2, -2)
    sideBar:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", 2, 2)

    local buttons = window.KT_ActionButtons
    if #buttons == 0 then
        sideBar:SetWidth(32)
        return
    end

    local btnSize = 32
    local step = 38
    local height = sideBar:GetHeight() or 0
    local rows = math.max(1, math.floor((height + 6) / step))
    rows = math.min(rows, #buttons)
    local cols = math.ceil(#buttons / rows)

    sideBar:SetWidth(((cols - 1) * step) + btnSize)

    for i, button in ipairs(buttons) do
        local col = math.floor((i - 1) / rows)
        local row = (i - 1) % rows
        button:ClearAllPoints()
        button:SetPoint("TOPRIGHT", sideBar, "TOPRIGHT", -(col * step), -(row * step))
    end
end

function Mod:CreateNativeWindow()
    local window = _G.KT_ChatWindow
    if window then
        return window
    end

    window = CreateFrame("Frame", "KT_ChatWindow", UIParent, "BackdropTemplate")
    window:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", KT_CHAT_WINDOW_DEFAULT_X, KT_CHAT_WINDOW_DEFAULT_Y)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:SetResizable(false)
    window:SetFrameStrata("MEDIUM")
    window:SetFrameLevel(20)
    window:SetAlpha(1)
    window.KT_HoverElapsed = 0
    window:SetScript("OnUpdate", function(chatWindow, elapsed)
        chatWindow.KT_HoverElapsed = (chatWindow.KT_HoverElapsed or 0) + elapsed
        if chatWindow.KT_HoverElapsed < 0.08 then return end
        chatWindow.KT_HoverElapsed = 0
        local hovered = chatWindow:IsMouseOver()
            or (chatWindow.KT_TabsHolder and chatWindow.KT_TabsHolder:IsMouseOver())
            or (chatWindow.KT_SideBar and chatWindow.KT_SideBar:IsMouseOver())
            or (chatWindow.KT_WhisperStrip and chatWindow.KT_WhisperStrip:IsShown() and chatWindow.KT_WhisperStrip:IsMouseOver())
        if hovered and not chatWindow.KT_MouseInside then
            chatWindow.KT_MouseInside = true
            self:ShowWindowForActivity(false)
        elseif not hovered and chatWindow.KT_MouseInside then
            chatWindow.KT_MouseInside = nil
            self:RecordChatActivity()
            self:ScheduleWindowFade()
        end
    end)
    self:ApplyWindowGeometry(window)

    KT:AddBackdrop(window, KT_CHAT_DEFAULT_PANEL_COLOR.r, KT_CHAT_DEFAULT_PANEL_COLOR.g, KT_CHAT_DEFAULT_PANEL_COLOR.b, KT_CHAT_DEFAULT_PANEL_COLOR.a)
    KT:AddBorder(window, 0.08, 0.08, 0.08, 0)
    window:SetScript("OnShow", function()
        KT_HideBlizzardChatFrames()
        self:AttachBlizzardEditBox()
        self:AttachSidebarControls()
        self:QueueChatLayoutReflow()
    end)
    window:SetScript("OnSizeChanged", function()
        self:RefreshTabButtons()
        self:UpdateSidebarLayout()
        self:ApplyNormalChatFrameLayout()
        self:RefreshChatFrameMode()
        self:QueueChatLayoutReflow()
    end)

    local glassTop = window:CreateTexture(nil, "ARTWORK", nil, -1)
    glassTop:SetPoint("TOPLEFT", 1, -1)
    glassTop:SetPoint("TOPRIGHT", -1, -1)
    glassTop:SetHeight(math.floor(self.db.window.height * 0.45))
    window.KT_GlassTop = glassTop

    local leftShade = window:CreateTexture(nil, "ARTWORK", nil, -1)
    leftShade:SetPoint("TOPLEFT", 1, -1)
    leftShade:SetPoint("BOTTOMLEFT", 1, 1)
    leftShade:SetWidth(math.floor(self.db.window.width * 0.22))
    window.KT_LeftShade = leftShade

    local glassBottom = window:CreateTexture(nil, "ARTWORK", nil, -1)
    glassBottom:SetPoint("BOTTOMLEFT", 1, 1)
    glassBottom:SetPoint("BOTTOMRIGHT", -1, 1)
    glassBottom:SetHeight(math.floor(self.db.window.height * 0.42))
    window.KT_GlassBottom = glassBottom

    local tabsHolder = CreateFrame("Frame", nil, window)
    tabsHolder:SetPoint("BOTTOMLEFT", window, "TOPLEFT", 2, -2)
    tabsHolder:SetPoint("BOTTOMRIGHT", window, "TOPRIGHT", -4, -2)
    tabsHolder:SetHeight(34)
    window.KT_TabsHolder = tabsHolder
    window.KT_Tabs = {}

    local header = CreateFrame("Frame", nil, window, "BackdropTemplate")
    header:SetPoint("TOPLEFT", window, "TOPLEFT", 12, -8)
    header:SetPoint("TOPRIGHT", window, "TOPRIGHT", -12, -8)
    header:SetHeight(30)
    KT_SetButtonBackdrop(header)
    header:SetBackdropColor(0, 0, 0, 0)
    header:SetBackdropBorderColor(0, 0, 0, 0)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            window:StartMoving()
        end
    end)
    header:SetScript("OnDragStop", function()
        window:StopMovingOrSizing()
        self:SaveWindowPosition()
    end)
    window.KT_Header = header

    local content = CreateFrame("Frame", nil, window, "BackdropTemplate")
    content:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    content:SetFrameLevel(window:GetFrameLevel() + 1)
    KT_SetButtonBackdrop(content)
    content:SetBackdropColor(0, 0, 0, 0)
    content:SetBackdropBorderColor(0, 0, 0, 0)
    window.KT_Content = content

    local fade = content:CreateTexture(nil, "BACKGROUND")
    fade:SetAllPoints()
    window.KT_BackdropFade = fade

    local contentTopGlow = content:CreateTexture(nil, "ARTWORK")
    contentTopGlow:SetPoint("TOPLEFT", 0, 0)
    contentTopGlow:SetPoint("TOPRIGHT", 0, 0)
    contentTopGlow:SetHeight(38)
    window.KT_ContentTopGlow = contentTopGlow

    local contentBottomShade = content:CreateTexture(nil, "BORDER")
    contentBottomShade:SetPoint("BOTTOMLEFT", 0, 0)
    contentBottomShade:SetPoint("BOTTOMRIGHT", 0, 0)
    contentBottomShade:SetHeight(72)
    window.KT_ContentBottomShade = contentBottomShade

    local sideBar = CreateFrame("Frame", nil, window)
    sideBar:SetPoint("TOPRIGHT", window, "TOPLEFT", 2, -2)
    sideBar:SetPoint("BOTTOMRIGHT", window, "BOTTOMLEFT", 2, 2)
    sideBar:SetWidth(40)
    sideBar:SetFrameStrata(window:GetFrameStrata())
    sideBar:SetFrameLevel((window:GetFrameLevel() or 0) + 20)
    window.KT_SideBar = sideBar

    local whisperStrip = CreateFrame("Frame", nil, window)
    whisperStrip:SetPoint("TOPLEFT", content, "TOPRIGHT", 0, -12)
    whisperStrip:SetPoint("BOTTOMLEFT", content, "BOTTOMRIGHT", 0, 48)
    whisperStrip:SetWidth(tonumber(KT_CHAT_WHISPER_STRIP_WIDTH) or 42)
    whisperStrip:Hide()
    window.KT_WhisperStrip = whisperStrip
    window.KT_WhisperStripButtons = {}

    for index = 1, (tonumber(KT_CHAT_WHISPER_STRIP_MAX_BUTTONS) or 6) do
        local button = CreateFrame("Button", nil, whisperStrip, "BackdropTemplate")
        button:SetSize(tonumber(KT_CHAT_WHISPER_STRIP_BUTTON_SIZE) or 32, tonumber(KT_CHAT_WHISPER_STRIP_BUTTON_SIZE) or 32)
        if index == 1 then
            button:SetPoint("TOP", whisperStrip, "TOP", 0, 0)
        else
            button:SetPoint("TOP", window.KT_WhisperStripButtons[index - 1], "BOTTOM", 0, -(tonumber(KT_CHAT_WHISPER_STRIP_SPACING) or 6))
        end
        KT_StyleActionButton(button)
        button.KT_Icon = KT_StyleActionTexture(button, KT_CHAT_ICON_PATH .. "Whisp.png", false)
        if button.KT_Icon and button.KT_Icon.SetDesaturated then
            button.KT_Icon:SetDesaturated(true)
        end
        button.KT_Icon:SetSize(16, 16)
        button.KT_Icon:SetPoint("TOP", button, "TOP", 0, -4)
        button.KT_Icon:SetVertexColor(0.42, 0.78, 1, 0.95)
        button.KT_Label = button:CreateFontString(nil, "OVERLAY")
        button.KT_Label:SetFont(KT_DEFAULT_FONT, 8, "OUTLINE")
        button.KT_Label:SetPoint("BOTTOM", button, "BOTTOM", 0, 3)
        button.KT_Label:SetTextColor(0.92, 0.96, 1, 0.95)
        button.KT_Close = CreateFrame("Button", nil, button, "BackdropTemplate")
        button.KT_Close:SetSize(10, 10)
        button.KT_Close:SetPoint("TOPRIGHT", button, "TOPRIGHT", 1, -1)
        KT_SetButtonBackdrop(button.KT_Close)
        button.KT_Close:SetBackdropColor(0.14, 0.04, 0.06, 0.94)
        button.KT_Close:SetBackdropBorderColor(0.55, 0.22, 0.26, 0.95)
        button.KT_Close.Text = button.KT_Close:CreateFontString(nil, "OVERLAY")
        button.KT_Close.Text:SetFont(KT_DEFAULT_FONT, 7, "OUTLINE")
        button.KT_Close.Text:SetPoint("CENTER", 0, 0)
        button.KT_Close.Text:SetText("x")
        button.KT_Close.Text:SetTextColor(1, 0.88, 0.88, 1)
        if button.KT_Close.SetPropagateMouseClicks then
            button.KT_Close:SetPropagateMouseClicks(false)
        end
        button.KT_Close:SetScript("OnClick", function(closeButton)
            local parentButton = closeButton:GetParent()
            if parentButton then
                -- The close control is nested inside the target button. Mark
                -- the parent so a propagated click cannot reopen the target.
                parentButton.KT_SuppressNextClick = true
                local target = parentButton.KT_Target
                local bnetIDAccount = parentButton.KT_BNetAccountID
                if target then
                    self:RemoveWhisperTarget(target, bnetIDAccount)
                end
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        if parentButton then
                            parentButton.KT_SuppressNextClick = nil
                        end
                    end)
                end
            end
        end)
        KT_SetTooltip(button.KT_Close, "Close")
        button.KT_Close:Hide()
        button:SetScript("OnClick", function(widget)
            if widget.KT_SuppressNextClick then
                widget.KT_SuppressNextClick = nil
                return
            end
            if widget.KT_Target then
                self:HandleWhisperStripClick(widget.KT_Target, widget.KT_BNetAccountID, widget.KT_ChatType)
            end
        end)
        window.KT_WhisperStripButtons[index] = button
    end

    local frame = self:CreateMessageFrame(content, "KT_ChatFrame")
    self:RegisterMessageFrame(frame, function(entry)
        local tab = self:GetActiveTab()
        return not tab or not tab.filter or tab.filter(entry)
    end)
    self:ApplyNormalChatFrameLayout()

    local scrollButton = CreateFrame("Button", nil, content, "BackdropTemplate")
    scrollButton:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 46)
    scrollButton:SetSize(24, 24)
    scrollButton:SetFrameLevel(content:GetFrameLevel() + 3)
    KT_StyleActionButton(scrollButton)
    local scrollIcon = KT_StyleActionTexture(scrollButton, KT_CHAT_SCROLL_TEXTURE, false)
    scrollIcon:SetSize(14, 14)
    scrollIcon:SetPoint("CENTER")
    scrollButton.KT_Icon = scrollIcon
    scrollButton:SetScript("OnClick", function()
        local activeFrame = self:GetActiveMessageFrame()
        if activeFrame and activeFrame.ScrollToBottom then
            activeFrame:ScrollToBottom()
            self:UpdateScrollButtonVisibility()
        end
    end)
    KT_SetTooltip(scrollButton, "Scroll to bottom")
    window.KT_ScrollButton = scrollButton

    local footer = CreateFrame("Frame", nil, window, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(40)
    footer:SetFrameLevel(window:GetFrameLevel() + 20)
    KT_SetButtonBackdrop(footer)
    footer:SetBackdropColor(0, 0, 0, 0)
    footer:SetBackdropBorderColor(0, 0, 0, 0)
    window.KT_Footer = footer

    local footerGlow = footer:CreateTexture(nil, "ARTWORK")
    footerGlow:SetPoint("TOPLEFT", 0, 0)
    footerGlow:SetPoint("TOPRIGHT", 0, 0)
    footerGlow:SetHeight(24)
    window.KT_FooterGlow = footerGlow

    local inputHost = CreateFrame("Frame", nil, footer, "BackdropTemplate")
    inputHost:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, -2)
    inputHost:SetPoint("BOTTOMRIGHT", footer, "BOTTOMRIGHT", -58, 0)
    inputHost:SetFrameLevel(footer:GetFrameLevel() + 1)
    KT_SetButtonBackdrop(inputHost)
    inputHost:SetBackdropColor(0, 0, 0, 0)
    inputHost:SetBackdropBorderColor(0, 0, 0, 0)
    inputHost:EnableMouse(true)
    inputHost:SetScript("OnMouseDown", function()
        self:FocusInputForActiveTab()
    end)
    window.KT_InputHost = inputHost

    local inputGlow = inputHost:CreateTexture(nil, "ARTWORK")
    inputGlow:SetPoint("TOPLEFT", 0, 0)
    inputGlow:SetPoint("TOPRIGHT", 0, 0)
    inputGlow:SetHeight(18)
    window.KT_InputGlow = inputGlow

    local sendButton = CreateFrame("Button", nil, footer, "BackdropTemplate")
    sendButton:SetPoint("RIGHT", footer, "RIGHT", -4, -1)
    sendButton:SetSize(42, 30)
    sendButton:SetFrameLevel(inputHost:GetFrameLevel() + 1)
    KT_StyleActionButton(sendButton)
    sendButton.KT_Icon = KT_StyleActionTexture(sendButton, KT_CHAT_SEND_ICON, false)
    sendButton.KT_Icon:SetSize(18, 18)
    sendButton.KT_Icon:SetPoint("CENTER")
    sendButton:SetScript("OnClick", function()
        if _G.ChatFrame1EditBox then
            if not _G.ChatFrame1EditBox:IsShown() then
                self:FocusInputForActiveTab()
            else
                KT_SendEditText(_G.ChatFrame1EditBox)
            end
        end
    end)
    window.KT_SendButton = sendButton

    self:RefreshTabButtons()
    self:RefreshChatFrameMode()
    self:QueueChatLayoutReflow()

    if self.db.window.visible then
        window:Show()
    else
        window:Hide()
    end

    self:ApplyPanelColor()
    self:HookBlizzardEditBox()
    self:AttachSidebarControls()
    self:UpdateSocialButton()
    self:PrimeDedicatedNativeTabFrames(window.KT_Content)
    self:UpdateScrollButtonVisibility()
    self:EnsureWindowFadeWake(window)

    if self.db.fadeEnabled ~= false and not (_G.ChatFrame1EditBox and _G.ChatFrame1EditBox:IsShown()) then
        if #self.history == 0 then
            window:SetAlpha(0)
        else
            self:ScheduleWindowFade()
        end
    else
        window:SetAlpha(1)
    end

    return window
end
function Mod:BuildEntryFromCombatLog()
    if not CombatLogGetCurrentEventInfo then
        return nil
    end

    local info = { CombatLogGetCurrentEventInfo() }
    local subevent = KT_GetNonEmptyAccessibleString(info[2])
    if not subevent then
        return nil
    end

    local sourceGUID = KT_GetNonEmptyAccessibleString(info[4])
    local sourceName = KT_GetNonEmptyAccessibleString(info[5])
    local destName = KT_GetNonEmptyAccessibleString(info[9])
    local summary = KT_GetNonEmptyAccessibleString(
        self:BuildCombatLogSummary(subevent, sourceName, destName, unpack(info, 12)),
        KT_SECRET_PLACEHOLDER
    ) or KT_SECRET_PLACEHOLDER
    local r, g, b = self:GetCombatLogColor(subevent)
    local timestamp = date("%H:%M")
    local label = KT_LText("Combat Log")
    local author = KT_AmbiguateAccessibleName(sourceName)

    local entry = {
        rawMessage = summary,
        r = r,
        g = g,
        b = b,
        event = "COMBAT_LOG_EVENT_UNFILTERED",
        chatType = "COMBAT",
        timestamp = timestamp,
        label = label,
        channelName = nil,
        author = author,
        senderGUID = sourceGUID,
        searchText = self:BuildSearchText({
            timestamp,
            label,
            subevent,
            author or "",
            destName or "",
            summary,
        }),
    }
    entry.message = self:GetEntryMessage(entry)
    return entry
end
function Mod:OnCombatLogEvent()
    if not self:ShouldCaptureCombatLog() then
        return
    end

    local entry = self:BuildEntryFromCombatLog()
    if not entry then
        return
    end

    local handleIncomingEntry = rawget(self, "HandleIncomingEntry") or rawget(Mod, "HandleIncomingEntry")
    if type(handleIncomingEntry) == "function" then
        handleIncomingEntry(self, entry)
        return
    end

    local pushed = self:PushHistory(entry)
    if pushed then
        self:RecordChatActivity()
        self:ShowWindowForActivity(false)
        self:AddEntryToFrames(pushed)
        self:ScheduleWindowFade()
        self:UpdateScrollButtonVisibility()
    end
end

function Mod:OnChatEvent(event, ...)
    return
end

function Mod:EnsureWhisperVisibleInGeneral(entry)
    if type(entry) ~= "table" then
        return
    end

    local frame = _G.ChatFrame1
    if not frame or type(frame.AddMessage) ~= "function" then
        return
    end

    local dedupeKey = entry.lineID
    if dedupeKey == nil then
        dedupeKey = table.concat({
            KT_SafeString(entry.chatType, ""),
            KT_SafeString(entry.bnSenderID, ""),
            KT_SafeString(entry.authorRaw or entry.author, ""),
            KT_SafeString(entry.rawMessage or entry.message, ""),
            KT_SafeString(entry.timestamp, ""),
        }, "|")
    end

    if dedupeKey ~= nil and self.lastGeneralWhisperKey == dedupeKey then
        return
    end
    self.lastGeneralWhisperKey = dedupeKey

    local message = KT_GetAccessibleString(entry.rawMessage, KT_GetAccessibleString(entry.message, "")) or ""
    local linkText = KT_BuildWhisperDisplayLink(entry)
    local parts = {}
    local timestamp = KT_GetAccessibleString(entry.timestamp, nil)
    local label = KT_GetAccessibleString(entry.label, nil)

    if type(timestamp) == "string" and timestamp ~= "" then
        parts[#parts + 1] = "[" .. timestamp .. "]"
    end
    if type(label) == "string" and label ~= "" then
        parts[#parts + 1] = "[" .. label .. "]"
    end
    if type(linkText) == "string" and linkText ~= "" then
        parts[#parts + 1] = linkText .. ":"
    else
        local safeAuthor = KT_GetAccessibleString(entry.author, nil)
        if type(safeAuthor) == "string" and safeAuthor ~= "" then
            parts[#parts + 1] = safeAuthor .. ":"
        end
    end
    if message ~= "" then
        parts[#parts + 1] = message
    end

    local rendered = table.concat(parts, " ")
    if rendered == "" then
        rendered = self:GetEntryMessage(entry)
    end
    if not rendered or rendered == "" then
        rendered = KT_GetNonEmptyAccessibleString(entry.renderedMessage, entry.message)
    end
    if not rendered or rendered == "" then
        return
    end

    pcall(frame.AddMessage, frame, rendered, entry.r or 1, entry.g or 1, entry.b or 1)
end
function Mod:OnWhisperEvent(event, ...)
    if not self.runtimeInitialized or not self.chatEventsRegistered then
        return
    end

    local entry = self:BuildEntryFromEvent(event, ...)
    if not entry then
        return
    end

    local chatType = entry.chatType or ""
    if chatType == "WHISPER" or chatType == "BN_WHISPER" or chatType == "WHISPER_INFORM" or chatType == "BN_WHISPER_INFORM" then
        -- Only confirmed message events create or refresh conversations. The
        -- edit box target changes continuously while typing commands such as
        -- /w Franzhunter and must never create entries for partial names.
        local sender = KT_GetNonEmptyAccessibleString(entry.authorRaw) or KT_GetNonEmptyAccessibleString(entry.author)
        if (chatType == "BN_WHISPER" or chatType == "BN_WHISPER_INFORM") and type(entry.bnSenderID) == "number" then
            sender = KT_ResolveBNetWhisperTarget(entry.bnSenderID) or KT_GetNonEmptyAccessibleString(entry.author) or sender
        end
        if sender then
            entry.whisperTarget = sender
            entry.whisperThreadKey = KT_GetWhisperTargetKey(sender, chatType, entry.bnSenderID)
            self:AddWhisperTarget(sender, chatType, false, entry.bnSenderID)
        end
    end

    local handleIncomingEntry = rawget(self, "HandleIncomingEntry") or rawget(Mod, "HandleIncomingEntry")
    if type(handleIncomingEntry) == "function" then
        handleIncomingEntry(self, entry)
        return true
    end

    local pushed = self:PushHistory(entry)
    if pushed then
        self:RecordChatActivity()
        self:ShowWindowForActivity(false)
        self:AddEntryToFrames(pushed)
        self:ScheduleWindowFade()
        self:UpdateScrollButtonVisibility()
    end
    return pushed ~= nil
end

function Mod:EnsureBridgeFrame(parent)
    if not parent then
        return nil
    end

    local frame = self.bridgeFrames[parent]
    if frame then
        return frame
    end

    frame = self:CreateMessageFrame(parent, nil)
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -22)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -15, 0)
    self.bridgeFrames[parent] = frame
    self:RegisterMessageFrame(frame, nil)
    return frame
end
function Mod:InstallIntoChattynator(parent)
    KT_SafeCallback(function()
        local frame = self:EnsureBridgeFrame(parent)
        if frame then
            frame:SetParent(parent)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -22)
            frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -15, 0)
            frame:Show()
            self:RenderFrame(frame)
        end
    end)
end

function Mod:RegisterWithUnlockMode()
    if self.unlockRegistered or not _G.KT_ChatWindow then
        return
    end

    KT.RegisterUnlockElement(KT_CHAT_DB_KEY, {
        label = "Chat",
        group = "Other",
        order = 120,
        getFrame = function()
            return _G.KT_ChatWindow
        end,
        getSize = function()
            return _G.KT_ChatWindow:GetWidth(), _G.KT_ChatWindow:GetHeight()
        end,
        getScale = function()
            return _G.KT_ChatWindow:GetScale()
        end,
        loadPosition = function()
            local saved = KT.db.profile.editMode
                and KT.db.profile.editMode.frames
                and KT.db.profile.editMode.frames[KT_CHAT_DB_KEY]
            if saved and saved.point then
                return saved
            end
            return nil
        end,
        savePosition = function(_, pt, rpt, x, y)
            KT.db.profile.editMode = KT.db.profile.editMode or {}
            KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}
            KT.db.profile.chat = KT.db.profile.chat or {}
            KT.db.profile.chat.window = KT.db.profile.chat.window or {}
            KT.db.profile.chat.window.scale = _G.KT_ChatWindow:GetScale()
            KT.db.profile.editMode.frames[KT_CHAT_DB_KEY] = {
                point = pt,
                relativePoint = rpt,
                x = x,
                y = y,
                scale = _G.KT_ChatWindow:GetScale(),
            }
            self:RecordPositionDebug("UnlockMode savePosition")
        end,
        applyPosition = function()
            local saved = KT.db.profile.editMode
                and KT.db.profile.editMode.frames
                and KT.db.profile.editMode.frames[KT_CHAT_DB_KEY]
            if saved and saved.point then
                if saved.scale and _G.KT_ChatWindow.SetScale then
                    _G.KT_ChatWindow:SetScale(saved.scale)
                    KT.db.profile.chat.window.scale = saved.scale
                end
                _G.KT_ChatWindow:ClearAllPoints()
                _G.KT_ChatWindow:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
            end
        end,
    })

    self.unlockRegistered = true
end

function Mod:RegisterChattynatorBridge()
    local api = KT_IsChattynatorActive()
    if not api or self.bridgeRegistered or not KT_IsChattynatorCompatible() then
        return
    end

    api.RegisterCustomTab(KT_CHAT_TAB_LABEL, KT_CHAT_TAB_ID, function(parent)
        self:InstallIntoChattynator(parent)
    end)
    api.AddModifier(self.bridgeModifier)
    self.bridgeRegistered = true
end

function Mod:SendMessageToChat(message, r, g, b)
    local text = KT_SafeString(message, "")
    local red = r or KT_BRAND_COLOR.r
    local green = g or KT_BRAND_COLOR.g
    local blue = b or KT_BRAND_COLOR.b

    self:PushHistory({
        message = format("[%s] %s", date("%H:%M"), text),
        rawMessage = text,
        r = red,
        g = green,
        b = blue,
        event = "CHAT_MSG_ADDON",
        chatType = "ADDON",
        label = "Addon",
        channelName = KT_MODULE_NAME,
        author = KT_MODULE_NAME,
        searchText = self:BuildSearchText({
            KT_MODULE_NAME,
            text,
        }),
    })
    self:RenderAllFrames()

    if _G.KT_ChatWindow then
        if self.db.window.visible then
            _G.KT_ChatWindow:Show()
        end
        return true
    end

    print(text)
    return false
end
