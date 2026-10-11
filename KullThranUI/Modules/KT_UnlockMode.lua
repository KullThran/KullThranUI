local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local UM = KT:NewModule("UnlockMode", "AceEvent-3.0", "AceHook-3.0")

local _G = _G
local UIParent = UIParent
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local GetCursorPosition = GetCursorPosition
local floor = math.floor
local abs = math.abs
local max = math.max
local min = math.min
local pairs = pairs
local ipairs = ipairs
local unpack = unpack or table.unpack
local tinsert = table.insert
local wipe = wipe

local MOVER_R, MOVER_G, MOVER_B = 0.85, 0.15, 0.15
local EMPTY = {}
local GRID_SIZE = 32
local SNAP_DISTANCE = 6
local MOVER_HOVER_DURATION = 0.22
local MOVER_HOVER_EXPANSION = 6
local MOVER_SHEEN_DURATION = 0.55
local MOVER_CLICK_DURATION = 0.5
local SIDEBAR_WIDTH = 220
local SIDEBAR_HEIGHT = 713
local SIDEBAR_BG = { r = 0.01, g = 0.01, b = 0.01, a = 0.88 }
local SIDEBAR_ACCENT = { r = 0.96, g = 0.12, b = 0.28, a = 1.0 }
local SIDEBAR_ACCENT_SOFT = { r = 0.42, g = 0.04, b = 0.10, a = 0.95 }
local SIDEBAR_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\BackgroundEditMode.png"
local SIDEBAR_BUTTON_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Button.png"
local SIDEBAR_GLOSS_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\gloss.tga"
local UNLOCK_LOGO_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png"
local UNLOCK_LOGO_CUT_UPPER_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco_CutUpper.png"
local UNLOCK_LOGO_CUT_LOWER_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco_CutLower.png"
local WHITE8X8 = "Interface\\Buttons\\WHITE8x8"
local SIDEBAR_TOP_SAFE = 38
local SIDEBAR_BOTTOM_SAFE = 42
local ICON_COG = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\cogs.png"
local ICON_RESET = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\unlock-reset.png"
local ICON_CENTER = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\unlock-center.png"
-- Paleta fija y neutra para los menus del unlock mode. El tinte de fondo del
-- estilo visual puede ser claro y, usado como relleno plano, dejaba el texto
-- ilegible fuese cual fuese el accent. El accent queda para bordes y detalles.
local MENU_BG = { 0.045, 0.045, 0.055, 0.97 }
local MENU_ROW = { 0.10, 0.10, 0.12, 0.96 }
local MENU_ROW_HOVER = { 0.17, 0.17, 0.20, 0.98 }
local MENU_INPUT_BG = { 0.015, 0.015, 0.02, 0.98 }
local MENU_TEXT = { 0.96, 0.96, 0.97, 1 }
local MENU_LABEL = { 0.76, 0.76, 0.80, 1 }
local MENU_HINT = { 0.55, 0.55, 0.60, 1 }
local MENU_DIVIDER = { 1, 1, 1, 0.08 }
local MOUSEOVER_SETTING_KEYS = {
    bar1 = { section = "actionbars", key = "fadeBar1" },
    bar2 = { section = "actionbars", key = "fadeBar2" },
    bar3 = { section = "actionbars", key = "fadeBar3" },
    bar4 = { section = "actionbars", key = "fadeBar4" },
    bar5 = { section = "actionbars", key = "fadeBar5" },
    bar6 = { section = "actionbars", key = "fadeBar6" },
    bar7 = { section = "actionbars", key = "fadeBar7" },
    bar8 = { section = "actionbars", key = "fadeBar8" },
    pet = { section = "actionbars", key = "fadePet" },
    stance = { section = "actionbars", key = "fadeStance" },
    bags = { section = "blizzframes", key = "fadeBags" },
    micro = { section = "blizzframes", key = "fadeMicroMenu" },
    tracker = { section = "blizzframes", key = "fadeObjectiveTracker" },
    status = { section = "blizzframes", key = "fadeStatusBar" },
    queue = { section = "blizzframes", key = "fadeQueueStatus" },
}
local MOUSEOVER_KEY_ALIASES = {
    action_bar_1 = "bar1",
    action_bar_2 = "bar2",
    action_bar_3 = "bar3",
    action_bar_4 = "bar4",
    action_bar_5 = "bar5",
    action_bar_6 = "bar6",
    action_bar_7 = "bar7",
    action_bar_8 = "bar8",
    main_action_bar = "bar1",
    pet_bar = "pet",
    stance_bar = "stance",
    stance_bar_1 = "stance",
    shapeshift_bar = "stance",
    bags = "bags",
    micro_menu = "micro",
    objective_tracker = "tracker",
    status_bar = "status",
    status_bar_1 = "status",
    lfg_eye = "queue",
    queue_status = "queue",
}

KT.UnlockElements = KT.UnlockElements or {}
KT.MovableElements = KT.UnlockElements

local function LText(text)
    if type(text) ~= "string" then
        return text
    end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L and L[text] then
            return L[text]
        end
    end
    return text
end

local function Round(value)
    if value >= 0 then
        return floor(value + 0.5)
    end
    return floor(value - 0.5)
end

local function CopyPosition(pos)
    if not pos then return nil end
    return {
        point = pos.point,
        relativePoint = pos.relativePoint,
        x = pos.x,
        y = pos.y,
        scale = pos.scale,
    }
end

local function EaseOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then return end
    local ok, result = pcall(func, ...)
    if not ok and KT.db and KT.db.profile and KT.db.profile.debugMode then
        print("|cFFFF0000[KT UnlockMode]|r " .. string.format(LText("Error: %s"), tostring(result)))
    end
    return ok, result
end

local function ReadThemeColor(color, fallbackR, fallbackG, fallbackB, fallbackA)
    if type(color) ~= "table" then
        return fallbackR, fallbackG, fallbackB, fallbackA
    end

    return color.r or fallbackR,
        color.g or fallbackG,
        color.b or fallbackB,
        color.a or fallbackA
end

local function BlendThemeColor(r1, g1, b1, r2, g2, b2, amount)
    local t = max(0, min(amount or 0, 1))
    return r1 + ((r2 - r1) * t),
        g1 + ((g2 - g1) * t),
        b1 + ((b2 - b1) * t)
end

local function SetThemeColor(target, r, g, b, a)
    if not target then
        return
    end

    target.r, target.g, target.b, target.a = r, g, b, a
end

local GetUnlockTheme

local function ApplyTextureGradient(texture, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
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

local function EnsureUnlockSurface(frame)
    if not frame then
        return nil
    end

    if frame._ktUnlockSurface then
        return frame._ktUnlockSurface
    end

    local surface = {}

    surface.pattern = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    surface.pattern:SetAllPoints()
    surface.pattern:SetTexture(SIDEBAR_BUTTON_TEXTURE)

    surface.shade = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    surface.shade:SetAllPoints()

    surface.gloss = frame:CreateTexture(nil, "ARTWORK", nil, 0)
    surface.gloss:SetTexture(SIDEBAR_GLOSS_TEXTURE)
    surface.gloss:SetPoint("TOPLEFT", 1, -1)
    surface.gloss:SetPoint("TOPRIGHT", -1, -1)

    surface.accentH = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    surface.accentH:SetPoint("TOPLEFT", 1, -1)
    surface.accentH:SetPoint("BOTTOMLEFT", 1, 1)
    surface.accentH:SetTexture(WHITE8X8)

    surface.accentV = frame:CreateTexture(nil, "ARTWORK", nil, 2)
    surface.accentV:SetPoint("TOPLEFT", 1, -1)
    surface.accentV:SetPoint("TOPRIGHT", -1, -1)
    surface.accentV:SetTexture(WHITE8X8)

    surface.topLine = frame:CreateTexture(nil, "ARTWORK", nil, 3)
    surface.topLine:SetPoint("TOPLEFT", 1, -1)
    surface.topLine:SetPoint("TOPRIGHT", -1, -1)
    surface.topLine:SetHeight(1)

    surface.bottomLine = frame:CreateTexture(nil, "ARTWORK", nil, 3)
    surface.bottomLine:SetPoint("BOTTOMLEFT", 1, 1)
    surface.bottomLine:SetPoint("BOTTOMRIGHT", -1, 1)
    surface.bottomLine:SetHeight(1)

    frame._ktUnlockSurface = surface
    return surface
end

local function ApplyUnlockSurface(frame, options)
    if not frame then
        return
    end

    local surface = EnsureUnlockSurface(frame)
    if not surface then
        return
    end

    local theme = GetUnlockTheme()
    local accent = options and options.accentColor or nil
    local accentR = accent and (accent[1] or accent.r) or theme.accent.r
    local accentG = accent and (accent[2] or accent.g) or theme.accent.g
    local accentB = accent and (accent[3] or accent.b) or theme.accent.b
    local width = frame:GetWidth() > 0 and frame:GetWidth() or 140
    local height = frame:GetHeight() > 0 and frame:GetHeight() or 24
    local glossAlpha = options and options.glossAlpha or 0
    local accentHAlpha = options and options.accentHAlpha or 0
    local accentVAlpha = options and options.accentVAlpha or 0

    surface.pattern:SetTexture((options and options.texturePath) or SIDEBAR_BUTTON_TEXTURE)
    surface.pattern:SetTexCoord(0, 1, 0, 1)
    surface.pattern:SetVertexColor(1, 1, 1, options and options.patternAlpha or 0)
    surface.shade:SetColorTexture(0, 0, 0, options and options.shadeAlpha or 0.10)
    surface.gloss:SetHeight(max(6, height * ((options and options.glossRatio) or 0.60)))
    surface.gloss:SetVertexColor(1, 1, 1, glossAlpha)
    surface.topLine:SetColorTexture(accentR, accentG, accentB, options and options.topLineAlpha or 0)
    surface.bottomLine:SetColorTexture(1, 1, 1, options and options.bottomLineAlpha or 0)

    if accentHAlpha > 0 then
        surface.accentH:SetWidth(max(8, width * ((options and options.accentHRatio) or 0.58)))
        ApplyTextureGradient(surface.accentH, "HORIZONTAL",
            accentR, accentG, accentB, accentHAlpha,
            accentR, accentG, accentB, 0)
        surface.accentH:Show()
    else
        surface.accentH:Hide()
    end

    if accentVAlpha > 0 then
        surface.accentV:SetHeight(max(6, height * ((options and options.accentVRatio) or 0.72)))
        ApplyTextureGradient(surface.accentV, "VERTICAL",
            accentR, accentG, accentB, accentVAlpha,
            accentR, accentG, accentB, 0)
        surface.accentV:Show()
    else
        surface.accentV:Hide()
    end
end

GetUnlockTheme = function()
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin or nil
    local unlockAccent = skin and skin.unlockModeColorMode == "custom" and skin.unlockModeColor or nil
    local palette = KT and KT.GetStylePalette and KT:GetStylePalette()
    local accentR, accentG, accentB, accentA

    if unlockAccent then
        accentR, accentG, accentB, accentA = ReadThemeColor(unlockAccent, KT.C_R or MOVER_R, KT.C_G or MOVER_G, KT.C_B or MOVER_B, 1)
    else
        if palette and palette.accent then
            accentR, accentG, accentB, accentA = palette.accent.r, palette.accent.g, palette.accent.b, palette.accent.a or 1
        else
            accentR, accentG, accentB, accentA = ReadThemeColor(
                skin and (skin.accentColor or skin.borderColor),
                KT.C_R or MOVER_R,
                KT.C_G or MOVER_G,
                KT.C_B or MOVER_B,
                1
            )
        end
    end
    
    local bgR, bgG, bgB, bgA
    if palette and palette.backgroundTint then
        bgR, bgG, bgB, bgA = palette.backgroundTint.r, palette.backgroundTint.g, palette.backgroundTint.b, palette.backgroundTint.a
    else
        bgR, bgG, bgB, bgA = ReadThemeColor(
            skin and (skin.menuBackgroundTint or skin.backgroundColor),
            SIDEBAR_BG.r,
            SIDEBAR_BG.g,
            SIDEBAR_BG.b,
            SIDEBAR_BG.a
        )
    end
    
    local textR, textG, textB, textA
    if palette and palette.text then
        textR, textG, textB, textA = palette.text.r, palette.text.g, palette.text.b, palette.text.a
    else
        textR, textG, textB, textA = ReadThemeColor(
            skin and (skin.menuTextColor or skin.headerColor),
            1,
            0.96,
            0.97,
            1
        )
    end
    local softR, softG, softB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.48)
    local hoverR, hoverG, hoverB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.28)
    local activeR, activeG, activeB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.44)
    local activeHoverR, activeHoverG, activeHoverB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.58)
    local mutedR, mutedG, mutedB = BlendThemeColor(textR, textG, textB, bgR, bgG, bgB, 0.34)
    local artR, artG, artB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.16)
    local trackR, trackG, trackB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.14)
    local trackHoverR, trackHoverG, trackHoverB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.24)

    MOVER_R, MOVER_G, MOVER_B = accentR, accentG, accentB
    SetThemeColor(SIDEBAR_BG, bgR, bgG, bgB, bgA or 0.88)
    SetThemeColor(SIDEBAR_ACCENT, accentR, accentG, accentB, accentA or 1)
    SetThemeColor(SIDEBAR_ACCENT_SOFT, softR, softG, softB, 0.95)

    return {
        accent = { r = accentR, g = accentG, b = accentB, a = accentA or 1 },
        soft = { r = softR, g = softG, b = softB, a = 0.95 },
        background = { r = bgR, g = bgG, b = bgB, a = bgA or 0.88 },
        text = { r = textR, g = textG, b = textB, a = textA or 1 },
        muted = { r = mutedR, g = mutedG, b = mutedB, a = 1 },
        hover = { r = hoverR, g = hoverG, b = hoverB, a = 1 },
        active = { r = activeR, g = activeG, b = activeB, a = 1 },
        activeHover = { r = activeHoverR, g = activeHoverG, b = activeHoverB, a = 1 },
        art = { r = artR, g = artG, b = artB, a = 1 },
        track = { r = trackR, g = trackG, b = trackB, a = 1 },
        trackHover = { r = trackHoverR, g = trackHoverG, b = trackHoverB, a = 1 },
    }
end

local function RefreshPanelButtonTheme(button)
    if not button or button._ktActionButton then return end

    local theme = GetUnlockTheme()
    if button.bgKT and not button.normalColor then
        button.bgKT:SetColorTexture(theme.background.r, theme.background.g, theme.background.b, 0.94)
    end
    if button.borderKT then
        KT:AddBorder(button, theme.soft.r, theme.soft.g, theme.soft.b, 1)
    end
    if button.text then
        button.text:SetTextColor(theme.text.r, theme.text.g, theme.text.b, theme.text.a or 1)
    end
end

