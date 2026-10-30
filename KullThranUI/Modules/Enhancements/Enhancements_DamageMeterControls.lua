-------------------------------------------------------------------------------
--  Damage Meter window controls and first-use preset picker.
--
--  Toolbar (right side of every meter header):
--    new      open another meter window
--    reset    reset all combat data (asks first)
--    mode     choose the shown data type
--    segment  left click flips Current / Overall, right click opens the history
--    options  opens the Damage Meter page of KUI's Enhancements
--  The toolbar replaces the session button; cfg.showToolbar = false brings it back.
--
--  Each meter style draws its own buttons (KUI flat accent, Retail grey bevel,
--  Forever bronze, Classic quickslot with gold glyphs). All art is packaged with
--  KUI (chat packs) or native to both clients (UI-Quickslot2).
-------------------------------------------------------------------------------
local _, ns = ...

local KT = (ns and ns.KT) or _G.KT
if not KT then
    return
end

local Mod = ns.Enhancements or KT:GetModule("Enhancements", true)
if not Mod then
    return
end

local CreateFrame = _G.CreateFrame
local C_Timer = _G.C_Timer
local ipairs = _G.ipairs
local math = _G.math
local type = _G.type

local function LText(text)
    if type(text) ~= "string" then
        return text
    end
    local locale = KT.GetLocale and KT:GetLocale()
    return locale and locale[text] or text
end

local function Internals()
    return Mod._damageMeterInternals
end

local CHAT_PACKS = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\chat\\"
local ICONS = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"
local BUTTON_SIZE = 17
local BUTTON_GAP = 2
local NARROW_WIDTH = 210

-- Button art per meter style. Rects are { x, y, w, h } in pixels of the sheet.
local BUTTON_STYLES = {
    retail = {
        file = CHAT_PACKS .. "chat_retail.tga", w = 256, h = 256,
        normal = { 1, 45, 34, 34 }, hover = { 37, 45, 34, 34 }, pressed = { 73, 45, 34, 34 },
        glyph = { 0.88, 0.89, 0.92 }, glyphHover = { 1, 0.82, 0.10 },
    },
    forever = {
        file = CHAT_PACKS .. "chat_forever.tga", w = 512, h = 256,
        normal = { 411, 1, 34, 34 }, hover = { 447, 1, 34, 34 }, pressed = { 1, 83, 34, 34 },
        glyph = { 0.925, 0.815, 0.667 }, glyphHover = { 0.862745, 0.521569, 0.376471 },
    },
    classic = {
        file = "Interface\\Buttons\\UI-Quickslot2", w = 64, h = 64,
        normal = { 10, 10, 44, 44 }, inset = 2,
        glyph = { 1, 0.82, 0.10 }, glyphHover = { 1, 1, 1 },
    },
}

local ORDER = { "new", "reset", "mode", "segment", "options" }
local GLYPHS = {
    reset = ICONS .. "Profiles\\delete.tga",
    mode = ICONS .. "Profiles\\modules.tga",
    options = ICONS .. "chaticons\\Confrig.png",
}
local TOOLTIPS = {
    new = "Create New Window",
    reset = "Reset All Data",
    mode = "Display Mode",
    segment = "Segment",
    options = "Damage Meter Options",
}

-- First UTF-8 character of a localized word (C / O, or a multi-byte letter).
local function FirstLetter(text)
    if type(text) ~= "string" or text == "" then return "?" end
    local length = 1
    while length < #text do
        local byte = text:byte(length + 1)
        if byte < 128 or byte >= 192 then break end -- not a continuation byte
        length = length + 1
    end
    return text:sub(1, length)
end

local function SetRect(texture, style, rect)
    texture:SetTexture(style.file)
    texture:SetTexCoord(rect[1] / style.w, (rect[1] + rect[3]) / style.w, rect[2] / style.h, (rect[2] + rect[4]) / style.h)
end

function Mod:GetDamageMeterToolbarStyleKey()
    local key = self.GetDamageMeterStyle and self:GetDamageMeterStyle() or "kui"
    return BUTTON_STYLES[key] and key or "kui"
end

local function GlyphColor(button, hovered)
    local key = Mod:GetDamageMeterToolbarStyleKey()
    local style = BUTTON_STYLES[key]
    if style then
        local c = hovered and style.glyphHover or style.glyph
        return c[1], c[2], c[3]
    end
    if hovered then
        local internals = Internals()
        if internals and internals.GetAccentColor then
            return internals.GetAccentColor()
        end
        return 1, 0.486, 0.039
    end
    return 0.80, 0.80, 0.86
end

