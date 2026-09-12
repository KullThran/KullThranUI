local addonName, ns = ...
local KT = (ns and ns.KT) or _G.KT
if not KT then
    return
end

local Mod = KT:GetModule("Enhancements", true) or KT:NewModule("Enhancements", "AceEvent-3.0")
ns.Enhancements = Mod

local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local C_BattleNet = _G.C_BattleNet
local C_Club = _G.C_Club
local C_Container = _G.C_Container
local C_CurrencyInfo = _G.C_CurrencyInfo
local C_FriendList = _G.C_FriendList
local C_GossipInfo = _G.C_GossipInfo
local C_Item = _G.C_Item
local C_LFGList = _G.C_LFGList
local C_QuestLog = _G.C_QuestLog
local C_QuestSession = _G.C_QuestSession
local C_SummonInfo = _G.C_SummonInfo
local Enum = _G.Enum
local GetLFGMode = _G.GetLFGMode
local GetNumLootItems = _G.GetNumLootItems
local GetNumQuestChoices = _G.GetNumQuestChoices
local GetNumSubgroupMembers = _G.GetNumSubgroupMembers
local GetRepairAllCost = _G.GetRepairAllCost
local GetTime = _G.GetTime
local GetQuestReward = _G.GetQuestReward
local IsInGuild = _G.IsInGuild
local IsInInstance = _G.IsInInstance
local IsModifiedClick = _G.IsModifiedClick
local IsShiftKeyDown = _G.IsShiftKeyDown
local LootSlot = _G.LootSlot
local BNDeclineFriendInvite = _G.BNDeclineFriendInvite
local BNGetFriendInviteInfo = _G.BNGetFriendInviteInfo
local BNGetNumFriendInvites = _G.BNGetNumFriendInvites
local BNGetNumFriends = _G.BNGetNumFriends
local BNInviteFriend = _G.BNInviteFriend
local CanGuildBankRepair = _G.CanGuildBankRepair
local CanMerchantRepair = _G.CanMerchantRepair
local CommunitiesUtil = _G.CommunitiesUtil
local CompleteQuest = _G.CompleteQuest
local ConfirmAcceptQuest = _G.ConfirmAcceptQuest
local ConfirmLootRoll = _G.ConfirmLootRoll
local ConfirmLootSlot = _G.ConfirmLootSlot
local DeclineGroup = _G.DeclineGroup
local DeclineQuest = _G.DeclineQuest
local GetActiveTitle = _G.GetActiveTitle
local GetAvailableTitle = _G.GetAvailableTitle
local GetGuildRosterInfo = _G.GetGuildRosterInfo
local GetInviteConfirmationInfo = _G.GetInviteConfirmationInfo
local GetNumActiveQuests = _G.GetNumActiveQuests
local GetNumAvailableQuests = _G.GetNumAvailableQuests
local GuildRoster = _G.GuildRoster
local IsQuestCompletable = _G.IsQuestCompletable
local QuestFont = _G.QuestFont
local QuestFontNormalSmall = _G.QuestFontNormalSmall
local QuestGetAutoAccept = _G.QuestGetAutoAccept
local QuestRequiresCurrency = _G.QuestRequiresCurrency
local QuestRequiresGold = _G.QuestRequiresGold
local QuestSessionManager = _G.QuestSessionManager
local QuestTitleFont = _G.QuestTitleFont
local RepairAllItems = _G.RepairAllItems
local RespondMailLockSendItem = _G.RespondMailLockSendItem
local RespondToInviteConfirmation = _G.RespondToInviteConfirmation
local SelectActiveQuest = _G.SelectActiveQuest
local SelectAvailableQuest = _G.SelectAvailableQuest
local SellCursorItem = _G.SellCursorItem
local SendMailBodyEditBox = _G.SendMailBodyEditBox
local SetAllowLowLevelRaid = _G.SetAllowLowLevelRaid
local SetCVar = _G.SetCVar
local ShowQuestComplete = _G.ShowQuestComplete
local Sound_GameSystem_RestartSoundSystem = _G.Sound_GameSystem_RestartSoundSystem
local StaticPopup_FindVisible = _G.StaticPopup_FindVisible
local StaticPopup_Hide = _G.StaticPopup_Hide
local StaticPopup_OnClick = _G.StaticPopup_OnClick
local StaticPopup_Visible = _G.StaticPopup_Visible
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitExists = _G.UnitExists
local UnitGUID = _G.UnitGUID
local UnitIsDead = _G.UnitIsDead
local UnitIsGroupAssistant = _G.UnitIsGroupAssistant
local UnitIsGroupLeader = _G.UnitIsGroupLeader
local UnitIsPlayer = _G.UnitIsPlayer
local UnitInParty = _G.UnitInParty
local UnitInRaid = _G.UnitInRaid
local UnitName = _G.UnitName
local AcceptGroup = _G.AcceptGroup
local AcceptQuest = _G.AcceptQuest
local AcceptResurrect = _G.AcceptResurrect
local CancelDuel = _G.CancelDuel
local CloseQuest = _G.CloseQuest
local hooksecurefunc = _G.hooksecurefunc
local InCombatLockdown = _G.InCombatLockdown
local ipairs = _G.ipairs
local math = _G.math
local pairs = _G.pairs
local strlower = _G.strlower
local strsplit = _G.strsplit
local strtrim = _G.strtrim
local tostring = _G.tostring
local type = _G.type
local UIParent = _G.UIParent

local function LText(text)
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

local ACTION_BUTTON_GROUPS = {
    { prefix = "ActionButton", count = 12 },
    { prefix = "MultiBarBottomLeftButton", count = 12 },
    { prefix = "MultiBarBottomRightButton", count = 12 },
    { prefix = "MultiBarRightButton", count = 12 },
    { prefix = "MultiBarLeftButton", count = 12 },
    { prefix = "MultiBar5Button", count = 12 },
    { prefix = "MultiBar6Button", count = 12 },
    { prefix = "MultiBar7Button", count = 12 },
    { prefix = "PetActionButton", count = 10 },
    { prefix = "StanceButton", count = 10 },
    { prefix = "OverrideActionBarButton", count = 6 },
    { prefix = "PossessButton", count = 2 },
    { prefix = "ExtraActionButton", count = 1 },
}

local BODYGUARD_IDS = { 1733, 1736, 1737, 1738, 1739, 1740, 1741 }
local RESURRECT_EXCLUDE_NAMES = {
    ["Failure Detection Pylon"] = true,
    ["Pilon detector de errores"] = true,
    ["Pilón detector de errores"] = true,
    ["Brazier of Awakening"] = true,
    ["Blandon de Despertar"] = true,
    ["Blandón de Despertar"] = true,
}

