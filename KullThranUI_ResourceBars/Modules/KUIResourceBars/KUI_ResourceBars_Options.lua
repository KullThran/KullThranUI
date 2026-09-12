-------------------------------------------------------------------------------
--  KUI_ResourceBars_Options.lua
--  Panel de configuración nativo y visual para KullThranUI Resource Bars
-------------------------------------------------------------------------------
local addonName, ns = ...
local KT = LibStub("AceAddon-3.0"):GetAddon("KullThranUI")
local LSM = LibStub("LibSharedMedia-3.0", true)

local function LText(text)
    if type(text) ~= "string" then return text end
    if KT and KT.GetLocale then
        local L = KT:GetLocale()
        if L then return L[text] end
    end
    return text
end

local function CurrentAccentColor()
    local palette = (KT and KT.GetStylePalette and KT:GetStylePalette()) or KT.STYLE_PALETTE or nil
    local accent = palette and palette.accent or nil
    return (accent and accent.r) or KT.C_R or 1,
        (accent and accent.g) or KT.C_G or 0,
        (accent and accent.b) or KT.C_B or 0.3333333333
end

-- ============================================================================
-- HELPERS Y BASE DE DATOS
-- ============================================================================
local function DB()
    if _G._KRB_GetDB then return _G._KRB_GetDB() end
    return nil
end

local function Refresh()
    if _G._KRB_Apply then _G._KRB_Apply() end
end

local function RestoreResourceBarsDefaults()
    if not (KT and KT.db and KT.db.profile) then
        return
    end

    KT.db.profile.resourceBars = nil

    if _G._KRB_GetDB then
        _G._KRB_GetDB()
    end

    Refresh()

    if KT.RefreshPage then
        KT:RefreshPage(true)
    end
end

local function NormalizeColorMode(mode, fallbackClassColor)
    if mode == "spec" or mode == "power" or mode == "custom" then
        return mode
    end
    return (fallbackClassColor == false) and "custom" or "power"
end

local ResolveSectionColor

local function GetCurrentSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex or not GetSpecializationInfo then
        return nil
    end
    local specID = GetSpecializationInfo(specIndex)
    if type(specID) == "number" and specID > 0 then
        return specID
    end
    return nil
end

local function GetCurrentSpecName()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex or not GetSpecializationInfo then
        return nil
    end
    local _, specName = GetSpecializationInfo(specIndex)
    if type(specName) == "string" and specName ~= "" then
        return specName
    end
    return nil
end

local function GetPowerColor(powerType)
    if _G._KRB_GetPowerBarColor then
        local ok, r, g, b = pcall(_G._KRB_GetPowerBarColor, powerType)
        if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
            return r, g, b
        end
    end

    local colors = _G._KRB_PowerColors
    local fallback = colors and colors[powerType]
    if type(fallback) == "table" then
        return fallback[1], fallback[2], fallback[3]
    end
    return nil
end

local function IsCurrentSpecManaHidden(db)
    if _G._KRB_GetHideManaSetting then
        local ok, value = pcall(_G._KRB_GetHideManaSetting)
        if ok then
            return value == true
        end
    end
    return db and db.primary and db.primary.hideMana == true or false
end

local function SetCurrentSpecManaHidden(db, value)
    if _G._KRB_SetHideManaSetting then
        local ok = pcall(_G._KRB_SetHideManaSetting, value and true or false)
        if ok then
            return
        end
    end
    if db and db.primary then
        db.primary.hideMana = value and true or false
    end
end

local function GetLocalizedPowerLabel(globalKey, fallback)
    local value = _G[globalKey]
    if type(value) == "string" and value ~= "" then
        return value
    end
    return LText(fallback)
end

