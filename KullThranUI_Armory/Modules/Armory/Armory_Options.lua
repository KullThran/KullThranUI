-- Modules//Armory//Armory_Options.lua
-- Options page: armory

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
local PANEL_BG = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Armory_Right_Panel_png.tga"
local ARMORY_PANEL_BG = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\armory_rightpanel.png"
local ARMORY_PANEL_ASPECT = 583 / 1024
local ARMORY_HEADER_GOLD = { r = 0.94, g = 0.78, b = 0.29, a = 1 }
local ARMORY_HEADER_ATTRIBUTE = { r = 1.00, g = 0.64, b = 0.00, a = 1 }
local ARMORY_HEADER_SECONDARY = { r = 0.50, g = 0.78, b = 0.50, a = 1 }
local ARMORY_ILVL_PURPLE = { r = 0.7568627451, g = 0.00, b = 1.00, a = 1 }
local ARMORY_PVP_ILVL_COLOR = { r = 0.00, g = 0.50, b = 1.00, a = 1 }
local ARMORY_ENHANCEMENT_COLOR = { r = 0.00, g = 1.00, b = 0.6156862745, a = 1 }
local ARMORY_SECONDARY_COLOR = { r = 1.00, g = 0.96, b = 0.41, a = 1 }
local ARMORY_DEFENSE_COLOR = { r = 0.00, g = 0.44, b = 0.87, a = 1 }
local ARMORY_ARMOR_COLOR = { r = 0.2, g = 0.6588235294, b = 0.9019607843, a = 1 }
local ARMORY_GENERAL_COLOR = { r = 0.60, g = 0.60, b = 0.60, a = 1 }
local ARMORY_ATTACK_COLOR = { r = 1.00, g = 0.41, b = 0.70, a = 1 }
local ARMORY_PURPLE_COLOR = { r = 0.64, g = 0.21, b = 0.93, a = 1 }
local ARMORY_PINK_COLOR = { r = 0.9882352941, g = 0.6745098039, b = 0.6745098039, a = 1 }
local function SafePreviewNumber(value)
    if value == nil then return nil end
    if issecretvalue and issecretvalue(value) then
        if not securecallfunction then return nil end
        local extracted = securecallfunction(function(v) return tonumber(v) end, value)
        if extracted == nil or (issecretvalue and issecretvalue(extracted)) then return nil end
        return extracted
    end
    return tonumber(value)
end

local function SafePreviewNumberCall(func, ...)
    if not func then return nil, nil, nil, nil, nil end
    local ok, first, second, third, fourth, fifth = pcall(func, ...)
    if not ok then return nil, nil, nil, nil, nil end
    return SafePreviewNumber(first), SafePreviewNumber(second), SafePreviewNumber(third), SafePreviewNumber(fourth), SafePreviewNumber(fifth)
end

local function GetPreviewSpellTexture(spellID)
    local ok, texture = pcall(function()
        if C_Spell and C_Spell.GetSpellTexture then
            return C_Spell.GetSpellTexture(spellID)
        elseif C_Spell and C_Spell.GetSpellInfo then
            local info = C_Spell.GetSpellInfo(spellID)
            return info and info.iconID
        elseif GetSpellTexture then
            return GetSpellTexture(spellID)
        elseif GetSpellInfo then
            local _, _, icon = GetSpellInfo(spellID)
            return icon
        end
    end)
    return ok and texture or nil
end

local function FormatPreviewNumber(value)
    local numeric = SafePreviewNumber(value)
    if not numeric then return "—" end
    numeric = math.floor(numeric + 0.5)
    if BreakUpLargeNumbers then return BreakUpLargeNumbers(numeric) end
    return tostring(numeric)
end

local function GetPreviewHastePercent()
    local haste = SafePreviewNumberCall(UnitSpellHaste, "player")
    if haste ~= nil then return haste end
    return SafePreviewNumberCall(GetHaste) or 0
end

local function FormatPreviewSecondaryValue(displayMode, percentValue, ratingValue, numericValueOverride)
    local percent = SafePreviewNumber(percentValue) or 0
    local rating = numericValueOverride ~= nil and SafePreviewNumber(numericValueOverride) or SafePreviewNumber(ratingValue)
    local percentText = string.format("%.2f%%", percent)
    local numericText = (rating and rating > 0) and FormatPreviewNumber(rating) or "0"
    if displayMode == "PERCENT" then return percentText end
    if displayMode == "NUMERIC" then return numericText end
    return string.format("%s (%s)", numericText, percentText)
