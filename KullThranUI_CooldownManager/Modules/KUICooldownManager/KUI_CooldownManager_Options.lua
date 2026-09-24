-------------------------------------------------------------------------------
--  KUI_CooldownManager_Options.lua
-- PESTANA: CUSTOM BARS
-- PESTANA: CUSTOM BARS
-------------------------------------------------------------------------------
---@diagnostic disable: deprecated
local ADDON_NAME, ns = ...
---@type any
local KT = ns.KT or LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
-- KUI localization helper (resolved at call time; falls back to the raw text)
local function LText(text)
    if type(text) ~= "string" then return text end
    local L = KT and KT.GetLocale and KT:GetLocale()
    if L and L[text] ~= nil then return L[text] end
    return text
end
local DisablePixelSnap = (KT and KT.PP and KT.PP.DisablePixelSnap) or function(tex)
    if tex and tex.SetSnapToPixelGrid then
        tex:SetSnapToPixelGrid(false)
        tex:SetTexelSnappingBias(0)
    end
end
if not KT then return end

-- Reload helper – mirrors the one in Options.lua.
-- Falls back to ReloadUI() if the popup has not been registered yet.
local function Reload()
    if StaticPopupDialogs["KULLTHRANUI_RELOAD"] then
        StaticPopup_Show("KULLTHRANUI_RELOAD")
    else
        ReloadUI()
    end
end

-- ============================================================================
-- MOVABLE ELEMENTS REGISTRY
-- PESTANA: CUSTOM BARS
-- PESTANA: CUSTOM BARS
-- siempre retorna sin registrar los frames del CDM.
-- ============================================================================
KT.MovableElements = KT.MovableElements or {}
if not KT.RegisterMovableElements then
    function KT:RegisterMovableElements(elements)
        for _, el in ipairs(elements) do
            KT.MovableElements[el.key] = el
        end
    end
end

-- ============================================================================
-- VARIABLES GLOBALES Y COLOR
-- ============================================================================
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
local FONT_PATH = KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
local ITEM_ID_NEG_OFFSET = 1000000
local GetSpellInfoSafe = rawget(_G, "GetSpellInfo")
local GetSpellBookItemInfoSafe = rawget(_G, "GetSpellBookItemInfo")
local GetSpellBookItemNameSafe = rawget(_G, "GetSpellBookItemName")

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

local function DecodeItemID(id)
    if not id then return nil end
    local neg = -id
    if neg >= ITEM_ID_NEG_OFFSET then return neg - ITEM_ID_NEG_OFFSET end
    return nil
end

local function GetPotionTrackerSlotInfo(identifier)
    if not (ns.IsPotionTrackerSlotID and ns.IsPotionTrackerSlotID(identifier)) then
        return nil, nil, nil
    end
    local itemID = ns.ResolvePotionTrackerSlotItem and ns.ResolvePotionTrackerSlotItem(identifier)
    local slotKey = ns.GetPotionTrackerSlotKey and ns.GetPotionTrackerSlotKey(identifier)
    local label = ns.GetPotionTrackerSlotLabel and ns.GetPotionTrackerSlotLabel(identifier)
    return itemID, slotKey, label
end


-- ============================================================================
-- HELPER STUBS FOR CDM PORT
-- ============================================================================
local function GetCDMOptOutline() return "OUTLINE" end
local function GetCDMOptUseShadow() return true end
local function SetPVFont(fs, font, size)
    if not (fs and fs.SetFont) then return end
    fs:SetFont(font, size, "OUTLINE")
end
local DD_H = 34
local PAD = 10
local ICON_SZ = 20
local MEDIA = "Interface\\AddOns\\KullThranUI\\Media\\"
local PAGE_BUTTON_TEXTURE = "Interface\\AddOns\\KullThranUI\\Libraries\\KUITextures\\Button.png"
local AddGlowColorRow
local ApplyPreviewShapeToSlot
local IsCDMBuffsBar
local AddCDMBuffsNoticeBlock
local OpenBlizzardCDMSettings

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

local function ApplyModernButtonVisual(button, mode, hovered)
    if not button then return end

    local bgAlpha, shadeAlpha, borderAlpha, accentAlpha = 0.58, 0.28, 0.35, 0.15
    local textR, textG, textB = 0.70, 0.70, 0.70

    if mode == "active" then
        bgAlpha, shadeAlpha, borderAlpha, accentAlpha = 1.0, 0.08, 0.95, 0.90
        textR, textG, textB = 1, 1, 1
    elseif mode == "action" then
        bgAlpha, shadeAlpha, borderAlpha, accentAlpha = 0.88, 0.12, 0.82, 0.78
        textR, textG, textB = 1, 1, 1
    end

    if hovered and mode ~= "active" then
        bgAlpha = math.min(1, bgAlpha + 0.12)
        shadeAlpha = math.max(0.08, shadeAlpha - 0.10)
        borderAlpha = math.max(borderAlpha, 0.92)
        accentAlpha = math.max(accentAlpha, 0.82)
        textR, textG, textB = 1, 1, 1
    end

    if button.bgKT then
        button.bgKT:SetAlpha(0)
    end

    if not button._kuiPageBg then
        button._kuiPageBg = button:CreateTexture(nil, "BACKGROUND")
        button._kuiPageBg:SetAllPoints()
        button._kuiPageBg:SetTexture(PAGE_BUTTON_TEXTURE)
    end
    if not button._kuiPageShade then
        button._kuiPageShade = button:CreateTexture(nil, "BORDER")
        button._kuiPageShade:SetAllPoints()
    end
    if not button._kuiPageAccent then
        button._kuiPageAccent = button:CreateTexture(nil, "OVERLAY")
        button._kuiPageAccent:SetHeight(2)
        button._kuiPageAccent:SetPoint("BOTTOMLEFT", 2, 1)
        button._kuiPageAccent:SetPoint("BOTTOMRIGHT", -2, 1)
    end
    if not button._kuiPageBorder then
        button._kuiPageBorder = {}
        for i = 1, 4 do
            button._kuiPageBorder[i] = button:CreateTexture(nil, "OVERLAY")
        end
        button._kuiPageBorder[1]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button._kuiPageBorder[1]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        button._kuiPageBorder[1]:SetHeight(1)
        button._kuiPageBorder[2]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        button._kuiPageBorder[2]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button._kuiPageBorder[2]:SetHeight(1)
        button._kuiPageBorder[3]:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button._kuiPageBorder[3]:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
        button._kuiPageBorder[3]:SetWidth(1)
        button._kuiPageBorder[4]:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        button._kuiPageBorder[4]:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
        button._kuiPageBorder[4]:SetWidth(1)
    end

    button._kuiPageBg:SetVertexColor(1, 1, 1, bgAlpha)
    button._kuiPageShade:SetColorTexture(0, 0, 0, shadeAlpha)
    button._kuiPageAccent:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, accentAlpha)

    if button._kuiPageBorder then
        for i = 1, 4 do
            button._kuiPageBorder[i]:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, borderAlpha)
        end
    end

    local label = button._kuiPageLabel or FindButtonLabel(button)
    if label then
        label:SetTextColor(textR, textG, textB, 1)
    end
end

local function StyleModernPageButton(button, mode, fontSize)
    if not button then return end
    button._kuiPageLabel = button._kuiPageLabel or FindButtonLabel(button)
    if button._kuiPageLabel and fontSize then
        button._kuiPageLabel:SetFont(FONT_PATH, fontSize, "OUTLINE")
    end
    button._kuiPageMode = mode or "inactive"
    ApplyModernButtonVisual(button, button._kuiPageMode, false)

    if not button._kuiPageStyled then
        button._kuiPageStyled = true
        button:HookScript("OnEnter", function(self)
            ApplyModernButtonVisual(self, self._kuiPageMode or "inactive", true)
        end)
        button:HookScript("OnLeave", function(self)
            ApplyModernButtonVisual(self, self._kuiPageMode or "inactive", false)
        end)
    end
end

local function GetKeybindFontFlags(barData)
    return (barData and barData.keybindOutline ~= false) and "OUTLINE" or ""
end

local _tbbSelectedBar = 1

local cdmActiveTab = "cdmbars"


-- ============================================================================
-- ACCESO A BASE DE DATOS
-- ============================================================================
local function DB()
    if not KT.db.profile.cooldownManager then
        KT.db.profile.cooldownManager = {}
    end

    local p = KT.db.profile.cooldownManager

    if p._capturedOnce == nil then p._capturedOnce = false end
    if not p.activeSpecKey then p.activeSpecKey = "0" end

    if not p.cdmBars then p.cdmBars = { enabled = true, hideBlizzard = true, bars = {} } end
    if p.cdmBars.useBlizzardDisplayDefaults == nil then
        p.cdmBars.useBlizzardDisplayDefaults = true
    end
    if p.cdmBars.promptBlizzardLayoutChanges == nil then
        p.cdmBars.promptBlizzardLayoutChanges = true
    end
    if not p.cdmBars.bars or #p.cdmBars.bars == 0 then
        p.cdmBars.bars = {
            { key = "cooldowns", name = "Cooldowns", enabled = true, barType = "cooldowns", iconSize = 42, spacing = 2, numRows = 1, barScale = 1.0, growDirection = "RIGHT", barVisibility = "always", barBgAlpha = 1, growCentered = true, desaturateOnCD = false, hideGCDSwipe = false, anchorTo = "erb_powerbar", anchorPosition = "bottom", anchorOffsetX = 0, anchorOffsetY = -250 },
            { key = "utility",   name = "Utility",   enabled = true, barType = "utility",   iconSize = 33, spacing = 2, numRows = 2, barScale = 1.0, growDirection = "RIGHT", barVisibility = "always", barBgAlpha = 1, growCentered = true, desaturateOnCD = false, hideGCDSwipe = false, anchorTo = "cooldowns",    anchorPosition = "bottom", anchorOffsetY = -2 },
            { key = "buffs",     name = "Buffs",     enabled = true, barType = "buffs",     iconSize = 32, spacing = 2, numRows = 1, barScale = 1.0, growDirection = "RIGHT", barVisibility = "always", barBgAlpha = 1, growCentered = true, desaturateOnCD = false, hideGCDSwipe = false, anchorTo = "castbar",      anchorPosition = "top",    anchorOffsetY = 15 },
        }
    end

    for _, b in ipairs(p.cdmBars.bars) do
        if b.hideGCDSwipe == nil then
            b.hideGCDSwipe = false
        end
        if b.swipeAlpha == nil then b.swipeAlpha = 0.7 end
        if b.swipeR == nil then b.swipeR = 0 end
        if b.swipeG == nil then b.swipeG = 0 end
        if b.swipeB == nil then b.swipeB = 0 end
        if b.activeSwipeUsesGlowColor == nil then b.activeSwipeUsesGlowColor = true end
        if b.showKeybind == nil then
            b.showKeybind = (b.key == "kui_potion" or b.key == "kui_trinket")
        end
        if b.keybindSize == nil or b.keybindSize == 10 or b.keybindSize == 12 then
            b.keybindSize = 13
        end
        if b.keybindOutline == nil then
            b.keybindOutline = true
        end
        if b.keybindOffsetX == nil then b.keybindOffsetX = 2 end
        if b.keybindOffsetY == nil then b.keybindOffsetY = -2 end
        if b.keybindR == nil then b.keybindR = 1 end
        if b.keybindG == nil then b.keybindG = 1 end
        if b.keybindB == nil then b.keybindB = 1 end
        if b.keybindA == nil then b.keybindA = 0.9 end
    end

    if not p.customTracker then
        p.customTracker = {
            interrupt = { enabled = true, size = 42, showText = true, x = 0, y = 4, side = "TOPRIGHT_OUT", auto = true, maxIcons = 1, spells = {} },
            defensive = { enabled = true, size = 36, showText = true, x = 0, y = 4, side = "TOPRIGHT_OUT", auto = true, maxIcons = 2, spells = {} },
            trinket   = { enabled = true, size = 36, showText = true, x = 0, y = -4, side = "BOTTOMRIGHT_OUT", auto = true, maxIcons = 2, spells = {} },
            potion    = { enabled = true, size = 36, showText = true, x = 0, y = -4, side = "BOTTOMLEFT_OUT", auto = true, maxIcons = 3, spells = {}, trackManaPotion = false, potionQuality = "highest" },
        }
    end

    local hasKUIUF = _G["KullThranUI_UF_Player"] or (KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
        and KT.db.profile.unitFrames.enable ~= false
        and KT.db.profile.unitFrames.enabledFrames and KT.db.profile.unitFrames.enabledFrames.player ~= false)
    local ctDefaults = hasKUIUF and {
        interrupt = { x = 0, y = 6, side = "TOPRIGHT_OUT" },
        defensive = { x = 0, y = 4, side = "TOPRIGHT_OUT" },
        trinket   = { x = 0, y = -4, side = "BOTTOMRIGHT_OUT" },
        potion    = { x = 1, y = -4, side = "BOTTOMLEFT_OUT" },
    } or {
        interrupt = { x = 0, y = 4, side = "TOPRIGHT_OUT" },
        defensive = { x = 0, y = 4, side = "TOPRIGHT_OUT" },
        trinket   = { x = 0, y = -4, side = "BOTTOMRIGHT_OUT" },
        potion    = { x = 0, y = -4, side = "BOTTOMLEFT_OUT" },
    }
    for _, key in ipairs({ "interrupt", "defensive", "trinket", "potion" }) do
        local d = ctDefaults[key] or ctDefaults.interrupt
        if not p.customTracker[key] then
            p.customTracker[key] = {
                enabled = true,
                size = (key == "interrupt") and 42 or 36,
                showText = false,
                x = d.x,
                y =
                    d.y,
                side = d.side,
                auto = true,
                maxIcons = (key == "interrupt") and 1 or ((key == "potion") and 3 or 2),
                spells = {}
            }
        end
        if p.customTracker[key].auto == nil then p.customTracker[key].auto = true end
        if p.customTracker[key].maxIcons == nil then
            p.customTracker[key].maxIcons = (key == "interrupt") and 1 or ((key == "potion") and 3 or 2)
        end
        if p.customTracker[key].side == nil then p.customTracker[key].side = d.side end
        if p.customTracker[key].x == nil then p.customTracker[key].x = d.x end
        if p.customTracker[key].y == nil then p.customTracker[key].y = d.y end
        if not p.customTracker[key].spells then p.customTracker[key].spells = {} end
        if key == "potion" then
            local quality = tostring(p.customTracker[key].potionQuality or "highest")
            if quality ~= "highest" and quality ~= 'most' and quality ~= "1" and quality ~= "2" and quality ~= "3" then
                quality = "highest"
            end
            p.customTracker[key].potionQuality = quality
        end
    end

    return p
end

if not StaticPopupDialogs["KUI_CDM_RESTORE_DEFAULTS"] then
    StaticPopupDialogs["KUI_CDM_RESTORE_DEFAULTS"] = {
        text = LText("Restore all Cooldown Manager settings to defaults?\n\nThis resets CDM Bars, Bar Glows, Buff Bars, and KUI Tracker, then reloads the UI."),
        button1 = YES,
        button2 = CANCEL,
        OnAccept = function()
            if KT and KT.db and KT.db.profile then
                KT.db.profile.cooldownManager = nil
            end
            ReloadUI()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

-- ============================================================================
-- PESTANA: CUSTOM BARS
-- ============================================================================

local function GetCDMOptOutline() return "OUTLINE" end
local function SetPVFont(fs, font, size)
    if fs and fs.SetFont then fs:SetFont(font, size, "OUTLINE") end
end
local FONT_PATH = KT.FONT_PATH or "Fonts\\FRIZQT__.TTF"
local cdmActiveTab = "cdmbars"
local cdmActiveSubTab = "manage"
local selectedCDMBarIndex = 1

local function SelectedCDMBar()
    local p = DB()
    if not p or not p.cdmBars or not p.cdmBars.bars then return nil end
    if selectedCDMBarIndex < 1 then selectedCDMBarIndex = 1 end
    if selectedCDMBarIndex > #p.cdmBars.bars then selectedCDMBarIndex = #p.cdmBars.bars end
    return p.cdmBars.bars[selectedCDMBarIndex]
end

-- ============================================================================
local CDM_BAR_DEFAULTS = {
    cooldowns = { barBgAlpha = 100, barScale = 100, borderSize = 1, iconSize = 42, numRows = 1, spacing = 2 },
    utility   = { barBgAlpha = 100, barScale = 100, borderSize = 1, iconSize = 33, numRows = 2, spacing = 2 },
    buffs     = { barBgAlpha = 100, barScale = 100, borderSize = 1, iconSize = 32, numRows = 1, spacing = 2 },
}

local CDM_CUSTOM_BAR_DEFAULTS = {
    barBgAlpha = 100,
    barScale = 100,
    borderSize = 1,
    iconSize = 36,
    numRows = 1,
    spacing = 2,
}

local function GetCDMBarDefaultValue(barData, key)
    if not barData or not key then return nil end
    local defaults = CDM_BAR_DEFAULTS[barData.key or ""] or CDM_CUSTOM_BAR_DEFAULTS
    return defaults[key]
end

-- REFRESH TRIGGERS
-- ============================================================================
local _optionsRefreshToken = 0
local function Refresh()
    -- Sliders/color pickers can fire dozens of changes while dragging. The old
    -- path rebuilt every CDM bar synchronously for every value and froze the UI.
    _optionsRefreshToken = _optionsRefreshToken + 1
    local token = _optionsRefreshToken
    C_Timer.After(0.12, function()
        if token ~= _optionsRefreshToken then return end
        if ns.BuildAllCDMBars then ns.BuildAllCDMBars() end
        if ns.BuildKUICustomTracker then ns.BuildKUICustomTracker() end
        if ns.RequestCDMUpdate then ns.RequestCDMUpdate("options_debounced") end
    end)
end

local function RefreshVis()
    if ns.CDMApplyVisibility then ns.CDMApplyVisibility() end
end

-- ============================================================================

local function RefreshCDMRuntime(barKey)
    if barKey and ns.RefreshCDMBarFromConfig then
        ns.RefreshCDMBarFromConfig(barKey)
    end
    if ns.RequestCDMUpdate then
        ns.RequestCDMUpdate("options_cdm_layout_changed")
    elseif ns.RequestUpdate then
        ns.RequestUpdate("options_cdm_layout_changed")
    elseif barKey then
        if ns.UpdateCDMBarIcons then ns.UpdateCDMBarIcons(barKey) end
        if ns.LayoutCDMBar then ns.LayoutCDMBar(barKey) end
    elseif ns.UpdateAllCDMBars then
        ns.UpdateAllCDMBars()
    end
end

-- UI HELPERS
-- ============================================================================
local function MakeSeparator(parent, yOff, alpha)
    local sep = parent:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, yOff)
    sep:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, yOff)
    sep:SetColorTexture(1, 1, 1, alpha or 0.06)
    return sep, 8
end

local function CreateCDMOptionBlock(parent, title, x, y, width)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 40)
    frame:SetPoint("TOPLEFT", x, y)
    KT:AddBackdrop(frame, 0.04, 0.04, 0.05, 0.95)
    KT:AddBorder(frame, 0.18, 0.18, 0.22, 1)

    local titleText = frame:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(FONT_PATH, 10, "OUTLINE")
    titleText:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
    titleText:SetPoint("TOPLEFT", 10, -8)
    titleText:SetText(string.upper(LText(title) or title or ""))

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", 0, -24)
    content:SetWidth(width)
    content:SetHeight(1)
    content.rowCounter = 0

    return frame, content
end

local function FinalizeCDMOptionBlock(frame, content, contentHeight)
    local headerHeight = 24
    local bottomPad = 10
    local totalHeight = headerHeight + contentHeight + bottomPad
    content:SetHeight(contentHeight)
    frame:SetHeight(totalHeight)
    return totalHeight
end

local function BeginCDMOptionBlocks(sc, startY, opts)
    local gap = (opts and opts.gap) or 12
    local columnGap = (opts and opts.columnGap) or 14
    local fullWidth = sc:GetWidth()
    -- Reserve a right margin so option blocks never sit flush against the frame
    -- border. Left pad stays at 10; the right column's right edge lands at
    -- (fullWidth - rightPad).
    local leftX = 10
    local rightPad = 12
    local blockWidth = math.floor((fullWidth - leftX - rightPad - columnGap) / 2)
    local rightX = leftX + blockWidth + columnGap

    return {
        parent = sc,
        startY = startY,
        gap = gap,
        blockWidth = blockWidth,
        leftX = leftX,
        rightX = rightX,
        fullWidth = fullWidth,
        leftUsed = 0,
        rightUsed = 0,
    }
end

local function AddCDMOptionBlock(cols, column, title, buildFn)
    local x = (column == "right") and cols.rightX or cols.leftX
    local width = cols.blockWidth
    local yOff = -(cols.startY + ((column == "right") and cols.rightUsed or cols.leftUsed))
    
    if column == "full" then
        x = cols.leftX
        width = cols.fullWidth - x - 12
        yOff = -(cols.startY + math.max(cols.leftUsed, cols.rightUsed))
    end

    local frame, content = CreateCDMOptionBlock(cols.parent, title, x, yOff, width)
    local contentHeight = buildFn(content)
    local totalHeight = FinalizeCDMOptionBlock(frame, content, contentHeight)

    if column == "right" then
        cols.rightUsed = cols.rightUsed + totalHeight + cols.gap
    elseif column == "left" then
        cols.leftUsed = cols.leftUsed + totalHeight + cols.gap
    elseif column == "full" then
        local maxUsed = math.max(cols.leftUsed, cols.rightUsed) + totalHeight + cols.gap
        cols.leftUsed = maxUsed
        cols.rightUsed = maxUsed
    end

    return frame
end

local function EndCDMOptionBlocks(cols)
    return cols.startY + math.max(cols.leftUsed, cols.rightUsed)
end

local function PulseCDMOptionBlock(frame)
    if not frame then return end

    local glow = frame._cdmPreviewGlow
    if not glow then
        glow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
        glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
        KT:AddBorder(glow, ACCENT.r, ACCENT.g, ACCENT.b, 1)
        glow:SetFrameLevel(frame:GetFrameLevel() + 10)
        frame._cdmPreviewGlow = glow
    end

    glow:Show()
    C_Timer.After(1.0, function()
        if glow then
            glow:Hide()
        end
    end)
end

local function ScrollToCDMOptionBlock(frame)
    if not (frame and KT and KT.SmoothScrollTo) then return end

    local scrollFrame = KT._scrollFrame
    local scrollChild = scrollFrame and scrollFrame.GetScrollChild and scrollFrame:GetScrollChild()
    local frameTop = frame.GetTop and frame:GetTop()
    local childTop = scrollChild and scrollChild.GetTop and scrollChild:GetTop()
    if frameTop and childTop then
        KT.SmoothScrollTo(math.max(0, (childTop - frameTop) - 40))
        C_Timer.After(0.15, function()
            PulseCDMOptionBlock(frame)
        end)
    end
end

local _cachedSCWidth = 0
local function SafeFrameWidth(frame, fallback)
    fallback = fallback or 300
    if not frame then return fallback end
    local ok, w = pcall(function() return frame:GetWidth() end)
    if not ok or type(w) ~= "number" or w < 10 then return fallback end
    return math.floor(w)
end

local function GetSCSafeWidth(sc)
    local w = SafeFrameWidth(sc, _cachedSCWidth > 10 and _cachedSCWidth or 300)
    if w > 10 then _cachedSCWidth = w end
    return w
end

local function GetIDFromCursor()
    local infoType, val1, val2, val3 = GetCursorInfo()
    if infoType == "spell" then
        -- Retail can provide either a spellID or a spellbook slot+bookType.
        if type(val3) == "number" and val3 > 0 then return val3 end

        -- Some cursor sources provide spellID directly in val1.
        if type(val1) == "number" and val1 > 0 and C_Spell and C_Spell.GetSpellInfo then
            if C_Spell.GetSpellInfo(val1) then return val1 end
        end

        -- Spellbook drag: val1=slot, val2=bookType ("spell"/"pet")
        if type(val1) == "number" and type(val2) == "string" then
            if GetSpellBookItemInfoSafe then
                local _, spellID = GetSpellBookItemInfoSafe(val1, val2)
                if type(spellID) == "number" and spellID > 0 then return spellID end
            end
            if GetSpellBookItemNameSafe and GetSpellInfoSafe then
                local spellName = GetSpellBookItemNameSafe(val1, val2)
                if spellName then
                    local sid = select(7, GetSpellInfoSafe(spellName))
                    if type(sid) == "number" and sid > 0 then return sid end
                end
            end
        end

        return nil
    elseif infoType == "item" then
        return -(ITEM_ID_NEG_OFFSET + val1)
    elseif infoType == "macro" then
        -- Dragging directly from the macro UI.
        local macroIndex = val1
        if type(macroIndex) == "number" and macroIndex > 0 then
            local spellID
            if GetMacroSpell then
                spellID = GetMacroSpell(macroIndex)
            end
            if type(spellID) == "number" and spellID > 0 then return spellID end
            local _, _, itemID
            if GetMacroItem then
                _, _, itemID = GetMacroItem(macroIndex)
            end
            if type(itemID) == "number" and itemID > 0 then
                return -(ITEM_ID_NEG_OFFSET + itemID)
            end
        end
        return nil
    elseif infoType == "action" then
        if type(val1) ~= "number" or val1 <= 0 then return nil end
        local actionType, actionID, subType = GetActionInfo(val1)
        if actionType == "spell" and actionID then
            return actionID
        elseif actionType == "item" and actionID then
            return -(ITEM_ID_NEG_OFFSET + actionID)
        elseif actionType == "macro" and actionID then
            local spellID = GetMacroSpell(actionID)
            if spellID then return spellID end
            local _, _, itemID = GetMacroItem(actionID)
            if itemID then return -(ITEM_ID_NEG_OFFSET + itemID) end
        end
    end
    return nil
end

local function GetPreviewKeybind(spellID)
    if not spellID then return nil end
    if ns.FindCachedKeybind then
        local cached = ns.FindCachedKeybind(spellID)
        if cached then
            return cached
        end
    end
    local cache = ns.CDMKeybindCache
    if cache and cache[spellID] then return cache[spellID] end
    if type(spellID) ~= "number" or spellID < 0 then
        return nil
    end
    local actionSlots = C_ActionBar.FindSpellActionButtons(spellID)
    if actionSlots and #actionSlots > 0 then
        local slot = actionSlots[1]
        local key = GetBindingKey("ACTIONBUTTON" .. slot)
        if key then
            key = GetBindingText(key, "KEY_")
            key = key:gsub("SHIFT%-", "S-"):gsub("ALT%-", "A-"):gsub("CTRL%-", "C-")
            key = key:gsub("NUMPAD", "N"):gsub("MOUSEWHEELUP", "MU"):gsub("MOUSEWHEELDOWN", "MD")
            key = key:gsub("BUTTON", "M")
            return key
        end
    end
    return nil
end

-- ============================================================================
-- UNLOCK MODE CON OVERLAYS ROJOS
-- ============================================================================
local isUnlocked = false
local lockPanel
local unlockOverlays = {}
ns.IsUnlocked = function()
    local UM = KT and KT.GetModule and KT:GetModule("UnlockMode", true)
    if UM then
        return UM.isOpen and true or false
    end
    if EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive then
        return EditModeManagerFrame:IsEditModeActive()
    end
    return isUnlocked
end

local function FormatPreviewCooldown(seconds)
    if type(seconds) ~= "number" or seconds <= 0 then
        return nil
    end

    seconds = math.floor(seconds + 0.5)
    if seconds >= 3600 then
        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        if minutes > 0 then
            return string.format("%dh%dm", hours, minutes)
        end
        return string.format("%dh", hours)
    end
    if seconds >= 60 then
        local minutes = math.floor(seconds / 60)
        local rem = seconds % 60
        if rem > 0 then
            return string.format("%dm%ds", minutes, rem)
        end
        return string.format("%dm", minutes)
    end
    return string.format("%ds", seconds)
end

local function GetTrackerPreviewCooldownText(trackerKey, identifier)
    if type(identifier) ~= "number" then
        return nil
    end

    if identifier > 0 and GetSpellBaseCooldown then
        local baseMS = GetSpellBaseCooldown(identifier) or 0
        if type(baseMS) == "number" and baseMS > 1500 then
            return FormatPreviewCooldown(baseMS / 1000)
        end
    end

    local slotItemID, slotKey = GetPotionTrackerSlotInfo(identifier)
    local itemID = slotItemID or (identifier < 0 and DecodeItemID(identifier) or nil)
    if slotKey == "healthstone" then
        return FormatPreviewCooldown(60)
    elseif slotKey then
        return FormatPreviewCooldown(300)
    end
    if not itemID then
        return nil
    end

    local healthMeta = ns.CDMHealthItemsByID and ns.CDMHealthItemsByID[itemID]
    if healthMeta and healthMeta.cooldown then
        return FormatPreviewCooldown(healthMeta.cooldown)
    end

    if trackerKey == "potion" then
        return FormatPreviewCooldown(300)
    end

    return nil
end

local KUI_TRACKER_PREVIEW_ORDER = { "defensive", "interrupt", "trinket", "potion" }
local KUI_TRACKER_PREVIEW_COLORS = {
    interrupt = { 0.93, 0.33, 0.30 },
    defensive = { 0.35, 0.72, 0.95 },
    trinket = { 0.94, 0.74, 0.30 },
    potion = { 0.39, 0.84, 0.53 },
}

