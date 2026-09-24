-- Core.lua
-- Inicialización del addon (OnInitialize), eventos y comandos /kt.
local addonName, ns = ...
local KT = ns.KT
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end

local C_AddOns = _G.C_AddOns
local C_BattleNet = _G.C_BattleNet
local C_Timer = _G.C_Timer
local InCombatLockdown = _G.InCombatLockdown
local IsAddOnLoaded = _G.IsAddOnLoaded
local LoadAddOn = _G.LoadAddOn
local GetAddOnMetadata = _G.GetAddOnMetadata
local strfind = _G.strfind
local strtrim = _G.strtrim
local strupper = _G.strupper

function KT.IsSecret(val)
    if C_UI and C_UI.IsSecret then return C_UI.IsSecret(val) end
    return issecretvalue and issecretvalue(val)
end

KT._unitClassByGUID = KT._unitClassByGUID or {}
KT._unitClassByName = KT._unitClassByName or {}

local function CacheUnitClass(unit, className, classFile, classID)
    if KT.IsSecret(classFile) or not classFile then return end
    local record = { className, classFile, classID }
    local guid = UnitGUID(unit)
    if not KT.IsSecret(guid) and guid then KT._unitClassByGUID[guid] = record end
    -- Identity APIs can throw inside Blizzard code before returning a secret
    -- value. Class resolution therefore never depends on a unit name in 12.1.
end

local function ArenaOpponentClass(index)
    index = tonumber(index)
    if not index or not GetArenaOpponentSpec then return end
    local specID = GetArenaOpponentSpec(index)
    if KT.IsSecret(specID) or not specID or specID <= 0 then return end
    local _, _, _, _, _, classFile, className = GetSpecializationInfoByID(specID)
    if not KT.IsSecret(classFile) and classFile then return className, classFile, nil end
end

function KT.SafeUnitClass(unit)
    local className, classFile, classID = UnitClass(unit)
    if not KT.IsSecret(classFile) and classFile then
        CacheUnitClass(unit, className, classFile, classID)
        return className, classFile, classID
    end

    local arenaIndex = type(unit) == "string" and unit:match("^arena(%d+)$")
    if arenaIndex then
        local aName, aFile, aID = ArenaOpponentClass(arenaIndex)
        if aFile then
            -- The arena specialization API is public during preparation even
            -- when UnitClass is secret. Cache its result so recycled
            -- nameplateN tokens can resolve the same opponent by GUID/name.
            CacheUnitClass(unit, aName, aFile, aID)
            return aName, aFile, aID
        end
    end

    -- If secret (e.g. enemy in PvP), try to map via GUID to arena specs
    local guid = UnitGUID(unit)
    if not KT.IsSecret(guid) and guid then
        local cached = KT._unitClassByGUID[guid]
        if cached then return cached[1], cached[2], cached[3] end

        -- GUID lookup avoids comparing the unit's secret name and remains
        -- useful for battleground nameplates when UnitClass is hidden.
        if GetPlayerInfoByGUID then
            local ok, localizedClass, englishClass = pcall(GetPlayerInfoByGUID, guid)
            if ok and not KT.IsSecret(englishClass) and englishClass then
                CacheUnitClass(unit, localizedClass, englishClass, nil)
                return localizedClass, englishClass, nil
            end
        end
        if GetArenaOpponentSpec then
            for i = 1, 5 do
                local arenaGUID = UnitGUID("arena" .. i)
                if not KT.IsSecret(arenaGUID) and arenaGUID and arenaGUID == guid then
                    local aName, aFile, aID = ArenaOpponentClass(i)
                    if aFile then return aName, aFile, aID end
                end
            end
        end
    end

    return nil, nil, nil
end



KT.UnlockElements = KT.UnlockElements or {}
KT.MovableElements = KT.UnlockElements

function KT.RegisterUnlockElement(key, elementDef)
    if type(key) ~= "string" or type(elementDef) ~= "table" then
        return
    end

    elementDef.key = key
    KT.UnlockElements[key] = elementDef
    KT.MovableElements = KT.UnlockElements

    if KT.GetModule then
        local unlockMode = KT:GetModule("UnlockMode", true)
        if unlockMode and unlockMode.UpdateRegistry then
            unlockMode:UpdateRegistry()
        end
    end
end

function KT:RegisterMovableElements(elements)
    if type(elements) ~= "table" then
        return
    end

    for _, element in ipairs(elements) do
        if element and element.key then
            if not element.group then
                local keyText = tostring(element.key)
                if keyText:find("^CDM_") then
                    element.group = "Cooldown Manager"
                elseif keyText:find("^PROGBAR_TBB_") then
                    element.group = "Aura Reminders"
                elseif keyText:find("^PROGBAR_") then
                    element.group = "Progress Bars"
                else
                    element.group = "Other"
                end
            end

            KT.RegisterUnlockElement(element.key, element)
        end
    end
end

local function CurrentFontPath()
    if KT and KT.ResolveFontPath then
        return KT:ResolveFontPath()
    end

    return KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
end

local function EnsureRegionWidth(region, fallback)
    if not region or not region.GetWidth or not region.SetWidth then
        return
    end

    local ok, width = pcall(region.GetWidth, region)
    if not ok or type(width) ~= "number" or width <= 0 then
        pcall(region.SetWidth, region, fallback)
    end
end

local function KT_GetEditBoxAttribute(editBox, key, fallback)
    if not editBox or type(key) ~= "string" or key == "" then
        return fallback
    end

    if editBox.GetAttribute then
        local ok, value = pcall(editBox.GetAttribute, editBox, key)
        if ok and value ~= nil then
            return value
        end
    end

    local directValue = editBox[key]
    if directValue ~= nil then
        return directValue
    end

    return fallback
end

local function KT_GetLastTellTarget()
    local getter = _G.ChatEdit_GetLastTellTarget
        or (_G.ChatFrameUtil and _G.ChatFrameUtil.GetLastTellTarget)
    if not getter then
        return nil
    end

    local ok, target = pcall(getter)
    if not ok or type(target) ~= "string" or strtrim(target) == "" then
        return nil
    end

    return target
end

local function KT_GetNonEmptyString(value)
    if type(value) ~= "string" then
        return nil
    end

    value = strtrim(value)
    return value ~= "" and value or nil
end

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
    if KT_IsSecureChatSafeMode() then
        return false
    end

    if _G.ChatEdit_UpdateHeader then
        return pcall(_G.ChatEdit_UpdateHeader, editBox)
    end

    return false
end

local function KT_GetBattleTagBase(target)
    target = KT_GetNonEmptyString(target)
    if not target then
        return nil
    end

    local base = target:match("^([^#]+)") or target
    base = strtrim(base)
    return base ~= "" and base or nil
end

local function KT_NormalizeWhisperRealmName(realmName)
    realmName = KT_GetNonEmptyString(realmName)
    if not realmName then
        return nil
    end

    realmName = realmName:gsub("[%s%-']+", "")
    return realmName ~= "" and realmName or nil
end

local function KT_ResolveBNetTellTarget(editBox)
    local bnetAccountID = tonumber(KT_GetEditBoxAttribute(editBox, "bnetAccountID"))
    if not (bnetAccountID and C_BattleNet and C_BattleNet.GetAccountInfoByID) then
        return nil
    end

    local accountInfo = C_BattleNet.GetAccountInfoByID(bnetAccountID)
    if not accountInfo then
        return nil
    end

    local accountName = KT_GetNonEmptyString(accountInfo.accountName)
    if accountName then
        return accountName
    end

    local battleTagBase = KT_GetBattleTagBase(accountInfo.battleTag)
    if battleTagBase then
        return battleTagBase
    end

    local gameInfo = accountInfo.gameAccountInfo
    local characterName = KT_GetNonEmptyString(gameInfo and gameInfo.characterName)
    if not characterName then
        return nil
    end

    local realmName = KT_NormalizeWhisperRealmName(gameInfo and (gameInfo.realmName or gameInfo.realmDisplayName))
    if realmName and not strfind(characterName, "-", 1, true) then
        characterName = characterName .. "-" .. realmName
    end

    return characterName
end

local function KT_IsExternalChatManagingEditBox(editBox)
    if editBox ~= (_G.ChatFrame1EditBox or (_G.ChatFrame1 and _G.ChatFrame1.editBox)) then
        return false
    end

    if not (KT and KT.GetModule) then
        return false
    end

    local chatMod = KT:GetModule("Chat", true)
    if not chatMod then
        return false
    end

    if chatMod.IsEnabled then
        local ok, enabled = pcall(chatMod.IsEnabled, chatMod)
        if ok and enabled then
            return true
        end
    end

    return chatMod.db ~= nil
end

local function KT_NormalizeInvalidWhisperEditBox(editBox)
    if not editBox or editBox._ktSanitizingWhisper then
        return
    end

    -- Modern clients protect the chat send path. Any insecure rewrite of the
    -- edit box state can taint the later SendChatMessage call in combat.
    if KT_IsSecureChatSafeMode() or (_G.InCombatLockdown and _G.InCombatLockdown()) then
        return
    end

    if KT_IsExternalChatManagingEditBox(editBox) then
        return
    end

    local chatType = KT_GetEditBoxAttribute(editBox, "chatType")
    if chatType == "BN_WHISPER" then
        local tellTarget = KT_GetEditBoxAttribute(editBox, "tellTarget")
        local bnetAccountID = tonumber(KT_GetEditBoxAttribute(editBox, "bnetAccountID"))
        if bnetAccountID and type(tellTarget) == "string" and strtrim(tellTarget) ~= "" then
            return
        end

        local resolvedTarget = KT_ResolveBNetTellTarget(editBox)

        editBox._ktSanitizingWhisper = true

        if editBox.SetAttribute then
            if resolvedTarget and bnetAccountID then
                pcall(editBox.SetAttribute, editBox, "chatType", "BN_WHISPER")
                pcall(editBox.SetAttribute, editBox, "bnetAccountID", bnetAccountID)
                pcall(editBox.SetAttribute, editBox, "tellTarget", resolvedTarget)
            else
                pcall(editBox.SetAttribute, editBox, "chatType", "SAY")
                pcall(editBox.SetAttribute, editBox, "tellTarget", nil)
                pcall(editBox.SetAttribute, editBox, "bnetAccountID", nil)
            end
        end

        if resolvedTarget and bnetAccountID then
            editBox.chatType = "BN_WHISPER"
            editBox.bnetAccountID = bnetAccountID
            editBox.tellTarget = resolvedTarget
        else
            editBox.chatType = "SAY"
            editBox.bnetAccountID = nil
            editBox.tellTarget = nil
        end

        KT_UpdateChatEditHeader(editBox)

        editBox._ktSanitizingWhisper = nil
        return
    end

    if chatType ~= "WHISPER" and chatType ~= "REPLY" then
        return
    end

    local tellTarget = KT_GetEditBoxAttribute(editBox, "tellTarget")
    if chatType == "REPLY" then
        local bnetAccountID = tonumber(KT_GetEditBoxAttribute(editBox, "bnetAccountID"))
        local replyTarget = nil
        local resolvedBNetTarget = nil

        if bnetAccountID then
            resolvedBNetTarget = KT_ResolveBNetTellTarget(editBox)
        end

        if type(tellTarget) == "string" and strtrim(tellTarget) ~= "" then
            replyTarget = tellTarget
        elseif not resolvedBNetTarget then
            replyTarget = KT_GetLastTellTarget()
        end

        editBox._ktSanitizingWhisper = true

        if editBox.SetAttribute then
            if resolvedBNetTarget and bnetAccountID then
                pcall(editBox.SetAttribute, editBox, "chatType", "BN_WHISPER")
                pcall(editBox.SetAttribute, editBox, "bnetAccountID", bnetAccountID)
                pcall(editBox.SetAttribute, editBox, "tellTarget", resolvedBNetTarget)
            elseif replyTarget then
                pcall(editBox.SetAttribute, editBox, "chatType", "WHISPER")
                pcall(editBox.SetAttribute, editBox, "tellTarget", replyTarget)
                pcall(editBox.SetAttribute, editBox, "bnetAccountID", nil)
            else
                pcall(editBox.SetAttribute, editBox, "chatType", "SAY")
                pcall(editBox.SetAttribute, editBox, "tellTarget", nil)
                pcall(editBox.SetAttribute, editBox, "bnetAccountID", nil)
            end
        end

        if resolvedBNetTarget and bnetAccountID then
            editBox.chatType = "BN_WHISPER"
            editBox.tellTarget = resolvedBNetTarget
            editBox.bnetAccountID = bnetAccountID
        elseif replyTarget then
            editBox.chatType = "WHISPER"
            editBox.tellTarget = replyTarget
            editBox.bnetAccountID = nil
        else
            editBox.chatType = "SAY"
            editBox.tellTarget = nil
            editBox.bnetAccountID = nil
        end

        KT_UpdateChatEditHeader(editBox)

        editBox._ktSanitizingWhisper = nil
        return
    end

    if type(tellTarget) == "string" and strtrim(tellTarget) ~= "" then
        return
    end

    editBox._ktSanitizingWhisper = true

    if editBox.SetAttribute then
        pcall(editBox.SetAttribute, editBox, "chatType", "SAY")
        pcall(editBox.SetAttribute, editBox, "tellTarget", nil)
        pcall(editBox.SetAttribute, editBox, "bnetAccountID", nil)
    end

    editBox.chatType = "SAY"
    editBox.tellTarget = nil
    editBox.bnetAccountID = nil

    KT_UpdateChatEditHeader(editBox)

    editBox._ktSanitizingWhisper = nil
