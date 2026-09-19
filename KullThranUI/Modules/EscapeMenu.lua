local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local M = KT:GetModule("EscapeMenu", true) or KT:NewModule("EscapeMenu", "AceEvent-3.0", "AceTimer-3.0")

local _G = _G
local C_Timer = _G.C_Timer
local CreateFrame = _G.CreateFrame
local GetTimePreciseSec = _G.GetTimePreciseSec or _G.GetTime
local HideUIPanel = _G.HideUIPanel
local InCombatLockdown = _G.InCombatLockdown
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local UnitClass = _G.UnitClass
local hooksecurefunc = _G.hooksecurefunc
local GameFontDisable = _G.GameFontDisable
local GameFontHighlight = _G.GameFontHighlight
local GameFontNormal = _G.GameFontNormal

local ipairs = ipairs
local pairs = pairs
local abs = math.abs
local max = math.max
local floor = math.floor
local remove = table.remove
local sort = table.sort
local tonumber = tonumber
local format = string.format
local strlower = string.lower

local WHITE8X8 = "Interface\\Buttons\\WHITE8x8"

local function IsSecureGameMenuSafeMode()
    local _, _, _, interfaceVersion = _G.GetBuildInfo and _G.GetBuildInfo()
    interfaceVersion = tonumber(interfaceVersion) or 0
    return interfaceVersion >= 120000
end

local function CurrentFontPath()
    if KT and KT.ResolveFontPath then
        return KT:ResolveFontPath()
    end

    return KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
end

local PANEL_INSET = 14
local TOP_OFFSET_WITH_HEADER = 40
local TOP_OFFSET_NO_HEADER = 18
local BUTTON_GAP = 4
local BOTTOM_PAD = 16
local FALLBACK_BUTTON_WIDTH = 180
local FALLBACK_BUTTON_HEIGHT = 20
local MENU_SETTLE_DELAY = 0.05
local MENU_REVEAL_DELAY = 0.03
local MENU_HEALTH_DELAY_SHORT = 0.02
local MENU_HEALTH_DELAY_MEDIUM = 0.08
local MENU_HEALTH_DELAY_LONG = 0.18
local MENU_HEALTH_TOLERANCE = 4

local CUSTOM_MENU_TEXT_KEYS = {
    ["kullthranui"] = "config",
    ["kui unlock mode"] = "unlock",
}

local CUSTOM_MENU_NAME_KEYS = {
    GameMenuButtonKullThranUI = "config",
    GameMenuButtonKUIUnlockMode = "unlock",
}

local function IsEscapeMenuDebugEnabled()
    return _G.KT_ESCAPE_MENU_DEBUG == true
end

local function DebugMetric(value)
    if type(value) ~= "number" then
        return "nil"
    end

    return format("%.3f", value)
end

local function DebugFlag(value)
    return value and "1" or "0"
end

local function DebugEscapeMenu(message, ...)
    if not IsEscapeMenuDebugEnabled() then
        return
    end

    local text = message
    if select("#", ...) > 0 then
        local ok, formatted = pcall(format, message, ...)
        if ok and type(formatted) == "string" then
            text = formatted
        end
    end

    if KT and KT.Print then
        KT:Print("|cff00c8ff[EscapeDbg]|r " .. text)
    else
        print("[EscapeDbg] " .. text)
    end
end

function M:IsDebugTraceActive()
    if not IsEscapeMenuDebugEnabled() then
        return false
    end

    local now = GetTimePreciseSec and GetTimePreciseSec() or 0
    return self._debugTraceUntil ~= nil and now <= self._debugTraceUntil
end

function M:LogGameMenuState(label, menu)
    if not IsEscapeMenuDebugEnabled() then
        return
    end

    menu = menu or _G.GameMenuFrame
    if not menu then
        DebugEscapeMenu("%s menu=nil", label)
        return
    end

    local width = menu.GetWidth and menu:GetWidth() or nil
    local height = menu.GetHeight and menu:GetHeight() or nil
    local left = menu.GetLeft and menu:GetLeft() or nil
    local top = menu.GetTop and menu:GetTop() or nil
    local alpha = menu.GetAlpha and menu:GetAlpha() or nil
    local scale = menu.GetScale and menu:GetScale() or nil
    local effectiveScale = menu.GetEffectiveScale and menu:GetEffectiveScale() or nil
    local uiScale = _G.UIParent and _G.UIParent.GetScale and _G.UIParent:GetScale() or nil
    local uiEffectiveScale = _G.UIParent and _G.UIParent.GetEffectiveScale and _G.UIParent:GetEffectiveScale() or nil

    DebugEscapeMenu(
        "%s shown=%s alpha=%s scale=%s eff=%s width=%s height=%s left=%s top=%s uiScale=%s uiEff=%s refresh=%s pending=%s detached=%s",
        label,
        DebugFlag(menu.IsShown and menu:IsShown()),
        DebugMetric(alpha),
        DebugMetric(scale),
        DebugMetric(effectiveScale),
        DebugMetric(width),
        DebugMetric(height),
        DebugMetric(left),
        DebugMetric(top),
        DebugMetric(uiScale),
        DebugMetric(uiEffectiveScale),
        DebugFlag(self._refreshing),
        DebugFlag(self._refreshPending),
        DebugFlag(self._kuiMoveGameMenuDetached)
    )
end

function M:ScheduleDebugSnapshot(label, delay, menu, token)
    if not IsEscapeMenuDebugEnabled() then
        return
    end

    C_Timer.After(delay, function()
        if not (M and M.LogGameMenuState) then
            return
        end
        if token ~= nil and M._debugTraceToken ~= token then
            return
        end

        M:LogGameMenuState(label, menu)
    end)
end

function M:StartDebugTrace(label, menu)
    if not IsEscapeMenuDebugEnabled() then
        return nil
    end

    local now = GetTimePreciseSec and GetTimePreciseSec() or 0
    self._debugTraceToken = (self._debugTraceToken or 0) + 1
    self._debugTraceUntil = now + 0.25
    self:LogGameMenuState(label, menu)
    return self._debugTraceToken
end

function M:BeginMenuSettle(menu)
    if not menu then
        return
    end

    self._hideUntilLayout = true
    self._holdMenuHidden = true
    self._showSettleToken = (self._showSettleToken or 0) + 1

    if menu.SetAlpha and menu:GetAlpha() ~= 0 then
        menu:SetAlpha(0)
    end

    if self.IsDebugTraceActive and self:IsDebugTraceActive() then
        self:LogGameMenuState("Settle:begin", menu)
    end
end

function M:ArmMenuSettleReveal(menu, reason)
    if not (menu and self._holdMenuHidden) then
        return
    end

    self._showSettleToken = (self._showSettleToken or 0) + 1
    local token = self._showSettleToken

    if self.IsDebugTraceActive and self:IsDebugTraceActive() then
        self:LogGameMenuState(reason or "Settle:arm", menu)
    end

    C_Timer.After(MENU_SETTLE_DELAY, function()
        if not (M and M.RefreshLayout and menu and menu:IsShown()) then
            return
        end
        if M._showSettleToken ~= token then
            return
        end

        M._hideUntilLayout = true
        M:RefreshLayout()
        if M.IsDebugTraceActive and M:IsDebugTraceActive() then
            M:LogGameMenuState("Settle:postRefresh", menu)
        end

        C_Timer.After(MENU_REVEAL_DELAY, function()
            if not (M and menu and menu:IsShown()) then
                return
            end
            if M._showSettleToken ~= token then
                return
            end
            if M._refreshPending or M._refreshing then
                return
            end

            M._holdMenuHidden = nil
            M._hideUntilLayout = nil
            if menu.SetAlpha then
                menu:SetAlpha(1)
            end
            if M.IsDebugTraceActive and M:IsDebugTraceActive() then
                M:LogGameMenuState("Settle:reveal", menu)
            end
        end)
    end)
end

local function CloseGameMenu()
    local menu = _G.GameMenuFrame
    if not menu then return end

    if HideUIPanel then
        pcall(HideUIPanel, menu)
    elseif menu.Hide then
        pcall(menu.Hide, menu)
    end
end

local function ToggleUnlockMode()
    local unlockMode = KT and KT.GetModule and KT:GetModule("UnlockMode", true)
    if unlockMode and unlockMode.ToggleUnlockMode then
        unlockMode:ToggleUnlockMode()
        return true
    end

    if KT and KT.Print then
        KT:Print("|cffFF4444UnlockMode|r: module not available.")
    end
    return false
end

local function OpenConfigMenu()
    if not KT then return end

    CloseGameMenu()

    if KT.OpenMenu then
        KT:OpenMenu()
        return
    end

    if KT.ToggleConfig then
        KT:ToggleConfig()
    end
end

local function GetSkinConfig()
    return KT and KT.db and KT.db.profile and KT.db.profile.skin
end

local function IsGameMenuSkinEnabled()
    local skin = GetSkinConfig()
    if not skin then
        return true
    end

    if skin.enable == false then
        return false
    end

    if skin.blizzard and skin.blizzard.gamemenu == false then
        return false
    end

    return true
