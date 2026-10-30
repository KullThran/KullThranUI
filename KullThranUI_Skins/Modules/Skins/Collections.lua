local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local hooksecurefunc = hooksecurefunc
local ipairs, pairs, type = ipairs, pairs, type
local unpack = unpack or table.unpack
local CreateFrame = CreateFrame
local C_Timer = C_Timer

local function Accent()
    return S:GetAccentColor()
end

local function IsUIObject(object)
    local objectType = type(object)
    return (objectType == "table" or objectType == "userdata")
        and type(object.GetObjectType) == "function"
end

local function HideRegion(region)
    if not region then return end
    if region.SetAlpha then region:SetAlpha(0) end
end

local function SetWhiteFont(fontString)
    if not IsUIObject(fontString) then return end
    S:HandleFont(fontString)
    if fontString.SetTextColor then fontString:SetTextColor(1, 1, 1) end
end

local function EnsureBackdrop(frame, inset)
    if not IsUIObject(frame) then return nil end
    if frame.backdrop then return frame.backdrop end
    S:CreateBackdrop(frame, true)
    if frame.backdrop then return frame.backdrop end

    local parent = frame.GetParent and frame:GetParent()
    if not IsUIObject(parent) then return nil end

    local backdrop = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    backdrop:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    inset = inset or 1
    backdrop:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    backdrop:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset)
    backdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    backdrop:SetBackdropColor(0.035, 0.035, 0.045, 0.94)
    backdrop:SetBackdropBorderColor(0, 0, 0, 1)
    backdrop:SetShown(frame:IsShown())
    frame:HookScript("OnShow", function() backdrop:Show() end)
    frame:HookScript("OnHide", function() backdrop:Hide() end)
    frame.backdrop = backdrop
    return backdrop
end

local function SetPanelBackdrop(frame, alpha)
    if not frame then return end
    S:StripTextures(frame)
    if not frame.backdrop then S:CreateBackdrop(frame, true) end
    if frame.backdrop then
        frame.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        if S.ApplyKuiSurface then
            -- Keep the artwork inside the helper backdrop so its border stays
            -- above the surface while the texture fills the content panel.
            S:ApplyKuiSurface(frame.backdrop, { flat = frame.backdrop, washAlpha = 0.55 })
        else
            S:RegisterBlizzardWindowBackground(frame.backdrop)
        end
    end
end

local function ApplyCollectionSurface(frame, washAlpha)
    if not IsUIObject(frame) or not S.ApplyKuiSurface then return end
    S:ApplyKuiSurface(frame, {
        flat = frame.backdrop,
        washAlpha = washAlpha or 0.55,
    })
end

local SetOverlayBorderColor

local function SetCollectionItemTextWhite(button)
    if not button then return end
    local seen = {}
    for _, key in ipairs({
        "Name", "name", "Label", "label", "Title", "title",
        "SubName", "subName", "Source", "source", "Level", "level",
        "Special", "special", "OwnedText", "CollectedText",
    }) do
        local text = button[key]
        if IsUIObject(text) and not seen[text] then
            seen[text] = true
            S:HandleFont(text)
            if text.SetTextColor then text:SetTextColor(1, 1, 1, 1) end
        end
    end

    local fontString = button.GetFontString and button:GetFontString()
    if IsUIObject(fontString) and not seen[fontString] then
        S:HandleFont(fontString)
        if fontString.SetTextColor then fontString:SetTextColor(1, 1, 1, 1) end
    end
end

local function UpdateCollectionItemState(button)
    if not button then return end
    local selectionTexture = button._ktSelectionTexture or button.selectedTexture or button.SelectedTexture
    local selected = button.selected == true or (selectionTexture and selectionTexture.IsShown
        and selectionTexture:IsShown())
    if button._ktSelectedOverlay then button._ktSelectedOverlay:SetShown(selected == true) end
    if button._ktSelectionBar then button._ktSelectionBar:SetShown(selected == true) end
    local color = Accent()
    SetOverlayBorderColor(button,
        selected and color[1] or 0,
        selected and color[2] or 0,
        selected and color[3] or 0,
        1)
    if button.backdrop then
        if selected then
            button.backdrop:SetBackdropBorderColor(color[1], color[2], color[3], 1)
            button.backdrop:SetBackdropColor(0.105, 0.105, 0.12, 1)
        else
            button.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
            button.backdrop:SetBackdropColor(0.035, 0.035, 0.045, 0.94)
        end
    end
    -- Text never inherits the accent: on bright or saturated themes it loses
    -- too much contrast against the selected overlay. Reapply this on every
    -- state update because ScrollBox recycles its buttons between entries.
    SetCollectionItemTextWhite(button)
    local icon = button.Icon or button.icon or (button.IconFrame and button.IconFrame.Icon)
    if icon and icon.backdrop then
        if selected then icon.backdrop:SetBackdropBorderColor(color[1], color[2], color[3], 1)
        else icon.backdrop:SetBackdropBorderColor(0, 0, 0, 1) end
    end