local function CreateText(parent, size, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", size, "OUTLINE")
    fs:SetJustifyH(justify or "CENTER")
    fs:SetTextColor(1, 1, 1, 1)
    return fs
end

local function CreatePanelButton(parent, width, height, label)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    KT:AddBackdrop(button, 0.01, 0.01, 0.01, 0.94)
    button.text = CreateText(button, 12)
    button.text:SetAllPoints()
    button.text:SetText(label or "")
    button._ktUnlockPanelButton = true
    RefreshPanelButtonTheme(button)
    button:SetScript("OnEnter", function(self)
        if self._ktUnlockButtonStyle then
            local style = self._ktUnlockButtonStyle
            local accentHAlpha = (style.accentHAlpha or 0) + (style.hoverAccentBoost or 0.04)
            local accentVAlpha = (style.accentVAlpha or 0) + (style.hoverAccentBoost or 0.04) * 0.75
            local glossAlpha = (style.glossAlpha or 0) + (style.hoverGlossBoost or 0.04)
            if self.bgKT and self.hoverColor then
                self.bgKT:SetColorTexture(unpack(self.hoverColor))
            end
            if style.hoverBorderColor then
                KT:AddBorder(self, style.hoverBorderColor[1], style.hoverBorderColor[2], style.hoverBorderColor[3], style.hoverBorderColor[4] or 1)
            end
            ApplyUnlockSurface(self, {
                texturePath = style.texturePath,
                patternAlpha = style.patternAlpha,
                shadeAlpha = style.shadeAlpha,
                glossAlpha = glossAlpha,
                glossRatio = style.glossRatio,
                accentColor = style.accentColor,
                accentHAlpha = accentHAlpha,
                accentHRatio = style.accentHRatio,
                accentVAlpha = accentVAlpha,
                accentVRatio = style.accentVRatio,
                topLineAlpha = (style.topLineAlpha or 0) + (style.hoverTopLineBoost or 0.03),
                bottomLineAlpha = (style.bottomLineAlpha or 0) + (style.hoverBottomLineBoost or 0.02),
            })
        elseif self.bgKT and self.hoverColor then
            self.bgKT:SetColorTexture(self.hoverColor[1], self.hoverColor[2], self.hoverColor[3], self.hoverColor[4])
        end
    end)
    button:SetScript("OnLeave", function(self)
        if self._ktUnlockButtonStyle then
            local style = self._ktUnlockButtonStyle
            if self.bgKT and self.normalColor then
                self.bgKT:SetColorTexture(unpack(self.normalColor))
            end
            if style.borderColor then
                KT:AddBorder(self, style.borderColor[1], style.borderColor[2], style.borderColor[3], style.borderColor[4] or 1)
            end
            ApplyUnlockSurface(self, {
                texturePath = style.texturePath,
                patternAlpha = style.patternAlpha,
                shadeAlpha = style.shadeAlpha,
                glossAlpha = style.glossAlpha,
                glossRatio = style.glossRatio,
                accentColor = style.accentColor,
                accentHAlpha = style.accentHAlpha,
                accentHRatio = style.accentHRatio,
                accentVAlpha = style.accentVAlpha,
                accentVRatio = style.accentVRatio,
                topLineAlpha = style.topLineAlpha,
                bottomLineAlpha = style.bottomLineAlpha,
            })
        elseif self.bgKT and self.normalColor then
            self.bgKT:SetColorTexture(self.normalColor[1], self.normalColor[2], self.normalColor[3], self.normalColor[4])
        end
    end)
    return button
end

local function CreateActionButton(parent, width, height, label, kind)
    -- Botones de accion del panel: mismo estilo que el resto de menus
    -- (largo = KT.PortalButton, corto = KT.NavTabs variante "short").
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button._ktActionButton = true
    local text = button:CreateFontString(nil, "OVERLAY")
    text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    button.text = text
    local upper = KT.NavTabs and KT.NavTabs.Upper
    if upper then
        local rawSetText = text.SetText
        text.SetText = function(self, value) rawSetText(self, upper(value)) end
    end
    if kind == "short" and KT.NavTabs then
        KT.NavTabs.StyleButton(button, { text = text, fontSize = 12, variant = "short" })
    elseif KT.PortalButton then
        KT.PortalButton.Style(button, { text = text, fontSize = 12 })
    end
    text:SetText(label or "")
    return button
end

local function StyleMenuInputBox(box)
    if not box then return end

    local theme = GetUnlockTheme()
    KT:AddBackdrop(box, MENU_INPUT_BG[1], MENU_INPUT_BG[2], MENU_INPUT_BG[3], MENU_INPUT_BG[4])
    KT:AddBorder(box, theme.accent.r, theme.accent.g, theme.accent.b, 0.40)
    box:SetTextColor(MENU_TEXT[1], MENU_TEXT[2], MENU_TEXT[3], 1)
end

local function CreateMenuInputBox(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width or 54, height or 18)
    box:SetAutoFocus(false)
    box:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    box:SetJustifyH("CENTER")
    box:SetTextInsets(4, 4, 1, 1)
    box:SetMaxLetters(8)
    StyleMenuInputBox(box)
    box:SetScript("OnEditFocusGained", function(self)
        local theme = GetUnlockTheme()
        KT:AddBorder(self, theme.accent.r, theme.accent.g, theme.accent.b, 1)
        self:HighlightText()
    end)
    box:SetScript("OnEditFocusLost", function(self)
        StyleMenuInputBox(self)
    end)
    return box
end

-- Botones del menu contextual / dialogo: relleno oscuro fijo, texto claro y
-- borde accent. isActive = opcion marcada o accion principal.
local function StyleMenuButton(button, isActive)
    if not button then return end

    local theme = GetUnlockTheme()
    button._ktUnlockButtonStyle = nil
    if isActive then
        local r, g, b = BlendThemeColor(MENU_ROW[1], MENU_ROW[2], MENU_ROW[3], theme.accent.r, theme.accent.g, theme.accent.b, 0.38)
        local hr, hg, hb = BlendThemeColor(MENU_ROW[1], MENU_ROW[2], MENU_ROW[3], theme.accent.r, theme.accent.g, theme.accent.b, 0.52)
        button.normalColor = { r, g, b, 0.98 }
        button.hoverColor = { hr, hg, hb, 1 }
        button._ktMenuBorderAlpha = 0.95
    else
        button.normalColor = { MENU_ROW[1], MENU_ROW[2], MENU_ROW[3], MENU_ROW[4] }
        button.hoverColor = { MENU_ROW_HOVER[1], MENU_ROW_HOVER[2], MENU_ROW_HOVER[3], MENU_ROW_HOVER[4] }
        button._ktMenuBorderAlpha = 0.30
    end

    if button.bgKT then
        button.bgKT:SetColorTexture(unpack(button._ktMenuHovered and button.hoverColor or button.normalColor))
    end
    KT:AddBorder(button, theme.accent.r, theme.accent.g, theme.accent.b, button._ktMenuHovered and 1 or button._ktMenuBorderAlpha)
    if button.text then
        button.text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
        button.text:SetTextColor(MENU_TEXT[1], MENU_TEXT[2], MENU_TEXT[3], 1)
    end

    if not button._ktMenuHooks then
        button._ktMenuHooks = true
        button:HookScript("OnEnter", function(self)
            self._ktMenuHovered = true
            local hoverTheme = GetUnlockTheme()
            KT:AddBorder(self, hoverTheme.accent.r, hoverTheme.accent.g, hoverTheme.accent.b, 1)
        end)
        button:HookScript("OnLeave", function(self)
            self._ktMenuHovered = false
            local hoverTheme = GetUnlockTheme()
            KT:AddBorder(self, hoverTheme.accent.r, hoverTheme.accent.g, hoverTheme.accent.b, self._ktMenuBorderAlpha or 0.30)
        end)
    end
end

local function NormalizeMouseoverKey(value)
    if type(value) ~= "string" or value == "" then
        return nil
    end

    local normalized = string.lower(value)
    normalized = string.gsub(normalized, "[^%w]+", "_")
    normalized = string.gsub(normalized, "_+", "_")
    normalized = string.gsub(normalized, "^_", "")
    normalized = string.gsub(normalized, "_$", "")
    return normalized
end

local function ResolveMouseoverTargetID(key, def)
    if type(key) == "string" and MOUSEOVER_SETTING_KEYS[key] then
        return key
    end

    local normalizedKey = NormalizeMouseoverKey(key)
    if normalizedKey and MOUSEOVER_KEY_ALIASES[normalizedKey] then
        return MOUSEOVER_KEY_ALIASES[normalizedKey]
    end

    local label = def and def.label
    local normalizedLabel = NormalizeMouseoverKey(label)
    if normalizedLabel then
        if MOUSEOVER_SETTING_KEYS[normalizedLabel] then
            return normalizedLabel
        end
        if MOUSEOVER_KEY_ALIASES[normalizedLabel] then
            return MOUSEOVER_KEY_ALIASES[normalizedLabel]
        end
    end

    return nil
end

local function GetMouseoverSetting(targetID)
    local info = MOUSEOVER_SETTING_KEYS[targetID]
    if not (info and KT.db and KT.db.profile) then
        return false
    end

    local section = KT.db.profile[info.section]
    if type(section) ~= "table" then
        return false
    end

    return section[info.key] == true
end

local function SetMouseoverSetting(targetID, value)
    local info = MOUSEOVER_SETTING_KEYS[targetID]
    if not (info and KT.db and KT.db.profile) then
        return
    end

    KT.db.profile[info.section] = KT.db.profile[info.section] or {}
    KT.db.profile[info.section][info.key] = value == true
end

local function RefreshMouseoverModules(targetID)
    local info = MOUSEOVER_SETTING_KEYS[targetID]
    if not info then
        return
    end

    if info.section == "actionbars" then
        local mod = KT:GetModule("ActionBars", true)
        if mod and mod.UpdateMouseoverState then
            SafeCall(mod.UpdateMouseoverState, mod)
        end
    elseif info.section == "blizzframes" then
        local mod = KT:GetModule("BlizzardFrames", true)
        if mod and mod.UpdateMouseoverState then
            SafeCall(mod.UpdateMouseoverState, mod)
        end
    end
end

local function SetButtonAccent(button, r, g, b)
    if button and button.bgKT then
        button.bgKT:SetColorTexture(r, g, b, 0.18)
    end
    if button and button.borderKT then
        KT:AddBorder(button, r, g, b, 1)
    end
end

local function ApplySidebarPanelStyle(frame, variant)
    if not frame then
        return
    end

    local theme = GetUnlockTheme()
    local bgR, bgG, bgB = BlendThemeColor(theme.background.r, theme.background.g, theme.background.b, 0, 0, 0, 0.30)
    local borderR, borderG, borderB = 0, 0, 0
    local accentHAlpha, accentVAlpha, patternAlpha, glossAlpha, topLineAlpha = 0, 0, 0, 0, 0
    local bottomLineAlpha = 0

    if variant == "list" then
        -- no highlights
    elseif variant == "footer" then
        -- no highlights
    end

    KT:AddBackdrop(frame, 0, 0, 0, 0.40)
    KT:AddBorder(frame, borderR, borderG, borderB, 1)
    ApplyUnlockSurface(frame, {
        patternAlpha = patternAlpha,
        shadeAlpha = 0.08,
        glossAlpha = glossAlpha,
        accentHAlpha = accentHAlpha,
        accentHRatio = 0.42,
        accentVAlpha = accentVAlpha,
        accentVRatio = 0.26,
        topLineAlpha = topLineAlpha,
        bottomLineAlpha = bottomLineAlpha,
    })
    frame._ktUnlockPanelVariant = variant
end

local function StyleSidebarButton(button, variant, isActive)
    if not button or button._ktActionButton then return end

    local theme = GetUnlockTheme()
    local style
    button._ktUnlockVariant = variant

    if variant == "toggle" then
        local baseR, baseG, baseB = 0.02, 0.02, 0.025
        local hoverR, hoverG, hoverB = BlendThemeColor(baseR, baseG, baseB, theme.accent.r, theme.accent.g, theme.accent.b, 0.08)
        style = {
            normalColor = { baseR, baseG, baseB, 0.92 },
            hoverColor = { hoverR, hoverG, hoverB, 0.95 },
            borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.25 },
            hoverBorderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },
            textColor = { 1, 1, 1, 1 },
            fontSize = 12,
            patternAlpha = 0.05,
            shadeAlpha = 0.08,
            glossAlpha = 0.03,
            hoverGlossBoost = 0.02,
            accentHAlpha = 0.05,
            accentHRatio = 0.18,
            accentVAlpha = 0.03,
            accentVRatio = 0.28,
            hoverAccentBoost = 0.02,
            topLineAlpha = 0.05,
            bottomLineAlpha = 0.02,
        }
    elseif variant == "group" then
        local baseR, baseG, baseB = 0.015, 0.015, 0.02
        style = {
            normalColor = { baseR, baseG, baseB, 0.56 },
            hoverColor = { baseR, baseG, baseB, 0.56 },
            borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.15 },
            textColor = { 1, 1, 1, 1 },
            fontSize = 11,
            patternAlpha = 0.00,
            shadeAlpha = 0.02,
            glossAlpha = 0.00,
            accentHAlpha = 0.10,
            accentHRatio = 0.18,
            accentVAlpha = 0.00,
            topLineAlpha = 0.00,
            bottomLineAlpha = 0.00,
        }
    elseif variant == "item" then
        if isActive then
            local activeR, activeG, activeB = 0.03, 0.03, 0.04
            local activeHoverR, activeHoverG, activeHoverB = BlendThemeColor(activeR, activeG, activeB, theme.accent.r, theme.accent.g, theme.accent.b, 0.20)
            style = {
                normalColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.35 },
                hoverColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.45 },
                borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },
                hoverBorderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },
                textColor = { 1, 1, 1, 1 },
                fontSize = 11,
                patternAlpha = 0.04,
                shadeAlpha = 0.06,
                glossAlpha = 0.04,
                hoverGlossBoost = 0.03,
                accentHAlpha = 0.22,
                accentHRatio = 0.10,
                accentVAlpha = 0.05,
                accentVRatio = 0.20,
                hoverAccentBoost = 0.03,
                topLineAlpha = 0.08,
                bottomLineAlpha = 0.03,
            }
        else
            local baseR, baseG, baseB = 0.02, 0.02, 0.025
            local hoverR, hoverG, hoverB = BlendThemeColor(baseR, baseG, baseB, theme.accent.r, theme.accent.g, theme.accent.b, 0.06)
            style = {
                normalColor = { baseR, baseG, baseB, 0.84 },
                hoverColor = { hoverR, hoverG, hoverB, 0.90 },
                borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.15 },
                hoverBorderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },
                textColor = { 1, 1, 1, 1 },
                fontSize = 11,
                patternAlpha = 0.03,
                shadeAlpha = 0.06,
                glossAlpha = 0.02,
                hoverGlossBoost = 0.02,
                accentHAlpha = 0.04,
                accentHRatio = 0.08,
                accentVAlpha = 0.02,
                accentVRatio = 0.16,
                hoverAccentBoost = 0.02,
                topLineAlpha = 0.03,
                bottomLineAlpha = 0.02,
            }
        end
    elseif variant == "footer_red" then
        local baseR, baseG, baseB = 0.02, 0.02, 0.025
        local hoverR, hoverG, hoverB = BlendThemeColor(baseR, baseG, baseB, theme.accent.r, theme.accent.g, theme.accent.b, 0.10)
        style = {
            normalColor = { baseR, baseG, baseB, 0.90 },
            hoverColor = { hoverR, hoverG, hoverB, 0.94 },
            borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.25 },
            hoverBorderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.80 },
            textColor = { 1, 1, 1, 1 },
            fontSize = 12,
            patternAlpha = 0.04,
            shadeAlpha = 0.06,
            glossAlpha = 0.03,
            hoverGlossBoost = 0.02,
            accentHAlpha = 0.08,
            accentHRatio = 0.12,
            accentVAlpha = 0.03,
            accentVRatio = 0.20,
            hoverAccentBoost = 0.02,
            topLineAlpha = 0.05,
            bottomLineAlpha = 0.02,
        }
    elseif variant == "footer_green" then
        local baseR, baseG, baseB = 0.02, 0.02, 0.025
        local hoverR, hoverG, hoverB = BlendThemeColor(baseR, baseG, baseB, theme.accent.r, theme.accent.g, theme.accent.b, 0.10)
        style = {
            normalColor = { baseR, baseG, baseB, 0.88 },
            hoverColor = { hoverR, hoverG, hoverB, 0.92 },
            borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.25 },
            hoverBorderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },
            textColor = { 1, 1, 1, 1 },
            accentColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },
            fontSize = 12,
            patternAlpha = 0.04,
            shadeAlpha = 0.06,
            glossAlpha = 0.03,
            hoverGlossBoost = 0.02,
            accentHAlpha = 0.08,
            accentHRatio = 0.12,
            accentVAlpha = 0.03,
            accentVRatio = 0.20,
            hoverAccentBoost = 0.02,
            topLineAlpha = 0.05,
            bottomLineAlpha = 0.02,
        }
    else
        return
    end

    button._ktUnlockButtonStyle = style
    button.normalColor = style.normalColor
    button.hoverColor = style.hoverColor
    if button.bgKT then
        button.bgKT:SetColorTexture(unpack(button.normalColor))
    end
    KT:AddBorder(button, style.borderColor[1], style.borderColor[2], style.borderColor[3], style.borderColor[4] or 1)
    button.text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", style.fontSize or 11, "OUTLINE")
    button.text:SetTextColor(style.textColor[1], style.textColor[2], style.textColor[3], style.textColor[4] or 1)
    ApplyUnlockSurface(button, {
        texturePath = style.texturePath,
        patternAlpha = style.patternAlpha,
        shadeAlpha = style.shadeAlpha,
        glossAlpha = style.glossAlpha,
        glossRatio = style.glossRatio,
        accentColor = style.accentColor,
        accentHAlpha = style.accentHAlpha,
        accentHRatio = style.accentHRatio,
        accentVAlpha = style.accentVAlpha,
        accentVRatio = style.accentVRatio,
        topLineAlpha = style.topLineAlpha,
        bottomLineAlpha = style.bottomLineAlpha,
    })
end

local function SetScrollbarThumbState(sidebar, state)
    if not sidebar or not sidebar.scrollbarThumb then return end

    local theme = GetUnlockTheme()
    local thumb = sidebar.scrollbarThumb
    local thumbBorder = sidebar.scrollbarThumbBorder
    local track = sidebar.scrollbarTrack
    local thumbGlow = sidebar.scrollbarThumbGlow
    local trackLeft = sidebar.scrollbarTrackLeft
    local trackRight = sidebar.scrollbarTrackRight

    if state == "drag" then
        thumb:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
        thumb:SetAlpha(1)
        if thumbGlow then
            thumbGlow:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.28)
            thumbGlow:SetAlpha(1)
        end
        if thumbBorder then
            KT:AddBorder(thumbBorder, theme.accent.r, theme.accent.g, theme.accent.b, 1)
        end
        if track and track.bgKT then
            track.bgKT:SetColorTexture(theme.trackHover.r, theme.trackHover.g, theme.trackHover.b, 0.96)
        end
        if trackLeft then
            trackLeft:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.75)
        end
        if trackRight then
            trackRight:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.75)
        end
    elseif state == "hover" then
        thumb:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
        thumb:SetAlpha(1)
        if thumbGlow then
            thumbGlow:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.22)
            thumbGlow:SetAlpha(1)
        end
        if thumbBorder then
            KT:AddBorder(thumbBorder, theme.accent.r, theme.accent.g, theme.accent.b, 0.92)
        end
        if track and track.bgKT then
            track.bgKT:SetColorTexture(theme.trackHover.r, theme.trackHover.g, theme.trackHover.b, 0.92)
        end
        if trackLeft then
            trackLeft:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.62)
        end
        if trackRight then
            trackRight:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.62)
        end
    else
        thumb:SetVertexColor(MOVER_R, MOVER_G, MOVER_B, 0.95)
        thumb:SetAlpha(0.96)
        if thumbGlow then
            thumbGlow:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.16)
            thumbGlow:SetAlpha(1)
        end
        if thumbBorder then
            KT:AddBorder(thumbBorder, theme.accent.r, theme.accent.g, theme.accent.b, 0.82)
        end
        if track and track.bgKT then
            track.bgKT:SetColorTexture(theme.track.r, theme.track.g, theme.track.b, 0.90)
        end
        if trackLeft then
            trackLeft:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.42)
        end
        if trackRight then
            trackRight:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.42)
        end
    end
end

local function GetUIRect()
    return UIParent:GetWidth(), UIParent:GetHeight()
end

local function SetFrameTopLeft(frame, left, top)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - UIParent:GetHeight())
end

local function PointToCenter(point, x, y, width, height, uiWidth, uiHeight)
    local anchorX = 0
    local anchorY = 0

    if point == "TOPLEFT" then
        anchorX = x
        anchorY = uiHeight + y
        return anchorX + (width * 0.5), anchorY - (height * 0.5)
    elseif point == "TOP" then
        anchorX = (uiWidth * 0.5) + x
        anchorY = uiHeight + y
        return anchorX, anchorY - (height * 0.5)
    elseif point == "TOPRIGHT" then
        anchorX = uiWidth + x
        anchorY = uiHeight + y
        return anchorX - (width * 0.5), anchorY - (height * 0.5)
    elseif point == "LEFT" then
        anchorX = x
        anchorY = (uiHeight * 0.5) + y
        return anchorX + (width * 0.5), anchorY
    elseif point == "CENTER" then
        anchorX = (uiWidth * 0.5) + x
        anchorY = (uiHeight * 0.5) + y
        return anchorX, anchorY
    elseif point == "RIGHT" then
        anchorX = uiWidth + x
        anchorY = (uiHeight * 0.5) + y
        return anchorX - (width * 0.5), anchorY
    elseif point == "BOTTOMLEFT" then
        anchorX = x
        anchorY = y
        return anchorX + (width * 0.5), anchorY + (height * 0.5)
    elseif point == "BOTTOM" then
        anchorX = (uiWidth * 0.5) + x
        anchorY = y
        return anchorX, anchorY + (height * 0.5)
    elseif point == "BOTTOMRIGHT" then
        anchorX = uiWidth + x
        anchorY = y
        return anchorX - (width * 0.5), anchorY + (height * 0.5)
    end

    return (uiWidth * 0.5) + (x or 0), (uiHeight * 0.5) + (y or 0)
end

local function BoundsFromStoredPosition(pos, width, height)
    local uiWidth, uiHeight = GetUIRect()
    local point = pos.point or pos.relativePoint or "CENTER"
    local centerX, centerY = PointToCenter(point, pos.x or 0, pos.y or 0, width, height, uiWidth, uiHeight)
    return centerX - (width * 0.5), centerY + (height * 0.5), width, height
end

function UM:EnsureDB()
    if not KT.db or not KT.db.profile then return end
    KT.db.profile.editMode = KT.db.profile.editMode or {}
    KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}
    KT.db.profile.editMode.positionMeta = KT.db.profile.editMode.positionMeta or {}
    KT.db.profile.editMode.snapTargets = KT.db.profile.editMode.snapTargets or {}
    if KT.db.profile.editMode.unlockGrid == nil then KT.db.profile.editMode.unlockGrid = "dimmed" end
    if KT.db.profile.editMode.unlockSnap == nil then KT.db.profile.editMode.unlockSnap = true end
    if KT.db.profile.editMode.unlockDarkOverlays == nil then KT.db.profile.editMode.unlockDarkOverlays = true end
    if KT.db.profile.editMode.unlockCoords == nil then KT.db.profile.editMode.unlockCoords = false end
    self.db = KT.db.profile.editMode
end

function UM:OnInitialize()
    self:EnsureDB()

    self.registry = KT.UnlockElements
    self.registryOrder = {}
    self.movers = {}
    self.pendingPositions = {}
    self.snapshotPositions = {}
    self.snapshotSizes = {}
    self.snapshotSnapTargets = {}
    self.selectedKey = nil
    self.selectedKeys = {}
    self.isOpen = false
    self.isSuspended = false
    self.hasChanges = false

    self.snapshotGenericSizes = {}
    self.touchedNativeSizes = {}
end

function UM:SaveChanges()
    -- "Save" sin salir: confirma las posiciones y las toma como nueva base de Discard/ESC.
    if not self.isOpen then return end
    self:CommitPositions()
    wipe(self.snapshotPositions)
    wipe(self.snapshotSizes)
    wipe(self.snapshotSnapTargets)
    self.snapshotGenericSizes = self:CopyGenericSizes()
    wipe(self.touchedNativeSizes)
    for _, key in ipairs(self.registryOrder) do
        if not self:IsElementHidden(key) then
            self.snapshotPositions[key] = self:CaptureCurrentPosition(key)
            self.snapshotSnapTargets[key] = self:GetSnapTarget(key) or false
            if self:CanEditElementSize(key) then
                local width, height = self:GetEditableElementSize(key)
                if width and height then
                    self.snapshotSizes[key] = { width = width, height = height }
                end
            end
        end
    end
end

function UM:HasUnsavedChanges()
    return self.hasChanges == true
end

-- Aviso de cambios sin guardar. Antes era un StaticPopup: vive en la capa
-- DIALOG, por debajo del overlay FULLSCREEN_DIALOG del unlock mode, y como el
-- overlay propaga el teclado, el mismo ESC que lo abria llegaba despues al
-- binding del juego, que cierra los StaticPopup con hideOnEscape. Resultado:
-- nunca se veia. Ahora es un dialogo propio por encima de todo el unlock mode.
function UM:StyleUnsavedDialog()
    local dialog = self.unsavedDialog
    if not dialog then return end
    local theme = GetUnlockTheme()
    local box = dialog.box
    KT:AddBackdrop(box, MENU_BG[1], MENU_BG[2], MENU_BG[3], 0.98)
    KT:AddBorder(box, theme.accent.r, theme.accent.g, theme.accent.b, 0.9)
    box.topAccent:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 1)
    box.title:SetTextColor(1, 1, 1, 1)
    box.body:SetTextColor(MENU_LABEL[1], MENU_LABEL[2], MENU_LABEL[3], 1)
    box.hint:SetTextColor(MENU_HINT[1], MENU_HINT[2], MENU_HINT[3], 1)
    StyleMenuButton(box.discard)
    StyleMenuButton(box.save, true)
end

function UM:CreateUnsavedDialog()
    if self.unsavedDialog then
        return self.unsavedDialog
    end

    local parent = self.unlockFrame or UIParent
    local dialog = CreateFrame("Button", "KullThranUIUnlockModeUnsavedDialog", parent)
    dialog:SetAllPoints(UIParent)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetFrameLevel(parent:GetFrameLevel() + 400)
    dialog:SetToplevel(true)
    dialog:EnableMouse(true)
    dialog:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    dialog.shade = dialog:CreateTexture(nil, "BACKGROUND")
    dialog.shade:SetAllPoints()
    dialog.shade:SetColorTexture(0, 0, 0, 0.55)
    -- Clic fuera del cuadro = seguir editando (igual que ESC).
    dialog:SetScript("OnClick", function(widget)
        widget:Hide()
    end)

    local box = CreateFrame("Frame", nil, dialog)
    box:SetSize(360, 140)
    box:SetPoint("CENTER", UIParent, "CENTER", 0, 90)
    box:EnableMouse(true)
    dialog.box = box

    box.topAccent = box:CreateTexture(nil, "ARTWORK")
    box.topAccent:SetPoint("TOPLEFT", 1, -1)
    box.topAccent:SetPoint("TOPRIGHT", -1, -1)
    box.topAccent:SetHeight(2)

    box.title = CreateText(box, 15)
    box.title:SetPoint("TOP", 0, -18)
    box.title:SetText(LText("Unsaved Changes"))

    box.body = CreateText(box, 11)
    box.body:SetPoint("TOP", box.title, "BOTTOM", 0, -10)
    box.body:SetWidth(320)
    box.body:SetText(LText("You have unsaved position changes.") .. "\n" .. LText("What would you like to do?"))

    box.discard = CreatePanelButton(box, 156, 26, LText("Exit Without Saving"))
    box.discard:SetPoint("BOTTOMLEFT", 18, 26)
    box.discard:SetScript("OnClick", function()
        dialog:Hide()
        UM:CloseUnlockMode(false, true)
    end)

    box.save = CreatePanelButton(box, 156, 26, LText("Save & Exit"))
    box.save:SetPoint("BOTTOMRIGHT", -18, 26)
    box.save:SetScript("OnClick", function()
        dialog:Hide()
        UM:CloseUnlockMode(true, true)
    end)

    box.hint = CreateText(box, 9)
    box.hint:SetPoint("BOTTOM", 0, 9)
    box.hint:SetText(LText("ESC: keep editing"))

    dialog:Hide()
    self.unsavedDialog = dialog
    return dialog
end

function UM:PromptCloseUnlockMode()
    if not self.isOpen then return end
    if not self:HasUnsavedChanges() then
        self:CloseUnlockMode(false, true)
        return
    end

    local dialog = self:CreateUnsavedDialog()
    self:StyleUnsavedDialog()
    if self.moverMenu then
        self.moverMenu:Hide()
    end
    dialog:SetFrameLevel((self.unlockFrame and self.unlockFrame:GetFrameLevel() or 0) + 400)
    dialog:Show()
    dialog:Raise()
end

function UM:OnEnable()
    self:EnsureDB()
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")
    if not self.sizeEventFrame then
        self.sizeEventFrame = CreateFrame("Frame")
        self.sizeEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        self.sizeEventFrame:SetScript("OnEvent", function()
            C_Timer.After(2.5, function()
                if not UM.isOpen then
                    UM:ApplyAllStoredSizes()
                end
            end)
        end)
    end
    self:RegisterEvent("UI_SCALE_CHANGED", "OnUnlockDisplayScaleChanged")
    self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnUnlockDisplayScaleChanged")

    KT:RegisterChatCommand("ktunlock", function()
        self:ToggleUnlockMode()
    end)

    ns.IsUnlocked = function() return self.isOpen end
    ns.ToggleUnlockMode = function() self:ToggleUnlockMode() end
end

function UM:UpdateRegistry()
    self.registry = KT.UnlockElements or {}
    wipe(self.registryOrder)
    for key, _ in pairs(self.registry) do
        tinsert(self.registryOrder, key)
    end
    table.sort(self.registryOrder, function(a, b)
        local ea = self.registry[a] or {}
        local eb = self.registry[b] or {}
        local ga = tostring(ea.group or "Other")
        local gb = tostring(eb.group or "Other")
        if ga ~= gb then
            return ga < gb
        end
        local oa = tonumber(ea.order) or 9999
        local ob = tonumber(eb.order) or 9999
        if oa ~= ob then
            return oa < ob
        end
        return tostring(ea.label or a) < tostring(eb.label or b)
    end)

    if self.isOpen then
        self:RefreshMovers()
        self:RefreshSidebar()
    elseif self.db and type(self.db.sizes) == "table" and next(self.db.sizes) then
        self:ApplyAllStoredSizes()
    end
end

function UM:GetPositionReference()
    local width, height = GetUIRect()
    return max(tonumber(width) or 1, 1), max(tonumber(height) or 1, 1)
end

function UM:RememberPositionReference(key)
    if not key then return end
    self:EnsureDB()
    if not self.db then return end

    local width, height = self:GetPositionReference()
    self.db.positionMeta[key] = {
        width = width,
        height = height,
    }
end

