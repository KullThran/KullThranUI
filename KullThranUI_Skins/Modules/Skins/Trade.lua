local KT = LibStub('AceAddon-3.0'):GetAddon('KullThranUI')
local S = KT:GetModule('Skins', true)
if not S then return end

local _G = _G
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local ipairs = ipairs
local pcall = pcall
local type = type

local TRADE_ART = {
    'TradeFrameBg',
    'TradeRecipientBotLeftCorner',
    'TradeRecipientLeftBorder',
    'TradeRecipientBG',
    'TradeRecipientMoneyBg',
}

local TRADE_PANELS = {
    'TradeFrameInset',
    'TradeRecipientItemsInset',
    'TradeRecipientEnchantInset',
    'TradePlayerItemsInset',
    'TradePlayerEnchantInset',
}

local function IsUsable(frame)
    if not frame then return false end
    if frame.IsProtected then
        local ok, protected = pcall(frame.IsProtected, frame)
        if ok and protected then return false end
    end
    if frame.IsForbidden then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if ok and forbidden then return false end
    end
    return true
end

local function SafeMethod(object, method, ...)
    if not (object and type(object[method]) == 'function') then return end
    pcall(object[method], object, ...)
end

local function SkinCall(method, ...)
    local fn = S[method]
    if type(fn) == 'function' then
        pcall(fn, S, ...)
    end
end

local function EnsureAccentBorder(frame, key, alpha)
    if not IsUsable(frame) then return nil end
    if frame[key] then
        local accent = S:GetAccentColor()
        SafeMethod(frame[key], 'SetBackdropBorderColor', accent[1], accent[2], accent[3], alpha or 0.9)
        return frame[key]
    end

    local ok, border = pcall(CreateFrame, 'Frame', nil, frame, 'BackdropTemplate')
    if not ok or not border then return nil end
    SafeMethod(border, 'SetAllPoints', frame)
    local level = frame.GetFrameLevel and frame:GetFrameLevel() or 1
    SafeMethod(border, 'SetFrameLevel', level + 8)
    SafeMethod(border, 'SetBackdrop', {
        edgeFile = 'Interface\\Buttons\\WHITE8x8',
        edgeSize = S.mult or 1,
    })
    local accent = S:GetAccentColor()
    SafeMethod(border, 'SetBackdropBorderColor', accent[1], accent[2], accent[3], alpha or 0.9)
    frame[key] = border
    if S.RegisterBlizzardWindowBorder then
        S:RegisterBlizzardWindowBorder(border, function(self, enabled, color)
            SafeMethod(self, 'SetBackdropBorderColor', color[1], color[2], color[3], alpha or 0.9)
            SafeMethod(self, 'SetAlpha', enabled and 1 or 0)
        end)
    end
    return border
end

local function SetPanelColors(panel, borderAlpha, background)
    if not IsUsable(panel) then return end
    borderAlpha = borderAlpha or 0.5
    EnsureAccentBorder(panel, '_ktTradeAccentBorder', borderAlpha)
    if not panel.backdrop then return end
    local accent = S:GetAccentColor()
    local fill = background or 0.075
    SafeMethod(panel.backdrop, 'SetBackdropColor', fill, fill, fill + 0.015, 0.97)
    SafeMethod(panel.backdrop, 'SetBackdropBorderColor',
        accent[1] * 0.38, accent[2] * 0.38, accent[3] * 0.38, borderAlpha)
end

local function SkinPanel(panel)
    if not IsUsable(panel) then return end
    if not panel._ktTradePanel then
        SkinCall('StripTextures', panel)
        SkinCall('CreateBackdrop', panel, true)
        panel._ktTradePanel = true
    end
    SetPanelColors(panel)
end

local function SkinText(fontString)
    if not IsUsable(fontString) then return end
    SkinCall('HandleFont', fontString)
    SafeMethod(fontString, 'SetTextColor', 1, 1, 1, 1)
end

