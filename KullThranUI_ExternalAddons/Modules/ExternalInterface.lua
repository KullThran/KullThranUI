local KT = _G.KT
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local Mod = KT:GetModule("ExternalInterface", true) or KT:NewModule("ExternalInterface", "AceEvent-3.0", "AceHook-3.0")

local C_Timer = _G.C_Timer

local DEFAULT_FONT_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
local FALLBACK_BUTTON_WIDTH = 180
local FALLBACK_BUTTON_HEIGHT = 20

local function NormalizeButtonSize(width, height)
    if type(width) ~= "number" or width <= 0 or width < FALLBACK_BUTTON_WIDTH then
        width = FALLBACK_BUTTON_WIDTH
    end

    if type(height) ~= "number" or height <= 0 or height < FALLBACK_BUTTON_HEIGHT then
        height = FALLBACK_BUTTON_HEIGHT
    end

    return width, height
end

local function IsEscapeMenuManagedByCore()
    if not (KT and KT.GetModule) then
        return false
    end

    local escapeMenu = KT:GetModule("EscapeMenu", true)
    return escapeMenu and escapeMenu.IsEnabled and escapeMenu:IsEnabled()
end

-- Since 11.0 the Game Menu is a vertical layout filled from a button pool by
-- GameMenuFrameMixin:InitButtons; the old named buttons are gone. The KUI
-- buttons then join that layout as children made from the menu's template.
local LAYOUT_SECTION_SPACING = 20
local KUI_POSITIONS = { bottom = true, top = true, afterOptions = true }

local function UsesLayoutMenu(menu)
    return menu ~= nil and type(menu.InitButtons) == "function"
        and type(menu.MarkDirty) == "function" and type(menu.buttonTemplate) == "string"
end

local function GetGameMenuConfig()
    local profile = KT and KT.db and KT.db.profile
    local gameMenu = profile and profile.enhancements and profile.enhancements.gameMenu
    return type(gameMenu) == "table" and gameMenu or {}
end

local function SafeHideGameMenu()
    if _G.HideUIPanel and _G.GameMenuFrame then
        pcall(_G.HideUIPanel, _G.GameMenuFrame)
        return
    end
    if _G.GameMenuFrame and _G.GameMenuFrame.Hide then
        pcall(_G.GameMenuFrame.Hide, _G.GameMenuFrame)
    end
end

local function ToggleUnlockMode()
    local um = KT and KT.GetModule and KT:GetModule("UnlockMode", true)
    if um and um.ToggleUnlockMode then
        um:ToggleUnlockMode()
        return true
    end

    if KT and KT.Print then
        KT:Print("|cffFF4444UnlockMode|r: " .. LText("module not available."))
    end
    return false
end

local function CreateButtonFontString(button, text)
    local fs = button:CreateFontString(nil, "OVERLAY")
    fs:SetFont(DEFAULT_FONT_PATH, 13, "OUTLINE")
    fs:SetTextColor(1, 1, 1, 1)
    fs:SetAllPoints(button)
    fs:SetJustifyH("CENTER")
    fs:SetText(text)
    button:SetFontString(fs)
    return fs
end

function Mod:OnEnable()
    self:TrySetupGameMenu()
    self:RegisterEvent("ADDON_LOADED")
    self:RegisterEvent("PLAYER_LOGIN")
end

function Mod:PLAYER_LOGIN()
    self:TrySetupGameMenu()
end

function Mod:ADDON_LOADED(_, addonName)
    if self.setupDone then
        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_LOGIN")
        return
    end

    if addonName == "Blizzard_GameMenu" or addonName == "KullThranUI" then
        self:TrySetupGameMenu()
    else
        self:TrySetupGameMenu()
    end

    if self.setupDone then
        self:UnregisterEvent("ADDON_LOADED")
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end

function Mod:TrySetupGameMenu()
    if self.setupDone then return end
    if not _G.GameMenuFrame then return end
    if IsEscapeMenuManagedByCore() then
        self.setupDone = true
        return
    end
    self:SetupGameMenu()
end