local DEFAULTS = {
    enable = true,
    automation = {
        autoQuests = false,
        autoGossip = false,
        acceptSummon = false,
        acceptResurrection = false,
        releaseInPvP = false,
        deathReleaseProtection = false,
        sellJunk = false,
        autoRepair = false,
        repairUseGuildFunds = false,
        repairShowSummary = false,
        vendorShowSummary = false,
        durabilityWarning = false,
        durabilityThreshold = 30,
        skipLFGRoleCheck = false,
        lfgRoles = {
            tank = false,
            healer = false,
            damager = false,
        },
    },
    blocks = {
        blockDuels = false,
        blockPetBattleDuels = false,
        blockPartyInvites = false,
        blockRequestedInvites = false,
        blockFriendRequests = false,
        blockSharedQuests = false,
    },
    groups = {
        partyFromFriends = false,
        syncFromFriends = false,
        queueFromFriends = false,
        inviteFromWhispers = false,
        whisperKeyword = "inv",
        whisperFriendsOnly = false,
        guildAsFriends = false,
        communitiesAsFriends = false,
        persistentLFGNoteEnabled = false,
        persistentLFGNote = "",
        persistentLFGNoteBackup = "",
    },
    social = {
        enhancedFriendList = true,
        friendGroups = {},
        friendGroupAssignments = {},
    },
    visibility = {
        hideErrorMessages = false,
        hideZoneText = false,
        hideKeybindText = false,
        hideMacroText = false,
        hideAlerts = false,
        hideBodyguardGossip = false,
        hideTalkingFrame = false,
        hideCleanupButtons = false,
        hideBossBanner = false,
        hideEventToasts = false,
        hideStanceBar = false,
        skipQueueConfirmation = false,
        hideMinimapIcon = false,
    },
    textSize = {
        resizeMailText = false,
        mailFontSize = 16,
        resizeQuestText = false,
        questFontSize = 14,
    },
    graphicsSound = {
        disableScreenGlow = false,
        disableScreenEffects = false,
        setWeatherDensity = false,
        weatherDensity = 0,
        maxCameraZoom = true,
        keepAudioSynced = false,
    },
    gameOptions = {
        removeRaidRestrictions = false,
        disableLootWarnings = false,
        fasterAutoLoot = false,
        autoLootDelay = 0.1,
        fasterMovieSkip = false,
        combatPlates = false,
        easyItemDestroy = false,
        autoInsertKeystone = false,
        ahCurrentExpansion = false,
    },
    combatRez = {
        enabled = false,
        deathWarning = true,
    },
    equipmentReminder = {
        enabled = false,
        showOnInstance = true,
        showOnReadyCheck = true,
        enchantCheck = false,
        useAllSpecs = true,
        autoHideDelay = 10,
        iconSize = 40,
    },
    optimizations = {
        spellQueueWindow = 150,
    },
    combatText = {
        enabled = false,
        enterEnabled = true,
        leaveEnabled = true,
        enterText = LText("IN COMBAT"),
        leaveText = LText("OUT OF COMBAT"),
        enterColor = { r = 1, g = 0.18, b = 0.18, a = 1 },
        leaveColor = { r = 0.20, g = 1, b = 0.45, a = 1 },
        backgroundColor = { r = 0.01, g = 0.01, b = 0.015, a = 0.76 },
        showBackground = false,
        fontSize = 32,
        outline = "OUTLINE",
        animation = "fadeScale",
        duration = 1.6,
        fadeIn = 0.12,
        fadeOut = 0.35,
        position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 120 },
    },
    mplusTracker = {
        enabled = true,
        insertKeystoneAutomatically = false,
        showMillisecondsWhenDungeonCompleted = false,
        showRemainingTimeOnly = false,
        showTooltipCount = true,
        showDeathsTooltip = true,
        showBackground = false,
        showForcesGlow = false,
        scale = 1,
        barWidth = 271,
        barHeight = 10,
        keyFontSize = 16,
        keyDetailsFontSize = 13,
        timerFontSize = 26,
        forcesFontSize = 13,
        deathsFontSize = 15,
        objectivesFontSize = 12,
        globalFont = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf",
        barTexture = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga",
        backgroundColor = { r = 0.01, g = 0.01, b = 0.015, a = 0 },
        keyColor = { r = 0.761, g = 0, b = 1, a = 1 },
        keyDetailsColor = { r = 1, g = 0.804, b = 0.569, a = 1 },
        timerRunningColor = { r = 1, g = 0.808, b = 0.714, a = 1 },
        timerSuccessColor = { r = 0.118, g = 1, b = 0.714, a = 1 },
        timerExpiredColor = { r = 1, g = 0.16, b = 0.18, a = 1 },
        deathsColor = { r = 1, g = 0, b = 0.412, a = 1 },
        forcesColor = { r = 1, g = 1, b = 1, a = 1 },
        forcesBarColor = { r = 0.733, g = 0.62, b = 0.133, a = 1 },
        forcesGlowColor = { r = 1, g = 0.33, b = 0.08, a = 0.8 },
        bar1Color = { r = 0, g = 1, b = 0.478, a = 1 },
        bar2Color = { r = 0, g = 0.749, b = 1, a = 1 },
        bar3Color = { r = 0.796, g = 0, b = 1, a = 1 },
        objectivesColor = { r = 1, g = 1, b = 1, a = 1 },
        completedObjectivesColor = { r = 0, g = 1, b = 0.14, a = 1 },
        forcesFormat = ":percent:",
        currentPullFormat = "(+:percent:)",
        tooltipCountFormat = "+:count: / :percent:",
        objectivesOffset = 4,
        position = { point = "RIGHT", relativePoint = "RIGHT", x = -16, y = 224 },
    },
    combatTimer = {
        enabled = true,
        fontSize = 22,
        outline = "OUTLINE",
        color = { r = 1, g = 1, b = 1, a = 1 },
        backgroundColor = { r = 0.01, g = 0.01, b = 0.015, a = 0.78 },
        showBackground = false,
        scale = 1,
        position = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 150 },
    },
    damageMeter = {
        moduleEnabled = true,
        enabled = true,
        locked = false,
        showOnlyInCombat = false,
        showBackground = false,
        showIcons = true,
        iconMode = "spec",
        iconShape = "square",
        classColors = true,
        alwaysShowPlayer = false,
        showPercentages = false,
        mode = "damageDone",
        session = "current",
        width = 320,
        height = 220,
        autoHeight = true,
        rowHeight = 19,
        maxRows = 10,
        fontSize = 12,
        headerFontSize = 12,
        fontOutline = "OUTLINE",
        textColor = { r = 1, g = 1, b = 1, a = 1 },
        backgroundColor = { r = 0.012, g = 0.014, b = 0.02, a = 0.94 },
        font = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf",
        barTexture = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga",
        layoutVersion = 7,
        position = { point = "RIGHT", relativePoint = "RIGHT", x = -36, y = 0 },
        windows = {},
    },
}

local runtime = {
    hooksInstalled = false,
    bodyguardNames = nil,
    errorsHookInstalled = false,
    originalUIErrorsOnEvent = nil,
    originalLFGListApplicationDialog_Show = nil,
    patchedLFGListApplicationDialog_Show = nil,
    lfgNoteDialogPatched = false,
    lfgNoteHooksInstalled = false,
    lfgNoteEditBox = nil,
    lfgNoteShowHookInstalled = false,
    lfgNoteClearHookInstalled = false,
    lfgNoteDescriptionEditBoxHookInstalled = false,
    applyingPersistentLFGNote = false,
    lfgNoteCommandRegistered = false,
    questFontsStored = false,
    mailFontsStored = false,
    lastLootAt = 0,
    pendingStanceBarMouse = nil,
    combatTextKind = "enter",
}

local function SetMouseEnabledSafe(frame, enabled, pendingKey)
    if not (frame and frame.EnableMouse) then
        return false
    end

    if InCombatLockdown and InCombatLockdown() and frame.IsProtected and frame:IsProtected() then
        if pendingKey then
            runtime[pendingKey] = enabled and true or false
        end
        return false
    end

    if pendingKey then
        runtime[pendingKey] = nil
    end
    frame:EnableMouse(enabled and true or false)
    return true
end

local function NormalizePersistentLFGNote(noteText)
    if type(noteText) ~= "string" then
        return ""
    end

    return strtrim(noteText) or ""
end

local function IterateFrameChildren(root, callback, visited)
    if not (root and callback) then
        return
    end

    visited = visited or {}
    if visited[root] then
        return
    end
    visited[root] = true

    callback(root)

    if root.GetChildren then
        for _, child in ipairs({ root:GetChildren() }) do
            IterateFrameChildren(child, callback, visited)
        end
    end
end

