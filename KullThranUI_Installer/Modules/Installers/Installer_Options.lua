-- Modules/Installers/Installer_Options.lua
-- Registers the "Installer" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end

KT:RegisterPage("installer", LText("Installer"), 95, function(sc, W)
    local y, h = 0, 0
    local accentR, accentG, accentB = KT:GetStyleAccentRGB()

    -- Restore the original "Installer" tab design (card + login toggle block).
    local function ApplyStableInstallerBorder(frame, r, g, b, a)
        if not frame then return end
        frame._ktInstallerBorder = frame._ktInstallerBorder or CreateFrame("Frame", nil, frame)
        local borderFrame = frame._ktInstallerBorder
        borderFrame:ClearAllPoints()
        borderFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        borderFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        borderFrame:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel()) + 8)
        borderFrame._edges = borderFrame._edges or {}
        local edges = borderFrame._edges

        local function EnsureEdge(key)
            if edges[key] then return edges[key] end
            local tex = borderFrame:CreateTexture(nil, "BORDER")
            edges[key] = tex
            return tex
        end

        local top = EnsureEdge("top")
        top:ClearAllPoints()
        top:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)
        top:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)
        top:SetHeight(1)
        top:SetColorTexture(r, g, b, a)

        local bottom = EnsureEdge("bottom")
        bottom:ClearAllPoints()
        bottom:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)
        bottom:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
        bottom:SetHeight(1)
        bottom:SetColorTexture(r, g, b, a)

        local left = EnsureEdge("left")
        left:ClearAllPoints()
        left:SetPoint("TOPLEFT", borderFrame, "TOPLEFT", 0, 0)
        left:SetPoint("BOTTOMLEFT", borderFrame, "BOTTOMLEFT", 0, 0)
        left:SetWidth(1)
        left:SetColorTexture(r, g, b, a)

        local right = EnsureEdge("right")
        right:ClearAllPoints()
        right:SetPoint("TOPRIGHT", borderFrame, "TOPRIGHT", 0, 0)
        right:SetPoint("BOTTOMRIGHT", borderFrame, "BOTTOMRIGHT", 0, 0)
        right:SetWidth(1)
        right:SetColorTexture(r, g, b, a)
    end

    local cardW = math.min((sc:GetWidth() or 760) - 40, 560)
    local cardH = 172

    local card = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    card:SetSize(cardW, cardH)
    card:SetPoint("TOP", sc, "TOP", 0, -y)
    if KT.AddBackdrop then KT:AddBackdrop(card, 0.04, 0.04, 0.05, 0.94) end
    ApplyStableInstallerBorder(card, accentR, accentG, accentB, 0.4)

    local cardAccent = card:CreateTexture(nil, "BACKGROUND")
    cardAccent:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    cardAccent:SetPoint("TOPRIGHT", card, "TOPRIGHT", -1, -1)
    cardAccent:SetHeight(44)
    cardAccent:SetColorTexture(accentR * 0.12, accentG * 0.12, accentB * 0.12, 0.22)

    local iconPanel = CreateFrame("Frame", nil, card, "BackdropTemplate")
    iconPanel:SetSize(96, 96)
    iconPanel:SetPoint("TOPLEFT", card, "TOPLEFT", 18, -24)
    if KT.AddBackdrop then KT:AddBackdrop(iconPanel, 0.06, 0.06, 0.08, 0.92) end
    ApplyStableInstallerBorder(iconPanel, accentR, accentG, accentB, 0.35)

    local logo = iconPanel:CreateTexture(nil, "ARTWORK")
    logo:SetAllPoints()
    logo:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png")
    logo:SetTexCoord(0, 1, 0, 1)
    if logo.SetDesaturated then
        logo:SetDesaturated(true)
    end
    logo:SetVertexColor(accentR, accentG, accentB, 1)

    local heroTitle = card:CreateFontString(nil, "OVERLAY")
    heroTitle:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    heroTitle:SetTextColor(1, 1, 1, 1)
    heroTitle:SetPoint("TOPLEFT", iconPanel, "TOPRIGHT", 18, -2)
    heroTitle:SetText(LText("KullThranUI Setup Wizard"))

    local heroText = card:CreateFontString(nil, "OVERLAY")
    heroText:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    heroText:SetTextColor(0.84, 0.84, 0.84, 1)
    heroText:SetPoint("TOPLEFT", heroTitle, "BOTTOMLEFT", 0, -10)
    heroText:SetWidth(cardW - 132 - 60)
    heroText:SetJustifyH("LEFT")
    heroText:SetJustifyV("TOP")
    heroText:SetText(LText("Launch the full installer to configure KullThranUI, recommended addons, profiles and base UI settings in one pass."))

    local statusText = card:CreateFontString(nil, "OVERLAY")
    statusText:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    statusText:SetTextColor(accentR, accentG, accentB, 1)
    statusText:SetPoint("BOTTOMLEFT", heroText, "BOTTOMLEFT", 0, -20)
    statusText:SetText(LText("Recommended for first-time setup and profile resets."))

    local openBtn = CreateFrame("Button", nil, card, "BackdropTemplate")
    openBtn:SetSize(250, 34)
    openBtn:SetPoint("BOTTOM", card, "BOTTOM", 0, 18)
    if KT.AddBackdrop then KT:AddBackdrop(openBtn, 0.08, 0.08, 0.11, 1) end
    ApplyStableInstallerBorder(openBtn, accentR, accentG, accentB, 0.8)

    local openBtnText = openBtn:CreateFontString(nil, "OVERLAY")
    openBtnText:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    openBtnText:SetTextColor(1, 1, 1, 1)
    openBtnText:SetPoint("CENTER")
    openBtnText:SetText(LText("Open Installer"))

    openBtn:SetScript("OnEnter", function(self)
        ApplyStableInstallerBorder(self, accentR, accentG, accentB, 1)
    end)
    openBtn:SetScript("OnLeave", function(self)
        ApplyStableInstallerBorder(self, accentR, accentG, accentB, 0.8)
    end)
    openBtn:SetScript("OnClick", function()
        local Installer = KT:GetModule("Installer", true)
        if Installer and Installer.CreateInstallerWindow then
            Installer:CreateInstallerWindow()
        end
    end)

    y = y + card:GetHeight() + 16

    local loginBlock = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    loginBlock:SetSize((sc:GetWidth() or 760) - 20, 72)
    loginBlock:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)
    if KT.AddBackdrop then KT:AddBackdrop(loginBlock, 0.03, 0.03, 0.04, 0.7) end
    ApplyStableInstallerBorder(loginBlock, 0.16, 0.16, 0.2, 1)

    local loginTitle = loginBlock:CreateFontString(nil, "OVERLAY")
    loginTitle:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    loginTitle:SetTextColor(1, 1, 1, 1)
    loginTitle:SetPoint("TOPLEFT", loginBlock, "TOPLEFT", 14, -12)
    loginTitle:SetText(LText("Installer visibility"))

    _, h = W:Toggle(loginBlock, "Show Installer On Login", -28,
        function()
            KT.db.profile.installer = KT.db.profile.installer or {}
            return KT.db.profile.installer.showOnLogin ~= false
        end,
        function(v)
            KT.db.profile.installer = KT.db.profile.installer or {}
            local installerDb = KT.db.profile.installer
            installerDb.showOnLogin = v
            if v then
                installerDb.dontShowAgain = nil
            else
                installerDb.dontShowAgain = true
                installerDb.reopenStep = nil
                installerDb.resumeStep = nil
                installerDb.reopenOnReload = nil
                installerDb.forceOpenForCharacter = nil
                installerDb.isOpen = false
            end
        end
    )

    y = y + loginBlock:GetHeight() + 8

    _, h = W:Label(sc, "Enable this if you want to undo a previous 'Don't show again' choice and let the installer appear on login again.", -y, 11); y = y + h

    return y
end)
