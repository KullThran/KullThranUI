local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local hooksecurefunc, pairs, select, ipairs = hooksecurefunc, pairs, select, ipairs
local gsub, strfind = string.gsub, string.find
local C_QuestLog = C_QuestLog
local tonumber = tonumber

local FONT_AVANT    = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local FONT_FALLBACK = "Fonts\\FRIZQT__.TTF"

local DisableBackdrop
local SkinQuestFrame

local function KT_CanAccessValue(value)
    if value == nil then return false end

    if type(issecretvalue) == "function" then
        local ok, isSecret = pcall(issecretvalue, value)
        if not ok or isSecret then return false end
    end

    if type(canaccessvalue) == "function" then
        local ok, canAccess = pcall(canaccessvalue, value)
        if not ok or canAccess ~= true then return false end
    end

    return true
end

local function KT_GetAccessibleText(fontString)
    if not (fontString and fontString.GetText) then return nil end

    local ok, text = pcall(fontString.GetText, fontString)
    if not ok or type(text) ~= "string" or not KT_CanAccessValue(text) then
        return nil
    end

    return text
end

local function HideTexture(texture)
    if not texture then return end

    if texture._ktQuestHidingTexture then return end
    texture._ktQuestHidingTexture = true
    if texture.SetTexture then texture:SetTexture(nil) end
    if texture.SetAtlas then pcall(texture.SetAtlas, texture, nil) end
    if texture.SetAlpha then texture:SetAlpha(0) end
    texture._ktQuestHidingTexture = nil

    if not texture._ktQuestTextureHooked then
        if texture.SetTexture then
            hooksecurefunc(texture, "SetTexture", function(self)
                HideTexture(self)
            end)
        end
        if texture.SetAtlas then
            hooksecurefunc(texture, "SetAtlas", function(self)
                HideTexture(self)
            end)
        end
        if texture.SetAlpha then
            hooksecurefunc(texture, "SetAlpha", function(self, alpha)
                if alpha and alpha > 0 then
                    HideTexture(self)
                end
            end)
        end
        texture._ktQuestTextureHooked = true
    end
end

local function HideFrameTextures(frame, deep)
    if not (frame and frame.GetRegions) then return end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            HideTexture(region)
        end
    end

    for _, key in ipairs({
        "Bg", "Background", "Inset", "NineSlice", "SealMaterialBG",
        "TopLeft", "TopRight", "BottomLeft", "BottomRight",
        "TopBorder", "BottomBorder", "LeftBorder", "RightBorder",
    }) do
        HideTexture(frame[key])
    end

    if deep and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            if child and child.IsObjectType and not child:IsObjectType("Button") then
                HideFrameTextures(child, true)
                if DisableBackdrop then
                    DisableBackdrop(child)
                end
            end
        end
    end
end

DisableBackdrop = function(frame)
    if not frame or not frame.backdrop then return end

    frame.backdrop:SetAlpha(0)
    if frame.backdrop.SetBackdropColor then
        frame.backdrop:SetBackdropColor(0, 0, 0, 0)
    end
    if frame.backdrop.SetBackdropBorderColor then
        frame.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

local function EnsureUniformPanel(frame, key, left, top, right, bottom)
    if not frame then return end

    key = key or "_ktQuestUniformPanel"
    local texture = frame[key]
    if texture then
        texture:SetAlpha(0)
        texture:Hide()
    end
end

local function ApplyReadableShadow(fs)
    if not fs then return end
    if fs.SetShadowColor then
        fs:SetShadowColor(0, 0, 0, 0.95)
    end
    if fs.SetShadowOffset then
        fs:SetShadowOffset(1, -1)
    end
end

local function SetBodyFont(fs)
    if not (fs and fs.IsObjectType and fs:IsObjectType("FontString")) then return end
    local _, size = fs:GetFont()
    size = (size and size > 0) and size or 12
    if not fs:SetFont(FONT_AVANT, size, "") then
        fs:SetFont(FONT_FALLBACK, size, "")
    end
end

local function SmartReplaceToWhite(hex)
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    if (r + g + b) < 600 then return "|cffffffff" end
    return "|cff"..hex
end

local function SmartReplaceToGold(hex)
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    if (r + g + b) < 600 then return "|cffffd100" end
    return "|cff"..hex
end

local function IsDarkRGB(r, g, b)
    if r == nil or g == nil or b == nil then return false end
    return (r + g + b) < 0.65
end