local function AppendUniqueEditBox(list, seen, candidate)
    if not candidate then
        return
    end

    if candidate.GetObjectType and candidate:GetObjectType() == "EditBox" then
        if not seen[candidate] then
            seen[candidate] = true
            list[#list + 1] = candidate
        end
        return
    end

    if candidate.EditBox then
        AppendUniqueEditBox(list, seen, candidate.EditBox)
    end
    if candidate.InputBox then
        AppendUniqueEditBox(list, seen, candidate.InputBox)
    end
end

local function FindLFGApplicationNoteEditBoxes(root)
    if not root then
        return {}
    end

    local matches = {}
    local seen = {}
    local applicationDescription = _G.LFGListApplicationDialogDescription

    local candidates = {
        applicationDescription and applicationDescription.EditBox or nil,
        applicationDescription,
        root.Description,
        root.Description and root.Description.EditBox or nil,
        root.Comment,
        root.Message,
        root.EntryBox,
        root.EditBox,
        root.Description and root.Description.Comment or nil,
    }

    for _, candidate in ipairs(candidates) do
        AppendUniqueEditBox(matches, seen, candidate)
    end

    IterateFrameChildren(root, function(frame)
        if not (frame and frame.GetObjectType and frame:GetObjectType() == "EditBox") then
            return
        end

        local width = frame.GetWidth and frame:GetWidth() or 0
        local enabled = not frame.IsEnabled or frame:IsEnabled()
        if enabled and width > 40 and not seen[frame] then
            seen[frame] = true
            matches[#matches + 1] = frame
        end
    end)

    return matches
end

local function TrackPersistentLFGNoteEditBox(editBox)
    if not (editBox and editBox.HookScript and not editBox._KTEnhancementsPersistentLFGNoteHook) then
        return
    end

    editBox._KTEnhancementsPersistentLFGNoteHook = true
    editBox:HookScript("OnTextChanged", function(self)
        if runtime.applyingPersistentLFGNote then
            return
        end
        if not IsModuleEnabled() then
            return
        end

        local noteText = NormalizePersistentLFGNote(self.GetText and self:GetText() or "")
        if noteText == "" then
            return
        end

        if Mod and Mod.SetPersistentLFGNote then
            Mod:SetPersistentLFGNote(noteText)
        end
    end)
end

function Mod:SchedulePersistentLFGNotePopulate()
    local delays = { 0, 0.01, 0.03, 0.05, 0.1, 0.2, 0.4, 0.8, 1.2, 2.0 }
    for _, delay in ipairs(delays) do
        if C_Timer and C_Timer.After then
            C_Timer.After(delay, function()
                if Mod and Mod.ApplyPersistentLFGNote then
                    Mod:ApplyPersistentLFGNote()
                end
            end)
        elseif self and self.ApplyPersistentLFGNote then
            self:ApplyPersistentLFGNote()
        end
    end
end

local function CopyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, nested in pairs(value) do
        copy[key] = CopyValue(nested)
    end
    return copy
end

local function MergeDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = CopyValue(value)
        elseif type(value) == "table" and type(target[key]) == "table" then
            MergeDefaults(target[key], value)
        end
    end
end

local function SafeCoinText(amount)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinText then
        return C_CurrencyInfo.GetCoinText(amount or 0)
    end
    return tostring(amount or 0)
end

local function NormalizeName(name)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    local shortName = strsplit("-", name, 2)
    return shortName or name
end

IsModuleEnabled = function()
    local db = Mod:GetDB()
    return db.enable ~= false
end

local function GetCombatTextDB()
    local db = Mod:GetDB()
    db.combatText = db.combatText or CopyValue(DEFAULTS.combatText)
    db.combatText.position = db.combatText.position or CopyValue(DEFAULTS.combatText.position)
    return db.combatText
end

local function GetCombatTextMessage(config, kind)
    local isLeaving = kind == "leave"
    local defaultText = isLeaving and DEFAULTS.combatText.leaveText or DEFAULTS.combatText.enterText
    local text = isLeaving and config.leaveText or config.enterText
    if type(text) ~= "string" then
        text = defaultText
    end
    if text == defaultText then
        return LText(defaultText)
    end
    return text
end

function Mod:GetCombatTextMessage(kind)
    return GetCombatTextMessage(GetCombatTextDB(), kind)
end

function Mod:SetCombatTextMessage(kind, text)
    local config = GetCombatTextDB()
    text = type(text) == "string" and text or ""
    if kind == "leave" then
        config.leaveText = text
    else
        config.enterText = text
    end
end

function Mod:ApplyCombatTextPosition()
    local frame = self.combatTextFrame
    if not frame then
        return
    end

    local config = GetCombatTextDB()
    local position = config.position or DEFAULTS.combatText.position
    frame:ClearAllPoints()
    frame:SetPoint(
        position.point or "CENTER",
        UIParent,
        position.relativePoint or position.point or "CENTER",
        position.x or 0,
        position.y or 120
    )
end

function Mod:RefreshCombatTextStyle(kind)
    local frame = self.combatTextFrame
    if not (frame and frame.text) then
        return
    end

    local config = GetCombatTextDB()
    kind = kind or frame.combatTextKind or runtime.combatTextKind or "enter"
    local color = kind == "leave" and config.leaveColor or config.enterColor
    local fallback = kind == "leave" and DEFAULTS.combatText.leaveColor or DEFAULTS.combatText.enterColor
    color = type(color) == "table" and color or fallback
    local r = tonumber(color.r) or fallback.r
    local g = tonumber(color.g) or fallback.g
    local b = tonumber(color.b) or fallback.b
    local a = tonumber(color.a) or fallback.a
    local fontSize = math.max(10, math.min(72, tonumber(config.fontSize) or DEFAULTS.combatText.fontSize))
    local outline = config.outline
    if outline ~= "" and outline ~= "OUTLINE" and outline ~= "THICKOUTLINE" then
        outline = DEFAULTS.combatText.outline
    end

    local fontPath = KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
    local fontOK, fontApplied = pcall(frame.text.SetFont, frame.text, fontPath, fontSize, outline)
    if not fontOK or fontApplied == false then
        pcall(frame.text.SetFont, frame.text, "Fonts\\FRIZQT__.TTF", fontSize, outline)
    end
    frame.text:SetTextColor(r, g, b, a)

    local background = type(config.backgroundColor) == "table"
        and config.backgroundColor
        or DEFAULTS.combatText.backgroundColor
    if config.showBackground == true then
        KT:AddBackdrop(
            frame,
            tonumber(background.r) or DEFAULTS.combatText.backgroundColor.r,
            tonumber(background.g) or DEFAULTS.combatText.backgroundColor.g,
            tonumber(background.b) or DEFAULTS.combatText.backgroundColor.b,
            tonumber(background.a) or DEFAULTS.combatText.backgroundColor.a
        )
        KT:AddBorder(frame, r, g, b, math.min(1, a * 0.78), 1)
        if frame.bgKT and frame.bgKT.Show then
            frame.bgKT:Show()
        end
        if frame.borderKT and frame.borderKT.Show then
            frame.borderKT:Show()
        end
    else
        if frame.SetBackdrop then
            frame:SetBackdrop(nil)
        end
        if frame.bgKT and frame.bgKT.Hide then
            frame.bgKT:Hide()
        end
        if frame.borderKT and frame.borderKT.Hide then
            frame.borderKT:Hide()
        end
    end

    local textWidth = frame.text:GetStringWidth() or 0
    frame:SetSize(
        math.max(280, math.min(900, textWidth + (config.showBackground == true and 48 or 20))),
        math.max(48, fontSize + (config.showBackground == true and 28 or 14))
    )
end

function Mod:GetCombatTextFrame()
    if self.combatTextFrame then
        return self.combatTextFrame
    end

    local frame = CreateFrame("Frame", "KullThranUICombatStatusTextFrame", UIParent, "BackdropTemplate")
    frame:SetSize(520, 70)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(40)
    frame:EnableMouse(false)
    frame:Hide()

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.text:SetPoint("CENTER")
    frame.text:SetJustifyH("CENTER")
    frame.text:SetJustifyV("MIDDLE")

    self.combatTextFrame = frame
    self:ApplyCombatTextPosition()
    self:RefreshCombatTextStyle("enter")
    frame.text:SetText(self:GetCombatTextMessage("enter"))
    self:RefreshCombatTextStyle("enter")
    return frame
end

function Mod:HideCombatText()
    local frame = self.combatTextFrame
    if not frame then
        return
    end
    frame:SetScript("OnUpdate", nil)
    frame:SetAlpha(0)
    frame:SetScale(1)
    frame:Hide()
end

function Mod:ShowCombatText(kind, forcePreview)
    local config = GetCombatTextDB()
    kind = kind == "leave" and "leave" or "enter"
    if not forcePreview then
        if not (IsModuleEnabled() and config.enabled == true) then
            return
        end
        if (kind == "enter" and config.enterEnabled == false)
            or (kind == "leave" and config.leaveEnabled == false) then
            return
        end
    end

    local text = GetCombatTextMessage(config, kind)
    if strtrim(text or "") == "" then
        self:HideCombatText()
        return
    end

    runtime.combatTextKind = kind
    local frame = self:GetCombatTextFrame()
    frame.combatTextKind = kind
    self:RefreshCombatTextStyle(kind)
    frame.text:SetText(text)
    self:RefreshCombatTextStyle(kind)
    self:ApplyCombatTextPosition()

    local duration = math.max(0.1, tonumber(config.duration) or DEFAULTS.combatText.duration)
    local fadeIn = math.max(0, math.min(duration, tonumber(config.fadeIn) or DEFAULTS.combatText.fadeIn))
    local fadeOut = math.max(0, math.min(duration, tonumber(config.fadeOut) or DEFAULTS.combatText.fadeOut))
    local animation = config.animation or DEFAULTS.combatText.animation
    local elapsed = 0

    frame:SetScript("OnUpdate", nil)
    frame:SetScale(animation == "fadeScale" and 0.88 or 1)
    frame:SetAlpha(animation == "none" and 1 or 0)
    frame:Show()

    frame:SetScript("OnUpdate", function(display, delta)
        elapsed = elapsed + delta
        if elapsed >= duration then
            Mod:HideCombatText()
            return
        end

        local alpha = 1
        if animation ~= "none" then
            local inAlpha = fadeIn > 0 and math.min(1, elapsed / fadeIn) or 1
            local outAlpha = fadeOut > 0 and math.min(1, (duration - elapsed) / fadeOut) or 1
            alpha = math.min(inAlpha, outAlpha)
        end
        display:SetAlpha(alpha)

        if animation == "fadeScale" then
            local scaleProgress = fadeIn > 0 and math.min(1, elapsed / fadeIn) or 1
            local eased = 1 - ((1 - scaleProgress) * (1 - scaleProgress))
            display:SetScale(0.88 + (0.12 * eased))
        else
            display:SetScale(1)
        end
    end)
end

function Mod:PreviewCombatText(kind)
    self:ShowCombatText(kind, true)
end

function Mod:RegisterCombatTextMover()
    if self.combatTextMoverRegistered then
        return
    end
    if not (KT and KT.RegisterMovableElements) then
        return
    end

    KT:RegisterMovableElements({
        {
            key = "ENH_COMBAT_TEXT",
            label = LText("Combat Status Text"),
            group = "Enhancements",
            getFrame = function() return Mod:GetCombatTextFrame() end,
            getSize = function()
                local frame = Mod:GetCombatTextFrame()
                return frame:GetWidth(), frame:GetHeight()
            end,
            isHidden = function()
                return GetCombatTextDB().enabled ~= true
            end,
            loadPosition = function()
                local position = GetCombatTextDB().position or DEFAULTS.combatText.position
                return {
                    point = position.point or "CENTER",
                    relativePoint = position.relativePoint or position.point or "CENTER",
                    x = position.x or 0,
                    y = position.y or 120,
                }
            end,
            savePosition = function(_, point, relativePoint, x, y)
                GetCombatTextDB().position = {
                    point = point or "CENTER",
                    relativePoint = relativePoint or point or "CENTER",
                    x = x or 0,
                    y = y or 120,
                }
            end,
            applyPosition = function()
                Mod:ApplyCombatTextPosition()
            end,
            applyPendingPosition = function(_, position)
                local frame = Mod:GetCombatTextFrame()
                frame:ClearAllPoints()
                frame:SetPoint(
                    position.point or "CENTER",
                    UIParent,
                    position.relativePoint or position.point or "CENTER",
                    position.x or 0,
                    position.y or 120
                )
            end,
        },
    })
    self.combatTextMoverRegistered = true
end

local function IterateActionButtons(callback)
    for _, group in ipairs(ACTION_BUTTON_GROUPS) do
        for index = 1, group.count do
            local button = _G[group.prefix .. index]
            if button then
                callback(button)
            end
        end
    end
end

function Mod:GetDefaults()
    return DEFAULTS
end

function Mod:GetDB()
    KT.db.profile.enhancements = KT.db.profile.enhancements or {}
    MergeDefaults(KT.db.profile.enhancements, DEFAULTS)
    local enhancements = KT.db.profile.enhancements
    local groups = enhancements.groups
    if groups then
        local primaryNote = NormalizePersistentLFGNote(groups.persistentLFGNote)
        local backupNote = NormalizePersistentLFGNote(groups.persistentLFGNoteBackup)
        if primaryNote == "" and backupNote ~= "" then
            groups.persistentLFGNote = backupNote
        elseif primaryNote ~= "" and backupNote ~= primaryNote then
            groups.persistentLFGNoteBackup = primaryNote
        end
    end
    if groups
        and groups.persistentLFGNoteMigrationDone ~= true
        and groups.persistentLFGNoteEnabled == false
        and NormalizePersistentLFGNote(groups.persistentLFGNote) ~= ""
    then
        groups.persistentLFGNoteEnabled = true
        groups.persistentLFGNoteMigrationDone = true
    end
    return enhancements
end

function Mod:GetPersistentLFGNote()
    local db = self:GetDB()
    local groups = db and db.groups
    if not groups then
        return ""
    end

    local noteText = NormalizePersistentLFGNote(groups.persistentLFGNote)
    if noteText == "" then
        noteText = NormalizePersistentLFGNote(groups.persistentLFGNoteBackup)
        if noteText ~= "" then
            groups.persistentLFGNote = noteText
        end
    end
    return noteText
end

function Mod:SetPersistentLFGNote(noteText)
    local db = self:GetDB()
    local groups = db.groups
    local normalized = NormalizePersistentLFGNote(noteText)

    groups.persistentLFGNote = normalized
    groups.persistentLFGNoteBackup = normalized
    groups.persistentLFGNoteMigrationDone = true
    groups.persistentLFGNoteEnabled = normalized ~= ""

    return normalized
end

function Mod:RegisterPersistentLFGNoteCommand()
    if runtime.lfgNoteCommandRegistered or not (KT and KT.RegisterChatCommand) then
        return
    end

    runtime.lfgNoteCommandRegistered = true
    KT:RegisterChatCommand("ktlfgnote", function(msg)
        local noteText = self:SetPersistentLFGNote(msg or "")
        if KT.Print then
            if noteText ~= "" then
                KT:Print("Persistent LFG note saved: " .. noteText)
            else
                KT:Print("Persistent LFG note cleared.")
            end
        end
    end)
end

function Mod:IsInLFGQueue()
    return (GetLFGMode and (
        GetLFGMode(_G.LE_LFG_CATEGORY_LFD) or
        GetLFGMode(_G.LE_LFG_CATEGORY_LFR) or
        GetLFGMode(_G.LE_LFG_CATEGORY_RF) or
        GetLFGMode(_G.LE_LFG_CATEGORY_SCENARIO) or
        GetLFGMode(_G.LE_LFG_CATEGORY_FLEXRAID)
    )) and true or false
end

function Mod:BuildBodyguardNameSet()
    if runtime.bodyguardNames then
        return runtime.bodyguardNames
    end

    runtime.bodyguardNames = {}
    if not (C_GossipInfo and C_GossipInfo.GetFriendshipReputation) then
        return runtime.bodyguardNames
    end

    for _, followerID in ipairs(BODYGUARD_IDS) do
        local info = C_GossipInfo.GetFriendshipReputation(followerID)
        if info and info.name then
            runtime.bodyguardNames[info.name] = true
        end
    end

    return runtime.bodyguardNames
end

function Mod:IsFriendLike(name, guid)
    local db = self:GetDB()
    local normalized = NormalizeName(name)
    if not normalized then
        return false
    end

    if C_FriendList and C_FriendList.ShowFriends then
        C_FriendList.ShowFriends()
    end

    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        for i = 1, C_FriendList.GetNumFriends() do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            local friendName = info and NormalizeName(info.name)
            if friendName and friendName == normalized then
                if not guid or not info.guid or info.guid == guid then
                    return true
                end
            end
        end
    end

    if C_BattleNet and C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendGameAccountInfo then
        for i = 1, BNGetNumFriends() do
            local numAccounts = C_BattleNet.GetFriendNumGameAccounts(i) or 0
            for j = 1, numAccounts do
                local gameAccountInfo = C_BattleNet.GetFriendGameAccountInfo(i, j)
                local characterName = gameAccountInfo and NormalizeName(gameAccountInfo.characterName)
                if gameAccountInfo and gameAccountInfo.clientProgram == "WoW" and characterName == normalized then
                    return true
                end
            end
        end
    end

    if db.groups.guildAsFriends and IsInGuild() and GetGuildRosterInfo then
        for i = 1, (_G.GetNumGuildMembers and _G.GetNumGuildMembers() or 0) do
            local guildName, _, _, _, _, _, _, _, online, _, _, _, _, mobile, _, _, guildGuid = GetGuildRosterInfo(i)
            guildName = NormalizeName(guildName)
            if online and not mobile and guildName == normalized then
                if not guid or not guildGuid or guildGuid == guid then
                    return true
                end
            end
        end
    end

    if db.groups.communitiesAsFriends and C_Club and CommunitiesUtil and CommunitiesUtil.GetMemberIdsSortedByName and CommunitiesUtil.GetMemberInfo then
        local clubs = C_Club.GetSubscribedClubs and C_Club.GetSubscribedClubs() or nil
        if clubs then
            for _, club in pairs(clubs) do
                if club and club.clubType == Enum.ClubType.Character then
                    local memberIDs = CommunitiesUtil.GetMemberIdsSortedByName(club.clubId)
                    local members = CommunitiesUtil.GetMemberInfo(club.clubId, memberIDs)
                    for _, member in pairs(members or {}) do
                        local memberName = member and NormalizeName(member.name)
                        if memberName == normalized then
                            if not guid or not member.guid or member.guid == guid then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end

    return false
end

function Mod:ApplyActionButtonTextVisibility()
    local db = self:GetDB()
    local hideKeybinds = IsModuleEnabled() and db.visibility.hideKeybindText
    local hideMacros = IsModuleEnabled() and db.visibility.hideMacroText

    IterateActionButtons(function(button)
        if button.HotKey then
            button.HotKey:SetAlpha(hideKeybinds and 0 or 1)
        end
        if button.Name then
            button.Name:SetAlpha(hideMacros and 0 or 1)
        end
    end)
end

function Mod:ApplyStanceBarVisibility()
    local db = self:GetDB()
    local hide = IsModuleEnabled() and db.visibility.hideStanceBar
    if _G.StanceBar then
        _G.StanceBar:SetAlpha(hide and 0 or 1)
        SetMouseEnabledSafe(_G.StanceBar, not hide, "pendingStanceBarMouse")
    end
end

function Mod:ApplyCleanupButtonsVisibility()
    local db = self:GetDB()
    local hide = IsModuleEnabled() and db.visibility.hideCleanupButtons

    if _G.BagItemAutoSortButton then
        _G.BagItemAutoSortButton:SetAlpha(hide and 0 or 1)
        if _G.BagItemAutoSortButton.EnableMouse then
            _G.BagItemAutoSortButton:EnableMouse(not hide)
        end
    end

    if _G.BankPanel and _G.BankPanel.AutoSortButton then
        _G.BankPanel.AutoSortButton:SetAlpha(hide and 0 or 1)
        if _G.BankPanel.AutoSortButton.EnableMouse then
            _G.BankPanel.AutoSortButton:EnableMouse(not hide)
        end
    end
end

function Mod:ApplyFontSizes()
    local db = self:GetDB()

    if not runtime.questFontsStored and QuestTitleFont and QuestFont and QuestFontNormalSmall then
        runtime.questTitlePath, runtime.questTitleSize, runtime.questTitleFlags = QuestTitleFont:GetFont()
        runtime.questBodyPath, runtime.questBodySize, runtime.questBodyFlags = QuestFont:GetFont()
        runtime.questSmallPath, runtime.questSmallSize, runtime.questSmallFlags = QuestFontNormalSmall:GetFont()
        runtime.questFontsStored = true
    end

    -- Taint safety: QuestTitleFont, QuestFont, and QuestFontNormalSmall are Blizzard
    -- font objects used by secure quest/widget flows. Mutating them leaks taint into
    -- Blizzard-owned text measurements, which can break UIWidgets on the world map.

    if not runtime.mailFontsStored and QuestFont then
        runtime.mailBodyPath, runtime.mailBodySize, runtime.mailBodyFlags = QuestFont:GetFont()
        runtime.editBoxPath, runtime.editBoxSize, runtime.editBoxFlags = QuestFont:GetFont()
        runtime.mailFontsStored = true
    end

    if runtime.mailFontsStored and _G.OpenMailBodyText and SendMailBodyEditBox then
        local size = (IsModuleEnabled() and db.textSize.resizeMailText) and db.textSize.mailFontSize or runtime.mailBodySize
        OpenMailBodyText:SetFont("h1", runtime.mailBodyPath, size, runtime.mailBodyFlags)
        OpenMailBodyText:SetFont("h2", runtime.mailBodyPath, size, runtime.mailBodyFlags)
        OpenMailBodyText:SetFont("h3", runtime.mailBodyPath, size, runtime.mailBodyFlags)
        OpenMailBodyText:SetFont("p", runtime.mailBodyPath, size, runtime.mailBodyFlags)
        SendMailBodyEditBox:SetFont(runtime.editBoxPath, size, runtime.editBoxFlags)
    end
end

function Mod:ApplyCVars()
    local db = self:GetDB()

    SetCVar("ffxGlow", (IsModuleEnabled() and db.graphicsSound.disableScreenGlow) and "0" or "1")

    if IsModuleEnabled() and db.graphicsSound.disableScreenEffects then
        SetCVar("ffxDeath", "0")
        SetCVar("ffxNether", "0")
        SetCVar("ffxVenari", "0")
        SetCVar("ffxLingeringVenari", "0")
    else
        SetCVar("ffxDeath", "1")
        SetCVar("ffxNether", "1")
        SetCVar("ffxVenari", "1")
        SetCVar("ffxLingeringVenari", "1")
    end

    if IsModuleEnabled() and db.graphicsSound.setWeatherDensity then
        local density = math.max(0, math.min(3, db.graphicsSound.weatherDensity or 0))
        SetCVar("WeatherDensity", density)
        SetCVar("RAIDweatherDensity", density)
    else
        SetCVar("WeatherDensity", "3")
        SetCVar("RAIDweatherDensity", "3")
    end

    SetCVar("cameraDistanceMaxZoomFactor", (IsModuleEnabled() and db.graphicsSound.maxCameraZoom) and 2.6 or 1.9)

    if SetAllowLowLevelRaid then
        SetAllowLowLevelRaid(IsModuleEnabled() and db.gameOptions.removeRaidRestrictions or false)
    end
end

function Mod:ApplyCombatPlates()
    local db = self:GetDB()
    if IsModuleEnabled() and db.gameOptions.combatPlates then
        SetCVar("nameplateShowEnemies", UnitAffectingCombat("player") and 1 or 0)
    end
end

function Mod:CheckAndDeclineSharedQuest()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.blocks.blockSharedQuests) then
        return false
    end

    if UnitExists("questnpc") and UnitIsPlayer("questnpc") and (UnitInParty("questnpc") or UnitInRaid("questnpc")) then
        local npcName = UnitName("questnpc")
        local npcGuid = UnitGUID("questnpc")
        if not self:IsFriendLike(npcName, npcGuid) then
            DeclineQuest()
            return true
        end
    end

    return false
end

function Mod:HandleQuestGreeting()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.automation.autoQuests) then
        return
    end

    for i = 1, (GetNumActiveQuests and GetNumActiveQuests() or 0) do
        local _, isComplete = GetActiveTitle(i)
        if isComplete then
            SelectActiveQuest(i)
            return
        end
    end

    for i = 1, (GetNumAvailableQuests and GetNumAvailableQuests() or 0) do
        local title = GetAvailableTitle(i)
        if title then
            SelectAvailableQuest(i)
            return
        end
    end
