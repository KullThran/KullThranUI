local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local hooksecurefunc = hooksecurefunc
local gsub = string.gsub
local ipairs = ipairs
local tonumber = tonumber

local FONT_AVANT    = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local FONT_FALLBACK = "Fonts\\FRIZQT__.TTF"

local SkinGossip
local ITEM_TEXT_FRAME_WIDTH = 340
local ITEM_TEXT_RIGHT_MARGIN = 6
local ITEM_TEXT_BACKDROP

local INLINE_DARK_REPLACEMENTS = {
    ["000000"] = "ffffff",
    ["414141"] = "c8ced4",
}

local function IsDarkHex(hex)
    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return (r + g + b) < 600
end

local function IsDarkRGB(r, g, b)
    if r == nil or g == nil or b == nil then return false end
    return (r + g + b) < 0.65
end

local function SmartReplaceToWhite(hex)
    local lower = hex and hex:lower()
    local replacement = lower and INLINE_DARK_REPLACEMENTS[lower]
    if replacement then
        return "|cff" .. replacement
    end

    if lower and IsDarkHex(lower) then
        return "|cffffffff"
    end

    return "|cff" .. hex
end

local function ApplyReadableShadow(fontString)
    if fontString.SetShadowColor then
        fontString:SetShadowColor(0, 0, 0, 0.95)
    end
    if fontString.SetShadowOffset then
        fontString:SetShadowOffset(1, -1)
    end
end

local function ApplyReadableFont(fontString)
    if not (fontString and fontString.IsObjectType and fontString:IsObjectType("FontString")) then return end

    local _, size = fontString:GetFont()
    size = (size and size > 0) and size or 12
    if not fontString:SetFont(FONT_AVANT, size, "OUTLINE") then
        fontString:SetFont(FONT_FALLBACK, size, "OUTLINE")
    end

    if fontString.SetDrawLayer then
        fontString:SetDrawLayer("OVERLAY", 7)
    end
    ApplyReadableShadow(fontString)
end

local function CleanInlineText(fontString)
    if not (fontString and fontString.GetText and fontString.SetText) then return end

    local currentText = fontString:GetText()
    if currentText and currentText ~= "" then
        local cleanText = gsub(currentText, "|[cC][fF][fF](%x%x%x%x%x%x)", SmartReplaceToWhite)
        if currentText ~= cleanText then
            fontString.ktSettingText = true
            fontString:SetText(cleanText)
            fontString.ktSettingText = false
        end
    end
end

local function ForceReadableColor(fontString)
    if not (fontString and fontString.SetTextColor) then return end

    if fontString.GetTextColor then
        local r, g, b = fontString:GetTextColor()
        if IsDarkRGB(r, g, b) then
            fontString.ktSettingColor = true
            fontString:SetTextColor(1, 1, 1, 1)
            fontString.ktSettingColor = false
        end
    end
end

local function SkinFontString(fontString)
    if not (fontString and fontString.IsObjectType and fontString:IsObjectType("FontString")) then return end

    ApplyReadableFont(fontString)
    CleanInlineText(fontString)
    ForceReadableColor(fontString)

    if not fontString.ktGossipHooked then
        hooksecurefunc(fontString, "SetText", function(self, text)
            if not text or self.ktSettingText then return end
            CleanInlineText(self)
        end)

        hooksecurefunc(fontString, "SetTextColor", function(self, r, g, b)
            if self.ktSettingColor then return end
            if IsDarkRGB(r, g, b) then
                self.ktSettingColor = true
                self:SetTextColor(1, 1, 1, 1)
                self.ktSettingColor = false
            end
            ApplyReadableShadow(self)
        end)

        fontString.ktGossipHooked = true
    end
end

local function SkinGossipButton(button)
    if not button then return end

    if button.GreetingText then
        SkinFontString(button.GreetingText)
    end

    local fontString = button.GetFontString and button:GetFontString()
    if fontString then
        SkinFontString(fontString)
    end

    if button.GetRegions then
        for _, region in ipairs({ button:GetRegions() }) do
            SkinFontString(region)
        end
    end

    if button.Icon then
        button.Icon:SetDrawLayer("ARTWORK", 5)
        button.Icon:SetAlpha(1)
    end
end