local function GetPowerColorEntries()
    local pt = _G._KRB_PowerTypes or {}
    local entries = {
        { power = pt.MANA, label = GetLocalizedPowerLabel("MANA", "Mana") },
        { power = pt.RAGE, label = GetLocalizedPowerLabel("RAGE", "Rage") },
        { power = pt.FOCUS, label = GetLocalizedPowerLabel("FOCUS", "Focus") },
        { power = pt.ENERGY, label = GetLocalizedPowerLabel("ENERGY", "Energy") },
        { power = pt.COMBO, label = GetLocalizedPowerLabel("COMBO_POINTS", "Combo Points") },
        { power = pt.RUNES, label = GetLocalizedPowerLabel("RUNES", "Runes") },
        { power = pt.RUNIC_POWER, label = GetLocalizedPowerLabel("RUNIC_POWER", "Runic Power") },
        { power = pt.SOUL_SHARDS, label = GetLocalizedPowerLabel("SOUL_SHARDS", "Soul Shards") },
        { power = pt.LUNAR_POWER, label = GetLocalizedPowerLabel("LUNAR_POWER", "Astral Power") },
        { power = pt.HOLY_POWER, label = GetLocalizedPowerLabel("HOLY_POWER", "Holy Power") },
        { power = pt.MAELSTROM, label = GetLocalizedPowerLabel("MAELSTROM", "Maelstrom") },
        { power = pt.CHI, label = GetLocalizedPowerLabel("CHI", "Chi") },
        { power = pt.INSANITY, label = GetLocalizedPowerLabel("INSANITY", "Insanity") },
        { power = pt.ARCANE, label = GetLocalizedPowerLabel("ARCANE_CHARGES", "Arcane Charges") },
        { power = pt.FURY, label = GetLocalizedPowerLabel("FURY", "Fury") },
        { power = pt.PAIN, label = GetLocalizedPowerLabel("PAIN", "Pain") },
        { power = pt.ESSENCE, label = GetLocalizedPowerLabel("ESSENCE", "Essence") },
    }

    local filtered = {}
    for i = 1, #entries do
        if type(entries[i].power) == "number" then
            filtered[#filtered + 1] = entries[i]
        end
    end
    return filtered
end

local function GetEditablePowerColor(db, powerType)
    if not db then
        return 1, 1, 1
    end
    db.powerColors = db.powerColors or {}
    local entry = db.powerColors[tostring(powerType or "")]
    if type(entry) == "table" then
        return entry.r or 1, entry.g or 1, entry.b or 1
    end
    local r, g, b = GetPowerColor(powerType)
    return r or 1, g or 1, b or 1
end

local function SetEditablePowerColor(db, powerType, r, g, b)
    if not db then
        return
    end
    db.powerColors = db.powerColors or {}
    db.powerColors[tostring(powerType or "")] = { r = r, g = g, b = b }
end

local function GetSecondaryPipColorKey(resource)
    if _G._KRB_GetSecondaryPipColorKey then
        local ok, key = pcall(_G._KRB_GetSecondaryPipColorKey, resource)
        if ok and type(key) == "string" and key ~= "" then
            return key
        end
    end

    if type(resource) ~= "table" then
        return nil
    end

    local pt = _G._KRB_PowerTypes or {}
    local powerType = tonumber(resource.power)
    if not powerType and resource.kind == "runes" then
        powerType = pt.RUNES
    end
    if not powerType then
        return nil
    end

    local _, classFile = UnitClass("player")
    classFile = classFile or "UNKNOWN"
    return string.format("%s:%s:%s", classFile, tostring(resource.kind or resource.type or "resource"), tostring(powerType))
end

local function GetSecondaryPipColorBucket(db, resource, createIfMissing)
    if not (db and db.secondary) then
        return nil, nil
    end

    local key = GetSecondaryPipColorKey(resource)
    if not key then
        return nil, nil
    end

    db.secondary.pipColors = db.secondary.pipColors or {}
    local bucket = db.secondary.pipColors[key]
    if type(bucket) ~= "table" then
        if not createIfMissing then
            return nil, key
        end
        bucket = {}
        db.secondary.pipColors[key] = bucket
    end

    return bucket, key
end

local function GetCurrentSecondaryPipResource()
    if _G._KRB_GetSecondaryResource then
        local ok, resource = pcall(_G._KRB_GetSecondaryResource)
        if ok and type(resource) == "table" and resource.type == "pips" then
            return resource
        end
    end
    return nil
end

local function GetSecondaryPipResourceLabel(resource)
    if type(resource) ~= "table" then
        return nil
    end

    local entries = GetPowerColorEntries()
    for i = 1, #entries do
        if entries[i].power == resource.power then
            return entries[i].label
        end
    end

    if resource.kind == "runes" then
        return GetLocalizedPowerLabel("RUNES", "Runes")
    end

    return LText("Class Resource")
end

local function GetSecondaryPipColor(db, resource, index)
    local bucket = GetSecondaryPipColorBucket(db, resource, false)
    local entry = bucket and bucket[tostring(index or "")]
    if type(entry) == "table" then
        local r = tonumber(entry.r)
        local g = tonumber(entry.g)
        local b = tonumber(entry.b)
        local a = tonumber(entry.a)
        if r and g and b then
            return r, g, b, a or (db and db.secondary and db.secondary.fillA) or 1
        end
    end

    return ResolveSectionColor(db and db.secondary, resource and resource.power)
end

local function SetSecondaryPipColor(db, resource, index, r, g, b, a)
    local bucket = GetSecondaryPipColorBucket(db, resource, true)
    if not bucket then
        return
    end

    bucket[tostring(index or "")] = { r = r, g = g, b = b, a = a }
end

local function ResetSecondaryPipColors(db, resource)
    local _, key = GetSecondaryPipColorBucket(db, resource, false)
    if key and db and db.secondary and db.secondary.pipColors then
        db.secondary.pipColors[key] = nil
    end
end

local function EnsureSpecColor(section, powerType)
    section.specColors = section.specColors or {}
    local specID = GetCurrentSpecID()
    local key = tostring(specID or 0)
    local entry = section.specColors[key]
    if type(entry) ~= "table" then
        entry = {
            r = section.fillR or 1,
            g = section.fillG or 1,
            b = section.fillB or 1,
            a = section.fillA or 1,
        }
        section.specColors[key] = entry
    end
    if entry.a == nil then
        entry.a = section.fillA or 1
    end
    return entry
end

ResolveSectionColor = function(section, powerType)
    local mode = NormalizeColorMode(section.colorMode, section.classColor)
    if mode == "spec" then
        local entry = EnsureSpecColor(section, powerType)
        return entry.r or 1, entry.g or 1, entry.b or 1, entry.a or (section.fillA or 1)
    end
    if mode == "power" and powerType then
        local r, g, b = GetPowerColor(powerType)
        if r and g and b then
            return r, g, b, section.fillA or 1
        end
    end
    return section.fillR or 1, section.fillG or 1, section.fillB or 1, section.fillA or 1
end

local function GetStatusbarValues()
    local v = {}
    if LSM then 
        for _, n in ipairs(LSM:List("statusbar")) do v[n] = n end 
    end
    return v
end

local function ParseMarkerValues(rawValues, maxValue)
    local values = {}
    local seen = {}

    if type(rawValues) == "table" then
        for _, rawValue in ipairs(rawValues) do
            local value = tonumber(rawValue)
            if value then
                if type(maxValue) == "number" and maxValue > 0 then
                    value = math.max(0, math.min(value, maxValue))
                end
                if value > 0 then
                    local key = string.format("%.3f", value)
                    if not seen[key] then
                        seen[key] = true
                        values[#values + 1] = value
                    end
                end
            end
        end
    elseif type(rawValues) == "string" and rawValues ~= "" then
        for token in string.gmatch(rawValues, "[-%d%.]+") do
            local value = tonumber(token)
            if value then
                if type(maxValue) == "number" and maxValue > 0 then
                    value = math.max(0, math.min(value, maxValue))
                end
                if value > 0 then
                    local key = string.format("%.3f", value)
                    if not seen[key] then
                        seen[key] = true
                        values[#values + 1] = value
                    end
                end
            end
        end
    end

    table.sort(values)
    while #values > 3 do
        table.remove(values)
    end
    return values
end

local function GetMarkerState(db)
    if _G._KRB_GetMarkerState then
        return _G._KRB_GetMarkerState()
    end
    db.secondary = db.secondary or {}
    db.secondary.markers = db.secondary.markers or { mode = "loadout", character = {}, specs = {}, loadouts = {} }
    return db.secondary.markers
end

local function GetActiveMarkerConfig(db)
    if _G._KRB_GetActiveMarkerConfig then
        return _G._KRB_GetActiveMarkerConfig()
    end
    local state = GetMarkerState(db)
    state.character = state.character or {}
    return state.character
end

local function GetMarkerSlotText(markerCfg, index)
    local value = markerCfg and markerCfg["slot" .. index]
    return value and tostring(value) or ""
end

local function SetMarkerSlotText(markerCfg, index, text)
    local value = tonumber(text)
    markerCfg["slot" .. index] = (value and value > 0) and value or nil
    local values = ParseMarkerValues({
        markerCfg.slot1,
        markerCfg.slot2,
        markerCfg.slot3,
    })
    markerCfg.values = table.concat(values, ",")
end

local function GetMarkerRenderValues(markerCfg, maxValue)
    if type(markerCfg) ~= "table" then
        return {}
    end

    local slotValues = ParseMarkerValues({
        markerCfg.slot1,
        markerCfg.slot2,
        markerCfg.slot3,
    }, maxValue)

    if #slotValues > 0 then
        return slotValues
    end

    return ParseMarkerValues(markerCfg.values, maxValue)
end

local function ShouldPreviewMarkersOnPrimary(markerCfg, primaryPowerType, secondaryResource)
    local manaPowerType = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0
    if type(markerCfg) ~= "table" or markerCfg.enabled ~= true then
        return false
    end

    if markerCfg.target == "primary" then
        return primaryPowerType ~= manaPowerType
    end
    if markerCfg.target == "secondary" then
        return false
    end

    if secondaryResource and secondaryResource.type == "bar" then
        return false
    end

    return primaryPowerType ~= manaPowerType
end

local function ShouldPreviewMarkersOnSecondary(markerCfg, secondaryResource)
    if type(markerCfg) ~= "table" or markerCfg.enabled ~= true then
        return false
    end

    if not (secondaryResource and secondaryResource.type == "bar") then
        return false
    end

    if markerCfg.target == "primary" then
        return false
    end

    return true
end

-------------------------------------------------------------------------------
-- BLOQUES DE OPCIONES (DOS COLUMNAS)
-------------------------------------------------------------------------------
local function CreateOptionBlock(parent, title, x, y, width)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 40)
    frame:SetPoint("TOPLEFT", x, y)
    KT:AddBackdrop(frame, 0.04, 0.04, 0.05, 0.95)
    KT:AddBorder(frame, 0.18, 0.18, 0.22, 1)

    local titleText = frame:CreateFontString(nil, "OVERLAY")
    titleText:SetFont(KT.FONT_PATH, 10, "OUTLINE")
    do
        local r, g, b = CurrentAccentColor()
        titleText:SetTextColor(r, g, b, 1)
    end
    titleText:SetPoint("TOPLEFT", 10, -8)
    local localizedTitle = LText(title) or ""
    if type(localizedTitle) == "string" then
        localizedTitle = localizedTitle:upper()
    end
    titleText:SetText(localizedTitle)

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

local function BeginOptionBlocks(sc, startY, opts)
    local gap = (opts and opts.gap) or 12
    local columnGap = (opts and opts.columnGap) or 14
    local fullW = sc:GetWidth()
    local blockW = math.floor((fullW - 20 - columnGap) / 2)
    local leftX = 10
    local rightX = leftX + blockW + columnGap
    return {
        parent = sc,
        startY = startY,
        gap = gap,
        blockW = blockW,
        leftX = leftX,
        rightX = rightX,
        leftUsed = 0,
        rightUsed = 0,
    }
end

local function AddOptionBlock(cols, column, title, buildFn)
    local x = (column == "right") and cols.rightX or cols.leftX
    local yOff = -(cols.startY + ((column == "right") and cols.rightUsed or cols.leftUsed))
    local frame, content = CreateOptionBlock(cols.parent, title, x, yOff, cols.blockW)
    local contentH = buildFn(content)
    local totalH = FinalizeOptionBlock(frame, content, contentH)
    if column == "right" then
        cols.rightUsed = cols.rightUsed + totalH + cols.gap
    else
        cols.leftUsed = cols.leftUsed + totalH + cols.gap
    end
    return frame
end

local function EndOptionBlocks(cols)
    return cols.startY + math.max(cols.leftUsed, cols.rightUsed)
end

local function PulseBlock(frame)
    if not frame then return end
    local glow = frame._rbPreviewGlow
    if not glow then
        glow = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        glow:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
        glow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
        local r, g, b = CurrentAccentColor()
        KT:AddBorder(glow, r, g, b, 1)
        glow:SetFrameLevel(frame:GetFrameLevel() + 10)
        frame._rbPreviewGlow = glow
    end
    glow:Show()
    C_Timer.After(1.0, function()
        if glow then glow:Hide() end
    end)
end

local function ScrollToBlock(sc, frame)
    if not (sc and frame and KT and KT.SmoothScrollTo) then return end
    local sf = KT._scrollFrame
    local child = sf and sf.GetScrollChild and sf:GetScrollChild()
    local sectionTop = frame.GetTop and frame:GetTop()
    local childTop = child and child.GetTop and child:GetTop()
    if sectionTop and childTop then
        KT.SmoothScrollTo(math.max(0, (childTop - sectionTop) - 40))
        C_Timer.After(0.15, function() PulseBlock(frame) end)
    end
end

-------------------------------------------------------------------------------
-- Animador de Previsualización Suave
-------------------------------------------------------------------------------
local _animTimers = {}
local function SmoothAnimate(frame, key, targetVal, applyFn)
    if not frame then return end
    if not _animTimers[frame] then _animTimers[frame] = {} end
    if _animTimers[frame][key] then
        _animTimers[frame][key]:Cancel()
        _animTimers[frame][key] = nil
    end
    
    local startVal = frame["_anim_" .. key] or targetVal
    frame["_anim_" .. key] = targetVal
    
    if math.abs(startVal - targetVal) < 0.001 then
        applyFn(targetVal)
        return
    end
    
    local elapsed = 0
    local ticker
    ticker = C_Timer.NewTicker(0.016, function()
        elapsed = elapsed + 0.016
        local t = math.min(elapsed / 0.18, 1)
        -- Ease-out quad
        t = 1 - (1 - t) * (1 - t)
        local v = startVal + (targetVal - startVal) * t
        applyFn(v)
        if t >= 1 then
            ticker:Cancel()
            if _animTimers[frame] then _animTimers[frame][key] = nil end
        end
    end)
    _animTimers[frame][key] = ticker
end

-- ============================================================================
-- PESTAÑA: BARRAS DE RECURSOS (RESOURCE BARS)
-- ============================================================================
KT:RegisterPage("resourcebars", LText("Resource Bars"), 13, function(sc, W)
    local y, h = 0, 0
    local db = DB()
    if not db then return y end
    local markerState = GetMarkerState(db)
    local previewBlocks = {}
    local function MarkerCfg()
        return GetActiveMarkerConfig(db)
    end
    local function PreviewMode()
        local mode = db.general and db.general.previewMode or "stack"
        if mode ~= "stack" and mode ~= "health" and mode ~= "power" and mode ~= "class" then
            mode = "stack"
        end
        return mode
    end

    -- ── LAYOUT PREVIEW (Visualización Interactiva en Orden) ──
    local previewContainer = CreateFrame("Frame", nil, sc)
    previewContainer:SetSize(sc:GetWidth() - 20, 180)
    previewContainer:SetPoint("TOP", sc, "TOP", 10, -10)
    if KT.AttachStickyPreview then
        KT:AttachStickyPreview(previewContainer, { point = "TOP", relativePoint = "TOP", x = 10, y = -10 })
    end
    
    local bgPrev = previewContainer:CreateTexture(nil, "BACKGROUND")
    bgPrev:SetAllPoints()
    bgPrev:SetColorTexture(0.05, 0.05, 0.05, 0.7)

    local lblPreview = previewContainer:CreateFontString(nil, "OVERLAY")
    lblPreview:SetFont(KT.FONT_PATH, 12, "OUTLINE")
    lblPreview:SetPoint("TOP", 0, -5)
    lblPreview:SetText(LText("Layout Preview (Stack)"))
    do
        local r, g, b = CurrentAccentColor()
        lblPreview:SetTextColor(r, g, b, 1)
    end

    local function CreatePreviewNavButton(parent, text, x)
        local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
        btn:SetSize(82, 20)
        btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -26)
        KT:AddBackdrop(btn, 0.05, 0.05, 0.06, 0.95)
        KT:AddBorder(btn, 0.18, 0.18, 0.22, 1)
        local fs = btn:CreateFontString(nil, "OVERLAY")
        fs:SetFont(KT.FONT_PATH, 9, "OUTLINE")
        fs:SetPoint("CENTER")
        fs:SetText(text)
        btn.text = fs
        return btn
    end

    local previewModeButtons = {
        stack = CreatePreviewNavButton(previewContainer, LText("Stack"), 10),
        health = CreatePreviewNavButton(previewContainer, LText("Health"), 98),
        power = CreatePreviewNavButton(previewContainer, LText("Power"), 186),
        class = CreatePreviewNavButton(previewContainer, LText("Class"), 274),
    }
    local previewModeOrder = { "stack", "health", "power", "class" }
    local previewModeAvailability = {
        stack = true,
        health = db.health.enabled == true,
        power = db.primary.enabled == true,
        class = db.secondary.enabled == true,
    }

    local function UpdatePreviewModeButtons()
        local mode = PreviewMode()
        local x = 10
        for _, key in ipairs(previewModeOrder) do
            local btn = previewModeButtons[key]
            local available = previewModeAvailability[key] == true
            btn:SetShown(available)
            if available then
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", x, -26)
                x = x + 88
            end

            if available and key == mode then
                local r, g, b = CurrentAccentColor()
                KT:AddBorder(btn, r, g, b, 1)
                btn.text:SetTextColor(1, 1, 1, 1)
            else
                KT:AddBorder(btn, 0.18, 0.18, 0.22, 1)
                btn.text:SetTextColor(0.75, 0.75, 0.75, 1)
            end
        end
    end
    for key, btn in pairs(previewModeButtons) do
        btn:SetScript("OnClick", function()
            db.general.previewMode = key
            UpdatePreviewModeButtons()
            if KT.RefreshPage then KT:RefreshPage(true) end
        end)
    end

    -- Base Ancla (Representando la barra de Cooldowns que sirve de ancla)
    local fakeAnchor = CreateFrame("StatusBar", nil, previewContainer)
    local castW = 250
    fakeAnchor:SetSize(castW, 30)
    fakeAnchor:SetPoint("BOTTOM", previewContainer, "BOTTOM", 0, 15)
    fakeAnchor:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    do
        local r, g, b = CurrentAccentColor()
        fakeAnchor:SetStatusBarColor(r, g, b, 0.5)
    end
    local castText = fakeAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    castText:SetPoint("CENTER")
    castText:SetText(LText("Anchor: Cooldowns / Fallback"))

    -- Recurso Falso (Puntos de Combo / Runas)
    local fakePips = CreateFrame("Frame", nil, previewContainer)
    local pipTextures = {}
    for i = 1, 10 do
        local pipBg = fakePips:CreateTexture(nil, "BACKGROUND")
        local pip = fakePips:CreateTexture(nil, "ARTWORK")
        pipTextures[i] = { bg = pipBg, fill = pip }
    end

    -- Poder Falso
    local fakePower = CreateFrame("StatusBar", nil, previewContainer)
    fakePower:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    fakePower._markers = {}
    
    -- Recurso de clase falso (barra continua para specs tipo Astral Power / Maelstrom)
    local fakeClassBar = CreateFrame("StatusBar", nil, previewContainer)
    fakeClassBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    fakeClassBar._markers = {}
    
    -- Salud Falsa
    local fakeHealth = CreateFrame("StatusBar", nil, previewContainer)
    fakeHealth:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")

    local function CreatePreviewHitbox(frame, label, blockKey)
        local btn = CreateFrame("Button", nil, previewContainer)
        btn:SetAllPoints(frame)
        btn:RegisterForClicks("LeftButtonDown")
        btn:SetFrameLevel(frame:GetFrameLevel() + 10)
        local r, g, b = CurrentAccentColor()
        local border = KT.PP.CreateBorder(btn, r, g, b, 1, 2, "OVERLAY", 7)
        border:Hide()
        local text = btn:CreateFontString(nil, "OVERLAY")
        text:SetFont(KT.FONT_PATH, 9, "OUTLINE")
        text:SetPoint("BOTTOM", btn, "TOP", 0, 4)
        text:SetText(label)
        text:SetTextColor(1, 1, 1, 0.95)
        text:Hide()
        btn:SetScript("OnEnter", function()
            border:Show()
            text:Show()
        end)
        btn:SetScript("OnLeave", function()
            border:Hide()
            text:Hide()
        end)
        btn:SetScript("OnMouseDown", function()
            ScrollToBlock(sc, previewBlocks[blockKey])
        end)
        btn:Hide()
        return btn
    end

    local anchorHit = CreatePreviewHitbox(fakeAnchor, LText("Go to Anchor"), "anchor")
    local healthHit = CreatePreviewHitbox(fakeHealth, LText("Go to Health"), "health")
    local powerHit = CreatePreviewHitbox(fakePower, LText("Go to Power"), "power")
    local classBarHit = CreatePreviewHitbox(fakeClassBar, LText("Go to Class Resource"), "class")
    local classPipsHit = CreatePreviewHitbox(fakePips, LText("Go to Class Resource"), "class")

    local function UpdatePreview()
        local matchW = db.general.matchCooldownWidth
        local w = matchW and castW or (db.general.manualWidth or 250)
        local texHealth = LSM and LSM:Fetch("statusbar", db.health and db.health.texture) or "Interface\\Buttons\\WHITE8x8"
        local texPrimary = LSM and LSM:Fetch("statusbar", db.primary and db.primary.texture) or "Interface\\Buttons\\WHITE8x8"
        local texSecondary = LSM and LSM:Fetch("statusbar", db.secondary and db.secondary.texture) or "Interface\\Buttons\\WHITE8x8"
        local markerCfg = MarkerCfg() or {}
        local previewMode = PreviewMode()
        local manaPowerType = (Enum and Enum.PowerType and Enum.PowerType.Mana) or 0

        local ppType
        if _G._KRB_GetPrimaryPowerType then
            local ok, res = pcall(_G._KRB_GetPrimaryPowerType)
            if ok and type(res) == "number" then
                ppType = res
            end
        end
        if type(ppType) ~= "number" and UnitPowerType then
            ppType = UnitPowerType("player")
        end
        if type(ppType) ~= "number" then
            ppType = manaPowerType
        end

        local secondary = nil
        if _G._KRB_GetSecondaryResource then
            local ok, res = pcall(_G._KRB_GetSecondaryResource)
            if ok and type(res) == "table" then
                secondary = res
            end
        end

        local hidePrimaryMana = (IsCurrentSpecManaHidden(db) and ppType == manaPowerType)
        previewModeAvailability.health = db.health.enabled == true
        previewModeAvailability.power = db.primary.enabled == true and not hidePrimaryMana
        previewModeAvailability.class = db.secondary.enabled == true and secondary ~= nil
        if not previewModeAvailability[previewMode] then
            previewMode = "stack"
            db.general.previewMode = previewMode
        end

        local singleMode = previewMode ~= "stack"
        local shouldShowPower = db.primary.enabled and not hidePrimaryMana and (previewMode == "stack" or previewMode == "power")
        local shouldShowSecondaryBar = db.secondary.enabled and secondary and secondary.type == "bar" and (previewMode == "stack" or previewMode == "class")
        local shouldShowSecondaryPips = db.secondary.enabled and secondary and secondary.type == "pips" and (previewMode == "stack" or previewMode == "class")

        fakeHealth:SetStatusBarTexture(texHealth)
        SmoothAnimate(fakeHealth, "width", w, function(val) fakeHealth:SetWidth(val) end)
        SmoothAnimate(fakeHealth, "height", db.health.height, function(val) fakeHealth:SetHeight(val) end)
        fakeHealth:SetStatusBarColor(db.health.fillR, db.health.fillG, db.health.fillB, db.health.fillA)
        fakeHealth:SetShown(db.health.enabled and (previewMode == "stack" or previewMode == "health"))

        fakePower:SetStatusBarTexture(texPrimary)
        SmoothAnimate(fakePower, "width", w, function(val) fakePower:SetWidth(val) end)
        SmoothAnimate(fakePower, "height", db.primary.height, function(val) fakePower:SetHeight(val) end)
        do
            local r, g, b, a = ResolveSectionColor(db.primary, ppType)
            fakePower:SetStatusBarColor(r, g, b, a)
        end
        fakePower:SetShown(shouldShowPower)
        do
            local maxPower = 100
            if UnitPowerMax then
                local ok, res = pcall(UnitPowerMax, "player", ppType)
                if ok and type(res) == "number" and res > 0 then
                    maxPower = res
                end
            end
            pcall(fakePower.SetMinMaxValues, fakePower, 0, maxPower)
            pcall(fakePower.SetValue, fakePower, maxPower * 0.5)
        end

        fakeClassBar:SetStatusBarTexture(texSecondary)
        SmoothAnimate(fakeClassBar, "width", w, function(val) fakeClassBar:SetWidth(val) end)
        SmoothAnimate(fakeClassBar, "height", db.secondary.pipHeight, function(val) fakeClassBar:SetHeight(val) end)
        do
            local secPowerType = secondary and secondary.power
            local r, g, b, a = ResolveSectionColor(db.secondary, secPowerType)
            fakeClassBar:SetStatusBarColor(r, g, b, a)
        end
        fakeClassBar:SetShown(shouldShowSecondaryBar)
        do
            local maxValue = 100
            if secondary and secondary.kind == "stagger" and UnitHealthMax then
                local ok, res = pcall(UnitHealthMax, "player")
                if ok and type(res) == "number" and res > 0 then
                    maxValue = res
                end
            elseif secondary and type(secondary.max) == "number" and secondary.max > 0 then
                maxValue = secondary.max
            elseif secondary and secondary.power and UnitPowerMax then
                local ok, res = pcall(UnitPowerMax, "player", secondary.power)
                if ok and type(res) == "number" and res > 0 then
                    maxValue = res
                end
            end
            pcall(fakeClassBar.SetMinMaxValues, fakeClassBar, 0, maxValue)
            pcall(fakeClassBar.SetValue, fakeClassBar, maxValue * 0.55)
        end

        SmoothAnimate(fakePips, "width", w, function(val) fakePips:SetWidth(val) end)
        SmoothAnimate(fakePips, "height", db.secondary.pipHeight, function(val) fakePips:SetHeight(val) end)
        
        local pipCount = 5
        if secondary and secondary.type == "pips" and type(secondary.max) == "number" and secondary.max > 0 then
            pipCount = math.max(1, math.min(10, math.floor(secondary.max + 0.5)))
        end

        local pipSpacing = db.secondary.pipSpacing or 0
        local denom = math.max(1, pipCount)
        local pipW = (w - (pipSpacing * (denom - 1))) / denom
        for i = 1, 10 do
            local texEntry = pipTextures[i]
            if not texEntry then break end
            local bg = texEntry.bg
            local fill = texEntry.fill
            if i <= pipCount then
                local x = (i - 1) * (pipW + pipSpacing)
                bg:Show()
                fill:Show()
                SmoothAnimate(bg, "x", x, function(val) bg:SetPoint("LEFT", fakePips, "LEFT", val, 0) end)
                SmoothAnimate(bg, "w", pipW, function(val)
                    bg:SetWidth(val); fill:SetWidth(val)
                end)
                SmoothAnimate(bg, "h", db.secondary.pipHeight, function(val)
                    bg:SetHeight(val); fill:SetHeight(val)
                end)
                fill:SetTexture(texSecondary)
                fill:SetPoint("CENTER", bg, "CENTER", 0, 0)
                do
                    local r, g, b, a = GetSecondaryPipColor(db, secondary, i)
                    fill:SetVertexColor(r, g, b, i <= math.min(3, pipCount) and a or math.min(a or 1, 0.2))
                end
                bg:SetColorTexture(0.1, 0.1, 0.1, db.general.bgA)
            else
                bg:Hide()
                fill:Hide()
            end
        end
        fakePips:SetShown(shouldShowSecondaryPips)

        local function UpdateMarkersForBar(bar, maxValue, barHeight, markersTable)
            if not bar or not bar:IsShown() or markerCfg.enabled ~= true then
                for _, marker in pairs(markersTable or {}) do
                    if marker and marker.Hide then marker:Hide() end
                end
                return
            end
            if type(maxValue) ~= "number" or maxValue <= 0 then
                for _, marker in pairs(markersTable or {}) do
                    if marker and marker.Hide then marker:Hide() end
                end
                return
            end

            local values = GetMarkerRenderValues(markerCfg, maxValue)
            if #values == 0 then
                for _, marker in pairs(markersTable or {}) do
                    if marker and marker.Hide then marker:Hide() end
                end
                return
            end

            for index = 1, #values do
                if not markersTable[index] then
                    local marker = bar:CreateTexture(nil, "OVERLAY", nil, 3)
                    marker:SetTexture("Interface\\Buttons\\WHITE8x8")
                    markersTable[index] = marker
                end
            end

            for index, value in ipairs(values) do
                local marker = markersTable[index]
                local markerWidth = math.max(1, markerCfg.width or 2)
                local markerHeight = math.max(1, (barHeight or 0) - 4)
                local offset = (value / maxValue) * w
                offset = math.max(markerWidth * 0.5, math.min(offset, math.max(markerWidth * 0.5, w - (markerWidth * 0.5))))
                marker:ClearAllPoints()
                marker:SetPoint("CENTER", bar, "LEFT", offset, 0)
                marker:SetSize(markerWidth, markerHeight)
                marker:SetColorTexture(markerCfg.colorR or 1, markerCfg.colorG or 1, markerCfg.colorB or 1, markerCfg.colorA or 0.95)
                marker:Show()
            end

            for index, marker in pairs(markersTable) do
                if index > #values and marker and marker.Hide then
                    marker:Hide()
                end
            end
        end

        -- Markers follow the same rules as the live bars:
        -- - on primary bar when the primary power isn't Mana
        -- - on class-resource bar when the secondary resource is a continuous bar
        do
            local maxPower = 100
            if UnitPowerMax then
                local ok, res = pcall(UnitPowerMax, "player", ppType)
                if ok and type(res) == "number" and res > 0 then
                    maxPower = res
                end
            end
            if ShouldPreviewMarkersOnPrimary(markerCfg, ppType, secondary) then
                UpdateMarkersForBar(fakePower, maxPower, db.primary.height or 0, fakePower._markers or {})
            else
                for _, marker in pairs(fakePower._markers or {}) do
                    if marker and marker.Hide then marker:Hide() end
                end
            end
        end

        do
            local maxValue = 100
            if secondary and secondary.kind == "stagger" and UnitHealthMax then
                local ok, res = pcall(UnitHealthMax, "player")
                if ok and type(res) == "number" and res > 0 then
                    maxValue = res
                end
            elseif secondary and type(secondary.max) == "number" and secondary.max > 0 then
                maxValue = secondary.max
            elseif secondary and secondary.power and UnitPowerMax then
                local ok, res = pcall(UnitPowerMax, "player", secondary.power)
                if ok and type(res) == "number" and res > 0 then
                    maxValue = res
                end
            end
            if ShouldPreviewMarkersOnSecondary(markerCfg, secondary) then
                UpdateMarkersForBar(fakeClassBar, maxValue, db.secondary.pipHeight or 0, fakeClassBar._markers or {})
            else
                for _, marker in pairs(fakeClassBar._markers or {}) do
                    if marker and marker.Hide then marker:Hide() end
                end
            end
        end

        -- Apilamiento Abajo -> Arriba
        fakePips:ClearAllPoints(); fakeClassBar:ClearAllPoints(); fakePower:ClearAllPoints(); fakeHealth:ClearAllPoints()
        fakeAnchor:SetShown(previewMode == "stack")
        if singleMode then
            if previewMode == "health" and fakeHealth:IsShown() then
                fakeHealth:SetPoint("CENTER", previewContainer, "CENTER", 0, -4)
            elseif previewMode == "power" and fakePower:IsShown() then
                fakePower:SetPoint("CENTER", previewContainer, "CENTER", 0, -4)
            elseif previewMode == "class" then
                if fakeClassBar:IsShown() then
                    fakeClassBar:SetPoint("CENTER", previewContainer, "CENTER", 0, -4)
                elseif fakePips:IsShown() then
                    fakePips:SetPoint("CENTER", previewContainer, "CENTER", 0, -4)
                end
            end
        else
            local lastAnchor = fakeAnchor
            local lastRel = "TOP"
            local yOff = db.general.anchorGap or 4
            local xOff = db.general.xOffset or 0

            if shouldShowSecondaryBar or shouldShowSecondaryPips then
                if shouldShowSecondaryBar then
                    fakeClassBar:SetPoint("BOTTOM", lastAnchor, lastRel, xOff, yOff)
                    lastAnchor = fakeClassBar
                else
                    fakePips:SetPoint("BOTTOM", lastAnchor, lastRel, xOff, yOff)
                    lastAnchor = fakePips
                end
                lastRel = "TOP"; yOff = db.general.anchorGap or 4; xOff = 0
            end
            if shouldShowPower then
                fakePower:SetPoint("BOTTOM", lastAnchor, lastRel, xOff, yOff)
                lastAnchor = fakePower; lastRel = "TOP"; yOff = db.general.anchorGap or 4; xOff = 0
            end
            if db.health.enabled then
                fakeHealth:SetPoint("BOTTOM", lastAnchor, lastRel, xOff, yOff)
            end
        end

        lblPreview:SetText(LText(previewMode == "stack" and "Layout Preview (Stack)" or ("Layout Preview - " .. previewMode:gsub("^%l", string.upper))))
        anchorHit:SetShown(fakeAnchor:IsShown())
        healthHit:SetShown(fakeHealth:IsShown())
        powerHit:SetShown(fakePower:IsShown())
        classBarHit:SetShown(fakeClassBar:IsShown())
        classPipsHit:SetShown(fakePips:IsShown())
        UpdatePreviewModeButtons()
    end

    UpdatePreview()
    y = y + 200

    _, h = W:Toggle(sc, LText("Enable Module"), -y,
        function()
            return (db.primary.enabled or db.secondary.enabled or db.health.enabled) and true or false
        end,
        function(v)
            db.primary.enabled = v and true or false
            db.secondary.enabled = v and true or false
            db.health.enabled = v and true or false
            Reload()
        end)
    y = y + h

    _, h = W:Button(sc, LText("Restore Resource Bars Defaults"), -y, function()
        RestoreResourceBarsDefaults()
    end)
    y = y + h + 8

    local cols = BeginOptionBlocks(sc, y)
    local colorModeValues = { ["spec"] = LText("Per Spec"), ["power"] = LText("Power Type"), ["custom"] = LText("Custom") }
    local currentSpecName = GetCurrentSpecName() or "Current Spec"

    AddOptionBlock(cols, "left", LText("Behavior"), function(container)
        local by = 0
        _, h = W:Toggle(container, "Hide Out of Combat", -by, function() return db.general.hideOOC end, function(v) db.general.hideOOC=v; Refresh(); KT:RefreshPage(true) end); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", LText("Skins & Background"), function(container)
        local by = 0
        _, h = W:Dropdown(container, "Bar Texture", -by, GetStatusbarValues, function() return db.general.texture end, function(v)
            db.general.texture = v
            db.health.texture = v
            db.primary.texture = v
            db.secondary.texture = v
            UpdatePreview()
            Refresh()
        end); by = by + h
        _, h = W:Slider(container, "Background Alpha", -by, function() return db.general.bgA end, function(v) db.general.bgA=v; UpdatePreview(); Refresh() end, 0, 1, 0.05); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", LText("Frame Strata"), function(container)
        local by = 0
        _, h = W:Dropdown(container, "Stack Strata", -by, { ["BACKGROUND"]="Background", ["LOW"]="Low", ["MEDIUM"]="Medium", ["HIGH"]="High", ["DIALOG"]="Dialog" }, function() return db.general.strata end, function(v) db.general.strata=v; Refresh() end); by = by + h
        return by
    end)

    AddOptionBlock(cols, "left", LText("Power Type Colors"), function(container)
        local by = 0
        local entries = GetPowerColorEntries()
        _, h = W:Label(container, LText("These colors apply when Color Source is set to Power Type."), -by, 10, { r = 0.75, g = 0.75, b = 0.75 }); by = by + h
        for i = 1, #entries, 2 do
            local leftEntry = entries[i]
            local rightEntry = entries[i + 1]
            _, h = W:DualRow(container, -by,
                leftEntry and {
                    type = "colorpicker",
                    text = leftEntry.label,
                    getValue = function()
                        return GetEditablePowerColor(db, leftEntry.power)
                    end,
                    setValue = function(r, g, b)
                        SetEditablePowerColor(db, leftEntry.power, r, g, b)
                        UpdatePreview()
                        Refresh()
                    end,
                } or nil,
                rightEntry and {
                    type = "colorpicker",
                    text = rightEntry.label,
                    getValue = function()
                        return GetEditablePowerColor(db, rightEntry.power)
                    end,
                    setValue = function(r, g, b)
                        SetEditablePowerColor(db, rightEntry.power, r, g, b)
                        UpdatePreview()
                        Refresh()
                    end,
                } or nil
            ); by = by + h
        end
        _, h = W:Button(container, LText("Reset Power Colors"), -by, function()
            db.powerColors = {}
            UpdatePreview()
            Refresh()
            if KT.RefreshPage then KT:RefreshPage(true) end
        end, 220, nil, nil, "CENTER"); by = by + h
        return by
    end)
    previewBlocks.health = AddOptionBlock(cols, "left", LText("Health Bar"), function(container)
        local by = 0
        _, h = W:Toggle(container, "Enable Health Bar", -by, function() return db.health.enabled end, function(v) db.health.enabled=v; UpdatePreview(); Refresh(); KT:RefreshPage(true) end); by = by + h
        _, h = W:Slider(container, "Height", -by, function() return db.health.height end, function(v) db.health.height=v; UpdatePreview(); Refresh() end, 5, 50, 1); by = by + h
        _, h = W:Slider(container, "Border Size", -by, function() return db.health.borderSize end, function(v) db.health.borderSize=v; Refresh() end, 0, 5, 1); by = by + h
        _, h = W:Slider(container, "Text Size", -by, function() return db.health.textSize or 13 end, function(v) db.health.textSize=v; Refresh() end, 8, 32, 1); by = by + h
        _, h = W:Dropdown(container, "Resource Text", -by, { ["none"]="None", ["both"]="HP & Percent", ["curhpshort"]="HP Only (Abbrev)", ["curhpfull"]="HP Only (Full)", ["perhp"]="Percent Only" }, function() return db.health.textFormat end, function(v) db.health.textFormat=v; Refresh() end); by = by + h
        _, h = W:ColorSwatch(container, LText("Fill Color Options"), -by,
            function() return db.health.fillR, db.health.fillG, db.health.fillB, db.health.fillA end,
            function(r,g,b,a) db.health.fillR, db.health.fillG, db.health.fillB, db.health.fillA = r,g,b,a; UpdatePreview(); Refresh() end, true); by = by + h
        return by
    end)

    previewBlocks.anchor = AddOptionBlock(cols, "right", LText("CDM Group Anchor & Position"), function(container)
        local by = 0
        _, h = W:Toggle(container, "Match Cooldowns Width", -by, function() return db.general.matchCooldownWidth end, function(v) db.general.matchCooldownWidth=v; UpdatePreview(); Refresh(); KT:RefreshPage(true) end); by = by + h
        if not db.general.matchCooldownWidth then
            _, h = W:Slider(container, "Manual Stack Width", -by, function() return db.general.manualWidth end, function(v) db.general.manualWidth=v; UpdatePreview(); Refresh() end, 50, 400, 1); by = by + h
        end
        _, h = W:Slider(container, "X Offset (From Anchor)", -by, function() return db.general.xOffset end, function(v) db.general.xOffset=v; UpdatePreview(); Refresh() end, -200, 200, 1); by = by + h
        _, h = W:Slider(container, "Y Offset (Gap between bars)", -by, function() return db.general.anchorGap end, function(v) db.general.anchorGap=v; UpdatePreview(); Refresh() end, 0, 20, 1); by = by + h
        return by
    end)

    previewBlocks.class = AddOptionBlock(cols, "right", LText("Resource 1: Class Specific (Pips)"), function(container)
        local by = 0
        _, h = W:Toggle(container, "Enable Class Resource", -by, function() return db.secondary.enabled end, function(v) db.secondary.enabled=v; UpdatePreview(); Refresh(); KT:RefreshPage(true) end); by = by + h
        _, h = W:Slider(container, "Height", -by, function() return db.secondary.pipHeight end, function(v) db.secondary.pipHeight=v; UpdatePreview(); Refresh() end, 5, 40, 1); by = by + h
        _, h = W:Slider(container, "Pip Spacing", -by, function() return db.secondary.pipSpacing end, function(v) db.secondary.pipSpacing=v; UpdatePreview(); Refresh() end, 0, 20, 1); by = by + h
        _, h = W:Slider(container, "Border Size", -by, function() return db.secondary.borderSize end, function(v) db.secondary.borderSize=v; Refresh() end, 0, 5, 1); by = by + h
        _, h = W:Slider(container, "Text Size", -by, function() return db.secondary.textSize or 13 end, function(v) db.secondary.textSize=v; Refresh() end, 8, 32, 1); by = by + h
        _, h = W:Dropdown(container, LText("Color Source"), -by, colorModeValues,
            function() return NormalizeColorMode(db.secondary.colorMode, db.secondary.classColor) end,
            function(v) db.secondary.colorMode=v; UpdatePreview(); Refresh(); KT:RefreshPage(true) end,
            { "spec", "power", "custom" }); by = by + h
        _, h = W:Label(container, LText("Spec Color") .. ": " .. currentSpecName, -by, 10, { r = 0.75, g = 0.75, b = 0.75 }); by = by + h
        _, h = W:ColorSwatch(container, LText("Current Spec Color"), -by,
            function()
                local secondary = nil
                if _G._KRB_GetSecondaryResource then
                    local ok, res = pcall(_G._KRB_GetSecondaryResource)
                    if ok and type(res) == "table" then secondary = res end
                end
                local entry = EnsureSpecColor(db.secondary, secondary and secondary.power)
                return entry.r, entry.g, entry.b, entry.a
            end,
            function(r,g,b,a)
                local secondary = nil
                if _G._KRB_GetSecondaryResource then
                    local ok, res = pcall(_G._KRB_GetSecondaryResource)
                    if ok and type(res) == "table" then secondary = res end
                end
                local entry = EnsureSpecColor(db.secondary, secondary and secondary.power)
                entry.r, entry.g, entry.b, entry.a = r, g, b, a
                UpdatePreview(); Refresh()
            end, true); by = by + h
        _, h = W:ColorSwatch(container, LText("Custom Fill Color"), -by,
            function() return db.secondary.fillR, db.secondary.fillG, db.secondary.fillB, db.secondary.fillA end,
            function(r,g,b,a) db.secondary.fillR, db.secondary.fillG, db.secondary.fillB, db.secondary.fillA = r,g,b,a; UpdatePreview(); Refresh() end, true); by = by + h
        do
            local pipResource = GetCurrentSecondaryPipResource()
            if pipResource then
                local pipLabel = GetSecondaryPipResourceLabel(pipResource) or LText("Class Resource")
                local pipCount = math.max(1, math.min(10, math.floor((pipResource.max or 0) + 0.5)))
                _, h = W:Label(container, string.format("%s: %s", LText("Current Pip Resource"), pipLabel), -by, 10, { r = 0.75, g = 0.75, b = 0.75 }); by = by + h
                _, h = W:Label(container, LText("These colors override the selected color source for each pip."), -by, 10, { r = 0.75, g = 0.75, b = 0.75 }); by = by + h
                for i = 1, pipCount, 2 do
                    local leftIndex = i
                    local rightIndex = i + 1
                    _, h = W:DualRow(container, -by,
                        {
                            type = "colorpicker",
                            text = string.format(LText("Pip %d"), leftIndex),
                            getValue = function()
                                return GetSecondaryPipColor(db, pipResource, leftIndex)
                            end,
                            setValue = function(r, g, b, a)
                                SetSecondaryPipColor(db, pipResource, leftIndex, r, g, b, a)
                                UpdatePreview()
                                Refresh()
                            end,
                            hasAlpha = true,
                        },
                        rightIndex <= pipCount and {
                            type = "colorpicker",
                            text = string.format(LText("Pip %d"), rightIndex),
                            getValue = function()
                                return GetSecondaryPipColor(db, pipResource, rightIndex)
                            end,
                            setValue = function(r, g, b, a)
                                SetSecondaryPipColor(db, pipResource, rightIndex, r, g, b, a)
                                UpdatePreview()
                                Refresh()
                            end,
                            hasAlpha = true,
                        } or nil
                    ); by = by + h
                end
                _, h = W:Button(container, LText("Reset Pip Colors"), -by, function()
                    ResetSecondaryPipColors(db, pipResource)
                    UpdatePreview()
                    Refresh()
                    if KT.RefreshPage then KT:RefreshPage(true) end
                end, 220, nil, nil, "CENTER"); by = by + h
            else
                _, h = W:Label(container, LText("No pip-based resource is active for the current spec."), -by, 10, { r = 0.75, g = 0.75, b = 0.75 }); by = by + h
            end
        end
        _, h = W:Dropdown(container, "Marker Profile Scope", -by,
            { loadout = LText("Per Talent Preset"), spec = LText("Per Spec"), character = LText("Per Character") },
            function() return markerState.mode or "loadout" end,
            function(v) markerState.mode = v; UpdatePreview(); Refresh(); KT:RefreshPage(true) end,
            { "loadout", "spec", "character" }); by = by + h
        _, h = W:Dropdown(container, "Marker Target", -by,
            { auto = LText("Auto"), primary = LText("Primary Power Bar"), secondary = LText("Class Resource Bar") },
            function() return MarkerCfg().target or "auto" end,
            function(v) local markerCfg = MarkerCfg(); markerCfg.target = v; UpdatePreview(); Refresh() end,
            { "auto", "primary", "secondary" }); by = by + h
        _, h = W:Toggle(container, "Enable Custom Markers", -by,
            function() return MarkerCfg().enabled == true end,
            function(v) local markerCfg = MarkerCfg(); markerCfg.enabled = v; UpdatePreview(); Refresh() end); by = by + h
        _, h = W:Input(container, "Marker 1", -by,
            function() return GetMarkerSlotText(MarkerCfg(), 1) end,
            function(v) SetMarkerSlotText(MarkerCfg(), 1, v); UpdatePreview(); Refresh() end); by = by + h
        _, h = W:Input(container, "Marker 2", -by,
            function() return GetMarkerSlotText(MarkerCfg(), 2) end,
            function(v) SetMarkerSlotText(MarkerCfg(), 2, v); UpdatePreview(); Refresh() end); by = by + h
        _, h = W:Input(container, "Marker 3", -by,
            function() return GetMarkerSlotText(MarkerCfg(), 3) end,
            function(v) SetMarkerSlotText(MarkerCfg(), 3, v); UpdatePreview(); Refresh() end); by = by + h
        _, h = W:Label(container, "Up to 3 thresholds for class-resource bars like Astral Power or Maelstrom.", -by, 10, { r = 0.75, g = 0.75, b = 0.75 }); by = by + h
        _, h = W:Slider(container, "Marker Width", -by,
            function() return MarkerCfg().width or 2 end,
            function(v) local markerCfg = MarkerCfg(); markerCfg.width = v; UpdatePreview(); Refresh() end, 1, 6, 1); by = by + h
        _, h = W:ColorSwatch(container, "Marker Color", -by,
            function() local markerCfg = MarkerCfg(); return markerCfg.colorR or 1, markerCfg.colorG or 1, markerCfg.colorB or 1, markerCfg.colorA or 0.95 end,
            function(r,g,b,a) local markerCfg = MarkerCfg(); markerCfg.colorR, markerCfg.colorG, markerCfg.colorB, markerCfg.colorA = r,g,b,a; UpdatePreview(); Refresh() end, true); by = by + h
        return by
    end)

    previewBlocks.power = AddOptionBlock(cols, "right", LText("Primary Power Bar"), function(container)
        local by = 0
        _, h = W:Toggle(container, "Enable Power Bar", -by, function() return db.primary.enabled end, function(v) db.primary.enabled=v; UpdatePreview(); Refresh(); KT:RefreshPage(true) end); by = by + h
        _, h = W:Toggle(container, LText("Hide Mana Bar (Current Spec)"), -by, function() return IsCurrentSpecManaHidden(db) end, function(v) SetCurrentSpecManaHidden(db, v); UpdatePreview(); Refresh() end); by = by + h
        _, h = W:Slider(container, "Height", -by, function() return db.primary.height end, function(v) db.primary.height=v; UpdatePreview(); Refresh() end, 2, 50, 1); by = by + h
        _, h = W:Slider(container, "Border Size", -by, function() return db.primary.borderSize end, function(v) db.primary.borderSize=v; Refresh() end, 0, 5, 1); by = by + h
        _, h = W:Slider(container, "Text Size", -by, function() return db.primary.textSize or 13 end, function(v) db.primary.textSize=v; Refresh() end, 8, 32, 1); by = by + h
        _, h = W:Dropdown(container, "Resource Text", -by, { ["none"]="None", ["both"]="Power & Percent", ["curpp"]="Power Only (Abbrev)", ["curppfull"]="Power Only (Full)", ["perpp"]="Percent Only" }, function() return db.primary.textFormat end, function(v) db.primary.textFormat=v; Refresh() end); by = by + h
        _, h = W:Dropdown(container, LText("Color Source"), -by, colorModeValues,
            function() return NormalizeColorMode(db.primary.colorMode, db.primary.classColor) end,
            function(v) db.primary.colorMode=v; UpdatePreview(); Refresh(); KT:RefreshPage(true) end,
            { "spec", "power", "custom" }); by = by + h
        _, h = W:Label(container, LText("Spec Color") .. ": " .. currentSpecName, -by, 10, { r = 0.75, g = 0.75, b = 0.75 }); by = by + h
        _, h = W:ColorSwatch(container, LText("Current Spec Color"), -by,
            function()
                local ppType = nil
                if _G._KRB_GetPrimaryPowerType then
                    local ok, res = pcall(_G._KRB_GetPrimaryPowerType)
                    if ok and type(res) == "number" then ppType = res end
                end
                local entry = EnsureSpecColor(db.primary, ppType)
                return entry.r, entry.g, entry.b, entry.a
            end,
            function(r,g,b,a)
                local ppType = nil
                if _G._KRB_GetPrimaryPowerType then
                    local ok, res = pcall(_G._KRB_GetPrimaryPowerType)
                    if ok and type(res) == "number" then ppType = res end
                end
                local entry = EnsureSpecColor(db.primary, ppType)
                entry.r, entry.g, entry.b, entry.a = r, g, b, a
                UpdatePreview(); Refresh()
            end, true); by = by + h
        _, h = W:ColorSwatch(container, LText("Custom Fill Color"), -by,
            function() return db.primary.fillR, db.primary.fillG, db.primary.fillB, db.primary.fillA end,
            function(r,g,b,a) db.primary.fillR, db.primary.fillG, db.primary.fillB, db.primary.fillA = r,g,b,a; UpdatePreview(); Refresh() end, true); by = by + h
        return by
    end)

    y = EndOptionBlocks(cols)

    return y
end)