end

function Mod:HandleGossip()
    local db = self:GetDB()
    if not IsModuleEnabled() then
        return
    end

    if db.visibility.hideBodyguardGossip and UnitExists("target") and UnitName("target") then
        local bodyguards = self:BuildBodyguardNameSet()
        local targetName = UnitName("target")
        if bodyguards[targetName] and _G.UnitCanCooperate and _G.UnitCanCooperate("target", "player") and C_GossipInfo and C_GossipInfo.CloseGossip then
            C_GossipInfo.CloseGossip()
            return
        end
    end

    if db.automation.autoQuests and C_GossipInfo then
        local activeQuests = C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or nil
        for _, questInfo in ipairs(activeQuests or {}) do
            if questInfo and questInfo.isComplete and questInfo.questID then
                C_GossipInfo.SelectActiveQuest(questInfo.questID)
                return
            end
        end

        local availableQuests = C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or nil
        for _, questInfo in ipairs(availableQuests or {}) do
            if questInfo and questInfo.questID then
                if not _G.DoesQuestHaveRequirementsMet or _G.DoesQuestHaveRequirementsMet(questInfo.questID) then
                    C_GossipInfo.SelectAvailableQuest(questInfo.questID)
                    return
                end
            end
        end
    end

    if db.automation.autoGossip and C_GossipInfo and C_GossipInfo.GetOptions then
        local options = C_GossipInfo.GetOptions()
        local available = C_GossipInfo.GetAvailableQuests and C_GossipInfo.GetAvailableQuests() or {}
        local active = C_GossipInfo.GetActiveQuests and C_GossipInfo.GetActiveQuests() or {}
        if #active == 0 and #available == 0 and options and #options == 1 then
            local option = options[1]
            if option and option.gossipOptionID then
                C_GossipInfo.SelectOption(option.gossipOptionID)
            end
        end
    end
