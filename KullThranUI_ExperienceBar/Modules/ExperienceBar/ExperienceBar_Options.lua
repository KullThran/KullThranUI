-- Modules/ExperienceBar/ExperienceBar_Options.lua
-- Registers the "Experience Bar" page in KullThranUI's custom Options menu.
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local LSM = LibStub("LibSharedMedia-3.0", true)

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local GetFontValues = Opt.GetFontValues
local GetStatusbarValues = Opt.GetStatusbarValues

local function RefreshExperienceBar()
    local M = KT:GetModule("ExperienceBar", true)
    if M and M.Refresh then
        M:Refresh()
    end
end

KT:RegisterPage("expbar", LText("Experience Bar"), 65, function(sc, W)
    local y, h = 0, 0
    local db = KT.db and KT.db.profile and KT.db.profile.experienceBar
    if not db then
        KT.db.profile.experienceBar = KT.db.profile.experienceBar or {}
        db = KT.db.profile.experienceBar
    end

    -- Live Preview (as in the last functional version): fake XP bar reflecting DB values.
    local prevContainer = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    prevContainer:SetSize((sc:GetWidth() or 1) - 20, 96)
    prevContainer:SetPoint("TOP", sc, "TOP", 0, -10)
    if KT.AddBackdrop then KT:AddBackdrop(prevContainer, 0.1, 0.1, 0.1, 0.4) end
    if KT.AddBorder then KT:AddBorder(prevContainer, 0, 0, 0, 1) end
    if KT.AttachStickyPreview then
        KT:AttachStickyPreview(prevContainer, { point = "TOP", relativePoint = "TOP", x = 0, y = -10 })
    end

    local lblPrev = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPrev:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 10, -8)
    lblPrev:SetText(LText("LIVE PREVIEW (XP BAR)"))
    KT:SetAccentTextColor(lblPrev, 1)

    local fakeBar = CreateFrame("StatusBar", nil, prevContainer, "BackdropTemplate")
    fakeBar:SetPoint("CENTER", 0, -4)
    fakeBar:SetMinMaxValues(0, 100)
    fakeBar:SetValue(65)
    if KT.AddBorder then KT:AddBorder(fakeBar, 0, 0, 0, 1) end

    local fakeText = fakeBar:CreateFontString(nil, "OVERLAY")
    fakeText:SetPoint("CENTER")

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

    local function UpdatePreview()
        local w = tonumber(db.width) or 300
        local hgt = tonumber(db.height) or 10
        fakeBar:SetSize(w, hgt)

        local tex = FetchStatusbarTex(db.texture or "Melli")
        fakeBar:SetStatusBarTexture(tex)

        local c = db.xpColor or { r = 0, g = 0.4, b = 0.9, a = 1 }
        fakeBar:SetStatusBarColor(c.r or 0, c.g or 0.4, c.b or 0.9, c.a or 1)

        local font = FetchFont(db.font or "AAA_ITC_Avant_Garde")
        fakeText:SetFont(font, db.fontSize or 12, db.fontOutline or "OUTLINE")
        local level = UnitLevel and UnitLevel("player") or 70
        fakeText:SetText(string.format("%s %d | %s", _G.LEVEL or "Level", level, LText("XP: 65% / Rep: 3000/6000")))
        if db.showText ~= false then
            fakeText:Show()
        else
            fakeText:Hide()
        end
    end

    local function RefreshAndPreview()
        RefreshExperienceBar()
        UpdatePreview()
    end

    UpdatePreview()
    y = y + 116

    _, h = W:SectionHeader(sc, "General", -y); y = y + h
    _, h = W:Toggle(sc, "Enable Module", -y,
        function() return db.enable == true end,
        function(v) db.enable = v; Reload() end); y = y + h
    _, h = W:Toggle(sc, "Visible", -y,
        function() return db.visible ~= false end,
        function(v) db.visible = v; RefreshExperienceBar() end); y = y + h
    _, h = W:Toggle(sc, "Disable At Max Level", -y,
        function() return db.disableAtMaxLevel ~= false end,
        function(v) db.disableAtMaxLevel = v; RefreshExperienceBar() end); y = y + h
    _, h = W:Toggle(sc, "Auto Track Watched Reputation", -y,
        function() return db.autoTrackReputation == true end,
        function(v) db.autoTrackReputation = v; RefreshExperienceBar() end); y = y + h

    _, h = W:Dropdown(sc, "Mode", -y,
        { ["AUTO"] = "Auto", ["XP"] = "XP", ["REP"] = "Reputation", ["HONOR"] = "Honor" },
        function() return db.mode or "AUTO" end,
        function(v) db.mode = v; RefreshExperienceBar() end); y = y + h

    _, h = W:SectionHeader(sc, "Layout", -y); y = y + h
    _, h = W:Slider(sc, "Width", -y,
        function() return db.width or 300 end,
        function(v) db.width = v; RefreshAndPreview() end, 150, 1000, 1); y = y + h
    _, h = W:Slider(sc, "Height", -y,
        function() return db.height or 10 end,
        function(v) db.height = v; RefreshAndPreview() end, 6, 40, 1); y = y + h
    _, h = W:Slider(sc, "X Offset", -y,
        function() return db.x or 0 end,
        function(v) db.x = v; RefreshExperienceBar() end, -1000, 1000, 1); y = y + h
    _, h = W:Slider(sc, "Y Offset", -y,
        function() return db.y or 0 end,
        function(v) db.y = v; RefreshExperienceBar() end, -1000, 1000, 1); y = y + h

    _, h = W:SectionHeader(sc, "Style", -y); y = y + h
    _, h = W:Dropdown(sc, "Texture", -y, GetStatusbarValues,
        function() return db.texture or "Melli" end,
        function(v) db.texture = v; RefreshAndPreview() end); y = y + h

    _, h = W:Dropdown(sc, "Font", -y, GetFontValues,
        function() return db.font or "AAA_ITC_Avant_Garde" end,
        function(v) db.font = v; RefreshAndPreview() end); y = y + h
    _, h = W:Slider(sc, "Font Size", -y,
        function() return db.fontSize or 12 end,
        function(v) db.fontSize = v; RefreshAndPreview() end, 8, 24, 1); y = y + h
    _, h = W:Dropdown(sc, "Outline", -y,
        { ["NONE"] = "None", ["OUTLINE"] = "Thin", ["THICKOUTLINE"] = "Thick" },
        function() return db.fontOutline or "OUTLINE" end,
        function(v) db.fontOutline = v; RefreshAndPreview() end); y = y + h

    _, h = W:SectionHeader(sc, "Colors", -y); y = y + h
    _, h = W:ColorSwatch(sc, "XP Color", -y,
        function()
            local c = db.xpColor or { r = 0, g = 0.4, b = 0.9, a = 1 }
            return c.r, c.g, c.b, c.a
        end,
        function(r, g, b, a) db.xpColor = { r = r, g = g, b = b, a = a }; RefreshAndPreview() end, true); y = y + h
    _, h = W:ColorSwatch(sc, "Rested Color", -y,
        function()
            local c = db.restedColor or { r = 1, g = 0, b = 1, a = 1 }
            return c.r, c.g, c.b, c.a
        end,
        function(r, g, b, a) db.restedColor = { r = r, g = g, b = b, a = a }; RefreshExperienceBar() end, true); y = y + h
    _, h = W:ColorSwatch(sc, "Reputation Color", -y,
        function()
            local c = db.repColor or { r = 0, g = 0.8, b = 0, a = 1 }
            return c.r, c.g, c.b, c.a
        end,
        function(r, g, b, a) db.repColor = { r = r, g = g, b = b, a = a }; RefreshExperienceBar() end, true); y = y + h

    _, h = W:SectionHeader(sc, "Text", -y); y = y + h
    _, h = W:Toggle(sc, "Show Text", -y,
        function() return db.showText ~= false end,
        function(v) db.showText = v; RefreshAndPreview() end); y = y + h
    _, h = W:Toggle(sc, "Show Session Data", -y,
        function() return db.showSessionData == true end,
        function(v) db.showSessionData = v; RefreshExperienceBar() end); y = y + h

    return y
end)