local function GetTrackerPreviewIdentifiers(ct, trackerKey)
    local tracker = ct and ct[trackerKey]
    if not tracker or tracker.enabled == false then
        return {}
    end

    local source = ((tracker.auto ~= false) and ns.BuildAutoTrackerSpells and ns.BuildAutoTrackerSpells(trackerKey))
        or tracker.spells
        or {}
    local out = {}
    local limit = tracker.maxIcons or #source
    for i = 1, math.min(#source, limit) do
        out[#out + 1] = source[i]
    end
    return out
end

local function GetTrackerPreviewTexture(identifier)
    if type(identifier) ~= "number" then
        return 134400
    end

    local slotItemID, _, slotLabel = GetPotionTrackerSlotInfo(identifier)
    local decoded = slotItemID or (identifier < 0 and DecodeItemID(identifier) or nil)
    if decoded then
        return C_Item.GetItemIconByID(decoded) or 134400
    end
    if identifier < 0 and not slotLabel then
        return C_Item.GetItemIconByID(-identifier) or 134400
    end
    return C_Spell.GetSpellTexture(identifier) or 134400
end

local function AnchorTrackerPreviewGroup(group, anchorFrame, side, xOffset, yOffset)
    group:ClearAllPoints()
    side = side or "TOPRIGHT_OUT"
    xOffset = xOffset or 0
    yOffset = yOffset or 0

    if side == "TOPRIGHT_OUT" then
        group:SetPoint("BOTTOMRIGHT", anchorFrame, "TOPRIGHT", xOffset, yOffset)
    elseif side == "TOPLEFT_OUT" then
        group:SetPoint("BOTTOMLEFT", anchorFrame, "TOPLEFT", xOffset, yOffset)
    elseif side == "BOTTOMRIGHT_OUT" then
        group:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", xOffset, yOffset)
    elseif side == "BOTTOMLEFT_OUT" then
        group:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", xOffset, yOffset)
    elseif side == "TOPRIGHT" then
        group:SetPoint("TOPRIGHT", anchorFrame, "TOPRIGHT", xOffset, yOffset)
    elseif side == "TOPLEFT" then
        group:SetPoint("TOPLEFT", anchorFrame, "TOPLEFT", xOffset, yOffset)
    elseif side == "BOTTOMRIGHT" then
        group:SetPoint("BOTTOMRIGHT", anchorFrame, "BOTTOMRIGHT", xOffset, yOffset)
    elseif side == "BOTTOMLEFT" then
        group:SetPoint("BOTTOMLEFT", anchorFrame, "BOTTOMLEFT", xOffset, yOffset)
    elseif side == "RIGHT" then
        group:SetPoint("LEFT", anchorFrame, "RIGHT", xOffset, yOffset)
    elseif side == "LEFT" then
        group:SetPoint("RIGHT", anchorFrame, "LEFT", xOffset, yOffset)
    elseif side == "BOTTOM" then
        group:SetPoint("TOP", anchorFrame, "BOTTOM", xOffset, yOffset)
    else
        group:SetPoint("BOTTOM", anchorFrame, "TOP", xOffset, yOffset)
    end
end

local function ClampTrackerPreviewNumber(value, minValue, maxValue)
    value = tonumber(value) or minValue
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function GetTrackerPreviewPlayerFrame()
    if type(_G._KUI_FindPlayerUnitFrame) == "function" then
        local ok, frame = pcall(_G._KUI_FindPlayerUnitFrame)
        if ok and frame then
            return frame
        end
    end

    if type(ns.CDMGetBlizzardPlayerFrameCandidate) == "function" then
        local ok, frame = pcall(ns.CDMGetBlizzardPlayerFrameCandidate)
        if ok and frame then
            return frame
        end
    end

    return _G["KullThranUI_UF_Player"]
        or _G["UUF_PlayerFrame"]
        or _G["UUF_Player"]
        or _G["PlayerFrame"]
end

local function GetTrackerPreviewStatusBarColor(bar, fallbackR, fallbackG, fallbackB)
    if bar and bar.GetStatusBarColor then
        local ok, r, g, b = pcall(bar.GetStatusBarColor, bar)
        if ok and r and g and b then
            return r, g, b
        end
    end
    return fallbackR, fallbackG, fallbackB
end

local function FormatTrackerPreviewNumber(value)
    value = tonumber(value) or 0
    if AbbreviateLargeNumbers then
        return AbbreviateLargeNumbers(value)
    end
    if value >= 1000000 then
        return string.format("%.1fM", value / 1000000):gsub("%.0M", "M")
    end
    if value >= 1000 then
        return string.format("%.1fK", value / 1000):gsub("%.0K", "K")
    end
    return tostring(math.floor(value + 0.5))
end

local function GetTrackerPreviewAccessibleText(value, fallback)
    if type(value) ~= "string" then
        return fallback
    end

    local canAccessValue = rawget(_G, "canaccessvalue")
    if type(canAccessValue) == "function" then
        local ok, canAccess = pcall(canAccessValue, value)
        if not ok or canAccess ~= true then
            return fallback
        end
    else
        return fallback
    end

    if value == "" then
        return fallback
    end

    return value
end

local function GetTrackerPreviewVisibleText(fontString, fallback)
    if fontString and fontString.GetText then
        local ok, text = pcall(fontString.GetText, fontString)
        if ok then
            return GetTrackerPreviewAccessibleText(text, fallback)
        end
    end
    return fallback
end

local function GetTrackerPreviewUFProfile()
    return KT and KT.db and KT.db.profile and KT.db.profile.unitFrames or nil
end

local function GetTrackerPreviewPlayerSettings()
    local ufProfile = GetTrackerPreviewUFProfile()
    return ufProfile, ufProfile and ufProfile.player or nil
end

local function ResolveTrackerPreviewHealthColor(ufProfile, settings, classColor)
    if ufProfile and ufProfile.darkTheme then
        return 0x11 / 255, 0x11 / 255, 0x11 / 255
    end

    if settings then
        local customFill = settings.customFillColor
        local classColored = settings.healthClassColored ~= false
        if customFill and not classColored then
            return customFill.r or 1, customFill.g or 1, customFill.b or 1
        end
        if classColored and classColor then
            return classColor.r or 1, classColor.g or 1, classColor.b or 1
        end
    end

    if classColor then
        return classColor.r or 1, classColor.g or 1, classColor.b or 1
    end

    return 0.18, 0.68, 0.34
end

local function ResolveTrackerPreviewPowerColor(settings)
    if settings and settings.powerPercentPowerColor ~= false and UnitPowerType and PowerBarColor then
        local powerType = UnitPowerType("player")
        local info = PowerBarColor[powerType]
        if info then
            return info.r or 0, info.g or 0, info.b or 1
        end
    end

    if settings and settings.customPowerFillColor then
        local c = settings.customPowerFillColor
        return c.r or 0, c.g or 0, c.b or 1
    end

    return 0, 0, 1
end

local function GetTrackerPreviewRelativeRect(child, parent)
    if not (child and parent and child.IsShown and child:IsShown()) then return nil end

    local parentLeft = parent.GetLeft and parent:GetLeft() or nil
    local parentRight = parent.GetRight and parent:GetRight() or nil
    local parentTop = parent.GetTop and parent:GetTop() or nil
    local parentBottom = parent.GetBottom and parent:GetBottom() or nil
    local childLeft = child.GetLeft and child:GetLeft() or nil
    local childRight = child.GetRight and child:GetRight() or nil
    local childTop = child.GetTop and child:GetTop() or nil
    local childBottom = child.GetBottom and child:GetBottom() or nil

    if not (parentLeft and parentRight and parentTop and parentBottom and childLeft and childRight and childTop and childBottom) then
        return nil
    end

    local parentWidth = parentRight - parentLeft
    local parentHeight = parentTop - parentBottom
    local childWidth = childRight - childLeft
    local childHeight = childTop - childBottom
    if parentWidth <= 0 or parentHeight <= 0 or childWidth <= 0 or childHeight <= 0 then
        return nil
    end

    return {
        x = (childLeft - parentLeft) / parentWidth,
        y = (parentTop - childTop) / parentHeight,
        width = childWidth / parentWidth,
        height = childHeight / parentHeight,
    }
end

local function GetTrackerPreviewFrameInfo()
    local sourceFrame = GetTrackerPreviewPlayerFrame()
    local sourceName = sourceFrame and sourceFrame.GetName and sourceFrame:GetName() or nil
    local width = sourceFrame and sourceFrame.GetWidth and sourceFrame:GetWidth() or 190
    local height = sourceFrame and sourceFrame.GetHeight and sourceFrame:GetHeight() or 62
    local name = UnitName and UnitName("player") or "Player"
    local ufProfile, playerSettings = GetTrackerPreviewPlayerSettings()
    local classTag
    if UnitClass then
        _, classTag = UnitClass("player")
    end
    local classColor = (classTag and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag]) or NORMAL_FONT_COLOR
    local healthBar = sourceFrame and (sourceFrame.Health or sourceFrame.healthbar or sourceFrame.healthBar or sourceFrame.HealthBar or sourceFrame.PlayerFrameContent and sourceFrame.PlayerFrameContent.PlayerFrameContentMain and sourceFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer and sourceFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.HealthBar) or nil
    local powerBar = sourceFrame and (sourceFrame.Power or sourceFrame.powerbar or sourceFrame.powerBar or sourceFrame.ManaBar or sourceFrame.PlayerFrameContent and sourceFrame.PlayerFrameContent.PlayerFrameContentMain and sourceFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea and sourceFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar) or nil
    local portraitFrame = sourceFrame and sourceFrame.Portrait and sourceFrame.Portrait.backdrop or nil
    local healthR, healthG, healthB = ResolveTrackerPreviewHealthColor(ufProfile, playerSettings, classColor)
    local powerR, powerG, powerB = ResolveTrackerPreviewPowerColor(playerSettings)

    local portraitStyle = ufProfile and ufProfile.portraitStyle or "attached"
    local showPortrait = portraitStyle ~= "none" and playerSettings and playerSettings.showPortrait ~= false
    local isAttachedPortrait = portraitStyle == "attached"
    local portraitSide = playerSettings and playerSettings.portraitSide or "left"
    if isAttachedPortrait and portraitSide == "top" then
        portraitSide = "left"
    end

    local powerPos = playerSettings and playerSettings.powerPosition or "below"
    local powerIsAttached = (powerPos == "below" or powerPos == "above")
    local powerHeight = powerIsAttached and ((playerSettings and playerSettings.powerHeight) or 6) or 0
    local healthHeight = (playerSettings and playerSettings.healthHeight) or 46
    local bottomTextBar = playerSettings and playerSettings.bottomTextBar
    local btbPosition = playerSettings and playerSettings.btbPosition or "bottom"
    local btbAttached = bottomTextBar and (btbPosition == "top" or btbPosition == "bottom")
    local btbHeight = btbAttached and ((playerSettings and playerSettings.bottomTextBarHeight) or 16) or 0
    local portraitSize = (playerSettings and playerSettings.portraitSize) or 0
    local barHeight = healthHeight + powerHeight
    local portraitWidth = 0
    if showPortrait and isAttachedPortrait then
        portraitWidth = math.max(8, barHeight + portraitSize)
    end

    local computedWidth = (playerSettings and playerSettings.frameWidth or 230) + portraitWidth
    local computedHeight = barHeight + btbHeight
    local healthXOffset = (showPortrait and isAttachedPortrait and portraitSide == "left") and portraitWidth or 0
    local healthRightInset = (showPortrait and isAttachedPortrait and portraitSide == "right") and portraitWidth or 0
    local healthWidth = math.max(1, computedWidth - healthXOffset - healthRightInset)

    local healthRect = {
        x = healthXOffset / computedWidth,
        y = (powerPos == "above" and powerHeight or 0) / computedHeight,
        width = healthWidth / computedWidth,
        height = healthHeight / computedHeight,
    }

    local powerRect = nil
    if powerIsAttached and powerHeight > 0 then
        if powerPos == "above" then
            powerRect = {
                x = healthXOffset / computedWidth,
                y = 0,
                width = healthWidth / computedWidth,
                height = powerHeight / computedHeight,
            }
        else
            powerRect = {
                x = healthXOffset / computedWidth,
                y = healthHeight / computedHeight,
                width = healthWidth / computedWidth,
                height = powerHeight / computedHeight,
            }
        end
    end

    local portraitRect = nil
    if showPortrait and isAttachedPortrait and portraitWidth > 0 then
        portraitRect = {
            x = (portraitSide == "right") and ((computedWidth - portraitWidth) / computedWidth) or 0,
            y = 0,
            width = portraitWidth / computedWidth,
            height = barHeight / computedHeight,
        }
    end

    return {
        frame = sourceFrame,
        sourceName = sourceName,
        width = ClampTrackerPreviewNumber(computedWidth > 0 and computedWidth or width, 150, 420),
        height = ClampTrackerPreviewNumber(computedHeight > 0 and computedHeight or height, 24, 140),
        playerName = GetTrackerPreviewVisibleText(sourceFrame and (sourceFrame.LeftText or sourceFrame.NameText), name or "Player"),
        playerHealthText = GetTrackerPreviewVisibleText(sourceFrame and (sourceFrame.RightText or sourceFrame.HealthValue), nil),
        classColor = classColor or NORMAL_FONT_COLOR,
        healthColor = { healthR, healthG, healthB },
        powerColor = { powerR, powerG, powerB },
        healthRect = healthRect or GetTrackerPreviewRelativeRect(healthBar, sourceFrame),
        powerRect = powerRect or GetTrackerPreviewRelativeRect(powerBar, sourceFrame),
        portraitRect = portraitRect or GetTrackerPreviewRelativeRect(portraitFrame, sourceFrame),
        hasPortrait = portraitRect ~= nil or (portraitFrame and portraitFrame.IsShown and portraitFrame:IsShown() or false),
        settings = playerSettings,
    }
end

local function BuildKUITrackerUnitFramePreview(sc, yOffset, ct, onTrackerClick)
    local width = math.max(320, GetSCSafeWidth(sc) - 20)
    local frame = CreateFrame("Frame", nil, sc, "BackdropTemplate")
    frame:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -yOffset)
    frame:SetSize(width, 238)

    if KT.AddBackdrop then
        KT:AddBackdrop(frame, 0.04, 0.04, 0.05, 0.94)
    end
    if KT.AddBorder then
        KT:AddBorder(frame, 0.18, 0.18, 0.18, 0.9)
    end

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT_PATH, 12, "OUTLINE")
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -10)
    title:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
    title:SetText(LText("Unitframe Tracker Preview"))

    local subtitle = frame:CreateFontString(nil, "OVERLAY")
    subtitle:SetFont(FONT_PATH, 10, "")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetTextColor(0.76, 0.76, 0.78, 1)
    subtitle:SetText(LText("Live layout using your current player frame, tracker size, side and offsets."))

    local canvas = CreateFrame("Frame", nil, frame)
    canvas:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -38)
    canvas:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)

    local dragButton, dragTrackerKey, dragIndex, dragTarget, dragGhost
    local dragStartX, dragStartY, dragActive
    local dragEndTime = 0

    local function FindTrackerDropTarget(group, cursorX, cursorY)
        local bestIndex, bestDistance
        for index = 1, (group._trackerSlotCount or 0) do
            local button = group._trackerSlots and group._trackerSlots[index]
            if button and button:IsShown() then
                local left, right = button:GetLeft(), button:GetRight()
                local bottom, top = button:GetBottom(), button:GetTop()
                if left and right and bottom and top then
                    if cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top then
                        return index
                    end
                    local centerX = (left + right) * 0.5
                    local centerY = (bottom + top) * 0.5
                    local distance = (cursorX - centerX) ^ 2 + (cursorY - centerY) ^ 2
                    if not bestDistance or distance < bestDistance then
                        bestDistance = distance
                        bestIndex = index
                    end
                end
            end
        end
        return bestIndex
    end

    local function EnsureTrackerDragGhost()
        if dragGhost then return dragGhost end
        dragGhost = CreateFrame("Frame", nil, frame)
        dragGhost:SetFrameStrata("TOOLTIP")
        dragGhost:SetSize(36, 36)
        dragGhost:SetAlpha(0.75)
        dragGhost._icon = dragGhost:CreateTexture(nil, "ARTWORK")
        dragGhost._icon:SetAllPoints()
        dragGhost:Hide()
        return dragGhost
    end

    local function ClearTrackerDrag()
        if dragButton then
            dragButton:SetAlpha(1)
            local group = dragButton:GetParent()
            local targetButton = group and group._trackerSlots and dragTarget
                and group._trackerSlots[dragTarget]
            if targetButton and targetButton ~= dragButton then
                targetButton:SetAlpha(1)
            end
        end
        if dragGhost then dragGhost:Hide() end
        frame:SetScript("OnUpdate", nil)
        dragButton, dragTrackerKey, dragIndex, dragTarget = nil, nil, nil, nil
        dragStartX, dragStartY, dragActive = nil, nil, nil
    end

    local function FinishTrackerDrag()
        if not dragButton then return end

        local changed = false
        local barKey = "kui_" .. tostring(dragTrackerKey)
        if dragActive and dragTarget and dragIndex ~= dragTarget and ns.SwapTrackedSpells then
            changed = ns.SwapTrackedSpells(barKey, dragIndex, dragTarget) == true
        end

        local wasDragged = dragActive == true
        if wasDragged then
            dragEndTime = GetTime()
        end
        ClearTrackerDrag()

        if changed then
            Refresh()
            RefreshCDMRuntime(barKey)
            if KT and KT.RefreshPage then
                C_Timer.After(0, function() KT:RefreshPage(true) end)
            end
        end
    end

    local function BeginTrackerDrag(button, trackerKey, index, group)
        if dragButton then return end

        local cursorX, cursorY = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        dragButton = button
        dragTrackerKey = trackerKey
        dragIndex = index
        dragTarget = index
        dragStartX = cursorX
        dragStartY = cursorY
        dragActive = false

        button:SetScript("OnUpdate", function(self)
            if not IsMouseButtonDown("LeftButton") then
                self:SetScript("OnUpdate", nil)
                FinishTrackerDrag()
                return
            end

            local nextX, nextY = GetCursorPosition()
            if not dragActive and (nextX - dragStartX) ^ 2 + (nextY - dragStartY) ^ 2 >= 25 then
                self:SetScript("OnUpdate", nil)
                dragActive = true
                local ghost = EnsureTrackerDragGhost()
                ghost:SetSize(button:GetWidth(), button:GetHeight())
                ghost._icon:SetTexture(button._trackerIconTexture)
                ghost._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                ghost:Show()
                button:SetAlpha(0.3)
                GameTooltip:Hide()

                frame:SetScript("OnUpdate", function()
                    if not IsMouseButtonDown("LeftButton") then
                        FinishTrackerDrag()
                        return
                    end

                    local gx, gy = GetCursorPosition()
                    local cursorUIX, cursorUIY = gx / scale, gy / scale
                    ghost:ClearAllPoints()
                    ghost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorUIX / (ghost:GetScale() or 1), cursorUIY / (ghost:GetScale() or 1))

                    local nextTarget = FindTrackerDropTarget(group, cursorUIX, cursorUIY)
                    if nextTarget and nextTarget ~= dragTarget then
                        if dragTarget and group._trackerSlots[dragTarget] and group._trackerSlots[dragTarget] ~= dragButton then
                            group._trackerSlots[dragTarget]:SetAlpha(1)
                        end
                        dragTarget = nextTarget
                        if group._trackerSlots[dragTarget] and group._trackerSlots[dragTarget] ~= dragButton then
                            group._trackerSlots[dragTarget]:SetAlpha(0.65)
                        end
                    end
                end)
            end
        end)
    end

    local previewInfo = GetTrackerPreviewFrameInfo()
    local hasKUIUF = _G["KullThranUI_UF_Player"] or (KT and KT.db and KT.db.profile and KT.db.profile.unitFrames
        and KT.db.profile.unitFrames.enable ~= false
        and KT.db.profile.unitFrames.enabledFrames and KT.db.profile.unitFrames.enabledFrames.player ~= false)
    local hasIntegratedUF = hasKUIUF or (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("UnhaltedUnitFrames"))
    local unitWidth = ClampTrackerPreviewNumber(previewInfo.width, 150, math.max(150, width - 96))
    local unitHeight = ClampTrackerPreviewNumber(previewInfo.height, 48, 96)

    local unitFrame = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    unitFrame:SetSize(unitWidth, unitHeight)
    unitFrame:SetPoint("CENTER", canvas, "CENTER", 0, 8)
    if KT.AddBackdrop then
        KT:AddBackdrop(unitFrame, 0.07, 0.08, 0.10, 1)
    end
    if KT.AddBorder then
        KT:AddBorder(unitFrame, 0.23, 0.23, 0.24, 1)
    end

    local function ApplyPreviewRect(region, rect, r, g, b, a)
        if not region then return end
        region:ClearAllPoints()
        if rect then
            region:SetPoint("TOPLEFT", unitFrame, "TOPLEFT", math.floor(unitWidth * rect.x + 0.5), -math.floor(unitHeight * rect.y + 0.5))
            region:SetSize(
                ClampTrackerPreviewNumber(math.floor(unitWidth * rect.width + 0.5), 4, unitWidth),
                ClampTrackerPreviewNumber(math.floor(unitHeight * rect.height + 0.5), 4, unitHeight)
            )
        else
            region:SetPoint("TOPLEFT", unitFrame, "TOPLEFT", 2, -2)
            region:SetPoint("BOTTOMRIGHT", unitFrame, "BOTTOMRIGHT", -2, 2)
        end
        region:SetColorTexture(r, g, b, a or 1)
        region:Show()
    end

    local portrait = unitFrame:CreateTexture(nil, "ARTWORK")
    if previewInfo.hasPortrait and previewInfo.portraitRect then
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", unitFrame, "TOPLEFT", math.floor(unitWidth * previewInfo.portraitRect.x + 0.5), -math.floor(unitHeight * previewInfo.portraitRect.y + 0.5))
        portrait:SetSize(
            ClampTrackerPreviewNumber(math.floor(unitWidth * previewInfo.portraitRect.width + 0.5), 12, unitWidth),
            ClampTrackerPreviewNumber(math.floor(unitHeight * previewInfo.portraitRect.height + 0.5), 12, unitHeight)
        )
        if SetPortraitTexture then
            SetPortraitTexture(portrait, "player")
        else
            portrait:SetColorTexture(0.18, 0.20, 0.24, 1)
        end
        portrait:Show()
    else
        portrait:Hide()
    end

    local hpBar = unitFrame:CreateTexture(nil, "ARTWORK")
    ApplyPreviewRect(hpBar, previewInfo.healthRect, previewInfo.healthColor[1], previewInfo.healthColor[2], previewInfo.healthColor[3], 0.95)

    local powerBar = unitFrame:CreateTexture(nil, "ARTWORK")
    if previewInfo.powerRect then
        ApplyPreviewRect(powerBar, previewInfo.powerRect, previewInfo.powerColor[1], previewInfo.powerColor[2], previewInfo.powerColor[3], 0.95)
    else
        powerBar:Hide()
    end

    local textSettings = previewInfo.settings or {}
    local nameText = unitFrame:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(FONT_PATH, ClampTrackerPreviewNumber(textSettings.leftTextSize or math.floor(unitHeight * 0.18), 9, 18), "OUTLINE")
    nameText:SetPoint("LEFT", hpBar, "LEFT", 5 + (textSettings.leftTextX or 0), textSettings.leftTextY or 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetTextColor(previewInfo.classColor.r or 1, previewInfo.classColor.g or 1, previewInfo.classColor.b or 1, 1)
    nameText:SetText(previewInfo.playerName or "Player")
    if textSettings.leftTextContent == "none" then
        nameText:Hide()
    end

    local valueText = unitFrame:CreateFontString(nil, "OVERLAY")
    valueText:SetFont(FONT_PATH, ClampTrackerPreviewNumber(textSettings.rightTextSize or math.floor(unitHeight * 0.18), 9, 18), "OUTLINE")
    valueText:SetPoint("RIGHT", hpBar, "RIGHT", -5 + (textSettings.rightTextX or 0), textSettings.rightTextY or 0)
    valueText:SetJustifyH("RIGHT")
    valueText:SetTextColor(1, 1, 1, 1)
    valueText:SetText(previewInfo.playerHealthText or "")
    if textSettings.rightTextContent == "none" or not previewInfo.playerHealthText then
        valueText:Hide()
    end

    local sourceText = frame:CreateFontString(nil, "OVERLAY")
    sourceText:SetFont(FONT_PATH, 9, "")
    sourceText:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    sourceText:SetTextColor(0.62, 0.66, 0.72, 0.95)
    sourceText:SetJustifyH("RIGHT")
    sourceText:SetText(previewInfo.sourceName or "PlayerFrame")

    local function CreateTrackerPreviewIcon(parent, trackerKey, identifier, size, showCooldownText, index)
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetSize(size, size)
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        if KT.AddBackdrop then
            KT:AddBackdrop(button, 0.06, 0.06, 0.08, 1)
        end
        -- The live preview uses the icon artwork directly; tracker-color
        -- borders make the preview look like the runtime bars and are not useful
        -- for configuring the layout.
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
        icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:SetTexture(GetTrackerPreviewTexture(identifier))
        button._trackerIconTexture = GetTrackerPreviewTexture(identifier)

        parent._trackerSlots = parent._trackerSlots or {}
        parent._trackerSlots[index] = button
        parent._trackerSlotCount = math.max(parent._trackerSlotCount or 0, index)

        local cdText = button:CreateFontString(nil, "OVERLAY")
        cdText:SetFont(FONT_PATH, math.max(9, math.floor(size * 0.26)), "OUTLINE")
        cdText:SetPoint("CENTER", button, "CENTER", 0, 0)
        cdText:SetTextColor(1, 1, 1, 1)
        local previewCooldown = GetTrackerPreviewCooldownText(trackerKey, identifier)
        if showCooldownText and previewCooldown then
            cdText:SetText(previewCooldown)
        end

        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if type(identifier) == "number" and identifier > 0 then
                GameTooltip:SetSpellByID(identifier)
            elseif type(identifier) == "number" and identifier ~= 0 then
                GameTooltip:SetItemByID(DecodeItemID(identifier) or -identifier)
            end
            if onTrackerClick then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(LText("Left-click to open this tracker controls."), 0.35, 0.82, 0.95)
            end
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        button:SetScript("OnClick", function()
            if GetTime() - dragEndTime < 0.2 then return end
            if onTrackerClick then
                onTrackerClick(trackerKey)
            end
        end)
        button:SetScript("OnMouseDown", function(self, mouseButton)
            if mouseButton == "LeftButton" then
                BeginTrackerDrag(self, trackerKey, index, parent)
            end
        end)
        button:SetScript("OnMouseUp", function(self, mouseButton)
            if mouseButton == "LeftButton" then
                self:SetScript("OnUpdate", nil)
                FinishTrackerDrag()
            end
        end)

        return button
    end

    local previewGroups = {}
    for _, trackerKey in ipairs(KUI_TRACKER_PREVIEW_ORDER) do
        local tracker = ct and ct[trackerKey]
        if tracker and tracker.enabled ~= false then
            local identifiers = GetTrackerPreviewIdentifiers(ct, trackerKey)
            local count = math.max(1, math.min(#identifiers, tracker.maxIcons or #identifiers or 1))
            local iconSize = math.max(18, math.min(tracker.size or 36, 42))
            local spacing = 2
            local groupWidth = (count * iconSize) + ((count - 1) * spacing)
            local group = CreateFrame("Frame", nil, canvas)
            group:SetSize(groupWidth, iconSize)

            if trackerKey == "interrupt" and hasIntegratedUF and previewGroups.defensive then
                group:SetPoint("BOTTOMRIGHT", previewGroups.defensive, "TOPRIGHT", 0, 12)
            else
                AnchorTrackerPreviewGroup(group, unitFrame, tracker.side, tracker.x, tracker.y)
            end

            local label = group:CreateFontString(nil, "OVERLAY")
            label:SetFont(FONT_PATH, 9, "OUTLINE")
            label:SetTextColor(unpack(KUI_TRACKER_PREVIEW_COLORS[trackerKey] or { 1, 1, 1 }))
            label:SetText(LText(({
                interrupt = "Interrupt",
                defensive = "Defensive",
                trinket = "Trinket",
                potion = "Potions",
            })[trackerKey] or trackerKey))
            local labelUsesTopAnchor = (trackerKey == "interrupt" and hasIntegratedUF and previewGroups.defensive)
                or not (tracker.side or ""):find("BOTTOM")
            if not labelUsesTopAnchor then
                label:SetPoint("BOTTOM", group, "TOP", 0, 2)
            else
                label:SetPoint("TOP", group, "BOTTOM", 0, -2)
            end

            local alignRight = (tracker.side or ""):find("RIGHT") ~= nil
            for i = 1, count do
                local icon = CreateTrackerPreviewIcon(group, trackerKey, identifiers[i] or 0, iconSize, tracker.showText ~= false, i)
                if alignRight then
                    icon:SetPoint("TOPRIGHT", group, "TOPRIGHT", -((i - 1) * (iconSize + spacing)), 0)
                else
                    icon:SetPoint("TOPLEFT", group, "TOPLEFT", (i - 1) * (iconSize + spacing), 0)
                end
            end
            previewGroups[trackerKey] = group
        end
    end

    return frame:GetHeight()
end

ns.ToggleUnlockMode = function()
    local UM = KT and KT.GetModule and KT:GetModule("UnlockMode", true)
    if UM then
        if UM.isOpen then
            UM:CloseUnlockMode(false)
        else
            UM:OpenUnlockMode()
        end
        isUnlocked = UM.isOpen and true or false
        return
    end

    if EditModeManagerFrame and EditModeManagerFrame.EnterEditMode then
        if EditModeManagerFrame:IsEditModeActive() then
            if EditModeManagerFrame.ExitEditMode then
                EditModeManagerFrame:ExitEditMode()
            elseif EditModeManagerFrame.CloseButton and EditModeManagerFrame.CloseButton.Click then
                EditModeManagerFrame.CloseButton:Click()
            end
        else
            EditModeManagerFrame:EnterEditMode()
        end
        isUnlocked = EditModeManagerFrame:IsEditModeActive()
        return
    end

    isUnlocked = not isUnlocked
    if not lockPanel then
        lockPanel = CreateFrame("Frame", "KUI_CDM_UnlockPanel", UIParent, "BackdropTemplate")
        lockPanel:SetSize(180, 50); lockPanel:SetPoint("TOP", 0, -50); lockPanel:SetFrameStrata("DIALOG")

        if KT.AddBackdrop then KT:AddBackdrop(lockPanel, KT.BG_COLOR.r, KT.BG_COLOR.g, KT.BG_COLOR.b, 0.96) end
        if KT.AddBorder then KT:AddBorder(lockPanel, ACCENT.r, ACCENT.g, ACCENT.b, 1) end

        local title = lockPanel:CreateFontString(nil, "OVERLAY")
        title:SetFont(FONT_PATH, 12, "OUTLINE")
        title:SetText(string.format("|cff%02x%02x%02x%s|r", ACCENT.r * 255, ACCENT.g * 255, ACCENT.b * 255, LText("Bars Unlocked")))
        title:SetPoint("TOP", 0, -8)

        local btn = CreateFrame("Button", nil, lockPanel, "UIPanelButtonTemplate")
        btn:SetSize(100, 22); btn:SetPoint("BOTTOM", 0, 6); btn:SetText(LText("Lock & Save"))
        btn:SetScript("OnClick", function() ns.ToggleUnlockMode() end)
    end

    if isUnlocked then
        if KT.MenuPrincipal then KT.MenuPrincipal:Hide() end
        lockPanel:Show()
        if KT.MovableElements then
-- PESTANA: CUSTOM BARS
            if ns.BuildAllCDMBars then ns.BuildAllCDMBars() end
            for key, el in pairs(KT.MovableElements) do
                if key:match("^CDM_") or key:match("^PROGBAR_") then
                    local frame = el.getFrame and el.getFrame()
                    if frame then
                        frame:SetMovable(true)

                        local ov = unlockOverlays[key]
                        if not ov then
                            ov = CreateFrame("Button", nil, frame, "BackdropTemplate")
                            ov:SetFrameStrata("DIALOG")
                            local tex = ov:CreateTexture(nil, "BACKGROUND")
                            tex:SetAllPoints()
                            tex:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.4)
                            if KT.AddBorder then KT:AddBorder(ov, ACCENT.r, ACCENT.g, ACCENT.b, 1) end

                            local lbl = ov:CreateFontString(nil, "OVERLAY")
                            lbl:SetFont(FONT_PATH, 10, "OUTLINE")
                            lbl:SetPoint("CENTER")
                            lbl:SetText(el.label or key)

                            ov:RegisterForDrag("LeftButton")
                            ov:SetScript("OnDragStart", function() frame:StartMoving() end)
                            ov:SetScript("OnDragStop", function()
                                frame:StopMovingOrSizing()
                                if el.savePosition then
                                    -- Siempre guardar como CENTER/CENTER relativo a UIParent
                                    -- para que savePosition funcione independientemente del anchor original
                                    local cx, cy = frame:GetCenter()
                                    if cx and cy then
                                        local fScale   = frame:GetEffectiveScale()
                                        local uiScale  = UIParent:GetEffectiveScale()
                                        local uiW, uiH = UIParent:GetSize()
                                        local nx       = (cx * fScale / uiScale) - uiW * 0.5
                                        local ny       = (cy * fScale / uiScale) - uiH * 0.5
                                        el.savePosition(nil, "CENTER", "CENTER", nx, ny,
                                            el.getScale and el.getScale() or 1)
                                    end
                                end
                            end)
                            unlockOverlays[key] = ov
                        end

                        local w, h = 100, 36
                        if el.getSize then
                            w, h = el.getSize()
                        elseif frame.GetSize then
                            w, h = frame:GetSize()
                        end

                        ov:SetSize(math.max(w, 10), math.max(h, 10))
                        ov:ClearAllPoints()
                        ov:SetPoint("CENTER", frame, "CENTER")
                        ov:Show()
                    end
                end
            end
        end
    else
        lockPanel:Hide()
        for _, ov in pairs(unlockOverlays) do ov:Hide() end
        if KT.MenuPrincipal then KT.MenuPrincipal:Show() end
        Refresh()
    end
end

-- ============================================================================
-- LIVE PREVIEW & SPELL PICKER
-- ============================================================================
local _cdmPreview
local _cdmHeaderFixedH = 0

local function UpdateCDMPreview()
    if _cdmPreview and _cdmPreview.Update then
        _cdmPreview:Update()
    end
end

local function UpdateCDMPreviewAndResize(sc)
    UpdateCDMPreview()

    -- Fallback: if we cannot rebuild the page (KT:RefreshPage), try to keep the sticky host and scrollChild height sane.
    if not (_cdmPreview and _cdmHeaderFixedH > 0 and sc) then return end

    

    -- Ensure the scroll child is tall enough so the preview doesn't overlap content when it grows.
    if sc.SetHeight then
        local newTotal = _cdmHeaderFixedH + (_cdmPreview:GetHeight() * (_cdmPreview:GetScale() or 1)) + 800
        pcall(function() sc:SetHeight(newTotal) end)
    end
end

local function GetTrackedList(bd)
    local t = {}
    if not bd then return t end

    if bd.customSpells then
        for i, v in ipairs(bd.customSpells) do t[i] = v end
        return t
    end

    if bd.trackedSpells and #bd.trackedSpells > 0 then
        for i, v in ipairs(bd.trackedSpells) do t[i] = v end
        if bd.extraSpells then
            for i, v in ipairs(bd.extraSpells) do t[#t + 1] = v end
        end
        return t
    end

    -- Para barras por defecto: leer del CDM directamente
    if ns.GetCDMSpellsForBar and bd.key then
        local allSpells = ns.GetCDMSpellsForBar(bd.key)
        if allSpells then
            for _, sp in ipairs(allSpells) do
                if sp.spellID and sp.isDisplayed then t[#t + 1] = sp.spellID end
            end
        end
    end

    if #t == 0 and bd.extraSpells then
        for _, eid in ipairs(bd.extraSpells) do t[#t + 1] = eid end
    end
    return t
end

local _spellPickerMenu
local function ShowSpellPicker(anchorFrame, barKey, slotIndex, excludeSet, onSelect)
    if _spellPickerMenu then _spellPickerMenu:Hide() end
    local allSpells = ns.GetCDMSpellsForBar and ns.GetCDMSpellsForBar(barKey) or {}
    if not allSpells or #allSpells == 0 then return end

    local menuW = 210
    local ITEM_H = 26
    local MAX_H = 260

    local menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(300)
    menu:SetClampedToScreen(true)
    menu:SetSize(menuW, 10)

    if KT.AddBackdrop then KT:AddBackdrop(menu, 0.08, 0.08, 0.10, 0.98) end
    if KT.AddBorder then KT:AddBorder(menu, 0.2, 0.2, 0.2, 1) end

    local inner = CreateFrame("Frame", nil, menu)
    inner:SetWidth(menuW)
    inner:SetPoint("TOPLEFT")

    local mH = 4

    if slotIndex then
        local rmItem = CreateFrame("Button", nil, inner)
        rmItem:SetHeight(ITEM_H)
        rmItem:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH)
        rmItem:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH)

        local rmLbl = rmItem:CreateFontString(nil, "OVERLAY")
        rmLbl:SetFont(FONT_PATH, 11, "OUTLINE")
        rmLbl:SetPoint("LEFT", 10, 0); rmLbl:SetText(LText("Remove Spell")); rmLbl:SetTextColor(0.7, 0.7, 0.7, 0.85)

        local rmHl = rmItem:CreateTexture(nil, "ARTWORK")
        rmHl:SetAllPoints(); rmHl:SetColorTexture(1, 1, 1, 0); rmHl:SetAlpha(0)

        rmItem:SetScript("OnEnter",
            function()
                rmLbl:SetTextColor(1, 1, 1, 1); rmHl:SetColorTexture(1, 1, 1, 0.08); rmHl:SetAlpha(1)
            end)
        rmItem:SetScript("OnLeave", function()
            rmLbl:SetTextColor(0.7, 0.7, 0.7, 0.85); rmHl:SetAlpha(0)
        end)
        rmItem:SetScript("OnClick", function()
            menu:Hide()
            ns.RemoveTrackedSpell(barKey, slotIndex)
            Refresh(); RefreshCDMRuntime(barKey); UpdateCDMPreview()
        end)
        mH = mH + ITEM_H

        local div = inner:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1); div:SetColorTexture(1, 1, 1, 0.10)
        div:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH - 4)
        div:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH - 4)
        mH = mH + 9
    end

    local inputWrap = CreateFrame("Frame", nil, inner)
    inputWrap:SetHeight(ITEM_H + 4)
    inputWrap:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH)
    inputWrap:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH)

    local input = CreateFrame("EditBox", nil, inputWrap)
    input:SetFontObject("ChatFontNormal")
    input:SetSize(menuW - 20, ITEM_H)
    input:SetPoint("CENTER")
    input:SetAutoFocus(false)
    if KT and KT.AddBackdrop then KT:AddBackdrop(input, 0, 0, 0, 0.5) end
    input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    input:SetScript("OnEnterPressed", function(self)
        local val = tonumber(self:GetText())
        if val and val > 0 then
            menu:Hide()
            if onSelect then onSelect(val, false) end
        end
    end)
    local pht = input:CreateFontString(nil, "OVERLAY")
    pht:SetFont(FONT_PATH, 11)
    pht:SetTextColor(0.5, 0.5, 0.5, 1)
    pht:SetPoint("LEFT", 5, 0)
    pht:SetText(LText("Enter Spell ID..."))
    input:SetScript("OnEditFocusGained", function() pht:Hide() end)
    input:SetScript("OnEditFocusLost", function(self) if self:GetText()=="" then pht:Show() end end)

    mH = mH + ITEM_H + 8

    local div2 = inner:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1); div2:SetColorTexture(1, 1, 1, 0.10)
    div2:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH)
    div2:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH)
    mH = mH + 5

    local function MakeItem(sp, isDisabled)
        local item = CreateFrame("Button", nil, inner)
        item:SetHeight(ITEM_H)
        item:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH)
        item:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH)

        local ico = item:CreateTexture(nil, "ARTWORK")
        local icoSz = ITEM_H - 2
        ico:SetSize(icoSz, icoSz); ico:SetPoint("RIGHT", item, "RIGHT", -6, 0)
        if sp.icon then ico:SetTexture(sp.icon) end
        ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local lbl = item:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT_PATH, 11, "OUTLINE")
        lbl:SetPoint("LEFT", 10, 0); lbl:SetPoint("RIGHT", ico, "LEFT", -5, 0)
        lbl:SetJustifyH("LEFT"); lbl:SetWordWrap(false); lbl:SetMaxLines(1)
        lbl:SetText(sp.name)

        local hl = item:CreateTexture(nil, "ARTWORK")
        hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0); hl:SetAlpha(0)

        if isDisabled then
            lbl:SetTextColor(0.7, 0.7, 0.7, 0.3)
            ico:SetDesaturated(true); ico:SetAlpha(0.4)
        else
            lbl:SetTextColor(0.7, 0.7, 0.7, 0.85)
            item:SetScript("OnEnter",
                function()
                    lbl:SetTextColor(1, 1, 1, 1); hl:SetColorTexture(1, 1, 1, 0.08); hl:SetAlpha(1)
                end)
            item:SetScript("OnLeave", function()
                lbl:SetTextColor(0.7, 0.7, 0.7, 0.85); hl:SetAlpha(0)
            end)
            item:SetScript("OnClick", function()
                menu:Hide()
                if onSelect then onSelect(sp.spellID, sp.isExtra) end
            end)
        end
        mH = mH + ITEM_H
    end

    local bd = SelectedCDMBar()
    local isCustomBar = bd and bd.customSpells ~= nil
    local itemsDisplayed, itemsOther, itemsDisabled = {}, {}, {}

    for _, sp in ipairs(allSpells) do
        local excluded = excludeSet and (excludeSet[sp.cdID] or excludeSet[sp.spellID])
        if not excluded then
            if not sp.isKnown then
                itemsDisabled[#itemsDisabled + 1] = sp
            elseif sp.isDisplayed then
                itemsDisplayed[#itemsDisplayed + 1] = sp
            else
                itemsOther[#itemsOther + 1] = sp
            end
        end
    end

    for _, sp in ipairs(itemsDisplayed) do MakeItem(sp, false) end
    if #itemsDisplayed > 0 and (#itemsOther > 0 or #itemsDisabled > 0) then
        local div = inner:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1); div:SetColorTexture(1, 1, 1, 0.10)
        div:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH - 4); div:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH - 4)
        mH = mH + 9
    end
    for _, sp in ipairs(itemsOther) do MakeItem(sp, false) end
    if #itemsOther > 0 and #itemsDisabled > 0 then
        local div = inner:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1); div:SetColorTexture(1, 1, 1, 0.10)
        div:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH - 4); div:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH - 4)
        mH = mH + 9
    end
    for _, sp in ipairs(itemsDisabled) do MakeItem(sp, true) end

    local totalH = mH + 4
    inner:SetHeight(totalH)

    if totalH > MAX_H then
        menu:SetHeight(MAX_H)
        local sf = CreateFrame("ScrollFrame", nil, menu)
        sf:SetPoint("TOPLEFT"); sf:SetPoint("BOTTOMRIGHT")
        sf:SetFrameLevel(menu:GetFrameLevel() + 1)
        sf:EnableMouseWheel(true)
        sf:SetScrollChild(inner)
        inner:SetWidth(menuW)
        local scrollPos = 0
        local maxScroll = totalH - MAX_H
        sf:SetScript("OnMouseWheel", function(_, delta)
            scrollPos = math.max(0, math.min(maxScroll, scrollPos - delta * 30))
            sf:SetVerticalScroll(scrollPos)
        end)
    else
        menu:SetHeight(totalH)
        inner:SetParent(menu); inner:SetPoint("TOPLEFT")
    end

    menu:ClearAllPoints()
    menu:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -2)

    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetFrameStrata("FULLSCREEN_DIALOG")
    closer:SetFrameLevel(menu:GetFrameLevel() - 1)
    closer:SetAllPoints(UIParent)
    closer:SetScript("OnClick", function()
        menu:Hide(); closer:Hide()
    end)
    menu:HookScript("OnHide", function() closer:Hide() end)
    closer:Show()

    menu:Show()
    _spellPickerMenu = menu
