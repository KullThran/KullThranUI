-- Modules//Tooltip//Tooltip_Options.lua
-- Options page: tooltip

-- Auto-generated from Options.lua
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI", true)
if not KT then return end

local LSM = LibStub("LibSharedMedia-3.0", true)

local Opt = KT.Options or {}
local LText = Opt.LText or function(t) return t end
local LTextFmt = Opt.LTextFmt or function(t, ...) return string.format(t, ...) end
local Reload = Opt.Reload or function() StaticPopup_Show("KULLTHRANUI_RELOAD") end
local ResetConfirm = Opt.ResetConfirm or function() StaticPopup_Show("KULLTHRANUI_RESET_CONFIRM") end

local GetFontValues = Opt.GetFontValues
local GetStatusbarValues = Opt.GetStatusbarValues
local GetBackgroundValues = Opt.GetBackgroundValues

local BeginOptionBlocks = Opt.BeginOptionBlocks
local AddOptionBlock = Opt.AddOptionBlock
local EndOptionBlocks = Opt.EndOptionBlocks

local AddPageSubTabBar = KT.AddOptionsSubTabBar

KT:RegisterPage("tooltip", "Tooltip", 50, function(sc, W)
    local y, h = 0, 0
    local db = KT.db.profile.tooltip
    local function Refresh() local M = KT:GetModule("Tooltip",true); if M and M.Refresh then M:Refresh() end end
    
    -- ── LIVE PREVIEW ──
    local prevContainer = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    prevContainer:SetSize(sc:GetWidth() - 20, 260)
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

    local fakeTT = CreateFrame("Frame", nil, prevContainer, "BackdropTemplate")
    fakeTT:SetSize(360, 170)
    fakeTT:SetPoint("CENTER", 0, -2)

    fakeTT.ktBackdrop = CreateFrame("Frame", nil, fakeTT)
    fakeTT.ktBackdrop:SetPoint("TOPLEFT", fakeTT, "TOPLEFT", 0, 0)
    fakeTT.ktBackdrop:SetPoint("BOTTOMRIGHT", fakeTT, "BOTTOMRIGHT", 0, 0)
    fakeTT.ktBackdrop:SetFrameLevel(math.max((fakeTT:GetFrameLevel() or 1) - 1, 0))

    fakeTT.ktBackdrop.bg = fakeTT.ktBackdrop:CreateTexture(nil, "BACKGROUND")
    fakeTT.ktBackdrop.bg:SetPoint("TOPLEFT", 1, -1)
    fakeTT.ktBackdrop.bg:SetPoint("BOTTOMRIGHT", -1, 1)
    fakeTT.ktBackdrop.bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)

    fakeTT.ktBackdrop.top = fakeTT.ktBackdrop:CreateTexture(nil, "BORDER")
    fakeTT.ktBackdrop.top:SetHeight(1)
    fakeTT.ktBackdrop.top:SetPoint("TOPLEFT")
    fakeTT.ktBackdrop.top:SetPoint("TOPRIGHT")

    fakeTT.ktBackdrop.bottom = fakeTT.ktBackdrop:CreateTexture(nil, "BORDER")
    fakeTT.ktBackdrop.bottom:SetHeight(1)
    fakeTT.ktBackdrop.bottom:SetPoint("BOTTOMLEFT")
    fakeTT.ktBackdrop.bottom:SetPoint("BOTTOMRIGHT")

    fakeTT.ktBackdrop.left = fakeTT.ktBackdrop:CreateTexture(nil, "BORDER")
    fakeTT.ktBackdrop.left:SetWidth(1)
    fakeTT.ktBackdrop.left:SetPoint("TOPLEFT")
    fakeTT.ktBackdrop.left:SetPoint("BOTTOMLEFT")

    fakeTT.ktBackdrop.right = fakeTT.ktBackdrop:CreateTexture(nil, "BORDER")
    fakeTT.ktBackdrop.right:SetWidth(1)
    fakeTT.ktBackdrop.right:SetPoint("TOPRIGHT")
    fakeTT.ktBackdrop.right:SetPoint("BOTTOMRIGHT")

    fakeTT.ktBackdrop.SetBackdropBorderColor = function(self, r, g, b, a)
        self.top:SetColorTexture(r, g, b, a)
        self.bottom:SetColorTexture(r, g, b, a)
        self.left:SetColorTexture(r, g, b, a)
        self.right:SetColorTexture(r, g, b, a)
    end
    local healthBar = CreateFrame("StatusBar", nil, prevContainer)
    healthBar:SetPoint("BOTTOMLEFT", fakeTT, "TOPLEFT", 0, 2)
    healthBar:SetPoint("BOTTOMRIGHT", fakeTT, "TOPRIGHT", 0, 2)
    healthBar:SetHeight(6)
    healthBar:SetStatusBarTexture((LSM and LSM:Fetch("statusbar", "Details Flat")) or "Interface\\TargetingFrame\\UI-StatusBar")
    healthBar.bg = healthBar:CreateTexture(nil, "BACKGROUND")
    healthBar.bg:SetAllPoints()
    healthBar.bg:SetColorTexture(0.1, 0.1, 0.1, 0.8)

    local divider = fakeTT:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetColorTexture(0.35, 0.35, 0.35, 0.35)

    local function CreatePreviewText(justify)
        local text = fakeTT:CreateFontString(nil, "OVERLAY")
        text:SetJustifyH(justify or "LEFT")
        text:SetTextColor(0.96, 0.96, 0.98, 1)
        text:SetShadowColor(0, 0, 0, 0.9)
        text:SetShadowOffset(1, -1)
        return text
    end

    local nameText = CreatePreviewText("LEFT")
    local guildText = CreatePreviewText("LEFT")
    local levelText = CreatePreviewText("LEFT")
    local specText = CreatePreviewText("LEFT")

    local scoreLabel = CreatePreviewText("LEFT")
    local scoreValue = CreatePreviewText("RIGHT")
    local itemLevelLabel = CreatePreviewText("LEFT")
    local itemLevelValue = CreatePreviewText("RIGHT")
    local raidLabel = CreatePreviewText("LEFT")
    local raidValue = CreatePreviewText("RIGHT")

    local previewTexts = {
        nameText, guildText, levelText, specText,
        scoreLabel, scoreValue, itemLevelLabel, itemLevelValue,
        raidLabel, raidValue,
    }

    local function SafePreviewCall(func, ...)
        if type(func) ~= "function" then return nil end
        local ok, a, b, c, d, e = pcall(func, ...)
        if not ok then return nil end
        if _G.issecretvalue then
            if a ~= nil and _G.issecretvalue(a) then a = nil end
            if b ~= nil and _G.issecretvalue(b) then b = nil end
            if c ~= nil and _G.issecretvalue(c) then c = nil end
            if d ~= nil and _G.issecretvalue(d) then d = nil end
            if e ~= nil and _G.issecretvalue(e) then e = nil end
        end
        return a, b, c, d, e
    end

    local function HexColor(r, g, b)
        return string.format("|cff%02x%02x%02x", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255)
    end

    local function GetPlayerClassColor(classFilename)
        local color = classFilename and C_ClassColor and C_ClassColor.GetClassColor
            and C_ClassColor.GetClassColor(classFilename)
        if not color and classFilename and RAID_CLASS_COLORS then
            color = RAID_CLASS_COLORS[classFilename]
        end
        return (color and color.r) or 1, (color and color.g) or 1, (color and color.b) or 1
    end

    local function AnchorPreviewLine(text, left, right, yOffset)
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", fakeTT, "TOPLEFT", left, yOffset)
        text:SetPoint("RIGHT", fakeTT, "RIGHT", right, 0)
    end

    local function UpdatePreview()
        local font = (LSM and LSM:Fetch("font", db.font)) or "Fonts\\FRIZQT__.TTF"
        local fontSize = math.max(10, db.fontSize or 12)
        local outline = db.fontOutline or "OUTLINE"
        local lineStep = fontSize + 5
        for _, text in ipairs(previewTexts) do
            text:SetFont(font, fontSize, outline)
        end
        nameText:SetFont(font, fontSize + 2, outline)

        local playerName, realm = SafePreviewCall(UnitFullName, "player")
        if not playerName then
            playerName = SafePreviewCall(UnitName, "player") or UNKNOWNOBJECT or "Player"
        end
        realm = realm or SafePreviewCall(GetNormalizedRealmName)

        local className, classFilename = SafePreviewCall(UnitClass, "player")
        local raceName = SafePreviewCall(UnitRace, "player") or ""
        local level = tonumber(SafePreviewCall(UnitLevel, "player")) or 0
        local guildName, guildRank = SafePreviewCall(GetGuildInfo, "player")
        local faction, localizedFaction = SafePreviewCall(UnitFactionGroup, "player")
        local classR, classG, classB = GetPlayerClassColor(classFilename)
        local classHex = HexColor(classR, classG, classB)
        local displayName = playerName
        if realm and realm ~= "" then
            displayName = displayName .. "-" .. realm
        end

        nameText:SetText(classHex .. displayName .. "|r")
        guildText:SetText(guildName and guildName ~= ""
            and ("|cff40ff40<" .. guildName .. ">|r  |cffaaaaaa" .. (guildRank or "") .. "|r")
            or "|cff888888" .. LText("No Guild") .. "|r")

        local levelColor = SafePreviewCall(GetQuestDifficultyColor, level) or { r = 1, g = 0.82, b = 0 }
        local levelHex = HexColor(levelColor.r, levelColor.g, levelColor.b)
        levelText:SetText(string.format("%s %s%d|r %s %s", LEVEL or "Level", levelHex, level, raceName, className or ""))

        local specName
        local specIndex = SafePreviewCall(GetSpecialization)
        if specIndex then
            local _, resolvedSpecName = SafePreviewCall(GetSpecializationInfo, specIndex)
            specName = resolvedSpecName
        end
        local identityParts = {}
        if specName and specName ~= "" then identityParts[#identityParts + 1] = specName end
        local factionText = localizedFaction or faction
        if factionText and factionText ~= "" then identityParts[#identityParts + 1] = factionText end
        specText:SetText("|cffaaaaaa" .. table.concat(identityParts, " - ") .. "|r")

        local firstY = -10
        AnchorPreviewLine(nameText, 10, -10, firstY)
        AnchorPreviewLine(guildText, 10, -10, firstY - lineStep)
        AnchorPreviewLine(levelText, 10, -10, firstY - (lineStep * 2))
        AnchorPreviewLine(specText, 10, -10, firstY - (lineStep * 3))

        local infoY = firstY - (lineStep * 4) - 7
        divider:ClearAllPoints()
        divider:SetPoint("TOPLEFT", fakeTT, "TOPLEFT", 10, infoY + 5)
        divider:SetPoint("TOPRIGHT", fakeTT, "TOPRIGHT", -10, infoY + 5)

        AnchorPreviewLine(scoreLabel, 10, -120, infoY)
        AnchorPreviewLine(scoreValue, 120, -10, infoY)
        AnchorPreviewLine(itemLevelLabel, 10, -120, infoY - lineStep)
        AnchorPreviewLine(itemLevelValue, 120, -10, infoY - lineStep)
        AnchorPreviewLine(raidLabel, 10, -120, infoY - (lineStep * 2))
        AnchorPreviewLine(raidValue, 120, -10, infoY - (lineStep * 2))

        scoreLabel:SetTextColor(1, 0.8, 0, 1)
        itemLevelLabel:SetTextColor(1, 0.8, 0, 1)
        raidLabel:SetTextColor(1, 0.8, 0, 1)
        itemLevelLabel:SetText(LText("Item Level:"))
        raidLabel:SetText(LText("Raid Progress:"))
        raidValue:SetText("...")
        raidValue:SetTextColor(0.5, 0.5, 0.5, 1)

        if db.scoreType == "PVP" then
            local bestRating = 0
            if C_PvP and C_PvP.GetPersonalRatedInfo then
                for bracketIndex = 1, 4 do
                    local rating = tonumber(SafePreviewCall(C_PvP.GetPersonalRatedInfo, bracketIndex)) or 0
                    bestRating = math.max(bestRating, rating)
                end
            end
            scoreLabel:SetText(LText("PvP Rating:"))
            scoreValue:SetText(tostring(bestRating))
            scoreValue:SetTextColor(1, 1, 1, 1)
        else
            local summary = C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary
                and SafePreviewCall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
            local score = summary and tonumber(summary.currentSeasonScore) or 0
            local scoreColor = C_ChallengeMode and C_ChallengeMode.GetDungeonScoreRarityColor
                and C_ChallengeMode.GetDungeonScoreRarityColor(score)
            scoreLabel:SetText(LText("Mythic+ Score:"))
            scoreValue:SetText(tostring(math.floor(score + 0.5)))
            scoreValue:SetTextColor(
                (scoreColor and scoreColor.r) or 1,
                (scoreColor and scoreColor.g) or 1,
                (scoreColor and scoreColor.b) or 1,
                1
            )
        end

        local _, equippedItemLevel = SafePreviewCall(GetAverageItemLevel)
        equippedItemLevel = tonumber(equippedItemLevel)
        itemLevelValue:SetText(equippedItemLevel and string.format("%.1f", equippedItemLevel) or "...")
        itemLevelValue:SetTextColor(1, 1, 1, 1)

        local health = tonumber(SafePreviewCall(UnitHealth, "player")) or 1
        local healthMax = tonumber(SafePreviewCall(UnitHealthMax, "player")) or 1
        healthMax = math.max(1, healthMax)
        healthBar:SetMinMaxValues(0, healthMax)
        healthBar:SetValue(math.max(0, math.min(health, healthMax)))
        healthBar:SetStatusBarColor(classR, classG, classB, 1)
        fakeTT.ktBackdrop:SetBackdropBorderColor(classR, classG, classB, 1)

        fakeTT:SetHeight(math.max(150, 35 + (lineStep * 7)))
    end
    UpdatePreview()
    prevContainer:SetScript("OnShow", UpdatePreview)
    y = y + 280
    
    local function RefreshAndPreview()
        Refresh()
        UpdatePreview()
    end

    _, h = W:SectionHeader(sc, "General", -y); y = y + h
    _, h = W:Toggle(sc, "Enable Module", -y, function() return db.enable end, function(v) db.enable=v; Reload() end); y = y + h
    _, h = W:Dropdown(sc, "Score Type", -y, {["M+"]="Mythic+",["PVP"]="PvP (Max Rating)"},
        function() return db.scoreType end, function(v) db.scoreType=v; RefreshAndPreview() end); y = y + h
    _, h = W:Toggle(sc, "Show Spell ID", -y, function() return db.showSpellID end, function(v) db.showSpellID=v; Refresh() end); y = y + h
    _, h = W:Toggle(sc, "Show Icon",     -y, function() return db.showIcon end,    function(v) db.showIcon=v;    Refresh() end); y = y + h
    if db.showTargetingPlayers == nil then db.showTargetingPlayers = true end
    _, h = W:Toggle(sc, "Show Targeting Players", -y, function() return db.showTargetingPlayers ~= false end, function(v) db.showTargetingPlayers = v and true or false; Refresh() end); y = y + h
    _, h = W:Slider(sc, "X Offset",     -y, function() return db.xOffset end,     function(v) db.xOffset=v;     Refresh() end, -500, 500, 1); y = y + h
    _, h = W:Slider(sc, "Y Offset",     -y, function() return db.yOffset end,     function(v) db.yOffset=v;     Refresh() end, 0,    1000, 1); y = y + h

    _, h = W:SectionHeader(sc, "Typography", -y); y = y + h
    _, h = W:Dropdown(sc, "Font",    -y, GetFontValues, function() return db.font end,       function(v) db.font=v;       RefreshAndPreview() end); y = y + h
    _, h = W:Slider(sc,  "Size",     -y, function() return db.fontSize end,                 function(v) db.fontSize=v;   RefreshAndPreview() end, 8, 24, 1); y = y + h
    _, h = W:Dropdown(sc, "Outline", -y, {["NONE"]="None",["OUTLINE"]="Thin",["THICKOUTLINE"]="Thick"},
        function() return db.fontOutline end, function(v) db.fontOutline=v; RefreshAndPreview() end); y = y + h
    _, h = W:ColorSwatch(sc, "ID Text Color", -y,
        function() local c=db.textColor; return c.r,c.g,c.b,c.a end,
        function(r,g,b,a) db.textColor={r=r,g=g,b=b,a=a} end, true); y = y + h

    return y
end)
