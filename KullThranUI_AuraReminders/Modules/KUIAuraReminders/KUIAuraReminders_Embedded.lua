-- Hosts the bundled full aura editor inside the existing Custom Auras page.
local _, ns = ...
local KT = ns.KT or (LibStub and LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true))
local E = ns.EmbeddedAuraEngine
local M = {}
ns.AuraRemindersEmbedded = M
local host, currentParent, editor, opening, queuedMessage, pendingImport
local HEIGHT = 665
if E then
    E.Core().CanShowEmbeddedOptions = function() return host and host:IsVisible() end
    E.Core().CanLoadEmbeddedAuras = function()
        local db = _G._KUIAR_AceDB
        return not (db and db.profile and db.profile.enable == false)
    end
    local api = E.API()
    if api and api.OpenOptions then
        local open = api.OpenOptions
        api.OpenOptions = function(message)
            if not host or not host:IsVisible() then
                queuedMessage = message
                local widgets = ns.AuraRemindersWidgets
                if widgets then widgets.SetSelectedPage(widgets.Pages.CUSTOM_AURAS) end
                if KT.ShowModule then KT:ShowModule("KUIAuraReminders") end
                return
            end
            return open(message)
        end
    end
    local callbacks = E.Core().callbacks
    if callbacks then
        local pending
        local function RefreshCards()
            if pending then return end
            pending = true
            C_Timer.After(0, function()
                pending = nil
                local cards = ns.AuraRemindersCards
                if cards and cards.RefreshStatus then cards.RefreshStatus() end
            end)
        end
        for _, event in ipairs({ "Add", "Delete", "ScanForLoads" }) do callbacks:RegisterCallback(event, RefreshCards) end
    end
end

local function L(text)
    return KT.Options and KT.Options.LText and KT.Options.LText(text) or text
end

local function Style()
    local options = E.Options()
    local theme = options and options.Theme
    local api = E.API()
    if not theme or not api then return end
    local r, g, b = 1, 0.6, 0.4
    if KT.GetStyleAccentRGB then r, g, b = KT:GetStyleAccentRGB() end
    theme.colors.accent = { r, g, b, 0.8 }
    theme.colors.border = { r * 0.45, g * 0.45, b * 0.45, 0.9 }
    theme.colors.window = { 0.06, 0.055, 0.05, 0.97 }
    theme.colors.titleBar = { 0.1, 0.075, 0.06, 1 }
    theme.colors.selected = { r, g, b, 0.15 }
    theme.IsModern = function() return true end
    theme.GetFontPath = function()
        return KT.ResolveFontPath and KT:ResolveFontPath() or "Fonts\\FRIZQT__.TTF"
    end
    api.displayName = L("Custom Auras")
end

local function Layout()
    if not editor or not host then return end
    local width = math.max(1, host:GetWidth())
    editor:SetScale(1)
    editor:ClearAllPoints()
    editor:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    editor:SetSize(width, host:GetHeight())
    editor:SetFrameStrata(host:GetFrameStrata())
    editor:SetFrameLevel(host:GetFrameLevel() + 2)
    editor:SetMovable(false)
    editor:SetResizable(false)
    editor:SetClampedToScreen(false)
    if editor.TitleContainer then
        editor.TitleContainer:SetScript("OnMouseDown", nil)
        editor.TitleContainer:SetScript("OnMouseUp", nil)
    end
    if editor.bottomRightResizer then editor.bottomRightResizer:Hide() end
    if editor.kuiMinimizeButton then editor.kuiMinimizeButton:Hide() end
    -- Window layout is owned by KUI. Font and all aura editing controls remain available.
    if editor.layoutButton then editor.layoutButton:Hide() end
    if editor.fontButton then editor.fontButton:Hide() end
    if editor.faTitleLogo then
        editor.faTitleLogo:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUILogoCuadrado.PNG")
    end
    local portrait = _G.KUIAR_EngineOptionsPortrait
    if portrait then portrait:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUILogoCuadrado.PNG") end
    -- The window theme is part of the Forever engine only.
    local theme = E.Options().Theme
    if theme and theme.ApplyFont then theme.ApplyFont(editor) end
    if ns.AuraRemindersEmbeddedUI then ns.AuraRemindersEmbeddedUI.Attach(editor) end
end

local function Status(text)
    if host and host.status then host.status:SetText(L(text)) end
end

function M.Close()
    local api = E and E.API()
    if api and api.HideOptions then api.HideOptions() end
    if host and host.openButton then host.openButton:Show() end