function UM:NormalizePositionForCurrentUI(key, pos)
    if not pos then
        return nil, false
    end

    self:EnsureDB()
    local normalized = CopyPosition(pos)
    local meta = self.db and self.db.positionMeta and self.db.positionMeta[key]
    local oldWidth = meta and tonumber(meta.width)
    local oldHeight = meta and tonumber(meta.height)
    local width, height = self:GetPositionReference()

    if not (oldWidth and oldWidth > 0 and oldHeight and oldHeight > 0) then
        return normalized, false
    end

    local xRatio = width / oldWidth
    local yRatio = height / oldHeight
    if abs(xRatio - 1) < 0.0001 and abs(yRatio - 1) < 0.0001 then
        return normalized, false
    end

    normalized.x = (tonumber(pos.x) or 0) * xRatio
    normalized.y = (tonumber(pos.y) or 0) * yRatio
    return normalized, true
end

function UM:GetRawElementPosition(key)
    local def = self:GetElementDef(key)
    if def and type(def.loadPosition) == "function" then
        local ok, pos = SafeCall(def.loadPosition, key)
        if ok and type(pos) == "table" and pos.point then
            return CopyPosition(pos)
        end
    end

    local saved = self:GetStoredDBPosition(key)
    if saved and saved.point then
        return CopyPosition(saved)
    end
    return nil
end

function UM:PrepareElementPositionForCurrentUI(key)
    -- Opening UnlockMode must be read-only. Re-applying every element's
    -- stored position here (anchored to UIParent, without relativeTo) broke
    -- modules that own their own anchoring: Damage Meter docks, CDM bars with
    -- anchorTo, Unit Frames, Combat Timer... and rescaling + saving on open
    -- permanently cleared those docks/anchors. Only record the reference size.
    self:RememberPositionReference(key)
    return self:GetRawElementPosition(key)
end

function UM:GetStoredDBPosition(key)
    self:EnsureDB()
    return self.db and self.db.frames and self.db.frames[key]
end

function UM:SaveStoredDBPosition(key, point, relativePoint, x, y, scale)
    self:EnsureDB()
    self.db.frames[key] = self.db.frames[key] or {}
    local data = self.db.frames[key]
    data.point = point
    data.relativePoint = relativePoint
    data.x = x
    data.y = y
    if scale ~= nil then
        data.scale = scale
    end
    self:RememberPositionReference(key)
end

function UM:GetElementDef(key)
    return self.registry and self.registry[key]
end

function UM:GetElementFrame(key)
    local def = self:GetElementDef(key)
    if not def or type(def.getFrame) ~= "function" then return nil end
    local ok, frame = SafeCall(def.getFrame, key)
    if ok then
        return frame
    end
    return nil
end

function UM:GetElementScale(key)
    local def = self:GetElementDef(key)
    if not def then return 1 end
    if type(def.getScale) == "function" then
        local ok, scale = SafeCall(def.getScale, key)
        if ok and type(scale) == "number" and scale > 0 then
            return scale
        end
    end
    local frame = self:GetElementFrame(key)
    if frame and frame.GetScale then
        local scale = frame:GetScale()
        if type(scale) == "number" and scale > 0 then
            return scale
        end
    end
    return 1
end

function UM:GetElementSize(key)
    local def = self:GetElementDef(key)
    if not def then return 64, 32 end
    if type(def.getSize) == "function" then
        local ok, width, height = pcall(def.getSize, key)
        if ok and type(width) == "number" and type(height) == "number" and width > 0 and height > 0 then
            return width, height
        end
    end
    local frame = self:GetElementFrame(key)
    if frame and frame.GetWidth and frame.GetHeight then
        return max(frame:GetWidth(), 32), max(frame:GetHeight(), 24)
    end
    return 64, 32
end

function UM:IsElementHidden(key)
    local def = self:GetElementDef(key)
    if not def then return true end
    if type(def.isHidden) == "function" then
        local ok, hidden = SafeCall(def.isHidden, key)
        if ok and hidden then
            return true
        end
    end
    return false
end

function UM:LoadElementPosition(key)
    local raw = self:GetRawElementPosition(key)
    if not raw then
        return nil
    end
    return raw
end

function UM:GetElementRect(key)
    local def = self:GetElementDef(key)
    if def and type(def.getRect) == "function" then
        local ok, left, top, width, height = pcall(def.getRect, key)
        if ok and left and top and width and height then
            return left, top, width, height
        end
    end

    local frame = self:GetElementFrame(key)
    local moverScale = self:GetElementScale(key)
    local width, height
    if def and type(def.getMoverSize) == "function" then
        local ok, mw, mh = pcall(def.getMoverSize, key)
        if ok and mw and mh then
            width, height = mw, mh
        end
    end
    if not width then
        width, height = self:GetElementSize(key)
    end
    width = width * moverScale
    height = height * moverScale

    if frame and frame.GetLeft and frame.GetTop and frame:GetLeft() and frame:GetTop() then
        local uiScale = UIParent:GetEffectiveScale()
        local frameScale = frame:GetEffectiveScale()
        local left = frame:GetLeft() * frameScale / uiScale
        local top = frame:GetTop() * frameScale / uiScale
        local right = frame:GetRight() and (frame:GetRight() * frameScale / uiScale) or (left + width)
        local bottom = frame:GetBottom() and (frame:GetBottom() * frameScale / uiScale) or (top - height)
        return left, top, max(right - left, width), max(top - bottom, height)
    end

    local stored = self:LoadElementPosition(key)
    if stored then
        return BoundsFromStoredPosition(stored, width, height)
    end

    local uiWidth, uiHeight = GetUIRect()
    return (uiWidth * 0.5) - (width * 0.5), (uiHeight * 0.5) + (height * 0.5), width, height
end

function UM:CaptureCurrentPosition(key)
    local frame = self:GetElementFrame(key)
    if frame and frame.GetPoint then
        local point, relativeTo, relativePoint, x, y = frame:GetPoint()
        if point then
            return {
                point = point,
                relativeTo = relativeTo,
                relativePoint = relativePoint or point,
                x = x or 0,
                y = y or 0,
                scale = self:GetElementScale(key),
            }
        end
    end
    if frame and frame.GetLeft and frame:GetLeft() and frame:GetTop() then
        local uiScale = UIParent:GetEffectiveScale()
        local frameScale = frame:GetEffectiveScale()
        return {
            point = "TOPLEFT",
            relativePoint = "TOPLEFT",
            x = frame:GetLeft() * frameScale / uiScale * (uiScale / frameScale),
            y = (frame:GetTop() * frameScale / uiScale - UIParent:GetHeight()) * (uiScale / frameScale),
            scale = self:GetElementScale(key),
        }
    end
    local stored = self:LoadElementPosition(key)
    if stored then
        return stored
    end
    local left, top = self:GetElementRect(key)
    return {
        point = "TOPLEFT",
        relativePoint = "TOPLEFT",
        x = left,
        y = top - UIParent:GetHeight(),
        scale = self:GetElementScale(key),
    }
end

function UM:ApplyStoredPositionToElement(key, pos)
    if not pos then return end
    local def = self:GetElementDef(key)
    local frame = self:GetElementFrame(key)
    if not frame then return end

    -- El unlock mode no edita la escala: solo se reaplica si de verdad es
    -- distinta. Reaplicarla siempre (al descartar, al resetear) reescribia
    -- frameScale en los Unit Frames y pisaba el 132% de los temas.
    local currentScale = self:GetElementScale(key)
    local scaleChanged = pos.scale and abs(pos.scale - (currentScale or 1)) > 0.001
    if not scaleChanged then
        -- misma escala: nada que hacer
    elseif def and type(def.setScale) == "function" then
        SafeCall(def.setScale, key, pos.scale)
    elseif frame.SetScale then
        frame:SetScale(pos.scale)
    end

    frame:ClearAllPoints()
    frame:SetPoint(
        pos.point or "TOPLEFT",
        pos.relativeTo or UIParent,
        pos.relativePoint or pos.point or "TOPLEFT",
        pos.x or 0,
        pos.y or 0
    )
end

function UM:SaveElementPosition(key, pos)
    self:RememberPositionReference(key)
    local def = self:GetElementDef(key)
    if def and type(def.savePosition) == "function" then
        SafeCall(def.savePosition, key, pos.point, pos.relativePoint, pos.x, pos.y, pos.scale)
    else
        self:SaveStoredDBPosition(key, pos.point, pos.relativePoint, pos.x, pos.y, pos.scale)
    end
end

function UM:GetSnapTarget(key)
    self:EnsureDB()
    local target = self.db and self.db.snapTargets and self.db.snapTargets[key]
    if type(target) ~= "string" or target == "" then
        return nil
    end
    return target
end

function UM:SetSnapTarget(key, targetKey)
    self:EnsureDB()
    if not (self.db and self.db.snapTargets and key) then
        return
    end

    local currentTarget = self.db.snapTargets[key]
    if type(targetKey) ~= "string" or targetKey == "" or targetKey == key then
        self.db.snapTargets[key] = nil
        if currentTarget ~= nil then
            self.hasChanges = true
        end
        return
    end

    if currentTarget ~= targetKey then
        self.db.snapTargets[key] = targetKey
        self.hasChanges = true
    end
end

function UM:GetSnapTargetOptions(key)
    local options = {
        { value = nil, label = LText("Auto") },
    }

    for _, otherKey in ipairs(self.registryOrder or {}) do
        if otherKey ~= key and not self:IsElementHidden(otherKey) then
            local def = self:GetElementDef(otherKey)
            options[#options + 1] = {
                value = otherKey,
                label = def and (def.label or otherKey) or otherKey,
            }
        end
    end

    return options
end

function UM:GetSnapTargetLabel(key)
    local targetKey = self:GetSnapTarget(key)
    if not targetKey then
        return LText("Auto")
    end

    local def = self:GetElementDef(targetKey)
    if not def or self:IsElementHidden(targetKey) then
        return LText("Auto")
    end

    return LText(def.label or targetKey)
end

function UM:GetMoverStoredXY(key)
    local mover = self.movers and self.movers[key]
    local frame = self:GetElementFrame(key)
    if not frame then
        return 0, 0
    end

    local uiScale = UIParent:GetEffectiveScale()
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local ratio = uiScale / (frameScale > 0 and frameScale or 1)

    local left = mover and mover.GetLeft and mover:GetLeft() or nil
    local top = mover and mover.GetTop and mover:GetTop() or nil
    if left and top then
        return Round(left * ratio), Round((top - UIParent:GetHeight()) * ratio)
    end

    local pos = self.pendingPositions and self.pendingPositions[key]
    if pos then
        return Round(pos.x or 0), Round(pos.y or 0)
    end

    pos = self:CaptureCurrentPosition(key)
    if pos then
        return Round(pos.x or 0), Round(pos.y or 0)
    end

    return 0, 0
end

function UM:SetMoverStoredXY(key, x, y)
    local mover = self.movers and self.movers[key]
    local frame = self:GetElementFrame(key)
    if not (mover and frame) then
        return
    end

    local uiScale = UIParent:GetEffectiveScale()
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    local ratio = uiScale / (frameScale > 0 and frameScale or 1)
    local left = (tonumber(x) or 0) / ratio
    local top = UIParent:GetHeight() + ((tonumber(y) or 0) / ratio)

    SetFrameTopLeft(mover, left, top)
    self:ApplyMoverToElement(key, mover)
    mover:RefreshCoords()
end

function UM:HasNativeElementSize(key)
    local def = self:GetElementDef(key)
    return def
        and type(def.setEditableSize) == "function"
        and (type(def.getEditableSize) == "function" or type(def.getSize) == "function")
        and true or false
end

-- Tamano generico: los elementos sin soporte nativo
-- (setEditableSize) se redimensionan sobre su propio frame y el override se
-- guarda en editMode.sizes. Los frames protegidos (cabeceras seguras, barras
-- de accion) los recoloca su layout seguro, asi que quedan fuera.
function UM:CanUseGenericSize(key)
    local def = self:GetElementDef(key)
    if not def or def.noResize or def.disableSizeEdit then
        return false
    end
    local frame = self:GetElementFrame(key)
    if not (frame and frame.SetSize and frame.GetWidth and frame.GetHeight) then
        return false
    end
    if frame.IsProtected and frame:IsProtected() then
        return false
    end
    return true
end

function UM:CanEditElementSize(key)
    return self:HasNativeElementSize(key) or self:CanUseGenericSize(key)
end

function UM:GetGenericSizeEntry(key)
    local sizes = self.db and self.db.sizes
    local entry = type(sizes) == "table" and sizes[key] or nil
    if type(entry) == "table" and tonumber(entry.width) and tonumber(entry.height) then
        return entry
    end
    return nil
end

function UM:HasGenericSizeOverride(key)
    return (not self:HasNativeElementSize(key)) and self:GetGenericSizeEntry(key) ~= nil
end

function UM:GetEditableElementSize(key)
    local def = self:GetElementDef(key)
    if not def then
        return nil, nil
    end

    if self:HasNativeElementSize(key) then
        if type(def.getEditableSize) == "function" then
            local ok, width, height = pcall(def.getEditableSize, key)
            if ok and type(width) == "number" and type(height) == "number" then
                return Round(width), Round(height)
            end
        end

        if type(def.getSize) == "function" then
            local ok, width, height = pcall(def.getSize, key)
            if ok and type(width) == "number" and type(height) == "number" then
                return Round(width), Round(height)
            end
        end

        return nil, nil
    end

    if self:CanUseGenericSize(key) then
        local entry = self:GetGenericSizeEntry(key)
        if entry then
            return Round(entry.width), Round(entry.height)
        end
        local frame = self:GetElementFrame(key)
        local width, height = frame:GetWidth(), frame:GetHeight()
        if type(width) == "number" and type(height) == "number" then
            return Round(width), Round(height)
        end
    end

    return nil, nil
end

local function EnforceGenericSize(frame)
    if not frame or frame._ktUnlockSizing then return end
    local key = frame._ktUnlockSizeKey
    local entry = key and UM:GetGenericSizeEntry(key)
    if not entry then return end
    local width, height = frame:GetWidth(), frame:GetHeight()
    if width and height and abs(width - entry.width) < 0.5 and abs(height - entry.height) < 0.5 then
        return
    end
    frame._ktUnlockSizing = true
    frame:SetSize(entry.width, entry.height)
    frame._ktUnlockSizing = nil
end

function UM:HookGenericSize(key, frame)
    if not frame then return end
    frame._ktUnlockSizeKey = key
    if frame._ktUnlockSizeHooked then return end
    frame._ktUnlockSizeHooked = true
    -- El modulo dueno puede volver a fijar el tamano en cada refresco: el
    -- override se vuelve a imponer justo despues mientras exista.
    hooksecurefunc(frame, "SetSize", EnforceGenericSize)
    hooksecurefunc(frame, "SetWidth", EnforceGenericSize)
    hooksecurefunc(frame, "SetHeight", EnforceGenericSize)
end

function UM:ApplyGenericSize(key)
    local entry = self:GetGenericSizeEntry(key)
    if not entry or not self:CanUseGenericSize(key) then return end
    local frame = self:GetElementFrame(key)
    self:HookGenericSize(key, frame)
    frame._ktUnlockSizing = true
    frame:SetSize(entry.width, entry.height)
    frame._ktUnlockSizing = nil
end

function UM:ApplyAllStoredSizes()
    self:EnsureDB()
    local sizes = self.db and self.db.sizes
    if type(sizes) ~= "table" then return end
    for key in pairs(sizes) do
        if self:GetElementDef(key) and not self:HasNativeElementSize(key) then
            self:ApplyGenericSize(key)
        end
    end
end

function UM:CopyGenericSizes()
    local copy = {}
    local sizes = self.db and self.db.sizes
    if type(sizes) == "table" then
        for key, entry in pairs(sizes) do
            if type(entry) == "table" then
                copy[key] = {
                    width = entry.width,
                    height = entry.height,
                    origWidth = entry.origWidth,
                    origHeight = entry.origHeight,
                }
            end
        end
    end
    return copy
end

function UM:RestoreGenericSizeEntry(key, before)
    self.db.sizes = self.db.sizes or {}
    local now = self.db.sizes[key]
    if before then
        self.db.sizes[key] = {
            width = before.width,
            height = before.height,
            origWidth = before.origWidth,
            origHeight = before.origHeight,
        }
        self:ApplyGenericSize(key)
    elseif type(now) == "table" then
        self.db.sizes[key] = nil
        local frame = self:GetElementFrame(key)
        if frame and now.origWidth and now.origHeight and self:CanUseGenericSize(key) then
            frame:SetSize(now.origWidth, now.origHeight)
        end
    end
end

function UM:ResetElementSize(key)
    if not self:GetGenericSizeEntry(key) then return end
    self:RestoreGenericSizeEntry(key, nil)
    self.hasChanges = true

    local mover = self.movers and self.movers[key]
    if mover and mover.Sync then
        mover:Sync()
    end
end

function UM:SetEditableElementSize(key, width, height)
    local def = self:GetElementDef(key)
    if not def then
        return
    end

    width = tonumber(width)
    height = tonumber(height)
    if not (width and height) then
        return
    end
    width = Round(max(1, width))
    height = Round(max(1, height))

    if self:HasNativeElementSize(key) then
        local currentWidth, currentHeight = self:GetEditableElementSize(key)
        if currentWidth == width and currentHeight == height then
            return
        end
        SafeCall(def.setEditableSize, key, width, height)
        self.touchedNativeSizes[key] = true
    elseif self:CanUseGenericSize(key) then
        self:EnsureDB()
        self.db.sizes = self.db.sizes or {}
        local entry = self.db.sizes[key]
        if type(entry) ~= "table" then
            local frame = self:GetElementFrame(key)
            entry = {
                origWidth = Round(frame:GetWidth() or width),
                origHeight = Round(frame:GetHeight() or height),
            }
            self.db.sizes[key] = entry
        end
        entry.width = width
        entry.height = height
        self:ApplyGenericSize(key)
    else
        return
    end
    self.hasChanges = true

    local mover = self.movers and self.movers[key]
    if mover and mover.Sync then
        mover:Sync()
    end

    if self.moverMenu and self.moverMenu:IsShown() and self.moverMenu.activeKey == key and self.RefreshMoverMenuFields then
        self:RefreshMoverMenuFields()
    end
end

function UM:CommitPositions()
    for key, pos in pairs(self.pendingPositions) do
        self:SaveElementPosition(key, pos)
        local def = self:GetElementDef(key)
        if def and type(def.applyPosition) == "function" then
            SafeCall(def.applyPosition, key)
        end
    end
    wipe(self.pendingPositions)
    self.hasChanges = false
end

function UM:RevertPositions()
    if self.snapshotGenericSizes and self.db then
        self.db.sizes = self.db.sizes or {}
        local touched = {}
        for key in pairs(self.db.sizes) do touched[key] = true end
        for key in pairs(self.snapshotGenericSizes) do touched[key] = true end
        for key in pairs(touched) do
            if not self:HasNativeElementSize(key) then
                self:RestoreGenericSizeEntry(key, self.snapshotGenericSizes[key])
            end
        end
    end

    for key, targetKey in pairs(self.snapshotSnapTargets or {}) do
        if targetKey and targetKey ~= false then
            self.db.snapTargets[key] = targetKey
        elseif self.db and self.db.snapTargets then
            self.db.snapTargets[key] = nil
        end
    end

    -- Solo se deshacen los tamanos nativos tocados en esta sesion: reaplicarlos
    -- todos relanzaba el layout de cada modulo (Unit Frames) al descartar.
    for key, size in pairs(self.snapshotSizes or {}) do
        local def = self:GetElementDef(key)
        if self.touchedNativeSizes[key] and def and type(def.setEditableSize) == "function" and size and size.width and size.height then
            SafeCall(def.setEditableSize, key, size.width, size.height)
        end
    end

    for key, pos in pairs(self.snapshotPositions) do
        self:ApplyStoredPositionToElement(key, pos)
        local mover = self.movers[key]
        if mover then
            mover:Sync()
        end
    end
    wipe(self.pendingPositions)
    wipe(self.touchedNativeSizes)
    self.hasChanges = false
end

function UM:SelectMover(key)
    wipe(self.selectedKeys)
    if key then
        self.selectedKeys[key] = true
    end
    self.selectedKey = key
    for moverKey, mover in pairs(self.movers) do
        mover.isSelected = self.selectedKeys[moverKey] or false
        mover:RefreshStyle()
    end
    self:RefreshSidebarSelection()
end

function UM:IsMoverSelected(key)
    return key and self.selectedKeys and self.selectedKeys[key] or false
end

function UM:GetSelectedMoverKeys()
    local keys = {}
    for _, key in ipairs(self.registryOrder) do
        if self.selectedKeys and self.selectedKeys[key] then
            tinsert(keys, key)
        end
    end
    if #keys == 0 and self.selectedKey then
        tinsert(keys, self.selectedKey)
    end
    return keys
end

function UM:GetSelectedMoverCount()
    local count = 0
    if not self.selectedKeys then return count end
    for _ in pairs(self.selectedKeys) do
        count = count + 1
    end
    return count
end

function UM:ToggleMoverSelection(key)
    if not key then return end
    self.selectedKeys = self.selectedKeys or {}
    if self.selectedKeys[key] then
        self.selectedKeys[key] = nil
        if self.selectedKey == key then
            self.selectedKey = next(self.selectedKeys)
        end
    else
        self.selectedKeys[key] = true
        self.selectedKey = key
    end
    for moverKey, mover in pairs(self.movers) do
        mover.isSelected = self.selectedKeys[moverKey] or false
        mover:RefreshStyle()
    end
    self:RefreshSidebarSelection()
end

-- Lista de elementos del panel izquierdo: filas planas en vez de botones con
-- relieve. Cabecera de grupo = texto pequeno en accent con una regla; fila =
-- texto con barra de accent a la izquierda al pasar el raton o seleccionarla.
local SIDEBAR_ROW_HEIGHT = 20
local SIDEBAR_HEADER_HEIGHT = 24

local function StyleSidebarRow(row)
    if not row then return end
    local theme = GetUnlockTheme()
    local selected = row.isSelected
    local hovered = row.isHovered

    if selected then
        row.bg:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, hovered and 0.30 or 0.22)
        row.bar:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 1)
        row.bar:Show()
        row.text:SetTextColor(1, 1, 1, 1)
    elseif hovered then
        row.bg:SetColorTexture(1, 1, 1, 0.06)
        row.bar:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.55)
        row.bar:Show()
        row.text:SetTextColor(1, 1, 1, 1)
    else
        row.bg:SetColorTexture(0, 0, 0, 0)
        row.bar:Hide()
        row.text:SetTextColor(MENU_LABEL[1], MENU_LABEL[2], MENU_LABEL[3], 1)
    end
end

local function StyleSidebarHeader(header)
    if not header then return end
    local theme = GetUnlockTheme()
    header.text:SetTextColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
    ApplyTextureGradient(header.rule, "HORIZONTAL",
        theme.accent.r, theme.accent.g, theme.accent.b, 0.35,
        theme.accent.r, theme.accent.g, theme.accent.b, 0)
end

