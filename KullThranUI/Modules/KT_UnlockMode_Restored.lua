local addonName, ns = ...\r
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")\r
local UM = KT:NewModule("UnlockMode", "AceEvent-3.0", "AceHook-3.0")\r
\r
local _G = _G\r
local UIParent = UIParent\r
local CreateFrame = CreateFrame\r
local InCombatLockdown = InCombatLockdown\r
local GetCursorPosition = GetCursorPosition\r
local floor = math.floor\r
local abs = math.abs\r
local max = math.max\r
local min = math.min\r
local pairs = pairs\r
local ipairs = ipairs\r
local unpack = unpack or table.unpack\r
local tinsert = table.insert\r
local wipe = wipe\r
\r
local MOVER_R, MOVER_G, MOVER_B = 0.85, 0.15, 0.15\r
local EMPTY = {}\r
local GRID_SIZE = 32\r
local SNAP_DISTANCE = 6\r
local MOVER_HOVER_DURATION = 0.15\r
local MOVER_HOVER_EXPANSION = 4\r
local SIDEBAR_WIDTH = 184\r
local SIDEBAR_HEIGHT = 713\r
local SIDEBAR_BG = { r = 0.01, g = 0.01, b = 0.01, a = 0.88 }\r
local SIDEBAR_ACCENT = { r = 0.96, g = 0.12, b = 0.28, a = 1.0 }\r
local SIDEBAR_ACCENT_SOFT = { r = 0.42, g = 0.04, b = 0.10, a = 0.95 }\r
local SIDEBAR_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\BackgroundEditMode.png"\r
local SIDEBAR_BUTTON_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Button.png"\r
local SIDEBAR_GLOSS_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\gloss.tga"
local UNLOCK_LOGO_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\KUIBlanco.png"
local WHITE8X8 = "Interface\\Buttons\\WHITE8x8"
local SIDEBAR_TOP_SAFE = 38\r
local SIDEBAR_BOTTOM_SAFE = 42\r
local ICON_COG = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\cogs.png"\r
local ICON_RESET = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\unlock-reset.png"\r
local ICON_CENTER = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\unlock-center.png"\r
local MOUSEOVER_SETTING_KEYS = {\r
    bar1 = { section = "actionbars", key = "fadeBar1" },\r
    bar2 = { section = "actionbars", key = "fadeBar2" },\r
    bar3 = { section = "actionbars", key = "fadeBar3" },\r
    bar4 = { section = "actionbars", key = "fadeBar4" },\r
    bar5 = { section = "actionbars", key = "fadeBar5" },\r
    bar6 = { section = "actionbars", key = "fadeBar6" },\r
    bar7 = { section = "actionbars", key = "fadeBar7" },\r
    bar8 = { section = "actionbars", key = "fadeBar8" },\r
    pet = { section = "actionbars", key = "fadePet" },\r
    stance = { section = "actionbars", key = "fadeStance" },\r
    bags = { section = "blizzframes", key = "fadeBags" },\r
    micro = { section = "blizzframes", key = "fadeMicroMenu" },\r
    tracker = { section = "blizzframes", key = "fadeObjectiveTracker" },\r
    status = { section = "blizzframes", key = "fadeStatusBar" },\r
    queue = { section = "blizzframes", key = "fadeQueueStatus" },\r
}\r
local MOUSEOVER_KEY_ALIASES = {\r
    action_bar_1 = "bar1",\r
    action_bar_2 = "bar2",\r
    action_bar_3 = "bar3",\r
    action_bar_4 = "bar4",\r
    action_bar_5 = "bar5",\r
    action_bar_6 = "bar6",\r
    action_bar_7 = "bar7",\r
    action_bar_8 = "bar8",\r
    main_action_bar = "bar1",\r
    pet_bar = "pet",\r
    stance_bar = "stance",\r
    stance_bar_1 = "stance",\r
    shapeshift_bar = "stance",\r
    bags = "bags",\r
    micro_menu = "micro",\r
    objective_tracker = "tracker",\r
    status_bar = "status",\r
    status_bar_1 = "status",\r
    lfg_eye = "queue",\r
    queue_status = "queue",\r
}\r
\r
KT.UnlockElements = KT.UnlockElements or {}\r
KT.MovableElements = KT.UnlockElements\r
\r
local function LText(text)\r
    if type(text) ~= "string" then\r
        return text\r
    end\r
    if KT and KT.GetLocale then\r
        local L = KT:GetLocale()\r
        if L and L[text] then\r
            return L[text]\r
        end\r
    end\r
    return text\r
end\r
\r
local function Round(value)\r
    if value >= 0 then\r
        return floor(value + 0.5)\r
    end\r
    return floor(value - 0.5)\r
end\r
\r
local function CopyPosition(pos)\r
    if not pos then return nil end\r
    return {\r
        point = pos.point,\r
        relativePoint = pos.relativePoint,\r
        x = pos.x,\r
        y = pos.y,\r
        scale = pos.scale,\r
    }\r
end\r
\r
local function EaseOutQuad(t)\r
    return 1 - (1 - t) * (1 - t)\r
end\r
\r
local function SafeCall(func, ...)\r
    if type(func) ~= "function" then return end\r
    local ok, result = pcall(func, ...)\r
    if not ok and KT.db and KT.db.profile and KT.db.profile.debugMode then\r
        print("|cFFFF0000[KT UnlockMode Error]|r", result)\r
    end\r
    return ok, result\r
end\r
\r
local function ReadThemeColor(color, fallbackR, fallbackG, fallbackB, fallbackA)\r
    if type(color) ~= "table" then\r
        return fallbackR, fallbackG, fallbackB, fallbackA\r
    end\r
\r
    return color.r or fallbackR,\r
        color.g or fallbackG,\r
        color.b or fallbackB,\r
        color.a or fallbackA\r
end\r
\r
local function BlendThemeColor(r1, g1, b1, r2, g2, b2, amount)\r
    local t = max(0, min(amount or 0, 1))\r
    return r1 + ((r2 - r1) * t),\r
        g1 + ((g2 - g1) * t),\r
        b1 + ((b2 - b1) * t)\r
end\r
\r
local function SetThemeColor(target, r, g, b, a)\r
    if not target then\r
        return\r
    end\r
\r
    target.r, target.g, target.b, target.a = r, g, b, a\r
end\r
\r
local GetUnlockTheme\r
\r
local function ApplyTextureGradient(texture, orientation, r1, g1, b1, a1, r2, g2, b2, a2)\r
    if not texture then\r
        return\r
    end\r
\r
    if texture.SetGradientAlpha then\r
        texture:SetGradientAlpha(orientation, r1, g1, b1, a1, r2, g2, b2, a2)\r
        return\r
    end\r
\r
    if texture.SetGradient and CreateColor then\r
        texture:SetGradient(orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))\r
    end\r
end\r
\r
local function EnsureUnlockSurface(frame)\r
    if not frame then\r
        return nil\r
    end\r
\r
    if frame._ktUnlockSurface then\r
        return frame._ktUnlockSurface\r
    end\r
\r
    local surface = {}\r
\r
    surface.pattern = frame:CreateTexture(nil, "BACKGROUND", nil, 1)\r
    surface.pattern:SetAllPoints()\r
    surface.pattern:SetTexture(SIDEBAR_BUTTON_TEXTURE)\r
\r
    surface.shade = frame:CreateTexture(nil, "BACKGROUND", nil, 2)\r
    surface.shade:SetAllPoints()\r
\r
    surface.gloss = frame:CreateTexture(nil, "ARTWORK", nil, 0)\r
    surface.gloss:SetTexture(SIDEBAR_GLOSS_TEXTURE)\r
    surface.gloss:SetPoint("TOPLEFT", 1, -1)\r
    surface.gloss:SetPoint("TOPRIGHT", -1, -1)\r
\r
    surface.accentH = frame:CreateTexture(nil, "ARTWORK", nil, 1)\r
    surface.accentH:SetPoint("TOPLEFT", 1, -1)\r
    surface.accentH:SetPoint("BOTTOMLEFT", 1, 1)\r
    surface.accentH:SetTexture(WHITE8X8)\r
\r
    surface.accentV = frame:CreateTexture(nil, "ARTWORK", nil, 2)\r
    surface.accentV:SetPoint("TOPLEFT", 1, -1)\r
    surface.accentV:SetPoint("TOPRIGHT", -1, -1)\r
    surface.accentV:SetTexture(WHITE8X8)\r
\r
    surface.topLine = frame:CreateTexture(nil, "ARTWORK", nil, 3)\r
    surface.topLine:SetPoint("TOPLEFT", 1, -1)\r
    surface.topLine:SetPoint("TOPRIGHT", -1, -1)\r
    surface.topLine:SetHeight(1)\r
\r
    surface.bottomLine = frame:CreateTexture(nil, "ARTWORK", nil, 3)\r
    surface.bottomLine:SetPoint("BOTTOMLEFT", 1, 1)\r
    surface.bottomLine:SetPoint("BOTTOMRIGHT", -1, 1)\r
    surface.bottomLine:SetHeight(1)\r
\r
    frame._ktUnlockSurface = surface\r
    return surface\r
end\r
\r
local function ApplyUnlockSurface(frame, options)\r
    if not frame then\r
        return\r
    end\r
\r
    local surface = EnsureUnlockSurface(frame)\r
    if not surface then\r
        return\r
    end\r
\r
    local theme = GetUnlockTheme()\r
    local accent = options and options.accentColor or nil\r
    local accentR = accent and (accent[1] or accent.r) or theme.accent.r\r
    local accentG = accent and (accent[2] or accent.g) or theme.accent.g\r
    local accentB = accent and (accent[3] or accent.b) or theme.accent.b\r
    local width = frame:GetWidth() > 0 and frame:GetWidth() or 140\r
    local height = frame:GetHeight() > 0 and frame:GetHeight() or 24\r
    local glossAlpha = options and options.glossAlpha or 0\r
    local accentHAlpha = options and options.accentHAlpha or 0\r
    local accentVAlpha = options and options.accentVAlpha or 0\r
\r
    surface.pattern:SetTexture((options and options.texturePath) or SIDEBAR_BUTTON_TEXTURE)\r
    surface.pattern:SetTexCoord(0, 1, 0, 1)\r
    surface.pattern:SetVertexColor(1, 1, 1, options and options.patternAlpha or 0)\r
    surface.shade:SetColorTexture(0, 0, 0, options and options.shadeAlpha or 0.10)\r
    surface.gloss:SetHeight(max(6, height * ((options and options.glossRatio) or 0.60)))\r
    surface.gloss:SetVertexColor(1, 1, 1, glossAlpha)\r
    surface.topLine:SetColorTexture(accentR, accentG, accentB, options and options.topLineAlpha or 0)\r
    surface.bottomLine:SetColorTexture(1, 1, 1, options and options.bottomLineAlpha or 0)\r
\r
    if accentHAlpha > 0 then\r
        surface.accentH:SetWidth(max(8, width * ((options and options.accentHRatio) or 0.58)))\r
        ApplyTextureGradient(surface.accentH, "HORIZONTAL",\r
            accentR, accentG, accentB, accentHAlpha,\r
            accentR, accentG, accentB, 0)\r
        surface.accentH:Show()\r
    else\r
        surface.accentH:Hide()\r
    end\r
\r
    if accentVAlpha > 0 then\r
        surface.accentV:SetHeight(max(6, height * ((options and options.accentVRatio) or 0.72)))\r
        ApplyTextureGradient(surface.accentV, "VERTICAL",\r
            accentR, accentG, accentB, accentVAlpha,\r
            accentR, accentG, accentB, 0)\r
        surface.accentV:Show()\r
    else\r
        surface.accentV:Hide()\r
    end\r
end\r
\r
GetUnlockTheme = function()\r
    local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin or nil\r
    local unlockAccent = skin and skin.unlockModeColorMode == "custom" and skin.unlockModeColor or nil\r
    local palette = KT and KT.GetStylePalette and KT:GetStylePalette()\r
    local accentR, accentG, accentB, accentA\r
\r
    if unlockAccent then\r
        accentR, accentG, accentB, accentA = ReadThemeColor(unlockAccent, KT.C_R or MOVER_R, KT.C_G or MOVER_G, KT.C_B or MOVER_B, 1)\r
    else\r
        if palette and palette.accent then\r
            accentR, accentG, accentB, accentA = palette.accent.r, palette.accent.g, palette.accent.b, palette.accent.a or 1\r
        else\r
            accentR, accentG, accentB, accentA = ReadThemeColor(\r
                skin and (skin.accentColor or skin.borderColor),\r
                KT.C_R or MOVER_R,\r
                KT.C_G or MOVER_G,\r
                KT.C_B or MOVER_B,\r
                1\r
            )\r
        end\r
    end\r
    \r
    local bgR, bgG, bgB, bgA\r
    if palette and palette.backgroundTint then\r
        bgR, bgG, bgB, bgA = palette.backgroundTint.r, palette.backgroundTint.g, palette.backgroundTint.b, palette.backgroundTint.a\r
    else\r
        bgR, bgG, bgB, bgA = ReadThemeColor(\r
            skin and (skin.menuBackgroundTint or skin.backgroundColor),\r
            SIDEBAR_BG.r,\r
            SIDEBAR_BG.g,\r
            SIDEBAR_BG.b,\r
            SIDEBAR_BG.a\r
        )\r
    end\r
    \r
    local textR, textG, textB, textA\r
    if palette and palette.text then\r
        textR, textG, textB, textA = palette.text.r, palette.text.g, palette.text.b, palette.text.a\r
    else\r
        textR, textG, textB, textA = ReadThemeColor(\r
            skin and (skin.menuTextColor or skin.headerColor),\r
            1,\r
            0.96,\r
            0.97,\r
            1\r
        )\r
    end\r
    local softR, softG, softB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.48)\r
    local hoverR, hoverG, hoverB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.28)\r
    local activeR, activeG, activeB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.44)\r
    local activeHoverR, activeHoverG, activeHoverB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.58)\r
    local mutedR, mutedG, mutedB = BlendThemeColor(textR, textG, textB, bgR, bgG, bgB, 0.34)\r
    local artR, artG, artB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.16)\r
    local trackR, trackG, trackB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.14)\r
    local trackHoverR, trackHoverG, trackHoverB = BlendThemeColor(bgR, bgG, bgB, accentR, accentG, accentB, 0.24)\r
\r
    MOVER_R, MOVER_G, MOVER_B = accentR, accentG, accentB\r
    SetThemeColor(SIDEBAR_BG, bgR, bgG, bgB, bgA or 0.88)\r
    SetThemeColor(SIDEBAR_ACCENT, accentR, accentG, accentB, accentA or 1)\r
    SetThemeColor(SIDEBAR_ACCENT_SOFT, softR, softG, softB, 0.95)\r
\r
    return {\r
        accent = { r = accentR, g = accentG, b = accentB, a = accentA or 1 },\r
        soft = { r = softR, g = softG, b = softB, a = 0.95 },\r
        background = { r = bgR, g = bgG, b = bgB, a = bgA or 0.88 },\r
        text = { r = textR, g = textG, b = textB, a = textA or 1 },\r
        muted = { r = mutedR, g = mutedG, b = mutedB, a = 1 },\r
        hover = { r = hoverR, g = hoverG, b = hoverB, a = 1 },\r
        active = { r = activeR, g = activeG, b = activeB, a = 1 },\r
        activeHover = { r = activeHoverR, g = activeHoverG, b = activeHoverB, a = 1 },\r
        art = { r = artR, g = artG, b = artB, a = 1 },\r
        track = { r = trackR, g = trackG, b = trackB, a = 1 },\r
        trackHover = { r = trackHoverR, g = trackHoverG, b = trackHoverB, a = 1 },\r
    }\r
end\r
\r
local function RefreshPanelButtonTheme(button)\r
    if not button then return end\r
\r
    local theme = GetUnlockTheme()\r
    if button.bgKT and not button.normalColor then\r
        button.bgKT:SetColorTexture(theme.background.r, theme.background.g, theme.background.b, 0.94)\r
    end\r
    if button.borderKT then\r
        KT:AddBorder(button, theme.soft.r, theme.soft.g, theme.soft.b, 1)\r
    end\r
    if button.text then\r
        button.text:SetTextColor(theme.text.r, theme.text.g, theme.text.b, theme.text.a or 1)\r
    end\r
end\r
\r
local function CreateText(parent, size, justify)\r
    local fs = parent:CreateFontString(nil, "OVERLAY")\r
    fs:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", size, "OUTLINE")\r
    fs:SetJustifyH(justify or "CENTER")\r
    fs:SetTextColor(1, 1, 1, 1)\r
    return fs\r