local function FixQuestFontIfDark(fontString, useGold)
    if not fontString or not fontString.SetTextColor then return end

    ApplyReadableShadow(fontString)

    if fontString.GetTextColor then
        local r, g, b = fontString:GetTextColor()
        if IsDarkRGB(r, g, b) then
            if useGold then
                fontString:SetTextColor(1, 0.82, 0, 1)
            else
                fontString:SetTextColor(1, 1, 1, 1)
            end
        end
    end

    local text = KT_GetAccessibleText(fontString)
    if text then
        local replacer = useGold and SmartReplaceToGold or SmartReplaceToWhite
        local cleaned, count = gsub(text, "|c[fF][fF](%x%x%x%x%x%x)", replacer)
        if count > 0 and cleaned ~= text then
            fontString:SetText(cleaned)
        end
    end

    -- [FIX] Persistir formateo: como en spellbook, instalar hooks para que
    -- Blizzard no pueda resetear colores oscuros al actualizar texto dinámicamente.
    if not fontString._ktQuestFontHooked then
        fontString._ktQuestFontHooked = true

        hooksecurefunc(fontString, "SetTextColor", function(self, r, g, b, a)
            if self._ktQuestTextColorGuard then return end
            if IsDarkRGB(r, g, b) then
                self._ktQuestTextColorGuard = true
                if useGold then
                    self:SetTextColor(1, 0.82, 0, a or 1)
                else
                    self:SetTextColor(1, 1, 1, a or 1)
                end
                self._ktQuestTextColorGuard = nil
            end
        end)

        hooksecurefunc(fontString, "SetShadowColor", function(self, r, g, b, a)
            if self._ktQuestShadowGuard then return end
            if r ~= 0 or g ~= 0 or b ~= 0 or (a or 1) ~= 1 then
                self._ktQuestShadowGuard = true
                self:SetShadowColor(0, 0, 0, 1)
                self._ktQuestShadowGuard = nil
            end
        end)

        hooksecurefunc(fontString, "SetText", function(self, t)
            if self._ktQuestTextSetGuard then return end
            -- Secret strings still report type "string".  Do not inspect or
            -- transform them: gsub would attempt to convert the value.
            if type(t) == "string" and KT_CanAccessValue(t) then
                self._ktQuestTextSetGuard = true
                local cleaned, count = gsub(t, "|c[fF][fF](%x%x%x%x%x%x)", useGold and SmartReplaceToGold or SmartReplaceToWhite)
                if count > 0 then
                    self:SetText(cleaned)
                end
                self._ktQuestTextSetGuard = nil
            end
        end)
    end
end

local function RefreshQuestReadableText(root)
    if not root then return end
    local seen = {}

    local function Apply(region)
        if not region or not region.GetObjectType or region:GetObjectType() ~= "FontString" then
            return
        end
        local text = KT_GetAccessibleText(region)
        local lower = text and text:lower() or ""
        local regionName = region.GetName and region:GetName()
        local _, fontSize = region.GetFont and region:GetFont()
        local useGold =
            lower:find("quest", 1, true) or
            lower:find("objectives", 1, true) or
            lower:find("rewards", 1, true) or
            lower:find("description", 1, true) or
            (type(regionName) == "string" and (
                regionName:find("Title", 1, true) or
                regionName:find("Header", 1, true)
            )) or
            ((fontSize or 0) >= 15)
        FixQuestFontIfDark(region, useGold)
    end

    local function Visit(obj, depth)
        if not obj or seen[obj] or depth > 7 then return end
        seen[obj] = true

        if obj.GetObjectType and obj:GetObjectType() == "FontString" then
            Apply(obj)
            return
        end

        if obj.GetScrollChild then
            Visit(obj:GetScrollChild(), depth + 1)
        end
        if obj.GetRegions then
            for _, region in ipairs({ obj:GetRegions() }) do
                Visit(region, depth + 1)
            end
        end
        if obj.GetChildren then
            for _, child in ipairs({ obj:GetChildren() }) do
                Visit(child, depth + 1)
            end
        end
    end

    Visit(root, 0)
end

-- [FIX] Funciones para limpiar colores oscuros incrustados en el texto
local function SkinQuestTitle(fontString)
    if not fontString then return end
    fontString:SetDrawLayer("OVERLAY", 7)
    S:HandleFont(fontString)
    fontString:SetTextColor(1, 0.82, 0)
    ApplyReadableShadow(fontString)

    local text = KT_GetAccessibleText(fontString)
    if text then
        local newText, count = gsub(text, "|c[fF][fF](%x%x%x%x%x%x)", SmartReplaceToGold)
        if count > 0 and newText ~= text then
            fontString:SetText(newText)
        end
    end