end

local function KT_HookWhisperGuardForEditBox(editBox)
    if KT_IsSecureChatSafeMode()
        or not (editBox and editBox.HookScript)
        or editBox._ktWhisperGuardInstalled then
        return
    end

    editBox._ktWhisperGuardInstalled = true
    editBox:HookScript("OnShow", KT_NormalizeInvalidWhisperEditBox)
    editBox:HookScript("OnTextChanged", KT_NormalizeInvalidWhisperEditBox)
    editBox:HookScript("OnEditFocusGained", KT_NormalizeInvalidWhisperEditBox)

    KT_NormalizeInvalidWhisperEditBox(editBox)
end

local function KT_ShouldShowWhisperHeader(editBox)
    if not editBox then
        return false
    end

    local chatType = KT_GetEditBoxAttribute(editBox, "chatType")
    if chatType ~= "WHISPER" and chatType ~= "BN_WHISPER" and chatType ~= "REPLY" then
        return false
    end

    local tellTarget = KT_GetEditBoxAttribute(editBox, "tellTarget")
    if type(tellTarget) == "string" and strtrim(tellTarget) ~= "" then
        return true
    end

    local bnetAccountID = tonumber(KT_GetEditBoxAttribute(editBox, "bnetAccountID"))
    if bnetAccountID and KT_ResolveBNetTellTarget(editBox) then
        return true
    end

    return chatType == "REPLY" and KT_GetLastTellTarget() ~= nil
end

local function KT_SetChatHeaderVisibility(editBox, visible)
    if not editBox then
        return
    end

    for _, key in ipairs({ "header", "headerSuffix", "languageHeader", "prompt" }) do
        local region = editBox[key]
        if region then
            if visible then
                if region.Show then
                    pcall(region.Show, region)
                elseif region.SetAlpha then
                    pcall(region.SetAlpha, region, 1)
                end
            else
                if region.SetText then
                    pcall(region.SetText, region, "")
                end
                if region.Hide then
                    pcall(region.Hide, region)
                elseif region.SetAlpha then
                    pcall(region.SetAlpha, region, 0)
                end
            end
        end
    end
end

local function KT_TruncatePromptText(text, maxChars)
    if type(text) ~= "string" then
        return nil
    end

    maxChars = tonumber(maxChars) or 28
    if #text <= maxChars then
        return text
    end

    return text:sub(1, math.max(1, maxChars - 3)) .. "..."
end

local function KT_GetExternalChatPromptText(editBox, chatMod)
    chatMod = chatMod or (KT and KT.GetModule and KT:GetModule("Chat", true)) or nil
    if not chatMod then
        return nil
    end

    local activeTab = chatMod.GetActiveTab and chatMod:GetActiveTab() or nil
    local prompt = activeTab and (activeTab.prompt or activeTab.label) or nil
    local chatType = KT_GetEditBoxAttribute(editBox, "chatType")
    local tellTarget = KT_GetEditBoxAttribute(editBox, "tellTarget")
    local bnetAccountID = tonumber(KT_GetEditBoxAttribute(editBox, "bnetAccountID"))
    local target = nil

    if type(tellTarget) == "string" and strtrim(tellTarget) ~= "" then
        target = strtrim(tellTarget)
    elseif bnetAccountID then
        target = KT_ResolveBNetTellTarget(editBox)
    elseif chatType == "REPLY" then
        target = KT_GetLastTellTarget()
    end

    if not target and chatMod.GetActiveWhisperTargetForInput then
        target = chatMod:GetActiveWhisperTargetForInput()
    end
    if not target and type(chatMod.activeWhisperTarget) == "string" and strtrim(chatMod.activeWhisperTarget) ~= "" then
        target = strtrim(chatMod.activeWhisperTarget)
    end

    if (chatType == "WHISPER" or chatType == "BN_WHISPER" or chatType == "REPLY")
        or (activeTab and tostring(activeTab.filterMode or "") == "WHISPER") then
        prompt = prompt or ((chatType == "BN_WHISPER") and "Battle.net" or "Whisper")
        if target then
            prompt = string.format("%s %s:", tostring(prompt), KT_TruncatePromptText(target, 22))
        else
            prompt = string.format("%s:", tostring(prompt))
        end
    elseif prompt then
        prompt = string.format("%s:", tostring(prompt))
    end

    return KT_GetNonEmptyString(prompt)
end

local function KT_UpdateExternalChatPrompt(editBox, chatMod)
    chatMod = chatMod or (KT and KT.GetModule and KT:GetModule("Chat", true)) or nil
    local window = _G.KT_ChatWindow
    local inputHost = window and window.KT_InputHost or nil
    editBox = editBox or _G.ChatFrame1EditBox or (_G.ChatFrame1 and _G.ChatFrame1.editBox) or nil
    if not (chatMod and window and inputHost and editBox) then
        return
    end

    local promptFrame = window.KT_InputPromptFrame
    if not promptFrame then
        promptFrame = CreateFrame("Frame", nil, inputHost)
        promptFrame:SetAllPoints(inputHost)
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

    local fontPath, fontSize, fontOutline
    if chatMod.GetResolvedFont then
        fontPath, fontSize, fontOutline = chatMod:GetResolvedFont()
    end
    if label.SetFont then
        label:SetFont(fontPath or (KT and KT.FONT_PATH) or "Fonts\\FRIZQT__.TTF", fontSize or 12, fontOutline or "OUTLINE")
    end
    label:SetTextColor(0.94, 0.94, 0.98, 0.92)

    local promptText = KT_GetExternalChatPromptText(editBox, chatMod)
    if promptText then
        label:SetText(promptText)
        label:Show()
        local insetLeft = math.floor((label:GetStringWidth() or 0) + 18)
        if editBox.SetTextInsets then
            editBox:SetTextInsets(insetLeft, 8, 5, 5)
        end
    else
        label:SetText("")
        label:Hide()
        if editBox.SetTextInsets then
            editBox:SetTextInsets(8, 8, 5, 5)
        end
    end
end

local function KT_PatchExternalTemporaryWhisperWindows()
    return
end

local KT_PatchExternalChatHeaderBehavior

local function KT_AttemptExternalChatPatches()
    KT_PatchExternalChatHeaderBehavior()
    KT_PatchExternalTemporaryWhisperWindows()
end

KT_PatchExternalChatHeaderBehavior = function()
    return
end

local function KT_QueueExternalChatPatchRetries()
    return
end

local function KT_InstallWhisperTargetGuard()
    KT_AttemptExternalChatPatches()

    -- Do not replace EditBox:SendText or attach state-normalizing scripts on
    -- clients where Blizzard routes chat through protected/secret values.
    if KT_IsSecureChatSafeMode() then
        return
    end

    if KT and KT._whisperTargetGuardInstalled then
        return
    end

    if KT then
        KT._whisperTargetGuardInstalled = true
    end

    local total = tonumber(_G.NUM_CHAT_WINDOWS) or 10
    for i = 1, total do
        local frame = _G["ChatFrame" .. i]
        local editBox = _G["ChatFrame" .. i .. "EditBox"] or (frame and frame.editBox) or nil
        KT_HookWhisperGuardForEditBox(editBox)
    end

    if not KT_IsSecureChatSafeMode() and not (KT and KT._whisperTargetHeaderHooked) and _G.ChatEdit_UpdateHeader then
        if KT then
            KT._whisperTargetHeaderHooked = true
        end

        hooksecurefunc("ChatEdit_UpdateHeader", function(editBox)
            KT_NormalizeInvalidWhisperEditBox(editBox)
        end)
    end

    if not KT_IsSecureChatSafeMode() and not (KT and KT._whisperTargetTempWindowHooked) and _G.FCF_OpenTemporaryWindow then
        if KT then
            KT._whisperTargetTempWindowHooked = true
        end

        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, KT_InstallWhisperTargetGuard)
            else
                KT_InstallWhisperTargetGuard()
            end
        end)
    end

    KT_QueueExternalChatPatchRetries()
end

local function KT_PerfGetChatFrame()
    local total = tonumber(_G.NUM_CHAT_WINDOWS) or 10
    for i = 1, total do
        local frame = _G["ChatFrame" .. i]
        if frame and frame.AddMessage and frame.IsShown and frame:IsShown() then
            return frame
        end
    end

    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME.AddMessage then
        return _G.DEFAULT_CHAT_FRAME
    end
end

local function KT_PerfEnsureOutputFrame()
    if KT._perfOutputFrame then
        return KT._perfOutputFrame
    end

    if not (_G.CreateFrame and _G.UIParent) then
        return nil
    end

    local frame = CreateFrame("Frame", "KullThranUI_PerfOutputFrame", _G.UIParent, "BackdropTemplate")
    frame:SetSize(860, 420)
    frame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    if frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true,
            tileSize = 32,
            edgeSize = 32,
            insets = { left = 8, right = 8, top = 8, bottom = 8 },
        })
    end
    frame:Hide()

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16)
    title:SetText(LText("KullThranUI Perf Output"))
    frame.title = title

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    frame.closeButton = close

    local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clear:SetSize(80, 22)
    clear:SetPoint("TOPRIGHT", close, "TOPLEFT", -8, -2)
    clear:SetText(LText("Clear"))
    frame.clearButton = clear

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -46)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -34, 16)
    frame.scrollFrame = scroll

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:EnableMouse(true)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetWidth(780)
    editBox:SetScript("OnEscapePressed", function() frame:Hide() end)
    editBox:SetScript("OnTextChanged", function(box)
        box:SetCursorPosition(0)
        scroll:UpdateScrollChildRect()
        scroll:SetVerticalScroll(math.max(0, scroll:GetVerticalScrollRange() or 0))
    end)
    scroll:SetScrollChild(editBox)
    frame.editBox = editBox

    clear:SetScript("OnClick", function()
        frame.lines = {}
        editBox:SetText("")
    end)

    frame.lines = {}
    KT._perfOutputFrame = frame
    return frame
end

local function KT_PerfAppendToFrame(message)
    local frame = KT_PerfEnsureOutputFrame()
    if not frame or not frame.editBox then
        return
    end

    local lines = frame.lines or {}
    lines[#lines + 1] = message
    if #lines > 400 then
        table.remove(lines, 1)
    end
    frame.lines = lines

    frame.editBox:SetText(table.concat(lines, "\n"))
    frame:Show()
end

local function KT_PerfPrintLine(message)
    message = tostring(message or "")
    KT_PerfAppendToFrame(message)

    local chatFrame = KT_PerfGetChatFrame()
    if chatFrame then
        pcall(chatFrame.AddMessage, chatFrame, message)
    end

    if _G.DEFAULT_CHAT_FRAME and _G.DEFAULT_CHAT_FRAME ~= chatFrame and _G.DEFAULT_CHAT_FRAME.AddMessage then
        pcall(_G.DEFAULT_CHAT_FRAME.AddMessage, _G.DEFAULT_CHAT_FRAME, message)
    end

    if _G.ChatFrame_DisplaySystemMessageInPrimary then
        pcall(_G.ChatFrame_DisplaySystemMessageInPrimary, message)
    end

    if _G.UIErrorsFrame and _G.UIErrorsFrame.AddMessage then
        pcall(_G.UIErrorsFrame.AddMessage, _G.UIErrorsFrame, message, 1, 0.82, 0, 1, 3)
    end

    if _G.RaidNotice_AddMessage and _G.RaidWarningFrame then
        local info = (_G.ChatTypeInfo and (_G.ChatTypeInfo.SYSTEM or _G.ChatTypeInfo.RAID_WARNING)) or {}
        pcall(_G.RaidNotice_AddMessage, _G.RaidWarningFrame, message, info)
    end
end

local function KT_PerfPrint(...)
    local count = select("#", ...)
    if count <= 1 then
        KT_PerfPrintLine(select(1, ...))
        return
    end

    local parts = {}
    for i = 1, count do
        parts[i] = tostring(select(i, ...))
    end

    KT_PerfPrintLine(table.concat(parts, " "))
end

local function KT_GetCDMNamespace()
    if type(_G.KUI_CDM_NS) == "table" then
        return _G.KUI_CDM_NS
    end
    return ns
end

local function KT_GetMinimapModule()
    if type(_G.KT_MINIMAP_MODULE) == "table" then
        return _G.KT_MINIMAP_MODULE
    end
    if KT and KT.GetModule then
        return KT:GetModule("Minimap", true)
    end
end

local function KT_TryLoadStartupAddon(addonName)
    if type(addonName) ~= "string" or addonName == "" then
        return false, "INVALID"
    end

    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.LoadAddOn) then
        return false, "API"
    end

    if C_AddOns.IsAddOnLoaded(addonName) then
        return true, "ALREADY"
    end

    local playerName = UnitName and UnitName("player")
    if playerName and C_AddOns.GetAddOnEnableState then
        local state = C_AddOns.GetAddOnEnableState(playerName, addonName) or 0
        if state <= 0 then
            return false, "DISABLED"
        end
    end

    local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, addonName)
    if not ok then
        return false, "ERROR"
    end
    if loaded then
        return true, "LOADED"
    end

    return false, reason or "FAILED"
