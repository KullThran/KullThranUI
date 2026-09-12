-- ============================================================================
-- ACTION BUTTON ENHANCEMENTS (ANIMATIONS)
-- ============================================================================
-- Modules/ActionBars/Actionbuttonenhancements.lua (moved from Modules/Actionbuttonenhancements.lua)
-- Replicates functionality of "Bartender4 Animations"
-- 1. Smooth Flash on Press (Juicy Texture)
-- 2. Physical Button Press (Scale Animation)
-- 3. Shake on Cast
-- 4. Keypress Indicator

local _, ns = ...
local _G = _G
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local LSM = LibStub("LibSharedMedia-3.0", true)

local function IsAccessibleInputValue(value)
    if _G.issecretvalue and _G.issecretvalue(value) then return false end
    if _G.canaccessvalue and not _G.canaccessvalue(value) then return false end
    return true
end

local function SafeInputBoolean(func)
    if type(func) ~= "function" then return false end
    local ok, value = pcall(func)
    return ok and IsAccessibleInputValue(value) and value == true
end

-- ============================================================================
-- 1. SMOOTH FLASH (AL PULSAR)
-- ============================================================================

local function CreateActionFlash(button)
    if button.KT_ActionFlash then return button.KT_ActionFlash end
    
    local flash = CreateFrame("Frame", nil, button)
    flash:SetAllPoints(button)
    flash:SetFrameLevel(button:GetFrameLevel() + 10)
    flash:Hide()
    
    local tex = flash:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    tex:SetAllPoints(button)
    tex:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    tex:SetVertexColor(1, 1, 1, 1)
    tex:SetBlendMode("ADD")
    flash.texture = tex
    
    local anim = flash:CreateAnimationGroup()
    
    local fadeIn = anim:CreateAnimation("Alpha")
    fadeIn:SetTarget(tex)
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.05)
    fadeIn:SetOrder(1)
    fadeIn:SetSmoothing("OUT")
    
    local fadeOut = anim:CreateAnimation("Alpha")
    fadeOut:SetTarget(tex)
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.2)
    fadeOut:SetOrder(2)
    fadeOut:SetSmoothing("OUT")
    
    anim:SetScript("OnFinished", function() flash:Hide() end)
    flash.anim = anim
    
    flash.Play = function(self)
        self:Show()
        self.anim:Stop()
        self.anim:Play()
    end
    
    button.KT_ActionFlash = flash
    return flash
end

-- ============================================================================
-- 2. SHAKE ANIMATION (SACUDIDA)
-- ============================================================================

local function CreateShakeAnimation(button)
    if not button or button.ShakeAnimation then return end

    local group = button:CreateAnimationGroup()

    local moveLeft = group:CreateAnimation("Translation")
    moveLeft:SetOffset(2, -2)
    moveLeft:SetDuration(0.05)
    moveLeft:SetOrder(1)
    moveLeft:SetSmoothing("OUT")
    
    local moveRight = group:CreateAnimation("Translation")
    moveRight:SetOffset(-2, 2)
    moveRight:SetDuration(0.05)
    moveRight:SetOrder(2)
    moveRight:SetSmoothing("OUT")
    
    local moveBack = group:CreateAnimation("Translation")
    moveBack:SetOffset(0, 0)
    moveBack:SetDuration(0.05)
    moveBack:SetOrder(3)
    
    group:SetLooping("NONE")
    button.ShakeAnimation = group
end

-- ============================================================================
-- 3. PHYSICAL PRESS ANIMATION (ESCALA)
-- ============================================================================

local function CreatePressAnimation(button)
    if button.KT_PressAnim then return end
    
    local group = button:CreateAnimationGroup()
    
    group:SetScript("OnStop", function() 
        if not InCombatLockdown() then button:SetScale(1) end 
    end)
    group:SetScript("OnFinished", function() 
        if not InCombatLockdown() then button:SetScale(1) end 
    end)
    
    local shrink = group:CreateAnimation("Scale")
    shrink:SetScale(0.95, 0.95)
    shrink:SetDuration(0.05)
    shrink:SetOrder(1)
    shrink:SetSmoothing("OUT")
    
    local grow = group:CreateAnimation("Scale")
    grow:SetScale(1.0526, 1.0526)
    grow:SetDuration(0.1)
    grow:SetOrder(2)
    grow:SetSmoothing("OUT")
    
    button.KT_PressAnim = group