end

function Mod:SellJunk()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.automation.sellJunk) or IsShiftKeyDown() then
        return
    end

    local totalValue = 0
    local soldCount = 0

    for bag = 0, 5 do
        local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
        for slot = 1, slots do
            local itemLink = C_Container.GetContainerItemLink(bag, slot)
            if itemLink then
                local _, _, quality, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemLink)
                if quality == 0 and (sellPrice or 0) > 0 then
                    local info = C_Container.GetContainerItemInfo(bag, slot)
                    local stackCount = info and info.stackCount or 1
                    totalValue = totalValue + (sellPrice * stackCount)
                    soldCount = soldCount + 1
                    C_Container.UseContainerItem(bag, slot)
                end
            end
        end
    end

    if soldCount > 0 and db.automation.vendorShowSummary and KT and KT.Print then
        KT:Print(string.format(LText("|cff00c8ffEnhancements|r: Sold %d junk items for %s."), soldCount, SafeCoinText(totalValue)))
    end
end

function Mod:RepairGear()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.automation.autoRepair) or IsShiftKeyDown() then
        return
    end

    if not CanMerchantRepair or not CanMerchantRepair() then
        return
    end

    local repairCost, canRepair = GetRepairAllCost()
    if not canRepair or not repairCost or repairCost <= 0 then
        return
    end

    if db.automation.repairUseGuildFunds and IsInGuild() and CanGuildBankRepair and CanGuildBankRepair() then
        RepairAllItems(1)
        RepairAllItems()
    else
        RepairAllItems()
    end

    if db.automation.repairShowSummary and KT and KT.Print then
        KT:Print(string.format(LText("|cff00c8ffEnhancements|r: Repaired for %s."), SafeCoinText(repairCost)))
    end
end

function Mod:DeclinePendingFriendInvites()
    if not (IsModuleEnabled() and self:GetDB().blocks.blockFriendRequests) then
        return
    end

    for i = BNGetNumFriendInvites(), 1, -1 do
        local inviteID = BNGetFriendInviteInfo(i)
        if inviteID then
            BNDeclineFriendInvite(inviteID)
        end
    end
end

function Mod:UpdatePersistentLFGNotePatch()
    local db = self:GetDB()
    local noteText = self:GetPersistentLFGNote()
    if not (IsModuleEnabled() and db.groups.persistentLFGNoteEnabled and noteText ~= "") then
        if runtime.lfgNoteDialogPatched and runtime.originalLFGListApplicationDialog_Show ~= nil then
            _G.LFGListApplicationDialog_Show = runtime.originalLFGListApplicationDialog_Show
        end
        runtime.lfgNoteDialogPatched = false
        return
    end

    if runtime.lfgNoteDialogPatched then
        return
    end

    if not (_G.LFGListApplicationDialog_Show and C_LFGList and C_LFGList.GetSearchResultInfo) then
        return
    end

    runtime.originalLFGListApplicationDialog_Show = runtime.originalLFGListApplicationDialog_Show or _G.LFGListApplicationDialog_Show
    runtime.patchedLFGListApplicationDialog_Show = function(dialog, resultID)
        if resultID then
            local searchResultInfo = C_LFGList.GetSearchResultInfo(resultID)
            dialog.resultID = resultID
            if searchResultInfo then
                dialog.activityID = searchResultInfo.activityID or (searchResultInfo.activityIDs and searchResultInfo.activityIDs[1])
            end
        end

        if _G.LFGListApplicationDialog_UpdateRoles then
            _G.LFGListApplicationDialog_UpdateRoles(dialog)
        end
        if _G.StaticPopupSpecial_Show then
            _G.StaticPopupSpecial_Show(dialog)
        elseif dialog.Show then
            dialog:Show()
        end

        if Mod and Mod.ApplyPersistentLFGNoteNow then
            Mod:ApplyPersistentLFGNoteNow()
        end
    end

    _G.LFGListApplicationDialog_Show = runtime.patchedLFGListApplicationDialog_Show
    runtime.lfgNoteDialogPatched = true
end

function Mod:ApplyPersistentLFGNote()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.groups.persistentLFGNoteEnabled) then
        return
    end

    local noteText = self:GetPersistentLFGNote()
    if noteText == "" then
        return
    end

    local dialog = _G.LFGListApplicationDialog
    if not (dialog and dialog.IsShown and dialog:IsShown()) then
        return
    end

    local editBoxes = FindLFGApplicationNoteEditBoxes(dialog)
    if #editBoxes == 0 then
        return
    end

    runtime.lfgNoteEditBox = editBoxes[1]
    TrackPersistentLFGNoteEditBox(runtime.lfgNoteEditBox)

    runtime.applyingPersistentLFGNote = true
    for _, editBox in ipairs(editBoxes) do
        TrackPersistentLFGNoteEditBox(editBox)
        pcall(function()
            if editBox.SetFocus then
                editBox:SetFocus()
            end
            if editBox.SetText then
                editBox:SetText(noteText)
            end
            if editBox.Insert then
                local currentText = editBox.GetText and editBox:GetText() or nil
                if currentText ~= noteText then
                    if editBox.SetText then
                        editBox:SetText("")
                    end
                    editBox:Insert(noteText)
                end
            end
            if editBox.HighlightText then
                editBox:HighlightText(0, 0)
            end
            if editBox.ClearFocus then
                editBox:ClearFocus()
            end
        end)
    end
    runtime.applyingPersistentLFGNote = false
end