end

local function KT_HandlePerfCommand(args)
    local cdmNs = KT_GetCDMNamespace()
    local perf = cdmNs and cdmNs._perf
    if not perf then
        KT_PerfPrint("|cffFF4444[ktperf]|r ns._perf no encontrado - cargo KUICooldownManager?")
        return
    end
    if perf.capturing then
        KT_PerfPrint("|cffFFAA00[ktperf]|r Captura en curso, espera que termine.")
        return
    end

    local duration = math.max(1, math.min(tonumber(args) or 5, 60))
    perf.tickCount    = 0
    perf.totalMs      = 0
    perf.peakMs       = 0
    perf.bars         = {}
    perf.phases       = {}
    perf.phasePeaks   = {}
    perf.events       = {}
    perf.dirtyReasons = {}
    perf.skippedTicks = 0
    perf.lastTick     = {}
    perf.captureStart = GetTime()
    perf.captureDur   = duration
    perf.onDone       = function() KT:_PrintPerfReport(perf, duration) end
    perf.capturing    = true

    KT_PerfPrint("|cff00FF88[ktperf]|r Midiendo " .. duration .. "s... (espera el resultado)")
end

local function KT_HandleCDMStatsCommand()
    if KT and KT._PrintCDMStats then
        KT:_PrintCDMStats()
        return
    end

    KT_PerfPrint("|cffFF4444[ktcdmstats]|r handler no disponible.")
end

local function KT_HandleMinimapPerfCommand(args)
    local duration = math.max(1, math.min(tonumber(args) or 5, 60))
    local minimapModule = KT_GetMinimapModule()
    if not minimapModule or type(minimapModule.StartPerfCapture) ~= "function" then
            KT_PerfPrint("|cffFF4444[ktminimapperf]|r módulo Minimap no disponible.")
        return
    end

    local ok = minimapModule:StartPerfCapture(duration, function(snapshot)
        KT:_PrintMinimapPerfReport(snapshot)
    end)
    if not ok then
        KT_PerfPrint("|cffFFAA00[ktminimapperf]|r Ya hay una captura en curso.")
        return
    end

    KT_PerfPrint("|cff00FF88[ktminimapperf]|r Midiendo " .. duration .. "s... (espera el resultado)")
end

SLASH_KTPERF1 = "/ktperf"
SlashCmdList["KTPERF"] = function(msg)
    local ok, err = pcall(KT_HandlePerfCommand, msg)
    if not ok then
        KT_PerfPrint("|cffFF4444[ktperf]|r error: " .. tostring(err))
    end
end

SLASH_KTCDMSTATS1 = "/ktcdmstats"
SlashCmdList["KTCDMSTATS"] = function(msg)
    local ok, err = pcall(KT_HandleCDMStatsCommand, msg)
    if not ok then
        KT_PerfPrint("|cffFF4444[ktcdmstats]|r error: " .. tostring(err))
    end
end

SLASH_KTMINIMAPPERF1 = "/ktminimapperf"
SlashCmdList["KTMINIMAPPERF"] = function(msg)
    local ok, err = pcall(KT_HandleMinimapPerfCommand, msg)
    if not ok then
        KT_PerfPrint("|cffFF4444[ktminimapperf]|r error: " .. tostring(err))
    end
end

local function InstallSafePvPObjectiveBanner()
    local frame = _G.PvPObjectiveBannerFrame
    if not frame or frame._ktSafePlayBannerInstalled then
        return
    end

    local original = frame.PlayBanner
    if type(original) ~= "function" then
        return
    end

    frame.PlayBanner = function(self, data, ...)
        EnsureRegionWidth(self.BG1, 340)
        EnsureRegionWidth(self.BG2, 340)
        EnsureRegionWidth(self.Icon, 64)
        EnsureRegionWidth(self.Icon2, 64)
        EnsureRegionWidth(self.Icon3, 64)

        local ok = pcall(original, self, data, ...)
        if ok then
            return
        end

        local titleText = type(data) == "table" and data.name or ""
        local bonusText = type(data) == "table" and (data.description or "") or ""

        if self.Anim and self.Anim.Stop then
            pcall(self.Anim.Stop, self.Anim)
        end
        if self.Title and self.Title.SetText then
            pcall(self.Title.SetText, self.Title, titleText)
        end
        if self.TitleFlash and self.TitleFlash.SetText then
            pcall(self.TitleFlash.SetText, self.TitleFlash, titleText)
        end
        if self.BonusLabel and self.BonusLabel.SetText then
            pcall(self.BonusLabel.SetText, self.BonusLabel, bonusText)
        end
        if self.BG1 and self.BG1.Show then
            pcall(self.BG1.Show, self.BG1)
        end
        if self.BG2 and self.BG2.Show then
            pcall(self.BG2.Show, self.BG2)
        end
        if self.Show then
            pcall(self.Show, self)
        end
        if self.Title and self.Title.Show then
            pcall(self.Title.Show, self.Title)
        end
        if self.BonusLabel and self.BonusLabel.Show then
            pcall(self.BonusLabel.Show, self.BonusLabel)
        end

        if C_Timer and C_Timer.After and self.Hide then
            C_Timer.After(4, function()
                if self and self.Hide then
                    pcall(self.Hide, self)
                end
            end)
        end
    end

    frame._ktSafePlayBannerInstalled = true
end

local function EnsureSafePvPBannerHook()
    if IsAddOnLoaded and IsAddOnLoaded("Blizzard_PVPUI") then
        InstallSafePvPObjectiveBanner()
        if not (_G.PvPObjectiveBannerFrame and _G.PvPObjectiveBannerFrame._ktSafePlayBannerInstalled) and C_Timer and not KT._pvpBannerInstallTicker then
            KT._pvpBannerInstallTicker = C_Timer.NewTicker(0.5, function()
                InstallSafePvPObjectiveBanner()
                if _G.PvPObjectiveBannerFrame and _G.PvPObjectiveBannerFrame._ktSafePlayBannerInstalled then
                    if KT._pvpBannerInstallTicker and KT._pvpBannerInstallTicker.Cancel then
                        KT._pvpBannerInstallTicker:Cancel()
                    end
                    KT._pvpBannerInstallTicker = nil
                end
            end, 20)
        end
        return
    end

    if KT._pvpBannerLoadWatcher then
        return
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(_, _, addon)
        if addon == "Blizzard_PVPUI" then
            InstallSafePvPObjectiveBanner()
            if not (_G.PvPObjectiveBannerFrame and _G.PvPObjectiveBannerFrame._ktSafePlayBannerInstalled) and C_Timer and not KT._pvpBannerInstallTicker then
                KT._pvpBannerInstallTicker = C_Timer.NewTicker(0.5, function()
                    InstallSafePvPObjectiveBanner()
                    if _G.PvPObjectiveBannerFrame and _G.PvPObjectiveBannerFrame._ktSafePlayBannerInstalled then
                        if KT._pvpBannerInstallTicker and KT._pvpBannerInstallTicker.Cancel then
                            KT._pvpBannerInstallTicker:Cancel()
                        end
                        KT._pvpBannerInstallTicker = nil
                    end
                end, 20)
            end
            watcher:UnregisterEvent("ADDON_LOADED")
            KT._pvpBannerLoadWatcher = nil
        end
    end)
    KT._pvpBannerLoadWatcher = watcher
end

local function IsSecureGroupFinderBuild()
    local _, _, _, interfaceVersion = _G.GetBuildInfo and _G.GetBuildInfo()
    interfaceVersion = tonumber(interfaceVersion) or 0
    return interfaceVersion >= 120000
end

local function EnsureSafeGroupFinderSkinSetting()
    if not IsSecureGroupFinderBuild() then
        return
    end

    KT.db = KT.db or {}
    KT.db.profile = KT.db.profile or {}
    KT.db.profile.skin = KT.db.profile.skin or {}
    KT.db.profile.skin.blizzard = KT.db.profile.skin.blizzard or {}

    KT.db.profile.skin.blizzard.lfg = false

    local skins = KT and KT.GetModule and KT:GetModule("Skins", true)
    if skins then
        skins.db = skins.db or KT.db.profile.skin.blizzard
        skins.db.lfg = false
        if type(skins.SkinFuncs) == "table" then
            skins.SkinFuncs["Blizzard_GroupFinder"] = nil
        end
    end
end

local function ApplySafeGroupFinderSkinGuard()
    if not IsSecureGroupFinderBuild() then
        return true
    end

    EnsureSafeGroupFinderSkinSetting()

    local skins = KT and KT.GetModule and KT:GetModule("Skins", true)
    if not skins or type(skins.SkinFuncs) ~= "table" then
        return false
    end

    local original = skins.SkinFuncs["Blizzard_GroupFinder"]
    if type(original) == "function" and not skins._ktOriginalGroupFinderSkinFunc then
        skins._ktOriginalGroupFinderSkinFunc = original
        skins.SkinFuncs["Blizzard_GroupFinder"] = function()
            -- Modern retail LFGList uses secret values heavily; keep Blizzard's
            -- Group Finder UI untouched to avoid taint in applicant viewer updates.
        end
    end

    KT._groupFinderSkinGuardApplied = true
    return true
end

local function EnsureSafeGroupFinderSkinGuard()
    if KT._groupFinderSkinGuardApplied and not KT._groupFinderSkinGuardWatcher then
        return
    end

    EnsureSafeGroupFinderSkinSetting()

    if ApplySafeGroupFinderSkinGuard() and KT._groupFinderSkinGuardWatcher then
        KT._groupFinderSkinGuardWatcher:UnregisterEvent("ADDON_LOADED")
        KT._groupFinderSkinGuardWatcher = nil
        return
    end

    if KT._groupFinderSkinGuardWatcher then
        return
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(self, _, addon)
        if addon == "KullThranUI_Skins" or addon == "Blizzard_GroupFinder" then
            if ApplySafeGroupFinderSkinGuard() then
                self:UnregisterEvent("ADDON_LOADED")
                KT._groupFinderSkinGuardWatcher = nil
            elseif C_Timer and C_Timer.After then
                C_Timer.After(0, function()
                    if ApplySafeGroupFinderSkinGuard() and KT._groupFinderSkinGuardWatcher then
                        KT._groupFinderSkinGuardWatcher:UnregisterEvent("ADDON_LOADED")
                        KT._groupFinderSkinGuardWatcher = nil
                    end
                end)
            end
        end
    end)
    KT._groupFinderSkinGuardWatcher = watcher
end

local function PerformFullKullThranUIReset()
    KT.db:ResetProfile()
    if ns.ResetNameplatesDB then
        ns.ResetNameplatesDB()
    end
    if ns.ProfileData and ns.ProfileData.Layouts and ns.Handlers and ns.Handlers.Layout then
        local _, height = GetPhysicalScreenSize()
        local layout = height >= 2160 and "4K" or height >= 1440 and "2K" or "1080p"
        if ns.ProfileData.Layouts[layout] then
            ns.Handlers.Layout(KT.db:GetCurrentProfile(), ns.ProfileData.Layouts[layout])
        end
    end
    KT.db.profile.autoResolutionScale = true
    KT.db.profile.useBlizzardUIScale = false
    KT.db.profile.uiScaleInitialized = false
    if KT.db and KT.db.profile then
        KT.db.profile.installer = KT.db.profile.installer or {}
        KT.db.profile.installer.showOnLogin = true
        KT.db.profile.installer.step = 1
        KT.db.profile.installer.dontShowAgain = nil
        KT.db.profile.installer.lastVersion = nil
    end
    local Installer = KT:GetModule("Installer", true)
    if Installer and Installer.ApplyScaleOnly then
        Installer:ApplyScaleOnly("AUTO", { silent = true })
    elseif KT.ApplyUIScale then
        KT.db.profile.uiScale = nil
        KT:ApplyUIScale()
    end
    ReloadUI()
end

function KT:SanitizeEditModeFramesDB(framesDB)
    if type(framesDB) ~= "table" then
        return framesDB
    end

    local blockedKeys = {
        "minimap",
        "Minimap",
        "MinimapCluster",
        "KT_MinimapHolder_Main",
        "DamageMeter",
        "Blizzard_DamageMeter",
        "DamageMeterFrame",
        "DamageMeterViewer",
        "DamageMeterSessionWindow",
        "DamageMeterSessionWindow1",
        "DamageMeterSessionWindow2",
    }

    for i = 1, #blockedKeys do
        framesDB[blockedKeys[i]] = nil
    end

    for key in pairs(framesDB) do
        if type(key) == "number" then
            framesDB[key] = nil
        end
    end

    return framesDB
end

function KT:IsManagedMinimapKey(key)
    return key == "minimap"
        or key == "Minimap"
        or key == "MinimapCluster"
        or key == "KT_MinimapHolder_Main"
end

local SENSITIVE_BLIZZARD_PROFILE_KEYS = {
    "DamageMeter",
    "Blizzard_DamageMeter",
    "DamageMeterFrame",
    "DamageMeterViewer",
    "DamageMeterSessionWindow",
    "DamageMeterSessionWindow1",
    "DamageMeterSessionWindow2",
}

