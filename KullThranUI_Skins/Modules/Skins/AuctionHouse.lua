local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc
local pairs, ipairs = pairs, ipairs

-- == HELPERS ==
local function SkinCategoryButton(button)
    if not button or button.isSkinned then return end
    S:StripTextures(button)
    S:HandleButton(button)
    button.backdrop:SetBackdropColor(0.16, 0.16, 0.16, 1)
    button:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
    button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.1)
    if button.Text then S:HandleFont(button.Text); button.Text:SetTextColor(1, 1, 1) end
    button.isSkinned = true
end

local function SkinResultRow(row)
    if not row then return end
    if row.cells then
        for _, cell in ipairs(row.cells) do
            if cell.Icon then S:HandleIcon(cell.Icon); if cell.IconBorder then cell.IconBorder:Hide() end end
            if cell.Text then S:HandleFont(cell.Text); cell.Text:SetTextColor(1, 1, 1) end
        end
    end
    if row.HighlightTexture then row.HighlightTexture:SetTexture("Interface\\Buttons\\WHITE8x8"); row.HighlightTexture:SetVertexColor(1, 1, 1, 0.05) end
    if row.SelectedHighlight then
        row.SelectedHighlight:SetTexture("Interface\\Buttons\\WHITE8x8")
        -- Usar el color dinámico para el resaltado de selección de fila
        local bc = S:GetAccentColor()
        row.SelectedHighlight:SetVertexColor(bc[1], bc[2], bc[3], 0.2)
    end
end

-- Busca pestañas extra y fuerza el estilo
local function SkinExtraTabs(frame)
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        if child:IsObjectType("Button") and child:GetID() > 0 and not child.isSkinned then
            if child.Text or (child.GetFontString and child:GetFontString()) then
                S:HandleTab(child)
            end
        end
    end
end

-- Busca botones inferiores sueltos y fuerza el estilo y fuente
local function SkinBottomButtons(frame)
    local children = {frame:GetChildren()}
    for _, child in ipairs(children) do
        if child:IsObjectType("Button") and child:GetNumRegions() > 2 then
            local name = child:GetName()
            local textLabel = child:GetText()
            -- Si tiene texto o parece un botón de addon, skinéalo
            if textLabel or (name and (name:find("Auctionator") or name:find("Export") or name:find("Import") or name:find("Scan"))) then
                S:HandleButton(child)
            end
        end
    end
end

-- == CARGA PRINCIPAL ==
S.SkinFuncs["Blizzard_AuctionHouseUI"] = function()
    if not (S.db.enable and S.db.auctionhouse) then return end
    
    local AH = _G.AuctionHouseFrame
    S:StripTextures(AH)
    -- ESTE ES EL ÚNICO QUE LLEVARÁ EL COLOR DINÁMICO
    S:CreateBackdrop(AH) 
    if AH.backdrop then
        S:RegisterBlizzardWindowBackground(AH.backdrop)
    end
    
    -- Barra Superior (Botones y EditBox ya se ponen negros por el motor Skins.lua)
    S:HandleButton(AH.SearchBar.SearchButton)
    S:HandleButton(AH.SearchBar.FilterButton)
    S:HandleButton(AH.SearchBar.FavoritesSearchButton)
    if AH.SearchBar.FavoritesSearchButton.Icon then
        AH.SearchBar.FavoritesSearchButton.Icon:SetAlpha(1)
    end
    S:HandleEditBox(AH.SearchBar.SearchBox)
    
    -- Categorías (Contenedor interno -> borde negro)
    local Categories = AH.CategoriesList
    S:StripTextures(Categories)
    S:CreateBackdrop(Categories)
    Categories.backdrop:SetBackdropBorderColor(0, 0, 0, 1) -- FORZAR NEGRO
    S:HandleScrollBar(Categories.ScrollBar)
    if Categories.ScrollBox then
        hooksecurefunc(Categories.ScrollBox, "Update", function(self) if not self:GetView() then return end self:ForEachFrame(SkinCategoryButton) end)
    end
    
    -- Resultados (Contenedor interno -> borde negro)
    if AH.BrowseResultsFrame then
        local Browse = AH.BrowseResultsFrame
        local ItemList = Browse.ItemList
        S:StripTextures(ItemList)
        S:CreateBackdrop(ItemList)
        ItemList.backdrop:SetBackdropBorderColor(0, 0, 0, 1) -- FORZAR NEGRO
        S:HandleScrollBar(ItemList.ScrollBar)
        if ItemList.HeaderContainer then
            S:StripTextures(ItemList.HeaderContainer)
            for _, header in ipairs({ItemList.HeaderContainer:GetChildren()}) do
                S:HandleButton(header); header.backdrop:SetBackdropColor(0.2, 0.2, 0.2, 1); S:HandleFont(header)
            end
        end
        if ItemList.ScrollBox then
            hooksecurefunc(ItemList.ScrollBox, "Update", function(self) if not self:GetView() then return end self:ForEachFrame(SkinResultRow) end)
        end
    end
    
    -- Pestañas de Blizzard
    if AH.Tabs then
        for _, tab in ipairs(AH.Tabs) do
            S:HandleTab(tab)
        end
    end
    
    -- Hook para pestañas y botones de Auctionator/Addons
    C_Timer.After(0.1, function()
        SkinExtraTabs(AH)
        SkinBottomButtons(AH)
    end)
    hooksecurefunc(AH, "SetPoint", function() SkinExtraTabs(AH) end)

    -- Paneles de Venta
    if AH.ItemSellFrame then
        S:HandleButton(AH.ItemSellFrame.PostButton)
        S:HandleButton(AH.ItemSellFrame.QuantityInput.MaxButton)
        S:HandleEditBox(AH.ItemSellFrame.QuantityInput.InputBox)
        if AH.ItemSellFrame.PriceInput then
            S:HandleEditBox(AH.ItemSellFrame.PriceInput.MoneyInputFrame.GoldBox)
            S:HandleEditBox(AH.ItemSellFrame.PriceInput.MoneyInputFrame.SilverBox)
        end
        if AH.ItemSellFrame.ItemDisplay then
            S:StripTextures(AH.ItemSellFrame.ItemDisplay)
            S:CreateBackdrop(AH.ItemSellFrame.ItemDisplay)
            AH.ItemSellFrame.ItemDisplay.backdrop:SetBackdropBorderColor(0, 0, 0, 1) -- FORZAR NEGRO
            if AH.ItemSellFrame.ItemDisplay.ItemButton then
                S:StripTextures(AH.ItemSellFrame.ItemDisplay.ItemButton)
                S:HandleIcon(AH.ItemSellFrame.ItemDisplay.ItemButton.Icon)
                if AH.ItemSellFrame.ItemDisplay.ItemButton.Icon then AH.ItemSellFrame.ItemDisplay.ItemButton.Icon:SetAlpha(1) end
            end
        end
    end

    -- Limpieza final
    local framesToKill = { AH.MoneyFrameBorder, AH.MoneyFrameInset, AH.BotLeftCorner, AH.BotRightCorner, AH.BottomBorder, AH.LeftBorder, AH.RightBorder, AH.NineSlice, AH.Border, AH.Portrait, AH.PortraitFrame }
    for _, frame in ipairs(framesToKill) do if frame then S:Kill(frame) end end
end