end

local function SkinStatusBar(bar)
    if not bar then return end
    S:HandleStatusBar(bar)
    if bar.SetStatusBarColor then
        local color = Accent()
        bar:SetStatusBarColor(color[1], color[2], color[3], 0.9)
    end
end

SetOverlayBorderColor = function(frame, r, g, b, a)
    if not (frame and frame._ktModernBorder) then return end
    for _, edge in pairs(frame._ktModernBorder) do
        edge:SetColorTexture(r, g, b, a or 1)
    end
end

local function EnsureOverlayBorder(frame, useAccent)
    if not IsUIObject(frame) then return end
    if not frame._ktModernBorder then
        local edges = {}
        edges.top = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        edges.top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        edges.top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        edges.top:SetHeight(1)
        edges.bottom = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        edges.bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        edges.bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        edges.bottom:SetHeight(1)
        edges.left = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        edges.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        edges.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
        edges.left:SetWidth(1)
        edges.right = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        edges.right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        edges.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        edges.right:SetWidth(1)
        frame._ktModernBorder = edges
    end
    if useAccent then
        local color = Accent()
        SetOverlayBorderColor(frame, color[1], color[2], color[3], 1)
    else
        SetOverlayBorderColor(frame, 0, 0, 0, 1)
    end
end

local function SkinActionButton(button)
    if not IsUIObject(button) then return end
    S:HandleButton(button)
    EnsureBackdrop(button, 0)
    EnsureOverlayBorder(button, true)
    SetWhiteFont(button.Text or (button.GetFontString and button:GetFontString()))
    if not button._ktModernActionHooks then
        button:HookScript("OnEnter", function(self)
            SetOverlayBorderColor(self, 1, 1, 1, 1)
        end)
        button:HookScript("OnLeave", function(self)
            local color = Accent()
            SetOverlayBorderColor(self, color[1], color[2], color[3], 1)
        end)
        button._ktModernActionHooks = true
    end
end

local function SkinModernScrollBar(scrollBar)
    if not IsUIObject(scrollBar) then return end
    S:HandleScrollBar(scrollBar)

    if not scrollBar._ktModernTrack then
        local track = scrollBar:CreateTexture(nil, "BACKGROUND", nil, 2)
        track:SetColorTexture(0.015, 0.015, 0.02, 0.95)
        track:SetPoint("TOP", scrollBar, "TOP", 0, -2)
        track:SetPoint("BOTTOM", scrollBar, "BOTTOM", 0, 2)
        track:SetWidth(5)
        scrollBar._ktModernTrack = track
    end

    local thumb = scrollBar.Track and scrollBar.Track.Thumb
    if IsUIObject(thumb) and not thumb._ktModernFill then
        local fill = thumb:CreateTexture(nil, "ARTWORK", nil, 7)
        local color = Accent()
        fill:SetColorTexture(color[1], color[2], color[3], 0.9)
        fill:SetPoint("TOPLEFT", thumb, "TOPLEFT", 2, -2)
        fill:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", -2, 2)
        thumb._ktModernFill = fill
        EnsureOverlayBorder(thumb, false)
    elseif scrollBar.ThumbTexture then
        local color = Accent()
        scrollBar.ThumbTexture:SetColorTexture(color[1], color[2], color[3], 0.9)
        scrollBar.ThumbTexture:SetWidth(7)
    end
end

local function SkinPagingFrame(frame)
    if not frame then return end
    local controls = frame.PagingControls or frame
    for _, key in ipairs({
        "PrevPageButton", "NextPageButton", "PreviousPageButton", "NextButton",
        "PrevButton", "PreviousButton",
    }) do
        local button = controls[key]
        if IsUIObject(button) and not button._ktCollectionPagingSkinned then
            S:CreateBackdrop(button, true)
            if button.backdrop then
                button.backdrop:SetBackdropColor(0.04, 0.04, 0.05, 0.72)
                button.backdrop:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)
                S:SetInside(button.backdrop, button, 4)
            end
            local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
            if highlight then
                local color = Accent()
                highlight:SetVertexColor(color[1], color[2], color[3], 0.75)
            end
            button._ktCollectionPagingSkinned = true
        end
    end
    if IsUIObject(controls.PageNumber) then S:HandleFont(controls.PageNumber) end
    if IsUIObject(controls.PageText) then S:HandleFont(controls.PageText) end