local function ClearSensitiveBlizzardKeys(container)
    if type(container) ~= "table" then
        return false
    end

    local changed = false
    for i = 1, #SENSITIVE_BLIZZARD_PROFILE_KEYS do
        local key = SENSITIVE_BLIZZARD_PROFILE_KEYS[i]
        if container[key] ~= nil then
            container[key] = nil
            changed = true
        end
    end
    return changed
end

function KT:SanitizeLegacyMinimapData(profileDB)
    if type(profileDB) ~= "table" then
        return false
    end

    local changed = false

    if type(profileDB.editMode) == "table" then
        local framesDB = profileDB.editMode.frames
        if type(framesDB) == "table" then
            for _, key in ipairs({
                "minimap",
                "Minimap",
                "MinimapCluster",
                "KT_MinimapHolder_Main",
                "DamageMeter",
                "Blizzard_DamageMeter",
                "DamageMeterFrame",
                "DamageMeterViewer",
                "DamageMeterSessionWindow",
                "DamageMeterSessionWindow1",
                "DamageMeterSessionWindow2",
            }) do
                if framesDB[key] ~= nil then
                    framesDB[key] = nil
                    changed = true
                end
            end

            for key in pairs(framesDB) do
                if type(key) == "number" then
                    framesDB[key] = nil
                    changed = true
                end
            end
        end
    end

    local movers = profileDB.movers
    if type(movers) == "table" then
        for _, key in ipairs({
            "minimap",
            "Minimap",
            "MinimapCluster",
            "KT_MinimapHolder_Main",
            "DamageMeter",
            "Blizzard_DamageMeter",
            "DamageMeterFrame",
            "DamageMeterViewer",
            "DamageMeterSessionWindow",
            "DamageMeterSessionWindow1",
            "DamageMeterSessionWindow2",
        }) do
            if movers[key] ~= nil then
                movers[key] = nil
                changed = true
            end
        end
    end

    if type(profileDB.skin) == "table" and type(profileDB.skin.blizzard) == "table" then
        if profileDB.skin.blizzard.damagemeter ~= false then
            profileDB.skin.blizzard.damagemeter = false
            changed = true
        end
    end

    for _, moveKey in ipairs({ "kuiMove", "blizzMove", "BlizzMove", "KUIMove" }) do
        local moveDB = profileDB[moveKey]
        if type(moveDB) == "table" then
            if type(moveDB.points) == "table" and ClearSensitiveBlizzardKeys(moveDB.points) then
                changed = true
            end
            if type(moveDB.scales) == "table" and ClearSensitiveBlizzardKeys(moveDB.scales) then
                changed = true
            end
            if type(moveDB.disabledFrames) == "table" then
                for _, addOnName in ipairs({ "KullThranUI", "Blizzard_DamageMeter" }) do
                    if type(moveDB.disabledFrames[addOnName]) ~= "table" then
                        moveDB.disabledFrames[addOnName] = {}
                    end
                    for i = 1, #SENSITIVE_BLIZZARD_PROFILE_KEYS do
                        local key = SENSITIVE_BLIZZARD_PROFILE_KEYS[i]
                        if moveDB.disabledFrames[addOnName][key] ~= true then
                            moveDB.disabledFrames[addOnName][key] = true
                            changed = true
                        end
                    end
                end
            end
            if type(moveDB.enabledFrames) == "table" then
                for _, addOnName in ipairs({ "KullThranUI", "Blizzard_DamageMeter" }) do
                    if type(moveDB.enabledFrames[addOnName]) == "table" and ClearSensitiveBlizzardKeys(moveDB.enabledFrames[addOnName]) then
                        changed = true
                    end
                end
            end
        end
    end

    return changed
end

function KT:SanitizeAllProfilesMinimapData()
    if not self.db then
        return false
    end

    local changed = false
    local sv = self.db.sv
    local profiles = sv and sv.profiles

    if type(profiles) == "table" then
        for _, profileDB in pairs(profiles) do
            if self:SanitizeLegacyMinimapData(profileDB) then
                changed = true
            end
        end
    end

    if self.db.profile and self:SanitizeLegacyMinimapData(self.db.profile) then
        changed = true
    end

    return changed
end

local function CaptureFrameAnchorSnapshot(frame)
    if not (frame and frame.GetPoint) then
        return nil
    end

    local point, relativeTo, relativePoint, x, y = frame:GetPoint()
    if not point then
        return nil
    end

    return {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint or point,
        x = x or 0,
        y = y or 0,
        scale = frame.GetScale and frame:GetScale() or nil,
    }
end

function KT:CaptureManagedPositions()
    self._uiHiddenManagedPositions = self._uiHiddenManagedPositions or {
        bars = {},
        elements = {},
    }

    local snapshot = self._uiHiddenManagedPositions
    wipe(snapshot.bars)
    wipe(snapshot.elements)

    if self.bars then
        for index, bar in ipairs(self.bars) do
            if bar and bar.header then
                snapshot.bars[index] = CaptureFrameAnchorSnapshot(bar.header)
            end
        end
    end

    if not self.UnlockElements then
        return
    end

    for key, def in pairs(self.UnlockElements) do
        if not self:IsManagedMinimapKey(key) and type(def) == "table" and type(def.getFrame) == "function" then
            local okFrame, frame = pcall(def.getFrame, key)
            if okFrame and frame then
                snapshot.elements[key] = CaptureFrameAnchorSnapshot(frame)
            end
        end
    end
end

function KT:RestoreManagedPositions()
    if InCombatLockdown and InCombatLockdown() then
        self._pendingManagedPositionRestore = true
        if not self._managedPositionRestoreFrame then
            local frame = CreateFrame("Frame")
            frame:SetScript("OnEvent", function(f, event)
                if event ~= "PLAYER_REGEN_ENABLED" then
                    return
                end

                if KT and KT._pendingManagedPositionRestore and KT.RestoreManagedPositions then
                    KT._pendingManagedPositionRestore = nil
                    KT:RestoreManagedPositions()
                end

                if not (KT and KT._pendingManagedPositionRestore) then
                    f:UnregisterEvent("PLAYER_REGEN_ENABLED")
                end
            end)
            self._managedPositionRestoreFrame = frame
        end
        self._managedPositionRestoreFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end

    if self.bars then
        for index, bar in ipairs(self.bars) do
            if bar and bar.header then
                local snapshot = self._uiHiddenManagedPositions and self._uiHiddenManagedPositions.bars and self._uiHiddenManagedPositions.bars[index]
                if snapshot then
                    if snapshot.scale and bar.header.SetScale then
                        pcall(bar.header.SetScale, bar.header, snapshot.scale)
                    end
                    pcall(bar.header.ClearAllPoints, bar.header)
                    pcall(
                        bar.header.SetPoint,
                        bar.header,
                        snapshot.point or "TOPLEFT",
                        snapshot.relativeTo or _G.UIParent,
                        snapshot.relativePoint or snapshot.point or "TOPLEFT",
                        snapshot.x or 0,
                        snapshot.y or 0
                    )
                elseif type(bar.LoadPosition) == "function" then
                    pcall(bar.LoadPosition, bar)
                end
            end
        end
    end

    local kuiMove = self.GetModule and self:GetModule("KUIMove", true)
    if kuiMove and kuiMove.FrameData and kuiMove.AddToSetFramePointsQueue then
        for frame, frameData in pairs(kuiMove.FrameData) do
            local storage = frameData and frameData.storage
            local points = storage and storage.points
            local dragPoints = points and points.dragPoints
            if
                frame
                and storage
                and not storage.disabled
                and points
                and points.dragged
                and dragPoints
                and not (frameData.IgnoreSavedPositionWhenMaximized and frame.isMaximized)
            then
                if kuiMove.SetupPointStorage then
                    pcall(kuiMove.SetupPointStorage, kuiMove, frame)
                end
                pcall(kuiMove.AddToSetFramePointsQueue, kuiMove, frame, dragPoints)
            end
        end
    end

    if not self.UnlockElements then
        return
    end

    for key, def in pairs(self.UnlockElements) do
        if not self:IsManagedMinimapKey(key) and type(def) == "table" then
            local snapshot = self._uiHiddenManagedPositions and self._uiHiddenManagedPositions.elements and self._uiHiddenManagedPositions.elements[key]
            if snapshot and type(def.getFrame) == "function" then
                local okFrame, frame = pcall(def.getFrame, key)
                if okFrame and frame then
                    if snapshot.scale and frame.SetScale then
                        pcall(frame.SetScale, frame, snapshot.scale)
                    end
                    if frame.ClearAllPoints and frame.SetPoint then
                        pcall(frame.ClearAllPoints, frame)
                        pcall(
                            frame.SetPoint,
                            frame,
                            snapshot.point or "TOPLEFT",
                            snapshot.relativeTo or _G.UIParent,
                            snapshot.relativePoint or snapshot.point or "TOPLEFT",
                            snapshot.x or 0,
                            snapshot.y or 0
                        )
                    end
                end
            elseif type(def.applyPosition) == "function" then
                pcall(def.applyPosition, key)
            elseif type(def.loadPosition) == "function" and type(def.getFrame) == "function" then
                local okPos, pos = pcall(def.loadPosition, key)
                local okFrame, frame = pcall(def.getFrame, key)
                if okPos and okFrame and frame and pos and pos.point then
                    if pos.scale and frame.SetScale then
                        pcall(frame.SetScale, frame, pos.scale)
                    end
                    if frame.ClearAllPoints and frame.SetPoint then
                        pcall(frame.ClearAllPoints, frame)
                        pcall(
                            frame.SetPoint,
                            frame,
                            pos.point or "TOPLEFT",
                            pos.relativeTo or _G.UIParent,
                            pos.relativePoint or pos.point or "TOPLEFT",
                            pos.x or 0,
                            pos.y or 0
                        )
                    end
                end
            end
        end
    end
end

function KT:ScheduleManagedPositionRestore(delay)
    local waitTime = tonumber(delay) or 0
    if waitTime <= 0 then
        self:RestoreManagedPositions()
        return
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(waitTime, function()
            if KT and KT.RestoreManagedPositions then
                KT:RestoreManagedPositions()
            end
        end)
        return
    end

    self:RestoreManagedPositions()
end

function KT:RunOptionalModuleLayoutRecovery()
    if not (self and self.GetModule) then
        return
    end

    local chatMod = self:GetModule("Chat", true)
    if chatMod then
        if chatMod.QueueWorldLayoutRecovery then
            pcall(chatMod.QueueWorldLayoutRecovery, chatMod)
        elseif chatMod.RecoverChatLayoutAfterWorldChange then
            pcall(chatMod.RecoverChatLayoutAfterWorldChange, chatMod)
        elseif chatMod.AttachBlizzardEditBox then
            pcall(chatMod.AttachBlizzardEditBox, chatMod)
        end
    end

    local auraMod = self:GetModule("BuffsAndDebuffs", true)
    if auraMod then
        if auraMod.ScheduleScan then
            pcall(auraMod.ScheduleScan, auraMod, 0)
        elseif auraMod.HandleImmediateRefresh then
            pcall(auraMod.HandleImmediateRefresh, auraMod)
        elseif auraMod.UpdateAll then
            pcall(auraMod.UpdateAll, auraMod)
        end
    end
end

function KT:QueueOptionalModuleRecoveryBurst(delays)
    local recoveryDelays = delays or { 0, 0.1, 0.3, 0.8 }
    for i = 1, #recoveryDelays do
        local waitTime = tonumber(recoveryDelays[i]) or 0
        if waitTime <= 0 then
            self:RunOptionalModuleLayoutRecovery()
        elseif C_Timer and C_Timer.After then
            C_Timer.After(waitTime, function()
                if KT and KT.RunOptionalModuleLayoutRecovery then
                    KT:RunOptionalModuleLayoutRecovery()
                end
            end)
        end
    end
end

function KT:HookOptionalModuleLayoutRecovery()
    if self._optionalModuleRecoveryHooked then
        return
    end

    self._optionalModuleRecoveryHooked = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
    frame:SetScript("OnEvent", function(_, event, arg1)
        if not (KT and KT.QueueOptionalModuleRecoveryBurst) then
            return
        end

        if event == "ADDON_LOADED" then
            if arg1 == "KullThranUI_Chat" or arg1 == "KullThranUI_BuffsAndDebuffs" then
                KT:QueueOptionalModuleRecoveryBurst()
            end
            return
        end

        if event == "EDIT_MODE_LAYOUTS_UPDATED" then
            KT:QueueOptionalModuleRecoveryBurst({ 0, 0.1, 0.3, 0.8, 1.2 })
            return
        end

        KT:QueueOptionalModuleRecoveryBurst({ 0, 0.1, 0.3, 0.8 })
    end)
    self._optionalModuleRecoveryFrame = frame

    local function hookEditModeManager()
        if KT and KT._optionalModuleEditModeHooked then
            return
        end

        local manager = _G.EditModeManagerFrame
        if not (manager and manager.HookScript) then
            if C_Timer and C_Timer.After then
                C_Timer.After(1, hookEditModeManager)
            end
            return
        end

        KT._optionalModuleEditModeHooked = true
        manager:HookScript("OnHide", function()
            if KT and KT.QueueOptionalModuleRecoveryBurst then
                KT:QueueOptionalModuleRecoveryBurst({ 0, 0.05, 0.15, 0.35, 0.8, 1.2 })
            end
        end)
    end

    hookEditModeManager()
