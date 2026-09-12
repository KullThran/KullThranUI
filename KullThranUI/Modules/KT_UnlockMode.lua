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
local MOVER_HOVER_DURATION = 0.15
local MOVER_HOVER_EXPANSION = 4
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
        print("|cFFFF0000[KT UnlockMode Error]|r", result)
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
    if not button then return end

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

local function StyleMenuInputBox(box)
    if not box then return end

    local theme = GetUnlockTheme()
    KT:AddBackdrop(box, theme.background.r, theme.background.g, theme.background.b, 0.96)
    KT:AddBorder(box, theme.soft.r, theme.soft.g, theme.soft.b, 1)
    box:SetTextColor(theme.text.r, theme.text.g, theme.text.b, 1)
end

local function CreateMenuInputBox(parent, width, height)
    local box = CreateFrame("EditBox", nil, parent)
    box:SetSize(width or 54, height or 18)
    box:SetAutoFocus(false)
    box:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
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
    if not button then return end

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

    StaticPopupDialogs["KULLTHRANUI_UNLOCKMODE_UNSAVED"] = {
        text = "Save KT UnlockMode changes before closing?",
        button1 = "Save",
        button2 = "Discard",
        button3 = "Cancel",
        OnAccept = function()
            UM:CloseUnlockMode(true, true)
        end,
        OnCancel = function()
            UM:CloseUnlockMode(false, true)
        end,
        OnAlt = function()
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        preferredIndex = 3,
    }
end

function UM:PromptCloseUnlockMode()
    StaticPopup_Show("KULLTHRANUI_UNLOCKMODE_UNSAVED")
end

function UM:OnEnable()
    self:EnsureDB()
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")

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
    end
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

    if def and type(def.setScale) == "function" and pos.scale then
        SafeCall(def.setScale, key, pos.scale)
    elseif pos.scale and frame.SetScale then
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

    return def.label or targetKey
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

function UM:CanEditElementSize(key)
    local def = self:GetElementDef(key)
    return def
        and type(def.setEditableSize) == "function"
        and (type(def.getEditableSize) == "function" or type(def.getSize) == "function")
        and true or false
end

function UM:GetEditableElementSize(key)
    local def = self:GetElementDef(key)
    if not def then
        return nil, nil
    end

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

function UM:SetEditableElementSize(key, width, height)
    local def = self:GetElementDef(key)
    if not (def and type(def.setEditableSize) == "function") then
        return
    end

    width = tonumber(width)
    height = tonumber(height)
    if not (width and height) then
        return
    end

    SafeCall(def.setEditableSize, key, Round(max(1, width)), Round(max(1, height)))
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
    for key, targetKey in pairs(self.snapshotSnapTargets or {}) do
        if targetKey and targetKey ~= false then
            self.db.snapTargets[key] = targetKey
        elseif self.db and self.db.snapTargets then
            self.db.snapTargets[key] = nil
        end
    end

    for key, size in pairs(self.snapshotSizes or {}) do
        local def = self:GetElementDef(key)
        if def and type(def.setEditableSize) == "function" and size and size.width and size.height then
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

function UM:RefreshSidebarSelection()
    if not self.sidebar or not self.sidebar.itemButtons then return end
    for _, button in ipairs(self.sidebar.itemButtons) do
        if button.key then
            StyleSidebarButton(button, "item", self:IsMoverSelected(button.key))
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
    KT:AddBackdrop(mover, 0, 0, 0, 0.22)
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

    mover.hoverAnimator = CreateFrame("Frame", nil, mover)
    mover.hoverProgress = 0
    mover.hoverTarget = 0
    mover.isHovered = false

    mover.ApplyHoverVisual = function(s, progress)
        progress = max(0, min(progress or 0, 1))
        s.hoverProgress = progress

        local eased = progress * progress * (3 - (2 * progress))
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
            if self.db.unlockDarkOverlays then
                local baseAlpha = s.isSelected and 0.30 or 0.22
                s.bgKT:SetColorTexture(
                    0.03 * eased,
                    0.03 * eased,
                    0.03 * eased,
                    baseAlpha + ((0.34 - baseAlpha) * eased)
                )
            else
                s.bgKT:SetColorTexture(0.03 * eased, 0.03 * eased, 0.03 * eased, 0.02 + (0.06 * eased))
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

    mover.SetHoverTarget = function(s, target)
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
    end

    mover.Sync = function(s)
        local def = self:GetElementDef(s.key)
        local left, top, width, height = self:GetElementRect(s.key)
        s:SetSize(max(width, 32), max(height, 24))
        SetFrameTopLeft(s, left, top)
        s.label:SetText(def and (def.label or s.key) or s.key)
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
        elseif not self:IsMoverSelected(s.key) or self:GetSelectedMoverCount() <= 1 then
            self:SelectMover(s.key)
        end
        s.isDragging = true
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
    local snapshot = self.snapshotPositions[key]
    if mover and snapshot then
        self:ApplyStoredPositionToElement(key, snapshot)
        mover:Sync()
        self.pendingPositions[key] = nil
        self.hasChanges = next(self.pendingPositions) ~= nil
        if self.moverMenu and self.moverMenu:IsShown() and self.moverMenu.activeKey == key and self.RefreshMoverMenuFields then
            self:RefreshMoverMenuFields()
        end
    end
