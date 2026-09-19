local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local W = KT.Widgets
local LSM = LibStub("LibSharedMedia-3.0", true)

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

local function GetDB()
    if not (KT and KT.db and KT.db.profile) then return nil end
    KT.db.profile.unitFrames = KT.db.profile.unitFrames or {}
    if KT.db.profile.unitFrames.enable == nil then
        KT.db.profile.unitFrames.enable = true
    end
    return KT.db.profile.unitFrames
end

local function GetModule()
    return KT:GetModule("UnitFrames", true)
end

local previewRefresh
local PREVIEW_FONT = KT.FONT_PATH
local PREVIEW_FILL = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\CustomTextures\\MelliReforged.tga"
local PREVIEW_BG = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\MelliDark.tga"
local PREVIEW_CLASS_TEXTURE = "Interface\\TargetingFrame\\UI-Classes-Circles"
local PREVIEW_PORTRAIT_MEDIA = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
local PREVIEW_CIRCLE_MASK = PREVIEW_PORTRAIT_MEDIA .. "circle_mask.tga"
local PREVIEW_CIRCLE_BORDER = PREVIEW_PORTRAIT_MEDIA .. "circle_border.tga"
local PREVIEW_ABSORB_VALUE = 22
local PREVIEW_DYNAMIC_UNITS = { "pet", "focus", "target", "totPet", "focustarget" }
local PREVIEW_CLASS_POOL = {
    "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK",
    "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR",
}
local previewClassAssignments = {}
local GetDefaultPortraitFacing
local ApplyPreviewPortraitTexture

local function RerollPreviewClassAssignments()
    local pool = {}
    for index, classToken in ipairs(PREVIEW_CLASS_POOL) do
        pool[index] = classToken
    end
    for index = #pool, 2, -1 do
        local swapIndex = math.random(index)
        pool[index], pool[swapIndex] = pool[swapIndex], pool[index]
    end
    for index, unitKey in ipairs(PREVIEW_DYNAMIC_UNITS) do
        previewClassAssignments[unitKey] = pool[index]
    end
end

RerollPreviewClassAssignments()

local function CurrentAccentColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local accent = palette and palette.accent or nil
    return (accent and accent.r) or KT.C_R or 1,
        (accent and accent.g) or KT.C_G or 0,
        (accent and accent.b) or KT.C_B or 0.3333333333
end

local ACCENT = setmetatable({}, {
    __index = function(_, key)
        local r, g, b = CurrentAccentColor()
        if key == "r" then return r end
        if key == "g" then return g end
        if key == "b" then return b end
        return nil
    end,
})

local PAGE_BUTTON_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Button.png"
local TAB_H = 36
local TAB_GAP = 2
local _tabBarFrame
local ufActiveTab = "general"

local function GetSCSafeWidth(sc)
    return sc:GetWidth() or 300
end