end

local function SkinSquareControl(frame, explicitIcon)
    if not IsUIObject(frame) or frame._ktCollectionSquareSkinned then return end

    local frameName = frame.GetName and frame:GetName()
    local icon = explicitIcon or frame.Icon or frame.icon or frame.texture
        or (frameName and (_G[frameName .. "Icon"] or _G[frameName .. "IconTexture"]))

    if not icon and frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture")
                and region ~= frame.Border and region ~= frame.HighlightTexture
                and region ~= frame.UnspentGlyphsHighlight
            then
                icon = region
                break
            end
        end
    end

    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture")
                and region ~= icon and region ~= frame.UnspentGlyphsHighlight
            then
                HideRegion(region)
            end
        end
    end
    HideRegion(frame.Border)
    HideRegion(frame.PushedTexture)
    if icon then S:HandleIcon(icon, true) end

    for _, key in ipairs({ "Label", "label", "Text", "Name" }) do
        if IsUIObject(frame[key]) then SetWhiteFont(frame[key]) end
    end
    if frameName then
        SetWhiteFont(_G[frameName .. "Label"])
        SetWhiteFont(_G[frameName .. "Text"])
    end
    frame._ktCollectionSquareSkinned = true
end

local function SkinSpellFrame(frame)
    if not IsUIObject(frame) then return end
    local frameName = frame.GetName and frame:GetName()
    local button = frame.Button or frame.SpellButton
        or (frameName and (_G[frameName .. "Button"] or _G[frameName .. "SpellButton"]))
    local icon = frame.Icon or frame.icon
        or (button and (button.Icon or button.icon))
        or (frameName and _G[frameName .. "Icon"])

    if IsUIObject(button) then
        SkinSquareControl(button, icon)
    else
        SkinSquareControl(frame, icon)
    end
    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture")
                and region ~= icon and region ~= frame.UnspentGlyphsHighlight
            then
                HideRegion(region)
            end
        end
    end
    SetWhiteFont(frame.Label or frame.label)
end

local function SetTopControlOffset(frame, yOffset)
    if not IsUIObject(frame) or frame._ktTopControlAdjusted then return end
    local point, relativeTo, relativePoint, xOffset = frame:GetPoint(1)
    if not point then return end
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, xOffset or 0, yOffset)
    frame._ktTopControlAdjusted = true
end

local function ApplyFlatTabState(tab, selected)
    if not (tab and tab.backdrop) then return end
    tab.KT_Selected = selected
    local color = Accent()
    if selected then
        tab.backdrop:SetBackdropColor(0.09, 0.09, 0.105, 1)
        tab.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        SetOverlayBorderColor(tab, color[1], color[2], color[3], 1)
    else
        tab.backdrop:SetBackdropColor(0.035, 0.035, 0.045, 0.96)
        tab.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        SetOverlayBorderColor(tab, 0, 0, 0, 1)
    end
end

local function UpdateCollectionTab(tab, journal)
    if not (tab and journal) then return end
    local selected = CollectionsJournal_GetTab and CollectionsJournal_GetTab(journal) == tab:GetID()
    ApplyFlatTabState(tab, selected)
end

local function UpdateAllCollectionTabs(journal)
    if not journal then return end
    for i = 1, 6 do
        UpdateCollectionTab(journal["Tab" .. i] or _G["CollectionsJournalTab" .. i], journal)
    end
end

local function SkinCollectionTab(tab, journal)
    if not IsUIObject(tab) then return end
    if not tab._ktCollectionFlatTab then
        S:StripTextures(tab)
        S:HandleButton(tab)
        if tab.backdrop then
            tab.backdrop:ClearAllPoints()
            tab.backdrop:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -1)
            tab.backdrop:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
        end
        EnsureOverlayBorder(tab, false)
        local text = tab.Text or (tab.GetFontString and tab:GetFontString())
        SetWhiteFont(text)
        tab:HookScript("OnClick", function(self)
            C_Timer.After(0, function()
                UpdateAllCollectionTabs(journal)
            end)
        end)
        tab._ktCollectionFlatTab = true
    end
    UpdateCollectionTab(tab, journal)