end\r
\r
local function CreatePanelButton(parent, width, height, label)\r
    local button = CreateFrame("Button", nil, parent)\r
    button:SetSize(width, height)\r
    KT:AddBackdrop(button, 0.01, 0.01, 0.01, 0.94)\r
    button.text = CreateText(button, 12)\r
    button.text:SetAllPoints()\r
    button.text:SetText(label or "")\r
    button._ktUnlockPanelButton = true\r
    RefreshPanelButtonTheme(button)\r
    button:SetScript("OnEnter", function(self)\r
        if self._ktUnlockButtonStyle then\r
            local style = self._ktUnlockButtonStyle\r
            local accentHAlpha = (style.accentHAlpha or 0) + (style.hoverAccentBoost or 0.04)\r
            local accentVAlpha = (style.accentVAlpha or 0) + (style.hoverAccentBoost or 0.04) * 0.75\r
            local glossAlpha = (style.glossAlpha or 0) + (style.hoverGlossBoost or 0.04)\r
            if self.bgKT and self.hoverColor then\r
                self.bgKT:SetColorTexture(unpack(self.hoverColor))\r
            end\r
            if style.hoverBorderColor then\r
                KT:AddBorder(self, style.hoverBorderColor[1], style.hoverBorderColor[2], style.hoverBorderColor[3], style.hoverBorderColor[4] or 1)\r
            end\r
            ApplyUnlockSurface(self, {\r
                texturePath = style.texturePath,\r
                patternAlpha = style.patternAlpha,\r
                shadeAlpha = style.shadeAlpha,\r
                glossAlpha = glossAlpha,\r
                glossRatio = style.glossRatio,\r
                accentColor = style.accentColor,\r
                accentHAlpha = accentHAlpha,\r
                accentHRatio = style.accentHRatio,\r
                accentVAlpha = accentVAlpha,\r
                accentVRatio = style.accentVRatio,\r
                topLineAlpha = (style.topLineAlpha or 0) + (style.hoverTopLineBoost or 0.03),\r
                bottomLineAlpha = (style.bottomLineAlpha or 0) + (style.hoverBottomLineBoost or 0.02),\r
            })\r
        elseif self.bgKT and self.hoverColor then\r
            self.bgKT:SetColorTexture(self.hoverColor[1], self.hoverColor[2], self.hoverColor[3], self.hoverColor[4])\r
        end\r
    end)\r
    button:SetScript("OnLeave", function(self)\r
        if self._ktUnlockButtonStyle then\r
            local style = self._ktUnlockButtonStyle\r
            if self.bgKT and self.normalColor then\r
                self.bgKT:SetColorTexture(unpack(self.normalColor))\r
            end\r
            if style.borderColor then\r
                KT:AddBorder(self, style.borderColor[1], style.borderColor[2], style.borderColor[3], style.borderColor[4] or 1)\r
            end\r
            ApplyUnlockSurface(self, {\r
                texturePath = style.texturePath,\r
                patternAlpha = style.patternAlpha,\r
                shadeAlpha = style.shadeAlpha,\r
                glossAlpha = style.glossAlpha,\r
                glossRatio = style.glossRatio,\r
                accentColor = style.accentColor,\r
                accentHAlpha = style.accentHAlpha,\r
                accentHRatio = style.accentHRatio,\r
                accentVAlpha = style.accentVAlpha,\r
                accentVRatio = style.accentVRatio,\r
                topLineAlpha = style.topLineAlpha,\r
                bottomLineAlpha = style.bottomLineAlpha,\r
            })\r
        elseif self.bgKT and self.normalColor then\r
            self.bgKT:SetColorTexture(self.normalColor[1], self.normalColor[2], self.normalColor[3], self.normalColor[4])\r
        end\r
    end)\r
    return button\r
end\r
\r
local function StyleMenuInputBox(box)\r
    if not box then return end\r
\r
    local theme = GetUnlockTheme()\r
    KT:AddBackdrop(box, theme.background.r, theme.background.g, theme.background.b, 0.96)\r
    KT:AddBorder(box, theme.soft.r, theme.soft.g, theme.soft.b, 1)\r
    box:SetTextColor(theme.text.r, theme.text.g, theme.text.b, 1)\r
end\r
\r
local function CreateMenuInputBox(parent, width, height)\r
    local box = CreateFrame("EditBox", nil, parent)\r
    box:SetSize(width or 54, height or 18)\r
    box:SetAutoFocus(false)\r
    box:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")\r
    box:SetJustifyH("CENTER")\r
    box:SetTextInsets(4, 4, 1, 1)\r
    box:SetMaxLetters(8)\r
    StyleMenuInputBox(box)\r
    box:SetScript("OnEditFocusGained", function(self)\r
        local theme = GetUnlockTheme()\r
        KT:AddBorder(self, theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
        self:HighlightText()\r
    end)\r
    box:SetScript("OnEditFocusLost", function(self)\r
        StyleMenuInputBox(self)\r
    end)\r
    return box\r
end\r
\r
local function NormalizeMouseoverKey(value)\r
    if type(value) ~= "string" or value == "" then\r
        return nil\r
    end\r
\r
    local normalized = string.lower(value)\r
    normalized = string.gsub(normalized, "[^%w]+", "_")\r
    normalized = string.gsub(normalized, "_+", "_")\r
    normalized = string.gsub(normalized, "^_", "")\r
    normalized = string.gsub(normalized, "_$", "")\r
    return normalized\r
end\r
\r
local function ResolveMouseoverTargetID(key, def)\r
    if type(key) == "string" and MOUSEOVER_SETTING_KEYS[key] then\r
        return key\r
    end\r
\r
    local normalizedKey = NormalizeMouseoverKey(key)\r
    if normalizedKey and MOUSEOVER_KEY_ALIASES[normalizedKey] then\r
        return MOUSEOVER_KEY_ALIASES[normalizedKey]\r
    end\r
\r
    local label = def and def.label\r
    local normalizedLabel = NormalizeMouseoverKey(label)\r
    if normalizedLabel then\r
        if MOUSEOVER_SETTING_KEYS[normalizedLabel] then\r
            return normalizedLabel\r
        end\r
        if MOUSEOVER_KEY_ALIASES[normalizedLabel] then\r
            return MOUSEOVER_KEY_ALIASES[normalizedLabel]\r
        end\r
    end\r
\r
    return nil\r
end\r
\r
local function GetMouseoverSetting(targetID)\r
    local info = MOUSEOVER_SETTING_KEYS[targetID]\r
    if not (info and KT.db and KT.db.profile) then\r
        return false\r
    end\r
\r
    local section = KT.db.profile[info.section]\r
    if type(section) ~= "table" then\r
        return false\r
    end\r
\r
    return section[info.key] == true\r
end\r
\r
local function SetMouseoverSetting(targetID, value)\r
    local info = MOUSEOVER_SETTING_KEYS[targetID]\r
    if not (info and KT.db and KT.db.profile) then\r
        return\r
    end\r
\r
    KT.db.profile[info.section] = KT.db.profile[info.section] or {}\r
    KT.db.profile[info.section][info.key] = value == true\r
end\r
\r
local function RefreshMouseoverModules(targetID)\r
    local info = MOUSEOVER_SETTING_KEYS[targetID]\r
    if not info then\r
        return\r
    end\r
\r
    if info.section == "actionbars" then\r
        local mod = KT:GetModule("ActionBars", true)\r
        if mod and mod.UpdateMouseoverState then\r
            SafeCall(mod.UpdateMouseoverState, mod)\r
        end\r
    elseif info.section == "blizzframes" then\r
        local mod = KT:GetModule("BlizzardFrames", true)\r
        if mod and mod.UpdateMouseoverState then\r
            SafeCall(mod.UpdateMouseoverState, mod)\r
        end\r
    end\r
end\r
\r
local function SetButtonAccent(button, r, g, b)\r
    if button and button.bgKT then\r
        button.bgKT:SetColorTexture(r, g, b, 0.18)\r
    end\r
    if button and button.borderKT then\r
        KT:AddBorder(button, r, g, b, 1)\r
    end\r
end\r
\r
local function ApplySidebarPanelStyle(frame, variant)\r
    if not frame then\r
        return\r
    end\r
\r
    local theme = GetUnlockTheme()\r
    local bgR, bgG, bgB = BlendThemeColor(theme.background.r, theme.background.g, theme.background.b, 0, 0, 0, 0.30)\r
    local borderR, borderG, borderB = BlendThemeColor(bgR, bgG, bgB, theme.accent.r, theme.accent.g, theme.accent.b, 0.08)\r
    local accentHAlpha, accentVAlpha, patternAlpha, glossAlpha, topLineAlpha = 0.03, 0.02, 0.04, 0.02, 0.05\r
    local bottomLineAlpha = 0.01\r
\r
    if variant == "list" then\r
        accentHAlpha, accentVAlpha, patternAlpha, glossAlpha, topLineAlpha = 0.04, 0.02, 0.05, 0.03, 0.06\r
    elseif variant == "footer" then\r
        accentHAlpha, accentVAlpha, patternAlpha, glossAlpha, topLineAlpha = 0.05, 0.03, 0.06, 0.03, 0.06\r
    end\r
\r
    KT:AddBackdrop(frame, bgR, bgG, bgB, 0.84)\r
    KT:AddBorder(frame, borderR, borderG, borderB, 0.9)\r
    ApplyUnlockSurface(frame, {\r
        patternAlpha = patternAlpha,\r
        shadeAlpha = 0.08,\r
        glossAlpha = glossAlpha,\r
        accentHAlpha = accentHAlpha,\r
        accentHRatio = 0.42,\r
        accentVAlpha = accentVAlpha,\r
        accentVRatio = 0.26,\r
        topLineAlpha = topLineAlpha,\r
        bottomLineAlpha = bottomLineAlpha,\r
    })\r
    frame._ktUnlockPanelVariant = variant\r
end\r
\r
local function StyleSidebarButton(button, variant, isActive)\r
    if not button then return end\r
\r
    local theme = GetUnlockTheme()\r
    local style\r
    button._ktUnlockVariant = variant\r
\r
    if variant == "toggle" then\r
        local baseR, baseG, baseB = 0.02, 0.02, 0.025\r
        local hoverR, hoverG, hoverB = BlendThemeColor(baseR, baseG, baseB, theme.accent.r, theme.accent.g, theme.accent.b, 0.08)\r
        style = {\r
            normalColor = { baseR, baseG, baseB, 0.92 },\r
            hoverColor = { hoverR, hoverG, hoverB, 0.95 },\r
            borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.88 },\r
            hoverBorderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },\r
            textColor = { 1, 1, 1, 1 },\r
            fontSize = 12,\r
            patternAlpha = 0.05,\r
            shadeAlpha = 0.08,\r
            glossAlpha = 0.03,\r
            hoverGlossBoost = 0.02,\r
            accentHAlpha = 0.05,\r
            accentHRatio = 0.18,\r
            accentVAlpha = 0.03,\r
            accentVRatio = 0.28,\r
            hoverAccentBoost = 0.02,\r
            topLineAlpha = 0.05,\r
            bottomLineAlpha = 0.02,\r
        }\r
    elseif variant == "group" then\r
        local baseR, baseG, baseB = 0.015, 0.015, 0.02\r
        style = {\r
            normalColor = { baseR, baseG, baseB, 0.56 },\r
            hoverColor = { baseR, baseG, baseB, 0.56 },\r
            borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.72 },\r
            textColor = { 1, 1, 1, 1 },\r
            fontSize = 11,\r
            patternAlpha = 0.00,\r
            shadeAlpha = 0.02,\r
            glossAlpha = 0.00,\r
            accentHAlpha = 0.10,\r
            accentHRatio = 0.18,\r
            accentVAlpha = 0.00,\r
            topLineAlpha = 0.00,\r
            bottomLineAlpha = 0.00,\r
        }\r
    elseif variant == "item" then\r
        if isActive then\r
            local activeR, activeG, activeB = 0.03, 0.03, 0.04\r
            local activeHoverR, activeHoverG, activeHoverB = BlendThemeColor(activeR, activeG, activeB, theme.accent.r, theme.accent.g, theme.accent.b, 0.10)\r
            style = {\r
                normalColor = { activeR, activeG, activeB, 0.94 },\r
                hoverColor = { activeHoverR, activeHoverG, activeHoverB, 0.97 },\r
                borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },\r
                hoverBorderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },\r
                textColor = { 1, 1, 1, 1 },\r
                fontSize = 11,\r
                patternAlpha = 0.04,\r
                shadeAlpha = 0.06,\r
                glossAlpha = 0.04,\r
                hoverGlossBoost = 0.03,\r
                accentHAlpha = 0.22,\r
                accentHRatio = 0.10,\r
                accentVAlpha = 0.05,\r
                accentVRatio = 0.20,\r
                hoverAccentBoost = 0.03,\r
                topLineAlpha = 0.08,\r
                bottomLineAlpha = 0.03,\r
            }\r
        else\r
            local baseR, baseG, baseB = 0.02, 0.02, 0.025\r
            local hoverR, hoverG, hoverB = BlendThemeColor(baseR, baseG, baseB, theme.accent.r, theme.accent.g, theme.accent.b, 0.06)\r
            style = {\r
                normalColor = { baseR, baseG, baseB, 0.84 },\r
                hoverColor = { hoverR, hoverG, hoverB, 0.90 },\r
                borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.82 },\r
                hoverBorderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },\r
                textColor = { 1, 1, 1, 1 },\r
                fontSize = 11,\r
                patternAlpha = 0.03,\r
                shadeAlpha = 0.06,\r
                glossAlpha = 0.02,\r
                hoverGlossBoost = 0.02,\r
                accentHAlpha = 0.04,\r
                accentHRatio = 0.08,\r
                accentVAlpha = 0.02,\r
                accentVRatio = 0.16,\r
                hoverAccentBoost = 0.02,\r
                topLineAlpha = 0.03,\r
                bottomLineAlpha = 0.02,\r
            }\r
        end\r
    elseif variant == "footer_red" then\r
        local baseR, baseG, baseB = 0.02, 0.02, 0.025\r
        local hoverR, hoverG, hoverB = BlendThemeColor(baseR, baseG, baseB, theme.accent.r, theme.accent.g, theme.accent.b, 0.10)\r
        style = {\r
            normalColor = { baseR, baseG, baseB, 0.90 },\r
            hoverColor = { hoverR, hoverG, hoverB, 0.94 },\r
            borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.88 },\r
            hoverBorderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.90 },\r
            textColor = { 1, 1, 1, 1 },\r
            fontSize = 12,\r
            patternAlpha = 0.04,\r
            shadeAlpha = 0.06,\r
            glossAlpha = 0.03,\r
            hoverGlossBoost = 0.02,\r
            accentHAlpha = 0.08,\r
            accentHRatio = 0.12,\r
            accentVAlpha = 0.03,\r
            accentVRatio = 0.20,\r
            hoverAccentBoost = 0.02,\r
            topLineAlpha = 0.05,\r
            bottomLineAlpha = 0.02,\r
        }\r
    elseif variant == "footer_green" then\r
        local baseR, baseG, baseB = 0.02, 0.02, 0.025\r
        local hoverR, hoverG, hoverB = BlendThemeColor(baseR, baseG, baseB, theme.accent.r, theme.accent.g, theme.accent.b, 0.10)\r
        style = {\r
            normalColor = { baseR, baseG, baseB, 0.88 },\r
            hoverColor = { hoverR, hoverG, hoverB, 0.92 },\r
            borderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 0.88 },\r
            hoverBorderColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },\r
            textColor = { 1, 1, 1, 1 },\r
            accentColor = { theme.accent.r, theme.accent.g, theme.accent.b, 1 },\r
            fontSize = 12,\r
            patternAlpha = 0.04,\r
            shadeAlpha = 0.06,\r
            glossAlpha = 0.03,\r
            hoverGlossBoost = 0.02,\r
            accentHAlpha = 0.08,\r
            accentHRatio = 0.12,\r
            accentVAlpha = 0.03,\r
            accentVRatio = 0.20,\r
            hoverAccentBoost = 0.02,\r
            topLineAlpha = 0.05,\r
            bottomLineAlpha = 0.02,\r
        }\r
    else\r
        return\r
    end\r
\r
    button._ktUnlockButtonStyle = style\r
    button.normalColor = style.normalColor\r
    button.hoverColor = style.hoverColor\r
    if button.bgKT then\r
        button.bgKT:SetColorTexture(unpack(button.normalColor))\r
    end\r
    KT:AddBorder(button, style.borderColor[1], style.borderColor[2], style.borderColor[3], style.borderColor[4] or 1)\r
    button.text:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", style.fontSize or 11, "OUTLINE")\r
    button.text:SetTextColor(style.textColor[1], style.textColor[2], style.textColor[3], style.textColor[4] or 1)\r
    ApplyUnlockSurface(button, {\r
        texturePath = style.texturePath,\r
        patternAlpha = style.patternAlpha,\r
        shadeAlpha = style.shadeAlpha,\r
        glossAlpha = style.glossAlpha,\r
        glossRatio = style.glossRatio,\r
        accentColor = style.accentColor,\r
        accentHAlpha = style.accentHAlpha,\r
        accentHRatio = style.accentHRatio,\r
        accentVAlpha = style.accentVAlpha,\r
        accentVRatio = style.accentVRatio,\r
        topLineAlpha = style.topLineAlpha,\r
        bottomLineAlpha = style.bottomLineAlpha,\r
    })\r
