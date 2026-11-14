local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local _G = _G
local hooksecurefunc = hooksecurefunc

-- Función para crear un checkbox con feedback visual sólido (Cuadrado de color)
local function SkinAddonCheckbox(checkbox)
    if not checkbox or checkbox.IsSkinnedCustom then return end
    
    S:HandleCheckBox(checkbox)
    
    -- Crear cuadrado interior manual (Feedback visual sólido)
    checkbox.InnerSquare = checkbox:CreateTexture(nil, "OVERLAY")
    local accent = S:GetAccentColor()
    checkbox.InnerSquare:SetColorTexture(accent[1], accent[2], accent[3], 1)
    checkbox.InnerSquare:SetPoint("TOPLEFT", checkbox, "TOPLEFT", 5, -5)
    checkbox.InnerSquare:SetPoint("BOTTOMRIGHT", checkbox, "BOTTOMRIGHT", -5, 5)
    checkbox.InnerSquare:Hide()

    local function UpdateState(self)
        if self:GetChecked() then
            self.InnerSquare:Show()
        else
            self.InnerSquare:Hide()
        end
    end

    hooksecurefunc(checkbox, "SetChecked", UpdateState)
    checkbox:HookScript("OnClick", UpdateState)
    checkbox:HookScript("OnShow", UpdateState)
    
    -- Desactivar la textura de check original para usar nuestro cuadrado
    if checkbox.SetCheckedTexture then checkbox:SetCheckedTexture("") end
    
    UpdateState(checkbox)
    checkbox.IsSkinnedCustom = true
end

-- Función local para skinear cada entrada de la lista (checkbox, texto, botón)
local function HandleAddonEntry(entry)
    if not entry.IsSkinned then
        -- Checkbox
        SkinAddonCheckbox(entry.Enabled)
        if entry.Enabled then
             entry.Enabled:SetSize(22, 22)
             entry.Enabled:SetPoint("LEFT", entry, "LEFT", 6, 0)
        end
        
        -- Botón Cargar
        S:HandleButton(entry.LoadAddonButton)
        if entry.LoadAddonButton then
             entry.LoadAddonButton:SetSize(90, 20)
        end

        -- Fuente Avant Garde
        if entry.Title then S:HandleFont(entry.Title) end
        if entry.Status then S:HandleFont(entry.Status) end
        if entry.Reload then S:HandleFont(entry.Reload) end
        
        entry.IsSkinned = true
    end
    
    -- Ajustar color del Checkbox según estado (Dorado = Activo, Gris = Desactivado/Dep)
    local data = entry:GetData()
    if data and entry.Enabled and entry.Enabled.InnerSquare then
        local inner = entry.Enabled.InnerSquare
        if data.addonIndex then
            local state = C_AddOns.GetAddOnEnableState(data.addonIndex)
            local _, _, _, _, reason = C_AddOns.GetAddOnInfo(data.addonIndex)
            
            if reason == 'DEP_DISABLED' then
                inner:SetColorTexture(0.5, 0.5, 0.5)
            elseif state == 1 or state == 2 then
                local accent = S:GetAccentColor()
                inner:SetColorTexture(accent[1], accent[2], accent[3], 1)
            else
                inner:SetColorTexture(0.5, 0.5, 0.5)
            end
        end
    end
end

S:RegisterWindow("addonManager", { addon = "Blizzard_AddonList", name = "Blizzard_AddonList", label = "Addon Manager", apply = function()
    if not S:IsWindowEnabled("addonManager") then return end

    local AddonList = _G.AddonList
    
    -- 1. Marco Principal (Color Dinámico)
    S:HandlePortraitFrame(AddonList)
    
    -- 2. Botones Inferiores (Borde Negro)
    S:HandleButton(AddonList.EnableAllButton)
    S:HandleButton(AddonList.DisableAllButton)
    S:HandleButton(AddonList.OkayButton)
    S:HandleButton(AddonList.CancelButton)
    S:HandlePanelButtons(_G.AddonDialog)
    
    -- 3. Elementos Varios
    S:HandleDropDownBox(AddonList.Dropdown, 165)
    S:HandleCheckBox(AddonList.ForceLoad)
    S:HandleEditBox(AddonList.SearchBox)
    S:HandleScrollBar(AddonList.ScrollBar)
    
    -- "Load out of date AddOns" moves to the bottom bar, next to Disable All:
    -- under the dropdown it covered the "AddOn Usage" header.
    if AddonList.ForceLoad and AddonList.DisableAllButton then
        AddonList.ForceLoad:SetSize(22, 22)
        AddonList.ForceLoad:ClearAllPoints()
        AddonList.ForceLoad:SetPoint("LEFT", AddonList.DisableAllButton, "RIGHT", 12, 0)
        if AddonList.ForceLoad.Text then S:HandleFont(AddonList.ForceLoad.Text) end
    end

    -- Header strip: character dropdown, search and the CPU row on one inset
    -- panel, below the controls.
    if AddonList.Dropdown and AddonList.SearchBox and not AddonList._ktHeaderPanel then
        local header = CreateFrame("Frame", nil, AddonList)
        header:SetFrameLevel(math.max(1, AddonList.Dropdown:GetFrameLevel() - 2))
        header:SetPoint("TOPLEFT", AddonList.Dropdown, "TOPLEFT", -8, 6)
        header:SetPoint("RIGHT", AddonList.SearchBox, "RIGHT", 8, 0)
        header:SetPoint("BOTTOM", AddonList.Performance or AddonList.SearchBox, "BOTTOM", 0, -6)
        if KT.Surface then KT.Surface:Apply(header, "inset") end
        AddonList._ktHeaderPanel = header
    end
    
    -- 4. Hookear la lista de addons (ScrollBox)
    if AddonList.ScrollBox then
        hooksecurefunc(AddonList.ScrollBox, "Update", function(self)
            self:ForEachFrame(HandleAddonEntry)
        end)
    end
end })