function UM:AcquireSidebarHeader(index)
    local sidebar = self.sidebar
    sidebar.headerPool = sidebar.headerPool or {}
    local header = sidebar.headerPool[index]
    if not header then
        header = CreateFrame("Frame", nil, sidebar.content)
        header:SetSize(178, SIDEBAR_HEADER_HEIGHT)
        header.text = CreateText(header, 10, "LEFT")
        header.text:SetPoint("BOTTOMLEFT", 2, 5)
        header.rule = header:CreateTexture(nil, "ARTWORK")
        header.rule:SetTexture(WHITE8X8)
        header.rule:SetHeight(1)
        header.rule:SetPoint("LEFT", header.text, "RIGHT", 6, 0)
        header.rule:SetPoint("RIGHT", header, "RIGHT", -2, 0)
        sidebar.headerPool[index] = header
    end
    return header
end

function UM:AcquireSidebarRow(index)
    local sidebar = self.sidebar
    sidebar.rowPool = sidebar.rowPool or {}
    local row = sidebar.rowPool[index]
    if not row then
        row = CreateFrame("Button", nil, sidebar.content)
        row:SetSize(178, SIDEBAR_ROW_HEIGHT)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bar = row:CreateTexture(nil, "ARTWORK")
        row.bar:SetPoint("TOPLEFT", 0, 0)
        row.bar:SetPoint("BOTTOMLEFT", 0, 0)
        row.bar:SetWidth(2)
        row.text = CreateText(row, 11, "LEFT")
        row.text:SetPoint("LEFT", 10, 0)
        row.text:SetPoint("RIGHT", -6, 0)
        row.text:SetWordWrap(false)
        row:SetScript("OnEnter", function(widget)
            widget.isHovered = true
            StyleSidebarRow(widget)
            local mover = widget.key and UM.movers and UM.movers[widget.key]
            if mover and mover.SetLocatorHover then
                mover:SetLocatorHover(true)
            end
        end)
        row:SetScript("OnLeave", function(widget)
            widget.isHovered = false
            StyleSidebarRow(widget)
            local mover = widget.key and UM.movers and UM.movers[widget.key]
            if mover and mover.SetLocatorHover then
                mover:SetLocatorHover(false)
            end
        end)
        row:SetScript("OnClick", function(widget, button)
            local key = widget.key
            if not key then return end
            if IsShiftKeyDown() then
                UM:ToggleMoverSelection(key)
            else
                UM:SelectMover(key)
            end
            local mover = UM.movers and UM.movers[key]
            if mover then
                mover:SetFrameLevel(UM.unlockFrame:GetFrameLevel() + 60)
                if mover.Locate then
                    mover:Locate()
                end
                if button == "RightButton" then
                    UM:OpenMoverMenu(key, mover)
                end
            end
        end)
        sidebar.rowPool[index] = row
    end
    return row
end

function UM:RefreshSidebarSelection()
    if not self.sidebar or not self.sidebar.itemButtons then return end
    for _, row in ipairs(self.sidebar.itemButtons) do
        if row.key then
            row.isSelected = self:IsMoverSelected(row.key) and true or false
            StyleSidebarRow(row)
        elseif row.rule then
            StyleSidebarHeader(row)
        end
    end
end

function UM:ApplyMoverToElement(key, mover)
    local def = self:GetElementDef(key)
    local frame = self:GetElementFrame(key)
    if not frame then return end
    local left = mover:GetLeft()
    local top = mover:GetTop()
    if not left or not top then return end

    local uiScale = UIParent:GetEffectiveScale()
    local frameScale = frame:GetEffectiveScale()
    local ratio = uiScale / frameScale
    local x = left * ratio
    local y = (top - UIParent:GetHeight()) * ratio

    local pos = {
        point = "TOPLEFT",
        relativePoint = "TOPLEFT",
        x = x,
        y = y,
        scale = self:GetElementScale(key),
    }

    if def and type(def.translateMoverPosition) == "function" then
        local ok, translated = pcall(def.translateMoverPosition, key, pos, mover)
        if ok and type(translated) == "table" and translated.point then
            pos = translated
        end
    end

    if def and type(def.applyPendingPosition) == "function" then
        SafeCall(def.applyPendingPosition, key, pos, mover)
    else
        frame:ClearAllPoints()
        frame:SetPoint(
            pos.point or "TOPLEFT",
            pos.relativeTo or UIParent,
            pos.relativePoint or pos.point or "TOPLEFT",
            pos.x or 0,
            pos.y or 0
        )
    end

    self.pendingPositions[key] = pos
    self.hasChanges = true

    if self.moverMenu and self.moverMenu:IsShown() and self.moverMenu.activeKey == key and self.RefreshMoverMenuFields then
        self:RefreshMoverMenuFields()
    end
end

function UM:HideGuides()
    if not self.guideVertical or not self.guideHorizontal then return end
    self.guideVertical:Hide()
    self.guideHorizontal:Hide()
end

function UM:ShowGuideVertical(x)
    local guide = self.guideVertical
    guide:ClearAllPoints()
    guide:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, 0)
    guide:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
    guide:SetWidth(1)
    guide:Show()
end

function UM:ShowGuideHorizontal(y)
    local guide = self.guideHorizontal
    guide:ClearAllPoints()
    guide:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, y)
    guide:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, y)
    guide:SetHeight(1)
    guide:Show()
end

function UM:GetSnapPosition(key, left, top, width, height)
    if not self.db.unlockSnap then
        self:HideGuides()
        return left, top
    end

    local bestX, bestY
    local bestDeltaX = SNAP_DISTANCE + 1
    local bestDeltaY = SNAP_DISTANCE + 1

    local myTargetsX = {
        left,
        left + (width * 0.5),
        left + width,
    }
    local myTargetsY = {
        top,
        top - (height * 0.5),
        top - height,
    }

    self:HideGuides()
    local function ConsiderSnapMover(mover)
        if not (mover and mover.IsShown and mover:IsShown()) then
            return
        end

        local oLeft = mover:GetLeft()
        local oTop = mover:GetTop()
        if not (oLeft and oTop) then
            return
        end

        local oWidth = mover:GetWidth()
        local oHeight = mover:GetHeight()
        local otherTargetsX = { oLeft, oLeft + (oWidth * 0.5), oLeft + oWidth }
        local otherTargetsY = { oTop, oTop - (oHeight * 0.5), oTop - oHeight }

        for _, myX in ipairs(myTargetsX) do
            for _, otherX in ipairs(otherTargetsX) do
                local delta = otherX - myX
                local deltaAbs = abs(delta)
                if deltaAbs < bestDeltaX and deltaAbs <= SNAP_DISTANCE then
                    bestDeltaX = deltaAbs
                    bestX = left + delta
                    self:ShowGuideVertical(otherX)
                end
            end
        end

        for _, myY in ipairs(myTargetsY) do
            for _, otherY in ipairs(otherTargetsY) do
                local delta = otherY - myY
                local deltaAbs = abs(delta)
                if deltaAbs < bestDeltaY and deltaAbs <= SNAP_DISTANCE then
                    bestDeltaY = deltaAbs
                    bestY = top + delta
                    self:ShowGuideHorizontal(otherY)
                end
            end
        end
    end

    local preferredTarget = self:GetSnapTarget(key)
    local preferredMover = preferredTarget and self.movers and self.movers[preferredTarget] or nil
    if preferredTarget and preferredMover and preferredMover:IsShown() then
        ConsiderSnapMover(preferredMover)
    else
        for otherKey, mover in pairs(self.movers) do
            if otherKey ~= key then
                ConsiderSnapMover(mover)
            end
        end
    end

    return bestX or left, bestY or top
end

function UM:CreateMover(key)
    local mover = CreateFrame("Button", nil, self.unlockFrame)
    mover.key = key
    mover:SetFrameStrata("FULLSCREEN_DIALOG")
    mover:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 20)
    mover:EnableMouse(true)
    mover:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    mover:SetClampedToScreen(true)

    local theme = GetUnlockTheme()
    KT:AddBackdrop(mover, 0.02, 0.02, 0.025, 0.58)
    KT:AddBorder(mover, theme.accent.r, theme.accent.g, theme.accent.b, 1)

    mover.label = CreateText(mover, 10)
    mover.label:SetPoint("CENTER")

    mover.coords = CreateText(mover, 9, "LEFT")
    mover.coords:SetPoint("TOPLEFT", 4, -4)

    mover.close = CreateFrame("Button", nil, mover)
    mover.close:SetSize(16, 16)
    mover.close:SetPoint("TOPLEFT", 3, -3)
    mover.close:RegisterForClicks("LeftButtonUp")
    KT:AddBackdrop(mover.close, 0.10, 0.05, 0.05, 0.94)
    KT:AddBorder(mover.close, 0.32, 0.14, 0.14, 1)
    mover.close.text = CreateText(mover.close, 10)
    mover.close.text:SetPoint("CENTER")
    mover.close.text:SetText(LText("X"))
    mover.close.text:SetTextColor(1, 0.82, 0.82, 1)
    mover.close:SetScript("OnEnter", function(widget)
        KT:AddBorder(widget, 0.90, 0.28, 0.28, 1)
    end)
    mover.close:SetScript("OnLeave", function(widget)
        KT:AddBorder(widget, 0.32, 0.14, 0.14, 1)
    end)
    mover.close:SetScript("OnClick", function()
        self:SelectMover(key)
        local def = self:GetElementDef(key)
        if def and type(def.unlockClose) == "function" then
            SafeCall(def.unlockClose, key, mover)
            mover:Sync()
        end
    end)
    mover.close:Hide()

    mover.cog = CreateFrame("Button", nil, mover)
    mover.cog:SetSize(16, 16)
    mover.cog:SetPoint("TOPRIGHT", -3, -3)
    mover.cog.icon = mover.cog:CreateTexture(nil, "ARTWORK")
    mover.cog.icon:SetSize(16, 12)
    mover.cog.icon:SetPoint("CENTER")
    mover.cog.icon:SetTexture(ICON_COG)
    mover.cog.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    mover.cog.icon:SetVertexColor(1, 0.9, 0.9, 1)

    mover.hoverGlow = {}
    for index = 1, 4 do
        local edge = mover:CreateTexture(nil, "ARTWORK", nil, 6)
        edge:SetTexture(WHITE8X8)
        edge:Hide()
        mover.hoverGlow[index] = edge
    end

    -- Accent wash that fades in with the hover.
    mover.hoverTint = mover:CreateTexture(nil, "BACKGROUND", nil, 3)
    mover.hoverTint:SetAllPoints()
    mover.hoverTint:SetTexture(WHITE8X8)
    mover.hoverTint:Hide()

    -- Light sweep that crosses the element once when the cursor enters.
    mover.sheenClip = CreateFrame("Frame", nil, mover)
    mover.sheenClip:SetAllPoints()
    mover.sheenClip:SetClipsChildren(true)
    mover.sheenHolder = CreateFrame("Frame", nil, mover.sheenClip)
    mover.sheenHolder:SetSize(44, 10)
    mover.sheenHolder:Hide()
    mover.sheenA = mover.sheenHolder:CreateTexture(nil, "OVERLAY")
    mover.sheenA:SetTexture(WHITE8X8)
    mover.sheenA:SetPoint("TOPLEFT")
    mover.sheenA:SetPoint("BOTTOMLEFT")
    mover.sheenA:SetWidth(22)
    mover.sheenB = mover.sheenHolder:CreateTexture(nil, "OVERLAY")
    mover.sheenB:SetTexture(WHITE8X8)
    mover.sheenB:SetPoint("TOPRIGHT")
    mover.sheenB:SetPoint("BOTTOMRIGHT")
    mover.sheenB:SetWidth(22)
    mover.sheenAnimator = CreateFrame("Frame", nil, mover)

    -- Ripple + flash played on click.
    mover.pulseEdges = {}
    for index = 1, 4 do
        local edge = mover:CreateTexture(nil, "OVERLAY", nil, 6)
        edge:SetTexture(WHITE8X8)
        edge:Hide()
        mover.pulseEdges[index] = edge
    end
    mover.pulseFlash = mover:CreateTexture(nil, "ARTWORK", nil, 6)
    mover.pulseFlash:SetAllPoints()
    mover.pulseFlash:SetTexture(WHITE8X8)
    mover.pulseFlash:Hide()
    mover.pulseAnimator = CreateFrame("Frame", nil, mover)

    -- Soft breathing outline while the element is selected.
    mover.selEdges = {}
    for index = 1, 4 do
        local edge = mover:CreateTexture(nil, "OVERLAY", nil, 5)
        edge:SetTexture(WHITE8X8)
        edge:Hide()
        mover.selEdges[index] = edge
    end
    mover.selAnimator = CreateFrame("Frame", nil, mover)

    mover.hoverAnimator = CreateFrame("Frame", nil, mover)
    mover.hoverProgress = 0
    mover.hoverTarget = 0
    mover.isHovered = false

    mover.ApplyHoverVisual = function(s, progress)
        progress = max(0, min(progress or 0, 1))
        s.hoverProgress = progress

        -- smootherstep: no velocity jump at either end, so enter/leave feel soft.
        local eased = progress * progress * progress * (progress * ((progress * 6) - 15) + 10)
        local borderR = MOVER_R + ((1 - MOVER_R) * eased)
        local borderG = MOVER_G + ((1 - MOVER_G) * eased)
        local borderB = MOVER_B + ((1 - MOVER_B) * eased)
        local idleBorderAlpha = s.isSelected and 1 or 0.85
        local borderAlpha = idleBorderAlpha + ((1 - idleBorderAlpha) * eased)

        if s.borderKT and s.borderKT._edges then
            for _, edge in ipairs(s.borderKT._edges) do
                edge:SetColorTexture(borderR, borderG, borderB, borderAlpha)
            end
        end

        if s.bgKT then
            -- Overlays mas opacos: el contenido del juego ya no se come la
            -- etiqueta del elemento ni hace dificil ver sus limites.
            if self.db.unlockDarkOverlays then
                local baseAlpha = s.isSelected and 0.66 or 0.58
                s.bgKT:SetColorTexture(
                    0.02 + (0.04 * eased),
                    0.02 + (0.04 * eased),
                    0.025 + (0.045 * eased),
                    baseAlpha + ((0.74 - baseAlpha) * eased)
                )
            else
                local baseAlpha = s.isSelected and 0.30 or 0.22
                s.bgKT:SetColorTexture(0.03 * eased, 0.03 * eased, 0.03 * eased, baseAlpha + ((0.34 - baseAlpha) * eased))
            end
        end

        if s.hoverTint then
            if eased > 0.01 then
                local tintTheme = GetUnlockTheme()
                s.hoverTint:SetVertexColor(tintTheme.accent.r, tintTheme.accent.g, tintTheme.accent.b, 0.16 * eased)
                s.hoverTint:Show()
            else
                s.hoverTint:Hide()
            end
        end

        s.label:ClearAllPoints()
        s.label:SetPoint("CENTER", s, "CENTER", 0, -4 * eased)
        local idleText = s.isSelected and 0.95 or 0.85
        local textValue = idleText + ((1 - idleText) * eased)
        s.label:SetTextColor(1, textValue, textValue, 1)

        local persistentCoords = self.db.unlockCoords or s.isSelected or s.isDragging
        if persistentCoords or progress > 0.01 then
            s.coords:Show()
            s.coords:SetAlpha(persistentCoords and 1 or eased)
        else
            s.coords:Hide()
        end

        if s.cog then
            s.cog:SetAlpha(0.35 + (0.65 * eased))
            if s.cog.icon then
                local themeNow = GetUnlockTheme()
                local iconR = themeNow.accent.r + ((1 - themeNow.accent.r) * eased)
                local iconG = themeNow.accent.g + ((1 - themeNow.accent.g) * eased)
                local iconB = themeNow.accent.b + ((1 - themeNow.accent.b) * eased)
                s.cog.icon:SetVertexColor(iconR, iconG, iconB, 1)
            end
        end

        local glow = s.hoverGlow
        if glow and progress > 0.01 then
            local extent = 1 + (MOVER_HOVER_EXPANSION * eased)
            local glowAlpha = 0.42 * (1 - ((1 - eased) * (1 - eased)))
            local thickness = 1

            glow[1]:ClearAllPoints()
            glow[1]:SetPoint("BOTTOMLEFT", s, "TOPLEFT", -extent, extent)
            glow[1]:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", extent, extent)
            glow[1]:SetHeight(thickness)

            glow[2]:ClearAllPoints()
            glow[2]:SetPoint("TOPLEFT", s, "BOTTOMLEFT", -extent, -extent)
            glow[2]:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", extent, -extent)
            glow[2]:SetHeight(thickness)

            glow[3]:ClearAllPoints()
            glow[3]:SetPoint("TOPRIGHT", s, "TOPLEFT", -extent, extent)
            glow[3]:SetPoint("BOTTOMRIGHT", s, "BOTTOMLEFT", -extent, -extent)
            glow[3]:SetWidth(thickness)

            glow[4]:ClearAllPoints()
            glow[4]:SetPoint("TOPLEFT", s, "TOPRIGHT", extent, extent)
            glow[4]:SetPoint("BOTTOMLEFT", s, "BOTTOMRIGHT", extent, -extent)
            glow[4]:SetWidth(thickness)

            for _, edge in ipairs(glow) do
                edge:SetColorTexture(borderR, borderG, borderB, glowAlpha)
                edge:Show()
            end
        elseif glow then
            for _, edge in ipairs(glow) do
                edge:Hide()
            end
        end
    end

    -- Localizador: resalta el elemento al pasar el raton por su fila del
    -- panel izquierdo y parpadea al pulsarla, para encontrarlo en pantalla.
    mover.locatorEdges = {}
    for index = 1, 4 do
        local edge = mover:CreateTexture(nil, "OVERLAY", nil, 7)
        edge:SetTexture(WHITE8X8)
        edge:Hide()
        mover.locatorEdges[index] = edge
    end
    mover.locatorFill = mover:CreateTexture(nil, "ARTWORK", nil, 7)
    mover.locatorFill:SetAllPoints()
    mover.locatorFill:SetTexture(WHITE8X8)
    mover.locatorFill:Hide()
    mover.locatorAnimator = CreateFrame("Frame", nil, mover)

    mover.UpdateLocator = function(s, wave)
        local strength = 0
        if wave then
            strength = 0.30 + (0.70 * wave)
        elseif s.locatorHover then
            strength = 0.85
        end

        local edges = s.locatorEdges
        if strength <= 0 then
            for _, edge in ipairs(edges) do
                edge:Hide()
            end
            s.locatorFill:Hide()
            return
        end

        local themeNow = GetUnlockTheme()
        local r, g, b = themeNow.accent.r, themeNow.accent.g, themeNow.accent.b
        local extent = 3
        local thickness = 2

        edges[1]:ClearAllPoints()
        edges[1]:SetPoint("BOTTOMLEFT", s, "TOPLEFT", -extent, extent - thickness)
        edges[1]:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", extent, extent - thickness)
        edges[1]:SetHeight(thickness)

        edges[2]:ClearAllPoints()
        edges[2]:SetPoint("TOPLEFT", s, "BOTTOMLEFT", -extent, -extent + thickness)
        edges[2]:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", extent, -extent + thickness)
        edges[2]:SetHeight(thickness)

        edges[3]:ClearAllPoints()
        edges[3]:SetPoint("TOPRIGHT", s, "TOPLEFT", -extent + thickness, extent)
        edges[3]:SetPoint("BOTTOMRIGHT", s, "BOTTOMLEFT", -extent + thickness, -extent)
        edges[3]:SetWidth(thickness)

        edges[4]:ClearAllPoints()
        edges[4]:SetPoint("TOPLEFT", s, "TOPRIGHT", extent - thickness, extent)
        edges[4]:SetPoint("BOTTOMLEFT", s, "BOTTOMRIGHT", extent - thickness, -extent)
        edges[4]:SetWidth(thickness)

        for _, edge in ipairs(edges) do
            edge:SetVertexColor(r, g, b, strength)
            edge:Show()
        end
        s.locatorFill:SetVertexColor(r, g, b, 0.22 * strength)
        s.locatorFill:Show()
    end

    mover.SetLocatorHover = function(s, enabled)
        s.locatorHover = enabled and true or false
        if enabled then
            s:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 60)
        end
        if not s.locatorElapsed then
            s:UpdateLocator()
        end
    end

    mover.StopLocator = function(s)
        s.locatorAnimator:SetScript("OnUpdate", nil)
        s.locatorElapsed = nil
        s.locatorHover = false
        s:UpdateLocator()
    end

    mover.Locate = function(s)
        local duration = 1.6
        local period = 0.4
        s.locatorElapsed = 0
        s.locatorAnimator:SetScript("OnUpdate", function(animator, elapsed)
            s.locatorElapsed = (s.locatorElapsed or 0) + elapsed
            if s.locatorElapsed >= duration then
                animator:SetScript("OnUpdate", nil)
                s.locatorElapsed = nil
                s:UpdateLocator()
                return
            end
            local wave = 0.5 + (0.5 * math.cos(s.locatorElapsed * math.pi * 2 / period))
            s:UpdateLocator(wave)
        end)
        s:UpdateLocator(1)
    end

    mover.PlaySheen = function(s)
        local width = s:GetWidth() or 0
        if width < 60 then return end
        local themeNow = GetUnlockTheme()
        local r, g, b = themeNow.accent.r, themeNow.accent.g, themeNow.accent.b
        ApplyTextureGradient(s.sheenA, "HORIZONTAL", r, g, b, 0, 1, 1, 1, 0.22)
        ApplyTextureGradient(s.sheenB, "HORIZONTAL", 1, 1, 1, 0.22, r, g, b, 0)
        s.sheenHolder:SetHeight(max(s:GetHeight() or 0, 1))
        s.sheenElapsed = 0
        s.sheenHolder:Show()
        s.sheenAnimator:SetScript("OnUpdate", function(animator, elapsed)
            s.sheenElapsed = s.sheenElapsed + elapsed
            local t = s.sheenElapsed / MOVER_SHEEN_DURATION
            if t >= 1 then
                animator:SetScript("OnUpdate", nil)
                s.sheenHolder:Hide()
                return
            end
            local out = 1 - ((1 - t) * (1 - t))
            local w = s:GetWidth() or width
            s.sheenHolder:ClearAllPoints()
            s.sheenHolder:SetPoint("LEFT", s.sheenClip, "LEFT", -44 + ((w + 44) * out), 0)
        end)
    end

    mover.PlayClickPulse = function(s)
        s.pulseElapsed = 0
        s.pulseAnimator:SetScript("OnUpdate", function(animator, elapsed)
            s.pulseElapsed = (s.pulseElapsed or 0) + elapsed
            local t = s.pulseElapsed / MOVER_CLICK_DURATION
            local edges = s.pulseEdges
            if t >= 1 then
                animator:SetScript("OnUpdate", nil)
                s.pulseElapsed = nil
                for _, edge in ipairs(edges) do edge:Hide() end
                s.pulseFlash:Hide()
                return
            end
            local out = 1 - ((1 - t) * (1 - t) * (1 - t))
            local fade = (1 - t) * (1 - t)
            local themeNow = GetUnlockTheme()
            local r, g, b = themeNow.accent.r, themeNow.accent.g, themeNow.accent.b
            local extent = 2 + (20 * out)
            local thickness = max(1, 3 - (2 * t))

            edges[1]:ClearAllPoints()
            edges[1]:SetPoint("BOTTOMLEFT", s, "TOPLEFT", -extent, extent)
            edges[1]:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", extent, extent)
            edges[1]:SetHeight(thickness)
            edges[2]:ClearAllPoints()
            edges[2]:SetPoint("TOPLEFT", s, "BOTTOMLEFT", -extent, -extent)
            edges[2]:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", extent, -extent)
            edges[2]:SetHeight(thickness)
            edges[3]:ClearAllPoints()
            edges[3]:SetPoint("TOPRIGHT", s, "TOPLEFT", -extent, extent)
            edges[3]:SetPoint("BOTTOMRIGHT", s, "BOTTOMLEFT", -extent, -extent)
            edges[3]:SetWidth(thickness)
            edges[4]:ClearAllPoints()
            edges[4]:SetPoint("TOPLEFT", s, "TOPRIGHT", extent, extent)
            edges[4]:SetPoint("BOTTOMLEFT", s, "BOTTOMRIGHT", extent, -extent)
            edges[4]:SetWidth(thickness)
            for _, edge in ipairs(edges) do
                edge:SetColorTexture(r, g, b, 0.9 * fade)
                edge:Show()
            end
            s.pulseFlash:SetColorTexture(r, g, b, 0.34 * fade)
            s.pulseFlash:Show()
        end)
    end

    mover.UpdateSelectedGlow = function(s)
        local edges = s.selEdges
        if not (s.isSelected and not s.isDragging and s:IsShown()) then
            s.selActive = false
            s.selAnimator:SetScript("OnUpdate", nil)
            for _, edge in ipairs(edges) do edge:Hide() end
            return
        end
        if s.selActive then return end
        s.selActive = true
        s.selPhase = 0
        local extent = 3
        edges[1]:ClearAllPoints()
        edges[1]:SetPoint("BOTTOMLEFT", s, "TOPLEFT", -extent, extent - 1)
        edges[1]:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", extent, extent - 1)
        edges[1]:SetHeight(1)
        edges[2]:ClearAllPoints()
        edges[2]:SetPoint("TOPLEFT", s, "BOTTOMLEFT", -extent, -extent + 1)
        edges[2]:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", extent, -extent + 1)
        edges[2]:SetHeight(1)
        edges[3]:ClearAllPoints()
        edges[3]:SetPoint("TOPRIGHT", s, "TOPLEFT", -extent + 1, extent)
        edges[3]:SetPoint("BOTTOMRIGHT", s, "BOTTOMLEFT", -extent + 1, -extent)
        edges[3]:SetWidth(1)
        edges[4]:ClearAllPoints()
        edges[4]:SetPoint("TOPLEFT", s, "TOPRIGHT", extent - 1, extent)
        edges[4]:SetPoint("BOTTOMLEFT", s, "BOTTOMRIGHT", extent - 1, -extent)
        edges[4]:SetWidth(1)
        s.selAnimator:SetScript("OnUpdate", function(_, elapsed)
            s.selPhase = (s.selPhase or 0) + elapsed
            local themeNow = GetUnlockTheme()
            local alpha = 0.32 + (0.28 * (0.5 + (0.5 * math.sin(s.selPhase * 2.6))))
            for _, edge in ipairs(edges) do
                edge:SetColorTexture(themeNow.accent.r, themeNow.accent.g, themeNow.accent.b, alpha)
                edge:Show()
            end
        end)
    end

    mover.SetHoverTarget = function(s, target)
        if target and s.hoverTarget ~= 1 and s.hoverProgress < 0.25 then
            s:PlaySheen()
        end
        s.hoverTarget = target and 1 or 0
        if abs(s.hoverProgress - s.hoverTarget) < 0.001 then
            s.hoverProgress = s.hoverTarget
            s.hoverAnimator:SetScript("OnUpdate", nil)
            s:ApplyHoverVisual(s.hoverProgress)
            return
        end

        s.hoverAnimator:SetScript("OnUpdate", function(animator, elapsed)
            local direction = s.hoverTarget > s.hoverProgress and 1 or -1
            s.hoverProgress = s.hoverProgress + (direction * elapsed / MOVER_HOVER_DURATION)
            if (direction > 0 and s.hoverProgress >= s.hoverTarget)
                or (direction < 0 and s.hoverProgress <= s.hoverTarget) then
                s.hoverProgress = s.hoverTarget
                animator:SetScript("OnUpdate", nil)
            end
            s:ApplyHoverVisual(s.hoverProgress)
        end)
    end

    mover.ResetHoverAnimation = function(s)
        s.isHovered = false
        s.hoverTarget = 0
        s.hoverProgress = 0
        s.hoverAnimator:SetScript("OnUpdate", nil)
        s:ApplyHoverVisual(0)
    end

    mover.RefreshCoords = function(s)
        local pos = self.pendingPositions[s.key]
        if not pos then
            pos = self:CaptureCurrentPosition(s.key)
        end
        s.coords:ClearAllPoints()
        s.coords:SetPoint("TOPLEFT", (s.close and s.close:IsShown()) and 24 or 4, -4)
        s.coords:SetText(string.format("%d, %d", Round(pos.x or 0), Round(pos.y or 0)))
        if self.db.unlockCoords or s.isSelected or s.isDragging or s.isHovered then
            s.coords:Show()
        else
            s.coords:Hide()
        end
    end

    mover.RefreshStyle = function(s)
        s:ApplyHoverVisual(s.hoverProgress or 0)
        s:RefreshCoords()
        s:UpdateSelectedGlow()
    end

    mover.Sync = function(s)
        local def = self:GetElementDef(s.key)
        local left, top, width, height = self:GetElementRect(s.key)
        s:SetSize(max(width, 32), max(height, 24))
        SetFrameTopLeft(s, left, top)
        s.label:SetText(LText(def and (def.label or s.key) or s.key))
        if s.close then
            if def and type(def.unlockClose) == "function" then
                s.close:Show()
            else
                s.close:Hide()
            end
        end
        s:RefreshStyle()
    end

    mover:SetScript("OnMouseDown", function(s, button)
        if button ~= "LeftButton" then return end
        if InCombatLockdown() then return end
        if IsShiftKeyDown() then
            if not self:IsMoverSelected(s.key) then
                self:ToggleMoverSelection(s.key)
            end
        else
            -- A normal drag must never inherit a stale multi-selection. This
            -- is especially important for Damage Meter windows: touching one
            -- of them while moving an unrelated element clears its dock and
            -- permanently changes the saved layout. Keep group dragging an
            -- explicit Shift action from the start of the drag.
            self:SelectMover(s.key)
        end
        s.isDragging = true
        s:PlayClickPulse()
        local scale = UIParent:GetEffectiveScale()
        s.dragStartX, s.dragStartY = GetCursorPosition()
        s.dragStartX = s.dragStartX / scale
        s.dragStartY = s.dragStartY / scale
        s.dragLeft = s:GetLeft() or 0
        s.dragTop = s:GetTop() or 0
        s.dragMembers = {}
        for _, dragKey in ipairs(self:GetSelectedMoverKeys()) do
            local dragMover = self.movers[dragKey]
            if dragMover then
                dragMover.isDragging = true
                tinsert(s.dragMembers, {
                    key = dragKey,
                    mover = dragMover,
                    left = dragMover:GetLeft() or 0,
                    top = dragMover:GetTop() or 0,
                })
            end
        end
        s:SetScript("OnUpdate", function(btn)
            local cursorX, cursorY = GetCursorPosition()
            cursorX = cursorX / scale
            cursorY = cursorY / scale
            local width = btn:GetWidth()
            local height = btn:GetHeight()
            local nextLeft = btn.dragLeft + (cursorX - btn.dragStartX)
            local nextTop = btn.dragTop + (cursorY - btn.dragStartY)
            nextLeft, nextTop = self:GetSnapPosition(btn.key, nextLeft, nextTop, width, height)
            local deltaLeft = nextLeft - btn.dragLeft
            local deltaTop = nextTop - btn.dragTop
            for _, member in ipairs(btn.dragMembers or EMPTY) do
                local memberMover = member.mover
                local memberLeft = member.left + deltaLeft
                local memberTop = member.top + deltaTop
                SetFrameTopLeft(memberMover, memberLeft, memberTop)
                self:ApplyMoverToElement(member.key, memberMover)
                memberMover:RefreshCoords()
            end
        end)
        s:RefreshStyle()
    end)

    mover:SetScript("OnMouseUp", function(s, button)
        if button == "RightButton" then
            s:PlayClickPulse()
            self:OpenMoverMenu(s.key, s)
            return
        end
        s.isDragging = false
        s:SetScript("OnUpdate", nil)
        self:HideGuides()
        for _, member in ipairs(s.dragMembers or EMPTY) do
            member.mover.isDragging = false
            member.mover:RefreshStyle()
        end
        s.dragMembers = nil
        s:RefreshStyle()
    end)

    mover:SetScript("OnEnter", function(s)
        s.isHovered = true
        s:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 80)
        s:SetHoverTarget(true)
    end)

    mover:SetScript("OnLeave", function(s)
        s.isHovered = false
        s:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 20)
        s:SetHoverTarget(false)
    end)

    mover:SetScript("OnHide", function(s)
        s:ResetHoverAnimation()
        s:StopLocator()
        s.pulseAnimator:SetScript("OnUpdate", nil)
        s.sheenAnimator:SetScript("OnUpdate", nil)
        s.sheenHolder:Hide()
        s.pulseFlash:Hide()
        for _, edge in ipairs(s.pulseEdges) do edge:Hide() end
        s:UpdateSelectedGlow()
    end)

    mover.cog:SetScript("OnClick", function()
        self:SelectMover(key)
        
        -- Special handling for Unit Frames: open options directly
        if key and type(key) == "string" and key:match("^unitframes_") then
            local frameType = key:gsub("^unitframes_", "")
            -- Map frame types to option page IDs
            local pageMap = {
                player = "player",
                pet = "player",
                target = "target",
                targettarget = "target",
                focus = "target",
                focustarget = "target",
                boss = "boss",
                boss1 = "boss",
                boss2 = "boss",
                boss3 = "boss",
                boss4 = "boss",
                boss5 = "boss",
            }
            local pageId = pageMap[frameType]
            if pageId and KT and KT.OpenMainMenu then
                KT:OpenMainMenu()
                C_Timer.After(0.1, function()
                    if KT.MenuPrincipal and KT.MenuPrincipal.NavigateToPage then
                        KT.MenuPrincipal:NavigateToPage("unitframes")
                        -- Give time for page to load, then switch tab
                        C_Timer.After(0.05, function()
                            if KT.MenuPrincipal and KT.MenuPrincipal.activePageContext 
                                and KT.MenuPrincipal.activePageContext.SwitchTab then
                                KT.MenuPrincipal.activePageContext:SwitchTab(pageId)
                            end
                        end)
                    end
                end)
                return
            end
        end
        
        -- Default behavior: open mover menu
        self:OpenMoverMenu(key, mover)
    end)

    self.movers[key] = mover
    return mover
