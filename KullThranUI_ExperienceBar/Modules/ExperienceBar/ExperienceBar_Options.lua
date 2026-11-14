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
local Styles = KT.ExperienceBarStyles

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
    -- Tall enough for the text above or below the bar (Text Position).
    prevContainer:SetSize((sc:GetWidth() or 1) - 20, 112)
    prevContainer:SetPoint("TOP", sc, "TOP", 0, -10)
    if KT.AddBackdrop then KT:AddBackdrop(prevContainer, 0.1, 0.1, 0.1, 0.4) end
    if KT.AddBorder then KT:AddBorder(prevContainer, 0, 0, 0, 1) end
    if KT.AttachStickyPreview then
        KT:AttachStickyPreview(prevContainer, { point = "TOP", relativePoint = "TOP", x = 0, y = -10 })
    end

    local lblPrev = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPrev:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 10, -8)
    lblPrev:SetText(LText("LIVE PREVIEW (XP BAR)"))
    -- Glass card border (Widgets.lua W:PreviewCard).
    if KT.Widgets and KT.Widgets.PreviewCard then KT.Widgets:PreviewCard(prevContainer) end
    KT:SetAccentTextColor(lblPrev, 1)

    -- Same renderer as the live bar, so every style card shows its real art here.
    local fake = Styles:Build(prevContainer)
    fake:SetPoint("CENTER", 0, -6)
    fake._bar:SetMinMaxValues(0, 100)
    fake._bar:SetValue(65)
    fake._rested:SetMinMaxValues(0, 100)
    fake._rested:SetValue(80)
    fake._rested:Show()
    local fakeText = fake._text

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

    local function UpdatePreview()
        local w = tonumber(db.width) or 300
        local hgt = tonumber(db.height) or 10
        -- Keep the preview inside its card on narrow option windows.
        local room = (prevContainer:GetWidth() or w) - 40
        if room > 50 and w > room then w = room end
        fake:SetSize(w, hgt)
        Styles:Apply(fake, db)
        -- Classic keeps the stock 1024 px bar: shrink the preview to fit its card.
        local fw = fake:GetWidth() or w
        fake:SetScale((room > 50 and fw > room) and room / fw or 1)
        Styles:SetFill(fake, db, "xp", true)

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
    -- Below the preview card (10 + 112) with a clear gap, so nothing touches it.
    y = y + 136

    -- Style cards, as on the Cast Bar, Bags and Minimap pages: the bar's art for the
    -- applied Visual Style. Without a pick it follows that style's own look, and
    -- changing the Visual Style switches the bar to the new style's art.
    if KT.VisualThemes and KT.VisualThemes.AddStyleCards then
        local pickedStyle = Styles:Resolve(db)
        y = KT.VisualThemes:AddStyleCards(sc, y, LText("Experience Bar Style"), db, function(key)
            RefreshAndPreview()
            -- A different style asks for a reload; the active card clicked again does not.
            if key ~= pickedStyle then
                pickedStyle = key
                Reload()
            end
        end)
    end

    -- Under the style cards (the first choice on the page): the text inside the bar,
    -- above or below it.
    _, h = W:Dropdown(sc, "Text Position", -y,
        { INSIDE = LText("Inside"), ABOVE = LText("Above"), BELOW = LText("Below") },
        function() return db.textPosition or "ABOVE" end,
        function(v) db.textPosition = v; RefreshAndPreview() end,
        { "INSIDE", "ABOVE", "BELOW" }); y = y + h + 8

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
    -- No X / Y: the bar sits between Action Bars 2 and 3 until moved in Unlock Mode.

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
    _, h = W:Toggle(sc, "Bar Animation", -y,
        function() return db.animate ~= false end,
        function(v) db.animate = v; RefreshAndPreview() end); y = y + h

    return y
end)