local function RefreshGossipScrollBox(scrollBox)
    if not (scrollBox and scrollBox.ForEachFrame) then return end

    scrollBox:ForEachFrame(SkinGossipButton)
end

local function SkinPageButton(button, text)
    if not button then return end

    S:HandleButton(button)
    if button._ktPageArrow then
        button._ktPageArrow:SetText(text)
        return
    end

    local arrow = button:CreateFontString(nil, "OVERLAY")
    arrow:SetFont(FONT_AVANT, 16, "OUTLINE")
    arrow:SetText(text)
    arrow:SetTextColor(1, 1, 1, 1)
    arrow:SetPoint("CENTER", button.backdrop or button, "CENTER", 0, 1)
    ApplyReadableShadow(arrow)
    button._ktPageArrow = arrow
end

local function SkinAnyItemTextButton(button)
    if not button or button._ktItemTextButtonSkinned then return end
    if button == _G.ItemTextNextPageButton or button == _G.ItemTextPrevPageButton then return end

    local text = button.GetText and button:GetText()
    if text and text ~= "" then
        S:HandleButton(button)
        local fs = button.GetFontString and button:GetFontString()
        if fs then
            SkinFontString(fs)
            fs:SetTextColor(1, 1, 1, 1)
        end
        if button.SetHeight and button.GetHeight and button:GetHeight() < 22 then
            button:SetHeight(22)
        end
        if button.SetWidth and button.GetWidth and button:GetWidth() < 72 then
            button:SetWidth(72)
        end
        button._ktItemTextButtonSkinned = true
    end
end

local function SkinItemTextButtons(frame)
    if not (frame and frame.GetChildren) then return end

    for _, child in ipairs({ frame:GetChildren() }) do
        if child and child.IsObjectType and child:IsObjectType("Button") then
            SkinAnyItemTextButton(child)
        end
    end
end

local function HideTexture(texture)
    if not texture then return end

    if texture._ktGossipHidingTexture then return end
    texture._ktGossipHidingTexture = true
    if texture.SetTexture then texture:SetTexture(nil) end
    if texture.SetAtlas then pcall(texture.SetAtlas, texture, nil) end
    if texture.SetAlpha then texture:SetAlpha(0) end
    texture._ktGossipHidingTexture = nil

    if not texture._ktGossipTextureHooked then
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
        texture._ktGossipTextureHooked = true
    end
end

local function HideItemTextParchment()
    for _, texture in ipairs({
        _G.ItemTextFramePageBg,
        _G.ItemTextFrameInset,
        _G.ItemTextFrameBg,
        _G.ItemTextFrameTopBorder,
        _G.ItemTextFrameBottomBorder,
        _G.ItemTextFrameLeftBorder,
        _G.ItemTextFrameRightBorder,
        _G.ItemTextMaterialTopLeft,
        _G.ItemTextMaterialTopRight,
        _G.ItemTextMaterialBotLeft,
        _G.ItemTextMaterialBotRight,
        _G.ItemTextFrameMaterialTopLeft,
        _G.ItemTextFrameMaterialTopRight,
        _G.ItemTextFrameMaterialBotLeft,
        _G.ItemTextFrameMaterialBotRight,
    }) do
        HideTexture(texture)
    end
end

local DisableBackdrop

local function HideFrameTextures(frame, deep)
    if not (frame and frame.GetRegions) then return end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            HideTexture(region)
        end
    end

    if deep and frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            -- Keep the ItemText backdrop intact when the skin is refreshed.
            -- Otherwise the recursive cleanup hides the backdrop's own fill,
            -- leaving readable world texts (tablets, scrolls, inscriptions)
            -- transparent after they are opened again.
            if child and child.IsObjectType and not child:IsObjectType("Button")
                and child ~= ITEM_TEXT_BACKDROP then
                HideFrameTextures(child, true)
                DisableBackdrop(child)
            end
        end
    end
end

local function EnsureUniformPanel(frame, key, left, top, right, bottom)
    if not frame then return end

    key = key or "_ktUniformPanel"
    local texture = frame[key]
    if texture then
        texture:SetAlpha(0)
        texture:Hide()
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