end

local function BuildCDMLivePreview(parent, yOff, resolvePreviewBlock)
    local p = DB()
    if not p or not p.cdmBars or not p.cdmBars.bars then return 0 end

    local previewPad = 10
    local previewTitleHeight = 18
    local previewNavHeight = 0
    local previewTopInset = 60
    local previewFrame = CreateFrame("Frame", nil, parent)
    previewFrame:SetClipsChildren(false)

    local previewScale = UIParent:GetEffectiveScale() / parent:GetEffectiveScale()
    previewFrame:SetScale(previewScale)
    local localParentWidth = (parent:GetWidth() - previewPad * 2) / previewScale
    previewFrame:SetSize(localParentWidth, 200)
    previewFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", previewPad / previewScale, yOff / previewScale)

    local previewBg = previewFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
    previewBg:SetAllPoints()
    previewBg:SetColorTexture(0.05, 0.05, 0.05, 0.72)

    local previewTitle = previewFrame:CreateFontString(nil, "OVERLAY")
    previewTitle:SetFont(FONT_PATH, 12, "OUTLINE")
    previewTitle:SetPoint("TOP", previewFrame, "TOP", 0, -15)
    previewTitle:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
    previewTitle:SetText(LText("Layout Preview By Block"))

    local MAX_PREVIEW_ICONS = 30
    local dragSlot, dragIdx, dragGhost, insertIdx, dragMode, swapTargetIdx
    local dragEndTime = 0
    local activeGroupSlots = {}
    local activeGroupTrackedCount = 0
    local activeGridSlots = 0

    local function FindPreviewDropTarget(cursorX, cursorY)
        local limit = math.min(activeGroupTrackedCount, activeGridSlots)
        local bestIdx, bestDist
        for i = 1, limit do
            local slot = activeGroupSlots[i]
            if slot and slot:IsShown() then
                local left, right = slot:GetLeft(), slot:GetRight()
                local bottom, top = slot:GetBottom(), slot:GetTop()
                if left and right and bottom and top then
                    if cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top then
                        return i
                    end
                    local cx = (left + right) * 0.5
                    local cy = (bottom + top) * 0.5
                    local dx = cursorX - cx
                    local dy = cursorY - cy
                    local dist = (dx * dx) + (dy * dy)
                    if not bestDist or dist < bestDist then
                        bestDist = dist
                        bestIdx = i
                    end
                end
            end
        end
        return bestIdx
    end

    local function EnsureDragGhost()
        if dragGhost then return dragGhost end
        local g = CreateFrame("Frame", nil, UIParent)
        g:SetFrameStrata("TOOLTIP"); g:SetSize(36, 36); g:SetAlpha(0.7)
        g._icon = g:CreateTexture(nil, "ARTWORK"); g._icon:SetAllPoints()
        g:Hide(); dragGhost = g; return g
    end

    local insertLine = previewFrame:CreateTexture(nil, "OVERLAY", nil, 7)
    insertLine:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.9)
    insertLine:SetWidth(2); insertLine:Hide()

    local function CreatePreviewSlot(group, idx)
        local slot = CreateFrame("Button", nil, group)
        slot:SetSize(1, 1)
        slot:RegisterForClicks("LeftButtonUp", "RightButtonDown", "MiddleButtonDown")
        slot:SetHitRectInsets(-6, -6, -6, -6); slot:Hide()

        slot._bg = slot:CreateTexture(nil, "BACKGROUND")
        slot._bg:SetAllPoints(); slot._bg:SetColorTexture(0.08, 0.08, 0.08, 0.6)

        slot._icon = slot:CreateTexture(nil, "ARTWORK")
        slot._icon:SetAllPoints()

        slot._edges = {}
        for e = 1, 4 do
            slot._edges[e] = slot:CreateTexture(nil, "OVERLAY", nil, 7)
            slot._edges[e]:SetColorTexture(0, 0, 0, 1)
        end
        slot._edges[1]:SetPoint("TOPLEFT"); slot._edges[1]:SetPoint("TOPRIGHT"); slot._edges[1]:SetHeight(1)
        slot._edges[2]:SetPoint("BOTTOMLEFT"); slot._edges[2]:SetPoint("BOTTOMRIGHT"); slot._edges[2]:SetHeight(1)
        slot._edges[3]:SetPoint("TOPLEFT"); slot._edges[3]:SetPoint("BOTTOMLEFT"); slot._edges[3]:SetWidth(1)
        slot._edges[4]:SetPoint("TOPRIGHT"); slot._edges[4]:SetPoint("BOTTOMRIGHT"); slot._edges[4]:SetWidth(1)

        local hlEdges = {}
        for e = 1, 4 do
            hlEdges[e] = slot:CreateTexture(nil, "OVERLAY", nil, 7)
            hlEdges[e]:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1); hlEdges[e]:Hide()
        end
        hlEdges[1]:SetHeight(2); hlEdges[1]:SetPoint("TOPLEFT"); hlEdges[1]:SetPoint("TOPRIGHT")
        hlEdges[2]:SetHeight(2); hlEdges[2]:SetPoint("BOTTOMLEFT"); hlEdges[2]:SetPoint("BOTTOMRIGHT")
        hlEdges[3]:SetWidth(2); hlEdges[3]:SetPoint("TOPLEFT", hlEdges[1], "BOTTOMLEFT"); hlEdges[3]:SetPoint("BOTTOMLEFT", hlEdges[2], "TOPLEFT")
        hlEdges[4]:SetWidth(2); hlEdges[4]:SetPoint("TOPRIGHT", hlEdges[1], "BOTTOMRIGHT"); hlEdges[4]:SetPoint("BOTTOMRIGHT", hlEdges[2], "TOPRIGHT")
        slot._hlEdges = hlEdges

        local cdTxt = slot:CreateFontString(nil, "OVERLAY")
        cdTxt:SetFont(FONT_PATH, 11, "OUTLINE")
        cdTxt:SetPoint("CENTER", slot, "CENTER", 0, 0)
        cdTxt:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1); cdTxt:Hide()
        slot._cdText = cdTxt

        local kbTxt = slot:CreateFontString(nil, "OVERLAY")
        kbTxt:SetFont(FONT_PATH, 12, "OUTLINE")
        kbTxt:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
        kbTxt:SetJustifyH("LEFT"); kbTxt:Hide()
        kbTxt:SetTextColor(1, 1, 1, 1)
        slot._keybindText = kbTxt

        slot:SetScript("OnEnter", function(self)
            local barConf = SelectedCDMBar()
            if not dragSlot then
                for e = 1, 4 do hlEdges[e]:Show() end
            end
            if barConf and barConf.showTooltip and self._spellID then
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                GameTooltip:SetSpellByID(self._spellID)
                GameTooltip:Show()
            end
        end)
        slot:SetScript("OnLeave", function()
            if not dragSlot then
                for e = 1, 4 do hlEdges[e]:Hide() end
            end
            GameTooltip:Hide()
        end)
        slot._slotIdx = idx

        slot:SetScript("OnClick", function(self, button)
            if GetTime() - dragEndTime < 0.2 then return end
            local barConf = SelectedCDMBar(); if not barConf then return end
            if barConf.key == "buffs" then return end
            local si = self._slotIdx

            if button == "MiddleButton" then
                if barConf.customSpells and barConf.customSpells[si] then
                    ns.RemoveTrackedSpell(barConf.key, si); Refresh(); RefreshCDMRuntime(barConf.key); UpdateCDMPreview()
                end
            elseif button == "RightButton" or button == "LeftButton" then
                local fullTracked = GetTrackedList(barConf)
                local isOccupied = (fullTracked[si] ~= nil) and (fullTracked[si] ~= 0)
                local excl = {}
                if barConf.customSpells then
                    for _, sid in ipairs(barConf.customSpells) do excl[sid] = true end
                elseif barConf.trackedSpells then
                    for _, sid in ipairs(barConf.trackedSpells) do excl[sid] = true end
                    if barConf.extraSpells then for _, sid in ipairs(barConf.extraSpells) do excl[sid] = true end end
                end

                ShowSpellPicker(self, barConf.key, isOccupied and si or nil, excl, function(newSpellID, isExtra)
                    if isOccupied then
                        ns.ReplaceTrackedSpell(barConf.key, si, newSpellID, isExtra)
                    else
                        ns.AddTrackedSpell(barConf.key, newSpellID, isExtra)
                    end
                    Refresh(); RefreshCDMRuntime(barConf.key); UpdateCDMPreview()
                end)
            end
        end)

        slot:SetScript("OnMouseDown", function(self, button)
            if button ~= "LeftButton" then return end
            local dragBarConf = SelectedCDMBar()
            if dragBarConf and dragBarConf.key == "buffs" then return end
            local cx, cy = GetCursorPosition()
            local pendingStartX, pendingStartY = cx, cy
            self:SetScript("OnUpdate", function()
                local nx, ny = GetCursorPosition()
                if (nx - pendingStartX) ^ 2 + (ny - pendingStartY) ^ 2 >= 9 then
                    self:SetScript("OnUpdate", nil)
                    local barConf = SelectedCDMBar(); if not barConf then return end
                    local t = GetTrackedList(barConf)
                    if not t or not t[self._slotIdx] or t[self._slotIdx] == 0 then return end
                    dragSlot = self; dragIdx = self._slotIdx
                    local ghost = EnsureDragGhost()
                    ghost:SetSize(barConf.iconSize or 36, barConf.iconSize or 36)
                    ghost._icon:SetTexture(self._icon:GetTexture()); ghost._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    ghost:SetScale(0.5); ghost:Show()
                    GameTooltip:Hide()
                    self:SetAlpha(0.3)
                    previewFrame:SetScript("OnUpdate", function(_, dt)
                        if not IsMouseButtonDown("LeftButton") then
                            previewFrame:SetScript("OnUpdate", nil)
                            local changed = false
                            if dragMode == "swap" and insertIdx and insertIdx ~= dragIdx then
                                changed = ns.SwapTrackedSpells(barConf.key, dragIdx, insertIdx)
                            elseif dragMode == "insert" and insertIdx then
                                local toIdx = insertIdx > dragIdx and (insertIdx - 1) or insertIdx
                                if toIdx ~= dragIdx then
                                    changed = ns.MoveTrackedSpell(barConf.key, dragIdx, toIdx)
                                end
                            end
                            dragSlot = nil
                            if dragGhost then dragGhost:Hide() end
                            self:SetAlpha(1)
                            insertIdx = nil
                            insertLine:Hide(); if swapTargetIdx then
                                for e = 1, 4 do activeGroupSlots[swapTargetIdx]._hlEdges[e]:Hide() end; swapTargetIdx = nil
                            end
                            dragMode = nil
                            dragEndTime = GetTime()
                            if changed then
                                Refresh(); RefreshCDMRuntime(barConf.key); UpdateCDMPreview()
                            end
                            return
                        end
                        local gx, gy = GetCursorPosition()
                        local sc = UIParent:GetEffectiveScale()
                        local cursorX, cursorY = gx / sc, gy / sc
                        local ghostScale = dragGhost:GetScale() or 1
                        dragGhost:ClearAllPoints()
                        dragGhost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX / ghostScale, cursorY / ghostScale)

                        local newTarget = FindPreviewDropTarget(cursorX, cursorY)
                        if newTarget and newTarget <= (activeGroupTrackedCount or 0) then
                            insertIdx = newTarget; dragMode = "swap"
                            if swapTargetIdx and swapTargetIdx ~= newTarget then
                                for e = 1, 4 do activeGroupSlots[swapTargetIdx]._hlEdges[e]:Hide() end
                            end
                            swapTargetIdx = newTarget; for e = 1, 4 do activeGroupSlots[newTarget]._hlEdges[e]:Show() end
                        elseif swapTargetIdx then
                            for e = 1, 4 do activeGroupSlots[swapTargetIdx]._hlEdges[e]:Hide() end
                            swapTargetIdx = nil
                            insertIdx = nil
                        end
                    end)
                end
            end)
        end)
        slot:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
        return slot
    end

    local barGroups = {}
    local function GetBarGroup(index)
        if not barGroups[index] then
            local group = CreateFrame("Frame", nil, previewFrame)
            group.slots = {}
            for i = 1, MAX_PREVIEW_ICONS do group.slots[i] = CreatePreviewSlot(group, i) end
            
            local addBtn = CreateFrame("Button", nil, group)
            addBtn:SetSize(36, 36); addBtn:Hide()
            local addBg = addBtn:CreateTexture(nil, "BACKGROUND")
            addBg:SetAllPoints(); addBg:SetColorTexture(0.08, 0.08, 0.08, 0.6)
            local addLbl = addBtn:CreateFontString(nil, "OVERLAY")
            addLbl:SetFont(FONT_PATH, 22, "OUTLINE"); addLbl:SetPoint("CENTER", 0, 1); addLbl:SetText("+")
            addBtn:SetScript("OnClick", function(self)
                local barConf = p.cdmBars.bars[index]
                if not barConf then return end
                ShowSpellPicker(self, barConf.key, nil, nil, function(newSpellID, isExtra)
                    ns.AddTrackedSpell(barConf.key, newSpellID, isExtra); Refresh(); RefreshCDMRuntime(barConf.key); UpdateCDMPreview()
                end)
            end)
            group.addBtn = addBtn
            group.addLbl = addLbl

            local bg = group:CreateTexture(nil, "BACKGROUND", nil, -8)
            bg:SetColorTexture(0, 0, 0, 0.4); bg:Hide()
            group.bg = bg

            local invisBtn = CreateFrame("Button", nil, group)
            invisBtn:SetAllPoints()
            invisBtn:SetFrameLevel(group:GetFrameLevel() + 10)
            invisBtn:SetScript("OnClick", function()
                selectedCDMBarIndex = index
                Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
            end)
            group.invisBtn = invisBtn

            barGroups[index] = group
        end
        return barGroups[index]
    end

    previewFrame.Update = function(self)
        if not p.cdmBars.bars then return end
        
        for _, group in pairs(barGroups) do group:Hide() end
        local startY = -previewTopInset

        local validBars = {}
        local orderVal = { buffs = 1, cooldowns = 2, utility = 3 }
        for i, b in ipairs(p.cdmBars.bars) do
            if not b.isKUITracker then
                table.insert(validBars, { index = i, conf = b })
            end
        end

        table.sort(validBars, function(a, b)
            local oa = orderVal[a.conf.key] or 100
            local ob = orderVal[b.conf.key] or 100
            if oa ~= ob then return oa < ob end
            return a.index < b.index
        end)

        for _, item in ipairs(validBars) do
            local index = item.index
            local barConf = item.conf
            if barConf.enabled ~= false then
                local group = GetBarGroup(index)
                group:Show()

                local isSelected = (index == selectedCDMBarIndex)
                if isSelected then
                    group:SetAlpha(1)
                    group.invisBtn:Hide()
                    activeGroupSlots = group.slots
                else
                    group:SetAlpha(0.15)
                    group.invisBtn:Show()
                end

                local iconSize = barConf.iconSize or 36
                local iconH = (barConf.iconShape == "cropped") and math.floor(iconSize * 0.80 + 0.5) or iconSize
                local spacing = barConf.spacing or 2
                local numRows = math.max(1, math.min(3, barConf.numRows or 1))

                local tracked = GetTrackedList(barConf)
                local count = #tracked
                if isSelected then
                    activeGroupTrackedCount = count
                end
                
                local grow = barConf.growDirection or "RIGHT"
                local isHoriz = (grow == "RIGHT" or grow == "LEFT")
                local stride = math.max(1, math.ceil(count / numRows))
                if isSelected then
                    activeGridSlots = stride * numRows
                end

                local stepW = iconSize + spacing
                local stepH = iconH + spacing
                local barW, barH
                if isHoriz then
                    barW = (stride * iconSize) + ((stride - 1) * spacing)
                    barH = (numRows * iconH) + ((numRows - 1) * spacing)
                else
                    barW = (numRows * iconSize) + ((numRows - 1) * spacing)
                    barH = (stride * iconH) + ((stride - 1) * spacing)
                end

                local totalW = barW
                local totalH = math.max(barH, iconH)
                local barStartX = math.max(0, math.floor((localParentWidth - totalW) / 2))
                local contentStartX = barStartX

                local function GetPreviewSlotOffsets(idxNum)
                    local idx = idxNum - 1
                    local col = idx % stride
                    local row = math.floor(idx / stride)
                    local rowStart = row * stride
                    local iconsInRow = math.min(stride, count - rowStart)

                    if grow == "RIGHT" then
                        local flippedRow = (numRows - 1) - row
                        local rowOffset = math.floor((stride - iconsInRow) * stepW / 2)
                        return contentStartX + col * stepW + rowOffset, -flippedRow * stepH
                    elseif grow == "LEFT" then
                        local flippedRow = (numRows - 1) - row
                        local rowOffset = math.floor((stride - iconsInRow) * stepW / 2)
                        return contentStartX + barW - iconSize - (col * stepW + rowOffset), -flippedRow * stepH
                    elseif grow == "DOWN" then
                        local flippedRow = (numRows - 1) - row
                        local rowOffset = math.floor((stride - iconsInRow) * stepH / 2)
                        return contentStartX + flippedRow * stepW, -(col * stepH + rowOffset)
                    else
                        local rowOffset = math.floor((stride - iconsInRow) * stepH / 2)
                        return contentStartX + row * stepW, -(barH - iconH - (col * stepH + rowOffset))
                    end
                end

                group:SetSize(localParentWidth, totalH)
                group:SetPoint("TOPLEFT", previewFrame, "TOPLEFT", 0, startY)

                local groupGridSlots = stride * numRows
                for i = 1, math.min(groupGridSlots, MAX_PREVIEW_ICONS) do
                    local slot = group.slots[i]
                    local px, py = GetPreviewSlotOffsets(i)

                    slot:SetSize(iconSize, iconH); slot:ClearAllPoints(); slot:SetPoint("TOPLEFT", group, "TOPLEFT", px, py)
                    slot._baseX = px; slot._baseY = py
                    slot._cdText:SetFont(FONT_PATH, math.max(10, math.floor(iconSize * 0.28)), "OUTLINE")
                    slot._keybindText:SetFont(FONT_PATH, barConf.keybindSize or 13, GetKeybindFontFlags(barConf))

                    if i <= count then
                        local id = tracked[i]
                        slot._spellID = nil
                        local tex = nil
                        if id and id > 0 then
                            slot._spellID = id
                            tex = C_Spell.GetSpellTexture(id)
                        elseif id and id < 0 then
                            local itemID = DecodeItemID(id) or -id
                            tex = C_Item.GetItemIconByID(itemID)
                        end

                        if tex then
                            slot._icon:SetTexture(tex); slot._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        else
                            slot._icon:SetTexture(nil); slot._icon:SetColorTexture(0.12, 0.12, 0.14, 1)
                        end
                        ApplyPreviewShapeToSlot(slot, tostring(barConf.iconShape or "none"))

                        if barConf.showKeybind and id then
                            local keyStr = GetPreviewKeybind(id)
                            if keyStr then
                                slot._keybindText:SetText(keyStr); slot._keybindText:Show()
                            else
                                slot._keybindText:Hide()
                            end
                        else
                            slot._keybindText:Hide()
                        end
                    else
                        slot._icon:SetTexture(nil); slot._icon:SetColorTexture(0.08, 0.08, 0.08, 0.6)
                        ApplyPreviewShapeToSlot(slot, tostring(barConf.iconShape or "none"))
                        slot._keybindText:Hide()
                    end
                    if slot._bg then
                        slot._bg:ClearAllPoints()
                        slot._bg:SetAllPoints()
                    end
                    slot:Show()
                end

                for i = groupGridSlots + 1, MAX_PREVIEW_ICONS do group.slots[i]:Hide() end

                if isSelected then
                    local addPx = contentStartX + barW + spacing
                    local addPy = -math.floor((totalH - iconH) / 2)
                    group.addBtn:SetSize(iconSize, iconH); group.addBtn:ClearAllPoints()
                    group.addBtn:SetPoint("TOPLEFT", group, "TOPLEFT", addPx, addPy); group.addBtn:Show()
                    group.addLbl:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 0.6)
                else
                    group.addBtn:Hide()
                end

                if barConf.barBgEnabled then
                    group.bg:ClearAllPoints()
                    group.bg:SetPoint("TOPLEFT", group, "TOPLEFT", barStartX, 0)
                    group.bg:SetPoint("BOTTOMRIGHT", group, "TOPLEFT", barStartX + barW, -barH)
                    group.bg:SetColorTexture(barConf.barBgR or 0, barConf.barBgG or 0, barConf.barBgB or 0, 0.5)
                    group.bg:Show()
                else
                    group.bg:Hide()
                end

                startY = startY - totalH - 15
            end
        end

        self:SetHeight(math.abs(startY) + 15)
    end

    local _unlocked = ns.IsUnlocked and ns.IsUnlocked() or false
    local iconContainer = CreateFrame("Frame", nil, previewFrame)
    iconContainer:SetSize(130, 40)
    iconContainer:SetPoint("BOTTOMRIGHT", previewFrame, "BOTTOMRIGHT", -10, 10)
    
    local unlockBtn = CreateFrame("Button", nil, iconContainer, "BackdropTemplate")
    unlockBtn:SetSize(60, 40)
    unlockBtn:SetPoint("RIGHT", iconContainer, "RIGHT", 0, 0)
    local unlockIco = unlockBtn:CreateTexture(nil, "ARTWORK")
    unlockIco:SetAllPoints()
    unlockIco:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\extra\\unlockbars.png")
    unlockIco:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if ACCENT then unlockIco:SetVertexColor(ACCENT.r, ACCENT.g, ACCENT.b, 1) end
    unlockBtn:SetScript("OnClick", function()
        if ns.ToggleUnlockMode then ns.ToggleUnlockMode() end
        if KT and KT.RefreshPage then KT:RefreshPage(true) end
    end)
    unlockBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(_unlocked and LText("Lock Bars") or LText("Unlock Bars"))
        GameTooltip:Show()
    end)
    unlockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    local restoreBtn = CreateFrame("Button", nil, iconContainer, "BackdropTemplate")
    restoreBtn:SetSize(60, 40)
    restoreBtn:SetPoint("RIGHT", unlockBtn, "LEFT", -10, 0)
    local restoreIco = restoreBtn:CreateTexture(nil, "ARTWORK")
    restoreIco:SetAllPoints()
    restoreIco:SetTexture("Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\icons\\extra\\restoredefaults.png")
    restoreIco:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if ACCENT then restoreIco:SetVertexColor(ACCENT.r, ACCENT.g, ACCENT.b, 1) end
    restoreBtn:SetScript("OnClick", function()
        StaticPopup_Show("KUI_CDM_RESTORE_DEFAULTS")
    end)
    restoreBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(LText("Restore Defaults"))
        GameTooltip:Show()
    end)
    restoreBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    _cdmPreview = previewFrame
    previewFrame:Update()
    return previewFrame:GetHeight() * previewScale
