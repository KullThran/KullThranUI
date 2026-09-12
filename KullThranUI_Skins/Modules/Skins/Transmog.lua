local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
local S = KT and KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local type = type
local ipairs = ipairs
local pairs = pairs
local CreateFrame = CreateFrame
local C_Timer = C_Timer

local function IsObject(value, objectType)
    local kind = type(value)
    if (kind ~= "table" and kind ~= "userdata") or type(value.GetObjectType) ~= "function" then
        return false
    end
    if value.IsForbidden and value:IsForbidden() then return false end
    return not objectType or value:GetObjectType() == objectType
end

local function StyleNativeTexture(texture, alpha)
    if not IsObject(texture, "Texture") then return end
    texture:Show()
    texture:SetDesaturated(false)
    texture:SetVertexColor(0.40, 0.40, 0.44, 1)
    texture:SetAlpha(alpha or 0.62)
end

local function SkinButton(button)
    if not IsObject(button, "Button") or button._ktTransmogSkinned then return end
    S:HandleButton(button)
    button._ktTransmogSkinned = true
end

local function SkinEditBox(editBox)
    if not IsObject(editBox, "EditBox") or editBox._ktTransmogSkinned then return end
    S:HandleEditBox(editBox)
    editBox._ktTransmogSkinned = true
end

local function SkinCloseButton(button)
    if not IsObject(button, "Button") or button._ktTransmogSkinned then return end
    if S.HandleCloseButton then S:HandleCloseButton(button) end
    button._ktTransmogSkinned = true
end

local function SkinCheckBox(checkBox)
    if not IsObject(checkBox, "CheckButton") or checkBox._ktTransmogSkinned then return end
    S:HandleCheckBox(checkBox)
    checkBox._ktTransmogSkinned = true
end

local function SkinDropDown(dropDown, width)
    if not IsObject(dropDown) or dropDown._ktTransmogSkinned then return end
    S:HandleDropDownBox(dropDown, width)
    dropDown._ktTransmogSkinned = true
end

local function SkinScrollBar(scrollBar)
    if not IsObject(scrollBar) or scrollBar._ktTransmogSkinned then return end
    S:HandleScrollBar(scrollBar)
    scrollBar._ktTransmogSkinned = true
end

local function StylePanel(panel, alpha)
    if not IsObject(panel) then return end

    local panelBackground = panel.Background or panel.Bg or panel.bg
    if panelBackground and panelBackground.SetAlpha then panelBackground:SetAlpha(0) end
    if panel.SetBackdropColor then
        panel:SetBackdropColor(0, 0, 0, 0)
    end
    StyleNativeTexture(panel.GradientTop, 0.12)
    StyleNativeTexture(panel.GradientBottom, 0.12)

    if not panel._ktTransmogModernPanel then
        S:CreateBackdrop(panel, true)
        S:ContentShade(panel, "TOPLEFT", 1, -1, "BOTTOMRIGHT", -1, 1, 0.22)
        panel._ktTransmogModernPanel = true
    end
    local panelData = S:GetFFD(panel)
    if panelData.rightShade then panelData.rightShade:SetAlpha(0.08) end

    if panel.backdrop then
        local accent = S:GetAccentColor()
        panel.backdrop:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.34)
        if S.ApplyKuiSurface then
            -- Transmog uses several opaque child panels. Apply the shared KUI
            -- artwork to each one so the texture remains visible throughout
            -- the outfit, preview, wardrobe and popup views.
            S:ApplyKuiSurface(panel, { flat = panel.backdrop, washAlpha = 0.28 })
        else
            panel.backdrop:SetBackdropColor(0.055, 0.055, 0.065, 0.90)
        end
    end
end

local function SkinTabs(tabHeaders)
    if not IsObject(tabHeaders) then return end

    local handled = {}
    if type(tabHeaders.tabs) == "table" then
        for _, tab in pairs(tabHeaders.tabs) do
            if IsObject(tab, "Button") then
                S:HandleTab(tab)
                handled[tab] = true
            end
        end
    end

    if tabHeaders.GetChildren then
        for _, child in ipairs({ tabHeaders:GetChildren() }) do
            if IsObject(child, "Button") and not handled[child] then
                S:HandleTab(child)
            end
        end
    end
end

local function SkinPagingControls(paging)
    if not IsObject(paging) then return end
    for _, key in ipairs({
        "BackButton", "PrevPageButton", "PreviousPageButton", "PrevButton", "PreviousButton",
        "NextButton", "NextPageButton",
    }) do
        local button = paging[key]
        if IsObject(button, "Button") and not button._ktTransmogPagingSkinned then
            S:CreateBackdrop(button, true)
            if button.backdrop then
                button.backdrop:SetBackdropColor(0.04, 0.04, 0.05, 0.72)
                button.backdrop:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)
                S:SetInside(button.backdrop, button, 4)
            end
            button._ktTransmogPagingSkinned = true
        end
    end
    if IsObject(paging.PageNumber) then S:HandleFont(paging.PageNumber) end
    if IsObject(paging.PageText) then S:HandleFont(paging.PageText) end
end

local function SkinToggle(toggle)
    if not toggle then return end
    SkinCheckBox(toggle.Checkbox or toggle.CheckButton or toggle)
end