local function ForceItemTextFrameSize(frame)
    if not frame or frame._ktGossipSizing then return end

    frame._ktGossipSizing = true
    local height = frame.GetHeight and frame:GetHeight()
    if not height or height <= 0 then
        height = 506
    end

    if frame.SetSize then
        frame:SetSize(ITEM_TEXT_FRAME_WIDTH, height)
    elseif frame.SetWidth then
        frame:SetWidth(ITEM_TEXT_FRAME_WIDTH)
    end
    frame._ktGossipSizing = nil
end

local function SkinItemTextFrame()
    local ItemTextFrame = _G.ItemTextFrame
    if not ItemTextFrame then return end

    ForceItemTextFrameSize(ItemTextFrame)

    S:StripTextures(ItemTextFrame)
    HideFrameTextures(ItemTextFrame, true)
    EnsureUniformPanel(ItemTextFrame, "_ktGossipUniformPanel", 0, -16, -ITEM_TEXT_RIGHT_MARGIN, 16)
    S:CreateBackdrop(ItemTextFrame, true)
    HideItemTextParchment()

    if ItemTextFrame.backdrop then
        ITEM_TEXT_BACKDROP = ItemTextFrame.backdrop
        ItemTextFrame.backdrop:SetAlpha(1)
        ItemTextFrame.backdrop:SetBackdropColor(0.02, 0.015, 0.02, 0.98)
        ItemTextFrame.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        ItemTextFrame.backdrop:ClearAllPoints()
        ItemTextFrame.backdrop:SetPoint("TOPLEFT", ItemTextFrame, "TOPLEFT", 6, -16)
        ItemTextFrame.backdrop:SetPoint("BOTTOMRIGHT", ItemTextFrame, "BOTTOMRIGHT", -ITEM_TEXT_RIGHT_MARGIN, 16)
    end

    if ItemTextFrame.TitleText then
        S:HandleFont(ItemTextFrame.TitleText)
        ItemTextFrame.TitleText:ClearAllPoints()
        ItemTextFrame.TitleText:SetPoint("TOP", ItemTextFrame, "TOP", 0, -24)
        ItemTextFrame.TitleText:SetTextColor(1, 0.82, 0, 1)
        ApplyReadableShadow(ItemTextFrame.TitleText)
    end

    if _G.ItemTextScrollFrame then
        _G.ItemTextScrollFrame:ClearAllPoints()
        _G.ItemTextScrollFrame:SetPoint("TOPLEFT", ItemTextFrame, "TOPLEFT", 20, -70)
        _G.ItemTextScrollFrame:SetPoint("BOTTOMRIGHT", ItemTextFrame, "BOTTOMRIGHT", -32, 58)

        S:StripTextures(_G.ItemTextScrollFrame)
        HideFrameTextures(_G.ItemTextScrollFrame, true)
        DisableBackdrop(_G.ItemTextScrollFrame)
        HideItemTextParchment()

        if _G.ItemTextScrollFrame.GetScrollChild then
            HideFrameTextures(_G.ItemTextScrollFrame:GetScrollChild(), true)
        end

        if _G.ItemTextScrollFrame.ScrollBar then
            S:HandleScrollBar(_G.ItemTextScrollFrame.ScrollBar)
            _G.ItemTextScrollFrame.ScrollBar:ClearAllPoints()
            _G.ItemTextScrollFrame.ScrollBar:SetPoint("TOPLEFT", _G.ItemTextScrollFrame, "TOPRIGHT", 4, -2)
            _G.ItemTextScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", _G.ItemTextScrollFrame, "BOTTOMRIGHT", 4, 2)
        end
    end

    if _G.ItemTextFrameCloseButton then
        S:HandleCloseButton(_G.ItemTextFrameCloseButton)
        _G.ItemTextFrameCloseButton:ClearAllPoints()
        _G.ItemTextFrameCloseButton:SetPoint("TOPRIGHT", ItemTextFrame, "TOPRIGHT", -ITEM_TEXT_RIGHT_MARGIN + 3, -14)
    end
    SkinPageButton(_G.ItemTextNextPageButton, ">")
    SkinPageButton(_G.ItemTextPrevPageButton, "<")

    if _G.ItemTextPageText then
        SkinFontString(_G.ItemTextPageText)
        _G.ItemTextPageText:SetTextColor("P", 1, 1, 1)
        if not _G.ItemTextPageText._ktGossipPageHooked then
            hooksecurefunc(_G.ItemTextPageText, "SetTextColor", function(self, headerType, r, g, b)
                if self._ktGossipPageGuard then return end
                if IsDarkRGB(r, g, b) then
                    self._ktGossipPageGuard = true
                    self:SetTextColor(headerType, 1, 1, 1)
                    self._ktGossipPageGuard = false
                end
            end)
            _G.ItemTextPageText._ktGossipPageHooked = true
        end
    end

    SkinItemTextButtons(ItemTextFrame)

    if not ItemTextFrame._ktGossipOnShowHooked then
        ItemTextFrame:HookScript("OnShow", function()
            SkinItemTextFrame()
        end)
        hooksecurefunc(ItemTextFrame, "SetWidth", function(self)
            if not self._ktGossipSizing then
                ForceItemTextFrameSize(self)
            end
        end)
        hooksecurefunc(ItemTextFrame, "SetSize", function(self)
            if not self._ktGossipSizing then
                ForceItemTextFrameSize(self)
            end
        end)
        ItemTextFrame._ktGossipOnShowHooked = true
    end