end

local function UpdateWardrobeTabs(frame)
    if not frame then return end
    local selected = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(frame)
    ApplyFlatTabState(frame.ItemsTab, selected == 1)
    ApplyFlatTabState(frame.SetsTab, selected == 2)
end

local function SkinWardrobeTab(tab, frame)
    if not IsUIObject(tab) then return end
    if not tab._ktCollectionFlatTab then
        S:StripTextures(tab)
        S:HandleButton(tab)
        if tab.backdrop then
            tab.backdrop:ClearAllPoints()
            tab.backdrop:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -1)
            tab.backdrop:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
        end
        EnsureOverlayBorder(tab, false)
        SetWhiteFont(tab.Text or (tab.GetFontString and tab:GetFontString()))
        tab:HookScript("OnClick", function()
            C_Timer.After(0, function() UpdateWardrobeTabs(frame) end)
        end)
        tab._ktCollectionFlatTab = true
    end
end

local function SkinIconButton(button)
    if not IsUIObject(button) then return end
    if button._ktCollectionItemSkinned then
        UpdateCollectionItemState(button)
        return
    end
    EnsureBackdrop(button, 1)
    if button.backdrop then
        button.backdrop:SetBackdropColor(0.035, 0.035, 0.045, 0.94)
        button.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
        S:SetInside(button.backdrop, button, 1)
    end

    HideRegion(button.background or button.Background)
    HideRegion(button.iconBorder or button.IconBorder)
    HideRegion(button.slotFrameCollected)
    HideRegion(button.slotFrameUncollected)
    HideRegion(button.slotFrameUncollectedInnerGlow)

    local selectionTexture = button.selectedTexture or button.SelectedTexture
    button._ktSelectionTexture = selectionTexture
    if selectionTexture then
        if not button._ktSelectedOverlay then
            local selected = button:CreateTexture(nil, "BACKGROUND", nil, 1)
            local color = Accent()
            selected:SetColorTexture(color[1], color[2], color[3], 0.30)
            selected:SetAllPoints(button)
            button._ktSelectedOverlay = selected

            local bar = button:CreateTexture(nil, "OVERLAY", nil, 7)
            bar:SetColorTexture(color[1], color[2], color[3], 1)
            bar:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -1)
            bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 1)
            bar:SetWidth(3)
            button._ktSelectionBar = bar
        end
        HideRegion(selectionTexture)
        EnsureOverlayBorder(button, false)
        if not button._ktSelectionHooks then
            if type(selectionTexture.Show) == "function" then
                hooksecurefunc(selectionTexture, "Show", function() UpdateCollectionItemState(button) end)
            end
            if type(selectionTexture.Hide) == "function" then
                hooksecurefunc(selectionTexture, "Hide", function() UpdateCollectionItemState(button) end)
            end
            if type(selectionTexture.SetShown) == "function" then
                hooksecurefunc(selectionTexture, "SetShown", function() UpdateCollectionItemState(button) end)
            end
            button._ktSelectionHooks = true
        end
    end

    local icon = button.Icon or button.icon or button.iconTexture or button.texture
        or (button.IconFrame and button.IconFrame.Icon)
        or (button.Button and (button.Button.Icon or button.Button.icon))
    if icon and icon.IsObjectType and icon:IsObjectType("Texture") then
        S:HandleIcon(icon, true)
    end
    if button.iconTextureUncollected then
        button.iconTextureUncollected:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    for _, key in ipairs({
        "Name", "name", "Label", "label", "SubName", "subName", "Source", "source",
        "Level", "level", "Special", "special", "OwnedText", "CollectedText",
    }) do
        if button[key] then SetWhiteFont(button[key]) end
    end

    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
        local color = Accent()
        highlight:SetColorTexture(color[1], color[2], color[3], 0.18)
        if button.backdrop then S:SetInside(highlight, button.backdrop) end
    end
    button._ktCollectionItemSkinned = true
    UpdateCollectionItemState(button)
end

local function ForEachScrollFrame(scrollBox, callback)
    if not (scrollBox and callback) then return end
    local function Apply(self)
        if self.ForEachFrame then self:ForEachFrame(callback) end
    end
    Apply(scrollBox)
    if type(scrollBox.Update) == "function" and not scrollBox._ktCollectionsUpdateHook then
        hooksecurefunc(scrollBox, "Update", Apply)
        scrollBox._ktCollectionsUpdateHook = true
    end