local function FindButtonLabel(button)
    if not button then return nil end
    for _, region in ipairs({ button:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("FontString") then
            return region
        end
    end
end

local MENU_BTN_TEX = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\MenuButton.png"
local MENU_BTN_minX  = 12 / 601
local MENU_BTN_maxX  = 586 / 601
local MENU_BTN_minY  = 8 / 147
local MENU_BTN_maxY  = 136 / 147
local MENU_BTN_cx    = 8 / 601
local MENU_BTN_cy    = 8 / 147
local MENU_BTN_cs    = 4  -- cornerScreen pixels

local function Apply9SliceTabButton(button, isActive)
    if not button then return end
    local ar, ag, ab = CurrentAccentColor()

    if not button._kui9slices then
        -- Build 9-slice the first time
        local visual = CreateFrame("Frame", nil, button)
        visual:SetAllPoints()
        visual:SetFrameLevel(math.max(1, button:GetFrameLevel() - 1))
        visual:SetClipsChildren(false)
        button._kui9visual = visual

        local slices = {}
        for i = 1, 9 do
            local t = visual:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(MENU_BTN_TEX)
            slices[i] = t
        end
        local TL,TR,BL,BR,T,B,L,R,C = unpack(slices)

        TL:SetSize(MENU_BTN_cs, MENU_BTN_cs); TR:SetSize(MENU_BTN_cs, MENU_BTN_cs)
        BL:SetSize(MENU_BTN_cs, MENU_BTN_cs); BR:SetSize(MENU_BTN_cs, MENU_BTN_cs)
        TL:SetPoint("TOPLEFT"); TR:SetPoint("TOPRIGHT")
        BL:SetPoint("BOTTOMLEFT"); BR:SetPoint("BOTTOMRIGHT")
        T:SetPoint("TOPLEFT",TL,"TOPRIGHT");  T:SetPoint("BOTTOMRIGHT",TR,"BOTTOMLEFT")
        B:SetPoint("TOPLEFT",BL,"TOPRIGHT");  B:SetPoint("BOTTOMRIGHT",BR,"BOTTOMLEFT")
        L:SetPoint("TOPLEFT",TL,"BOTTOMLEFT"); L:SetPoint("BOTTOMRIGHT",BL,"TOPRIGHT")
        R:SetPoint("TOPLEFT",TR,"BOTTOMLEFT"); R:SetPoint("BOTTOMRIGHT",BR,"TOPRIGHT")
        C:SetPoint("TOPLEFT",TL,"BOTTOMRIGHT"); C:SetPoint("BOTTOMRIGHT",BR,"TOPLEFT")

        TL:SetTexCoord(MENU_BTN_minX, MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_minY, MENU_BTN_minY+MENU_BTN_cy)
        TR:SetTexCoord(MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_maxX, MENU_BTN_minY, MENU_BTN_minY+MENU_BTN_cy)
        BL:SetTexCoord(MENU_BTN_minX, MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_maxY-MENU_BTN_cy, MENU_BTN_maxY)
        BR:SetTexCoord(MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_maxX, MENU_BTN_maxY-MENU_BTN_cy, MENU_BTN_maxY)
        T:SetTexCoord(MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_minY, MENU_BTN_minY+MENU_BTN_cy)
        B:SetTexCoord(MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_maxY-MENU_BTN_cy, MENU_BTN_maxY)
        L:SetTexCoord(MENU_BTN_minX, MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_minY+MENU_BTN_cy, MENU_BTN_maxY-MENU_BTN_cy)
        R:SetTexCoord(MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_maxX, MENU_BTN_minY+MENU_BTN_cy, MENU_BTN_maxY-MENU_BTN_cy)
        C:SetTexCoord(MENU_BTN_minX+MENU_BTN_cx, MENU_BTN_maxX-MENU_BTN_cx, MENU_BTN_minY+MENU_BTN_cy, MENU_BTN_maxY-MENU_BTN_cy)

        button._kui9slices = slices

        button:HookScript("OnEnter", function(self)
            local r,g,b = CurrentAccentColor()
            for _, t in ipairs(self._kui9slices) do t:SetVertexColor(r,g,b,1) end
            local lbl = self._kuiPageLabel or FindButtonLabel(self)
            if lbl then lbl:SetTextColor(1,1,1,1) end
        end)
        button:HookScript("OnLeave", function(self)
            local r,g,b = CurrentAccentColor()
            local alpha = self._kuiIsActive and 1 or 0.4
            for _, t in ipairs(self._kui9slices) do t:SetVertexColor(r,g,b,alpha) end
            local lbl = self._kuiPageLabel or FindButtonLabel(self)
            if lbl then lbl:SetTextColor(alpha == 1 and 1 or 0.7, alpha == 1 and 1 or 0.7, alpha == 1 and 1 or 0.7, 1) end
        end)
    end

    button._kuiIsActive = isActive
    local alpha = isActive and 1 or 0.4
    for _, t in ipairs(button._kui9slices) do
        t:SetVertexColor(ar, ag, ab, alpha)
    end
    local lbl = button._kuiPageLabel or FindButtonLabel(button)
    if lbl then
        lbl:SetTextColor(isActive and 1 or 0.7, isActive and 1 or 0.7, isActive and 1 or 0.7, 1)
    end
end

-- Compatibility shims so existing call sites still work
local function ApplyModernButtonVisual(button, mode, hovered)
    Apply9SliceTabButton(button, mode == "active")
end

local function StyleModernPageButton(button, mode, fontSize)
    if not button then return end
    button._kuiPageLabel = button._kuiPageLabel or FindButtonLabel(button)
    if button._kuiPageLabel and fontSize then
        button._kuiPageLabel:SetFont(PREVIEW_FONT, fontSize, "OUTLINE")
    end
    button._kuiPageMode = mode or "inactive"
    Apply9SliceTabButton(button, mode == "active")
end

local function BuildTabBar(sc, yOff)
    local tabs = {
        { id = "general",     label = LText("General") },
        { id = "player",      label = LText("Player & Pet") },
        { id = "target",      label = LText("Targeting") },
        { id = "boss",        label = LText("Boss") },
    }
    local containerH = TAB_H + 6
    local container
    if _tabBarFrame and _tabBarFrame:GetParent() == sc then
        container = _tabBarFrame
        for _, child in ipairs({ container:GetChildren() }) do child:Hide() end
    else
        if _tabBarFrame then _tabBarFrame:Hide() end
        container = CreateFrame("Frame", nil, sc)
        _tabBarFrame = container
    end
    container:SetHeight(containerH)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, yOff)
    container:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -20, yOff)
    container:Show()

    local scW = GetSCSafeWidth(sc) - 30
    local totalWidth = math.max(1, scW)
    local usableWidth = totalWidth - ((#tabs - 1) * TAB_GAP)
    local tabWidth = math.floor(usableWidth / #tabs)
    local usedWidth = (tabWidth * #tabs) + ((#tabs - 1) * TAB_GAP)
    local remainder = totalWidth - usedWidth

    local previousButton
    for i, tab in ipairs(tabs) do
        local isActive = (tab.id == ufActiveTab)
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetHeight(TAB_H)
        btn:SetWidth(tabWidth + ((i == #tabs) and remainder or 0))
        if i == 1 then
            btn:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", previousButton, "RIGHT", TAB_GAP, 0)
        end

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(PREVIEW_FONT, 11, "OUTLINE")
        lbl:SetText(tab.label); lbl:SetAllPoints(); lbl:SetJustifyH("CENTER")
        btn._kuiPageLabel = lbl
        StyleModernPageButton(btn, isActive and "active" or "inactive", 11)

        local tid = tab.id
        btn:SetScript("OnClick", function()
            ufActiveTab = tid; if KT.RefreshPage then KT:RefreshPage(true) end
        end)
        btn:Show()
        previousButton = btn
    end
    return container, containerH + 8
end


local function RefreshFrames()
    local Mod = GetModule()
    if Mod and Mod.Reload then
        Mod:Reload()
    elseif ns.ReloadFrames then
        ns.ReloadFrames()
    end
    if previewRefresh then
        previewRefresh()
    end
end

local function SetAndRefresh(setter)
    setter()
    RefreshFrames()
end

local function ApplyHealthDisplayToText(settings)
    if not settings then return end
    local hd = settings.healthDisplay or "both"
    local namePos = settings.namePosition or "left"
    local hpPos = settings.healthTextPosition or "right"

    if namePos == "left" then
        settings.leftTextContent = "name"
        settings.rightTextContent = (hpPos == "right") and hd or "none"
    elseif namePos == "right" then
        settings.rightTextContent = "name"
        settings.leftTextContent = (hpPos == "left") and hd or "none"
    else
        settings.leftTextContent = (hpPos == "left") and hd or "none"
        settings.rightTextContent = (hpPos == "right") and hd or "none"
    end
end

local function CreatePreviewUnit(parent)
    local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    frame:RegisterForClicks("AnyUp")
    frame:EnableMouse(true)
    KT:AddBorder(frame, 0, 0, 0, 1)

    frame.portraitFrame = CreateFrame("Frame", nil, frame)
    frame.portraitFrame:SetFrameLevel(frame:GetFrameLevel() + 20)
    frame.portrait = frame.portraitFrame:CreateTexture(nil, "ARTWORK")
    frame.portrait:SetAllPoints(frame.portraitFrame)
    frame.portrait:SetColorTexture(0.35, 0.35, 0.35, 1)
    frame.portraitMask = frame.portraitFrame:CreateMaskTexture()
    frame.portraitMask:SetTexture(PREVIEW_CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    frame.portraitMask:Hide()
    frame.portraitBorder = frame.portraitFrame:CreateTexture(nil, "OVERLAY")
    frame.portraitBorder:SetTexture(PREVIEW_CIRCLE_BORDER)
    frame.portraitBorder:Hide()

    frame.health = CreateFrame("StatusBar", nil, frame)
    frame.health:SetStatusBarTexture(PREVIEW_FILL)
    frame.health.bg = frame.health:CreateTexture(nil, "BACKGROUND")
    frame.health.bg:SetTexture(PREVIEW_BG)
    frame.health.bg:SetAllPoints()
    frame.health.bg:SetVertexColor(0.1, 0.1, 0.1, 1)
    frame.health:SetClipsChildren(true)

    frame.absorb = CreateFrame("StatusBar", nil, frame.health)
    frame.absorb:SetMinMaxValues(0, 100)
    frame.absorb:SetReverseFill(true)
    frame.absorb:SetFrameLevel(frame.health:GetFrameLevel() + 1)
    frame.absorb:Hide()

    frame.power = CreateFrame("StatusBar", nil, frame)
    frame.power:SetStatusBarTexture(PREVIEW_FILL)
    frame.power.bg = frame.power:CreateTexture(nil, "BACKGROUND")
    frame.power.bg:SetTexture(PREVIEW_BG)
    frame.power.bg:SetAllPoints()
    frame.power.bg:SetVertexColor(0.08, 0.08, 0.08, 1)
    frame.power:SetStatusBarColor(0.22, 0.45, 0.95, 1)

    frame.name = frame.health:CreateFontString(nil, "OVERLAY")
    frame.name:SetFont(PREVIEW_FONT, 14, "OUTLINE")
    frame.name:SetTextColor(1, 1, 1, 1)
    frame.name:SetPoint("LEFT", 6, 0)
    frame.name:SetJustifyH("LEFT")

    frame.value = frame.health:CreateFontString(nil, "OVERLAY")
    frame.value:SetFont(PREVIEW_FONT, 14, "OUTLINE")
    frame.value:SetTextColor(1, 1, 1, 1)
    frame.value:SetPoint("RIGHT", -6, 0)
    frame.value:SetJustifyH("RIGHT")

    frame.levelText = frame:CreateFontString(nil, "OVERLAY")
    frame.levelText:SetJustifyH("LEFT")
    frame.levelText:SetWordWrap(false)
    frame.levelText:SetWidth(38)
    frame.levelText:SetHeight(14)
    frame.levelText:Hide()
    frame.pvpIcon = frame:CreateTexture(nil, "OVERLAY")
    frame.pvpIcon:SetSize(16, 16)
    frame.pvpIcon:Hide()

    frame.hover = frame:CreateTexture(nil, "HIGHLIGHT")
    frame.hover:SetAllPoints()
    KT:SetAccentTexture(frame.hover, 0.12)

    return frame
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
        if minVal and target < minVal then
            target = minVal
        end
        if maxVal and target > maxVal then
            target = maxVal
        end

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
        local r, g, b = CurrentAccentColor()
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

local function BindPreviewClick(frame, label, targetTab, getTargetBlock)
    if not frame then return end

    frame:SetScript("OnClick", function()
        local needsDelay = false
        if targetTab and ufActiveTab ~= targetTab then
            ufActiveTab = targetTab
            needsDelay = true
            if KT.RefreshPage then KT:RefreshPage(true) end
        end
        C_Timer.After(needsDelay and 0.15 or 0.05, function()
            local target = getTargetBlock and getTargetBlock()
            if target then
                ScrollToOptionBlock(target)
            end
        end)
    end)

    frame:SetScript("OnEnter", function(self)
        KT:AddAccentBorder(self, 1)
        if GameTooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label or LText("Unit Frame Preview"), 1, 1, 1)
            GameTooltip:AddLine(LText("Click to jump to its settings block."), 0.75, 0.82, 0.9, true)
            GameTooltip:Show()
        end
    end)

    frame:SetScript("OnLeave", function(self)
        KT:AddBorder(self, 0, 0, 0, 1)
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function GetPreviewClassColor(unitKey)
    local colors = CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS or {}

    local function colorFor(classToken)
        local c = classToken and colors[classToken]
        if c then
            return c.r, c.g, c.b
        end
        return nil
    end

    if unitKey == "player" then
        local _, classToken = UnitClass("player")
        local r, g, b = colorFor(classToken)
        if r then
            return r, g, b
        end
    end

    local assignedClass = previewClassAssignments[unitKey]
    if assignedClass then
        local r, g, b = colorFor(assignedClass)
        if r then
            return r, g, b
        end
    end

    local previewClasses = {
        target = "MAGE",
        focus = "PRIEST",
        pet = "HUNTER",
        totPet = "ROGUE",
        focustarget = "DRUID",
        boss = "WARRIOR",
    }

    local r, g, b = colorFor(previewClasses[unitKey])
    if r then
        return r, g, b
    end

    return 0.95, 0.53, 0.02
end

local function ResolvePreviewBarTexture(textureKey, fallbackPath)
    local textures = ns.healthBarTextures or {}
    if textureKey and textures[textureKey] then
        return textures[textureKey]
    end
    if textureKey and LSM then
        local sharedPath = LSM:Fetch("statusbar", textureKey, true)
        if sharedPath then return sharedPath end
    end
    return fallbackPath or PREVIEW_FILL
end

local function ApplyPreviewUnit(frame, unitKey, settings, globalDB, nameText, valueText)
    local showPortrait = globalDB.portraitStyle ~= "none" and settings.showPortrait ~= false
    local powerHeight = ((settings.powerPosition or "below") ~= "none") and (settings.powerHeight or 6) or 0
    local totalBarHeight = (settings.healthHeight or 20) + powerHeight
    local isCircular = globalDB.portraitStyle == "circular"
    local portraitWidth = showPortrait and (totalBarHeight + (isCircular and 10 or 0)) or 0
    local circularOverlap = portraitWidth * 0.5
    local totalWidth = (settings.frameWidth or 100)
        + (isCircular and math.max(0, portraitWidth - circularOverlap) or portraitWidth)
    local totalHeight = isCircular and math.max(totalBarHeight, portraitWidth) or totalBarHeight
    local portraitSide = settings.portraitSide or "left"

    frame:SetSize(totalWidth, totalHeight)
    frame.health:ClearAllPoints()
    frame.health:SetSize(settings.frameWidth or 100, settings.healthHeight or 20)
    frame.power:ClearAllPoints()
    frame.power:SetSize(settings.frameWidth or 100, powerHeight)
    frame.portraitFrame:ClearAllPoints()
    local applyPortraitTexture = ApplyPreviewPortraitTexture or _G.ApplyPreviewPortraitTexture
    if applyPortraitTexture then
        applyPortraitTexture(frame.portrait, unitKey, settings.portraitFacing or GetDefaultPortraitFacing(unitKey))
    end

    if showPortrait then
        frame.portraitFrame:Show()
        frame.portraitFrame:SetSize(portraitWidth, portraitWidth)
        if isCircular then
            local verticalOffset = (totalHeight - totalBarHeight) * 0.5
            if portraitSide == "right" then
                frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -verticalOffset)
                frame.portraitFrame:SetPoint("LEFT", frame.health, "RIGHT", -circularOverlap, 0)
            else
                frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", portraitWidth - circularOverlap, -verticalOffset)
                frame.portraitFrame:SetPoint("RIGHT", frame.health, "LEFT", circularOverlap, 0)
            end

            if not frame._portraitMaskApplied then
                frame.portrait:AddMaskTexture(frame.portraitMask)
                frame._portraitMaskApplied = true
            end
            frame.portraitMask:ClearAllPoints()
            frame.portraitMask:SetAllPoints(frame.portrait)
            frame.portraitMask:Show()
            frame.portraitBorder:ClearAllPoints()
            frame.portraitBorder:SetPoint("TOPLEFT", frame.portrait, "TOPLEFT", -1, 1)
            frame.portraitBorder:SetPoint("BOTTOMRIGHT", frame.portrait, "BOTTOMRIGHT", 1, -1)
            frame.portraitBorder:Show()
        elseif portraitSide == "right" then
            frame.portraitFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
            frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        else
            frame.portraitFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
            frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", portraitWidth, 0)
        end
    else
        frame.portraitFrame:Hide()
        frame.health:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    end

    if not isCircular then
        if frame._portraitMaskApplied then
            frame.portrait:RemoveMaskTexture(frame.portraitMask)
            frame._portraitMaskApplied = false
        end
        frame.portraitMask:Hide()
        frame.portraitBorder:Hide()
    end

    if powerHeight > 0 then
        frame.power:Show()
        frame.power:SetPoint("TOPLEFT", frame.health, "BOTTOMLEFT", 0, 0)
    else
        frame.power:Hide()
    end

    frame.health:SetMinMaxValues(0, 100)
    local previewHealthValue = 100
    local showAbsorbPreview = unitKey == "player" and settings.showPlayerAbsorb == true
    if showAbsorbPreview then
        previewHealthValue = 100 - PREVIEW_ABSORB_VALUE
    end
    frame.health:SetStatusBarTexture(ResolvePreviewBarTexture(settings.healthBarTexture, PREVIEW_FILL))
    frame.health:SetValue(previewHealthValue)

    local fillR, fillG, fillB
    local bgR, bgG, bgB
    if globalDB.darkTheme == true then
        fillR, fillG, fillB = 0x11 / 255, 0x11 / 255, 0x11 / 255
        bgR, bgG, bgB = 0x4f / 255, 0x4f / 255, 0x4f / 255
    elseif settings.healthClassColored ~= false then
        fillR, fillG, fillB = GetPreviewClassColor(unitKey)
        bgR, bgG, bgB = fillR * 0.2, fillG * 0.2, fillB * 0.2
    elseif settings.customFillColor then
        local c = settings.customFillColor
        fillR, fillG, fillB = c.r or 1, c.g or 1, c.b or 1
        if settings.customBgColor then
            local bg = settings.customBgColor
            bgR, bgG, bgB = bg.r or 0.08, bg.g or 0.08, bg.b or 0.08
        else
            bgR, bgG, bgB = fillR * 0.2, fillG * 0.2, fillB * 0.2
        end
    else
        fillR, fillG, fillB = 0.95, 0.53, 0.02
        bgR, bgG, bgB = 0.08, 0.08, 0.08
    end

    frame.health:SetStatusBarColor(fillR, fillG, fillB, 1)
    if isCircular then
        local borderColor = globalDB.circularPortraitBorderColor
        if globalDB.circularPortraitBorderUseCustomColor == true and type(borderColor) == "table" then
            frame.portraitBorder:SetVertexColor(borderColor.r or 1, borderColor.g or 1, borderColor.b or 1, borderColor.a or 1)
        else
            frame.portraitBorder:SetVertexColor(fillR, fillG, fillB, 1)
        end
    end
    frame.health.bg:SetTexture(PREVIEW_BG)
    frame.health.bg:SetVertexColor(bgR, bgG, bgB, 1)
    frame.power:SetStatusBarTexture(ResolvePreviewBarTexture(settings.powerBarTexture or settings.healthBarTexture, PREVIEW_FILL))
    frame.power.bg:SetTexture(PREVIEW_BG)
    frame.name:ClearAllPoints()
    frame.value:ClearAllPoints()
    local nameInset = (isCircular and portraitSide ~= "right") and (circularOverlap + 5) or 6
    local valueInset = (isCircular and portraitSide == "right") and (circularOverlap + 5) or 6
    frame.name:SetPoint("LEFT", frame.health, "LEFT", nameInset, 0)
    frame.value:SetPoint("RIGHT", frame.health, "RIGHT", -valueInset, 0)
    local metadataAnchor = showPortrait and frame.portraitFrame or frame.health
    frame.levelText:ClearAllPoints()
    if unitKey == "target" then
        frame.levelText:SetPoint("BOTTOMRIGHT", metadataAnchor, "TOPRIGHT", -(tonumber(globalDB.levelX) or 2), tonumber(globalDB.levelY) or 2)
    else
        frame.levelText:SetPoint("BOTTOMLEFT", metadataAnchor, "TOPLEFT", tonumber(globalDB.levelX) or 2, tonumber(globalDB.levelY) or 2)
    end
    local levelOutline = globalDB.levelFontOutline
    if levelOutline == "NONE" then levelOutline = "" end
    frame.levelText:SetFont(ResolvePreviewFont(globalDB.levelFont), tonumber(globalDB.levelFontSize) or 11, levelOutline or "OUTLINE")
    local levelColor = globalDB.levelColor or { r = 1, g = 0.82, b = 0.20, a = 1 }
    frame.levelText:SetTextColor(levelColor.r or 1, levelColor.g or 1, levelColor.b or 1, levelColor.a or 1)
    frame.levelText:SetText(unitKey == "player" and "80" or "70")
    frame.levelText:SetShown(globalDB.showCharacterLevel == true)
    frame.pvpIcon:ClearAllPoints()
    if unitKey == "target" then
        frame.pvpIcon:SetPoint("LEFT", metadataAnchor, "RIGHT", 2, 1)
        frame.pvpIcon:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\Horde.png")
    else
        frame.pvpIcon:SetPoint("RIGHT", metadataAnchor, "LEFT", -2, 1)
        frame.pvpIcon:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\EnhancedFriendList\\Alliance.png")
    end
    frame.pvpIcon:SetShown(globalDB.showPvPIcon == true and (unitKey == "player" or unitKey == "target"))
    frame.name:SetFont(PREVIEW_FONT, settings.leftTextSize or settings.textSize or 14, "OUTLINE")
    frame.value:SetFont(PREVIEW_FONT, settings.rightTextSize or settings.textSize or 14, "OUTLINE")
    frame.name:SetText(nameText)
    if showAbsorbPreview then
        frame.value:SetText(string.format("%d%%", previewHealthValue))
    else
        frame.value:SetText(valueText)
    end

    frame.absorb:ClearAllPoints()
    frame.absorb:SetPoint("TOPRIGHT", frame.health:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    frame.absorb:SetPoint("BOTTOMRIGHT", frame.health:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    frame.absorb:SetWidth(settings.frameWidth or 100)
    frame.absorb:SetStatusBarTexture(ResolvePreviewBarTexture(settings.absorbBarTexture, PREVIEW_FILL))
    if showAbsorbPreview then
        local c = settings.absorbBarColor or { r = 0.11, g = 1.00, b = 0.62, a = 1.00 }
        frame.absorb:SetStatusBarColor(c.r or 0.11, c.g or 1.00, c.b or 0.62, c.a or 1.00)
        frame.absorb:SetValue(PREVIEW_ABSORB_VALUE)
        frame.absorb:Show()
    else
        frame.absorb:Hide()
    end
end

local function FontValues()
    local vals = {}
    local compat = ns.KUIUFCompat
    local paths = compat and compat.fontPaths or {}
    for name in pairs(paths) do
        if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(name) then
            vals[name] = name
        end
    end
    if LSM then
        local sharedFonts = LSM:List("font")
        for i = 1, #(sharedFonts or {}) do
            local name = sharedFonts[i]
            if not KT or not KT.IsFontOptionVisible or KT:IsFontOptionVisible(name) then
                vals[name] = name
            end
        end
    end
    if not next(vals) then
        local def = (KT and KT.GetDefaultFontName and KT:GetDefaultFontName()) or "AAA_ITC_Avant_Garde"
        vals[def] = def
    end
    vals._menuOpts = {
        kind = "font",
        sharedMedia = true,
        resolve = function(name)
            return paths[name] or (LSM and LSM:Fetch("font", name, true))
        end,
    }
    return vals
end

local function TextureValues(includeNone)
    local values = {}
    local order = ns.healthBarTextureOrder or {}
    local names = ns.healthBarTextureNames or {}

    for _, key in ipairs(order) do
        if includeNone or key ~= "none" then
            values[key] = names[key] or key
        end
    end

    if next(values) == nil then
        values["Melli Reforged"] = "Melli Reforged"
    end

    values._menuOpts = {
        kind = "texture",
        sharedMedia = true,
        itemHeight = 28,
        background = function(key)
            return (ns.healthBarTextures and ns.healthBarTextures[key])
                or (LSM and LSM:Fetch("statusbar", key, true))
        end,
    }

    return values
end

local PREVIEW_LIVE_UNITS = {
    player = "player",
    pet = "pet",
    target = "target",
    focus = "focus",
    totPet = "targettarget",
    focustarget = "focustarget",
}

local PREVIEW_CLASS_FALLBACKS = {
    target = "MAGE",
    focus = "PRIEST",
    totPet = "ROGUE",
    focustarget = "DRUID",
    boss = "WARRIOR",
}

local PREVIEW_ICON_FALLBACKS = {
    pet = "Interface\\Icons\\Ability_Hunter_BeastCall",
}

ApplyPreviewPortraitTexture = function(texture, unitKey, portraitFacing)
    if not texture then
        return
    end

    texture:SetTexCoord(0, 1, 0, 1)

    local liveUnit = PREVIEW_LIVE_UNITS[unitKey]
    if liveUnit and UnitExists(liveUnit) then
        SetPortraitTexture(texture, liveUnit)
        if portraitFacing == "flipped" then
            texture:SetTexCoord(1, 0, 0, 1)
        end
        return
    end

    local classToken = PREVIEW_CLASS_FALLBACKS[unitKey]
    if classToken and _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[classToken] then
        texture:SetTexture(PREVIEW_CLASS_TEXTURE)
        texture:SetTexCoord(unpack(_G.CLASS_ICON_TCOORDS[classToken]))
        return
    end

    texture:SetTexture(PREVIEW_ICON_FALLBACKS[unitKey] or "Interface\\Icons\\INV_Misc_QuestionMark")
end
_G.ApplyPreviewPortraitTexture = ApplyPreviewPortraitTexture

local PORTRAIT_STYLES = {
    none = "Hidden",
    attached = "Attached",
    detached = "Detached",
    circular = "Circular",
}

local PORTRAIT_MODES = {
    ["2d"] = "2D Portrait",
    ["3d"] = "3D Portrait",
    ["class"] = "Class Theme",
}
local CIRCULAR_PORTRAIT_MODES = {
    ["2d"] = "2D Portrait",
    ["class"] = "Class Theme",
}

local PORTRAIT_FACING = {
    normal = "Normal",
    flipped = "Flipped",
}

local PORTRAIT_SIDES = {
    left = "Left",
    right = "Right",
}

local POWER_POSITIONS = {
    none = "Hidden",
    above = "Above",
    below = "Below",
}

local HEALTH_TEXT = {
    none = "None",
    curhpshort = "Current (Abbrev)",
    curhp = "Current (Full)",
    perhp = "Percent",
    both = "Current (Abbrev) + Percent",
    curhp_perhp = "Current (Full) + Percent",
    deficit = "Deficit",
}

local CLASS_POWER_STYLES = {
    none = "Disabled",
    blizzard = "Blizzard",
    modern = "Modern",
}

local COMBAT_INDICATOR_STYLES = {
    none = "Disabled",
    standard = "Blizzard",
}

local function NormalizeCombatIndicatorStyle(style)
    if style == "none" then
        return "none"
    end

    return "standard"
end

local function AddVisibilityControls(sc, unitKey, y)
    local db = GetDB()
    local s = db[unitKey]
    local h
    _, h = W:Toggle(sc, "Show Solo", -y, function() return s.showSolo ~= false end, function(v) SetAndRefresh(function() s.showSolo = v end) end); y = y + h
    _, h = W:Toggle(sc, "Show In Party", -y, function() return s.showInParty ~= false end, function(v) SetAndRefresh(function() s.showInParty = v end) end); y = y + h
    _, h = W:Toggle(sc, "Show In Raid", -y, function() return s.showInRaid ~= false end, function(v) SetAndRefresh(function() s.showInRaid = v end) end); y = y + h
    return y
end

GetDefaultPortraitFacing = function(unitKey)
    if unitKey == "target" then
        return "flipped"
    end
    return "normal"
end

local function AddCommonUnitControls(sc, unitKey, label, y, opts)
    local db = GetDB()
    local s = db[unitKey]
    local enabledKey = opts.enabledKey or unitKey
    local h

    if opts.showHeader ~= false then
        _, h = W:SectionHeader(sc, label, -y); y = y + h
    else
        sc.rowCounter = 0
    end
    _, h = W:Toggle(sc, "Enable Frame", -y,
        function()
            if opts.enabledGet then return opts.enabledGet(db) end
            return db.enabledFrames[enabledKey] ~= false
        end,
        function(v)
            SetAndRefresh(function()
                if opts.enabledSet then
                    opts.enabledSet(db, v)
                else
                    db.enabledFrames[enabledKey] = v
                end
            end)
        end); y = y + h
    _, h = W:Slider(sc, "Frame Width", -y,
        function() return s.frameWidth or 100 end,
        function(v) SetAndRefresh(function() s.frameWidth = v end) end, 60, 320, 1); y = y + h
    _, h = W:Slider(sc, "Health Height", -y,
        function() return s.healthHeight or 20 end,
        function(v) SetAndRefresh(function() s.healthHeight = v end) end, 12, 80, 1); y = y + h
    _, h = W:Toggle(sc, "Class Colored Health", -y,
        function() return s.healthClassColored ~= false end,
        function(v) SetAndRefresh(function() s.healthClassColored = v end) end); y = y + h
    _, h = W:ColorSwatch(sc, "Health Fill Color", -y,
        function()
            local c = s.customFillColor or { r = 0.22, g = 0.55, b = 0.95, a = 1 }
            return c.r, c.g, c.b, c.a
        end,
        function(r, g, b, a)
            SetAndRefresh(function()
                s.customFillColor = { r = r, g = g, b = b, a = a }
            end)
        end, true); y = y + h
    _, h = W:ColorSwatch(sc, "Health Background Color", -y,
        function()
            local c = s.customBgColor or { r = 0.08, g = 0.08, b = 0.08, a = 1 }
            return c.r, c.g, c.b, c.a
        end,
        function(r, g, b, a)
            SetAndRefresh(function()
                s.customBgColor = { r = r, g = g, b = b, a = a }
            end)
        end, true); y = y + h

    if opts.hasPower then
        _, h = W:Dropdown(sc, "Power Bar Position", -y, POWER_POSITIONS,
            function() return s.powerPosition or "below" end,
            function(v) SetAndRefresh(function() s.powerPosition = v end) end); y = y + h
        _, h = W:Slider(sc, "Power Height", -y,
            function() return s.powerHeight or 6 end,
            function(v) SetAndRefresh(function() s.powerHeight = v end) end, 0, 24, 1); y = y + h
    end

    _, h = W:Toggle(sc, "Show Portrait", -y,
        function() return s.showPortrait ~= false end,
        function(v) SetAndRefresh(function() s.showPortrait = v end) end); y = y + h
    _, h = W:Dropdown(sc, "Portrait Style", -y, PORTRAIT_STYLES,
        function() return db.portraitStyle or "attached" end,
        function(v) SetAndRefresh(function() db.portraitStyle = v end) end); y = y + h
    local portraitModes = db.portraitStyle == "circular" and CIRCULAR_PORTRAIT_MODES or PORTRAIT_MODES
    _, h = W:Dropdown(sc, "Portrait Mode", -y, portraitModes,
        function()
            local mode = s.portraitMode or "2d"
            return (db.portraitStyle == "circular" and mode == "3d") and "2d" or mode
        end,
        function(v) SetAndRefresh(function() s.portraitMode = v end) end); y = y + h
    
    -- Portrait Side (for attached and circular portraits)
    if db.portraitStyle ~= "none" then
        _, h = W:Dropdown(sc, "Portrait Side", -y, PORTRAIT_SIDES,
            function() 
                local defaultSide = (unitKey == "player" or unitKey == "pet") and "left" or "right"
                return s.portraitSide or defaultSide 
            end,
            function(v) SetAndRefresh(function() s.portraitSide = v end) end); y = y + h
    end
    
    if opts.allowPortraitFacing then
        _, h = W:Dropdown(sc, "Portrait Facing", -y, PORTRAIT_FACING,
            function() return s.portraitFacing or GetDefaultPortraitFacing(unitKey) end,
            function(v) SetAndRefresh(function() s.portraitFacing = v end) end); y = y + h
    end
    
    -- Portrait position and size controls (always shown when portrait options exist)
    _, h = W:Slider(sc, "Portrait Size Adjustment", -y,
        function() return s.portraitSize or 0 end,
        function(v) SetAndRefresh(function() s.portraitSize = v end) end, -40, 300, 1); y = y + h
    _, h = W:Slider(sc, "Portrait X Offset", -y,
        function() return s.portraitX or 0 end,
        function(v) SetAndRefresh(function() s.portraitX = v end) end, -250, 250, 1); y = y + h
    _, h = W:Slider(sc, "Portrait Y Offset", -y,
        function() return s.portraitY or 0 end,
        function(v) SetAndRefresh(function() s.portraitY = v end) end, -250, 250, 1); y = y + h

    if opts.hasCastbar then
        local castToggleKey = opts.castToggleKey or "showCastbar"
        _, h = W:Toggle(sc, "Show Castbar", -y,
            function() return s[castToggleKey] ~= false end,
            function(v) SetAndRefresh(function() s[castToggleKey] = v end) end); y = y + h
    end

    if opts.showBuffsKey then
        _, h = W:Toggle(sc, opts.showBuffsLabel or "Show Buffs", -y,
            function() return s[opts.showBuffsKey] ~= false end,
            function(v) SetAndRefresh(function() s[opts.showBuffsKey] = v end) end); y = y + h
    end

    if opts.showDebuffsKey then
        _, h = W:Toggle(sc, opts.showDebuffsLabel or "Show Debuffs", -y,
            function() return s[opts.showDebuffsKey] ~= false end,
            function(v) SetAndRefresh(function() s[opts.showDebuffsKey] = v end) end); y = y + h
    end

    if opts.showDispelOverlayKey then
        _, h = W:Toggle(sc, opts.showDispelOverlayLabel or "Dispel Overlay", -y,
            function() return s[opts.showDispelOverlayKey] ~= false end,
            function(v) SetAndRefresh(function() s[opts.showDispelOverlayKey] = v end) end); y = y + h
            
        local function AddColorSwatch(key, label, defR, defG, defB)
            _, h = W:ColorSwatch(sc, label, -y,
                function()
                    local c = s[key]
                    if c then return c.r, c.g, c.b, 1 else return defR, defG, defB, 1 end
                end,
                function(r, g, b)
                    SetAndRefresh(function() s[key] = {r=r, g=g, b=b} end)
                end, false); y = y + h
        end
        AddColorSwatch("dispelColorMagic", "Magic Color", 0.349, 0.475, 1.0)
        AddColorSwatch("dispelColorCurse", "Curse Color", 0.636, 0.0, 0.640)
        AddColorSwatch("dispelColorDisease", "Disease Color", 0.671, 0.384, 0.098)
        AddColorSwatch("dispelColorPoison", "Poison Color", 0.0, 0.706, 0.286)
        AddColorSwatch("dispelColorBleed", "Bleed Color", 0.750, 0.150, 0.150)
    end


    _, h = W:Dropdown(sc, "Health Text", -y, HEALTH_TEXT,
        function() return s.healthDisplay or "both" end,
        function(v) SetAndRefresh(function()
            s.healthDisplay = v
            ApplyHealthDisplayToText(s)
        end) end); y = y + h
    _, h = W:Slider(sc, "Text Size", -y,
        function() return s.textSize or s.leftTextSize or 12 end,
        function(v) SetAndRefresh(function() s.textSize = v; s.leftTextSize = v; s.rightTextSize = v; s.centerTextSize = v end) end, 8, 24, 1); y = y + h

    if opts.hasVisibility then
        y = AddVisibilityControls(sc, unitKey, y)
    end

    return y
end

local function CreateOptionBlock(parent, title, x, y, width)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 40)
    frame:SetPoint("TOPLEFT", x, y)
    KT:AddBackdrop(frame, 0.04, 0.04, 0.05, 0.95)
    KT:AddBorder(frame, 0.18, 0.18, 0.22, 1)

    local titleText = frame:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(KT.FONT_PATH, 10, "OUTLINE")
    KT:SetAccentTextColor(titleText, 1)
    titleText:SetPoint("TOPLEFT", 10, -8)
    titleText:SetText(string.upper(title))

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 0, -24)
    content:SetWidth(width)
    content:SetHeight(1)
    content.rowCounter = 0

    return frame, content
end

local function FinalizeOptionBlock(frame, content, contentHeight)
    local headerH = 24
    local bottomPad = 10
    local total = headerH + contentHeight + bottomPad
    content:SetHeight(contentHeight)
    frame:SetHeight(total)
    return total
end

local function CreateUnitFramesLivePreview(parent, options)
    options = options or {}
    local db = GetDB()
    if not db then return nil end

    local preview = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    preview:SetSize(options.width or (parent:GetWidth() - 20), options.height or 180)
    preview:SetPoint("TOPLEFT", options.x or 10, -(options.y or 10))
    KT:AddBackdrop(preview, 0.04, 0.04, 0.05, 0.95)
    KT:AddBorder(preview, 0.18, 0.18, 0.22, 1)
    if options.attachSticky ~= false and KT.AttachStickyPreview then
        KT:AttachStickyPreview(preview, { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 10, y = -10 })
    end

    local previewTitle = preview:CreateFontString(nil, "OVERLAY")
    previewTitle:SetFont(PREVIEW_FONT, 10, "OUTLINE")
    KT:SetAccentTextColor(previewTitle, 1)
    previewTitle:SetPoint("TOPLEFT", 10, -8)
    previewTitle:SetText(LText("LIVE PREVIEW"))

    local playerPreview = CreatePreviewUnit(preview)
    local targetPreview = CreatePreviewUnit(preview)
    local focusPreview = CreatePreviewUnit(preview)
    local petPreview = CreatePreviewUnit(preview)
    local targetTargetPreview = CreatePreviewUnit(preview)
    local focusTargetPreview = CreatePreviewUnit(preview)

    preview.Refresh = function()
        local previewWidth = preview:GetWidth()
        ApplyPreviewUnit(playerPreview, "player", db.player, db, "Player", "100%")
        ApplyPreviewUnit(targetPreview, "target", db.target, db, "Target", "100%")
        ApplyPreviewUnit(focusPreview, "focus", db.focus, db, "Focus", "100%")
        ApplyPreviewUnit(petPreview, "pet", db.pet, db, "Pet", "100%")
        ApplyPreviewUnit(targetTargetPreview, "totPet", db.totPet, db, "ToT", "100%")
        ApplyPreviewUnit(focusTargetPreview, "focustarget", db.totPet, db, "Focus Target", "100%")

        playerPreview:ClearAllPoints()
        playerPreview:SetPoint("TOPLEFT", preview, "TOPLEFT", 18, -34)
        targetPreview:ClearAllPoints()
        targetPreview:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -18, -34)
        petPreview:ClearAllPoints()
        petPreview:SetPoint("TOPLEFT", playerPreview, "BOTTOMLEFT", 0, -12)
        focusPreview:ClearAllPoints()
        focusPreview:SetPoint("TOPLEFT", petPreview, "BOTTOMLEFT", 0, -20)
        targetTargetPreview:ClearAllPoints()
        targetTargetPreview:SetPoint("TOPRIGHT", targetPreview, "BOTTOMRIGHT", -5, -8)
        focusTargetPreview:ClearAllPoints()
        focusTargetPreview:SetPoint("TOPRIGHT", targetTargetPreview, "BOTTOMRIGHT", 0, -12)

        if previewWidth > 0 then
            local leftStackHeight = (playerPreview:GetHeight() or 0) + (petPreview:GetHeight() or 0) + (focusPreview:GetHeight() or 0) + 86
            local rightStackHeight = (targetPreview:GetHeight() or 0) + (targetTargetPreview:GetHeight() or 0) + (focusTargetPreview:GetHeight() or 0) + 66
            preview:SetHeight(math.max(leftStackHeight, rightStackHeight))
        end
    end
    preview:Refresh()
    
    -- Store preview frames for external access
    preview.playerPreview = playerPreview
    preview.targetPreview = targetPreview
    preview.focusPreview = focusPreview
    preview.petPreview = petPreview
    preview.targetTargetPreview = targetTargetPreview
    preview.focusTargetPreview = focusTargetPreview
    
    return preview
end

_G.KullThranUI_UnitFramesOptions = _G.KullThranUI_UnitFramesOptions or {}
_G.KullThranUI_UnitFramesOptions.CreateLivePreview = CreateUnitFramesLivePreview
KT:RegisterPage("unitframes", "Unit Frames", 11, function(sc, W)
    W = W or (KT and KT.Widgets)
    if not W then return 0 end
    local db = GetDB()
    if not db then return 0 end
    local y, h = 0, 0

    local optionsFrame = KT.MenuPrincipal
    if optionsFrame and not optionsFrame._kuiUFPreviewClassHooked then
        optionsFrame._kuiUFPreviewClassHooked = true
        optionsFrame:HookScript("OnShow", function()
            RerollPreviewClassAssignments()
            C_Timer.After(0, function()
                if previewRefresh then previewRefresh() end
            end)
        end)
    end

    local preview = CreateUnitFramesLivePreview(sc)
    previewRefresh = function() preview:Refresh() end    previewRefresh()
    local previewBottomGap = 24
    y = y + preview:GetHeight() + previewBottomGap

    local gap = 12
    local columnGap = 14
    local fullW = sc:GetWidth()
    local blockW = math.floor((fullW - 20 - columnGap) / 2)
    local leftX = 10
    local rightX = leftX + blockW + columnGap
    local leftUsed = 0
    local rightUsed = 0

    for _, child in ipairs({ sc:GetChildren() }) do
        if child ~= _tabBarFrame and child ~= preview then child:Hide() end
    end
    local tabContainer, tabH = BuildTabBar(sc, -y)
    y = y + tabH + 6

    local optionBlocks = {}

    local function AddBlock(column, title, buildFn, key)
        local x = (column == 'right') and rightX or leftX
        local yOff = -(y + ((column == 'right') and rightUsed or leftUsed))
        local frame, content = CreateOptionBlock(sc, title, x, yOff, blockW)
        local contentH = buildFn(content)
        local totalH = FinalizeOptionBlock(frame, content, contentH)
        optionBlocks[key or title] = frame
        if column == 'right' then
            rightUsed = rightUsed + totalH + gap
        else
            leftUsed = leftUsed + totalH + gap
        end
        return frame
    end

    if ufActiveTab == 'general' then
        AddBlock('left', 'Global', function(container)
            local by = 0
            _, h = W:Toggle(container, 'Enable Module', -by,
                function() return db.enable ~= false end,
                function(v)
                    db.enable = v
                    ReloadUI()
                end); by = by + h
            _, h = W:Toggle(container, 'Show Character Level', -by,
                function() return db.showCharacterLevel == true end,
                function(v) SetAndRefresh(function() db.showCharacterLevel = v and true or false end) end); by = by + h
            _, h = W:Toggle(container, 'Show PvP Faction Icon', -by,
                function() return db.showPvPIcon == true end,
                function(v) SetAndRefresh(function() db.showPvPIcon = v and true or false end) end); by = by + h
            local levelOutlineValues = { NONE = 'None', OUTLINE = 'Outline', THICKOUTLINE = 'Thick Outline', MONOCHROME = 'Monochrome', OUTLINEMONOCHROME = 'Monochrome Outline' }
            _, h = W:Dropdown(container, 'Level Font', -by, FontValues,
                function() return db.levelFont or 'AAA_ITC_Avant_Garde' end,
                function(v) SetAndRefresh(function() db.levelFont = v end) end); by = by + h
            _, h = W:Slider(container, 'Level Font Size', -by,
                function() return tonumber(db.levelFontSize) or 11 end,
                function(v) SetAndRefresh(function() db.levelFontSize = v end) end, 6, 48, 1); by = by + h
            _, h = W:Dropdown(container, 'Level Text Outline', -by, levelOutlineValues,
                function() return db.levelFontOutline or 'OUTLINE' end,
                function(v) SetAndRefresh(function() db.levelFontOutline = v end) end); by = by + h
            _, h = W:ColorSwatch(container, 'Level Text Color', -by,
                function() local c = db.levelColor or { r = 1, g = 0.82, b = 0.20, a = 1 }; return c.r, c.g, c.b, c.a end,
                function(r, g, b, a) SetAndRefresh(function() db.levelColor = { r = r, g = g, b = b, a = a or 1 } end) end, true); by = by + h
            _, h = W:Slider(container, 'Level X Offset', -by,
                function() return tonumber(db.levelX) or 2 end,
                function(v) SetAndRefresh(function() db.levelX = v end) end, -200, 200, 1); by = by + h
            _, h = W:Slider(container, 'Level Y Offset', -by,
                function() return tonumber(db.levelY) or 2 end,
                function(v) SetAndRefresh(function() db.levelY = v end) end, -100, 200, 1); by = by + h
            _, h = W:Dropdown(container, 'Portrait Style', -by, PORTRAIT_STYLES,
                function() return db.portraitStyle or 'attached' end,
                function(v) SetAndRefresh(function() db.portraitStyle = v end) end); by = by + h
            _, h = W:Toggle(container, 'Custom Circular Portrait Border', -by,
                function() return db.circularPortraitBorderUseCustomColor == true end,
                function(v) SetAndRefresh(function() db.circularPortraitBorderUseCustomColor = v and true or false end) end); by = by + h
            _, h = W:ColorSwatch(container, 'Circular Portrait Border Color', -by,
                function()
                    local c = db.circularPortraitBorderColor
                    if c then return c.r, c.g, c.b, c.a end
                    local r, g, b = CurrentAccentColor()
                    return r, g, b, 1
                end,
                function(r, g, b, a)
                    SetAndRefresh(function()
                        db.circularPortraitBorderColor = { r = r, g = g, b = b, a = a or 1 }
                    end)
                end, false); by = by + h
            _, h = W:Toggle(container, 'Dark Theme', -by,
                function() return db.darkTheme == true end,
                function(v) SetAndRefresh(function() db.darkTheme = v end) end); by = by + h
            _, h = W:Slider(container, 'Castbar Opacity', -by,
                function() return math.floor((db.castbarOpacity or 1) * 100 + 0.5) end,
                function(v) SetAndRefresh(function() db.castbarOpacity = v / 100 end) end, 0, 100, 1); by = by + h
            _, h = W:ColorSwatch(container, 'Castbar Color', -by,
                function()
                    local c = db.castbarColor
                    if c then return c.r, c.g, c.b, c.a end
                    local r, g, b = CurrentAccentColor()
                    return r, g, b, 1
                end,
                function(r, g, b, a) SetAndRefresh(function() db.castbarColor = { r = r, g = g, b = b, a = a } end) end, true); by = by + h
            _, h = W:Dropdown(container, 'Default Font', -by, FontValues,
                function() return db.player and db.player.selectedFont or 'AAA_ITC_Avant_Garde' end,
                function(v) SetAndRefresh(function()
                    for _, key in ipairs({ 'player', 'target', 'focus', 'boss', 'pet', 'totPet' }) do
                        if db[key] then db[key].selectedFont = v end
                    end
                end) end); by = by + h
            _, h = W:Dropdown(container, 'Default Texture', -by, TextureValues(false),
                function() return db.player and db.player.healthBarTexture or 'Melli Reforged' end,
                function(v) SetAndRefresh(function()
                    for _, key in ipairs({ 'player', 'target', 'focus', 'boss', 'pet', 'totPet' }) do
                        if db[key] then db[key].healthBarTexture = v end
                    end
                end) end); by = by + h
            return by
        end, 'global')

        AddBlock('right', 'Positions', function(container)
            local by = 0
            _, h = W:Label(container, 'Use Unlock Mode to drag Unit Frames registered by KullThranUI.', -by, 11); by = by + h
            _, h = W:Button(container, 'Open Unlock Mode', -by, function()
                local UM = KT and KT.GetModule and KT:GetModule('UnlockMode', true)
                if UM and not UM.isOpen and UM.OpenUnlockMode then
                    UM:OpenUnlockMode()
                elseif UM and UM.isOpen and UM.RefreshMovers then
                    UM:RefreshMovers()
                end
            end); by = by + h
            _, h = W:Button(container, 'Reset Unit Frames Defaults', -by, function()
                StaticPopup_Show('KULLTHRANUI_UF_RESET_DEFAULTS')
            end); by = by + h
            return by
        end, 'positions')
    end

    if ufActiveTab == 'player' then
        AddBlock('left', 'Player', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'player', 'Player', by, {
                hasPower = true,
                hasCastbar = true,
                allowPortraitFacing = true,
                castToggleKey = 'showPlayerCastbar',
                showBuffsKey = 'showBuffs',
                showBuffsLabel = 'Show Buffs',
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = true,
                showHeader = false,
            })

            _, h = W:Toggle(container, 'Show Absorb Bar', -by,
                function() return db.player.showPlayerAbsorb == true end,
                function(v) SetAndRefresh(function() db.player.showPlayerAbsorb = v end) end); by = by + h
            _, h = W:Dropdown(container, 'Absorb Texture', -by, TextureValues(true),
                function() return db.player.absorbBarTexture or 'glass' end,
                function(v) SetAndRefresh(function() db.player.absorbBarTexture = v end) end); by = by + h
            _, h = W:ColorSwatch(container, 'Absorb Color', -by,
                function()
                    local c = db.player.absorbBarColor or { r = 0.74, g = 0.92, b = 1, a = 0.82 }
                    return c.r, c.g, c.b, c.a
                end,
                function(r, g, b, a)
                    SetAndRefresh(function()
                        db.player.absorbBarColor = { r = r, g = g, b = b, a = a }
                    end)
                end, true); by = by + h
            _, h = W:Toggle(container, 'Show Class Power', -by,
                function() return db.player.showClassPowerBar == true end,
                function(v) SetAndRefresh(function() db.player.showClassPowerBar = v end) end); by = by + h
            _, h = W:Dropdown(container, 'Class Power Style', -by, CLASS_POWER_STYLES,
                function() return db.player.classPowerStyle or 'none' end,
                function(v) SetAndRefresh(function() db.player.classPowerStyle = v; db.player.showClassPowerBar = (v ~= 'none') end) end); by = by + h
            _, h = W:Dropdown(container, 'Combat Indicator', -by, COMBAT_INDICATOR_STYLES,
                function() return NormalizeCombatIndicatorStyle(db.player.combatIndicatorStyle) end,
                function(v) SetAndRefresh(function() db.player.combatIndicatorStyle = v end) end); by = by + h
            return by
        end, 'player')

        AddBlock('right', 'Pet', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'pet', 'Pet', by, {
                hasPower = false,
                hasCastbar = false,
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = false,
                showHeader = false,
            })
            return by
        end, 'pet')
    end

    if ufActiveTab == 'target' then
        AddBlock('left', 'Target', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'target', 'Target', by, {
                hasPower = true,
                hasCastbar = true,
                allowPortraitFacing = true,
                showBuffsKey = 'showBuffs',
                showBuffsLabel = 'Show Buffs',
                showDebuffsKey = 'onlyPlayerDebuffs',
                showDebuffsLabel = 'Only Player Debuffs',
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = true,
                showHeader = false,
            })
            return by
        end, 'target')

        AddBlock('right', 'Focus', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'focus', 'Focus', by, {
                hasPower = true,
                hasCastbar = true,
                showDebuffsKey = 'onlyPlayerDebuffs',
                showDebuffsLabel = 'Only Player Debuffs',
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = true,
                showHeader = false,
            })
            return by
        end, 'focus')

        AddBlock('left', 'Target Of Target / Focus Target', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'totPet', 'Target Of Target / Focus Target', by, {
                enabledGet = function(dbRef)
                    return dbRef.enabledFrames.targettarget ~= false or dbRef.enabledFrames.focustarget ~= false
                end,
                enabledSet = function(dbRef, v)
                    dbRef.enabledFrames.targettarget = v
                    dbRef.enabledFrames.focustarget = v
                end,
                hasPower = false,
                hasCastbar = false,
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = false,
                showHeader = false,
            })
            return by
        end, 'totPet')
    end

    if ufActiveTab == 'boss' then
        AddBlock('left', 'Boss', function(container)
            local by = 0
            by = AddCommonUnitControls(container, 'boss', 'Boss', by, {
                enabledKey = 'boss',
                hasPower = true,
                hasCastbar = false,
                showDispelOverlayKey = 'dispelOverlay',
                hasVisibility = false,
                showHeader = false,
            })
            _, h = W:Slider(container, 'Boss Spacing', -by,
                function() return db.bossSpacing or 60 end,
                function(v) SetAndRefresh(function() db.bossSpacing = v end) end, 20, 120, 1); by = by + h
            return by
        end, 'boss')
    end

    BindPreviewClick(preview.playerPreview, 'Player Preview', 'player', function() return optionBlocks.player end)
    BindPreviewClick(preview.targetPreview, 'Target Preview', 'target', function() return optionBlocks.target end)
    BindPreviewClick(preview.focusPreview, 'Focus Preview', 'target', function() return optionBlocks.focus end)
    BindPreviewClick(preview.petPreview, 'Pet Preview', 'player', function() return optionBlocks.pet end)
    BindPreviewClick(preview.targetTargetPreview, 'Target Of Target / Focus Target Preview', 'target', function() return optionBlocks.totPet end)
    BindPreviewClick(preview.focusTargetPreview, 'Target Of Target / Focus Target Preview', 'target', function() return optionBlocks.totPet end)

    y = y + math.max(leftUsed, rightUsed)

    return y
end)