end\r
\r
local function SetScrollbarThumbState(sidebar, state)\r
    if not sidebar or not sidebar.scrollbarThumb then return end\r
\r
    local theme = GetUnlockTheme()\r
    local thumb = sidebar.scrollbarThumb\r
    local thumbBorder = sidebar.scrollbarThumbBorder\r
    local track = sidebar.scrollbarTrack\r
    local thumbGlow = sidebar.scrollbarThumbGlow\r
    local trackLeft = sidebar.scrollbarTrackLeft\r
    local trackRight = sidebar.scrollbarTrackRight\r
\r
    if state == "drag" then\r
        thumb:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
        thumb:SetAlpha(1)\r
        if thumbGlow then\r
            thumbGlow:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.28)\r
            thumbGlow:SetAlpha(1)\r
        end\r
        if thumbBorder then\r
            KT:AddBorder(thumbBorder, theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
        end\r
        if track and track.bgKT then\r
            track.bgKT:SetColorTexture(theme.trackHover.r, theme.trackHover.g, theme.trackHover.b, 0.96)\r
        end\r
        if trackLeft then\r
            trackLeft:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.75)\r
        end\r
        if trackRight then\r
            trackRight:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.75)\r
        end\r
    elseif state == "hover" then\r
        thumb:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
        thumb:SetAlpha(1)\r
        if thumbGlow then\r
            thumbGlow:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.22)\r
            thumbGlow:SetAlpha(1)\r
        end\r
        if thumbBorder then\r
            KT:AddBorder(thumbBorder, theme.accent.r, theme.accent.g, theme.accent.b, 0.92)\r
        end\r
        if track and track.bgKT then\r
            track.bgKT:SetColorTexture(theme.trackHover.r, theme.trackHover.g, theme.trackHover.b, 0.92)\r
        end\r
        if trackLeft then\r
            trackLeft:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.62)\r
        end\r
        if trackRight then\r
            trackRight:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.62)\r
        end\r
    else\r
        thumb:SetVertexColor(MOVER_R, MOVER_G, MOVER_B, 0.95)\r
        thumb:SetAlpha(0.96)\r
        if thumbGlow then\r
            thumbGlow:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.16)\r
            thumbGlow:SetAlpha(1)\r
        end\r
        if thumbBorder then\r
            KT:AddBorder(thumbBorder, theme.accent.r, theme.accent.g, theme.accent.b, 0.82)\r
        end\r
        if track and track.bgKT then\r
            track.bgKT:SetColorTexture(theme.track.r, theme.track.g, theme.track.b, 0.90)\r
        end\r
        if trackLeft then\r
            trackLeft:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.42)\r
        end\r
        if trackRight then\r
            trackRight:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.42)\r
        end\r
    end\r
end\r
\r
local function GetUIRect()\r
    return UIParent:GetWidth(), UIParent:GetHeight()\r
end\r
\r
local function SetFrameTopLeft(frame, left, top)\r
    frame:ClearAllPoints()\r
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left, top - UIParent:GetHeight())\r
end\r
\r
local function PointToCenter(point, x, y, width, height, uiWidth, uiHeight)\r
    local anchorX = 0\r
    local anchorY = 0\r
\r
    if point == "TOPLEFT" then\r
        anchorX = x\r
        anchorY = uiHeight + y\r
        return anchorX + (width * 0.5), anchorY - (height * 0.5)\r
    elseif point == "TOP" then\r
        anchorX = (uiWidth * 0.5) + x\r
        anchorY = uiHeight + y\r
        return anchorX, anchorY - (height * 0.5)\r
    elseif point == "TOPRIGHT" then\r
        anchorX = uiWidth + x\r
        anchorY = uiHeight + y\r
        return anchorX - (width * 0.5), anchorY - (height * 0.5)\r
    elseif point == "LEFT" then\r
        anchorX = x\r
        anchorY = (uiHeight * 0.5) + y\r
        return anchorX + (width * 0.5), anchorY\r
    elseif point == "CENTER" then\r
        anchorX = (uiWidth * 0.5) + x\r
        anchorY = (uiHeight * 0.5) + y\r
        return anchorX, anchorY\r
    elseif point == "RIGHT" then\r
        anchorX = uiWidth + x\r
        anchorY = (uiHeight * 0.5) + y\r
        return anchorX - (width * 0.5), anchorY\r
    elseif point == "BOTTOMLEFT" then\r
        anchorX = x\r
        anchorY = y\r
        return anchorX + (width * 0.5), anchorY + (height * 0.5)\r
    elseif point == "BOTTOM" then\r
        anchorX = (uiWidth * 0.5) + x\r
        anchorY = y\r
        return anchorX, anchorY + (height * 0.5)\r
    elseif point == "BOTTOMRIGHT" then\r
        anchorX = uiWidth + x\r
        anchorY = y\r
        return anchorX - (width * 0.5), anchorY + (height * 0.5)\r
    end\r
\r
    return (uiWidth * 0.5) + (x or 0), (uiHeight * 0.5) + (y or 0)\r
end\r
\r
local function BoundsFromStoredPosition(pos, width, height)\r
    local uiWidth, uiHeight = GetUIRect()\r
    local point = pos.point or pos.relativePoint or "CENTER"\r
    local centerX, centerY = PointToCenter(point, pos.x or 0, pos.y or 0, width, height, uiWidth, uiHeight)\r
    return centerX - (width * 0.5), centerY + (height * 0.5), width, height\r
end\r
\r
function UM:EnsureDB()\r
    if not KT.db or not KT.db.profile then return end\r
    KT.db.profile.editMode = KT.db.profile.editMode or {}\r
    KT.db.profile.editMode.frames = KT.db.profile.editMode.frames or {}\r
    KT.db.profile.editMode.snapTargets = KT.db.profile.editMode.snapTargets or {}\r
    if KT.db.profile.editMode.unlockGrid == nil then KT.db.profile.editMode.unlockGrid = "dimmed" end\r
    if KT.db.profile.editMode.unlockSnap == nil then KT.db.profile.editMode.unlockSnap = true end\r
    if KT.db.profile.editMode.unlockDarkOverlays == nil then KT.db.profile.editMode.unlockDarkOverlays = true end\r
    if KT.db.profile.editMode.unlockCoords == nil then KT.db.profile.editMode.unlockCoords = false end\r
    self.db = KT.db.profile.editMode\r
end\r
\r
function UM:OnInitialize()\r
    self:EnsureDB()\r
\r
    self.registry = KT.UnlockElements\r
    self.registryOrder = {}\r
    self.movers = {}\r
    self.pendingPositions = {}\r
    self.snapshotPositions = {}\r
    self.snapshotSizes = {}\r
    self.snapshotSnapTargets = {}\r
    self.selectedKey = nil\r
    self.selectedKeys = {}\r
    self.isOpen = false\r
    self.isSuspended = false\r
    self.hasChanges = false\r
\r
    StaticPopupDialogs["KULLTHRANUI_UNLOCKMODE_UNSAVED"] = {\r
        text = "Save KT UnlockMode changes before closing?",\r
        button1 = "Save",\r
        button2 = "Discard",\r
        button3 = "Cancel",\r
        OnAccept = function()\r
            UM:CloseUnlockMode(true, true)\r
        end,\r
        OnCancel = function()\r
            UM:CloseUnlockMode(false, true)\r
        end,\r
        OnAlt = function()\r
        end,\r
        timeout = 0,\r
        whileDead = 1,\r
        hideOnEscape = 1,\r
        preferredIndex = 3,\r
    }\r
end\r
\r
function UM:PromptCloseUnlockMode()\r
    StaticPopup_Show("KULLTHRANUI_UNLOCKMODE_UNSAVED")\r
end\r
\r
function UM:OnEnable()\r
    self:EnsureDB()\r
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStart")\r
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatEnd")\r
\r
    KT:RegisterChatCommand("ktunlock", function()\r
        self:ToggleUnlockMode()\r
    end)\r
\r
    ns.IsUnlocked = function() return self.isOpen end\r
    ns.ToggleUnlockMode = function() self:ToggleUnlockMode() end\r
end\r
\r
function UM:UpdateRegistry()\r
    self.registry = KT.UnlockElements or {}\r
    wipe(self.registryOrder)\r
    for key, _ in pairs(self.registry) do\r
        tinsert(self.registryOrder, key)\r
    end\r
    table.sort(self.registryOrder, function(a, b)\r
        local ea = self.registry[a] or {}\r
        local eb = self.registry[b] or {}\r
        local ga = tostring(ea.group or "Other")\r
        local gb = tostring(eb.group or "Other")\r
        if ga ~= gb then\r
            return ga < gb\r
        end\r
        local oa = tonumber(ea.order) or 9999\r
        local ob = tonumber(eb.order) or 9999\r
        if oa ~= ob then\r
            return oa < ob\r
        end\r
        return tostring(ea.label or a) < tostring(eb.label or b)\r
    end)\r
\r
    if self.isOpen then\r
        self:RefreshMovers()\r
        self:RefreshSidebar()\r
    end\r
end\r
\r
function UM:GetStoredDBPosition(key)\r
    self:EnsureDB()\r
    return self.db and self.db.frames and self.db.frames[key]\r
end\r
\r
function UM:SaveStoredDBPosition(key, point, relativePoint, x, y, scale)\r
    self:EnsureDB()\r
    self.db.frames[key] = self.db.frames[key] or {}\r
    local data = self.db.frames[key]\r
    data.point = point\r
    data.relativePoint = relativePoint\r
    data.x = x\r
    data.y = y\r
    if scale ~= nil then\r
        data.scale = scale\r
    end\r
end\r
\r
function UM:GetElementDef(key)\r
    return self.registry and self.registry[key]\r
end\r
\r
function UM:GetElementFrame(key)\r
    local def = self:GetElementDef(key)\r
    if not def or type(def.getFrame) ~= "function" then return nil end\r
    local ok, frame = SafeCall(def.getFrame, key)\r
    if ok then\r
        return frame\r
    end\r
    return nil\r
end\r
\r
function UM:GetElementScale(key)\r
    local def = self:GetElementDef(key)\r
    if not def then return 1 end\r
    if type(def.getScale) == "function" then\r
        local ok, scale = SafeCall(def.getScale, key)\r
        if ok and type(scale) == "number" and scale > 0 then\r
            return scale\r
        end\r
    end\r
    local frame = self:GetElementFrame(key)\r
    if frame and frame.GetScale then\r
        local scale = frame:GetScale()\r
        if type(scale) == "number" and scale > 0 then\r
            return scale\r
        end\r
    end\r
    return 1\r
end\r
\r
function UM:GetElementSize(key)\r
    local def = self:GetElementDef(key)\r
    if not def then return 64, 32 end\r
    if type(def.getSize) == "function" then\r
        local ok, width, height = pcall(def.getSize, key)\r
        if ok and type(width) == "number" and type(height) == "number" and width > 0 and height > 0 then\r
            return width, height\r
        end\r
    end\r
    local frame = self:GetElementFrame(key)\r
    if frame and frame.GetWidth and frame.GetHeight then\r
        return max(frame:GetWidth(), 32), max(frame:GetHeight(), 24)\r
    end\r
    return 64, 32\r
end\r
\r
function UM:IsElementHidden(key)\r
    local def = self:GetElementDef(key)\r
    if not def then return true end\r
    if type(def.isHidden) == "function" then\r
        local ok, hidden = SafeCall(def.isHidden, key)\r
        if ok and hidden then\r
            return true\r
        end\r
    end\r
    return false\r
end\r
\r
function UM:LoadElementPosition(key)\r
    local def = self:GetElementDef(key)\r
    if def and type(def.loadPosition) == "function" then\r
        local ok, pos = SafeCall(def.loadPosition, key)\r
        if ok and type(pos) == "table" and pos.point then\r
            return CopyPosition(pos)\r
        end\r
    end\r
    local saved = self:GetStoredDBPosition(key)\r
    if saved and saved.point then\r
        return CopyPosition(saved)\r
    end\r
    return nil\r
end\r
\r
function UM:GetElementRect(key)\r
    local def = self:GetElementDef(key)\r
    if def and type(def.getRect) == "function" then\r
        local ok, left, top, width, height = pcall(def.getRect, key)\r
        if ok and left and top and width and height then\r
            return left, top, width, height\r
        end\r
    end\r
\r
    local frame = self:GetElementFrame(key)\r
    local moverScale = self:GetElementScale(key)\r
    local width, height\r
    if def and type(def.getMoverSize) == "function" then\r
        local ok, mw, mh = pcall(def.getMoverSize, key)\r
        if ok and mw and mh then\r
            width, height = mw, mh\r
        end\r
    end\r
    if not width then\r
        width, height = self:GetElementSize(key)\r
    end\r
    width = width * moverScale\r
    height = height * moverScale\r
\r
    if frame and frame.GetLeft and frame.GetTop and frame:GetLeft() and frame:GetTop() then\r
        local uiScale = UIParent:GetEffectiveScale()\r
        local frameScale = frame:GetEffectiveScale()\r
        local left = frame:GetLeft() * frameScale / uiScale\r
        local top = frame:GetTop() * frameScale / uiScale\r
        local right = frame:GetRight() and (frame:GetRight() * frameScale / uiScale) or (left + width)\r
        local bottom = frame:GetBottom() and (frame:GetBottom() * frameScale / uiScale) or (top - height)\r
        return left, top, max(right - left, width), max(top - bottom, height)\r
    end\r
\r
    local stored = self:LoadElementPosition(key)\r
    if stored then\r
        return BoundsFromStoredPosition(stored, width, height)\r
    end\r
\r
    local uiWidth, uiHeight = GetUIRect()\r
    return (uiWidth * 0.5) - (width * 0.5), (uiHeight * 0.5) + (height * 0.5), width, height\r
end\r
\r
function UM:CaptureCurrentPosition(key)\r
    local frame = self:GetElementFrame(key)\r
    if frame and frame.GetPoint then\r
        local point, relativeTo, relativePoint, x, y = frame:GetPoint()\r
        if point then\r
            return {\r
                point = point,\r
                relativeTo = relativeTo,\r
                relativePoint = relativePoint or point,\r
                x = x or 0,\r
                y = y or 0,\r
                scale = self:GetElementScale(key),\r
            }\r
        end\r
    end\r
    if frame and frame.GetLeft and frame:GetLeft() and frame:GetTop() then\r
        local uiScale = UIParent:GetEffectiveScale()\r
        local frameScale = frame:GetEffectiveScale()\r
        return {\r
            point = "TOPLEFT",\r
            relativePoint = "TOPLEFT",\r
            x = frame:GetLeft() * frameScale / uiScale * (uiScale / frameScale),\r
            y = (frame:GetTop() * frameScale / uiScale - UIParent:GetHeight()) * (uiScale / frameScale),\r
            scale = self:GetElementScale(key),\r
        }\r
    end\r
    local stored = self:LoadElementPosition(key)\r
    if stored then\r
        return stored\r
    end\r
    local left, top = self:GetElementRect(key)\r
    return {\r
        point = "TOPLEFT",\r
        relativePoint = "TOPLEFT",\r
        x = left,\r
        y = top - UIParent:GetHeight(),\r
        scale = self:GetElementScale(key),\r
    }\r
end\r
\r
function UM:ApplyStoredPositionToElement(key, pos)\r
    if not pos then return end\r
    local def = self:GetElementDef(key)\r
    local frame = self:GetElementFrame(key)\r
    if not frame then return end\r
\r
    if def and type(def.setScale) == "function" and pos.scale then\r
        SafeCall(def.setScale, key, pos.scale)\r
    elseif pos.scale and frame.SetScale then\r
        frame:SetScale(pos.scale)\r
    end\r
\r
    frame:ClearAllPoints()\r
    frame:SetPoint(\r
        pos.point or "TOPLEFT",\r
        pos.relativeTo or UIParent,\r
        pos.relativePoint or pos.point or "TOPLEFT",\r
        pos.x or 0,\r
        pos.y or 0\r
    )\r