function Mod:ApplyPersistentLFGNoteNow()
    if self.ApplyPersistentLFGNote then
        self:ApplyPersistentLFGNote()
    end
    if self.SchedulePersistentLFGNotePopulate then
        self:SchedulePersistentLFGNotePopulate()
    end
end

function Mod:EnsureLFGNoteHooks()
    self:UpdatePersistentLFGNotePatch()

    local dialog = _G.LFGListApplicationDialog
    if dialog and not runtime.lfgNoteHooksInstalled and dialog.HookScript then
        runtime.lfgNoteHooksInstalled = true
        dialog:HookScript("OnShow", function()
            runtime.lfgNoteEditBox = nil
            if Mod and Mod.SchedulePersistentLFGNotePopulate then
                Mod:SchedulePersistentLFGNotePopulate()
            end
        end)
    end

    local descriptionEditBox = _G.LFGListApplicationDialogDescription and _G.LFGListApplicationDialogDescription.EditBox
    if descriptionEditBox and descriptionEditBox.HookScript and not runtime.lfgNoteDescriptionEditBoxHookInstalled then
        runtime.lfgNoteDescriptionEditBoxHookInstalled = true
        TrackPersistentLFGNoteEditBox(descriptionEditBox)
        descriptionEditBox:HookScript("OnShow", function()
            if Mod and Mod.ApplyPersistentLFGNoteNow then
                Mod:ApplyPersistentLFGNoteNow()
            end
        end)
    end

    local dialogSignupButton = dialog and dialog.SignUpButton
    if dialogSignupButton and dialogSignupButton.HookScript and not dialogSignupButton._KTEnhancementsLFGNotePreClickHook then
        dialogSignupButton._KTEnhancementsLFGNotePreClickHook = true
        dialogSignupButton:HookScript("PreClick", function()
            if Mod and Mod.ApplyPersistentLFGNoteNow then
                Mod:ApplyPersistentLFGNoteNow()
            end
        end)
        dialogSignupButton:HookScript("OnMouseDown", function()
            if Mod and Mod.ApplyPersistentLFGNote then
                Mod:ApplyPersistentLFGNote()
            end
        end)
    end

    local signupButton = _G.LFGListFrame and _G.LFGListFrame.SearchPanel and _G.LFGListFrame.SearchPanel.SignUpButton
    if signupButton and signupButton.HookScript and not signupButton._KTEnhancementsLFGNoteHook then
        signupButton._KTEnhancementsLFGNoteHook = true
        signupButton:HookScript("OnClick", function()
            if Mod and Mod.SchedulePersistentLFGNotePopulate then
                Mod:SchedulePersistentLFGNotePopulate()
            end
        end)
    end

    if not runtime.lfgNoteClearHookInstalled and C_LFGList and C_LFGList.ClearApplicationTextFields and hooksecurefunc then
        runtime.lfgNoteClearHookInstalled = true
        hooksecurefunc(C_LFGList, "ClearApplicationTextFields", function()
            if Mod and Mod.ApplyPersistentLFGNoteNow then
                Mod:ApplyPersistentLFGNoteNow()
            end
        end)
    end

    if not runtime.lfgNoteShowHookInstalled and _G.LFGListApplicationDialog_Show and hooksecurefunc then
        runtime.lfgNoteShowHookInstalled = true
        hooksecurefunc("LFGListApplicationDialog_Show", function()
            runtime.lfgNoteEditBox = nil
            if Mod and Mod.SchedulePersistentLFGNotePopulate then
                Mod:SchedulePersistentLFGNotePopulate()
            end
        end)
    end
end

function Mod:InstallErrorHook()
    if runtime.errorsHookInstalled or not _G.UIErrorsFrame then
        return
    end

    runtime.originalUIErrorsOnEvent = _G.UIErrorsFrame:GetScript("OnEvent")
    _G.UIErrorsFrame:SetScript("OnEvent", function(frame, event, ...)
        if event == "UI_ERROR_MESSAGE" then
            local db = Mod:GetDB()
            if IsModuleEnabled() and db.visibility.hideErrorMessages then
                return
            end
        end
        if runtime.originalUIErrorsOnEvent then
            return runtime.originalUIErrorsOnEvent(frame, event, ...)
        end
    end)

    runtime.errorsHookInstalled = true
end

function Mod:EnsureTalkingHeadHook()
    local frame = _G.TalkingHeadFrame
    if not frame then
        return false
    end

    -- Blizzard_TalkingHeadUI is load-on-demand. InstallHooks may have already
    -- completed before this frame exists, so track this hook independently
    -- from the rest of the one-time hook bundle.
    if runtime.talkingHeadHookFrame ~= frame then
        frame:HookScript("OnShow", function(shownFrame)
            local db = Mod:GetDB()
            if IsModuleEnabled() and db.visibility.hideTalkingFrame then
                shownFrame:Hide()
            end
        end)
        runtime.talkingHeadHookFrame = frame
    end

    local db = self:GetDB()
    if IsModuleEnabled() and db.visibility.hideTalkingFrame and frame:IsShown() then
        frame:Hide()
    end
    return true
end

function Mod:InstallHooks()
    -- Unlike the static frames below, TalkingHeadFrame can appear after this
    -- function's first pass. Always retry it before the one-time early return.
    self:EnsureTalkingHeadHook()
    if runtime.hooksInstalled then
        self:EnsureLFGNoteHooks()
        return
    end

    self:InstallErrorHook()
    self:EnsureLFGNoteHooks()

    if _G.ZoneTextFrame and not _G.ZoneTextFrame._KTEnhancementsZoneHook then
        _G.ZoneTextFrame._KTEnhancementsZoneHook = true
        _G.ZoneTextFrame:HookScript("OnShow", function(frame)
            local db = Mod:GetDB()
            if IsModuleEnabled() and db.visibility.hideZoneText then
                frame:Hide()
            end
        end)
    end

    if _G.SubZoneTextFrame and not _G.SubZoneTextFrame._KTEnhancementsZoneHook then
        _G.SubZoneTextFrame._KTEnhancementsZoneHook = true
        _G.SubZoneTextFrame:HookScript("OnShow", function(frame)
            local db = Mod:GetDB()
            if IsModuleEnabled() and db.visibility.hideZoneText then
                frame:Hide()
            end
        end)
    end

    if _G.AlertFrame and not _G.AlertFrame._KTEnhancementsHook then
        _G.AlertFrame._KTEnhancementsHook = true
        _G.AlertFrame:HookScript("OnShow", function(frame)
            local db = Mod:GetDB()
            if IsModuleEnabled() and db.visibility.hideAlerts then
                frame:Hide()
            end
        end)
    end

    if _G.BossBanner and not _G.BossBanner._KTEnhancementsHook then
        _G.BossBanner._KTEnhancementsHook = true
        _G.BossBanner:HookScript("OnShow", function(frame)
            local db = Mod:GetDB()
            if IsModuleEnabled() and db.visibility.hideBossBanner then
                frame:Hide()
            end
        end)
    end

    if _G.EventToastManagerFrame and not _G.EventToastManagerFrame._KTEnhancementsHook then
        _G.EventToastManagerFrame._KTEnhancementsHook = true
        _G.EventToastManagerFrame:HookScript("OnShow", function(frame)
            local db = Mod:GetDB()
            if IsModuleEnabled() and db.visibility.hideEventToasts then
                frame:Hide()
            end
        end)
    end

    if _G.LFDRoleCheckPopupAcceptButton and not _G.LFDRoleCheckPopupAcceptButton._KTEnhancementsHook then
        _G.LFDRoleCheckPopupAcceptButton._KTEnhancementsHook = true
        _G.LFDRoleCheckPopupAcceptButton:HookScript("OnShow", function(button)
            local db = Mod:GetDB()
            if not (IsModuleEnabled() and db.groups.queueFromFriends) then
                return
            end

            local leaderName, leaderGuid
            for i = 1, GetNumSubgroupMembers() do
                local unit = "party" .. i
                if UnitIsGroupLeader(unit) then
                    leaderName = UnitName(unit)
                    leaderGuid = UnitGUID(unit)
                    break
                end
            end

            if leaderName and Mod:IsFriendLike(leaderName, leaderGuid) then
                button:Click()
            end
        end)
    end

    if QuestSessionManager and QuestSessionManager.StartDialog and not QuestSessionManager.StartDialog._KTEnhancementsHook then
        QuestSessionManager.StartDialog._KTEnhancementsHook = true
        hooksecurefunc(QuestSessionManager.StartDialog, "Show", function(dialog)
            local db = Mod:GetDB()
            if not (IsModuleEnabled() and db.groups.syncFromFriends) then
                return
            end

            local details = C_QuestSession and C_QuestSession.GetSessionBeginDetails and C_QuestSession.GetSessionBeginDetails()
            if not details then
                return
            end

            for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
                if UnitGUID(unit) == details.guid then
                    local requesterName = UnitName(unit)
                    if requesterName and Mod:IsFriendLike(requesterName, details.guid) and dialog.ButtonContainer and dialog.ButtonContainer.Confirm then
                        dialog.ButtonContainer.Confirm:Click()
                    end
                    break
                end
            end
        end)
    end

    if not Mod._KTEnhancementsReleaseHook then
        Mod._KTEnhancementsReleaseHook = true
        hooksecurefunc("StaticPopup_Show", function(which)
            local db = Mod:GetDB()
            if not (IsModuleEnabled() and db.automation.releaseInPvP) then
                return
            end
            if which ~= "DEATH" then
                return
            end
            if _G.C_DeathInfo and _G.C_DeathInfo.GetSelfResurrectOptions then
                local options = _G.C_DeathInfo.GetSelfResurrectOptions()
                if options and #options > 0 then
                    return
                end
            end
            local inInstance, instanceType = IsInInstance()
            if not inInstance or (instanceType ~= "pvp" and instanceType ~= "arena") then
                return
            end
            C_Timer.After(0.25, function()
                local dialog = StaticPopup_Visible("DEATH")
                if dialog and not IsShiftKeyDown() then
                    StaticPopup_OnClick(_G[dialog], 1)
                end
            end)
        end)
    end

    if _G.CinematicFrame and not _G.CinematicFrame._KTEnhancementsHook then
        _G.CinematicFrame._KTEnhancementsHook = true
        _G.CinematicFrame:HookScript("OnKeyDown", function(_, key)
            local db = Mod:GetDB()
            if not (IsModuleEnabled() and db.gameOptions.fasterMovieSkip) then
                return
            end
            if key == "ESCAPE" and _G.CinematicFrame:IsShown() and _G.CinematicFrameCloseDialog then
                _G.CinematicFrameCloseDialog:Hide()
            end
        end)
        _G.CinematicFrame:HookScript("OnKeyUp", function(_, key)
            local db = Mod:GetDB()
            if not (IsModuleEnabled() and db.gameOptions.fasterMovieSkip) then
                return
            end
            if (key == "SPACE" or key == "ESCAPE" or key == "ENTER") and _G.CinematicFrame:IsShown() and _G.CinematicFrameCloseDialogConfirmButton then
                _G.CinematicFrameCloseDialogConfirmButton:Click()
            end
        end)
    end

    if _G.MovieFrame and not _G.MovieFrame._KTEnhancementsHook then
        _G.MovieFrame._KTEnhancementsHook = true
        _G.MovieFrame:HookScript("OnKeyUp", function(_, key)
            local db = Mod:GetDB()
            if not (IsModuleEnabled() and db.gameOptions.fasterMovieSkip) then
                return
            end
            if (key == "SPACE" or key == "ESCAPE" or key == "ENTER") and _G.MovieFrame:IsShown() and _G.MovieFrame.CloseDialog and _G.MovieFrame.CloseDialog.ConfirmButton then
                _G.MovieFrame.CloseDialog.ConfirmButton:Click()
            end
        end)
    end

    runtime.hooksInstalled = true