function Mod:SetupGameMenu()
    if self.setupDone then return end
    if IsEscapeMenuManagedByCore() then
        self.setupDone = true
        return
    end
    self.setupDone = true

    local menu = _G.GameMenuFrame
    local layoutMenu = UsesLayoutMenu(menu)
    self.buttonTemplate = layoutMenu and menu.buttonTemplate or "GameMenuButtonTemplate"

    local button = CreateFrame("Button", "GameMenuButtonKullThranUI", menu, self.buttonTemplate)
    if not layoutMenu then
        button:SetSize(FALLBACK_BUTTON_WIDTH, FALLBACK_BUTTON_HEIGHT)
    end
    button:SetText(LText("KullThranUI"))
    if not (button.GetFontString and button:GetFontString()) then
        CreateButtonFontString(button, "KullThranUI")
    end

    button:SetScript("OnClick", function()
        if not InCombatLockdown() then
            SafeHideGameMenu()
            KT:ToggleConfig()
        end
    end)
    self.ktButton = button

    self:EnsureKUIUnlockButton()

    if layoutMenu then
        -- InitButtons runs on every show before Blizzard's Layout.
        self:SecureHook(menu, "InitButtons", "PlaceLayoutButtons")
        if menu:IsShown() then
            -- InitButtons marks the menu dirty itself; an open menu needs it here.
            self:PlaceLayoutButtons()
            menu:MarkDirty()
        end
        return
    end

    if _G.GameMenuFrame_UpdateVisibleButtons then
        self:SecureHook("GameMenuFrame_UpdateVisibleButtons", "AnchorButton")
    end
    self:SecureHookScript(menu, "OnShow", "AnchorButton")

    if menu:IsShown() then
        self:AnchorButton()
    end
end

function Mod:EnsureKUIUnlockButton()
    if self.kuiUnlockButton and self.kuiUnlockButton.GetParent then
        return self.kuiUnlockButton
    end

    local menu = _G.GameMenuFrame
    if not menu then return nil end

    local btn = _G.GameMenuButtonKUIUnlockMode
    if btn and btn.GetParent and btn:GetParent() == menu then
        self.kuiUnlockButton = btn
        return btn
    end

    local layoutMenu = UsesLayoutMenu(menu)
    btn = CreateFrame("Button", "GameMenuButtonKUIUnlockMode", menu,
        self.buttonTemplate or (layoutMenu and menu.buttonTemplate) or "GameMenuButtonTemplate")
    if not layoutMenu then
        btn:SetSize(FALLBACK_BUTTON_WIDTH, FALLBACK_BUTTON_HEIGHT)
    end
    btn:SetText(LText("KUI Unlock Mode"))
    if not (btn.GetFontString and btn:GetFontString()) then
        CreateButtonFontString(btn, "KUI Unlock Mode")
    end

    btn:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            if KT and KT.Print then
                KT:Print("|cffFF4444UnlockMode|r: " .. LText("not available in combat."))
            end
            return
        end
        SafeHideGameMenu()
        ToggleUnlockMode()
    end)

    self.kuiUnlockButton = btn
    return btn
end