local function SkinTradeItemButton(button)
    if not IsUsable(button) then return end
    if not button._ktTradeItemButton then
        SkinCall('CreateBackdrop', button, true)
        button._ktTradeItemButton = true
    end

    EnsureAccentBorder(button, '_ktTradeAccentBorder', 0.36)
    if button.backdrop then
        local accent = S:GetAccentColor()
        SafeMethod(button.backdrop, 'SetBackdropColor', 0.06, 0.06, 0.075, 0.98)
        SafeMethod(button.backdrop, 'SetBackdropBorderColor',
            accent[1] * 0.42, accent[2] * 0.42, accent[3] * 0.42, 0.72)
    end

    local name = button.GetName and button:GetName()
    local icon = button.IconTexture or button.icon
    if not icon and name then
        icon = _G[name .. 'IconTexture']
    end
    if icon and IsUsable(icon) then
        SafeMethod(icon, 'SetAlpha', 1)
        SafeMethod(icon, 'SetTexCoord', 0.08, 0.92, 0.08, 0.92)
        SafeMethod(icon, 'SetDrawLayer', 'ARTWORK', 1)
        SkinCall('SetInside', icon, button.backdrop or button, 1)
    end
end

local function SkinTradeSlot(slot, index)
    if not IsUsable(slot) then return end
    local name = slot.GetName and slot:GetName()
    if slot._ktTradeSlotBorder then
        SafeMethod(slot._ktTradeSlotBorder, 'SetAlpha', 0)
    end

    local alternate = index and index % 2 == 0
    local rowFill = alternate and 0.088 or 0.068
    if not slot._ktTradeSurface then
        local ok, surface = pcall(slot.CreateTexture, slot, nil, 'BACKGROUND', nil, -2)
        if ok and surface then
            SafeMethod(surface, 'SetAllPoints', slot)
            slot._ktTradeSurface = surface
        end
    end
    if slot._ktTradeSurface then
        SafeMethod(slot._ktTradeSurface, 'SetColorTexture', rowFill, rowFill, rowFill + 0.018, 0.94)
    end
    if not slot._ktTradeSeparator then
        local ok, separator = pcall(slot.CreateTexture, slot, nil, 'ARTWORK', nil, 2)
        if ok and separator then
            SafeMethod(separator, 'SetPoint', 'BOTTOMLEFT', slot, 'BOTTOMLEFT', 1, 1)
            SafeMethod(separator, 'SetPoint', 'BOTTOMRIGHT', slot, 'BOTTOMRIGHT', -1, 1)
            SafeMethod(separator, 'SetHeight', 1)
            slot._ktTradeSeparator = separator
        end
    end
    if slot._ktTradeSeparator then
        local accent = S:GetAccentColor()
        SafeMethod(slot._ktTradeSeparator, 'SetColorTexture', accent[1], accent[2], accent[3], 0.22)
    end

    local slotTexture = slot.SlotTexture
    if not slotTexture and name then
        slotTexture = _G[name .. 'SlotTexture']
    end
    if slotTexture then SafeMethod(slotTexture, 'SetAlpha', 0) end

    local nameFrame = slot.NameFrame
    if not nameFrame and name then
        nameFrame = _G[name .. 'NameFrame']
    end
    if IsUsable(nameFrame) and not nameFrame._ktTradeNameFrame then
        SkinCall('StripTextures', nameFrame)
        SkinCall('CreateBackdrop', nameFrame, true)
        nameFrame._ktTradeNameFrame = true
    end
    SetPanelColors(nameFrame, 0.18, rowFill)
    local itemName = slot.Name
    if not itemName and name then
        itemName = _G[name .. 'Name']
    end
    SkinText(itemName)

    local itemButton = slot.ItemButton
    if not itemButton and name then
        itemButton = _G[name .. 'ItemButton']
    end
    SkinTradeItemButton(itemButton)
end