end


-- ============================================================================
-- PESTANA: CUSTOM BARS
-- ============================================================================
local function BuildCustomTrackerTab(sc, W, startY, p)
    local y, h = startY, 0
    local ct = p.customTracker
    local trackerSectionAnchors = {}

    local function FocusTrackerSection(trackerKey)
        local target = trackerSectionAnchors[trackerKey]
        if target then
            ScrollToCDMOptionBlock(target)
        end
    end

    _, h = W:SectionHeader(sc, LText("KUI Custom Tracker"), -y); y = y + h
    _, h = W:Label(sc, LText("Configure KullThranUI-specific trackers (Interrupts, Defensives, Trinkets, etc)."), -y,
        11); y = y + h

    y = y + BuildKUITrackerUnitFramePreview(sc, y, ct, FocusTrackerSection) + 12

    local trackers = {
        { key = "interrupt", label = LText("Interrupts") },
        { key = "defensive", label = LText("Racials & Defensives") },
        { key = "trinket",   label = LText("Trinkets") },
        { key = "potion",    label = LText("Potions & Consumables") },
    }

    for _, t in ipairs(trackers) do
        local tk = t.key
        local spells = (ct[tk].auto and ns.BuildAutoTrackerSpells) and ns.BuildAutoTrackerSpells(tk) or ct[tk].spells
        local trackerAnchor = CreateFrame("Frame", nil, sc)
        trackerAnchor:SetSize(1, 1)
        trackerAnchor:SetPoint("TOPLEFT", sc, "TOPLEFT", 10, -y)
        trackerSectionAnchors[tk] = trackerAnchor

        _, h = W:SectionHeader(sc, t.label, -y); y = y + h

        _, h = W:DualRow(sc, -y,
            {
                type = "toggle",
                text = LText("Enable Tracker"),
                getValue = function() return ct[tk].enabled end,
                setValue = function(
                    v)
                    ct[tk].enabled = v; Refresh()
                end
            },
            {
                type = "toggle",
                text = LText("Show Text"),
                getValue = function() return ct[tk].showText end,
                setValue = function(
                    v)
                    ct[tk].showText = v; Refresh()
                end
            }
        ); y = y + h

        local function GetTrackerBar()
            local barKey = "kui_" .. tk
            for _, b in ipairs(p.cdmBars.bars or {}) do
                if b.key == barKey then return b end
            end
            return nil
        end
        _, h = W:Toggle(sc, LText("Show Keybinds"), -y,
            function()
                local b = GetTrackerBar()
                if b then return b.showKeybind ~= false end
                return tk == "potion" or tk == "trinket"
            end,
            function(v)
                local b = GetTrackerBar()
                if not b then return end
                b.showKeybind = v
                if b.keybindOutline == nil then
                    b.keybindOutline = true
                end
                RefreshCDMRuntime(b.key)
                Refresh()
            end
        ); y = y + h

        local autoLabel = (tk == "potion") and LText("Auto-detect items in bags") or LText("Auto-detect spells (by spec)")
        _, h = W:Toggle(sc, autoLabel, -y,
            function() return ct[tk].auto ~= false end,
            function(v)
                ct[tk].auto = v
                if v then ct[tk].spells = {} end
                Refresh()
            end
        ); y = y + h

        if tk == "potion" then
            _, h = W:Dropdown(sc, LText("Potion Quality"), -y,
                {
                    highest = LText("Highest Available"),
                    most = LText('Most Available'),
                    ["1"] = LText("Quality 1"),
                    ["2"] = LText("Quality 2"),
                    ["3"] = LText("Quality 3 (Legacy)"),
                },
                function() return tostring(ct[tk].potionQuality or "highest") end,
                function(v)
                    v = tostring(v or "highest")
                    if v ~= "most" and v ~= "1" and v ~= "2" and v ~= "3" then v = "highest" end
                    ct[tk].potionQuality = v
                    if ns.ScheduleKUITrackerSync then
                        ns.ScheduleKUITrackerSync(0.05, "potion_quality")
                    end
                    Refresh()
                end,
                { "highest", "most", "1", "2", "3" }
            ); y = y + h

            _, h = W:Toggle(sc, LText("Track Mana Potions"), -y,
                function() return ct[tk].trackManaPotion == true end,
                function(v)
                    ct[tk].trackManaPotion = (v == true)
                    if v == true and (ct[tk].maxIcons or 3) < 4 then
                        ct[tk].maxIcons = 4
                    end
                    Refresh()
                end
            ); y = y + h
        end

        _, h = W:DualRow(sc, -y,
            {
                type = "slider",
                text = LText("X Offset"),
                min = -500,
                max = 500,
                step = 1,
                getValue = function()
                    return ct[tk].x or
                        0
                end,
                setValue = function(v)
                    ct[tk].x = v; Refresh()
                end
            },
            {
                type = "slider",
                text = LText("Y Offset"),
                min = -500,
                max = 500,
                step = 1,
                getValue = function()
                    return ct[tk].y or
                        0
                end,
                setValue = function(v)
                    ct[tk].y = v; Refresh()
                end
            }
        ); y = y + h

        _, h = W:Slider(sc, LText("Icon Size"), -y, function() return ct[tk].size or 36 end,
            function(v)
                ct[tk].size = v; Refresh()
            end, 16, 80, 1); y = y + h

        if tk ~= "interrupt" then
            local maxAllowed = (tk == "trinket") and 2 or 6
            _, h = W:Slider(sc, LText("Max Icons"), -y,
                function() return ct[tk].maxIcons or ((tk == "trinket") and 2 or 2) end,
                function(v)
                    ct[tk].maxIcons = v
                    Refresh()
                end, 1, maxAllowed, 1); y = y + h
        end

        -- Rendering drag & drop area for tracker spells
        local scW = GetSCSafeWidth(sc)
        local sz = 36
        local rowX = 0

        -- The row below is the editable order for this tracker. Keep drag state
        -- local to each section so moving one tracker never affects another.
        local trackerDragButtons = {}
        local trackerDragButton
        local trackerDragIndex
        local trackerDragTarget
        local trackerDragGhost
        local trackerDragPending = false
        local trackerDragActive = false
        local trackerDragStartX
        local trackerDragStartY

        local function GetTrackerCursorPosition()
            local x, y = GetCursorPosition()
            if not x or not y then return nil, nil end
            local scale = UIParent:GetEffectiveScale() or 1
            return x / scale, y / scale
        end

        local function ClearTrackerDrag()
            if trackerDragButton then
                trackerDragButton:SetAlpha(1)
            end
            if trackerDragTarget and trackerDragTarget._trackerDropHighlight then
                trackerDragTarget._trackerDropHighlight:Hide()
            end
            if trackerDragGhost then
                trackerDragGhost:Hide()
            end
            trackerDragButton = nil
            trackerDragIndex = nil
            trackerDragTarget = nil
            trackerDragPending = false
            trackerDragActive = false
            trackerDragStartX = nil
            trackerDragStartY = nil
        end

        local function FindTrackerDropTarget(cursorX, cursorY)
            local bestButton
            local bestDistance
            local limit = math.max(sz * 1.5, 54)
            for _, candidate in ipairs(trackerDragButtons) do
                local centerX, centerY = candidate:GetCenter()
                if centerX and centerY then
                    local dx = cursorX - centerX
                    local dy = cursorY - centerY
                    local distance = math.sqrt(dx * dx + dy * dy)
                    if distance <= limit and (not bestDistance or distance < bestDistance) then
                        bestButton = candidate
                        bestDistance = distance
                    end
                end
            end
            return bestButton
        end

        local function EnsureTrackerDragGhost()
            if trackerDragGhost or not trackerDragButton then return end
            trackerDragGhost = CreateFrame("Frame", nil, sc)
            trackerDragGhost:SetSize(sz, sz)
            trackerDragGhost:SetFrameStrata("TOOLTIP")
            trackerDragGhost:SetAlpha(0.9)
            trackerDragGhost._icon = trackerDragGhost:CreateTexture(nil, "ARTWORK")
            trackerDragGhost._icon:SetAllPoints()
            trackerDragGhost._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            trackerDragGhost._icon:SetTexture(trackerDragButton._trackerIconTexture:GetTexture())
        end

        local function FinishTrackerDrag()
            if not trackerDragButton then
                ClearTrackerDrag()
                return
            end

            local sourceButton = trackerDragButton
            local sourceIndex = trackerDragIndex
            local targetButton = trackerDragTarget
            local targetIndex = targetButton and targetButton._trackerRowIndex
            local changed = false

            if trackerDragActive and targetIndex and sourceIndex ~= targetIndex
                and ns.SwapTrackedSpells then
                changed = ns.SwapTrackedSpells("kui_" .. tk, sourceIndex, targetIndex) == true
            end

            if trackerDragActive then
                sourceButton._trackerDragSuppressUntil = GetTime() + 0.25
            end
            ClearTrackerDrag()

            if changed then
                Refresh()
                RefreshCDMRuntime("kui_" .. tk)
                if KT.RefreshPage then KT:RefreshPage(true) end
            end
        end

        local function BeginTrackerDrag(button, index)
            if trackerDragButton then ClearTrackerDrag() end
            local x, y = GetTrackerCursorPosition()
            if not x or not y then return end
            trackerDragButton = button
            trackerDragIndex = index
            trackerDragPending = true
            trackerDragStartX = x
            trackerDragStartY = y
        end

        sc:HookScript("OnUpdate", function()
            if not trackerDragButton then return end
            if not IsMouseButtonDown("LeftButton") then
                FinishTrackerDrag()
                return
            end

            local cursorX, cursorY = GetTrackerCursorPosition()
            if not cursorX or not cursorY then return end

            if trackerDragPending then
                local dx = cursorX - trackerDragStartX
                local dy = cursorY - trackerDragStartY
                if math.sqrt(dx * dx + dy * dy) >= 5 then
                    trackerDragPending = false
                    trackerDragActive = true
                    trackerDragButton:SetAlpha(0.35)
                    EnsureTrackerDragGhost()
                    trackerDragGhost:Show()
                end
            end

            if trackerDragActive then
                local target = FindTrackerDropTarget(cursorX, cursorY)
                if target ~= trackerDragTarget then
                    if trackerDragTarget and trackerDragTarget._trackerDropHighlight then
                        trackerDragTarget._trackerDropHighlight:Hide()
                    end
                    trackerDragTarget = target
                    if trackerDragTarget and trackerDragTarget ~= trackerDragButton
                        and trackerDragTarget._trackerDropHighlight then
                        trackerDragTarget._trackerDropHighlight:Show()
                    end
                end
                if trackerDragGhost then
                    trackerDragGhost:ClearAllPoints()
                    trackerDragGhost:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX, cursorY)
                end
            end
        end)

        -- Normalise a tracker entry to a comparable key so the same spell/item
        -- dropped or picked twice (even with a different encoding) never ends up
        -- duplicated in ct[tk].spells.
        local function TrackerEntryKey(entry)
            return tostring(entry or "")
        end
        local function TrackerAlreadyPresent(list, entry)
            local k = TrackerEntryKey(entry)
            for i = 1, #(list or {}) do
                if TrackerEntryKey(list[i]) == k then return true end
            end
            return false
        end
        -- Add a spell/item to a manual tracker list, deduping and flipping auto off
        -- only when the dropped entry was not one of the auto-detected ones.
        local function TrackerAddEntry(entry)
            if not entry then return false end
            if ct[tk].auto ~= false then
                if tk == "potion" and ns.IsPotionTrackerSlotID
                    and ns.IsPotionTrackerSlotID(entry) then
                    if ns.SetTrackerSpellSuppressed then
                        ns.SetTrackerSpellSuppressed(tk, entry, false)
                    end
                    return true
                end
                local autoList = (ns.BuildAutoTrackerSpells and ns.BuildAutoTrackerSpells(tk)) or {}
                if TrackerAlreadyPresent(autoList, entry) then
                    -- It is already part of the auto set; just ensure it isn't
                    -- suppressed so it shows up again.
                    if ns.SetTrackerSpellSuppressed then
                        ns.SetTrackerSpellSuppressed(tk, entry, false)
                    end
                    return true
                end
                -- Breaking auto: seed the manual list with the current auto set so
                -- the player keeps everything they had, then append the new one.
                local seed = {}
                for _, sid in ipairs(autoList) do
                    if not TrackerAlreadyPresent(seed, sid) then
                        seed[#seed + 1] = sid
                    end
                end
                ct[tk].spells = seed
                ct[tk].auto = false
            end
            if not ct[tk].spells then ct[tk].spells = {} end
            if TrackerAlreadyPresent(ct[tk].spells, entry) then return true end
            ct[tk].spells[#ct[tk].spells + 1] = entry
            return true
        end
        -- Remove a spell/item, supporting both manual removal and auto suppression.
        local function TrackerRemoveEntry(entry)
            if not entry then return end
            if ct[tk].auto ~= false then
                if ns.SetTrackerSpellSuppressed then
                    ns.SetTrackerSpellSuppressed(tk, entry, true)
                end
                return
            end
            for i = #(ct[tk].spells or {}), 1, -1 do
                if TrackerEntryKey(ct[tk].spells[i]) == TrackerEntryKey(entry) then
                    table.remove(ct[tk].spells, i)
                    return
                end
            end
        end

        -- Build a candidate list for the picker: the tracker's own auto set (so
        -- hidden/removed entries can be re-added) plus, for trinkets, the two
        -- trinket slots, and for potions, the curated health/prepot item lists.
        local function BuildTrackerCandidates()
            local out = {}
            local seen = {}
            local function Push(spellOrItemID, name, icon, isItem)
                local key = TrackerEntryKey(spellOrItemID)
                if seen[key] then return end
                seen[key] = true
                out[#out + 1] = { id = spellOrItemID, name = name, icon = icon, isItem = isItem, key = key }
            end

            if tk == "potion" and ns.POTION_TRACKER_SLOT_ORDER then
                for _, slotID in ipairs(ns.POTION_TRACKER_SLOT_ORDER) do
                    local itemID, slotKey, slotLabel = GetPotionTrackerSlotInfo(slotID)
                    if slotKey ~= "mana" or ct[tk].trackManaPotion == true then
                        local itemName = itemID and C_Item.GetItemNameByID
                            and C_Item.GetItemNameByID(itemID)
                        local name = LText(slotLabel or "Potion")
                        if itemName then
                            name = name .. ": " .. itemName
                        end
                        local icon = itemID and C_Item.GetItemIconByID(itemID) or 134400
                        Push(slotID, name, icon, true)
                    end
                end
            end

            local autoList = (ct[tk].auto ~= false and ns.BuildAutoTrackerSpells and ns.BuildAutoTrackerSpells(tk)) or {}
            for _, sid in ipairs(autoList) do
                if type(sid) == "number" and sid > 0 then
                    Push(sid, C_Spell.GetSpellName(sid) or tostring(sid), C_Spell.GetSpellTexture(sid))
                elseif type(sid) == "number" and sid < 0 then
                    local itemID, _, slotLabel = GetPotionTrackerSlotInfo(sid)
                    itemID = itemID or DecodeItemID(sid)
                    if itemID then
                        local itemName = (C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or tostring(itemID)
                        local name = slotLabel and (LText(slotLabel) .. ": " .. itemName) or itemName
                        Push(sid, name, C_Item.GetItemIconByID(itemID))
                    end
                end
            end
            if ct[tk].auto ~= false and ns.CDMHealthItemsByID then
                for _, item in pairs(ns.CDMHealthItemsByID) do
                    if item and item.itemID and tonumber(item.cooldown) == 300 then
                        Push(ns.EncodeItemID and ns.EncodeItemID(item.itemID) or -item.itemID, item.name, C_Item.GetItemIconByID(item.itemID), true)
                    end
                end
            end
            if ct[tk].auto ~= false and ns.CDMPrepotItemIDs then
                for itemID in pairs(ns.CDMPrepotItemIDs) do
                    local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
                    Push(ns.EncodeItemID and ns.EncodeItemID(itemID) or -itemID, name or tostring(itemID), C_Item.GetItemIconByID(itemID), true)
                end
            end
            if tk == "trinket" then
                for _, slot in ipairs({ -13, -14 }) do
                    local invItemID = GetInventoryItemID("player", -slot)
                    local name = invItemID and (C_Item.GetItemNameByID and C_Item.GetItemNameByID(invItemID)) or (format("Trinket %d", -slot))
                    local icon = invItemID and C_Item.GetItemIconByID(invItemID) or 134400
                    Push(slot, name, icon, true)
                end
            end
            return out
        end

        local _trackerPicker = nil
        local function ShowTrackerPicker(anchor)
            if _trackerPicker then _trackerPicker:Hide() end
            local cand = BuildTrackerCandidates()
            local menuW = 230
            local ITEM_H = 26
            local MAX_H = 300
            local menu = CreateFrame("Frame", nil, UIParent)
            menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:SetFrameLevel(300)
            menu:SetClampedToScreen(true); menu:SetSize(menuW, 10)
            if KT.AddBackdrop then KT:AddBackdrop(menu, 0.08, 0.08, 0.10, 0.98) end
            if KT.AddBorder then KT:AddBorder(menu, 0.2, 0.2, 0.2, 1) end
            local inner = CreateFrame("Frame", nil, menu)
            inner:SetWidth(menuW); inner:SetPoint("TOPLEFT")
            local mH = 4

            local tip = menu:CreateFontString(nil, "OVERLAY")
            tip:SetFont(FONT_PATH, 11, "OUTLINE"); tip:SetTextColor(0.5, 0.5, 0.5, 0.9)
            tip:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -4)
            tip:SetText(LText("Drag a spell/item or pick below"))

            local inputWrap = CreateFrame("Frame", nil, inner)
            inputWrap:SetHeight(ITEM_H + 4); inputWrap:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH)
            inputWrap:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH)
            local input = CreateFrame("EditBox", nil, inputWrap)
            input:SetFontObject("ChatFontNormal"); input:SetSize(menuW - 32, ITEM_H)
            input:SetPoint("LEFT", 2, 0); input:SetAutoFocus(false)
            if KT.AddBackdrop then KT:AddBackdrop(input, 0, 0, 0, 0.5) end
            input:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            input:SetScript("OnEnterPressed", function(self)
                local val = tonumber(self:GetText())
                self:ClearFocus()
                if not val or val <= 0 then return end
                menu:Hide()
                TrackerAddEntry(val)
                Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
            end)
            input:SetScript("OnTextChanged", function(self)
                local text = (self:GetText() or ""):lower()
                for _, row in ipairs(rows or {}) do
                    row:Hide()
                    if row._nameKey and row._nameKey:find(text) ~= nil then row:Show() end
                end
            end)
            local pht = input:CreateFontString(nil, "OVERLAY")
            pht:SetFont(FONT_PATH, 11); pht:SetTextColor(0.5, 0.5, 0.5, 1)
            pht:SetPoint("LEFT", 5, 0); pht:SetText(LText("Spell ID  /  Item ID"))
            input:SetScript("OnEditFocusGained", function() pht:Hide() end)
            input:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then pht:Show() end end)
            mH = mH + ITEM_H + 6
            local rows = {}

            local function MakeRow(entry)
                local row = CreateFrame("Button", nil, inner)
                row:SetHeight(ITEM_H)
                row:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH)
                row:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH)
                row._nameKey = (entry.name or ""):lower()
                local ico = row:CreateTexture(nil, "ARTWORK")
                ico:SetSize(ITEM_H - 2, ITEM_H - 2); ico:SetPoint("LEFT", 2, 0)
                if entry.icon then ico:SetTexture(entry.icon) end
                ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                local lbl = row:CreateFontString(nil, "OVERLAY")
                lbl:SetFont(FONT_PATH, 11, "OUTLINE")
                lbl:SetPoint("LEFT", ico, "RIGHT", 4, 0); lbl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                lbl:SetJustifyH("LEFT"); lbl:SetWordWrap(false); lbl:SetMaxLines(1)
                lbl:SetTextColor(0.7, 0.7, 0.7, 0.85)
                lbl:SetText(entry.name or tostring(entry.id))
                local hl = row:CreateTexture(nil, "ARTWORK")
                hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0); hl:SetAlpha(0)
                row:SetScript("OnEnter", function()
                    lbl:SetTextColor(1, 1, 1, 1); hl:SetColorTexture(1, 1, 1, 0.08); hl:SetAlpha(1)
                end)
                row:SetScript("OnLeave", function()
                    lbl:SetTextColor(0.7, 0.7, 0.7, 0.85); hl:SetAlpha(0)
                end)
                row:SetScript("OnClick", function()
                    menu:Hide()
                    TrackerAddEntry(entry.id)
                    Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
                end)
                mH = mH + ITEM_H
                rows[#rows + 1] = row
                return row
            end

            for _, entry in ipairs(cand) do MakeRow(entry) end

            local totalH = math.max(mH - 6, 60)
            inner:SetHeight(totalH)
            if totalH > MAX_H then
                menu:SetHeight(MAX_H)
                local sf = CreateFrame("ScrollFrame", nil, menu)
                sf:SetPoint("TOPLEFT", 0, -22); sf:SetPoint("BOTTOMRIGHT")
                sf:SetFrameLevel(menu:GetFrameLevel() + 1); sf:EnableMouseWheel(true)
                sf:SetScrollChild(inner)
                inner:SetWidth(menuW)
                local scrollPos = 0
                local maxScroll = totalH - MAX_H
                sf:SetScript("OnMouseWheel", function(_, delta)
                    scrollPos = math.max(0, math.min(maxScroll, scrollPos - delta * 30))
                    sf:SetVerticalScroll(scrollPos)
                end)
            else
                menu:SetHeight(totalH + 22)
                inner:SetParent(menu); inner:SetPoint("TOPLEFT", 0, -22)
            end
            menu:ClearAllPoints(); menu:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
            local closer = CreateFrame("Button", nil, UIParent)
            closer:SetFrameStrata("FULLSCREEN_DIALOG"); closer:SetFrameLevel(menu:GetFrameLevel() - 1)
            closer:SetAllPoints(UIParent)
            closer:SetScript("OnClick", function() menu:Hide(); closer:Hide() end)
            menu:HookScript("OnHide", function() closer:Hide(); _trackerPicker = nil end)
            closer:Show(); menu:Show(); _trackerPicker = menu
        end

        for si, sid in ipairs(spells) do
            local sidx = si
            local btn = CreateFrame("Button", nil, sc, "BackdropTemplate")
            btn:SetSize(sz, sz); btn:SetPoint("TOPLEFT", sc, "TOPLEFT", 10 + rowX, -y)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            if KT.AddBackdrop then KT:AddBackdrop(btn, 0.08, 0.08, 0.10, 1) end
            if KT.AddBorder then KT:AddBorder(btn, 0.2, 0.2, 0.2, 0.8) end
            btn._trackerRowIndex = sidx
            trackerDragButtons[#trackerDragButtons + 1] = btn

            local dropHighlight = btn:CreateTexture(nil, "OVERLAY")
            dropHighlight:SetAllPoints()
            dropHighlight:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.35)
            dropHighlight:Hide()
            btn._trackerDropHighlight = dropHighlight

            local ic = btn:CreateTexture(nil, "ARTWORK")
            ic:SetPoint("TOPLEFT", 2, -2); ic:SetPoint("BOTTOMRIGHT", -2, 2); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local slotItemID, _, slotLabel = GetPotionTrackerSlotInfo(sid)
            local decoded = slotItemID or DecodeItemID(sid)
            if sid > 0 then ic:SetTexture(C_Spell.GetSpellTexture(sid) or 134400)
            elseif decoded then ic:SetTexture(C_Item.GetItemIconByID(decoded) or 134400)
            elseif not slotLabel then ic:SetTexture(C_Item.GetItemIconByID(-sid) or 134400)
            else ic:SetTexture(134400) end
            btn._trackerIconTexture = ic

            btn:SetScript("OnMouseDown", function(self, button)
                if button == "LeftButton" then
                    BeginTrackerDrag(self, sidx)
                end
            end)
            btn:SetScript("OnMouseUp", function(self, button)
                if button == "LeftButton" then
                    FinishTrackerDrag()
                end
            end)

            local cdText = btn:CreateFontString(nil, "OVERLAY")
            cdText:SetFont(FONT_PATH, math.max(10, math.floor(sz * 0.28)), "OUTLINE")
            cdText:SetPoint("CENTER", btn, "CENTER", 0, 0)
            cdText:SetTextColor(1, 1, 1, 1)
            cdText:SetShadowOffset(0, 0)
            local previewCooldown = GetTrackerPreviewCooldownText(tk, sid)
            if previewCooldown then
                cdText:SetText(previewCooldown)
                cdText:Show()
            else
                cdText:Hide()
            end

            btn:SetScript("OnEnter", function()
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                if sid > 0 then
                    GameTooltip:SetSpellByID(sid)
                elseif decoded then
                    GameTooltip:SetItemByID(decoded)
                elseif slotLabel then
                    GameTooltip:AddLine(LText(slotLabel), 1, 1, 1)
                else
                    GameTooltip:SetItemByID(-sid)
                end
                GameTooltip:AddLine(LText("Right-click to remove"), 1, 0, 0); GameTooltip:AddLine(LText("Drag to reorder"), ACCENT.r, ACCENT.g, ACCENT.b); GameTooltip:Show()
                if KT.AddBorder then KT:AddBorder(btn, 1, 0.2, 0.2, 1) end
            end)
            btn:SetScript("OnLeave",
                function()
                    GameTooltip:Hide(); if KT.AddBorder then KT:AddBorder(btn, 0.2, 0.2, 0.2, 0.8) end
                end)
            btn:SetScript("OnClick",
                function(self, button)
                    if button == "RightButton" then
                        TrackerRemoveEntry(sid)
                        Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
                    elseif button == "LeftButton" and self._trackerDragSuppressUntil
                        and GetTime() < self._trackerDragSuppressUntil then
                        return
                    end
                end)

            rowX = rowX + sz + 2
            if (10 + rowX + sz) > (scW - 20) then
                rowX = 0; y = y + sz + 2
            end
        end

        local addBtn = CreateFrame("Button", nil, sc, "BackdropTemplate")
        addBtn:SetSize(sz, sz); addBtn:SetPoint("TOPLEFT", sc, "TOPLEFT", 10 + rowX, -y)
        if KT.AddBackdrop then KT:AddBackdrop(addBtn, 0.05, 0.18, 0.10, 0.9) end
        if KT.AddBorder then KT:AddBorder(addBtn, ACCENT.r, ACCENT.g, ACCENT.b, 0.6) end
        local al = addBtn:CreateFontString(nil, "OVERLAY")
        al:SetFont(FONT_PATH, 20, "OUTLINE")
        al:SetPoint("CENTER", addBtn, "CENTER", 0, 1)
        al:SetText("+")
        al:SetJustifyH("CENTER")
        al:SetJustifyV("MIDDLE")
        al:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)

        addBtn:SetScript("OnEnter",
            function()
                al:SetTextColor(1, 1, 1, 1); if KT.AddBorder then KT:AddBorder(addBtn, ACCENT.r, ACCENT.g, ACCENT.b, 1) end; GameTooltip
                    :SetOwner(addBtn, "ANCHOR_RIGHT"); GameTooltip:AddLine(LText("Drag & Drop a spell here"), ACCENT.r, ACCENT
                    .g, ACCENT.b); GameTooltip:AddLine(LText("to assign it to this tracker"), 1, 1, 1); GameTooltip:Show()
            end)
        addBtn:SetScript("OnLeave",
            function()
                al:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1); if KT.AddBorder then
                    KT:AddBorder(addBtn, ACCENT.r,
                        ACCENT.g, ACCENT.b, 0.6)
                end; GameTooltip:Hide()
            end)

        addBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local function OnTrackerDrop()
            local dropID = GetIDFromCursor()
            
            if dropID then
                TrackerAddEntry(dropID)
                ClearCursor(); Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
            else
                local infoType = GetCursorInfo()
                if infoType then
                    print("|cffff4444KullThranUI:|r Cannot track this object type: " .. tostring(infoType))
                end
            end
        end
        addBtn:SetScript("OnReceiveDrag", OnTrackerDrop)
        addBtn:SetScript("OnClick", function(self, button)
            if button == "LeftButton" then
                if GetCursorInfo() then
                    OnTrackerDrop()
                else
                    ShowTrackerPicker(self)
                end
            end
        end)

        y = y + sz + 10
        _, h = W:Spacer(sc, -y, 6); y = y + h
    end
    return y
end