end

-- ============================================================================
-- 4. INTEGRACIÓN DE EVENTOS (MOUSE & KEYBOARD)
-- ============================================================================

local function SetupButtonFeedback(button)
    if button.KT_FeedbackHooked then return end
    
    button:HookScript("OnMouseDown", function(self)
        if self.KT_ActionFlash then self.KT_ActionFlash:Play() end
        
        if self.ShakeAnimation then 
            self.ShakeAnimation:Stop()
            self.ShakeAnimation:Play() 
        end
        
        if self.KT_PressAnim then
            if InCombatLockdown() and self:IsProtected() then return end
            
            self.KT_PressAnim:Stop()
            self.KT_PressAnim:Play()
        end
    end)
    
    button.KT_FeedbackHooked = true
end

-- ============================================================================
-- 5. KEYPRESS INDICATOR
-- ============================================================================

local function CreateKeypressIndicator(button)
    if button.KT_KeypressIndicator then return button.KT_KeypressIndicator end
    
    local indicator = CreateFrame("Frame", nil, button)
    indicator:SetSize(button:GetWidth() * 0.6, button:GetHeight() * 0.6)
    indicator:SetPoint("CENTER")
    indicator:SetFrameLevel(button:GetFrameLevel() + 9)
    indicator:Hide()
    
    local text = indicator:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    text:SetPoint("CENTER")
    text:SetTextColor(1, 1, 1)
    indicator.text = text
    
    local anim = indicator:CreateAnimationGroup()
    
    local fadeOut = anim:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.3)
    fadeOut:SetStartDelay(0.2)
    
    anim:SetScript("OnFinished", function() indicator:Hide() end)
    indicator.anim = anim
    
    indicator.Show = function(self, keyText)
        if _G.KT and _G.KT.db and _G.KT.db.profile and _G.KT.db.profile.actionbars then
            local db = _G.KT.db.profile.actionbars
            if db.showKeypressIndicator == false then
                self.anim:Stop()
                self:Hide()
                return
            end
            local fontName = db.hotkeyFont or db.font or "Friz Quadrata TT"
            local fontPath = (KT and KT.ResolveFontForLocale and KT:ResolveFontForLocale(fontName)) or (LSM and LSM:Fetch("font", fontName)) or "Fonts\\FRIZQT__.TTF"
            local outline = db.hotkeyFontOutline or db.fontOutline or "OUTLINE"
            local btnHeight = button:GetHeight() or 36
            local fontSize = math.max(10, math.min(24, btnHeight * 0.6))
            self.text:SetFont(fontPath, fontSize, outline)
        end

        self.text:SetText(keyText or "?")
        self:SetAlpha(1)
        self.anim:Stop()
        self.anim:Play()
        getmetatable(self).__index.Show(self)
    end
    
    button.KT_KeypressIndicator = indicator
    return indicator
end

-- ============================================================================
-- 6. SISTEMA DE DETECCIÓN DE TECLAS
-- ============================================================================

local ActiveButtons = {}
local KeybindToButton = {}

local function GetButtonBindingAction(button)
    if button.GetBindingAction then return button:GetBindingAction() end
    
    local name = button:GetName()
    if not name then return nil end
    local id = button:GetID()
    
    if name:find("^ActionButton") then return "ACTIONBUTTON"..id end
    if name:find("^MultiBarBottomLeft") then return "MULTIACTIONBAR1BUTTON"..id end
    if name:find("^MultiBarBottomRight") then return "MULTIACTIONBAR2BUTTON"..id end
    if name:find("^MultiBarRight") then return "MULTIACTIONBAR3BUTTON"..id end
    if name:find("^MultiBarLeft") then return "MULTIACTIONBAR4BUTTON"..id end
    if name:find("^MultiBar5") then return "MULTIACTIONBAR5BUTTON"..id end
    if name:find("^MultiBar6") then return "MULTIACTIONBAR6BUTTON"..id end
    if name:find("^MultiBar7") then return "MULTIACTIONBAR7BUTTON"..id end
    if name:find("^PetActionButton") then return "BONUSACTIONBUTTON"..id end
    if name:find("^StanceButton") then return "SHAPESHIFTBUTTON"..id end
    
    return nil