local function SkinOutfitCollection(outfits)
    if not IsObject(outfits) then return end
    StylePanel(outfits, 0.55)
    StyleNativeTexture(outfits.DividerBar, 0.55)

    SkinButton(outfits.PurchaseOutfitButton)
    SkinButton(outfits.SaveOutfitButton or outfits.SaveButton)
    SkinButton(outfits.CreateButton)
    SkinButton(outfits.DeleteButton)
    SkinEditBox(outfits.NameEditBox)

    if outfits.OutfitList then
        StylePanel(outfits.OutfitList, 0.42)
        SkinScrollBar(outfits.OutfitList.ScrollBar)
    end

    if outfits.MoneyFrame then
        StylePanel(outfits.MoneyFrame, 0.48)
        StyleNativeTexture(outfits.MoneyFrame.Background, 0.48)
    end
end

local function SkinCharacterPreview(preview)
    if not IsObject(preview) then return end
    StylePanel(preview, 0.58)
    StyleNativeTexture(preview.SavedFrame, 0.46)

    SkinButton(preview.ClearAllPendingButton)
    local toggles = preview.ToggleOptions
    if toggles then
        SkinToggle(toggles.HideIgnoredToggle)
        SkinToggle(toggles.SheatheWeaponToggle)
        SkinToggle(toggles.PreviewedWeaponToggle)
    end
end

local function SkinWardrobeCollection(collection)
    if not IsObject(collection) then return end
    StylePanel(collection, 0.58)
    SkinTabs(collection.TabHeaders)

    local content = collection.TabContent
    if content then
        StylePanel(content, 0.54)
        StyleNativeTexture(content.Border, 0.52)
    end

    local items = content and content.ItemsFrame or collection.ItemsFrame
    if items then
        StylePanel(items, 0.48)
        SkinEditBox(items.SearchBox)
        SkinDropDown(items.FilterButton)
        SkinDropDown(items.WeaponDropdown)
        SkinDropDown(items.WeaponSheatheDropdown)
        SkinToggle(items.SecondaryAppearanceToggle)
        SkinPagingControls(items.PagedContent and items.PagedContent.PagingControls)
    end

    local sets = content and content.SetsFrame or collection.SetsFrame
    if sets then
        StylePanel(sets, 0.48)
        SkinEditBox(sets.SearchBox)
        SkinDropDown(sets.FilterButton)
        SkinPagingControls(sets.PagedContent and sets.PagedContent.PagingControls)
    end

    local customSets = content and content.CustomSetsFrame or collection.CustomSetsFrame
    if customSets then
        StylePanel(customSets, 0.48)
        SkinButton(customSets.NewCustomSetButton)
        SkinPagingControls(customSets.PagedContent and customSets.PagedContent.PagingControls)
    end

    local situations = content and content.SituationsFrame or collection.SituationsFrame
    if situations then
        StylePanel(situations, 0.48)
        StylePanel(situations.Situations, 0.45)
        SkinButton(situations.DefaultsButton)
        SkinButton(situations.ApplyButton)
        SkinButton(situations.UndoButton)
        SkinToggle(situations.EnabledToggle)
    end
end

local function SkinOutfitPopup(popup)
    if not IsObject(popup) then return end
    StylePanel(popup, 0.54)
    SkinCloseButton(popup.CloseButton)
    SkinButton(popup.AcceptButton or popup.SaveButton)
    SkinButton(popup.CancelButton)
    SkinEditBox(popup.EditBox or popup.NameEditBox)
end

local function ApplyTransmogSkin(frame)
    if not IsObject(frame) then return end

    if not frame._ktTransmogShellSkinned then
        S:SkinPremiumWindow(frame)
        frame._ktTransmogShellSkinned = true
    end
    if S.ApplyKuiSurface then
        S:ApplyKuiSurface(frame, { washAlpha = 0.30 })
    end

    SkinCloseButton(frame.CloseButton)
    SkinButton(frame.ApplyButton)
    SkinButton(frame.ResetButton)
    SkinButton(frame.SaveButton)

    SkinOutfitCollection(frame.OutfitCollection or frame.OutfitDetails)
    SkinCharacterPreview(frame.CharacterPreview)
    SkinWardrobeCollection(frame.WardrobeCollection or frame.WardrobeCollectionFrame or _G.WardrobeCollectionFrame)
    SkinOutfitPopup(frame.OutfitPopup)
end

local function SkinTransmog()
    if not (S.db and S.db.enable and S.db.collections) then return end
    local frame = _G.TransmogFrame or _G.WardrobeTransmogFrame
    if not frame then return end

    ApplyTransmogSkin(frame)
    if not frame._ktTransmogRefreshHooked then
        frame:HookScript("OnShow", function(self)
            if C_Timer then
                C_Timer.After(0, function() ApplyTransmogSkin(self) end)
            else
                ApplyTransmogSkin(self)
            end
        end)
        frame._ktTransmogRefreshHooked = true
    end
end

S.SkinFuncs["Blizzard_Transmog"] = SkinTransmog
S.SkinFuncs["Blizzard_Wardrobe"] = SkinTransmog

hooksecurefunc(S, "OnEnable", function()
    if _G.TransmogFrame or _G.WardrobeTransmogFrame then SkinTransmog() end
end)
