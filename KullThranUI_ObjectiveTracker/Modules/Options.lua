local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local LSM = LibStub("LibSharedMedia-3.0", true)

local function GetFontValues()
    local fonts = {}
    if LSM then
        for _, name in ipairs(LSM:List("font")) do
            fonts[name] = name
        end
    end
    return fonts
end

KT:RegisterPage("objectivetracker", "Objective Tracker", 55, function(sc, W)
    local y, h = 0, 0
    
    _, h = W:SectionHeader(sc, LText("Objective Tracker"), -y); y = y + h
    _, h = W:Label(sc, LText("Objective Tracker Skin settings."), -y, 11); y = y + h
    
    if not KT.db.profile.objectiveTracker then
        KT.db.profile.objectiveTracker = { enable = true, font = KT.DEFAULT_FONT_NAME, fontSize = 13, fontOutline = "OUTLINE", colorMode = "accent", customColor = { r = 1, g = 1, b = 1, a = 1 }, solidBackground = false }
    end
    local db = KT.db.profile.objectiveTracker

    -- LIVE PREVIEW
    _, h = W:SectionHeader(sc, LText("Live Preview"), -y); y = y + h
    
    local previewFrame = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    previewFrame:SetSize(280, 200)
    previewFrame:SetPoint("TOP", sc, "TOP", 0, -y)
    
    local zoneBg = previewFrame:CreateTexture(nil, "BACKGROUND", nil, -7)
    zoneBg:SetAllPoints()
    zoneBg:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\InstallerBackground.png")
    zoneBg:SetTexCoord(0, 1, 0.2, 0.5)
    
    previewFrame.tex = previewFrame:CreateTexture(nil, "BACKGROUND", nil, -1)
    previewFrame.tex:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 0, 0)
    previewFrame.tex:SetPoint("BOTTOMLEFT", previewFrame, "BOTTOMLEFT", 0, 0)
    previewFrame.tex:SetWidth(270) -- slightly smaller than the frame so the gradient fades out nicely
    previewFrame.tex:SetColorTexture(0, 0, 0, 1)
    previewFrame.tex:SetGradient("HORIZONTAL", CreateColor(0,0,0,1), CreateColor(0,0,0,0))
    previewFrame.topBorder = previewFrame:CreateTexture(nil, "OVERLAY")
    previewFrame.topBorder:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 0, 0)
    previewFrame.topBorder:SetPoint("TOPRIGHT", previewFrame, "TOPRIGHT", 0, 0)
    previewFrame.topBorder:SetHeight(2)
    previewFrame.topBorder:Hide()
    
    local lines = {}
    local function SetPreviewAtlas(texture, normalAtlas, selectedAtlas, selected)
        if not texture then return end
        local atlas = selected and (selectedAtlas or normalAtlas) or normalAtlas
        if texture.SetAtlas and atlas then
            texture:SetAtlas(atlas, true)
        end
        texture:SetSize(18, 18)
    end

    local function AddPreviewLine(text, isHeader, isQuest, isComplete, icon)
        local fs = previewFrame:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject("GameFontNormal")
        fs:SetText(text)
        fs.isHeader = isHeader
        fs.isQuest = isQuest
        fs.isComplete = isComplete

        local line = {
            fs = fs,
            icon = icon,
            isHeader = isHeader,
            isQuest = isQuest,
            isComplete = isComplete,
            selected = false,
            hovered = false,
        }

        if icon == "campaign" or icon == "quest" or icon == "turnin" then
            local iconButton = CreateFrame("Button", nil, previewFrame)
            iconButton:SetSize(20, 20)
            iconButton:EnableMouse(true)
            line.iconButton = iconButton
            line.iconTex = iconButton:CreateTexture(nil, "ARTWORK")
            line.iconTex:SetPoint("CENTER")
            line.iconTex:SetSize(18, 18)

            if icon == "campaign" then
                line.poiAtlas = "UI-QuestPoiCampaign-QuestNumber"
                line.poiSelectedAtlas = "UI-QuestPoiCampaign-QuestNumber-SuperTracked"
            elseif icon == "turnin" then
                line.poiAtlas = "UI-QuestPoi-QuestBangTurnIn"
                line.poiSelectedAtlas = line.poiAtlas
            else
                line.poiAtlas = "UI-QuestPoi-QuestNumber"
                line.poiSelectedAtlas = "UI-QuestPoi-QuestNumber-SuperTracked"
            end

            iconButton:SetScript("OnEnter", function()
                line.hovered = true
                previewFrame.timer = 1
            end)
            iconButton:SetScript("OnLeave", function()
                line.hovered = false
                previewFrame.timer = 1
            end)
            iconButton:SetScript("OnClick", function()
                line.selected = not line.selected
                previewFrame.timer = 1
            end)
        elseif icon == "minus" then
            line.iconTex = previewFrame:CreateTexture(nil, "OVERLAY")
            line.iconTex:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
            line.iconTex:SetSize(12, 12)
        elseif icon == "check" then
            line.iconTex = previewFrame:CreateTexture(nil, "OVERLAY")
            line.iconTex:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
            line.iconTex:SetSize(16, 16)
        elseif icon == "dash" then
            line.iconTex = previewFrame:CreateTexture(nil, "OVERLAY")
            line.iconTex:SetColorTexture(0.75, 0.75, 0.75, 1)
            line.iconTex:SetSize(8, 2)
        end

        table.insert(lines, line)
    end

    AddPreviewLine(LText("Campaign"), true, false, false, "minus")
    AddPreviewLine(LText("The Voidspire"), false, true, false, "campaign")
    AddPreviewLine(LText("- 0/1 Enter the Voidspire Raid\n  Story Mode (Optional)"), false, false, false, "dash")
    AddPreviewLine(LText("Enter the Voidspire Raid"), false, true, true, "turnin")
    AddPreviewLine(LText("- 0/1 Voidspire Raid completed"), false, false, true, "check")

    AddPreviewLine(LText("Quests"), true, false, false, "minus")
    AddPreviewLine(LText("Late Night Training: Week 1 of 3"), false, true, false, "quest")
    AddPreviewLine(LText("- 0/2 Battlegrounds won"), false, false, false, "dash")
    AddPreviewLine(LText("Slayer's Rise"), false, true, true, "turnin")
    AddPreviewLine(LText("Ready for turn-in"), false, false, true, "check")
    previewFrame:SetScript("OnUpdate", function(self, elapsed)
        self.timer = (self.timer or 0) + elapsed
        if self.timer > 0.2 then
            self.timer = 0
            
            local db = KT.db.profile.objectiveTracker
            local size = db.fontSize or 13
            local outline = db.fontOutline or "OUTLINE"
            if outline == "NONE" then outline = "" end
            
            local fontPath = KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
            if KT and KT.ResolveFontForLocale then
                fontPath = KT:ResolveFontForLocale(db.font, fontPath)
            elseif LSM and db.font then
                fontPath = LSM:Fetch("font", db.font) or fontPath
            end
            
            local r, g, b = 1, 1, 1
            if db.colorMode == "custom" and db.customColor then
                r, g, b = db.customColor.r, db.customColor.g, db.customColor.b
            elseif KT.GetStyleAccentRGB then
                r, g, b = KT:GetStyleAccentRGB()
            else
                local skin = KT.db.profile.skin
                local color = (skin and skin.accentColor) or KT.BRAND_COLOR or { r = 0, g = 0.6, b = 1 }
                r, g, b = color.r, color.g, color.b
            end
            
            local currentY = -10
            for i, line in ipairs(lines) do
                local fs = line.fs
                local fontSize = size
                if line.isHeader then
                    fontSize = size + 2
                    fs:SetTextColor(r, g, b)
                    fs:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 10, currentY)
                elseif line.isQuest then
                    fontSize = size
                    if db.useBlizzardQuestColors then
                        fs:SetTextColor((line.selected or line.hovered) and 1 or 1, (line.selected or line.hovered) and 1 or 0.82, (line.selected or line.hovered) and 1 or 0)
                    else
                        fs:SetTextColor((line.selected or line.hovered) and 1 or r, (line.selected or line.hovered) and 1 or g, (line.selected or line.hovered) and 1 or b)
                    end
                    fs:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 30, currentY)
                else
                    fontSize = size - 1
                    if line.isComplete then
                        fs:SetTextColor(0.6, 0.6, 0.6)
                    else
                        fs:SetTextColor(0.9, 0.9, 0.9)
                    end
                    local xOff = line.isComplete and 36 or 30
                    fs:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", xOff, currentY)
                end
                
                fs:SetFont(fontPath, fontSize, outline)
                fs:SetShadowColor(0, 0, 0, 1)
                fs:SetShadowOffset(1, -1)
                
                if line.iconButton then
                    line.iconButton:ClearAllPoints()
                    line.iconButton:SetPoint("LEFT", previewFrame, "TOPLEFT", 8, currentY - 2)
                    SetPreviewAtlas(line.iconTex, line.poiAtlas, line.poiSelectedAtlas, line.selected or line.hovered)
                elseif line.iconTex then
                    if line.isHeader then
                        line.iconTex:SetPoint("RIGHT", previewFrame, "RIGHT", -15, currentY - (fontSize/2) + 5)
                        line.iconTex:SetVertexColor(1, 0.8, 0)
                    elseif line.icon == "check" then
                        line.iconTex:SetPoint("LEFT", fs, "LEFT", -18, -1)
                        line.iconTex:SetVertexColor(0, 1, 0)
                    elseif line.icon == "dash" then
                        line.iconTex:SetPoint("LEFT", fs, "LEFT", -12, -fontSize / 2 + 5)
                        line.iconTex:SetVertexColor(0.75, 0.75, 0.75)
                    end
                end
                currentY = currentY - fs:GetHeight() - 4
                if line.isHeader or line.isQuest then
                    currentY = currentY - 2
                end
            end
            
            -- Adjust background frame size to exactly fit contents
            local totalHeight = math.abs(currentY) + 10
            previewFrame:SetHeight(totalHeight)
            
            if db.solidBackground == true then
                self.tex:ClearAllPoints()
                self.tex:SetAllPoints(previewFrame)
                self.tex:SetColorTexture(0, 0, 0, 1)
                self.topBorder:SetColorTexture(r, g, b, 1)
                self.topBorder:Show()
                self.tex:SetAlpha(1)
            else
                self.tex:ClearAllPoints()
                self.tex:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 0, 0)
                self.tex:SetPoint("BOTTOMLEFT", previewFrame, "BOTTOMLEFT", 0, 0)
                self.tex:SetWidth(270)
                self.tex:SetColorTexture(0, 0, 0, 1)
                self.tex:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 1), CreateColor(0, 0, 0, 0))
                self.topBorder:Hide()
                self.tex:SetAlpha(db.bgAlpha or 0)
            end
        end
    end)
    
    y = y + 210 + 20

    local leftCol = CreateFrame("Frame", nil, sc)
    leftCol:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)
    leftCol:SetSize(300, 300)

    local rightCol = CreateFrame("Frame", nil, sc)
    rightCol:SetPoint("TOPLEFT", sc, "TOPLEFT", 330, -y)
    rightCol:SetSize(300, 300)

    local ly, ry = 0, 0

    -- GENERAL SECTION
    _, h = W:SectionHeader(leftCol, LText("General"), -ly); ly = ly + h
    _, h = W:Toggle(leftCol, LText("Enable Objective Tracker Skin"), -ly,
        function() return db.enable end,
        function(v) db.enable = v; ReloadUI() end
    ); ly = ly + h + 10
    
    -- COLOR SECTION
    _, h = W:SectionHeader(leftCol, LText("Color"), -ly); ly = ly + h
    _, h = W:Dropdown(leftCol, LText("Objective Tracker Color"), -ly,
        { accent = LText("Accent (Default)"), custom = LText("Custom Color") },
        function() return db.colorMode or "accent" end,
        function(v)
            db.colorMode = v
            if KT.ObjectiveTrackerSkin_UpdateColors then KT.ObjectiveTrackerSkin_UpdateColors() end
        end,
        { "accent", "custom" }
    ); ly = ly + h + 10
    _, h = W:ColorSwatch(leftCol, LText("Objective Tracker Custom Color"), -ly,
        function()
            local c = db.customColor or { r = 1, g = 1, b = 1, a = 1 }
            return c.r, c.g, c.b, 1
        end,
        function(r, g, b)
            db.colorMode = "custom"
            db.customColor = { r = r, g = g, b = b, a = 1 }
            if KT.ObjectiveTrackerSkin_UpdateColors then KT.ObjectiveTrackerSkin_UpdateColors() end
            if KT.RefreshPage then KT:RefreshPage(true) end
        end,
        false
    ); ly = ly + h + 10
    
    _, h = W:Toggle(leftCol, LText("Use Blizzard Quest Colors"), -ly,
        function() return db.useBlizzardQuestColors end,
        function(v) 
            db.useBlizzardQuestColors = v
            if KT.ObjectiveTrackerSkin_UpdateColors then KT.ObjectiveTrackerSkin_UpdateColors() end
        end
    ); ly = ly + h + 10
    
    -- VISIBILITY SECTION
    _, h = W:SectionHeader(leftCol, LText("Visibility"), -ly); ly = ly + h
    local function RefreshVisibility()
        if KT.ObjectiveTrackerSkin_UpdateVisibility then KT.ObjectiveTrackerSkin_UpdateVisibility() end
    end
    _, h = W:Toggle(leftCol, LText("Hide in Combat"), -ly,
        function() return db.hideInCombat end,
        function(v) db.hideInCombat = v; RefreshVisibility() end
    ); ly = ly + h
    _, h = W:Toggle(leftCol, LText("Hide in Arena"), -ly,
        function() return db.hideInArena end,
        function(v) db.hideInArena = v; RefreshVisibility() end
    ); ly = ly + h
    _, h = W:Toggle(leftCol, LText("Hide in Dungeon"), -ly,
        function() return db.hideInDungeon end,
        function(v) db.hideInDungeon = v; RefreshVisibility() end
    ); ly = ly + h
    _, h = W:Toggle(leftCol, LText("Hide in Raid"), -ly,
        function() return db.hideInRaid end,
        function(v) db.hideInRaid = v; RefreshVisibility() end
    ); ly = ly + h + 10

    -- TYPOGRAPHY SECTION
    _, h = W:SectionHeader(rightCol, LText("Typography"), -ry); ry = ry + h
    _, h = W:Dropdown(rightCol, LText("Quest Title Font"), -ry,
        GetFontValues,
        function() return db.font end,
        function(v) db.font = v; if KT.ObjectiveTrackerSkin_Refresh then KT.ObjectiveTrackerSkin_Refresh() end end
    ); ry = ry + h + 10
    _, h = W:Slider(rightCol, LText("Quest Title Size"), -ry, 
        function() return db.fontSize end,
        function(v) db.fontSize = v; if KT.ObjectiveTrackerSkin_Refresh then KT.ObjectiveTrackerSkin_Refresh() end end,
        8, 24, 1
    ); ry = ry + h + 10
    _, h = W:Dropdown(rightCol, LText("Font Outline"), -ry,
        { NONE = LText("None"), OUTLINE = LText("Outline"), THICKOUTLINE = LText("Thick Outline") },
        function() return db.fontOutline end,
        function(v) db.fontOutline = v; if KT.ObjectiveTrackerSkin_Refresh then KT.ObjectiveTrackerSkin_Refresh() end end,
        { "NONE", "OUTLINE", "THICKOUTLINE" }
    ); ry = ry + h + 10

    -- BACKGROUND & FADE SECTION
    _, h = W:SectionHeader(rightCol, LText("Background & Fade"), -ry); ry = ry + h
    _, h = W:Toggle(rightCol, LText("Solid Background"), -ry,
        function() return db.solidBackground == true end,
        function(v)
            db.solidBackground = v
            if KT.ObjectiveTrackerSkin_UpdateBgAlpha then KT.ObjectiveTrackerSkin_UpdateBgAlpha() end
            if KT.RefreshPage then KT:RefreshPage(true) end
        end
    ); ry = ry + h
    _, h = W:Label(rightCol, LText("Opaque black background with an accent-colored top border."), -ry, 10, { r = 0.6, g = 0.6, b = 0.6 }); ry = ry + h + 10
    _, h = W:Slider(rightCol, LText("Background Alpha"), -ry, 
        function() return db.bgAlpha or 0 end,
        function(v) 
            db.bgAlpha = v
            if KT.ObjectiveTrackerSkin_UpdateBgAlpha then KT.ObjectiveTrackerSkin_UpdateBgAlpha() end
        end,
        0, 1, 0.05
    ); ry = ry + h + 10
    _, h = W:Slider(rightCol, LText("Fade Delay (Seconds)"), -ry, 
        function() return db.fadeDelay or 0 end,
        function(v) db.fadeDelay = v end,
        0, 60, 1
    ); ry = ry + h
    _, h = W:Label(rightCol, LText("Set to 0 to disable fading."), -ry, 10, { r = 0.6, g = 0.6, b = 0.6 }); ry = ry + h + 10

    -- RESTORE DEFAULTS
    _, h = W:Button(rightCol, LText("Restore Defaults"), -ry, function()
        db.font = "AAA_ITC_Avant_Garde"
        db.fontSize = 13
        db.fontOutline = "OUTLINE"
        db.colorMode = "accent"
        db.customColor = { r = 1, g = 1, b = 1, a = 1 }
        db.useBlizzardQuestColors = false
        db.bgAlpha = 0
        db.solidBackground = false
        db.hideInCombat = false
        db.hideInArena = false
        db.hideInDungeon = false
        db.hideInRaid = false
        db.fadeDelay = 0
        ReloadUI()
    end, 180); ry = ry + h + 20

    -- Restore maxy logic but without Live Preview at bottom
    local maxy = math.max(ly, ry)
    maxy = maxy + 20
    return maxy
end)