end

function UM:CenterMover(key)
    local mover = self.movers[key]
    if not mover then return end
    local uiWidth, uiHeight = GetUIRect()
    local left = (uiWidth * 0.5) - (mover:GetWidth() * 0.5)
    local top = (uiHeight * 0.5) + (mover:GetHeight() * 0.5)
    SetFrameTopLeft(mover, left, top)
    self:ApplyMoverToElement(key, mover)
    mover:RefreshCoords()
end

function UM:ResetMover(key)
    local mover = self.movers[key]
    if not mover then return end

    local def = self:GetElementDef(key)
    local handled = false

    -- Elements that persist into their own module store (Unit Frames) expose a
    -- resetPosition hook: it drops the user override and re-applies the shipped
    -- default. Reading loadPosition alone would just return that same override.
    if def and type(def.resetPosition) == "function" then
        local ok, result = SafeCall(def.resetPosition, key)
        handled = (ok ~= false and result ~= false)
    end

    if not handled then
        local snapshot = self.snapshotPositions[key]
        if snapshot then
            self:ApplyStoredPositionToElement(key, snapshot)
        end
    end

    mover:Sync()
    self.pendingPositions[key] = nil
    -- Un reset nativo ya ha escrito en el store del modulo: cuenta como cambio
    -- para que el aviso de salida no lo pierda. Tampoco se pisan cambios de
    -- tamano o de snap hechos antes sobre otros elementos.
    if handled then
        self.hasChanges = true
    elseif next(self.pendingPositions) ~= nil then
        self.hasChanges = true
    end

    if self.BackupPersistedPositionsToGlobal then
        self:BackupPersistedPositionsToGlobal()
    end
    if self.moverMenu and self.moverMenu:IsShown() and self.moverMenu.activeKey == key and self.RefreshMoverMenuFields then
        self:RefreshMoverMenuFields()
    end
end

-- ---------------------------------------------------------------------------
-- Menu de clic derecho: tamano, posicion relativa a un
-- punto de la pantalla, anclaje a otro elemento con offsets y ancho extra.
-- Cada valor se edita con slider + caja numerica.
-- ---------------------------------------------------------------------------
local RELATIVE_POINTS = {
    { value = "TOPLEFT", label = "Top Left" },
    { value = "TOP", label = "Top" },
    { value = "TOPRIGHT", label = "Top Right" },
    { value = "LEFT", label = "Left" },
    { value = "CENTER", label = "Center" },
    { value = "RIGHT", label = "Right" },
    { value = "BOTTOMLEFT", label = "Bottom Left" },
    { value = "BOTTOM", label = "Bottom" },
    { value = "BOTTOMRIGHT", label = "Bottom Right" },
}

-- Fraccion horizontal / vertical de un punto de anclaje (0 = izquierda/abajo).
local function PointFractions(point)
    point = point or "CENTER"
    local fx = point:find("LEFT") and 0 or (point:find("RIGHT") and 1 or 0.5)
    local fy = point:find("BOTTOM") and 0 or (point:find("TOP") and 1 or 0.5)
    return fx, fy
end

function UM:GetMenuRelativePoint()
    local point = self.db and self.db.unlockRelativePoint
    for _, option in ipairs(RELATIVE_POINTS) do
        if option.value == point then
            return point, option.label
        end
    end
    return "CENTER", "Center"
end

-- X/Y del elemento medidos desde el punto elegido de la pantalla hasta el
-- mismo punto del elemento, en pixeles de UIParent.
function UM:GetRelativeXY(key)
    local mover = self.movers and self.movers[key]
    local left, top = mover and mover:GetLeft(), mover and mover:GetTop()
    if not (left and top) then
        return 0, 0
    end
    local uiWidth, uiHeight = GetUIRect()
    local fx, fy = PointFractions(self:GetMenuRelativePoint())
    local width, height = mover:GetWidth(), mover:GetHeight()
    local x = (left + (width * fx)) - (uiWidth * fx)
    local y = ((top - height) + (height * fy)) - (uiHeight * fy)
    return Round(x), Round(y)
end

function UM:SetRelativeXY(key, x, y)
    local mover = self.movers and self.movers[key]
    if not mover then return end
    local uiWidth, uiHeight = GetUIRect()
    local fx, fy = PointFractions(self:GetMenuRelativePoint())
    local width, height = mover:GetWidth(), mover:GetHeight()
    local left = (tonumber(x) or 0) + (uiWidth * fx) - (width * fx)
    local bottom = (tonumber(y) or 0) + (uiHeight * fy) - (height * fy)
    SetFrameTopLeft(mover, left, bottom + height)
    self:ApplyMoverToElement(key, mover)
    mover:RefreshCoords()
end

-- Offset respecto al elemento elegido como anclaje ("Snap Target"): distancia
-- entre las esquinas superiores izquierdas de ambos movers.
function UM:GetSnapOffset(key)
    local targetKey = self:GetSnapTarget(key)
    local mover = self.movers and self.movers[key]
    local targetMover = targetKey and self.movers and self.movers[targetKey]
    if not (mover and targetMover and targetMover:IsShown()) then
        return nil, nil
    end
    local left, top = mover:GetLeft(), mover:GetTop()
    local targetLeft, targetTop = targetMover:GetLeft(), targetMover:GetTop()
    if not (left and top and targetLeft and targetTop) then
        return nil, nil
    end
    return Round(left - targetLeft), Round(top - targetTop)
end

function UM:SetSnapOffset(key, offsetX, offsetY)
    local targetKey = self:GetSnapTarget(key)
    local mover = self.movers and self.movers[key]
    local targetMover = targetKey and self.movers and self.movers[targetKey]
    if not (mover and targetMover) then return end
    local targetLeft, targetTop = targetMover:GetLeft(), targetMover:GetTop()
    if not (targetLeft and targetTop) then return end
    SetFrameTopLeft(mover, targetLeft + (tonumber(offsetX) or 0), targetTop + (tonumber(offsetY) or 0))
    self:ApplyMoverToElement(key, mover)
    mover:RefreshCoords()
end

-- Ancho extra: diferencia de ancho (en pixeles de pantalla) entre el elemento
-- y el elemento al que esta anclado. Al editarlo se ajusta el ancho real.
function UM:GetExtraWidth(key)
    local targetKey = self:GetSnapTarget(key)
    local mover = self.movers and self.movers[key]
    local targetMover = targetKey and self.movers and self.movers[targetKey]
    if not (mover and targetMover and targetMover:IsShown()) then
        return nil
    end
    return Round(mover:GetWidth() - targetMover:GetWidth())
end

function UM:SetExtraWidth(key, extra)
    local targetKey = self:GetSnapTarget(key)
    local mover = self.movers and self.movers[key]
    local targetMover = targetKey and self.movers and self.movers[targetKey]
    local frame = self:GetElementFrame(key)
    if not (mover and targetMover and frame and self:CanEditElementSize(key)) then return end
    local width, height = self:GetEditableElementSize(key)
    if not (width and height) then return end
    local pixelsPerUnit = (frame:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    if pixelsPerUnit <= 0 then pixelsPerUnit = 1 end
    local desired = targetMover:GetWidth() + (tonumber(extra) or 0)
    local newWidth = width + ((desired - mover:GetWidth()) / pixelsPerUnit)
    self:SetEditableElementSize(key, newWidth, height)
end

local function SetMenuInputValue(input, value)
    if not input or input:HasFocus() then return end
    input:SetText(value ~= nil and tostring(value) or "")
    input:SetCursorPosition(0)
end

local function SliderRange(current, minimum, maximum)
    current = tonumber(current) or 0
    return min(minimum, current), max(maximum, current)
end

function UM:RefreshMoverMenuFields()
    local menuFrame = self.moverMenu
    if not (menuFrame and menuFrame.activeKey) then
        return
    end

    local key = menuFrame.activeKey
    local def = self:GetElementDef(key)
    local theme = GetUnlockTheme()
    local canEditSize = self:CanEditElementSize(key)
    local width, height = self:GetEditableElementSize(key)
    local x, y = self:GetRelativeXY(key)
    local offsetX, offsetY = self:GetSnapOffset(key)
    local extraWidth = canEditSize and self:GetExtraWidth(key) or nil
    local sizeLabels = def and type(def.sizeLabels) == "table" and def.sizeLabels or nil
    local uiWidth, uiHeight = GetUIRect()
    local _, relativeLabel = self:GetMenuRelativePoint()

    menuFrame.fadeTargetID = ResolveMouseoverTargetID(key, def)
    menuFrame.canEditSize = canEditSize and width ~= nil
    menuFrame.hasAnchor = offsetX ~= nil
    menuFrame.hasExtraWidth = extraWidth ~= nil
    menuFrame.hasGenericSize = self:HasGenericSizeOverride(key)

    KT:AddBackdrop(menuFrame, MENU_BG[1], MENU_BG[2], MENU_BG[3], MENU_BG[4])
    KT:AddBorder(menuFrame, theme.accent.r, theme.accent.g, theme.accent.b, 0.85)
    menuFrame.topAccent:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 1)

    menuFrame.hint:SetTextColor(MENU_HINT[1], MENU_HINT[2], MENU_HINT[3], 1)
    menuFrame.title:SetText(LText("Element Options") .. ":  " .. LText(def and (def.label or key) or key))
    menuFrame.title:SetTextColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
    menuFrame.noSize:SetTextColor(MENU_HINT[1], MENU_HINT[2], MENU_HINT[3], 1)
    for _, divider in ipairs(menuFrame.dividers) do
        divider:SetColorTexture(MENU_DIVIDER[1], MENU_DIVIDER[2], MENU_DIVIDER[3], MENU_DIVIDER[4])
    end
    for _, row in ipairs(menuFrame.valueRows) do
        row:ApplyStyle()
    end

    menuFrame.widthRow.label:SetText(LText(sizeLabels and sizeLabels.width or "Width"))
    menuFrame.heightRow.label:SetText(LText(sizeLabels and sizeLabels.height or "Height"))
    if menuFrame.canEditSize then
        menuFrame.widthRow:SetRange(SliderRange(width, 1, max(600, (width or 0) * 2)))
        menuFrame.widthRow:SetValue(width)
        menuFrame.heightRow:SetRange(SliderRange(height, 1, max(300, (height or 0) * 2)))
        menuFrame.heightRow:SetValue(height)
    end

    menuFrame.xRow:SetRange(SliderRange(x, -Round(uiWidth), Round(uiWidth)))
    menuFrame.xRow:SetValue(x)
    menuFrame.yRow:SetRange(SliderRange(y, -Round(uiHeight), Round(uiHeight)))
    menuFrame.yRow:SetValue(y)

    if menuFrame.hasExtraWidth then
        menuFrame.extraWidthRow:SetRange(SliderRange(extraWidth, -300, 300))
        menuFrame.extraWidthRow:SetValue(extraWidth)
    end
    if menuFrame.hasAnchor then
        menuFrame.offsetXRow:SetRange(SliderRange(offsetX, -500, 500))
        menuFrame.offsetXRow:SetValue(offsetX)
        menuFrame.offsetYRow:SetRange(SliderRange(offsetY, -500, 500))
        menuFrame.offsetYRow:SetValue(offsetY)
    end

    StyleMenuButton(menuFrame.anchorButton)
    menuFrame.anchorButton.text:SetText(LText("Anchored to") .. ":  " .. (self:GetSnapTarget(key) and self:GetSnapTargetLabel(key) or LText("Screen")))
    menuFrame.anchorButton.arrow:SetTextColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
    StyleMenuButton(menuFrame.relativeButton)
    menuFrame.relativeButton.text:SetText(LText("Relative to Screen") .. ":  " .. LText(relativeLabel))
    menuFrame.relativeButton.arrow:SetTextColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)

    StyleMenuButton(menuFrame.fade)
    if menuFrame.fadeTargetID then
        menuFrame.fade:SetVisualState(GetMouseoverSetting(menuFrame.fadeTargetID))
    end
    StyleMenuButton(menuFrame.configure)
    StyleMenuButton(menuFrame.center)
    StyleMenuButton(menuFrame.reset)
    StyleMenuButton(menuFrame.resetSize)

    KT:AddBackdrop(menuFrame.list, MENU_BG[1], MENU_BG[2], MENU_BG[3], MENU_BG[4])
    KT:AddBorder(menuFrame.list, theme.accent.r, theme.accent.g, theme.accent.b, 0.85)

    menuFrame:UpdateLayout()