end

function M.Open()
    if opening or not host or not host:IsVisible() then return false end
    if InCombatLockdown and InCombatLockdown() then
        Status("The aura editor is available out of combat.")
        return false
    end
    local api = E and E.API()
    if not api or not api.IsLibsOK() then Status("The aura engine could not be initialized."); return false end
    if not api.IsLoginFinished() then Status("The aura engine is still initializing. Press Open Editor to retry."); return false end
    opening = true
    local ok, reason
    local success, message = pcall(function()
      ok, reason = E.Load("KUIAR_EngineOptions")
      if ok then
        Style()
        if not api.IsOptionsOpen() then api.OpenOptions(queuedMessage); queuedMessage = nil end
        editor = _G.KUIAR_EngineOptions
        if editor then
            -- Hide before reparenting: the upstream close handler resumes real displays.
            -- ShowOptions below re-enters preview mode for this host.
            if editor:GetParent() ~= host then
                api.HideOptions()
                editor:SetParent(host)
                api.ShowOptions()
            end
            if not editor.kuiLayoutHooked and hooksecurefunc then
                editor.kuiLayoutHooked = true
                hooksecurefunc(editor, "UpdateFrameVisible", function()
                    if editor.bottomRightResizer then editor.bottomRightResizer:Hide() end
                    if editor.kuiMinimizeButton then editor.kuiMinimizeButton:Hide() end
                end)
            end
            Layout()
            host.status:SetText("")
            if host.openButton then host.openButton:Hide() end
            if pendingImport then
                local text = pendingImport
                pendingImport = nil
                api.Import(text)
            end
        else
            Status("The aura editor could not be opened.")
            ok = false
        end
      else
        Status("The aura editor could not be loaded. Reload the UI and try again.")
      end
    end)
    opening = nil
    if not success then
        Status("The aura editor could not be opened.")
        M.Close()
        if geterrorhandler then geterrorhandler()(message) end
        return false
    end
    return ok, reason
end

-- True for a string of the aura engine itself (!WA:N! or !FA:N!), which the KUI aura codec does not read.
function M.IsEngineString(text)
    return E ~= nil and type(text) == "string" and text:match("^%s*![FW]A:%d+!") ~= nil
end

-- Hands an engine string to the editor's own import window; it opens once the editor is shown.
function M.Import(text)
    pendingImport = text:match("^%s*(.-)%s*$")
    if host and host:IsVisible() then M.Open() end
end

function M.BuildPage(parent, y)
    if not host then
        host = CreateFrame("Frame", nil, parent)
        host.status = host:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        host.status:SetPoint("TOPLEFT", 8, -48)
        host.status:SetPoint("TOPRIGHT", -8, -48)
        host.status:SetJustifyH("LEFT")
        host:SetScript("OnShow", function()
            C_Timer.After(0, function() M.Open() end)
        end)
        host:SetScript("OnHide", M.Close)
        host:SetScript("OnSizeChanged", Layout)
        local button = CreateFrame("Button", nil, host)
        button:SetSize(170, 30)
        button:SetPoint("TOPLEFT", 8, -8)
        if KT.NavTabs then
            KT.NavTabs.StyleButton(button, { label = L("Open Editor"), fontSize = 12, variant = "short" })
        else
            KT:AddBackdrop(button, 0.08, 0.10, 0.13, 0.95)
            KT:AddBorder(button, 0.25, 0.25, 0.25, 1)
            local text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("CENTER")
            text:SetText(L("Open Editor"))
        end
        button:SetScript("OnClick", M.Open)
        host.openButton = button
        local events = CreateFrame("Frame")
        events:RegisterEvent("PLAYER_REGEN_ENABLED")
        events:SetScript("OnEvent", function()
            if host:IsVisible() then C_Timer.After(0, function() M.Open() end) end
        end)
    end
    if currentParent ~= parent then
        M.Close()
        host:SetParent(parent)
        currentParent = parent
    end
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -y)
    host:SetWidth(math.max(1, parent:GetWidth()))
    local widgets = ns.AuraRemindersWidgets
    local available = widgets and widgets.GetAvailableContentHeight and widgets.GetAvailableContentHeight()
    local height = math.max(1, (available or (HEIGHT + y)) - y)
    host:SetHeight(height)
    host:SetFrameLevel(parent:GetFrameLevel() + 1)
    host:Show()
    C_Timer.After(0, function() M.Open() end)
    return height
end