end

function Mod:RefreshSettings()
    if self.RegisterMythicPlusTrackerMover then
        self:RegisterMythicPlusTrackerMover()
        self:GetMythicPlusTrackerFrame()
        self:RefreshMythicPlusTracker()
    end
    if self.RegisterCombatTimerMover then
        self:RegisterCombatTimerMover()
        self:RefreshCombatTimer()
    end
    self:RegisterCombatTextMover()
    self:GetCombatTextFrame()
    self:RefreshCombatTextStyle()
    self:ApplyCombatTextPosition()
    local combatTextConfig = GetCombatTextDB()
    if not (IsModuleEnabled() and combatTextConfig.enabled == true) then
        self:HideCombatText()
    end
    if self.RefreshDamageMeter then
        self:RefreshDamageMeter()
    end
    self:EnsureLFGNoteHooks()
    self:ApplyActionButtonTextVisibility()
    self:ApplyStanceBarVisibility()
    self:ApplyCleanupButtonsVisibility()
    self:ApplyFontSizes()
    self:ApplyCVars()
    self:ApplyCombatPlates()
    self:EnsureTalkingHeadHook()
    if self.EnhancedFriendList and self.EnhancedFriendList.Refresh then
        self.EnhancedFriendList:Refresh()
    end

    local db = self:GetDB()
    if IsModuleEnabled() and db.blocks.blockFriendRequests then
        self:DeclinePendingFriendInvites()
    end
    if _G.AlertFrame and IsModuleEnabled() and db.visibility.hideAlerts then
        _G.AlertFrame:Hide()
    end
    if _G.BossBanner and IsModuleEnabled() and db.visibility.hideBossBanner then
        _G.BossBanner:Hide()
    end
    if _G.EventToastManagerFrame and IsModuleEnabled() and db.visibility.hideEventToasts then
        _G.EventToastManagerFrame:Hide()
    end
    self:UpdatePersistentLFGNotePatch()
    self:ApplyPersistentLFGNote()
end

function Mod:OnInitialize()
    self:GetDB()
end

function Mod:OnEnable()
    self:RegisterPersistentLFGNoteCommand()
    self:InstallHooks()
    self:RefreshSettings()
    if self.InitializeMythicPlusTracker then self:InitializeMythicPlusTracker() end
    if self.InitializeMythicPlusHistory then self:InitializeMythicPlusHistory() end
    if self._ktCombatTimerInit then self:_ktCombatTimerInit() end

    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LOGOUT")
    self:RegisterEvent("DAMAGE_METER_COMBAT_SESSION_UPDATED")
    self:RegisterEvent("DAMAGE_METER_CURRENT_SESSION_UPDATED")
    self:RegisterEvent("DAMAGE_METER_RESET")
    self:RegisterEvent("UPDATE_BINDINGS")
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("CONFIRM_SUMMON")
    self:RegisterEvent("RESURRECT_REQUEST")
    self:RegisterEvent("PARTY_INVITE_REQUEST")
    self:RegisterEvent("GROUP_INVITE_CONFIRMATION")
    self:RegisterEvent("BN_FRIEND_INVITE_ADDED")
    self:RegisterEvent("DUEL_REQUESTED")
    self:RegisterEvent("PET_BATTLE_PVP_DUEL_REQUESTED")
    self:RegisterEvent("QUEST_DETAIL")
    self:RegisterEvent("QUEST_ACCEPT_CONFIRM")
    self:RegisterEvent("QUEST_PROGRESS")
    self:RegisterEvent("QUEST_COMPLETE")
    self:RegisterEvent("QUEST_GREETING")
    self:RegisterEvent("QUEST_AUTOCOMPLETE")
    self:RegisterEvent("GOSSIP_SHOW")
    self:RegisterEvent("MERCHANT_SHOW")
    self:RegisterEvent("LOOT_READY")
    self:RegisterEvent("CONFIRM_LOOT_ROLL")
    self:RegisterEvent("CONFIRM_DISENCHANT_ROLL")
    self:RegisterEvent("LOOT_BIND_CONFIRM")
    self:RegisterEvent("MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL")
    self:RegisterEvent("MAIL_LOCK_SEND_ITEMS")
    self:RegisterEvent("CHAT_MSG_WHISPER")
    self:RegisterEvent("CHAT_MSG_BN_WHISPER")
    self:RegisterEvent("VOICE_CHAT_OUTPUT_DEVICES_UPDATED")

    C_Timer.After(0, function()
        if Mod and Mod.RefreshSettings then
            Mod:RefreshSettings()
        end
    end)
    C_Timer.After(1, function()
        if Mod and Mod.RefreshSettings then
            Mod:RefreshSettings()
        end
    end)
end

function Mod:ADDON_LOADED(event, addonName)
    self:InstallHooks()
    if addonName == "Blizzard_DamageMeter" and self.RefreshDamageMeter then
        -- Refresh after the native API has become available.
        self:RefreshDamageMeter()
    end
    if addonName == "Blizzard_GroupFinder" then
        runtime.lfgNoteHooksInstalled = false
        runtime.lfgNoteDescriptionEditBoxHookInstalled = false
        runtime.lfgNoteEditBox = nil
        self:EnsureLFGNoteHooks()
        self:ApplyPersistentLFGNote()
    end
    self:ApplyFontSizes()
    if self.EnhancedFriendList and self.EnhancedFriendList.OnAddonLoaded then
        self.EnhancedFriendList:OnAddonLoaded(addonName)
    end
end

function Mod:PLAYER_ENTERING_WORLD()
    if GuildRoster then
        GuildRoster()
    end
    self:RefreshSettings()
    if self.ScheduleDamageMeterHistoryCapture then
        -- Native sessions are repopulated shortly after the loading screen.
        -- Capture after that hand-off and retain the SavedVariables fallback.
        self:ScheduleDamageMeterHistoryCapture(1)
    end
end

function Mod:UPDATE_BINDINGS()
    self:ApplyActionButtonTextVisibility()
end

function Mod:ACTIONBAR_SLOT_CHANGED()
    self:ApplyActionButtonTextVisibility()
end

function Mod:PLAYER_REGEN_DISABLED()
    self:ShowCombatText("enter")
    if IsModuleEnabled() and self:GetDB().gameOptions.combatPlates then
        SetCVar("nameplateShowEnemies", 1)
    end
    if self.StartDamageMeterLiveRefresh then
        if self.PrepareDamageMeterCombatStart then
            self:PrepareDamageMeterCombatStart()
        end
        self:StartDamageMeterLiveRefresh()
    end
end

function Mod:PLAYER_REGEN_ENABLED()
    self:ShowCombatText("leave")
    if IsModuleEnabled() and self:GetDB().gameOptions.combatPlates then
        SetCVar("nameplateShowEnemies", 0)
    end
    if runtime.pendingStanceBarMouse ~= nil then
        self:ApplyStanceBarVisibility()
    end
    if self.StopDamageMeterLiveRefresh then
        self:StopDamageMeterLiveRefresh(true)
    end
end

