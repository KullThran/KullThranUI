-- Modules/CastBar/CastBar_Options.lua
-- Registers the "Cast Bar" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local LSM = LibStub("LibSharedMedia-3.0", true)
local Styles = KT.CastBarStyles

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local GetFontValues = Opt.GetFontValues
local GetStatusbarValues = Opt.GetStatusbarValues
local BeginOptionBlocks = Opt.BeginOptionBlocks
local AddOptionBlock = Opt.AddOptionBlock
local EndOptionBlocks = Opt.EndOptionBlocks
local UnitClass = UnitClass
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local C_ClassColor = C_ClassColor

local function RefreshCastBar()
    local M = KT:GetModule("CastBar", true)
    if M and M.Refresh then
        M:Refresh()
    end
end

local function PreviewAccentColor()
    if KT and KT.GetStyleAccentRGB then
        return KT:GetStyleAccentRGB()
    end
    return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333
end

local function RestoreCastBarDefaults()
    if not (KT and KT.db and KT.db.profile) then
        return
    end

    KT.db.profile.castbar = nil
    RefreshCastBar()

    if KT.RefreshPage then
        KT:RefreshPage()
    end
end

local function GetPreviewBarColor(db)
    if Styles:GetStyle(db) ~= "kui" then return Styles:Color(db) end
    local profile = KT and KT.db and KT.db.profile
    local skin = profile and profile.skin
    local globalClassColor = skin and (skin.kullthranUIColorByClass == true or skin.borderTheme == "CLASS")

    if db and (db.classColor or globalClassColor) then
        local _, classTag = UnitClass("player")
        local classColor = classTag and C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(classTag)
        if not classColor then
            classColor = classTag and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag]
        end
        if classColor then
            local alpha = 1
            if db.color and db.color.a ~= nil then
                alpha = db.color.a
            end
            return classColor.r or 1, classColor.g or 1, classColor.b or 1, alpha
        end
    end

    if not db or db.colorMode ~= "CUSTOM" then
        local r, g, b = PreviewAccentColor()
        local alpha = db and db.color and db.color.a or 1
        return r, g, b, alpha
    end

    local c = (db and db.color) or { r = 1, g = 0, b = 0.3333, a = 1 }
    return c.r or 1, c.g or 0, c.b or 0.3333, c.a or 1
end