-- Layout indices between Blizzard's whole numbers, at the position chosen in
-- Enhancements > Game Menu (read from the profile; that module may be off).
-- At the top or bottom the KUI buttons form a section of their own.
function Mod:PlaceLayoutButtons()
    local menu = _G.GameMenuFrame
    if not (menu and self.ktButton) then return end

    local config = GetGameMenuConfig()
    local position = KUI_POSITIONS[config.kuiPosition] and config.kuiPosition or "bottom"
    local order = config.kuiFirst == "unlock" and { "unlock", "config" } or { "config", "unlock" }
    local buttons = { config = self.ktButton, unlock = self.kuiUnlockButton }
    local shownSetting = { config = "showConfig", unlock = "showUnlock" }

    local native = {}
    for _, button in ipairs(type(menu.buttons) == "table" and menu.buttons or {}) do
        if button and tonumber(button.layoutIndex) then
            native[#native + 1] = button
        end
    end
    table.sort(native, function(a, b) return a.layoutIndex < b.layoutIndex end)

    local base
    if position == "top" then
        base = (native[1] and native[1].layoutIndex or 1) - 1
    elseif position == "afterOptions" then
        local anchor = native[1]
        for _, button in ipairs(native) do
            if button.GetText and button:GetText() == _G.GAMEMENU_OPTIONS then
                anchor = button
                break
            end
        end
        base = anchor and anchor.layoutIndex or 0
    else
        base = native[#native] and native[#native].layoutIndex or 1000
    end

    local shown = {}
    for _, key in ipairs(order) do
        local button = buttons[key]
        if button then
            button.ignoreInLayout = nil
            button.topPadding = nil
            button.bottomPadding = nil
            local visible = config[shownSetting[key]] ~= false
            button:SetShown(visible)
            if visible then shown[#shown + 1] = button end
        end
    end
    local texts = { config = "KullThranUI", unlock = "KUI Unlock Mode" }
    for key, button in pairs(buttons) do
        button:SetText(LText(texts[key]))
    end

    for index, button in ipairs(shown) do
        button.layoutIndex = base + index * 0.1
    end
    if #shown > 0 then
        if position == "top" then
            shown[#shown].bottomPadding = LAYOUT_SECTION_SPACING
        elseif position == "bottom" then
            shown[1].topPadding = LAYOUT_SECTION_SPACING
        end
    end
end

function Mod:StyleGameMenuButton(button, width, height)
    if not button then return end

    width, height = NormalizeButtonSize(width, height)
    button:SetSize(width, height)

    local S = KT:GetModule("Skins", true)
    if S and not button.isSkinned then
        S:HandleButton(button)
    end

    local fs = button.GetFontString and button:GetFontString()
    if fs then
        fs:SetFont(DEFAULT_FONT_PATH, 13, "OUTLINE")
        fs:SetTextColor(1, 1, 1, 1)
        fs:Show()
    end

    if button.backdrop then
        button.backdrop:Show()
        button.backdrop:SetBackdropColor(0.11, 0.11, 0.11, 1)
    end
end

function Mod:AnchorKUIUnlockButton(gameMenu, referenceButton)
    local btn = self:EnsureKUIUnlockButton()
    if not btn then return end

    local continueBtn = _G.GameMenuButtonContinue
    local ref = referenceButton
        or continueBtn
        or _G.GameMenuButtonExitGame
        or _G.GameMenuButtonLogout
        or _G.GameMenuButtonAddons
        or _G.GameMenuButtonOptions

    local w = (ref and ref.GetWidth and ref:GetWidth() > 0 and ref:GetWidth()) or FALLBACK_BUTTON_WIDTH
    local h = (ref and ref.GetHeight and ref:GetHeight() > 0 and ref:GetHeight()) or FALLBACK_BUTTON_HEIGHT
    w, h = NormalizeButtonSize(w, h)
    self:StyleGameMenuButton(btn, w, h)

    local fs = btn.GetFontString and btn:GetFontString()
    if fs then
        fs:SetText(LText("KUI Unlock Mode"))
    end

    btn:Show()
    btn:ClearAllPoints()
    if continueBtn then
        btn:SetPoint("TOP", continueBtn, "BOTTOM", 0, -1)
    elseif ref then
        btn:SetPoint("TOP", ref, "BOTTOM", 0, -1)
    elseif gameMenu then
        btn:SetPoint("BOTTOM", gameMenu, "BOTTOM", 0, 10)
    end
end

function Mod:AnchorButton()
    if not self.ktButton then return end

    local gameMenu = _G.GameMenuFrame
    if not gameMenu then return end

    if InCombatLockdown and InCombatLockdown() then
        if not (C_Timer and C_Timer.After) then return end
        if self._combatRetryScheduled then return end
        self._combatRetryScheduled = true
        C_Timer.After(1, function()
            if not self then return end
            self._combatRetryScheduled = nil
            if self.AnchorButton then
                self:AnchorButton()
            end
        end)
        return
    end

    local targetAnchor = _G.GameMenuButtonAddons or _G.GameMenuButtonOptions or _G.GameMenuButtonStore or _G.GameMenuButtonLogout

    if not targetAnchor and gameMenu.GetLayoutChildren then
        for _, child in ipairs(gameMenu:GetLayoutChildren()) do
            if child:IsObjectType("Button") and child:IsShown() and child ~= self.ktButton then
                targetAnchor = child
                break
            end
        end
    end

    local function DoAnchor()
        if not self then return end

        local ref = targetAnchor or _G.GameMenuButtonContinue
        local w = (ref and ref.GetWidth and ref:GetWidth() > 0 and ref:GetWidth()) or FALLBACK_BUTTON_WIDTH
        local h = (ref and ref.GetHeight and ref:GetHeight() > 0 and ref:GetHeight()) or FALLBACK_BUTTON_HEIGHT
        w, h = NormalizeButtonSize(w, h)

        self:StyleGameMenuButton(self.ktButton, w, h)

        local fs = self.ktButton.GetFontString and self.ktButton:GetFontString()
        if fs then
            fs:SetText(LText("KullThranUI"))
        end

        self.ktButton:Show()
        self.ktButton:ClearAllPoints()
        if targetAnchor then
            self.ktButton:SetPoint("BOTTOM", targetAnchor, "TOP", 0, 1)
        elseif ref then
            self.ktButton:SetPoint("TOP", ref, "BOTTOM", 0, -1)
        else
            self.ktButton:SetPoint("TOP", gameMenu, "TOP", 0, -120)
        end

        self:AnchorKUIUnlockButton(gameMenu, ref)
    end

    DoAnchor()
end