end\r
\r
function UM:SaveElementPosition(key, pos)\r
    local def = self:GetElementDef(key)\r
    if def and type(def.savePosition) == "function" then\r
        SafeCall(def.savePosition, key, pos.point, pos.relativePoint, pos.x, pos.y, pos.scale)\r
    else\r
        self:SaveStoredDBPosition(key, pos.point, pos.relativePoint, pos.x, pos.y, pos.scale)\r
    end\r
end\r
\r
function UM:GetSnapTarget(key)\r
    self:EnsureDB()\r
    local target = self.db and self.db.snapTargets and self.db.snapTargets[key]\r
    if type(target) ~= "string" or target == "" then\r
        return nil\r
    end\r
    return target\r
end\r
\r
function UM:SetSnapTarget(key, targetKey)\r
    self:EnsureDB()\r
    if not (self.db and self.db.snapTargets and key) then\r
        return\r
    end\r
\r
    local currentTarget = self.db.snapTargets[key]\r
    if type(targetKey) ~= "string" or targetKey == "" or targetKey == key then\r
        self.db.snapTargets[key] = nil\r
        if currentTarget ~= nil then\r
            self.hasChanges = true\r
        end\r
        return\r
    end\r
\r
    if currentTarget ~= targetKey then\r
        self.db.snapTargets[key] = targetKey\r
        self.hasChanges = true\r
    end\r
end\r
\r
function UM:GetSnapTargetOptions(key)\r
    local options = {\r
        { value = nil, label = LText("Auto") },\r
    }\r
\r
    for _, otherKey in ipairs(self.registryOrder or {}) do\r
        if otherKey ~= key and not self:IsElementHidden(otherKey) then\r
            local def = self:GetElementDef(otherKey)\r
            options[#options + 1] = {\r
                value = otherKey,\r
                label = def and (def.label or otherKey) or otherKey,\r
            }\r
        end\r
    end\r
\r
    return options\r
end\r
\r
function UM:GetSnapTargetLabel(key)\r
    local targetKey = self:GetSnapTarget(key)\r
    if not targetKey then\r
        return LText("Auto")\r
    end\r
\r
    local def = self:GetElementDef(targetKey)\r
    if not def or self:IsElementHidden(targetKey) then\r
        return LText("Auto")\r
    end\r
\r
    return def.label or targetKey\r
end\r
\r
function UM:GetMoverStoredXY(key)\r
    local mover = self.movers and self.movers[key]\r
    local frame = self:GetElementFrame(key)\r
    if not frame then\r
        return 0, 0\r
    end\r
\r
    local uiScale = UIParent:GetEffectiveScale()\r
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1\r
    local ratio = uiScale / (frameScale > 0 and frameScale or 1)\r
\r
    local left = mover and mover.GetLeft and mover:GetLeft() or nil\r
    local top = mover and mover.GetTop and mover:GetTop() or nil\r
    if left and top then\r
        return Round(left * ratio), Round((top - UIParent:GetHeight()) * ratio)\r
    end\r
\r
    local pos = self.pendingPositions and self.pendingPositions[key]\r
    if pos then\r
        return Round(pos.x or 0), Round(pos.y or 0)\r
    end\r
\r
    pos = self:CaptureCurrentPosition(key)\r
    if pos then\r
        return Round(pos.x or 0), Round(pos.y or 0)\r
    end\r
\r
    return 0, 0\r
end\r
\r
function UM:SetMoverStoredXY(key, x, y)\r
    local mover = self.movers and self.movers[key]\r
    local frame = self:GetElementFrame(key)\r
    if not (mover and frame) then\r
        return\r
    end\r
\r
    local uiScale = UIParent:GetEffectiveScale()\r
    local frameScale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1\r
    local ratio = uiScale / (frameScale > 0 and frameScale or 1)\r
    local left = (tonumber(x) or 0) / ratio\r
    local top = UIParent:GetHeight() + ((tonumber(y) or 0) / ratio)\r
\r
    SetFrameTopLeft(mover, left, top)\r
    self:ApplyMoverToElement(key, mover)\r
    mover:RefreshCoords()\r
end\r
\r
function UM:CanEditElementSize(key)\r
    local def = self:GetElementDef(key)\r
    return def\r
        and type(def.setEditableSize) == "function"\r
        and (type(def.getEditableSize) == "function" or type(def.getSize) == "function")\r
        and true or false\r
end\r
\r
function UM:GetEditableElementSize(key)\r
    local def = self:GetElementDef(key)\r
    if not def then\r
        return nil, nil\r
    end\r
\r
    if type(def.getEditableSize) == "function" then\r
        local ok, width, height = pcall(def.getEditableSize, key)\r
        if ok and type(width) == "number" and type(height) == "number" then\r
            return Round(width), Round(height)\r
        end\r
    end\r
\r
    if type(def.getSize) == "function" then\r
        local ok, width, height = pcall(def.getSize, key)\r
        if ok and type(width) == "number" and type(height) == "number" then\r
            return Round(width), Round(height)\r
        end\r
    end\r
\r
    return nil, nil\r
end\r
\r
function UM:SetEditableElementSize(key, width, height)\r
    local def = self:GetElementDef(key)\r
    if not (def and type(def.setEditableSize) == "function") then\r
        return\r
    end\r
\r
    width = tonumber(width)\r
    height = tonumber(height)\r
    if not (width and height) then\r
        return\r
    end\r
\r
    SafeCall(def.setEditableSize, key, Round(max(1, width)), Round(max(1, height)))\r
    self.hasChanges = true\r
\r
    local mover = self.movers and self.movers[key]\r
    if mover and mover.Sync then\r
        mover:Sync()\r
    end\r
\r
    if self.moverMenu and self.moverMenu:IsShown() and self.moverMenu.activeKey == key and self.RefreshMoverMenuFields then\r
        self:RefreshMoverMenuFields()\r
    end\r
end\r
\r
function UM:CommitPositions()\r
    for key, pos in pairs(self.pendingPositions) do\r
        self:SaveElementPosition(key, pos)\r
        local def = self:GetElementDef(key)\r
        if def and type(def.applyPosition) == "function" then\r
            SafeCall(def.applyPosition, key)\r
        end\r
    end\r
    wipe(self.pendingPositions)\r
    self.hasChanges = false\r
end\r
\r
function UM:RevertPositions()\r
    for key, targetKey in pairs(self.snapshotSnapTargets or {}) do\r
        if targetKey and targetKey ~= false then\r
            self.db.snapTargets[key] = targetKey\r
        elseif self.db and self.db.snapTargets then\r
            self.db.snapTargets[key] = nil\r
        end\r
    end\r
\r
    for key, size in pairs(self.snapshotSizes or {}) do\r
        local def = self:GetElementDef(key)\r
        if def and type(def.setEditableSize) == "function" and size and size.width and size.height then\r
            SafeCall(def.setEditableSize, key, size.width, size.height)\r
        end\r
    end\r
\r
    for key, pos in pairs(self.snapshotPositions) do\r
        self:ApplyStoredPositionToElement(key, pos)\r
        local mover = self.movers[key]\r
        if mover then\r
            mover:Sync()\r
        end\r
    end\r
    wipe(self.pendingPositions)\r
    self.hasChanges = false\r
end\r
\r
function UM:SelectMover(key)\r
    wipe(self.selectedKeys)\r
    if key then\r
        self.selectedKeys[key] = true\r
    end\r
    self.selectedKey = key\r
    for moverKey, mover in pairs(self.movers) do\r
        mover.isSelected = self.selectedKeys[moverKey] or false\r
        mover:RefreshStyle()\r
    end\r
    self:RefreshSidebarSelection()\r
end\r
\r
function UM:IsMoverSelected(key)\r
    return key and self.selectedKeys and self.selectedKeys[key] or false\r
end\r
\r
function UM:GetSelectedMoverKeys()\r
    local keys = {}\r
    for _, key in ipairs(self.registryOrder) do\r
        if self.selectedKeys and self.selectedKeys[key] then\r
            tinsert(keys, key)\r
        end\r
    end\r
    if #keys == 0 and self.selectedKey then\r
        tinsert(keys, self.selectedKey)\r
    end\r
    return keys\r
end\r
\r
function UM:GetSelectedMoverCount()\r
    local count = 0\r
    if not self.selectedKeys then return count end\r
    for _ in pairs(self.selectedKeys) do\r
        count = count + 1\r
    end\r
    return count\r
end\r
\r
function UM:ToggleMoverSelection(key)\r
    if not key then return end\r
    self.selectedKeys = self.selectedKeys or {}\r
    if self.selectedKeys[key] then\r
        self.selectedKeys[key] = nil\r
        if self.selectedKey == key then\r
            self.selectedKey = next(self.selectedKeys)\r
        end\r
    else\r
        self.selectedKeys[key] = true\r
        self.selectedKey = key\r
    end\r
    for moverKey, mover in pairs(self.movers) do\r
        mover.isSelected = self.selectedKeys[moverKey] or false\r
        mover:RefreshStyle()\r
    end\r
    self:RefreshSidebarSelection()\r
end\r
\r
function UM:RefreshSidebarSelection()\r
    if not self.sidebar or not self.sidebar.itemButtons then return end\r
    for _, button in ipairs(self.sidebar.itemButtons) do\r
        if button.key then\r
            StyleSidebarButton(button, "item", self:IsMoverSelected(button.key))\r
        end\r
    end\r
end\r
\r
function UM:ApplyMoverToElement(key, mover)\r
    local def = self:GetElementDef(key)\r
    local frame = self:GetElementFrame(key)\r
    if not frame then return end\r
    local left = mover:GetLeft()\r
    local top = mover:GetTop()\r
    if not left or not top then return end\r
\r
    local uiScale = UIParent:GetEffectiveScale()\r
    local frameScale = frame:GetEffectiveScale()\r
    local ratio = uiScale / frameScale\r
    local x = left * ratio\r
    local y = (top - UIParent:GetHeight()) * ratio\r
\r
    local pos = {\r
        point = "TOPLEFT",\r
        relativePoint = "TOPLEFT",\r
        x = x,\r
        y = y,\r
        scale = self:GetElementScale(key),\r
    }\r
\r
    if def and type(def.translateMoverPosition) == "function" then\r
        local ok, translated = pcall(def.translateMoverPosition, key, pos, mover)\r
        if ok and type(translated) == "table" and translated.point then\r
            pos = translated\r
        end\r
    end\r
\r
    if def and type(def.applyPendingPosition) == "function" then\r
        SafeCall(def.applyPendingPosition, key, pos, mover)\r
    else\r
        frame:ClearAllPoints()\r
        frame:SetPoint(\r
            pos.point or "TOPLEFT",\r
            pos.relativeTo or UIParent,\r
            pos.relativePoint or pos.point or "TOPLEFT",\r
            pos.x or 0,\r
            pos.y or 0\r
        )\r
    end\r
\r
    self.pendingPositions[key] = pos\r
    self.hasChanges = true\r
\r
    if self.moverMenu and self.moverMenu:IsShown() and self.moverMenu.activeKey == key and self.RefreshMoverMenuFields then\r
        self:RefreshMoverMenuFields()\r
    end\r
end\r
\r
function UM:HideGuides()\r
    if not self.guideVertical or not self.guideHorizontal then return end\r
    self.guideVertical:Hide()\r
    self.guideHorizontal:Hide()\r
end\r
\r
function UM:ShowGuideVertical(x)\r
    local guide = self.guideVertical\r
    guide:ClearAllPoints()\r
    guide:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, 0)\r
    guide:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)\r
    guide:SetWidth(1)\r
    guide:Show()\r
end\r
\r
function UM:ShowGuideHorizontal(y)\r
    local guide = self.guideHorizontal\r
    guide:ClearAllPoints()\r
    guide:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, y)\r
    guide:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, y)\r
    guide:SetHeight(1)\r
    guide:Show()\r
end\r
\r
function UM:GetSnapPosition(key, left, top, width, height)\r
    if not self.db.unlockSnap then\r
        self:HideGuides()\r
        return left, top\r
    end\r
\r
    local bestX, bestY\r
    local bestDeltaX = SNAP_DISTANCE + 1\r
    local bestDeltaY = SNAP_DISTANCE + 1\r
\r
    local myTargetsX = {\r
        left,\r
        left + (width * 0.5),\r
        left + width,\r
    }\r
    local myTargetsY = {\r
        top,\r
        top - (height * 0.5),\r
        top - height,\r
    }\r
\r
    self:HideGuides()\r
    local function ConsiderSnapMover(mover)\r
        if not (mover and mover.IsShown and mover:IsShown()) then\r
            return\r
        end\r
\r
        local oLeft = mover:GetLeft()\r
        local oTop = mover:GetTop()\r
        if not (oLeft and oTop) then\r
            return\r
        end\r
\r
        local oWidth = mover:GetWidth()\r
        local oHeight = mover:GetHeight()\r
        local otherTargetsX = { oLeft, oLeft + (oWidth * 0.5), oLeft + oWidth }\r
        local otherTargetsY = { oTop, oTop - (oHeight * 0.5), oTop - oHeight }\r
\r
        for _, myX in ipairs(myTargetsX) do\r
            for _, otherX in ipairs(otherTargetsX) do\r
                local delta = otherX - myX\r
                local deltaAbs = abs(delta)\r
                if deltaAbs < bestDeltaX and deltaAbs <= SNAP_DISTANCE then\r
                    bestDeltaX = deltaAbs\r
                    bestX = left + delta\r
                    self:ShowGuideVertical(otherX)\r
                end\r
            end\r
        end\r
\r
        for _, myY in ipairs(myTargetsY) do\r
            for _, otherY in ipairs(otherTargetsY) do\r
                local delta = otherY - myY\r
                local deltaAbs = abs(delta)\r
                if deltaAbs < bestDeltaY and deltaAbs <= SNAP_DISTANCE then\r
                    bestDeltaY = deltaAbs\r
                    bestY = top + delta\r
                    self:ShowGuideHorizontal(otherY)\r
                end\r
            end\r
        end\r
    end\r
\r
    local preferredTarget = self:GetSnapTarget(key)\r
    local preferredMover = preferredTarget and self.movers and self.movers[preferredTarget] or nil\r
    if preferredTarget and preferredMover and preferredMover:IsShown() then\r
        ConsiderSnapMover(preferredMover)\r
    else\r
        for otherKey, mover in pairs(self.movers) do\r
            if otherKey ~= key then\r
                ConsiderSnapMover(mover)\r
            end\r
        end\r
    end\r
\r
    return bestX or left, bestY or top\r
end\r
\r
function UM:CreateMover(key)\r
    local mover = CreateFrame("Button", nil, self.unlockFrame)\r
    mover.key = key\r
    mover:SetFrameStrata("FULLSCREEN_DIALOG")\r
    mover:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 20)\r
    mover:EnableMouse(true)\r
    mover:RegisterForClicks("LeftButtonUp", "RightButtonUp")\r
    mover:SetClampedToScreen(true)\r
\r
    local theme = GetUnlockTheme()\r
    KT:AddBackdrop(mover, 0, 0, 0, 0.22)\r
    KT:AddBorder(mover, theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
\r
    mover.label = CreateText(mover, 10)\r
    mover.label:SetPoint("CENTER")\r
\r
    mover.coords = CreateText(mover, 9, "LEFT")\r
    mover.coords:SetPoint("TOPLEFT", 4, -4)\r
\r
    mover.close = CreateFrame("Button", nil, mover)\r
    mover.close:SetSize(16, 16)\r
    mover.close:SetPoint("TOPLEFT", 3, -3)\r
    mover.close:RegisterForClicks("LeftButtonUp")\r
    KT:AddBackdrop(mover.close, 0.10, 0.05, 0.05, 0.94)\r
    KT:AddBorder(mover.close, 0.32, 0.14, 0.14, 1)\r
    mover.close.text = CreateText(mover.close, 10)\r
    mover.close.text:SetPoint("CENTER")\r
    mover.close.text:SetText(LText("X"))\r
    mover.close.text:SetTextColor(1, 0.82, 0.82, 1)\r
    mover.close:SetScript("OnEnter", function(widget)\r
        KT:AddBorder(widget, 0.90, 0.28, 0.28, 1)\r
    end)\r
    mover.close:SetScript("OnLeave", function(widget)\r
        KT:AddBorder(widget, 0.32, 0.14, 0.14, 1)\r
    end)\r
    mover.close:SetScript("OnClick", function()\r
        self:SelectMover(key)\r
        local def = self:GetElementDef(key)\r
        if def and type(def.unlockClose) == "function" then\r
            SafeCall(def.unlockClose, key, mover)\r
            mover:Sync()\r
        end\r
    end)\r
    mover.close:Hide()\r
\r
    mover.cog = CreateFrame("Button", nil, mover)\r
    mover.cog:SetSize(16, 16)\r
    mover.cog:SetPoint("TOPRIGHT", -3, -3)\r
    mover.cog.icon = mover.cog:CreateTexture(nil, "ARTWORK")\r
    mover.cog.icon:SetSize(16, 12)\r
    mover.cog.icon:SetPoint("CENTER")\r
    mover.cog.icon:SetTexture(ICON_COG)\r
    mover.cog.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)\r
    mover.cog.icon:SetVertexColor(1, 0.9, 0.9, 1)\r