end

local function SkinQuestBody(fontString)
    if not fontString then return end
    fontString:SetDrawLayer("OVERLAY", 7)
    SetBodyFont(fontString)
    fontString:SetTextColor(1, 1, 1)
    ApplyReadableShadow(fontString)

    local text = KT_GetAccessibleText(fontString)
    if text then
        local newText, count = gsub(text, "|c[fF][fF](%x%x%x%x%x%x)", SmartReplaceToWhite)
        if count > 0 and newText ~= text then
            fontString:SetText(newText)
        end
    end
end

S.RefreshQuestReadableText = RefreshQuestReadableText

-- [FIX] Función específica para botones de diálogo (Greeting/Gossip)
-- Combina la limpieza de color con el ajuste de iconos
local function SkinGreetingText(fontString)
    if not fontString then return end
    fontString:SetDrawLayer("OVERLAY", 7)
    SetBodyFont(fontString)
    fontString:SetTextColor(1, 1, 1)
    ApplyReadableShadow(fontString)

    local text = KT_GetAccessibleText(fontString)
    if not text then return end

    local original = text

    local newText, count = gsub(text, "|c[fF][fF](%x%x%x%x%x%x)", SmartReplaceToWhite)
    if count > 0 then
        text = newText
    end

    if text ~= original then
        fontString:SetText(text)
    end
end

-- ============================================================
-- GREETING PANEL (seleccion de opciones del NPC)
-- Blizzard embebe |cff000000 (negro) directamente en el texto
-- de cada botón de opción. Hay que reemplazarlo en el string.
-- ============================================================
local function SkinGreetingButtons(frame)
    if not frame or not frame.titleButtonPool then return end
    for button in frame.titleButtonPool:EnumerateActive() do
        if button.Icon then
            button.Icon:SetDrawLayer("ARTWORK")
        end

        local fs = button:GetFontString()
        if fs then
            SkinGreetingText(fs)
            if not button.IsSkinned then
                button:SetWidth(300)
                button.IsSkinned = true
            end
        end
    end
end
-- ============================================================
-- REWARDS
-- ============================================================
local skinnedQuestRewardButtons = {}

local function SetQuestRewardSelected(button, selected)
    if not button then return end

    if button._ktQuestRewardSelection then
        button._ktQuestRewardSelection:SetShown(selected)
    end

    if button.backdrop then
        if selected then
            local accent = S:GetAccentColor()
            button.backdrop:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        else
            button.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end
end

local function RefreshQuestRewardSelection(selectedButton)
    local selectedChoice = _G.QuestInfoFrame and _G.QuestInfoFrame.itemChoice or 0

    for button in pairs(skinnedQuestRewardButtons) do
        local selected = button == selectedButton
        if not selected and selectedChoice and selectedChoice > 0 and button.type == "choice" then
            selected = button:GetID() == selectedChoice
        end
        SetQuestRewardSelected(button, selected)
    end
end

local function SkinQuestRewardButton(button)
    if not button then return end

    if not button.isSkinned then
        S:StripTextures(button)
        S:CreateBackdrop(button)
        if button.Icon and button.backdrop then
            button.backdrop:ClearAllPoints()
            button.backdrop:SetPoint("TOPLEFT", button.Icon, "TOPLEFT", -1, 1)
            button.backdrop:SetPoint("BOTTOMRIGHT", button.Icon, "BOTTOMRIGHT", 1, -1)
            button.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
        if button.Icon then
            S:HandleIcon(button.Icon)
            button.Icon:SetDrawLayer("ARTWORK")
            button.Icon:SetAlpha(1)
        end
        if button.IconBorder then button.IconBorder:SetAlpha(0) end
        if button.IconOverlay then button.IconOverlay:SetAlpha(0) end
        if button.NameFrame then button.NameFrame:SetAlpha(0) end

        local selection = CreateFrame("Frame", nil, button, "BackdropTemplate")
        selection:SetPoint("TOPLEFT", button, "TOPLEFT", -3, 3)
        selection:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 3, -3)
        selection:SetFrameLevel(button:GetFrameLevel() + 2)
        selection:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 2,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        local accent = S:GetAccentColor()
        selection:SetBackdropColor(accent[1], accent[2], accent[3], 0.16)
        selection:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
        selection:EnableMouse(false)
        selection:Hide()
        button._ktQuestRewardSelection = selection

        button.isSkinned = true
    end

    skinnedQuestRewardButtons[button] = true

    if button.Name then SkinQuestBody(button.Name) end
    if button.Count then
        button.Count:SetDrawLayer("OVERLAY")
        S:HandleFont(button.Count)
        ApplyReadableShadow(button.Count)
    end