end
local PREVIEW_EMPTY_SLOT_TEXTURES = {
    [1]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head",
    [2]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck",
    [3]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder",
    [4]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shirt",
    [5]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",
    [6]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",
    [7]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs",
    [8]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",
    [9]  = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrist",
    [10] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands",
    [11] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",
    [12] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",
    [13] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
    [14] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
    [15] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Back",
    [16] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand",
    [17] = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand",
}local PREVIEW_LEFT_SLOT_IDS = { 1, 2, 3, 15, 5, 4, 9 }
local PREVIEW_RIGHT_SLOT_IDS = { 10, 6, 7, 8, 11, 12, 13, 14 }
local PREVIEW_BOTTOM_SLOT_IDS = { 16, 17 }
local PREVIEW_SLOT_IDS = {}
for _, slotID in ipairs(PREVIEW_LEFT_SLOT_IDS) do PREVIEW_SLOT_IDS[#PREVIEW_SLOT_IDS + 1] = slotID end
for _, slotID in ipairs(PREVIEW_RIGHT_SLOT_IDS) do PREVIEW_SLOT_IDS[#PREVIEW_SLOT_IDS + 1] = slotID end
for _, slotID in ipairs(PREVIEW_BOTTOM_SLOT_IDS) do PREVIEW_SLOT_IDS[#PREVIEW_SLOT_IDS + 1] = slotID end
local function GetPvPIlvlExtraHeight(db)
    if not db or db.showAvgIlvl == false or db.showAvgIlvlPvP == false then return 0 end
    local size = tonumber(db.avgIlvlPvPFontSize) or 10
    local offsetY = tonumber(db.avgIlvlPvPOffsetY) or -2
    return math.max(0, size - 10) + math.max(0, -2 - offsetY)
end
local function GetArmoryPreviewHeight(db)
    local statSize = (db and db.statFontSize) or 11
    local sectionGap = math.max(8, math.floor(statSize * 0.77))
    local previewHeight = 322 + (sectionGap * 3)

    if db and db.showAvgIlvl == false then
        previewHeight = previewHeight - 14
    end

    previewHeight = previewHeight + GetPvPIlvlExtraHeight(db)
    return math.max(previewHeight, 316)
end

local function LayoutPreviewHeaderBars(leftBar, rightBar, label, parent, color)
    if not (leftBar and rightBar and label and parent) then
        return
    end

    local parentWidth = parent.GetWidth and parent:GetWidth() or 180
    local labelWidth = label.GetStringWidth and label:GetStringWidth() or 0
    local gap = math.max(10, math.floor(parentWidth * 0.06))
    local lineWidth = math.max(28, math.floor((parentWidth - labelWidth - (gap * 2)) / 2))
    local r = (color and color.r) or 1
    local g = (color and color.g) or 1
    local b = (color and color.b) or 1
    local a = ((color and color.a) or 1) * 0.82

    leftBar:ClearAllPoints()
    leftBar:SetSize(lineWidth, 2)
    leftBar:SetPoint("RIGHT", label, "LEFT", -gap, 0)
    leftBar:SetPoint("CENTER", label, "CENTER", 0, 0)
    leftBar:SetTexture("Interface\\Buttons\\WHITE8X8")
    leftBar:SetColorTexture(r, g, b, a)
    leftBar:ClearAllPoints()
    leftBar:SetPoint('RIGHT', label, 'LEFT', -5, 1)
    leftBar:SetSize(80, 8)
    leftBar:SetWidth(math.min(80, lineWidth))
    leftBar:SetTexture('Interface\\AddOns\\KullThranUI\\Libraries\\texture\\separator_armory.png')
    leftBar:SetTexCoord(1, 0, 0, 1)
    leftBar:SetVertexColor(r, g, b, 1)
    leftBar:Show()

    rightBar:ClearAllPoints()
    rightBar:SetSize(lineWidth, 2)
    rightBar:SetPoint("LEFT", label, "RIGHT", gap, 0)
    rightBar:SetPoint("CENTER", label, "CENTER", 0, 0)
    rightBar:SetTexture("Interface\\Buttons\\WHITE8X8")
    rightBar:SetColorTexture(r, g, b, a)
    rightBar:ClearAllPoints()
    rightBar:SetPoint('LEFT', label, 'RIGHT', 5, 1)
    rightBar:SetSize(80, 8)
    rightBar:SetWidth(math.min(80, lineWidth))
    rightBar:SetTexture('Interface\\AddOns\\KullThranUI\\Libraries\\texture\\separator_armory.png')
    rightBar:SetTexCoord(0, 1, 0, 1)
    rightBar:SetVertexColor(r, g, b, 1)
    rightBar:Show()
end

local function ScrollToOptionBlock(block)
    local menu = KT and KT.MenuPrincipal
    local sf = menu and menu.scrollFrame
    local sb = sf and sf.ScrollBar
    local sc = menu and menu.scrollChild
    if not (block and sf and sb and sc) then return end

    local function ApplyScroll()
        local scTop = sc:GetTop()
        local blockTop = block:GetTop()
        if not (scTop and blockTop) then return end

        local minVal, maxVal = sb:GetMinMaxValues()
        local target = math.floor((scTop - blockTop) + 8 + 0.5)
        if minVal and target < minVal then target = minVal end
        if maxVal and target > maxVal then target = maxVal end

        if KT.SmoothScrollTo then
            KT.SmoothScrollTo(target)
        else
            sb:SetValue(target)
        end
    end

    ApplyScroll()
    C_Timer.After(0.05, ApplyScroll)

    if not block._previewHighlight then
        local hl = block:CreateTexture(nil, "OVERLAY")
        hl:SetAllPoints()
        local r, g, b = 1, 0.82, 0 -- fallback
        if KT and KT.GetStyleAccentRGB then
            r, g, b = KT:GetStyleAccentRGB()
        elseif KT.C_R then
            r, g, b = KT.C_R, KT.C_G, KT.C_B
        end
        hl:SetColorTexture(r, g, b, 0.4)
        hl:SetBlendMode("ADD")
        hl:Hide()
        block._previewHighlight = hl
        
        local ag = hl:CreateAnimationGroup()
        local a1 = ag:CreateAnimation("Alpha")
        a1:SetFromAlpha(0)
        a1:SetToAlpha(1)
        a1:SetDuration(0.15)
        a1:SetOrder(1)
        local a2 = ag:CreateAnimation("Alpha")
        a2:SetFromAlpha(1)
        a2:SetToAlpha(0)
        a2:SetDuration(0.6)
        a2:SetOrder(2)
        ag:SetScript("OnFinished", function() hl:Hide() end)
        ag:SetScript("OnPlay", function() hl:Show() end)
        block._previewHighlightAnim = ag
    end
    
    if block._previewHighlightAnim then
        block._previewHighlightAnim:Stop()
        block._previewHighlightAnim:Play()
    end
end

local function BindPreviewClick(frame, label, desc, getTargetBlock)
    if not frame then return end

    frame:SetScript("OnClick", function()
        C_Timer.After(0.05, function()
            local target = getTargetBlock and getTargetBlock()
            if target then ScrollToOptionBlock(target) end
        end)
    end)

    frame:SetScript("OnEnter", function(self)
        if KT.AddAccentBorder then KT:AddAccentBorder(self, 1) end
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label or "Armory Preview", 1, 1, 1)
            GameTooltip:AddLine(desc or "Click to jump to its settings block.", 0.75, 0.82, 0.9, true)
            GameTooltip:Show()
        end
    end)

    frame:SetScript("OnLeave", function(self)
        if KT.AddBorder then KT:AddBorder(self, 0, 0, 0, 1) end
        if GameTooltip then GameTooltip:Hide() end
    end)
end


KT:RegisterPage("armory", "Armory", 55, function(sc, W)
    local y, h = 0, 0
    local db = KT.db.profile.armory
    db.statFormatMode = db.statFormatMode or "BOTH"
    local function UpdatePreview() end
    local function Refresh()
        local M = KT:GetModule("Armory",true)
        if M and M.Refresh then M:Refresh() end
        UpdatePreview()
    end
    local function RefreshH()
        local M = KT:GetModule("Armory",true)
        if M and M.UpdateHeader then M:UpdateHeader() end
        UpdatePreview()
    end

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

    local previewTexturePath = "Interface\\AddOns\\KullThranUI\\Modules\\Armory\\Armory Textures\\"
    local previewDefaultBackgroundFile = "Space.blp"
    local previewBackgroundFiles = {
        SPACE = "Space.blp",
        CASTLE = "Castle.blp",
        EMPIRE = "TheEmpire.blp",
        KYRIAN = "Cov_Kyrian.blp",
        NECRO = "Cov_Necrolords.blp",
        NIGHTFAE = "Cov_NightFae.blp",
        VENTHYR = "Cov_Venthyr.blp",
        DK = "DEATHKNIGHT.blp",
        HUNTER = "HUNTER.blp",
        MAGE = "MAGE.blp",
        WARRIOR = "WARRIOR.blp",
        ROGUE = "ROGUE.blp",
        DRUID = "DRUID.blp",
        SHAMAN = "SHAMAN.blp",
        PRIEST = "PRIEST.blp",
        WARLOCK = "WARLOCK.blp",
        PALADIN = "PALADIN.blp",
        MONK = "MONK.blp",
        DH = "DEMONHUNTER.blp",
        EVOKER = previewDefaultBackgroundFile,
    }

    local previewClassBackgroundFiles = {
        DEATHKNIGHT = "DEATHKNIGHT.blp",
        DEMONHUNTER = "DEMONHUNTER.blp",
        DRUID = "DRUID.blp",
        EVOKER = previewDefaultBackgroundFile,
        HUNTER = "HUNTER.blp",
        MAGE = "MAGE.blp",
        MONK = "MONK.blp",
        PALADIN = "PALADIN.blp",
        PRIEST = "PRIEST.blp",
        ROGUE = "ROGUE.blp",
        SHAMAN = "SHAMAN.blp",
        WARLOCK = "WARLOCK.blp",
        WARRIOR = "WARRIOR.blp",
    }

    local function ResolvePreviewBackgroundFile(bgType)
        local selected = bgType or "CLASS"
        if selected == "CLASS" then
            local _, classFilename = UnitClass("player")
            return previewClassBackgroundFiles[classFilename] or previewDefaultBackgroundFile
        end
        return previewBackgroundFiles[selected] or previewDefaultBackgroundFile
    end

    local function ResolveArmoryAccentColor()
        local skin = KT and KT.db and KT.db.profile and KT.db.profile.skin or nil
        if skin and skin.armoryColorMode == "custom" and skin.armoryColor then
            local c = skin.armoryColor
            return c.r or 1, c.g or 0, c.b or 0.3333333333
        end
        if KT and KT.GetStyleAccentRGB then
            return KT:GetStyleAccentRGB()
        end
        return KT.C_R or 1, KT.C_G or 0, KT.C_B or 0.3333333333
    end

    local function GetUnifiedHeaderColor()
        local color = db and db.ilvlHeaderColor or nil
        if type(color) == "table" then
            return color
        end
        return ARMORY_HEADER_GOLD
    end

    local function ApplyTextureGradient(texture, orientation, startR, startG, startB, startA, endR, endG, endB, endA)
        if not texture then
            return
        end

        texture:SetTexture("Interface\\Buttons\\WHITE8X8")
        if texture.SetGradientAlpha then
            texture:SetGradientAlpha(
                orientation or "HORIZONTAL",
                startR or 1, startG or 1, startB or 1, startA or 1,
                endR or 1, endG or 1, endB or 1, endA or 1
            )
        else
            texture:SetColorTexture(startR or 1, startG or 1, startB or 1, math.max(startA or 0, endA or 0))
        end
    end

    local function ApplyPreviewPanelTexture(texture)
        if not texture then
            return
        end

        local ok = false
        if texture.SetTexture then
            local success, result = pcall(texture.SetTexture, texture, ARMORY_PANEL_BG)
            ok = success and result ~= false
        end

        if not ok and texture.SetTexture then
            texture:SetTexture(PANEL_BG)
        end

        texture:SetBlendMode("BLEND")
        texture:SetVertexColor(1, 1, 1, 1)
    end

    local function LayoutPreviewPanelTexture(texture, parent)
        if not (texture and parent) then
            return
        end

        local width = parent.GetWidth and parent:GetWidth() or 0
        local height = parent.GetHeight and parent:GetHeight() or 0
        if width <= 0 or height <= 0 then
            texture:ClearAllPoints()
            texture:SetAllPoints(parent)
            if texture.SetTexCoord then
                texture:SetTexCoord(0, 1, 0, 1)
            end
            return
        end

        texture:ClearAllPoints()
        if texture.SetTexCoord then
            texture:SetTexCoord(0, 1, 0, 1)
        end

        local targetWidth = height * ARMORY_PANEL_ASPECT
        if targetWidth <= width then
            texture:SetPoint("TOP", parent, "TOP", 0, 0)
            texture:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)
            texture:SetWidth(targetWidth)
        else
            local targetHeight = width / ARMORY_PANEL_ASPECT
            texture:SetPoint("LEFT", parent, "LEFT", 0, 0)
            texture:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
            texture:SetHeight(targetHeight)
            texture:SetPoint("CENTER", parent, "CENTER", 0, 0)
        end
    end

    local stickyHost = KT.MenuPrincipal and KT.MenuPrincipal._stickyPreviewHost
    local prevContainer = CreateFrame("Frame", nil, stickyHost or sc, "BackdropTemplate")
    prevContainer:SetSize(sc:GetWidth() - 20, GetArmoryPreviewHeight(db))
    prevContainer:SetPoint("TOP", sc, "TOP", 0, -10)
    if stickyHost then
        prevContainer:SetFrameStrata(stickyHost:GetFrameStrata())
        prevContainer:SetFrameLevel((stickyHost:GetFrameLevel() or prevContainer:GetFrameLevel() or 1) + 1)
    end
    if KT.AddBackdrop then KT:AddBackdrop(prevContainer, 0.08, 0.08, 0.09, 0.55) end
    if KT.AddBorder then KT:AddBorder(prevContainer, 0, 0, 0, 1) end
    if KT.AttachStickyPreview then
        KT:AttachStickyPreview(prevContainer, { point = "TOP", relativePoint = "TOP", x = 0, y = -10, extraPad = 10 })
    end

    local lblPrev = prevContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lblPrev:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 10, -8)
    lblPrev:SetText(LText("LIVE PREVIEW"))
    KT:SetAccentTextColor(lblPrev, 1)

    local leftPane = CreateFrame("Frame", nil, prevContainer, "BackdropTemplate")
    leftPane:SetPoint("TOPLEFT", prevContainer, "TOPLEFT", 10, -26)
    leftPane:SetPoint("BOTTOMRIGHT", prevContainer, "BOTTOMRIGHT", -268, 10)
    if KT.AddBackdrop then KT:AddBackdrop(leftPane, 0.03, 0.03, 0.04, 0.92) end
    if KT.AddBorder then KT:AddBorder(leftPane, 0, 0, 0, 1) end

    local leftShade = leftPane:CreateTexture(nil, "BORDER")
    leftShade:SetAllPoints()
    leftShade:SetColorTexture(0, 0, 0, 0.32)

    local headerBar = CreateFrame("Frame", nil, leftPane)
    headerBar:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 0, 0)
    headerBar:SetPoint("TOPRIGHT", leftPane, "TOPRIGHT", 0, 0)
    headerBar:SetHeight(54)

    local headerShade = headerBar:CreateTexture(nil, "BACKGROUND")
    headerShade:SetAllPoints()
    headerShade:SetColorTexture(0, 0, 0, 0.55)

    local previewPortrait = headerBar:CreateTexture(nil, "ARTWORK")
    previewPortrait:SetSize(38, 38)
    previewPortrait:SetPoint("TOPLEFT", headerBar, "TOPLEFT", 8, -8)

    local previewClassIcon = headerBar:CreateTexture(nil, "ARTWORK")
    previewClassIcon:SetSize(38, 38)
    previewClassIcon:SetPoint("TOPLEFT", headerBar, "TOPLEFT", 8, -8)

    local previewName = headerBar:CreateFontString(nil, "OVERLAY")
    previewName:SetPoint("TOPLEFT", previewPortrait, "TOPRIGHT", 10, -1)
    previewName:SetJustifyH("LEFT")
    previewName:SetWordWrap(false)

    local previewLevel = headerBar:CreateFontString(nil, "OVERLAY")
    previewLevel:SetPoint("TOPLEFT", previewName, "BOTTOMLEFT", 0, -2)
    previewLevel:SetJustifyH("LEFT")

    local previewSpecIcon = headerBar:CreateTexture(nil, "ARTWORK")
    previewSpecIcon:SetSize(18, 18)
    previewSpecIcon:SetPoint("LEFT", previewName, "RIGHT", 6, 0)

    local previewScoreLabel = headerBar:CreateFontString(nil, "OVERLAY")
    previewScoreLabel:SetPoint("TOPRIGHT", headerBar, "TOPRIGHT", -60, -8)
    previewScoreLabel:SetJustifyH("RIGHT")

    local previewScore = headerBar:CreateFontString(nil, "OVERLAY")
    previewScore:SetPoint("LEFT", previewScoreLabel, "RIGHT", 4, 0)
    previewScore:SetJustifyH("LEFT")

    local stageLine = leftPane:CreateTexture(nil, "ARTWORK")
    stageLine:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -1)
    stageLine:SetPoint("TOPRIGHT", headerBar, "BOTTOMRIGHT", 0, -1)
    stageLine:SetHeight(1)
    stageLine:SetColorTexture(1, 1, 1, 0.08)

    local stageGlow = leftPane:CreateTexture(nil, "ARTWORK")
    stageGlow:SetPoint("TOPLEFT", leftPane, "TOPLEFT", 20, -68)
    stageGlow:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", -20, 16)
    stageGlow:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
    KT:SetAccentVertexColor(stageGlow, 0.10)

    local previewStage = CreateFrame("Frame", nil, leftPane, "BackdropTemplate")
    previewStage:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 8, -8)
    previewStage:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", -8, 8)
    if previewStage.SetClipsChildren then
        previewStage:SetClipsChildren(true)
    end
    if KT.AddBorder then KT:AddBorder(previewStage, 0, 0, 0, 0) end

    local leftBG = previewStage:CreateTexture(nil, "BACKGROUND", nil, -8)
    leftBG:SetAllPoints()
    leftBG:SetTexture(previewTexturePath .. previewDefaultBackgroundFile)
    leftBG:SetTexCoord(0, 1, 0, 1)
    leftBG:SetVertexColor(1, 1, 1, 1)

    local previewStageShade = previewStage:CreateTexture(nil, "BACKGROUND", nil, -7)
    previewStageShade:SetAllPoints()
    previewStageShade:SetColorTexture(0, 0, 0, 0.18)

    local previewModelGlow = previewStage:CreateTexture(nil, "ARTWORK")
    previewModelGlow:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
    previewModelGlow:SetPoint("BOTTOM", previewStage, "BOTTOM", 0, 38)
    previewModelGlow:SetSize(150, 166)
    KT:SetAccentVertexColor(previewModelGlow, 0.12)

    local previewModelAura = previewStage:CreateTexture(nil, "ARTWORK")
    previewModelAura:SetTexture("Interface\\GLUES\\Models\\UI_Draenei\\GenericGlow64")
    previewModelAura:SetPoint("BOTTOM", previewStage, "BOTTOM", 0, 46)
    previewModelAura:SetSize(164, 182)
    previewModelAura:SetVertexColor(1, 1, 1, 0.06)

    local previewModel = CreateFrame("PlayerModel", nil, previewStage)
    previewModel:SetPoint("BOTTOM", previewStage, "BOTTOM", 0, 2)
    previewModel:SetSize(202, 216)

    local previewModelShade = previewStage:CreateTexture(nil, "ARTWORK")
    previewModelShade:SetTexture("Interface\\Buttons\\WHITE8X8")
    previewModelShade:SetPoint("BOTTOM", previewStage, "BOTTOM", 0, 6)
    previewModelShade:SetSize(120, 148)
    previewModelShade:SetColorTexture(0, 0, 0, 0.05)

    local previewFloor = previewStage:CreateTexture(nil, "ARTWORK")
    previewFloor:SetTexture("Interface\\Buttons\\WHITE8X8")
    previewFloor:SetPoint("BOTTOMLEFT", previewStage, "BOTTOMLEFT", 32, 26)
    previewFloor:SetPoint("BOTTOMRIGHT", previewStage, "BOTTOMRIGHT", -32, 26)
    previewFloor:SetHeight(1)
    previewFloor:SetColorTexture(1, 1, 1, 0.08)

    local previewSlots = {}
    local function CreatePreviewSlot(parent)
        local slot = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        slot:SetSize(30, 30)
        if KT.AddBackdrop then KT:AddBackdrop(slot, 0.03, 0.03, 0.04, 0.92) end
        if KT.AddBorder then KT:AddBorder(slot, 0.45, 0.32, 0.12, 0.95) end
        slot.Icon = slot:CreateTexture(nil, "ARTWORK")
        slot.Icon:SetPoint("TOPLEFT", 2, -2)
        slot.Icon:SetPoint("BOTTOMRIGHT", -2, 2)
        slot.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        slot.Ilvl = slot:CreateFontString(nil, "OVERLAY")
        slot.Ilvl:SetPoint("BOTTOM", slot, "TOP", 0, 2)
        slot.Ilvl:SetJustifyH("CENTER")
        previewSlots[#previewSlots + 1] = slot
        return slot
    end

    for i = 1, #PREVIEW_SLOT_IDS do
        CreatePreviewSlot(previewStage)
    end

    local statsPanel = CreateFrame("Frame", nil, prevContainer, "BackdropTemplate")
    statsPanel:SetPoint("TOPRIGHT", prevContainer, "TOPRIGHT", -10, -26)
    statsPanel:SetPoint("BOTTOMRIGHT", prevContainer, "BOTTOMRIGHT", -10, 10)
    statsPanel:SetWidth(248)
    if KT.AddBackdrop then KT:AddBackdrop(statsPanel, 0.04, 0.04, 0.05, 0.92) end
    if KT.AddBorder then KT:AddBorder(statsPanel, 0, 0, 0, 1) end
    local previewStatsTab = CreateFrame("Frame", nil, statsPanel, "BackdropTemplate")
    previewStatsTab:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 8, -8)
    previewStatsTab:SetPoint("TOPRIGHT", statsPanel, "TOP", -2, -8)
    previewStatsTab:SetHeight(22)
    if KT.AddBackdrop then KT:AddBackdrop(previewStatsTab, 0.04, 0.04, 0.05, 0.96) end
    if KT.AddAccentBorder then KT:AddAccentBorder(previewStatsTab, 0.85) end
    local previewStatsTabText = previewStatsTab:CreateFontString(nil, "OVERLAY")
    previewStatsTabText:SetPoint("CENTER")
    previewStatsTabText:SetFont(KT.FONT_PATH or STANDARD_TEXT_FONT, 10, "OUTLINE")
    previewStatsTabText:SetText(LText("Stats"))
    KT:SetAccentTextColor(previewStatsTabText, 1)

    local previewProgressTab = CreateFrame("Frame", nil, statsPanel, "BackdropTemplate")
    previewProgressTab:SetPoint("TOPLEFT", statsPanel, "TOP", 2, -8)
    previewProgressTab:SetPoint("TOPRIGHT", statsPanel, "TOPRIGHT", -8, -8)
    previewProgressTab:SetHeight(22)
    if KT.AddBackdrop then KT:AddBackdrop(previewProgressTab, 0.025, 0.025, 0.03, 0.88) end
    if KT.AddBorder then KT:AddBorder(previewProgressTab, 0.18, 0.18, 0.2, 0.9) end
    local previewProgressTabText = previewProgressTab:CreateFontString(nil, "OVERLAY")
    previewProgressTabText:SetPoint("CENTER")
    previewProgressTabText:SetFont(KT.FONT_PATH or STANDARD_TEXT_FONT, 10, "OUTLINE")
    previewProgressTabText:SetText(LText("Progress"))
    previewProgressTabText:SetTextColor(0.62, 0.62, 0.66, 1)

    local statsPanelBase = statsPanel:CreateTexture(nil, "BACKGROUND")
    statsPanelBase:SetAllPoints()
    statsPanelBase:SetColorTexture(0, 0, 0, 0.96)

    local statsPanelBG = statsPanel:CreateTexture(nil, "BACKGROUND", nil, 1)
    ApplyPreviewPanelTexture(statsPanelBG)
    LayoutPreviewPanelTexture(statsPanelBG, statsPanel)
    statsPanelBG:SetAlpha(1)
    statsPanel:HookScript("OnSizeChanged", function(panel)
        LayoutPreviewPanelTexture(statsPanelBG, panel)
    end)

    local statsPanelShade = statsPanel:CreateTexture(nil, "BACKGROUND", nil, 3)
    statsPanelShade:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 1, -1)
    statsPanelShade:SetPoint("BOTTOMRIGHT", statsPanel, "BOTTOMRIGHT", -1, 1)

    local statsPanelFill = statsPanel:CreateTexture(nil, "BACKGROUND", nil, 2)
    statsPanelFill:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 1, -1)
    statsPanelFill:SetPoint("BOTTOMRIGHT", statsPanel, "BOTTOMRIGHT", -1, 1)

    local statsPanelTopGlow = statsPanel:CreateTexture(nil, "BACKGROUND", nil, 4)
    statsPanelTopGlow:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 1, -1)
    statsPanelTopGlow:SetPoint("TOPRIGHT", statsPanel, "TOPRIGHT", -1, -1)

    local statsPanelLeftGlow = statsPanel:CreateTexture(nil, "BACKGROUND", nil, 5)
    statsPanelLeftGlow:SetPoint("TOPLEFT", statsPanel, "TOPLEFT", 1, -1)
    statsPanelLeftGlow:SetPoint("BOTTOMLEFT", statsPanel, "BOTTOMLEFT", 1, 1)

    local statsPanelBottomLine = statsPanel:CreateTexture(nil, "ARTWORK")
    statsPanelBottomLine:SetPoint("BOTTOMLEFT", statsPanel, "BOTTOMLEFT", 1, 1)
    statsPanelBottomLine:SetPoint("BOTTOMRIGHT", statsPanel, "BOTTOMRIGHT", -1, 1)
    statsPanelBottomLine:SetHeight(1)

    local elements = {}
    elements.itemHeaderStripe = statsPanel:CreateTexture(nil, "ARTWORK")
    elements.itemHeaderStripeRight = statsPanel:CreateTexture(nil, "ARTWORK")
    elements.itemHeaderText = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.itemValueText = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.itemPvPText = statsPanel:CreateFontString(nil, "OVERLAY")

    elements.attrHeaderStripe = statsPanel:CreateTexture(nil, "ARTWORK")
    elements.attrHeaderStripeRight = statsPanel:CreateTexture(nil, "ARTWORK")
    elements.attrHeaderText = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.attrLabel1 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.attrValue1 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.attrIcon1 = statsPanel:CreateTexture(nil, "OVERLAY")
    elements.attrLabel2 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.attrValue2 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.attrIcon2 = statsPanel:CreateTexture(nil, "OVERLAY")
    elements.attrLabel3 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.attrValue3 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.attrIcon3 = statsPanel:CreateTexture(nil, "OVERLAY")

    elements.enhHeaderStripe = statsPanel:CreateTexture(nil, "ARTWORK")
    elements.enhHeaderStripeRight = statsPanel:CreateTexture(nil, "ARTWORK")
    elements.enhHeaderText = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.enhLabel1 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.enhValue1 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.enhIcon1 = statsPanel:CreateTexture(nil, "OVERLAY")
    elements.enhLabel2 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.enhValue2 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.enhIcon2 = statsPanel:CreateTexture(nil, "OVERLAY")
    elements.enhLabel3 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.enhValue3 = statsPanel:CreateFontString(nil, "OVERLAY")
    elements.enhIcon3 = statsPanel:CreateTexture(nil, "OVERLAY")

    elements.btnStage = CreateFrame("Button", nil, prevContainer)
    elements.btnStage:SetAllPoints(previewStage)
    elements.btnIlvl = CreateFrame("Button", nil, prevContainer)
    elements.btnAttr = CreateFrame("Button", nil, prevContainer)
    elements.btnEnh = CreateFrame("Button", nil, prevContainer)

    UpdatePreview = function()
        local e = elements
        local itemHeaderStripe, itemHeaderStripeRight, itemHeaderText, itemValueText, itemPvPText = e.itemHeaderStripe, e.itemHeaderStripeRight, e.itemHeaderText, e.itemValueText, e.itemPvPText
        local attrHeaderStripe, attrHeaderStripeRight, attrHeaderText = e.attrHeaderStripe, e.attrHeaderStripeRight, e.attrHeaderText
        local attrLabel1, attrValue1, attrIcon1 = e.attrLabel1, e.attrValue1, e.attrIcon1
        local attrLabel2, attrValue2, attrIcon2 = e.attrLabel2, e.attrValue2, e.attrIcon2
        local attrLabel3, attrValue3, attrIcon3 = e.attrLabel3, e.attrValue3, e.attrIcon3
        local enhHeaderStripe, enhHeaderStripeRight, enhHeaderText = e.enhHeaderStripe, e.enhHeaderStripeRight, e.enhHeaderText
        local enhLabel1, enhValue1, enhIcon1 = e.enhLabel1, e.enhValue1, e.enhIcon1
        local enhLabel2, enhValue2, enhIcon2 = e.enhLabel2, e.enhValue2, e.enhIcon2
        local enhLabel3, enhValue3, enhIcon3 = e.enhLabel3, e.enhValue3, e.enhIcon3
        local btnStage, btnIlvl, btnAttr, btnEnh = e.btnStage, e.btnIlvl, e.btnAttr, e.btnEnh

        local statFont = FetchFont(db.statFont or db.charNameFont)
        local statSize = db.statFontSize or 11
        prevContainer:SetHeight(GetArmoryPreviewHeight(db))
        LayoutPreviewPanelTexture(statsPanelBG, statsPanel)

        local function LayoutPreviewRow(labelFS, valueFS, iconTex, topY, labelText, valueText, color, showLabel, iconID)
            labelFS:SetFont(statFont, statSize, "OUTLINE")
            valueFS:SetFont(statFont, statSize, "OUTLINE")
            labelFS:ClearAllPoints()
            valueFS:ClearAllPoints()
            iconTex:ClearAllPoints()

            if not showLabel then
                labelFS:Hide()
                valueFS:Hide()
                iconTex:Hide()
                return
            end

            labelFS:Show()
            valueFS:Show()
            
            valueFS:SetText(valueText)
            valueFS:SetPoint("RIGHT", statsPanel, "RIGHT", -10, topY)
            valueFS:SetJustifyH("RIGHT")
            valueFS:SetWidth(115)
            valueFS:ClearAllPoints()
            valueFS:SetPoint('TOPRIGHT', statsPanel, 'TOPRIGHT', -10, topY)
            
            if iconID then
                iconTex:SetTexture(iconID)
                iconTex:SetTexCoord(5/64, 59/64, 5/64, 59/64)
                iconTex:SetSize(14, 14)
                iconTex:SetPoint("LEFT", statsPanel, "LEFT", 10, topY - 1)
                iconTex:Show()
                iconTex:ClearAllPoints()
                iconTex:SetPoint('TOPLEFT', statsPanel, 'TOPLEFT', 10, topY + 1)
                labelFS:SetPoint("LEFT", iconTex, "RIGHT", 4, 1)
            else
                iconTex:Hide()
                labelFS:SetPoint("LEFT", statsPanel, "LEFT", 10, topY)
            end
            
            if not iconID then
                labelFS:ClearAllPoints()
                labelFS:SetPoint('TOPLEFT', statsPanel, 'TOPLEFT', 10, topY)
            end

            local inset = 10
            local columnGap = 15
            local iconOffset = iconTex:IsShown() and 18 or 0
            local labelWidth = statsPanel:GetWidth() - (inset * 2) - columnGap - 115 - iconOffset
            
            local maxChars = math.floor(labelWidth / 5.8)
            local function utf8_safe_truncate(str, limit)
                local len = string.len(str)
                local chars = 0
                local offset = 1
                while offset <= len and chars < limit do
                    local b = string.byte(str, offset)
                    if not b then break end
                    if b < 128 then offset = offset + 1
                    elseif b < 224 then offset = offset + 2
                    elseif b < 240 then offset = offset + 3
                    else offset = offset + 4 end
                    chars = chars + 1
                end
                if offset <= len then
                    chars = 0
                    local newOffset = 1
                    local ellipsisLimit = math.max(1, limit - 3)
                    while newOffset <= len and chars < ellipsisLimit do
                        local b = string.byte(str, newOffset)
                        if not b then break end
                        if b < 128 then newOffset = newOffset + 1
                        elseif b < 224 then newOffset = newOffset + 2
                        elseif b < 240 then newOffset = newOffset + 3
                        else newOffset = newOffset + 4 end
                        chars = chars + 1
                    end
                    return string.sub(str, 1, newOffset - 1) .. "..."
                end
                return str
            end
            
            labelFS:SetText(utf8_safe_truncate(labelText, maxChars))
            labelFS:SetWidth(labelWidth)
            labelFS:SetWordWrap(false)
            labelFS:SetNonSpaceWrap(false)
            labelFS:SetJustifyH("LEFT")
            labelFS:SetMaxLines(1)

            labelFS:SetTextColor(color.r, color.g, color.b, color.a or 1)
            valueFS:SetTextColor(color.r, color.g, color.b, color.a or 1)
        end

        local nameText = UnitName("player") or LText("Mew")
        local _, class = UnitClass("player")
        local classColor = class and C_ClassColor.GetClassColor(class)
        local nameFont = FetchFont(db.charNameFont)
        previewName:SetFont(nameFont, db.charNameSize or 16, db.charNameOutline or "OUTLINE")
        previewName:SetText(nameText)
        if classColor then
            previewName:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            previewName:SetTextColor(1, 1, 1)
        end

        local levelFont = FetchFont(db.charLevelFont or db.charNameFont)
        previewLevel:SetFont(levelFont, db.charLevelSize or 12, db.charLevelOutline or "OUTLINE")
        previewLevel:SetText((LEVEL or "Level") .. " 90")
        previewLevel:SetTextColor(1, 1, 1, 1)

        if db.showPortrait then
            SetPortraitTexture(previewPortrait, "player")
            previewPortrait:Show()
            previewClassIcon:Hide()
        else
            if class and _G.CLASS_ICON_TCOORDS[class] then
                previewClassIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
                previewClassIcon:SetTexCoord(unpack(_G.CLASS_ICON_TCOORDS[class]))
                previewClassIcon:Show()
            else
                previewClassIcon:Hide()
            end
            previewPortrait:Hide()
        end

        local currentSpec = GetSpecialization and GetSpecialization()
        if currentSpec then
            local _, _, _, icon = GetSpecializationInfo(currentSpec)
            if icon then
                previewSpecIcon:SetTexture(icon)
                previewSpecIcon:Show()
            else
                previewSpecIcon:Hide()
            end
        else
            previewSpecIcon:Hide()
        end

        local function GetPreviewPrimaryStatInfo()
            local spec = GetSpecialization and GetSpecialization()
            local _, classToken = UnitClass("player")
            local statID

            if classToken == "HUNTER" or classToken == "ROGUE" or classToken == "DEMONHUNTER" then
                statID = 2
            elseif classToken == "MAGE" or classToken == "WARLOCK" or classToken == "PRIEST" or classToken == "EVOKER" then
                statID = 4
            elseif classToken == "WARRIOR" or classToken == "DEATHKNIGHT" then
                statID = 1
            elseif classToken == "PALADIN" then
                statID = (spec == 1) and 4 or 1
            elseif classToken == "SHAMAN" then
                statID = (spec == 2) and 2 or 4
            elseif classToken == "MONK" then
                statID = (spec == 2) and 4 or 2
            elseif classToken == "DRUID" then
                statID = (spec == 1 or spec == 4) and 4 or 2
            end

            if not statID then
                return nil, nil, nil
            end

            local baseValue, effectiveValue = SafePreviewNumberCall(UnitStat, "player", statID)
            return statID, _G["SPELL_STAT" .. statID .. "_NAME"], effectiveValue or baseValue or 0
        end

        local function GetPreviewSlotData(slotID)
            local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", slotID)
            local link = GetInventoryItemLink and GetInventoryItemLink("player", slotID)
            local itemLevel = nil

            if slotID and ItemLocation and C_Item and C_Item.DoesItemExist and C_Item.GetCurrentItemLevel then
                local itemLoc = ItemLocation:CreateFromEquipmentSlot(slotID)
                if itemLoc and C_Item.DoesItemExist(itemLoc) then
                    itemLevel = C_Item.GetCurrentItemLevel(itemLoc)
                end
            end

            if (not itemLevel or itemLevel == 0) and link and GetDetailedItemLevelInfo then
                itemLevel = GetDetailedItemLevelInfo(link)
            end

            return icon, (itemLevel and itemLevel > 0) and tostring(math.floor(itemLevel)) or ""
        end

        local scoreFont = FetchFont(db.scoreFont)
        local scoreLabel = (db.scoreType == "PVP") and "PvP" or "M+"
        local scoreValue = 3382
        local scoreColor = { r = 1, g = 0.6, b = 0.2, a = 1 }

        if db.scoreType == "PVP" then
            local maxRating = 0
            if GetPersonalRatedInfo then
                for _, bracket in ipairs({ 1, 2, 4 }) do
                    local rating = select(1, GetPersonalRatedInfo(bracket))
                    if rating and rating > maxRating then
                        maxRating = rating
                    end
                end
            end
            if C_PvP and C_PvP.GetSoloShufflePersonalRatedInfo then
                local shuffleRating = C_PvP.GetSoloShufflePersonalRatedInfo()
                if shuffleRating and shuffleRating > maxRating then
                    maxRating = shuffleRating
                end
            end
            scoreValue = maxRating > 0 and maxRating or 0
        elseif C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
            scoreValue = C_ChallengeMode.GetOverallDungeonScore() or 0
            if C_ChallengeMode.GetDungeonScoreRarityColor then
                local rarityColor = C_ChallengeMode.GetDungeonScoreRarityColor(scoreValue)
                if rarityColor then
                    scoreColor = {
                        r = rarityColor.r or 1,
                        g = rarityColor.g or 0.6,
                        b = rarityColor.b or 0.2,
                        a = rarityColor.a or 1,
                    }
                end
            end
        end

        previewScoreLabel:SetFont(scoreFont, 11, db.scoreOutline or "OUTLINE")
        previewScoreLabel:SetText(scoreLabel)
        previewScoreLabel:SetTextColor(0.78, 0.78, 0.78, 1)
        previewScore:SetFont(scoreFont, db.scoreSize or 20, db.scoreOutline or "OUTLINE")
        previewScore:SetText(tostring(math.floor(scoreValue or 0)))
        previewScore:SetTextColor(scoreColor.r, scoreColor.g, scoreColor.b, scoreColor.a or 1)

        local backgroundFile = ResolvePreviewBackgroundFile(db.backgroundType)
        if backgroundFile then
            local ok, loaded = pcall(leftBG.SetTexture, leftBG, previewTexturePath .. backgroundFile)
            if ok and loaded ~= false then
                leftBG:SetTexCoord(0, 1, 0, 1)
                leftBG:SetVertexColor(1, 1, 1, 1)
            elseif classColor then
                leftBG:SetTexture("Interface\\Buttons\\WHITE8X8")
                leftBG:SetVertexColor(classColor.r * 0.24, classColor.g * 0.24, classColor.b * 0.24, 1)
            end
        else
            leftBG:SetTexture("Interface\\Buttons\\WHITE8X8")
            if classColor then
                leftBG:SetVertexColor(classColor.r * 0.24, classColor.g * 0.24, classColor.b * 0.24, 1)
            else
                leftBG:SetVertexColor(0.08, 0.08, 0.10, 1)
            end
        end

        if classColor then
            previewModelAura:SetVertexColor(classColor.r, classColor.g, classColor.b, 0.10)
            previewModelShade:SetColorTexture(classColor.r * 0.18, classColor.g * 0.18, classColor.b * 0.18, 0.10)
        else
            previewModelAura:SetVertexColor(1, 1, 1, 0.06)
            previewModelShade:SetColorTexture(1, 1, 1, 0.04)
        end

        if previewModel and previewModel.SetUnit then
            if previewModel.ClearModel then
                pcall(previewModel.ClearModel, previewModel)
            end
            pcall(previewModel.SetUnit, previewModel, "player")
            if previewModel.SetCamDistanceScale then
                pcall(previewModel.SetCamDistanceScale, previewModel, 1.18)
            end
            if previewModel.SetPortraitZoom then
                pcall(previewModel.SetPortraitZoom, previewModel, 0)
            end
            if previewModel.SetFacing then
                pcall(previewModel.SetFacing, previewModel, 0.25)
            end
            if previewModel.SetPosition then
                pcall(previewModel.SetPosition, previewModel, 0, 0, -0.08)
            end
        end

        local previewSlotSize = 31
        local previewIlvlColor = db.avgIlvlColor or db.itemLevelColor or ARMORY_ILVL_PURPLE
        local leftOffsets = { -10, -43, -76, -109, -142, -175, -208 }
        local rightOffsets = { -10, -43, -76, -109, -142, -175, -208, -241 }
        local bottomOffsets = { -21, 21 }
        local leftCount = #PREVIEW_LEFT_SLOT_IDS
        local rightCount = #PREVIEW_RIGHT_SLOT_IDS
        local ilvlFont = FetchFont(db.ilvlFont or db.charNameFont)

        for index, slot in ipairs(previewSlots) do
            slot:ClearAllPoints()
            slot:SetSize(previewSlotSize, previewSlotSize)
            local slotID = PREVIEW_SLOT_IDS[index]
            local icon, itemLevelText = GetPreviewSlotData(slotID)
            if icon then
                slot.Icon:SetTexture(icon)
                slot.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                slot.Icon:SetTexture(PREVIEW_EMPTY_SLOT_TEXTURES[slotID])
                slot.Icon:SetTexCoord(0, 1, 0, 1)
            end
            slot.Icon:Show()
            slot.Ilvl:SetFont(ilvlFont, 9, "OUTLINE")
            slot.Ilvl:SetTextColor(previewIlvlColor.r, previewIlvlColor.g, previewIlvlColor.b, 1)
            slot.Ilvl:SetText(itemLevelText)

            if index <= leftCount then
                slot:SetPoint("TOPLEFT", previewStage, "TOPLEFT", 14, leftOffsets[index])
            elseif index <= leftCount + rightCount then
                local rIndex = index - leftCount
                slot:SetPoint("TOPRIGHT", previewStage, "TOPRIGHT", -14, rightOffsets[rIndex])
            else
                local bIndex = index - leftCount - rightCount
                slot:SetPoint("BOTTOM", previewStage, "BOTTOM", bottomOffsets[bIndex] or 0, 12)
            end
        end

        statsPanelBase:SetColorTexture(0, 0, 0, 0.96)
        ApplyPreviewPanelTexture(statsPanelBG)
        LayoutPreviewPanelTexture(statsPanelBG, statsPanel)
        statsPanelFill:SetColorTexture(0, 0, 0, 0)
        statsPanelShade:SetColorTexture(0, 0, 0, 0)
        statsPanelTopGlow:SetColorTexture(0, 0, 0, 0)
        statsPanelLeftGlow:SetColorTexture(0, 0, 0, 0)
        statsPanelBottomLine:SetColorTexture(0, 0, 0, 0)

        local headerFont = FetchFont(db.headerFont or db.statFont or db.charNameFont)
        local headerSize = statSize + 2
        local headerOutline = db.headerOutline or "OUTLINE"
        local sectionGap = math.max(8, math.floor((statSize or 14) * 0.77))
        local previewTabsInset = 30
        local pvpExtraHeight = GetPvPIlvlExtraHeight(db)
        local ilvlSectionOffset = previewTabsInset + ((db.showAvgIlvl ~= false) and sectionGap or 0) + pvpExtraHeight
        local enhancementSectionOffset = ilvlSectionOffset + sectionGap

        local headerColor = GetUnifiedHeaderColor()
        local attrHeaderColor = headerColor
        local enhHeaderColor = headerColor
        headerColor = db.ilvlHeaderColor or ARMORY_HEADER_GOLD
        attrHeaderColor = db.attrHeaderColor or ARMORY_HEADER_ATTRIBUTE
        enhHeaderColor = db.enhHeaderColor or ARMORY_HEADER_SECONDARY

        itemHeaderStripe:Hide()
        itemHeaderStripeRight:Hide()
        attrHeaderStripe:Hide()
        attrHeaderStripeRight:Hide()
        enhHeaderStripe:Hide()
        enhHeaderStripeRight:Hide()

        itemHeaderText:ClearAllPoints()
        itemHeaderText:SetPoint("TOP", statsPanel, "TOP", 0, -42)
        itemHeaderText:SetJustifyH("CENTER")
        itemHeaderText:SetFont(headerFont, headerSize, headerOutline)
        itemHeaderText:SetText(LText("Item Level"))
        itemHeaderText:SetTextColor(headerColor.r, headerColor.g, headerColor.b, 1)
        LayoutPreviewHeaderBars(itemHeaderStripe, itemHeaderStripeRight, itemHeaderText, statsPanel, headerColor)

        itemValueText:ClearAllPoints()
        itemValueText:SetPoint("TOP", itemHeaderText, "BOTTOM", 0, -4)
        itemValueText:SetJustifyH("CENTER")
        local avgColor = db.avgIlvlColor or db.itemLevelColor or ARMORY_ILVL_PURPLE
        itemValueText:SetFont(FetchFont(db.avgIlvlFont or db.charNameFont), db.avgIlvlFontSize or 18, db.avgIlvlOutline or "OUTLINE")
        itemValueText:SetTextColor(avgColor.r, avgColor.g, avgColor.b, avgColor.a or 1)
        local avgVal, avgEquipped, avgPvp = SafePreviewNumberCall(GetAverageItemLevel)
        local avgText = db.avgIlvlDecimals and string.format("%.1f", avgVal or 0) or tostring(math.floor((avgVal or 0) + 0.0001))
        local avgEquippedText = db.avgIlvlDecimals and string.format("%.1f", avgEquipped or 0) or tostring(math.floor((avgEquipped or 0) + 0.0001))
        if db.showAvgIlvl ~= false then
            itemValueText:SetText(avgEquippedText .. " / " .. avgText)
            itemValueText:Show()
            itemHeaderText:Show()

            itemPvPText:ClearAllPoints()
            itemPvPText:SetPoint("TOP", itemValueText, "BOTTOM", tonumber(db.avgIlvlPvPOffsetX) or 0, tonumber(db.avgIlvlPvPOffsetY) or -2)
            itemPvPText:SetJustifyH("CENTER")
            itemPvPText:SetFont(FetchFont(db.avgIlvlPvPFont or db.avgIlvlFont or db.statFont), tonumber(db.avgIlvlPvPFontSize) or 10, db.avgIlvlPvPOutline or "OUTLINE")
            local pvpColor = db.avgIlvlPvPColor or ARMORY_PVP_ILVL_COLOR
            itemPvPText:SetTextColor(pvpColor.r or 0, pvpColor.g or 0.5, pvpColor.b or 1, pvpColor.a or 1)
            if avgPvp and avgPvp > 0 and db.showAvgIlvlPvP ~= false then
                local pvpValue = db.avgIlvlPvPDecimals and string.format("%.1f", avgPvp) or tostring(math.floor(avgPvp))
                itemPvPText:SetText(db.avgIlvlPvPShowLabel == false and pvpValue or ("PvP: " .. pvpValue))
                itemPvPText:Show()
            else
                itemPvPText:Hide()
            end
        else
            itemValueText:Hide()
            itemHeaderText:Hide()
            itemPvPText:Hide()
        end

        attrHeaderText:ClearAllPoints()
        attrHeaderText:SetPoint("TOP", statsPanel, "TOP", 0, ((db.showAvgIlvl ~= false) and -62 or -18) - ilvlSectionOffset)
        attrHeaderText:SetJustifyH("CENTER")
        attrHeaderText:SetFont(headerFont, headerSize, headerOutline)
        attrHeaderText:SetText(_G["STAT_CATEGORY_ATTRIBUTES"] or LText("Attributes"))
        attrHeaderText:SetTextColor(attrHeaderColor.r, attrHeaderColor.g, attrHeaderColor.b, 1)
        LayoutPreviewHeaderBars(attrHeaderStripe, attrHeaderStripeRight, attrHeaderText, statsPanel, attrHeaderColor)

        local attrColor = db.attrColor or { r = 1, g = 1, b = 1, a = 1 }
        local primaryStatID, primaryStatLabel, primaryStatValue = GetPreviewPrimaryStatInfo()
        local primaryStatColor = attrColor
        local showPrimaryLabel = true
        if primaryStatID == 1 then
            primaryStatColor = db.strengthColor or attrColor
            showPrimaryLabel = db.showStrengthLabel ~= false
        elseif primaryStatID == 2 then
            primaryStatColor = db.agilityColor or attrColor
            showPrimaryLabel = db.showAgilityLabel ~= false
        elseif primaryStatID == 4 then
            primaryStatColor = db.intellectColor or attrColor
            showPrimaryLabel = db.showIntellectLabel ~= false
        end
        local primaryIcon = "Interface\\Icons\\spell_holy_magicalsentry"
        if primaryStatID == 1 then primaryIcon = 132401
        elseif primaryStatID == 2 then primaryIcon = 135133 end

        local staminaBase, staminaEffective = SafePreviewNumberCall(UnitStat, "player", 3)
        local _, effectiveArmor = SafePreviewNumberCall(UnitArmor, "player")
        LayoutPreviewRow(
            attrLabel1, attrValue1, attrIcon1,
            ((db.showAvgIlvl ~= false) and -82 or -38) - ilvlSectionOffset,
            primaryStatLabel or (_G["SPELL_STAT4_NAME"] or LText("Intellect")),
            FormatPreviewNumber(primaryStatValue),
            primaryStatColor,
            showPrimaryLabel,
            primaryIcon
        )
        LayoutPreviewRow(
            attrLabel2, attrValue2, attrIcon2,
            ((db.showAvgIlvl ~= false) and -106 or -62) - ilvlSectionOffset,
            _G["SPELL_STAT3_NAME"] or LText("Stamina"),
            FormatPreviewNumber(staminaEffective or staminaBase),
            db.staminaColor or attrColor,
            db.showStaminaLabel ~= false,
            1386545
        )
        LayoutPreviewRow(
            attrLabel3, attrValue3, attrIcon3,
            ((db.showAvgIlvl ~= false) and -130 or -86) - ilvlSectionOffset,
            _G["STAT_ARMOR"] or LText("Armor"),
            FormatPreviewNumber(effectiveArmor),
            db.armorColor or attrColor,
            db.showArmorLabel ~= false,
            GetPreviewSpellTexture(74001)
        )

        enhHeaderText:ClearAllPoints()
        enhHeaderText:SetPoint("TOP", statsPanel, "TOP", 0, ((db.showAvgIlvl ~= false) and -148 or -104) - enhancementSectionOffset)
        enhHeaderText:SetJustifyH("CENTER")
        enhHeaderText:SetFont(headerFont, headerSize, headerOutline)
        enhHeaderText:SetText(_G["STAT_CATEGORY_ENHANCEMENTS"] or LText("Enhancements"))
        enhHeaderText:SetTextColor(enhHeaderColor.r, enhHeaderColor.g, enhHeaderColor.b, 1)
        LayoutPreviewHeaderBars(enhHeaderStripe, enhHeaderStripeRight, enhHeaderText, statsPanel, enhHeaderColor)

        local secondaryMode = db.statFormatMode or "BOTH"
        local useColor = db.colorStats ~= false
        local enhancementFallback = db.enhColor or db.enchantColor or ARMORY_ENHANCEMENT_COLOR
        local critColor = useColor and (db.critColor or enhancementFallback) or { r = 1, g = 1, b = 1, a = 1 }
        local hasteColor = useColor and (db.hasteColor or enhancementFallback) or { r = 1, g = 1, b = 1, a = 1 }
        local masteryColor = useColor and (db.masteryColor or enhancementFallback) or { r = 1, g = 1, b = 1, a = 1 }
        local crit = SafePreviewNumberCall(GetCritChance) or 0
        local critRating = CR_CRIT_MELEE and SafePreviewNumberCall(GetCombatRating, CR_CRIT_MELEE) or 0
        local haste = GetPreviewHastePercent()
        local hasteRating = CR_HASTE_MELEE and SafePreviewNumberCall(GetCombatRating, CR_HASTE_MELEE) or 0
        local mastery = SafePreviewNumberCall(GetMasteryEffect) or 0
        local masteryRating = CR_MASTERY and SafePreviewNumberCall(GetCombatRating, CR_MASTERY) or 0
        local critValue = FormatPreviewSecondaryValue(secondaryMode, crit, critRating)
        local hasteValue = FormatPreviewSecondaryValue(secondaryMode, haste, hasteRating)
        local masteryValue = FormatPreviewSecondaryValue(secondaryMode, mastery, masteryRating)
        LayoutPreviewRow(
            enhLabel1, enhValue1, enhIcon1,
            ((db.showAvgIlvl ~= false) and -168 or -124) - enhancementSectionOffset,
            _G["STAT_CRITICAL_STRIKE"] or LText("Crit"),
            critValue,
            critColor,
            db.showCritLabel ~= false,
            GetPreviewSpellTexture(143610)
        )
        LayoutPreviewRow(
            enhLabel2, enhValue2, enhIcon2,
            ((db.showAvgIlvl ~= false) and -192 or -148) - enhancementSectionOffset,
            _G["STAT_HASTE"] or LText("Haste"),
            hasteValue,
            hasteColor,
            db.showHasteLabel ~= false,
            GetPreviewSpellTexture(143618)
        )
        LayoutPreviewRow(
            enhLabel3, enhValue3, enhIcon3,
            ((db.showAvgIlvl ~= false) and -216 or -172) - enhancementSectionOffset,
            _G["STAT_MASTERY"] or LText("Mastery"),
            masteryValue,
            masteryColor,
            db.showMasteryLabel ~= false,
            "Interface\\Icons\\spell_arcane_prismaticcloak"
        )
        
        if db.showAvgIlvl ~= false then
            btnIlvl:SetPoint("TOP", itemHeaderText, "TOP", 0, 10)
            btnIlvl:SetSize(228, 60 + pvpExtraHeight)
            btnIlvl:Show()
        else
            btnIlvl:Hide()
        end
        btnAttr:SetPoint("TOP", attrHeaderText, "TOP", 0, 10)
        btnAttr:SetSize(228, 90)
        btnEnh:SetPoint("TOP", enhHeaderText, "TOP", 0, 10)
        btnEnh:SetSize(228, 90)
    end

    UpdatePreview()
    y = y + prevContainer:GetHeight() + 36

    local cols = BeginOptionBlocks(sc, y)

    AddOptionBlock(cols, "left", "General", function(container)
        local by = 0
        _, h = W:Toggle(container, "Enable Module",  -by, function() return db.enable end, function(v) db.enable=v; Reload() end); by = by + h
        _, h = W:Button(container, LText("Restore Defaults"), -by, function()
            KT.db.profile.armory = nil
            ReloadUI()
        end, "FULL", true, LText("RESET_CONFIRM_TEXT")); by = by + h
        _, h = W:Slider(container,  "Frame Scale",   -by, function() return db.scale end,  function(v) db.scale=v;  Refresh() end, 0.6, 1.6, 0.05); by = by + h
        _, h = W:Dropdown(container, "Background",   -by, {["CLASS"]="Class (Automatic)",["SPACE"]="Space / Cosmos",["CASTLE"]="Castle (Alliance)",["EMPIRE"]="Empire (Horde)",["KYRIAN"]="Bastion (Kyrian)",["NECRO"]="Necrolords",["NIGHTFAE"]="Night Fae",["VENTHYR"]="Venthyr",["DK"]="Death Knight",["HUNTER"]="Hunter",["MAGE"]="Mage",["WARRIOR"]="Warrior",["ROGUE"]="Rogue",["DRUID"]="Druid",["SHAMAN"]="Shaman",["PRIEST"]="Priest",["WARLOCK"]="Warlock",["PALADIN"]="Paladin",["MONK"]="Monk",["DH"]="Demon Hunter",["EVOKER"]="Evoker"},
            function() return db.backgroundType end, function(v) db.backgroundType=v; Refresh() end); by = by + h
        _, h = W:Toggle(container, "Show 2D Portrait",-by, function() return db.showPortrait end, function(v) db.showPortrait=v; Refresh() end); by = by + h
        _, h = W:Dropdown(container, "Stat Values Format", -by, {["NUMERIC"]="Numeric only (e.g. 3000)", ["PERCENT"]="Percentage only (e.g. 25%)", ["BOTH"]="Both (e.g. 3000 (25%))"},
            function() return db.statFormatMode or "BOTH" end, function(v) db.statFormatMode=v; Refresh() end); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", "Header Fonts", function(container)
        local by = 0
        _, h = W:Dropdown(container, "Name Font",    -by, GetFontValues, function() return db.charNameFont end,  function(v) db.charNameFont=v;  RefreshH() end); by = by + h
        _, h = W:Slider(container,  "Name Size",     -by, function() return db.charNameSize end,                 function(v) db.charNameSize=v;  RefreshH() end, 10, 30, 1); by = by + h
        _, h = W:Dropdown(container, "Score Type",   -by, {["M+"]="Mythic+",["PVP"]="PvP"},
            function() return db.scoreType end, function(v) db.scoreType=v; RefreshH() end); by = by + h
        _, h = W:Dropdown(container, "Score Font",   -by, GetFontValues, function() return db.scoreFont end,     function(v) db.scoreFont=v;     RefreshH() end); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", "Enchants", function(container)
        local by = 0
        _, h = W:Toggle(container, "Show Enchants", -by, function() return db.showEnchant end, function(v) db.showEnchant=v; Refresh() end); by = by + h
        _, h = W:Slider(container,  "Size",         -by, function() return db.enchantSize end, function(v) db.enchantSize=v; Refresh() end, 8, 20, 1); by = by + h
        _, h = W:Dropdown(container, "Font",         -by, GetFontValues, function() return db.enchantFont end, function(v) db.enchantFont=v; Refresh() end); by = by + h
        _, h = W:ColorSwatch(container, "Color",     -by,
            function() local c=db.enchantColor; return c.r,c.g,c.b,c.a end,
            function(r,g,b,a) db.enchantColor={r=r,g=g,b=b,a=a}; Refresh() end, true); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", "Stat Labels", function(container)
        local by = 0
        local toggles = {
            { key = "showStrengthLabel", label = "Strength Label" },
            { key = "showAgilityLabel", label = "Agility Label" },
            { key = "showIntellectLabel", label = "Intellect Label" },
            { key = "showStaminaLabel", label = "Stamina Label" },
            { key = "showArmorLabel", label = "Armor Label" },
            { key = "showCritLabel", label = "Crit Label" },
            { key = "showHasteLabel", label = "Haste Label" },
            { key = "showMasteryLabel", label = "Mastery Label" },
            { key = "showVersatilityLabel", label = "Versatility Label" },
            { key = "showLeechLabel", label = "Leech Label" },
            { key = "showAvoidanceLabel", label = "Avoidance Label" },
            { key = "showSpeedLabel", label = "Speed Label" },
            { key = "showDodgeLabel", label = "Dodge Label" },
            { key = "showParryLabel", label = "Parry Label" },
            { key = "showBlockLabel", label = "Block Label" },
        }
        for _, entry in ipairs(toggles) do
            _, h = W:Toggle(container, entry.label, -by,
                function() return db[entry.key] ~= false end,
                function(v) db[entry.key] = v; Refresh() end); by = by + h
        end
        return by
    end)

    AddOptionBlock(cols, "right", "Item Level", function(container)
        local by = 0
        _, h = W:Toggle(container, "Show iLvl",          -by, function() return db.showIlvl end,        function(v) db.showIlvl=v;        Refresh() end); by = by + h
        _, h = W:Slider(container,  "Size",              -by, function() return db.ilvlSize end,        function(v) db.ilvlSize=v;        Refresh() end, 8, 24, 1); by = by + h
        _, h = W:Toggle(container, "Color by Quality",   -by, function() return db.ilvlColorByRarity end, function(v) db.ilvlColorByRarity=v; Refresh() end); by = by + h
        _, h = W:Toggle(container, "Show Average iLvl",  -by, function() return db.showAvgIlvl end,     function(v) db.showAvgIlvl=v;     Refresh() end); by = by + h
        _, h = W:Toggle(container, "Show Decimals",      -by, function() return db.avgIlvlDecimals end, function(v) db.avgIlvlDecimals=v; Refresh() end); by = by + h
        _, h = W:ColorSwatch(container, "Avg iLvl Color",-by,
            function() local c=db.avgIlvlColor; return c.r,c.g,c.b,c.a end,
            function(r,g,b,a) db.avgIlvlColor={r=r,g=g,b=b,a=a}; Refresh() end, true); by = by + h
        _, h = W:ColorSwatch(container, "Section Color",-by,
            function() local c=db.itemLevelColor or db.avgIlvlColor; return c.r,c.g,c.b,c.a end,
            function(r,g,b,a) db.itemLevelColor={r=r,g=g,b=b,a=a}; Refresh() end, true); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "PvP Item Level", function(container)
        local by = 0
        _, h = W:Toggle(container, "Show PvP iLvl", -by,
            function() return db.showAvgIlvlPvP ~= false end,
            function(v) db.showAvgIlvlPvP = v; Refresh() end); by = by + h
        _, h = W:Toggle(container, "Show PvP Label", -by,
            function() return db.avgIlvlPvPShowLabel ~= false end,
            function(v) db.avgIlvlPvPShowLabel = v; Refresh() end); by = by + h
        _, h = W:Toggle(container, "Show Decimals", -by,
            function() return db.avgIlvlPvPDecimals == true end,
            function(v) db.avgIlvlPvPDecimals = v; Refresh() end); by = by + h
        _, h = W:Dropdown(container, "Font", -by, GetFontValues,
            function() return db.avgIlvlPvPFont or db.avgIlvlFont or db.statFont end,
            function(v) db.avgIlvlPvPFont = v; Refresh() end); by = by + h
        _, h = W:Slider(container, "Size", -by,
            function() return tonumber(db.avgIlvlPvPFontSize) or 10 end,
            function(v) db.avgIlvlPvPFontSize = v; Refresh() end, 8, 32, 1); by = by + h
        _, h = W:Dropdown(container, "Outline", -by,
            { NONE = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick Outline" },
            function() return db.avgIlvlPvPOutline or "OUTLINE" end,
            function(v) db.avgIlvlPvPOutline = v; Refresh() end,
            { "NONE", "OUTLINE", "THICKOUTLINE" }); by = by + h
        _, h = W:ColorSwatch(container, "Color", -by,
            function() local c = db.avgIlvlPvPColor or ARMORY_PVP_ILVL_COLOR; return c.r, c.g, c.b, c.a end,
            function(r,g,b,a) db.avgIlvlPvPColor = {r=r,g=g,b=b,a=a}; Refresh() end, true); by = by + h
        _, h = W:Slider(container, "X Offset", -by,
            function() return tonumber(db.avgIlvlPvPOffsetX) or 0 end,
            function(v) db.avgIlvlPvPOffsetX = v; Refresh() end, -40, 40, 1); by = by + h
        _, h = W:Slider(container, "Y Offset", -by,
            function() return tonumber(db.avgIlvlPvPOffsetY) or -2 end,
            function(v) db.avgIlvlPvPOffsetY = v; Refresh() end, -30, 20, 1); by = by + h
        return by
    end)
    AddOptionBlock(cols, "right", "Character Stats", function(container)
        local by = 0
        _, h = W:Toggle(container, "Color Stats", -by, function() return db.colorStats end, function(v) db.colorStats=v; Refresh() end); by = by + h
        _, h = W:Toggle(container, "Color Stat Values", -by, function() return db.colorStatValues ~= false end, function(v) db.colorStatValues=v; Refresh() end); by = by + h
        _, h = W:ColorSwatch(container, "Stat Value Color", -by,
            function() local c = db.statValueColor or {r=1, g=1, b=1, a=1}; return c.r, c.g, c.b, c.a end,
            function(r,g,b,a) db.statValueColor={r=r, g=g, b=b, a=a}; Refresh() end, true); by = by + h
        _, h = W:Dropdown(container, "Panel Texture", -by, GetBackgroundValues,
            function() return db.statsTexture end, function(v) db.statsTexture=v; Refresh() end); by = by + h
        _, h = W:Dropdown(container, "Stat Font", -by, GetFontValues,
            function() return db.statFont end, function(v) db.statFont=v; Refresh() end); by = by + h
        _, h = W:Slider(container, "Font Size", -by, function() return db.statFontSize end, function(v) db.statFontSize=v; Refresh() end, 8, 24, 1); by = by + h
        _, h = W:Slider(container, "Spacing",   -by, function() return math.max(0, tonumber(db.statSpacing) or 0) end,  function(v) db.statSpacing=math.max(0, tonumber(v) or 0);  Refresh() end, 0, 10, 1); by = by + h
        _, h = W:Dropdown(container, "Secondary Stats", -by,
            { PERCENT = "Percent", NUMERIC = "Full Value", BOTH = "Both" },
            function() return db.statFormatMode or "BOTH" end,
            function(v) db.statFormatMode = v; Refresh() end,
            { "PERCENT", "NUMERIC", "BOTH" }); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "Section Colors", function(container)
        local by = 0
        _, h = W:ColorSwatch(container, "Attributes", -by,
            function() local c = db.attrColor; return c.r, c.g, c.b, c.a end,
            function(r, g, b, a)
                local color = { r = r, g = g, b = b, a = a }
                db.attrColor = color
                db.strengthColor = { r = r, g = g, b = b, a = a }
                db.agilityColor = { r = r, g = g, b = b, a = a }
                db.intellectColor = { r = r, g = g, b = b, a = a }
                db.staminaColor = { r = r, g = g, b = b, a = a }
                db.armorColor = { r = r, g = g, b = b, a = a }
                Refresh()
            end, true); by = by + h
        _, h = W:ColorSwatch(container, "Enhancements", -by,
            function() local c = db.enhColor or db.enchantColor; return c.r, c.g, c.b, c.a end,
            function(r, g, b, a)
                local color = { r = r, g = g, b = b, a = a }
                db.enhColor = color
                db.enchantColor = { r = r, g = g, b = b, a = a }
                db.critColor = { r = r, g = g, b = b, a = a }
                db.hasteColor = { r = r, g = g, b = b, a = a }
                db.masteryColor = { r = r, g = g, b = b, a = a }
                db.versatilityColor = { r = r, g = g, b = b, a = a }
                db.leechColor = { r = r, g = g, b = b, a = a }
                db.avoidanceColor = { r = r, g = g, b = b, a = a }
                db.speedColor = { r = r, g = g, b = b, a = a }
                db.dodgeColor = { r = r, g = g, b = b, a = a }
                db.parryColor = { r = r, g = g, b = b, a = a }
                db.blockColor = { r = r, g = g, b = b, a = a }
                Refresh()
            end, true); by = by + h
        return by
    end)

    AddOptionBlock(cols, "right", "Individual Stat Colors", function(container)
        local by = 0
        local statColors = {
            {k="strengthColor",     l="Strength"     }, {k="agilityColor",      l="Agility"     },
            {k="intellectColor",    l="Intellect"    }, {k="staminaColor",       l="Stamina"     },
            {k="armorColor",        l="Armor"        }, {k="critColor",          l="Crit Strike" },
            {k="hasteColor",        l="Haste"        }, {k="masteryColor",       l="Mastery"     },
            {k="versatilityColor",  l="Versatility"  }, {k="leechColor",         l="Leech"       },
            {k="avoidanceColor",    l="Avoidance"    }, {k="speedColor",         l="Speed"       },
            {k="dodgeColor",        l="Dodge"        }, {k="parryColor",         l="Parry"       },
            {k="blockColor",        l="Block"        },
        }
        for _, sc2 in ipairs(statColors) do
            local k = sc2.k
            _, h = W:ColorSwatch(container, sc2.l, -by,
                function() local c=db[k]; return c.r,c.g,c.b,c.a end,
                function(r,g,b,a) db[k]={r=r,g=g,b=b,a=a}; Refresh() end, true); by = by + h
        end
        return by
    end)

    local btnStage, btnIlvl, btnAttr, btnEnh = elements.btnStage, elements.btnIlvl, elements.btnAttr, elements.btnEnh
    BindPreviewClick(btnStage, "Armory Layout", "Click to jump to General settings.", function() return cols.left[1] end)
    BindPreviewClick(btnIlvl, "Item Level", "Click to jump to Item Level settings.", function() return cols.right[1] end)
    BindPreviewClick(btnAttr, "Attributes", "Click to jump to Character Stats settings.", function() return cols.right[3] end)
    BindPreviewClick(btnEnh, "Enhancements", "Click to jump to Stat Labels settings.", function() return cols.left[4] end)

    y = EndOptionBlocks(cols)

    return y
end)