\r
    mover.hoverGlow = {}\r
    for index = 1, 4 do\r
        local edge = mover:CreateTexture(nil, "ARTWORK", nil, 6)\r
        edge:SetTexture(WHITE8X8)\r
        edge:Hide()\r
        mover.hoverGlow[index] = edge\r
    end\r
\r
    mover.hoverAnimator = CreateFrame("Frame", nil, mover)\r
    mover.hoverProgress = 0\r
    mover.hoverTarget = 0\r
    mover.isHovered = false\r
\r
    mover.ApplyHoverVisual = function(s, progress)\r
        progress = max(0, min(progress or 0, 1))\r
        s.hoverProgress = progress\r
\r
        local eased = progress * progress * (3 - (2 * progress))\r
        local borderR = MOVER_R + ((1 - MOVER_R) * eased)\r
        local borderG = MOVER_G + ((1 - MOVER_G) * eased)\r
        local borderB = MOVER_B + ((1 - MOVER_B) * eased)\r
        local idleBorderAlpha = s.isSelected and 1 or 0.85\r
        local borderAlpha = idleBorderAlpha + ((1 - idleBorderAlpha) * eased)\r
\r
        if s.borderKT and s.borderKT._edges then\r
            for _, edge in ipairs(s.borderKT._edges) do\r
                edge:SetColorTexture(borderR, borderG, borderB, borderAlpha)\r
            end\r
        end\r
\r
        if s.bgKT then\r
            if self.db.unlockDarkOverlays then\r
                local baseAlpha = s.isSelected and 0.30 or 0.22\r
                s.bgKT:SetColorTexture(\r
                    0.03 * eased,\r
                    0.03 * eased,\r
                    0.03 * eased,\r
                    baseAlpha + ((0.34 - baseAlpha) * eased)\r
                )\r
            else\r
                s.bgKT:SetColorTexture(0.03 * eased, 0.03 * eased, 0.03 * eased, 0.02 + (0.06 * eased))\r
            end\r
        end\r
\r
        s.label:ClearAllPoints()\r
        s.label:SetPoint("CENTER", s, "CENTER", 0, -4 * eased)\r
        local idleText = s.isSelected and 0.95 or 0.85\r
        local textValue = idleText + ((1 - idleText) * eased)\r
        s.label:SetTextColor(1, textValue, textValue, 1)\r
\r
        local persistentCoords = self.db.unlockCoords or s.isSelected or s.isDragging\r
        if persistentCoords or progress > 0.01 then\r
            s.coords:Show()\r
            s.coords:SetAlpha(persistentCoords and 1 or eased)\r
        else\r
            s.coords:Hide()\r
        end\r
\r
        if s.cog then\r
            s.cog:SetAlpha(0.35 + (0.65 * eased))\r
            if s.cog.icon then\r
                local themeNow = GetUnlockTheme()\r
                local iconR = themeNow.accent.r + ((1 - themeNow.accent.r) * eased)\r
                local iconG = themeNow.accent.g + ((1 - themeNow.accent.g) * eased)\r
                local iconB = themeNow.accent.b + ((1 - themeNow.accent.b) * eased)\r
                s.cog.icon:SetVertexColor(iconR, iconG, iconB, 1)\r
            end\r
        end\r
\r
        local glow = s.hoverGlow\r
        if glow and progress > 0.01 then\r
            local extent = 1 + (MOVER_HOVER_EXPANSION * eased)\r
            local glowAlpha = 0.42 * (1 - ((1 - eased) * (1 - eased)))\r
            local thickness = 1\r
\r
            glow[1]:ClearAllPoints()\r
            glow[1]:SetPoint("BOTTOMLEFT", s, "TOPLEFT", -extent, extent)\r
            glow[1]:SetPoint("BOTTOMRIGHT", s, "TOPRIGHT", extent, extent)\r
            glow[1]:SetHeight(thickness)\r
\r
            glow[2]:ClearAllPoints()\r
            glow[2]:SetPoint("TOPLEFT", s, "BOTTOMLEFT", -extent, -extent)\r
            glow[2]:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", extent, -extent)\r
            glow[2]:SetHeight(thickness)\r
\r
            glow[3]:ClearAllPoints()\r
            glow[3]:SetPoint("TOPRIGHT", s, "TOPLEFT", -extent, extent)\r
            glow[3]:SetPoint("BOTTOMRIGHT", s, "BOTTOMLEFT", -extent, -extent)\r
            glow[3]:SetWidth(thickness)\r
\r
            glow[4]:ClearAllPoints()\r
            glow[4]:SetPoint("TOPLEFT", s, "TOPRIGHT", extent, extent)\r
            glow[4]:SetPoint("BOTTOMLEFT", s, "BOTTOMRIGHT", extent, -extent)\r
            glow[4]:SetWidth(thickness)\r
\r
            for _, edge in ipairs(glow) do\r
                edge:SetColorTexture(borderR, borderG, borderB, glowAlpha)\r
                edge:Show()\r
            end\r
        elseif glow then\r
            for _, edge in ipairs(glow) do\r
                edge:Hide()\r
            end\r
        end\r
    end\r
\r
    mover.SetHoverTarget = function(s, target)\r
        s.hoverTarget = target and 1 or 0\r
        if abs(s.hoverProgress - s.hoverTarget) < 0.001 then\r
            s.hoverProgress = s.hoverTarget\r
            s.hoverAnimator:SetScript("OnUpdate", nil)\r
            s:ApplyHoverVisual(s.hoverProgress)\r
            return\r
        end\r
\r
        s.hoverAnimator:SetScript("OnUpdate", function(animator, elapsed)\r
            local direction = s.hoverTarget > s.hoverProgress and 1 or -1\r
            s.hoverProgress = s.hoverProgress + (direction * elapsed / MOVER_HOVER_DURATION)\r
            if (direction > 0 and s.hoverProgress >= s.hoverTarget)\r
                or (direction < 0 and s.hoverProgress <= s.hoverTarget) then\r
                s.hoverProgress = s.hoverTarget\r
                animator:SetScript("OnUpdate", nil)\r
            end\r
            s:ApplyHoverVisual(s.hoverProgress)\r
        end)\r
    end\r
\r
    mover.ResetHoverAnimation = function(s)\r
        s.isHovered = false\r
        s.hoverTarget = 0\r
        s.hoverProgress = 0\r
        s.hoverAnimator:SetScript("OnUpdate", nil)\r
        s:ApplyHoverVisual(0)\r
    end\r
\r
    mover.RefreshCoords = function(s)\r
        local pos = self.pendingPositions[s.key]\r
        if not pos then\r
            pos = self:CaptureCurrentPosition(s.key)\r
        end\r
        s.coords:ClearAllPoints()\r
        s.coords:SetPoint("TOPLEFT", (s.close and s.close:IsShown()) and 24 or 4, -4)\r
        s.coords:SetText(string.format("%d, %d", Round(pos.x or 0), Round(pos.y or 0)))\r
        if self.db.unlockCoords or s.isSelected or s.isDragging or s.isHovered then\r
            s.coords:Show()\r
        else\r
            s.coords:Hide()\r
        end\r
    end\r
\r
    mover.RefreshStyle = function(s)\r
        s:ApplyHoverVisual(s.hoverProgress or 0)\r
        s:RefreshCoords()\r
    end\r
\r
    mover.Sync = function(s)\r
        local def = self:GetElementDef(s.key)\r
        local left, top, width, height = self:GetElementRect(s.key)\r
        s:SetSize(max(width, 32), max(height, 24))\r
        SetFrameTopLeft(s, left, top)\r
        s.label:SetText(def and (def.label or s.key) or s.key)\r
        if s.close then\r
            if def and type(def.unlockClose) == "function" then\r
                s.close:Show()\r
            else\r
                s.close:Hide()\r
            end\r
        end\r
        s:RefreshStyle()\r
    end\r
\r
    mover:SetScript("OnMouseDown", function(s, button)\r
        if button ~= "LeftButton" then return end\r
        if InCombatLockdown() then return end\r
        if IsShiftKeyDown() then\r
            if not self:IsMoverSelected(s.key) then\r
                self:ToggleMoverSelection(s.key)\r
            end\r
        elseif not self:IsMoverSelected(s.key) or self:GetSelectedMoverCount() <= 1 then\r
            self:SelectMover(s.key)\r
        end\r
        s.isDragging = true\r
        local scale = UIParent:GetEffectiveScale()\r
        s.dragStartX, s.dragStartY = GetCursorPosition()\r
        s.dragStartX = s.dragStartX / scale\r
        s.dragStartY = s.dragStartY / scale\r
        s.dragLeft = s:GetLeft() or 0\r
        s.dragTop = s:GetTop() or 0\r
        s.dragMembers = {}\r
        for _, dragKey in ipairs(self:GetSelectedMoverKeys()) do\r
            local dragMover = self.movers[dragKey]\r
            if dragMover then\r
                dragMover.isDragging = true\r
                tinsert(s.dragMembers, {\r
                    key = dragKey,\r
                    mover = dragMover,\r
                    left = dragMover:GetLeft() or 0,\r
                    top = dragMover:GetTop() or 0,\r
                })\r
            end\r
        end\r
        s:SetScript("OnUpdate", function(btn)\r
            local cursorX, cursorY = GetCursorPosition()\r
            cursorX = cursorX / scale\r
            cursorY = cursorY / scale\r
            local width = btn:GetWidth()\r
            local height = btn:GetHeight()\r
            local nextLeft = btn.dragLeft + (cursorX - btn.dragStartX)\r
            local nextTop = btn.dragTop + (cursorY - btn.dragStartY)\r
            nextLeft, nextTop = self:GetSnapPosition(btn.key, nextLeft, nextTop, width, height)\r
            local deltaLeft = nextLeft - btn.dragLeft\r
            local deltaTop = nextTop - btn.dragTop\r
            for _, member in ipairs(btn.dragMembers or EMPTY) do\r
                local memberMover = member.mover\r
                local memberLeft = member.left + deltaLeft\r
                local memberTop = member.top + deltaTop\r
                SetFrameTopLeft(memberMover, memberLeft, memberTop)\r
                self:ApplyMoverToElement(member.key, memberMover)\r
                memberMover:RefreshCoords()\r
            end\r
        end)\r
        s:RefreshStyle()\r
    end)\r
\r
    mover:SetScript("OnMouseUp", function(s, button)\r
        if button == "RightButton" then\r
            self:OpenMoverMenu(s.key, s)\r
            return\r
        end\r
        s.isDragging = false\r
        s:SetScript("OnUpdate", nil)\r
        self:HideGuides()\r
        for _, member in ipairs(s.dragMembers or EMPTY) do\r
            member.mover.isDragging = false\r
            member.mover:RefreshStyle()\r
        end\r
        s.dragMembers = nil\r
        s:RefreshStyle()\r
    end)\r
\r
    mover:SetScript("OnEnter", function(s)\r
        s.isHovered = true\r
        s:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 80)\r
        s:SetHoverTarget(true)\r
    end)\r
\r
    mover:SetScript("OnLeave", function(s)\r
        s.isHovered = false\r
        s:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 20)\r
        s:SetHoverTarget(false)\r
    end)\r
\r
    mover:SetScript("OnHide", function(s)\r
        s:ResetHoverAnimation()\r
    end)\r
\r
    mover.cog:SetScript("OnClick", function()\r
        self:SelectMover(key)\r
        \r
        -- Special handling for Unit Frames: open options directly\r
        if key and type(key) == "string" and key:match("^unitframes_") then\r
            local frameType = key:gsub("^unitframes_", "")\r
            -- Map frame types to option page IDs\r
            local pageMap = {\r
                player = "player",\r
                pet = "player",\r
                target = "target",\r
                targettarget = "target",\r
                focus = "target",\r
                focustarget = "target",\r
                boss = "boss",\r
                boss1 = "boss",\r
                boss2 = "boss",\r
                boss3 = "boss",\r
                boss4 = "boss",\r
                boss5 = "boss",\r
            }\r
            local pageId = pageMap[frameType]\r
            if pageId and KT and KT.OpenMainMenu then\r
                KT:OpenMainMenu()\r
                C_Timer.After(0.1, function()\r
                    if KT.MenuPrincipal and KT.MenuPrincipal.NavigateToPage then\r
                        KT.MenuPrincipal:NavigateToPage("unitframes")\r
                        -- Give time for page to load, then switch tab\r
                        C_Timer.After(0.05, function()\r
                            if KT.MenuPrincipal and KT.MenuPrincipal.activePageContext \r
                                and KT.MenuPrincipal.activePageContext.SwitchTab then\r
                                KT.MenuPrincipal.activePageContext:SwitchTab(pageId)\r
                            end\r
                        end)\r
                    end\r
                end)\r
                return\r
            end\r
        end\r
        \r
        -- Default behavior: open mover menu\r
        self:OpenMoverMenu(key, mover)\r
    end)\r
\r
    self.movers[key] = mover\r
    return mover\r
end\r
\r
function UM:CenterMover(key)\r
    local mover = self.movers[key]\r
    if not mover then return end\r
    local uiWidth, uiHeight = GetUIRect()\r
    local left = (uiWidth * 0.5) - (mover:GetWidth() * 0.5)\r
    local top = (uiHeight * 0.5) + (mover:GetHeight() * 0.5)\r
    SetFrameTopLeft(mover, left, top)\r
    self:ApplyMoverToElement(key, mover)\r
    mover:RefreshCoords()\r
end\r
\r
function UM:ResetMover(key)\r
    local mover = self.movers[key]\r
    local snapshot = self.snapshotPositions[key]\r
    if mover and snapshot then\r
        self:ApplyStoredPositionToElement(key, snapshot)\r
        mover:Sync()\r
        self.pendingPositions[key] = nil\r
        self.hasChanges = next(self.pendingPositions) ~= nil\r
        if self.moverMenu and self.moverMenu:IsShown() and self.moverMenu.activeKey == key and self.RefreshMoverMenuFields then\r
            self:RefreshMoverMenuFields()\r
        end\r
    end\r
end\r
\r
function UM:RefreshMoverMenuFields()\r
    local menuFrame = self.moverMenu\r
    if not (menuFrame and menuFrame.activeKey) then\r
        return\r
    end\r
\r
    local key = menuFrame.activeKey\r
    local theme = GetUnlockTheme()\r
    local canEditSize = self:CanEditElementSize(key)\r
    local width, height = self:GetEditableElementSize(key)\r
    local x, y = self:GetMoverStoredXY(key)\r
\r
    menuFrame.fadeTargetID = ResolveMouseoverTargetID(key, self:GetElementDef(key))\r
\r
    if menuFrame.widthRow then\r
        menuFrame.widthRow:SetShown(canEditSize)\r
        if canEditSize then\r
            menuFrame.widthRow.input:SetText(tostring(width or ""))\r
        end\r
        menuFrame.widthRow.label:SetTextColor(theme.muted.r, theme.muted.g, theme.muted.b, 1)\r
        StyleMenuInputBox(menuFrame.widthRow.input)\r
    end\r
    if menuFrame.heightRow then\r
        menuFrame.heightRow:SetShown(canEditSize)\r
        if canEditSize then\r
            menuFrame.heightRow.input:SetText(tostring(height or ""))\r
        end\r
        menuFrame.heightRow.label:SetTextColor(theme.muted.r, theme.muted.g, theme.muted.b, 1)\r
        StyleMenuInputBox(menuFrame.heightRow.input)\r
    end\r
    if menuFrame.xRow then\r
        menuFrame.xRow.input:SetText(tostring(x or 0))\r
        menuFrame.xRow.label:SetTextColor(theme.muted.r, theme.muted.g, theme.muted.b, 1)\r
        StyleMenuInputBox(menuFrame.xRow.input)\r
    end\r
    if menuFrame.yRow then\r
        menuFrame.yRow.input:SetText(tostring(y or 0))\r
        menuFrame.yRow.label:SetTextColor(theme.muted.r, theme.muted.g, theme.muted.b, 1)\r
        StyleMenuInputBox(menuFrame.yRow.input)\r
    end\r
\r
    if menuFrame.snapHeader then\r
        menuFrame.snapHeader:SetTextColor(theme.muted.r, theme.muted.g, theme.muted.b, 1)\r
    end\r
    if menuFrame.snapButton then\r
        RefreshPanelButtonTheme(menuFrame.snapButton)\r
        menuFrame.snapButton.text:SetText(self:GetSnapTargetLabel(key))\r
        menuFrame.snapButton.text:SetTextColor(theme.text.r, theme.text.g, theme.text.b, 1)\r
        if menuFrame.snapButton.arrow then\r
            menuFrame.snapButton.arrow:SetTextColor(theme.soft.r, theme.soft.g, theme.soft.b, 1)\r
        end\r
    end\r