end

function UM:RefreshMoverMenuFields()
    local menuFrame = self.moverMenu
    if not (menuFrame and menuFrame.activeKey) then
        return
    end

    local key = menuFrame.activeKey
    local theme = GetUnlockTheme()
    local canEditSize = self:CanEditElementSize(key)
    local width, height = self:GetEditableElementSize(key)
    local x, y = self:GetMoverStoredXY(key)

    menuFrame.fadeTargetID = ResolveMouseoverTargetID(key, self:GetElementDef(key))

    if menuFrame.widthRow then
        menuFrame.widthRow:SetShown(canEditSize)
        if canEditSize then
            menuFrame.widthRow.input:SetText(tostring(width or ""))
        end
        menuFrame.widthRow.label:SetTextColor(theme.muted.r, theme.muted.g, theme.muted.b, 1)
        StyleMenuInputBox(menuFrame.widthRow.input)
    end
    if menuFrame.heightRow then
        menuFrame.heightRow:SetShown(canEditSize)
        if canEditSize then
            menuFrame.heightRow.input:SetText(tostring(height or ""))
        end
        menuFrame.heightRow.label:SetTextColor(theme.muted.r, theme.muted.g, theme.muted.b, 1)
        StyleMenuInputBox(menuFrame.heightRow.input)
    end
    if menuFrame.xRow then
        menuFrame.xRow.input:SetText(tostring(x or 0))
        menuFrame.xRow.label:SetTextColor(theme.muted.r, theme.muted.g, theme.muted.b, 1)
        StyleMenuInputBox(menuFrame.xRow.input)
    end
    if menuFrame.yRow then
        menuFrame.yRow.input:SetText(tostring(y or 0))
        menuFrame.yRow.label:SetTextColor(theme.muted.r, theme.muted.g, theme.muted.b, 1)
        StyleMenuInputBox(menuFrame.yRow.input)
    end

    if menuFrame.snapHeader then
        menuFrame.snapHeader:SetTextColor(theme.muted.r, theme.muted.g, theme.muted.b, 1)
    end
    if menuFrame.snapButton then
        RefreshPanelButtonTheme(menuFrame.snapButton)
        menuFrame.snapButton.text:SetText(self:GetSnapTargetLabel(key))
        menuFrame.snapButton.text:SetTextColor(theme.text.r, theme.text.g, theme.text.b, 1)
        if menuFrame.snapButton.arrow then
            menuFrame.snapButton.arrow:SetTextColor(theme.soft.r, theme.soft.g, theme.soft.b, 1)
        end
    end

    if menuFrame.fade and menuFrame.fade.SetVisualState then
        RefreshPanelButtonTheme(menuFrame.fade)
        menuFrame.fade:SetVisualState(GetMouseoverSetting(menuFrame.fadeTargetID))
    end
    if menuFrame.center then
        RefreshPanelButtonTheme(menuFrame.center)
    end
    if menuFrame.reset then
        RefreshPanelButtonTheme(menuFrame.reset)
    end

    if menuFrame.UpdateLayout then
        menuFrame:UpdateLayout()
    end

    if menuFrame.snapList and menuFrame.snapList:IsShown() then
        self:ToggleMoverSnapList(nil, true)
    end
end