local function SkinTrade()
    if not (S.db and S.db.enable and S.db.trade ~= false) then return end
    local frame = _G.TradeFrame
    if not IsUsable(frame) then return end

    if not frame._ktTradeShell then
        SkinCall('SkinPremiumWindow', frame)
        for _, name in ipairs(TRADE_ART) do
            local object = _G[name]
            if object then SafeMethod(object, 'SetAlpha', 0) end
        end
        if frame.PortraitContainer then SafeMethod(frame.PortraitContainer, 'SetAlpha', 0) end
        if frame.Portrait then SafeMethod(frame.Portrait, 'SetAlpha', 0) end
        if frame.RecipientOverlay then
            SafeMethod(frame.RecipientOverlay, 'SetAlpha', 0)
            if frame.RecipientOverlay.portrait then
                SafeMethod(frame.RecipientOverlay.portrait, 'SetAlpha', 0)
            end
        end
        if frame.CloseButton then
            SkinCall('HandleCloseButton', frame.CloseButton)
        elseif _G.TradeFrameCloseButton then
            SkinCall('HandleCloseButton', _G.TradeFrameCloseButton)
        end
        frame._ktTradeShell = true
    end

    for _, name in ipairs(TRADE_PANELS) do
        SkinPanel(_G[name])
    end

    SkinText(_G.TradeFramePlayerNameText)
    SkinText(_G.TradeFrameRecipientNameText)
    SkinText(_G.TradeFramePlayerEnchantText)
    SkinText(_G.TradeFrameRecipientEnchantText)
    SkinText(frame.TitleText or _G.TradeFrameTitleText)

    for i = 1, 7 do
        SkinTradeSlot(_G['TradePlayerItem' .. i], i)
        SkinTradeSlot(_G['TradeRecipientItem' .. i], i)
    end

    SkinCall('HandleButton', _G.TradeFrameTradeButton)
    SkinCall('HandleButton', _G.TradeFrameCancelButton)
    for _, button in ipairs({ _G.TradeFrameTradeButton, _G.TradeFrameCancelButton }) do
        if IsUsable(button) then
            EnsureAccentBorder(button, '_ktTradeAccentBorder', 0.65)
            if button.backdrop then
                local accent = S:GetAccentColor()
                SafeMethod(button.backdrop, 'SetBackdropColor', 0.12, 0.12, 0.14, 1)
                SafeMethod(button.backdrop, 'SetBackdropBorderColor', accent[1] * 0.75, accent[2] * 0.75, accent[3] * 0.75, 0.85)
            end
        end
    end

    if IsUsable(frame) then
        local accent = S:GetAccentColor()
        if not frame._ktTradeDivider then
            local ok, divider = pcall(frame.CreateTexture, frame, nil, 'ARTWORK', nil, 6)
            if ok and divider then
                SafeMethod(divider, 'SetPoint', 'TOP', frame, 'TOP', 0, -58)
                SafeMethod(divider, 'SetPoint', 'BOTTOM', frame, 'BOTTOM', 0, 28)
                SafeMethod(divider, 'SetWidth', 1)
                frame._ktTradeDivider = divider
            end
        end
        if frame._ktTradeDivider then
            SafeMethod(frame._ktTradeDivider, 'SetColorTexture', accent[1], accent[2], accent[3], 0.45)
        end
        if not frame._ktTradeHeaderLine then
            local ok, line = pcall(frame.CreateTexture, frame, nil, 'ARTWORK', nil, 6)
            if ok and line then
                SafeMethod(line, 'SetPoint', 'TOPLEFT', frame, 'TOPLEFT', 10, -58)
                SafeMethod(line, 'SetPoint', 'TOPRIGHT', frame, 'TOPRIGHT', -10, -58)
                SafeMethod(line, 'SetHeight', 1)
                frame._ktTradeHeaderLine = line
            end
        end
        if frame._ktTradeHeaderLine then
            SafeMethod(frame._ktTradeHeaderLine, 'SetColorTexture', accent[1], accent[2], accent[3], 0.55)
        end
    end

    if not frame._ktTradeShowHooked then
        SafeMethod(frame, 'HookScript', 'OnShow', function()
            SkinTrade()
        end)
        frame._ktTradeShowHooked = true
    end
end

S:AddCallbackForAddon('Blizzard_TradeUI', 'TradeFrame', SkinTrade)

local tradeEvents = CreateFrame('Frame')
tradeEvents:RegisterEvent('TRADE_SHOW')
tradeEvents:RegisterEvent('PLAYER_ENTERING_WORLD')
tradeEvents:SetScript('OnEvent', function(_, event)
    local function Apply()
        pcall(SkinTrade)
    end
    if event == 'TRADE_SHOW' and C_Timer and C_Timer.After then
        C_Timer.After(0, Apply)
    else
        Apply()
    end
end)