end

local function RegisterButtonKeybinds(button)
    local action = GetButtonBindingAction(button)
    if not action then return end
    
    local key1, key2 = GetBindingKey(action)
    
    if key1 then KeybindToButton[key1] = button end
    if key2 then KeybindToButton[key2] = button end
    
    table.insert(ActiveButtons, button)
end

local KeyListenerFrame = CreateFrame("Frame", nil, UIParent)
KeyListenerFrame:SetFrameStrata("BACKGROUND")
KeyListenerFrame:SetFrameLevel(0)
KeyListenerFrame:EnableMouse(false)
KeyListenerFrame:SetPropagateKeyboardInput(true)

KeyListenerFrame:SetScript("OnKeyDown", function(self, key)
    if not IsAccessibleInputValue(key) or type(key) ~= "string" then return end
    local keyName = key:upper()
    local modString = ""
    if SafeInputBoolean(IsShiftKeyDown) then modString = modString .. "SHIFT-" end
    if SafeInputBoolean(IsControlKeyDown) then modString = modString .. "CTRL-" end
    if SafeInputBoolean(IsAltKeyDown) then modString = modString .. "ALT-" end
    
    local fullKey = modString .. keyName
    local button = KeybindToButton[fullKey]
    
    if not button and modString ~= "" then
        button = KeybindToButton[keyName]
    end
    
    local visible = button and button:IsVisible()
    if button and IsAccessibleInputValue(visible) and visible then
        if button.KT_ActionFlash then button.KT_ActionFlash:Play() end
        
        if button.ShakeAnimation then 
            button.ShakeAnimation:Stop()
            button.ShakeAnimation:Play()
        end
        
        if button.KT_PressAnim then
            if not (InCombatLockdown() and button:IsProtected()) then
                button.KT_PressAnim:Stop()
                button.KT_PressAnim:Play()
            end
        end
        
        local actionBarsDB = _G.KT and _G.KT.db and _G.KT.db.profile and _G.KT.db.profile.actionbars
        if button.KT_KeypressIndicator and (not actionBarsDB or actionBarsDB.showKeypressIndicator ~= false) then
            local displayKey = key:upper()
            local keySymbols = {
                ["BUTTON1"] = "L",
                ["BUTTON2"] = "R",
                ["BUTTON3"] = "M",
                ["MOUSEWHEELUP"] = "↑",
                ["MOUSEWHEELDOWN"] = "↓",
                ["SPACE"] = "␣",
            }
            displayKey = keySymbols[displayKey] or displayKey
            button.KT_KeypressIndicator:Show(displayKey)
        end
    end
end)

-- ============================================================================
-- 7. FUNCIÓN PRINCIPAL DE INTEGRACIÓN
-- ============================================================================

function ns.EnhanceActionButton(button)
    if not button or button.KT_Enhanced then return end
    
    CreateActionFlash(button)
    CreateKeypressIndicator(button)
    CreateShakeAnimation(button)
    CreatePressAnimation(button)
    SetupButtonFeedback(button)
    RegisterButtonKeybinds(button)
    
    button.KT_Enhanced = true
end

function ns.RefreshKeybinds()
    KeybindToButton = {}
    for _, button in ipairs(ActiveButtons) do
        RegisterButtonKeybinds(button)
    end
end

KeyListenerFrame:RegisterEvent("PLAYER_LOGIN")
KeyListenerFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        self:EnableKeyboard(true)
    end
end)

_G.KullThranUI_ActionButtonEnhancements = ns
