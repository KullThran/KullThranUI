local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local S = KT:GetModule("Skins", true)
if not S then return end

local _G = _G
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown

local pendingRefresh
local regenFrame
local ApplyCooldownManagerSkin

local function IsUsableObject(object)
    if not object then return false end
    if object.IsForbidden and object:IsForbidden() then return false end
    if object.IsProtected and object:IsProtected() then return false end
    return true
end

local function SkinCategoryHeaders(settings)
    local scroll = settings.CooldownScroll
    local content = scroll and scroll.Content
    if not (IsUsableObject(content) and content.GetChildren) then return end

    local categories = { content:GetChildren() }
    for index = 1, #categories do
        local category = categories[index]
        local header = IsUsableObject(category) and category.Header
        if IsUsableObject(header) then
            S:HandleButton(header)
            if header.Text then
                S:HandleFont(header.Text)
            end
        end
    end
end

local function TintTabTexture(texture, color, alpha)
    if not (texture and texture.SetVertexColor) then return end
    texture:SetVertexColor(color[1], color[2], color[3], alpha or 1)
end

local function SkinSideTab(tab)
    if not IsUsableObject(tab) then return end

    local accent = S:GetAccentColor()
    TintTabTexture(tab.Background, { 0.18, 0.18, 0.20 }, 1)
    TintTabTexture(tab.SelectedTexture, accent, 1)
    TintTabTexture(tab.HighlightTexture, accent, 0.45)
    TintTabTexture(tab.TabGlow, accent, 0.65)

    if not tab._ktCooldownManagerTabSkinned then
        S:RegisterBlizzardAccentRefresh(tab, function(self, color)
            TintTabTexture(self.SelectedTexture, color, 1)
            TintTabTexture(self.HighlightTexture, color, 0.45)
            TintTabTexture(self.TabGlow, color, 0.65)
        end)
        tab._ktCooldownManagerTabSkinned = true
    end
end

local function QueueAfterCombat()
    pendingRefresh = true
    if not regenFrame then
        regenFrame = CreateFrame("Frame")
        regenFrame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            if pendingRefresh then
                pendingRefresh = nil
                ApplyCooldownManagerSkin()
            end
        end)
    end
    regenFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

ApplyCooldownManagerSkin = function()
    if not (S.db and S.db.enable and S.db.cooldownmanager ~= false) then return end
    if InCombatLockdown and InCombatLockdown() then
        QueueAfterCombat()
        return
    end

    local settings = _G.CooldownViewerSettings
    if not IsUsableObject(settings) then return end

    if not settings._ktModernKUISkinned then
        S:SkinPremiumWindow(settings)
        settings._ktModernKUISkinned = true
        settings:HookScript("OnShow", function()
            C_Timer.After(0, ApplyCooldownManagerSkin)
            C_Timer.After(0.10, ApplyCooldownManagerSkin)
        end)
    end

    if IsUsableObject(settings.CloseButton) then
        S:HandleCloseButton(settings.CloseButton)
    end
    if IsUsableObject(settings.SearchBox) then
        S:HandleEditBox(settings.SearchBox)
    end
    if IsUsableObject(settings.SettingsDropdown) then
        S:HandleDropDownBox(settings.SettingsDropdown)
    end
    if IsUsableObject(settings.LayoutDropdown) then
        S:HandleDropDownBox(settings.LayoutDropdown)
    end
    if IsUsableObject(settings.UndoButton) then
        S:HandleButton(settings.UndoButton)
    end
    if IsUsableObject(settings.SpellsTab) then
        SkinSideTab(settings.SpellsTab)
    end
    if IsUsableObject(settings.AurasTab) then
        SkinSideTab(settings.AurasTab)
    end
    if IsUsableObject(settings.GroupBuffsTab) then
        SkinSideTab(settings.GroupBuffsTab)
    end

    local scroll = settings.CooldownScroll
    if IsUsableObject(scroll) and IsUsableObject(scroll.ScrollBar) then
        S:HandleScrollBar(scroll.ScrollBar)
    end

    SkinCategoryHeaders(settings)
end

S.SkinFuncs["Blizzard_CooldownViewer"] = ApplyCooldownManagerSkin

if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("CooldownViewerSettings.OnDataChanged", function()
        local settings = _G.CooldownViewerSettings
        if IsUsableObject(settings) and settings:IsShown() then
            C_Timer.After(0, ApplyCooldownManagerSkin)
        end
    end, "KUI_Skins_CooldownManager")
end