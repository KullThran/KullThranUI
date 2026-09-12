local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc
local pairs = pairs
local unpack = unpack

local function KT_TabTextureCoords(tex, x1)
    if tex and x1 ~= 0.16001 then
        tex:SetTexCoord(0.16001, 0.86, 0.16, 0.86)
    end
end

local function UpdateSidebarTabState(tab)
    if not (tab and tab.backdrop) then
        return
    end

    local selected = tab.GetChecked and tab:GetChecked()

    if tab.Hider then
        tab.Hider:SetAlpha(0)
        tab.Hider:Hide()
    end

    if tab.Icon then
        tab.Icon:SetAlpha(1)
        tab.Icon:Show()
        tab.Icon:SetDesaturated(false)
        tab.Icon:SetVertexColor(1, 1, 1, 1)
        tab.Icon:SetDrawLayer("OVERLAY")
    end

    if selected then
        local accent = S:GetAccentColor()
        tab.backdrop:SetBackdropBorderColor(accent[1], accent[2], accent[3], 1)
    else
        tab.backdrop:SetBackdropBorderColor(0, 0, 0, 1)
    end
end

local function FixSidebarTabCoords()
    local index = 1
    local tab = _G["PaperDollSidebarTab"..index]

    while tab do
        if not tab.backdrop then
            S:CreateBackdrop(tab)
            tab.backdrop:SetBackdropBorderColor(0, 0, 0, 1)

            if tab.Icon then
                tab.Icon:SetAllPoints()
                tab.Icon:SetAlpha(1)
                tab.Icon:SetDesaturated(false)
                tab.Icon:SetVertexColor(1, 1, 1, 1)
                tab.Icon:SetDrawLayer("OVERLAY")
            end

            if tab.Highlight then
                tab.Highlight:SetColorTexture(1, 1, 1, 0.15)
                tab.Highlight:SetAllPoints()
                tab.Highlight:SetDrawLayer("HIGHLIGHT")
            end

            if tab.Hider then
                tab.Hider:SetTexture(nil)
                tab.Hider:SetAlpha(0)
                tab.Hider:SetAllPoints(tab.backdrop or tab)
                tab.Hider:Hide()
            end

            if tab.TabBg then
                tab.TabBg:SetTexture("")
                tab.TabBg:SetAlpha(0)
            end

            if not tab._ktSidebarHooks then
                tab:HookScript("OnEnter", function(self)
                    if self.backdrop and not (self.GetChecked and self:GetChecked()) then
                        self.backdrop:SetBackdropBorderColor(1, 1, 1, 1)
                    end
                end)
                tab:HookScript("OnLeave", UpdateSidebarTabState)
                tab:HookScript("OnShow", UpdateSidebarTabState)
                tab._ktSidebarHooks = true
            end

            if index == 1 then
                for _, region in pairs({ tab:GetRegions() }) do
                    if region and region.SetTexCoord then
                        region:SetTexCoord(0.16, 0.86, 0.16, 0.86)
                        hooksecurefunc(region, "SetTexCoord", KT_TabTextureCoords)
                    end
                end
            end
        end

        UpdateSidebarTabState(tab)

        index = index + 1
        tab = _G["PaperDollSidebarTab"..index]
    end
end