-- ============================================================================
-- PESTANA: CUSTOM BARS
-- ============================================================================
local function BuildCDMBarsTab(sc, W, startY, p)
    local y, h = startY, 0

    _, h = W:SectionHeader(sc, LText("CDM Bars"), -y); y = y + h
    _, h = W:Label(sc, LText("Manage icon groups for cooldowns. Use the interactive preview below to add or remove spells."), -
        y, 11); y = y + h

    local cdmBars = p.cdmBars.bars or {}
    if #cdmBars == 0 then return y end

    local cdmLabels, cdmOrder = {}, {}
    for i, b in ipairs(cdmBars) do
        local keyStr = tostring(i)
        cdmLabels[keyStr] = b.name or b.key or ("Bar " .. i)
        cdmOrder[#cdmOrder + 1] = keyStr
    end

    _, h = W:Dropdown(sc, LText("Select Bar"), -y, cdmLabels,
        function() return tostring(selectedCDMBarIndex) end,
        function(v)
            selectedCDMBarIndex = tonumber(v) or 1; if KT.RefreshPage then KT:RefreshPage(true) end
        end,
        cdmOrder
    ); y = y + h

    y = y + AddCDMBuffsNoticeBlock(sc, W, y, SelectedCDMBar())

    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Use Blizzard Layout by Default"),
            getValue = function()
                return p.cdmBars.useBlizzardDisplayDefaults ~= false
            end,
            setValue = function(v)
                p.cdmBars.useBlizzardDisplayDefaults = v and true or false
                Refresh()
            end
        },
        {
            type = "toggle",
            text = LText("Prompt on Blizzard Changes"),
            getValue = function()
                return p.cdmBars.promptBlizzardLayoutChanges ~= false
            end,
            setValue = function(v)
                p.cdmBars.promptBlizzardLayoutChanges = v and true or false
            end
        }
    ); y = y + h

    _, h = W:Button(sc, LText("Import Blizzard Layout Now"), -y, function()
        if ns.ImportBlizzardDisplayedMainBars then
            ns.ImportBlizzardDisplayedMainBars(true, false)
            Refresh()
        else
            print("KUI: Blizzard CDM import unavailable.")
        end
    end, 260, nil, nil, "CENTER", 28); y = y + h

    _, h = W:Label(sc, LText("Imports the visible order from Blizzard CDM for Cooldowns, Utility and Buffs."), -y, 11); y = y + h

    ns.customBarTypeToCreate = ns.customBarTypeToCreate or "cooldowns"
    _, h = W:Dropdown(sc, LText("New Custom Bar Category"), -y, 
        { cooldowns = LText("Cooldowns"), utility = LText("Utility"), buffs = LText("Buffs") },
        function() return ns.customBarTypeToCreate end,
        function(v) 
            ns.customBarTypeToCreate = v 
            Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
        end,
        { "cooldowns", "utility", "buffs" }
    ); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "button",
            text = LText("+ Add Custom Bar"),
            onClick = function()
                if ns.AddCDMBar then
                    local newKey = ns.AddCDMBar(ns.customBarTypeToCreate)
                    if newKey then
                        for i, b in ipairs(p.cdmBars.bars) do
                            if b.key == newKey then
                                selectedCDMBarIndex = i
                                break
                            end
                        end
                    else
                        print("|cffff4444KullThranUI:|r Se ha alcanzado el límite de Custom Bars (" .. (ns.MAX_CUSTOM_BARS or 12) .. ").")
                    end
                else
                    print("KUI: AddCDMBar unavailable.")
                end
                Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
            end
        },
        {
            type = "button",
            text = LText("Delete Bar"),
            onClick = function()
                local bd = SelectedCDMBar()
                if bd and bd.key:match("^custom_") then
                    if ns.RemoveCDMBar then
                        ns.RemoveCDMBar(bd.key)
                    else
                        table.remove(p.cdmBars.bars, selectedCDMBarIndex)
                    end
                    selectedCDMBarIndex = 1; Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
                else
                    print("KUI: You cannot delete default Blizzard bars.")
                end
            end
        }
    ); y = y + h

    local bd = SelectedCDMBar()
    if not bd then return y end

    BuildCDMLivePreview(sc, -y)
    _, h = W:SectionHeader(sc, LText("Live Layout Preview"), -y); y = y + h
    local previewH = _cdmPreview and (_cdmPreview:GetHeight() * (_cdmPreview:GetScale() or 1)) or 0
    _cdmHeaderFixedH = y
    y = y + previewH + 15

    _, h = W:SectionHeader(sc, LText("Bar Layout"), -y); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Enabled"),
            getValue = function() return bd.enabled end,
            setValue = function(v)
                bd.enabled = v; Refresh()
            end
        },
        {
            type = "dropdown",
            text = LText("Visibility"),
            values = { always = LText("Always"), in_combat = LText("In Combat"), mouseover = LText("Mouseover"), never = LText("Never") },
            order = { "always", "in_combat", "mouseover", "never" },
            getValue = function()
                return
                    bd.barVisibility or "always"
            end,
            setValue = function(v)
                bd.barVisibility = v; RefreshVis()
            end
        }
    ); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "slider",
            text = LText("Bar Opacity"),
            min = 0,
            max = 100,
            step = 5,
            getValue = function()
                return math.floor(((bd.barBgAlpha or 1.0) * 100) +
                    0.5)
            end,
            setValue = function(v)
                bd.barBgAlpha = v / 100; Refresh()
            end
        },
        {
            type = "toggle",
            text = LText("Show Background"),
            getValue = function() return bd.barBgEnabled end,
            setValue = function(
                v)
                bd.barBgEnabled = v; Refresh(); RefreshCDMRuntime(bd.key); UpdateCDMPreview()
            end
        }
    ); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "slider",
            text = LText("Number of Rows"),
            min = 1,
            max = 8,
            step = 1,
            getValue = function()
                return bd.numRows or
                    1
            end,
            setValue = function(v)
                bd.numRows = v; Refresh()
                if KT.RefreshPage then KT:RefreshPage(true) else UpdateCDMPreviewAndResize(sc) end
            end
        },
        {
            type = "dropdown",
            text = LText("Grow Direction"),
-- PESTANA: CUSTOM BARS
            order = { "RIGHT", "LEFT", "UP", "DOWN" },
            getValue = function()
                return
                    bd.growDirection or "RIGHT"
            end,
            setValue = function(v)
                bd.growDirection = v; Refresh()
                if KT.RefreshPage then KT:RefreshPage(true) else UpdateCDMPreviewAndResize(sc) end
            end
        }
    ); y = y + h

    local anchorOptions = {
        none = "Free (Draggable)",
        partyframe = "Party Frame",
        playerframe = "Player Frame",
        castbar =
        "Cast Bar"
    }
    local anchorOrder = { "none", "partyframe", "playerframe", "castbar" }
    if bd.key == "cooldowns" then
        anchorOptions.castbar = nil; for i, k in ipairs(anchorOrder) do
            if k == "castbar" then
                table.remove(anchorOrder, i); break
            end
        end
    end
    for _, otherBar in ipairs(cdmBars) do
        if otherBar.key ~= bd.key then
            anchorOptions[otherBar.key] = "Bar: " .. (otherBar.name or otherBar.key); anchorOrder[#anchorOrder + 1] =
                otherBar.key
        end
    end

    _, h = W:Dropdown(sc, LText("Anchored To"), -y, anchorOptions, function() return bd.anchorTo or "none" end,
        function(v)
            bd.anchorTo = v; Refresh()
        end, anchorOrder); y = y + h

    if bd.anchorTo and bd.anchorTo ~= "none" then
        _, h = W:Dropdown(sc, LText("Anchor Position"), -y, { left = LText("Left"), right = LText("Right"), top = LText("Top"), bottom = LText("Bottom") },
            function() return bd.anchorPosition or "right" end, function(v)
                bd.anchorPosition = v; Refresh()
            end, { "left", "right", "top", "bottom" }); y = y + h
        _, h = W:DualRow(sc, -y,
            {
                type = "slider",
                text = LText("Anchor Offset X"),
                min = -200,
                max = 200,
                step = 1,
                getValue = function()
                    return bd
                        .anchorOffsetX or 0
                end,
                setValue = function(v)
                    bd.anchorOffsetX = v; Refresh()
                end
            },
            {
                type = "slider",
                text = LText("Anchor Offset Y"),
                min = -200,
                max = 200,
                step = 1,
                getValue = function()
                    return bd
                        .anchorOffsetY or 0
                end,
                setValue = function(v)
                    bd.anchorOffsetY = v; Refresh()
                end
            }
        ); y = y + h
    end

    _, h = W:Slider(sc, LText("Global Bar Scale"), -y, function() return math.floor(((bd.barScale or 1.0) * 100) + 0.5) end,
        function(v)
            bd.barScale = v / 100; Refresh()
        end, 40, 200, 5); y = y + h

    local strataValues = {
        BACKGROUND = LText("Background"),
        LOW = LText("Low"),
        MEDIUM = LText("Medium (Default)"),
        HIGH = LText("High"),
        DIALOG = LText("Dialog"),
        TOOLTIP = LText("Tooltip"),
    }
    local strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "TOOLTIP" }
    _, h = W:Dropdown(sc, LText("Frame Strata"), -y, strataValues,
        function() return tostring(bd.barStrata or "MEDIUM"):upper() end,
        function(v)
            bd.barStrata = tostring(v):upper(); Refresh()
        end, strataOrder); y = y + h

    _, h = W:SectionHeader(sc, LText("Icon Display"), -y); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "slider",
            text = LText("Icon Scale"),
            min = 16,
            max = 80,
            step = 1,
            getValue = function()
                return bd.iconSize or
                    36
            end,
            setValue = function(v)
                bd.iconSize = v; Refresh()
                if KT.RefreshPage then KT:RefreshPage(true) else UpdateCDMPreviewAndResize(sc) end
            end
        },
        {
            type = "slider",
            text = LText("Icon Spacing"),
            min = -4,
            max = 24,
            step = 1,
            getValue = function()
                return bd.spacing or
                    2
            end,
            setValue = function(v)
                bd.spacing = v
                if bd.isKUITracker then
                    bd.spacingCustomized = true
                end
                Refresh()
                if KT.RefreshPage then KT:RefreshPage(true) else UpdateCDMPreviewAndResize(sc) end
            end
        }
    ); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "dropdown",
            text = LText("Custom Icon Shape"),
            values = { none = LText("None"), cropped = LText("Cropped"), square = LText("Square"), circle = LText("Circle"), csquare = LText("Curved Square"), diamond = LText("Diamond"), hexagon = LText("Hexagon"), portrait = LText("Portrait"), shield = LText("Shield") },
            order = { "none", "cropped", "square", "circle", "csquare", "diamond", "hexagon", "portrait", "shield" },
            getValue = function()
                return
                    bd.iconShape or "none"
            end,
            setValue = function(v)
                bd.iconShape = v; Refresh()
                if KT.RefreshPage then KT:RefreshPage(true) else UpdateCDMPreviewAndResize(sc) end
            end
        },
        {
            type = "dropdown",
            text = LText("Border Size"),
            values = { ["0"] = LText("None"), ["1"] = LText("Thin"), ["2"] = LText("Medium"), ["3"] = LText("Thick") },
            order = { "0", "1", "2", "3" },
            getValue = function()
                return
                    tostring(bd.borderSize or 1)
            end,
            setValue = function(v)
                bd.borderSize = tonumber(v) or 1; Refresh(); RefreshCDMRuntime(bd.key); UpdateCDMPreview()
            end
        }
    ); y = y + h

    if W.ColorSwatch then
        _, h = W:DualRow(sc, -y,
            {
                type = "colorpicker",
                text = LText("Border Color"),
                getValue = function()
                    return bd.borderR or 0, bd.borderG or 0,
                        bd.borderB or 0, bd.borderA or 1
                end,
                setValue = function(r, g, b, a)
                    bd.borderR, bd.borderG, bd.borderB, bd.borderA = r, g, b, a; Refresh(); RefreshCDMRuntime(bd.key); UpdateCDMPreview()
                end,
                hasAlpha = true
            },
            {
                type = "toggle",
                text = LText("Class Color Border"),
                getValue = function() return bd.borderClassColor end,
                setValue = function(
                    v)
                    bd.borderClassColor = v; Refresh(); RefreshCDMRuntime(bd.key); UpdateCDMPreview()
                end
            }
        ); y = y + h
    end

    _, h = W:SectionHeader(sc, LText("Active State"), -y); y = y + h

    _, h = W:Dropdown(sc, LText("Active Animation"), -y,
        {
            blizzard = LText("Blizzard Default"),
            none = LText("None"),
            hideActive = LText("Hide When Active"),
            ["1"] = LText("Pixel Glow"),
            ["2"] =
            LText("Custom Shape Glow"),
            ["3"] = LText("Action Button Glow"),
            ["4"] = LText("Auto-Cast Shine")
        },
        function() return tostring(bd.activeStateAnim or "2") end,
        function(v)
            bd.activeStateAnim = v; Refresh()
        end, { "blizzard", "none", "hideActive", "1", "2", "3", "4" }); y = y + h

    if W.ColorSwatch then
        _, h = W:DualRow(sc, -y,
            {
                type = "toggle",
                text = LText("Class Color Glow"),
                getValue = function() return bd.activeAnimClassColor end,
                setValue = function(
                    v)
                    bd.activeAnimClassColor = v; Refresh()
                end
            },
            {
                type = "colorpicker",
                text = LText("Glow Color"),
                getValue = function()
                    return bd.activeAnimR or 1.0,
                        bd.activeAnimG or 0.85, bd.activeAnimB or 0.0, 1
                end,
                setValue = function(r, g, b)
                    bd.activeAnimR, bd.activeAnimG, bd.activeAnimB = r, g, b; Refresh()
                end
            }
        ); y = y + h

    end

    _, h = W:SectionHeader(sc, LText("Swipe"), -y); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Active Swipe Uses Glow Color"),
            getValue = function() return bd.activeSwipeUsesGlowColor ~= false end,
            setValue = function(v)
                bd.activeSwipeUsesGlowColor = v and true or false
                Refresh()
            end
        },
        {
            type = "slider",
            text = LText("Swipe Alpha"),
            min = 0,
            max = 100,
            step = 5,
            getValue = function()
                return math.floor(((bd.swipeAlpha or 0.7) * 100) + 0.5)
            end,
            setValue = function(v)
                bd.swipeAlpha = v / 100
                Refresh()
            end
        }
    ); y = y + h

    _, h = AddGlowColorRow(W, sc, -y,
        LText("Swipe Color"),
        function()
            return bd.swipeR or 0, bd.swipeG or 0, bd.swipeB or 0
        end,
        function(r, g, b)
            bd.swipeR, bd.swipeG, bd.swipeB = r, g, b
            Refresh()
        end
    ); y = y + h

    _, h = W:SectionHeader(sc, "Texts & Misc", -y); y = y + h
    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Show Duration Text"),
            getValue = function() return bd.showCooldownText end,
            setValue = function(
                v)
                bd.showCooldownText = v; Refresh(); RefreshCDMRuntime(bd.key); UpdateCDMPreview()
            end
        },
        {
            type = "toggle",
            text = LText("Show Charges"),
            getValue = function() return bd.showCharges end,
            setValue = function(
                v)
                bd.showCharges = v; Refresh(); RefreshCDMRuntime(bd.key); UpdateCDMPreview()
            end
        }
    ); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "slider",
            text = LText("Duration Font Size"),
            min = 8,
            max = 32,
            step = 1,
            getValue = function()
                return bd
                    .cooldownFontSize or 15
            end,
            setValue = function(v)
                bd.cooldownFontSize = v; Refresh()
            end
        },
        {
            type = "slider",
            text = LText("Charge Count Font Size"),
            min = 8,
            max = 20,
            step = 1,
            getValue = function()
                return bd
                    .stackCountSize or 11
            end,
            setValue = function(v)
                bd.stackCountSize = v; Refresh()
            end
        }
    ); y = y + h

    _, h = W:SectionHeader(sc, "Keybind Text", -y); y = y + h
    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Show Keybinds"),
            getValue = function() return bd.showKeybind end,
            setValue = function(
                v)
                bd.showKeybind = v
                if bd.keybindOutline == nil then
                    bd.keybindOutline = true
                end
                Refresh(); RefreshCDMRuntime(bd.key); UpdateCDMPreview()
            end
        },
        {
            type = "slider",
            text = LText("Keybind Font Size"),
            min = 6,
            max = 20,
            step = 1,
            getValue = function()
                return bd
                    .keybindSize or 13
            end,
            setValue = function(v)
                bd.keybindSize = v; Refresh()
            end
        }
    ); y = y + h
    _, h = W:Toggle(sc, LText("Keybind Outline"), -y,
        function() return bd.keybindOutline ~= false end,
        function(v)
                    bd.keybindOutline = v; Refresh(); RefreshCDMRuntime(bd.key); UpdateCDMPreview()
        end); y = y + h

    _, h = W:SectionHeader(sc, "Misc", -y); y = y + h
    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Assisted Combat Highlight"),
            getValue = function() return bd.assistedCombatHighlight end,
            setValue = function(v)
                bd.assistedCombatHighlight = v; Refresh()
            end
        },
        {
            type = "toggle",
            text = LText("Button Press Highlight"),
            getValue = function() return bd.buttonPressHighlight end,
            setValue = function(v)
                bd.buttonPressHighlight = v; Refresh()
            end
        }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Desaturate on Cooldown"),
            getValue = function() return bd.desaturateOnCD end,
            setValue = function(
                v)
                bd.desaturateOnCD = v; Refresh()
            end
        },
        {
            type = "toggle",
            text = LText("Show Tooltip on Hover"),
            getValue = function() return bd.showTooltip end,
            setValue = function(
                v)
                bd.showTooltip = v; Refresh()
            end
        }
    ); y = y + h
    _, h = W:Toggle(sc, LText("Hide GCD Swipe"), -y, function() return bd.hideGCDSwipe end, function(v)
        bd.hideGCDSwipe = v; Refresh()
    end); y = y + h
    _, h = W:Toggle(sc, LText("Hide Buffs When Inactive"), -y, function() return bd.hideBuffsWhenInactive end,
        function(v)
            bd.hideBuffsWhenInactive = v; Refresh()
        end); y = y + h

    _, h = W:SectionHeader(sc, LText("Hide When..."), -y); y = y + h
    _, h = W:Dropdown(sc, LText("Condition Match Mode"), -y,
        { ANY = LText("Match Any (hide if any condition met)"), ALL = LText("Match All (hide if all met)") },
        function() return tostring(bd.hideWhenMode or "ANY"):upper() end,
        function(v)
            bd.hideWhenMode = tostring(v):upper(); RefreshVis()
        end,
        { "ANY", "ALL" }
    ); y = y + h

    local function HW(key) return bd.hideWhen and bd.hideWhen[key] end
    local function SetHW(key, v)
        bd.hideWhen = bd.hideWhen or {}
        bd.hideWhen[key] = v; RefreshVis()
    end

    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("Always (Disabled)"), getValue = function() return HW("always") end, setValue = function(v) SetHW("always", v) end },
        { type = "toggle", text = LText("While Casting"), getValue = function() return HW("casting") end, setValue = function(v) SetHW("casting", v) end }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("Not Casting"), getValue = function() return HW("notCasting") end, setValue = function(v) SetHW("notCasting", v) end },
        { type = "toggle", text = LText("In Combat"), getValue = function() return HW("inCombat") end, setValue = function(v) SetHW("inCombat", v) end }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("Out of Combat"), getValue = function() return HW("outOfCombat") end, setValue = function(v) SetHW("outOfCombat", v) end },
        { type = "toggle", text = LText("Boss Encounter"), getValue = function() return HW("boss") end, setValue = function(v) SetHW("boss", v) end }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("In Instance"), getValue = function() return HW("inInstance") end, setValue = function(v) SetHW("inInstance", v) end },
        { type = "toggle", text = LText("In Vehicle / Taxi"), getValue = function() return HW("inVehicle") end, setValue = function(v) SetHW("inVehicle", v) end }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("Mounted"), getValue = function() return HW("mounted") end, setValue = function(v) SetHW("mounted", v) end },
        { type = "toggle", text = LText("Flying"), getValue = function() return HW("flying") end, setValue = function(v) SetHW("flying", v) end }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("Skyriding"), getValue = function() return HW("skyriding") end, setValue = function(v) SetHW("skyriding", v) end },
        { type = "toggle", text = LText("Swimming"), getValue = function() return HW("swimming") end, setValue = function(v) SetHW("swimming", v) end }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("Resting (City/Inn)"), getValue = function() return HW("resting") end, setValue = function(v) SetHW("resting", v) end },
        { type = "toggle", text = LText("Dead / Ghost"), getValue = function() return HW("dead") end, setValue = function(v) SetHW("dead", v) end }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("Has Target"), getValue = function() return HW("hasTarget") end, setValue = function(v) SetHW("hasTarget", v) end },
        { type = "toggle", text = LText("No Target"), getValue = function() return HW("noTarget") end, setValue = function(v) SetHW("noTarget", v) end }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("In Group"), getValue = function() return HW("inGroup") end, setValue = function(v) SetHW("inGroup", v) end },
        { type = "toggle", text = LText("Solo (Not in Group)"), getValue = function() return HW("solo") end, setValue = function(v) SetHW("solo", v) end }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("In Raid"), getValue = function() return HW("inRaid") end, setValue = function(v) SetHW("inRaid", v) end },
        { type = "toggle", text = LText("PvP Flagged"), getValue = function() return HW("pvp") end, setValue = function(v) SetHW("pvp", v) end }
    ); y = y + h
    _, h = W:DualRow(sc, -y,
        { type = "toggle", text = LText("Stealthed"), getValue = function() return HW("stealthed") end, setValue = function(v) SetHW("stealthed", v) end },
        { type = "toggle", text = LText("In Pet Battle"), getValue = function() return HW("petBattle") end, setValue = function(v) SetHW("petBattle", v) end }
    ); y = y + h

    return y
end

-- ============================================================================
local _subTabBarFrame = nil