end

function KT:HookUIParentRestore()
    local parent = _G.UIParent
    if self._uiParentRestoreHooked or not (parent and parent.HookScript) then
        return
    end

    self._uiParentRestoreHooked = true
    parent:HookScript("OnHide", function()
        if KT and KT.CaptureManagedPositions then
            KT:CaptureManagedPositions()
        end
    end)
    parent:HookScript("OnShow", function()
        if KT and KT.ScheduleManagedPositionRestore then
            KT:ScheduleManagedPositionRestore(0)
            KT:ScheduleManagedPositionRestore(0.1)
            KT:ScheduleManagedPositionRestore(0.3)
        end
        if KT and KT.QueueOptionalModuleRecoveryBurst then
            KT:QueueOptionalModuleRecoveryBurst({ 0, 0.1, 0.3, 0.8 })
        end
    end)
end

-- ============================================================================
-- 1. ON INITIALIZE
-- ============================================================================
function KT:PrintStartupMessages()
    local version = KT.VERSION or "5.0.9"
    local updateAvailable = false
    local latestVersion = KT.GetLatestArchivedChangelogVersion and KT:GetLatestArchivedChangelogVersion()
    if latestVersion and KT.CompareVersions then
        updateAvailable = KT.CompareVersions(version, latestVersion) < 0
    end

    local L = self:GetLocale() or {}
    local welcomeKey = updateAvailable
        and [[Welcome to KullThranUI version %s, an update is available.]]
        or [[Welcome to KullThranUI version %s, you have the latest version installed!]]
    local discordKey = [[To keep up with the latest KUI news, join our Discord: %s.]]
    local discordUrl = 'https://discord.gg/cqAVWpeVvd'
    local white = '|cffffffff'
    local crimson = '|cffdc143c'
    local discordBlue = '|cff5865f2'

    local function ColorBrandNames(text)
        text = tostring(text or '')
        text = text:gsub('KullThranUI', crimson .. 'KullThranUI' .. white)
        text = text:gsub('KUI', crimson .. 'KUI' .. white)
        return white .. text .. '|r'
    end

    local welcomeText = string.format(L[welcomeKey] or welcomeKey, version)
    local discordLink = discordBlue .. discordUrl .. white
    local discordText = string.format(L[discordKey] or discordKey, discordLink)

    self:Print(ColorBrandNames(welcomeText))
    self:Print(ColorBrandNames(discordText))
end

local classCacheWatcher = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "NAME_PLATE_UNIT_ADDED", "ARENA_OPPONENT_UPDATE" }) do
    classCacheWatcher:RegisterEvent(event)
end
classCacheWatcher:RegisterEvent('ARENA_PREP_OPPONENT_SPECIALIZATIONS')
classCacheWatcher:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" or event == "ARENA_OPPONENT_UPDATE" then
        if unit then pcall(KT.SafeUnitClass, unit) end
        return
    end
    pcall(KT.SafeUnitClass, "player")
    for i = 1, 5 do
        pcall(KT.SafeUnitClass, "party" .. i)
        pcall(KT.SafeUnitClass, "arena" .. i)
    end
end)

function KT:InitializeCore()
    local L = self:GetLocale() or {}
    local function LText(text)
        return L[text] or text
    end

    -- 1. Generar defaults (definidos en Config.lua)
    local defaults = self.GenerateDefaults and self:GenerateDefaults()
                     or { profile = {} }

    -- 2. Crear base de datos
    -- Existing characters keep the profile recorded in profileKeys. New
    -- characters must start on their own profile so first-run defaults (most
    -- importantly installer.showOnLogin) are not inherited from "Default".
    self.db = LibStub("AceDB-3.0"):New("KullThranDB", defaults)
    if self.db and self.db.profile then
        self.db.profile.editMode = self.db.profile.editMode or {}
        self.db.profile.editMode.frames = self:SanitizeEditModeFramesDB(self.db.profile.editMode.frames or {})
    end
    self:SanitizeAllProfilesMinimapData()
    if self.SanitizeLegacyCooldownManagerBorders then
        self:SanitizeLegacyCooldownManagerBorders()
    end
    if self.NormalizeStyleState then
        self:NormalizeStyleState()
    end
    if self.RefreshStylePalette then
        self:RefreshStylePalette()
    end

    C_Timer.After(0, function()
        KT_TryLoadStartupAddon("KullThranUI_Chat")
        KT_InstallWhisperTargetGuard()
    end)

    EnsureSafePvPBannerHook()
    EnsureSafeGroupFinderSkinGuard()
    self:HookUIParentRestore()
    self:HookOptionalModuleLayoutRecovery()

    -- 3. Escala de UI
    self:ApplyUIScale()
    C_Timer.After(0, function() if KT and KT.ApplyUIScale then KT:ApplyUIScale() end end)
    C_Timer.After(0.5, function() if KT and KT.ApplyUIScale then KT:ApplyUIScale() end end)
    C_Timer.After(2.0, function() if KT and KT.ApplyUIScale then KT:ApplyUIScale() end end)

    -- 4. Diálogos estáticos
    StaticPopupDialogs["KULLTHRANUI_RELOAD"] = {
        text    = LText("KullThranUI: Reload the UI to apply the changes."),
        button1 = LText("Reload UI"),
        button2 = LText("Later"),
        OnAccept = function() ReloadUI() end,
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    }

    StaticPopupDialogs["KULLTHRANUI_RESET_CONFIRM"] = {
        text    = LText("|cffFF4444Warning:|r This will restore all KullThranUI settings to their defaults and reload the UI."),
        button1 = LText("Continue"),
        button2 = LText("Cancel"),
        OnAccept = function()
            StaticPopup_Show("KULLTHRANUI_RESET_CONFIRM_FINAL")
        end,
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    }

    StaticPopupDialogs["KULLTHRANUI_RESET_CONFIRM_FINAL"] = {
        text    = LText("|cffFF2222Final confirmation:|r Your KullThranUI profile will be fully reset, the installer will reopen, and the UI will reload. This action cannot be undone."),
        button1 = LText("Reset Now"),
        button2 = LText("Cancel"),
        OnAccept = PerformFullKullThranUIReset,
        timeout = 0, whileDead = 1, hideOnEscape = 1, preferredIndex = 3,
    }
    -- 5. Comandos de chat
    self:RegisterChatCommand("kt",        "ToggleConfig")
    self:RegisterChatCommand("kui",       "ToggleConfig")
    self:RegisterChatCommand("installer", "OpenInstaller")
    self:RegisterChatCommand("ins", "OpenInstaller")
    self:RegisterChatCommand("installers", "OpenInstaller")

    -- Direct slash aliases: keep these available even if another addon
    -- changes AceConsole's command table after the core initializes.
    SLASH_KULLTHRANUIINSTALLER1 = "/installer"
    SLASH_KULLTHRANUIINSTALLER2 = "/ins"
    SLASH_KULLTHRANUIINSTALLER3 = "/installers"
    SlashCmdList["KULLTHRANUIINSTALLER"] = function()
        KT:OpenInstaller()
    end
    self:RegisterChatCommand("ktcpu", function(args)
        KT:_HandleCPUCommand(args)
    end)

    -- 6. Comandos estándar de debug
    self:RegisterChatCommand("ktdebug", function()
        self:Print("DB: " .. (self.db and "|cff00FF00OK|r" or "|cffFF0000FAIL|r") ..
                   "  Profile: " .. (self.db and self.db:GetCurrentProfile() or "n/a"))
    end)

    self:RegisterChatCommand("ktdmdebug", function()
        local damageMeter = KT:GetModule("Enhancements", true)
        if damageMeter and damageMeter.DebugDamageMeter then
            damageMeter:DebugDamageMeter()
        else
            self:Print("|cff66ccff[ktdmdebug]|r Damage Meter module not available.")
        end
    end)
    self:RegisterChatCommand("ktframe", function()
        local frame
        if _G.GetMouseFoci then
            local ok, foci = pcall(_G.GetMouseFoci)
            if ok and (not _G.canaccessvalue or _G.canaccessvalue(foci)) and type(foci) == "table" then
                frame = foci[1]
                if _G.canaccessvalue and not _G.canaccessvalue(frame) then frame = nil end
            end
        else
            local ok, focus = pcall(_G.GetMouseFocus)
            if ok and (not _G.canaccessvalue or _G.canaccessvalue(focus)) then frame = focus end
        end
        if frame then
            local name = frame:GetName() or tostring(frame)
            self:Print("|cff00FFFFFrame:|r " .. name)
            self:Print("Size: " .. math.floor(frame:GetWidth()) .. "x" .. math.floor(frame:GetHeight()))
        else
            self:Print("No hay frame bajo el ratón.")
        end
    end)

    self:RegisterChatCommand("ktbaddebug", function()
        local function frameName(frame)
            if not frame then
                return "nil"
            end
            return (frame.GetDebugName and frame:GetDebugName())
                or (frame.GetName and frame:GetName())
                or tostring(frame)
        end

        local badLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("KullThranUI_BuffsAndDebuffs")) or false
        local mod = KT.GetModule and KT:GetModule("BuffsAndDebuffs", true)
        local buffContainer = _G.BuffFrame and _G.BuffFrame.AuraContainer
        local debuffContainer = _G.DebuffFrame and _G.DebuffFrame.AuraContainer

        KT:Print("|cff66ccff[ktbaddebug]|r addonLoaded=" .. tostring(badLoaded)
            .. " module=" .. tostring(mod ~= nil)
            .. " buffContainer=" .. frameName(buffContainer)
            .. " debuffContainer=" .. frameName(debuffContainer))

        if debuffContainer and debuffContainer.GetNumChildren then
            KT:Print("|cff66ccff[ktbaddebug]|r debuffChildren=" .. tostring(debuffContainer:GetNumChildren())
                .. " shown=" .. tostring(debuffContainer.IsShown and debuffContainer:IsShown()))
        elseif _G.DebuffFrame then
            KT:Print("|cff66ccff[ktbaddebug]|r DebuffFrame=" .. frameName(_G.DebuffFrame)
                .. " shown=" .. tostring(_G.DebuffFrame.IsShown and _G.DebuffFrame:IsShown()))
        else
            KT:Print("|cff66ccff[ktbaddebug]|r DebuffFrame=nil")
        end

        if mod and mod.RunAuraDebugSnapshots then
            mod:RunAuraDebugSnapshots()
        else
            KT:Print("|cff66ccff[ktbaddebug]|r BuffsAndDebuffs module debug not available.")
        end
    end)

    -- -----------------------------------------------------------------------
    -- /ktperf [segundos]
    -- Lee ns._perf que el módulo CDM popula con debugprofilestart/stop.
    -- -----------------------------------------------------------------------
    self:RegisterChatCommand("ktperf", function(args)
        local perf = ns._perf
        if not perf then
            KT_PerfPrint("|cffFF4444[ktperf]|r ns._perf no encontrado — ¿cargó KUICooldownManager?")
            return
        end
        if perf.capturing then
            KT_PerfPrint("|cffFFAA00[ktperf]|r Captura en curso, espera que termine.")
            return
        end
        local duration = math.max(1, math.min(tonumber(args) or 5, 60))
        perf.tickCount    = 0
        perf.totalMs      = 0
        perf.peakMs       = 0
        perf.bars         = {}
        perf.phases       = {}
        perf.phasePeaks   = {}
        perf.events       = {}
        perf.dirtyReasons = {}
        perf.skippedTicks = 0
        perf.lastTick     = {}
        perf.captureStart = GetTime()
        perf.captureDur   = duration
        perf.onDone       = function() KT:_PrintPerfReport(perf, duration) end
        perf.capturing    = true
        KT_PerfPrint("|cff00FF88[ktperf]|r Midiendo " .. duration .. "s... (espera el resultado)")
    end)

    -- -----------------------------------------------------------------------
    -- /ktcdmstats — Estado de cada barra CDM
    -- -----------------------------------------------------------------------
    self:RegisterChatCommand("ktcdmstats", function()
        KT:_PrintCDMStats()
    end)

    self:RegisterChatCommand("ktminimapperf", function(args)
        local duration = math.max(1, math.min(tonumber(args) or 5, 60))
        local minimapModule = KT_GetMinimapModule()
        if not minimapModule or type(minimapModule.StartPerfCapture) ~= "function" then
            KT_PerfPrint("|cffFF4444[ktminimapperf]|r módulo Minimap no disponible.")
            return
        end

        local ok = minimapModule:StartPerfCapture(duration, function(snapshot)
            KT:_PrintMinimapPerfReport(snapshot)
        end)
        if not ok then
            KT_PerfPrint("|cffFFAA00[ktminimapperf]|r Ya hay una captura en curso.")
            return
        end

        KT_PerfPrint("|cff00FF88[ktminimapperf]|r Midiendo " .. duration .. "s... (espera el resultado)")
    end)

    -- 7. Mostrar instalador (primer login / update)
    self:MaybeAutoOpenInstaller()

    if not self._installerReopenWatcher then
        local watcher = CreateFrame('Frame')
        watcher:RegisterEvent('PLAYER_ENTERING_WORLD')
        watcher:SetScript('OnEvent', function(frame)
            frame:UnregisterEvent('PLAYER_ENTERING_WORLD')
            C_Timer.After(1, function()
                local pendingInstaller = self.db and self.db.profile and self.db.profile.installer
                local shouldAutoOpen = pendingInstaller and pendingInstaller.dontShowAgain ~= true
                    and (pendingInstaller.forceOpenForCharacter or pendingInstaller.showOnLogin ~= false)
                if pendingInstaller and (pendingInstaller.reopenOnReload or pendingInstaller.reopenStep
                    or pendingInstaller.resumeStep or shouldAutoOpen) then
                    self:OpenInstaller()
                end
            end)
        end)
        self._installerReopenWatcher = watcher
    end

    local version = KT.VERSION or "5.0.9"
    local accentR, accentG, accentB = self:GetStyleAccentRGB()
    self:Print("Welcome to |cff" .. string.format("%02x%02x%02x", accentR * 255, accentG * 255, accentB * 255) .. "KullThranUI|r " .. version)