local function SkinArmory()
    if not (S.db.enable and S.db.armory) then return end

    local ArmoryFrame = _G.CharacterFrame
    if not ArmoryFrame then return end

    -- 1. Marco Principal
    S:HandlePortraitFrame(ArmoryFrame)
    
    -- Limpieza de texturas de fondo adicionales
    if ArmoryFrame.Inset then S:StripTextures(ArmoryFrame.Inset) end
    if ArmoryFrame.Background then ArmoryFrame.Background:Hide() end
    if ArmoryFrame.Bg then ArmoryFrame.Bg:Hide() end
    if _G.CharacterFrameBg then _G.CharacterFrameBg:Hide() end
    if _G.CharacterModelFrameBackgroundOverlay then _G.CharacterModelFrameBackgroundOverlay:Hide() end

    -- 2. Pestañas Superiores
    for i = 1, 3 do
        local tab = _G["CharacterFrameTab"..i]
        if tab then S:HandleTab(tab) end
    end

    -- 3. Slots de Equipo (Cabeza, Hombros, etc.)
    local slots = {
        "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot",
        "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
        "MainHandSlot", "SecondaryHandSlot"
    }

    for _, slotName in pairs(slots) do
        local slot = _G["Character"..slotName]
        if slot then
            local icon = slot.icon or _G[slot:GetName().."IconTexture"]
            S:StripTextures(slot, nil, icon)
            S:CreateBackdrop(slot)
            slot.backdrop:SetBackdropBorderColor(0, 0, 0, 1) -- Borde negro para iconos
            S:SetInside(slot.backdrop, slot)
            
            if icon then
                icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                icon:SetAlpha(1) -- Restaurar visibilidad del icono
                S:SetInside(icon, slot.backdrop)
            end
            
            slot:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
            slot:GetHighlightTexture():SetBlendMode("ADD")
            slot:GetHighlightTexture():SetAllPoints(slot.backdrop)
        end
    end

    -- 4. Pestañas Laterales (Stats, Titles, Sets)
    if _G.PaperDollSidebarTabs then
        S:StripTextures(_G.PaperDollSidebarTabs)
        FixSidebarTabCoords()
        if not _G.PaperDollSidebarTabs._ktHooked then
            hooksecurefunc("PaperDollFrame_UpdateSidebarTabs", FixSidebarTabCoords)
            _G.PaperDollSidebarTabs._ktHooked = true
        end

    end

    -- 5. Panel de Estadísticas (Limpieza)
    if _G.CharacterStatsPane then
        S:StripTextures(_G.CharacterStatsPane)
        if _G.CharacterStatsPane.ClassBackground then _G.CharacterStatsPane.ClassBackground:Hide() end
        if _G.CharacterStatsPane.ItemLevelFrame and _G.CharacterStatsPane.ItemLevelFrame.Background then 
            _G.CharacterStatsPane.ItemLevelFrame.Background:Hide() 
        end
    end
    
    -- 6. Botones del Gestor de Equipamiento
    -- Modern clients expose these through EquipmentManagerPane; retain the
    -- legacy globals as fallbacks for older interface versions.
    local equipmentPane = _G.PaperDollFrame and _G.PaperDollFrame.EquipmentManagerPane
    local equipSetButton = (equipmentPane and equipmentPane.EquipSet) or _G.PaperDollFrameEquipSet
    local saveSetButton = (equipmentPane and equipmentPane.SaveSet) or _G.PaperDollFrameSaveSet
    if equipSetButton then S:HandleButton(equipSetButton) end
    if saveSetButton then S:HandleButton(saveSetButton) end
    
    -- [FIX] Skin para la lista de Sets de Equipamiento
    if equipmentPane then
        local Pane = equipmentPane
        if Pane.ScrollBar then S:HandleScrollBar(Pane.ScrollBar) end
        
        if Pane.ScrollBox then
            hooksecurefunc(Pane.ScrollBox, "Update", function(self)
                self:ForEachFrame(function(button)
                    local icon = button.icon or button.Icon
                    if icon and not button.isSkinned then
                        if button.BgTop then button.BgTop:SetTexture("") end
                        if button.BgMiddle then button.BgMiddle:SetTexture("") end
                        if button.BgBottom then button.BgBottom:SetTexture("") end
                        if button.Stripe then button.Stripe:SetTexture("") end

                        S:HandleIcon(icon)
                        icon:SetAlpha(1)
                        icon:Show()
                        icon:SetDrawLayer("OVERLAY")

                        if button.HighlightBar then
                            button.HighlightBar:SetColorTexture(1, 1, 1, 0.25)
                            button.HighlightBar:SetDrawLayer("BACKGROUND")
                        end

                        if button.SelectedBar then
                            button.SelectedBar:SetColorTexture(0.8, 0.8, 0.8, 0.25)
                            button.SelectedBar:SetDrawLayer("BACKGROUND")
                        end

                        button.isSkinned = true
                    end

                    if icon then
                        icon:SetAlpha(1)
                        icon:Show()
                    end
                end)
            end)
        end
    end

    -- [FIX] Skin para la lista de Títulos
    if _G.PaperDollFrame and _G.PaperDollFrame.TitleManagerPane then
        local Pane = _G.PaperDollFrame.TitleManagerPane
        if Pane.ScrollBar then S:HandleScrollBar(Pane.ScrollBar) end
        
        if Pane.ScrollBox then
            hooksecurefunc(Pane.ScrollBox, "Update", function(self)
                self:ForEachFrame(function(button)
                    if not button.isSkinned then
                        -- Darken title background textures (SpellBook style) instead of fully hiding them
                        for i = 1, button:GetNumRegions() do
                            local r = select(i, button:GetRegions())
                            if r and r.IsObjectType and r:IsObjectType("Texture") then
                                r:SetVertexColor(0.35, 0.35, 0.35, 1)
                            end
                        end
                        if button.text then
                            S:HandleFont(button.text)
                            local _, size = button.text:GetFont()
                            button.text:SetFont("Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf", size or 12, "OUTLINE")
                        end
                        button.isSkinned = true
                    end
                end)
            end)
        end
    end

    -- 7. REPUTATION FRAME (Fix Icons)
    if _G.CharacterReputationFrame then
        S:StripTextures(_G.CharacterReputationFrame)
        if _G.CharacterReputationFrame.ScrollBar then
            S:HandleScrollBar(_G.CharacterReputationFrame.ScrollBar)
        end
        
        if _G.CharacterReputationFrame.ScrollBox then
            hooksecurefunc(_G.CharacterReputationFrame.ScrollBox, "Update", function(self)
                self:ForEachFrame(function(child)
                    local frame = child.Content or child
                    if not frame.isSkinned then
                        local icon = frame.Icon
                        if icon then
                            -- [FIX] Entrada con icono: Ocultar fondos manualmente en vez de StripTextures
                            if frame.Background then frame.Background:SetAlpha(0) end
                            if frame.LeftLine then frame.LeftLine:SetAlpha(0) end
                            if frame.RightLine then frame.RightLine:SetAlpha(0) end
                            if frame.BottomLine then frame.BottomLine:SetAlpha(0) end
                            
                            icon:SetAlpha(1)
                            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        else
                            -- Cabecera (sin icono): Limpiar todo
                            S:StripTextures(frame)
                        end
                        if frame.ReputationBar then
                            S:StripTextures(frame.ReputationBar)
                            S:CreateBackdrop(frame.ReputationBar)
                            if frame.ReputationBar.SetStatusBarTexture then
                                frame.ReputationBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
                            end
                        end
                        frame.isSkinned = true
                    end
                    -- Force visibility
                    if frame.Icon then frame.Icon:SetAlpha(1); frame.Icon:Show() end
                end)
            end)
        end
    end

    -- 8. CURRENCY FRAME (Fix Icons)
    if _G.CharacterTokenFrame then
        S:StripTextures(_G.CharacterTokenFrame)
        if _G.CharacterTokenFrame.ScrollBar then
            S:HandleScrollBar(_G.CharacterTokenFrame.ScrollBar)
        end
        
        if _G.CharacterTokenFrame.ScrollBox then
            hooksecurefunc(_G.CharacterTokenFrame.ScrollBox, "Update", function(self)
                self:ForEachFrame(function(child)
                    local frame = child.Content or child
                    if not frame.isSkinned then
                        local icon = frame.Icon
                        if icon then
                            -- [FIX] Entrada con icono: Ocultar fondos manualmente
                            if frame.Stripe then frame.Stripe:SetAlpha(0) end
                            if frame.Background then frame.Background:SetAlpha(0) end
                            
                            icon:SetAlpha(1)
                            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        else
                            -- Cabecera
                            S:StripTextures(frame)
                        end
                        frame.isSkinned = true
                    end
                    -- Force visibility
                    if frame.Icon then frame.Icon:SetAlpha(1); frame.Icon:Show() end
                end)
            end)
        end
    end
end

-- Hookear al inicio del módulo Skins
hooksecurefunc(S, "OnEnable", SkinArmory)