local function PaintButton(button, hovered, pressed)
    local key = Mod:GetDamageMeterToolbarStyleKey()
    local style = BUTTON_STYLES[key]
    if style then
        local rect = (pressed and style.pressed) or (hovered and style.hover) or style.normal
        SetRect(button.art, style, rect)
        button.art:SetVertexColor(1, 1, 1, 1)
        button.art:Show()
        if style.inset then
            button.fill:ClearAllPoints()
            button.fill:SetPoint("TOPLEFT", style.inset, -style.inset)
            button.fill:SetPoint("BOTTOMRIGHT", -style.inset, style.inset)
            button.fill:SetColorTexture(0, 0, 0, 0.85)
            button.fill:Show()
        else
            button.fill:Hide()
        end
        -- Classic has no hover art of its own: Blizzard's square highlight.
        if key == "classic" and hovered then
            button.highlight:SetColorTexture(1, 0.82, 0.10, 0.18)
            button.highlight:Show()
        else
            button.highlight:Hide()
        end
    else
        button.art:Hide()
        button.fill:Hide()
        if hovered then
            local r, g, b = GlyphColor(button, true)
            button.highlight:SetColorTexture(r, g, b, 0.16)
            button.highlight:Show()
        else
            button.highlight:Hide()
        end
    end

    local r, g, b = GlyphColor(button, hovered)
    if button.glyph then button.glyph:SetVertexColor(r, g, b, 1) end
    if button.plusH then
        button.plusH:SetColorTexture(r, g, b, 1)
        button.plusV:SetColorTexture(r, g, b, 1)
    end
    if button.letter then button.letter:SetTextColor(r, g, b, 1) end
end

local function SegmentLetter(frame)
    local internals = Internals()
    local cfg = internals and internals.GetFrameConfig(frame) or {}
    if frame.selectedSessionID then
        return "#"
    end
    return FirstLetter(LText(cfg.session == "overall" and "Overall" or "Current"))
end

local function ShowTooltip(button)
    if not GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
    if button.kind == "segment" then
        local internals = Internals()
        local cfg = internals and internals.GetFrameConfig(button.meter) or {}
        local label = internals and internals.GetSessionLabel and internals.GetSessionLabel(cfg, button.meter)
        GameTooltip:AddLine(LText("Segment") .. ": " .. (label or LText("Current")), 1, 1, 1)
        GameTooltip:AddLine(LText("Left-click: Current / Overall"), 0.75, 0.75, 0.78)
        GameTooltip:AddLine(LText("Right-click: combat history"), 0.75, 0.75, 0.78)
    else
        GameTooltip:AddLine(LText(TOOLTIPS[button.kind]), 1, 1, 1)
    end
    GameTooltip:Show()
end

local function RefreshOptionsPage()
    if KT and KT.RefreshPage and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if KT.MenuPrincipal and KT.MenuPrincipal.IsShown and KT.MenuPrincipal:IsShown() then
                KT:RefreshPage(true)
            end
        end)
    end
end

function Mod:ResetDamageMeterData(frame)
    local internals = Internals()
    local api = _G.C_DamageMeter
    if api and api.ResetAllCombatSessions then
        pcall(api.ResetAllCombatSessions)
    end
    if internals and internals.GetSavedCombatHistory then
        internals.GetSavedCombatHistory().sessions = {}
    end
    if internals and frame then
        internals.SelectSession(frame, "current")
    end
end

local function ConfirmReset(frame)
    local dialogs = _G.StaticPopupDialogs
    if not (dialogs and _G.StaticPopup_Show) then
        Mod:ResetDamageMeterData(frame)
        return
    end
    dialogs.KT_DAMAGE_METER_RESET = dialogs.KT_DAMAGE_METER_RESET or {
        button1 = _G.YES or "Yes",
        button2 = _G.NO or "No",
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
        OnAccept = function(_, data) Mod:ResetDamageMeterData(data) end,
    }
    dialogs.KT_DAMAGE_METER_RESET.text = LText("Reset all Damage Meter data?")
    local popup = _G.StaticPopup_Show("KT_DAMAGE_METER_RESET")
    if popup then popup.data = frame end
end

function Mod:OpenDamageMeterOptions()
    local db = self.GetDB and self:GetDB()
    if db then
        db.ui = db.ui or {}
        db.ui.activeEnhancementCategory = "damage"
    end
    if KT.OpenMenu then
        KT:OpenMenu("enhancements")
    end
end

local function OnClick(button, mouseButton)
    local frame = button.meter
    local internals = Internals()
    if not (frame and internals) then return end
    if button.kind == "new" then
        if Mod.CreateAdditionalDamageMeterWindow then
            Mod:CreateAdditionalDamageMeterWindow(frame)
            RefreshOptionsPage()
        end
    elseif button.kind == "reset" then
        ConfirmReset(frame)
    elseif button.kind == "mode" then
        internals.ShowDropdown(button, nil, internals.BuildModeMenu(frame))
    elseif button.kind == "segment" then
        if mouseButton == "RightButton" then
            internals.ShowDropdown(button, nil, internals.BuildSessionMenu(frame))
        else
            local cfg = internals.GetFrameConfig(frame)
            local onOverall = not frame.selectedSessionID and cfg.session == "overall"
            internals.SelectSession(frame, onOverall and "current" or "overall")
        end
    elseif button.kind == "options" then
        Mod:OpenDamageMeterOptions()
    end
