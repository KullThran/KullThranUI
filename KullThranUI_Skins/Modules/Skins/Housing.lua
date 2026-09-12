local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local S = KT:GetModule("Skins")
local installed = false

-- Only known panel backgrounds, never pooled decor icons, model scenes,
-- progress bars or purchase/teleport callbacks.
local function HideBackground(texture)
    if not texture or not texture.IsObjectType or not texture:IsObjectType("Texture") then return end
    texture:SetAlpha(0)
    local data = S:GetFFD(texture)
    if data.housingHidden then return end
    data.housingHidden = true
    for _, method in ipairs({ "SetAtlas", "SetTexture", "Show" }) do
        if type(texture[method]) == "function" then
            hooksecurefunc(texture, method, function(self) self:SetAlpha(0) end)
        end
    end
end

local function Panel(frame, topInset)
    if not frame or frame:IsForbidden() then return end
    local data = S:GetFFD(frame)
    local function Refresh()
        for _, key in ipairs({ "Background", "Bg", "BG", "BGTexture", "PreviewBackground" }) do
            HideBackground(frame[key])
        end
        S:ApplyKuiSurface(frame)
        -- These catalog wrappers include the title/header. Leave that area
        -- transparent so child-frame artwork cannot cover the window title.
        if topInset then
            for _, texture in ipairs({ data.kuiArtwork, data.kuiWash }) do
                texture:ClearAllPoints()
                texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -topInset)
                texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            end
        end
        if frame.TabSystem and frame.TabSystem.tabs then
            for _, tab in pairs(frame.TabSystem.tabs) do S:HandleTab(tab) end
        end
    end
    Refresh()
    if not data.housingPanel then
        data.housingPanel = true
        frame:HookScript("OnShow", Refresh)
        if type(frame.SetTab) == "function" then hooksecurefunc(frame, "SetTab", Refresh) end
    end
end

local function SkinHousing()
    if installed or not (S.db and S.db.enable and S.db.housing ~= false) then return end
    local frame = _G.HousingDashboardFrame
    if not frame or frame:IsForbidden() then return end
    S:SkinPremiumWindow(frame)
    if frame.PortraitContainer then frame.PortraitContainer:SetAlpha(0) end
    if frame.CloseButton then S:HandleCloseButton(frame.CloseButton) end
    if frame.TitleText then S:HandleFont(frame.TitleText) end

    local function Refresh()
        local info = frame.HouseInfoContent
        if info then
            Panel(info.DashboardNoHousesFrame, 55)
            Panel(info.ContentFrame)
            local content = info.ContentFrame
            if content then
                Panel(content.HouseUpgradeFrame)
                Panel(content.InitiativesFrame)
                local initiatives = content.InitiativesFrame
                local active = initiatives and initiatives.InitiativeSetFrame
                if active then
                    Panel(active.InitiativeTasks)
                    Panel(active.InitiativeActivity)
                    Panel(active.InitiativeActiveNeighborhoodSwitcher)
                end
            end
            if info.HouseFinderButton then S:HandleButton(info.HouseFinderButton) end
            local empty = info.DashboardNoHousesFrame
            if empty and empty.NoHouseButton then S:HandleButton(empty.NoHouseButton) end
        end
        Panel(frame.CatalogContent, 55)
        Panel(frame.CollectionContent, 55)
        if frame.CollectionContent then Panel(frame.CollectionContent.BlueprintDetails) end
        -- Preserve native side-tab icons and checked-state behavior.
        for _, tab in ipairs(frame.TabButtons or {}) do S:HandleTab(tab) end
    end
    Refresh()
    frame:HookScript("OnShow", Refresh)
    if type(frame.SetTab) == "function" then hooksecurefunc(frame, "SetTab", Refresh) end
    installed = true
end

S:AddCallback("Housing", SkinHousing)
S:AddCallbackForAddon("Blizzard_HousingDashboard", "Housing", SkinHousing)