end

local function SkinChildButtons(frame, depth)
    if not (IsUIObject(frame) and frame.GetChildren) or (depth or 0) < 1 then return end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsObjectType("Button") or child:IsObjectType("CheckButton") then
            SkinIconButton(child)
        elseif child.GetChildren then
            SkinChildButtons(child, depth - 1)
        end
    end
end

local function SkinCommonControls(frame)
    if not frame then return end
    local searchBox = frame.SearchBox or frame.searchBox
    if searchBox then S:HandleEditBox(searchBox) end
    for _, key in ipairs({
        "FilterDropdown", "FilterButton", "ClassDropdown", "WeaponDropdown",
        "VariantSetsDropdown", "TypeDropdown",
    }) do
        if IsUIObject(frame[key]) then S:HandleDropDownBox(frame[key]) end
    end
    if frame.ScrollBar then SkinModernScrollBar(frame.ScrollBar) end
    if frame.scrollBar then SkinModernScrollBar(frame.scrollBar) end
    SkinStatusBar(frame.ProgressBar or frame.progressBar)
    SkinPagingFrame(frame.PagingFrame or frame.PagingControls)
end

local function SkinMountJournal()
    local frame = _G.MountJournal
    if not frame then return end
    SkinCommonControls(frame)
    SetPanelBackdrop(frame.LeftInset)
    SetPanelBackdrop(frame.BottomLeftInset, 0.96)
    SetPanelBackdrop(frame.RightInset, 0.96)
    SetPanelBackdrop(frame.MountCount, 0.96)
    SetPanelBackdrop(frame.MountDisplay, 0.96)
    if frame.MountCount then
        SetWhiteFont(frame.MountCount.Label)
        SetWhiteFont(frame.MountCount.Count)
    end

    SkinSpellFrame(frame.SummonRandomFavoriteSpellFrame)
    SetTopControlOffset(frame.SummonRandomFavoriteSpellFrame, -28)
    SkinSquareControl(frame.ToggleDynamicFlightFlyoutButton)
    SetPanelBackdrop(frame.DynamicFlightFlyoutPopup, 0.98)
    if frame.DynamicFlightFlyoutPopup then
        SkinSquareControl(frame.DynamicFlightFlyoutPopup.OpenDynamicFlightSkillTreeButton)
        SkinSquareControl(frame.DynamicFlightFlyoutPopup.DynamicFlightModeButton)
    end

    if frame.BottomLeftInset and frame.BottomLeftInset.SlotButton then
        local slot = frame.BottomLeftInset.SlotButton
        HideRegion(slot.ItemBorder)
        HideRegion(slot.SlotBorder)
        HideRegion(slot.SlotBorderOpen)
        SkinSquareControl(slot, slot.ItemIcon)
        SetWhiteFont(frame.BottomLeftInset.SlotLabel)
        SetWhiteFont(frame.BottomLeftInset.SlotRequirementLabel)
    end
    if frame.MountDisplay and frame.MountDisplay.InfoButton then
        local info = frame.MountDisplay.InfoButton
        if info.Icon then S:HandleIcon(info.Icon, true) end
        for _, key in ipairs({ "Name", "Source", "Lore" }) do
            if info[key] then S:HandleFont(info[key]) end
        end
    end
    if frame.MountDisplay then
        S:StripTextures(frame.MountDisplay.ShadowOverlay)
        if frame.MountDisplay.ModelScene and frame.MountDisplay.ModelScene.ControlFrame then
            local toggle = frame.MountDisplay.ModelScene.ControlFrame.TogglePlayer
            if toggle then
                S:HandleCheckBox(toggle)
                SetWhiteFont(toggle.TogglePlayerText)
            end
        end
    end
    if frame.MountButton then SkinActionButton(frame.MountButton) end
    ForEachScrollFrame(frame.ScrollBox, SkinIconButton)
end