\r
    if menuFrame.fade and menuFrame.fade.SetVisualState then\r
        RefreshPanelButtonTheme(menuFrame.fade)\r
        menuFrame.fade:SetVisualState(GetMouseoverSetting(menuFrame.fadeTargetID))\r
    end\r
    if menuFrame.center then\r
        RefreshPanelButtonTheme(menuFrame.center)\r
    end\r
    if menuFrame.reset then\r
        RefreshPanelButtonTheme(menuFrame.reset)\r
    end\r
\r
    if menuFrame.UpdateLayout then\r
        menuFrame:UpdateLayout()\r
    end\r
\r
    if menuFrame.snapList and menuFrame.snapList:IsShown() then\r
        self:ToggleMoverSnapList(nil, true)\r
    end\r
end\r
\r
function UM:ToggleMoverSnapList(anchorButton, forceRefresh)\r
    local menuFrame = self.moverMenu\r
    local snapList = menuFrame and menuFrame.snapList\r
    if not (menuFrame and snapList and menuFrame.activeKey) then\r
        return\r
    end\r
\r
    if snapList:IsShown() and not forceRefresh then\r
        snapList:Hide()\r
        return\r
    end\r
\r
    snapList.buttons = snapList.buttons or {}\r
    for _, button in ipairs(snapList.buttons) do\r
        button:Hide()\r
    end\r
\r
    local theme = GetUnlockTheme()\r
    local options = self:GetSnapTargetOptions(menuFrame.activeKey)\r
    local currentTarget = self:GetSnapTarget(menuFrame.activeKey)\r
    local buttonWidth = 170\r
    local buttonHeight = 20\r
\r
    for index, option in ipairs(options) do\r
        local button = snapList.buttons[index]\r
        if not button then\r
            button = CreatePanelButton(snapList, buttonWidth, buttonHeight, "")\r
            button.text:ClearAllPoints()\r
            button.text:SetPoint("LEFT", 8, 0)\r
            button.text:SetPoint("RIGHT", -8, 0)\r
            button.text:SetJustifyH("LEFT")\r
            snapList.buttons[index] = button\r
        end\r
\r
        button:SetPoint("TOPLEFT", 5, -(5 + ((index - 1) * (buttonHeight + 2))))\r
        button.text:SetText(option.label or "")\r
        local isSelected = (option.value == nil and currentTarget == nil) or option.value == currentTarget\r
        if isSelected then\r
            button.normalColor = { theme.active.r, theme.active.g, theme.active.b, 0.96 }\r
            button.hoverColor = { theme.activeHover.r, theme.activeHover.g, theme.activeHover.b, 1.0 }\r
            if button.bgKT then\r
                button.bgKT:SetColorTexture(unpack(button.normalColor))\r
            end\r
            KT:AddBorder(button, theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
            button.text:SetTextColor(1, 1, 1, 1)\r
        else\r
            button.normalColor = { theme.background.r, theme.background.g, theme.background.b, 0.94 }\r
            button.hoverColor = { theme.hover.r, theme.hover.g, theme.hover.b, 0.98 }\r
            if button.bgKT then\r
                button.bgKT:SetColorTexture(unpack(button.normalColor))\r
            end\r
            KT:AddBorder(button, theme.soft.r, theme.soft.g, theme.soft.b, 1)\r
            button.text:SetTextColor(theme.text.r, theme.text.g, theme.text.b, 1)\r
        end\r
        button:Show()\r
\r
        button:SetScript("OnClick", function()\r
            self:SetSnapTarget(menuFrame.activeKey, option.value)\r
            snapList:Hide()\r
            self:RefreshMoverMenuFields()\r
        end)\r
    end\r
\r
    snapList:SetSize(buttonWidth + 10, 10 + (#options * (buttonHeight + 2)))\r
    snapList:ClearAllPoints()\r
    snapList:SetPoint("TOPLEFT", anchorButton or menuFrame.snapButton, "BOTTOMLEFT", 0, -4)\r
    snapList:Show()\r
end\r
\r
function UM:OpenMoverMenu(key, anchor)\r
    local menuFrame = self.moverMenu\r
    if not menuFrame then\r
        menuFrame = CreateFrame("Frame", "KullThranUIUnlockModeMenu", self.unlockFrame)\r
        menuFrame:SetSize(190, 190)\r
        menuFrame:SetFrameStrata("FULLSCREEN_DIALOG")\r
        menuFrame:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 80)\r
        menuFrame:SetClampedToScreen(true)\r
        KT:AddBackdrop(menuFrame, 0.02, 0.03, 0.04, 0.96)\r
        KT:AddBorder(menuFrame, MOVER_R, MOVER_G, MOVER_B, 1)\r
\r
        local function CreateValueRow(parent, labelText)\r
            local row = CreateFrame("Frame", nil, parent)\r
            row:SetSize(174, 20)\r
            row.label = CreateText(row, 10, "LEFT")\r
            row.label:SetPoint("LEFT", 2, 0)\r
            row.label:SetText(LText(labelText))\r
            row.input = CreateMenuInputBox(row, 62, 18)\r
            row.input:SetPoint("RIGHT", -2, 0)\r
            row.CommitValue = function(selfRow)\r
                if not (menuFrame and menuFrame.activeKey and selfRow.applyValue) then\r
                    return\r
                end\r
                local value = tonumber(selfRow.input:GetText())\r
                if not value then\r
                    UM:RefreshMoverMenuFields()\r
                    return\r
                end\r
                selfRow.applyValue(Round(value))\r
                UM:RefreshMoverMenuFields()\r
            end\r
            row.input:SetScript("OnEnterPressed", function(self)\r
                row:CommitValue()\r
                self:ClearFocus()\r
            end)\r
            row.input:SetScript("OnEscapePressed", function(self)\r
                self:ClearFocus()\r
                UM:RefreshMoverMenuFields()\r
            end)\r
            row.input:HookScript("OnEditFocusLost", function()\r
                row:CommitValue()\r
            end)\r
            return row\r
        end\r
\r
        menuFrame.widthRow = CreateValueRow(menuFrame, "Width")\r
        menuFrame.widthRow.applyValue = function(value)\r
            local _, currentHeight = self:GetEditableElementSize(menuFrame.activeKey)\r
            self:SetEditableElementSize(menuFrame.activeKey, value, currentHeight or value)\r
        end\r
\r
        menuFrame.heightRow = CreateValueRow(menuFrame, "Height")\r
        menuFrame.heightRow.applyValue = function(value)\r
            local currentWidth = self:GetEditableElementSize(menuFrame.activeKey)\r
            self:SetEditableElementSize(menuFrame.activeKey, currentWidth or value, value)\r
        end\r
\r
        menuFrame.xRow = CreateValueRow(menuFrame, "X Position")\r
        menuFrame.xRow.applyValue = function(value)\r
            local _, currentY = self:GetMoverStoredXY(menuFrame.activeKey)\r
            self:SetMoverStoredXY(menuFrame.activeKey, value, currentY)\r
        end\r
\r
        menuFrame.yRow = CreateValueRow(menuFrame, "Y Position")\r
        menuFrame.yRow.applyValue = function(value)\r
            local currentX = self:GetMoverStoredXY(menuFrame.activeKey)\r
            self:SetMoverStoredXY(menuFrame.activeKey, currentX, value)\r
        end\r
\r
        menuFrame.snapHeader = CreateText(menuFrame, 10, "LEFT")\r
        menuFrame.snapHeader:SetText(LText("Select Snap Target"))\r
\r
        menuFrame.snapButton = CreatePanelButton(menuFrame, 174, 22, "")\r
        menuFrame.snapButton.text:ClearAllPoints()\r
        menuFrame.snapButton.text:SetPoint("LEFT", 8, 0)\r
        menuFrame.snapButton.text:SetPoint("RIGHT", -18, 0)\r
        menuFrame.snapButton.text:SetJustifyH("LEFT")\r
        menuFrame.snapButton.arrow = CreateText(menuFrame.snapButton, 12, "RIGHT")\r
        menuFrame.snapButton.arrow:SetPoint("RIGHT", -8, 0)\r
        menuFrame.snapButton.arrow:SetText(">")\r
        menuFrame.snapButton:SetScript("OnClick", function(button)\r
            self:ToggleMoverSnapList(button)\r
        end)\r
\r
        menuFrame.fade = CreatePanelButton(menuFrame, 174, 22, LText("Fade on Mouseover"))\r
        menuFrame.fade.text:ClearAllPoints()\r
        menuFrame.fade.text:SetPoint("LEFT", 8, 0)\r
        menuFrame.fade.text:SetJustifyH("LEFT")\r
        menuFrame.fade.indicator = CreateText(menuFrame.fade, 11, "RIGHT")\r
        menuFrame.fade.indicator:SetPoint("RIGHT", -8, 0)\r
        menuFrame.fade.SetVisualState = function(button, enabled)\r
            button.isChecked = enabled == true\r
            if button.isChecked then\r
                button.indicator:SetText(LText("ON"))\r
                button.indicator:SetTextColor(0.72, 1, 0.76, 1)\r
            else\r
                button.indicator:SetText(LText("OFF"))\r
                button.indicator:SetTextColor(1, 0.82, 0.82, 1)\r
            end\r
        end\r
        menuFrame.fade:SetScript("OnClick", function(button)\r
            local targetID = menuFrame.fadeTargetID\r
            if not targetID then\r
                return\r
            end\r
\r
            local nextValue = not GetMouseoverSetting(targetID)\r
            SetMouseoverSetting(targetID, nextValue)\r
            button:SetVisualState(nextValue)\r
            RefreshMouseoverModules(targetID)\r
        end)\r
\r
        menuFrame.configure = CreatePanelButton(menuFrame, 174, 22, LText("Open Configuration"))\r
        menuFrame.configure:SetScript("OnClick", function()\r
            local activeKey = menuFrame.activeKey\r
            local def = activeKey and self:GetElementDef(activeKey)\r
            local page = def and (def.optionsPage or def.pageId or def.configPage)\r
            local group = def and def.group\r
            menuFrame:Hide()\r
            self:CloseUnlockMode(true, true)\r
            if page and KT.OpenMenu then\r
                KT:OpenMenu(page)\r
            elseif group and KT.ShowModule then\r
                KT:ShowModule(group)\r
            end\r
        end)\r
\r
        menuFrame.center = CreatePanelButton(menuFrame, 174, 22, LText("Center on Screen"))\r
        menuFrame.center:SetScript("OnClick", function()\r
            if menuFrame.activeKey then\r
                self:CenterMover(menuFrame.activeKey)\r
                self:RefreshMoverMenuFields()\r
            end\r
        end)\r
\r
        menuFrame.reset = CreatePanelButton(menuFrame, 174, 22, LText("Reset Position"))\r
        menuFrame.reset:SetScript("OnClick", function()\r
            if menuFrame.activeKey then\r
                self:ResetMover(menuFrame.activeKey)\r
                self:RefreshMoverMenuFields()\r
            end\r
        end)\r
\r
        menuFrame.snapList = CreateFrame("Frame", nil, self.unlockFrame)\r
        menuFrame.snapList:SetFrameStrata("FULLSCREEN_DIALOG")\r
        menuFrame.snapList:SetFrameLevel(menuFrame:GetFrameLevel() + 5)\r
        menuFrame.snapList:SetClampedToScreen(true)\r
        KT:AddBackdrop(menuFrame.snapList, 0.02, 0.03, 0.04, 0.98)\r
        KT:AddBorder(menuFrame.snapList, MOVER_R, MOVER_G, MOVER_B, 1)\r
        menuFrame.snapList:Hide()\r
\r
        menuFrame.UpdateLayout = function(frame)\r
            local y = -8\r
\r
            local function PlaceRow(row, extraGap)\r
                if not (row and row:IsShown()) then\r
                    return\r
                end\r
                row:ClearAllPoints()\r
                row:SetPoint("TOPLEFT", 8, y)\r
                y = y - row:GetHeight() - (extraGap or 4)\r
            end\r
\r
            PlaceRow(frame.widthRow)\r
            PlaceRow(frame.heightRow)\r
            PlaceRow(frame.xRow)\r
            PlaceRow(frame.yRow, 6)\r
\r
            frame.snapHeader:ClearAllPoints()\r
            frame.snapHeader:SetPoint("TOPLEFT", 10, y)\r
            y = y - 14\r
\r
            frame.snapButton:ClearAllPoints()\r
            frame.snapButton:SetPoint("TOPLEFT", 8, y)\r
            y = y - 26\r
\r
            if frame.fadeTargetID then\r
                frame.fade:Show()\r
                frame.fade:SetVisualState(GetMouseoverSetting(frame.fadeTargetID))\r
                PlaceRow(frame.fade)\r
            else\r
                frame.fade:Hide()\r
            end\r
\r
            PlaceRow(frame.configure)\r
            PlaceRow(frame.center)\r
            PlaceRow(frame.reset)\r
\r
            frame:SetHeight(abs(y) + 8)\r
        end\r
\r
        menuFrame:SetScript("OnHide", function(frame)\r
            if frame.snapList then\r
                frame.snapList:Hide()\r
            end\r
        end)\r
\r
        menuFrame:Hide()\r
        self.moverMenu = menuFrame\r
    end\r
\r
    if menuFrame:IsShown() and menuFrame.activeKey == key then\r
        menuFrame:Hide()\r
        return\r
    end\r
\r
    menuFrame.activeKey = key\r
    if menuFrame.snapList then\r
        menuFrame.snapList:Hide()\r
    end\r
    self:RefreshMoverMenuFields()\r
    menuFrame:ClearAllPoints()\r
    menuFrame:SetPoint("TOPLEFT", anchor or self.movers[key] or self.unlockFrame, "TOPRIGHT", 6, 0)\r
    menuFrame:Show()\r
end\r
\r
function UM:RefreshMovers()\r
    local visible = {}\r
    for _, key in ipairs(self.registryOrder) do\r
        if not self:IsElementHidden(key) then\r
            local mover = self.movers[key] or self:CreateMover(key)\r
            mover:Sync()\r
            mover:Show()\r
            visible[key] = true\r
        end\r
    end\r
\r
    for key, mover in pairs(self.movers) do\r
        if not visible[key] then\r
            mover:Hide()\r
        end\r
    end\r
end\r
\r
function UM:CreateGrid()\r
    if self.gridFrame then return end\r
    local grid = CreateFrame("Frame", nil, self.unlockFrame)\r
    grid:SetAllPoints(UIParent)\r
    grid.lines = {}\r
    self.gridFrame = grid\r
end\r
\r
function UM:RebuildGrid()\r
    self:CreateGrid()\r
    local grid = self.gridFrame\r
    for _, line in ipairs(grid.lines) do\r
        line:Hide()\r
    end\r
    wipe(grid.lines)\r
\r
    local uiWidth, uiHeight = GetUIRect()\r
    local alpha = self.db.unlockGrid == "bright" and 0.30 or 0.15\r
    local centerAlpha = self.db.unlockGrid == "bright" and 0.50 or 0.25\r
\r
    local theme = GetUnlockTheme()\r
    for x = 0, uiWidth, GRID_SIZE do\r
        local line = grid:CreateTexture(nil, "BACKGROUND")\r
        line:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, (abs(x - (uiWidth * 0.5)) < 1) and centerAlpha or alpha)\r
        line:SetPoint("TOPLEFT", x, 0)\r
        line:SetPoint("BOTTOMLEFT", x, 0)\r
        line:SetWidth(1)\r
        tinsert(grid.lines, line)\r
    end\r
\r
    for y = 0, uiHeight, GRID_SIZE do\r
        local line = grid:CreateTexture(nil, "BACKGROUND")\r
        line:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, (abs(y - (uiHeight * 0.5)) < 1) and centerAlpha or alpha)\r
        line:SetPoint("TOPLEFT", 0, -y)\r
        line:SetPoint("TOPRIGHT", 0, -y)\r
        line:SetHeight(1)\r
        tinsert(grid.lines, line)\r
    end\r
\r
    if self.db.unlockGrid == "disabled" then\r
        grid:Hide()\r
    else\r
        grid:Show()\r
    end\r
end\r
\r
function UM:CreateSidebar()\r
    if self.sidebar then return end\r