function Mod:CONFIRM_SUMMON()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.automation.acceptSummon) then
        return
    end
    if UnitAffectingCombat("player") then
        return
    end

    local summoner = C_SummonInfo and C_SummonInfo.GetSummonConfirmSummoner and C_SummonInfo.GetSummonConfirmSummoner()
    local location = C_SummonInfo and C_SummonInfo.GetSummonConfirmAreaName and C_SummonInfo.GetSummonConfirmAreaName()
    C_Timer.After(1, function()
        local newSummoner = C_SummonInfo and C_SummonInfo.GetSummonConfirmSummoner and C_SummonInfo.GetSummonConfirmSummoner()
        local newLocation = C_SummonInfo and C_SummonInfo.GetSummonConfirmAreaName and C_SummonInfo.GetSummonConfirmAreaName()
        if summoner and location and summoner == newSummoner and location == newLocation and C_SummonInfo and C_SummonInfo.ConfirmSummon then
            C_SummonInfo.ConfirmSummon()
            StaticPopup_Hide("CONFIRM_SUMMON")
        end
    end)
end

function Mod:RESURRECT_REQUEST(event, requesterName)
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.automation.acceptResurrection) then
        return
    end
    if requesterName and RESURRECT_EXCLUDE_NAMES[requesterName] then
        return
    end
    if requesterName and UnitIsDead(requesterName) then
        return
    end
    AcceptResurrect()
    StaticPopup_Hide("RESURRECT_NO_TIMER")
end

function Mod:PARTY_INVITE_REQUEST(event, inviterName, _, _, _, _, inviterGuid)
    local db = self:GetDB()
    if not IsModuleEnabled() then
        return
    end

    local isFriendLike = inviterName and self:IsFriendLike(inviterName, inviterGuid)
    if db.groups.partyFromFriends and isFriendLike and not self:IsInLFGQueue() then
        AcceptGroup()
        StaticPopup_Hide("PARTY_INVITE")
        StaticPopup_Hide("PARTY_INVITE_XREALM")
        return
    end

    if db.blocks.blockPartyInvites and not isFriendLike then
        DeclineGroup()
        StaticPopup_Hide("PARTY_INVITE")
        StaticPopup_Hide("PARTY_INVITE_XREALM")
    end
end

function Mod:GROUP_INVITE_CONFIRMATION()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.blocks.blockRequestedInvites) then
        return
    end

    local popup = StaticPopup_FindVisible("GROUP_INVITE_CONFIRMATION")
    if not popup or not popup.data then
        return
    end

    local _, name, guid = GetInviteConfirmationInfo(popup.data)
    if self:IsFriendLike(name, guid) then
        return
    end
    RespondToInviteConfirmation(popup.data, false)
    StaticPopup_Hide("GROUP_INVITE_CONFIRMATION")
end

function Mod:BN_FRIEND_INVITE_ADDED()
    self:DeclinePendingFriendInvites()
end

function Mod:DUEL_REQUESTED(event, requesterName)
    local db = self:GetDB()
    if IsModuleEnabled() and db.blocks.blockDuels and not self:IsFriendLike(requesterName) then
        CancelDuel()
        StaticPopup_Hide("DUEL_REQUESTED")
    end
end

function Mod:PET_BATTLE_PVP_DUEL_REQUESTED(event, requesterName)
    local db = self:GetDB()
    if IsModuleEnabled() and db.blocks.blockPetBattleDuels and not self:IsFriendLike(requesterName) and _G.C_PetBattles and _G.C_PetBattles.CancelPVPDuel then
        _G.C_PetBattles.CancelPVPDuel()
    end
end

function Mod:QUEST_DETAIL()
    if self:CheckAndDeclineSharedQuest() then
        return
    end
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.automation.autoQuests) then
        return
    end
    if QuestGetAutoAccept and QuestGetAutoAccept() then
        CloseQuest()
    else
        AcceptQuest()
    end
end

function Mod:QUEST_ACCEPT_CONFIRM()
    if IsModuleEnabled() and self:GetDB().automation.autoQuests then
        ConfirmAcceptQuest()
        StaticPopup_Hide("QUEST_ACCEPT")
    end
end

function Mod:QUEST_PROGRESS()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.automation.autoQuests and IsQuestCompletable()) then
        return
    end
    if QuestRequiresCurrency and QuestRequiresCurrency() then
        return
    end
    if QuestRequiresGold and QuestRequiresGold() then
        return
    end
    CompleteQuest()
end

function Mod:QUEST_COMPLETE()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.automation.autoQuests) then
        return
    end
    if QuestRequiresCurrency and QuestRequiresCurrency() then
        return
    end
    if QuestRequiresGold and QuestRequiresGold() then
        return
    end
    if GetNumQuestChoices() <= 1 then
        GetQuestReward(GetNumQuestChoices())
    end
end

function Mod:QUEST_GREETING()
    self:HandleQuestGreeting()
end

function Mod:QUEST_AUTOCOMPLETE(event, questID)
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.automation.autoQuests and questID and C_QuestLog) then
        return
    end
    local index = C_QuestLog.GetLogIndexForQuestID and C_QuestLog.GetLogIndexForQuestID(questID)
    local info = index and C_QuestLog.GetInfo and C_QuestLog.GetInfo(index)
    if info and info.isAutoComplete and C_QuestLog.SetSelectedQuest and C_QuestLog.GetSelectedQuest then
        C_QuestLog.SetSelectedQuest(questID)
        ShowQuestComplete(C_QuestLog.GetSelectedQuest())
    end
end

function Mod:GOSSIP_SHOW()
    self:HandleGossip()
end

function Mod:MERCHANT_SHOW()
    self:SellJunk()
    self:RepairGear()
end

function Mod:LOOT_READY()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.gameOptions.fasterAutoLoot) then
        return
    end
    local delay = db.gameOptions.autoLootDelay or 0.1
    if GetTime() - runtime.lastLootAt < delay then
        return
    end
    if _G.GetCVarBool and (_G.GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE")) then
        for i = GetNumLootItems(), 1, -1 do
            LootSlot(i)
        end
        runtime.lastLootAt = GetTime()
    end
end

function Mod:CONFIRM_LOOT_ROLL(event, rollID, rollType)
    if IsModuleEnabled() and self:GetDB().gameOptions.disableLootWarnings then
        ConfirmLootRoll(rollID, rollType)
        StaticPopup_Hide("CONFIRM_LOOT_ROLL")
    end
end

function Mod:CONFIRM_DISENCHANT_ROLL(event, rollID, rollType)
    if IsModuleEnabled() and self:GetDB().gameOptions.disableLootWarnings then
        ConfirmLootRoll(rollID, rollType)
        StaticPopup_Hide("CONFIRM_LOOT_ROLL")
    end
end

function Mod:LOOT_BIND_CONFIRM(event, slot, ...)
    if IsModuleEnabled() and self:GetDB().gameOptions.disableLootWarnings then
        ConfirmLootSlot(slot, ...)
        StaticPopup_Hide("LOOT_BIND")
    end
end

function Mod:MERCHANT_CONFIRM_TRADE_TIMER_REMOVAL()
    if IsModuleEnabled() and self:GetDB().gameOptions.disableLootWarnings then
        SellCursorItem()
    end
end

function Mod:MAIL_LOCK_SEND_ITEMS(event, index)
    if IsModuleEnabled() and self:GetDB().gameOptions.disableLootWarnings then
        RespondMailLockSendItem(index, true)
    end
end

function Mod:CHAT_MSG_WHISPER(event, message, author, ...)
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.groups.inviteFromWhispers) then
        return
    end
    if self:IsInLFGQueue() then
        return
    end
    if UnitExists("party1") and not UnitIsGroupLeader("player") and not UnitIsGroupAssistant("player") then
        return
    end
    local keyword = strlower(strtrim(db.groups.whisperKeyword or "inv"))
    if strlower(strtrim(message or "")) ~= keyword then
        return
    end
    local guid = select(11, ...)
    if db.groups.whisperFriendsOnly and not self:IsFriendLike(author, guid) then
        return
    end

    local shortName, realm = strsplit("-", author or "", 2)
    if realm then
        local _, playerRealm = _G.UnitFullName("player")
        if playerRealm and realm == playerRealm then
            author = shortName
        end
    end
    if _G.C_PartyInfo and _G.C_PartyInfo.InviteUnit then
        _G.C_PartyInfo.InviteUnit(author)
    end
end

function Mod:CHAT_MSG_BN_WHISPER(event, message, author, ...)
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.groups.inviteFromWhispers and db.groups.whisperFriendsOnly) then
        return
    end
    if self:IsInLFGQueue() then
        return
    end
    if strlower(strtrim(message or "")) ~= strlower(strtrim(db.groups.whisperKeyword or "inv")) then
        return
    end
    local presenceID = select(11, ...)
    if not presenceID then
        return
    end

    local index = _G.BNGetFriendIndex and _G.BNGetFriendIndex(presenceID)
    if index and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        local accountInfo = C_BattleNet.GetFriendAccountInfo(index)
        local gameAccountInfo = accountInfo and accountInfo.gameAccountInfo
        local gameAccountID = gameAccountInfo and gameAccountInfo.gameAccountID
        if gameAccountID then
            BNInviteFriend(gameAccountID)
        end
    end
end

function Mod:VOICE_CHAT_OUTPUT_DEVICES_UPDATED()
    local db = self:GetDB()
    if not (IsModuleEnabled() and db.graphicsSound.keepAudioSynced) then
        return
    end
    SetCVar("Sound_OutputDriverIndex", "0")
    if Sound_GameSystem_RestartSoundSystem and not (_G.CinematicFrame and _G.CinematicFrame:IsShown()) and not (_G.MovieFrame and _G.MovieFrame:IsShown()) then
        Sound_GameSystem_RestartSoundSystem()
    end
end