end

local function ShouldUseNativeGameMenuPresentation()
    -- Keep KullThranUI's custom ESC menu presentation enabled by default.
    -- The surrounding layout code now guards the problematic retail cases
    -- instead of hard-disabling the feature and leaving the menu half-skinned.
    return false
end

local HideExternalEscapeVisuals
local HideKUIFrameArt

local function HideCustomGameMenuButtons()
    if not (M and M.buttons) then
        return
    end

    for _, button in pairs(M.buttons) do
        if button then
            HideKUIFrameArt(button)
            if button.Hide then
                button:Hide()
            end
        end
    end
end

local function ApplyNativeGameMenuMode(menu)
    menu = menu or _G.GameMenuFrame
    if not menu then
        return
    end

    HideExternalEscapeVisuals()
    HideCustomGameMenuButtons()
    HideKUIFrameArt(menu)

    if menu.SetAlpha then
        menu:SetAlpha(1)
    end
end

local function RunEscapeMenuStep(stepName, callback)
    if type(callback) ~= "function" then
        return true
    end

    local ok, err = pcall(callback)
    if not ok and M then
        M._lastMenuStepError = (stepName or "unknown") .. ": " .. tostring(err)
        DebugEscapeMenu("step %s failed: %s", tostring(stepName or "unknown"), tostring(err))
    end

    return ok
end

local function DisableKUIMoveGameMenuHandling()
    if not M or M._kuiMoveGameMenuDetached then
        return
    end

    local api = KT and KT.KUIMoveAPI
    if not (api and api.UnregisterFrame) then
        return
    end

    local ok = pcall(function()
        api:UnregisterFrame(nil, "GameMenuFrame")
    end)

    if ok then
        M._kuiMoveGameMenuDetached = true
        if InCombatLockdown and InCombatLockdown() then
            return
        end
        local menu = _G.GameMenuFrame
        if menu then
            local currentScale = menu.GetScale and menu:GetScale() or nil
            if not currentScale or abs(currentScale - 1) > 0.001 then
                menu:SetScale(1)
            end
        end
    end
end

local function NormalizeGameMenuScale(menu)
    if not (menu and menu.SetScale) then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    local currentScale = menu.GetScale and menu:GetScale() or nil
    if not currentScale or abs(currentScale - 1) > 0.001 then
        menu:SetScale(1)
    end
end

local function CaptureMenuDefaultPoints(menu)
    if not (M and menu and menu.GetNumPoints and menu.GetPoint) then
        return
    end

    if M._defaultMenuPoints then
        return
    end

    local points = {}
    for index = 1, (menu:GetNumPoints() or 0) do
        local point, relativeTo, relativePoint, x, y = menu:GetPoint(index)
        points[#points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = x,
            y = y,
        }
    end

    if #points > 0 then
        M._defaultMenuPoints = points
    end
end

local function RestoreMenuDefaultPoints(menu)
    if not (M and menu and M._defaultMenuPoints and menu.ClearAllPoints and menu.SetPoint) then
        return
    end

    menu:ClearAllPoints()
    for _, info in ipairs(M._defaultMenuPoints) do
        menu:SetPoint(
            info.point or "CENTER",
            info.relativeTo,
            info.relativePoint or info.point or "CENTER",
            info.x or 0,
            info.y or 0
        )
    end
end

local function EnsureGameMenuDraggable(menu)
    if not menu or menu._ktEscapeMenuDraggable then
        return
    end

    menu:SetClampedToScreen(true)
    CaptureMenuDefaultPoints(menu)
    if menu.SetMovable then
        menu:SetMovable(true)
    end
    if menu.EnableMouse then
        menu:EnableMouse(true)
    end
    if menu.RegisterForDrag then
        menu:RegisterForDrag("LeftButton")
    end

    local function StartDrag(self)
        if InCombatLockdown and InCombatLockdown() then
            return
        end
        if self.StartMoving then
            self:StartMoving()
        end
    end

    local function StopDrag(self)
        if self.StopMovingOrSizing then
            self:StopMovingOrSizing()
        end
        if self.SetUserPlaced then
            self:SetUserPlaced(false)
        end
    end

    menu:SetScript("OnDragStart", StartDrag)
    menu:SetScript("OnDragStop", StopDrag)

    if menu.Header then
        if menu.Header.EnableMouse then
            menu.Header:EnableMouse(true)
        end
        if menu.Header.RegisterForDrag then
            menu.Header:RegisterForDrag("LeftButton")
        end
        menu.Header:SetScript("OnDragStart", function()
            StartDrag(menu)
        end)
        menu.Header:SetScript("OnDragStop", function()
            StopDrag(menu)
        end)
    end

    menu._ktEscapeMenuDraggable = true
end

local function ReadColor(color, fallbackR, fallbackG, fallbackB, fallbackA)
    if type(color) ~= "table" then
        return fallbackR, fallbackG, fallbackB, fallbackA
    end

    return color.r or color[1] or fallbackR,
        color.g or color[2] or fallbackG,
        color.b or color[3] or fallbackB,
        color.a or color[4] or fallbackA
end

local function GetAccentColor()
    -- Use the canonical accent color API for consistency
    local r, g, b = KT:GetStyleAccentRGB()
    return r, g, b, 1
end

local function GetBorderColor()
    -- Game Menu should follow the theme accent directly, not a separate border palette.
    return GetAccentColor()
end

local function GetBackgroundColor()
    local skin = GetSkinConfig()
    if skin and skin.backgroundColor then
        return ReadColor(skin.backgroundColor, 0, 0, 0, 0.96)
    end

    return 0, 0, 0, 0.96
end

local function SetBackdropColor(frame, r, g, b, a)
    if not frame then return end

    if frame.SetBackdropColor then
        pcall(frame.SetBackdropColor, frame, r, g, b, a)
    end

    if frame._ktBackdropTexture and frame._ktBackdropTexture.SetColorTexture then
        frame._ktBackdropTexture:SetColorTexture(r, g, b, a)
        frame._ktBackdropTexture:Show()
    end
end

local function EnsureEscapeSkin(frame)
    if not frame then
        return nil
    end

    local skin = frame._ktEscapeMenuSkin
    if skin then
        return skin
    end

    skin = {}

    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetTexture(WHITE8X8)
    bg:SetAllPoints()
    bg._ktEscapeOwned = true
    skin.bg = bg

    skin.edges = {}
    for i = 1, 4 do
        local edge = frame:CreateTexture(nil, "OVERLAY", nil, 6)
        edge:SetTexture(WHITE8X8)
        edge._ktEscapeOwned = true
        skin.edges[i] = edge
    end

    frame._ktEscapeMenuSkin = skin
    return skin
end