\r
    local theme = GetUnlockTheme()\r
    local sidebar = CreateFrame("Frame", nil, self.unlockFrame)\r
    sidebar:SetSize(SIDEBAR_WIDTH, SIDEBAR_HEIGHT)\r
    sidebar:SetPoint("LEFT", UIParent, "LEFT", 0, 0)\r
    sidebar:SetFrameStrata("FULLSCREEN_DIALOG")\r
    sidebar:SetFrameLevel((self.unlockFrame and self.unlockFrame:GetFrameLevel() or 0) + 50)\r
    sidebar:SetToplevel(true)\r
    sidebar:SetClampedToScreen(true)\r
    sidebar:EnableMouse(true)\r
    sidebar.bgArt = sidebar:CreateTexture(nil, "BACKGROUND", nil, -8)\r
    sidebar.bgArt:SetAllPoints()\r
    sidebar.bgArt:SetTexture(SIDEBAR_TEXTURE)\r
    sidebar.bgArt:SetVertexColor(theme.art.r, theme.art.g, theme.art.b, 1)\r
\r
    sidebar.bgVeil = sidebar:CreateTexture(nil, "BACKGROUND", nil, -7)\r
    sidebar.bgVeil:SetAllPoints()\r
    sidebar.bgVeil:SetTexture(SIDEBAR_TEXTURE)\r
    sidebar.bgVeil:SetVertexColor(theme.background.r, theme.background.g, theme.background.b, 0.12)\r
\r
    sidebar.edgeGlow = sidebar:CreateTexture(nil, "BORDER", nil, -7)\r
    sidebar.edgeGlow:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -6, -SIDEBAR_TOP_SAFE)\r
    sidebar.edgeGlow:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -6, SIDEBAR_BOTTOM_SAFE)\r
    sidebar.edgeGlow:SetWidth(1)\r
    sidebar.edgeGlow:SetColorTexture(1, 1, 1, 0.03)\r
\r
    local title = CreateText(sidebar, 13)\r
    title:SetPoint("TOPLEFT", 14, -46)\r
    title:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 15, "OUTLINE")\r
    title:SetShadowOffset(1, -1)\r
    title:SetShadowColor(0, 0, 0, 1)\r
    title:SetText(LText("EDIT MODE"))\r
    title:SetJustifyH("LEFT")\r
    title:SetTextColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
    sidebar.title = title\r
\r
    sidebar.titleRule = sidebar:CreateTexture(nil, "ARTWORK", nil, -4)\r
    sidebar.titleRule:SetPoint("TOPLEFT", 14, -74)\r
    sidebar.titleRule:SetHeight(1)\r
    sidebar.titleRule:SetWidth(136)\r
    sidebar.titleRule:SetTexture(WHITE8X8)\r
    ApplyTextureGradient(sidebar.titleRule, "HORIZONTAL",\r
        theme.accent.r, theme.accent.g, theme.accent.b, 0.24,\r
        theme.accent.r, theme.accent.g, theme.accent.b, 0)\r
\r
    sidebar.controlsPanel = CreateFrame("Frame", nil, sidebar)\r
    sidebar.controlsPanel:SetPoint("TOPLEFT", 10, -88)\r
    sidebar.controlsPanel:SetSize(154, 148)\r
    ApplySidebarPanelStyle(sidebar.controlsPanel, "controls")\r
\r
    sidebar.toggleGrid = CreatePanelButton(sidebar, 146, 28, "")\r
    sidebar.toggleGrid:SetPoint("TOPLEFT", 14, -102)\r
    StyleSidebarButton(sidebar.toggleGrid, "toggle")\r
    sidebar.toggleGrid:SetScript("OnClick", function()\r
        if self.db.unlockGrid == "disabled" then\r
            self.db.unlockGrid = "dimmed"\r
        elseif self.db.unlockGrid == "dimmed" then\r
            self.db.unlockGrid = "bright"\r
        else\r
            self.db.unlockGrid = "disabled"\r
        end\r
        self:RebuildGrid()\r
        self:RefreshSidebar()\r
    end)\r
\r
    sidebar.toggleSnap = CreatePanelButton(sidebar, 146, 28, "")\r
    sidebar.toggleSnap:SetPoint("TOPLEFT", sidebar.toggleGrid, "BOTTOMLEFT", 0, -6)\r
    StyleSidebarButton(sidebar.toggleSnap, "toggle")\r
    sidebar.toggleSnap:SetScript("OnClick", function()\r
        self.db.unlockSnap = not self.db.unlockSnap\r
        self:RefreshSidebar()\r
    end)\r
\r
    sidebar.toggleDark = CreatePanelButton(sidebar, 146, 28, "")\r
    sidebar.toggleDark:SetPoint("TOPLEFT", sidebar.toggleSnap, "BOTTOMLEFT", 0, -6)\r
    StyleSidebarButton(sidebar.toggleDark, "toggle")\r
    sidebar.toggleDark:SetScript("OnClick", function()\r
        self.db.unlockDarkOverlays = not self.db.unlockDarkOverlays\r
        for _, mover in pairs(self.movers) do\r
            mover:RefreshStyle()\r
        end\r
        self:RefreshSidebar()\r
    end)\r
\r
    sidebar.toggleCoords = CreatePanelButton(sidebar, 146, 28, "")\r
    sidebar.toggleCoords:SetPoint("TOPLEFT", sidebar.toggleDark, "BOTTOMLEFT", 0, -6)\r
    StyleSidebarButton(sidebar.toggleCoords, "toggle")\r
    sidebar.toggleCoords:SetScript("OnClick", function()\r
        self.db.unlockCoords = not self.db.unlockCoords\r
        for _, mover in pairs(self.movers) do\r
            mover:RefreshCoords()\r
        end\r
        self:RefreshSidebar()\r
    end)\r
\r
    local header = CreateText(sidebar, 10, "LEFT")\r
    header:SetPoint("TOPLEFT", 14, -236)\r
    header:SetFont(KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 13, "OUTLINE")\r
    header:SetText(LText("KUI ELEMENTS"))\r
    header:SetTextColor(theme.soft.r, theme.soft.g, theme.soft.b, 1)\r
    sidebar.header = header\r
\r
    sidebar.listPanel = CreateFrame("Frame", nil, sidebar)\r
    sidebar.listPanel:SetPoint("TOPLEFT", 10, -254)\r
    sidebar.listPanel:SetPoint("BOTTOMRIGHT", -20, SIDEBAR_BOTTOM_SAFE + 40)\r
    ApplySidebarPanelStyle(sidebar.listPanel, "list")\r
\r
    sidebar.headerRule = sidebar:CreateTexture(nil, "ARTWORK", nil, -3)\r
    sidebar.headerRule:SetPoint("TOPLEFT", 14, -254)\r
    sidebar.headerRule:SetHeight(1)\r
    sidebar.headerRule:SetWidth(146)\r
    sidebar.headerRule:SetTexture(WHITE8X8)\r
    ApplyTextureGradient(sidebar.headerRule, "HORIZONTAL",\r
        theme.accent.r, theme.accent.g, theme.accent.b, 0.18,\r
        theme.accent.r, theme.accent.g, theme.accent.b, 0)\r
\r
    local scroll = CreateFrame("ScrollFrame", nil, sidebar, "UIPanelScrollFrameTemplate")\r
    scroll:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 14, -262)\r
    scroll:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -22, SIDEBAR_BOTTOM_SAFE + 46)\r
    sidebar.scroll = scroll\r
\r
    local content = CreateFrame("Frame", nil, scroll)\r
    content:SetSize(142, 392)\r
    scroll:SetScrollChild(content)\r
    sidebar.content = content\r
    sidebar.itemButtons = {}\r
\r
    local scrollbar = scroll.ScrollBar\r
    if scrollbar then\r
        scrollbar:ClearAllPoints()\r
        scrollbar:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -12, -262)\r
        scrollbar:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", -12, SIDEBAR_BOTTOM_SAFE + 46)\r
        scrollbar:SetWidth(12)\r
        if scrollbar.Track then scrollbar.Track:Hide() end\r
        if scrollbar.Top then scrollbar.Top:Hide() end\r
        if scrollbar.Bottom then scrollbar.Bottom:Hide() end\r
        if scrollbar.Middle then scrollbar.Middle:Hide() end\r
        if scrollbar.BG then scrollbar.BG:Hide() end\r
        if scrollbar.ScrollUpButton then\r
            scrollbar.ScrollUpButton:Hide()\r
            scrollbar.ScrollUpButton:SetHeight(0.01)\r
        end\r
        if scrollbar.ScrollDownButton then\r
            scrollbar.ScrollDownButton:Hide()\r
            scrollbar.ScrollDownButton:SetHeight(0.01)\r
        end\r
        sidebar.scrollbarTrack = sidebar.scrollbarTrack or CreateFrame("Frame", nil, scrollbar)\r
        sidebar.scrollbarTrack:SetPoint("TOPLEFT", 2, -2)\r
        sidebar.scrollbarTrack:SetPoint("BOTTOMRIGHT", -2, 2)\r
        KT:AddBackdrop(sidebar.scrollbarTrack, 0.01, 0.01, 0.01, 0.96)\r
        KT:AddBorder(sidebar.scrollbarTrack, theme.accent.r, theme.accent.g, theme.accent.b, 0.55)\r
        sidebar.scrollbarTrackLeft = sidebar.scrollbarTrackLeft or scrollbar:CreateTexture(nil, "BACKGROUND", nil, 2)\r
        sidebar.scrollbarTrackLeft:SetPoint("TOPLEFT", sidebar.scrollbarTrack, "TOPLEFT", 0, 0)\r
        sidebar.scrollbarTrackLeft:SetPoint("BOTTOMLEFT", sidebar.scrollbarTrack, "BOTTOMLEFT", 0, 0)\r
        sidebar.scrollbarTrackLeft:SetWidth(1)\r
        sidebar.scrollbarTrackRight = sidebar.scrollbarTrackRight or scrollbar:CreateTexture(nil, "BACKGROUND", nil, 2)\r
        sidebar.scrollbarTrackRight:SetPoint("TOPRIGHT", sidebar.scrollbarTrack, "TOPRIGHT", 0, 0)\r
        sidebar.scrollbarTrackRight:SetPoint("BOTTOMRIGHT", sidebar.scrollbarTrack, "BOTTOMRIGHT", 0, 0)\r
        sidebar.scrollbarTrackRight:SetWidth(1)\r
\r
        local thumb = scrollbar.ThumbTexture or scrollbar:GetThumbTexture()\r
        if thumb then\r
            thumb:SetTexture("Interface\\Buttons\\WHITE8x8")\r
            thumb:SetVertexColor(MOVER_R, MOVER_G, MOVER_B, 0.95)\r
            thumb:SetWidth(8)\r
            sidebar.scrollbarThumb = thumb\r
            sidebar.scrollbarThumbGlow = sidebar.scrollbarThumbGlow or scrollbar:CreateTexture(nil, "ARTWORK", nil, 1)\r
            sidebar.scrollbarThumbGlow:SetTexture(WHITE8X8)\r
            sidebar.scrollbarThumbGlow:SetBlendMode("ADD")\r
            sidebar.scrollbarThumbGlow:ClearAllPoints()\r
            sidebar.scrollbarThumbGlow:SetPoint("CENTER", thumb, "CENTER", 0, 0)\r
            sidebar.scrollbarThumbGlow:SetWidth(14)\r
            sidebar.scrollbarThumbGlow:SetHeight(54)\r
            sidebar.scrollbarThumbBorder = sidebar.scrollbarThumbBorder or CreateFrame("Frame", nil, scrollbar)\r
            sidebar.scrollbarThumbBorder:SetFrameLevel(scrollbar:GetFrameLevel() + 6)\r
            sidebar.scrollbarThumbBorder:ClearAllPoints()\r
            sidebar.scrollbarThumbBorder:SetPoint("TOPLEFT", thumb, "TOPLEFT", -1, 1)\r
            sidebar.scrollbarThumbBorder:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", 1, -1)\r
            KT:AddBorder(sidebar.scrollbarThumbBorder, theme.accent.r, theme.accent.g, theme.accent.b, 0.82)\r
\r
            scrollbar:HookScript("OnMouseDown", function()\r
                sidebar.scrollbarDragging = true\r
                SetScrollbarThumbState(sidebar, "drag")\r
            end)\r
            scrollbar:HookScript("OnMouseUp", function()\r
                sidebar.scrollbarDragging = nil\r
                SetScrollbarThumbState(sidebar, scrollbar:IsMouseOver() and "hover" or "normal")\r
            end)\r
            scrollbar:HookScript("OnEnter", function()\r
                if not sidebar.scrollbarDragging then\r
                    SetScrollbarThumbState(sidebar, "hover")\r
                end\r
            end)\r
            scrollbar:HookScript("OnLeave", function()\r
                if not sidebar.scrollbarDragging then\r
                    SetScrollbarThumbState(sidebar, "normal")\r
                end\r
            end)\r
            scrollbar:HookScript("OnValueChanged", function()\r
                if sidebar.scrollbarDragging then\r
                    SetScrollbarThumbState(sidebar, "drag")\r
                end\r
            end)\r
            SetScrollbarThumbState(sidebar, "normal")\r
        end\r
    end\r
\r
    sidebar.footerPanel = CreateFrame("Frame", nil, sidebar)\r
    sidebar.footerPanel:SetPoint("BOTTOMLEFT", 10, SIDEBAR_BOTTOM_SAFE - 8)\r
    sidebar.footerPanel:SetPoint("BOTTOMRIGHT", -20, SIDEBAR_BOTTOM_SAFE + 40)\r
    ApplySidebarPanelStyle(sidebar.footerPanel, "footer")\r
\r
    sidebar.discard = CreatePanelButton(sidebar, 70, 30, LText("Discard"))\r
    sidebar.discard:SetPoint("BOTTOMLEFT", 14, SIDEBAR_BOTTOM_SAFE)\r
    StyleSidebarButton(sidebar.discard, "footer_red")\r
    sidebar.discard:SetScript("OnClick", function()\r
        if self.hasChanges then\r
            StaticPopup_Show("KULLTHRANUI_UNLOCKMODE_UNSAVED")\r
            return\r
        end\r
        self:CloseUnlockMode(false, true)\r
    end)\r
\r
    sidebar.save = CreatePanelButton(sidebar, 70, 30, LText("Save"))\r
    sidebar.save:SetPoint("BOTTOMRIGHT", -28, SIDEBAR_BOTTOM_SAFE)\r
    StyleSidebarButton(sidebar.save, "footer_green")\r
    sidebar.save:SetScript("OnClick", function()\r
        self:CloseUnlockMode(true, true)\r
    end)\r
\r
    self.sidebar = sidebar\r
end\r
\r
function UM:RefreshSidebar()\r
    self:CreateSidebar()\r
\r
    local gridMode = self.db.unlockGrid or "dimmed"\r
    self.sidebar.toggleGrid.text:SetText("Grid: " .. gridMode)\r
    self.sidebar.toggleSnap.text:SetText("Snap: " .. (self.db.unlockSnap and "On" or "Off"))\r
    self.sidebar.toggleDark.text:SetText("Dark: " .. (self.db.unlockDarkOverlays and "On" or "Off"))\r
    self.sidebar.toggleCoords.text:SetText("Coords: " .. (self.db.unlockCoords and "On" or "Off"))\r
\r
    local content = self.sidebar.content\r
    for _, button in ipairs(self.sidebar.itemButtons) do\r
        button:Hide()\r
    end\r
    wipe(self.sidebar.itemButtons)\r
\r
    local offsetY = -2\r
    local lastGroup\r
    for _, key in ipairs(self.registryOrder) do\r
        if not self:IsElementHidden(key) then\r
            local def = self:GetElementDef(key)\r
            local group = def.group or "Other"\r
            if group ~= lastGroup then\r
                local groupButton = CreatePanelButton(content, 142, 20, string.upper(group))\r
                groupButton:SetPoint("TOPLEFT", 0, offsetY)\r
                StyleSidebarButton(groupButton, "group")\r
                groupButton:Disable()\r
                groupButton.text:SetJustifyH("LEFT")\r
                groupButton.text:SetPoint("LEFT", 0, 0)\r
                tinsert(self.sidebar.itemButtons, groupButton)\r
                offsetY = offsetY - 22\r
                lastGroup = group\r
            end\r
\r
            local item = CreatePanelButton(content, 142, 20, def.label or key)\r
            item.key = key\r
            item:SetPoint("TOPLEFT", 0, offsetY)\r
            StyleSidebarButton(item, "item")\r
            item.text:SetJustifyH("LEFT")\r
            item.text:SetPoint("LEFT", 6, 0)\r
            item:SetScript("OnClick", function()\r
                if IsShiftKeyDown() then\r
                    self:ToggleMoverSelection(key)\r
                else\r
                    self:SelectMover(key)\r
                end\r
                local mover = self.movers[key]\r
                if mover then\r
                    mover:SetFrameLevel(self.unlockFrame:GetFrameLevel() + 60)\r
                end\r
            end)\r
            tinsert(self.sidebar.itemButtons, item)\r
            offsetY = offsetY - 22\r
        end\r
    end\r