KT:RegisterPage("castbar", "Cast Bar", 12, function(sc, W)
    local y, h = 0, 0
    local db = KT.db and KT.db.profile and KT.db.profile.castbar
    if not db then
        KT.db.profile.castbar = KT.db.profile.castbar or {}
        db = KT.db.profile.castbar
    end

    -- Live Preview (as in the last functional version): fake cast bar reflecting DB values.
    local function FetchFont(fontKey)
        if KT and KT.ResolveFontForLocale then
            return KT:ResolveFontForLocale(fontKey, "Fonts\\FRIZQT__.TTF")
        end
        if LSM and fontKey then
            local fetched = LSM:Fetch("font", fontKey)
            if fetched then return fetched end
        end
        return "Fonts\\FRIZQT__.TTF"
    end

    local function FetchStatusbarTex(texKey)
        if LSM and texKey then
            local fetched = LSM:Fetch("statusbar", texKey)
            if fetched then return fetched end
        end
        return "Interface\\Buttons\\WHITE8x8"
    end

    local prevContainer = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    prevContainer:SetSize((sc:GetWidth() or 1) - 20, 160)
    prevContainer:SetPoint("TOP", sc, "TOP", 0, -10)
    if KT.AddBackdrop then KT:AddBackdrop(prevContainer, 0.1, 0.1, 0.1, 0.4) end
    if KT.AddBorder then KT:AddBorder(prevContainer, 0, 0, 0, 1) end
    if KT.AttachStickyPreview then
        KT:AttachStickyPreview(prevContainer, { point = "TOP", relativePoint = "TOP", x = 0, y = -10 })
    end

    local lblPrev = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPrev:SetPoint("BOTTOMLEFT", prevContainer, "TOPLEFT", 0, 4)
    lblPrev:SetText(LText("LIVE PREVIEW"))
    KT:SetAccentTextColor(lblPrev, 1)

    local fakeBar = CreateFrame("StatusBar", nil, prevContainer, "BackdropTemplate")
    fakeBar:SetPoint("CENTER")
    fakeBar:SetMinMaxValues(0, 1)
    fakeBar:SetValue(0.65)

    local fakeBg = fakeBar:CreateTexture(nil, "BACKGROUND")
    fakeBg:SetAllPoints()
    fakeBg:SetColorTexture(0, 0, 0, 0.5)

    local fakeSpark = fakeBar:CreateTexture(nil, "OVERLAY")
    fakeSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    fakeSpark:SetBlendMode("ADD")
    fakeSpark:SetWidth(20)

    local fakeText = fakeBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fakeText:SetPoint("LEFT", 5, 0)
    fakeText:SetText(LText("Polymorph"))
    fakeText:SetShadowOffset(1, -1)

    local fakeTime = fakeBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fakeTime:SetPoint("RIGHT", -5, 0)
    fakeTime:SetText("1.5")
    fakeTime:SetShadowOffset(1, -1)

    local fakeIconBg = CreateFrame("Frame", nil, fakeBar, "BackdropTemplate")
    fakeIconBg:SetFrameLevel(fakeBar:GetFrameLevel() + 2)
    if KT.AddBackdrop then KT:AddBackdrop(fakeIconBg, 0.05, 0.05, 0.05, 0.9) end
    if KT.AddBorder then KT:AddBorder(fakeIconBg, 0, 0, 0, 1) end

    local fakeIcon = fakeBar:CreateTexture(nil, "ARTWORK")
    fakeIcon:SetTexture(136071)
    fakeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    fakeBar.Text, fakeBar.Time, fakeBar.Spark = fakeText, fakeTime, fakeSpark
    fakeBar.Icon, fakeBar.IconBg, fakeBar.PreviewBackground = fakeIcon, fakeIconBg, fakeBg
    local iconMask = nil

    -- Browse a preset without changing the live cast bar; Apply commits it.
    local selectedStyle = KT._castbarStyleTab or Styles:GetStyle(db)
    if not Styles.labels[selectedStyle] then selectedStyle = "kui" end
    local previewDB, UpdatePreview
    local tabs = {}
    local tabsHost = CreateFrame("Frame", nil, prevContainer)
    tabsHost:SetSize(4 * 116, 28)
    tabsHost:SetPoint("TOP", prevContainer, "TOP", 0, -8)
    for i, key in ipairs(Styles.order) do
        local button = CreateFrame("Button", nil, tabsHost, "BackdropTemplate")
        button:SetSize(110, 26)
        button:SetPoint("TOPLEFT", tabsHost, "TOPLEFT", (i - 1) * 116, 0)
        if KT.AddBackdrop then KT:AddBackdrop(button, 0.06, 0.06, 0.06, 0.9) end
        local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("CENTER", button, "CENTER", 8, 0); text:SetText(LText(Styles.labels[key]))
        text:SetFont(FetchFont("AAA_ITC_Avant_Garde"), 11, "OUTLINE")
        local icon = button:CreateTexture(nil, "OVERLAY")
        icon:SetSize(key == "kui" and 22 or 16, key == "kui" and 22 or 16); icon:SetPoint("LEFT", button, "LEFT", key == "kui" and 4 or 7, 0)
        Styles:ApplyStyleIcon(icon, key)
        button.styleIcon = icon
        button.label, button.key = text, key
        button:SetScript("OnClick", function()
            selectedStyle = key
            KT._castbarStyleTab = key
            UpdatePreview()
        end)
        tabs[#tabs + 1] = button
    end
    local function ApplyStyleButtonSkin(btn)
        local visual = CreateFrame("Frame", nil, btn)
        visual:SetAllPoints()
        visual:SetFrameLevel(btn:GetFrameLevel() - 1)
        visual:SetClipsChildren(false)

        local tex = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\MenuButton.png"
        local minX = 12 / 601
        local maxX = 586 / 601
        local minY = 8 / 147
        local maxY = 136 / 147
        local cx = 8 / 601
        local cy = 8 / 147
        local cornerScreen = 4

        local slices = {}
        for i = 1, 9 do
            local t = visual:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(tex)
            slices[i] = t
        end
        local TL, TR, BL, BR, T, B, L, R, C = unpack(slices)

        TL:SetSize(cornerScreen, cornerScreen)
        TR:SetSize(cornerScreen, cornerScreen)
        BL:SetSize(cornerScreen, cornerScreen)
        BR:SetSize(cornerScreen, cornerScreen)

        TL:SetPoint("TOPLEFT")
        TR:SetPoint("TOPRIGHT")
        BL:SetPoint("BOTTOMLEFT")
        BR:SetPoint("BOTTOMRIGHT")

        T:SetPoint("TOPLEFT", TL, "TOPRIGHT")
        T:SetPoint("BOTTOMRIGHT", TR, "BOTTOMLEFT")
        B:SetPoint("TOPLEFT", BL, "TOPRIGHT")
        B:SetPoint("BOTTOMRIGHT", BR, "BOTTOMLEFT")
        L:SetPoint("TOPLEFT", TL, "BOTTOMLEFT")
        L:SetPoint("BOTTOMRIGHT", BL, "TOPRIGHT")
        R:SetPoint("TOPLEFT", TR, "BOTTOMLEFT")
        R:SetPoint("BOTTOMRIGHT", BR, "TOPRIGHT")
        C:SetPoint("TOPLEFT", TL, "BOTTOMRIGHT")
        C:SetPoint("BOTTOMRIGHT", BR, "TOPLEFT")

        TL:SetTexCoord(minX, minX + cx, minY, minY + cy)
        TR:SetTexCoord(maxX - cx, maxX, minY, minY + cy)
        BL:SetTexCoord(minX, minX + cx, maxY - cy, maxY)
        BR:SetTexCoord(maxX - cx, maxX, maxY - cy, maxY)
        T:SetTexCoord(minX + cx, maxX - cx, minY, minY + cy)
        B:SetTexCoord(minX + cx, maxX - cx, maxY - cy, maxY)
        L:SetTexCoord(minX, minX + cx, minY + cy, maxY - cy)
        R:SetTexCoord(maxX - cx, maxX, minY + cy, maxY - cy)
        C:SetTexCoord(minX + cx, maxX - cx, minY + cy, maxY - cy)

        btn.slices = slices
    end

    local apply = CreateFrame("Button", nil, prevContainer)
    ApplyStyleButtonSkin(apply)
    local applyLabel = apply:CreateFontString(nil, "OVERLAY")
    applyLabel:SetAllPoints()
    applyLabel:SetJustifyH("CENTER")
    applyLabel:SetJustifyV("MIDDLE")
    apply:SetFontString(applyLabel)
    local function PaintApplyButton(hover)
        local enabled = apply:IsEnabled()
        local r, g, b = PreviewAccentColor()
        for _, slice in ipairs(apply.slices) do
            slice:SetVertexColor(r, g, b, enabled and (hover and 1 or 0.5) or 0.25)
        end
        applyLabel:SetTextColor(enabled and 1 or 0.55, enabled and 1 or 0.55, enabled and 1 or 0.55, 1)
    end
    apply:SetScript("OnEnter", function() PaintApplyButton(true) end)
    apply:SetScript("OnLeave", function() PaintApplyButton(false) end)

    apply:SetSize(150, 24)
    apply:SetPoint("BOTTOM", prevContainer, "BOTTOM", 0, 8)
    local dimensions = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dimensions:SetPoint("BOTTOM", apply, "TOP", 0, 5)
    dimensions:SetFont(FetchFont("AAA_ITC_Avant_Garde"), 10, "OUTLINE")
    local styleIcon = prevContainer:CreateTexture(nil, "OVERLAY")
    styleIcon:SetSize(20, 20)
    styleIcon:SetPoint("RIGHT", dimensions, "LEFT", -5, 0)
    fakeBar.StyleIcon = styleIcon
    apply:SetScript("OnClick", function()
        Styles:Select(db, selectedStyle)
        RefreshCastBar()
        UpdatePreview()
        if KT.RefreshPage then KT:RefreshPage() end
    end)

    local function GetPreviewDB()
        if selectedStyle == Styles:GetStyle(db) then return db end
        local sample = {}
        if selectedStyle == "kui" and db.kuiStyleSettings then
            for key, value in pairs(db.kuiStyleSettings) do sample[key] = value end
        else
            Styles:Seed(sample, selectedStyle)
        end
        return sample
    end

    UpdatePreview = function()
        previewDB = GetPreviewDB()
        local db = previewDB
        local barW = tonumber(db.width) or 250
        local barH = tonumber(db.height) or 20
        local barScale = tonumber(db.scale) or 1.0

        fakeBar:SetSize(barW, barH)
        fakeBar:SetScale(barScale)

        local tex = Styles:GetStyle(db) == "kui" and FetchStatusbarTex(db.texture or "Melli")
            or "Interface\\Buttons\\WHITE8x8"
        fakeBar:SetStatusBarTexture(tex)

        do
            local r, g, b, a = GetPreviewBarColor(db)
            fakeBar:SetStatusBarColor(r, g, b, a)
        end

        local font = FetchFont(db.font or "AAA_ITC_Avant_Garde")
        local outline = db.fontOutline or "OUTLINE"
        if outline == "NONE" then outline = "" end
        local sz = tonumber(db.fontSize) or 16
        local adjustedSize = math.min(sz, math.max(8, barW / 12))
        fakeText:SetFont(font, adjustedSize, outline)
        fakeTime:SetFont(font, adjustedSize, outline)

        local tc = db.textColor or { r = 1, g = 1, b = 1, a = 1 }
        fakeText:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, tc.a or 1)
        fakeTime:SetTextColor(tc.r or 1, tc.g or 1, tc.b or 1, tc.a or 1)

        local sparkX = math.max(0, math.min(1, 0.65)) * barW
        fakeSpark:ClearAllPoints()
        fakeSpark:SetPoint("CENTER", fakeBar, "LEFT", sparkX, 0)

        if Styles:ShowsIcon(db) then
            fakeIcon:Show()
            fakeIconBg:Show()
            fakeIconBg:ClearAllPoints()
            fakeIconBg:SetSize(barH, barH)

            if (db.iconPosition or "LEFT") == "RIGHT" then
                fakeIconBg:SetPoint("LEFT", fakeBar, "RIGHT", 2, 0)
            else
                fakeIconBg:SetPoint("RIGHT", fakeBar, "LEFT", -2, 0)
            end

            if (db.iconShape or "SQUARE") == "CIRCLE" then
                if not iconMask then
                    iconMask = fakeBar:CreateMaskTexture()
                    iconMask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
                    iconMask:SetAllPoints(fakeIcon)
                    fakeIcon:AddMaskTexture(iconMask)
                end
                iconMask:Show()
                if KT.AddBorder then KT:AddBorder(fakeIconBg, 0, 0, 0, 0) end
            else
                if iconMask then iconMask:Hide() end
                if KT.AddBorder then KT:AddBorder(fakeIconBg, 0, 0, 0, 1) end
            end
        else
            fakeIcon:Hide()
            fakeIconBg:Hide()
        end
        Styles:Apply(fakeBar, db)
        fakeSpark:SetPoint("CENTER", fakeBar, "LEFT", sparkX, selectedStyle == "classic" and 2 or 0)
        fakeTime:SetText(selectedStyle == "kui" and "1.5" or "1.5 / 3.0")
        Styles:ApplyStyleIcon(styleIcon, selectedStyle)
        dimensions:SetText(string.format("%s  |  %d x %d", LText(Styles.labels[selectedStyle]), barW, barH))
        local applied = selectedStyle == Styles:GetStyle(KT.db.profile.castbar)
        apply:SetText(LText(applied and "Applied" or "Apply Style"))
        apply:SetEnabled(not applied)
        local globalFont = KT.ResolveFontPath and KT:ResolveFontPath() or FetchFont("AAA_ITC_Avant_Garde")
        applyLabel:SetFont(globalFont, 11, "OUTLINE")
        dimensions:SetFont(globalFont, 10, "OUTLINE")
        PaintApplyButton(false)
        for _, button in ipairs(tabs) do
            button.label:SetFont(globalFont, 11, "OUTLINE")
            local on = button.key == selectedStyle
            local r, g, b = PreviewAccentColor()
            if KT.AddBorder then KT:AddBorder(button, on and r or 0, on and g or 0, on and b or 0, 1) end
            if on then KT:SetAccentTextColor(button.label, 1) else button.label:SetTextColor(0.75, 0.75, 0.75, 1) end
        end
    end

    local function RefreshAndPreview()
        selectedStyle = Styles:GetStyle(db)
        KT._castbarStyleTab = selectedStyle
        RefreshCastBar()
        UpdatePreview()
    end

    UpdatePreview()
    y = y + 198

    _, h = W:Label(sc, LText("This module auto-anchors above the top cooldown/resource stack. With Auto Width enabled, the width slider becomes a fallback value instead of the live width."), -y, 11)
    y = y + h

    local cols = BeginOptionBlocks and BeginOptionBlocks(sc, y, { gap = 14, columnGap = 16 }) or nil
    if not (cols and AddOptionBlock and EndOptionBlocks) then
        return y
    end

    AddOptionBlock(cols, "left", "Overview", function(container)
        local by = 0

        _, h = W:Label(container, "Control the module state here and restore the original cast bar profile if you want to start clean.", -by, 11); by = by + h
        _, h = W:Toggle(container, "Enable Module", -by,
            function() return db.enable ~= false end,
            function(v)
                db.enable = v
                local module = KT:GetModule("CastBar", true)
                if module then
                    if v then
                        module:OnEnable()
                    else
                        module:OnDisable()
                    end
                end
                Reload()
            end); by = by + h
        _, h = W:Button(container, LText("Restore Cast Bar Defaults"), -by, function()
            RestoreCastBarDefaults()
        end); by = by + h

        return by
    end)

    AddOptionBlock(cols, "right", "Behavior", function(container)
        local by = 0

        _, h = W:Label(container, "These options control how the cast bar anchors itself relative to the top cooldown or resource stack.", -by, 11); by = by + h
        _, h = W:Toggle(container, "Auto Position (SnapToTop)", -by,
            function() return db.autoPosition ~= false end,
            function(v) db.autoPosition = v; RefreshCastBar() end); by = by + h
        _, h = W:Toggle(container, "Auto Width", -by,
            function() return db.autoWidth ~= false end,
            function(v) db.autoWidth = v; RefreshCastBar() end); by = by + h
        if db.autoWidth ~= false then
            do
                local r, g, b = PreviewAccentColor()
                _, h = W:Label(container, "Auto Width is active, so the Width slider acts as a fallback value instead of the live bar width.", -by, 10, { r = r, g = g, b = b })
            end
            by = by + h
        end

        return by
    end)

    AddOptionBlock(cols, "left", "Size & Placement", function(container)
        local by = 0

        _, h = W:Label(container, "Tune the overall footprint of the cast bar. These values are reflected immediately in the live preview.", -by, 11); by = by + h
        _, h = W:Slider(container, "Width", -by,
            function() return db.width or 250 end,
            function(v) db.width = v; RefreshAndPreview() end, 120, 800, 1); by = by + h
        _, h = W:Slider(container, "Height", -by,
            function() return db.height or 25 end,
            function(v) db.height = v; RefreshAndPreview() end, 8, 80, 1); by = by + h
        _, h = W:Slider(container, "Scale", -by,
            function() return db.scale or 1.0 end,
            function(v) db.scale = v; RefreshAndPreview() end, 0.5, 2.0, 0.01); by = by + h

        return by
    end)

    AddOptionBlock(cols, "right", "Bar Appearance", function(container)
        local by = 0
        if Styles:GetStyle(db) ~= "kui" then
            _, h = W:Label(container, "This style uses Blizzard casting textures and colors. Choose KUI Style to customize the bar fill.", -by, 11)
            return by + h
        end

        _, h = W:Label(container, "Choose the texture and base colors for the cast bar body. Class Color overrides the live fill while preserving your saved manual color.", -by, 11); by = by + h
        _, h = W:Dropdown(container, "Texture", -by, GetStatusbarValues,
            function() return db.texture or "Melli" end,
            function(v) db.texture = v; RefreshAndPreview() end); by = by + h
        _, h = W:Toggle(container, "Color by Class", -by,
            function() return db.classColor == true end,
            function(v) db.classColor = v; RefreshAndPreview() end); by = by + h
        if db.classColor == true then
            do
                local r, g, b = PreviewAccentColor()
                _, h = W:Label(container, "Bar Color remains as your fallback color, but the visible bar now uses your player's class color.", -by, 10, { r = r, g = g, b = b })
            end
            by = by + h
        end
        _, h = W:ColorSwatch(container, "Bar Color", -by,
            function()
                local c = db.color or { r = 1, g = 0, b = 0.3333, a = 1 }
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a)
                db.color = { r = r, g = g, b = b, a = a }
                db.colorMode = "CUSTOM"
                RefreshAndPreview()
            end, true); by = by + h
        _, h = W:ColorSwatch(container, "Text Color", -by,
            function()
                local c = db.textColor or { r = 1, g = 1, b = 1, a = 1 }
                return c.r, c.g, c.b, c.a
            end,
            function(r, g, b, a) db.textColor = { r = r, g = g, b = b, a = a }; RefreshAndPreview() end, true); by = by + h

        return by
    end)

    AddOptionBlock(cols, "left", "Typography", function(container)
        local by = 0

        _, h = W:Label(container, "Text styling applies to both the spell name and the cast time shown inside the bar.", -by, 11); by = by + h
        _, h = W:Dropdown(container, "Font", -by, GetFontValues,
            function() return db.font or "AAA_ITC_Avant_Garde" end,
            function(v) db.font = v; RefreshAndPreview() end); by = by + h
        _, h = W:Slider(container, "Font Size", -by,
            function() return db.fontSize or 16 end,
            function(v) db.fontSize = v; RefreshAndPreview() end, 8, 32, 1); by = by + h
        _, h = W:Dropdown(container, "Outline", -by,
            { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
            function() return db.fontOutline or "OUTLINE" end,
            function(v) db.fontOutline = v; RefreshAndPreview() end); by = by + h

        return by
    end)

    AddOptionBlock(cols, "right", "Icon", function(container)
        local by = 0
        if Styles:GetStyle(db) == "classic" then
            _, h = W:Label(container, "Classic cast bars do not use a spell icon.", -by, 11)
            return by + h
        end

        _, h = W:Label(container, "Configure the spell icon independently so it can match either a compact or more decorative cast bar layout.", -by, 11); by = by + h
        _, h = W:Toggle(container, "Show Icon", -by,
            function() return db.showIcon ~= false end,
            function(v) db.showIcon = v; RefreshAndPreview() end); by = by + h
        _, h = W:Dropdown(container, "Icon Position", -by,
            { ["LEFT"] = "Left", ["RIGHT"] = "Right" },
            function() return db.iconPosition or "LEFT" end,
            function(v) db.iconPosition = v; RefreshAndPreview() end); by = by + h
        _, h = W:Dropdown(container, "Icon Shape", -by,
            { ["SQUARE"] = "Square", ["CIRCLE"] = "Circle" },
            function() return db.iconShape or "SQUARE" end,
            function(v) db.iconShape = v; RefreshAndPreview() end); by = by + h

        return by
    end)

    return EndOptionBlocks(cols)
end)