local function SkinPetLoadoutSlot(slot)
    if not slot then return end
    EnsureBackdrop(slot, 1)
    if slot.backdrop then
        slot.backdrop:SetBackdropColor(0.03, 0.03, 0.035, 0.94)
        slot.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
    end
    HideRegion(slot.BG or slot.bg)
    HideRegion(slot.shadows)
    HideRegion(slot.iconBorder)
    HideRegion(slot.qualityBorder)
    HideRegion(slot.levelBG)
    local pet = slot.pet or slot.Pet
    local icon = slot.icon or slot.Icon or (pet and (pet.icon or pet.Icon))
    if icon then S:HandleIcon(icon, true) end
    SetWhiteFont(slot.name)
    SetWhiteFont(slot.subName)
    SetWhiteFont(slot.level)
    if slot.healthFrame then
        SkinStatusBar(slot.healthFrame.healthBar)
        SetWhiteFont(slot.healthFrame.healthValue)
    end
    SkinStatusBar(slot.xpBar or slot.XPBar)
    for i = 1, 3 do
        local spell = slot["spell" .. i]
        if spell then SkinSquareControl(spell, spell.icon) end
    end
end

local function SkinPetJournal()
    local frame = _G.PetJournal
    if not frame then return end
    SkinCommonControls(frame)
    SetPanelBackdrop(frame.LeftInset)
    SetPanelBackdrop(frame.PetCardInset, 0.96)
    SetPanelBackdrop(frame.RightInset, 0.96)
    SetPanelBackdrop(frame.PetCount, 0.96)
    if frame.PetCount then
        SetWhiteFont(frame.PetCount.Label)
        SetWhiteFont(frame.PetCount.Count)
    end

    SkinSpellFrame(frame.HealPetSpellFrame)
    SkinSpellFrame(frame.SummonRandomPetSpellFrame)
    SetTopControlOffset(frame.HealPetSpellFrame, -28)
    SetTopControlOffset(frame.SummonRandomPetSpellFrame, -28)
    S:StripTextures(frame.loadoutBorder)

    if frame.FindBattleButton then SkinActionButton(frame.FindBattleButton) end
    if frame.SummonButton then SkinActionButton(frame.SummonButton) end
    if frame.AchievementStatus then SkinSquareControl(frame.AchievementStatus, frame.AchievementStatus.icon) end
    if frame.SpellSelect then
        SetPanelBackdrop(frame.SpellSelect, 0.98)
        SkinSquareControl(frame.SpellSelect.Spell1, frame.SpellSelect.Spell1 and frame.SpellSelect.Spell1.icon)
        SkinSquareControl(frame.SpellSelect.Spell2, frame.SpellSelect.Spell2 and frame.SpellSelect.Spell2.icon)
    end
    ForEachScrollFrame(frame.ScrollBox, SkinIconButton)

    local loadout = frame.Loadout
    if loadout then
        for i = 1, 3 do SkinPetLoadoutSlot(loadout["Pet" .. i]) end
    end

    local card = frame.PetCard
    if card then
        SetPanelBackdrop(card, 0.94)
        if card.PetInfo and card.PetInfo.icon then S:HandleIcon(card.PetInfo.icon, true) end
        if card.PetInfo then
            HideRegion(card.PetInfo.qualityBorder)
            HideRegion(card.PetInfo.levelBG)
            SetWhiteFont(card.PetInfo.name)
            SetWhiteFont(card.PetInfo.subName)
            SetWhiteFont(card.PetInfo.level)
        end
        if card.HealthFrame then SkinStatusBar(card.HealthFrame.healthBar) end
        SkinStatusBar(card.xpBar)
        for i = 1, 6 do
            local spell = card["spell" .. i]
            if spell then SkinSquareControl(spell, spell.icon) end
        end
    end
end

local function SkinStaticSpellButtons(frame, count)
    if not frame then return end
    for i = 1, count do
        SkinIconButton(frame["spellButton" .. i] or frame["SpellButton" .. i])
    end
end

local function SkinToyBox()
    local frame = _G.ToyBox
    if not frame then return end
    SkinCommonControls(frame)
    local iconsFrame = frame.IconsFrame or frame.iconsFrame
    SetPanelBackdrop(iconsFrame, 0.96)
    SkinStaticSpellButtons(iconsFrame, 18)
end

local function SkinHeirlooms()
    local frame = _G.HeirloomsJournal
    if not frame then return end
    ApplyCollectionSurface(frame)
    SkinCommonControls(frame)
    local iconsFrame = frame.iconsFrame or frame.IconsFrame
    SetPanelBackdrop(iconsFrame, 0.96)
    if frame.heirloomEntryFrames then
        for _, button in pairs(frame.heirloomEntryFrames) do SkinIconButton(button) end
    end
    if frame.heirloomHeaderFrames then
        for _, header in pairs(frame.heirloomHeaderFrames) do
            if header.text then SetWhiteFont(header.text) end
        end
    end