end

local function QuestRewardItemSelected(button)
    if not button or button.type ~= "choice" then return end
    SkinQuestRewardButton(button)
    RefreshQuestRewardSelection(button)
end

local function SkinQuestRewards()
    if not _G.QuestInfoFrame or not _G.QuestInfoFrame.rewardsFrame then return end
    local rewardsFrame = _G.QuestInfoFrame.rewardsFrame

    for i = 1, (rewardsFrame.numItems or 0) do
        SkinQuestRewardButton(_G["QuestInfoRewardsFrameQuestInfoItem"..i])
    end

    if rewardsFrame.RewardButtons then
        for _, button in ipairs(rewardsFrame.RewardButtons) do
            SkinQuestRewardButton(button)
        end
    end

    if rewardsFrame.spellRewardPool then
        for button in rewardsFrame.spellRewardPool:EnumerateActive() do
            SkinQuestRewardButton(button)
        end
    end

    if rewardsFrame.reputationRewardPool then
        for button in rewardsFrame.reputationRewardPool:EnumerateActive() do
            SkinQuestRewardButton(button)
        end
    end

    RefreshQuestRewardSelection()
end

-- ============================================================
-- INFO TEXT (títulos y cuerpo)
-- ============================================================
local function SkinQuestInfoText()
    if not _G.QuestInfoFrame then return end

    -- Amarillo: cabeceras
    SkinQuestTitle(_G.QuestInfoTitleHeader)
    SkinQuestTitle(_G.QuestInfoDescriptionHeader)
    SkinQuestTitle(_G.QuestInfoObjectivesHeader)
    
    if _G.QuestInfoRewardsFrame then
        SkinQuestTitle(_G.QuestInfoRewardsFrame.Header)
        -- Blanco: textos de recompensa
        SkinQuestBody(_G.QuestInfoRewardsFrame.ItemChooseText)
        SkinQuestBody(_G.QuestInfoRewardsFrame.ItemReceiveText)
        SkinQuestBody(_G.QuestInfoRewardsFrame.PlayerTitleText)
        SkinQuestBody(_G.QuestInfoRewardsFrame.SpellLearnText)
        if _G.QuestInfoRewardsFrame.XPFrame then
            SkinQuestBody(_G.QuestInfoRewardsFrame.XPFrame.ReceiveText)
        end
    end

    -- Blanco: cuerpo
    SkinQuestBody(_G.QuestInfoDescriptionText)
    SkinQuestBody(_G.QuestInfoObjectivesText)
    SkinQuestBody(_G.QuestInfoRewardText)
    SkinQuestBody(_G.QuestInfoGroupSize)
    SkinQuestBody(_G.QuestInfoQuestType)
    SkinQuestBody(_G.QuestInfoRequiredMoneyText)
end

-- ============================================================
-- OBJETIVOS (verde si completado, blanco si no)
-- ============================================================
local function ColorizeObjectives()
    local objectives = _G.QuestInfoObjectivesFrame and _G.QuestInfoObjectivesFrame.Objectives
    if not objectives then return end
    local questID = C_QuestLog.GetSelectedQuest()
    if not questID then return end
    
    -- [FIX] 11.0 API Change: GetQuestObjectiveInfo removed, replaced by GetQuestObjectives
    local questObjectives = C_QuestLog.GetQuestObjectives and C_QuestLog.GetQuestObjectives(questID) or nil

    for i = 1, _G.MAX_OBJECTIVES do
        local obj = objectives[i]
        if obj and obj:IsShown() then
            local completed = false
            if questObjectives then
                local info = questObjectives[i]
                if info then completed = info.finished end
            elseif C_QuestLog.GetQuestObjectiveInfo then
                local _, _, finished = C_QuestLog.GetQuestObjectiveInfo(questID, i)
                completed = finished
            end
            obj:SetTextColor(completed and 0.2 or 1, completed and 1 or 1, completed and 0.2 or 1)
        end
    end
end