\r
    content:SetHeight(max(-offsetY + 10, 318))\r
    self:RefreshSidebarSelection()\r
end\r
\r
function UM:ApplyTheme()\r
    local theme = GetUnlockTheme()\r
\r
    if self.unlockFrame then\r
        if self.unlockFrame.overlay then\r
            self.unlockFrame.overlay:SetColorTexture(0.01, 0.01, 0.01, 0.20)\r
        end\r
        if self.guideVertical then\r
            self.guideVertical:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)\r
        end\r
        if self.guideHorizontal then\r
            self.guideHorizontal:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)\r
        end\r
    end\r
\r
    if self.moverMenu then\r
        KT:AddBorder(self.moverMenu, theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
        if self.moverMenu.snapList then\r
            KT:AddBorder(self.moverMenu.snapList, theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
        end\r
        if self.RefreshMoverMenuFields and self.moverMenu.activeKey then\r
            self:RefreshMoverMenuFields()\r
        end\r
    end\r
\r
    if self.sidebar then\r
        if self.sidebar.bgArt then\r
            self.sidebar.bgArt:SetVertexColor(theme.art.r, theme.art.g, theme.art.b, 1)\r
        end\r
        if self.sidebar.bgVeil then\r
            self.sidebar.bgVeil:SetVertexColor(theme.background.r, theme.background.g, theme.background.b, 0.12)\r
        end\r
        if self.sidebar.title then\r
            self.sidebar.title:SetTextColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
        end\r
        if self.sidebar.titleRule then\r
            ApplyTextureGradient(self.sidebar.titleRule, "HORIZONTAL",\r
                theme.accent.r, theme.accent.g, theme.accent.b, 0.24,\r
                theme.accent.r, theme.accent.g, theme.accent.b, 0)\r
        end\r
        if self.sidebar.header then\r
            self.sidebar.header:SetTextColor(theme.soft.r, theme.soft.g, theme.soft.b, 1)\r
        end\r
        if self.sidebar.headerRule then\r
            ApplyTextureGradient(self.sidebar.headerRule, "HORIZONTAL",\r
                theme.accent.r, theme.accent.g, theme.accent.b, 0.18,\r
                theme.accent.r, theme.accent.g, theme.accent.b, 0)\r
        end\r
        if self.sidebar.controlsPanel then\r
            ApplySidebarPanelStyle(self.sidebar.controlsPanel, self.sidebar.controlsPanel._ktUnlockPanelVariant or "controls")\r
        end\r
        if self.sidebar.listPanel then\r
            ApplySidebarPanelStyle(self.sidebar.listPanel, self.sidebar.listPanel._ktUnlockPanelVariant or "list")\r
        end\r
        if self.sidebar.footerPanel then\r
            ApplySidebarPanelStyle(self.sidebar.footerPanel, self.sidebar.footerPanel._ktUnlockPanelVariant or "footer")\r
        end\r
        StyleSidebarButton(self.sidebar.discard, "footer_red")\r
        StyleSidebarButton(self.sidebar.save, "footer_green")\r
        StyleSidebarButton(self.sidebar.toggleGrid, "toggle")\r
        StyleSidebarButton(self.sidebar.toggleSnap, "toggle")\r
        StyleSidebarButton(self.sidebar.toggleDark, "toggle")\r
        StyleSidebarButton(self.sidebar.toggleCoords, "toggle")\r
        if self.sidebar.scrollbarTrack then\r
            KT:AddBorder(self.sidebar.scrollbarTrack, theme.soft.r, theme.soft.g, theme.soft.b, 1)\r
        end\r
        if self.sidebar.scrollbarThumbBorder or self.sidebar.scrollbarThumb then\r
            SetScrollbarThumbState(self.sidebar, self.sidebar.scrollbarDragging and "drag" or "normal")\r
        end\r
        if self.sidebar.itemButtons then\r
            for _, button in ipairs(self.sidebar.itemButtons) do\r
                if button._ktUnlockVariant then\r
                    StyleSidebarButton(button, button._ktUnlockVariant)\r
                elseif button._ktUnlockPanelButton then\r
                    RefreshPanelButtonTheme(button)\r
                end\r
            end\r
        end\r
    end\r
\r
    if self.guideVertical then\r
        self.guideVertical:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)\r
    end\r
    if self.guideHorizontal then\r
        self.guideHorizontal:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)\r
    end\r
\r
    for _, mover in pairs(self.movers) do\r
        if not mover.isSelected then\r
            KT:AddBorder(mover, theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
        end\r
        if mover.cog and mover.cog.icon then\r
            mover.cog.icon:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
        end\r
        if mover.close then\r
            KT:AddBackdrop(mover.close, theme.background.r, theme.background.g, theme.background.b, 0.94)\r
            KT:AddBorder(mover.close, theme.soft.r, theme.soft.g, theme.soft.b, 1)\r
            if mover.close.text then\r
                mover.close.text:SetTextColor(theme.text.r, theme.text.g, theme.text.b, 1)\r
            end\r
            mover.close:SetScript("OnEnter", function(widget)\r
                KT:AddBorder(widget, theme.accent.r, theme.accent.g, theme.accent.b, 1)\r
            end)\r
            mover.close:SetScript("OnLeave", function(widget)\r
                KT:AddBorder(widget, theme.soft.r, theme.soft.g, theme.soft.b, 1)\r
            end)\r
        end\r
        if mover.RefreshStyle then\r
            mover:RefreshStyle()\r
        end\r
    end\r
\r
    if self.gridFrame and self.gridFrame:IsShown() then\r
        self:RebuildGrid()\r
    end\r
\r
    self:RefreshSidebarSelection()\r
end\r
\r
function UM:CreateUnlockFrame()
    if self.unlockFrame then return end\r
\r
    local frame = CreateFrame("Frame", "KullThranUIUnlockMode", UIParent)\r
    frame:SetAllPoints(UIParent)\r
    frame:SetFrameStrata("FULLSCREEN_DIALOG")\r
    frame:EnableMouse(false)\r
    frame:EnableKeyboard(true)\r
\r
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
    logoGlow:SetBlendMode("ADD")
    if logoGlow.SetDesaturated then
        logoGlow:SetDesaturated(true)
    end
    logoSplash.glow = logoGlow

    local logo = logoSplash:CreateTexture(nil, "OVERLAY", nil, 2)
    logo:SetSize(154, 154)
    logo:SetPoint("CENTER")
    logo:SetTexture(UNLOCK_LOGO_TEXTURE)
    if logo.SetDesaturated then
        logo:SetDesaturated(true)
    end
    logoSplash.logo = logo

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

    local hold = logoAnimation:CreateAnimation("Alpha")
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)
    hold:SetDuration(0.20)
    hold:SetOrder(2)

    local fadeOut = logoAnimation:CreateAnimation("Alpha")
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(0.28)
    fadeOut:SetOrder(3)

    local scaleOut = logoAnimation:CreateAnimation("Scale")
    scaleOut:SetScaleFrom(1, 1)
    scaleOut:SetScaleTo(1.12, 1.12)
    scaleOut:SetDuration(0.28)
    scaleOut:SetOrder(3)
    scaleOut:SetSmoothing("OUT")

    logoAnimation:SetScript("OnFinished", function()
        logoSplash:Hide()
    end)
    logoAnimation:SetScript("OnStop", function()
        logoSplash:Hide()
    end)
    logoSplash.animation = logoAnimation
    self.openLogoSplash = logoSplash
\r
    local theme = GetUnlockTheme()\r
    self.guideVertical = frame:CreateTexture(nil, "OVERLAY")\r
    self.guideVertical:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)\r
    self.guideVertical:SetWidth(1)\r
    self.guideVertical:Hide()\r
\r
    self.guideHorizontal = frame:CreateTexture(nil, "OVERLAY")\r
    self.guideHorizontal:SetColorTexture(theme.accent.r, theme.accent.g, theme.accent.b, 0.95)\r
    self.guideHorizontal:SetHeight(1)\r
    self.guideHorizontal:Hide()\r
\r
    frame:SetScript("OnKeyDown", function(_, key)\r
        if key == "ESCAPE" then\r
            if self.hasChanges then\r
                self:PromptCloseUnlockMode()\r
            else\r
                self:CloseUnlockMode(false, true)\r
            end\r
            return\r
        end\r
\r
        if not self.selectedKey then return end\r
        local delta = IsShiftKeyDown() and 10 or 1\r
        if key == "LEFT" then\r
            self:NudgeSelected(-delta, 0)\r
        elseif key == "RIGHT" then\r
            self:NudgeSelected(delta, 0)\r
        elseif key == "UP" then\r
            self:NudgeSelected(0, delta)\r
        elseif key == "DOWN" then\r
            self:NudgeSelected(0, -delta)\r
        end\r
    end)\r
\r
    frame:Hide()\r
    self.unlockFrame = frame\r
    self:CreateGrid()\r
    self:CreateSidebar()
end

function UM:PlayOpenLogoAnimation()
    local splash = self.openLogoSplash
    if not (splash and splash.animation) then return end

    local theme = GetUnlockTheme()
    splash.logo:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 1)
    splash.glow:SetVertexColor(theme.accent.r, theme.accent.g, theme.accent.b, 0.48)

    if splash.animation:IsPlaying() then
        splash.animation:Stop()
    end
    splash:SetAlpha(1)
    splash:SetScale(1)
    splash:Show()
    splash.animation:Play()
end
\r
function UM:NudgeSelected(deltaX, deltaY)\r
    local moved = false\r
    for _, key in ipairs(self:GetSelectedMoverKeys()) do\r
        local mover = self.movers[key]\r
        if mover then\r
            local left = (mover:GetLeft() or 0) + deltaX\r
            local top = (mover:GetTop() or 0) + deltaY\r
            SetFrameTopLeft(mover, left, top)\r
            self:ApplyMoverToElement(key, mover)\r
            mover:RefreshCoords()\r
            moved = true\r
        end\r
    end\r
    if moved then\r
        self:RefreshSidebarSelection()\r
    end\r
end\r
\r
function UM:AnimateSidebarIn()\r
    if not self.sidebar then return end\r
    self.sidebar:ClearAllPoints()\r
    self.sidebar:SetPoint("LEFT", UIParent, "LEFT", -SIDEBAR_WIDTH, 0)\r
    local startTime = GetTime()\r
    local duration = 0.25\r
    self.sidebar:SetScript("OnUpdate", function(sidebar)\r
        local t = min((GetTime() - startTime) / duration, 1)\r
        local eased = EaseOutQuad(t)\r
        sidebar:ClearAllPoints()\r
        sidebar:SetPoint("LEFT", UIParent, "LEFT", Round((-SIDEBAR_WIDTH) + (SIDEBAR_WIDTH * eased)), 0)\r
        if t >= 1 then\r
            sidebar:SetScript("OnUpdate", nil)\r
            sidebar:ClearAllPoints()\r
            sidebar:SetPoint("LEFT", UIParent, "LEFT", 0, 0)\r
        end\r
    end)\r
end\r
\r
function UM:FadeInOpenUI()\r
    if UIFrameFadeIn then\r
        UIFrameFadeIn(self.unlockFrame, 0.30, 0, 1)\r
        UIFrameFadeIn(self.sidebar, 0.25, 0, 1)\r
        for _, mover in pairs(self.movers) do\r
            UIFrameFadeIn(mover, 0.40, 0, 1)\r
        end\r
    else\r
        self.unlockFrame:SetAlpha(1)\r
        self.sidebar:SetAlpha(1)\r
        for _, mover in pairs(self.movers) do\r
            mover:SetAlpha(1)\r
        end\r
    end\r
    self:AnimateSidebarIn()\r
end\r
\r
function UM:OpenUnlockMode()
    if self.isOpen or InCombatLockdown() or (KT.IsBlizzardEditModeTransitionActive and KT:IsBlizzardEditModeTransitionActive()) then\r
        if InCombatLockdown() then\r
            KT:Print("UnlockMode is unavailable in combat.")\r
        end\r
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
    self:CreateUnlockFrame()\r
    self:UpdateRegistry()\r
    wipe(self.snapshotPositions)\r
    wipe(self.snapshotSizes)\r
    wipe(self.snapshotSnapTargets)\r
    wipe(self.pendingPositions)\r
    self.hasChanges = false\r
\r
    KT._unlockActive = true\r
    self.isOpen = true\r
\r
    for _, key in ipairs(self.registryOrder) do\r
        if not self:IsElementHidden(key) then\r
            self.snapshotPositions[key] = self:CaptureCurrentPosition(key)\r
            self.snapshotSnapTargets[key] = self:GetSnapTarget(key) or false\r
            if self:CanEditElementSize(key) then\r
                local width, height = self:GetEditableElementSize(key)\r
                if width and height then\r
                    self.snapshotSizes[key] = {\r
                        width = width,\r
                        height = height,\r
                    }\r
                end\r
            end\r
        end\r
    end\r
\r
    self.unlockFrame:Show()\r
    self.unlockFrame:SetAlpha(0)\r
    self.sidebar:SetAlpha(0)\r
    self.sidebar:Show()\r
    self.sidebar:SetFrameStrata("FULLSCREEN_DIALOG")\r
    self.sidebar:SetFrameLevel((self.unlockFrame and self.unlockFrame:GetFrameLevel() or 0) + 50)\r
    if self.sidebar.Raise then\r
        self.sidebar:Raise()\r
    end\r
    self:RebuildGrid()\r
    self:RefreshMovers()\r
    self:RefreshSidebar()\r
    self:ApplyTheme()\r
    self:HideGuides()\r
\r
    C_Timer.After(0, function()\r
        if self.isOpen then
            self:RefreshMovers()
            self:FadeInOpenUI()
            self:PlayOpenLogoAnimation()
        end
    end)\r
end\r
\r
function UM:CloseUnlockMode(saveChanges, force)\r
    if not self.isOpen then return end\r
\r
    if saveChanges then\r
        self:CommitPositions()\r
    elseif not force and self.hasChanges then\r
        self:PromptCloseUnlockMode()\r
        return\r
    else\r
        self:RevertPositions()\r
    end\r
\r
    self.isOpen = false\r
    self.isSuspended = false\r
    KT._unlockActive = false\r
    self.selectedKey = nil\r
    wipe(self.selectedKeys)\r
    self:HideGuides()\r
\r
    for _, mover in pairs(self.movers) do\r
        mover:SetScript("OnUpdate", nil)\r
        mover.isDragging = false\r
        mover:Hide()\r
    end\r
\r
    if UIFrameFadeOut then\r
        UIFrameFadeOut(self.unlockFrame, 0.25, self.unlockFrame:GetAlpha(), 0)\r
        UIFrameFadeOut(self.sidebar, 0.25, self.sidebar:GetAlpha(), 0)\r
    end\r
\r
    C_Timer.After(0.26, function()\r
        if not self.isOpen and self.unlockFrame then\r
            self.unlockFrame:Hide()\r
            self.sidebar:Hide()\r
            self.unlockFrame:SetAlpha(1)\r
            self.sidebar:SetAlpha(1)\r
        end\r
    end)\r
end\r
\r
function UM:ToggleUnlockMode()\r
    if self.isOpen then\r
        self:CloseUnlockMode(false)\r
    else\r
        self:OpenUnlockMode()\r
    end\r
end\r
\r
function UM:OnBlizzardEnterEditMode()\r
    -- Decoupled from Blizzard Edit Mode: do not auto-open KUI Unlock Mode.\r
    -- If both overlap, close KUI Unlock Mode to prevent confusing UI states.\r
    if self.isOpen then\r
        self:CloseUnlockMode(false, true)\r
    end\r
end\r
\r
function UM:OnBlizzardExitEditMode()\r
    -- No-op (kept for backwards compatibility if some external hook calls it).\r
end\r
\r
function UM:OnCombatStart()\r
    if not self.isOpen then return end\r
    self.isSuspended = true\r
    KT._unlockActive = false\r
    self.unlockFrame:Hide()\r
    self.sidebar:Hide()\r
    for _, mover in pairs(self.movers) do\r
        mover:SetScript("OnUpdate", nil)\r
        mover.isDragging = false\r
        mover:Hide()\r
    end\r
    self:HideGuides()\r
end\r
\r
function UM:OnCombatEnd()\r
    if not self.isSuspended then return end\r
    C_Timer.After(0.5, function()\r
        if not self.isOpen or InCombatLockdown() then return end\r
        self.isSuspended = false\r
        KT._unlockActive = true\r
        self.unlockFrame:Show()\r
        self.sidebar:Show()\r
        self:RebuildGrid()\r
        self:RefreshMovers()\r
        self:RefreshSidebar()\r
    end)\r
end\r