local function ApplyEscapeSkin(frame, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA, borderSize)
    if not frame then
        return
    end

    local skin = EnsureEscapeSkin(frame)
    if not skin then
        return
    end

    borderSize = max(1, floor(tonumber(borderSize) or 1))

    skin.bg:ClearAllPoints()
    skin.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    skin.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    skin.bg:SetColorTexture(bgR or 0, bgG or 0, bgB or 0, bgA or 1)
    skin.bg:Show()

    local edges = skin.edges

    edges[1]:ClearAllPoints()
    edges[1]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    edges[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    edges[1]:SetHeight(borderSize)

    edges[2]:ClearAllPoints()
    edges[2]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    edges[2]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    edges[2]:SetHeight(borderSize)

    edges[3]:ClearAllPoints()
    edges[3]:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    edges[3]:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    edges[3]:SetWidth(borderSize)

    edges[4]:ClearAllPoints()
    edges[4]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    edges[4]:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    edges[4]:SetWidth(borderSize)

    for _, edge in ipairs(edges) do
        edge:SetColorTexture(borderR or 0, borderG or 0, borderB or 0, borderA or 1)
        edge:Show()
    end
end

local function EnsureEscapeVisualHost(frame)
    if not frame then
        return nil
    end

    local host = frame._ktEscapeVisualHost
    if host then
        frame._ktVisualHost = host
        return host
    end

    host = CreateFrame("Frame", nil, frame)
    host:SetMouseClickEnabled(false)
    host:SetMouseMotionEnabled(false)
    host:SetAllPoints()
    host._ktEscapeOwnedFrame = true
    frame._ktEscapeVisualHost = host
    frame._ktVisualHost = host
    return host
end

local function EnsureExternalMenuOverlay(menu)
    if not M then
        return nil
    end

    if M._externalMenuOverlay then
        return M._externalMenuOverlay
    end

    local overlay = CreateFrame("Frame", nil, _G.UIParent)
    overlay:EnableMouse(false)
    overlay._ktEscapeOwnedFrame = true

    local bg = overlay:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetTexture(WHITE8X8)

    local edges = {}
    for i = 1, 4 do
        local edge = overlay:CreateTexture(nil, "OVERLAY", nil, 6)
        edge:SetTexture(WHITE8X8)
        edges[i] = edge
    end

    overlay._ktOverlayBg = bg
    overlay._ktOverlayEdges = edges
    M._externalMenuOverlay = overlay
    return overlay
end

local function LayoutOverlayTextures(backdrop, edgeSize)
    if not backdrop then return end
    edgeSize = max(1, floor(tonumber(edgeSize) or 1))

    local bg = backdrop._ktOverlayBg
    if bg then
        bg:ClearAllPoints()
        bg:SetAllPoints()
    end

    local edges = backdrop._ktOverlayEdges
    if edges then
        edges[1]:ClearAllPoints()
        edges[1]:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
        edges[1]:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
        edges[1]:SetHeight(edgeSize)

        edges[2]:ClearAllPoints()
        edges[2]:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
        edges[2]:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
        edges[2]:SetHeight(edgeSize)

        edges[3]:ClearAllPoints()
        edges[3]:SetPoint("TOPLEFT", backdrop, "TOPLEFT", 0, 0)
        edges[3]:SetPoint("BOTTOMLEFT", backdrop, "BOTTOMLEFT", 0, 0)
        edges[3]:SetWidth(edgeSize)

        edges[4]:ClearAllPoints()
        edges[4]:SetPoint("TOPRIGHT", backdrop, "TOPRIGHT", 0, 0)
        edges[4]:SetPoint("BOTTOMRIGHT", backdrop, "BOTTOMRIGHT", 0, 0)
        edges[4]:SetWidth(edgeSize)
    end
end

local function RecolorOverlayTextures(backdrop, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)
    if not backdrop then return end

    local bg = backdrop._ktOverlayBg
    if bg then
        bg:SetColorTexture(bgR or 0, bgG or 0, bgB or 0, bgA or 1)
        bg:Show()
    end

    local edges = backdrop._ktOverlayEdges
    if edges then
        for _, edge in ipairs(edges) do
            edge:SetColorTexture(borderR or 0, borderG or 0, borderB or 0, borderA or 1)
            edge:Show()
        end
    end
end

local function EnsureExternalButtonBackdrop(button)
    if not (M and button) then
        return nil
    end

    M._externalButtonBackdrops = M._externalButtonBackdrops or {}

    local backdrop = M._externalButtonBackdrops[button]
    if backdrop then
        return backdrop
    end

    backdrop = CreateFrame("Frame", nil, _G.UIParent)
    backdrop:EnableMouse(false)
    backdrop._ktEscapeOwnedFrame = true

    local bg = backdrop:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetTexture(WHITE8X8)

    local edges = {}
    for i = 1, 4 do
        local edge = backdrop:CreateTexture(nil, "OVERLAY", nil, 6)
        edge:SetTexture(WHITE8X8)
        edges[i] = edge
    end

    backdrop._ktOverlayBg = bg
    backdrop._ktOverlayEdges = edges
    M._externalButtonBackdrops[button] = backdrop
    return backdrop
end

HideExternalEscapeVisuals = function()
    if M and M._externalMenuOverlay then
        M._externalMenuOverlay:Hide()
    end

    if M and M._externalButtonBackdrops then
        for _, backdrop in pairs(M._externalButtonBackdrops) do
            if backdrop then
                backdrop:Hide()
            end
        end
    end
end

local function RecolorExistingKUIBorder(frame, r, g, b, a)
    if not frame then
        return
    end

    if frame._ktBorderFrame and frame._ktBorderFrame.SetColor then
        frame._ktBorderFrame:SetColor(r or 0, g or 0, b or 0, a or 1)
        frame._ktBorderFrame:Show()
    end

    if frame._ktBorders then
        for _, edge in pairs(frame._ktBorders) do
            if edge and edge.SetColorTexture then
                edge:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
                edge:Show()
            end
        end
    end

    if frame._ppBorderFrame and frame._ppBorderFrame.SetColor then
        frame._ppBorderFrame:SetColor(r or 0, g or 0, b or 0, a or 1)
        frame._ppBorderFrame:Show()
    end

    if frame._ppBorders then
        for _, edge in pairs(frame._ppBorders) do
            if edge and edge.SetColorTexture then
                edge:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
                edge:Show()
            end
        end
    end

    local nested = { frame.backdrop, frame.Border }
    for _, child in ipairs(nested) do
        if child then
            if child._ktBorderFrame and child._ktBorderFrame.SetColor then
                child._ktBorderFrame:SetColor(r or 0, g or 0, b or 0, a or 1)
                child._ktBorderFrame:Show()
            end

            if child._ktBorders then
                for _, edge in pairs(child._ktBorders) do
                    if edge and edge.SetColorTexture then
                        edge:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
                        edge:Show()
                    end
                end
            end

            if child._ppBorderFrame and child._ppBorderFrame.SetColor then
                child._ppBorderFrame:SetColor(r or 0, g or 0, b or 0, a or 1)
                child._ppBorderFrame:Show()
            end

            if child._ppBorders then
                for _, edge in pairs(child._ppBorders) do
                    if edge and edge.SetColorTexture then
                        edge:SetColorTexture(r or 0, g or 0, b or 0, a or 1)
                        edge:Show()
                    end
                end
            end
        end
    end
end

HideKUIFrameArt = function(frame)
    if not frame then
        return
    end

    if frame._ktBackdropTexture then
        frame._ktBackdropTexture:Hide()
    end

    if frame._ktBorderFrame then
        frame._ktBorderFrame:Hide()
    end

    if frame._ktBorders then
        for _, edge in pairs(frame._ktBorders) do
            if edge and edge.Hide then
                edge:Hide()
            end
        end
    end

    if frame._ppBorderFrame then
        frame._ppBorderFrame:Hide()
    end

    if frame._ppBorders then
        for _, edge in pairs(frame._ppBorders) do
            if edge and edge.Hide then
                edge:Hide()
            end
        end
    end

    if frame._ktEscapeMenuSkin then
        if frame._ktEscapeMenuSkin.bg then
            frame._ktEscapeMenuSkin.bg:Hide()
        end
        for _, edge in ipairs(frame._ktEscapeMenuSkin.edges or {}) do
            edge:Hide()
        end
    end

    if frame._ktEscapeVisualHost then
        frame._ktEscapeVisualHost:Hide()
    end

    if frame._ktVisualHost and frame._ktVisualHost ~= frame._ktEscapeVisualHost then
        frame._ktVisualHost:Hide()
    end
end

function M:RequestForeignOverlaySuppression(menu)
    -- Never enumerate and measure anonymous UIParent children here. Foreign
    -- addons can anchor those frames to restricted Blizzard regions (notably
    -- nameplates), and even a protected GetPoint() call then raises a
    -- FrameMeasurement taint error. KUI-owned menu art is tracked explicitly
    -- in M._externalMenuOverlay / M._externalButtonBackdrops and is styled or
    -- hidden through those references, so no global overlay sweep is needed.
end

local function GetVisibleButtonMetrics(button)
    if not button then
        return 0, 0
    end

    local buttonLeft = button.GetLeft and button:GetLeft() or nil
    local buttonRight = button.GetRight and button:GetRight() or nil
    local buttonTop = button.GetTop and button:GetTop() or nil
    local buttonBottom = button.GetBottom and button:GetBottom() or nil

    local visualLeft, visualRight = nil, nil
    local visualTop, visualBottom = nil, nil

    local function Consider(region)
        if not (region and region.IsShown and region:IsShown()) then
            return
        end

        local left = region.GetLeft and region:GetLeft() or nil
        local right = region.GetRight and region:GetRight() or nil
        local top = region.GetTop and region:GetTop() or nil
        local bottom = region.GetBottom and region:GetBottom() or nil

        if left and (not visualLeft or left < visualLeft) then
            visualLeft = left
        end
        if right and (not visualRight or right > visualRight) then
            visualRight = right
        end
        if top and (not visualTop or top > visualTop) then
            visualTop = top
        end
        if bottom and (not visualBottom or bottom < visualBottom) then
            visualBottom = bottom
        end
    end

    Consider(button.Left)
    Consider(button.Middle)
    Consider(button.Right)
    Consider(button.GetNormalTexture and button:GetNormalTexture() or nil)

    local width = 0
    local height = 0

    if buttonLeft and buttonRight and visualLeft and visualRight then
        width = max(0, floor((visualRight - visualLeft) + 0.5))
    end
    if buttonTop and buttonBottom and visualTop and visualBottom then
        height = max(0, floor((visualTop - visualBottom) + 0.5))
    end

    return width, height
end

local function LockHiddenRegion(region)
    if not region then return end

    region:SetAlpha(0)
    if region.Hide then
        region:Hide()
    end

    if region.Show and not region._ktEscapeMenuHidden then
        hooksecurefunc(region, "Show", function(self)
            self:SetAlpha(0)
            self:Hide()
        end)
        region._ktEscapeMenuHidden = true
    end
end

local function IsRegionWithinMenuBounds(region, menu, tolerance)
    if not (region and menu) then
        return false
    end

    tolerance = tonumber(tolerance) or MENU_HEALTH_TOLERANCE

    local menuLeft = menu.GetLeft and menu:GetLeft() or nil
    local menuRight = menu.GetRight and menu:GetRight() or nil
    local menuTop = menu.GetTop and menu:GetTop() or nil
    local menuBottom = menu.GetBottom and menu:GetBottom() or nil
    local regionLeft = region.GetLeft and region:GetLeft() or nil
    local regionRight = region.GetRight and region:GetRight() or nil
    local regionTop = region.GetTop and region:GetTop() or nil
    local regionBottom = region.GetBottom and region:GetBottom() or nil

    if not (menuLeft and menuRight and menuTop and menuBottom and regionLeft and regionRight and regionTop and regionBottom) then
        return false
    end

    return regionLeft >= (menuLeft - tolerance)
        and regionRight <= (menuRight + tolerance)
        and regionTop <= (menuTop + tolerance)
        and regionBottom >= (menuBottom - tolerance)
end

local function GetAllMenuChildren(menu)
    local out = {}
    local seen = {}

    local function AddChild(child)
        if not child or seen[child] then
            return
        end
        seen[child] = true
        out[#out + 1] = child
    end

    local function AddDescendants(frame, depth)
        if not frame or depth <= 0 or not frame.GetChildren then
            return
        end

        for _, child in ipairs({ frame:GetChildren() }) do
            AddChild(child)
            AddDescendants(child, depth - 1)
        end
    end

    if menu.GetLayoutChildren then
        for _, child in ipairs(menu:GetLayoutChildren()) do
            AddChild(child)
            AddDescendants(child, 3)
        end
    end

    for _, child in ipairs({ menu:GetChildren() }) do
        AddChild(child)
        AddDescendants(child, 3)
    end

    return out
end

local function IsMenuDescendant(frame, menu)
    if not (frame and menu and frame.GetParent) then
        return false
    end

    local current = frame
    while current do
        if current == menu then
            return true
        end
        current = current.GetParent and current:GetParent() or nil
    end

    return false
end

local function IsTextButton(button)
    if not (button and button.IsObjectType and button:IsObjectType("Button")) then
        return false
    end

    if not button.GetText then
        return false
    end

    local text = button:GetText()
    return type(text) == "string" and text ~= ""
end

local function NormalizeButtonText(text)
    if type(text) ~= "string" then
        return nil
    end

    local normalized = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s+", ""):gsub("%s+$", "")
    if normalized == "" then
        return nil
    end

    return strlower(normalized)
end

local function GetCustomButtonSemanticKey(button)
    if not button then
        return nil
    end

    local name = button.GetName and button:GetName()
    if name and CUSTOM_MENU_NAME_KEYS[name] then
        return CUSTOM_MENU_NAME_KEYS[name]
    end

    local text = button.GetText and button:GetText()
    local normalized = NormalizeButtonText(text)
    if normalized then
        return CUSTOM_MENU_TEXT_KEYS[normalized]
    end

    return nil
end

local function IsPrimaryGameMenuButton(button, menu)
    if not (button and menu) then
        return false
    end

    if button._ktEscapeMenuCustom then
        return true
    end

    if not IsTextButton(button) then
        return false
    end

    if not IsMenuDescendant(button, menu) then
        return false
    end

    local name = button.GetName and button:GetName() or nil
    if type(name) == "string" and name:match("^GameMenuButton") then
        return true
    end

    if tonumber(button.layoutIndex or button._ktMenuOrder) then
        return true
    end

    return false
end

local function RemoveCollectedButton(buttons, target)
    for i = #buttons, 1, -1 do
        if buttons[i] == target then
            remove(buttons, i)
            return
        end
    end
end

function M:CollectVisibleButtons(includeCustom)
    local menu = _G.GameMenuFrame
    if not menu then
        return {}
    end

    local out = {}
    local seenCustom = {}
    for _, child in ipairs(GetAllMenuChildren(menu)) do
        if child and child:IsShown() and IsPrimaryGameMenuButton(child, menu) then
            if includeCustom or not child._ktEscapeMenuCustom then
                local semanticKey = GetCustomButtonSemanticKey(child)
                if semanticKey then
                    local canonical = self.buttons and self.buttons[semanticKey]
                    local existing = seenCustom[semanticKey]

                    if canonical and child ~= canonical then
                        child:Hide()
                    elseif existing and existing ~= child then
                        if canonical and child == canonical then
                            existing:Hide()
                            RemoveCollectedButton(out, existing)
                            seenCustom[semanticKey] = child
                            out[#out + 1] = child
                        else
                            child:Hide()
                        end
                    else
                        seenCustom[semanticKey] = child
                        out[#out + 1] = child
                    end
                else
                    out[#out + 1] = child
                end
            end
        end
    end

    sort(out, function(a, b)
        local aIndex = tonumber(a.layoutIndex or a._ktMenuOrder) or math.huge
        local bIndex = tonumber(b.layoutIndex or b._ktMenuOrder) or math.huge
        if aIndex ~= bIndex then
            return aIndex < bIndex
        end

        local aName = a:GetName() or a:GetText() or ""
        local bName = b:GetName() or b:GetText() or ""
        return aName < bName
    end)

    return out
end

function M:RefreshVisibleButtonSkins(includeCustom)
    local buttons = self:CollectVisibleButtons(includeCustom ~= false)
    for _, button in ipairs(buttons) do
        if button then
            self:StyleButton(button)
        end
    end
end

function M:GetReferenceButtonSize(buttons)
    local width = 0
    local height = 0
    local visualWidth = 0
    local visualHeight = 0

    for _, button in ipairs(buttons) do
        width = max(width, button:GetWidth() or 0)
        height = max(height, button:GetHeight() or 0)

        if not button._ktEscapeMenuCustom then
            local buttonVisualWidth, buttonVisualHeight = GetVisibleButtonMetrics(button)
            visualWidth = max(visualWidth, buttonVisualWidth or 0)
            visualHeight = max(visualHeight, buttonVisualHeight or 0)
        end
    end

    if width <= 0 then
        width = FALLBACK_BUTTON_WIDTH
    end

    if height <= 0 then
        height = FALLBACK_BUTTON_HEIGHT
    end

    self._referenceButtonWidth = width
    self._referenceButtonHeight = height
    self._referenceVisualButtonWidth = visualWidth > 0 and visualWidth or max(120, width - 36)
    self._referenceVisualButtonHeight = visualHeight > 0 and visualHeight or max(20, height - 8)

    return width, height
end

function M:HideNativeMenuArt(menu)
    if not menu then return end

    LockHiddenRegion(menu.NineSlice)
    LockHiddenRegion(menu.Border)
end

function M:StyleMenuFrame()
    local menu = _G.GameMenuFrame
    if not menu then return end

    if not IsGameMenuSkinEnabled() then
        HideExternalEscapeVisuals()
        HideKUIFrameArt(menu)
        return
    end

    if ShouldUseNativeGameMenuPresentation() then
        HideExternalEscapeVisuals()
        HideKUIFrameArt(menu)
        return
    end

    self:HideNativeMenuArt(menu)
    DisableKUIMoveGameMenuHandling()
    NormalizeGameMenuScale(menu)
    EnsureGameMenuDraggable(menu)

    local bgR, bgG, bgB, bgA = GetBackgroundColor()
    local accentR, accentG, accentB = GetAccentColor()
    local borderR, borderG, borderB, borderA = GetBorderColor()

    HideKUIFrameArt(menu)
    if menu.SetBackdropColor then
        pcall(menu.SetBackdropColor, menu, 0, 0, 0, 0)
    end
    if menu.SetBackdropBorderColor then
        pcall(menu.SetBackdropBorderColor, menu, 0, 0, 0, 0)
    end

    local overlay = EnsureExternalMenuOverlay(menu)
    if overlay then
        if overlay.SetFrameStrata and menu.GetFrameStrata then
            overlay:SetFrameStrata(menu:GetFrameStrata())
        end
        if overlay.SetFrameLevel and menu.GetFrameLevel then
            overlay:SetFrameLevel(max(0, (menu:GetFrameLevel() or 1) - 1))
        end
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", menu, "TOPLEFT", -2, 2)
        overlay:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", 2, -2)
        LayoutOverlayTextures(overlay, 1)
        RecolorOverlayTextures(overlay, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)
        if menu.IsShown and menu:IsShown() then
            overlay:Show()
        else
            overlay:Hide()
        end
    end

    if menu.IsShown and menu:IsShown() then
        self:RequestForeignOverlaySuppression(menu)
    end

    if menu.Header then
        for _, region in ipairs({ menu.Header:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetAlpha(0)
            end
        end

        local title = menu.Header.Text or (menu.Header.GetFontString and menu.Header:GetFontString())
        if title then
            title:SetFont(CurrentFontPath(), 15, "OUTLINE")
            title:SetTextColor(accentR, accentG, accentB, 1)
            title:SetShadowColor(0, 0, 0, 0.85)
            title:SetShadowOffset(1, -1)
        end
    end
end

function M:EnsureButtonFont(button, text)
    if not button then return end

    if not IsGameMenuSkinEnabled() then
        if text and button.SetText then
            button:SetText(text)
        end

        if button.SetNormalFontObject and GameFontNormal then
            button:SetNormalFontObject(GameFontNormal)
        end
        if button.SetHighlightFontObject and GameFontHighlight then
            button:SetHighlightFontObject(GameFontHighlight)
        end
        if button.SetDisabledFontObject and GameFontDisable then
            button:SetDisabledFontObject(GameFontDisable)
        end

        local fontString = button.GetFontString and button:GetFontString()
        if fontString and fontString.SetFontObject and GameFontNormal then
            fontString:SetFontObject(GameFontNormal)
        end

        return
    end

    local fontString = button.GetFontString and button:GetFontString()
    if not fontString then
        fontString = button:CreateFontString(nil, "OVERLAY")
        fontString:SetPoint("CENTER")
        fontString:SetJustifyH("CENTER")
        fontString:SetJustifyV("MIDDLE")
        button:SetFontString(fontString)
    end

    fontString:SetFont(CurrentFontPath(), 13, "OUTLINE")
    fontString:SetTextColor(1, 1, 1, 1)
    fontString:SetShadowColor(0, 0, 0, 0.85)
    fontString:SetShadowOffset(1, -1)
    fontString:SetJustifyH("CENTER")
    fontString:SetJustifyV("MIDDLE")

    local resolvedText = text
    if not resolvedText and button.GetText then
        resolvedText = button:GetText()
    end

    if resolvedText then
        if button.SetText then
            button:SetText(resolvedText)
        end
        fontString:SetText(resolvedText)
    end
end

function M:HideNativeButtonArt(button)
    if not button then return end

    local artKeys = {
        "backdrop",
        "Left",
        "Middle",
        "Right",
        "LeftDisabled",
        "MiddleDisabled",
        "RightDisabled",
        "Border",
        "NineSlice",
        "NormalTexture",
        "PushedTexture",
        "DisabledTexture",
        "HighlightTexture",
    }

    for _, key in ipairs(artKeys) do
        local region = button[key]
        if type(region) ~= "function" then
            LockHiddenRegion(region)
        end
    end

    if button.backdrop and button.backdrop.SetBackdropBorderColor then
        button.backdrop:SetBackdropBorderColor(0, 0, 0, 0)
    end
    if button.backdrop and button.backdrop.SetBackdropColor then
        button.backdrop:SetBackdropColor(0, 0, 0, 0)
    end
    if button.backdrop then
        HideKUIFrameArt(button.backdrop)
    end

    if button.SetNormalTexture then
        button:SetNormalTexture("")
    end
    if button.SetHighlightTexture then
        button:SetHighlightTexture("")
    end
    if button.SetPushedTexture then
        button:SetPushedTexture("")
    end
    if button.SetDisabledTexture then
        button:SetDisabledTexture("")
    end

    for _, region in ipairs({ button:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") and not region._ktEscapeOwned then
            region:SetAlpha(0)
            if region.Hide then
                region:Hide()
            end
        end
    end

end

function M:UpdateButtonVisual(button, hovered)
    if not button then return end

    local menu = _G.GameMenuFrame
    local visualHost = EnsureEscapeVisualHost(button)
    local externalBackdrop = EnsureExternalButtonBackdrop(button)
    local hoverOverlay = nil
    if visualHost then
        if visualHost.SetFrameLevel and button.GetFrameLevel then
            visualHost:SetFrameLevel(max(0, (button:GetFrameLevel() or 1) - 1))
        end
        visualHost:Show()
        if not button._ktVisualHoverOverlay then
            hoverOverlay = visualHost:CreateTexture(nil, "ARTWORK", nil, 1)
            hoverOverlay:SetAllPoints()
            hoverOverlay:SetColorTexture(1, 1, 1, 0)
            hoverOverlay._ktEscapeOwned = true
            button._ktVisualHoverOverlay = hoverOverlay
        else
            hoverOverlay = button._ktVisualHoverOverlay
        end
    end

    if ShouldUseNativeGameMenuPresentation() then
        if externalBackdrop then
            externalBackdrop:Hide()
        end
        HideKUIFrameArt(button)
        if visualHost then
            HideKUIFrameArt(visualHost)
            visualHost:Hide()
        end
        if button._ktHoverOverlay then
            button._ktHoverOverlay:SetColorTexture(1, 1, 1, 0)
        end
        if hoverOverlay then
            hoverOverlay:SetColorTexture(1, 1, 1, 0)
        end
        return
    end

    if not IsGameMenuSkinEnabled() then
        if externalBackdrop then externalBackdrop:Hide() end
        HideKUIFrameArt(button)
        if visualHost then
            HideKUIFrameArt(visualHost)
            visualHost:Hide()
        end
        if button._ktHoverOverlay then
            button._ktHoverOverlay:SetColorTexture(1, 1, 1, 0)
        end
        if hoverOverlay then
            hoverOverlay:SetColorTexture(1, 1, 1, 0)
        end
        return
    end

    self:EnsureButtonFont(button)

    local fontString = button.GetFontString and button:GetFontString()
    if fontString then
        if button.IsEnabled and not button:IsEnabled() then
            fontString:SetTextColor(0.55, 0.55, 0.60, 1)
        else
            fontString:SetTextColor(1, 1, 1, 1)
        end
    end

    local borderR, borderG, borderB = GetBorderColor()
    local bgAlpha = hovered and 0.90 or 0.96
    HideKUIFrameArt(button)
    if button.SetBackdropColor then
        pcall(button.SetBackdropColor, button, 0, 0, 0, 0)
    end
    if button.SetBackdropBorderColor then
        pcall(button.SetBackdropBorderColor, button, 0, 0, 0, 0)
    end

    local buttonVisible = (button.IsShown and button:IsShown()) and (menu and menu.IsShown and menu:IsShown())
    if not buttonVisible then
        if externalBackdrop then externalBackdrop:Hide() end
        if visualHost then
            visualHost:Hide()
        end
        local hiddenOverlay = button._ktHoverOverlay
        if hiddenOverlay then
            hiddenOverlay:SetColorTexture(1, 1, 1, 0)
        end
        if hoverOverlay then
            hoverOverlay:SetColorTexture(1, 1, 1, 0)
        end
        return
    end

    if visualHost then
        HideKUIFrameArt(visualHost)
        visualHost:Hide()
        if hoverOverlay then
            hoverOverlay:SetColorTexture(1, 1, 1, hovered and 0.05 or 0)
        end
    end

    if externalBackdrop then
        if externalBackdrop.SetFrameStrata and button.GetFrameStrata then
            externalBackdrop:SetFrameStrata(button:GetFrameStrata())
        end
        if externalBackdrop.SetFrameLevel and button.GetFrameLevel then
            externalBackdrop:SetFrameLevel(max(0, (button:GetFrameLevel() or 1) - 1))
        end
        externalBackdrop:ClearAllPoints()
        externalBackdrop:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        externalBackdrop:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        LayoutOverlayTextures(externalBackdrop, 1)
        RecolorOverlayTextures(
            externalBackdrop,
            0, 0, 0, bgAlpha,
            hovered and 1 or borderR,
            hovered and 1 or borderG,
            hovered and 1 or borderB,
            1
        )
        externalBackdrop:Show()
    end

    if fontString then
        fontString:ClearAllPoints()
        fontString:SetPoint("CENTER", button, "CENTER", 0, 0)
        fontString:SetWidth(max((button:GetWidth() or FALLBACK_BUTTON_WIDTH) - 10, 1))
        fontString:SetHeight(button:GetHeight() or FALLBACK_BUTTON_HEIGHT)
    end

    local overlayKey = "_ktHoverOverlay"
    if not button[overlayKey] then
        local overlay = button:CreateTexture(nil, "HIGHLIGHT", nil, 0)
        overlay:SetAllPoints()
        overlay:SetColorTexture(1, 1, 1, 0)
        overlay._ktEscapeOwned = true
        button[overlayKey] = overlay
    end

    button[overlayKey]:SetColorTexture(1, 1, 1, 0)
end

function M:StyleButton(button, text)
    if not button then return end

    if ShouldUseNativeGameMenuPresentation() then
        if text and button.SetText then
            button:SetText(text)
        end

        if button.SetNormalFontObject and GameFontNormal then
            button:SetNormalFontObject(GameFontNormal)
        end
        if button.SetHighlightFontObject and GameFontHighlight then
            button:SetHighlightFontObject(GameFontHighlight)
        end
        if button.SetDisabledFontObject and GameFontDisable then
            button:SetDisabledFontObject(GameFontDisable)
        end

        local fontString = button.GetFontString and button:GetFontString()
        if fontString and fontString.SetFontObject and GameFontNormal then
            fontString:SetFontObject(GameFontNormal)
        end

        local externalBackdrop = EnsureExternalButtonBackdrop(button)
        if externalBackdrop then
            externalBackdrop:Hide()
        end
        HideKUIFrameArt(button)
        if button._ktVisualHost then
            HideKUIFrameArt(button._ktVisualHost)
            button._ktVisualHost:Hide()
        end
        return
    end

    self:EnsureButtonFont(button, text)

    if IsGameMenuSkinEnabled() then
        self:HideNativeButtonArt(button)
    else
        HideKUIFrameArt(button)
        if button._ktVisualHost then
            HideKUIFrameArt(button._ktVisualHost)
            button._ktVisualHost:Hide()
        end
    end

    if not button._ktEscapeMenuStyled then
        button:HookScript("OnEnter", function(btn)
            if M and M.UpdateButtonVisual then
                M:UpdateButtonVisual(btn, true)
            end
        end)
        button:HookScript("OnLeave", function(btn)
            if M and M.UpdateButtonVisual then
                M:UpdateButtonVisual(btn, false)
            end
        end)
        button:HookScript("OnShow", function(btn)
            if M and M.UpdateButtonVisual then
                M:UpdateButtonVisual(btn, false)
            end
        end)
        button:HookScript("OnHide", function(btn)
            local visualHost = btn._ktEscapeVisualHost or btn._ktVisualHost
            if visualHost then
                visualHost:Hide()
            end
            local externalBackdrop = M and M._externalButtonBackdrops and M._externalButtonBackdrops[btn]
            if externalBackdrop then
                externalBackdrop:Hide()
            end
            if btn._ktHoverOverlay then
                btn._ktHoverOverlay:SetColorTexture(1, 1, 1, 0)
            end
        end)
        button._ktEscapeMenuStyled = true
    end

    self:UpdateButtonVisual(button, false)
end

function M:StabilizeCustomButtons()
    if ShouldUseNativeGameMenuPresentation() then
        HideCustomGameMenuButtons()
        return
    end

    if not self.buttons then return end

    local width = self._referenceButtonWidth or FALLBACK_BUTTON_WIDTH
    local height = self._referenceButtonHeight or FALLBACK_BUTTON_HEIGHT

    for _, button in pairs(self.buttons) do
        if button then
            button:SetSize(width, height)
            self:StyleButton(button)
        end
    end
end

function M:EnsureButtons()
    local menu = _G.GameMenuFrame
    if not menu then return end

    self.buttons = self.buttons or {}

    if ShouldUseNativeGameMenuPresentation() then
        HideCustomGameMenuButtons()
        return
    end

    local definitions = {
        {
            key = "config",
            name = "GameMenuButtonKullThranUI",
            text = "KullThranUI",
            onClick = function()
                CloseGameMenu()
                OpenConfigMenu()
            end,
        },
        {
            key = "unlock",
            name = "GameMenuButtonKUIUnlockMode",
            text = "KUI Unlock Mode",
            onClick = function()
                CloseGameMenu()
                ToggleUnlockMode()
            end,
        },
    }

    for _, definition in ipairs(definitions) do
        local button = _G[definition.name]
        if not button then
            button = CreateFrame("Button", definition.name, menu, "UIPanelButtonTemplate")
        elseif button:GetParent() ~= menu then
            button:SetParent(menu)
        end

        button._ktEscapeMenuCustom = true
        button._ktEscapeMenuKey = definition.key
        button.ignoreInLayout = true
        button:SetSize(self._referenceButtonWidth or FALLBACK_BUTTON_WIDTH, self._referenceButtonHeight or FALLBACK_BUTTON_HEIGHT)
        button:SetScript("OnClick", definition.onClick)
        button:Show()

        self:StyleButton(button, definition.text)
        self.buttons[definition.key] = button
    end
end

function M:UpdateCustomButtonOrder()
    if not self.buttons then return end

    local standardButtons = self:CollectVisibleButtons(false)
    local baseOrder = #standardButtons

    if #standardButtons > 0 then
        local lastButton = standardButtons[#standardButtons]
        baseOrder = tonumber(lastButton.layoutIndex or lastButton._ktMenuOrder) or baseOrder
    end

    if self.buttons.config then
        self.buttons.config._ktMenuOrder = baseOrder + 0.1
        self.buttons.config.layoutIndex = baseOrder + 0.1
    end

    if self.buttons.unlock then
        self.buttons.unlock._ktMenuOrder = baseOrder + 0.2
        self.buttons.unlock.layoutIndex = baseOrder + 0.2
    end
end

function M:CompactLayout()
    local menu = _G.GameMenuFrame
    if not menu then return end

    local standardButtons = self:CollectVisibleButtons(false)
    local customButtons = {}
    if self.buttons and self.buttons.config and self.buttons.config:IsShown() then
        customButtons[#customButtons + 1] = self.buttons.config
    end
    if self.buttons and self.buttons.unlock and self.buttons.unlock:IsShown() then
        customButtons[#customButtons + 1] = self.buttons.unlock
    end

    local buttons = {}
    for _, button in ipairs(standardButtons) do
        buttons[#buttons + 1] = button
    end
    for _, button in ipairs(customButtons) do
        buttons[#buttons + 1] = button
    end

    if #buttons == 0 then
        HideExternalEscapeVisuals()
        return
    end

    HideExternalEscapeVisuals()

    local buttonWidth, buttonHeight = self:GetReferenceButtonSize(buttons)
    local menuWidth = max(buttonWidth + (PANEL_INSET * 2), 212)
    menu:SetWidth(menuWidth)

    local headerShown = menu.Header and menu.Header:IsShown()
    if headerShown then
        menu.Header:ClearAllPoints()
        menu.Header:SetPoint("TOPLEFT", menu, "TOPLEFT", 8, -10)
        menu.Header:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -8, -10)
        menu.Header:SetHeight(20)
    end

    local topOffset = headerShown and TOP_OFFSET_WITH_HEADER or TOP_OFFSET_NO_HEADER
    local previous

    for _, button in ipairs(buttons) do
        self:StyleButton(button)
        button:SetSize(buttonWidth, buttonHeight)
        button:ClearAllPoints()

        if previous then
            button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -BUTTON_GAP)
            button:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -BUTTON_GAP)
        else
            button:SetPoint("TOPLEFT", menu, "TOPLEFT", PANEL_INSET, -topOffset)
            button:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -PANEL_INSET, -topOffset)
        end

        previous = button
    end

    local totalHeight = topOffset + (#buttons * buttonHeight) + ((#buttons - 1) * BUTTON_GAP) + BOTTOM_PAD
    local menuTop = menu.GetTop and menu:GetTop() or nil
    local lastBottom = previous and previous.GetBottom and previous:GetBottom() or nil
    if menuTop and lastBottom then
        totalHeight = max(totalHeight, floor((menuTop - lastBottom) + BOTTOM_PAD + 0.5))
    end
    menu:SetHeight(totalHeight)
end

function M:LayoutSafeModeCustomButtons()
    local menu = _G.GameMenuFrame
    if not (menu and self.buttons) then
        return
    end

    local standardButtons = self:CollectVisibleButtons(false)
    local customButtons = {}
    if self.buttons.config and self.buttons.config:IsShown() then
        customButtons[#customButtons + 1] = self.buttons.config
    end
    if self.buttons.unlock and self.buttons.unlock:IsShown() then
        customButtons[#customButtons + 1] = self.buttons.unlock
    end

    if #customButtons == 0 then
        return
    end

    local buttonWidth = self._referenceButtonWidth or FALLBACK_BUTTON_WIDTH
    local buttonHeight = self._referenceButtonHeight or FALLBACK_BUTTON_HEIGHT
    local anchor = standardButtons[#standardButtons]
    local topOffset = (menu.Header and menu.Header:IsShown()) and TOP_OFFSET_WITH_HEADER or TOP_OFFSET_NO_HEADER

    for index, button in ipairs(customButtons) do
        button:SetSize(buttonWidth, buttonHeight)
        button:ClearAllPoints()
        if index == 1 then
            if anchor then
                button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -BUTTON_GAP)
                button:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -BUTTON_GAP)
            else
                button:SetPoint("TOPLEFT", menu, "TOPLEFT", PANEL_INSET, -topOffset)
                button:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -PANEL_INSET, -topOffset)
            end
        else
            local previous = customButtons[index - 1]
            button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -BUTTON_GAP)
            button:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -BUTTON_GAP)
        end
        self:StyleButton(button)
    end

    local lastButton = customButtons[#customButtons]
    local menuTop = menu.GetTop and menu:GetTop() or nil
    local lastBottom = lastButton and lastButton.GetBottom and lastButton:GetBottom() or nil
    if menuTop and lastBottom then
        local requiredHeight = max(menu:GetHeight() or 0, floor((menuTop - lastBottom) + BOTTOM_PAD + 0.5))
        menu:SetHeight(requiredHeight)
    end
end

function M:IsCustomMenuHealthy(menu)
    menu = menu or _G.GameMenuFrame
    if not menu or not menu.IsShown or not menu:IsShown() then
        return true
    end

    if ShouldUseNativeGameMenuPresentation() or not IsGameMenuSkinEnabled() then
        return true
    end

    if not (self.buttons and self.buttons.config and self.buttons.unlock) then
        return false
    end

    for _, key in ipairs({ "config", "unlock" }) do
        local button = self.buttons[key]
        if not (button and button.IsShown and button:IsShown()) then
            return false
        end
        if not IsRegionWithinMenuBounds(button, menu) then
            return false
        end
    end

    local visibleButtons = self:CollectVisibleButtons(true)
    local visibleCount = 0
    for _, button in ipairs(visibleButtons) do
        if button and button.IsShown and button:IsShown() then
            visibleCount = visibleCount + 1
            if not IsRegionWithinMenuBounds(button, menu) then
                return false
            end

            local backdrop = self._externalButtonBackdrops and self._externalButtonBackdrops[button]
            if not (backdrop and backdrop.IsShown and backdrop:IsShown()) then
                return false
            end
        end
    end

    return visibleCount > 0
end

function M:ScheduleMenuHealthCheck(delay, reason)
    local menu = _G.GameMenuFrame
    if not (menu and menu.IsShown and menu:IsShown()) then
        return
    end

    if ShouldUseNativeGameMenuPresentation() or not IsGameMenuSkinEnabled() then
        return
    end

    local token = self._menuHealthToken
    C_Timer.After(delay, function()
        if not (M and M.IsCustomMenuHealthy and M.RefreshLayout) then
            return
        end
        if token ~= M._menuHealthToken then
            return
        end

        local currentMenu = _G.GameMenuFrame
        if not (currentMenu and currentMenu.IsShown and currentMenu:IsShown()) then
            return
        end
        if M._refreshing or M._refreshPending or M._holdMenuHidden then
            return
        end
        if InCombatLockdown and InCombatLockdown() then
            return
        end

        if not M:IsCustomMenuHealthy(currentMenu) then
            DebugEscapeMenu("Health check rebuild: %s", tostring(reason or "unknown"))
            M:RefreshLayout()
            M:StabilizeCustomButtons()
        end
    end)
end

function M:ArmMenuHealthChecks(reason)
    if ShouldUseNativeGameMenuPresentation() or not IsGameMenuSkinEnabled() then
        return
    end

    self:ScheduleMenuHealthCheck(MENU_HEALTH_DELAY_SHORT, (reason or "show") .. ":short")
    self:ScheduleMenuHealthCheck(MENU_HEALTH_DELAY_MEDIUM, (reason or "show") .. ":medium")
    self:ScheduleMenuHealthCheck(MENU_HEALTH_DELAY_LONG, (reason or "show") .. ":long")
end

function M:RunCombatSafeStyle(menu)
    menu = menu or _G.GameMenuFrame
    if not (menu and menu.IsShown and menu:IsShown()) then
        return
    end

    -- The external art lives on UIParent children and only uses combat-safe
    -- calls (CreateTexture/SetColorTexture/SetPoint on non-protected frames),
    -- so it can be restored while in combat without tainting the bindings
    -- pipeline. Never touch GameMenuFrame geometry, scripts or backdrop here.
    -- FontString and texture region styling (SetFont/SetTextColor/SetAlpha)
    -- on the header/title are also safe in combat.
    local overlay = EnsureExternalMenuOverlay(menu)
    if overlay then
        if overlay.SetFrameStrata and menu.GetFrameStrata then
            overlay:SetFrameStrata(menu:GetFrameStrata())
        end
        if overlay.SetFrameLevel and menu.GetFrameLevel then
            overlay:SetFrameLevel(max(0, (menu:GetFrameLevel() or 1) - 1))
        end
        overlay:ClearAllPoints()
        overlay:SetPoint("TOPLEFT", menu, "TOPLEFT", -2, 2)
        overlay:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", 2, -2)
        local bgR, bgG, bgB, bgA = GetBackgroundColor()
        local borderR, borderG, borderB, borderA = GetBorderColor()
        LayoutOverlayTextures(overlay, 1)
        RecolorOverlayTextures(overlay, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA)
        overlay:Show()
    end

    if menu.Header then
        for _, region in ipairs({ menu.Header:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetAlpha(0)
            end
        end

        local title = menu.Header.Text or (menu.Header.GetFontString and menu.Header:GetFontString())
        if title and title.SetFont then
            local accentR, accentG, accentB = GetAccentColor()
            title:SetFont(CurrentFontPath(), 15, "OUTLINE")
            title:SetTextColor(accentR, accentG, accentB, 1)
            title:SetShadowColor(0, 0, 0, 0.85)
            title:SetShadowOffset(1, -1)
        end
    end

    -- Blizzard's GameMenuFrame Layout hides children it does not manage when
    -- it re-lays out on show, which drops the KUI custom buttons while in
    -- combat. Re-show them here: they are plain non-secure buttons
    -- (UIPanelButtonTemplate), so Show is not a protected call even in combat.
    if self.buttons then
        for _, button in pairs(self.buttons) do
            if button and button.Show and not (button.IsShown and button:IsShown()) then
                button:Show()
            end
        end
    end

    local buttons = self:CollectVisibleButtons(true)
    for _, button in ipairs(buttons) do
        if button then
            self:UpdateButtonVisual(button, false)
        end
    end
end

function M:RunCombatFullStyle(menu)
    menu = menu or _G.GameMenuFrame
    if not (menu and menu.IsShown and menu:IsShown()) then
        return
    end

    -- Replicate the out-of-combat presentation during combat so the menu looks
    -- identical (compact layout, custom buttons, KUI textures, styled title).
    -- NormalizeGameMenuScale (SetScale), the KUIMove detach and the draggable
    -- wiring are already applied and become no-ops here. Blizzard's Layout has
    -- already run on show, so we only re-style and re-position on top of it.
    self:EnsureButtons()
    self:StyleMenuFrame()
    if not ShouldUseNativeGameMenuPresentation() then
        self:UpdateCustomButtonOrder()
        self:RefreshVisibleButtonSkins(true)
        self:CompactLayout()
        self:LayoutSafeModeCustomButtons()
    else
        HideCustomGameMenuButtons()
    end
    self:StabilizeCustomButtons()
end

function M:RefreshLayout()
    local menu = _G.GameMenuFrame
    if not menu then return end
    if not menu:IsShown() then return end

    if InCombatLockdown and InCombatLockdown() then
        -- 12.x: GameMenuFrame es un frame SEGURO: tocar su geometria o crear
        -- botones en combate son llamadas protegidas que manchan (taint) el
        -- pipeline de bindings (teclas muertas hasta /reload). Por eso se
        -- difiere el estilado a PLAYER_REGEN_ENABLED via _refreshAfterCombat.
        -- Aun asi, replicamos el aspecto completo durante el combate
        -- (RunCombatFullStyle): el layout de Blizzard ya corrio en OnShow, y
        -- solo re-estilamos y reposicionamos encima para que el menu se vea
        -- igual que fuera de combate. Si el taint se confirmara en pruebas,
        -- revertir a RunCombatSafeStyle (solo arte externo).
        self._refreshAfterCombat = true
        if self._hideUntilLayout and menu.SetAlpha then
            menu:SetAlpha(1)
            self._hideUntilLayout = nil
        end
        RunEscapeMenuStep("combat:fullStyle", function() self:RunCombatFullStyle(menu) end)
        return
    end

    if self._refreshing then
        return
    end

    self._refreshing = true
    if self.IsDebugTraceActive and self:IsDebugTraceActive() then
        self:LogGameMenuState("RefreshLayout:start", menu)
    end

    if IsSecureGameMenuSafeMode() then
        self._suspendMenuHooks = true
        RunEscapeMenuStep("safe:EnsureButtons", function() self:EnsureButtons() end)
        RunEscapeMenuStep("safe:UpdateVisibleButtons", function()
            if _G.GameMenuFrame_UpdateVisibleButtons then
                _G.GameMenuFrame_UpdateVisibleButtons()
            end
        end)
        RunEscapeMenuStep("safe:MarkDirty", function()
            if menu.MarkDirty then
                menu:MarkDirty()
            end
        end)
        RunEscapeMenuStep("safe:Layout", function()
            if menu.Layout then
                menu:Layout()
            end
        end)
        RunEscapeMenuStep("safe:StyleMenuFrame", function() self:StyleMenuFrame() end)
        if not ShouldUseNativeGameMenuPresentation() then
            RunEscapeMenuStep("safe:UpdateCustomButtonOrder", function() self:UpdateCustomButtonOrder() end)
            RunEscapeMenuStep("safe:RefreshVisibleButtonSkins", function() self:RefreshVisibleButtonSkins(true) end)
            RunEscapeMenuStep("safe:CompactLayout", function() self:CompactLayout() end)
            RunEscapeMenuStep("safe:LayoutSafeModeCustomButtons", function() self:LayoutSafeModeCustomButtons() end)
        else
            HideCustomGameMenuButtons()
        end
        self._suspendMenuHooks = nil
        self:StabilizeCustomButtons()
        if self.IsDebugTraceActive and self:IsDebugTraceActive() then
            self:LogGameMenuState("RefreshLayout:safeMode", menu)
        end
        self:ScheduleMenuHealthCheck(MENU_HEALTH_DELAY_MEDIUM, "safeMode")
        self._refreshing = nil
        return
    end

    local restoreAlpha
    if self._hideUntilLayout and menu.GetAlpha then
        restoreAlpha = menu:GetAlpha()
        menu:SetAlpha(0)
    end
    self._suspendMenuHooks = true
    RunEscapeMenuStep("layout:EnsureButtons", function() self:EnsureButtons() end)
    RunEscapeMenuStep("layout:UpdateVisibleButtons", function()
        if _G.GameMenuFrame_UpdateVisibleButtons then
            _G.GameMenuFrame_UpdateVisibleButtons()
        end
    end)
    RunEscapeMenuStep("layout:MarkDirty", function()
        if menu.MarkDirty then
            menu:MarkDirty()
        end
    end)
    RunEscapeMenuStep("layout:Layout", function()
        if menu.Layout then
            menu:Layout()
        end
    end)
    RunEscapeMenuStep("layout:StyleMenuFrame", function() self:StyleMenuFrame() end)
    if not ShouldUseNativeGameMenuPresentation() then
        RunEscapeMenuStep("layout:UpdateCustomButtonOrder", function() self:UpdateCustomButtonOrder() end)
        RunEscapeMenuStep("layout:CompactLayout", function() self:CompactLayout() end)
    else
        HideCustomGameMenuButtons()
    end
    self._suspendMenuHooks = nil
    if restoreAlpha then
        if self._holdMenuHidden then
            menu:SetAlpha(0)
        else
            menu:SetAlpha(restoreAlpha > 0 and restoreAlpha or 1)
        end
    end
    if not self._holdMenuHidden then
        self._hideUntilLayout = nil
    end
    if self.IsDebugTraceActive and self:IsDebugTraceActive() then
        self:LogGameMenuState("RefreshLayout:end", menu)
    end
    self:ScheduleMenuHealthCheck(MENU_HEALTH_DELAY_MEDIUM, "layout")
    self._refreshing = nil
end

function M:RequestRefresh()
    if self._refreshPending then
        return
    end

    self._refreshPending = true
    C_Timer.After(0, function()
        self._refreshPending = nil
        if self and self.RefreshLayout then
            self:RefreshLayout()
        end
    end)
end

function M:RefreshTheme()
    if InCombatLockdown and InCombatLockdown() then
        self._refreshAfterCombat = true
        return
    end

    if _G.GameMenuFrame and _G.GameMenuFrame:IsShown() then
        self:RefreshLayout()
        return
    end

    HideExternalEscapeVisuals()
    self:StyleMenuFrame()
    if self.buttons then
        for _, button in pairs(self.buttons) do
            if button then
                self:StyleButton(button)
            end
        end
    end
end

function M:HookMenu()
    if self._menuHooked then
        return
    end

    local menu = _G.GameMenuFrame
    if not menu then return end

    self._menuHooked = true

    if IsEscapeMenuDebugEnabled() and not menu._ktEscapeMenuDebugHooked then
        menu._ktEscapeMenuDebugHooked = true

        if menu.SetScale then
            hooksecurefunc(menu, "SetScale", function(self, newScale)
                if M and M.IsDebugTraceActive and M:IsDebugTraceActive() then
                    M:LogGameMenuState(format("hook:SetScale(%s)", DebugMetric(newScale)), self)
                end
            end)
        end

        if menu.SetAlpha then
            hooksecurefunc(menu, "SetAlpha", function(self, newAlpha)
                if M and M.IsDebugTraceActive and M:IsDebugTraceActive() then
                    M:LogGameMenuState(format("hook:SetAlpha(%s)", DebugMetric(newAlpha)), self)
                end
            end)
        end

        if menu.SetHeight then
            hooksecurefunc(menu, "SetHeight", function(self, newHeight)
                if M and M.IsDebugTraceActive and M:IsDebugTraceActive() then
                    M:LogGameMenuState(format("hook:SetHeight(%s)", DebugMetric(newHeight)), self)
                end
            end)
        end
    end

    if _G.GameMenuFrame_UpdateVisibleButtons then
        hooksecurefunc("GameMenuFrame_UpdateVisibleButtons", function()
            if M and M.IsDebugTraceActive and M:IsDebugTraceActive() then
                M:LogGameMenuState("hook:UpdateVisibleButtons", _G.GameMenuFrame)
            end
            if M and M._suspendMenuHooks then
                return
            end
            if M and M._holdMenuHidden and _G.GameMenuFrame and _G.GameMenuFrame:IsShown() then
                M:ArmMenuSettleReveal(_G.GameMenuFrame, "Settle:UpdateVisibleButtons")
            end
            if M and M.RequestRefresh and _G.GameMenuFrame and _G.GameMenuFrame:IsShown() then
                M:RequestRefresh()
            end
        end)
    end

    if menu.Layout then
        hooksecurefunc(menu, "Layout", function()
            if M and M.IsDebugTraceActive and M:IsDebugTraceActive() then
                M:LogGameMenuState("hook:Layout", menu)
            end
            if M and M._suspendMenuHooks then
                return
            end
            if M and M._holdMenuHidden and menu:IsShown() then
                M:ArmMenuSettleReveal(menu, "Settle:Layout")
                return
            end
            if M and M.RequestRefresh and menu:IsShown() then
                M:RequestRefresh()
            end
        end)
    end

    menu:HookScript("OnHide", function()
        if not M then
            return
        end

        if not ShouldUseNativeGameMenuPresentation() then
            RestoreMenuDefaultPoints(menu)
        end
        if not ShouldUseNativeGameMenuPresentation() and menu.SetUserPlaced and menu.IsMovable and menu:IsMovable() then
            menu:SetUserPlaced(false)
        end
        HideExternalEscapeVisuals()
        M._hideUntilLayout = nil
        M._holdMenuHidden = nil
        M._showSettleToken = (M._showSettleToken or 0) + 1
        M._menuHealthToken = (M._menuHealthToken or 0) + 1
        if menu.SetAlpha then
            menu:SetAlpha(1)
        end
    end)

    menu:HookScript("OnShow", function()
        if not (M and M.RefreshLayout and M.RequestRefresh) then
            return
        end

        local traceToken = M:StartDebugTrace("OnShow:start", menu)
        M._menuHealthToken = (M._menuHealthToken or 0) + 1
        M:BeginMenuSettle(menu)
        DisableKUIMoveGameMenuHandling()
        NormalizeGameMenuScale(menu)

        M:LogGameMenuState("OnShow:beforeRefresh", menu)
        M:RefreshLayout()
        M:LogGameMenuState("OnShow:afterRefresh", menu)
        if not IsSecureGameMenuSafeMode() then
            M:RequestRefresh()
            M:ArmMenuSettleReveal(menu, "Settle:OnShow")
        end
        M:ScheduleDebugSnapshot("OnShow:+0.000", 0, menu, traceToken)
        M:ScheduleDebugSnapshot("OnShow:+0.016", 0.016, menu, traceToken)
        M:ScheduleDebugSnapshot("OnShow:+0.033", 0.033, menu, traceToken)
        M:ScheduleDebugSnapshot("OnShow:+0.066", 0.066, menu, traceToken)
        M:ScheduleDebugSnapshot("OnShow:+0.100", 0.100, menu, traceToken)
        M:ArmMenuHealthChecks("OnShow")
    end)
end

function M:TrySetup()
    if not _G.GameMenuFrame then
        return false
    end

    if ShouldUseNativeGameMenuPresentation() then
        ApplyNativeGameMenuMode(_G.GameMenuFrame)
        self._refreshAfterCombat = nil
        return true
    end

    DisableKUIMoveGameMenuHandling()
    self:EnsureButtons()
    self:StyleMenuFrame()
    self:HookMenu()
    self:RequestRefresh()
    return true
end

function M:PLAYER_REGEN_ENABLED()
    if self._refreshAfterCombat then
        self._refreshAfterCombat = nil
        self:RequestRefresh()
    end
end

function M:OnEnable()
    self:RegisterEvent("PLAYER_LOGIN", "TrySetup")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "TrySetup")
    self:RegisterEvent("ADDON_LOADED", "TrySetup")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("UI_SCALE_CHANGED", "RequestRefresh")
    self:RegisterEvent("DISPLAY_SIZE_CHANGED", "RequestRefresh")

    if not self._themeHooked and KT and KT.RefreshStylePalette then
        hooksecurefunc(KT, "RefreshStylePalette", function()
            if M and M.RefreshTheme then
                M:RefreshTheme()
            end
        end)
        self._themeHooked = true
    end

    if self:TrySetup() then
        return
    end

    local tries = 0
    self._bootstrapTimer = self:ScheduleRepeatingTimer(function()
        tries = tries + 1
        if self:TrySetup() or tries >= 20 then
            self:CancelTimer(self._bootstrapTimer)
            self._bootstrapTimer = nil
        end
    end, 0.5)
end