end

local function CreateToolbarButton(frame, kind)
    local button = CreateFrame("Button", nil, frame)
    button:SetSize(BUTTON_SIZE, BUTTON_SIZE)
    button:SetFrameLevel(frame:GetFrameLevel() + 6)
    button.kind = kind
    button.meter = frame
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button.fill = button:CreateTexture(nil, "BACKGROUND")
    button.art = button:CreateTexture(nil, "BORDER")
    button.art:SetAllPoints()
    button.highlight = button:CreateTexture(nil, "ARTWORK", nil, -1)
    button.highlight:SetAllPoints()
    button.highlight:Hide()

    if kind == "new" then
        button.plusH = button:CreateTexture(nil, "OVERLAY")
        button.plusH:SetSize(9, 2)
        button.plusH:SetPoint("CENTER")
        button.plusV = button:CreateTexture(nil, "OVERLAY")
        button.plusV:SetSize(2, 9)
        button.plusV:SetPoint("CENTER")
    elseif kind == "segment" then
        button.letter = button:CreateFontString(nil, "OVERLAY")
        button.letter:SetPoint("CENTER", 0, 0)
    else
        button.glyph = button:CreateTexture(nil, "OVERLAY")
        button.glyph:SetSize(10, 10)
        button.glyph:SetPoint("CENTER")
        button.glyph:SetTexture(GLYPHS[kind])
    end

    button:SetScript("OnEnter", function(self)
        self._hovered = true
        PaintButton(self, true, false)
        ShowTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        self._hovered = nil
        PaintButton(self, false, false)
        if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetScript("OnMouseDown", function(self) PaintButton(self, true, true) end)
    button:SetScript("OnMouseUp", function(self) PaintButton(self, self._hovered, false) end)
    button:SetScript("OnClick", OnClick)
    return button
end

function Mod:CreateDamageMeterToolbar(frame)
    if not frame or frame.toolbarButtons then return end
    frame.toolbarButtons = {}
    for _, kind in ipairs(ORDER) do
        frame.toolbarButtons[kind] = CreateToolbarButton(frame, kind)
    end
end

-- Places and paints the toolbar for a meter `width` px wide; returns the width it
-- takes in the header (0 when the toolbar is off, so the session button shows).
function Mod:LayoutDamageMeterToolbar(frame, width)
    local buttons = frame and frame.toolbarButtons
    if not buttons then return 0 end
    local internals = Internals()
    local cfg = internals and internals.GetFrameConfig(frame) or {}
    if cfg.showToolbar == false then
        for _, button in pairs(buttons) do button:Hide() end
        return 0
    end
    -- Narrow windows keep the three essentials; new window and mode stay in the title menu.
    local narrow = (width or 0) < NARROW_WIDTH
    local x = -6
    local used = 0
    for index = #ORDER, 1, -1 do
        local kind = ORDER[index]
        local button = buttons[kind]
        if narrow and (kind == "new" or kind == "mode") then
            button:Hide()
        else
            button:ClearAllPoints()
            button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", x, -7)
            button:Show()
            x = x - BUTTON_SIZE - BUTTON_GAP
            used = used + BUTTON_SIZE + BUTTON_GAP
        end
    end
    local letter = buttons.segment.letter
    if letter then
        local font = internals and internals.GetDamageMeterFont and internals.GetDamageMeterFont(cfg)
        letter:SetFont(font or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        letter:SetText(SegmentLetter(frame))
    end
    for _, button in pairs(buttons) do
        PaintButton(button, button._hovered, false)
    end
    return used
end

-------------------------------------------------------------------------------
--  First-use preset picker: what the main window shows.
-------------------------------------------------------------------------------
local PRESETS = { "damageDone", "dps", "healingDone", "hps", "damageTaken", "interrupts", "dispels", "deaths" }

function Mod:ShouldOfferDamageMeterPreset()
    local internals = Internals()
    if not internals then return false end
    if not internals.IsDamageMeterModuleEnabled() then return false end
    local cfg = internals.GetConfig()
    return cfg.enabled == true and cfg.presetPicked == false
end

function Mod:ApplyDamageMeterPreset(modeKey)
    local internals = Internals()
    if not internals then return end
    local cfg = internals.GetConfig()
    if modeKey and internals.IsModeSupported(modeKey) then
        cfg.mode = modeKey
    end
    cfg.presetPicked = true
    if self.damageMeterPresetPicker then self.damageMeterPresetPicker:Hide() end
    if self.damageMeterFrame then
        self:RefreshDamageMeterStyle(false, self.damageMeterFrame)
        self:UpdateDamageMeterData(self.damageMeterFrame)
    end
end

local function BuildPicker()
    local internals = Internals()
    local picker = CreateFrame("Frame", "KullThranUIDamageMeterPresetPicker", _G.UIParent, "BackdropTemplate")
    picker:SetFrameStrata("DIALOG")
    picker:SetSize(372, 236)
    picker:SetPoint("CENTER", 0, 80)
    picker:EnableMouse(true)
    picker:SetMovable(true)
    picker:RegisterForDrag("LeftButton")
    picker:SetScript("OnDragStart", picker.StartMoving)
    picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
    picker:SetClampedToScreen(true)
    local r, g, b = internals.GetAccentColor()
    KT:AddBackdrop(picker, 0.025, 0.03, 0.04, 0.97)
    KT:AddBorder(picker, r, g, b, 0.8)

    local title = picker:CreateFontString(nil, "OVERLAY")
    title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    title:SetPoint("TOP", 0, -14)
    title:SetText(LText("Damage Meter"))
    title:SetTextColor(r, g, b, 1)

    local subtitle = picker:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -6)
    subtitle:SetText(LText("What should the main window show?"))
    subtitle:SetTextColor(0.86, 0.86, 0.90, 1)

    picker.cards = {}
    local column, row = 0, 0
    for _, modeKey in ipairs(PRESETS) do
        if internals.IsModeSupported(modeKey) then
            local card = CreateFrame("Button", nil, picker, "BackdropTemplate")
            card:SetSize(170, 30)
            card:SetPoint("TOPLEFT", 12 + column * 178, -56 - row * 36)
            KT:AddBackdrop(card, 0.06, 0.065, 0.08, 0.95)
            KT:AddBorder(card, r, g, b, 0.25)
            local icon = card:CreateTexture(nil, "ARTWORK")
            icon:SetSize(20, 20)
            icon:SetPoint("LEFT", 6, 0)
            icon:SetTexture(internals.MODE_ICONS[modeKey])
            local label = card:CreateFontString(nil, "OVERLAY")
            label:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
            label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
            label:SetText(LText(internals.MODE_LABELS[modeKey]))
            card:SetScript("OnEnter", function(self) KT:AddBorder(self, r, g, b, 0.9) end)
            card:SetScript("OnLeave", function(self) KT:AddBorder(self, r, g, b, 0.25) end)
            card:SetScript("OnClick", function() Mod:ApplyDamageMeterPreset(modeKey) end)
            picker.cards[#picker.cards + 1] = card
            column = column + 1
            if column == 2 then column, row = 0, row + 1 end
        end
    end

    local skip = CreateFrame("Button", nil, picker)
    skip:SetSize(150, 18)
    skip:SetPoint("BOTTOM", 0, 10)
    skip.text = skip:CreateFontString(nil, "OVERLAY")
    skip.text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 10, "")
    skip.text:SetAllPoints()
    skip.text:SetText(LText("Keep Damage Done"))
    skip.text:SetTextColor(0.62, 0.62, 0.68, 1)
    skip:SetScript("OnEnter", function(self) self.text:SetTextColor(r, g, b, 1) end)
    skip:SetScript("OnLeave", function(self) self.text:SetTextColor(0.62, 0.62, 0.68, 1) end)
    skip:SetScript("OnClick", function() Mod:ApplyDamageMeterPreset(nil) end)
    picker:SetHeight(56 + math.ceil(#picker.cards / 2) * 36 + 34)
    return picker
end

function Mod:ShowDamageMeterPresetPicker()
    if not Internals() then return end
    self.damageMeterPresetPicker = self.damageMeterPresetPicker or BuildPicker()
    self.damageMeterPresetPicker:Show()
end

-- Called after every meter refresh: offers the picker once, out of combat.
function Mod:MaybeShowDamageMeterPresetPicker()
    if self._damageMeterPresetQueued or not self:ShouldOfferDamageMeterPreset() then return end
    self._damageMeterPresetQueued = true
    C_Timer.After(1.5, function()
        Mod._damageMeterPresetQueued = nil
        if not Mod:ShouldOfferDamageMeterPreset() then return end
        if _G.InCombatLockdown and _G.InCombatLockdown() then
            -- Retry once combat ends.
            local waiter = Mod._damageMeterPresetWaiter or CreateFrame("Frame")
            Mod._damageMeterPresetWaiter = waiter
            waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
            waiter:SetScript("OnEvent", function(self)
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                Mod:MaybeShowDamageMeterPresetPicker()
            end)
            return
        end
        Mod:ShowDamageMeterPresetPicker()
    end)
end