end

local function SkinGossipFrame()
    local GossipFrame = _G.GossipFrame
    if not GossipFrame then return end

    S:HandlePortraitFrame(GossipFrame)
    if GossipFrame.backdrop then
        S:RegisterBlizzardWindowBackground(GossipFrame.backdrop)
        GossipFrame.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
    end
    if GossipFrame.Inset then S:StripTextures(GossipFrame.Inset) end
    if _G.GossipFrameInset then S:StripTextures(_G.GossipFrameInset) end
    if GossipFrame.Background then HideTexture(GossipFrame.Background) end

    local panel = GossipFrame.GreetingPanel
    if panel then
        S:StripTextures(panel)
        DisableBackdrop(panel)
        if panel.GoodbyeButton then
            S:HandleButton(panel.GoodbyeButton)
        end

        if panel.ScrollBar then
            S:HandleScrollBar(panel.ScrollBar)
        end

        if panel.ScrollBox then
            RefreshGossipScrollBox(panel.ScrollBox)
            if not panel.ScrollBox._ktGossipUpdateHooked then
                hooksecurefunc(panel.ScrollBox, "Update", RefreshGossipScrollBox)
                panel.ScrollBox._ktGossipUpdateHooked = true
            end
        end
    end

    if _G.GossipGreetingScrollFrame and _G.GossipGreetingScrollFrame.ScrollBar then
        S:HandleScrollBar(_G.GossipGreetingScrollFrame.ScrollBar)
    end
    if GossipFrame.FriendshipStatusBar then
        S:StripTextures(GossipFrame.FriendshipStatusBar)
        S:CreateBackdrop(GossipFrame.FriendshipStatusBar)
        S:HandleStatusBar(GossipFrame.FriendshipStatusBar)
    end
    if _G.GossipNPCModel then
        S:StripTextures(_G.GossipNPCModel)
        S:CreateBackdrop(_G.GossipNPCModel)
    end
end

local function ScheduleGossipSkin()
    if C_Timer and C_Timer.After then
        C_Timer.After(0, SkinGossip)
        C_Timer.After(0.05, SkinGossip)
    else
        SkinGossip()
    end
end

SkinGossip = function()
    if not (S.db.enable and S.db.gossip) then return end

    SkinItemTextFrame()
    SkinGossipFrame()
end

S.SkinFuncs["Blizzard_GossipUI"] = SkinGossip
S.SkinFuncs["Blizzard_ItemTextFrame"] = SkinGossip
S:AddCallback("GossipFrame", SkinGossip)
S:AddCallback("GossipFrameBootstrap", function()
    SkinGossip()

    if not S._ktGossipEventFrame then
        local frame = CreateFrame("Frame")
        frame:RegisterEvent("GOSSIP_SHOW")
        frame:RegisterEvent("ITEM_TEXT_BEGIN")
        frame:RegisterEvent("QUEST_GREETING")
        frame:SetScript("OnEvent", ScheduleGossipSkin)
        S._ktGossipEventFrame = frame
    end

    if _G.ItemTextFrame_Update and not S._ktItemTextUpdateHooked then
        hooksecurefunc("ItemTextFrame_Update", SkinItemTextFrame)
        S._ktItemTextUpdateHooked = true
    end
end)
