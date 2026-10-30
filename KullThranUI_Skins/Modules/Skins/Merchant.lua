local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc

local function SkinMerchant()
    if not (S.db.enable and S.db.merchant) then return end
    
    local MerchantFrame = _G.MerchantFrame
    if not MerchantFrame then return end
    
    S:HandlePortraitFrame(MerchantFrame)
    if MerchantFrame.Inset then S:StripTextures(MerchantFrame.Inset) end
    if MerchantFrame.FilterDropdown then S:HandleDropDownBox(MerchantFrame.FilterDropdown) end
    
    -- Pestañas
    for i = 1, 2 do
        local tab = _G["MerchantFrameTab"..i]
        if tab then S:HandleTab(tab) end
    end
    
    -- Items de Venta
    for i = 1, _G.MERCHANT_ITEMS_PER_PAGE do
        local item = _G["MerchantItem"..i]
        if item then
            S:StripTextures(item)
            S:CreateBackdrop(item)
            item.backdrop:SetPoint("TOPLEFT", -2, 2)
            item.backdrop:SetPoint("BOTTOMRIGHT", 2, -2)
            
            local button = _G["MerchantItem"..i.."ItemButton"]
            local icon = _G["MerchantItem"..i.."ItemButtonIconTexture"]
            
            if button then
                -- Merchant item icons are the button's normal texture on modern
                -- clients. HandleButton would replace that texture with BLANK_TEX.
                S:CreateBackdrop(button)
                if button.backdrop then
                    button.backdrop:SetBackdropColor(0.025, 0.025, 0.03, 0.96)
                end
                if icon then
                    icon:SetAlpha(1)
                    icon:SetVertexColor(1, 1, 1, 1)
                    icon:SetDrawLayer("ARTWORK", 1)
                    S:HandleIcon(icon)
                    S:SetInside(icon, button.backdrop or button)
                end
            end

            if _G["MerchantItem"..i.."Name"] then
                S:HandleFont(_G["MerchantItem"..i.."Name"])
            end
            if _G["MerchantItem"..i.."MoneyFrame"] then
                S:HandleFont(_G["MerchantItem"..i.."MoneyFrame"])
            end
        end
    end
    
    -- Pestaña de Recompra
    if _G.MerchantBuyBackItem then
        S:StripTextures(_G.MerchantBuyBackItem)
        S:CreateBackdrop(_G.MerchantBuyBackItem)
        if _G.MerchantBuyBackItemItemButton then
            local buybackButton = _G.MerchantBuyBackItemItemButton
            local buybackIcon = _G.MerchantBuyBackItemItemButtonIconTexture
            S:CreateBackdrop(buybackButton)
            if buybackIcon then
                buybackIcon:SetAlpha(1)
                buybackIcon:SetVertexColor(1, 1, 1, 1)
                buybackIcon:SetDrawLayer("ARTWORK", 1)
                S:HandleIcon(buybackIcon)
                S:SetInside(buybackIcon, buybackButton.backdrop or buybackButton)
            end
        end
    end
    
    -- Keep Blizzard's real repair artwork. Replacing the normal texture with a
    -- hand-cropped atlas produced blank or incorrect icons on current clients.
    local function UpdateRepairIcons()
        local accent = S:GetAccentColor()
        local repairButtons = {
            _G.MerchantRepairItemButton,
            _G.MerchantRepairAllButton,
            _G.MerchantGuildBankRepairButton,
        }

        for _, button in ipairs(repairButtons) do
            if button then
                if button.KT_Icon then
                    button.KT_Icon:Hide()
                end

                local icon = button:GetNormalTexture()
                if icon then
                    local enabled = button:IsEnabled()
                    icon:SetAlpha(enabled and 1 or 0.72)
                    icon:SetDesaturated(not enabled)
                    icon:SetVertexColor(
                        accent[1] * (enabled and 1 or 0.42),
                        accent[2] * (enabled and 1 or 0.42),
                        accent[3] * (enabled and 1 or 0.42),
                        1
                    )
                end
            end
        end
    end
    -- Botones de Reparación
    local repairButtons = {
        _G.MerchantRepairItemButton,
        _G.MerchantRepairAllButton,
        _G.MerchantGuildBankRepairButton
    }
    
    for _, btn in pairs(repairButtons) do
        if btn then
            -- Do not call StripTextures/HandleButton here: both replace the
            -- native repair atlas. A backdrop is enough to match the skin.
            S:CreateBackdrop(btn, true)
        end
    end

    -- Hookear la función de Blizzard para que nuestros iconos persistan
    hooksecurefunc("MerchantFrame_UpdateRepairButtons", UpdateRepairIcons)
    UpdateRepairIcons() -- Aplicar inicialmente
    
    -- Navigation uses three independent fixed zones. Button labels are attached
    -- to the arrow buttons by Blizzard, so anchoring arrows to MerchantPageText
    -- made Prev/Page/Next overlap whenever localized text changed width.
    local pageY = 78
    if _G.MerchantPageText then
        _G.MerchantPageText:ClearAllPoints()
        _G.MerchantPageText:SetPoint("BOTTOM", MerchantFrame, "BOTTOM", 0, pageY + 4)
        _G.MerchantPageText:SetWidth(96)
        _G.MerchantPageText:SetJustifyH("CENTER")
    end

    if _G.MerchantNextPageButton then
        local button = _G.MerchantNextPageButton
        S:HandleButton(button)
        button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
        local tex = button:GetNormalTexture()
        if tex then
            local accent = S:GetAccentColor()
            tex:SetAlpha(1)
            tex:SetTexCoord(0.2, 0.8, 0.2, 0.8)
            tex:SetVertexColor(accent[1], accent[2], accent[3], 1)
            S:SetInside(tex, button.backdrop or button)
        end
        button:ClearAllPoints()
        button:SetSize(24, 24)
        button:SetPoint("BOTTOM", MerchantFrame, "BOTTOM", 105, pageY)
    end

    if _G.MerchantPrevPageButton then
        local button = _G.MerchantPrevPageButton
        S:HandleButton(button)
        button:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
        local tex = button:GetNormalTexture()
        if tex then
            local accent = S:GetAccentColor()
            tex:SetAlpha(1)
            tex:SetTexCoord(0.2, 0.8, 0.2, 0.8)
            tex:SetVertexColor(accent[1], accent[2], accent[3], 1)
            S:SetInside(tex, button.backdrop or button)
        end
        button:ClearAllPoints()
        button:SetSize(24, 24)
        button:SetPoint("BOTTOM", MerchantFrame, "BOTTOM", -105, pageY)
    end
    -- Moneda
    if _G.MerchantMoneyInset then S:StripTextures(_G.MerchantMoneyInset) end
    if _G.MerchantExtraCurrencyInset then S:StripTextures(_G.MerchantExtraCurrencyInset) end
    if _G.MerchantExtraCurrencyBg then S:StripTextures(_G.MerchantExtraCurrencyBg) end
end

hooksecurefunc(S, "OnEnable", SkinMerchant)