end

-- ============================================================================
-- 2. APPLY UI SCALE
-- ============================================================================
function KT:ApplyUIScale()
    if self._suppressApplyUIScale then return end
    if not (self.db and self.db.profile and _G.UIParent) then return end

    local scale = tonumber(self.db.profile.uiScale)
    local auto = (self.db.profile.autoResolutionScale ~= false)
    if auto or not scale then
        local _, height = GetPhysicalScreenSize()
        if height and height >= 2160 then
            scale = 0.35
        elseif height and height >= 1440 then
            scale = 0.53
        else
            scale = 0.71
        end
        self.db.profile.uiScale = scale
    end

    _G.UIParent:SetScale(scale)

    if _G.GameMenuFrame then
        C_Timer.After(0, function()
            local escapeMenu = KT.GetModule and KT:GetModule("EscapeMenu", true)
            if escapeMenu and escapeMenu.RequestRefresh then
                pcall(escapeMenu.RequestRefresh, escapeMenu)
            end
        end)
    end
end

-- ============================================================================
-- 3. WELCOME FRAME (Instalador)
-- ============================================================================
function KT:GetInstallerCharacterKey()
    local dbCharacterKey = self.db and self.db.keys and self.db.keys.char
    if type(dbCharacterKey) == "string" and dbCharacterKey ~= "" then
        return dbCharacterKey
    end

    local name = UnitName and UnitName("player")
    local realm = GetRealmName and GetRealmName()
    if name and name ~= "" and realm and realm ~= "" then
        return name .. " - " .. realm
    end

    return UnitGUID and UnitGUID("player") or nil
end
function KT:MaybeAutoOpenInstaller()
    if self._installerProfileChoiceInProgress then return end
    if not (self.db and self.db.profile) then return end

    local installerDb = self.db.profile.installer
    if type(installerDb) ~= "table" then
        installerDb = {}
        self.db.profile.installer = installerDb
    end

    -- isOpen describes the current UI session; it is not a persisted request
    -- to reopen after a reload. Also repair stale resume flags left by older
    -- versions when the user has explicitly disabled the Installer.
    if installerDb.dontShowAgain == true then
        installerDb.showOnLogin = false
        installerDb.reopenOnReload = nil
        installerDb.reopenStep = nil
        installerDb.resumeStep = nil
        installerDb.forceOpenForCharacter = nil
        installerDb.isOpen = false
    elseif not (installerDb.reopenOnReload or installerDb.reopenStep or installerDb.resumeStep) then
        installerDb.isOpen = false
    end

    local currentVersion = KT.VERSION or "5.0.9"
    local characterKey = self:GetInstallerCharacterKey()
    local legacyCharacterGUID = UnitGUID and UnitGUID("player")

    self.db.global = self.db.global or {}
    self.db.global.installerSeenByCharacter = self.db.global.installerSeenByCharacter or {}
    self.db.global.installerProfileChoicePendingByCharacter = self.db.global.installerProfileChoicePendingByCharacter or {}
    local installerSeen = self.db.global.installerSeenByCharacter
    local installerAlreadySeen
    if legacyCharacterGUID then
        installerAlreadySeen = installerSeen[legacyCharacterGUID]
    elseif characterKey then
        installerAlreadySeen = installerSeen[characterKey]
    end
    if characterKey and not installerAlreadySeen and installerDb.dontShowAgain ~= true then
        installerDb.showOnLogin = true
        installerDb.step = 1
        installerDb.forceOpenForCharacter = true
        self.db.global.installerProfileChoicePendingByCharacter[characterKey] = true
    end

    local function MaybeNotifyArchivedUpdate(version)
        local latestArchivedVersion = (KT.GetLatestArchivedChangelogVersion and KT:GetLatestArchivedChangelogVersion())
            or KT.CHANGELOG_LATEST_ARCHIVED_VERSION
        if type(latestArchivedVersion) ~= "string" or latestArchivedVersion == "" then
            installerDb.lastUpdateNoticeVersion = nil
            return
        end

        local compare = KT.CompareVersions and KT.CompareVersions(version, latestArchivedVersion)
        if type(compare) ~= "number" then
            installerDb.lastUpdateNoticeVersion = nil
            return
        end

        if false and compare < 0 then
            if installerDb.lastUpdateNoticeVersion ~= latestArchivedVersion then
                local L = KT:GetLocale() or {}
                local msg = L["A new KullThranUI version is available on Wago/CurseForge: %s. You are using %s."]
                    or "A new KullThranUI version is available on Wago/CurseForge: %s. You are using %s."
                local followup = L["Please update to get the latest fixes and features."]
                    or "Please update to get the latest fixes and features."
            end
        end
    end

    if installerDb.lastVersion ~= currentVersion then
        if installerDb.dontShowAgain ~= true then
            installerDb.showOnLogin = true
        end
        if not installerDb.reopenOnReload and not installerDb.reopenStep and not installerDb.resumeStep then
            installerDb.step = 1
        end
        installerDb.lastVersion = currentVersion
        self._loginPopupStep = 1
    end

    if installerDb.reopenOnReload or installerDb.reopenStep or installerDb.resumeStep then
        local pendingStep = tonumber(installerDb.reopenStep) or tonumber(installerDb.resumeStep)
        if pendingStep then
            installerDb.step = pendingStep
        end
    end
    if not self.ProcessLoginPopups then
        function self:ProcessLoginPopups(step)
            self._loginPopupStep = step or self._loginPopupStep or 1
            local instDb = self.db and self.db.profile and self.db.profile.installer
            if instDb and instDb.dontShowAgain ~= true
                and (instDb.reopenOnReload or instDb.reopenStep or instDb.resumeStep or instDb.forceOpenForCharacter) then
                self._loginPopupStep = 4
                if self.OpenInstaller then
                    self:OpenInstaller()
                end
                return
            end

            if self._loginPopupStep == 1 then
                -- Step 1: Conflict Detector
                self._loginPopupStep = 2
                local installer = self:GetModule("Installer", true)
                if installer and installer.CheckConflicts then
                    local conflicts = installer:CheckConflicts()
                    local cdb = self.db.profile.conflictDetector
                    local installerSuppressed = self.db.profile.installer
                        and self.db.profile.installer.dontShowAgain == true
                    if not installerSuppressed and conflicts and not (cdb and cdb.dontShowAgain) then
                        -- Show Conflict UI and wait
                        if installer.CreateInstallerWindow then
                            installer:CreateInstallerWindow(true)
                        end
                        return
                    end
                end
            end

            if self._loginPopupStep == 2 then
                -- Step 2: Changelog
                self._loginPopupStep = 3
                self.db.global = self.db.global or {}
                self.db.global.changelog = self.db.global.changelog or {}
                local changelogDb = self.db.global.changelog
                local currentVer = KT.VERSION or "0"
                local suppressed = self.IsChangelogPatchSuppressed
                    and self:IsChangelogPatchSuppressed(currentVer)
                if not suppressed then
                    -- Compatibility with databases written before version keys
                    -- were normalized and before the per-version dismissal map.
                    suppressed = changelogDb.lastAutoShownVersion == currentVer
                        or changelogDb.lastDismissedVersion == currentVer
                        or (type(changelogDb.dismissedVersions) == "table"
                            and changelogDb.dismissedVersions[currentVer] == true)
                end
                if not suppressed then
                    if self.ShowChangelogPopup then
                        local ok = pcall(self.ShowChangelogPopup, self, currentVer)
                        if ok then
                            return
                        end
                    end
                end
            end

            if self._loginPopupStep == 3 then
                -- Step 3: Installer
                self._loginPopupStep = 4
                local instDb = self.db and self.db.profile and self.db.profile.installer
                if instDb and instDb.dontShowAgain ~= true
                    and (instDb.showOnLogin or instDb.reopenOnReload or instDb.reopenStep or instDb.resumeStep or instDb.forceOpenForCharacter) then
                    if self.OpenInstaller then
                        self:OpenInstaller()
                    end
                end
            end
        end
    end

    installerDb.pendingChangelogVersion = nil
    installerDb.suppressChangelogAutoPopup = nil

    C_Timer.After(2, function()
        local pendingInstaller = self.db and self.db.profile and self.db.profile.installer
        if pendingInstaller and pendingInstaller.dontShowAgain ~= true
            and (pendingInstaller.reopenOnReload or pendingInstaller.reopenStep or pendingInstaller.resumeStep) then
            self:OpenInstaller()
            return
        end
        if KT and KT.ProcessLoginPopups then
            KT:ProcessLoginPopups()
        end
    end)

    -- Loading the optional Installer can finish after the first login pass.
    -- Retry while an explicit resume or a permitted automatic open is pending.
    C_Timer.After(5, function()
        local pendingInstaller = self.db and self.db.profile and self.db.profile.installer
        if not pendingInstaller then
            return
        end
        local shouldAutoOpen = pendingInstaller.dontShowAgain ~= true
            and (pendingInstaller.forceOpenForCharacter or pendingInstaller.showOnLogin ~= false)
        if not (pendingInstaller.reopenOnReload or pendingInstaller.reopenStep or pendingInstaller.resumeStep or shouldAutoOpen) then return end
        local installer = self:GetModule('Installer', true)
        if not installer or not installer.frame or not installer.frame.IsShown or not installer.frame:IsShown() then
            self:OpenInstaller()
        end
    end)
end
function KT:_KT_OnInstallerRegenEnabled()
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self._ktInstallerRegenHooked = nil

    if self._ktPendingInstallerOpen then
        self._ktPendingInstallerOpen = nil
        self:OpenInstaller()
    end
end

function KT:OpenInstaller()
    if InCombatLockdown and InCombatLockdown() then
        self._ktPendingInstallerOpen = true
        if not self._ktInstallerRegenHooked then
            self._ktInstallerRegenHooked = true
            self:RegisterEvent("PLAYER_REGEN_ENABLED", "_KT_OnInstallerRegenEnabled")
        end
        return
    end

    local installerAddon = "KullThranUI_Installer"
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(installerAddon))
        or (IsAddOnLoaded and IsAddOnLoaded(installerAddon))

    if not loaded then
        local ok, reason
        if C_AddOns and C_AddOns.LoadAddOn then
            ok, reason = C_AddOns.LoadAddOn(installerAddon)
        elseif LoadAddOn then
            ok, reason = LoadAddOn(installerAddon)
        else
            ok, reason = false, "LoadAddOn unavailable"
        end

        if not ok then
            if self.Print then
                self:Print("|cffFF4444Installer|r: no se pudo cargar (" .. tostring(reason) .. ").")
            end
            return
        end
    end

    local installerDb = self.db and self.db.profile and self.db.profile.installer
    local pendingStep = installerDb and (tonumber(installerDb.reopenStep) or tonumber(installerDb.resumeStep))
    if installerDb and pendingStep then
        installerDb.step = pendingStep
    end
    local installer = self:GetModule("Installer", true)
    if installer and installer.CreateInstallerWindow then
        installer:CreateInstallerWindow()

        local installerShown = installer.frame
            and installer.frame.IsShown
            and installer.frame:IsShown()
        if not installerShown then
            return
        end

        if self.db.profile and self.db.profile.installer then
            if pendingStep then
                self.db.profile.installer.step = pendingStep
            end
        end

        self.db.global = self.db.global or {}
        self.db.global.installerSeenByCharacter = self.db.global.installerSeenByCharacter or {}
        local characterKey = self:GetInstallerCharacterKey()
        local legacyCharacterGUID = UnitGUID and UnitGUID("player")
        if characterKey then
            self.db.global.installerSeenByCharacter[characterKey] = true
        end
        if legacyCharacterGUID then
            self.db.global.installerSeenByCharacter[legacyCharacterGUID] = true
        end
        if self.db.profile and self.db.profile.installer then
            self.db.profile.installer.forceOpenForCharacter = nil
        end
        return
    end

    if self.Print then
        self:Print("|cffFF4444Installer|r: módulo no disponible tras cargar.")
    end