function UM:ToggleMoverSnapList(anchorButton, forceRefresh)
    local menuFrame = self.moverMenu
    local snapList = menuFrame and menuFrame.snapList
    if not (menuFrame and snapList and menuFrame.activeKey) then
        return
    end

    if snapList:IsShown() and not forceRefresh then
        snapList:Hide()
        return
    end

    snapList.buttons = snapList.buttons or {}
    for _, button in ipairs(snapList.buttons) do
        button:Hide()
    end

    local theme = GetUnlockTheme()
    local options = self:GetSnapTargetOptions(menuFrame.activeKey)
    local currentTarget = self:GetSnapTarget(menuFrame.activeKey)
    local buttonWidth = 170
    local buttonHeight = 20

    for index, option in ipairs(options) do
        local button = snapList.buttons[index]
        if not button then
            button = CreatePanelButton(snapList, buttonWidth, buttonHeight, "")
            button.text:ClearAllPoints()
            button.text:SetPoint("LEFT", 8, 0)
            button.text:SetPoint("RIGHT", -8, 0)
            button.text:SetJustifyH("LEFT")
            snapList.buttons[index] = button
        end

        button:SetPoint("TOPLEFT", 5, -(5 + ((index - 1) * (buttonHeight + 2))))
        button.text:SetText(option.label or "")
        local isSelected = (option.value == nil and currentTarget == nil) or option.value == currentTarget
        if isSelected then
            button.normalColor = { theme.active.r, theme.active.g, theme.active.b, 0.96 }
            button.hoverColor = { theme.activeHover.r, theme.activeHover.g, theme.activeHover.b, 1.0 }
            if button.bgKT then
                button.bgKT:SetColorTexture(unpack(button.normalColor))
            end
            KT:AddBorder(button, theme.accent.r, theme.accent.g, theme.accent.b, 1)
            button.text:SetTextColor(1, 1, 1, 1)
        else
            button.normalColor = { theme.background.r, theme.background.g, theme.background.b, 0.94 }
            button.hoverColor = { theme.hover.r, theme.hover.g, theme.hover.b, 0.98 }
            if button.bgKT then
                button.bgKT:SetColorTexture(unpack(button.normalColor))
            end
            KT:AddBorder(button, theme.soft.r, theme.soft.g, theme.soft.b, 1)
            button.text:SetTextColor(theme.text.r, theme.text.g, theme.text.b, 1)
        end
        button:Show()

        button:SetScript("OnClick", function()
            self:SetSnapTarget(menuFrame.activeKey, option.value)
            snapList:Hide()
            self:RefreshMoverMenuFields()
        end)
    end

    snapList:SetSize(buttonWidth + 10, 10 + (#options * (buttonHeight + 2)))
    snapList:ClearAllPoints()
    snapList:SetPoint("TOPLEFT", anchorButton or menuFrame.snapButton, "BOTTOMLEFT", 0, -4)
    snapList:Show()
end

function UM:OpenMoverMenu(key, anchor)
    local menuFrame = self.moverMenu
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "KullThranUIUnlockModeMenu", self.unlockFrame)
        menuFrame:SetSize(190, 190)
        menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")
        menuFrame:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 80)
        menuFrame:SetClampedToScreen(true)
        KT:AddBackdrop(menuFrame, 0.02, 0.03, 0.04, 0.96)
        
        local theme = GetUnlockTheme()
        menuFrame.shadowArt = menuFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
        menuFrame.shadowArt:SetPoint("TOPLEFT", menuFrame, "TOPLEFT", 6, -6)
        menuFrame.shadowArt:SetPoint("BOTTOMRIGHT", menuFrame, "BOTTOMRIGHT", 6, -6)
        menuFrame.shadowArt:SetTexture(SIDEBAR_TEXTURE)
        menuFrame.shadowArt:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 0.5)

        menuFrame.bgArt = menuFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
        menuFrame.bgArt:SetAllPoints()
        menuFrame.bgArt:SetTexture(SIDEBAR_TEXTURE)
        menuFrame.bgArt:SetVertexColor(theme.background.r, theme.background.g, theme.background.b, 0.98)
        KT:AddBorder(menuFrame, MOVER_R, MOVER_G, MOVER_B, 1)

        local function CreateValueRow(parent, labelText)
            local row = CreateFrame("Frame", nil, parent)
            row:SetSize(174, 20)
            row.label = CreateText(row, 10, "LEFT")
            row.label:SetPoint("LEFT", 2, 0)
            row.label:SetText(LText(labelText))
            row.input = CreateMenuInputBox(row, 62, 18)
            row.input:SetPoint("RIGHT", -2, 0)
            row.CommitValue = function(selfRow)
                if not (menuFrame and menuFrame.activeKey and selfRow.applyValue) then
                    return
                end
                local value = tonumber(selfRow.input:GetText())
                if not value then
                    UM:RefreshMoverMenuFields()
                    return
                end
                selfRow.applyValue(Round(value))
                UM:RefreshMoverMenuFields()
            end
            row.input:SetScript("OnEnterPressed", function(self)
                row:CommitValue()
                self:ClearFocus()
            end)
            row.input:SetScript("OnEscapePressed", function(self)
                self:ClearFocus()
                UM:RefreshMoverMenuFields()
            end)
            row.input:HookScript("OnEditFocusLost", function()
                row:CommitValue()
            end)
            return row
        end

        menuFrame.widthRow = CreateValueRow(menuFrame, "Width")
        menuFrame.widthRow.applyValue = function(value)
            local _, currentHeight = self:GetEditableElementSize(menuFrame.activeKey)
            self:SetEditableElementSize(menuFrame.activeKey, value, currentHeight or value)
        end

        menuFrame.heightRow = CreateValueRow(menuFrame, "Height")
        menuFrame.heightRow.applyValue = function(value)
            local currentWidth = self:GetEditableElementSize(menuFrame.activeKey)
            self:SetEditableElementSize(menuFrame.activeKey, currentWidth or value, value)
        end

        menuFrame.xRow = CreateValueRow(menuFrame, "X Position")
        menuFrame.xRow.applyValue = function(value)
            local _, currentY = self:GetMoverStoredXY(menuFrame.activeKey)
            self:SetMoverStoredXY(menuFrame.activeKey, value, currentY)
        end

        menuFrame.yRow = CreateValueRow(menuFrame, "Y Position")
        menuFrame.yRow.applyValue = function(value)
            local currentX = self:GetMoverStoredXY(menuFrame.activeKey)
            self:SetMoverStoredXY(menuFrame.activeKey, currentX, value)
        end

        menuFrame.snapHeader = CreateText(menuFrame, 10, "LEFT")
        menuFrame.snapHeader:SetText(LText("Select Snap Target"))

        menuFrame.snapButton = CreatePanelButton(menuFrame, 174, 22, "")
        menuFrame.snapButton.text:ClearAllPoints()
        menuFrame.snapButton.text:SetPoint("LEFT", 8, 0)
        menuFrame.snapButton.text:SetPoint("RIGHT", -18, 0)
        menuFrame.snapButton.text:SetJustifyH("LEFT")
        menuFrame.snapButton.arrow = CreateText(menuFrame.snapButton, 12, "RIGHT")
        menuFrame.snapButton.arrow:SetPoint("RIGHT", -8, 0)
        menuFrame.snapButton.arrow:SetText(">")
        menuFrame.snapButton:SetScript("OnClick", function(button)
            self:ToggleMoverSnapList(button)
        end)

        menuFrame.fade = CreatePanelButton(menuFrame, 174, 22, LText("Fade on Mouseover"))
        menuFrame.fade.text:ClearAllPoints()
        menuFrame.fade.text:SetPoint("LEFT", 8, 0)
        menuFrame.fade.text:SetJustifyH("LEFT")
        menuFrame.fade.indicator = CreateText(menuFrame.fade, 11, "RIGHT")
        menuFrame.fade.indicator:SetPoint("RIGHT", -8, 0)
        menuFrame.fade.SetVisualState = function(button, enabled)
            button.isChecked = enabled == true
            if button.isChecked then
                button.indicator:SetText(LText("ON"))
                button.indicator:SetTextColor(0.72, 1, 0.76, 1)
            else
                button.indicator:SetText(LText("OFF"))
                button.indicator:SetTextColor(1, 0.82, 0.82, 1)
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

        menuFrame.configure = CreatePanelButton(menuFrame, 174, 22, LText("Open Configuration"))
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

        menuFrame.center = CreatePanelButton(menuFrame, 174, 22, LText("Center on Screen"))
        menuFrame.center:SetScript("OnClick", function()
            if menuFrame.activeKey then
                self:CenterMover(menuFrame.activeKey)
                self:RefreshMoverMenuFields()
            end
        end)

        menuFrame.reset = CreatePanelButton(menuFrame, 174, 22, LText("Reset Position"))
        menuFrame.reset:SetScript("OnClick", function()
            if menuFrame.activeKey then
                self:ResetMover(menuFrame.activeKey)
                self:RefreshMoverMenuFields()
            end
        end)

        menuFrame.snapList = CreateFrame("Frame", nil, self.unlockFrame)
        menuFrame.snapList:SetFrameStrata("FULLSCREEN_DIALOG")
        menuFrame.snapList:SetFrameLevel(menuFrame:GetFrameLevel() + 5)
        menuFrame.snapList:SetClampedToScreen(true)
        KT:AddBackdrop(menuFrame.snapList, 0.02, 0.03, 0.04, 0.98)
        KT:AddBorder(menuFrame.snapList, MOVER_R, MOVER_G, MOVER_B, 1)
        menuFrame.snapList:Hide()

        menuFrame.UpdateLayout = function(frame)
            local y = -8

            local function PlaceRow(row, extraGap)
                if not (row and row:IsShown()) then
                    return
                end
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", 8, y)
                y = y - row:GetHeight() - (extraGap or 4)
            end

            PlaceRow(frame.widthRow)
            PlaceRow(frame.heightRow)
            PlaceRow(frame.xRow)
            PlaceRow(frame.yRow, 6)

            frame.snapHeader:ClearAllPoints()
            frame.snapHeader:SetPoint("TOPLEFT", 10, y)
            y = y - 14

            frame.snapButton:ClearAllPoints()
            frame.snapButton:SetPoint("TOPLEFT", 8, y)
            y = y - 26

            if frame.fadeTargetID then
                frame.fade:Show()
                frame.fade:SetVisualState(GetMouseoverSetting(frame.fadeTargetID))
                PlaceRow(frame.fade)
            else
                frame.fade:Hide()
            end

            PlaceRow(frame.configure)
            PlaceRow(frame.center)
            PlaceRow(frame.reset)

            frame:SetHeight(abs(y) + 8)
        end

        menuFrame:SetScript("OnHide", function(frame)
            if frame.snapList then
                frame.snapList:Hide()
            end
        end)

        menuFrame:Hide()
        self.moverMenu = menuFrame
    end

    if menuFrame:IsShown() and menuFrame.activeKey == key then
        menuFrame:Hide()
        return
    end

    menuFrame.activeKey = key
    if menuFrame.snapList then
        menuFrame.snapList:Hide()
    end
    self:RefreshMoverMenuFields()
    menuFrame:ClearAllPoints()
    menuFrame:SetPoint("TOPLEFT", anchor or self.movers[key] or self.unlockFrame, "TOPRIGHT", 6, 0)
    menuFrame:Show()
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

    sidebar.toggleGrid = CreatePanelButton(sidebar.contentGroup, 182, 28, "")
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

    sidebar.toggleSnap = CreatePanelButton(sidebar.contentGroup, 182, 28, "")
    sidebar.toggleSnap:SetPoint("TOPLEFT", sidebar.toggleGrid, "BOTTOMLEFT", 0, -6)
    StyleSidebarButton(sidebar.toggleSnap, "toggle")
    sidebar.toggleSnap:SetScript("OnClick", function()
        self.db.unlockSnap = not self.db.unlockSnap
        self:RefreshSidebar()
    end)

    sidebar.toggleDark = CreatePanelButton(sidebar.contentGroup, 182, 28, "")
    sidebar.toggleDark:SetPoint("TOPLEFT", sidebar.toggleSnap, "BOTTOMLEFT", 0, -6)
    StyleSidebarButton(sidebar.toggleDark, "toggle")
    sidebar.toggleDark:SetScript("OnClick", function()
        self.db.unlockDarkOverlays = not self.db.unlockDarkOverlays
        for _, mover in pairs(self.movers) do
            mover:RefreshStyle()
        end
        self:RefreshSidebar()
    end)

    sidebar.toggleCoords = CreatePanelButton(sidebar.contentGroup, 182, 28, "")
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

    sidebar.restore = CreatePanelButton(sidebar.contentGroup, 180, 22, LText("Restore Defaults"))
    sidebar.restore:SetPoint("BOTTOMLEFT", sidebar.footerPanel, "BOTTOMLEFT", 6, 70)
    StyleSidebarButton(sidebar.restore, "toggle")
    sidebar.restore:SetScript("OnClick", function()
        StaticPopupDialogs["KULLTHRANUI_UNLOCKMODE_RESTORE"] = {
            text = LText("Are you sure you want to restore default positions for all elements?"),
            button1 = LText("Yes"),
            button2 = LText("No"),
            OnAccept = function()
                wipe(UM.db.frames)
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

    sidebar.import = CreatePanelButton(sidebar.contentGroup, 180, 22, LText("Import Profile"))
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

    sidebar.discard = CreatePanelButton(sidebar.contentGroup, 86, 22, LText("Discard"))
    sidebar.discard:SetPoint("BOTTOMLEFT", sidebar.footerPanel, "BOTTOMLEFT", 6, 6)
    StyleSidebarButton(sidebar.discard, "footer_red")
    sidebar.discard:SetScript("OnClick", function()
        if self.hasChanges then
            StaticPopup_Show("KULLTHRANUI_UNLOCKMODE_UNSAVED")
            return
        end
        self:CloseUnlockMode(false, true)
    end)

    sidebar.save = CreatePanelButton(sidebar.contentGroup, 86, 22, LText("Save"))
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
    for _, button in ipairs(self.sidebar.itemButtons) do
        button:Hide()
    end
    wipe(self.sidebar.itemButtons)

    local offsetY = -2
    local lastGroup
    for _, key in ipairs(self.registryOrder) do
        if not self:IsElementHidden(key) then
            local def = self:GetElementDef(key)
            local group = def.group or "Other"
            if group ~= lastGroup then
                local groupButton = CreatePanelButton(content, 178, 24, string.upper(group))
                groupButton:SetPoint("TOPLEFT", 0, offsetY)
                StyleSidebarButton(groupButton, "group")
                groupButton:Disable()
                groupButton.text:SetJustifyH("LEFT")
                groupButton.text:SetPoint("LEFT", 0, 0)
                tinsert(self.sidebar.itemButtons, groupButton)
                offsetY = offsetY - 22
                lastGroup = group
            end

            local item = CreatePanelButton(content, 178, 24, def.label or key)
            item.key = key
            item:SetPoint("TOPLEFT", 0, offsetY)
            StyleSidebarButton(item, "item")
            item.text:SetJustifyH("LEFT")
            item.text:SetPoint("LEFT", 6, 0)
            item:SetScript("OnClick", function()
                if IsShiftKeyDown() then
                    self:ToggleMoverSelection(key)
                else
                    self:SelectMover(key)
                end
                local mover = self.movers[key]
                if mover then
                    mover:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 60)
                end
            end)
            tinsert(self.sidebar.itemButtons, item)
            offsetY = offsetY - 22
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
            KT:AddBorder(self.sidebar.scrollbarTrack, theme.soft.r, theme.soft.g, theme.soft.b, 1)
        end
        if self.sidebar.scrollbarThumbBorder or self.sidebar.scrollbarThumb then
            SetScrollbarThumbState(self.sidebar, self.sidebar.scrollbarDragging and "drag" or "normal")
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

    frame:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" then
            if self.hasChanges then
                self:PromptCloseUnlockMode()
            else
                self:CloseUnlockMode(false, true)
            end
            return
        end

        if not self.selectedKey then return end
        local delta = IsShiftKeyDown() and 10 or 1
        if key == "LEFT" then
            self:NudgeSelected(-delta, 0)
        elseif key == "RIGHT" then
            self:NudgeSelected(delta, 0)
        elseif key == "UP" then
            self:NudgeSelected(0, delta)
        elseif key == "DOWN" then
            self:NudgeSelected(0, -delta)
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

function UM:OpenUnlockMode()
    if self.isOpen or InCombatLockdown() or (KT.IsBlizzardEditModeTransitionActive and KT:IsBlizzardEditModeTransitionActive()) then
        if InCombatLockdown() then
            KT:Print("UnlockMode is unavailable in combat.")
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
    wipe(self.snapshotPositions)
    wipe(self.snapshotSizes)
    wipe(self.snapshotSnapTargets)
    wipe(self.pendingPositions)
    self.hasChanges = false

    KT._unlockActive = true
    self.isOpen = true

    for _, key in ipairs(self.registryOrder) do
        if not self:IsElementHidden(key) then
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
    elseif not force and self.hasChanges then
        self:PromptCloseUnlockMode()
        return
    else
        self:RevertPositions()
    end

    self.isOpen = false
    self.isSuspended = false
    KT._unlockActive = false
    -- Drop keyboard capture immediately so the fade-out window (and any
    -- interrupted close) never leaves bindings/ESC dead.
    self:SetUnlockKeyboardCapture(false)
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