end

-- Lista desplegable compartida (anclaje y punto de referencia).
function UM:ShowMoverMenuList(anchorButton, listKind, options, currentValue, onSelect)
    local menuFrame = self.moverMenu
    local list = menuFrame and menuFrame.list
    if not list then return end

    if list:IsShown() and list.kind == listKind and list.anchorButton == anchorButton then
        list:Hide()
        return
    end
    list.kind = listKind
    list.anchorButton = anchorButton

    local content = list.content
    list.buttons = list.buttons or {}
    for _, button in ipairs(list.buttons) do
        button:Hide()
    end

    local buttonWidth = anchorButton:GetWidth()
    local buttonHeight = 20
    local spacing = 2
    for index, option in ipairs(options) do
        local button = list.buttons[index]
        if not button then
            button = CreatePanelButton(content, buttonWidth, buttonHeight, "")
            button.text:ClearAllPoints()
            button.text:SetPoint("LEFT", 8, 0)
            button.text:SetPoint("RIGHT", -8, 0)
            button.text:SetJustifyH("LEFT")
            list.buttons[index] = button
        end
        button:SetWidth(buttonWidth)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", 0, -((index - 1) * (buttonHeight + spacing)))
        button.text:SetText(LText(option.label or ""))
        StyleMenuButton(button, option.value == currentValue)
        button:SetScript("OnClick", function()
            list:Hide()
            onSelect(option.value)
            self:RefreshMoverMenuFields()
        end)
        button:Show()
    end

    local contentHeight = (#options * (buttonHeight + spacing)) - spacing
    content:SetSize(buttonWidth, max(contentHeight, 1))
    list:SetSize(buttonWidth + 12, min(contentHeight, 286) + 12)
    list.scroll:SetVerticalScroll(0)
    list:ClearAllPoints()
    list:SetPoint("TOPLEFT", anchorButton, "BOTTOMLEFT", -6, -2)
    list:Show()
    list:Raise()
end

-- Compatibilidad: el nombre antiguo abre la lista de anclaje.
function UM:ToggleMoverSnapList(anchorButton)
    local menuFrame = self.moverMenu
    if not (menuFrame and menuFrame.activeKey) then return end
    local key = menuFrame.activeKey
    local options = self:GetSnapTargetOptions(key)
    if options[1] and options[1].value == nil then
        options[1].label = "Screen"
    end
    self:ShowMoverMenuList(anchorButton or menuFrame.anchorButton, "anchor", options, self:GetSnapTarget(key), function(value)
        self:SetSnapTarget(key, value)
    end)
end

local function CreateMenuSlider(parent)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(16)
    slider:SetHitRectInsets(0, 0, -3, -3)
    slider:SetValueStep(1)
    if slider.SetObeyStepOnDrag then
        slider:SetObeyStepOnDrag(true)
    end
    slider:EnableMouseWheel(true)

    slider.track = slider:CreateTexture(nil, "BACKGROUND")
    slider.track:SetTexture(WHITE8X8)
    slider.track:SetPoint("LEFT", 0, 0)
    slider.track:SetPoint("RIGHT", 0, 0)
    slider.track:SetHeight(4)

    slider.fill = slider:CreateTexture(nil, "ARTWORK")
    slider.fill:SetTexture(WHITE8X8)
    slider.fill:SetPoint("LEFT", slider.track, "LEFT", 0, 0)
    slider.fill:SetHeight(4)

    slider.thumb = slider:CreateTexture(nil, "OVERLAY")
    slider.thumb:SetTexture(WHITE8X8)
    slider.thumb:SetSize(6, 14)
    slider:SetThumbTexture(slider.thumb)

    slider.UpdateFill = function(s)
        local minValue, maxValue = s:GetMinMaxValues()
        local value = s:GetValue()
        local percent = (maxValue > minValue) and ((value - minValue) / (maxValue - minValue)) or 0
        s.fill:SetWidth(max(1, (s:GetWidth() or 1) * max(0, min(1, percent))))
    end
    slider:SetScript("OnSizeChanged", function(s)
        s:UpdateFill()
    end)
    return slider
end

function UM:OpenMoverMenu(key, anchor)
    local menuFrame = self.moverMenu
    if not menuFrame then
        local MENU_WIDTH = 300
        local INNER_WIDTH = MENU_WIDTH - 24

        menuFrame = CreateFrame("Frame", "KullThranUIUnlockModeMenu", self.unlockFrame)
        menuFrame:SetSize(MENU_WIDTH, 200)
        menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        menuFrame:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 120)
        menuFrame:SetClampedToScreen(true)
        menuFrame:EnableMouse(true)
        KT:AddBackdrop(menuFrame, MENU_BG[1], MENU_BG[2], MENU_BG[3], MENU_BG[4])
        KT:AddBorder(menuFrame, MOVER_R, MOVER_G, MOVER_B, 0.85)

        menuFrame.topAccent = menuFrame:CreateTexture(nil, "ARTWORK")
        menuFrame.topAccent:SetPoint("TOPLEFT", 1, -1)
        menuFrame.topAccent:SetPoint("TOPRIGHT", -1, -1)
        menuFrame.topAccent:SetHeight(2)

        menuFrame.dividers = {}
        menuFrame.valueRows = {}

        menuFrame.hint = CreateText(menuFrame, 10, "CENTER")
        menuFrame.hint:SetWidth(INNER_WIDTH)
        menuFrame.hint:SetText(LText("Use arrow keys to move the selected element 1px in any direction. Shift+Arrows moves 10px."))

        menuFrame.title = CreateText(menuFrame, 12, "LEFT")
        menuFrame.title:SetWidth(INNER_WIDTH)
        menuFrame.title:SetWordWrap(false)

        menuFrame.noSize = CreateText(menuFrame, 10, "LEFT")
        menuFrame.noSize:SetWidth(INNER_WIDTH)
        menuFrame.noSize:SetText(LText("This element's size is set by its own module."))

        local function CreateDivider()
            local divider = menuFrame:CreateTexture(nil, "ARTWORK")
            divider:SetHeight(1)
            divider:SetWidth(INNER_WIDTH)
            tinsert(menuFrame.dividers, divider)
            return divider
        end

        -- Fila: etiqueta | slider | caja numerica. El slider aplica en vivo
        -- (con un pequeno throttle) y la caja acepta valores exactos.
        local function CreateValueRow(labelText)
            local row = CreateFrame("Frame", nil, menuFrame)
            row:SetSize(INNER_WIDTH, 22)
            row.label = CreateText(row, 11, "LEFT")
            row.label:SetPoint("LEFT", 0, 0)
            row.label:SetWidth(84)
            row.label:SetWordWrap(false)
            row.label:SetText(LText(labelText))
            row.input = CreateMenuInputBox(row, 54, 20)
            row.input:SetPoint("RIGHT", 0, 0)
            row.slider = CreateMenuSlider(row)
            row.slider:SetPoint("LEFT", 88, 0)
            row.slider:SetPoint("RIGHT", row.input, "LEFT", -10, 0)

            row.ApplyStyle = function(selfRow)
                local rowTheme = GetUnlockTheme()
                selfRow.label:SetTextColor(MENU_LABEL[1], MENU_LABEL[2], MENU_LABEL[3], 1)
                selfRow.slider.track:SetVertexColor(1, 1, 1, 0.12)
                selfRow.slider.fill:SetVertexColor(rowTheme.accent.r, rowTheme.accent.g, rowTheme.accent.b, 0.85)
                selfRow.slider.thumb:SetVertexColor(1, 1, 1, 1)
                if not selfRow.input:HasFocus() then
                    StyleMenuInputBox(selfRow.input)
                end
            end

            row.SetRange = function(selfRow, minValue, maxValue)
                if selfRow.isDragging then return end
                selfRow.slider._ktSetting = true
                selfRow.slider:SetMinMaxValues(minValue, maxValue)
                selfRow.slider._ktSetting = nil
            end

            row.SetValue = function(selfRow, value)
                if selfRow.isDragging then return end
                selfRow.slider._ktSetting = true
                selfRow.slider:SetValue(tonumber(value) or 0)
                selfRow.slider._ktSetting = nil
                selfRow.slider:UpdateFill()
                SetMenuInputValue(selfRow.input, value)
            end

            row.Apply = function(selfRow, value)
                if not (menuFrame.activeKey and selfRow.applyValue) then return end
                selfRow.applyValue(Round(value))
            end

            row.FlushPending = function(selfRow)
                local value = selfRow.pendingValue
                selfRow.pendingValue = nil
                if value ~= nil then
                    selfRow:Apply(value)
                end
            end

            row.slider:SetScript("OnValueChanged", function(slider, value)
                slider:UpdateFill()
                if slider._ktSetting then return end
                value = Round(value)
                SetMenuInputValue(row.input, value)
                row.pendingValue = value
                if not row.applyQueued then
                    row.applyQueued = true
                    C_Timer.After(0.06, function()
                        row.applyQueued = nil
                        row:FlushPending()
                        if not row.isDragging then
                            UM:RefreshMoverMenuFields()
                        end
                    end)
                end
            end)
            row.slider:SetScript("OnMouseDown", function()
                row.isDragging = true
            end)
            row.slider:SetScript("OnMouseUp", function()
                row.isDragging = nil
                row:FlushPending()
                UM:RefreshMoverMenuFields()
            end)
            row.slider:SetScript("OnMouseWheel", function(slider, delta)
                local step = IsShiftKeyDown() and 10 or 1
                local minValue, maxValue = slider:GetMinMaxValues()
                slider:SetValue(max(minValue, min(maxValue, Round(slider:GetValue()) + (delta * step))))
            end)

            row.input:SetScript("OnEnterPressed", function(box)
                box:ClearFocus()
            end)
            row.input:SetScript("OnTabPressed", function(box)
                box:ClearFocus()
            end)
            row.input:SetScript("OnEscapePressed", function(box)
                box._ktSkipCommit = true
                box:ClearFocus()
                UM:RefreshMoverMenuFields()
            end)
            row.input:HookScript("OnEditFocusLost", function(box)
                if box._ktSkipCommit then
                    box._ktSkipCommit = nil
                    return
                end
                local value = tonumber(box:GetText())
                if value then
                    row:Apply(value)
                end
                UM:RefreshMoverMenuFields()
            end)

            tinsert(menuFrame.valueRows, row)
            return row
        end

        local function CreateSelectButton()
            local button = CreatePanelButton(menuFrame, INNER_WIDTH, 22, "")
            button.text:ClearAllPoints()
            button.text:SetPoint("LEFT", 8, 0)
            button.text:SetPoint("RIGHT", -20, 0)
            button.text:SetJustifyH("LEFT")
            button.arrow = CreateText(button, 12, "RIGHT")
            button.arrow:SetPoint("RIGHT", -8, 0)
            button.arrow:SetText(">")
            return button
        end

        menuFrame.hintDivider = CreateDivider()
        menuFrame.titleDivider = CreateDivider()

        menuFrame.widthRow = CreateValueRow("Width")
        menuFrame.widthRow.applyValue = function(value)
            local _, currentHeight = self:GetEditableElementSize(menuFrame.activeKey)
            self:SetEditableElementSize(menuFrame.activeKey, value, currentHeight or value)
        end
        menuFrame.heightRow = CreateValueRow("Height")
        menuFrame.heightRow.applyValue = function(value)
            local currentWidth = self:GetEditableElementSize(menuFrame.activeKey)
            self:SetEditableElementSize(menuFrame.activeKey, currentWidth or value, value)
        end
        menuFrame.xRow = CreateValueRow("X Position")
        menuFrame.xRow.applyValue = function(value)
            local _, currentY = self:GetRelativeXY(menuFrame.activeKey)
            self:SetRelativeXY(menuFrame.activeKey, value, currentY)
        end
        menuFrame.yRow = CreateValueRow("Y Position")
        menuFrame.yRow.applyValue = function(value)
            local currentX = self:GetRelativeXY(menuFrame.activeKey)
            self:SetRelativeXY(menuFrame.activeKey, currentX, value)
        end

        menuFrame.extraDivider = CreateDivider()
        menuFrame.extraWidthRow = CreateValueRow("Extra Width")
        menuFrame.extraWidthRow.applyValue = function(value)
            self:SetExtraWidth(menuFrame.activeKey, value)
        end

        menuFrame.anchorDivider = CreateDivider()
        menuFrame.anchorButton = CreateSelectButton()
        menuFrame.anchorButton:SetScript("OnClick", function(button)
            self:ToggleMoverSnapList(button)
        end)
        menuFrame.offsetXRow = CreateValueRow("Offset X")
        menuFrame.offsetXRow.applyValue = function(value)
            local _, currentY = self:GetSnapOffset(menuFrame.activeKey)
            self:SetSnapOffset(menuFrame.activeKey, value, currentY or 0)
        end
        menuFrame.offsetYRow = CreateValueRow("Offset Y")
        menuFrame.offsetYRow.applyValue = function(value)
            local currentX = self:GetSnapOffset(menuFrame.activeKey)
            self:SetSnapOffset(menuFrame.activeKey, currentX or 0, value)
        end

        menuFrame.actionsDivider = CreateDivider()

        menuFrame.fade = CreatePanelButton(menuFrame, INNER_WIDTH, 22, LText("Fade on Mouseover"))
        menuFrame.fade.text:ClearAllPoints()
        menuFrame.fade.text:SetPoint("LEFT", 8, 0)
        menuFrame.fade.text:SetJustifyH("LEFT")
        menuFrame.fade.indicator = CreateText(menuFrame.fade, 11, "RIGHT")
        menuFrame.fade.indicator:SetPoint("RIGHT", -8, 0)
        menuFrame.fade.SetVisualState = function(button, enabled)
            button.isChecked = enabled == true
            if button.isChecked then
                button.indicator:SetText(LText("ON"))
                button.indicator:SetTextColor(0.55, 1, 0.62, 1)
            else
                button.indicator:SetText(LText("OFF"))
                button.indicator:SetTextColor(1, 0.55, 0.55, 1)
            end
        end
        menuFrame.fade:SetScript("OnClick", function(button)
            local targetID = menuFrame.fadeTargetID
            if not targetID then
                return
            end

            local nextValue = not GetMouseoverSetting(targetID)
            SetMouseoverSetting(targetID, nextValue)
            button:SetVisualState(nextValue)
            RefreshMouseoverModules(targetID)
        end)

        menuFrame.configure = CreatePanelButton(menuFrame, INNER_WIDTH, 22, LText("Open Configuration"))
        menuFrame.configure:SetScript("OnClick", function()
            local activeKey = menuFrame.activeKey
            local def = activeKey and self:GetElementDef(activeKey)
            local page = def and (def.optionsPage or def.pageId or def.configPage)
            local group = def and def.group
            menuFrame:Hide()
            self:CloseUnlockMode(true, true)
            if page and KT.OpenMenu then
                KT:OpenMenu(page)
            elseif group and KT.ShowModule then
                KT:ShowModule(group)
            end
        end)

        menuFrame.center = CreatePanelButton(menuFrame, INNER_WIDTH, 22, LText("Center on Screen"))
        menuFrame.center:SetScript("OnClick", function()
            if menuFrame.activeKey then
                self:CenterMover(menuFrame.activeKey)
                self:RefreshMoverMenuFields()
            end
        end)

        menuFrame.reset = CreatePanelButton(menuFrame, INNER_WIDTH, 22, LText("Reset Position"))
        menuFrame.reset:SetScript("OnClick", function()
            if menuFrame.activeKey then
                self:ResetMover(menuFrame.activeKey)
                self:RefreshMoverMenuFields()
            end
        end)

        menuFrame.resetSize = CreatePanelButton(menuFrame, INNER_WIDTH, 22, LText("Reset Size"))
        menuFrame.resetSize:SetScript("OnClick", function()
            if menuFrame.activeKey then
                self:ResetElementSize(menuFrame.activeKey)
                self:RefreshMoverMenuFields()
            end
        end)

        menuFrame.relativeDivider = CreateDivider()
        menuFrame.relativeButton = CreateSelectButton()
        menuFrame.relativeButton:SetScript("OnClick", function(button)
            local current = self:GetMenuRelativePoint()
            self:ShowMoverMenuList(button, "relative", RELATIVE_POINTS, current, function(value)
                self.db.unlockRelativePoint = value
            end)
        end)

        local list = CreateFrame("Frame", nil, self.unlockFrame)
        list:SetFrameStrata("FULLSCREEN_DIALOG")
        list:SetFrameLevel(menuFrame:GetFrameLevel() + 10)
        list:SetClampedToScreen(true)
        list:EnableMouse(true)
        list.scroll = CreateFrame("ScrollFrame", nil, list)
        list.scroll:SetPoint("TOPLEFT", 6, -6)
        list.scroll:SetPoint("BOTTOMRIGHT", -6, 6)
        list.content = CreateFrame("Frame", nil, list.scroll)
        list.content:SetSize(INNER_WIDTH, 1)
        list.scroll:SetScrollChild(list.content)
        list:EnableMouseWheel(true)
        list:SetScript("OnMouseWheel", function(widget, delta)
            local scroll = widget.scroll
            local maxScroll = max(0, widget.content:GetHeight() - scroll:GetHeight())
            scroll:SetVerticalScroll(max(0, min(maxScroll, scroll:GetVerticalScroll() - (delta * 44))))
        end)
        list:Hide()
        menuFrame.list = list
        menuFrame.snapList = list

        menuFrame.UpdateLayout = function(frame)
            local y = -10

            local function Place(region, height, gap)
                region:ClearAllPoints()
                region:SetPoint("TOPLEFT", 12, y)
                region:Show()
                y = y - height - (gap or 4)
            end

            local function Hide(region)
                region:Hide()
            end

            Place(frame.hint, max(frame.hint:GetStringHeight() or 0, 24), 8)
            Place(frame.hintDivider, 1, 8)
            Place(frame.title, 14, 8)
            Place(frame.titleDivider, 1, 8)

            if frame.canEditSize then
                Hide(frame.noSize)
                Place(frame.widthRow, 22, 3)
                Place(frame.heightRow, 22, 3)
            else
                Hide(frame.widthRow)
                Hide(frame.heightRow)
                Place(frame.noSize, 12, 6)
            end
            Place(frame.xRow, 22, 3)
            Place(frame.yRow, 22, 6)

            if frame.hasExtraWidth then
                Place(frame.extraDivider, 1, 6)
                Place(frame.extraWidthRow, 22, 6)
            else
                Hide(frame.extraDivider)
                Hide(frame.extraWidthRow)
            end

            Place(frame.anchorDivider, 1, 6)
            Place(frame.anchorButton, 22, 4)
            if frame.hasAnchor then
                Place(frame.offsetXRow, 22, 3)
                Place(frame.offsetYRow, 22, 6)
            else
                Hide(frame.offsetXRow)
                Hide(frame.offsetYRow)
                y = y - 2
            end

            Place(frame.actionsDivider, 1, 6)
            if frame.fadeTargetID then
                Place(frame.fade, 22, 4)
            else
                Hide(frame.fade)
            end
            Place(frame.configure, 22, 4)
            Place(frame.center, 22, 4)
            Place(frame.reset, 22, 4)
            if frame.hasGenericSize then
                Place(frame.resetSize, 22, 4)
            else
                Hide(frame.resetSize)
            end

            Place(frame.relativeDivider, 1, 6)
            Place(frame.relativeButton, 22, 4)

            frame:SetHeight(abs(y) + 6)
        end

        menuFrame:SetScript("OnHide", function(frame)
            frame.list:Hide()
            for _, row in ipairs(frame.valueRows) do
                row.isDragging = nil
                row.pendingValue = nil
                row.input._ktSkipCommit = true
                row.input:ClearFocus()
                row.input._ktSkipCommit = nil
            end
        end)

        menuFrame:Hide()
        self.moverMenu = menuFrame
    end

    if menuFrame:IsShown() and menuFrame.activeKey == key then
        menuFrame:Hide()
        return
    end

    menuFrame:Hide()
    menuFrame.activeKey = key
    menuFrame.list:Hide()
    self:RefreshMoverMenuFields()
    menuFrame:ClearAllPoints()
    menuFrame:SetPoint("TOPLEFT", anchor or self.movers[key] or self.unlockFrame, "TOPRIGHT", 6, 0)
    menuFrame:Show()
    menuFrame:Raise()
    -- Pin the menu where it opened. Anchored to the mover it followed every X/Y
    -- change, so the slider under the cursor moved too: the value kept changing,
    -- the element ran away and flickered.
    local left, top = menuFrame:GetLeft(), menuFrame:GetTop()
    if left and top then
        menuFrame:ClearAllPoints()
        menuFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    end
end

function UM:RefreshMovers()
    local visible = {}
    for _, key in ipairs(self.registryOrder) do
        if not self:IsElementHidden(key) then
            local mover = self.movers[key] or self:CreateMover(key)
            mover:Sync()
            mover:Show()
            visible[key] = true
        end
    end

    for key, mover in pairs(self.movers) do
        if not visible[key] then
            mover:Hide()
        end
    end
end

function UM:CreateGrid()
    if self.gridFrame then return end
    local grid = CreateFrame("Frame", nil, self.unlockFrame)
    grid:SetAllPoints(UIParent)
    grid.lines = {}
    self.gridFrame = grid
end

function UM:RebuildGrid()
    self:CreateGrid()
    local grid = self.gridFrame
    for _, line in ipairs(grid.lines) do
        line:Hide()
    end
    wipe(grid.lines)

    local uiWidth, uiHeight = GetUIRect()
    local alpha = self.db.unlockGrid == "bright" and 0.30 or 0.15
    local centerAlpha = self.db.unlockGrid == "bright" and 0.50 or 0.25

    local theme = GetUnlockTheme()
    for x = 0, uiWidth, GRID_SIZE do
        local line = grid:CreateTexture(nil, "BACKGROUND")
        line:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, (abs(x - (uiWidth * 0.5)) < 1) and centerAlpha or alpha)
        line:SetPoint("TOPLEFT", x, 0)
        line:SetPoint("BOTTOMLEFT", x, 0)
        line:SetWidth(1)
        tinsert(grid.lines, line)
    end

    for y = 0, uiHeight, GRID_SIZE do
        local line = grid:CreateTexture(nil, "BACKGROUND")
        line:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, (abs(y - (uiHeight * 0.5)) < 1) and centerAlpha or alpha)
        line:SetPoint("TOPLEFT", 0, -y)
        line:SetPoint("TOPRIGHT", 0, -y)
        line:SetHeight(1)
        tinsert(grid.lines, line)
    end

    if self.db.unlockGrid == "disabled" then
        grid:Hide()
    else
        grid:Show()
    end
end