end

function KT:ShowWelcomeFrame()
    if KT.WelcomeFrame then
        local accentR, accentG, accentB = KT:GetStyleAccentRGB()
        if KT.WelcomeFrame._logoTex then
            KT.WelcomeFrame._logoTex:SetVertexColor(accentR, accentG, accentB, 1)
        end
        KT.WelcomeFrame:Show()
        return
    end

    local L = KT:GetLocale()
    local accentR, accentG, accentB = KT:GetStyleAccentRGB()

    local f = CreateFrame("Frame", "KullThranWelcome", UIParent)
    f:SetSize(800, 500)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    KT:AddBackdrop(f, KT.BG_COLOR)
    KT:AddBorder(f, accentR, accentG, accentB, 0.7)

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetSize(84, 84)
    logo:SetPoint("TOP", f, "TOP", 0, -60)
    logo:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png")
    if logo.SetDesaturated then
        logo:SetDesaturated(true)
    end
    logo:SetVertexColor(accentR, accentG, accentB, 1)
    f._logoTex = logo

    local titleStr = (L["Welcome to"] or "Welcome to")
    local title    = f:CreateFontString(nil, "OVERLAY")
    title:SetFont(CurrentFontPath(), 28, "OUTLINE")
    title:SetPoint("TOP", logo, "BOTTOM", 0, -18)
    title:SetText(titleStr .. " |cff" ..
        string.format("%02x%02x%02x", accentR * 255, accentG * 255, accentB * 255) .. "KullThranUI|r")
    title:SetTextColor(1, 1, 1, 1)

    local descText = L["Below a list of highly recommended addons will open to embed them\ninto the interface and avoid errors."]
                     or "Below a list of highly recommended addons will open\nto embed them into the interface."
    local desc = f:CreateFontString(nil, "OVERLAY")
    desc:SetFont(CurrentFontPath(), 14)
    desc:SetPoint("TOP", title, "BOTTOM", 0, -18)
    desc:SetText(descText)
    desc:SetTextColor(0.70, 0.70, 0.70, 1)
    desc:SetJustifyH("CENTER")

    local btnSkip = CreateFrame("Button", nil, f)
    btnSkip:SetSize(140, 38)
    btnSkip:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 40, 40)
    KT:AddBackdrop(btnSkip, 0.08, 0.08, 0.11, 1)
    KT:AddBorder(btnSkip, 0.4, 0.4, 0.4, 0.7)
    local skipLbl = btnSkip:CreateFontString(nil, "OVERLAY")
    skipLbl:SetFont(CurrentFontPath(), 12, "OUTLINE")
    skipLbl:SetText(L["Skip Install"] or "Skip Install")
    skipLbl:SetTextColor(0.75, 0.75, 0.75, 1)
    skipLbl:SetAllPoints(); skipLbl:SetJustifyH("CENTER"); skipLbl:SetJustifyV("MIDDLE")
    btnSkip:SetScript("OnClick", function()
        f:Hide()
        if KT.db then KT.db.profile.installer.showOnLogin = false end
    end)
    btnSkip:SetScript("OnEnter", function(s) KT:AddBorder(s, 0.7, 0.7, 0.7, 1) end)
    btnSkip:SetScript("OnLeave", function(s) KT:AddBorder(s, 0.4, 0.4, 0.4, 0.7) end)

    local btnNext = CreateFrame("Button", nil, f)
    btnNext:SetSize(160, 38)
    btnNext:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -40, 40)
    KT:AddBackdrop(btnNext, 0.08, 0.08, 0.11, 1)
    KT:AddBorder(btnNext, accentR, accentG, accentB, 0.8)
    local nextLbl = btnNext:CreateFontString(nil, "OVERLAY")
    nextLbl:SetFont(CurrentFontPath(), 12, "OUTLINE")
    nextLbl:SetText(L["Next Step"] or "Configure KullThranUI")
    nextLbl:SetTextColor(1, 1, 1, 1)
    nextLbl:SetAllPoints(); nextLbl:SetJustifyH("CENTER"); nextLbl:SetJustifyV("MIDDLE")
    btnNext:SetScript("OnClick", function()
        f:Hide()
        if KT.db then KT.db.profile.installer.showOnLogin = false end
        KT:ToggleConfig()
    end)
    btnNext:SetScript("OnEnter", function(s) KT:AddBorder(s, accentR, accentG, accentB, 1) end)
    btnNext:SetScript("OnLeave", function(s) KT:AddBorder(s, accentR, accentG, accentB, 0.8) end)

    KT.WelcomeFrame = f
end