local function BuildCDMSubTabBar(sc, yOff)
    local subTabs = {
        { id = "manage", label = "Manage & Layout" },
        { id = "icons",  label = "Icon & Effects" },
        { id = "text",   label = "Text & Misc" },
        { id = "rules",  label = "Visibility Rules" },
    }
    local containerH = 26
    local container
    if _subTabBarFrame and _subTabBarFrame:GetParent() == sc then
        container = _subTabBarFrame
        for _, child in ipairs({ container:GetChildren() }) do child:Hide() end
    else
        if _subTabBarFrame then _subTabBarFrame:Hide() end
        container = CreateFrame("Frame", nil, sc)
        _subTabBarFrame = container
    end
    container:SetHeight(containerH)
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOff)
    container:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -4, yOff)
    container:Show()

    local TAB_GAP = 4
    local scW = sc:GetWidth() > 0 and sc:GetWidth() or 500
    local totalWidth = math.max(1, scW - 6)
    local usableWidth = totalWidth - ((#subTabs - 1) * TAB_GAP)
    local tabWidth = math.floor(usableWidth / #subTabs)
    local usedWidth = (tabWidth * #subTabs) + ((#subTabs - 1) * TAB_GAP)
    local remainder = totalWidth - usedWidth

    local previousButton
    for i, tab in ipairs(subTabs) do
        local isActive = (tab.id == cdmActiveSubTab)
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetHeight(containerH)
        btn:SetWidth(tabWidth + ((i == #subTabs) and remainder or 0))
        if i == 1 then
            btn:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", previousButton, "RIGHT", TAB_GAP, 0)
        end

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(KT and KT.FONT_PATH or "Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
        lbl:SetText(LText(tab.label))
        lbl:SetAllPoints()
        lbl:SetJustifyH("CENTER")
        
        if StyleModernPageButton then
            StyleModernPageButton(btn, isActive and "active" or "inactive", 10)
        else
            if KT and KT.AddBackdrop then KT:AddBackdrop(btn, 0.1, 0.1, 0.1, isActive and 0.9 or 0.4) end
            if KT and KT.AddBorder then KT:AddBorder(btn, 0, 0, 0, 1) end
        end

        local tid = tab.id
        btn:SetScript("OnClick", function()
            cdmActiveSubTab = tid
            if KT and KT.RefreshPage then KT:RefreshPage(true) end
        end)
        btn:Show()
        previousButton = btn
    end
    return container, containerH + 8
end

-- PESTANA: CUSTOM BARS
-- ============================================================================


local function BuildCDMBarsBlocksTab(sc, W, startY, p)
    local currentY, rowHeight = startY, 0

    _, rowHeight = W:SectionHeader(sc, LText("CDM Bars"), -currentY); currentY = currentY + rowHeight
    _, rowHeight = W:Label(sc, LText("Manage icon groups for cooldowns. Use the interactive preview below to add or remove spells."), -currentY, 11); currentY = currentY + rowHeight

    local cdmBars = p.cdmBars.bars or {}
    if #cdmBars == 0 then
        return currentY
    end

    local previewBlockFrames = {}
    BuildCDMLivePreview(sc, -currentY, function(blockKey)
        return previewBlockFrames[blockKey]
    end)

    local previewHeight = _cdmPreview and (_cdmPreview:GetHeight() * (_cdmPreview:GetScale() or 1)) or 0
    _, rowHeight = W:SectionHeader(sc, LText("Live Layout Preview"), -currentY); currentY = currentY + rowHeight
    _cdmHeaderFixedH = currentY
    currentY = currentY + previewHeight + 6

    local selectedBarConfig = SelectedCDMBar()
    if not selectedBarConfig then
        return currentY
    end

    local cdmLabels = {}
    local cdmOrder = {}
    for barIndex, barData in ipairs(cdmBars) do
        local keyString = tostring(barIndex)
        cdmLabels[keyString] = barData.name or barData.key or ("Bar " .. barIndex)
        cdmOrder[#cdmOrder + 1] = keyString
    end

    local anchorOptions = {
        none = "Free (Draggable)",
        partyframe = "Party Frame",
        playerframe = "Player Frame",
        castbar = "Cast Bar",
    }
    local anchorOrder = { "none", "partyframe", "playerframe", "castbar" }
    if selectedBarConfig.key == "cooldowns" then
        anchorOptions.castbar = nil
        for orderIndex, anchorKey in ipairs(anchorOrder) do
            if anchorKey == "castbar" then
                table.remove(anchorOrder, orderIndex)
                break
            end
        end
    end
    for _, otherBar in ipairs(cdmBars) do
        if otherBar.key ~= selectedBarConfig.key then
            anchorOptions[otherBar.key] = "Bar: " .. (otherBar.name or otherBar.key)
            anchorOrder[#anchorOrder + 1] = otherBar.key
        end
    end

    local strataValues = {
        BACKGROUND = LText("Background"),
        LOW = LText("Low"),
        MEDIUM = LText("Medium (Default)"),
        HIGH = LText("High"),
        DIALOG = LText("Dialog"),
        TOOLTIP = LText("Tooltip"),
    }
    local strataOrder = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "TOOLTIP" }

    local hideConditions = {
        { left = "always",      leftText = LText("Always (Disabled)"),       right = "casting",    rightText = LText("While Casting") },
        { left = "notCasting",  leftText = LText("Not Casting"),             right = "inCombat",   rightText = LText("In Combat") },
        { left = "outOfCombat", leftText = LText("Out of Combat"),           right = "boss",       rightText = LText("Boss Encounter") },
        { left = "inInstance",  leftText = LText("In Instance"),             right = "inVehicle",  rightText = LText("In Vehicle / Taxi") },
        { left = "mounted",     leftText = LText("Mounted"),                 right = "flying",     rightText = LText("Flying") },
        { left = "skyriding",   leftText = LText("Skyriding"),               right = "swimming",   rightText = LText("Swimming") },
        { left = "resting",     leftText = LText("Resting (City/Inn)"),      right = "dead",       rightText = LText("Dead / Ghost") },
        { left = "hasTarget",   leftText = LText("Has Target"),              right = "noTarget",   rightText = LText("No Target") },
        { left = "inGroup",     leftText = LText("In Group"),                right = "solo",       rightText = LText("Solo (Not in Group)") },
        { left = "inRaid",      leftText = LText("In Raid"),                 right = "pvp",        rightText = LText("PvP Flagged") },
        { left = "stealthed",   leftText = LText("Stealthed"),               right = "petBattle",  rightText = LText("In Pet Battle") },
    }

    local function HideWhenValue(key)
        return selectedBarConfig.hideWhen and selectedBarConfig.hideWhen[key]
    end

    local function SetHideWhenValue(key, value)
        selectedBarConfig.hideWhen = selectedBarConfig.hideWhen or {}
        selectedBarConfig.hideWhen[key] = value
        RefreshVis()
    end

    local _, subTabH = BuildCDMSubTabBar(sc, -currentY)
    currentY = currentY + subTabH + 4
    local blockColumns = BeginCDMOptionBlocks(sc, currentY)

    if cdmActiveSubTab == "manage" then
        previewBlockFrames.manage = AddCDMOptionBlock(blockColumns, "left", LText("Manage Bars"), function(container)
        local blockY, blockRowHeight = 0, 0

        _, blockRowHeight = W:Dropdown(container, LText("Select Bar"), -blockY, cdmLabels,
            function()
                return tostring(selectedCDMBarIndex)
            end,
            function(value)
                selectedCDMBarIndex = tonumber(value) or 1
                if KT.RefreshPage then
                    KT:RefreshPage(true)
                end
            end,
            cdmOrder
        ); blockY = blockY + blockRowHeight

        blockY = blockY + AddCDMBuffsNoticeBlock(container, W, blockY, selectedBarConfig)

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "toggle",
                text = LText("Use Blizzard Layout by Default"),
                getValue = function() return p.cdmBars.useBlizzardDisplayDefaults ~= false end,
                setValue = function(value)
                    p.cdmBars.useBlizzardDisplayDefaults = value and true or false
                    Refresh()
                end
            },
            {
                type = "toggle",
                text = LText("Prompt on Blizzard Changes"),
                getValue = function() return p.cdmBars.promptBlizzardLayoutChanges ~= false end,
                setValue = function(value)
                    p.cdmBars.promptBlizzardLayoutChanges = value and true or false
                end
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:Button(container, LText("Import Blizzard Layout Now"), -blockY, function()
            if ns.ImportBlizzardDisplayedMainBars then
                ns.ImportBlizzardDisplayedMainBars(true, false)
                Refresh()
            else
                print("KUI: Blizzard CDM import unavailable.")
            end
        end, 260, nil, nil, "CENTER", 28); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:Label(container, LText("Imports the visible order from Blizzard CDM for Cooldowns, Utility and Buffs."), -blockY, 11); blockY = blockY + blockRowHeight

        ns.customBarTypeToCreate = ns.customBarTypeToCreate or "cooldowns"
        _, blockRowHeight = W:Dropdown(container, LText("New Custom Bar Category"), -blockY, 
            { cooldowns = LText("Cooldowns"), utility = LText("Utility"), buffs = LText("Buffs") },
            function() return ns.customBarTypeToCreate end,
            function(v) 
                ns.customBarTypeToCreate = v 
                Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
            end,
            { "cooldowns", "utility", "buffs" }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "button",
                text = LText("+ Add Custom Bar"),
                onClick = function()
                    if ns.AddCDMBar then
                        local newKey = ns.AddCDMBar(ns.customBarTypeToCreate)
                        if newKey then
                            for barIndex, barData in ipairs(p.cdmBars.bars) do
                                if barData.key == newKey then
                                    selectedCDMBarIndex = barIndex
                                    break
                                end
                            end
                        else
                            print("|cffff4444KullThranUI:|r Se ha alcanzado el límite de Custom Bars (" .. (ns.MAX_CUSTOM_BARS or 12) .. ").")
                        end
                    else
                        print("KUI: AddCDMBar unavailable.")
                    end
                    Refresh()
                    if KT.RefreshPage then
                        KT:RefreshPage(true)
                    end
                end
            },
            {
                type = "button",
                text = LText("Delete Bar"),
                onClick = function()
                    local currentBar = SelectedCDMBar()
                    if currentBar and currentBar.key:match("^custom_") then
                        if ns.RemoveCDMBar then
                            ns.RemoveCDMBar(currentBar.key)
                        else
                            table.remove(p.cdmBars.bars, selectedCDMBarIndex)
                        end
                        selectedCDMBarIndex = 1
                        Refresh()
                        if KT.RefreshPage then
                            KT:RefreshPage(true)
                        end
                    else
                        print("KUI: You cannot delete default Blizzard bars.")
                    end
                end
            }
        ); blockY = blockY + blockRowHeight

        return blockY
    end)

    previewBlockFrames.layout = AddCDMOptionBlock(blockColumns, "right", LText("Bar Layout"), function(container)
        local blockY, blockRowHeight = 0, 0

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "toggle",
                text = LText("Enabled"),
                getValue = function() return selectedBarConfig.enabled end,
                setValue = function(value)
                    selectedBarConfig.enabled = value
                    Refresh()
                end
            },
            {
                type = "dropdown",
                text = LText("Visibility"),
                values = { always = LText("Always"), in_combat = LText("In Combat"), mouseover = LText("Mouseover"), never = LText("Never") },
                order = { "always", "in_combat", "mouseover", "never" },
                getValue = function() return selectedBarConfig.barVisibility or "always" end,
                setValue = function(value)
                    selectedBarConfig.barVisibility = value
                    RefreshVis()
                end
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "slider",
                text = LText("Bar Opacity"),
                min = 0,
                max = 100,
                step = 5,
                getValue = function()
                    return math.floor(((selectedBarConfig.barBgAlpha or 1.0) * 100) + 0.5)
                end,
                setValue = function(value)
                    selectedBarConfig.barBgAlpha = value / 100
                    Refresh()
                end,
                sliderOptions = {
                    defaultGet = function() return GetCDMBarDefaultValue(selectedBarConfig, "barBgAlpha") end,
                }
            },
            {
                type = "toggle",
                text = LText("Show Background"),
                getValue = function() return selectedBarConfig.barBgEnabled end,
                setValue = function(value)
                    selectedBarConfig.barBgEnabled = value
                    Refresh()
                    UpdateCDMPreview()
                end
            }
        ); blockY = blockY + blockRowHeight
        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "slider",
                text = LText("Number of Rows"),
                min = 1,
                max = 8,
                step = 1,
                getValue = function() return selectedBarConfig.numRows or 1 end,
                setValue = function(value)
                    selectedBarConfig.numRows = value
                    Refresh()
                    UpdateCDMPreviewAndResize(sc)
                end,
                sliderOptions = {
                    defaultGet = function() return GetCDMBarDefaultValue(selectedBarConfig, "numRows") end,
                }
            },
            {
                type = "dropdown",
                text = LText("Grow Direction"),
                values = { RIGHT = LText("Right"), LEFT = LText("Left"), UP = LText("Up"), DOWN = LText("Down") },
                order = { "RIGHT", "LEFT", "UP", "DOWN" },
                getValue = function() return selectedBarConfig.growDirection or "RIGHT" end,
                setValue = function(value)
                    selectedBarConfig.growDirection = value
                    Refresh()
                    if KT.RefreshPage then
                        KT:RefreshPage(true)
                    else
                        UpdateCDMPreviewAndResize(sc)
                    end
                end
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:Dropdown(container, LText("Anchored To"), -blockY, anchorOptions,
            function()
                return selectedBarConfig.anchorTo or "none"
            end,
            function(value)
                selectedBarConfig.anchorTo = value
                Refresh()
                if KT.RefreshPage then
                    KT:RefreshPage(true)
                end
            end,
            anchorOrder
        ); blockY = blockY + blockRowHeight

        if selectedBarConfig.anchorTo and selectedBarConfig.anchorTo ~= "none" then
            _, blockRowHeight = W:Dropdown(container, LText("Anchor Position"), -blockY,
                { left = LText("Left"), right = LText("Right"), top = LText("Top"), bottom = LText("Bottom") },
                function()
                    return selectedBarConfig.anchorPosition or "right"
                end,
                function(value)
                    selectedBarConfig.anchorPosition = value
                    Refresh()
                end,
                { "left", "right", "top", "bottom" }
            ); blockY = blockY + blockRowHeight

            _, blockRowHeight = W:DualRow(container, -blockY,
                {
                    type = "slider",
                    text = LText("Anchor Offset X"),
                    min = -200,
                    max = 200,
                    step = 1,
                    getValue = function() return selectedBarConfig.anchorOffsetX or 0 end,
                    setValue = function(value)
                        selectedBarConfig.anchorOffsetX = value
                        Refresh()
                    end
                },
                {
                    type = "slider",
                    text = LText("Anchor Offset Y"),
                    min = -200,
                    max = 200,
                    step = 1,
                    getValue = function() return selectedBarConfig.anchorOffsetY or 0 end,
                    setValue = function(value)
                        selectedBarConfig.anchorOffsetY = value
                        Refresh()
                    end
                }
            ); blockY = blockY + blockRowHeight
        end

        _, blockRowHeight = W:Slider(container, LText("Global Bar Scale"), -blockY,
            function()
                return math.floor(((selectedBarConfig.barScale or 1.0) * 100) + 0.5)
            end,
            function(value)
                selectedBarConfig.barScale = value / 100
                Refresh()
                UpdateCDMPreviewAndResize(sc)
            end,
            40, 200, 5,
            nil,
            {
                defaultGet = function() return GetCDMBarDefaultValue(selectedBarConfig, "barScale") end,
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:Dropdown(container, LText("Frame Strata"), -blockY, strataValues,
            function()
                return tostring(selectedBarConfig.barStrata or "MEDIUM"):upper()
            end,
            function(value)
                selectedBarConfig.barStrata = tostring(value):upper()
                Refresh()
            end,
            strataOrder
        ); blockY = blockY + blockRowHeight

        return blockY
    end)

    end

    if cdmActiveSubTab == "icons" then
        previewBlockFrames.icons = AddCDMOptionBlock(blockColumns, "left", LText("Icon Display"), function(container)
        local blockY, blockRowHeight = 0, 0

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "slider",
                text = LText("Icon Scale"),
                min = 16,
                max = 80,
                step = 1,
                getValue = function() return selectedBarConfig.iconSize or 36 end,
                setValue = function(value)
                    selectedBarConfig.iconSize = value
                    Refresh()
                    UpdateCDMPreviewAndResize(sc)
                end,
                sliderOptions = {
                    defaultGet = function() return GetCDMBarDefaultValue(selectedBarConfig, "iconSize") end,
                }
            },
            {
                type = "slider",
                text = LText("Icon Spacing"),
                min = -4,
                max = 24,
                step = 1,
                getValue = function() return selectedBarConfig.spacing or 2 end,
                setValue = function(value)
                    selectedBarConfig.spacing = value
                    if selectedBarConfig.isKUITracker then
                        selectedBarConfig.spacingCustomized = true
                    end
                    Refresh()
                    UpdateCDMPreviewAndResize(sc)
                end,
                sliderOptions = {
                    defaultGet = function() return GetCDMBarDefaultValue(selectedBarConfig, "spacing") end,
                }
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "dropdown",
                text = LText("Custom Icon Shape"),
                values = { none = LText("None"), cropped = LText("Cropped"), square = LText("Square"), circle = LText("Circle"), csquare = LText("Curved Square"), diamond = LText("Diamond"), hexagon = LText("Hexagon"), portrait = LText("Portrait"), shield = LText("Shield") },
                order = { "none", "cropped", "square", "circle", "csquare", "diamond", "hexagon", "portrait", "shield" },
                getValue = function() return selectedBarConfig.iconShape or "none" end,
                setValue = function(value)
                    selectedBarConfig.iconShape = value
                    Refresh()
                    if KT.RefreshPage then
                        KT:RefreshPage(true)
                    else
                        UpdateCDMPreviewAndResize(sc)
                    end
                end
            },
            {
                type = "dropdown",
                text = LText("Border Size"),
                values = { ["0"] = LText("None"), ["1"] = LText("Thin"), ["2"] = LText("Medium"), ["3"] = LText("Thick") },
                order = { "0", "1", "2", "3" },
                getValue = function() return tostring(selectedBarConfig.borderSize or 1) end,
                setValue = function(value)
                    selectedBarConfig.borderSize = tonumber(value) or 1
                    Refresh()
                    UpdateCDMPreview()
                end
            }
        ); blockY = blockY + blockRowHeight

        if W.ColorSwatch then
            _, blockRowHeight = W:DualRow(container, -blockY,
                {
                    type = "colorpicker",
                    text = LText("Border Color"),
                    getValue = function()
                        return selectedBarConfig.borderR or 0, selectedBarConfig.borderG or 0, selectedBarConfig.borderB or 0, selectedBarConfig.borderA or 1
                    end,
                    setValue = function(r, g, b, a)
                        selectedBarConfig.borderR, selectedBarConfig.borderG, selectedBarConfig.borderB, selectedBarConfig.borderA = r, g, b, a
                        Refresh()
                        UpdateCDMPreview()
                    end,
                    hasAlpha = true
                },
                {
                    type = "toggle",
                    text = LText("Class Color Border"),
                    getValue = function() return selectedBarConfig.borderClassColor end,
                    setValue = function(value)
                        selectedBarConfig.borderClassColor = value
                        Refresh()
                        UpdateCDMPreview()
                    end
                }
            ); blockY = blockY + blockRowHeight
        end

        return blockY
    end)

    previewBlockFrames.effects = AddCDMOptionBlock(blockColumns, "right", LText("Active & Swipe"), function(container)
        local blockY, blockRowHeight = 0, 0

        _, blockRowHeight = W:Dropdown(container, LText("Active Animation"), -blockY,
            {
                blizzard = LText("Blizzard Default"),
                none = LText("None"),
                hideActive = LText("Hide When Active"),
                ["1"] = LText("Pixel Glow"),
                ["2"] = LText("Custom Shape Glow"),
                ["3"] = LText("Action Button Glow"),
                ["4"] = LText("Auto-Cast Shine"),
            },
            function()
                return tostring(selectedBarConfig.activeStateAnim or "2")
            end,
            function(value)
                selectedBarConfig.activeStateAnim = value
                Refresh()
            end,
            { "blizzard", "none", "hideActive", "1", "2", "3", "4" }
        ); blockY = blockY + blockRowHeight

        if W.ColorSwatch then
            _, blockRowHeight = W:DualRow(container, -blockY,
                {
                    type = "toggle",
                    text = LText("Class Color Glow"),
                    getValue = function() return selectedBarConfig.activeAnimClassColor end,
                    setValue = function(value)
                        selectedBarConfig.activeAnimClassColor = value
                        Refresh()
                    end
                },
                {
                    type = "colorpicker",
                    text = LText("Glow Color"),
                    getValue = function()
                        return selectedBarConfig.activeAnimR or 1.0, selectedBarConfig.activeAnimG or 0.85, selectedBarConfig.activeAnimB or 0.0, 1
                    end,
                    setValue = function(r, g, b)
                        selectedBarConfig.activeAnimR, selectedBarConfig.activeAnimG, selectedBarConfig.activeAnimB = r, g, b
                        Refresh()
                    end
                }
            ); blockY = blockY + blockRowHeight
        end

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "toggle",
                text = LText("Active Swipe Uses Glow Color"),
                getValue = function() return selectedBarConfig.activeSwipeUsesGlowColor ~= false end,
                setValue = function(value)
                    selectedBarConfig.activeSwipeUsesGlowColor = value and true or false
                    Refresh()
                end
            },
            {
                type = "slider",
                text = LText("Swipe Alpha"),
                min = 0,
                max = 100,
                step = 5,
                getValue = function()
                    return math.floor(((selectedBarConfig.swipeAlpha or 0.7) * 100) + 0.5)
                end,
                setValue = function(value)
                    selectedBarConfig.swipeAlpha = value / 100
                    Refresh()
                end
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = AddGlowColorRow(W, container, -blockY,
            LText("Swipe Color"),
            function()
                return selectedBarConfig.swipeR or 0, selectedBarConfig.swipeG or 0, selectedBarConfig.swipeB or 0
            end,
            function(r, g, b)
                selectedBarConfig.swipeR, selectedBarConfig.swipeG, selectedBarConfig.swipeB = r, g, b
                Refresh()
            end
        ); blockY = blockY + blockRowHeight

        return blockY
    end)

    end

    if cdmActiveSubTab == "text" then
        previewBlockFrames.text = AddCDMOptionBlock(blockColumns, "left", LText("Text & Keybinds"), function(container)
        local blockY, blockRowHeight = 0, 0

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "toggle",
                text = LText("Show Duration Text"),
                getValue = function() return selectedBarConfig.showCooldownText end,
                setValue = function(value)
                    selectedBarConfig.showCooldownText = value
                    Refresh()
                    UpdateCDMPreview()
                end
            },
            {
                type = "toggle",
                text = LText("Show Charges"),
                getValue = function() return selectedBarConfig.showCharges end,
                setValue = function(value)
                    selectedBarConfig.showCharges = value
                    Refresh()
                    UpdateCDMPreview()
                end
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "slider",
                text = LText("Duration Font Size"),
                min = 8,
                max = 32,
                step = 1,
                getValue = function() return selectedBarConfig.cooldownFontSize or 15 end,
                setValue = function(value)
                    selectedBarConfig.cooldownFontSize = value
                    Refresh()
                end
            },
            {
                type = "slider",
                text = LText("Charge Count Font Size"),
                min = 8,
                max = 20,
                step = 1,
                getValue = function() return selectedBarConfig.stackCountSize or 11 end,
                setValue = function(value)
                    selectedBarConfig.stackCountSize = value
                    Refresh()
                end
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "toggle",
                text = LText("Show Keybinds"),
                getValue = function() return selectedBarConfig.showKeybind end,
                setValue = function(value)
                    selectedBarConfig.showKeybind = value
                    if selectedBarConfig.keybindOutline == nil then
                        selectedBarConfig.keybindOutline = true
                    end
                    Refresh()
                    UpdateCDMPreview()
                end
            },
            {
                type = "slider",
                text = LText("Keybind Font Size"),
                min = 6,
                max = 20,
                step = 1,
                getValue = function() return selectedBarConfig.keybindSize or 13 end,
                setValue = function(value)
                    selectedBarConfig.keybindSize = value
                    Refresh()
                end
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:Toggle(container, LText("Keybind Outline"), -blockY,
            function()
                return selectedBarConfig.keybindOutline ~= false
            end,
            function(value)
                selectedBarConfig.keybindOutline = value
                Refresh()
                UpdateCDMPreview()
            end
        ); blockY = blockY + blockRowHeight

        return blockY
    end)

    previewBlockFrames.misc = AddCDMOptionBlock(blockColumns, "right", LText("Misc"), function(container)
        local blockY, blockRowHeight = 0, 0

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "toggle",
                text = LText("Assisted Combat Highlight"),
                getValue = function() return selectedBarConfig.assistedCombatHighlight end,
                setValue = function(value)
                    selectedBarConfig.assistedCombatHighlight = value
                    Refresh()
                end
            },
            {
                type = "toggle",
                text = LText("Button Press Highlight"),
                getValue = function() return selectedBarConfig.buttonPressHighlight end,
                setValue = function(value)
                    selectedBarConfig.buttonPressHighlight = value
                    Refresh()
                end
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:DualRow(container, -blockY,
            {
                type = "toggle",
                text = LText("Desaturate on Cooldown"),
                getValue = function() return selectedBarConfig.desaturateOnCD end,
                setValue = function(value)
                    selectedBarConfig.desaturateOnCD = value
                    Refresh()
                end
            },
            {
                type = "toggle",
                text = LText("Show Tooltip on Hover"),
                getValue = function() return selectedBarConfig.showTooltip end,
                setValue = function(value)
                    selectedBarConfig.showTooltip = value
                    Refresh()
                end
            }
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:Toggle(container, LText("Hide GCD Swipe"), -blockY,
            function()
                return selectedBarConfig.hideGCDSwipe
            end,
            function(value)
                selectedBarConfig.hideGCDSwipe = value
                Refresh()
            end
        ); blockY = blockY + blockRowHeight

        _, blockRowHeight = W:Toggle(container, LText("Hide Buffs When Inactive"), -blockY,
            function()
                return selectedBarConfig.hideBuffsWhenInactive
            end,
            function(value)
                selectedBarConfig.hideBuffsWhenInactive = value
                Refresh()
            end
        ); blockY = blockY + blockRowHeight

        return blockY
    end)

    end

    if cdmActiveSubTab == "rules" then
        previewBlockFrames.rules = AddCDMOptionBlock(blockColumns, "full", LText("Hide Rules"), function(container)
        local blockY, blockRowHeight = 0, 0

        _, blockRowHeight = W:Dropdown(container, LText("Condition Match Mode"), -blockY,
            { ANY = LText("Match Any (hide if any condition met)"), ALL = LText("Match All (hide if all met)") },
            function()
                return tostring(selectedBarConfig.hideWhenMode or "ANY"):upper()
            end,
            function(value)
                selectedBarConfig.hideWhenMode = tostring(value):upper()
                RefreshVis()
            end,
            { "ANY", "ALL" }
        ); blockY = blockY + blockRowHeight

        for _, conditionRow in ipairs(hideConditions) do
            local leftKey = conditionRow.left
            local leftText = conditionRow.leftText
            local rightKey = conditionRow.right
            local rightText = conditionRow.rightText
            _, blockRowHeight = W:DualRow(container, -blockY,
                {
                    type = "toggle",
                    text = leftText,
                    getValue = function() return HideWhenValue(leftKey) end,
                    setValue = function(value) SetHideWhenValue(leftKey, value) end
                },
                {
                    type = "toggle",
                    text = rightText,
                    getValue = function() return HideWhenValue(rightKey) end,
                    setValue = function(value) SetHideWhenValue(rightKey, value) end
                }
            ); blockY = blockY + blockRowHeight
        end

        return blockY
    end)

    end

    currentY = EndCDMOptionBlocks(blockColumns)
    return currentY
end

local BAR_BUTTON_PREFIXES  = {
    [1] = "ActionButton",
    [2] = "MultiBarBottomLeftButton",
    [3] = "MultiBarBottomRightButton",
    [4] = "MultiBarRightButton",
    [5] = "MultiBarLeftButton",
    [6] = "MultiBar5Button",
    [7] = "MultiBar6Button",
    [8] = "MultiBar7Button",
}

-- Action bar shape masks/borders (for preview rendering)
local AB_SHAPE_MEDIA       = "Interface\\AddOns\\KullThranUI\\Libraries\\texture\\media\\portraits\\"
local AB_SHAPE_MASKS       = {
    circle = AB_SHAPE_MEDIA .. "circle_mask.tga",
    csquare = AB_SHAPE_MEDIA .. "csquare_mask.tga",
    diamond = AB_SHAPE_MEDIA .. "diamond_mask.tga",
    hexagon = AB_SHAPE_MEDIA .. "hexagon_mask.tga",
    portrait = AB_SHAPE_MEDIA .. "portrait_mask.tga",
    shield = AB_SHAPE_MEDIA .. "shield_mask.tga",
    square = AB_SHAPE_MEDIA .. "square_mask.tga",
}
local AB_SHAPE_BORDERS     = {
    circle = AB_SHAPE_MEDIA .. "circle_border.tga",
    csquare = AB_SHAPE_MEDIA .. "csquare_border.tga",
    diamond = AB_SHAPE_MEDIA .. "diamond_border.tga",
    hexagon = AB_SHAPE_MEDIA .. "hexagon_border.tga",
    portrait = AB_SHAPE_MEDIA .. "portrait_border.tga",
    shield = AB_SHAPE_MEDIA .. "shield_border.tga",
    square = AB_SHAPE_MEDIA .. "square_border.tga",
}

local BG_ACTION_BAR_VALUES = {
    [1] = "Action Bar 1 (Main)",
    [2] = "Action Bar 2",
    [3] = "Action Bar 3",
    [4] = "Action Bar 4",
    [5] = "Action Bar 5",
    [6] = "Action Bar 6",
    [7] = "Action Bar 7",
    [8] = "Action Bar 8",
}
local BG_ACTION_BAR_ORDER  = { 1, 2, 3, 4, 5, 6, 7, 8 }

local BG_MODE_VALUES       = { ACTIVE = "Buff Active", MISSING = "Buff Missing" }
local BG_MODE_ORDER        = { "ACTIVE", "MISSING" }

-- Build glow style dropdown values from ns.GLOW_STYLES
local function GetGlowStyleValues()
    local labels, order = {}, {}
    labels.blizzard = LText("Proc Glow (WoW)")
    order[#order + 1] = "blizzard"

    labels.autocast = LText("AutoCast Shine")
    order[#order + 1] = "autocast"

    if not ns.CDMHasNamedGlowSupport or ns.CDMHasNamedGlowSupport("pixel") then
        labels.pixel = LText("Pixel Border")
        order[#order + 1] = "pixel"
    end

    labels.none = LText("None")
    order[#order + 1] = "none"

    if #order == 0 then
        labels.blizzard = LText("Proc Glow (WoW)")
        order[1] = "blizzard"
    end
    return labels, order
end

-- Get the icon texture from a real Blizzard action button
local function GetActionButtonIcon(barIdx, slot)
    local prefix = BAR_BUTTON_PREFIXES[barIdx]
    if not prefix then return nil end
    local btn = _G[prefix .. slot]
    if not btn then return nil end
    local icon = btn.icon or btn.Icon
    if icon and icon.GetTexture then return icon:GetTexture() end
    return nil
end

local ResolveBarGlowStyleForRender

local function GlowStyleCodeFromGlobalStyle(styleId)
    if styleId == "none" then return 0 end
    if styleId == "pixel" then return 2 end
    if styleId == "autocast" then return 1 end
    return 6 -- "blizzard" default
end

local function NormalizeGlowStyleOption(styleValue, fallbackStyleId)
    local resolved = ResolveBarGlowStyleForRender(styleValue, fallbackStyleId)
    if resolved == 0 then
        return "none"
    end
    if resolved == "autocast" or resolved == "pixel" or resolved == "button" or resolved == "blizzard" then
        return resolved
    end
    return "blizzard"
end

ResolveBarGlowStyleForRender = function(styleValue, fallbackStyleId)
    if ns.ResolveBarGlowStyle then
        return ns.ResolveBarGlowStyle({ glowStyle = styleValue }, { glowStyle = fallbackStyleId })
    end
    if styleValue == 0 or styleValue == "none" then return 0 end
    if styleValue == 6 or styleValue == "blizzard" then return "blizzard" end
    if styleValue == 1 or styleValue == "autocast" then return "autocast" end
    if styleValue == 2 or styleValue == "pixel" then return "pixel" end
    if styleValue == 4 or styleValue == "button" then return "button" end
    if fallbackStyleId == "none" then return 0 end
    if fallbackStyleId == "pixel" then return "pixel" end
    if fallbackStyleId == "autocast" then return "autocast" end
    if fallbackStyleId == "button" then return "button" end
    return "blizzard"
end

local function ResolveBarGlowColorForRender(entry, bg)
    if ns.ResolveBarGlowColor then
        return ns.ResolveBarGlowColor(entry or {}, bg or {})
    end
    local c = (entry and entry.glowColor) or (bg and bg.glowColor) or { r = 1, g = 0.82, b = 0.1 }
    return c.r or 1, c.g or 0.82, c.b or 0.1
end

local function ResolveBarGlowColorForTargetOrRender(identifier, entry, bg)
    if ns.ResolveBarGlowColorForTarget then
        local r, g, b = ns.ResolveBarGlowColorForTarget(identifier, entry, bg)
        if r ~= nil and g ~= nil and b ~= nil then
            return r, g, b
        end
    end
    return ResolveBarGlowColorForRender(entry, bg)
end

local function ResolveSwipeColorForTargetOrRender(identifier, spellOverride, bg, bd)
    if spellOverride and spellOverride.useGlobalSwipeColor ~= true and spellOverride.swipeColor then
        local c = spellOverride.swipeColor
        return c.r or 0, c.g or 0, c.b or 0
    end
    if bd and bd.activeSwipeUsesGlowColor ~= false then
        return ResolveBarGlowColorForTargetOrRender(identifier, nil, bg)
    end
    return (bd and bd.swipeR) or 0, (bd and bd.swipeG) or 0, (bd and bd.swipeB) or 0
end

local function EnsureBarGlowSpellOverrideForRender(identifier, bg)
    if identifier == nil then
        return nil
    end
    if ns.GetBarGlowSpellOverride then
        return ns.GetBarGlowSpellOverride(identifier, true)
    end

    bg = bg or (ns.GetBarGlows and ns.GetBarGlows()) or {}
    bg.spellOverrides = bg.spellOverrides or {}

    local key
    if ns.GetBarGlowSpellOverrideKey then
        key = ns.GetBarGlowSpellOverrideKey(identifier)
    else
        key = tostring(identifier)
    end
    if not key then
        return nil
    end

    local entry = bg.spellOverrides[key]
    if not entry then
        entry = {
            useGlobalGlow = true,
            useGlobalColor = true,
            useGlobalSwipeColor = true,
        }
        bg.spellOverrides[key] = entry
    end
    if entry.useGlobalSwipeColor == nil then
        entry.useGlobalSwipeColor = true
    end
    return entry
end

local function RefreshBarGlowConfigUI(forceFullRuntimeRefresh)
    Refresh()
    if ns.RefreshActiveProcGlows then
        ns.RefreshActiveProcGlows()
    end
    if ns.RefreshBarGlowRuntime then
        ns.RefreshBarGlowRuntime(forceFullRuntimeRefresh)
    elseif ns.RequestUpdate then
        ns.RequestUpdate()
    end
    if KT.RefreshPage then
        KT:RefreshPage(true)
    end
end

local function GetBasicGlowDropdownData()
    local values, order = GetGlowStyleValues()
    values.button = nil
    for i = #order, 1, -1 do
        if order[i] == "button" then
            table.remove(order, i)
        end
    end
    return values, order
end

local BG_ACTION_BAR_START_SLOTS = {
    [1] = 1,
    [2] = 61,
    [3] = 49,
    [4] = 25,
    [5] = 37,
    [6] = 145,
    [7] = 157,
    [8] = 169,
}

local function GetBarGlowActionSlot(barIdx, btnIdx)
    local startSlot = BG_ACTION_BAR_START_SLOTS[tonumber(barIdx or 0)]
    btnIdx = tonumber(btnIdx or 0)
    if not startSlot or btnIdx < 1 then
        return nil
    end
    return startSlot + btnIdx - 1
end

local function GetBarGlowTargetIdentifier(barIdx, btnIdx)
    local slot = GetBarGlowActionSlot(barIdx, btnIdx)
    if not slot or not ns.CDM_ResolveIdentifierFromActionSlot then
        return nil
    end
    return ns.CDM_ResolveIdentifierFromActionSlot(slot)
end

local function GetBarGlowIdentifierDisplayName(identifier)
    if type(identifier) == "number" and identifier > 0 then
        return (C_Spell.GetSpellName and C_Spell.GetSpellName(identifier)) or ("Spell " .. tostring(identifier))
    end
    if type(identifier) == "number" and identifier < 0 then
        local itemID = DecodeItemID(identifier) or -identifier
        return (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)) or (GetItemInfo and GetItemInfo(itemID)) or
            ("Item " .. tostring(itemID))
    end
    return "Unknown"
end

local function FindBarGlowActionButtonByIdentifier(identifier, assignedOnly)
    if not identifier then
        return nil, nil
    end

    local bg = ns.GetBarGlows and ns.GetBarGlows() or nil
    for barIdx = 1, 8 do
        for btnIdx = 1, 12 do
            local assignKey = barIdx .. "_" .. btnIdx
            if not assignedOnly or (bg and bg.assignments and bg.assignments[assignKey]) then
                if GetBarGlowTargetIdentifier(barIdx, btnIdx) == identifier then
                    return barIdx, btnIdx
                end
            end
        end
    end

    return nil, nil
end

local function GetActionButtonDisplayName(barIdx, btnIdx)
    local startSlot = BG_ACTION_BAR_START_SLOTS[barIdx]
    if not startSlot or not btnIdx then return nil end

    local slot = startSlot + btnIdx - 1
    local actionType, actionID = GetActionInfo(slot)
    if actionType == "spell" and actionID then
        return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(actionID)) or (GetSpellInfoSafe and GetSpellInfoSafe(actionID))
    end
    if actionType == "macro" and actionID then
        local spellID = GetMacroSpell and GetMacroSpell(actionID)
        if spellID then
            return (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)) or (GetSpellInfoSafe and GetSpellInfoSafe(spellID))
        end
        local macroName = GetMacroInfo and select(1, GetMacroInfo(actionID))
        if macroName and macroName ~= "" then
            return macroName
        end
    end
    if actionType == "item" and actionID then
        return (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(actionID)) or GetItemInfo(actionID)
    end
    return nil
end

local function CreateInlineColorSwatch(parent, getColor, setColor, size)
    if not (parent and getColor and setColor) then return nil end
    size = size or 18

    local swatch = CreateFrame("Button", nil, parent)
    swatch:SetSize(size, size)
    swatch:SetFrameLevel((parent:GetFrameLevel() or 1) + 5)
    if KT.AddBackdrop then KT:AddBackdrop(swatch, 0.08, 0.08, 0.11, 1) end
    if KT.AddBorder then KT:AddBorder(swatch, 0.20, 0.20, 0.25, 1) end

    local fill = swatch:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", swatch, "TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", swatch, "BOTTOMRIGHT", -2, 2)

    local function RefreshSwatch()
        local r, g, b = getColor()
        fill:SetColorTexture(r or 1, g or 1, b or 1, 1)
    end

    RefreshSwatch()
    swatch:SetScript("OnClick", function()
        local r, g, b = getColor()
        ColorPickerFrame:SetupColorPickerAndShow({
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                setColor(nr, ng, nb)
                RefreshSwatch()
            end,
            cancelFunc = function(prev)
                setColor(prev.r, prev.g, prev.b)
                RefreshSwatch()
            end,
            hasOpacity = false,
            r = r or 1,
            g = g or 1,
            b = b or 1,
        })
    end)

    return swatch, RefreshSwatch
end

AddGlowColorRow = function(widgets, parent, y, label, getColor, setColor)
    if widgets and widgets.ColorSwatch then
        return widgets:ColorSwatch(parent, label, y, getColor, setColor, false)
    end
    return nil, 0
end

local function GetActionBarShapeForIndex(barIdx)
    local db = KT.db and KT.db.profile and KT.db.profile.actionbars
    if not db or db.buttonStyle == "BLIZZARD" then return "NONE" end
    local keyByBar = {
        [1] = "shapeBar1", [2] = "shapeBar2", [3] = "shapeBar3", [4] = "shapeBar4",
        [5] = "shapeBar5", [6] = "shapeBar6", [7] = "shapeBar7", [8] = "shapeBar8",
    }
    local specificKey = keyByBar[barIdx]
    local specific = specificKey and db[specificKey] or "GLOBAL"
    if not specific or specific == "GLOBAL" then
        return db.buttonShape or "NONE"
    end
    return specific
end

local function GetActionBarShapeKeyForPreview(barIdx)
    local shape = tostring(GetActionBarShapeForIndex(barIdx) or "NONE"):upper()
    local map = {
        CIRCLE = "circle",
        CSQUARE = "csquare",
        DIAMOND = "diamond",
        HEXAGON = "hexagon",
        SHIELD = "shield",
        PORTRAIT = "portrait",
        SQUARE = "square",
    }
    return map[shape] or "none"
end

-- Check if a specific action bar uses a custom shape (not "none"/"cropped")
local function BarHasCustomShape(barIdx)
    return GetActionBarShapeKeyForPreview(barIdx) ~= "none"
end

ApplyPreviewShapeToSlot = function(slot, shapeKey)
    if not slot or not slot._icon or not slot._bg then return end

    local function RemoveShape()
        if slot._shapeMask then
            pcall(slot._icon.RemoveMaskTexture, slot._icon, slot._shapeMask)
            pcall(slot._bg.RemoveMaskTexture, slot._bg, slot._shapeMask)
        end
        if slot._shapeBorder then
            slot._shapeBorder:Hide()
        end
    end

    if not shapeKey or shapeKey == "none" or shapeKey == "cropped" then
        RemoveShape()
        if shapeKey == "cropped" then
            slot._icon:SetTexCoord(0.08, 0.92, 0.18, 0.82)
        else
            slot._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        return
    end

    local maskTex = AB_SHAPE_MASKS[shapeKey]
    if not maskTex then
        RemoveShape()
        slot._icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        return
    end

    if not slot._shapeMask then
        slot._shapeMask = slot:CreateMaskTexture()
        slot._shapeMask:SetAllPoints(slot)
    end
    slot._shapeMask:SetTexture(maskTex)

    pcall(slot._icon.RemoveMaskTexture, slot._icon, slot._shapeMask)
    pcall(slot._bg.RemoveMaskTexture, slot._bg, slot._shapeMask)
    pcall(slot._icon.AddMaskTexture, slot._icon, slot._shapeMask)
    pcall(slot._bg.AddMaskTexture, slot._bg, slot._shapeMask)
    slot._icon:SetTexCoord(0.03, 0.97, 0.03, 0.97)

    if not slot._shapeBorder then
        slot._shapeBorder = slot:CreateTexture(nil, "OVERLAY", nil, 7)
        slot._shapeBorder:SetAllPoints(slot)
    end
    local borderTex = AB_SHAPE_BORDERS[shapeKey]
    if borderTex then
        slot._shapeBorder:SetTexture(borderTex)
        slot._shapeBorder:SetVertexColor(0, 0, 0, 1)
        slot._shapeBorder:Show()
    else
        slot._shapeBorder:Hide()
    end
end

-- Preview glow state tracking
local _bgPreviewGlowActive = {}
local _bgPreviewGlowOverlays = {}
local _bgSpellPickerMenu

local function ShowBarGlowSpellPicker(anchorFrame, barIdx, btnIdx, onChanged)
    if _bgSpellPickerMenu then _bgSpellPickerMenu:Hide() end

    local bg = ns.GetBarGlows()
    local assignKey = barIdx .. "_" .. btnIdx
    local buffList = bg.assignments[assignKey] or {}

    -- Build set of currently assigned spellIDs
    local assignedSet = {}
    for _, entry in ipairs(buffList) do
        if entry.spellID then assignedSet[entry.spellID] = true end
    end

    -- Get tracked and untracked buff spells
    local tracked, untracked = ns.GetAllCDMBuffSpells()
    if #tracked == 0 and #untracked == 0 then return end

    -- Standard dropdown colors
    local mBgR   = 0.1 -- R or 0.075
    local mBgG   = 0.1 -- G or 0.113
    local mBgB   = 0.1 -- B or 0.141
    local mBgA   = 0.1 -- HA or 0.98
    local mBrdA  = 0.2 -- A or 0.20
    local hlA    = 0.1 -- A or 0.08
    local tDimR  = 0.7 -- R or 0.7
    local tDimG  = 0.7 -- G or 0.7
    local tDimB  = 0.7 -- B or 0.7
    local tDimA  = 0.7 -- A or 0.85
    local accent = { r = ACCENT.r, g = ACCENT.g, b = ACCENT.b }

    local menuW  = 240
    local ITEM_H = 26
    local MAX_H  = 300

    local menu   = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(300)
    menu:SetClampedToScreen(true)
    menu:SetSize(menuW, 10)
    if KT.AddBackdrop then KT:AddBackdrop(menu, 0.08, 0.08, 0.10, 0.98) end
    if KT.AddBorder then KT:AddBorder(menu, 0.2, 0.2, 0.2, 1) end

    local mbg = menu:CreateTexture(nil, "BACKGROUND")
    mbg:SetAllPoints()
    mbg:SetColorTexture(mBgR, mBgG, mBgB, 0.98)

    local inner = CreateFrame("Frame", nil, menu)
    inner:SetWidth(menuW)
    inner:SetPoint("TOPLEFT")

    local mH = 4

    local function MakeCheckItem(sp, isUntracked)
        local item = CreateFrame("Button", nil, inner)
        item:SetHeight(ITEM_H)
        item:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH)
        item:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH)
        item:SetFrameLevel(menu:GetFrameLevel() + 2)

        -- Checkbox
        local cbSize = 14
        local cb = item:CreateTexture(nil, "ARTWORK")
        cb:SetSize(cbSize, cbSize)
        cb:SetPoint("LEFT", 8, 0)
        local isChecked = assignedSet[sp.spellID] or false
        if isChecked then
            cb:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1)
        else
            cb:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        end
        -- Checkbox border
        for edge = 1, 4 do
            local t = item:CreateTexture(nil, "OVERLAY", nil, 7)
            t:SetColorTexture(0.4, 0.4, 0.4, 0.6)
            if edge == 1 then
                t:SetPoint("TOPLEFT", cb, "TOPLEFT"); t:SetPoint("TOPRIGHT", cb, "TOPRIGHT"); t:SetHeight(1)
            elseif edge == 2 then
                t:SetPoint("BOTTOMLEFT", cb, "BOTTOMLEFT"); t:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT"); t
                    :SetHeight(1)
            elseif edge == 3 then
                t:SetPoint("TOPLEFT", cb, "TOPLEFT"); t:SetPoint("BOTTOMLEFT", cb, "BOTTOMLEFT"); t:SetWidth(1)
            else
                t:SetPoint("TOPRIGHT", cb, "TOPRIGHT"); t:SetPoint("BOTTOMRIGHT", cb, "BOTTOMRIGHT"); t:SetWidth(1)
            end
        end

        -- Icon
        local ico = item:CreateTexture(nil, "ARTWORK")
        local icoSz = ITEM_H - 4
        ico:SetSize(icoSz, icoSz)
        ico:SetPoint("RIGHT", item, "RIGHT", -6, 0)
        if sp.icon then ico:SetTexture(sp.icon) end
        ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Label
        local lbl = item:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT_PATH, 11, GetCDMOptOutline())
        lbl:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        lbl:SetPoint("RIGHT", ico, "LEFT", -4, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false); lbl:SetMaxLines(1)
        lbl:SetText(sp.name)
        lbl:SetTextColor(tDimR, tDimG, tDimB, tDimA)

        local hl = item:CreateTexture(nil, "ARTWORK", nil, -1)
        hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0)

        item:SetScript("OnEnter", function()
            lbl:SetTextColor(1, 1, 1, 1)
            hl:SetColorTexture(1, 1, 1, hlA)
        end)
        item:SetScript("OnLeave", function()
            lbl:SetTextColor(tDimR, tDimG, tDimB, tDimA)
            hl:SetColorTexture(1, 1, 1, 0)
        end)
        item:SetScript("OnClick", function()
            if isUntracked then
                -- Fire popup to send user to Blizzard CDM
                menu:Hide()
                OpenBlizzardCDMSettings()
                return
            end
            -- Toggle assignment
            if assignedSet[sp.spellID] then
                -- Remove
                assignedSet[sp.spellID] = nil
                for idx = #buffList, 1, -1 do
                    if buffList[idx].spellID == sp.spellID then
                        table.remove(buffList, idx)
                        break
                    end
                end
                cb:SetColorTexture(0.2, 0.2, 0.2, 0.8)
            else
                -- Add with defaults
                assignedSet[sp.spellID] = true
                buffList[#buffList + 1] = {
                    spellID = sp.spellID,
                    useGlobalGlow = true,
                    useGlobalColor = true,
                    mode = "ACTIVE",
                }
                cb:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1)
            end
            bg.assignments[assignKey] = buffList
            Refresh()
            if onChanged then onChanged() end
        end)

        mH = mH + ITEM_H
    end

    -- Tracked buffs
    for _, sp in ipairs(tracked) do MakeCheckItem(sp, false) end

    -- Divider
    if #tracked > 0 and #untracked > 0 then
        local div = inner:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1); div:SetColorTexture(1, 1, 1, 0.10)
        div:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH - 4)
        div:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH - 4)
        mH = mH + 9
    end

    -- Untracked buffs
    for _, sp in ipairs(untracked) do MakeCheckItem(sp, true) end

    local totalH = mH + 4
    inner:SetHeight(totalH)

    if totalH > MAX_H then
        menu:SetHeight(MAX_H)
        local scrollBg = menu:CreateTexture(nil, "BORDER", nil, -1)
        scrollBg:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1)
        scrollBg:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1, 1)
        scrollBg:SetColorTexture(mBgR, mBgG, mBgB, 0.96)
        local sf = CreateFrame("ScrollFrame", nil, menu)
        sf:SetPoint("TOPLEFT"); sf:SetPoint("BOTTOMRIGHT")
        sf:SetFrameLevel(menu:GetFrameLevel() + 1)
        sf:EnableMouseWheel(true)
        sf:SetScrollChild(inner)
        inner:SetWidth(menuW)
        local scrollPos = 0
        local maxScroll = totalH - MAX_H
        sf:SetScript("OnMouseWheel", function(_, delta)
            scrollPos = math.max(0, math.min(maxScroll, scrollPos - delta * 30))
            sf:SetVerticalScroll(scrollPos)
        end)
    else
        menu:SetHeight(totalH)
        inner:SetParent(menu)
        inner:SetPoint("TOPLEFT")
    end

    menu:ClearAllPoints()
    menu:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -2)

    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetFrameStrata("FULLSCREEN_DIALOG")
    closer:SetFrameLevel(menu:GetFrameLevel() - 1)
    closer:SetAllPoints(UIParent)
    closer:SetScript("OnClick", function()
        menu:Hide(); closer:Hide()
    end)
    menu:HookScript("OnHide", function() closer:Hide() end)
    closer:Show()

    menu:Show()
    _bgSpellPickerMenu = menu