function UM:CreateSidebar()
    if self.sidebar then return end

    local theme = GetUnlockTheme()
    local sidebar = CreateFrame("Frame", nil, self.unlockFrame)
    sidebar:SetSize(SIDEBAR_WIDTH, SIDEBAR_HEIGHT)
    sidebar:SetPoint("LEFT", UIParent, "LEFT", 0, 0)
    sidebar:SetFrameStrata("FULLSCREEN_DIALOG")
    sidebar:SetFrameLevel((self.unlockFrame and self.unlockFrame:GetFrameLevel() or 0) + 50)
    sidebar:SetToplevel(true)
    sidebar:SetClampedToScreen(false)
    sidebar:EnableMouse(true)
    sidebar.shadowArt = sidebar:CreateTexture(nil, "BACKGROUND", nil, -8)
    sidebar.shadowArt:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 6, -6)
    sidebar.shadowArt:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 6, -6)
    sidebar.shadowArt:SetTexture(SIDEBAR_TEXTURE)
    sidebar.shadowArt:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 0.5)

    sidebar.bgArt = sidebar:CreateTexture(nil, "BACKGROUND", nil, -7)
    sidebar.bgArt:SetAllPoints()
    sidebar.bgArt:SetTexture(SIDEBAR_TEXTURE)
    sidebar.bgArt:SetVertexColor(theme.background.r, theme.background.g, theme.background.b, 0.98)

    sidebar.idleLogo = sidebar:CreateTexture(nil, "OVERLAY")
    sidebar.idleLogo:SetSize(46, 46)
    sidebar.idleLogo:SetPoint("CENTER", sidebar, "RIGHT", -27.5, 0)
    sidebar.idleLogo:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png")
    sidebar.idleLogo:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
    sidebar.idleLogo:SetAlpha(0)

    -- Add some decorative detail for the closed state
    sidebar.idleGrip = sidebar:CreateTexture(nil, "OVERLAY")
    sidebar.idleGrip:SetSize(4, 46)
    sidebar.idleGrip:SetPoint("RIGHT", sidebar.idleLogo, "LEFT", -8, 0)
    sidebar.idleGrip:SetTexture(SIDEBAR_BUTTON_TEXTURE)
    sidebar.idleGrip:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 0.4)
    sidebar.idleGrip:SetAlpha(0)
    
    sidebar.idleGrip2 = sidebar:CreateTexture(nil, "OVERLAY")
    sidebar.idleGrip2:SetSize(2, 46)
    sidebar.idleGrip2:SetPoint("RIGHT", sidebar.idleGrip, "LEFT", -4, 0)
    sidebar.idleGrip2:SetTexture(SIDEBAR_BUTTON_TEXTURE)
    sidebar.idleGrip2:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 0.2)
    sidebar.idleGrip2:SetAlpha(0)
    
    sidebar.contentGroup = CreateFrame("Frame", nil, sidebar)
    sidebar.contentGroup:SetAllPoints()







    sidebar.edgeGlow = sidebar.contentGroup:CreateTexture(nil, "BORDER", nil, -7)
    sidebar.edgeGlow:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -6, -SIDEBAR_TOP_SAFE)
    sidebar.edgeGlow:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -6, SIDEBAR_BOTTOM_SAFE)
    sidebar.edgeGlow:SetWidth(1)
    sidebar.edgeGlow:SetColorTexture(1, 1, 1, 0.03)

    local title = CreateText(sidebar.contentGroup, 13)
    title:SetPoint("TOPLEFT", 14, -46)
    title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 15, "OUTLINE")
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 1)
    title:SetText(LText("EDIT MODE"))
    title:SetJustifyH("LEFT")
    title:SetTextColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
    sidebar.title = title

    sidebar.titleRule = sidebar.contentGroup:CreateTexture(nil, "ARTWORK", nil, -4)
    sidebar.titleRule:SetPoint("TOPLEFT", 14, -74)
    sidebar.titleRule:SetHeight(1)
    sidebar.titleRule:SetWidth(136)
    sidebar.titleRule:SetTexture(WHITE8X8)
    ApplyTextureGradient(sidebar.titleRule, "HORIZONTAL",
        theme.accent.r, theme.accent.g, theme.accent.b, 0.24,
        theme.accent.r, theme.accent.g, theme.accent.b, 0)

    sidebar.controlsPanel = CreateFrame("Frame", nil, sidebar.contentGroup)
    sidebar.controlsPanel:SetPoint("TOPLEFT", 10, -88)
    sidebar.controlsPanel:SetSize(190, 148)
    ApplySidebarPanelStyle(sidebar.controlsPanel, "controls")

    sidebar.toggleGrid = CreateActionButton(sidebar.contentGroup, 182, 28, "", "long")
    sidebar.toggleGrid:SetPoint("TOPLEFT", 14, -102)
    StyleSidebarButton(sidebar.toggleGrid, "toggle")
    sidebar.toggleGrid:SetScript("OnClick", function()
        if self.db.unlockGrid == "disabled" then
            self.db.unlockGrid = "dimmed"
        elseif self.db.unlockGrid == "dimmed" then
            self.db.unlockGrid = "bright"
        else
            self.db.unlockGrid = "disabled"
        end
        self:RebuildGrid()
        self:RefreshSidebar()
    end)

    sidebar.toggleSnap = CreateActionButton(sidebar.contentGroup, 182, 28, "", "long")
    sidebar.toggleSnap:SetPoint("TOPLEFT", sidebar.toggleGrid, "BOTTOMLEFT", 0, -6)
    StyleSidebarButton(sidebar.toggleSnap, "toggle")
    sidebar.toggleSnap:SetScript("OnClick", function()
        self.db.unlockSnap = not self.db.unlockSnap
        self:RefreshSidebar()
    end)

    sidebar.toggleDark = CreateActionButton(sidebar.contentGroup, 182, 28, "", "long")
    sidebar.toggleDark:SetPoint("TOPLEFT", sidebar.toggleSnap, "BOTTOMLEFT", 0, -6)
    StyleSidebarButton(sidebar.toggleDark, "toggle")
    sidebar.toggleDark:SetScript("OnClick", function()
        self.db.unlockDarkOverlays = not self.db.unlockDarkOverlays
        for _, mover in pairs(self.movers) do
            mover:RefreshStyle()
        end
        self:RefreshSidebar()
    end)

    sidebar.toggleCoords = CreateActionButton(sidebar.contentGroup, 182, 28, "", "long")
    sidebar.toggleCoords:SetPoint("TOPLEFT", sidebar.toggleDark, "BOTTOMLEFT", 0, -6)
    StyleSidebarButton(sidebar.toggleCoords, "toggle")
    sidebar.toggleCoords:SetScript("OnClick", function()
        self.db.unlockCoords = not self.db.unlockCoords
        for _, mover in pairs(self.movers) do
            mover:RefreshCoords()
        end
        self:RefreshSidebar()
    end)

    local header = CreateText(sidebar.contentGroup, 10, "LEFT")
    header:SetPoint("TOPLEFT", 18, -228)
    header:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    header:SetText(LText("KUI ELEMENTS"))
    header:SetTextColor(theme.soft.r, theme.soft.g, theme.soft.b, 1)
    sidebar.header = header

    sidebar.listPanel = CreateFrame("Frame", nil, sidebar.contentGroup)
    sidebar.listPanel:SetPoint("TOPLEFT", 10, -254)
    sidebar.listPanel:SetPoint("BOTTOMRIGHT", -20, SIDEBAR_BOTTOM_SAFE + 108)
    ApplySidebarPanelStyle(sidebar.listPanel, "list")

    sidebar.headerRule = sidebar.contentGroup:CreateTexture(nil, "ARTWORK", nil, -3)
    sidebar.headerRule:SetPoint("TOPLEFT", 14, -254)
    sidebar.headerRule:SetHeight(1)
    sidebar.headerRule:SetWidth(182)
    sidebar.headerRule:SetTexture(WHITE8X8)
    ApplyTextureGradient(sidebar.headerRule, "HORIZONTAL",
        theme.accent.r, theme.accent.g, theme.accent.b, 0.18,
        theme.accent.r, theme.accent.g, theme.accent.b, 0)

    local scroll = CreateFrame("ScrollFrame", nil, sidebar.contentGroup, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 14, -262)
    scroll:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -22, SIDEBAR_BOTTOM_SAFE + 114)
    sidebar.scroll = scroll

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(178, 392)
    scroll:SetScrollChild(content)
    sidebar.content = content
    sidebar.itemButtons = {}

    local scrollbar = scroll.ScrollBar
    if scrollbar then
        scrollbar:ClearAllPoints()
        scrollbar:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -12, -262)
        scrollbar:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -12, SIDEBAR_BOTTOM_SAFE + 46)
        scrollbar:SetWidth(8)
        if scrollbar.Track then scrollbar.Track:Hide() end
        if scrollbar.Top then scrollbar.Top:Hide() end
        if scrollbar.Bottom then scrollbar.Bottom:Hide() end
        if scrollbar.Middle then scrollbar.Middle:Hide() end
        if scrollbar.BG then scrollbar.BG:Hide() end
        if scrollbar.ScrollUpButton then
            scrollbar.ScrollUpButton:Hide()
            scrollbar.ScrollUpButton:SetHeight(0.01)
        end
        if scrollbar.ScrollDownButton then
            scrollbar.ScrollDownButton:Hide()
            scrollbar.ScrollDownButton:SetHeight(0.01)
        end
        sidebar.scrollbarTrack = sidebar.scrollbarTrack or CreateFrame("Frame", nil, scrollbar)
        sidebar.scrollbarTrack:SetPoint("TOPLEFT", 2, -2)
        sidebar.scrollbarTrack:SetPoint("BOTTOMRIGHT", -2, 2)
        KT:AddBackdrop(sidebar.scrollbarTrack, 0.01, 0.01, 0.01, 0.96)
        KT:AddBorder(sidebar.scrollbarTrack, theme.accent.r, theme.accent.g, theme.accent.b, 0.55)
        sidebar.scrollbarTrackLeft = sidebar.scrollbarTrackLeft or scrollbar:CreateTexture(nil, "BACKGROUND", nil, 2)
        sidebar.scrollbarTrackLeft:SetPoint("TOPLEFT", sidebar.scrollbarTrack, "TOPLEFT", 0, 0)
        sidebar.scrollbarTrackLeft:SetPoint("BOTTOMLEFT", sidebar.scrollbarTrack, "BOTTOMLEFT", 0, 0)
        sidebar.scrollbarTrackLeft:SetWidth(1)
        sidebar.scrollbarTrackRight = sidebar.scrollbarTrackRight or scrollbar:CreateTexture(nil, "BACKGROUND", nil, 2)
        sidebar.scrollbarTrackRight:SetPoint("TOPRIGHT", sidebar.scrollbarTrack, "TOPRIGHT", 0, 0)
        sidebar.scrollbarTrackRight:SetPoint("BOTTOMRIGHT", sidebar.scrollbarTrack, "BOTTOMRIGHT", 0, 0)
        sidebar.scrollbarTrackRight:SetWidth(1)

        local thumb = scrollbar.ThumbTexture or scrollbar:GetThumbTexture()
        if thumb then
            thumb:SetTexture("Interface\\Buttons\\WHITE8x8")
            thumb:SetVertexColor(MOVER_R, MOVER_G, MOVER_B, 0.95)
            thumb:SetWidth(4)
            sidebar.scrollbarThumb = thumb
            sidebar.scrollbarThumbGlow = sidebar.scrollbarThumbGlow or scrollbar:CreateTexture(nil, "ARTWORK", nil, 1)
            sidebar.scrollbarThumbGlow:SetTexture(WHITE8X8)
            sidebar.scrollbarThumbGlow:SetBlendMode("ADD")
            sidebar.scrollbarThumbGlow:ClearAllPoints()
            sidebar.scrollbarThumbGlow:SetPoint("CENTER", thumb, "CENTER", 0, 0)
            sidebar.scrollbarThumbGlow:SetWidth(14)
            sidebar.scrollbarThumbGlow:SetHeight(54)
            sidebar.scrollbarThumbBorder = sidebar.scrollbarThumbBorder or CreateFrame("Frame", nil, scrollbar)
            sidebar.scrollbarThumbBorder:SetFrameLevel(scrollbar:GetFrameLevel() + 6)
            sidebar.scrollbarThumbBorder:ClearAllPoints()
            sidebar.scrollbarThumbBorder:SetPoint("TOPLEFT", thumb, "TOPLEFT", -1, 1)
            sidebar.scrollbarThumbBorder:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", 1, -1)
            KT:AddBorder(sidebar.scrollbarThumbBorder, theme.accent.r, theme.accent.g, theme.accent.b, 0.82)

            scrollbar:HookScript("OnMouseDown", function()
                sidebar.scrollbarDragging = true
                SetScrollbarThumbState(sidebar, "drag")
            end)
            scrollbar:HookScript("OnMouseUp", function()
                sidebar.scrollbarDragging = nil
                SetScrollbarThumbState(sidebar, scrollbar:IsMouseOver() and "hover" or "normal")
            end)
            scrollbar:HookScript("OnEnter", function()
                if not sidebar.scrollbarDragging then
                    SetScrollbarThumbState(sidebar, "hover")
                end
            end)
            scrollbar:HookScript("OnLeave", function()
                if not sidebar.scrollbarDragging then
                    SetScrollbarThumbState(sidebar, "normal")
                end
            end)
            scrollbar:HookScript("OnValueChanged", function()
                if sidebar.scrollbarDragging then
                    SetScrollbarThumbState(sidebar, "drag")
                end
            end)
            SetScrollbarThumbState(sidebar, "normal")
        end
    end

    sidebar.footerPanel = CreateFrame("Frame", nil, sidebar.contentGroup)
    sidebar.footerPanel:SetPoint("BOTTOMLEFT", 14, SIDEBAR_BOTTOM_SAFE - 8)
    sidebar.footerPanel:SetPoint("BOTTOMRIGHT", -14, SIDEBAR_BOTTOM_SAFE - 8)
    sidebar.footerPanel:SetHeight(108)
    ApplySidebarPanelStyle(sidebar.footerPanel, "footer")

    sidebar.restore = CreateActionButton(sidebar.contentGroup, 180, 22, LText("Restore Defaults"), "long")
    sidebar.restore:SetPoint("BOTTOMLEFT", sidebar.footerPanel, "BOTTOMLEFT", 6, 70)
    StyleSidebarButton(sidebar.restore, "toggle")
    sidebar.restore:SetScript("OnClick", function()
        StaticPopupDialogs["KULLTHRANUI_UNLOCKMODE_RESTORE"] = {
            text = LText("Are you sure you want to restore default positions for all elements?"),
            button1 = LText("Yes"),
            button2 = LText("No"),
            OnAccept = function()
                wipe(UM.db.frames)
                wipe(UM.db.positionMeta)
                wipe(UM.db.snapTargets)
                wipe(UM.pendingPositions)
                for _, mover in pairs(UM.movers) do
                    local def = UM:GetElementDef(mover.key)
                    if def and type(def.loadPosition) == "function" then
                        local pos = SafeCall(def.loadPosition, mover.key)
                        if type(pos) == "table" and pos.point then
                            UM:ApplyStoredPositionToElement(mover.key, pos)
                        end
                    else
                        UM:CenterMover(mover.key)
                    end
                end
                UM.hasChanges = true
                UM:RefreshMovers()
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1,
        }
        StaticPopup_Show("KULLTHRANUI_UNLOCKMODE_RESTORE")
    end)

    sidebar.import = CreateActionButton(sidebar.contentGroup, 180, 22, LText("Import Profile"), "long")
    sidebar.import:SetPoint("TOPLEFT", sidebar.restore, "BOTTOMLEFT", 0, -6)
    StyleSidebarButton(sidebar.import, "toggle")
    sidebar.import:SetScript("OnClick", function()
        if KT and KT.MenuPrincipal and KT.MenuPrincipal.NavigateToPage then
            UM:CloseUnlockMode(false, true)
            KT:OpenMainMenu()
            C_Timer.After(0.1, function()
                KT.MenuPrincipal:NavigateToPage("profiles")
            end)
        elseif KT and KT.GetModule then
            local profileMod = KT:GetModule("Profiles", true)
            if profileMod and profileMod.ShowImportPopup then
                UM:CloseUnlockMode(false, true)
                profileMod:ShowImportPopup(LText("Import Profile"), LText("This overwrites the active KullThranUI profile."), function(text)
                    profileMod:ImportProfileString(text)
                end)
            end
        end
    end)

    sidebar.discard = CreateActionButton(sidebar.contentGroup, 86, 22, LText("Discard"), "short")
    sidebar.discard:SetPoint("BOTTOMLEFT", sidebar.footerPanel, "BOTTOMLEFT", 6, 6)
    StyleSidebarButton(sidebar.discard, "footer_red")
    sidebar.discard:SetScript("OnClick", function()
        self:CloseUnlockMode(false, true)
    end)

    sidebar.save = CreateActionButton(sidebar.contentGroup, 86, 22, LText("Save"), "short")
    sidebar.save:SetPoint("BOTTOMRIGHT", sidebar.footerPanel, "BOTTOMRIGHT", -6, 6)
    StyleSidebarButton(sidebar.save, "footer_green")
    sidebar.save:SetScript("OnClick", function()
        self:CloseUnlockMode(true, true)
    end)

    self.sidebar = sidebar
end

function UM:RefreshSidebar()
    self:CreateSidebar()

    local gridMode = self.db.unlockGrid or "dimmed"
    self.sidebar.toggleGrid.text:SetText(LText("Grid: ") .. gridMode)
    self.sidebar.toggleSnap.text:SetText(LText("Snap: ") .. (self.db.unlockSnap and "On" or "Off"))
    self.sidebar.toggleDark.text:SetText(LText("Dark: ") .. (self.db.unlockDarkOverlays and "On" or "Off"))
    self.sidebar.toggleCoords.text:SetText(LText("Coords: ") .. (self.db.unlockCoords and "On" or "Off"))

    local content = self.sidebar.content
    for _, widget in ipairs(self.sidebar.itemButtons) do
        widget:Hide()
    end
    wipe(self.sidebar.itemButtons)

    local offsetY = 0
    local lastGroup
    local headerIndex, rowIndex = 0, 0
    for _, key in ipairs(self.registryOrder) do
        if not self:IsElementHidden(key) then
            local def = self:GetElementDef(key)
            local group = def.group or "Other"
            if group ~= lastGroup then
                headerIndex = headerIndex + 1
                local header = self:AcquireSidebarHeader(headerIndex)
                header:ClearAllPoints()
                header:SetPoint("TOPLEFT", 0, offsetY)
                header.text:SetText(string.upper(LText(group)))
                header:Show()
                tinsert(self.sidebar.itemButtons, header)
                offsetY = offsetY - SIDEBAR_HEADER_HEIGHT
                lastGroup = group
            end

            rowIndex = rowIndex + 1
            local row = self:AcquireSidebarRow(rowIndex)
            row.key = key
            row.isHovered = false
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", 0, offsetY)
            row.text:SetText(LText(def.label or key))
            row:Show()
            tinsert(self.sidebar.itemButtons, row)
            offsetY = offsetY - SIDEBAR_ROW_HEIGHT - 1
        end
    end

    content:SetHeight(max(-offsetY + 10, 318))
    self:RefreshSidebarSelection()
end

function UM:ApplyTheme()
    local theme = GetUnlockTheme()

    if self.unlockFrame then
        if self.unlockFrame.overlay then
            self.unlockFrame.overlay:SetColorTexture(0.01, 0.01, 0.01, 0.20)
        end
        if self.guideVertical then
            self.guideVertical:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)
        end
        if self.guideHorizontal then
            self.guideHorizontal:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)
        end
    end

    if self.moverMenu then
        KT:AddBorder(self.moverMenu, theme.accent.r, theme.accent.g, theme.accent.b, 1)
        if self.moverMenu.snapList then
            KT:AddBorder(self.moverMenu.snapList, theme.accent.r, theme.accent.g, theme.accent.b, 1)
        end
        if self.RefreshMoverMenuFields and self.moverMenu.activeKey then
            self:RefreshMoverMenuFields()
        end
    end

    if self.sidebar then
        if self.sidebar.bgArt then
            self.sidebar.bgArt:SetVertexColor(theme.art.r, theme.art.g, theme.art.b, 1)
        end
        if self.sidebar.bgVeil then
            self.sidebar.bgVeil:SetVertexColor(theme.background.r, theme.background.g, theme.background.b, 0.12)
        end
        if self.sidebar.title then
            self.sidebar.title:SetTextColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
        end
        if self.sidebar.titleRule then
            ApplyTextureGradient(self.sidebar.titleRule, "HORIZONTAL",
                theme.accent.r, theme.accent.g, theme.accent.b, 0.24,
                theme.accent.r, theme.accent.g, theme.accent.b, 0)
        end
        if self.sidebar.header then
            self.sidebar.header:SetTextColor(theme.soft.r, theme.soft.g, theme.soft.b, 1)
        end
        if self.sidebar.headerRule then
            ApplyTextureGradient(self.sidebar.headerRule, "HORIZONTAL",
                theme.accent.r, theme.accent.g, theme.accent.b, 0.18,
                theme.accent.r, theme.accent.g, theme.accent.b, 0)
        end
        if self.sidebar.controlsPanel then
            ApplySidebarPanelStyle(self.sidebar.controlsPanel, self.sidebar.controlsPanel._ktUnlockPanelVariant or "controls")
        end
        if self.sidebar.listPanel then
            ApplySidebarPanelStyle(self.sidebar.listPanel, self.sidebar.listPanel._ktUnlockPanelVariant or "list")
        end
        if self.sidebar.footerPanel then
            ApplySidebarPanelStyle(self.sidebar.footerPanel, self.sidebar.footerPanel._ktUnlockPanelVariant or "footer")
        end
        StyleSidebarButton(self.sidebar.discard, "footer_red")
        StyleSidebarButton(self.sidebar.save, "footer_green")
        if self.sidebar.restore then StyleSidebarButton(self.sidebar.restore, "toggle") end
        if self.sidebar.import then StyleSidebarButton(self.sidebar.import, "toggle") end
        StyleSidebarButton(self.sidebar.toggleGrid, "toggle")
        StyleSidebarButton(self.sidebar.toggleSnap, "toggle")
        StyleSidebarButton(self.sidebar.toggleDark, "toggle")
        StyleSidebarButton(self.sidebar.toggleCoords, "toggle")
        if self.sidebar.scrollbarTrack then
            -- Keep the scrollbar frame on the active accent after a live theme change.
            -- Using theme.soft here left the old scrollbar edge visible until reload.
            KT:AddBorder(self.sidebar.scrollbarTrack, theme.accent.r, theme.accent.g, theme.accent.b, 0.55)
        end
        if self.sidebar.scrollbarThumbBorder or self.sidebar.scrollbarThumb then
            local scrollbar = self.sidebar.scroll and self.sidebar.scroll.ScrollBar
            local scrollbarState = self.sidebar.scrollbarDragging and "drag"
                or (scrollbar and scrollbar:IsMouseOver() and "hover" or "normal")
            SetScrollbarThumbState(self.sidebar, scrollbarState)
        end
        if self.sidebar.itemButtons then
            for _, button in ipairs(self.sidebar.itemButtons) do
                if button._ktUnlockVariant then
                    StyleSidebarButton(button, button._ktUnlockVariant)
                elseif button._ktUnlockPanelButton then
                    RefreshPanelButtonTheme(button)
                end
            end
        end
    end

    if self.guideVertical then
        self.guideVertical:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)
    end
    if self.guideHorizontal then
        self.guideHorizontal:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)
    end

    for _, mover in pairs(self.movers) do
        if not mover.isSelected then
            KT:AddBorder(mover, theme.accent.r, theme.accent.g, theme.accent.b, 1)
        end
        if mover.cog and mover.cog.icon then
            mover.cog.icon:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
        end
        if mover.close then
            KT:AddBackdrop(mover.close, theme.background.r, theme.background.g, theme.background.b, 0.94)
            KT:AddBorder(mover.close, theme.soft.r, theme.soft.g, theme.soft.b, 1)
            if mover.close.text then
                mover.close.text:SetTextColor(theme.text.r, theme.text.g, theme.text.b, 1)
            end
            mover.close:SetScript("OnEnter", function(widget)
                KT:AddBorder(widget, theme.accent.r, theme.accent.g, theme.accent.b, 1)
            end)
            mover.close:SetScript("OnLeave", function(widget)
                KT:AddBorder(widget, theme.soft.r, theme.soft.g, theme.soft.b, 1)
            end)
        end
        if mover.RefreshStyle then
            mover:RefreshStyle()
        end
    end

    if self.gridFrame and self.gridFrame:IsShown() then
        self:RebuildGrid()
    end

    self:RefreshSidebarSelection()