-- ============================================================================
-- 4. PERF REPORT  (llamado por ns._perf.onDone desde el módulo CDM)
-- ============================================================================
function KT:_PrintPerfReport(perf, duration)
    self = { Print = function(_, ...) KT_PerfPrint(...) end }
    local cdmNs = KT_GetCDMNamespace()
    local function c(hex, txt) return "|cff" .. hex .. txt .. "|r" end
    local sep = c("555555", "--------------------------------------")

    self:Print(sep)
    self:Print(c("00FF88", "[ktperf] Resultado " .. duration .. "s"))
    self:Print(sep)

    if perf.tickCount == 0 then
        self:Print(c("FF4444", "Sin ticks capturados. ¿El módulo CDM está habilitado?"))
        return
    end

    local avgMs  = perf.totalMs / perf.tickCount
    local tickHz = perf.tickCount / duration
    local cpuPct = (perf.totalMs / (duration * 1000)) * 100
    local cpuCol = cpuPct > 2 and "FF4444" or cpuPct > 0.5 and "FFAA00" or "00FF88"
    local skipped = tonumber(perf.skippedTicks) or 0

    self:Print(string.format("%s  ticks: %d  (%.1f/s)",
        c("FFCC00", "CDM tick"), perf.tickCount, tickHz))
    self:Print(string.format("  avg %.4f ms  |  pico %s  |  total %.1f ms",
        avgMs,
        c("FF8800", string.format("%.4f ms", perf.peakMs)),
        perf.totalMs))
    self:Print(string.format("  %s %d",
        c("888888", "ticks saltados:"), skipped))
    self:Print(string.format("  %s %s  (del total del addon)",
        c("FFCC00", "CPU estimado CDM:"),
        c(cpuCol, string.format("%.3f%%", cpuPct))))
    if perf.lastTick and next(perf.lastTick) then
        self:Print(string.format("  %s barras=%d  iconos=%d/%d  mouse-track=%d  skipped=%s",
            c("888888", "último tick:"),
            tonumber(perf.lastTick.enabledBars) or 0,
            tonumber(perf.lastTick.visibleIcons) or 0,
            tonumber(perf.lastTick.totalIcons) or 0,
            tonumber(perf.lastTick.mouseTrackedBars) or 0,
            tostring(perf.lastTick.skipped and "yes" or "no")
        ))
    end

    if perf.phases and next(perf.phases) then
        self:Print(sep)
        self:Print(c("88FFFF", "Fases del tick:"))
        local phases = {}
        for key, totalMs in pairs(perf.phases) do
            phases[#phases + 1] = {
                key = key,
                totalMs = totalMs,
                peakMs = (perf.phasePeaks and perf.phasePeaks[key]) or 0,
            }
        end
        table.sort(phases, function(a, b) return a.totalMs > b.totalMs end)
        for i = 1, math.min(6, #phases) do
            local row = phases[i]
            self:Print(string.format("  %s  total %.3f ms  pico %.3f ms",
                c("FFCC00", row.key), row.totalMs, row.peakMs))
        end
    end

    if perf.dirtyReasons and next(perf.dirtyReasons) then
        self:Print(sep)
        self:Print(c("88FFFF", "Dirty reasons:"))
        local reasons = {}
        for key, count in pairs(perf.dirtyReasons) do
            reasons[#reasons + 1] = { key = key, count = count }
        end
        table.sort(reasons, function(a, b) return a.count > b.count end)
        for i = 1, math.min(6, #reasons) do
            local row = reasons[i]
            self:Print(string.format("  %s  x%d", c("FFCC00", row.key), row.count))
        end
    end

    -- Desglose por barra, ordenado por coste
    if next(perf.bars) then
        self:Print(sep)
        self:Print(c("88FFFF", "Desglose por barra:"))
        local sorted = {}
        for k, v in pairs(perf.bars) do sorted[#sorted + 1] = { key = k, b = v } end
        table.sort(sorted, function(a, b) return a.b.totalMs > b.b.totalMs end)

        for _, entry in ipairs(sorted) do
            local k, b = entry.key, entry.b
            local bavg = b.ticks > 0 and (b.totalMs / b.ticks) or 0
            local bpct = (b.totalMs / (duration * 1000)) * 100
            local bcol = bpct > 1 and "FF4444" or bpct > 0.3 and "FFAA00" or "AAAAAA"
            local nIcons = tonumber(b.visibleIcons) or 0
            local totalIcons = tonumber(b.totalIcons) or 0
            local topSource, topSourceMs = nil, 0
            if b.sources then
                for sourceKey, sourceMs in pairs(b.sources) do
                    if sourceMs > topSourceMs then
                        topSource = sourceKey
                        topSourceMs = sourceMs
                    end
                end
            end
            self:Print(string.format("  %s  avg %.4f ms  pico %.4f ms  %s  (%d/%d iconos)%s",
                c(bcol, string.format("%-14s", k)),
                bavg, b.peakMs,
                c(bcol, string.format("%.3f%%", bpct)),
                nIcons,
                totalIcons,
                topSource and ("  src=" .. topSource) or ""))
        end
    end

    -- Advertencia mouse-track (corre OnUpdate cada frame, muy costoso)
    local mouseTrack = {}
    if cdmNs and cdmNs.cdmBarFrames then
        for k, frame in pairs(cdmNs.cdmBarFrames) do
            if frame._mouseTrack then mouseTrack[#mouseTrack + 1] = k end
        end
    end
    if #mouseTrack > 0 then
        self:Print(sep)
        self:Print(c("FF4444", "ALERTA: barras con mouse-tracking (OnUpdate CADA FRAME):"))
        for _, k in ipairs(mouseTrack) do
            self:Print("  " .. c("FF8800", k) .. " — corre ~60 veces/s, no 10 veces/s")
        end
    end

    self:Print(sep)
    self:Print(c("888888", "Usa /ktcdmstats para ver anchorTo/tamaños/iconos"))
end

-- ============================================================================
-- 5. CDM STATS
-- ============================================================================
-- ============================================================================
-- CPU DEBUG (/ktcpu)
-- ============================================================================
local function KT_CPUProfileEnabled()
    if not _G.GetCVar then
        return false
    end
    return tonumber(_G.GetCVar("scriptProfile") or 0) == 1
end

local function KT_CPUGetNumAddOns()
    if _G.C_AddOns and _G.C_AddOns.GetNumAddOns then
        return _G.C_AddOns.GetNumAddOns()
    end
    return _G.GetNumAddOns and _G.GetNumAddOns() or 0
end

local function KT_CPUGetAddOnName(index)
    if _G.GetAddOnInfo then
        return _G.GetAddOnInfo(index)
    end
    if _G.C_AddOns and _G.C_AddOns.GetAddOnInfo then
        return _G.C_AddOns.GetAddOnInfo(index)
    end
    return nil
end

local function KT_CPUIsAddOnLoaded(indexOrName)
    if _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded then
        return _G.C_AddOns.IsAddOnLoaded(indexOrName)
    end
    if _G.IsAddOnLoaded then
        return _G.IsAddOnLoaded(indexOrName)
    end
    return false
end

local function KT_CPUTrim(value)
    value = tostring(value or "")
    if _G.strtrim then
        return _G.strtrim(value)
    end
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function KT:_CPUGetSnapshot()
    if _G.UpdateAddOnCPUUsage then
        _G.UpdateAddOnCPUUsage()
    end

    local num = KT_CPUGetNumAddOns()
    local rows = {}
    local total = 0

    for i = 1, num do
        local name = KT_CPUGetAddOnName(i)
        if name and KT_CPUIsAddOnLoaded(i) then
            local ms = (_G.GetAddOnCPUUsage and _G.GetAddOnCPUUsage(i)) or 0
            ms = tonumber(ms) or 0
            total = total + ms
            rows[#rows + 1] = { index = i, name = name, ms = ms }
        end
    end

    table.sort(rows, function(a, b) return a.ms > b.ms end)

    local byName = {}
    for _, row in ipairs(rows) do
        byName[row.name] = row.ms
    end

    return {
        time = _G.GetTime and _G.GetTime() or 0,
        rows = rows,
        total = total,
        byName = byName,
    }
end

function KT:_CPUPrintTop(limit, prefix)
    local function c(hex, txt) return "|cff" .. hex .. txt .. "|r" end
    local sep = c("555555", "--------------------------------------")

    if not KT_CPUProfileEnabled() then
        self:Print(sep)
        self:Print(c("FF4444", "[ktcpu] scriptProfile desactivado."))
        self:Print("  Activa: " .. c("FFCC00", "/console scriptProfile 1"))
        self:Print("  Luego reinicia el juego (o vuelve a pantalla de personaje) y usa /ktcpu reset.")
        self:Print(sep)
        return
    end

    local snap = self:_CPUGetSnapshot()
    local rows, total = snap.rows, snap.total
    limit = math.max(1, math.min(tonumber(limit) or 15, #rows))
    prefix = prefix or "[ktcpu]"

    self:Print(sep)
    self:Print(c("00FF88", prefix .. " Top " .. limit .. " addons por CPU (desde último reset)"))

    local elapsedText = nil
    if self._cpuLastResetAt and snap.time and snap.time >= self._cpuLastResetAt then
        local elapsed = snap.time - self._cpuLastResetAt
        elapsedText = string.format(" (%.0fs)", elapsed)
    end
    self:Print(c("888888", "Total CPU addons: " .. string.format("%.1f ms", total) .. (elapsedText or "")))
    self:Print(sep)

    for n = 1, limit do
        local row = rows[n]
        local pct = total > 0 and (row.ms / total) * 100 or 0
        local col = pct > 20 and "FF4444" or pct > 8 and "FFAA00" or "AAAAAA"
        self:Print(string.format("  %s  %s  %s",
            c("888888", string.format("%2d.", n)),
            c("88FFFF", string.format("%-28s", row.name)),
            c(col, string.format("%8.1f ms  (%5.1f%%)", row.ms, pct))
        ))
    end
end

function KT:_CPUStopWatch(silent)
    if self._cpuWatch and self._cpuWatch.timer and self.CancelTimer then
        self:CancelTimer(self._cpuWatch.timer)
    end
    self._cpuWatch = nil
    if not silent then
        self:Print("|cff00FF88[ktcpu]|r watch detenido.")
    end
end

function KT:_CPUStartWatch(interval, topN)
    if not KT_CPUProfileEnabled() then
        self:_CPUPrintTop(topN or 15)
        return
    end

    interval = tonumber(interval) or 5
    interval = math.max(1, math.min(interval, 60))
    topN = tonumber(topN) or 8
    topN = math.max(1, math.min(topN, 25))

    self:_CPUStopWatch(true)
    self._cpuWatch = {
        interval = interval,
        topN = topN,
        last = self:_CPUGetSnapshot(),
    }

    local function tick()
        local state = self._cpuWatch
        if not state then
            return
        end

        local now = self:_CPUGetSnapshot()
        local prev = state.last
        state.last = now

        local deltas = {}
        local totalDelta = 0
        for name, ms in pairs(now.byName) do
            local before = prev.byName[name] or 0
            local d = ms - before
            if d > 0 then
                totalDelta = totalDelta + d
                deltas[#deltas + 1] = { name = name, ms = d }
            end
        end

        table.sort(deltas, function(a, b) return a.ms > b.ms end)

        local function c(hex, txt) return "|cff" .. hex .. txt .. "|r" end
        local perSec = (state.interval > 0) and (totalDelta / state.interval) or 0
        self:Print(c("00FF88", string.format("[ktcpu] Delta CPU ultimos %.0fs: %.1f ms (%.2f ms/s)", state.interval, totalDelta, perSec)))

        local shown = 0
        for _, row in ipairs(deltas) do
            if shown >= state.topN then
                break
            end
            local col = row.ms >= 30 and "FF4444" or row.ms >= 10 and "FFAA00" or "AAAAAA"
            self:Print(string.format("  %s  %s",
                c("88FFFF", string.format("%-28s", row.name)),
                c(col, string.format("%8.1f ms", row.ms))
            ))
            shown = shown + 1
        end

        if shown == 0 then
            self:Print(c("888888", "  (sin cambios de CPU apreciables en este intervalo)"))
        end
    end

    if self.ScheduleRepeatingTimer then
        self._cpuWatch.timer = self:ScheduleRepeatingTimer(tick, interval)
        self:Print("|cff00FF88[ktcpu]|r watch iniciado (" .. interval .. "s, top " .. topN .. "). Usa /ktcpu stop para parar.")
    else
        self:Print("|cffFF4444[ktcpu]|r AceTimer no disponible; no se puede iniciar watch.")
    end
end

function KT:_HandleCPUCommand(args)
    args = KT_CPUTrim(args)

    local cmd, rest = args:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" then
        self:_CPUPrintTop(15)
        return
    end

    if cmd == "top" then
        self:_CPUPrintTop(tonumber(rest) or 15)
        return
    end

    if cmd == "reset" then
        if not KT_CPUProfileEnabled() then
            self:_CPUPrintTop(15)
            return
        end
        if _G.ResetCPUUsage then
            _G.ResetCPUUsage()
            if _G.UpdateAddOnCPUUsage then
                _G.UpdateAddOnCPUUsage()
            end
            self._cpuLastResetAt = _G.GetTime and _G.GetTime() or nil
            self:Print("|cff00FF88[ktcpu]|r contadores CPU reseteados.")
        else
            self:Print("|cffFF4444[ktcpu]|r ResetCPUUsage no disponible.")
        end
        return
    end

    if cmd == "watch" then
        local interval, topN = rest:match("^(%S+)%s*(%S*)$")
        self:_CPUStartWatch(interval, topN)
        return
    end

    if cmd == "stop" then
        self:_CPUStopWatch()
        return
    end

    self:Print("|cff00FF88[ktcpu]|r uso:")
    self:Print("  /ktcpu            (top 15)")
    self:Print("  /ktcpu top 25     (top N)")
    self:Print("  /ktcpu reset      (resetea contadores)")
    self:Print("  /ktcpu watch 5 8  (cada 5s, top 8 deltas)")
    self:Print("  /ktcpu stop       (para watch)")
end

function KT:_PrintCDMStats()
    self = { Print = function(_, ...) KT_PerfPrint(...) end }
    local cdmNs = KT_GetCDMNamespace()
    local function c(hex, txt) return "|cff" .. hex .. txt .. "|r" end
    local sep = c("555555", "--------------------------------------")

    self:Print(sep)
    self:Print(c("00FF88", "[ktcdmstats] Estado CDM"))
    self:Print(sep)

    local p = KT.db and KT.db.profile.cooldownManager
    if not p or not p.cdmBars or not p.cdmBars.bars then
        self:Print(c("FF4444", "cooldownManager no inicializado"))
        return
    end

    local perf = cdmNs and cdmNs._perf
    if perf and perf.lastTick and next(perf.lastTick) then
        self:Print(string.format("último tick: barras=%d  iconos=%d/%d  mouse-track=%d  skipped=%s",
            tonumber(perf.lastTick.enabledBars) or 0,
            tonumber(perf.lastTick.visibleIcons) or 0,
            tonumber(perf.lastTick.totalIcons) or 0,
            tonumber(perf.lastTick.mouseTrackedBars) or 0,
            tostring(perf.lastTick.skipped and "yes" or "no")
        ))
    end

    for _, barData in ipairs(p.cdmBars.bars) do
        local k     = barData.key
        local frame = cdmNs and cdmNs.cdmBarFrames and cdmNs.cdmBarFrames[k]
        local icons = cdmNs and cdmNs.cdmBarIcons and cdmNs.cdmBarIcons[k]
        local nShown, nTotal = 0, icons and #icons or 0
        if icons then
            for _, ic in ipairs(icons) do if ic:IsShown() then nShown = nShown + 1 end end
        end

        -- Frame info
        local fInfo = c("FF4444", "no frame")
        if frame then
            local fw = math.floor(frame:GetWidth()  + 0.5)
            local fh = math.floor(frame:GetHeight() + 0.5)
            local fa = frame:GetAlpha()
            local pt, fx, fy = "?", 0, 0
            if frame:GetNumPoints() > 0 then
                local _, relFrame, _, ox, oy = frame:GetPoint(1)
                pt = _
                fx = math.floor((ox or 0) + 0.5)
                fy = math.floor((oy or 0) + 0.5)
                local relName = relFrame and (relFrame.GetName and relFrame:GetName() or tostring(relFrame)) or "UIParent"
                fInfo = string.format("%dx%d  α=%.2f  %s→%s(%d,%d)",
                    fw, fh, fa, pt, relName, fx, fy)
            else
                fInfo = string.format("%dx%d  α=%.2f  sin anchor", fw, fh, fa)
            end
        end

        -- Anchor config
        local anchorDesc
        if not barData.anchorTo or barData.anchorTo == "none" then
            anchorDesc = c("888888", "libre (posición guardada)")
        else
            anchorDesc = string.format("anchorTo=%s  pos=%s  gap=%s",
                c("FFCC00", barData.anchorTo),
                barData.anchorPosition or "?",
                tostring(barData.anchorGap or "?"))
        end

        local stateCol = barData.enabled and "00FF88" or "FF4444"
        local mtFlag   = (frame and frame._mouseTrack) and c("FF4444", " [MOUSE-TRACK!]") or ""

        self:Print(string.format("%s [%s]  icons %d/%d  %s%s",
            c("FFCC00", string.format("%-14s", k)),
            c(stateCol, barData.enabled and "ON" or "OFF"),
            nShown, nTotal, anchorDesc, mtFlag))
        self:Print("    " .. fInfo)

        if barData.trackedSpells then
            self:Print("    mode:" .. c("88FFFF", "tracked") .. " " .. #barData.trackedSpells .. " IDs")
        elseif barData.customSpells then
            self:Print("    mode:" .. c("88FFFF", "custom") .. " " .. #barData.customSpells .. " spells")
        else
            self:Print("    mode:" .. c("FFAA00", "blizzard-mirror"))
        end
    end

    -- Tick frame
    local cdm = cdmNs and cdmNs.CDM
    local tf   = (cdm and cdm._cdmTickFrame)
        or (cdmNs and cdmNs.initFrame and cdmNs.initFrame._cdmTickFrame)
        or (_G.KUI_CDM and _G.KUI_CDM._cdmTickFrame)
    self:Print(sep)
    if tf then
        self:Print("_cdmTickFrame: " ..
            (tf:IsShown() and c("00FF88","activo") or c("FF4444","inactivo")) ..
            "  interval=0.1s")
    else
        self:Print(c("FF4444", "_cdmTickFrame no encontrado"))
    end
    self:Print(sep)
end

function KT:_PrintMinimapPerfReport(snapshot)
    self = { Print = function(_, ...) KT_PerfPrint(...) end }
    local function c(hex, txt) return "|cff" .. hex .. txt .. "|r" end
    local sep = c("555555", "--------------------------------------")

    if type(snapshot) ~= "table" then
        self:Print("|cffFF4444[ktminimapperf]|r snapshot no disponible.")
        return
    end

    self:Print(sep)
    self:Print(c("00FF88", string.format("[ktminimapperf] Resultado %.0fs", tonumber(snapshot.duration) or 0)))
    self:Print(sep)
    self:Print(string.format("  ticker ticks: %d  |  ticker activo: %s",
        tonumber(snapshot.tickerTicks) or 0,
        tostring(snapshot.tickerActive and "yes" or "no")))
    self:Print(string.format("  memoria: %.1f KB -> %.1f KB  (delta %.1f KB)",
        tonumber(snapshot.memoryStartKB) or 0,
        tonumber(snapshot.memoryEndKB) or 0,
        tonumber(snapshot.memoryDeltaKB) or 0))
    self:Print(string.format("  mapCoordCache: %d  (delta %d)  |  overlay buttons: %d",
        tonumber(snapshot.mapCoordCacheEntries) or 0,
        tonumber(snapshot.mapCoordCacheDelta) or 0,
        tonumber(snapshot.overlayButtonsCreated) or 0))

    local runtime = snapshot.legacyMinimapStats or {}
    self:Print(string.format("  MinimapStats runtime: disabled=%s  shown=%d  onUpdate=%d  onEvent=%d",
        tostring(runtime.runtimeDisabled and "yes" or "no"),
        tonumber(runtime.shownFrames) or 0,
        tonumber(runtime.onUpdateFrames) or 0,
        tonumber(runtime.onEventFrames) or 0))

    local keys = { "UpdateDynamicStats", "UpdateCoords", "UpdatePerformance", "UpdateOverlayVisibility" }
    local hadRows = false
    for _, key in ipairs(keys) do
        local count = snapshot.counts and snapshot.counts[key]
        local totalMs = snapshot.totals and snapshot.totals[key]
        if count and totalMs then
            if not hadRows then
                hadRows = true
                self:Print(sep)
                self:Print(c("88FFFF", "Muestras:"))
            end
            self:Print(string.format("  %s  calls=%d  total=%.3f ms  avg=%.3f ms  pico=%.3f ms",
                c("FFCC00", key),
                count,
                totalMs,
                count > 0 and (totalMs / count) or 0,
                (snapshot.peaks and snapshot.peaks[key]) or 0
            ))
            local callers = snapshot.callers and snapshot.callers[key]
            if callers and next(callers) then
                local sortedCallers = {}
                for callerKey, callerCount in pairs(callers) do
                    sortedCallers[#sortedCallers + 1] = { key = callerKey, count = callerCount }
                end
                table.sort(sortedCallers, function(a, b) return a.count > b.count end)
                for i = 1, math.min(3, #sortedCallers) do
                    local row = sortedCallers[i]
                    self:Print(string.format("    caller %s x%d",
                        c("888888", tostring(row.key)),
                        tonumber(row.count) or 0
                    ))
                end
            end
        end
    end
end