end

---------------------------------------------------------------------------
--  Bar Glows: BuildBarGlowsPage (v2)
---------------------------------------------------------------------------
local function BuildBarGlowsAdvancedTab(sc, W, startY, p)
    local parent = sc
    local y = -startY
    local _, h

    local bg = ns.GetBarGlows()
    local curBar = bg.selectedBar or 1
    local curBtn = bg.selectedButton -- nil = no selection
    local curBD = SelectedCDMBar()
    local selectedTargetIdentifier = bg.selectedSpellIdentifier
    if selectedTargetIdentifier == nil and curBtn then
        selectedTargetIdentifier = GetBarGlowTargetIdentifier(curBar, curBtn)
    end
    local selectedPreviewFrame

    local accentR, accentG, accentB = CurrentAccentColor()
    local ACCENT = { r = accentR, g = accentG, b = accentB }

    _, h = W:SectionHeader(parent, LText("Bar Glows"), y); y = y - h
    _, h = W:Label(parent, LText("Set global defaults and override them from the selected CDM icon, while keeping action bar mappings intact."), y,
        11); y = y - h

    local globalRow
    globalRow, h = W:DualRow(parent, y,
        {
            type = "toggle",
            text = LText("Enable Bar Glows Module"),
            getValue = function() return bg.enabled ~= false end,
            setValue = function(v)
                bg.enabled = v and true or false
                RefreshBarGlowConfigUI(true)
            end
        },
        {
            type = "dropdown",
            text = LText("Global Glow Style"),
            values = { blizzard = LText("Proc Glow (WoW)"), autocast = LText("AutoCast Shine"), pixel = LText("Pixel Border"), none = LText("None") },
            order = { "blizzard", "autocast", "pixel", "none" },
            getValue = function() return tostring(bg.glowStyle or "blizzard") end,
            setValue = function(v)
                bg.glowStyle = v
                RefreshBarGlowConfigUI(true)
            end
        }
    ); y = y - h

    local globalColorRow
    globalColorRow, h = W:DualRow(parent, y,
        {
            type = "toggle",
            text = LText("Global Class Colored Glow"),
            getValue = function() return bg.classColor == true end,
            setValue = function(v)
                bg.classColor = v and true or false
                RefreshBarGlowConfigUI(true)
            end
        },
        {
            type = "dropdown",
            text = LText("Cooldown Proc Glow"),
            values = { blizzard = LText("Proc Glow (WoW)"), autocast = LText("AutoCast Shine"), pixel = LText("Pixel Border"), none = LText("None") },
            order = { "blizzard", "autocast", "pixel", "none" },
            getValue = function() return tostring(bg.procGlowStyle or "blizzard") end,
            setValue = function(v)
                bg.procGlowStyle = v
                RefreshBarGlowConfigUI(true)
            end
        }
    ); y = y - h

    _, h = AddGlowColorRow(W, parent, y,
        LText("Global Glow Color"),
        function()
            return ResolveBarGlowColorForRender(nil, bg)
        end,
        function(r, g, b)
            bg.glowColor = { r = r, g = g, b = b }
            bg.classColor = false
            RefreshBarGlowConfigUI(true)
        end
    ); y = y - h

    _, h = W:Spacer(parent, y, 8); y = y - h

    -------------------------------------------------------------------
    --  Content Header: Live CDM Bar Preview
    -------------------------------------------------------------------

    for idx, ov in pairs(_bgPreviewGlowOverlays) do
        ns.StopNativeGlow(ov)
        if ov.Hide then ov:Hide() end
        _bgPreviewGlowActive[idx] = nil
        _bgPreviewGlowOverlays[idx] = nil
    end

    local headerBuilder = function(headerFrame, width)
        local bd = SelectedCDMBar()
        local tracked = GetTrackedList(bd)
        if not bd or #tracked == 0 then
            return 0
        end

        local iconSize = bd.iconSize or 36
        local iconH = (bd.iconShape == "cropped") and math.floor(iconSize * 0.80 + 0.5) or iconSize
        local spacing = bd.spacing or 2
        local grow = bd.growDirection or "RIGHT"
        local numRows = math.max(1, bd.numRows or 1)
        local isHoriz = (grow == "RIGHT" or grow == "LEFT")
        local stride = math.max(1, math.ceil(#tracked / numRows))
        local totalW, totalH
        if isHoriz then
            totalW = (stride * iconSize) + ((stride - 1) * spacing)
            totalH = (numRows * iconH) + ((numRows - 1) * spacing)
        else
            totalW = (numRows * iconSize) + ((numRows - 1) * spacing)
            totalH = (stride * iconH) + ((stride - 1) * spacing)
        end
        local startX = math.max(0, math.floor((width - totalW) / 2))
        local startY = y
        local headerH = totalH + 20
        local stepW = iconSize + spacing
        local stepH = iconH + spacing

        local function GetPreviewOffsets(index)
            local idx = index - 1
            local col = idx % stride
            local row = math.floor(idx / stride)
            local rowStart = row * stride
            local iconsInRow = math.min(stride, #tracked - rowStart)

            if grow == "RIGHT" then
                local flippedRow = (numRows - 1) - row
                local rowOffset = math.floor((stride - iconsInRow) * stepW / 2)
                return startX + col * stepW + rowOffset, startY - flippedRow * stepH
            elseif grow == "LEFT" then
                local flippedRow = (numRows - 1) - row
                local rowOffset = math.floor((stride - iconsInRow) * stepW / 2)
                return startX + totalW - iconSize - (col * stepW + rowOffset), startY - flippedRow * stepH
            elseif grow == "DOWN" then
                local flippedRow = (numRows - 1) - row
                local rowOffset = math.floor((stride - iconsInRow) * stepH / 2)
                return startX + flippedRow * stepW, startY - (col * stepH + rowOffset)
            else
                local rowOffset = math.floor((stride - iconsInRow) * stepH / 2)
                return startX + row * stepW, startY - (totalH - iconH - (col * stepH + rowOffset))
            end
        end

        for i, identifier in ipairs(tracked) do
            local xOff, yOff = GetPreviewOffsets(i)
            local isSelected = (selectedTargetIdentifier ~= nil and identifier == selectedTargetIdentifier)

            local bf = CreateFrame("Button", nil, headerFrame)
            bf:SetSize(iconSize, iconH)
            bf:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", xOff, yOff)
            bf:RegisterForClicks("LeftButtonUp", "RightButtonDown")

            local bgTex = bf:CreateTexture(nil, "BACKGROUND")
            bgTex:SetAllPoints()
            bgTex:SetColorTexture(0.06, 0.08, 0.10, 0.5)

            local iconTex = bf:CreateTexture(nil, "ARTWORK")
            iconTex:SetAllPoints()
            DisablePixelSnap(iconTex)

            local tex
            if type(identifier) == "number" and identifier > 0 then
                tex = C_Spell.GetSpellTexture(identifier)
            elseif type(identifier) == "number" and identifier < 0 then
                tex = C_Item.GetItemIconByID(DecodeItemID(identifier) or -identifier)
            end

            if tex then
                iconTex:SetTexture(tex)
                iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            else
                iconTex:SetColorTexture(0, 0, 0, 0.5)
            end

            if bd.showKeybind then
                local keybind = GetPreviewKeybind(identifier)
                if keybind then
                    local kbTxt = bf:CreateFontString(nil, "OVERLAY")
                    kbTxt:SetFont(FONT_PATH, bd.keybindSize or 13, GetKeybindFontFlags(bd))
                    kbTxt:SetPoint("TOPLEFT", bf, "TOPLEFT", bd.keybindOffsetX or 2, bd.keybindOffsetY or -2)
                    kbTxt:SetTextColor(bd.keybindR or 1, bd.keybindG or 1, bd.keybindB or 1, bd.keybindA or 0.9)
                    kbTxt:SetText(keybind)
                end
            end

            local edges = {}
            for e = 1, 4 do
                local t = bf:CreateTexture(nil, "OVERLAY", nil, 7)
                t:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 1)
                if not isSelected then t:Hide() end
                edges[e] = t
            end
            edges[1]:SetHeight(2); edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT")
            edges[2]:SetHeight(2); edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT")
            edges[3]:SetWidth(2); edges[3]:SetPoint("TOPLEFT", edges[1], "BOTTOMLEFT"); edges[3]:SetPoint("BOTTOMLEFT", edges[2], "TOPLEFT")
            edges[4]:SetWidth(2); edges[4]:SetPoint("TOPRIGHT", edges[1], "BOTTOMRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT", edges[2], "TOPRIGHT")

            if not isSelected then
                bf:SetScript("OnEnter", function() for e = 1, 4 do edges[e]:Show() end end)
                bf:SetScript("OnLeave", function() for e = 1, 4 do edges[e]:Hide() end end)
            else
                selectedPreviewFrame = bf
            end

            local assignedBar, assignedBtn = FindBarGlowActionButtonByIdentifier(identifier, true)
            local assignKey = assignedBar and assignedBtn and (assignedBar .. "_" .. assignedBtn) or nil
            local assigns = assignKey and bg.assignments[assignKey] or nil
            if assigns and #assigns > 0 then
                local dotSize = 4
                local dotGap = 2
                local totalDotsW = #assigns * dotSize + (#assigns - 1) * dotGap
                local dotStartX = (iconSize - totalDotsW) / 2
                for di, aEntry in ipairs(assigns) do
                    local dot = bf:CreateTexture(nil, "OVERLAY", nil, 7)
                    dot:SetSize(dotSize, dotSize)
                    dot:SetPoint("BOTTOM", bf, "BOTTOM", dotStartX + (di - 1) * (dotSize + dotGap) + dotSize / 2 - iconSize / 2, 2)
                    local dr, dg, db = ResolveBarGlowColorForRender(aEntry, bg)
                    dot:SetColorTexture(dr, dg, db, 1)
                end
            end

            if isSelected then
                local previewKey = "live_" .. tostring(identifier)
                local previewEntry = assigns and assigns[1] or nil
                local previewStyle = 0
                local pr, pg, pb

                if assigns and #assigns > 0 then
                    local previewIndex = bg.selectedAssignment or 1
                    if previewIndex > #assigns then previewIndex = 1 end
                    previewEntry = assigns[previewIndex] or assigns[1]
                end

                if bg.enabled == false then
                    previewStyle = 0
                else
                    previewStyle = (ns.ResolveBarGlowStyleForTarget and ns.ResolveBarGlowStyleForTarget(identifier, previewEntry, bg, true))
                        or ResolveBarGlowStyleForRender(previewEntry and previewEntry.glowStyle or nil, bg.procGlowStyle or bg.glowStyle)
                    pr, pg, pb = ResolveBarGlowColorForTargetOrRender(identifier, previewEntry, bg)
                end

                if previewStyle ~= 0 then
                    local ov = CreateFrame("Frame", nil, bf)
                    ov:SetAllPoints(bf)
                    ov:SetFrameLevel(bf:GetFrameLevel() + 10)
                    ov._kuiUseSelfGlowTarget = true
                    ov._spellID = identifier
                    ov._baseSpellID = identifier
                    _bgPreviewGlowOverlays[previewKey] = ov
                    ns.StartNativeGlow(ov, previewStyle, pr, pg, pb)
                    _bgPreviewGlowActive[previewKey] = true
                end
            end

            bf:SetScript("OnClick", function(self, button)
                local targetBar, targetBtn = FindBarGlowActionButtonByIdentifier(identifier, false)
                bg.selectedSpellIdentifier = identifier
                EnsureBarGlowSpellOverrideForRender(identifier, bg)
                bg.selectedBar = targetBar or bg.selectedBar
                bg.selectedButton = targetBtn
                bg.selectedAssignment = 1

                if button == "RightButton" and targetBar and targetBtn then
                    ShowBarGlowSpellPicker(self, targetBar, targetBtn, function()
                        Refresh()
                        if KT.RefreshPage then KT:RefreshPage(true) end
                    end)
                else
                    Refresh()
                    if KT.RefreshPage then KT:RefreshPage(true) end
                end
            end)
        end

        return headerH
    end

    local W_safe_w = GetSCSafeWidth(parent)
    local cdmHeaderLabel = curBD and string.format(LText("Live %s Preview"), (curBD.name or curBD.key or "CDM")) or LText("Live CDM Preview")
    _, h = W:SectionHeader(parent, cdmHeaderLabel, y); y = y - h
    local headerH = headerBuilder(parent, W_safe_w)
    y = y - headerH - 15

    -------------------------------------------------------------------
    --  Scrollable content area
    -------------------------------------------------------------------

    if curBD then
        _, h = W:Label(parent, LText("Selected CDM Bar:") .. " " .. tostring(curBD.name or curBD.key or LText("Unknown")), y, 11)
        y = y - h
    end

    if selectedTargetIdentifier ~= nil then
        local selectedSpellName = GetBarGlowIdentifierDisplayName(selectedTargetIdentifier)
        _, h = W:SectionHeader(parent, LText("Selected CDM Skill Glow"), y); y = y - h
        _, h = W:Label(parent, selectedSpellName, y, 12); y = y - h

        local spellOverride = EnsureBarGlowSpellOverrideForRender(selectedTargetIdentifier, bg)
        if spellOverride then
            local spellGlowLabels, spellGlowOrder = GetGlowStyleValues()
            local spellGlowRow
            spellGlowRow, h = W:DualRow(parent, y,
                {
                    type = "dropdown",
                    text = LText("Glow Type"),
                    values = spellGlowLabels,
                    order = spellGlowOrder,
                    getValue = function()
                        return NormalizeGlowStyleOption(spellOverride.glowStyle, bg.procGlowStyle or bg.glowStyle)
                    end,
                    setValue = function(v)
                        spellOverride.glowStyle = NormalizeGlowStyleOption(v, bg.procGlowStyle or bg.glowStyle)
                        spellOverride.useGlobalGlow = false
                        RefreshBarGlowConfigUI(true)
                    end,
                },
                {
                    type = "toggle",
                    text = LText("Use Global Glow"),
                    getValue = function() return spellOverride.useGlobalGlow == true end,
                    setValue = function(v)
                        spellOverride.useGlobalGlow = v and true or false
                        RefreshBarGlowConfigUI(true)
                    end,
                }
            ); y = y - h

            do
                local EYE_MEDIA = "Interface\\AddOns\\KullThranUI\\Modules\\SimplicityTextures\\"
                local EYE_VIS   = EYE_MEDIA .. "visible_eye.tga"
                local EYE_INVIS = EYE_MEDIA .. "invisible_eye.tga"
                local leftRgn   = spellGlowRow and spellGlowRow._leftRegion
                if leftRgn and leftRgn._control then
                    local pvKey = "selectedspell_" .. tostring(selectedTargetIdentifier)
                    local eyeBtn = CreateFrame("Button", nil, leftRgn)
                    eyeBtn:SetSize(26, 26)
                    eyeBtn:SetPoint("RIGHT", leftRgn._control, "LEFT", -8, 0)
                    eyeBtn:SetFrameLevel(leftRgn:GetFrameLevel() + 5)
                    eyeBtn:SetAlpha(0.4)
                    local eyeTex = eyeBtn:CreateTexture(nil, "OVERLAY")
                    eyeTex:SetAllPoints()
                    local function RefreshEye()
                        eyeTex:SetTexture(_bgPreviewGlowActive[pvKey] and EYE_INVIS or EYE_VIS)
                    end
                    RefreshEye()
                    eyeBtn:SetScript("OnClick", function()
                        if not selectedPreviewFrame then return end
                        if not _bgPreviewGlowOverlays[pvKey] then
                            local ov = CreateFrame("Frame", nil, selectedPreviewFrame)
                            ov:SetAllPoints(selectedPreviewFrame)
                            ov:SetFrameLevel(selectedPreviewFrame:GetFrameLevel() + 10)
                            ov._kuiUseSelfGlowTarget = true
                            ov._spellID = selectedTargetIdentifier
                            ov._baseSpellID = selectedTargetIdentifier
                            _bgPreviewGlowOverlays[pvKey] = ov
                        end
                        local ov = _bgPreviewGlowOverlays[pvKey]
                        if _bgPreviewGlowActive[pvKey] then
                            ns.StopNativeGlow(ov)
                            _bgPreviewGlowActive[pvKey] = false
                        else
                            local style = (ns.ResolveBarGlowStyleForTarget and ns.ResolveBarGlowStyleForTarget(selectedTargetIdentifier, nil, bg, true))
                                or ResolveBarGlowStyleForRender(spellOverride.glowStyle, bg.procGlowStyle or bg.glowStyle)
                            local cr, cg, cb = ResolveBarGlowColorForTargetOrRender(selectedTargetIdentifier, nil, bg)
                            ns.StartNativeGlow(ov, style, cr, cg, cb)
                            _bgPreviewGlowActive[pvKey] = true
                        end
                        RefreshEye()
                    end)
                    eyeBtn:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
                    eyeBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
                end
            end

            local spellColorRow
            spellColorRow, h = W:DualRow(parent, y,
                {
                    type = "toggle",
                    text = LText("Class Colored Glow"),
                    getValue = function()
                        if spellOverride.useGlobalColor then
                            return bg.classColor == true
                        end
                        return spellOverride.classColor == true
                    end,
                    setValue = function(v)
                        spellOverride.classColor = v and true or false
                        spellOverride.useGlobalColor = false
                        RefreshBarGlowConfigUI(true)
                    end,
                },
                {
                    type = "toggle",
                    text = LText("Use Global Color"),
                    getValue = function() return spellOverride.useGlobalColor == true end,
                    setValue = function(v)
                        spellOverride.useGlobalColor = v and true or false
                        RefreshBarGlowConfigUI(true)
                    end,
                }
            ); y = y - h

            _, h = AddGlowColorRow(W, parent, y,
                LText("Selected Spell Glow Color"),
                function()
                    return ResolveBarGlowColorForTargetOrRender(selectedTargetIdentifier, nil, bg)
                end,
                function(r, g, b)
                    spellOverride.glowColor = { r = r, g = g, b = b }
                    spellOverride.classColor = false
                    spellOverride.useGlobalColor = false
                    RefreshBarGlowConfigUI(true)
                end
            ); y = y - h

            _, h = W:Toggle(parent, LText("Use Global Swipe Color"), y,
                function() return spellOverride.useGlobalSwipeColor ~= false end,
                function(v)
                    spellOverride.useGlobalSwipeColor = v and true or false
                    RefreshBarGlowConfigUI(true)
                end
            ); y = y - h

            _, h = AddGlowColorRow(W, parent, y,
                LText("Selected Spell Swipe Color"),
                function()
                    return ResolveSwipeColorForTargetOrRender(selectedTargetIdentifier, spellOverride, bg, curBD)
                end,
                function(r, g, b)
                    spellOverride.swipeColor = { r = r, g = g, b = b }
                    spellOverride.useGlobalSwipeColor = false
                    RefreshBarGlowConfigUI(true)
                end
            ); y = y - h
        end

        _, h = W:Spacer(parent, y, 10); y = y - h
    end

    if curBtn then
        local actionName = GetActionButtonDisplayName(curBar, curBtn)
        local label = LText("Mapped Action Button:") .. " " .. LText("Bar") .. " " .. tostring(curBar) .. " " .. LText("Button") .. " " .. tostring(curBtn)
        if actionName and actionName ~= "" then
            label = label .. " - " .. actionName
        end
        _, h = W:Label(parent, label, y, 11)
        y = y - h
    end

    _, h = W:Spacer(parent, y, 8); y = y - h

    if not curBtn then
        -- No button selected: show centered hint text
        local hintFrame = CreateFrame("Frame", nil, parent)
        hintFrame:SetSize(parent:GetWidth(), 40)
        hintFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
        local hintText = hintFrame:CreateFontString(nil, "OVERLAY")
        hintText:SetFont(FONT_PATH, 12, GetCDMOptOutline())
        hintText:SetTextColor(0.5, 0.5, 0.5, 1)
        hintText:SetPoint("CENTER")
        hintText:SetText(LText("Left click a CDM icon to edit its mapped glow, right click it to assign or update buffs."))
        y = y - 40
    else
        -- Button selected: show assignments
        local assignKey = curBar .. "_" .. curBtn
        local buffList = bg.assignments[assignKey] or {}

        _, h = W:SectionHeader(parent, string.format(LText("Trigger Buff Assignments for Action Button %s / %s"), curBar, curBtn), y); y =
            y - h

        if #buffList == 0 then
            _, h = W:Spacer(parent, y, 8); y = y - h
            local emptyFrame = CreateFrame("Frame", nil, parent)
            emptyFrame:SetSize(parent:GetWidth(), 30)
            emptyFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            local emptyText = emptyFrame:CreateFontString(nil, "OVERLAY")
            emptyText:SetFont(FONT_PATH, 12, GetCDMOptOutline())
            emptyText:SetTextColor(0.5, 0.5, 0.5, 1)
            emptyText:SetPoint("LEFT", 22, 0)
            emptyText:SetText(LText("No buffs assigned. Right click the selected CDM icon in the preview to assign buffs."))
            y = y - 30
        else
            -- Build dropdown values for assigned buffs
            local buffLabels = {}
            local buffOrder = {}
            for idx, entry in ipairs(buffList) do
                local name = "Unknown"
                if entry.spellID and entry.spellID > 0 then
                    name = C_Spell.GetSpellName(entry.spellID) or ("Spell " .. entry.spellID)
                end
                buffLabels[idx] = name
                buffOrder[#buffOrder + 1] = idx
            end

            local selectedAssign = bg.selectedAssignment or 1
            if selectedAssign > #buffList then selectedAssign = 1 end

            _, h = W:Dropdown(parent, LText("Trigger Buff"), y,
                buffLabels,
                function() return selectedAssign end,
                function(v)
                    bg.selectedAssignment = tonumber(v) or 1
                    Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
                end,
                buffOrder
            ); y = y - h

            _, h = W:Spacer(parent, y, 6); y = y - h

            -- Per-buff settings
            local entry = buffList[selectedAssign]
            if entry then
                -- Row 1: Glow Type | Class Colored Glow
                local glowLabels, glowOrder = GetGlowStyleValues()
                local glowRow
                glowRow, h = W:DualRow(parent, y,
                    {
                        type = "dropdown",
                        text = LText("Glow Type"),
                        values = glowLabels,
                        order = glowOrder,
                        getValue = function()
                            return NormalizeGlowStyleOption(entry.glowStyle, bg.glowStyle)
                        end,
                        setValue = function(v)
                            entry.glowStyle = NormalizeGlowStyleOption(v, bg.glowStyle)
                            entry.useGlobalGlow = false
                            Refresh()
                            if KT.RefreshPage then KT:RefreshPage(true) end
                        end,
                    },
                    {
                        type = "toggle",
                        text = LText("Use Global Glow"),
                        getValue = function() return entry.useGlobalGlow == true end,
                        setValue = function(v)
                            entry.useGlobalGlow = v and true or false
                            Refresh()
                            Refresh(); if KT.RefreshPage then KT:RefreshPage(true) end
                        end,
                    }
                ); y = y - h

                -- Eyeball preview toggle (on left region of glow type row)
                do
                    local EYE_MEDIA = "Interface\\AddOns\\KullThranUI\\Modules\\SimplicityTextures\\"
                    local EYE_VIS   = EYE_MEDIA .. "visible_eye.tga"
                    local EYE_INVIS = EYE_MEDIA .. "invisible_eye.tga"
                    local leftRgn   = glowRow._leftRegion
                    if leftRgn and leftRgn._control then
                        local pvKey = assignKey .. "_" .. selectedAssign
                        local eyeBtn = CreateFrame("Button", nil, leftRgn)
                        eyeBtn:SetSize(26, 26)
                        eyeBtn:SetPoint("RIGHT", leftRgn._control, "LEFT", -8, 0)
                        eyeBtn:SetFrameLevel(leftRgn:GetFrameLevel() + 5)
                        eyeBtn:SetAlpha(0.4)
                        local eyeTex = eyeBtn:CreateTexture(nil, "OVERLAY")
                        eyeTex:SetAllPoints()
                        local function RefreshEye()
                            eyeTex:SetTexture(_bgPreviewGlowActive[pvKey] and EYE_INVIS or EYE_VIS)
                        end
                        RefreshEye()
                        eyeBtn:SetScript("OnClick", function()
                            if not selectedPreviewFrame then return end
                            if not _bgPreviewGlowOverlays[pvKey] then
                                local ov = CreateFrame("Frame", nil, selectedPreviewFrame)
                                ov:SetAllPoints(selectedPreviewFrame)
                                ov:SetFrameLevel(selectedPreviewFrame:GetFrameLevel() + 10)
                                _bgPreviewGlowOverlays[pvKey] = ov
                            end
                            local ov = _bgPreviewGlowOverlays[pvKey]
                            if _bgPreviewGlowActive[pvKey] then
                                ns.StopNativeGlow(ov)
                                _bgPreviewGlowActive[pvKey] = false
                            else
                                local style = ResolveBarGlowStyleForRender(
                                    (entry.useGlobalGlow and nil) or entry.glowStyle,
                                    bg.glowStyle
                                )
                                local cr, cg, cb = ResolveBarGlowColorForRender(
                                    (entry.useGlobalColor and { useGlobalColor = true } or entry), bg
                                )
                                ns.StartNativeGlow(ov, style, cr, cg, cb)
                                _bgPreviewGlowActive[pvKey] = true
                            end
                            RefreshEye()
                        end)
                        eyeBtn:SetScript("OnEnter", function(self) self:SetAlpha(0.7) end)
                        eyeBtn:SetScript("OnLeave", function(self) self:SetAlpha(0.4) end)
                    end
                end

                -- Row 2: Class color override | use global color
                local colorRow
                colorRow, h = W:DualRow(parent, y,
                    {
                        type = "toggle",
                        text = LText("Class Colored Glow"),
                        getValue = function()
                            if entry.useGlobalColor then
                                return bg.classColor == true
                            end
                            return entry.classColor == true
                        end,
                        setValue = function(v)
                            entry.classColor = v and true or false
                            entry.useGlobalColor = false
                            Refresh()
                            if KT.RefreshPage then KT:RefreshPage(true) end
                        end,
                    },
                    {
                        type = "toggle",
                        text = LText("Use Global Color"),
                        getValue = function() return entry.useGlobalColor == true end,
                        setValue = function(v)
                            entry.useGlobalColor = v and true or false
                            Refresh()
                            if KT.RefreshPage then KT:RefreshPage(true) end
                        end,
                    }
                ); y = y - h

                _, h = AddGlowColorRow(W, parent, y,
                    LText("Glow Color"),
                    function()
                        return ResolveBarGlowColorForRender(
                            (entry.useGlobalColor and { useGlobalColor = true } or entry), bg
                        )
                    end,
                    function(r, g, b)
                        entry.glowColor = { r = r, g = g, b = b }
                        entry.classColor = false
                        entry.useGlobalColor = false
                        Refresh()
                        if KT.RefreshPage then KT:RefreshPage(true) end
                    end
                ); y = y - h

                -- Row 2: Glow When (mode)
                _, h = W:Dropdown(parent, LText("Glow When"), y,
                    BG_MODE_VALUES,
                    function() return entry.mode or "ACTIVE" end,
                    function(v)
                        entry.mode = v
                        Refresh()
                    end,
                    BG_MODE_ORDER
                ); y = y - h

                _, h = W:Spacer(parent, y, 10); y = y - h

                -- Remove this buff assignment button
                _, h = W:Button(parent, LText("Remove This Buff"), y,
                    function()
                        table.remove(buffList, selectedAssign)
                        if #buffList == 0 then
                            bg.assignments[assignKey] = nil
                        end
                        Refresh()
                        if KT.RefreshPage then KT:RefreshPage(true) end
                    end
                ); y = y - h
            end
        end
    end

    return math.abs(y)
end

---------------------------------------------------------------------------


local _tbbSelectedBar = 1
local _tbbHeaderBuilder
local _tbbHeaderFixedH = 0
local _tbbPvFrame
local _tbbPvIcon
local BUFF_BARS_BLIZZARD_NOTICE = LText("You must first add the buffs in Blizzard CDM for them to appear in KUI CDM.")
local OPEN_BLIZZARD_CDM_LABEL = LText("Open Blizzard CDM")
local CDM_BUFFS_IMPORT_NOTICE = LText("You must first add the buffs in Blizzard CDM for them to appear in KUI CDM.")

OpenBlizzardCDMSettings = function()
    if InCombatLockdown and InCombatLockdown() then
        print("|cff0cd29fKUI:|r Blizzard CDM cannot be opened during combat.")
        return false
    end

    local cvs = _G["CooldownViewerSettings"]
    if not cvs then
        if UIParentLoadAddOn then
            pcall(UIParentLoadAddOn, "Blizzard_CooldownViewer")
        elseif C_AddOns and C_AddOns.LoadAddOn then
            pcall(C_AddOns.LoadAddOn, "Blizzard_CooldownViewer")
        end
        cvs = _G["CooldownViewerSettings"]
    end

    if cvs then
        if not (cvs.IsShown and cvs:IsShown()) then
            if cvs.TogglePanel then
                cvs:TogglePanel()
            elseif cvs.Show then
                cvs:Show()
            end
        end
        return true
    end

    print("|cff0cd29fKUI:|r Blizzard CDM is not available on this client.")
    return false
end

IsCDMBuffsBar = function(barConfig)
    return type(barConfig) == "table" and (barConfig.key == "buffs" or barConfig.barType == "buffs")
end

AddCDMBuffsNoticeBlock = function(parent, W, y, barConfig)
    if not IsCDMBuffsBar(barConfig) then
        return 0
    end

    local totalH = 0
    local _, h = W:Label(parent, CDM_BUFFS_IMPORT_NOTICE, -y, 11, { r = 1, g = 0.45, b = 0.45 })
    y = y + h
    totalH = totalH + h

    _, h = W:Button(parent, LText("Open Blizzard CDM"), -y, function()
        OpenBlizzardCDMSettings()
    end, 260, nil, nil, "CENTER", 28)
    totalH = totalH + h

    return totalH
end

-- Buff spell picker for tracked buff bars (reuses CDM buff spell list)
local _tbbSpellPickerMenu
local function GetTBBConfigIcon(cfg)
    if type(cfg) ~= "table" then return nil end

    if cfg.popularKey and ns and ns.TBB_POPULAR_BUFFS then
        for _, entry in ipairs(ns.TBB_POPULAR_BUFFS) do
            if entry.key == cfg.popularKey and entry.icon then
                return entry.icon
            end
        end
    end

    local spellID = tonumber(cfg.spellID) or 0
    if spellID > 0 and C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.iconID then
            return info.iconID
        end
    end

    return nil
end

local function ShowTBBSpellPicker(anchorFrame, barCfg, onChanged)
    if _tbbSpellPickerMenu then _tbbSpellPickerMenu:Hide() end

    local tracked, untracked = ns.GetAllCDMBuffSpells()
    if #tracked == 0 and #untracked == 0 then return end

    local mBgR   = 0.1 -- R or 0.075
    local mBgG   = 0.1 -- G or 0.113
    local mBgB   = 0.1 -- B or 0.141
    local mBgA   = 0.94
    local mBrdA  = 0.35
    local hlA    = 0.1 -- A or 0.08
    local tDimR  = 0.7 -- R or 0.7
    local tDimG  = 0.7 -- G or 0.7
    local tDimB  = 0.7 -- B or 0.7
    local tDimA  = 0.7 -- A or 0.85
    local accentR, accentG, accentB = CurrentAccentColor()
    local ACCENT = { r = accentR, g = accentG, b = accentB }

    local menuW  = 300
    local ITEM_H = 26
    local MAX_H  = 300

    local menu   = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(300)
    menu:SetClampedToScreen(true)
    menu:SetSize(menuW, 10)
    if menu.SetBackdrop then
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        menu:SetBackdropColor(mBgR, mBgG, mBgB, mBgA)
        menu:SetBackdropBorderColor(ACCENT.r, ACCENT.g, ACCENT.b, mBrdA)
    end

    local mbg = menu:CreateTexture(nil, "BACKGROUND")
    mbg:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1)
    mbg:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -1, 1)
    mbg:SetColorTexture(mBgR, mBgG, mBgB, mBgA)

    local inner = CreateFrame("Frame", nil, menu)
    inner:SetWidth(menuW - 2)
    inner:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1)

    local mH = 4

    local function AddNoticeBlock()
        local inset = 8
        local noticeWidth = menuW - (inset * 2)

        local title = inner:CreateFontString(nil, "OVERLAY")
        title:SetFont(FONT_PATH, 12, GetCDMOptOutline())
        title:SetPoint("TOPLEFT", inner, "TOPLEFT", inset, -mH)
        title:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -inset, -mH)
        title:SetJustifyH("LEFT")
        title:SetWordWrap(true)
        title:SetTextColor(ACCENT.r, ACCENT.g, ACCENT.b, 1)
        title:SetText(LText("Important"))
        local titleH = math.max(14, title:GetStringHeight())
        mH = mH + titleH + 4

        local noticeES = inner:CreateFontString(nil, "OVERLAY")
        noticeES:SetFont(FONT_PATH, 11, "")
        noticeES:SetWidth(noticeWidth)
        noticeES:SetPoint("TOPLEFT", inner, "TOPLEFT", inset, -mH)
        noticeES:SetJustifyH("LEFT")
        noticeES:SetWordWrap(true)
        noticeES:SetTextColor(0.92, 0.92, 0.94, 1)
        noticeES:SetText(BUFF_BARS_BLIZZARD_NOTICE)
        local noticeESH = math.max(14, noticeES:GetStringHeight())
        mH = mH + noticeESH + 3


        local openBtn = CreateFrame("Button", nil, inner, "UIPanelButtonTemplate")
        openBtn:SetSize(menuW - 16, 22)
        openBtn:SetPoint("TOPLEFT", inner, "TOPLEFT", inset, -mH)
        openBtn:SetText(OPEN_BLIZZARD_CDM_LABEL)
        openBtn:SetScript("OnClick", function()
            menu:Hide()
            OpenBlizzardCDMSettings()
        end)
        mH = mH + 26

        local div = inner:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1)
        div:SetColorTexture(1, 1, 1, 0.10)
        div:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH)
        div:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH)
        mH = mH + 8
    end

    AddNoticeBlock()

    local function MakeSpellItem(sp, isUntracked)
        local item = CreateFrame("Button", nil, inner)
        item:SetHeight(ITEM_H)
        item:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH)
        item:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH)
        item:SetFrameLevel(menu:GetFrameLevel() + 2)

        local itemBg = item:CreateTexture(nil, "BACKGROUND")
        itemBg:SetAllPoints()
        itemBg:SetColorTexture(1, 1, 1, isUntracked and 0.03 or 0.06)

        local ico = item:CreateTexture(nil, "ARTWORK")
        local icoSz = ITEM_H - 4
        ico:SetSize(icoSz, icoSz)
        ico:SetPoint("RIGHT", item, "RIGHT", -6, 0)
        if sp.icon then ico:SetTexture(sp.icon) end
        ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        local lbl = item:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT_PATH, 11, GetCDMOptOutline())
        lbl:SetPoint("LEFT", 8, 0)
        lbl:SetPoint("RIGHT", ico, "LEFT", -4, 0)
        lbl:SetJustifyH("LEFT")
        lbl:SetWordWrap(false); lbl:SetMaxLines(1)
        lbl:SetText(sp.name)
        lbl:SetTextColor(tDimR, tDimG, tDimB, tDimA)

        local hl = item:CreateTexture(nil, "ARTWORK", nil, -1)
        hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0)

        item:SetScript("OnEnter", function()
            lbl:SetTextColor(1, 1, 1, 1); hl:SetColorTexture(1, 1, 1, hlA)
        end)
        item:SetScript("OnLeave", function()
            lbl:SetTextColor(tDimR, tDimG, tDimB, tDimA); hl:SetColorTexture(1, 1, 1, 0)
        end)
        item:SetScript("OnClick", function()
            menu:Hide()
            if isUntracked then
                OpenBlizzardCDMSettings()
                return
            end
            barCfg.spellID = sp.spellID
            barCfg.name = sp.name
            Refresh()
            ns.BuildTrackedBuffBars()
            if onChanged then onChanged() end
        end)
        mH = mH + ITEM_H
    end

    for _, sp in ipairs(tracked) do MakeSpellItem(sp, false) end
    if #tracked > 0 and #untracked > 0 then
        local div = inner:CreateTexture(nil, "ARTWORK")
        div:SetHeight(1); div:SetColorTexture(1, 1, 1, 0.10)
        div:SetPoint("TOPLEFT", inner, "TOPLEFT", 1, -mH - 4)
        div:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -1, -mH - 4)
        mH = mH + 9
    end
    for _, sp in ipairs(untracked) do MakeSpellItem(sp, true) end

    local totalH = mH + 4
    inner:SetHeight(totalH)
    if totalH > MAX_H then
        menu:SetHeight(MAX_H)
        local sf = CreateFrame("ScrollFrame", nil, menu)
        sf:SetPoint("TOPLEFT"); sf:SetPoint("BOTTOMRIGHT")
        sf:SetFrameLevel(menu:GetFrameLevel() + 1)
        sf:EnableMouseWheel(true)
        sf:SetScrollChild(inner)
        inner:SetWidth(menuW)
        local scrollPos = 0
        local maxScroll = totalH - MAX_H
        sf:SetScript("OnMouseWheel", function(_, delta)
            scrollPos = math.max(0, math.min(maxScroll, scrollPos - delta * 30))
            sf:SetVerticalScroll(scrollPos)
        end)
    else
        menu:SetHeight(totalH)
        inner:SetParent(menu)
        inner:SetPoint("TOPLEFT")
    end

    menu:ClearAllPoints()
    menu:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -2)
    local closer = CreateFrame("Button", nil, UIParent)
    closer:SetFrameStrata("FULLSCREEN_DIALOG")
    closer:SetFrameLevel(menu:GetFrameLevel() - 1)
    closer:SetAllPoints(UIParent)
    closer:SetScript("OnClick", function()
        menu:Hide(); closer:Hide()
    end)
    menu:HookScript("OnHide", function() closer:Hide() end)
    closer:Show()
    menu:Show()
    _tbbSpellPickerMenu = menu
