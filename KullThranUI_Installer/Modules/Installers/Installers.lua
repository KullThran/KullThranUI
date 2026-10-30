local ADDON_NAME, addonNS = ...
local ns = _G.KT_NS or _G.KullThranUI_NS or addonNS
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local Mod = KT:NewModule("Installer", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")

local _G = _G
local CreateFrame = CreateFrame
local UIParent = UIParent
local C_AddOns = C_AddOns
local C_EditMode = C_EditMode 
local StaticPopup_Show = StaticPopup_Show
local StaticPopupDialogs = StaticPopupDialogs

-- Constants
local ICON_PATH = "Interface\\AddOns\\KullThranUI\\Modules\\Installers\\Icons\\"
local DISCORD_INVITE_URL = "https://discord.gg/cqAVWpeVvd"
local STEP_PROFILE = 19
local INSTALLER_STEP_ORDER = { 1, 2, 19, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 30, 20 }
local TOTAL_INSTALLER_STEPS = 20
local KUI_TEXTURE_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\"
-- Holo toggles of the Language step and the soft glows (installer_toggle.py).
local INSTALLER_TOGGLE_PATH = KUI_TEXTURE_PATH .. "InstallerWindow\\Toggle\\"
local KUI_ICON_PATH = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\"
local EFL_FRIEND_ICON = KUI_ICON_PATH .. "chaticons\\FriendList.png"
local EFL_HEADER_ICON = KUI_ICON_PATH .. "EnhancedFriendList\\Friends.png"
local EFL_WHITE8X8 = "Interface\\Buttons\\WHITE8X8"
local EFL_FRAME_BACKGROUND_TEXTURE = KUI_TEXTURE_PATH .. "InstallerBackground.png"
local EFL_BUTTON_TEXTURE = KUI_TEXTURE_PATH .. "Button.png"
local EFL_GLOSS_TEXTURE = KUI_TEXTURE_PATH .. "gloss.tga"
local INSTALLER_MELLI_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga"
local INSTALLER_BAGS_BACKGROUND = KUI_TEXTURE_PATH .. "BagsBackground.png"

-- TU FUENTE PERSONALIZADA
local function GetKTFont()
    if KT and KT.FONT_PATH then return KT.FONT_PATH end
    return "Interface\\AddOns\\KullThranUI\\Libraries\\font\\AAA_ITC_Avant_Garde.ttf"
end

-- TU COLOR PERSONALIZADO (#DE1D4A -> RGB)
local KT_COLOR = {0.87, 0.11, 0.29, 1} 

-- Colores Generales (Estilo Dark Flat)
local COLOR_BG = {0.11, 0.11, 0.11, 1} 
local COLOR_BORDER = {0, 0, 0, 1}
local COLOR_BTN_NORMAL = {0.16, 0.16, 0.16, 1} 
local COLOR_BTN_HOVER = {0.25, 0.25, 0.25, 1} 

-- Addon List
local RECOMMENDED_ADDONS = {
    { name = "LittleWigs", icon = "LittleWigs.tga", url = "https://www.curseforge.com/wow/addons/littlewigs", profileString = nil },
    { name = "SharedMedia", icon = "SharedMedia.tga", url = "https://www.curseforge.com/wow/addons/sharedmedia", profileString = nil },
    { name = "Auctionator", icon = "Auctionator.tga", url = "https://www.curseforge.com/wow/addons/auctionator", profileString = nil },
    { name = "Syndicator", icon = "Syndicator.tga", url = "https://www.curseforge.com/wow/addons/syndicator", profileString = nil },
    { name = "Northern Sky Raid Tools", folder = "NorthernSkyRaidTools", icon = "NorthernSkyRaidTools.tga", url = "https://www.curseforge.com/wow/addons/northern-sky-raid-tools", profileString = nil },
    { name = "BigWigs", icon = "BigWigs.tga", url = "https://www.curseforge.com/wow/addons/bigwigs", profileString = nil },
    { name = "Opie", icon = "Opie.tga", url = "https://www.curseforge.com/wow/addons/opie", profileString = nil },
    { name = "Plumber", icon = "Plumber.tga", url = "https://www.curseforge.com/wow/addons/plumber", profileString = nil },
    { name = "Waypoint UI", folder = "WaypointUI", icon = "WaypointUI.tga", url = "https://www.curseforge.com/wow/addons/waypointui", profileString = nil },
}

-- Localization
local L = KT:GetLocale()


-------------------------------------------------------------------------
-- HELPER FUNCTIONS
-------------------------------------------------------------------------
local function CreateBackdrop(f)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
    })
    f:SetBackdropColor(unpack(COLOR_BG))
    f:SetBackdropBorderColor(unpack(COLOR_BORDER))

    if f.GetObjectType and (f:GetObjectType() == "Button" or f:GetObjectType() == "CheckButton") and not f.KTInstallerPressedFeedback then
        f.KTInstallerPressedFeedback = true
        f:HookScript("OnMouseDown", function(self)
            if self:IsEnabled() then
                self:SetBackdropColor(0.09, 0.09, 0.09, 1)
                self:SetBackdropBorderColor(unpack(KT_COLOR))
            end
        end)
        f:HookScript("OnMouseUp", function(self)
            if self:IsEnabled() then
                self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
                self:SetBackdropBorderColor(unpack(KT_COLOR))
            end
        end)
    end
end

-------------------------------------------------------------------------
-- ANIMATED BUTTON (diagonal sweep + glow, driven by OnUpdate)
-------------------------------------------------------------------------
local SWEEP_EDGE_TEXTURE = KUI_TEXTURE_PATH .. "SweepEdge.tga"
local SWEEP_DURATION = 0.30
local SWEEP_SKEW = 0.58 -- tan(30 degrees): width of the slanted leading edge per pixel of height
local SWEEP_TEXT_FILLED = 0.04

local function UpdateButtonSweep(btn, progress)
    local sweep = btn.KT_Sweep
    if not sweep then return end
    local width, height = btn:GetWidth() or 0, btn:GetHeight() or 0
    local inner = width - 2
    local edge = height * SWEEP_SKEW
    local r, g, b = KT_COLOR[1], KT_COLOR[2], KT_COLOR[3]
    local eased = progress * progress * (3 - 2 * progress)

    if eased <= 0.001 or inner <= 0 or edge <= 0 then
        sweep.body:Hide()
        sweep.edge:Hide()
    else
        local reach = eased * (inner + edge)
        local bodyWidth = math.max(0, math.min(inner, reach - edge))
        local edgeWidth = math.max(0, math.min(edge, reach - bodyWidth, inner - bodyWidth))

        sweep.body:SetVertexColor(r * 0.8, g * 0.8, b * 0.8, 1)
        if bodyWidth > 0.5 then
            sweep.body:SetWidth(bodyWidth)
            sweep.body:Show()
        else
            sweep.body:Hide()
        end

        sweep.edge:SetVertexColor(r * 0.8, g * 0.8, b * 0.8, 1)
        if edgeWidth > 0.5 then
            sweep.edge:ClearAllPoints()
            sweep.edge:SetPoint("TOPLEFT", btn, "TOPLEFT", 1 + bodyWidth, -1)
            sweep.edge:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1 + bodyWidth, 1)
            sweep.edge:SetWidth(edgeWidth)
            sweep.edge:SetTexCoord(0, edgeWidth / edge, 0, 1)
            sweep.edge:Show()
        else
            sweep.edge:Hide()
        end
    end

    sweep.glow:SetBackdropBorderColor(r, g, b, 0.38 * eased)
end

-- Hover animation for any Button: a skewed accent fill sweeps across the
-- button, the text flips to dark while it is filled, and a soft glow fades in.
local function AttachButtonSweep(btn)
    if btn.KT_Sweep then return end
    local sweep = {
        progress = 0,
        target = 0,
        body = btn:CreateTexture(nil, "BACKGROUND", nil, 7),
        edge = btn:CreateTexture(nil, "BACKGROUND", nil, 7),
        glow = CreateFrame("Frame", nil, btn, "BackdropTemplate"),
        driver = CreateFrame("Frame", nil, btn),
    }
    btn.KT_Sweep = sweep

    sweep.body:SetTexture(EFL_WHITE8X8)
    sweep.body:SetPoint("TOPLEFT", btn, "TOPLEFT", 1, -1)
    sweep.body:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 1, 1)
    sweep.body:Hide()
    sweep.edge:SetTexture(SWEEP_EDGE_TEXTURE)
    sweep.edge:Hide()

    sweep.glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -3, 3)
    sweep.glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 3, -3)
    sweep.glow:SetFrameLevel(math.max(0, btn:GetFrameLevel() - 1))
    sweep.glow:SetBackdrop({ edgeFile = EFL_WHITE8X8, edgeSize = 3 })
    sweep.glow:SetBackdropBorderColor(0, 0, 0, 0)

    local function Step(_, elapsed)
        local delta = elapsed / SWEEP_DURATION
        if sweep.progress < sweep.target then
            sweep.progress = math.min(sweep.target, sweep.progress + delta)
        else
            sweep.progress = math.max(sweep.target, sweep.progress - delta)
        end
        UpdateButtonSweep(btn, sweep.progress)
        if sweep.progress == sweep.target then
            sweep.driver:SetScript("OnUpdate", nil)
        end
    end
    local function Animate(target)
        if target == 1 and sweep.progress == 0 then
            local fs = btn:GetFontString()
            if fs then
                local r, g, b = fs:GetTextColor()
                sweep.restColor = { r, g, b }
                local fontPath, fontSize, fontFlags = fs:GetFont()
                sweep.restFont = { fontPath, fontSize, fontFlags }
            end
        end
        sweep.target = target
        sweep.driver:SetScript("OnUpdate", Step)
    end

    -- The sweep handlers are the button's primary scripts and any script the
    -- caller sets later (the language / style buttons set their own OnEnter and
    -- OnLeave) is chained in front of them. A plain HookScript would be lost then.
    local rawSetScript = btn.SetScript
    local userScripts = {}
    local ours = {
        OnEnter = function(self)
            if self:IsEnabled() then Animate(1) end
        end,
        OnLeave = function() Animate(0) end,
        OnHide = function()
            sweep.progress, sweep.target = 0, 0
            sweep.driver:SetScript("OnUpdate", nil)
            UpdateButtonSweep(btn, 0)
        end,
    }
    local function Install(name)
        rawSetScript(btn, name, function(self, ...)
            local user = userScripts[name]
            if user then user(self, ...) end
            ours[name](self, ...)
        end)
    end
    for name in pairs(ours) do
        userScripts[name] = btn:GetScript(name)
        Install(name)
    end
    btn.SetScript = function(self, name, handler)
        if ours[name] then
            userScripts[name] = handler
            Install(name)
        else
            rawSetScript(self, name, handler)
        end
    end
end

-- Cut-corner look of the KUI options window (KT.Widgets:SkinCutButton):
-- corners cut at the top left and bottom right, a drifting accent border and
-- a face that draws back on hover. Steps mark a selected button by painting
-- its backdrop border in the accent; that call now holds the hovered look.
local function IsInstallerAccent(r, g, b, a)
    if (a or 1) <= 0 then return false end
    return math.abs((r or 0) - KT_COLOR[1]) < 0.02 and math.abs((g or 0) - KT_COLOR[2]) < 0.02
        and math.abs((b or 0) - KT_COLOR[3]) < 0.02
end

local function SkinCutButton(btn)
    local widgets = KT.Widgets
    if not (widgets and widgets.SkinCutButton) then return false end
    if btn.Left then btn.Left:SetAlpha(0) end
    if btn.Middle then btn.Middle:SetAlpha(0) end
    if btn.Right then btn.Right:SetAlpha(0) end
    if btn.SetNormalTexture then btn:SetNormalTexture("") end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    if btn.SetPushedTexture then btn:SetPushedTexture("") end
    if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
    if btn.SetBackdrop then btn:SetBackdrop(nil) end
    btn.SetBackdropColor = function() end
    btn.SetBackdropBorderColor = function(self, r, g, b, a)
        -- Only buttons that show a selection call this: mark them as choices.
        self._choiceKT = true
        if self.SetCutActive then self:SetCutActive(IsInstallerAccent(r, g, b, a)) end
    end

    local fs = btn:GetFontString()
    if not fs then
        fs = btn:CreateFontString(nil, "OVERLAY")
        btn:SetFontString(fs)
    end
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", btn, "LEFT", 8, 0)
    fs:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:SetWordWrap(false)
    if fs.SetMaxLines then fs:SetMaxLines(1) end

    -- Labels in capitals, as the options window's buttons; the size steps
    -- down until the label fits.
    local rawSetText = btn.SetText
    local function Fit(self)
        local availableWidth = math.max(24, (self:GetWidth() or 0) - 16)
        fs:SetWordWrap(false)
        if fs.SetMaxLines then fs:SetMaxLines(1) end
        local fits
        for fontSize = 11, 9, -1 do
            fs:SetFont(GetKTFont(), fontSize, "")
            local textWidth = fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()
            if not textWidth or textWidth <= availableWidth then fits = true break end
        end
        -- Long translations: two lines inside a tall enough button instead of
        -- a label cut at the edges.
        if not fits and (self:GetHeight() or 0) >= 28 then
            fs:SetFont(GetKTFont(), 9, "")
            fs:SetWordWrap(true)
            if fs.SetMaxLines then fs:SetMaxLines(2) end
        elseif not fits then
            fs:SetFont(GetKTFont(), 8, "")
        end
    end
    btn.SetText = function(self, text)
        rawSetText(self, type(text) == "string" and text:upper() or text)
        Fit(self)
    end
    btn:SetText(btn:GetText() or "")

    widgets:SkinCutButton(btn, { accent = function() return KT_COLOR[1], KT_COLOR[2], KT_COLOR[3] end })
    return true
end

local function SkinButton(btn)
    if SkinCutButton(btn) then return end
    -- Remove default textures
    if btn.Left then btn.Left:SetAlpha(0) end
    if btn.Middle then btn.Middle:SetAlpha(0) end
    if btn.Right then btn.Right:SetAlpha(0) end
    if btn.SetNormalTexture then btn:SetNormalTexture("") end
    if btn.SetHighlightTexture then btn:SetHighlightTexture("") end
    if btn.SetPushedTexture then btn:SetPushedTexture("") end
    if btn.SetDisabledTexture then btn:SetDisabledTexture("") end
    
    -- Create Custom Backdrop
    CreateBackdrop(btn)
    btn:SetBackdropColor(unpack(COLOR_BTN_NORMAL))
    
    -- Font Style (ensure the button actually has a FontString)
    local fs = btn:GetFontString()
    if not fs then
        fs = btn:CreateFontString(nil, "OVERLAY")
        fs:SetPoint("CENTER")
        btn:SetFontString(fs)
    end
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", btn, "LEFT", 8, 0)
    fs:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    fs:SetJustifyH("CENTER")
    fs:SetJustifyV("MIDDLE")
    fs:SetWordWrap(false)
    if fs.SetMaxLines then
        fs:SetMaxLines(1)
    end

    local availableWidth = math.max(24, (btn:GetWidth() or 0) - 16)
    local fittedSize = 12
    for fontSize = 12, 9, -1 do
        fs:SetFont(GetKTFont(), fontSize, "OUTLINE")
        local textWidth
        if fs.GetUnboundedStringWidth then
            textWidth = fs:GetUnboundedStringWidth()
        else
            textWidth = fs:GetStringWidth()
        end
        fittedSize = fontSize
        if not textWidth or textWidth <= availableWidth then
            break
        end
    end
    fs:SetFont(GetKTFont(), fittedSize, "OUTLINE")
    fs:SetTextColor(0.95, 0.95, 0.95)
    
    AttachButtonSweep(btn)

    -- Scripts for Hover Effect
    btn:HookScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
        self:SetBackdropBorderColor(unpack(KT_COLOR)) 
    end)
    btn:HookScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(COLOR_BTN_NORMAL))
        self:SetBackdropBorderColor(unpack(COLOR_BORDER))
    end)
    btn:HookScript("OnMouseDown", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(0.09, 0.09, 0.09, 1)
            self:SetBackdropBorderColor(unpack(KT_COLOR))
        end
    end)
    btn:HookScript("OnMouseUp", function(self)
        if self:IsEnabled() then
            self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
            self:SetBackdropBorderColor(unpack(KT_COLOR))
        end
    end)
end

local function CreateSkipCheckbox(parent, anchor)
    local installerDb = KT.db and KT.db.profile and KT.db.profile.installer
    if not installerDb then
        KT.db.profile.installer = {}
        installerDb = KT.db.profile.installer
    end

    local checkbox = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    checkbox:SetSize(18, 18)
    -- In the footer, right of the Skip button (above it would cross the
    -- progress line).
    checkbox:SetPoint("LEFT", anchor, "RIGHT", 16, 0)
    CreateBackdrop(checkbox)
    checkbox:SetBackdropColor(0, 0, 0, 1)
    if checkbox.SetHitRectInsets then
        checkbox:SetHitRectInsets(0, -130, 0, 0)
    end

    checkbox.Checked = checkbox:CreateTexture(nil, "ARTWORK")
    checkbox.Checked:SetTexture(EFL_WHITE8X8)
    checkbox.Checked:SetPoint("TOPLEFT", 4, -4)
    checkbox.Checked:SetPoint("BOTTOMRIGHT", -4, 4)
    checkbox.Checked:SetVertexColor(unpack(KT_COLOR))

    local label = checkbox:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", checkbox, "RIGHT", 6, 0)
    label:SetFont(GetKTFont(), 12, "OUTLINE")
    label:SetTextColor(0.95, 0.95, 0.95, 1)
    label:SetText(LText("Don't show again"))

    local function RefreshCheckedState()
        local checked = checkbox:GetChecked() and true or false
        checkbox.Checked:SetAlpha(checked and 1 or 0)
        installerDb.dontShowAgain = checked or nil
        installerDb.showOnLogin = not checked
        if checked then
            installerDb.reopenStep = nil
            installerDb.resumeStep = nil
            installerDb.reopenOnReload = nil
            installerDb.forceOpenForCharacter = nil
            installerDb.isOpen = false
        end
    end

    checkbox:SetChecked(installerDb.dontShowAgain == true)
    checkbox.Checked:SetAlpha(checkbox:GetChecked() and 1 or 0)
    checkbox:SetScript("OnClick", RefreshCheckedState)

    anchor:HookScript('OnMouseDown', function()
        local frame = parent and parent.GetParent and parent:GetParent()
        if frame then frame._ktExplicitlyClosed = true end
    end)
    parent.skipChk = checkbox
    return checkbox
end

local function RequestInstallerReload(self, step)
    local db = KT and KT.db and KT.db.profile and KT.db.profile.installer
    if not db then
        ReloadUI()
        return
    end

    local reopenStep = tonumber(step) or tonumber(db.step) or 1
    db.step = reopenStep
    if db.dontShowAgain == true then
        db.reopenStep = nil
        db.resumeStep = nil
        db.reopenOnReload = nil
        db.isOpen = false
    else
        db.reopenStep = reopenStep
        db.resumeStep = reopenStep
        db.reopenOnReload = true
        db.isOpen = true
    end

    if StaticPopupDialogs["KT_INSTALLER_RELOAD"] then
        StaticPopup_Show("KT_INSTALLER_RELOAD")
    else
        ReloadUI()
    end
end

-- Most installer choices only take effect after a reload. Asking after every
-- click meant a reload per page (and popups stacking with the compatibility
-- one), so they are collected here and applied with a single reload when the
-- installer finishes or is closed. The footer tells the user how many wait.
function Mod:DeferReload(step)
    self.moduleSettingsDirty = true
    self.pendingReloadSteps = self.pendingReloadSteps or {}
    self.pendingReloadSteps[tonumber(step) or 0] = true
    self:UpdatePendingReloadNotice()
end

-- The Visual Style picked in the installer (Unit Frames style row or the
-- Visual Style cards) waits here and is applied with that same reload.
function Mod:SetPendingVisualTheme(themeKey)
    local themes = KT.VisualThemes
    local rendered = themes and themes.GetRenderedTheme and themes:GetRenderedTheme() or "kui"
    if not themeKey or themeKey == rendered then
        self.pendingVisualTheme = nil
    else
        self.pendingVisualTheme = themeKey
        self:DeferReload(3)
    end
end

function Mod:GetChosenVisualTheme()
    local themes = KT.VisualThemes
    return self.pendingVisualTheme or (themes and themes.GetRenderedTheme and themes:GetRenderedTheme()) or "kui"
end

-- Writes the pending Visual Style's settings (no reload of its own).
function Mod:CommitPendingVisualTheme()
    local key = self.pendingVisualTheme
    self.pendingVisualTheme = nil
    local themes = KT.VisualThemes
    if key and themes and themes.ApplyAll then pcall(themes.ApplyAll, themes, key, true) end
end

function Mod:GetPendingReloadCount()
    local count = 0
    for _ in pairs(self.pendingReloadSteps or {}) do count = count + 1 end
    if count == 0 and self.moduleSettingsDirty then count = 1 end
    return count
end

-- Tooltip-style card hung under the installer window (outside it, so it
-- never takes room from a page or sits on its buttons), styled like the
-- Unlock Mode dialog: dark box, accent border and accent top line.
function Mod:UpdatePendingReloadNotice()
    local frame = self.frame
    if not frame then return end
    local card = frame._ktPendingReloadCard
    if not card then
        card = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        card:SetPoint("TOP", frame, "BOTTOM", 0, -6)
        card:SetFrameStrata(frame:GetFrameStrata())
        card:SetFrameLevel(frame:GetFrameLevel() + 60)
        card:EnableMouse(false)
        CreateBackdrop(card)
        card.topAccent = card:CreateTexture(nil, "ARTWORK")
        card.topAccent:SetPoint("TOPLEFT", 1, -1)
        card.topAccent:SetPoint("TOPRIGHT", -1, -1)
        card.topAccent:SetHeight(2)
        card.title = card:CreateFontString(nil, "OVERLAY")
        card.title:SetPoint("TOPLEFT", 12, -10)
        card.title:SetJustifyH("LEFT")
        card.body = card:CreateFontString(nil, "OVERLAY")
        card.body:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
        card.body:SetJustifyH("LEFT")
        card.body:SetWordWrap(true)
        frame._ktPendingReloadCard = card
    end
    local count = self:GetPendingReloadCount()
    if count <= 0 then
        card:Hide()
        return
    end
    card:SetBackdropColor(0.035, 0.032, 0.04, 0.97)
    card:SetBackdropBorderColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 0.9)
    card.topAccent:SetColorTexture(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 1)
    card.title:SetFont(GetKTFont(), 13, "OUTLINE")
    card.title:SetTextColor(1, 1, 1, 1)
    card.title:SetText(LText("Pending changes"))
    card.body:SetFont(GetKTFont(), 12, "")
    card.body:SetTextColor(0.86, 0.86, 0.88, 1)
    card.body:SetWidth(420)
    card.body:SetText(string.format(LText("%d change(s) pending: applied with one reload when you finish."), count))
    local bodyW = math.min(420, math.ceil(card.body.GetUnboundedStringWidth and card.body:GetUnboundedStringWidth() or 420))
    card.body:SetWidth(bodyW)
    local width = math.max(bodyW, math.ceil(card.title:GetStringWidth() or 0)) + 24
    card:SetSize(width, 10 + (card.title:GetStringHeight() or 14) + 4 + (card.body:GetStringHeight() or 14) + 12)
    card:Show()
end

-- One reload for everything chosen in the installer. The window is already
-- hidden, so the ReloadUI hook does not bring the installer back afterwards.
function Mod:ApplyPendingReload(finished)
    local count = self:GetPendingReloadCount()
    if count == 0 then return false end
    self.moduleSettingsDirty = nil
    self.pendingReloadSteps = nil
    -- The chosen Visual Style is written now either way, so "Later" keeps it
    -- for the next reload.
    self:CommitPendingVisualTheme()
    StaticPopupDialogs["KT_INSTALLER_APPLY_RELOAD"] = {
        text = finished and LText("Setup complete. Reload now to apply your changes?")
            or LText("Some of your installer choices need a reload to take effect. Reload now?"),
        button1 = L["KT_INSTALLER_RELOAD"] or "Reload",
        button2 = L["KT_INSTALLER_LATER"] or "Later",
        OnAccept = function() ReloadUI() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopup_Show("KT_INSTALLER_APPLY_RELOAD")
    return true
end
local function ForceSetProfile(addonName, profileName, altAddonName)
    if KT and KT.ForceSetProfile then
        KT:ForceSetProfile(addonName, profileName, altAddonName)
        return
    end

    local addon = LibStub("AceAddon-3.0"):GetAddon(addonName, true)
    if not addon and altAddonName then
        addon = LibStub("AceAddon-3.0"):GetAddon(altAddonName, true)
    end
    if not addon and addonName == "DandersFrames" then
        addon = LibStub("AceAddon-3.0"):GetAddon("DF", true)
    end
    
    -- BCM specific check (Addon object might be named "BCM")
    if not addon and addonName == "BetterCooldownManager" then
        addon = LibStub("AceAddon-3.0"):GetAddon("BCM", true)
    end
    
    -- Fallback: Buscar objeto global si no es AceAddon
    if not addon then
        if _G[addonName] and type(_G[addonName]) == "table" then 
            if _G[addonName].db then addon = _G[addonName] end
        end
        if not addon and altAddonName and _G[altAddonName] and type(_G[altAddonName]) == "table" then 
             if _G[altAddonName].db then addon = _G[altAddonName] end
        end
        if not addon and addonName == "DandersFrames" and _G.DF and type(_G.DF) == "table" and _G.DF.db then
            addon = _G.DF
        end
    end
    
    -- 1. Intentar cambiar en vivo (Objeto Addon)
    if addon and addon.db then
        if addon.db.SetProfile then
            addon.db:SetProfile(profileName)
        else
            -- Si no tiene SetProfile directo, buscar en sub-tablas (común en algunos addons)
            if addon.db.profile and type(addon.db.profile) == "table" and addon.db.keys then
                 -- Intentar forzar cambio interno si es AceDB
                 addon.db:SetProfile(profileName)
            end
        end
        -- Forzar estado interno de AceDB para asegurar guardado
        if addon.db.keys then
            addon.db.keys.profile = profileName
        end
    end

    -- 2. Forzar escritura en la DB Global (Persistencia ante ReloadUI)
    local dbNames = { addonName .. "DB" }
    if altAddonName then table.insert(dbNames, altAddonName .. "DB") end
    
    -- Alias de Bases de Datos conocidas
    if addonName == "UnhaltedUnitFrames" then table.insert(dbNames, "UUFDB") end
    if addonName == "DandersFrames" then table.insert(dbNames, "DandersFramersDB") end
    if addonName == "BetterCooldownManager" then 
        table.insert(dbNames, "BetterCooldownManagerDB")
        table.insert(dbNames, "BCMDB") 
    end
    if addonName == "KullThranUI" then table.insert(dbNames, "KullThranDB") end

    local myName = UnitName("player")
    local myRealm = GetRealmName()
    local exactKey = myName .. " - " .. myRealm
    
    for _, dbName in ipairs(dbNames) do
        local db = _G[dbName]
        
        -- Si la DB no existe (instalación limpia), la creamos para poder pre-configurar
        if not db then
            _G[dbName] = { profileKeys = {} }
            db = _G[dbName]
        end

        if db then
            if not db.profileKeys then db.profileKeys = {} end
            
                -- Método exacto
                db.profileKeys[exactKey] = profileName
                
                -- Método difuso
                for k, v in pairs(db.profileKeys) do
                    if type(k) == "string" and k:find("^" .. myName .. " %-") then
                        db.profileKeys[k] = profileName
                    end
                end
        end
    end
end

function Mod:CheckConflicts()
    local detector = KT:GetModule("AddonConflictDetector", true)
    if detector and detector.Scan and detector.GetActiveConflicts then
        local report = detector:Scan()
        local active = detector:GetActiveConflicts(report)
        if active and #active > 0 then
            return active
        end
        return nil
    end

    local conflicts = {}
    if C_AddOns.IsAddOnLoaded("BetterCooldownManager") then table.insert(conflicts, "BetterCooldownManager") end
    if C_AddOns.IsAddOnLoaded("CenteredCooldownManager") then table.insert(conflicts, "CenteredCooldownManager") end
    if C_AddOns.IsAddOnLoaded("CooldownManagerCentered") then table.insert(conflicts, "CooldownManagerCentered") end
    if C_AddOns.IsAddOnLoaded("ArcUI") then table.insert(conflicts, "ArcUI") end
    if #conflicts > 0 then return conflicts end
    return nil
end

local function RefreshInstallerMinimapShape()
    local minimap = KT:GetModule("Minimap", true)
    if minimap and minimap.Refresh then
        minimap:Refresh()
    end
end

local function GetInstallerClassColor()
    local _, classTag = UnitClass("player")
    local colorTable = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local color = classTag and colorTable and colorTable[classTag]
    if color then
        return color.r, color.g, color.b
    end
    return 1, 1, 1
end

-- The player's own character (race, gear and class stance) in its normal
-- lighting, standing in a soft accent glow that breathes slowly.
-- Returns the model frame, or nil when the client cannot show it.
local CHARACTER_GLOW_PERIOD = 4

local function CreateInstallerCharacter(parent)
    local okFrame, model = pcall(CreateFrame, "PlayerModel", nil, parent)
    if not okFrame or not model then return nil end
    -- Kept below the description text (up to three lines) and above the
    -- footer line (the progress track, 82px up).
    model:SetSize(210, 200)
    model:SetPoint("BOTTOM", parent, "BOTTOM", 0, 92)
    -- Third argument: the character's native form, so a shapeshifted druid still
    -- shows the humanoid; some builds only take the unit, hence the fallback.
    if not pcall(model.SetUnit, model, "player", false, true) and not pcall(model.SetUnit, model, "player") then
        model:Hide()
        return nil
    end
    pcall(model.SetPortraitZoom, model, 0)
    pcall(model.SetFacing, model, math.rad(-18))

    -- Glow behind the model (parent textures draw under the model frame): a
    -- tall halo and a flatter pool at the feet.
    local r, g, b = KT_COLOR[1], KT_COLOR[2], KT_COLOR[3]
    local halo = parent:CreateTexture(nil, "BACKGROUND", nil, 1)
    halo:SetTexture(INSTALLER_TOGGLE_PATH .. "soft_glow.png")
    halo:SetBlendMode("ADD")
    halo:SetSize(250, 250)
    halo:SetPoint("CENTER", model, "CENTER", 0, 4)
    halo:SetVertexColor(r, g, b, 0.55)
    local pool = parent:CreateTexture(nil, "BACKGROUND", nil, 2)
    pool:SetTexture(INSTALLER_TOGGLE_PATH .. "soft_glow.png")
    pool:SetBlendMode("ADD")
    pool:SetSize(220, 46)
    pool:SetPoint("CENTER", model, "BOTTOM", 0, 14)
    pool:SetVertexColor(r, g, b, 0.7)

    local breathe = halo:CreateAnimationGroup()
    breathe:SetLooping("BOUNCE")
    local fade = breathe:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.65)
    fade:SetDuration(CHARACTER_GLOW_PERIOD / 2)
    fade:SetSmoothing("IN_OUT")
    breathe:Play()
    return model
end

-- Flat class crest for the welcome page. Returns true when a class image was applied.
local function ApplyInstallerClassShape(texture)
    local _, classTag = UnitClass("player")
    if not classTag then return false end
    local atlas = "classicon-" .. classTag:lower()
    local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    local applied = false
    if info and texture.SetAtlas then
        texture:SetAtlas(atlas)
        applied = true
    else
        local coords = _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[classTag]
        if coords then
            texture:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            applied = true
        end
    end
    if not applied then return false end
    texture:SetSize(300, 300)
    if texture.SetDesaturated then texture:SetDesaturated(true) end
    local r, g, b = GetInstallerClassColor()
    texture:SetVertexColor(r, g, b, 0.28)
    return true
end

local function GetInstallerCursorModule()
    local cursor = KT:GetModule("Cursor", true)
    if cursor then
        return cursor
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "KullThranUI_Cursor")
        cursor = KT:GetModule("Cursor", true)
    end

    return cursor
end

local function GetInstallerCursorDB()
    local cursor = GetInstallerCursorModule()
    if cursor and cursor.GetDB then
        return cursor:GetDB(), cursor
    end

    KT.db.profile.cursor = KT.db.profile.cursor or {}
    local db = KT.db.profile.cursor
    db.enable = db.enable ~= false
    db.scale = db.scale or 0.8
    db.transparency = db.transparency or 1
    db.reticle = db.reticle or "Dot"
    db.reticleScale = db.reticleScale or 1.5
    db.innerRing = db.innerRing or "GCD"
    db.mainRing = db.mainRing or "Main Ring"
    db.outerRing = db.outerRing or "Cast"
    db.reticleColorMode = db.reticleColorMode or "class"
    db.mainRingColorMode = db.mainRingColorMode or "class"
    db.gcdColorMode = db.gcdColorMode or "class"
    db.castColorMode = db.castColorMode or "class"
    db.trailColorMode = db.trailColorMode or "class"
    db.enableTrail = db.enableTrail == true
    if db.enableClickAnimation == nil then db.enableClickAnimation = true end
    db.clickScale = db.clickScale or 1
    db.reticleCustomColor = db.reticleCustomColor or { r = 1, g = 1, b = 1 }
    db.mainRingCustomColor = db.mainRingCustomColor or { r = 1, g = 1, b = 1 }
    db.gcdCustomColor = db.gcdCustomColor or { r = 1, g = 1, b = 1 }
    db.castCustomColor = db.castCustomColor or { r = 1, g = 1, b = 1 }
    db.trailCustomColor = db.trailCustomColor or { r = 1, g = 1, b = 1 }
    return db, cursor
end

local function ApplyInstallerCursorSettings()
    local cursor = GetInstallerCursorModule()
    if cursor and cursor.ApplyToAddon then
        pcall(cursor.ApplyToAddon, cursor)
    end
end

local function GetInstallerEnhancementsModule()
    local enhancements = KT:GetModule("Enhancements", true)
    if enhancements then
        return enhancements
    end

    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "KullThranUI_Enhancements")
        enhancements = KT:GetModule("Enhancements", true)
    end

    return enhancements
end

local function GetInstallerEnhancementsDB()
    local enhancements = GetInstallerEnhancementsModule()
    if enhancements and enhancements.GetDB then
        return enhancements:GetDB(), enhancements
    end

    KT.db.profile.enhancements = KT.db.profile.enhancements or {}
    KT.db.profile.enhancements.social = KT.db.profile.enhancements.social or {}
    local social = KT.db.profile.enhancements.social
    if social.enhancedFriendList == nil then
        social.enhancedFriendList = true
    end
    return KT.db.profile.enhancements, enhancements
end

local function ApplyInstallerEnhancedFriendListSettings()
    local enhancements = GetInstallerEnhancementsModule()
    if not enhancements then
        return
    end

    local friendList = enhancements.EnhancedFriendList
    if friendList and friendList.Refresh then
        pcall(friendList.Refresh, friendList, true)
    end
end

local function GetInstallerPreviewFont()
    if KT and KT.ResolveFontPath then
        return KT:ResolveFontPath()
    end
    return GetKTFont()
end

local function GetInstallerStylePalette()
    return (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or {}
end

local function GetInstallerPreviewAccentRGB(accentOverride)
    if type(accentOverride) == "table" then
        return accentOverride[1] or 1, accentOverride[2] or 0.35, accentOverride[3] or 0.35
    end

    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin or nil
    if skin and skin.friendListColorMode == "custom" and skin.friendListColor then
        local c = skin.friendListColor
        return c.r or 1, c.g or 0.35, c.b or 0.35
    end
    if KT and KT.GetStyleAccentRGB then
        local r, g, b = KT:GetStyleAccentRGB()
        return r, g, b
    end
    local accent = GetInstallerStylePalette().accent or {}
    return accent.r or KT.C_R or 1, accent.g or KT.C_G or 0.35, accent.b or KT.C_B or 0.35
end

local function GetInstallerPreviewTextRGB()
    local text = GetInstallerStylePalette().text or {}
    return text.r or 0.98, text.g or 0.94, text.b or 0.96
end

local function GetInstallerPreviewMutedRGB()
    local muted = GetInstallerStylePalette().muted or {}
    return muted.r or 0.74, muted.g or 0.74, muted.b or 0.78
end

local function InstallerApplyTextureGradient(texture, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    if not texture then
        return
    end
    if texture.SetGradientAlpha then
        texture:SetGradientAlpha(orientation, r1, g1, b1, a1, r2, g2, b2, a2)
        return
    end
    if texture.SetGradient and CreateColor then
        texture:SetGradient(orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    end
end

local function InstallerEnsureOutline(frame)
    if not frame then
        return nil
    end
    if frame._ktEFLPreviewOutline then
        return frame._ktEFLPreviewOutline
    end

    local outline = {}
    outline.top = frame:CreateTexture(nil, "BORDER")
    outline.top:SetPoint("TOPLEFT")
    outline.top:SetPoint("TOPRIGHT")
    outline.top:SetHeight(1)

    outline.bottom = frame:CreateTexture(nil, "BORDER")
    outline.bottom:SetPoint("BOTTOMLEFT")
    outline.bottom:SetPoint("BOTTOMRIGHT")
    outline.bottom:SetHeight(1)

    outline.left = frame:CreateTexture(nil, "BORDER")
    outline.left:SetPoint("TOPLEFT")
    outline.left:SetPoint("BOTTOMLEFT")
    outline.left:SetWidth(1)

    outline.right = frame:CreateTexture(nil, "BORDER")
    outline.right:SetPoint("TOPRIGHT")
    outline.right:SetPoint("BOTTOMRIGHT")
    outline.right:SetWidth(1)

    frame._ktEFLPreviewOutline = outline
    return outline
end

local function InstallerSetOutlineColor(frame, r, g, b, a)
    local outline = InstallerEnsureOutline(frame)
    if not outline then
        return
    end

    outline.top:SetColorTexture(r, g, b, a)
    outline.bottom:SetColorTexture(r, g, b, a)
    outline.left:SetColorTexture(r, g, b, a)
    outline.right:SetColorTexture(r, g, b, a)
end

local function InstallerEnsureSurface(frame)
    if not frame then
        return nil
    end
    if frame._ktEFLPreviewSurface then
        return frame._ktEFLPreviewSurface
    end

    local surface = {}
    surface.base = frame:CreateTexture(nil, "BACKGROUND")
    surface.base:SetDrawLayer("BACKGROUND", 0)
    surface.base:SetAllPoints()

    surface.pattern = frame:CreateTexture(nil, "BACKGROUND")
    surface.pattern:SetDrawLayer("BACKGROUND", 1)
    surface.pattern:SetAllPoints()
    surface.pattern:SetTexture(EFL_BUTTON_TEXTURE)
    surface.pattern:SetTexCoord(0, 1, 0, 1)

    surface.shade = frame:CreateTexture(nil, "BACKGROUND")
    surface.shade:SetDrawLayer("BACKGROUND", 2)
    surface.shade:SetAllPoints()

    surface.gloss = frame:CreateTexture(nil, "ARTWORK")
    surface.gloss:SetDrawLayer("ARTWORK", 0)
    surface.gloss:SetTexture(EFL_GLOSS_TEXTURE)
    surface.gloss:SetPoint("TOPLEFT", 1, -1)
    surface.gloss:SetPoint("TOPRIGHT", -1, -1)
    surface.gloss:SetHeight(22)

    surface.topLine = frame:CreateTexture(nil, "ARTWORK")
    surface.topLine:SetDrawLayer("ARTWORK", 1)
    surface.topLine:SetPoint("TOPLEFT", 1, -1)
    surface.topLine:SetPoint("TOPRIGHT", -1, -1)
    surface.topLine:SetHeight(1)

    surface.bottomShade = frame:CreateTexture(nil, "ARTWORK")
    surface.bottomShade:SetDrawLayer("ARTWORK", 1)
    surface.bottomShade:SetPoint("BOTTOMLEFT", 1, 1)
    surface.bottomShade:SetPoint("BOTTOMRIGHT", -1, 1)
    surface.bottomShade:SetHeight(1)

    surface.accentGradH = frame:CreateTexture(nil, "BACKGROUND")
    surface.accentGradH:SetDrawLayer("BACKGROUND", 3)
    surface.accentGradH:SetPoint("TOPLEFT", 1, -1)
    surface.accentGradH:SetPoint("BOTTOMLEFT", 1, 1)
    surface.accentGradH:SetTexture(EFL_WHITE8X8)

    surface.accentGradV = frame:CreateTexture(nil, "BACKGROUND")
    surface.accentGradV:SetDrawLayer("BACKGROUND", 4)
    surface.accentGradV:SetPoint("TOPLEFT", 1, -1)
    surface.accentGradV:SetPoint("TOPRIGHT", -1, -1)
    surface.accentGradV:SetTexture(EFL_WHITE8X8)

    surface.accentBottomLine = frame:CreateTexture(nil, "ARTWORK")
    surface.accentBottomLine:SetDrawLayer("ARTWORK", 2)
    surface.accentBottomLine:SetPoint("BOTTOMLEFT", 1, 1)
    surface.accentBottomLine:SetPoint("BOTTOMRIGHT", -1, 1)
    surface.accentBottomLine:SetHeight(1)
    surface.accentBottomLine:SetTexture(EFL_WHITE8X8)

    frame._ktEFLPreviewSurface = surface
    return surface
end

local function InstallerApplyPreviewSurface(frame, accentColor, texturePath, baseR, baseG, baseB, baseA, patternA, lineA, borderA, gradH, gradV, botLineA)
    local surface = InstallerEnsureSurface(frame)
    if not surface then
        return
    end

    local accentR, accentG, accentB = GetInstallerPreviewAccentRGB(accentColor)
    surface.pattern:SetTexture(texturePath or EFL_BUTTON_TEXTURE)
    if texturePath == EFL_FRAME_BACKGROUND_TEXTURE then
        surface.pattern:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        surface.pattern:SetTexCoord(0, 1, 0, 1)
    end
    surface.base:SetColorTexture(baseR, baseG, baseB, baseA)
    surface.pattern:SetVertexColor(1, 1, 1, patternA or 0)
    surface.shade:SetColorTexture(0, 0, 0, 0.16)
    surface.gloss:SetVertexColor(1, 1, 1, 0.08)
    surface.topLine:SetColorTexture(accentR, accentG, accentB, lineA or 0.08)
    surface.bottomShade:SetColorTexture(1, 1, 1, 0.03)
    InstallerSetOutlineColor(frame, 0.18, 0.18, 0.23, borderA or 0.85)

    local hAlpha = gradH or 0
    if hAlpha > 0 then
        surface.accentGradH:SetWidth(math.max(1, ((frame:GetWidth() or 0) > 0 and frame:GetWidth() or 300) * 0.6))
        InstallerApplyTextureGradient(surface.accentGradH, "HORIZONTAL", accentR, accentG, accentB, hAlpha, accentR, accentG, accentB, 0)
        surface.accentGradH:Show()
    else
        surface.accentGradH:Hide()
    end

    local vAlpha = gradV or 0
    if vAlpha > 0 then
        surface.accentGradV:SetHeight(math.max(1, ((frame:GetHeight() or 0) > 0 and frame:GetHeight() or 100) * 0.45))
        InstallerApplyTextureGradient(surface.accentGradV, "VERTICAL", accentR, accentG, accentB, 0, accentR, accentG, accentB, vAlpha)
        surface.accentGradV:Show()
    else
        surface.accentGradV:Hide()
    end

    local bottomAlpha = botLineA or 0
    if bottomAlpha > 0 then
        InstallerApplyTextureGradient(surface.accentBottomLine, "HORIZONTAL", accentR, accentG, accentB, 0, accentR, accentG, accentB, bottomAlpha)
        surface.accentBottomLine:Show()
    else
        surface.accentBottomLine:Hide()
    end
end

local function InstallerApplyPreviewShellStyle(frame, accentColor, bgAlpha)
    InstallerApplyPreviewSurface(frame, accentColor, EFL_FRAME_BACKGROUND_TEXTURE, 0.018, 0.018, 0.024, bgAlpha or 0.985, 0.16, 0.18, 0.95, 0.06, 0.08, 0.12)
end

local function InstallerApplyPreviewSectionStyle(frame, accentColor, bgAlpha, borderAlpha)
    InstallerApplyPreviewSurface(frame, accentColor, EFL_BUTTON_TEXTURE, 0.055, 0.055, 0.07, bgAlpha or 0.96, 0.20, 0.14, borderAlpha or 0.88, 0.10, 0.07, 0.08)
end

local function InstallerApplyPreviewInsetStyle(frame, accentColor, bgAlpha)
    InstallerApplyPreviewSurface(frame, accentColor, EFL_BUTTON_TEXTURE, 0.038, 0.038, 0.048, bgAlpha or 0.98, 0.16, 0.08, 0.9, 0.07, 0, 0)
end

local function InstallerCreatePreviewLabel(parent, size, r, g, b, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(GetInstallerPreviewFont(), size, flags or "")
    fs:SetTextColor(r, g, b, 1)
    fs:SetWordWrap(false)
    fs:SetJustifyH("LEFT")
    return fs
end

local function CreateEnhancedFriendListPreviewCard(parent, accentColor, titleText)
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(206, 292)
    InstallerApplyPreviewShellStyle(card, accentColor, 0.985)

    local textR, textG, textB = GetInstallerPreviewTextRGB()
    local mutedR, mutedG, mutedB = GetInstallerPreviewMutedRGB()
    local accentR, accentG, accentB = GetInstallerPreviewAccentRGB(accentColor)

    local mainPanel = CreateFrame("Frame", nil, card)
    mainPanel:SetPoint("TOPLEFT", 4, -4)
    mainPanel:SetPoint("BOTTOMRIGHT", -4, 4)
    InstallerApplyPreviewShellStyle(mainPanel, accentColor, 0.965)

    local header = CreateFrame("Frame", nil, mainPanel)
    header:SetPoint("TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", -4, -4)
    header:SetHeight(34)
    InstallerApplyPreviewSectionStyle(header, accentColor, 0.98, 0.9)

    local headerIconBox = CreateFrame("Frame", nil, header)
    headerIconBox:SetSize(28, 22)
    headerIconBox:SetPoint("LEFT", 6, 0)
    InstallerApplyPreviewInsetStyle(headerIconBox, accentColor, 1)

    local headerIcon = headerIconBox:CreateTexture(nil, "ARTWORK")
    headerIcon:SetPoint("CENTER")
    headerIcon:SetSize(20, 13)
    headerIcon:SetTexture(EFL_HEADER_ICON)
    headerIcon:SetVertexColor(accentR, accentG, accentB, 1)

    local headerTitle = InstallerCreatePreviewLabel(header, 10, textR, textG, textB, "OUTLINE")
    headerTitle:SetPoint("LEFT", headerIconBox, "RIGHT", 6, 0)
    headerTitle:SetText(L["Contacts"])

    local badge = InstallerCreatePreviewLabel(header, 8, mutedR, mutedG, mutedB, "OUTLINE")
    badge:SetPoint("RIGHT", -8, 0)
    badge:SetText(titleText or "")

    local navBar = CreateFrame("Frame", nil, mainPanel)
    navBar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
    navBar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
    navBar:SetHeight(24)
    InstallerApplyPreviewSectionStyle(navBar, accentColor, 0.98, 0.9)

    local navSelected = CreateFrame("Frame", nil, navBar)
    navSelected:SetPoint("TOPLEFT", 4, -4)
    navSelected:SetSize(76, 16)
    InstallerApplyPreviewSectionStyle(navSelected, accentColor, 0.98, 0.92)
    local navSelectedText = InstallerCreatePreviewLabel(navSelected, 8, textR, textG, textB, "OUTLINE")
    navSelectedText:SetPoint("CENTER")
    navSelectedText:SetText(L["Contacts"])

    local navIdleText = InstallerCreatePreviewLabel(navBar, 8, mutedR, mutedG, mutedB, "OUTLINE")
    navIdleText:SetPoint("LEFT", navSelected, "RIGHT", 12, 0)
    navIdleText:SetText(L["Quick Join"])

    local topPanel = CreateFrame("Frame", nil, mainPanel)
    topPanel:SetPoint("TOPLEFT", navBar, "BOTTOMLEFT", 0, -4)
    topPanel:SetPoint("TOPRIGHT", navBar, "BOTTOMRIGHT", 0, -4)
    topPanel:SetHeight(26)

    local recentPanel = CreateFrame("Frame", nil, topPanel)
    recentPanel:SetPoint("TOPLEFT", 0, 0)
    recentPanel:SetPoint("BOTTOMLEFT", 0, 0)
    recentPanel:SetPoint("RIGHT", topPanel, "CENTER", -2, 0)
    InstallerApplyPreviewSectionStyle(recentPanel, accentColor, 0.98, 0.9)
    local recentTitle = InstallerCreatePreviewLabel(recentPanel, 8, textR, textG, textB)
    recentTitle:SetPoint("LEFT", 6, 0)
    recentTitle:SetText(L["Recent Allies"])

    local recruitPanel = CreateFrame("Frame", nil, topPanel)
    recruitPanel:SetPoint("TOPRIGHT", 0, 0)
    recruitPanel:SetPoint("BOTTOMRIGHT", 0, 0)
    recruitPanel:SetPoint("LEFT", topPanel, "CENTER", 2, 0)
    InstallerApplyPreviewSectionStyle(recruitPanel, accentColor, 0.98, 0.9)
    local recruitTitle = InstallerCreatePreviewLabel(recruitPanel, 8, textR, textG, textB)
    recruitTitle:SetPoint("LEFT", 6, 0)
    recruitTitle:SetText(L["Recruit Friend"])

    local listInset = CreateFrame("Frame", nil, mainPanel)
    listInset:SetPoint("TOPLEFT", topPanel, "BOTTOMLEFT", 0, -5)
    listInset:SetPoint("BOTTOMRIGHT", mainPanel, "BOTTOMRIGHT", -4, 28)
    InstallerApplyPreviewInsetStyle(listInset, accentColor, 0.98)

    local groupHeader = CreateFrame("Frame", nil, listInset)
    groupHeader:SetPoint("TOPLEFT", 4, -4)
    groupHeader:SetPoint("TOPRIGHT", -4, -4)
    groupHeader:SetHeight(18)
    InstallerApplyPreviewInsetStyle(groupHeader, accentColor, 0.96)
    local groupAccent = groupHeader:CreateTexture(nil, "ARTWORK")
    groupAccent:SetPoint("LEFT", 4, 0)
    groupAccent:SetSize(2, 8)
    groupAccent:SetColorTexture(accentR, accentG, accentB, 0.85)
    local groupTitle = InstallerCreatePreviewLabel(groupHeader, 8, textR, textG, textB, "OUTLINE")
    groupTitle:SetPoint("LEFT", 10, 0)
    groupTitle:SetText(LText("Raiders"))

    local function CreatePreviewRow(anchor, offsetY, nameText, subtitleText, detailText, onlineColor)
        local row = CreateFrame("Frame", nil, listInset)
        row:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
        row:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, offsetY)
        row:SetHeight(44)
        InstallerApplyPreviewSectionStyle(row, accentColor, 0.98, 0.9)

        local accentEdge = row:CreateTexture(nil, "BACKGROUND")
        accentEdge:SetPoint("TOPLEFT", 1, -1)
        accentEdge:SetPoint("BOTTOMLEFT", 1, 1)
        accentEdge:SetWidth(2)
        accentEdge:SetColorTexture(accentR, accentG, accentB, 0.9)

        local accentGlow = row:CreateTexture(nil, "BACKGROUND")
        accentGlow:SetPoint("TOPLEFT", accentEdge, "TOPRIGHT", 0, 0)
        accentGlow:SetPoint("BOTTOMLEFT", accentEdge, "BOTTOMRIGHT", 0, 0)
        accentGlow:SetWidth(48)
        InstallerApplyTextureGradient(accentGlow, "HORIZONTAL", accentR, accentG, accentB, 0.12, accentR, accentG, accentB, 0)
        accentGlow:SetTexture(EFL_WHITE8X8)

        local iconBox = CreateFrame("Frame", nil, row)
        iconBox:SetSize(30, 30)
        iconBox:SetPoint("LEFT", 7, 0)
        InstallerApplyPreviewInsetStyle(iconBox, accentColor, 1)

        local icon = iconBox:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("CENTER")
        icon:SetSize(24, 24)
        icon:SetTexture(EFL_FRIEND_ICON)

        local status = row:CreateTexture(nil, "ARTWORK")
        status:SetSize(5, 5)
        status:SetPoint("LEFT", iconBox, "RIGHT", 6, 0)
        status:SetColorTexture(onlineColor[1], onlineColor[2], onlineColor[3], 1)

        local name = InstallerCreatePreviewLabel(row, 9, textR, textG, textB, "OUTLINE")
        name:SetPoint("TOPLEFT", status, "TOPRIGHT", 6, 8)
        name:SetText(nameText)

        local subtitle = InstallerCreatePreviewLabel(row, 8, mutedR, mutedG, mutedB)
        subtitle:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
        subtitle:SetText(subtitleText)

        local detail = InstallerCreatePreviewLabel(row, 8, accentR, accentG, accentB)
        detail:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -1)
        detail:SetText(detailText)

        return row
    end

    local row1 = CreatePreviewRow(groupHeader, -5, "Futnorris", "Futurized Sanguino 90", "The Dreamrift", { 0.28, 0.77, 0.51 })
    CreatePreviewRow(row1, -4, "Qute", "Battle.net Sanguino 90", "Skyreach", { 0.86, 0.32, 0.32 })

    local footer = CreateFrame("Frame", nil, mainPanel)
    footer:SetPoint("BOTTOMLEFT", 4, 4)
    footer:SetPoint("BOTTOMRIGHT", -4, 4)
    footer:SetHeight(20)
    InstallerApplyPreviewSectionStyle(footer, accentColor, 0.97, 0.9)

    local footerText = InstallerCreatePreviewLabel(footer, 8, textR, textG, textB, "OUTLINE")
    footerText:SetPoint("CENTER")
    footerText:SetText(L["Send Message"])

    local caption = InstallerCreatePreviewLabel(parent, 10, accentR, accentG, accentB, "OUTLINE")
    caption:SetPoint("TOP", card, "BOTTOM", 0, -8)
    caption:SetText(titleText or "")
    card.caption = caption

    local disabledOverlay = CreateFrame("Frame", nil, card)
    disabledOverlay:SetAllPoints()
    InstallerApplyPreviewSectionStyle(disabledOverlay, accentColor, 0.96, 0.9)
    disabledOverlay:SetFrameLevel(card:GetFrameLevel() + 20)
    disabledOverlay.label = InstallerCreatePreviewLabel(disabledOverlay, 12, textR, textG, textB, "OUTLINE")
    disabledOverlay.label:SetPoint("CENTER")
    disabledOverlay.label:SetText(L["Disabled"])
    disabledOverlay:Hide()
    card.disabledOverlay = disabledOverlay

    return card
end

local function CreateInstallerPreviewIcon(parent, size, texture, text)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(size, size)
    CreateBackdrop(frame)
    frame:SetBackdropColor(0.015, 0.015, 0.02, 0.98)
    frame:SetBackdropBorderColor(0.28, 0.28, 0.32, 1)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", -2, 2)
    icon:SetTexture(texture)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    frame.Icon = icon

    if text then
        local label = InstallerCreatePreviewLabel(frame, math.max(8, math.floor(size * 0.28)), 1, 1, 1, "OUTLINE")
        label:SetPoint("BOTTOMRIGHT", -3, 3)
        label:SetText(text)
    end
    return frame
end

local function CreateBagsInstallerPreview(parent)
    local accentR, accentG, accentB = GetInstallerPreviewAccentRGB()
    local textR, textG, textB = GetInstallerPreviewTextRGB()
    local mutedR, mutedG, mutedB = GetInstallerPreviewMutedRGB()

    local root = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    root:SetPoint("TOPLEFT", 8, -8)
    root:SetPoint("BOTTOMRIGHT", -8, 8)
    CreateBackdrop(root)
    root:SetBackdropColor(0.01, 0.01, 0.015, 0.98)
    root:SetBackdropBorderColor(accentR, accentG, accentB, 0.78)

    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(INSTALLER_BAGS_BACKGROUND)
    bg:SetAlpha(0.32)

    local header = CreateFrame("Frame", nil, root, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 5, -5)
    header:SetPoint("TOPRIGHT", -5, -5)
    header:SetHeight(26)
    InstallerApplyPreviewSectionStyle(header, nil, 0.96, 0.72)
    local title = InstallerCreatePreviewLabel(header, 11, textR, textG, textB, "OUTLINE")
    title:SetPoint("CENTER")
    title:SetText(L["Bags"])

    local search = CreateFrame("Frame", nil, root, "BackdropTemplate")
    search:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)
    search:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -5)
    search:SetHeight(24)
    CreateBackdrop(search)
    search:SetBackdropColor(0.01, 0.01, 0.015, 0.96)
    search:SetBackdropBorderColor(accentR, accentG, accentB, 0.72)
    local searchIcon = search:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", 8, 0)
    searchIcon:SetTexture(KUI_ICON_PATH .. "chaticons\\Search.png")
    searchIcon:SetVertexColor(accentR, accentG, accentB, 1)
    local searchText = InstallerCreatePreviewLabel(search, 9, mutedR, mutedG, mutedB)
    searchText:SetPoint("LEFT", searchIcon, "RIGHT", 6, 0)
    searchText:SetText(L["Search"] .. "...")

    local categories = CreateFrame("Frame", nil, root, "BackdropTemplate")
    categories:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -5)
    categories:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 5, 5)
    categories:SetWidth(154)
    InstallerApplyPreviewInsetStyle(categories, nil, 0.98)
    local categoryTitle = InstallerCreatePreviewLabel(categories, 9, mutedR, mutedG, mutedB, "OUTLINE")
    categoryTitle:SetPoint("TOPLEFT", 8, -7)
    categoryTitle:SetText(L["Categories"])

    local categoryRows = {
        { L["All Items"], 133633, "182" },
        { L["Consumable"], 134829, "33" },
        { L["Quest"], 134400, "2" },
        { L["Weapon"], 135274, "7" },
        { L["Armor"], 132738, "61" },
    }
    local previous
    for index, data in ipairs(categoryRows) do
        local row = CreateFrame("Frame", nil, categories, "BackdropTemplate")
        row:SetPoint("LEFT", 5, 0)
        row:SetPoint("RIGHT", -5, 0)
        row:SetHeight(31)
        if previous then
            row:SetPoint("TOP", previous, "BOTTOM", 0, -2)
        else
            row:SetPoint("TOP", categoryTitle, "BOTTOM", 0, -7)
        end
        if index == 1 then
            CreateBackdrop(row)
            row:SetBackdropColor(accentR * 0.2, accentG * 0.2, accentB * 0.2, 0.92)
            row:SetBackdropBorderColor(accentR, accentG, accentB, 0.8)
        end
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", 4, 0)
        icon:SetTexture(data[2])
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local label = InstallerCreatePreviewLabel(row, 9, textR, textG, textB)
        label:SetPoint("LEFT", icon, "RIGHT", 7, 0)
        label:SetText(data[1])
        local count = InstallerCreatePreviewLabel(row, 8, mutedR, mutedG, mutedB)
        count:SetPoint("RIGHT", -6, 0)
        count:SetText(data[3])
        previous = row
    end

    local inventory = CreateFrame("Frame", nil, root)
    inventory:SetPoint("TOPLEFT", categories, "TOPRIGHT", 8, 0)
    inventory:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -8, 8)
    local inventoryTitle = InstallerCreatePreviewLabel(inventory, 12, textR, textG, textB, "OUTLINE")
    inventoryTitle:SetPoint("TOPLEFT", 0, -3)
    inventoryTitle:SetText(L["Backpack Categories"])
    local section = InstallerCreatePreviewLabel(inventory, 10, textR, textG, textB, "OUTLINE")
    section:SetPoint("TOPLEFT", inventoryTitle, "BOTTOMLEFT", 0, -10)
    section:SetText(L["Consumable"])
    local line = inventory:CreateTexture(nil, "ARTWORK")
    line:SetPoint("LEFT", section, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", -4, 0)
    line:SetHeight(1)
    line:SetColorTexture(accentR, accentG, accentB, 0.48)

    local itemTextures = { 134829, 134712, 134773, 135920, 133685, 134532, 132794, 134756, 134830, 134781, 133733, 134027, 133858, 134437, 134765, 134743, 132806, 135863 }
    for index, texture in ipairs(itemTextures) do
        local icon = CreateInstallerPreviewIcon(inventory, 34, texture, index % 3 == 0 and tostring(index * 3) or nil)
        local column = (index - 1) % 9
        local row = math.floor((index - 1) / 9)
        icon:SetPoint("TOPLEFT", inventory, "TOPLEFT", column * 38, -58 - row * 38)
    end
    local equipment = InstallerCreatePreviewLabel(inventory, 10, textR, textG, textB, "OUTLINE")
    equipment:SetPoint("TOPLEFT", inventory, "TOPLEFT", 0, -144)
    equipment:SetText(L["Equipment"])
    local equipLine = inventory:CreateTexture(nil, "ARTWORK")
    equipLine:SetPoint("LEFT", equipment, "RIGHT", 8, 0)
    equipLine:SetPoint("RIGHT", -4, 0)
    equipLine:SetHeight(1)
    equipLine:SetColorTexture(accentR, accentG, accentB, 0.48)
    for index, texture in ipairs({ 135274, 132738, 132626, 133122, 132605, 132545 }) do
        local icon = CreateInstallerPreviewIcon(inventory, 34, texture)
        icon:SetPoint("TOPLEFT", inventory, "TOPLEFT", (index - 1) * 38, -164)
    end
    return root
end

local function CollectInstallerBagPreviewItems()
    local groups = {
        consumable = {},
        equipment = {},
        other = {},
    }
    local total = 0
    local containerAPI = _G.C_Container
    local maxBagID = _G.NUM_BAG_SLOTS or 4

    if containerAPI and containerAPI.GetContainerNumSlots and containerAPI.GetContainerItemInfo then
        for bagID = 0, maxBagID do
            local slotCount = containerAPI.GetContainerNumSlots(bagID) or 0
            for slotID = 1, slotCount do
                local info = containerAPI.GetContainerItemInfo(bagID, slotID)
                if info and info.iconFileID then
                    local category = "other"
                    local classID
                    local equipLoc
                    if info.itemID and _G.GetItemInfoInstant then
                        local _, _, _, resolvedEquipLoc, _, resolvedClassID = _G.GetItemInfoInstant(info.itemID)
                        equipLoc = resolvedEquipLoc
                        classID = resolvedClassID
                    end
                    if (equipLoc and equipLoc ~= "") or classID == 2 or classID == 4 then
                        category = "equipment"
                    elseif classID == 0 then
                        category = "consumable"
                    end

                    groups[category][#groups[category] + 1] = {
                        texture = info.iconFileID,
                        count = info.stackCount or 1,
                        quality = info.quality,
                    }
                    total = total + 1
                    if total >= 30 then
                        break
                    end
                end
            end
            if total >= 30 then
                break
            end
        end
    end

    local fallbackItems = {
        consumable = {
            { texture = 134829, count = 12, quality = 1 },
            { texture = 134712, count = 5, quality = 2 },
            { texture = 134773, count = 20, quality = 1 },
            { texture = 133685, count = 8, quality = 1 },
            { texture = 135920, count = 3, quality = 2 },
        },
        equipment = {
            { texture = 135274, count = 1, quality = 4 },
            { texture = 132738, count = 1, quality = 3 },
            { texture = 132626, count = 1, quality = 4 },
            { texture = 133122, count = 1, quality = 3 },
            { texture = 132605, count = 1, quality = 3 },
        },
        other = {
            { texture = 134532, count = 1, quality = 1 },
            { texture = 132794, count = 7, quality = 2 },
            { texture = 134756, count = 4, quality = 3 },
            { texture = 133858, count = 16, quality = 1 },
            { texture = 134781, count = 1, quality = 1 },
        },
    }

    for _, category in ipairs({ "consumable", "equipment", "other" }) do
        local target = groups[category]
        local fallback = fallbackItems[category]
        local fallbackIndex = 1
        while #target < 5 do
            target[#target + 1] = fallback[fallbackIndex]
            fallbackIndex = (fallbackIndex % #fallback) + 1
        end
    end

    return groups
end

local function SetInstallerPreviewQualityBorder(frame, quality)
    local qualityColor = quality and _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[quality]
    if qualityColor then
        frame:SetBackdropBorderColor(qualityColor.r or 0.3, qualityColor.g or 0.3, qualityColor.b or 0.34, 0.95)
    end
end

local function CreateBagsInstallerFallbackPreview(parent)
    local accentR, accentG, accentB = GetInstallerPreviewAccentRGB()
    local textR, textG, textB = GetInstallerPreviewTextRGB()
    local mutedR, mutedG, mutedB = GetInstallerPreviewMutedRGB()
    local groups = CollectInstallerBagPreviewItems()
    -- Text is designed at the real window size, then the whole preview is scaled.
    local function PreviewLabel(labelParent, size, ...)
        return InstallerCreatePreviewLabel(labelParent, size * 1.45, ...)
    end

    local root = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    root:SetSize(780, 540)
    root:SetPoint("CENTER")
    root:SetScale(math.min(((parent:GetWidth() or 700) - 16) / 780, ((parent:GetHeight() or 320) - 16) / 540))
    CreateBackdrop(root)
    root:SetBackdropColor(0.05, 0.07, 0.09, 0.97)
    root:SetBackdropBorderColor(0.10, 0.10, 0.10, 1)

    local bg = root:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(INSTALLER_BAGS_BACKGROUND)
    bg:SetAlpha(0.18)

    local header = CreateFrame("Frame", nil, root, "BackdropTemplate")
    header:SetPoint("TOPLEFT", 6, -6)
    header:SetPoint("TOPRIGHT", -6, -6)
    header:SetHeight(36)
    InstallerApplyPreviewSectionStyle(header, nil, 0.97, 0.74)

    local bagIcon = header:CreateTexture(nil, "ARTWORK")
    bagIcon:SetSize(17, 17)
    bagIcon:SetPoint("LEFT", 7, 0)
    bagIcon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    bagIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    bagIcon:SetVertexColor(accentR, accentG, accentB, 1)

    local title = PreviewLabel(header, 11, textR, textG, textB, "OUTLINE")
    title:SetPoint("CENTER")
    title:SetText(L["Bags"])

    local function CreateHeaderButton(anchor, width, labelText, isClose)
        local button = CreateFrame("Frame", nil, header, "BackdropTemplate")
        button:SetSize(width, 21)
        button:SetPoint("RIGHT", anchor, "LEFT", -5, 0)
        CreateBackdrop(button)
        button:SetBackdropColor(isClose and 0.10 or 0.07, isClose and 0.035 or 0.07, isClose and 0.035 or 0.085, 0.96)
        button:SetBackdropBorderColor(isClose and 0.55 or 0.20, isClose and 0.12 or 0.20, isClose and 0.12 or 0.24, 0.9)
        local label = PreviewLabel(button, 8, textR, textG, textB, "OUTLINE")
        label:SetPoint("CENTER")
        label:SetText(labelText)
        return button
    end

    local closeButton = CreateFrame("Frame", nil, header, "BackdropTemplate")
    closeButton:SetSize(24, 21)
    closeButton:SetPoint("RIGHT", -5, 0)
    CreateBackdrop(closeButton)
    closeButton:SetBackdropColor(0.10, 0.035, 0.035, 0.96)
    closeButton:SetBackdropBorderColor(0.55, 0.12, 0.12, 0.9)
    local closeText = PreviewLabel(closeButton, 9, 1, 0.82, 0.82, "OUTLINE")
    closeText:SetPoint("CENTER")
    closeText:SetText("X")

    local sectionsButton = CreateHeaderButton(closeButton, 58, LText("Sections"))
    CreateHeaderButton(sectionsButton, 58, LText("Options"))

    local toolbar = CreateFrame("Frame", nil, root, "BackdropTemplate")
    toolbar:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -5)
    toolbar:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -5)
    toolbar:SetHeight(43)
    InstallerApplyPreviewSectionStyle(toolbar, nil, 0.96, 0.62)

    local search = CreateFrame("Frame", nil, toolbar, "BackdropTemplate")
    search:SetPoint("LEFT", 7, 0)
    search:SetPoint("RIGHT", toolbar, "RIGHT", -174, 0)
    search:SetHeight(31)
    CreateBackdrop(search)
    search:SetBackdropColor(0.01, 0.01, 0.02, 0.94)
    search:SetBackdropBorderColor(accentR, accentG, accentB, 0.64)
    local searchIcon = search:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(18, 18)
    searchIcon:SetPoint("LEFT", 8, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetVertexColor(accentR, accentG, accentB, 0.9)
    local searchText = PreviewLabel(search, 9, mutedR, mutedG, mutedB)
    searchText:SetPoint("LEFT", searchIcon, "RIGHT", 7, 0)
    searchText:SetText((LText("Search")) .. "...")

    local watch = CreateFrame("Frame", nil, toolbar, "BackdropTemplate")
    watch:SetSize(48, 27)
    watch:SetPoint("RIGHT", -116, 0)
    InstallerApplyPreviewSectionStyle(watch, nil, 0.95, 0.54)
    local watchText = PreviewLabel(watch, 8, textR, textG, textB, "OUTLINE")
    watchText:SetPoint("CENTER")
    watchText:SetText(LText("Watch"))

    local toolbarIcons = {
        { texture = "Interface\\Icons\\INV_Misc_Bag_08" },
        { atlas = "bags-button-autosort-up", fallback = 134532 },
        { atlas = "UI-RefreshButton", fallback = "Interface\\Buttons\\UI-RefreshButton" },
    }
    local previousToolbarButton
    for index, iconData in ipairs(toolbarIcons) do
        local button = CreateInstallerPreviewIcon(toolbar, 27, iconData.texture or iconData.fallback)
        if iconData.atlas and button.Icon and button.Icon.SetAtlas then
            local ok = pcall(button.Icon.SetAtlas, button.Icon, iconData.atlas, false)
            if not ok then
                button.Icon:SetTexture(iconData.fallback)
                button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                button.Icon:SetTexCoord(0, 1, 0, 1)
            end
        end
        if previousToolbarButton then
            button:SetPoint("RIGHT", previousToolbarButton, "LEFT", -5, 0)
        else
            button:SetPoint("RIGHT", -7, 0)
        end
        button:SetBackdropBorderColor(accentR, accentG, accentB, index == 2 and 0.88 or 0.54)
        previousToolbarButton = button
    end

    local footer = CreateFrame("Frame", nil, root, "BackdropTemplate")
    footer:SetPoint("BOTTOMLEFT", 6, 6)
    footer:SetPoint("BOTTOMRIGHT", -6, 6)
    footer:SetHeight(44)
    InstallerApplyPreviewSectionStyle(footer, nil, 0.97, 0.68)
    local previousBag
    for bagIndex = 0, 4 do
        local texture = "Interface\\Buttons\\Button-Backpack-Up"
        if bagIndex > 0 then
            local equipped = _G.GetInventoryItemTexture and _G.GetInventoryItemTexture("player", (_G.CONTAINER_BAG_OFFSET or 19) + bagIndex)
            texture = equipped or "Interface\\Icons\\INV_Misc_Bag_08"
        end
        local bagButton = CreateInstallerPreviewIcon(footer, 28, texture)
        if previousBag then
            bagButton:SetPoint("LEFT", previousBag, "RIGHT", 4, 0)
        else
            bagButton:SetPoint("LEFT", 8, 0)
        end
        bagButton:SetBackdropBorderColor(accentR, accentG, accentB, bagIndex == 0 and 0.88 or 0.45)
        previousBag = bagButton
    end
    local footerSlots = PreviewLabel(footer, 8, mutedR, mutedG, mutedB, "OUTLINE")
    footerSlots:SetPoint("LEFT", previousBag, "RIGHT", 12, 0)
    footerSlots:SetText(string.format("%d %s", #groups.consumable + #groups.equipment + #groups.other, LText("items")))
    local footerGold = PreviewLabel(footer, 8, textR, textG, textB, "OUTLINE")
    footerGold:SetPoint("RIGHT", -8, 0)
    -- Up to two tracked currencies, placed left of the gold like the real footer.
    local previousCurrency = footerGold
    local currencyAPI = _G.C_CurrencyInfo
    for currencyIndex = 1, 2 do
        local info = currencyAPI and currencyAPI.GetBackpackCurrencyInfo and currencyAPI.GetBackpackCurrencyInfo(currencyIndex)
        if info and info.iconFileID then
            local currencyIcon = footer:CreateTexture(nil, "ARTWORK")
            currencyIcon:SetSize(18, 18)
            currencyIcon:SetPoint("RIGHT", previousCurrency, "LEFT", -14, 0)
            currencyIcon:SetTexture(info.iconFileID)
            currencyIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local currencyText = PreviewLabel(footer, 8, textR, textG, textB, "OUTLINE")
            currencyText:SetPoint("RIGHT", currencyIcon, "LEFT", -3, 0)
            currencyText:SetText(tostring(info.quantity or 0))
            previousCurrency = currencyText
        end
    end
    if _G.GetMoneyString and _G.GetMoney then
        footerGold:SetText(_G.GetMoneyString(_G.GetMoney() or 0, true))
    else
        footerGold:SetText("12,450g")
    end

    local content = CreateFrame("Frame", nil, root)
    content:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -5)
    content:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 5)

    local sidebar = CreateFrame("Frame", nil, content, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT")
    sidebar:SetPoint("BOTTOMLEFT")
    sidebar:SetWidth(196)
    InstallerApplyPreviewInsetStyle(sidebar, nil, 0.97)
    local sidebarTitle = PreviewLabel(sidebar, 8, mutedR, mutedG, mutedB, "OUTLINE")
    sidebarTitle:SetPoint("TOPLEFT", 8, -7)
    sidebarTitle:SetText(L["Categories"])

    local categoryRows = {
        { L["All Items"], #groups.consumable + #groups.equipment + #groups.other, 133633 },
        { L["Consumable"], #groups.consumable, 134829 },
        { L["Equipment"], #groups.equipment, 135274 },
        { LText("Other"), #groups.other, 134400 },
    }
    local previousCategory
    for index, category in ipairs(categoryRows) do
        local row = CreateFrame("Frame", nil, sidebar, "BackdropTemplate")
        row:SetPoint("LEFT", 5, 0)
        row:SetPoint("RIGHT", -5, 0)
        row:SetHeight(42)
        if previousCategory then
            row:SetPoint("TOP", previousCategory, "BOTTOM", 0, -2)
        else
            row:SetPoint("TOP", sidebarTitle, "BOTTOM", 0, -6)
        end
        if index == 1 then
            CreateBackdrop(row)
            row:SetBackdropColor(accentR * 0.16, accentG * 0.16, accentB * 0.16, 0.94)
            row:SetBackdropBorderColor(accentR, accentG, accentB, 0.72)
        end
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(32, 32)
        icon:SetPoint("LEFT", 5, 0)
        icon:SetTexture(category[3])
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        local label = PreviewLabel(row, 8, textR, textG, textB)
        label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        label:SetText(category[1])
        local count = PreviewLabel(row, 8, mutedR, mutedG, mutedB)
        count:SetPoint("RIGHT", -5, 0)
        count:SetText(tostring(category[2]))
        previousCategory = row
    end

    local gridPanel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    gridPanel:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 7, 0)
    gridPanel:SetPoint("BOTTOMRIGHT")
    InstallerApplyPreviewInsetStyle(gridPanel, nil, 0.96)
    local gridTitle = PreviewLabel(gridPanel, 9, textR, textG, textB, "OUTLINE")
    gridTitle:SetPoint("TOPLEFT", 8, -6)
    gridTitle:SetText(L["Backpack Categories"])

    local categoryData = {
        { label = L["Consumable"], items = groups.consumable },
        { label = L["Equipment"], items = groups.equipment },
        { label = LText("Other"), items = groups.other },
    }
    local groupY = -36
    for _, category in ipairs(categoryData) do
        local label = PreviewLabel(gridPanel, 8, textR, textG, textB, "OUTLINE")
        label:SetPoint("TOPLEFT", 8, groupY)
        label:SetText(category.label)
        local divider = gridPanel:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("LEFT", label, "RIGHT", 6, 0)
        divider:SetPoint("RIGHT", -7, 0)
        divider:SetHeight(1)
        divider:SetColorTexture(accentR, accentG, accentB, 0.34)

        for index = 1, math.min(10, #category.items) do
            local item = category.items[index]
            local countText = item.count and item.count > 1 and tostring(item.count) or nil
            local icon = CreateInstallerPreviewIcon(gridPanel, 40, item.texture, countText)
            icon:SetPoint("TOPLEFT", 8 + ((index - 1) * 43), groupY - 16)
            SetInstallerPreviewQualityBorder(icon, item.quality)
        end
        groupY = groupY - 76
    end

    return root
end


-- The Bags module's own live preview (Bags_Preview.lua, the one on the /kui
-- Bags page): the real window at its real sizes with your items, categories,
-- currencies and bag style, scaled into the step's box. The hand-drawn one
-- above is the fallback when the Bags addon is not loaded.
local function CreateBagsInstallerLivePreview(parent)
    local bags = KT:GetModule("Bags", true)
    if not (bags and bags.CreateOptionsPreview) then
        return CreateBagsInstallerFallbackPreview(parent)
    end
    local boxW, boxH = parent:GetWidth() or 700, parent:GetHeight() or 320
    local ok, box = pcall(bags.CreateOptionsPreview, bags, parent, boxW - 8)
    if not ok or not box then
        return CreateBagsInstallerFallbackPreview(parent)
    end
    -- The box keeps the height it opened with; give it the step's height
    -- and let it scale the window to fit.
    box.fixedHeight = boxH - 8
    if box.Refresh then pcall(box.Refresh, box) end
    box:ClearAllPoints()
    box:SetPoint("TOP", parent, "TOP", 0, -4)
    return box
end

local function GetInstallerSpecializationIcon(specID, fallbackTexture)
    if specID and _G.GetSpecializationInfoByID then
        local ok, _, _, _, icon = pcall(_G.GetSpecializationInfoByID, specID)
        if ok and icon then
            return icon
        end
    end
    return fallbackTexture
end

local function GetInstallerPlayerSpecPreview()
    local playerName = (_G.UnitName and _G.UnitName("player")) or LText("Player")
    local classToken
    if _G.UnitClass then
        _, classToken = _G.UnitClass("player")
    end
    local classColor = classToken and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classToken]
    local color = classColor
        and { classColor.r or 0.75, classColor.g or 0.75, classColor.b or 0.75 }
        or { 0.75, 0.75, 0.75 }
    local specID
    local specIcon

    if _G.GetSpecialization and _G.GetSpecializationInfo then
        local specIndex = _G.GetSpecialization()
        if specIndex then
            local ok, resolvedSpecID, _, _, resolvedIcon = pcall(_G.GetSpecializationInfo, specIndex)
            if ok then
                specID = resolvedSpecID
                specIcon = resolvedIcon
            end
        end
    end

    if not specIcon and specID then
        specIcon = GetInstallerSpecializationIcon(specID)
    end
    return playerName, specID, specIcon, color, classToken
end

local INSTALLER_DAMAGE_METER_HEROES = {
    { name = "Jaina Proudmoore", specID = 64, classToken = "MAGE" },
    { name = "Thrall", specID = 263, classToken = "SHAMAN" },
    { name = "Sylvanas Windrunner", specID = 254, classToken = "HUNTER" },
    { name = "Anduin Wrynn", specID = 257, classToken = "PRIEST" },
    { name = "Malfurion Stormrage", specID = 105, classToken = "DRUID" },
    { name = "Illidan Stormrage", specID = 577, classToken = "DEMONHUNTER" },
    { name = "Arthas Menethil", specID = 251, classToken = "DEATHKNIGHT" },
    { name = "Varian Wrynn", specID = 71, classToken = "WARRIOR" },
    { name = "Uther Lightbringer", specID = 65, classToken = "PALADIN" },
    { name = "Valeera Sanguinar", specID = 259, classToken = "ROGUE" },
    { name = "Gul'dan", specID = 266, classToken = "WARLOCK" },
    { name = "Chen Stormstout", specID = 268, classToken = "MONK" },
    { name = "Scalecommander Emberthal", specID = 1467, classToken = "EVOKER" },
}

local function GetInstallerClassPreviewColor(classToken)
    local classColor = classToken and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classToken]
    if classColor then
        return { classColor.r or 0.75, classColor.g or 0.75, classColor.b or 0.75 }
    end
    return { 0.75, 0.75, 0.75 }
end

-- Classes this client really has (Forever has no Death Knight, Demon Hunter or Evoker).
local INSTALLER_FOREVER_MISSING_CLASSES = { DEATHKNIGHT = true, DEMONHUNTER = true, EVOKER = true }
local function IsInstallerClassAvailable(classToken)
    if KT.IsForever and KT:IsForever() and INSTALLER_FOREVER_MISSING_CLASSES[classToken] then
        return false
    end
    if _G.GetNumClasses and _G.GetClassInfo then
        local classCount = _G.GetNumClasses()
        if classCount and classCount > 0 then
            for index = 1, classCount do
                local _, classFile = _G.GetClassInfo(index)
                if classFile == classToken then return true end
            end
            return false
        end
    end
    return true
end

-- Spec icons do not exist in every client: fall back to the class icon.
local function ApplyInstallerClassIconFallback(iconFrame, classToken, specIcon)
    if specIcon and specIcon ~= "Interface\\Icons\\INV_Misc_QuestionMark" then return end
    local coords = classToken and _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[classToken]
    if coords and iconFrame and iconFrame.Icon then
        iconFrame.Icon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
        iconFrame.Icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
end

local function GetRandomInstallerDamageHeroes(count, excludedClassToken)
    local candidates = {}
    for _, hero in ipairs(INSTALLER_DAMAGE_METER_HEROES) do
        if hero.classToken ~= excludedClassToken and IsInstallerClassAvailable(hero.classToken) then
            candidates[#candidates + 1] = hero
        end
    end

    for index = #candidates, 2, -1 do
        local swapIndex = math.random(index)
        candidates[index], candidates[swapIndex] = candidates[swapIndex], candidates[index]
    end

    local selected = {}
    for index = 1, math.min(count, #candidates) do
        selected[index] = candidates[index]
    end
    return selected
end

local function CreateDamageMeterInstallerPreview(parent)
    local textR, textG, textB = GetInstallerPreviewTextRGB()
    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", 28, -22)
    root:SetPoint("BOTTOMRIGHT", -28, 22)

    local mode = InstallerCreatePreviewLabel(root, 13, textR, textG, textB, "OUTLINE")
    mode:SetPoint("TOPLEFT", 4, -2)
    mode:SetText(L["Damage Done"] .. "  v")
    local session = InstallerCreatePreviewLabel(root, 13, textR, textG, textB, "OUTLINE")
    session:SetPoint("TOPRIGHT", -4, -2)
    session:SetText(L["Current"] .. "  v")

    local playerName, playerSpecID, playerSpecIcon, playerColor = GetInstallerPlayerSpecPreview()
    local rows = {
        { playerName, 12.35, "154.4K", playerSpecID, playerSpecIcon or "Interface\\Icons\\INV_Misc_QuestionMark", playerColor },
        { "Futnorris", 9.82, "122.7K", 72, "Interface\\Icons\\Ability_Warrior_InnerRage", { 0.78, 0.61, 0.43 } },
        { "Qute", 7.41, "92.6K", 63, "Interface\\Icons\\Spell_Fire_FireBolt02", { 0.25, 0.78, 0.92 } },
        { "Yhii", 5.16, "64.5K", 258, "Interface\\Icons\\Spell_Shadow_ShadowWordPain", { 1.00, 1.00, 1.00 } },
    }
    local maxValue = rows[1][2]
    local previous
    for index, data in ipairs(rows) do
        local row = CreateFrame("Frame", nil, root)
        row:SetPoint("LEFT", 0, 0)
        row:SetPoint("RIGHT", 0, 0)
        row:SetHeight(32)
        if previous then
            row:SetPoint("TOP", previous, "BOTTOM", 0, -4)
        else
            row:SetPoint("TOP", root, "TOP", 0, -34)
        end
        local bar = row:CreateTexture(nil, "BACKGROUND")
        bar:SetPoint("TOPLEFT", 36, -2)
        bar:SetPoint("BOTTOMLEFT", 36, 2)
        bar:SetWidth(math.max(80, 500 * (data[2] / maxValue)))
        bar:SetTexture(INSTALLER_MELLI_TEXTURE)
        bar:SetVertexColor(data[6][1], data[6][2], data[6][3], 0.92)
        local specIcon = GetInstallerSpecializationIcon(data[4], data[5])
        local icon = CreateInstallerPreviewIcon(row, 28, specIcon)
        icon:SetPoint("LEFT", 0, 0)
        icon:SetBackdropBorderColor(data[6][1], data[6][2], data[6][3], 0.92)
        local rank = InstallerCreatePreviewLabel(row, 10, textR, textG, textB, "OUTLINE")
        rank:SetPoint("LEFT", icon, "RIGHT", 8, 0)
        rank:SetText(index .. ".  " .. data[1])
        local amount = InstallerCreatePreviewLabel(row, 10, textR, textG, textB, "OUTLINE")
        amount:SetPoint("RIGHT", -82, 0)
        amount:SetText(string.format("%.2fM", data[2]))
        local dps = InstallerCreatePreviewLabel(row, 10, textR, textG, textB, "OUTLINE")
        dps:SetPoint("RIGHT", -8, 0)
        dps:SetText(data[3])
        previous = row
    end
    return root
end

local METER_PREVIEW_SKINS = {
    kui = { panel = { 0.03, 0.032, 0.04, 0.95 }, edge = { 0.18, 0.18, 0.22, 1 }, rowBg = { 0.025, 0.028, 0.038, 0.88 },
        barTexture = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\Melli.tga" },
    classic = { panel = { 0.06, 0.04, 0.03, 0.96 }, edge = { 0, 0, 0, 1 }, header = { 0.60, 0.06, 0.05, 1 },
        title = { 1, 0.9, 0.45 }, rowBg = { 0.05, 0.03, 0.02, 0.7 },
        -- The Classic meter's bar texture (BantoBar), same file as the live Classic meter.
        barTexture = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\damagemeter\\BantoBar.tga" },
    retail = { panel = { 0.03, 0.035, 0.045, 0.94 }, edge = { 0.12, 0.12, 0.14, 1 }, title = { 1, 0.82, 0.1 },
        rowBg = { 0.02, 0.02, 0.03, 0.9 }, barTexture = "Interface\\TargetingFrame\\UI-StatusBar" },
    forever = { panel = { 0.15, 0.11, 0.075, 0.9 }, edge = { 0.72, 0.55, 0.30, 1 }, title = { 0.862745, 0.521569, 0.376471 },
        rowBg = { 0.075, 0.055, 0.04, 0.9 }, iconBorder = { 0.55, 0.42, 0.24, 1 },
        barTexture = "Interface\\TargetingFrame\\UI-StatusBar" },
}

local function CreateDamageMeterInstallerFallbackPreview(parent, styleKey)
    local textR, textG, textB = GetInstallerPreviewTextRGB()
    local skin = METER_PREVIEW_SKINS[styleKey or ""] or METER_PREVIEW_SKINS.kui
    local titleR, titleG, titleB = textR, textG, textB
    if skin.title then titleR, titleG, titleB = skin.title[1], skin.title[2], skin.title[3] end
    local root = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    root:SetPoint("TOPLEFT", 14, -14)
    root:SetPoint("BOTTOMRIGHT", -14, 14)
    CreateBackdrop(root)
    root:SetBackdropColor(unpack(skin.panel))
    root:SetBackdropBorderColor(unpack(skin.edge))

    -- Retail and Forever draw the real meter's own art (same atlases as the live meter).
    local nativeStyle = (styleKey == "retail" or styleKey == "forever") and styleKey or nil
    local function StyleAtlas(texture, name)
        local themes = KT.VisualThemes
        local info = name and ((themes and themes.GetStyleAtlasInfo and themes:GetStyleAtlasInfo(name))
            or (C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name)))
        if not info then return false end
        if info.packaged then
            texture:SetTexture(info.file)
            texture:SetTexCoord(info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)
        else
            texture:SetAtlas(name)
        end
        texture:SetVertexColor(1, 1, 1, 1)
        texture:Show()
        return true
    end
    if nativeStyle == "retail" then
        local panelArt = root:CreateTexture(nil, "BACKGROUND", nil, 1)
        panelArt:SetAllPoints()
        if StyleAtlas(panelArt, "damagemeters-background") then
            root:SetBackdropColor(0, 0, 0, 0)
        else
            panelArt:Hide()
        end
        local headerArt = root:CreateTexture(nil, "BACKGROUND", nil, 4)
        headerArt:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        headerArt:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
        headerArt:SetHeight(32)
        if not StyleAtlas(headerArt, "ui-damagemeters-header-bar") then headerArt:Hide() end
    end
    if skin.header then
        local band = root:CreateTexture(nil, "BACKGROUND")
        band:SetPoint("TOPLEFT", 1, -1)
        band:SetPoint("TOPRIGHT", -1, -1)
        band:SetHeight(30)
        band:SetColorTexture(unpack(skin.header))
    end

    local modeIcon = root:CreateTexture(nil, "ARTWORK")
    modeIcon:SetSize(18, 18)
    modeIcon:SetPoint("TOPLEFT", 10, -7)
    modeIcon:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\damagemeter\\DPS.png")

    local mode = InstallerCreatePreviewLabel(root, 12, titleR, titleG, titleB, "OUTLINE")
    mode:SetPoint("LEFT", modeIcon, "RIGHT", 5, 0)
    mode:SetText((LText("Damage Done")) .. "  v")
    local session = InstallerCreatePreviewLabel(root, 12, titleR, titleG, titleB, "OUTLINE")
    session:SetPoint("TOPRIGHT", -10, -9)
    session:SetText((LText("Current")) .. "  v")

    local playerName, playerSpecID, playerSpecIcon, playerColor, playerClassToken = GetInstallerPlayerSpecPreview()
    local rows = {
        { playerName, 12.35, "154.4K", playerSpecID, playerSpecIcon or "Interface\\Icons\\INV_Misc_QuestionMark", playerColor, playerClassToken },
    }
    local exampleValues = {
        { 9.82, "122.7K" },
        { 7.41, "92.6K" },
        { 5.16, "64.5K" },
        { 3.88, "48.5K" },
    }
    for index, hero in ipairs(GetRandomInstallerDamageHeroes(4, playerClassToken)) do
        local values = exampleValues[index]
        rows[#rows + 1] = {
            hero.name,
            values[1],
            values[2],
            hero.specID,
            "Interface\\Icons\\INV_Misc_QuestionMark",
            GetInstallerClassPreviewColor(hero.classToken),
            hero.classToken,
        }
    end
    local maxValue = rows[1][2]
    local previous
    for index, data in ipairs(rows) do
        local row = CreateFrame("Frame", nil, root)
        row:SetPoint("LEFT", 8, 0)
        row:SetPoint("RIGHT", -8, 0)
        row:SetHeight(28)
        if previous then
            row:SetPoint("TOP", previous, "BOTTOM", 0, -4)
        else
            row:SetPoint("TOP", root, "TOP", 0, -40)
        end

        local specIcon = GetInstallerSpecializationIcon(data[4], data[5])
        local icon = CreateInstallerPreviewIcon(row, 28, specIcon)
        icon:SetPoint("LEFT", 0, 0)
        if skin.iconBorder then icon:SetBackdropBorderColor(unpack(skin.iconBorder)) else icon:SetBackdropBorderColor(data[6][1], data[6][2], data[6][3], 0.95) end
        ApplyInstallerClassIconFallback(icon, data[7], specIcon)

        local background = row:CreateTexture(nil, "BACKGROUND")
        background:SetPoint("TOPLEFT", icon, "TOPRIGHT", 1, -1)
        background:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
        background:SetColorTexture(unpack(skin.rowBg))

        local bar = CreateFrame("StatusBar", nil, row)
        bar:SetPoint("TOPLEFT", icon, "TOPRIGHT", 1, -1)
        bar:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 1)
        bar:SetStatusBarTexture(skin.barTexture)
        bar:SetStatusBarColor(data[6][1], data[6][2], data[6][3], 0.92)
        bar:SetMinMaxValues(0, maxValue)
        bar:SetValue(data[2])

        local shade = bar:CreateTexture(nil, "ARTWORK")
        shade:SetAllPoints()
        shade:SetColorTexture(0, 0, 0, 0.13)

        if nativeStyle then
            -- Fill, row shadow and edge exactly as the live Retail/Forever meter builds them.
            local fill = bar:GetStatusBarTexture()
            if fill and StyleAtlas(fill, "UI-HUD-CoolDownManager-Bar") then
                fill:SetVertexColor(data[6][1], data[6][2], data[6][3], 0.92)
            end
            StyleAtlas(background, "ui-damagemeters-bar-shadowbg")
            local edgeArt = bar:CreateTexture(nil, "OVERLAY", nil, 4)
            edgeArt:SetPoint("TOPLEFT", background, "TOPLEFT", -2, 2)
            edgeArt:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", 2, -2)
            if not StyleAtlas(edgeArt, "ui-damagemeters-bar-shadowedge") then edgeArt:Hide() end
        end

        local textLayer = CreateFrame("Frame", nil, bar)
        textLayer:SetAllPoints()
        textLayer:SetFrameLevel(bar:GetFrameLevel() + 2)

        local rank = InstallerCreatePreviewLabel(textLayer, 10, 1, 1, 1, "OUTLINE")
        rank:SetPoint("LEFT", textLayer, "LEFT", 4, 0)
        rank:SetWidth(15)
        rank:SetJustifyH("LEFT")
        rank:SetText(index .. ".")

        local amount = InstallerCreatePreviewLabel(textLayer, 10, 1, 1, 1, "OUTLINE")
        amount:SetPoint("RIGHT", textLayer, "RIGHT", -78, 0)
        amount:SetWidth(64)
        amount:SetJustifyH("RIGHT")
        amount:SetText(string.format("%.2fM", data[2]))

        local rate = InstallerCreatePreviewLabel(textLayer, 10, 1, 1, 1, "OUTLINE")
        rate:SetPoint("RIGHT", textLayer, "RIGHT", -4, 0)
        rate:SetWidth(66)
        rate:SetJustifyH("RIGHT")
        rate:SetText(data[3])

        local name = InstallerCreatePreviewLabel(textLayer, 10, 1, 1, 1, "OUTLINE")
        name:SetPoint("LEFT", rank, "RIGHT", 1, 0)
        name:SetPoint("RIGHT", amount, "LEFT", -6, 0)
        name:SetJustifyH("LEFT")
        name:SetWordWrap(false)
        name:SetText(data[1])
        previous = row
    end
    return root
end


-- The real Damage Meter window in its preview mode (Enhancements_DamageMeter
-- .lua, Mod:CreateInstallerDamageMeterPreview): header with mode and session,
-- the chosen style's toolbar and art, sample rows, lock and resize grip,
-- fitted into the step's box. Without it, the /kui options preview
-- (Enhancements_Options.lua), and the hand-drawn one above last.
local function CreateDamageMeterInstallerLivePreview(parent, styleKey)
    local db, enhancements = GetInstallerEnhancementsDB()
    if enhancements and enhancements.CreateInstallerDamageMeterPreview then
        -- The meter copies its settings when built: build it with the chosen
        -- style's own Damage Meter settings so it keeps that look.
        local themes = KT.VisualThemes
        local frame
        if styleKey and themes and themes.WithPreviewProfile then
            frame = themes:WithPreviewProfile("damagemeter", styleKey,
                enhancements.CreateInstallerDamageMeterPreview, enhancements, parent)
        else
            local ok, created = pcall(enhancements.CreateInstallerDamageMeterPreview, enhancements, parent)
            frame = ok and created or nil
        end
        if frame then return frame end
    end
    local config = db and db.damageMeter
    if not (enhancements and enhancements.CreateDamageMeterLivePreview and config) then
        return CreateDamageMeterInstallerFallbackPreview(parent, styleKey)
    end

    local boxW, boxH = parent:GetWidth() or 460, parent:GetHeight() or 256
    local naturalW = math.max(150, tonumber(config.width) or 320)
    local naturalH = math.max(72, tonumber(config.height) or 220) + 26
    -- The preview scales itself to its container's width only, so the holder
    -- is scaled to make the height fit as well.
    local k = math.min(1, (boxH - 16) / naturalH)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetScale(k)
    holder:SetSize(boxW / k, boxH / k)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    local ok, preview = pcall(enhancements.CreateDamageMeterLivePreview, holder, config, 8, { static = true })
    if not ok or not preview then
        holder:Hide()
        return CreateDamageMeterInstallerFallbackPreview(parent, styleKey)
    end
    holder.preview = preview
    return holder
end

local function CreateCooldownManagerInstallerPreview(parent)
    local accentR, accentG, accentB = GetInstallerPreviewAccentRGB()
    local textR, textG, textB = GetInstallerPreviewTextRGB()
    local mutedR, mutedG, mutedB = GetInstallerPreviewMutedRGB()
    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", 20, -16)
    root:SetPoint("BOTTOMRIGHT", -20, 16)

    local title = InstallerCreatePreviewLabel(root, 11, textR, textG, textB, "OUTLINE")
    title:SetPoint("TOP", 0, -2)
    title:SetText(L["Cooldown Manager"])

    local bars = {
        { label = L["Cooldowns"], size = 42, y = -34, textures = { 135846, 136116, 136243, 136197, 136041, 135932, 132347 } },
        { label = L["Utility"], size = 34, y = -92, textures = { 135952, 136075, 135953, 136090, 135894, 136048 } },
        { label = L["Buffs"], size = 32, y = -142, textures = { 136224, 136097, 135990, 136080, 136129 } },
    }
    for _, barData in ipairs(bars) do
        local label = InstallerCreatePreviewLabel(root, 8, mutedR, mutedG, mutedB, "OUTLINE")
        label:SetPoint("TOP", root, "TOP", 0, barData.y)
        label:SetText(barData.label)
        local totalWidth = #barData.textures * (barData.size + 3) - 3
        for index, texture in ipairs(barData.textures) do
            local icon = CreateInstallerPreviewIcon(root, barData.size, texture, index < 4 and tostring(index * 3) or nil)
            icon:SetPoint("TOPLEFT", root, "TOP", -totalWidth / 2 + (index - 1) * (barData.size + 3), barData.y - 14)
            if index == 1 then
                icon:SetBackdropBorderColor(accentR, accentG, accentB, 0.92)
            end
        end
    end
    local power = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    power:SetSize(310, 8)
    power:SetPoint("BOTTOM", 0, 4)
    power:SetStatusBarTexture(INSTALLER_MELLI_TEXTURE)
    power:SetStatusBarColor(accentR, accentG, accentB, 0.95)
    power:SetMinMaxValues(0, 100)
    power:SetValue(72)
    CreateBackdrop(power)
    power:SetBackdropColor(0.02, 0.02, 0.025, 0.92)
    return root
end

local INSTALLER_CDM_CLASS_SPELLS = {
    WARRIOR = {
        cooldowns = { 1719, 107574, 227847, 167105, 46924, 152277, 385059 },
        utility = { 100, 97462, 23920, 3411, 5246, 18499 },
        buffs = { 6673, 12975, 12328, 386164, 20230 },
    },
    PALADIN = {
        cooldowns = { 31884, 231895, 105809, 20066, 255937, 343527, 389539 },
        utility = { 642, 633, 1022, 6940, 853, 1044 },
        buffs = { 465, 20217, 31850, 184662, 223819 },
    },
    HUNTER = {
        cooldowns = { 19574, 288613, 193530, 359844, 120679, 266779, 321530 },
        utility = { 186265, 109304, 5384, 781, 34477, 187650 },
        buffs = { 186257, 5118, 131894, 257946, 260242 },
    },
    ROGUE = {
        cooldowns = { 13750, 121471, 51690, 79140, 360194, 381989, 385627 },
        utility = { 31224, 5277, 1856, 1766, 2094, 36554 },
        buffs = { 315496, 1966, 13877, 5171, 2823 },
    },
    PRIEST = {
        cooldowns = { 10060, 47536, 64843, 200183, 228260, 391109, 34433 },
        utility = { 33206, 62618, 73325, 8122, 586, 32375 },
        buffs = { 21562, 17, 139, 194384, 391401 },
    },
    DEATHKNIGHT = {
        cooldowns = { 51271, 49028, 49206, 63560, 383269, 152279, 207289 },
        utility = { 48792, 48707, 51052, 49576, 47528, 108199 },
        buffs = { 57330, 55233, 194679, 194844, 219809 },
    },
    SHAMAN = {
        cooldowns = { 114050, 114051, 51533, 192249, 198067, 114052, 384352 },
        utility = { 108271, 98008, 192058, 8143, 57994, 2825 },
        buffs = { 2645, 974, 383648, 108281, 79206 },
    },
    MAGE = {
        cooldowns = { 190319, 12472, 365350, 12042, 153595, 205025, 116011 },
        utility = { 45438, 110959, 1953, 2139, 80353, 66 },
        buffs = { 1459, 130, 12051, 235450, 190446 },
    },
    WARLOCK = {
        cooldowns = { 1122, 111898, 205180, 265187, 267217, 113858, 386997 },
        utility = { 104773, 108416, 48020, 678, 30283, 20707 },
        buffs = { 5697, 20707, 264119, 111400, 386124 },
    },
    MONK = {
        cooldowns = { 123904, 137639, 152173, 322109, 325197, 310454, 387184 },
        utility = { 115203, 122278, 122783, 119381, 116841, 115078 },
        buffs = { 116781, 125883, 124682, 388686, 450380 },
    },
    DRUID = {
        cooldowns = { 194223, 106951, 102560, 102543, 50334, 740, 391528 },
        utility = { 22812, 61336, 29166, 20484, 102793, 132469 },
        buffs = { 1126, 768, 5487, 5215, 1850 },
    },
    DEMONHUNTER = {
        cooldowns = { 191427, 212084, 258860, 200166, 198013, 370965, 390163 },
        utility = { 198589, 196718, 195072, 179057, 217832, 188501 },
        buffs = { 203819, 188499, 258920, 389847, 427912 },
    },
    EVOKER = {
        cooldowns = { 375087, 357210, 359073, 403631, 370553, 382266, 442204 },
        utility = { 363916, 374348, 370665, 374251, 360806, 351338 },
        buffs = { 364342, 381748, 395152, 410089, 408233 },
    },
}

local function GetInstallerSpellTexture(spellID, fallbackTexture)
    if spellID and _G.C_Spell and _G.C_Spell.GetSpellTexture then
        local ok, texture = pcall(_G.C_Spell.GetSpellTexture, spellID)
        if ok and texture then
            return texture
        end
    end
    if spellID and _G.GetSpellTexture then
        local ok, texture = pcall(_G.GetSpellTexture, spellID)
        if ok and texture then
            return texture
        end
    end
    return fallbackTexture or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function GetInstallerPlayerClassPreviewData()
    local localizedClass
    local classToken
    if _G.UnitClass then
        localizedClass, classToken = _G.UnitClass("player")
    end
    classToken = classToken or "WARRIOR"
    localizedClass = localizedClass or classToken
    local classSpells = INSTALLER_CDM_CLASS_SPELLS[classToken] or INSTALLER_CDM_CLASS_SPELLS.WARRIOR
    local classColor = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classToken]
    local color = classColor
        and { classColor.r or 0.78, classColor.g or 0.61, classColor.b or 0.43 }
        or { 0.78, 0.61, 0.43 }

    local specName = localizedClass
    local specID
    local specIcon = "Interface\\Icons\\INV_Misc_QuestionMark"
    if _G.GetSpecialization and _G.GetSpecializationInfo then
        local specIndex = _G.GetSpecialization()
        if specIndex then
            local ok, resolvedSpecID, resolvedName, _, resolvedIcon = pcall(_G.GetSpecializationInfo, specIndex)
            if ok then
                specID = resolvedSpecID
                specName = resolvedName or specName
                specIcon = resolvedIcon or specIcon
            end
        end
    end
    return classSpells, localizedClass, specName, specIcon, color, specID, classToken
end

local function CreateClassCooldownManagerInstallerPreview(parent)
    local textR, textG, textB = GetInstallerPreviewTextRGB()
    local mutedR, mutedG, mutedB = GetInstallerPreviewMutedRGB()
    local classSpells, localizedClass, specName, specIcon, classColor = GetInstallerPlayerClassPreviewData()

    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", 20, -13)
    root:SetPoint("BOTTOMRIGHT", -20, 13)

    local specIconFrame = CreateInstallerPreviewIcon(root, 30, specIcon)
    specIconFrame:SetPoint("TOPLEFT", 5, -2)
    specIconFrame:SetBackdropBorderColor(classColor[1], classColor[2], classColor[3], 0.95)

    local title = InstallerCreatePreviewLabel(root, 11, textR, textG, textB, "OUTLINE")
    title:SetPoint("TOPLEFT", specIconFrame, "TOPRIGHT", 8, -1)
    title:SetText(L["Cooldown Manager"])

    local classLabel = InstallerCreatePreviewLabel(root, 9, classColor[1], classColor[2], classColor[3], "OUTLINE")
    classLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    classLabel:SetText(string.format("%s - %s", localizedClass, specName))

    local barDefinitions = {
        { key = "cooldowns", label = L["Cooldowns"], size = 38, top = -42, limit = 7 },
        { key = "utility", label = L["Utility"], size = 32, top = -100, limit = 6 },
        { key = "buffs", label = L["Buffs"], size = 28, top = -151, limit = 5 },
    }

    for _, definition in ipairs(barDefinitions) do
        local panel = CreateFrame("Frame", nil, root, "BackdropTemplate")
        panel:SetPoint("TOPLEFT", 4, definition.top)
        panel:SetPoint("TOPRIGHT", -4, definition.top)
        panel:SetHeight(definition.size + 12)
        InstallerApplyPreviewInsetStyle(panel, classColor, 0.94)

        local label = InstallerCreatePreviewLabel(panel, 8, mutedR, mutedG, mutedB, "OUTLINE")
        label:SetPoint("LEFT", 8, 0)
        label:SetWidth(88)
        label:SetJustifyH("RIGHT")
        label:SetWordWrap(false)
        label:SetText(definition.label)

        local spellIDs = classSpells[definition.key] or {}
        local fallbackTexture = specIcon
        local spacing = 4
        for index = 1, math.min(definition.limit, #spellIDs) do
            local texture = GetInstallerSpellTexture(spellIDs[index], fallbackTexture)
            local cooldownText = index <= 3 and tostring((index * 3) + (definition.key == "cooldowns" and 3 or 0)) or nil
            local icon = CreateInstallerPreviewIcon(panel, definition.size, texture, cooldownText)
            icon:SetPoint("LEFT", panel, "LEFT", 108 + ((index - 1) * (definition.size + spacing)), 0)
            if index == 1 then
                icon:SetBackdropBorderColor(classColor[1], classColor[2], classColor[3], 1)
            end
        end
    end

    local power = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    power:SetPoint("BOTTOMLEFT", 112, 2)
    power:SetPoint("BOTTOMRIGHT", -8, 2)
    power:SetHeight(7)
    power:SetStatusBarTexture(INSTALLER_MELLI_TEXTURE)
    power:SetStatusBarColor(classColor[1], classColor[2], classColor[3], 0.95)
    power:SetMinMaxValues(0, 100)
    power:SetValue(72)
    CreateBackdrop(power)
    power:SetBackdropColor(0.02, 0.02, 0.025, 0.92)

    return root
end

local function GetInstallerViewerSpellIDs(viewerNames, limit)
    local spellIDs = {}
    local seen = {}

    local function AddChild(child)
        if not child or #spellIDs >= limit then
            return
        end
        local spellID = child.spellID
            or (child.cooldownInfo and child.cooldownInfo.spellID)
        if not spellID and child.GetSpellID then
            local ok, resolvedSpellID = pcall(child.GetSpellID, child)
            if ok then
                spellID = resolvedSpellID
            end
        end
        if spellID and not seen[spellID] then
            seen[spellID] = true
            spellIDs[#spellIDs + 1] = spellID
        end
    end

    for _, viewerName in ipairs(viewerNames) do
        local viewer = _G[viewerName]
        if viewer then
            if viewer.itemFramePool and viewer.itemFramePool.EnumerateActive then
                for child in viewer.itemFramePool:EnumerateActive() do
                    AddChild(child)
                end
            elseif viewer.EnumerateChildren then
                for child in viewer:EnumerateChildren() do
                    AddChild(child)
                end
            elseif viewer.GetChildren then
                for _, child in ipairs({ viewer:GetChildren() }) do
                    AddChild(child)
                end
            end
        end
        if #spellIDs >= limit then
            break
        end
    end
    return spellIDs
end

local function GetInstallerPreviewSpellIDs(viewerNames, fallbackSpellIDs, limit)
    local result = GetInstallerViewerSpellIDs(viewerNames, limit)
    local seen = {}
    for _, spellID in ipairs(result) do
        seen[spellID] = true
    end

    local function IsKnown(spellID)
        if _G.IsPlayerSpell then
            local ok, known = pcall(_G.IsPlayerSpell, spellID)
            if ok and known then
                return true
            end
        end
        if _G.C_SpellBook and _G.C_SpellBook.IsSpellKnown then
            local ok, known = pcall(_G.C_SpellBook.IsSpellKnown, spellID)
            if ok and known then
                return true
            end
        end
        return false
    end

    for _, spellID in ipairs(fallbackSpellIDs or {}) do
        if #result >= limit then
            break
        end
        if not seen[spellID] and IsKnown(spellID) then
            seen[spellID] = true
            result[#result + 1] = spellID
        end
    end
    if #result == 0 then
        for _, spellID in ipairs(fallbackSpellIDs or {}) do
            if #result >= limit then
                break
            end
            if not seen[spellID] then
                seen[spellID] = true
                result[#result + 1] = spellID
            end
        end
    end
    return result
end

local function InstallerIsSpellKnown(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then return false end
    if _G.IsPlayerSpell then
        local ok, known = pcall(_G.IsPlayerSpell, spellID)
        if ok and known then return true end
    end
    if _G.C_SpellBook and _G.C_SpellBook.IsSpellKnown then
        local ok, known = pcall(_G.C_SpellBook.IsSpellKnown, spellID)
        if ok and known then return true end
    end
    return false
end

-- Category sets with includeUnknown=false are generated by Blizzard for the
-- player's current specialization and selected talents. They are a more
-- accurate source for the Installer than a generic per-class spell pool.
local function GetInstallerCategorySpellIDs(categories)
    local spellIDs, seen = {}, {}
    if not (_G.C_CooldownViewer
        and _G.C_CooldownViewer.GetCooldownViewerCategorySet
        and _G.C_CooldownViewer.GetCooldownViewerCooldownInfo) then
        return spellIDs, false
    end

    for _, category in ipairs(categories or {}) do
        local okIDs, cooldownIDs = pcall(_G.C_CooldownViewer.GetCooldownViewerCategorySet, category, false)
        if okIDs and type(cooldownIDs) == "table" then
            for _, cooldownID in ipairs(cooldownIDs) do
                local okInfo, info = pcall(_G.C_CooldownViewer.GetCooldownViewerCooldownInfo, cooldownID)
                if okInfo and info then
                    local spellID = info.spellID
                    if (type(spellID) ~= "number" or spellID <= 0)
                        and type(info.overrideSpellID) == "number" and info.overrideSpellID > 0 then
                        spellID = info.overrideSpellID
                    end
                    if type(spellID) == "number" and spellID > 0 and not seen[spellID] then
                        seen[spellID] = true
                        spellIDs[#spellIDs + 1] = spellID
                    end
                end
            end
        end
    end
    return spellIDs, true
end

local function GetInstallerSpecPreviewSpellIDs(categories, viewerNames, fallbackSpellIDs, limit)
    local viewerIDs = GetInstallerViewerSpellIDs(viewerNames, limit)
    if #viewerIDs > 0 then return viewerIDs end

    local categoryIDs, categoryAPIAvailable = GetInstallerCategorySpellIDs(categories)
    if #categoryIDs > 0 then return categoryIDs end
    if categoryAPIAvailable then return {} end

    return GetInstallerPreviewSpellIDs(viewerNames, fallbackSpellIDs, limit)
end

local INSTALLER_SPEC_INTERRUPTS = {
    [62] = 2139, [63] = 2139, [64] = 2139,
    [65] = 96231, [66] = 96231, [70] = 96231,
    [71] = 6552, [72] = 6552, [73] = 6552,
    [102] = 78675, [103] = 106839, [104] = 106839, [105] = 106839,
    [250] = 47528, [251] = 47528, [252] = 47528,
    [253] = 147362, [254] = 147362, [255] = 187707,
    [258] = 15487,
    [259] = 1766, [260] = 1766, [261] = 1766,
    [262] = 57994, [263] = 57994, [264] = 57994,
    [265] = 19647, [266] = 19647, [267] = 19647,
    [268] = 116705, [269] = 116705, [270] = 116705,
    [577] = 183752, [581] = 183752,
    [1467] = 351338, [1468] = 351338, [1473] = 351338,
}

local INSTALLER_CLASS_INTERRUPTS = {
    WARRIOR = 6552, PALADIN = 96231, HUNTER = 147362, ROGUE = 1766,
    PRIEST = 15487, DEATHKNIGHT = 47528, SHAMAN = 57994, MAGE = 2139,
    WARLOCK = 19647, MONK = 116705, DRUID = 106839,
    DEMONHUNTER = 183752, EVOKER = 351338,
}

local function RemoveInstallerSpellID(spellIDs, spellID)
    local removed = false
    for index = #spellIDs, 1, -1 do
        if spellIDs[index] == spellID then
            table.remove(spellIDs, index)
            removed = true
        end
    end
    return removed
end

local function MoveInstallerInterruptToUtility(cooldownIDs, utilityIDs, specID, classToken)
    local interruptID = INSTALLER_SPEC_INTERRUPTS[specID] or INSTALLER_CLASS_INTERRUPTS[classToken]
    if not interruptID then return end

    local wasCooldown = RemoveInstallerSpellID(cooldownIDs, interruptID)
    local wasUtility = RemoveInstallerSpellID(utilityIDs, interruptID)
    if wasCooldown or wasUtility or InstallerIsSpellKnown(interruptID) then
        table.insert(utilityIDs, 1, interruptID)
    end
end
local INSTALLER_SPEC_POWER_TOKENS = {
    [62] = "MANA", [63] = "MANA", [64] = "MANA",
    [65] = "HOLY_POWER", [66] = "HOLY_POWER", [70] = "HOLY_POWER",
    [102] = "LUNAR_POWER", [103] = "ENERGY", [104] = "RAGE", [105] = "MANA",
    [256] = "MANA", [257] = "MANA", [258] = "INSANITY",
    [262] = "MAELSTROM", [263] = "MANA", [264] = "MANA",
    [268] = "ENERGY", [269] = "CHI", [270] = "MANA",
    [577] = "FURY", [581] = "FURY",
    [1467] = "ESSENCE", [1468] = "ESSENCE", [1473] = "ESSENCE",
}

local INSTALLER_CLASS_POWER_TOKENS = {
    WARRIOR = "RAGE",
    PALADIN = "HOLY_POWER",
    HUNTER = "FOCUS",
    ROGUE = "ENERGY",
    PRIEST = "MANA",
    DEATHKNIGHT = "RUNIC_POWER",
    SHAMAN = "MANA",
    MAGE = "MANA",
    WARLOCK = "SOUL_SHARDS",
    MONK = "ENERGY",
    DRUID = "MANA",
    DEMONHUNTER = "FURY",
    EVOKER = "ESSENCE",
}

local function GetInstallerPlayerPowerPreview(specID, classToken)
    local powerToken = INSTALLER_SPEC_POWER_TOKENS[specID]
        or INSTALLER_CLASS_POWER_TOKENS[classToken]
        or "MANA"
    local powerColor = _G.PowerBarColor and _G.PowerBarColor[powerToken]
    local color = {
        powerColor and powerColor.r or 0.20,
        powerColor and powerColor.g or 0.55,
        powerColor and powerColor.b or 1.00,
    }
    local label = _G[powerToken]
    if type(label) ~= "string" or label == "" then
        label = powerToken:gsub("_", " "):lower():gsub("^%l", string.upper)
    end
    return label, 64, color
end

local function CreateMythicPlusTimerInstallerLivePreview(parent)
    local textR, textG, textB = GetInstallerPreviewTextRGB()
    local mutedR, mutedG, mutedB = GetInstallerPreviewMutedRGB()
    local root = CreateFrame("Frame", nil, parent)
    root:SetSize(271, 180)
    root:SetPoint("CENTER", parent, "CENTER", 0, 0)

    local pad = 8
    local width = root:GetWidth()
    local contentWidth = width - (pad * 2)
    local barTexture = INSTALLER_MELLI_TEXTURE
    local readyTexture = "Interface\\RaidFrame\\ReadyCheck-Ready"

    local deaths = InstallerCreatePreviewLabel(root, 13, 1, 0, 0.412, "OUTLINE")
    deaths:SetPoint("TOPRIGHT", root, "TOPRIGHT", -pad, 0)
    deaths:SetJustifyH("RIGHT")
    deaths:SetText(string.format(LText("%d Deaths (%s)"), 2, "-00:10"))

    local timer = InstallerCreatePreviewLabel(root, 26, 1, 0.808, 0.714, "OUTLINE")
    timer:SetPoint("TOPRIGHT", root, "TOPRIGHT", -pad, -17)
    timer:SetJustifyH("RIGHT")
    timer:SetText("20:00 / 30:00")

    local keyRow = CreateFrame("Frame", nil, root)
    keyRow:SetSize(215, 17)
    keyRow:SetPoint("TOP", root, "TOP", 0, -49)

    local keyDetails = InstallerCreatePreviewLabel(keyRow, 13, 1, 0.804, 0.569, "OUTLINE")
    keyDetails:SetPoint("RIGHT", keyRow, "CENTER", -3, 0)
    keyDetails:SetJustifyH("RIGHT")
    keyDetails:SetText(LText("Tyrannical - Fortified"))

    local key = InstallerCreatePreviewLabel(keyRow, 16, 0.761, 0, 1, "OUTLINE")
    key:SetPoint("LEFT", keyRow, "CENTER", 3, 0)
    key:SetJustifyH("LEFT")
    key:SetText("[10]")

    local segmentColors = {
        { 0, 1, 0.478 },
        { 0, 0.749, 1 },
        { 0.796, 0, 1 },
    }
    local segmentLabels = { "4:00", "8:00", "12:00" }
    local gap = 2
    local availableWidth = contentWidth - (pad * 2)
    local firstWidth = math.floor((availableWidth - (gap * 2)) * 0.6)
    local secondWidth = math.floor((availableWidth - (gap * 2)) * 0.2)
    local thirdWidth = availableWidth - (gap * 2) - firstWidth - secondWidth
    local segmentWidths = { firstWidth, secondWidth, thirdWidth }
    local x = pad

    for index = 1, 3 do
        local bar = CreateFrame("StatusBar", nil, root)
        bar:SetSize(segmentWidths[index], 10)
        bar:SetPoint("TOPLEFT", root, "TOPLEFT", x, -74)
        bar:SetStatusBarTexture(barTexture)
        bar:SetStatusBarColor(segmentColors[index][1], segmentColors[index][2], segmentColors[index][3], 1)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0.42)

        local value = InstallerCreatePreviewLabel(bar, 10, 1, 0.808, 0.714, "OUTLINE")
        value:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -2, 1)
        value:SetJustifyH("RIGHT")
        value:SetText(segmentLabels[index])
        x = x + segmentWidths[index] + gap
    end

    local forces = CreateFrame("StatusBar", nil, root)
    forces:SetSize(availableWidth, 10)
    forces:SetPoint("TOPLEFT", root, "TOPLEFT", pad, -101)
    forces:SetStatusBarTexture(barTexture)
    forces:SetStatusBarColor(0.733, 0.62, 0.133, 1)
    forces:SetMinMaxValues(0, 1)
    forces:SetValue(0.8233)

    local forcesText = InstallerCreatePreviewLabel(root, 11, textR, textG, textB, "OUTLINE")
    forcesText:SetPoint("BOTTOMRIGHT", forces, "TOPRIGHT", -3, 2)
    forcesText:SetJustifyH("RIGHT")
    forcesText:SetText(string.format(LText("Forces: %s"), "82.33%"))

    local function CreateObjective(y, completed, label)
        local row = CreateFrame("Frame", nil, root)
        row:SetSize(220, 16)
        row:SetPoint("TOPRIGHT", root, "TOPRIGHT", -pad, y)

        local objective = InstallerCreatePreviewLabel(row, 11, completed and 0 or textR, completed and 1 or textG, completed and 0.14 or textB, "OUTLINE")
        objective:SetPoint("RIGHT", row, "RIGHT", 0, 0)
        objective:SetWidth(190)
        objective:SetJustifyH("RIGHT")
        objective:SetWordWrap(false)
        objective:SetText(LText(label))

        if completed then
            local tick = row:CreateTexture(nil, "OVERLAY")
            tick:SetSize(12, 12)
            tick:SetPoint("RIGHT", objective, "LEFT", -3, 0)
            tick:SetTexture(readyTexture)
        end
    end

    CreateObjective(-123, true, string.format(LText("First Boss (%s)"), "03:20"))
    CreateObjective(-141, true, string.format(LText("Second Boss (%s)"), "06:40"))
    CreateObjective(-159, false, "( ) " .. LText("Third Boss"))

    return root
end
-- Cooldown Manager + Resource Bars as they stack on screen, built from the
-- profile's own numbers (KUICooldownManager.lua bar defaults,
-- KUIResourceBars.lua StackAbove, CastBar SnapToTop): from the top, the Buffs
-- bar (anchored 15px over the cast bar), the cast bar, the primary power bar,
-- the class resource pips, the Cooldowns row and the two Utility rows. Every
-- bar takes the Cooldowns row's width; icons keep their zoom, 1px black
-- border and 2px spacing, a few show a cooldown swipe with its countdown.
local INSTALLER_SECONDARY_PIPS = {
    ROGUE = { 5, "COMBO_POINTS" },
    PALADIN = { 5, "HOLY_POWER" },
    WARLOCK = { 5, "SOUL_SHARDS" },
    EVOKER = { 5, "ESSENCE" },
    DEATHKNIGHT = { 6, "RUNES" },
}
local INSTALLER_SPEC_SECONDARY_PIPS = {
    [103] = { 5, "COMBO_POINTS" }, -- Feral
    [269] = { 5, "CHI" },          -- Windwalker
    [62] = { 4, "ARCANE_CHARGES" }, -- Arcane
}
local INSTALLER_RUNE_COLORS = { [250] = { 0.85, 0.15, 0.20 }, [251] = { 0.25, 0.65, 1.0 }, [252] = { 0.35, 0.85, 0.25 } }

local function InstallerCDMBarConfig(key, fallback)
    local cdm = KT.db and KT.db.profile and KT.db.profile.cooldownManager
    local bars = cdm and cdm.cdmBars and cdm.cdmBars.bars
    if type(bars) == "table" then
        for _, bar in ipairs(bars) do
            if bar.key == key then
                return setmetatable({}, { __index = function(_, field)
                    local value = bar[field]
                    if value == nil then value = fallback[field] end
                    return value
                end })
            end
        end
    end
    return fallback
end

local function InstallerStatusBarTexture(name, fallback)
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    local path = LSM and name and LSM:Fetch("statusbar", name, true)
    return path or fallback or INSTALLER_MELLI_TEXTURE
end

local function CreateCooldownManagerInstallerLivePreview(parent)
    local classSpells, localizedClass, specName, specIcon, classColor, specID, classToken =
        GetInstallerPlayerClassPreviewData()
    local font = GetKTFont()

    local cdBar = InstallerCDMBarConfig("cooldowns", { iconSize = 42, spacing = 2, borderSize = 1, iconZoom = 0.08, cooldownFontSize = 12, numRows = 1 })
    local utBar = InstallerCDMBarConfig("utility", { iconSize = 28, spacing = 2, borderSize = 1, iconZoom = 0.08, cooldownFontSize = 12, numRows = 2, anchorOffsetY = -2 })
    local bfBar = InstallerCDMBarConfig("buffs", { iconSize = 32, spacing = 2, borderSize = 1, iconZoom = 0.08, cooldownFontSize = 12, numRows = 1, anchorOffsetY = 15 })

    local rb = KT.db and KT.db.profile and KT.db.profile.resourceBars or {}
    local rbGeneral, rbPrimary, rbSecondary = rb.general or {}, rb.primary or {}, rb.secondary or {}
    local gap = rbGeneral.anchorGap or 4
    local castDB = KT.db and KT.db.profile and KT.db.profile.castbar or {}

    local cooldownIDs = GetInstallerSpecPreviewSpellIDs({ 0 }, { "EssentialCooldownViewer" }, classSpells.cooldowns, 7)
    local utilityIDs = GetInstallerSpecPreviewSpellIDs({ 1 }, { "UtilityCooldownViewer" }, classSpells.utility, 6)
    local buffIDs = GetInstallerSpecPreviewSpellIDs({ 2, 3 }, { "BuffIconCooldownViewer", "BuffBarCooldownViewer" }, classSpells.buffs, 4)
    MoveInstallerInterruptToUtility(cooldownIDs, utilityIDs, specID, classToken)

    local function RowWidth(count, size, spacing)
        return count * size + math.max(0, count - 1) * spacing
    end
    local cdCount = math.max(1, math.min(#cooldownIDs, 7))
    local width = RowWidth(cdCount, cdBar.iconSize, cdBar.spacing)

    -- Natural height of the stack, top to bottom.
    local castH = castDB.height or 20
    local primaryH = rbPrimary.height or 25
    local pipInfo = INSTALLER_SPEC_SECONDARY_PIPS[specID] or INSTALLER_SECONDARY_PIPS[classToken]
    local showPrimary = rbPrimary.enabled ~= false and rb.enabled ~= false
    local showPips = pipInfo and rbSecondary.enabled ~= false and rb.enabled ~= false
    local pipH = rbSecondary.pipHeight or 14
    local utRows = math.max(1, utBar.numRows or 2)
    local utPerRow = math.ceil(math.min(#utilityIDs, 6) / utRows)
    local height = bfBar.iconSize + (bfBar.anchorOffsetY or 15) + castH + 5
        + (showPrimary and (primaryH + gap) or 0) + (showPips and (pipH + gap) or 0)
        + cdBar.iconSize + math.abs(utBar.anchorOffsetY or 2)
        + utRows * utBar.iconSize + (utRows - 1) * utBar.spacing

    local root = CreateFrame("Frame", nil, parent)
    root:SetSize(math.max(width, castH + 200), height)
    -- Leave the bottom 52px for the Import button the step puts there.
    local availW, availH = (parent:GetWidth() or 700) - 40, (parent:GetHeight() or 262) - 70
    root:SetScale(math.min(1, availW / root:GetWidth(), availH / height))
    root:SetPoint("TOP", parent, "TOP", 0, -12 / root:GetScale())

    local function Icon(size, spellID, zoom, borderSize, countdown, fontSize)
        local f = CreateFrame("Frame", nil, root)
        f:SetSize(size, size)
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.08, 0.08, 0.08, 0.6)
        local tex = f:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", borderSize, -borderSize)
        tex:SetPoint("BOTTOMRIGHT", -borderSize, borderSize)
        tex:SetTexture(GetInstallerSpellTexture(spellID, specIcon))
        tex:SetTexCoord(zoom, 1 - zoom, zoom, 1 - zoom)
        for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
                                { "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
            local edge = f:CreateTexture(nil, "OVERLAY", nil, 7)
            edge:SetColorTexture(0, 0, 0, 1)
            edge:SetPoint(side[1])
            edge:SetPoint(side[2])
            if side[3] then edge:SetHeight(borderSize) else edge:SetWidth(borderSize) end
        end
        if countdown then
            local swipe = f:CreateTexture(nil, "ARTWORK", nil, 3)
            swipe:SetPoint("TOPLEFT", tex, "TOPLEFT")
            swipe:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT")
            swipe:SetColorTexture(0, 0, 0, 0.7)
            local cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
            cd:SetAllPoints(tex)
            if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
            if cd.SetDrawEdge then cd:SetDrawEdge(false) end
            if cd.SetSwipeColor then cd:SetSwipeColor(0, 0, 0, 0.7) end
            -- A radial swipe held still at its remaining share (the countdown
            -- text does not tick either); the flat dark layer stays when the
            -- client cannot pause a Cooldown frame.
            if cd.SetCooldown and cd.Pause then
                cd:SetCooldown(GetTime() - (countdown * 0.4), countdown * 1.4)
                cd:Pause()
                swipe:Hide()
            else
                cd:Hide()
            end
            local text = f:CreateFontString(nil, "OVERLAY")
            text:SetFont(font, fontSize, "OUTLINE")
            text:SetPoint("CENTER")
            text:SetTextColor(1, 1, 1, 1)
            text:SetText(tostring(countdown))
        end
        return f
    end

    local function Row(ids, count, conf, y, countdowns)
        local rowW = RowWidth(count, conf.iconSize, conf.spacing)
        for index = 1, count do
            local icon = Icon(conf.iconSize, ids[index], conf.iconZoom or 0.08, conf.borderSize or 1,
                countdowns and countdowns[index], conf.cooldownFontSize or 12)
            icon:SetPoint("TOPLEFT", root, "TOP", -rowW / 2 + (index - 1) * (conf.iconSize + conf.spacing), -y)
        end
    end

    local function Bar(y, h, texture, r, g, b, value, border)
        local bar = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
        bar:SetSize(width, h)
        bar:SetPoint("TOP", root, "TOP", 0, -y)
        bar:SetStatusBarTexture(texture)
        bar:SetStatusBarColor(r, g, b, 1)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(value)
        bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = border or 1 })
        bar:SetBackdropColor(0, 0, 0, rbGeneral.bgA or 0.8)
        bar:SetBackdropBorderColor(0, 0, 0, 1)
        return bar
    end

    local y = 0
    -- Buffs bar.
    Row(buffIDs, math.min(#buffIDs, 4), bfBar, y)
    y = y + bfBar.iconSize + (bfBar.anchorOffsetY or 15)

    -- Cast bar: theme accent, spell icon on the left, name and timer.
    local castColor = castDB.color
    local cr, cg, cb = KT_COLOR[1], KT_COLOR[2], KT_COLOR[3]
    if castDB.colorMode == "CUSTOM" and type(castColor) == "table" then cr, cg, cb = castColor.r or cr, castColor.g or cg, castColor.b or cb end
    if castDB.classColor or castDB.colorMode == "CLASS" then cr, cg, cb = classColor[1], classColor[2], classColor[3] end
    local cast = Bar(y, castH, InstallerStatusBarTexture(castDB.texture, INSTALLER_MELLI_TEXTURE), cr, cg, cb, 62)
    if castDB.showIcon ~= false then
        cast:SetWidth(width - castH)
        cast:ClearAllPoints()
        cast:SetPoint("TOPRIGHT", root, "TOP", width / 2, -y)
        local castIcon = cast:CreateTexture(nil, "ARTWORK")
        castIcon:SetSize(castH, castH)
        castIcon:SetPoint("RIGHT", cast, "LEFT", 0, 0)
        castIcon:SetTexture(GetInstallerSpellTexture(cooldownIDs[1], specIcon))
        castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    local castName = cast:CreateFontString(nil, "OVERLAY")
    castName:SetFont(font, math.min(castDB.fontSize or 16, castH - 4), castDB.fontOutline or "OUTLINE")
    castName:SetPoint("LEFT", 4, 0)
    castName:SetText(GetSpellInfo and GetSpellInfo(cooldownIDs[1]) or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(cooldownIDs[1])) or "")
    local castTime = cast:CreateFontString(nil, "OVERLAY")
    castTime:SetFont(font, math.min(castDB.fontSize or 16, castH - 4), castDB.fontOutline or "OUTLINE")
    castTime:SetPoint("RIGHT", -4, 0)
    castTime:SetText("1.2")
    y = y + castH + 5

    -- Primary power bar, value text in the middle (curpp).
    if showPrimary then
        local _, _, powerColor = GetInstallerPlayerPowerPreview(specID, classToken)
        local primary = Bar(y, primaryH, InstallerStatusBarTexture(rbPrimary.texture, INSTALLER_MELLI_TEXTURE),
            powerColor[1], powerColor[2], powerColor[3], 64, rbPrimary.borderSize)
        local value = primary:CreateFontString(nil, "OVERLAY")
        value:SetFont(font, rbPrimary.textSize or 13, "OUTLINE")
        value:SetPoint("CENTER")
        local fmt = rbPrimary.textFormat or "curpp"
        value:SetText(fmt == "perpp" and "64%" or fmt == "both" and "64 - 64%" or fmt == "none" and "" or "64")
        y = y + primaryH + gap
    end

    -- Class resource pips (combo points, holy power, runes...).
    if showPips then
        local count, token = pipInfo[1], pipInfo[2]
        local color = _G.PowerBarColor and _G.PowerBarColor[token]
        local pr, pg, pb = color and color.r or 0.95, color and color.g or 0.9, color and color.b or 0.6
        if token == "RUNES" and INSTALLER_RUNE_COLORS[specID] then
            pr, pg, pb = unpack(INSTALLER_RUNE_COLORS[specID])
        end
        local spacing = rbSecondary.pipSpacing or 2
        local pipW = (width - (count - 1) * spacing) / count
        local texture = InstallerStatusBarTexture(rbSecondary.texture, INSTALLER_MELLI_TEXTURE)
        for index = 1, count do
            local pip = CreateFrame("Frame", nil, root, "BackdropTemplate")
            pip:SetSize(pipW, pipH)
            pip:SetPoint("TOPLEFT", root, "TOP", -width / 2 + (index - 1) * (pipW + spacing), -y)
            pip:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = rbSecondary.borderSize or 1 })
            pip:SetBackdropColor(0, 0, 0, rbGeneral.bgA or 0.8)
            pip:SetBackdropBorderColor(0, 0, 0, 1)
            if index <= math.ceil(count * 0.6) then
                local fill = pip:CreateTexture(nil, "ARTWORK")
                fill:SetPoint("TOPLEFT", 1, -1)
                fill:SetPoint("BOTTOMRIGHT", -1, 1)
                fill:SetTexture(texture)
                fill:SetVertexColor(pr, pg, pb, 1)
            end
        end
        y = y + pipH + gap
    end

    -- Cooldowns row: the first icons on cooldown with their countdown.
    Row(cooldownIDs, cdCount, cdBar, y, { [2] = 8, [4] = 24, [6] = 51 })
    y = y + cdBar.iconSize + math.abs(utBar.anchorOffsetY or 2)

    -- Utility rows, centred under the Cooldowns row.
    for row = 1, utRows do
        local ids = {}
        for index = (row - 1) * utPerRow + 1, math.min(row * utPerRow, #utilityIDs) do ids[#ids + 1] = utilityIDs[index] end
        if #ids > 0 then
            Row(ids, #ids, utBar, y, row == 1 and { [1] = 12 } or nil)
        end
        y = y + utBar.iconSize + utBar.spacing
    end

    return root
end

local function CreateInstallerPreviewUnavailable(parent, label)
    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints()
    local text = InstallerCreatePreviewLabel(root, 14, 0.82, 0.82, 0.86, "OUTLINE")
    text:SetPoint("CENTER")
    text:SetText(LText(label))
    return root
end

-- styleKey: the Visual Style to draw (the one chosen in the step, which may
-- not be applied yet); later refreshes keep drawing it.
local function CreateUnitFramesInstallerLivePreview(parent, styleKey)
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "KullThranUI_UnitFrames")
    end
    local api = _G.KullThranUI_UnitFramesOptions
    local themes = KT.VisualThemes
    if api and api.CreateLivePreview then
        local options = { attachSticky = false, width = parent:GetWidth() - 20, x = 10, y = 10 }
        local preview
        if styleKey and themes and themes.WithPreviewProfile then
            -- Draw with the chosen style's own unit frame settings, not KUI's.
            preview = themes:WithPreviewProfile("unitframes", styleKey, api.CreateLivePreview, parent, options)
            if preview and preview.Refresh then
                local refresh = preview.Refresh
                preview.Refresh = function(...) return themes:WithPreviewProfile("unitframes", styleKey, refresh, ...) end
            end
        else
            local ok, created = pcall(api.CreateLivePreview, parent, options)
            preview = ok and created or nil
        end
        if preview then return preview end
    end
    return CreateInstallerPreviewUnavailable(parent, "KullThranUI Unit Frames preview unavailable")
end

-- Runs fn with the Party Frames settings of `styleKey` (VisualThemes:WithPreviewProfile).
-- The module keeps its own reference to its profile, so it is pointed at the
-- same copy for the call and put back afterwards.
local function WithPartyFramesStyle(styleKey, fn, ...)
    local themes = KT.VisualThemes
    if not (styleKey and themes and themes.WithPreviewProfile) then
        local results = { pcall(fn, ...) }
        if not results[1] then return nil end
        return unpack(results, 2)
    end
    local partyMod = KT:GetModule("PartyFrames", true)
    return themes:WithPreviewProfile("partyframes", styleKey, function(...)
        local real = partyMod and partyMod.db
        if partyMod then partyMod.db = KT.db.profile.partyFrames end
        local results = { pcall(fn, ...) }
        if partyMod then partyMod.db = real end
        if not results[1] then error(results[2], 0) end
        return unpack(results, 2)
    end, ...)
end

-- styleKey: the Visual Style to draw (the one chosen in the installer, which
-- may not be applied yet); later refreshes keep drawing it.
local function CreatePartyFramesInstallerLivePreview(parent, styleKey)
    local showPlayer = false
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "KullThranUI_PartyFrames")
    end
    local api = _G.KullThranUI_PartyFramesOptions
    if api and api.CreateLivePreview then
        local function CreateInStyle(...)
            local preview = WithPartyFramesStyle(styleKey, api.CreateLivePreview, ...)
            if preview and preview.Refresh and styleKey then
                local refresh = preview.Refresh
                preview.Refresh = function(...) return WithPartyFramesStyle(styleKey, refresh, ...) end
            end
            return preview ~= nil, preview
        end
        local root = CreateFrame("Frame", nil, parent)
        root:SetAllPoints()

        local verticalButton = CreateFrame("Button", nil, root, "BackdropTemplate")
        verticalButton:SetSize(130, 24)
        verticalButton:SetPoint("TOP", root, "TOP", -70, -5)
        verticalButton:SetText(LText("Vertical"))
        SkinButton(verticalButton)

        local horizontalButton = CreateFrame("Button", nil, root, "BackdropTemplate")
        horizontalButton:SetSize(130, 24)
        horizontalButton:SetPoint("LEFT", verticalButton, "RIGHT", 10, 0)
        horizontalButton:SetText(LText("Horizontal"))
        SkinButton(horizontalButton)

        local okVertical, verticalPreview = CreateInStyle(root, 38, {
            styleOverride = styleKey,
            attachSticky = false,
            registerGlobal = false,
            controls = false,
            keepTestButtons = true,
            modeOverride = "party",
            countOverride = 4,
            directionOverride = "VERTICAL",
            frameWidthOverride = 235,
            frameHeightOverride = 41,
            frameSpacingOverride = 10,
            frameScaleOverride = 1,
            allowUpscale = false,
            width = parent:GetWidth() - 20,
            height = parent:GetHeight() - 48,
            x = 10,
        })
        local okHorizontal, horizontalPreview = CreateInStyle(root, 38, {
            styleOverride = styleKey,
            attachSticky = false,
            registerGlobal = false,
            controls = false,
            keepTestButtons = true,
            modeOverride = "party",
            countOverride = 5,
            directionOverride = "HORIZONTAL",
            frameWidthOverride = 138,
            -- The Heal layout has no portrait; the profile's circular one is
            -- sized to the 93 px frame height and swamps the row.
            cfgOverride = { showPortrait = false, portraitStyle = "none" },
            frameHeightOverride = 93,
            frameSpacingOverride = 1,
            frameScaleOverride = 1,
            allowUpscale = false,
            width = parent:GetWidth() - 20,
            height = parent:GetHeight() - 48,
            x = 10,
        })

        local function GroupInstallerTestControls(preview, vertical)
            if not preview then return end

            local testButtons = {
                preview.partyBtn,
                preview.raidBtn,
                preview.raid40Btn,
            }
            if not (testButtons[1] and testButtons[2] and testButtons[3]) then
                return
            end

            if preview.canvas then
                -- The vertical column is centred in the whole box (the canvas
                -- keeps the same margin on both sides of the test buttons);
                -- the horizontal row needs the full width right of them.
                preview.canvas:ClearAllPoints()
                preview.canvas:SetPoint("TOPLEFT", preview, "TOPLEFT", 142, -34)
                preview.canvas:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", vertical and -142 or -12, 12)
                if preview.Refresh then pcall(preview.Refresh, preview) end
            end

            local controlBar = CreateFrame("Frame", nil, preview, "BackdropTemplate")
            controlBar:SetSize(122, 96)
            controlBar:SetPoint("LEFT", preview, "LEFT", 8, -4)
            controlBar:SetFrameLevel((preview:GetFrameLevel() or 1) + 1)
            CreateBackdrop(controlBar)
            controlBar:SetBackdropColor(0.018, 0.018, 0.024, 0.96)
            controlBar:SetBackdropBorderColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 0.48)

            for index, button in ipairs(testButtons) do
                button:ClearAllPoints()
                button:SetSize(106, 24)
                button:SetFrameLevel(controlBar:GetFrameLevel() + 1)
                button:Show()
                if index == 1 then
                    button:SetPoint("TOP", controlBar, "TOP", 0, -6)
                else
                    button:SetPoint("TOP", testButtons[index - 1], "BOTTOM", 0, -6)
                end
            end

            if preview.stopBtn then preview.stopBtn:Hide() end
            if preview.scaleDown then preview.scaleDown:Hide() end
            if preview.scaleUp then preview.scaleUp:Hide() end
            preview.installerTestControlBar = controlBar
        end
        if okVertical and verticalPreview and okHorizontal and horizontalPreview then
            GroupInstallerTestControls(verticalPreview, true)
            GroupInstallerTestControls(horizontalPreview, false)

            local function SetPreviewDirection(direction)
                local vertical = direction == "VERTICAL"
                verticalPreview:SetShown(vertical)
                horizontalPreview:SetShown(not vertical)
                verticalButton:SetBackdropBorderColor(unpack(vertical and KT_COLOR or COLOR_BORDER))
                horizontalButton:SetBackdropBorderColor(unpack(vertical and COLOR_BORDER or KT_COLOR))
            end
            -- The direction is a real choice: it applies the matching Party
            -- Frames layout (vertical DPS/Tank, horizontal Heal) so the Party /
            -- Raid tests show it too, and pins it to the current spec so the
            -- spec auto-switch does not undo it on the next login.
            local partyMod = KT:GetModule("PartyFrames", true)
            local function ChooseDirection(direction)
                SetPreviewDirection(direction)
                if not (partyMod and partyMod.ApplyPreset) then return end
                local presetKey = direction == "HORIZONTAL" and "heal" or "dps_tank"
                partyMod:ApplyPreset(presetKey)
                local spec = partyMod.GetCurrentSpecInfo and partyMod:GetCurrentSpecInfo()
                if spec and partyMod.SetSpecProfileAssignment then
                    partyMod:SetSpecProfileAssignment(spec.id, presetKey)
                end
                for _, shown in ipairs({ verticalPreview, horizontalPreview }) do
                    if shown.Refresh then pcall(shown.Refresh, shown) end
                end
            end
            verticalButton:SetScript("OnClick", function() ChooseDirection("VERTICAL") end)
            horizontalButton:SetScript("OnClick", function() ChooseDirection("HORIZONTAL") end)
            local activePreset = partyMod and partyMod.db and partyMod.db.activePreset
            SetPreviewDirection(activePreset == "heal" and "HORIZONTAL" or "VERTICAL")
            return root
        end
        root:Hide()
    end
    return CreateInstallerPreviewUnavailable(parent, "KullThranUI Party Frames preview unavailable")
end

local function CreateNameplatesInstallerPreview(parent, styleKey)
    local accentR, accentG, accentB = GetInstallerPreviewAccentRGB()
    local textR, textG, textB = GetInstallerPreviewTextRGB()
    local mutedR, mutedG, mutedB = GetInstallerPreviewMutedRGB()
    local root = CreateFrame("Frame", nil, parent)
    root:SetPoint("TOPLEFT", 20, -12)
    root:SetPoint("BOTTOMRIGHT", -20, 12)

    -- The look of the chosen style, taken from the same seed the options use.
    local validStyles = { kui = "KUI", forever = "Forever", retail = "Retail", classic = "Classic" }
    styleKey = validStyles[styleKey or ""] and styleKey or nil
    if not styleKey then
        local stored = (_G.KullThranUINameplatesDB or {}).nameplateStyle
        local themes = KT.VisualThemes
        local rendered = themes and themes.GetRenderedTheme and themes:GetRenderedTheme()
        styleKey = validStyles[stored or ""] and stored or (validStyles[rendered or ""] and rendered or "kui")
    end
    -- The real plate of the chosen style (layout, sizes, art, cast bar, auras),
    -- drawn by the Nameplates module itself. The drawing below is only the
    -- fallback for when that module cannot load.
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "KullThranUI_Nameplates") end
    local plateApi = _G.KullThranUI_NameplatesOptions
    if plateApi and plateApi.BuildStyleSample then
        local spell = _G.C_Spell and _G.C_Spell.GetSpellName and _G.C_Spell.GetSpellName(686)
        local ok, sample = pcall(plateApi.BuildStyleSample, root, styleKey, {
            name = LText("Enemy"), level = (UnitLevel and UnitLevel("player")) or 80,
            icon = GetInstallerSpellTexture(686, 136197), spell = spell or "",
        })
        if ok and sample and (sample:GetWidth() or 0) > 0 and (sample:GetHeight() or 0) > 0 then
            local areaW, areaH = (parent:GetWidth() or 700) - 80, (parent:GetHeight() or 282) - 70
            local scale = math.min(2.4, areaW / sample:GetWidth(), areaH / sample:GetHeight())
            sample:SetScale(scale)
            sample:ClearAllPoints()
            -- offsets are in the sample's own (scaled) units
            sample:SetPoint("CENTER", root, "CENTER", 0, 12 / scale)
            local tag = InstallerCreatePreviewLabel(root, 10, accentR, accentG, accentB, "OUTLINE")
            tag:SetPoint("BOTTOM", root, "BOTTOM", 0, 4)
            tag:SetText(string.format(LText("Nameplate style: %s"), LText(validStyles[styleKey])))
            return root
        elseif ok and sample then
            sample:Hide()
        end
    end

    local seeded = {}
    local nameplateAdapter = KT.VisualThemes and KT.VisualThemes.GetModuleAdapter and KT.VisualThemes:GetModuleAdapter("nameplates")
    if nameplateAdapter and nameplateAdapter.seed then pcall(nameplateAdapter.seed, seeded, styleKey) end
    local barTexture = INSTALLER_MELLI_TEXTURE
    local sharedMedia = LibStub and LibStub("LibSharedMedia-3.0", true)
    if sharedMedia and seeded.healthBarTexture then
        local fetched = sharedMedia:Fetch("statusbar", seeded.healthBarTexture, true)
        if fetched then barTexture = fetched end
    end
    local border = seeded.borderColor
    local borderR = border and border.r or accentR
    local borderG = border and border.g or accentG
    local borderB = border and border.b or accentB
    local borderAlpha = seeded.borderStyle == "none" and 0 or 0.95
    local fill = seeded.enemyInCombat or seeded.hostile or { r = 0.80, g = 0.137, b = 0.137 }
    local barHeight = 30

    -- A nameplate preview must describe the enemy, not the player's class or
    -- cooldown loadout. These are four distinct, well-known debuffs whose
    -- textures remain useful even when the client has not cached spell data.
    local debuffData = {
        { spellID = 55095, fallback = 136096, duration = "12" }, -- Frost Fever
        { spellID = 589,   fallback = 132152, duration = "8"  }, -- Shadow Word: Pain
        { spellID = 980,   fallback = 132123, duration = "6"  }, -- Agony
        { spellID = 772,   fallback = 132122, duration = "3"  }, -- Rend
    }
    local debuffSize = 32
    local debuffSpacing = 4
    local totalDebuffWidth = (#debuffData * debuffSize) + ((#debuffData - 1) * debuffSpacing)
    for index, data in ipairs(debuffData) do
        local texture = GetInstallerSpellTexture(data.spellID, data.fallback)
        local icon = CreateInstallerPreviewIcon(root, debuffSize, texture, data.duration)
        icon:SetPoint(
            "TOPLEFT",
            root,
            "TOP",
            -(totalDebuffWidth / 2) + ((index - 1) * (debuffSize + debuffSpacing)),
            -63
        )
        icon:SetBackdropBorderColor(0.78, 0.22, 0.18, 0.95)
    end

    local enemyName = InstallerCreatePreviewLabel(root, 14, textR, textG, textB, "OUTLINE")
    enemyName:SetPoint("TOP", root, "TOP", 0, -102)
    enemyName:SetWidth(330)
    enemyName:SetJustifyH("CENTER")
    enemyName:SetText(LText("Enemy"))

    local classification = InstallerCreatePreviewLabel(root, 9, mutedR, mutedG, mutedB, "OUTLINE")
    classification:SetPoint("TOP", root, "TOP", 0, -121)
    classification:SetWidth(330)
    classification:SetJustifyH("CENTER")
    classification:SetText(LText("Elite"))

    local health = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    health:SetSize(330, barHeight)
    health:SetPoint("TOP", root, "TOP", 0, -139)
    health:SetStatusBarTexture(barTexture)
    health:SetStatusBarColor(fill.r, fill.g, fill.b, 1)
    health:SetMinMaxValues(0, 100)
    health:SetValue(83)
    CreateBackdrop(health)
    health:SetBackdropColor(0.06, 0.06, 0.07, 0.98)
    health:SetBackdropBorderColor(borderR, borderG, borderB, borderAlpha)

    local hp = InstallerCreatePreviewLabel(health, 11, 1, 1, 1, "OUTLINE")
    hp:SetPoint("RIGHT", -7, 0)
    hp:SetText("83%")

    -- Crowd-control effects use the default right aura slot. Keep this
    -- separate from the debuff row so the preview explains both groups.
    local ccSpellID = 118 -- Polymorph
    local ccIcon = CreateInstallerPreviewIcon(root, 36, GetInstallerSpellTexture(ccSpellID, 136071), "5")
    ccIcon:SetPoint("LEFT", health, "RIGHT", 6, 0)
    ccIcon:SetBackdropBorderColor(0.30, 0.58, 0.95, 1)

    local castSpellID = 686 -- Shadow Bolt
    local castSpellName = "Shadow Bolt"
    if _G.C_Spell and _G.C_Spell.GetSpellName then
        local ok, name = pcall(_G.C_Spell.GetSpellName, castSpellID)
        if ok and name then castSpellName = name end
    elseif _G.C_Spell and _G.C_Spell.GetSpellInfo then
        local ok, info = pcall(_G.C_Spell.GetSpellInfo, castSpellID)
        if ok and info and info.name then castSpellName = info.name end
    end

    local cast = CreateFrame("StatusBar", nil, root, "BackdropTemplate")
    cast:SetSize(330, 18)
    cast:SetPoint("TOP", health, "BOTTOM", 0, -4)
    cast:SetStatusBarTexture(barTexture)
    cast:SetStatusBarColor(0.70, 0.40, 0.90, 1)
    cast:SetMinMaxValues(0, 100)
    cast:SetValue(72)
    CreateBackdrop(cast)
    cast:SetBackdropColor(0.04, 0.04, 0.05, 0.98)
    cast:SetBackdropBorderColor(0.12, 0.12, 0.14, 1)

    local castIcon = CreateInstallerPreviewIcon(cast, 18, GetInstallerSpellTexture(castSpellID, 136197))
    castIcon:SetPoint("RIGHT", cast, "LEFT", -3, 0)
    castIcon:SetBackdropBorderColor(0.70, 0.40, 0.90, 1)

    local castText = InstallerCreatePreviewLabel(cast, 9, 1, 1, 1, "OUTLINE")
    castText:SetPoint("LEFT", 6, 0)
    castText:SetPoint("RIGHT", -42, 0)
    castText:SetJustifyH("LEFT")
    castText:SetText(castSpellName)

    local castTime = InstallerCreatePreviewLabel(cast, 9, 1, 1, 1, "OUTLINE")
    castTime:SetPoint("RIGHT", -6, 0)
    castTime:SetText("1.4")

    local styleTag = InstallerCreatePreviewLabel(root, 10, accentR, accentG, accentB, "OUTLINE")
    styleTag:SetPoint("TOP", cast, "BOTTOM", 0, -10)
    styleTag:SetWidth(330)
    styleTag:SetJustifyH("CENTER")
    styleTag:SetText(string.format(LText("Nameplate style: %s"), LText(validStyles[styleKey])))

    return root
end
local function CreateResourceBarsInstallerLivePreview(parent)
    local accentR, accentG, accentB = GetInstallerPreviewAccentRGB()
    local textR, textG, textB = GetInstallerPreviewTextRGB()
    local mutedR, mutedG, mutedB = GetInstallerPreviewMutedRGB()
    local root = CreateFrame('Frame', nil, parent)
    root:SetPoint('TOPLEFT', 20, -16)
    root:SetPoint('BOTTOMRIGHT', -20, 16)

    local title = InstallerCreatePreviewLabel(root, 11, textR, textG, textB, 'OUTLINE')
    title:SetPoint('TOP', 0, -2)
    title:SetText(LText('Resource Bars'))

    local function AddBar(y, height, r, g, b, label, value)
        local bar = CreateFrame('StatusBar', nil, root, 'BackdropTemplate')
        bar:SetSize(430, height)
        bar:SetPoint('TOP', root, 'TOP', 0, y)
        bar:SetStatusBarTexture(INSTALLER_MELLI_TEXTURE)
        bar:SetStatusBarColor(r, g, b, 0.95)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(value)
        CreateBackdrop(bar)
        bar:SetBackdropColor(0.025, 0.025, 0.03, 0.96)
        bar:SetBackdropBorderColor(accentR, accentG, accentB, 0.85)

        local left = InstallerCreatePreviewLabel(bar, 10, mutedR, mutedG, mutedB, 'OUTLINE')
        left:SetPoint('LEFT', 8, 0)
        left:SetText(label)
        local right = InstallerCreatePreviewLabel(bar, 10, 1, 1, 1, 'OUTLINE')
        right:SetPoint('RIGHT', -8, 0)
        right:SetText(value .. '%')
    end

    AddBar(-48, 28, 0.10, 0.58, 1.00, LText('Primary Power'), 72)
    AddBar(-84, 18, 0.90, 0.74, 0.28, LText('Class Resource'), 46)
    AddBar(-112, 18, 0.20, 0.78, 0.32, LText('Health'), 88)
    return root
end

local function ShowInstallerModuleToggleStep(self, spec)
    L = KT:GetLocale()
    KT.db.profile.installer.step = spec.step
    self:UpdateProgressBar(spec.step)
    if self.content then self.content:Hide() end

    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(LText(spec.title))
    title:SetTextColor(unpack(KT_COLOR))

    local subtitle = content:CreateFontString(nil, "OVERLAY")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -10)
    subtitle:SetWidth(700)
    subtitle:SetFont(GetKTFont(), 14)
    subtitle:SetText(LText(spec.question))
    subtitle:SetTextColor(0.9, 0.9, 0.9)
    subtitle:SetJustifyH("CENTER")

    local infoAnchor = subtitle
    if spec.location then
        local location = content:CreateFontString(nil, "OVERLAY")
        location:SetPoint("TOP", subtitle, "BOTTOM", 0, -5)
        location:SetWidth(700)
        location:SetFont(GetKTFont(), 11, "OUTLINE")
        location:SetText(LText(spec.location))
        location:SetTextColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 1)
        location:SetJustifyH("CENTER")
        infoAnchor = location
    end

    local previewFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    previewFrame:SetSize(spec.previewWidth or 700, spec.previewHeight or 282)
    previewFrame:SetPoint("TOP", infoAnchor, "BOTTOM", 0, -12)
    previewFrame:SetClipsChildren(true)
    CreateBackdrop(previewFrame)
    previewFrame:SetBackdropColor(0.025, 0.025, 0.032, 0.94)
    local accentR, accentG, accentB = GetInstallerPreviewAccentRGB()
    previewFrame:SetBackdropBorderColor(accentR, accentG, accentB, 0.48)

    -- fitPreview: the box keeps one height and every preview (the first and
    -- each one rebuilt for another style, which may be taller) is scaled to fit
    -- inside it, so nothing is cut off at the bottom.
    if spec.fitPreview then
        previewFrame:SetHeight(spec.previewHeight or 236)
        previewFrame:ClearAllPoints()
        previewFrame:SetPoint("TOP", infoAnchor, "BOTTOM", 0, -50)
    end
    local function FitPreview(shown)
        if not (spec.fitPreview and shown and shown.GetHeight and shown.SetScale) then return end
        shown:SetScale(1)
        local height = shown:GetHeight() or 0
        local scale = height > 0 and math.min(1, (previewFrame:GetHeight() - 16) / height) or 1
        shown:SetScale(scale)
        shown:ClearAllPoints()
        shown:SetPoint("TOP", previewFrame, "TOP", 0, -8 / scale)
    end
    local preview = spec.createPreview(previewFrame, spec.styleRow and spec.styleRow.get() or nil)
    FitPreview(preview)

    local disabledOverlay = CreateFrame("Frame", nil, previewFrame, "BackdropTemplate")
    disabledOverlay:SetAllPoints()
    disabledOverlay:SetFrameLevel(previewFrame:GetFrameLevel() + 40)
    CreateBackdrop(disabledOverlay)
    disabledOverlay:SetBackdropColor(0.015, 0.015, 0.02, 0.72)
    disabledOverlay:SetBackdropBorderColor(accentR, accentG, accentB, 0.55)
    local disabledLabel = InstallerCreatePreviewLabel(disabledOverlay, 15, 1, 1, 1, "OUTLINE")
    disabledLabel:SetPoint("CENTER")
    disabledLabel:SetText(LText(spec.disabledPreviewLabel) or LText("Disabled"))

    local controlsFrame = CreateFrame("Frame", nil, content)
    controlsFrame:SetSize(600, 58)
    if spec.fitPreview then
        -- With a style row the state line sits above it (see below).
        controlsFrame:SetPoint("TOP", previewFrame, "BOTTOM", 0, spec.styleRow and -62 or -48)
    else
        controlsFrame:SetPoint("BOTTOM", content, "BOTTOM", 0, 82)
    end

    local stateText = controlsFrame:CreateFontString(nil, "OVERLAY")
    if spec.styleRow then
        -- Right under the preview, so it never sits on the style buttons.
        stateText:SetPoint("TOP", previewFrame, "BOTTOM", 0, -6)
    else
        stateText:SetPoint("BOTTOM", controlsFrame, "TOP", 0, 5)
    end
    stateText:SetFont(GetKTFont(), 14, "OUTLINE")

    if spec.styleRow then
        local themes = KT.VisualThemes
        local styleLabels = { kui = "KUI", forever = "Forever", retail = "Retail", classic = "Classic" }
        local styleKeys = {}
        for _, key in ipairs({ "kui", "forever", "retail", "classic" }) do
            if not (themes and themes.IsKnownTheme) or themes:IsKnownTheme(key) then
                styleKeys[#styleKeys + 1] = key
            end
        end
        local styleButtons = {}
        local function RefreshStyleButtons()
            local current = spec.styleRow.get()
            for _, styleButton in ipairs(styleButtons) do
                styleButton.KT_selected = (styleButton.styleKey == current)
                styleButton:SetBackdropBorderColor(unpack(styleButton.KT_selected and KT_COLOR or COLOR_BORDER))
            end
        end
        for index, key in ipairs(styleKeys) do
            local styleButton = CreateFrame("Button", nil, content, "BackdropTemplate")
            styleButton:SetSize(118, 26)
            styleButton:SetPoint("TOP", previewFrame, "BOTTOM", (index - (#styleKeys + 1) / 2) * 126, -28)
            styleButton:SetText(LText(styleLabels[key]))
            styleButton.styleKey = key
            SkinButton(styleButton)
            styleButton:HookScript("OnLeave", function(self)
                self:SetBackdropBorderColor(unpack(self.KT_selected and KT_COLOR or COLOR_BORDER))
            end)
            styleButton:SetScript("OnClick", function()
                spec.styleRow.set(key)
                RefreshStyleButtons()
                if spec.styleRow.rebuild then
                    if preview then preview:Hide() end
                    preview = spec.createPreview(previewFrame, key)
                    FitPreview(preview)
                    if preview then preview:SetAlpha(spec.get() and 1 or 0.34) end
                end
            end)
            styleButtons[#styleButtons + 1] = styleButton
        end
        RefreshStyleButtons()
    end

    local btnEnable = CreateFrame("Button", nil, controlsFrame, "BackdropTemplate")
    btnEnable:SetSize(286, 34)
    btnEnable:SetPoint("TOPLEFT", controlsFrame, "TOPLEFT", 0, -10)
    btnEnable:SetText(LText(spec.enableLabel))
    SkinButton(btnEnable)

    local btnDisable = CreateFrame("Button", nil, controlsFrame, "BackdropTemplate")
    btnDisable:SetSize(286, 34)
    btnDisable:SetPoint("LEFT", btnEnable, "RIGHT", 28, 0)
    btnDisable:SetText(LText(spec.disableLabel))
    SkinButton(btnDisable)

    local function RefreshState()
        local enabled = spec.get() and true or false
        stateText:SetText(enabled and L["Enabled"] or L["Disabled"])
        stateText:SetTextColor(enabled and KT_COLOR[1] or 0.72, enabled and KT_COLOR[2] or 0.72, enabled and KT_COLOR[3] or 0.76, 1)
        btnEnable:SetBackdropBorderColor(unpack(enabled and KT_COLOR or COLOR_BORDER))
        btnDisable:SetBackdropBorderColor(unpack(enabled and COLOR_BORDER or KT_COLOR))
        if preview then
            preview:SetAlpha(enabled and 1 or 0.34)
        end
        disabledOverlay:SetShown(not enabled)
    end

    local function SetEnabled(value)
        local newValue = value and true or false
        if (spec.get() and true or false) == newValue then
            RefreshState()
            return
        end
        spec.set(newValue)
        self.moduleSettingsDirty = true
        if spec.apply then
            spec.apply(newValue)
        end
        RefreshState()
        if spec.requiresReload then
            self:DeferReload(spec.step)
        end
    end

    btnEnable:SetScript("OnClick", function() SetEnabled(true) end)
    btnDisable:SetScript("OnClick", function() SetEnabled(false) end)
    RefreshState()

    if spec.createExtraControls then
        spec.createExtraControls(content, previewFrame, controlsFrame)
    end

    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", spec.next)

    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", spec.back)

    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)
    local chk = CreateSkipCheckbox(content, btnSkip)
    btnSkip:SetScript("OnClick", function()
        if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end
        self.frame:Hide()
    end)
end

-------------------------------------------------------------------------
-- MODULE LOGIC
-------------------------------------------------------------------------

function Mod:OnInitialize()
    if not KT.db.profile.installer then
        KT.db.profile.installer = { showOnLogin = true, step = 1 }
    end
    if not KT.db.profile.installer.step then KT.db.profile.installer.step = 1 end
    
    -- Keep the installer on its welcome step after version changes, but let
    -- the main launcher handle the auto-open changelog flow.
    local currentVersion = C_AddOns.GetAddOnMetadata("KullThranUI", "Version") or "0"
    local reopenStep = tonumber(KT.db.profile.installer.reopenStep) or tonumber(KT.db.profile.installer.resumeStep)
    if KT.db.profile.installer.lastVersion ~= currentVersion then
        if not KT.db.profile.installer.reopenOnReload
            and not KT.db.profile.installer.reopenStep
            and not KT.db.profile.installer.resumeStep
        then
            KT.db.profile.installer.step = 1
        end
        KT.db.profile.installer.lastVersion = currentVersion
    end
    if reopenStep then
        KT.db.profile.installer.step = reopenStep
    end

    -- Inicializar tabla de perfiles externos
    if not KT.ProfileStrings then KT.ProfileStrings = {} end
    
    self:RegisterChatCommand("installers", function()
        KT.db.profile.installer.step = 1
        self:CreateInstallerWindow()
    end)
    
    -- Define Popups globally
    StaticPopupDialogs["KT_INSTALLER_URL"] = {
        text = L["KT_INSTALLER_COPY_LINK"] or "Copy link (Ctrl+C):",
        button1 = L["KT_INSTALLER_CLOSE"] or "Close",
        hasEditBox = true,
        editBoxWidth = 350,
        OnShow = function(self, data)
            local editBox = self.editBox or self.EditBox
            editBox:SetFont(GetKTFont(), 12, "")
            editBox:SetText(data or "")
            editBox:HighlightText()
            editBox:SetFocus()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    
    StaticPopupDialogs["KT_INSTALLER_PROFILE"] = {
        text = L["KT_INSTALLER_PROFILE_CONFIRM"] or "Install profile for %s?\n|cffFF0000This will overwrite current settings.|r",
        button1 = L["KT_INSTALLER_INSTALL"] or "Install",
        button2 = L["KT_INSTALLER_CANCEL"] or "Cancel",
        OnAccept = function(self, data)
            if data and data.func then data.func() end
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    StaticPopupDialogs["KT_INSTALLER_RELOAD"] = {
        text = L["KT_INSTALLER_RELOAD_CONFIRM"] or "KullThranUI: UI reload is required to apply the changes.",
        button1 = L["KT_INSTALLER_RELOAD"] or "Reload",
        button2 = L["KT_INSTALLER_LATER"] or "Later",
        OnShow = function(self)
            self._ktInstallerReloadAccepted = nil
        end,
        OnAccept = function(self)
            local db = KT and KT.db and KT.db.profile and KT.db.profile.installer
            if db then
                local step = tonumber(db.reopenStep or db.resumeStep or db.step) or 1
                db.step = step
                if db.dontShowAgain == true then
                    db.reopenStep = nil
                    db.resumeStep = nil
                    db.reopenOnReload = nil
                    db.isOpen = false
                else
                    db.reopenStep = step
                    db.resumeStep = step
                    db.reopenOnReload = true
                    db.isOpen = true
                end
            end
            self._ktInstallerReloadAccepted = true
            ReloadUI()
        end,
        OnCancel = function()
            -- Keep the resume state. It is consumed only after the Installer
            -- has actually reopened the saved page.
        end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
    -- Keep every static popup (reload prompts, confirmations, copy boxes)
    -- above the installer window, which sits in the TOOLTIP strata.
    if not self._popupsAboveInstaller then
        self._popupsAboveInstaller = true
        local function RaisePopup(popup)
            local installerFrame = self.frame
            if not (popup and installerFrame and installerFrame:IsShown()) then return end
            if popup._ktBaseStrata == nil then
                popup._ktBaseStrata = popup:GetFrameStrata()
                if not popup._ktRestoreHooked then
                    popup._ktRestoreHooked = true
                    popup:HookScript("OnHide", function(shown)
                        if shown._ktBaseStrata then
                            shown:SetFrameStrata(shown._ktBaseStrata)
                            shown._ktBaseStrata = nil
                        end
                    end)
                end
            end
            popup:SetFrameStrata("TOOLTIP")
            popup:SetFrameLevel(installerFrame:GetFrameLevel() + 100)
            popup:Raise()
        end
        local function RaiseShownPopups()
            if StaticPopup_ForEachShownDialog then
                StaticPopup_ForEachShownDialog(RaisePopup)
                return
            end
            for index = 1, (STATICPOPUP_NUMDIALOGS or 4) do
                local popup = _G["StaticPopup" .. index]
                if popup and popup:IsShown() then RaisePopup(popup) end
            end
        end
        hooksecurefunc("StaticPopup_Show", function()
            RaiseShownPopups()
            C_Timer.After(0, RaiseShownPopups)
        end)

        -- Any reload requested while the installer is open (including the
        -- generic "settings changed" popups) brings the installer back on
        -- the same page afterwards.
        hooksecurefunc("ReloadUI", function()
            local installerDb = KT and KT.db and KT.db.profile and KT.db.profile.installer
            if not (installerDb and self.frame and self.frame:IsShown()) then return end
            -- Whatever the "Don't show again" box says, a reload done on purpose while
            -- the installer is open brings it back on the same page.
            if KT.db.global then
                KT.db.global.installerReloadResume = { step = tonumber(installerDb.step) or 1, time = time() }
            end
            if installerDb.dontShowAgain == true then return end
            if installerDb.reopenStep or installerDb.resumeStep then return end
            local step = tonumber(installerDb.step) or 1
            installerDb.step = step
            installerDb.reopenStep, installerDb.resumeStep = step, step
            installerDb.reopenOnReload, installerDb.isOpen = true, true
        end)
    end
end

function Mod:OnEnable()
    -- Reopen after a deliberate /reload (see the ReloadUI hook in OnInitialize).
    local resumeAttempts = 0
    local function ResumeAfterReload()
        resumeAttempts = resumeAttempts + 1
        local global = KT and KT.db and KT.db.global
        local resume = global and global.installerReloadResume
        if resume then
            global.installerReloadResume = nil
            local profileDb = KT.db.profile and KT.db.profile.installer
            if profileDb and type(resume.time) == "number" and (time() - resume.time) < 300 then
                profileDb.step = tonumber(resume.step) or 1
                profileDb.resumeStep = profileDb.step
                self:CreateInstallerWindow()
            end
            return
        end
        if resumeAttempts < 6 then C_Timer.After(1.5, ResumeAfterReload) end
    end
    C_Timer.After(1, ResumeAfterReload)

    local reopenAttempts = 0
    local function ReopenInstallerAfterReload()
        reopenAttempts = reopenAttempts + 1
        local db = KT and KT.db and KT.db.profile and KT.db.profile.installer
        if db and db.dontShowAgain ~= true and (db.reopenOnReload or db.reopenStep or db.resumeStep) then
            self:CreateInstallerWindow()
            return
        end
        if reopenAttempts < 5 then
            C_Timer.After(1, ReopenInstallerAfterReload)
        end
    end
    C_Timer.After(0, ReopenInstallerAfterReload)
    local currentVersion = C_AddOns.GetAddOnMetadata("KullThranUI", "Version") or "0"
    
    if not KT.db or not KT.db.profile then return end
    KT.db.profile.installer = KT.db.profile.installer or {}

    if KT.db.profile.installer.lastSeenVersion ~= currentVersion then
        KT.db.profile.installer.lastSeenVersion = currentVersion
        if KT.db.profile.installer.dontShowAgain ~= true then
            KT.db.profile.installer.showOnLogin = true
        end
    end

    if KT.db.profile.installer.skipInstallerAutoOpenVersion == currentVersion then
        KT.db.profile.installer.skipInstallerAutoOpenVersion = nil
        return
    end

    if KT.db.profile.installer.showOnLogin == false then
        return
    end

    local conflicts = self:CheckConflicts()
    local cdb = KT.db.profile.conflictDetector
    if conflicts and not (cdb and cdb.dontShowAgain) then
        KT.db.profile.installer.showOnLogin = KT.db.profile.installer.dontShowAgain ~= true
    end
end

-- Called right before a Visual Style change reloads the UI. Resume data is
-- created only while the Visual Style page is on screen and the player has
-- not chosen "Don't show again".
function Mod:PrepareStyleReload()
    local db = KT and KT.db and KT.db.profile and KT.db.profile.installer
    local content = self._themeStepContent
    if not db or db.dontShowAgain == true then return end
    if not (self.frame and self.frame:IsShown() and content and content:IsVisible()) then return end
    db.step = 3
    db.reopenStep, db.resumeStep, db.reopenOnReload, db.isOpen = 3, 3, true, true
end

function Mod:GetInstallerCharacterKey()
    if KT and KT.GetInstallerCharacterKey then
        return KT:GetInstallerCharacterKey()
    end
    return UnitGUID and UnitGUID("player") or nil
end

function Mod:IsInitialProfileChoicePending()
    local global = KT and KT.db and KT.db.global
    local pending = global and global.installerProfileChoicePendingByCharacter
    local characterKey = self:GetInstallerCharacterKey()
    return characterKey and pending and pending[characterKey] == true
end

function Mod:GetInitialProfileChoices()
    local profiles = {}
    if not (KT and KT.db and KT.db.GetProfiles) then
        return profiles
    end

    local currentProfile = KT.db:GetCurrentProfile()
    for _, profileName in ipairs(KT.db:GetProfiles({})) do
        if type(profileName) == "string" and profileName ~= "" and profileName ~= currentProfile then
            profiles[#profiles + 1] = profileName
        end
    end
    table.sort(profiles, function(left, right)
        return left:lower() < right:lower()
    end)
    return profiles
end

function Mod:CompleteInitialProfileChoice(profileName)
    if profileName and KT.db:GetCurrentProfile() ~= profileName then
        KT._installerProfileChoiceInProgress = true
        local ok, err = pcall(KT.db.SetProfile, KT.db, profileName)
        KT._installerProfileChoiceInProgress = nil
        if not ok then
            KT:Print(string.format(LText("Installer: could not apply profile '%s': %s"), tostring(profileName), tostring(err)))
            return false
        end
    end

    local characterKey = self:GetInstallerCharacterKey()
    local global = KT and KT.db and KT.db.global
    if global and characterKey then
        global.installerProfileChoicePendingByCharacter = global.installerProfileChoicePendingByCharacter or {}
        global.installerProfileChoiceByCharacter = global.installerProfileChoiceByCharacter or {}
        global.installerProfileChoicePendingByCharacter[characterKey] = nil
        global.installerProfileChoiceByCharacter[characterKey] = profileName or "defaults"
    end

    KT.db.profile.installer = KT.db.profile.installer or {}
    local db = KT.db.profile.installer
    db.showOnLogin = true
    db.step = 1
    db.isOpen = true
    db.forceOpenForCharacter = nil
    self:UpdateKTColor()
    return true
end

function Mod:ContinueAfterInitialProfileChoice()
    local conflicts = self:CheckConflicts()
    local conflictDb = KT.db.profile.conflictDetector
    if conflicts and not (conflictDb and conflictDb.dontShowAgain) then
        self.onlyConflicts = nil
        self:ShowConflictStep(conflicts)
        return
    end
    self:ShowWelcomeStep()
end

function Mod:ShowInitialProfileStep(profiles)
    L = KT:GetLocale()
    if self.content then self.content:Hide() end
    if self.progressBar then self.progressBar:Hide() end

    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -42)
    title:SetFont(GetKTFont(), 26, "OUTLINE")
    title:SetText(LText("Choose a starting profile"))
    title:SetTextColor(unpack(KT_COLOR))

    local description = content:CreateFontString(nil, "OVERLAY")
    description:SetPoint("TOP", title, "BOTTOM", 0, -12)
    description:SetWidth(620)
    description:SetFont(GetKTFont(), 14)
    description:SetText(L["Choose saved settings for this character, or start from KUI defaults."]
        or "Choose saved settings for this character, or start from KUI defaults.")
    description:SetTextColor(0.9, 0.9, 0.9)
    description:SetJustifyH("CENTER")

    local defaultButton = CreateFrame("Button", nil, content, "BackdropTemplate")
    defaultButton:SetSize(500, 38)
    defaultButton:SetPoint("TOP", description, "BOTTOM", 0, -24)
    defaultButton:SetText(LText("Use KUI defaults"))
    SkinButton(defaultButton)
    defaultButton:SetScript("OnClick", function()
        if self:CompleteInitialProfileChoice(nil) then
            self:ContinueAfterInitialProfileChoice()
        end
    end)

    local savedTitle = content:CreateFontString(nil, "OVERLAY")
    savedTitle:SetPoint("TOPLEFT", defaultButton, "BOTTOMLEFT", 0, -22)
    savedTitle:SetFont(GetKTFont(), 15, "OUTLINE")
    savedTitle:SetText(LText("Saved profiles"))
    savedTitle:SetTextColor(unpack(KT_COLOR))

    local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", savedTitle, "BOTTOMLEFT", 0, -10)
    scroll:SetSize(522, 285)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(500, math.max(1, #profiles * 44))
    scroll:SetScrollChild(child)

    for index, profileName in ipairs(profiles) do
        local button = CreateFrame("Button", nil, child, "BackdropTemplate")
        button:SetSize(500, 36)
        button:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -((index - 1) * 44))
        button:SetText(profileName)
        SkinButton(button)
        button:SetScript("OnClick", function()
            if self:CompleteInitialProfileChoice(profileName) then
                self:ContinueAfterInitialProfileChoice()
            end
        end)
    end
end
function Mod:OpenCurrentStep()
    local db = KT.db and KT.db.profile and KT.db.profile.installer
    local resumeStep = tonumber(db and (db.reopenStep or db.resumeStep))
    local step = resumeStep or tonumber(db and db.step) or 1
    if db then
        db.step = step
        -- Resume data is only for the next installer open. Clear it after it
        -- has selected the page so later manual opens use the current page.
        if resumeStep then
            db.reopenStep = nil
            db.resumeStep = nil
            db.reopenOnReload = nil
        end
    end
    if step == 1 then self:ShowWelcomeStep()
    elseif step == 2 then self:ShowLanguageStep()
    elseif step == 3 then self:ShowThemeStep()
    elseif step == 4 then self:ShowGlobalFontStep()
    elseif step == 5 then self:ShowSkinStep()
    elseif step == 6 then self:ShowButtonStyleStep()
    elseif step == 7 then self:ShowMinimapShapeStep()
    elseif step == 8 then self:ShowCursorStep()
    elseif step == 9 then self:ShowEnhancedFriendListStep()
    elseif step == 10 then self:ShowBagsStep()
    elseif step == 11 then self:ShowDamageMeterStep()
    elseif step == 12 then self:ShowMythicPlusTimerStep()
    elseif step == 13 then self:ShowUnitFramesStep()
    elseif step == 14 then self:ShowPartyFramesStep()
    elseif step == 15 then self:ShowCooldownManagerStep()
    elseif step == 16 then self:ShowCooldownManagerStep()
    elseif step == 17 then self:ShowNameplatesStep()
    elseif step == 18 then self:ShowAddonListStep()
    elseif step == 19 then self:ShowProfileStep()
    elseif step == 30 then self:ShowAccessStep()
    elseif step == 20 then self:ShowModuleSelectionStep()
    else self:ShowWelcomeStep() end
end

-------------------------------------------------------------------------
-- WINDOW SHELL (look ported from a Uiverse CSS card: rounded panel, inset
-- accent frame that turns in from 10 degrees, spaced caption on the frame)
-------------------------------------------------------------------------
local INSTALLER_WINDOW_PATH = KUI_TEXTURE_PATH .. "InstallerWindow\\"
local SHELL_BORDER_INSET = 15
local SHELL_BORDER_TILT = math.rad(10)
local SHELL_OPEN_DURATION = 0.5
local SHELL_CAPTION_DELAY = 0.2
local SHELL_CAPTION_SIZE = 10

local function ShellEase(p)
    return p * p * (3 - 2 * p)
end

-- FontStrings have no letter spacing, so each letter is its own FontString
-- and SetSpacing re-lays them out centred on the holder.
local function CreateShellSpacedText(parent, text, size)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(1, size + 4)
    holder.letters = {}
    for char in tostring(text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local fs = holder:CreateFontString(nil, "OVERLAY")
        fs:SetFont(GetKTFont(), size, "")
        fs:SetText(char)
        holder.letters[#holder.letters + 1] = fs
    end
    function holder:SetSpacing(spacing)
        local total = 0
        for i, fs in ipairs(self.letters) do
            total = total + fs:GetStringWidth() + (i > 1 and spacing or 0)
        end
        local x = -total / 2
        for _, fs in ipairs(self.letters) do
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", self, "CENTER", x, 0)
            x = x + fs:GetStringWidth() + spacing
        end
        self.textWidth = total
    end
    function holder:SetTextColor(r, g, b, a)
        for _, fs in ipairs(self.letters) do
            fs:SetTextColor(r, g, b, a or 1)
        end
    end
    holder:SetSpacing(0)
    return holder
end

-- Painted canvas in the options window's "Forja" style (built with
-- tools/photoshop/Build-InstallerSkin.ps1): base (never tinted), light
-- (tinted with the accent) and a pulsing glow. Each layer is 960x760 with
-- the 800x600 window centred, so the shadow can spill past the edge.
local SHELL_CANVAS_W, SHELL_CANVAS_H = 960, 760
local SHELL_GLOW_PERIOD = 4
local SHELL_GLOW_MIN = 0.6
-- Plate colour under the caption (the patch hides the frame line there).
local SHELL_PLATE_COLOR = { 0.092, 0.081, 0.073 }

local function CreateShellCanvasLayer(f, name, sublevel)
    local tex = f:CreateTexture(nil, "BACKGROUND", nil, sublevel)
    tex:SetSize(SHELL_CANVAS_W, SHELL_CANVAS_H)
    tex:SetPoint("CENTER", f, "CENTER", 0, 0)
    tex:SetTexture(INSTALLER_WINDOW_PATH .. name)
    return tex
end

local function CreateInstallerWindowShell(f)
    -- Square backdrop off: the painted canvas replaces it.
    f:SetBackdropColor(0, 0, 0, 0)
    f:SetBackdropBorderColor(0, 0, 0, 0)

    local panel = CreateShellCanvasLayer(f, "installer_base", -8)
    local light = CreateShellCanvasLayer(f, "installer_light", -7)
    light:SetAlpha(0.9)
    local glow = CreateShellCanvasLayer(f, "installer_glow", -6)
    local pulse = glow:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local fade = pulse:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(SHELL_GLOW_MIN)
    fade:SetDuration(SHELL_GLOW_PERIOD / 2)
    fade:SetSmoothing("IN_OUT")
    -- Same switch as the options window glow.
    local profile = KT.db and KT.db.profile
    if profile and profile.menuGlow == false then
        glow:Hide()
    else
        pulse:Play()
    end

    -- Own clipping layer so the tilted frame never draws outside the window
    -- without clipping the step content (dropdowns, popups).
    local clip = CreateFrame("Frame", nil, f)
    clip:SetAllPoints()
    clip:SetClipsChildren(true)
    clip:SetFrameLevel(f:GetFrameLevel())
    local layer = CreateFrame("Frame", nil, clip)
    layer:SetAllPoints()
    layer:SetFrameLevel(f:GetFrameLevel())

    local border = layer:CreateTexture(nil, "ARTWORK")
    border:SetPoint("CENTER")
    border:SetTexture(INSTALLER_WINDOW_PATH .. "WindowBorderCut.png")

    local caption = CreateShellSpacedText(layer, "KULLTHRANUI  INSTALLER", SHELL_CAPTION_SIZE)
    -- Centred on the top line of the frame (2px stroke at the inset).
    caption:SetPoint("CENTER", layer, "TOP", 0, -(SHELL_BORDER_INSET + 1))
    local patch = layer:CreateTexture(nil, "OVERLAY", nil, -1)
    patch:SetPoint("CENTER", caption, "CENTER")
    patch:SetHeight(SHELL_CAPTION_SIZE + 4)
    patch:SetTexture(EFL_WHITE8X8)
    patch:SetVertexColor(SHELL_PLATE_COLOR[1], SHELL_PLATE_COLOR[2], SHELL_PLATE_COLOR[3], 1)

    local shell = {
        panel = panel, light = light, glow = glow, border = border, caption = caption, patch = patch,
        elapsed = SHELL_OPEN_DURATION + SHELL_CAPTION_DELAY,
    }

    local function Apply()
        local p = ShellEase(math.min(1, shell.elapsed / SHELL_OPEN_DURATION))
        local q = ShellEase(math.max(0, math.min(1, (shell.elapsed - SHELL_CAPTION_DELAY) / SHELL_OPEN_DURATION)))
        local width, height = f:GetWidth(), f:GetHeight()
        local inset = SHELL_BORDER_INSET * p
        -- The art keeps a 2px clear margin around its stroke.
        border:SetSize(width - inset * 2 + 4, height - inset * 2 + 4)
        border:SetRotation(SHELL_BORDER_TILT * (1 - p))
        border:SetAlpha(p)

        caption:SetSpacing(10 - 6 * q)
        caption:SetAlpha(q)
        patch:SetWidth((caption.textWidth or 0) + 16)
        patch:SetAlpha(q)
    end
    shell.Apply = Apply

    local function Step(_, elapsed)
        shell.elapsed = shell.elapsed + elapsed
        Apply()
        if shell.elapsed >= SHELL_OPEN_DURATION + SHELL_CAPTION_DELAY then
            layer:SetScript("OnUpdate", nil)
        end
    end

    -- Opening plays the CSS hover: the frame turns in and the caption closes up.
    function shell:Play()
        shell.elapsed = 0
        Apply()
        layer:SetScript("OnUpdate", Step)
    end
    f:HookScript("OnShow", function() shell:Play() end)

    function shell:SetAccentColor(r, g, b)
        light:SetVertexColor(r, g, b, 1)
        glow:SetVertexColor(r, g, b, 1)
        border:SetVertexColor(r, g, b, 1)
        caption:SetTextColor(r, g, b, 1)
    end

    -- A new frame starts shown, so OnShow does not fire for the first open.
    shell:Play()
    return shell
end

-- Progress bar after a CSS loader: an 8px bar with 2px corners across the
-- window (24px in from each side), centred on the footer line the canvas
-- engraves (82px up, clear of the buttons): a dim track, a solid accent
-- fill and a wide soft glow under it (box-shadow 29px, 2px down). The fill eases in and out to each new step and grows from empty
-- when the window opens. Pieces: ProgressFill.png / ProgressGlow.png
-- (tools/photoshop/installer_forja.py).
local PROGRESS_INSET = 24
local PROGRESS_H = 8
local PROGRESS_LINE_Y = 82      -- from the window bottom (installer_forja.py FOOTER_H)
local PROGRESS_CAP = 3          -- fill corner slice, in screen pixels
local PROGRESS_GLOW_CAP = 64    -- glow slice beyond each end of the fill
local PROGRESS_GLOW_H = 96
local PROGRESS_GLOW_ALPHA = 0.75
local PROGRESS_TRACK_ALPHA = 0.6
local PROGRESS_TWEEN = 0.9

-- Three textures sliced from one image: two fixed caps round a stretched
-- middle. u0/u1 bound the middle slice.
local function CreateSlices(parent, layer, sublevel, file, u0, u1)
    local slices = {}
    for i, coords in ipairs({ { 0, u0 }, { u0, u1 }, { u1, 1 } }) do
        local t = parent:CreateTexture(nil, layer, nil, sublevel)
        t:SetTexture(INSTALLER_WINDOW_PATH .. file)
        t:SetTexCoord(coords[1], coords[2], 0, 1)
        slices[i] = t
    end
    return slices
end

local function SetSlicesColor(slices, r, g, b, a)
    for _, t in ipairs(slices) do t:SetVertexColor(r, g, b, a) end
end

local function SetSlicesShown(slices, shown)
    for _, t in ipairs(slices) do t:SetShown(shown) end
end

-- left/right in bar coordinates; cap = width of each end slice.
local function PlaceSlices(slices, bar, left, right, cap, height)
    local l, m, r = slices[1], slices[2], slices[3]
    l:ClearAllPoints()
    l:SetPoint("RIGHT", bar, "LEFT", left + cap, 0)
    l:SetSize(cap, height)
    m:ClearAllPoints()
    m:SetPoint("LEFT", bar, "LEFT", left + cap, 0)
    m:SetSize(math.max(0.01, right - left - cap * 2), height)
    r:ClearAllPoints()
    r:SetPoint("LEFT", bar, "LEFT", right - cap, 0)
    r:SetSize(cap, height)
end

local function CreateInstallerProgress(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetSize(f:GetWidth() - PROGRESS_INSET * 2, PROGRESS_H)
    bar:SetPoint("CENTER", f, "BOTTOM", 0, PROGRESS_LINE_Y)
    bar.min, bar.max, bar.value = 1, 1, 1
    bar.from, bar.to, bar.shown, bar.t = 0, 0, 0, 1
    bar.r, bar.g, bar.b = KT_COLOR[1], KT_COLOR[2], KT_COLOR[3]

    local track = CreateSlices(bar, "BACKGROUND", 0, "ProgressFill.png", 0.25, 0.75)
    SetSlicesColor(track, 0, 0, 0, PROGRESS_TRACK_ALPHA)
    local glow = CreateSlices(bar, "BORDER", 0, "ProgressGlow.png", 0.25, 0.75)
    local fill = CreateSlices(bar, "ARTWORK", 0, "ProgressFill.png", 0.25, 0.75)

    local function Paint()
        SetSlicesColor(fill, bar.r, bar.g, bar.b, 1)
        SetSlicesColor(glow, bar.r, bar.g, bar.b, PROGRESS_GLOW_ALPHA)
    end

    local function Target()
        local span = math.max(1, bar.max - bar.min + 1)
        return math.max(0, math.min(1, (bar.value - bar.min + 1) / span))
    end

    local function Layout()
        local width = bar:GetWidth() or 0
        PlaceSlices(track, bar, 0, width, PROGRESS_CAP, PROGRESS_H)
        local x = width * bar.shown
        local visible = x >= PROGRESS_CAP * 2
        SetSlicesShown(fill, visible)
        SetSlicesShown(glow, visible)
        if visible then
            PlaceSlices(fill, bar, 0, x, PROGRESS_CAP, PROGRESS_H)
            PlaceSlices(glow, bar, -PROGRESS_GLOW_CAP, x + PROGRESS_GLOW_CAP, PROGRESS_GLOW_CAP, PROGRESS_GLOW_H)
        end
    end

    -- Ease-in-out from wherever the fill is towards the step's share.
    local function Tween(from)
        bar.from, bar.to, bar.t = from, Target(), 0
        bar:SetScript("OnUpdate", function(self, elapsed)
            self.t = math.min(1, self.t + elapsed / PROGRESS_TWEEN)
            local p = self.t
            local e = p < 0.5 and 2 * p * p or 1 - (-2 * p + 2) ^ 2 / 2
            self.shown = self.from + (self.to - self.from) * e
            Layout()
            if p >= 1 then self:SetScript("OnUpdate", nil) end
        end)
    end

    bar:SetScript("OnShow", function() Tween(0) end)

    -- The StatusBar calls the rest of the installer makes.
    function bar:SetMinMaxValues(lo, hi) self.min, self.max = lo, hi end
    function bar:SetValue(value)
        self.value = value
        -- Already resting on this step: nothing to animate.
        if self.t >= 1 and math.abs(self.shown - Target()) < 0.0005 then return end
        Tween(self.shown)
    end
    function bar:SetStatusBarColor(r, g, b)
        self.r, self.g, self.b = r, g, b
        Paint()
    end
    Paint()
    Layout()
    return bar
end

-- The installer accent is the KUI accent: the same palette the /kui window
-- reads (class, custom or preset colour), with the profile fields as a
-- fallback before the core is ready.
local function ResolveInstallerAccent()
    if KT.GetStyleAccentRGB then
        local ok, r, g, b = pcall(KT.GetStyleAccentRGB, KT)
        if ok and r and g and b then return r, g, b end
    end
    local r, g, b = KT_COLOR[1], KT_COLOR[2], KT_COLOR[3]
    local skin = KT.db and KT.db.profile and KT.db.profile.skin
    if skin then
        if skin.kullthranUIColorByClass or skin.borderTheme == "CLASS" then
            local _, class = UnitClass("player")
            if class then
                local colorTable = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
                local color = colorTable and colorTable[class]
                if color then r, g, b = color.r, color.g, color.b end
            end
        elseif skin.borderTheme == "CUSTOM" and skin.customBorderColor then
            r, g, b = skin.customBorderColor.r, skin.customBorderColor.g, skin.customBorderColor.b
        elseif skin.accentColor then
            r, g, b = skin.accentColor.r, skin.accentColor.g, skin.accentColor.b
        end
    end
    return r, g, b
end

local function SameColor(r1, g1, b1, r2, g2, b2)
    return math.abs(r1 - r2) < 0.01 and math.abs(g1 - g2) < 0.01 and math.abs(b1 - b2) < 0.01
end

-- Steps paint their titles, highlights and glows with the accent when they
-- are built. On an accent change, walk the open step and move everything
-- still wearing the old accent to the new one (alpha kept).
local function RecolorAccent(frame, old, r, g, b, depth)
    if not frame or depth > 14 then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        local kind = region.GetObjectType and region:GetObjectType()
        if kind == "FontString" then
            local cr, cg, cb, ca = region:GetTextColor()
            if cr and SameColor(cr, cg, cb, old[1], old[2], old[3]) then region:SetTextColor(r, g, b, ca) end
        elseif kind == "Texture" then
            local cr, cg, cb, ca = region:GetVertexColor()
            if cr and SameColor(cr, cg, cb, old[1], old[2], old[3]) then region:SetVertexColor(r, g, b, ca) end
        end
    end
    if frame.GetBackdropBorderColor and frame.GetBackdrop and frame:GetBackdrop() then
        local cr, cg, cb, ca = frame:GetBackdropBorderColor()
        if cr and SameColor(cr, cg, cb, old[1], old[2], old[3]) then frame:SetBackdropBorderColor(r, g, b, ca) end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        RecolorAccent(child, old, r, g, b, depth + 1)
    end
end

function Mod:UpdateKTColor()
    local r, g, b = ResolveInstallerAccent()
    local old = { KT_COLOR[1], KT_COLOR[2], KT_COLOR[3] }
    KT_COLOR[1] = r
    KT_COLOR[2] = g
    KT_COLOR[3] = b
    -- The Visual Style step shows colour swatches (one of them is the
    -- accent itself) and repaints its own accent pieces below.
    if self.content and self.content ~= self._themeStepContent
        and not SameColor(r, g, b, old[1], old[2], old[3]) then
        RecolorAccent(self.content, old, r, g, b, 0)
    end
    
    if self.shell then
        self.shell:SetAccentColor(r, g, b)
    end
    if self.progressBar then
        self.progressBar:SetStatusBarColor(r, g, b, 1)
    end
    if self.content and self.content.titleFS then
        self.content.titleFS:SetTextColor(r, g, b, 1)
    end
    if self.content and self.content.UpdateAllButtons then
        self.content.UpdateAllButtons()
    end
    if self.content and self.content.skipChk and self.content.skipChk.Checked then
        self.content.skipChk.Checked:SetVertexColor(r, g, b, 1)
    end
end

function Mod:CreateInstallerWindow(onlyConflicts)
    if not self.frame then
        local f = CreateFrame("Frame", "KullThranUIInstallerFrame", UIParent, "BackdropTemplate")
        f:SetSize(800, 600)
        f:SetPoint("CENTER")
        -- The main KullThranUI menu is FULLSCREEN_DIALOG. Keep the installer
        -- above it so it remains usable when both are visible.
        f:SetFrameStrata("TOOLTIP")
        f:SetToplevel(true)
        f:SetFrameLevel(200)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:HookScript("OnShow", function(self)
            self:Raise()
        end)
        f:SetScript("OnHide", function()
            local db = KT and KT.db and KT.db.profile and KT.db.profile.installer
            if db then
                -- Only RequestInstallerReload may create resume state. Normal
                -- hides (Skip, close, logout and /reload teardown) must never
                -- manufacture a new reopen request.
                db.isOpen = db.dontShowAgain ~= true
                    and (db.reopenOnReload or db.reopenStep or db.resumeStep)
                    and true or false
            end
        end)
        CreateBackdrop(f)
        f:HookScript('OnShow', function()
            self._ktExplicitlyClosed = nil
        end)
        f:HookScript('OnHide', function()
            self._ktExplicitlyClosed = nil
            -- Closed or skipped with choices still waiting for a reload.
            if not self._ktFinishing and self.moduleSettingsDirty then
                C_Timer.After(0, function() self:ApplyPendingReload(false) end)
            end
        end)
        f:HookScript('OnShow', function() self:UpdatePendingReloadNotice() end)
        
        local close = CreateFrame("Button", nil, f)
        close:SetSize(30, 30)
        close:HookScript('OnMouseDown', function()
            self._ktExplicitlyClosed = true
        end)
        close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -18)
        local closeTex = close:CreateTexture(nil, "ARTWORK")
        closeTex:SetSize(16, 16)
        closeTex:SetPoint("CENTER")
        closeTex:SetTexture(KUI_ICON_PATH .. "kui-close.png")
        close:SetScript("OnClick", function() f:Hide() end)
        close:SetScript("OnEnter", function() closeTex:SetVertexColor(1, 0.3, 0.3, 1) end)
        close:SetScript("OnLeave", function() closeTex:SetVertexColor(0.6, 0.6, 0.6, 1) end)
        
        self.shell = CreateInstallerWindowShell(f)
        
        local progressBar = CreateInstallerProgress(f)

        -- Follow accent changes made anywhere (the /kui window, class colour,
        -- a preset) while the installer is open.
        local accentPoll = 0
        f:HookScript("OnUpdate", function(_, elapsed)
            accentPoll = accentPoll + elapsed
            if accentPoll < 0.25 then return end
            accentPoll = 0
            local r, g, b = ResolveInstallerAccent()
            if not SameColor(r, g, b, KT_COLOR[1], KT_COLOR[2], KT_COLOR[3]) then
                self:UpdateKTColor()
            end
        end)
        progressBar:SetMinMaxValues(1, #INSTALLER_STEP_ORDER)
        self.progressBar = progressBar
        
        self.frame = f
    end
    
    local db = KT and KT.db and KT.db.profile and KT.db.profile.installer
    local resumeStep = tonumber(db and (db.reopenStep or db.resumeStep))
    if not resumeStep and db and db.isOpen then
        resumeStep = tonumber(db.step)
    end
    if resumeStep then
        db.step = resumeStep
    end
    self:UpdateKTColor()
    if self.frame then 
        L = KT:GetLocale()
        self.frame:Show() 
        if KT and KT.db and KT.db.profile and KT.db.profile.installer then
            KT.db.profile.installer.isOpen = true
        end
        if self:IsInitialProfileChoicePending() then
            local profiles = self:GetInitialProfileChoices()
            if #profiles > 0 then
                self:ShowInitialProfileStep(profiles)
                return
            end
            self:CompleteInitialProfileChoice(nil)
        end
        local conflicts = self:CheckConflicts()
        if conflicts and not resumeStep then
            self.onlyConflicts = onlyConflicts
            self:ShowConflictStep(conflicts)
        elseif not onlyConflicts then
            self:OpenCurrentStep()
        else
            self.frame:Hide()
            if KT.ProcessLoginPopups then KT:ProcessLoginPopups() end
        end
    end
end

function Mod:UpdateProgressBar(step)
    if self.progressBar then
        self.progressBar:Show()
        local position = step
        for index, stepId in ipairs(INSTALLER_STEP_ORDER) do
            if stepId == step then position = index break end
        end
        self.progressBar:SetValue(position)
    end
end

function Mod:ShowConflictStep(conflicts)
    local f = self.frame
    if self.content then self.content:Hide() end
    if self.progressBar then self.progressBar:Hide() end
    
    local content = CreateFrame("Frame", nil, f)
    content:SetAllPoints()
    self.content = content
    
    local icon = content:CreateTexture(nil, "ARTWORK")
    icon:SetSize(64, 64)
    icon:SetPoint("TOP", 0, -40)
    icon:SetTexture("Interface\\DialogFrame\\UI-Dialog-Icon-AlertNew")
    
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetPoint("TOP", icon, "BOTTOM", 0, -20)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(L["Compatibility Check"])
    title:SetTextColor(1, 0.2, 0.2)
    
    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOP", title, "BOTTOM", 0, -20)
    text:SetWidth(620)
    text:SetFont(GetKTFont(), 15)
    text:SetText(L["Detected addons that may interfere with KullThranUI modules. Loaded or enabled addons are highlighted below. Disable them if you want KullThranUI to control those features."])
    text:SetTextColor(0.9, 0.9, 0.9)
    text:SetJustifyH("CENTER")

    local function Normalize(conflictList)
        local entries = {}
        if type(conflictList) ~= "table" then return entries end
        for _, item in ipairs(conflictList) do
            if type(item) == "string" then
                table.insert(entries, {
                    rule = {
                        title = "Addon Conflict",
                        kind = "conflict",
                        severity = "high",
                        modules = { "KullThranUI" },
                        reason = "Conflicts with KullThranUI modules.",
                    },
                    addons = {
                        { name = item, title = item, installed = true, enabled = true, loaded = true },
                    },
                    hasLoaded = true,
                })
            elseif type(item) == "table" then
                table.insert(entries, item)
            end
        end
        return entries
    end

    local controls = CreateFrame("Frame", nil, content)
    controls:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 8)
    controls:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 8)
    controls:SetHeight(106)

    local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOP", text, "BOTTOM", 0, -18)
    scroll:SetPoint("BOTTOMLEFT", controls, "TOPLEFT", 92, 10)
    scroll:SetPoint("BOTTOMRIGHT", controls, "TOPRIGHT", -112, 10)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local range = self:GetVerticalScrollRange() or 0
        local target = current - (delta * 34)
        if target < 0 then
            target = 0
        elseif target > range then
            target = range
        end
        self:SetVerticalScroll(target)
    end)

    local scrollContent = CreateFrame("Frame", nil, scroll)
    scrollContent:SetWidth(620)
    scrollContent:SetHeight(1)
    scroll:SetScrollChild(scrollContent)

    local entries = Normalize(conflicts)
    local y = 0
    local first = true
    for _, entry in ipairs(entries) do
        local rule = entry.rule or {}
        local kind = (rule.kind or "conflict"):upper()
        y = y + (first and 6 or 18)

        local header = scrollContent:CreateFontString(nil, "OVERLAY")
        header:SetPoint("TOP", scrollContent, "TOP", 0, -y)
        header:SetFont(GetKTFont(), 14, "OUTLINE")
        header:SetText(string.format("%s [%s]", LText(rule.title or "Addon Conflict"), kind))
        header:SetTextColor(1, 0.85, 0.85)
        header:SetJustifyH("CENTER")
        y = y + math.ceil(header:GetStringHeight() or 16) + 6
        first = false

        local modules = rule.modules and table.concat(rule.modules, ", ") or "KullThranUI"
        local reason = LText(rule.reason or "Potential overlap with KullThranUI.")
        local detail = scrollContent:CreateFontString(nil, "OVERLAY")
        detail:SetPoint("TOP", scrollContent, "TOP", 0, -y)
        detail:SetFont(GetKTFont(), 12)
        detail:SetWidth(560)
        detail:SetText(modules .. " - " .. reason)
        detail:SetTextColor(0.75, 0.75, 0.75)
        detail:SetJustifyH("CENTER")
        detail:SetJustifyV("TOP")
        y = y + math.ceil(detail:GetStringHeight() or 30) + 10

        for _, addon in ipairs(entry.addons or {}) do
            if addon.loaded or addon.enabled then
                local row = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
                row:SetSize(560, 58)
                row:SetPoint("TOP", scrollContent, "TOP", 0, -y)
                CreateBackdrop(row)
                row:SetBackdropColor(0.08, 0.08, 0.08, 0.92)

                local nameText = row:CreateFontString(nil, "OVERLAY")
                nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
                nameText:SetPoint("RIGHT", row, "RIGHT", -230, 0)
                nameText:SetFont(GetKTFont(), 12, "OUTLINE")
                nameText:SetJustifyH("LEFT")

                local statusText = row:CreateFontString(nil, "OVERLAY")
                statusText:SetPoint("TOPLEFT", nameText, "BOTTOMLEFT", 0, -5)
                statusText:SetPoint("RIGHT", nameText, "RIGHT", 0, 0)
                statusText:SetFont(GetKTFont(), 10)
                statusText:SetJustifyH("LEFT")
                statusText:SetTextColor(1, 0.72, 0.28, 1)

                local btnDisableAddon = CreateFrame("Button", nil, row, "BackdropTemplate")
                btnDisableAddon:SetSize(170, 22)
                btnDisableAddon:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -6)

                local btnDisableKUI = CreateFrame("Button", nil, row, "BackdropTemplate")
                btnDisableKUI:SetSize(170, 22)
                btnDisableKUI:SetPoint("TOPRIGHT", btnDisableAddon, "BOTTOMRIGHT", 0, -6)

                local label = addon.title or addon.name or "Addon"
                local status = addon.loaded and (LText("Loaded")) or (addon.enabled and (LText("Enabled")) or (LText("Installed")))
                nameText:SetText(label)
                statusText:SetText(status)

                btnDisableAddon:SetText(LText("Disable Addon"))
                btnDisableAddon:SetScript("OnClick", function()
                    local detector = KT:GetModule("AddonConflictDetector", true)
                    local ok = detector and detector.DisableAddon and detector:DisableAddon(addon.name)
                    if not ok and C_AddOns and C_AddOns.DisableAddOn then
                        ok = pcall(C_AddOns.DisableAddOn, addon.name)
                    end
                    if ok then
                        btnDisableAddon:SetText(LText("Reload Required"))
                        btnDisableAddon:Disable()
                        statusText:SetText(LText("Addon Disabled - Reload Required"))
                    end
                end)
                SkinButton(btnDisableAddon)

                btnDisableKUI:SetText(LText("Disable KUI Module"))
                btnDisableKUI:SetScript("OnClick", function()
                    local detector = KT:GetModule("AddonConflictDetector", true)
                    local ok, moduleLabel
                    if detector and detector.DisableKUIRule and rule.id then
                        ok, moduleLabel = detector:DisableKUIRule(rule.id)
                    end
                    if ok then
                        btnDisableKUI:SetText(LText("Reload Required"))
                        btnDisableKUI:Disable()
                        statusText:SetText(string.format("%s - %s", moduleLabel or LText(rule.title or "KUI Module"), LText("Reload Required")))
                    end
                end)
                SkinButton(btnDisableKUI)

                y = y + 68
            end
        end
    end
    scrollContent:SetHeight(math.max(1, y + 8))
    
    local btnReload = CreateFrame("Button", nil, controls, "BackdropTemplate")
    btnReload:SetSize(140, 30)
    btnReload:SetPoint("TOP", controls, "TOP", 0, -2)
    btnReload:SetText(L["Reload UI"])
    SkinButton(btnReload)
    btnReload:SetScript("OnClick", function() RequestInstallerReload(self, 1) end)
    
    -- The recommended answer: every incompatible addon off with one reload,
    -- instead of one "Disable Addon" click and reload per row.
    local detectorForAll = KT:GetModule("AddonConflictDetector", true)
    if detectorForAll and detectorForAll.DisableAllConflicts then
        local btnDisableAll = CreateFrame("Button", nil, controls, "BackdropTemplate")
        btnDisableAll:SetSize(230, 30)
        btnDisableAll:SetPoint("RIGHT", btnReload, "LEFT", -14, 0)
        btnDisableAll:SetText(LText("Disable All & Reload"))
        SkinButton(btnDisableAll)
        local glow = CreateFrame("Frame", nil, controls)
        glow:SetPoint("TOPLEFT", btnDisableAll, "TOPLEFT", -4, 4)
        glow:SetPoint("BOTTOMRIGHT", btnDisableAll, "BOTTOMRIGHT", 4, -4)
        glow:SetFrameLevel(math.max(0, btnDisableAll:GetFrameLevel() - 1))
        local edges = {}
        for index = 1, 4 do
            local edge = glow:CreateTexture(nil, "BACKGROUND")
            edge:SetColorTexture(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 0.9)
            edges[index] = edge
        end
        edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(2)
        edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(2)
        edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(2)
        edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(2)
        local pulse = glow:CreateAnimationGroup()
        pulse:SetLooping("BOUNCE")
        local fade = pulse:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0.2)
        fade:SetDuration(0.85)
        fade:SetSmoothing("IN_OUT")
        pulse:Play()
        btnDisableAll:SetScript("OnClick", function()
            -- Rows already disabled one by one are pending too: reload either way.
            detectorForAll:DisableAllConflicts(Normalize(conflicts))
            RequestInstallerReload(self, 1)
        end)
    end

    local btnIgnore = CreateFrame("Button", nil, controls, "BackdropTemplate")
    btnIgnore:SetSize(140, 30)
    btnIgnore:SetPoint("TOP", btnReload, "BOTTOM", 0, -8)
    btnIgnore:SetText(L["Ignore & Continue"])
    SkinButton(btnIgnore)
    btnIgnore:SetScript("OnClick", function() self:ShowWelcomeStep() end)

    -- Don't show again checkbox (per conflict detector)
    local cdb = KT.db.profile.conflictDetector or {}
    KT.db.profile.conflictDetector = cdb

    local cb = CreateFrame("CheckButton", nil, controls, "BackdropTemplate")
    cb:SetSize(18, 18)
    cb:SetPoint("TOP", btnIgnore, "BOTTOM", -70, -6)
    CreateBackdrop(cb)
    cb:SetBackdropColor(0, 0, 0, 1)

    cb.Checked = cb:CreateTexture(nil, "ARTWORK")
    cb.Checked:SetTexture("Interface\\Buttons\\WHITE8x8")
    cb.Checked:SetVertexColor(unpack(KT_COLOR))
    cb.Checked:SetAllPoints(cb)
    cb.Checked:SetAlpha(cdb.dontShowAgain and 1 or 0)
    cb:SetChecked(cdb.dontShowAgain and true or false)

    local cbText = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cbText:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    cbText:SetFont(GetKTFont(), 12)
    cbText:SetText(L["Don't show again"])

    cb:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        self.Checked:SetAlpha(v and 1 or 0)
        cdb.dontShowAgain = v
    end)

    local function ApplyDontShowAgain()
        cdb.dontShowAgain = cb:GetChecked() and true or false
    end

    btnReload:SetScript("OnClick", function()
        ApplyDontShowAgain()
        RequestInstallerReload(self, 1)
    end)

    btnIgnore:SetScript("OnClick", function()
        ApplyDontShowAgain()
        if self.onlyConflicts then self.frame:Hide(); if KT.ProcessLoginPopups then KT:ProcessLoginPopups() end else self:ShowWelcomeStep() end
    end)
end

function Mod:ShowWelcomeStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 1
    self:UpdateProgressBar(1)
    
    local f = self.frame
    if self.content then self.content:Hide() end
    
    local content = CreateFrame("Frame", nil, f)
    content:SetAllPoints()
    self.content = content
    
    local icon = content:CreateTexture(nil, "ARTWORK")
    icon:SetSize(80, 80)
    icon:SetPoint("TOP", 0, -60)
    icon:SetTexture(ICON_PATH .. "KUI.png")
    
    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", icon, "BOTTOM", 0, -20)
    title:SetFont(GetKTFont(), 30, "OUTLINE")
    title:SetText(L["Welcome to KullThranUI"])
    title:SetTextColor(unpack(KT_COLOR))
    
    local cmdText = content:CreateFontString(nil, "OVERLAY")
    cmdText:SetPoint("TOP", title, "BOTTOM", 0, -5)
    cmdText:SetWidth(600)
    cmdText:SetFont(GetKTFont(), 14)
    cmdText:SetText(L["You can open the options menu anytime with /kui"])
    cmdText:SetTextColor(unpack(KT_COLOR))
    
    local text = content:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOP", cmdText, "BOTTOM", 0, -20)
    text:SetWidth(600)
    text:SetFont(GetKTFont(), 16)
    text:SetText(L["This guided setup will help you choose language, fonts, visual style, and recommended addons."])
    text:SetTextColor(0.9, 0.9, 0.9)
    text:SetJustifyH("CENTER")
    
    -- Class shape background: the crest of the player's own class, drawn flat
    -- (2D) and tinted with the class colour. Falls back to the feral shape.
    local silhouette = CreateInstallerCharacter(content)
    local shape = content:CreateTexture(nil, "BACKGROUND")
    shape:SetPoint("CENTER", 0, -95)
    if silhouette then
        shape:Hide()
    elseif not ApplyInstallerClassShape(shape) then
        shape:SetSize(665, 285)
        shape:SetPoint("CENTER", -50, -100)
        shape:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\feralshape.tga")
        shape:SetVertexColor(1, 1, 1, 0.25)
    end
    
    -- Botones
    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(140, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() self:ShowLanguageStep() end)
    
    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(140, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)
    
    local chk = CreateSkipCheckbox(content, btnSkip)
    
    btnSkip:SetScript("OnClick", function() 
        if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end
        f:Hide()
    end)
end

-------------------------------------------------------------------------
-- HOLO TOGGLE (Language step), after a Uiverse CSS toggle by reglobby,
-- in the KUI accent: a glassy pill with a dashed line running through it
-- and a glowing thumb (pulsing core, rising particles). The chosen language
-- is "on": the thumb slides to the right end, three energy rings spin round
-- it and every piece takes the full accent; the others stay in a muted
-- accent. No scan line. Textures: InstallerWindow/Toggle (installer_toggle.py).
-------------------------------------------------------------------------
local HOLO_W, HOLO_H = 220, 44
local HOLO_THUMB = 38
local HOLO_SLIDE = 0.6          -- cubic-bezier(0.23, 1, 0.32, 1) ~ ease-out quint
local HOLO_DASH_SPEED = 20 / 3  -- px per second
local HOLO_PULSE = 2
local HOLO_BLINK = 2
local HOLO_PARTICLE_LIFE = 3
-- Particles: x, y as a share of the thumb, start delay.
local HOLO_PARTICLES = { { 0.30, 0.70, 0.2 }, { 0.60, 0.60, 0.6 }, { 0.40, 0.50, 1.0 }, { 0.70, 0.40, 1.4 }, { 0.50, 0.80, 1.8 } }
-- Energy rings: texture, size, turns per second (CSS clockwise = negative).
local HOLO_RINGS = { { "arc1", 35, -1 / 3 }, { "arc2", 28, 1 / 2 }, { "arc3", 21, -1 / 1.5 } }
-- Interface lines under the pill, mirrored on the right: x from the side,
-- y below the pill, width, height.
local HOLO_LINES = { { 29, 3, 22, 1 }, { 51, 3, 1, 5 }, { 51, 7, 36, 1 } }

local function HoloEaseOut(p)
    return 1 - (1 - p) ^ 5
end

-- Both states come from the installer accent (KT_COLOR, the KUI theme
-- colour): on is the accent itself, off the same accent dimmed.
local HOLO_OFF_DIM = 0.55

local function HoloColors()
    local r, g, b = KT_COLOR[1], KT_COLOR[2], KT_COLOR[3]
    return { r, g, b }, { r * HOLO_OFF_DIM, g * HOLO_OFF_DIM, b * HOLO_OFF_DIM }
end

local function HoloTex(parent, file, layer, sublevel, w, h)
    local t = parent:CreateTexture(nil, layer, nil, sublevel)
    t:SetTexture(INSTALLER_TOGGLE_PATH .. file .. ".png")
    if w then t:SetSize(w, h or w) end
    return t
end

local function CreateHoloToggle(parent, label, locale)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(HOLO_W, HOLO_H)
    btn.on, btn.p, btn.clock, btn.hoverP = false, 0, 0, 0

    -- Track.
    local glow = HoloTex(btn, "track_glow", "BACKGROUND", 0, HOLO_W + 48, HOLO_H + 48)
    glow:SetPoint("CENTER")
    local holo = HoloTex(btn, "soft_glow", "BACKGROUND", 1, HOLO_W + 30, HOLO_H + 26)
    holo:SetPoint("CENTER")
    holo:SetBlendMode("ADD")
    local fill = HoloTex(btn, "track_fill", "BACKGROUND", 2)
    fill:SetAllPoints()
    local radial = HoloTex(btn, "track_radial", "BACKGROUND", 3)
    radial:SetAllPoints()
    local inset = HoloTex(btn, "track_inset", "BACKGROUND", 4)
    inset:SetAllPoints()
    local sheen = HoloTex(btn, "track_sheen", "BORDER", 0)
    sheen:SetAllPoints()
    local dash = btn:CreateTexture(nil, "BORDER", nil, 1)
    dash:SetTexture(INSTALLER_TOGGLE_PATH .. "dash.png", "REPEAT", "CLAMP")
    dash:SetPoint("LEFT", btn, "LEFT", HOLO_H / 2, 0)
    dash:SetPoint("RIGHT", btn, "RIGHT", -HOLO_H / 2, 0)
    dash:SetHeight(1)
    local border = HoloTex(btn, "track_border", "BORDER", 2)
    border:SetAllPoints()
    local reflection = HoloTex(btn, "reflection", "OVERLAY", 7)
    reflection:SetAllPoints()
    reflection:SetVertexColor(1, 1, 1, 0.1)

    local lines = {}
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local sign = side == "LEFT" and 1 or -1
        for _, l in ipairs(HOLO_LINES) do
            local t = btn:CreateTexture(nil, "BACKGROUND", nil, 1)
            t:SetTexture(EFL_WHITE8X8)
            t:SetSize(l[3], l[4])
            t:SetPoint("TOP" .. side, btn, "BOTTOM" .. side, sign * l[1], -l[2])
            lines[#lines + 1] = t
        end
    end

    -- Status light at the free end of the track.
    local lightGlow = HoloTex(btn, "soft_glow", "ARTWORK", 0, 22)
    lightGlow:SetBlendMode("ADD")
    local light = HoloTex(btn, "disc_soft", "ARTWORK", 1, 8)
    light:SetPoint("CENTER", lightGlow, "CENTER")

    -- Label: flag and name in capitals, between the thumb and the light.
    local labelHolder = CreateFrame("Frame", nil, btn)
    labelHolder:SetSize(HOLO_W - HOLO_THUMB - 40, HOLO_H)
    -- Painted country flag (installer_flags.py); "auto" is a globe.
    local flag = labelHolder:CreateTexture(nil, "ARTWORK")
    flag:SetTexture(INSTALLER_TOGGLE_PATH .. "flag_" .. tostring(locale or "auto") .. ".png")
    flag:SetSize(24, 16)
    flag:SetPoint("LEFT", labelHolder, "LEFT", 0, 0)
    local text = labelHolder:CreateFontString(nil, "OVERLAY")
    text:SetPoint("LEFT", flag, "RIGHT", 7, 0)
    text:SetPoint("RIGHT", labelHolder, "RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    local upper = tostring(label or ""):upper()
    local room = labelHolder:GetWidth() - 31
    for size = 13, 9, -1 do
        text:SetFont(GetKTFont(), size, "")
        text:SetText(upper)
        local width = text.GetUnboundedStringWidth and text:GetUnboundedStringWidth() or text:GetStringWidth()
        if width <= room then break end
    end

    -- Thumb.
    local thumb = CreateFrame("Frame", nil, btn)
    thumb:SetSize(HOLO_THUMB, HOLO_THUMB)
    thumb:SetFrameLevel(btn:GetFrameLevel() + 2)
    local shadow = HoloTex(thumb, "soft_glow", "BACKGROUND", 0, HOLO_THUMB + 18)
    shadow:SetPoint("CENTER", thumb, "CENTER", 0, -2)
    shadow:SetVertexColor(0, 0, 0, 0.5)
    local body = HoloTex(thumb, "disc", "BACKGROUND", 1)
    body:SetAllPoints()
    local bodyLight = HoloTex(thumb, "disc_soft", "BACKGROUND", 2)
    bodyLight:SetAllPoints()
    local thumbInset = HoloTex(thumb, "thumb_inset", "BORDER", 0)
    thumbInset:SetAllPoints()
    local coreGlow = HoloTex(thumb, "soft_glow", "BORDER", 1, 44)
    coreGlow:SetPoint("CENTER")
    coreGlow:SetBlendMode("ADD")
    local core = HoloTex(thumb, "disc", "BORDER", 2, 28)
    core:SetPoint("CENTER")
    local coreLight = HoloTex(thumb, "disc_soft", "BORDER", 3, 28)
    coreLight:SetPoint("CENTER")
    local innerGlow = HoloTex(thumb, "soft_glow", "ARTWORK", 0, 26)
    innerGlow:SetPoint("CENTER")
    innerGlow:SetBlendMode("ADD")
    local inner = HoloTex(thumb, "disc", "ARTWORK", 1, 18)
    inner:SetPoint("CENTER")
    local innerLight = HoloTex(thumb, "disc_soft", "ARTWORK", 2, 18)
    innerLight:SetPoint("CENTER")
    innerLight:SetVertexColor(1, 1, 1, 0.8)
    local ring = HoloTex(thumb, "thumb_ring", "OVERLAY", 0)
    ring:SetAllPoints()

    local mask = thumb:CreateMaskTexture()
    mask:SetAllPoints()
    mask:SetTexture(INSTALLER_TOGGLE_PATH .. "disc.png", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    local particles = {}
    for i, def in ipairs(HOLO_PARTICLES) do
        local t = HoloTex(thumb, "disc_soft", "OVERLAY", 1, 4)
        t:SetBlendMode("ADD")
        t:AddMaskTexture(mask)
        particles[i] = { tex = t, x = def[1], y = def[2], delay = def[3] }
    end

    local rings = {}
    for i, def in ipairs(HOLO_RINGS) do
        local t = thumb:CreateTexture(nil, "OVERLAY", nil, 2)
        t:SetTexture(INSTALLER_TOGGLE_PATH .. def[1] .. ".png")
        t:SetSize(def[2], def[2])
        t:SetPoint("CENTER", thumb, "CENTER")
        rings[i] = { tex = t, speed = def[3] }
    end

    local function Paint()
        local on, off = HoloColors()
        local e = HoloEaseOut(btn.p)
        local c = { off[1] + (on[1] - off[1]) * e, off[2] + (on[2] - off[2]) * e, off[3] + (on[3] - off[3]) * e }
        local lc = { c[1] + (1 - c[1]) * 0.5, c[2] + (1 - c[2]) * 0.5, c[3] + (1 - c[3]) * 0.5 }

        glow:SetVertexColor(c[1], c[2], c[3], 0.35 + 0.2 * btn.hoverP)
        holo:SetVertexColor(c[1], c[2], c[3], 0.12)
        fill:SetVertexColor(c[1] * 0.2, c[2] * 0.2, c[3] * 0.2, 0.6)
        radial:SetVertexColor(c[1], c[2], c[3], 0.1)
        sheen:SetVertexColor(c[1], c[2], c[3], 0.35)
        dash:SetVertexColor(c[1], c[2], c[3], 0.3)
        border:SetVertexColor(c[1], c[2], c[3], 0.45)
        for _, t in ipairs(lines) do t:SetVertexColor(c[1], c[2], c[3], 0.3) end
        lightGlow:SetVertexColor(c[1], c[2], c[3], 0.5)
        light:SetVertexColor(c[1], c[2], c[3], 1)

        body:SetVertexColor(c[1] * 0.12, c[2] * 0.12, c[3] * 0.12, 0.9)
        bodyLight:SetVertexColor(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, 0.6)
        thumbInset:SetVertexColor(c[1], c[2], c[3], 0.5)
        ring:SetVertexColor(c[1], c[2], c[3], 0.6)
        coreGlow:SetVertexColor(c[1], c[2], c[3], 0.5)
        core:SetVertexColor(c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 0.2)
        coreLight:SetVertexColor(c[1], c[2], c[3], 0.6)
        innerGlow:SetVertexColor(lc[1], lc[2], lc[3], 0.7)
        inner:SetVertexColor(lc[1], lc[2], lc[3], 0.5)
        for _, pt in ipairs(particles) do pt.tex:SetVertexColor(lc[1], lc[2], lc[3], 0.8) end
        -- The rings only show on the chosen language.
        for _, rg in ipairs(rings) do rg.tex:SetVertexColor(c[1], c[2], c[3], 0.5 * e) end

        local k = 0.45 + 0.35 * e
        text:SetTextColor(c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k, 1)
    end

    local function Layout()
        local e = HoloEaseOut(btn.p)
        thumb:ClearAllPoints()
        thumb:SetPoint("LEFT", btn, "LEFT", 3 + (HOLO_W - HOLO_THUMB - 6) * e, 0)
        -- The light and the label sit on the side the thumb left.
        lightGlow:ClearAllPoints()
        lightGlow:SetPoint("CENTER", btn, "LEFT", HOLO_W - 16 - (HOLO_W - 32) * e, 0)
        labelHolder:ClearAllPoints()
        labelHolder:SetPoint("LEFT", btn, "LEFT", (HOLO_THUMB + 12) + (30 - (HOLO_THUMB + 12)) * e, 0)
    end

    local function Step(_, elapsed)
        btn.clock = btn.clock + elapsed
        local target = btn.on and 1 or 0
        if btn.p ~= target then
            local d = elapsed / HOLO_SLIDE
            btn.p = target > btn.p and math.min(1, btn.p + d) or math.max(0, btn.p - d)
        end
        local hoverTarget = btn:IsMouseOver() and 1 or 0
        btn.hoverP = btn.hoverP + (hoverTarget - btn.hoverP) * math.min(1, elapsed * 6)
        Layout()
        Paint()

        local t = btn.clock
        -- Dashed line drifts right; the chosen language runs it the other way.
        local offset = (t * HOLO_DASH_SPEED / 16 * (btn.on and -1 or 1)) % 1
        dash:SetTexCoord(-offset, -offset + (dash:GetWidth() or 0) / 16, 0, 1)

        -- Core pulse (2s alternate): scale 0.9-1.1, opacity 0.5-0.8.
        local k = 0.5 - 0.5 * math.cos(t * math.pi / HOLO_PULSE)
        local s = 0.9 + 0.2 * k
        inner:SetSize(18 * s, 18 * s)
        innerLight:SetSize(18 * s, 18 * s)
        innerGlow:SetSize(26 * s, 26 * s)
        inner:SetAlpha(0.5 + 0.3 * k)
        innerLight:SetAlpha(0.5 + 0.3 * k)

        -- Status light blink (2s): opacity 0.5-1, scale 0.9-1.1.
        local bk = 0.5 - 0.5 * math.cos(t * 2 * math.pi / HOLO_BLINK)
        light:SetSize(8 * (0.9 + 0.2 * bk), 8 * (0.9 + 0.2 * bk))
        light:SetAlpha(0.5 + 0.5 * bk)
        lightGlow:SetAlpha(0.5 + 0.5 * bk)

        -- Particles rise 21px and shrink away over 3s.
        for _, pt in ipairs(particles) do
            local life = ((t - pt.delay) % HOLO_PARTICLE_LIFE) / HOLO_PARTICLE_LIFE
            local rise = 1 - (1 - life) ^ 2
            local alpha = life < 0.2 and life / 0.2 * 0.8 or 0.8 * (1 - (life - 0.2) / 0.8)
            local size = math.max(0.01, 4 * (1 - rise))
            pt.tex:SetSize(size, size)
            pt.tex:ClearAllPoints()
            pt.tex:SetPoint("CENTER", thumb, "TOPLEFT", HOLO_THUMB * pt.x, -HOLO_THUMB * pt.y + 21 * rise)
            pt.tex:SetAlpha(t < pt.delay and 0 or alpha)
        end

        for _, rg in ipairs(rings) do
            rg.tex:SetRotation(t * rg.speed * 2 * math.pi)
        end
    end

    function btn:SetOn(on, instant)
        self.on = on and true or false
        if instant then self.p = self.on and 1 or 0 end
    end
    btn:SetScript("OnUpdate", Step)
    Step(btn, 0)
    return btn
end

function Mod:ShowLanguageStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 2
    self:UpdateProgressBar(2)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(LText("Language"))
    title:SetTextColor(unpack(KT_COLOR))

    local desc = content:CreateFontString(nil, "OVERLAY")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -10)
    desc:SetWidth(600)
    desc:SetFont(GetKTFont(), 14)
    -- Some translations store the line break as a literal "\n".
    local descText = L["Choose the language for KullThranUI.\nChanging it will reload the UI and reopen the installer on this step."]
    desc:SetText((descText:gsub("\\n", "\n")))
    desc:SetTextColor(0.9, 0.9, 0.9)
    desc:SetJustifyH("CENTER")

    local currentLanguage = KT.db.profile.language or "auto" 

    local toggles = {}
    local function CreateLanguageButton(label, value, xOffset, yOffset)
        local btn = CreateHoloToggle(content, LText(label), value)
        btn:SetPoint("CENTER", content, "CENTER", xOffset, yOffset or 10)
        btn:SetOn(currentLanguage == value, true)
        btn:SetScript("OnClick", function()
            currentLanguage = value
            KT.db.profile.language = value
            KT.db.profile.installer = KT.db.profile.installer or {}
            KT.db.profile.installer.step = 2
            -- Let the thumbs slide over before the reload prompt.
            for _, other in ipairs(toggles) do other:SetOn(other == btn) end
            C_Timer.After(0.45, function() RequestInstallerReload(self, 2) end)
        end)
        toggles[#toggles + 1] = btn
        return btn
    end

    CreateLanguageButton(LText("Auto (Client)"), "auto", 0, 155)
    CreateLanguageButton(LText("English"), "enUS", -130, 100)
    CreateLanguageButton(LText("Spanish"), "esES", 130, 100)
    CreateLanguageButton(LText("French"), "frFR", -130, 45)
    CreateLanguageButton(LText("German"), "deDE", 130, 45)
    CreateLanguageButton(LText("Italian"), "itIT", -130, -10)
    CreateLanguageButton(LText("Portuguese"), "ptBR", 130, -10)
    CreateLanguageButton(LText("Russian"), "ruRU", -130, -65)
    CreateLanguageButton(LText("Korean"), "koKR", 130, -65)
    CreateLanguageButton(LText("Traditional Chinese"), "zhTW", -130, -120)
    CreateLanguageButton(LText("Simplified Chinese"), "zhCN", 130, -120)

    local note = content:CreateFontString(nil, "OVERLAY")
    note:SetPoint("TOP", content, "CENTER", 0, -180)
    note:SetWidth(600)
    note:SetFont(GetKTFont(), 13)
    if currentLanguage == "esES" then
        note:SetText(L["You can change this later from /kui."])
    else
        note:SetText(L["You can change this later from /kui."])
    end
    note:SetTextColor(0.75, 0.75, 0.75)
    note:SetJustifyH("CENTER")

    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() self:ShowProfileStep() end)

    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowWelcomeStep() end)

    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)

    local chk = CreateSkipCheckbox(content, btnSkip)
    btnSkip:SetScript("OnClick", function() if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end self.frame:Hide() end)
end



function Mod:ShowThemeStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 3
    self:UpdateProgressBar(3)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    -- Applying a Visual Style reloads the UI: PrepareStyleReload() asks the
    -- Installer to come back to this page, and only at that moment.
    local idb = KT.db.profile.installer
    local function ClearResume()
        if idb then idb.reopenStep, idb.resumeStep, idb.reopenOnReload = nil, nil, nil end
    end
    ClearResume()
    self._themeStepContent = content

    local title = content:CreateFontString(nil, "OVERLAY")
    content.titleFS = title
    title:SetPoint("TOP", 0, -26)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(LText("Visual Style & Color"))
    title:SetTextColor(unpack(KT_COLOR))

    local desc = content:CreateFontString(nil, "OVERLAY")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -8)
    desc:SetWidth(700)
    desc:SetFont(GetKTFont(), 13)
    desc:SetText(LText("Pick the look of your interface and its accent color."))
    desc:SetTextColor(0.9, 0.9, 0.9)
    desc:SetJustifyH("CENTER")

    local contentWidth = 750
    local function SectionLabel(text, yOff)
        local fs = content:CreateFontString(nil, "OVERLAY")
        fs:SetFont(GetKTFont(), 11, "OUTLINE")
        fs:SetPoint("TOPLEFT", content, "TOP", -(contentWidth / 2), yOff)
        fs:SetText(string.upper(text))
        fs:SetTextColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 1)
        return fs
    end

    -- Visual Style cards (same cards as the options menu).
    local stylesTop = -92
    SectionLabel(LText("Visual Style"), stylesTop)
    local stylesHeight = 0
    if KT.VisualThemes and KT.VisualThemes.CreateSelector then
        local selectorContainer = CreateFrame("Frame", nil, content)
        selectorContainer:SetSize(contentWidth, 250)
        selectorContainer:SetPoint("TOP", content, "TOP", 0, stylesTop - 18)
        stylesHeight = KT.VisualThemes:CreateSelector(selectorContainer, {
            columns = 4, compact = true, width = contentWidth,
            -- Pending, like every installer choice: no reload prompt here.
            currentTheme = self.pendingVisualTheme,
            onApply = function(themeKey)
                self:SetPendingVisualTheme(themeKey)
                self:ShowThemeStep()
            end,
        }) or 238
    end

    -- Accent colour cards.
    local accentTop = stylesTop - 18 - math.max(stylesHeight, 238) - 12
    SectionLabel(LText("Accent Color"), accentTop)

    local currentPreset, isClass, isCustom
    local function ReadState()
        local skin = KT.db.profile.skin
        currentPreset = skin and skin.stylePreset or "kui_crimson"
        isClass = skin and skin.kullthranUIColorByClass
        isCustom = skin and not skin.kullthranUIColorByClass and skin.borderTheme == "CUSTOM"
    end
    ReadState()

    local buttons = {}
    local refreshGrid
    local function UpdateAllButtons()
        ReadState()
        if refreshGrid then refreshGrid() end
        for _, b in ipairs(buttons) do
            if b.UpdateState then b.UpdateState() end
        end
    end
    content.UpdateAllButtons = UpdateAllButtons

    local accentContainer = CreateFrame("Frame", nil, content)
    accentContainer:SetSize(contentWidth, 100)
    accentContainer:SetPoint("TOP", content, "TOP", 0, accentTop - 18)
    local accentHeight
    accentHeight, refreshGrid = KT:CreateAccentPresetGrid(accentContainer, {
        columns = 6, width = contentWidth, cardHeight = 38, gap = 8,
        fontPath = GetKTFont(), fontSize = 10,
        isSelected = function(presetKey)
            return (not isClass) and (not isCustom) and (currentPreset == presetKey)
        end,
        onSelect = function(presetKey)
            KT.db.profile.skin = KT.db.profile.skin or {}
            KT.db.profile.castbar = KT.db.profile.castbar or {}
            KT.db.profile.castbar.colorMode = "THEME"
            KT.db.profile.skin.kullthranUIColorByClass = false
            KT.db.profile.skin.borderTheme = "KULLTHRAN"
            if KT.ApplySmartStylePreset then KT.ApplySmartStylePreset(presetKey) end
            UpdateAllButtons()
            if KT.SyncSmartStyleDerivedTargets then KT.SyncSmartStyleDerivedTargets() end
            if KT.RefreshStylePalette then KT:RefreshStylePalette() end
            if KT.GetModule then
                local cb = KT:GetModule("CastBar", true)
                if cb and cb.Refresh then cb:Refresh("ApplySettings") end
            end
            Mod:UpdateKTColor()
        end,
    })

    -- Class / Custom colour: two pill chips on the "Accent Color" line, at the
    -- right. Each shows its colour in a dot; the active one is filled with the
    -- accent. They are an alternative to the preset cards, not more cards.
    local HINT = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\InfoHint\\"
    local CHIP_H, CHIP_PAD, CHIP_GAP = 22, 12, 8
    local function PillTexture(parent, layer, file)
        local tex = parent:CreateTexture(nil, layer)
        tex:SetTexture(HINT .. file)
        tex:SetAllPoints()
        local sliced = tex.SetTextureSliceMargins and pcall(tex.SetTextureSliceMargins, tex, 11, 11, 11, 11)
        if sliced and tex.SetTextureSliceMode then
            pcall(tex.SetTextureSliceMode, tex, 0)
        elseif not sliced then
            tex:SetTexture("Interface\\Buttons\\WHITE8X8")
        end
        return tex
    end
    local function ChipDotColor(isClassBtn)
        if isClassBtn then
            local _, classToken = UnitClass("player")
            local c = classToken and ((C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classToken))
                or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]))
            if c then return c.r, c.g, c.b end
        end
        local accent = KT.db.profile.skin and KT.db.profile.skin.accentColor
        if accent then return accent.r or 1, accent.g or 1, accent.b or 1 end
        return KT_COLOR[1], KT_COLOR[2], KT_COLOR[3]
    end

    local chipAnchor
    local function CreateExtraButton(label, isClassBtn)
        local btn = CreateFrame("Button", nil, content)
        btn:SetHeight(CHIP_H)
        btn.fill = PillTexture(btn, "BACKGROUND", "round12.png")
        btn.edge = PillTexture(btn, "BORDER", "round12_edge.png")
        btn.dot = btn:CreateTexture(nil, "ARTWORK")
        btn.dot:SetTexture(HINT .. "disc.png")
        btn.dot:SetSize(9, 9)
        btn.dot:SetPoint("LEFT", CHIP_PAD - 2, 0)

        local fs = btn:CreateFontString(nil, "OVERLAY")
        fs:SetFont(GetKTFont(), 11, "")
        fs:SetPoint("LEFT", btn.dot, "RIGHT", 6, 0)
        fs:SetText(label)
        fs:SetWordWrap(false)
        local textWidth = fs:GetStringWidth() or 0
        if textWidth < 1 then textWidth = 7 * #label end
        btn:SetWidth(CHIP_PAD - 2 + 9 + 6 + textWidth + CHIP_PAD)
        btn.label = fs

        -- Right to left: the first chip created sits at the right edge.
        if chipAnchor then
            btn:SetPoint("RIGHT", chipAnchor, "LEFT", -CHIP_GAP, 0)
        else
            btn:SetPoint("RIGHT", content, "TOP", contentWidth / 2, accentTop - 6)
        end
        chipAnchor = btn

        local function UpdateState()
            local selected = isClassBtn and isClass or (not isClassBtn and isCustom)
            local r, g, b = KT_COLOR[1], KT_COLOR[2], KT_COLOR[3]
            local hover = btn:IsMouseOver()
            if selected then
                btn.fill:SetVertexColor(r * 0.35, g * 0.35, b * 0.35, 0.95)
                btn.edge:SetVertexColor(r, g, b, 1)
                fs:SetTextColor(1, 1, 1)
            else
                local lift = hover and 0.16 or 0.10
                btn.fill:SetVertexColor(lift, lift, lift, 0.9)
                btn.edge:SetVertexColor(1, 1, 1, hover and 0.35 or 0.16)
                fs:SetTextColor(hover and 0.95 or 0.70, hover and 0.95 or 0.70, hover and 0.95 or 0.70)
            end
            btn.dot:SetVertexColor(ChipDotColor(isClassBtn))
        end
        btn.UpdateState = UpdateState
        UpdateState()

        btn:SetScript("OnClick", function()
            local skin = KT.db.profile.skin
            KT.db.profile.castbar = KT.db.profile.castbar or {}
            KT.db.profile.castbar.colorMode = "THEME"
            if isClassBtn then
                skin.kullthranUIColorByClass = true
                skin.borderTheme = "CLASS"
            else
                skin.kullthranUIColorByClass = false
                skin.borderTheme = "CUSTOM"
            end
            if KT.SyncSmartStyleDerivedTargets then KT.SyncSmartStyleDerivedTargets() end
            if KT.RefreshStylePalette then KT:RefreshStylePalette() end
            if KT.MenuPrincipal and KT.MenuPrincipal.RefreshTheme then
                KT.MenuPrincipal:RefreshTheme()
            end
            if KT.RefreshPage then
                KT:RefreshPage(true)
            end
            if KT.GetModule then
                local cb = KT:GetModule("CastBar", true)
                if cb and cb.Refresh then cb:Refresh("ApplySettings") end
            end
            UpdateAllButtons()
            Mod:UpdateKTColor()
        end)
        btn:SetScript("OnEnter", UpdateState)
        btn:SetScript("OnLeave", UpdateState)
        table.insert(buttons, btn)
    end

    CreateExtraButton(LText("Custom Color"), false)
    CreateExtraButton(LText("Class Color"), true)

    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() ClearResume(); self:ShowGlobalFontStep() end)

    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() ClearResume(); self:ShowProfileStep() end)

    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)

    local chk = CreateSkipCheckbox(content, btnSkip)
    content.skipChk = chk
    btnSkip:SetScript("OnClick", function()
        ClearResume()
        if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end
        self.frame:Hide()
    end)
end

function Mod:ShowGlobalFontStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 4
    self:UpdateProgressBar(4)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content
    
    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(L["Global Font"])
    title:SetTextColor(unpack(KT_COLOR))
    
    local desc = content:CreateFontString(nil, "OVERLAY")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -10)
    desc:SetWidth(600)
    desc:SetFont(GetKTFont(), 14)
    desc:SetText(L["Select the main font for the entire UI.\nChanges apply immediately to most elements."])
    desc:SetTextColor(0.9, 0.9, 0.9)
    desc:SetJustifyH("CENTER")

    -- ScrollFrame Container
    local scrollContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    scrollContainer:SetPoint("TOPLEFT", 50, -100)
    scrollContainer:SetPoint("BOTTOMRIGHT", -50, 96)
    CreateBackdrop(scrollContainer)
    scrollContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    
    local scroll = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 5, -5)
    scroll:SetPoint("BOTTOMRIGHT", -25, 5)
    
    local scrollBar = scroll.ScrollBar
    if scrollBar then
        local thumbtack = scrollBar:GetThumbTexture()
        if thumbtack then 
            thumbtack:SetColorTexture(unpack(KT_COLOR))
            thumbtack:SetHeight(30)
        end 
    end

    local CONTENT_WIDTH = 670
    local child = CreateFrame("Frame")
    child:SetSize(CONTENT_WIDTH, 1)
    scroll:SetScrollChild(child)

    local LSM = LibStub("LibSharedMedia-3.0", true)
    local fonts = LSM and LSM:List("font") or {"Friz Quadrata TT"}
    local GF = KT:GetModule("GlobalFont", true)
    local currentFont = KT.db.profile.globalFont.font
    
    local y = 0
    for i, fontName in ipairs(fonts) do
        local btn = CreateFrame("Button", nil, child, "BackdropTemplate")
        btn:SetSize(CONTENT_WIDTH, 30)
        btn:SetPoint("TOPLEFT", 0, y)
        
        if i % 2 == 0 then
            local bg = btn:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end
        
        local text = btn:CreateFontString(nil, "OVERLAY")
        text:SetPoint("LEFT", 10, 0)
        local fontPath = LSM and LSM:Fetch("font", fontName)
        if fontPath then text:SetFont(fontPath, 14) else text:SetFont(GetKTFont(), 14) end
        text:SetText(fontName == "Friz Quadrata TT" and "Friz Quadrata TT (Blizzard)" or fontName)
        btn.text = text
        
        local check = btn:CreateTexture(nil, "ARTWORK")
        check:SetSize(16, 16)
        check:SetPoint("RIGHT", -10, 0)
        check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
        check:SetVertexColor(unpack(KT_COLOR))
        check:Hide()
        btn.check = check
        
        if fontName == currentFont then 
            check:Show()
            text:SetTextColor(unpack(KT_COLOR))
        else
            text:SetTextColor(1, 1, 1)
        end
        
        btn:SetScript("OnClick", function()
            if GF then GF:SetFont(fontName) end
            currentFont = fontName
            for _, b in ipairs({child:GetChildren()}) do 
                if b.check then b.check:Hide() end 
                if b.text then b.text:SetTextColor(1, 1, 1) end
            end
            check:Show()
            text:SetTextColor(unpack(KT_COLOR))
            
            local newFontPath = LSM and LSM:Fetch("font", fontName) or GetKTFont()
            if title then title:SetFont(newFontPath, 24, "OUTLINE") end
            if desc then desc:SetFont(newFontPath, 14) end
            if btnNext and btnNext:GetFontString() then btnNext:GetFontString():SetFont(newFontPath, 12, "OUTLINE") end
            if btnBack and btnBack:GetFontString() then btnBack:GetFontString():SetFont(newFontPath, 12, "OUTLINE") end
        end)
        
        btn:SetScript("OnEnter", function(self) text:SetTextColor(unpack(KT_COLOR)) end)
        btn:SetScript("OnLeave", function(self) 
            if currentFont == fontName then
                text:SetTextColor(unpack(KT_COLOR))
            else
                text:SetTextColor(1, 1, 1) 
            end
        end)
        
        y = y - 30
    end
    child:SetHeight(-y)
    
    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() self:ShowSkinStep() end)
    
    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowThemeStep() end)
    
    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)
    
    local chk = CreateSkipCheckbox(content, btnSkip)
    btnSkip:SetScript("OnClick", function() if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end self.frame:Hide() end)
end

function Mod:ShowSkinStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 5
    self:UpdateProgressBar(5)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content
    
    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(L["Interface Style"])
    title:SetTextColor(unpack(KT_COLOR))
    
    -- Image
    local tex = content:CreateTexture(nil, "ARTWORK")
    tex:SetSize(512, 256)
    tex:SetPoint("TOP", title, "BOTTOM", 0, -10)
    tex:SetTexture(ICON_PATH .. "KUISkins.png")
    
    local text = content:CreateFontString(nil, "OVERLAY")
    text:SetPoint("TOP", tex, "BOTTOM", 0, -10)
    text:SetWidth(600)
    text:SetFont(GetKTFont(), 14)
    text:SetText(L["Choose your preferred visual style.\nKUI Skins applies a dark, minimalist theme to all Blizzard windows."])
    text:SetTextColor(0.9, 0.9, 0.9)
    text:SetJustifyH("CENTER")
    
    -- Buttons
    local btnEnable = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnEnable:SetSize(200, 40)
    btnEnable:SetPoint("TOPLEFT", content, "CENTER", 10, -100)
    btnEnable:SetText(L["Enable KUI Skins"])
    SkinButton(btnEnable)
    
    local btnDisable = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnDisable:SetSize(200, 40)
    btnDisable:SetPoint("TOPRIGHT", content, "CENTER", -10, -100)
    btnDisable:SetText(L["Blizzard Default"])
    SkinButton(btnDisable)

    local colorLabel = content:CreateFontString(nil, "OVERLAY")
    colorLabel:SetPoint("TOP", content, "CENTER", 0, -154)
    colorLabel:SetFont(GetKTFont(), 13, "OUTLINE")
    colorLabel:SetText(L["Blizzard window accent"])
    colorLabel:SetTextColor(0.86, 0.86, 0.90)

    local btnThemeAccent = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnThemeAccent:SetSize(200, 32)
    btnThemeAccent:SetPoint("TOPRIGHT", colorLabel, "BOTTOM", -5, -8)
    btnThemeAccent:SetText(L["Use theme accent"])
    SkinButton(btnThemeAccent)

    local btnClassicYellow = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnClassicYellow:SetSize(200, 32)
    btnClassicYellow:SetPoint("TOPLEFT", colorLabel, "BOTTOM", 5, -8)
    btnClassicYellow:SetText(L["Classic Blizzard yellow"])
    SkinButton(btnClassicYellow)

    local btnWindowBorders = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnWindowBorders:SetSize(240, 28)
    btnWindowBorders:SetPoint("TOP", colorLabel, "BOTTOM", 0, -48)
    SkinButton(btnWindowBorders)
    
    local function UpdateButtons()
        KT.db.profile.skin.blizzard = KT.db.profile.skin.blizzard or {}
        local enabled = KT.db.profile.skin.enable
        if enabled then
            btnEnable:SetBackdropBorderColor(unpack(KT_COLOR))
            btnDisable:SetBackdropBorderColor(unpack(COLOR_BORDER))
        else
            btnEnable:SetBackdropBorderColor(unpack(COLOR_BORDER))
            btnDisable:SetBackdropBorderColor(unpack(KT_COLOR))
        end

        local classicYellow = KT.db.profile.skin.blizzard.classicYellowAccent == true
        if classicYellow then
            btnThemeAccent:SetBackdropBorderColor(unpack(COLOR_BORDER))
            btnClassicYellow:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            btnThemeAccent:SetBackdropBorderColor(unpack(KT_COLOR))
            btnClassicYellow:SetBackdropBorderColor(unpack(COLOR_BORDER))
        end

        local showWindowBorders = KT.db.profile.skin.blizzard.showWindowBorders ~= false
        btnWindowBorders:SetText(showWindowBorders and L["Window borders: On"] or L["Window borders: Off"])
        if showWindowBorders then
            btnWindowBorders:SetBackdropBorderColor(unpack(KT_COLOR))
        else
            btnWindowBorders:SetBackdropBorderColor(unpack(COLOR_BORDER))
        end
    end
    
    btnEnable:SetScript("OnClick", function()
        KT.db.profile.skin.enable = true
        KT.db.profile.skin.blizzard = KT.db.profile.skin.blizzard or {}
        KT.db.profile.skin.blizzard.enable = true
        UpdateButtons()
        self:DeferReload(5)
    end)
    
    btnDisable:SetScript("OnClick", function()
        KT.db.profile.skin.enable = false
        UpdateButtons()
        self:DeferReload(5)
    end)

    btnThemeAccent:SetScript("OnClick", function()
        KT.db.profile.skin.blizzard.classicYellowAccent = false
        UpdateButtons()
        local skins = KT:GetModule("Skins", true)
        if skins and skins.RefreshBlizzardAccent then skins:RefreshBlizzardAccent() end
    end)

    btnClassicYellow:SetScript("OnClick", function()
        KT.db.profile.skin.blizzard.classicYellowAccent = true
        UpdateButtons()
        local skins = KT:GetModule("Skins", true)
        if skins and skins.RefreshBlizzardAccent then skins:RefreshBlizzardAccent() end
    end)

    btnWindowBorders:SetScript("OnClick", function()
        KT.db.profile.skin.blizzard.showWindowBorders = not (KT.db.profile.skin.blizzard.showWindowBorders ~= false)
        UpdateButtons()
        local skins = KT:GetModule("Skins", true)
        if skins and skins.RefreshBlizzardWindowBorders then skins:RefreshBlizzardWindowBorders() end
    end)
    
    UpdateButtons()
    
    -- Navigation
    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() self:ShowButtonStyleStep() end)
    
    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowGlobalFontStep() end)
    
    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)
    
    local chk = CreateSkipCheckbox(content, btnSkip)
    
    btnSkip:SetScript("OnClick", function() 
        if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end
        self.frame:Hide()
    end)
end

function Mod:ShowButtonStyleStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 6
    self:UpdateProgressBar(6)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content
    
    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -20)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(L["Visual Style"])
    title:SetTextColor(unpack(KT_COLOR))

    local styleFrame = CreateFrame("Frame", nil, content)
    styleFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
    styleFrame:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -2)
    styleFrame:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 0, 90)
    styleFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 90)

    local PREVIEW_SMP = "Interface\\AddOns\\KullThranUI\\Modules\\SimplicityTextures\\"
    local PREVIEW_SHAPE_MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
    local PREVIEW_SHAPE_MASKS = {
        CIRCLE = PREVIEW_SHAPE_MEDIA .. "circle_mask.tga",
        CSQUARE = PREVIEW_SHAPE_MEDIA .. "csquare_mask.tga",
        HEXAGON = PREVIEW_SHAPE_MEDIA .. "hexagon_mask.tga",
        DIAMOND = PREVIEW_SHAPE_MEDIA .. "diamond_mask.tga",
        SHIELD = PREVIEW_SHAPE_MEDIA .. "shield_mask.tga",
    }
    local PREVIEW_SHAPE_BORDERS = {
        CIRCLE = PREVIEW_SHAPE_MEDIA .. "circle_border.tga",
        CSQUARE = PREVIEW_SHAPE_MEDIA .. "csquare_border.tga",
        HEXAGON = PREVIEW_SHAPE_MEDIA .. "hexagon_border.tga",
        DIAMOND = PREVIEW_SHAPE_MEDIA .. "diamond_border.tga",
        SHIELD = PREVIEW_SHAPE_MEDIA .. "shield_border.tga",
    }

    -- Shape borders wear the accent: dimmed at rest, full when chosen or
    -- hovered.
    local SHAPE_IDLE_ALPHA = 0.5
    local function ShapeIdleColor()
        return KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], SHAPE_IDLE_ALPHA
    end
    local divider = styleFrame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(1, 1, 1, 0.08)
    divider:SetPoint("TOP", styleFrame, "TOP", 0, -78)
    divider:SetSize(1, 320)

    local function ClearInstallerPreviewShape(frame)
        if not frame then
            return
        end

        if frame.KT_InstallerMasks then
            local cooldown = frame.Cooldown or frame.cooldown
            local targets = { frame.Icon, frame.KT_PreviewFill, cooldown }
            for _, mask in ipairs(frame.KT_InstallerMasks) do
                for _, target in ipairs(targets) do
                    if target and target.RemoveMaskTexture then
                        pcall(target.RemoveMaskTexture, target, mask)
                    end
                end
                mask:Hide()
            end
        end
        frame.KT_InstallerMasks = {}

        local cooldown = frame.Cooldown or frame.cooldown
        if cooldown then
            if cooldown.SetSwipeTexture then pcall(cooldown.SetSwipeTexture, cooldown, "") end
            if cooldown.SetUseCircularEdge then pcall(cooldown.SetUseCircularEdge, cooldown, false) end
        end

        if frame.KT_PreviewShapeBorder then
            frame.KT_PreviewShapeBorder:Hide()
        end
    end

    local function HideInstallerPreviewSquareBorder(frame)
        if frame and frame._ktBorderFrame then
            frame._ktBorderFrame:Hide()
        end
    end

    local function RenderInstallerShapePreview(frame, borderR, borderG, borderB)
        if not frame or not frame.Icon then
            return
        end

        local style = ((frame.KT_PreviewStyleOverride or "BLIZZARD"):upper())
        local shape = ((frame.KT_PreviewShapeOverride or "NONE"):upper())
        local colorR, colorG, colorB = borderR or 0, borderG or 0, borderB or 0
        local normal = frame.GetNormalTexture and frame:GetNormalTexture() or nil
        local nativeBorder = frame.Border or (frame.GetName and _G[frame:GetName() .. "Border"]) or nil
        local cooldown = frame.Cooldown or frame.cooldown

        frame.KT_PreviewFill = frame.KT_PreviewFill or frame:CreateTexture(nil, "BACKGROUND", nil, -5)
        frame.KT_PreviewSquareArt = frame.KT_PreviewSquareArt or frame:CreateTexture(nil, "OVERLAY", nil, 0)
        frame.KT_PreviewShapeBorder = frame.KT_PreviewShapeBorder or frame:CreateTexture(nil, "OVERLAY", nil, 1)

        ClearInstallerPreviewShape(frame)
        frame.KT_PreviewSquareArt:Hide()
        HideInstallerPreviewSquareBorder(frame)

        frame.Icon:ClearAllPoints()
        frame.Icon:SetVertexColor(1, 1, 1, 1)
        frame.Icon:SetAlpha(1)
        frame.Icon:Show()
        frame.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if frame.Icon.SetDesaturated then
            frame.Icon:SetDesaturated(false)
        end

        if style == "BLIZZARD" then
            if normal then
                normal:SetAlpha(1)
            end
            if nativeBorder then
                nativeBorder:SetAlpha(1)
            end
            frame.KT_PreviewFill:Hide()
            KT:AddBorder(frame, colorR, colorG, colorB, 1)
            frame.Icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            frame.Icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            return
        end

        if normal then
            normal:SetAlpha(0)
        end
        if nativeBorder then
            nativeBorder:SetAlpha(0)
        end

        if style == "SIMPLICITY" then
            frame.KT_PreviewFill:SetTexture(PREVIEW_SMP .. "Backdrop")
            frame.KT_PreviewFill:SetVertexColor(0, 0, 0, 1)
            frame.KT_PreviewFill:ClearAllPoints()
            frame.KT_PreviewFill:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
            frame.KT_PreviewFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
            frame.KT_PreviewFill:Show()

            frame.Icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
            frame.Icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)

            if shape == "NONE" then
                frame.KT_PreviewSquareArt:SetTexture(PREVIEW_SMP .. "Normal")
                frame.KT_PreviewSquareArt:SetVertexColor(colorR, colorG, colorB, 1)
                frame.KT_PreviewSquareArt:ClearAllPoints()
                frame.KT_PreviewSquareArt:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
                frame.KT_PreviewSquareArt:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
                frame.KT_PreviewSquareArt:Show()
                return
            end
        else
            frame.KT_PreviewFill:SetTexture("Interface\\Buttons\\WHITE8x8")
            frame.KT_PreviewFill:SetVertexColor(0, 0, 0, 0.85)
            frame.KT_PreviewFill:ClearAllPoints()
            frame.KT_PreviewFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            frame.KT_PreviewFill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
            frame.KT_PreviewFill:Show()

            frame.Icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
            frame.Icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

            if shape == "NONE" then
                KT:AddBorder(frame, colorR, colorG, colorB, 1)
                return
            end
        end

        local maskPath = PREVIEW_SHAPE_MASKS[shape]
        local borderPath = PREVIEW_SHAPE_BORDERS[shape]
        if not maskPath or not borderPath then
            KT:AddBorder(frame, colorR, colorG, colorB, 1)
            return
        end

        -- MaskTexture support differs between retail UI builds. Do not let
        -- one unavailable preview API abort the complete installer page.
        local okMask, mask = pcall(frame.CreateMaskTexture, frame)
        if not okMask or not mask then
            KT:AddBorder(frame, colorR, colorG, colorB, 1)
            return
        end

        local okTexture = pcall(mask.SetTexture, mask, maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if not okTexture then
            if mask.Hide then mask:Hide() end
            KT:AddBorder(frame, colorR, colorG, colorB, 1)
            return
        end

        local okPoints = pcall(mask.SetAllPoints, mask, frame)
        if not okPoints then
            if mask.Hide then mask:Hide() end
            KT:AddBorder(frame, colorR, colorG, colorB, 1)
            return
        end
        frame.KT_InstallerMasks = { mask }

        for _, target in ipairs({ frame.Icon, frame.KT_PreviewFill, cooldown }) do
            if target and target.AddMaskTexture then
                pcall(target.AddMaskTexture, target, mask)
            end
        end

        frame.KT_PreviewShapeBorder:SetTexture(borderPath)
        frame.KT_PreviewShapeBorder:SetVertexColor(colorR, colorG, colorB, 1)
        frame.KT_PreviewShapeBorder:ClearAllPoints()
        if style == "SIMPLICITY" then
            frame.KT_PreviewShapeBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
            frame.KT_PreviewShapeBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
        else
            frame.KT_PreviewShapeBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
            frame.KT_PreviewShapeBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, -1)
        end
        frame.KT_PreviewShapeBorder:Show()

        if cooldown then
            if cooldown.SetDrawSwipe then pcall(cooldown.SetDrawSwipe, cooldown, true) end
            if cooldown.SetUseCircularEdge then pcall(cooldown.SetUseCircularEdge, cooldown, shape ~= "CSQUARE") end
            if cooldown.SetSwipeTexture then pcall(cooldown.SetSwipeTexture, cooldown, maskPath) end
        end
    end

    local function EnsureInstallerShapeMask(frame)
        if not frame or not frame.Icon then
            return
        end

        local shape = ((frame.KT_PreviewShapeOverride or "NONE"):upper())
        local maskPath = PREVIEW_SHAPE_MASKS[shape]
        local borderPath = PREVIEW_SHAPE_BORDERS[shape]
        if not maskPath or not borderPath then
            return
        end

        if frame.KT_InstallerMasks then
            local cooldown = frame.Cooldown or frame.cooldown
            for _, oldMask in ipairs(frame.KT_InstallerMasks) do
                for _, target in ipairs({ frame.Icon, frame.KT_PreviewFill, cooldown }) do
                    if target and target.RemoveMaskTexture then
                        pcall(target.RemoveMaskTexture, target, oldMask)
                    end
                end
                pcall(oldMask.Hide, oldMask)
            end
        end

        local okMask, mask = pcall(frame.CreateMaskTexture, frame)
        if not okMask or not mask then
            return
        end
        local okTexture = pcall(mask.SetTexture, mask, maskPath,
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if not okTexture then
            return
        end
        pcall(mask.SetAllPoints, mask, frame)
        frame.KT_InstallerMasks = { mask }

        for _, target in ipairs({ frame.Icon, frame.KT_PreviewFill, frame.Cooldown or frame.cooldown }) do
            if target and target.AddMaskTexture then
                pcall(target.AddMaskTexture, target, mask)
            end
        end

        frame.KT_PreviewShapeBorder = frame.KT_PreviewShapeBorder
            or frame:CreateTexture(nil, "OVERLAY", nil, 1)
        frame.KT_PreviewShapeBorder:SetTexture(borderPath)
        frame.KT_PreviewShapeBorder:SetVertexColor(0, 0, 0, 1)
        frame.KT_PreviewShapeBorder:ClearAllPoints()
        frame.KT_PreviewShapeBorder:SetPoint("TOPLEFT", frame, "TOPLEFT", -2, 2)
        frame.KT_PreviewShapeBorder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 2, -2)
        frame.KT_PreviewShapeBorder:Show()

        local cooldown = frame.Cooldown or frame.cooldown
        if cooldown then
            if cooldown.SetDrawSwipe then pcall(cooldown.SetDrawSwipe, cooldown, true) end
            if cooldown.SetUseCircularEdge then
                pcall(cooldown.SetUseCircularEdge, cooldown, shape ~= "CSQUARE")
            end
            if cooldown.SetSwipeTexture then
                pcall(cooldown.SetSwipeTexture, cooldown, maskPath)
            end
        end
    end
    local function SafeRenderInstallerShapePreview(frame, borderR, borderG, borderB)
        local ok = pcall(RenderInstallerShapePreview, frame, borderR, borderG, borderB)
        pcall(EnsureInstallerShapeMask, frame)
        if ok then
            return
        end

        -- A preview is optional; never let one unsupported shape stop the
        -- rest of the installer page from being created.
        pcall(ClearInstallerPreviewShape, frame)
        if frame and frame.Icon then
            pcall(frame.Icon.ClearAllPoints, frame.Icon)
            pcall(frame.Icon.SetAllPoints, frame.Icon, frame)
            pcall(frame.Icon.SetTexCoord, frame.Icon, 0.08, 0.92, 0.08, 0.92)
            pcall(frame.Icon.SetAlpha, frame.Icon, 1)
            pcall(frame.Icon.Show, frame.Icon)
        end

        local shape = frame and frame.KT_PreviewShapeOverride and frame.KT_PreviewShapeOverride:upper()
        local borderPath = shape and PREVIEW_SHAPE_BORDERS[shape]
        if borderPath and frame.KT_PreviewShapeBorder then
            pcall(frame.KT_PreviewShapeBorder.SetTexture, frame.KT_PreviewShapeBorder, borderPath)
            pcall(frame.KT_PreviewShapeBorder.SetAllPoints, frame.KT_PreviewShapeBorder, frame)
            pcall(frame.KT_PreviewShapeBorder.Show, frame.KT_PreviewShapeBorder)
        end
        pcall(EnsureInstallerShapeMask, frame)
    end
    local function EnsureInstallerPreviewIcon(frame)
        if not frame then
            return nil
        end

        local icon = frame.Icon or (frame.GetName and _G[frame:GetName() .. "Icon"]) or frame.icon
        if not icon then
            icon = frame:CreateTexture(nil, "ARTWORK")
            icon:SetDrawLayer("ARTWORK", 1)
        end

        frame.Icon = icon
        icon:ClearAllPoints()
        icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetVertexColor(1, 1, 1, 1)
        icon:SetAlpha(1)
        icon:Show()
        return icon
    end
    
    -- 1. ACTION BARS
    local abHeader = styleFrame:CreateFontString(nil, "OVERLAY")
    abHeader:SetPoint("TOP", styleFrame, "TOP", -200, -78)
    abHeader:SetFont(GetKTFont(), 16, "OUTLINE")
    abHeader:SetText(L["Action Bars"])
    abHeader:SetTextColor(0.9, 0.9, 0.9)

    -- 1.1 LIVE PREVIEW FRAME (ACTION BARS)
    local abPreview = CreateFrame("Frame", nil, styleFrame, "BackdropTemplate")
    abPreview:SetSize(320, 48)
    abPreview:SetPoint("TOP", abHeader, "BOTTOM", 0, -4)
    CreateBackdrop(abPreview)
    abPreview:SetBackdropColor(0.02, 0.02, 0.025, 0.92)
    abPreview:SetBackdropBorderColor(unpack(COLOR_BORDER))
    
    local classPreviewSpells = select(1, GetInstallerPlayerClassPreviewData())
    local actionBarSpellIDs = {}
    local actionBarSpellSeen = {}
    local function AddActionBarSpellIDs(source)
        for _, spellID in ipairs(source or {}) do
            if spellID and not actionBarSpellSeen[spellID] then
                actionBarSpellSeen[spellID] = true
                actionBarSpellIDs[#actionBarSpellIDs + 1] = spellID
            end
        end
    end
    AddActionBarSpellIDs(classPreviewSpells and classPreviewSpells.cooldowns)
    AddActionBarSpellIDs(classPreviewSpells and classPreviewSpells.utility)

    local actionBarFallbackIDs = {
        6603, 100, 772, 355, 7384, 6552, 6343, 1715,
        23881, 1464, 2565, 23922, 5308, 78, 5246, 1766,
        133, 686, 116, 2061,
    }
    local actionBarPreviewTextures = {}
    local actionBarPreviewTextureSeen = {}
    local function AddActionBarPreviewSpell(spellID)
        if not spellID then return end
        local texture = GetInstallerSpellTexture(spellID, "Interface\\Icons\\INV_Misc_QuestionMark")
        local key = type(texture) .. ":" .. tostring(texture)
        if texture and texture ~= "Interface\\Icons\\INV_Misc_QuestionMark" and not actionBarPreviewTextureSeen[key] then
            actionBarPreviewTextureSeen[key] = true
            actionBarPreviewTextures[#actionBarPreviewTextures + 1] = texture
        end
    end
    -- Real icons from the character's own action bars come first.
    if _G.GetActionTexture then
        for slot = 1, 24 do
            if #actionBarPreviewTextures >= 8 then break end
            local ok, texture = pcall(_G.GetActionTexture, slot)
            if ok and texture then
                local key = type(texture) .. ":" .. tostring(texture)
                if not actionBarPreviewTextureSeen[key] then
                    actionBarPreviewTextureSeen[key] = true
                    actionBarPreviewTextures[#actionBarPreviewTextures + 1] = texture
                end
            end
        end
    end
    for _, spellID in ipairs(actionBarSpellIDs) do
        AddActionBarPreviewSpell(spellID)
    end
    for _, spellID in ipairs(actionBarFallbackIDs) do
        if #actionBarPreviewTextures >= 8 then break end
        AddActionBarPreviewSpell(spellID)
    end
    local actionBarStaticTextures = {
        "Interface\\Icons\\Ability_Warrior_Charge",
        "Interface\\Icons\\Ability_Rogue_Sprint",
        "Interface\\Icons\\Spell_Nature_Lightning",
        "Interface\\Icons\\Spell_Fire_FlameBolt",
        "Interface\\Icons\\Spell_Shadow_ShadowBolt",
        "Interface\\Icons\\Spell_Holy_HolyBolt",
        "Interface\\Icons\\Ability_Druid_Dash",
        "Interface\\Icons\\Ability_Hunter_BeastCall",
    }
    for _, texture in ipairs(actionBarStaticTextures) do
        if #actionBarPreviewTextures >= 8 then break end
        local key = type(texture) .. ":" .. tostring(texture)
        if not actionBarPreviewTextureSeen[key] then
            actionBarPreviewTextureSeen[key] = true
            actionBarPreviewTextures[#actionBarPreviewTextures + 1] = texture
        end
    end
    while #actionBarPreviewTextures < 8 do
        actionBarPreviewTextures[#actionBarPreviewTextures + 1] = actionBarStaticTextures[((#actionBarPreviewTextures - 1) % #actionBarStaticTextures) + 1]
    end
    -- Typical self-buffs per class; debuffs a player can really carry.
    local CLASS_BUFF_SPELLS = {
        WARRIOR = { 6673, 18499, 97462, 3411 },
        PALADIN = { 465, 642, 1022, 31884 },
        HUNTER = { 5118, 186257, 19574, 109304 },
        ROGUE = { 2983, 1784, 5277, 1966 },
        PRIEST = { 21562, 17, 586, 2096 },
        DEATHKNIGHT = { 48707, 3714, 48792, 49039 },
        SHAMAN = { 2645, 546, 974, 192106 },
        MAGE = { 1459, 66, 45438, 12472 },
        WARLOCK = { 5697, 687, 20707, 104773 },
        MONK = { 116841, 101643, 119085, 122278 },
        DRUID = { 1126, 768, 5487, 22812 },
        DEMONHUNTER = { 188501, 162264, 198589, 196718 },
        EVOKER = { 358267, 364342, 363916, 374348 },
    }
    local GENERIC_BUFF_SPELLS = { 1459, 6673, 1126, 21562 }
    local QUESTION_MARK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
    local function ResolveClassAuraSpells(preferred, generic)
        local resolved, seen = {}, {}
        for _, list in ipairs({ preferred or {}, generic }) do
            for _, spellID in ipairs(list) do
                if #resolved >= 4 then break end
                if not seen[spellID] and GetInstallerSpellTexture(spellID, QUESTION_MARK_ICON) ~= QUESTION_MARK_ICON then
                    seen[spellID] = true
                    resolved[#resolved + 1] = spellID
                end
            end
        end
        while #resolved < 4 do resolved[#resolved + 1] = generic[#resolved + 1] or generic[1] end
        return resolved
    end
    local _, previewClassToken = UnitClass("player")
    local buffPreviewSpellIDs = ResolveClassAuraSpells(CLASS_BUFF_SPELLS[previewClassToken], GENERIC_BUFF_SPELLS)
    local debuffPreviewSpellIDs = ResolveClassAuraSpells({ 57723, 25771, 6788, 11196 }, { 589, 980, 172, 55095 })
    local buffPreviewTextures, debuffPreviewTextures = {}, {}
    for i, spellID in ipairs(buffPreviewSpellIDs) do
        buffPreviewTextures[i] = GetInstallerSpellTexture(spellID, "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    for i, spellID in ipairs(debuffPreviewSpellIDs) do
        debuffPreviewTextures[i] = GetInstallerSpellTexture(spellID, "Interface\\Icons\\INV_Misc_QuestionMark")
    end
    local buffDebuffPreviewTextures = {
        buffPreviewTextures[1], buffPreviewTextures[2],
        debuffPreviewTextures[1], debuffPreviewTextures[2],
        buffPreviewTextures[3], debuffPreviewTextures[3],
    }
    abPreview.buttons = {}
    for i = 1, 8 do
        local btn = CreateFrame("Frame", nil, abPreview, "BackdropTemplate")
        btn:SetSize(34, 34)
        btn:SetPoint("CENTER", abPreview, "CENTER", (i - 4.5) * 37, 0)
        btn:SetFrameLevel(abPreview:GetFrameLevel() + 2)

        btn.Icon = btn:CreateTexture(nil, "ARTWORK")
        btn.Icon:SetAllPoints(btn)
        btn.KT_PreviewIconTexture = actionBarPreviewTextures[i]
        btn.Icon:SetTexture(btn.KT_PreviewIconTexture)
        btn.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        btn.Cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.Cooldown:SetAllPoints(btn)
        if btn.Cooldown.SetDrawSwipe then btn.Cooldown:SetDrawSwipe(true) end
        if btn.Cooldown.SetCooldown then btn.Cooldown:SetCooldown(GetTime() - 5, 20) end

        local hotKey = btn:CreateFontString(nil, "OVERLAY")
        hotKey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -1)
        hotKey:SetFont(GetKTFont(), 9, "OUTLINE")
        hotKey:SetText(tostring(i))
        hotKey:SetTextColor(1, 1, 1, 1)

        if i == 1 then
            local macro = btn:CreateFontString(nil, "OVERLAY")
            macro:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 2, 2)
            macro:SetFont(GetKTFont(), 7, "OUTLINE")
            macro:SetText(LText("Macro"))
            macro:SetTextColor(1, 1, 1, 1)
        end

        table.insert(abPreview.buttons, btn)
    end
    local function RefreshABPreview()
        local style = KT.db.profile.actionbars.buttonStyle or "BLIZZARD"
        local shape = KT.db.profile.actionbars.buttonShape or "NONE"
        for _, btn in ipairs(abPreview.buttons) do
            if btn.Icon then
                btn.Icon:SetTexture(btn.KT_PreviewIconTexture)
                btn.Icon:SetVertexColor(1, 1, 1, 1)
                btn.Icon:SetAlpha(1)
                btn.Icon:Show()
                btn.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                if btn.Icon.SetDesaturated then
                    btn.Icon:SetDesaturated(false)
                end
            end
            btn.KT_PreviewStyleOverride = style
            btn.KT_PreviewShapeOverride = shape
            SafeRenderInstallerShapePreview(btn, 0, 0, 0)
        end
    end
    
    -- Init Preview
    RefreshABPreview()

    local UpdateABShapeButtons
    local function CreateABBtn(label, style, xOffset)
        local btn = CreateFrame("Button", nil, styleFrame, "BackdropTemplate")
        btn:SetSize(116, 28)
        btn:SetPoint("TOP", abPreview, "BOTTOM", xOffset, -4)
        btn:SetText(LText(label))
        
        -- KUI cut-corner button; the accent border these steps paint on the
        -- chosen style holds its lit look (SkinButton).
        SkinButton(btn)
        
        btn:SetScript("OnClick", function()
            KT.db.profile.actionbars.buttonStyle = style
            RefreshABPreview()
            if UpdateABShapeButtons then UpdateABShapeButtons() end
            for _, b in ipairs({styleFrame:GetChildren()}) do
                if b.isABBtn then
                    if b == btn then
                        b:SetBackdropBorderColor(unpack(KT_COLOR))
                    else
                        b:SetBackdropBorderColor(unpack(COLOR_BORDER))
                    end
                end
            end
            self:DeferReload(6)
        end)
        
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
            self:SetBackdropBorderColor(unpack(KT_COLOR)) 
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(COLOR_BTN_NORMAL))
            if KT.db.profile.actionbars.buttonStyle == style then
                self:SetBackdropBorderColor(unpack(KT_COLOR))
            else
                self:SetBackdropBorderColor(unpack(COLOR_BORDER))
            end
        end)
        
        -- Initial State
        if KT.db.profile.actionbars.buttonStyle == style then
            btn:SetBackdropBorderColor(unpack(KT_COLOR))
        else
            btn:SetBackdropBorderColor(unpack(COLOR_BORDER))
        end
        
        btn.isABBtn = true
        return btn
    end
    
    local abBtnLeft = CreateABBtn("Blizzard", "BLIZZARD", -120)
    local abBtnMid = CreateABBtn("Modern KUI", "KUI", 0)
    local abBtnRight = CreateABBtn("Simplicity", "SIMPLICITY", 120)

    -- Shape selector (Action Bars)
    local abShapeHeader = styleFrame:CreateFontString(nil, "OVERLAY")
    abShapeHeader:SetPoint("TOP", abBtnMid, "BOTTOM", 0, -6)
    abShapeHeader:SetFont(GetKTFont(), 14, "OUTLINE")
    abShapeHeader:SetText(L["Shapes"])
    abShapeHeader:SetTextColor(0.85, 0.85, 0.85)

    UpdateABShapeButtons = function()
        local current = KT.db.profile.actionbars.buttonShape or "NONE"
        local enabled = (KT.db.profile.actionbars.buttonStyle or "BLIZZARD") ~= "BLIZZARD"
        for _, b in ipairs({styleFrame:GetChildren()}) do
            if b.isABShapeBtn then
                local selected = b.shapeValue == current
                if b.SetEnabled then b:SetEnabled(enabled) end
                if b.EnableMouse then b:EnableMouse(enabled) end
                b:SetAlpha(enabled and 1 or 0.42)
                if b.Icon and b.Icon.SetDesaturated then b.Icon:SetDesaturated(not enabled) end
                if b.KT_PreviewShapeBorder then
                    if enabled and (selected or b.KT_PreviewShapeHover) then
                        b.KT_PreviewShapeBorder:SetVertexColor(unpack(KT_COLOR))
                    else
                        b.KT_PreviewShapeBorder:SetVertexColor(ShapeIdleColor())
                    end
                end
                if b.shapeValue == "NONE" or not b.KT_PreviewShapeBorder then
                    if enabled and selected then b:SetBackdropBorderColor(unpack(KT_COLOR))
                    else b:SetBackdropBorderColor(ShapeIdleColor()) end
                else
                    b:SetBackdropBorderColor(0, 0, 0, 0)
                end
            end
        end
    end

    local function CreateABShapeBtn(label, shape, anchor, xOffset, yOffset, previewTexture)
        local btn = CreateFrame("Button", nil, styleFrame, "BackdropTemplate")
        btn:SetSize(64, 64)
        btn:SetPoint("TOP", anchor, "BOTTOM", xOffset, yOffset)
        CreateBackdrop(btn)
        btn:SetBackdropColor(0, 0, 0, 0)

        btn.Icon = btn:CreateTexture(nil, "ARTWORK")
        btn.Icon:SetPoint("TOPLEFT", 6, -6)
        btn.Icon:SetPoint("BOTTOMRIGHT", -6, 6)
        btn.Icon:SetTexture(previewTexture or actionBarPreviewTextures[1])
        btn.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.Cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.Cooldown:SetAllPoints(btn)
        if btn.Cooldown.SetDrawSwipe then btn.Cooldown:SetDrawSwipe(true) end
        if btn.Cooldown.SetCooldown then btn.Cooldown:SetCooldown(GetTime() - 5, 20) end
        btn.KT_PreviewStyleOverride = "SIMPLICITY"
        btn.KT_PreviewShapeOverride = shape
        btn.shapeValue = shape
        btn.isABShapeBtn = true

        local function RefreshShapeIcon()
            btn.KT_PreviewStyleOverride = "SIMPLICITY"
            btn.KT_PreviewShapeOverride = shape
            SafeRenderInstallerShapePreview(btn, KT_COLOR[1], KT_COLOR[2], KT_COLOR[3])
        end
        btn.KT_RefreshShapeIcon = RefreshShapeIcon
        RefreshShapeIcon()

        btn:SetScript("OnClick", function()
            if (not btn:IsEnabled()) or (KT.db.profile.actionbars.buttonStyle or "BLIZZARD") == "BLIZZARD" then
                return
            end
            KT.db.profile.actionbars.buttonShape = shape
            RefreshABPreview()
            UpdateABShapeButtons()
            self:DeferReload(6)
        end)

        btn:SetScript("OnEnter", function(self)
            if not self:IsEnabled() then return end
            self.KT_PreviewShapeHover = true
            self:SetBackdropColor(1, 1, 1, 0.06)
            if self.shapeValue == "NONE" or not self.KT_PreviewShapeBorder then
                self:SetBackdropBorderColor(unpack(KT_COLOR))
            else
                self:SetBackdropBorderColor(0, 0, 0, 0)
                self.KT_PreviewShapeBorder:SetVertexColor(unpack(KT_COLOR))
            end
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(LText(label))
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            self.KT_PreviewShapeHover = nil
            self:SetBackdropColor(0, 0, 0, 0)
            UpdateABShapeButtons()
            if GameTooltip then GameTooltip:Hide() end
        end)

        return btn
    end

    local abShapeRow1Left = CreateABShapeBtn("Square (Default)", "NONE", abShapeHeader, -84, -4, actionBarPreviewTextures[1])
    local abShapeRow1Mid = CreateABShapeBtn("Circle", "CIRCLE", abShapeHeader, 0, -4, actionBarPreviewTextures[2])
    local abShapeRow1Right = CreateABShapeBtn("Rounded Square", "CSQUARE", abShapeHeader, 84, -4, actionBarPreviewTextures[3])

    local abShapeRow2Mid = CreateABShapeBtn("Hexagon", "HEXAGON", abShapeRow1Mid, 0, -10, actionBarPreviewTextures[4])
    CreateABShapeBtn("Diamond", "DIAMOND", abShapeRow1Mid, 84, -10, actionBarPreviewTextures[5])
    CreateABShapeBtn("Shield", "SHIELD", abShapeRow1Mid, -84, -10, actionBarPreviewTextures[6])

    UpdateABShapeButtons()

    local keypressToggle = CreateFrame("CheckButton", nil, styleFrame, "BackdropTemplate")
    keypressToggle:SetSize(18, 18)
    keypressToggle:SetPoint("TOP", abShapeRow2Mid, "BOTTOM", -92, -10)
    CreateBackdrop(keypressToggle)
    keypressToggle:SetBackdropColor(0, 0, 0, 1)

    keypressToggle.Checked = keypressToggle:CreateTexture(nil, "ARTWORK")
    keypressToggle.Checked:SetTexture("Interface\\Buttons\\WHITE8x8")
    keypressToggle.Checked:SetVertexColor(unpack(KT_COLOR))
    keypressToggle.Checked:SetAllPoints(keypressToggle)
    
    local isChecked = KT.db.profile.actionbars.showKeypressIndicator ~= false
    keypressToggle.Checked:SetAlpha(isChecked and 1 or 0)
    keypressToggle:SetChecked(isChecked)

    local keypressLabel = keypressToggle:CreateFontString(nil, "OVERLAY")
    keypressLabel:SetPoint("LEFT", keypressToggle, "RIGHT", 6, 0)
    keypressLabel:SetFont(GetKTFont(), 12, "OUTLINE")
    keypressLabel:SetText(LText("Show Pressed Key Indicator"))
    keypressLabel:SetTextColor(0.85, 0.85, 0.85)

    keypressToggle:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        self.Checked:SetAlpha(v and 1 or 0)
        KT.db.profile.actionbars.showKeypressIndicator = v
    end)

    local abSectionEnd = CreateFrame("Frame", nil, styleFrame)
    abSectionEnd:SetSize(1, 1)
    abSectionEnd:SetPoint("TOP", abShapeRow2Mid, "BOTTOM", 0, -18)

    -- 2. BUFFS & DEBUFFS
    local bdHeader = styleFrame:CreateFontString(nil, "OVERLAY")
    bdHeader:SetPoint("TOP", styleFrame, "TOP", 200, -78)
    bdHeader:SetFont(GetKTFont(), 16, "OUTLINE")
    bdHeader:SetText(L["Buffs & Debuffs"])
    bdHeader:SetTextColor(0.9, 0.9, 0.9)

    -- 2.1 LIVE PREVIEW FRAME (BUFFS)
    local bdPreview = CreateFrame("Frame", nil, styleFrame, "BackdropTemplate")
    bdPreview:SetSize(320, 48)
    bdPreview:SetPoint("TOP", bdHeader, "BOTTOM", 0, -4)
    CreateBackdrop(bdPreview)
    bdPreview:SetBackdropColor(0.02, 0.02, 0.025, 0.92)
    bdPreview:SetBackdropBorderColor(unpack(COLOR_BORDER))
    
    bdPreview.icons = {}
    local sampleIcons = {
        buffPreviewTextures[1],
        buffPreviewTextures[2],
        debuffPreviewTextures[1],
        debuffPreviewTextures[2],
    }
    for i = 1, 4 do
        local f = CreateFrame("Frame", "KT_Installer_PreviewBD_"..i, bdPreview)
        f:SetSize(32, 32)
        f:SetPoint("CENTER", bdPreview, "CENTER", (i-2.5)*36, 0)
        f.Icon = f:CreateTexture(nil, "ARTWORK")
        f.Icon:SetAllPoints()
        f.Icon:SetTexture(sampleIcons[i])
        f.Icon:SetTexCoord(0.08,0.92,0.08,0.92)
        
        -- Add Count
        f.Count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        f.Count:SetPoint("BOTTOMRIGHT", 0, 0)
        f.Count:SetText(i > 1 and i or "")
        
        table.insert(bdPreview.icons, f)
    end
    
    local function RefreshBDPreview()
        local style = KT.db.profile.buffsAndDebuffs.style or "BLIZZARD"
        local shape = KT.db.profile.buffsAndDebuffs.shape or "NONE"
        for index, icon in ipairs(bdPreview.icons) do
            icon.KT_PreviewStyleOverride = style
            icon.KT_PreviewShapeOverride = shape
            if index > 2 then
                SafeRenderInstallerShapePreview(icon, 0.8, 0, 0) -- Debuff red border
            else
                SafeRenderInstallerShapePreview(icon, 0, 0, 0) -- Buff black border
            end
        end
    end
    
    RefreshBDPreview()

    local UpdateBDShapeButtons
    local function CreateBDBtn(label, style, xOffset)
        local btn = CreateFrame("Button", nil, styleFrame, "BackdropTemplate")
        btn:SetSize(116, 28)
        btn:SetPoint("TOP", bdPreview, "BOTTOM", xOffset, -4)
        btn:SetText(LText(label))
        
        -- KUI cut-corner button; the accent border these steps paint on the
        -- chosen style holds its lit look (SkinButton).
        SkinButton(btn)
        
        btn:SetScript("OnClick", function()
            KT.db.profile.buffsAndDebuffs.style = style
            RefreshBDPreview()
            if UpdateBDShapeButtons then UpdateBDShapeButtons() end
            for _, b in ipairs({styleFrame:GetChildren()}) do
                if b.isBDBtn then
                    if b == btn then
                        b:SetBackdropBorderColor(unpack(KT_COLOR))
                    else
                        b:SetBackdropBorderColor(unpack(COLOR_BORDER))
                    end
                end
            end
            self:DeferReload(6)
        end)
        
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(COLOR_BTN_HOVER))
            self:SetBackdropBorderColor(unpack(KT_COLOR)) 
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(COLOR_BTN_NORMAL))
            if KT.db.profile.buffsAndDebuffs.style == style then
                self:SetBackdropBorderColor(unpack(KT_COLOR))
            else
                self:SetBackdropBorderColor(unpack(COLOR_BORDER))
            end
        end)
        
        -- Initial State
        if KT.db.profile.buffsAndDebuffs.style == style then
            btn:SetBackdropBorderColor(unpack(KT_COLOR))
        else
            btn:SetBackdropBorderColor(unpack(COLOR_BORDER))
        end
        
        btn.isBDBtn = true
        return btn
    end

    local bdBtnLeft = CreateBDBtn("Blizzard", "BLIZZARD", -120)
    local bdBtnMid = CreateBDBtn("Modern KUI", "KUI", 0)
    local bdBtnRight = CreateBDBtn("Simplicity", "SIMPLICITY", 120)

    -- Shape selector (Buffs & Debuffs)
    local bdShapeHeader = styleFrame:CreateFontString(nil, "OVERLAY")
    bdShapeHeader:SetPoint("TOP", bdBtnMid, "BOTTOM", 0, -6)
    bdShapeHeader:SetFont(GetKTFont(), 14, "OUTLINE")
    bdShapeHeader:SetText(L["Shapes"])
    bdShapeHeader:SetTextColor(0.85, 0.85, 0.85)

    UpdateBDShapeButtons = function()
        local current = KT.db.profile.buffsAndDebuffs.shape or "NONE"
        local enabled = (KT.db.profile.buffsAndDebuffs.style or "BLIZZARD") ~= "BLIZZARD"
        for _, b in ipairs({styleFrame:GetChildren()}) do
            if b.isBDShapeBtn then
                local selected = b.shapeValue == current
                if b.SetEnabled then b:SetEnabled(enabled) end
                if b.EnableMouse then b:EnableMouse(enabled) end
                b:SetAlpha(enabled and 1 or 0.42)
                if b.Icon and b.Icon.SetDesaturated then b.Icon:SetDesaturated(not enabled) end
                if b.KT_PreviewShapeBorder then
                    if enabled and (selected or b.KT_PreviewShapeHover) then
                        b.KT_PreviewShapeBorder:SetVertexColor(unpack(KT_COLOR))
                    else
                        b.KT_PreviewShapeBorder:SetVertexColor(ShapeIdleColor())
                    end
                end
                if b.shapeValue == "NONE" or not b.KT_PreviewShapeBorder then
                    if enabled and selected then b:SetBackdropBorderColor(unpack(KT_COLOR))
                    else b:SetBackdropBorderColor(ShapeIdleColor()) end
                else
                    b:SetBackdropBorderColor(0, 0, 0, 0)
                end
            end
        end
    end

    local function CreateBDShapeBtn(label, shape, anchor, xOffset, yOffset, previewTexture)
        local btn = CreateFrame("Button", nil, styleFrame, "BackdropTemplate")
        btn:SetSize(64, 64)
        btn:SetPoint("TOP", anchor, "BOTTOM", xOffset, yOffset)
        CreateBackdrop(btn)
        btn:SetBackdropColor(0, 0, 0, 0)

        btn.Icon = btn:CreateTexture(nil, "ARTWORK")
        btn.Icon:SetPoint("TOPLEFT", 6, -6)
        btn.Icon:SetPoint("BOTTOMRIGHT", -6, 6)
        btn.Icon:SetTexture(previewTexture or buffDebuffPreviewTextures[1])
        btn.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.Cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
        btn.Cooldown:SetAllPoints(btn)
        if btn.Cooldown.SetDrawSwipe then btn.Cooldown:SetDrawSwipe(true) end
        if btn.Cooldown.SetCooldown then btn.Cooldown:SetCooldown(GetTime() - 5, 20) end
        btn.KT_PreviewStyleOverride = "SIMPLICITY"
        btn.KT_PreviewShapeOverride = shape
        btn.shapeValue = shape
        btn.isBDShapeBtn = true

        local function RefreshShapeIcon()
            btn.KT_PreviewStyleOverride = "SIMPLICITY"
            btn.KT_PreviewShapeOverride = shape
            SafeRenderInstallerShapePreview(btn, KT_COLOR[1], KT_COLOR[2], KT_COLOR[3])
        end
        btn.KT_RefreshShapeIcon = RefreshShapeIcon
        RefreshShapeIcon()

        btn:SetScript("OnClick", function()
            if (not btn:IsEnabled()) or (KT.db.profile.buffsAndDebuffs.style or "BLIZZARD") == "BLIZZARD" then
                return
            end
            KT.db.profile.buffsAndDebuffs.shape = shape
            RefreshBDPreview()
            UpdateBDShapeButtons()
            self:DeferReload(6)
        end)
        btn:SetScript("OnEnter", function(self)
            if not self:IsEnabled() then return end
            self.KT_PreviewShapeHover = true
            self:SetBackdropColor(1, 1, 1, 0.06)
            if self.shapeValue == "NONE" or not self.KT_PreviewShapeBorder then
                self:SetBackdropBorderColor(unpack(KT_COLOR))
            else
                self:SetBackdropBorderColor(0, 0, 0, 0)
                self.KT_PreviewShapeBorder:SetVertexColor(unpack(KT_COLOR))
            end
            if GameTooltip then
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(LText(label))
                GameTooltip:Show()
            end
        end)
        btn:SetScript("OnLeave", function(self)
            self.KT_PreviewShapeHover = nil
            self:SetBackdropColor(0, 0, 0, 0)
            UpdateBDShapeButtons()
            if GameTooltip then GameTooltip:Hide() end
        end)
        return btn
    end

    local bdShapeRow1Left = CreateBDShapeBtn("Square (Default)", "NONE", bdShapeHeader, -84, -4, buffDebuffPreviewTextures[1])
    local bdShapeRow1Mid = CreateBDShapeBtn("Circle", "CIRCLE", bdShapeHeader, 0, -4, buffDebuffPreviewTextures[2])
    local bdShapeRow1Right = CreateBDShapeBtn("Rounded Square", "CSQUARE", bdShapeHeader, 84, -4, buffDebuffPreviewTextures[3])

    local bdShapeRow2Mid = CreateBDShapeBtn("Hexagon", "HEXAGON", bdShapeRow1Mid, 0, -10, buffDebuffPreviewTextures[4])
    CreateBDShapeBtn("Diamond", "DIAMOND", bdShapeRow1Mid, 84, -10, buffDebuffPreviewTextures[5])
    CreateBDShapeBtn("Shield", "SHIELD", bdShapeRow1Mid, -84, -10, buffDebuffPreviewTextures[6])

    UpdateBDShapeButtons()
    
    -- Navigation
    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() self:ShowMinimapShapeStep() end)
    
    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowSkinStep() end)
    
    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)
    
    local chk = CreateSkipCheckbox(content, btnSkip)
    btnSkip:SetScript("OnClick", function() if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end self.frame:Hide() end)
end

function Mod:ShowMinimapShapeStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 7
    self:UpdateProgressBar(7)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    KT.db.profile.minimap = KT.db.profile.minimap or { enable = true, shape = "SQUARE" }
    KT.db.profile.minimap.shape = KT.db.profile.minimap.shape or "SQUARE"
    local db = KT.db.profile.minimap

    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(L["Minimap Shape"])
    title:SetTextColor(unpack(KT_COLOR))

    local subtitle = content:CreateFontString(nil, "OVERLAY")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -14)
    subtitle:SetWidth(620)
    subtitle:SetFont(GetKTFont(), 14)
    subtitle:SetText(L["Choose the minimap shape you want to start with. This preview updates the real minimap setting immediately."])
    subtitle:SetTextColor(0.9, 0.9, 0.9)
    subtitle:SetJustifyH("CENTER")

    local previewFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    previewFrame:SetSize(520, 322)
    previewFrame:SetPoint("TOP", subtitle, "BOTTOM", 0, -18)
    CreateBackdrop(previewFrame)
    previewFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.9)

    local previewMap = CreateFrame("Frame", nil, previewFrame, "BackdropTemplate")
    previewMap:SetSize(160, 160)
    previewMap:SetPoint("TOP", previewFrame, "TOP", 0, -34)
    CreateBackdrop(previewMap)
    previewMap:SetBackdropColor(0.04, 0.06, 0.08, 0.95)
    previewMap:SetBackdropBorderColor(unpack(KT_COLOR))

    local previewTex = previewMap:CreateTexture(nil, "BACKGROUND")
    previewTex:SetAllPoints()
    
    local faction = UnitFactionGroup("player")
    local mapID = (faction == "Horde") and 85 or 84
    local textures = C_Map and C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(mapID, 1)
    local tileIndex = (textures and #textures >= 6) and 6 or 1
    
    if textures and textures[tileIndex] then
        previewTex:SetTexture(textures[tileIndex])
        previewTex:SetVertexColor(0.6, 0.65, 0.7, 1)
        previewTex:SetTexCoord(0.2, 0.8, 0.2, 0.8)
    else
        previewTex:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        previewTex:SetVertexColor(0.45, 0.48, 0.50, 1)
    end
    
    local previewCompass = previewMap:CreateTexture(nil, "BORDER")
    previewCompass:SetSize(26, 26)
    previewCompass:SetPoint("TOPLEFT", previewMap, "TOPLEFT", 6, -6)
    previewCompass:SetTexture("Interface\\Minimap\\Minimap-TrackingBorder")
    previewCompass:SetAlpha(0.65)

    local previewGlow = previewMap:CreateTexture(nil, "ARTWORK")
    previewGlow:SetAllPoints()
    previewGlow:SetColorTexture(0.18, 0.35, 0.5, 0.08)

    local previewShade = previewMap:CreateTexture(nil, "ARTWORK")
    previewShade:SetAllPoints()
    previewShade:SetColorTexture(0, 0, 0, 0.16)

    local previewMask = previewMap:CreateMaskTexture()
    previewMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    previewMask:SetAllPoints(previewMap)

    previewTex:AddMaskTexture(previewMask)
    previewGlow:AddMaskTexture(previewMask)
    previewShade:AddMaskTexture(previewMask)

    local previewCircleBorder = previewMap:CreateTexture(nil, "OVERLAY")
    previewCircleBorder:SetPoint("TOPLEFT", previewMap, "TOPLEFT", -1, 1)
    previewCircleBorder:SetPoint("BOTTOMRIGHT", previewMap, "BOTTOMRIGHT", 1, -1)
    previewCircleBorder:SetTexture("Interface\\AddOns\\KullThranUI\\Modules\\SimplicityTextures\\circle_border.tga")
    previewCircleBorder:SetVertexColor(unpack(KT_COLOR))

    -- Decorative ring of the chosen visual style (same art as the real minimap).
    -- A texture on the map itself (not a child frame) so the texts stay above it.
    local previewRing = previewMap:CreateTexture(nil, "OVERLAY", nil, -8)
    previewRing:Hide()

    -- Square frame drawn one pixel outside the map so every edge stays visible.
    local previewSquareFrame = CreateFrame("Frame", nil, previewMap, "BackdropTemplate")
    previewSquareFrame:SetPoint("TOPLEFT", previewMap, "TOPLEFT", -1, 1)
    previewSquareFrame:SetPoint("BOTTOMRIGHT", previewMap, "BOTTOMRIGHT", 1, -1)
    previewSquareFrame:SetFrameLevel(previewMap:GetFrameLevel() + 6)
    previewSquareFrame:SetBackdrop({ edgeFile = EFL_WHITE8X8, edgeSize = 2 })
    previewSquareFrame:SetBackdropBorderColor(unpack(KT_COLOR))

    local function ResolveRingKey()
        local key = db.ringStyle
        if key == "none" or key == "forever" or key == "retail" or key == "classic" then return key end
        local themes = KT.VisualThemes
        local theme = themes and themes.GetRenderedTheme and themes:GetRenderedTheme()
        return (({ kui = "none", forever = "forever", retail = "retail", classic = "classic" })[theme]) or "none"
    end

    local zoneText = previewMap:CreateFontString(nil, "OVERLAY")
    zoneText:SetPoint("TOP", previewMap, "TOP", 0, -15)
    zoneText:SetFont(GetKTFont(), 14, "OUTLINE")
    zoneText:SetText(L["Stormwind City"])
    zoneText:SetTextColor(0.1, 1, 0.1)

    local subZoneText = previewMap:CreateFontString(nil, "OVERLAY")
    subZoneText:SetPoint("TOP", zoneText, "BOTTOM", 0, -2)
    subZoneText:SetFont(GetKTFont(), 11, "OUTLINE")
    subZoneText:SetText(L["Trade District"])
    subZoneText:SetTextColor(0, 0.75, 1)

    local coordText = previewMap:CreateFontString(nil, "OVERLAY")
    coordText:SetPoint("TOPRIGHT", previewMap, "TOPRIGHT", -10, -12)
    coordText:SetFont(GetKTFont(), 11, "OUTLINE")
    coordText:SetText("45.3, 62.7")
    coordText:SetTextColor(1, 1, 1)

    local clockText = previewMap:CreateFontString(nil, "OVERLAY")
    clockText:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 8, 26)
    clockText:SetFont(GetKTFont(), 13, "OUTLINE")
    clockText:SetText("13:37")
    clockText:SetTextColor(1, 1, 1)

    local perfText = previewMap:CreateFontString(nil, "OVERLAY")
    perfText:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 8, 12)
    perfText:SetFont(GetKTFont(), 11, "OUTLINE")
    perfText:SetText("|cffd7f3ff144FPS|r | |cffffb34723MS|r")
    perfText:SetTextColor(1, 1, 1)
    
    local friendsText = previewMap:CreateFontString(nil, "OVERLAY")
    friendsText:SetPoint("BOTTOMLEFT", previewMap, "BOTTOMLEFT", 8, 3)
    friendsText:SetFont(GetKTFont(), 12, "OUTLINE")
    friendsText:SetText(L["Friends"] .. ": 4")
    friendsText:SetTextColor(0, 0.7, 1)
    
    local guildText = previewMap:CreateFontString(nil, "OVERLAY")
    guildText:SetPoint("BOTTOMRIGHT", previewMap, "BOTTOMRIGHT", -8, 3)
    guildText:SetFont(GetKTFont(), 12, "OUTLINE")
    guildText:SetText(L["Guild"] .. ": |cff00ff0012|r")
    guildText:SetTextColor(0.2, 1, 0.2)

    local buttons = {}
    local ringButtons = {}
    local function RefreshPreviewShape()
        local shape = (db.shape or "SQUARE"):upper()
        local ringKey = ResolveRingKey()
        local ringDrawn = false
        if shape == "ROUND" and ringKey ~= "none" and KT.DrawMinimapRing and KT.MinimapRingStyles then
            for _, def in ipairs(KT.MinimapRingStyles) do
                if def.key == ringKey then
                    ringDrawn = KT.DrawMinimapRing(def, previewRing, previewRing, previewMap, previewMap:GetWidth()) and true or false
                    break
                end
            end
        end
        previewRing:SetShown(ringDrawn)
        previewSquareFrame:SetShown(shape ~= "ROUND")
        if shape == "ROUND" then
            previewMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            previewCircleBorder:SetShown(not ringDrawn)
            previewMap:SetBackdropBorderColor(0, 0, 0, 0)
        else
            previewMask:SetTexture("Interface\\Buttons\\WHITE8X8", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            previewCircleBorder:Hide()
            previewMap:SetBackdropBorderColor(0, 0, 0, 0)
        end
        for _, ringBtn in ipairs(ringButtons) do
            ringBtn:SetBackdropBorderColor(unpack(ringBtn.ringKey == ringKey and KT_COLOR or COLOR_BORDER))
            ringBtn:SetAlpha(shape == "ROUND" and 1 or 0.45)
        end

        for _, btn in ipairs(buttons) do
            if btn.shapeValue == shape then
                btn:SetBackdropBorderColor(unpack(KT_COLOR))
            else
                btn:SetBackdropBorderColor(unpack(COLOR_BORDER))
            end
        end
        
        coordText:SetShown(db.showCoords ~= false)
        clockText:SetShown(db.showClock ~= false)
        perfText:SetShown(db.showFPS ~= false or db.showMS ~= false)
        friendsText:SetShown(db.showFriends ~= false)
        guildText:SetShown(db.showGuild ~= false)
    end

    local function CreateShapeButton(label, shape, xOffset)
        local btn = CreateFrame("Button", nil, previewFrame, "BackdropTemplate")
        btn:SetSize(180, 34)
        btn:SetPoint("BOTTOM", previewFrame, "BOTTOM", xOffset, 20)
        btn:SetText(LText(label))
        btn.shapeValue = shape
        SkinButton(btn)
        btn:SetScript("OnClick", function()
            db.shape = shape
            RefreshInstallerMinimapShape()
            RefreshPreviewShape()
        end)
        buttons[#buttons + 1] = btn
        return btn
    end

    CreateShapeButton(L["Square"], "SQUARE", -100)
    CreateShapeButton(L["Round"], "ROUND", 100)

    -- Border of each visual style (applies to the round minimap).
    if KT.MinimapRingStyles then
        local count = #KT.MinimapRingStyles
        local width, gap = 104, 8
        for index, def in ipairs(KT.MinimapRingStyles) do
            local ringBtn = CreateFrame("Button", nil, previewFrame, "BackdropTemplate")
            ringBtn:SetSize(width, 26)
            ringBtn:SetPoint("BOTTOM", previewFrame, "BOTTOM", (index - (count + 1) / 2) * (width + gap), 64)
            ringBtn:SetText(LText(def.label))
            ringBtn.ringKey = def.key
            SkinButton(ringBtn)
            ringBtn:SetScript("OnClick", function()
                db.ringStyle = def.key
                db.shape = "ROUND"
                RefreshInstallerMinimapShape()
                RefreshPreviewShape()
            end)
            ringButtons[#ringButtons + 1] = ringBtn
        end
    end
    
    local function CreateToggle(label, key, anchorPoint, anchorTo, anchorPointTo, x, y)
        local cb = CreateFrame("CheckButton", nil, content, "BackdropTemplate")
        cb:SetSize(18, 18)
        cb:SetPoint(anchorPoint, anchorTo, anchorPointTo, x, y)
        CreateBackdrop(cb)
        cb:SetBackdropColor(0, 0, 0, 1)
        
        cb.Checked = cb:CreateTexture(nil, "ARTWORK")
        cb.Checked:SetTexture("Interface\\Buttons\\WHITE8x8")
        cb.Checked:SetVertexColor(unpack(KT_COLOR))
        cb.Checked:SetAllPoints(cb)

        local isChecked = db[key] ~= false
        cb.Checked:SetAlpha(isChecked and 1 or 0)
        cb:SetChecked(isChecked)

        local cbLabel = cb:CreateFontString(nil, "OVERLAY")
        cbLabel:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        cbLabel:SetFont(GetKTFont(), 12, "OUTLINE")
        cbLabel:SetText(label)
        cbLabel:SetTextColor(0.85, 0.85, 0.85)
        
        cb:SetScript("OnClick", function(self)
            local v = self:GetChecked() and true or false
            self.Checked:SetAlpha(v and 1 or 0)
            db[key] = v
            if key == "showFPS" then db.showMS = v end
            RefreshPreviewShape()
            RefreshInstallerMinimapShape()
        end)
        return cb
    end

    local chkCoords = CreateToggle(LText("Coordinates"), "showCoords", "TOPLEFT", previewFrame, "BOTTOM", -137, -10)
    local chkClock = CreateToggle(LText("Clock"), "showClock", "LEFT", chkCoords, "RIGHT", 110, 0)
    local chkFPS = CreateToggle(LText("FPS / MS"), "showFPS", "LEFT", chkClock, "RIGHT", 80, 0)
    
    local chkFriends = CreateToggle(LText("Friends"), "showFriends", "TOPLEFT", chkCoords, "BOTTOMLEFT", 0, -5)
    local chkGuild = CreateToggle(LText("Guild"), "showGuild", "LEFT", chkFriends, "RIGHT", 110, 0)

    RefreshPreviewShape()

    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() self:ShowCursorStep() end)

    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowButtonStyleStep() end)

    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)

    local chk = CreateSkipCheckbox(content, btnSkip)
    btnSkip:SetScript("OnClick", function()
        if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end
        self.frame:Hide()
    end)
end

function Mod:ShowCursorStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 8
    self:UpdateProgressBar(8)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    local db, cursor = GetInstallerCursorDB()
    local media = (cursor and cursor.GetMediaPaths and cursor:GetMediaPaths()) or {
        ring = "Interface\\AddOns\\KullThranUI_Cursor\\Modules\\Cursor\\Media\\Ring_Main.tga",
        reticleDot = "Interface\\AddOns\\KullThranUI_Cursor\\Modules\\Cursor\\Media\\Reticle_Dot.tga",
        cursorPoint = "Interface\\CURSOR\\Point",
    }

    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(L["Cursor"])
    title:SetTextColor(unpack(KT_COLOR))

    local subtitle = content:CreateFontString(nil, "OVERLAY")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -14)
    subtitle:SetWidth(620)
    subtitle:SetFont(GetKTFont(), 14)
    subtitle:SetText(L["Choose the cursor color style you want to start with. This preview updates the real cursor setting immediately."])
    subtitle:SetTextColor(0.9, 0.9, 0.9)
    subtitle:SetJustifyH("CENTER")

    local previewFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    previewFrame:SetSize(520, 308)
    previewFrame:SetPoint("TOP", subtitle, "BOTTOM", 0, -18)
    CreateBackdrop(previewFrame)
    previewFrame:SetBackdropColor(0.06, 0.06, 0.06, 0.9)

    local previewCore = CreateFrame("Frame", nil, previewFrame)
    previewCore:SetSize(170, 170)
    previewCore:SetPoint("TOP", previewFrame, "TOP", 0, -18)

    local cursorLayer = CreateFrame("Frame", nil, previewFrame)
    cursorLayer:SetSize(1, 1)
    cursorLayer:SetPoint("CENTER", previewCore, "CENTER")
    cursorLayer:SetFrameLevel(previewCore:GetFrameLevel() + 50)
    local previewCursor = cursorLayer:CreateTexture(nil, "OVERLAY", nil, 7)
    previewCursor:SetPoint("TOPLEFT", cursorLayer, "CENTER")
    previewCursor:SetTexture(media.cursorPoint or "Interface\\CURSOR\\Point")

    local outerRing = previewCore:CreateTexture(nil, "ARTWORK")
    outerRing:SetPoint("CENTER")
    outerRing:SetTexture(media.ring)

    local mainRing = previewCore:CreateTexture(nil, "ARTWORK")
    mainRing:SetPoint("CENTER")
    mainRing:SetTexture(media.ring)

    local innerRing = previewCore:CreateTexture(nil, "ARTWORK")
    innerRing:SetPoint("CENTER")
    innerRing:SetTexture(media.ring)

    local reticle = previewCore:CreateTexture(nil, "OVERLAY")
    reticle:SetPoint("CENTER")
    reticle:SetTexture(media.reticleDot)

    local trailPreview = CreateFrame("Frame", nil, previewFrame)
    trailPreview:SetSize(240, 36)
    trailPreview:SetPoint("BOTTOM", previewFrame, "BOTTOM", 0, 98)
    trailPreview.dots = {}
    for i = 1, 12 do
        local dot = trailPreview:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(media.reticleDot)
        dot:SetPoint("LEFT", trailPreview, "LEFT", (i - 1) * 18, (i % 2 == 0) and -2 or 2)
        trailPreview.dots[i] = dot
    end

    local btnClass = CreateFrame("Button", nil, previewFrame, "BackdropTemplate")
    btnClass:SetSize(142, 34)
    btnClass:SetPoint("BOTTOMLEFT", previewFrame, "BOTTOMLEFT", 28, 18)
    btnClass:SetText(L["Class Color"])
    SkinButton(btnClass)

    local btnCustom = CreateFrame("Button", nil, previewFrame, "BackdropTemplate")
    btnCustom:SetSize(142, 34)
    btnCustom:SetPoint("LEFT", btnClass, "RIGHT", 10, 0)
    btnCustom:SetText(L["Custom Color"])
    SkinButton(btnCustom)

    local swatch = CreateFrame("Button", nil, previewFrame, "BackdropTemplate")
    swatch:SetSize(34, 34)
    swatch:SetPoint("LEFT", btnCustom, "RIGHT", 8, 0)
    CreateBackdrop(swatch)
    swatch:SetBackdropColor(0.1, 0.1, 0.1, 1)

    swatch.fill = swatch:CreateTexture(nil, "ARTWORK")
    swatch.fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 4, -4)
    swatch.fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -4, 4)
    swatch.fill:SetColorTexture(1, 1, 1, 1)

    local btnTrail = CreateFrame("Button", nil, previewFrame, "BackdropTemplate")
    btnTrail:SetSize(118, 34)
    btnTrail:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
    btnTrail:SetText(L["Enable Trail"])
    SkinButton(btnTrail)

    local btnEnable = CreateFrame("Button", nil, previewFrame, "BackdropTemplate")
    btnEnable:SetSize(142, 34)
    btnEnable:SetPoint("BOTTOMLEFT", previewFrame, "BOTTOMLEFT", 28, 58)
    SkinButton(btnEnable)

    local btnClickEffect = CreateFrame("Button", nil, previewFrame, "BackdropTemplate")
    btnClickEffect:SetSize(142, 34)
    btnClickEffect:SetPoint("TOPRIGHT", previewFrame, "TOPRIGHT", -28, -22)
    SkinButton(btnClickEffect)

    local sizeLabel = previewFrame:CreateFontString(nil, "OVERLAY")
    sizeLabel:SetPoint("BOTTOMLEFT", previewFrame, "BOTTOMLEFT", 190, 84)
    sizeLabel:SetFont(GetKTFont(), 11, "OUTLINE")
    sizeLabel:SetText(L["Global Scale"])
    sizeLabel:SetTextColor(0.9, 0.9, 0.9)

    local sizeValue = previewFrame:CreateFontString(nil, "OVERLAY")
    sizeValue:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT", -28, 84)
    sizeValue:SetFont(GetKTFont(), 11, "OUTLINE")
    sizeValue:SetTextColor(unpack(KT_COLOR))

    local sizeSlider = CreateFrame("Slider", nil, previewFrame)
    sizeSlider:SetOrientation("HORIZONTAL")
    sizeSlider:SetMinMaxValues(0.5, 2.5)
    sizeSlider:SetValueStep(0.1)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider:SetSize(302, 18)
    sizeSlider:SetPoint("BOTTOMLEFT", previewFrame, "BOTTOMLEFT", 190, 59)
    if sizeSlider.SetHitRectInsets then
        sizeSlider:SetHitRectInsets(0, 0, -5, -5)
    end

    local sizeTrack = sizeSlider:CreateTexture(nil, "BACKGROUND")
    sizeTrack:SetPoint("LEFT", sizeSlider, "LEFT", 0, 0)
    sizeTrack:SetPoint("RIGHT", sizeSlider, "RIGHT", 0, 0)
    sizeTrack:SetHeight(4)
    sizeTrack:SetColorTexture(0.2, 0.2, 0.2, 1)

    sizeSlider:SetThumbTexture("Interface\\Buttons\\WHITE8x8")
    local sizeThumb = sizeSlider:GetThumbTexture()
    if sizeThumb then
        sizeThumb:SetSize(10, 16)
        sizeThumb:SetVertexColor(unpack(KT_COLOR))
    end
    sizeSlider:SetValue(tonumber(db.scale) or 1)

    local function ApplyColorMode(mode)
        db.reticleColorMode = mode
        db.mainRingColorMode = mode
        db.gcdColorMode = mode
        db.castColorMode = mode
        db.trailColorMode = mode
    end

    local function ApplyCustomColor(r, g, b)
        db.reticleCustomColor = { r = r, g = g, b = b }
        db.mainRingCustomColor = { r = r, g = g, b = b }
        db.gcdCustomColor = { r = r, g = g, b = b }
        db.castCustomColor = { r = r, g = g, b = b }
        db.trailCustomColor = { r = r, g = g, b = b }
        ApplyColorMode("custom")
    end

    local function GetPreviewColor()
        if db.mainRingColorMode == "custom" and db.mainRingCustomColor then
            local c = db.mainRingCustomColor
            return c.r or 1, c.g or 1, c.b or 1
        end
        return GetInstallerClassColor()
    end

    local function UpdateState()
        local r, g, b = GetPreviewColor()
        local cursorScale = math.max(0.5, math.min(2.5, tonumber(db.scale) or 1))
        local previewScale = math.max(0.55, math.min(1.45, cursorScale))
        previewCursor:SetSize(40, 40)
        previewCursor:SetVertexColor(1, 1, 1, 1)
        outerRing:SetSize(96 * previewScale, 96 * previewScale)
        outerRing:SetVertexColor(r, g, b, 0.9)
        mainRing:SetSize(72 * previewScale, 72 * previewScale)
        mainRing:SetVertexColor(r, g, b, 0.6)
        innerRing:SetSize(48 * previewScale, 48 * previewScale)
        innerRing:SetVertexColor(r, g, b, 0.3)
        reticle:SetSize(16 * previewScale, 16 * previewScale)
        reticle:SetVertexColor(r, g, b, 1)
        swatch.fill:SetColorTexture(r, g, b, 1)
        sizeValue:SetText(string.format("%d%%", math.floor((cursorScale * 100) + 0.5)))

        for index, dot in ipairs(trailPreview.dots) do
            local size = (8 + math.floor(index / 2)) * previewScale
            dot:SetSize(size, size)
            dot:SetVertexColor(r, g, b, 1)
            dot:SetAlpha(db.enableTrail and (0.2 + (index * 0.05)) or 0.08)
        end

        if db.mainRingColorMode == "custom" then
            btnCustom:SetBackdropBorderColor(unpack(KT_COLOR))
            btnClass:SetBackdropBorderColor(unpack(COLOR_BORDER))
        else
            btnClass:SetBackdropBorderColor(unpack(KT_COLOR))
            btnCustom:SetBackdropBorderColor(unpack(COLOR_BORDER))
        end

        if db.enableTrail then
            btnTrail:SetBackdropBorderColor(unpack(KT_COLOR))
        else
            btnTrail:SetBackdropBorderColor(unpack(COLOR_BORDER))
        end

        local clickEnabled = db.enableClickAnimation ~= false
        btnClickEffect:SetText(clickEnabled and L["Disable Click Effect"] or L["Enable Click Effect"])
        btnClickEffect:SetBackdropBorderColor(unpack(clickEnabled and KT_COLOR or COLOR_BORDER))

        local enabled = db.enable ~= false
        previewCore:SetAlpha(enabled and 1 or 0.22)
        trailPreview:SetAlpha(enabled and 1 or 0.22)
        btnEnable:SetText(enabled and L["Disable Module"] or L["Enable Module"])
        if enabled then
            btnEnable:SetBackdropBorderColor(unpack(KT_COLOR))
        else
            btnEnable:SetBackdropBorderColor(unpack(COLOR_BORDER))
        end
    end

    local function ApplyAndRefresh()
        ApplyInstallerCursorSettings()
        UpdateState()
    end

    sizeSlider:SetScript("OnValueChanged", function(_, value)
        value = math.floor((value * 10) + 0.5) / 10
        db.scale = value
        ApplyAndRefresh()
    end)

    local function OpenColorPicker()
        local initial = db.mainRingCustomColor or { r = 1, g = 1, b = 1 }
        local function applyPickedColor()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            ApplyCustomColor(r, g, b)
            ApplyAndRefresh()
        end

        ApplyColorMode("custom")
        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = initial.r or 1,
                g = initial.g or 1,
                b = initial.b or 1,
                swatchFunc = applyPickedColor,
                opacityFunc = nil,
                cancelFunc = function(previous)
                    local restore = previous or initial
                    ApplyCustomColor(restore.r or 1, restore.g or 1, restore.b or 1)
                    ApplyAndRefresh()
                end,
            })
        else
            ColorPickerFrame.func = applyPickedColor
            ColorPickerFrame.cancelFunc = function()
                ApplyCustomColor(initial.r or 1, initial.g or 1, initial.b or 1)
                ApplyAndRefresh()
            end
            ColorPickerFrame.hasOpacity = false
            ColorPickerFrame:SetColorRGB(initial.r or 1, initial.g or 1, initial.b or 1)
            ColorPickerFrame:Hide()
            ColorPickerFrame:Show()
        end
        UpdateState()
    end

    btnClass:SetScript("OnClick", function()
        ApplyColorMode("class")
        ApplyAndRefresh()
    end)

    btnCustom:SetScript("OnClick", OpenColorPicker)

    swatch:SetScript("OnClick", OpenColorPicker)

    btnTrail:SetScript("OnClick", function()
        db.enableTrail = not (db.enableTrail == true)
        ApplyAndRefresh()
    end)

    btnClickEffect:SetScript("OnClick", function()
        db.enableClickAnimation = not (db.enableClickAnimation ~= false)
        ApplyAndRefresh()
    end)

    btnEnable:SetScript("OnClick", function()
        local enabled = db.enable ~= false
        db.enable = not enabled
        ApplyAndRefresh()
    end)

    UpdateState()

    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() self:ShowEnhancedFriendListStep() end)

    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowMinimapShapeStep() end)

    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)

    local chk = CreateSkipCheckbox(content, btnSkip)
    btnSkip:SetScript("OnClick", function()
        if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end
        self.frame:Hide()
    end)
end

function Mod:ShowEnhancedFriendListStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 9
    self:UpdateProgressBar(9)
    if self.content then self.content:Hide() end

    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    local db, enhancements = GetInstallerEnhancementsDB()
    db.social = db.social or {}
    if db.social.enhancedFriendList == nil then
        db.social.enhancedFriendList = true
    end

    local friendList = enhancements and enhancements.EnhancedFriendList or nil

    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(L["Enhanced Friend List"])
    title:SetTextColor(unpack(KT_COLOR))

    -- The real window, scaled, on the left (your accent); text, state and
    -- the Enable / Disable buttons on the right, all clear of the footer.
    local previewFrame = CreateFrame("Frame", nil, content)
    previewFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 56, -82)
    previewFrame:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 56, 100)
    previewFrame:SetWidth(320)

    local previewCards = {}
    local accent = { KT_COLOR[1], KT_COLOR[2], KT_COLOR[3] }
    local previewH = 600 - 82 - 100
    local card
    if friendList and friendList.CreateInstallerPreviewCard then
        card = friendList:CreateInstallerPreviewCard(previewFrame, accent, nil, 320, previewH)
    else
        card = CreateEnhancedFriendListPreviewCard(previewFrame, accent, "")
    end
    card:SetPoint("TOP", previewFrame, "TOP", 0, 0)
    previewCards[1] = card

    local side = CreateFrame("Frame", nil, content)
    side:SetPoint("TOPLEFT", previewFrame, "TOPRIGHT", 34, -24)
    side:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -40, 100)

    local subtitle = side:CreateFontString(nil, "OVERLAY")
    subtitle:SetPoint("TOPLEFT", 0, 0)
    subtitle:SetPoint("TOPRIGHT", 0, 0)
    subtitle:SetFont(GetKTFont(), 14)
    subtitle:SetText(LText("The redesigned social panel: class-coloured contacts, custom groups, notes, search and one-click invites, Who, Raid and Quick Join in the same window."))
    subtitle:SetTextColor(0.9, 0.9, 0.9)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetSpacing(3)

    local note = side:CreateFontString(nil, "OVERLAY")
    note:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -14)
    note:SetPoint("RIGHT", side, "RIGHT", 0, 0)
    note:SetFont(GetKTFont(), 12)
    note:SetText(LText("The preview is the real window with your accent colour and sample friends."))
    note:SetTextColor(0.62, 0.62, 0.66)
    note:SetJustifyH("LEFT")

    local controlsFrame = CreateFrame("Frame", nil, side)
    controlsFrame:SetPoint("BOTTOMLEFT", 0, 0)
    controlsFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    controlsFrame:SetHeight(110)

    local stateText = controlsFrame:CreateFontString(nil, "OVERLAY")
    stateText:SetFont(GetKTFont(), 14, "OUTLINE")
    stateText:SetPoint("TOPLEFT", controlsFrame, "TOPLEFT", 0, 0)

    local btnEnable
    local btnDisable

    local function RefreshPreviewState()
        local enabled = db.social.enhancedFriendList ~= false
        stateText:SetText(enabled and L["Enabled"] or L["Disabled"])
        if enabled then
            stateText:SetTextColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 1)
            btnEnable:SetBackdropBorderColor(unpack(KT_COLOR))
            btnDisable:SetBackdropBorderColor(unpack(COLOR_BORDER))
        else
            stateText:SetTextColor(0.72, 0.72, 0.76, 1)
            btnEnable:SetBackdropBorderColor(unpack(COLOR_BORDER))
            btnDisable:SetBackdropBorderColor(unpack(KT_COLOR))
        end

        for _, card in ipairs(previewCards) do
            card:SetAlpha(enabled and 1 or 0.38)
            if card.disabledOverlay then
                if enabled then
                    card.disabledOverlay:Hide()
                else
                    card.disabledOverlay:Show()
                end
            end
            if card.caption then
                card.caption:SetAlpha(enabled and 1 or 0.7)
            end
        end
    end

    local function SetEnhancedFriendListEnabled(value)
        db.social.enhancedFriendList = value and true or false
        ApplyInstallerEnhancedFriendListSettings()
        RefreshPreviewState()
    end

    btnEnable = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnEnable:SetParent(controlsFrame)
    btnEnable:SetSize(220, 32)
    btnEnable:SetPoint("TOPLEFT", controlsFrame, "TOPLEFT", 0, -30)
    btnEnable:SetText(L["Enable Enhanced Friend List"])
    SkinButton(btnEnable)
    btnEnable:SetScript("OnClick", function()
        SetEnhancedFriendListEnabled(true)
    end)

    btnDisable = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnDisable:SetParent(controlsFrame)
    btnDisable:SetSize(220, 32)
    btnDisable:SetPoint("TOPLEFT", btnEnable, "BOTTOMLEFT", 0, -8)
    btnDisable:SetText(L["Disable Enhanced Friend List"])
    SkinButton(btnDisable)
    btnDisable:SetScript("OnClick", function()
        SetEnhancedFriendListEnabled(false)
    end)

    RefreshPreviewState()

    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() self:ShowBagsStep() end)

    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowCursorStep() end)

    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)

    local chk = CreateSkipCheckbox(content, btnSkip)
    btnSkip:SetScript("OnClick", function()
        if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end
        self.frame:Hide()
    end)
end

function Mod:ShowBagsStep()
    local profile = KT.db.profile
    profile.bags = profile.bags or { enable = true }
    if profile.bags.enable == nil then profile.bags.enable = true end

    ShowInstallerModuleToggleStep(self, {
        step = 10,
        requiresReload = true,
        title = "KullThranUI Bags",
        question = "Do you want to enable or disable KullThranUI Bags?",
        enableLabel = "Enable KullThranUI Bags",
        disableLabel = "Disable KullThranUI Bags",
        createPreview = CreateBagsInstallerLivePreview,
        previewHeight = 320,
        get = function() return profile.bags.enable ~= false end,
        set = function(value) profile.bags.enable = value end,
        apply = function(value)
            local bags = KT:GetModule("Bags", true)
            if bags and bags.OnProfileUpdate then
                pcall(bags.OnProfileUpdate, bags)
            end
            if not value and _G.KT_BagsWindow then
                _G.KT_BagsWindow:Hide()
            end
        end,
        next = function() self:ShowDamageMeterStep() end,
        back = function() self:ShowEnhancedFriendListStep() end,
    })
end

function Mod:ShowDamageMeterStep()
    local db, enhancements = GetInstallerEnhancementsDB()
    db.damageMeter = db.damageMeter or {}
    if db.damageMeter.moduleEnabled == nil then db.damageMeter.moduleEnabled = true end
    if db.damageMeter.enabled == nil then db.damageMeter.enabled = false end

    ShowInstallerModuleToggleStep(self, {
        step = 11,
        title = "KullThranUI Damage Meter",
        question = "Do you want to enable or disable the KullThranUI Damage Meter?",
        location = "You can configure it later in Enhancements > Damage Meter.",
        enableLabel = "Enable KullThranUI Damage Meter",
        disableLabel = "Disable KullThranUI Damage Meter",
        createPreview = CreateDamageMeterInstallerLivePreview,
        previewWidth = 460,
        previewHeight = 256,
        styleRow = {
            get = function()
                return enhancements and enhancements.GetDamageMeterStyle and enhancements:GetDamageMeterStyle() or "kui"
            end,
            set = function(key)
                if enhancements and enhancements.SetDamageMeterStyle then
                    pcall(enhancements.SetDamageMeterStyle, enhancements, key)
                end
            end,
            rebuild = true,
        },
        get = function() return db.damageMeter.moduleEnabled ~= false and db.damageMeter.enabled == true end,
        set = function(value)
            db.damageMeter.moduleEnabled = value and true or false
            db.damageMeter.enabled = value and true or false
        end,
        apply = function()
            if enhancements and enhancements.RefreshSettings then
                pcall(enhancements.RefreshSettings, enhancements)
            end
        end,
        next = function() self:ShowMythicPlusTimerStep() end,
        back = function() self:ShowBagsStep() end,
    })
end

function Mod:ShowMythicPlusTimerStep()
    local db, enhancements = GetInstallerEnhancementsDB()
    db.mplusTracker = db.mplusTracker or {}
    if db.mplusTracker.enabled == nil then db.mplusTracker.enabled = true end

    ShowInstallerModuleToggleStep(self, {
        step = 12,
        title = "KullThranUI Mythic+ Timer",
        question = "Do you want to enable or disable the KullThranUI Mythic+ Timer?",
        location = "You can configure it later in Enhancements > Mythic+ Timer.",
        enableLabel = "Enable KullThranUI Mythic+ Timer",
        disableLabel = "Disable KullThranUI Mythic+ Timer",
        createPreview = CreateMythicPlusTimerInstallerLivePreview,
        get = function() return db.mplusTracker.enabled ~= false end,
        set = function(value) db.mplusTracker.enabled = value and true or false end,
        apply = function()
            if enhancements and enhancements.RefreshMythicPlusTracker then
                pcall(enhancements.RefreshMythicPlusTracker, enhancements)
            end
        end,
        next = function() self:ShowUnitFramesStep() end,
        back = function() self:ShowDamageMeterStep() end,
    })
end

function Mod:ShowUnitFramesStep()
    local profile = KT.db.profile
    profile.unitFrames = profile.unitFrames or {}
    if profile.unitFrames.enable == nil then profile.unitFrames.enable = true end

    ShowInstallerModuleToggleStep(self, {
        step = 13,
        requiresReload = true,
        title = "KullThranUI Unit Frames",
        question = "Which unit frame system do you want to use?",
        location = "Choose another addon to leave KullThranUI Unit Frames disabled.",
        enableLabel = "Use KullThranUI Unit Frames",
        disableLabel = "Use Unit Frames From Another Addon",
        disabledPreviewLabel = "Using unit frames from another addon",
        createPreview = CreateUnitFramesInstallerLivePreview,
        fitPreview = true,
        previewWidth = 560,
        styleRow = {
            -- Unit frames follow the global Visual Style: the choice is kept as
            -- a pending change and the preview redraws in it right away.
            get = function() return self:GetChosenVisualTheme() end,
            set = function(key) self:SetPendingVisualTheme(key) end,
            rebuild = true,
        },
        get = function() return profile.unitFrames.enable ~= false end,
        set = function(value) profile.unitFrames.enable = value end,
        next = function() self:ShowPartyFramesStep() end,
        back = function() self:ShowMythicPlusTimerStep() end,
    })
end

function Mod:ShowPartyFramesStep()
    local profile = KT.db.profile
    profile.partyFrames = profile.partyFrames or {}
    if profile.partyFrames.enable == nil then profile.partyFrames.enable = true end

    ShowInstallerModuleToggleStep(self, {
        step = 14,
        requiresReload = true,
        title = "KullThranUI Party Frames",
        question = "Which party frame system do you want to use?",
        location = "Choose another addon to leave KullThranUI Party Frames disabled.",
        enableLabel = "Use KullThranUI Party Frames",
        disableLabel = "Use Party Frames From Another Addon",
        disabledPreviewLabel = "Using party frames from another addon",
        createPreview = CreatePartyFramesInstallerLivePreview,
        styleRow = {
            -- Same Visual Style row as Unit Frames: a pending change, and the
            -- preview redraws in it right away.
            get = function() return self:GetChosenVisualTheme() end,
            set = function(key) self:SetPendingVisualTheme(key) end,
            rebuild = true,
        },
        get = function() return profile.partyFrames.enable ~= false end,
        set = function(value) profile.partyFrames.enable = value end,
        next = function() self:ShowCooldownManagerStep() end,
        back = function() self:ShowUnitFramesStep() end,
    })
end

function Mod:ShowCooldownManagerStep()
    local profile = KT.db.profile
    profile.cooldownManager = profile.cooldownManager or {}
    profile.cooldownManager.cdmBars = profile.cooldownManager.cdmBars or { enabled = false }
    if profile.cooldownManager.cdmBars.enabled == nil then
        profile.cooldownManager.cdmBars.enabled = false
    end

    ShowInstallerModuleToggleStep(self, {
        step = 16,
        title = "KullThranUI Cooldown Manager",
        question = "Do you want to enable or disable the KullThranUI Cooldown Manager?",
        enableLabel = "Enable KullThranUI Cooldown Manager",
        disableLabel = "Disable KullThranUI Cooldown Manager",
        location = "Recommended: import the Blizzard layout now so every Cooldown Manager bar starts in the intended position.",
        createPreview = CreateCooldownManagerInstallerLivePreview,
        previewHeight = 262,
        createExtraControls = function(content, previewFrame)
            local glow = previewFrame:CreateTexture(nil, "ARTWORK", nil, 1)
            glow:SetTexture("Interface\\Buttons\\WHITE8x8")
            glow:SetSize(270, 42)
            glow:SetPoint("BOTTOM", previewFrame, "BOTTOM", 0, 8)
            glow:SetVertexColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 0.20)
            local anim = glow:CreateAnimationGroup()
            anim:SetLooping("BOUNCE")
            local fade = anim:CreateAnimation("Alpha")
            fade:SetFromAlpha(0.18)
            fade:SetToAlpha(0.65)
            fade:SetDuration(0.8)
            anim:Play()

            local import = CreateFrame("Button", nil, previewFrame, "BackdropTemplate")
            import:SetSize(250, 30)
            import:SetPoint("BOTTOM", previewFrame, "BOTTOM", 0, 14)
            import:SetFrameLevel(previewFrame:GetFrameLevel() + 5)
            import:SetText(LText("Import Blizzard Layout"))
            SkinButton(import)
            import:SetBackdropBorderColor(unpack(KT_COLOR))
            import:SetScript("OnClick", function(self)
                local ns = _G.KUI_CDM_NS
                local ok = ns and ns.ImportBlizzardDisplayedMainBars and pcall(ns.ImportBlizzardDisplayedMainBars, true, false)
                if _G._KUI_CDM_Apply then pcall(_G._KUI_CDM_Apply) end
                self:SetText(ok and (LText("Layout Imported")) or (LText("Import unavailable")))
            end)

            -- Resource Bars live with the Cooldown Manager: highlighted switch under the preview.
            profile.resourceBars = profile.resourceBars or {}
            if profile.resourceBars.enabled == nil then profile.resourceBars.enabled = true end
            local panel = CreateFrame("Frame", nil, content, "BackdropTemplate")
            panel:SetSize(700, 36)
            panel:SetPoint("TOP", previewFrame, "BOTTOM", 0, -6)
            CreateBackdrop(panel)
            panel:SetBackdropColor(KT_COLOR[1] * 0.14, KT_COLOR[2] * 0.14, KT_COLOR[3] * 0.14, 0.95)
            panel:SetBackdropBorderColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 1)
            local pulse = panel:CreateTexture(nil, "ARTWORK", nil, 1)
            pulse:SetTexture("Interface\\Buttons\\WHITE8x8")
            pulse:SetPoint("TOPLEFT", 1, -1)
            pulse:SetPoint("BOTTOMRIGHT", -1, 1)
            pulse:SetVertexColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 0.10)
            local pulseAnim = pulse:CreateAnimationGroup()
            pulseAnim:SetLooping("BOUNCE")
            local pulseFade = pulseAnim:CreateAnimation("Alpha")
            pulseFade:SetFromAlpha(0.3)
            pulseFade:SetToAlpha(1)
            pulseFade:SetDuration(0.9)
            pulseAnim:Play()

            local panelTitle = panel:CreateFontString(nil, "OVERLAY")
            panelTitle:SetPoint("LEFT", 12, 5)
            panelTitle:SetFont(GetKTFont(), 14, "OUTLINE")
            panelTitle:SetTextColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 1)
            panelTitle:SetText(LText("Resource Bars"))
            local panelHint = panel:CreateFontString(nil, "OVERLAY")
            panelHint:SetPoint("LEFT", 12, -8)
            panelHint:SetFont(GetKTFont(), 10)
            panelHint:SetTextColor(0.8, 0.8, 0.8, 1)
            panelHint:SetText(LText("Power bar shown with your Cooldown Manager."))

            local btnRbDisable = CreateFrame("Button", nil, panel, "BackdropTemplate")
            btnRbDisable:SetSize(120, 26)
            btnRbDisable:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
            btnRbDisable:SetText(LText("Disable"))
            SkinButton(btnRbDisable)
            local btnRbEnable = CreateFrame("Button", nil, panel, "BackdropTemplate")
            btnRbEnable:SetSize(120, 26)
            btnRbEnable:SetPoint("RIGHT", btnRbDisable, "LEFT", -8, 0)
            btnRbEnable:SetText(LText("Enable"))
            SkinButton(btnRbEnable)
            local function RefreshResourceBarButtons()
                local enabled = profile.resourceBars.enabled ~= false
                btnRbEnable:SetBackdropBorderColor(unpack(enabled and KT_COLOR or COLOR_BORDER))
                btnRbDisable:SetBackdropBorderColor(unpack(enabled and COLOR_BORDER or KT_COLOR))
            end
            local function SetResourceBars(value)
                if (profile.resourceBars.enabled ~= false) == value then return end
                profile.resourceBars.enabled = value
                RefreshResourceBarButtons()
                self:DeferReload(16)
            end
            btnRbEnable:SetScript("OnClick", function() SetResourceBars(true) end)
            btnRbDisable:SetScript("OnClick", function() SetResourceBars(false) end)
            btnRbEnable:HookScript("OnLeave", RefreshResourceBarButtons)
            btnRbDisable:HookScript("OnLeave", RefreshResourceBarButtons)
            RefreshResourceBarButtons()
        end,
        get = function() return profile.cooldownManager.cdmBars.enabled ~= false end,
        set = function(value) profile.cooldownManager.cdmBars.enabled = value end,
        apply = function()
            if _G._KUI_CDM_Apply then
                pcall(_G._KUI_CDM_Apply)
            end
        end,
        next = function() self:ShowNameplatesStep() end,
        back = function() self:ShowPartyFramesStep() end,
    })
end

function Mod:ShowNameplatesStep()
    _G.KullThranUINameplatesDB = _G.KullThranUINameplatesDB or {}
    if _G.KullThranUINameplatesDB.enable == nil then
        _G.KullThranUINameplatesDB.enable = true
    end

    ShowInstallerModuleToggleStep(self, {
        step = 17,
        requiresReload = true,
        title = "KullThranUI Nameplates",
        question = "Which nameplate system do you want to use?",
        location = "Choose another addon to leave KullThranUI Nameplates disabled.",
        enableLabel = "Use KullThranUI Nameplates",
        disableLabel = "Use Nameplates From Another Addon",
        disabledPreviewLabel = "Using another nameplate addon",
        createPreview = CreateNameplatesInstallerPreview,
        styleRow = {
            get = function()
                local key = _G.KullThranUINameplatesDB.nameplateStyle
                if key == "kui" or key == "forever" or key == "retail" or key == "classic" then return key end
                local themes = KT.VisualThemes
                return themes and themes.GetRenderedTheme and themes:GetRenderedTheme() or "kui"
            end,
            set = function(key)
                local d = _G.KullThranUINameplatesDB
                local adapter = KT.VisualThemes and KT.VisualThemes.GetModuleAdapter and KT.VisualThemes:GetModuleAdapter("nameplates")
                local P = (adapter and adapter.getProfile and adapter.getProfile()) or d
                -- Same reset the Nameplates options tile performs: sizes go back to the style's own.
                local prefixes = { "healthBar", "castBar", "cast", "enemyName", "level", "name", "classPower",
                    "textSlot", "raidMarker", "rareElite", "targetArrow", "focusCast" }
                for _, tbl in ipairs({ d, P }) do
                    for field in pairs(tbl) do
                        if type(field) == "string" and not field:find("^friendly") then
                            for _, prefix in ipairs(prefixes) do
                                if field:sub(1, #prefix) == prefix then tbl[field] = nil break end
                            end
                        end
                    end
                end
                if adapter and adapter.seed then
                    pcall(adapter.seed, P, key)
                    if adapter.validate then pcall(adapter.validate, P) end
                end
                d.nameplateStyle = key
                P.nameplateStyle = key
                d.classPowerPos = "bottom"
                self:DeferReload(17)
            end,
            rebuild = true,
        },
        get = function() return _G.KullThranUINameplatesDB.enable ~= false end,
        set = function(value) _G.KullThranUINameplatesDB.enable = value end,
        next = function() self:ShowAddonListStep() end,
        back = function() self:ShowCooldownManagerStep() end,
    })
end

-- Download button of the Recommended Addons list: the KUI cut-corner button
-- with a download glyph (arrow over a tray, installer_toggle.py) in the
-- accent; on hover the arrow keeps dropping into the tray and turns white.
local DOWNLOAD_DROP = 4        -- px the arrow travels
local DOWNLOAD_PERIOD = 0.9    -- seconds per drop

local function CreateInstallerDownloadButton(parent, width, height)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 100, height or 22)
    btn:SetText(L["Download"])
    SkinButton(btn)

    local glyph = CreateFrame("Frame", nil, btn)
    glyph:SetSize(14, 14)
    glyph:SetPoint("LEFT", btn, "LEFT", 9, 0)
    glyph:SetFrameLevel(btn:GetFrameLevel() + 2)
    local tray = glyph:CreateTexture(nil, "OVERLAY")
    tray:SetAllPoints()
    tray:SetTexture(INSTALLER_TOGGLE_PATH .. "download_tray.png")
    local arrow = glyph:CreateTexture(nil, "OVERLAY", nil, 1)
    arrow:SetSize(14, 14)
    arrow:SetTexture(INSTALLER_TOGGLE_PATH .. "download_arrow.png")

    local fs = btn:GetFontString()
    if fs then
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", glyph, "RIGHT", 5, 0)
        fs:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    end

    local clock, hover = 0, 0
    btn:HookScript("OnUpdate", function(self, elapsed)
        local target = (self:IsMouseOver() and self:IsEnabled()) and 1 or 0
        hover = hover + (target - hover) * math.min(1, elapsed * 10)
        local drop = 0
        if hover > 0.05 then
            clock = clock + elapsed
            local t = (clock % DOWNLOAD_PERIOD) / DOWNLOAD_PERIOD
            drop = DOWNLOAD_DROP * (1 - (1 - t) ^ 2) * hover
            arrow:SetAlpha(1 - 0.7 * t * hover)
        else
            clock = 0
            arrow:SetAlpha(1)
        end
        arrow:ClearAllPoints()
        arrow:SetPoint("CENTER", glyph, "CENTER", 0, -drop)
        local r = KT_COLOR[1] + (1 - KT_COLOR[1]) * hover
        local g = KT_COLOR[2] + (1 - KT_COLOR[2]) * hover
        local b = KT_COLOR[3] + (1 - KT_COLOR[3]) * hover
        arrow:SetVertexColor(r, g, b, 1)
        tray:SetVertexColor(r, g, b, 1)
    end)
    return btn
end

function Mod:ShowAddonListStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 18
    self:UpdateProgressBar(18)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content
    
    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(L["Recommended Addons"])
    title:SetTextColor(unpack(KT_COLOR))
    
    -- ScrollFrame Container
    local scrollContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    scrollContainer:SetPoint("TOPLEFT", 30, -70)
    scrollContainer:SetPoint("BOTTOMRIGHT", -30, 96)
    CreateBackdrop(scrollContainer)
    scrollContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
    
    local scroll = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 5, -5)
    scroll:SetPoint("BOTTOMRIGHT", -25, 5)
    
    -- ScrollBar Color
    local scrollBar = scroll.ScrollBar
    if scrollBar then
        local thumbtack = scrollBar:GetThumbTexture()
        if thumbtack then 
            thumbtack:SetColorTexture(unpack(KT_COLOR))
            thumbtack:SetHeight(30)
        end 
    end

    local CONTENT_WIDTH = 710

    local child = CreateFrame("Frame")
    child:SetSize(CONTENT_WIDTH, 1)
    scroll:SetScrollChild(child)

    local function UpdateAddonListScrollbar()
        if not scrollBar then
            return
        end

        local contentHeight = child:GetHeight() or 0
        local viewportHeight = scroll:GetHeight() or 0
        local needsScroll = contentHeight > (viewportHeight + 1)

        scrollBar:SetShown(needsScroll)
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT", 5, -5)
        scroll:SetPoint("BOTTOMRIGHT", needsScroll and -25 or -5, 5)
        if not needsScroll then
            scroll:SetVerticalScroll(0)
        end
    end

    -- Ordenar: Primero los que tienen perfil, luego alfabéticamente
    table.sort(RECOMMENDED_ADDONS, function(a, b)
        local function HasProfile(addon)
            -- 1. String directo en la tabla
            if addon.profileString then return true end
            -- 2. String en KT.ProfileStrings (Legacy)
            if KT.ProfileStrings then
                if KT.ProfileStrings[addon.name] then return true end
                if addon.folder and KT.ProfileStrings[addon.folder] then return true end
                if addon.altFolder and KT.ProfileStrings[addon.altFolder] then return true end
            end
            -- 3. Tabla en ns.ProfileData (Nuevo sistema)
            if ns.ProfileData then
                if ns.ProfileData[addon.name] then return true end
                if addon.folder and ns.ProfileData[addon.folder] then return true end
                if addon.altFolder and ns.ProfileData[addon.altFolder] then return true end
            end
            return false
        end
        
        local hasA = HasProfile(a)
        local hasB = HasProfile(b)
        
        if hasA and not hasB then return true end
        if not hasA and hasB then return false end
        return a.name < b.name
    end)
    
    local y = 0
    for i, addon in ipairs(RECOMMENDED_ADDONS) do
        local addon = addon -- Capturar la variable para evitar que todos los botones usen la URL del último addon
        local row = CreateFrame("Frame", nil, child)
        row:SetSize(CONTENT_WIDTH, 32)
        row:SetPoint("TOPLEFT", 0, y)
        
        -- Zebra striping
        if i % 2 == 0 then
            local bg = row:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, 0.03)
        end
        
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", 5, 0)
        local iconName = addon.icon
        if not iconName:find("%.tga$") then iconName = iconName .. ".tga" end
        icon:SetTexture(ICON_PATH .. iconName)
        
        -- Icon Border
        local iconBorder = row:CreateTexture(nil, "OVERLAY")
        iconBorder:SetPoint("TOPLEFT", icon, -1, 1)
        iconBorder:SetPoint("BOTTOMRIGHT", icon, 1, -1)
        iconBorder:SetColorTexture(0,0,0,1)
        iconBorder:SetDrawLayer("ARTWORK", -1)
        
        local name = row:CreateFontString(nil, "OVERLAY")
        name:SetPoint("LEFT", icon, "RIGHT", 10, 0)
        name:SetFont(GetKTFont(), 14)
        name:SetText(addon.name)
        name:SetJustifyH("LEFT")
        
        local addonID = addon.folder or addon.name
        local info = C_AddOns.GetAddOnInfo(addonID)
        
        if not info and addon.altFolder then
            addonID = addon.altFolder
            info = C_AddOns.GetAddOnInfo(addonID)
        end
        
        -- Mejor detección de estado: Si está cargado, está habilitado seguro.
        local enableState = C_AddOns.GetAddOnEnableState(addonID, UnitName("player") or "")
        local isInstalled = (info ~= nil)
        local isEnabled = (enableState > 0) or C_AddOns.IsAddOnLoaded(addonID)
        
        -- Resolver string del perfil (Prioridad: Tabla externa > Config local)
        local profileString = addon.profileString
        if not profileString and KT.ProfileStrings then
            profileString = KT.ProfileStrings[addon.name] 
                         or (addon.folder and KT.ProfileStrings[addon.folder])
                         or (addon.altFolder and KT.ProfileStrings[addon.altFolder])
        end

        -- 1. Download Button (SIEMPRE VISIBLE)
        local btnDownload = CreateInstallerDownloadButton(row, 112, 22)
        btnDownload:SetPoint("RIGHT", -5, 0)
        btnDownload:SetScript("OnClick", function()
            StaticPopup_Show("KT_INSTALLER_URL", nil, nil, addon.url)
        end)
        
        -- 2. Apply Profile Button (A la izquierda de Download)
        local rightAnchor = btnDownload
        
        local handled = false
        
        -- Sistema de Handlers (Lua Tables)
        if isInstalled and ns.ProfileData and ns.Handlers then
            -- CASO ESPECIAL: addon externo con doble perfil
            if addon.name == "DandersFrames" and ns.ProfileData.DandersFrames then
                local btnHeal = CreateFrame("Button", nil, row, "BackdropTemplate")
                btnHeal:SetSize(60, 20)
                btnHeal:SetPoint("RIGHT", btnDownload, "LEFT", -5, 0)
                btnHeal:SetText(L["Healer"])
                SkinButton(btnHeal)
                btnHeal:SetScript("OnClick", function()
                    StaticPopup_Show("KT_INSTALLER_PROFILE", "Danders Frames (Healer)", nil, { func = function() 
                        ns.Handlers.DandersFrames(nil, ns.ProfileData.DandersFrames)
                        ForceSetProfile("DandersFrames", "KullThranUI - Healer", "DandersFramers")
                        KT:Print(string.format(LText("Profile Applied: %s (%s)"), "DandersFrames", LText("Healer")))
                    end })
                end)
                
                local btnDPS = CreateFrame("Button", nil, row, "BackdropTemplate")
                btnDPS:SetSize(60, 20)
                btnDPS:SetPoint("RIGHT", btnHeal, "LEFT", -5, 0)
                btnDPS:SetText(L["DPS"])
                SkinButton(btnDPS)
                btnDPS:SetScript("OnClick", function()
                    StaticPopup_Show("KT_INSTALLER_PROFILE", "Danders Frames (DPS)", nil, { func = function() 
                        ns.Handlers.DandersFrames(nil, ns.ProfileData.DandersFrames)
                        ForceSetProfile("DandersFrames", "KullThranUI - DPS/Tank", "DandersFramers")
                        KT:Print(string.format(LText("Profile Applied: %s (%s)"), "DandersFrames", LText("DPS")))
                    end })
                end)
                
                rightAnchor = btnDPS
                handled = true
                
            -- CASO GENÉRICO: addon externo con perfil único
            elseif ns.ProfileData[addon.name] and ns.Handlers[addon.name] then
                local btnProfile = CreateFrame("Button", nil, row, "BackdropTemplate")
                btnProfile:SetSize(90, 20)
                btnProfile:SetPoint("RIGHT", btnDownload, "LEFT", -5, 0)
                btnProfile:SetText(L["Apply Profile"])
                SkinButton(btnProfile)
                btnProfile:SetScript("OnClick", function()
                    StaticPopup_Show("KT_INSTALLER_PROFILE", addon.name, nil, { func = function() 
                        ns.Handlers[addon.name]("KullThranUI", ns.ProfileData[addon.name])
                        ForceSetProfile(addon.name, "KullThranUI")
                        KT:Print(string.format(LText("Profile Applied: %s"), addon.name))
                    end })
                end)
                rightAnchor = btnProfile
                handled = true
            end
        end

        -- Sistema de Strings (Fallback)
        if isInstalled and not handled and profileString then
            local btnProfile = CreateFrame("Button", nil, row, "BackdropTemplate")
            btnProfile:SetSize(90, 20)
            btnProfile:SetPoint("RIGHT", btnDownload, "LEFT", -5, 0)
            btnProfile:SetText(L["Apply Profile"])
            SkinButton(btnProfile)
            btnProfile:SetScript("OnClick", function()
                self:ShowProfileImportStep(addon.name, profileString)
            end)
            rightAnchor = btnProfile
        end

        -- 3. Status Text (A la izquierda de los botones)
        if isInstalled then
            local status = row:CreateFontString(nil, "OVERLAY")
            status:SetPoint("RIGHT", rightAnchor, "LEFT", -10, 0)
            status:SetFont(GetKTFont(), 14)
            
            if isEnabled then
                status:SetText(L["Installed"])
                status:SetTextColor(0, 1, 0) -- Green
            else
                status:SetText(L["Disabled"])
                status:SetTextColor(1, 0.5, 0) -- Orange
            end
        end
        
        y = y - 33
    end
    child:SetHeight(-y)
    UpdateAddonListScrollbar()
    
    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() self:ShowAccessStep() end)
    
    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowNameplatesStep() end)
    
    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)
    
    local chk = CreateSkipCheckbox(content, btnSkip)
    btnSkip:SetScript("OnClick", function() 
        if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end
        self.frame:Hide()
    end)
    
    -- Reload UI Button (Manual)
    local btnReload = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnReload:SetSize(120, 30)
    btnReload:SetPoint("LEFT", btnSkip, "RIGHT", 10, 0)
    btnReload:SetText(L["Reload UI"])
    SkinButton(btnReload)
    btnReload:SetScript("OnClick", function() 
        RequestInstallerReload(self, KT.db.profile.installer.step)
    end)
end

function Mod:ShowProfileImportStep(addonName, profileString)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    -- Title
    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(string.format(L["Import Profile: %s"], addonName))
    title:SetTextColor(unpack(KT_COLOR))

    -- Instructions
    local instructions = content:CreateFontString(nil, "OVERLAY")
    instructions:SetPoint("TOP", title, "BOTTOM", 0, -20)
    instructions:SetWidth(600)
    instructions:SetFont(GetKTFont(), 14, "OUTLINE")
    instructions:SetText(string.format(L["Open /kui, External Addons panel, find '%s', open the 'Profiles' tab and paste the string in the Import Profile option."], addonName))
    instructions:SetTextColor(0.9, 0.9, 0.9)
    instructions:SetJustifyH("CENTER")

    -- EditBox Container
    local scrollContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    scrollContainer:SetPoint("TOPLEFT", 50, -120)
    scrollContainer:SetPoint("BOTTOMRIGHT", -50, 96)
    CreateBackdrop(scrollContainer)
    scrollContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.5)

    local scroll = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 5, -5)
    scroll:SetPoint("BOTTOMRIGHT", -25, 5)

    local editBox = CreateFrame("EditBox", nil, scroll)
    editBox:SetMultiLine(true)
    editBox:SetFont(GetKTFont(), 12, "")
    editBox:SetWidth(680)
    editBox:SetText(profileString or "")
    editBox:SetFocus()
    editBox:HighlightText()
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    
    scroll:SetScrollChild(editBox)

    -- Back Button
    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("BOTTOM", 0, 30)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowAddonListStep() end)
end

-- Interface scale and frame positions. Nothing is changed until the player
-- picks an option and presses Apply: the current scale and the saved
-- positions are the defaults.
function Mod:ShowProfileStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = STEP_PROFILE
    self:UpdateProgressBar(STEP_PROFILE)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(LText("Interface Scale & Positions"))
    title:SetTextColor(unpack(KT_COLOR))

    local intro = content:CreateFontString(nil, "OVERLAY")
    intro:SetPoint("TOP", title, "BOTTOM", 0, -10)
    intro:SetWidth(660)
    intro:SetFont(GetKTFont(), 13)
    intro:SetText(LText("Your current scale and your saved frame positions are kept unless you choose otherwise and press Apply."))
    intro:SetTextColor(0.9, 0.9, 0.9)
    intro:SetJustifyH("CENTER")

    local function CreateChoice(label, width, anchorPoint, anchor, relPoint, x, y)
        local btn = CreateFrame("Button", nil, content, "BackdropTemplate")
        btn:SetSize(width, 32)
        btn:SetPoint(anchorPoint, anchor, relPoint, x, y)
        btn:SetText(LText(label))
        SkinButton(btn)
        btn:HookScript("OnLeave", function(self)
            self:SetBackdropBorderColor(unpack(self.KT_selected and KT_COLOR or COLOR_BORDER))
        end)
        return btn
    end
    local function SelectChoice(group, selected)
        for _, btn in ipairs(group) do
            btn.KT_selected = (btn == selected)
            btn:SetBackdropBorderColor(unpack(btn.KT_selected and KT_COLOR or COLOR_BORDER))
        end
    end
    local function SetApplyEnabled(btn, enabled)
        if enabled then btn:Enable() else btn:Disable() end
        btn:SetAlpha(enabled and 1 or 0.4)
    end

    -- INTERFACE SCALE
    local scaleTitle = content:CreateFontString(nil, "OVERLAY")
    scaleTitle:SetPoint("TOP", intro, "BOTTOM", 0, -26)
    scaleTitle:SetFont(GetKTFont(), 18, "OUTLINE")
    scaleTitle:SetText(LText("Interface scale"))
    scaleTitle:SetTextColor(0.9, 0.9, 0.9)

    local scaleCurrent = content:CreateFontString(nil, "OVERLAY")
    scaleCurrent:SetPoint("TOP", scaleTitle, "BOTTOM", 0, -6)
    scaleCurrent:SetFont(GetKTFont(), 12)
    scaleCurrent:SetTextColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 1)
    local function RefreshCurrentScale()
        local scale = UIParent and UIParent.GetScale and UIParent:GetScale() or 1
        scaleCurrent:SetText(string.format(LText("Current scale: %s"), string.format("%.2f", scale)))
    end
    RefreshCurrentScale()

    local scaleChoices = {}
    local scaleValue = "KEEP"
    local scaleOptions = {
        { label = "Keep my current scale", value = "KEEP", width = 190 },
        { label = L["1080p"] or "1080p", value = "1080", width = 120 },
        { label = L["2K (1440p)"] or "2K (1440p)", value = "2K", width = 140 },
        { label = L["4K (2160p)"] or "4K (2160p)", value = "4K", width = 140 },
    }
    local previous
    for index, option in ipairs(scaleOptions) do
        local btn
        if previous then
            btn = CreateChoice(option.label, option.width, "LEFT", previous, "RIGHT", 10, 0)
        else
            -- Row is 190 + 120 + 140 + 140 + 3 * 10 wide; centre it.
            btn = CreateChoice(option.label, option.width, "TOP", scaleCurrent, "BOTTOM", -((620 / 2) - (190 / 2)), -14)
        end
        btn.KT_value = option.value
        scaleChoices[index] = btn
        previous = btn
    end

    local btnApplyScale = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnApplyScale:SetSize(190, 30)
    btnApplyScale:SetPoint("TOP", scaleCurrent, "BOTTOM", 0, -58)
    btnApplyScale:SetText(L["Apply Scale"])
    SkinButton(btnApplyScale)
    SetApplyEnabled(btnApplyScale, false)
    for _, btn in ipairs(scaleChoices) do
        btn:SetScript("OnClick", function()
            scaleValue = btn.KT_value
            SelectChoice(scaleChoices, btn)
            SetApplyEnabled(btnApplyScale, scaleValue ~= "KEEP")
        end)
    end
    SelectChoice(scaleChoices, scaleChoices[1])
    btnApplyScale:SetScript("OnClick", function()
        if scaleValue == "KEEP" then return end
        -- Silent: changes only the scale. Positions and the Edit Mode
        -- profile are left alone, and no reload is needed.
        self:ApplyScaleOnly(scaleValue, { silent = true })
        RefreshCurrentScale()
        scaleValue = "KEEP"
        SelectChoice(scaleChoices, scaleChoices[1])
        SetApplyEnabled(btnApplyScale, false)
    end)

    -- FRAME POSITIONS
    local posTitle = content:CreateFontString(nil, "OVERLAY")
    posTitle:SetPoint("TOP", btnApplyScale, "BOTTOM", 0, -22)
    posTitle:SetFont(GetKTFont(), 18, "OUTLINE")
    posTitle:SetText(LText("Frame positions"))
    posTitle:SetTextColor(0.9, 0.9, 0.9)

    -- Hover hint: how to move the frames later with Unlock Mode.
    if KT.Widgets and KT.Widgets.InfoHint then
        local moveHint = KT.Widgets:InfoHint(content, {
            label = LText("How do I move frames?"),
            title = LText("Moving your frames"),
            text = LText("After the installer, open Unlock Mode to place every KullThranUI frame where you want it."),
            items = {
                LText("Open it with the KUI Unlock Mode button in the game menu (Esc), from the /kui window or with /ktunlock."),
                LText("Drag frames to move them and right-click one for its options."),
                LText("Nothing changes until you press Save; Discard leaves everything as it was."),
            },
            height = 24,
            accent = function() return KT_COLOR[1], KT_COLOR[2], KT_COLOR[3] end,
        })
        moveHint:SetPoint("LEFT", posTitle, "RIGHT", 14, 0)
    end

    local posChoices = {}
    local keepPositions = CreateChoice("Keep my saved positions", 250, "TOP", posTitle, "BOTTOM", -130, -12)
    local kuiPositions = CreateChoice("Use KullThranUI default positions", 250, "LEFT", keepPositions, "RIGHT", 10, 0)
    keepPositions.KT_value, kuiPositions.KT_value = "KEEP", "KUI"
    posChoices[1], posChoices[2] = keepPositions, kuiPositions
    SelectChoice(posChoices, keepPositions)

    local btnApplyPositions = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnApplyPositions:SetSize(250, 30)
    btnApplyPositions:SetPoint("TOP", posTitle, "BOTTOM", 0, -58)
    btnApplyPositions:SetText(LText("Apply Positions"))
    SkinButton(btnApplyPositions)
    SetApplyEnabled(btnApplyPositions, false)
    for _, btn in ipairs(posChoices) do
        btn:SetScript("OnClick", function()
            SelectChoice(posChoices, btn)
            SetApplyEnabled(btnApplyPositions, btn.KT_value == "KUI")
        end)
    end
    btnApplyPositions:SetScript("OnClick", function()
        local _, height = GetPhysicalScreenSize()
        local layoutKey = (height and height >= 2160 and "4K") or (height and height >= 1440 and "2K") or "1080p"
        local layout = ns.ProfileData and ns.ProfileData.Layouts and ns.ProfileData.Layouts[layoutKey]
        if not (layout and ns.Handlers and ns.Handlers.Layout) then return end
        StaticPopup_Show("KT_INSTALLER_PROFILE", LText("KullThranUI default positions"), nil, { func = function()
            ns.Handlers.Layout(KT.db:GetCurrentProfile(), layout)
            self:DeferReload(STEP_PROFILE)
        end })
    end)

    local editModeNote = content:CreateFontString(nil, "OVERLAY")
    editModeNote:SetPoint("TOP", btnApplyPositions, "BOTTOM", 0, -12)
    editModeNote:SetWidth(620)
    editModeNote:SetFont(GetKTFont(), 12)
    editModeNote:SetText(LText("NOTE: Using the KullThranUI default positions replaces your Blizzard Edit Mode profile."))
    editModeNote:SetTextColor(1, 0.85, 0.2)
    editModeNote:SetJustifyH("CENTER")

    -- VERSION WARNING BOX
    local verFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    verFrame:SetSize(600, 50)
    verFrame:SetPoint("TOP", editModeNote, "BOTTOM", 0, -16)
    CreateBackdrop(verFrame)
    verFrame:SetBackdropColor(0.2, 0, 0, 0.5)
    verFrame:SetBackdropBorderColor(1, 0.2, 0.2, 1)

    local verText = verFrame:CreateFontString(nil, "OVERLAY")
    verText:SetPoint("CENTER", 0, 0)
    verText:SetWidth(560)
    verText:SetFont(GetKTFont(), 13)
    local verMessage = L["|cffff5555WARNING:|r If updating from version 3.0.0 or lower, it is highly recommended to |cffffffffRestore Defaults|r."]
        or "|cffff5555WARNING:|r If updating from version 3.0.0 or lower, it is highly recommended to |cffffffffRestore Defaults|r."
    verText:SetText((verMessage:gsub("3%.0%.0", "5.0.0")))
    verText:SetTextColor(1, 1, 1)

    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function()
        self:ShowThemeStep()
    end)

    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowLanguageStep() end)
end

-- Opening KullThranUI: one card each for the /kui options, Unlock Mode and
-- this installer, with what it is for, its slash commands and the other
-- ways in (game menu, minimap button, /kui window).
local ACCESS_CARD_W, ACCESS_CARD_GAP = 232, 14
local ACCESS_ROUND = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\InfoHint\\round16"
local ACCESS_ICONS = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\UnlockSidebar\\icons_base"

local function AccessRounded(frame, layer, sublevel, file)
    local tex = frame:CreateTexture(nil, layer, nil, sublevel)
    tex:SetAllPoints()
    tex:SetTexture(ACCESS_ROUND .. file .. ".png")
    local sliced = tex.SetTextureSliceMargins and pcall(tex.SetTextureSliceMargins, tex, 16, 16, 16, 16)
    if sliced and tex.SetTextureSliceMode then pcall(tex.SetTextureSliceMode, tex, 0) end
    if not sliced then tex:SetTexture(EFL_WHITE8X8) end
    return tex
end

-- An atlas cell of the Unlock Mode icons (unlock_sidebar.py, 8x4 of 64px).
local function AccessIcon(texture, cell)
    local col, row = cell % 8, math.floor(cell / 8)
    texture:SetTexture(ACCESS_ICONS)
    texture:SetTexCoord(col / 8, (col + 1) / 8, row / 4, (row + 1) / 4)
end

local function CreateAccessCard(parent, spec)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(ACCESS_CARD_W)
    local fill = AccessRounded(card, "BACKGROUND", 0, "")
    if CreateColor and fill.SetGradient then
        pcall(fill.SetGradient, fill, "VERTICAL", CreateColor(0.058, 0.054, 0.052, 0.95), CreateColor(0.105, 0.098, 0.094, 0.95))
    else
        fill:SetVertexColor(0.08, 0.075, 0.07, 0.95)
    end
    local edge = AccessRounded(card, "BORDER", 0, "_edge")
    edge:SetVertexColor(1, 1, 1, 0.10)
    local topLine = card:CreateTexture(nil, "ARTWORK")
    topLine:SetTexture(EFL_WHITE8X8)
    topLine:SetPoint("TOPLEFT", 18, -1)
    topLine:SetPoint("TOPRIGHT", -18, -1)
    topLine:SetHeight(2)
    topLine:SetVertexColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 0.9)

    local disc = card:CreateTexture(nil, "ARTWORK")
    disc:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\InfoHint\\disc.png")
    disc:SetSize(44, 44)
    disc:SetPoint("TOP", 0, -18)
    disc:SetVertexColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 0.18)
    local icon = card:CreateTexture(nil, "OVERLAY")
    icon:SetSize(spec.logo and 30 or 22, spec.logo and 30 or 22)
    icon:SetPoint("CENTER", disc, "CENTER")
    if spec.logo then
        icon:SetTexture(spec.logo)
    else
        AccessIcon(icon, spec.icon)
    end
    icon:SetVertexColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 1)

    local title = card:CreateFontString(nil, "OVERLAY")
    title:SetFont(GetKTFont(), 15, "OUTLINE")
    title:SetPoint("TOP", disc, "BOTTOM", 0, -10)
    title:SetWidth(ACCESS_CARD_W - 24)
    title:SetText(LText(spec.title))
    title:SetTextColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 1)

    local text = card:CreateFontString(nil, "OVERLAY")
    text:SetFont(GetKTFont(), 12, "")
    text:SetPoint("TOP", title, "BOTTOM", 0, -8)
    text:SetWidth(ACCESS_CARD_W - 32)
    text:SetSpacing(2)
    text:SetText(LText(spec.text))
    text:SetTextColor(0.85, 0.85, 0.88, 1)

    local labelY = -(18 + 44 + 10 + 18 + 8 + math.ceil(text:GetStringHeight() or 30) + 18)
    local label = card:CreateFontString(nil, "OVERLAY")
    label:SetFont(GetKTFont(), 10, "")
    label:SetPoint("TOPLEFT", card, "TOPLEFT", 16, labelY)
    label:SetText(string.upper(LText("Open it with")))
    label:SetTextColor(0.55, 0.55, 0.6, 1)

    -- Slash commands as accent chips, wrapping onto a second line.
    local x, rowY = 16, labelY - 18
    for _, command in ipairs(spec.commands) do
        local chip = CreateFrame("Frame", nil, card)
        local chipText = chip:CreateFontString(nil, "OVERLAY")
        chipText:SetFont(GetKTFont(), 12, "OUTLINE")
        chipText:SetPoint("CENTER")
        chipText:SetText(command)
        chipText:SetTextColor(1, 1, 1, 1)
        local w = math.ceil((chipText.GetUnboundedStringWidth and chipText:GetUnboundedStringWidth() or chipText:GetStringWidth()) + 20)
        if x + w > ACCESS_CARD_W - 16 then
            x, rowY = 16, rowY - 30
        end
        chip:SetSize(w, 24)
        chip:SetPoint("TOPLEFT", card, "TOPLEFT", x, rowY)
        local chipFill = AccessRounded(chip, "BACKGROUND", 0, "")
        chipFill:SetVertexColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 0.18)
        local chipEdge = AccessRounded(chip, "BORDER", 0, "_edge")
        chipEdge:SetVertexColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 0.75)
        x = x + w + 8
    end
    rowY = rowY - 36

    -- Other ways in, one line each with a bullet.
    for _, way in ipairs(spec.ways) do
        local dot = card:CreateTexture(nil, "ARTWORK")
        dot:SetTexture(EFL_WHITE8X8)
        dot:SetSize(4, 4)
        dot:SetPoint("TOPLEFT", card, "TOPLEFT", 18, rowY - 5)
        dot:SetVertexColor(KT_COLOR[1], KT_COLOR[2], KT_COLOR[3], 1)
        local line = card:CreateFontString(nil, "OVERLAY")
        line:SetFont(GetKTFont(), 11, "")
        line:SetPoint("TOPLEFT", card, "TOPLEFT", 30, rowY)
        line:SetWidth(ACCESS_CARD_W - 46)
        line:SetJustifyH("LEFT")
        line:SetSpacing(2)
        line:SetText(LText(way))
        line:SetTextColor(0.78, 0.78, 0.82, 1)
        rowY = rowY - math.ceil(line:GetStringHeight() or 14) - 8
    end
    card:SetHeight(-rowY + 10)
    return card
end

function Mod:ShowAccessStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 30
    self:UpdateProgressBar(30)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(LText("Opening KullThranUI"))
    title:SetTextColor(unpack(KT_COLOR))

    local subtitle = content:CreateFontString(nil, "OVERLAY")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -10)
    subtitle:SetWidth(680)
    subtitle:SetFont(GetKTFont(), 14)
    subtitle:SetText(LText("Everything you choose here can be changed later. This is how to get back to each part of KullThranUI."))
    subtitle:SetTextColor(0.9, 0.9, 0.9)
    subtitle:SetJustifyH("CENTER")

    local cards = {
        { title = "KUI Options", logo = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png",
          text = "Every module, style and colour of KullThranUI in one window.",
          commands = { "/kui", "/kt" },
          ways = { "Game menu (Esc) > KullThranUI", "Right-click the KUI minimap button" } },
        { title = "KUI Unlock Mode", icon = 27,
          text = "Move, resize and anchor every KullThranUI frame on screen.",
          commands = { "/ktunlock" },
          ways = { "Game menu (Esc) > KUI Unlock Mode", "The Unlock Mode button in the /kui window" } },
        { title = "Installer", icon = 31,
          text = "Run this setup again whenever you want to change your choices.",
          commands = { "/installer", "/ins" },
          ways = { "Tick Don't show again to stop it opening at login" } },
    }
    local total = #cards * ACCESS_CARD_W + (#cards - 1) * ACCESS_CARD_GAP
    for index, spec in ipairs(cards) do
        local card = CreateAccessCard(content, spec)
        card:SetPoint("TOPLEFT", content, "TOP", -total / 2 + (index - 1) * (ACCESS_CARD_W + ACCESS_CARD_GAP), -112)
    end

    local btnNext = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnNext:SetSize(120, 30)
    btnNext:SetPoint("BOTTOMRIGHT", -30, 30)
    btnNext:SetText(L["Next Step"])
    SkinButton(btnNext)
    btnNext:SetScript("OnClick", function() self:ShowModuleSelectionStep() end)

    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnNext, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowAddonListStep() end)

    local btnSkip = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnSkip:SetSize(120, 30)
    btnSkip:SetPoint("BOTTOMLEFT", 30, 30)
    btnSkip:SetText(L["Skip Install"])
    SkinButton(btnSkip)

    local chk = CreateSkipCheckbox(content, btnSkip)
    btnSkip:SetScript("OnClick", function()
        if chk:GetChecked() then KT.db.profile.installer.showOnLogin = false end
        self.frame:Hide()
    end)
end

function Mod:ShowModuleSelectionStep()
    L = KT:GetLocale()
    KT.db.profile.installer.step = 20
    self:UpdateProgressBar(20)
    if self.content then self.content:Hide() end
    local content = CreateFrame("Frame", nil, self.frame)
    content:SetAllPoints()
    self.content = content

    local title = content:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOP", 0, -30)
    title:SetFont(GetKTFont(), 24, "OUTLINE")
    title:SetText(L["Module Selection"])
    title:SetTextColor(unpack(KT_COLOR))

    local info = content:CreateFontString(nil, "OVERLAY")
    info:SetPoint("TOP", title, "BOTTOM", 0, -16)
    info:SetWidth(660)
    info:SetFont(GetKTFont(), 13)
    info:SetText(L["Toggle which KullThranUI modules you want enabled. Changes take effect after a reload."])
    info:SetTextColor(0.9, 0.9, 0.9)
    info:SetJustifyH("CENTER")

    local p = KT.db.profile
    p.resourceBars = p.resourceBars or { enabled = true }
    if p.resourceBars.enabled == nil then p.resourceBars.enabled = true end
    p.skin = p.skin or { enable = true }
    p.minimap = p.minimap or { enable = true }
    p.actionbars = p.actionbars or { enable = true }
    p.buffsAndDebuffs = p.buffsAndDebuffs or { enable = true }
    p.castbar = p.castbar or { enable = true }
    p.tooltip = p.tooltip or { enable = true }
    p.armory = p.armory or { enable = true }
    p.dragonRiding = p.dragonRiding or { enable = true }
    p.experienceBar = p.experienceBar or { enable = true }
    p.chat = p.chat or { enable = true }
    p.bags = p.bags or { enable = true }
    p.objectiveTracker = p.objectiveTracker or { enable = true }
    if p.objectiveTracker.enable == nil then
        p.objectiveTracker.enable = true
    end
    p.unitFrames = p.unitFrames or { enable = true }
    p.partyFrames = p.partyFrames or { enable = true }
    p.cursor = p.cursor or { enable = true }
    p.teleportMenu = p.teleportMenu or { enable = true }
    p.inspectArmory = p.inspectArmory or { enable = true }
    p.enhancements = p.enhancements or { enable = true }
    p.externalAddons = p.externalAddons or { enable = true }
    p.enhancements.damageMeter = p.enhancements.damageMeter or { moduleEnabled = true }
    p.enhancements.mplusTracker = p.enhancements.mplusTracker or { enabled = true }
    if p.enhancements.mplusTracker.enabled == nil then p.enhancements.mplusTracker.enabled = true end
    _G.KullThranUINameplatesDB = _G.KullThranUINameplatesDB or { enable = true }
    p.cooldownManager = p.cooldownManager or { cdmBars = { enabled = false } }
    p.cooldownManager.cdmBars = p.cooldownManager.cdmBars or { enabled = false }
    p.resourceBars = p.resourceBars or {
        health = { enabled = false },
        primary = { enabled = true, hideMana = false },
        secondary = { enabled = true },
    }

    local function CreateToggleRow(x, y, label, getValue, setValue)
        local cb = CreateFrame("CheckButton", nil, content, "BackdropTemplate")
        cb:SetSize(18, 18)
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
        CreateBackdrop(cb)
        cb:SetBackdropColor(0, 0, 0, 1)

        cb.Checked = cb:CreateTexture(nil, "ARTWORK")
        cb.Checked:SetTexture("Interface\\Buttons\\WHITE8x8")
        cb.Checked:SetVertexColor(unpack(KT_COLOR))
        cb.Checked:SetAllPoints(cb)

        local text = cb:CreateFontString(nil, "OVERLAY")
        text:SetPoint("LEFT", cb, "RIGHT", 8, 0)
        text:SetFont(GetKTFont(), 13, "OUTLINE")
        text:SetText(LText(label))
        text:SetTextColor(0.9, 0.9, 0.9)

        local function Sync()
            local v = getValue() and true or false
            cb:SetChecked(v)
            cb.Checked:SetAlpha(v and 1 or 0)
        end

        cb:SetScript("OnClick", function(self)
            local v = self:GetChecked() and true or false
            self.Checked:SetAlpha(v and 1 or 0)
            setValue(v)
            content._ktInstallerModulesDirty = true
        end)

        Sync()
        return cb
    end

    local modules = {
        { L["Skins"], function() return p.skin.enable end, function(v) p.skin.enable = v end },
        { L["Minimap"], function() return p.minimap.enable end, function(v) p.minimap.enable = v end },
        { L["Action Bars"], function() return p.actionbars.enable end, function(v) p.actionbars.enable = v end },
        { L["Buffs & Debuffs"], function() return p.buffsAndDebuffs.enable end, function(v) p.buffsAndDebuffs.enable = v end },
        { L["Cast Bar"], function() return p.castbar.enable end, function(v) p.castbar.enable = v end },
        { L["Tooltip"], function() return p.tooltip.enable end, function(v) p.tooltip.enable = v end },
        { L["Armory"], function() return p.armory.enable end, function(v) p.armory.enable = v end },
        { L["Dragon Riding"], function() return p.dragonRiding.enable end, function(v) p.dragonRiding.enable = v end },
        { L["Experience Bar"], function() return p.experienceBar.enable end, function(v) p.experienceBar.enable = v end },
        { L["Chat"], function() return p.chat.enable end, function(v) p.chat.enable = v end },
        { L["Bags"], function() return p.bags.enable end, function(v) p.bags.enable = v end },
        { L["Objective Tracker"], function() return p.objectiveTracker.enable ~= false end, function(v) p.objectiveTracker.enable = v end },
        { L["Unit Frames"], function() return p.unitFrames.enable ~= false end, function(v) p.unitFrames.enable = v end },
        { L["Party Frames"], function() return p.partyFrames.enable ~= false end, function(v) p.partyFrames.enable = v end },
        { L["Enhancements"], function() return p.enhancements.enable ~= false end, function(v) p.enhancements.enable = v end },
        { "   - " .. L["Damage Meter"], function() return p.enhancements.damageMeter.moduleEnabled ~= false end, function(v) p.enhancements.damageMeter.moduleEnabled = v and true or false end },
        { "   - " .. L["Mythic+ Timer"], function() return p.enhancements.mplusTracker.enabled ~= false end, function(v) p.enhancements.mplusTracker.enabled = v and true or false end },
        { L["External Addons"], function() return p.externalAddons.enable ~= false end, function(v) p.externalAddons.enable = v end },
        { L["Cursor"], function() return p.cursor.enable ~= false end, function(v) p.cursor.enable = v end },
        { L["Teleport Menu"], function() return p.teleportMenu.enable ~= false end, function(v) p.teleportMenu.enable = v end },
        { L["Inspect Armory"], function() return p.inspectArmory.enable ~= false end, function(v) p.inspectArmory.enable = v end },
        { L["Aura Reminders"], function() local auraDB = _G._KUIAR_AceDB; return not (auraDB and auraDB.profile and auraDB.profile.enable == false) end, function(v) local auraDB = _G._KUIAR_AceDB; if auraDB and auraDB.profile then auraDB.profile.enable = v and true or false end end },
        { L["Nameplates"], function() return _G.KullThranUINameplatesDB.enable ~= false end, function(v) _G.KullThranUINameplatesDB.enable = v and true or false end },
        { L["Cooldown Manager"], function() return p.cooldownManager.cdmBars.enabled end, function(v) p.cooldownManager.cdmBars.enabled = v end },
        { L["Resource Bars"], function()
            return p.resourceBars.enabled ~= false
        end, function(v)
            p.resourceBars.enabled = v and true or false
        end },
    }

    local startY = -120
    local rowH = 30
    local col1X = 120
    local col2X = 420
    local rowsPerCol = math.ceil(#modules / 2)

    for i, entry in ipairs(modules) do
        local col = (i <= rowsPerCol) and 1 or 2
        local row = (col == 1) and (i - 1) or (i - rowsPerCol - 1)
        local x = (col == 1) and col1X or col2X
        local y = startY - rowH * row
        CreateToggleRow(x, y, entry[1], entry[2], entry[3])
    end

    local btnFinish = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnFinish:SetSize(120, 30)
    btnFinish:SetPoint("BOTTOMRIGHT", -30, 30)
    btnFinish:SetText(L["Finish"])
    SkinButton(btnFinish)
    btnFinish:SetScript("OnClick", function()
        if content._ktInstallerModulesDirty == true then self:DeferReload(20) end
        KT.db.profile.installer.showOnLogin = false
        self._ktExplicitlyClosed = true
        self._ktFinishing = true
        self.frame:Hide()
        self._ktFinishing = nil
        C_Timer.After(0, function()
            if KT and KT.OpenMenu then
                KT:OpenMenu()
            end
            self:ApplyPendingReload(true)
        end)
    end)

    local btnBack = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnBack:SetSize(120, 30)
    btnBack:SetPoint("RIGHT", btnFinish, "LEFT", -10, 0)
    btnBack:SetText(L["Previous"])
    SkinButton(btnBack)
    btnBack:SetScript("OnClick", function() self:ShowAccessStep() end)

    local btnDiscord = CreateFrame("Button", nil, content, "BackdropTemplate")
    btnDiscord:SetSize(150, 30)
    btnDiscord:SetPoint("RIGHT", btnBack, "LEFT", -10, 0)
    btnDiscord:SetText(LText("Join Discord"))
    SkinButton(btnDiscord)
    btnDiscord:SetScript("OnClick", function()
        StaticPopup_Show("KT_INSTALLER_URL", nil, nil, DISCORD_INVITE_URL)
    end)
end

function Mod:ApplyScaleOnly(resolution, opts)
    local res = tostring(resolution or "AUTO"):upper()
    local silent = type(opts) == "table" and opts.silent == true
    local scale

    if res == "AUTO" then
        local _, height = GetPhysicalScreenSize()
        if height and height >= 2160 then
            res = "4K"
        elseif height and height >= 1440 then
            res = "2K"
        else
            res = "1080P"
        end
        KT.db.profile.autoResolutionScale = true
    else
        KT.db.profile.autoResolutionScale = false
    end

    if res == "1080" or res == "1080P" then
        scale = 0.71
    elseif res == "2K" then
        scale = 0.53
    elseif res == "4K" then
        scale = 0.35
    end

    if scale then
        -- Every caller is a user action (installer button, scale preset).
        if KT.MarkUIScaleUserSet then KT:MarkUIScaleUserSet() end
        if KT.db and KT.db.profile and KT.db.profile.useBlizzardUIScale and KT.SetBlizzardUIScale then
            KT:SetBlizzardUIScale(scale)
        else
            KT.db.profile.uiScale = scale
            if KT.ApplyUIScale then KT:ApplyUIScale() end
        end
    end

    if silent then return end

    -- Reset EditMode frames to avoid conflicts with new layout
    if KT.db.profile.editMode and KT.db.profile.editMode.frames then
        table.wipe(KT.db.profile.editMode.frames)
    end

    self:DeferReload(KT.db.profile.installer.step)
end