-- ============================================================
-- STRIP DE PERGAMINOS (scroll children)
-- Se llama en setup Y en cada cambio de panel porque Blizzard
-- reasigna texturas al cambiar entre accept/progress/reward.
-- ============================================================
local function StripParchmentScrollChildren()
    if _G.QuestDetailScrollChildFrame   then S:StripTextures(_G.QuestDetailScrollChildFrame)   end
    if _G.QuestProgressScrollChildFrame then S:StripTextures(_G.QuestProgressScrollChildFrame) end
    if _G.QuestRewardScrollChildFrame   then S:StripTextures(_G.QuestRewardScrollChildFrame)   end
    if _G.QuestGreetingScrollChildFrame then S:StripTextures(_G.QuestGreetingScrollChildFrame) end
end

local function CleanQuestGreetingPanelVisuals()
    local function HideFrameTextures(frame)
        if not frame then return end
        S:StripTextures(frame)
        local regions = { frame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetAlpha(0)
            end
        end
        if frame.NineSlice then
            frame.NineSlice:SetAlpha(0)
        end
        if frame.Bg then
            frame.Bg:SetAlpha(0)
        end
        if frame.Background then
            frame.Background:SetAlpha(0)
        end
    end

    HideFrameTextures(_G.QuestFrameGreetingPanel)
    HideFrameTextures(_G.QuestGreetingScrollFrame)
    HideFrameTextures(_G.QuestGreetingScrollChildFrame)
end

-- ============================================================
-- PANEL DE PROGRESO (entregar ítems)
-- No pasa por QuestInfo_Display, tiene su propia función.
-- ============================================================
local function SkinProgressPanel()
    StripParchmentScrollChildren()

    if _G.QuestInfoTitleHeader then
        SkinQuestTitle(_G.QuestInfoTitleHeader)
    end
    if _G.QuestProgressTitleText then
        SkinQuestTitle(_G.QuestProgressTitleText)
    end
    if _G.QuestProgressRequiredItemsText then
        SkinQuestTitle(_G.QuestProgressRequiredItemsText)
    end
    if _G.QuestProgressText then
        SkinQuestBody(_G.QuestProgressText)
    end

    for i = 1, _G.MAX_REQUIRED_ITEMS or 6 do
        local btn  = _G["QuestProgressItem"..i]
        -- El icono NO es btn.Icon: es un global separado QuestProgressItemNIconTexture
        local icon = _G["QuestProgressItem"..i.."IconTexture"]
        if btn and btn:IsShown() and not btn.isSkinned then
            S:StripTextures(btn)
            S:CreateBackdrop(btn)
            if icon then
                -- Restaurar visibilidad después de StripTextures
                icon:SetAlpha(1)
                icon:Show()
                icon:SetDrawLayer("ARTWORK")
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                -- Posicionar el backdrop alrededor del icono
                if btn.backdrop then
                    btn.backdrop:ClearAllPoints()
                    btn.backdrop:SetPoint("TOPLEFT",     icon, "TOPLEFT",     -2,  2)
                    btn.backdrop:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT",  2, -2)
                end
            end
            local name = btn.Name or btn.name
            if name then S:HandleFont(name); name:SetTextColor(1, 1, 1) end
            btn.isSkinned = true
        end
        -- Garantizar visibilidad aunque ya esté skinned (Blizzard puede resetearlo)
        if btn and btn:IsShown() and icon then
            icon:SetAlpha(1)
            icon:Show()
        end
    end
end

-- ============================================================
-- FUNCIÓN PRINCIPAL
-- ============================================================
local function QuestFrame_SetTitleTextColor(fontString)
    SkinQuestTitle(fontString)
end

local function QuestFrame_SetTextColor(fontString)
    SkinQuestBody(fontString)
end

local function QuestInfo_ShowRequiredMoney()
    local fs = _G.QuestInfoRequiredMoneyText
    if not fs then return end

    fs:SetDrawLayer("OVERLAY", 7)
    SetBodyFont(fs)
    ApplyReadableShadow(fs)

    if fs.GetTextColor then
        local r, g, b = fs:GetTextColor()
        if IsDarkRGB(r, g, b) then
            fs:SetTextColor(1, 1, 1, 1)
        end
    end

    local text = KT_GetAccessibleText(fs)
    if text then
        local newText, count = gsub(text, "|c[fF][fF](%x%x%x%x%x%x)", SmartReplaceToWhite)
        if count > 0 and newText ~= text then
            fs:SetText(newText)
        end
    end
end

local function ApplyQuestUniformLayout()
    local questFrame = _G.QuestFrame
    if questFrame then
        EnsureUniformPanel(questFrame, "_ktQuestUniformPanel", 0, 0, 0, 0)
        if questFrame.backdrop then
            S:RegisterBlizzardWindowBackground(questFrame.backdrop)
            questFrame.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
    end

    for _, frame in ipairs({
        _G.QuestFrameDetailPanel,
        _G.QuestFrameProgressPanel,
        _G.QuestFrameRewardPanel,
        _G.QuestFrameGreetingPanel,
        _G.QuestDetailScrollFrame,
        _G.QuestProgressScrollFrame,
        _G.QuestRewardScrollFrame,
        _G.QuestGreetingScrollFrame,
        _G.QuestDetailScrollChildFrame,
        _G.QuestProgressScrollChildFrame,
        _G.QuestRewardScrollChildFrame,
        _G.QuestGreetingScrollChildFrame,
    }) do
        if frame then
            S:StripTextures(frame)
            HideFrameTextures(frame, true)
            DisableBackdrop(frame)
        end
    end
end

SkinQuestFrame = function()
    if not (S.db.enable and S.db.quest) then return end

    local QuestFrame = _G.QuestFrame
    if QuestFrame then
        S:HandlePortraitFrame(QuestFrame)
        ApplyQuestUniformLayout()
        if QuestFrame.Inset then S:StripTextures(QuestFrame.Inset) end

        if _G.QuestFrameDetailPanel   then S:StripTextures(_G.QuestFrameDetailPanel)   end
        if _G.QuestFrameProgressPanel then S:StripTextures(_G.QuestFrameProgressPanel) end
        if _G.QuestFrameRewardPanel   then S:StripTextures(_G.QuestFrameRewardPanel)   end
        if _G.QuestFrameGreetingPanel then S:StripTextures(_G.QuestFrameGreetingPanel) end

        StripParchmentScrollChildren()

        -- Botones principales
        local buttons = {
            "QuestFrameAcceptButton", "QuestFrameDeclineButton",
            "QuestFrameCompleteButton", "QuestFrameGoodbyeButton",
            "QuestFrameCompleteQuestButton",
        }
        for _, name in pairs(buttons) do
            if _G[name] then S:HandleButton(_G[name]) end
        end
        if _G.QuestFrameGreetingGoodbyeButton then S:HandleButton(_G.QuestFrameGreetingGoodbyeButton) end

        -- ScrollBars
        local scrolls = {
            "QuestDetailScrollFrame", "QuestProgressScrollFrame",
            "QuestRewardScrollFrame",  "QuestGreetingScrollFrame",
        }
        for _, name in pairs(scrolls) do
            if _G[name] and _G[name].ScrollBar then S:HandleScrollBar(_G[name].ScrollBar) end
        end

        -- Modelo NPC
        if _G.QuestNPCModel then
            S:StripTextures(_G.QuestNPCModel)
            DisableBackdrop(_G.QuestNPCModel)
            if _G.QuestNPCModelTextFrame then
                S:StripTextures(_G.QuestNPCModelTextFrame)
                DisableBackdrop(_G.QuestNPCModelTextFrame)
            end
        end

        -- Hook principal: panel de aceptar / recompensa
        if not QuestFrame._ktQuestInfoHooked then
            QuestFrame._ktQuestInfoHooked = true
            hooksecurefunc("QuestInfo_Display", function()
                StripParchmentScrollChildren()
                ApplyQuestUniformLayout()
                SkinQuestInfoText()
                SkinQuestRewards()
                ColorizeObjectives()
                RefreshQuestReadableText(_G.QuestInfoFrame)
                RefreshQuestReadableText(_G.QuestFrame)
            end)
        end

        if _G.QuestInfoItem_OnClick and not QuestFrame._ktQuestInfoItemClickHooked then
            hooksecurefunc("QuestInfoItem_OnClick", QuestRewardItemSelected)
            QuestFrame._ktQuestInfoItemClickHooked = true
        end
        if _G.QuestRewardItem_OnClick and not QuestFrame._ktQuestRewardItemClickHooked then
            hooksecurefunc("QuestRewardItem_OnClick", QuestRewardItemSelected)
            QuestFrame._ktQuestRewardItemClickHooked = true
        end
        if _G.QuestInfo_ShowRewards and not QuestFrame._ktQuestRewardsUpdateHooked then
            hooksecurefunc("QuestInfo_ShowRewards", SkinQuestRewards)
            QuestFrame._ktQuestRewardsUpdateHooked = true
        end

        -- Hook panel de progreso (entregar ítems) — no pasa por QuestInfo_Display
        if not QuestFrame._ktQuestColorHooks then
            if _G.QuestFrame_SetTitleTextColor then
                hooksecurefunc("QuestFrame_SetTitleTextColor", QuestFrame_SetTitleTextColor)
            end
            if _G.QuestFrame_SetTextColor then
                hooksecurefunc("QuestFrame_SetTextColor", QuestFrame_SetTextColor)
            end
            if _G.QuestInfo_ShowRequiredMoney then
                hooksecurefunc("QuestInfo_ShowRequiredMoney", QuestInfo_ShowRequiredMoney)
            end
            QuestFrame._ktQuestColorHooks = true
        end

        if not QuestFrame._ktQuestProgressHooks then
            if _G.QuestFrameProgress_ShowItems then
                hooksecurefunc("QuestFrameProgress_ShowItems", SkinProgressPanel)
            elseif _G.QuestFrameProgressItems_Update then
                hooksecurefunc("QuestFrameProgressItems_Update", SkinProgressPanel)
            end
            if _G.QuestFrameProgressPanel then
            _G.QuestFrameProgressPanel:HookScript("OnShow", SkinProgressPanel)
            end
            QuestFrame._ktQuestProgressHooks = true
        end

        -- ============================================================
        -- FIX PANEL DE SALUDO (texto negro en opciones del NPC)
        -- Blizzard embebe |cff000000 en los botones de titleButtonPool.
        -- Hay que hookear OnShow Y QuestFrameGreetingPanel_OnShow
        -- (este segundo se dispara en QUEST_LOG_UPDATE sin OnShow).
        -- ============================================================
        if _G.QuestFrameGreetingPanel and not _G.QuestFrameGreetingPanel._ktGreetingSkinHooked then
            _G.QuestFrameGreetingPanel:HookScript("OnShow", function(self)
                SkinGreetingButtons(self)
                StripParchmentScrollChildren()
                CleanQuestGreetingPanelVisuals()
            end)
            _G.QuestFrameGreetingPanel._ktGreetingSkinHooked = true
        end
        -- Este hook captura actualizaciones via QUEST_LOG_UPDATE sin re-show
        if _G.QuestFrameGreetingPanel_OnShow and not QuestFrame._ktGreetingPanelOnShowHooked then
            hooksecurefunc("QuestFrameGreetingPanel_OnShow", function()
                SkinGreetingButtons(_G.QuestFrameGreetingPanel)
                CleanQuestGreetingPanelVisuals()
                RefreshQuestReadableText(_G.QuestFrameGreetingPanel)
            end)
            QuestFrame._ktGreetingPanelOnShowHooked = true
        end

        if not QuestFrame._ktReadableTextHooked then
            QuestFrame:HookScript("OnShow", function(self)
                RefreshQuestReadableText(self)
            end)
            QuestFrame._ktReadableTextHooked = true
        end

        SkinQuestInfoText()
        SkinQuestRewards()
        ApplyQuestUniformLayout()
        SkinProgressPanel()
        SkinGreetingButtons(_G.QuestFrameGreetingPanel)
        RefreshQuestReadableText(QuestFrame)
    end

    -- Quest Log Popup (ventana flotante L)
    local QuestLogPopupDetailFrame = _G.QuestLogPopupDetailFrame
    if QuestLogPopupDetailFrame then
        S:HandlePortraitFrame(QuestLogPopupDetailFrame)
        EnsureUniformPanel(QuestLogPopupDetailFrame, "_ktQuestPopupUniformPanel", 0, 0, 0, 0)
        if QuestLogPopupDetailFrame.backdrop then
            S:RegisterBlizzardWindowBackground(QuestLogPopupDetailFrame.backdrop)
            QuestLogPopupDetailFrame.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        end
        if QuestLogPopupDetailFrame.Inset then S:StripTextures(QuestLogPopupDetailFrame.Inset) end
        S:HandleButton(_G.QuestLogPopupDetailFrameAbandonButton)
        S:HandleButton(_G.QuestLogPopupDetailFrameShareButton)
        S:HandleButton(_G.QuestLogPopupDetailFrameTrackButton)
        if _G.QuestLogPopupDetailFrameScrollFrame and _G.QuestLogPopupDetailFrameScrollFrame.ScrollBar then
            S:StripTextures(_G.QuestLogPopupDetailFrameScrollFrame)
            HideFrameTextures(_G.QuestLogPopupDetailFrameScrollFrame, true)
            DisableBackdrop(_G.QuestLogPopupDetailFrameScrollFrame)
            S:HandleScrollBar(_G.QuestLogPopupDetailFrameScrollFrame.ScrollBar)
        end
        if not QuestLogPopupDetailFrame._ktReadableTextHooked then
            QuestLogPopupDetailFrame:HookScript("OnShow", function(self)
                RefreshQuestReadableText(self)
            end)
            QuestLogPopupDetailFrame._ktReadableTextHooked = true
        end
        RefreshQuestReadableText(QuestLogPopupDetailFrame)
    end

    -- QuestMapFrame se skinea exclusivamente desde WorldMap.lua.
    -- Evitamos aquí tocar el panel lateral para no duplicar backdrops,
    -- hooks y offsets sobre la misma ventana.
end

-- ============================================================
-- QUEST CHOICE (ventana de elección de camino de historia)
-- ============================================================
local function SkinQuestChoice()
    if not (S.db.enable and S.db.quest) then return end
    local QuestChoiceFrame = _G.QuestChoiceFrame
    if not QuestChoiceFrame then return end

    S:StripTextures(QuestChoiceFrame)
    S:CreateBackdrop(QuestChoiceFrame)

    if QuestChoiceFrame.CloseButton then S:HandleCloseButton(QuestChoiceFrame.CloseButton) end
    if QuestChoiceFrame.Title then
        S:HandleFont(QuestChoiceFrame.Title)
        QuestChoiceFrame.Title:SetTextColor(1, 0.82, 0)
        ApplyReadableShadow(QuestChoiceFrame.Title)
    end

    local function RefreshQuestChoiceOptions(self)
        local numOptions = self.numOptions or 4
        for i = 1, numOptions do
            local option = self["Option"..i]
            if option then
                if not option.isSkinned then
                    S:StripTextures(option)
                    S:CreateBackdrop(option)
                    option.backdrop:SetBackdropColor(0, 0, 0, 0.5)

                    if option.Header and option.Header.Text then S:HandleFont(option.Header.Text) end
                    if option.OptionText then S:HandleFont(option.OptionText) end

                    if option.OptionButtonsContainer and option.OptionButtonsContainer.OptionButton1 then
                        S:HandleButton(option.OptionButtonsContainer.OptionButton1)
                    end

                    if option.Rewards then
                        local rewards = option.Rewards
                        if rewards.Item then
                            if rewards.Item.Icon then S:HandleIcon(rewards.Item.Icon); rewards.Item.Icon:SetDrawLayer("ARTWORK") end
                            if rewards.Item.IconBorder then rewards.Item.IconBorder:SetAlpha(0) end
                            if rewards.Item.Name then S:HandleFont(rewards.Item.Name) end
                        end
                        if rewards.Currencies then
                            for j = 1, 3 do
                                local cu = rewards.Currencies["Currency"..j]
                                if cu and cu.Icon then S:HandleIcon(cu.Icon) end
                            end
                        end
                    end
                    option.isSkinned = true
                end

                -- Forzar colores en cada update (Blizzard puede resetearlos)
                if option.Header and option.Header.Text then
                    SkinQuestTitle(option.Header.Text)
                end
                if option.OptionText then
                    SkinQuestBody(option.OptionText)
                end
                if option.Rewards and option.Rewards.Item and option.Rewards.Item.Name then
                    SkinQuestBody(option.Rewards.Item.Name)
                end
            end
        end
    end

    RefreshQuestChoiceOptions(QuestChoiceFrame)
    if not QuestChoiceFrame._ktChoiceUpdateHooked then
        hooksecurefunc(QuestChoiceFrame, "Update", RefreshQuestChoiceOptions)
        QuestChoiceFrame._ktChoiceUpdateHooked = true
    end
end

S.SkinFuncs["Blizzard_QuestClient"] = SkinQuestFrame
S.SkinFuncs["Blizzard_QuestChoice"] = SkinQuestChoice
S:AddCallback("BlizzardQuestFrames", SkinQuestFrame)
S:AddCallback("KullThranUIQuestFrameBootstrap", function()
    SkinQuestFrame()

    if not S._ktQuestEventFrame then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("QUEST_DETAIL")
        frame:RegisterEvent("QUEST_PROGRESS")
        frame:RegisterEvent("QUEST_COMPLETE")
        frame:RegisterEvent("QUEST_GREETING")
        frame:RegisterEvent("QUEST_FINISHED")
        frame:RegisterEvent("QUEST_ACCEPTED")
        frame:SetScript("OnEvent", function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, SkinQuestFrame)
                C_Timer.After(0.05, SkinQuestFrame)
            else
                SkinQuestFrame()
            end
        end)
        S._ktQuestEventFrame = frame
    end
end)