end

local function BuildBuffBarsTab(sc, W, startY, p)
    if not (ns.GetTrackedBuffBars and ns.BuildTrackedBuffBars) then
        local y, h = startY, 0
        _, h = W:Label(sc, LText("Buff Bars settings are unavailable: tracked buff bars module not loaded."), -y, 11)
        y = y + h
        return y - startY
    end

    local function RefreshTBB(soft)
        ns.BuildTrackedBuffBars()
        if ns.RefreshTBBResolvedIDs then
            ns.RefreshTBBResolvedIDs()
        end
        if not soft and KT.RefreshPage then
            KT:RefreshPage(true)
        end
    end

    local function GetSelectedTBB()
        local tbb = ns.GetTrackedBuffBars()
        local bars = tbb and tbb.bars or {}
        if _tbbSelectedBar < 1 then _tbbSelectedBar = 1 end
        if _tbbSelectedBar > #bars then _tbbSelectedBar = #bars end
        return bars[_tbbSelectedBar], tbb
    end

    local y, h = startY, 0
    local tbb = ns.GetTrackedBuffBars()
    local bars = tbb.bars or {}

    _, h = W:SectionHeader(sc, LText("Buff Bars"), -y); y = y + h
    _, h = W:Label(sc, LText("Tracked buff progress bars with their own spell, size, texture and colors."), -y, 11); y = y + h
    _, h = W:Label(sc, BUFF_BARS_BLIZZARD_NOTICE, -y, 11); y = y + h
    _, h = W:Button(sc, OPEN_BLIZZARD_CDM_LABEL, -y, function()
        OpenBlizzardCDMSettings()
    end); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "button",
            text = LText("+ Add Buff Bar"),
            onClick = function()
                if ns.AddTrackedBuffBar then
                    _tbbSelectedBar = ns.AddTrackedBuffBar() or (#(ns.GetTrackedBuffBars().bars or {}))
                    RefreshTBB()
                end
            end
        },
        {
            type = "button",
            text = LText("Delete Buff Bar"),
            onClick = function()
                local cfg = GetSelectedTBB()
                if cfg and ns.RemoveTrackedBuffBar then
                    ns.RemoveTrackedBuffBar(_tbbSelectedBar)
                    local count = #(ns.GetTrackedBuffBars().bars or {})
                    _tbbSelectedBar = math.max(1, math.min(_tbbSelectedBar, count))
                    RefreshTBB()
                end
            end
        }
    ); y = y + h

    if #bars == 0 then
        _, h = W:Label(sc, LText("No buff bars created yet. Add one to configure it here."), -y, 11)
        y = y + h
        return y - startY
    end

    local barLabels, barOrder = {}, {}
    for idx, cfg in ipairs(bars) do
        local label = cfg.name or ("Bar " .. idx)
        local spellID = tonumber(cfg.spellID) or 0
        if spellID > 0 and C_Spell and C_Spell.GetSpellName then
            label = C_Spell.GetSpellName(spellID) or label
        end
        barLabels[tostring(idx)] = label
        barOrder[#barOrder + 1] = tostring(idx)
    end

    _, h = W:Dropdown(sc, LText("Select Buff Bar"), -y,
        barLabels,
        function() return tostring(_tbbSelectedBar) end,
        function(v)
            _tbbSelectedBar = tonumber(v) or 1
            if KT.RefreshPage then KT:RefreshPage(true) end
        end,
        barOrder
    ); y = y + h

    local cfg = GetSelectedTBB()
    if not cfg then
        return y - startY
    end

    -- Grouping Settings (Global)
    _, h = W:DualRow(sc, -y,
        {
            type = "slider",
            text = LText("Group Spacing"),
            min = -5, max = 50, step = 1,
            getValue = function() return tbb.groupSpacing or 2 end,
            setValue = function(v) tbb.groupSpacing = v; RefreshTBB() end,
            disabled = function() return ns.TBBGroupedCount and ns.TBBGroupedCount() < 2 end,
            disabledTooltip = LText("Requires 2 or more grouped bars")
        },
        {
            type = "dropdown",
            text = LText("Group Grow Direction"),
            options = {DOWN=LText("Down"), UP=LText("Up"), LEFT=LText("Left"), RIGHT=LText("Right")},
            getValue = function() return tbb.groupGrowDirection or "DOWN" end,
            setValue = function(v) tbb.groupGrowDirection = v; RefreshTBB() end,
            order = {"DOWN", "UP", "LEFT", "RIGHT"},
            disabled = function() return ns.TBBGroupedCount and ns.TBBGroupedCount() < 2 end,
            disabledTooltip = LText("Requires 2 or more grouped bars")
        }
    ); y = y + h

    -- Grouped Toggle for selected bar
    _, h = W:Toggle(sc, LText("Group with other bars"), -y,
        function() return cfg.grouped ~= false end,
        function(v) cfg.grouped = v; RefreshTBB() end
    ); y = y + h

    local selectedSpellName = (cfg.spellID and cfg.spellID > 0 and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(cfg.spellID)) or cfg.name or LText("Choose a buff")
    local selectedSpellIcon = GetTBBConfigIcon(cfg)
    local spellButtonText = LText("Tracked Buff:") .. " " .. tostring(selectedSpellName)
    if selectedSpellIcon then
        spellButtonText = string.format("%s |T%s:16:16:0:0:64:64:5:59:5:59|t %s", LText("Tracked Buff:"), tostring(selectedSpellIcon), tostring(selectedSpellName))
    end
    local spellButtonRow
    spellButtonRow, h = W:Button(sc, spellButtonText, -y, function()
        local anchor = spellButtonRow
        if anchor and anchor.GetChildren then
            anchor = select(1, anchor:GetChildren()) or anchor
        end
        ShowTBBSpellPicker(anchor, cfg, function()
            RefreshTBB()
        end)
    end, 300, nil, nil, "CENTER", 28); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Enabled"),
            getValue = function() return cfg.enabled ~= false end,
            setValue = function(v)
                cfg.enabled = v and true or false
                RefreshTBB(true)
            end
        },
        {
            type = "toggle",
            text = LText("Vertical Orientation"),
            getValue = function() return cfg.verticalOrientation == true end,
            setValue = function(v)
                cfg.verticalOrientation = v and true or false
                RefreshTBB(true)
            end
        }
    ); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "slider",
            text = LText("Width"),
            min = 80,
            max = 600,
            step = 5,
            getValue = function() return cfg.width or 270 end,
            setValue = function(v)
                cfg.width = v
                RefreshTBB(true)
            end
        },
        {
            type = "slider",
            text = LText("Height"),
            min = 8,
            max = 60,
            step = 1,
            getValue = function() return cfg.height or 24 end,
            setValue = function(v)
                cfg.height = v
                RefreshTBB(true)
            end
        }
    ); y = y + h

    local textureValues = {}
    for key, label in pairs(ns.TBB_TEXTURE_NAMES or { none = LText("None") }) do
        textureValues[key] = LText(label)
    end
    local textureOrder = ns.TBB_TEXTURE_ORDER or { "none" }
    _, h = W:DualRow(sc, -y,
        {
            type = "dropdown",
            text = LText("Bar Texture"),
            values = textureValues,
            order = textureOrder,
            getValue = function() return tostring(cfg.texture or "none") end,
            setValue = function(v)
                cfg.texture = v
                RefreshTBB(true)
            end
        },
        {
            type = "toggle",
            text = LText("Show Spark"),
            getValue = function() return cfg.showSpark ~= false end,
            setValue = function(v)
                cfg.showSpark = v and true or false
                RefreshTBB(true)
            end
        }
    ); y = y + h

    local iconDisplayValues = { none = LText("No Icon"), left = LText("Left"), right = LText("Right") }
    local iconDisplayOrder = { "none", "left", "right" }
    _, h = W:DualRow(sc, -y,
        {
            type = "dropdown",
            text = LText("Icon Display"),
            values = iconDisplayValues,
            order = iconDisplayOrder,
            getValue = function() return tostring(cfg.iconDisplay or "none") end,
            setValue = function(v)
                cfg.iconDisplay = v
                RefreshTBB(true)
            end
        },
        {
            type = "slider",
            text = LText("Icon Size"),
            min = 12,
            max = 48,
            step = 1,
            getValue = function() return cfg.iconSize or 24 end,
            setValue = function(v)
                cfg.iconSize = v
                RefreshTBB(true)
            end
        }
    ); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Show Name"),
            getValue = function() return cfg.showName ~= false end,
            setValue = function(v)
                cfg.showName = v and true or false
                RefreshTBB(true)
            end
        },
        {
            type = "slider",
            text = LText("Name Size"),
            min = 8,
            max = 24,
            step = 1,
            getValue = function() return cfg.nameSize or 11 end,
            setValue = function(v)
                cfg.nameSize = v
                RefreshTBB(true)
            end
        }
    ); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Show Timer"),
            getValue = function() return cfg.showTimer ~= false end,
            setValue = function(v)
                cfg.showTimer = v and true or false
                RefreshTBB(true)
            end
        },
        {
            type = "slider",
            text = LText("Timer Size"),
            min = 8,
            max = 24,
            step = 1,
            getValue = function() return cfg.timerSize or 11 end,
            setValue = function(v)
                cfg.timerSize = v
                RefreshTBB(true)
            end
        }
    ); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Gradient Fill"),
            getValue = function() return cfg.gradientEnabled == true end,
            setValue = function(v)
                cfg.gradientEnabled = v and true or false
                RefreshTBB(true)
            end
        },
        {
            type = "slider",
            text = LText("Opacity"),
            min = 0,
            max = 100,
            step = 5,
            getValue = function() return math.floor(((cfg.opacity or 1) * 100) + 0.5) end,
            setValue = function(v)
                cfg.opacity = v / 100
                RefreshTBB(true)
            end
        }
    ); y = y + h

    _, h = AddGlowColorRow(W, sc, -y,
        LText("Fill Color"),
        function()
            local _, classToken = UnitClass("player")
            local classColor = classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]
            return cfg.fillR or (classColor and classColor.r) or 1,
                cfg.fillG or (classColor and classColor.g) or 1,
                cfg.fillB or (classColor and classColor.b) or 1
        end,
        function(r, g, b)
            cfg.fillR, cfg.fillG, cfg.fillB = r, g, b
            RefreshTBB(true)
        end
    ); y = y + h

    _, h = AddGlowColorRow(W, sc, -y,
        "Background Color",
        function()
            return cfg.bgR or 0, cfg.bgG or 0, cfg.bgB or 0
        end,
        function(r, g, b)
            cfg.bgR, cfg.bgG, cfg.bgB = r, g, b
            RefreshTBB(true)
        end
    ); y = y + h

    if cfg.gradientEnabled then
        _, h = AddGlowColorRow(W, sc, -y,
            "Gradient Color",
            function()
                return cfg.gradientR or 0.20, cfg.gradientG or 0.20, cfg.gradientB or 0.80
            end,
            function(r, g, b)
                cfg.gradientR, cfg.gradientG, cfg.gradientB = r, g, b
                RefreshTBB(true)
            end
        ); y = y + h
    end

    return y - startY
end
---------------------------------------------------------------------------


local TAB_H        = 30
local TAB_GAP      = 4
local _tabBarFrame = nil

local function BuildTabBar(sc, yOff)
    local tabs = {
        { id = "cdmbars",       label = "CDM Bars" },
        { id = "barglows",      label = "Bar Glows" },
        { id = "buffbars",      label = "Buff Bars" },
        { id = "customtracker", label = "KUI Tracker" },
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
    container:SetPoint("TOPLEFT", sc, "TOPLEFT", 0, yOff)
    container:SetPoint("TOPRIGHT", sc, "TOPRIGHT", -4, yOff)
    container:Show()

    local scW = GetSCSafeWidth(sc)
    local totalWidth = math.max(1, scW - 6)
    local usableWidth = totalWidth - ((#tabs - 1) * TAB_GAP)
    local tabWidth = math.floor(usableWidth / #tabs)
    local usedWidth = (tabWidth * #tabs) + ((#tabs - 1) * TAB_GAP)
    local remainder = totalWidth - usedWidth

    local previousButton
    for i, tab in ipairs(tabs) do
        local isActive = (tab.id == cdmActiveTab)
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetHeight(TAB_H)
        btn:SetWidth(tabWidth + ((i == #tabs) and remainder or 0))
        if i == 1 then
            btn:SetPoint("LEFT", container, "LEFT", 0, 0)
        else
            btn:SetPoint("LEFT", previousButton, "RIGHT", TAB_GAP, 0)
        end

        local lbl = btn:CreateFontString(nil, "OVERLAY")
        lbl:SetFont(FONT_PATH, 11, "OUTLINE")
        lbl:SetText(LText(tab.label)); lbl:SetAllPoints(); lbl:SetJustifyH("CENTER")
        btn._kuiPageLabel = lbl
        StyleModernPageButton(btn, isActive and "active" or "inactive", 11)

        local tid = tab.id
        btn:SetScript("OnClick", function()
            cdmActiveTab = tid; if KT.RefreshPage then KT:RefreshPage(true) end
        end)
        btn:Show()
        previousButton = btn
    end
    return container, containerH + 8
end

-- ============================================================================
-- PESTANA: CUSTOM BARS
-- ============================================================================
local function BuildBarGlowsLegacyTab(sc, W, startY, p)
    local y, h = startY, 0
    _, h = W:SectionHeader(sc, LText("Bar Glows"), -y); y = y + h
    _, h = W:Label(sc, LText("Enable action button glows for tracked buffs/debuffs."), -y, 11); y = y + h

    if not p.barGlows then
        p.barGlows = {
            enabled = true,
            glowStyle = "blizzard",
            glowColor = { r = 1, g = 0.82, b = 0.1 },
            classColor = false,
            procGlowStyle = "blizzard",
        }
    end
    local bg = p.barGlows
    if bg.procGlowStyle == nil then bg.procGlowStyle = "blizzard" end
    if bg.classColor == nil then bg.classColor = false end
    if not bg.glowColor then bg.glowColor = { r = 1, g = 0.82, b = 0.1 } end

    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Enable Bar Glows Module"),
            getValue = function() return bg.enabled end,
            setValue = function(v)
                bg.enabled = v; if KT.RefreshPage then KT:RefreshPage(true) end
            end
        },
        {
            type = "dropdown",
            text = LText("Global Glow Style"),
            values = { blizzard = LText("Proc Glow (WoW)"), autocast = LText("AutoCast Shine"), pixel = LText("Pixel Border"), none = LText("None") },
            order = { "blizzard", "autocast", "pixel", "none" },
            getValue = function() return tostring(bg.glowStyle or "blizzard") end,
            setValue = function(v)
                bg.glowStyle = v; if KT.RefreshPage then KT:RefreshPage(true) end
            end
        }
    ); y = y + h

    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Global Class Colored Glow"),
            getValue = function() return bg.classColor == true end,
            setValue = function(v)
                bg.classColor = v and true or false
                if KT.RefreshPage then KT:RefreshPage(true) end
            end
        },
        {
            type = "dropdown",
            text = LText("Cooldown Proc Glow"),
            values = { blizzard = LText("Proc Glow (WoW)"), autocast = LText("AutoCast Shine"), pixel = LText("Pixel Border"), none = LText("None") },
            order = { "blizzard", "autocast", "pixel", "none" },
            getValue = function() return tostring(bg.procGlowStyle or "blizzard") end,
            setValue = function(v)
                bg.procGlowStyle = v; if KT.RefreshPage then KT:RefreshPage(true) end
            end
        }
    ); y = y + h

    _, h = AddGlowColorRow(W, sc, -y,
        LText("Global Glow Color"),
        function()
            return ResolveBarGlowColorForRender(nil, bg)
        end,
        function(r, g, b)
            bg.glowColor = { r = r, g = g, b = b }
            bg.classColor = false
            if KT.RefreshPage then KT:RefreshPage(true) end
        end
    ); y = y + h

    return y
end

KT:RegisterPage("cooldownmanager", LText("Cooldown Manager"), 14, function(sc, W)
    for _, region in ipairs({ sc:GetRegions() }) do region:Hide() end
    for _, child in ipairs({ sc:GetChildren() }) do
        if child ~= _tabBarFrame and child ~= _cdmPreview then child:Hide() end
    end

    local y, h = 0, 0
    local p = DB()

    _, h = W:SectionHeader(sc, LText("Cooldown Manager"), -y); y = y + h
    _, h = W:Label(sc, LText("Central hub for Action Bar trackers, ability cooldowns and logic."), -y, 11); y = y + h
    _, h = W:DualRow(sc, -y,
        {
            type = "toggle",
            text = LText("Enable Module"),
            getValue = function() return p.cdmBars.enabled ~= false end,
            setValue = function(v)
                p.cdmBars.enabled = v and true or false
                Reload()
            end,
        },
        {
            type = "button",
            text = LText("Open Blizzard CDM"),
            onClick = function()
                OpenBlizzardCDMSettings()
            end,
        }
    ); y = y + h



    local tabFrame, tabH = BuildTabBar(sc, -y); y = y + tabH
    local sep, sepH = MakeSeparator(sc, -y); y = y + sepH + 6

    if not cdmActiveTab then cdmActiveTab = "cdmbars" end

    if cdmActiveTab == "cdmbars" then y = BuildCDMBarsBlocksTab(sc, W, y, p) end
    if cdmActiveTab == "customtracker" then y = BuildCustomTrackerTab(sc, W, y, p) end
    if cdmActiveTab == "barglows" then y = y + BuildBarGlowsAdvancedTab(sc, W, y, p) end
    if cdmActiveTab == "buffbars" then y = y + BuildBuffBarsTab(sc, W, y, p) end

    local safeY = math.floor(math.abs(type(y) == "number" and y or 1000)) + 100
    C_Timer.After(0.05, function()
        if sc and sc.GetParent then
            local container = sc:GetParent()
            if container and container.SetHeight then pcall(function() container:SetHeight(safeY) end) end
        end
    end)
    return math.floor(math.abs(y))
end)