end

function UM:CreateUnlockFrame()
    if self.unlockFrame then return end

    local frame = CreateFrame("Frame", "KullThranUIUnlockMode", UIParent)
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(false)
    -- Propagate keyboard input so this overlay NEVER blocks the rest of the UI
    -- (bindings, ESC, game menu) even if it lingers shown while closed. Without
    -- this, a fullscreen keyboard-enabled frame swallows every key and ESC stops
    -- working until it is hidden again.
    frame:SetPropagateKeyboardInput(true)
    frame:EnableKeyboard(true)

    local overlay = frame:CreateTexture(nil, "BACKGROUND")
    overlay:SetAllPoints()
    overlay:SetColorTexture(0.01, 0.01, 0.01, 0.20)
    frame.overlay = overlay

    local logoSplash = CreateFrame("Frame", nil, frame)
    logoSplash:SetSize(200, 200)
    logoSplash:SetPoint("CENTER", UIParent, "CENTER", 0, 18)
    logoSplash:SetFrameLevel((frame:GetFrameLevel() or 0) + 100)
    logoSplash:EnableMouse(false)
    logoSplash:Hide()

    local logoGlow = logoSplash:CreateTexture(nil, "ARTWORK", nil, 1)
    logoGlow:SetSize(188, 188)
    logoGlow:SetPoint("CENTER")
    logoGlow:SetTexture(UNLOCK_LOGO_TEXTURE)
    logoGlow:SetRotation(math.rad(180))
    logoGlow:SetBlendMode("ADD")
    if logoGlow.SetDesaturated then
        logoGlow:SetDesaturated(true)
    end
    logoSplash.glow = logoGlow

    local logo = logoSplash:CreateTexture(nil, "OVERLAY", nil, 2)
    logo:SetSize(154, 154)
    logo:SetPoint("CENTER")
    logo:SetTexture(UNLOCK_LOGO_TEXTURE)
    logo:SetRotation(math.rad(180))
    if logo.SetDesaturated then
        logo:SetDesaturated(true)
    end
    logoSplash.logo = logo

    -- These are exact, complementary alpha cuts of the original PNG. Each
    -- piece remains a full-size square texture, so rotating and translating it
    -- cannot stretch or repeat the artwork as the previous procedural cut did.
    local function CreateDiagonalLogoPiece(texturePath)
        local piece = CreateFrame("Frame", nil, logoSplash)
        piece:SetSize(154, 154)
        piece:SetPoint("CENTER")
        piece:SetAlpha(0)

        local texture = piece:CreateTexture(nil, "OVERLAY", nil, 3)
        texture:SetAllPoints()
        texture:SetTexture(texturePath)
        texture:SetRotation(0)
        if texture.SetDesaturated then
            texture:SetDesaturated(true)
        end
        piece.texture = texture

        return piece
    end

    local logoPieceUpper = CreateDiagonalLogoPiece(UNLOCK_LOGO_CUT_UPPER_TEXTURE)
    local logoPieceLower = CreateDiagonalLogoPiece(UNLOCK_LOGO_CUT_LOWER_TEXTURE)
    logoSplash.pieceUpper = logoPieceUpper
    logoSplash.pieceLower = logoPieceLower

    local logoAnimation = logoSplash:CreateAnimationGroup()
    local fadeIn = logoAnimation:CreateAnimation("Alpha")
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(0.16)
    fadeIn:SetOrder(1)

    local scaleIn = logoAnimation:CreateAnimation("Scale")
    scaleIn:SetScaleFrom(0.72, 0.72)
    scaleIn:SetScaleTo(1, 1)
    scaleIn:SetDuration(0.24)
    scaleIn:SetOrder(1)
    scaleIn:SetSmoothing("OUT")

    local rotateLogo = logoAnimation:CreateAnimation("Rotation")
    rotateLogo:SetTarget(logo)
    rotateLogo:SetDegrees(-180)
    rotateLogo:SetDuration(0.50)
    rotateLogo:SetOrder(1)
    rotateLogo:SetSmoothing("OUT")

    local rotateGlow = logoAnimation:CreateAnimation("Rotation")
    rotateGlow:SetTarget(logoGlow)
    rotateGlow:SetDegrees(-180)
    rotateGlow:SetDuration(0.50)
    rotateGlow:SetOrder(1)
    rotateGlow:SetSmoothing("OUT")

    local hideWholeLogo = logoAnimation:CreateAnimation("Alpha")
    hideWholeLogo:SetTarget(logo)
    hideWholeLogo:SetFromAlpha(1)
    hideWholeLogo:SetToAlpha(0)
    hideWholeLogo:SetDuration(0.05)
    hideWholeLogo:SetOrder(2)

    local hideWholeGlow = logoAnimation:CreateAnimation("Alpha")
    hideWholeGlow:SetTarget(logoGlow)
    hideWholeGlow:SetFromAlpha(1)
    hideWholeGlow:SetToAlpha(0)
    hideWholeGlow:SetDuration(0.05)
    hideWholeGlow:SetOrder(2)

    local showUpperPiece = logoAnimation:CreateAnimation("Alpha")
    showUpperPiece:SetTarget(logoPieceUpper)
    showUpperPiece:SetFromAlpha(0)
    showUpperPiece:SetToAlpha(1)
    showUpperPiece:SetDuration(0.05)
    showUpperPiece:SetOrder(2)

    local showLowerPiece = logoAnimation:CreateAnimation("Alpha")
    showLowerPiece:SetTarget(logoPieceLower)
    showLowerPiece:SetFromAlpha(0)
    showLowerPiece:SetToAlpha(1)
    showLowerPiece:SetDuration(0.05)
    showLowerPiece:SetOrder(2)

    local openUpperPiece = logoAnimation:CreateAnimation("Translation")
    openUpperPiece:SetTarget(logoPieceUpper)
    openUpperPiece:SetOffset(32, -24)
    openUpperPiece:SetDuration(0.30)
    openUpperPiece:SetOrder(2)
    openUpperPiece:SetSmoothing("OUT")

    local openLowerPiece = logoAnimation:CreateAnimation("Translation")
    openLowerPiece:SetTarget(logoPieceLower)
    openLowerPiece:SetOffset(-32, 24)
    openLowerPiece:SetDuration(0.30)
    openLowerPiece:SetOrder(2)
    openLowerPiece:SetSmoothing("OUT")

    local splitHold = logoAnimation:CreateAnimation("Alpha")
    splitHold:SetFromAlpha(1)
    splitHold:SetToAlpha(1)
    splitHold:SetDuration(0.18)
    splitHold:SetOrder(3)

    local fadeOut = logoAnimation:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.24)
    fadeOut:SetOrder(4)

    logoAnimation:SetScript("OnFinished", function()
        logoSplash:Hide()
    end)
    logoAnimation:SetScript("OnStop", function()
        logoSplash:Hide()
    end)
    logoSplash.animation = logoAnimation
    self.openLogoSplash = logoSplash

    local theme = GetUnlockTheme()
    self.guideVertical = frame:CreateTexture(nil, "OVERLAY")
    self.guideVertical:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)
    self.guideVertical:SetWidth(1)
    self.guideVertical:Hide()

    self.guideHorizontal = frame:CreateTexture(nil, "OVERLAY")
    self.guideHorizontal:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)
    self.guideHorizontal:SetHeight(1)
    self.guideHorizontal:Hide()

    frame:SetScript("OnKeyDown", function(widget, key)
        local consume = false
        local dialogShown = self.unsavedDialog and self.unsavedDialog:IsShown()

        if key == "ESCAPE" then
            -- ESC se consume aqui: si llegaba al binding del juego abria el
            -- menu de juego y cerraba cualquier aviso nada mas abrirse.
            consume = true
            if dialogShown then
                self.unsavedDialog:Hide()
            elseif self.moverMenu and self.moverMenu:IsShown() then
                self.moverMenu:Hide()
            elseif self:HasUnsavedChanges() then
                self:PromptCloseUnlockMode()
            else
                self:CloseUnlockMode(false, true)
            end
        elseif self.selectedKey and not dialogShown
            and (key == "LEFT" or key == "RIGHT" or key == "UP" or key == "DOWN") then
            consume = true
            local delta = IsShiftKeyDown() and 10 or 1
            if key == "LEFT" then
                self:NudgeSelected(-delta, 0)
            elseif key == "RIGHT" then
                self:NudgeSelected(delta, 0)
            elseif key == "UP" then
                self:NudgeSelected(0, delta)
            else
                self:NudgeSelected(0, -delta)
            end
        end

        if not InCombatLockdown() then
            widget:SetPropagateKeyboardInput(not consume)
        end
    end)

    frame:Hide()
    self.unlockFrame = frame
    self:CreateGrid()
    self:CreateSidebar()
end

function UM:PlayOpenLogoAnimation()
    local splash = self.openLogoSplash
    if not (splash and splash.animation) then return end

    local theme = GetUnlockTheme()
    splash.logo:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
    splash.glow:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 0.48)
    splash.pieceUpper.texture:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
    splash.pieceLower.texture:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)

    if splash.animation:IsPlaying() then
        splash.animation:Stop()
    end
    splash.logo:SetAlpha(1)
    splash.logo:SetRotation(math.rad(180))
    splash.glow:SetAlpha(1)
    splash.glow:SetRotation(math.rad(180))
    splash.pieceUpper:ClearAllPoints()
    splash.pieceUpper:SetPoint("CENTER")
    splash.pieceUpper:SetAlpha(0)
    splash.pieceUpper.texture:SetRotation(0)
    splash.pieceLower:ClearAllPoints()
    splash.pieceLower:SetPoint("CENTER")
    splash.pieceLower:SetAlpha(0)
    splash.pieceLower.texture:SetRotation(0)
    splash:SetAlpha(1)
    splash:SetScale(1)
    splash:Show()
    splash.animation:Play()
end

function UM:NudgeSelected(deltaX, deltaY)
    local moved = false
    for _, key in ipairs(self:GetSelectedMoverKeys()) do
        local mover = self.movers[key]
        if mover then
            local left = (mover:GetLeft() or 0) + deltaX
            local top = (mover:GetTop() or 0) + deltaY
            SetFrameTopLeft(mover, left, top)
            self:ApplyMoverToElement(key, mover)
            mover:RefreshCoords()
            moved = true
        end
    end
    if moved then
        self:RefreshSidebarSelection()
    end
end

function UM:AnimateSidebarTarget(targetX, targetAlpha, logoAlpha)
    if not self.sidebar then return end
    local startX = 0
    if self.sidebar:GetNumPoints() > 0 then
        local _, _, _, xOfs = self.sidebar:GetPoint(1)
        startX = xOfs or 0
    end
    local startAlpha = self.sidebar.contentGroup:GetAlpha() or 1
    local startLogoAlpha = self.sidebar.idleLogo:GetAlpha() or 0
    
    local startTime = GetTime()
    local duration = 0.25
    
    self.sidebar:SetScript("OnUpdate", function(sidebar)
        local t = min((GetTime() - startTime) / duration, 1)
        local eased = EaseOutQuad(t)
        sidebar:ClearAllPoints()
        sidebar:SetPoint("LEFT", UIParent, "LEFT", Round(startX + (targetX - startX) * eased), 0)
        
        sidebar.contentGroup:SetAlpha(startAlpha + (targetAlpha - startAlpha) * eased)
        sidebar.idleLogo:SetAlpha(startLogoAlpha + (logoAlpha - startLogoAlpha) * eased)
        if sidebar.idleGrip then
            sidebar.idleGrip:SetAlpha(startLogoAlpha + (logoAlpha - startLogoAlpha) * eased)
            sidebar.idleGrip2:SetAlpha(startLogoAlpha + (logoAlpha - startLogoAlpha) * eased)
        end
        
        if t >= 1 then
            sidebar:SetScript("OnUpdate", nil)
            sidebar:ClearAllPoints()
            sidebar:SetPoint("LEFT", UIParent, "LEFT", targetX, 0)
            sidebar.contentGroup:SetAlpha(targetAlpha)
            sidebar.idleLogo:SetAlpha(logoAlpha)
            if sidebar.idleGrip then
                sidebar.idleGrip:SetAlpha(logoAlpha)
                sidebar.idleGrip2:SetAlpha(logoAlpha)
            end
        end
    end)
end

function UM:AnimateSidebarIn()
    if not self.sidebar then return end
    self.sidebar:ClearAllPoints()
    self.sidebar:SetPoint("LEFT", UIParent, "LEFT", -SIDEBAR_WIDTH, 0)
    self.sidebar.contentGroup:SetAlpha(0)
    self.sidebar.idleLogo:SetAlpha(0)
    if self.sidebar.idleGrip then
        self.sidebar.idleGrip:SetAlpha(0)
        self.sidebar.idleGrip2:SetAlpha(0)
    end
    self:AnimateSidebarTarget(0, 1, 0)
end

function UM:FadeInOpenUI()
    if UIFrameFadeIn then
        UIFrameFadeIn(self.unlockFrame, 0.30, 0, 1)
        UIFrameFadeIn(self.sidebar, 0.25, 0, 1)
        for _, mover in pairs(self.movers) do
            UIFrameFadeIn(mover, 0.40, 0, 1)
        end
    else
        self.unlockFrame:SetAlpha(1)
        self.sidebar:SetAlpha(1)
        for _, mover in pairs(self.movers) do
            mover:SetAlpha(1)
        end
    end
    self:AnimateSidebarIn()
end

function UM:RescaleOpenLayout()
    if not self.isOpen then return end

    local oldWidth = tonumber(self._unlockReferenceWidth)
    local oldHeight = tonumber(self._unlockReferenceHeight)
    local width, height = self:GetPositionReference()
    if not (oldWidth and oldWidth > 0 and oldHeight and oldHeight > 0) then
        self._unlockReferenceWidth = width
        self._unlockReferenceHeight = height
        return
    end

    local xRatio = width / oldWidth
    local yRatio = height / oldHeight
    if abs(xRatio - 1) < 0.0001 and abs(yRatio - 1) < 0.0001 then
        return
    end

    -- Do not move real frames on a scale/display change: that queued a
    -- pending position for EVERY element (committed on Save), dropping docks
    -- and anchors. Movers are re-synced from the real frames below instead.
    self._unlockReferenceWidth = width
    self._unlockReferenceHeight = height
    self:RebuildGrid()
    self:RefreshMovers()
end

function UM:OnUnlockDisplayScaleChanged()
    if not self.isOpen or self._unlockScaleRefreshQueued then
        return
    end

    self._unlockScaleRefreshQueued = true
    C_Timer.After(0, function()
        self._unlockScaleRefreshQueued = nil
        if self.isOpen then
            self:RescaleOpenLayout()
        end
    end)
end

function UM:OpenUnlockMode()
    if self.isOpen or InCombatLockdown() or (KT.IsBlizzardEditModeTransitionActive and KT:IsBlizzardEditModeTransitionActive()) then
        if InCombatLockdown() then
            KT:Print(LText("UnlockMode is unavailable in combat."))
        end
        return
    end

    local optionsMenu = KT and KT.MenuPrincipal
    if optionsMenu and optionsMenu.IsShown and optionsMenu:IsShown() and optionsMenu.Hide then
        optionsMenu:Hide()
        if _G.GameTooltip and _G.GameTooltip.Hide then
            _G.GameTooltip:Hide()
        end
    end

    self:EnsureDB()
    self:CreateUnlockFrame()
    self:UpdateRegistry()
    self._unlockReferenceWidth, self._unlockReferenceHeight = self:GetPositionReference()
    wipe(self.snapshotPositions)
    wipe(self.snapshotSizes)
    wipe(self.snapshotSnapTargets)
    wipe(self.pendingPositions)
    self.snapshotGenericSizes = self:CopyGenericSizes()
    wipe(self.touchedNativeSizes)
    self.hasChanges = false

    KT._unlockActive = true
    self.isOpen = true

    for _, key in ipairs(self.registryOrder) do
        if not self:IsElementHidden(key) then
            self:PrepareElementPositionForCurrentUI(key)
            self.snapshotPositions[key] = self:CaptureCurrentPosition(key)
            self.snapshotSnapTargets[key] = self:GetSnapTarget(key) or false
            if self:CanEditElementSize(key) then
                local width, height = self:GetEditableElementSize(key)
                if width and height then
                    self.snapshotSizes[key] = {
                        width = width,
                        height = height,
                    }
                end
            end
        end
    end

    self.unlockFrame:Show()
    self:SetUnlockKeyboardCapture(true)
    self.unlockFrame:SetAlpha(0)
    self.sidebar:SetAlpha(0)
    self.sidebar:Show()
    self.sidebar:SetFrameStrata("FULLSCREEN_DIALOG")
    self.sidebar:SetFrameLevel((self.unlockFrame and self.unlockFrame:GetFrameLevel() or 0) + 50)
    if self.sidebar.Raise then
        self.sidebar:Raise()
    end
    self:RebuildGrid()
    self:RefreshMovers()
    self:RefreshSidebar()
    self:ApplyTheme()
    self:HideGuides()

    C_Timer.After(0, function()
        if self.isOpen then
            self:RefreshMovers()
            self:FadeInOpenUI()
            self:PlayOpenLogoAnimation()
            
            -- Start idle timer logic
            self.sidebar.isIdle = false
            self.sidebar.idleTimer = 0
            self.idleTicker = C_Timer.NewTicker(0.1, function()
                if not self.isOpen then return end
                -- Use IsMouseOver on sidebar to detect if we should keep it open
                if self.sidebar:IsMouseOver(10, -10, -10, 10) then
                    if self.sidebar.isIdle then
                        self:AnimateSidebarTarget(0, 1, 0)
                        self.sidebar.isIdle = false
                    end
                    self.sidebar.idleTimer = 0
                else
                    if not self.sidebar.isIdle then
                        self.sidebar.idleTimer = (self.sidebar.idleTimer or 0) + 0.1
                        if self.sidebar.idleTimer >= 3.0 then
                            self:AnimateSidebarTarget(-SIDEBAR_WIDTH * 0.75, 0, 1)
                            self.sidebar.isIdle = true
                        end
                    end
                end
            end)
        end
    end)
end

function UM:SetUnlockKeyboardCapture(enabled)
    if not self.unlockFrame then return end
    -- A fullscreen keyboard-enabled frame swallows every key (bindings + ESC)
    -- while shown. Tie capture strictly to the open state and always propagate
    -- so a lingering overlay can never block the rest of the UI.
    self.unlockFrame:SetPropagateKeyboardInput(true)
    self.unlockFrame:EnableKeyboard(enabled == true)
end

function UM:CloseUnlockMode(saveChanges, force)
    if not self.isOpen then return end

    if saveChanges then
        self:CommitPositions()
    elseif not force and self:HasUnsavedChanges() then
        self:PromptCloseUnlockMode()
        return
    else
        self:RevertPositions()
    end

    self.isOpen = false
    self.isSuspended = false
    self._unlockReferenceWidth = nil
    self._unlockReferenceHeight = nil
    KT._unlockActive = false
    if type(_G.KUI_CDM_OnUnlockModeChanged) == "function" then
        pcall(_G.KUI_CDM_OnUnlockModeChanged, false)
    end
    -- Drop keyboard capture immediately so the fade-out window (and any
    -- interrupted close) never leaves bindings/ESC dead.
    self:SetUnlockKeyboardCapture(false)
    if self.unsavedDialog then
        self.unsavedDialog:Hide()
    end
    if self.moverMenu then
        self.moverMenu:Hide()
    end
    self.selectedKey = nil
    wipe(self.selectedKeys)
    self:HideGuides()

    for _, mover in pairs(self.movers) do
        mover:SetScript("OnUpdate", nil)
        mover.isDragging = false
        mover:Hide()
    end

    if self.idleTicker then
        self.idleTicker:Cancel()
        self.idleTicker = nil
    end

    if UIFrameFadeOut then
        UIFrameFadeOut(self.unlockFrame, 0.25, self.unlockFrame:GetAlpha(), 0)
        UIFrameFadeOut(self.sidebar, 0.25, self.sidebar:GetAlpha(), 0)
    end

    C_Timer.After(0.26, function()
        if not self.isOpen and self.unlockFrame then
            self.unlockFrame:Hide()
            self.sidebar:Hide()
            self.unlockFrame:SetAlpha(1)
            self.sidebar:SetAlpha(1)
        end
    end)
end

function UM:ToggleUnlockMode()
    if self.isOpen then
        self:CloseUnlockMode(false)
    else
        self:OpenUnlockMode()
    end
end

function UM:OnBlizzardEnterEditMode()
    -- Decoupled from Blizzard Edit Mode: do not auto-open KUI Unlock Mode.
    -- If both overlap, close KUI Unlock Mode to prevent confusing UI states.
    if self.isOpen then
        self:CloseUnlockMode(false, true)
    end
end

function UM:OnBlizzardExitEditMode()
    -- No-op (kept for backwards compatibility if some external hook calls it).
end

function UM:OnCombatStart()
    if not self.isOpen then return end
    self.isSuspended = true
    KT._unlockActive = false
    self:SetUnlockKeyboardCapture(false)
    self.unlockFrame:Hide()
    self.sidebar:Hide()
    for _, mover in pairs(self.movers) do
        mover:SetScript("OnUpdate", nil)
        mover.isDragging = false
        mover:Hide()
    end
    self:HideGuides()
end

function UM:OnCombatEnd()
    if not self.isSuspended then return end
    C_Timer.After(0.5, function()
        if not self.isOpen or InCombatLockdown() then return end
        self.isSuspended = false
        KT._unlockActive = true
        self:SetUnlockKeyboardCapture(true)
        self.unlockFrame:Show()
        self.sidebar:Show()
        self:RebuildGrid()
        self:RefreshMovers()
        self:RefreshSidebar()
    end)
end