end

local function DarkenNativeBackground(frame, alpha)
    if not IsUIObject(frame) or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            if not S:IsKuiSurfaceRegion(region) then
                region:SetAlpha(alpha or 0.12)
                if region.SetVertexColor then region:SetVertexColor(0.42, 0.42, 0.46, 1) end
            end
        end
    end
end

local function SoftenWardrobeModel(model)
    if not IsUIObject(model) then return end
    HideRegion(model.Border)
    HideRegion(model.DisabledOverlay)
    if model.GetRegions then
        for _, region in ipairs({ model:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture")
                and region.GetDrawLayer and region:GetDrawLayer() == "BACKGROUND"
            then
                region:SetAlpha(0.24)
                if region.SetVertexColor then region:SetVertexColor(0.48, 0.48, 0.52, 1) end
            end
        end
    end
    if model.backdrop then model.backdrop:SetBackdropColor(0, 0, 0, 0.12) end
    EnsureOverlayBorder(model, false)
end

local function SkinWardrobe()
    local frame = _G.WardrobeCollectionFrame
    if not frame then return end
    ApplyCollectionSurface(frame)
    SkinCommonControls(frame)
    SkinWardrobeTab(frame.ItemsTab, frame)
    SkinWardrobeTab(frame.SetsTab, frame)
    UpdateWardrobeTabs(frame)
    if frame.SearchBox and frame.SearchBox.ProgressFrame then
        SetPanelBackdrop(frame.SearchBox.ProgressFrame, 0.98)
        SkinStatusBar(frame.SearchBox.ProgressFrame.ProgressBar)
    end

    local items = frame.ItemsCollectionFrame
    if items then
        ApplyCollectionSurface(items, 0.58)
        DarkenNativeBackground(items, 0.12)
        SkinCommonControls(items)
        if items.Models then
            for _, model in pairs(items.Models) do
                SoftenWardrobeModel(model)
            end
        end
        if items.SlotsFrame and items.SlotsFrame.Buttons then
            for _, button in pairs(items.SlotsFrame.Buttons) do
                HideRegion(button.SelectedTexture)
                SkinSquareControl(button, button.NormalTexture)
            end
        end
    end

    local sets = frame.SetsCollectionFrame
    if sets then
        ApplyCollectionSurface(sets, 0.58)
        SetPanelBackdrop(sets.LeftInset, 0.96)
        ApplyCollectionSurface(sets.RightInset, 0.58)
        DarkenNativeBackground(sets.RightInset, 0.12)
        if sets.ListContainer then
            SkinModernScrollBar(sets.ListContainer.ScrollBar)
            ForEachScrollFrame(sets.ListContainer.ScrollBox, SkinIconButton)
        end
        if sets.DetailsFrame then
            local details = sets.DetailsFrame
            HideRegion(details.ModelFadeTexture)
            HideRegion(details.IconRowBackground)
            SetWhiteFont(details.Name)
            SetWhiteFont(details.LongName)
            SetWhiteFont(details.Label)
            SkinCommonControls(details)
        end
    end
end

local function SkinWarbandScenes()
    local frame = _G.WarbandSceneJournal
    if not frame then return end
    ApplyCollectionSurface(frame)
    local iconsFrame = frame.IconsFrame
    SetPanelBackdrop(iconsFrame, 0.96)
    if not iconsFrame then return end

    local controls = iconsFrame.Icons and iconsFrame.Icons.Controls
    if controls then
        if controls.ShowOwned and controls.ShowOwned.Checkbox then
            S:HandleCheckBox(controls.ShowOwned.Checkbox)
            if controls.ShowOwned.Text then S:HandleFont(controls.ShowOwned.Text) end
        end
        SkinPagingFrame(controls.PagingControls)
    end

    local icons = iconsFrame.Icons
    if icons and icons.ViewFrames then
        for _, view in pairs(icons.ViewFrames) do
            EnsureBackdrop(view, 1)
            if view.backdrop then
                view.backdrop:SetBackdropColor(0.025, 0.025, 0.03, 0.96)
                view.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
            end
            SkinChildButtons(view, 3)
        end
    end
end

local function HideFrameArt(object)
    if not IsUIObject(object) then return end
    if object.SetAlpha then object:SetAlpha(0) end
    if object.Hide then object:Hide() end
    if object.Show and not object._ktCollectionsHideHook then
        hooksecurefunc(object, "Show", function(self)
            if self.SetAlpha then self:SetAlpha(0) end
        end)
        object._ktCollectionsHideHook = true
    end
end

local function SkinModernCollectionsShell(journal)
    if not journal then return end

    if journal.GetRegions then
        for _, region in ipairs({ journal:GetRegions() }) do
            local keep = S:IsKuiSurfaceRegion(region) or region == journal._ktModernSolidBackground
                or region == journal._ktModernHeader
                or region == journal._ktModernHeaderDivider
            if not keep and journal._ktModernBorder then
                for _, edge in pairs(journal._ktModernBorder) do
                    if region == edge then keep = true break end
                end
            end
            if not keep and region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetAlpha(0)
            end
        end
    end

    local data = S:GetFFD(journal)
    HideFrameArt(data.atlasBorderFrame)
    HideFrameArt(journal.NineSlice)
    HideFrameArt(journal.PortraitContainer)
    HideFrameArt(journal.PortraitFrame)
    HideFrameArt(journal.Portrait)
    HideFrameArt(journal.Bg)
    HideFrameArt(journal.TitleBg)
    HideFrameArt(journal.TopTileStreaks)
    HideFrameArt(_G.CollectionsJournalPortrait)
    HideFrameArt(_G.CollectionsJournalPortraitFrame)

    if journal.TitleContainer then S:StripTextures(journal.TitleContainer) end
    if journal.Header then S:StripTextures(journal.Header) end

    if not journal._ktModernSolidBackground then
        local bg = journal:CreateTexture(nil, "BACKGROUND", nil, -8)
        local color = S:GetWindowBackgroundColor(false)
        bg:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
        bg:SetAllPoints(journal)
        journal._ktModernSolidBackground = bg

        local header = journal:CreateTexture(nil, "BORDER", nil, 6)
        header:SetColorTexture(0, 0, 0, 0.35)
        header:SetPoint("TOPLEFT", journal, "TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", journal, "TOPRIGHT", -1, -1)
        header:SetHeight(18)
        journal._ktModernHeader = header

        local divider = journal:CreateTexture(nil, "ARTWORK", nil, 6)
        local accent = Accent()
        divider:SetColorTexture(accent[1], accent[2], accent[3], 0.9)
        divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
        divider:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
        divider:SetHeight(1)
        journal._ktModernHeaderDivider = divider
    end

    S:ApplyKuiSurface(journal, { flat = journal._ktModernSolidBackground })
    journal._ktModernHeader:SetAlpha(1)
    journal._ktModernHeaderDivider:SetAlpha(1)
    EnsureOverlayBorder(journal, true)
    S:RegisterBlizzardWindowBorder(journal, function(self, enabled, color)
        SetOverlayBorderColor(self, color[1], color[2], color[3], color[4] or 1)
        for _, edge in pairs(self._ktModernBorder or {}) do
            edge:SetAlpha(enabled and 1 or 0)
        end
    end)
    if journal.TitleText then SetWhiteFont(journal.TitleText) end
    if journal.CloseButton then S:HandleCloseButton(journal.CloseButton) end
end

local function SkinCollections()
    if not (S.db.enable and S.db.collections) then return end
    local journal = _G.CollectionsJournal
    if not journal then return end

    S:HandlePortraitFrame(journal)
    SkinModernCollectionsShell(journal)
    for i = 1, 6 do
        local tab = journal["Tab" .. i] or _G["CollectionsJournalTab" .. i]
        SkinCollectionTab(tab, journal)
    end

    if not journal._ktCollectionTabStateHook and type(_G.CollectionsJournal_UpdateSelectedTab) == "function" then
        hooksecurefunc("CollectionsJournal_UpdateSelectedTab", function(self)
            UpdateAllCollectionTabs(self)
        end)
        journal._ktCollectionTabStateHook = true
    end

    SkinMountJournal()
    SkinPetJournal()
    SkinToyBox()
    SkinHeirlooms()
    SkinWardrobe()
    SkinWarbandScenes()

    if not journal._ktCollectionsShowHook then
        journal:HookScript("OnShow", function()
            SkinModernCollectionsShell(journal)
            SkinMountJournal()
            SkinPetJournal()
            SkinToyBox()
            SkinHeirlooms()
            SkinWardrobe()
            SkinWarbandScenes()
        end)
        journal._ktCollectionsShowHook = true
    end
end

S.SkinFuncs["Blizzard_Collections"] = SkinCollections
